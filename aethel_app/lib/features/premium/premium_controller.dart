import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../data/data_actions.dart';

enum PremiumStatus { loading, ready, error }

enum BillingPeriod { monthly, yearly }

extension BillingPeriodApi on BillingPeriod {
  String get apiValue => name;
}

/// Plan caps from the server. A null value means unlimited.
class PremiumPlanLimits {
  const PremiumPlanLimits({this.vaultItems, this.billingItems, this.schedules});

  final int? vaultItems;
  final int? billingItems;
  final int? schedules;

  /// The free tier before the first successful plan fetch, and the display
  /// fallback when the plan endpoint cannot be reached.
  static const free = PremiumPlanLimits(
    vaultItems: 15,
    billingItems: 5,
    schedules: 1,
  );

  static const unlimited = PremiumPlanLimits();

  int? of(PremiumKind kind) {
    return switch (kind) {
      PremiumKind.vaultItem => vaultItems,
      PremiumKind.billingItem => billingItems,
      PremiumKind.schedule => schedules,
    };
  }
}

class PremiumState {
  const PremiumState({
    this.status = PremiumStatus.loading,
    this.plan = 'free',
    this.expiresAt,
    this.isPremium = false,
    this.limits = PremiumPlanLimits.free,
    this.pendingOrderId,
    this.confirming = false,
    this.error,
  });

  final PremiumStatus status;

  /// 'free' or 'premium', per the frozen payments contract.
  final String plan;
  final DateTime? expiresAt;
  final bool isPremium;
  final PremiumPlanLimits limits;

  /// Set once checkout returned an order, cleared when verify confirms
  /// premium. Survives app restarts via shared preferences.
  final String? pendingOrderId;

  /// True while POST /payments/verify is in flight.
  final bool confirming;

  /// Last plan-fetch error, for display only. Never used for gating.
  final String? error;

  PremiumState copyWith({
    PremiumStatus? status,
    String? plan,
    DateTime? expiresAt,
    bool? isPremium,
    PremiumPlanLimits? limits,
    Object? pendingOrderId = _unset,
    bool? confirming,
    Object? error = _unset,
  }) {
    return PremiumState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      expiresAt: expiresAt ?? this.expiresAt,
      isPremium: isPremium ?? this.isPremium,
      limits: limits ?? this.limits,
      pendingOrderId: identical(pendingOrderId, _unset)
          ? this.pendingOrderId
          : pendingOrderId as String?,
      confirming: confirming ?? this.confirming,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

const Object _unset = Object();

class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
  });

  final String orderId;
  final String checkoutUrl;
  final String amount;
  final String currency;
}

