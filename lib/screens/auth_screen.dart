import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  BattingStyle _battingStyle = BattingStyle.rightHanded;
  int _avatarPreset = 1;
  bool _registering = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final store = AppScope.read(context);
      if (_registering) {
        await store.registerAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          battingStyle: _battingStyle,
          avatarPreset: _avatarPreset,
        );
      } else {
        await store.signInWithEmail(_email.text, _password.text);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    final text = '$error';
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.asset(
                  'assets/branding/cricxii_app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 13),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRICXII',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'BY TEXIOL',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _registering ? 'Create your player.' : 'Welcome back.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              height: 1,
              letterSpacing: -1.7,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _registering
                ? 'Name, email and password create one permanent CricXii Player ID. Sign in later with the same email and password.'
                : 'Sign in with the email and password used when this Player ID was created.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Sign in')),
              ButtonSegment(value: true, label: Text('Register')),
            ],
            selected: {_registering},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() {
                    _registering = value.single;
                    _formKey.currentState?.reset();
                  }),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (_registering) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Player name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().length < 2
                        ? 'Enter the player name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  autofillHints: _registering
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                  onFieldSubmitted: (_) {
                    if (!_registering && !_busy) _submit();
                  },
                ),
                if (_registering) ...[
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose avatar',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: List.generate(5, (index) {
                      final preset = index + 1;
                      final selected = preset == _avatarPreset;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _busy
                            ? null
                            : () => setState(() => _avatarPreset = preset),
                        child: Container(
                          width: 58,
                          height: 58,
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _registering
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      _busy
                          ? 'Please wait...'
                          : _registering
                          ? 'Create account'
                          : 'Sign in',
                    ),
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
