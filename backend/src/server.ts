import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { isFcmConfigured } from './config/fcm.js';
import authRoutes from './modules/auth/auth.routes.js';
import vaultRoutes from './modules/vault/vault.routes.js';
import billingRoutes from './modules/billing/billing.routes.js';
import schedulesRoutes from './modules/schedules/schedules.routes.js';
import paymentsRoutes from './modules/payments/payments.routes.js';
import { deviceRoutes, timelineRoutes } from './modules/notifications/notifications.routes.js';
import { errorHandler } from './middleware/errorHandler.middleware.js';
import { DueDateCheckJob } from './jobs/dueDateCheck.job.js';
import { initSyncGateway, syncGateway as gatewayInstance } from './websocket/syncGateway.js';

const app = express();

app.use(helmet());

// Auth is Bearer-token only (Authorization header; no cookies), so CORS is a
// browser *read* gate, not an ambient-credential boundary. Reflect any
// browser origin instead of a single FRONTEND_URL — that allowlist broke
// every time a dashboard mirror was added (Vercel, Cloudflare dpdns, local).
// credentials stays false so a reflected origin can never carry cookies.
// Native clients send no Origin header and are always allowed.
app.use(cors({
  origin: true,
  credentials: false,
}));

// /payments is mounted before the global express.json() because its /webhook
// route must read the raw request body bytes for HMAC verification; re-parsing
// and re-serializing JSON would break the signature. Other modules mount below.
app.use('/payments', paymentsRoutes);

app.use(express.json({ limit: '256kb' }));

app.use('/auth', authRoutes);
app.use('/vault', vaultRoutes);
app.use('/billing', billingRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/timeline', timelineRoutes);
app.use('/devices', deviceRoutes);

app.get(['/health', '/api/health'], (_req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    push: isFcmConfigured() ? 'configured' : 'disabled',
  });
});

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});
app.use(errorHandler);

DueDateCheckJob.start();

const server = app.listen(env.PORT, () => {
  // Attach the WebSocket gateway to the same HTTP server (path /ws) so
  // hosts that expose a single port (Render, Railway) can serve both.
  initSyncGateway(server);
  console.log(`[Server] http://localhost:${env.PORT}`);
  console.log(`[WebSocket] ws://localhost:${env.PORT}/ws`);
  console.log(`[Push] ${isFcmConfigured() ? 'FCM configured' : 'disabled (optional)'}`);
});

let shuttingDown = false;
function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[Server] ${signal} received, shutting down`);
  try {
    gatewayInstance.close();
  } catch {
    // Gateway was never initialised.
  }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
