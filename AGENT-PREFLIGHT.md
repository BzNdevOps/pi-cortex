# pi-cortex — Agent Pre-flight Checklist

> **Purpose:** Run this checklist BEFORE starting the coding loop.
> If every CRITICAL check passes, the agent can complete the full project without human intervention.
> If any CRITICAL check fails, stop and fix it (or ask the human) before starting.

---

## How to run

**Option A — Automated (recommended):**
Copy-paste the master runner at the bottom of this file into a terminal.
It prints a color-coded report and a final verdict.

**Option B — Manual:**
Work through each section in order. Mark each check ✅ PASS or ❌ FAIL.

**Verdict logic:**
- All CRITICAL checks PASS → **FULLY AUTONOMOUS** — proceed with TEST-PLAN.md
- Any CRITICAL check FAILS → **BLOCKED** — fix or ask human before starting
- REQUIRED check FAILS → **PARTIAL** — agent can code but specific phases will fail (noted per check)
- OPTIONAL check FAILS → agent can still complete the project; some features are degraded

---

## Section 1 — Shell Tools

> These are the basic executables the agent needs. All are CRITICAL.

### 1.1 — bash 4+
```bash
bash --version | head -1 | grep -oP 'version \K\d+' | awk '$1 >= 4 {print "PASS"}'
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Every test command in TEST-PLAN.md

---

### 1.2 — curl
```bash
curl --version | head -1 | grep -oP 'curl \K[\d.]+'
```
**PASS:** Any version string (e.g. `8.5.0`)
**Severity:** CRITICAL
**Blocked if missing:** All API tests, all health checks

---

### 1.3 — python3
```bash
python3 --version 2>&1 | grep -oP 'Python 3\.\d+'
```
**PASS:** `Python 3.X`
**Severity:** CRITICAL
**Blocked if missing:** All JSON-parsing in test commands

---

### 1.4 — Node.js 22+
```bash
node --version | grep -oP 'v(\d+)' | grep -oP '\d+' | awk '$1 >= 22 {print "PASS"}'
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Phase 2a, 2b, 3, 4, 5a — entire API + extension + Gardener

---

### 1.5 — npm 9+
```bash
npm --version | grep -oP '^\d+' | awk '$1 >= 9 {print "PASS"}'
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** All npm install, build, test commands

---

### 1.6 — TypeScript (tsc) or esbuild available
```bash
(npx --yes esbuild --version 2>/dev/null || npx tsc --version 2>/dev/null) | head -1
```
**PASS:** Any version string
**Severity:** CRITICAL
**Blocked if missing:** Phase 3 (extension build)

---

### 1.7 — Java 21+
```bash
java -version 2>&1 | grep -oP '"(\d+)' | grep -oP '\d+' | awk '$1 >= 21 {print "PASS"}'
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1)
**Blocked if missing:** Phase 1 — Neo4j won't start without Java 21
**Install:** `sudo apt install openjdk-21-jre-headless`

---

### 1.8 — git
```bash
git --version | grep -oP 'git version \K[\d.]+'
```
**PASS:** Any version string
**Severity:** CRITICAL
**Blocked if missing:** Cannot commit, cannot track progress

---

### 1.9 — openssl
```bash
openssl version | grep -oP 'OpenSSL \K[\d.]+'
```
**PASS:** Any version string
**Severity:** REQUIRED (Phase 0, 9)
**Blocked if missing:** Phase 0.1 (key generation), Phase 0.4 (TLS cert check)

---

### 1.10 — ss (socket statistics)
```bash
ss --version 2>/dev/null | head -1 || echo "PASS (ss is part of iproute2)"
```
**PASS:** Any output or `PASS`
**Severity:** REQUIRED (Phase 9)
**Blocked if missing:** Phase 9.1 (port binding verification)

---

### 1.11 — systemctl
```bash
systemctl --version | head -1 | grep -oP 'systemd \K\d+'
```
**PASS:** Number ≥ 245
**Severity:** CRITICAL
**Blocked if missing:** Phase 1 (Neo4j Quadlet), Phase 2a (API service), Phase 5a (Gardener timers)

---

### 1.12 — podman
```bash
podman --version | grep -oP 'version \K[\d.]+'
```
**PASS:** Any version string (e.g. `4.9.3`)
**Severity:** REQUIRED (Phase 1)
**Blocked if missing:** Phase 1.1 — cannot deploy Neo4j via Podman Quadlet
**Install:** `sudo apt install podman`

---

## Section 2 — Project Filesystem Access

> The agent must be able to read and write all paths involved in the project.

### 2.1 — Project directory readable and writable
```bash
TEST_FILE="/home/bzn/Projects/BzNdevOps/pi-cortex/.preflight-write-test"
echo "ok" > "$TEST_FILE" && cat "$TEST_FILE" && rm "$TEST_FILE" && echo "PASS"
```
**PASS:** `ok` then `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Cannot write any code

---

### 2.2 — .pi/.env readable (secrets access)
```bash
[ -r /home/bzn/.pi/.env ] && \
  stat -c "%a" /home/bzn/.pi/.env | grep -q "600" && \
  echo "PASS" || echo "FAIL: missing or wrong perms"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Agent cannot read API keys, Neo4j password, tokens
**Fix:** `touch /home/bzn/.pi/.env && chmod 600 /home/bzn/.pi/.env`

---

### 2.3 — Can create /opt/knowledge-vault/ (with sudo)
```bash
sudo test -d /opt/knowledge-vault 2>/dev/null && echo "EXISTS" || \
  sudo mkdir -p /opt/knowledge-vault/test-preflight && \
  sudo rmdir /opt/knowledge-vault/test-preflight && echo "PASS"
```
**PASS:** `EXISTS` or `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Phase 1.4 — vault directory setup
**Fix:** `sudo mkdir -p /opt/knowledge-vault && sudo chown bzn:bzn /opt/knowledge-vault`

---

### 2.4 — Can write to /var/lib/ (Gardener state)
```bash
sudo mkdir -p /var/lib/pi-cortex/state && \
  sudo chown bzn:bzn /var/lib/pi-cortex && \
  touch /var/lib/pi-cortex/state/.preflight-test && \
  rm /var/lib/pi-cortex/state/.preflight-test && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 2b)
**Blocked if missing:** Gardener state files (`taxonomy.json`, `weights.json`, `fallback-block.md`) cannot be written

---

