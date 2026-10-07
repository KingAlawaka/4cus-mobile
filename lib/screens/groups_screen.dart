import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'join_group_screen.dart';

/// My Groups tab: list of groups with today's check-in counts.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: _body(context, groups),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupActions(context),
        icon: const Icon(Icons.add),
        label: const Text('Group'),
      ),
    );
  }

  Widget _body(BuildContext context, GroupsState groups) {
    if (groups.groupsLoading) {
      return const LoadingView(message: 'Loading your groups…');
    }
    if (groups.error != null) {
      return ErrorView(message: groups.error!);
    }
    if (groups.groups.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'No groups yet',
        subtitle: 'Create your first accountability group or join '
            'one with an invite code.',
        actionLabel: 'Create group',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const CreateGroupScreen()),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: groups.groups.length,
      itemBuilder: (context, i) =>
          _GroupCard(group: groups.groups[i]),
    );
  }

  void _showGroupActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create group'),
              subtitle:
                  const Text('Start a new 4-person group'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const CreateGroupScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Join with code'),
              subtitle:
                  const Text('Enter a 6-character invite code'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const JoinGroupScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = context.read<FirestoreService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GroupDetailScreen(groupId: group.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (group.isPrivate)
                    Icon(Icons.lock_outline,
                        size: 16,
                        color: theme
                            .colorScheme.onSurfaceVariant)
                  else
                    Icon(Icons.public_outlined,
                        size: 16,
                        color: theme
                            .colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                group.goalTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MemberAvatars(group: group),
                  const SizedBox(width: 8),
                  Text(
                    '${group.memberCount}/4 members',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<List<CheckIn>>(
                    stream:
                        firestore.todayCheckInsStream(group.id),
                    builder: (context, snapshot) {
                      final done =
                          snapshot.data?.length ?? 0;
                      return Text(
                        'Today: $done/${group.memberCount}',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: done >= group.memberCount &&
                                  group.memberCount > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme
                                  .onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  final Group group;

  const _MemberAvatars({required this.group});

  @override
  Widget build(BuildContext context) {
    final shown = group.memberIds.take(4).toList();
    return SizedBox(
      height: 32,
      width: 24.0 + shown.length * 24,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 24.0,
              child: Avatar(
                name: group.memberName(shown[i]),
                radius: 16,
              ),
            ),
        ],
      ),
    );
  }
}
