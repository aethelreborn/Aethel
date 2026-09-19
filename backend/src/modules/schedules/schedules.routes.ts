import { Router } from 'express';
import { z } from 'zod';
import { SchedulesService } from './schedules.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';

const router = Router();
const schedulesService = new SchedulesService();

const scheduleSchema = z.object({
  label: z.string().min(1),
  start_time: z.string(),
  end_time: z.string(),
  days_of_week: z.array(z.number().int()).min(1),
  blocked_apps: z.array(z.string()),
});

router.get('/', authMiddleware, async (req, res) => {
  const items = await schedulesService.findByUser((req as any).userId);
  res.json({ items });
});

router.post('/', authMiddleware, validateBody(scheduleSchema), async (req, res) => {
  const item = await schedulesService.create((req as any).userId, req.body);
  res.status(201).json(item);
});

router.put('/:id', authMiddleware, validateBody(scheduleSchema), async (req, res) => {
  const item = await schedulesService.update((req as any).userId, req.params.id as string, req.body);
  res.json(item);
});

router.delete('/:id', authMiddleware, async (req, res) => {
  await schedulesService.delete((req as any).userId, req.params.id as string);
  res.json({ success: true });
});

export default router;
