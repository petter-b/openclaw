import "./monitor-inbox.test-harness.js";
import { describe, expect, it, vi } from "vitest";
import { monitorWebInbox } from "./inbound.js";
import {
  DEFAULT_ACCOUNT_ID,
  getAuthDir,
  getSock,
  installWebMonitorInboxUnitTestHooks,
} from "./monitor-inbox.test-harness.js";

describe("web monitor inbox error reply on unrecoverable handler failure", () => {
  installWebMonitorInboxUnitTestHooks();

  it("sends error reply to user when handler throws", async () => {
    const onMessage = vi.fn().mockRejectedValue(new Error("session write failed"));

    const listener = await monitorWebInbox({
      verbose: false,
      onMessage,
      accountId: DEFAULT_ACCOUNT_ID,
      authDir: getAuthDir(),
    });
    const sock = getSock();
    const upsert = {
      type: "notify",
      messages: [
        {
          key: { id: "err1", fromMe: false, remoteJid: "999@s.whatsapp.net" },
          message: { conversation: "hello" },
          messageTimestamp: 1_700_000_000,
          pushName: "Tester",
        },
      ],
    };

    sock.ev.emit("messages.upsert", upsert);
    await new Promise((resolve) => setImmediate(resolve));

    expect(onMessage).toHaveBeenCalled();
    expect(sock.sendMessage).toHaveBeenCalledWith("999@s.whatsapp.net", {
      text: expect.stringContaining("Something went wrong"),
    });

    await listener.close();
  });

  it("error reply is best-effort (swallows reply failure)", async () => {
    const onMessage = vi.fn().mockRejectedValue(new Error("session write failed"));

    const listener = await monitorWebInbox({
      verbose: false,
      onMessage,
      accountId: DEFAULT_ACCOUNT_ID,
      authDir: getAuthDir(),
    });
    const sock = getSock();
    // Make the reply attempt also fail
    sock.sendMessage.mockRejectedValueOnce(new Error("socket broken"));

    const upsert = {
      type: "notify",
      messages: [
        {
          key: { id: "err2", fromMe: false, remoteJid: "999@s.whatsapp.net" },
          message: { conversation: "hello" },
          messageTimestamp: 1_700_000_001,
          pushName: "Tester",
        },
      ],
    };

    // Should not throw even when error reply fails
    sock.ev.emit("messages.upsert", upsert);
    await new Promise((resolve) => setImmediate(resolve));

    expect(onMessage).toHaveBeenCalled();

    await listener.close();
  });
});
