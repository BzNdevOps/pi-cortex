# pi-cortex — Plan détaillé (Opus 4.7 Audit Revision)

> **Auditor:** Claude Opus 4.7
> **Audit date:** 2026-05-03
> **Source plan:** `PLAN.md` (2026-05-03)
> **Status:** Architecture validated, deployment to begin — **with the corrections in this document**.
> **Convention:** Sections, sub-sections and rows added or rewritten by this audit are tagged `[OPUS REVISION]`. Items only clarified are tagged `[OPUS CLARIFICATION]`.

---

## 0. Audit Summary `[OPUS REVISION]`

The original `PLAN.md` is structurally sound. The macro-architecture (Neo4j as graph engine, Markdown as source of truth, REST API, Pi extension, autonomous Gardener, Obsidian/WebDAV human interface) is the right shape. The **fundamental risks are not in the design — they are in how much of it is being attempted in a single deployment, and in several concrete gaps that block any first-day usage**.

### High-severity findings (must fix before Phase 1)

| # | Finding | Why it blocks |
|---|---------|---------------|
| H1 | **Markdown ↔ Neo4j watcher is unspecified.** The plan mentions "Watcher Markdown → Neo4j" as one line in Phase 2.4 but never defines: source of truth on conflict, debouncing, frontmatter schema, deletion semantics, atomic write detection, fsnotify vs poll. Without this, Obsidian writes silently diverge from the graph. | Phase 7 (Obsidian) cannot complete. |
| H2 | **No conflict resolution model between Obsidian writes, agent writes (`POST /api/knowledge`), and Gardener writes.** Last-writer-wins on a graph is a correctness bug, not a feature. | Data corruption inside 1 week of use. |
| H3 | **Auth model is described as "levels 1/2/3" without defining how tokens are issued, rotated, stored, or transported.** `INTERNAL_API_KEY` is mentioned in `AGENTS.md` but never tied to the API. Sub-agent token provisioning at `fork()` is undocumented. | Sub-agent extension cannot be written; `pi install` for end users is impossible without a setup story. |
| H4 | **Pi extension fingerprints are inconsistent with the SDK.** `Pi-Cortex-Knowladge.md` correctly notes that `before_agent_start` is actually `pi.on("context", ...)`, but `PLAN.md §6` still uses the old name in the hooks table. The plan calls `session_shutdown` what the SDK calls `session_before_compact`. `turn_end` is actually `agent_end` per `PiExtensions.md` Appendix. | Implementation will not match the plan; reviewers will mistrust the spec. |
| H5 | **`pi install` does NOT load local `.ts` files** — confirmed in `Pi-Cortex-Knowladge.md §4`. The PLAN's Phase 8 `npm publish` strategy and the package.json `"pi.extensions": ["./app/extension"]` glob are correct only **after** npm publication. The plan does not describe the local-development path. | First agent attempting Phase 3 will be stuck for hours. |
| H6 | **Neo4j Community Edition does not include GDS by default; APOC Core is bundled but GDS Community must be installed manually**, and several missions (Optimize/PageRank — Mission 4; Cluster — Mission 9) depend on GDS. The plan assumes GDS is "just there". | Missions 4 + 9 silently fall back to no-op. |
| H7 | **The 17-mission Gardener is too large for an MVP.** No mission is marked optional. The plan provides no critical-path. | Phase 5 will balloon and block Phase 6/7/8. |
| H8 | **Algorithm-to-phase mapping is missing.** The 15 algorithms in `ALGORITHMS.md` are referenced via a single link from `PLAN.md`, but no phase commits to implementing any specific algorithm. | Algorithms get rediscovered during coding instead of designed in. |

### Medium-severity findings

| # | Finding | Mitigation |
|---|---------|------------|
| M1 | No backup strategy for Neo4j Podman volume during deployment (Restic does file-level, not transactional). | Add Neo4j `dump` cron + Restic of the dump file. |
| M2 | nginx WebDAV authentication is `auth_basic` over Tailscale only — fine for `bzn`, but plan also asks to expose via VM1 + Cloudflare Tunnel. Basic auth over a Cloudflare-fronted endpoint is acceptable but **must** be combined with Cloudflare Access or fail2ban; plan only mentions fail2ban. | Add Cloudflare Access policy, or restrict WebDAV to Tailscale (recommended). |
| M3 | API server is described as "Node.js + Express, port 3002" but no decision is made on neo4j-driver session pooling, timeouts, retry semantics, query parameterization standards. | Specify in §5.5 [OPUS REVISION]. |
| M4 | Memory injection into the system prompt has no token cap. A pathological vault of 100k tokens can blow up every agent turn. | Hard cap (default 1500 tokens) + adaptive degradation. |
| M5 | No Markdown frontmatter schema is specified. Both API server and watcher need to parse it deterministically. | Define in §4 [OPUS REVISION]. |
| M6 | Obsidian's `Remotely Save` plugin is community-maintained and has had multiple breaking changes; not all conflict modes are reliable. | Pin plugin version; test conflict scenario before declaring Phase 7 complete. |
| M7 | Pi SDK API version compatibility is not pinned. `pi-coding-agent` is pre-1.0; events have been renamed. | Pin `@mariozechner/pi-coding-agent` minor version in package.json + `pi --version` regression check in CI. |
| M8 | Sub-agent fallback "inject static memory at fork" is unimplemented and unspecified — what does Pi's `ctx.newSession()` actually receive? | Define in §9 [OPUS REVISION]. |
| M9 | `weights.json` and `taxonomy.json` are in the vault, synced over WebDAV. They are also written by the API. Race condition on iPhone-sync vs. API write. | Move them out of the WebDAV-synced area into `.pi-cortex/state/` (read-only to humans). |
| M10 | No observability: no metrics, no log aggregation, no dashboards. Health endpoint is a single counter dump. | Add `/metrics` (Prometheus text), Loki-or-journal-grep, simple Grafana board (deferred but planned). |

### Low-severity findings (record, don't block)

L1. The Gardener uses Pi sessions with system prompt — the plan's `pi -p --model gemini-flash --system-prompt "..."` invocation depends on Pi `-p` print mode being suitable for non-interactive sessions; verify before Phase 5.
L2. README.md and AGENT_HANDOVER.md still say "8 phases" — both must be updated to the new 11-phase split below.
L3. `Pi-Cortex-Knowladge.md` is misspelled — keep filename for now (already committed) but note in next handover.
L4. The hybrid "global socle + project memory" decision needs a concrete policy: does `pi install` write into `/opt/knowledge-vault/global/` (system-wide) or into `~/.pi-cortex/global/` (user)? Both have implications.
L5. `agent-chain.ts` is currently loaded in `.pi/settings.json` but is not part of pi-cortex's design. Decide: keep as ambient developer-experience tool, or remove for clean baseline.

### What this revision changes vs. PLAN.md

1. **Phases 1 → 11** instead of 1 → 8 (split Phase 2, add a watcher phase, add a Phase 0 prerequisite, add an Observability phase).
2. **Gardener split into 7 MVP missions + 10 deferred missions.**
3. **§4 (Neo4j Model)** gains an explicit Markdown frontmatter schema and indexes/constraints list.
4. **§5 (API)** gains the auth/transport spec, pooling, atomic write semantics, and a `Watcher` sub-section.
5. **§6 (Pi Extension)** gets corrected event names and a local-dev install recipe.
6. **§9 (Sub-agents)** gains a concrete token-issuance and `ctx.newSession()` injection contract.
7. **§12 (Risks)** grows from 8 to 16 entries; existing entries get sharper mitigations.
8. **New §13 — Algorithm Phase Mapping.** Pins each of the 15 algorithms to a deployment phase.
9. **New §14 — Observability and Backups.** Production-grade.
10. **New §15 — End-user `pi install` story.** Closes the public-package gap.

### Recommended decision now

