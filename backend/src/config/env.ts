import { z } from 'zod';
import dotenv from 'dotenv';
dotenv.config();

const schema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().positive().default(3000),
  WS_PORT: z.coerce.number().positive().default(3001),
  FRONTEND_URL: z.string().url().default('http://localhost:5173'),
});

export const env = schema.parse(process.env);
