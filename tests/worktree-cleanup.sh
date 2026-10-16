#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK="$ROOT/mise-tasks/worktree/cleanup"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/worktree-cleanup-test.XXXXXXXX")
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/tests/fixtures/worktree-cleanup:$PATH"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR || true
count=0

new_repo() {
	count=$((count + 1))
	REPO="$TMP/repo-$count"
	git init --quiet --initial-branch=main "$REPO"
	printf 'initial\n' >"$REPO/tracked"
	git -C "$REPO" add tracked
	git -C "$REPO" commit --quiet -m initial
	export MOCK_GH_MODE='' MOCK_DEFAULT=main MOCK_SELECT='' MOCK_FZF_CANCEL=false MOCK_MUTATE=''
}
worktree() {
	git -C "$REPO" worktree add --quiet -b "$1" "$REPO/$1"
	# Worktrees are outside the main tree so they do not make it dirty.
	git -C "$REPO" worktree move "$REPO/$1" "$TMP/tree-$count-$1"
	TREE="$TMP/tree-$count-$1"
}
run_task() {
	local mode=${1:-} input=${2:-}
	if (cd "$REPO"; printf '%s' "$input" | "$TASK" ${mode:+"$mode"}) >"$TMP/output" 2>"$TMP/error"; then
		STATUS=0
	else
		STATUS=$?
	fi
}
contains() {
	if ! grep -F -- "$1" "$TMP/output" >/dev/null; then
		printf 'FAIL: missing %s\n' "$1" >&2
		cat "$TMP/output" "$TMP/error" >&2
		exit 1
	fi
}
exists() { [ -d "$1" ] || { printf 'FAIL: missing directory %s\n' "$1" >&2; exit 1; }; }
removed() { [ ! -d "$1" ] || { printf 'FAIL: directory still exists %s\n' "$1" >&2; exit 1; }; }

new_repo
worktree merged
MERGED=$TREE
worktree dirty
printf 'untracked\n' >"$TREE/new file"
worktree locked
git -C "$REPO" worktree lock "$TREE"
worktree develop
export MOCK_DEFAULT=develop
run_task --list
[ "$STATUS" -eq 0 ]
contains '#42'
contains 'merged'
contains 'blocked:primary'
contains 'blocked:dirty'
contains 'blocked:locked'
contains 'blocked:default-branch'
exists "$MERGED"
printf 'ok: inventory and protections\n'

export MOCK_SELECT=merged
run_task --dry-run
contains 'Dry run: no worktrees removed.'
exists "$MERGED"
run_task '' $'n\n'
contains 'Cancelled.'
exists "$MERGED"
export MOCK_FZF_CANCEL=true
run_task
contains 'Cancelled.'
exists "$MERGED"
export MOCK_FZF_CANCEL=false
run_task '' $'y\n'
[ "$STATUS" -eq 0 ]
removed "$MERGED"
git -C "$REPO" show-ref --verify --quiet refs/heads/merged
printf 'ok: dry run, cancellation, removal, branch retention\n'

new_repo
worktree feature
for mode in offline pr-failure none open closed mismatch cross; do
	export MOCK_GH_MODE=$mode MOCK_SELECT=feature
	run_task --list
	case "$mode" in
		offline|pr-failure) contains unknown ;;
		none|cross) contains none ;;
		open) contains open ;;
		closed) contains closed ;;
		mismatch) contains 'merged*' ;;
	esac
	run_task '' $'y\n'
	contains 'WARNING:'
	contains 'Cancelled.'
	exists "$TREE"
done
run_task '' $'remove unmerged\ny\n'
[ "$STATUS" -eq 0 ]
removed "$TREE"
printf 'ok: PR states, lookup failures, fork exclusion, explicit risk acceptance\n'

for mutation in dirty tracked lock head; do
	new_repo
	worktree feature
	export MOCK_SELECT=feature MOCK_MUTATE=$mutation MOCK_MUTATE_PATH=$TREE
	run_task '' $'y\n'
	[ "$STATUS" -eq 1 ]
	contains '0 removed, 1 failed'
	exists "$TREE"
done
printf 'ok: dirty, tracked, locked, and HEAD changes rechecked\n'

new_repo
worktree feature
REPO=$TREE
export MOCK_SELECT=feature
run_task --list
contains 'blocked:current'
run_task '' $'y\n'
contains 'No removable worktrees selected.'
exists "$TREE"
printf 'ok: current worktree protected\n'

new_repo
worktree detached
git -C "$TREE" checkout --quiet --detach
run_task --list
contains '(detached)'
contains unknown
printf 'ok: detached HEAD\n'

new_repo
SPECIAL="$TMP/worktree with spaces"$'\tand\nnewlines\n'
git -C "$REPO" worktree add --quiet -b special "$SPECIAL"
export MOCK_SELECT=special
run_task '' $'y\n'
[ "$STATUS" -eq 0 ]
removed "$SPECIAL"
git -C "$REPO" show-ref --verify --quiet refs/heads/special
printf 'ok: paths with spaces, tabs, and newlines\n'

new_repo
worktree first
FIRST=$TREE
worktree second
SECOND=$TREE
worktree dirty
printf 'untracked\n' >"$TREE/untracked"
run_task '' $'y\n'
[ "$STATUS" -eq 0 ]
contains '2 removed, 0 failed'
removed "$FIRST"
removed "$SECOND"
exists "$TREE"
exists "$REPO"
printf 'ok: multi-selection skips protected and dirty rows\n'

new_repo
worktree missing
mv "$TREE" "$TREE-moved"
run_task --list
contains 'blocked:prunable'
printf 'ok: missing/prunable worktree protected\n'

printf 'All worktree cleanup tests passed.\n'
