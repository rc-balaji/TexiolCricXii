enum GangRole { leader, coLeader, member }

enum BattingStyle { rightHanded, leftHanded }

enum AvatarSource { preset, customUrl }

enum ProfileVisibility {
  onlyMe,
  friends,
  selectedFriends,
  everyoneExceptSelected,
  everyone,
}

enum FriendRequestStatus { pending, accepted, rejected, cancelled }

enum NotificationType { friendRequest, friendAccepted, profile, system }

enum MatchStatus { draft, drawing, live, completed }

enum ScoringMode { ballByBall, quickTotal }

enum MatchWinnerMetric { overallPoints, runs }

enum BattingOrderSource { secretDraw, previousRanking }

enum ScoreEventType { delivery, quickSummary }

enum ExtraType { none, wide, noBall, bye, legBye, penalty }

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

extension BattingStyleLabel on BattingStyle {
  String get label => switch (this) {
    BattingStyle.rightHanded => 'Right-hand bat',
    BattingStyle.leftHanded => 'Left-hand bat',
  };
}

extension AvatarSourceLabel on AvatarSource {
  String get label => switch (this) {
    AvatarSource.preset => 'CricXii avatar',
    AvatarSource.customUrl => 'Private URL',
  };
}

extension ProfileVisibilityLabel on ProfileVisibility {
  String get label => switch (this) {
    ProfileVisibility.onlyMe => 'Only me',
    ProfileVisibility.friends => 'All friends',
    ProfileVisibility.selectedFriends => 'Selected friends',
    ProfileVisibility.everyoneExceptSelected => 'Everyone except selected',
    ProfileVisibility.everyone => 'Everyone',
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
