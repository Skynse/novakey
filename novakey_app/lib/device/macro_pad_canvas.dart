import 'package:flutter/material.dart';

import '../models/control_binding.dart';
import 'control_hit_region.dart';
import 'device_layout.dart';
import 'device_callouts.dart';

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
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 360 / 300,
    child: FittedBox(
      child: SizedBox(
        width: 360,
        height: 300,
        child: Stack(
          children: [
            const Positioned(
              left: 44,
              top: 64,
              width: 272,
              height: 172.84,
              child: Image(
                image: AssetImage('assets/novakey_v3.png'),
                filterQuality: FilterQuality.high,
              ),
            ),
            for (final c in controls.where(
              (c) =>
                  c.type == ControlType.key ||
                  c.type == ControlType.encoderPress,
            ))
              Positioned(
                left: 44 + c.x * 272 / deviceWidth,
                top: 64 + c.y * 272 / deviceWidth,
                width: c.width * 272 / deviceWidth,
                height: c.height * 272 / deviceWidth,
                child: ControlHitRegion(
                  control: c,
                  selected:
                      selectedId == c.id ||
                      (c.type == ControlType.encoderPress &&
                          selectedId.startsWith(c.id.substring(0, 5))),
                  binding: bindings[c.id],
                  displayLabel: c.label,
                  showContent: false,
                  onTap: () => onSelect(c.id),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: DeviceCallouts(selectedId)),
              ),
            ),
            if (selectedId.startsWith('enc-'))
              Positioned(
                left: 64,
                right: 64,
                bottom: 0,
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final action in [
                      ('ccw', '↶'),
                      ('press', 'Press'),
                      ('cw', '↷'),
                    ])
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: action.$1 == 'ccw'
                              ? 'Counter-clockwise'
                              : action.$1 == 'cw'
                              ? 'Clockwise'
                              : 'Press',
                          child: GestureDetector(
                            onTap: () => onSelect(
                              '${selectedId.substring(0, 5)}-${action.$1}',
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: selectedId.endsWith(action.$1)
                                    ? const Color(0xFF353539)
                                    : const Color(0xFF1C1C1F),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                action.$2,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE4E4E7),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
