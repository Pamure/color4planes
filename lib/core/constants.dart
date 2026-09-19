// lib/core/constants.dart
//
// REDESIGNED: Sharper neon-space palette that reads better over the dark
// starfield and gives a distinct retro-cockpit look.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography -- retro-futuristic font families via google_fonts package.
/// Orbitron: geometric, futuristic display font for titles and headers.
/// Share Tech Mono: clean monospace for stats, body text, and terminal readouts.
class AppFonts {
  AppFonts._();
  static String get title => GoogleFonts.orbitron().fontFamily     ?? 'Courier New';
  static String get body  => GoogleFonts.shareTechMono().fontFamily ?? 'Courier New';
}


/// All constants specific to multiplayer mode.
class MultiplayerConfig {
  MultiplayerConfig._();

  static const double freezeDuration = 1.5;
  static const int startingLives = 3;
  static const double opponentStartY = 80.0;
  static const double opponentBulletStartY = 110.0;
  static const int disconnectGraceMs = 3000;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACE COLORS  — cohesive neon retro palette
// ─────────────────────────────────────────────────────────────────────────────
class SpaceColors {
  SpaceColors._();

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color voidBlack = Color(0xFF020616);
  static const Color deepSpace = Color(0xFF040D26);
  static const Color cosmicDusk = Color(0xFF08112A);
  static const Color starField = Color(0xFF0E1A30); // surface cards
  static const Color nebulaVoid = Color(0xFF060F22);

  // ── Neon Blues ────────────────────────────────────────────────────────────
  static const Color neonBlue = Color(0xFF00C6FF); // primary accent
  static const Color blueNova = Color(0xFF0090D0); // button bg
  static const Color bluePulsar = Color(0xFF006090);
  static const Color blueGlow = Color(0xFF80DDFF); // highlight text
  static const Color blueNebula = Color(0x2200C6FF); // glass tint
  static const Color blueExplosion = Color(0xFF5CB8FF);

  // ── Neon Reds ─────────────────────────────────────────────────────────────
  static const Color neonRed = Color(0xFFFF2040); // primary accent
  static const Color redNova = Color(0xFFCC1030); // button bg
  static const Color redPulsar = Color(0xFF880020);
  static const Color redGlow = Color(0xFFFF8090); // highlight text
  static const Color redNebula = Color(0x22FF2040);
  static const Color redExplosion = Color(0xFFFF6B6B);

  // ── Text / UI ─────────────────────────────────────────────────────────────
  static const Color starWhite = Color(0xFFE0ECFF); // primary text
  static const Color cometGrey = Color(0xFF6A8AA8); // secondary text
  static const Color asteroidGrey = Color(0xFF344860); // muted text
  static const Color moonGlow = Color(0xFFFFF59D);
  static const Color sunflare = Color(0xFFFFB800); // score gold
  static const Color faint = Color(0xFF506B88); // placeholder / hint text
  // ── Difficulty tiers ──────────────────────────────────────────────────────
  static const Color difficultyBoy = Color(0xFF00FF88);
  static const Color difficultyMan = Color(0xFFFFB800);
  static const Color difficultySorcerer = Color(0xFFFF7700);
  static const Color difficultySupreme = Color(0xFFFF2040);

  // ── UI helpers ────────────────────────────────────────────────────────────
  static const Color blackOverlay = Color(0xDD020616);
  static const Color hudBackground = Color(0xBB020A1C);
  static const Color dividerLine = Color(0x2200C6FF);
  static const Color laneTint = Color(0x0C00C6FF);
  static const Color scanline = Color(0x0400C6FF);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const List<Color> swapGradient = [neonBlue, neonRed];
  static const List<Color> swapButtonGradient = [neonBlue, neonRed];
  static const List<Color> backgroundGradient = [
    voidBlack,
    deepSpace,
    nebulaVoid,
  ];
  static const List<Color> blueButtonGradient = [neonBlue, blueNova];
  static const List<Color> redButtonGradient = [neonRed, redNova];
}

class GameConfig {
  GameConfig._();

  static const int totalLanes = 4;
  static const double maxGameWidth = 560.0;
  static const double planeWidthRatio = 0.55;
  static const double planeAspectRatio = 1.2;
  static const double planeBottomPad = 80.0;

  static const double bulletSpeed = 450.0;
  static const double bulletWidth = 10.0;
  static const double bulletHeight = 48.0;
  static const double shootCooldown = 0.30;
  static const double bulletCooldown = shootCooldown;

  static const double alienSize = 48.0;
  static const int maxShipsOnScreen = 15;
  static const int colorImbalanceCap = 3;

  static const int basePointsPerKill = 10;
  static const double minSwipeDistance = 40.0;
  static const double parallaxBaseSpeed = 50.0;
  static const double parallaxMultiplier = 2.0;

