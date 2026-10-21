#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK="$ROOT/mise-tasks/worktree/ceiling"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/worktree-ceiling-test.XXXXXXXX")
trap 'rm -rf "$TMP"' EXIT
export MISE_CONFIG_DIR="$TMP/config"
MISERC="$MISE_CONFIG_DIR/miserc.toml"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR || true

git init -q "$TMP/repo"
git -C "$TMP/repo" commit -q --allow-empty -m init
git -C "$TMP/repo" worktree add -q "$TMP/repo/.worktrees/feature" -b feature
REPO=$(cd "$TMP/repo" && pwd -P)
CEILING="\"$REPO/.worktrees\""

fail() { printf 'FAIL: %s\n' "$1" >&2; cat "$MISERC" >&2 2>/dev/null || true; exit 1; }
run_task() { (cd "$1" && "$TASK") >"$TMP/output" 2>&1 || STATUS=$?; }

STATUS=0
run_task "$TMP/repo/.worktrees/feature"
[ "$STATUS" -eq 0 ] || fail 'task failed on a fresh config dir'
[ "$(cat "$MISERC")" = "ceiling_paths = [$CEILING]" ] || fail 'expected a new ceiling_paths line from a worktree'
run_task "$TMP/repo"
[ "$(grep -c ceiling_paths "$MISERC")" -eq 1 ] || fail 'rerun from the main checkout must not duplicate the entry'
grep -qF 'already in ceiling_paths' "$TMP/output" || fail 'rerun should report the existing entry'
printf 'ok: creates miserc.toml and is idempotent across checkouts\n'

printf 'env = ["dev"]\nceiling_paths = ["/elsewhere"]\n' >"$MISERC"
run_task "$TMP/repo"
[ "$(sed -n 2p "$MISERC")" = "ceiling_paths = [\"/elsewhere\", $CEILING]" ] || fail 'expected the entry appended to the existing array'
[ "$(sed -n 1p "$MISERC")" = 'env = ["dev"]' ] || fail 'other settings must be kept'
printf 'ceiling_paths = []\n' >"$MISERC"
run_task "$TMP/repo"
[ "$(cat "$MISERC")" = "ceiling_paths = [$CEILING]" ] || fail 'expected the entry added to an empty array'
printf 'ok: appends to single-line arrays\n'

printf 'ceiling_paths = [\n  "/elsewhere",\n]\n' >"$MISERC"
STATUS=0
run_task "$TMP/repo"
[ "$STATUS" -ne 0 ] || fail 'multi-line arrays must be refused'
[ "$(wc -l <"$MISERC" | tr -d ' ')" -eq 3 ] || fail 'a refused file must be left unchanged'
printf 'ok: refuses multi-line arrays without editing them\n'
