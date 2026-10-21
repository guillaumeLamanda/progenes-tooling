#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=mise-tasks/db/_neon.sh
source "$ROOT/mise-tasks/db/_neon.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
expect_name() { [ "$(neon_branch_name "$1")" = "$2" ] || fail "neon_branch_name '$1' gave '$(neon_branch_name "$1")', expected '$2'"; }

unset DB_BRANCH_PREFIX
expect_name 'feat/image-zoom' 'preview/feat/image-zoom'
expect_name 'fix: two words' 'preview/fix--two-words'
expect_name 'café' 'preview/caf--' # byte-wise: each UTF-8 byte becomes a dash
DB_BRANCH_PREFIX='' expect_name 'feat/x' 'feat/x'
DB_BRANCH_PREFIX='dev/' expect_name 'feat/x' 'dev/feat/x'
printf 'ok: neon_branch_name prefixes and sanitizes\n'

if (unset NEON_PROJECT_ID; require_neon_project) 2>/dev/null; then fail 'require_neon_project must exit without NEON_PROJECT_ID'; fi
(NEON_PROJECT_ID=p; require_neon_project) || fail 'require_neon_project must pass with NEON_PROJECT_ID'
printf 'ok: require_neon_project\n'
