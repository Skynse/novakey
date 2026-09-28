import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/preset_bindings.dart';
import '../models/profile.dart';
import '../models/control_binding.dart';
import 'profile_store.dart';
import 'device_service.dart';
import 'action_runner.dart';
import 'application_monitor.dart';

class StudioController extends ChangeNotifier {
  StudioController() {
    runner = ActionRunner(device, onError: report);
    device.addListener(_deviceChanged);
    _events = device.events.stream.listen((e) {
      lastControl = e.id;
      if (e.pressed) {
        selected = e.id;
        notifyListeners();
      }
      runner.event(e);
    });
  }
  final store = ProfileStore();
  final monitor = ApplicationMonitor();
  bool autoSwitch = false;
  bool saveFailed = false;
  final device = DeviceService();
  late final ActionRunner runner;
  late final StreamSubscription<DeviceEvent> _events;
  List<Profile> profiles = [];
  String activeId = '', selected = 'key-01', message = '', lastControl = '';
  bool loading = true, learn = false, saving = false;
  bool _loadFailed = false;
  Future<void> _writes = Future.value();
  Profile get active => profiles.firstWhere(
    (p) => p.id == activeId,
    orElse: () => profiles.first,
  );
  ControlBinding get binding => active.bindings[selected] ?? unassigned;
  void report(String text) {
    message = text;
    notifyListeners();
  }

  void _deviceChanged() {
    if (!device.connected) {
      unawaited(runner.stop());
    } else if (!device.running) {
      unawaited(device.capture(true).catchError((_) {}));
    }
    notifyListeners();
  }

