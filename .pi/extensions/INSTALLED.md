# Pi Extensions Install Summary

> **Installed:** 2026-05-03
> **Location:** `/home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/`
> **Discovery:** Auto-discovered by Pi (`.pi/extensions/*.ts` and `.pi/extensions/*/index.ts`)

---

## Installed Extensions (6 total)

| # | Extension | File | Source | Status | Lib deps |
|---|-----------|------|--------|--------|----------|
| 1 | **qwen-autostart** | `.pi/extensions/qwen-autostart.ts` | bzn-pi-agents | ✅ Standalone | None |
| 2 | **message-integrity-guard** | `.pi/extensions/message-integrity-guard.ts` | agent-pi | ✅ Standalone | None |
| 3 | **todo** | `.pi/extensions/todo.ts` | Pi SDK | ✅ Standalone | None |
| 4 | **custom-compaction** | `.pi/extensions/custom-compaction.ts` | Pi SDK | ✅ Standalone | None |
| 5 | **memory-cycle** | `.pi/extensions/memory-cycle/index.ts` | agent-pi | ✅ With lib/ | memory-cycle-helpers.ts, context-gate.ts |
| 6 | **security-guard** | `.pi/extensions/security-guard/index.ts` | agent-pi | ✅ With lib/ | security-engine.ts |

---

## Directory Structure

```
.pi/extensions/
├── qwen-autostart.ts                    ← standalone
├── message-integrity-guard.ts           ← standalone
├── todo.ts                              ← standalone
├── custom-compaction.ts                 ← standalone
├── memory-cycle/
│   ├── index.ts                         ← memory-cycle.ts renamed
│   └── lib/
│       ├── memory-cycle-helpers.ts
│       └── context-gate.ts
├── security-guard/
│   ├── index.ts                         ← security-guard.ts renamed
│   └── lib/
│       └── security-engine.ts
└── tool-search/
    ├── index.ts                         ← tool-search.ts renamed
    ├── tool-registry.ts                 ← co-dependent
    └── lib/
        └── themeMap.ts
```

Note: **tool-search** is included as a subdirectory but depends on `tool-registry.ts`. Both are bundled.

---

## How Pi Discovers Them

Per Pi SDK docs (`extensions.md` lines 118–119):
- `.pi/extensions/*.ts` → auto-discovered as standalone files
- `.pi/extensions/*/index.ts` → auto-discovered as directory modules

**Settings.json** has `"extensions": []` so Pi uses auto-discovery only.

---

## Test It

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi
# Then inside pi:
/reload
```

You should see in `[Extensions]`:
```
ruizrica/agent-pi:agent-chain.ts
qwen-autostart
todo
custom-compaction
memory-cycle
security-guard
tool-search
tool-registry
```

If any fail to load, Pi will show an error line. Fix the import path and `/reload` again.

---

## Extension Sources (OEM)

| Extension | OEM URL |
|-----------|---------|
| qwen-autostart | Your custom code (bzn-pi-agents) |
| message-integrity-guard | https://github.com/ruizrica/agent-pi |
| memory-cycle | https://github.com/ruizrica/agent-pi |
| security-guard | https://github.com/ruizrica/agent-pi |
| tool-search | https://github.com/ruizrica/agent-pi |
| todo | https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/examples/extensions |
| custom-compaction | https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/examples/extensions |
