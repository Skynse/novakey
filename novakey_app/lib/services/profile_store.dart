import 'dart:convert';
import 'dart:io';

import '../models/profile.dart';
import '../models/control_binding.dart';
import '../device/device_layout.dart';

class ProfileStore {
  static String get directory =>
      '${Platform.environment['XDG_CONFIG_HOME'] ?? '${Platform.environment['HOME']}/.config'}/novakey';
  final File file = File('$directory/profiles.json');
  Future<Map<String, dynamic>?> load() async {
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final oldVersion = data['version'];
    migrate(data);
    validate(data);
    if (oldVersion != data['version']) {
      final backup = File('${file.path}.before-firmware-orientation-v4');
      if (!await backup.exists()) await file.copy(backup.path);
      await save(data);
    }
    return data;
  }

  static void migrate(Map<String, dynamic> data) {
    if (data['version'] == 4) return;
    // Version 3 was already stored in canonical order during the UI changes.
    if (data['version'] == 3) {
      data['version'] = 4;
      return;
    }
    if (data['version'] == 2) {
      _canonicalKeys(data);
      return;
    }
    if (data['version'] != 1) return;
    for (final raw in (data['profiles'] as List? ?? [])) {
      final profile = raw as Map<String, dynamic>;
      final bindings = Map<String, dynamic>.from(
        profile['bindings'] as Map? ?? {},
      );
      profile['bindings'] = {
        for (final entry in bindings.entries)
          _rotatedId(entry.key): entry.value,
      };
      for (final rawCombo in (profile['combinations'] as List? ?? [])) {
        final combo = rawCombo as Map<String, dynamic>;
        combo['held'] = _rotatedId(combo['held'] as String);
        combo['trigger'] = _rotatedId(combo['trigger'] as String);
      }
    }
    data['version'] = 2;
    _canonicalKeys(data);
  }

  // Firmware protocol 3 owns canonical orientation; migrate legacy profiles once.
  static void _canonicalKeys(Map<String, dynamic> data) {
    String keyId(String id) {
      final match = RegExp(r'^key-(\d{2})$').firstMatch(id);
      if (match == null) return id;
      return 'key-${(17 - int.parse(match.group(1)!)).toString().padLeft(2, '0')}';
    }

    for (final profile in data['profiles'] as List) {
      final bindings = profile['bindings'] as Map? ?? {};
      profile['bindings'] = {
        for (final entry in bindings.entries)
          keyId(entry.key as String): entry.value,
      };
      for (final combo in profile['combinations'] as List? ?? []) {
        combo['held'] = keyId(combo['held'] as String);
        combo['trigger'] = keyId(combo['trigger'] as String);
      }
    }
    data['version'] = 4;
  }

  static String _rotatedId(String id) {
    final key = RegExp(r'^key-(\d+)$').firstMatch(id);
    if (key != null) {
      final number = 17 - int.parse(key.group(1)!);
      return 'key-${number.toString().padLeft(2, '0')}';
    }
    final encoder = RegExp(r'^enc-(\d+)-(ccw|cw|press)$').firstMatch(id);
    if (encoder == null) return id;
    final direction = encoder.group(2) == 'ccw'
        ? 'cw'
        : encoder.group(2) == 'cw'
        ? 'ccw'
        : 'press';
    return 'enc-${encoder.group(1)}-$direction';
  }

  static void validate(Map<String, dynamic> data) {
    if (data['version'] != 4 ||
        data['profiles'] is! List ||
        (data['profiles'] as List).isEmpty) {
      throw const FormatException(
        'This is not a NovaKey profile export (supported versions: 1–4).',
      );
    }
    final ids = <String>{};
    final controlsById = {for (final c in controls) c.id: c};
    for (final raw in data['profiles']) {
      final p = Profile.fromJson(Map<String, dynamic>.from(raw));
      if (p.name.trim().isEmpty || !ids.add(p.id)) {
        throw const FormatException('Invalid or duplicate profile.');
      }
      for (final e in p.bindings.entries) {
        if (!controlsById.containsKey(e.key)) {
          throw const FormatException('Unknown control.');
        }
        checkBinding(e.value);
      }
      final pairs = <String>{};
      for (final c in p.combinations) {
        final held = controlsById[c.held];
        if (held == null ||
            !controlsById.containsKey(c.trigger) ||
            c.held == c.trigger ||
            (held.type != ControlType.key &&
                held.type != ControlType.encoderPress) ||
            !pairs.add('${c.held}:${c.trigger}')) {
          throw const FormatException('Invalid combination.');
        }
        checkBinding(c.binding);
      }
    }
  }

  static void checkBinding(ControlBinding b) {
    if (b.kind == ActionKind.hud &&
        (!['peek', 'toggle'].contains(b.detail) ||
            b.activationMode != ActivationMode.immediate)) {
      throw const FormatException('Invalid HUD action.');
    }
    if (b.keyCode < 0 ||
        b.keyCode > 255 ||
        b.modifiers < 0 ||
        b.modifiers > 15 ||
        b.steps.length > 128) {
      throw const FormatException('Invalid shortcut or sequence.');
    }
    for (final s in b.steps) {
      if (!['Shortcut', 'Wait', 'Type text', 'Open'].contains(s.title)) {
        throw const FormatException('Unknown sequence action.');
      }
      if (s.keyCode < 0 ||
          s.keyCode > 255 ||
          s.modifiers < 0 ||
          s.modifiers > 15) {
        throw const FormatException('Invalid shortcut.');
      }
      if (s.title == 'Wait' &&
          (int.tryParse(s.detail) == null ||
              int.parse(s.detail) < 0 ||
              int.parse(s.detail) > 60000)) {
        throw const FormatException('Delay must be 0–60000 ms.');
      }
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    validate(data);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
