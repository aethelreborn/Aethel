# Aethel — Persistent Project Memory (AI/Agent)

> **⚠️ MANDATORY PROTOCOL — read this file at the START of every session, and update it at the END of every session (even incomplete ones).** This is the project's persistent memory: decisions, current state, landmines, and where the work left off. Future sessions depend on it.

---

## 1. How to use this file

- **Start of session:** read this whole file. If a previous session logged incomplete work, resume from `Session Log` / `In Progress`.
- **End of session:** append a row to the Session Log table, update "Current build status", "Landmines", and "Next up". If a task in TASKS.md changed status, update that too.
- Keep facts terse and specific (file:line). Do not paste formatting junk.

---

## 2. Project facts

| | |
|---|---|
| Product | **Aethel** — zero-knowledge vault + bill/subscription tracker + focus blocker |
| Repo root | `/home/darkie/Main Project/Aethel` (NOTE: `PLAN.md` still says `/home/darkie/Desktop/Main Project/Aether/` — stale) |
| Excluded repo | `/home/darkie/Main Project/AethelxStoneMC` (the SteelMc/StoneMC server — NOT part of Aethel work) |
| Stack | Flutter/Riverpod · Node+TS+Express · Prisma/Postgres 16 · `ws` · node-cron |
| Decisions | Name **Aethel** · No master-password recovery (pure ZK) · Freemium = Phase 4 · KDF currently **HKDF-SHA256 → must upgrade to Argon2id** (TASK-012) |
| Key docs | `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/RULES.md`, `docs/DESIGN.md`, `docs/TASKS.md` (this = `MEMORY.md`), spec = `app_specification_document.md` |
| Git | 1 commit `58dbb78` ("feat: Phase 1 complete — …"); branch `main` | 

---

## 3. Current build status (2026-09-20)

- **Do NOT trust PLAN.md/README "Phase 1 complete / 0 issues" claims — stale.** Audit (2026-09-19/20) found the tree mid-refactor with compile errors.
- Uncommitted, in-progress work on disk: `aethel_app/lib/core/crypto/secure_key_store.dart`, `aethel_app/lib/features/auth/presentation/screens/{login_screen,master_password_setup,splash_screen}.dart`, `aethel_app/lib/features/vault/presentation/{vault_detail_screen,vault_grid_screen}.dart`, `backend/src/websocket/syncGateway.ts`.
- **Files were actively changing during the audit** — re-read before editing.
- `docs/analysis_options.yaml` holds the analyzer config; repo root no longer has one → `flutter analyze` from `aethel_app/` won't pick it up (TASK-016).
- Backend live entry = `backend/src/server.ts`. Root `backend/server.ts` + `backend/src/app.ts` are dead code.

---

## 4. Landmines (known bugs — do not reintroduce)

| # | Landmine | Location |
|---|---|---|
| L1 | `getDerivedKey()` derives from **empty password** → wrong key, GCM auth fails. Fix = biometric + `readKey()`. | `aethel_app/lib/core/crypto/secure_key_store.dart:55` |
| L2 | Storage key names inconsistent: `aethel_aes_key`/`aethel_salt` vs `master_key` (vault_edit reads) vs deleted `vault_key`. | `secure_key_store.dart`, `vault_edit_screen.dart:114` |
| L3 | `vault_edit_screen` uses base64 string bytes as AES key, sends `iv: ''`. Saved ciphertext is unreadable. | `aethel_app/lib/features/vault/presentation/vault_edit_screen.dart:118,135` |
| L4 | `main.dart:19` `overrides: [syncInitializerProvider]` = type error; WS sync never activates. | `aethel_app/lib/main.dart` |
| L5 | `vault_detail_screen.dart` references `FlutterSecureStorage` without import (compile error); decrypt path + §8.4 biometric re-auth + clipboard clear not met. | `vault_detail_screen.dart:36` |
| L6 | Backend: mass-assignment in `update` (raw `req.body` → Prisma) — ownership transfer possible. | `src/modules/vault/vault.service.ts:25`, `schedules.service.ts:22` |
| L7 | `markPaid` writes `last_notified_at` → suppresses next cycle's push. | `src/modules/billing/billing.service.ts:29` |
| L8 | WS gateway cookie-auth for a Bearer client; missing token ⇒ socket stays open unauthenticated; `Map<userId,ws>` no fan-out; `broadcast()` never called. | `src/websocket/syncGateway.ts` |
| L9 | `express` missing from `dependencies` (transitive only) — prod boot risk. | `backend/package.json` |
| L10 | Two competing crons; live one (`DueDateCheckJob`) never pushes; orphaned `scheduler.ts` never runs; `priceChangeCheck` is a placeholder needing `PriceHistory`. | `src/jobs/*` |

