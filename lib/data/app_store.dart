import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/id_generator.dart';
import '../domain/cricket_match.dart';
import '../domain/daily_performance.dart';
import '../domain/enums.dart';
import '../domain/gang.dart';
import '../domain/match_planning.dart';
import '../domain/player.dart';
import '../domain/player_history.dart';
import '../domain/scoring_engine.dart';
import '../domain/social.dart';

class CreatedPlayer {
  const CreatedPlayer({required this.player, required this.loginEmail});

  final Player player;
  final String loginEmail;
}

class AppStore extends ChangeNotifier {
  AppStore({IdGenerator? ids, this.firebaseEnabled = false})
    : _ids = ids ?? IdGenerator();

  static const _storageKey = 'texiol_local_cricket_state_v4';
  static const _accountPlayerIdKey = 'cricxii_account_player_id_v4';
  static const _accountEmailKey = 'cricxii_account_email_v4';
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
  SharedPreferencesAsync? _preferencesInstance;
  SharedPreferencesAsync get _preferences =>
      _preferencesInstance ??= SharedPreferencesAsync();
  final bool firebaseEnabled;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  bool _accountSignedIn = false;
  String? _accountEmail;
  final Map<String, Player> _playerIndex = <String, Player>{};
  final List<Player> players = <Player>[];
  final List<Gang> gangs = <Gang>[];
  final List<CricketMatch> matches = <CricketMatch>[];
  final List<FriendRequest> friendRequests = <FriendRequest>[];
  final List<CricNotification> notifications = <CricNotification>[];
  final List<PointPreset> pointPresets = <PointPreset>[];
  final Set<String> _sharedMatchIds = <String>{};
  final Set<String> _pendingSharedMatchDeletes = <String>{};
  final Map<String, String> _lastSharedMatchPayloads = <String, String>{};
  String? _lastPublicProfileFingerprint;
  Future<void> _cloudSyncTail = Future<void>.value();
  Map<String, Object?>? _pendingCloudState;
  bool _cloudSyncRunning = false;
  String defaultPointPresetId = 'balanced';

  bool initialized = false;
  String? activePlayerId;

  User? get firebaseUser => _auth?.currentUser;
  String? get accountEmail => _accountEmail;
  bool get requiresAuthentication => !_accountSignedIn;
  bool get cloudConnected =>
      firebaseEnabled && firebaseUser != null && _accountSignedIn;

  Player? get activePlayer => playerById(activePlayerId);

  PointPreset get defaultPointPreset {
    _ensurePointPresets();
    return pointPresets.firstWhere(
      (preset) => preset.id == defaultPointPresetId,
      orElse: () => pointPresets.first,
    );
  }

  DailyPerformanceSummary performanceForDate(DateTime date) =>
      DailyPerformanceSummary.build(date, matches);

  String suggestMatchTitle([DateTime? at]) {
    final now = at ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final number = matches.where((match) {
      return !match.createdAt.isBefore(start) && match.createdAt.isBefore(end);
    }).length + 1;
    final period = switch (now.hour) {
      < 12 => 'Morning',
      < 17 => 'Afternoon',
      < 21 => 'Evening',
      _ => 'Night',
    };
    return '$period Match $number';
  }

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

  bool isActiveMatchForPlayer(CricketMatch match, String playerId) {
    if (!match.participantIds.contains(playerId)) return false;
    return switch (match.status) {
      MatchStatus.draft || MatchStatus.drawing || MatchStatus.live => true,
      MatchStatus.completed => false,
    };
  }

  List<CricketMatch> get activeMatches {
    final id = activePlayerId;
    if (id == null) return const [];
    return matches.where((match) => isActiveMatchForPlayer(match, id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool canControlMatch(CricketMatch match) {
    final id = activePlayerId;
    return id != null &&
        match.creatorPlayerId == id &&
        match.participantIds.contains(id);
  }

  Future<void> cancelMatch(String matchId) async {
    final index = matches.indexWhere((match) => match.id == matchId);
    if (index < 0) return;
    final match = matches[index];
    _requireMatchHost(match);
    if (match.status == MatchStatus.completed) {
      throw StateError('Completed matches stay in history.');
    }
    _pendingSharedMatchDeletes.add(match.id);
    matches.removeAt(index);
    await _commit(waitForCloud: true);
  }

  Future<void> initialize() async {
    if (firebaseEnabled) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      await _ensureAnonymousSession();
    }

    final savedPlayerId = await _preferences.getString(_accountPlayerIdKey);
    final savedEmail = await _preferences.getString(_accountEmailKey);
    if (savedPlayerId != null && savedPlayerId.isNotEmpty) {
      activePlayerId = savedPlayerId;
      _accountEmail = savedEmail;
      _accountSignedIn = true;
      final raw = await _preferences.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          _replaceState(Map<String, dynamic>.from(jsonDecode(raw) as Map));
          activePlayerId = savedPlayerId;
        } on Object {
          _clearState();
          activePlayerId = savedPlayerId;
        }
      }
      if (firebaseUser != null) {
        await _bindCurrentSession(savedPlayerId);
        await _restoreCloudState(replaceLocal: players.isEmpty);
        await _refreshSharedMatches(migrateLegacy: true);
        await _refreshSocialGraph();
        await _persistLocal();
        await _syncActivePlayerPublicProfile();
      }
    } else {
      _clearState();
      _accountSignedIn = false;
    }
    _ensurePointPresets();
    initialized = true;
    notifyListeners();
  }

