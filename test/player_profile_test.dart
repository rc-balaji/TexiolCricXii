import 'dart:convert';
import 'dart:math';

import 'package:crixx/core/id_generator.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh account Player IDs contain exactly eight digits', () {
    final generator = IdGenerator(Random(42));
    final ids = List.generate(1000, (_) => generator.playerId());

    expect(ids.every((value) => RegExp(r'^\d{8}$').hasMatch(value)), isTrue);
  });

  test('profile JSON preserves playing styles, privacy and public age', () {
    final player = Player(
      id: '100245',
      name: 'Dinesh',
      avatarColor: 0xFF19C37D,
      createdAt: DateTime.utc(2026, 8, 9),
      publicAge: 24,
      phoneNumber: '9876543210',
      battingStyle: BattingStyle.leftHanded,
      bowlingStyles: ['Leg spin', 'Right-arm medium'],
      contactVisibility: {
        'phone': ProfileVisibility.selectedFriends,
      },
      contactAudienceIds: {
        'phone': ['100246'],
      },
    );

    final restored = Player.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(player.toJson())) as Map,
      ),
    );

    expect(restored.age, 24);
    expect(restored.battingStyle, BattingStyle.leftHanded);
    expect(restored.bowlingStyles, contains('Leg spin'));
    expect(
      restored.canViewField(
        'phone',
        viewerPlayerId: '100246',
        areFriends: true,
      ),
      isTrue,
    );
    expect(
      restored.canViewField(
        'phone',
        viewerPlayerId: '100247',
        areFriends: true,
      ),
      isFalse,
    );
    expect(
      restored.canViewField(
        'phone',
        viewerPlayerId: '100246',
        areFriends: false,
      ),
      isFalse,
    );
  });

  test('public player document excludes private contact and custom avatar URL', () {
    final player = Player(
      id: '100245',
      name: 'Dinesh',
      avatarColor: 0xFF19C37D,
      createdAt: DateTime.utc(2026, 8, 9),
      phoneNumber: '9876543210',
      avatarSource: AvatarSource.customUrl,
      avatarUrl: 'https://example.com/private-avatar.png',
      avatarImageBase64: base64Encode(<int>[137, 80, 78, 71]),
      avatarImageSourceHash: 'private-source-hash',
      privateAvatars: [
        PrivateAvatar(
          id: 'avatar-abc123',
          name: 'Night match',
          url: 'https://example.com/private-avatar.png',
          createdAt: DateTime.utc(2026, 8, 9),
        ),
      ],
    );

    final public = player.toPublicJson();
    expect(public.containsKey('phoneNumber'), isFalse);
    expect(public.containsKey('privateAvatars'), isFalse);
    expect(public['avatarUrl'], isNull);
    expect(public['avatarImageBase64'], isNotNull);
    expect(public.containsKey('avatarImageSourceHash'), isFalse);
  });

  test('private avatars preserve generated ID, name and URL', () {
    final player = Player(
      id: '100245',
      name: 'Dinesh',
      avatarColor: 0xFF19C37D,
      createdAt: DateTime.utc(2026, 8, 9),
      avatarImageBase64: base64Encode(<int>[1, 2, 3, 4]),
      avatarImageSourceHash: 'hash-123',
      privateAvatars: [
        PrivateAvatar(
          id: 'avatar-abc123',
          name: 'Night match',
          url: 'https://example.com/night.png',
          createdAt: DateTime.utc(2026, 8, 9),
        ),
      ],
    );
    final restored = Player.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(player.toJson())) as Map,
      ),
    );
    expect(restored.privateAvatars.single.id, 'avatar-abc123');
    expect(restored.privateAvatars.single.name, 'Night match');
    expect(restored.privateAvatars.single.url, 'https://example.com/night.png');
    expect(restored.avatarImageBase64, base64Encode(<int>[1, 2, 3, 4]));
    expect(restored.avatarImageSourceHash, 'hash-123');
  });
}
