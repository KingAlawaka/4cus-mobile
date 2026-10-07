import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Profile tab: avatar, name, focus target, sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
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

    final auth = context.read<AuthState>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await context
          .read<StorageService>()
          .uploadAvatar(uid: uid, file: file);
      await auth.updatePhotoUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editName() async {
    final auth = context.read<AuthState>();
    final controller =
        TextEditingController(text: auth.appUser?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'Alex'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null &&
        result.isNotEmpty &&
        context.mounted) {
      await auth.updateName(result);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirm(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use 4cus.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthState>().signOut();
    if (mounted) {
      context.read<GroupsState>().disposeStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthState>();
    final appUser = auth.appUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Stack(
              children: [
                Avatar(
                  name: appUser?.name ?? '?',
                  photoUrl: appUser?.photoUrl,
                  radius: 44,
                ),
                if (_uploadingAvatar)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appUser?.name ?? '',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            appUser?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Name'),
                  subtitle: Text(appUser?.name ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editName,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Daily focus target'),
                  subtitle: Text(
                      '${auth.focusTarget} minutes'),
                  trailing:
                      const Icon(Icons.chevron_right),
                  onTap: () =>
                      _editTarget(context, auth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '4cus is better with four. Invite friends '
                      'to your groups and keep each other honest.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                  color: theme.colorScheme.error
                      .withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '4cus · version 0.1.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _editTarget(
      BuildContext context, AuthState auth) async {
    final controller = TextEditingController(
        text: auth.focusTarget.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily focus target (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              hintText: 'e.g. 120'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0 && context.mounted) {
      await auth.updateFocusTarget(result);
    }
  }
}
