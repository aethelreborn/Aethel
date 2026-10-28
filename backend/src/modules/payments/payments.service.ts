import crypto from 'crypto';
import { prisma } from '../../config/db.js';
import { env } from '../../config/env.js';
import { FREE_LIMITS, isPremium } from './entitlement.js';

const PLAN_PRICES = {
  monthly: { amount: '49.00', amountPaise: 4900, days: 31 },
  yearly: { amount: '399.00', amountPaise: 39900, days: 366 },
} as const;

export type CheckoutPeriod = keyof typeof PLAN_PRICES;

/** Statuses the UPI observer/reconciliation pipeline produces for a real payment. */
const GRANT_STATUSES = new Set(['OBSERVED_SUCCESS', 'RECONCILED']);

const SIGNATURE_SKEW_MS = 2 * 60 * 60 * 1000;

class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

const unauthorized = () => new HttpError(401, 'WEBHOOK_SIGNATURE_INVALID', 'Invalid webhook signature');
const notConfigured = () => new HttpError(503, 'PAYMENTS_NOT_CONFIGURED', 'Payments are not configured');
const gatewayDown = () => new HttpError(502, 'GATEWAY_ERROR', 'Payment gateway is unavailable');

function headerValue(headers: Record<string, string | string[] | undefined>, name: string): string | undefined {
  const raw = headers[name];
  if (Array.isArray(raw)) return raw[0];
  return raw;
}

/** Constant-time compare that tolerates length mismatch without throwing. */
function timingSafeEqualStr(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  if (ba.length !== bb.length) {
    // Still burn a compare so length differences are not trivially timeable.
    crypto.timingSafeEqual(ba, ba);
    return false;
  }
  return crypto.timingSafeEqual(ba, bb);
}

