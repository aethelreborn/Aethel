// Vault / billing endpoints only accept pre-encrypted ciphertext payloads.
// Rejects anything that looks like plaintext as a second line of defense.
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';

const base64CiphertextSchema = z.object({
  encryptedPayload: z.string().min(20, 'encryptedPayload must be valid ciphertext'),
  iv: z.string().min(12, 'iv must be a valid initialization vector'),
});

/**
 * Middleware: ensure vault/billing POST/PATCH bodies contain only
 * shaped ciphertext fields — no raw passwords or secrets can leak through here.
 */
export function rejectPlaintext(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const body = req.body as Record<string, unknown>;
  if (body.encrypted_payload !== undefined) {
    const result = base64CiphertextSchema.safeParse({
      encryptedPayload: body.encrypted_payload,
      iv: body.iv,
    });
    if (!result.success) {
      res.status(400).json({
        error: 'Vault endpoint received plaintext instead of ciphertext',
        details: result.error.issues,
      });
      return;
    }
  }
  next();
}
