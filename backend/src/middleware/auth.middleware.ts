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
      return res.status(401).json({ error: 'Authorization required' });
    }

    const token = authHeader.slice(7);
    const payload = jwt.verify(token, env.JWT_SECRET) as { userId: string; email: string; tokenVersion?: number };

    // Check token version matches current user record
    const user = await prisma.user.findUnique({ where: { id: payload.userId }, select: { tokenVersion: true } });
    if (!user) return res.status(401).json({ error: 'Invalid or expired token' });
    if (payload.tokenVersion !== undefined && payload.tokenVersion < user.tokenVersion) {
      return res.status(401).json({ error: 'Session invalidated — log in again' });
    }

    req.userId = payload.userId;
    req.userEmail = payload.email;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
