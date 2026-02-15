import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("./message-handler.process.js", () => ({
  processDiscordMessage: vi.fn().mockRejectedValue(new Error("session write failed")),
}));

vi.mock("./message-handler.preflight.js", () => ({
  preflightDiscordMessage: vi.fn().mockResolvedValue({
    channelId: "ch123",
    message: { channelId: "ch123" },
  }),
}));

import { createDiscordMessageHandler } from "./message-handler.js";

describe("discord message-handler error reply on unrecoverable handler failure", () => {
  let mockFetch: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("sends error reply to channel when handler throws", async () => {
    const mockRuntime = { error: vi.fn(), log: vi.fn() };

    const handler = createDiscordMessageHandler({
      // oxlint-disable-next-line typescript/no-explicit-any
      cfg: { messages: {} } as any,
      // oxlint-disable-next-line typescript/no-explicit-any
      discordConfig: {} as any,
      accountId: "default",
      token: "test-bot-token",
      // oxlint-disable-next-line typescript/no-explicit-any
      runtime: mockRuntime as any,
      guildHistories: new Map(),
      historyLimit: 0,
      mediaMaxBytes: 1024,
      textLimit: 4000,
      replyToMode: "off",
      dmEnabled: true,
      groupDmEnabled: false,
    });

    await handler(
      {
        message: { channelId: "ch123", id: "m1", content: "hello" },
        author: { id: "user1" },
        // oxlint-disable-next-line typescript/no-explicit-any
      } as any,
      // oxlint-disable-next-line typescript/no-explicit-any
      {} as any,
    );

    expect(mockRuntime.error).toHaveBeenCalled();
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("channels/ch123/messages"),
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bot test-bot-token",
        }),
      }),
    );
  });

  it("error reply is best-effort (swallows fetch failure)", async () => {
    mockFetch.mockRejectedValue(new Error("network failure"));
    const mockRuntime = { error: vi.fn(), log: vi.fn() };

    const handler = createDiscordMessageHandler({
      // oxlint-disable-next-line typescript/no-explicit-any
      cfg: { messages: {} } as any,
      // oxlint-disable-next-line typescript/no-explicit-any
      discordConfig: {} as any,
      accountId: "default",
      token: "test-bot-token",
      // oxlint-disable-next-line typescript/no-explicit-any
      runtime: mockRuntime as any,
      guildHistories: new Map(),
      historyLimit: 0,
      mediaMaxBytes: 1024,
      textLimit: 4000,
      replyToMode: "off",
      dmEnabled: true,
      groupDmEnabled: false,
    });

    // Should not throw even if error reply fails
    await handler(
      {
        message: { channelId: "ch123", id: "m1", content: "hello" },
        author: { id: "user1" },
        // oxlint-disable-next-line typescript/no-explicit-any
      } as any,
      // oxlint-disable-next-line typescript/no-explicit-any
      {} as any,
    );

    expect(mockRuntime.error).toHaveBeenCalled();
  });
});
