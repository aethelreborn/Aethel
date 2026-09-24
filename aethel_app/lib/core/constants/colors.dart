import 'package:flutter/material.dart';

// ── Color tokens (§8.2 of spec) ──────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Light mode
  static const Color bgPrimaryLight     = Color(0xFFFAFAF9);
  static const Color bgSurfaceLight     = Color(0xFFFFFFFF);
  static const Color textPrimaryLight   = Color(0xFF1A1A1E);
  static const Color accentLight        = Color(0xFF3B6E6B);
  static const Color urgentLight        = Color(0xFFD64545);
  static const Color upcomingLight      = Color(0xFFD9A441);
  static const Color informationalLight = Color(0xFF3F6FBF);
  static const Color resolvedLight      = Color(0xFF4C9A6A);

  // Dark mode
  static const Color bgPrimaryDark      = Color(0xFF121316);
  static const Color bgSurfaceDark      = Color(0xFF1C1E22);
  static const Color textPrimaryDark    = Color(0xFFF2F2F3);
  static const Color accentDark         = Color(0xFF5FA39F);
  static const Color urgentDark         = Color(0xFFE06767);
  static const Color upcomingDark       = Color(0xFFE0B65C);
  static const Color informationalDark  = Color(0xFF6C93D6);
  static const Color resolvedDark       = Color(0xFF6FBF8A);

  // Resolve for current theme
  static Color bgPrimary(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? bgPrimaryDark : bgPrimaryLight;

  static Color bgSurface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? bgSurfaceDark : bgSurfaceLight;

  static Color textPrimary(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;

  static Color accent(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? accentDark : accentLight;

  static Color urgent(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? urgentDark : urgentLight;

  static Color upcoming(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? upcomingDark : upcomingLight;

  static Color informational(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? informationalDark : informationalLight;

  static Color resolved(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? resolvedDark : resolvedLight;
}