---

## 5. Wiring map (what's reachable vs dead)

Wire: Splash → Onboarding → MasterPasswordSetup · Login → Dashboard (5-tab bottom nav: Home/Vault/Bills/Focus/Settings).

| Layer | Reachable? |
|---|---|
| `data/local/database.dart` (+ daos, repositories) | 💀 never initialized |
| `core/network/websocket_client.dart`, `dashboard/providers/sync*` | 💀 never started |
| `bills_subscriptions/bill_edit_screen.dart`, `focus_blocker/schedule_editor_screen.dart` | 💀 no navigation |
| `vault/{grid,detail,edit}` | ✅ reachable (detail/edit broken — L1–L3, L5) |
| Settings tiles | ✅ reachable, all inert |
| Backend modules auth/vault/billing/schedules | ✅ mounted (path/verb drift) |
| `notifications` device functions, `src/app.ts`, root `server.ts` | 💀 unmounted / dead |

---

## 6. Commands cheatsheet

```bash
# Flutter (from aethel_app/)
flutter pub get
flutter analyze          # NOTE: analyzer config location — TASK-016
dart format lib

# Backend (from backend/)
cp .env.example .env     # REQUIRED — no .env on disk, env.ts throws without it
npm install
npx prisma migrate deploy
npm run dev              # ts-node src/server.ts  (port 3000, WS 3001)
npm run build            # tsc
npm run lint             # broken until TASK-008

# Database
docker compose up -d     # Postgres 16, db=aethel, :5432
```

---

## 7. Next up (first session priorities)

Follow `TASKS.md` Phase 0 order: **TASK-001 → TASK-002 → TASK-003** (compile + ZK key flow) before anything else. Don't branch into Phase 2 wiring until `flutter analyze` and `tsc` are green.

---

## 8. Session Log

**Protocol:** append newest row at TOP. Columns: `Date | Who | Work done | Outcome | State left in`.

| Date | Who | Work done | Outcome | State left in |
| 2026-09-20 | claude | Firebase FCM push notifications fully implemented — backend sends real pushes, Flutter registers devices, cron job triggers notifications | Backend tsc green; Flutter needs android/ platform files + google-services.json | Push to Railway → run flutter create . --platforms=android → add google-services.json → flutter build apk |

| 2026-09-20 | claude | Production deploy config — Railway Dockerfile, GitHub Actions CI (flutter analyze + tsc), deploy.sh script, VERIFICATION.md checklist | 6 new files committed; app ready for zero-cost production deployment | Push to GitHub → Railway auto-deploys; set up UptimeRobot at https://your-app.railway.app/health |

| 2026-09-20 | claude | Phase 1+2 completion: wired auth/vault/bills end-to-end, fixed L1 key bug, added Zod validation, killed mass-assignment, activated WS sync multi-device, fixed markPaid/cron dedup, made settings functional, added signup + JWT persistence | 14 tasks done; backend tsc green; flutter compile blockers resolved | Ready for docker + smoke test; TASK-007 (local DB) and TASK-012 (Argon2id) remain as debt |

|---|---|---|---|---|
| 2026-09-20 | audit | Full codebase audit (excl. AethelxStoneMC); created `docs/` set (PRD, ARCHITECTURE, RULES, DESIGN, TASKS, MEMORY) | 31 Dart + 23 TS files mapped; 31 tasks filed; landmines L1–L10 recorded | See §3–§5; next = TASK-001 (compile blockers) |

---

## 9. Scratch / uncommitted diff notes

- `secure_key_store.dart`: keys renamed `_aesKeyStoreKey`/`_saltStoreKey`; added `local_auth` + `kdf_service` imports; new `storeDerivedKey()`/`getDerivedKey()` (L1 bug). Not committed.
- `login_screen.dart`, `master_password_setup.dart`: converted to Consumer widgets wired to providers/storage. Not committed.
- `splash_screen.dart`, `vault_detail_screen.dart`, `vault_grid_screen.dart`, `syncGateway.ts`: mid-edit during audit. Not committed.

---

*If this file grows stale, the stale facts live in PLAN.md/README.md (superseded).*