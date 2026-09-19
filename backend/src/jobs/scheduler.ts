import cron from 'node-cron';
import { prisma } from '../config/db';
import { sendPushNotification } from '../modules/notifications/notifications.service';

/**
 * Runs every 10 minutes.
 * Finds billing_items and study_schedules entering their notification window
 * (due within 24 h) that have not yet been notified, and dispatches pushes.
 */
export async function dueDateCheckJob() {
  const now = new Date();
  const windowMs = 24 * 60 * 60 * 1000;
  const windowEnd = new Date(now.getTime() + windowMs);

  try {
    // Upcoming bills / subscriptions
    const upcomingBills = await prisma.billingItem.findMany({
      where: {
        isActive: true,
        nextDueDate: { gte: now, lte: windowEnd },
        lastNotifiedAt: null,
      },
      select: { id: true, userId: true, title: true, nextDueDate: true },
    });

    for (const bill of upcomingBills) {
      await sendPushNotification(bill.userId, {
        title: `Bill Due: ${bill.title}`,
        body: `Your ${bill.title} bill is due on ${bill.nextDueDate?.toLocaleDateString() ?? 'TBD'}.`,
      });
    }

    // Upcoming focus sessions (notify 15 min before start)
    const soon = new Date(now.getTime() + 15 * 60 * 1000);
    const upcomingSchedules = await prisma.studySchedule.findMany({
      where: { startTime: { gte: now, lte: soon } },
      select: { id: true, userId: true, label: true, startTime: true },
    });

    for (const s of upcomingSchedules) {
      await sendPushNotification(s.userId, {
        title: `Focus: ${s.label}`,
        body: `Your "${s.label}" session starts in 15 minutes.`,
      });
    }

    console.log(`[cron] dueDateCheck @ ${now.toISOString()} -> ${upcomingBills.length} bills, ${upcomingSchedules.length} schedules`);
  } catch (err) {
    console.error('[cron] dueDateCheck error:', err);
  }
}

/** Bootstrap all background cron jobs. */
export function startScheduler() {
  cron.schedule('*/10 * * * *', dueDateCheckJob);
  console.log('[cron] Scheduler started — checks every 10 min');
}
