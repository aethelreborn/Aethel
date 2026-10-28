import 'package:aethel/data/data_actions.dart';
import 'package:aethel/features/premium/premium_controller.dart';
import 'package:flutter_test/flutter_test.dart';

PremiumState _state({
  PremiumStatus status = PremiumStatus.ready,
  bool isPremium = false,
  PremiumPlanLimits limits = PremiumPlanLimits.free,
}) {
  return PremiumState(
    status: status,
    isPremium: isPremium,
    plan: isPremium ? 'premium' : 'free',
    limits: limits,
  );
}

void main() {
  group('canCreateWithState', () {
    test('blocks vault creates exactly at the free cap', () {
      final state = _state();
      expect(
        canCreateWithState(state, PremiumKind.vaultItem, 14),
        isTrue,
      );
      expect(
        canCreateWithState(state, PremiumKind.vaultItem, 15),
        isFalse,
      );
    });

    test('blocks bills at 5 and schedules at 1', () {
      final state = _state();
      expect(canCreateWithState(state, PremiumKind.billingItem, 4), isTrue);
      expect(canCreateWithState(state, PremiumKind.billingItem, 5), isFalse);
      expect(canCreateWithState(state, PremiumKind.schedule, 0), isTrue);
      expect(canCreateWithState(state, PremiumKind.schedule, 1), isFalse);
    });

    test('allows every create once premium, at any count', () {
      final state =
          _state(isPremium: true, limits: PremiumPlanLimits.unlimited);
      expect(canCreateWithState(state, PremiumKind.vaultItem, 999), isTrue);
      expect(canCreateWithState(state, PremiumKind.billingItem, 999), isTrue);
      expect(canCreateWithState(state, PremiumKind.schedule, 999), isTrue);
    });

    test('never blocks while the plan is unknown (loading or error)', () {
      for (final status in [PremiumStatus.loading, PremiumStatus.error]) {
        final state = _state(status: status);
        expect(
          canCreateWithState(state, PremiumKind.vaultItem, 999),
          isTrue,
          reason: 'creates must not be blocked on $status',
        );
      }
    });

    test('treats a null limit from the server as unlimited', () {
      final state = _state(
        limits: const PremiumPlanLimits(
          vaultItems: null,
          billingItems: null,
          schedules: null,
        ),
      );
      expect(canCreateWithState(state, PremiumKind.vaultItem, 999), isTrue);
      expect(canCreateWithState(state, PremiumKind.billingItem, 999), isTrue);
      expect(canCreateWithState(state, PremiumKind.schedule, 999), isTrue);
    });
  });

  group('FreeLimitExceededException', () {
    test('carries a plain message per kind', () {
      expect(
        const FreeLimitExceededException(PremiumKind.vaultItem).message,
        contains('15 vault entries'),
      );
      expect(
        const FreeLimitExceededException(PremiumKind.billingItem).message,
        contains('5 bills'),
      );
      expect(
        const FreeLimitExceededException(PremiumKind.schedule).message,
        contains('1 focus schedule'),
      );
    });
  });
}
