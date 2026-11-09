import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // DirectNet brand palette
  static const Color _bg         = Color(0xFF0A0D14);
  static const Color _surface    = Color(0xFF131720);
  static const Color _card       = Color(0xFF1C2230);
  static const Color _accent     = Color(0xFF00D4FF);  // electric cyan
  static const Color _accentDim  = Color(0xFF007A99);
  static const Color _success    = Color(0xFF00E676);
  static const Color _warning    = Color(0xFFFFB300);
  static const Color _error      = Color(0xFFFF5252);
  static const Color _textPrimary   = Color(0xFFECEFF1);
  static const Color _textSecondary = Color(0xFF78909C);
  static const Color _border     = Color(0xFF263144);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      secondary: _accentDim,
      surface: _surface,
      error: _error,
      onPrimary: _bg,
      onSecondary: _textPrimary,
      onSurface: _textPrimary,
      onError: _textPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -1),
        displayMedium: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -0.5),
        titleLarge: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: _textPrimary),
        titleMedium: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary),
        bodyLarge: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, color: _textPrimary),
        bodyMedium: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, color: _textSecondary),
        labelLarge: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: _accent, letterSpacing: 0.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: _card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: _textPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: _bg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: _border,
      thickness: 1,
      space: 0,
    ),
    extensions: const [
      DirectNetColors(
        accent: _accent,
        accentDim: _accentDim,
        success: _success,
        warning: _warning,
        card: _card,
        surface: _surface,
        border: _border,
        textSecondary: _textSecondary,
      ),
    ],
  );
}

/// Custom color extension for DirectNet-specific tokens
class DirectNetColors extends ThemeExtension<DirectNetColors> {
  final Color accent;
  final Color accentDim;
  final Color success;
  final Color warning;
  final Color card;
  final Color surface;
  final Color border;
  final Color textSecondary;

  const DirectNetColors({
    required this.accent,
    required this.accentDim,
    required this.success,
    required this.warning,
    required this.card,
    required this.surface,
    required this.border,
    required this.textSecondary,
  });

  @override
  DirectNetColors copyWith({
    Color? accent, Color? accentDim, Color? success, Color? warning,
    Color? card, Color? surface, Color? border, Color? textSecondary,
  }) => DirectNetColors(
    accent: accent ?? this.accent,
    accentDim: accentDim ?? this.accentDim,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    card: card ?? this.card,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    textSecondary: textSecondary ?? this.textSecondary,
  );

  @override
  DirectNetColors lerp(DirectNetColors? other, double t) {
    if (other == null) return this;
    return DirectNetColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }

  static DirectNetColors of(BuildContext context) =>
      Theme.of(context).extension<DirectNetColors>()!;
}