### 2.5 — Can write to /etc/systemd/system/ (with sudo)
```bash
TESTFILE="/etc/systemd/system/.preflight-test"
sudo touch "$TESTFILE" && sudo rm "$TESTFILE" && echo "PASS"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Phase 1 (Neo4j Quadlet), Phase 2a (API service), Phase 5a (Gardener service + timers)

---

### 2.6 — Can write to /etc/nginx/sites-enabled/ (with sudo)
```bash
TESTFILE="/etc/nginx/sites-enabled/.preflight-test"
sudo touch "$TESTFILE" && sudo rm "$TESTFILE" && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.5)
**Blocked if missing:** Phase 1.5 — WebDAV nginx config cannot be deployed

---

### 2.7 — Can write to /etc/containers/systemd/ (with sudo, for Podman Quadlet)
```bash
TESTFILE="/etc/containers/systemd/.preflight-test"
sudo touch "$TESTFILE" && sudo rm "$TESTFILE" && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.1)
**Blocked if missing:** Phase 1.1 — Neo4j Quadlet cannot be deployed
**Note:** Directory must exist: `sudo mkdir -p /etc/containers/systemd`

---

### 2.8 — Can write to /var/backups/ (for Neo4j dumps)
```bash
sudo mkdir -p /var/backups/neo4j && \
  sudo chown bzn:bzn /var/backups/neo4j && \
  touch /var/backups/neo4j/.preflight-test && \
  rm /var/backups/neo4j/.preflight-test && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.8, Phase 5a.3)
**Blocked if missing:** Snapshot mission and Neo4j dump cron cannot write dumps

---

### 2.9 — Can write to /var/log/pi-cortex/ (API + watcher logs)
```bash
sudo mkdir -p /var/log/pi-cortex && \
  sudo chown bzn:bzn /var/log/pi-cortex && \
  touch /var/log/pi-cortex/.preflight-test && \
  rm /var/log/pi-cortex/.preflight-test && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 2a, 2b)
**Blocked if missing:** Watcher errors cannot be logged; API startup fails if log path is hardcoded

---

### 2.10 — Restic backup destination writable
```bash
[ -d /mnt/wd3t/backups ] && echo "PASS" || echo "FAIL: /mnt/wd3t/backups not mounted"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.7, 1.8)
**Blocked if missing:** Backup crons will fail silently — agent should warn but not block
**Note:** If disk not mounted, backups go to local fallback — confirm with human

---

## Section 3 — Sudo Privileges

> The agent needs sudo for deployment commands. Each check verifies a specific sudo permission.

### 3.1 — sudo systemctl (start/stop/enable services)
```bash
sudo systemctl is-system-running --quiet 2>/dev/null && echo "PASS"
```
**PASS:** `PASS` (exit 0, system is running)
**Severity:** CRITICAL
**Blocked if missing:** Cannot start Neo4j, API, Gardener, nginx

---

### 3.2 — sudo podman (manage containers)
```bash
sudo podman info --format "{{.Host.OS}}" 2>/dev/null | grep -qi linux && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.1)
**Blocked if missing:** Cannot deploy Neo4j container

---

### 3.3 — sudo ufw (firewall management)
```bash
sudo ufw status 2>/dev/null | grep -qiE 'Status:|active|inactive' && echo "PASS"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Cannot configure firewall rules — SECURITY RISK if skipped
**⚠️ Never add UFW rules without human review if this check fails**

---

### 3.4 — sudo nginx (reload/test config)
```bash
sudo nginx -t 2>/dev/null && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.5)
**Blocked if missing:** Cannot deploy WebDAV config

---

### 3.5 — sudo fail2ban-client (manage jails)
```bash
sudo fail2ban-client status 2>/dev/null | grep -q "Number of jail" && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 9.3)
**Blocked if missing:** Cannot add WebDAV fail2ban jail

---

### 3.6 — sudo crontab (root cron for backups)
```bash
sudo crontab -l 2>/dev/null; echo "PASS"
```
**PASS:** `PASS` (crontab -l exits 0 even if empty)
**Severity:** REQUIRED (Phase 1.7, 1.8)
**Blocked if missing:** Cannot add Restic + Neo4j dump crons

---

### 3.7 — sudo htpasswd (nginx basic auth)
```bash
which htpasswd > /dev/null 2>&1 && echo "PASS" || \
  sudo apt list --installed 2>/dev/null | grep -q apache2-utils && echo "PASS" || \
  echo "FAIL: htpasswd missing — install apache2-utils"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.5)
**Blocked if missing:** Cannot create WebDAV basic-auth password file
**Fix:** `sudo apt install apache2-utils`

---

## Section 4 — Secrets & Credentials

> The agent must be able to read or generate all required secrets.

### 4.1 — PI_CORTEX_*_KEY present or generable
```bash
source /home/bzn/.pi/.env 2>/dev/null
if grep -qP '^PI_CORTEX_AGENT_KEY=sk-cortex-' /home/bzn/.pi/.env 2>/dev/null; then
  echo "PRESENT"
else
  # Can we generate them?
  openssl rand -hex 32 > /dev/null 2>&1 && echo "GENERABLE"
fi
```
**PASS:** `PRESENT` or `GENERABLE`
**Severity:** CRITICAL
**Blocked if missing:** Cannot authenticate to API at all
**Generate:** `echo "PI_CORTEX_AGENT_KEY=sk-cortex-agent-$(openssl rand -hex 32)" >> /home/bzn/.pi/.env`

---

### 4.2 — NEO4J_PASSWORD present or settable
```bash
grep -qP '^NEO4J_PASSWORD=\S+' /home/bzn/.pi/.env 2>/dev/null && echo "PRESENT" || \
  echo "MISSING — agent will generate and add a random password at Phase 0.1"
