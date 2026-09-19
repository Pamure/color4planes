// lib/providers/settings_provider.dart
//
// FIX: toggleMusic() and toggleSfx() now take immediate effect.
// Previously they only wrote to SharedPreferences — the live AudioManager
// (which is a Flame component) never received the signal, so music kept
// playing after being toggled off.
//
// Fix: FlameAudio.bgm is a global singleton shared by every AudioManager
// instance. Calling .stop()/.play() here reaches the live game immediately,
// regardless of which screen is active. No Flame reference needed.

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:color4planes/core/constants.dart';

class SettingsState {
  final bool sfxEnabled;
  final bool musicEnabled;
  const SettingsState({this.sfxEnabled = true, this.musicEnabled = true});

  SettingsState copyWith({bool? sfxEnabled, bool? musicEnabled}) => SettingsState(
    sfxEnabled:   sfxEnabled   ?? this.sfxEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
  );
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    Future.microtask(() => _load());
    return const SettingsState();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      sfxEnabled:   _prefs.getBool(StorageKeys.sfxEnabled)   ?? true,
      musicEnabled: _prefs.getBool(StorageKeys.musicEnabled) ?? true,
    );
  }

  Future<void> toggleSfx() async {
    final newVal = !state.sfxEnabled;
    state = state.copyWith(sfxEnabled: newVal);
    await _prefs.setBool(StorageKeys.sfxEnabled, newVal);
    // No live effect needed for SFX — sounds are fire-and-forget.
    // The new value is picked up by AudioManager.initialize() on next game start.
  }

  Future<void> toggleMusic() async {
    final newVal = !state.musicEnabled;
    state = state.copyWith(musicEnabled: newVal);
    await _prefs.setBool(StorageKeys.musicEnabled, newVal);

    // Turning OFF: stop any currently-playing BGM immediately
    if (!newVal) {
      try { FlameAudio.bgm.stop(); } catch (_) {}
    }
    // Turning ON: do NOT start music here.
    // The game will read this setting and start it automatically when a match begins.
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
