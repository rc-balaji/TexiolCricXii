import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'widgets/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseRequested = bool.fromEnvironment('FIREBASE_ENABLED');
  var firebaseEnabled = false;
  if (firebaseRequested) {
    try {
      await Firebase.initializeApp();
      firebaseEnabled = true;
    } on FirebaseException {
      firebaseEnabled = false;
    }
  }
  final store = AppStore(firebaseEnabled: firebaseEnabled);
  await store.initialize();
  runApp(AppScope(store: store, child: const CricXiiApp()));
}
