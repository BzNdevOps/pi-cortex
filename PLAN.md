# pi-cortex — Plan détaillé

> **Date :** 2026-05-03
> **Statut :** Architecture validée, déploiement à venir
> **Session :** Design macro — aucun code écrit, aucun déploiement effectué

---

## Table des matières

1. [Résumé exécutif](#1-résumé-exécutif)
2. [Décisions architecturales](#2-décisions-architecturales)
3. [Infrastructure](#3-infrastructure)
4. [Modèle Neo4j](#4-modèle-neo4j)
5. [API REST](#5-api-rest)
6. [Extension Pi](#6-extension-pi)
7. [Agent Knowledge Gardener](#7-agent-knowledge-gardener)
8. [Interface humaine — Obsidian + WebDAV](#8-interface-humaine--obsidian--webdav)
9. [Accès sub-agents](#9-accès-sub-agents)
10. [Package Pi](#10-package-pi)
11. [Phases de déploiement](#11-phases-de-déploiement)
12. [Risques et mitigations](#12-risques-et-mitigations)

---

## 1. Résumé exécutif

`pi-cortex` construit un **cortex de connaissance** pour les agents Pi, inspiré de `codex-claude-memory-autopilot` mais 100% natif à l'écosystème Pi (extensions TypeScript, skills, pi packages).

**Objectifs :**
- Accélérer le développement en donnant aux agents un accès structuré à la mémoire du projet
- Minimiser les tokens via progressive disclosure et routage catégoriel
- Éviter les erreurs répétées via une base de patterns d'erreurs et corrections
- Code correct en moins d'itérations grâce aux guardrails et architecture validée
- Partageable avec la communauté Pi en un `pi install`

**Infrastructure :** tout sur **bzserv** (15 GB RAM, Java 21, Podman), VM1 en proxy public.

---

## 2. Décisions architecturales

| # | Décision | Choix | Raison |
|---|----------|-------|--------|
| 1 | Package auto-suffisant vs framework | **Hybride** | Socle global packagé + mémoire projet à remplir |
| 2 | Stockage des connaissances | **JSON Document Store** (`.md` + `.json`) comme source de vérité, **Neo4j** comme moteur de graphe | Git-friendly + algorithmes graphe puissants |
| 3 | Base de données | **Neo4j Community Edition** | Seule option avec moteur graphe natif pour ACO, PageRank, GDS |
| 4 | Interface humaine | **Obsidian + WebDAV** | App iOS native + desktop, Markdown natif, sync auto |
| 5 | Extraction connaissances | **Agent valide → pending-review → Gardener valide → promeut** | Automatique avec garde-fou |
| 6 | Agent validateur | **Knowledge Gardener — 17 missions autonomes** | Valide, consolide, nettoie, optimise + 13 missions supplémentaires |
| 7 | Sub-agents | **Hybride (Option E)** : Read filtré, Write pending-review seulement, fallback injection au fork | Sécurité + tokens optimisés |

---

## 3. Infrastructure

### Topologie

```
iPhone / Laptop
    │ Obsidian.app → WebDAV
    ▼
VM1 (OCI Paris, 954 MB RAM)
    │ nginx proxy uniquement
    ▼
bzserv (local, 15 GB RAM, RTX 5070 Ti)
    ├── Neo4j (Podman, heap 2 GB, ports 7474/7687)
    ├── API Server (Node.js, port 3001)
    ├── Vault Markdown (/opt/knowledge-vault/)
    ├── nginx local (WebDAV pour Obsidian)
    ├── Gardener (systemd timer)
    └── Extension Pi
```

### Allocation mémoire bzserv

| Composant | RAM |
|-----------|-----|
| OS + buffers | ~2 GB |
| Podman (ollama, open-webui, whisper) | ~3 GB |
| Neo4j (heap 2 GB + overhead) | ~3 GB |
| API Server (Node.js) | ~200 MB |
| Marge | ~7 GB |

✅ 8 GB utilisés / 15 GB — large.

---

## 4. Modèle Neo4j

### Labels de nœuds

```
Knowledge
Project
Category
Agent
Session
```

### Propriétés du nœud Knowledge

| Propriété | Type | Description |
|-----------|------|-------------|
| `id` | String | Chemin unique (ex: `global/01-engineering-principles`) |
| `title` | String | Titre |
| `content` | String | Contenu Markdown |
| `category` | String | `architecture`, `mistakes`, `guardrails`, `best-practices`, `corrections`, `questions`, `reasoning-traces`, `self-model` |
| `status` | String | `active`, `draft`, `archived`, `deprecated` |
| `confidence` | Float | 0.0 à 1.0 |
| `uses` | Int | Compteur d'utilisation |
| `last_used` | DateTime | Dernier accès |
| `pagerank` | Float | Score PageRank |
| `freshness_score` | Float | 1/(jours_sans_màj + 1) |
| `source_agent` | String | Agent qui a créé |
| `source_url` | String | URL de provenance |
| `created_at` | DateTime | Création |
| `updated_at` | DateTime | Dernière modification |
| `valid_from` | DateTime | Versioning |
| `valid_to` | DateTime | Versioning |
| `version_id` | Int | Numéro de version |
| `superseded_by` | String | ID de la connaissance remplaçante |

### Types de relations

| Relation | Propriétés | Description |
|----------|-----------|-------------|
| `RELATED_TO` | `pheromone`, `last_used` | Lien pondéré entre connaissances |
| `HAS_KNOWLEDGE` | | Projet → Connaissance |
| `BELONGS_TO` | | Connaissance → Catégorie |
| `SUPERSEDED_BY` | `version` | Obsolète → Remplaçant |
| `CONTRADICTS` | `detected_at` | Conflit logique |
| `SUGGESTED_LINK` | `auto_generated`, `confidence` | Lien suggéré par optimisation |
| `SIMILAR_TO` | `score` | Similarité sémantique |
| `CORRECTED_BY` | `session_id` | Erreur → Correction |
| `SOURCE_FROM` | `url`, `extracted_at` | Provenance externe |
| `CREATED_BY` | `session_id` | Agent créateur |

---

## 5. API REST

### Endpoints — Lecture

| Endpoint | Description |
|----------|-------------|
| `GET /api/search?q=&category=&project=&top_k=5&level=compact` | Recherche lexicale + routage catégoriel |
| `GET /api/knowledge/:id` | Récupérer une connaissance |
| `GET /api/graph/related/:id?depth=2` | Nœuds reliés + poids des arêtes |
| `GET /api/weights/top?k=10` | Top connaissances par poids ACO |
| `GET /api/projects` | Liste des projets |
| `GET /api/gaps` | Connaissances manquantes |
| `GET /api/contradictions` | Incohérences détectées |
| `GET /api/freshness/:id` | Score fraîcheur |
| `GET /api/health` | Santé globale du graphe |
| `GET /api/pending-review` | Candidats en attente |

### Endpoints — Écriture

| Endpoint | Niveau requis | Description |
|----------|:---:|-------------|
| `POST /api/knowledge` | 1, 2 | Créer/modifier une connaissance |
| `POST /api/lesson` | 1, 2, 3 | Soumettre une leçon (→ draft) |
| `POST /api/graph/reinforce` | 1, 2 | Renforcer poids ACO |
| `POST /api/feedback` | 1, 2, 3 | Feedback agent (utile/inutile) |
| `DELETE /api/knowledge/:id` | 1, 2 | Supprimer (archiver) |
| `POST /api/admin/consolidate` | 2 | Lancer une consolidation manuelle |
| `POST /api/admin/evaporate` | 2 | Forcer évaporation |
| `POST /api/admin/snapshot` | 2 | Créer un snapshot |

### Format réponse standard

```json
{
  "results": [
    {
      "id": "global/01-engineering-principles",
      "title": "Engineering Principles",
      "category": "engineering",
      "excerpt": "Core principles: zero external dependencies...",
      "score": 0.92,
      "pheromone": 12.5,
      "confidence": 0.95
    }
  ],
  "routing_mode": "auto",
  "detected_categories": ["engineering"],
  "tokens_estimated": 450
}
```

---

## 6. Extension Pi

### Outils enregistrés

| Outil | Description |
|-------|-------------|
| `memory_search` | Recherche lexicale + routage catégoriel dans Neo4j |
| `memory_search_routed` | Version avancée avec budget tokens, level |
| `memory_get` | Lire une connaissance complète |
| `memory_record_lesson` | Enregistrer une leçon apprise |
| `memory_get_graph` | Explorer le graphe de connaissances |
| `memory_status` | État de santé de la mémoire |
| `memory_feedback` | Donner un feedback sur une connaissance |

### Hooks cycle de vie

| Hook | Action |
|------|--------|
| `session_start` | Charger weights.json, vérifier santé mémoire |
| `before_agent_start` | Injecter mémoire pertinente (routage catégoriel) dans le system prompt |
| `tool_call` | Gates de sécurité (bloquer commandes dangereuses) |
| `turn_end` | Détecter patterns d'erreurs → suggérer memory_record_lesson |
| `session_shutdown` | Persister l'état |

### Injection contextuelle dans le system prompt

```
Avant chaque prompt, l'extension :
1. Analyse le message utilisateur (mots-clés, intention)
2. Route vers les catégories pertinentes (architecture? mistakes? guardrails?)
3. Injecte un bloc compact :

   ## 🧠 Mémoire du projet (pi-cortex)

   ### Architecture validée
   - Décision: microservices, API Gateway NGINX, PostgreSQL
   - [Voir 02-validated-architecture.md]

   ### ⚠️ Guardrails actifs
   - Ne jamais exposer un port sur 0.0.0.0 sans approbation
   - Toujours préférer Tailscale aux IP publiques

   ### 🔍 Patterns d'erreurs connus
   - M1: SQLite lock concurrent → utiliser WAL mode
```

---

## 7. Agent Knowledge Gardener

### Identité

Agent Pi dédié, exécuté périodiquement via systemd timer, modèle léger (Gemini Flash gratuit ou Qwen local).

### Missions (17)

| # | Mission | Fréquence | Description |
|---|---------|-----------|-------------|
| 1 | **Valide** | Weekly | Vérifie redondance + exactitude (SearXNG), score confiance |
| 2 | **Consolide** | Weekly | Fusionne doublons sémantiques, promeut project→global |
| 3 | **Nettoie** | Daily | Évaporation ACO (-3%/j), prune nœuds morts (>30j, 0 connexions) |
| 4 | **Optimise** | Monthly | PageRank, renforcement liens chauds, suggère liens manquants |
| 5 | **Détecte contradictions** | Weekly | Vérifie cohérence logique : `(A, returnType, X)` ET `(A, returnType, Y)` |
| 6 | **Versionne** | Weekly | `valid_from`/`valid_to`, détecte `supersededBy` |
| 7 | **Traque provenance** | Daily | `source_agent`, `source_url`, `extraction_timestamp` pour chaque fait |
| 8 | **Détecte gaps** | Weekly | Analyse requêtes sans résultat → suggère connaissances manquantes |
| 9 | **Clusterise** | Monthly | Regroupe sémantiquement, détecte « presque doublons » |
| 10 | **Deprecation** | Weekly | Détecte `@deprecated` → marque obsolète → guide remplacement |
| 11 | **Cross-reference** | Daily | Complète relations inverses manquantes |
| 12 | **Normalise** | Weekly | Standards : dates ISO 8601, versions semver, statuts cohérents |
| 13 | **Score fraîcheur** | Daily | Score basé sur âge + liens valides (HTTP 200?) |
| 14 | **Feedback loop** | Weekly | Traite retours agents → ajuste confiance |
| 15 | **Perf Neo4j** | Daily | Monitor indexes, requêtes lentes, super-nœuds |
| 16 | **Snapshot** | Monthly | Export graphe → rollback possible |
| 17 | **Anomalies** | Weekly | Détecte déviations structurelles (degré, clustering) |

### Planification systemd

```ini
# /etc/systemd/system/pi-cortex-gardener-daily.timer
[Timer]
OnCalendar=daily
Persistent=true

# /etc/systemd/system/pi-cortex-gardener-weekly.timer
[Timer]
OnCalendar=weekly
Persistent=true

# /etc/systemd/system/pi-cortex-gardener-monthly.timer
[Timer]
OnCalendar=monthly
Persistent=true
```

---

## 8. Interface humaine — Obsidian + WebDAV

### Setup

```bash
# Sur bzserv
apt install nginx-extras  # module WebDAV inclus

# /etc/nginx/sites-enabled/knowledge-vault
location /knowledge/ {
    alias /opt/knowledge-vault/;
    dav_methods PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods PROPFIND OPTIONS;
    auth_basic "Knowledge Vault";
    auth_basic_user_file /etc/nginx/.htpasswd-knowledge;
}
```

### Plugin Obsidian — Remotely Save

```yaml
# Configuration Obsidian (identique iPhone + laptop)
Type: WebDAV
URL: https://bzserv.tail011919.ts.net/knowledge/
Auth: Basic
User: bzn
Password: ***
Sync on save: true
Sync interval: 30s
```

### Structure vault

```
/opt/knowledge-vault/
├── global/                              ← Socle (lecture seule)
│   ├── 01-engineering-principles.md
│   ├── 02-best-practices.md
│   ├── 03-mistakes-patterns.md
│   ├── 04-correction-patterns.md
│   └── 05-guardrails.md
├── project/                             ← Spécifique au projet
│   ├── 01-project-brief.md
│   ├── 02-validated-architecture.md
│   ├── 03-design-mistakes.md
│   ├── 04-best-practices.md
│   ├── 05-correction-patterns.md
│   ├── 06-guardrails.md
│   └── 07-open-questions.md
├── taxonomy.json
├── weights.json
└── .obsidian/
```

---

## 9. Accès sub-agents

| Niveau | Agent | Read | Write | Scope |
|--------|-------|:----:|:-----:|-------|
| **1** | Agent principal | ✅ Tout | ✅ Tout | Graphe complet |
| **2** | Gardener | ✅ Tout | ✅ Tout | Graphe complet |
| **3** | Sub-agents | ✅ Filtré catégorie | ⚠️ `pending-review/` | Limitée |

### Fallback injection au fork

Si Neo4j est lent ou indisponible, l'agent principal injecte un résumé mémoire statique dans le system prompt du sub-agent au moment du `fork`/`newSession`.

---

## 10. Package Pi

### package.json

```json
{
  "name": "@bzndevops/pi-cortex",
  "version": "0.1.0",
  "description": "Pi memory autopilot — Neo4j-powered knowledge graph for Pi agents",
  "keywords": ["pi-package"],
  "pi": {
    "extensions": ["./app/extension"],
    "skills": ["./skills"],
    "prompts": ["./prompts"],
    "video": "https://example.com/pi-cortex-demo.mp4"
  },
  "dependencies": {
    "neo4j-driver": "^5.x"
  }
}
```

### Contenu

```
pi-cortex/
├── app/
│   ├── api-server/       ← Node.js/Express, API REST
│   ├── extension/        ← Extension TypeScript pour Pi
│   ├── gardener/         ← Scripts gardener + systemd units
│   └── watcher/          ← Sync Markdown → Neo4j
├── skills/
│   ├── mem-start/SKILL.md
│   ├── mem-status/SKILL.md
│   ├── mem-extract/SKILL.md
│   ├── mem-validate/SKILL.md
│   ├── mem-consolidate/SKILL.md
│   └── mem-vault/SKILL.md
├── prompts/
│   ├── mem-review.md
│   └── mem-lesson.md
└── knowledge/
    └── global/
        ├── 01-engineering-principles.md
        ├── 02-best-practices.md
        ├── 03-mistakes-patterns.md
        ├── 04-correction-patterns.md
        └── 05-guardrails.md
```

---

## 11. Phases de déploiement

### Phase 1 — Infrastructure (bzserv)

| Étape | Tâche | Statut |
|-------|-------|--------|
| 1.1 | Déployer Neo4j Community via Podman Quadlet | ⬜ |
| 1.2 | Configurer plugins APOC + GDS | ⬜ |
| 1.3 | Créer indexes et contraintes Neo4j | ⬜ |
| 1.4 | Créer `/opt/knowledge-vault/` + structure | ⬜ |
| 1.5 | Configurer nginx WebDAV pour Obsidian | ⬜ |
| 1.6 | Configurer HTTPS (certificat existant ou self-signed) | ⬜ |

### Phase 2 — API Server

| Étape | Tâche | Statut |
|-------|-------|--------|
| 2.1 | Initialiser projet Node.js/Express | ⬜ |
| 2.2 | Implémenter endpoints lecture (search, get, graph, weights...) | ⬜ |
| 2.3 | Implémenter endpoints écriture (record_lesson, reinforce, feedback) | ⬜ |
| 2.4 | Implémenter watcher Markdown → Neo4j | ⬜ |
| 2.5 | Middleware auth (niveaux 1/2/3) | ⬜ |
| 2.6 | Tests API | ⬜ |
| 2.7 | systemd service pour l'API | ⬜ |

### Phase 3 — Extension Pi

| Étape | Tâche | Statut |
|-------|-------|--------|
| 3.1 | Créer extension TypeScript avec outils memory_* | ⬜ |
| 3.2 | Hook before_agent_start (injection mémoire) | ⬜ |
| 3.3 | Hook tool_call (gates sécurité) | ⬜ |
| 3.4 | Hook turn_end (détection patterns) | ⬜ |
| 3.5 | Tests extension | ⬜ |

### Phase 4 — Skills + Templates

| Étape | Tâche | Statut |
|-------|-------|--------|
| 4.1 | mem-start SKILL.md | ⬜ |
| 4.2 | mem-status SKILL.md | ⬜ |
| 4.3 | mem-extract SKILL.md | ⬜ |
| 4.4 | mem-validate SKILL.md | ⬜ |
| 4.5 | mem-consolidate SKILL.md | ⬜ |
| 4.6 | mem-vault SKILL.md | ⬜ |
| 4.7 | Prompt templates | ⬜ |

### Phase 5 — Agent Gardener

| Étape | Tâche | Statut |
|-------|-------|--------|
| 5.1 | Script gardener principal (17 missions) | ⬜ |
| 5.2 | systemd timers (daily, weekly, monthly) | ⬜ |
| 5.3 | Logs et dashboard | ⬜ |
| 5.4 | Tests gardener | ⬜ |

### Phase 6 — Proxy VM1

| Étape | Tâche | Statut |
|-------|-------|--------|
| 6.1 | Configurer nginx VM1 → bzserv (API :3001, Neo4j :7474, WebDAV) | ⬜ |
| 6.2 | Cloudflare Tunnel (si domaine dédié) | ⬜ |
| 6.3 | Test accès public | ⬜ |

### Phase 7 — Obsidian

| Étape | Tâche | Statut |
|-------|-------|--------|
| 7.1 | Configurer Obsidian iPhone (Remotely Save → WebDAV) | ⬜ |
| 7.2 | Configurer Obsidian Laptop | ⬜ |
| 7.3 | Peupler premier vault (connaissances globales) | ⬜ |

### Phase 8 — Package npm

| Étape | Tâche | Statut |
|-------|-------|--------|
| 8.1 | Finaliser package.json + manifest pi | ⬜ |
| 8.2 | npm publish | ⬜ |
| 8.3 | Test `pi install npm:@bzndevops/pi-cortex` | ⬜ |

---

## 12. Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Neo4j consomme trop de RAM | Moyenne | Haut | Heap réglable, monitoring, limite 2 GB initial |
| Corruption Neo4j | Faible | Critique | Snapshots mensuels (mission 16), backup Podman volume |
| L'agent valide une erreur | Moyenne | Moyen | Seuil confiance 80%, SearXNG vérification, évaporation corrige |
| Conflit Obsidian ↔ API (écriture simultanée) | Faible | Faible | Watcher API lit les fichiers après écriture, Neo4j transactionnel |
| Boucle feedback (agent valide ses propres leçons) | Faible | Moyen | Gardener = session Pi séparée, system prompt « sceptique » |
| WebDAV non sécurisé | Moyenne | Haut | HTTPS + basic auth + fail2ban |
| Sub-agent pollue le graphe | Faible | Moyen | Write pending-review SEULEMENT, pas d'accès direct au graphe actif |
| VM1 ne supporte pas la charge proxy | Faible | Faible | nginx proxy léger, Tailscale direct en fallback |
