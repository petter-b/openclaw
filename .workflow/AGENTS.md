# Agent Workflow Guide

**Private fork** (`openclaw-dev`). PRs flow: `dev` → `fork` → `upstream`

Agent identity: see `~/agent-config/AGENTS.md`.

## Quick Start

1. Root `AGENTS.md` → source of truth for coding standards (**never edit, upstream-only**)
2. `/help` → available commands
3. `/dev:gate` → run before every commit

---

## CLI Usage

**Production** — use the globally installed `openclaw` command (default profile, port 18789):

```bash
openclaw channels status
openclaw gateway restart
openclaw config get bindings
```

**Test gateway** — use `pnpm openclaw --profile test` to run from source (port 19213, state in `~/.openclaw-test/`):

```bash
pnpm openclaw --profile test gateway run --port 19213 --bind loopback
pnpm openclaw --profile test config set ...
pnpm openclaw --profile test channels status
```

For development builds/tests, use `pnpm build`, `pnpm test`, etc.

---

**Dev-only** (never push): `.workflow/`, `.claude/`

**Never edit upstream files**: Root `AGENTS.md`, `CHANGELOG.md`, `package.json`, `src/**` (unless contributing via PR)

---

## Commands

Run `/help` for full list.

---

## Upstream Contributions

| Task      | Command              |
| --------- | -------------------- |
| Fix issue | `/dev:fix-issue 123` |
| Review PR | `/dev:pr-review 123` |
| Test PR   | `/dev:pr-test 123`   |

---

## Builds

| Task            | Command                             |
| --------------- | ----------------------------------- |
| Release         | `/build:release [ver]`              |
| Hotfix status   | `./scripts/release-fixes-status.sh` |
| Daily (ARM+x86) | `./.workflow/scripts/daily-all.sh`  |

Hotfix branches: `hotfix/*` → auto-applied. See `automation/infrastructure.md` for details.

---

## Standards

See root `AGENTS.md`. Key: `/dev:gate` before commits, `scripts/committer` for scoped commits.

---

## Shell Scripts (Fork-Only)

Applies to: `.workflow/scripts/`, fork-specific `scripts/` (see `scripts/README.md`), `.claude/` scripts.

Standards: `#!/usr/bin/env bash`, `set -euo pipefail`, pass shellcheck. Fork linter: `.workflow/scripts/lint-fork-scripts.sh`.

---

## Workflow

**After upstream sync**: Run `/dev:docs-review` to check for doc drift (e.g., renamed files, broken references).

---

## Troubleshooting

See `automation/infrastructure.md` for logs, environment variables, and troubleshooting commands.

---

## macOS Gateway Rules

**NEVER run `scripts/restart-mac.sh` without explicit user request.** It rebuilds Swift (~80s) and is rarely needed.

### Gateway Commands

| Task            | Command                    |
| --------------- | -------------------------- |
| Restart gateway | `openclaw gateway restart` |
| Check status    | `openclaw gateway status`  |
| Install/start   | `openclaw gateway install` |
| View logs       | `./scripts/clawlog.sh -f`  |

### When Rebuild is Required (ask user first)

- Swift/SwiftUI code changed
- App version bump
- Release prep

### When Restart Suffices (no rebuild)

- Config changed → `openclaw gateway restart`
- TypeScript changed → `pnpm build && openclaw gateway restart`
- Gateway unresponsive → `openclaw gateway restart`

---

## Test Gateway (from source)

Isolated gateway running the latest code from the repo. Separate from the production gateway (global install).

### Port Allocation

| Profile              | Port  | State dir           | How to run                                                              |
| -------------------- | ----- | ------------------- | ----------------------------------------------------------------------- |
| default (production) | 18789 | `~/.openclaw/`      | `openclaw gateway run`                                                  |
| dev                  | 19001 | `~/.openclaw-dev/`  | `pnpm openclaw --dev gateway run`                                       |
| test                 | 19213 | `~/.openclaw-test/` | `pnpm openclaw --profile test gateway run --port 19213 --bind loopback` |

Each profile gets fully isolated config, credentials, and sessions.

**Port blocks:** Each gateway uses a block of ~112 ports (WS +0, bridge +1, browser control +2, canvas +4, CDP +11..+110). Profiles are spaced 212 apart to avoid collisions.

### First-time Setup

```bash
# 1. Build from source
pnpm build

# 2. Run the full onboarding wizard for the test profile
pnpm openclaw --profile test onboard
# - Select mode: local
# - Auth: pick Google Antigravity OAuth + Google Gemini CLI OAuth (or any providers you need)
# - Gateway port defaults to 19213 for the test profile
# - Skip "hatching" (optional first-message step — not needed for dev/testing)

# 3. (Optional) Swap primary/fallback models after onboarding
pnpm openclaw --profile test config set agents.defaults.model.primary "google-antigravity/claude-opus-4-5-thinking"
pnpm openclaw --profile test config set agents.defaults.model.fallbacks '["google-gemini-cli/gemini-3-pro-preview"]'
```

To add more providers later without re-running full onboarding:

```bash
pnpm openclaw --profile test configure --section model
```

### Commands

| Task               | Command                                                              |
| ------------------ | -------------------------------------------------------------------- |
| Start test gateway | `pnpm openclaw --profile test gateway run`                           |
| Start as daemon    | `pnpm openclaw --profile test gateway run --daemon`                  |
| Stop test gateway  | `Ctrl+C` (foreground) or `pnpm openclaw --profile test gateway stop` |
| Check status       | `pnpm openclaw --profile test channels status --probe`               |
| Configure          | `pnpm openclaw --profile test config set <key> <value>`              |
| Add model provider | `pnpm openclaw --profile test configure --section model`             |
| Send test message  | `pnpm openclaw --profile test agent --message "ping"`                |

### Notes

- The test gateway runs latest source (auto-rebuilds if stale via `run-node.mjs`)
- Production gateway (global install) is unaffected — different port, different state dir
- `--bind loopback` restricts to localhost only (safe for testing)
- Port 19001 is reserved (already in use)
- Profiles are spaced 212 ports apart: 18789 → 19001 → 19213 (see `src/config/port-defaults.ts`)
- After changing config, restart the gateway for changes to take effect

---

## Learnings & Gotchas

Hard-won insights from past work. Keep this section tight — delete entries once they're obvious or obsolete.

### Testing

- `pnpm test | tail` stalls in background mode — run without pipes or use foreground.
- Vitest worker limit: use `npx vitest run --maxWorkers=6` (pnpm doesn't forward the flag; `pnpm test --maxWorkers=6` is silently ignored).
- Multi-layer defensive fixes (guard + catch) need independent tests per layer — a mock that rejects a function the guard prevents from being called gives false confidence.
- Sub-agent review should check: (a) overly broad error suppression, (b) mock verification — do mocks exercise the intended code path?

### Commits & PRs

- `scripts/committer` rejects `.` as path — always list files explicitly.
- PR branch naming: `fix/$ISSUE-$SLUG` (upstream) or `fix/$SLUG` (non-upstream).
- PR body should be concise: 3 lines (root cause, fix, test) — optimized for AI auto-approval.
- After squash onto fresh `upstream/main`, re-run `pnpm build && pnpm test` before pushing.

### Build Infrastructure

- `.worktrees/latest` is reserved for `/build:mac-clean` — never delete it.
- Gate order: `pnpm build && pnpm check && pnpm test` (build catches type errors first).
- `prek` is upstream-internal (not on npm) — `/dev:gate` is the local equivalent.

---

## Signals

Drop issues/ideas in `.workflow/signals/` as `YYYY-MM-DD-<topic>.md`.
