import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _instagram = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _instagram.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await AppScope.read(context).createPlayer(
      name: _name.text,
      email: _email.text,
      instagramHandle: _instagram.text,
      claimed: true,
      makeActive: true,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.sports_cricket, color: AppColors.green),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Every street has\na champion.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              height: .98,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'CricXii turns your local singles cricket into permanent scores, rankings and player history.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 30),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create your player',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A unique Player ID will be generated automatically.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
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
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instagram,
                      decoration: const InputDecoration(
                        labelText: 'Instagram ID (optional)',
                        prefixIcon: Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _busy ? null : _continue,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Enter CricXii'),
                    ),
                  ],
                ),
              ),
            ),
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
                Icon(Icons.cloud_sync_outlined, color: Color(0xFF8A5A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Local-first scoring stays usable without signal. A signed-in Firebase build also keeps a private cloud backup.',
                    style: TextStyle(color: Color(0xFF6D4B0F), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Center(
            child: Text(
              'CRICXII  •  BY TEXIOL',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
