import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { isFcmConfigured } from './config/fcm.js';
import authRoutes from './modules/auth/auth.routes.js';
import vaultRoutes from './modules/vault/vault.routes.js';
import billingRoutes from './modules/billing/billing.routes.js';
import schedulesRoutes from './modules/schedules/schedules.routes.js';
import { deviceRoutes, timelineRoutes } from './modules/notifications/notifications.routes.js';
import { errorHandler } from './middleware/errorHandler.middleware.js';
import { DueDateCheckJob } from './jobs/dueDateCheck.job.js';
import { initSyncGateway, syncGateway as gatewayInstance } from './websocket/syncGateway.js';

const app = express();

app.use(helmet());

const configuredOrigins = new Set(
  [env.FRONTEND_URL, ...(env.CORS_ORIGINS ?? '').split(',')]
    .map((origin) => origin.trim())
    .filter(Boolean),
);

app.use(cors({
  origin(origin, callback) {
    // Native clients do not send an Origin header. In development every origin
    // is permitted so Flutter web can run on any local port.
    if (!origin || env.NODE_ENV !== 'production' || configuredOrigins.has(origin)) {
      callback(null, true);
      return;
    }
    callback(new Error('Origin not allowed'));
  },
  credentials: true,
}));

app.use(express.json({ limit: '256kb' }));

app.use('/auth', authRoutes);
app.use('/vault', vaultRoutes);
app.use('/billing', billingRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/timeline', timelineRoutes);
app.use('/devices', deviceRoutes);

app.get('/health', (_req, res) => {
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
initSyncGateway(env.WS_PORT);

const server = app.listen(env.PORT, () => {
  console.log(`[Server] http://localhost:${env.PORT}`);
  console.log(`[WebSocket] ws://localhost:${env.WS_PORT}`);
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
