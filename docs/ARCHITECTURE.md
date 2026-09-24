# Aethel — Architecture

**Last updated:** 2026-09-20
**Read with:** `PRD.md` (requirements), `TASKS.md` (known gaps → fixes), `RULES.md` (conventions)
**Legend:** ✅ implemented · 🟡 partial/stub · ❌ missing · 💀 dead code (not reachable)

---

## 1. System Context

```
┌───────────────────────── FLUTTER CLIENT (Dart) ─────────────────────────┐
│  UI Layer: Dashboard / Vault / Bills / Focus / Settings                 │
│  Crypto:   Argon2id KDF  + AES-256-GCM  (key NEVER leaves device)       │
│  Local:    SQLCipher cache (sqflite_sqlcipher)                           │
│  Bio:      local_auth (Face ID / Fingerprint)                            │
│  Network:  Dio (HTTPS) + WebSocket (WSS)                                 │
│  Android:  UsageStatsManager + Overlay  (Phase 3)                        │
│  iOS:      FamilyControls / ManagedSettings / DeviceActivity (Phase 3)   │
└──────────────────────────────────┬───────────────────────────────────────┘
                                   │ HTTPS: ciphertext + IV only (REST)
                                   │ WSS:   real-time sync events
                    ┌──────────────▼──────────────────────────────┐
                    │ BACKEND (Node.js + TS + Express)            │
                    │  Express + JWT Auth                         │
                    │  Jobs (node-cron): due-date / price-change  │
                    │  Push: FCM (Android) / APNs (iOS)           │
                    │  WebSocket Gateway (ws) — multi-device sync │
                    └──────────────┬──────────────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │ POSTGRESQL (Prisma ORM)     │
                    │ users, vault_items          │
                    │ billing_items, schedules    │
                    │ devices, notification_logs  │
                    └─────────────────────────────┘
```

**Trust boundary — the one rule that governs everything:** anything sensitive (passwords, secure notes) is encrypted **on the device, before it touches the network**. The backend, the database, and anyone who breaches either only ever sees ciphertext. Titles/labels ("Netflix", "Electricity Bill") stay plaintext since they aren't secret and must be searchable/sortable server-side.

---

## 2. Repository Layout

```
Aethel/
├── docs/                    # this documentation set
│   ├── PRD.md               # product requirements
│   ├── ARCHITECTURE.md      # this file
│   ├── RULES.md             # engineering + security rules
│   ├── DESIGN.md            # design system + UX
│   ├── TASKS.md             # work tracker
│   └── MEMORY.md            # AI/agent persistent memory
├── aethel_app/                 # Flutter frontend
├── backend/                 # Node.js + TypeScript backend
├── docker-compose.yml       # PostgreSQL 16 service
├── PLAN.md                  # legacy phase plan (superseded by docs/)
└── app_specification_document.md  # original spec (source for docs/)
```

---

## 3. Flutter Client Architecture

### 3.1 Directory structure (spec §4.1 — target)

```
lib/
├── main.dart                    # entry point (wires app + providers)
├── app.dart                     # AethelApp MaterialApp  ❌ MISSING (spec requires)
├── core/
│   ├── constants/               # colors.dart  (+ spacing/strings  ❌)
│   ├── theme/                   # app_theme.dart (+ text_styles.dart  ❌)
│   ├── crypto/                  # kdf_service, aes_service, secure_key_store
│   ├── network/                 # api_client (Dio), websocket_client
│   └── utils/                   # ❌ empty
├── data/
│   ├── local/                   # database.dart, daos/ (💀 not initialized)
│   ├── remote/                  # ❌ no *_api.dart files
│   └── repositories/            # vault_repository, billing_repository (💀)
├── domain/models/               # models.dart (+ usecases/ ❌)
├── features/                    # dashboard, vault, bills_subscriptions,
│                                # focus_blocker, auth, settings
│                                # (each: presentation/ + providers/)
├── platform/                    # ❌ android/ios channels absent (Phase 3)
└── widgets/                     # ❌ timeline_tile, urgency_card, app_fab absent
```

