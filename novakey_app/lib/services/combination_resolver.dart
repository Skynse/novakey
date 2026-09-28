import 'dart:async';

import '../models/control_binding.dart';
import '../models/profile.dart';

/// Activates controls immediately and replaces their holds when a combo forms.
class CombinationResolver {
  CombinationResolver({
    required this.onDown,
    required this.onUp,
    required this.onTap,
  });

  final void Function(ControlBinding) onDown, onUp;
  final Future<void> Function(ControlBinding, bool Function()) onTap;
  final Set<String> _pressed = {};
  final Map<String, _Activation> _active = {};
  bool get busy => _pressed.isNotEmpty;

  void press(String id, ControlBinding binding, List<Combination> combos) {
    if (!_pressed.add(id)) return;
    for (final combo in combos.reversed) {
      final other = combo.held == id
          ? combo.trigger
          : combo.trigger == id
          ? combo.held
          : null;
      if (other == null || !_pressed.contains(other)) continue;
      // Release the previous shortcut before sending the combo's shortcut.
      // Actions already executed on the first press cannot be undone here.
      _end(other);
      _activate(combo.binding, {id, other});
      return;
    }
    _activate(binding, {id});
  }

  void _activate(ControlBinding binding, Set<String> members) {
    final activation = _Activation(binding, members);
    for (final member in members) {
      _active[member] = activation;
    }
    switch (binding.activationMode) {
      case ActivationMode.immediate:
        onDown(binding);
      case ActivationMode.onRelease:
        break;
      case ActivationMode.repeat:
        unawaited(_repeat(activation));
    }
  }

  void release(String id) {
    if (!_pressed.remove(id)) return;
    _end(id, released: true);
  }

  void _end(String id, {bool released = false}) {
    final activation = _active.remove(id);
    if (activation == null) return;
    // End a combo on either release. The other key stays consumed until lifted,
    // but can still participate in another combo or repeated encoder ticks.
    for (final member in activation.members) {
      _active.remove(member);
    }
    activation.live = false;
    activation.timer?.cancel();
    switch (activation.binding.activationMode) {
      case ActivationMode.immediate:
        onUp(activation.binding);
      case ActivationMode.onRelease:
        if (released) unawaited(onTap(activation.binding, () => true));
      case ActivationMode.repeat:
        break;
    }
  }

  Future<void> _repeat(_Activation activation, {bool first = true}) async {
    // Serialize each pulse before scheduling another, avoiding a macro backlog.
    await onTap(activation.binding, first ? () => true : () => activation.live);
    if (!activation.live) return;
    activation.timer = Timer(
      Duration(milliseconds: first ? 350 : 100),
      () => unawaited(_repeat(activation, first: false)),
    );
  }

  void reset() {
    for (final activation in _active.values.toSet()) {
      activation.live = false;
      activation.timer?.cancel();
    }
    _pressed.clear();
    _active.clear();
  }
}

class _Activation {
  _Activation(this.binding, this.members);
  final ControlBinding binding;
  final Set<String> members;
  bool live = true;
  Timer? timer;
}
