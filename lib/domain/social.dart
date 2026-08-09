import 'enums.dart';

class FriendRequest {
  FriendRequest({
    required this.id,
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.createdAt,
    this.status = FriendRequestStatus.pending,
    this.respondedAt,
  });

  final String id;
  final String fromPlayerId;
  final String toPlayerId;
  FriendRequestStatus status;
  final DateTime createdAt;
  DateTime? respondedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'fromPlayerId': fromPlayerId,
    'toPlayerId': toPlayerId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    fromPlayerId: json['fromPlayerId'] as String,
    toPlayerId: json['toPlayerId'] as String,
    status: FriendRequestStatus.values.byName(
      json['status'] as String? ?? FriendRequestStatus.pending.name,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    respondedAt: json['respondedAt'] == null
        ? null
        : DateTime.parse(json['respondedAt'] as String),
  );
}

class CricNotification {
  CricNotification({
    required this.id,
    required this.playerId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.referenceId,
    this.read = false,
  });

  final String id;
  final String playerId;
  final NotificationType type;
  final String title;
  final String body;
  final String? referenceId;
  final DateTime createdAt;
  bool read;

  Map<String, Object?> toJson() => {
    'id': id,
    'playerId': playerId,
    'type': type.name,
    'title': title,
    'body': body,
    'referenceId': referenceId,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  factory CricNotification.fromJson(Map<String, dynamic> json) =>
      CricNotification(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        type: NotificationType.values.byName(
          json['type'] as String? ?? NotificationType.system.name,
        ),
        title: json['title'] as String,
        body: json['body'] as String,
        referenceId: json['referenceId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool? ?? false,
      );
}
