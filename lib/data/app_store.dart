import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/id_generator.dart';
import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/gang.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../domain/social.dart';
import '../services/provider_auth_service.dart';

class CreatedPlayer {
  const CreatedPlayer({required this.player, this.temporaryPassword});

  final Player player;
  final String? temporaryPassword;
}

class AppStore extends ChangeNotifier {
  AppStore({IdGenerator? ids, this.firebaseEnabled = false})
    : _ids = ids ?? IdGenerator();

  static const _storageKey = 'texiol_local_cricket_state_v1';
  static const _offlineSessionKey = 'cricxii_offline_session_v1';
  static const _cloudUidKey = 'cricxii_last_cloud_uid_v2';
  static const _avatarColors = <int>[
    0xFF19C37D,
    0xFFFFB020,
    0xFF7C5CFC,
    0xFF2D9CDB,
    0xFFE85D75,
    0xFF00A6A6,
    0xFFF97316,
    0xFF4F46E5,
  ];

  final IdGenerator _ids;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final bool firebaseEnabled;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseFunctions? _functions;
  ProviderAuthService? _providerAuth;
  bool _offlineSession = false;
  String? _pendingIdPassword;
  final Map<String, Player> _playerIndex = <String, Player>{};
  final List<Player> players = <Player>[];
  final List<Gang> gangs = <Gang>[];
  final List<CricketMatch> matches = <CricketMatch>[];
  final List<FriendRequest> friendRequests = <FriendRequest>[];
  final List<CricNotification> notifications = <CricNotification>[];

  bool initialized = false;
  String? activePlayerId;

  User? get firebaseUser => _auth?.currentUser;
  String? get cloudEmail => firebaseUser?.email;
  bool get requiresAuthentication =>
      firebaseEnabled && firebaseUser == null && !_offlineSession;
  bool get cloudConnected => firebaseEnabled && firebaseUser != null;
  bool get facebookLoginConfigured =>
      const bool.fromEnvironment('FACEBOOK_ENABLED');
  bool get functionsBackendEnabled =>
      const bool.fromEnvironment('FUNCTIONS_ENABLED', defaultValue: false);
  bool get canContinueOffline =>
      activePlayer == null || activePlayer?.accountUid == null;
  bool get hasNumericIdLogin =>
      functionsBackendEnabled &&
      cloudConnected &&
      (activePlayer?.claimed ?? false) &&
      !(activePlayer?.pendingSync ?? true);
  bool get needsPlayerIdSync =>
      cloudConnected && (activePlayer?.pendingSync ?? false);

  Player? get activePlayer => playerById(activePlayerId);

  List<Player> get visiblePlayers => players
      .where((player) => !player.archived)
      .toList(growable: false);

