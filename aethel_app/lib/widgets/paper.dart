import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class LedgerBackground extends StatelessWidget {
  const LedgerBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return CustomPaint(
      painter: _LedgerPainter(
        line: palette.line,
        margin: palette.brass,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: child,
    );
  }
}

class _LedgerPainter extends CustomPainter {
  const _LedgerPainter({
    required this.line,
    required this.margin,
    required this.isDark,
  });

  final Color line;
  final Color margin;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = line.withValues(alpha: isDark ? 0.24 : 0.42)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final marginPaint = Paint()
      ..color = margin.withValues(alpha: isDark ? 0.18 : 0.28)
      ..strokeWidth = 1;
    final x = size.width > 900 ? 72.0 : 28.0;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(_LedgerPainter oldDelegate) =>
      oldDelegate.line != line ||
      oldDelegate.margin != margin ||
      oldDelegate.isDark != isDark;
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
    this.borderColor,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? palette.line),
      ),
      child: child,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? palette.tealSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.46,
        color: iconColor ?? palette.teal,
      ),
    );
  }
}
