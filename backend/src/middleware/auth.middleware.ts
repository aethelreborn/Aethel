import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { prisma } from '../config/db.js';
import { env } from '../config/env.js';

export interface AuthRequest extends Request {
  userId?: string;
  userEmail?: string;
  tokenVersion?: number;
}

export const authMiddleware = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authorization required' });
      return;
    }

    const token = authHeader.slice(7);
    const payload = jwt.verify(token, env.JWT_SECRET) as {
      userId: string;
      email: string;
      tokenVersion?: number;
    };

    // Every access token must carry a token version. Treating `undefined` as
    // valid would let stale, pre-rotation tokens survive a logout.
    if (typeof payload.tokenVersion !== 'number') {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { tokenVersion: true },
    });
    if (!user) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }
    if (payload.tokenVersion !== user.tokenVersion) {
      res.status(401).json({ error: 'Session invalidated — sign in again' });
      return;
    }

    req.userId = payload.userId;
    req.userEmail = payload.email;
    req.tokenVersion = payload.tokenVersion;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
};
