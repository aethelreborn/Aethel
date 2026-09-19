# Aethel — Zero-Knowledge Vault & Life Tracker

A secure password vault, bill/subscription tracker, and focus blocker — built with Flutter + Node.js. Your master password never leaves your device; the server only ever sees ciphertext.

## Status

**Phase 1 COMPLETE** ✅ — All screens, crypto layer, backend APIs, and Prisma schema implemented.  
**Build status:** `flutter analyze` = 0 issues · `tsc` = 0 errors

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter / Dart (Riverpod state management) |
| Backend | Node.js / TypeScript / Express |
| Database | PostgreSQL via Prisma ORM |
| Real-time | WebSocket (`ws`) on port 3001 |
| Scheduler | node-cron (every 10 min for due-date checks) |
| Crypto | HKDF-SHA256 KDF + AES-256-GCM (pointycastle) |
| Storage | SQLCipher (sqflite_sqlcipher) for local cache |
| Auth | JWT access (15 min) + refresh tokens (7 days) |

## Project Structure

```
Aether/
├── flutter/                          # Flutter frontend (Dart)
│   ├── lib/
│   │   ├── main.dart                 # Entry point
│   │   ├── core/
│   │   │   ├── constants/colors.dart # §8.2 color tokens (light + dark)
│   │   │   ├── theme/app_theme.dart  # ThemeData builder
│   │   │   ├── crypto/
│   │   │   │   ├── aes_service.dart       # AES-256-GCM encrypt/decrypt
│   │   │   │   ├── kdf_service.dart       # HKDF-SHA256 key derivation
│   │   │   │   └── secure_key_store.dart  # flutter_secure_storage wrapper
│   │   │   └── network/api_client.dart    # Dio + JWT auto-refresh interceptor
│   │   ├── domain/models/models.dart      # User, VaultEntry, BillingEntry, TimelineEvent
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── presentation/screens/
│   │   │   │   │   ├── splash_screen.dart
│   │   │   │   │   ├── onboarding_screen.dart
│   │   │   │   │   └── master_password_setup.dart
│   │   │   │   └── providers/auth_provider.dart
│   │   │   ├── dashboard/
│   │   │   │   └── providers/timeline_provider.dart
│   │   │   ├── vault/presentation/vault_grid_screen.dart
│   │   │   ├── bills_subscriptions/presentation/bills_screen.dart
│   │   │   ├── focus_blocker/presentation/focus_panel_screen.dart
│   │   │   └── settings/presentation/settings_screen.dart
│   │   └── widgets/
│   └── pubspec.yaml
│
├── backend/                         # Node.js + TypeScript server
│   ├── src/
│   │   ├── server.ts               # Express boot, middleware stack, graceful shutdown
│   │   ├── app.ts                  # App factory
│   │   ├── config/
│   │   │   ├── env.ts              # Zod environment validation
│   │   │   └── db.ts               # Prisma singleton
│   │   ├── middleware/
│   │   │   ├── auth.middleware.ts  # JWT verify
│   │   │   ├── rateLimiter.middleware.ts
│   │   │   ├── errorHandler.middleware.ts
│   │   │   ├── rejectPlaintext.middleware.ts
│   │   │   └── validate.middleware.ts
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   │   ├── auth.controller.ts
│   │   │   │   ├── auth.service.ts
│   │   │   │   └── auth.routes.ts
│   │   │   ├── vault/
│   │   │   │   ├── vault.controller.ts
│   │   │   │   ├── vault.service.ts
│   │   │   └── billing/
│   │   │   ├── schedules/
│   │   │   └── notifications/
│   │   ├── jobs/
│   │   │   ├── scheduler.ts        # node-cron bootstrapping
│   │   │   └── dueDateCheck.job.ts
│   │   └── websocket/syncGateway.ts
│   ├── prisma/schema.prisma        # §6 DB schema
│   ├── package.json
│   └── tsconfig.json
│
└── docker-compose.yml               # PostgreSQL service
```

## What's Done (Phase 1 Foundation)

### Flutter Frontend ✅
- [x] Project scaffold with Riverpod
- [x] Color tokens (§8.2) and theme builder (light + dark)
- [x] Crypto layer: AES-256-GCM (`aes_service.dart`) + HKDF-SHA256 (`kdf_service.dart`)
- [x] Secure key store wrapper (`secure_key_store.dart`)
- [x] API client with JWT interceptor + auto-refresh on 401 (`api_client.dart`)
- [x] Domain models: User, VaultEntry, BillingEntry, TimelineEvent with urgency logic
- [x] Splash screen with biometric check
- [x] Onboarding flow (3-page PageView)
- [x] Master password setup screen
- [x] Dashboard with bottom nav (Home, Vault, Bills, Focus tabs)
- [x] Vault grid screen with filter chips (All/Passwords/Cards/Notes)
- [x] Bills screen with tab bar (All/Upcoming/Paid)
- [x] Focus panel screen with countdown timer and quick-start buttons
- [x] Settings screen
- [x] Auth provider (Riverpod StateNotifier)
- [x] Timeline provider (aggregates events from vault + billing)
- [x] **Zero analyzer errors, zero warnings** (only 4 info lints)

