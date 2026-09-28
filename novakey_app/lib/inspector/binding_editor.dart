import 'package:flutter/material.dart';

import '../models/control_binding.dart';
import '../data/preset_bindings.dart';
import 'shortcut_recorder.dart';
import 'activation_mode_picker.dart';
import 'step_dialog.dart';

Future<ControlBinding?> editBinding(
  BuildContext context,
  String title,
  ControlBinding initial,
) => showDialog<ControlBinding>(
  context: context,
  builder: (_) => BindingEditor(title: title, initial: initial),
);

class BindingEditor extends StatefulWidget {
  const BindingEditor({super.key, required this.title, required this.initial});
  final String title;
  final ControlBinding initial;
  @override
  State<BindingEditor> createState() => _BindingEditorState();
}

class _BindingEditorState extends State<BindingEditor> {
  late ControlBinding binding;
  late TextEditingController name, target;
  String query = '';
  @override
  void initState() {
    super.initState();
    binding = widget.initial;
    name = TextEditingController(
      text: binding.kind == ActionKind.none ? '' : binding.name,
    );
    target = TextEditingController(
      text: binding.kind == ActionKind.system ? binding.detail : '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    super.dispose();
  }

  void update(ControlBinding b) {
    setState(() {
      binding = b.copyWith(activationMode: binding.activationMode);
      name.text = b.name;
    });
  }

  Future<void> step([int? index]) async {
    final result = await editStep(
      context,
      initial: index == null ? null : binding.steps[index],
    );
    if (result == null || !mounted) return;
    final list = [...binding.steps];
    if (index == null) {
      list.add(result);
    } else {
      list[index] = result;
    }
    setState(() => binding = binding.copyWith(steps: list));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Expanded(child: Text(widget.title)),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: SizedBox(
      width: 620,
      height: 540,
      child: ListView(
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Action name',
              hintText: 'e.g. Brush size, Save reference, Export preview',
            ),
          ),
          const SizedBox(height: 18),
          if (binding.kind != ActionKind.hud)
            ActivationModePicker(
              value: binding.activationMode,
              onChanged: (mode) => setState(
                () => binding = binding.copyWith(activationMode: mode),
              ),
            ),
          const SizedBox(height: 18),
          SegmentedButton<ActionKind>(
            segments: const [
              ButtonSegment(
                value: ActionKind.shortcut,
                label: Text('Shortcut'),
              ),
              ButtonSegment(
                value: ActionKind.sequence,
                label: Text('Sequence'),
              ),
              ButtonSegment(
                value: ActionKind.system,
                label: Text('File / URL'),
              ),
              ButtonSegment(value: ActionKind.hud, label: Text('HUD')),
            ],
            selected: {
              binding.kind == ActionKind.none
                  ? ActionKind.shortcut
                  : binding.kind,
            },
            onSelectionChanged: (v) => setState(
              () => binding = binding.copyWith(
                kind: v.first,
                activationMode: v.first == ActionKind.hud
                    ? ActivationMode.immediate
                    : binding.activationMode,
                detail: v.first == ActionKind.hud ? 'peek' : binding.detail,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (binding.kind == ActionKind.shortcut ||
              binding.kind == ActionKind.none) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final b = await recordShortcut(
                  context,
                  initial: binding.kind == ActionKind.shortcut ? binding : null,
                );
                if (b != null && mounted) {
                  final n = name.text;
                  update(b);
                  if (n.isNotEmpty) name.text = n;
                }
              },
              icon: const Icon(Icons.keyboard_outlined),
              label: Text(
                binding.kind == ActionKind.shortcut
                    ? binding.detail
                    : 'Record custom shortcut',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Find an artist shortcut',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            const Text(
              'Starting points — shortcuts vary by application.',
              style: TextStyle(fontSize: 12),
            ),
            for (final preset in presetBindings.where(
              (p) => p.name.toLowerCase().contains(query),
            ))
              ListTile(
                dense: true,
                title: Text(preset.name),
                trailing: Text(preset.detail),
                onTap: () => update(preset),
              ),
          ],
          if (binding.kind == ActionKind.hud) ...[
            DropdownButtonFormField<String>(
              initialValue: binding.detail == 'toggle' ? 'toggle' : 'peek',
              decoration: const InputDecoration(labelText: 'Bindings HUD'),
              items: const [
                DropdownMenuItem(value: 'peek', child: Text('Hold to peek')),
                DropdownMenuItem(value: 'toggle', child: Text('Toggle HUD')),
              ],
              onChanged: (value) =>
                  setState(() => binding = binding.copyWith(detail: value)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Shows the active profile above your application. Hold to peek dismisses on release. Toggle is useful for encoder turns. Requires Studio on KDE Linux.',
            ),
          ],
          if (binding.kind == ActionKind.system) ...[
            TextField(
              controller: target,
              decoration: const InputDecoration(
                labelText: 'Absolute file path or https:// URL',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Opens with your desktop’s default application. Requires Studio running.',
            ),
          ],
          if (binding.kind == ActionKind.sequence) ...[
            const Text('Actions run in order. Requires Studio running.'),
            const SizedBox(height: 10),
            for (var i = 0; i < binding.steps.length; i++)
              ListTile(
                leading: Text('${i + 1}'),
                title: Text(binding.steps[i].title),
                subtitle: Text(
                  binding.steps[i].detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => step(i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: i == 0
                          ? null
                          : () => setState(() {
                              final list = [...binding.steps];
                              final s = list.removeAt(i);
                              list.insert(i - 1, s);
                              binding = binding.copyWith(steps: list);
                            }),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Remove step',
                      onPressed: () => setState(() {
                        final list = [...binding.steps]..removeAt(i);
                        binding = binding.copyWith(steps: list);
                      }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: binding.steps.length >= 128 ? null : () => step(),
              icon: const Icon(Icons.add),
              label: const Text('Add action'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, unassigned),
        child: const Text('Clear assignment'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            binding.kind == ActionKind.none ||
                (binding.kind == ActionKind.sequence && binding.steps.isEmpty)
            ? null
            : () {
                if (binding.kind == ActionKind.system &&
                    target.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  binding.copyWith(
                    name: name.text.trim().isEmpty
                        ? (binding.kind == ActionKind.hud
                              ? 'Bindings HUD'
                              : 'Custom action')
                        : name.text.trim(),
                    detail: binding.kind == ActionKind.system
                        ? target.text.trim()
                        : binding.kind == ActionKind.sequence
                        ? '${binding.steps.length} actions'
                        : binding.detail,
                  ),
                );
              },
        child: const Text('Save assignment'),
      ),
    ],
  );
}
