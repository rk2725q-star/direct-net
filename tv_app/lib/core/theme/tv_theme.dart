import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TvTheme {
  TvTheme._();

  static const Color _bg         = Color(0xFF05080F);
  static const Color _surface    = Color(0xFF0D1119);
  static const Color _card       = Color(0xFF131B28);
  static const Color _accent     = Color(0xFF00D4FF);
  static const Color _success    = Color(0xFF00E676);
  static const Color _warning    = Color(0xFFFFB300);
  static const Color _error      = Color(0xFFFF5252);
  static const Color _textPrimary   = Color(0xFFECEFF1);
  static const Color _textSecondary = Color(0xFF607D8B);
  static const Color _border     = Color(0xFF1E2D40);
  static const Color _focus      = Color(0xFF00D4FF);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      surface: _surface,
      error: _error,
      onPrimary: _bg,
      onSurface: _textPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme.copyWith(
        // TV text needs to be much larger for 10-foot viewing distance
        displayLarge: const TextStyle(
          fontSize: 56, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -2),
        displayMedium: const TextStyle(
          fontSize: 40, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -1),
        titleLarge: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600, color: _textPrimary),
        titleMedium: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w500, color: _textPrimary),
        bodyLarge: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w400, color: _textPrimary),
        bodyMedium: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w400, color: _textSecondary),
        labelLarge: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 1),
      ),
    ),
    // Focus / D-pad highlight
    focusColor: _focus.withValues(alpha: 0.15),
    extensions: const [
      TvColors(
        accent: _accent,
        success: _success,
        warning: _warning,
        card: _card,
        surface: _surface,
        border: _border,
        focus: _focus,
        textSecondary: _textSecondary,
      ),
    ],
  );
}

class TvColors extends ThemeExtension<TvColors> {
  final Color accent;
  final Color success;
  final Color warning;
  final Color card;
  final Color surface;
  final Color border;
  final Color focus;
  final Color textSecondary;

  const TvColors({
    required this.accent,
    required this.success,
    required this.warning,
    required this.card,
    required this.surface,
    required this.border,
    required this.focus,
    required this.textSecondary,
  });

  @override
  TvColors copyWith({
    Color? accent, Color? success, Color? warning, Color? card,
    Color? surface, Color? border, Color? focus, Color? textSecondary,
  }) => TvColors(
    accent: accent ?? this.accent,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    card: card ?? this.card,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    focus: focus ?? this.focus,
    textSecondary: textSecondary ?? this.textSecondary,
  );

  @override
  TvColors lerp(TvColors? other, double t) {
    if (other == null) return this;
    return TvColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }

  static TvColors of(BuildContext context) =>
      Theme.of(context).extension<TvColors>()!;
}

