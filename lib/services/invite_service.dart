import 'dart:math';

import 'package:share_plus/share_plus.dart';

/// Invite codes for private groups: 6 unambiguous characters
/// (no 0/O, 1/I/L to avoid confusion when read aloud).
class InviteService {
  static const String _chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  /// Generates a random 6-character invite code.
  static String generateInviteCode() {
    return List.generate(
      6,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }

  /// Opens the system share sheet with the invite text.
  static Future<void> shareInvite({
    required String groupName,
    required String inviteCode,
  }) {
    return Share.share(
      'Join my 4cus accountability group "$groupName"! '
      'Open 4cus, tap Join with code, and enter: $inviteCode',
      subject: 'Join my 4cus group',
    );
  }

  /// Extracts a 6-character invite code from pasted text, or null.
  static String? parseInviteCode(String text) {
    final match = RegExp(r'\b([A-HJ-NP-Z2-9]{6})\b')
        .firstMatch(text.toUpperCase());
    return match?.group(1);
  }

  /// True when the input looks like a complete invite code.
  static bool isValidCodeFormat(String code) {
    return RegExp(r'^[A-HJ-NP-Z2-9]{6}$')
        .hasMatch(code.trim().toUpperCase());
  }
}
