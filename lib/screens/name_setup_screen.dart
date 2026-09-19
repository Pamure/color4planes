// lib/screens/name_setup_screen.dart
//
// Shown only on first launch (or when display name is still 'Pilot').
// Saves name to Nakama + SharedPreferences, then goes to home.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class NameSetupScreen extends ConsumerStatefulWidget {
  const NameSetupScreen({super.key});

  @override
  ConsumerState<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends ConsumerState<NameSetupScreen> {
  // TextEditingController: bridges a TextFormField with your code.
  // controller.text = what's currently typed. controller.clear() clears it.
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();  // lets us call _form.currentState!.validate()

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();  // ALWAYS dispose controllers to avoid memory leaks
    super.dispose();
  }

  // Called when user taps CONFIRM
  Future<void> _save() async {
    // validate() calls all validator functions in the Form and returns true if all pass
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() { _saving = true; _error = null; });

    try {
      final name = _ctrl.text.trim();
      // Save to Nakama server (updates the display name on the account)
      await ref.read(authProvider.notifier).setDisplayName(name);
      // Navigate to home — never come back here (go replaces the stack)
      if (mounted) context.go(RoutePaths.home);
    } catch (e) {
      setState(() { _error = 'Could not save. Check connection.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('CHOOSE YOUR', style: TextStyle(
                        color: SpaceColors.asteroidGrey, fontSize: 11,
                        fontFamily: AppFonts.body, letterSpacing: 4.0,
                      )),
                      Text('PILOT NAME', style: TextStyle(
                        color: SpaceColors.neonBlue, fontSize: 32,
                        fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                        letterSpacing: 6.0,
                        shadows: [Shadow(color: SpaceColors.neonBlue, blurRadius: 20)],
                      )),
                      SizedBox(height: 40),

                      // TextFormField = TextField with built-in Form validation
                      TextFormField(
                        controller: _ctrl,
                        autofocus: true,
                        maxLength: 20,  // Nakama accepts up to 255 chars but we cap at 20
                        style: TextStyle(
                          color: SpaceColors.starWhite, fontFamily: AppFonts.body,
                          fontSize: 18, letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        cursorColor: SpaceColors.neonBlue,
                        decoration: InputDecoration(
                          hintText: 'e.g. StarPilot99',
                          hintStyle: TextStyle(color: SpaceColors.faint, fontFamily: AppFonts.body),
                          counterStyle: TextStyle(color: SpaceColors.faint, fontSize: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: SpaceColors.dividerLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: SpaceColors.neonBlue),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: SpaceColors.neonRed),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: SpaceColors.neonRed, width: 2),
                          ),
                          filled: true,
                          fillColor: SpaceColors.hudBackground,
                        ),
                        // validator runs when _form.currentState!.validate() is called
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
                          if (value.trim().length < 2) return 'At least 2 characters';
                          if (value.trim().length > 20) return 'Max 20 characters';
                          // Regex: only letters, digits, underscores — no special chars
                          final valid = RegExp(r'^[a-zA-Z0-9_]+$');
                          if (!valid.hasMatch(value.trim())) return 'Letters, digits, _ only';
                          return null;  // null = valid
                        },
                      ),

                      if (_error != null) ...[
                        SizedBox(height: 10),
                        Text(_error!, style: TextStyle(color: SpaceColors.neonRed, fontSize: 11, fontFamily: AppFonts.body)),
                      ],

                      SizedBox(height: 28),

                      // ── Confirm button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _saving ? null : _save,  // null = disabled while saving
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(4),
                              color: SpaceColors.neonBlue.withValues(alpha: 0.12),
                            ),
                            child: _saving
                                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: SpaceColors.neonBlue, strokeWidth: 2)))
                                : Text('CONFIRM PILOT NAME', textAlign: TextAlign.center, style: TextStyle(
                                    color: SpaceColors.neonBlue, fontSize: 13,
                                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                    letterSpacing: 3.0,
                                  )),
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
