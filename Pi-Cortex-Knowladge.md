# Pi-Cortex Knowledge Base

> **Single source of truth for pi-cortex development.**  
> **Last updated:** 2026-05-03  
> **OEM Sources:**
> - Pi SDK: https://github.com/badlogic/pi-mono (packages/coding-agent/) — Mario Zechner, MIT
> - agent-pi: https://github.com/ruizrica/agent-pi — ruizrica
> - All reference extensions copied to `pi-cortex/reference/extensions/` for offline use

---

## Table of Contents

1. [What is pi-cortex?](#1-what-is-pi-cortex)
2. [Architecture Overview](#2-architecture-overview)
3. [The Pi Extension](#3-the-pi-extension)
4. [How to Install Local Extensions (Final Solution)](#4-how-to-install-local-extensions-final-solution)
5. [Installed Reference Extensions](#5-installed-reference-extensions)
6. [The Gardener Agent](#6-the-gardener-agent)
7. [Infrastructure & Constraints](#7-infrastructure--constraints)
8. [File Reference](#8-file-reference)

---

## 1. What is pi-cortex?

**pi-cortex** is a persistent knowledge graph system for Pi agents. It combines:
- **Neo4j** graph database (ACO, PageRank, contradiction detection)
- **REST API Server** (Node.js, :3002)
- **Markdown Vault** (Obsidian + WebDAV)
- **Knowledge Gardener** agent (17 autonomous missions)
- **Pi Extension** (TypeScript — hooks into Pi's lifecycle)

**Goal:** Agents remember what they learn across sessions, avoid repeated mistakes, and share knowledge across projects.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  iPhone / Laptop (Obsidian) ──WebDAV──→ /opt/knowledge-vault │
│                                                             │
│  Agent Pi (extension) ──API REST──→ API Server (:3002)      │
│                                                             │
│  Sub-agents ──API REST (filtered)──→ Neo4j (:7474/:7687)    │
│                                                             │
│  Gardener ──API REST (full)──────→ 17 missions autonomes    │
└─────────────────────────────────────────────────────────────┘
```

| Component | Tech | Location |
|-----------|------|----------|
| Neo4j | Community Edition, Podman Quadlet | bzserv (2 GB heap) |
| API Server | Node.js/Express | bzserv (:3002) |
| Vault | Markdown + nginx WebDAV | bzserv /opt/knowledge-vault |
| Gardener | Node.js standalone + systemd timers | bzserv |
| Pi Extension | TypeScript, Pi ExtensionAPI | Project-local (`.pi/extensions/`) |
| Proxy | nginx on VM1 (Tailscale) | Public access |

---

## 3. The Pi Extension

The Pi extension is the bridge between Pi agents and the knowledge graph. It implements **5 lifecycle hooks** and **7 memory tools**.

### 3.1 Lifecycle Hooks (PLAN.md §6)

| Hook | Event | Purpose |
|------|-------|---------|
| `session_start` | `pi.on("session_start", ...)` | Load `weights.json`, check Neo4j health |
| `before_agent_start` | `pi.on("context", ...)` | Inject memory block into system prompt before LLM call |
| `tool_call` | `pi.on("tool_call", ...)` | Guardrails: block dangerous commands |
| `turn_end` | Scan last assistant message | Detect patterns → suggest `memory_record_lesson` |
| `session_shutdown` | `pi.on("session_before_compact", ...)` | Persist accumulated lessons to Neo4j |

### 3.2 Memory Tools (7 total)

| Tool | API Endpoint | Purpose |
|------|-------------|---------|
| `memory_search` | `GET /api/search` | Lexical search + routing |
| `memory_search_routed` | `GET /api/search?budget=&level=` | Advanced search with token budget |
| `memory_get` | `GET /api/knowledge/:id` | Retrieve single knowledge node |
| `memory_record_lesson` | `POST /api/lesson` | Submit a learned lesson |
| `memory_get_graph` | `GET /api/graph/related/:id` | Explore knowledge graph |
| `memory_status` | `GET /api/health` | Graph health check |
| `memory_feedback` | `POST /api/feedback` | Rate knowledge usefulness |

### 3.3 Implementation Pattern

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  // -- HOOKS --
  pi.on("session_start", async (_event, ctx) => { ... });
  pi.on("context", async (event, ctx) => { ... });
  pi.on("tool_call", async (event, ctx) => { ... });

  // -- TOOLS --
  pi.registerTool({ name: "memory_search", ... });

  // -- COMMANDS --
  pi.registerCommand("mem-status", { ... });
}
```

---

## 4. How to Install Local Extensions (Final Solution)

**Critical finding:** `pi install` does **NOT** work for local `.ts` files. It only works for npm/git packages. Local extensions are loaded via **auto-discovery** or explicit paths in `settings.json`.

Per Pi SDK docs (`extensions.md`, line 7):
> `"Placement for /reload: Put extensions in ~/.pi/agent/extensions/ (global) or .pi/extensions/ (project-local) for auto-discovery."`

### 4.1 The 7-Step Process

**Step 1: Create the extensions directory**
```bash
mkdir -p /path/to/pi-cortex/.pi/extensions
```

**Step 2: Identify extension dependencies**
Check if the extension imports from `./lib/` or other relative paths:
```bash
grep 'from "\./' extension-file.ts
```
- **No relative imports** → standalone file
- **Has `./lib/...` imports** → needs subdirectory with dependencies

**Step 3: Install standalone extensions**
```bash
cp extension.ts .pi/extensions/
```

**Step 4: Install extensions with lib/ dependencies**
Create a subdirectory, rename to `index.ts`, copy lib files:
```bash
mkdir -p .pi/extensions/my-extension/lib
cp extension.ts .pi/extensions/my-extension/index.ts
cp -r lib/ .pi/extensions/my-extension/
```

**Step 5: Configure settings.json**
Use **auto-discovery** (cleanest):
```json
{
  "extensions": [],
  "packages": [...]
}
```

Or use **absolute paths**:
```json
{
  "extensions": [
    "/home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/my-extension/index.ts"
  ]
}
```

**WARNING:** Relative paths like `"../app/extension/index.ts"` are relative to `.pi/settings.json` and break silently if the target file doesn't exist.

**Step 6: Verify**
```bash
cd /path/to/pi-cortex
pi
# Inside Pi:
/reload
```

**Step 7: Check `[Extensions]` output**
```
[Extensions]
  qwen-autostart.ts, message-integrity-guard.ts, memory-cycle,
  security-guard, todo.ts, custom-compaction.ts, tool-search,
  ruizrica/agent-pi:agent-chain.ts
```

If any extension fails, Pi shows the error inline. Fix the import path and `/reload`.

### 4.2 Anti-Patterns to Avoid

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| `pi install ./my-extension.ts` | `pi install` only works for npm/git, not local files |
| `"extensions": ["../relative/path.ts"]` | Resolves relative to `.pi/settings.json`, breaks silently |
| Drop extension with `./lib/` deps into root `.pi/extensions/` | Import errors on `/reload` |

---

## 5. Installed Reference Extensions

All 6 ranked extensions are installed in `pi-cortex/.pi/extensions/` and auto-discovered.

| # | Extension | Source | Type | Installed Path |
|---|-----------|--------|------|----------------|
| 1 | **memory-cycle** | agent-pi | With lib/ | `.pi/extensions/memory-cycle/index.ts` |
| 2 | **todo** | Pi SDK | Standalone | `.pi/extensions/todo.ts` |
| 3 | **security-guard** | agent-pi | With lib/ | `.pi/extensions/security-guard/index.ts` |
| 4 | **custom-compaction** | Pi SDK | Standalone | `.pi/extensions/custom-compaction.ts` |
| 5 | **message-integrity-guard** | agent-pi | Standalone | `.pi/extensions/message-integrity-guard.ts` |
| 6 | **tool-search** | agent-pi | With lib/ | `.pi/extensions/tool-search/index.ts` |
| + | **qwen-autostart** | bzn-pi-agents | Standalone | `.pi/extensions/qwen-autostart.ts` |

### What each provides for pi-cortex

| Extension | Pattern to Copy | Use in pi-cortex |
|-----------|----------------|-----------------|
| `memory-cycle` | Extension skeleton with hooks/tools/commands | Main architecture for pi-cortex extension |
| `todo` | `reconstructState()` from session branch | Survive Pi restarts by rebuilding state from session history |
| `security-guard` | `pi.on("tool_call")` gate | Block dangerous commands per PLAN.md §6 guardrails |
| `custom-compaction` | `session_before_compact` hook | Persist accumulated lessons to Neo4j before context is lost |
| `message-integrity-guard` | Session message validation | Debug aid if state reconstruction fails |
| `tool-search` + `tool-registry` | Tool categorization registry | Build memory tool index with categories |
| `qwen-autostart` | `pi.on("model_select")` + systemd | Autostart local Qwen LLM when switching to `llama-local` provider |

### Why tool-registry is included
`tool-search.ts` imports `./tool-registry.ts`, so it's co-bundled in the `tool-search/` subdirectory.

---

## 6. The Gardener Agent

**Not a Pi extension.** The Gardener is a **standalone Node.js service** run by systemd timers.

**Why standalone?** Pi extensions are reactive (event-driven, manual triggers). The Gardener must be proactive (scheduled, autonomous). `control-watch.ts` from bzn-pi-agents proved this — it's a manual sub-agent launcher, not an autonomous scheduler.

### 17 Missions

| # | Mission | Frequency | Description |
|---|---------|-----------|-------------|
| 1 | Validate | Weekly | Check redundancy + accuracy |
| 2 | Consolidate | Weekly | Merge duplicates, promote project→global |
| 3 | Clean | Daily | ACO evaporation (-3%/day), prune dead nodes |
| 4 | Optimize | Monthly | PageRank, link reinforcement |
| 5 | Detect contradictions | Weekly | Logical consistency checks |
| 6 | Version | Weekly | valid_from/valid_to versioning |
| 7 | Track provenance | Daily | source_agent, source_url tracking |
| 8 | Detect gaps | Weekly | Unanswered queries → suggest knowledge |
| 9 | Clusterise | Monthly | Semantic grouping |
| 10 | Deprecation | Weekly | Detect @deprecated → mark obsolete |
| 11 | Cross-reference | Daily | Complete missing inverse relations |
| 12 | Normalise | Weekly | ISO 8601 dates, semver, consistent statuses |
| 13 | Score freshness | Daily | Age + link validity scoring |
| 14 | Feedback loop | Weekly | Process agent feedback → adjust confidence |
| 15 | Perf Neo4j | Daily | Monitor indexes, slow queries |
| 16 | Snapshot | Monthly | Export graph for rollback |
| 17 | Anomalies | Weekly | Detect structural deviations |

### systemd Timers

```ini
# /etc/systemd/system/pi-cortex-gardener-daily.timer
[Timer]
OnCalendar=daily
Persistent=true
```

---

## 7. Infrastructure & Constraints

### Target: bzserv (15 GB RAM)

| Component | RAM | Notes |
|-----------|-----|-------|
| OS + buffers | ~2 GB | — |
| Podman (ollama, open-webui, whisper) | ~3 GB | — |
| Neo4j (heap 2 GB + overhead) | ~3 GB | Community Edition |
| API Server (Node.js) | ~200 MB | — |
| Marge | ~7 GB | Available |

### Network Rules

| Rule | Detail |
|------|--------|
| **No `0.0.0.0`** | Bind on `127.0.0.1` or Tailscale IPs only |
| **Tailscale only** | `100.64.144.126` (bzserv), `100.110.99.95` (VM1) |
| **UFW order matters** | `ALLOW on tailscale0` BEFORE `DENY` |
| **No PublishPort** | Bug netavark Ubuntu 24.04 → use nginx proxy |
| **HTTPS + basic auth** | WebDAV for Obsidian |

### Service Bindings

| Service | Port | Bind | Auth | Status |
|---------|------|------|------|--------|
| voice-pi API | 8000 | 127.0.0.1 | X-API-Key | active |
| llama-qwen | 11435 | 100.64.144.126 | Bearer | active |
| searxng | 8888 | 127.0.0.1 | none | active |
| open-webui | 3000 | 127.0.0.1 | none | active (proxied) |
| netdata | 19999 | 100.64.144.126 | none | active |
| pi-cortex API | 3002 | 127.0.0.1 | X-API-Key | **planned** |
| Neo4j HTTP | 7474 | 127.0.0.1 | basic | **planned** |
| Neo4j Bolt | 7687 | 127.0.0.1 | basic | **planned** |

---

## 8. File Reference

### Core Documents

| File | Purpose |
|------|---------|
| `README.md` | Project overview, quick start, structure |
| `PLAN.md` | Full architecture spec (12 sections, 8 phases) |
| `AGENTS.md` | Agent conventions, security rules, SSH aliases |
| `AGENT_HANDOVER.md` | Session handover, next steps checklist |
| `ALGORITHMS.md` | 15 algorithms from codex-claude-memory-autopilot |
| `PiExtensions.md` | Full encyclopedia of SDK patterns |
| `PiExt-Blueprint.md` | Implementation blueprint — what to copy where |
| `Pi-Cortex-Knowladge.md` | **This file** — single source of truth |

### Reference Extensions (offline copies)

| File | OEM Source |
|------|-----------|
| `reference/extensions/memory-cycle.ts` | https://github.com/ruizrica/agent-pi |
| `reference/extensions/security-guard.ts` | https://github.com/ruizrica/agent-pi |
| `reference/extensions/message-integrity-guard.ts` | https://github.com/ruizrica/agent-pi |
| `reference/extensions/tool-search.ts` | https://github.com/ruizrica/agent-pi |
| `reference/extensions/tool-registry.ts` | https://github.com/ruizrica/agent-pi |
| `reference/extensions/todo.ts` | https://github.com/badlogic/pi-mono |
| `reference/extensions/custom-compaction.ts` | https://github.com/badlogic/pi-mono |
| `reference/extensions/qwen-autostart.ts` | bzn-pi-agents (custom) |

### Installed Extensions (active in Pi)

| File | Status |
|------|--------|
| `.pi/extensions/memory-cycle/index.ts` | ✅ Loaded |
| `.pi/extensions/security-guard/index.ts` | ✅ Loaded |
| `.pi/extensions/tool-search/index.ts` | ✅ Loaded |
| `.pi/extensions/todo.ts` | ✅ Loaded |
| `.pi/extensions/custom-compaction.ts` | ✅ Loaded |
| `.pi/extensions/message-integrity-guard.ts` | ✅ Loaded |
| `.pi/extensions/qwen-autostart.ts` | ✅ Loaded |

### Project Config

| File | Purpose |
|------|---------|
| `.pi/settings.json` | Pi config — auto-discovery enabled |
| `.pi/extensions/INSTALLED.md` | Install manifest for active extensions |
| `.gitignore` | Excludes node_modules, .env, .pi/install-cache |

---

*This document is the single source of truth. Update it when architecture changes or new patterns are validated.*
