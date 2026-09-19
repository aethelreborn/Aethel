import { WebSocketServer, WebSocket } from 'ws';
import { prisma } from '../config/db.js';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

interface ConnectedClient extends WebSocket {
  userId?: string;
}

export class SyncGateway {
  private wss: WebSocketServer;
  // Map<userId, Set<ConnectedClient>> — supports multi-device fan-out
  private clients: Map<string, Set<ConnectedClient>> = new Map();

  constructor(port: number) {
    this.wss = new WebSocketServer({ port });

    this.wss.on('connection', (incomingWs, req) => {
      const ws = incomingWs as ConnectedClient;

      // Extract token from URL query param (?token=<JWT>)
      const url = req.url ?? '';
      const tokenMatch = url.match(/[?&]token=([^&]+)/);
      const token = tokenMatch ? decodeURIComponent(tokenMatch[1]) : null;

      if (!token) {
        // No token at all — close immediately
        incomingWs.close(1008, 'Missing authentication token');
        return;
      }

      try {
        const payload = jwt.verify(token, env.JWT_SECRET) as { userId: string };
        ws.userId = payload.userId;

        // Add to set (create set if first device for this user)
        let userSet = this.clients.get(payload.userId);
        if (!userSet) {
          userSet = new Set<ConnectedClient>();
          this.clients.set(payload.userId, userSet);
        }
        userSet.add(ws);

        console.log(`[WS] User ${payload.userId} connected`);

        // Handle close/error — remove from set
        ws.on('close', () => {
          this.removeClient(payload.userId, ws);
          console.log(`[WS] User ${payload.userId} disconnected`);
        });
        ws.on('error', (err) => {
          console.error(`[WS] User ${payload.userId} error:`, err.message);
          this.removeClient(payload.userId, ws);
        });

      } catch (e) {
        // Invalid/expired token — close immediately
        console.log(`[WS] Authentication failed, closing connection`);
        incomingWs.close(1008, 'Invalid or expired token');
      }
    });

    this.wss.on('close', () => {
      console.log('[WS] Server closed');
    });
  }

  private removeClient(userId: string, ws: ConnectedClient) {
    const userSet = this.clients.get(userId);
    if (userSet) {
      userSet.delete(ws);
      if (userSet.size === 0) {
        this.clients.delete(userId);
      }
    }
  }

  broadcast(userId: string, event: string, data: any) {
    const userSet = this.clients.get(userId);
    if (!userSet || userSet.size === 0) return;

    const payload = JSON.stringify({ event, data });
    for (const ws of userSet) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(payload);
      }
    }
  }

  close() {
    this.wss.close();
  }
}

// ── Singleton instance ────────────────────────────────────────────────────────
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
