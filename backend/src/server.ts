import express from 'express';
import helmet from 'helmet';
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

// 1. Security headers — must be first
app.use(helmet());

// 2. CORS
app.use(cors({ origin: env.FRONTEND_URL, credentials: true }));

// 3. JSON body parser with 10kb size limit
app.use(express.json({ limit: '10kb' }));

// 4. Routes
app.use('/auth', authRoutes);
app.use('/vault', vaultRoutes);
app.use('/billing', billingRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/timeline', notificationsRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// 5. 404 handler — AFTER all routes but BEFORE errorHandler
app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// 6. Error handler — last middleware
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
