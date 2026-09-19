// lib/main.dart
//
// App entry point. Three responsibilities only:
//   1. WidgetsFlutterBinding.ensureInitialized() — must happen before any async
//   2. SystemChrome: lock portrait on mobile
//   3. ProviderScope + MaterialApp.router: wire Riverpod and go_router

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color4planes/core/app_router.dart';
import 'package:color4planes/core/responsive.dart';
import 'package:color4planes/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: ColorPlanesApp()));
}

class ColorPlanesApp extends ConsumerWidget {
  const ColorPlanesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title:                      'Color4Planes',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.darkTheme,
      routerConfig:               ref.watch(appRouterProvider),
      builder: (context, child) {
        // Globally scale ALL text on larger screens without manual per-widget scaling!
        final scale = Responsive.textScale(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
    );
  }
}
