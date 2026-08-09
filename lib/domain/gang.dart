import 'enums.dart';

class Gang {
  Gang({
    required this.id,
    required this.name,
    required this.leaderPlayerId,
    required this.createdAt,
    Map<String, GangRole>? members,
  }) : members = members ?? {leaderPlayerId: GangRole.leader};

  final String id;
  String name;
  String leaderPlayerId;
  final DateTime createdAt;
  final Map<String, GangRole> members;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'leaderPlayerId': leaderPlayerId,
    'createdAt': createdAt.toIso8601String(),
    'members': members.map((key, value) => MapEntry(key, value.name)),
  };

  factory Gang.fromJson(Map<String, dynamic> json) => Gang(
    id: json['id'] as String,
    name: json['name'] as String,
    leaderPlayerId: json['leaderPlayerId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    members: Map<String, dynamic>.from(json['members'] as Map).map(
      (key, value) => MapEntry(key, GangRole.values.byName(value as String)),
    ),
  );
}
