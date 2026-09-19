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
      const token = req.headers.cookie?.split('=')[1];
      if (token) {
        try {
          const payload = jwt.verify(token.replace('token=', ''), env.JWT_SECRET) as { userId: string };
          ws.userId = payload.userId;
          this.clients.set(payload.userId, ws);
          console.log(`[WS] User ${payload.userId} connected`);
        } catch {
          incomingWs.close();
        }
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
