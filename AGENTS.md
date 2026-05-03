# pi-cortex — Agent Instructions

> **Projet :** Système de mémoire persistante pour agents Pi (Neo4j + API + Obsidian)
> **Déploiement :** bzserv (local), VM1 (proxy public)
> **Statut actuel :** Architecture validée, infrastructure à déployer

---

## Rôle du projet

`pi-cortex` fournit une mémoire persistante aux agents Pi via un graphe de connaissance Neo4j.
Quand tu travailles sur ce projet, tu es soit en train de **déployer l'infrastructure**, soit de **coder l'API/l'extension/le gardener**, soit de **maintenir les connaissances**.

---

## Structure du projet

```
pi-cortex/
├── README.md              ← Vue d'ensemble
├── PLAN.md                ← Architecture détaillée, specs, phases
├── AGENT_HANDOVER.md      ← Contexte pour le prochain agent
├── AGENTS.md              ← Ce fichier — instructions pour l'agent Pi
├── app/                   ← Code source (API, extension, gardener, watcher)
├── knowledge/global/      ← Connaissances packagées (5 fichiers .md)
├── skills/                ← Skills Pi (mem-start, mem-status...)
├── prompts/               ← Prompt templates
└── docs/                  ← Documentation
```

---

## Commandes disponibles

```bash
# Tests (quand le code existera)
npm test

# Vérifier la cohérence des fichiers de connaissance
python3 -c "
import json, os
for f in ['taxonomy.json','weights.json']:
    json.load(open(f'.pi/knowledge/{f}'))
print('OK')
"

# Lancer l'API en local
cd app/api-server && npm start

# Vérifier Neo4j
curl http://127.0.0.1:7474
```

---

## Infrastructure BzN (contexte global)

### Topologie réseau

```
Internet ──► Cloudflare (CDN + Tunnel) ──► VM1 (OCI Paris)
                                               │
                                          Tailscale WireGuard
                                               │
                                         bzserv (local, RTX 5070 Ti)
```

| Node | Rôle | IP Tailscale | Accès |
|------|------|-------------|-------|
| **bzserv** | Serveur AI local | `100.64.144.126` | SSH direct / `bzserv.tail011919.ts.net` |
| **VM1** | Proxy public OCI | `100.110.99.95` | SSH `vm1` alias |
| **VM2** | Private OCI | `10.0.1.x` | `ProxyJump vm1` |

- **Tailnet :** `tail011919.ts.net`
- **Cloudflare Tunnel ID :** `7f1c8af8-62f1-4996-b902-03e8d1f25812`

### Services actuels bzserv

| Service | Port | Bind | Notes |
|---------|------|------|-------|
| Ollama (Podman) | `11434` | hermes-net (interne) | GPU, model `gemma4:e4b` |
| Open WebUI (Podman) | `8080` | `10.89.1.10` | Proxy nginx :3000 |
| Whisper ASR (Podman) | `9000` | `10.89.1.4` | Model `large-v3` |
| voice-pi FastAPI | `8000` | `127.0.0.1` | Auth `X-API-Key` |
| llama-qwen | `11435` | `100.64.144.126` | Auth Bearer token |
| SearXNG (Podman) | `8888` | `127.0.0.1` | Recherche privée |
| nginx local | `3000`, `7788` | `100.64.144.126` | Proxy inter-conteneurs |

> ⚠️ **Jamais de `PublishPort`** — bug netavark Ubuntu 24.04. Toujours utiliser nginx proxy local.

### Infrastructure cible pi-cortex

| Composant | Machine | Port | Bind | Statut |
|-----------|---------|------|------|--------|
| **Neo4j Community** (Podman) | bzserv | `7474` HTTP, `7687` Bolt | `127.0.0.1` (nginx proxy) | ⬜ À déployer |
| **API Server** (Node.js/Express) | bzserv | `3001` | `127.0.0.1` (nginx proxy) | ⬜ À coder |
| **nginx WebDAV** | bzserv | `443` | `100.64.144.126` | ⬜ À configurer |
| **Vault Markdown** | bzserv | — | `/opt/knowledge-vault/` | ⬜ À créer |
| **Extension Pi** | bzserv | — | Chargée par Pi | ⬜ À coder |
| **Gardener** (systemd timer) | bzserv | — | Appelle l'API locale | ⬜ À coder |
| **nginx proxy** | VM1 | `443` | Proxy → `100.64.144.126:3001`, `:7474`, WebDAV | ⬜ À configurer |

### Podman réseaux bzserv

| Réseau | Subnet | Usage |
|--------|--------|-------|
| `hermes-net` | `10.89.1.0/24` | Conteneurs isolés (ollama, open-webui, whisper) |
| `ollama-pull` | — | Internet uniquement (download modèles) |

Neo4j sera sur `hermes-net` ou un nouveau réseau dédié `cortex-net`.

---

## Conventions

### Code
- API Server : Node.js + Express, port 3001, stdio uniquement (pas de framework lourd)
- Extension Pi : TypeScript, `pi.registerTool()` + hooks cycle de vie
- Gardener : skill Pi exécuté via systemd timer (`pi --model ... "/skill:mem-validate"`)
- Tous les appels Neo4j passent par le driver officiel `neo4j-driver`