```
**PASS:** `PRESENT` (or `MISSING` is acceptable — agent generates it at Phase 0.1)
**Severity:** REQUIRED (Phase 1)
**Note:** If missing, agent generates: `echo "NEO4J_PASSWORD=$(openssl rand -hex 24)" >> /home/bzn/.pi/.env`

---

### 4.3 — GitHub token readable (for git push)
```bash
TOKEN=$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials 2>/dev/null | head -1)
[ -n "$TOKEN" ] && echo "PRESENT" || echo "MISSING"
```
**PASS:** `PRESENT`
**Severity:** REQUIRED (Phase 10, 11 — git commits and npm publish)
**Blocked if missing:** Cannot push commits or publish npm package (can still code locally)
**Note:** If MISSING, agent can still complete all coding phases but cannot push to GitHub

---

### 4.4 — OPENROUTER_API_KEY present (for Gardener deferred missions)
```bash
grep -qP '^OPENROUTER_API_KEY=\S+' /home/bzn/.pi/.env 2>/dev/null && echo "PRESENT" || echo "MISSING"
```
**PASS:** `PRESENT` or `MISSING` (MVP Gardener doesn't use LLM — deferred only)
**Severity:** OPTIONAL
**Blocked if missing:** Gardener Mission 1 (validate via SearXNG+LLM) — Phase 5b only, not MVP

---

### 4.5 — Telegram alert credentials present
```bash
grep -qP '^TELEGRAM_BOT_TOKEN=\S+' /etc/bzserv-electricity.env 2>/dev/null && echo "PRESENT" || echo "MISSING"
```
**PASS:** `PRESENT` or `MISSING` (only needed for Phase 8 alerts)
**Severity:** OPTIONAL
**Blocked if missing:** Phase 8.3 health alerts will not fire to Telegram

---

## Section 5 — Network & Connectivity

> The agent needs internet access for npm installs and (optionally) GitHub push.

### 5.1 — Internet access (npm registry reachable)
```bash
curl -sf --max-time 5 https://registry.npmjs.org/ -o /dev/null && echo "PASS"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** Cannot `npm install` any dependencies

---

### 5.2 — GitHub reachable (for git push)
```bash
curl -sf --max-time 5 https://api.github.com -o /dev/null && echo "PASS"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 10, 11)
**Blocked if missing:** Cannot push commits or check remote state (can still code locally)

---

### 5.3 — Tailscale connected (agent is on bzserv or can reach it)
```bash
# Check if we ARE bzserv (most likely — agent runs on bzserv)
hostname | grep -qi bzserv && echo "LOCAL" && exit 0
# Otherwise check Tailscale connectivity
ping -c 1 -W 3 100.64.144.126 > /dev/null 2>&1 && echo "REACHABLE" || echo "FAIL: cannot reach bzserv"
```
**PASS:** `LOCAL` (running on bzserv) or `REACHABLE`
**Severity:** CRITICAL
**Blocked if missing:** All API calls, Neo4j commands, systemctl — everything on bzserv

---

### 5.4 — localhost:7474 will be reachable (pre-deploy check)
```bash
# Before Neo4j is deployed this will fail — that is expected.
# This check verifies the PORT is not already taken by another process.
ss -tlnp | grep ':7474' && echo "IN_USE" || echo "PORT_FREE"
```
**PASS:** `PORT_FREE` (nothing blocking the port before Neo4j deploys)
**Severity:** REQUIRED (Phase 1.1)
**Blocked if missing:** If `IN_USE`: find what's using 7474 — `sudo ss -tlnp | grep 7474`

---

### 5.5 — localhost:3002 is free
```bash
ss -tlnp | grep ':3002' && echo "IN_USE" || echo "PORT_FREE"
```
**PASS:** `PORT_FREE`
**Severity:** REQUIRED (Phase 2a)
**Blocked if missing:** API server cannot bind; find conflicting process

---

### 5.6 — SearXNG accessible (for Gardener Mission 1 — deferred)
```bash
curl -sf --max-time 3 http://127.0.0.1:8888/ -o /dev/null && echo "PASS" || echo "FAIL (deferred — only needed for Phase 5b)"
```
**PASS:** `PASS` or `FAIL` (acceptable for MVP)
**Severity:** OPTIONAL (Phase 5b only)
**Note:** SearXNG is already running on bzserv per CLAUDE.md — `FAIL` here means it's down temporarily

---

## Section 6 — Pi Agent Environment

> The agent uses Pi for the extension development and testing.

### 6.1 — Pi CLI installed
```bash
pi --version 2>/dev/null | head -1 || which pi 2>/dev/null && echo "PASS"
```
**PASS:** Any output or `PASS`
**Severity:** REQUIRED (Phase 3 — extension testing)
**Blocked if missing:** Cannot test extension loading via `/reload`, cannot verify Pi SDK compatibility
**Note:** If missing, Phase 3 coding is possible but manual testing requires human

---

### 6.2 — .pi/settings.json readable
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/settings.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('VALID')"
```
**PASS:** `VALID`
**Severity:** REQUIRED (Phase 3)
**Blocked if missing:** Cannot verify extension auto-discovery config
**Fix:** `echo '{"extensions":[],"packages":[]}' > .pi/settings.json`

---

### 6.3 — .pi/extensions/ directory writable
```bash
mkdir -p /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/pi-cortex && \
  touch /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/.preflight-test && \
  rm /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/.preflight-test && echo "PASS"
```
**PASS:** `PASS`
**Severity:** CRITICAL (Phase 3)
**Blocked if missing:** Cannot deploy extension bundle

---

### 6.4 — Reference extensions present (offline copies)
```bash
ls /home/bzn/Projects/BzNdevOps/pi-cortex/reference/extensions/ 2>/dev/null | \
  grep -cE '\.(ts)$'
```
**PASS:** `7` or more (memory-cycle, todo, security-guard, custom-compaction, message-integrity-guard, tool-search, tool-registry, qwen-autostart)
**Severity:** REQUIRED (Phase 3)
**Blocked if missing:** Agent cannot copy patterns from reference extensions
**Note:** If missing, agent must fetch from GitHub (requires internet) — see Pi-Cortex-Knowladge.md §5

---

### 6.5 — Pi SDK version known and compatible
```bash
# Check if the SDK is available in the project's node_modules
node -e "const p=require('/home/bzn/.pi/agent/package.json' ); console.log('pi-sdk:',p.version)" 2>/dev/null || \
  pi --version 2>/dev/null | head -1 || echo "UNKNOWN — check manually"
```
**PASS:** Any version output
**Severity:** REQUIRED (Phase 3)
**Note:** Pi SDK events were renamed in pre-1.0 versions — verify event names match PLAN-OPUS.md §6.2 before coding extension

---

## Section 7 — Git Configuration

### 7.1 — Git user configured
```bash
git -C /home/bzn/Projects/BzNdevOps/pi-cortex config user.name 2>/dev/null && \
git -C /home/bzn/Projects/BzNdevOps/pi-cortex config user.email 2>/dev/null && echo "PASS"
```
**PASS:** `PASS` (name and email both printed)
**Severity:** REQUIRED (Phase 10)
**Blocked if missing:** Cannot commit
**Fix:** `git config --global user.name "BzNdevOps" && git config --global user.email "bzndevops@gmail.com"`

