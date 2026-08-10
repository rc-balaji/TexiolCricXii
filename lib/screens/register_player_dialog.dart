import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/ui_bits.dart';

Future<CreatedPlayer?> showPlayerAccountRegistration(
  BuildContext context,
) => Navigator.of(context).push<CreatedPlayer>(
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
  final _email = TextEditingController();
  final _password = TextEditingController();
  BattingStyle _battingStyle = BattingStyle.rightHanded;
  int _avatarPreset = 1;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final created = await AppScope.read(context).registerManagedPlayerAccount(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        battingStyle: _battingStyle,
        avatarPreset: _avatarPreset,
      );
      if (!mounted) return;
      await _showRegistrationComplete(created);
      if (mounted) Navigator.of(context).pop(created);
    } on Object catch (error) {
      if (mounted) {
        final text = '$error'.replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRegistrationComplete(CreatedPlayer created) =>
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => SafeArea(
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
                  'This account is ready now. The player can open CricXii on their phone and sign in directly with the email and password you entered.',
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
                    'Login email: ${created.loginEmail}',
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
    appBar: AppBar(title: const Text('Create player account')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const ScreenTitle(
              title: 'Add another player',
              subtitle:
                  'Create the account now. Only basic details are required. Instagram, phone, bio and other profile details can be added later by that player.',
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
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? 'Enter the player name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Login email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        return text.contains('@')
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Login password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<BattingStyle>(
                      value: _battingStyle,
                      decoration: const InputDecoration(
                        labelText: 'Batting style',
                        prefixIcon: Icon(Icons.sports_cricket_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BattingStyle.rightHanded,
                          child: Text('Right handed'),
                        ),
                        DropdownMenuItem(
                          value: BattingStyle.leftHanded,
                          child: Text('Left handed'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(
                              () => _battingStyle =
                                  value ?? BattingStyle.rightHanded,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('STARTING AVATAR'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(5, (index) {
                        final preset = index + 1;
                        final selected = preset == _avatarPreset;
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _busy
                              ? null
                              : () => setState(() => _avatarPreset = preset),
                          child: Container(
                            width: 62,
                            height: 62,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.greenDark
                                    : const Color(0xFFDCE5E0),
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/avatars/avatar_$preset.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _register,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_reg_rounded),
              label: Text(_busy ? 'Creating...' : 'Create Player Account'),
            ),
          ],
        ),
      ),
    ),
  );
}
