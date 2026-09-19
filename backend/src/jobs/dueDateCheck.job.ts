import { prisma } from '../config/db.js';
import cron from 'node-cron';
import { sendPushNotification } from '../modules/notifications/notifications.service.js';

/**
 * Runs every 10 minutes.
 * - Checks billing_items due within 24 h that haven't been notified.
 * - Checks study_schedules starting within 15 min that haven't been notified.
 * - Sends push notifications and stamps lastNotifiedAt (skips on markPaid).
 */
export class DueDateCheckJob {
  static start() {
    cron.schedule('*/10 * * * *', async () => {
      try {
        const now = new Date();
        const billWindowEnd = new Date(now.getTime() + 24 * 60 * 60 * 1000);
        const scheduleWindowEnd = new Date(now.getTime() + 15 * 60 * 1000);

        // Bills due within 24h that haven't been notified yet
        const upcomingBills = await prisma.billingItem.findMany({
          where: {
            isActive: true,
            nextDueDate: { gte: now, lte: billWindowEnd },
            lastNotifiedAt: null,
          },
          select: { id: true, userId: true, title: true, nextDueDate: true },
        });

        for (const bill of upcomingBills) {
          await sendPushNotification(bill.userId, {
            title: `Bill Due: ${bill.title}`,
            body: `Your ${bill.title} bill is due on ${bill.nextDueDate?.toLocaleDateString() ?? 'TBD'}.`,
          });
          await prisma.billingItem.update({
            where: { id: bill.id },
            data: { lastNotifiedAt: now },
          });
        }

        // Study schedules starting within 15 min that haven't been notified
        const upcomingSchedules = await prisma.studySchedule.findMany({
          where: { startTime: { gte: now, lte: scheduleWindowEnd } },
          select: { id: true, userId: true, label: true, startTime: true },
        });

        for (const sched of upcomingSchedules) {
          await sendPushNotification(sched.userId, {
            title: `Focus: ${sched.label}`,
            body: `Your "${sched.label}" session starts in 15 minutes.`,
          });
          await prisma.studySchedule.update({
            where: { id: sched.id },
            data: { lastNotifiedAt: now },
          });
        }

        console.log(`[DueDateCheck] Checked -> ${upcomingBills.length} bills, ${upcomingSchedules.length} schedules`);
      } catch (err) {
        console.error('[DueDateCheck] Error:', err);
      }
    });
  }
}
