# pi-cortex — Algorithmes & Concepts

> **Source :** Extraits de `codex-claude-memory-autopilot` (moteur de mémoire Codex/Claude)
> **Date extraction :** 2026-05-03
> **Applicabilité :** 15 algorithmes identifiés, tous transposables à pi-cortex

---

## Table des matières

1. [Recherche lexicale — 5 algorithmes](#1-recherche-lexicale)
2. [Ant Colony Optimization (ACO) — 3 algorithmes](#2-ant-colony-optimization-aco)
3. [Routage catégoriel — 2 algorithmes](#3-routage-catégoriel)
4. [Strategy Learning (méta-apprentissage) — 4 algorithmes](#4-strategy-learning-méta-apprentissage)
5. [Machine à états — 1 algorithme](#5-machine-à-états)
6. [Tableau récapitulatif](#6-tableau-récapitulatif)
7. [Transposition à Neo4j / pi-cortex](#7-transposition-à-neo4j--pi-cortex)

---

## 1. Recherche lexicale

### 1.1 Porter-lite Stemmer

**Source :** `mcp_memory_server.py::_stem()` / `knowledge_router.py::_stem()`

**But :** Normaliser les mots pour améliorer le rappel (recall) en recherche lexicale, sans dépendance externe.

**Principe :**
```python
def _stem(word: str) -> str:
    w = word.lower()
    if len(w) <= 3:
        return w
    # 1. Pluriels
    if w.endswith("ies") and len(w) > 4:    w = w[:-3] + "y"
    elif w.endswith("sses") ...:             w = w[:-2]
    elif w.endswith("s") and not w.endswith("ss"): w = w[:-1]
    # 2. Suffixes dérivationnels (longest-first)
    stem_rules = [
        ("ational", "ate"), ("tional", "tion"), ("ations", "ate"), ("ation", "ate"),
        ("izing", "ize"), ("ising", "ise"), ("ized", "ize"), ("ised", "ise"),
        ("nesses", ""), ("ness", ""), ("ments", ""), ("ment", ""),
        ("ingly", ""), ("edly", ""), ("ings", ""), ("ing", ""),
        ("eds", ""), ("ed", ""), ("ical", ""), ("ics", ""),
        ("ists", ""), ("ism", ""), ("ist", ""),
        ("ive", ""), ("ize", ""), ("ise", ""), ("ful", ""), ("less", ""),
        ("ers", "e"), ("er", "e"), ("lly", "l"), ("ly", ""),
        ("al", ""), ("ic", ""),
    ]
    for suffix, replacement in stem_rules:
        if w.endswith(suffix) and len(w) - len(suffix) >= 3:
            w = w[:-len(suffix)] + replacement
            break
    return w if w else word.lower()
```

**Exemples :**
```
"architectural"  → "architect"
"decisions"      → "decision"
"running"        → "runn"
"optimizations"  → "optimiz"
"reusable"       → "reus"
```

**Propriétés :**
- Conservateur : préfère les faux positifs aux faux négatifs
- O(n) où n = longueur du mot
- Zéro dépendance externe
- Appliqué **symétriquement** aux tokens de requête ET aux tokens de document

**Transposition pi-cortex :** ✅ Directe — à implémenter en TypeScript dans l'API server et l'extension.

---

### 1.2 Tokenisation + Scoring lexical

**Source :** `mcp_memory_server.py::_tokenize()` / `_score_section()`

**But :** Mesurer la pertinence d'une section de document par rapport à une requête.

**Principe :**
```python
def _tokenize(text: str) -> list[str]:
    return [_stem(w) for w in re.findall(r"\w+", text.lower()) if len(w) > 2]

def _score_section(tokens: list[str], text: str) -> float:
    words = _tokenize(text)
    if not words: return 0.0
    word_set = set(words)
    matches = sum(1 for t in tokens if t in word_set)
    return matches / max(len(words) ** 0.5, 1)
```

**Détail :**
- Tokenise en mots > 2 caractères (filtre le bruit : `a`, `is`, `of`)
- Stemme chaque mot
- Score = **intersection(query_tokens, section_words) / √(nb_mots_section)**
- La racine carrée au dénominateur favorise les sections concises avec forte correspondance
- Compense le fait qu'une longue section a plus de chances d'avoir des matchs fortuits

**Exemple :**
```
Requête : "postgresql connection pooling architecture"
Tokens  : ["postgresql", "connect", "pool", "architect"]

Section courte (50 mots) :
  "Use connection pooling for PostgreSQL databases."
  matchs = 3 (connect, pool, postgresql)
  score  = 3 / √50 = 3 / 7.07 = 0.42

Section longue (500 mots) :
  Même matchs (3)
  score  = 3 / √500 = 3 / 22.36 = 0.13  ← pénalisé
```

**Transposition pi-cortex :** ✅ Directe — à implémenter dans l'API `/api/search`.

---

### 1.3 Scoring combiné (lexical × phéromone)

**Source :** `mcp_memory_server.py::_collect_candidates()`

**But :** Combiner la pertinence lexicale avec la « sagesse collective » (poids ACO).

**Principe :**
```python
lexical_score = _score_section(tokens, content)
pheromone     = _pheromone(rel_path)  # issu de weights.json
combined      = lexical_score * (1.0 + pheromone)

# Bonus local : +5% si la connaissance est dans le projet courant
if prefer_project_local and rel_path.startswith(local_prefix):
    combined *= 1.05
```

**Effet :**
- Deux documents avec le même score lexical → celui avec le plus de phéromone monte
- Une connaissance jamais utilisée (phéromone = 0) n'est pas pénalisée — elle vaut `lexical × 1.0`
- Une connaissance très utilisée (phéromone = 10) → `lexical × 11.0` — boost massif
- Bonus local léger (+5%) pour favoriser le contexte projet sans écraser le global

**Transposition pi-cortex :** ✅ Directe — appliqué sur les arêtes `RELATED_TO` dans Neo4j.

---

### 1.4 Excerpt adaptatif

**Source :** `knowledge_router.py::excerpt_size()`

**But :** Adapter la taille de l'extrait retourné au score de pertinence.

**Principe :**
```python
def excerpt_size(score: float) -> int:
    if score >= 0.7: return 300   # Très pertinent → extrait long
    if score >= 0.4: return 150   # Moyennement pertinent
    return 80                      # Peu pertinent → extrait court
```

**Économie de tokens :**
```
Top 5 résultats d'une recherche :
  R1: score 0.92 → 300 chars
  R2: score 0.65 → 150 chars
  R3: score 0.55 → 150 chars
  R4: score 0.38 → 80 chars
  R5: score 0.22 → 80 chars
  Total           → 760 chars (vs 1500 si tous à 300)
```

**Transposition pi-cortex :** ✅ Directe — paramètre `excerpt` dans la réponse `/api/search`.

---

### 1.5 Token budgeting

**Source :** `mcp_memory_server.py::_apply_budget()`

**But :** Maximiser la densité d'information dans un budget de tokens fixe.

**Principe :**
```python
def _apply_budget(results, budget_tokens, top_k, compact):
    if budget_tokens <= 0: return []

    # Trier par DENSITÉ = score / tokens_estimés
    ranked = sorted(results, key=lambda item:
        item.score / max(estimate_tokens(item, compact), 1),
        reverse=True
    )

    # Remplir jusqu'à épuisement du budget
    selected = []
    remaining = budget_tokens
    for item in ranked:
        estimated = estimate_tokens(item, compact)
        if estimated > remaining: continue
        selected.append(item)
        remaining -= estimated
        if len(selected) >= top_k: break

    # Re-trier par score pour l'affichage final
    selected.sort(key=lambda item: item.score, reverse=True)
    return selected
```

**Exemple :**
```
Budget : 500 tokens, top_k = 5
Candidats :
  A: score 0.9, tokens 300 → densité 0.003
  B: score 0.8, tokens 200 → densité 0.004  ← sélectionné
  C: score 0.7, tokens 150 → densité 0.005  ← sélectionné
  D: score 0.6, tokens 200 → densité 0.003  ← sélectionné
  E: score 0.5, tokens 400 → densité 0.001
→ Résultat : B + C + D (550 tokens, ok si marge)
```

**Implémentation de `estimate_tokens()` — utiliser exactement ceci :**
```typescript
// Estimation sans tokenizer externe: 1 token ≈ 4 chars (GPT/Claude standard)
function estimateTokens(item: { title: string; content: string }, compact: boolean): number {
  const text = compact
    ? `${item.title} ${item.content.slice(0, 150)}`   // compact mode: title + first 150 chars
    : `${item.title}\n${item.content}`;                 // full mode: title + full content
  return Math.ceil(text.length / 4);
}
```

**Transposition pi-cortex :** ✅ Directe — paramètre optionnel `budget_tokens` dans `/api/search`.

---

## 2. Ant Colony Optimization (ACO)

### 2.1 Phéromone decay (évaporation)

**Source :** `mcp_memory_server.py::_compute_weight()`

**But :** Les connaissances les plus utilisées remontent ; les connaissances oubliées disparaissent.

**Formule :**
```python
weight = uses × exp(-days_ago / decay_days)

# decay_days = 30 (configurable)
# demi-vie ≈ 21 jours (30 × ln(2))
```

**Comportement temporel :**
```
Jour 0  : 10 uses → poids = 10 × 1.0    = 10.0
Jour 10 : 10 uses → poids = 10 × 0.72   = 7.2
Jour 21 : 10 uses → poids = 10 × 0.50   = 5.0  ← demi-vie
Jour 30 : 10 uses → poids = 10 × 0.37   = 3.7
Jour 60 : 10 uses → poids = 10 × 0.14   = 1.4
Jour 90 : 10 uses → poids = 10 × 0.05   = 0.5  ← quasi nul
```

**Propriétés :**
- Sans utilisation, un poids fort s'évapore en ~90 jours
- Une connaissance utilisée régulièrement maintient son poids
- `uses` est incrémenté à chaque `memory_search` ou `memory_get`
- L'évaporation est appliquée en lecture (pas de job périodique dans la V1)

**Transposition pi-cortex :** ✅ Sur les propriétés `pheromone` des arêtes `RELATED_TO` dans Neo4j. Évaporation via Gardener mission 3 (daily) ou en lecture (comme l'original).

---

### 2.2 Batch flush (écriture différée)

**Source :** `mcp_memory_server.py::_increment_weight()` / `_flush_dirty_weights()`

**But :** Réduire les écritures disque en accumulant les incréments en mémoire.

**Principe :**
```python
# Accumulation en RAM
_weight_dirty[rel_path] = {"uses": existing.uses + 1, "last_used": today}
_weight_op_count += 1

# Flush tous les 10 incréments
if _weight_op_count >= 10:
    _flush_dirty_weights()

# Safety net : flush au exit
atexit.register(_flush_dirty_weights)
```

**Économie :**
```
Sans batch flush : 1000 recherches = 1000 écritures disque
Avec batch flush  : 1000 recherches = 100 écritures disque (10× moins)
```

**Propriétés :**
- Perte de quelques incréments acceptable (flush non-bloquant)
- atexit garantit qu'on ne perd pas tout au crash
- Implémenté avec `os.replace(tmp, target)` pour l'atomicité

**Transposition pi-cortex :** ✅ Pattern applicable à l'API server (accumuler les renforcements ACO avant d'écrire dans Neo4j).

---

### 2.3 Seeding initial des poids

**Source :** Décision de design documentée dans `knowledge/projects/codex-claude-memory-autopilot/memory/07-open-questions.md`

**But :** Éviter le problème de « cold start » où le système mettrait des semaines à devenir utile.

**Principe :**
```python
# Au setup initial :
seed_weight = word_count(file) / 100  # proportionnel à la taille
# Ex: fichier de 500 mots → poids initial = 5.0
# Ex: fichier de 50 mots  → poids initial = 0.5
```

**Propriétés :**
- Les fichiers volumineux (plus d'information) démarrent avec un poids plus élevé
- Les petits fichiers (peu d'information) démarrent bas
- Les seeds ont un `decay_days` plus long (365j) pour une décroissance très lente
- Après quelques semaines d'usage réel, les seeds sont naturellement remplacées par les vrais poids

**Transposition pi-cortex :** ✅ Au premier import des fichiers `.md` dans Neo4j, initialiser `uses` proportionnel à la taille du contenu.

---

## 3. Routage catégoriel

### 3.1 Détection de catégorie par lexique

**Source :** `knowledge_router.py::score_categories()` / `build_lexicon()`

**But :** Déterminer quelles catégories de connaissances sont pertinentes pour une requête donnée.

**Principe :**
```python
# 9 catégories, chacune avec un lexique fixe de mots-clés
# NOTE: These are the COMPLETE keyword lists — implement exactly as-is.
# All keywords are already stemmed (Porter-lite) to match stemmed query tokens.
_RAW_LEXICON = {
    "architecture": [
        "architectur", "design", "decis", "structur", "pattern", "diagram",
        "layer", "component", "modul", "interfac", "servic", "microservic",
        "monolith", "schema", "topolog", "deploy", "infrastructur", "stack",
        "databas", "cach", "queue", "broker", "gateway", "proxy", "abstraction",
    ],
    "mistakes": [
        "mistak", "avoid", "pitfall", "error", "failur", "bug", "broken",
        "wrong", "incorrect", "bad", "never", "do not", "dont", "warn",
        "trap", "gotcha", "footgun", "regress", "incident", "outag", "postmort",
        "corrupt", "leak", "deadlock", "racecond", "overflow", "crash",
    ],
    "best-practices": [
        "best", "practic", "guidelin", "standard", "recommend", "prefer",
        "should", "alway", "convex", "idiom", "pattern", "approach", "strategi",
        "optim", "effici", "clean", "solid", "principl", "conventionl", "rule",
        "tip", "trick", "how-to", "cookbook", "checklist", "workflow",
    ],
    "corrections": [
        "correct", "fix", "repair", "resolv", "patch", "workaround", "hotfix",
        "migrat", "upgrad", "replac", "refactor", "rewrit", "updat", "chang",
        "amend", "adjust", "reconfigur", "revert", "rollback", "supersed",
        "deprecat", "remov", "cleanup", "consolidat",
    ],
    "guardrails": [
        "guardrail", "constraint", "rule", "must", "forbidden", "prohibit",
        "block", "prevent", "secur", "permiss", "restrict", "enforc", "limit",
        "bound", "safeguard", "hardcod", "whitelist", "blacklist", "deni",
        "authent", "authoris", "firewal", "ufw", "iptabl", "audit",
    ],
    "open-questions": [
        "question", "unknown", "pending", "open", "unclear", "investig",
        "todo", "tbd", "research", "explor", "hypothes", "uncertainti",
        "consider", "tradeoff", "decid", "option", "alternativ", "candidat",
        "review", "propos", "discuss", "issu", "ticket",
    ],
    "brief": [
        "brief", "overview", "purpos", "scope", "goal", "objectiv", "summari",
        "introduc", "context", "background", "what", "why", "project", "mission",
        "vision", "status", "readme", "document", "describ", "explain",
    ],
    "reasoning-traces": [
        "reason", "trace", "analysi", "hypothes", "logic", "infer", "deduc",
        "thought", "step-by-step", "chain", "problem", "diagnos", "debug",
        "investig", "root-caus", "theori", "evalu", "compar", "trade-off",
        "observ", "conclus", "find", "insight", "learn",
    ],
    "self-model": [
        "self", "model", "strength", "weakness", "limit", "capabilit",
        "bias", "blind", "agent", "persona", "identiti", "confid", "uncert",
        "style", "prefer", "behavior", "habit", "heurist", "tendenc",
        "adapt", "improv", "feedback", "reflect", "calibr",
    ],
}

# Score = proportion des tokens requête présents dans le lexique
for category, lexicon in lexicon_map.items():
    hits = len(query_tokens & lexicon[category])
    score = hits / max(len(query_tokens), 1)
```

**Exemple :**
```
Requête : "What architecture patterns should I avoid?"
Tokens   : ["architectur", "pattern", "avoid"]

→ architecture : 2 matchs ("architectur", "pattern") → score 0.67
→ mistakes      : 1 match  ("avoid")                → score 0.33
→ best-practices: 1 match  ("pattern")              → score 0.33
→ Autres        : 0 match                            → score 0.0
```

**Transposition pi-cortex :** ✅ Directe — mapping catégories → filtre sur `Knowledge.category` dans Neo4j.

---

### 3.2 Résolution de routage

**Source :** `knowledge_router.py::resolve_routing()`

**But :** Décider du scope de recherche (quels fichiers/catégories interroger).

**Principe — 3 modes :**

```python
# Mode 1 — "auto"
#   Détecte les catégories > seuil (0.3 par défaut)
#   Garde les top 2 catégories
#   Si aucune > seuil → fallback-global

# Mode 2 — "explicit-category"
#   L'utilisateur force une catégorie : ?category=architecture
#   Valide que la catégorie existe
#   Erreur si catégorie invalide

# Mode 3 — "fallback-global"
#   Cherche dans TOUS les fichiers (global + projet)
#   Déclenché automatiquement si aucune catégorie > seuil
```

**Seuil de confiance :** `DEFAULT_CONFIDENCE_THRESHOLD = 0.3`
```
top_score ≥ 0.3 → routage automatique (top 2 catégories)
top_score < 0.3 → fallback-global (tous les fichiers)
```

**Transposition pi-cortex :** ✅ Directe — paramètre `category` et `routing_mode` dans `/api/search`.

---

## 4. Strategy Learning (méta-apprentissage)

### 4.1 Score d'étape

**Source :** `strategy_learning.py::_step_score()`

**But :** Évaluer la performance d'une action individuelle de l'agent.

**Principe :**
```python
def _step_score(step: dict) -> float:
    status = step.get("status")
    if status == "ok":       return 1.0
    elif status == "skipped": return 0.35
    else:                     return -0.8  # "failed"
```

**Interprétation :**
- Succès = +1.0 (renforcement positif)
- Sauté = +0.35 (neutre, mais on note que l'action a été tentée)
- Échec = -0.8 (pénalité forte, mais pas -1.0 pour garder une trace)

**Transposition pi-cortex :** ✅ Utilisé par le Gardener (mission 14 — feedback loop) pour scorer les actions.

---

### 4.2 Score de run

**Source :** `strategy_learning.py::score_run()`

**But :** Agréger les scores d'étapes en un score global pour la session.

**Principe :**
```python
def score_run(run_record) -> (float, best_action):
    steps = run_record.get("steps", [])
    if not steps:
        # Pas d'étapes → score dégradé par les issues
        issues_penalty = min(len(issues) * 0.1, 0.5)
        return max(0.1, 0.6 - issues_penalty), "no-action"

    # Moyenne des scores d'étapes
    scored = [(step.action, _step_score(step)) for step in steps]
    average = sum(s for _, s in scored) / len(scored)

    # Pénalité par issue détectée
    issues_penalty = min(len(issues) * 0.08, 0.4)

    run_score = max(0.1, average + 0.3 - issues_penalty)
    best_action = max(scored, key=lambda x: x[1])[0]
    return run_score, best_action
```

**Plancher :** toujours ≥ 0.1 (même en cas d'échec total).

**Transposition pi-cortex :** ✅ Utilisé par le Gardener pour évaluer la qualité d'une session.

---

### 4.3 Poids de stratégie (ACO)

**Source :** `strategy_learning.py::_strategy_weight()`

**But :** Donner un poids aux stratégies d'action basé sur leur historique.

**Formule :**
```python
reliability = successes / max(successes + failures, 1.0)
recency     = exp(-days_ago / decay_days)
weight      = uses × recency × (0.35 + reliability) × max(average_score, 0.1)

# decay_days = 45 (plus long que les phéromones de connaissance)
```

**Composants :**
| Composant | Rôle | Plage |
|-----------|------|:---:|
| `uses` | Compteur d'utilisation | ≥ 0 |
| `recency` | Décroissance temporelle | 0 → 1 |
| `reliability` | Ratio succès/échecs | 0 → 1 |
| `0.35 + reliability` | Bonus fiabilité (plancher 0.35) | 0.35 → 1.35 |
| `average_score` | Score moyen historique | 0.1 → 1.0 |

**Pourquoi decay_days=45 vs 30 pour les connaissances ?**
Les stratégies évoluent plus lentement que les connaissances. Une stratégie qui a marché il y a un mois est probablement encore bonne.

**Transposition pi-cortex :** ✅ Le Gardener ajuste les poids des stratégies (mission 14). Stocké dans un nœud `Strategy` Neo4j.

---

### 4.4 Recommandation adaptative

**Source :** `strategy_learning.py::recommend_strategies()`

**But :** Avant d'exécuter une action, choisir la meilleure stratégie basée sur l'historique.

**Principe :**
```python
def recommend_strategies(target_root, candidates, top_k=3):
    payload = load_strategy_weights(target_root)
    ranked = []
    for strategy in candidates:
        entry = payload["weights"].get(strategy, {})
        ranked.append({
            "strategy": strategy,
            "weight": entry.get("weight", 0.0),
            "average_score": entry.get("average_score", 0.0),
        })
    ranked.sort(key=lambda x: (x["weight"], x["average_score"]), reverse=True)
    return ranked[:top_k]
```

**Usage dans `engine.py::run_auto()` :**
```python
state = classify(root, goal, ctx)
_update_adaptive_recommendations(ctx, state)
# → ctx.adaptive_recommendations = [
#     "install-bundle (w=12.50, score=0.92)",
#     "bootstrap (w=8.30, score=0.85)",
#     ...
# ]
```

L'agent sait quelle action a le meilleur track record pour l'état courant.

**Transposition pi-cortex :** ✅ L'extension Pi utilise ces recommandations dans `before_agent_start` pour guider l'agent.

---

## 5. Machine à états

### 5.1 Classifieur déterministe

**Source :** `state.py::classify()` / `engine.py::STATE_STRATEGY_CANDIDATES`

**But :** Déterminer l'état du repo en une chaîne de prédicats simples.

**États (dans l'ordre) :**
```
CORRUPT_MANIFEST   ← manifest.json corrompu ou version incompatible
    ↓
BUNDLE_MISSING     ← AGENTS.md ou fichiers globaux absents
    ↓
MEMORY_MISSING     ← project/memory/ absent
    ↓
SEED_PENDING       ← --seed-from-project spécifié mais pas appliqué
    ↓
HANDOFF_STALE      ← last-handoff.json absent, expiré, ou déjà consommé
    ↓
EXTRACT_PENDING    ← pending-review existe mais last-extract absent
    ↓
CONSOLIDATE_READY  ← ≥2 fichiers dans pending-review/
    ↓
STEADY_STATE       ← tout est en ordre
```

**Propriétés :**
- Ordre strict — le premier état qui matche est retourné
- Chaque prédicat est une fonction pure (lit le filesystem)
- Pas d'inférence, pas de ML — 100% déterministe
- Mapping `STATE_STRATEGY_CANDIDATES` → actions recommandées par état

**Mapping état → stratégies candidates :**
```python
STATE_STRATEGY_CANDIDATES = {
    BUNDLE_MISSING:    ["install-bundle"],
    MEMORY_MISSING:    ["install-bundle"],
    SEED_PENDING:      ["apply-seed", "bootstrap"],
    HANDOFF_STALE:     ["bootstrap", "extract-memory"],
    EXTRACT_PENDING:   ["extract-memory", "bootstrap"],
    CONSOLIDATE_READY: ["consolidate"],
    STEADY_STATE:      ["bootstrap", "extract-memory", "consolidate"],
}
```

**Transposition pi-cortex :** ✅ L'extension Pi implémente ce classifieur pour déterminer l'état de la mémoire Neo4j + vault.

---

## 6. Tableau récapitulatif

| # | Algorithme | Catégorie | Complexité | Dépendances | Fichier source |
|---|-----------|-----------|:---:|-------------|----------------|
| 1 | Porter-lite Stemmer | Recherche | O(n) | Aucune | `mcp_memory_server.py` |
| 2 | Tokenisation + scoring lexical | Recherche | O(n×m) | Stemmer | `mcp_memory_server.py` |
| 3 | Scoring combiné lexical × phéromone | Ranking | O(k) | ACO | `mcp_memory_server.py` |
| 4 | Excerpt adaptatif | UX | O(1) | Aucune | `knowledge_router.py` |
| 5 | Token budgeting | Optimisation | O(k log k) | Aucune | `mcp_memory_server.py` |
| 6 | ACO phéromone decay | Ranking | O(1)/arête | Exp | `mcp_memory_server.py` |
| 7 | Batch flush | I/O | O(1) amorti | `os.replace` | `mcp_memory_server.py` |
| 8 | Seeding initial | Cold start | O(n) | ACO | Design doc |
| 9 | Détection catégorie par lexique | Routage | O(c×t) | Stemmer | `knowledge_router.py` |
| 10 | Résolution de routage | Routage | O(c) | Taxonomy | `knowledge_router.py` |
| 11 | Score d'étape | Méta | O(1) | Aucune | `strategy_learning.py` |
| 12 | Score de run | Méta | O(s) | Score étape | `strategy_learning.py` |
| 13 | Poids stratégie ACO | Méta | O(1) | Exp, ACO | `strategy_learning.py` |
| 14 | Recommandation adaptative | Méta | O(k log k) | ACO stratégie | `strategy_learning.py` |
| 15 | Classifieur déterministe | État | O(1) | Aucune | `state.py` |

> **Légende complexité :** n = longueur mot, m = mots section, k = résultats, c = catégories, t = tokens requête, s = steps

---

## 7. Transposition à Neo4j / pi-cortex

### Ce qui change avec Neo4j

| Concept original | Implémentation originale | Transposition Neo4j |
|---|---|---|
| Fichiers `.md` | `pathlib.Path` glob | Nœuds `Knowledge` avec propriété `content` |
| Poids phéromone | `weights.json` (dict Python) | Propriétés `pheromone`, `uses` sur les arêtes `RELATED_TO` |
| Catégories | `taxonomy.json` → `allowed_filenames` | Propriété `category` sur les nœuds `Knowledge` |
| Scoring lexical | Python en mémoire | Cypher avec `reduce()` + APOC text functions |
| Évaporation | Calcul en lecture | Job Gardener (daily) + calcul en lecture |
| Stratégies | `strategy-weights.json` | Nœuds `Strategy` avec propriétés `uses`, `successes`, `failures` |
| États repo | Filesystem checks | Checks Neo4j + vault Markdown |
| Excerpt | Substring Python | `apoc.text.split()` ou substring Cypher |

### Formules Neo4j équivalentes

```cypher
// Phéromone decay (équivalent algorithme 6)
MATCH ()-[r:RELATED_TO]->()
WHERE r.last_used IS NOT NULL
SET r.pheromone = r.pheromone * exp(
  -duration.between(date(r.last_used), date()).days / 30.0
)

// Scoring combiné (équivalent algorithme 3)
// En lecture : lexical_score × (1.0 + r.pheromone)

// PageRank (équivalent algorithme 14 pour les connaissances)
CALL gds.pageRank.stream('knowledgeGraph', {
  relationshipWeightProperty: 'pheromone',
  dampingFactor: 0.85
})
```

### Ce qui reste identique

- **Stemmer Porter-lite** : implémenté en TypeScript (mêmes règles)
- **Excerpt adaptatif** : seuils 0.7 / 0.4 / 0.0
- **Token budgeting** : même algorithme de densité
- **Classifieur d'état** : mêmes prédicats, adaptés à Neo4j
- **Score étape/run** : mêmes formules, stockage Neo4j
- **Batch flush** : pattern identique en Node.js

---

*Extraction et analyse terminées le 2026-05-03.*
*Source : `codex-claude-memory-autopilot` — Projet sous licence MIT.*