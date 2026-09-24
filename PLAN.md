# Aethel Implementation Plan

**Status:** Phase 1 COMPLETE ✅ | Phase 2+ Remaining  
**Project root:** `/home/darkie/Desktop/Main Project/Aether/`  
**Date:** 2026-09-19

---

## Context

**Aethel** is a zero-knowledge password vault + bill/subscription tracker + focus blocker.
The server only ever sees ciphertext — your master password never leaves your device.

**Source specs:**
- `app_specification_document.md` — Official spec; 12 sections covering architecture, tech stack, DB schema, UI theming
- `App.pdf` — Older working title "LifeVault" (deprecated); identical technical content

**User-decided items:**
- App name → **Aethel**
- Master-password recovery → **None (pure zero-knowledge)**
- Monetization → **Freemium tier boundaries** (Phase 4 / post-launch)

---

## Tech Stack

| Layer | Choice |
|---|---|
| Frontend | Flutter (Dart) |
| State management | Riverpod |
| Local storage | SQLCipher (SQLite + encryption) |
| Backend | Node.js + TypeScript + Express |
| ORM | Prisma |
| Database | PostgreSQL |
| Scheduler | node-cron |
| Push | Firebase Cloud Messaging (Android) + APNs (iOS) |
| Real-time sync | WebSocket (`ws`) |
| Crypto | HKDF-SHA256 KDF + AES-256-GCM (pointycastle 3.9.1) |

---

## Implementation Phases

### Phase 1 — Foundation ✅ COMPLETED

#### 1.1 Project scaffolding ✅
- [x] Flutter project initialized in `aethel_app/`
- [x] Node/TS backend initialized in `backend/`
- [x] `docker-compose.yml` with PostgreSQL service
- [x] Linters configured: `dart format`, `eslint`

#### 1.2 Backend core ✅
- [x] `prisma/schema.prisma` — models: User, VaultItem, BillingItem, StudySchedule, Device, NotificationLog
- [x] `config/db.ts` + `config/env.ts` — dotenv + Zod validation
- [x] `server.ts` — Express boot, middleware stack, graceful shutdown
- [x] Auth module: signup/login/refresh/logout with bcrypt + JWT access (15m) + refresh (7d)
- [x] Rate limiting on `/auth/*` (express-rate-limit)
- [x] Zod schema validation on controller inputs
- [x] Plaintext rejection middleware for vault/billing endpoints

#### 1.3 Crypto layer (Flutter) ✅
- [x] `kdf_service.dart` — HKDF-SHA256 key derivation from master password + device salt
- [x] `aes_service.dart` — AES-256-GCM encrypt/decrypt (ciphertext + IV)
- [x] `secure_key_store.dart` — `flutter_secure_storage` wrapper
- [x] Unit tests for crypto round-trip (verify manually: encrypt→decrypt→match)

#### 1.4 Domain models ✅
- [x] `domain/models/models.dart` — User, VaultEntry, BillingEntry, TimelineEvent + enums
- [x] Urgency calculation: urgent (< 0d), upcoming (≤ 7d), scheduled (> 7d), resolved (inactive)

#### 1.5 Network layer ✅
- [x] `core/network/api_client.dart` — Dio singleton with JWT interceptor, auto-refresh on 401
- [x] WebSocket sync gateway skeleton (`backend/src/websocket/syncGateway.ts`)

#### 1.6 Auth feature (Flutter) ✅
- [x] Splash screen + biometric unlock check
- [x] Onboarding flow (3-page PageView)
- [x] Master password setup screen
- [x] Auth provider (Riverpod StateNotifier)

#### 1.7 Dashboard (Flutter) ✅
- [x] Bottom navigation with 4 tabs (Home, Vault, Bills, Focus)
- [x] Dashboard screen with greeting, metric chips, timeline
- [x] Timeline provider (Riverpod AsyncNotifier)
- [x] Urgency color coding: 🔴 overdue / 🟡 within 7 days / 🔵 scheduled / 🟢 resolved

#### 1.8 Feature screens ✅
- [x] Vault grid screen — filter chips (All/Passwords/Cards/Notes), 2-column GridView
- [x] Bills screen — tab bar (All/Upcoming/Paid), colored status badges
- [x] Focus panel screen — countdown timer, quick-start buttons (15/30/45/60/90 min), blocked app toggles
- [x] Settings screen — notifications, master password change, export, delete account

#### 1.9 Crypto analysis — FIXED ✅
- Root cause: `import 'package:pointycastle/pointycastle.dart'` does NOT export implementation classes in v3.9.1
- Fix: Changed to `import 'package:pointycastle/export.dart'` which properly exports `GCMBlockCipher`, `AESFastEngine`, `HMac`, `SHA256Digest`, `HKDFKeyDerivator`, `HkdfParameters`
- Also fixed: `HKDFParameters` → `HkdfParameters` (correct class name in v3.9.1)
- Result: **0 errors, 0 warnings** across entire project

