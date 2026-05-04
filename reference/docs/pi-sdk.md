# Pi Coding Agent — Extension API Cheat Sheet
> Source: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md
> Fetched: 2026-05-04

## Extension entry point

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

export default function (pi: ExtensionAPI) {
  // register tools, subscribe to events, register commands
}
```

Async factories are supported: `export default async function(pi) { await setup(); ... }`

## Auto-discovery paths

| Location | Scope |
|----------|-------|
| `~/.pi/agent/extensions/*.ts` | Global |
| `~/.pi/agent/extensions/*/index.ts` | Global (subdirectory) |
| `.pi/extensions/*.ts` | Project-local |
| `.pi/extensions/*/index.ts` | Project-local (subdirectory) |

## Events — complete ordered list

### Session lifecycle
```
session_start          → fired on load / reload / new session
resources_discover     → contribute skill/prompt/theme paths
session_before_compact → fired BEFORE Pi compacts the conversation
session_before_switch  → fired before switching sessions
session_before_fork    → fired before forking
session_shutdown       → final teardown
```

### Per-turn (user prompt) flow — in order
```
input                  → intercept raw user text before expansion
before_agent_start     → inject messages, modify system prompt ← USE THIS for memory injection
agent_start            → LLM turn begins
message_start          → new LLM message starts streaming
message_update         → streaming delta
message_end            → LLM message complete
tool_execution_start   → tool about to run
tool_call              → blockable — fires before execution ← USE THIS for guardrails
tool_execution_update  → tool streaming output
tool_result            → tool done, result modifiable
tool_execution_end     → cleanup
turn_start / turn_end  → per LLM response cycle
agent_end              → full prompt completed ← USE THIS for lesson detection
```

## Event handler signatures

```typescript
// before_agent_start — inject memory into system prompt
pi.on("before_agent_start", async (event, ctx) => {
  // event.systemPromptOptions.skills, .tools, .guidelines, .contextFiles, .customPrompts
  // Return value can inject messages or replace/append system prompt:
  return {
    systemPrompt: "extra context to prepend",   // appended to Pi's system prompt
    messages: [{ role: "user", content: "..." }], // optional extra messages to inject
  };
  // Or return nothing to leave prompt unchanged
});

// tool_call — block dangerous commands
pi.on("tool_call", (event, ctx) => {
  // event.toolName — name of tool being called (e.g. "bash", "edit")
  // event.input — mutable! mutations propagate to actual execution
  const cmd = (event.input as any).command ?? "";
  if (cmd.includes("rm -rf /")) {
    return { block: true, reason: "Destructive command blocked by guardrail" };
  }
  // Return nothing (undefined) to allow
});

// tool_result — modify tool output
pi.on("tool_result", (event, ctx) => {
  // return partial patch: { output: "..." } — omitted fields retain current values
});

// session_before_compact — flush before compaction
pi.on("session_before_compact", async (event, ctx) => {
  // event.preparation.messagesToSummarize — messages being compacted
  // Must complete before returning — Pi waits for this hook
  // Do NOT throw — that would block compaction
});

// agent_end — detect errors, suggest lessons
pi.on("agent_end", (event, ctx) => {
  // event.messages — full conversation so far (read-only here)
});
```

## registerTool

```typescript
pi.registerTool("tool_name", {
  description: "What this tool does",
  parameters: Type.Object({
    query: Type.String({ description: "The search query" }),
    top_k: Type.Optional(Type.Number()),
  }),
  execute: async ({ query, top_k = 5 }) => {
    // return any JSON-serializable value
    // throw to signal error (sets isError: true in result sent to LLM)
    return { results: [] };
  },
  // Optional: custom rendering
  // renderCall: (input, theme, ctx) => TUI component
  // renderResult: (output, theme, ctx) => TUI component
});
```

**IMPORTANT:** Use `@sinclair/typebox` `Type.*` for schemas. `Type.Union` / `Type.Literal` does NOT work with Google's API — use `StringEnum` from `@mariozechner/pi-ai` instead.

## registerCommand

```typescript
pi.registerCommand("/mem-status", {
  description: "Show memory system health",
  handler: async (ctx) => {
    // ctx has extra methods: ctx.waitForIdle(), ctx.newSession(), ctx.reload()
    ctx.ui.notify("Memory healthy", "info");
  },
});
```

Multiple extensions registering the same command get numeric suffixes: `/cmd:1`, `/cmd:2`.

## ctx (ExtensionContext) — key methods

```typescript
ctx.ui.notify(message, severity)        // "info" | "warning" | "error" | "success"
ctx.ui.confirm(title, prompt)           // → Promise<boolean>
ctx.ui.input(prompt)                    // → Promise<string>
ctx.getContextUsage()                   // → { used: number, total: number }
ctx.getSystemPrompt()                   // → current chained system prompt string
ctx.compact()                           // trigger compaction programmatically
ctx.signal                              // AbortSignal — abort during active turns
ctx.cwd                                 // current working directory string
ctx.model                               // current model info
```

## Available imports

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";   // for string enums (not Type.Union)
import { Box, Text } from "@mariozechner/pi-tui";    // TUI components
// Node.js builtins work normally:
import { existsSync, readFileSync } from "node:fs";
```

## esbuild for Pi extensions

Pi expects `.ts` extension. Use `--outfile=path/index.ts` with explicit filename, or `--outdir + --out-extension:.js=.ts`.

```bash
# Recommended (explicit outfile):
esbuild src/index.ts --bundle --platform=node \
  --external:@mariozechner/pi-coding-agent \
  --external:@mariozechner/pi-tui \
  --external:@sinclair/typebox \
  --outfile=../../.pi/extensions/pi-cortex/index.ts

# Alternative (outdir + rename):
esbuild src/index.ts --bundle --platform=node \
  --external:@mariozechner/pi-coding-agent \
  --outdir=../../.pi/extensions/pi-cortex \
  --out-extension:.js=.ts
```

**`--external:pkg`** prevents bundling Pi packages (they are resolved at runtime by Pi).

## CRITICAL: before_agent_start vs context

PLAN-OPUS.md §6.2 uses the name `context` for the memory injection hook. The current Pi SDK names this event `before_agent_start`. Both may work — use `before_agent_start` if `context` does not fire in testing.

```typescript
// Try this first (current SDK name):
pi.on("before_agent_start", async (event, ctx) => { ... });
// Fallback if the above doesn't fire:
pi.on("context", async (event, ctx) => { ... });
```
