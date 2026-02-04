# Infrastructure

## Worktrees

`./.workflow/scripts/setup-worktrees.sh [dir]` → creates `agent-{dev,test,review}` worktrees.

## tmux

Socket: `${TMPDIR}/openclaw-tmux-sockets/openclaw.sock`

## Daily Builds

| Script | Target |
|--------|--------|
| `./.workflow/scripts/daily-all.sh` | ARM + x86 parallel |
| `./.workflow/scripts/daily-build.sh` | ARM (local) |
| `./.workflow/scripts/daily-build-k8s.sh` | x86 (k8s) |

Results: `~/.openclaw/daily-builds/summary-$(date +%Y-%m-%d).log`

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `OPENCLAW_CONFIG_PATH` | Config file location |
| `OPENCLAW_GATEWAY_URL` | Gateway WebSocket URL |
| `OPENCLAW_GATEWAY_PORT` | Gateway port |
| `OPENCLAW_TMUX_SOCKET_DIR` | tmux socket directory |
| `OPENCLAW_SKIP_PROVIDERS` | Skip provider init (testing) |
| `OPENCLAW_ENABLE_BRIDGE_IN_TESTS` | Enable bridge (testing) |

---

## Log Locations

| Log | Location |
|-----|----------|
| Gateway | stdout/stderr |
| Sessions | `~/.openclaw/agents/main/sessions/*.jsonl` |
| Agent | `~/.claude/session.log` |
| macOS unified | `./scripts/clawlog.sh --follow` |

---

## Fork Safety

| Script | Purpose |
|--------|---------|
| `./.workflow/scripts/audit-fork-config.sh` | Validate fork configuration |

Run before upstream syncs to ensure `.gitattributes` merge=ours only protects fork-only files.

---

## Troubleshooting

```bash
pgrep -f openclaw && pkill -f openclaw    # Stuck processes
lsof -i :8080                             # Port conflicts
git worktree list                         # Worktree issues
pnpm format                               # Lint auto-fix
tailscale status                          # Network check
ls -la ${TMPDIR}/openclaw-tmux-sockets/   # tmux sockets
tmux -S $SOCKET kill-server               # Reset tmux
./.workflow/scripts/audit-fork-config.sh  # Validate fork config
```
