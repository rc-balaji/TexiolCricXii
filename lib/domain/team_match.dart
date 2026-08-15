import 'cricket_match.dart';
import 'enums.dart';

enum TeamMatchStatus { toss, live, inningsBreak, completed }

enum TeamTossCall { heads, tails }

enum TeamTossDecision { bat, bowl }

class TeamMatchRules {
  const TeamMatchRules({
    required this.ballLimit,
    this.ballsPerOver = 6,
    this.wideEnabled = true,
    this.noBallEnabled = true,
    this.byeEnabled = true,
    this.legByeEnabled = true,
    this.penaltyExtrasEnabled = true,
    this.freeHitEnabled = false,
    this.wideValue = 1,
    this.noBallValue = 1,
    this.wideCountsAsLegal = false,
    this.noBallCountsAsLegal = false,
    this.askLastPlayerStanding = true,
    this.allowConsecutiveOvers = false,
    this.pointRules = const PointRules(),
  });

  final int ballLimit;
  final int ballsPerOver;
  final bool wideEnabled;
  final bool noBallEnabled;
  final bool byeEnabled;
  final bool legByeEnabled;
  final bool penaltyExtrasEnabled;
  final bool freeHitEnabled;
  final int wideValue;
  final int noBallValue;
  final bool wideCountsAsLegal;
  final bool noBallCountsAsLegal;
  final bool askLastPlayerStanding;
  final bool allowConsecutiveOvers;
  final PointRules pointRules;

  Map<String, Object?> toJson() => {
    'ballLimit': ballLimit,
    'ballsPerOver': ballsPerOver,
    'wideEnabled': wideEnabled,
    'noBallEnabled': noBallEnabled,
    'byeEnabled': byeEnabled,
    'legByeEnabled': legByeEnabled,
    'penaltyExtrasEnabled': penaltyExtrasEnabled,
    'freeHitEnabled': freeHitEnabled,
    'wideValue': wideValue,
    'noBallValue': noBallValue,
    'wideCountsAsLegal': wideCountsAsLegal,
    'noBallCountsAsLegal': noBallCountsAsLegal,
    'askLastPlayerStanding': askLastPlayerStanding,
    'allowConsecutiveOvers': allowConsecutiveOvers,
    'pointRules': pointRules.toJson(),
  };

  factory TeamMatchRules.fromJson(Map<String, dynamic> json) => TeamMatchRules(
    ballLimit: json['ballLimit'] as int? ?? 30,
    ballsPerOver: json['ballsPerOver'] as int? ?? 6,
    wideEnabled: json['wideEnabled'] as bool? ?? true,
    noBallEnabled: json['noBallEnabled'] as bool? ?? true,
    byeEnabled: json['byeEnabled'] as bool? ?? true,
    legByeEnabled: json['legByeEnabled'] as bool? ?? true,
    penaltyExtrasEnabled: json['penaltyExtrasEnabled'] as bool? ?? true,
    freeHitEnabled: json['freeHitEnabled'] as bool? ?? false,
    wideValue: json['wideValue'] as int? ?? 1,
    noBallValue: json['noBallValue'] as int? ?? 1,
    wideCountsAsLegal: json['wideCountsAsLegal'] as bool? ?? false,
    noBallCountsAsLegal: json['noBallCountsAsLegal'] as bool? ?? false,
    askLastPlayerStanding:
        json['askLastPlayerStanding'] as bool? ?? true,
    allowConsecutiveOvers:
        json['allowConsecutiveOvers'] as bool? ?? false,
    pointRules: PointRules.fromJson(
      Map<String, dynamic>.from(json['pointRules'] as Map? ?? const {}),
    ),
  );
}

class TeamSide {
  TeamSide({
    required this.id,
    required this.name,
    required this.colorValue,
    required List<String> playerIds,
    List<String>? battingOrder,
    Map<String, int>? bowlingQuotaBalls,
    this.captainPlayerId,
    this.wicketkeeperPlayerId,
  }) : playerIds = playerIds,
       battingOrder = battingOrder ?? List<String>.from(playerIds),
       bowlingQuotaBalls = bowlingQuotaBalls ?? <String, int>{};

