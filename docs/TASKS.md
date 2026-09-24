# Aethel — Task Tracker

**Last updated:** 2026-09-20
**Statuses:** `todo` · `in_progress` · `done` · `blocked`
**Priorities:** P0 (blocks launch/security) · P1 (feature) · P2 (nice-to-have)
**Source:** codebase audit (2026-09-19/20). Gaps cross-referenced from `ARCHITECTURE.md` §9 and `PRD.md` §9.

---

## Phase 0 — Stabilize (do first)

| ID | Pri | Status | Task | Target / AC |
|---|---|---|---|---|
| TASK-001 | P0 | todo | Fix compile blockers: `main.dart:19` `overrides: [syncInitializerProvider]` (bare Provider ≠ Override), and `vault_detail_screen.dart` unimported `FlutterSecureStorage`. | `flutter analyze` → 0 errors |
| TASK-002 | P0 | todo | Add missing platform scaffolding + `assets/` so the app can build/run; sync `pubspec` SDK floor with code's Flutter API usage (`withValues`, `CardThemeData`, `Switch.activeThumbColor`). | `flutter build apk --debug` succeeds |
| TASK-003 | P0 | todo | Fix the ZK key flow end-to-end: `getDerivedKey()` must return `readKey()` after biometric (never `deriveKey('', salt)`); unify storage keys to `aethel_aes_key`/`aethel_salt`; fix `vault_edit_screen` (base64-decodes to real bytes, no `master_key`, real `iv`, prefill existing secrets). | Round-trip: save → reopen → decrypt matches plaintext |
| TASK-004 | P1 | todo | Activate sync: create `SyncInitializer` override/auto-start so `syncInitializerProvider`/`SyncNotifier` connect the WS client; confirm `WebSocketClient.connect()` is invoked post-login. | WS connects on dashboard after login |
| TASK-005 | P1 | todo | Make Settings functional: wire change-master-password (with re-key), export-encrypted-zip, delete account, logout, notification prefs. | Each tile performs its action |
| TASK-006 | P0 | todo | Enforce Zod validation: wire `validateBody` on every route; add signup/login/signup schemas; Prisma-code → HTTP mapping (P2002→409, enum→400, not-found→404). | No route accepts unvalidated input |
| TASK-007 | P0 | todo | Wire local cache: call `AethelDatabase.init(key)` at startup; route DAO/repo usage through it; resolve `sqflite` vs `sqflite_sqlcipher` channel conflict (single dialect). | DB file created; reads hit cache |
| TASK-008 | P0 | todo | Backend deps/build: add `express` to `dependencies`; fix `lint` (ESLint flat config or downgrade; drop invalid `.eslintrc.json` + add `@typescript-eslint/*`; remove unused `date-fns` dead-dep or use it). | `npm ci && npm run build && npm run lint` green |

---

## Phase 1 — Backend consolidation & security

