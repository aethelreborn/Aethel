import { prisma } from '../../config/db.js';
import { Response, NextFunction } from 'express';
import { fcm, isFcmConfigured } from '../../config/fcm.js';

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

/**
 * Register a device for push notifications (standalone function for programmatic use)
 */
export async function registerDeviceForPush(
  userId: string,
  body: { pushToken?: string; id?: string; platform?: string }
) {
  return prisma.device.upsert({
    where: { id: body.id ?? undefined },
    create: { id: body.id ?? undefined, userId, pushToken: body.pushToken || 'local-only', platform: body.platform || 'web' },
    update: { pushToken: body.pushToken, platform: body.platform || 'web', lastActive: new Date() },
    select: { id: true, pushToken: true, platform: true },
  });
}

/**
 * Send push notifications to all devices for a user.
 * Falls back to logging only if FCM is not configured.
 */
export async function sendPushNotification(userId: string, payload: { title: string; body: string }): Promise<number> {
  const devices = await prisma.device.findMany({ where: { userId } });
  const tokens = devices.map(d => d.pushToken).filter(Boolean) as string[];

  // Always log to notification_logs for audit trail
  await prisma.notificationLog.createMany({
    data: devices.map((d) => ({
      userId,
      channel: d.platform === 'ios' ? 'push_apns' : 'push_fcm',
      message: JSON.stringify({ title: payload.title, body: payload.body }),
    })),
  });

  // If FCM is configured, send real pushes
  if (isFcmConfigured() && tokens.length > 0) {
    try {
      const message = {
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: { type: 'aethel_notification', title: payload.title, body: payload.body },
        tokens,
      };

      const response = await fcm.sendEachForMulticast(message);
      console.log(`[FCM] Sent ${response.successCount}/${tokens.length} push notifications`);
      return response.successCount;
    } catch (err: any) {
      console.error('[FCM] Push failed:', err.message);
    }
  } else {
    console.log(`[push] User ${userId}: ${payload.title} -> ${tokens.length} device(s) [FCM not configured, logged only]`);
  }

  return devices.length;
}
