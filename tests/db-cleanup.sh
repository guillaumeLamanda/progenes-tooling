#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK="$ROOT/mise-tasks/db/cleanup"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/db-cleanup-test.XXXXXXXX")
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/tests/fixtures/db-cleanup:$PATH"
export NEON_PROJECT_ID=test-project
export MOCK_NEON_BRANCHES="$TMP/branches.json" MOCK_NEON_DELETED="$TMP/deleted"

cat >"$MOCK_NEON_BRANCHES" <<'JSON'
[
	{"id": "br-main", "name": "main", "current_state": "ready", "default": true, "protected": false, "updated_at": "2026-01-01T00:00:00Z"},
	{"id": "br-prot", "name": "staging", "current_state": "ready", "default": false, "protected": true, "updated_at": "2026-01-01T00:00:00Z"},
	{"id": "br-old", "name": "preview/old", "current_state": "archived", "default": false, "protected": false, "updated_at": "2026-02-01T00:00:00Z"},
	{"id": "br-stale", "name": "preview/stale", "current_state": "archived", "default": false, "protected": false, "updated_at": "2026-03-01T00:00:00Z"},
	{"id": "br-live", "name": "preview/live", "current_state": "ready", "default": false, "protected": false, "updated_at": "2026-01-15T00:00:00Z"}
]
JSON

reset() { : >"$MOCK_NEON_DELETED"; export MOCK_SELECT='' MOCK_FZF_CANCEL=false MOCK_NEON_FAIL=''; }
run_task() {
	local mode=${1:-} input=${2:-}
	if printf '%s' "$input" | "$TASK" ${mode:+"$mode"} >"$TMP/output" 2>"$TMP/error"; then STATUS=0; else STATUS=$?; fi
}
fail() { printf 'FAIL: %s\n' "$1" >&2; cat "$TMP/output" "$TMP/error" >&2; exit 1; }
contains() { grep -F -- "$1" "$TMP/output" >/dev/null || fail "missing $1"; }
lacks() { ! grep -F -- "$1" "$TMP/output" >/dev/null || fail "unexpected $1"; }
deleted() { [ "$(sort "$MOCK_NEON_DELETED" | tr '\n' ' ')" = "$1" ] || fail "deleted '$(tr '\n' ' ' <"$MOCK_NEON_DELETED")', expected '$1'"; }

reset
run_task --list
[ "$STATUS" -eq 0 ]
contains 'preview/old'
contains 'preview/live'
lacks 'staging'
lacks 'br-'
[ "$(sed -n 3p "$TMP/output" | cut -c1-11)" = 'preview/old' ] || fail 'oldest archived branch should sort first'
deleted ''
printf 'ok: inventory hides default and protected branches\n'

reset
export MOCK_SELECT=archived
run_task --dry-run
contains 'Dry run: no branches deleted.'
deleted ''
run_task '' $'n\n'
contains 'Cancelled.'
deleted ''
export MOCK_FZF_CANCEL=true
run_task
contains 'Cancelled.'
deleted ''
printf 'ok: dry run and cancellation\n'

reset
export MOCK_SELECT='preview/old preview/live'
run_task '' $'y\n'
[ "$STATUS" -eq 0 ]
contains '2 deleted, 0 failed'
deleted 'br-live br-old '
printf 'ok: multi-selection deletes by ID\n'

reset
export MOCK_SELECT=archived MOCK_NEON_FAIL=br-old
run_task '' $'y\n'
[ "$STATUS" -eq 1 ]
contains '1 deleted, 1 failed'
deleted 'br-stale '
printf 'ok: partial failure reported\n'

reset
run_task
contains 'No branches selected.'
printf '[]' >"$MOCK_NEON_BRANCHES"
run_task
contains 'No deletable branches found.'
printf 'ok: empty selection and inventory\n'

printf 'All db cleanup tests passed.\n'
