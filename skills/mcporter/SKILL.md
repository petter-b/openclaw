---
name: mcporter
description: >
  Explore and test MCP servers interactively before integrating them.
  Use when you need to understand available tools, test tool behavior,
  debug authentication, or call tools for one-off queries.
  Helpful for evaluating new MCP servers or verifying they work correctly.
homepage: http://mcporter.dev
argument-hint: "[server] [server.tool] or [url]"
metadata:
  {
    "openclaw":
      {
        "emoji": "📦",
        "requires": { "bins": ["mcporter"] },
        "install":
          [
            {
              "id": "brew",
              "kind": "brew",
              "package": "steipete/tap/mcporter",
              "bins": ["mcporter"],
              "label": "Install mcporter (Homebrew)",
            },
            {
              "id": "node",
              "kind": "node",
              "package": "mcporter",
              "bins": ["mcporter"],
              "label": "Install mcporter (npm)",
            },
          ],
      },
  }
---

# mcporter — MCP Server CLI

Discover, test, and call MCP (Model Context Protocol) servers directly from the command line.

## Purpose

mcporter lets you **call MCP tools without loading their full schemas** into agent context. Use it to:

- **Conserve agent context** - Make tool calls via CLI without integrating full MCP server documentation
- **Evaluate** a new MCP server (list tools, read schemas, understand capabilities)
- **Test** tool behavior before deciding to integrate or deploy
- **Debug** auth issues or server connectivity problems
- **Call** tools directly for one-off tasks without context overhead
- **Production automation** - CLI scripts, cron jobs, and workflows
- **Develop** custom MCP servers with stdio mode
- **Generate** CLI wrappers or TypeScript clients from servers

## For AI Agents: When to Use mcporter

### Use mcporter when:

- ✅ You need to **conserve context** - make tool calls without loading full MCP documentation into your context
- ✅ You're **evaluating a new MCP server** and need to understand its capabilities
- ✅ You need to **test a tool** before building on it or deploying
- ✅ You're **debugging authentication** issues with an MCP server
- ✅ You need to **make one-off tool calls** without context overhead
- ✅ You're **developing a custom MCP server** and want to test it locally
- ✅ You need to **inspect tool schemas** before deciding how to use them
- ✅ Building **production automation** (scripts, cron jobs, workflows)

### Don't use mcporter when:

