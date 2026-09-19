# Aethel — Production Verification Checklist

## Pre-deploy (local)
- [ ] `flutter analyze` → 0 errors, 0 warnings
- [ ] `npm run build` (backend/) → tsc succeeds
- [ ] `npm run lint` (backend/) → clean
- [ ] `docker compose up -d` → Postgres starts
- [ ] `npx prisma migrate deploy` → migration applies cleanly
- [ ] `curl http://localhost:3000/health` → `{"status":"ok","timestamp":...}`
- [ ] `curl http://localhost:3000/nonexistent` → `{"error":"Not found"}` (JSON 404)
- [ ] Helmet headers present: `curl -I http://localhost:3000/health`

## Security invariants
- [ ] Add vault item → `psql` shows ciphertext in `encrypted_payload`, plaintext absent
- [ ] Biometric gate blocks vault detail until authenticated
- [ ] Logout → next API call returns 401 (tokenVersion incremented)
- [ ] Invalid refresh token → 401 from `/auth/refresh`

## Runtime
- [ ] WebSocket sync: two devices add items → both see updates
- [ ] Due-date cron: create bill due tomorrow → notification log created within 10 min
- [ ] Mark paid → `paidAt` set, `lastNotifiedAt` unchanged

## Post-deploy (Railway)
- [ ] `https://your-app.onrender.com/health` → 200
- [ ] UptimeRobot / Better Uptime pings every 5 min (see below)
- [ ] Flutter app connects to public backend URL

## Flutter app flow
- [ ] Splash → Onboarding → Sign up → Master password → Dashboard
- [ ] Login → biometric unlock → Dashboard
- [ ] Vault add/edit/delete works end-to-end
- [ ] Bills add/markPaid/delete works end-to-end
- [ ] Settings: logout navigates to login; delete account clears session
