# Aethel TODO - Concrete Bugs/Issues

## Backend (Critical)

- [ ] **backend/src/config/env.ts:5-15** - Missing FCM env vars in schema. `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` are read in `config/fcm.ts` but not validated. Add them to zod schema (make privateKey required if FCM used, or optional with checks). 
  - Problem: App can start with missing FCM creds; initialization may behave unexpectedly.
  - Minimal fix: Add to schema: `FCM_PROJECT_ID: z.string().optional()`, `FCM_CLIENT_EMAIL: z.string().optional()`, `FCM_PRIVATE_KEY: z.string().optional()` (or required if enforcing FCM). Also consider validation.

- [ ] **backend/src/config/fcm.ts:5-19** - `isFcmConfigured()` only checks `FCM_PROJECT_ID` and `FCM_CLIENT_EMAIL` (line 18). Missing `FCM_PRIVATE_KEY` check. Also if privateKey is malformed/missing, `cert()` will receive undefined parts.
  - Problem: FCM may appear "configured" but fail to init/send.
  - Minimal fix: Check all three: `!!process.env.FCM_PROJECT_ID && !!process.env.FCM_CLIENT_EMAIL && !!process.env.FCM_PRIVATE_KEY`

- [ ] **backend/src/modules/notifications/notifications.service.ts:12-20** - `prisma.device.upsert` uses `where: { id: body.id ?? undefined }`. If `body.id` undefined, Prisma receives `undefined` in unique where clause → runtime error. Also `create` passes `id: body.id ?? undefined`.
  - Problem: Registration from clients without explicit device id (Flutter sends no id) will crash.
  - Minimal fix: If `body.id` provided, use upsert by id; else use `findFirst`/`create` or upsert with a different strategy. For example: if id present do upsert by id, else create new record (or find by userId+pushToken). Since Device.id has default uuid(), better to not pass id when missing.

- [ ] **backend/src/modules/notifications/notifications.service.ts:50-56** - Same upsert issue as above in `registerDeviceForPush`.
  - Problem: Programmatic registration with no id will crash.
  - Minimal fix: Same fix as registerDevice.

- [ ] **backend/src/modules/notifications/notifications.routes.ts** - Missing HTTP routes for device registration/unregistration. Service functions exist but not mounted.
  - Problem: Flutter calls `POST /devices/register` (see `aethel_app/lib/core/services/firebase_messaging_service.dart:58`) → 404. Also `unregisterDevice` not exposed.
  - Minimal fix: Add routes. Either create `backend/src/modules/devices/devices.routes.ts` mounted in `server.ts`, or add to existing routes. Need authMiddleware. Mount in `server.ts` e.g. `app.use('/devices', devicesRoutes)` or directly handle `POST /devices/register`. Also need to import/register in server.ts.

- [ ] **backend/src/server.ts:30** - Mounts notifications routes at `/timeline` (`app.use('/timeline', notificationsRoutes)`) but notifications module also handles devices. API surface unclear. Also devices endpoints missing entirely.
  - Problem: Device registration endpoint not available.
  - Minimal fix: Add devices routes mounting (and/or mount notifications routes differently). Also ensure `/devices/register` is accessible as Flutter expects.

