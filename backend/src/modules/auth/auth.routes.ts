import { Router } from 'express';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import { AuthService } from './auth.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';
import { env } from '../../config/env.js';

const router = Router();
const authService = new AuthService();

const authBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const refreshTokenBodySchema = z.object({
  refresh_token: z.string().min(1),
});

router.post('/signup', authLimiter, validateBody(authBodySchema), async (req, res) => {
  try {
    const result = await authService.signup(req.body.email, req.body.password);
    res.status(201).json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/login', authLimiter, validateBody(authBodySchema), async (req, res) => {
  try {
    const result = await authService.login(req.body.email, req.body.password);
    res.json(result);
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

router.post('/refresh', authLimiter, validateBody(refreshTokenBodySchema), async (req, res) => {
  try {
    const result = await authService.refreshToken(req.body.refresh_token);
    res.json(result);
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

router.post('/logout', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const payload = jwt.verify(token, env.JWT_SECRET) as { userId: string };
      await authService.logout(payload.userId);
    }
    res.json({ message: 'Logged out' });
  } catch {
    res.json({ message: 'Logged out' });
  }
});

export default router;
