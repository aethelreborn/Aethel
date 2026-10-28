# Aethel

Zero-knowledge password vault, bill/subscription tracker, and focus blocker. Flutter app, Node backend, Postgres.

The server only ever sees ciphertext — your master password is derived and used on-device (HKDF-SHA256, AES-256-GCM), so there is no way to read a vault out of the database. There is no password recovery either. Forget the master password and the data is gone for good. That's the tradeoff, don't lose it.

## Running it locally

Postgres first:

```bash
docker compose up -d
```

Backend:

```bash
cd backend
cp .env.example .env   # DATABASE_URL and the rest
npm install
npx prisma migrate deploy
npm run dev            # api on :3000, ws sync on :3001
```

App:

```bash
cd aethel_app
flutter pub get
flutter run
```

## Where things live

- `aethel_app/` — Flutter (Riverpod, SQLCipher for the local cache)
- `backend/` — Express + Prisma, JWT auth with refresh tokens, WebSocket sync gateway, node-cron checking due bills every 10 minutes
- `docs/` — product requirements, architecture notes, design tokens
- `docker-compose.yml` — Postgres for development

What's missing so far: push notifications are half-wired (devices register, sends get logged, but FCM/APNs isn't hooked up), and price-change detection, encrypted backup export, and account deletion don't exist yet.
