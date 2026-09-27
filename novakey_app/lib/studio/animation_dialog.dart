import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_service.dart';
import '../theme/palette.dart';

const animationNames = [
  'Wave tank',
  'Particle flow field',
  'Reaction–diffusion',
  'Boids',
  'Fluid-like ink',
  'Metaballs',
  'Dithered plasma',
  'Rule 30',
  'Langton’s ants',
  'Damped membrane',
  'Display diagnostic',
];

Future<void> showAnimationPicker(BuildContext context, DeviceService device) =>
    showDialog<void>(
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
  String status = 'Reading current mode…';
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
      status = 'Switching animation…';
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
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.animation, color: signal),
    title: const Text('OLED animation'),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The active mode lives in device SRAM. It returns to Wave tank '
            'when NovaKey loses power or restarts.',
            style: TextStyle(color: muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Simulation'),
            items: [
              for (var index = 0; index < animationNames.length; index++)
                DropdownMenuItem(
                  value: index,
                  child: Text(animationNames[index]),
                ),
            ],
            onChanged: busy ? null : (value) => _select(value!),
          ),
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (busy) const SizedBox(height: 12),
          Text(status, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
