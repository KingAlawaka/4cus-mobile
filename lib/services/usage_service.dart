import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Result of one day's phone-usage query (Android only).
class UsageStats {
  final int totalMinutes;
  final int unlocks;
  final List<UsageApp> apps;

  const UsageStats({
    required this.totalMinutes,
    required this.unlocks,
    required this.apps,
  });

  factory UsageStats.fromMap(Map<dynamic, dynamic> map) {
    final appsRaw = map['apps'];
    return UsageStats(
      totalMinutes: (map['totalMinutes'] ?? 0) as int,
      unlocks: (map['unlocks'] ?? 0) as int,
      apps: appsRaw is List
          ? appsRaw
              .whereType<Map>()
              .map((m) => UsageApp.fromMap(
                  m.map((k, v) => MapEntry(k.toString(), v))))
              .toList()
          : const [],
    );
  }
}

/// Talks to native Android UsageStatsManager over a MethodChannel.
/// On iOS/web (or channel failure) returns null and the app falls back
/// to in-app focus sessions (see UsageState).
class UsageService {
  static const MethodChannel _channel =
      MethodChannel('dev.fourcus/usage');

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<bool> hasPermission() async {
    if (!isAndroid) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('hasPermission');
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('4cus: hasPermission failed: $e');
      return false;
    }
  }

  /// Opens the system Usage Access settings screen.
  Future<void> requestPermission() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } on PlatformException catch (e) {
      debugPrint('4cus: requestPermission failed: $e');
    }
  }

  /// Returns stats for the given day, or null on non-Android / failure.
  Future<UsageStats?> getUsageStats(DateTime date) async {
    if (!isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getUsageStats',
        {'dateKey': dateKeyFromDate(date)},
      );
      if (result == null) return null;
      return UsageStats.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint('4cus: getUsageStats failed: $e');
      return null;
    }
  }
}

/// ---------- Focus score + coaching heuristics ----------
///
/// focusScore: 100 when screen time is 0, 0 when it hits the target,
/// clamped to [0, 100].
int focusScore({
  required int screenMinutes,
  required int targetMinutes,
}) {
  if (targetMinutes <= 0) return 100;
  final ratio = screenMinutes / targetMinutes;
  return (100 - ratio * 100).clamp(0, 100).round();
}

/// Coaching message based on screen time as a fraction of the target.
///
/// NOTE (roadmap): these static thresholds are a starting point. They are
/// meant to be replaced by a small on-device LLM (e.g. flutter_gemma) that
/// generates personal milestones and coaching from local usage history —
/// without sending any user data to the cloud.
String coachingMessage({
  required int screenMinutes,
  required int targetMinutes,
}) {
  if (targetMinutes <= 0) {
    return 'Set a daily screen-time target to start coaching.';
  }
  final ratio = screenMinutes / targetMinutes;
  if (ratio < 0.5) {
    return 'On track — screen time is well under your target. '
        'Keep the momentum on your goals.';
  }
  if (ratio < 1.0) {
    return 'Halfway to your limit. A short focus session now can '
        'keep the rest of the day on your goals.';
  }
  return 'Over target for today. Put the phone down, reset, and '
      'let your group know what you are working on next.';
}

/// Coaching message for the in-app focus-session mode (iOS/web).
String focusSessionCoachingMessage({
  required int focusMinutes,
  required int targetMinutes,
}) {
  if (targetMinutes <= 0) {
    return 'Set a daily focus target to start coaching.';
  }
  if (focusMinutes >= targetMinutes) {
    return 'Target reached — $focusMinutes focused minutes today. '
        'Your group will be proud.';
  }
  if (focusMinutes >= targetMinutes / 2) {
    return 'Halfway to your focus target. One more session and '
        'you are there.';
  }
  final remaining = targetMinutes - focusMinutes;
  return '$remaining focused minutes to go today. Start a session '
      'and give your goal your full attention.';
}
