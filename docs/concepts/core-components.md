---
summary: "Internal component structure, key interfaces, and message flow"
read_when:
  - Understanding how the codebase is organized
  - Adding new channels, plugins, or agent features
  - Onboarding to the project
title: "Core Components"
---

# Core components

Last updated: 2026-02-15

## Overview

OpenClaw is a **multi-channel AI messaging gateway**. It connects to messaging
platforms (WhatsApp, Telegram, Discord, Slack, Signal, iMessage, etc.), routes
incoming messages to AI agents, and streams responses back. The architecture is
hub-and-spoke: the Gateway Server is the hub.

```
┌──────────────────────────────────────────────────────────────┐
│                      Gateway Server                          │
│             (HTTP + WebSocket, src/gateway/)                  │
│                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ Channel  │ │ Routing  │ │  Agent   │ │   Plugin     │   │
│  │ Manager  │ │ Engine   │ │  Runner  │ │   System     │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘   │
│       │             │            │               │           │
└───────┼─────────────┼────────────┼───────────────┼───────────┘
        │             │            │               │
   ┌────▼────┐   ┌────▼────┐ ┌────▼────┐    ┌─────▼─────┐
   │Channels │   │Bindings │ │  LLM    │    │Extensions │
   │(WA, TG, │   │& Routes │ │Providers│    │(msteams,  │
   │ DC, etc)│   │(config) │ │         │    │ matrix,..)│
   └─────────┘   └─────────┘ └─────────┘    └───────────┘
```

## Gateway Server

**Location:** `src/gateway/`

The central orchestration hub. `startGatewayServer()` in `server.impl.ts` boots
an HTTP + WebSocket server that ties all subsystems together.

Responsibilities:

- Host the WebSocket server for clients (native apps, web UI, CLI)
- Serve the HTTP API (OpenAI-compatible `/v1/chat/completions` and `/v1/responses`)
- Coordinate channel lifecycle (start/stop/reconnect)
- Handle auth, config reloading, mDNS discovery, and health checks

The gateway is not a monolithic class. It is **function-composed**: each
subsystem is a separate module (`server-channels.ts`, `server-chat.ts`,
`server-plugins.ts`, `server-cron.ts`, `server-discovery.ts`) wired together
during startup. `startGatewayServer` returns a minimal `{ close }` handle.

See also: [Gateway Architecture](/concepts/architecture) for protocol details.

## Channel system

**Location:** `src/channels/`, per-channel dirs (`src/whatsapp/`, `src/telegram/`, etc.)

Channels are **adapters** between messaging platforms and the gateway. Every
platform implements the `ChannelPlugin` interface
(`src/channels/plugins/types.plugin.ts`):

```typescript
type ChannelPlugin = {
  id: ChannelId;
  meta: ChannelMeta;
  capabilities: ChannelCapabilities;
  config: ChannelConfigAdapter; // How to read/resolve config
  gateway?: ChannelGatewayAdapter; // Lifecycle hooks (start/stop)
  outbound?: ChannelOutboundAdapter; // How to send messages out
  streaming?: ChannelStreamingAdapter; // Streaming reply support
  groups?: ChannelGroupAdapter; // Group chat support
  commands?: ChannelCommandAdapter; // Channel-specific commands
  security?: ChannelSecurityAdapter; // Allowlist enforcement
  pairing?: ChannelPairingAdapter; // Device pairing (QR, etc.)
  threading?: ChannelThreadingAdapter; // Thread support
  mentions?: ChannelMentionAdapter; // @mention handling
  agentPrompt?: ChannelAgentPromptAdapter; // Channel-specific prompt hints
  // ... more optional adapter slots
};
```

The design uses a **slot-based adapter pattern**. Each capability is an optional
slot, so a channel only implements what it supports. iMessage doesn't need
`pairing`; Discord has `groups` but not `pairing`.

Each channel also has a **`ChannelDock`** (`src/channels/dock.ts`) — a lighter
capability descriptor used by routing and UI layers without the full plugin:

```typescript
type ChannelDock = {
  id: ChannelId;
  capabilities: ChannelCapabilities;
  commands?: ChannelCommandAdapter;
  outbound?: { textChunkLimit?: number };
  streaming?: ChannelDockStreaming;
  // ...
};
```

The `ChannelManager` (`src/gateway/server-channels.ts`) manages lifecycle:
`startChannels()`, `startChannel(id)`, `stopChannel(id)`,
`getRuntimeSnapshot()`.

Built-in channels live in `src/whatsapp/`, `src/telegram/`, etc. Extension
channels live in `extensions/` as workspace packages.

## Routing engine

**Location:** `src/routing/`

Routing determines **which AI agent** handles a given incoming message. The core
function is `resolveAgentRoute()` in `resolve-route.ts`:

```typescript
type ResolveAgentRouteInput = {
  cfg: OpenClawConfig;
  channel: string;          // "telegram", "whatsapp", etc.
  accountId?: string;       // Which bot account received it
  peer?: RoutePeer;         // Who sent it (user/group/channel)
  parentPeer?: RoutePeer;   // Thread parent (binding inheritance)
  guildId?: string;         // Discord guild
  teamId?: string;          // Slack team
  memberRoleIds?: string[]; // Discord roles
}

type ResolvedAgentRoute = {
  agentId: string;          // Which agent handles this
  channel: string;
  accountId: string;
  sessionKey: string;       // Persistence key
  mainSessionKey: string;   // Collapsed key for DMs
  matchedBy: "binding.peer" | "binding.guild" | "default" | ...;
}
```

Routing works through **bindings** defined in user config. The matcher tries
increasingly broad patterns:

