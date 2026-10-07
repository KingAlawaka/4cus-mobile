import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection; // intl also exports TextDirection (bidi); hide it to keep Flutter's enum
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';
import 'group_detail_screen.dart';

/// Discover tab: public goal posts others have shared. Join open groups.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsState>();
    final myGroupIds =
        groups.groups.map((g) => g.id).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: _body(context, groups, myGroupIds),
    );
  }

  Widget _body(BuildContext context, GroupsState groups,
      Set<String> myGroupIds) {
    if (groups.postsLoading) {
      return const LoadingView(
          message: 'Finding public goals…');
    }
    if (groups.error != null) {
      return ErrorView(message: groups.error!);
    }
    if (groups.discoverPosts.isEmpty) {
      return const EmptyState(
        icon: Icons.explore_outlined,
        title: 'Nothing public yet',
        subtitle: 'Be the first to share a goal — create a public '
            'group and it will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(
            const Duration(milliseconds: 400));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: groups.discoverPosts.length,
        itemBuilder: (context, i) => _PostCard(
          post: groups.discoverPosts[i],
          alreadyMember:
              myGroupIds.contains(groups.discoverPosts[i].groupId),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final GoalPost post;
  final bool alreadyMember;

  const _PostCard({
    required this.post,
    required this.alreadyMember,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    final auth = context.read<AuthState>();
    final firestore = context.read<FirestoreService>();
    try {
      await firestore.joinGroup(
        groupId: widget.post.groupId,
        uid: auth.user!.uid,
        userName: auth.displayName,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GroupDetailScreen(groupId: widget.post.groupId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryChip(label: post.category),
                const Spacer(),
                Text(
                  '${post.memberCount}/4',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: post.isFull
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (post.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Avatar(name: post.ownerName, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${post.ownerName} · ${post.createdAt != null ? DateFormat('d MMM').format(post.createdAt!) : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.alreadyMember)
                  Text(
                    'Joined',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: (post.isFull || _joining)
                        ? null
                        : _join,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                    ),
                    child: _joining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Text(post.isFull ? 'Full' : 'Join'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
