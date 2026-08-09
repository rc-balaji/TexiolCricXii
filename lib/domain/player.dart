import 'enums.dart';

class PlayerStats {
  PlayerStats({
    this.matches = 0,
    this.runs = 0,
    this.balls = 0,
    this.outs = 0,
    this.wickets = 0,
    this.catches = 0,
    this.directRunOuts = 0,
    this.assistedRunOuts = 0,
    this.stumpings = 0,
    this.points = 0,
    this.wins = 0,
  });

  int matches;
  int runs;
  int balls;
  int outs;
  int wickets;
  int catches;
  int directRunOuts;
  int assistedRunOuts;
  int stumpings;
  int points;
  int wins;

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;

  Map<String, Object> toJson() => {
    'matches': matches,
    'runs': runs,
    'balls': balls,
    'outs': outs,
    'wickets': wickets,
    'catches': catches,
    'directRunOuts': directRunOuts,
    'assistedRunOuts': assistedRunOuts,
    'stumpings': stumpings,
    'points': points,
    'wins': wins,
  };

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    matches: json['matches'] as int? ?? 0,
    runs: json['runs'] as int? ?? 0,
    balls: json['balls'] as int? ?? 0,
    outs: json['outs'] as int? ?? 0,
    wickets: json['wickets'] as int? ?? 0,
    catches: json['catches'] as int? ?? 0,
    directRunOuts: json['directRunOuts'] as int? ?? 0,
    assistedRunOuts: json['assistedRunOuts'] as int? ?? 0,
    stumpings: json['stumpings'] as int? ?? 0,
    points: json['points'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
  );
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.createdAt,
    this.email,
    this.instagramHandle,
    this.claimSecretHash,
    this.claimSecretSalt,
    this.claimed = false,
    this.gangId,
    this.gangRole,
    List<String>? friendIds,
    PlayerStats? stats,
  }) : friendIds = friendIds ?? <String>[],
       stats = stats ?? PlayerStats();

  final String id;
  String name;
  String? email;
  String? instagramHandle;
  final String? claimSecretHash;
  final String? claimSecretSalt;
  int avatarColor;
  bool claimed;
  String? gangId;
  GangRole? gangRole;
  final DateTime createdAt;
  final List<String> friendIds;
  final PlayerStats stats;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'instagramHandle': instagramHandle,
    'claimSecretHash': claimSecretHash,
    'claimSecretSalt': claimSecretSalt,
    'avatarColor': avatarColor,
    'claimed': claimed,
    'gangId': gangId,
    'gangRole': gangRole?.name,
    'createdAt': createdAt.toIso8601String(),
    'friendIds': friendIds,
    'stats': stats.toJson(),
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String?,
    instagramHandle: json['instagramHandle'] as String?,
    claimSecretHash: json['claimSecretHash'] as String?,
    claimSecretSalt: json['claimSecretSalt'] as String?,
    avatarColor: json['avatarColor'] as int,
    claimed: json['claimed'] as bool? ?? false,
    gangId: json['gangId'] as String?,
    gangRole: json['gangRole'] == null
        ? null
        : GangRole.values.byName(json['gangRole'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    friendIds: List<String>.from(json['friendIds'] as List? ?? const []),
    stats: PlayerStats.fromJson(
      Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
    ),
  );
}
