import * as admin from 'firebase-admin';
import { getMessaging } from 'firebase-admin/messaging';
import { cert, getApps } from 'firebase-admin/app';

if (getApps().length === 0) {
  admin.initializeApp({
    credential: cert({
      projectId: process.env.FCM_PROJECT_ID,
      clientEmail: process.env.FCM_CLIENT_EMAIL,
      privateKey: process.env.FCM_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

export const fcm = getMessaging();

export function isFcmConfigured(): boolean {
  return !!process.env.FCM_PROJECT_ID && !!process.env.FCM_CLIENT_EMAIL;
}
