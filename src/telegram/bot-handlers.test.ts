import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { registerTelegramHandlers } from "./bot-handlers.js";

describe("telegram bot-handlers error reply on unrecoverable handler failure", () => {
  // oxlint-disable-next-line typescript/no-explicit-any
  let handlers: Array<{ event: string; handler: (...args: any[]) => Promise<void> }>;
  // oxlint-disable-next-line typescript/no-explicit-any
  let mockBot: any;
  // oxlint-disable-next-line typescript/no-explicit-any
  let mockRuntime: any;

  beforeEach(() => {
    handlers = [];
    mockBot = {
      // oxlint-disable-next-line typescript/no-explicit-any
      on: vi.fn((event: string, handler: any) => {
        handlers.push({ event, handler });
      }),
      api: {
        sendMessage: vi.fn().mockResolvedValue(undefined),
        answerCallbackQuery: vi.fn().mockResolvedValue(undefined),
        editMessageText: vi.fn().mockResolvedValue(undefined),
        deleteMessage: vi.fn().mockResolvedValue(undefined),
      },
    };
    mockRuntime = {
      error: vi.fn(),
      log: vi.fn(),
    };
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // oxlint-disable-next-line typescript/no-explicit-any
  function createBaseParams(overrides: Record<string, any> = {}) {
    return {
      cfg: { messages: {} },
      accountId: "default",
      bot: mockBot,
      opts: {},
      runtime: mockRuntime,
      mediaMaxBytes: 1024,
      telegramCfg: {},
      groupAllowFrom: [],
      // oxlint-disable-next-line typescript/no-explicit-any
      resolveGroupPolicy: () => ({ allowlistEnabled: false, allowed: true }) as any,
      resolveTelegramGroupConfig: () => ({
        groupConfig: undefined,
        topicConfig: undefined,
      }),
      shouldSkipUpdate: () => false,
      processMessage: vi.fn().mockResolvedValue(undefined),
      logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), child: vi.fn() },
      ...overrides,
      // oxlint-disable-next-line typescript/no-explicit-any
    } as any;
  }

  function findHandler(event: string) {
    return handlers.find((h) => h.event === event)?.handler;
  }

  describe("message handler", () => {
    it("sends error reply to user when handler throws", async () => {
      registerTelegramHandlers(
        createBaseParams({
          shouldSkipUpdate: () => {
            throw new Error("ENOSPC: no space left on device");
          },
        }),
      );

      const handler = findHandler("message");
      expect(handler).toBeDefined();

      const reply = vi.fn().mockResolvedValue(undefined);
      await handler!({
        message: { chat: { id: 123, type: "private" }, message_id: 1 },
        me: { username: "bot" },
        reply,
      });

      expect(mockRuntime.error).toHaveBeenCalled();
      expect(reply).toHaveBeenCalledWith(expect.stringContaining("Something went wrong"));
    });

    it("error reply is best-effort (swallows reply failure)", async () => {
      registerTelegramHandlers(
        createBaseParams({
          shouldSkipUpdate: () => {
            throw new Error("ENOSPC");
          },
        }),
      );

      const handler = findHandler("message");
      const reply = vi.fn().mockRejectedValue(new Error("reply also failed"));
      await handler!({
        message: { chat: { id: 123, type: "private" }, message_id: 1 },
        me: { username: "bot" },
        reply,
      });

      // Handler should not throw even when error reply fails
      expect(mockRuntime.error).toHaveBeenCalled();
      expect(reply).toHaveBeenCalled();
    });
  });

  describe("callback handler", () => {
    it("sends error reply to user when handler throws", async () => {
      registerTelegramHandlers(
        createBaseParams({
          shouldSkipUpdate: () => {
            throw new Error("ENOSPC: no space left on device");
          },
        }),
      );

      const handler = findHandler("callback_query");
      expect(handler).toBeDefined();

      const reply = vi.fn().mockResolvedValue(undefined);
      // After fix, guards are inside try — handler must not throw
      await handler!({
        callbackQuery: {
          id: "cb1",
          from: { id: 1 },
          data: "test",
          message: { chat: { id: 456, type: "private" } },
        },
        me: { username: "bot" },
        reply,
      });

      expect(reply).toHaveBeenCalledWith(expect.stringContaining("Something went wrong"));
    });
  });

  describe("ENOSPC detection", () => {
    it("sends disk-full-specific message for ENOSPC errors", async () => {
      const enospcError = new Error("ENOSPC: no space left on device") as NodeJS.ErrnoException;
      enospcError.code = "ENOSPC";

      registerTelegramHandlers(
        createBaseParams({
          shouldSkipUpdate: () => {
            throw enospcError;
          },
        }),
      );

      const handler = findHandler("message");
      const reply = vi.fn().mockResolvedValue(undefined);
      await handler!({
        message: { chat: { id: 123, type: "private" }, message_id: 1 },
        me: { username: "bot" },
        reply,
      });

      expect(reply).toHaveBeenCalledWith(expect.stringContaining("Disk full"));
    });
  });
});
