import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'invite_service.dart';

/// All Firestore access for 4cus.
///
/// Collections:
///   users/{uid}
///   goal_posts/{postId}            (public discover feed)
///   groups/{groupId}
///   groups/{groupId}/messages/{id}
///   groups/{groupId}/checkins/{uid_yyyy-MM-dd}
///   tasks/{taskId}
///   usage_days/{uid_yyyy-MM-dd}
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= users =================

  Stream<AppUser?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists && d.data() != null
            ? AppUser.fromMap(d.id, d.data()!)
            : null);
  }

  Future<AppUser?> getUser(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    if (!d.exists || d.data() == null) return null;
    return AppUser.fromMap(d.id, d.data()!);
  }

  Future<void> upsertUser(AppUser user) {
    return _db
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserFields(
      String uid, Map<String, dynamic> fields) {
    return _db.collection('users').doc(uid).update(fields);
  }

  // ================= goal posts (discover) =================

  Stream<List<GoalPost>> discoverPostsStream() {
    return _db
        .collection('goal_posts')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => GoalPost.fromMap(d.id, d.data())).toList());
  }

  // ================= groups =================

  /// Creates a group and — when public — its linked discover post,
  /// atomically in one batch. Returns the group id + invite code.
  Future<({String groupId, String inviteCode})> createGroup({
    required String ownerId,
    required String ownerName,
    required String name,
    required String goalTitle,
    required String description,
    required String category,
    required bool isPrivate,
  }) async {
    final groupRef = _db.collection('groups').doc();
    final inviteCode = InviteService.generateInviteCode();
    final batch = _db.batch();

    String? postId;
    if (!isPrivate) {
      final postRef = _db.collection('goal_posts').doc();
      postId = postRef.id;
      batch.set(
        postRef,
        GoalPost(
          id: postRef.id,
          ownerId: ownerId,
          ownerName: ownerName,
          title: goalTitle,
          description: description,
          category: category,
          groupId: groupRef.id,
          memberCount: 1,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    }

    batch.set(
      groupRef,
      Group(
        id: groupRef.id,
        name: name.trim(),
        goalTitle: goalTitle.trim(),
        description: description.trim(),
        category: category,
        isPrivate: isPrivate,
        inviteCode: inviteCode,
        ownerId: ownerId,
        memberIds: [ownerId],
        memberNames: {ownerId: ownerName},
        goalPostId: postId,
        createdAt: DateTime.now(),
      ).toMap(),
    );

    await batch.commit();
    return (groupId: groupRef.id, inviteCode: inviteCode);
  }

  Stream<List<Group>> myGroupsStream(String uid) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Group.fromMap(d.id, d.data())).toList());
  }

  Stream<Group?> groupStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((d) => d.exists && d.data() != null
            ? Group.fromMap(d.id, d.data()!)
            : null);
  }

  Future<Group?> findGroupByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final q = await _db
        .collection('groups')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return Group.fromMap(q.docs.first.id, q.docs.first.data());
  }

  /// Joins a group in a transaction that enforces the 4-member cap and
  /// bumps the linked discover post's member count.
  Future<void> joinGroup({
    required String groupId,
    required String uid,
    required String userName,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found.');
      }
      final group = Group.fromMap(snap.id, snap.data()!);
      if (group.memberIds.contains(uid)) return; // already in
      if (group.memberIds.length >= 4) {
        throw Exception('This group is full (4/4).');
      }
      tx.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberNames': {...group.memberNames, uid: userName},
      });
      if (group.goalPostId != null) {
        tx.update(
          _db.collection('goal_posts').doc(group.goalPostId),
          {'memberCount': FieldValue.increment(1)},
        );
      }
    });
  }

  /// Leaves a group. If nobody remains, the group (and its discover
  /// post, if any) is deleted.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists || snap.data() == null) return;
      final group = Group.fromMap(snap.id, snap.data()!);
      final remaining =
          group.memberIds.where((id) => id != uid).toList();
      if (remaining.isEmpty) {
        tx.delete(groupRef);
        if (group.goalPostId != null) {
          tx.delete(
              _db.collection('goal_posts').doc(group.goalPostId));
        }
        return;
      }
      final names = Map<String, String>.from(group.memberNames)
        ..remove(uid);
      tx.update(groupRef, {
        'memberIds': remaining,
        'memberNames': names,
        if (group.ownerId == uid) 'ownerId': remaining.first,
      });
      if (group.goalPostId != null) {
        tx.update(
          _db.collection('goal_posts').doc(group.goalPostId),
          {'memberCount': FieldValue.increment(-1)},
        );
      }
    });
  }

  // ================= chat messages =================

  Stream<List<ChatMessage>> messagesStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? text,
    String? imageUrl,
  }) {
    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty && (imageUrl ?? '').isEmpty) {
      return Future.value();
    }
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderId: senderId,
          senderName: senderName,
          text: trimmed.isEmpty ? null : trimmed,
          imageUrl: (imageUrl ?? '').isEmpty ? null : imageUrl,
          createdAt: DateTime.now(),
        ).toMap());
  }

  // ================= check-ins =================

  /// Today's check-ins for a group (at most 4 docs).
  Stream<List<CheckIn>> todayCheckInsStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('checkins')
        .where('dateKey', isEqualTo: todayKey())
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CheckIn.fromMap(d.id, d.data())).toList());
  }

  /// Creates or replaces today's check-in for the user.
  Future<void> upsertTodayCheckIn({
    required String groupId,
    required String uid,
    required String userName,
    required String photoUrl,
    String note = '',
  }) {
    final key = todayKey();
    final docId = CheckIn.docIdFor(uid, key);
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('checkins')
        .doc(docId)
        .set(
          CheckIn(
            id: docId,
            groupId: groupId,
            userId: uid,
            userName: userName,
            dateKey: key,
            photoUrl: photoUrl,
            note: note.trim(),
            createdAt: DateTime.now(),
          ).toMap(),
          SetOptions(merge: true),
        );
  }

  /// Peers verify each other's check-ins. Users cannot verify themselves.
  Future<void> toggleVerify({
    required String groupId,
    required String checkinId,
    required String uid,
  }) {
    final ref = _db
        .collection('groups')
        .doc(groupId)
        .collection('checkins')
        .doc(checkinId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Check-in not found.');
      }
      final checkIn = CheckIn.fromMap(snap.id, snap.data()!);
      if (checkIn.userId == uid) {
        throw Exception('You cannot verify your own check-in.');
      }
      if (checkIn.isVerifiedBy(uid)) {
        tx.update(ref, {
          'verifiedBy': FieldValue.arrayRemove([uid])
        });
      } else {
        tx.update(ref, {
          'verifiedBy': FieldValue.arrayUnion([uid])
        });
      }
    });
  }

  // ================= tasks =================

  Stream<List<TaskItem>> tasksStream(String uid) {
    return _db
        .collection('tasks')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => TaskItem.fromMap(d.id, d.data())).toList());
  }

  Future<String> addTask({
    required String ownerId,
    required String title,
    String notes = '',
    DateTime? dueAt,
  }) async {
    final ref = await _db.collection('tasks').add(TaskItem(
          id: '',
          ownerId: ownerId,
          title: title.trim(),
          notes: notes.trim(),
          dueAt: dueAt,
          createdAt: DateTime.now(),
        ).toMap());
    return ref.id;
  }

  Future<void> updateTask(TaskItem task) {
    return _db.collection('tasks').doc(task.id).update({
      'title': task.title,
      'notes': task.notes,
      'dueAt': task.dueAt != null
          ? Timestamp.fromDate(task.dueAt!)
          : null,
    });
  }

  Future<void> toggleTaskDone(TaskItem task) {
    return _db
        .collection('tasks')
        .doc(task.id)
        .update({'done': !task.done});
  }

  Future<void> deleteTask(String taskId) {
    return _db.collection('tasks').doc(taskId).delete();
  }

  // ================= usage days =================

  Stream<UsageDay?> usageDayStream(String uid, String dateKey) {
    final docId = UsageDay.docIdFor(uid, dateKey);
    return _db
        .collection('usage_days')
        .doc(docId)
        .snapshots()
        .map((d) => d.exists && d.data() != null
            ? UsageDay.fromMap(d.id, d.data()!)
            : null);
  }

  Future<void> upsertUsageDay(UsageDay day) {
    return _db
        .collection('usage_days')
        .doc(day.id)
        .set(day.toMap(), SetOptions(merge: true));
  }

  /// Adds focus-session minutes for in-app tracking (iOS/web).
  Future<void> addFocusMinutes({
    required String uid,
    required String dateKey,
    required int minutes,
  }) {
    if (minutes <= 0) return Future.value();
    final docId = UsageDay.docIdFor(uid, dateKey);
    return _db.collection('usage_days').doc(docId).set(
      {
        'uid': uid,
        'dateKey': dateKey,
        'focusMinutes': FieldValue.increment(minutes),
        'source': 'inapp',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Last 7 days of usage docs (newest first). Uses documentId whereIn
  /// so no composite index is required.
  Future<List<UsageDay>> last7UsageDays(String uid) async {
    final now = DateTime.now();
    final ids = List.generate(
      7,
      (i) => UsageDay.docIdFor(
          uid, dateKeyFromDate(now.subtract(Duration(days: i)))),
    );
    try {
      final q = await _db
          .collection('usage_days')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      final days =
          q.docs.map((d) => UsageDay.fromMap(d.id, d.data())).toList();
      days.sort((a, b) => a.dateKey.compareTo(b.dateKey));
      return days;
    } catch (e) {
      debugPrint('4cus: last7UsageDays failed: $e');
      return [];
    }
  }
}
