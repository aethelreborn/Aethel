import { z } from 'zod';
import dotenv from 'dotenv';
dotenv.config();

const optionalText = z.string().trim().min(1).optional();

const schema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().positive().default(3000),
  FRONTEND_URL: z.string().url().default('http://localhost:5173'),
  CORS_ORIGINS: z.string().optional(),
  FCM_PROJECT_ID: optionalText,
  FCM_CLIENT_EMAIL: optionalText,
  FCM_PRIVATE_KEY: optionalText,
  AETHEL_PAY_GATEWAY_URL: z.string().url().default('http://127.0.0.1:6100'),
  AETHEL_PAY_MERCHANT_ID: z.string().trim().min(1).default('00000000-0000-0000-0000-000000000001'),
  AETHEL_PAY_MERCHANT_KEY: optionalText,
  AETHEL_PAY_RETURN_URL: z.string().url().optional(),
});

export const env = schema.parse(process.env);
