import 'enums.dart';

class PointRules {
  const PointRules({
    this.run = 1,
    this.wicket = 5,
    this.bowledBonus = 2,
    this.catchPoint = 2,
    this.directRunOut = 3,
    this.assistedRunOut = 1,
    this.stumping = 2,
    this.notOutBonus = 2,
  });

  final int run;
  final int wicket;
  final int bowledBonus;
  final int catchPoint;
  final int directRunOut;
  final int assistedRunOut;
  final int stumping;
  final int notOutBonus;

  Map<String, int> toJson() => {
    'run': run,
    'wicket': wicket,
    'bowledBonus': bowledBonus,
    'catchPoint': catchPoint,
    'directRunOut': directRunOut,
    'assistedRunOut': assistedRunOut,
    'stumping': stumping,
    'notOutBonus': notOutBonus,
  };

  factory PointRules.fromJson(Map<String, dynamic> json) => PointRules(
    run: json['run'] as int? ?? 1,
    wicket: json['wicket'] as int? ?? 5,
    bowledBonus: json['bowledBonus'] as int? ?? 2,
    catchPoint: json['catchPoint'] as int? ?? 2,
    directRunOut: json['directRunOut'] as int? ?? 3,
    assistedRunOut: json['assistedRunOut'] as int? ?? 1,
    stumping: json['stumping'] as int? ?? 2,
    notOutBonus: json['notOutBonus'] as int? ?? 2,
  );
}

class PointPreset {
  const PointPreset({
    required this.id,
    required this.name,
    required this.rules,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final PointRules rules;
  final bool builtIn;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'rules': rules.toJson(),
    'builtIn': builtIn,
  };

  factory PointPreset.fromJson(Map<String, dynamic> json) => PointPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    rules: PointRules.fromJson(
      Map<String, dynamic>.from(json['rules'] as Map? ?? const {}),
    ),
    builtIn: json['builtIn'] as bool? ?? false,
  );
}

class DrawCard {
  const DrawCard({
    required this.id,
    required this.order,
    required this.colorValue,
  });

  final String id;
  final int order;
  final int colorValue;

  Map<String, Object> toJson() => {
    'id': id,
    'order': order,
    'colorValue': colorValue,
  };

  factory DrawCard.fromJson(Map<String, dynamic> json) => DrawCard(
    id: json['id'] as String,
    order: json['order'] as int,
    colorValue: json['colorValue'] as int,
  );
}

class DrawAssignment {
  const DrawAssignment({required this.playerId, required this.card});

  final String playerId;
  final DrawCard card;

  Map<String, Object> toJson() => {'playerId': playerId, 'card': card.toJson()};

  factory DrawAssignment.fromJson(Map<String, dynamic> json) => DrawAssignment(
    playerId: json['playerId'] as String,
    card: DrawCard.fromJson(Map<String, dynamic>.from(json['card'] as Map)),
  );
}

class BowlingBlock {
  BowlingBlock({
    required this.batterId,
    required this.blockIndex,
    required this.startLegalBall,
    required this.legalBalls,
    required this.bowlerId,
  });

  final String batterId;
  final int blockIndex;
  final int startLegalBall;
  final int legalBalls;
  String bowlerId;

  Map<String, Object?> toJson() => {
    'batterId': batterId,
    'blockIndex': blockIndex,
    'startLegalBall': startLegalBall,
    'legalBalls': legalBalls,
    'bowlerId': bowlerId,
  };

  factory BowlingBlock.fromJson(Map<String, dynamic> json) => BowlingBlock(
    batterId: json['batterId'] as String,
    blockIndex: json['blockIndex'] as int? ?? 0,
    startLegalBall: json['startLegalBall'] as int? ?? 0,
    legalBalls: json['legalBalls'] as int? ?? 6,
    bowlerId: json['bowlerId'] as String,
  );
}

