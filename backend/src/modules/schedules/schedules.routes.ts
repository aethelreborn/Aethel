import { Router } from 'express';
import { SchedulesService } from './schedules.service.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';

const router = Router();
const schedulesService = new SchedulesService();

router.get('/', authMiddleware, async (req, res) => {
  const items = await schedulesService.findByUser((req as any).userId);
  res.json({ items });
});

router.post('/', authMiddleware, async (req, res) => {
  const item = await schedulesService.create((req as any).userId, req.body);
  res.status(201).json(item);
});

router.put('/:id', authMiddleware, async (req, res) => {
  const item = await schedulesService.update((req as any).userId, req.params.id as string, req.body);
  res.json(item);
});

router.delete('/:id', authMiddleware, async (req, res) => {
  await schedulesService.delete((req as any).userId, req.params.id as string);
  res.json({ success: true });
});

export default router;
