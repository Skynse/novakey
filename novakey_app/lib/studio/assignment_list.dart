import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../device/device_layout.dart';
import '../models/control_binding.dart';
import '../models/profile.dart';
import '../theme/palette.dart';

class AssignmentList extends StatefulWidget {
  const AssignmentList({
    super.key,
    required this.profile,
    required this.selected,
    required this.onEdit,
    required this.onSelect,
    required this.onAddCombination,
    required this.onEditCombination,
    required this.onDeleteCombination,
  });

  final Profile profile;
  final String selected;
  final ValueChanged<String> onSelect, onEdit;
  final VoidCallback onAddCombination;
  final ValueChanged<int> onEditCombination, onDeleteCombination;

  @override
  State<AssignmentList> createState() => _AssignmentListState();
}

class _AssignmentListState extends State<AssignmentList> {
  String query = '';
  final _scrollKey = GlobalKey();

  @override
  void didUpdateWidget(covariant AssignmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollKey.currentContext?.findRenderObject()?.showOnScreen(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: ShadInput(
          placeholder: const Text('Find a control or action'),
          leading: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(LucideIcons.search, size: 15, color: muted),
          ),
          onChanged: (value) => setState(() => query = value.toLowerCase()),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            for (final group in [
              ('KEYS', controls.take(16)),
              ('DIALS & KNOBS', controls.skip(16)),
            ]) ...[
              _SectionLabel(group.$1),
              for (final control in group.$2.where(
                (control) =>
                    '${control.label} ${widget.profile.bindings[control.id]?.name ?? ''}'
                        .toLowerCase()
                        .contains(query),
              ))
                _AssignmentRow(
                  key: control.id == widget.selected
                      ? _scrollKey
                      : ValueKey(control.id),
                  control: control,
                  binding: widget.profile.bindings[control.id] ?? unassigned,
                  selected: control.id == widget.selected,
                  onPressed: () {
                    widget.onSelect(control.id);
                    widget.onEdit(control.id);
                  },
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: _SectionLabel(
                    'COMBINATIONS',
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: widget.onAddCombination,
                  leading: const Icon(LucideIcons.plus, size: 14),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (widget.profile.combinations.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panelRaised,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'Hold one control while using another to trigger a separate action.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            for (
              var index = 0;
              index < widget.profile.combinations.length;
              index++
            )
              _CombinationRow(
                title:
                    '${_label(widget.profile.combinations[index].held)} + ${_label(widget.profile.combinations[index].trigger)}',
                action: widget.profile.combinations[index].binding.name,
                onPressed: () => widget.onEditCombination(index),
                onDelete: () => widget.onDeleteCombination(index),
              ),
          ],
        ),
      ),
    ],
  );

  String _label(String id) =>
      controls.firstWhere((control) => control.id == id).label;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
    this.label, {
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });
  final String label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      label,
      style: const TextStyle(
        color: muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
      ),
    ),
  );
}

class _AssignmentRow extends StatefulWidget {
  const _AssignmentRow({
    super.key,
    required this.control,
    required this.binding,
    required this.selected,
    required this.onPressed,
  });
  final ControlSpec control;
  final ControlBinding binding;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_AssignmentRow> createState() => _AssignmentRowState();
}

class _AssignmentRowState extends State<_AssignmentRow> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) {
      setState(() => hovered = true);
    },
    onExit: (_) => setState(() => hovered = false),
    child: GestureDetector(
      onDoubleTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.selected
              ? signal.withValues(alpha: .10)
              : hovered
              ? panelHover
              : panel,
          border: Border.all(
            color: widget.selected ? signal.withValues(alpha: .32) : line,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: _controlIcon(widget.control, widget.selected),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Text(
                widget.control.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.binding.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.binding.kind == ActionKind.none
                          ? muted
                          : paper,
                    ),
                  ),
                  if (widget.binding.kind != ActionKind.none)
                    Text(
                      widget.binding.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                ],
              ),
            ),
            if (!widget.binding.onboard)
              const Tooltip(
                message: 'Requires Studio running',
                child: Icon(LucideIcons.monitor, size: 14, color: muted),
              ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, size: 14, color: muted),
          ],
        ),
      ),
    ),
  );

  Widget _controlIcon(ControlSpec control, bool selected) =>
      control.type == ControlType.key
      ? SvgPicture.asset(
          'assets/keycap.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            selected ? signal : muted,
            BlendMode.srcIn,
          ),
        )
      : Icon(
          control.type == ControlType.encoderPress
              ? LucideIcons.circleDot
              : control.type == ControlType.encoderClockwise
              ? LucideIcons.rotateCw
              : LucideIcons.rotateCcw,
          size: 17,
          color: selected ? signal : muted,
        );
}

class _CombinationRow extends StatefulWidget {
  const _CombinationRow({
    required this.title,
    required this.action,
    required this.onPressed,
    required this.onDelete,
  });
  final String title, action;
  final VoidCallback onPressed, onDelete;

  @override
  State<_CombinationRow> createState() => _CombinationRowState();
}

class _CombinationRowState extends State<_CombinationRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: GestureDetector(
      onDoubleTap: widget.onPressed,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.fromLTRB(12, 9, 5, 9),
        decoration: BoxDecoration(
          color: hovered ? panelHover : panel,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.combine, size: 15, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.action,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            ShadButton.ghost(
              width: 28,
              height: 28,
              padding: EdgeInsets.zero,
              onPressed: widget.onDelete,
              child: const Icon(LucideIcons.x, size: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
