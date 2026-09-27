import 'dart:async';
import 'dart:io';

import '../models/control_binding.dart';
import '../models/profile.dart';
import 'device_service.dart';

/// Resolves held-control combinations and serializes macro execution.
class ActionRunner {
  ActionRunner(this.device, {required this.onError});
  final DeviceService device;
  final void Function(String) onError;
  Profile? profile;
  final Set<String> _pressed = {};
  final Set<String> _usedAsModifier = {};
  final Map<String, ControlBinding> _active = {};
  Future<void> _work = Future.value();
  int _generation = 0, _pending = 0;
  Completer<void> _cancel = Completer<void>();
  bool get busy => _pending > 0 || _pressed.isNotEmpty;
  void event(DeviceEvent event) {
    if (!device.running || profile == null) return;
    final p = profile!;
    if (event.pressed) {
      if (!_pressed.add(event.id)) return;
      ControlBinding? binding;
      for (final combo in p.combinations.reversed) {
        if (combo.trigger == event.id && _pressed.contains(combo.held)) {
          binding = combo.binding;
          _usedAsModifier.add(combo.held);
          break;
        }
      }
      final isModifier = p.combinations.any((c) => c.held == event.id);
      if (binding == null && isModifier) {
        return; // Tap executes on release; hold modifies other controls.
      }
      binding ??= p.bindings[event.id] ?? unassigned;
      _active[event.id] = binding;
      if (binding.kind == ActionKind.shortcut) {
        final b = binding;
        _hold(b, true);
      } else {
        _enqueue(() => _execute(binding!));
      }
    } else {
      _pressed.remove(event.id);
      final active = _active.remove(event.id);
      if (active?.kind == ActionKind.shortcut) {
        _hold(active!, false);
      } else if (active == null &&
          p.combinations.any((c) => c.held == event.id)) {
        if (!_usedAsModifier.remove(event.id)) {
          _enqueue(() => _execute(p.bindings[event.id] ?? unassigned));
        }
      }
    }
  }

  void _hold(ControlBinding b, bool down) {
    unawaited(
      device.output(b.keyCode, b.modifiers, down).catchError((Object e) {
        onError(e.toString());
        unawaited(stop());
      }),
    );
  }

  void _enqueue(Future<void> Function() action) {
    final generation = _generation;
    if (_pending >= 128) {
      onError('Action queue full. Stop playback to clear it.');
      unawaited(stop());
      return;
    }
    _pending++;
    _work = _work
        .then((_) async {
          if (generation == _generation) await action();
        })
        .catchError((Object e) async {
          onError(e.toString());
          await stop();
        })
        .whenComplete(() => _pending--);
  }

  Future<void> preview(ControlBinding b) async {
    final generation = _generation;
    await Future<void>.delayed(const Duration(seconds: 3));
    if (generation == _generation) _enqueue(() => _execute(b));
  }

  Future<void> _tap(int key, int mods) async {
    await device.output(key, mods, true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    } finally {
      if (device.connected) await device.output(key, mods, false);
    }
  }

  Future<void> _execute(ControlBinding b) async {
    final generation = _generation;
    switch (b.kind) {
      case ActionKind.none:
        return;
      case ActionKind.shortcut:
        await _tap(b.keyCode, b.modifiers);
        return;
      case ActionKind.system:
        await openTarget(b.detail);
        return;
      case ActionKind.sequence:
        for (final step in b.steps) {
          if (generation != _generation) return;
          switch (step.title) {
            case 'Shortcut':
              await _tap(step.keyCode, step.modifiers);
            case 'Wait':
              await Future.any<void>([
                Future<void>.delayed(
                  Duration(milliseconds: int.parse(step.detail)),
                ),
                _cancel.future,
              ]);
            case 'Open':
              await openTarget(step.detail);
            case 'Type text':
              // Validate first so unsupported text never produces a partial sentence.
              final codes = step.detail.runes.map(asciiUsage).toList();
              for (final code in codes) {
                if (generation != _generation) return;
                await _tap(code.$1, code.$2);
              }
            default:
              throw StateError('Unknown action: ${step.title}');
          }
        }
        return;
      default:
        throw StateError(
          'Unsupported action. Choose a shortcut, sequence, or file/URL.',
        );
    }
  }

  static Future<void> openTarget(String target) async {
    if (target.trim().isEmpty) throw StateError('Choose a file or URL.');
    final uri = Uri.tryParse(target);
    if (uri?.hasScheme == true &&
        !['https', 'http', 'file'].contains(uri!.scheme)) {
      throw StateError('Use an http(s) URL or local file path.');
    }
    final result = await Process.run('xdg-open', [target]);
    if (result.exitCode != 0) {
      throw StateError('Could not open $target: ${result.stderr}');
    }
  }

  Future<void> stop() async {
    _generation++;
    if (!_cancel.isCompleted) _cancel.complete();
    _cancel = Completer<void>();
    _pressed.clear();
    _usedAsModifier.clear();
    _active.clear();
    if (device.connected) {
      try {
        await device.release();
      } catch (_) {}
    }
  }

  static (int, int) asciiUsage(int rune) {
    if (rune >= 97 && rune <= 122) return (4 + rune - 97, 0);
    if (rune >= 65 && rune <= 90) return (4 + rune - 65, 2);
    const plain = '1234567890\n\u001b\b\t -=[]\\;\'`,./';
    const codes = [
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      48,
      49,
      51,
      52,
      53,
      54,
      55,
      56,
    ];
    final i = plain.indexOf(String.fromCharCode(rune));
    if (i >= 0) return (codes[i], 0);
    const shifted = '!@#\$%^&*()_+{}|:"~<>?';
    const shiftCodes = [
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      45,
      46,
      47,
      48,
      49,
      51,
      52,
      53,
      54,
      55,
      56,
    ];
    final j = shifted.indexOf(String.fromCharCode(rune));
    if (j >= 0) return (shiftCodes[j], 2);
    throw StateError('Text typing currently supports US-layout ASCII only.');
  }
}
