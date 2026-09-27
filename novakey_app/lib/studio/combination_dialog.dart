import 'package:flutter/material.dart';

import '../device/device_layout.dart';
import '../models/control_binding.dart';

Future<(String, String)?> chooseCombination(BuildContext context) =>
    showDialog<(String, String)>(
      context: context,
      builder: (_) => const CombinationDialog(),
    );

class CombinationDialog extends StatefulWidget {
  const CombinationDialog({super.key});
  @override
  State<CombinationDialog> createState() => _CombinationDialogState();
}

class _CombinationDialogState extends State<CombinationDialog> {
  String held = 'key-16', trigger = 'enc-1-cw';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create a combination'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hold one control, then press or turn another. The held control’s own action fires on release only if no combination was used.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: held,
            decoration: const InputDecoration(labelText: 'While holding'),
            items: [
              for (final c in controls.where(
                (c) =>
                    c.type == ControlType.key ||
                    c.type == ControlType.encoderPress,
              ))
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => held = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: trigger,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Press or turn'),
            items: [
              for (final c in controls)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => trigger = v!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: held == trigger
            ? null
            : () => Navigator.pop(context, (held, trigger)),
        child: const Text('Choose action'),
      ),
    ],
  );
}
