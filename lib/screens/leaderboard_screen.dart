// lib/screens/leaderboard_screen.dart
//
// Global top scores from Nakama's built-in leaderboard.
// Uses a FutureProvider to load data once on entry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/leaderboard_entry.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/services/nakama_service.dart';
import 'package:color4planes/widgets/starfield_background.dart';

final _leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  return NakamaService.instance.getLeaderboard(limit: 50);
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lb      = ref.watch(_leaderboardProvider);
    final myId    = ref.watch(currentUserProvider)?.id;

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
                    Text('LEADERBOARD', style: TextStyle(
                      color: SpaceColors.starWhite, fontSize: 18,
                      fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                      letterSpacing: 6.0,
                    )),
                  ],
                ),
              ),

              // ── Divider ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SpaceColors.neonBlue, Colors.transparent, SpaceColors.neonRed],
                  ),
                ),
              ),

              SizedBox(height: 8),

              // ── Column headers ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('RANK', style: _headerStyle)),
                    Expanded(child: Text('PILOT', style: _headerStyle)),
                    Text('SCORE', style: _headerStyle),
                  ],
                ),
              ),

              // ── List ───────────────────────────────────────────────────
              Expanded(
                child: lb.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: SpaceColors.neonBlue),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: SpaceColors.asteroidGrey, size: 40),
                          SizedBox(height: 12),
                          Text('Could not load leaderboard',
                              style: TextStyle(
                                  color: SpaceColors.cometGrey, fontSize: 13,
                                  fontFamily: AppFonts.body)),
                          SizedBox(height: 4),
                          Text(e.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: SpaceColors.asteroidGrey, fontSize: 10,
                                  fontFamily: AppFonts.body)),
                        ],
                      ),
                    ),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                color: SpaceColors.asteroidGrey, size: 48),
                            SizedBox(height: 12),
                            Text('NO SCORES YET', style: TextStyle(
                              color: SpaceColors.cometGrey, fontSize: 14,
                              fontFamily: AppFonts.body, letterSpacing: 4,
                            )),
                            SizedBox(height: 4),
                            Text('Play a game to be the first!', style: TextStyle(
                              color: SpaceColors.asteroidGrey, fontSize: 11,
                              fontFamily: AppFonts.body,
                            )),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e   = entries[i];
                        final isMe = e.userId == myId;
                        return _LeaderboardRow(entry: e, isMe: isMe);
                      },
                    );
                  },
                ),
              ),

              // ── Refresh button ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => ref.invalidate(_leaderboardProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                      color: SpaceColors.neonBlue.withValues(alpha: 0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: SpaceColors.neonBlue, size: 16),
                        SizedBox(width: 8),
                        Text('REFRESH', style: TextStyle(
                          color: SpaceColors.neonBlue, fontSize: 11,
                          fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _headerStyle = TextStyle(
    color: SpaceColors.asteroidGrey, fontSize: 9,
    fontFamily: AppFonts.body, letterSpacing: 2,
  );
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  const _LeaderboardRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (entry.rank) {
      1 => SpaceColors.sunflare,
      2 => SpaceColors.blueGlow,
      3 => SpaceColors.redGlow,
      _ => SpaceColors.cometGrey,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: isMe
              ? SpaceColors.neonBlue.withValues(alpha: 0.5)
              : SpaceColors.dividerLine,
        ),
        borderRadius: BorderRadius.circular(4),
        color: isMe
            ? SpaceColors.neonBlue.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: rankColor, fontSize: 14,
                fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                shadows: entry.rank <= 3
                    ? [Shadow(color: rankColor.withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
          // Name
          Expanded(
            child: Row(
              children: [
                if (isMe)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text('YOU', style: TextStyle(
                      color: SpaceColors.neonBlue, fontSize: 7,
                      fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                    )),
                  ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.displayName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? SpaceColors.starWhite : SpaceColors.cometGrey,
                          fontSize: 12, fontFamily: AppFonts.body,
                          fontWeight: FontWeight.bold, letterSpacing: 1,
                        ),
                      ),
                      if (entry.username.isNotEmpty)
                        Text(
                          '@${entry.username}',
                          style: TextStyle(
                            color: SpaceColors.asteroidGrey, fontSize: 8,
                            fontFamily: AppFonts.body, letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Score
          Text(
            entry.score.toString().padLeft(6, '0'),
            style: TextStyle(
              color: SpaceColors.sunflare, fontSize: 14,
              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: [Shadow(color: SpaceColors.sunflare.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}