### Connaissances
- Fichiers `.md` avec frontmatter YAML (format `codex-claude-memory-autopilot`)
- `taxonomy.json` : mapping catégories → fichiers
- `weights.json` : poids ACO (pheromone, uses, last_used)
- Noms de fichiers : `NN-description.md` (ex: `02-validated-architecture.md`)

### Git
- Ne jamais commiter `node_modules/` ou `.env`
- `PLAN.md` mis à jour quand le statut d'une phase change
- `AGENT_HANDOVER.md` mis à jour à chaque fin de session

---

## ⚠️ Sécurité (NON-NÉGOCIABLE)

### Directive agent : NE PAS DÉGRADER LA SÉCURITÉ

Toute modification réseau, firewall, SSH, conteneurs ou services **doit préserver ou améliorer** la posture de sécurité existante. En cas de doute sur UFW/iptables, SSH hardening, auditd, fail2ban, Tailscale → **stop et demande avant d'exécuter**.

### Posture actuelle bzserv

| Score global | MITRE Coverage |
|:---:|:---:|
| **8.5/10** | ~80% |

**Couches de défense actives :**
- SSH : `PasswordAuthentication no`, `PermitRootLogin no`, `MaxAuthTries 3`, `AllowUsers` restreint
- SSH keys : `from="100.64.0.0/10"` + `no-agent-forwarding,no-port-forwarding,no-X11-forwarding`
- Fail2ban : 6 jails, `maxretry=3`, `bantime=24h`
- Auditd : 354 règles Neo23x0
- Kernel : `kptr_restrict=2`, `ptrace_scope=2`, `unprivileged_bpf_disabled=1`, `bpf_jit_harden=2`
- UFW : deny default + egress allowlist, `ALLOW on tailscale0` AVANT `DENY`
- AIDE daily + debsums weekly + Telegram alerts
- Restic backups daily → `/mnt/wd3t/backups/`

### Règles réseau

| Règle | Détail |
|-------|--------|
| **Jamais `0.0.0.0/0`** | Toujours `127.0.0.1` ou IP Tailscale `100.64.x.x` |
| **Pas de `PublishPort`** | Bug netavark → nginx proxy local obligatoire |
| **UFW : ordre critique** | `ALLOW on tailscale0` **avant** `DENY` générique |
| **Toujours vérifier** `sudo ufw status numbered` | Avant toute modification |
| **Préférer nginx proxy + réseau Podman interne** | Pas de port exposé directement |
| **Utiliser les IPs Tailscale** `100.64.x.x` | Pour `proxy_pass`, restrictions `from=`, firewall |
| **Vérifier la chaîne complète** après modif | local → Tailscale → URL publique |

### Règles code

| Règle | Contexte |
|-------|----------|
| **`os.replace(tmp, target)`** | Écritures atomiques, jamais directes |
| **`subprocess timeout`** | Tout appel externe a un timeout |
| **Secrets dans `.env` UNIQUEMENT** | `/home/bzn/.pi/.env` (`chmod 600`). Jamais git. |
| **Ne jamais modifier `AGENTS.md` ou `CLAUDE.md` auto** | Surface pour review manuelle |
| **Neo4j : écritures transactionnelles** | Pas de writes partiels |
| **Images Podman par SHA256 digest** | Épingler le hash, pas le tag |
| **Défense en profondeur > commodité** | En cas de doute, le plus sécurisé gagne |

### Ports à exposer (pi-cortex)

| Port | Service | Bind | UFW requis |
|------|---------|------|------------|
| `3001` | API pi-cortex | `127.0.0.1` | `ALLOW on tailscale0 to 100.64.144.126 port 3001` |
| `7474` | Neo4j HTTP | `127.0.0.1` | Pas d'accès direct (via nginx proxy) |
| `7687` | Neo4j Bolt | `127.0.0.1` | Pas d'accès direct |
| WebDAV | nginx | `100.64.144.126` | Intégré dans le flux nginx existant |

> ⚠️ **Avant d'ajouter une règle UFW :** `sudo ufw status numbered` → insérer au bon index.

---

## Workflows standards

### 1. Déployer un composant

```bash
# 1. Lire PLAN.md → section 11 (Phases)
# 2. Identifier la phase et l'étape
# 3. Exécuter
# 4. Valider (curl, systemctl status, logs)
# 5. Mettre à jour AGENT_HANDOVER.md
```

### 2. Ajouter une connaissance

```bash
# Via Obsidian (humain)
1. Ouvrir l'app → éditer le fichier .md → sauvegarder
2. WebDAV sync automatique → bzserv
3. Watcher API détecte le changement → met à jour Neo4j

# Via agent Pi (automatique)
memory_record_lesson(content, project, category)
→ écrit dans Neo4j (status: draft)
→ Gardener valide + promeut
```

### 3. Valider l'état du graphe

