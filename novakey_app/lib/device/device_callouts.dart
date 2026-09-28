import 'package:flutter/material.dart';

import 'device_layout.dart';

/// Labels occupy reserved screen-space gutters, independent of image pixels.
class DeviceCallouts extends CustomPainter {
  DeviceCallouts(this.selectedId);
  final String selectedId;
  Offset project(double x, double y) =>
      Offset(44 + x * 272 / deviceWidth, 64 + y * 272 / deviceWidth);

  @override
  void paint(Canvas canvas, Size size) {
    void label(
      String text,
      Offset anchor,
      List<Offset> bends,
      Offset position,
      bool active,
    ) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            color: active ? const Color(0xFF18181B) : const Color(0xFFB8B8BF),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromLTWH(
        position.dx,
        position.dy,
        tp.width + 10,
        tp.height + 6,
      );
      final points = [anchor, ...bends];
      final paint = Paint()
        ..color = active ? const Color(0xFFE4E4E7) : const Color(0xFF85858D)
        ..strokeWidth = active ? 1.4 : .85;
      for (var i = 0; i < points.length - 1; i++) {
        final delta = points[i + 1] - points[i];
        final distance = delta.distance;
        if (active) {
          canvas.drawLine(points[i], points[i + 1], paint);
        } else if (distance > 0) {
          for (double d = 0; d < distance; d += 5) {
            canvas.drawLine(
              points[i] + delta * (d / distance),
              points[i] + delta * ((d + 2).clamp(0, distance) / distance),
              paint,
            );
          }
        }
      }
      canvas.drawCircle(anchor, active ? 2.4 : 1.5, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()
          ..color = active ? const Color(0xFFE4E4E7) : const Color(0xFF111113),
      );
      tp.paint(canvas, position + const Offset(5, 3));
    }

    label(
      'Dial',
      project(394, 258),
      [const Offset(143.4, 44), const Offset(108, 44)],
      const Offset(76, 34),
      selectedId.startsWith('enc-1'),
    );
    label(
      'Knob 3',
      project(332, 417),
      [const Offset(127.8, 249), const Offset(102, 249)],
      const Offset(53, 240),
      selectedId.startsWith('enc-3'),
    );
    label(
      'Knob 2',
      project(455, 417),
      [const Offset(158.8, 249), const Offset(186, 249)],
      const Offset(186, 240),
      selectedId.startsWith('enc-2'),
    );
    if (selectedId.startsWith('key-')) {
      final c = controls.firstWhere((c) => c.id == selectedId);
      final a = project(c.x + c.width / 2, c.y + c.height / 2);
      label(
        c.label,
        a,
        [Offset(a.dx, 44), const Offset(270, 44)],
        const Offset(270, 34),
        true,
      );
    }
  }

  @override
  bool shouldRepaint(DeviceCallouts oldDelegate) =>
      oldDelegate.selectedId != selectedId;
}
