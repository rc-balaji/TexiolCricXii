import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';

Future<CreatedPlayer?> showProvisionalPlayerRegistration(
  BuildContext context, {
  bool offerFriendRequest = true,
}) async {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  var sendRequest = false;
  final submit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Register provisional player'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This creates a separate Player ID. It does not become another profile under your account.',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Player name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Contact Gmail/email (optional)',
                  helperText: 'They can connect it after claiming the ID',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temporary numeric password (optional)',
                  helperText:
                      'Generated if empty; it becomes their Player ID login',
                ),
              ),
              if (offerFriendRequest) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendRequest,
                  onChanged: (value) =>
                      setState(() => sendRequest = value ?? false),
                  title: const Text('Send friend request after registration'),
                  subtitle: const Text('They will receive an in-app notification.'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              name.text.trim().length >= 2 &&
                  (password.text.isEmpty ||
                      (password.text.length >= 8 &&
                          RegExp(r'^\d+$').hasMatch(password.text))),
            ),
            child: const Text('Create Player ID'),
          ),
        ],
      ),
    ),
  );

  if (submit != true || !context.mounted) {
    name.dispose();
    email.dispose();
    password.dispose();
    return null;
  }

  CreatedPlayer? created;
  try {
    created = await AppScope.read(context).createProvisionalPlayer(
      name: name.text,
      email: email.text,
      temporaryPassword: password.text,
      sendFriendRequest: sendRequest,
    );
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
  name.dispose();
  email.dispose();
  password.dispose();
  if (created == null || !context.mounted) return null;
  final result = created;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Save claim details'),
      content: SelectableText(
        'Name: ${result.player.name}\nPlayer ID: ${result.player.id}\nTemporary password: ${result.temporaryPassword}',
        style: const TextStyle(height: 1.7, fontWeight: FontWeight.w800),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Saved'),
        ),
      ],
    ),
  );
  return result;
}
