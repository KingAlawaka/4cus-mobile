import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection; // intl also exports TextDirection (bidi); hide it to keep Flutter's enum

/// ---------- Date helpers ----------

/// Canonical per-day key used for check-in and usage-day document IDs.
String dateKeyFromDate(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(date);

String todayKey() => dateKeyFromDate(DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

Map<String, String> _stringMap(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return const {};
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

/// ---------- AppUser ----------
///
/// Firestore: users/{uid}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool onboardingDone;
  final int focusTargetMinutes;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.onboardingDone = false,
    this.focusTargetMinutes = 120,
    this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      onboardingDone: (map['onboardingDone'] ?? false) as bool,
      focusTargetMinutes: (map['focusTargetMinutes'] ?? 120) as int,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'onboardingDone': onboardingDone,
      'focusTargetMinutes': focusTargetMinutes,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? name,
    String? photoUrl,
    bool? onboardingDone,
    int? focusTargetMinutes,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      focusTargetMinutes: focusTargetMinutes ?? this.focusTargetMinutes,
      createdAt: createdAt,
    );
  }
}

/// ---------- GoalPost ----------
///
/// Public goal listing on the Discover tab.
/// Firestore: goal_posts/{postId}

class GoalPost {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final String category;
  final String groupId;
  final int memberCount;
  final DateTime? createdAt;

  const GoalPost({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.category,
    required this.groupId,
    this.memberCount = 1,
    this.createdAt,
  });

  bool get isFull => memberCount >= 4;