### 3.2 State management — Riverpod

- `ProviderScope` at root (`main.dart`).
- AsyncNotifier/StateNotifier providers per feature; `AsyncNotifierProvider` maps to "load local cache instantly, then reconcile with server".
- **Timeline pattern:** every feature module publishes events to a shared `timelineProvider`; Dashboard reads it. This makes the unified timeline possible without coupling modules.

### 3.3 Crypto key lifecycle (target)

```
master password
      │  KDF (Argon2id)   ← on-device ONLY
      ▼
AES-256-GCM key  ──►  flutter_secure_storage (Keystore/Keychain)
      │                     keys: aethel_aes_key, aethel_salt
      ├── encrypt(payload, iv)  → base64(ciphertext||tag||iv) → server
      └── decrypt(ciphertext)   ← biometric re-auth BEFORE each reveal
```

**Current-state gaps (from audit) — see TASKS-001/002/003:**
- `secure_key_store.getDerivedKey()` derives from **empty password** (`KdfService.deriveKey('', salt)`) — wrong key, GCM auth fails. Correct path `readKey()` exists but is unused.
- Three inconsistent storage key names: `aethel_aes_key`/`aethel_salt` (written by setup) vs `master_key` (read by vault_edit, never written) vs legacy `vault_key` (removed).
- KDF is single-round **HKDF-SHA256** (spec mandates Argon2id) — upgrade planned (TASK-012).
- `vault_edit_screen` treats base64 string bytes as AES key and sends `iv: ''` — ciphertext saved there is unreadable (TASK-003).

### 3.4 Network

- `api_client.dart` — Dio singleton; JWT interceptor; auto-refresh on 401 via `/auth/refresh`; clears tokens on refresh failure. Tokens currently **in-memory only** (lost on restart) — persist securely (TASK-0xx). Default base URL `http://localhost:3000` — needs per-platform override + Android cleartext config (TASK).
- `websocket_client.dart` — WSS to `ws://host:3001`, token-in-query, 30 s heartbeat, backoff reconnect, dispatches `vault.*`/`billing.*` events. 💀 **Never connected** (sync provider never instantiated — see §5).

### 3.5 Local cache (SQLCipher)

- `data/local/database.dart` — `sqlcipher.openDatabase(dbPath, password: base64UrlEncode(key))`; tables `vault_items`, `billing_items` (+2 indexes). `_onUpgrade` is an empty stub.
- DAOs: `vault_dao`, `billing_dao`. Repositories: `vault_repository`, `billing_repository`.
- 💀 **`AethelDatabase.init()` has zero callers** — entire layer unreachable (TASK-007). Mixing `sqflite` (DAOs) + `sqflite_sqlcipher` (facade) = method-channel conflict risk (TASK).

### 3.6 Navigation (current)

- No router package. `MaterialApp` with `home: SplashScreen` + 4 named routes (`/onboarding`, `/login`, `/master-password`, `/dashboard`).
- `main.dart:19` `ProviderScope(overrides: [syncInitializerProvider])` — ❌ type error (bare Provider ≠ Override) and the provider is never read, so WS sync never activates (TASK-004).
- Screens status: Splash ✅ → Onboarding ✅ → MasterPasswordSetup ✅ (uncommitted changes) · Login ✅ (uncommitted) · Dashboard ✅ (5-tab bottom nav) · VaultGrid ✅ (wired to vaultProvider) · VaultDetail 🟡 (decrypt placeholder, compile error `FlutterSecureStorage` unimported) · VaultEdit 🟡 (encryption broken) · BillsScreen ❌ mock data · BillEditScreen 💀 unreachable · FocusPanel 🟡 no-op timers · ScheduleEditor 💀 unreachable · Settings ❌ inert tiles.

---

## 4. Backend Architecture

### 4.1 Entry points

