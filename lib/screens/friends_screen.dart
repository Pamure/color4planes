// lib/screens/friends_screen.dart
//
// Friends management: view your Pilot ID, add friends, see list, accept/remove.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/friend_model.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/services/nakama_service.dart';
import 'package:color4planes/widgets/starfield_background.dart';

final _friendsProvider = FutureProvider<List<FriendModel>>((ref) async {
  return NakamaService.instance.getFriends();
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _idCtrl   = TextEditingController();
  bool _adding    = false;
  bool _addByUsername = false;
  String? _msg;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh friends list every 15 seconds for online status updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(_friendsProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;

    setState(() { _adding = true; _msg = null; });
    try {
      if (_addByUsername) {
        await NakamaService.instance.addFriendByUsername(id);
      } else {
        await NakamaService.instance.addFriend(id);
      }
      _idCtrl.clear();
      setState(() { _msg = 'Friend request sent!'; _adding = false; });
      ref.invalidate(_friendsProvider);
    } catch (e) {
      setState(() { _msg = 'Failed: ${e.toString().replaceAll('Exception: ', '')}'; _adding = false; });
    }
  }

  Future<void> _accept(String userId) async {
    await NakamaService.instance.acceptFriend(userId);
    ref.invalidate(_friendsProvider);
  }

  Future<void> _remove(String userId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceColors.deepSpace,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: SpaceColors.dividerLine),
        ),
        title: Text('REMOVE FRIEND', style: TextStyle(
          color: SpaceColors.starWhite, fontSize: 14,
          fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
          letterSpacing: 3,
        )),
        content: Text(
          'Remove ${displayName.toUpperCase()} from your friends?',
          style: TextStyle(
            color: SpaceColors.cometGrey, fontSize: 12,
            fontFamily: AppFonts.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(
              color: SpaceColors.cometGrey, fontSize: 11,
              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
            )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('REMOVE', style: TextStyle(
              color: SpaceColors.neonRed, fontSize: 11,
              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
            )),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NakamaService.instance.removeFriend(userId);
      ref.invalidate(_friendsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(currentUserProvider);
    final friends = ref.watch(_friendsProvider);

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
                    Text('FRIENDS', style: TextStyle(
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
                    // ── Your Pilot ID ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: SpaceColors.dividerLine),
                        borderRadius: BorderRadius.circular(4),
                        color: SpaceColors.hudBackground,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR PILOT ID', style: TextStyle(
                            color: SpaceColors.asteroidGrey, fontSize: 9,
                            fontFamily: AppFonts.body, letterSpacing: 3,
                          )),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user?.id ?? 'Unknown',
                                  style: TextStyle(
                                    color: SpaceColors.blueGlow, fontSize: 11,
                                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  if (user?.id != null) {
                                    Clipboard.setData(ClipboardData(text: user!.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Pilot ID copied!',
                                          style: TextStyle(color: SpaceColors.starWhite, fontFamily: AppFonts.body, letterSpacing: 1.5)),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(4),
                                    color: SpaceColors.neonBlue.withValues(alpha: 0.1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, color: SpaceColors.neonBlue, size: 12),
                                      SizedBox(width: 4),
                                      Text('COPY', style: TextStyle(
                                        color: SpaceColors.neonBlue, fontSize: 9,
                                        fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Share this ID with friends (if you have any )',
                            style: TextStyle(
                              color: SpaceColors.asteroidGrey, fontSize: 9,
                              fontFamily: AppFonts.body,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ── Add Friend ─────────────────────────────────────────
                    Text('ADD FRIEND', style: TextStyle(
                      color: SpaceColors.cometGrey, fontSize: 10,
                      fontFamily: AppFonts.body, letterSpacing: 3,
                    )),
                    SizedBox(height: 8),
                    // Toggle: ID vs Username
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() { _addByUsername = false; _idCtrl.clear(); _msg = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: !_addByUsername ? SpaceColors.neonBlue : SpaceColors.dividerLine),
                              borderRadius: BorderRadius.circular(4),
                              color: !_addByUsername ? SpaceColors.neonBlue.withValues(alpha: 0.15) : Colors.transparent,
                            ),
                            child: Text('BY ID', style: TextStyle(
                              color: !_addByUsername ? SpaceColors.neonBlue : SpaceColors.asteroidGrey,
                              fontSize: 9, fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            )),
                          ),
                        ),
                        SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() { _addByUsername = true; _idCtrl.clear(); _msg = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: _addByUsername ? SpaceColors.neonBlue : SpaceColors.dividerLine),
                              borderRadius: BorderRadius.circular(4),
                              color: _addByUsername ? SpaceColors.neonBlue.withValues(alpha: 0.15) : Colors.transparent,
                            ),
                            child: Text('BY USERNAME', style: TextStyle(
                              color: _addByUsername ? SpaceColors.neonBlue : SpaceColors.asteroidGrey,
                              fontSize: 9, fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            )),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _idCtrl,
                            style: TextStyle(
                              color: SpaceColors.starWhite, fontSize: 12,
                              fontFamily: AppFonts.body,
                            ),
                            cursorColor: SpaceColors.neonBlue,
                            decoration: InputDecoration(
                              hintText: _addByUsername ? 'Enter username...' : 'Paste Pilot ID...',
                              hintStyle: TextStyle(color: SpaceColors.faint, fontSize: 11, fontFamily: AppFonts.body),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: SpaceColors.dividerLine),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: SpaceColors.neonBlue),
                              ),
                              filled: true,
                              fillColor: SpaceColors.hudBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: _adding ? null : _addFriend,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(4),
                              color: SpaceColors.neonBlue.withValues(alpha: 0.12),
                            ),
                            child: _adding
                                ? SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(color: SpaceColors.neonBlue, strokeWidth: 2))
                                : Text('ADD', style: TextStyle(
                                    color: SpaceColors.neonBlue, fontSize: 11,
                                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  )),
                          ),
                        ),
                      ],
                    ),
                    if (_msg != null) ...[
                      SizedBox(height: 8),
                      Text(_msg!, style: TextStyle(
                        color: _msg!.contains('sent') ? SpaceColors.difficultyBoy : SpaceColors.neonRed,
                        fontSize: 10, fontFamily: AppFonts.body,
                      )),
                    ],

                    SizedBox(height: 28),

                    // ── Friend List ───────────────────────────────────────
                    Text('FRIEND LIST', style: TextStyle(
                      color: SpaceColors.cometGrey, fontSize: 10,
                      fontFamily: AppFonts.body, letterSpacing: 3,
                    )),
                    SizedBox(height: 12),

                    friends.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: SpaceColors.neonBlue),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Could not load friends',
                              style: TextStyle(
                                  color: SpaceColors.cometGrey, fontSize: 12,
                                  fontFamily: AppFonts.body)),
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.dividerLine),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    color: SpaceColors.asteroidGrey, size: 32),
                                SizedBox(height: 8),
                                Text('NO FRIENDS YET ( touch some grass )', style: TextStyle(
                                  color: SpaceColors.cometGrey, fontSize: 12,
                                  fontFamily: AppFonts.body, letterSpacing: 3,
                                )),
                                SizedBox(height: 4),
                                Text('Share your Pilot ID to get started',
                                    style: TextStyle(
                                      color: SpaceColors.asteroidGrey, fontSize: 10,
                                      fontFamily: AppFonts.body,
                                    )),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: list.map((f) => _FriendTile(
                            friend: f,
                            onAccept: () => _accept(f.userId),
                            onRemove: () => _remove(f.userId, f.displayName),
                          )).toList(),
                        );
                      },
                    ),

                    SizedBox(height: 24),

                    // ── Refresh ─────────────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () => ref.invalidate(_friendsProvider),
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
                                color: SpaceColors.neonBlue, fontSize: 10,
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

