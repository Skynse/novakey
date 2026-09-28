import 'package:flutter/material.dart';

enum ControlType {
  key,
  encoderPress,
  encoderCounterClockwise,
  encoderClockwise,
}

enum ActivationMode { immediate, onRelease, repeat }

enum ActionKind { shortcut, sequence, appCommand, system, layer, hud, none }

class ControlSpec {
  const ControlSpec({
    required this.id,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final String id, label;
  final ControlType type;
  final double x, y, width, height;
}

class MacroStep {
  const MacroStep(
    this.icon,
    this.title,
    this.detail, {
    this.keyCode = 0,
    this.modifiers = 0,
  });
  final IconData icon;
  final String title, detail;
  final int keyCode, modifiers;
  Map<String, dynamic> toJson() => {
    'type': title,
    'value': detail,
    'key': keyCode,
    'mods': modifiers,
  };
  factory MacroStep.fromJson(Map<String, dynamic> j) => MacroStep(
    stepIcon(j['type'] as String),
    j['type'] as String,
    j['value'] as String,
    keyCode: j['key'] as int? ?? 0,
    modifiers: j['mods'] as int? ?? 0,
  );
  static IconData stepIcon(String type) => switch (type) {
    'Wait' => Icons.timer_outlined,
    'Type text' => Icons.text_fields,
    'Open' => Icons.open_in_new,
    _ => Icons.keyboard_outlined,
  };
}

class ControlBinding {
  const ControlBinding({
    required this.kind,
    required this.name,
    required this.detail,
    this.keyCode = 0,
    this.modifiers = 0,
    this.steps = const [],
    this.activationMode = ActivationMode.immediate,
  });
  final ActionKind kind;
  final String name, detail;
  final int keyCode, modifiers;
  final List<MacroStep> steps;
  final ActivationMode activationMode;
  bool get onboard =>
      activationMode == ActivationMode.immediate &&
      (kind == ActionKind.shortcut || kind == ActionKind.none);
  ControlBinding copyWith({
    ActionKind? kind,
    String? name,
    String? detail,
    int? keyCode,
    int? modifiers,
    List<MacroStep>? steps,
    ActivationMode? activationMode,
  }) => ControlBinding(
    kind: kind ?? this.kind,
    name: name ?? this.name,
    detail: detail ?? this.detail,
    keyCode: keyCode ?? this.keyCode,
    modifiers: modifiers ?? this.modifiers,
    steps: steps ?? this.steps,
    activationMode: activationMode ?? this.activationMode,
  );
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'activationMode': activationMode.name,
    'name': name,
    'detail': detail,
    'key': keyCode,
    'mods': modifiers,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  factory ControlBinding.fromJson(Map<String, dynamic> j) => ControlBinding(
    activationMode: ActivationMode.values.byName(
      j['activationMode'] as String? ?? 'immediate',
    ),
    kind: ActionKind.values.byName(j['kind'] as String),
    name: j['name'] as String,
    detail: j['detail'] as String,
    keyCode: j['key'] as int? ?? 0,
    modifiers: j['mods'] as int? ?? 0,
    steps: (j['steps'] as List? ?? [])
        .map((e) => MacroStep.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

const unassigned = ControlBinding(
  kind: ActionKind.none,
  name: 'Unassigned',
  detail: '',
);
