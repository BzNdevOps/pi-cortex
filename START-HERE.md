# START-HERE.md — pi-cortex Autonomous Agent

> **Lis ce fichier en premier. Il contient tout ce dont tu as besoin pour démarrer.**

---

## Qui tu es

Tu es un agent de développement autonome. Ton seul objectif est de développer
et déployer le projet **pi-cortex** sur **bzserv** sans intervention humaine.

pi-cortex est un système de mémoire structurée pour agents Pi — knowledge graph
Neo4j + API REST + extension Pi + Gardener autonome.

---

## Répertoire de travail

```
/home/bzn/Projects/BzNdevOps/pi-cortex
```

---

## Démarrage — dans cet ordre exact

### Étape 1 — Identifier la session courante
```bash
python3 -c "
import json
try:
    s = json.load(open('/home/bzn/Projects/BzNdevOps/pi-cortex/.context/session-state.json'))
    print('current_session:', s.get('current_session', 1))
    print('last_completed_step:', s.get('last_completed_step', 'none'))
except:
    print('current_session: 1 (fresh start)')
"
```
→ Note le numéro de session. Tu vas lire SESSIONS.md à l'étape suivante.

### Étape 2 — Lire le plan de session (PAS TEST-PLAN.md complet)
```bash
cat /home/bzn/Projects/BzNdevOps/pi-cortex/SESSIONS.md
```
**⚠️ NE PAS lire TEST-PLAN.md complet** — il fait 1500 lignes (20K tokens).
SESSIONS.md contient les commandes `sed` pour extraire uniquement les phases de ta session.

### Étape 3 — Vérifier l'environnement
```bash
bash /home/bzn/Projects/BzNdevOps/pi-cortex/scripts/preflight.sh 2>&1 | tail -20
```
- `🟢 FULLY AUTONOMOUS` → continuer
- `🟡 PARTIALLY AUTONOMOUS` → noter les phases bloquées, continuer quand même
- `🔴 BLOCKED` → corriger les CRITICAL FAIL avant de continuer

### Étape 4 — Suivre les instructions de ta session dans SESSIONS.md
Chaque session contient :
1. Les `cat reference/docs/X.md` à lire (uniquement les docs pertinents)
2. Les commandes `sed` pour charger uniquement les phases de ta session
3. Les commandes de vérification des dépendances
4. La commande de checkpoint de fin de session

**Règle d'or : ne charger que ce dont tu as besoin pour cette session.**
Budget contexte par session : ~80K tokens utilisés sur 125K disponibles.

---

## Boucle de codage

```
POUR chaque étape dans TEST-PLAN.md (dans l'ordre) :
  TANT QUE l'étape n'est pas PASS :
    1. Lire le Goal + la référence dans PLAN-OPUS.md
    2. Implémenter / corriger
    3. Exécuter la commande de test exacte
    4. Si PASS → sauvegarder le checkpoint → passer à la suivante
    5. Sinon → lire les FAIL hints → retourner au point 2

  Si toujours FAIL après 3 tentatives :
    → Enregistrer dans .context/blocked-steps.json
    → Marquer [DEFERRED]
    → Continuer à la prochaine étape indépendante

À la fin de chaque phase :
  → Exécuter le bloc "Phase X complete — commit + notify"
  → Cela fait : git commit + message Telegram de résumé au propriétaire
```

### Sauvegarder le checkpoint après chaque PASS
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
with open(STATE_FILE, 'w') as f: json.dump(state, f, indent=2)
print('checkpoint saved:', step)
" "<STEP_ID>"
```
Remplacer `<STEP_ID>` par le numéro de l'étape (ex: `"0.2"`, `"1.3"`, `"2a.5"`).

---

## Règles non-négociables

| Règle | Détail |
|-------|--------|
| **Jamais `0.0.0.0`** | API :3002, Neo4j :7474/:7687 → bind `127.0.0.1` uniquement |
| **UFW order** | Vérifier `sudo ufw status numbered` avant toute modification — ALLOW tailscale0 AVANT DENY |
| **Pas de `--no-verify`** | Ne jamais bypasser les hooks git |
| **Ne pas casser les services existants** | ollama, open-webui, whisper, voice-pi, llama-qwen doivent rester actifs |
| **Test avant PASS** | Ne jamais marquer une étape PASS sans avoir exécuté sa commande de test |
| **Secrets dans `.pi/.env`** | chmod 600, jamais dans les logs |

---

## État actuel du projet

| Phase | Statut |
|-------|--------|
| Phase 0.1 — Clés API générées | ✅ Fait (commit deb0c44) |
| Phase 1.1 — Neo4j Podman Quadlet | ✅ Fait (commit deb0c44) |
| Phase 0.2 → 0.7 | ⬜ À faire |
| Phase 1.2 → 11 | ⬜ À faire |

**Prochaine étape : TEST-PLAN.md Step 0.2**

---

## Fichiers de référence

| Fichier | Rôle |
|---------|------|
| `PLAN-OPUS.md` | Spec complète — 11 phases, architecture, API, auth, watcher, Gardener |
| `TEST-PLAN.md` | Boucle de test — 1 commande par étape, PASS/FAIL/hints, commits, Telegram |
| `ALGORITHMS.md` | 15 algorithmes à implémenter (stemmer, ACO, routing, scoring...) |
| `AGENTS.md` | Secrets, tokens GitHub, règles de sécurité |
| `AGENT-PREFLIGHT.md` | Détail de chaque check du preflight (sections 1–13) |
| `scripts/preflight.sh` | Script exécutable du preflight |
| `.context/session-state.json` | Dernier checkpoint (last_completed_step) |
| `.context/blocked-steps.json` | Étapes bloquées après 3 tentatives |

---

## Notifications Telegram

À la fin de chaque phase, un message est envoyé automatiquement au propriétaire
via `/usr/local/bin/bzserv-telegram-send`. Les commandes exactes sont dans
TEST-PLAN.md dans les blocs **"Phase X complete — commit + notify"**.

Ne pas sauter ces blocs — ils permettent au propriétaire de suivre la progression
en temps réel sans intervenir.

---

## Objectif final

Compléter toutes les phases de TEST-PLAN.md jusqu'au test E2E inclus,
puis envoyer le rapport final :

```
[pi-cortex] 🚀 PROJET TERMINÉ — E2E PASS
```

**Commence maintenant par l'Étape 1 ci-dessus.**
