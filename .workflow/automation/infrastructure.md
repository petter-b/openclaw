# Infrastructure Setup Guide

> **Purpose**: Configure Mac mini (Apple Silicon), k3s cluster (x86), and Tailscale for AI agent automation with real clawdbot instances.
> This is a recommendation document based on user requirements.

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Tailscale Network                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐          ┌──────────────────────────┐   │
│  │   Mac mini M1    │          │     k3s Cluster (x86)    │   │
│  │  Apple Silicon   │◄────────►│                          │   │
│  │                  │          │  ┌────────────────────┐  │   │
│  │  - Claude Code   │          │  │  clawdbot-gateway  │  │   │
│  │  - Sandbox       │          │  │  (Docker/k8s pod)  │  │   │
│  │  - tmux agents   │          │  └────────────────────┘  │   │
│  │  - Real devices  │          │                          │   │
│  └──────────────────┘          │  ┌────────────────────┐  │   │
│                                │  │  test-runner       │  │   │
│                                │  │  (E2E tests)       │  │   │
│                                │  └────────────────────┘  │   │
│                                └──────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Mac mini Setup (Apple Silicon)

### Prerequisites

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install node@22 pnpm bun tmux tailscale

# Install Claude Code
npm install -g @anthropic-ai/claude-code
```

### Sandbox Strategy Decision

**Recommended: Git Worktrees (Native Isolation)**

For Mac mini Apple Silicon, we recommend **git worktrees** over Docker because:
- No x86 emulation overhead (Docker Desktop uses Rosetta 2)
- Native performance for builds and tests
- Simple setup, easy cleanup
- Each agent has fully isolated working directory
- Compatible with existing tmux + coding-agent skills

Docker sandboxing is available for untrusted code execution, but git worktrees are sufficient for development agent isolation.

### Git Worktree Setup

Use the provided setup script:

```bash
# Run the setup script (creates agent-dev, agent-test, agent-review worktrees)
./scripts/setup-worktrees.sh

# Or specify custom sandbox root
./scripts/setup-worktrees.sh ~/my-sandboxes
```

The script creates three worktrees and installs dependencies in each:
- `~/clawdbot-sandboxes/agent-dev` - Development agent
- `~/clawdbot-sandboxes/agent-test` - Test runner agent
- `~/clawdbot-sandboxes/agent-review` - Code review agent

Manual setup (if needed):

```bash
SANDBOX_ROOT=~/clawdbot-sandboxes
mkdir -p "$SANDBOX_ROOT"
git worktree add "$SANDBOX_ROOT/agent-dev" -b sandbox/agent-dev
(cd "$SANDBOX_ROOT/agent-dev" && pnpm install)
```

### Worktree Cleanup

```bash
# Remove worktree when done
git worktree remove ~/clawdbot-sandboxes/agent-dev

# Prune stale worktree references
git worktree prune
```

### Docker Sandboxing (Alternative)

For running untrusted code or needing full isolation:

```bash
# Build sandbox images (x86 emulation on ARM)
docker buildx create --use
scripts/sandbox-setup.sh
scripts/sandbox-common-setup.sh

# Run tests in container
docker run --rm \
  -v $PWD:/workspace \
  -w /workspace \
  clawdbot-sandbox-common:bookworm-slim \
  pnpm test
```

**Note:** Docker on Apple Silicon has performance overhead due to x86 emulation. Use only when necessary.

### tmux Agent Sessions

Setup isolated tmux sessions:

```bash
# Create socket directory (from skills/tmux/SKILL.md)
export CLAWDBOT_TMUX_SOCKET_DIR="${TMPDIR}/clawdbot-tmux-sockets"
mkdir -p "$CLAWDBOT_TMUX_SOCKET_DIR"

SOCKET="$CLAWDBOT_TMUX_SOCKET_DIR/clawdbot.sock"

# Create agent sessions
tmux -S "$SOCKET" new -d -s agent-dev -n main
tmux -S "$SOCKET" new -d -s agent-test -n main
tmux -S "$SOCKET" new -d -s agent-review -n main

# List sessions
tmux -S "$SOCKET" list-sessions
```

### Clawdbot Gateway on Mac mini

```bash
# Start gateway with specific config
export CLAWDBOT_CONFIG_PATH=~/.clawdbot/clawdbot.json

