# Aethel — Product Requirements Document

**Official name:** Aethel
**Document status:** Living — source of truth for product requirements
**Last updated:** 2026-09-20
**Sources:** `app_specification_document.md` (v1, 2026-09-18), user decisions, codebase audit (2026-09-19/20)

---

## 1. Product Overview

**One sentence:** A single mobile app that removes the "I have to remember this myself" burden of daily life by combining a zero-knowledge password vault, a bill/subscription/renewal tracker, and an optional app-blocking focus mode — unified into one chronological timeline instead of three separate apps.

**The core insight / differentiator:** Existing tools each solve one category (1Password → credentials, Rocket Money → subscriptions, Opal → focus), but none connect the categories. The value is **contextual execution**: a study-block reminder can surface the exact login the user needs for that session right next to the lock controls — instead of forcing three app switches.

**What Aethel is not:** a bank-sync-first finance app, a parental-control app, or a generic to-do list.

### 1.1 Goals
- Provide a **zero-knowledge** vault — the server only ever sees ciphertext.
- Consolidate passwords, bills/subscriptions, and focus blocking into a **single unified timeline**.
- Ship a Phase-1 MVP usable for passwords + bills/subscriptions without special entitlement risk.
- Optional (Phase 3+) focus blocking gated on Apple/Android platform approvals.

### 1.2 Non-goals
- Bank-linked auto-detection (Plaid-style) — Phase 4, post-launch.
- OCR / email-scanning digests — Phase 4.
- Freemium monetization gating — Phase 4.
- Master-password **recovery** — none (pure zero-knowledge, user decision).

---

## 2. Users & Personas

| Persona | Description | Key needs |
|---|---|---|
| Primary — Busy professional / student | Single device for daily life admin; skeptical of cloud password managers | Speed, security, fewer app switches |
| Secondary — Privacy-conscious user | Trust-boundary aware; wants the server provably unable to read secrets | Zero-knowledge, biometric gating, no recovery option accepted |
| Tertiary — Subscriber consolidator | Tracks multiple streaming/subscription renewals out of habit | Bills timeline, mark-paid flow, monthly spend |

**Platform:** Android + iOS (Flutter). Phase 3 Android-only focus blocking; iOS FamilyControls pending Apple approval.

---

## 3. Functional Requirements

Requirement IDs: `FR-<module>-<n>`. Priority: P0 (must), P1 (should), P2 (could / deferred).

### 3.1 Auth module
| ID | Requirement | Priority |
|---|---|---|
| FR-AUTH-01 | `signUp(email, password)` — creates account; server login credential is separate from local vault key | P0 |
| FR-AUTH-02 | `logIn(email, password)` — returns access + refresh JWT | P0 |
| FR-AUTH-03 | `refreshToken(refreshToken)` — rotates refresh token | P0 |
| FR-AUTH-04 | `logOut()` — revokes refresh token **server-side**, clears local session | P0 |
| FR-AUTH-05 | `enableBiometric()` / `verifyBiometric()` — gates vault reveal and app unlock | P0 |
| FR-AUTH-06 | Master-password setup derives local vault key on-device; **never transmits raw password** | P0 |
| FR-AUTH-07 | Signup UI reachable from app (onboarding → create account) | P1 |

**Security invariant:** the user's master password must never leave the device. The field labeled "master password" must not be sent to `/auth/login`.

### 3.2 Vault module
| ID | Requirement | Priority |
|---|---|---|
| FR-VLT-01 | `deriveVaultKey(masterPassword, deviceSalt)` — Argon2id, on-device only, never transmitted | P0 |
| FR-VLT-02 | `addVaultItem(title, payload, type)` — encrypt locally (AES-256-GCM), sync ciphertext only | P0 |
| FR-VLT-03 | `revealVaultItem(itemId)` — requires **fresh** biometric check, decrypts locally | P0 |
| FR-VLT-04 | `editVaultItem(itemId, newPayload)` — re-encrypts, syncs | P0 |
| FR-VLT-05 | `deleteVaultItem(itemId)` | P0 |
| FR-VLT-06 | `copyToClipboard(value)` — auto-clears after 30–60 s | P0 |
| FR-VLT-07 | Item types: password / card / note / identity (filter chips: All/Passwords/Cards/Notes) | P0 |
| FR-VLT-08 | Titles/labels stay plaintext (searchable server-side); secret payloads ciphertext only | P0 |

