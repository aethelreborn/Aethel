import { WebSocketServer, WebSocket } from 'ws';
import { prisma } from '../config/db.js';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

interface ConnectedClient extends WebSocket {
  userId?: string;
}

export class SyncGateway {
  private wss: WebSocketServer;
  private clients: Map<string, ConnectedClient> = new Map();

  constructor(port: number) {
    this.wss = new WebSocketServer({ port });

    this.wss.on('connection', (incomingWs, req) => {
      const ws = incomingWs as ConnectedClient;

      // Extract token from URL query param (?token=<JWT>) — this is how the
      // Flutter client sends it; cookie parsing is unreliable across platforms.
      const url = req.url ?? '';
      const tokenMatch = url.match(/[?&]token=([^&]+)/);
      const token = tokenMatch ? decodeURIComponent(tokenMatch[1]) : null;

      if (token) {
        try {
          const payload = jwt.verify(token, env.JWT_SECRET) as { userId: string };
          ws.userId = payload.userId;
          this.clients.set(payload.userId, ws);
          console.log(`[WS] User ${payload.userId} connected`);
        } catch {
          incomingWs.close();
        }
      } else {
        incomingWs.close();
      }
    });

    this.wss.on('close', () => {
      console.log('[WS] Server closed');
    });
  }

  broadcast(userId: string, event: string, data: any) {
    const client = this.clients.get(userId);
    if (client && client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({ event, data }));
    }
  }

  close() {
    this.wss.close();
  }
}

// ── Singleton instance ────────────────────────────────────────────────────────
// Exported so modules (vault.service, billing.service) can import and broadcast
// events. The real WebSocket port is set via [init()] called from server.ts.
let _instance: SyncGateway | null = null;

export function getSyncGateway(): SyncGateway {
  if (!_instance) throw new Error('SyncGateway not initialized — call init(port) first');
  return _instance;
}

export function initSyncGateway(port: number): SyncGateway {
  _instance = new SyncGateway(port);
  return _instance;
}

export const syncGateway = {
  get broadcast() { return getSyncGateway().broadcast.bind(getSyncGateway()); },
  get close() { return getSyncGateway().close.bind(getSyncGateway()); },
};