---

### 7.2 — Git remote reachable with credentials
```bash
TOKEN=$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials 2>/dev/null | head -1)
if [ -z "$TOKEN" ]; then echo "SKIP: no token"; exit 0; fi
curl -sf -H "Authorization: token ${TOKEN}" https://api.github.com/user | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('user:',d.get('login','unknown'))"
```
**PASS:** `user: BzNdevOps`
**Severity:** REQUIRED (Phase 10, 11)
**Blocked if missing:** Cannot push commits or publish npm package
**Note:** If token expired: the human must regenerate at github.com/settings/tokens

---

### 7.3 — npm registry authenticated (for publish)
```bash
npm whoami 2>/dev/null || echo "NOT_LOGGED_IN (only needed for Phase 11 — npm publish)"
```
**PASS:** npm username printed (e.g. `bzndevops`)
**Severity:** OPTIONAL (Phase 11 only)
**Blocked if missing:** Cannot `npm publish` — Phase 11.2 only
**Fix:** `npm login` (requires human, interactive)

---

## Section 8 — Existing Services (must not be broken)

> These are the existing bzserv services. The agent must NOT break them.

### 8.1 — Ollama/Open WebUI still running
```bash
curl -sf http://127.0.0.1:3000/ -o /dev/null && echo "PASS" || echo "FAIL: open-webui down (pre-existing issue)"
```
**PASS:** `PASS`
**Severity:** REQUIRED (integrity check — not pi-cortex's responsibility)
**Note:** If FAIL before starting: document this as a pre-existing issue. Do not accept blame for it.

---

### 8.2 — voice-pi API running
```bash
curl -sf http://127.0.0.1:8000/health 2>/dev/null && echo "PASS" || echo "FAIL: voice-pi down (pre-existing issue)"
```
**PASS:** `PASS` or `FAIL (pre-existing issue)`
**Severity:** REQUIRED (integrity check)
**Note:** Document baseline state before starting any work

---

### 8.3 — nginx serving existing services
```bash
sudo nginx -t 2>&1 | grep -q "successful" && echo "PASS"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if failing:** Any nginx config the agent adds could fail; DO NOT reload nginx if pre-existing config is broken

---

### 8.4 — Restic backup working (pre-existing)
```bash
sudo restic -r /mnt/wd3t/backups/knowledge-vault snapshots 2>/dev/null | grep -c "snapshot" || \
  echo "NO_SNAPSHOTS_YET (acceptable if vault not deployed yet)"
```
**PASS:** Any count or `NO_SNAPSHOTS_YET`
**Severity:** OPTIONAL (integrity check)
**Note:** Confirms /mnt/wd3t is mounted and Restic repo accessible

---

## Section 9 — Autonomy Summary

Run this section LAST. It aggregates all checks into a verdict.

### 9.1 — MASTER PREFLIGHT RUNNER

Copy and run this complete script:

```bash
#!/usr/bin/env bash
# pi-cortex Agent Pre-flight Runner
# Run from: /home/bzn/Projects/BzNdevOps/pi-cortex/
set -o pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'; BOLD='\033[1m'
PASS_COUNT=0; FAIL_CRITICAL=0; FAIL_REQUIRED=0; FAIL_OPTIONAL=0
BLOCKED_PHASES=""

check() {
  local id="$1" desc="$2" severity="$3" cmd="$4" expect="$5" blocked="$6"
  result=$(eval "$cmd" 2>/dev/null)
  if echo "$result" | grep -qP "$expect"; then
    echo -e "${GREEN}✅ PASS${NC} [$id] $desc"
    ((PASS_COUNT++))
  else
    case "$severity" in
      CRITICAL)
        echo -e "${RED}❌ CRITICAL FAIL${NC} [$id] $desc"
        echo -e "   Got: ${result:-<empty>}"
        ((FAIL_CRITICAL++))
        BLOCKED_PHASES="$BLOCKED_PHASES $blocked"
        ;;
      REQUIRED)
        echo -e "${YELLOW}⚠️  REQUIRED FAIL${NC} [$id] $desc"
        echo -e "   Got: ${result:-<empty>}"
        ((FAIL_REQUIRED++))
        BLOCKED_PHASES="$BLOCKED_PHASES $blocked"
        ;;
      OPTIONAL)
        echo -e "   ℹ️  OPTIONAL SKIP [$id] $desc"
        ((FAIL_OPTIONAL++))
        ;;
    esac
  fi
}

echo -e "\n${BOLD}pi-cortex Agent Pre-flight Checklist${NC}"
echo -e "Running on: $(hostname) as $(whoami) — $(date)\n"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${BOLD}[1] Shell Tools${NC}"
check "1.1"  "bash 4+"           CRITICAL  "bash --version | head -1 | grep -oP 'version \\K\\d+' | awk '\$1 >= 4 {print \"PASS\"}'"  "PASS" "ALL"
check "1.2"  "curl"              CRITICAL  "curl --version | head -1 | grep -oP 'curl \\K[\\d.]+'"  "[0-9]" "ALL"
check "1.3"  "python3"           CRITICAL  "python3 --version 2>&1 | grep -oP 'Python 3\\.\\d+'"  "Python 3" "ALL"
check "1.4"  "Node.js 22+"       CRITICAL  "node --version | grep -oP 'v(\\d+)' | grep -oP '\\d+' | awk '\$1 >= 22 {print \"PASS\"}'"  "PASS" "Phase2a,2b,3,5a"
check "1.5"  "npm 9+"            CRITICAL  "npm --version | grep -oP '^\\d+' | awk '\$1 >= 9 {print \"PASS\"}'"  "PASS" "Phase2a,2b,3,5a"
check "1.6"  "esbuild/tsc"       CRITICAL  "(npx --yes esbuild --version 2>/dev/null || npx tsc --version 2>/dev/null) | head -1"  "[0-9]" "Phase3"
check "1.7"  "Java 21+"          REQUIRED  "java -version 2>&1 | grep -oP '\"(\\d+)' | grep -oP '\\d+' | awk '\$1 >= 21 {print \"PASS\"}'"  "PASS" "Phase1"
check "1.8"  "git"               CRITICAL  "git --version | grep -oP 'git version \\K[\\d.]+'"  "[0-9]" "Phase10,11"
check "1.9"  "openssl"           REQUIRED  "openssl version | grep -oP 'OpenSSL \\K[\\d.]+'"  "[0-9]" "Phase0"
check "1.10" "ss"                REQUIRED  "command -v ss > /dev/null 2>&1 && echo PASS"  "PASS" "Phase9"
check "1.11" "systemctl"         CRITICAL  "systemctl --version | head -1 | grep -oP 'systemd \\K\\d+' | awk '\$1 >= 245 {print \"PASS\"}'"  "PASS" "Phase1,2a,5a"
check "1.12" "podman"            REQUIRED  "podman --version | grep -oP 'version \\K[\\d.]+'"  "[0-9]" "Phase1"