  Future<void> _ensureAnonymousSession() async {
    final auth = _auth;
    if (!firebaseEnabled || auth == null) return;
    final user = auth.currentUser;
    if (user == null) {
      await auth.signInAnonymously();
      return;
    }
    if (!user.isAnonymous) {
      await auth.signOut();
      await auth.signInAnonymously();
      return;
    }
    try {
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      const staleCodes = {
        'invalid-user-token',
        'user-disabled',
        'user-not-found',
        'user-token-expired',
      };
      if (!staleCodes.contains(error.code)) return;
      await auth.signOut();
      await auth.signInAnonymously();
    }
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  String _emailKey(String email) =>
      sha256.convert(utf8.encode(_normalizeEmail(email))).toString();

  String _newPasswordSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _passwordVerifier(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var round = 0; round < 12000; round++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  Future<void> _bindCurrentSession(String playerId) async {
    final user = firebaseUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;
    await firestore.collection('sessions').doc(user.uid).set({
      'playerId': playerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Player> _createAccountRecord({
    required String name,
    required String email,
    required String password,
    required BattingStyle battingStyle,
    required int avatarPreset,
    bool bindToCurrentSession = false,
  }) async {
    if (!firebaseEnabled || _firestore == null || firebaseUser == null) {
      throw StateError('Connect Firebase and enable Anonymous sign-in first.');
    }
    final cleanName = name.trim();
    final cleanEmail = _normalizeEmail(email);
    if (cleanName.length < 2) throw StateError('Enter the player name.');
    if (!cleanEmail.contains('@')) throw StateError('Enter a valid email.');
    if (password.length < 8) {
      throw StateError('Password must contain at least 8 characters.');
    }

    final firestore = _firestore!;
    final credentialRef = firestore.collection('loginCredentials').doc(
      _emailKey(cleanEmail),
    );
    final salt = _newPasswordSalt();
    final verifier = _passwordVerifier(password, salt);

    for (var attempt = 0; attempt < 15; attempt++) {
      final playerId = _ids.playerId();
      final playerRef = firestore.collection('players').doc(playerId);
      try {
        await firestore.runTransaction((transaction) async {
          final credential = await transaction.get(credentialRef);
          if (credential.exists) {
            throw StateError('An account already uses this email.');
          }
          final collision = await transaction.get(playerRef);
          if (collision.exists) throw _PlayerIdCollision();
          transaction.set(credentialRef, {
            'email': cleanEmail,
            'playerId': playerId,
            'passwordSalt': salt,
            'passwordVerifier': verifier,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(playerRef, {
            'playerId': playerId,
            'name': cleanName,
            'battingStyle': battingStyle.name,
            'bowlingStyles': <String>['Right-arm medium'],
            'avatarSource': AvatarSource.preset.name,
            'avatarPreset': avatarPreset,
            'avatarColor': _avatarColors[players.length % _avatarColors.length],
            'archived': false,
            'joinedAt': DateTime.now().toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        final player = Player(
          id: playerId,
          name: cleanName,
          battingStyle: battingStyle,
          avatarPreset: avatarPreset,
          avatarSource: AvatarSource.preset,
          avatarColor: _avatarColors[players.length % _avatarColors.length],
          createdAt: DateTime.now(),
        );
        if (bindToCurrentSession) await _bindCurrentSession(playerId);
        return player;
      } on _PlayerIdCollision {
        continue;
      }
    }
    throw StateError('Could not generate a unique Player ID. Try again.');
  }

  Future<void> registerAccount({
    required String name,
    required String email,
    required String password,
    required BattingStyle battingStyle,
    required int avatarPreset,
  }) async {
    await _ensureAnonymousSession();
    final player = await _createAccountRecord(
      name: name,
      email: email,
      password: password,
      battingStyle: battingStyle,
      avatarPreset: avatarPreset,
      bindToCurrentSession: true,
    );
    _clearState();
    _addOrReplacePlayer(player);
    activePlayerId = player.id;
    _accountEmail = _normalizeEmail(email);
    _accountSignedIn = true;
    await _preferences.setString(_accountPlayerIdKey, player.id);
    await _preferences.setString(_accountEmailKey, _accountEmail!);
    await _commit();
    await _refreshSocialGraph();
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _ensureAnonymousSession();
    final firestore = _firestore;
    if (!firebaseEnabled || firestore == null || firebaseUser == null) {
      throw StateError('Firebase is unavailable.');
    }
    final cleanEmail = _normalizeEmail(email);
    final credential = await firestore
        .collection('loginCredentials')
        .doc(_emailKey(cleanEmail))
        .get();
    final data = credential.data();
    if (data == null) throw StateError('Email or password is incorrect.');
    final salt = data['passwordSalt']?.toString();
    final expected = data['passwordVerifier']?.toString();
    final playerId = data['playerId']?.toString();
    if (salt == null || expected == null || playerId == null ||
        _passwordVerifier(password, salt) != expected) {
      throw StateError('Email or password is incorrect.');
    }

    _clearState();
    activePlayerId = playerId;
    _accountEmail = cleanEmail;
    _accountSignedIn = true;
    await _bindCurrentSession(playerId);
    await _preferences.setString(_accountPlayerIdKey, playerId);
    await _preferences.setString(_accountEmailKey, cleanEmail);
    await _restoreCloudState(replaceLocal: true);
    if (activePlayer == null) {
      final player = await findPublicPlayer(playerId, bypassSignedInGate: true);
      if (player == null) throw StateError('Player profile is missing.');
      _addOrReplacePlayer(player);
      activePlayerId = playerId;
    }
    await _refreshSharedMatches(migrateLegacy: true);
    await _persistLocal();
    await _syncActivePlayerPublicProfile();
    await _refreshSocialGraph();
    notifyListeners();
  }

  Future<CreatedPlayer> registerManagedPlayerAccount({
    required String name,
    required String email,
    required String password,
    required BattingStyle battingStyle,
    required int avatarPreset,
  }) async {
    final player = await _createAccountRecord(
      name: name,
      email: email,
      password: password,
      battingStyle: battingStyle,
      avatarPreset: avatarPreset,
    );
    final loginEmail = _normalizeEmail(email);
    _addOrReplacePlayer(player);
    await _commit();
    return CreatedPlayer(player: player, loginEmail: loginEmail);
  }

  Future<void> changeAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _accountEmail;
    final firestore = _firestore;
    if (email == null || firestore == null || activePlayerId == null) {
      throw StateError('Sign in first.');
    }
    if (newPassword.length < 8) {
      throw StateError('New password must contain at least 8 characters.');
    }
    final ref = firestore.collection('loginCredentials').doc(_emailKey(email));
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null || data['playerId']?.toString() != activePlayerId) {
      throw StateError('Account credentials are missing.');
    }
    final salt = data['passwordSalt']?.toString() ?? '';
    if (_passwordVerifier(currentPassword, salt) !=
        data['passwordVerifier']?.toString()) {
      throw StateError('Current password is incorrect.');
    }
    final newSalt = _newPasswordSalt();
    await ref.update({
      'passwordSalt': newSalt,
      'passwordVerifier': _passwordVerifier(newPassword, newSalt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOutCloud() async {
    // Finish already queued host updates before removing the anonymous session.
    // This prevents a quick Sign out immediately after scoring from dropping
    // the last shared-match snapshot.
    await _cloudSyncTail;
    final uid = firebaseUser?.uid;
    if (uid != null && _firestore != null) {
      try {
        await _firestore!.collection('sessions').doc(uid).delete();
      } on FirebaseException {
        // Local sign-out still proceeds.
      }
    }
    _accountSignedIn = false;
    _accountEmail = null;
    _clearState();
    await _preferences.remove(_accountPlayerIdKey);
    await _preferences.remove(_accountEmailKey);
    await _preferences.remove(_storageKey);
    notifyListeners();
  }

  Future<void> deleteMyAccount() async {
    final player = activePlayer;
    final email = _accountEmail;
    final firestore = _firestore;
    if (player == null || email == null || firestore == null) {
      await signOutCloud();
      return;
    }
    final batch = firestore.batch();
    for (final match in matches.where(
      (value) =>
          value.creatorPlayerId == player.id &&
          value.status != MatchStatus.completed,
    )) {
      batch.delete(firestore.collection('matches').doc(match.id));
    }
    batch.delete(firestore.collection('loginCredentials').doc(_emailKey(email)));
    batch.delete(firestore.collection('accountStates').doc(player.id));
    batch.delete(firestore.collection('players').doc(player.id));
    final uid = firebaseUser?.uid;
    if (uid != null) batch.delete(firestore.collection('sessions').doc(uid));
    await batch.commit();
    await signOutCloud();
  }

  Future<void> refreshSocialGraph() => _refreshSocialGraph();

  Future<void> refreshMatchHistory() async {
    await _refreshSharedMatches(migrateLegacy: true);
    await _persistLocal();
    await _syncActivePlayerPublicProfile();
    notifyListeners();
  }

  Future<void> refreshMatches() => refreshMatchHistory();

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

  void _requireMatchHost(CricketMatch match) {
    if (!canControlMatch(match)) {
      throw StateError(
        'This match is controlled by ${match.creatorPlayerId}. You can watch it, but only the host can change the score or match setup.',
      );
    }
  }

  Future<void> savePlayerProfile(Player player) async {
    if (playerById(player.id) == null) throw StateError('Player not found.');
    if (player.id != activePlayerId) {
      throw StateError('Only that player can edit this registered account.');
    }
    if (player.name.trim().length < 2) {
      throw StateError('Player name must contain at least two characters.');
    }
    player.name = player.name.trim();
    player.instagramHandle = _cleanInstagram(player.instagramHandle);
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
    await _commit();
  }

  Future<bool> deleteCachedPlayer(String playerId) async {
    final player = playerById(playerId);
    if (player == null) return false;
    if (playerId == activePlayerId) {
      throw StateError('Use Delete account for your own account.');
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
    }
    await _commit();
    return !isReferenced;
  }

  Future<void> resetActivePlayerData() async {
    final player = activePlayer;
    if (player == null) return;
    // Completed shared matches are permanent participant history. Reset only
    // unfinished local match state and cached social data. If this player hosts
    // an unfinished match, queue a canonical shared delete so participants do
    // not keep a ghost Watch card. Foreign matches are cleared only locally.
    _pendingSharedMatchDeletes.addAll(
      matches
          .where(
            (match) =>
                match.creatorPlayerId == player.id &&
                match.status != MatchStatus.completed,
          )
          .map((match) => match.id),
    );
    matches.removeWhere(
      (match) =>
          match.participantIds.contains(player.id) &&
          match.status != MatchStatus.completed,
    );
    for (final cached in players) {
      cached.friendIds.remove(player.id);
    }
    player.friendIds.clear();
    PlayerHistory.copyStats(
      player.stats,
      PlayerHistory.calculateSinglesCareer(player.id, matches),
    );
    _clearStats(player.teamStats);
    friendRequests.removeWhere(
      (request) =>
          request.fromPlayerId == player.id || request.toPlayerId == player.id,
    );
    notifications.removeWhere((value) => value.playerId == player.id);
    await _commit();
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

  Future<Player?> findPublicPlayer(
    String playerId, {
    bool bypassSignedInGate = false,
  }) async {
    final normalized = playerId.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(normalized)) return null;
    final cached = playerById(normalized);
    if (cached != null) return cached;
    final firestore = _firestore;
    if ((!cloudConnected && !bypassSignedInGate) || firestore == null) return null;
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
    if (!RegExp(r'^\d{8}$').hasMatch(normalized)) return null;
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
      throw StateError(
        existing.fromPlayerId == player.id
            ? 'Friend request already sent.'
            : 'This player has already sent you a request.',
      );
    }
    final firestore = _firestore;
    if (!cloudConnected || firestore == null) {
      throw StateError('Connect to the internet and sign in first.');
    }

    final requestId = _friendPairKey(player.id, friendId);
    final requestRef = firestore.collection('friendRequests').doc(requestId);
    final friendRef = firestore
        .collection('players')
        .doc(player.id)
        .collection('friends')
        .doc(friendId);
    final notificationRef = firestore
        .collection('notifications')
        .doc('request_$requestId');
    await firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final friendshipSnapshot = await transaction.get(friendRef);
      if (friendshipSnapshot.exists) {
        throw StateError('This player is already your friend.');
      }
      if (requestSnapshot.exists &&
          requestSnapshot.data()?['status'] == 'pending') {
        throw StateError('A friend request is already pending.');
      }
      transaction.set(requestRef, {
        'fromPlayerId': player.id,
        'toPlayerId': friendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        'recipientPlayerId': friendId,
        'fromPlayerId': player.id,
        'type': 'friendRequest',
        'requestId': requestId,
        'actionStatus': 'pending',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

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
    final receiver = activePlayer;
    if (receiver == null || request.toPlayerId != receiver.id) {
      throw StateError('Only the receiving player can respond.');
    }
    final firestore = _firestore;
    if (!cloudConnected || firestore == null) {
      throw StateError('Connect to the internet and refresh first.');
    }

    final requestRef = firestore.collection('friendRequests').doc(requestId);
    final incomingNotification = firestore
        .collection('notifications')
        .doc('request_$requestId');
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestRef);
      final data = snapshot.data();
      if (!snapshot.exists || data?['status'] != 'pending') {
        throw StateError('Pending request not found.');
      }
      if (data?['toPlayerId']?.toString() != receiver.id) {
        throw StateError('Only the receiving player can respond.');
      }
      transaction.delete(requestRef);
      transaction.set(
        incomingNotification,
        {
          'actionStatus': accept ? 'accepted' : 'rejected',
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (accept) {
        transaction.set(
          firestore
              .collection('players')
              .doc(request.fromPlayerId)
              .collection('friends')
              .doc(request.toPlayerId),
          {
            'playerId': request.toPlayerId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        transaction.set(
          firestore
              .collection('players')
              .doc(request.toPlayerId)
              .collection('friends')
              .doc(request.fromPlayerId),
          {
            'playerId': request.fromPlayerId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        transaction.set(
          firestore.collection('notifications').doc('accepted_$requestId'),
          {
            'recipientPlayerId': request.fromPlayerId,
            'fromPlayerId': request.toPlayerId,
            'type': 'friendAccepted',
            'requestId': requestId,
            'actionStatus': 'accepted',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
    });

    friendRequests.removeWhere((value) => value.id == requestId);
    for (final item in notifications) {
      if (item.referenceId == requestId && item.playerId == receiver.id) {
        item
          ..read = true
          ..actionStatus = accept ? 'accepted' : 'rejected';
      }
    }
    if (accept) {
      final sender = await findPublicPlayer(request.fromPlayerId);
      if (sender != null) {
        if (!sender.friendIds.contains(receiver.id)) sender.friendIds.add(receiver.id);
        if (!receiver.friendIds.contains(sender.id)) receiver.friendIds.add(sender.id);
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
      final batch = firestore.batch();
      batch.delete(
        firestore.collection('players').doc(player.id).collection('friends').doc(friendPlayerId),
      );
      batch.delete(
        firestore.collection('players').doc(friendPlayerId).collection('friends').doc(player.id),
      );
      await batch.commit();
    }
    player.friendIds.remove(friendPlayerId);
    playerById(friendPlayerId)?.friendIds.remove(player.id);
    await _persistLocal();
    notifyListeners();
  }

  Future<void> setNotificationRead(String notificationId, bool read) async {
    for (final value in notifications) {
      if (value.id == notificationId && value.playerId == activePlayerId) {
        value.read = read;
      }
    }
    final firestore = _firestore;
    if (cloudConnected && firestore != null) {
      await firestore.collection('notifications').doc(notificationId).update({
        'read': read,
        'readAt': read ? FieldValue.serverTimestamp() : null,
      });
    }
    await _persistLocal();
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) =>
      setNotificationRead(notificationId, true);

  Future<void> markNotificationUnread(String notificationId) =>
      setNotificationRead(notificationId, false);

  Future<void> deleteNotification(String notificationId) async {
    CricNotification? target;
    for (final value in notifications) {
      if (value.id == notificationId && value.playerId == activePlayerId) {
        target = value;
        break;
      }
    }
    if (target == null) return;
    final item = target;

    if (item.type == NotificationType.friendRequest &&
        item.actionStatus == 'pending' &&
        item.referenceId != null) {
      final requestId = item.referenceId!;
      final pending = friendRequests.any(
        (request) =>
            request.id == requestId &&
            request.toPlayerId == activePlayerId &&
            request.status == FriendRequestStatus.pending,
      );
      if (pending) {
        await respondToFriendRequest(requestId, accept: false);
      }
    }

    notifications.removeWhere(
      (value) => value.id == notificationId && value.playerId == activePlayerId,
    );
    final firestore = _firestore;
    if (cloudConnected && firestore != null) {
      try {
        await firestore.collection('notifications').doc(notificationId).delete();
      } on FirebaseException {
        // Local deletion still keeps the UI responsive.
      }
    }
    await _persistLocal();
    notifyListeners();
  }

  Future<void> deleteAllNotifications() async {
    final playerId = activePlayerId;
    if (playerId == null) return;
    final items = activeNotifications.toList(growable: false);
    if (items.isEmpty) return;

    for (final item in items) {
      if (item.type != NotificationType.friendRequest ||
          item.actionStatus != 'pending' ||
          item.referenceId == null) {
        continue;
      }
      final requestId = item.referenceId!;
      final pending = friendRequests.any(
        (request) =>
            request.id == requestId &&
            request.toPlayerId == playerId &&
            request.status == FriendRequestStatus.pending,
      );
      if (pending) {
        await respondToFriendRequest(requestId, accept: false);
      }
    }

    final ids = items.map((item) => item.id).toSet();
    notifications.removeWhere(
      (value) => value.playerId == playerId && ids.contains(value.id),
    );
    final firestore = _firestore;
    if (cloudConnected && firestore != null) {
      final refs = ids
          .map((id) => firestore.collection('notifications').doc(id))
          .toList(growable: false);
      for (var start = 0; start < refs.length; start += 400) {
        final batch = firestore.batch();
        final end = min(start + 400, refs.length);
        for (final ref in refs.sublist(start, end)) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    }
    await _persistLocal();
    notifyListeners();
  }


  void _ensurePointPresets() {
    if (!pointPresets.any((preset) => preset.id == 'balanced')) {
      pointPresets.insert(
        0,
        const PointPreset(
          id: 'balanced',
          name: 'Balanced',
          rules: PointRules(),
          builtIn: true,
        ),
      );
    }
    if (!pointPresets.any((preset) => preset.id == defaultPointPresetId)) {
      defaultPointPresetId = 'balanced';
    }
  }

  Future<PointPreset> savePointPreset({
    required String name,
    required PointRules rules,
    bool makeDefault = false,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw StateError('Enter a preset name.');
    }
    final existingIndex = pointPresets.indexWhere(
      (preset) => preset.name.toLowerCase() == cleanName.toLowerCase(),
    );
    final preset = PointPreset(
      id: existingIndex >= 0 && !pointPresets[existingIndex].builtIn
          ? pointPresets[existingIndex].id
          : 'preset_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      rules: rules,
    );
    if (existingIndex >= 0 && !pointPresets[existingIndex].builtIn) {
      pointPresets[existingIndex] = preset;
    } else {
      pointPresets.add(preset);
    }
    if (makeDefault) defaultPointPresetId = preset.id;
    await _commit();
    return preset;
  }

  Future<void> setDefaultPointPreset(String presetId) async {
    if (!pointPresets.any((preset) => preset.id == presetId)) {
      throw StateError('Point preset not found.');
    }
    defaultPointPresetId = presetId;
    await _commit();
  }

  Future<void> deletePointPreset(String presetId) async {
    final index = pointPresets.indexWhere((value) => value.id == presetId);
    if (index < 0 || pointPresets[index].builtIn) return;
    pointPresets.removeAt(index);
    if (defaultPointPresetId == presetId) defaultPointPresetId = 'balanced';
    await _commit();
  }

  Future<CricketMatch> createMatch({
    required String title,
    required ScoringMode scoringMode,
    required int ballLimit,
    required List<String> participantIds,
    required MatchWinnerMetric winnerMetric,
    String? trackerPlayerId,
    PointRules? pointRules,
    String? pointPresetName,
    bool autoBowlingPlan = true,
  }) async {
    final creator = activePlayer;
    if (creator == null) throw StateError('Create a player profile first.');
    final uniqueParticipants = participantIds.toSet().toList();
    if (uniqueParticipants.length < 2) {
      throw StateError('A singles match needs at least two players.');
    }
    if (ballLimit < 1) throw StateError('Over limit must be at least one ball.');
    if (uniqueParticipants.any((id) => playerById(id) == null)) {
      throw StateError('Every participant needs a valid Player ID.');
    }
    if (trackerPlayerId != null &&
        !uniqueParticipants.contains(trackerPlayerId)) {
      throw StateError('The selected tracker must be in this match.');
    }
    final selectedPreset = defaultPointPreset;
    final match = CricketMatch(
      id: _uniqueMatchId(),
      title: title.trim().isEmpty ? suggestMatchTitle() : title.trim(),
      creatorPlayerId: creator.id,
      scoringMode: scoringMode,
      ballLimit: ballLimit,
      participantIds: uniqueParticipants,
      createdAt: DateTime.now(),
      status: MatchStatus.drawing,
      winnerMetric: winnerMetric,
      trackerPlayerId: trackerPlayerId,
      pointRules: pointRules ?? selectedPreset.rules,
      pointPresetName: pointPresetName ?? selectedPreset.name,
      autoBowlingPlan: autoBowlingPlan,
    );
    _createDrawPool(match);
    match.auditTrail.add(
      MatchAuditEntry(type: 'created', createdAt: match.createdAt),
    );
    matches.add(match);
    await _commit(waitForCloud: true);
    return match;
  }

  Future<CricketMatch> createRankRematch(String sourceMatchId) async {
    final source = matchById(sourceMatchId);
    if (source == null || source.status != MatchStatus.completed) {
      throw StateError('Complete the source match first.');
    }
    final rankings = ScoringEngine.rankings(source);
    final order = rankings.map((value) => value.playerId).toList();
    if (order.length < 2) throw StateError('Not enough ranked players.');
    final creator = activePlayer;
    if (creator == null) throw StateError('Sign in first.');
    final match = CricketMatch(
      id: _uniqueMatchId(),
      title: suggestMatchTitle(),
      creatorPlayerId: creator.id,
      scoringMode: source.scoringMode,
      ballLimit: source.ballLimit,
      participantIds: List<String>.from(order),
      battingOrder: List<String>.from(order),
      createdAt: DateTime.now(),
      status: MatchStatus.drawing,
      winnerMetric: source.winnerMetric,
      trackerPlayerId: source.trackerPlayerId,
      pointRules: source.pointRules,
      pointPresetName: source.pointPresetName,
      autoBowlingPlan: source.autoBowlingPlan,
      orderSource: BattingOrderSource.previousRanking,
    );
    _seedOrderAssignments(match, order);
    if (match.autoBowlingPlan) {
      match.bowlingPlan
        ..clear()
        ..addAll(
          BowlingScheduler.generate(
            battingOrder: match.battingOrder,
            participantIds: match.participantIds,
            ballLimit: match.ballLimit,
          ),
        );
    }
    match.auditTrail.add(
      MatchAuditEntry(
        type: 'rank_rematch_created',
        createdAt: match.createdAt,
        note: source.id,
      ),
    );
    matches.add(match);
    await _commit(waitForCloud: true);
    return match;
  }

  List<DrawCard> availableDrawCards(CricketMatch match) {
    final used = match.drawAssignments.values
        .map((value) => value.card.id)
        .toSet();
    return match.drawPool.where((card) => !used.contains(card.id)).toList();
  }

  String? nextDrawPlayerId(CricketMatch match) {
    final order = match.drawPlayerOrder.isEmpty
        ? match.participantIds
        : match.drawPlayerOrder;
    for (final playerId in order) {
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
    _requireMatchHost(match);
    if (nextDrawPlayerId(match) != playerId) {
      throw StateError('It is another player’s turn to draw.');
    }
    final card = availableDrawCards(match).firstWhere(
      (value) => value.id == cardId,
      orElse: () => throw StateError('That card has already been selected.'),
    );
    final assignment = DrawAssignment(playerId: playerId, card: card);
    match.drawAssignments[playerId] = assignment;

    final remainingPlayers = match.drawPlayerOrder
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
    _requireMatchHost(match);
    match.drawAssignments.clear();
    match.battingOrder.clear();
    match.orderSource = BattingOrderSource.secretDraw;
    match.bowlingPlan.clear();
    _createDrawPool(match);
    match.auditTrail.add(
      MatchAuditEntry(type: 'draw_reset', createdAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> startMatch(String matchId) async {
    final match = matchById(matchId);
    if (match == null ||
        match.status != MatchStatus.drawing ||
        match.battingOrder.length != match.participantIds.length) {
      throw StateError('Complete or confirm the batting order first.');
    }
    _requireMatchHost(match);
    if (match.autoBowlingPlan && match.bowlingPlan.isEmpty) {
      match.bowlingPlan.addAll(
        BowlingScheduler.generate(
          battingOrder: match.battingOrder,
          participantIds: match.participantIds,
          ballLimit: match.ballLimit,
        ),
      );
    }
    match.status = MatchStatus.live;
    match.startedAt = DateTime.now();
    match.auditTrail.add(
      MatchAuditEntry(type: 'started', createdAt: match.startedAt!),
    );
    await _commit(waitForCloud: true);
  }

  Future<void> setBattingOrder(String matchId, List<String> order) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.drawing) {
      throw StateError('Use remaining-order controls after the match starts.');
    }
    _requireMatchHost(match);
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
    if (match.autoBowlingPlan) {
      match.bowlingPlan
        ..clear()
        ..addAll(
          BowlingScheduler.generate(
            battingOrder: match.battingOrder,
            participantIds: match.participantIds,
            ballLimit: match.ballLimit,
          ),
        );
    }
    match.auditTrail.add(
      MatchAuditEntry(type: 'order_adjusted', createdAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> setAutoBowlingPlan(String matchId, bool enabled) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.drawing) return;
    _requireMatchHost(match);
    match.autoBowlingPlan = enabled;
    match.bowlingPlan.clear();
    if (enabled && match.battingOrder.isNotEmpty) {
      match.bowlingPlan.addAll(
        BowlingScheduler.generate(
          battingOrder: match.battingOrder,
          participantIds: match.participantIds,
          ballLimit: match.ballLimit,
        ),
      );
    }
    await _commit();
  }

  Future<void> regenerateBowlingPlan(String matchId) async {
    final match = matchById(matchId);
    if (match == null || match.battingOrder.isEmpty) return;
    _requireMatchHost(match);
    if (match.status == MatchStatus.live) {
      _regenerateFutureBowlingPlan(match);
    } else {
      match.bowlingPlan
        ..clear()
        ..addAll(
          BowlingScheduler.generate(
            battingOrder: match.battingOrder,
            participantIds: match.participantIds,
            ballLimit: match.ballLimit,
          ),
        );
    }
    match.auditTrail.add(
      MatchAuditEntry(type: 'bowling_plan_regenerated', createdAt: DateTime.now()),
    );
    await _commit();
  }

  List<String> remainingReorderablePlayerIds(CricketMatch match) {
    final states = ScoringEngine.rebuildTurns(match);
    final current = ScoringEngine.currentBatterId(match);
    return match.battingOrder.where((id) {
      if (id == current) return false;
      return !(states[id]?.isComplete(match.ballLimit) ?? false);
    }).toList();
  }

  Future<void> reorderRemainingPlayers(
    String matchId,
    List<String> remainingOrder,
  ) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    _requireMatchHost(match);
    final allowed = remainingReorderablePlayerIds(match);
    if (remainingOrder.length != allowed.length ||
        remainingOrder.toSet().length != allowed.length ||
        !remainingOrder.toSet().containsAll(allowed)) {
      throw StateError('Only unplayed players can be reordered.');
    }
    final allowedSet = allowed.toSet();
    var next = 0;
    for (var index = 0; index < match.battingOrder.length; index++) {
      if (allowedSet.contains(match.battingOrder[index])) {
        match.battingOrder[index] = remainingOrder[next++];
      }
    }
    _regenerateFutureBowlingPlan(match);
    match.auditTrail.add(
      MatchAuditEntry(type: 'live_order_changed', createdAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> addPlayerToLiveMatch(String matchId, String playerId) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    _requireMatchHost(match);
    if (playerById(playerId) == null) throw StateError('Player not found.');
    if (match.participantIds.contains(playerId)) {
      throw StateError('That player is already in this match.');
    }
    match.participantIds.add(playerId);
    match.battingOrder.add(playerId);
    _regenerateFutureBowlingPlan(match);
    match.auditTrail.add(
      MatchAuditEntry(
        type: 'player_added_live',
        playerId: playerId,
        createdAt: DateTime.now(),
      ),
    );
    await _commit(waitForCloud: true);
  }

  Future<void> moveCurrentBatterToEnd(String matchId) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    _requireMatchHost(match);
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
    _regenerateFutureBowlingPlan(match);
    match.auditTrail.add(
      MatchAuditEntry(
        type: 'current_batter_moved',
        playerId: current,
        createdAt: DateTime.now(),
      ),
    );
    await _commit();
  }

  Future<void> replaceCurrentBowler(
    String matchId, {
    required String newBowlerId,
    String reason = 'Replacement / injury',
    bool alsoNextBlock = false,
  }) async {
    final match = matchById(matchId);
    if (match == null || match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    _requireMatchHost(match);
    final batterId = ScoringEngine.currentBatterId(match);
    if (batterId == null) throw StateError('No active batter.');
    if (newBowlerId == batterId || !match.participantIds.contains(newBowlerId)) {
      throw StateError('Choose another player as bowler.');
    }
    final turn = ScoringEngine.rebuildTurns(match)[batterId]!;
    final block = BowlingScheduler.blockFor(match, batterId, turn.legalBalls);
    if (block == null) throw StateError('No bowling block is active.');
    final oldBowler = block.bowlerId;
    if (oldBowler == newBowlerId) return;
    block.bowlerId = newBowlerId;
    if (alsoNextBlock) {
      final blocks = BowlingScheduler.blocksForBatter(match, batterId);
      final nextIndex = blocks.indexWhere(
        (value) => value.blockIndex == block.blockIndex + 1,
      );
      if (nextIndex >= 0 && newBowlerId != batterId) {
        blocks[nextIndex].bowlerId = newBowlerId;
      }
    }
    match.bowlerChanges.add(
      BowlerChange(
        batterId: batterId,
        legalBallNumber: turn.legalBalls,
        fromBowlerId: oldBowler,
        toBowlerId: newBowlerId,
        createdAt: DateTime.now(),
        reason: reason,
        alsoNextBlock: alsoNextBlock,
      ),
    );
    match.auditTrail.add(
      MatchAuditEntry(
        type: 'bowler_replaced',
        playerId: newBowlerId,
        createdAt: DateTime.now(),
        note: '$oldBowler->$newBowlerId at ball ${turn.legalBalls + 1}',
      ),
    );
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
    _requireMatchHost(match);
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
    if (match.status == MatchStatus.completed && match.completedAt == null) {
      match.completedAt = DateTime.now();
      match.auditTrail.add(
        MatchAuditEntry(type: 'completed', createdAt: match.completedAt!),
      );
    }
    _applyStatsIfComplete(match);
    await _commit(waitForCloud: match.status == MatchStatus.completed);
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
    _requireMatchHost(match);
    ScoringEngine.recordQuickTotal(
      match,
      eventId: _ids.eventId(),
      runs: runs,
      isOut: isOut,
      dismissalType: dismissalType,
      bowlerId: bowlerId,
      fielderIds: fielderIds,
    );
    if (match.status == MatchStatus.completed && match.completedAt == null) {
      match.completedAt = DateTime.now();
      match.auditTrail.add(
        MatchAuditEntry(type: 'completed', createdAt: match.completedAt!),
      );
    }
    _applyStatsIfComplete(match);
    await _commit(waitForCloud: match.status == MatchStatus.completed);
  }

  Future<bool> undoLast(String matchId) async {
    final match = matchById(matchId);
    if (match == null) return false;
    _requireMatchHost(match);
    if (match.statsApplied) _revertAppliedStats(match);
    final changed = ScoringEngine.undoLast(match);
    if (changed && match.status != MatchStatus.completed) {
      match.completedAt = null;
    }
    await _commit();
    return changed;
  }

  Future<int> resetCurrentTurn(String matchId) async {
    final match = matchById(matchId);
    if (match == null) return 0;
    _requireMatchHost(match);
    final changed = ScoringEngine.resetCurrentTurn(match);
    await _commit();
    return changed;
  }

  Future<void> _commit({bool waitForCloud = false}) async {
    final data = _stateData();
    await _persistLocal(data);
    final cloudSync = _queueCloudSync(data);
    if (waitForCloud && cloudConnected) {
      await cloudSync;
    } else {
      unawaited(cloudSync);
    }
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
    'pointPresets': pointPresets.map((value) => value.toJson()).toList(),
    'defaultPointPresetId': defaultPointPresetId,
    'pendingSharedMatchDeletes': _pendingSharedMatchDeletes.toList(),
    'schemaVersion': 8,
  };

  void _replaceState(Map<String, dynamic> json) {
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
    pointPresets.addAll(
      (json['pointPresets'] as List? ?? const []).map(
        (value) => PointPreset.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      ),
    );
    defaultPointPresetId =
        json['defaultPointPresetId'] as String? ?? 'balanced';
    _pendingSharedMatchDeletes
      ..clear()
      ..addAll(
        List<String>.from(
          json['pendingSharedMatchDeletes'] as List? ?? const <String>[],
        ),
      );
    _ensurePointPresets();
  }

  void _clearState() {
    players.clear();
    _playerIndex.clear();
    gangs.clear();
    matches.clear();
    friendRequests.clear();
    notifications.clear();
    pointPresets.clear();
    _sharedMatchIds.clear();
    _pendingSharedMatchDeletes.clear();
    _lastSharedMatchPayloads.clear();
    _lastPublicProfileFingerprint = null;
    _pendingCloudState = null;
    defaultPointPresetId = 'balanced';
    activePlayerId = null;
  }

  Future<void> _queueCloudSync(Map<String, Object?> state) {
    // Keep only the newest not-yet-sent snapshot while a network write is in
    // flight. Every match snapshot contains the full event history, so this
    // safely coalesces rapid taps without letting cloud writes lag dozens of
    // balls behind the host.
    _pendingCloudState = state;
    if (_cloudSyncRunning) return _cloudSyncTail;

    _cloudSyncRunning = true;
    _cloudSyncTail = () async {
      try {
        while (_pendingCloudState != null) {
          final next = _pendingCloudState!;
          _pendingCloudState = null;
          try {
            await _syncCloudState(next);
          } on Object {
            // A later commit/refresh retries from the local source of truth.
          }
        }
      } finally {
        _cloudSyncRunning = false;
      }
    }();
    return _cloudSyncTail;
  }

  Future<void> _syncCloudState(Map<String, Object?> state) async {
    final firestore = _firestore;
    final player = activePlayer;
    if (!cloudConnected || firestore == null || player == null) return;

    // Keep private account/device state independent from the shared match
    // channel. Completed/foreign match history is canonical in `matches`, so
    // do not duplicate an ever-growing event archive inside accountStates.
    final cloudState = Map<String, Object?>.from(state);
    cloudState['matches'] = matches
        .where(
          (match) =>
              match.creatorPlayerId == player.id &&
              match.status != MatchStatus.completed,
        )
        .map((match) => match.toJson())
        .toList();
    try {
      await firestore.collection('accountStates').doc(player.id).set({
        'state': jsonEncode(cloudState),
        'schemaVersion': 8,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Local state remains the immediate source while offline.
    }

    await _flushPendingSharedMatchDeletes();
    await _syncOwnedMatchesToShared();
    await _syncActivePlayerPublicProfile();
  }

  Future<void> _syncActivePlayerPublicProfile() async {
    final firestore = _firestore;
    final player = activePlayer;
    if (!cloudConnected || firestore == null || player == null) return;
    final fingerprint = jsonEncode(player.toJson());
    if (_lastPublicProfileFingerprint == fingerprint) return;
    try {
      final playerRef = firestore.collection('players').doc(player.id);
      await playerRef.set({
        ...player.toPublicJson(),
        'playerId': player.id,
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
            'ownerPlayerId': player.id,
            'value': value,
            'visibility':
                (player.contactVisibility[field] ?? ProfileVisibility.onlyMe).name,
            'audienceIds': player.contactAudienceIds[field] ?? const [],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      _lastPublicProfileFingerprint = fingerprint;
    } on FirebaseException {
      // Public profile sync can retry on the next app change.
    }
  }

  Map<String, Object?> _watchSafeMatchJson(CricketMatch match) {
    final json = Map<String, Object?>.from(match.toJson());
    // Secret-draw card identities/assignments are host-device data. They are
    // never needed by participant Watch or completed History and must not be
    // exposed in the participant-readable shared document.
    json['drawPool'] = const <Object?>[];
    json['drawAssignments'] = const <String, Object?>{};
    return json;
  }

  String _watchSafeMatchPayload(CricketMatch match) =>
      jsonEncode(_watchSafeMatchJson(match));

  Map<String, Object?> _participantSnapshot(Player player) => {
    'id': player.id,
    'name': player.name,
    'avatarColor': player.avatarColor,
    'avatarSource': player.avatarSource.name,
    'avatarPreset': player.avatarPreset,
    'avatarUrl': player.avatarUrl,
    'battingStyle': player.battingStyle.name,
    'bowlingStyles': List<String>.from(player.bowlingStyles),
    'customBowlingStyle': player.customBowlingStyle,
    'createdAt': player.createdAt.toIso8601String(),
    'stats': player.stats.toJson(),
    'teamStats': player.teamStats.toJson(),
  };

  Map<String, Object?> _participantSnapshots(CricketMatch match) {
    final snapshots = <String, Object?>{};
    for (final participantId in match.participantIds) {
      final player = playerById(participantId);
      if (player != null) {
        snapshots[participantId] = _participantSnapshot(player);
      }
    }
    return snapshots;
  }

  void _hydrateParticipantSnapshots(Map<String, dynamic> data) {
    final raw = data['participantProfiles'];
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final playerId = entry.key.toString();
      if (playerById(playerId) != null || entry.value is! Map) continue;
      try {
        final snapshot = Map<String, dynamic>.from(entry.value as Map);
        snapshot['id'] = playerId;
        snapshot['createdAt'] ??= DateTime.now().toIso8601String();
        _addOrReplacePlayer(Player.fromJson(snapshot));
      } on Object {
        // A bad historical snapshot must not block the match itself.
      }
    }
  }

  Map<String, dynamic> _sharedMatchDocument(CricketMatch match) => {
    'matchId': match.id,
    'creatorPlayerId': match.creatorPlayerId,
    'participantIds': List<String>.from(match.participantIds),
    'participantProfiles': _participantSnapshots(match),
    'status': match.status.name,
    'title': match.title,
    'createdAt': Timestamp.fromDate(match.createdAt),
    'startedAt': match.startedAt == null
        ? null
        : Timestamp.fromDate(match.startedAt!),
    'completedAt': match.completedAt == null
        ? null
        : Timestamp.fromDate(match.completedAt!),
    'eventCount': match.events.length,
    'auditCount': match.auditTrail.length,
    'matchJson': _watchSafeMatchPayload(match),
    'schemaVersion': 2,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  CricketMatch? _matchFromSharedDocument(Map<String, dynamic> data) {
    try {
      final raw = data['matchJson'];
      if (raw is String && raw.isNotEmpty) {
        return CricketMatch.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
      final payload = data['match'];
      if (payload is Map) {
        return CricketMatch.fromJson(Map<String, dynamic>.from(payload));
      }
    } on Object {
      return null;
    }
    return null;
  }

  int _matchProgressScore(CricketMatch match) {
    final statusRank = switch (match.status) {
      MatchStatus.draft => 0,
      MatchStatus.drawing => 1,
      MatchStatus.live => 2,
      MatchStatus.completed => 3,
    };
    return statusRank * 1000000000 +
        match.events.length * 1000000 +
        match.auditTrail.length * 1000 +
        match.drawAssignments.length * 10 +
        match.participantIds.length;
  }

  Future<void> _syncOwnedMatchesToShared() async {
    final firestore = _firestore;
    final playerId = activePlayerId;
    if (!cloudConnected || firestore == null || playerId == null) return;

    final owned = matches.where(
      (match) =>
          match.creatorPlayerId == playerId &&
          !_pendingSharedMatchDeletes.contains(match.id),
    );
    for (final match in owned) {
      final payload = _watchSafeMatchPayload(match);
      if (_sharedMatchIds.contains(match.id) &&
          _lastSharedMatchPayloads[match.id] == payload) {
        continue;
      }
      try {
        await firestore
            .collection('matches')
            .doc(match.id)
            .set(_sharedMatchDocument(match), SetOptions(merge: true));
        _sharedMatchIds.add(match.id);
        _lastSharedMatchPayloads[match.id] = payload;
      } on FirebaseException {
        // Retry in order on a later commit/refresh.
      }
    }
  }

  Future<bool> _deleteSharedMatchRecord(String matchId) async {
    final firestore = _firestore;
    if (!cloudConnected || firestore == null) return false;
    try {
      await firestore.collection('matches').doc(matchId).delete();
      _sharedMatchIds.remove(matchId);
      _lastSharedMatchPayloads.remove(matchId);
      _pendingSharedMatchDeletes.remove(matchId);
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<void> _flushPendingSharedMatchDeletes() async {
    if (_pendingSharedMatchDeletes.isEmpty) return;
    for (final matchId in _pendingSharedMatchDeletes.toList()) {
      await _deleteSharedMatchRecord(matchId);
    }
  }

  Future<void> _cacheParticipantProfiles(CricketMatch match) async {
    for (final participantId in match.participantIds) {
      if (playerById(participantId) == null) {
        await findPublicPlayer(participantId, bypassSignedInGate: true);
      }
    }
  }

  Future<void> _ingestSharedMatch(
    CricketMatch remote, {
    bool preserveOwnedWhenAhead = true,
  }) async {
    final playerId = activePlayerId;
    if (playerId == null || !remote.participantIds.contains(playerId)) return;

    final localIndex = matches.indexWhere((value) => value.id == remote.id);
    if (localIndex < 0) {
      matches.add(remote);
    } else {
      final local = matches[localIndex];
      final ownedHere = local.creatorPlayerId == playerId;
      final keepLocal = ownedHere &&
          preserveOwnedWhenAhead &&
          _matchProgressScore(local) > _matchProgressScore(remote);
      if (!keepLocal) matches[localIndex] = remote;
    }
    _sharedMatchIds.add(remote.id);
    if (remote.creatorPlayerId == playerId) {
      _lastSharedMatchPayloads[remote.id] = _watchSafeMatchPayload(remote);
    }
    await _cacheParticipantProfiles(remote);

    final player = activePlayer;
    if (player != null) {
      PlayerHistory.copyStats(
        player.stats,
        PlayerHistory.calculateSinglesCareer(player.id, matches),
      );
    }
  }

  Future<void> _refreshSharedMatches({
    required bool migrateLegacy,
  }) async {
    final firestore = _firestore;
    final playerId = activePlayerId;
    if (!cloudConnected || firestore == null || playerId == null) return;

    try {
      if (migrateLegacy) {
        // Build 15 and older only shared completed matches. Push every match
        // owned by this account so active/drawing matches become participant-
        // visible without changing any Match ID.
        await _flushPendingSharedMatchDeletes();
        await _syncOwnedMatchesToShared();
      }

      final snapshot = await firestore
          .collection('matches')
          .where('participantIds', arrayContains: playerId)
          .get();

      final remoteIds = <String>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        _hydrateParticipantSnapshots(data);
        final match = _matchFromSharedDocument(data);
        if (match == null || !match.participantIds.contains(playerId)) continue;
        remoteIds.add(match.id);
        await _ingestSharedMatch(match);
      }

      // A foreign unfinished match disappearing from the canonical shared
      // collection means the host cancelled/cleared it. Do not keep a ghost
      // Resume card on participant devices.
      matches.removeWhere(
        (match) =>
            match.creatorPlayerId != playerId &&
            match.status != MatchStatus.completed &&
            match.participantIds.contains(playerId) &&
            !remoteIds.contains(match.id),
      );

      _sharedMatchIds
        ..clear()
        ..addAll(remoteIds);

      final player = activePlayer;
      if (player != null) {
        PlayerHistory.copyStats(
          player.stats,
          PlayerHistory.calculateSinglesCareer(player.id, matches),
        );
      }
    } on FirebaseException {
      // Cached/offline matches stay visible; Refresh can retry later.
    }
  }

  Stream<CricketMatch?> watchSharedMatch(String matchId) {
    final firestore = _firestore;
    final playerId = activePlayerId;
    if (!cloudConnected || firestore == null || playerId == null) {
      return Stream<CricketMatch?>.value(matchById(matchId));
    }

    return firestore.collection('matches').doc(matchId).snapshots().asyncMap(
      (snapshot) async {
        if (!snapshot.exists) {
          final localIndex = matches.indexWhere((match) => match.id == matchId);
          if (localIndex >= 0 &&
              matches[localIndex].creatorPlayerId != playerId &&
              matches[localIndex].status != MatchStatus.completed) {
            matches.removeAt(localIndex);
            await _persistLocal();
            notifyListeners();
          }
          return null;
        }
        final data = snapshot.data()!;
        _hydrateParticipantSnapshots(data);
        final remote = _matchFromSharedDocument(data);
        if (remote == null || !remote.participantIds.contains(playerId)) {
          return null;
        }
        await _ingestSharedMatch(remote, preserveOwnedWhenAhead: true);
        await _persistLocal();
        if (remote.status == MatchStatus.completed) {
          await _syncActivePlayerPublicProfile();
        }
        notifyListeners();
        return matchById(matchId);
      },
    );
  }

  Future<void> _restoreCloudState({bool replaceLocal = false}) async {
    final firestore = _firestore;
    final playerId = activePlayerId;
    if (firestore == null || playerId == null) return;
    try {
      final snapshot = await firestore.collection('accountStates').doc(playerId).get();
      final raw = snapshot.data()?['state'] as String?;
      if (raw != null && raw.isNotEmpty && (replaceLocal || players.isEmpty)) {
        _replaceState(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        activePlayerId = playerId;
        await _persistLocal();
        return;
      }
      final publicPlayer = await findPublicPlayer(playerId, bypassSignedInGate: true);
      if (publicPlayer != null) {
        _addOrReplacePlayer(publicPlayer);
        activePlayerId = playerId;
        await _persistLocal();
      }
    } on FirebaseException {
      // Login can still use cached local data when available.
    }
  }

  Future<void> _refreshSocialGraph() async {
    final firestore = _firestore;
    final self = activePlayer;
    if (!cloudConnected || firestore == null || self == null) return;
    try {
      final results = await Future.wait([
        firestore
            .collection('friendRequests')
            .where('toPlayerId', isEqualTo: self.id)
            .limit(50)
            .get(),
        firestore
            .collection('friendRequests')
            .where('fromPlayerId', isEqualTo: self.id)
            .limit(50)
            .get(),
        firestore
            .collection('notifications')
            .where('recipientPlayerId', isEqualTo: self.id)
            .limit(100)
            .get(),
        firestore
            .collection('players')
            .doc(self.id)
            .collection('friends')
            .limit(200)
            .get(),
      ]);

      final requestDocuments = [...results[0].docs, ...results[1].docs];
      friendRequests.removeWhere(
        (request) =>
            request.toPlayerId == self.id || request.fromPlayerId == self.id,
      );
      for (final document in requestDocuments) {
        final data = document.data();
        if (data['status'] != 'pending') continue;
        final fromId = data['fromPlayerId']?.toString();
        final toId = data['toPlayerId']?.toString();
        if (fromId == null || toId == null) continue;
        final otherId = fromId == self.id ? toId : fromId;
        await findPublicPlayer(otherId);
        friendRequests.add(
          FriendRequest(
            id: document.id,
            fromPlayerId: fromId,
            toPlayerId: toId,
            status: FriendRequestStatus.pending,
            createdAt: _dateFromCloud(data['createdAt']),
          ),
        );
      }

      notifications.removeWhere((value) => value.playerId == self.id);
      for (final document in results[2].docs) {
        final data = document.data();
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
                '${sender?.name ?? fromId ?? 'A player'} accepted your friend request.',
              _ => 'Your CricXii account has an update.',
            },
            referenceId: data['requestId']?.toString(),
            fromPlayerId: fromId,
            createdAt: _dateFromCloud(data['createdAt']),
            read: data['read'] as bool? ?? false,
            actionStatus: data['actionStatus']?.toString(),
          ),
        );
      }

      final cloudFriendIds = <String>{};
      for (final document in results[3].docs) {
        final friendId = document.data()['playerId']?.toString() ?? document.id;
        if (friendId == self.id) continue;
        cloudFriendIds.add(friendId);
        await findPublicPlayer(friendId);
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
      // Cached social data remains visible; manual Refresh can retry.
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
    'phone' => player.phoneNumber,
    'whatsapp' => player.whatsappNumber,
    'location' => player.location,
    _ => null,
  };

  void _setContactValue(Player player, String field, String? value) {
    switch (field) {
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
    final random = Random.secure();
    final previousPlayerOrder = List<String>.from(match.drawPlayerOrder);
    final previousCardOrder = match.drawPool
        .map((card) => card.order.toString())
        .toList(growable: false);
    final playerOrder = List<String>.from(match.participantIds);
    for (var attempt = 0; attempt < 8; attempt++) {
      playerOrder.shuffle(random);
      if (playerOrder.length < 2 || !_sameOrder(playerOrder, previousPlayerOrder)) {
        break;
      }
    }
    match.drawPlayerOrder
      ..clear()
      ..addAll(playerOrder);

    final cardColors = <int>[
      for (var index = 0; index < match.participantIds.length; index++)
        colors[index % colors.length],
    ]..shuffle(random);
    final cards = List.generate(
      match.participantIds.length,
      (index) => DrawCard(
        id: _ids.cardId(),
        order: index + 1,
        colorValue: cardColors[index],
      ),
    );
    for (var attempt = 0; attempt < 8; attempt++) {
      cards.shuffle(random);
      final nextPattern = cards
          .map((card) => card.order.toString())
          .toList(growable: false);
      if (cards.length < 2 || !_sameOrder(nextPattern, previousCardOrder)) {
        break;
      }
    }
    match.drawPool
      ..clear()
      ..addAll(cards);
  }

  bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _finalizeDraw(CricketMatch match) {
    final ordered = match.drawAssignments.values.toList()
      ..sort((a, b) => a.card.order.compareTo(b.card.order));
    match.battingOrder
      ..clear()
      ..addAll(ordered.map((value) => value.playerId));
    match.orderSource = BattingOrderSource.secretDraw;
    if (match.autoBowlingPlan) {
      match.bowlingPlan
        ..clear()
        ..addAll(
          BowlingScheduler.generate(
            battingOrder: match.battingOrder,
            participantIds: match.participantIds,
            ballLimit: match.ballLimit,
          ),
        );
    }
  }

  void _seedOrderAssignments(CricketMatch match, List<String> order) {
    _createDrawPool(match);
    final cards = List<DrawCard>.from(match.drawPool)
      ..sort((a, b) => a.order.compareTo(b.order));
    match.drawAssignments.clear();
    for (var index = 0; index < order.length; index++) {
      match.drawAssignments[order[index]] = DrawAssignment(
        playerId: order[index],
        card: cards[index],
      );
    }
  }

  void _regenerateFutureBowlingPlan(CricketMatch match) {
    if (!match.autoBowlingPlan) {
      match.bowlingPlan.clear();
      return;
    }
    final states = ScoringEngine.rebuildTurns(match);
    final current = ScoringEngine.currentBatterId(match);
    final lockedBatters = <String>{
      for (final id in match.battingOrder)
        if (states[id]?.isComplete(match.ballLimit) ?? false) id,
      if (current != null) current,
    };
    final fixed = match.bowlingPlan
        .where((block) => lockedBatters.contains(block.batterId))
        .toList();
    final orderIndex = <String, int>{
      for (var index = 0; index < match.battingOrder.length; index++)
        match.battingOrder[index]: index,
    };
    fixed.sort((a, b) {
      final batter = (orderIndex[a.batterId] ?? 0).compareTo(
        orderIndex[b.batterId] ?? 0,
      );
      return batter != 0 ? batter : a.blockIndex.compareTo(b.blockIndex);
    });
    final loads = <String, int>{for (final id in match.participantIds) id: 0};
    for (final block in fixed) {
      loads[block.bowlerId] = (loads[block.bowlerId] ?? 0) + block.legalBalls;
    }
    final futureBatters = match.battingOrder
        .where((id) => !lockedBatters.contains(id))
        .toList();
    final generated = BowlingScheduler.generate(
      battingOrder: futureBatters,
      participantIds: match.participantIds,
      ballLimit: match.ballLimit,
      initialLoads: loads,
      previousBowlerId: fixed.isEmpty ? null : fixed.last.bowlerId,
    );
    match.bowlingPlan
      ..clear()
      ..addAll(fixed)
      ..addAll(generated);
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

class _PlayerIdCollision implements Exception {}