### 3.3 Bills & Subscriptions module
| ID | Requirement | Priority |
|---|---|---|
| FR-BIL-01 | `addBillingItem(title, amount, dueDate, cycle, type)` | P0 |
| FR-BIL-02 | `markPaid(itemId)` — advances `next_due_date` per `billing_cycle` | P0 |
| FR-BIL-03 | `cancelSubscription(itemId)` — marks inactive, optional deep-link to provider cancel page | P1 |
| FR-BIL-04 | `snoozeReminder(itemId, days)` | P1 |
| FR-BIL-05 | `getMonthlySpendTotal()` — aggregates active subscriptions for dashboard chip | P1 |
| FR-BIL-06 | PATCH/update a bill (amount, title, due date) — **required endpoint missing today** | P0 |
| FR-BIL-07 | List views: All / Upcoming / Paid (tab bar) | P0 |

### 3.4 Focus & Blocker module (Phase 3)
| ID | Requirement | Priority |
|---|---|---|
| FR-FOC-01 | `createSchedule(label, startTime, endTime, daysOfWeek, blockedApps)` | P1 |
| FR-FOC-02 | `startImmediateLock(blockedApps, durationMinutes)` — one-tap lock outside a recurring schedule | P1 |
| FR-FOC-03 | Android: `checkForegroundApp()` — polls UsageStatsManager, triggers overlay if in blockedApps | P2 |
| FR-FOC-04 | iOS: `requestFamilyControlsAuthorization()` — Apple system consent flow | P2 |
| FR-FOC-05 | `endSession()` — releases block, logs session length for stats | P1 |

### 3.5 Notifications & sync
| ID | Requirement | Priority |
|---|---|---|
| FR-NOT-01 | `registerDevice(pushToken, platform)` | P0 |
| FR-NOT-02 | `dueDateCheckJob()` — server cron every 5–15 min | P0 |
| FR-NOT-03 | `sendPushNotification(userId, payload)` — real FCM (Android) / APNs (iOS) | P0 |
| FR-NOT-04 | `broadcastSyncEvent(userId, changeType, entity)` — WS push to all of a user's connected devices | P1 |
| FR-NOT-05 | Local cache + background reconcile (offline-friendly) | P1 |

### 3.6 Dashboard / timeline aggregation
| ID | Requirement | Priority |
|---|---|---|
| FR-DSH-01 | `getUnifiedTimeline(userId, rangeStart, rangeEnd)` — merges billing due dates + schedule start times + vault-linked reminders into one sorted, color-coded list | P0 |
| FR-DSH-02 | Max 3 metric chips on load; everything else collapsed behind taps | P1 |
| FR-DSH-03 | Urgency color language everywhere: red = overdue, yellow = within 7 days, blue = scheduled/informational, green = resolved | P0 |

### 3.7 Settings
| ID | Requirement | Priority |
|---|---|---|
| FR-SET-01 | Export encrypted data (zip) | P1 |
| FR-SET-02 | Delete account (with cascade cleanup server-side) | P1 |
| FR-SET-03 | Change master password (requiring re-keying of encrypted data) | P1 |
| FR-SET-04 | Notification preferences | P1 |
| FR-SET-05 | Logout (revokes refresh token server-side) | P0 |

---

## 4. Non-Functional Requirements

| Area | Requirement | Priority |
|---|---|---|
| **Security** | Zero-knowledge trust boundary — server/DB/breach only ever sees ciphertext (§ trust boundary) | P0 |
| **Crypto** | Argon2id KDF + AES-256-GCM payload encryption (spec §9). Current impl uses HKDF-SHA256 — **must upgrade** | P0 |
| **Biometric UX** | Full secret reveal requires biometric re-auth **every** time, not once per session (§8.4) | P0 |
| **Clipboard** | Copy auto-clears after 30–60 s (§8.4) | P0 |
| **Auth** | JWT access ~15 min + rotated refresh tokens (7 d) | P0 |
| **Auth/rate** | Rate limiting on all `/auth/*` routes | P0 |
| **Validation** | Zod schema validation on every controller input; vault/billing reject non-ciphertext shapes | P0 |
| **Privacy** | Plain-language permission explanations before requesting Screen Time / Accessibility-adjacent permissions | P1 |
| **Performance** | Local cache reads first, background reconcile; offline-capable | P1 |
| **Dark mode** | First-class, not a toggle afterthought. Parity between light/dark token sets | P1 |
| **Accessibility** | Body text ≥ 15sp; color language not the only signal (icons/labels too) | P2 |

---

## 5. Data Requirements (POSTGRESQL)

