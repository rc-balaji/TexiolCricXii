import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scope.dart';

class CricXiiApp extends StatelessWidget {
  const CricXiiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CricXii by Texiol',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const _AppGate(),
  );
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!store.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.requiresAuthentication) return const AuthScreen();
    return store.activePlayer == null
        ? const OnboardingScreen()
        : const HomeShell();
  }
}
