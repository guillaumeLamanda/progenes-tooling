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

Tasks: `db:sync` (alias `db`), `db:status`, `db:list`, `db:delete`, `db:reset`, `db:cleanup`, `setup`, `uninstall`, `nvim:trust`.
They need `neon` (`npm:neonctl`), `vc`, `jq` and `hk` in the project's `[tools]`.

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
