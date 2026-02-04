# E2E Test Patterns Reference

> Source of truth: `test/gateway.multi.e2e.test.ts`

## Pattern 1: Ephemeral Port Allocation

```typescript
const getFreePort = async () => {
  const srv = net.createServer();
  await new Promise<void>((resolve) => srv.listen(0, "127.0.0.1", resolve));
  const addr = srv.address();
  if (!addr || typeof addr === "string") {
    srv.close();
    throw new Error("failed to bind ephemeral port");
  }
  await new Promise<void>((resolve) => srv.close(() => resolve()));
  return addr.port;
};
```

## Pattern 2: Port Readiness with Error Capture

```typescript
const waitForPortOpen = async (
  proc: ChildProcessWithoutNullStreams,
  chunksOut: string[],
  chunksErr: string[],
  port: number,
  timeoutMs: number,
) => {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (proc.exitCode !== null) {
      const stdout = chunksOut.join("");
      const stderr = chunksErr.join("");
      throw new Error(
        `gateway exited before listening (code=${String(proc.exitCode)})\n` +
          `--- stdout ---\n${stdout}\n--- stderr ---\n${stderr}`,
      );
    }
    try {
      await new Promise<void>((resolve, reject) => {
        const socket = net.connect({ host: "127.0.0.1", port });
        socket.once("connect", () => { socket.destroy(); resolve(); });
        socket.once("error", reject);
      });
      return;
    } catch {
      await sleep(25);
    }
  }
  throw new Error(`timeout waiting for port ${port}`);
};
```

## Pattern 3: Process Spawning with Isolation

```typescript
const spawnGatewayInstance = async (name: string): Promise<GatewayInstance> => {
  const port = await getFreePort();

  // Create isolated HOME directory
  const homeDir = await fs.mkdtemp(
    path.join(os.tmpdir(), `openclaw-e2e-${name}-`),
  );

  // Create config in isolated HOME
  const configDir = path.join(homeDir, ".openclaw");
  await fs.mkdir(configDir, { recursive: true });

  // Spawn with isolated environment
  const child = spawn("bun", ["src/index.ts", "gateway", "--port", String(port)], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      HOME: homeDir,
      // See env-vars.md for full list
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  // Capture stdout/stderr for debugging
  const stdout: string[] = [];
  const stderr: string[] = [];
  child.stdout?.on("data", (d) => stdout.push(String(d)));
  child.stderr?.on("data", (d) => stderr.push(String(d)));

  await waitForPortOpen(child, stdout, stderr, port, GATEWAY_START_TIMEOUT_MS);
  return { name, port, homeDir, child, stdout, stderr };
};
```

## Pattern 4: Graceful Cleanup

```typescript
const stopGatewayInstance = async (inst: GatewayInstance) => {
  // Try SIGTERM first
  if (inst.child.exitCode === null && !inst.child.killed) {
    inst.child.kill("SIGTERM");
  }

  // Wait for graceful exit
  const exited = await Promise.race([
    new Promise<boolean>((resolve) => {
      if (inst.child.exitCode !== null) return resolve(true);
      inst.child.once("exit", () => resolve(true));
    }),
    sleep(5_000).then(() => false),
  ]);

  // Force kill if needed
  if (!exited && inst.child.exitCode === null) {
    inst.child.kill("SIGKILL");
  }

  // Clean up temp directory
  await fs.rm(inst.homeDir, { recursive: true, force: true });
};

// Register cleanup in afterAll
describe("e2e tests", () => {
  const instances: GatewayInstance[] = [];

  afterAll(async () => {
    for (const inst of instances) {
      await stopGatewayInstance(inst);
    }
  });
});
```

## Pattern 5: CLI JSON Output Testing

```typescript
const runCliJson = async (args: string[], env: NodeJS.ProcessEnv): Promise<unknown> => {
  const stdout: string[] = [];
  const stderr: string[] = [];

  const child = spawn("bun", ["src/index.ts", ...args], {
    cwd: process.cwd(),
    env: { ...process.env, ...env },
    stdio: ["ignore", "pipe", "pipe"],
  });

  child.stdout?.on("data", (d) => stdout.push(String(d)));
  child.stderr?.on("data", (d) => stderr.push(String(d)));

  const result = await new Promise((resolve) =>
    child.once("exit", (code, signal) => resolve({ code, signal })),
  );

  if (result.code !== 0) {
    throw new Error(`cli failed: ${stderr.join("")}`);
  }

  return JSON.parse(stdout.join("").trim());
};

// Usage
const health = await runCliJson(
  ["health", "--json", "--timeout", "10000"],
  { OPENCLAW_GATEWAY_PORT: String(port) }
);
expect(health.ok).toBe(true);
```

## Debugging Tips

### Capture Output
```typescript
// On failure, log captured output
console.log("stdout:", stdout.join(""));
console.log("stderr:", stderr.join(""));
```

### Increase Timeout
```typescript
it("slow test", { timeout: 300_000 }, async () => {
  // 5 minute timeout
});
```

### Keep Instance Running
Comment out cleanup in `afterAll` to inspect state after test failure.