### Backend ✅
- [x] Prisma schema with all models (User, VaultItem, BillingItem, StudySchedule, Device, NotificationLog)
- [x] Environment config with Zod validation (`env.ts`)
- [x] Database connection singleton (`db.ts`)
- [x] JWT auth middleware
- [x] Rate limiter for `/auth/*` routes
- [x] Error handler middleware
- [x] Plaintext rejection middleware for vault endpoints
- [x] Zod body validation middleware
- [x] Auth module: signup/login/refresh/logout with bcrypt + JWT
- [x] Vault module: CRUD endpoints (ciphertext-only)
- [x] Billing module: CRUD + markPaid (advances next_due_date)
- [x] Schedules module: CRUD endpoints
- [x] Notifications module: device registration + push notification logging
- [x] Cron job: due-date check every 10 minutes
- [x] WebSocket sync gateway (`syncGateway.ts`)
- [x] Docker Compose for PostgreSQL
- [x] `.env.example` and `.env` files

## What Remains (Phase 2+)

### Flutter
- [ ] Local SQLCipher database integration (`sqflite_sqlcipher`)
- [ ] Repository layer (local-first reads, background reconcile)
- [ ] WebSocket client for real-time sync
- [ ] Vault detail/edit screens with biometric gate
- [ ] Bill edit/add screens with forms
- [ ] Schedule editor screen with `table_calendar`
- [ ] Push notification setup (Firebase FCM Android / APNs iOS)
- [ ] UI polish: urgency colors, max-3-chip rule, dark mode parity

### Backend
- [ ] Controllers with full Zod schema validation per endpoint
- [ ] FCM/APNs push notification integration
- [ ] Price change detection job
- [ ] Backup/export endpoint (encrypted zip)
- [ ] Account deletion with cascade cleanup

### CI/CD
- [ ] GitHub Actions: Flutter analyze + test, backend lint + build
- [ ] Docker multi-stage build

## How to Run

### Backend
```bash
cd backend
cp .env.example .env   # edit DATABASE_URL and secrets
npm install
npx prisma migrate deploy
npm run dev
# Server: http://localhost:3000
# WS:     ws://localhost:3001
```

### Flutter
```bash
cd flutter
flutter pub get
flutter run
```

### Database (Docker)
```bash
docker compose up -d
# PostgreSQL on localhost:5432, db=aethel, user=postgres, pass=password
```

## Design Tokens (§8.2)

### Light Mode
| Token | Value |
|---|---|
| bgPrimary | `#FAFAF9` |
| bgSurface | `#FFFFFF` |
| textPrimary | `#1A1A1E` |
| accent | `#3B6E6B` |
| urgent | `#D64545` |
| upcoming | `#D9A441` |
| informational | `#3F6FBF` |
| resolved | `#4C9A6A` |

### Dark Mode
| Token | Value |
|---|---|
| bgPrimary | `#121316` |
| bgSurface | `#1C1E22` |
| textPrimary | `#F2F2F3` |
| accent | `#5FA39F` |
| urgent | `#E06767` |
| upcoming | `#E0B65C` |
| informational | `#6C93D6` |
| resolved | `#6FBF8A` |

## Verification

**Phase 1 smoke test:**
1. `cd backend && npx prisma migrate deploy && npm run dev` — server starts on :3000
2. `curl -X POST http://localhost:3000/auth/signup -H 'Content-Type: application/json' -d '{"email":"test@test.com","password":"Test1234!"}'` — returns tokens
3. `flutter run` — splash → onboarding → dashboard renders
4. Add vault item → confirm ciphertext in PostgreSQL
5. Biometric gate: vault detail requires re-auth before revealing credential

---

**Name:** Aethel (not LifeVault — name conflict per spec)  
**Security model:** Pure zero-knowledge — server never sees plaintext  
**Recovery:** None — lost master password = lost data forever

---

## Verification Status (2026-09-19)

```
✓ flutter analyze — No issues found!
✓ Backend TypeScript compiles without errors
✓ 17 Flutter Dart files across domain, core, features
✓ 23 Node/TS backend files across config, middleware, modules, jobs
✓ Prisma schema complete (User, VaultItem, BillingItem, StudySchedule, Device, NotificationLog)
✓ PostgreSQL Docker Compose ready (port 5432)
✓ Crypto layer: AES-256-GCM + HKDF-SHA256 (pointycastle 3.9.1, AESEngine)
✓ JWT auth with auto-refresh interceptor
✓ All Phase 1 screens implemented:
  - Splash + biometric check
  - Onboarding (3-page PageView)
  - Master password setup
  - Login
  - Dashboard with Home/Vault/Bills/Focus/Settings tabs
  - Vault grid with filter chips
  - Bills with tab bar (All/Upcoming/Paid)
  - Focus panel with countdown timer
  - Settings screen
```

## Quick Start

```bash
# 1. Database
docker compose up -d

# 2. Backend
cd backend
npx prisma migrate deploy
npm run dev

# 3. Flutter
cd ../flutter
flutter run
```
