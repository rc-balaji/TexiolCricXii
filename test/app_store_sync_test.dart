// SDK interface doubles let these tests control transaction completion and
// retries without a live Firebase project. They are never used by the app.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crixx/data/app_store.dart';
import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:crixx/domain/social.dart';
import 'package:crixx/domain/team_match.dart';
import 'package:crixx/domain/team_scoring_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _host = '11111111';
const _friend = '22222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final team in [false, true]) {
    test(
      '${team ? 'Team' : 'Singles'} upload never acknowledges a later ball',
      () async {
        final cloud = _Firestore();
        final store = _store(cloud);
        final singles = _singles();
        final teams = _team();
        if (team) {
          TeamScoringEngine.startFirstInnings(teams, openingBowlerId: _friend);
          store.teamMatches.add(teams);
        } else {
          store.matches.add(singles);
        }
        final written = Completer<void>();
        final release = Completer<void>();
        cloud.beforeCommit = (transaction) async {
          written.complete();
          await release.future;
        };
        final firstSync =
            team
                ? store.syncTeamMatchNow(teams.id)
                : store.syncMatchNow(singles.id);
        await written.future;
        if (team) {
          TeamScoringEngine.recordDelivery(teams, eventId: 'later', batRuns: 4);
        } else {
          ScoringEngine.recordDelivery(
            singles,
            eventId: 'later',
            batRuns: 4,
            bowlerId: _friend,
          );
        }
        // Firestore can emit its local write echo before the transaction Future
        // resolves. That older payload must not replace a ball entered meanwhile.
        final path = team ? 'teamMatches/${teams.id}' : 'matches/${singles.id}';
        cloud.documents[path] = cloud.pendingTransaction!.writes[path]!;
        if (team) {
          final echoed = await store.watchSharedTeamMatch(teams.id).first;
          expect(echoed, same(teams));
          expect(echoed!.currentInnings!.events, hasLength(1));
        } else {
          final echoed = await store.watchSharedMatch(singles.id).first;
          expect(echoed, same(singles));
          expect(echoed!.events, hasLength(1));
        }
        release.complete();
        expect(await firstSync, isFalse);
        final key = team ? 'teamMatchJson' : 'matchJson';
        final firstSent =
            jsonDecode(cloud.documents[path]![key] as String) as Map;
        expect(
          team
              ? (firstSent['innings'] as List).single['events']
              : firstSent['events'],
          isEmpty,
        );
        expect(
          team ? teams.currentInnings!.events : singles.events,
          hasLength(1),
        );
        expect(
          await (team
              ? store.syncTeamMatchNow(teams.id)
              : store.syncMatchNow(singles.id)),
          isTrue,
        );
        final latest = jsonDecode(cloud.documents[path]![key] as String) as Map;
        expect(
          team
              ? (latest['innings'] as List).single['events']
              : latest['events'],
          hasLength(1),
        );
        expect(team ? teams.revision : singles.revision, 2);
      },
    );

    test(
      '${team ? 'Team' : 'Singles'} failed and retried transactions preserve the live revision',
      () async {
        final cloud = _Firestore()..failCommits = true;
        final store = _store(cloud);
        final singles = _singles();
        final teams = _team();
        if (team) {
          store.teamMatches.add(teams);
        } else {
          store.matches.add(singles);
        }
        Future<bool> sync() =>
            team
                ? store.syncTeamMatchNow(teams.id)
                : store.syncMatchNow(singles.id);
        expect(await sync(), isFalse);
        expect(team ? teams.revision : singles.revision, 0);
        expect(team ? teams.controllerUid : singles.controllerUid, isNull);
        expect(cloud.documents, isEmpty);
        cloud
          ..failCommits = false
          ..retryOnce = true
          ..onRetry = () {
            expect(team ? teams.revision : singles.revision, 0);
            expect(team ? teams.controllerUid : singles.controllerUid, isNull);
          };
        expect(await sync(), isTrue);
        expect(team ? teams.revision : singles.revision, 1);
      },
    );
  }

  test(
    'refresh before the first card retains the host secret draw after restart',
    () async {
      final cloud = _Firestore();
      final preferences = _Preferences();
      var store = _store(cloud, preferences: preferences);
      final local =
          _singles()
            ..status = MatchStatus.drawing
            ..battingOrder.clear();
      local.drawPlayerOrder.addAll(local.participantIds);
      local.drawPool.addAll([
        const DrawCard(id: 'hidden-1', order: 2, colorValue: 1),
        const DrawCard(id: 'hidden-2', order: 1, colorValue: 2),
      ]);
      store.matches.add(local);
      expect(await store.syncMatchNow(local.id), isTrue);
      final shared =
          jsonDecode(
                cloud.documents['matches/${local.id}']!['matchJson'] as String,
              )
              as Map;
      expect(shared['drawPool'], isEmpty);
      expect(shared['drawAssignments'], isEmpty);
      store = _store(
        cloud,
        preferences: preferences,
        savedState: preferences.state,
      );
      final refreshed = await store.watchSharedMatch(local.id).first;
      expect(refreshed!.drawPool.map((card) => card.id), [
        'hidden-1',
        'hidden-2',
      ]);
      expect(refreshed.drawAssignments, isEmpty);
      await store.chooseDrawCard(local.id, _host, 'hidden-1');
      expect(store.matchById(local.id)!.battingOrder, [_friend, _host]);
    },
  );

  test(
    'rejected friend request can be resent using a new notification',
    () async {
      final cloud = _Firestore();
      final sender = _store(cloud);
      await sender.sendFriendRequestTo(
        _friend,
        knownPlayer: sender.playerById(_friend),
      );
      final request = sender.friendRequests.single;
      final requestPath = 'friendRequests/${request.id}';
      final originalNotification =
          cloud.documents[requestPath]!['notificationId'] as String;
      final recipient = _store(cloud, playerId: _friend);
      recipient.friendRequests.add(FriendRequest.fromJson(request.toJson()));
      cloud.actor = _friend;
      await recipient.respondToFriendRequest(request.id, accept: false);
      expect(
        cloud.documents['notifications/$originalNotification']!['actionStatus'],
        'rejected',
      );
      sender.friendRequests.clear();
      cloud.actor = _host;
      await sender.sendFriendRequestTo(
        _friend,
        knownPlayer: sender.playerById(_friend),
      );
      final newNotification = cloud.documents[requestPath]!['notificationId'];
      expect(newNotification, isNot(originalNotification));
      expect(
        cloud.documents['notifications/$newNotification']!['actionStatus'],
        'pending',
      );
      expect(
        cloud.documents['notifications/$originalNotification']!['actionStatus'],
        'rejected',
      );
    },
  );

  test(
    'failed Team cancellation stays hidden after restart and retries durably',
    () async {
      final cloud = _Firestore();
      final preferences = _Preferences();
      final store = _store(cloud, preferences: preferences);
      final match = _team();
      store.teamMatches.add(match);
      expect(await store.syncTeamMatchNow(match.id), isTrue);
      cloud.failDeletes = true;
      await store.cancelTeamMatch(match.id);
      expect(preferences.state['pendingSharedTeamMatchDeletes'], [match.id]);
      expect(store.teamMatchById(match.id), isNull);
      final restarted = _store(
        cloud,
        preferences: preferences,
        savedState: preferences.state,
      );
      expect(await restarted.watchSharedTeamMatch(match.id).first, isNull);
      await restarted.refreshMatches();
      expect(restarted.teamMatchById(match.id), isNull);
      expect(preferences.state['pendingSharedTeamMatchDeletes'], [match.id]);
      expect(cloud.documents.containsKey('teamMatches/${match.id}'), isTrue);
      cloud.failDeletes = false;
      await restarted.refreshMatches();
      expect(preferences.state['pendingSharedTeamMatchDeletes'], isEmpty);
      expect(cloud.documents.containsKey('teamMatches/${match.id}'), isFalse);
    },
  );

  test(
    'Team cancellation waits for an in-flight creation before deleting',
    () async {
      final cloud = _Firestore();
      final preferences = _Preferences();
      final store = _store(cloud, preferences: preferences);
      final match = _team();
      store.teamMatches.add(match);
      final written = Completer<void>();
      final release = Completer<void>();
      cloud.beforeCommit = (_) async {
        written.complete();
        await release.future;
      };
      final upload = store.syncTeamMatchNow(match.id);
      await written.future;
      final cancel = store.cancelTeamMatch(match.id);
      // Cancellation persists its tombstone before any network work.
      await Future<void>.delayed(Duration.zero);
      expect(preferences.state['pendingSharedTeamMatchDeletes'], [match.id]);
      release.complete();
      await upload;
      await cancel;
      expect(store.teamMatchById(match.id), isNull);
      expect(cloud.documents.containsKey('teamMatches/${match.id}'), isFalse);
      expect(preferences.state['pendingSharedTeamMatchDeletes'], isEmpty);
    },
  );
}