class BowlerChange {
  const BowlerChange({
    required this.batterId,
    required this.legalBallNumber,
    required this.fromBowlerId,
    required this.toBowlerId,
    required this.createdAt,
    this.reason = 'Replacement',
    this.alsoNextBlock = false,
  });

  final String batterId;
  final int legalBallNumber;
  final String fromBowlerId;
  final String toBowlerId;
  final DateTime createdAt;
  final String reason;
  final bool alsoNextBlock;

  Map<String, Object?> toJson() => {
    'batterId': batterId,
    'legalBallNumber': legalBallNumber,
    'fromBowlerId': fromBowlerId,
    'toBowlerId': toBowlerId,
    'createdAt': createdAt.toIso8601String(),
    'reason': reason,
    'alsoNextBlock': alsoNextBlock,
  };

  factory BowlerChange.fromJson(Map<String, dynamic> json) => BowlerChange(
    batterId: json['batterId'] as String,
    legalBallNumber: json['legalBallNumber'] as int? ?? 0,
    fromBowlerId: json['fromBowlerId'] as String,
    toBowlerId: json['toBowlerId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    reason: json['reason'] as String? ?? 'Replacement',
    alsoNextBlock: json['alsoNextBlock'] as bool? ?? false,
  );
}

class MatchAuditEntry {
  const MatchAuditEntry({
    required this.type,
    required this.createdAt,
    this.playerId,
    this.note,
  });

  final String type;
  final DateTime createdAt;
  final String? playerId;
  final String? note;

  Map<String, Object?> toJson() => {
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'playerId': playerId,
    'note': note,
  };

  factory MatchAuditEntry.fromJson(Map<String, dynamic> json) => MatchAuditEntry(
    type: json['type'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    playerId: json['playerId'] as String?,
    note: json['note'] as String?,
  );
}

class ScoreEvent {
  ScoreEvent({
    required this.id,
    required this.type,
    required this.batterId,
    required this.createdAt,
    this.batRuns = 0,
    this.extraRuns = 0,
    this.extraType = ExtraType.none,
    this.legalBall = true,
    this.isOut = false,
    this.dismissalType = DismissalType.none,
    this.bowlerId,
    List<String>? fielderIds,
  }) : fielderIds = fielderIds ?? <String>[];

  final String id;
  final ScoreEventType type;
  final String batterId;
  final DateTime createdAt;
  final int batRuns;
  final int extraRuns;
  final ExtraType extraType;
  final bool legalBall;
  final bool isOut;
  final DismissalType dismissalType;
  final String? bowlerId;
  final List<String> fielderIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'batterId': batterId,
    'createdAt': createdAt.toIso8601String(),
    'batRuns': batRuns,
    'extraRuns': extraRuns,
    'extraType': extraType.name,
    'legalBall': legalBall,
    'isOut': isOut,
    'dismissalType': dismissalType.name,
    'bowlerId': bowlerId,
    'fielderIds': fielderIds,
  };

