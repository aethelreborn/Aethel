import 'package:flutter/material.dart';

import '../data/models.dart';

IconData vaultIcon(VaultType type) {
  return switch (type) {
    VaultType.password => Icons.key_rounded,
    VaultType.card => Icons.credit_card_rounded,
    VaultType.note => Icons.notes_rounded,
    VaultType.identity => Icons.badge_outlined,
    VaultType.secureNote => Icons.shield_outlined,
  };
}

String vaultTypeDescription(VaultType type) {
  return switch (type) {
    VaultType.password => 'Login and password',
    VaultType.card => 'Payment card',
    VaultType.note => 'Private note',
    VaultType.identity => 'Identity details',
    VaultType.secureNote => 'Secure note',
  };
}