Adopt this revision. Treat `PLAN.md` as the design memo and `PLAN-OPUS.md` as the execution plan. The next agent should **not** start Phase 1 from `PLAN.md`; they should start from §11 of this document.

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Architectural decisions](#2-architectural-decisions)
3. [Infrastructure](#3-infrastructure)
4. [Neo4j model + Markdown frontmatter](#4-neo4j-model--markdown-frontmatter)
5. [REST API + Watcher + Auth](#5-rest-api--watcher--auth)
6. [Pi extension](#6-pi-extension)
7. [Knowledge Gardener (MVP vs. deferred)](#7-knowledge-gardener-mvp-vs-deferred)
8. [Human interface — Obsidian + WebDAV](#8-human-interface--obsidian--webdav)
9. [Sub-agent access](#9-sub-agent-access)
10. [Pi package](#10-pi-package)
11. [Deployment phases (11 phases)](#11-deployment-phases)
12. [Risks and mitigations](#12-risks-and-mitigations)
13. [`[OPUS REVISION]` Algorithm phase mapping](#13-algorithm-phase-mapping)
14. [`[OPUS REVISION]` Observability and backups](#14-observability-and-backups)
15. [`[OPUS REVISION]` `pi install` end-user story](#15-pi-install-end-user-story)
- **[Algorithms & Concepts →](ALGORITHMS.md)** — 15 algorithms extracted from `codex-claude-memory-autopilot`

---

## 1. Executive summary

`pi-cortex` builds a **knowledge cortex** for Pi agents, inspired by `codex-claude-memory-autopilot` but 100% native to the Pi ecosystem (TypeScript extensions, skills, Pi packages).

**Goals (unchanged):**
- Speed up development by giving agents structured access to project memory
- Minimize tokens via progressive disclosure and category routing
- Avoid repeated mistakes via a base of error patterns and corrections
- Correct code in fewer iterations thanks to guardrails and a validated architecture
- Shareable with the Pi community via `pi install`

**Infrastructure:** everything on **bzserv** (15 GB RAM, Java 21, Podman), VM1 as public proxy.

`[OPUS CLARIFICATION]` **What pi-cortex is NOT, in V1:**
- Not a vector store — search is lexical + ACO. Embeddings are a deferred phase.
- Not a multi-tenant platform — single user `bzn`. Multi-tenancy is out-of-scope V1.
- Not a real-time collaboration tool — Obsidian WebDAV is single-writer-at-a-time in practice.
- Not a replacement for `codex-claude-memory-autopilot` — pi-cortex is the Pi-native sibling, sharing only algorithms.

---

## 2. Architectural decisions

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Self-contained package vs. framework | **Hybrid** | Global socle packaged + project memory to fill |
| 2 | Knowledge storage | **JSON Document Store** (`.md` + `.json`) as source of truth, **Neo4j** as graph engine | Git-friendly + powerful graph algorithms |
| 3 | Database | **Neo4j Community Edition 5.x** | Only option with native graph engine for ACO, PageRank, GDS |
| 4 | Human interface | **Obsidian + WebDAV** | Native iOS app + desktop, Markdown native, auto-sync |
| 5 | Knowledge extraction | **Agent validates → pending-review → Gardener validates → promotes** | Automatic with safety gate |
| 6 | Validator agent | **Knowledge Gardener — 17 missions** of which **7 are MVP** | See §7 [OPUS REVISION] |
| 7 | Sub-agents | **Hybrid (Option E)**: filtered read, write to `pending-review` only, fallback static injection at fork | Security + token-optimized |
| 8 `[OPUS]` | **Source of truth on conflict** | **Markdown wins** (vault is canonical). Neo4j is a derived index. | Recovery story: `rm -rf neo4j; reimport vault` always works. |
| 9 `[OPUS]` | **Embedding/vector search** | **Deferred to Phase 11+**. V1 is lexical + ACO + category routing. | Avoids GPU dependency, simpler, smaller surface. |
| 10 `[OPUS]` | **GDS plugin** | **Required**, install from official tarball at Phase 1. PageRank-dependent missions degrade gracefully if absent. | Plan assumed GDS but never installed it. |
| 11 `[OPUS]` | **Auth transport** | **`X-API-Key` header**, three keys (`PI_CORTEX_AGENT_KEY`, `PI_CORTEX_GARDENER_KEY`, `PI_CORTEX_SUBAGENT_KEY`), stored in `/home/bzn/.pi/.env`, rotated quarterly. | Minimal infrastructure, matches existing voice-pi pattern. |
| 12 `[OPUS]` | **Watcher technology** | **`chokidar`** (polling fallback for WebDAV-synced filesystem) with 500ms debounce + `*.md.tmp` ignore. | fsnotify alone misses WebDAV's atomic-rename pattern on iOS. |

---

## 3. Infrastructure

### Topology

```
iPhone / Laptop
    │ Obsidian.app → WebDAV (Tailscale-only by default; Cloudflare optional)
    ▼
[VM1 (OCI Paris, 954 MB RAM)]
    │ nginx proxy ONLY (optional, for off-Tailscale mobile access)
    ▼
bzserv (local, 15 GB RAM, RTX 5070 Ti)
    ├── Neo4j (Podman, heap 2 GB, ports 7474/7687, bind 127.0.0.1)
    ├── pi-cortex API (Node.js, port 3002, bind 127.0.0.1)
    ├── Vault Markdown (/opt/knowledge-vault/)
    ├── Watcher (Node.js, in-process or sibling daemon)
    ├── nginx local (WebDAV for Obsidian, bind 100.64.144.126:443)
    ├── Gardener (Node.js standalone, systemd timers)
    └── Pi Extension (loaded by pi from project's .pi/extensions/)
```

`[OPUS CLARIFICATION]` **VM1 is OPTIONAL.** All inter-node traffic should go via Tailscale. VM1 proxy exists only for the case where the iPhone is off-Tailscale (e.g., on a corporate Wi-Fi that blocks WireGuard). Phase 6 is **opt-in**, not default.

### bzserv RAM allocation `[OPUS CLARIFICATION]`

| Component | RAM | Notes |
|-----------|-----|-------|
| OS + buffers | ~2 GB | — |
| Podman (ollama, open-webui, whisper) | ~3 GB | Existing workload |
| Neo4j (heap 2 GB + page cache 512 MB + JVM overhead 500 MB) | ~3 GB | Heap CAP enforced via `NEO4J_server_memory_heap_max__size` |
| API Server (Node.js, neo4j-driver connection pool) | ~250 MB | Pool size = 50 (default) |
| Watcher (chokidar) | ~50 MB | Debounce buffer + open file handles |
| Gardener (peak, monthly PageRank job) | ~500 MB | Idle: ~50 MB |
| **Total committed** | **~9 GB** | |
| **Margin** | **~6 GB** | Comfortable |

⚠️ **GPU RAM is unrelated.** None of pi-cortex uses CUDA. The RTX 5070 Ti is reserved for ollama/whisper/llama-qwen.

### Storage

| Path | Size budget | Backup |
|------|-------------|--------|
| `/opt/knowledge-vault/` | < 100 MB (text) | Daily Restic |
| Podman volume `neo4j-data` | < 1 GB initial, grows to ~5 GB | Daily `neo4j-admin database dump` + Restic of dump |
| `/var/log/pi-cortex/` | rotated, max 500 MB | Journald + logrotate |
| `/home/bzn/.pi/.env` | < 4 KB | Restic + offline copy in password manager |

---

## 4. Neo4j model + Markdown frontmatter `[OPUS REVISION]`

### Node labels

```
Knowledge
Project
Category
Agent
Session
Strategy            ← [OPUS] for Strategy Learning algorithms
```

### `Knowledge` node properties

(unchanged from PLAN.md, plus the following additions/clarifications)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `id` | String | yes | `<scope>/<file-stem>` (e.g. `global/01-engineering-principles`) |
| `title` | String | yes | First H1 of the file or frontmatter `title:` |
| `content` | String | yes | Full Markdown body (after frontmatter) |
| `content_hash` | String | yes `[OPUS]` | SHA256 of content; used by watcher to skip no-op writes |
| `category` | String | yes | One of the 9 categories (closed enum, see below) |
| `status` | String | yes | `active` \| `draft` \| `archived` \| `deprecated` |
| `confidence` | Float | yes | 0.0 to 1.0 |
| `uses` | Int | yes | Default 0 |
| `last_used` | DateTime | no | nullable |
| `pagerank` | Float | no | Set by Mission 4 (monthly) |
| `freshness_score` | Float | no | Set by Mission 13 (daily) |
| `source_agent` | String | no | Agent that created the node |
| `source_url` | String | no | Provenance |
| `created_at` | DateTime | yes | |
| `updated_at` | DateTime | yes | |
| `valid_from` | DateTime | no | Versioning |
| `valid_to` | DateTime | no | Versioning |
| `version_id` | Int | no | Default 1 |
| `superseded_by` | String | no | ID of replacement |
| `vault_path` | String | yes `[OPUS]` | Relative path under `/opt/knowledge-vault/` for round-trip |

### Categories (closed enum) `[OPUS REVISION]`

```
architecture | mistakes | best-practices | corrections | guardrails |
open-questions | brief | reasoning-traces | self-model
```

The category set must match `ALGORITHMS.md §3.1` exactly. The Gardener (Mission 12) enforces this enum.

### Relationship types

(unchanged from PLAN.md — see §4 of the original)

### Indexes and constraints `[OPUS REVISION]`

```cypher
// Run once at Phase 1.3
CREATE CONSTRAINT knowledge_id_unique IF NOT EXISTS
  FOR (k:Knowledge) REQUIRE k.id IS UNIQUE;

CREATE CONSTRAINT category_name_unique IF NOT EXISTS
  FOR (c:Category) REQUIRE c.name IS UNIQUE;

CREATE INDEX knowledge_status IF NOT EXISTS
  FOR (k:Knowledge) ON (k.status);

CREATE INDEX knowledge_category IF NOT EXISTS
  FOR (k:Knowledge) ON (k.category);

CREATE FULLTEXT INDEX knowledge_search IF NOT EXISTS
  FOR (k:Knowledge) ON EACH [k.title, k.content];

CREATE INDEX rel_pheromone IF NOT EXISTS
  FOR ()-[r:RELATED_TO]-() ON (r.pheromone);
```

### Markdown frontmatter schema `[OPUS REVISION]`

Each file under `/opt/knowledge-vault/` MUST start with YAML frontmatter:

```yaml
---
id: global/01-engineering-principles
title: Engineering Principles
category: architecture            # one of the 9 closed enum
status: active                    # active | draft | archived | deprecated
confidence: 0.95
source_agent: bzn                 # human or agent name
source_url: null
created_at: 2026-05-03T14:00:00Z
updated_at: 2026-05-03T14:00:00Z
version_id: 1
related:                          # optional, becomes RELATED_TO edges
  - global/02-best-practices
  - global/05-guardrails
---

# Engineering Principles

(Markdown body...)
```

Watcher behavior (see §5):
- **Frontmatter is parsed by `gray-matter`.**
- Missing required fields → file is logged to `/var/log/pi-cortex/watcher-errors.log` and skipped (NOT promoted to `Knowledge` node).
- `content_hash` is computed by the watcher; nodes with unchanged hash are skipped (no Cypher write).
- `related:` list creates `RELATED_TO {pheromone: 1.0, last_used: now}` edges if missing.

### Markdown ↔ Neo4j conflict policy `[OPUS REVISION]`

| Source | When | Resolution |
|--------|------|------------|
| Obsidian human edit | Always | **Wins.** Watcher applies to Neo4j on next debounce window. |
| Agent `POST /api/knowledge` | When `content_hash` matches the in-Neo4j hash | API writes to Neo4j AND to vault file via the watcher's "write-back" channel. |
| Agent `POST /api/knowledge` | When `content_hash` differs (Obsidian wrote in between) | API returns `409 Conflict` with the current vault content; agent retries with merge. |
| Gardener | Always after `flock()` on `/var/lock/pi-cortex-gardener` | Holds lock, reads vault, writes vault, refreshes Neo4j. |

This is not optimistic locking on the database — it's optimistic on the **filesystem**. Markdown is the truth.

---

## 5. REST API + Watcher + Auth `[OPUS REVISION]`

### 5.1 Read endpoints (unchanged signature)

| Endpoint | Description |
|----------|-------------|
| `GET /api/search?q=&category=&project=&top_k=5&level=compact&budget_tokens=` | Lexical search + category routing + ACO ranking |
| `GET /api/knowledge/:id` | Retrieve single knowledge |
| `GET /api/graph/related/:id?depth=2` | Connected nodes + edge weights |
| `GET /api/weights/top?k=10` | Top knowledges by ACO weight |
| `GET /api/projects` | List projects |
| `GET /api/gaps` | Knowledge gaps (queries with no result) |
| `GET /api/contradictions` | Detected logical conflicts |
| `GET /api/freshness/:id` | Freshness score |
| `GET /api/health` | Graph health |
| `GET /api/pending-review` | Pending validation queue |
| `GET /metrics` `[OPUS]` | Prometheus text format (cf §14) |

### 5.2 Write endpoints (unchanged signature)

| Endpoint | Required level | Description |
|----------|:-------------:|-------------|
| `POST /api/knowledge` | 1, 2 | Create/update a knowledge |
| `POST /api/lesson` | 1, 2, 3 | Submit a lesson (→ `draft`) |
| `POST /api/graph/reinforce` | 1, 2 | Reinforce ACO weight |
| `POST /api/feedback` | 1, 2, 3 | Agent feedback (useful/not useful) |
| `DELETE /api/knowledge/:id` | 1, 2 | Soft-delete (archive) |
| `POST /api/admin/consolidate` | 2 | Trigger manual consolidation |
| `POST /api/admin/evaporate` | 2 | Force evaporation |
| `POST /api/admin/snapshot` | 2 | Create snapshot |

### 5.3 Auth model `[OPUS REVISION]`

**Three static API keys**, generated at deployment:

```bash
# /home/bzn/.pi/.env  (chmod 600)
PI_CORTEX_AGENT_KEY=sk-cortex-agent-<32 hex>
PI_CORTEX_GARDENER_KEY=sk-cortex-gardener-<32 hex>
PI_CORTEX_SUBAGENT_KEY=sk-cortex-subagent-<32 hex>
```

| Key | Level | Used by |
|-----|-------|---------|
| `PI_CORTEX_AGENT_KEY` | 1 | Pi extension (read by extension on `session_start`) |
| `PI_CORTEX_GARDENER_KEY` | 2 | Gardener systemd service |
| `PI_CORTEX_SUBAGENT_KEY` | 3 | Sub-agents — passed to `ctx.newSession()` env (see §9) |

Transport: HTTP `X-API-Key` header. The API rejects requests on `127.0.0.1:3002` if the header is absent or unknown. **No JWT, no OAuth — KISS.**

Rotation: quarterly (Q1 of each year). Rotation steps documented in `docs/runbooks/rotate-api-keys.md` (Phase 14 deliverable).

### 5.4 Neo4j connection pooling `[OPUS REVISION]`

```typescript
const driver = neo4j.driver(
  "bolt://127.0.0.1:7687",
  neo4j.auth.basic("neo4j", process.env.NEO4J_PASSWORD),
  {
    maxConnectionPoolSize: 50,
    connectionAcquisitionTimeout: 60_000,
    maxTransactionRetryTime: 30_000,
    logging: { level: "warn", logger: pino },
  }
);

// Per-request: read transactions for GET, write transactions for POST/DELETE
session.executeRead(async tx => tx.run(cypher, params));
session.executeWrite(async tx => tx.run(cypher, params));
```

**All queries are parameterized.** Cypher string concatenation is forbidden (Snyk-flagged in CI).

### 5.5 Watcher specification `[OPUS REVISION]`

- **Tech:** `chokidar` v3 with `usePolling: true` interval 1000ms (WebDAV does not always emit fsnotify events on iOS sync writes).
- **Watched paths:** `/opt/knowledge-vault/global/` and `/opt/knowledge-vault/project/`.
- **Ignored:** `*.tmp`, `*.swp`, `.obsidian/`, `*.json` (taxonomy and weights are managed by the API, not the human).
- **Debounce:** 500ms per file.
- **On `add`/`change`:**
  1. Read file, parse frontmatter via `gray-matter`.
  2. Validate against schema; on failure → log + skip.
  3. Compute `content_hash`. If same as Neo4j's stored hash → skip.
  4. Upsert `Knowledge` node + `RELATED_TO` edges from `related:` list.
- **On `unlink`:** Mark node `status=archived`, do NOT delete (allows undo via Obsidian undelete).
- **On startup:** Full reconciliation — every `.md` file is parsed and reconciled.
- **Lock:** `flock` on `/var/lock/pi-cortex-watcher` so the Gardener never collides.
- **Where it runs:** As a child process spawned by the API server (`watcher.ts`), supervised via the same systemd unit. Crash → unit restarts both. Rationale: avoids cross-process Neo4j credentials.

### 5.6 Tech stack

- Node.js 22+, TypeScript 5.x, Express 4.x, `neo4j-driver` 5.x, `chokidar` 3.x, `gray-matter` 4.x, `pino` 9.x, `zod` 3.x for input validation.
- Bind: `127.0.0.1:3002` only.
- Compose with VM1 nginx via Tailscale `100.64.144.126:3002` for Phase 6.
- Container: **NOT containerized.** Running natively under systemd reduces complexity (no PublishPort issues; the netavark bug applies). Keeps Neo4j as the only Podman thing.

---

## 6. Pi extension `[OPUS REVISION]`

### 6.1 Tools (unchanged set, 7 tools)

| Tool | Description |
|------|-------------|
| `memory_search` | Lexical search + category routing in Neo4j |
| `memory_search_routed` | Advanced version with token budget, level |
| `memory_get` | Read a complete knowledge |
| `memory_record_lesson` | Record a learned lesson |
| `memory_get_graph` | Explore the knowledge graph |
| `memory_status` | Memory health |
| `memory_feedback` | Give feedback on a knowledge |

### 6.2 Lifecycle hooks — **corrected event names** `[OPUS REVISION]`

| Original PLAN.md name | Actual Pi SDK event | Action |
|-----------------------|---------------------|--------|
| `session_start` | `session_start` | Load `weights.json` cache, ping `/api/health`, **call `reconstructState()` from session branch (todo.ts pattern)** |
| `before_agent_start` | **`context`** | Inject memory block (route → search → format → prepend to system prompt). **Hard cap 1500 tokens default** |
| `tool_call` | `tool_call` | Guardrails (block destructive cmds) |
| `turn_end` | **`agent_end`** | Detect error patterns in last assistant message → suggest `memory_record_lesson` |
| `session_shutdown` | **`session_before_compact`** | Persist accumulated lessons via `POST /api/lesson` BEFORE Pi compacts |
| `[OPUS NEW]` | `session_tree` | Re-run `reconstructState()` (matches todo.ts pattern) |

The plan must be updated to use the SDK names. The internal docs (Pi-Cortex-Knowladge.md) already use the right names.

### 6.3 Token-budgeted memory injection `[OPUS REVISION]`

```typescript
pi.on("context", async (event, ctx) => {
  const userMsg = lastUserMessage(event.messages);
  if (!userMsg) return;

  const budget = parseInt(process.env.PI_CORTEX_INJECT_BUDGET ?? "1500", 10);
  const res = await fetch(
    `http://127.0.0.1:3002/api/search?` +
    new URLSearchParams({
      q: userMsg,
      level: "compact",
      budget_tokens: String(budget),
      top_k: "5",
    }),
    { headers: { "X-API-Key": API_KEY }, signal: AbortSignal.timeout(800) }
  );

  if (!res.ok) {
    // Graceful degradation: no injection, agent proceeds without memory
    return;
  }

  const block = formatInjectionBlock(await res.json());
  // Inject at top of system message (memory-cycle.ts pattern)
  prependToSystem(event.messages, block);
});
```

Hard requirements:
- 800ms timeout. Pi must not stall on memory.
- Budget enforced server-side (token budgeting algorithm — `ALGORITHMS.md §1.5`).
- On timeout/error → silent skip, log to `/var/log/pi-cortex/extension.log`.

### 6.4 Local-development install recipe `[OPUS REVISION]`

Re-statement of `Pi-Cortex-Knowladge.md §4` for clarity in the plan:

**`pi install` does NOT load local `.ts` files.** During development:

```bash
# Project-local auto-discovery (preferred)
mkdir -p /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/pi-cortex
# Build:
cd /home/bzn/Projects/BzNdevOps/pi-cortex
npm run build:extension  # outputs app/extension/dist/index.js
# Copy/symlink:
ln -sf $(pwd)/app/extension/dist/index.js .pi/extensions/pi-cortex/index.ts
# Or, alternatively: write index.ts as a thin wrapper that imports the compiled bundle.

# Inside pi:
/reload
# Verify: [Extensions] line lists pi-cortex
```

`[OPUS RECOMMENDATION]` Use a **monolithic compiled `.ts` bundle** (esbuild bundle preserving `.ts` extension for Pi) under `.pi/extensions/pi-cortex/index.ts`. This avoids the lib/ subfolder dance.

### 6.5 Custom commands

| Command | Action |
|---------|--------|
| `/mem-status` | Show graph health, top weights |
| `/mem-vault` | Open `/opt/knowledge-vault/` reference (logs path, optionally launches `code`) |
| `/mem-lesson <text>` `[OPUS]` | Manual lesson record (shortcut for `memory_record_lesson` tool) |
| `/mem-search <query>` `[OPUS]` | Manual search shortcut |

---

## 7. Knowledge Gardener — MVP vs. deferred `[OPUS REVISION]`

The Gardener is a **standalone Node.js daemon** triggered by systemd timers (it is NOT a Pi extension — confirmed in `Pi-Cortex-Knowladge.md §6`). For each invocation it acquires `flock(/var/lock/pi-cortex-gardener)` and refuses to run concurrently.

### 7.1 MVP missions (Phase 5a — required for first useful release) `[OPUS]`

| # | Mission | Frequency | Why MVP |
|---|---------|-----------|---------|
| 3 | **Clean (ACO evaporation)** | Daily | Without it, weights never stabilize; "stale" knowledge never demotes. |
| 6 | **Version** | Weekly | `valid_from`/`valid_to` is needed before any `superseded_by` — and it's cheap. |
| 7 | **Track provenance** | Daily | `source_agent` + `source_url` is required for trust scoring; trivial to implement. |
| 11 | **Cross-reference** | Daily | Inverse relations are what makes the graph navigable. Without it, search returns dead ends. |
| 13 | **Score freshness** | Daily | Used by API ranking; trivial. |
| 15 | **Perf Neo4j** | Daily | Catches super-nodes before they kill the graph. |
| 16 | **Snapshot** | Monthly | Disaster recovery. **Must exist before Phase 7.** |

### 7.1.1 Cypher for critical MVP missions `[OPUS — implement exactly as written]`

**Mission 3 — ACO evaporation (daily)**

Neo4j 5.x datetime arithmetic: use `duration.between(k.updated_at, datetime()).days` — NOT `duration.inDays()` which takes two Duration arguments, not two DateTime arguments.

```cypher
// Evaporate pheromone weights — run daily via pi-cortex-gardener@clean.service
MATCH (k:Knowledge)
WHERE k.updated_at IS NOT NULL
SET k.pheromone_weight = toFloat(coalesce(k.uses, 0))
  * exp(-toFloat(duration.between(k.updated_at, datetime()).days) / 30.0)
RETURN count(k) AS evaporated
```

If `updated_at` is stored as ISO string (not Neo4j DateTime), parse it first:
```cypher
SET k.pheromone_weight = toFloat(coalesce(k.uses, 0))
  * exp(-toFloat(duration.between(datetime(k.updated_at), datetime()).days) / 30.0)
```

**Mission 11 — Cross-reference inverse relations (daily)**

Use `MERGE` (not `CREATE`) to avoid duplicates on every run. Properties on MERGE must be in the `ON CREATE SET` clause.

```cypher
// Create inverse RELATED_TO edges where they are missing
MATCH (a:Knowledge)-[:RELATED_TO]->(b:Knowledge)
WHERE NOT (b)-[:RELATED_TO]->(a)
  AND a.id <> b.id
MERGE (b)-[r:RELATED_TO]->(a)
ON CREATE SET r.pheromone = 0.0, r.created_at = datetime(), r.source = "gardener-crossref"
RETURN count(r) AS created
```

**Mission 13 — Freshness scoring (daily)**

```cypher
// freshness = 1 / (1 + ln(days_since_accessed + 1)) — range (0, 1]
MATCH (k:Knowledge)
WHERE k.last_accessed IS NOT NULL
SET k.freshness_score = 1.0 / (
  1.0 + log(toFloat(duration.between(datetime(k.last_accessed), datetime()).days) + 1.0)
)
RETURN count(k) AS scored
```

**Mission 16 — Snapshot (monthly)**

```bash
# Exact command for Neo4j 5.x inside Podman container
# Stop writes first (brief), dump, restart writes
podman exec neo4j neo4j-admin database dump neo4j \
  --to-path=/data/backups/ \
  --overwrite-destination=true
# Then copy out of container:
podman cp neo4j:/data/backups/neo4j.dump /var/backups/neo4j/neo4j-$(date +%Y%m%d).dump
```

### 7.2 Deferred missions (Phase 5b — added incrementally after first 30 days of usage) `[OPUS]`

| # | Mission | Trigger to implement |
|---|---------|----------------------|
| 1 | Validate (SearXNG accuracy check) | After 100 knowledge nodes accumulated |
| 2 | Consolidate (semantic dedup) | After observed duplicate ratio > 5% |
| 4 | Optimize (PageRank) | After GDS plugin verified working |
| 5 | Detect contradictions | After observed contradiction count flagged ≥ 3 |
| 8 | Detect gaps | After search miss-rate > 20% |
| 9 | Clusterise | After PageRank running |
| 10 | Deprecation | After first `@deprecated` tag observed |
| 12 | Normalise | After category drift observed |
| 14 | Feedback loop | After ≥ 50 feedback events recorded |
| 17 | Anomaly detection | After 6 weeks of stable graph (need baseline) |

### 7.3 Gardener invocation `[OPUS REVISION]`

The original plan suggested running the Gardener as a Pi session (`pi -p --model gemini-flash --system-prompt "..."`). **This is fragile** — Pi's `-p` mode is an interactive shell, model availability changes, and it embeds an LLM cost on every tick.

**Recommended:** Each mission is a **plain Node.js function** in `app/gardener/missions/<NN>-<name>.ts`. The systemd timer invokes:

```bash
node /opt/pi-cortex/gardener/dist/gardener.js --mission=clean --root=/opt/knowledge-vault
```

LLM calls (e.g. Mission 1 validate via SearXNG) are made **only when the mission requires it**, via direct fetch to OpenRouter or a local model — not via Pi shell. This avoids the Pi runtime and gives the Gardener clean error semantics.

### 7.4 systemd units `[OPUS CLARIFICATION]`

```ini
# /etc/systemd/system/pi-cortex-gardener@.service
[Unit]
Description=pi-cortex Gardener mission %I
After=pi-cortex-api.service neo4j.service
Requires=pi-cortex-api.service

[Service]
Type=oneshot
User=bzn
EnvironmentFile=/home/bzn/.pi/.env
ExecStart=/usr/bin/node /opt/pi-cortex/gardener/dist/gardener.js --mission=%I --root=/opt/knowledge-vault
Nice=10
TimeoutStartSec=300
StandardOutput=journal
StandardError=journal
```

Three timers (`-daily.timer`, `-weekly.timer`, `-monthly.timer`) each `Wants=` the right `pi-cortex-gardener@<name>.service` instances.

---

## 8. Human interface — Obsidian + WebDAV `[OPUS REVISION]`

### Setup (mostly unchanged)

```bash
# On bzserv
sudo apt install nginx-extras  # WebDAV module included

# STEP 1 — Create the htpasswd file BEFORE writing the nginx config.
# Without this file nginx fails to start (auth_basic_user_file missing).
# Replace CHOOSE_A_PASSWORD with a real password; save it in /home/bzn/.pi/.env as WEBDAV_PASSWORD=...
sudo apt install apache2-utils -y
sudo htpasswd -c /etc/nginx/.htpasswd-knowledge bzn
# Verify: sudo cat /etc/nginx/.htpasswd-knowledge  → should show "bzn:$apr1$..."

# STEP 2 — Create vault root and set ownership
sudo mkdir -p /opt/knowledge-vault/{global,project,pending-review}
sudo chown -R bzn:bzn /opt/knowledge-vault

# STEP 3 — Write the nginx config
# /etc/nginx/sites-enabled/knowledge-vault
server {
    listen 100.64.144.126:443 ssl;       # Tailscale only
    server_name bzserv.tail011919.ts.net;

    ssl_certificate     /etc/ssl/certs/bzserv-tailscale.crt;
    ssl_certificate_key /etc/ssl/private/bzserv-tailscale.key;

    client_max_body_size 50m;

    location /knowledge/ {
        alias /opt/knowledge-vault/;
        dav_methods PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS;
        dav_access user:rw group:r all:r;
        create_full_put_path on;

        auth_basic "Knowledge Vault";
        auth_basic_user_file /etc/nginx/.htpasswd-knowledge;

        # Hide vault internal state files from Obsidian writers
        location ~ /knowledge/(taxonomy|weights)\.json$ {
            return 403;
        }
    }
}
```

`[OPUS REVISION]` `taxonomy.json` and `weights.json` are **not** in `/opt/knowledge-vault/` anymore — they are in `/var/lib/pi-cortex/state/` (managed by API). This removes the M9 race condition.

### Vault structure `[OPUS REVISION]`

```
/opt/knowledge-vault/                    ← Obsidian-synced
├── global/                              ← Socle (system-managed; humans rarely edit)
│   ├── 01-engineering-principles.md
│   ├── 02-best-practices.md
│   ├── 03-mistakes-patterns.md
│   ├── 04-correction-patterns.md
│   └── 05-guardrails.md
├── project/                             ← Project-specific (humans + agents edit)
│   ├── 01-project-brief.md
│   ├── 02-validated-architecture.md
│   ├── 03-design-mistakes.md
│   ├── 04-best-practices.md
│   ├── 05-correction-patterns.md
│   ├── 06-guardrails.md
│   └── 07-open-questions.md
├── pending-review/                      ← [OPUS] sub-agent writes land here
│   └── *.md
└── .obsidian/                           ← Obsidian config

/var/lib/pi-cortex/state/                ← NOT synced
├── taxonomy.json
└── weights.json
```

### Plugin Obsidian — Remotely Save

| Setting | Value |
|---------|-------|
| Plugin | **Remotely Save 0.5.x** (pin minor version; community-maintained) |
| Type | WebDAV |
| URL | `https://bzserv.tail011919.ts.net/knowledge/` |
| Auth | Basic |
| User | `bzn` |
| Password | (htpasswd) |
| Sync on save | `true` |
| Sync interval | `30s` |
| Conflict mode | **Manual review** (do NOT use auto-merge — corrupts frontmatter) |

### Cloudflare Tunnel exposure `[OPUS CLARIFICATION]`

Optional, deferred to Phase 6. **If enabled, gate with Cloudflare Access** (Zero Trust email-based auth) — basic auth alone over a public hostname is insufficient.

---

## 9. Sub-agent access `[OPUS REVISION]`

### Levels (unchanged)

| Level | Agent | Read | Write | Scope |
|-------|-------|:----:|:-----:|-------|
| 1 | Main agent | ✅ All | ✅ All | Full graph |
| 2 | Gardener | ✅ All | ✅ All | Full graph |
| 3 | Sub-agents | ✅ Filtered | ⚠️ `pending-review/` only | Restricted |

### How sub-agent tokens are issued `[OPUS REVISION]`

When the main agent calls `ctx.newSession()` (Pi handoff pattern), the extension passes:

```typescript
const subSession = await ctx.newSession({
  systemPrompt: parentSystemPrompt + memoryFallbackBlock,
  env: {
    PI_CORTEX_API_URL: "http://127.0.0.1:3002",
    PI_CORTEX_API_KEY: process.env.PI_CORTEX_SUBAGENT_KEY,
    PI_CORTEX_LEVEL: "3",
    PI_CORTEX_CATEGORY_FILTER: inferCategoryFromTask(task),
  },
});
```

The sub-agent's pi-cortex extension reads `PI_CORTEX_API_KEY` and `PI_CORTEX_CATEGORY_FILTER`. The API enforces:

```typescript
// Middleware
if (req.header("X-API-Key") === SUBAGENT_KEY) {
  req.level = 3;
  req.categoryFilter = req.header("X-Category-Filter") ?? null;
}
```

### Fallback static injection `[OPUS REVISION]`

If `/api/health` returns 5xx or times out 800ms three times in a session, the main agent's `ctx.newSession()` injects a **pre-computed static memory block** (`/var/lib/pi-cortex/state/fallback-block.md`, refreshed daily by Gardener Mission 7). This block is the top-50 by ACO weight, formatted compact, ~2000 tokens.

The sub-agent's extension detects "API unavailable" and skips its own injection — relying on the parent's static block.

---

## 10. Pi package `[OPUS CLARIFICATION]`

### package.json

```json
{
  "name": "@bzndevops/pi-cortex",
  "version": "0.1.0",
  "description": "Pi memory autopilot — Neo4j-powered knowledge graph for Pi agents",
  "keywords": ["pi-package"],
  "engines": {
    "pi": ">=0.5.0 <0.7.0"
  },
  "pi": {
    "extensions": ["./extension/dist/index.ts"],
    "skills": ["./skills"],
    "prompts": ["./prompts"]
  },
  "dependencies": {
    "@mariozechner/pi-coding-agent": "^0.6.0",
    "@sinclair/typebox": "^0.32.0",
    "neo4j-driver": "^5.0.0",
    "zod": "^3.22.0"
  }
}
```

`[OPUS REVISION]` Pin `pi-coding-agent` minor version. Pi's pre-1.0 events have been renamed historically.

### Skills (6) — unchanged set, content TBD per `docs/skills.md`

`mem-start`, `mem-status`, `mem-extract`, `mem-validate`, `mem-consolidate`, `mem-vault`.

### Prompts (2) — `mem-review.md`, `mem-lesson.md`.

### Layout

```
pi-cortex/                                      ← repo root
├── app/
│   ├── api-server/        ← Node.js/Express, REST API
│   ├── extension/         ← TypeScript Pi extension (built via esbuild)
│   ├── gardener/          ← Standalone Gardener + missions
│   └── shared/            ← [OPUS] Stemmer, scorer, frontmatter parser, types
├── skills/                ← 6 SKILL.md
├── prompts/               ← 2 prompt templates
├── knowledge/global/      ← 5 .md packaged with the npm release
├── infra/                 ← [OPUS] Quadlet units, nginx confs, systemd timers
│   ├── neo4j.container
│   ├── pi-cortex-api.service
│   ├── pi-cortex-gardener@.service
│   ├── pi-cortex-gardener-daily.timer
│   ├── pi-cortex-gardener-weekly.timer
│   ├── pi-cortex-gardener-monthly.timer
│   └── nginx-knowledge-vault.conf
└── docs/
    └── runbooks/
        ├── deploy-bzserv.md
        ├── rotate-api-keys.md
        ├── restore-from-snapshot.md
        └── obsidian-conflict-resolution.md
```

`[OPUS REVISION]` Add `infra/` and `docs/runbooks/` — without runbooks the operator (you) is fragile.

---

## 11. Deployment phases — **11 phases** `[OPUS REVISION]`

The original 8 phases are split and reordered. New phases are added (0, 2b, 9). Existing phases are renumbered.

### Phase 0 — Prerequisites `[OPUS NEW]`

| Step | Task | Status |
|------|------|--------|
| 0.1 | Generate `PI_CORTEX_*_KEY` triple → write to `/home/bzn/.pi/.env`, chmod 600 | ⬜ |
| 0.2 | Verify Java 21 present on bzserv (`java -version`) | ⬜ |
| 0.3 | Verify `nginx-extras` available in apt | ⬜ |
| 0.4 | Verify Tailscale TLS cert exists (`/etc/ssl/certs/bzserv-tailscale.crt`); generate via `tailscale cert` if missing | ⬜ |
| 0.5 | Decide global socle location (`/opt/knowledge-vault/global/` vs `~/.pi-cortex/global/`) — **decision: `/opt/knowledge-vault/global/`** for V1 single-user | ⬜ |
| 0.6 | Confirm `Pi-Cortex-Knowladge.md` install recipe still works after Pi version bumps | ⬜ |

### Phase 1 — Infrastructure (bzserv)

| Step | Task | Status |
|------|------|--------|
| 1.1 | Deploy Neo4j Community via Podman Quadlet (`/etc/containers/systemd/neo4j.container`), bind `127.0.0.1:7474` and `127.0.0.1:7687` | ⬜ |
| 1.2 | Install APOC (bundled) + **GDS Community plugin** from official tarball | ⬜ |
| 1.3 | Apply Cypher constraints + indexes (§4) | ⬜ |
| 1.4 | Create `/opt/knowledge-vault/{global,project,pending-review,.obsidian}` and `/var/lib/pi-cortex/state/` | ⬜ |
| 1.5 | Configure nginx WebDAV for Obsidian (Tailscale-only, basic auth, hide `*.json`) | ⬜ |
| 1.6 | Configure UFW: `ALLOW on tailscale0` for 443, then verify `ALLOW...DENY` order with `ufw status numbered` | ⬜ |
| 1.7 | Set up daily Restic backup of `/opt/knowledge-vault/` | ⬜ |
| 1.8 | Set up daily `neo4j-admin database dump` cron + Restic of dump | ⬜ |

### Phase 2a — API Server core `[OPUS REVISION — split from old Phase 2]`

| Step | Task | Status |
|------|------|--------|
| 2a.1 | Initialize Node.js + TypeScript project under `app/api-server/` | ⬜ |
| 2a.2 | Implement neo4j-driver wrapper with pooling, retries, parameterized queries | ⬜ |
| 2a.3 | Implement read endpoints (`/api/search`, `/api/knowledge/:id`, `/api/graph/related/:id`, `/api/weights/top`, `/api/projects`, `/api/freshness/:id`, `/api/health`) | ⬜ |
| 2a.4 | Implement Porter-lite stemmer + lexical scoring (`ALGORITHMS.md §1.1, §1.2`) in TypeScript | ⬜ |
| 2a.5 | Implement combined scoring (lexical × pheromone) (`§1.3`), excerpt sizing (`§1.4`), token budgeting (`§1.5`) | ⬜ |
| 2a.6 | Implement category routing (`§3.1`, `§3.2`) | ⬜ |
| 2a.7 | Auth middleware (3-key model) | ⬜ |
| 2a.8 | systemd unit `pi-cortex-api.service` | ⬜ |

### Phase 2b — Watcher + write endpoints `[OPUS NEW]`

| Step | Task | Status |
|------|------|--------|
| 2b.1 | Implement chokidar watcher with debounce, frontmatter parsing, content_hash | ⬜ |
| 2b.2 | Full reconciliation on startup | ⬜ |
| 2b.3 | Write endpoints: `POST /api/knowledge` (with 409 on hash mismatch), `POST /api/lesson`, `POST /api/graph/reinforce`, `POST /api/feedback`, `DELETE /api/knowledge/:id` | ⬜ |
| 2b.4 | ACO batch flush (`§2.2`) — accumulate reinforcements, flush every 10 ops + on shutdown | ⬜ |
| 2b.5 | API integration tests covering watcher round-trip (write file → query Neo4j) | ⬜ |
| 2b.6 | API + watcher under same systemd unit (sibling supervisor) | ⬜ |

### Phase 3 — Pi extension `[OPUS REVISION — corrected event names]`

| Step | Task | Status |
|------|------|--------|
| 3.1 | Scaffold `app/extension/` with esbuild → bundle to `.pi/extensions/pi-cortex/index.ts` | ⬜ |
| 3.2 | Implement `session_start` (load weights cache, ping `/api/health`, `reconstructState()`) | ⬜ |
| 3.3 | Implement `context` hook (memory injection with 800ms timeout + 1500-token cap) | ⬜ |
| 3.4 | Implement `tool_call` gate (regex blocklist, mirror `security-guard.ts`) | ⬜ |
| 3.5 | Implement `agent_end` (pattern detection → suggest `memory_record_lesson`) | ⬜ |
| 3.6 | Implement `session_before_compact` (POST lessons to `/api/lesson`) | ⬜ |
| 3.7 | Implement `session_tree` (re-run `reconstructState`) | ⬜ |
| 3.8 | Register 7 tools (`memory_*`) | ⬜ |
| 3.9 | Register 4 commands (`/mem-status`, `/mem-vault`, `/mem-lesson`, `/mem-search`) | ⬜ |
| 3.10 | Verify `/reload` lists `pi-cortex` in `[Extensions]` line | ⬜ |
| 3.11 | Extension unit tests (mock fetch to API) | ⬜ |

### Phase 4 — Skills + prompt templates

| Step | Task | Status |
|------|------|--------|
| 4.1–4.6 | 6 SKILL.md as in original plan | ⬜ |
| 4.7 | 2 prompt templates | ⬜ |

### Phase 5a — Gardener MVP `[OPUS REVISION — split into 5a/5b]`

| Step | Task | Status |
|------|------|--------|
| 5a.1 | Scaffold `app/gardener/` standalone Node.js | ⬜ |
| 5a.2 | Implement Mission 3 (Clean — ACO evaporation, `ALGORITHMS.md §2.1`) | ⬜ |
| 5a.3 | Implement Mission 6 (Version) | ⬜ |
| 5a.4 | Implement Mission 7 (Track provenance) | ⬜ |
| 5a.5 | Implement Mission 11 (Cross-reference inverse relations) | ⬜ |
| 5a.6 | Implement Mission 13 (Score freshness) | ⬜ |
| 5a.7 | Implement Mission 15 (Perf Neo4j — slow query log + super-node alert) | ⬜ |
| 5a.8 | Implement Mission 16 (Snapshot — `neo4j-admin database dump` + vault tar) | ⬜ |
| 5a.9 | systemd `pi-cortex-gardener@.service` template + 3 timers | ⬜ |
| 5a.10 | flock guard against concurrent Gardener + watcher | ⬜ |

### Phase 5b — Gardener deferred missions `[OPUS NEW]`

(Run sequentially over weeks 4–12 of usage.)

| Step | Task | Status |
|------|------|--------|
| 5b.1 | Mission 1 (Validate via SearXNG) — add when ≥ 100 nodes | ⬜ |
| 5b.2 | Mission 4 (Optimize / PageRank) — requires GDS verified | ⬜ |
| 5b.3 | Mission 2 (Consolidate) | ⬜ |
| 5b.4 | Mission 5 (Detect contradictions) | ⬜ |
| 5b.5 | Mission 8 (Detect gaps) | ⬜ |
| 5b.6 | Mission 9 (Clusterise) | ⬜ |
| 5b.7 | Mission 10 (Deprecation) | ⬜ |
| 5b.8 | Mission 12 (Normalise) | ⬜ |
| 5b.9 | Mission 14 (Feedback loop) — full Strategy Learning algorithms (`§4.1–4.4`) | ⬜ |
| 5b.10 | Mission 17 (Anomaly detection) — needs 6-week baseline | ⬜ |

### Phase 6 — VM1 proxy (OPTIONAL)

| Step | Task | Status |
|------|------|--------|
| 6.1 | nginx VM1 → bzserv (only if off-Tailscale access required) | ⬜ |
| 6.2 | Cloudflare Tunnel + Cloudflare Access policy | ⬜ |
| 6.3 | Public URL test from off-Tailscale device | ⬜ |

### Phase 7 — Obsidian human interface

| Step | Task | Status |
|------|------|--------|
| 7.1 | Configure Obsidian iPhone (Remotely Save → WebDAV, conflict mode = manual) | ⬜ |
| 7.2 | Configure Obsidian Laptop | ⬜ |
| 7.3 | Populate first vault (5 global files) | ⬜ |
| 7.4 | Smoke test conflict scenario: edit same file from both devices, verify Obsidian flags conflict | ⬜ |

### Phase 8 — Observability `[OPUS NEW]`

| Step | Task | Status |
|------|------|--------|
| 8.1 | `/metrics` endpoint (Prometheus text) — counters: searches, hits, misses, evaporations, watcher events, errors | ⬜ |
| 8.2 | journald → log forwarding (existing infra) | ⬜ |
| 8.3 | Optional: Grafana dashboard (deferred but planned) | ⬜ |
| 8.4 | Health alert: Telegram alert if `/api/health` 5xx for 5 min (use existing `bzserv-electricity.env` infra) | ⬜ |

### Phase 9 — Hardening `[OPUS NEW]`

| Step | Task | Status |
|------|------|--------|
| 9.1 | Verify all binds: `ss -tlnp \| grep -E '3002\|7474\|7687'` → 127.0.0.1 only | ⬜ |
| 9.2 | Verify UFW order: `sudo ufw status numbered`, ALLOW tailscale0 before generic DENY | ⬜ |
| 9.3 | fail2ban jail for nginx WebDAV basic-auth failures | ⬜ |
| 9.4 | AIDE rule for `/opt/knowledge-vault/` and `/etc/containers/systemd/neo4j.container` | ⬜ |
| 9.5 | Auditd rules for `/home/bzn/.pi/.env` reads | ⬜ |
| 9.6 | Run end-to-end security test: confirm bzserv security score still ≥ 8.5/10 (per `~/CLAUDE.md` §4) | ⬜ |

### Phase 10 — Documentation + runbooks `[OPUS NEW]`

| Step | Task | Status |
|------|------|--------|
| 10.1 | `docs/runbooks/deploy-bzserv.md` — full clean-machine setup | ⬜ |
| 10.2 | `docs/runbooks/rotate-api-keys.md` | ⬜ |
| 10.3 | `docs/runbooks/restore-from-snapshot.md` | ⬜ |
| 10.4 | `docs/runbooks/obsidian-conflict-resolution.md` | ⬜ |
| 10.5 | Update `README.md`, `AGENT_HANDOVER.md`, `AGENTS.md` to reflect 11-phase split | ⬜ |

### Phase 11 — npm package release

| Step | Task | Status |
|------|------|--------|
| 11.1 | Finalize `package.json`, pin Pi SDK minor version | ⬜ |
| 11.2 | `npm publish` (or GitHub package registry first) | ⬜ |
| 11.3 | Test `pi install npm:@bzndevops/pi-cortex` in a fresh project | ⬜ |
| 11.4 | Document end-user `pi install` story (cf §15) | ⬜ |

---

## 12. Risks and mitigations `[OPUS REVISION — expanded]`

| # | Risk | Probability | Impact | Mitigation |
|---|------|:----------:|:------:|------------|
| R1 | Neo4j RAM overflow | Medium | High | Heap CAP via `NEO4J_server_memory_heap_max__size`, monitor via netdata, alert ≥ 80% |
| R2 | Neo4j data corruption | Low | Critical | Mission 16 monthly snapshots + daily `database dump` + Restic. **Markdown is canonical recovery source.** |
| R3 | Agent validates an error | Medium | Medium | Confidence threshold 0.8, SearXNG cross-check (Mission 1), evaporation auto-corrects |
| R4 | Obsidian ↔ API write conflict | **Medium** `[OPUS up]` | Medium | content_hash + 409 Conflict semantics; conflict scenario tested in Phase 7.4 |
| R5 | Feedback loop (agent validates own lessons) | Low | Medium | Gardener is non-Pi process — no LLM in MVP missions, no shared session state |
| R6 | WebDAV unsecured | Low `[OPUS down]` | High | Tailscale-only by default (Phase 6 is opt-in) + basic auth + fail2ban + Cloudflare Access if exposed |
| R7 | Sub-agent pollutes graph | Low | Medium | Write to `pending-review/` only; Gardener Mission 1 validates before promotion |
| R8 | VM1 proxy overload | Low | Low | nginx is light; Tailscale direct fallback; VM1 path is optional |
| R9 `[OPUS]` | **Pi SDK API drift** between minor versions | High | High | Pin `@mariozechner/pi-coding-agent` minor; CI smoke test on `pi --version` boundary; manual regression on event renames |
| R10 `[OPUS]` | **GDS plugin not installed / version-incompatible** | Medium | Medium (degrades 4 missions) | Phase 1.2 explicit; Mission 4/9 emit warning + skip if GDS missing |
| R11 `[OPUS]` | **`pi install` ergonomics for end users** (local-only, no auto-discovery from npm) | Medium | High | Phase 11 dry-run on fresh machine; runbook with explicit `mkdir .pi/extensions` step |
| R12 `[OPUS]` | **Watcher misses iOS atomic-rename WebDAV writes** | Medium | High | chokidar polling fallback; full reconciliation on startup; Mission 7 daily provenance scan |
| R13 `[OPUS]` | **Memory injection blows token budget on long user prompts** | Medium | Medium | Hard 1500-token cap; budget algorithm; observability alert if injection > 80% of cap |
| R14 `[OPUS]` | **Remotely Save Obsidian plugin breaking change** | Medium | Medium | Pin plugin minor version; document downgrade path; test before iOS app updates |
| R15 `[OPUS]` | **API key leak via `/var/log/pi-cortex/*.log`** | Low | Critical | pino redact list includes `req.headers.x-api-key`, `req.body.token`; log review in Phase 9.5 |
| R16 `[OPUS]` | **Watcher infinite loop**: API writes file → watcher detects → calls API → writes file | High during dev | High | content_hash check + write-back marker (`X-Watcher-Origin: api` skip); E2E test in Phase 2b.5 |

---

## 13. Algorithm phase mapping `[OPUS NEW]`

Maps the 15 algorithms in `ALGORITHMS.md` to a deployment phase. **Every algorithm is owned by a phase.**

| # | Algorithm | Phase | Owner module |
|---|-----------|:-----:|--------------|
| 1 | Porter-lite Stemmer | 2a.4 | `app/shared/stemmer.ts` |
| 2 | Tokenization + lexical scoring | 2a.4 | `app/shared/scorer.ts` |
| 3 | Combined scoring (lexical × pheromone) | 2a.5 | `app/api-server/search.ts` |
| 4 | Adaptive excerpt | 2a.5 | `app/shared/excerpt.ts` |
| 5 | Token budgeting | 2a.5 | `app/shared/budget.ts` |
| 6 | ACO pheromone decay | 5a.2 (write at decay), 2a.5 (read in scoring) | `app/gardener/missions/03-clean.ts` + `app/api-server/search.ts` |
| 7 | Batch flush | 2b.4 | `app/api-server/aco-batch.ts` |
| 8 | Initial seeding | 1.4 (vault populate) + 2b.5 | `app/gardener/seed.ts` |
| 9 | Category-by-lexicon detection | 2a.6 | `app/shared/router.ts` |
| 10 | Routing resolution | 2a.6 | `app/shared/router.ts` |
| 11 | Step score | 5b.9 (Mission 14) | `app/gardener/missions/14-feedback.ts` |
| 12 | Run score | 5b.9 | same |
| 13 | Strategy ACO weight | 5b.9 | same |
| 14 | Adaptive recommendation | 3.3 (extension uses recommendations from API) | `app/api-server/strategies.ts` |
| 15 | Deterministic state classifier | 3.2 (extension state machine) | `app/extension/state.ts` |

`[OPUS]` Algorithms 1–10 are **Phase 2 critical path** — they are search and routing. Algorithms 11–14 are **Phase 5b** (Strategy Learning is non-MVP). Algorithm 15 is **Phase 3** (state classifier is what `session_start` calls to know the cortex's state).

---

## 14. Observability and backups `[OPUS NEW]`

### Metrics surface (`/metrics` Prometheus text)

```
pi_cortex_searches_total{category="..."}                  Counter
pi_cortex_search_results_total{category="..."}            Counter
pi_cortex_search_misses_total                             Counter
pi_cortex_search_duration_seconds                         Histogram
pi_cortex_lessons_recorded_total{level="..."}             Counter
pi_cortex_evaporations_total                              Counter
pi_cortex_watcher_events_total{op="add|change|unlink"}    Counter
pi_cortex_watcher_errors_total                            Counter
pi_cortex_neo4j_pool_active                               Gauge
pi_cortex_neo4j_pool_idle                                 Gauge
pi_cortex_gardener_runs_total{mission="..."}              Counter
pi_cortex_gardener_errors_total{mission="..."}            Counter
pi_cortex_aco_pending_flush                               Gauge
```

Scraped (eventually) by netdata on bzserv.

### Logs

- API + watcher: pino JSON to journald (tagged `pi-cortex-api`).
- Gardener: pino JSON to journald (tagged `pi-cortex-gardener`).
- Watcher errors: also `/var/log/pi-cortex/watcher-errors.log` for fast triage.
- All sensitive fields redacted (`x-api-key`, `password`, `token`).

### Backups

| Asset | Frequency | Retention | Location |
|-------|-----------|-----------|----------|
| `/opt/knowledge-vault/` | Daily Restic | 30 days local + 12 months cold | `/mnt/wd3t/backups/` |
| Neo4j `database dump` | Daily | 14 days local + monthly to Restic | `/var/backups/neo4j/`, then Restic |
| `/home/bzn/.pi/.env` | On change | Indefinite (offline copy in password manager) | password manager |
| `/var/lib/pi-cortex/state/` | Daily Restic | 30 days | `/mnt/wd3t/backups/` |

### Alerts (Telegram via existing `bzserv-electricity.env`)

- `/api/health` 5xx for 5 min
- `pi_cortex_watcher_errors_total` increases by > 10/hour
- Gardener mission failed 3 days in a row
- Neo4j RAM > 80% of cap

---

## 15. `pi install` end-user story `[OPUS NEW]`

This section addresses Risk R11 — the gap between "we publish to npm" and "another developer types `pi install` and it works".

### Reality check (per `Pi-Cortex-Knowladge.md §4`)

`pi install npm:@bzndevops/pi-cortex` will:
- Download the package to `~/.pi/install-cache/`.
- Register the **bundled extension via `package.json` `pi.extensions` entry**.
- Register the skills and prompts.

It will **NOT**:
- Install Neo4j, the API server, or the Gardener — these are bzserv infrastructure.
- Set up nginx, WebDAV, or systemd timers.
- Provision API keys.

### What an end user gets vs. needs

| Capability | After `pi install` | Required additional setup |
|------------|:------------------:|--------------------------|
| Memory tools registered | ✅ | — |
| Hooks active | ✅ | — |
| Memory injection works | ❌ | Their own pi-cortex API or pointer to `bzserv` (not portable) |
| Skills available | ✅ | — |

`[OPUS]` **The honest pi-package value is: extension code + skills + global socle markdown.** The infrastructure stays bzserv-private. To productize for community, **Phase 11 needs a `pi-cortex up` CLI** that:

1. Bootstraps Neo4j via Podman or Docker.
2. Initializes the vault.
3. Generates API keys.
4. Starts the API server locally.

This is **Phase 12 (deferred — out of MVP scope)**. For now, document clearly in the package README that pi-cortex is "bring-your-own-Neo4j".

### V1 README block to add

```md
## Quickstart (community user)

pi-cortex requires a local pi-cortex API server (default `http://127.0.0.1:3002`).
You can self-host with `docker compose -f infra/compose.yml up` (provided in repo).

Set in `.pi/settings.json`:

  "envOverrides": {
    "PI_CORTEX_API_URL": "http://127.0.0.1:3002",
    "PI_CORTEX_API_KEY": "your-generated-key"
  }
```

### V1 docker-compose for community `[OPUS deferred to Phase 12]`

A `docker-compose.yml` and `pi-cortex-init` script reproducing the bzserv setup are explicitly **out-of-scope V1**. Tracked as backlog item.

---

## Appendix A — Files to update after this revision `[OPUS]`

| File | Change |
|------|--------|
| `PLAN.md` | Add header pointer: "See `PLAN-OPUS.md` for the execution plan." |
| `README.md` | Update phase count "8 → 11"; link to `PLAN-OPUS.md` |
| `AGENT_HANDOVER.md` | Update "Next step: Phase 1" to point to **Phase 0** of `PLAN-OPUS.md` |
| `AGENTS.md` | Add `PI_CORTEX_*_KEY` to the secrets table; add §11 (Pi extension reload recipe) cross-reference |
| `Pi-Cortex-Knowladge.md` | Cross-link to `PLAN-OPUS.md §6.4` for install recipe (avoid duplication) |

---

## Appendix B — Decisions still open `[OPUS]`

These are NOT blockers for Phase 0–4, but must be answered before the deferred phases:

1. **Embedding/vector search in Phase 11+?** Likely yes (sentence-transformers via local ollama embedding model), but evaluate after 30 days of lexical-only usage.
2. **Multi-project memory partitioning?** Currently flat `Project → HAS_KNOWLEDGE → Knowledge`. If pi-cortex spreads to 5+ projects, consider per-project Neo4j databases (Neo4j 5 supports multiple databases per instance — Community Edition allows `system` + 1 user database; for >1 user db need Enterprise).
3. **Is the Gardener allowed to call OpenRouter** (paid)? Mission 1 validate via SearXNG is free; but more advanced consolidation might want LLM. Decide budget cap.
4. **`agent-chain.ts` from `ruizrica/agent-pi`** — keep loaded ambiently, or remove from `.pi/settings.json` to keep pi-cortex baseline clean? Recommendation: remove for production tests, keep for active dev.

---

*End of `PLAN-OPUS.md` — Opus 4.7 audit revision, 2026-05-03.*
