import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../services/invite_service.dart';
import '../widgets/common.dart';
import 'group_detail_screen.dart';

/// Join a group with a 6-character invite code.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() =>
      _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;
  Group? _found;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim().toUpperCase();
    setState(() {
      _error = null;
      _found = null;
    });
    if (!InviteService.isValidCodeFormat(code)) {
      setState(() =>
          _error = 'Codes are 6 characters (letters and digits).');
      return;
    }
    setState(() => _joining = true);
    try {
      final group = await context
          .read<FirestoreService>()
          .findGroupByInviteCode(code);
      if (!mounted) return;
      if (group == null) {
        setState(() => _error =
            'No group found with that code. Check and try again.');
      } else {
        setState(() => _found = group);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Lookup failed: $e');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _join() async {
    final group = _found;
    if (group == null) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      await context.read<FirestoreService>().joinGroup(
            groupId: group.id,
            uid: auth.user!.uid,
            userName: auth.displayName,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              GroupDetailScreen(groupId: group.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst(
            'Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = context.read<AuthState>().user?.uid;
    final alreadyMember =
        _found != null && uid != null && _found!.memberIds.contains(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Join with code')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Enter the 6-character code shared by the group owner.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z0-9]')),
            ],
            onChanged: (v) {
              final parsed = InviteService.parseInviteCode(v);
              if (parsed != null && parsed != v.toUpperCase()) {
                _codeController.text = parsed;
                _codeController.selection =
                    TextSelection.fromPosition(
                  TextPosition(offset: parsed.length),
                );
              }
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _lookup(),
            decoration: const InputDecoration(
              hintText: 'ABC123',
              counterText: '',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Find group',
            loading: _joining && _found == null,
            onPressed: _lookup,
          ),
          if (_found != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _found!.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _found!.goalTitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_found!.memberCount}/4 members',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: alreadyMember
                          ? 'Already a member'
                          : _found!.isFull
                              ? 'Group is full'
                              : 'Join group',
                      loading:
                          _joining && _found != null,
                      onPressed: (alreadyMember ||
                              _found!.isFull)
                          ? null
                          : _join,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
