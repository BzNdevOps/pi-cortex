# AGENT_HANDOVER.md — pi-cortex

> **Dernière mise à jour :** 2026-05-04
> **Statut :** ✅ Architecture validée, ✅ Phase 0.1 + 1.1 faites, ⬜ Phase 0.2–11 à faire
> **Plan de référence :** `PLAN-OPUS.md` (11 phases — PAS `PLAN.md` qui est obsolète)

---

## Démarrage rapide pour le prochain agent

```
1. Lancer le preflight :
   bash /home/bzn/Projects/BzNdevOps/pi-cortex/scripts/preflight.sh

2. Vérifier l'état de la session :
   cat /home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json

3. Ouvrir TEST-PLAN.md et commencer à l'étape indiquée par last_completed_step
   → Si session-state absent ou vide : commencer à Step 0.2

4. Spec complète : PLAN-OPUS.md
   Algorithmes : ALGORITHMS.md
```

### Progression actuelle

| Phase | Étapes faites | Étapes restantes |
|-------|--------------|-----------------|
| Phase 0 (Prérequis) | **0.1** ✅ (clés API générées) | 0.2 → 0.6 |
| Phase 1 (Infrastructure) | **1.1** ✅ (Neo4j Podman Quadlet) | 1.2 → 1.8 |
| Phase 2a–11 | — | toutes |

**Prochaine étape : TEST-PLAN.md Step 0.2** (Java 21 vérifié)

---

## Règles de la boucle autonome

L'agent suit ces règles sans exception :

1. **Ne jamais sauter une étape non-OPTIONAL** sans avoir exécuté son test
2. **Après 3 tentatives FAIL** → écrire dans `.context/blocked-steps.json`, marquer `[DEFERRED]`, passer à l'étape suivante indépendante
3. **Après chaque étape PASS** → mettre à jour `.context/session-state.json` avec `last_completed_step`
4. **À la fin de chaque phase** → `git commit -m "feat: phase Xa complete"`
5. **Ne jamais exposer un port sur `0.0.0.0`** (voir AGENTS.md)
6. **Ne jamais réordonner les règles UFW** sans vérifier `ufw status numbered`

---

## Ce qui a été fait (historique)

### Session 2026-05-03 (Design)
1. Analyse de `codex-claude-memory-autopilot`
2. Étude de la documentation Pi (extensions, skills, packages)
3. Design macro de pi-cortex — knowledge cortex natif Pi
4. Audit Opus 4.7 → `PLAN-OPUS.md` (11 phases, 8 findings critiques résolus)
5. Création : `README.md`, `PLAN.md`, `PLAN-OPUS.md`, `TEST-PLAN.md`, `AGENT-PREFLIGHT.md`, `ALGORITHMS.md`

### Session 2026-05-04 (Phase 0.1 + 1.1)
1. Phase 0.1 : Génération des 3 clés `PI_CORTEX_*_KEY` → `/home/bzn/.pi/.env` (chmod 600)
2. Phase 1.1 : Déploiement Neo4j Community 5.x via Podman Quadlet (`/etc/containers/systemd/neo4j.container`)
3. Commit : `deb0c44 🟢 Pre-flight Pass + Phase 0.1 & 1.1 Implementation`

---

## Décisions architecturales validées

| # | Question | Décision |
|---|----------|----------|
| 1 | Package auto-suffisant vs framework | **Hybride** — socle global + mémoire projet |
| 2 | Stockage | `/opt/knowledge-vault/` Markdown (source vérité) + Neo4j (index dérivé) |
| 3 | Base de données | **Neo4j Community 5.x** (Podman, heap 2 GB) |
| 4 | Interface humaine | **Obsidian + WebDAV** (iPhone + Laptop) |
| 5 | Conflit Obsidian/API | **Markdown wins** — content_hash + 409 Conflict |
| 6 | Auth | **X-API-Key** — 3 clés (AGENT/GARDENER/SUBAGENT) dans `/home/bzn/.pi/.env` |
| 7 | Watcher | **chokidar** polling 1s + debounce 500ms (WebDAV iOS) |
| 8 | Sub-agents | **Hybrid Option E** — read filtré, write pending-review, fallback static block |
| 9 | Gardener | **7 missions MVP** (Node.js pur, pas de Pi session) + 10 différées |
| 10 | GDS | Requis, install Phase 1.2 — missions 4/9 dégradent si absent |

---

## Architecture

```
iPhone/Laptop (Obsidian) ──WebDAV (TLS Tailscale)──► bzserv:/opt/knowledge-vault/
                                                           │ chokidar watcher
Agent Pi (extension)     ──X-API-Key──► API Server (Node.js 127.0.0.1:3002) ──► Neo4j (127.0.0.1:7687)
Sub-agents               ──API Level 3──► write pending-review/ only
Gardener                 ──systemd timers──► 7 missions MVP
VM1                      ──nginx proxy──► Tailscale (optionnel, Phase 6)
```

---

## Fichiers de référence

| Fichier | Rôle |
|---------|------|
| `PLAN-OPUS.md` | **Spec d'exécution** (11 phases, audit Opus 4.7) |
| `TEST-PLAN.md` | **Boucle de codage** — 1 test par étape, PASS/FAIL/hints |
| `AGENT-PREFLIGHT.md` | Checklist d'environnement (13 sections) |
| `scripts/preflight.sh` | Runner exécutable du preflight |
| `ALGORITHMS.md` | 15 algorithmes à implémenter (phases 2a–5b) |
| `AGENTS.md` | Règles de sécurité, secrets, tokens GitHub |
| `.context/session-state.json` | État courant de la session (last_completed_step) |
| `.context/blocked-steps.json` | Étapes bloquées après 3 tentatives |

---

## Contraintes de sécurité non-négociables

| Règle | Détail |
|-------|--------|
| **Jamais `0.0.0.0`** | API :3002, Neo4j :7474/:7687 → bind `127.0.0.1` uniquement |
| **Pas de `PublishPort`** | Bug netavark Ubuntu 24.04 → nginx proxy local |
| **Tout sur Tailscale** | Inter-nodes via `100.64.x.x` |
| **UFW order matters** | `ALLOW on tailscale0` AVANT tout `DENY` — vérifier avec `ufw status numbered` |
| **systemd Quadlet** | `/etc/containers/systemd/neo4j.container` |
| **Secrets dans `.pi/.env`** | chmod 600, jamais dans les logs (pino redact) |
