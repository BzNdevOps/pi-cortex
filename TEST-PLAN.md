# pi-cortex — Test Plan (Autonomous Coding Loop)

> **Date:** 2026-05-03
> **Source plan:** `PLAN-OPUS.md` (Opus 4.7 revision)
> **Model:** Designed for autonomous Pi agent — each step has exactly one runnable test, a PASS condition, and FAIL hints.

---

## How to use this file

The agent follows this loop for every step:

```
FOR each step in this file (in order):
  WHILE step is not PASS:
    1. Read step Goal + PLAN-OPUS.md reference
    2. Implement / fix
    3. Run the Test command
    4. If output matches PASS → mark ✅ → update session-state.json → advance
    5. Else → read FAIL hints → go back to step 2
  END
END
```

**Rules:**
- Never skip a step unless it is marked `[OPTIONAL]`.
- Never mark a step PASS without running its exact test command.
- If a step stays FAIL after 3 coding attempts → write to `.context/blocked-steps.json`, mark `[DEFERRED]`, continue to the next independent step.
- Steps marked `[OPTIONAL]` may be skipped for MVP.

**After each PASS — update checkpoint:**
```bash
python3 -c "
import json, datetime, sys
STATE_FILE = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'
step = sys.argv[1]
try:
    with open(STATE_FILE) as f: state = json.load(f)
except: state = {}
state['last_completed_step'] = step
state['ts'] = datetime.datetime.utcnow().isoformat() + 'Z'
state['\$schema'] = 'session-state-v2'
with open(STATE_FILE, 'w') as f: json.dump(state, f, indent=2)
print('checkpoint saved:', step)
" "<STEP_ID>"
```
Replace `<STEP_ID>` with the step number (e.g. `"0.2"`, `"1.1"`, `"2a.3"`).

**When BLOCKED (after 3 attempts):**
```bash
python3 -c "
import json, datetime, sys
BLOCKED_FILE = '/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'
step, reason = sys.argv[1], sys.argv[2]
try:
    with open(BLOCKED_FILE) as f: blocked = json.load(f)
except: blocked = []
blocked.append({'step': step, 'reason': reason, 'ts': datetime.datetime.utcnow().isoformat()+'Z'})
with open(BLOCKED_FILE, 'w') as f: json.dump(blocked, f, indent=2)
print('blocked step recorded:', step)
" "<STEP_ID>" "<reason>"
```
Then continue to the next independent step.

**At the end of each phase — Telegram notification (MANDATORY):**

After the git commit, send a progress report to Telegram using the existing `/usr/local/bin/bzserv-telegram-send` script. The message must include: phase name, list of completed steps, what was built, and any blocked steps.

```bash
BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    phase_blocked = [x['step'] for x in b if x['step'].startswith('<PHASE_PREFIX>')]
    print('Blocked: ' + ', '.join(phase_blocked) if phase_blocked else 'None blocked')
except: print('None blocked')
")
printf "pi-cortex Phase <N> complete ✅\n\nSteps done: <LIST>\nWhat was built: <SUMMARY>\n%s\nNext: Phase <N+1>" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase <N> done"
```

Replace `<N>`, `<PHASE_PREFIX>`, `<LIST>`, `<SUMMARY>` with the actual phase values at each phase end. See the per-phase Telegram blocks below for the exact pre-filled commands.

---

## Phase 0 — Prerequisites

### Step 0.1 — API keys generated
> **Goal:** Three `PI_CORTEX_*_KEY` tokens are in `/home/bzn/.pi/.env`, chmod 600.
> **Ref:** PLAN-OPUS.md §5.3

```bash
stat -c "%a" /home/bzn/.pi/.env && \
  grep -cP '^PI_CORTEX_(AGENT|GARDENER|SUBAGENT)_KEY=sk-cortex-\w{32,}' /home/bzn/.pi/.env
```

**PASS:** First line is `600`, second line is `3`
**FAIL hints:**
- If file missing: `touch /home/bzn/.pi/.env && chmod 600 /home/bzn/.pi/.env` then generate keys with `openssl rand -hex 32`
- If wrong perms: `chmod 600 /home/bzn/.pi/.env`
- If count < 3: generate missing keys with `echo "PI_CORTEX_AGENT_KEY=sk-cortex-agent-$(openssl rand -hex 32)" >> /home/bzn/.pi/.env`

---

### Step 0.2 — Java 21 present
> **Goal:** Java 21+ is available on bzserv (required by Neo4j 5.x).
> **Ref:** PLAN-OPUS.md §3

```bash
java -version 2>&1 | grep -oP '(\d+)\.' | head -1 | tr -d '.'
```

**PASS:** Output is `21` or higher
**FAIL hints:**
- `sudo apt install openjdk-21-jre-headless`
- Or set `JAVA_HOME` if multiple JVMs installed

---

### Step 0.3 — nginx-extras available
> **Goal:** `nginx-extras` (includes WebDAV modules) is available in apt.
> **Ref:** PLAN-OPUS.md §8

```bash
apt-cache show nginx-extras 2>/dev/null | grep -c "Package: nginx-extras"
```

**PASS:** `1`
**FAIL hints:**
- `sudo apt update`
- If still missing: `nginx-full` also includes WebDAV — check `apt-cache show nginx-full | grep dav`

---

### Step 0.4 — Tailscale TLS certificate present
> **Goal:** A TLS cert for `bzserv.tail011919.ts.net` exists for nginx WebDAV.
> **Ref:** PLAN-OPUS.md §8

```bash
openssl x509 -noout -subject -in /etc/ssl/certs/bzserv-tailscale.crt 2>/dev/null | grep -i tail
```

**PASS:** Output contains `tail011919` or `bzserv`
**FAIL hints:**
- Generate: `sudo tailscale cert bzserv.tail011919.ts.net`
- Cert lands in `/var/lib/tailscale/certs/` — copy to `/etc/ssl/`
- If Tailscale MagicDNS not enabled: enable it in Tailscale admin console

---

### Step 0.5 — Node.js 22+ present
> **Goal:** Node.js 22+ available for API server and Gardener.
> **Ref:** PLAN-OPUS.md §5.6

```bash
node --version | grep -oP 'v(\d+)' | grep -oP '\d+' | awk '$1 >= 22 {print "OK"}'
```

**PASS:** `OK`
**FAIL hints:**
- Install via `nvm install 22` or `sudo apt install nodejs` from NodeSource PPA
- `curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs`

---

### Step 0.6 — Pi version pinned in package.json
> **Goal:** `app/extension/package.json` pins `@mariozechner/pi-coding-agent` minor version.
> **Ref:** PLAN-OPUS.md §10, Risk R9

```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension/package.json 2>/dev/null \
  | grep -P '"@mariozechner/pi-coding-agent":\s*"\^0\.\d+\.'
```

**PASS:** Line containing `^0.X.` (pinned minor)
**FAIL hints:**
- File may not exist yet — create it in Phase 3.1; revisit this step then
- If exists but unpinned: change `"*"` to `"^0.6.0"` (current known-good minor)

---

### Step 0.7 — ALGORITHMS.md contains all 15 algorithms
> **Goal:** The 15 algorithms referenced throughout the plan are documented in ALGORITHMS.md.
> **Ref:** PLAN-OPUS.md §13 (Algorithm phase mapping)

```bash
grep -c "^## " /home/bzn/Projects/BzNdevOps/pi-cortex/ALGORITHMS.md
```

**PASS:** `15` or more
**FAIL hints:**
- Open ALGORITHMS.md and check which sections are missing vs. PLAN-OPUS.md §13
- Each algorithm must have at minimum: a section header, input/output description, pseudocode or formula
- Required sections: Porter-lite Stemmer (§1.1), Tokenization+lexical scoring (§1.2), Combined scoring (§1.3), Adaptive excerpt (§1.4), Token budgeting (§1.5), ACO pheromone decay (§2.1), Batch flush (§2.2), Initial seeding (§2.3), Category-by-lexicon detection (§3.1), Routing resolution (§3.2), Step score (§4.1), Run score (§4.2), Strategy ACO weight (§4.3), Adaptive recommendation (§4.4), Deterministic state classifier (§5.1)

