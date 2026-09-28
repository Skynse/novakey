import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../services/studio_controller.dart';
import '../theme/palette.dart';

class StudioHeader extends StatelessWidget {
  const StudioHeader({
    super.key,
    required this.controller,
    required this.debugMode,
    required this.onToggleDebug,
    required this.onAnimation,
    required this.onFirmware,
    required this.onStop,
  });

  final StudioController controller;
  final bool debugMode;
  final VoidCallback onToggleDebug;
  final VoidCallback onAnimation;
  final VoidCallback onFirmware;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: ink,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 10),
        const Spacer(),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: controller.hud.toggle,
          leading: const Icon(Icons.view_list_outlined, size: 16),
          child: const Text('Bindings HUD'),
        ),
        const SizedBox(width: 12),
        ShadBadge.outline(
          foregroundColor: controller.device.connected ? positive : muted,
          backgroundColor: controller.device.connected
              ? positive.withValues(alpha: .08)
              : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: controller.device.connected ? positive : muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                controller.device.connected
                    ? 'Connected'
                    : controller.device.connecting
                    ? 'Connecting'
                    : 'Offline',
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!controller.device.connected)
          ShadButton.outline(
            size: ShadButtonSize.sm,
            enabled: !controller.device.connecting,
            onPressed: controller.device.connect,
            leading: const Icon(LucideIcons.usb, size: 15),
            child: const Text('Connect'),
          ),
        if (debugMode) ...[
          const SizedBox(width: 8),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            enabled: controller.device.connected,
            onPressed: onAnimation,
            leading: const Icon(LucideIcons.sparkles, size: 15),
            child: const Text('OLED'),
          ),
          const SizedBox(width: 8),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onFirmware,
            leading: const Icon(LucideIcons.microchip, size: 15),
            child: const Text('Firmware'),
          ),
        ],
        const SizedBox(width: 8),
        ShadButton.ghost(
          size: ShadButtonSize.sm,
          onPressed: onToggleDebug,
          foregroundColor: debugMode ? signal : muted,
          leading: const Icon(LucideIcons.bug, size: 15),
          child: const Text('Debug'),
        ),
        const SizedBox(width: 4),
        ShadButton.ghost(
          width: 34,
          height: 34,
          padding: EdgeInsets.zero,
          onPressed: onStop,
          foregroundColor: muted,
          child: const Tooltip(
            message: 'Stop actions and release keys',
            child: Icon(LucideIcons.circleStop, size: 17),
          ),
        ),
      ],
    ),
  );
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.active.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.saveFailed
                    ? 'Changes could not be saved'
                    : '${controller.active.bindings.length} assignments  ·  ${controller.active.combinations.length} combinations',
                style: TextStyle(
                  color: controller.saveFailed ? destructive : muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ShadBadge.secondary(
          foregroundColor: controller.saveFailed ? destructive : muted,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.saving
                    ? LucideIcons.refreshCw
                    : LucideIcons.cloudCheck,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(controller.saving ? 'Syncing' : 'Auto-saved'),
            ],
          ),
        ),
      ],
    ),
  );
}

class StudioStatusBar extends StatelessWidget {
  const StudioStatusBar({super.key, required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: panel,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Icon(
          controller.message.isEmpty
              ? LucideIcons.info
              : LucideIcons.messageSquare,
          size: 14,
          color: muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            controller.message.isEmpty
                ? controller.device.status
                : controller.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
        if (controller.message.isNotEmpty)
          ShadButton.ghost(
            width: 28,
            height: 28,
            padding: EdgeInsets.zero,
            onPressed: () => controller.report(''),
            child: const Icon(LucideIcons.x, size: 13),
          ),
      ],
    ),
  );
}