1. Exact peer match
2. Parent peer match (threads)
3. Guild + roles match
4. Guild-only match
5. Team match
6. Account match
7. Channel-wide match
8. Default agent

The `sessionKey` determines **conversation isolation**. Two messages from
different Discord channels might route to the same agent but get different
session keys, giving each conversation its own context. The `matchedBy` field is
a debugging breadcrumb for understanding routing decisions.

## Agent system

**Location:** `src/agents/`

The AI brain. The Pi embedded runner (`pi-embedded-runner.ts`) orchestrates LLM
calls with tool use, session management, and streaming.

Key modules:

| Module                  | Purpose                                                 |
| ----------------------- | ------------------------------------------------------- |
| `pi-embedded-runner.ts` | Main agent loop: messages to LLM, tool calls, streaming |
| `pi-tools.ts`           | Tool definitions (bash, read, write, search, etc.)      |
| `models-config.ts`      | Model provider resolution                               |
| `model-selection.ts`    | Dynamic model selection and fallback                    |
| `auth-profiles.ts`      | Auth profile rotation (API keys, OAuth)                 |
| `system-prompt.ts`      | System prompt construction                              |
| `skills.ts`             | Skill/prompt injection                                  |
| `compaction.ts`         | Context window management                               |
| `subagent-registry.ts`  | Sub-agent spawning and lifecycle                        |
| `sandbox.ts`            | Sandboxed code execution                                |
| `workspace.ts`          | Workspace (project directory) management                |

The agent uses an **embedded runner pattern**: the LLM interaction loop runs
in-process (send message, receive streaming response, execute tool calls
locally, feed results back, repeat). This enables tight integration with local
tools like file I/O, bash, and browser automation.

Agent events connect to the gateway via `createAgentEventHandler()` in
`server-chat.ts`, which translates agent events (text chunks, tool calls,
errors) into WebSocket broadcasts. The `pi-embedded-subscribe.ts` module handles
the streaming protocol, splitting LLM output into block-level chunks for
real-time display across UI surfaces.

## Plugin system

**Location:** `src/plugins/`

The extension mechanism. Everything registers through `OpenClawPluginApi`
(`src/plugins/types.ts`):

```typescript
type OpenClawPluginApi = {
  registerTool: (tool) => void; // Agent tools
  registerHook: (events, handler) => void; // Lifecycle hooks
  registerChannel: (reg) => void; // New messaging channels
  registerHttpHandler: (handler) => void; // HTTP endpoints
  registerGatewayMethod: (method, h) => void; // WS methods
  registerCli: (registrar) => void; // CLI commands
  registerService: (service) => void; // Background services
  registerProvider: (provider) => void; // LLM providers
  registerCommand: (command) => void; // Chat commands (bypass LLM)
  // ...
};
```

Plugins define themselves with `OpenClawPluginDefinition`:

```typescript
type OpenClawPluginDefinition = {
  id?: string;
  name?: string;
  description?: string;
  version?: string;
  kind?: PluginKind;
  configSchema?: OpenClawPluginConfigSchema;
  register?: (api: OpenClawPluginApi) => void | Promise<void>;
  activate?: (api: OpenClawPluginApi) => void | Promise<void>;
};
```

Lifecycle: `register()` (declarative setup) then `activate()` (side effects).

The hook system provides lifecycle events:

- `message.received` / `message.sending` / `message.sent`
- `agent.start` / `agent.end`
- `session.start` / `session.end`
- `gateway.start` / `gateway.stop`
- `tool.before` / `tool.after` / `tool.result.persist`
- `compaction.before` / `compaction.after`

## Config system

**Location:** `src/config/`

The single source of truth for user preferences. Uses **Zod schemas** for
validation. Covers:

- Agent settings (models, identity, tools, sandbox, skills)
- Channel settings per platform (tokens, allowlists, group policies)
- Routing bindings
- Gateway settings (ports, auth, TLS, HTTP endpoints)
- Hook definitions
- Plugin configuration

Channel-specific types live in separate files (`types.telegram.ts`,
`types.discord.ts`, etc.) while the master config type composes them. Supports
**hot-reloading** via `config-reload.ts`.

## Message flow (end-to-end)

What happens when someone sends "Hello" on Telegram:

```
1. Telegram ChannelPlugin receives webhook
       │
2. Channel normalizes message
       │  { channel: "telegram", peer, accountId, text: "Hello" }
       │
3. resolveAgentRoute()
       │  → { agentId: "default", sessionKey: "tg:dm:12345" }
       │
4. Gateway enqueues message for session
       │
5. Pi embedded runner loads session history + system prompt
       │
6. LLM API call (streaming) → response chunks
       │
7. createAgentEventHandler() broadcasts chunks via WebSocket
       │
8. Channel outbound adapter sends final reply to Telegram
```

## Summary

| Component | Location                          | Interface                      | Role                                |
| --------- | --------------------------------- | ------------------------------ | ----------------------------------- |
| Gateway   | `src/gateway/`                    | `startGatewayServer()`         | HTTP/WS server, orchestration hub   |
| Channels  | `src/channels/`, per-channel dirs | `ChannelPlugin`, `ChannelDock` | Platform adapters (in/out)          |
| Routing   | `src/routing/`                    | `resolveAgentRoute()`          | Message-to-agent mapping            |
| Agents    | `src/agents/`                     | Pi embedded runner             | LLM interaction, tool use, sessions |
| Plugins   | `src/plugins/`                    | `OpenClawPluginApi`            | Extension mechanism                 |
| Config    | `src/config/`                     | `OpenClawConfig` (Zod)         | User settings, hot-reloadable       |
