#!/usr/bin/env bash
# One-command production deploy.
# Usage: bash scripts/deploy.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶ Applying DB migrations..."
cd backend
npx prisma migrate deploy

echo "▶ Committing & pushing (triggers Railway + CI)..."
cd ..
git add -A
git commit -m "chore: production deploy config + migrations" || echo "Nothing to commit"
git push

echo "✓ Deployed. Watch: https://railway.app"
