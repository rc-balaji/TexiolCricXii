import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final store = AppScope.read(context);
      if (_creating) {
        await store.signUpWithEmail(_email.text, _password.text);
      } else {
        await store.signInWithEmail(_email.text, _password.text);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    } on Object catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already uses this email.',
    'weak-password' => 'Use a stronger password with at least 6 characters.',
    'network-request-failed' => 'No internet. Continue offline or try again.',
    _ => 'Firebase sign-in failed ($code).',
  };

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
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.sports_cricket_rounded,
                  color: AppColors.green,
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
          const SizedBox(height: 38),
          Text(
            _creating ? 'Create your account.' : 'Welcome back.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              height: 1,
              letterSpacing: -1.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _creating
                ? 'Your scores stay on this phone first and back up privately when connected.'
                : 'Sign in to restore your CricXii profiles and match history.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 26),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sign in')),
              ButtonSegment(value: true, label: Text('Create account')),
            ],
            selected: {_creating},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _creating = value.single),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) =>
                      value == null || !value.trim().contains('@')
                      ? 'Enter your email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  autofillHints: _creating
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
                  validator: (value) => value == null || value.length < 6
                      ? 'Use at least 6 characters'
                      : null,
                  onFieldSubmitted: (_) {
                    if (!_busy) _submit();
                  },
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _creating
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                        ),
                  label: Text(_creating ? 'Create & continue' : 'Sign in'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => AppScope.read(context).continueOffline(),
            icon: const Icon(Icons.signal_wifi_off_rounded),
            label: const Text('Continue offline on this phone'),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.key_rounded, color: Color(0xFF8A5A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Player-ID + temporary-password claiming is reserved for the secure claim service. Existing local profiles can still be switched without repeated login.',
                    style: TextStyle(color: Color(0xFF6D4B0F), height: 1.35),
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
