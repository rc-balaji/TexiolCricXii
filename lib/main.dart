import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'widgets/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseRequested = bool.fromEnvironment('FIREBASE_ENABLED');
  const appCheckRequested = bool.fromEnvironment('APP_CHECK_ENABLED');
  var firebaseEnabled = false;
  if (firebaseRequested) {
    try {
      await Firebase.initializeApp();
      if (appCheckRequested) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        );
      }
      firebaseEnabled = true;
    } on FirebaseException {
      firebaseEnabled = false;
    }
  }
  final store = AppStore(firebaseEnabled: firebaseEnabled);
  await store.initialize();
  runApp(AppScope(store: store, child: const CricXiiApp()));
}
