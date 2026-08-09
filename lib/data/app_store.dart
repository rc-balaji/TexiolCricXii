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
import '../domain/enums.dart';
import '../domain/gang.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';

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
  bool _offlineSession = false;
  final List<Player> players = <Player>[];
  final List<Gang> gangs = <Gang>[];
  final List<CricketMatch> matches = <CricketMatch>[];

  bool initialized = false;
  String? activePlayerId;

  User? get firebaseUser => _auth?.currentUser;
  String? get cloudEmail => firebaseUser?.email;
  bool get requiresAuthentication =>
      firebaseEnabled && firebaseUser == null && !_offlineSession;
  bool get cloudConnected => firebaseEnabled && firebaseUser != null;

  Player? get activePlayer => playerById(activePlayerId);

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
      } on Object {
        _clearState();
      }
    }
    if (firebaseEnabled) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      if (firebaseUser != null && players.isEmpty) {
        await _restoreCloudState();
      }
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
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _syncCloudState(_stateData());
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
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    await _restoreCloudState(replaceLocal: true);
    await _syncCloudState(_stateData());
    notifyListeners();
  }

  Future<void> signOutCloud() async {
    await _auth?.signOut();
    _offlineSession = false;
    await _preferences.setBool(_offlineSessionKey, false);
    notifyListeners();
  }

  Future<void> continueOffline() async {
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

  Player? playerById(String? id) {
    if (id == null) return null;
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
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
    bool claimed = true,
    bool makeActive = false,
  }) async {
    final id = _uniquePlayerId();
    final temporaryPassword = claimed ? null : _ids.temporaryPassword();
    final claimSecretSalt = claimed ? null : _ids.eventId();
    final claimSecretHash = temporaryPassword == null
        ? null
        : sha256
              .convert(utf8.encode('$claimSecretSalt:$temporaryPassword'))
              .toString();
    final player = Player(
      id: id,
      name: name.trim(),
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      instagramHandle: instagramHandle?.trim().isEmpty ?? true
          ? null
          : instagramHandle!.trim().replaceFirst('@', ''),
      claimSecretHash: claimSecretHash,
      claimSecretSalt: claimSecretSalt,
      avatarColor: _avatarColors[players.length % _avatarColors.length],
      claimed: claimed,
      createdAt: DateTime.now(),
    );
    players.add(player);
    if (makeActive || activePlayerId == null) activePlayerId = player.id;
    await _commit();
    return CreatedPlayer(player: player, temporaryPassword: temporaryPassword);
  }

  Future<void> switchPlayer(String playerId) async {
    if (playerById(playerId) == null) throw StateError('Player not found.');
    activePlayerId = playerId;
    await _commit();
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

  Future<void> addFriend(String playerId, String friendId) async {
    final player = playerById(playerId);
    final friend = playerById(friendId);
    if (player == null || friend == null || playerId == friendId) {
      throw StateError('Choose another valid player.');
    }
    if (!player.friendIds.contains(friendId)) player.friendIds.add(friendId);
    if (!friend.friendIds.contains(playerId)) friend.friendIds.add(playerId);
    await _commit();
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
    await _preferences.setString(_storageKey, jsonEncode(data));
    unawaited(_syncCloudState(data));
    notifyListeners();
  }

  Map<String, Object?> _stateData() => {
    'activePlayerId': activePlayerId,
    'players': players.map((value) => value.toJson()).toList(),
    'gangs': gangs.map((value) => value.toJson()).toList(),
    'matches': matches.map((value) => value.toJson()).toList(),
    'schemaVersion': 1,
  };

  void _replaceState(Map<String, dynamic> json) {
    _clearState();
    activePlayerId = json['activePlayerId'] as String?;
    players.addAll(
      (json['players'] as List? ?? const []).map(
        (value) => Player.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
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
  }

  void _clearState() {
    players.clear();
    gangs.clear();
    matches.clear();
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
            'schemaVersion': 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
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
        await _preferences.setString(_storageKey, jsonEncode(_stateData()));
      }
    } on FirebaseException {
      // A cached local match can still continue if Firebase is unreachable.
    }
  }

  String _uniquePlayerId() {
    var id = _ids.playerId();
    while (playerById(id) != null) {
      id = _ids.playerId();
    }
    return id;
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
