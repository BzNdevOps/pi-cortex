# Reference Extensions Install Manifest

> **Date:** 2026-05-03  
> **Purpose:** All extensions copied from OEM sources for pi-cortex extension development  
> **Location:** `pi-cortex/reference/extensions/`

---

## OEM Sources

| Package | Author | URL | Install Command |
|---------|--------|-----|-----------------|
| **Pi SDK (coding-agent)** | Mario Zechner | https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent | `npm i -g @mariozechner/pi-coding-agent` |
| **agent-pi** | ruizrica | https://github.com/ruizrica/agent-pi | `pi install git:github.com/ruizrica/agent-pi` |

---

## Installed Reference Extensions

| File | OEM Source | Original Path | Size | Lines | What to Copy |
|------|-----------|---------------|------|-------|-------------|
| `memory-cycle.ts` | agent-pi | `extensions/memory-cycle.ts` | 20 KB | ~420 | Full extension skeleton — hooks, tools, commands, state persistence |
| `security-guard.ts` | agent-pi | `extensions/security-guard.ts` | 29 KB | ~720 | `pi.on("tool_call")` gate pattern |
| `message-integrity-guard.ts` | agent-pi | `extensions/message-integrity-guard.ts` | 14 KB | ~320 | Session message validation (debug reference) |
| `tool-search.ts` | agent-pi | `extensions/tool-search.ts` | 9 KB | ~180 | Meta-tool / dynamic tool discovery |
| `tool-registry.ts` | agent-pi | `extensions/tool-registry.ts` | 8 KB | ~200 | In-memory tool categorization |
| `todo.ts` | Pi SDK | `examples/extensions/todo.ts` | 8.8 KB | ~200 | `reconstructState()` from session branch |
| `custom-compaction.ts` | Pi SDK | `examples/extensions/custom-compaction.ts` | 4.3 KB | ~100 | `session_before_compact` hook with external API call |

---

## How to Use

These are **reference files** — read them, copy patterns from them, but **do not import them directly** into your extension. They live in `reference/` (not `app/`) for a reason.

```bash
# Read the primary architecture reference
cat reference/extensions/memory-cycle.ts

# Copy key patterns into your extension
cp reference/extensions/memory-cycle.ts app/extension/index.ts
# Then strip out everything you don't need and rename variables
```

---

## Re-install from OEM (if needed)

```bash
# Re-install agent-pi (has memory-cycle, security-guard, etc.)
cd /home/bzn/Projects/BzNdevOps/bzn-pi-agents
pi install git:github.com/ruizrica/agent-pi

# SDK examples are bundled with pi-coding-agent
# Re-install SDK:
npm install -g @mariozechner/pi-coding-agent@latest
```

---

## License Note

- Pi SDK: MIT (Mario Zechner)
- agent-pi: Check repo at https://github.com/ruizrica/agent-pi
