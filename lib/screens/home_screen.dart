import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers.dart';
import 'discover_screen.dart';
import 'focus_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

/// Bottom-navigation shell with 5 tabs. Initializes the stream-backed
/// providers once the signed-in user is known.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthState>().user?.uid;
      if (uid == null) return;
      context.read<GroupsState>().init(uid);
      context.read<TasksState>().init(uid);
      context.read<UsageState>().init(uid);
    });
  }

  static const _tabs = [
    (icon: Icons.wb_sunny_outlined, activeIcon: Icons.wb_sunny, label: 'Today'),
    (icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Groups'),
    (
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Discover'
    ),
    (
      icon: Icons.timer_outlined,
      activeIcon: Icons.timer,
      label: 'Focus'
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          TodayScreen(),
          GroupsScreen(),
          DiscoverScreen(),
          FocusScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(
              icon: Icon(t.icon),
              activeIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