  static const double hitboxShrinkFactor = 0.75;
}

class DifficultyConfig {
  DifficultyConfig._();

  static const double phase1End = 30.0;
  static const double phase2End = 65.0; // Pushed out slightly
  static const double phase3End = 130.0;

  // Breather Wave curve: Spawn rate dips when hitting a new phase to give players a break
  static const double spawnP1Start = 0.8;
  static const double spawnP1End   = 1.5;

  static const double spawnP2Start = 1.25; // Breather (drops from 1.5)
  static const double spawnP2End   = 2.10;

  static const double spawnP3Start = 1.70; // Breather (drops from 2.1)
  static const double spawnP3End   = 2.40;

  static const double spawnP4Start = 2.10; // Breather (drops from 2.4)
  static const double spawnP4Max   = 2.80; // Hard cap so it doesn't become mathematically unwinnable

  static const double speedPhase1 = 110.0;
  static const double speedPhase2 = 150.0;
  static const double speedPhase3 = 190.0;
  static const double speedPhase4 = 220.0; // Much more reasonable max speed

  // Slightly wider variant speeds to create staggered clusters of ships
  static const double speedVarMin = 0.75;  
  static const double speedVarMax = 1.25;  

  static const double multPhase1 = 1.0;
  static const double multPhase2 = 1.5;
  static const double multPhase3 = 2.0;
  static const double multPhase4 = 3.0;

  static const String labelPhase1 = 'BOY';
  static const String labelPhase2 = 'MAN';
  static const String labelPhase3 = 'SORCERER';
  static const String labelPhase4 = 'BIHARI';
}

class ParticleConfig {
  ParticleConfig._();

  static const int count = 18;
  static const double size = 5.0;
  static const double speedMin = 80.0;
  static const double speedMax = 200.0;
  static const double lifetimeMin = 0.30;
  static const double lifetimeMax = 0.70;
  static const int cleanupMs = 800;
  static const int trailLength = 8;
  static const double trailOpacity = 0.50;
  static const double trailWidth = 3.0;
}

class AudioConfig {
  AudioConfig._();

  static const String shoot = 'shoot.mp3';
  static const String explosion = 'explosion.mp3';
  static const String gameOver = 'gameover.mp3';
  static const String bgm = 'bgm.mp3';
  static const String youWin = 'youwin.mp3';
  static const String youLose = 'youloose.mp3';
  static const String lifelineLost = 'lifelinelost.mp3';

  static const double shootVol = 0.35;
  static const double explosionVol = 0.70;
  static const double gameOverVol = 0.80;
  static const double musicVol = 0.50;
}

class Assets {
  Assets._();

  static const String bluePlane = 'blueplane.png';
  static const String redPlane = 'redplane.png';
  static const String blueAlien = 'bluealien.png';
  static const String redAlien = 'redalien.png';
  static const String blueBullet = 'bluebullet.png';
  static const String redBullet = 'redbullet.png';
  static const String background = 'spaceParralax.png';
  static const String layer1 = 'layer1.png';
  static const String layer2 = 'layer2.png';
}

class UIDimensions {
  UIDimensions._();

  static const double swapButtonSize = 64.0;
  static const double swapButtonIconSize = 30.0;
  static const double swapButtonBottomPad = 100.0;

  static const double hudTopMargin = 8.0;
  static const double hudSideMargin = 12.0;
  static const double hudPadH = 14.0;
  static const double hudPadV = 8.0;
  static const double hudBorderRadius = 4.0; // sharper corners = more retro

  static const double cardMargin = 20.0;
  static const double cardPadding = 24.0;
  static const double cardRadius = 4.0; // sharp retro corners

  static const double radiusSm = 4.0;
  static const double radiusMd = 4.0;
  static const double radiusLg = 4.0;
}

class StorageKeys {
  StorageKeys._();

  static const String guestUserId = 'guest_user_id';
  static const String highScore = 'high_score';
  static const String sfxEnabled = 'sfx_enabled';
  static const String musicEnabled = 'music_enabled';
  static const String sfxVolume = 'sfx_volume';
  static const String musicVolume = 'music_volume';
  static const String displayName = 'display_name';
  static const String totalGames = 'total_games';
  static const String totalKills = 'total_kills';
}

class RoutePaths {
  RoutePaths._();
  static const String nameSetup = '/setup-name';
  static const String splash = '/';
  static const String home = '/home';
  static const String game = '/game';
  static const String multiplayer = '/multiplayer';
  static const String multiplayerGame = '/multiplayer/game';
  static const String settings = '/settings';
  static const String leaderboard = '/leaderboard';
  static const String friends = '/friends';
  static const String profile = '/profile';
}
