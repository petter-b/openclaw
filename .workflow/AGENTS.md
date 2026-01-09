# Agent Workflow Guide

> **You are in `clawdbot-dev`** (private fork). This is the primary development environment.
> PRs flow: `dev` → `fork` (public) → `upstream` (clawdbot/clawdbot)

## Directory Structure

```
.workflow/
├── AGENTS.md               # This file - main workflow guide
└── automation/
    ├── agent-automation.md # Multi-agent coordination
    └── infrastructure.md   # Mac mini + k3s + Tailscale

.claude/
├── CLAUDE.md               # Points here
├── settings.json           # Permissions and hooks
├── commands/dev/           # Slash commands (dev:*)
├── skills/                 # Auto-applied knowledge
│   ├── writing-tests/      # TDD patterns
│   ├── e2e-testing/        # E2E patterns
│   └── reviewing-code/     # Code review checklists
└── hooks/pre-bash.sh       # Pre-bash validation
```

### What Stays in Dev Repo (Never Push to Fork/Upstream)

| Content | Location |
|---------|----------|
| Workflow docs | `.workflow/` |
| Claude Code config | `.claude/` |
| Setup scripts | `scripts/setup-*.sh` |

**Explore locally:** `CLAUDE.md` (root) for project standards, `package.json` for commands, `src/**/*.test.ts` for test patterns.

---

## Quick Start

```bash
/dev:help              # List all dev commands
/dev:fix-issue <num>   # Fix an upstream issue
/dev:pr-review <num>   # Review a PR (read-only)
/dev:pr-test <num>     # Test a PR locally
/dev:gate              # Quality gate - run before every commit
```

---

## Git Remotes (Three-Remote Model)

| Remote | Repository | Purpose |
|--------|------------|---------|
| `dev` | petter-b/clawdbot-dev (private) | Daily development |
| `fork` | petter-b/clawdbot (public) | PR staging, mirrors upstream |
| `upstream` | clawdbot/clawdbot | PR target only, never push directly |

### Dev-Only Files (Never Push to Fork/Upstream)

```
.workflow/           # This workflow documentation
.claude/             # Claude Code config (slash commands, hooks)
scripts/setup-*.sh   # Local setup scripts
```

---

## Contributing to Upstream

### Workflow 1: Fixing an Issue

```bash
# 1. Sync from upstream
git fetch upstream
git checkout main
git merge upstream/main
git push dev main

# 2. Create PR branch from upstream/main
git checkout -b pr/fix-issue-123 upstream/main

# 3. Develop with TDD
/dev:tdd red "fix <issue description>"   # Write failing test
/dev:tdd green                            # Implement fix
/dev:gate                                 # Verify all passes

# 4. Commit (scoped) and push to public fork
scripts/committer "fix: description (#123)" src/file.ts src/file.test.ts
git push fork pr/fix-issue-123

# 5. Create PR
gh pr create --repo clawdbot/clawdbot \
  --base main \
  --head petter-b:pr/fix-issue-123 \
  --title "fix: description" \
  --body "Closes #123

## Summary
- What this fixes

## Test plan
- [x] Added regression test
- [x] Ran /dev:gate"
```

### Workflow 2: Reviewing a PR (Read-Only)

```bash
# View PR details and diff - do NOT checkout
gh pr view 123 --repo clawdbot/clawdbot
gh pr diff 123 --repo clawdbot/clawdbot

# Review checklist:
# - Security: input validation, injection, secrets
# - Quality: error handling, edge cases, types
# - Style: <700 LOC files, no over-engineering
# - Tests: adequate coverage
# - CHANGELOG: entry with PR # and contributor thanks
```

### Workflow 3: Testing a PR Locally

```bash
# 1. Create temp branch
git checkout -b temp/test-pr-123 main

# 2. Fetch and apply PR
gh pr checkout 123 --repo clawdbot/clawdbot

# 3. Test
/dev:gate
/dev:e2e

# 4. Clean up
git checkout main
git branch -D temp/test-pr-123
```

---

## One-Shot Prompt Templates

**Preferred: Use slash commands** (they include full context):
- `/dev:fix-issue 123` - Fix issue #123
- `/dev:pr-review 456` - Review PR #456
- `/dev:pr-test 456` - Test PR #456 locally

**Alternative: Copy/paste prompts** for manual sessions:

| Task | Prompt File |
|------|-------------|
| Fix an issue | `prompts/fix-issue.md` |
| Review a PR | `prompts/pr-review.md` |
| Implement a feature | `prompts/new-feature.md` |

---

## Slash Commands Reference

