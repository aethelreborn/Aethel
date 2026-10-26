import { Router } from 'express';
import { z } from 'zod';
import { AuthService } from './auth.service.js';
import { validateBody } from '../../middleware/validate.middleware.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';

const router = Router();
const authService = new AuthService();

// The client sends a PBKDF2-derived verifier, never the master password.
const authBodySchema = z.object({
  email: z.string().email().max(254),
  password: z.string().min(20).max(256),
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

router.get('/me', authMiddleware, async (req: AuthRequest, res) => {
  try {
    res.json({ user: await authService.me(req.userId as string) });
  } catch (err: any) {
    res.status(404).json({ error: err.message });
  }
});

router.post(
  '/change-password',
  authMiddleware,
  authLimiter,
  validateBody(z.object({ password: z.string().min(20).max(256) })),
  async (req: AuthRequest, res) => {
    try {
      const result = await authService.changePassword(req.userId as string, req.body.password);
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  },
);

router.delete('/account', authMiddleware, async (req: AuthRequest, res) => {
  try {
    await authService.deleteAccount(req.userId as string);
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/logout', authLimiter, authMiddleware, async (req: AuthRequest, res) => {
  try {
    await authService.logout(req.userId as string);
  } catch {
    // Best effort — token version bump already invalidates sessions.
  }
  res.json({ message: 'Logged out' });
});

export default router;
