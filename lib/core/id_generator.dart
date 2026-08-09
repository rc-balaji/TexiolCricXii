import 'dart:math';

class IdGenerator {
  IdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String playerId() => 'TXP-${_segment(6)}';
  String gangId() => 'TXG-${_segment(5)}';
  String matchId() => 'TXM-${_segment(6)}';
  String eventId() =>
      'EVT-${DateTime.now().microsecondsSinceEpoch}-${_segment(3)}';
  String cardId() => 'CARD-${_segment(8)}';

  String temporaryPassword() => '${_segment(4)}-${_segment(4)}';

  String _segment(int length) => List.generate(
    length,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();
}
