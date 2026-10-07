import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection; // intl also exports TextDirection (bidi); hide it to keep Flutter's enum
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../services/invite_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Group detail with three tabs: Chat | Check-ins | Members.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final int initialTab;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialTab = 0,
  });

  @override
  State<GroupDetailScreen> createState() =>
      _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<Group?>(
      stream: firestore.groupStream(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
              body: LoadingView(message: 'Loading group…'));
        }
        final group = snapshot.data;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.group_off_outlined,
              title: 'Group not available',
              subtitle:
                  'This group may have been deleted or you are no '
                  'longer a member.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name),
                Text(
                  group.goalTitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Chat'),
                Tab(text: 'Check-ins'),
                Tab(text: 'Members'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _ChatTab(group: group),
              _CheckInsTab(group: group),
              _MembersTab(group: group),
            ],
          ),
        );
      },
    );
  }
}

// ================= CHAT =================

class _ChatTab extends StatefulWidget {
  final Group group;

  const _ChatTab({required this.group});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    await _send(text: text);
  }

  Future<void> _send({String? text, String? imageUrl}) async {
    setState(() => _sending = true);
    final auth = context.read<AuthState>();
    try {
      await context.read<FirestoreService>().sendMessage(
            groupId: widget.group.id,
            senderId: auth.user!.uid,
            senderName: auth.displayName,
            text: text,
            imageUrl: imageUrl,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = source == ImageSource.camera
        ? await ImagePick.fromCamera()
        : await ImagePick.fromGallery();
    if (file == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final url = await context
          .read<StorageService>()
          .uploadChatImage(groupId: widget.group.id, file: file);
      await _send(imageUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myUid = context.read<AuthState>().user!.uid;
    final firestore = context.read<FirestoreService>();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream:
                firestore.messagesStream(widget.group.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                    message: snapshot.error.toString());
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No messages yet',
                  subtitle:
                      'Say hello to your group and agree on the '
                      'plan for this week.',
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, 12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final mine = m.senderId == myUid;
                  return _MessageBubble(
                      message: m, mine: mine);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                12, 8, 12, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                      Icons.add_photo_alternate_outlined),
                  onPressed:
                      _sending ? null : _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message the group…',
                      contentPadding:
                          EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _sendText,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _MessageBubble({
    required this.message,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment:
          mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (message.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder:
                      (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 120,
                      child: Center(
                          child:
                              CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined),
                ),
              ),
            if (message.text != null &&
                message.text!.isNotEmpty) ...[
              if (message.hasImage)
                const SizedBox(height: 6),
              Text(
                message.text!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mine
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a')
                    .format(message.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= CHECK-INS =================

class _CheckInsTab extends StatelessWidget {
  final Group group;

  const _CheckInsTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final myUid = context.read<AuthState>().user!.uid;

    return StreamBuilder<List<CheckIn>>(
      stream: firestore.todayCheckInsStream(group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LoadingView(
              message: 'Loading check-ins…');
        }
        if (snapshot.hasError) {
          return ErrorView(
              message: snapshot.error.toString());
        }
        final checkIns = {
          for (final c in (snapshot.data ?? [])) c.userId: c,
        };
        return ListView(
          padding:
              const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Today · ${DateFormat('d MMM').format(DateTime.now())}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            for (final memberId in group.memberIds)
              _CheckInSlot(
                group: group,
                memberId: memberId,
                memberName: group.memberName(memberId),
                checkIn: checkIns[memberId],
                isSelf: memberId == myUid,
              ),
          ],
        );
      },
    );
  }
}

class _CheckInSlot extends StatefulWidget {
  final Group group;
  final String memberId;
  final String memberName;
  final CheckIn? checkIn;
  final bool isSelf;

  const _CheckInSlot({
    required this.group,
    required this.memberId,
    required this.memberName,
    required this.checkIn,
    required this.isSelf,
  });

  @override
  State<_CheckInSlot> createState() => _CheckInSlotState();
}

class _CheckInSlotState extends State<_CheckInSlot> {
  bool _busy = false;

  Future<void> _postCheckIn() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = source == ImageSource.camera
        ? await ImagePick.fromCamera()
        : await ImagePick.fromGallery();
    if (file == null || !mounted) return;

    // Capture services before the next async gap.
    final storage = context.read<StorageService>();
    final firestore = context.read<FirestoreService>();

    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a note (optional)'),
        content: TextField(
          controller: noteController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What did you do today?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(''),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(noteController.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (!mounted) return;
    // null = dialog dismissed -> cancel; '' = skipped note -> post anyway.
    if (note == null) return;

    setState(() => _busy = true);
    try {
      final url = await storage.uploadCheckInPhoto(
        groupId: widget.group.id,
        uid: widget.memberId,
        dateKey: todayKey(),
        file: file,
      );
      await firestore.upsertTodayCheckIn(
        groupId: widget.group.id,
        uid: widget.memberId,
        userName: widget.memberName,
        photoUrl: url,
        note: note,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleVerify() async {
    final checkIn = widget.checkIn;
    if (checkIn == null) return;
    setState(() => _busy = true);
    try {
      await context.read<FirestoreService>().toggleVerify(
            groupId: widget.group.id,
            checkinId: checkIn.id,
            uid: context.read<AuthState>().user!.uid,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkIn = widget.checkIn;
    final myUid = context.read<AuthState>().user!.uid;
    final verified = checkIn?.isVerifiedBy(myUid) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
                name: widget.memberName, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isSelf
                              ? '${widget.memberName} (you)'
                              : widget.memberName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700),
                        ),
                      ),
                      if (checkIn != null)
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: checkIn.verifiedCount >
                                      0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${checkIn.verifiedCount}',
                              style: theme
                                  .textTheme.labelLarge
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (checkIn != null) ...[
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(12),
                      child: Image.network(
                        checkIn.photoUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, progress) {
                          if (progress == null) {
                            return child;
                          }
                          return const SizedBox(
                            height: 140,
                            child: Center(
                                child:
                                    CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(
                          height: 140,
                          child: Center(
                              child: Icon(Icons
                                  .broken_image_outlined)),
                        ),
                      ),
                    ),
                    if (checkIn.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        checkIn.note,
                        style:
                            theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!widget.isSelf)
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : _toggleVerify,
                        icon: Icon(
                          verified
                              ? Icons.check_circle
                              : Icons
                                  .check_circle_outline,
                          size: 18,
                        ),
                        label: Text(verified
                            ? 'Verified'
                            : 'Verify'),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size(0, 38),
                          foregroundColor: verified
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                  ] else if (widget.isSelf)
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : _postCheckIn,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              size: 18),
                      label: const Text('Post check-in'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, 40),
                      ),
                    )
                  else
                    Text(
                      'No check-in yet today.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= MEMBERS =================

class _MembersTab extends StatelessWidget {
  final Group group;

  const _MembersTab({required this.group});

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showConfirm(
      context,
      title: 'Leave group?',
      message:
          'You will stop receiving check-ins and messages from "${group.name}".',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<FirestoreService>().leaveGroup(
            groupId: group.id,
            uid: context.read<AuthState>().user!.uid,
          );
      if (context.mounted) {
        Navigator.of(context)
            .popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite code',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.inviteCode,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      InviteService.shareInvite(
                    groupName: group.name,
                    inviteCode: group.inviteCode,
                  ),
                  icon: const Icon(Icons.share_outlined,
                      size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(
            'Members (${group.memberCount}/4)'),
        const SizedBox(height: 8),
        for (final memberId in group.memberIds)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Avatar(
                  name: group.memberName(memberId)),
              title: Text(group.memberName(memberId)),
              subtitle: memberId == group.ownerId
                  ? const Text('Owner')
                  : null,
              trailing:
                  memberId == context.read<AuthState>().user?.uid
                      ? Text(
                          'You',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(
                            color:
                                theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _leave(context),
          icon: const Icon(Icons.exit_to_app_outlined),
          label: const Text('Leave group'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
                color: theme.colorScheme.error
                    .withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}