- ❌ You're making **many repeated calls** in a single conversation (switch to integrated tools to reduce call overhead)
- ❌ You need **persistent state** across multiple tool calls (use integrated tools)
- ❌ The **MCP server is unavailable or unreachable** (won't help—verify connectivity first)

## Quick Start

```bash
# List all configured MCP servers
mcporter list

# Explore a specific server
mcporter list linear

# View tool schemas and documentation
mcporter list linear --schema

# Test a tool call
mcporter call linear.list_issues team=ENG limit:5

# Use JSON for machine-readable output
mcporter call linear.list_issues team=ENG limit:5 --output json
```

## Context Conservation Strategy

**Key insight**: Integrating an MCP server loads its full schema and documentation into your context, consuming tokens. mcporter lets you **call tools without that overhead**.

### Pattern: One-off tool call (context-lean)

```bash
# Make a single tool call without integrating the full MCP server
mcporter call upstash/context7.resolve-library-id query="React" libraryName="react" --output json

# Result is returned directly—no MCP schema loaded in your context
```

**Context cost**: ~100 tokens (just the CLI call)
**vs. Integrated MCP**: ~2000+ tokens (full server schema + documentation)

### Pattern: Repeated calls (integrate when worth it)

```bash
# First call via mcporter (lean)
mcporter call linear.list_issues team=ENG --output json

# If you need to make many more calls in this conversation,
# integrate the Linear MCP server to avoid repeated overhead
```

**When to integrate**:

- Making 3+ calls to the same server
- Need persistent schema context
- Building complex workflows

---

## Typical Agent Workflow

### 1. Evaluate a server (context-lean)

```bash
# What tools are available?
mcporter list upstash/context7

# Show detailed schemas
mcporter list upstash/context7 --schema
```

### 2. Test a tool (one-off call)

```bash
# Try a simple call without loading full MCP context
mcporter call upstash/context7.resolve-library-id query="React" libraryName="react" --output json
```

### 3. Decide next steps

- If successful: Use the result in your response
- If making many more calls: integrate the server formally (switch to full MCP)
- If failed: Debug auth, check connectivity, or try a different tool
- If useful: Document the tool for future reference

## Call Tools

### Selector syntax (recommended for most calls)

```bash
mcporter call linear.list_issues team=ENG limit:5
mcporter call upstash/context7.resolve-library-id query="React" libraryName="react"
```

### Function syntax (for complex arguments)

```bash
mcporter call "linear.create_issue(title: \"Bug\", team: \"ENG\")"
```

### Full HTTP URL (for ad-hoc servers)

```bash
mcporter call https://api.example.com/mcp.fetch url:https://example.com
```

### Stdio mode (for local/custom servers)

**Use when**: Testing a custom MCP server you're developing before deployment

```bash
mcporter call --stdio "bun run ./my-server.ts" myTool input=value
```

Useful for:

- Building and testing custom MCP servers locally
- Verifying server behavior before deploying to production
- Debugging server issues

### JSON payload (for complex arguments)

```bash
mcporter call linear.search --args '{"query":"label:bug","limit":10}'
```

### Machine-readable output

```bash
# Always use --output json for scripts and data processing
mcporter call upstash/context7.resolve-library-id query="Python" libraryName="python" --output json
```

## Authentication & Configuration

### OAuth for authenticated servers

```bash
# Authenticate before calling a tool
mcporter auth linear

# Reset authentication if needed
mcporter auth linear --reset

# Then call tools (auth tokens reused)
mcporter call linear.list_issues team=ENG limit:5
```

### Manage configuration

```bash
# View all configs
mcporter config list

# Add a new server config
mcporter config add <server> <config>

# Remove a server config
mcporter config remove <server>

# Import configs from editors (Cursor, Claude Code)
mcporter config import
```

**Config location**: `./config/mcporter.json` (override with `--config <path>`)

## Daemon & Connection Pooling

### Keep-alive daemon (for repeated calls)

```bash
# Start persistent daemon (reuses connections)
mcporter daemon start

# Check daemon status
mcporter daemon status

# Stop daemon
mcporter daemon stop

# Restart daemon
mcporter daemon restart
```

**When to use**: If you're making many repeated calls to the same server, start the daemon for performance.

## Code Generation

### Generate standalone CLI

```bash
# Create a CLI from a remote MCP server
mcporter generate-cli --command https://mcp.context7.com/mcp --compile ./context7-cli

# Or from a configured server
mcporter generate-cli --server linear --compile ./linear-cli

# Use the generated CLI
./context7-cli resolve-library-id query="React" libraryName="react"
```

### Inspect generated CLI

```bash
mcporter inspect-cli ./context7-cli
mcporter inspect-cli ./context7-cli --json
```

### Generate TypeScript client

```bash
# Generate type-safe TypeScript interfaces
mcporter emit-ts upstash/context7 --mode client

# Generate type definitions only
mcporter emit-ts upstash/context7 --mode types
```

## Error Handling & Debugging

### Tool call fails

```bash
# Step 1: Verify server is reachable
mcporter list linear

# Step 2: Check authentication if needed
mcporter config list
mcporter auth linear

# Step 3: Re-test the call
mcporter call linear.list_issues team=ENG limit:5 --output json
```

### Server not found

```bash
# List all available servers
mcporter list

# Import configs from editors if needed
mcporter config import
```

### Authentication issues

```bash
# Reset authentication
mcporter auth linear --reset

# Verify config
mcporter config get linear
```

## Security Considerations

### ⚠️ Token & Credential Management

- **Tokens stored in** `./config/mcporter.json` are **not encrypted**
- **Don't commit** `./config/` to version control—add to `.gitignore`
- **Auth tokens are sensitive**—treat like passwords
- **Rotate tokens** after testing if they were created for temporary use
- **Never pass credentials** as command arguments; use environment variables or auth commands instead

### ⚠️ Remote Server Safety

When calling HTTP endpoints with `mcporter call https://...`:

- ✅ Only call **trusted endpoints** you control or have verified
- ✅ Verify the **URL is correct** before sending data
- ❌ Don't send **sensitive data** (passwords, API keys) to untrusted servers
- ❌ Don't expose **internal URLs** publicly

### ⚠️ Rate Limiting

- Some MCP servers have **rate limits**—check their documentation
- If rate limited, **add delays** between calls or use the daemon for better throughput
- Monitor **API usage** if tools are called frequently

## Best Practices for Agents

**🎯 Default Strategy: Always use mcporter first**

Your agents should **default to mcporter** for all tool calls to conserve context tokens. Only integrate a full MCP server if you need to make many repeated calls in a single conversation.

1. **Default: One-off call via mcporter (context-lean)**

   ```bash
   # Most agent workflows should use this pattern
   mcporter call upstash/context7.resolve-library-id query="React" libraryName="react" --output json
   # ~100 tokens context cost
   ```

2. **Exception: Many repeated calls (integrate if necessary)**

   ```bash
   # Only after 3+ calls to the same server, consider integrating
   # This loads the full MCP server (~2000+ tokens)
   # But makes subsequent calls cheaper
   ```

3. **Always start with schema inspection**

   ```bash
   mcporter list <server> --schema
   ```

   Understand what parameters and outputs to expect.

4. **Use `--output json` for processing**

   ```bash
   mcporter call <server.tool> params... --output json
   ```

   JSON is easier for agents to parse and handle errors.

5. **Handle errors gracefully**
   - If a call fails, print the error and explain what went wrong
   - Don't crash—suggest alternatives or next steps
   - Log the command for debugging

6. **Cache results when appropriate**
   - If you call the same tool multiple times, cache the results
   - Reduces API usage and improves performance

7. **Conserve context aggressively**
   - Prefer mcporter (CLI calls) over integrating full MCP servers
   - Each integrated MCP server costs 2000+ context tokens
   - Use those tokens for the actual work instead

## Configuration Notes

- **Default config location**: `./config/mcporter.json`
- **Override config path**: `mcporter <command> --config /path/to/config.json`
- **Editor integration**: mcporter auto-discovers configs from Cursor, Claude Code
- **Import editor configs**: `mcporter config import`

## Examples

### Explore context7 (documentation service)

```bash
# What does context7 provide?
mcporter list upstash/context7

# Test resolving a library
mcporter call upstash/context7.resolve-library-id \
  query="JWT authentication" \
  libraryName="express" \
  --output json

# Query documentation
mcporter call upstash/context7.query-docs \
  libraryId="/expressjs/express" \
  query="middleware authentication" \
  --output json
```

### Explore Linear API

```bash
# List available tools
mcporter list linear

# See all tools with schemas
mcporter list linear --schema

# List issues (requires auth)
mcporter auth linear
mcporter call linear.list_issues team=ENG limit:5 --output json

# Create an issue
mcporter call "linear.create_issue(title: \"New feature\", team: \"ENG\")"
```

### Test a custom server before deployment

```bash
# Test locally with stdio
mcporter call --stdio "bun run ./my-server.ts" \
  myFunction \
  input="test data"

# If successful, deploy to production
# Then update config to use HTTP endpoint
```

### Generate a CLI wrapper for reuse

```bash
# Create a standalone context7 CLI
mcporter generate-cli --command https://mcp.context7.com/mcp --compile ./context7

# Now use it directly
./context7 resolve-library-id query="React" libraryName="react"
```

## Installed mcporter Version & Location

- **Version**: 0.7.3
- **Location**: `/opt/homebrew/bin/mcporter` (Homebrew)
- **Verify**: `which mcporter && mcporter --version`

## Related Skills

- **netatmo**: Control Netatmo smart home devices
- **context7**: Documentation search & code examples (available as MCP server)
