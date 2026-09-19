// lib/screens/profile_screen.dart
//
// "Pilot Dossier" — player stats at a glance.
// Reads from statsProvider (AsyncNotifier backed by Nakama cloud storage).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/providers/stats_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(currentUserProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(Icons.arrow_back_ios_rounded,
                          color: SpaceColors.cometGrey, size: 20),
                    ),
                    SizedBox(width: 16),
                    Text('PILOT DOSSIER', style: TextStyle(
                      color: SpaceColors.starWhite, fontSize: 18,
                      fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                      letterSpacing: 6.0,
                    )),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // ── Pilot Identity ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                        color: SpaceColors.hudBackground,
                      ),
                      child: Column(
                        children: [
                          // Avatar circle
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [SpaceColors.neonBlue, SpaceColors.neonRed],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: SpaceColors.neonBlue.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (user?.displayName ?? 'P')[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white, fontSize: 28,
                                  fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            (user?.displayName ?? 'Pilot').toUpperCase(),
                            style: TextStyle(
                              color: SpaceColors.starWhite, fontSize: 20,
                              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'PILOT ID: ${(user?.id ?? 'unknown').substring(0, 8).toUpperCase()}...',
                            style: TextStyle(
                              color: SpaceColors.asteroidGrey, fontSize: 9,
                              fontFamily: AppFonts.body, letterSpacing: 2,
                            ),
                          ),
                          if (user?.username != null && user!.username.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(4),
                                color: SpaceColors.neonBlue.withValues(alpha: 0.06),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('USERNAME: ', style: TextStyle(
                                    color: SpaceColors.asteroidGrey, fontSize: 12,
                                    fontFamily: AppFonts.body, letterSpacing: 2,
                                  )),
                                  Flexible(
                                    child: SelectableText(
                                      user.username,
                                      style: TextStyle(
                                        color: SpaceColors.blueGlow, fontSize: 14,
                                        fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: user.username));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Username copied!',
                                            style: TextStyle(color: SpaceColors.starWhite, fontFamily: AppFonts.body, letterSpacing: 1.5)),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy_rounded, color: SpaceColors.neonBlue, size: 12),
                                          SizedBox(width: 4),
                                          Text('COPY', style: TextStyle(
                                            color: SpaceColors.neonBlue, fontSize: 12,
                                            fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                          )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ── Stats ──────────────────────────────────────────────
                    stats.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: SpaceColors.neonBlue),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Text('Could not load stats',
                            style: TextStyle(
                                color: SpaceColors.cometGrey, fontSize: 15,
                                fontFamily: AppFonts.body)),
                      ),
                      data: (s) => Column(
                        children: [
                          // ── Highlight stats ──────────────────────────────
                          Row(
                            children: [
                              Expanded(child: _BigStat(
                                label: 'BEST SCORE',
                                value: s.bestScore.toString().padLeft(6, '0'),
                                color: SpaceColors.sunflare,
                              )),
                              SizedBox(width: 8),
                              Expanded(child: _BigStat(
                                label: 'WIN RATE',
                                value: '${s.winRate.toStringAsFixed(1)}%',
                                color: SpaceColors.difficultyBoy,
                              )),
                            ],
                          ),

                          SizedBox(height: 16),

                          // ── All stats ──────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.dividerLine),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: [
                                _StatRow(label: 'GAMES PLAYED', value: s.totalGamesPlayed.toString()),
                                _StatRow(label: 'TOTAL KILLS', value: s.totalKills.toString()),
                                _StatRow(label: 'WINS', value: s.totalWins.toString(), color: SpaceColors.difficultyBoy),
                                _StatRow(label: 'LOSSES', value: s.totalLosses.toString(), color: SpaceColors.neonRed),
                                _StatRow(label: 'TIME PLAYED', value: s.totalTimePlayed),
                                _StatRow(label: 'SHOTS FIRED', value: s.totalShotsFired.toString()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // ── Refresh ──────────────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () => ref.invalidate(statsProvider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: SpaceColors.neonBlue, size: 14),
                              SizedBox(width: 6),
                              Text('REFRESH', style: TextStyle(
                                color: SpaceColors.neonBlue, fontSize: 13,
                                fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _BigStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(4),
      color: color.withValues(alpha: 0.06),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(
          color: SpaceColors.asteroidGrey, fontSize: 12,
          fontFamily: AppFonts.body, letterSpacing: 2,
        )),
        SizedBox(height: 6),
        Text(value, style: TextStyle(
          color: color, fontSize: 22,
          fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
          letterSpacing: 2,
          shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10)],
        )),
      ],
    ),
  );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: SpaceColors.cometGrey, fontSize: 11,
          fontFamily: AppFonts.body, letterSpacing: 2,
        )),
        Text(value, style: TextStyle(
          color: color ?? SpaceColors.starWhite, fontSize: 14,
          fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
          letterSpacing: 1,
        )),
      ],
    ),
  );
}
