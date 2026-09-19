import express from 'express';
import cors from 'cors';
import { env } from './config/env.js';
import authRoutes from './modules/auth/auth.routes.js';
import vaultRoutes from './modules/vault/vault.routes.js';
import billingRoutes from './modules/billing/billing.routes.js';
import schedulesRoutes from './modules/schedules/schedules.routes.js';
import notificationsRoutes from './modules/notifications/notifications.routes.js';
import { errorHandler } from './middleware/errorHandler.middleware.js';
import { DueDateCheckJob } from './jobs/dueDateCheck.job.js';
import { initSyncGateway, syncGateway as gatewayInstance } from './websocket/syncGateway.js';

const app = express();

app.use(cors({ origin: env.FRONTEND_URL, credentials: true }));
app.use(express.json());

app.use('/auth', authRoutes);
app.use('/vault', vaultRoutes);
app.use('/billing', billingRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/timeline', notificationsRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

app.use(errorHandler);

DueDateCheckJob.start();
initSyncGateway(env.WS_PORT);

const server = app.listen(env.PORT, () => {
  console.log(`[Server] Running on http://localhost:${env.PORT}`);
  console.log(`[WebSocket] Running on ws://localhost:${env.WS_PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[Server] Shutting down...');
  gatewayInstance.close();
  server.close(() => process.exit(0));
});
