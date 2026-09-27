import 'package:flutter/material.dart';

import '../services/studio_controller.dart';
import '../device/macro_pad_canvas.dart';
import '../theme/palette.dart';
import '../services/application_monitor.dart';

class ProfileSidebar extends StatelessWidget {
  const ProfileSidebar({
    super.key,
    required this.controller,
    required this.onNew,
    required this.onMenu,
    required this.onEdit,
  });
  final StudioController controller;
  final VoidCallback onNew;
  final ValueChanged<String> onMenu, onEdit;
  @override
  Widget build(BuildContext context) => Container(
    width: 340,
    color: panel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Profiles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'New profile',
                onPressed: onNew,
                icon: const Icon(Icons.add),
              ),
              PopupMenuButton<String>(
                tooltip: 'Profile options',
                onSelected: onMenu,
                itemBuilder: (_) => [
                  for (final item in [
                    ('rename', 'Rename'),
                    ('duplicate', 'Duplicate'),
                    ('link', 'Link application'),
                    ('delete', 'Delete'),
                    ('import', 'Import profiles'),
                    ('export', 'Export profiles'),
                  ])
                    PopupMenuItem(value: item.$1, child: Text(item.$2)),
                ],
              ),
            ],
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text(
            'Auto-switch profiles',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            ApplicationMonitor.supported
                ? (controller.switchingIntegration
                      ? 'Connecting to KWin…'
                      : controller.autoSwitch
                      ? 'KWin • ${controller.focusedApplication.isEmpty ? 'waiting for focus' : controller.focusedApplication}'
                      : 'Use KDE application focus')
                : 'Requires KDE Plasma',
            style: const TextStyle(fontSize: 11),
          ),
          value: controller.autoSwitch,
          onChanged:
              ApplicationMonitor.supported && !controller.switchingIntegration
              ? controller.toggleAutoSwitch
              : null,
        ),
        SizedBox(
          height: 150,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final p in controller.profiles)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  selected: p.id == controller.activeId,
                  selectedTileColor: signal.withValues(alpha: .1),
                  leading: Icon(
                    Icons.palette_outlined,
                    size: 19,
                    color: p.id == controller.activeId ? signal : muted,
                  ),
                  title: Text(p.name),
                  subtitle: p.application.isEmpty
                      ? null
                      : Text(
                          p.application,
                          style: const TextStyle(fontSize: 11),
                        ),
                  onTap: () => controller.selectProfile(p.id),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Text(
            'Your NovaKey',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: MacroPadCanvas(
                selectedId: controller.selected,
                bindings: controller.active.bindings,
                onSelect: (id) {
                  controller.select(id);
                  onEdit(id);
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Text(
            controller.device.connected
                ? 'Press a physical control to reveal and edit its assignment.'
                : 'Connect the pad to select controls from hardware.',
            style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );
}
