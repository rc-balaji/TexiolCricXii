import 'package:flutter/material.dart';

import '../domain/player.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.player,
    this.radius = 24,
    this.showClaimState = false,
    super.key,
  });

  final Player player;
  final double radius;
  final bool showClaimState;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Color(player.avatarColor),
      foregroundColor: Colors.white,
      child: Text(
        player.initials,
        style: TextStyle(fontSize: radius * .72, fontWeight: FontWeight.w900),
      ),
    );
    if (!showClaimState || player.claimed) return avatar;
    return Badge(
      backgroundColor: Colors.amber.shade700,
      label: const Icon(Icons.key_rounded, size: 11, color: Colors.white),
      child: avatar,
    );
  }
}