export class PaymentsService {
  async getPlan(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { plan: true, planExpiresAt: true },
    });
    if (!user) throw new HttpError(404, 'USER_NOT_FOUND', 'User not found');

    // Expired premium is treated as free in the response and in cap enforcement.
    const premium = isPremium(user);
    return {
      plan: premium ? ('premium' as const) : ('free' as const),
      expiresAt: premium && user.planExpiresAt ? user.planExpiresAt.toISOString() : null,
      isPremium: premium,
      limits: {
        vaultItems: premium ? null : FREE_LIMITS.vaultItems,
        billingItems: premium ? null : FREE_LIMITS.billingItems,
        schedules: premium ? null : FREE_LIMITS.schedules,
      },
    };
  }

  async checkout(userId: string, period: CheckoutPeriod) {
    if (!env.AETHEL_PAY_MERCHANT_KEY) throw notConfigured();
    const pricing = PLAN_PRICES[period];
    const orderId = crypto.randomUUID();

    let created: { paymentId?: string; checkoutUrl?: string };
    try {
      const res = await fetch(`${env.AETHEL_PAY_GATEWAY_URL}/api/v1/payments`, {
        method: 'POST',
        headers: {
          'X-Merchant-Id': env.AETHEL_PAY_MERCHANT_ID,
          'X-Merchant-Key': env.AETHEL_PAY_MERCHANT_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          orderId,
          amount: pricing.amount,
          currency: 'INR',
          method: 'UPI',
          returnUrl: env.AETHEL_PAY_RETURN_URL || env.FRONTEND_URL,
          metadata: { userId, plan: 'premium', period },
        }),
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) throw gatewayDown();
      created = (await res.json()) as { paymentId?: string; checkoutUrl?: string };
    } catch (err: unknown) {
      if (err instanceof HttpError) throw err;
      throw gatewayDown();
    }

    if (!created?.paymentId || !created?.checkoutUrl) throw gatewayDown();

    // Best-effort order→payment mapping so /verify (which receives only
    // orderId) can poll the gateway. A crash between the gateway call and
    // this insert leaves the mapping missing; /verify then 404s until a
    // webhook grant arrives, never grants incorrectly.
    try {
      await prisma.paymentEvent.create({
        data: {
          userId,
          orderId,
          paymentId: created.paymentId,
          event: 'checkout_created',
          deliveryId: `checkout:${orderId}`,
          amountPaise: pricing.amountPaise,
        },
      });
    } catch (err: any) {
      if (err?.code !== 'P2002') throw err;
    }

    return {
      orderId,
      paymentId: created.paymentId,
      checkoutUrl: created.checkoutUrl,
      amount: pricing.amount,
      currency: 'INR',
    };
  }

  async verify(userId: string, orderId: string) {
    if (!env.AETHEL_PAY_MERCHANT_KEY) throw notConfigured();

    const record = await prisma.paymentEvent.findFirst({
      where: { userId, orderId, paymentId: { not: null } },
      orderBy: { createdAt: 'desc' },
      select: { paymentId: true },
    });
    if (!record?.paymentId) throw new HttpError(404, 'PAYMENT_NOT_FOUND', 'Payment not found');

    const session = await this.fetchGatewayPayment(record.paymentId);
    const status = String(session.internalStatus ?? session.status ?? 'UNKNOWN');

    // Never grant one user's payment to another: the owner view must echo
    // metadata naming us — a missing metadata.userId is rejected, not skipped.
    const metadataUserId = session.metadata?.userId;
    if (metadataUserId == null || String(metadataUserId) !== userId) {
      throw new HttpError(403, 'PAYMENT_USER_MISMATCH', 'Payment does not belong to this user');
    }

    // Repeat verifies reuse the same deliveryId, so ensureGrant is a no-op the second time.
    await this.ensureGrant({
      userId,
      orderId,
      paymentId: record.paymentId,
      event: status,
      deliveryId: `poll:${record.paymentId}:${status}`,
      amountPaise: session.amountPaise != null ? Number(session.amountPaise) : null,
      method: session.method ?? null,
      currency: session.currency ?? null,
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { plan: true, planExpiresAt: true },
    });
    if (!user) throw new HttpError(404, 'USER_NOT_FOUND', 'User not found');
    const premium = isPremium(user);
    return {
      status,
      isPremium: premium,
      plan: premium ? ('premium' as const) : ('free' as const),
      expiresAt: premium && user.planExpiresAt ? user.planExpiresAt.toISOString() : null,
    };
  }

  /**
   * Raw-body HMAC webhook handler. Signature is checked over the exact bytes the
   * gateway sent — the route must therefore mount express.raw, never express.json.
   */
  async handleWebhook(
    rawBody: Buffer,
    headers: Record<string, string | string[] | undefined>,
  ): Promise<{ kind: 'ok' } | { kind: 'ignored' }> {
    if (!this.verifyWebhookSignature(rawBody, headers)) throw unauthorized();

    let payload: any;
    try {
      payload = JSON.parse(rawBody.toString('utf8'));
    } catch {
      return { kind: 'ignored' };
    }

    // Dedupe key and event must come from the SIGNED payload: the gateway
    // headers are not covered by the HMAC (v1 signs the body only), so a
    // header-first lookup would let one signed delivery be replayed under a
    // fresh delivery id. Headers are accepted only as a cross-check.
    const deliveryId = payload?.deliveryId;
    const event = payload?.event;
    if (!deliveryId || !event) return { kind: 'ignored' };
    const headerDeliveryId = headerValue(headers, 'x-gateway-delivery-id');
    const headerEvent = headerValue(headers, 'x-gateway-event');
    if ((headerDeliveryId && headerDeliveryId !== String(deliveryId)) || (headerEvent && headerEvent !== String(event))) {
      return { kind: 'ignored' };
    }

    const userId = payload?.metadata?.userId;
    if (!userId) return { kind: 'ignored' };

    const granted = await this.ensureGrant({
      userId: String(userId),
      orderId: String(payload?.orderId ?? ''),
      paymentId: payload?.paymentId != null ? String(payload.paymentId) : null,
      event: String(event),
      deliveryId: String(deliveryId),
      amountPaise: payload?.amountPaise != null ? Number(payload.amountPaise) : null,
      method: payload?.method != null ? String(payload.method) : null,
      currency: payload?.currency != null ? String(payload.currency) : null,
    });

    return granted ? { kind: 'ok' } : { kind: 'ignored' };
  }

  verifyWebhookSignature(
    rawBody: Buffer,
    headers: Record<string, string | string[] | undefined>,
  ): boolean {
    const secret = env.AETHEL_PAY_MERCHANT_KEY;
    if (!secret || rawBody.length === 0) return false;

    const tsHeader = headerValue(headers, 'x-gateway-timestamp');
    let timestamp = Number(tsHeader);
    let tsUsed = tsHeader;
    if (!Number.isFinite(timestamp)) {
      // No header timestamp: fall back to a payload-embedded one, if present.
      try {
        const payload = JSON.parse(rawBody.toString('utf8'));
        if (payload && Number.isFinite(Number(payload.timestamp))) {
          timestamp = Number(payload.timestamp);
          tsUsed = String(payload.timestamp);
        }
      } catch {
        // Not JSON — the skew check below fails closed.
      }
    }
    if (!Number.isFinite(timestamp) || !tsUsed) return false;
    if (Math.abs(Date.now() - timestamp) > SIGNATURE_SKEW_MS) return false;

    const bodyText = rawBody.toString('utf8');
    const mac = (data: string) => `sha256=${crypto.createHmac('sha256', secret).update(data).digest('hex')}`;
    const accepted = [mac(bodyText), mac(`${tsUsed}.${bodyText}`)];

    const presented = [headerValue(headers, 'x-gateway-signature'), headerValue(headers, 'x-gateway-signature-v2')];
    return presented.some((sig) => sig && accepted.some((expected) => timingSafeEqualStr(sig, expected)));
  }

  /**
   * Idempotent grant shared by the poll (verify) path and the webhook path.
   * The unique deliveryId is the claim: a duplicate insert means this exact
   * delivery was already processed, so nothing is granted twice. Claim and
   * grant commit in one transaction so a crash between them cannot leave a
   * claimed-but-ungranted delivery (the gateway would retry into the dedupe).
   */
  private async ensureGrant(input: {
    userId: string;
    orderId: string;
    paymentId: string | null;
    event: string;
    deliveryId: string;
    amountPaise: number | null;
    method: string | null;
    currency: string | null;
  }): Promise<boolean> {
    const eligible =
      GRANT_STATUSES.has(input.event) &&
      input.method === 'UPI' &&
      input.currency === 'INR' &&
      (input.amountPaise === PLAN_PRICES.monthly.amountPaise ||
        input.amountPaise === PLAN_PRICES.yearly.amountPaise);

    let granted = false;
    try {
      await prisma.$transaction(async (tx) => {
        await tx.paymentEvent.create({
          data: {
            userId: input.userId,
            orderId: input.orderId,
            paymentId: input.paymentId,
            event: input.event,
            deliveryId: input.deliveryId,
            amountPaise: input.amountPaise,
          },
        });
        if (!eligible) return;

        // One payment grants once: a status transition (OBSERVED_SUCCESS →
        // RECONCILED) arrives as a second delivery but must not reset expiry.
        if (input.paymentId) {
          const priorGrant = await tx.paymentEvent.findFirst({
            where: {
              paymentId: input.paymentId,
              event: { in: [...GRANT_STATUSES] },
              deliveryId: { not: input.deliveryId },
            },
            select: { id: true },
          });
          if (priorGrant) return;
        }

        const user = await tx.user.findUnique({ where: { id: input.userId }, select: { id: true } });
        if (!user) return;

        const days =
          input.amountPaise === PLAN_PRICES.monthly.amountPaise
            ? PLAN_PRICES.monthly.days
            : PLAN_PRICES.yearly.days;
        const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
        await tx.user.update({
          where: { id: user.id },
          data: { plan: 'premium', planExpiresAt: expiresAt },
        });
        granted = true;
      });
    } catch (err: any) {
      if (err?.code === 'P2002') return false;
      throw err;
    }
    return granted;
  }

  private async fetchGatewayPayment(paymentId: string): Promise<any> {
    if (!env.AETHEL_PAY_MERCHANT_KEY) throw notConfigured();
    let res: Response;
    try {
      res = await fetch(`${env.AETHEL_PAY_GATEWAY_URL}/api/v1/payments/${encodeURIComponent(paymentId)}`, {
        headers: {
          'X-Merchant-Id': env.AETHEL_PAY_MERCHANT_ID,
          'X-Merchant-Key': env.AETHEL_PAY_MERCHANT_KEY,
        },
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw gatewayDown();
    }
    if (!res.ok) throw gatewayDown();
    return res.json();
  }
}
