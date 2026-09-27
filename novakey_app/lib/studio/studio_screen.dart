import 'dart:async';

import 'package:flutter/material.dart';

import '../services/studio_controller.dart';
import '../services/profile_store.dart';
import '../models/profile.dart';
import '../models/control_binding.dart';
import '../device/device_layout.dart';
import '../inspector/binding_editor.dart';
import '../theme/palette.dart';
import 'assignment_list.dart';
import 'profile_sidebar.dart';
import 'combination_dialog.dart';
import 'dialogs.dart';
import 'application_link_dialog.dart';
import 'animation_dialog.dart';
import 'firmware_dialog.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final controller = StudioController();
  bool debugMode = false;
  @override
  void initState() {
    super.initState();
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> edit(String id) async {
    controller.select(id);
    await controller.runner.stop();
    final wasRunning = controller.device.running;
    // Avoid running artist shortcuts against the configuration dialog itself.
    controller.learn = true;
    if (!mounted) return;
    final value = await editBinding(
      context,
      controls.firstWhere((c) => c.id == id).label,
      controller.binding,
    );
    controller.learn = false;
    if (value != null) {
      controller.select(id);
      controller.assign(value);
    }
    if (!wasRunning && controller.device.running) {
      await controller.device.capture(false);
    }
  }

  Future<void> combo([int? index]) async {
    await controller.runner.stop();
    controller.learn = true;
    try {
      if (!mounted) return;
      final existing = index == null
          ? null
          : controller.active.combinations[index];
      final pair = existing == null
          ? await chooseCombination(context)
          : (existing.held, existing.trigger);
      if (pair == null || !mounted) return;
      if (existing == null &&
          controller.active.combinations.any(
            (c) => c.held == pair.$1 && c.trigger == pair.$2,
          )) {
        controller.report(
          'That combination already exists. Edit it in the list.',
        );
        return;
      }
      final binding = await editBinding(
        context,
        'Combination',
        existing?.binding ?? unassigned,
      );
      if (binding == null) return;
      if (existing != null) {
        existing.binding = binding;
      } else {
        controller.active.combinations.add(
          Combination(held: pair.$1, trigger: pair.$2, binding: binding),
        );
      }
      await controller.persist();
    } finally {
      controller.learn = false;
    }
  }

  Future<void> profileMenu(String action) async {
    try {
      if (action == 'link') {
        final value = await linkApplication(
          context,
          controller.active.application,
          List.of(controller.recentApplications),
        );
        if (value != null) {
          final other = controller.profiles.where(
            (p) =>
                p.id != controller.activeId &&
                p.application.toLowerCase() == value.toLowerCase(),
          );
          if (value.isNotEmpty && other.isNotEmpty) {
            controller.report(
              'That application is already linked to ${other.first.name}.',
            );
            return;
          }
          controller.active.application = value;
          await controller.persist();
        }
        return;
      }
      if (action == 'delete') {
        if (controller.profiles.length == 1) {
          controller.report('Keep at least one profile.');
          return;
        }
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${controller.active.name}?'),
            content: const Text(
              'This removes its assignments and combinations.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (yes == true) await controller.deleteProfile();
        return;
      }
      final title = switch (action) {
        'rename' => 'Rename profile',
        'duplicate' => 'Duplicate profile',
        'link' => 'Link application',
        'import' => 'Import profiles from file',
        'export' => 'Export profiles to file',
        _ => 'New profile',
      };
      final initial = switch (action) {
        'rename' => controller.active.name,
        'duplicate' => '${controller.active.name} copy',
        'link' => controller.active.application,
        'export' => '${ProfileStore.directory}/export.json',
        _ => '',
      };
      final value = await askText(
        context,
        title,
        initial: initial,
        hint: action == 'link'
            ? 'KDE app ID or class (e.g. org.kde.krita or krita)'
            : '',
      );
      if (value == null) return;
      switch (action) {
        case 'rename':
          controller.active.name = value;
          await controller.persist();
        case 'link':
          controller.active.application = value;
          await controller.persist();
        case 'duplicate':
          await controller.addProfile(value, duplicate: true);
        case 'import':
          await controller.importFrom(value);
        case 'export':
          await controller.exportTo(value);
        default:
          await controller.addProfile(value);
      }
    } catch (e) {
      controller.report(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    const Icon(Icons.tune, color: signal, size: 23),
                    const SizedBox(width: 12),
                    const Text(
                      'NovaKey',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Studio', style: TextStyle(color: muted)),
                    const Spacer(),
                    if (debugMode) ...[
                      OutlinedButton.icon(
                        onPressed: controller.device.connected
                            ? () => showAnimationPicker(
                                context,
                                controller.device,
                              )
                            : null,
                        icon: const Icon(Icons.animation, size: 17),
                        label: const Text('Animation'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showFirmwareUpdater(context, controller.device),
                        icon: const Icon(Icons.memory, size: 17),
                        label: const Text('Firmware'),
                      ),
                      const SizedBox(width: 10),
                    ],
                    TextButton.icon(
                      onPressed:
                          controller.device.connecting ||
                              controller.device.connected
                          ? null
                          : controller.device.connect,
                      icon: Icon(
                        controller.device.connected ? Icons.usb : Icons.usb_off,
                        size: 17,
                      ),
                      label: Text(
                        controller.device.connected
                            ? 'Connected'
                            : controller.device.connecting
                            ? 'Connecting…'
                            : 'Connect pad',
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      tooltip: 'Studio options',
                      onSelected: (value) {
                        if (value == 'debug') {
                          setState(() => debugMode = !debugMode);
                        }
                      },
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem<String>(
                          value: 'debug',
                          checked: debugMode,
                          child: const Text('Debug mode'),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Stop all actions and release keys',
                      onPressed: () {
                        unawaited(controller.runner.stop());
                        if (controller.device.running) {
                          unawaited(controller.device.capture(false));
                        }
                      },
                      icon: const Icon(Icons.stop_circle_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: box.maxWidth < 1000 ? 1000 : box.maxWidth,
                      child: Row(
                        children: [
                          ProfileSidebar(
                            controller: controller,
                            onNew: () => profileMenu('new'),
                            onMenu: profileMenu,
                            onEdit: edit,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    22,
                                    24,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              controller.active.name,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              controller.saving
                                                  ? 'Saving…'
                                                  : controller.saveFailed
                                                  ? 'Changes could not be saved'
                                                  : '${controller.active.bindings.length} assignments · local profiles',
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: controller.device.connected
                                            ? controller.upload
                                            : null,
                                        icon: const Icon(
                                          Icons.save_alt,
                                          size: 17,
                                        ),
                                        label: const Text('Save onboard'),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: AssignmentList(
                                    profile: controller.active,
                                    selected: controller.selected,
                                    onSelect: controller.select,
                                    onEdit: edit,
                                    onAddCombination: () => combo(),
                                    onEditCombination: combo,
                                    onDeleteCombination: (i) {
                                      controller.active.combinations.removeAt(
                                        i,
                                      );
                                      unawaited(controller.runner.stop());
                                      unawaited(controller.persist());
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: panel,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      controller.message.isEmpty
                          ? Icons.info_outline
                          : Icons.chat_bubble_outline,
                      size: 15,
                      color: muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.message.isEmpty
                            ? controller.device.status
                            : controller.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    if (controller.message.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Dismiss',
                        onPressed: () => controller.report(''),
                        icon: const Icon(Icons.close, size: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
