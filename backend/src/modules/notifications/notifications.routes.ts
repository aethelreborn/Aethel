import { prisma } from '../../config/db.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';
import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', authMiddleware, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const events = [];
  
  const vaultItems = await prisma.vaultItem.findMany({ where: { userId }, orderBy: { updatedAt: 'desc' }, take: 10 });
  for (const item of vaultItems) {
    events.push({ id: item.id, title: item.title, subtitle: `Vault - ${item.itemType}`, urgency: 'scheduled', timestamp: item.updatedAt.toISOString(), module: 'vault' });
  }
  
  const billingItems = await prisma.billingItem.findMany({ where: { userId, isActive: true }, orderBy: { nextDueDate: 'asc' }, take: 10 });
  for (const item of billingItems) {
    const now = new Date();
    let urgency = 'scheduled';
    if (item.nextDueDate && item.nextDueDate < now) urgency = 'urgent';
    else if (item.nextDueDate && (item.nextDueDate.getTime() - now.getTime()) < 7 * 24 * 60 * 60 * 1000) urgency = 'upcoming';
    events.push({ id: item.id, title: item.title, subtitle: `$${item.amountDue} — ${item.billingCycle || 'one-time'}`, urgency, timestamp: item.nextDueDate?.toISOString() || item.createdAt.toISOString(), module: 'billing' });
  }
  
  events.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  res.json({ events: events.slice(0, 50) });
});

export default router;