---

### Phase 0 complete — notify
```bash
BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('0.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 0 — Prérequis ✅\n\nEnvironnement vérifié:\n• Node.js 22+, Java 21+, podman, nginx-extras, openssl\n• /opt/knowledge-vault writable, /etc/systemd writable\n• PI_CORTEX_*_KEY générées dans /home/bzn/.pi/.env (chmod 600)\n• ALGORITHMS.md: 15 algos documentés\n• Pi SDK version pinned\n\n%s\n\nNext: Phase 1 — Infrastructure Neo4j" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 0 done ✅"
```

---

## Phase 1 — Infrastructure (bzserv)

### Step 1.1 — Neo4j container running
> **Goal:** Neo4j Community 5.x is deployed via Podman Quadlet, HTTP accessible on `127.0.0.1:7474`.
> **Ref:** PLAN-OPUS.md §11 Phase 1.1

```bash
curl -sf http://127.0.0.1:7474/ | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('neo4j_version',''))" 2>/dev/null | grep -oP '^\d+'
```

**PASS:** `5` (Neo4j major version 5)
**FAIL hints:**
- Check Quadlet file: `cat /etc/containers/systemd/neo4j.container`
- `sudo systemctl daemon-reload && sudo systemctl start neo4j`
- Check logs: `sudo podman logs neo4j --tail 50`
- Bind must be `127.0.0.1` — verify in Quadlet `Environment=NEO4J_server_http_listen__address=127.0.0.1:7474`
- Memory: set `NEO4J_server_memory_heap_max__size=2G` in Quadlet

---

### Step 1.2 — APOC + GDS plugins loaded
> **Goal:** APOC Core and GDS Community are installed and recognized by Neo4j.
> **Ref:** PLAN-OPUS.md §11 Phase 1.2, Risk R10

```bash
NEO4J_PASS=$(grep NEO4J_PASSWORD /home/bzn/.pi/.env | cut -d= -f2)
curl -sf -u "neo4j:${NEO4J_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"statements":[{"statement":"RETURN apoc.version() AS apoc, gds.version() AS gds"}]}' \
  http://127.0.0.1:7474/db/neo4j/tx/commit \
  | python3 -c "import sys,json; r=json.load(sys.stdin); d=r['results'][0]['data'][0]['row']; print('apoc:',d[0],'gds:',d[1])"
```

**PASS:** `apoc: X.X.X gds: X.X.X` (both non-null, no `errors` key in response)
**FAIL hints:**
- APOC: Download `apoc-X.X-core.jar` matching Neo4j version → `/var/lib/containers/storage/volumes/neo4j-plugins/_data/`
- GDS: Download `neo4j-graph-data-science-X.X.X.jar` → same path
- Restart: `sudo systemctl restart neo4j`
- If GDS missing: Gardener missions 4 and 9 will degrade gracefully — do NOT block on GDS if download fails; log warning

---

### Step 1.3 — Neo4j constraints and indexes created
> **Goal:** All constraints and full-text indexes from PLAN-OPUS.md §4 are present.
> **Ref:** PLAN-OPUS.md §4

```bash
NEO4J_PASS=$(grep NEO4J_PASSWORD /home/bzn/.pi/.env | cut -d= -f2)
curl -sf -u "neo4j:${NEO4J_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"statements":[{"statement":"SHOW CONSTRAINTS YIELD name RETURN count(*) AS n"}]}' \
  http://127.0.0.1:7474/db/neo4j/tx/commit \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['results'][0]['data'][0]['row'][0])"
```

**PASS:** `2` or more (knowledge_id_unique + category_name_unique)
**FAIL hints:**
- Run the Cypher block from PLAN-OPUS.md §4 (indexes + constraints)
- Full-text index can be checked separately: `SHOW INDEXES YIELD name WHERE name = 'knowledge_search' RETURN name`

---

### Step 1.4 — Vault directory structure created
> **Goal:** `/opt/knowledge-vault/` and `/var/lib/pi-cortex/state/` exist with correct ownership.
> **Ref:** PLAN-OPUS.md §11 Phase 1.4

```bash
ls -la /opt/knowledge-vault/ | grep -cE '^d.*\s(global|project|pending-review)$' && \
ls -d /var/lib/pi-cortex/state/ 2>/dev/null && echo "state_ok"
```

**PASS:** First line is `3`, second line is `state_ok`
**FAIL hints:**
- `sudo mkdir -p /opt/knowledge-vault/{global,project,pending-review,.obsidian}`
- `sudo mkdir -p /var/lib/pi-cortex/state`
- `sudo chown -R bzn:bzn /opt/knowledge-vault /var/lib/pi-cortex`

---

### Step 1.5 — nginx WebDAV responding on Tailscale
> **Goal:** nginx serves WebDAV at `https://bzserv.tail011919.ts.net/knowledge/` with basic auth.
> **Ref:** PLAN-OPUS.md §8

```bash
WEBDAV_PASS=$(sudo grep -oP '(?<=bzn:)\S+' /etc/nginx/.htpasswd-knowledge 2>/dev/null || echo "MISSING")
curl -sf -u "bzn:${WEBDAV_PASS}" \
  -X PROPFIND \
  --resolve "bzserv.tail011919.ts.net:443:100.64.144.126" \
  https://bzserv.tail011919.ts.net/knowledge/ \
  -o /dev/null -w "%{http_code}"
```

**PASS:** `207` (Multi-Status — WebDAV PROPFIND success)
**FAIL hints:**
- Check nginx config: `sudo nginx -t`
- Check WebDAV module loaded: `nginx -V 2>&1 | grep dav`
- Create htpasswd: `sudo htpasswd -c /etc/nginx/.htpasswd-knowledge bzn`
- If cert error: ensure `ssl_certificate` path in nginx config matches `/etc/ssl/certs/bzserv-tailscale.crt`
- `sudo systemctl reload nginx`

---

### Step 1.6 — UFW rules correct order (Tailscale before DENY)
> **Goal:** `ALLOW on tailscale0` rules for port 443 appear before any generic DENY in UFW.
> **Ref:** PLAN-OPUS.md §11 Phase 1.6, AGENTS.md security rules

```bash
ALLOW_NUM=$(sudo ufw status numbered 2>/dev/null | grep -P 'ALLOW.*tailscale0|tailscale0.*ALLOW' | grep -oP '^\[\s*\K\d+' | head -1)
DENY_NUM=$(sudo ufw status numbered 2>/dev/null | grep -P 'DENY' | grep -oP '^\[\s*\K\d+' | head -1)
[ -n "$ALLOW_NUM" ] && [ -n "$DENY_NUM" ] && [ "$ALLOW_NUM" -lt "$DENY_NUM" ] && echo "ORDER_CORRECT allow[$ALLOW_NUM]<deny[$DENY_NUM]" || echo "RECHECK: allow=${ALLOW_NUM:-missing} deny=${DENY_NUM:-missing}"
```

**PASS:** `ORDER_CORRECT allow[N]<deny[M]` where N < M
**FAIL hints:**
- Check full order: `sudo ufw status numbered`
- If ALLOW missing: `sudo ufw insert 1 allow in on tailscale0 to 100.64.144.126 port 443`
- If wrong order: `sudo ufw delete <deny_rule_number>` then `sudo ufw insert 1 allow in on tailscale0`
- NEVER use `ufw delete` on existing ALLOW rules without checking order first
- If `ALLOW_NUM` is missing: Tailscale rule doesn't exist — **STOP, add it before any DENY rules**

---

### Step 1.7 — Restic backup for vault configured
> **Goal:** Daily Restic backup is scheduled for `/opt/knowledge-vault/`.
> **Ref:** PLAN-OPUS.md §14

```bash
sudo crontab -l | grep -c "restic.*knowledge-vault"
```

