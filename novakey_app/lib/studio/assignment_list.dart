import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: TextField(
          onChanged: (v) => setState(() => query = v.toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Find a control or action',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            for (final group in [
              ('Keys', controls.take(16)),
              ('Dials & knobs', controls.skip(16)),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 10),
                child: Text(
                  group.$1,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final c in group.$2.where(
                (c) => '${c.label} ${widget.profile.bindings[c.id]?.name ?? ''}'
                    .toLowerCase()
                    .contains(query),
              ))
                _row(c),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Combinations',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAddCombination,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (widget.profile.combinations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Hold a key to give another key or dial a second action.',
                  style: TextStyle(color: muted),
                ),
              ),
            for (var i = 0; i < widget.profile.combinations.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${_label(widget.profile.combinations[i].held)} + ${_label(widget.profile.combinations[i].trigger)}',
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(widget.profile.combinations[i].binding.name),
                onTap: () => widget.onEditCombination(i),
                trailing: IconButton(
                  tooltip: 'Remove combination',
                  onPressed: () => widget.onDeleteCombination(i),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
          ],
        ),
      ),
    ],
  );
  String _label(String id) => controls.firstWhere((c) => c.id == id).label;
  Widget _row(ControlSpec c) {
    final b = widget.profile.bindings[c.id] ?? unassigned;
    final selected = c.id == widget.selected;
    return Padding(
      key: c.id == widget.selected ? _scrollKey : null,
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? signal.withValues(alpha: .10) : panel,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            widget.onSelect(c.id);
            widget.onEdit(c.id);
          },
          onHover: (hover) {
            if (hover) widget.onSelect(c.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                c.type == ControlType.key
                    ? SvgPicture.asset(
                        'assets/keycap.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          selected ? signal : muted,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        c.type == ControlType.encoderPress
                            ? Icons.radio_button_checked
                            : c.type == ControlType.encoderClockwise
                            ? Icons.rotate_right
                            : Icons.rotate_left,
                        size: 18,
                        color: selected ? signal : muted,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Text(
                    _visualLabel(c),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: b.kind == ActionKind.none ? muted : paper,
                        ),
                      ),
                      if (b.kind != ActionKind.none)
                        Text(
                          b.detail,
                          style: const TextStyle(color: muted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!b.onboard)
                  const Tooltip(
                    message: 'Requires Studio running',
                    child: Icon(Icons.computer, size: 15, color: muted),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 16, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _visualLabel(ControlSpec control) {
    final match = RegExp(r'^key-(\d+)$').firstMatch(control.id);
    if (match == null) return control.label;
    final number = 17 - int.parse(match.group(1)!);
    return 'Key ${number.toString().padLeft(2, '0')}';
  }
}