  List<FriendRequest> get incomingFriendRequests {
    final id = activePlayerId;
    if (id == null) return const [];
    return friendRequests
        .where(
          (request) =>
              request.toPlayerId == id &&
              request.status == FriendRequestStatus.pending,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<FriendRequest> get outgoingFriendRequests {
    final id = activePlayerId;
    if (id == null) return const [];
    return friendRequests
        .where(
          (request) =>
              request.fromPlayerId == id &&
              request.status == FriendRequestStatus.pending,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  FriendRequest? pendingRequestWith(String otherPlayerId) {
    final id = activePlayerId;
    if (id == null) return null;
    for (final request in friendRequests) {
      if (request.status != FriendRequestStatus.pending) continue;
      final samePair =
          (request.fromPlayerId == id && request.toPlayerId == otherPlayerId) ||
          (request.fromPlayerId == otherPlayerId && request.toPlayerId == id);
      if (samePair) return request;
    }
    return null;
  }

  List<CricNotification> get activeNotifications {
    final id = activePlayerId;
    if (id == null) return const [];
    return notifications.where((value) => value.playerId == id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get unreadNotificationCount =>
      activeNotifications.where((value) => !value.read).length;

  List<CricketMatch> get activeMatches {
    final id = activePlayerId;
    if (id == null) return const [];
    return matches
        .where(
          (match) =>
              match.participantIds.contains(id) &&
              match.status != MatchStatus.completed,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> initialize() async {
    _offlineSession = await _preferences.getBool(_offlineSessionKey) ?? false;
    final raw = await _preferences.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _replaceState(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        await _persistLocal();
      } on Object {
        _clearState();
      }
    }
    if (firebaseEnabled) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      _providerAuth = ProviderAuthService(auth: _auth);
      if (firebaseUser != null) await _selectCloudAccount();
      if (firebaseUser != null && players.isEmpty) {
        await _restoreCloudState();
      }
      if (firebaseUser != null) await _refreshSocialGraph();
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (!firebaseEnabled || _auth == null) {
      throw StateError('This build does not have Firebase enabled.');
    }
    await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _selectCloudAccount();
    _pendingIdPassword = password;
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    if (activePlayer != null) {
      try {
        await activatePendingPlayerId(password);
      } on FirebaseFunctionsException catch (error) {
        if (!_isBackendUnavailable(error)) rethrow;
        await _syncCloudState(_stateData());
      }
    } else {
      await _syncCloudState(_stateData());
    }
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (!firebaseEnabled || _auth == null) {
      throw StateError('This build does not have Firebase enabled.');
    }
    await _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _selectCloudAccount();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _restoreCloudState(replaceLocal: true);
    await _refreshSocialGraph();
    await _syncCloudState(_stateData());
    notifyListeners();
  }

  Future<void> signInWithPlayerId(String playerId, String password) async {
    if (!functionsBackendEnabled ||
        !firebaseEnabled ||
        _auth == null ||
        _functions == null) {
      throw StateError('Player ID login needs the optional Functions backend.');
    }
    final normalized = playerId.trim();
    if (!RegExp(r'^\d{6,}$').hasMatch(normalized)) {
      throw StateError('Enter a numeric Player ID with at least 6 digits.');
    }
    final result = await _functions!.httpsCallable('loginWithPlayerId').call(
      <String, Object?>{'playerId': normalized, 'password': password},
    );
    final token = (result.data as Map?)?['customToken']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('The Player ID login service returned no token.');
    }
    await _auth!.signInWithCustomToken(token);
    await _selectCloudAccount();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _restoreCloudState(replaceLocal: true);
    await _refreshSocialGraph();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final provider = _providerAuth;
    if (!firebaseEnabled || provider == null) {
      throw StateError('Google sign-in needs the connected Firebase build.');
    }
    final result = await provider.signInWithGoogle();
    await _selectCloudAccount();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _restoreCloudState(replaceLocal: true);
    await _refreshSocialGraph();
    _saveProviderPhoto(result.user, 'google.com');
    await _commit();
  }

  Future<void> signInWithFacebook() async {
    final provider = _providerAuth;
    if (!facebookLoginConfigured || !firebaseEnabled || provider == null) {
      throw StateError(
        'Facebook login is not configured in this build. Add the Facebook GitHub secrets and rebuild.',
      );
    }
    final result = await provider.signInWithFacebook();
    await _selectCloudAccount();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _restoreCloudState(replaceLocal: true);
    await _refreshSocialGraph();
    _saveProviderPhoto(result.user, 'facebook.com');
    await _commit();
  }

  Future<void> connectGoogle({bool replaceExisting = false}) async {
    final provider = _providerAuth;
    if (!firebaseEnabled || provider == null) {
      throw StateError('Google connection needs the Firebase build.');
    }
    final result = replaceExisting
        ? await provider.replaceGoogle()
        : await provider.linkGoogle();
    _saveProviderPhoto(result.user, 'google.com');
    await _commit();
  }

  Future<void> connectFacebook({bool replaceExisting = false}) async {
    final provider = _providerAuth;
    if (!facebookLoginConfigured || !firebaseEnabled || provider == null) {
      throw StateError(
        'Facebook login is not configured in this build. Add the Facebook GitHub secrets and rebuild.',
      );
    }
    final result = replaceExisting
        ? await provider.replaceFacebook()
        : await provider.linkFacebook();
    _saveProviderPhoto(result.user, 'facebook.com');
    await _commit();
  }

  Future<void> connectEmailPassword(String email, String password) async {
    final user = firebaseUser;
    if (user == null) throw StateError('Sign in before connecting email.');
    if (password.length < 8) {
      throw StateError('Use at least 8 characters for the email password.');
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await user.linkWithCredential(credential);
    final player = activePlayer;
    if (player != null) {
      player.email = email.trim();
      await _commit();
    }
  }

  Future<void> changePlayerIdPassword(String password) async {
    final player = activePlayer;
    if (!functionsBackendEnabled ||
        player == null ||
        _functions == null ||
        !cloudConnected) {
      throw StateError('Player ID password needs the optional Functions backend.');
    }
    if (password.length < 8) {
      throw StateError('Use at least 8 characters or digits.');
    }
    await _functions!.httpsCallable('changePlayerIdPassword').call(
      <String, Object?>{'password': password},
    );
  }

  Future<String> activatePendingPlayerId(String password) async {
    final player = activePlayer;
    if (!functionsBackendEnabled ||
        player == null ||
        _functions == null ||
        !cloudConnected) {
      throw StateError('Player ID activation needs the optional Functions backend.');
    }
    if (password.length < 8) {
      throw StateError('Use at least 8 characters or digits.');
    }
    final result = await _functions!
        .httpsCallable('ensurePlayerProfile')
        .call(<String, Object?>{
          'name': player.name,
          'contactEmail': player.email,
          'idPassword': password,
        });
    final officialId = (result.data as Map?)?['playerId']?.toString();
    if (officialId == null || !RegExp(r'^\d{6,}$').hasMatch(officialId)) {
      throw StateError('The Player ID service returned an invalid ID.');
    }
    await firebaseUser?.getIdToken(true);
    final oldId = player.id;
    if (oldId != officialId) {
      final remapped = _replaceExactPlayerReferences(
        _stateData(),
        <String, String>{oldId: officialId},
      );
      _replaceState(remapped);
    }
    final upgraded = activePlayer;
    if (upgraded != null) {
      upgraded
        ..accountUid = firebaseUser?.uid
        ..claimed = true
        ..pendingSync = false;
    }
    _pendingIdPassword = null;
    await _commit();
    return officialId;
  }

  Future<void> sendPasswordReset(String email) async {
    final auth = _auth;
    if (auth == null) throw StateError('Firebase is not connected.');
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> claimSparkRegisteredPlayer(String playerId) async {
    final user = firebaseUser;
    final firestore = _firestore;
    final email = user?.email?.trim().toLowerCase();
    final normalized = playerId.trim();
    if (!cloudConnected || user == null || firestore == null) {
      throw StateError('Sign in before claiming a registered Player ID.');
    }
    if (email == null || email.isEmpty) {
      throw StateError('Use an email account to claim a registered Player ID.');
    }
    if (!RegExp(r'^\d{6,}$').hasMatch(normalized)) {
      throw StateError('Enter a valid numeric Player ID.');
    }

    final userRef = firestore.collection('users').doc(user.uid);
    final playerRef = firestore.collection('players').doc(normalized);
    final claimRef = firestore.collection('playerClaims').doc(normalized);
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final playerSnapshot = await transaction.get(playerRef);
      final claimSnapshot = await transaction.get(claimRef);
      final mapped = userSnapshot.data()?['playerId']?.toString();
      if (mapped != null && mapped.isNotEmpty && mapped != normalized) {
        throw StateError('This login already owns Player ID $mapped.');
      }
      final playerData = playerSnapshot.data();
      if (playerData == null || playerData['claimed'] != false) {
        throw StateError('This Player ID is not available to claim.');
      }
      final claimData = claimSnapshot.data();
      final claimEmail = claimData?['email']?.toString().trim().toLowerCase();
      if (claimEmail == null || claimEmail != email) {
        throw StateError(
          'Sign in with the same email used when this player was registered.',
        );
      }
      transaction.update(playerRef, {
        'ownerUid': user.uid,
        'claimed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'playerId': normalized,
        'createdAt': userSnapshot.exists
            ? (userSnapshot.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.delete(claimRef);
    });

    // Force a fresh public read after ownership changed.
    final cached = _playerIndex.remove(normalized);
    if (cached != null) players.remove(cached);
    final player = await findPublicPlayer(normalized);
    if (player == null) {
      throw StateError('Player claimed, but the profile could not be loaded.');
    }
    player
      ..accountUid = user.uid
      ..claimed = true
      ..pendingSync = false;
    activePlayerId = player.id;
    await _refreshSocialGraph();
    await _commit();
  }

  Future<void> claimProvisionalPlayer(
    String playerId,
    String temporaryPassword,
  ) async {
    if (!functionsBackendEnabled ||
        !firebaseEnabled ||
        _auth == null ||
        _functions == null) {
      throw StateError('Legacy Player-ID claiming needs the optional Functions backend.');
    }
    if (_auth!.currentUser == null) {
      await _auth!.signInAnonymously();
      await _selectCloudAccount();
    }
    final result = await _functions!.httpsCallable('claimPlayer').call(
      <String, Object?>{
        'playerId': playerId.trim(),
        'temporaryPassword': temporaryPassword,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    final claimedId = data['playerId']?.toString();
    if (claimedId == null) throw StateError('Claiming did not return a profile.');
    await firebaseUser?.getIdToken(true);
    final player = await findPlayer(claimedId);
    if (player != null) {
      player
        ..accountUid = firebaseUser?.uid
        ..claimed = true
        ..pendingSync = false;
      activePlayerId = player.id;
    }
    await _refreshSocialGraph();
    await _commit();
  }

  List<String> get linkedProviderIds =>
      firebaseUser?.providerData.map((value) => value.providerId).toList() ??
      const [];

  Future<void> disconnectProvider(String providerId) async {
    final user = firebaseUser;
    if (user == null) throw StateError('Sign in before changing connections.');
    if (!hasNumericIdLogin && user.providerData.length <= 1) {
      throw StateError(
        'Activate the global Player ID or connect another login before disconnecting this one.',
      );
    }
    await user.unlink(providerId);
    final player = activePlayer;
    if (player != null) {
      player.providerPhotoUrls.remove(providerId);
      final disconnectedSource =
          (providerId == 'google.com' &&
              player.avatarSource == AvatarSource.google) ||
          (providerId == 'facebook.com' &&
              player.avatarSource == AvatarSource.facebook);
      if (disconnectedSource) {
        player
          ..avatarSource = AvatarSource.preset
          ..avatarUrl = null;
      }
      await _commit();
    }
  }

  Future<void> deleteMyAccount() async {
    final user = firebaseUser;
    if (user == null) {
      _clearState();
      await _persistLocal();
      notifyListeners();
      return;
    }
    var backendDeletedAuth = false;
    if (functionsBackendEnabled && _functions != null) {
      try {
        await _functions!.httpsCallable('deleteMyAccountData').call();
        backendDeletedAuth = true;
      } on FirebaseFunctionsException catch (error) {
        if (!_isBackendUnavailable(error) ||
            !(activePlayer?.pendingSync ?? true)) {
          rethrow;
        }
        // Fall back to client-owned documents and Firebase Auth deletion.
      }
    }
    if (!backendDeletedAuth) {
      final player = activePlayer;
      final firestore = _firestore;
      if (firestore != null) {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('private')
            .doc('state')
            .delete();
        if (player?.accountUid == user.uid) {
          await firestore.collection('players').doc(player!.id).delete();
        }
        await firestore.collection('users').doc(user.uid).delete();
      }
      await user.delete();
    }
    await _auth?.signOut();
    _clearState();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _preferences.remove(_cloudUidKey);
    await _persistLocal();
    notifyListeners();
  }

  void _saveProviderPhoto(User? user, String providerId) {
    final player = activePlayer;
    if (player == null || user == null) return;
    for (final data in user.providerData) {
      if (data.providerId != providerId) continue;
      final photo = data.photoURL;
      if (photo != null && photo.isNotEmpty) {
        player.providerPhotoUrls[providerId] = photo;
      }
    }
  }

  Future<void> _selectCloudAccount() async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    final previousUid = await _preferences.getString(_cloudUidKey);
    if (previousUid == null) {
      final player = activePlayer;
      if (player != null) {
        player
          ..accountUid ??= uid
          ..pendingSync = true;
      }
    } else if (previousUid != uid) {
      _clearState();
      await _persistLocal();
    }
    await _preferences.setString(_cloudUidKey, uid);
  }

  Future<void> signOutCloud() async {
    await _auth?.signOut();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    notifyListeners();
  }

  Future<void> continueOffline() async {
    if (!canContinueOffline) {
      throw StateError('Sign in to open this cloud-owned player profile.');
    }
    _offlineSession = true;
    await _preferences.setBool(_offlineSessionKey, true);
    notifyListeners();
  }

  Future<void> requestCloudSignIn() async {
    if (!firebaseEnabled) return;
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    notifyListeners();
  }

  Future<void> refreshSocialGraph() => _refreshSocialGraph();

  Player? playerById(String? id) {
    if (id == null) return null;
    return _playerIndex[id];
  }

  Gang? gangById(String? id) {
    if (id == null) return null;
    for (final gang in gangs) {
      if (gang.id == id) return gang;
    }
    return null;
  }

  CricketMatch? matchById(String id) {
    for (final match in matches) {
      if (match.id == id) return match;
    }
    return null;
  }

  Future<CreatedPlayer> createPlayer({
    required String name,
    String? email,
    String? instagramHandle,
    String? idPassword,
    bool claimed = true,
    bool makeActive = false,
  }) async {
    if (!claimed) {
      return createProvisionalPlayer(
        name: name,
        email: email,
        temporaryPassword: idPassword,
        sendFriendRequest: false,
      );
    }

    String? cloudPlayerId;
    if (cloudConnected && _functions != null && functionsBackendEnabled) {
      try {
        final result = await _functions!
            .httpsCallable('ensurePlayerProfile')
            .call(<String, Object?>{
              'name': name.trim(),
              'contactEmail': _clean(email),
              'idPassword': idPassword ?? _pendingIdPassword,
            });
        cloudPlayerId = (result.data as Map?)?['playerId']?.toString();
        if (cloudPlayerId != null) await firebaseUser?.getIdToken(true);
      } on FirebaseFunctionsException catch (error) {
        if (!_isBackendUnavailable(error)) rethrow;
        // The app remains testable before the optional Functions deployment.
      }
    }

    if (cloudPlayerId == null && cloudConnected) {
      cloudPlayerId = await _ensureSparkAccountPlayerId(name.trim());
    }

    final id = cloudPlayerId ?? _uniquePlayerId();
    final claimSecretSalt = claimed ? null : _ids.eventId();
    final player = Player(
      id: id,
      name: name.trim(),
      accountUid: firebaseUser?.uid,
      email: _clean(email),
      instagramHandle: _cleanInstagram(instagramHandle),
      claimSecretHash: null,
      claimSecretSalt: claimSecretSalt,
      avatarColor: _avatarColors[players.length % _avatarColors.length],
      claimed: claimed,
      pendingSync: cloudPlayerId == null,
      createdAt: DateTime.now(),
    );
    _addOrReplacePlayer(player);
    if (makeActive || activePlayerId == null) activePlayerId = player.id;
    _saveProviderPhoto(firebaseUser, 'google.com');
    _saveProviderPhoto(firebaseUser, 'facebook.com');
    _pendingIdPassword = null;
    await _commit();
    return CreatedPlayer(player: player);
  }

  Future<CreatedPlayer> createProvisionalPlayer({
    required String name,
    String? email,
    String? temporaryPassword,
    bool sendFriendRequest = false,
  }) async {
    final creator = activePlayer;
    final requestedPassword = _clean(temporaryPassword);
    var password = requestedPassword ?? _ids.temporaryPassword();
    String? cloudPlayerId;

    if (cloudConnected && _functions != null && functionsBackendEnabled) {
      try {
        final result = await _functions!
            .httpsCallable('createProvisionalPlayer')
            .call(<String, Object?>{
              'name': name.trim(),
              'contactEmail': _clean(email),
              'temporaryPassword': requestedPassword,
            });
        final data = Map<String, dynamic>.from(result.data as Map);
        cloudPlayerId = data['playerId']?.toString();
        password = data['temporaryPassword']?.toString() ?? password;
      } on FirebaseFunctionsException catch (error) {
        if (!_isBackendUnavailable(error)) rethrow;
        // A local provisional profile is clearly marked for later sync.
      }
    }

    if (cloudPlayerId == null && cloudConnected) {
      cloudPlayerId = await _reserveSparkProvisionalPlayerId(
        name.trim(),
        email: _clean(email),
      );
    }

    final id = cloudPlayerId ?? _uniquePlayerId();
    final player = Player(
      id: id,
      name: name.trim(),
      createdByPlayerId: creator?.id,
      email: _clean(email),
      avatarColor: _avatarColors[players.length % _avatarColors.length],
      claimed: false,
      pendingSync: cloudPlayerId == null,
      createdAt: DateTime.now(),
    );
    _addOrReplacePlayer(player);
    await _commit();
    if (sendFriendRequest && creator != null) {
      await sendFriendRequestTo(player.id);
    }
    return CreatedPlayer(player: player, temporaryPassword: password);
  }

  Future<void> switchPlayer(String playerId) async {
    if (playerById(playerId) == null) throw StateError('Player not found.');
    activePlayerId = playerId;
    await _commit();
  }

  Future<void> savePlayerProfile(Player player) async {
    if (playerById(player.id) == null) {
      throw StateError('Player not found.');
    }
    if (player.id != activePlayerId && !player.isProvisional) {
      throw StateError('Only that account owner can edit a claimed player.');
    }
    if (player.name.trim().length < 2) {
      throw StateError('Player name must contain at least two characters.');
    }
    player.name = player.name.trim();
    player.instagramHandle = _cleanInstagram(player.instagramHandle);
    player.email = _clean(player.email);
    player.phoneNumber = _clean(player.phoneNumber);
    player.whatsappNumber = _clean(player.whatsappNumber);
    player.location = _clean(player.location);
    player.facebookUrl = _clean(player.facebookUrl);
    player.bio = _clean(player.bio);
    player.customBowlingStyle = _clean(player.customBowlingStyle);
    if (player.avatarSource == AvatarSource.customUrl) {
      final avatar = Uri.tryParse(player.avatarUrl ?? '');
      if (avatar == null || avatar.scheme != 'https' || avatar.host.isEmpty) {
        throw StateError('A custom avatar must use a complete HTTPS URL.');
      }
    }
    if (player.id != activePlayerId &&
        player.isProvisional &&
        player.createdByPlayerId == activePlayerId &&
        !player.pendingSync &&
        cloudConnected &&
        !functionsBackendEnabled) {
      await _syncSparkProvisionalProfile(player);
    }
    if (player.id != activePlayerId &&
        player.isProvisional &&
        player.createdByPlayerId == activePlayerId &&
        !player.pendingSync &&
        cloudConnected &&
        _functions != null &&
        functionsBackendEnabled) {
      try {
        await _functions!.httpsCallable('updateProvisionalPlayer').call(
          <String, Object?>{
            'playerId': player.id,
            'profile': <String, Object?>{
              'name': player.name,
              'bio': player.bio,
              'age': player.age,
              'instagramHandle': player.instagramHandle,
              'facebookUrl': player.facebookUrl,
              'battingStyle': player.battingStyle.name,
              'bowlingStyles': player.bowlingStyles,
              'customBowlingStyle': player.customBowlingStyle,
              'avatarSource': player.avatarSource.name,
              'avatarPreset': player.avatarPreset,
            },
            'contacts': <String, Object?>{
              for (final field in sensitiveProfileFields)
                field: <String, Object?>{
                  'value': _contactValue(player, field),
                  'visibility':
                      (player.contactVisibility[field] ??
                              ProfileVisibility.onlyMe)
                          .name,
                  'audienceIds':
                      player.contactAudienceIds[field] ?? const <String>[],
                },
            },
          },
        );
      } on FirebaseFunctionsException catch (error) {
        if (!_isBackendUnavailable(error)) rethrow;
      }
    }
    await _commit();
  }

  Future<bool> deleteCachedPlayer(String playerId) async {
    final player = playerById(playerId);
    if (player == null) return false;
    if (playerId == activePlayerId) {
      throw StateError('Use Delete account for a claimed player.');
    }
    if (player.accountUid != null) {
      player.archived = true;
      activePlayer?.friendIds.remove(playerId);
      await _commit();
      return false;
    }
    if (player.isProvisional &&
        player.createdByPlayerId == activePlayerId &&
        !player.pendingSync &&
        cloudConnected &&
        !functionsBackendEnabled) {
      try {
        final firestore = _firestore;
        if (firestore != null) {
          final batch = firestore.batch();
          batch.delete(firestore.collection('players').doc(playerId));
          batch.delete(firestore.collection('playerClaims').doc(playerId));
          await batch.commit();
        }
      } on FirebaseException {
        // Local cleanup can still continue if the network is unavailable.
      }
    }
    if (player.isProvisional &&
        player.createdByPlayerId == activePlayerId &&
        !player.pendingSync &&
        cloudConnected &&
        _functions != null &&
        functionsBackendEnabled) {
      await _functions!.httpsCallable('deleteProvisionalPlayer').call(
        <String, Object?>{'playerId': playerId},
      );
    }
    final isReferenced = matches.any(
      (match) => match.participantIds.contains(playerId),
    );
    if (isReferenced) {
      player.archived = true;
    } else {
      players.remove(player);
      _playerIndex.remove(playerId);
      for (final gang in gangs) {
        gang.members.remove(playerId);
      }
      for (final value in players) {
        value.friendIds.remove(playerId);
      }
      friendRequests.removeWhere(
        (request) =>
            request.fromPlayerId == playerId ||
            request.toPlayerId == playerId,
      );
      notifications.removeWhere((value) => value.playerId == playerId);
    }
    await _commit();
    return !isReferenced;
  }

  Future<void> resetActivePlayerData() async {
    final player = activePlayer;
    if (player == null) return;
    if (cloudConnected &&
        !player.pendingSync &&
        _functions != null &&
        functionsBackendEnabled) {
      await _functions!.httpsCallable('resetMyPlayerData').call();
    }
    matches.removeWhere((match) => match.participantIds.contains(player.id));
    for (final cached in players) {
      cached.friendIds.remove(player.id);
    }
    player.friendIds.clear();
    _clearStats(player.stats);
    _clearStats(player.teamStats);
    friendRequests.removeWhere(
      (request) =>
          request.fromPlayerId == player.id || request.toPlayerId == player.id,
    );
    notifications.removeWhere((value) => value.playerId == player.id);
    await _commit();
    if (cloudConnected) await _syncCloudState(_stateData());
  }

  void _clearStats(PlayerStats stats) {
    stats
      ..matches = 0
      ..runs = 0
      ..balls = 0
      ..outs = 0
      ..wickets = 0
      ..catches = 0
      ..directRunOuts = 0
      ..assistedRunOuts = 0
      ..stumpings = 0
      ..points = 0
      ..wins = 0;
  }

  Future<Gang> createGang(String name) async {
    final player = activePlayer;
    if (player == null) throw StateError('Create a player profile first.');
    if (player.gangId != null) {
      throw StateError('A player can join only one gang.');
    }
    final gang = Gang(
      id: _uniqueGangId(),
      name: name.trim(),
      leaderPlayerId: player.id,
      createdAt: DateTime.now(),
    );
    gangs.add(gang);
    player.gangId = gang.id;
    player.gangRole = GangRole.leader;
    await _commit();
    return gang;
  }

  Future<void> addPlayerToGang(String gangId, String playerId) async {
    final gang = gangById(gangId);
    final player = playerById(playerId);
    if (gang == null || player == null) {
      throw StateError('Gang or player not found.');
    }
    if (player.gangId != null && player.gangId != gangId) {
      throw StateError('This player already belongs to another gang.');
    }
    if (gang.members.containsKey(playerId)) {
      throw StateError('This player is already in the gang.');
    }
    gang.members[playerId] = GangRole.member;
    player.gangId = gangId;
    player.gangRole = GangRole.member;
    await _commit();
  }

  Future<void> setGangRole(
    String gangId,
    String playerId,
    GangRole role,
  ) async {
    final gang = gangById(gangId);
    final player = playerById(playerId);
    if (gang == null || player == null) {
      throw StateError('Gang or player not found.');
    }
    if (!gang.members.containsKey(playerId)) {
      throw StateError('This player is not a member of the gang.');
    }
    if (gang.leaderPlayerId == playerId && role != GangRole.leader) {
      throw StateError('Transfer leadership before changing this role.');
    }
    if (role == GangRole.leader && gang.leaderPlayerId != playerId) {
      final previous = playerById(gang.leaderPlayerId);
      if (previous != null) previous.gangRole = GangRole.coLeader;
      gang.members[gang.leaderPlayerId] = GangRole.coLeader;
      gang.leaderPlayerId = playerId;
    }
    gang.members[playerId] = role;
    player.gangRole = role;
    await _commit();
  }

  bool areFriends(String firstPlayerId, String secondPlayerId) =>
      playerById(firstPlayerId)?.friendIds.contains(secondPlayerId) ?? false;

  Future<Player?> findPublicPlayer(String playerId) async {
    final normalized = playerId.trim();
    if (!RegExp(r'^\d{6,}$').hasMatch(normalized)) return null;
    final cached = playerById(normalized);
    if (cached != null) return cached;
    final firestore = _firestore;
    if (!cloudConnected || firestore == null) return null;
    try {
      final snapshot = await firestore.collection('players').doc(normalized).get();
      final data = snapshot.data();
      if (data == null) return null;
      final player = Player.fromJson(<String, dynamic>{
        ...data,
        'id': normalized,
        'createdAt':
            data['joinedAt']?.toString() ?? DateTime.now().toIso8601String(),
      });
      _addOrReplacePlayer(player);
      await _persistLocal();
      notifyListeners();
      return player;
    } on FirebaseException {
      return null;
    }
  }

  Future<Player?> findPlayer(String playerId) async {
    final normalized = playerId.trim();
    if (!RegExp(r'^\d{6,}$').hasMatch(normalized)) return null;
    final player = await findPublicPlayer(normalized);
    if (player == null) return null;
    final firestore = _firestore;
    if (!cloudConnected || firestore == null) return player;
    try {
      for (final field in sensitiveProfileFields) {
        try {
          final contact = await firestore
              .collection('players')
              .doc(normalized)
              .collection('contactFields')
              .doc(field)
              .get();
          final contactData = contact.data();
          if (contactData == null) continue;
          _setContactValue(player, field, contactData['value'] as String?);
          final visibility = contactData['visibility'] as String?;
          if (visibility != null &&
              ProfileVisibility.values.any(
                (value) => value.name == visibility,
              )) {
            player.contactVisibility[field] =
                ProfileVisibility.values.byName(visibility);
          }
          player.contactAudienceIds[field] = List<String>.from(
            contactData['audienceIds'] as List? ?? const [],
          );
        } on FirebaseException {
          // A field hidden by its owner is intentionally unavailable.
        }
      }
      await _persistLocal();
      notifyListeners();
      return player;
    } on FirebaseException {
      return player;
    }
  }

  Future<void> sendFriendRequestTo(
    String friendId, {
    Player? knownPlayer,
  }) async {
    final player = activePlayer;
    final friend = knownPlayer ?? await findPublicPlayer(friendId);
    if (player == null || friend == null || player.id == friendId) {
      throw StateError('Choose another valid numeric Player ID.');
    }
    if (player.friendIds.contains(friendId)) {
      throw StateError('This player is already your friend.');
    }
    final existing = pendingRequestWith(friendId);
    if (existing != null) {
      if (existing.fromPlayerId == player.id) {
        throw StateError('Friend request already sent.');
      }
      throw StateError('This player has already sent you a request.');
    }

    final user = firebaseUser;
    final firestore = _firestore;
    final targetUid = friend.accountUid;
    String requestId = _friendPairKey(player.id, friendId);

    if (cloudConnected && user != null && firestore != null) {
      if (targetUid == null || targetUid.isEmpty) {
        throw StateError(
          'This Player ID is not connected to an app account yet.',
        );
      }
      final requestRef = firestore.collection('friendRequests').doc(requestId);
      final friendshipRef = firestore.collection('friendships').doc(requestId);
      final notificationRef = firestore.collection('notifications').doc();
      await firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        final friendshipSnapshot = await transaction.get(friendshipRef);
        if (friendshipSnapshot.exists) {
          throw StateError('This player is already your friend.');
        }
        if (requestSnapshot.exists &&
            requestSnapshot.data()?['status'] == 'pending') {
          throw StateError('A friend request is already pending.');
        }
        transaction.set(requestRef, {
          'fromUid': user.uid,
          'fromPlayerId': player.id,
          'toUid': targetUid,
          'toPlayerId': friendId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(notificationRef, {
          'recipientUid': targetUid,
          'recipientPlayerId': friendId,
          'fromUid': user.uid,
          'fromPlayerId': player.id,
          'type': 'friendRequest',
          'requestId': requestId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }

    friendRequests.removeWhere((value) => value.id == requestId);
    friendRequests.add(
      FriendRequest(
        id: requestId,
        fromPlayerId: player.id,
        toPlayerId: friendId,
        createdAt: DateTime.now(),
      ),
    );
    await _persistLocal();
    notifyListeners();
  }

  Future<void> respondToFriendRequest(
    String requestId, {
    required bool accept,
  }) async {
    final request = friendRequests.cast<FriendRequest?>().firstWhere(
      (value) => value?.id == requestId,
      orElse: () => null,
    );
    if (request == null || request.status != FriendRequestStatus.pending) {
      throw StateError('This friend request is no longer pending.');
    }
    if (request.toPlayerId != activePlayerId) {
      throw StateError('Only the receiving player can respond.');
    }

    final user = firebaseUser;
    final firestore = _firestore;
    if (cloudConnected && user != null && firestore != null) {
      final requestRef = firestore.collection('friendRequests').doc(requestId);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(requestRef);
        final data = snapshot.data();
        if (!snapshot.exists || data?['status'] != 'pending') {
          throw StateError('Pending request not found.');
        }
        if (data?['toUid'] != user.uid) {
          throw StateError('Only the receiving player can respond.');
        }
        if (accept) {
          transaction.update(requestRef, {
            'status': 'accepted',
            'respondedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.delete(requestRef);
        }
        if (accept) {
          final fromUid = data?['fromUid']?.toString();
          final fromPlayerId = data?['fromPlayerId']?.toString();
          final toPlayerId = data?['toPlayerId']?.toString();
          if (fromUid == null || fromPlayerId == null || toPlayerId == null) {
            throw StateError('Friend request data is incomplete.');
          }
          final pairKey = _friendPairKey(fromPlayerId, toPlayerId);
          final friendshipRef = firestore.collection('friendships').doc(pairKey);
          transaction.set(friendshipRef, {
            'playerIds': [fromPlayerId, toPlayerId],
            'uids': [fromUid, user.uid],
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(
            firestore
                .collection('players')
                .doc(fromPlayerId)
                .collection('friends')
                .doc(toPlayerId),
            {
              'playerId': toPlayerId,
              'friendshipId': pairKey,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          transaction.set(
            firestore
                .collection('players')
                .doc(toPlayerId)
                .collection('friends')
                .doc(fromPlayerId),
            {
              'playerId': fromPlayerId,
              'friendshipId': pairKey,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          final notificationRef = firestore.collection('notifications').doc();
          transaction.set(notificationRef, {
            'recipientUid': fromUid,
            'recipientPlayerId': fromPlayerId,
            'fromUid': user.uid,
            'fromPlayerId': toPlayerId,
            'type': 'friendAccepted',
            'requestId': requestId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }

    request
      ..status = accept
          ? FriendRequestStatus.accepted
          : FriendRequestStatus.rejected
      ..respondedAt = DateTime.now();
    if (accept) {
      final sender = await findPlayer(request.fromPlayerId);
      final receiver = activePlayer;
      if (sender != null && receiver != null) {
        if (!sender.friendIds.contains(receiver.id)) {
          sender.friendIds.add(receiver.id);
        }
        if (!receiver.friendIds.contains(sender.id)) {
          receiver.friendIds.add(sender.id);
        }
      }
    }
    await _persistLocal();
    notifyListeners();
  }

  Future<void> removeFriend(String friendPlayerId) async {
    final player = activePlayer;
    if (player == null || !player.friendIds.contains(friendPlayerId)) {
      throw StateError('Friendship not found.');
    }
    final firestore = _firestore;
    if (cloudConnected && firestore != null) {
      final key = _friendPairKey(player.id, friendPlayerId);
      final batch = firestore.batch();
      batch.delete(firestore.collection('friendships').doc(key));
      batch.delete(firestore.collection('friendRequests').doc(key));
      batch.delete(
        firestore
            .collection('players')
            .doc(player.id)
            .collection('friends')
            .doc(friendPlayerId),
      );
      batch.delete(
        firestore
            .collection('players')
            .doc(friendPlayerId)
            .collection('friends')
            .doc(player.id),
      );
      await batch.commit();
    }
    player.friendIds.remove(friendPlayerId);
    final friend = playerById(friendPlayerId);
    friend?.friendIds.remove(player.id);
    if (friend != null) {
      for (final field in sensitiveProfileFields) {
        if (!friend.canViewField(
          field,
          viewerPlayerId: player.id,
          areFriends: false,
        )) {
          _setContactValue(friend, field, null);
        }
      }
    }
    await _persistLocal();
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    for (final value in notifications) {
      if (value.id == notificationId && value.playerId == activePlayerId) {
        value.read = true;
      }
    }
    final firestore = _firestore;
    if (cloudConnected && firestore != null) {
      try {
        await firestore.collection('notifications').doc(notificationId).update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        // Keep the local read state; the next manual refresh can retry.
      }
    }
    await _persistLocal();
    notifyListeners();
  }

  Future<CricketMatch> createMatch({
    required String title,
    required ScoringMode scoringMode,
    required int ballLimit,
    required List<String> participantIds,
    required MatchWinnerMetric winnerMetric,
    String? trackerPlayerId,
    PointRules pointRules = const PointRules(),
  }) async {
    final creator = activePlayer;
    if (creator == null) throw StateError('Create a player profile first.');
    final uniqueParticipants = participantIds.toSet().toList();
    if (uniqueParticipants.length < 2) {
      throw StateError('A singles match needs at least two players.');
    }
    if (ballLimit < 1) throw StateError('Ball limit must be at least one.');
    if (uniqueParticipants.any((id) => playerById(id) == null)) {
      throw StateError('Every participant needs a valid Player ID.');
    }
    if (trackerPlayerId != null &&
        !uniqueParticipants.contains(trackerPlayerId)) {
      throw StateError('The selected tracker must be in this match.');
    }
    final match = CricketMatch(
      id: _uniqueMatchId(),
      title: title.trim().isEmpty ? 'Local Singles Match' : title.trim(),
      creatorPlayerId: creator.id,
      scoringMode: scoringMode,
      ballLimit: ballLimit,
      participantIds: uniqueParticipants,
      createdAt: DateTime.now(),
      status: MatchStatus.drawing,
      winnerMetric: winnerMetric,
      trackerPlayerId: trackerPlayerId,
      pointRules: pointRules,
    );
    _createDrawPool(match);
    matches.add(match);
    await _commit();
    return match;
  }

  List<DrawCard> availableDrawCards(CricketMatch match) {
    final used = match.drawAssignments.values
        .map((value) => value.card.id)
        .toSet();
    return match.drawPool.where((card) => !used.contains(card.id)).toList();
  }

  String? nextDrawPlayerId(CricketMatch match) {
    for (final playerId in match.participantIds) {
      if (!match.drawAssignments.containsKey(playerId)) return playerId;
    }
    return null;
  }

  Future<DrawAssignment> chooseDrawCard(
    String matchId,
    String playerId,
    String cardId,
  ) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.drawing) {
      throw StateError('The draw is not active.');
    }
    if (nextDrawPlayerId(match) != playerId) {
      throw StateError('It is another player’s turn to draw.');
    }
    final card = availableDrawCards(match).firstWhere(
      (value) => value.id == cardId,
      orElse: () => throw StateError('That card has already been selected.'),
    );
    final assignment = DrawAssignment(playerId: playerId, card: card);
    match.drawAssignments[playerId] = assignment;

    final remainingPlayers = match.participantIds
        .where((id) => !match.drawAssignments.containsKey(id))
        .toList();
    final remainingCards = availableDrawCards(match);
    if (remainingPlayers.length == 1 && remainingCards.length == 1) {
      match.drawAssignments[remainingPlayers.single] = DrawAssignment(
        playerId: remainingPlayers.single,
        card: remainingCards.single,
      );
    }
    if (match.drawAssignments.length == match.participantIds.length) {
      _finalizeDraw(match);
    }
    await _commit();
    return assignment;
  }

  Future<void> resetDraw(String matchId) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.drawing) {
      throw StateError('Only an unfinished draw can be reset.');
    }
    match.drawAssignments.clear();
    match.battingOrder.clear();
    _createDrawPool(match);
    await _commit();
  }

  Future<void> startMatch(String matchId) async {
    final match = matchById(matchId);
    if (match == null ||
        match.status != MatchStatus.drawing ||
        match.battingOrder.length != match.participantIds.length) {
      throw StateError('Complete the secret draw first.');
    }
    match.status = MatchStatus.live;
    await _commit();
  }

  Future<void> setBattingOrder(String matchId, List<String> order) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.drawing) {
      throw StateError('Batting order can be changed only before the match.');
    }
    if (order.length != match.participantIds.length ||
        order.toSet().length != match.participantIds.length ||
        !order.toSet().containsAll(match.participantIds)) {
      throw StateError(
        'The batting order must contain every selected player once.',
      );
    }
    match.battingOrder
      ..clear()
      ..addAll(order);
    await _commit();
  }

  Future<void> moveCurrentBatterToEnd(String matchId) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    final current = ScoringEngine.currentBatterId(match);
    if (current == null) throw StateError('Every turn is already complete.');
    final states = ScoringEngine.rebuildTurns(match);
    final remaining = match.battingOrder
        .where((id) => !(states[id]?.isComplete(match.ballLimit) ?? false))
        .toList();
    if (remaining.length < 2) {
      throw StateError('There is no other remaining player to send next.');
    }
    match.battingOrder
      ..remove(current)
      ..add(current);
    await _commit();
  }

  Future<void> recordDelivery(
    String matchId, {
    required int batRuns,
    int extraRuns = 0,
    ExtraType extraType = ExtraType.none,
    bool legalBall = true,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
  }) async {
    final match = matchById(matchId);
    if (match == null) throw StateError('Match not found.');
    ScoringEngine.recordDelivery(
      match,
      eventId: _ids.eventId(),
      batRuns: batRuns,
      extraRuns: extraRuns,
      extraType: extraType,
      legalBall: legalBall,
      isOut: isOut,
      dismissalType: dismissalType,
      bowlerId: bowlerId,
      fielderIds: fielderIds,
    );
    _applyStatsIfComplete(match);
    await _commit();
  }

  Future<void> recordQuickTotal(
    String matchId, {
    required int runs,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
  }) async {
    final match = matchById(matchId);
    if (match == null) throw StateError('Match not found.');
    ScoringEngine.recordQuickTotal(
      match,
      eventId: _ids.eventId(),
      runs: runs,
      isOut: isOut,
      dismissalType: dismissalType,
      bowlerId: bowlerId,
      fielderIds: fielderIds,
    );
    _applyStatsIfComplete(match);
    await _commit();
  }

  Future<bool> undoLast(String matchId) async {
    final match = matchById(matchId);
    if (match == null) return false;
    if (match.statsApplied) _revertAppliedStats(match);
    final changed = ScoringEngine.undoLast(match);
    await _commit();
    return changed;
  }

  Future<int> resetCurrentTurn(String matchId) async {
    final match = matchById(matchId);
    if (match == null) return 0;
    final changed = ScoringEngine.resetCurrentTurn(match);
    await _commit();
    return changed;
  }

  Future<void> _commit() async {
    final data = _stateData();
    await _persistLocal(data);
    unawaited(_syncCloudState(data));
    notifyListeners();
  }

  Future<void> _persistLocal([Map<String, Object?>? state]) => _preferences
      .setString(_storageKey, jsonEncode(state ?? _stateData()));

  Map<String, Object?> _stateData() => {
    'activePlayerId': activePlayerId,
    'players': players.map((value) => value.toJson()).toList(),
    'gangs': gangs.map((value) => value.toJson()).toList(),
    'matches': matches.map((value) => value.toJson()).toList(),
    'friendRequests': friendRequests.map((value) => value.toJson()).toList(),
    'notifications': notifications.map((value) => value.toJson()).toList(),
    'schemaVersion': 2,
  };

  void _replaceState(Map<String, dynamic> json) {
    json = _migrateLegacyPlayerIds(json);
    _clearState();
    activePlayerId = json['activePlayerId'] as String?;
    players.addAll(
      (json['players'] as List? ?? const []).map(
        (value) => Player.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    _rebuildPlayerIndex();
    gangs.addAll(
      (json['gangs'] as List? ?? const []).map(
        (value) => Gang.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    matches.addAll(
      (json['matches'] as List? ?? const []).map(
        (value) =>
            CricketMatch.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    friendRequests.addAll(
      (json['friendRequests'] as List? ?? const []).map(
        (value) =>
            FriendRequest.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    notifications.addAll(
      (json['notifications'] as List? ?? const []).map(
        (value) =>
            CricNotification.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Map<String, dynamic> _migrateLegacyPlayerIds(Map<String, dynamic> state) {
    final rawPlayers = state['players'] as List? ?? const [];
    final used = <String>{};
    final replacements = <String, String>{};
    for (final value in rawPlayers) {
      final player = Map<String, dynamic>.from(value as Map);
      final id = player['id']?.toString();
      if (id != null && RegExp(r'^\d{6,}$').hasMatch(id)) used.add(id);
    }
    for (final value in rawPlayers) {
      final player = Map<String, dynamic>.from(value as Map);
      final id = player['id']?.toString();
      if (id == null || RegExp(r'^\d{6,}$').hasMatch(id)) continue;
      final bytes = sha256.convert(utf8.encode('cricxii-legacy:$id')).bytes;
      var numeric =
          100000 +
          (((bytes[0] << 24) |
                  (bytes[1] << 16) |
                  (bytes[2] << 8) |
                  bytes[3]) &
              0x7fffffff) %
              900000;
      while (used.contains('$numeric')) {
        numeric = numeric == 999999 ? 100000 : numeric + 1;
      }
      replacements[id] = '$numeric';
      used.add('$numeric');
    }
    if (replacements.isEmpty) return state;

    final migrated = _replaceExactPlayerReferences(state, replacements);
    final migratedPlayers = migrated['players'] as List? ?? const [];
    for (final value in migratedPlayers) {
      final player = value as Map;
      if (replacements.containsValue(player['id'])) {
        player['pendingSync'] = true;
      }
    }
    migrated['schemaVersion'] = 2;
    return migrated;
  }

  Map<String, dynamic> _replaceExactPlayerReferences(
    Map<String, Object?> state,
    Map<String, String> replacements,
  ) {
    Object? replace(Object? value) {
      if (value is String) return replacements[value] ?? value;
      if (value is List) return value.map(replace).toList();
      if (value is Map) {
        return <String, Object?>{
          for (final entry in value.entries)
            (replacements[entry.key.toString()] ?? entry.key.toString()):
                replace(entry.value),
        };
      }
      return value;
    }

    return Map<String, dynamic>.from(replace(state) as Map);
  }

  void _clearState() {
    players.clear();
    _playerIndex.clear();
    gangs.clear();
    matches.clear();
    friendRequests.clear();
    notifications.clear();
    activePlayerId = null;
  }

  Future<void> _syncCloudState(Map<String, Object?> state) async {
    final user = firebaseUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;
    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('state')
          .set({
            'state': jsonEncode(state),
            'schemaVersion': 2,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      final player = activePlayer;
      if (player != null && !player.pendingSync) {
        player.accountUid ??= user.uid;
        final playerRef = firestore.collection('players').doc(player.id);
        await playerRef.set({
          ...player.toPublicJson(),
          'ownerUid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final batch = firestore.batch();
        for (final field in sensitiveProfileFields) {
          final value = _contactValue(player, field);
          final ref = playerRef.collection('contactFields').doc(field);
          if (value == null || value.isEmpty) {
            batch.delete(ref);
          } else {
            batch.set(ref, {
              'ownerUid': user.uid,
              'ownerPlayerId': player.id,
              'value': value,
              'visibility':
                  (player.contactVisibility[field] ??
                          ProfileVisibility.onlyMe)
                      .name,
              'audienceIds': player.contactAudienceIds[field] ?? const [],
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await batch.commit();
      }
    } on FirebaseException {
      // Local scoring remains authoritative while the ground is offline.
    }
  }

  Future<void> _restoreCloudState({bool replaceLocal = false}) async {
    final user = firebaseUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('state')
          .get();
      final raw = snapshot.data()?['state'] as String?;
      if (raw == null || raw.isEmpty) return;
      if (replaceLocal || players.isEmpty) {
        _replaceState(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        activePlayer?.accountUid ??= user.uid;
        await _preferences.setString(_storageKey, jsonEncode(_stateData()));
      }
    } on FirebaseException {
      // A cached local match can still continue if Firebase is unreachable.
    }
  }

  Future<void> _refreshSocialGraph() async {
    final user = firebaseUser;
    final firestore = _firestore;
    final self = activePlayer;
    if (user == null || firestore == null || self == null) return;
    try {
      final results = await Future.wait([
        firestore
            .collection('friendRequests')
            .where('toUid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
        firestore
            .collection('friendRequests')
            .where('fromUid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
        firestore
            .collection('notifications')
            .where('recipientUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
        firestore
            .collection('friendships')
            .where('uids', arrayContains: user.uid)
            .limit(200)
            .get(),
      ]);

      final incomingSnapshot = results[0];
      final outgoingSnapshot = results[1];
      final requestDocuments = [...incomingSnapshot.docs, ...outgoingSnapshot.docs];
      final cloudPendingIds = requestDocuments.map((document) => document.id).toSet();
      friendRequests.removeWhere(
        (request) =>
            request.status == FriendRequestStatus.pending &&
            (request.toPlayerId == self.id || request.fromPlayerId == self.id) &&
            !cloudPendingIds.contains(request.id),
      );
      for (final document in requestDocuments) {
        final data = document.data();
        final fromId = data['fromPlayerId']?.toString();
        final toId = data['toPlayerId']?.toString();
        if (fromId == null || toId == null) continue;
        final otherId = fromId == self.id ? toId : fromId;
        await findPublicPlayer(otherId);
        final existing = friendRequests.where((value) => value.id == document.id);
        if (existing.isEmpty) {
          friendRequests.add(
            FriendRequest(
              id: document.id,
              fromPlayerId: fromId,
              toPlayerId: toId,
              createdAt: _dateFromCloud(data['createdAt']),
            ),
          );
        }
      }

      final notificationSnapshot = results[2];
      for (final document in notificationSnapshot.docs) {
        final data = document.data();
        final existing = notifications.where((value) => value.id == document.id);
        if (existing.isNotEmpty) {
          existing.first.read = data['read'] as bool? ?? false;
          continue;
        }
        final typeName = data['type']?.toString() ?? 'system';
        final fromId = data['fromPlayerId']?.toString();
        final sender = fromId == null ? null : await findPublicPlayer(fromId);
        final type = NotificationType.values.any((value) => value.name == typeName)
            ? NotificationType.values.byName(typeName)
            : NotificationType.system;
        notifications.add(
          CricNotification(
            id: document.id,
            playerId: self.id,
            type: type,
            title: switch (type) {
              NotificationType.friendRequest => 'New friend request',
              NotificationType.friendAccepted => 'Friend request accepted',
              _ => 'CricXii update',
            },
            body: switch (type) {
              NotificationType.friendRequest =>
                '${sender?.name ?? fromId ?? 'A player'} wants to connect.',
              NotificationType.friendAccepted =>
                '${sender?.name ?? fromId ?? 'A player'} is now your friend.',
              _ => 'Your CricXii account has an update.',
            },
            referenceId: data['requestId']?.toString(),
            createdAt: _dateFromCloud(data['createdAt']),
            read: data['read'] as bool? ?? false,
          ),
        );
      }

      final friendshipSnapshot = results[3];
      final cloudFriendIds = <String>{};
      for (final document in friendshipSnapshot.docs) {
        final ids = List<String>.from(document.data()['playerIds'] as List? ?? const []);
        for (final id in ids.where((value) => value != self.id)) {
          cloudFriendIds.add(id);
          await findPublicPlayer(id);
        }
      }
      self.friendIds
        ..clear()
        ..addAll(cloudFriendIds);
      for (final cached in players.where((player) => player.id != self.id)) {
        if (cloudFriendIds.contains(cached.id)) {
          if (!cached.friendIds.contains(self.id)) cached.friendIds.add(self.id);
        } else {
          cached.friendIds.remove(self.id);
        }
      }
      await _persistLocal();
      notifyListeners();
    } on FirebaseException {
      // Cached local social data remains usable. Refresh can be retried manually.
    }
  }

  DateTime _dateFromCloud(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String _friendPairKey(String firstPlayerId, String secondPlayerId) {
    final ids = <String>[firstPlayerId, secondPlayerId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> _reserveSparkProvisionalPlayerId(
    String name, {
    String? email,
  }) async {
    final creator = activePlayer;
    final user = firebaseUser;
    final firestore = _firestore;
    if (creator == null || user == null || firestore == null) {
      return _uniquePlayerId();
    }
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate =
          (10000000 + Random.secure().nextInt(90000000)).toString();
      final ref = firestore.collection('players').doc(candidate);
      final claimRef = firestore.collection('playerClaims').doc(candidate);
      try {
        await firestore.runTransaction((transaction) async {
          final collision = await transaction.get(ref);
          if (collision.exists) throw StateError('Player ID collision');
          transaction.set(ref, {
            'playerId': candidate,
            'ownerUid': null,
            'createdByUid': user.uid,
            'createdByPlayerId': creator.id,
            'name': name,
            'claimed': false,
            'archived': false,
            'joinedAt': DateTime.now().toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          final normalizedEmail = email?.trim().toLowerCase();
          if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
            transaction.set(claimRef, {
              'playerId': candidate,
              'email': normalizedEmail,
              'createdByUid': user.uid,
              'createdByPlayerId': creator.id,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        });
        return candidate;
      } on StateError {
        continue;
      }
    }
    throw StateError('Could not reserve a temporary Player ID. Try again.');
  }

  Future<void> _syncSparkProvisionalProfile(Player player) async {
    final user = firebaseUser;
    final creator = activePlayer;
    final firestore = _firestore;
    if (user == null || creator == null || firestore == null) return;
    try {
      final batch = firestore.batch();
      batch.set(
        firestore.collection('players').doc(player.id),
        {
          ...player.toPublicJson(),
          'ownerUid': null,
          'createdByUid': user.uid,
          'createdByPlayerId': creator.id,
          'claimed': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final email = player.email?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        batch.set(
          firestore.collection('playerClaims').doc(player.id),
          {
            'playerId': player.id,
            'email': email,
            'createdByUid': user.uid,
            'createdByPlayerId': creator.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } on FirebaseException {
      // The registered player remains cached locally and can retry on next edit.
    }
  }

  Future<String> _ensureSparkAccountPlayerId(String name) async {
    final user = firebaseUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return _uniquePlayerId();
    final userRef = firestore.collection('users').doc(user.uid);
    final existing = await userRef.get();
    final existingId = existing.data()?['playerId']?.toString();
    if (existingId != null && RegExp(r'^\d{6,}$').hasMatch(existingId)) {
      return existingId;
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate = (10000000 + Random.secure().nextInt(90000000)).toString();
      final playerRef = firestore.collection('players').doc(candidate);
      try {
        final reserved = await firestore.runTransaction<String>((transaction) async {
          final latestUser = await transaction.get(userRef);
          final mapped = latestUser.data()?['playerId']?.toString();
          if (mapped != null && RegExp(r'^\d{6,}$').hasMatch(mapped)) {
            return mapped;
          }
          final collision = await transaction.get(playerRef);
          if (collision.exists) throw StateError('Player ID collision');
          transaction.set(userRef, {
            'playerId': candidate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(playerRef, {
            'playerId': candidate,
            'ownerUid': user.uid,
            'name': name,
            'claimed': true,
            'archived': false,
            'joinedAt': DateTime.now().toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          return candidate;
        });
        return reserved;
      } on StateError {
        continue;
      }
    }
    throw StateError('Could not reserve a unique Player ID. Try again.');
  }

  String _uniquePlayerId() {
    var id = _ids.playerId();
    while (playerById(id) != null) {
      id = _ids.playerId();
    }
    return id;
  }

  void _addOrReplacePlayer(Player player) {
    final existing = _playerIndex[player.id];
    if (existing != null) players.remove(existing);
    players.add(player);
    _playerIndex[player.id] = player;
  }

  void _rebuildPlayerIndex() {
    _playerIndex
      ..clear()
      ..addEntries(players.map((player) => MapEntry(player.id, player)));
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  bool _isBackendUnavailable(FirebaseFunctionsException error) => const {
    'not-found',
    'unimplemented',
    'unavailable',
    'deadline-exceeded',
  }.contains(error.code);

  String? _cleanInstagram(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) return null;
    final uri = Uri.tryParse(cleaned);
    if (uri != null && uri.host.toLowerCase().contains('instagram.com')) {
      final segments = uri.pathSegments.where((part) => part.isNotEmpty);
      if (segments.isNotEmpty) return segments.first.replaceFirst('@', '');
    }
    return cleaned.replaceFirst('@', '');
  }

  String? _contactValue(Player player, String field) => switch (field) {
    'email' => player.email,
    'phone' => player.phoneNumber,
    'whatsapp' => player.whatsappNumber,
    'location' => player.location,
    _ => null,
  };

  void _setContactValue(Player player, String field, String? value) {
    switch (field) {
      case 'email':
        player.email = value;
        break;
      case 'phone':
        player.phoneNumber = value;
        break;
      case 'whatsapp':
        player.whatsappNumber = value;
        break;
      case 'location':
        player.location = value;
        break;
    }
  }

  String _uniqueGangId() {
    var id = _ids.gangId();
    while (gangById(id) != null) {
      id = _ids.gangId();
    }
    return id;
  }

  String _uniqueMatchId() {
    var id = _ids.matchId();
    while (matchById(id) != null) {
      id = _ids.matchId();
    }
    return id;
  }

  void _createDrawPool(CricketMatch match) {
    const colors = <int>[
      0xFF19C37D,
      0xFFFFB020,
      0xFF7C5CFC,
      0xFF2D9CDB,
      0xFFE85D75,
      0xFF00A6A6,
      0xFFF97316,
      0xFF4F46E5,
      0xFFA855F7,
      0xFF84CC16,
    ];
    match.drawPool
      ..clear()
      ..addAll(
        List.generate(
          match.participantIds.length,
          (index) => DrawCard(
            id: _ids.cardId(),
            order: index + 1,
            colorValue: colors[index % colors.length],
          ),
        )..shuffle(Random.secure()),
      );
  }

  void _finalizeDraw(CricketMatch match) {
    final ordered = match.drawAssignments.values.toList()
      ..sort((a, b) => a.card.order.compareTo(b.card.order));
    match.battingOrder
      ..clear()
      ..addAll(ordered.map((value) => value.playerId));
  }

  void _applyStatsIfComplete(CricketMatch match) {
    if (match.status != MatchStatus.completed || match.statsApplied) return;
    final stats = ScoringEngine.calculateStats(match);
    for (final entry in stats.entries) {
      final player = playerById(entry.key);
      if (player == null) continue;
      final value = entry.value;
      player.stats
        ..matches += 1
        ..runs += value.runs
        ..balls += value.balls
        ..outs += value.isOut ? 1 : 0
        ..wickets += value.wickets
        ..catches += value.catches
        ..directRunOuts += value.directRunOuts
        ..assistedRunOuts += value.assistedRunOuts
        ..stumpings += value.stumpings
        ..points += value.points;
    }
    final rankings = ScoringEngine.rankings(match);
    if (rankings.isNotEmpty) {
      playerById(rankings.first.playerId)?.stats.wins += 1;
    }
    match.statsApplied = true;
  }

  void _revertAppliedStats(CricketMatch match) {
    if (!match.statsApplied) return;
    final stats = ScoringEngine.calculateStats(match);
    final rankings = ScoringEngine.rankings(match);
    for (final entry in stats.entries) {
      final player = playerById(entry.key);
      if (player == null) continue;
      final value = entry.value;
      player.stats
        ..matches -= 1
        ..runs -= value.runs
        ..balls -= value.balls
        ..outs -= value.isOut ? 1 : 0
        ..wickets -= value.wickets
        ..catches -= value.catches
        ..directRunOuts -= value.directRunOuts
        ..assistedRunOuts -= value.assistedRunOuts
        ..stumpings -= value.stumpings
        ..points -= value.points;
    }
    if (rankings.isNotEmpty) {
      playerById(rankings.first.playerId)?.stats.wins -= 1;
    }
    match.statsApplied = false;
  }
}