- [ ] **backend/src/jobs/dueDateCheck.job.ts:41-55** - For study schedules, queries `startTime` in window but does **not** filter `lastNotifiedAt: null` and does **not** update/check to prevent resends. Also updates `lastNotifiedAt` after sending but will re-notify every 10 min while in window (and after update, next run will see it updated? It updates to `now` after sending; next cron run will look for schedules starting in [now, now+15min] - if session already started and lastNotifiedAt set to now from previous run, it won't match startTime>=now again? Maybe, but logic is flawed - should track if already notified for this session occurrence).
  - Problem: Study focus reminders will spam every 10 minutes.
  - Minimal fix: Add `lastNotifiedAt: null` to schedule query (or track by session id/time), similar to bills. Also consider that startTime might have passed? Query uses `gte: now` so once started, it drops out; but during the 15min window before start, if it runs multiple times it will resend each time until startTime passes or lastNotifiedAt set. Current code sets lastNotifiedAt after send, so first run in window notifies and sets it; second run looks for startTime>=now but also needs to not resend - but it doesn't filter lastNotifiedAt, so if startTime still in window on next run (e.g., started 5 min ago? no wait startTime is future relative to now when gte: now; but if we are within 15min of start and run again later? no - cron runs every 10 min, window is 15 min ahead; once startTime < now it won't match gte:now. But within the window, first run notifies and sets lastNotifiedAt; second run at +10 min: now moved forward, startTime might still be <= now+15min if start is in 5 min? e.g. start in 10 min, first run at T notifies (sets lastNotifiedAt), second run at T+10 min now is T+10, window end T+25, startTime still T+10 <= T+25 and >= T+10? yes gte now (T+10), so it will match again and notify again because no lastNotifiedAt filter.
  - Minimal fix: Add `lastNotifiedAt: null` to where clause for schedules, same as bills.

- [ ] **backend/src/middleware/auth.middleware.ts:22-28** - Token version check: if `payload.tokenVersion` is undefined (old tokens issued before tokenVersion existed), the code skips invalidation check. If user logged out (tokenVersion incremented), old tokens without tokenVersion won't be rejected.
  - Problem: Session invalidation (logout) doesn't affect pre-existing tokens missing tokenVersion.
  - Minimal fix: Treat missing tokenVersion as requiring re-auth or treat as version 0 and compare strictly (if user.tokenVersion > 0, reject tokens without version). Or when issuing tokens always include version; also reject if payload.tokenVersion is undefined and user.tokenVersion > 0.

- [ ] **backend/src/modules/auth/auth.service.ts:52-54** - `logout` increments tokenVersion. Combined with above, need to ensure old tokens are rejected.
  - Problem: As above.
  - Minimal fix: In auth middleware, if user.tokenVersion > 0 and (payload.tokenVersion === undefined or payload.tokenVersion < user.tokenVersion) reject.

- [ ] **backend/src/websocket/syncGateway.ts:18-66** - On auth failure (no token / invalid token) closes connection with code 1008. Correct. Also tracks clients per userId in Set.
  - Note: No cleanup on server close beyond wss.close() - clients map not cleared. Minor.

- [ ] **backend/src/modules/billing/billing.service.ts:42-47** - `prisma.billingItem.update({ where: { id, userId }, data: {...} })`. `id` is unique primary key; passing `userId` in where is redundant but usually allowed if combined in a way Prisma accepts? With `@@id` or just `@id`, unique where is just `{id}`. Also if using composite unique, different - but here id is PK. This should be fine as long as it's a unique filter. But better to be precise.
  - Minor: Could just use `where: { id }` and rely on ownership check done earlier (we already did findFirst). Or keep as-is.

- [ ] **backend/src/modules/notifications/notifications.service.ts:67-74** - Always creates NotificationLog entries for all devices (even if FCM not configured). That’s fine for audit. Also logs message as JSON string - fine.

- [ ] **backend/src/modules/notifications/notifications.service.ts:76-98** - If FCM configured but send fails, catches and logs error; returns `devices.length` (line 97). But we already logged to NotificationLog before attempting send. Also `tokens` includes all devices even if some tokens are 'local-only' - but 'local-only' is not a real FCM token; sending to it will fail. Not filtered.
  - Problem: Sending multicast to non-FCM tokens causes failures; better to filter tokens that look like real FCM tokens or handle errors per-token.
  - Minimal fix: Filter tokens (e.g., skip 'local-only' or very short tokens). Also consider using `sendEach` for better error handling per token.

## Flutter (Critical)

- [ ] **aethel_app/lib/main.dart:19-35** - `FirebaseMessagingService.initialize()` called at line 20 BEFORE `ApiClient.init()` at line 22. `FirebaseMessagingService.initialize()` calls `_registerToken()` which calls `_sendTokenToBackend()` which does `ApiClient.dio.post(...)` at line 58 in firebase_messaging_service.dart. But `ApiClient._dio` is `late final` initialized only in `ApiClient.init()` - accessing before init() will throw `LateInitializationError`.
  - Problem: App will crash on startup.
  - Minimal fix: Call `ApiClient.init()` before `FirebaseMessagingService.initialize()`, or have FirebaseMessagingService lazily send tokens after ApiClient is ready / queue registration.

- [ ] **aethel_app/lib/core/services/firebase_messaging_service.dart:58-65** - Sends to `ApiClient.dio.post('/devices/register', ...)`. Backend has no mounted route for this (see server.ts) → 404. Also platform hardcoded to `'android'` (line 60) - should detect platform.
  - Problem: Token registration will fail with 404.
  - Minimal fix: Add backend route for device registration (mount in server.ts), or change endpoint to match existing mounted routes. Also make platform dynamic (`Platform.isIOS ? 'ios' : 'android'`).

- [ ] **aethel_app/lib/core/services/firebase_messaging_service.dart:15** - `Firebase.initializeApp()` without options. May fail if `firebase_options.dart` not configured or platform files missing. Also project has `firebase_core` and `firebase_messaging` deps.
  - Note: May be okay if platform configs present.

- [ ] **aethel_app/lib/core/network/api_client.dart:33-52** - Token refresh flow: on 401, posts to `/auth/refresh`. If refresh fails or returns unexpected format, it clears tokens and passes error through. Also if refresh succeeds but new tokens missing, sets `_refreshToken = _refreshToken!` (line 39) which could be bad if null - but we check `_refreshToken != null` before entering. OK.
  - Minor: The refresh call uses `_dio.post()` which will go through interceptor (adds Authorization header if _accessToken exists). That’s usually fine.

- [ ] **aethel_app/lib/features/auth/providers/auth_provider.dart:33-71** - On login/signup, reads `data['access_token']` and `data['refresh_token']` from response. Backend returns snake_case - matches. Also stores tokens. OK.

## Infrastructure/Config

- [ ] **backend/.env.example** - Should document FCM vars and WS_PORT. Check if present.
- [ ] **aethel_app/android/app/google-services.json**, **aethel_app/ios/Runner/GoogleService-Info.plist** - Referenced by Firebase; may be missing. Not code bugs but deployment issues.
- [ ] **CI** (.github/workflows/ci.yml) - Backend does `npm ci && npm run build` (tsc). Flutter does analyze, format check, test. OK.

## General Notes
- Route naming: backend mounts vault at `/vault` (server.ts:27), billing at `/billing` (28), schedules at `/schedules` (29), notifications/timeline at `/timeline` (30). Docs mention some path/verb differences (TASK-019) - may need alignment.
- Prisma schema looks consistent with migrations referenced.
