import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../domain/enums.dart';
import '../domain/player.dart';

/// Loads custom avatar bytes without ever exposing the owner's source URL to
/// another player. New avatars are stored byte-for-byte in deterministic
/// Firestore chunks; legacy base64 thumbnails remain readable as a fallback.
class AvatarImageRepository {
  AvatarImageRepository._();

  static const int maxAvatarBytes = 8 * 1024 * 1024;
  static final Map<String, Future<Uint8List?>> _blobCache =
      <String, Future<Uint8List?>>{};

  static Future<Uint8List?> loadCustomBytes(Player player) async {
    if (player.avatarSource != AvatarSource.customUrl) return null;

    final blobId = player.avatarBlobId;
    final chunkCount = player.avatarBlobChunkCount;
    if (blobId != null && blobId.isNotEmpty && chunkCount > 0) {
      final key = '${player.id}:$blobId:$chunkCount';
      final bytes = await _blobCache.putIfAbsent(
        key,
        () => _loadBlob(player.id, blobId, chunkCount, player.avatarBlobByteLength),
      );
      if (bytes != null) return bytes;
      _blobCache.remove(key);
    }

    final encoded = player.avatarImageBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return base64Decode(encoded);
      } on FormatException {
        // Continue to the owner-only source URL fallback.
      }
    }

    final url = player.resolvedAvatarUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return _downloadPrivateSource(uri);
    }
    return null;
  }

  static Future<Uint8List?> _loadBlob(
    String playerId,
    String blobId,
    int chunkCount,
    int? expectedBytes,
  ) async {
    if (chunkCount <= 0 || chunkCount > 32) return null;
    if (expectedBytes != null && expectedBytes > maxAvatarBytes) return null;
    try {
      final firestore = FirebaseFirestore.instance;
      final refs = List.generate(
        chunkCount,
        (index) => firestore
            .collection('players')
            .doc(playerId)
            .collection('avatarChunks')
            .doc(_chunkId(blobId, index)),
      );
      final snapshots = await Future.wait(refs.map((ref) => ref.get()));
      final builder = BytesBuilder(copy: false);
      var total = 0;
      for (var index = 0; index < snapshots.length; index++) {
        final data = snapshots[index].data();
        if (data == null || data['blobId']?.toString() != blobId) return null;
        final encoded = data['data']?.toString();
        if (encoded == null || encoded.isEmpty) return null;
        final part = base64Decode(encoded);
        total += part.length;
        if (total > maxAvatarBytes) return null;
        builder.add(part);
      }
      final bytes = builder.takeBytes();
      if (expectedBytes != null && bytes.length != expectedBytes) return null;
      if (sha256.convert(bytes).toString() != blobId) return null;
      return bytes;
    } on Object {
      return null;
    }
  }

  static Future<Uint8List?> _downloadPrivateSource(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.userAgentHeader, 'CricXii');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (response.contentLength > maxAvatarBytes) return null;
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        total += chunk.length;
        if (total > maxAvatarBytes) return null;
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _chunkId(String blobId, int index) =>
      '${blobId}_${index.toString().padLeft(3, '0')}';
}
