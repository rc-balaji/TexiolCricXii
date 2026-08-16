import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/player.dart';
import '../services/avatar_image_repository.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.player,
    this.radius = 24,
    this.enableLongPressPreview = true,
    super.key,
  });

  final Player player;
  final double radius;
  final bool enableLongPressPreview;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Color(player.avatarColor),
      foregroundColor: Colors.white,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: _AvatarImage(player: player, fit: BoxFit.cover),
        ),
      ),
    );
    if (!enableLongPressPreview) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showPhoto(context),
      child: avatar,
    );
  }

  Future<void> _showPhoto(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .94),
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .75,
                maxScale: 5,
                child: Center(
                  child: _AvatarImage(
                    player: player,
                    fit: BoxFit.contain,
                    fullResolution: true,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 64,
              top: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pinch to zoom • drag to inspect',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 8,
              child: IconButton.filledTonal(
                tooltip: 'Close photo',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({
    required this.player,
    required this.fit,
    this.fullResolution = false,
  });

  final Player player;
  final BoxFit fit;
  final bool fullResolution;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        player.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fullResolution ? 48 : 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (player.avatarSource == AvatarSource.customUrl) {
      return FutureBuilder(
        future: AvatarImageRepository.loadCustomBytes(player),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              fit: fit,
              gaplessPlayback: true,
              filterQuality: fullResolution ? FilterQuality.high : FilterQuality.medium,
              errorBuilder: (_, _, _) => fallback,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            final encoded = player.avatarImageBase64;
            if (encoded != null && encoded.isNotEmpty) {
              try {
                return Image.memory(
                  base64Decode(encoded),
                  fit: fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                );
              } on FormatException {
                // Continue to progress/fallback.
              }
            }
            if (!fullResolution) return fallback;
            return const Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return fallback;
        },
      );
    }

    final preset = player.avatarPreset.clamp(1, 5);
    return Image.asset(
      'assets/avatars/avatar_$preset.png',
      fit: fit,
      filterQuality: fullResolution ? FilterQuality.high : FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