  factory GoalPost.fromMap(String id, Map<String, dynamic> map) {
    return GoalPost(
      id: id,
      ownerId: (map['ownerId'] ?? '') as String,
      ownerName: (map['ownerName'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? 'General') as String,
      groupId: (map['groupId'] ?? '') as String,
      memberCount: (map['memberCount'] ?? 1) as int,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title,
      'description': description,
      'category': category,
      'groupId': groupId,
      'memberCount': memberCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// ---------- Group ----------
///
/// A 4-person accountability group.
/// Firestore: groups/{groupId}

class Group {
  final String id;
  final String name;
  final String goalTitle;
  final String description;
  final String category;
  final bool isPrivate;
  final String inviteCode;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String? goalPostId;
  final DateTime? createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.goalTitle,
    required this.description,
    required this.category,
    required this.isPrivate,
    required this.inviteCode,
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    this.goalPostId,
    this.createdAt,
  });

  bool get isFull => memberIds.length >= 4;
  int get memberCount => memberIds.length;

  String memberName(String uid) => memberNames[uid] ?? 'Member';

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: (map['name'] ?? '') as String,
      goalTitle: (map['goalTitle'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? 'General') as String,
      isPrivate: (map['isPrivate'] ?? true) as bool,
      inviteCode: (map['inviteCode'] ?? '') as String,
      ownerId: (map['ownerId'] ?? '') as String,
      memberIds: _stringList(map['memberIds']),
      memberNames: _stringMap(map['memberNames']),
      goalPostId: map['goalPostId'] as String?,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'goalTitle': goalTitle,
      'description': description,
      'category': category,
      'isPrivate': isPrivate,
      'inviteCode': inviteCode,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'goalPostId': goalPostId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// ---------- ChatMessage ----------
///
/// Firestore: groups/{groupId}/messages/{messageId}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? text;
  final String? imageUrl;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.text,
    this.imageUrl,
    this.createdAt,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: (map['senderId'] ?? '') as String,
      senderName: (map['senderName'] ?? '') as String,
      text: map['text'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// ---------- CheckIn ----------
///
/// Daily photo check-in. Document ID: {uid}_{yyyy-MM-dd}.
/// Firestore: groups/{groupId}/checkins/{checkinId}

class CheckIn {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String dateKey;
  final String photoUrl;
  final String note;
  final List<String> verifiedBy;
  final DateTime? createdAt;

  const CheckIn({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.dateKey,
    required this.photoUrl,
    this.note = '',
    this.verifiedBy = const [],
    this.createdAt,
  });

  int get verifiedCount => verifiedBy.length;
  bool isVerifiedBy(String uid) => verifiedBy.contains(uid);

  static String docIdFor(String uid, String dateKey) => '${uid}_$dateKey';

  factory CheckIn.fromMap(String id, Map<String, dynamic> map) {
    return CheckIn(
      id: id,
      groupId: (map['groupId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      userName: (map['userName'] ?? '') as String,
      dateKey: (map['dateKey'] ?? '') as String,
      photoUrl: (map['photoUrl'] ?? '') as String,
      note: (map['note'] ?? '') as String,
      verifiedBy: _stringList(map['verifiedBy']),
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'dateKey': dateKey,
      'photoUrl': photoUrl,
      'note': note,
      'verifiedBy': verifiedBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// ---------- TaskItem ----------
///
/// Personal short-term goal / todo with an optional deadline.
/// Firestore: tasks/{taskId}

class TaskItem {
  final String id;
  final String ownerId;
  final String title;
  final String notes;
  final DateTime? dueAt;
  final bool done;
  final DateTime? createdAt;

  const TaskItem({
    required this.id,
    required this.ownerId,
    required this.title,
    this.notes = '',
    this.dueAt,
    this.done = false,
    this.createdAt,
  });

  bool get isOverdue =>
      !done && dueAt != null && dueAt!.isBefore(DateTime.now());

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    return TaskItem(
      id: id,
      ownerId: (map['ownerId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      dueAt: _toDate(map['dueAt']),
      done: (map['done'] ?? false) as bool,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'notes': notes,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'done': done,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  TaskItem copyWith({
    String? title,
    String? notes,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? done,
  }) {
    return TaskItem(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      done: done ?? this.done,
      createdAt: createdAt,
    );
  }
}

/// ---------- UsageApp ----------
///
/// Per-app screen-time breakdown (Android only).

class UsageApp {
  final String name;
  final int minutes;

  const UsageApp({required this.name, required this.minutes});

  factory UsageApp.fromMap(Map<String, dynamic> map) {
    return UsageApp(
      name: (map['name'] ?? '') as String,
      minutes: (map['minutes'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'minutes': minutes};
}

/// ---------- UsageDay ----------
///
/// One day of phone-usage / focus data. Document ID: {uid}_{yyyy-MM-dd}.
/// source: 'android' (UsageStatsManager) or 'inapp' (manual focus sessions).
/// Firestore: usage_days/{usageDayId}

class UsageDay {
  final String id;
  final String uid;
  final String dateKey;
  final int screenMinutes;
  final int unlocks;
  final int focusMinutes;
  final String source;
  final List<UsageApp> apps;
  final DateTime? updatedAt;

  const UsageDay({
    required this.id,
    required this.uid,
    required this.dateKey,
    this.screenMinutes = 0,
    this.unlocks = 0,
    this.focusMinutes = 0,
    this.source = 'android',
    this.apps = const [],
    this.updatedAt,
  });

  static String docIdFor(String uid, String dateKey) => '${uid}_$dateKey';

  factory UsageDay.fromMap(String id, Map<String, dynamic> map) {
    final appsRaw = map['apps'];
    return UsageDay(
      id: id,
      uid: (map['uid'] ?? '') as String,
      dateKey: (map['dateKey'] ?? '') as String,
      screenMinutes: (map['screenMinutes'] ?? 0) as int,
      unlocks: (map['unlocks'] ?? 0) as int,
      focusMinutes: (map['focusMinutes'] ?? 0) as int,
      source: (map['source'] ?? 'android') as String,
      apps: appsRaw is List
          ? appsRaw
              .whereType<Map<String, dynamic>>()
              .map(UsageApp.fromMap)
              .toList()
          : const [],
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'dateKey': dateKey,
      'screenMinutes': screenMinutes,
      'unlocks': unlocks,
      'focusMinutes': focusMinutes,
      'source': source,
      'apps': apps.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
