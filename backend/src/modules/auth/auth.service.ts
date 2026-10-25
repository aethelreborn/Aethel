import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/db.js';
import { env } from '../../config/env.js';

type TokenUser = { id: string; email: string; tokenVersion: number };

export class AuthService {
  private issueTokens(user: TokenUser) {
    const accessToken = jwt.sign(
      { userId: user.id, email: user.email, tokenVersion: user.tokenVersion },
      env.JWT_SECRET,
      { expiresIn: '15m' },
    );
    const refreshToken = jwt.sign(
      { userId: user.id, tokenVersion: user.tokenVersion },
      env.JWT_REFRESH_SECRET,
      { expiresIn: '30d' },
    );
    return { access_token: accessToken, refresh_token: refreshToken };
  }

  private publicUser(user: { id: string; email: string; createdAt: Date }) {
    return { id: user.id, email: user.email, createdAt: user.createdAt };
  }

  async signup(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const existing = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existing) throw new Error('Email already registered');

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.user.create({
      data: { email: normalizedEmail, passwordHash },
      select: { id: true, email: true, createdAt: true, tokenVersion: true },
    });

    return { ...this.issueTokens(user), user: this.publicUser(user) };
  }

  async login(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (!user) throw new Error('Invalid email or master password');

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new Error('Invalid email or master password');

    return { ...this.issueTokens(user), user: this.publicUser(user) };
  }

  async refreshToken(refreshToken: string) {
    let payload: { userId: string; tokenVersion: number };
    try {
      payload = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET) as typeof payload;
    } catch {
      throw new Error('Invalid refresh token');
    }

    const user = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!user) throw new Error('User not found');
    if (payload.tokenVersion !== user.tokenVersion) {
      throw new Error('Session invalidated — sign in again');
    }

    return { ...this.issueTokens(user), user: this.publicUser(user) };
  }

  async logout(userId: string) {
    await prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });
  }

  async me(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, createdAt: true },
    });
    if (!user) throw new Error('User not found');
    return user;
  }

  async changePassword(userId: string, newVerifier: string) {
    const passwordHash = await bcrypt.hash(newVerifier, 12);
    const user = await prisma.user.update({
      where: { id: userId },
      data: { passwordHash, tokenVersion: { increment: 1 } },
      select: { id: true, email: true, createdAt: true, tokenVersion: true },
    });
    return { ...this.issueTokens(user), user: this.publicUser(user) };
  }

  async deleteAccount(userId: string) {
    await prisma.user.delete({ where: { id: userId } });
  }
}
