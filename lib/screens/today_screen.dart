import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection; // intl also exports TextDirection (bidi); hide it to keep Flutter's enum
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';
import 'group_detail_screen.dart';

/// Today tab: greeting, today's tasks, and per-group check-in status.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthState>();
    final tasks = context.watch<TasksState>();
    final groups = context.watch<GroupsState>();

    return Scaffold(
      appBar: AppBar(title: const Text('4cus')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Streams refresh themselves; this gives pull feedback.
          await Future<void>.delayed(
              const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '${_greeting()}, ${auth.displayName.split(' ').first}.',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              "Today's tasks",
              trailing: TextButton(
                onPressed: () =>
                    _showAddTaskDialog(context),
                child: const Text('+ Add'),
              ),
            ),
            const SizedBox(height: 8),
            if (tasks.loading)
              const LoadingView()
            else if (tasks.todayTasks.isEmpty)
              _QuietCard(
                child: Text(
                  'Nothing due today. Add a task to get moving.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...tasks.todayTasks.map(
                (t) => _TaskTile(task: t),
              ),
            if (tasks.upcomingTasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader('Upcoming'),
              const SizedBox(height: 8),
              ...tasks.upcomingTasks
                  .take(5)
                  .map((t) => _TaskTile(task: t)),
            ],
            const SizedBox(height: 24),
            const SectionHeader("Today's check-ins"),
            const SizedBox(height: 8),
            if (groups.groupsLoading)
              const LoadingView()
            else if (groups.groups.isEmpty)
              _QuietCard(
                child: Text(
                  'Join or create a group to start daily check-ins.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...groups.groups.map(
                (g) => _GroupCheckInTile(group: g),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );
  }
}

class _QuietCard extends StatelessWidget {
  final Widget child;

  const _QuietCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = context.read<TasksState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          onChanged: (_) => tasks.toggleDone(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.done ? TextDecoration.lineThrough : null,
            color: task.done
                ? theme.colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        subtitle: task.dueAt != null
            ? Text(
                DateFormat('d MMM, h:mm a').format(task.dueAt!),
                style: TextStyle(
                  color: task.isOverdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () async {
            final confirmed = await showConfirm(
              context,
              title: 'Delete task?',
              message: 'This will remove "${task.title}".',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (confirmed) {
              await tasks.delete(task);
            }
          },
        ),
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueAt;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await context.read<TasksState>().addTask(
          title: _titleController.text,
          notes: _notesController.text,
          dueAt: _dueAt,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MinimalTextField(
              label: 'Title',
              controller: _titleController,
              hint: 'e.g. Run 5km',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            MinimalTextField(
              label: 'Notes (optional)',
              controller: _notesController,
              hint: 'Any details…',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(
                _dueAt == null
                    ? 'Set deadline'
                    : DateFormat('d MMM, h:mm a').format(_dueAt!),
              ),
            ),
            if (_dueAt != null)
              TextButton(
                onPressed: () => setState(() => _dueAt = null),
                child: Text(
                  'Clear deadline',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

/// Shows today's check-in progress for one group with a quick link.
class _GroupCheckInTile extends StatelessWidget {
  final Group group;

  const _GroupCheckInTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = context.read<FirestoreService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(
              groupId: group.id,
              initialTab: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<CheckIn>>(
            stream: firestore.todayCheckInsStream(group.id),
            builder: (context, snapshot) {
              final done = snapshot.data?.length ?? 0;
              final total = group.memberCount;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.goalTitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                            color: theme
                                .colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: done >= total
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius:
                          BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$done/$total',
                      style:
                          theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: done >= total
                            ? theme.colorScheme.primary
                            : theme.colorScheme
                                .onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
