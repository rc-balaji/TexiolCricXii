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
  final _emailOrId = TextEditingController();
  final _password = TextEditingController();
  int _mode = 0;
  bool _busy = false;
  bool _hidePassword = true;

  bool get _creating => _mode == 1;

  @override
  void dispose() {
    _emailOrId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final store = AppScope.read(context);
      if (_creating) {
        await store.signUpWithEmail(_emailOrId.text, _password.text);
      } else {
        await store.signInWithEmail(_emailOrId.text, _password.text);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    } on Object catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await AppScope.read(context).signInWithGoogle();
    } on Object catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _facebook() async {
    setState(() => _busy = true);
    try {
      await AppScope.read(context).signInWithFacebook();
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
    'credential-already-in-use' =>
      'This Google/Facebook account is connected to another Player ID.',
    'weak-password' => 'Use a stronger password with at least 8 characters.',
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
          const SizedBox(height: 34),
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
          const Text(
            'Use email and password, Google, or Facebook. One login opens one independent player account.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Sign in')),
              ButtonSegment(value: 1, label: Text('Register')),
            ],
            selected: {_mode},
            onSelectionChanged: _busy
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
                TextFormField(
                  controller: _emailOrId,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.contains('@') ? null : 'Enter your email';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
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
                      ? 'Use at least 8 characters or digits'
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
                  label: Text(_creating ? 'Register & continue' : 'Sign in'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: const Text('Continue with Google'),
          ),
          if (AppScope.of(context).facebookLoginConfigured)
            OutlinedButton.icon(
              onPressed: _busy ? null : _facebook,
              icon: const Icon(Icons.facebook_rounded),
              label: const Text('Continue with Facebook'),
            ),
          const SizedBox(height: 8),
          if (AppScope.of(context).canContinueOffline)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => AppScope.read(context).continueOffline(),
              icon: const Icon(Icons.signal_wifi_off_rounded),
              label: const Text('Continue offline on this phone'),
            ),
          const SizedBox(height: 16),
          Text(
            AppScope.of(context).facebookLoginConfigured
                ? 'Email, Google and Facebook are supported. Registered temporary players are claimed after sign-in using their Player ID.'
                : 'Facebook login becomes available after its App ID and Client Token are added to the build.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
