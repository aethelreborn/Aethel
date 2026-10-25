import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { env } from './env.js';

let messaging: Messaging | null = null;

export function isFcmConfigured(): boolean {
  return Boolean(env.FCM_PROJECT_ID && env.FCM_CLIENT_EMAIL && env.FCM_PRIVATE_KEY);
}

/**
 * FCM is optional. A missing or malformed credential set must never stop the
 * API from booting, because email/password auth, vault sync and billing all
 * work without push notifications.
 */
export function getFcm(): Messaging | null {
  if (!isFcmConfigured()) return null;
  if (messaging) return messaging;

  try {
    if (getApps().length === 0) {
      initializeApp({
        credential: cert({
          projectId: env.FCM_PROJECT_ID,
          clientEmail: env.FCM_CLIENT_EMAIL,
          privateKey: env.FCM_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        }),
      });
    }
    messaging = getMessaging();
    return messaging;
  } catch (err) {
    console.error('[FCM] Disabled: could not initialise Firebase Admin.', err);
    return null;
  }
}
