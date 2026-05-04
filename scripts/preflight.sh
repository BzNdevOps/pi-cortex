#!/usr/bin/env bash
# pi-cortex Agent Pre-flight Runner
# Extracted from AGENT-PREFLIGHT.md Section 9.1
# Run from: /home/bzn/Projects/BzNdevOps/pi-cortex/
# Usage: bash scripts/preflight.sh
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

# Resume hint
LAST=$(cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_completed_step','none'))" 2>/dev/null || echo "none")
echo -e "  ${BOLD}Last completed step:${NC} ${LAST}"
echo -e "  → Resume TEST-PLAN.md from next step after: ${LAST}\n"

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
check "5.4"  "port 7474 free"    REQUIRED  "ss -tlnp 2>/dev/null | grep -q ':7474' && echo IN_USE || echo PORT_FREE"  "PORT_FREE|IN_USE" "Phase1.1"
check "5.5"  "port 3002 free"    REQUIRED  "ss -tlnp 2>/dev/null | grep -q ':3002' && echo IN_USE || echo PORT_FREE"  "PORT_FREE" "Phase2a"

echo -e "\n${BOLD}[6] Pi Agent Environment${NC}"
check "6.1"  "Pi CLI installed"  REQUIRED  "command -v pi > /dev/null 2>&1 && echo PASS"  "PASS" "Phase3"
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
check "11.2" "neo4j container state"     REQUIRED  "sudo podman ps 2>/dev/null | grep -qi neo4j && echo RUNNING || echo NOT_RUNNING"  "RUNNING|NOT_RUNNING" "Phase1.1"
check "11.3" "pi-cortex-net state"       OPTIONAL  "sudo podman network exists pi-cortex-net 2>/dev/null && echo EXISTS || echo FREE"  "EXISTS|FREE" "Phase1.1"
check "11.4" "UFW tailscale rule exists" CRITICAL  "sudo ufw status 2>/dev/null | grep -qi 'tailscale' && echo PASS"  "PASS" "Phase1.6,9"

# UFW order check (automated)
echo -e "\n  ${BOLD}UFW rule order check (ALLOW tailscale0 < DENY):${NC}"
ALLOW_NUM=$(sudo ufw status numbered 2>/dev/null | grep -P 'ALLOW.*tailscale0|tailscale0.*ALLOW' | grep -oP '^\[\s*\K\d+' | head -1)
DENY_NUM=$(sudo ufw status numbered 2>/dev/null | grep -P 'DENY' | grep -oP '^\[\s*\K\d+' | head -1)
if [ -n "$ALLOW_NUM" ] && [ -n "$DENY_NUM" ]; then
  if [ "$ALLOW_NUM" -lt "$DENY_NUM" ]; then
    echo -e "  ${GREEN}✅ UFW order correct${NC}: ALLOW tailscale0 [${ALLOW_NUM}] < DENY [${DENY_NUM}]"
    ((PASS_COUNT++))
  else
    echo -e "  ${RED}❌ UFW order WRONG${NC}: DENY [${DENY_NUM}] before ALLOW tailscale0 [${ALLOW_NUM}] — SSH via Tailscale BLOCKED"
    ((FAIL_CRITICAL++))
    BLOCKED_PHASES="$BLOCKED_PHASES Phase1.6,9"
  fi
else
  echo -e "  ${YELLOW}⚠️  Cannot determine UFW order${NC} — run: sudo ufw status numbered"
fi

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
  echo "   All checks passed. Proceed with TEST-PLAN.md from step: ${LAST}"

elif [ "$FAIL_CRITICAL" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 VERDICT: PARTIALLY AUTONOMOUS${NC}"
  echo "   No critical failures. Agent can proceed but some phases will require"
  echo "   attention. Blocked phases:$(echo $BLOCKED_PHASES | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  echo "   Start coding — fix REQUIRED failures when their phase is reached."

else
  echo -e "${RED}${BOLD}🔴 VERDICT: BLOCKED — DO NOT START${NC}"
  echo "   Critical failures must be resolved before the coding loop begins."
  echo "   Blocked areas:$(echo $BLOCKED_PHASES | tr ' ' '\n' | sort -u | tr '\n' ' ')"
fi

echo ""
echo "Next step: follow TEST-PLAN.md starting after step '${LAST}'"
echo "Blocked steps tracker: .context/blocked-steps.json"
