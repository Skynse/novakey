import 'package:flutter/material.dart';

import '../device/device_layout.dart';
import '../models/control_binding.dart';
import '../services/studio_controller.dart';
import '../theme/novakey_theme.dart';

class BindingsHud extends StatelessWidget {
  const BindingsHud({super.key, required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: novaKeyMaterialTheme(),
    home: Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading) return const SizedBox.shrink();
          final profile = controller.active;
          String label(String id) =>
              controls.firstWhere((c) => c.id == id).label;
          return Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xEA141416),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.keyboard_alt_outlined, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hide bindings',
                      onPressed: controller.hud.hide,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'BINDINGS  /  NOVAKEY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            const _Heading('KEYS'),
                            for (var row = 0; row < 8; row++)
                              Row(
                                children: [
                                  for (final i in [row * 2, row * 2 + 1])
                                    Expanded(
                                      child: _BindingRow(
                                        label: controls[i].label,
                                        binding:
                                            profile.bindings[controls[i].id] ??
                                            unassigned,
                                        active:
                                            controller.lastControl ==
                                            controls[i].id,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            const _Heading('DIALS & KNOBS'),
                            for (final c in controls.skip(16))
                              _BindingRow(
                                label: c.label,
                                binding: profile.bindings[c.id] ?? unassigned,
                                active: controller.lastControl == c.id,
                                compact: true,
                              ),
                            const SizedBox(height: 20),
                            const _Heading('COMBINATIONS'),
                            if (profile.combinations.isEmpty)
                              const Text(
                                'No combinations assigned',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            for (final combo in profile.combinations)
                              _BindingRow(
                                label:
                                    '${label(combo.held)} + ${label(combo.trigger)}',
                                binding: combo.binding,
                                active: false,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use your HUD binding to dismiss • Scroll for more bindings',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.4,
        color: Colors.white54,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _BindingRow extends StatelessWidget {
  const _BindingRow({
    required this.label,
    required this.binding,
    required this.active,
    this.compact = false,
  });
  final String label;
  final ControlBinding binding;
  final bool active, compact;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: active ? const Color(0x30EDA45E) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            color: active ? const Color(0xFFFFC387) : Colors.white54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          binding.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: binding.kind == ActionKind.none
                ? Colors.white30
                : Colors.white,
          ),
        ),
        if (!compact && binding.kind == ActionKind.shortcut)
          Text(
            binding.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
      ],
    ),
  );
}
