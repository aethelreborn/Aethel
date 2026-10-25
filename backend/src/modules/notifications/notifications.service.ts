import { prisma } from '../../config/db.js';
import { getFcm, isFcmConfigured } from '../../config/fcm.js';

export type DeviceInput = {
  pushToken?: string;
  id?: string;
  platform?: string;
};

const LOCAL_ONLY_TOKEN = 'local-only';

export async function registerDevice(userId: string, body: DeviceInput) {
  const platform = body.platform || 'unknown';
  const pushToken = body.pushToken?.trim() || LOCAL_ONLY_TOKEN;

  if (body.id) {
    const existing = await prisma.device.findUnique({ where: { id: body.id } });
    if (existing && existing.userId !== userId) {
      throw new Error('Device already belongs to another account');
    }
    return prisma.device.upsert({
      where: { id: body.id },
      create: { id: body.id, userId, pushToken, platform },
      update: { pushToken, platform, lastActive: new Date() },
      select: { id: true, pushToken: true, platform: true, lastActive: true },
    });
  }

  const existing = await prisma.device.findFirst({
    where: { userId, pushToken },
    select: { id: true },
  });
  if (existing) {
    return prisma.device.update({
      where: { id: existing.id },
      data: { platform, lastActive: new Date() },
      select: { id: true, pushToken: true, platform: true, lastActive: true },
    });
  }

  return prisma.device.create({
    data: { userId, pushToken, platform },
    select: { id: true, pushToken: true, platform: true, lastActive: true },
  });
}

export async function listDevices(userId: string) {
  return prisma.device.findMany({
    where: { userId },
    orderBy: { lastActive: 'desc' },
    select: { id: true, platform: true, lastActive: true },
  });
}

export async function unregisterDevice(userId: string, deviceId: string) {
  const existing = await prisma.device.findFirst({ where: { id: deviceId, userId } });
  if (!existing) throw new Error('Device not found');
  await prisma.device.delete({ where: { id: deviceId } });
}

/**
 * Sends a push to every real FCM token for a user. Device records that were
 * registered without a token ("local-only") are ignored so FCM never receives
 * invalid registrations.
 */
export async function sendPushNotification(
  userId: string,
  payload: { title: string; body: string },
): Promise<number> {
  const devices = await prisma.device.findMany({ where: { userId } });
  const tokens = devices
    .map((device) => device.pushToken)
    .filter((token): token is string => Boolean(token) && token !== LOCAL_ONLY_TOKEN);

  if (tokens.length === 0) return 0;

  await prisma.notificationLog.createMany({
    data: devices
      .filter((device) => tokens.includes(device.pushToken))
      .map((device) => ({
        userId,
        channel: device.platform === 'ios' ? 'push_apns' : 'push_fcm',
        message: JSON.stringify({ title: payload.title, body: payload.body }),
      })),
  });

  const fcm = getFcm();
  if (!fcm) {
    console.log(`[push] User ${userId}: "${payload.title}" logged only (FCM not configured)`);
    return 0;
  }

  try {
    const response = await fcm.sendEachForMulticast({
      notification: payload,
      data: { type: 'aethel_notification', ...payload },
      tokens,
    });
    console.log(`[FCM] Sent ${response.successCount}/${tokens.length} push notifications`);
    return response.successCount;
  } catch (err: any) {
    console.error('[FCM] Push failed:', err.message);
    return 0;
  }
}

export { isFcmConfigured };