  Map<String, dynamic> get document => {
    'version': 4,
    'active': activeId,
    'autoSwitch': autoSwitch,
    'profiles': profiles.map((p) => p.toJson()).toList(),
  };
  Future<void> initialize() async {
    var restoreAutoSwitch = false;
    try {
      final doc = await store.load();
      if (doc != null) {
        profiles = (doc['profiles'] as List)
            .map((p) => Profile.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        activeId = doc['active'] as String? ?? '';
        restoreAutoSwitch = doc['autoSwitch'] == true;
      }
    } catch (e) {
      _loadFailed = true;
      message =
          'Could not load profiles; existing file will not be overwritten: $e';
    }
    if (profiles.isEmpty) {
      profiles = [
        Profile(
          id: 'illustration',
          name: 'Illustration',
          bindings: {
            'key-01': presetBindings[0],
            'key-02': presetBindings[1],
            'key-03': presetBindings[4],
            'key-04': presetBindings[5],
            'key-05': presetBindings[6],
            'key-06': presetBindings[8],
            'enc-1-ccw': presetBindings[3],
            'enc-1-cw': presetBindings[2],
          },
        ),
        Profile(id: 'sculpting', name: 'Sculpting'),
      ];
    }
    if (!profiles.any((p) => p.id == activeId)) activeId = profiles.first.id;
    runner.profile = active;
    loading = false;
    notifyListeners();
    if (restoreAutoSwitch && ApplicationMonitor.supported) {
      await toggleAutoSwitch(true);
    }
  }

  Future<void> persist() {
    if (_loadFailed) {
      report(
        'Resolve or move the invalid profiles file before saving. Export your changes to a different file.',
      );
      return Future.value();
    }
    final snapshot = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
    saving = true;
    saveFailed = false;
    notifyListeners();
    _writes = _writes
        .catchError((_) {})
        .then((_) => store.save(snapshot))
        .catchError((Object e) {
          saveFailed = true;
          report('Save failed: $e');
        })
        .whenComplete(() {
          saving = false;
          notifyListeners();
        });
    return _writes;
  }

  void select(String id) {
    selected = id;
    notifyListeners();
  }

  Future<void> selectProfile(String id) async {
    await runner.stop();
    activeId = id;
    runner.profile = active;
    notifyListeners();
    await persist();
  }

  void assign(ControlBinding value) {
    if (value.kind == ActionKind.none) {
      active.bindings.remove(selected);
    } else {
      active.bindings[selected] = value;
    }
    unawaited(runner.stop());
    notifyListeners();
    unawaited(persist());
    if (device.connected) {
      unawaited(
        device.upload(active.bindings).catchError((e) {
          report('Automatic onboard sync failed: $e');
        }),
      );
    }
  }

  bool switchingIntegration = false;
  String focusedApplication = '';
  final List<FocusedApplication> recentApplications = [];
  FocusedApplication? _focused;
  Timer? _pendingFocus;
  Future<void> toggleAutoSwitch(bool enabled) async {
    if (switchingIntegration) return;
    switchingIntegration = true;
    notifyListeners();
    try {
      if (enabled) {
        await monitor.start((window) {
          if (window.id.isEmpty || window.matches('org.novakey.Studio')) return;
          focusedApplication = window.id;
          _focused = window;
          recentApplications.removeWhere((app) => app.id == window.id);
          recentApplications.insert(0, window);
          if (recentApplications.length > 20) recentApplications.removeLast();
          notifyListeners();
          _applyFocusedProfile();
        });
        autoSwitch = true;
      } else {
        _pendingFocus?.cancel();
        _focused = null;
        await monitor.stop();
        autoSwitch = false;
      }
    } catch (e) {
      autoSwitch = false;
      report('KDE integration: $e');
    }
    switchingIntegration = false;
    notifyListeners();
    await persist();
  }

  void _applyFocusedProfile() {
    _pendingFocus?.cancel();
    if (_focused == null) return;
    if (learn || runner.busy) {
      _pendingFocus = Timer(
        const Duration(milliseconds: 150),
        _applyFocusedProfile,
      );
      return;
    }
    for (final p in profiles) {
      if (_focused!.matches(p.application) && p.id != activeId) {
        unawaited(selectProfile(p.id));
        break;
      }
    }
  }

  Future<void> addProfile(String name, {bool duplicate = false}) async {
    final p = duplicate
        ? Profile.fromJson({
            ...active.toJson(),
            'id': '${DateTime.now().microsecondsSinceEpoch}',
            'name': name,
          })
        : Profile(id: '${DateTime.now().microsecondsSinceEpoch}', name: name);
    profiles.add(p);
    await selectProfile(p.id);
  }

  Future<void> deleteProfile() async {
    if (profiles.length == 1) return;
    await runner.stop();
    profiles.remove(active);
    activeId = profiles.first.id;
    runner.profile = active;
    notifyListeners();
    await persist();
  }

  Future<void> toggleRuntime() async {
    if (!device.connected) await device.connect();
  }

  Future<void> toggleLearn() async {
    learn = false;
    notifyListeners();
  }

  Future<void> upload() async {
    try {
      await runner.stop();
      await device.upload(active.bindings);
      final skipped = active.bindings.values.where((b) => !b.onboard).length;
      report(
        'Onboard profile saved. $skipped app actions and ${active.combinations.length} combinations require Studio running.',
      );
    } catch (e) {
      report('Device save failed: $e');
    }
  }

  Future<void> exportTo(String path) async {
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(document));
    report('Exported profiles to $path');
  }

  Future<void> importFrom(String path) async {
    final doc =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    ProfileStore.migrate(doc);
    ProfileStore.validate(doc);
    final imported = (doc['profiles'] as List)
        .map((p) => Profile.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    for (final p in imported) {
      profiles.add(
        Profile.fromJson({
          ...p.toJson(),
          'id': 'import-${DateTime.now().microsecondsSinceEpoch}-${p.id}',
        }),
      );
    }
    await persist();
    report('Imported ${imported.length} profiles.');
  }

  @override
  void dispose() {
    _pendingFocus?.cancel();
    unawaited(monitor.stop().catchError((_) {}));
    device.removeListener(_deviceChanged);
    _events.cancel();
    device.dispose();
    super.dispose();
  }
}
