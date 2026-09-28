import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../services/device_service.dart';
import '../theme/palette.dart';

const animationNames = [
  'Wave tank',
  'Particle flow field',
  'Reaction-diffusion',
  'Boids',
  'Fluid-like ink',
  'Metaballs',
  'Dithered plasma',
  'Rule 30',
  "Langton's ants",
  'Damped membrane',
  'Display diagnostic',
];

Future<void> showAnimationPicker(BuildContext context, DeviceService device) =>
    showShadDialog<void>(
      context: context,
      builder: (_) => _AnimationDialog(device: device),
    );

class _AnimationDialog extends StatefulWidget {
  const _AnimationDialog({required this.device});
  final DeviceService device;

  @override
  State<_AnimationDialog> createState() => _AnimationDialogState();
}

class _AnimationDialogState extends State<_AnimationDialog> {
  int? selected;
  String status = 'Reading current mode';
  bool busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final mode = await widget.device.animationMode();
      if (!mounted) return;
      setState(() {
        selected = mode;
        status = 'Changes apply immediately.';
        busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = 'Could not read animation mode: $error';
        busy = false;
      });
    }
  }

  Future<void> _select(int mode) async {
    setState(() {
      selected = mode;
      status = 'Switching animation';
      busy = true;
    });
    try {
      await widget.device.setAnimationMode(mode);
      if (!mounted) return;
      setState(() {
        status = 'Running ${animationNames[mode]}.';
        busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = 'Could not switch animation: $error';
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ShadDialog(
    title: const Row(
      children: [
        Icon(LucideIcons.sparkles, size: 18, color: signal),
        SizedBox(width: 9),
        Text('OLED animation'),
      ],
    ),
    description: const Text(
      'Choose the live simulation. The mode lives in device SRAM and resets when NovaKey loses power.',
    ),
    actions: [
      ShadButton.outline(
        enabled: !busy,
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 7),
          ShadSelect<int>(
            key: ValueKey(selected),
            initialValue: selected,
            enabled: !busy,
            placeholder: const Text('Choose a simulation'),
            onChanged: (value) {
              if (value != null) unawaited(_select(value));
            },
            selectedOptionBuilder: (_, value) => Text(animationNames[value]),
            options: [
              for (var index = 0; index < animationNames.length; index++)
                ShadOption(value: index, child: Text(animationNames[index])),
            ],
          ),
          const SizedBox(height: 16),
          if (busy) ...[
            const ShadProgress(minHeight: 4, color: signal),
            const SizedBox(height: 10),
          ],
          Text(status, style: const TextStyle(color: muted, fontSize: 11)),
        ],
      ),
    ),
  );
}