class _FriendTile extends StatelessWidget {
  final FriendModel  friend;
  final VoidCallback onAccept;
  final VoidCallback onRemove;
  const _FriendTile({required this.friend, required this.onAccept, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (friend.friendState) {
      FriendState.mutual     => (friend.online ? 'ONLINE' : 'OFFLINE',
                                  friend.online ? SpaceColors.difficultyBoy : SpaceColors.asteroidGrey),
      FriendState.sentByMe   => ('PENDING', SpaceColors.sunflare),
      FriendState.sentByThem => ('WANTS TO ADD YOU', SpaceColors.neonBlue),
      FriendState.blocked    => ('BLOCKED', SpaceColors.neonRed),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: SpaceColors.dividerLine),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Online indicator
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: friend.online && friend.friendState == FriendState.mutual
                  ? [BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SpaceColors.starWhite, fontSize: 12,
                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                if (friend.username.isNotEmpty)
                  Text('@${friend.username}', style: TextStyle(
                    color: SpaceColors.asteroidGrey, fontSize: 8,
                    fontFamily: AppFonts.body, letterSpacing: 1,
                  )),
                SizedBox(height: 2),
                Text(statusLabel, style: TextStyle(
                  color: statusColor, fontSize: 9,
                  fontFamily: AppFonts.body, letterSpacing: 2,
                )),
              ],
            ),
          ),
          // Actions
          if (friend.friendState == FriendState.sentByThem)
            GestureDetector(
              onTap: onAccept,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: SpaceColors.difficultyBoy.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                  color: SpaceColors.difficultyBoy.withValues(alpha: 0.1),
                ),
                child: Text('ACCEPT', style: TextStyle(
                  color: SpaceColors.difficultyBoy, fontSize: 9,
                  fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                )),
              ),
            ),
          if (friend.friendState != FriendState.blocked)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: SpaceColors.neonRed.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.close_rounded, color: SpaceColors.neonRed, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
