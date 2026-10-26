import 'dart:typed_data';

import 'package:aethel/core/crypto/crypto_service.dart';
import 'package:aethel/core/utils/password_tools.dart';
import 'package:aethel/data/models.dart';
import 'package:aethel/widgets/password_strength.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CryptoService', () {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));

    test('round-trips encrypted text', () {
      final encrypted = CryptoService.encryptString('private ledger', key);

      expect(encrypted.iv, isNotEmpty);
      expect(encrypted.ciphertext, isNot(contains('private ledger')));
      expect(CryptoService.decryptString(encrypted.ciphertext, key),
          'private ledger');
    });

    test('rejects the wrong key', () {
      final encrypted = CryptoService.encryptString('private ledger', key);
      final wrongKey = Uint8List.fromList(List<int>.filled(32, 9));

      expect(
        () => CryptoService.decryptString(encrypted.ciphertext, wrongKey),
        throwsA(anything),
      );
    });

    test('derives stable verifier and vault key material', () async {
      final first = await CryptoService.deriveKeys(
        email: 'ada@example.com',
        masterPassword: 'a long master password',
      );
      final second = await CryptoService.deriveKeys(
        email: ' ADA@example.com ',
        masterPassword: 'a long master password',
      );

      expect(first.verifier, second.verifier);
      expect(first.vaultKey, orderedEquals(second.vaultKey));
      expect(first.verifier, isNot(contains('=')));
      expect(first.vaultKey, hasLength(32));
    });
  });

  group('password tools', () {
    test('honours the requested length and minimum', () {
      expect(generatePassword(length: 24), hasLength(24));
      expect(generatePassword(length: 1), hasLength(4));
      expect(
        generatePassword(
          length: 32,
          uppercase: false,
          numbers: false,
          symbols: false,
        ),
        hasLength(32),
      );
    });

    test('scores strong passwords', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('short'), 0);
      expect(passwordStrength('abcdefghij'), 1);
      expect(passwordStrength('Correct-Horse-9-Battery'), 4);
      expect(passwordStrengthLabel(4), 'Excellent');
    });
  });

  group('models', () {
    test('serializes vault items and billing cycles', () {
      final now = DateTime.utc(2026, 10, 25);
      final item = VaultItem(
        id: 'vault-1',
        title: 'Bank',
        type: VaultType.password,
        username: 'ada',
        password: 'secret',
        favorite: true,
        createdAt: now,
        updatedAt: now,
      );
      final decoded = VaultItem.fromJson(item.toJson());

      expect(decoded.title, 'Bank');
      expect(decoded.type, VaultType.password);
      expect(decoded.favorite, isTrue);
      expect(decoded.subtitle, 'ada');

      final next = BillingCycle.monthly.advance(DateTime.utc(2026, 1, 31));
      expect(next.month, DateTime.february);
      expect(next.day, 28);
    });
  });

  group('password strength meter', () {
    testWidgets('moves with every keystroke, without a submit', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller),
                PasswordStrengthMeter(controller: controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text(PasswordStrengthBar.hintFor(0)), findsOneWidget);
      expect(find.text(passwordStrengthLabel(0)), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcdefghij');
      await tester.pump();

      expect(find.text(PasswordStrengthBar.hintFor(1)), findsOneWidget);
      expect(find.text(passwordStrengthLabel(1)), findsOneWidget);
      expect(find.text(PasswordStrengthBar.hintFor(0)), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'Correct-Horse-9-Battery',
      );
      await tester.pump();

      expect(find.text(PasswordStrengthBar.hintFor(4)), findsOneWidget);
      expect(find.text(passwordStrengthLabel(4)), findsOneWidget);
    });
  });
}
