String easyLoginUsername(String value) {
  final username = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll('@', '');
  if (username.length < 2) {
    throw ArgumentError('Enter a player name using at least two characters.');
  }
  return username;
}

String easyLoginEmail(String value) => '${easyLoginUsername(value)}@gmail.com';

const easyLoginPassword = '12345678';
