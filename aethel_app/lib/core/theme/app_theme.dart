import 'package:flutter/material.dart';

@immutable
class AethelColors extends ThemeExtension<AethelColors> {
  const AethelColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.teal,
    required this.tealSoft,
    required this.brass,
    required this.brassSoft,
    required this.danger,
    required this.dangerSoft,
    required this.line,
    required this.success,
  });

  final Color ground;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color teal;
  final Color tealSoft;
  final Color brass;
  final Color brassSoft;
  final Color danger;
  final Color dangerSoft;
  final Color line;
  final Color success;

  static const light = AethelColors(
    ground: Color(0xFFF4F0E8),
    surface: Color(0xFFFBF8F1),
    raised: Color(0xFFFFFFFF),
    ink: Color(0xFF1C2422),
    muted: Color(0xFF69736F),
    teal: Color(0xFF1F5A54),
    tealSoft: Color(0xFFDCE7E3),
    brass: Color(0xFFB08D57),
    brassSoft: Color(0xFFF0E4CF),
    danger: Color(0xFFA9433B),
    dangerSoft: Color(0xFFF3DDD9),
    line: Color(0xFFDDD6C9),
    success: Color(0xFF3F7357),
  );

  static const dark = AethelColors(
    ground: Color(0xFF151A18),
    surface: Color(0xFF1D2421),
    raised: Color(0xFF242C28),
    ink: Color(0xFFF1EEE5),
    muted: Color(0xFF9DA9A3),
    teal: Color(0xFF72B7AE),
    tealSoft: Color(0xFF243A36),
    brass: Color(0xFFD3B178),
    brassSoft: Color(0xFF3A3124),
    danger: Color(0xFFE1877E),
    dangerSoft: Color(0xFF3B2522),
    line: Color(0xFF343D38),
    success: Color(0xFF82B99B),
  );

  @override
  AethelColors copyWith({
    Color? ground,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? teal,
    Color? tealSoft,
    Color? brass,
    Color? brassSoft,
    Color? danger,
    Color? dangerSoft,
    Color? line,
    Color? success,
  }) {
    return AethelColors(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      teal: teal ?? this.teal,
      tealSoft: tealSoft ?? this.tealSoft,
      brass: brass ?? this.brass,
      brassSoft: brassSoft ?? this.brassSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      line: line ?? this.line,
      success: success ?? this.success,
    );
  }

  @override
  AethelColors lerp(ThemeExtension<AethelColors>? other, double t) {
    if (other is! AethelColors) return this;
    return AethelColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealSoft: Color.lerp(tealSoft, other.tealSoft, t)!,
      brass: Color.lerp(brass, other.brass, t)!,
      brassSoft: Color.lerp(brassSoft, other.brassSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AethelThemeContext on BuildContext {
  AethelColors get aethel =>
      Theme.of(this).extension<AethelColors>() ?? AethelColors.light;

  bool get isCompact => MediaQuery.sizeOf(this).width < 700;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        palette: AethelColors.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        palette: AethelColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AethelColors palette,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.teal,
      brightness: brightness,
    ).copyWith(
      primary: palette.teal,
      onPrimary: brightness == Brightness.light
          ? const Color(0xFFF7F4EC)
          : const Color(0xFF0F1A18),
      primaryContainer: palette.tealSoft,
      onPrimaryContainer: palette.ink,
      secondary: palette.brass,
      onSecondary: const Color(0xFF241B0E),
      secondaryContainer: palette.brassSoft,
      onSecondaryContainer: palette.ink,
      surface: palette.surface,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.raised,
      onSurfaceVariant: palette.muted,
      outline: palette.line,
      outlineVariant: palette.line,
      error: palette.danger,
      onError: const Color(0xFFFFF8F5),
      errorContainer: palette.dangerSoft,
      onErrorContainer: palette.ink,
      shadow: const Color(0x14000000),
      scrim: const Color(0x99101513),
      inverseSurface: palette.ink,
      onInverseSurface: palette.surface,
      inversePrimary: palette.brass,
    );

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 68,
        fontWeight: FontWeight.w500,
        height: 1.02,
        letterSpacing: -1.8,
        color: palette.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 50,
        fontWeight: FontWeight.w500,
        height: 1.06,
        letterSpacing: -1.2,
        color: palette.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 38,
        fontWeight: FontWeight.w500,
        height: 1.1,
        letterSpacing: -0.7,
        color: palette.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.4,
        color: palette.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 27,
        fontWeight: FontWeight.w600,
        height: 1.18,
        color: palette.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: palette.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.2,
        color: palette.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: palette.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: palette.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: palette.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: palette.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: palette.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: palette.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: palette.muted,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: palette.muted,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.ground,
      canvasColor: palette.ground,
      fontFamily: 'Manrope',
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: palette.ink,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.line),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: palette.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: palette.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.teal,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: palette.teal.withValues(alpha: 0.35),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: palette.line),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.teal,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(44, 44),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.tealSoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? palette.teal : palette.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? palette.teal : palette.muted,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: palette.line),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: palette.tealSoft,
        disabledColor: palette.ground,
        side: BorderSide(color: palette.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.ink),
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: palette.teal),
        checkmarkColor: palette.teal,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: palette.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.line),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.teal
              : palette.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.tealSoft
              : palette.line.withValues(alpha: 0.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.teal,
        linearTrackColor: palette.line,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: palette.surface),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        textColor: palette.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
