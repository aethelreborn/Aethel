import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { startScheduler } from './jobs/scheduler.js';
import authRoutes from './modules/auth/auth.routes.js';
import vaultRoutes from './modules/vault/vault.routes.js';
import billingRoutes from './modules/billing/billing.routes.js';
import schedulesRoutes from './modules/schedules/schedules.routes.js';
import deviceRoutes from './modules/notifications/notifications.routes.js';
import errorHandler from './middleware/errorHandler.middleware.js';
import { SyncGateway } from './websocket/syncGateway.js';

const app = express();

app.use(helmet());
app.use(cors({ origin: env.FRONTEND_URL, credentials: true }));
app.use(express.json({ limit: '10kb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/auth', authRoutes);
app.use('/vault', vaultRoutes);
app.use('/billing', billingRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/devices', deviceRoutes);

app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));
app.use(errorHandler);

startScheduler();
const syncGateway = new SyncGateway(env.WS_PORT);

const server = app.listen(env.PORT, () => {
  console.log(`[Server] Running on http://localhost:${env.PORT}`);
  console.log(`[WS]     Running on ws://localhost:${env.WS_PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[Server] Shutting down...');
  syncGateway.close();
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  server.close(() => process.exit(0));
});
