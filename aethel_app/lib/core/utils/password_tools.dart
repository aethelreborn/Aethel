import 'dart:math';

const _lower = 'abcdefghijkmnopqrstuvwxyz';
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _digits = '23456789';
const _symbols = r'!@#$%^&*()-_=+[]{};:,.?';

String generatePassword({
  int length = 20,
  bool uppercase = true,
  bool lowercase = true,
  bool numbers = true,
  bool symbols = true,
}) {
  final pools = <String>[
    if (lowercase) _lower,
    if (uppercase) _upper,
    if (numbers) _digits,
    if (symbols) _symbols,
  ];
  if (pools.isEmpty) pools.add(_lower);
  final safeLength = length.clamp(4, 64);
  final random = Random.secure();
  final characters = <String>[
    for (final pool in pools) pool[random.nextInt(pool.length)],
  ];
  final all = pools.join();
  while (characters.length < safeLength) {
    characters.add(all[random.nextInt(all.length)]);
  }
  characters.shuffle(random);
  return characters.join();
}

int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 10) score++;
  if (password.length >= 16) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  return score.clamp(0, 4).toInt();
}

String passwordStrengthLabel(int score) {
  return switch (score) {
    0 => 'Too short',
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Strong',
    _ => 'Excellent',
  };
}
