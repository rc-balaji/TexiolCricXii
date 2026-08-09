import 'dart:math';

class IdGenerator {
  IdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Offline fallback only. Official cloud IDs come from the server allocator.
  String playerId() => (100000 + _random.nextInt(900000)).toString();
  String gangId() => 'TXG-${_segment(5)}';
  String matchId() => 'TXM-${_segment(6)}';
  String eventId() =>
      'EVT-${DateTime.now().microsecondsSinceEpoch}-${_segment(3)}';
  String cardId() => 'CARD-${_segment(8)}';

  String temporaryPassword() => List.generate(
    8,
    (_) => _random.nextInt(10),
  ).join();

  String _segment(int length) => List.generate(
    length,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();
}
