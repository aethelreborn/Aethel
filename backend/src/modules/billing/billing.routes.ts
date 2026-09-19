import { Router } from 'express';
import { BillingService } from './billing.service.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';

const router = Router();
const billingService = new BillingService();

router.get('/', authMiddleware, async (req, res) => {
  const items = await billingService.findByUser((req as any).userId);
  res.json({ items });
});

router.post('/', authMiddleware, async (req, res) => {
  const item = await billingService.create((req as any).userId, req.body);
  res.status(201).json(item);
});

router.post('/:id/paid', authMiddleware, async (req, res) => {
  try {
    const item = await billingService.markPaid((req as any).userId, req.params.id as string);
    res.json(item);
  } catch (err: any) {
    res.status(404).json({ error: err.message });
  }
});

router.delete('/:id', authMiddleware, async (req, res) => {
  await billingService.delete((req as any).userId, req.params.id as string);
  res.json({ success: true });
});

export default router;