echo -e "\n${BOLD}[2] Filesystem Access${NC}"
check "2.1"  "project dir r/w"   CRITICAL  "F=/home/bzn/Projects/BzNdevOps/pi-cortex/.preflight-write-test; echo ok > \$F && cat \$F && rm \$F"  "ok" "ALL"
check "2.2"  ".pi/.env readable" CRITICAL  "[ -r /home/bzn/.pi/.env ] && stat -c '%a' /home/bzn/.pi/.env | grep -q 600 && echo PASS"  "PASS" "ALL"
check "2.3"  "/opt writable"     CRITICAL  "sudo mkdir -p /opt/knowledge-vault && echo PASS"  "PASS" "Phase1.4"
check "2.4"  "/var/lib/pi-cortex writable" REQUIRED "sudo mkdir -p /var/lib/pi-cortex/state && sudo chown bzn:bzn /var/lib/pi-cortex && touch /var/lib/pi-cortex/state/.pf && rm /var/lib/pi-cortex/state/.pf && echo PASS"  "PASS" "Phase2b"
check "2.5"  "/etc/systemd/system writable" CRITICAL "sudo touch /etc/systemd/system/.preflight-test && sudo rm /etc/systemd/system/.preflight-test && echo PASS"  "PASS" "Phase1,2a,5a"
check "2.6"  "/etc/nginx writable" REQUIRED "sudo touch /etc/nginx/sites-enabled/.preflight-test && sudo rm /etc/nginx/sites-enabled/.preflight-test && echo PASS"  "PASS" "Phase1.5"
check "2.7"  "/etc/containers/systemd writable" REQUIRED "sudo mkdir -p /etc/containers/systemd && sudo touch /etc/containers/systemd/.preflight-test && sudo rm /etc/containers/systemd/.preflight-test && echo PASS"  "PASS" "Phase1.1"
check "2.8"  "/var/backups writable" REQUIRED "sudo mkdir -p /var/backups/neo4j && sudo chown bzn:bzn /var/backups/neo4j && touch /var/backups/neo4j/.pf && rm /var/backups/neo4j/.pf && echo PASS"  "PASS" "Phase1.8,5a.3"
check "2.9"  "/var/log/pi-cortex writable" REQUIRED "sudo mkdir -p /var/log/pi-cortex && sudo chown bzn:bzn /var/log/pi-cortex && touch /var/log/pi-cortex/.pf && rm /var/log/pi-cortex/.pf && echo PASS"  "PASS" "Phase2a,2b"

echo -e "\n${BOLD}[3] Sudo Privileges${NC}"
check "3.1"  "sudo systemctl"    CRITICAL  "sudo systemctl is-system-running --quiet 2>/dev/null && echo PASS"  "PASS" "Phase1,2a,5a"
check "3.2"  "sudo podman"       REQUIRED  "sudo podman info --format '{{.Host.OS}}' 2>/dev/null | grep -qi linux && echo PASS"  "PASS" "Phase1.1"
check "3.3"  "sudo ufw"          CRITICAL  "sudo ufw status 2>/dev/null | grep -qiE 'Status:' && echo PASS"  "PASS" "Phase1.6,9"
check "3.4"  "sudo nginx -t"     REQUIRED  "sudo nginx -t 2>/dev/null && echo PASS"  "PASS" "Phase1.5"
check "3.5"  "sudo fail2ban"     REQUIRED  "sudo fail2ban-client status 2>/dev/null | grep -q 'Number' && echo PASS"  "PASS" "Phase9.3"
check "3.6"  "sudo crontab"      REQUIRED  "sudo crontab -l > /dev/null 2>&1; echo PASS"  "PASS" "Phase1.7,1.8"
check "3.7"  "htpasswd present"  REQUIRED  "which htpasswd > /dev/null 2>&1 && echo PASS || (sudo apt list --installed 2>/dev/null | grep -q apache2-utils && echo PASS)"  "PASS" "Phase1.5"

echo -e "\n${BOLD}[4] Secrets & Credentials${NC}"
check "4.1"  "API keys present/generable" CRITICAL "grep -qP '^PI_CORTEX_AGENT_KEY=sk-cortex-' /home/bzn/.pi/.env 2>/dev/null && echo PRESENT || (openssl rand -hex 32 > /dev/null 2>&1 && echo GENERABLE)"  "PRESENT|GENERABLE" "ALL"
check "4.2"  "Neo4j password"    REQUIRED  "grep -qP '^NEO4J_PASSWORD=\\S+' /home/bzn/.pi/.env 2>/dev/null && echo PRESENT || echo MISSING_GENERABLE"  "PRESENT|MISSING_GENERABLE" "Phase1"
check "4.3"  "GitHub token"      REQUIRED  "grep -qP 'ghp_' /home/bzn/.git-credentials 2>/dev/null && echo PRESENT || echo MISSING"  "PRESENT" "Phase10,11"

echo -e "\n${BOLD}[5] Network & Connectivity${NC}"
check "5.1"  "Internet (npm)"    CRITICAL  "curl -sf --max-time 5 https://registry.npmjs.org/ -o /dev/null && echo PASS"  "PASS" "Phase2a,2b,3,5a"
check "5.2"  "GitHub reachable"  REQUIRED  "curl -sf --max-time 5 https://api.github.com -o /dev/null && echo PASS"  "PASS" "Phase10,11"
check "5.3"  "bzserv local/Tailscale" CRITICAL "hostname | grep -qi bzserv && echo LOCAL || (ping -c1 -W3 100.64.144.126 > /dev/null 2>&1 && echo REACHABLE)"  "LOCAL|REACHABLE" "ALL"
check "5.4"  "port 7474 free"    REQUIRED  "ss -tlnp 2>/dev/null | grep -q ':7474' && echo IN_USE || echo PORT_FREE"  "PORT_FREE" "Phase1.1"
check "5.5"  "port 3002 free"    REQUIRED  "ss -tlnp 2>/dev/null | grep -q ':3002' && echo IN_USE || echo PORT_FREE"  "PORT_FREE" "Phase2a"

