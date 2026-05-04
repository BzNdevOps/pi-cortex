# RUN-GUIDE.md — Lancer l'agent Qwen3.6 sur pi-cortex

---

## Prérequis — vérifier une seule fois avant la première session

```bash
# 1. Qwen3.6 est-il chargé en VRAM ?
curl -sf http://100.64.144.126:11435/v1/models | python3 -m json.tool | grep id

# Si le service n'est pas démarré :
sudo systemctl start llama-qwen.service
# Attendre ~40 secondes (chargement VRAM), puis re-vérifier
```

```bash
# 2. Vérifier l'état du projet
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json
```

---

## Démarrer une session — une seule commande

```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et commence."
```

Pi utilise Qwen3.6 par défaut (configuré dans `.pi/settings.json`).

**Ce que fait l'agent automatiquement :**
1. Lit `START-HERE.md`
2. Lit `session-state.json` → identifie la session courante
3. Lit `SESSIONS.md` → charge uniquement les phases de la session via `sed`
4. Lit uniquement les docs de référence pertinents (pas tout PLAN-OPUS.md)
5. Exécute les étapes : lire → implémenter → tester → PASS/DEFERRED → checkpoint
6. Envoie une notification Telegram en fin de phase

---

## Séquence des 5 sessions

Lancer chaque session après la notification Telegram de fin de la précédente.

### Session 1 — Infrastructure (Phase 0 + 1)
```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et commence."
```
**Ce qui sera fait :** Neo4j via Podman Quadlet, contraintes Cypher, nginx WebDAV,
vault `/opt/knowledge-vault/`, règles UFW, backups Restic.

**Durée estimée :** 30–60 min
**Notification Telegram :** `[pi-cortex] Phase 1 done 🏗️`

---

### Session 2 — API Server (Phase 2a)
```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et continue."
```
**Ce qui sera fait :** API REST TypeScript (Express + Neo4j driver), endpoint `/api/health`,
auth `X-API-Key`, stemmer Porter-lite, scoring lexical, routage catégoriel, service systemd.

**Durée estimée :** 45–90 min
**Notification Telegram :** `[pi-cortex] Phase 2a done ⚙️`

---

### Session 3 — Watcher + Extension Pi (Phase 2b + 3)
```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et continue."
```
**Ce qui sera fait :** Watcher chokidar (polling 1s, debounce 500ms), réconciliation vault,
endpoints d'écriture avec 409 Conflict, ACO batch flush.
Extension Pi : 7 outils `memory_*`, hooks `before_agent_start` / `tool_call` /
`session_before_compact`, build esbuild → `.pi/extensions/pi-cortex/index.ts`.

**Durée estimée :** 60–120 min
**Notification Telegram :** `[pi-cortex] Phase 3 done 🧩`

---

### Session 4 — Skills + Gardener MVP (Phase 4 + 5a)
```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et continue."
```
**Ce qui sera fait :** 6 fichiers SKILL.md, 2 prompt templates.
Gardener : 7 missions MVP (évaporation ACO, versioning, provenance, cross-références,
fraîcheur, perf Neo4j, snapshot), timers systemd.

**Durée estimée :** 45–90 min
**Notification Telegram :** `[pi-cortex] Phase 5a done — MVP ready! 🌱`

---

### Session 5 — Hardening + Release + E2E (Phase 8 + 9 + 10 + 11 + E2E)
```bash
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi "Lis START-HERE.md et continue."
```
**Ce qui sera fait :** Endpoint `/metrics` (Prometheus), alertes Telegram santé,
durcissement sécurité (bindings 127.0.0.1, fail2ban WebDAV, auditd),
4 runbooks, `npm pack`, test E2E complet.

**Durée estimée :** 45–75 min
**Notification Telegram :** `[pi-cortex] 🚀 PROJET TERMINÉ — E2E PASS`

---

## Reprendre après une interruption

```bash
# Reprendre la session en cours (Pi restaure la conversation) :
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi --continue

# Choisir manuellement une session à reprendre :
cd /home/bzn/Projects/BzNdevOps/pi-cortex
pi --resume
```

Si l'agent s'est arrêté entre deux sessions (pas au milieu d'une) :
```bash
# Vérifier où on en est :
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json

# Relancer normalement :
pi "Lis START-HERE.md et continue."
```

---

## Suivre la progression sans surveiller le terminal

Les notifications Telegram sont envoyées automatiquement après chaque phase.

Format des messages :
```
[pi-cortex] Phase 2a done ⚙️

Steps done:
• 2a.1 Node.js/TypeScript project initialisé
• 2a.2 Health endpoint + neo4j-driver pool
• 2a.3 Auth middleware X-API-Key
• 2a.4 Stemmer Porter-lite + scoring lexical
• 2a.5 Scoring combiné + budget tokens
• 2a.6 Routage catégoriel (9 catégories)
• 2a.7 Service systemd pi-cortex-api actif

✅ No blocked steps

Next: Phase 2b — Watcher + Write Endpoints
```

---

## Budget contexte par session

| Session | Phases | Tokens chargés | Tokens disponibles |
|---------|--------|---------------|-------------------|
| S1 | 0 + 1 | ~45K / 125K | ~80K pour le code |
| S2 | 2a | ~55K / 125K | ~70K pour le code |
| S3 | 2b + 3 | ~65K / 125K | ~60K pour le code |
| S4 | 4 + 5a | ~50K / 125K | ~75K pour le code |
| S5 | 8+9+10+11+E2E | ~45K / 125K | ~80K pour le code |

L'agent ne charge **jamais** `TEST-PLAN.md` complet (1500 lignes = 20K tokens).
Il utilise `sed -n 'X,Yp'` pour extraire uniquement les phases de la session.

---

## En cas de blocage répété

Si une étape échoue 3 fois, l'agent la marque DEFERRED et continue :
```bash
# Voir les étapes bloquées :
cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/blocked-steps.json
```

Pour débloquer manuellement une étape, intervenir directement :
```bash
# Exemple : Neo4j ne démarre pas
sudo systemctl status neo4j.service
sudo podman logs neo4j --tail 30

# Puis relancer l'agent sur l'étape suivante :
pi "Lis START-HERE.md et continue depuis l'étape <N>."
```

---

## Résumé visuel

```
Tu tapes : pi "Lis START-HERE.md et commence."
                ↓
Pi lit   : START-HERE.md → SESSIONS.md → session-state.json
                ↓
Pi charge: sed -n '1,392p' TEST-PLAN.md   (Phase 0+1 seulement, ~5K tokens)
           cat reference/docs/podman-quadlet.md
           cat reference/docs/neo4j-5x-cypher.md
                ↓
Pi boucle: lire étape → implémenter → tester → PASS → checkpoint → suivante
                ↓  (fin de session)
Telegram : "[pi-cortex] Phase 1 done 🏗️"
                ↓
Tu tapes : pi "Lis START-HERE.md et continue."   ← session suivante
```

**Interaction humaine totale : 5 commandes sur 2 à 4 heures.**
