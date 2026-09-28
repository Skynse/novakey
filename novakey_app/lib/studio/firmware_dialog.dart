import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../services/device_service.dart';
import '../services/firmware_updater.dart';
import '../theme/palette.dart';

Future<void> showFirmwareUpdater(BuildContext context, DeviceService device) async {
  final updater = FirmwareUpdater(device);
  await showShadDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ListenableBuilder(
      listenable: updater,
      builder: (context, _) => ShadDialog(
        constraints: const BoxConstraints(maxWidth: 510),
        title: Row(children: [
          Icon(updater.complete ? LucideIcons.circleCheck : LucideIcons.microchip, size: 18, color: updater.complete ? positive : signal),
          const SizedBox(width: 9),
          const Text('Firmware tools'),
        ]),
        description: const Text(
          'Install an RP2040 UF2 without opening the enclosure. Keep NovaKey connected until the update finishes.',
        ),
        actions: [
          ShadButton.outline(
            enabled: !updater.busy,
            onPressed: () => Navigator.pop(context),
            child: Text(updater.complete ? 'Done' : 'Close'),
          ),
          ShadButton(
            enabled: !updater.busy && updater.firmwarePath != null && !updater.complete,
            onPressed: updater.install,
            backgroundColor: signal,
            foregroundColor: ink,
            leading: const Icon(LucideIcons.upload, size: 15),
            child: const Text('Install firmware'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('UF2 FILE', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8)),
              const SizedBox(height: 7),
              ShadButton.outline(
                enabled: !updater.busy,
                onPressed: updater.chooseFirmware,
                mainAxisAlignment: MainAxisAlignment.start,
                leading: const Icon(LucideIcons.folderOpen, size: 15),
                child: Expanded(
                  child: Text(updater.firmwareName, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(height: 16),
              if (updater.busy) ...[
                const ShadProgress(minHeight: 4, color: signal),
                const SizedBox(height: 10),
              ],
              Text(
                updater.status,
                style: TextStyle(color: updater.complete ? positive : muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  updater.dispose();
}
