import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/control_binding.dart';
import 'device_layout.dart';
import 'control_hit_region.dart';

class MacroPadCanvas extends StatelessWidget {
  const MacroPadCanvas({
    super.key,
    required this.selectedId,
    required this.bindings,
    required this.onSelect,
  });

  final String selectedId;
  final Map<String, ControlBinding> bindings;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: deviceWidth / deviceHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sx = constraints.maxWidth / deviceWidth;
          final sy = constraints.maxHeight / deviceHeight;
          return RotatedBox(
            quarterTurns: 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    'assets/novakey-layout.svg',
                    fit: BoxFit.fill,
                  ),
                ),
                for (final control in controls)
                  Positioned(
                    left: control.x * sx,
                    top: control.y * sy,
                    width: control.width * sx,
                    height: control.height * sy,
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: ControlHitRegion(
                        control: control,
                        selected: selectedId == control.id,
                        binding: bindings[control.id],
                        displayLabel: _visualLabel(control),
                        onTap: () => onSelect(control.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
