#!/usr/bin/env bash
# Local room server for testing multiplayer games. Installs the dependencies
# the first time, then runs the server on http://127.0.0.1:8787 with the
# group key "test" (Plugins/Online settings).
set -e
cd "$(dirname "$0")/server"
[ -d node_modules ] || npm ci
npm run dev
