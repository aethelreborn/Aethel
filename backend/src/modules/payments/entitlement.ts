import { prisma } from '../../config/db.js';

export const FREE_LIMITS = {
  vaultItems: 15,
  billingItems: 5,
  schedules: 1,
} as const;

export type FreeResource = keyof typeof FREE_LIMITS;

/** Minimal plan shape needed to decide premium — works on any prisma user selection. */
export type PlanLike = {
  plan: string;
  planExpiresAt: Date | null;
};

/**
 * Premium is valid only while unexpired. An expired premium row is treated as free
 * everywhere (plan response and cap enforcement), so this single check is the gate.
 */
export function isPremium(user: PlanLike, now: Date = new Date()): boolean {
  return user.plan === 'premium' && (!user.planExpiresAt || user.planExpiresAt > now);
}

/** Thrown by the create paths of vault/billing/schedules when a free user is at cap. */
export class FreeLimitReachedError extends Error {
  readonly code = 'FREE_LIMIT_REACHED';
  constructor(
    readonly resource: FreeResource,
    readonly limit: number,
  ) {
    super(`Free plan limit reached for ${resource} (max ${limit}). Upgrade to premium to continue.`);
    this.name = 'FreeLimitReachedError';
  }
}

/**
 * Assert the authenticated user may create one more item of `resource`.
 * `count` is supplied by the caller so each module only queries its own table.
 * Premium users bypass the cap; free users are rejected at >= the free limit.
 */
export async function assertCanCreate(
  userId: string,
  resource: FreeResource,
  count: () => Promise<number>,
): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { plan: true, planExpiresAt: true },
  });
  if (!user) throw new Error('Not found');
  if (isPremium(user)) return;

  const limit = FREE_LIMITS[resource];
  if ((await count()) >= limit) {
    throw new FreeLimitReachedError(resource, limit);
  }
}