- **LIVE:** `backend/src/server.ts` (package.json `main: dist/server.js`, `dev: ts-node src/server.ts`, tsconfig `rootDir: ./src`).
- 💀 **DEAD:** `backend/server.ts` (root) — would crash (imports resolve to nothing; imports `errorHandler` as default but file only has named export). Never compiled.
- 💀 **DEAD:** `backend/src/app.ts` — "app factory" 16 lines, mounts no modules, never imported. Consolidate live server onto it (TASK-009).

### 4.2 src/server.ts (live) middleware stack

```
cors(origin: env.FRONTEND_URL, credentials)  →  express.json()  →  routes
  /auth  /vault  /billing  /schedules  /timeline  →  /health  →  errorHandler
DueDateCheckJob.start()   ;   new SyncGateway(env.WS_PORT)
```
Gaps: ❌ helmet, ❌ 10 kb body limit, ❌ JSON 404 handler (default HTML 404), `/timeline` mislabeled vs `/devices` (TASK-009).

### 4.3 Module layout (spec §5.1)

```
src/
├── server.ts                  # boot (live)       ; server.ts (root, dead)
├── app.ts                     # app factory (dead → consolidate)
├── config/env.ts  db.ts       # Zod env validation + Prisma singleton
├── middleware/                # auth, errorHandler, rateLimiter,
│                              #   rejectPlaintext, validate
├── modules/
│   ├── auth/{routes,service}          # ❌ no controller files (spec names them)
│   ├── vault/{routes,service}
│   ├── billing/{routes,service}
│   ├── schedules/{routes,service}
│   └── notifications/{routes,service}
├── jobs/                      # scheduler, dueDateCheck.job, priceChangeCheck.job
├── websocket/syncGateway.ts
└── prisma/schema.prisma
```

### 4.4 Middleware status

| Middleware | Implemented | Used | Notes |
|---|---|---|---|
| `auth` (JWT verify) | ✅ | ✅ vault/billing/schedules/timeline | imports `'../config/env'` w/o `.js` (inconsistent) |
| `rejectPlaintext` | ✅ | 🟡 vault POST/PUT only | Fails open: only checks snake_case `encrypted_payload`; ≥20-char plaintext passes |
| `validateBody` (Zod) | ✅ | ❌ **nowhere** | zero callers; no endpoint validates input |
| `rateLimiter` | ✅ | 🟡 auth signup/login/refresh only | not on logout |
| `errorHandler` | ✅ | ✅ both servers | plain `new Error()` → 500; no Prisma-code→status map (P2002→409) |

### 4.5 API surface (target spec §5.2 → current)

| Spec endpoint | Current | Status |
|---|---|---|
| `POST /auth/signup` | `/auth/signup` | ✅ (no input validation) |
| `POST /auth/login` | `/auth/login` | ✅ |
| `POST /auth/refresh` | `/auth/refresh` | 🟡 stateless rotation, no revocation |
| `POST /auth/logout` | `/auth/logout` | 🟡 **stub**, no revocation |
| `GET/POST/PATCH/DELETE /vault/items[...]` | `/vault` + `PUT /vault/:id` | ❌ path + verb drift |
| `GET/POST/PATCH/DELETE /billing/items[...]` | `/billing`; **no PATCH**; `POST /:id/paid` | ❌ PATCH missing, path drift |
| `GET/POST/PATCH/DELETE /schedules` | `PUT /schedules/:id` | ❌ verb drift |
| `POST /devices/register` | **unmounted** (functions exist in service) | ❌ 404 |
| `WS /sync` | `ws://host:3001` no path | 🟡 skeleton, never broadcasts |

### 4.6 Security notes
- bcrypt cost 12, access 15 m / refresh 7 d — ✅.
- Refresh rotation is **stateless**: old tokens valid 7 d; no `jti`/blacklist/`tokenVersion` → server-side revocation impossible today (TASK-011).
- Vault/schedules `update` passes full `req.body` to Prisma → **mass-assignment**: client could change `userId`/`itemType`/`id` (TASK-010).
- Auth: email not normalized (case-sensitive dupes), no password-strength rules.

---