  final String id;
  String name;
  int colorValue;
  final List<String> playerIds;
  final List<String> battingOrder;
  final Map<String, int> bowlingQuotaBalls;
  String? captainPlayerId;
  String? wicketkeeperPlayerId;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'playerIds': playerIds,
    'battingOrder': battingOrder,
    'bowlingQuotaBalls': bowlingQuotaBalls,
    'captainPlayerId': captainPlayerId,
    'wicketkeeperPlayerId': wicketkeeperPlayerId,
  };

  factory TeamSide.fromJson(Map<String, dynamic> json) => TeamSide(
    id: json['id'] as String,
    name: json['name'] as String,
    colorValue: json['colorValue'] as int? ?? 0xFF19C37D,
    playerIds: List<String>.from(json['playerIds'] as List? ?? const []),
    battingOrder: List<String>.from(
      json['battingOrder'] as List? ?? json['playerIds'] as List? ?? const [],
    ),
    bowlingQuotaBalls: Map<String, dynamic>.from(
      json['bowlingQuotaBalls'] as Map? ?? const {},
    ).map((key, value) => MapEntry(key, value as int)),
    captainPlayerId: json['captainPlayerId'] as String?,
    wicketkeeperPlayerId: json['wicketkeeperPlayerId'] as String?,
  );
}

class TeamToss {
  const TeamToss({
    required this.callerTeamId,
    required this.call,
    required this.result,
    required this.winnerTeamId,
    required this.decision,
    required this.createdAt,
  });

