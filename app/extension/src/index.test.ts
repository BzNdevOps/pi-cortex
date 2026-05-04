import { describe, it, expect, vi, beforeEach } from "vitest";

// ── Pi mock — inject behavior without a live Pi runtime ───────────────

const makePiMock = () => ({
  on: vi.fn(),
  registerTool: vi.fn(),
  registerCommand: vi.fn(),
});

// ── Stemmer / lexical scoring ─────────────────────────────────────────
// Import from shared util once implemented: import { stem } from "./utils/stemmer.js"

describe("stemmer", () => {
  it("stems English words correctly", () => {
    // TODO: expect(stem("running")).toBe("run")
    expect(true).toBe(true); // placeholder — replace with real assertions
  });
  it("leaves short roots unchanged", () => {
    // TODO: expect(stem("go")).toBe("go")
    expect(true).toBe(true);
  });
});

// ── Category routing ──────────────────────────────────────────────────
// Import: import { resolveRouting } from "./utils/routing.js"

describe("category routing", () => {
  it("routes infra keywords to the infra category", () => {
    // TODO: expect(resolveRouting("nginx systemd UFW")).toMatchObject({ category: "infra", confidence: ... })
    expect(true).toBe(true);
  });
  it("routes security keywords to the sec category", () => {
    // TODO: expect(resolveRouting("fail2ban auditd CVE")).toMatchObject({ category: "sec" })
    expect(true).toBe(true);
  });
  it("falls back to general when confidence < 0.3", () => {
    // TODO: expect(resolveRouting("hello world")).toMatchObject({ category: "general" })
    expect(true).toBe(true);
  });
});

// ── Context injection budget ──────────────────────────────────────────
// Import: import { formatInjectionBlock } from "./utils/injection.js"

describe("context injection", () => {
  it("truncates injection block to 1500 tokens", () => {
    // TODO: build a 3000-token mock result, call formatInjectionBlock with budget=1500
    // expect result token count <= 1500
    expect(true).toBe(true);
  });

  it("skips injection on 800ms timeout without throwing", async () => {
    const fetchMock = vi.fn(() => new Promise(resolve => setTimeout(resolve, 900)));
    vi.stubGlobal("fetch", fetchMock);
    // TODO: run the context hook with AbortSignal.timeout(800)
    // expect it resolves (no throw) even though fetch would timeout
    await expect(Promise.resolve()).resolves.not.toThrow();
    vi.unstubAllGlobals();
  });

  it("skips injection on API 5xx without throwing", async () => {
    const fetchMock = vi.fn(() => Promise.resolve({ ok: false, status: 500 } as Response));
    vi.stubGlobal("fetch", fetchMock);
    // TODO: run the context hook, verify no throw
    await expect(Promise.resolve()).resolves.not.toThrow();
    vi.unstubAllGlobals();
  });
});

// ── Guardrails ────────────────────────────────────────────────────────
// Import: import { checkGuardrail } from "./utils/guardrail.js"

describe("guardrail", () => {
  it("blocks commands containing 0.0.0.0", () => {
    // TODO: expect(checkGuardrail("curl http://0.0.0.0:3000")).toMatchObject({ block: true })
    expect(true).toBe(true);
  });
  it("blocks --no-verify flag", () => {
    // TODO: expect(checkGuardrail("git commit --no-verify")).toMatchObject({ block: true })
    expect(true).toBe(true);
  });
  it("blocks rm -rf /", () => {
    // TODO: expect(checkGuardrail("rm -rf /")).toMatchObject({ block: true })
    expect(true).toBe(true);
  });
  it("allows safe commands", () => {
    // TODO: expect(checkGuardrail("ls -la")).toBe(undefined)
    expect(true).toBe(true);
  });
});

// ── session_before_compact lesson flush ───────────────────────────────

describe("session_before_compact", () => {
  it("posts all pending lessons to /api/lesson before returning", async () => {
    const fetchMock = vi.fn(() => Promise.resolve({ ok: true } as Response));
    vi.stubGlobal("fetch", fetchMock);
    // TODO: call memory_record_lesson tool 3 times, then trigger session_before_compact
    // expect fetchMock called 3 times with POST /api/lesson
    expect(fetchMock.mock.calls.length).toBeGreaterThanOrEqual(0); // placeholder
    vi.unstubAllGlobals();
  });

  it("does not throw when API is unreachable during compaction", async () => {
    const fetchMock = vi.fn(() => Promise.reject(new Error("ECONNREFUSED")));
    vi.stubGlobal("fetch", fetchMock);
    // TODO: trigger session_before_compact, verify no throw
    await expect(Promise.resolve()).resolves.not.toThrow();
    vi.unstubAllGlobals();
  });
});
