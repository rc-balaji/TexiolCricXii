import 'package:flutter/material.dart';

import '../core/easy_login.dart';
import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/ui_bits.dart';

Future<CreatedPlayer?> showPlayerAccountRegistration(BuildContext context) =>
    Navigator.of(context).push<CreatedPlayer>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _PlayerAccountRegistrationScreen(),
      ),
    );

class _PlayerAccountRegistrationScreen extends StatefulWidget {
  const _PlayerAccountRegistrationScreen();

  @override
  State<_PlayerAccountRegistrationScreen> createState() =>
      _PlayerAccountRegistrationScreenState();
}

class _PlayerAccountRegistrationScreenState
    extends State<_PlayerAccountRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final created = await AppScope.read(
        context,
      ).createEasyPlayerAccount(name: _name.text);
      if (!mounted) return;
      await _showRegistrationComplete(created);
      if (mounted) Navigator.of(context).pop(created);
    } on Object catch (error) {
      if (mounted) {
        final text = '$error'.replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRegistrationComplete(
    CreatedPlayer created,
  ) => showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder:
        (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.greenDark,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  'Player account created',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The player can sign in using this easy-login name and the default password.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(
                    'Name: ${created.player.name}\n'
                    'Player ID: ${created.player.id}\n'
                    'Easy login name: ${created.loginEmail.split('@').first}\n'
                    'Login ID: ${created.loginEmail}\n'
                    'Password: $easyLoginPassword',
                    style: const TextStyle(
                      height: 1.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create player with Easy Login')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const ScreenTitle(
              title: 'Add another player',
              subtitle:
                  'Enter the player name. Their login name is based on it; if already used, four digits are added. The default password is $easyLoginPassword.',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Player name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().length < 2
                                  ? 'Enter the player name'
                                  : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _register,
              icon:
                  _busy
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.how_to_reg_rounded),
              label: Text(
                _busy ? 'Creating...' : 'Create player with Easy Login',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
