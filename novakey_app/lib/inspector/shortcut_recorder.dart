import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/control_binding.dart';

const keyNames = <int, String>{
  40: 'Enter',
  41: 'Escape',
  42: 'Backspace',
  43: 'Tab',
  44: 'Space',
  45: '-',
  46: '=',
  47: '[',
  48: ']',
  49: r'\',
  51: ';',
  52: "'",
  53: '`',
  54: ',',
  55: '.',
  56: '/',
  79: 'Right',
  80: 'Left',
  81: 'Down',
  82: 'Up',
  74: 'Home',
  77: 'End',
  75: 'Page Up',
  78: 'Page Down',
  76: 'Delete',
};
String shortcutLabel(int key, int mods) {
  final parts = <String>[
    if (mods & 1 != 0) 'Ctrl',
    if (mods & 2 != 0) 'Shift',
    if (mods & 4 != 0) 'Alt',
    if (mods & 8 != 0) 'Super',
  ];
  if (key != 0) {
    parts.add(
      keyNames[key] ??
          (key >= 4 && key <= 29
              ? String.fromCharCode(key + 61)
              : key >= 30 && key <= 38
              ? '${key - 29}'
              : key == 39
              ? '0'
              : key >= 58 && key <= 69
              ? 'F${key - 57}'
              : 'USB $key'),
    );
  }
  return parts.isEmpty ? 'Press a key' : parts.join(' + ');
}

Future<ControlBinding?> recordShortcut(
  BuildContext context, {
  ControlBinding? initial,
}) => showDialog<ControlBinding>(
  context: context,
  builder: (_) => ShortcutRecorder(initial: initial),
);

class ShortcutRecorder extends StatefulWidget {
  const ShortcutRecorder({super.key, this.initial});
  final ControlBinding? initial;
  @override
  State<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<ShortcutRecorder> {
  final focus = FocusNode();
  late int key, mods;
  @override
  void initState() {
    super.initState();
    key = widget.initial?.keyCode ?? 0;
    mods = widget.initial?.modifiers ?? 0;
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record shortcut'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Click the field, then press a shortcut. Modifier-only shortcuts can be held for brush pickers and canvas controls.',
          ),
          const SizedBox(height: 20),
          Focus(
            autofocus: true,
            focusNode: focus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) {
                final keyboard = HardwareKeyboard.instance;
                setState(() {
                  mods =
                      (keyboard.isControlPressed ? 1 : 0) |
                      (keyboard.isShiftPressed ? 2 : 0) |
                      (keyboard.isAltPressed ? 4 : 0) |
                      (keyboard.isMetaPressed ? 8 : 0);
                  final usage = event.physicalKey.usbHidUsage & 0xffff;
                  key = usage >= 224 && usage <= 231
                      ? 0
                      : usage <= 231
                      ? usage
                      : 0;
                });
              }
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              onTap: () => focus.requestFocus(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shortcutLabel(key, mods),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Some desktop shortcuts are reserved by the OS. You can also toggle modifiers below.',
            style: TextStyle(fontSize: 12),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final m in [
                (1, 'Ctrl'),
                (2, 'Shift'),
                (4, 'Alt'),
                (8, 'Super'),
              ])
                FilterChip(
                  label: Text(m.$2),
                  selected: mods & m.$1 != 0,
                  onSelected: (_) => setState(() => mods ^= m.$1),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: key == 0 && mods == 0
            ? null
            : () => Navigator.pop(
                context,
                ControlBinding(
                  kind: ActionKind.shortcut,
                  name: widget.initial?.name ?? shortcutLabel(key, mods),
                  detail: shortcutLabel(key, mods),
                  keyCode: key,
                  modifiers: mods,
                ),
              ),
        child: const Text('Use shortcut'),
      ),
    ],
  );
}
