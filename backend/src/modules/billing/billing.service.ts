import { prisma } from '../../config/db.js';

export class BillingService {
  async findByUser(userId: string) {
    return prisma.billingItem.findMany({ where: { userId }, orderBy: { nextDueDate: 'asc' } });
  }

  async create(userId: string, data: any) {
    return prisma.billingItem.create({
      data: {
        userId,
        itemType: data.item_type || 'BILL',
        title: data.title,
        amountDue: data.amount_due,
        billingCycle: data.billing_cycle || null,
        nextDueDate: data.next_due_date ? new Date(data.next_due_date) : null,
      },
    });
  }

  async markPaid(userId: string, id: string) {
    const item = await prisma.billingItem.findFirst({ where: { id, userId } });
    if (!item) throw new Error('Not found');

    const cycleDays: Record<string, number> = { DAILY: 1, WEEKLY: 7, BIWEEKLY: 14, MONTHLY: 30, QUARTERLY: 90, YEARLY: 365 };
    const days = cycleDays[item.billingCycle || 'MONTHLY'] || 30;
    const nextDate = item.nextDueDate ? new Date(item.nextDueDate.getTime() + days * 24 * 60 * 60 * 1000) : null;

    return prisma.billingItem.update({ where: { id, userId }, data: { lastNotifiedAt: new Date(), nextDueDate: nextDate } });
  }

  async delete(userId: string, id: string) {
    await prisma.billingItem.deleteMany({ where: { id, userId } });
  }
}
