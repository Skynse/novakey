import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../device/macro_pad_canvas.dart';
import '../services/application_monitor.dart';
import '../services/studio_controller.dart';
import '../theme/palette.dart';

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
    width: 370,
    color: panel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Profiles',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              ShadButton.ghost(
                width: 30,
                height: 30,
                padding: EdgeInsets.zero,
                onPressed: onNew,
                child: const Tooltip(
                  message: 'New profile',
                  child: Icon(LucideIcons.plus, size: 15),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Profile options',
                color: panelRaised,
                surfaceTintColor: Colors.transparent,
                icon: const Icon(LucideIcons.ellipsis, size: 16, color: muted),
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
                    PopupMenuItem(
                      value: item.$1,
                      height: 38,
                      child: Text(
                        item.$2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: panelRaised,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-switch profiles',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ApplicationMonitor.supported
                            ? controller.switchingIntegration
                                  ? 'Connecting to KWin'
                                  : controller.autoSwitch
                                  ? controller.focusedApplication.isEmpty
                                        ? 'Waiting for app focus'
                                        : controller.focusedApplication
                                  : 'Use KDE application focus'
                            : 'Requires KDE Plasma',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                ShadSwitch(
                  value: controller.autoSwitch,
                  enabled:
                      ApplicationMonitor.supported &&
                      !controller.switchingIntegration,
                  onChanged: controller.toggleAutoSwitch,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 144,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final profile in controller.profiles)
                _ProfileRow(
                  name: profile.name,
                  application: profile.application,
                  selected: profile.id == controller.activeId,
                  onPressed: () => controller.selectProfile(profile.id),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            'DEVICE MAP',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            controller.device.connected
                ? 'Use any physical control to reveal its assignment.'
                : 'Connect NovaKey to select controls from hardware.',
            style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _ProfileRow extends StatefulWidget {
  const _ProfileRow({
    required this.name,
    required this.application,
    required this.selected,
    required this.onPressed,
  });
  final String name, application;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: widget.selected
              ? signal.withValues(alpha: .10)
              : hovered
              ? panelHover
              : Colors.transparent,
          border: Border.all(
            color: widget.selected
                ? signal.withValues(alpha: .28)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.palette,
              size: 15,
              color: widget.selected ? signal : muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.application.isNotEmpty)
                    Text(
                      widget.application,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
