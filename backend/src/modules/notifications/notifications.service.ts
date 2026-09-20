import { prisma } from '../../config/db.js';
import { fcm, isFcmConfigured } from '../../config/fcm.js';

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
