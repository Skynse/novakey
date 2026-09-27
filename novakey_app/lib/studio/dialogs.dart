import 'package:flutter/material.dart';

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (s) {
            if (s.trim().isNotEmpty) Navigator.pop(context, s.trim());
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Dispose after the closing route animation has finished.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}
