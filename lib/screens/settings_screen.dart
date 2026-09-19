// lib/screens/settings_screen.dart
//
// Settings screen — music & SFX toggles, persisted via settingsProvider.
// AudioManager reads SharedPreferences on initialize() so changes take
// effect next time the game starts.  Wire live changes by calling
// game.audio?.setSfxEnabled(v) if you want in-session effect.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/providers/settings_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Back + Title ──────────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: SpaceColors.cometGrey,
                            size:  20,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'SETTINGS',
                          style: TextStyle(
                            color:         SpaceColors.starWhite,
                            fontSize:      18,
                            fontFamily:    AppFonts.body,
                            fontWeight:    FontWeight.bold,
                            letterSpacing: 6.0,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 36),
                    _SectionLabel('AUDIO'),
                    SizedBox(height: 16),

                    // ── Music toggle ──────────────────────────────────────────
                    _SettingsTile(
                      label:       'MUSIC',
                      description: 'Background music during gameplay',
                      icon:        Icons.music_note_rounded,
                      value:       settings.musicEnabled,
                      accentColor: SpaceColors.neonBlue,
                      onChanged:   (_) => notifier.toggleMusic(),
                    ),
                    SizedBox(height: 12),

                    // ── SFX toggle ────────────────────────────────────────────
                    _SettingsTile(
                      label:       'SOUND FX',
                      description: 'Bullets, explosions, game over',
                      icon:        Icons.volume_up_rounded,
                      value:       settings.sfxEnabled,
                      accentColor: SpaceColors.neonRed,
                      onChanged:   (_) => notifier.toggleSfx(),
                    ),

                    SizedBox(height: 40),
                    _SectionLabel('CONTROLS'),
                    SizedBox(height: 16),
                    _InfoCard(
                      rows: const [
                        ('TAP ON PLANE',       'Change lanes (toggle)'),
                        ('H-SWIPE',            'Change lanes (directional)'),
                        ('TAP ANYWHERE ELSE',  'Shoot'),
                        ('V-SWIPE / BUTTON',   'Swap colors'),
                      ],
                    ),

                    SizedBox(height: 24),
                    _SectionLabel('KEYBOARD (PC)'),
                    SizedBox(height: 16),
                    _InfoCard(
                      rows: const [
                        ('W',         'Shoot left plane'),
                        ('↑ ARROW',   'Shoot right plane'),
                        ('A / D',     'Left plane lanes'),
                        ('← / →',     'Right plane lanes'),
                        ('SPACE',     'Swap colors'),
                      ],
                    ),

                    SizedBox(height: 40),
                    _SectionLabel('DIFFICULTY'),
                    SizedBox(height: 16),
                    _InfoCard(
                      rows: const [
                        ('0 – 30s',  'BOY        x1.0'),
                        ('30 – 60s', 'MAN        x1.5'),
                        ('1 – 2m',   'SORCERER   x2.0'),
                        ('2m+',      'BIHARI      x3.0'),
                      ],
                    ),

                    SizedBox(height: 48),

                    // ── Version ───────────────────────────────────────────────
                    Center(
                      child: Text(
                        'COLOR4PLANES  v1.0',
                        style: TextStyle(
                          color:         SpaceColors.asteroidGrey,
                          fontSize:      9,
                          fontFamily:    AppFonts.body,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14, color: SpaceColors.neonBlue),
      SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color:         SpaceColors.cometGrey,
          fontSize:      11,
          fontFamily:    AppFonts.body,
          fontWeight:    FontWeight.bold,
          letterSpacing: 4.0,
        ),
      ),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  final String    label;
  final String    description;
  final IconData  icon;
  final bool      value;
  final Color     accentColor;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(
        color: value ? accentColor.withValues(alpha: 0.4) : SpaceColors.dividerLine,
        width: 1,
      ),
      borderRadius: BorderRadius.circular(4),
      color: value ? accentColor.withValues(alpha: 0.06) : Colors.transparent,
    ),
    child: Row(
      children: [
        Icon(icon, color: value ? accentColor : SpaceColors.asteroidGrey, size: 20),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:         value ? SpaceColors.starWhite : SpaceColors.cometGrey,
                  fontSize:      13,
                  fontFamily:    AppFonts.body,
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color:      SpaceColors.asteroidGrey,
                  fontSize:   10,
                  fontFamily: AppFonts.body,
                ),
              ),
            ],
          ),
        ),
        // Custom retro toggle
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 44, height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value ? accentColor : SpaceColors.asteroidGrey,
                width: 1,
              ),
              color: value ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: value ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? accentColor : SpaceColors.asteroidGrey,
                    boxShadow: value
                        ? [BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 6)]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: SpaceColors.dividerLine, width: 1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              r.$1,
              style: TextStyle(
                color:         Colors.white70,
                fontSize:      12,
                fontFamily:    AppFonts.body,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                r.$2,
                style: TextStyle(
                  color:         Colors.white54,
                  fontSize:      12,
                  fontFamily:    AppFonts.body,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      )).toList(),
    ),
  );
}