# Create config
cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "gateway": {
    "port": 8080,
    "bind": "tailnet"
  },
  "agent": {
    "model": "anthropic/claude-sonnet-4-20250514",
    "workspace": "~/clawdbot-workspace"
  }
}
EOF

# Start gateway
pnpm clawdbot gateway --port 8080 --bind tailnet
```

---

## k3s Cluster Setup (x86)

### Prerequisites

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Install Tailscale on cluster nodes
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key=tskey-xxx
```

### Clawdbot Gateway Deployment

> **Note:** The image `ghcr.io/anthropics/clawdbot:latest` is a placeholder. You must build and push your own image to a container registry before deploying.

Create `k8s/clawdbot-gateway.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clawdbot-gateway
  namespace: clawdbot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clawdbot-gateway
  template:
    metadata:
      labels:
        app: clawdbot-gateway
    spec:
      containers:
        - name: gateway
          image: ghcr.io/anthropics/clawdbot:latest
          args: ["gateway", "--port", "8080", "--bind", "lan"]
          ports:
            - containerPort: 8080
          env:
            - name: CLAWDBOT_CONFIG_PATH
              value: /config/clawdbot.json
          volumeMounts:
            - name: config
              mountPath: /config
            - name: sessions
              mountPath: /root/.clawdbot/sessions
      volumes:
        - name: config
          configMap:
            name: clawdbot-config
        - name: sessions
          persistentVolumeClaim:
            claimName: clawdbot-sessions
---
apiVersion: v1
kind: Service
metadata:
  name: clawdbot-gateway
  namespace: clawdbot
spec:
  selector:
    app: clawdbot-gateway
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: clawdbot-config
  namespace: clawdbot
data:
  clawdbot.json: |
    {
      "gateway": {
        "port": 8080,
        "bind": "lan"
      },
      "agent": {
        "model": "anthropic/claude-sonnet-4-20250514"
      }
    }
```

### E2E Test Runner Pod

Create `k8s/test-runner.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: e2e-tests
  namespace: clawdbot
spec:
  template:
    spec:
      containers:
        - name: test-runner
          image: clawdbot-sandbox-common:bookworm-slim
          command: ["pnpm", "test:e2e"]
          env:
            - name: CLAWDBOT_GATEWAY_URL
              value: "ws://clawdbot-gateway:8080"
          workingDir: /workspace
          volumeMounts:
            - name: workspace
              mountPath: /workspace
      volumes:
        - name: workspace
          hostPath:
            path: /path/to/clawdbot
      restartPolicy: Never
  backoffLimit: 3
```

---

## Tailscale Configuration

### Network Setup

```bash
# On Mac mini
sudo tailscale up --hostname=mac-mini-dev

# On k3s nodes
sudo tailscale up --hostname=k3s-node-1
sudo tailscale up --hostname=k3s-node-2

# Verify connectivity
tailscale status
```

### Access Control (ACL)

In Tailscale admin console, configure ACLs:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:dev"],
      "dst": ["tag:clawdbot:*"]
    }
  ],
  "tagOwners": {
    "tag:dev": ["user@example.com"],
    "tag:clawdbot": ["user@example.com"]
  }
}
```

### Service Discovery

```bash
# Access gateway from Mac mini
curl http://k3s-node-1:8080/health

# Access from anywhere on Tailnet
export CLAWDBOT_GATEWAY_URL="ws://k3s-node-1:8080"
pnpm clawdbot health
```

---

## Agent Workflow Architecture

### Development Workflow (Mac mini)

```
┌─────────────────────────────────────────────────────────────┐
│                      Mac mini (Primary)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  tmux session: agent-dev                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Claude Code                                         │   │
│  │  - Implements features                               │   │
│  │  - Runs local tests                                  │   │
│  │  - Uses scripts/committer                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  tmux session: agent-test                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Test Runner Agent                                   │   │
│  │  - Runs pnpm test:e2e                               │   │
│  │  - Reports failures                                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  tmux session: agent-review                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Code Reviewer Agent                                 │   │
│  │  - Reviews changes                                   │   │
│  │  - Checks security                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Integration Testing (k3s Cluster)

