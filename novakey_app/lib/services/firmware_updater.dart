import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'device_service.dart';

class FirmwareUpdater extends ChangeNotifier {
  FirmwareUpdater(this.device);

  final DeviceService device;
  String? firmwarePath;
  String status = 'Choose an RP2040 UF2 firmware image.';
  bool busy = false;
  bool complete = false;

  String get firmwareName => firmwarePath == null
      ? 'No firmware selected'
      : firmwarePath!.split(Platform.pathSeparator).last;

  Future<void> chooseFirmware() async {
    if (busy || !Platform.isLinux) return;
    final home = Platform.environment['HOME'] ?? '/';
    try {
      final result = await Process.run('kdialog', [
        '--title',
        'Choose NovaKey firmware',
        '--getopenfilename',
        home,
        '*.uf2|RP2040 firmware (*.uf2)',
      ]);
      if (result.exitCode != 0) return;
      final path = (result.stdout as String).trim();
      if (path.isEmpty) return;
      await _validate(File(path));
      firmwarePath = path;
      complete = false;
      status = 'Ready to install $firmwareName.';
    } catch (error) {
      firmwarePath = null;
      complete = false;
      status = 'Could not use that firmware: ${_clean(error)}';
    }
    notifyListeners();
  }

  Future<void> install() async {
    if (busy || firmwarePath == null) return;
    busy = true;
    complete = false;
    try {
      if (!device.connected) {
        status = 'Connecting to NovaKey…';
        notifyListeners();
        await device.connect();
      }
      if (!device.connected) {
        throw StateError('Connect NovaKey before installing firmware.');
      }

      status = 'Entering RP2040 bootloader…';
      notifyListeners();
      await device.enterBootloader();

      status = 'Waiting for RPI-RP2…';
      notifyListeners();
      var volume = await _waitForVolume(const Duration(seconds: 20));
      if (volume.mountpoint == null) {
        final mounted = await Process.run('udisksctl', [
          'mount',
          '--block-device',
          volume.device,
        ]);
        if (mounted.exitCode != 0) {
          throw StateError((mounted.stderr as String).trim());
        }
        volume = await _waitForVolume(
          const Duration(seconds: 5),
          requireMounted: true,
        );
      }

      status = 'Writing firmware…';
      notifyListeners();
      final target = File(
        '${volume.mountpoint}${Platform.pathSeparator}$firmwareName',
      );
      await File(firmwarePath!).copy(target.path);

      status = 'Waiting for NovaKey to restart…';
      notifyListeners();
      await _waitForVolumeToDisappear(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      for (var attempt = 0; attempt < 30 && !device.connected; attempt++) {
        await device.connect();
        if (!device.connected) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (!device.connected) {
        throw StateError(
          'Firmware was written, but NovaKey did not reconnect.',
        );
      }
      complete = true;
      status = 'Firmware installed. NovaKey is connected.';
    } catch (error) {
      status = 'Update failed: ${_clean(error)}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _validate(File file) async {
    if (!file.path.toLowerCase().endsWith('.uf2')) {
      throw const FormatException('Choose a .uf2 firmware image.');
    }
    final bytes = await file
        .openRead(0, 4)
        .fold<List<int>>(<int>[], (value, chunk) => value..addAll(chunk));
    if (bytes.length != 4 ||
        bytes[0] != 0x55 ||
        bytes[1] != 0x46 ||
        bytes[2] != 0x32 ||
        bytes[3] != 0x0a) {
      throw const FormatException('This file is not a valid UF2 image.');
    }
  }

  Future<_BootVolume> _waitForVolume(
    Duration timeout, {
    bool requireMounted = false,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final volume = await _bootVolume();
      if (volume != null && (!requireMounted || volume.mountpoint != null)) {
        return volume;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException('RPI-RP2 did not appear.', timeout);
  }

  Future<void> _waitForVolumeToDisappear(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _bootVolume() == null) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<_BootVolume?> _bootVolume() async {
    final result = await Process.run('lsblk', [
      '--json',
      '--paths',
      '--output',
      'NAME,LABEL,MOUNTPOINT',
    ]);
    if (result.exitCode != 0) return null;
    final document =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    return _findVolume(document['blockdevices'] as List);
  }

  _BootVolume? _findVolume(List<dynamic> devices) {
    for (final value in devices) {
      final item = Map<String, dynamic>.from(value as Map);
      if (item['label'] == 'RPI-RP2') {
        return _BootVolume(
          item['name'] as String,
          item['mountpoint'] as String?,
        );
      }
      final children = item['children'];
      if (children is List) {
        final found = _findVolume(children);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _clean(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '')
      .replaceFirst('TimeoutException: ', '');
}

class _BootVolume {
  const _BootVolume(this.device, this.mountpoint);
  final String device;
  final String? mountpoint;
}
