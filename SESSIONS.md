# SESSIONS.md — pi-cortex Session Plan
> For a 125K-context local model. Each session is designed to stay under 80K tokens,
> leaving 45K breathing room for implementation loops and error logs.

---

## How to resume

```bash
# Read current session number:
python3 -c "import json; s=json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json')); print('current_session:', s.get('current_session',1), '| last_step:', s.get('last_completed_step','none'))"
```

→ Find your session number below. Follow its instructions EXACTLY.
→ Do NOT read TEST-PLAN.md in full. Use the `sed` command in each session to load only the relevant phases.
→ Do NOT read PLAN-OPUS.md in full. Read only the referenced sections.

---

## Token budget summary

| Session | Phases | Static load | Work budget | Risk |
|---------|--------|-------------|------------|------|
| S1 | 0 + 1 | ~12K | ~68K | Low |
| S2 | 2a | ~19K | ~61K | Medium |
| S3 | 2b + 3 | ~16K | ~64K | Medium-High |
| S4 | 4 + 5a | ~11K | ~69K | Medium |
| S5 | 8 + 9 + 10 + 11 + E2E | ~9K | ~71K | Low-Medium |

---

## Session 1 — Infrastructure
**Phases:** 0 (Prerequisites) + 1 (Neo4j, nginx WebDAV, UFW, backups)
**Estimated context used:** ~45K / 125K
**Dependencies:** None — this is the first session.

