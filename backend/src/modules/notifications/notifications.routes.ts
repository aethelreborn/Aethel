import { prisma } from '../../config/db.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';
import { Router, Request, Response, NextFunction } from 'express';
import { listDevices, registerDevice, unregisterDevice } from './notifications.service.js';

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

// Device routes
router.post('/register', authMiddleware, (req: Request, res: Response, next: NextFunction) => {
  const userId = (req as any).userId;
  registerDevice(userId, req.body, res, next);
});

router.get('/devices', authMiddleware, (req: Request, res: Response, next: NextFunction) => {
  const userId = (req as any).userId;
  listDevices(userId, res, next);
});

router.delete('/devices/:id', authMiddleware, (req: Request, res: Response, next: NextFunction) => {
  const userId = (req as any).userId;
  const paramId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
  unregisterDevice(userId, paramId, res, next);
});

export default router;
