import { prisma } from '../../config/db.js';
import { syncGateway } from '../../websocket/syncGateway.js';
import { assertCanCreate } from '../payments/entitlement.js';
import { addDays, addWeeks, addMonths } from 'date-fns';

export class BillingService {
  async findByUser(userId: string) {
    return prisma.billingItem.findMany({ where: { userId }, orderBy: { nextDueDate: 'asc' } });
  }

  async create(userId: string, data: any) {
    await assertCanCreate(userId, 'billingItems', () => prisma.billingItem.count({ where: { userId } }));
    const item = await prisma.billingItem.create({
      data: {
        ...(data.id ? { id: data.id } : {}),
        userId,
        itemType: data.item_type || 'BILL',
        title: data.title,
        amountDue: data.amount_due,
        billingCycle: data.billing_cycle || null,
        nextDueDate: data.next_due_date ? new Date(data.next_due_date) : null,
        isActive: data.is_active ?? true,
        paidAt: data.paid_at ? new Date(data.paid_at) : null,
      },
    });
    syncGateway.broadcast(userId, 'billing.created', item);
    return item;
  }

  async update(userId: string, id: string, data: any) {
    const item = await prisma.billingItem.update({
      where: { id, userId },
      data: {
        ...(data.title !== undefined && { title: data.title }),
        ...(data.amount_due !== undefined && { amountDue: data.amount_due }),
        ...(data.item_type !== undefined && { itemType: data.item_type }),
        ...(data.next_due_date !== undefined && {
          nextDueDate: data.next_due_date ? new Date(data.next_due_date) : null,
        }),
        ...(data.billing_cycle !== undefined && { billingCycle: data.billing_cycle }),
        ...(data.is_active !== undefined && { isActive: data.is_active }),
        ...(data.paid_at !== undefined && {
          paidAt: data.paid_at ? new Date(data.paid_at) : null,
        }),
      },
    });
    syncGateway.broadcast(userId, 'billing.updated', item);
    return item;
  }

  async markPaid(userId: string, id: string) {
    const item = await prisma.billingItem.findFirst({ where: { id, userId } });
    if (!item) throw new Error('Not found');

    let nextDate: Date | null = null;
    if (item.nextDueDate && item.billingCycle) {
      switch (item.billingCycle) {
        case 'DAILY':     nextDate = addDays(item.nextDueDate, 1); break;
        case 'WEEKLY':    nextDate = addWeeks(item.nextDueDate, 1); break;
        case 'BIWEEKLY':  nextDate = addWeeks(item.nextDueDate, 2); break;
        case 'MONTHLY':   nextDate = addMonths(item.nextDueDate, 1); break;
        case 'QUARTERLY': nextDate = addMonths(item.nextDueDate, 3); break;
        case 'YEARLY':    nextDate = addMonths(item.nextDueDate, 12); break;
      }
    }

    const updated = await prisma.billingItem.update({
      where: { id, userId },
      data: {
        paidAt: new Date(),
        nextDueDate: nextDate,
        // A paid bill must be eligible for a fresh reminder next cycle.
        lastNotifiedAt: null,
      },
    });
    syncGateway.broadcast(userId, 'billing.marked_paid', updated);
    return updated;
  }

  async delete(userId: string, id: string) {
    await prisma.billingItem.deleteMany({ where: { id, userId } });
    syncGateway.broadcast(userId, 'billing.deleted', { id });
  }
}