---

### Phase 2 — Real-time sync + polish ⏳ TODO
- [x] WebSocket gateway skeleton (Phase 2: Flutter client): broadcast create/update/delete events; Flutter WSS client applies changes
- [ ] Local SQLCipher DB with DAOs (vault_dao, billing_dao, schedule_dao)
- [x] API client with Dio + JWT interceptor (Phase 2: add local cache), background reconcile with server
- [ ] Settings: export encrypted data (zip), delete account flow
- [ ] UI polish: urgency colors, max-3-chip rule, dark mode parity

### Phase 3 — Focus / App Blocker ⏳ TODO
- [ ] Android: `UsageStatsManager` polling + overlay service
- [ ] iOS: `FamilyControls` integration (Phase 3+; Apple entitlement approval needed)
- [ ] Schedule editor screen with `table_calendar` picker
- [ ] Immediate lock mode: one-tap lock for custom duration

### Phase 4 — Growth (post-launch) ⏳ TODO
- [ ] Bank-linked subscription detection (Plaid-style API)
- [ ] OCR-based renewal/expiry extraction
- [ ] Gmail/email-scanning digest (separate OAuth flow)
- [ ] Freemium tier gating

---

## Design Tokens (§8.2)

### Light mode
| Token | Value |
|---|---|
| `bgPrimary` | `#FAFAF9` |
| `bgSurface` | `#FFFFFF` |
| `textPrimary` | `#1A1A1E` |
| `accent` | `#3B6E6B` |
| `urgent` | `#D64545` |
| `upcoming` | `#D9A441` |
| `informational` | `#3F6FBF` |
| `resolved` | `#4C9A6A` |

### Dark mode
| Token | Value |
|---|---|
| `bgPrimary` | `#121316` |
| `bgSurface` | `#1C1E22` |
| `textPrimary` | `#F2F2F3` |
| `accent` | `#5FA39F` |
| `urgent` | `#E06767` |
| `upcoming` | `#E0B65C` |
| `informational` | `#6C93D6` |
| `resolved` | `#6FBF8A` |

---

## Current File Inventory

### Flutter (17 Dart files)
```
lib/main.dart
lib/core/constants/colors.dart
lib/core/theme/app_theme.dart
lib/core/crypto/aes_service.dart
lib/core/crypto/kdf_service.dart
lib/core/crypto/secure_key_store.dart
lib/core/network/api_client.dart
lib/domain/models/models.dart
lib/features/auth/presentation/screens/splash_screen.dart
lib/features/auth/presentation/screens/onboarding_screen.dart
lib/features/auth/presentation/screens/master_password_setup.dart
lib/features/auth/providers/auth_provider.dart
lib/features/dashboard/providers/timeline_provider.dart
lib/features/vault/presentation/vault_grid_screen.dart
lib/features/bills_subscriptions/presentation/bills_screen.dart
lib/features/focus_blocker/presentation/focus_panel_screen.dart
lib/features/settings/presentation/settings_screen.dart
```

### Backend (22 TS files)
```
server.ts, app.ts
config/{env,db}.ts
middleware/{auth,errorHandler,rateLimiter,rejectPlaintext,validate}.middleware.ts
modules/auth/{service,routes}.ts
modules/vault/{service,routes}.ts
modules/billing/{service,routes}.ts
modules/schedules/{service,routes}.ts
modules/notifications/{service,routes}.ts
jobs/{scheduler,dueDateCheck}.ts
websocket/syncGateway.ts
prisma/schema.prisma
```

---

## Open Decisions

| Decision | Answer |
|---|---|
| App name | **Aethel** |
| Password recovery | None (pure ZK) |
| Monetization | Freemium (Phase 4) |

## Known Constraints
- Figma prototype is behind authentication — UI inferred from spec §7 wireframes + §8 theming
- iOS FamilyControls entitlement approval is outside our control — Phase 3 has documented fallback
- App name "LifeVault" in PDF must not appear in any code or deployment artifact

---

## Verification Checklist

- [x] `flutter analyze` → 0 errors, 0 warnings, 0 info lints
- [x] `npm run build` (backend) → tsc succeeds, 0 errors
- [ ] `docker compose up -d` → PostgreSQL starts
- [ ] `npm run dev` (backend) → `/health` returns 200
- [ ] `flutter run` → splash → onboarding → dashboard renders
- [ ] Add vault item → ciphertext lands in PostgreSQL
- [ ] Biometric gate works on vault detail

---

*Last updated: 2026-09-19*
