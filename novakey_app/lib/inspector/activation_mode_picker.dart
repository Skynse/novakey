import 'package:flutter/material.dart';

import '../models/control_binding.dart';

class ActivationModePicker extends StatelessWidget {
  const ActivationModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ActivationMode value;
  final ValueChanged<ActivationMode> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<ActivationMode>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Activation'),
        items: const [
          DropdownMenuItem(
            value: ActivationMode.immediate,
            child: Text('Immediate / hold'),
          ),
          DropdownMenuItem(
            value: ActivationMode.onRelease,
            child: Text('On release (UP)'),
          ),
          DropdownMenuItem(
            value: ActivationMode.repeat,
            child: Text('Repeat while held (REP)'),
          ),
        ],
        onChanged: (mode) {
          if (mode != null) onChanged(mode);
        },
      ),
      const SizedBox(height: 8),
      Text(switch (value) {
        ActivationMode.immediate => 'Starts immediately. Shortcuts stay held until release. Use for Pan or Rotate Canvas.',
        ActivationMode.onRelease => 'Fires on release unless consumed by a combination. Requires Studio running.',
        ActivationMode.repeat => 'Fires immediately, repeats after 350 ms, then every 100 ms after completion. Requires Studio running.',
      }, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
