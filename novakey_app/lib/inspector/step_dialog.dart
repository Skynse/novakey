import 'package:flutter/material.dart';

import '../models/control_binding.dart';
import 'shortcut_recorder.dart';
import '../services/action_runner.dart';

Future<MacroStep?> editStep(BuildContext context, {MacroStep? initial}) =>
    showDialog<MacroStep>(
      context: context,
      builder: (_) => StepDialog(initial: initial),
    );

class StepDialog extends StatefulWidget {
  const StepDialog({super.key, this.initial});
  final MacroStep? initial;
  @override
  State<StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<StepDialog> {
  late String type;
  late TextEditingController value;
  late int key, mods;
  String? error;
  @override
  void initState() {
    super.initState();
    type = widget.initial?.title ?? 'Shortcut';
    value = TextEditingController(text: widget.initial?.detail ?? '');
    key = widget.initial?.keyCode ?? 0;
    mods = widget.initial?.modifiers ?? 0;
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  void save() {
    if (type == 'Shortcut' && key == 0 && mods == 0) {
      setState(() => error = 'Record a shortcut.');
      return;
    }
    if (type == 'Wait' &&
        (int.tryParse(value.text) == null ||
            int.parse(value.text) < 0 ||
            int.parse(value.text) > 60000)) {
      setState(() => error = 'Enter a delay between 0 and 60000 ms.');
      return;
    }
    if ((type == 'Open' || type == 'Type text') && value.text.isEmpty) {
      setState(() => error = 'Enter a value.');
      return;
    }
    if (type == 'Type text') {
      try {
        value.text.runes.forEach(ActionRunner.asciiUsage);
      } catch (e) {
        setState(() => error = e.toString());
        return;
      }
    }
    Navigator.pop(
      context,
      MacroStep(
        MacroStep.stepIcon(type),
        type,
        type == 'Shortcut' ? shortcutLabel(key, mods) : value.text,
        keyCode: key,
        modifiers: mods,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add action' : 'Edit action'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            items: [
              for (final t in ['Shortcut', 'Wait', 'Type text', 'Open'])
                DropdownMenuItem(
                  value: t,
                  child: Text(t == 'Open' ? 'Open file or URL' : t),
                ),
            ],
            onChanged: (t) => setState(() {
              type = t!;
              error = null;
              value.clear();
            }),
          ),
          const SizedBox(height: 16),
          if (type == 'Shortcut')
            OutlinedButton(
              onPressed: () async {
                final b = await recordShortcut(context);
                if (b != null && mounted) {
                  setState(() {
                    key = b.keyCode;
                    mods = b.modifiers;
                  });
                }
              },
              child: Text(shortcutLabel(key, mods)),
            )
          else
            TextField(
              controller: value,
              maxLines: type == 'Type text' ? 4 : 1,
              decoration: InputDecoration(
                labelText: type == 'Wait'
                    ? 'Milliseconds'
                    : type == 'Open'
                    ? 'Absolute file path or https:// URL'
                    : 'Text (US keyboard layout)',
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save action')),
    ],
  );
}