  final String callerTeamId;
  final TeamTossCall call;
  final TeamTossCall result;
  final String winnerTeamId;
  final TeamTossDecision decision;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'callerTeamId': callerTeamId,
    'call': call.name,
    'result': result.name,
    'winnerTeamId': winnerTeamId,
    'decision': decision.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TeamToss.fromJson(Map<String, dynamic> json) => TeamToss(
    callerTeamId: json['callerTeamId'] as String,
    call: TeamTossCall.values.byName(json['call'] as String),
    result: TeamTossCall.values.byName(json['result'] as String),
    winnerTeamId: json['winnerTeamId'] as String,
    decision: TeamTossDecision.values.byName(json['decision'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class TeamDeliveryEvent {
  TeamDeliveryEvent({
    required this.id,
    required this.sequence,
    required this.strikerId,
    required this.bowlerId,
    required this.createdAt,
    this.nonStrikerId,
    this.batRuns = 0,
    this.extraRuns = 0,
    this.runningRuns = 0,
    this.extraType = ExtraType.none,
    this.legalBall = true,
    this.isWicket = false,
    this.dismissalType = DismissalType.none,
    this.dismissedPlayerId,
    List<String>? fielderIds,
  }) : fielderIds = fielderIds ?? <String>[];

  final String id;
  final int sequence;
  final String strikerId;
  final String? nonStrikerId;
  final String bowlerId;
  final DateTime createdAt;
  final int batRuns;
  final int extraRuns;
  final int runningRuns;
  final ExtraType extraType;
  final bool legalBall;
  final bool isWicket;
  final DismissalType dismissalType;
  final String? dismissedPlayerId;
  final List<String> fielderIds;

  int get totalRuns => batRuns + extraRuns;

  Map<String, Object?> toJson() => {
    'id': id,
    'sequence': sequence,
    'strikerId': strikerId,
    'nonStrikerId': nonStrikerId,
    'bowlerId': bowlerId,
    'createdAt': createdAt.toIso8601String(),
    'batRuns': batRuns,
    'extraRuns': extraRuns,
    'runningRuns': runningRuns,
    'extraType': extraType.name,
    'legalBall': legalBall,
    'isWicket': isWicket,
    'dismissalType': dismissalType.name,
    'dismissedPlayerId': dismissedPlayerId,
    'fielderIds': fielderIds,
  };

  factory TeamDeliveryEvent.fromJson(Map<String, dynamic> json) =>
      TeamDeliveryEvent(
        id: json['id'] as String,
        sequence: json['sequence'] as int? ?? 0,
        strikerId: json['strikerId'] as String,
        nonStrikerId: json['nonStrikerId'] as String?,
        bowlerId: json['bowlerId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        batRuns: json['batRuns'] as int? ?? 0,
        extraRuns: json['extraRuns'] as int? ?? 0,
        runningRuns: json['runningRuns'] as int? ?? 0,
        extraType: ExtraType.values.byName(
          json['extraType'] as String? ?? ExtraType.none.name,
        ),
        legalBall: json['legalBall'] as bool? ?? true,
        isWicket: json['isWicket'] as bool? ?? false,
        dismissalType: DismissalType.values.byName(
          json['dismissalType'] as String? ?? DismissalType.none.name,
        ),
        dismissedPlayerId: json['dismissedPlayerId'] as String?,
        fielderIds: List<String>.from(
          json['fielderIds'] as List? ?? const [],
        ),
      );
}

class TeamInnings {
  TeamInnings({
    required this.index,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.strikerId,
    required this.startedAt,
    this.nonStrikerId,
    this.target,
    this.nextBatterIndex = 2,
    List<TeamDeliveryEvent>? events,
    List<String>? dismissedPlayerIds,
    Map<int, String>? bowlerByOver,
    this.awaitingSoloDecision = false,
    this.soloMode = false,
    this.soloDeclined = false,
    this.completed = false,
    this.completionReason,
    this.completedAt,
  }) : events = events ?? <TeamDeliveryEvent>[],
       dismissedPlayerIds = dismissedPlayerIds ?? <String>[],
       bowlerByOver = bowlerByOver ?? <int, String>{};

  final int index;
  final String battingTeamId;
  final String bowlingTeamId;
  final DateTime startedAt;
  final int? target;
  final List<TeamDeliveryEvent> events;
  final List<String> dismissedPlayerIds;
  final Map<int, String> bowlerByOver;
  String strikerId;
  String? nonStrikerId;
  int nextBatterIndex;
  bool awaitingSoloDecision;
  bool soloMode;
  bool soloDeclined;
  bool completed;
  String? completionReason;
  DateTime? completedAt;

  Map<String, Object?> toJson() => {
    'index': index,
    'battingTeamId': battingTeamId,
    'bowlingTeamId': bowlingTeamId,
    'strikerId': strikerId,
    'nonStrikerId': nonStrikerId,
    'startedAt': startedAt.toIso8601String(),
    'target': target,
    'nextBatterIndex': nextBatterIndex,
    'events': events.map((value) => value.toJson()).toList(),
    'dismissedPlayerIds': dismissedPlayerIds,
    'bowlerByOver': bowlerByOver.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'awaitingSoloDecision': awaitingSoloDecision,
    'soloMode': soloMode,
    'soloDeclined': soloDeclined,
    'completed': completed,
    'completionReason': completionReason,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory TeamInnings.fromJson(Map<String, dynamic> json) => TeamInnings(
    index: json['index'] as int? ?? 0,
    battingTeamId: json['battingTeamId'] as String,
    bowlingTeamId: json['bowlingTeamId'] as String,
    strikerId: json['strikerId'] as String,
    nonStrikerId: json['nonStrikerId'] as String?,
    startedAt: DateTime.parse(json['startedAt'] as String),
    target: json['target'] as int?,
    nextBatterIndex: json['nextBatterIndex'] as int? ?? 2,
    events: (json['events'] as List? ?? const [])
        .map(
          (value) => TeamDeliveryEvent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(),
    dismissedPlayerIds: List<String>.from(
      json['dismissedPlayerIds'] as List? ?? const [],
    ),
    bowlerByOver: Map<String, dynamic>.from(
      json['bowlerByOver'] as Map? ?? const {},
    ).map((key, value) => MapEntry(int.parse(key), value.toString())),
    awaitingSoloDecision:
        json['awaitingSoloDecision'] as bool? ?? false,
    soloMode: json['soloMode'] as bool? ?? false,
    soloDeclined: json['soloDeclined'] as bool? ?? false,
    completed: json['completed'] as bool? ?? false,
    completionReason: json['completionReason'] as String?,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.tryParse(json['completedAt'].toString()),
  );
}

class TeamMatch {
  TeamMatch({
    required this.id,
    required this.title,
    required this.creatorPlayerId,
    required this.teamA,
    required this.teamB,
    required this.rules,
    required this.createdAt,
    this.originToken,
    this.commonJokerPlayerId,
    this.trackerPlayerId,
    this.status = TeamMatchStatus.toss,
    this.toss,
    List<TeamInnings>? innings,
    List<MatchAuditEntry>? auditTrail,
    this.startedAt,
    this.completedAt,
    this.controllerUid,
    this.controllerPlayerId,
    this.controllerLeaseUntil,
    this.revision = 0,
    this.statsApplied = false,
  }) : innings = innings ?? <TeamInnings>[],
       auditTrail = auditTrail ?? <MatchAuditEntry>[];

  final String id;
  final String? originToken;
  String title;
  final String creatorPlayerId;
  final TeamSide teamA;
  final TeamSide teamB;
  final TeamMatchRules rules;
  final DateTime createdAt;
  final String? commonJokerPlayerId;
  String? trackerPlayerId;
  TeamMatchStatus status;
  TeamToss? toss;
  final List<TeamInnings> innings;
  final List<MatchAuditEntry> auditTrail;
  DateTime? startedAt;
  DateTime? completedAt;
  String? controllerUid;
  String? controllerPlayerId;
  DateTime? controllerLeaseUntil;
  int revision;
  bool statsApplied;

  TeamSide side(String id) => id == teamA.id ? teamA : teamB;

  TeamSide otherSide(String id) => id == teamA.id ? teamB : teamA;

  TeamInnings? get currentInnings => innings.isEmpty ? null : innings.last;

  List<String> get participantIds {
    final result = <String>{
      creatorPlayerId,
      ...teamA.playerIds,
      ...teamB.playerIds,
    };
    if (trackerPlayerId != null) result.add(trackerPlayerId!);
    return result.toList(growable: false);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'originToken': originToken,
    'title': title,
    'creatorPlayerId': creatorPlayerId,
    'teamA': teamA.toJson(),
    'teamB': teamB.toJson(),
    'rules': rules.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'commonJokerPlayerId': commonJokerPlayerId,
    'trackerPlayerId': trackerPlayerId,
    'status': status.name,
    'toss': toss?.toJson(),
    'innings': innings.map((value) => value.toJson()).toList(),
    'auditTrail': auditTrail.map((value) => value.toJson()).toList(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'controllerUid': controllerUid,
    'controllerPlayerId': controllerPlayerId,
    'controllerLeaseUntil': controllerLeaseUntil?.toIso8601String(),
    'revision': revision,
    'statsApplied': statsApplied,
  };

  factory TeamMatch.fromJson(Map<String, dynamic> json) => TeamMatch(
    id: json['id'] as String,
    originToken: json['originToken'] as String?,
    title: json['title'] as String,
    creatorPlayerId: json['creatorPlayerId'] as String,
    teamA: TeamSide.fromJson(
      Map<String, dynamic>.from(json['teamA'] as Map),
    ),
    teamB: TeamSide.fromJson(
      Map<String, dynamic>.from(json['teamB'] as Map),
    ),
    rules: TeamMatchRules.fromJson(
      Map<String, dynamic>.from(json['rules'] as Map),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    commonJokerPlayerId: json['commonJokerPlayerId'] as String?,
    trackerPlayerId: json['trackerPlayerId'] as String?,
    status: TeamMatchStatus.values.byName(
      json['status'] as String? ?? TeamMatchStatus.toss.name,
    ),
    toss: json['toss'] == null
        ? null
        : TeamToss.fromJson(
            Map<String, dynamic>.from(json['toss'] as Map),
          ),
    innings: (json['innings'] as List? ?? const [])
        .map(
          (value) => TeamInnings.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(),
    auditTrail: (json['auditTrail'] as List? ?? const [])
        .map(
          (value) => MatchAuditEntry.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.tryParse(json['startedAt'].toString()),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.tryParse(json['completedAt'].toString()),
    controllerUid: json['controllerUid'] as String?,
    controllerPlayerId: json['controllerPlayerId'] as String?,
    controllerLeaseUntil: json['controllerLeaseUntil'] == null
        ? null
        : DateTime.tryParse(json['controllerLeaseUntil'].toString()),
    revision: json['revision'] as int? ?? 0,
    statsApplied: json['statsApplied'] as bool? ?? false,
  );
}

class TeamPlayerMatchStats {
  TeamPlayerMatchStats({required this.playerId, required this.teamId});

  final String playerId;
  final String teamId;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  bool dismissed = false;
  int wickets = 0;
  int ballsBowled = 0;
  int runsConceded = 0;
  int maidens = 0;
  int wides = 0;
  int noBalls = 0;
  int catches = 0;
  int directRunOuts = 0;
  int assistedRunOuts = 0;
  int stumpings = 0;
  int points = 0;

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;

  double get economy => ballsBowled == 0 ? 0 : runsConceded * 6 / ballsBowled;
}

class TeamMatchResult {
  const TeamMatchResult({
    required this.summary,
    this.winnerTeamId,
    this.marginRuns,
    this.marginWickets,
  });

  final String summary;
  final String? winnerTeamId;
  final int? marginRuns;
  final int? marginWickets;
}
