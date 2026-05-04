import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

const API_BASE = process.env.PI_CORTEX_API_BASE ?? "http://127.0.0.1:3002";
const API_KEY  = process.env.PI_CORTEX_AGENT_KEY  ?? "";

// Accumulated lessons to flush on session_before_compact
const pendingLessons: Array<{ content: string; category?: string; tags?: string[] }> = [];

export default function (pi: ExtensionAPI) {

  // ── Tools ──────────────────────────────────────────────────────────

  pi.registerTool("memory_search", {
    description: "Search the knowledge graph by keyword",
    parameters: Type.Object({
      q:     Type.String({ description: "Search query" }),
      top_k: Type.Optional(Type.Number({ description: "Max results (default 5)" })),
    }),
    execute: async ({ q, top_k = 5 }) => {
      // TODO: GET /api/search?q=...&top_k=...&budget_tokens=1500
      throw new Error("memory_search: not implemented");
    },
  });

  pi.registerTool("memory_search_routed", {
    description: "Routed search with category detection and token budget",
    parameters: Type.Object({
      q:             Type.String({ description: "Search query" }),
      budget_tokens: Type.Optional(Type.Number({ description: "Token budget (default 1500)" })),
      level:         Type.Optional(Type.String({ description: "compact | full (default compact)" })),
    }),
    execute: async ({ q, budget_tokens = 1500, level = "compact" }) => {
      // TODO: GET /api/search with routing params — detect category, adjust weights
      throw new Error("memory_search_routed: not implemented");
    },
  });

  pi.registerTool("memory_get", {
    description: "Retrieve a complete knowledge node by ID",
    parameters: Type.Object({ id: Type.String({ description: "Knowledge node ID" }) }),
    execute: async ({ id }) => {
      // TODO: GET /api/knowledge/:id
      throw new Error("memory_get: not implemented");
    },
  });

  pi.registerTool("memory_record_lesson", {
    description: "Record a lesson learned during this session",
    parameters: Type.Object({
      content:  Type.String({ description: "Lesson text" }),
      category: Type.Optional(Type.String({ description: "One of: infra, code, sec, data, devops, api, ai, general, meta" })),
      tags:     Type.Optional(Type.Array(Type.String())),
    }),
    execute: async ({ content, category, tags }) => {
      // Accumulate locally; flushed in session_before_compact
      pendingLessons.push({ content, category, tags });
      return { queued: true, pending: pendingLessons.length };
    },
  });

  pi.registerTool("memory_get_graph", {
    description: "Explore the knowledge graph neighborhood of a node",
    parameters: Type.Object({
      id:    Type.String({ description: "Start node ID" }),
      depth: Type.Optional(Type.Number({ description: "Traversal depth (default 2)" })),
    }),
    execute: async ({ id, depth = 2 }) => {
      // TODO: GET /api/graph/:id?depth=...
      throw new Error("memory_get_graph: not implemented");
    },
  });

  pi.registerTool("memory_status", {
    description: "Get memory system health, node count, and top weights",
    parameters: Type.Object({}),
    execute: async () => {
      // TODO: GET /api/health + GET /api/stats
      throw new Error("memory_status: not implemented");
    },
  });

  pi.registerTool("memory_feedback", {
    description: "Give positive or negative feedback on a knowledge node (adjusts ACO weight)",
    parameters: Type.Object({
      id:       Type.String({ description: "Knowledge node ID" }),
      positive: Type.Boolean({ description: "true = reinforce, false = decay" }),
      note:     Type.Optional(Type.String()),
    }),
    execute: async ({ id, positive, note }) => {
      // TODO: POST /api/reinforce  { id, positive, note }
      throw new Error("memory_feedback: not implemented");
    },
  });

  // ── Hooks ──────────────────────────────────────────────────────────

  // Inject relevant memory into system prompt before each agent turn
  // Pattern from PLAN-OPUS.md §6.3 — hard cap 1500 tokens, 800ms timeout
  pi.on("context", async (event, _ctx) => {
    // TODO: implement memory injection
    // 1. Extract last user message: lastUserMessage(event.messages)
    // 2. Fetch: GET /api/search?q=...&budget_tokens=1500&level=compact&top_k=5
    //    with AbortSignal.timeout(800) and Authorization header
    // 3. On success: prepend formatted block to system message
    // 4. On timeout or error: silently return (no throw)
  });

  // Block dangerous tool calls before execution
  // Pattern from reference/extensions/security-guard.ts
  pi.on("tool_call", (event, _ctx) => {
    // TODO: implement guardrails
    // Check event.tool.input (bash commands, file paths) for:
    //   "0.0.0.0", "--no-verify", "rm -rf /", "ufw delete", "chmod 777"
    // Return { block: true, reason: "Security guardrail: <pattern>" } to block
    // Return nothing (undefined) to allow
  });

  // After each agent turn: detect errors, suggest recording lessons
  pi.on("agent_end", (_event, _ctx) => {
    // TODO: scan last assistant message for error patterns
    // If "Error:", "FAIL", "failed" found: suggest memory_record_lesson
  });

  // Before session compaction: flush accumulated lessons to API
  // Must complete before returning — Pi waits for this hook
  pi.on("session_before_compact", async (_event, _ctx) => {
    if (pendingLessons.length === 0) return;
    const toFlush = [...pendingLessons];
    pendingLessons.length = 0;
    for (const lesson of toFlush) {
      try {
        await fetch(`${API_BASE}/api/lesson`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-API-Key": API_KEY },
          body: JSON.stringify(lesson),
        });
      } catch {
        // Log but do NOT block compaction on API failure
      }
    }
  });
}