| ID | Pri | Status | Task | Target / AC |
|---|---|---|---|---|
| TASK-009 | P0 | todo | Consolidate entry points: delete dead root `server.ts`; fold live `src/server.ts` onto `src/app.ts` (mount modules + middleware); add helmet, 10 kb body limit, JSON 404 handler; mount notifications as `/devices` (not `/timeline`). | One entry; `/health`, 404 JSON, helmet active |
| TASK-010 | P0 | todo | Kill mass-assignment in `vault.service.ts:25` / `schedules.service.ts:22` `update` — whitelist fields; never trust client `userId`. | Update cannot change ownership |
| TASK-011 | P0 | todo | Server-side token revocation: add refresh-token store or `tokenVersion` on `users`; implement real logout + rotation invalidation. | Logged-out refresh token fails |
| TASK-012 | P0 | todo | Upgrade KDF from HKDF-SHA256 → Argon2id (spec §9/§10.2; `cryptography` package). Migrate stored keys/derivation path; keep param versioning. | New keys Argon2id-derived; old ciphertext migratable |
| TASK-013 | P0 | todo | Consolidate jobs: single scheduled due-date check that calls `notifications.service.sendPushNotification`, stamps `last_notified_at` (don't clobber via markPaid), handles overdue + `study_schedules`; remove duplicate/orphaned `scheduler.ts`. | Cron fires real push once per due item |
| TASK-014 | P0 | todo | Fix WS gateway: Bearer-token auth (close unauthenticated sockets), multi-device fan-out (`Map<userId, Set<ws>>`), invoke `broadcast()` from CRUD paths and cron. | Two devices both receive sync event |
| TASK-015 | P1 | todo | Schema gaps: add `PriceHistory`, refresh-token/session table, `billing_items.snoozed_until`, `notification_logs` content columns, `paid_at`. Generate + apply migration. | `prisma migrate deploy` clean; models usable |
| TASK-019 | P1 | todo | Spec §5.2 path/verb alignment: `/vault`→`/vault/items`, `PUT`→`PATCH`, add `PATCH /billing/items/:id`, add `GET /:id` for billing/schedules; add `cancelSubscription`, `snoozeReminder`, `getMonthlySpendTotal`; mount `POST /devices/register`. Note: align **both** backend and Flutter call sites. | Spec matrix fully green |
| TASK-020 | P1 | todo | Fix `markPaid`: use `date-fns` cycle math; separate `paid_at` from `last_notified_at`. | Paid bill still pushes on next due date |

---

## Phase 2 — Feature wiring (Flutter)

| ID | Pri | Status | Task | Target / AC |
|---|---|---|---|---|
| TASK-016 | P2 | todo | Analyzer config: `analysis_options.yaml` lives in `docs/` (intentional) but is not discovered from `aethel_app/`. Decide: restore a copy to repo root, or document `flutter analyze` working-directory requirement. | `flutter analyze` honors lints |
| TASK-017 | P1 | todo | Focus panel: add ticking Timer/countdown, wire switches to a provider, route "Manage Schedules" → `ScheduleEditorScreen` (already built), add immediate-lock + `endSession`. | Countdown decrements; schedule editor opens |
| TASK-018 | P1 | todo | Data auto-load: `vaultProvider`/`billingProvider`/`timelineProvider` must fetch on first build (not only pull-to-refresh); replace BillsScreen mock data with provider/DAO; FAB opens `BillEditScreen`. | First open shows real data; bills are server-backed |
| TASK-021 | P1 | todo | Navigation & signup: add signup route/UI calling `authStateProvider.signup()` (currently dead); persist JWTs securely across restarts; per-platform base URL config for `api_client`. | New user completes onboarding → dashboard |
| TASK-022 | P1 | todo | Vault detail §8.4: fresh biometric for every reveal/copy; real clipboard clear after 60 s (overwrite `Clipboard.setData`); remove placeholder `'••••••••'` fallback once decrypt is real. | Reveal re-auths; clipboard clears |
| TASK-023 | P2 | todo | Spec §4.1 structure: add `app.dart`, `core/utils/`, `domain/usecases`, `features/*/providers` parity, `widgets/` (timeline_tile, urgency_card, app_fab), `data/remote/*`; relocate shared vault/billing providers out of `dashboard/providers`. | Layout matches spec tree |
| TASK-024 | P2 | todo | Dead code pass: remove `share_plus`/`fl_chart`/`args`/`http_parser`/`collection`/`riverpod_*`-gen if unused; drop unused factories; fix `VaultEntry.iv` contract (embedded vs separate) consistently. | No unused imports/deps in analyze |

---

## Phase 3 — Focus / App Blocker

| ID | Pri | Status | Task | Target / AC |
|---|---|---|---|---|
| TASK-025 | P2 | todo | File iOS FamilyControls entitlement request (start of phase). | — |
| TASK-026 | P2 | todo | Android UsageStatsManager polling + overlay service (`platform/android/`). | Blocking active on scheduled windows |
| TASK-027 | P2 | todo | iOS ManagedSettings/DeviceActivity integration. | Conditional on approval |

---

## Phase 4 — Growth

| ID | Pri | Status | Task |
|---|---|---|---|
| TASK-028 | P2 | todo | Bank-linked subscription detection (Plaid-style) |
| TASK-029 | P2 | todo | OCR-based renewal/expiry extraction |
| TASK-030 | P2 | todo | Gmail/email-scanning digest (separate OAuth flow) |
| TASK-031 | P2 | todo | Freemium tier gating |

---

## Verification Checklist (run after main milestone)

- [ ] `flutter analyze` → 0 errors, 0 warnings
- [ ] `npm run build` (backend) → tsc 0 errors
- [ ] `npm run lint` (backend) → clean
- [ ] `docker compose up -d` → Postgres up; `npx prisma migrate deploy` clean
- [ ] `/health` → 200; unknown route → JSON 404; helmet headers present
- [ ] Vault add → ciphertext only in Postgres (plaintext absent)
- [ ] Biometric re-auth on every reveal; clipboard clears in ≤60 s
- [ ] Logout invalidates refresh token; stolen refresh token rejected
- [ ] WS: two clients get `broadcast` events synchronously
- [ ] Cron: due bill pushes once, `last_notified_at` stamped, no daily duplicates