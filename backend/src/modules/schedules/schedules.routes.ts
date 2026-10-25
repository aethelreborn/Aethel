import { Router } from 'express';
import { z } from 'zod';
import { SchedulesService } from './schedules.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';

const router = Router();
const schedulesService = new SchedulesService();

const scheduleSchema = z.object({
  id: z.string().uuid().optional(),
  label: z.string().min(1).max(500),
  start_time: z.string(),
  end_time: z.string(),
  days_of_week: z.array(z.number().int().min(0).max(6)).min(1),
  blocked_apps: z.array(z.string()),
  enabled: z.boolean().optional(),
});

const scheduleUpdateSchema = scheduleSchema.partial().omit({ id: true });

router.get('/', authMiddleware, async (req: AuthRequest, res) => {
  const items = await schedulesService.findByUser(req.userId as string);
  res.json({ items });
});

router.post('/', authMiddleware, validateBody(scheduleSchema), async (req: AuthRequest, res) => {
  try {
    const item = await schedulesService.create(req.userId as string, req.body);
    res.status(201).json(item);
  } catch (err: any) {
    res.status(409).json({ error: err.message });
  }
});

router.put('/:id', authMiddleware, validateBody(scheduleUpdateSchema), async (req: AuthRequest, res) => {
  try {
    const item = await schedulesService.update(req.userId as string, req.params.id as string, req.body);
    res.json(item);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

router.delete('/:id', authMiddleware, async (req: AuthRequest, res) => {
  await schedulesService.delete(req.userId as string, req.params.id as string);
  res.json({ success: true });
});

export default router;
