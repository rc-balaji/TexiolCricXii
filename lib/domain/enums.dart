enum GangRole { leader, coLeader, member }

enum MatchStatus { draft, drawing, live, completed }

enum ScoringMode { ballByBall, quickTotal }

enum MatchWinnerMetric { overallPoints, runs }

enum ScoreEventType { delivery, quickSummary }

enum ExtraType { none, wide, noBall, bye, legBye }

enum DismissalType {
  none,
  bowled,
  caught,
  caughtAndBowled,
  lbw,
  runOutDirect,
  runOutAssisted,
  stumped,
  hitWicket,
  retiredOut,
}

extension GangRoleLabel on GangRole {
  String get label => switch (this) {
    GangRole.leader => 'Leader',
    GangRole.coLeader => 'Co-leader',
    GangRole.member => 'Member',
  };
}

extension ScoringModeLabel on ScoringMode {
  String get label => switch (this) {
    ScoringMode.ballByBall => 'Ball tracker',
    ScoringMode.quickTotal => 'Direct runs',
  };
}

extension DismissalTypeLabel on DismissalType {
  String get label => switch (this) {
    DismissalType.none => 'Not out',
    DismissalType.bowled => 'Bowled',
    DismissalType.caught => 'Caught',
    DismissalType.caughtAndBowled => 'Caught & bowled',
    DismissalType.lbw => 'LBW',
    DismissalType.runOutDirect => 'Run out (direct)',
    DismissalType.runOutAssisted => 'Run out (assisted)',
    DismissalType.stumped => 'Stumped',
    DismissalType.hitWicket => 'Hit wicket',
    DismissalType.retiredOut => 'Retired out',
  };

  bool get creditsBowler => switch (this) {
    DismissalType.bowled ||
    DismissalType.caught ||
    DismissalType.caughtAndBowled ||
    DismissalType.lbw ||
    DismissalType.stumped ||
    DismissalType.hitWicket => true,
    _ => false,
  };
}
