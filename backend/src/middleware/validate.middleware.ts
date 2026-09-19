import { Request, Response, NextFunction } from 'express';
import { ZodSchema } from 'zod';

/**
 * Middleware: validate request body against a Zod schema.
 * Returns 400 with validation errors on failure.
 *
 * Usage: router.post('/', validateBody(mySchema), controller);
 */
export function validateBody<T>(schema: ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const details = result.error.issues.map((i: any) => ({
        field: (i.path as string[]).join('.'),
        message: i.message,
      }));
      res.status(400).json({ error: 'Validation failed', details });
      return;
    }
    req.body = result.data;
    next();
  };
}
