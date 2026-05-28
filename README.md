# Maeve // Lost Signal — Guide de contenu

Visual novel au format SMS réalisé avec Godot 4.6. Tout le contenu narratif est défini dans un seul fichier JSON, sans toucher au code.

---

## Sommaire

1. [Structure du fichier `dialogue.json`](#1-structure-du-fichier-dialoguejson)
2. [Contacts](#2-contacts)
3. [Scènes](#3-scènes)
4. [Messages (`messages_in`)](#4-messages-messages_in)
5. [Choix (`choices`)](#5-choix-choices)
6. [Modifications de message (`edit`)](#6-modifications-de-message-edit)
7. [Flags (booléens)](#7-flags-booléens)
8. [Variables numériques (`vars`)](#8-variables-numériques-vars)
9. [Déclencheurs (`trigger_after_scene`)](#9-déclencheurs-trigger_after_scene)
10. [Exemple complet annoté](#10-exemple-complet-annoté)
11. [Export web (Itch.io)](#11-export-web-itchio)

---

## 1. Structure du fichier `dialogue.json`

```
dialogue.json
├── contacts   → liste des personnages
└── scenes     → liste de toutes les scènes de dialogue
```

```json
{
  "contacts": [ ... ],
  "scenes":   [ ... ]
}
```

---

## 2. Contacts

Chaque contact représente un personnage avec qui le joueur peut recevoir des messages.

```json
{
  "id":      "maeve",
  "name":    "Maeve",
  "is_main": true,
  "avatar":  null
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Identifiant unique, utilisé dans les scènes. Ne pas changer après coup. |
| `name` | string | Nom affiché dans la barre supérieure et le panneau contacts. |
| `is_main` | bool | `true` pour le contact principal (celui que le joueur peut répondre activement). Un seul contact `is_main: true`. |
| `avatar` | string \| null | Chemin vers une image (`"res://assets/maeve.png"`) ou `null` pour afficher l'initiale. |

---

## 3. Scènes

Une scène est un bloc de messages entrants, éventuellement suivi de choix.

```json
{
  "id":                  "scene_01",
  "contact_id":          "maeve",
  "trigger_after_scene": null,
  "messages_in":         [ ... ],
  "choices":             [ ... ]
}
```

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| `id` | string | oui | Identifiant unique de la scène. |
| `contact_id` | string | non | Quel contact envoie ces messages. Par défaut : le contact `is_main`. |
| `trigger_after_scene` | string \| null | non | ID de la scène après laquelle cette scène se déclenche automatiquement. Voir [Déclencheurs](#8-déclencheurs-trigger_after_scene). |
| `messages_in` | array | oui | Liste des messages à afficher. |
| `choices` | array | non | Liste des options de réponse pour le joueur. Si absent, la scène passe directement à la suivante. |

---

## 4. Messages (`messages_in`)

```json
{
  "text":          "Je sais pas si ce message va partir.",
  "time":          "14:24",
  "requires_flag": null,
  "pause":         "short",
  "edit":          null
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `text` | string | Contenu du message. |
| `time` | string | Horodatage affiché (`"HH:MM"`). Valeur indicative — le jeu affiche l'heure système réelle. |
| `requires_flag` | string \| null | Nom d'un flag. Le message n'est affiché que si ce flag est actif. `null` = toujours affiché. |
| `pause` | string \| null | Délai **avant** l'affichage de ce message. Valeurs : `"short"` (1–4 s), `"medium"` (5–15 s), `"long"` (15–40 s), `null` (aucune pause). |
| `edit` | object \| null | Modification qui apparaît après l'envoi. Voir [ci-dessous](#6-modifications-de-message-edit). `null` = message définitif. |

---

## 5. Choix (`choices`)

Les choix s'affichent après que tous les `messages_in` de la scène ont été joués.

```json
{
  "text":    "Qui est-ce ?",
  "message": "Euh... qui êtes-vous exactement ? Comment avez-vous eu ce numéro ?",
  "next":    "scene_02a",
  "flag":    null
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `text` | string | Label du bouton de choix. |
| `message` | string | Ce que le joueur "tape" et envoie (animation de frappe + bulle sortante). |
| `next` | string | ID de la scène à jouer après ce choix. |
| `flag` | string \| null | Nom du flag à activer quand ce choix est sélectionné. `null` = aucun flag. |

> **Maximum 3 choix par scène** (contrainte UI actuelle).

---

## 6. Modifications de message (`edit`)

Permet de simuler une correction de faute de frappe ou la suppression d'un message.

### Correction

```json
"edit": {
  "type":           "correct",
  "corrected_text": "Désolée",
  "delay":          1.5
}
```

Le texte original s'affiche d'abord, puis est remplacé par `corrected_text` après `delay` secondes.

### Suppression

```json
"edit": {
  "type":  "delete",
  "delay": 2.0
}
```

Le message s'affiche puis disparaît après `delay` secondes.

| Champ | Type | Description |
|-------|------|-------------|
| `type` | `"correct"` \| `"delete"` | Type de modification. |
| `corrected_text` | string | Texte de remplacement (`"correct"` uniquement). |
| `delay` | float | Secondes avant que la modification s'applique. |

---

## 7. Flags (booléens)

Les flags sont des interrupteurs vrai/faux. Ils persistent dans la sauvegarde.

**Activer un flag** via un choix :
```json
{ "text": "...", "message": "...", "next": "...", "flag": "alerted_police" }
```

**Conditionner un message** à un flag actif :
```json
{ "text": "On a appelé la police.", "requires_flag": "alerted_police", ... }
```

---

## 8. Variables numériques (`vars`)

Les variables permettent de stocker des valeurs entières (compteurs, scores, niveaux de confiance…). Elles persistent dans la sauvegarde.

### Modifier une variable via un choix — `effects`

Ajouter un tableau `"effects"` à un choix. Chaque effet spécifie `var`, `op` et `value`.

```json
{
  "text": "Je vous crois.",
  "message": "OK, je vous crois.",
  "next": "scene_04",
  "flag": null,
  "effects": [
    { "var": "confiance", "op": "add", "value": 1 }
  ]
}
```

| `op` | Effet |
|------|-------|
| `"set"` | Fixe la variable à `value` |
| `"add"` | Ajoute `value` |
| `"sub"` | Soustrait `value` |

Un choix peut cumuler plusieurs effets dans le tableau, et peut utiliser `flag` et `effects` en même temps.

### Conditionner un message à une variable — `condition`

```json
{
  "text": "Tu m'as fait confiance dès le début...",
  "time": "15:00",
  "requires_flag": null,
  "pause": null,
  "edit": null,
  "condition": { "var": "confiance", "op": "gte", "value": 3 }
}
```

| `op` | Signification |
|------|---------------|
| `"eq"` | égal à |
| `"neq"` | différent de |
| `"gt"` | strictement supérieur |
| `"gte"` | supérieur ou égal |
| `"lt"` | strictement inférieur |
| `"lte"` | inférieur ou égal |

`requires_flag` et `condition` peuvent être combinés : le message ne s'affiche que si **les deux** conditions sont vraies.

---

## 9. Déclencheurs (`trigger_after_scene`)

Permet de déclencher une scène (typiquement d'un contact secondaire) automatiquement après qu'une autre scène s'est terminée.

```json
{
  "id":                  "alex_01",
  "contact_id":          "alex",
  "trigger_after_scene": "scene_02a",
  ...
}
```

Ici, `alex_01` se déclenche dès que `scene_02a` est terminée.

- Si le contact `alex` n'est pas celui affiché, les messages vont silencieusement dans son historique et un badge "non lu" apparaît dans le panneau contacts.
- Plusieurs scènes peuvent avoir le même `trigger_after_scene` : elles se jouent toutes dans l'ordre.

---

## 10. Exemple complet annoté

```json
{
  "contacts": [
    { "id": "maeve", "name": "Maeve", "is_main": true,  "avatar": null },
    { "id": "alex",  "name": "Alex",  "is_main": false, "avatar": null }
  ],
  "scenes": [

    {
      "id": "scene_01",
      "messages_in": [
        { "text": "...Hello?",                        "time": "14:23", "requires_flag": null, "pause": null,    "edit": null },
        { "text": "Je sais pas si ce message va partir.", "time": "14:24", "requires_flag": null, "pause": "short", "edit": null },
        { "text": "Y a quelqu'un ?",                  "time": "14:24", "requires_flag": null, "pause": "short", "edit": null }
      ],
      "choices": [
        { "text": "Qui est-ce ?",        "message": "Euh... qui êtes-vous ?", "next": "scene_02a", "flag": null },
        { "text": "Oui. Tout va bien ?", "message": "Oui, je suis là.",       "next": "scene_02b", "flag": null }
      ]
    },

    {
      "id": "scene_02a",
      "messages_in": [
        { "text": "Desole",                   "time": "14:27", "requires_flag": null, "pause": null, "edit": { "type": "correct", "corrected_text": "Désolée", "delay": 1.5 } },
        { "text": "J'ai un problème !!",      "time": "14:27", "requires_flag": null, "pause": "short", "edit": null }
      ]
    },

    {
      "id": "alex_01",
      "contact_id": "alex",
      "trigger_after_scene": "scene_02a",
      "messages_in": [
        { "text": "T'as des nouvelles de Maeve ?", "time": "14:35", "requires_flag": null, "pause": null, "edit": null }
      ],
      "choices": [
        { "text": "Oui, elle a des ennuis.", "message": "Oui. Tu vas pas aimer…", "next": "alex_02a", "flag": "told_alex" }
      ]
    }

  ]
}
```

---

## 11. Export web (Itch.io)

### Prérequis

1. Dans Godot : **Editor → Manage Export Templates** → télécharger les templates pour la version 4.6.
2. Le fichier `export_presets.cfg` (déjà inclus dans le projet) configure l'export Web.

### Exporter

```
Projet → Exporter → Web → Export Project
```

Les fichiers sont générés dans `exports/web/`. Créer ce dossier si nécessaire.

### Mettre en ligne sur Itch.io

1. Zipper le contenu du dossier `exports/web/` (pas le dossier lui-même, son contenu).
2. Sur Itch.io : **Upload files** → cocher **"This file will be played in the browser"**.
3. Dans les paramètres du projet Itch.io, activer **"SharedArrayBuffer support"** si disponible, ou laisser désactivé (l'export est configuré pour fonctionner sans).

> **Résolution** : le jeu est en 1920×1080 avec `stretch/mode = canvas_items`. Il s'adapte à toutes les tailles d'écran automatiquement.

---

## Flux de travail recommandé

1. Ouvrir `dialogue.json` dans n'importe quel éditeur de texte.
2. Ajouter ou modifier scènes et messages.
3. Lancer le jeu dans Godot (F5) pour tester.
4. Vérifier la console Godot pour les erreurs de parsing JSON.
5. Supprimer `user://savegame.json` (ou utiliser le bouton Reset en jeu) pour repartir du début.
