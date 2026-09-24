# Aethel — Engineering Rules

**Last updated:** 2026-09-20
**Purpose:** Hard conventions for every engineer and AI working on Aethel. Violating these is a bug.

---

## 1. Security Invariants (HARD — never break)

1. **The master password never leaves the device.** Never POST it to a server endpoint. The field in any login/signup UI is the *server login password* (`password_hash` on `users`), which is a **different secret** from the vault key source.
2. **`password_hash` on `users` must never be derivable from / used to derive the vault encryption key** (spec §6 critical rule).
3. **Never derive keys from empty/placeholder/mocked input.** `KdfService.deriveKey('', salt)` is a known bug — the derived key can never match the stored one. Guard against empty passwords in the KDF.
4. **The server only ever stores/returns ciphertext** for secret payloads. Vault and billing endpoints must reject anything not shaped like ciphertext (IV + ciphertext + tag).
5. **Every secret reveal requires a fresh biometric check** (§8.4) — not once per app session. `biometricOnly: false` fallback is acceptable only when explicitly reviewed; document the choice.
6. **Clipboard copies auto-clear after 30–60 s** — `Clipboard.setData` must be overwritten/cleared by the timer, not just a button label reset.
7. **No plaintext in logs or error messages.** No `console.log` of payloads. `debugPrint` is for dev-only paths.
8. **No secrets in the repo.** `.env*` gitignored; secrets come from environment.
9. **One canonical storage key namespace** — `aethel_aes_key` / `aethel_salt`. Never introduce ad-hoc key names (`master_key`) alongside them.
10. **Biometric error paths must not fall through to a broken key** — if authentication fails, the vault must not open with garbage state.

---

## 2. Architectural Rules

1. **No dead code.** Every widget/screen/provider/DAO/repository must be reachable from the app (navigation, provider graph, or explicit plugin). If it's not wired, either wire it or remove it. `💀` items in ARCHITECTURE.md are debt.
2. **No mock data in feature screens.** Screens consume providers/DAOs. Test data lives in tests or seed scripts, never in a release widget.
3. **Feature-first layout** (spec §4.1): screens + providers live under `features/<module>/`; shared infra under `core/`; data access under `data/`. No importing one feature's provider from another feature's presentation (e.g. vault grid must not import dashboard's provider — move shared providers to `data/repositories` or own feature).
4. **Timeline pattern:** modules publish events to the shared `timelineProvider`; the Dashboard reads it. Modules don't call the dashboard directly.
5. **Every configurable number is a named constant** — durations, retry backoffs, limits (e.g. copy-clearing 60 s).
6. **Local storage stays encrypted (SQLCipher).** Never fall back to plaintext `sqflite` for the same tables (method-channel conflict).

---

## 3. Flutter / Dart Conventions

1. Riverpod is the state solution. Prefer `AsyncNotifierProvider` for "load local cache instantly, then reconcile with server".
2. `app.dart` holds the `MaterialApp`/router; `main.dart` only wires `ProviderScope` + platform init. (Aligns to spec §4.1 — currently missing.)
3. `flutter analyze` must pass with 0 errors, 0 warnings before any PR/commit. Fix lints, don't `// ignore` except with a reason comment.
4. Format with `dart format`. Keep files focused; don't paste 600-line screens without extracting widgets.
5. Crypto code in `core/crypto` must be unit-tested with round-trips (encrypt → decrypt → match) and negative cases (wrong key → GCM failure).
6. Newer Flutter APIs (`withValues`, `CardThemeData`, `Switch.activeThumbColor`) require a matching SDK floor in `pubspec.yaml` — keep `environment` in sync with what code actually uses.
7. Don't send `''` for required payload fields (`iv`) to cover for "server generates IV" — define the contract in the model and honor it on both ends.
8. Asset declarations must match real directories.

---

## 4. TypeScript / Backend Conventions

1. Modules follow `{routes, service}` (+ controller where complexity warrants). Route handlers stay thin.
2. ESM-style relative imports with explicit `.js` extension — consistently (all files, not a mix).
3. **Every input is validated with Zod** (`validateBody`) before reaching a service. This is currently unenforced — fix as part of TASKS.
4. **Use `PATCH` for partial updates, `PUT` for full replace**, per spec §5.2.
5. **Whitelist fields in update paths — never pass raw `req.body` to Prisma** (mass-assignment). 
6. Map Prisma errors to HTTP semantics: P2002 → 409, invalid enum → 400, not-found → 404. Plain `new Error()` → 500 only as last resort.
7. Ownership scoping always: query-scope by `userId` (`findFirst({ where: { id, userId } })`), delete via scoped `deleteMany`. Never trust client-supplied `userId`.
8. `last_notified_at` means "last time the due-date cron pushed" — never repurpose it to mean "last paid/seeded". Do not let `markPaid` clobber the dedup stamp; the same field must not block future pushes.
9. Date math: prefer `date-fns` (declared) over hand-rolled fixed-day maps for cycle advances (MONTHLY=30 is wrong).
10. Real push (FCM/APNs) is required in production; a `console.log` stub is a stopgap and must be behind an interface.

---

## 5. Git Workflow

1. Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`. Match existing repo style (`feat: Phase 1 complete — …`).
2. Commit in logical units; don't bundle unrelated changes.
3. Review `git status`/`git diff` before committing; never commit `backend/.env`, `*.log`, or build artifacts.
4. No `--force` pushes, no history rewrites (unless explicitly requested).
5. Don't leave the working tree holding a half-finished refactor across sessions — either finish it or note it in MEMORY.md so the next session knows.

---

## 6. Documentation Rules

1. **PRD.md is the product source of truth.** Any functional decision updates PRD first.
2. **TASKS.md status is always current** — mark done/in-progress/blocked as you work.
3. **MEMORY.md is the AI/agent persistent memory.** Every AI session working on Aethel MUST:
   - read MEMORY.md at session start, and
   - append to the Session Log + update Current Build Status at session end (even if incomplete).
4. Keep ARCHITECTURE.md diagrams honest — mark new dead code with 💀 and existing gaps with their TASK ref.
5. `analysis_options.yaml` lives in `docs/` (intentional) — note that `flutter analyze` config discovery from `aethel_app/` is currently broken (TASK-016).

---

## 7. Definition of Done

- [ ] Meets its PRD requirement(s) (by ID) or explicitly changes the requirement in PRD.md
- [ ] Wired into the app/backend (no dead code)
- [ ] `flutter analyze` 0 errors / `tsc` 0 errors for touched scope
- [ ] Tests added for crypto/business logic
- [ ] Security invariants (§1) reviewed and intact
- [ ] TASKS.md row updated; MEMORY.md session log appended