echo -e "\n${BOLD}[6] Pi Agent Environment${NC}"
check "6.1"  "Pi CLI installed"  REQUIRED  "command -v pi > /dev/null 2>&1 && echo PASS || pi --version > /dev/null 2>&1 && echo PASS"  "PASS" "Phase3"
check "6.2"  ".pi/settings.json valid" REQUIRED "cat /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/settings.json 2>/dev/null | python3 -c 'import sys,json; json.load(sys.stdin); print(\"VALID\")'"  "VALID" "Phase3"
check "6.3"  ".pi/extensions/ writable" CRITICAL "mkdir -p /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/pi-cortex && touch /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/.pf && rm /home/bzn/Projects/BzNdevOps/pi-cortex/.pi/extensions/.pf && echo PASS"  "PASS" "Phase3"
check "6.4"  "reference extensions present" REQUIRED "ls /home/bzn/Projects/BzNdevOps/pi-cortex/reference/extensions/*.ts 2>/dev/null | wc -l | awk '\$1 >= 6 {print \"PASS\"}'"  "PASS" "Phase3"

echo -e "\n${BOLD}[7] Git Configuration${NC}"
check "7.1"  "git user configured" REQUIRED "git -C /home/bzn/Projects/BzNdevOps/pi-cortex config user.name 2>/dev/null | grep -q . && echo PASS"  "PASS" "Phase10"
check "7.2"  "GitHub API with token" REQUIRED "TOKEN=\$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials 2>/dev/null | head -1); [ -z \"\$TOKEN\" ] && echo NO_TOKEN || curl -sf -H \"Authorization: token \${TOKEN}\" https://api.github.com/user | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"login\",\"\"))' | grep -q BzNdevOps && echo PASS"  "PASS|NO_TOKEN" "Phase10,11"

echo -e "\n${BOLD}[8] Existing Services Baseline${NC}"
check "8.1"  "open-webui running" REQUIRED "curl -sf --max-time 3 http://127.0.0.1:3000/ -o /dev/null && echo PASS || echo FAIL_PREEXISTING"  "PASS|FAIL_PREEXISTING" "Baseline"
check "8.2"  "voice-pi API running" REQUIRED "curl -sf --max-time 3 http://127.0.0.1:8000/health > /dev/null 2>&1 && echo PASS || echo FAIL_PREEXISTING"  "PASS|FAIL_PREEXISTING" "Baseline"
check "8.3"  "nginx config valid" CRITICAL  "sudo nginx -t 2>&1 | grep -q successful && echo PASS"  "PASS" "Phase1.5"

echo -e "\n${BOLD}[9] Disk Space & Storage${NC}"
check "9.1"  "root >5 GB free"           CRITICAL  "python3 -c \"import shutil; s=shutil.disk_usage('/'); free_gb=s.free//1024**3; print('PASS' if free_gb > 5 else 'FAIL: '+str(free_gb)+'G free')\""  "PASS" "ALL"
check "9.2"  "/mnt/wd3t >20 GB free"     REQUIRED  "python3 -c \"import shutil; s=shutil.disk_usage('/mnt/wd3t'); print('PASS' if s.free > 20*1024**3 else 'FAIL: '+str(s.free//1024**3)+'G')\" 2>/dev/null || echo FAIL_NOT_MOUNTED"  "PASS" "Phase1.7,1.8"
check "9.3"  "/opt >1 GB free"           REQUIRED  "python3 -c \"import shutil; s=shutil.disk_usage('/opt'); free_gb=s.free//1024**3; print('PASS' if free_gb > 1 else 'FAIL: '+str(free_gb)+'G')\""  "PASS" "Phase1.4"

echo -e "\n${BOLD}[10] Additional System Tools${NC}"
check "10.1" "flock"                     REQUIRED  "command -v flock > /dev/null 2>&1 && echo PASS"  "PASS" "Phase5a"
check "10.2" "restic"                    REQUIRED  "command -v restic > /dev/null 2>&1 && echo PASS"  "PASS" "Phase1.7"
check "10.3" "nginx WebDAV module"       REQUIRED  "sudo nginx -V 2>&1 | grep -q http_dav_module && echo PASS"  "PASS" "Phase1.5"
check "10.4" "pigz or gzip"             OPTIONAL   "command -v pigz > /dev/null 2>&1 && echo PASS || command -v gzip > /dev/null 2>&1 && echo PASS"  "PASS" "Phase5a.3"

echo -e "\n${BOLD}[11] Neo4j & Podman Readiness${NC}"
check "11.1" "docker.io registry"        REQUIRED  "curl -s --max-time 8 https://registry-1.docker.io/v2/ -o /dev/null -w \"%{http_code}\" | grep -qE '200|401' && echo PASS"  "PASS" "Phase1.1"
check "11.2" "neo4j not running"         REQUIRED  "sudo podman ps 2>/dev/null | grep -qi neo4j && echo IN_USE || echo PASS"  "PASS" "Phase1.1"
check "11.3" "pi-cortex-net state"       OPTIONAL  "sudo podman network exists pi-cortex-net 2>/dev/null && echo EXISTS || echo FREE"  "EXISTS|FREE" "Phase1.1"
check "11.4" "UFW tailscale rule exists" CRITICAL  "sudo ufw status 2>/dev/null | grep -qi 'tailscale' && echo PASS"  "PASS" "Phase1.6,9"
echo -e "   ${YELLOW}UFW rule order — verify tailscale ALLOW < DENY (manual review):${NC}"
{ sudo ufw status numbered 2>/dev/null | head -20 | sed 's/^/   /'; } || echo "   (ufw status unavailable)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}PREFLIGHT SUMMARY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ✅ Passed:            ${GREEN}${PASS_COUNT}${NC}"
echo -e "  ❌ Critical failures: ${RED}${FAIL_CRITICAL}${NC}"
echo -e "  ⚠️  Required failures: ${YELLOW}${FAIL_REQUIRED}${NC}"
echo -e "  ℹ️  Optional skipped:  ${FAIL_OPTIONAL}"
echo ""

if [ "$FAIL_CRITICAL" -eq 0 ] && [ "$FAIL_REQUIRED" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}🟢 VERDICT: FULLY AUTONOMOUS${NC}"
  echo "   All checks passed. The agent can complete the entire project"
  echo "   without human intervention. Proceed with TEST-PLAN.md."