### Step 1 — Read reference docs (do this FIRST, in order)
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/podman-quadlet.md
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/neo4j-5x-cypher.md
```

### Step 2 — Load only Phase 0 and Phase 1 from TEST-PLAN
```bash
sed -n '1,392p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md
```
*(Lines 1–392: How to use + Phase 0 + Phase 1)*

### Step 3 — Check current state
```bash
bash /home/bzn/Projects/BzNdevOps/pi-cortex/scripts/preflight.sh 2>&1 | tail -30
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json
```

### Step 4 — Execute phases
Run all steps in Phase 0, then Phase 1, following the TEST-PLAN instructions.
Save checkpoint after each PASS. Use DEFERRED policy after 3 failed attempts.

### Step 5 — Session complete
```bash
python3 -c "
import json, datetime
f = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
with open(f) as fp: s = json.load(fp)
s['current_session'] = 2
s['session_1_completed'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open(f, 'w') as fp: json.dump(s, fp, indent=2)
print('Session 1 complete. Next: Session 2 — API Server')
"
```

---

## Session 2 — API Server Core
**Phases:** 2a (Node.js API: health, auth, search, stemmer, routing, systemd)
**Estimated context used:** ~55K / 125K
**Dependencies:** Neo4j running on 127.0.0.1:7474 ✅ (completed in Session 1)

### Step 1 — Verify dependency
```bash
curl -sf http://127.0.0.1:7474/ | python3 -c "import sys,json; print('Neo4j:', json.load(sys.stdin).get('neo4j_version','NOT RUNNING'))"
```
If Neo4j is not running: `sudo systemctl start neo4j.service` and wait 30s.

### Step 2 — Read reference docs
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/neo4j-5x-cypher.md
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/vitest.md
cat /home/bzn/Projects/BzNdevOps/pi-cortex/ALGORITHMS.md
```

### Step 3 — Load only Phase 2a from TEST-PLAN
```bash
sed -n '1,85p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md        # How to use
sed -n '393,584p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md     # Phase 2a only
```

### Step 4 — Read existing app structure
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/app/api/package.json            # existing api scaffold
ls /home/bzn/Projects/BzNdevOps/pi-cortex/app/
```

### Step 5 — Execute Phase 2a

### Step 6 — Session complete
```bash
python3 -c "
import json, datetime
f = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
with open(f) as fp: s = json.load(fp)
s['current_session'] = 3
s['session_2_completed'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open(f, 'w') as fp: json.dump(s, fp, indent=2)
print('Session 2 complete. Next: Session 3 — Watcher + Extension')
"
```

---

## Session 3 — Watcher + Pi Extension
**Phases:** 2b (chokidar watcher, write endpoints, ACO flush) + 3 (Pi extension)
**Estimated context used:** ~65K / 125K
**Dependencies:** API server running on 127.0.0.1:3002 ✅

### Step 1 — Verify dependency
```bash
curl -sf http://127.0.0.1:3002/api/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('API:', d.get('status','NOT RUNNING'))"
```
If not running: `sudo systemctl start pi-cortex-api.service`

### Step 2 — Read reference docs
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/pi-sdk.md
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/esbuild.md
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/vitest.md
```

### Step 3 — Load Phase 2b and Phase 3 from TEST-PLAN
```bash
sed -n '1,85p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md        # How to use
sed -n '585,944p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md     # Phase 2b + Phase 3
```

### Step 4 — Read the extension scaffold (already in place)
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension/src/index.ts
cat /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension/src/index.test.ts
cat /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension/package.json
```

### Step 5 — Read relevant PLAN-OPUS sections (NOT the full file)
```bash
# Pi extension spec: events, tools, token budget
sed -n '399,493p' /home/bzn/Projects/BzNdevOps/pi-cortex/PLAN-OPUS.md
```

### Step 6 — Execute Phase 2b, then Phase 3

### Step 7 — Session complete
```bash
python3 -c "
import json, datetime
f = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
with open(f) as fp: s = json.load(fp)
s['current_session'] = 4
s['session_3_completed'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open(f, 'w') as fp: json.dump(s, fp, indent=2)
print('Session 3 complete. Next: Session 4 — Skills + Gardener')
"
```

---

## Session 4 — Skills + Gardener MVP
**Phases:** 4 (6 skill files + 2 prompts) + 5a (7 Gardener missions)
**Estimated context used:** ~50K / 125K
**Dependencies:** API + Neo4j running ✅

### Step 1 — Verify dependencies
```bash
curl -sf http://127.0.0.1:3002/api/health | python3 -c "import sys,json; print('API:', json.load(sys.stdin).get('status'))"
curl -sf http://127.0.0.1:7474/ | python3 -c "import sys,json; print('Neo4j:', json.load(sys.stdin).get('neo4j_version'))"
```

### Step 2 — Read reference docs
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/neo4j-5x-cypher.md
```

### Step 3 — Load Phase 4 and Phase 5a from TEST-PLAN
```bash
sed -n '1,85p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md        # How to use
sed -n '945,1129p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md    # Phase 4 + Phase 5a
```

### Step 4 — Read Gardener Cypher specs (NOT full PLAN-OPUS)
```bash
# Gardener missions + exact Cypher for missions 3, 11, 13, 16:
sed -n '494,560p' /home/bzn/Projects/BzNdevOps/pi-cortex/PLAN-OPUS.md
```

### Step 5 — Execute Phase 4, then Phase 5a

### Step 6 — Session complete
```bash
python3 -c "
import json, datetime
f = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
with open(f) as fp: s = json.load(fp)
s['current_session'] = 5
s['session_4_completed'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open(f, 'w') as fp: json.dump(s, fp, indent=2)
print('Session 4 complete. Next: Session 5 — Hardening + Release + E2E')
"
```

---

## Session 5 — Hardening, Release, E2E
**Phases:** 8 (Observability) + 9 (Security) + 10 (Docs) + 11 (npm) + E2E
**Estimated context used:** ~45K / 125K
**Dependencies:** All services running ✅

### Step 1 — Verify all services
```bash
sudo systemctl is-active neo4j.service pi-cortex-api.service pi-cortex-gardener-daily.timer
curl -sf http://127.0.0.1:3002/api/health
curl -sf http://127.0.0.1:7474/
```

### Step 2 — No extra reference docs needed for these phases
```bash
# Optional — only if fail2ban step fails:
# cat /home/bzn/Projects/BzNdevOps/pi-cortex/reference/docs/podman-quadlet.md
```

### Step 3 — Load Phases 8–E2E from TEST-PLAN
```bash
sed -n '1,85p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md        # How to use
sed -n '1130,1522p' /home/bzn/Projects/BzNdevOps/pi-cortex/TEST-PLAN.md   # Phase 8 → E2E
```

### Step 4 — Execute Phase 8, 9, 10, 11, E2E in order

### Step 5 — Project complete
```bash
python3 -c "
import json, datetime
f = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
with open(f) as fp: s = json.load(fp)
s['current_session'] = 'COMPLETE'
s['project_completed'] = datetime.datetime.utcnow().isoformat() + 'Z'
with open(f, 'w') as fp: json.dump(s, fp, indent=2)
print('ALL SESSIONS COMPLETE')
"

printf "[pi-cortex] 🚀 PROJET TERMINÉ — E2E PASS\n5 sessions complètes." \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] DONE"
```

---

## If a session crashes mid-way

```bash
# Read where you left off:
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json

# Re-run from last_completed_step — do NOT restart the session from scratch.
# Re-read ONLY the docs for the current phase (not the full session doc list).
# The DEFERRED policy is in effect — after 3 failures, move on.
```

## Probability gain from this session plan

| Without sessions | With 5 sessions |
|-----------------|----------------|
| ~8% full success | ~18% full success |
| ~30% MVP | ~50% MVP |
| Context collapse at Phase 3–4 | Clean context per session |