```
┌─────────────────────────────────────────────────────────────┐
│                    k3s Cluster (E2E)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Pod: clawdbot-gateway                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Real clawdbot instance                              │   │
│  │  - Accepts WebSocket connections                     │   │
│  │  - Processes messages                                │   │
│  │  - Stores sessions                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                            ▲                                │
│                            │                                │
│  Job: e2e-tests           │                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Test runner                                         │   │
│  │  - Connects to gateway                               │   │
│  │  - Sends test messages                               │   │
│  │  - Validates responses                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Automation Scripts

### Start All Agents

Create `scripts/start-agents.sh`:

```bash
#!/bin/bash
set -e

SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR}/clawdbot-tmux-sockets}"
SOCKET="$SOCKET_DIR/clawdbot.sock"

mkdir -p "$SOCKET_DIR"

# Kill existing sessions
tmux -S "$SOCKET" kill-server 2>/dev/null || true

# Create sessions
tmux -S "$SOCKET" new -d -s agent-dev -n main
tmux -S "$SOCKET" new -d -s agent-test -n main
tmux -S "$SOCKET" new -d -s agent-review -n main

# Setup environments
for session in agent-dev agent-test agent-review; do
  tmux -S "$SOCKET" send-keys -t "$session":main -- \
    "cd $(pwd) && export CLAWDBOT_GATEWAY_URL=ws://localhost:8080" Enter
done

echo "Agent sessions created. Connect with:"
echo "  tmux -S $SOCKET attach -t agent-dev"
```

### Run E2E on Cluster

Create `scripts/cluster-e2e.sh`:

```bash
#!/bin/bash
set -e

# Trigger E2E job on k3s
kubectl -n clawdbot delete job e2e-tests --ignore-not-found
kubectl -n clawdbot apply -f k8s/test-runner.yaml

# Wait for completion
kubectl -n clawdbot wait --for=condition=complete job/e2e-tests --timeout=600s

# Get logs
kubectl -n clawdbot logs job/e2e-tests
```

### Health Check All Services

Create `scripts/health-check.sh`:

```bash
#!/bin/bash

echo "=== Mac mini Gateway ==="
curl -s http://localhost:8080/health | jq .

echo ""
echo "=== k3s Gateway ==="
curl -s http://k3s-node-1:8080/health | jq .

echo ""
echo "=== tmux Sessions ==="
SOCKET="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR}/clawdbot-tmux-sockets}/clawdbot.sock"
tmux -S "$SOCKET" list-sessions 2>/dev/null || echo "No sessions running"
```

---

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `CLAWDBOT_CONFIG_PATH` | Config file location | `~/.clawdbot/clawdbot.json` |
| `CLAWDBOT_GATEWAY_URL` | Gateway WebSocket URL | `ws://k3s-node-1:8080` |
| `CLAWDBOT_GATEWAY_PORT` | Gateway port | `8080` |
| `CLAWDBOT_TMUX_SOCKET_DIR` | tmux socket directory | `${TMPDIR}/clawdbot-tmux-sockets` |
| `CLAWDBOT_SKIP_PROVIDERS` | Skip provider init (testing) | `1` |
| `CLAWDBOT_ENABLE_BRIDGE_IN_TESTS` | Enable bridge (testing) | `1` |

---

## Security Considerations

### Sandbox Isolation

1. **Docker sandboxes**: Use `clawdbot-sandbox-*` images for untrusted code
2. **Git worktrees**: Isolate agent workspaces
3. **Network segmentation**: Use Tailscale ACLs

### Credential Management

1. **Never commit**: API keys, tokens, secrets
2. **Use environment**: Store in `~/.clawdbot/credentials/`
3. **Rotate regularly**: Especially for CI/CD

### Agent Permissions

1. **Principle of least privilege**: Only grant needed tools
2. **Deny dangerous operations**: `rm -rf`, `git push --force`
3. **Audit hooks**: Log all agent actions

---

## Monitoring & Logging

### Log Locations

| Log | Location | Purpose |
|-----|----------|---------|
| Gateway logs | stdout/stderr | Service logs |
| Session logs | `~/.clawdbot/sessions/*.jsonl` | Conversation history |
| Agent logs | `~/.claude/session.log` | Claude Code sessions |
| tmux capture | `tmux capture-pane` | Terminal output |

