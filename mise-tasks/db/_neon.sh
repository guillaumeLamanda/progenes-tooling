# shellcheck shell=bash
# Helpers sourced by the db:* tasks. Not executable, so mise doesn't list it as a task.

require_neon_project() {
	if [ -z "${NEON_PROJECT_ID:-}" ]; then
		echo "❌ NEON_PROJECT_ID not set in mise.toml" >&2
		exit 1
	fi
}

# Neon branch for a git branch: "${DB_BRANCH_PREFIX}<git branch>" with unsafe characters
# replaced. DB_BRANCH_PREFIX defaults to "preview/" and must match the neon-cleanup workflow.
neon_branch_name() {
	local LC_ALL=C name="${DB_BRANCH_PREFIX-preview/}$1"
	printf '%s' "${name//[^a-zA-Z0-9\/._-]/-}"
}

neon_branch_exists() {
	neon branches list --project-id "$NEON_PROJECT_ID" --output json |
		jq -e --arg name "$1" 'any(.[]; .name == $name)' >/dev/null
}
