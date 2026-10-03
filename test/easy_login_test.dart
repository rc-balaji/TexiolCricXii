import 'package:crixx/core/easy_login.dart';
import 'package:crixx/screens/auth_screen.dart';
import 'package:crixx/screens/register_player_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'easy login converts spaces to underscores and appends Gmail domain',
    () {
      expect(easyLoginEmail('  Arjun Kumar  '), 'arjun_kumar@gmail.com');
      expect(easyLoginEmail('arjun_1234'), 'arjun_1234@gmail.com');
      expect(easyLoginPassword, '12345678');
    },
  );

  testWidgets('easy login accepts a name without email or password fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.text('Easy login'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Easy Login name'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('player creation asks only for the player name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPlayerAccountRegistration(context),
                  child: const Text('Add player'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Player name'), findsOneWidget);
    expect(find.text('Login email'), findsNothing);
    expect(find.text('Login password'), findsNothing);
  });
}