### macOS Unified Logs

Using `scripts/clawlog.sh` from repo:

```bash
# Follow clawdbot logs
./scripts/clawlog.sh --follow

# Search for errors
./scripts/clawlog.sh --category error
```

---

## Troubleshooting

### Gateway Not Accessible

```bash
# Check if running
pgrep -f "clawdbot gateway"

# Check port binding
lsof -i :8080

# Check Tailscale
tailscale status
```

### tmux Session Issues

```bash
# List all sockets
ls -la ${TMPDIR}/clawdbot-tmux-sockets/

# Kill stuck session
tmux -S $SOCKET kill-session -t agent-dev

# Reset all
tmux -S $SOCKET kill-server
```

### k3s Pod Failures

```bash
# Check pod status
kubectl -n clawdbot get pods

# Get pod logs
kubectl -n clawdbot logs -l app=clawdbot-gateway

# Describe pod
kubectl -n clawdbot describe pod -l app=clawdbot-gateway
```

---

## Dedicated E2E Test Instance Setup

For real end-to-end testing against live clawdbot instances.

### Local E2E Instance (Mac mini)

Use the provided E2E script to run tests against a temporary gateway:

```bash
# Run all E2E tests on port 8081
./scripts/e2e-with-gateway.sh

# Run on custom port
./scripts/e2e-with-gateway.sh 8082

# Run specific test pattern
./scripts/e2e-with-gateway.sh 8081 "gateway"
```

The script:
1. Creates a temporary config directory
2. Starts a gateway on the specified port
3. Waits for gateway to be ready
4. Runs E2E tests against it
5. Cleans up gateway and config on exit

Manual setup (if needed):

```bash
# Start test gateway manually
CLAWDBOT_CONFIG_PATH=~/.clawdbot-test/clawdbot.json \
  pnpm clawdbot gateway --port 8081 &

# Run E2E tests against it
CLAWDBOT_GATEWAY_PORT=8081 pnpm test:e2e

# Cleanup
pkill -f "clawdbot gateway.*8081"
```

### k3s E2E Instance

Deploy a separate E2E gateway in the cluster (uses the same placeholder image as above):

```yaml
# k8s/clawdbot-e2e.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clawdbot-e2e
  namespace: clawdbot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clawdbot-e2e
  template:
    metadata:
      labels:
        app: clawdbot-e2e
    spec:
      containers:
        - name: gateway
          image: ghcr.io/anthropics/clawdbot:latest
          args: ["gateway", "--port", "8080"]
          ports:
            - containerPort: 8080
          resources:
            limits:
              memory: "512Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: clawdbot-e2e
  namespace: clawdbot
spec:
  selector:
    app: clawdbot-e2e
  ports:
    - port: 8080
```

### Parallel E2E Testing

Run multiple E2E suites in parallel using different ports:

```bash
# Terminal 1: Gateway tests
CLAWDBOT_GATEWAY_PORT=8081 pnpm test:e2e --grep "gateway"

# Terminal 2: Message flow tests
CLAWDBOT_GATEWAY_PORT=8082 pnpm test:e2e --grep "message"

# Terminal 3: Provider tests
CLAWDBOT_GATEWAY_PORT=8083 pnpm test:e2e --grep "provider"
```

### E2E Test Patterns (from upstream)

Key patterns from `test/gateway.multi.e2e.test.ts`:

```typescript
// Spawn gateway process
const gateway = spawn('pnpm', ['clawdbot', 'gateway', '--port', port], {
  env: { ...process.env, HOME: tempHome }
});

// Wait for ready
await waitForPort(port, 30000);

// Send test messages via WebSocket
const ws = new WebSocket(`ws://localhost:${port}`);
ws.send(JSON.stringify({ type: 'message', content: 'test' }));

// Verify response
const response = await waitForMessage(ws, 5000);
expect(response.type).toBe('response');
```

### Test Data Isolation

Each E2E test should use isolated data:

```bash
# Create isolated HOME for test
export TEST_HOME=$(mktemp -d)
export HOME=$TEST_HOME

# Test runs with isolated session storage
# Sessions go to $TEST_HOME/.clawdbot/sessions/

# Cleanup after test
rm -rf $TEST_HOME
```
