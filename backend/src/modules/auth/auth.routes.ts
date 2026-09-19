import { Router } from 'express';
import { AuthService } from './auth.service.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';

const router = Router();
const authService = new AuthService();

router.post('/signup', authLimiter, async (req, res) => {
  try {
    const result = await authService.signup(req.body.email, req.body.password);
    res.status(201).json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/login', authLimiter, async (req, res) => {
  try {
    const result = await authService.login(req.body.email, req.body.password);
    res.json(result);
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

router.post('/refresh', authLimiter, async (req, res) => {
  try {
    const result = await authService.refreshToken(req.body.refresh_token);
    res.json(result);
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

router.post('/logout', async (req, res) => {
  res.json({ message: 'Logged out' });
});

export default router;
