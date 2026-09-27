import 'package:flutter/material.dart';

import '../services/device_service.dart';
import '../services/firmware_updater.dart';
import '../theme/palette.dart';

Future<void> showFirmwareUpdater(
  BuildContext context,
  DeviceService device,
) async {
  final updater = FirmwareUpdater(device);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ListenableBuilder(
      listenable: updater,
      builder: (context, _) => AlertDialog(
        icon: Icon(
          updater.complete ? Icons.check_circle_outline : Icons.memory,
          color: updater.complete ? Colors.greenAccent : signal,
        ),
        title: const Text('Firmware tools'),
        content: SizedBox(
          width: 470,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Install an RP2040 UF2 without opening the enclosure. '
                'Keep NovaKey connected until the update finishes.',
                style: TextStyle(color: muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: updater.busy ? null : updater.chooseFirmware,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(updater.firmwareName),
              ),
              const SizedBox(height: 18),
              if (updater.busy) const LinearProgressIndicator(),
              if (updater.busy) const SizedBox(height: 14),
              Text(
                updater.status,
                style: TextStyle(
                  color: updater.complete ? Colors.greenAccent : muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: updater.busy ? null : () => Navigator.pop(context),
            child: Text(updater.complete ? 'Done' : 'Close'),
          ),
          FilledButton.icon(
            onPressed:
                updater.busy || updater.firmwarePath == null || updater.complete
                ? null
                : updater.install,
            icon: const Icon(Icons.system_update_alt, size: 18),
            label: const Text('Install firmware'),
          ),
        ],
      ),
    ),
  );
  updater.dispose();
}