AppStore _store(
  _Firestore cloud, {
  _Preferences? preferences,
  String playerId = _host,
  Map<String, dynamic>? savedState,
}) => AppStore.forTesting(
  auth: _Auth(),
  firestore: cloud,
  preferences: preferences ?? _Preferences(),
  playerId: playerId,
  savedState:
      savedState ??
      {
        'players': [
          for (final id in [_host, _friend, '33333333', '44444444'])
            Player(
              id: id,
              name: id,
              avatarColor: 1,
              createdAt: DateTime.utc(2026),
            ).toJson(),
        ],
      },
);

CricketMatch _singles() => CricketMatch(
  id: 'TXM-SYNC',
  title: 'Sync',
  creatorPlayerId: _host,
  scoringMode: ScoringMode.ballByBall,
  ballLimit: 12,
  participantIds: [_host, _friend],
  battingOrder: [_host, _friend],
  createdAt: DateTime.utc(2026),
  status: MatchStatus.live,
);

TeamMatch _team() => TeamMatch(
  id: 'TXT-SYNC',
  title: 'Sync',
  creatorPlayerId: _host,
  teamA: TeamSide(
    id: 'a',
    name: 'A',
    colorValue: 1,
    playerIds: [_host, '33333333'],
  ),
  teamB: TeamSide(
    id: 'b',
    name: 'B',
    colorValue: 2,
    playerIds: [_friend, '44444444'],
  ),
  rules: const TeamMatchRules(ballLimit: 12),
  createdAt: DateTime.utc(2026),
  toss: TeamToss(
    mode: TeamTossMode.skipped,
    firstBattingTeamId: 'a',
    createdAt: DateTime.utc(2026),
  ),
);

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'device';
}

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  Map<String, dynamic> get state =>
      jsonDecode(values['texiol_local_cricket_state_v4']!)
          as Map<String, dynamic>;
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  String actor = _host;
  int nextId = 0;
  bool failDeletes = false;
  bool failCommits = false;
  bool retryOnce = false;
  void Function()? onRetry;
  _Transaction? pendingTransaction;
  Future<void> Function(_Transaction)? beforeCommit;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(this, collectionPath);
  @override
  WriteBatch batch() => _Batch();
  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (retryOnce) {
      retryOnce = false;
      await transactionHandler(_Transaction(this));
      onRetry?.call();
    }
    final transaction = _Transaction(this);
    pendingTransaction = transaction;
    final result = await transactionHandler(transaction);
    final pause = beforeCommit;
    beforeCommit = null;
    if (pause != null) await pause(transaction);
    transaction.commit();
    return result;
  }
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.cloud, this.path, {this.arrayField, this.arrayValue});
  final _Firestore cloud;
  final String path;
  final Object? arrayField;
  final Object? arrayValue;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query(cloud, path, arrayField: field, arrayValue: arrayContains);
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QuerySnapshot([
    for (final entry in cloud.documents.entries)
      if (entry.key.startsWith('$path/') &&
          entry.key.split('/').length == path.split('/').length + 1 &&
          (arrayField == null ||
              (entry.value[arrayField] as List? ?? []).contains(arrayValue)))
        _QueryDocument(entry.value),
  ]);
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.value);
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Collection extends _Query
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(super.cloud, super.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(cloud, '${this.path}/${path ?? 'auto-${cloud.nextId++}'}');
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.cloud, this.path);
  final _Firestore cloud;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(cloud, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(cloud.documents[path]);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(_Snapshot(cloud.documents[path]));
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    cloud.documents[path] = Map.of(data);
  }

  @override
  Future<void> delete() async {
    cloud.documents.remove(path);
  }
}

class _Snapshot<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.cloud);
  final _Firestore cloud;
  final writes = <String, Map<String, dynamic>>{};
  final deletes = <String>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async => _Snapshot(cloud.documents[documentReference.path] as T?);
  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    writes[documentReference.path] = {
      if (options?.merge == true) ...?cloud.documents[documentReference.path],
      ...data as Map<String, dynamic>,
    };
    return this;
  }

  @override
  Transaction delete(DocumentReference<Object?> documentReference) {
    deletes.add(documentReference.path);
    return this;
  }

  void commit() {
    if (cloud.failCommits || (cloud.failDeletes && deletes.isNotEmpty)) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    for (final entry in writes.entries) {
      final old = cloud.documents[entry.key];
      if (entry.key.startsWith('notifications/') &&
          old != null &&
          old['recipientPlayerId'] != cloud.actor) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
    }
    for (final path in deletes) {
      cloud.documents.remove(path);
    }
    cloud.documents.addAll(writes);
  }
}

class _Batch extends Fake implements WriteBatch {
  @override
  void delete(DocumentReference<Object?> document) {}
  @override
  Future<void> commit() async {}
}
