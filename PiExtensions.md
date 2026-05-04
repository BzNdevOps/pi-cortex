# Pi Extensions & Skills Reference — pi-cortex Coding Guide

> **Purpose:** Consolidated reference for coding the pi-cortex Pi extension.  
> **Scope:** Official Pi SDK patterns, agent-pi package extensions, and bzn-pi-agents local extensions that are useful as coding references.  
> **Last updated:** 2026-05-03

---

## Table of Contents

1. [Quick Start for pi-cortex Extension](#1-quick-start)
2. [Official Pi SDK Sources](#2-official-pi-sdk)
3. [agent-pi Package (ruizrica)](#3-agent-pi-package)
4. [bzn-pi-agents Local Extensions](#4-bzn-pi-agents-local)
5. [Recommended Reading Order](#5-reading-order)
6. [Key Patterns for pi-cortex](#6-key-patterns)
7. [What to Skip](#7-what-to-skip)
8. [File Locations](#8-file-locations)

---

## 1. Quick Start for pi-cortex Extension

The pi-cortex Pi extension needs:
- **5 lifecycle hooks** (PLAN.md §6): `session_start`, `before_agent_start`, `tool_call`, `turn_end`, `session_shutdown`
- **7 memory tools**: `memory_search`, `memory_search_routed`, `memory_get`, `memory_record_lesson`, `memory_get_graph`, `memory_status`, `memory_feedback`
- **6 skills** (PLAN.md §4): `mem-start`, `mem-status`, `mem-extract`, `mem-validate`, `mem-consolidate`, `mem-vault`

Core API entry point:
```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  // Hooks
  pi.on("session_start", async (_event, ctx) => { ... });
  pi.on("tool_call", async (event, ctx) => { ... });
  
  // Tools
  pi.registerTool({ name: "memory_search", ... });
  
  // Commands
  pi.registerCommand("mem-status", { ... });
}
```

---

## 2. Official Pi SDK — Primary Reference

### 📍 Location
`/home/bzn/.local/lib/node_modules/@mariozechner/pi-coding-agent/`

### 📖 Documentation

| File | Pages | Relevance | What to Extract |
|------|-------|-----------|-----------------|
| `docs/extensions.md` | ~100 | ⭐⭐⭐ PRIMARY REFERENCE | All events (`pi.on()`), `ExtensionAPI` methods, `ExtensionContext`, tool registration, command registration, custom UI, state management, error handling, mode behavior |
| `docs/skills.md` | ~10 | ⭐⭐⭐ HIGH | Skill format (`SKILL.md`), frontmatter spec, progressive disclosure, how skills load into system prompt |
| `docs/compaction.md` | ~20 | ⭐⭐⭐ HIGH | Session compaction lifecycle — critical for `session_shutdown` persistence hook |
| `docs/tui.md` | ~70 | ⭐⭐ MEDIUM | Custom rendering with `ctx.ui.custom()`, `Text`, `Container`, `Markdown`, keyboard input |
| `docs/sdk.md` | ~80 | ⭐⭐ MEDIUM | `createAgentSession()`, `SessionManager`, inline extension factories |

### 💻 Code Examples

| Example | Relevance | Pattern for pi-cortex |
|---------|-----------|----------------------|
| **`examples/extensions/todo.ts`** | ⭐⭐⭐ CRITICAL | **State reconstruction from session entries** — `reconstructState()` scans `ctx.sessionManager.getBranch()` for `toolResult` entries to rebuild in-memory state after Pi restart |
| **`examples/extensions/custom-compaction.ts`** | ⭐⭐⭐ CRITICAL | `session_before_compact` hook — intercept compaction, call external API, return summary. Replace LLM call with Neo4j query |
| **`examples/extensions/handoff.ts`** | ⭐⭐⭐ HIGH | `convertToLlm()`, `serializeConversation()`, `ctx.newSession()` — context transfer for sub-agents with memory injection |
| **`examples/extensions/summarize.ts`** | ⭐⭐ MEDIUM | `ctx.sessionManager.getBranch()` + `@mariozechner/pi-ai`'s `complete()` — building conversation text |
| **`examples/extensions/dynamic-tools.ts`** | ⭐⭐ MEDIUM | Runtime tool registration after `session_start` — useful if tools depend on config |
| **`examples/extensions/confirm-destructive.ts`** | ⭐⭐ MEDIUM | `tool_call` gate pattern — confirm before destructive action |
| **`examples/extensions/permission-gate.ts`** | ⭐⭐ MEDIUM | Pre-execution gate with user confirmation |

### 🔧 SDK Utilities

| Import | Source | Use in pi-cortex |
|--------|--------|-----------------|
| `Type` from `typebox` | shipped with Pi | Tool parameter schemas for all 7 memory tools |
| `StringEnum` from `@mariozechner/pi-ai` | shipped with Pi | Enum parameters (e.g., `level: compact|full|excerpt`) |
| `Text` from `@mariozechner/pi-tui` | shipped with Pi | `renderCall()` and `renderResult()` for tool display |
| `convertToLlm()`, `serializeConversation()` | `@mariozechner/pi-coding-agent` | Building conversation text for `memory_record_lesson` |
| `complete()` from `@mariozechner/pi-ai` | shipped with Pi | If extension needs to call an LLM (e.g., for routing) |

---

## 3. agent-pi Package (ruizrica) — Production Patterns

### 📍 Location
`/home/bzn/Projects/BzNdevOps/bzn-pi-agents/.pi/git/github.com/ruizrica/agent-pi/extensions/`

Loaded via `.pi/settings.json`:
```json
{
  "packages": [{
    "source": "git:github.com/ruizrica/agent-pi@58b2b34d...",
    "extensions": ["extensions/agent-chain.ts"]
  }]
}
```

### 🧠 Most Valuable Extensions

| Extension | Lines | Relevance | Pattern for pi-cortex |
|-----------|-------|-----------|----------------------|
| **`memory-cycle.ts`** | ~420 | ⭐⭐⭐ CRITICAL | **Direct template** for `before_agent_start` injection, `turn_end` pattern detection, compaction hooks. Uses `context` event for pre-LLM content injection. Registers `cycle_memory` tool + `/cycle` command |
| **`message-integrity-guard.ts`** | ~320 | ⭐⭐⭐ HIGH | Session event hooks (`session_before_compact`, `session_switch`, `context`) with validation/repair logic. Shows how to maintain state consistency across session operations |
| **`security-guard.ts`** | ~720 | ⭐⭐⭐ HIGH | Pre-`tool_call` gate with regex scanning, audit logging to `.pi/security-audit.log`, config-driven `.pi/security-policy.yaml`. **Exact pattern** for guardrails hook (PLAN.md §6) |
| **`tool-registry.ts`** | ~200 | ⭐⭐⭐ HIGH | In-memory index of tools with categories, tags, sources. Build similar registry for memory tools |
| **`tool-search.ts`** | ~180 | ⭐⭐⭐ HIGH | Meta-tool that searches registry — pattern for `memory_search_routed` discovering available categories |
| **`tool-caller.ts`** | ~250 | ⭐⭐ MEDIUM | Meta-tool `call_tool` that dynamically invokes other tools by name. Pattern for routing between `memory_search` variants |
| **`context-gate.ts`** (lib) | ~40 | ⭐⭐⭐ HIGH | Pure threshold functions (`PREP_THRESHOLD=70`, `COMPACT_THRESHOLD=80`). Reusable for token budget gates |
| **`agent-defs.ts`** (lib) | ~180 | ⭐⭐ MEDIUM | Frontmatter parser for `.md` files, JSON config loader (`models.json`), model resolution chain. Reuse for vault `.md` parsing |

### 📋 Extension API Patterns from agent-pi

#### Hook: `context` — pre-LLM injection
From `memory-cycle.ts`:
```typescript
pi.on("context", (event) => {
  // Fires before EVERY LLM call
  // Can inspect/modify messages or inject system prompt content
});
```
**pi-cortex use:** `before_agent_start` — inject memory block into system prompt before agent runs.

#### Hook: `tool_call` — pre-execution gate
From `security-guard.ts`:
```typescript
pi.on("tool_call", async (event, ctx) => {
  const { toolName, input } = event;
  // Scan for dangerous patterns
  if (isBlocked(toolName, input)) {
    return { block: true, reason: "Guardrail triggered" };
  }
});
```
**pi-cortex use:** Block destructive commands per guardrails (PLAN.md §6).

#### Tool registration with stateful execute
From `memory-cycle.ts`:
```typescript
pi.registerTool({
  name: "cycle_memory",
  parameters: Type.Object({ instructions: Type.Optional(Type.String()) }),
  async execute(toolCallId, params, signal, onUpdate, ctx) {
    // Full access to ctx.ui, ctx.sessionManager, etc.
    return { content: [...], details: {} };
  }
});
```

#### Command registration
```typescript
pi.registerCommand("cycle", {
  description: "Trigger memory compaction cycle",
  handler: async (args, ctx) => { ... }
});
```

---

## 4. bzn-pi-agents Local Extensions — Limited Value

### 📍 Location
`/home/bzn/Projects/BzNdevOps/bzn-pi-agents/extensions/`

| Extension | Relevance | Notes |
|-----------|-----------|-------|
| **`control-watch.ts`** | ⭐ LOW (for extension) ⭐⭐⭐ HIGH (for Gardener) | **Not an ExtensionAPI pattern.** Spawns `pi` CLI subprocesses via `child_process.spawn()`. Manual tool launcher, not autonomous. **Skip for extension coding.** BUT: `telegram()` spawn pattern and evidence directory structure reusable in Gardener standalone service |
| **`qwen-autostart.ts`** | ⭐ NONE | Specific to voice-pi (`model_select` → `systemctl start llama-qwen`). No relevance to memory graph |

---

## 5. Recommended Reading Order

For **coding the pi-cortex extension**, read in this priority order:

| Step | Read | Time | Why |
|------|------|------|-----|
| 1 | `docs/extensions.md` | 60 min | API contract — every event, method, type |
| 2 | `examples/extensions/todo.ts` | 15 min | State reconstruction from session = core pattern for persisting weights |
| 3 | `examples/extensions/custom-compaction.ts` | 15 min | Hook interception with external API call (replace with Neo4j) |
| 4 | `memory-cycle.ts` (agent-pi) | 30 min | Production implementation of exact hooks you need |
| 5 | `security-guard.ts` (agent-pi) | 20 min | Pre-tool-call gate with config-driven rules |
| 6 | `docs/skills.md` | 10 min | How to package skills for progressive disclosure |
| 7 | `examples/extensions/handoff.ts` | 15 min | Context transfer for sub-agent memory injection |
| 8 | `tool-search.ts` + `tool-registry.ts` (agent-pi) | 20 min | Tool registration patterns with schemas and categories |

---

## 6. Key Patterns for pi-cortex

### Pattern 1: Session State Reconstruction
**From:** `examples/extensions/todo.ts` (official) + `memory-cycle.ts` (agent-pi)

After Pi restarts, extension loses in-memory state. Rebuild from session history:
```typescript
const reconstructState = (ctx: ExtensionContext) => {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "message" && entry.message.role === "toolResult") {
      if (entry.message.toolName === "memory_record_lesson") {
        // Restore ACO weights, pheromones, etc.
      }
    }
  }
};

pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));
```

### Pattern 2: Pre-LLM Memory Injection
**From:** `memory-cycle.ts` (agent-pi)

Inject memory context before every agent turn:
```typescript
pi.on("context", (event) => {
  const messages = event.messages; // messages about to be sent to LLM
  // Prepend memory block to system prompt or last user message
});
```

### Pattern 3: Tool Call Gate (Guardrails)
**From:** `security-guard.ts` (agent-pi)

Block dangerous commands before execution:
```typescript
pi.on("tool_call", async (event) => {
  if (event.toolName === "bash") {
    const cmd = event.input.command;
    if (/rm\s+-rf/.test(cmd)) {
      return { block: true, reason: "Guardrail: destructive command blocked" };
    }
  }
});
```

### Pattern 4: Compact-and-Persist
**From:** `examples/extensions/custom-compaction.ts` (official)

Intercept compaction to persist memory to Neo4j:
```typescript
pi.on("session_before_compact", async (event, ctx) => {
  const { messagesToSummarize, turnPrefixMessages } = event.preparation;
  // Call pi-cortex API: POST /api/lesson with compaction summary
  // Return { compaction: { summary, firstKeptEntryId, tokensBefore } }
});
```

---

## 7. What to Skip

| Extension/Source | Skip Reason |
|-----------------|-------------|
| `control-watch.ts` (bzn-pi-agents) | Spawns subprocesses — not ExtensionAPI. For Gardener service, not Pi extension |
| `qwen-autostart.ts` (bzn-pi-agents) | voice-pi specific, no memory relevance |
| `subagent-widget.ts` (agent-pi) | TUI widgets + child process spawning — overkill |
| `agent-chain.ts` (agent-pi) | Complex chain orchestration — not needed for memory tools |
| `agent-team.ts` (agent-pi) | Multi-agent coordination — out of scope |
| `pipeline-team.ts` (agent-pi) | Pipeline rendering — TUI-specific, not needed |
| `summarize.ts` (agent-pi) | Calls external LLM — pi-cortex calls Neo4j instead |
| `send-email.ts`, `web-chat.ts` (agent-pi) | Out of scope |
| `snake.ts`, `tic-tac-toe.ts`, `space-invaders.ts`, `doom-overlay/` (official examples) | Games/demos — not relevant |
| `overlay-qa-tests.ts`, `overlay-test.ts` (official examples) | QA/test overlays — not needed |

---

## 8. File Locations

### Official SDK
```
/home/bzn/.local/lib/node_modules/@mariozechner/pi-coding-agent/
├── README.md                    # Overview
├── docs/
│   ├── extensions.md            # ⭐ Primary API reference
│   ├── skills.md                # ⭐ Skill format spec
│   ├── compaction.md            # ⭐ Compaction lifecycle
│   ├── tui.md                   # Custom UI components
│   ├── sdk.md                   # Programmatic SDK usage
│   └── ...
├── examples/
│   ├── extensions/
│   │   ├── todo.ts              # ⭐ State reconstruction
│   │   ├── custom-compaction.ts # ⭐ Compaction hook
│   │   ├── handoff.ts           # ⭐ Context transfer
│   │   ├── summarize.ts         # Session summarization
│   │   ├── dynamic-tools.ts     # Runtime tool registration
│   │   ├── confirm-destructive.ts # Tool gate pattern
│   │   └── ...                  # Skip games/demos
│   └── sdk/
│       ├── 05-tools.ts          # Tool filtering
│       ├── 06-extensions.ts     # Inline factory pattern
│       └── ...                  # Other SDK examples
└── dist/
    ├── core/*.d.ts              # TypeScript definitions
    └── index.d.ts               # Main types
```

### agent-pi Package (git)
```
/home/bzn/Projects/BzNdevOps/bzn-pi-agents/.pi/git/github.com/ruizrica/agent-pi/extensions/
├── memory-cycle.ts              # ⭐ Most valuable — compaction + injection hooks
├── message-integrity-guard.ts   # ⭐ Session validation/repair
├── security-guard.ts            # ⭐ Pre-tool gate + audit logging
├── tool-registry.ts             # ⭐ Tool categorization/indexing
├── tool-search.ts               # ⭐ Discovery meta-tool
├── tool-caller.ts               # Dynamic tool invocation
├── subagent-widget.ts           # Skip — child processes
├── agent-chain.ts               # Skip — chain orchestration
├── agent-team.ts                # Skip — multi-agent
├── pipeline-team.ts             # Skip — pipeline UI
├── lib/
│   ├── context-gate.ts          # ⭐ Threshold functions
│   ├── agent-defs.ts            # Frontmatter parser
│   └── ...                      # Supporting utilities
└── ...
```

### bzn-pi-agents (local)
```
/home/bzn/Projects/BzNdevOps/bzn-pi-agents/extensions/
├── control-watch.ts             # Skip for extension (see Gardener notes)
└── qwen-autostart.ts             # Skip — voice-pi specific
```

---

## Appendix: Pi Extension Quick Reference

### Events

| Event | Fires When | pi-cortex Use |
|-------|-----------|---------------|
| `session_start` | New session begins | Load weights.json, verify Neo4j health |
| `session_tree` | Session tree changes | Reconstruct state from branch history |
| `session_before_compact` | Before compaction runs | Persist accumulated lessons to Neo4j |
| `session_switch` | After session restore | Validate restored state |
| `context` | Before LLM API call | Inject memory block into context |
| `tool_call` | Before tool executes | Guardrails: block dangerous commands |
| `agent_start` | Agent begins processing | — |
| `agent_end` | Agent finishes turn | Detect patterns → suggest `memory_record_lesson` |
| `message_update` | Assistant message updates | Track progress for notifications |

### ExtensionContext (`ctx`)

| Property | Type | Use |
|----------|------|-----|
| `ctx.ui` | UI API | `notify()`, `confirm()`, `editor()`, `custom()` |
| `ctx.sessionManager` | SessionManager | `getBranch()`, `getSessionFile()` |
| `ctx.modelRegistry` | ModelRegistry | `find()`, `getApiKeyAndHeaders()` |
| `ctx.model` | Model | Current active model |
| `ctx.cwd` | string | Current working directory |
| `ctx.hasUI` | boolean | Whether running in interactive mode |

### ExtensionAPI (`pi`)

| Method | Use in pi-cortex |
|--------|-----------------|
| `pi.on(event, handler)` | Subscribe to lifecycle events |
| `pi.registerTool(def)` | Register 7 memory tools |
| `pi.registerCommand(name, def)` | Register `/mem-status` etc. |
| `pi.registerShortcut(key, def)` | Custom keyboard shortcuts |
| `pi.registerFlag(name, def)` | CLI flags |

---

*This document is a living reference — update when new patterns are discovered.*