## 5. Real-time Sync (Phase 2 — target)

```
Create/Update/Delete (REST) ─────┐
                                 ▼
                       notifications/sync event
                                 ▼
                 SyncGateway.broadcast(userId, changeType, entity)
                                 ▼
                    all WS sockets for that userId
                                 ▼
           Flutter WebSocketClient → invalidate local providers
                                 ▼
                timelineProvider / vaultProvider / billingProvider
                                 ▼
                      SQLCipher cache update
```
- 💀 `broadcast()` never invoked; `clients` is `Map<userId, ws>` (one socket/user — no fan-out); auth is cookie-parsed for a Bearer-header client; missing token ⇒ socket stays open **unauthenticated** (TASK-014).
- `sync_initializer_provider` + `sync_provider` exist but are never instantiated (main.dart bug).

---

## 6. Jobs (node-cron)

| Job | Runs? | Behavior |
|---|---|---|
| `DueDateCheckJob` (dueDateCheck.job.ts) | ✅ live (src/server.ts) | bills due ≤7 d; writes `channel: 'in_app'` logs only — **never calls push**; daily-repeat dedupe bug; ignores overdue items + `study_schedules` |
| `scheduler.ts` `dueDateCheckJob` (24 h window + push calls) | 🟡 **never runs** — only wired in dead root server.ts | the "correct" impl, orphaned |
| `priceChangeCheck.job.ts` | ❌ placeholder (`void recent;`), `startPriceScheduler` uncalled | needs `PriceHistory` table (absent) |

Fix: consolidate into one scheduled set of jobs that calls `notifications.service.sendPushNotification` and stamps `last_notified_at` correctly (TASK-013).

---

## 7. Data Model (Prisma)

Schema ↔ migration.sql are in sync (all 6 tables + enums + FK CASCADE + indexes). Spec §6 field-name drift (snake_case vs camelCase, `time` vs `TIMESTAMP(3)`) is documented-only.

**Missing models/columns (TASK-011/013/015):**
- `PriceHistory` (price-change job)
- refresh-token session table or `tokenVersion` on `users`
- `billing_items.snoozed_until`
- `notification_logs` message/content columns
- `billing_items.paid_at` (for "Paid" tab)

---

## 8. Deployment

- `docker-compose.yml`: PostgreSQL 16, db `aethel`, postgres/postgres, port 5432.
- Backend env (`backend/.env.example`): `DATABASE_URL`, `JWT_SECRET`/`JWT_REFRESH_SECRET` (≥32 chars), `NODE_ENV`, `PORT` (3000), `WS_PORT` (3001), `FRONTEND_URL`. **No `.env` present on disk** — `env.ts` throws without it.
- Flutter run: `flutter run` from `aethel_app/` (needs platform scaffolding — none exists ❌ / assets/ absent ❌).
- **`express` missing from backend `dependencies`** (transitive peer only) — prod install risk (TASK-008).
- `docs/analysis_options.yaml` holds the analyzer config; repo root no longer has one, so `flutter analyze` from `aethel_app/` won't discover it (TASK-016).

---

## 9. Known Gaps → Tasks Index

| Gap | TASK ref |
|---|---|
| Compile blockers (main.dart overrides, unimported FlutterSecureStorage, no assets/) | TASK-001, 002 |
| Empty-password key bug / key-name mismatch / broken vault-edit encryption | TASK-003 |
| Sync never activated; WS gateway auth/fan-out/broadcast | TASK-004, 014 |
| Dead DB layer (init never called) | TASK-007 |
| Backend consolidation (dead server.ts/app.ts, express dep, 404/helmet/limit) | TASK-008, 009 |
| Mass-assignment + missing Zod validation | TASK-010, 006 |
| Token revocation / logout | TASK-011 |
| Argon2id upgrade | TASK-012 |
| Jobs consolidation + PriceHistory + real push | TASK-013, 015 |
| Feature wiring (bills mock, unreachable edit/schedule screens, inert settings, no signup, providers auto-fetch) | TASK-005, 017, 018 |