// Firebase configuration placeholders for the 4cus app.
//
// Run `flutterfire configure` (see FIREBASE_SETUP.md) to generate the real
// values for this file. Until then, every value below is a placeholder and
// Firebase.initializeApp() will fail gracefully — the app shows a friendly
// "Firebase not configured" screen instead of crashing.
//
// Do NOT commit real API keys to a public repository. The values produced by
// `flutterfire configure` are safe to commit for most projects, but keep them
// out of version control if your security policy requires it.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder Firebase options. Replace via `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run `flutterfire configure` (see FIREBASE_SETUP.md).',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO-REPLACE',
    appId: 'TODO-REPLACE',
    messagingSenderId: 'TODO-REPLACE',
    projectId: 'TODO-REPLACE',
    authDomain: 'TODO-REPLACE',
    storageBucket: 'TODO-REPLACE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO-REPLACE',
    appId: 'TODO-REPLACE',
    messagingSenderId: 'TODO-REPLACE',
    projectId: 'TODO-REPLACE',
    storageBucket: 'TODO-REPLACE',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO-REPLACE',
    appId: 'TODO-REPLACE',
    messagingSenderId: 'TODO-REPLACE',
    projectId: 'TODO-REPLACE',
    storageBucket: 'TODO-REPLACE',
    iosBundleId: 'com.fourcus.fourcus',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TODO-REPLACE',
    appId: 'TODO-REPLACE',
    messagingSenderId: 'TODO-REPLACE',
    projectId: 'TODO-REPLACE',
    storageBucket: 'TODO-REPLACE',
    iosBundleId: 'com.fourcus.fourcus',
  );
}
