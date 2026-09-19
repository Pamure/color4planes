// lib/overlays/game_over_overlay.dart
//
// REDESIGN: Retro "mission debrief" terminal.
// Full-screen overlay — no tiny card, everything breathes.
// Score is the centrepiece. Stats are monospace terminal output.
import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';

class GameOverOverlay extends StatefulWidget {
  final Map<String, String> summary;
  final int                 highScore;
  final VoidCallback        onRestart;
  final VoidCallback        onMainMenu;

  const GameOverOverlay({
    super.key,
    required this.summary,
    required this.highScore,
    required this.onRestart,
    required this.onMainMenu,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final currentScore = int.tryParse(widget.summary['Score'] ?? '0') ?? 0;
    final isNewHigh    = widget.highScore > 0 && currentScore >= widget.highScore;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          color: const Color(0xDD020616),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      // ── Header ────────────────────────────────────────────
                      CornerBracket(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            children: [
                              Text(
                                'MISSION FAILED',
                                style: TextStyle(
                                  color:         SpaceColors.asteroidGrey,
                                  fontSize:      10,
                                  fontFamily:    AppFonts.body,
                                  letterSpacing: 6.0,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'GAME OVER',
                                style: TextStyle(
                                  color:         SpaceColors.neonRed,
                                  fontSize:      36,
                                  fontFamily:    AppFonts.body,
                                  fontWeight:    FontWeight.w900,
                                  letterSpacing: 8.0,
                                  shadows: [
                                    Shadow(color: SpaceColors.neonRed, blurRadius: 24),
                                    Shadow(color: SpaceColors.neonRed, blurRadius: 48),
                                  ],
                                ),
                              ),
                              if (isNewHigh) ...[
                                SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(2),
                                    color: SpaceColors.sunflare.withValues(alpha: 0.08),
                                  ),
                                  child: Text(
                                    'NEW RECORD',
                                    style: TextStyle(
                                      color:         SpaceColors.sunflare,
                                      fontSize:      10,
                                      fontFamily:    AppFonts.body,
                                      fontWeight:    FontWeight.bold,
                                      letterSpacing: 4.0,
                                      shadows: [Shadow(color: SpaceColors.sunflare, blurRadius: 8)],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // ── Score ──────────────────────────────────────────────
                      Text(
                        currentScore.toString().padLeft(7, '0'),
                        style: TextStyle(
                          color:         SpaceColors.sunflare,
                          fontSize:      52,
                          fontFamily:    AppFonts.body,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(color: SpaceColors.sunflare, blurRadius: 20),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // ── Stats ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: SpaceColors.dividerLine),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: widget.summary.entries
                              .where((e) => e.key != 'Score')
                              .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      e.key.toUpperCase(),
                                      style: TextStyle(
                                        color:         SpaceColors.cometGrey,
                                        fontSize:      11,
                                        fontFamily:    AppFonts.body,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    Text(
                                      e.value,
                                      style: TextStyle(
                                        color:         SpaceColors.starWhite,
                                        fontSize:      13,
                                        fontFamily:    AppFonts.body,
                                        fontWeight:    FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                              .toList(),
                        ),
                      ),

                      SizedBox(height: 28),

                      // ── Action buttons ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _GameOverButton(
                              label:   'MENU',
                              icon:    Icons.home_outlined,
                              color:   SpaceColors.asteroidGrey,
                              outline: true,
                              onTap:   widget.onMainMenu,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _GameOverButton(
                              label: 'RETRY',
                              icon:  Icons.refresh_rounded,
                              color: SpaceColors.neonBlue,
                              onTap: widget.onRestart,
                            ),
                          ),
                        ],
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

/// Draws corner-bracket decoration around its child (retro terminal style).
class CornerBracket extends StatelessWidget {
  final Widget child;
  const CornerBracket({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BracketPainter(),
    child: child,
  );
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = SpaceColors.neonRed.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    const len = 16.0;
    // TL
    canvas.drawLine(Offset.zero,           Offset(len, 0),         paint);
    canvas.drawLine(Offset.zero,           Offset(0, len),         paint);
    // TR
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len),     paint);
    // BL
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height),         paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len),     paint);
    // BR
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _GameOverButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      outline;
  final VoidCallback onTap;

  const _GameOverButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: outline ? 0.4 : 0.6)),
        color: outline ? Colors.transparent : color.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color:         color,
              fontSize:      13,
              fontFamily:    AppFonts.body,
              fontWeight:    FontWeight.bold,
              letterSpacing: 3.0,
              shadows: outline ? null : [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)],
            ),
          ),
        ],
      ),
    ),
  );
}
