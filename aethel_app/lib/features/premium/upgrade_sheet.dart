import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/page.dart';
import '../../widgets/sheets.dart';
import 'premium_controller.dart';

/// Opens the premium offer. Reachable from a free-tier cap and from
/// Settings; also shows the waiting / active states once a payment is in
/// flight or the account already holds premium.
Future<void> showUpgradeSheet(BuildContext context) {
  return showAethelSheet<void>(
    context: context,
    builder: (_) => const _UpgradeSheet(),
  );
}

class _UpgradeSheet extends ConsumerStatefulWidget {
  const _UpgradeSheet();

  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  BillingPeriod _period = BillingPeriod.yearly;
  bool _busy = false;
  bool _checking = false;
  String? _error;

  Future<void> _checkout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(premiumControllerProvider.notifier)
          .startCheckout(_period);
      final uri = Uri.tryParse(order.checkoutUrl);
      if (uri == null) {
        throw const ApiException(
          'The payment gateway returned an invalid checkout link.',
        );
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const ApiException(
          'The payment page could not be opened in your browser.',
        );
      }
      if (mounted) setState(() => _busy = false);
    } on ApiException catch (ex) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ex.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Checkout could not be started. Try again.';
        });
      }
    }
  }

  Future<void> _checkAgain() async {
    if (_checking) return;
    final orderId = ref.read(premiumControllerProvider).pendingOrderId;
    if (orderId == null) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await ref
          .read(premiumControllerProvider.notifier)
          .confirmPayment(orderId);
    } on ApiException catch (ex) {
      if (mounted) setState(() => _error = ex.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Confirmation could not be checked.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(premiumControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: 'Aethel Premium',
          subtitle: 'Remove the free-plan caps on this account.',
          trailing: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.isPremium)
                  _ActivePanel(expiresAt: state.expiresAt)
                else if (state.pendingOrderId != null)
                  _WaitingPanel(
                    confirming: state.confirming || _checking,
                    onCheckAgain: _checkAgain,
                  )
                else ...[
                  _PaperBenefits(
                    limits: state.limits,
                  ),
                  const SizedBox(height: 18),
                  Text('Billing', style: textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SegmentedButton<BillingPeriod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: BillingPeriod.monthly,
                        label: Text('₹49 monthly'),
                      ),
                      ButtonSegment(
                        value: BillingPeriod.yearly,
                        label: Text('₹399 yearly'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (value) =>
                        setState(() => _period = value.first),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _period == BillingPeriod.yearly
                        ? '₹399 a year — ₹189 less than twelve monthly payments.'
                        : '₹49 a month, billed each month.',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.isPremium && state.pendingOrderId == null)
                FilledButton(
                  onPressed: _busy ? null : _checkout,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue to secure payment'),
                ),
              Text(
                state.isPremium
                    ? 'Premium is active on this account.'
                    : 'Payment opens in your browser. This account is '
                        'upgraded once the payment is confirmed.',
                style: textTheme.bodySmall?.copyWith(color: palette.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaperBenefits extends StatelessWidget {
  const _PaperBenefits({required this.limits});

  final PremiumPlanLimits limits;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final benefits = [
      (
        Icons.lock_open_rounded,
        'Unlimited vault entries',
        'The free plan holds ${limits.vaultItems ?? 15}.',
      ),
      (
        Icons.receipt_long_outlined,
        'Unlimited bills and subscriptions',
        'The free plan holds ${limits.billingItems ?? 5}.',
      ),
      (
        Icons.schedule_rounded,
        'Unlimited focus schedules',
        'The free plan holds ${limits.schedules ?? 1}.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: palette.tealSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, detail) in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 19, color: palette.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: textTheme.bodySmall
                              ?.copyWith(color: palette.ink, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.confirming, required this.onCheckAgain});

  final bool confirming;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.brassSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.brass.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 19, color: palette.brass),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Waiting for confirmation',
                    style: textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment is being confirmed with the server. If you have '
            'not finished paying in the browser, return to this sheet and '
            'start again.',
            style: textTheme.bodySmall?.copyWith(
              color: palette.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: confirming ? null : onCheckAgain,
                child: confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({this.expiresAt});

  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final renews =
        expiresAt == null ? null : DateFormat('d MMM yyyy').format(expiresAt!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.tealSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.teal.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 20, color: palette.teal),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium is active', style: textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  renews == null
                      ? 'All caps are lifted on this account.'
                      : 'Renews $renews. All caps are lifted on this account.',
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
