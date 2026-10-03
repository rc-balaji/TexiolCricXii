import 'package:flutter/material.dart';

import '../core/easy_login.dart';
import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';

enum _AuthMode { signIn, easyLogin, register }

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
  _AuthMode _mode = _AuthMode.signIn;
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
      if (_mode == _AuthMode.register) {
        await store.registerAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          battingStyle: _battingStyle,
          avatarPreset: _avatarPreset,
        );
      } else if (_mode == _AuthMode.easyLogin) {
        await store.signInWithEmail(
          easyLoginEmail(_name.text),
          easyLoginPassword,
        );
      } else {
        await store.signInWithEmail(_email.text, _password.text);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    final text = '$error';
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  Future<void> _forgotPassword() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _email.text),
    );
    if (reset == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
    }
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
            _mode == _AuthMode.register
                ? 'Create your player.'
                : _mode == _AuthMode.easyLogin
                ? 'Easy login.'
                : 'Welcome back.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              height: 1,
              letterSpacing: -1.7,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _mode == _AuthMode.register
                ? 'Name, email and password create one permanent CricXii Player ID.'
                : _mode == _AuthMode.easyLogin
                ? 'Enter the Easy Login name shown when the player was created. Password: $easyLoginPassword.'
                : 'Sign in with the email and password used when this Player ID was created.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          SegmentedButton<_AuthMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _AuthMode.signIn, label: Text('Sign in')),
              ButtonSegment(
                value: _AuthMode.easyLogin,
                label: Text('Easy login'),
              ),
              ButtonSegment(value: _AuthMode.register, label: Text('Register')),
            ],
            selected: {_mode},
            onSelectionChanged:
                _busy
                    ? null
                    : (value) => setState(() {
                      _mode = value.single;
                      _formKey.currentState?.reset();
                    }),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (_mode != _AuthMode.signIn) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText:
                          _mode == _AuthMode.easyLogin
                              ? 'Easy Login name'
                              : 'Player name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return _mode == _AuthMode.easyLogin
                            ? 'Enter the Easy Login name'
                            : 'Enter the player name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_mode != _AuthMode.easyLogin)
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
                if (_mode != _AuthMode.easyLogin) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autofillHints:
                        _mode == _AuthMode.register
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed:
                            () =>
                                setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator:
                        (value) =>
                            value == null || value.length < 8
                                ? 'Use at least 8 characters'
                                : null,
                    onFieldSubmitted: (_) {
                      if (_mode == _AuthMode.signIn && !_busy) _submit();
                    },
                  ),
                ],
                if (_mode == _AuthMode.signIn) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],
                if (_mode == _AuthMode.register) ...[
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
                    onChanged:
                        _busy
                            ? null
                            : (value) => setState(
                              () =>
                                  _battingStyle =
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
                        onTap:
                            _busy
                                ? null
                                : () => setState(() => _avatarPreset = preset),
                        child: Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected
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
                    icon:
                        _busy
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              _mode == _AuthMode.register
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.login_rounded,
                            ),
                    label: Text(
                      _busy
                          ? 'Please wait...'
                          : _mode == _AuthMode.register
                          ? 'Create account'
                          : _mode == _AuthMode.easyLogin
                          ? 'Easy login'
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

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _email = TextEditingController();
  final _playerId = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _identityVerified = false;
  bool _busy = false;
  bool _hidePasswords = true;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail.trim();
  }

  @override
  void dispose() {
    _email.dispose();
    _playerId.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _verifyIdentity() async {
    final email = _email.text.trim();
    final playerId = _playerId.text.trim();
    if (!email.contains('@') || !RegExp(r'^\d{8}$').hasMatch(playerId)) {
      _showError('Enter a valid email and 8-digit Player ID.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.read(
        context,
      ).verifyPasswordResetIdentity(email: email, playerId: playerId);
      if (mounted) setState(() => _identityVerified = true);
    } on Object catch (error) {
      _showError(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _newPassword.text;
    if (password.length < 8) {
      _showError('Use at least 8 characters for your new password.');
      return;
    }
    if (password != _confirmPassword.text) {
      _showError('Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.read(context).resetPasswordWithPlayerId(
        email: _email.text.trim(),
        playerId: _playerId.text.trim(),
        newPassword: password,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      _showError(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    final text = '$error';
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_identityVerified ? 'Set a new password' : 'Forgot password?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_identityVerified) ...[
            const Text('Confirm your account using its email and Player ID.'),
            const SizedBox(height: 8),
            const Text(
              'Anyone who knows both can reset this password.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _playerId,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Player ID'),
            ),
          ] else ...[
            TextField(
              controller: _newPassword,
              obscureText: _hidePasswords,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  onPressed:
                      () => setState(() => _hidePasswords = !_hidePasswords),
                  icon: Icon(
                    _hidePasswords
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPassword,
              obscureText: _hidePasswords,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            _busy
                ? null
                : _identityVerified
                ? _updatePassword
                : _verifyIdentity,
        child:
            _busy
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(_identityVerified ? 'Update password' : 'Confirm'),
      ),
    ],
  );
}
