# Pi Extension Blueprint — pi-cortex Implementation Guide

> **Suggested filename for this doc:** `PiExt-Blueprint.md`  
> **Scope:** Everything needed to write the pi-cortex Pi extension in one coding session.  
> **Last updated:** 2026-05-03

---

## 📦 Extension Dependencies — Code We Actually Copy

These existing extensions contain **production-tested patterns** that map 1:1 to pi-cortex requirements. Not "inspiration" — literal blocks of code to adapt.

### 1. `memory-cycle.ts` (agent-pi package) — PRIMARY ARCHITECTURE

**Path:** `~/.pi/git/github.com/ruizrica/agent-pi/extensions/memory-cycle.ts` (~420 lines)
**What to copy:** The entire extension skeleton.

| Your need (`PLAN.md` §6) | How it's already solved here |
|--------------------------|------------------------------|
| `session_start` hook | `readSessionState()` + `readRecentLogs()` 융합 |
| `before_agent_start` hook | `pi.on("context", ...)` with `buildCycleMemoryInjection()` |
| `session_shutdown` hook | `writeSessionState()` + `writeDailyLog()` 융합 |
| Tool registration with complex workflow | `cycle_memory` tool structure (params, execute, render) |
| Command registration | `/cycle` command with handler pattern |
| TUI rendering of tool calls | `renderCompactionCard()` — theme-aware text rendering |
| Pre-LLM content injection | The core mechanic of this entire extension |

**Exact copy pattern:**
```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text } from "@mariozechner/pi-tui";

export default function (pi: ExtensionAPI) {
  // -- HOOKS (top of file) --
  pi.on("session_start", async (_event, ctx) => {
    // Load weights.json, ping Neo4j health
  });

  pi.on("context", async (event, ctx) => {
    // BEFORE every LLM call: inject memory block
    // Same hook pattern as memory-cycle.ts buildCycleMemoryInjection()
  });

  // -- TOOLS (middle) --
  pi.registerTool({
    name: "memory_search",
    label: "Memory Search",
    parameters: Type.Object({ q: Type.String(), ... }),
    async execute(...) {
      // fetch() to http://127.0.0.1:3002/api/search
    },
    renderCall(args, theme) { return new Text(theme.fg("accent", "..."), 0, 0); }
  });

  // -- COMMANDS (bottom) --
  pi.registerCommand("mem-status", {
    description: "Show memory graph health",
    handler: async (args, ctx) => { ... }
  });
}
```

---

### 2. `examples/extensions/todo.ts` (Official Pi SDK) — STATE RECOVERY

**Path:** `~/.local/lib/node_modules/@mariozechner/pi-coding-agent/examples/extensions/todo.ts` (~200 lines)
**What to copy:** The `reconstructState()` pattern — **this is the ONLY way to survive Pi restarts**.

**Critical block to adapt verbatim:**
```typescript
// From todo.ts — canonical session state reconstruction
const reconstructState = (ctx: ExtensionContext) => {
  // Scan ENTIRE session branch history for previous tool results
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role !== "toolResult" || msg.toolName !== "memory_record_lesson") continue;

    const details = msg.details as MemoryState | undefined;
    if (details) {
      // Restore ACO weights, last_used timestamps, etc.
      memoryState = details;
    }
  }
};

// Called on EVERY session event that could wipe state
pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));
```

**Why this matters:** If Pi crashes or restarts, all in-memory variables are gone. The tool result `details` survive in the session file. This loop rebuilds your state from history.

---

### 3. `security-guard.ts` (agent-pi) — TOOL_CALL GATE

**Path:** `~/.pi/git/github.com/ruizrica/agent-pi/extensions/security-guard.ts` (~720 lines)  
**What to copy:** The `pi.on("tool_call")` hook structure (first 100 lines are enough).

**Your adaptation:**
```typescript
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName === "bash") {
    const cmd = event.input.command as string;
    const blocked = [
      /rm\s+-rf\s+\//,
      /curl.*\|.*bash/,
      /mkfs/,
      /dd\s+if=/,
    ];
    for (const pattern of blocked) {
      if (pattern.test(cmd)) {
        return { 
          block: true, 
          reason: "Guardrail: destructive command blocked (pi-cortex security policy)" 
        };
      }
    }
  }
  // Return undefined = allow
});
```

**Why:** PLAN.md §6 requires guardrails. This hook pattern is the exact mechanism.

---

### 4. `examples/extensions/custom-compaction.ts` (Official SDK) — PERSISTENCE HOOK

**Path:** `~/.local/lib/node_modules/@mariozechner/pi-coding-agent/examples/extensions/custom-compaction.ts` (~100 lines)  
**What to copy:** The `session_before_compact` hook signature and API call pattern.