/// Whether a create may proceed.
///
/// Creates are only blocked when we hold a definitive, successful plan
/// response saying the account is free and already at the cap. While the
/// plan is unknown (loading, or the endpoint is unreachable) creates are
/// allowed: a failed plan check must never lock a user out of their own
/// vault offline. The backend enforces the same caps authoritatively.
bool canCreateWithState(
  PremiumState state,
  PremiumKind kind,
  int currentCount,
) {
  if (state.status != PremiumStatus.ready) return true;
  if (state.isPremium) return true;
  final limit = state.limits.of(kind);
  if (limit == null) return true;
  return currentCount < limit;
}

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController(this._prefs)
      : super(PremiumState(pendingOrderId: _readPending(_prefs))) {
    SyncService.instance.onFreeLimitReached = _onFreeLimitReached;
    unawaited(refresh());
  }

  static const pendingOrderKey = 'aethel.pay.pendingOrderId';

  final SharedPreferences _prefs;
  final ApiClient _api = ApiClient.instance;

  static String? _readPending(SharedPreferences prefs) {
    return prefs.getString(pendingOrderKey);
  }

  void _onFreeLimitReached() {
    unawaited(refresh());
  }

  /// Re-reads the plan. If a checkout order is still pending, verify it
  /// first — this is the "user came back from the browser" path.
  Future<void> refresh() async {
    if (!_api.hasSession) return;
    final pending = state.pendingOrderId;
    if (pending != null) {
      try {
        final unlocked = await _verify(pending);
        if (unlocked) return;
      } on ApiException {
        // Verify unreachable (e.g. app resumed offline). Fall through to the
        // plan fetch, which reports its own status; the pending order stays
        // stored for the next attempt.
      }
    }
    try {
      final data = await _api.get('/payments/plan');
      state = state.copyWith(
        status: PremiumStatus.ready,
        plan: data['plan']?.toString() ?? 'free',
        isPremium: data['isPremium'] == true,
        expiresAt: _parseDate(data['expiresAt']),
        limits: _limitsFrom(data['limits']),
        error: null,
      );
    } on ApiException catch (ex) {
      // Display stays free with default limits; creates stay unblocked.
      state = state.copyWith(status: PremiumStatus.error, error: ex.message);
    } catch (_) {
      state = state.copyWith(
        status: PremiumStatus.error,
        error: 'The plan could not be fetched.',
      );
    }
  }

  /// POST /payments/checkout. Stores the order id as pending before
  /// returning so an app kill mid-payment is still recoverable.
  Future<CheckoutOrder> startCheckout(BillingPeriod period) async {
    final data = await _api.post(
      '/payments/checkout',
      data: {'period': period.apiValue},
    );
    final orderId = data['orderId']?.toString() ?? '';
    final checkoutUrl = data['checkoutUrl']?.toString() ?? '';
    if (orderId.isEmpty || checkoutUrl.isEmpty) {
      throw const ApiException(
        'The payment gateway did not return a checkout link.',
      );
    }
    await _prefs.setString(pendingOrderKey, orderId);
    state = state.copyWith(pendingOrderId: orderId);
    return CheckoutOrder(
      orderId: orderId,
      checkoutUrl: checkoutUrl,
      amount: data['amount']?.toString() ?? '',
      currency: data['currency']?.toString() ?? 'INR',
    );
  }

  /// POST /payments/verify. Throws [ApiException] on network failure so the
  /// sheet can tell "still pending" apart from "could not reach the server".
  Future<bool> confirmPayment(String orderId) async {
    final unlocked = await _verify(orderId);
    if (!unlocked && state.status != PremiumStatus.ready) {
      // Verify answered but the plan block never loaded; catch it up.
      await refresh();
    }
    return unlocked;
  }

  Future<bool> _verify(String orderId) async {
    state = state.copyWith(confirming: true);
    try {
      final data = await _api.post(
        '/payments/verify',
        data: {'orderId': orderId},
      );
      final unlocked = data['isPremium'] == true;
      state = state.copyWith(
        confirming: false,
        status: PremiumStatus.ready,
        plan: data['plan']?.toString() ?? (unlocked ? 'premium' : 'free'),
        isPremium: unlocked,
        expiresAt: _parseDate(data['expiresAt']),
        limits: unlocked ? PremiumPlanLimits.unlimited : state.limits,
        pendingOrderId: unlocked ? null : state.pendingOrderId,
        error: null,
      );
      if (unlocked) await _prefs.remove(pendingOrderKey);
      return unlocked;
    } catch (_) {
      state = state.copyWith(confirming: false);
      rethrow;
    }
  }

  @override
  void dispose() {
    if (identical(
        SyncService.instance.onFreeLimitReached, _onFreeLimitReached)) {
      SyncService.instance.onFreeLimitReached = null;
    }
    super.dispose();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static PremiumPlanLimits _limitsFrom(dynamic raw) {
    if (raw is! Map) return PremiumPlanLimits.unlimited;
    return PremiumPlanLimits(
      vaultItems: _limit(raw['vaultItems'] ?? raw['vault_items']),
      billingItems: _limit(raw['billingItems'] ?? raw['billing_items']),
      schedules: _limit(raw['schedules']),
    );
  }

  static int? _limit(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

final premiumControllerProvider =
    StateNotifierProvider<PremiumController, PremiumState>((ref) {
  return PremiumController(ref.watch(sharedPreferencesProvider));
});
