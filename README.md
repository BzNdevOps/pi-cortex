# pi-cortex

> Mémoire persistante et intelligence partagée pour les agents Pi.

`pi-cortex` est un **système de connaissance autonome** pour les agents Pi et leurs sous-agents. Il combine un **graphe Neo4j** (algorithmes ACO, PageRank, détection de contradictions), une **API REST** (agents), un **vault Markdown** (édition humaine via Obsidian iPhone/laptop), et un **agent « Knowledge Gardener »** qui maintient le graphe automatiquement (17 missions).

## Pourquoi ?

| Problème | Solution pi-cortex |
|----------|-------------------|
| Chaque session Pi repart de zéro | La connaissance persiste dans Neo4j |
| Les agents répètent les mêmes erreurs | Les patterns d'erreurs sont stockés et évités |
| Le contexte explose en tokens | Progressive disclosure + routage catégoriel |
| La connaissance se périme | Gardener : fraîcheur, évaporation, pruning |
| Pas de partage cross-projet | Consolidation project → global |

## Architecture

```
iPhone/Laptop (Obsidian) ──WebDAV──→ bzserv:/opt/knowledge-vault/
                                           │
Agent Pi (extension) ──API REST──→ API Server (Node.js, :3002)
                                           │
Sub-agents ──API REST (filtré)──→        Neo4j (Podman)
                                           │
Gardener ──API REST (full)────────→   17 missions autonomes
```

## Quick Start

```bash
# Installer le package Pi
pi install npm:@bzndevops/pi-cortex

# Dans un projet, initialiser la mémoire
/skill:mem-start

# Voir l'état
/skill:mem-status
```

## Structure du projet

```
pi-cortex/
├── README.md              ← Ce fichier
├── PLAN.md                ← Plan détaillé, architecture, specs
├── AGENT_HANDOVER.md      ← Contexte pour le prochain agent
│
├── app/                   ← Code source
│   ├── api-server/        ← API REST Node.js/Express
│   ├── extension/         ← Extension TypeScript pour Pi
│   ├── gardener/          ← Agent Knowledge Gardener
│   └── watcher/           ← Sync Markdown → Neo4j
│
├── knowledge/             ← Connaissances packagées
│   └── global/            ← Socle (5 fichiers .md)
│
├── skills/                ← Skills Pi (mem-start, mem-status...)
├── prompts/               ← Prompt templates
│
└── docs/                  ← Documentation
    ├── ARCHITECTURE.md
    └── DECISIONS.md
```

## Licence

MIT — Partagé avec la communauté Pi.