// lib/core/responsive.dart
//
// On mobile: game fills the full screen
// On tablet: game is centered with margins
// On desktop/web: game has a fixed max width, UI adapts
//
// HOW TO USE:
//   final width = Responsive.gameWidth(context);
//   if (Responsive.isMobile(context)) { ... }

import 'package:flutter/material.dart';

enum ScreenClass { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  // These breakpoints match Material Design guidelines
  static ScreenClass classify(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600)  return ScreenClass.mobile;
    if (w < 1100) return ScreenClass.tablet;
    return ScreenClass.desktop;
  }

  static bool isMobile (BuildContext context) => classify(context) == ScreenClass.mobile;
  static bool isTablet (BuildContext context) => classify(context) == ScreenClass.tablet;
  static bool isDesktop(BuildContext context) => classify(context) == ScreenClass.desktop;

  // ── Game Canvas Dimensions ────────────────────────────────────────────────
  // The actual width of the game play area.
  // On mobile: full screen. On larger: centred with a max cap.
  static double gameWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    switch (classify(context)) {
      case ScreenClass.mobile:  return w;
      case ScreenClass.tablet:  return (w * 0.70).clamp(320, 560);
      case ScreenClass.desktop: return 520.0;
    }
  }

  // ── Text Scaling ──────────────────────────────────────────────────────────
  // Keeps text readable across very different screen densities.
  static double scoreFontSize(BuildContext context) {
    switch (classify(context)) {
      case ScreenClass.mobile:  return 26.0;
      case ScreenClass.tablet:  return 30.0;
      case ScreenClass.desktop: return 34.0;
    }
  }

  // ── Touch Target Scaling ──────────────────────────────────────────────────
  // Buttons need to be bigger on mobile (fat fingers), smaller on desktop
  static double swapButtonSize(BuildContext context) {
    switch (classify(context)) {
      case ScreenClass.mobile:  return 70.0;
      case ScreenClass.tablet:  return 80.0;
      case ScreenClass.desktop: return 64.0;
    }
  }

  // ── Padding ───────────────────────────────────────────────────────────────
  static double screenPadding(BuildContext context) {
    switch (classify(context)) {
      case ScreenClass.mobile:  return 12.0;
      case ScreenClass.tablet:  return 20.0;
      case ScreenClass.desktop: return 24.0;
    }
  }

  // ── Text Scaling ───────────────────────────────────────────────────────────
  // Returns a multiplier for font sizes based on screen class.
  // Mobile sizes are unchanged (1.0x), tablet/desktop scale up.
  static double textScale(BuildContext context) {
    switch (classify(context)) {
      case ScreenClass.mobile:  return 1.0;
      case ScreenClass.tablet:  return 1.15;
      case ScreenClass.desktop: return 1.3;
    }
  }

  // Convenience: returns baseSize * textScale(context).
  static double fs(BuildContext context, double baseSize) =>
      baseSize * textScale(context);

  // ── Raw Size Helper ───────────────────────────────────────────────────────
  static Size screenSize(BuildContext context) => MediaQuery.sizeOf(context);
}
