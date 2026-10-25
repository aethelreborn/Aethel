import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../config/db.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import {
  DeviceInput,
  listDevices,
  registerDevice,
  unregisterDevice,
} from './notifications.service.js';

// ── Timeline ─────────────────────────────────────────────────────────────────
export const timelineRoutes = Router();

timelineRoutes.get('/', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.userId as string;
  const now = new Date();
  const events: Array<Record<string, unknown>> = [];

  const vaultItems = await prisma.vaultItem.findMany({
    where: { userId },
    orderBy: { updatedAt: 'desc' },
    take: 10,
  });
  for (const item of vaultItems) {
    events.push({
      id: item.id,
      title: item.title,
      subtitle: `Vault · ${item.itemType}`,
      urgency: 'scheduled',
      timestamp: item.updatedAt.toISOString(),
      module: 'vault',
    });
  }

  const billingItems = await prisma.billingItem.findMany({
    where: { userId, isActive: true },
    orderBy: { nextDueDate: 'asc' },
    take: 10,
  });
  for (const item of billingItems) {
    let urgency = 'scheduled';
    if (item.nextDueDate && item.nextDueDate < now) urgency = 'urgent';
    else if (item.nextDueDate && item.nextDueDate.getTime() - now.getTime() < 7 * 86400000) {
      urgency = 'upcoming';
    }
    events.push({
      id: item.id,
      title: item.title,
      subtitle: `$${item.amountDue} · ${item.billingCycle || 'one-time'}`,
      urgency,
      timestamp: item.nextDueDate?.toISOString() || item.createdAt.toISOString(),
      module: 'billing',
    });
  }

  events.sort((a, b) => new Date(b.timestamp as string).getTime() - new Date(a.timestamp as string).getTime());
  res.json({ events: events.slice(0, 50) });
});

// ── Devices ──────────────────────────────────────────────────────────────────
export const deviceRoutes = Router();

const deviceSchema = z.object({
  id: z.string().uuid().optional(),
  pushToken: z.string().min(1).max(4096).optional(),
  platform: z.string().max(40).optional(),
});

deviceRoutes.post('/register', authMiddleware, validateBody(deviceSchema), async (req: AuthRequest, res) => {
  try {
    const device = await registerDevice(req.userId as string, req.body as DeviceInput);
    res.status(201).json(device);
  } catch (err: any) {
    res.status(409).json({ error: err.message });
  }
});

deviceRoutes.get('/', authMiddleware, async (req: AuthRequest, res) => {
  res.json({ devices: await listDevices(req.userId as string) });
});

deviceRoutes.delete('/:id', authMiddleware, async (req: AuthRequest, res) => {
  try {
    await unregisterDevice(req.userId as string, req.params.id as string);
    res.json({ success: true });
  } catch (err: any) {
    res.status(404).json({ error: err.message });
  }
});