**PASS:** `1` or more
**FAIL hints:**
- Add cron: `0 3 * * * /usr/bin/restic -r /mnt/wd3t/backups/knowledge-vault backup /opt/knowledge-vault 2>&1 | systemd-cat -t restic-knowledge`
- Test backup now: `sudo restic -r /mnt/wd3t/backups/knowledge-vault init` (first time)
- Verify password matches `/etc/restic-password`

---

### Step 1.8 — Neo4j dump cron configured
> **Goal:** Daily `neo4j-admin database dump` is scheduled with Restic.
> **Ref:** PLAN-OPUS.md §14

```bash
sudo crontab -l | grep -c "neo4j-admin"
```

**PASS:** `1` or more
**FAIL hints:**
- Add: `30 2 * * * sudo podman exec neo4j neo4j-admin database dump neo4j --to-path=/var/backups/neo4j/ && /usr/bin/restic -r /mnt/wd3t/backups/neo4j backup /var/backups/neo4j`
- `sudo mkdir -p /var/backups/neo4j && sudo chown bzn:bzn /var/backups/neo4j`

---

### Phase 1 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 1 complete — Neo4j, vault, nginx WebDAV, backups"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('1.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 1 — Infrastructure ✅\n\nSteps done:\n• 1.1 Neo4j Community 5.x (Podman Quadlet, 127.0.0.1:7474/7687)\n• 1.2 APOC + GDS plugins\n• 1.3 Cypher constraints + full-text index\n• 1.4 /opt/knowledge-vault/ + /var/lib/pi-cortex/state/\n• 1.5 nginx WebDAV (Tailscale TLS, basic auth)\n• 1.6 UFW rules (tailscale0 ALLOW < DENY)\n• 1.7 Restic cron — knowledge-vault daily\n• 1.8 neo4j-admin dump cron daily\n\n%s\n\nNext: Phase 2a — API Server core" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 1 done 🗄️"
```

---

## Phase 2a — API Server Core

### Step 2a.1 — Node.js project initialized
> **Goal:** `app/api-server/` has a valid TypeScript project with required dependencies.
> **Ref:** PLAN-OPUS.md §5.6

```bash
node -e "const p=require('/home/bzn/Projects/BzNdevOps/pi-cortex/app/api-server/package.json'); \
  const deps=Object.keys({...p.dependencies,...p.devDependencies}); \
  const required=['neo4j-driver','express','chokidar','gray-matter','pino','zod']; \
  const missing=required.filter(d=>!deps.includes(d)); \
  console.log(missing.length===0?'OK':'MISSING:'+missing.join(','))"
```

**PASS:** `OK`
**FAIL hints:**
- `cd app/api-server && npm init -y`
- `npm install neo4j-driver express chokidar gray-matter pino zod`
- `npm install -D typescript ts-node @types/node @types/express esbuild vitest`
- Add to `package.json`: `"test": "vitest run"` (vitest is the required test framework — not mocha, not jest)
- `npm test -- --reporter verbose` for detailed output

---

### Step 2a.2 — API server starts and health endpoint responds
> **Goal:** `GET /api/health` returns a valid JSON health object.
> **Ref:** PLAN-OPUS.md §5.1

```bash
source /home/bzn/.pi/.env
curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" http://127.0.0.1:3002/api/health \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    assert 'total_nodes' in d and 'status' in d, 'missing fields'; print('OK')"
```

**PASS:** `OK`
**FAIL hints:**
- Start server manually: `cd app/api-server && npm start`
- Check port: `ss -tlnp | grep 3002`
- Check Neo4j reachable from API: `curl -sf http://127.0.0.1:7474/`
- Check `.env` loaded: add `dotenv` and `require('dotenv').config({path:'/home/bzn/.pi/.env'})`

---

### Step 2a.3 — Auth middleware enforced (401 without key)
> **Goal:** API rejects requests without `X-API-Key`, accepts valid keys.
> **Ref:** PLAN-OPUS.md §5.3

```bash
NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3002/api/health)
source /home/bzn/.pi/.env
WITH_AUTH=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" http://127.0.0.1:3002/api/health)
echo "${NO_AUTH} ${WITH_AUTH}"
```

**PASS:** `401 200`
**FAIL hints:**
- Implement auth middleware before all routes: `app.use((req,res,next)=>{ if(!validKey(req.header('X-API-Key'))) return res.status(401).json({error:'unauthorized'}); next(); })`
- Public routes (only `/metrics` for Prometheus scraping): exclude from auth

---

### Step 2a.4 — Stemmer unit tests pass
> **Goal:** Porter-lite stemmer (ALGORITHMS.md §1.1) implemented and tested.
> **Ref:** PLAN-OPUS.md §13 Algorithm 1

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/api-server && npm test -- --grep stemmer 2>&1 | tail -3
```

**PASS:** Last lines contain `passing` with count ≥ 5, zero `failing`
**FAIL hints:**
- Implement `app/shared/stemmer.ts` using the exact rules from ALGORITHMS.md §1.1
- Test cases: `architectural→architect`, `decisions→decision`, `running→runn`, `optimizations→optimiz`
- Use `mocha` or `vitest` for tests

---

### Step 2a.5 — Search endpoint returns scored results
> **Goal:** `GET /api/search?q=architecture` returns ranked results from Neo4j.
> **Ref:** PLAN-OPUS.md §5.1, ALGORITHMS.md §1.2, §1.3

```bash
source /home/bzn/.pi/.env
# First seed a test node
curl -sf -X POST http://127.0.0.1:3002/api/knowledge \
  -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"id":"test/01-arch-test","title":"Architecture Test","content":"This is an architecture pattern test document.","category":"architecture","status":"active","confidence":0.9}' \
  > /dev/null
# Then search
curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/search?q=architecture+pattern&top_k=5" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    assert len(d.get('results',[]))>0,'no results'; \
    assert 'score' in d['results'][0],'missing score'; \
    print('results:',len(d['results']),'top_score:',round(d['results'][0]['score'],2))"
```

**PASS:** `results: 1 top_score: 0.XX` (score > 0)
**FAIL hints:**
- Verify test node was created: `GET /api/knowledge/test/01-arch-test`
- Implement lexical scoring per ALGORITHMS.md §1.2 (tokenize + score_section)
- Combined scoring (§1.3): `lexical * (1.0 + pheromone)`
- Clean up test node after: `DELETE /api/knowledge/test/01-arch-test`

---

### Step 2a.6 — Category routing works
> **Goal:** Search with category auto-detection routes to the right category.
> **Ref:** PLAN-OPUS.md §5.1, ALGORITHMS.md §3.1, §3.2

```bash
source /home/bzn/.pi/.env
curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/search?q=never+expose+port+security+guardrail" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    cats=d.get('detected_categories',[]); \
    assert 'guardrails' in cats or 'architecture' in cats, f'wrong cats: {cats}'; \
    print('routing_mode:',d.get('routing_mode'),'cats:',cats)"
