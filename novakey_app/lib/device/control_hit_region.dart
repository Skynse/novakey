import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../models/control_binding.dart';

class ControlHitRegion extends StatefulWidget {
  const ControlHitRegion({
    super.key,
    required this.control,
    required this.selected,
    required this.binding,
    required this.onTap,
    this.displayLabel,
  });

  final ControlSpec control;
  final bool selected;
  final ControlBinding? binding;
  final VoidCallback onTap;
  final String? displayLabel;

  @override
  State<ControlHitRegion> createState() => _ControlHitRegionState();
}

class _ControlHitRegionState extends State<ControlHitRegion> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSequence = widget.binding?.kind == ActionKind.sequence;
    final isTiny =
        widget.control.type == ControlType.encoderClockwise ||
        widget.control.type == ControlType.encoderCounterClockwise;
    return Tooltip(
      message:
          '${widget.displayLabel ?? widget.control.label}\n${widget.binding?.name ?? 'Unassigned'}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: widget.selected
                  ? signal.withValues(alpha: .18)
                  : hovered
                  ? paper.withValues(alpha: .07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                widget.control.type == ControlType.encoderPress
                    ? 100
                    : (isTiny ? 6 : 11),
              ),
              border: Border.all(
                color: widget.selected
                    ? signal
                    : isSequence
                    ? orange.withValues(alpha: .8)
                    : hovered
                    ? paper.withValues(alpha: .35)
                    : Colors.transparent,
                width: widget.selected ? 2 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: signal.withValues(alpha: .16),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: isTiny
                ? Icon(
                    widget.control.type == ControlType.encoderClockwise
                        ? Icons.rotate_right
                        : Icons.rotate_left,
                    size: 14,
                    color: widget.selected ? signal : muted,
                  )
                : widget.control.type == ControlType.key
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      widget.binding?.name ??
                          (widget.displayLabel ?? widget.control.label)
                              .replaceFirst('Key ', ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.binding == null ? 12 : 9,
                        fontWeight: FontWeight.w700,
                        color: widget.selected ? signal : paper,
                      ),
                    ),
                  )
                : const Icon(Icons.radio_button_checked, color: ink, size: 19),
          ),
        ),
      ),
    );
  }
}
