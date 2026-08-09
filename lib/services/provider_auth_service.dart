import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProviderAuthService {
  ProviderAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Future<void> initializeGoogle() async {
    if (_googleInitialized) return;
    await _google.initialize();
    _googleInitialized = true;
  }

  Future<OAuthCredential> chooseGoogleCredential() async {
    await initializeGoogle();
    await _google.signOut();
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    return GoogleAuthProvider.credential(idToken: token);
  }

  Future<UserCredential> signInWithGoogle() async =>
      _auth.signInWithCredential(await chooseGoogleCredential());

  Future<UserCredential> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before connecting Google.');
    return user.linkWithCredential(await chooseGoogleCredential());
  }

  Future<UserCredential> replaceGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before changing Google.');
    final credential = await chooseGoogleCredential();
    if (user.providerData.any((value) => value.providerId == 'google.com')) {
      await user.unlink('google.com');
    }
    return user.linkWithCredential(credential);
  }

  Future<OAuthCredential> chooseFacebookCredential() async {
    await FacebookAuth.instance.logOut();
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );
    final token = result.accessToken;
    if (result.status != LoginStatus.success || token == null) {
      throw StateError(result.message ?? 'Facebook sign-in was cancelled.');
    }
    return FacebookAuthProvider.credential(token.tokenString);
  }

  Future<UserCredential> signInWithFacebook() async =>
      _auth.signInWithCredential(await chooseFacebookCredential());

  Future<UserCredential> linkFacebook() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before connecting Facebook.');
    return user.linkWithCredential(await chooseFacebookCredential());
  }

  Future<UserCredential> replaceFacebook() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before changing Facebook.');
    final credential = await chooseFacebookCredential();
    if (user.providerData.any((value) => value.providerId == 'facebook.com')) {
      await user.unlink('facebook.com');
    }
    return user.linkWithCredential(credential);
  }
}
