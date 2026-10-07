import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers.dart';
import '../services/firestore_service.dart';
import '../services/invite_service.dart';
import '../widgets/common.dart';

const List<String> kCategories = [
  'Fitness',
  'Study',
  'Work',
  'Health',
  'Habits',
  'Creative',
  'Finance',
  'General',
];

/// Create a new 4-person group (public -> also posts to Discover).
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() =>
      _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'General';
  bool _isPrivate = true;
  bool _saving = false;
  String? _createdCode;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthState>();
    final firestore = context.read<FirestoreService>();
    try {
      final result = await firestore.createGroup(
        ownerId: auth.user!.uid,
        ownerName: auth.displayName,
        name: _nameController.text,
        goalTitle: _goalController.text,
        description: _descController.text,
        category: _category,
        isPrivate: _isPrivate,
      );
      setState(() => _createdCode = result.inviteCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: _createdCode != null
          ? _InviteCreatedView(
              code: _createdCode!,
              groupName: _nameController.text.trim(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  MinimalTextField(
                    label: 'Group name',
                    controller: _nameController,
                    hint: 'e.g. Morning runners',
                    textCapitalization:
                        TextCapitalization.sentences,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Give your group a name'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  MinimalTextField(
                    label: 'Shared goal',
                    controller: _goalController,
                    hint: 'e.g. Run 5km every morning',
                    textCapitalization:
                        TextCapitalization.sentences,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'What is the group working toward?'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  MinimalTextField(
                    label: 'Description',
                    controller: _descController,
                    hint: 'Rules, schedule, anything useful…',
                    maxLines: 3,
                    textCapitalization:
                        TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Text('Category',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(
                              fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    items: [
                      for (final c in kCategories)
                        DropdownMenuItem(
                            value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(
                        () => _category = v ?? 'General'),
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Private group'),
                      subtitle: Text(
                        _isPrivate
                            ? 'Only people with your invite code can join.'
                            : 'Listed on Discover so others can find and join it.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: theme
                              .colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _isPrivate,
                      onChanged: (v) =>
                          setState(() => _isPrivate = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Create group',
                    loading: _saving,
                    onPressed: _create,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Groups hold at most 4 people.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Shown right after creation: the invite code + share button.
class _InviteCreatedView extends StatelessWidget {
  final String code;
  final String groupName;

  const _InviteCreatedView({
    required this.code,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Group created!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code so others can join:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              code,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Share invite',
            onPressed: () => InviteService.shareInvite(
              groupName: groupName,
              inviteCode: code,
            ),
            expanded: false,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context)
                .popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
