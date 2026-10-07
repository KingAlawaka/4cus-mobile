import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'services/usage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase is not configured yet (placeholder firebase_options.dart).
    // The app shows a friendly setup screen instead of crashing.
    firebaseError = e.toString();
    debugPrint('4cus: Firebase init failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<UsageService>(create: (_) => UsageService()),
        ChangeNotifierProvider<AuthState>(
          create: (context) => AuthState(
            context.read<AuthService>(),
            context.read<FirestoreService>(),
          ),
        ),
        ChangeNotifierProvider<GroupsState>(
          create: (context) =>
              GroupsState(context.read<FirestoreService>()),
        ),
        ChangeNotifierProvider<TasksState>(
          create: (context) => TasksState(context.read<FirestoreService>()),
        ),
        ChangeNotifierProvider<UsageState>(
          create: (context) => UsageState(
            context.read<FirestoreService>(),
            context.read<UsageService>(),
          ),
        ),
      ],
      child: FourcusApp(firebaseError: firebaseError),
    ),
  );
}