  factory ScoreEvent.fromJson(Map<String, dynamic> json) => ScoreEvent(
    id: json['id'] as String,
    type: ScoreEventType.values.byName(json['type'] as String),
    batterId: json['batterId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    batRuns: json['batRuns'] as int? ?? 0,
    extraRuns: json['extraRuns'] as int? ?? 0,
    extraType: ExtraType.values.byName(
      json['extraType'] as String? ?? ExtraType.none.name,
    ),
    legalBall: json['legalBall'] as bool? ?? true,
    isOut: json['isOut'] as bool? ?? false,
    dismissalType: DismissalType.values.byName(
      json['dismissalType'] as String? ?? DismissalType.none.name,
    ),
    bowlerId: json['bowlerId'] as String?,
    fielderIds: List<String>.from(json['fielderIds'] as List? ?? const []),
  );
}

class CricketMatch {
  CricketMatch({
    required this.id,
    required this.title,
    required this.creatorPlayerId,
    required this.scoringMode,
    required this.ballLimit,
    required this.participantIds,
    required this.createdAt,
    this.originToken,
    this.status = MatchStatus.draft,
    this.winnerMetric = MatchWinnerMetric.overallPoints,
    this.trackerPlayerId,
    this.controllerUid,
    this.controllerPlayerId,
    this.controllerLeaseUntil,
    this.revision = 0,
    List<String>? tieBreakOrder,
    this.pointRules = const PointRules(),
    this.pointPresetName = 'Balanced',
    this.autoBowlingPlan = true,
    this.orderSource = BattingOrderSource.secretDraw,
    this.startedAt,
    this.completedAt,
    List<String>? battingOrder,
    List<String>? drawPlayerOrder,
    List<DrawCard>? drawPool,
    Map<String, DrawAssignment>? drawAssignments,
    List<BowlingBlock>? bowlingPlan,
    List<BowlerChange>? bowlerChanges,
    List<MatchAuditEntry>? auditTrail,
    List<ScoreEvent>? events,
    this.statsApplied = false,
  }) : battingOrder = battingOrder ?? <String>[],
       drawPlayerOrder = drawPlayerOrder ?? <String>[],
       drawPool = drawPool ?? <DrawCard>[],
       drawAssignments = drawAssignments ?? <String, DrawAssignment>{},
       bowlingPlan = bowlingPlan ?? <BowlingBlock>[],
       bowlerChanges = bowlerChanges ?? <BowlerChange>[],
       auditTrail = auditTrail ?? <MatchAuditEntry>[],
       events = events ?? <ScoreEvent>[],
       tieBreakOrder = tieBreakOrder ?? <String>[];

  final String id;
  String title;
  final String creatorPlayerId;
  ScoringMode scoringMode;
  int ballLimit;
  final DateTime createdAt;
  final String? originToken;
  DateTime? startedAt;
  DateTime? completedAt;
  MatchStatus status;
  MatchWinnerMetric winnerMetric;
  String? trackerPlayerId;
  String? controllerUid;
  String? controllerPlayerId;
  DateTime? controllerLeaseUntil;
  int revision;
  final List<String> tieBreakOrder;
  PointRules pointRules;
  String pointPresetName;
  bool autoBowlingPlan;
  BattingOrderSource orderSource;
  final List<String> participantIds;
  final List<String> battingOrder;
  final List<String> drawPlayerOrder;
  final List<DrawCard> drawPool;
  final Map<String, DrawAssignment> drawAssignments;
  final List<BowlingBlock> bowlingPlan;
  final List<BowlerChange> bowlerChanges;
  final List<MatchAuditEntry> auditTrail;
  final List<ScoreEvent> events;
  bool statsApplied;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'creatorPlayerId': creatorPlayerId,
    'scoringMode': scoringMode.name,
    'ballLimit': ballLimit,
    'createdAt': createdAt.toIso8601String(),
    'originToken': originToken,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'winnerMetric': winnerMetric.name,
    'trackerPlayerId': trackerPlayerId,
    'controllerUid': controllerUid,
    'controllerPlayerId': controllerPlayerId,
    'controllerLeaseUntil': controllerLeaseUntil?.toIso8601String(),
    'revision': revision,
    'tieBreakOrder': tieBreakOrder,
    'pointRules': pointRules.toJson(),
    'pointPresetName': pointPresetName,
    'autoBowlingPlan': autoBowlingPlan,
    'orderSource': orderSource.name,
    'participantIds': participantIds,
    'battingOrder': battingOrder,
    'drawPlayerOrder': drawPlayerOrder,
    'drawPool': drawPool.map((card) => card.toJson()).toList(),
    'drawAssignments': drawAssignments.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'bowlingPlan': bowlingPlan.map((value) => value.toJson()).toList(),
    'bowlerChanges': bowlerChanges.map((value) => value.toJson()).toList(),
    'auditTrail': auditTrail.map((value) => value.toJson()).toList(),
    'events': events.map((event) => event.toJson()).toList(),
    'statsApplied': statsApplied,
  };

