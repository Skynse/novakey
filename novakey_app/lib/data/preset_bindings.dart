import '../models/control_binding.dart';

const presetBindings = <ControlBinding>[
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Undo',
    detail: 'Ctrl + Z',
    keyCode: 29,
    modifiers: 1,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Redo',
    detail: 'Ctrl + Shift + Z',
    keyCode: 29,
    modifiers: 3,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Brush size +',
    detail: ']',
    keyCode: 48,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Brush size −',
    detail: '[',
    keyCode: 47,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Brush',
    detail: 'B',
    keyCode: 5,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Eraser',
    detail: 'E',
    keyCode: 8,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Save',
    detail: 'Ctrl + S',
    keyCode: 22,
    modifiers: 1,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Fit canvas',
    detail: 'Ctrl + 0',
    keyCode: 39,
    modifiers: 1,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Pan (hold)',
    detail: 'Space',
    keyCode: 44,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Color picker (hold)',
    detail: 'Ctrl',
    modifiers: 1,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Hide panels',
    detail: 'Tab',
    keyCode: 43,
  ),
  ControlBinding(
    kind: ActionKind.shortcut,
    name: 'Select all',
    detail: 'Ctrl + A',
    keyCode: 4,
    modifiers: 1,
  ),
];
