import { Router } from 'express';
import { z } from 'zod';
import { BillingService } from './billing.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';

const router = Router();
const billingService = new BillingService();

const billingBaseSchema = z.object({
  id: z.string().uuid().optional(),
  title: z.string().min(1).max(20000),
  amount_due: z.number().nonnegative(),
  item_type: z.enum(['BILL', 'SUBSCRIPTION']),
  next_due_date: z.string().nullable().optional(),
  billing_cycle: z.enum(['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY']).nullable().optional(),
  is_active: z.boolean().optional(),
  paid_at: z.string().nullable().optional(),
});

const billingUpdateSchema = billingBaseSchema.partial().omit({ id: true });

router.get('/', authMiddleware, async (req: AuthRequest, res) => {
  const items = await billingService.findByUser(req.userId as string);
  res.json({ items });
});

router.post('/', authMiddleware, validateBody(billingBaseSchema), async (req: AuthRequest, res) => {
  try {
    const item = await billingService.create(req.userId as string, req.body);
    res.status(201).json(item);
  } catch (err: any) {
    if (err?.code === 'FREE_LIMIT_REACHED') {
      res.status(403).json({ error: err.message, code: err.code, limit: err.limit, resource: err.resource });
      return;
    }
    res.status(409).json({ error: err.message });
  }
});

router.put('/:id', authMiddleware, validateBody(billingUpdateSchema), async (req: AuthRequest, res) => {
  try {
    const item = await billingService.update(req.userId as string, req.params.id as string, req.body);
    res.json(item);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

router.post('/:id/paid', authMiddleware, async (req: AuthRequest, res) => {
  try {
    const item = await billingService.markPaid(req.userId as string, req.params.id as string);
    res.json(item);
  } catch (err: any) {
    res.status(404).json({ error: err.message });
  }
});

router.delete('/:id', authMiddleware, async (req: AuthRequest, res) => {
  await billingService.delete(req.userId as string, req.params.id as string);
  res.json({ success: true });
});

export default router;
