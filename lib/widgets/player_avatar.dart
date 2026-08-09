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
    final preset = player.avatarPreset.clamp(1, 5);
    final fallback = Text(
      player.initials,
      style: TextStyle(fontSize: radius * .72, fontWeight: FontWeight.w900),
    );
    final url = player.resolvedAvatarUrl;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Color(player.avatarColor),
      foregroundColor: Colors.white,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: url != null && Uri.tryParse(url)?.isScheme('https') == true
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: fallback),
                )
              : Image.asset(
                  'assets/avatars/avatar_$preset.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: fallback),
                ),
        ),
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