### Upstream Contributions
| Command | Purpose |
|---------|---------|
| `/dev:fix-issue <num>` | Fix an upstream issue with TDD |
| `/dev:pr-review <num>` | Review a PR (read-only) |
| `/dev:pr-test <num>` | Test a PR locally |

### Quality & Testing
| Command | Purpose |
|---------|---------|
| `/dev:gate` | **Run before every commit** - lint, build, test |
| `/dev:test [pattern]` | Run tests (add `--coverage` for report) |
| `/dev:e2e [pattern]` | Run E2E tests |
| `/dev:coverage [path]` | Analyze coverage gaps |

### Workflow
| Command | Purpose |
|---------|---------|
| `/dev:tdd red [feature]` | Write failing tests first |
| `/dev:tdd green` | Implement to pass tests |
| `/dev:tdd refactor` | Improve with tests passing |
| `/dev:commit "msg" files` | Safe commit via scripts/committer |
| `/dev:help` | List all commands |

---

## Quality Standards

### Before Every Commit
```bash
/dev:gate   # or manually: pnpm lint && pnpm build && pnpm test --run
```

### PR Title Format (Conventional Commits)
- `feat(scope): add feature`
- `fix(scope): fix bug`
- `refactor(scope): improve code`
- `docs: update guide`

### CHANGELOG Entry Format

From steipete's commits:
```markdown
- Telegram: retry long-polling conflicts with backoff to avoid fatal exits.
- Onboarding: QuickStart auto-installs the Gateway daemon with Node.
```

For external contributors, add thanks:
```markdown
- WhatsApp: group /model list output by provider. (#456) - thanks @mcinteerj
```

### Code Standards (from root CLAUDE.md)
- 70% test coverage threshold
- Files under ~700 LOC
- No `any` types
- Extract helpers instead of duplicating

---

## Multi-Agent Safety

When multiple agents work in parallel:

| Rule | Reason |
|------|--------|
| Don't switch branches | Other agents may be on them |
| Don't stash | Affects shared state |
| Don't force push | Destroys others' work |
| Scope commits to your files | Avoid conflicts |
| Use worktrees for isolation | `.worktrees/<agent>/` |

---

## Where to Find Things

| Need | Location |
|------|----------|
| Project coding standards | `CLAUDE.md` (root, synced from upstream) |
| Test patterns | `src/**/*.test.ts` |
| E2E patterns | `test/**/*.e2e.test.ts` |
| Test helpers | `src/gateway/test-helpers.ts` |
| CLI commands | `package.json` scripts |
| Slash commands | `.claude/commands/dev/` |

### Skills (Auto-Applied)

| Skill | Triggers When |
|-------|---------------|
| `writing-tests` | Writing or modifying tests, implementing features |
| `e2e-testing` | Writing integration tests, spawning processes |
| `reviewing-code` | After significant code changes, before commits |

### Workflow Documentation

| Trigger | Document |
|---------|----------|
| Multi-agent setup | `automation/agent-automation.md` |
| Infrastructure | `automation/infrastructure.md` |

---

## Troubleshooting

### Tests Timeout
Tests hanging or taking >30 seconds usually means stuck processes or port conflicts.

```bash
pgrep -f clawdbot          # Check for stuck gateway processes
pkill -f clawdbot          # Kill them
lsof -i :8080              # Check if port is in use
```

### E2E "Connection Refused"
Gateway not running. The `/dev:e2e` command spawns it automatically via `pnpm test:e2e`.

If running manually, ensure gateway is started first.

### Worktree Conflicts
"Branch already checked out" errors occur when multiple agents try to use the same branch.

```bash
git worktree list          # See all worktrees
git worktree remove <path> # Remove a stuck worktree
```

Each agent should have its own worktree under `.worktrees/`.

### Lint Fails
Biome formatting issues can often be auto-fixed.

```bash
pnpm format                # Auto-fix formatting
pnpm lint                  # See remaining issues
```

**Explore:** `biome.json` for lint rules.

---

## Upstream Patterns

### Current Open Issues (Good Starting Points)
- Issues labeled `bug` have clear scope
- Many issues unlabeled - opportunity to help triage
- Check https://github.com/clawdbot/clawdbot/issues

### PR Expectations
- Focused scope (one thing per PR)
- Tests for new/changed behavior
- CHANGELOG entry with PR # and thanks
- Conventional commit title

### AI-Assisted PRs Welcome
From upstream CONTRIBUTING.md:
- Mark as AI-assisted in PR description
- Note testing level (untested/lightly/fully tested)
- Include prompts if helpful
- Confirm you understand the code
