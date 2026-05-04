# AGENT_HANDOVER.md — pi-cortex

> **Session :** 2026-05-03 — Design macro
> **Statut :** ✅ Architecture entièrement validée, ❌ Aucun code écrit, ❌ Aucun déploiement
> **Prochain agent :** Commencer le déploiement (Phase 1)

---

## Ce qui a été fait dans cette session

1. Analyse approfondie du projet `codex-claude-memory-autopilot` (système de mémoire pour Codex/Claude)
2. Étude de la documentation Pi : extensions, skills, prompts, packages, TUI
3. Design macro de `pi-cortex` — système équivalent 100% natif Pi
4. Audit de performance : VM1 (954 MB → pas viable), bzserv (15 GB → déploiement complet)
5. Validation de 4 questions architecturales clés
6. Extension du Knowledge Gardener à 17 missions (recherche internet)
7. Création des documents : README.md, PLAN.md, AGENT_HANDOVER.md

---

## Décisions validées

| # | Question | Décision |
|---|----------|----------|
| 1 | Package auto-suffisant vs framework | **Hybride** — socle global + mémoire projet |
| 2 | Où stocker les connaissances | `/opt/knowledge-vault/` Markdown + Neo4j, sur **bzserv** |
| 3 | Technologie base de données | **Neo4j Community Edition** (Podman, heap 2 GB) |
| 4 | Interface humaine | **Obsidian + WebDAV** (iPhone + Laptop) |
| 5 | Extraction connaissances | Agent → pending-review → Gardener → promu |
| 6 | Agent validateur | **Knowledge Gardener** — 17 missions autonomes |
| 7 | Sub-agents | **Option E** : Read filtré, Write pending-review, fallback injection au fork |

---

## Architecture résumée

```
iPhone/Laptop (Obsidian) ──WebDAV──→ bzserv:/opt/knowledge-vault/
Agent Pi (extension)     ──API REST──→ API Server (Node.js :3002) → Neo4j
Sub-agents               ──API REST──→ filtré par catégorie, write pending-review
Gardener                 ──API REST──→ 17 missions (systemd timers)
VM1                       ──nginx─────→ proxy public (Cloudflare Tunnel)
```

---

## Prochaine étape : Phase 1 — Infrastructure

Déployer sur **bzserv** (ne pas toucher à VM1 sauf proxy) :

1. **Neo4j via Podman Quadlet**
   - Image : `neo4j:5-community`
   - Heap : 2 GB
   - Volume : `/opt/neo4j/data`
   - Ports : `7474` (HTTP), `7687` (Bolt)
   - Plugins : APOC, GDS

2. **Vault Markdown**
   ```bash
   mkdir -p /opt/knowledge-vault/{global,project}
   # Copier les 5 fichiers global/ depuis le package
   ```

3. **nginx WebDAV**
   - Module : `ngx_http_dav_module` (inclus standard)
   - Auth : basic auth
   - Path : `/opt/knowledge-vault/`

4. **Firewall bzserv**
   - Ajouter `ALLOW on tailscale0` pour 3002, 7474, WebDAV

---

## Contraintes à respecter

| Règle | Détail |
|-------|--------|
| **Pas de `PublishPort`** | Bug netavark Ubuntu 24.04 → utiliser nginx proxy local |
| **Tout sur Tailscale** | Bind sur `100.64.144.126` ou `127.0.0.1` (nginx proxy) |
| **Ne jamais `0.0.0.0`** | Sauf approbation explicite |
| **UFW order matters** | `ALLOW on tailscale0` AVANT `DENY` |
| **systemd Quadlet** | `/etc/containers/systemd/neo4j.container` |

---

## Fichiers de référence

| Fichier | Contenu |
|---------|---------|
| `README.md` | Vue d'ensemble, quick start, structure projet |
| `PLAN.md` | Architecture détaillée, 12 sections, 8 phases de déploiement |
| `AGENT_HANDOVER.md` | Ce fichier — contexte pour le prochain agent |

---

## Checklist démarrage rapide

```bash
# 1. Déployer Neo4j
sudo cp neo4j.container /etc/containers/systemd/
sudo systemctl daemon-reload
sudo systemctl start neo4j

# 2. Vérifier Neo4j
curl http://127.0.0.1:7474

# 3. Créer vault
sudo mkdir -p /opt/knowledge-vault/{global,project,.obsidian}
sudo chown -R bzn:bzn /opt/knowledge-vault

# 4. WebDAV nginx
sudo cp knowledge-vault.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 5. Test WebDAV
curl -u bzn:password -X PROPFIND http://127.0.0.1/knowledge/
```

---

## Modèle mental pour le prochain agent

Tu es l'agent qui **déploie l'infrastructure**. Tu n'as pas à concevoir — l'architecture est figée dans `PLAN.md`. Ton job :

1. Lire `PLAN.md` section 11 (Phases de déploiement)
2. Exécuter Phase 1 étape par étape
3. Valider chaque étape avant de passer à la suivante
4. Ne pas coder l'API ou l'extension — c'est pour les phases suivantes
5. Signaler tout écart entre le plan et la réalité