# progenes-tooling

Tooling shared by progenes projects (phoenix, cybelle, croisement-kiwi-france).
Projects pin a release tag (`v1.0.0`); Renovate bumps it.

## Renovate presets

```json
{ "extends": ["github>guillaumeLamanda/progenes-tooling", "github>guillaumeLamanda/progenes-tooling:payload"] }
```

- `default.json`: base preset (best practices, weekend schedule, automerge minor, grouping: pnpm, GitHub Actions, Effect-TS, Apollo client). It also lets Renovate bump the mise `?ref=` below.
- `payload.json`: Payload CMS / Lexical / Sharp rules.

## mise tasks

```toml
[settings]
experimental = true # required for git:: task includes

[task_config]
includes = [
  "mise-tasks", # keep the project's own file tasks
  "git::https://github.com/guillaumeLamanda/progenes-tooling.git//mise-tasks?ref=v1.0.0",
]

[env]
NEON_PROJECT_ID = "…"          # required
# NEON_PARENT_BRANCH = "main"
# DB_ENV_FILE = ".env.local"    # e.g. "website/.env.local"
# DB_BRANCH_PREFIX = "preview/" # must match the neon-cleanup workflow
```

Tasks: `db:sync` (alias `db`), `db:status`, `db:list`, `db:delete`, `db:reset`, `db:cleanup`, `setup`, `uninstall`, `nvim:trust`, `worktree:cleanup`.
They need `neon` (`npm:neonctl`), `vc`, `jq` and `hk` in the project's `[tools]`.

### Worktree cleanup

```sh
mise run worktree:cleanup           # Tab to select, Enter to review, then confirm
mise run worktree:cleanup --list    # Inspect without selecting or deleting
mise run worktree:cleanup --dry-run # Select and preview without deleting
```

Requires `git`, `gh`, `jq`, and `fzf` on PATH, with `gh` authenticated for PR status.
Lists all worktrees of the current repository with branch, clean/dirty status
(including untracked files), PR number, PR state, removal eligibility, and path.
The most recently updated same-repository PR for each branch is shown. `merged*`
means local HEAD differs from the PR head, not that all local commits were merged.
Failed GitHub lookups show `unknown`, not `none`.

Primary, current, locked, prunable, bare, main/master/default-branch, dirty, and
unreadable worktrees cannot be removed. Other worktrees can be selected regardless
of PR state, but anything without a matching merged PR requires typing
`remove unmerged` before the final confirmation. Status and HEAD are rechecked
before each removal. The task never forces removal or deletes local/remote branches.

Run regression tests with `mise run test`.

## Development

```sh
mise trust
mise install
mise run ci    # All checks, also run by GitHub Actions on Linux and macOS
mise run lint  # ShellCheck, actionlint, JSON validation
mise run test  # Worktree cleanup regression tests, no GitHub credentials needed
```

The root `mise.toml` pins development tools. Repository-only checks live there,
so projects importing `mise-tasks` do not inherit this repository's CI tasks.
Tests use temporary repositories and mocked GitHub/selection commands. The test
runner uses `/bin/bash` to check compatibility with macOS's bundled Bash.

## GitHub Actions

| | Usage |
|---|---|
| Delete Neon branch on PR close | `uses: guillaumeLamanda/progenes-tooling/.github/workflows/neon-cleanup.yml@v1.0.0` |
| opencode on `/oc` comments | `uses: guillaumeLamanda/progenes-tooling/.github/workflows/opencode.yml@v1.0.0` |
| pnpm + Node + install | `uses: guillaumeLamanda/progenes-tooling/actions/setup@v1.0.0` |

Caller examples are at the top of each workflow file.

## Biome

```sh
pnpm add -D "@progenes/biome-config@github:guillaumeLamanda/progenes-tooling#v1.0.0&path:/biome"
```

```jsonc
{ "extends": ["@progenes/biome-config/base", "@progenes/biome-config/anti-slop"] }
```

- `base`: VCS, recommended rules, domains, organize imports. Formatting style stays per project.
- `anti-slop`: GritQL rules in `biome/rules`, reported as warnings until existing violations are fixed. They apply to every linted file: Biome 2.5 ignores
  `{ "path", "includes" }` plugin entries and a project cannot remove inherited plugins.
  Exclude code with an override that sets `"linter": { "enabled": false }`.
- CI must install dependencies before running Biome (`setup-biome` alone cannot resolve `extends`).
