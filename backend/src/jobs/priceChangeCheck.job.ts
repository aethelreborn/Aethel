/**
 * Price-change monitor — runs daily.
 * Compares current billing_item amounts against a stored "last known" snapshot
 * and alerts the user when a recurring charge has changed.
 *
 * Placeholder: no price_history table exists yet in the schema.
 * Extend schema with a PriceHistory model once this feature is ready.
 */
import cron from 'node-cron';
import { prisma } from '../config/db';

export async function priceChangeCheckJob() {
  try {
    const recent = await prisma.billingItem.findMany({
      where: { updatedAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } },
      select: { id: true, userId: true, title: true, amountDue: true, updatedAt: true },
    });
    // TODO: compare against previous amounts (needs PriceHistory table)
    void recent;
    console.log(`[cron] priceChangeCheck ran -> ${recent.length} updated items (snapshot only)`);
  } catch (err) {
    console.error('[cron] priceChangeCheck error:', err);
  }
}

export function startPriceScheduler() {
  // Run once daily at 2 AM
  cron.schedule('0 2 * * *', priceChangeCheckJob);
  console.log('[cron] Price-change checker scheduled for 02:00 daily');
}
