import 'package:flutter/material.dart';

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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final store = AppScope.read(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [current.text, next.text]),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (result == null || result.length != 2) return;
    await _run(
      () => store.changeAccountPassword(
        currentPassword: result[0],
        newPassword: result[1],
      ),
    );
  }

  Future<void> _reset() async {
    final store = AppScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset cricket data?'),
        content: const Text(
          'Your Player ID and login stay. Local match history, stats and cached social data for this player are cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(store.resetActivePlayerData);
    }
  }


  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.read(context).signOutCloud();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final store = AppScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes this CricXii login credential, Player profile and private account state. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await store.deleteMyAccount();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.activePlayer;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Account',
            subtitle: 'Your CricXii login and Player ID.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text(
                    'Player ID',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: SelectableText(player?.id ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text(
                    'Login email',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(store.accountEmail ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Password'),
                  subtitle: const Text('Change your CricXii login password'),
                  trailing: TextButton(
                    onPressed: _busy ? null : _changePassword,
                    child: const Text('Change'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('ACCOUNT ACTIONS'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Reset cricket data'),
                  subtitle: const Text('Keep login and Player ID'),
                  onTap: _busy ? null : _reset,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  subtitle: const Text('Return directly to the login page'),
                  onTap: _busy ? null : _signOut,
                ),
                const Divider(height: 1),
                ListTile(
                  textColor: Colors.red.shade700,
                  iconColor: Colors.red.shade700,
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete account'),
                  onTap: _busy ? null : _delete,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
