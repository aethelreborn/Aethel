import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AethelMark extends StatelessWidget {
  const AethelMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(
          body: palette.teal,
          line: palette.brass,
          keyhole: palette.brass,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.body,
    required this.line,
    required this.keyhole,
  });

  final Color body;
  final Color line;
  final Color keyhole;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.24;
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(shape, Paint()..color = body);

    final inset = size.width * 0.09;
    final border = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(radius * 0.72),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..color = line.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025,
    );

    final center = Offset(size.width / 2, size.height * 0.44);
    canvas.drawCircle(
      center,
      size.width * 0.085,
      Paint()..color = keyhole,
    );
    final slot = Path()
      ..moveTo(center.dx - size.width * 0.035, center.dy + size.width * 0.06)
      ..lineTo(center.dx + size.width * 0.035, center.dy + size.width * 0.06)
      ..lineTo(center.dx + size.width * 0.02, size.height * 0.7)
      ..lineTo(center.dx - size.width * 0.02, size.height * 0.7)
      ..close();
    canvas.drawPath(slot, Paint()..color = keyhole);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.line != line ||
      oldDelegate.keyhole != keyhole;
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final color = light ? palette.surface : palette.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AethelMark(size: compact ? 30 : 38),
        SizedBox(width: compact ? 9 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aethel',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: compact ? 22 : 27,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                color: color,
              ),
            ),
            if (!compact)
              Text(
                'PRIVATE LEDGER',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: light
                      ? palette.surface.withValues(alpha: 0.6)
                      : palette.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