**Your adaptation:**
```typescript
pi.on("session_before_compact", async (event, ctx) => {
  const { messagesToSummarize, turnPrefixMessages } = event.preparation;

  // Extract lessons learned from conversation
  const lessons = extractLessons(messagesToSummarize);

  // Persist to pi-cortex API BEFORE context is lost
  for (const lesson of lessons) {
    await fetch("http://127.0.0.1:3002/api/lesson", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-API-Key": INTERNAL_KEY },
      body: JSON.stringify({
        content: lesson,
        category: inferCategory(lesson),
        source_agent: "pi-extension",
      }),
    });
  }
  // Don't override compaction — let Pi handle it normally
});
```

**Difference from original:** Original calls LLM for summary. You call your own API server. Same hook, different destination.

---

### 5. `message-integrity-guard.ts` (agent-pi) — OPTIONAL DEBUGGING

**Path:** `~/.pi/git/github.com/ruizrica/agent-pi/extensions/message-integrity-guard.ts` (~320 lines)  
**What to copy:** Read-only. Don't include in extension, but reference when debugging.

**Use case:** If `reconstructState()` fails because tool results were corrupted during compaction, this file shows how to validate message sequences. Keep it bookmarked for debugging.

---

### 6. `tool-search.ts` + `tool-registry.ts` (agent-pi) — ADVANCED ONLY

**Paths:** `agent-pi/extensions/tool-search.ts`, `agent-pi/extensions/tool-registry.ts`
**When to use:** Only if you want `memory_search_routed` to dynamically discover and call other memory tools.

**Simple alternative:** Hardcode the 7 tools directly in `registerTool()` calls. You don't need a registry until you have 20+ tools.

---

## 🏗️ Proposed Extension File Structure

```
app/extension/
├── index.ts                    # Entry point — exports default function(pi)
├── hooks/
│   ├── session-start.ts        # Load weights, check Neo4j
│   ├── context-inject.ts       # inject memory before LLM call
│   ├── tool-gate.ts            # Guardrails on tool_call
│   └── compaction-persist.ts   # POST /api/lesson on compact
├── tools/
│   ├── memory-search.ts        # GET /api/search
│   ├── memory-search-routed.ts # Search with token budget + routing
│   ├── memory-get.ts           # GET /api/knowledge/:id
│   ├── memory-record-lesson.ts # POST /api/lesson (local tracking)
│   ├── memory-get-graph.ts     # GET /api/graph/related/:id
│   ├── memory-status.ts        # GET /api/health
│   └── memory-feedback.ts      # POST /api/feedback
├── commands/
│   ├── mem-status.ts           # /mem-status
│   └── mem-vault.ts            # /mem-vault (open Obsidian reference)
├── state.ts                    # In-memory state + reconstructState()
├── api-client.ts               # fetch() wrapper for localhost:3002
├── render.ts                   # Tool call/result render functions
└── types.ts                    # TypeScript interfaces
```

**Why this structure:** Mirrors `memory-cycle.ts` (hooks/tools/commands separation) but modularized for 7 tools instead of 1.

---

## 🔗 Cross-Reference: PLAN.md §6 → Extension Hooks Mapping

| PLAN.md Requirement | Implementation File | Pattern Source |
|---------------------|---------------------|----------------|
| `session_start` — load weights | `hooks/session-start.ts` | `memory-cycle.ts` + `todo.ts` |
| `before_agent_start` — inject memory | `hooks/context-inject.ts` | `memory-cycle.ts` (`pi.on("context")`) |
| `tool_call` — security gate | `hooks/tool-gate.ts` | `security-guard.ts` |
| `turn_end` — detect patterns | `hooks/context-inject.ts` (or new file) | Partial: scan last assistant message |
| `session_shutdown` — persist state | `hooks/compaction-persist.ts` | `custom-compaction.ts` |

---

## ✅ Checklist Before First Commit

- [ ] Extension loads without error with `pi -e ./app/extension/index.ts`
- [ ] `session_start` hook prints Neo4j health status
- [ ] `memory_search` tool returns results from `curl http://127.0.0.1:3002/api/search`
- [ ] `context` event injects a memory block (visible in `pi -v` output)
- [ ] `tool_call` gate blocks `rm -rf /` (test with dry-run)
- [ ] `reconstructState()` restores weights after `pi /reload`
- [ ] `session_before_compact` POSTs to `/api/lesson` (check API server logs)

---

## 📚 Quick Access — Where to Read What

| If you need... | Read this file | Section to study |
|----------------|---------------|------------------|
| How an extension is structured top-to-bottom | `memory-cycle.ts` | Entire file |
| How tool schemas work | `examples/extensions/todo.ts` | `TodoParams` + `pi.registerTool()` |
| How to render tools in TUI | `memory-cycle.ts` | `renderCompactionCard()` |
| How to survive Pi restarts | `examples/extensions/todo.ts` | `reconstructState()` |
| How to intercept tool calls | `security-guard.ts` | `pi.on("tool_call")` block |
| How to intercept compaction | `examples/extensions/custom-compaction.ts` | `session_before_compact` hook |
| Full API reference | `docs/extensions.md` | Events + ExtensionAPI Methods |
| How skills work | `docs/skills.md` | SKILL.md format + progressive disclosure |

---

*This is a living doc — update when patterns are validated during implementation.*
