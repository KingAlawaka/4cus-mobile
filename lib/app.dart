import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Root widget. Routes:
///   Firebase not configured -> setup help screen
///   loading                 -> splash
///   onboarding not done     -> onboarding
///   signed out              -> auth
///   signed in               -> home
class FourcusApp extends StatelessWidget {
  final String? firebaseError;

  const FourcusApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '4cus',
      debugShowCheckedModeBanner: false,
      theme: FourcusTheme.light,
      darkTheme: FourcusTheme.dark,
      themeMode: ThemeMode.system,
      home: firebaseError != null
          ? FirebaseNotConfiguredScreen(error: firebaseError!)
          : const AuthGate(),
    );
  }
}

/// Decides which top-level screen to show based on auth + onboarding state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (auth.loading) {
      return const Scaffold(body: LoadingView(message: 'Loading 4cus…'));
    }
    if (!auth.onboardingDone) {
      return const OnboardingScreen();
    }
    if (!auth.signedIn) {
      return const AuthScreen();
    }
    return const HomeScreen();
  }
}

/// Shown when Firebase.initializeApp() failed (placeholder firebase_options).
class FirebaseNotConfiguredScreen extends StatelessWidget {
  final String error;

  const FirebaseNotConfiguredScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text('4cus', style: theme.textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Firebase is not configured yet',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'This build is still using the placeholder values in '
                'lib/firebase_options.dart. Follow FIREBASE_SETUP.md to '
                'create a Firebase project and run `flutterfire configure`, '
                'then rebuild the app.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const SectionHeader('Steps'),
              const SizedBox(height: 8),
              const _SetupStep('1', 'Create a Firebase project in the console'),
              const _SetupStep('2', 'Run `flutterfire configure`'),
              const _SetupStep('3', 'Enable Email/Password and Google sign-in'),
              const _SetupStep('4', 'Create Firestore + Storage, deploy the rules'),
              const Spacer(),
              Text(
                'Technical detail: $error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String text;

  const _SetupStep(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