  factory CricketMatch.fromJson(Map<String, dynamic> json) => CricketMatch(
    id: json['id'] as String,
    title: json['title'] as String,
    creatorPlayerId: json['creatorPlayerId'] as String,
    scoringMode: ScoringMode.values.byName(json['scoringMode'] as String),
    ballLimit: json['ballLimit'] as int,
    participantIds: List<String>.from(json['participantIds'] as List),
    createdAt: DateTime.parse(json['createdAt'] as String),
    originToken: json['originToken'] as String?,
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.tryParse(json['startedAt'].toString()),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.tryParse(json['completedAt'].toString()),
    status: MatchStatus.values.byName(json['status'] as String),
    winnerMetric: MatchWinnerMetric.values.byName(
      json['winnerMetric'] as String? ?? MatchWinnerMetric.overallPoints.name,
    ),
    trackerPlayerId: json['trackerPlayerId'] as String?,
    controllerUid: json['controllerUid'] as String?,
    controllerPlayerId: json['controllerPlayerId'] as String?,
    controllerLeaseUntil: json['controllerLeaseUntil'] == null
        ? null
        : DateTime.tryParse(json['controllerLeaseUntil'].toString()),
    revision: json['revision'] as int? ?? 0,
    tieBreakOrder: List<String>.from(
      json['tieBreakOrder'] as List? ?? const [],
    ),
    pointRules: PointRules.fromJson(
      Map<String, dynamic>.from(json['pointRules'] as Map? ?? const {}),
    ),
    pointPresetName: json['pointPresetName'] as String? ?? 'Balanced',
    autoBowlingPlan: json['autoBowlingPlan'] as bool? ?? true,
    orderSource: BattingOrderSource.values.byName(
      json['orderSource'] as String? ?? BattingOrderSource.secretDraw.name,
    ),
    battingOrder: List<String>.from(json['battingOrder'] as List? ?? const []),
    drawPlayerOrder: List<String>.from(
      json['drawPlayerOrder'] as List? ?? json['participantIds'] as List,
    ),
    drawPool: (json['drawPool'] as List? ?? const [])
        .map(
          (value) => DrawCard.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    drawAssignments:
        Map<String, dynamic>.from(
          json['drawAssignments'] as Map? ?? const {},
        ).map(
          (key, value) => MapEntry(
            key,
            DrawAssignment.fromJson(Map<String, dynamic>.from(value as Map)),
          ),
        ),
    bowlingPlan: (json['bowlingPlan'] as List? ?? const [])
        .map(
          (value) =>
              BowlingBlock.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    bowlerChanges: (json['bowlerChanges'] as List? ?? const [])
        .map(
          (value) =>
              BowlerChange.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    auditTrail: (json['auditTrail'] as List? ?? const [])
        .map(
          (value) =>
              MatchAuditEntry.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    events: (json['events'] as List? ?? const [])
        .map(
          (value) =>
              ScoreEvent.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    statsApplied: json['statsApplied'] as bool? ?? false,
  );
}

class TurnState {
  TurnState({required this.playerId});

  final String playerId;
  int runs = 0;
  int extras = 0;
  int legalBalls = 0;
  bool isOut = false;
  bool quickEntry = false;
  DismissalType dismissalType = DismissalType.none;

  bool isComplete(int ballLimit) =>
      quickEntry || isOut || legalBalls >= ballLimit;
}

class PlayerMatchStats {
  PlayerMatchStats({required this.playerId});

  final String playerId;
  int runs = 0;
  int balls = 0;
  bool isOut = false;
  int wickets = 0;
  int catches = 0;
  int directRunOuts = 0;
  int assistedRunOuts = 0;
  int stumpings = 0;
  int points = 0;
}