```

**PASS:** `routing_mode: auto cats: ['guardrails']` (or includes guardrails/architecture)
**FAIL hints:**
- Implement `_RAW_LEXICON` from ALGORITHMS.md §3.1 with all 9 categories
- Implement `resolve_routing()` from §3.2 with `DEFAULT_CONFIDENCE_THRESHOLD = 0.3`
- If threshold too high → falls back to global (all categories) — log `routing_mode: fallback-global`

---

### Step 2a.7 — API systemd service runs
> **Goal:** `pi-cortex-api.service` is active and survives a restart.
> **Ref:** PLAN-OPUS.md §11 Phase 2a.8

```bash
sudo systemctl restart pi-cortex-api && sleep 3 && \
systemctl is-active pi-cortex-api
```

**PASS:** `active`
**FAIL hints:**
- Create `/etc/systemd/system/pi-cortex-api.service`:
  ```ini
  [Unit]
  Description=pi-cortex API server
  After=neo4j.service
  Requires=neo4j.service

  [Service]
  Type=simple
  User=bzn
  WorkingDirectory=/home/bzn/Projects/BzNdevOps/pi-cortex/app/api-server
  EnvironmentFile=/home/bzn/.pi/.env
  ExecStart=/usr/bin/node dist/server.js
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
  ```
- `sudo systemctl daemon-reload && sudo systemctl enable pi-cortex-api`
- Check logs: `journalctl -u pi-cortex-api -n 30`

---

### Phase 2a complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 2a complete — API server core, auth, search, category routing"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('2a.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 2a — API Server Core ✅\n\nSteps done:\n• 2a.1 Node.js/TypeScript project (neo4j-driver, express, pino, zod, vitest)\n• 2a.2 Health endpoint + neo4j-driver pool (maxPool=50)\n• 2a.3 Auth middleware (X-API-Key, 401 without key)\n• 2a.4 Porter-lite stemmer + lexical scoring\n• 2a.5 Combined scoring + excerpt + token budgeting\n• 2a.6 Category routing (9 categories, resolve_routing)\n• 2a.7 pi-cortex-api.service systemd unit active\n\n%s\n\nNext: Phase 2b — Watcher + write endpoints" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 2a done 🔌"
```

---

## Phase 2b — Watcher + Write Endpoints

### Step 2b.1 — Watcher detects new vault file and syncs to Neo4j
> **Goal:** A new `.md` file in the vault is detected by chokidar and upserted to Neo4j within 3 seconds.
> **Ref:** PLAN-OPUS.md §5.5

```bash
source /home/bzn/.pi/.env
# Write a test .md to the vault
TEST_FILE="/opt/knowledge-vault/project/watcher-test-$(date +%s).md"
cat > "$TEST_FILE" << 'MDEOF'
---
id: project/watcher-test
title: Watcher Test Node
category: architecture
status: active
confidence: 0.8
source_agent: test
created_at: 2026-05-03T00:00:00Z
updated_at: 2026-05-03T00:00:00Z
version_id: 1
---

# Watcher Test

This node verifies the chokidar watcher is working.
MDEOF

# Wait for debounce + sync
sleep 3

# Query Neo4j via API
RESULT=$(curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/project/watcher-test" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title','NOT_FOUND'))")

# Cleanup
rm -f "$TEST_FILE"
curl -sf -X DELETE -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/project/watcher-test" > /dev/null 2>&1

echo "$RESULT"
```

**PASS:** `Watcher Test Node`
**FAIL hints:**
- Check watcher is running: `journalctl -u pi-cortex-api -n 20 | grep watcher`
- Verify chokidar polling mode: `usePolling: true, interval: 1000`
- Check frontmatter parser: `gray-matter` must handle the YAML block
- Verify `content_hash` is computed correctly (SHA256 of body after frontmatter)
- Watcher errors: `cat /var/log/pi-cortex/watcher-errors.log`

---

### Step 2b.2 — Full vault reconciliation on startup
> **Goal:** All `.md` files in vault are synced to Neo4j when the API starts.
> **Ref:** PLAN-OPUS.md §5.5

```bash
source /home/bzn/.pi/.env
# Populate vault with 5 global knowledge files first
# (assumes files exist from Phase 1.4 or are about to be created)
GLOBAL_COUNT=$(ls /opt/knowledge-vault/global/*.md 2>/dev/null | wc -l)
if [ "$GLOBAL_COUNT" -eq 0 ]; then
  echo "SKIP: no vault files yet — populate vault first (Step 7.3)"
  exit 0
fi
sudo systemctl restart pi-cortex-api && sleep 5
NEO4J_COUNT=$(curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  http://127.0.0.1:3002/api/health \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_nodes',0))")
echo "vault_files:${GLOBAL_COUNT} neo4j_nodes:${NEO4J_COUNT}"
```

**PASS:** `vault_files:N neo4j_nodes:M` where `M >= N` (all vault files ingested)
**FAIL hints:**
- Reconciliation runs at startup — check logs: `journalctl -u pi-cortex-api -n 50 | grep reconcil`
- If M < N: some files have invalid frontmatter — check `watcher-errors.log`
- Verify all 5 global files have valid frontmatter schema per PLAN-OPUS.md §4

---

### Step 2b.3 — POST /api/lesson creates a draft node
> **Goal:** Agents can submit a new lesson that lands as a `draft` Knowledge node.
> **Ref:** PLAN-OPUS.md §5.2

```bash
source /home/bzn/.pi/.env
RESP=$(curl -sf -X POST http://127.0.0.1:3002/api/lesson \
  -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"content":"Always use chokidar polling on WebDAV-synced filesystems.","project":"pi-cortex","category":"best-practices"}')
ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
STATUS=$(curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/${ID}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
# Cleanup
curl -sf -X DELETE -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/${ID}" > /dev/null 2>&1
echo "$STATUS"
```

**PASS:** `draft`
**FAIL hints:**
- `POST /api/lesson` must create node with `status=draft` (never `active` — Gardener promotes)
- `id` must be auto-generated (e.g. `project/pending-review/UUID`)
- Verify node also written to `/opt/knowledge-vault/pending-review/`

---

### Step 2b.4 — 409 Conflict returned on hash mismatch write
> **Goal:** `POST /api/knowledge` returns 409 when the vault file has changed since the agent's last read.
> **Ref:** PLAN-OPUS.md §4 (conflict policy)

```bash
source /home/bzn/.pi/.env
# Create a node
curl -sf -X POST http://127.0.0.1:3002/api/knowledge \
  -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"id":"test/conflict-test","title":"Conflict Test","content":"original","category":"architecture","status":"active","confidence":0.9,"content_hash":"WRONG_HASH_SIMULATING_STALE"}' \
  -o /dev/null -w "%{http_code}"
# Clean up
curl -sf -X DELETE -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/test/conflict-test" > /dev/null 2>&1
```

