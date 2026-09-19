# Aethel — Design System & UX

**Last updated:** 2026-09-20
**Sources:** spec §7 (wireframes), §8 (theming). Applies across ALL screens, light + dark.

---

## 1. Principles (§8.1)

- **Calm authority over clutter** — max 3 metric chips on dashboard load; everything else collapsed behind taps.
- **Consistent urgency color language** on every screen: 🔴 red = overdue · 🟡 yellow = within 7 days · 🔵 blue = scheduled/informational · 🟢 green = resolved.
- **One primary action per screen** — the focus-lock toggle never visually competes with the bill timeline.
- **Dark mode is first-class**, not a toggle afterthought. Every screen must render correctly in both themes.
- Deliberately avoiding generic security clichés — Aethel reads as a premium, high-end productivity system.

---

## 2. Color Tokens (§8.2)

Token values: `flutter/lib/core/constants/colors.dart` (verify they match — audit found them aligned).

| Token | Light | Dark |
|---|---|---|
| `bgPrimary` | `#FAFAF9` | `#121316` |
| `bgSurface` | `#FFFFFF` | `#1C1E22` |
| `textPrimary` | `#1A1A1E` | `#F2F2F3` |
| `accent` (muted teal) | `#3B6E6B` | `#5FA39F` |
| `urgent` | `#D64545` | `#E06767` |
| `upcoming` | `#D9A441` | `#E0B65C` |
| `informational` | `#3F6FBF` | `#6C93D6` |
| `resolved` | `#4C9A6A` | `#6FBF8A` |

**Usage mapping:**
- `urgent` → overdue bills, blocked/unlockable states, destructive actions (delete).
- `upcoming` → items due ≤7 days.
- `informational` → scheduled study blocks, neutral timeline headers, focus lock scheduled.
- `resolved` → marked-paid, completed, session-ended states, success feedback.
- `accent` → primary actions, FAB, active filters, biometric gate identity.

---

## 3. Typography (§8.3)

- Headers: system sans-serif stack (Inter / SF Pro / Roboto by platform). No bundled webfonts — avoids licensing/load overhead.
- Body: same family, regular weight, **minimum 15sp** for low-light "checking bills at night" readability.
- `fontFamily: 'Roboto'` hardcoding should be replaced with the system stack (TASK note).
- Monospace for revealed secrets (e.g. credential values) to aid transcription.

---

## 4. Component Inventory

| Component | Spec | Notes |
|---|---|---|
| Metric chip | §7 dashboard | Max 3 on load; e.g. "4 Active Subs", "₹3,200 due wk" |
| Timeline tile | §7, §10.6 | Time header (colored) + entity row + urgency badge |
| Filter chips | §7 vault | All / Passwords / Cards / Notes (Add: identity if shipped) |
| Vault card | §7 | Icon (type) + title + masked username + [Copy] affordance; tap → biometric → reveal |
| Bill tile | §7 | Amount, due label, [Mark Paid] / [Cancel] / [Snooze] actions |
| Focus panel | §7 | Countdown (HH:MM:SS), session label, blocked-app switches, edit-schedule entry |
| Auth gate | §8.4 | One primary action "Authenticate"; error panel on failure |
| Setting tile | settings | Label + chevron; must be tappable (currently inert — TASK-005) |

---

## 5. Screen Specs

### 5.1 Splash
Brand lock icon in accent circle, wordmark "Aethel", tagline "Your data. Your keys. Your privacy." → routes to onboarding (no key) or biometric unlock → dashboard, else login.

### 5.2 Onboarding (3-page PageView)
Value pitch pages → "Get Started" → master password setup; secondary "Already have an account?" → login.

### 5.3 Master password setup
Confirm-match password form; ≥8 chars; **this password derives the vault key locally (never sent)**. After success → dashboard (requires server session — account creation must exist; see PRD FR-AUTH-07/TASK suffix).

### 5.4 Login
Email + password; loading state on submit; error surface; link to onboarding.

### 5.5 Dashboard
Greeting + ⚙️ → metric chips (≤3) → unified timeline (🔴/🟡/🔵/🟢 color-coded rows) → FAB `+` → contextual add. Pull-to-refresh triggers data load *(fix auto-load — TASK-018)*.

### 5.6 Vault grid → detail → edit
- Grid: 2-column GridView, filter chips, card tap → detail.
- **Detail:** identity card → credential section (masked, reveal toggle) → Copy. **Security UX:** untouched-body biometric gate on entry; every Re-reveal + Copy re-authenticates; copy clears after 60 s (PRD §4).
- Edit: type-aware form (password/card/note fields); prefill existing secrets (currently wipes — TASK-003).

### 5.7 Bills & Subscriptions
Tab bar All / Upcoming / Paid. This-week / This-month groupings. Row actions: Mark Paid (advances next due date), Cancel, Snooze (TASK: cancel/snooze endpoints missing).

### 5.8 Focus panel & schedule editor
Countdown, quick-start 15/30/45/60/90 min, blocked-app toggles, weekly rule summary, Edit Schedule → `table_calendar` week picker + day chips + app toggles. (*Timer/blocking not yet real — TASK-017.*)

### 5.9 Settings
Notifications, Change Master Password (re-key flow — must re-encrypt vault), Export (encrypted zip), Delete Account (destructive confirm). Required but inert — TASK-005.

---

## 6. Interaction & State Rules

1. **Loading:** spinners for async (button-level where possible). Providers must auto-fetch on first build, not require pull-to-refresh.
2. **Empty state:** friendly copy + primary CTA (e.g. "Add your first vault entry") — never a blank screen.
3. **Error state:** inline error text/panel with a retry affordance. Never mask real failures with placeholders like `'••••••••••••••••'` tied to unimplemented decryption.
4. **Destructive actions:** require confirmation dialog; use `urgent` color for the destructive button.
5. **Feedback:** success snackbars in `resolved`, failure snackbars in `urgent`.
6. **Dark mode parity:** every screen uses `AppColors.bgPrimary(context)` etc.; verify contrast in both themes.
7. **Permissions (Phase 3):** plain-language explanation screens before requesting Screen Time / Accessibility-adjacent permissions (spec §8.4).

---

## 7. Accessibility

- Color is never the *only* signal — pair urgency colors with icons/labels (🔴 overdue also says "Overdue"; copy button text changes, etc.).
- Touch targets ≥ 44–48 dp on list/row actions.
- Proper `Semantics` labels on icons and masked fields (screen readers must not read a bonus-masked string as the secret).