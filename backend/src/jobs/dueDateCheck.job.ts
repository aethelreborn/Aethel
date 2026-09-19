import { prisma } from '../config/db.js';
import cron from 'node-cron';

export class DueDateCheckJob {
  static start() {
    cron.schedule('*/10 * * * *', async () => {
      try {
        const now = new Date();
        const cutoff = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
        const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const upcoming = await prisma.billingItem.findMany({
          where: {
            isActive: true,
            nextDueDate: {
              lte: cutoff,
              gte: now,
            },
          },
        });

        for (const item of upcoming) {
          if (!item.lastNotifiedAt || item.lastNotifiedAt < yesterday) {
            await prisma.notificationLog.create({
              data: {
                userId: item.userId,
                channel: 'in_app',
              },
            });
            await prisma.billingItem.update({
              where: { id: item.id },
              data: { lastNotifiedAt: now },
            });
          }
        }
        console.log('[DueDateCheck] Checked billing items');
      } catch (err) {
        console.error('[DueDateCheck] Error:', err);
      }
    });
  }
}
