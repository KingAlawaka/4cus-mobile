import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/usage_service.dart';

/// ---------- AuthState ----------

class AuthState extends ChangeNotifier {
  final AuthService _auth;
  final FirestoreService _firestore;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  User? user;
  AppUser? appUser;
  bool loading = true;
  String? error;

  /// In-memory onboarding flag for the signed-out case (no
  /// shared_preferences dependency; the user doc is the source of
  /// truth once signed in).
  bool _onboardingDoneLocal = false;

  AuthState(this._auth, this._firestore) {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  bool get signedIn => user != null;
  bool get onboardingDone =>
      _onboardingDoneLocal || (appUser?.onboardingDone ?? false);
  String get displayName => appUser?.name ?? user?.displayName ?? 'there';
  int get focusTarget => appUser?.focusTargetMinutes ?? 120;

  Future<void> _onAuthChanged(User? firebaseUser) async {
    await _userSub?.cancel();
    _userSub = null;
    user = firebaseUser;
    appUser = null;
    error = null;
    if (firebaseUser != null) {
      _userSub = _firestore
          .userStream(firebaseUser.uid)
          .listen((appUserSnapshot) {
        appUser = appUserSnapshot;
        loading = false;
        notifyListeners();
      }, onError: (Object e) {
        error = e.toString();
        loading = false;
        notifyListeners();
      });
    } else {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    return _guard(() => _auth.signInWithEmail(
        email: email, password: password));
  }

  Future<bool> signUp(String name, String email, String password) async {
    return _guard(() => _auth.signUpWithEmail(
        name: name, email: email, password: password));
  }

  Future<bool> signInWithGoogle() async {
    return _guard(() async {
      await _auth.signInWithGoogle();
    });
  }

  Future<bool> _guard(Future<void> Function() action) async {
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> markOnboardingDone() async {
    _onboardingDoneLocal = true;
    notifyListeners();
    if (user == null) return;
    await _firestore.updateUserFields(user!.uid, {'onboardingDone': true});
  }

  Future<void> updateName(String name) async {
    if (user == null || name.trim().isEmpty) return;
    await _firestore.updateUserFields(user!.uid, {'name': name.trim()});
  }

  Future<void> updatePhotoUrl(String url) async {
    if (user == null) return;
    await _firestore.updateUserFields(user!.uid, {'photoUrl': url});
  }

  Future<void> updateFocusTarget(int minutes) async {
    if (user == null) return;
    await _firestore.updateUserFields(
        user!.uid, {'focusTargetMinutes': minutes});
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

/// ---------- GroupsState ----------

class GroupsState extends ChangeNotifier {
  final FirestoreService _firestore;

  StreamSubscription<List<Group>>? _groupsSub;
  StreamSubscription<List<GoalPost>>? _postsSub;

  List<Group> groups = const [];
  List<GoalPost> discoverPosts = const [];
  bool groupsLoading = true;
  bool postsLoading = true;
  String? error;
  String? _uid;

  GroupsState(this._firestore);

  /// Starts listening. Safe to call once per sign-in.
  void init(String uid) {
    if (_uid == uid) return;
    disposeStreams();
    _uid = uid;
    groupsLoading = true;
    postsLoading = true;
    notifyListeners();

    _groupsSub = _firestore.myGroupsStream(uid).listen((list) {
      groups = list;
      groupsLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      groupsLoading = false;
      notifyListeners();
    });

    _postsSub = _firestore.discoverPostsStream().listen((list) {
      discoverPosts = list;
      postsLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      postsLoading = false;
      notifyListeners();
    });
  }

  void disposeStreams() {
    _groupsSub?.cancel();
    _postsSub?.cancel();
    _groupsSub = null;
    _postsSub = null;
    _uid = null;
  }

  @override
  void dispose() {
    disposeStreams();
    super.dispose();
  }
}

/// ---------- TasksState ----------

class TasksState extends ChangeNotifier {
  final FirestoreService _firestore;

  StreamSubscription<List<TaskItem>>? _sub;
  List<TaskItem> _tasks = const [];
  bool loading = true;
  String? error;
  String? _uid;

  TasksState(this._firestore);

  void init(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    loading = true;
    notifyListeners();
    _sub = _firestore.tasksStream(uid).listen((list) {
      _tasks = list;
      loading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  /// Not done and due today, overdue, or with no due date.
  List<TaskItem> get todayTasks {
    final now = DateTime.now();
    final endOfToday =
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _tasks
        .where((t) =>
            !t.done && (t.dueAt == null || !t.dueAt!.isAfter(endOfToday)))
        .toList()
      ..sort(_byDueAt);
  }

  /// Not done and due after today.
  List<TaskItem> get upcomingTasks {
    final now = DateTime.now();
    final endOfToday =
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _tasks
        .where((t) =>
            !t.done && t.dueAt != null && t.dueAt!.isAfter(endOfToday))
        .toList()
      ..sort(_byDueAt);
  }

  int get doneCount => _tasks.where((t) => t.done).length;

  static int _byDueAt(TaskItem a, TaskItem b) {
    if (a.dueAt == null && b.dueAt == null) return 0;
    if (a.dueAt == null) return 1;
    if (b.dueAt == null) return -1;
    return a.dueAt!.compareTo(b.dueAt!);
  }

  Future<void> addTask({
    required String title,
    String notes = '',
    DateTime? dueAt,
  }) async {
    if (_uid == null || title.trim().isEmpty) return;
    await _firestore.addTask(
      ownerId: _uid!,
      title: title,
      notes: notes,
      dueAt: dueAt,
    );
  }

  Future<void> toggleDone(TaskItem task) =>
      _firestore.toggleTaskDone(task);

  Future<void> delete(TaskItem task) =>
      _firestore.deleteTask(task.id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// ---------- UsageState ----------

class UsageState extends ChangeNotifier {
  final FirestoreService _firestore;
  final UsageService _usage;

  StreamSubscription<UsageDay?>? _sub;
  UsageDay? today;
  bool loading = true;
  String? error;
  String? _uid;

  bool androidPermissionGranted = false;
  bool checkingPermission = false;

  // In-app focus session (iOS/web fallback + manual sessions anywhere).
  DateTime? sessionStart;
  Duration sessionElapsed = Duration.zero;
  Timer? _sessionTimer;
  bool sessionRunning = false;

  UsageState(this._firestore, this._usage);

  bool get useAndroidStats => _usage.isAndroid;

  void init(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    loading = true;
    notifyListeners();
    final key = todayKey();
    _sub = _firestore.usageDayStream(uid, key).listen((day) {
      today = day;
      loading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
    if (useAndroidStats) {
      refreshAndroidPermission();
    }
  }

  /// Pulls today's Android usage stats and persists them.
  Future<void> refreshAndroidStats() async {
    if (_uid == null || !useAndroidStats) return;
    final stats = await _usage.getUsageStats(DateTime.now());
    if (stats == null) return;
    final key = todayKey();
    await _firestore.upsertUsageDay(UsageDay(
      id: UsageDay.docIdFor(_uid!, key),
      uid: _uid!,
      dateKey: key,
      screenMinutes: stats.totalMinutes,
      unlocks: stats.unlocks,
      focusMinutes: today?.focusMinutes ?? 0,
      source: 'android',
      apps: stats.apps,
    ));
  }

  Future<void> refreshAndroidPermission() async {
    if (!useAndroidStats) return;
    checkingPermission = true;
    notifyListeners();
    androidPermissionGranted = await _usage.hasPermission();
    checkingPermission = false;
    notifyListeners();
    if (androidPermissionGranted) {
      await refreshAndroidStats();
    }
  }

  Future<void> requestAndroidPermission() async {
    await _usage.requestPermission();
    // The user returns from system settings; re-check on next resume.
    await refreshAndroidPermission();
  }

  // ----- focus sessions -----

  void startFocusSession() {
    if (sessionRunning) return;
    sessionStart = DateTime.now();
    sessionElapsed = Duration.zero;
    sessionRunning = true;
    _sessionTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessionStart != null) {
        sessionElapsed = DateTime.now().difference(sessionStart!);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> stopFocusSession() async {
    if (!sessionRunning) return;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    sessionRunning = false;
    final minutes = sessionElapsed.inMinutes;
    sessionStart = null;
    sessionElapsed = Duration.zero;
    notifyListeners();
    if (_uid != null && minutes > 0) {
      await _firestore.addFocusMinutes(
        uid: _uid!,
        dateKey: todayKey(),
        minutes: minutes,
      );
    }
  }

  void discardFocusSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    sessionRunning = false;
    sessionStart = null;
    sessionElapsed = Duration.zero;
    notifyListeners();
  }

  Future<List<UsageDay>> last7Days() {
    if (_uid == null) return Future.value(const []);
    return _firestore.last7UsageDays(_uid!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }
}