Tables (spec §6): `users`, `vault_items` (ciphertext only: `encrypted_payload`, `iv`), `billing_items`, `study_schedules`, `devices`, `notification_logs`.

Required current-state gaps to close:
- `PriceHistory` table — required by price-change job; **absent**.
- `snoozed_until` column — required by `snoozeReminder`; **absent**.
- Refresh-token/session store or `tokenVersion` on User — required for server-side revocation; **absent**.
- `NotificationLog` message/content columns — so logs can record what was pushed; **absent**.

**Critical design rule (§6):** `password_hash` (on `users`) authenticates login only. It must never be derivable from / usable to derive the vault encryption key.

---

## 6. API Requirements (spec §5.2)

Auth:
- `POST /auth/signup`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`

Vault (ciphertext in/out only):
- `GET /vault/items`, `POST /vault/items`, `PATCH /vault/items/:id`, `DELETE /vault/items/:id`

Billing:
- `GET /billing/items`, `POST /billing/items`, `PATCH /billing/items/:id`, `DELETE /billing/items/:id`

Schedules:
- `GET /schedules`, `POST /schedules`, `PATCH /schedules/:id`, `DELETE /schedules/:id`

Devices & Sync:
- `POST /devices/register`
- `WS /sync`

**Drift to fix:** backend currently uses `/vault` (not `/vault/items`), `PUT` (not `PATCH`), and `PATCH /billing/items/:id` does not exist. `POST /devices/register` is implemented but unmounted.

---

## 7. Phased Roadmap

### Phase 1 — Foundation (in progress; see status snapshot)
Flutter UI skeleton (Dashboard/Vault/Bills), on-device crypto (Argon2id + AES-256-GCM), SQLCipher cache, backend auth/vault/billing + Postgres schema, push wired to due-date cron.
**Milestone:** usable for passwords + bills, shippable with no special entitlement risk.

### Phase 2 — Real-time sync + polish
WS multi-device sync, Settings (export, delete account, notification prefs), UI polish vs §8 theming.

### Phase 3 — Focus / App Blocker
File iOS FamilyControls entitlement request at start; Android UsageStatsManager + overlay; schedule editor + immediate-lock UI.
**Milestone:** full three-pillar app (contingent on Apple approval).

### Phase 4 — Growth
Bank-linked auto-detection (Plaid-style), OCR renewal/expiry extraction, Gmail/email-scanning digest, freemium tier gating.

---

## 8. Acceptance Checklist (Phase 1)

- [ ] `flutter analyze` → 0 errors, 0 warnings
- [ ] `npm run build` (backend) → tsc succeeds
- [ ] `docker compose up -d` → PostgreSQL starts
- [ ] `npm run dev` → `/health` returns 200
- [ ] `flutter run` → splash → onboarding → dashboard renders
- [ ] Add vault item → ciphertext lands in PostgreSQL (verify via psql, plaintext absent)
- [ ] Biometric gate on vault detail; reveal re-auths every time
- [ ] Copy to clipboard auto-clears after 60 s
- [ ] Login/logout round-trip revokes refresh token server-side
- [ ] Due-date cron sends real push notification and stamps `last_notified_at`

---

## 9. Status Snapshot (from codebase audit, 2026-09-20)

| Area | Status | Notes |
|---|---|---|
| Flutter screens | Partial | 5 screens routed; vault detail decrypt not wired; bills = mock data; settings inert |
| Crypto layer | Partial | AES-256-GCM present; KDF is HKDF not Argon2id; empty-password derive bug |
| SQLCipher cache | Dead code | DB/DAOs/repos written but never initialized |
| WS sync | Dead code | Client + gateway written; not activated; `broadcast` never invoked |
| Backend CRUD | Partial | Auth/vault/billing/schedules work; path/verb drift vs §5.2; no Zod validation |
| Push | Stub | Console log + log row; no real FCM/APNs |
| Jobs | Partial | Due-date cron logs in_app only; price-change job never runs; no PriceHistory |
| Settings (export/delete/rekey) | Missing | Not implemented |
| Account deletion / export endpoints | Missing | — |

---

## 10. Open Decisions (tracked in MEMORY.md)

| Decision | Answer |
|---|---|
| App name | **Aethel** |
| Master-password recovery | **None** (pure zero-knowledge) |
| Monetization | **Freemium** tier boundaries (Phase 4) |
| KDF | **HKDF-SHA256 today — spec requires Argon2id; upgrade planned** (TASK-012) |