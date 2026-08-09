import 'enums.dart';

class PointRules {
  const PointRules({
    this.run = 1,
    this.wicket = 20,
    this.catchPoint = 10,
    this.directRunOut = 15,
    this.assistedRunOut = 8,
    this.stumping = 12,
    this.notOutBonus = 5,
  });

  final int run;
  final int wicket;
  final int catchPoint;
  final int directRunOut;
  final int assistedRunOut;
  final int stumping;
  final int notOutBonus;

  Map<String, int> toJson() => {
    'run': run,
    'wicket': wicket,
    'catchPoint': catchPoint,
    'directRunOut': directRunOut,
    'assistedRunOut': assistedRunOut,
    'stumping': stumping,
    'notOutBonus': notOutBonus,
  };

  factory PointRules.fromJson(Map<String, dynamic> json) => PointRules(
    run: json['run'] as int? ?? 1,
    wicket: json['wicket'] as int? ?? 20,
    catchPoint: json['catchPoint'] as int? ?? 10,
    directRunOut: json['directRunOut'] as int? ?? 15,
    assistedRunOut: json['assistedRunOut'] as int? ?? 8,
    stumping: json['stumping'] as int? ?? 12,
    notOutBonus: json['notOutBonus'] as int? ?? 5,
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
    this.status = MatchStatus.draft,
    this.winnerMetric = MatchWinnerMetric.overallPoints,
    this.trackerPlayerId,
    this.pointRules = const PointRules(),
    List<String>? battingOrder,
    List<DrawCard>? drawPool,
    Map<String, DrawAssignment>? drawAssignments,
    List<ScoreEvent>? events,
    this.statsApplied = false,
  }) : battingOrder = battingOrder ?? <String>[],
       drawPool = drawPool ?? <DrawCard>[],
       drawAssignments = drawAssignments ?? <String, DrawAssignment>{},
       events = events ?? <ScoreEvent>[];

  final String id;
  String title;
  final String creatorPlayerId;
  ScoringMode scoringMode;
  int ballLimit;
  final DateTime createdAt;
  MatchStatus status;
  MatchWinnerMetric winnerMetric;
  String? trackerPlayerId;
  PointRules pointRules;
  final List<String> participantIds;
  final List<String> battingOrder;
  final List<DrawCard> drawPool;
  final Map<String, DrawAssignment> drawAssignments;
  final List<ScoreEvent> events;
  bool statsApplied;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'creatorPlayerId': creatorPlayerId,
    'scoringMode': scoringMode.name,
    'ballLimit': ballLimit,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'winnerMetric': winnerMetric.name,
    'trackerPlayerId': trackerPlayerId,
    'pointRules': pointRules.toJson(),
    'participantIds': participantIds,
    'battingOrder': battingOrder,
    'drawPool': drawPool.map((card) => card.toJson()).toList(),
    'drawAssignments': drawAssignments.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
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
    status: MatchStatus.values.byName(json['status'] as String),
    winnerMetric: MatchWinnerMetric.values.byName(
      json['winnerMetric'] as String? ?? MatchWinnerMetric.overallPoints.name,
    ),
    trackerPlayerId: json['trackerPlayerId'] as String?,
    pointRules: PointRules.fromJson(
      Map<String, dynamic>.from(json['pointRules'] as Map? ?? const {}),
    ),
    battingOrder: List<String>.from(json['battingOrder'] as List? ?? const []),
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
