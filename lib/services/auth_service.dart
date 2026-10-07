import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models.dart';
import 'firestore_service.dart';

/// Wraps FirebaseAuth: email sign-in/up, Google sign-in, sign-out,
/// and ensures a Firestore user document exists on first login.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestore = FirestoreService();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureUserDoc(credential.user);
    return credential;
  }

  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }
    await _ensureUserDoc(user, displayName: name.trim());
    return credential;
  }

  /// Classic google_sign_in ^6 API.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled the Google sign-in flow.
      return null;
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential =
        await _auth.signInWithCredential(credential);
    await _ensureUserDoc(userCredential.user);
    return userCredential;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Creates the users/{uid} document on first login so profile,
  /// onboarding and preferences always have a backing record.
  Future<void> _ensureUserDoc(User? user, {String? displayName}) async {
    if (user == null) return;
    try {
      final existing = await _firestore.getUser(user.uid);
      if (existing != null) return;
      final name = (displayName?.isNotEmpty ?? false)
          ? displayName!.trim()
          : (user.displayName?.isNotEmpty ?? false)
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'Member');
      await _firestore.upsertUser(
        AppUser(
          uid: user.uid,
          name: name,
          email: user.email ?? '',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      // Non-fatal: the user is signed in; the doc write can be
      // retried by the next app start.
      debugPrint('4cus: failed to ensure user doc: $e');
    }
  }
}

/// Maps FirebaseAuthException codes to friendly messages for the UI.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Try signing in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