elif [ "$FAIL_CRITICAL" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 VERDICT: PARTIALLY AUTONOMOUS${NC}"
  echo "   No critical failures. Agent can proceed but some phases will require"
  echo "   human attention. Blocked phases:$(echo $BLOCKED_PHASES | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  echo "   Recommendation: start coding — ask human to fix REQUIRED failures in parallel."

else
  echo -e "${RED}${BOLD}🔴 VERDICT: BLOCKED — DO NOT START${NC}"
  echo "   Critical failures must be resolved before the coding loop begins."
  echo "   Blocked areas:$(echo $BLOCKED_PHASES | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  echo "   Ask the human to fix the ❌ items above, then re-run this script."
fi

echo ""
echo "To re-run: bash /home/bzn/Projects/BzNdevOps/pi-cortex/AGENT-PREFLIGHT.md"
echo "Next step (if PASS): follow TEST-PLAN.md starting at Step 0.1"
```

---

## Section 10 — Quick Fix Reference

If the preflight reports failures, use this table to fix them before starting:

| Check | Fix command |
|-------|-------------|
| Node.js missing | `curl -fsSL https://deb.nodesource.com/setup_22.x \| sudo -E bash - && sudo apt install -y nodejs` |
| Java 21 missing | `sudo apt install openjdk-21-jre-headless` |
| podman missing | `sudo apt install podman` |
| htpasswd missing | `sudo apt install apache2-utils` |
| /opt not writable | `sudo mkdir -p /opt/knowledge-vault && sudo chown bzn:bzn /opt/knowledge-vault` |
| .pi/.env missing | `touch /home/bzn/.pi/.env && chmod 600 /home/bzn/.pi/.env` |
| PI_CORTEX keys missing | `echo "PI_CORTEX_AGENT_KEY=sk-cortex-agent-$(openssl rand -hex 32)" >> /home/bzn/.pi/.env` |
| NEO4J_PASSWORD missing | `echo "NEO4J_PASSWORD=$(openssl rand -hex 24)" >> /home/bzn/.pi/.env` |
| git user not set | `git config --global user.name "BzNdevOps" && git config --global user.email "bzndevops@gmail.com"` |
| esbuild missing | `cd app/extension && npm install -D esbuild` |
| /etc/containers/systemd missing | `sudo mkdir -p /etc/containers/systemd` |
| Tailscale cert missing | `sudo tailscale cert bzserv.tail011919.ts.net` |
| Port 7474 in use | `sudo ss -tlnp \| grep 7474` → identify process → stop it |
| Port 3002 in use | `sudo ss -tlnp \| grep 3002` → identify process → stop it |
| nginx config broken | `sudo nginx -t` → read error → fix config → `sudo nginx -t` again |
| GitHub token expired | Human must regenerate at github.com/settings/tokens |
| npm not logged in | `npm login` (interactive — requires human) |

---

## Autonomy Contract

When the preflight returns **🟢 FULLY AUTONOMOUS**, this means the agent has verified:

1. **All executables present** — can build, test, deploy
2. **All paths writable** — can create files, configs, services
3. **All sudo grants confirmed** — can manage firewall, services, containers
4. **All secrets accessible** — can authenticate to all services
5. **Network reachable** — can install deps, push code
6. **Pi environment ready** — can test extension without help
7. **No pre-existing breakage** — baseline services healthy before touching anything

**The agent is then authorized to:**
- Work through TEST-PLAN.md step by step
- Install packages, create files, deploy services, configure firewalls
- Commit and push to git
- Stop and ask the human ONLY if a test is still FAIL after 3 attempts

**The agent must NOT:**
- Expose any port to `0.0.0.0/0` (see AGENTS.md)
- Remove or reorder UFW rules without checking `ufw status numbered` first
- Skip a failing test and mark it PASS
- Break existing services (open-webui, voice-pi, nginx) — revert on regression

---

*Run this preflight before every new coding session. A clean preflight is the agent's green light.*

---

## Section 11 — Disk Space & Storage

> Silent failures from full disks are among the hardest issues to debug. Check before starting.

### 11.1 — Root partition has >5 GB free
```bash
python3 -c "import shutil; s=shutil.disk_usage('/'); free_gb=s.free//1024**3; print('PASS' if free_gb > 5 else f'FAIL: only {free_gb}G free')"
```
**PASS:** `PASS`
**Severity:** CRITICAL
**Blocked if missing:** `npm install` for API + Gardener + extension needs ~2 GB; Neo4j data dir grows over time; builds fail silently when disk is full
**Fix:** `sudo journalctl --vacuum-size=1G && sudo apt autoremove -y && sudo apt clean`

---

### 11.2 — /mnt/wd3t mounted with >20 GB free (Restic backup target)
```bash
python3 -c "import shutil; s=shutil.disk_usage('/mnt/wd3t'); print('PASS' if s.free > 20*1024**3 else f'FAIL: only {s.free//1024**3}G')" 2>/dev/null || echo "FAIL: not mounted"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.7, 1.8)
**Blocked if missing:** Restic vault backup cron (Phase 1.7) and Neo4j dump cron (Phase 1.8) fail silently
**Note:** If not mounted, the WD external drive is offline. Document as pre-existing — coding phases can proceed, but backups are broken from day one. Flag for the human.

---

### 11.3 — /opt has >1 GB free (knowledge vault landing zone)
```bash
python3 -c "import shutil; s=shutil.disk_usage('/opt'); free_gb=s.free//1024**3; print('PASS' if free_gb > 1 else f'FAIL: only {free_gb}G')"
```
**PASS:** `PASS`
**Severity:** REQUIRED (Phase 1.4)
**Blocked if missing:** `/opt/knowledge-vault/` has no room to grow — vault markdown imports silently fail as the vault grows
**Note:** `/opt` is usually on the same partition as `/`. If 11.1 passed, this almost certainly passes too.

---

## Section 12 — Additional System Tools

> Tools not covered in Section 1 but required for specific phases of the project.

### 12.1 — flock (Gardener concurrent-run guard)
```bash
flock --version 2>/dev/null | head -1 || (which flock > /dev/null 2>&1 && echo "PASS (flock in PATH)")
```
**PASS:** Version string or `PASS`
**Severity:** REQUIRED (Phase 5a — Gardener timers)
**Blocked if missing:** Multiple Gardener systemd timer instances can overlap. Two missions writing to Neo4j simultaneously cause write conflicts and corrupted pheromone weights.
**Why:** Gardener startup uses `flock /var/lock/pi-cortex-gardener` as a single-instance guard. Without `flock`, the lock is bypassed.
**Fix:** `sudo apt install util-linux` (almost always pre-installed on Ubuntu 24.04 — `which flock` may already exist)

---

### 12.2 — restic (backup tool)
```bash
restic version 2>/dev/null | head -1 || echo "MISSING"
```
**PASS:** Version string (e.g. `restic 0.16.5 compiled with go1.21...`)
**Severity:** REQUIRED (Phase 1.7, 1.8)
**Blocked if missing:** Phase 1.7 (Restic knowledge-vault cron) and Phase 1.8 (Neo4j dump cron) both call `restic` directly — both silently fail if it's not installed
**Fix:** `sudo apt install restic`

---

### 12.3 — nginx compiled with WebDAV module (`--with-http_dav_module`)
```bash
nginx -V 2>&1 | grep -oP -- '--with-http_dav_module' || sudo nginx -V 2>&1 | grep -oP -- '--with-http_dav_module'
```
**PASS:** `--with-http_dav_module`
**Severity:** REQUIRED (Phase 1.5)
**Blocked if missing:** The WebDAV location block in the nginx config for `/opt/knowledge-vault` will fail with `unknown directive "dav_methods"` on reload. Obsidian on iOS cannot write to the vault — it becomes read-only.
**Fix:** `sudo apt install nginx-full` (the base `nginx` package strips WebDAV; `nginx-full` includes it)
**After switching:** `sudo nginx -t && sudo systemctl reload nginx` — verify existing sites still load

---

### 12.4 — pigz or gzip (Neo4j dump compression for Snapshot mission)
```bash
command -v pigz > /dev/null 2>&1 && echo "pigz AVAILABLE" || \
  command -v gzip > /dev/null 2>&1 && echo "gzip AVAILABLE (fallback)" || echo "MISSING"
```
**PASS:** `pigz AVAILABLE` or `gzip AVAILABLE`
**Severity:** OPTIONAL
**Note:** Phase 5a.3 (Snapshot mission) compresses Neo4j dumps before shipping to Restic. `pigz` uses all cores and is faster for multi-GB graphs; `gzip` is the acceptable fallback. Either is fine for MVP.
**Fix (optional):** `sudo apt install pigz`

---

## Section 13 — Neo4j & Podman Readiness

> Pre-deployment checks specific to the Neo4j container and Podman network setup.

### 13.1 — Container registry reachable (docker.io)
```bash
curl -s --max-time 8 https://registry-1.docker.io/v2/ -o /dev/null -w "%{http_code}"
```
**PASS:** `401` (Unauthorized — the registry is reachable; no auth needed for public images like `neo4j:5.20-community-bullseye`)
**Severity:** REQUIRED (Phase 1.1)
**Blocked if missing:** `sudo podman pull neo4j:5.20-community-bullseye` hangs or fails
**Note:** `200` also passes. Anything other than a valid HTTP code means the registry is unreachable.

---

### 13.2 — Neo4j container not already running
```bash
sudo podman ps 2>/dev/null | grep -i neo4j || echo "NOT_RUNNING"
```
**PASS:** `NOT_RUNNING`
**Severity:** REQUIRED (Phase 1.1)
**Note:** If neo4j IS running: run `sudo systemctl status neo4j-pi-cortex` to confirm it's this project's container vs. a pre-existing one. Never stop an unknown container without identifying its owner. If it IS this project's container from a previous deploy attempt, that's fine — Phase 1.1 will use `systemctl restart`.

---

### 13.3 — Podman network pi-cortex-net status and subnet
```bash
sudo podman network inspect pi-cortex-net 2>/dev/null \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
subnet = d[0].get('subnets', [{}])[0].get('subnet', 'unknown')
print(f'EXISTS — subnet: {subnet}')
print('Verify: no overlap with hermes-net (10.89.1.0/24)')
" 2>/dev/null || echo "FREE — will be created at Phase 1.1"
```
**PASS:** `EXISTS` (verify subnet is not `10.89.1.x`) or `FREE`
**Severity:** OPTIONAL
**Note:** The pi-cortex API container network must NOT overlap with `hermes-net` (`10.89.1.0/24` — used by open-webui and whisper). Recommended subnet for pi-cortex: `10.89.2.0/24`.
**If conflict detected:** Update the Quadlet `Network=` field to use a free subnet before Phase 1.1.

---

### 13.4 — UFW rules: Tailscale ALLOW before DENY (MANUAL REVIEW)
```bash
sudo ufw status numbered 2>/dev/null | head -30
```
**PASS:** MANUAL — the agent must confirm both of the following:
1. A rule for `ALLOW IN on tailscale0` (or `Anywhere on tailscale0`) exists
2. That rule's number is **lower** than any generic `DENY` rule for the same port range

**Severity:** CRITICAL (security safety check — must not regress)

**Rule from AGENTS.md:** `ALLOW on tailscale0` MUST appear before `DENY` in UFW rule order. The **first matching rule wins** in UFW.

**Correct order — SAFE:**
```
[ 1] Anywhere on tailscale0        ALLOW IN    Anywhere
[ 5] 22/tcp                        DENY IN     Anywhere
```
Rule 1 (tailscale ALLOW) before Rule 5 (DENY) = **correct**, Tailscale SSH works

**Wrong order — LOCKED OUT:**
```
[ 3] 22/tcp                        DENY IN     Anywhere
[ 7] Anywhere on tailscale0        ALLOW IN    Anywhere
```
Rule 3 (DENY) before Rule 7 (tailscale ALLOW) = **wrong**, SSH via Tailscale is denied before the ALLOW can match

**Fix (if wrong):**
```bash
# Get the number of the misplaced DENY rule
sudo ufw status numbered | grep -i '22/tcp.*DENY'
# Delete it and re-add in correct position
sudo ufw delete <deny_rule_number>
sudo ufw insert 1 allow in on tailscale0
sudo ufw reload
```

**Agent rule:** If the Tailscale ALLOW rule is missing entirely, **stop and ask the human to restore it** before adding any pi-cortex UFW rules. Adding DENY rules for new ports without the Tailscale ALLOW in place would lock out all remote access to bzserv. This is irreversible without physical or OOB access.

---

*Sections 11–13 added 2026-05-04: disk space, additional tools (flock, restic, nginx-webdav, gzip), and Neo4j/Podman readiness including UFW safety review.*
