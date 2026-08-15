import 'enums.dart';

T _enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

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

class PrivateAvatar {
  PrivateAvatar({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  final String id;
  String name;
  String url;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PrivateAvatar.fromJson(Map<String, dynamic> json) => PrivateAvatar(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'Custom avatar',
    url: json['url'] as String,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

const builtInBowlingStyles = <String>[
  'Right-arm fast',
  'Right-arm medium',
  'Left-arm fast',
  'Left-arm medium',
  'Off spin',
  'Leg spin',
  'Left-arm orthodox',
  'Left-arm wrist spin',
  'Wicketkeeper only',
  'Does not bowl',
];

const sensitiveProfileFields = <String>[
  'phone',
  'whatsapp',
  'location',
];

class Player {
  Player({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.createdAt,
    this.phoneNumber,
    this.whatsappNumber,
    this.location,
    this.instagramHandle,
    this.facebookUrl,
    this.bio,
    this.dateOfBirth,
    this.publicAge,
    this.battingStyle = BattingStyle.rightHanded,
    List<String>? bowlingStyles,
    this.customBowlingStyle,
    this.avatarSource = AvatarSource.preset,
    this.avatarPreset = 1,
    this.avatarUrl,
    this.avatarImageBase64,
    this.avatarImageSourceHash,
    List<PrivateAvatar>? privateAvatars,
    Map<String, ProfileVisibility>? contactVisibility,
    Map<String, List<String>>? contactAudienceIds,
    this.archived = false,
    this.gangId,
    this.gangRole,
    List<String>? friendIds,
    PlayerStats? stats,
    PlayerStats? teamStats,
  }) : bowlingStyles = bowlingStyles ?? <String>['Right-arm medium'],
       privateAvatars = privateAvatars ?? <PrivateAvatar>[],
       contactVisibility = contactVisibility ??
           <String, ProfileVisibility>{
             for (final field in sensitiveProfileFields)
               field: ProfileVisibility.onlyMe,
           },
       contactAudienceIds = contactAudienceIds ?? <String, List<String>>{},
       friendIds = friendIds ?? <String>[],
       stats = stats ?? PlayerStats(),
       teamStats = teamStats ?? PlayerStats();

  final String id;
  String name;
  String? phoneNumber;
  String? whatsappNumber;
  String? location;
  String? instagramHandle;
  String? facebookUrl;
  String? bio;
  DateTime? dateOfBirth;
  int? publicAge;
  BattingStyle battingStyle;
  final List<String> bowlingStyles;
  String? customBowlingStyle;
  AvatarSource avatarSource;
  int avatarPreset;
  String? avatarUrl;
  String? avatarImageBase64;
  String? avatarImageSourceHash;
  final List<PrivateAvatar> privateAvatars;
  final Map<String, ProfileVisibility> contactVisibility;
  final Map<String, List<String>> contactAudienceIds;
  int avatarColor;
  bool archived;
  String? gangId;
  GangRole? gangRole;
  final DateTime createdAt;
  final List<String> friendIds;
  final PlayerStats stats;
  final PlayerStats teamStats;

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return publicAge;
    final today = DateTime.now();
    var value = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      value--;
    }
    return value < 0 ? null : value;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String? get resolvedAvatarUrl => switch (avatarSource) {
    AvatarSource.preset => null,
    AvatarSource.customUrl => avatarUrl,
  };

  bool canViewField(
    String field, {
    required String? viewerPlayerId,
    required bool areFriends,
  }) {
    if (viewerPlayerId == id) return true;
    final visibility =
        contactVisibility[field] ?? ProfileVisibility.onlyMe;
    final audience = contactAudienceIds[field] ?? const <String>[];
    return switch (visibility) {
      ProfileVisibility.onlyMe => false,
      ProfileVisibility.friends => areFriends,
      ProfileVisibility.selectedFriends =>
        areFriends &&
          viewerPlayerId != null &&
          audience.contains(viewerPlayerId),
      ProfileVisibility.everyoneExceptSelected =>
        viewerPlayerId == null || !audience.contains(viewerPlayerId),
      ProfileVisibility.everyone => true,
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'whatsappNumber': whatsappNumber,
    'location': location,
    'instagramHandle': instagramHandle,
    'facebookUrl': facebookUrl,
    'bio': bio,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'publicAge': age,
    'battingStyle': battingStyle.name,
    'bowlingStyles': bowlingStyles,
    'customBowlingStyle': customBowlingStyle,
    'avatarSource': avatarSource.name,
    'avatarPreset': avatarPreset,
    'avatarUrl': avatarUrl,
    'avatarImageBase64': avatarImageBase64,
    'avatarImageSourceHash': avatarImageSourceHash,
    'privateAvatars': privateAvatars.map((value) => value.toJson()).toList(),
    'contactVisibility': contactVisibility.map(
      (key, value) => MapEntry(key, value.name),
    ),
    'contactAudienceIds': contactAudienceIds,
    'avatarColor': avatarColor,
    'archived': archived,
    'gangId': gangId,
    'gangRole': gangRole?.name,
    'createdAt': createdAt.toIso8601String(),
    'friendIds': friendIds,
    'stats': stats.toJson(),
    'teamStats': teamStats.toJson(),
  };

  Map<String, Object?> toPublicJson() => {
    'playerId': id,
    'name': name,
    'bio': bio,
    'age': age,
    'instagramHandle': instagramHandle,
    'facebookUrl': facebookUrl,
    'battingStyle': battingStyle.name,
    'bowlingStyles': bowlingStyles,
    'customBowlingStyle': customBowlingStyle,
    'avatarSource': avatarSource.name,
    'avatarPreset': avatarPreset,
    'avatarUrl': null,
    'avatarImageBase64': avatarSource == AvatarSource.customUrl ? avatarImageBase64 : null,
    'archived': archived,
    'gangId': gangId,
    'gangRole': gangRole?.name,
    'joinedAt': createdAt.toIso8601String(),
    'stats': stats.toJson(),
    'teamStats': teamStats.toJson(),
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    final visibilityRaw = Map<String, dynamic>.from(
      json['contactVisibility'] as Map? ?? const {},
    );
    final audienceRaw = Map<String, dynamic>.from(
      json['contactAudienceIds'] as Map? ?? const {},
    );
    final privateAvatarRaw = json['privateAvatars'] as List?;
    final privateAvatars = privateAvatarRaw != null
        ? privateAvatarRaw
              .map(
                (value) => PrivateAvatar.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList()
        : (json['privateAvatarUrls'] as List? ?? const [])
              .asMap()
              .entries
              .map(
                (entry) => PrivateAvatar(
                  id: 'legacy-${entry.key + 1}',
                  name: 'Custom avatar ${entry.key + 1}',
                  url: entry.value.toString(),
                  createdAt: DateTime.now(),
                ),
              )
              .toList();
    return Player(
      id: json['id'].toString(),
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      whatsappNumber: json['whatsappNumber'] as String?,
      location: json['location'] as String?,
      instagramHandle: json['instagramHandle'] as String?,
      facebookUrl: json['facebookUrl'] as String?,
      bio: json['bio'] as String?,
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      publicAge: (json['publicAge'] ?? json['age']) as int?,
      battingStyle: _enumOr(
        BattingStyle.values,
        json['battingStyle'],
        BattingStyle.rightHanded,
      ),
      bowlingStyles: List<String>.from(
        json['bowlingStyles'] as List? ?? const ['Right-arm medium'],
      ),
      customBowlingStyle: json['customBowlingStyle'] as String?,
      avatarSource: _enumOr(
        AvatarSource.values,
        json['avatarSource'],
        AvatarSource.preset,
      ),
      avatarPreset: json['avatarPreset'] as int? ?? 1,
      avatarUrl: json['avatarUrl'] as String?,
      avatarImageBase64: json['avatarImageBase64'] as String?,
      avatarImageSourceHash: json['avatarImageSourceHash'] as String?,
      privateAvatars: privateAvatars,
      contactVisibility: visibilityRaw.map(
        (key, value) => MapEntry(
          key,
          _enumOr(
            ProfileVisibility.values,
            value,
            ProfileVisibility.onlyMe,
          ),
        ),
      ),
      contactAudienceIds: audienceRaw.map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      avatarColor: json['avatarColor'] as int? ?? 0xFF19C37D,
      archived: json['archived'] as bool? ?? false,
      gangId: json['gangId'] as String?,
      gangRole: json['gangRole'] == null
          ? null
          : _enumOr(GangRole.values, json['gangRole'], GangRole.member),
      createdAt: DateTime.parse(json['createdAt'] as String),
      friendIds: List<String>.from(json['friendIds'] as List? ?? const []),
      stats: PlayerStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
      ),
      teamStats: PlayerStats.fromJson(
        Map<String, dynamic>.from(json['teamStats'] as Map? ?? const {}),
      ),
    );
  }
}
