import { Router } from 'express';
import { z } from 'zod';
import { VaultService } from './vault.service.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { rejectPlaintext } from '../../middleware/rejectPlaintext.middleware.js';

const router = Router();
const vaultService = new VaultService();

const vaultBaseSchema = z.object({
  id: z.string().uuid().optional(),
  title: z.string().min(1).max(20000),
  item_type: z.enum(['PASSWORD', 'NOTE', 'CARDS', 'IDENTITY', 'SECURE_NOTE']),
  encrypted_payload: z.string().min(20).max(250000),
  iv: z.string().min(12).max(200),
});

router.get('/', authMiddleware, async (req: AuthRequest, res) => {
  const items = await vaultService.findByUser(req.userId as string);
  res.json({ items });
});

router.post('/', authMiddleware, rejectPlaintext, validateBody(vaultBaseSchema), async (req: AuthRequest, res) => {
  try {
    const item = await vaultService.create(req.userId as string, req.body);
    res.status(201).json(item);
  } catch (err: any) {
    res.status(409).json({ error: err.message });
  }
});

router.get('/:id', authMiddleware, async (req: AuthRequest, res) => {
  const item = await vaultService.findById(req.userId as string, req.params.id as string);
  if (!item) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(item);
});

router.put('/:id', authMiddleware, rejectPlaintext, validateBody(vaultBaseSchema), async (req: AuthRequest, res) => {
  try {
    const item = await vaultService.update(req.userId as string, req.params.id as string, req.body);
    res.json(item);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

router.delete('/:id', authMiddleware, async (req: AuthRequest, res) => {
  await vaultService.delete(req.userId as string, req.params.id as string);
  res.json({ success: true });
});

export default router;
