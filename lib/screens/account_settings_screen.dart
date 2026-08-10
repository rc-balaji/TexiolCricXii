import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/ui_bits.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() {});
    } on FirebaseAuthException catch (error) {
      if (mounted) _message(_authMessage(error));
    } on Object catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'requires-recent-login' =>
      'For security, sign out and sign in again before this change.',
    'credential-already-in-use' =>
      'That provider account is already connected to another Player ID.',
    'provider-already-linked' => 'This provider is already connected.',
    _ => error.message ?? error.code,
  };

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _emailConnection() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect email & password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              <String>[email.text.trim(), password.text],
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    if (result != null && mounted) {
      await _run(
        () => AppScope.read(context).connectEmailPassword(result[0], result[1]),
      );
    }
  }

  Future<void> _changeIdPassword() async {
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Player ID password'),
        content: TextField(
          controller: password,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters or digits',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    password.dispose();
    if (value != null && mounted) {
      await _run(() => AppScope.read(context).changePlayerIdPassword(value));
    }
  }

  Future<void> _activatePlayerId() async {
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate global Player ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your old/local ID and all match references will be upgraded to a globally reserved numeric ID.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Player ID password',
                helperText: 'At least 8 characters or digits',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    password.dispose();
    if (value != null && mounted) {
      await _run(() async {
        final id = await AppScope.read(context).activatePendingPlayerId(value);
        if (mounted) _message('Global Player ID activated: $id');
      });
    }
  }

  Future<void> _disconnect(String providerId, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect $label?'),
        content: Text(
          'This $label account will immediately lose access to this Player ID. Your cricket profile and history stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep connected'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _run(() => AppScope.read(context).disconnectProvider(providerId));
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start cricket data fresh?'),
        content: const Text(
          'This clears match history, Singles/Team stats, friends, requests and notifications on this phone and in CricXii cloud. Your Player ID and sign-in methods remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _run(AppScope.read(context).resetActivePlayerData);
    }
  }

  Future<void> _delete() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes the Player ID, connections and private account data. This cannot be undone.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Type DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().toUpperCase() == 'DELETE',
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirm == true && mounted) {
      await _run(AppScope.read(context).deleteMyAccount);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final linked = store.linkedProviderIds.toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Account & security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Login connections',
            subtitle:
                'One Player ID can use email, Google and Facebook. A provider can belong to only one Player ID at a time.',
          ),
          const SizedBox(height: 18),
          if (store.needsPlayerIdSync) ...[
            Card(
              color: const Color(0xFFFFF4D6),
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF8A5A00),
                ),
                title: const Text(
                  'Finish Player ID upgrade',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Reserve this profile on the global numeric-ID service.',
                ),
                trailing: FilledButton(
                  onPressed: _busy ? null : _activatePlayerId,
                  child: const Text('Activate'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text(
                'Numeric Player ID',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                store.functionsBackendEnabled
                    ? (store.hasNumericIdLogin
                          ? '${store.activePlayer?.id} • Backend login active'
                          : '${store.activePlayer?.id} • Backend login inactive')
                    : '${store.activePlayer?.id} • Spark profile ID',
              ),
              trailing: store.functionsBackendEnabled
                  ? TextButton(
                      onPressed: _busy || !store.hasNumericIdLogin
                          ? null
                          : _changeIdPassword,
                      child: const Text('Password'),
                    )
                  : null,
            ),
          ),
          _ProviderTile(
            icon: Icons.alternate_email_rounded,
            label: 'Email & password',
            connected: linked.contains('password'),
            subtitle: store.cloudEmail,
            onConnect: _busy ? null : _emailConnection,
            onDisconnect: _busy
                ? null
                : () => _disconnect('password', 'email login'),
          ),
          _ProviderTile(
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            connected: linked.contains('google.com'),
            onConnect: _busy
                ? null
                : () => _run(() => AppScope.read(context).connectGoogle()),
            onReplace: _busy
                ? null
                : () => _run(
                    () => AppScope.read(
                      context,
                    ).connectGoogle(replaceExisting: true),
                  ),
            onDisconnect: _busy
                ? null
                : () => _disconnect('google.com', 'Google'),
          ),
          _ProviderTile(
            icon: Icons.facebook_rounded,
            label: 'Facebook',
            connected: linked.contains('facebook.com'),
            subtitle: store.facebookLoginConfigured
                ? null
                : 'Add Facebook App ID + Client Token to the build',
            onConnect: _busy
                ? null
                : () => _run(() => AppScope.read(context).connectFacebook()),
            onReplace: _busy || !store.facebookLoginConfigured
                ? null
                : () => _run(
                    () => AppScope.read(
                      context,
                    ).connectFacebook(replaceExisting: true),
                  ),
            onDisconnect: _busy
                ? null
                : () => _disconnect('facebook.com', 'Facebook'),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Account actions'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Start cricket data fresh'),
                  subtitle: const Text('Keep Player ID, clear cricket and social data'),
                  onTap: _busy ? null : _reset,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  onTap: _busy
                      ? null
                      : () => _run(AppScope.read(context).signOutCloud),
                ),
                const Divider(height: 1),
                ListTile(
                  textColor: Colors.red.shade700,
                  iconColor: Colors.red.shade700,
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete account permanently'),
                  onTap: _busy ? null : _delete,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          const Text(
            'Account deletion and provider changes can require a recent login. Provider photos are removed from CricXii when that provider is disconnected.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.icon,
    required this.label,
    required this.connected,
    this.subtitle,
    this.onConnect,
    this.onReplace,
    this.onDisconnect,
  });

  final IconData icon;
  final String label;
  final bool connected;
  final String? subtitle;
  final VoidCallback? onConnect;
  final VoidCallback? onReplace;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: connected ? AppColors.greenDark : AppColors.muted),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        connected ? (subtitle ?? 'Connected') : (subtitle ?? 'Not connected'),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'connect') onConnect?.call();
          if (value == 'replace') onReplace?.call();
          if (value == 'disconnect') onDisconnect?.call();
        },
        itemBuilder: (context) => [
          if (!connected)
            const PopupMenuItem(value: 'connect', child: Text('Connect')),
          if (connected && onReplace != null)
            const PopupMenuItem(value: 'replace', child: Text('Change account')),
          if (connected)
            const PopupMenuItem(
              value: 'disconnect',
              child: Text('Disconnect'),
            ),
        ],
      ),
    ),
  );
}