**PASS:** `409`
**FAIL hints:**
- API must compare `content_hash` from request body with stored hash in Neo4j
- On mismatch: return `409 Conflict` with body `{"error":"conflict","current_content":"...","current_hash":"..."}`
- On first creation (node doesn't exist): `content_hash` check is skipped — return 201

---

### Step 2b.5 — ACO batch flush (10 reinforcements trigger write)
> **Goal:** Reinforcement accumulates in memory and flushes to Neo4j every 10 ops (ALGORITHMS.md §2.2).
> **Ref:** PLAN-OPUS.md §13 Algorithm 7

```bash
source /home/bzn/.pi/.env
# Create a test knowledge node
curl -sf -X POST http://127.0.0.1:3002/api/knowledge \
  -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"id":"test/aco-test","title":"ACO Test","content":"ACO test node.","category":"architecture","status":"active","confidence":0.9}' > /dev/null

# Send 10 reinforcements
for i in $(seq 1 10); do
  curl -sf -X POST http://127.0.0.1:3002/api/graph/reinforce \
    -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"id":"test/aco-test"}' > /dev/null
done

sleep 1
# Check uses was incremented
USES=$(curl -sf -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/test/aco-test" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('uses',0))")

# Cleanup
curl -sf -X DELETE -H "X-API-Key: ${PI_CORTEX_AGENT_KEY}" \
  "http://127.0.0.1:3002/api/knowledge/test/aco-test" > /dev/null 2>&1

echo "uses:$USES"
```

**PASS:** `uses:10` (all 10 increments flushed and persisted)
**FAIL hints:**
- Implement in-memory `_weight_dirty` map + `_weight_op_count`
- Flush at 10 ops: write to Neo4j, reset counter
- Also register `atexit` (process `SIGTERM` handler) for final flush
- Uses must be on the `Knowledge` node, not just on edges

---

### Phase 2b complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 2b complete — watcher, write endpoints, ACO batch, conflict resolution"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('2b.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 2b — Watcher + Write Endpoints ✅\n\nSteps done:\n• 2b.1 chokidar watcher (polling 1s, debounce 500ms, frontmatter parse)\n• 2b.2 Full vault reconciliation on startup\n• 2b.3 Write endpoints (POST /api/knowledge, /lesson, /reinforce, 409 conflict)\n• 2b.4 ACO batch flush (10 ops, SIGTERM handler)\n• 2b.5 Integration tests (watcher round-trip)\n\n%s\n\nNext: Phase 3 — Pi extension" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 2b done 👁️"
```

---

## Phase 3 — Pi Extension

### Step 3.1 — Extension builds without errors
> **Goal:** TypeScript extension compiles to `.pi/extensions/pi-cortex/index.ts` (esbuild bundle).
> **Ref:** PLAN-OPUS.md §6.4, §11 Phase 3.1

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex && \
npm run build:extension 2>&1 | tail -5 && \
ls -la .pi/extensions/pi-cortex/index.ts
```

**PASS:** Build output ends without `error`, and `index.ts` file exists and is > 1 KB
**FAIL hints:**
- Build script: `"build:extension": "esbuild app/extension/src/index.ts --bundle --platform=node --outfile=.pi/extensions/pi-cortex/index.ts"`
- esbuild preserves `.ts` extension: `--out-extension:.js=.ts` (Pi expects `.ts`)
- If import errors: check all imports use relative paths or bundled deps
- If Pi SDK import fails: esbuild external `--external:@mariozechner/pi-coding-agent`

---

### Step 3.2 — Pi discovers and loads the extension
> **Goal:** Extension file is in the correct location and `settings.json` has no broken paths.
> **Ref:** PLAN-OPUS.md §6.4 (auto-discovery), Pi-Cortex-Knowladge.md §4

```bash
# Verify extension file exists and settings.json has no broken relative paths
ls /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/pi-cortex/index.ts && \
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/settings.json \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
ext = d.get('extensions', [])
broken = [e for e in ext if e.startswith('../') or e.startswith('./')]
print('BROKEN:' + ','.join(broken) if broken else 'OK')
"
```

**PASS:** `OK` (file exists and no broken relative paths in settings)
**FAIL hints:**
- `.pi/settings.json` must NOT have relative paths like `"../app/extension/index.ts"` — these break silently
- Use auto-discovery (empty `extensions: []`) or absolute path: `"/home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/pi-cortex/index.ts"`
- If extension crashes on load: `journalctl --user -n 20` or check Pi stderr for TypeScript errors

**Note:** Live `/reload` verification inside Pi is optional (requires interactive terminal). The automated test above confirms the file is in place and settings are correct — that is the PASS condition for the autonomous loop.

---

### Step 3.3 — Memory injection hook fires with token cap
> **Goal:** `context` hook injects memory block into system prompt, respects 1500-token cap, 800ms timeout.
> **Ref:** PLAN-OPUS.md §6.3

```bash
# Unit test: verify injection logic returns max 1500 tokens
cd /home/bzn/Projects/BzNdevOps/pi-cortex && \
npm test -- --grep "context.*injection|token.*cap|injection.*budget" 2>&1 | tail -5
```

**PASS:** `passing` with count ≥ 1, zero `failing`
**FAIL hints:**
- Test should verify: if API returns 2000 tokens worth of results, injection is truncated to 1500
- Test should verify: on 800ms timeout, injection is silently skipped (no throw)
- Test should verify: on API 5xx, injection is silently skipped
- Use `AbortSignal.timeout(800)` — not `setTimeout`

---

### Step 3.4 — Tool registration: all 7 memory tools present
> **Goal:** The extension registers all 7 `memory_*` tools via `pi.registerTool()`.
> **Ref:** PLAN-OPUS.md §6.1

```bash
grep -c "registerTool" /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension/src/index.ts
```

**PASS:** `7`
**FAIL hints:**
- Required tools: `memory_search`, `memory_search_routed`, `memory_get`, `memory_record_lesson`, `memory_get_graph`, `memory_status`, `memory_feedback`
- Use `@sinclair/typebox` `Type.*` for parameter schemas (Pi SDK requirement)
- Copy pattern from `reference/extensions/memory-cycle/index.ts`

---

### Step 3.5 — Guardrail hook blocks dangerous patterns
> **Goal:** `tool_call` hook blocks known-dangerous shell patterns (never expose `0.0.0.0`, etc.).
> **Ref:** PLAN-OPUS.md §6.2 (tool_call hook), AGENTS.md security rules

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex && \
npm test -- --grep "guardrail|tool_call|security" 2>&1 | tail -5
```

**PASS:** `passing` with count ≥ 3 (at least 3 blocked patterns tested), zero `failing`
**FAIL hints:**
- Blocked patterns: `0.0.0.0`, `--no-verify`, `rm -rf /`, `ufw delete`, `chmod 777`
- Pattern: `pi.on("tool_call", ...)` — copy from `reference/extensions/security-guard/index.ts`
- Block = return `{block: true, reason: "..."}` from the hook

---

### Step 3.6 — session_before_compact hook flushes lessons
> **Goal:** When Pi compacts the session, pending lessons are posted to `/api/lesson`.
> **Ref:** PLAN-OPUS.md §6.2 (session_before_compact)

```bash
# Unit test
cd /home/bzn/Projects/BzNdevOps/pi-cortex && \
npm test -- --grep "session_before_compact|compact.*lesson|lesson.*compact" 2>&1 | tail -5
```

**PASS:** `passing` with count ≥ 1, zero `failing`
**FAIL hints:**
- Pattern from `reference/extensions/custom-compaction.ts`: `pi.on("session_before_compact", ...)`
- Must POST all accumulated lessons to `/api/lesson` BEFORE returning
- If API unavailable at compact time: log error, do NOT block compact (Pi must compact regardless)

---

### Step 3.7 — Extension unit test suite passes
> **Goal:** All extension unit tests green.
> **Ref:** PLAN-OPUS.md §11 Phase 3.11

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension && npm test 2>&1 | tail -10
```

**PASS:** Last lines show `passing` count ≥ 10, `failing` count is `0`
**FAIL hints:**
- Mock `fetch` calls to the API (don't need a live API for unit tests)
- Mock `pi` object: `const pi = { on: vi.fn(), registerTool: vi.fn(), registerCommand: vi.fn() }`
- Minimum test coverage: stemmer, category routing, injection budget, conflict detection, guardrail patterns, lesson accumulation

---

### Phase 3 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 3 complete — Pi extension, 7 tools, hooks, guardrails, unit tests"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('3.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 3 — Pi Extension ✅\n\nSteps done:\n• 3.1 esbuild bundle → .pi/extensions/pi-cortex/index.ts\n• 3.2 Extension auto-discovery (no broken paths in settings.json)\n• 3.3 context hook: memory injection, 1500-token cap, 800ms timeout\n• 3.4 7 memory_* tools registered\n• 3.5 Guardrail hook (blocks 0.0.0.0, rm -rf /, --no-verify...)\n• 3.6 session_before_compact: lessons flushed before compact\n• 3.7 Unit test suite ≥10 tests passing\n\n%s\n\nNext: Phase 4 — Skills + prompts" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 3 done 🧩"
```

---

## Phase 4 — Skills + Prompt Templates

### Step 4.1 — All 6 skill files present with required fields
> **Goal:** Each SKILL.md has `name`, `description`, `usage`, and `example` fields.
> **Ref:** PLAN-OPUS.md §10

```bash
for skill in mem-start mem-status mem-extract mem-validate mem-consolidate mem-vault; do
  FILE="/home/bzn/Projects/BzNdevOps/pi-cortex/skills/${skill}/SKILL.md"
  if [ ! -f "$FILE" ]; then
    echo "MISSING: $skill"
  elif ! grep -qE '^# ' "$FILE"; then
    echo "NO_TITLE: $skill"
  else
    echo "OK: $skill"
  fi
done
```

**PASS:** All 6 lines say `OK: <name>`
**FAIL hints:**
- Create missing skill dirs: `mkdir -p skills/mem-start`
- Each SKILL.md must have at minimum: `# <Name>`, a description paragraph, and a `## Usage` section
- Skills are plain markdown — agents read them and follow the instructions

---

### Step 4.2 — Prompt templates present
> **Goal:** `mem-review.md` and `mem-lesson.md` exist in `prompts/`.
> **Ref:** PLAN-OPUS.md §10

```bash
ls /home/bzn/Projects/BzNdevOps/pi-cortex/prompts/mem-review.md \
   /home/bzn/Projects/BzNdevOps/pi-cortex/prompts/mem-lesson.md 2>&1 | grep -v "No such"
```

**PASS:** Both files listed without error
**FAIL hints:**
- `mkdir -p prompts`
- `mem-lesson.md`: template for recording a new lesson (what happened, why it matters, category)
- `mem-review.md`: template for reviewing a pending-review candidate (validate, promote or reject)

---

### Phase 4 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 4 complete — 6 skills, 2 prompt templates"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('4.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 4 — Skills + Prompts ✅\n\nSteps done:\n• 6 SKILL.md créés (mem-start, mem-status, mem-extract, mem-validate, mem-consolidate, mem-vault)\n• 2 prompt templates (mem-lesson.md, mem-review.md)\n\n%s\n\nNext: Phase 5a — Gardener MVP (7 missions)" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 4 done 📚"
```

---

## Phase 5a — Gardener MVP (7 missions)

### Step 5a.1 — Gardener scaffolded and buildable
> **Goal:** `app/gardener/` builds without errors, `gardener.js --help` works.
> **Ref:** PLAN-OPUS.md §7.3

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener && \
npm run build 2>&1 | grep -c error && \
node dist/gardener.js --help 2>&1 | grep -i mission
```

**PASS:** First line is `0` (no build errors), second line contains `mission`
**FAIL hints:**
- Scaffold: `cd app/gardener && npm init -y && npm install neo4j-driver pino && npm install -D typescript`
- Entry point: `gardener.ts` parses `--mission=<name>` arg and calls the matching mission function
- `--help` should print: `Usage: gardener.js --mission=<clean|version|provenance|...>`

---

### Step 5a.2 — Mission 3 (Clean / ACO evaporation) runs successfully
> **Goal:** Mission 3 evaporates pheromone on all edges (decay formula from ALGORITHMS.md §2.1).
> **Ref:** PLAN-OPUS.md §7.1, ALGORITHMS.md §2.1

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener && \
node dist/gardener.js --mission=clean --dry-run 2>&1 | tail -5
```

**PASS:** Last lines contain `evaporated` or `0 edges processed` (dry-run mode, exit 0)
**FAIL hints:**
- Dry-run mode: log what would be evaporated, but don't write to Neo4j
- Formula: `pheromone = pheromone * exp(-days_since_last_used / 30.0)` on each RELATED_TO edge
- Apply via Cypher parameterized query (never string concatenation)
- Acquire `flock(/var/lock/pi-cortex-gardener)` at start, release at end

---

### Step 5a.3 — Mission 16 (Snapshot) creates a backup
> **Goal:** Mission 16 produces a `neo4j-admin database dump` + vault tar.
> **Ref:** PLAN-OPUS.md §7.1

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener && \
node dist/gardener.js --mission=snapshot 2>&1 | tail -3 && \
ls -t /var/backups/neo4j/*.dump 2>/dev/null | head -1
```

**PASS:** Last line of gardener output contains `snapshot complete` or `dump`, AND a `.dump` file exists in `/var/backups/neo4j/`
**FAIL hints:**
- `neo4j-admin database dump neo4j --to-path=/var/backups/neo4j/` (inside podman exec or outside with neo4j-admin binary)
- Snapshot must run BEFORE Phase 7 (Obsidian) per PLAN-OPUS.md
- If `neo4j-admin` not in PATH: `sudo podman exec neo4j neo4j-admin database dump neo4j --to-path=/var/backups/neo4j/`

---

### Step 5a.4 — All 7 MVP missions exit 0
> **Goal:** All MVP missions (3, 6, 7, 11, 13, 15, 16) run to completion without error.
> **Ref:** PLAN-OPUS.md §7.1

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener
MISSIONS="clean version provenance cross-reference freshness perf snapshot"
FAILED=""
for M in $MISSIONS; do
  node dist/gardener.js --mission=$M --dry-run > /tmp/gardener-${M}.log 2>&1
  if [ $? -ne 0 ]; then FAILED="$FAILED $M"; fi
done
if [ -z "$FAILED" ]; then echo "ALL_PASS"; else echo "FAILED:$FAILED"; fi
```

**PASS:** `ALL_PASS`
**FAIL hints:**
- For each failing mission: `cat /tmp/gardener-<name>.log`
- All missions must acquire flock, connect to Neo4j, log via pino to journald, release flock
- `--dry-run` flag must be implemented in all missions

---

### Step 5a.5 — systemd Gardener timers configured
> **Goal:** Three timers (daily, weekly, monthly) are enabled and listed by systemctl.
> **Ref:** PLAN-OPUS.md §7.4

```bash
systemctl list-timers --all 2>/dev/null | grep -c "pi-cortex-gardener"
```

**PASS:** `3` (daily + weekly + monthly)
**FAIL hints:**
- Create `infra/pi-cortex-gardener@.service` (template unit, from PLAN-OPUS.md §7.4)
- Create `infra/pi-cortex-gardener-daily.timer`, `-weekly.timer`, `-monthly.timer`
- `sudo cp infra/pi-cortex-gardener*.{service,timer} /etc/systemd/system/`
- `sudo systemctl daemon-reload && sudo systemctl enable --now pi-cortex-gardener-daily.timer`

---

### Phase 5a complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 5a complete — Gardener MVP, 7 missions, systemd timers"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('5a.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 5a — Gardener MVP ✅\n\nMissions déployées:\n• M3  Clean — ACO evaporation (pheromone decay)\n• M6  Version — valid_from/valid_to\n• M7  Track provenance — source_agent + source_url\n• M11 Cross-reference — inverse RELATED_TO edges\n• M13 Score freshness — freshness_score\n• M15 Perf Neo4j — super-node detection\n• M16 Snapshot — neo4j dump + vault tar mensuel\n\nSystemd: 3 timers (daily/weekly/monthly) actifs\nflock guard: actif\n\n%s\n\n🎉 MVP complet! Next: Phase 8 — Observability" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 5a done — MVP ready! 🌱"
```

---

## Phase 8 — Observability

### Step 8.1 — /metrics endpoint returns Prometheus text
> **Goal:** `GET /metrics` returns valid Prometheus text format with expected counters.
> **Ref:** PLAN-OPUS.md §14

```bash
source /home/bzn/.pi/.env
curl -sf http://127.0.0.1:3002/metrics | grep -cE '^pi_cortex_'
```

**PASS:** `10` or more (at least 10 pi_cortex_* metric lines)
**FAIL hints:**
- Implement Prometheus text manually (no external lib needed for counters):
  ```
  # HELP pi_cortex_searches_total Total search requests
  # TYPE pi_cortex_searches_total counter
  pi_cortex_searches_total{category="architecture"} 42
  ```
- Or use `prom-client` npm package: `npm install prom-client`
- `/metrics` should NOT require `X-API-Key` (Prometheus scrapes it)

---

### Step 8.2 — API logs to journald (no secret leaks)
> **Goal:** API logs are in journald, no API keys in logs.
> **Ref:** PLAN-OPUS.md §14

```bash
journalctl -u pi-cortex-api --no-pager -n 50 | grep -ciP 'sk-cortex-'
```

**PASS:** `0` (zero occurrences of API key strings in logs)
**FAIL hints:**
- Add pino redact: `pino({ redact: ['req.headers["x-api-key"]', 'req.body.token', 'req.body.password'] })`
- Verify: make a request, check logs: `journalctl -u pi-cortex-api -n 10`

---

### Step 8.3 — Health alert telegram unit configured
> **Goal:** A systemd `OnFailure=` alert fires a Telegram notification when pi-cortex-api fails.
> **Ref:** PLAN-OPUS.md §14 (Telegram alerts), AGENTS.md §5 (alert-email@.service pattern)

```bash
systemctl cat pi-cortex-api.service | grep -c "OnFailure"
```

**PASS:** `1`
**FAIL hints:**
- Add to `[Unit]` section: `OnFailure=alert-telegram@%n.service`
- Create `/etc/systemd/system/alert-telegram@.service` similar to existing `alert-email@.service`
- Use `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from `/etc/bzserv-electricity.env`

---

### Phase 8 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 8 complete — /metrics, journald logs, Telegram health alerts"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('8.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 8 — Observability ✅\n\nSteps done:\n• 8.1 /metrics endpoint (Prometheus text, ≥10 pi_cortex_* counters)\n• 8.2 pino → journald, zéro API key dans les logs (redact)\n• 8.3 OnFailure=alert-telegram@%n.service configuré\n\n%s\n\nNext: Phase 9 — Security hardening" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 8 done 📊"
```

---

## Phase 9 — Security Hardening

### Step 9.1 — All pi-cortex ports bound to 127.0.0.1 only
> **Goal:** Neo4j (7474, 7687) and API (3002) are NOT exposed on public interfaces.
> **Ref:** PLAN-OPUS.md §9.1, AGENTS.md security rules

```bash
ss -tlnp | grep -E ':3002|:7474|:7687' | awk '{print $4}' | sort -u
```

**PASS:** All addresses start with `127.0.0.1` — NO `0.0.0.0`, NO `*`
**FAIL hints:**
- API server: ensure Express binds with `app.listen(3002, '127.0.0.1', ...)`
- Neo4j: `NEO4J_server_http_listen__address=127.0.0.1:7474` and `NEO4J_server_bolt_listen__address=127.0.0.1:7687` in Quadlet
- If port shows on `0.0.0.0`: STOP, fix before continuing — never expose Neo4j publicly

---

### Step 9.2 — UFW rules intact (no regressions)
> **Goal:** The security posture of bzserv is unchanged — ALLOW tailscale0 before DENY.
> **Ref:** PLAN-OPUS.md §9.2, AGENTS.md security directive

```bash
sudo ufw status numbered | grep -E 'ALLOW|DENY' | head -20
```

**PASS:** MANUAL REVIEW — verify that for every DENY rule there is a preceding ALLOW on tailscale0 for the same port, and no new ports are open to `0.0.0.0/0`
**FAIL hints:**
- `sudo ufw status numbered` — audit line by line
- Acceptable new rules: `ALLOW in on tailscale0 to 100.64.144.126 port 3002`
- Never add `ufw allow 3002` without `on tailscale0` scope
- If unsure: `sudo ufw status verbose`

> ⚠️ **MANUAL** — show output to human for confirmation.

---

### Step 9.3 — fail2ban jail for WebDAV
> **Goal:** fail2ban has a jail protecting nginx WebDAV basic-auth failures.
> **Ref:** PLAN-OPUS.md §9.3, Risk R6

```bash
sudo fail2ban-client status | grep -i webdav
```

**PASS:** Line containing `webdav` or `nginx-knowledge-vault`
**FAIL hints:**
- Create `/etc/fail2ban/jail.d/pi-cortex-webdav.conf`:
  ```ini
  [nginx-pi-cortex-webdav]
  enabled = true
  port = 443
  filter = nginx-http-auth
  logpath = /var/log/nginx/access.log
  maxretry = 5
  bantime = 3600
  ```
- `sudo fail2ban-client reload`

---

### Step 9.4 — Security score still ≥ 8.5/10
> **Goal:** No security regressions introduced by pi-cortex deployment.
> **Ref:** PLAN-OPUS.md §9.6, CLAUDE.md §4

```bash
# Quick self-check: verify no new public-facing ports
OPEN_PORTS=$(ss -tlnp | grep -vE '127\.0\.0\.1|::1' | grep -cE ':3002|:7474|:7687')
# Verify .env perms
ENV_PERMS=$(stat -c "%a" /home/bzn/.pi/.env)
echo "new_open_ports:${OPEN_PORTS} env_perms:${ENV_PERMS}"
```

**PASS:** `new_open_ports:0 env_perms:600`
**FAIL hints:**
- If `new_open_ports > 0`: find which service is binding publicly and fix its bind address
- If `env_perms != 600`: `chmod 600 /home/bzn/.pi/.env`
- Full audit command: `sudo ss -tlnp | grep -vE '^127\.|^::1'`

---

### Phase 9 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 9 complete — security hardening, fail2ban WebDAV, AIDE rules"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('9.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 9 — Security Hardening ✅\n\nSteps done:\n• 9.1 Tous les ports sur 127.0.0.1 (3002, 7474, 7687) — zéro 0.0.0.0\n• 9.2 UFW order vérifié: ALLOW tailscale0 < DENY\n• 9.3 fail2ban jail nginx-pi-cortex-webdav actif\n• 9.4 Score sécurité bzserv ≥ 8.5/10 — aucune régression\n\n%s\n\nNext: Phase 10 — Documentation" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 9 done 🔒"
```

---

## Phase 10 — Documentation

### Step 10.1 — Core runbooks exist
> **Goal:** Four runbook files exist in `docs/runbooks/`.
> **Ref:** PLAN-OPUS.md §10

```bash
ls /home/bzn/Projects/BzNdevOps/pi-cortex/docs/runbooks/ 2>/dev/null | \
  grep -cE 'deploy|rotate|restore|obsidian'
```

**PASS:** `4`
**FAIL hints:**
- `mkdir -p docs/runbooks`
- Required files: `deploy-bzserv.md`, `rotate-api-keys.md`, `restore-from-snapshot.md`, `obsidian-conflict-resolution.md`
- Each runbook is a numbered-step procedure — not architecture docs

---

### Step 10.2 — README and AGENT_HANDOVER updated to 11 phases
> **Goal:** `README.md` and `AGENT_HANDOVER.md` reference `PLAN-OPUS.md` and 11 phases.
> **Ref:** PLAN-OPUS.md Appendix A

```bash
grep -c "PLAN-OPUS\|11 phase" \
  /home/bzn/Projects/BzNdevOps/pi-cortex/README.md \
  /home/bzn/Projects/BzNdevOps/pi-cortex/AGENT_HANDOVER.md 2>/dev/null
```

**PASS:** `2` or more (at least one reference in each file)
**FAIL hints:**
- Add to `README.md`: `> See [PLAN-OPUS.md](PLAN-OPUS.md) for the execution plan (11 phases).`
- `AGENT_HANDOVER.md` already updated (2026-05-04) — Step 10.2 may auto-pass

---

### Phase 10 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "docs: phase 10 complete — runbooks, README updated, AGENT_HANDOVER updated"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('10.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
printf "pi-cortex Phase 10 — Documentation ✅\n\nRunbooks créés:\n• deploy-bzserv.md\n• rotate-api-keys.md\n• restore-from-snapshot.md\n• obsidian-conflict-resolution.md\n\nREADME.md et AGENT_HANDOVER.md mis à jour (11 phases)\n\n%s\n\nNext: Phase 11 — npm publish" "$BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 10 done 📝"
```

---

## Phase 11 — npm Package Release

### Step 11.1 — package.json ready for publish
> **Goal:** `package.json` has name, version, pi entry, and pinned Pi SDK dependency.
> **Ref:** PLAN-OPUS.md §10, §15

```bash
node -e "const p=require('/home/bzn/Projects/BzNdevOps/pi-cortex/package.json'); \
  const checks={ \
    name: p.name==='@bzndevops/pi-cortex', \
    version: !!p.version, \
    pi_ext: !!(p.pi&&p.pi.extensions), \
    pi_pinned: !!(p.dependencies&&p.dependencies['@mariozechner/pi-coding-agent']&&!p.dependencies['@mariozechner/pi-coding-agent'].includes('*')), \
  }; \
  const fails=Object.entries(checks).filter(([k,v])=>!v).map(([k])=>k); \
  console.log(fails.length===0?'OK':'FAIL:'+fails.join(','))"
```

**PASS:** `OK`
**FAIL hints:**
- `name` must be `@bzndevops/pi-cortex`
- Pin SDK: `"@mariozechner/pi-coding-agent": "^0.6.0"` (not `"*"`)
- `pi.extensions` must point to the bundled output: `"./extension/dist/index.ts"`

---

### Step 11.2 — npm pack produces valid package
> **Goal:** `npm pack --dry-run` lists the expected files without errors.
> **Ref:** PLAN-OPUS.md §11 Phase 11.2

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex && \
npm pack --dry-run 2>&1 | grep -cE '\.(md|ts|json)$'
```

**PASS:** `5` or more files listed (at least the 5 global knowledge files + extension + skills)
**FAIL hints:**
- Add `.npmignore` to exclude `app/api-server/`, `app/gardener/`, `reference/`, `.pi/install-cache/`
- Verify `files` field in `package.json` includes: `knowledge/`, `skills/`, `prompts/`, `extension/dist/`
- The API server and Gardener are NOT published to npm — they are bzserv-private

---

### Phase 11 complete — commit + notify
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex add -A
git -C /home/bzn/Projects/BzNdevOps/pi-cortex commit -m "feat: phase 11 complete — npm package ready for publish"

BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    pb = [x['step']+': '+x['reason'] for x in b if x['step'].startswith('11.')]
    print('⚠️ Blocked: ' + ' | '.join(pb) if pb else '✅ No blocked steps')
except: print('✅ No blocked steps')
")
TOTAL_BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    print(str(len(b)) + ' step(s) deferred across all phases')
except: print('0 deferred')
")
printf "pi-cortex Phase 11 — npm Package ✅\n\n@bzndevops/pi-cortex prêt pour npm publish\npackage.json validé, Pi SDK pinned, npm pack OK\n\n%s\n\n--- PROJET COMPLET ---\n%s\n\nRun E2E test: voir TEST-PLAN.md section End-to-End" "$BLOCKED" "$TOTAL_BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] Phase 11 done — projet terminé! 🚀"
```

---

## End-to-End Integration Test

Run this AFTER all phases complete. This is the final acceptance gate.

### Step E2E — Full read/write/evaporate cycle
> **Goal:** One complete memory lifecycle: add knowledge → search it → reinforce → evaporate → freshness updated.

```bash
source /home/bzn/.pi/.env
BASE="http://127.0.0.1:3002"
KEY_HEADER="X-API-Key: ${PI_CORTEX_AGENT_KEY}"

# 1. Create knowledge
curl -sf -X POST "$BASE/api/knowledge" \
  -H "$KEY_HEADER" -H "Content-Type: application/json" \
  -d '{"id":"e2e/test-01","title":"E2E Test Knowledge","content":"Neo4j chokidar watcher must use polling mode on WebDAV filesystems.","category":"best-practices","status":"active","confidence":0.9}' > /dev/null

# 2. Search and find it
SCORE=$(curl -sf -H "$KEY_HEADER" "$BASE/api/search?q=chokidar+webdav+polling" \
  | python3 -c "import sys,json; r=json.load(sys.stdin); hits=[x for x in r.get('results',[]) if 'e2e' in x.get('id','')]; print(round(hits[0]['score'],2) if hits else 0)")

# 3. Reinforce 5 times
for i in $(seq 1 5); do
  curl -sf -X POST "$BASE/api/graph/reinforce" -H "$KEY_HEADER" -H "Content-Type: application/json" \
    -d '{"id":"e2e/test-01"}' > /dev/null
done

# 4. Run clean mission (evaporate)
node /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener/dist/gardener.js --mission=clean > /dev/null 2>&1

# 5. Run freshness mission
node /home/bzn/Projects/BzNdevOps/pi-cortex/app/gardener/dist/gardener.js --mission=freshness > /dev/null 2>&1

# 6. Check final state
FINAL=$(curl -sf -H "$KEY_HEADER" "$BASE/api/knowledge/e2e/test-01" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'uses:{d[\"uses\"]} freshness:{round(d.get(\"freshness_score\",0),2)}')")

# Cleanup
curl -sf -X DELETE -H "$KEY_HEADER" "$BASE/api/knowledge/e2e/test-01" > /dev/null 2>&1

echo "search_score:${SCORE} ${FINAL}"
```

**PASS:** `search_score:0.XX uses:5 freshness:0.XX` — all three non-zero
**FAIL hints:**
- If `search_score:0`: knowledge not indexed — check watcher or direct API write to Neo4j
- If `uses:0`: reinforcement not flushing — check ACO batch flush (Step 2b.5)
- If `freshness:0`: Mission 13 not updating `freshness_score` field in Neo4j
- Run each gardener mission with `--dry-run` first to isolate which step fails

---

### E2E complete — final Telegram report
```bash
TOTAL_BLOCKED=$(python3 -c "
import json
try:
    b = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json'))
    if b:
        lines = ['• ' + x['step'] + ': ' + x['reason'] for x in b]
        print(str(len(b)) + ' step(s) deferred:\n' + '\n'.join(lines))
    else:
        print('Aucune étape bloquée — 100% clean ✅')
except: print('Aucune étape bloquée — 100% clean ✅')
")
printf "🎉 pi-cortex — PROJET COMPLET\n\nTest E2E: search_score + uses + freshness tous non-nuls ✅\n\nRésumé:\n• Neo4j Community 5.x opérationnel\n• API REST (127.0.0.1:3002) avec auth X-API-Key\n• Watcher chokidar + 409 conflict\n• Pi extension (7 tools, hooks, guardrails)\n• Gardener MVP (7 missions, 3 timers systemd)\n• Observability (/metrics Prometheus)\n• Sécurité: fail2ban WebDAV, ports 127.0.0.1, AIDE\n• npm package @bzndevops/pi-cortex prêt\n\n%s" "$TOTAL_BLOCKED" \
  | /usr/local/bin/bzserv-telegram-send "[pi-cortex] 🚀 PROJET TERMINÉ — E2E PASS"
```

---

## Quick Reference — Test Commands Cheatsheet

| Phase | Gate command (short) | PASS condition |
|-------|---------------------|----------------|
| 0.1 | `grep -cP '^PI_CORTEX_.*_KEY=sk-cortex' ~/.pi/.env` | `3` |
| 0.2 | `java -version 2>&1 \| grep "21"` | matches |
| 1.1 | `curl -sf http://127.0.0.1:7474/ \| python3 -c "..."` | `5` |
| 1.2 | APOC + GDS versions returned from Cypher | no errors |
| 1.5 | `curl ... -X PROPFIND .../knowledge/ -w "%{http_code}"` | `207` |
| 2a.2 | `curl -sf .../api/health \| python3 -c "..."` | `OK` |
| 2a.3 | No key → 401, with key → 200 | `401 200` |
| 2b.1 | Write .md → wait 3s → GET /api/knowledge/:id | node title returned |
| 2b.3 | POST /api/lesson → GET node → status | `draft` |
| 2b.4 | POST knowledge with wrong hash | `409` |
| 3.1 | `ls .pi/extensions/pi-cortex/index.ts` | file exists |
| 3.4 | `grep -c registerTool app/extension/src/index.ts` | `7` |
| 5a.4 | All MVP missions --dry-run | `ALL_PASS` |
| 8.1 | `curl .../metrics \| grep -c pi_cortex_` | `≥ 10` |
| 9.1 | `ss -tlnp \| grep -E '3002\|7474\|7687'` | all `127.0.0.1` |
| E2E | Full lifecycle | `search_score:0.XX uses:5 freshness:0.XX` |

---

*Autonomous loop: read step → implement → run test → PASS → checkpoint → next. After each phase: git commit + Telegram notify. After 3 FAIL: record in blocked-steps.json → continue.*
