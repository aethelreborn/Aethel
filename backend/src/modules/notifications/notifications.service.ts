import { prisma } from '../../config/db.js';
import { Response, NextFunction } from 'express';

export async function registerDevice(
  userId: string,
  body: { pushToken?: string; id?: string; platform?: string },
  res: Response,
  next: NextFunction
) {
  try {
    const device = await prisma.device.upsert({
      where: { id: body.id ?? undefined },
      create: { id: body.id ?? undefined, userId, pushToken: body.pushToken || 'local-only', platform: body.platform || 'web' },
      update: { pushToken: body.pushToken, platform: body.platform || 'web', lastActive: new Date() },
      select: { id: true, pushToken: true, platform: true },
    });
    res.status(201).json(device);
  } catch (err) { next(err as Error); }
}

export async function listDevices(userId: string, res: Response, next: NextFunction) {
  try {
    const devices = await prisma.device.findMany({ where: { userId }, orderBy: { lastActive: 'desc' } });
    res.json(devices);
  } catch (err) { next(err as Error); }
}

export async function unregisterDevice(
  userId: string,
  paramId: string,
  res: Response,
  next: NextFunction
) {
  try {
    const existing = await prisma.device.findFirst({ where: { id: paramId, userId } });
    if (!existing) { res.status(404).json({ error: 'Device not found' }); return; }
    await prisma.device.delete({ where: { id: paramId } });
    res.json({ message: 'Device removed' });
  } catch (err) { next(err as Error); }
}

export async function sendPushNotification(userId: string, payload: { title: string; body: string }) {
  const devices = await prisma.device.findMany({ where: { userId } });
  console.log('[push] User ' + userId + ': ' + payload.title + ' -> ' + devices.length + ' device(s)');
  await prisma.notificationLog.createMany({
    data: devices.map((d) => ({
      userId,
      channel: d.platform === 'ios' ? 'push_apns' : 'push_fcm',
      message: JSON.stringify({ title: payload.title, body: payload.body }),
    })),
  });
  return devices.length;
}
