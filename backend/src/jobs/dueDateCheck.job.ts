import { prisma } from '../config/db.js';
import cron from 'node-cron';
import { sendPushNotification } from '../modules/notifications/notifications.service.js';

/**
 * Runs every 10 minutes.
 * - Bills entering the next 24 hours get one reminder; paying resets the flag.
 * - Recurring focus schedules are evaluated by local server time-of-day.
 *
 * Push bodies stay generic: the server only stores ciphertext titles and must
 * never imply it knows what a vault item or bill contains.
 */
export class DueDateCheckJob {
  static start() {
    cron.schedule('*/10 * * * *', () => {
      void DueDateCheckJob.run();
    });
  }

  static async run() {
    try {
      const now = new Date();
      const billWindowEnd = new Date(now.getTime() + 24 * 60 * 60 * 1000);

      const upcomingBills = await prisma.billingItem.findMany({
        where: {
          isActive: true,
          nextDueDate: { gte: now, lte: billWindowEnd },
          lastNotifiedAt: null,
        },
        select: { id: true, userId: true },
      });

      for (const bill of upcomingBills) {
        await sendPushNotification(bill.userId, {
          title: 'A bill is due soon',
          body: 'Open Aethel to review the amount and mark it paid.',
        });
        await prisma.billingItem.update({
          where: { id: bill.id },
          data: { lastNotifiedAt: now },
        });
      }

      const startOfToday = new Date(now);
      startOfToday.setHours(0, 0, 0, 0);

      const schedules = await prisma.studySchedule.findMany({
        where: {
          enabled: true,
          daysOfWeek: { has: now.getDay() },
          OR: [{ lastNotifiedAt: null }, { lastNotifiedAt: { lt: startOfToday } }],
        },
        select: { id: true, userId: true, startTime: true, lastNotifiedAt: true },
      });

      let scheduleCount = 0;
      for (const schedule of schedules) {
        const start = new Date(now);
        start.setHours(schedule.startTime.getHours(), schedule.startTime.getMinutes(), 0, 0);
        const minutesUntilStart = (start.getTime() - now.getTime()) / 60000;
        if (minutesUntilStart < 0 || minutesUntilStart > 15) continue;

        await sendPushNotification(schedule.userId, {
          title: 'Your focus session starts soon',
          body: 'Open Aethel to start your session on time.',
        });
        await prisma.studySchedule.update({
          where: { id: schedule.id },
          data: { lastNotifiedAt: now },
        });
        scheduleCount += 1;
      }

      console.log(`[DueDateCheck] ${upcomingBills.length} bills, ${scheduleCount} schedules`);
    } catch (err) {
      console.error('[DueDateCheck] Error:', err);
    }
  }
}
