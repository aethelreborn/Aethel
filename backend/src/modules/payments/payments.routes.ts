import express, { Router, Response } from 'express';
import { z } from 'zod';
import { PaymentsService } from './payments.service.js';
import { authMiddleware, AuthRequest } from '../../middleware/auth.middleware.js';
import { validateBody } from '../../middleware/validate.middleware.js';

const router = Router();
const paymentsService = new PaymentsService();

const checkoutSchema = z.object({
  period: z.enum(['monthly', 'yearly']),
});

const verifySchema = z.object({
  orderId: z.string().min(1).max(255),
});

// Payments is mounted BEFORE the global express.json() in server.ts so the
// webhook route can read the raw body bytes the gateway HMAC-signed. The
// JSON-parsing routes therefore attach their own parser explicitly below.
const jsonBody = express.json({ limit: '256kb' });

function sendError(res: Response, err: any) {
  const status = typeof err?.status === 'number' ? err.status : 500;
  if (status >= 500) {
    // The global errorHandler never sees these (handled inline), so log here —
    // a silent 500 on a payment path is undebuggable.
    console.error('[payments]', err);
  }
  const message = status === 500 ? 'Internal server error' : err.message;
  res.status(status).json({
    error: message,
    ...(err?.code && { code: err.code }),
    ...(err?.limit != null && { limit: err.limit }),
    ...(err?.resource && { resource: err.resource }),
  });
}

router.get('/plan', authMiddleware, async (req: AuthRequest, res) => {
  try {
    res.json(await paymentsService.getPlan(req.userId as string));
  } catch (err) {
    sendError(res, err);
  }
});

router.post('/checkout', authMiddleware, jsonBody, validateBody(checkoutSchema), async (req: AuthRequest, res) => {
  try {
    res.status(201).json(await paymentsService.checkout(req.userId as string, req.body.period));
  } catch (err) {
    sendError(res, err);
  }
});

router.post('/verify', authMiddleware, jsonBody, validateBody(verifySchema), async (req: AuthRequest, res) => {
  try {
    res.json(await paymentsService.verify(req.userId as string, req.body.orderId));
  } catch (err) {
    sendError(res, err);
  }
});

// Raw-body HMAC endpoint: express.raw (not express.json) so the signature is
// computed over the exact bytes the gateway sent — re-serializing would break it.
router.post('/webhook', express.raw({ type: '*/*', limit: '256kb' }), async (req, res) => {
  try {
    const raw = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
    const result = await paymentsService.handleWebhook(raw, req.headers as Record<string, string | string[] | undefined>);
    if (result.kind === 'ok') {
      res.status(200).json({ received: true });
    } else {
      res.status(200).json({ received: true, ignored: true });
    }
  } catch (err) {
    sendError(res, err);
  }
});

export default router;
