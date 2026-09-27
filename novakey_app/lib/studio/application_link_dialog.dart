import 'package:flutter/material.dart';

import '../services/application_monitor.dart';

Future<String?> linkApplication(
  BuildContext context,
  String current,
  List<FocusedApplication> recent,
) => showDialog<String>(
  context: context,
  builder: (_) => ApplicationLinkDialog(current: current, recent: recent),
);

class ApplicationLinkDialog extends StatefulWidget {
  const ApplicationLinkDialog({
    super.key,
    required this.current,
    required this.recent,
  });
  final String current;
  final List<FocusedApplication> recent;
  @override
  State<ApplicationLinkDialog> createState() => _ApplicationLinkDialogState();
}

class _ApplicationLinkDialogState extends State<ApplicationLinkDialog> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Link application'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enable auto-switch, focus your art app, then return here to select it. You can also enter its KDE application ID.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Application ID or resource class',
              hintText: 'org.kde.krita',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Recently focused applications'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final app in widget.recent)
                    ListTile(
                      dense: true,
                      title: Text(app.id),
                      subtitle: app.resourceClass == app.id
                          ? null
                          : Text(app.resourceClass),
                      onTap: () => setState(() => controller.text = app.id),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: const Text('Unlink'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Link profile'),
      ),
    ],
  );
}
