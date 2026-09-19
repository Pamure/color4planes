// lib/managers/audio_manager.dart
// REBUILT: robust audio with per-sound cooldowns to prevent pool exhaustion.

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:color4planes/core/constants.dart';

class AudioManager {
  bool _sfxOn   = true;
  bool _musicOn = true;

  // ── Per-sound cooldowns to prevent pool exhaustion ────────────────────────
  // Key = sound filename, Value = timestamp of last play (seconds)
  final Map<String, double> _lastPlayTime = {};

  // Minimum seconds between plays of the same sound
  static const Map<String, double> _cooldowns = {
    AudioConfig.explosion: 0.08,  // max ~12 explosions/sec
    AudioConfig.shoot:     0.05,  // max ~20 shoot sounds/sec
    AudioConfig.gameOver:  2.0,   // should only play once anyway
  };

  double _now() => DateTime.now().millisecondsSinceEpoch / 1000.0;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sfxOn   = prefs.getBool(StorageKeys.sfxEnabled)   ?? true;
      _musicOn = prefs.getBool(StorageKeys.musicEnabled) ?? true;
    } catch (_) {}

    try {
      await FlameAudio.audioCache.loadAll([
        AudioConfig.shoot,
        AudioConfig.explosion,
        AudioConfig.gameOver,
        AudioConfig.youWin,
        AudioConfig.youLose,
        AudioConfig.lifelineLost,
      ]);
      // ── PRE-DECODE FOR ZERO LATENCY ──────────────────────────────────────────
      // Flame preloads files, but OS/Web engines often wait to decode until the 
      // very first play() command, causing a micro-stutter mid-gameplay.
      if (!kIsWeb) {
        FlameAudio.play(AudioConfig.shoot, volume: 0.0);
        FlameAudio.play(AudioConfig.explosion, volume: 0.0);
        FlameAudio.play(AudioConfig.gameOver, volume: 0.0);
      }
    } catch (e) {
      debugPrint('[Audio] Failed to preload sounds: $e');
    }
  }

  void playSound(String file, {double volume = 0.7}) {
    if (!_sfxOn) return;

    // ── Cooldown check ──────────────────────────────────────────────────────
    final now      = _now();
    final cooldown = _cooldowns[file] ?? 0.0;
    final lastPlay = _lastPlayTime[file] ?? 0.0;

if (now - lastPlay < cooldown) return;  // too soon, skip this play

    _lastPlayTime[file] = now;

    try {
      FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('[Audio] playSound failed for "$file": $e');
      // Now we actually SEE if the pool is exhausted
    }
  }

  Future<void> playMusic() async {
    if (!_musicOn) return;
    try {
      stopMusic();
      await FlameAudio.bgm.play(AudioConfig.bgm, volume: AudioConfig.musicVol);
    } catch (e) {
      debugPrint('[Audio] playMusic failed: $e');
    }
  }

  void stopMusic() {
    try { FlameAudio.bgm.stop(); } catch (_) {}
  }

  void setSfxEnabled(bool on)   => _sfxOn   = on;
  void setMusicEnabled(bool on) => _musicOn = on;
  void dispose()                => stopMusic();
}
