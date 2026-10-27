/**
 * CORS origin policy smoke checks.
 *
 * The production dashboard mirrors (Vercel + Cloudflare dpdns) must be able
 * to read responses. Auth is Bearer-only, so any browser origin is allowed
 * and credentials stay off.
 *
 * Run: node scripts/cors-probe.mjs
 * (expects a local server on PORT, default 3000)
 */
const base = process.env.PROBE_URL || 'http://127.0.0.1:3000';
const origins = [
  null, // native client
  'https://aethel-dash.vercel.app',
  'https://aethelreborn.dpdns.org',
  'http://localhost:5173',
  'https://evil.example',
];

let failed = 0;
for (const origin of origins) {
  const headers = { Accept: 'application/json' };
  if (origin) headers.Origin = origin;
  const res = await fetch(`${base}/health`, { headers });
  const acao = res.headers.get('access-control-allow-origin');
  const ok = origin ? acao === origin : true;
  const label = origin ?? '(no Origin)';
  if (!ok) {
    failed += 1;
    console.error(`FAIL ${label} → status=${res.status} ACAO=${acao}`);
  } else {
    console.log(`ok   ${label} → status=${res.status} ACAO=${acao ?? '-'}`);
  }
}
if (failed > 0) {
  console.error(`${failed} CORS probe(s) failed`);
  process.exit(1);
}
console.log('all CORS probes passed');
