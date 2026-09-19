// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:color4planes/core/constants.dart';

class AppTheme {
  AppTheme._();

  static String get _displayFont => GoogleFonts.orbitron().fontFamily     ?? 'Courier New';
  static String get _bodyFont    => GoogleFonts.shareTechMono().fontFamily ?? 'Courier New';

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness:   Brightness.dark,
    scaffoldBackgroundColor: SpaceColors.voidBlack,

    colorScheme: const ColorScheme.dark(
      primary:   SpaceColors.neonBlue,
      secondary: SpaceColors.neonRed,
      surface:   SpaceColors.starField,
      error:     Color(0xFFFF2040),
    ),

    // ── ElevatedButton ────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: SpaceColors.starWhite,
        backgroundColor: SpaceColors.blueNova,
        elevation:       0,
        shadowColor:     Colors.transparent,
        padding:         const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIDimensions.radiusSm),
        ),
        textStyle: TextStyle(          // ← no const
          fontFamily:    _displayFont,
          fontSize:      13,
          fontWeight:    FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
    ),

    // ── OutlinedButton ────────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SpaceColors.cometGrey,
        side:            const BorderSide(color: SpaceColors.dividerLine, width: 1),
        padding:         const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIDimensions.radiusSm),
        ),
        textStyle: TextStyle(          // ← no const
          fontFamily:    _displayFont,
          fontSize:      13,
          fontWeight:    FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
    ),

    iconTheme: const IconThemeData(color: SpaceColors.starWhite, size: 22),

    // ── Text theme ────────────────────────────────────────────────────────────
    textTheme: TextTheme(              // ← no const
      displayLarge: TextStyle(         // ← no const
        fontFamily:    _displayFont,
        color:         SpaceColors.starWhite,
        fontSize:      40,
        fontWeight:    FontWeight.w900,
        letterSpacing: 10.0,
      ),
      titleLarge: TextStyle(           // ← no const
        fontFamily:    _displayFont,
        color:         SpaceColors.starWhite,
        fontSize:      16,
        fontWeight:    FontWeight.bold,
        letterSpacing: 4.0,
      ),
      bodyMedium: TextStyle(           // ← no const
        fontFamily: _bodyFont,
        color:      SpaceColors.cometGrey,
        fontSize:   13,
      ),
      labelSmall: TextStyle(           // ← no const
        fontFamily:    _bodyFont,
        color:         SpaceColors.asteroidGrey,
        fontSize:      10,
        letterSpacing: 2.0,
      ),
    ),

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color:     SpaceColors.dividerLine,
      thickness: 1,
      space:     24,
    ),

    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SpaceColors.deepSpace,
      contentTextStyle: TextStyle(
        color:      SpaceColors.starWhite,
        fontSize:   13,
        fontFamily: _bodyFont,
        letterSpacing: 1.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: SpaceColors.neonBlue, width: 0.5),
      ),
    ),
  );
}
