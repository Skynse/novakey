import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/control_binding.dart';
import '../device/protocol_controls.dart';
import 'profile_store.dart';

class DeviceEvent {
  const DeviceEvent(this.id, this.pressed);
  final String id;
  final bool pressed;
}

class DeviceService extends ChangeNotifier {
  DeviceService({this.reconnectInterval = const Duration(seconds: 3)})
    : assert(reconnectInterval > Duration.zero);

  final Duration reconnectInterval;
  Timer? _reconnect;

  void startAutoReconnect() {
    if (_disposed || !Platform.isLinux || _reconnect != null) return;
    _reconnect = Timer.periodic(reconnectInterval, (_) {
      if (!connected && !connecting) unawaited(connect());
    });
    unawaited(connect());
  }

  bool _disposed = false;
  Process? _process;
  Timer? _heartbeat;
  Completer<List<int>>? _reply;
  int? _command;
  Future<void> _queue = Future.value();
  bool connected = false, connecting = false, running = false;
  String status = 'Not connected';
  final events = StreamController<DeviceEvent>.broadcast();
  Future<void> connect() async {
    if (_disposed || connecting || connected) return;
    connecting = true;
    status = 'Looking for NovaKey…';
    notifyListeners();
    try {
      if (!Platform.isLinux) {
        throw StateError(
          'Device transport currently supports Linux. Profile editing is available offline.',
        );
      }
      final bridge = File('${ProfileStore.directory}/hid_bridge.py');
      await bridge.parent.create(recursive: true);
      await bridge.writeAsString(
        await rootBundle.loadString('assets/hid_bridge.py'),
      );
      if (_disposed) return;
      final ready = Completer<void>();
      final process = await Process.start('python3', ['-u', bridge.path]);
      if (_disposed) {
        process.kill();
        return;
      }
      _process = process;
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_disposed || !identical(_process, process)) return;
              final msg = jsonDecode(line) as Map<String, dynamic>;
              if (msg['ready'] == true && !ready.isCompleted) ready.complete();
              if (msg['error'] != null) {
                final error = StateError(msg['error']);
                if (!ready.isCompleted) {
                  ready.completeError(error);
                } else {
                  _lost(error.toString());
                }
              }
              if (msg['packet'] is List) {
                _receive(List<int>.from(msg['packet']));
              }
            },
            onError: (Object e) {
              if (identical(_process, process)) _lost(e.toString());
            },
          );
      process.stderr.drain<void>();
      unawaited(
        process.exitCode.then((_) {
          if (!ready.isCompleted) {
            ready.completeError(StateError('Device bridge stopped.'));
          }
          if (identical(_process, process)) _lost('Device disconnected');
        }),
      );
      await ready.future.timeout(const Duration(seconds: 4));
      final info = await request(2);
      if (info[4] != 3) {
        throw StateError(
          'Firmware update required: install the new NovaKey protocol 3 UF2.',
        );
      }
      if (_disposed || !identical(_process, process)) return;
      connected = true;
      status = 'NovaKey • protocol 3';
      _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
        if (connected) {
          unawaited(
            request(1).catchError((Object e) {
              if (identical(_process, process)) _lost(e.toString());
              return <int>[];
            }),
          );
        }
      });
    } catch (e) {
      _lost(e.toString());
    }
    connecting = false;
    if (!_disposed) notifyListeners();
  }

  void _receive(List<int> p) {
    if (p.length != 32 || p[0] != 78 || p[1] != 75) return;
    if (p[2] == 64) {
      if (p[4] < protocolControlIds.length) {
        final repeat = p[6].clamp(1, 4);
        for (var i = 0; i < repeat; i++) {
          events.add(DeviceEvent(protocolControlIds[p[4]], p[5] == 1));
          if (p[5] == 1 && repeat > 1) {
            events.add(DeviceEvent(protocolControlIds[p[4]], false));
          }
        }
      }
    } else if (p[2] == _command && _reply != null && !_reply!.isCompleted) {
      if (p[3] != 0) {
        _reply!.completeError(
          StateError('Device rejected command ${p[2]} (status ${p[3]}).'),
        );
      } else {
        _reply!.complete(p);
      }
    }
  }

  Future<List<int>> request(int command, [List<int> payload = const []]) {
    final result = Completer<List<int>>();
    final process = _process;
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        if (_disposed || process == null || !identical(_process, process)) {
          throw StateError('Device connection changed.');
        }
        final packet = List<int>.filled(32, 0);
        packet[0] = 78;
        packet[1] = 75;
        packet[2] = command;
        packet.setRange(4, 4 + payload.length, payload);
        _command = command;
        _reply = Completer<List<int>>();
        process.stdin.writeln(jsonEncode({'packet': packet}));
        await process.stdin.flush();
        final reply = await _reply!.future.timeout(const Duration(seconds: 2));
        result.complete(reply);
      } catch (e, st) {
        result.completeError(e, st);
        if (process != null && identical(_process, process)) {
          _lost('HID request failed: $e');
        }
      } finally {
        _reply = null;
        _command = null;
      }
    });
    return result.future;
  }

  Future<void> capture(bool enabled) async {
    final process = _process;
    await request(0x10, [enabled ? 1 : 0]);
    if (_disposed || !identical(_process, process)) return;
    running = enabled;
    notifyListeners();
  }

  Future<void> output(int key, int mods, bool down) async {
    await request(0x11, [key, mods, down ? 1 : 0]);
  }

  Future<void> release() async {
    if (connected) await request(0x12);
  }

  Future<void> enterBootloader() async {
    await release();
    await request(0x30, const [0x42, 0x4f, 0x4f, 0x54]);
  }

  Future<int> animationMode() async {
    final reply = await request(0x31, const [0xff]);
    return reply[4];
  }

  Future<void> setAnimationMode(int mode) async {
    if (mode < 0 || mode >= 11) throw RangeError.range(mode, 0, 10, 'mode');
    await request(0x31, [mode]);
  }

  Future<void> upload(Map<String, ControlBinding> bindings) async {
    await request(0x20);
    for (var i = 0; i < protocolControlIds.length; i++) {
      final b = bindings[protocolControlIds[i]] ?? unassigned;
      await request(0x21, [
        i,
        b.onboard ? b.keyCode : 0,
        b.onboard ? b.modifiers : 0,
      ]);
    }
    await request(0x22);
  }

  void _lost(String message) {
    if (_disposed) return;
    _heartbeat?.cancel();
    _heartbeat = null;
    connected = false;
    running = false;
    status = message;
    final p = _process;
    _process = null;
    p?.kill();
    if (_reply != null && !_reply!.isCompleted) {
      _reply!.completeError(StateError(message));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _heartbeat?.cancel();
    _process?.kill();
    events.close();
    super.dispose();
  }
}