```bash
curl http://127.0.0.1:3001/api/health
# Attendu :
# {
#   "total_nodes": ...,
#   "active_nodes": ...,
#   "draft_nodes": ...,
#   "avg_confidence": 0.87,
#   "contradictions": 0,
#   "gaps_flagged": 3
# }
```

### 4. Exécuter le gardener manuellement

```bash
pi -p --model gemini-flash \
   --system-prompt "Tu es le Knowledge Gardener de pi-cortex. Consulte PLAN.md section 7 pour tes missions." \
   "/skill:mem-validate --scope=all"
```

---

## Modèle Neo4j (référence rapide)

```cypher
// Nœuds principaux
(:Knowledge {
  id, title, content, category, status,
  confidence, uses, last_used, pagerank,
  freshness_score, source_agent, source_url,
  valid_from, valid_to, version_id
})

// Relations principales
(:Knowledge)-[:RELATED_TO {pheromone, last_used}]->(:Knowledge)
(:Project)-[:HAS_KNOWLEDGE]->(:Knowledge)
(:Knowledge)-[:SUPERSEDED_BY]->(:Knowledge)
(:Knowledge)-[:CONTRADICTS]->(:Knowledge)
(:Knowledge)-[:SIMILAR_TO {score}]->(:Knowledge)
```

---

## API (référence rapide)

| Endpoint | Méthode | Usage |
|----------|---------|-------|
| `/api/search?q=&category=&level=compact` | GET | Recherche |
| `/api/knowledge/:id` | GET | Lire |
| `/api/knowledge` | POST | Créer/modifier |
| `/api/lesson` | POST | Soumettre leçon (draft) |
| `/api/graph/related/:id` | GET | Voisins + poids |
| `/api/weights/top` | GET | Top par poids ACO |
| `/api/health` | GET | Santé graphe |
| `/api/feedback` | POST | Feedback agent |

---

## Dépendances

- **Neo4j Community Edition 5.x** (Podman Quadlet)
- **Node.js 22+** (API Server)
- **nginx** (WebDAV + proxy local)
- **Obsidian** (humain, iPhone + Laptop)
- **SearXNG** (sur bzserv, pour validation web du gardener)

## SSH Aliases

```
Host bzserv
    HostName 100.64.144.126
    User bzn
    IdentityFile ~/.ssh/id_ed25519

Host vm1
    HostName 100.110.99.95
    User ubuntu
    IdentityFile ~/.ssh/VM1-Oracle-ssh-key-2026-02-23.key

Host vm2
    HostName 10.0.1.82
    User ubuntu
    IdentityFile ~/.ssh/VM2-ssh-key-2026-03-03.key
    ProxyJump vm1
```

## Secrets (emplacements uniquement — jamais les valeurs)

| Secret | Fichier | Permissions |
|--------|---------|-------------|
| `OPENROUTER_API_KEY` | `/home/bzn/.pi/.env` | `600` |
| `INTERNAL_API_KEY` | `/home/bzn/.pi/.env` | `600` |
| `BOT_TOKEN` | `/home/bzn/.pi/.env` | `600` |
| `HF_TOKEN` | `/home/bzn/.pi/.env` | `600` |
| `GITHUB_TOKEN` | `/home/bzn/.git-credentials` | `600` |
| llama-qwen API key | `/etc/systemd/system/llama-qwen.service` | `644` |
| Pi providers config | `/home/bzn/.pi/agent/models.json` | `644` |
| Restic backup password | `/etc/restic-password` | `600` (root) |

### Git credentials (comment les utiliser)

Les credentials GitHub sont stockés dans `~/.git-credentials` (format `store`) :

```bash
# Voir l'utilisateur
cat ~/.git-credentials | grep -oP '//[^:]+'

# Extraire le token
TOKEN=$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials)

# Utiliser pour les API GitHub
curl -H "Authorization: token $TOKEN" https://api.github.com/user

# Pusher via HTTPS avec token
TOKEN=$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials)
git remote set-url origin "https://BzNdevOps:${TOKEN}@github.com/BzNdevOps/<repo>.git"
git push -u origin main

# Créer un repo via API
TOKEN=$(grep -oP 'ghp_[^@]+' /home/bzn/.git-credentials)
curl -s -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"mon-repo","description":"...","private":false}' \
  https://api.github.com/user/repos
```

> ⚠️ **Ne jamais afficher le token** dans les logs, commits, ou réponses visibles. Toujours utiliser `$(grep ...)` pour l'injecter sans l'afficher.
> ⚠️ **SSH vers GitHub ne fonctionne pas sur bzserv** — la clé `id_ed25519` n'est pas enregistrée sur GitHub. Toujours utiliser HTTPS + token.

---

## Références

| Document | Usage |
|----------|-------|
| `PLAN.md` | Architecture complète, specs, 8 phases de déploiement |
| `AGENT_HANDOVER.md` | Contexte pour le prochain agent |
| `/home/bzn/Projects/BzNdevOps/codex-claude-memory-autopilot/` | Projet source d'inspiration |
| `/home/bzn/CLAUDE.md` | Contexte global infrastructure BzN |
| `/home/bzn/.pi/agent/settings.json` | Configuration Pi (modèles, providers) |