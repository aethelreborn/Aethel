import { Router } from 'express';
import { z } from 'zod';
import { BillingService } from './billing.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';

const router = Router();
const billingService = new BillingService();

const billingBaseSchema = z.object({
  title: z.string().min(1),
  amount_due: z.number(),
  item_type: z.enum(['BILL', 'SUBSCRIPTION']),
  next_due_date: z.string().optional(),
  billing_cycle: z.enum(['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY']).optional(),
});

router.get('/', authMiddleware, async (req, res) => {
  const items = await billingService.findByUser((req as any).userId);
  res.json({ items });
});

router.post('/', authMiddleware, validateBody(billingBaseSchema), async (req, res) => {
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
