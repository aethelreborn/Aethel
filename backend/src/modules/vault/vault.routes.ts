import { Router } from 'express';
import { z } from 'zod';
import { VaultService } from './vault.service.js';
import { authMiddleware } from '../../middleware/auth.middleware.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { rejectPlaintext } from '../../middleware/rejectPlaintext.middleware.js';

const router = Router();
const vaultService = new VaultService();

const vaultBaseSchema = z.object({
  title: z.string().min(1),
  item_type: z.enum(['PASSWORD', 'NOTE', 'CARDS', 'IDENTITY', 'SECURE_NOTE']),
  encrypted_payload: z.string().min(20),
  iv: z.string().min(12),
});

router.get('/', authMiddleware, async (req, res) => {
  const items = await vaultService.findByUser((req as any).userId);
  res.json({ items });
});

router.post('/', authMiddleware, rejectPlaintext, validateBody(vaultBaseSchema), async (req, res) => {
  const item = await vaultService.create((req as any).userId, req.body);
  res.status(201).json(item);
});

router.get('/:id', authMiddleware, async (req, res) => {
  const item = await vaultService.findById((req as any).userId, req.params.id as string);
  if (!item) return res.status(404).json({ error: 'Not found' });
  res.json(item);
});

router.put('/:id', authMiddleware, rejectPlaintext, validateBody(vaultBaseSchema), async (req, res) => {
  const item = await vaultService.update((req as any).userId, req.params.id as string, req.body);
  res.json(item);
});

router.delete('/:id', authMiddleware, async (req, res) => {
  await vaultService.delete((req as any).userId, req.params.id as string);
  res.json({ success: true });
});

export default router;
