# Maeve // Lost Signal — Guide de contenu

Visual novel au format SMS réalisé avec Godot 4.6. Tout le contenu narratif est défini dans des fichiers JSON, sans toucher au code.

---

## Sommaire

1. [Organisation des fichiers](#1-organisation-des-fichiers)
2. [Contacts (`story.json`)](#2-contacts-storyjson)
3. [Scènes](#3-scènes)
4. [Messages (`messages_in`)](#4-messages-messages_in)
5. [Messages médias (images et audio)](#5-messages-médias-images-et-audio)
6. [Choix (`choices`)](#6-choix-choices)
7. [Modifications de message (`edit`)](#7-modifications-de-message-edit)
8. [Flags (booléens)](#8-flags-booléens)
9. [Variables numériques (`vars`)](#9-variables-numériques-vars)
10. [Déclencheurs (`trigger_after_scene`)](#10-déclencheurs-trigger_after_scene)
11. [Thème visuel (`theme.json`)](#11-thème-visuel-themejson)
12. [Exemple complet annoté](#12-exemple-complet-annoté)
13. [Export web (Itch.io)](#13-export-web-itchio)

---

## 1. Organisation des fichiers

```
projet/
├── story.json          ← configuration du jeu (contacts, scène de départ)
├── dialogues/
│   ├── acte1.json      ← scènes de l'acte 1
│   ├── acte2.json      ← scènes de l'acte 2
│   └── arc_alex.json   ← arc narratif secondaire (exemple)
└── assets/
    ├── images/         ← images envoyées dans les bulles (PNG, JPG…)
    └── sounds/         ← messages audio (OGG recommandé, MP3 et WAV supportés)
```

### `story.json` — à configurer une fois, ne plus toucher

Ce fichier déclare les personnages et la scène par laquelle commence le jeu. Il n'a pas besoin d'être modifié pour ajouter du contenu.

```json
{
  "start_scene": "scene_01",
  "contacts": [
    { "id": "maeve", "name": "Maeve", "is_main": true,  "avatar": null },
    { "id": "alex",  "name": "Alex",  "is_main": false, "avatar": null }
  ]
}
```

### `dialogues/` — tout le contenu narratif

Chaque fichier dans ce dossier est chargé automatiquement. Il suffit d'y déposer un nouveau `.json` pour que ses scènes soient disponibles dans le jeu — aucune déclaration supplémentaire n'est nécessaire.

Un fichier de dialogues ne contient qu'un tableau `"scenes"` :

```json
{
  "scenes": [
    { ... },
    { ... }
  ]
}
```

> **ID en double** : si deux fichiers définissent une scène avec le même `id`, le second est ignoré et un avertissement apparaît dans la console Godot.

> **Notes internes** : un champ `"_notes"` peut être ajouté sur n'importe quel objet (scène, message, choix). Il est ignoré par le jeu et sert uniquement à documenter l'intention de l'auteur.

---

## 2. Contacts (`story.json`)

Chaque contact représente un personnage avec qui le joueur échange des messages.

```json
{ "id": "maeve", "name": "Maeve", "is_main": true, "avatar": null }
```

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Identifiant unique, référencé dans les scènes. Ne pas modifier après coup. |
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
| `trigger_after_scene` | string \| null | non | ID de la scène après laquelle cette scène se déclenche automatiquement. Voir [§9](#9-déclencheurs-trigger_after_scene). |
| `resume_after_flag` | string \| null | non | Nom d'un flag. La scène est mise en attente jusqu'à ce que ce flag soit posé par un choix. |
| `messages_in` | array | oui | Liste des messages à afficher. |
| `choices` | array | non | Choix proposés au joueur. Si absent, la narration s'arrête à cette scène. |

---

## 4. Messages (`messages_in`)

```json
{
  "text":          "Je sais pas si ce message va partir.",
  "time":          "14:24",
  "requires_flag": null,
  "pause":         "short",
  "edit":          null,
  "condition":     null
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `text` | string \| null | Contenu du message. `null` = événement silencieux (aucune bulle), ou message média (utiliser `media` à la place). |
| `time` | string | Horodatage affiché (`"HH:MM"`). Valeur indicative — le jeu affiche l'heure système réelle. |
| `requires_flag` | string \| null | Le message ne s'affiche que si ce flag booléen est actif. `null` = toujours affiché. |
| `pause` | string \| null | Délai **avant** l'affichage de ce message : `"short"` (1–4 s), `"medium"` (5–15 s), `"long"` (15–40 s), `null` (aucune pause). |
| `edit` | object \| null | Modification qui apparaît après l'envoi. Voir [§7](#7-modifications-de-message-edit). |
| `condition` | object \| null | Condition sur une variable numérique. Voir [§9](#9-variables-numériques-vars). |
| `effects` | array | Effets à exécuter au moment où ce message est joué. Même format que les effets de choix. `[]` ou absent = aucun effet. |
| `media` | object \| null | Image ou message audio. Voir [§5](#5-messages-médias-images-et-audio). |

`requires_flag` et `condition` peuvent être combinés : le message ne s'affiche que si **les deux** sont vraies.

---

## 5. Messages médias (images et audio)

Un message peut envoyer une image ou un message audio à la place d'un texte. Le champ `text` doit être `null` et `media` doit être renseigné.

### Image

```json
{
  "text":  null,
  "time":  "14:43",
  "pause": "short",
  "media": { "type": "image", "path": "res://assets/images/lieu.png" }
}
```

L'image s'affiche dans une bulle cliquable. Un clic ouvre la photo en plein écran.

Formats supportés : PNG, JPG, WEBP. Placer les fichiers dans `assets/images/`.

### Message audio

```json
{
  "text":  null,
  "time":  "14:44",
  "pause": "short",
  "media": { "type": "audio", "path": "res://assets/sounds/voicenote.ogg" }
}
```

Une bulle avec un bouton ▶/⏸, une barre de progression et la durée restante est affichée. Le joueur peut démarrer et stopper la lecture.

Formats supportés : OGG (recommandé), MP3, WAV. Placer les fichiers dans `assets/sounds/`.

> Les médias sont sauvegardés dans la progression et réaffichés correctement lors d'un chargement.

---

## 6. Choix (`choices`)

Les choix s'affichent après que tous les `messages_in` de la scène ont été joués.

```json
{
  "text":    "Qui est-ce ?",
  "message": "Euh... qui êtes-vous exactement ?",
  "next":    "scene_02a",
  "flag":    null,
  "effects": []
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `text` | string | Label du bouton de choix. |
| `message` | string \| array | Ce que le joueur "tape" et envoie. Chaîne = un seul message. Tableau de chaînes = plusieurs messages envoyés en séquence, chacun avec son animation de frappe. |
| `next` | string | ID de la scène à jouer après ce choix. |
| `flag` | string \| null | Nom du flag booléen à activer. `null` = aucun. |
| `effects` | array | Liste d'effets sur des variables numériques. Voir [§8](#8-variables-numériques-vars). `[]` = aucun. |

> **Maximum 3 choix par scène** (contrainte UI actuelle).

### Envoyer plusieurs messages avec un choix

```json
{
  "text":    "Mouais… curieux quand même.",
  "message": ["Mouais je suis pas convaincu…", "mais je suis curieux de voir où ça va."],
  "next":    "scene_02",
  "flag":    null,
  "effects": []
}
```

Chaque entrée du tableau déclenche une animation de frappe indépendante avant d'afficher la bulle. La scène `next` ne se lance qu'après le dernier message.

---

## 7. Modifications de message (`edit`)

Permet de simuler une correction de faute de frappe ou la suppression d'un message après envoi.

### Correction

```json
"edit": { "type": "correct", "corrected_text": "Désolée", "delay": 1.5 }
```

Le texte original s'affiche, puis est remplacé par `corrected_text` après `delay` secondes.

### Suppression

```json
"edit": { "type": "delete", "delay": 2.0 }
```

Le message s'affiche puis disparaît après `delay` secondes.

| Champ | Type | Description |
|-------|------|-------------|
| `type` | `"correct"` \| `"delete"` | Type de modification. |
| `corrected_text` | string | Texte de remplacement (`"correct"` uniquement). |
| `delay` | float | Secondes avant que la modification s'applique. |

---

## 8. Flags (booléens)

Les flags sont des interrupteurs vrai/faux. Ils persistent dans la sauvegarde et sont remis à zéro à la nouvelle partie.

**Activer un flag** via un choix :
```json
{ "text": "...", "message": "...", "next": "...", "flag": "a_appele_police" }
```

**Conditionner un message** à un flag actif :
```json
{ "text": "On a appelé la police.", "requires_flag": "a_appele_police", ... }
```

---

## 9. Variables numériques (`vars`)

Les variables stockent des valeurs entières (compteur, score, niveau de confiance…). Elles persistent dans la sauvegarde.

### Modifier une variable via un choix — `effects`

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

| `op` | Champ requis | Effet |
|------|-------------|-------|
| `"set"` | `"var"`, `"value"` | Fixe la variable à `value` |
| `"add"` | `"var"`, `"value"` | Ajoute `value` |
| `"sub"` | `"var"`, `"value"` | Soustrait `value` |
| `"rename"` | `"contact"`, `"value"` | Change le nom affiché d'un contact |
| `"set_status"` | `"contact"`, `"value"` | Change le statut affiché d'un contact |

Un choix peut cumuler plusieurs effets et utiliser `flag` et `effects` simultanément.

### Statut d'un contact — `story.json`

Le statut initial se déclare dans `story.json` :

```json
{ "id": "maeve", "name": "Maeve", "is_main": true, "avatar": null, "status": "network_issue" }
```

| Valeur | Indicateur | Texte affiché |
|--------|------------|---------------|
| `"online"` | ● vert | en ligne |
| `"away"` | ● jaune | absent |
| `"offline"` | ● rouge | hors ligne |
| `"network_issue"` | ● rouge clignotant + ⚠ | problème réseau |

Si `"status"` est absent, le contact est considéré `"online"` par défaut.

### Changer le statut en cours de jeu — `"set_status"`

```json
"effects": [{ "op": "set_status", "contact": "maeve", "value": "offline" }]
```

Le changement est immédiat dans la topbar et persiste dans la sauvegarde.

### Renommer un contact — `"rename"`

Permet de révéler le vrai nom d'un contact initialement connu sous un numéro ou un pseudonyme.

Dans `story.json`, déclarer le contact avec son nom initial :
```json
{ "id": "maeve", "name": "+33 6 12 34 56 78", "is_main": true, "avatar": null }
```

Dans un choix, déclencher la révélation :
```json
{
  "text": "Vous avez un prénom ?",
  "message": "Attendez... vous avez un prénom ?",
  "next": "scene_04",
  "flag": null,
  "effects": [
    { "op": "rename", "contact": "maeve", "value": "Maeve" }
  ]
}
```

Le nom est mis à jour immédiatement dans la barre supérieure et le panneau contacts, et persiste dans la sauvegarde.

### Conditionner un message à une variable — `condition`

```json
{
  "text": "Tu m'as fait confiance dès le début...",
  "condition": { "var": "confiance", "op": "gte", "value": 3 },
  ...
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

---

## 10. Déclencheurs (`trigger_after_scene`)

Déclenche automatiquement une scène dès qu'une autre est terminée. Utile pour les contacts secondaires qui réagissent en parallèle.

```json
{
  "id":                  "alex_01",
  "contact_id":          "alex",
  "trigger_after_scene": "scene_02a",
  "messages_in":         [ ... ]
}
```

`alex_01` se déclenche dès que `scene_02a` se termine. Si le joueur est sur une autre conversation, les messages arrivent silencieusement et un badge "non lu" apparaît dans le panneau contacts.

Plusieurs scènes peuvent partager le même `trigger_after_scene` — elles se jouent toutes dans l'ordre de chargement.

---

## 11. Thème visuel (`theme.json`)

Créer un fichier `theme.json` à la racine du projet pour personnaliser l'apparence. Supprimer ce fichier revient au thème par défaut.

```json
{
  "background_color": "#0B0E11",
  "topbar_color":     "#1F2C34",
  "bubble_in_color":  "#21303D",
  "bubble_out_color": "#00705C",
  "accent_color":     "#00A884",
  "text_color":       "#E9EDEF",
  "time_color":       "#8696A0",
  "font_size":        15,
  "typing_speed":     0.05
}
```

| Clé | Description |
|-----|-------------|
| `background_color` | Fond de l'écran et zone de messages |
| `topbar_color` | Barre supérieure, panneau contacts, barre de saisie |
| `bubble_in_color` | Bulles entrantes (texte, image, audio) |
| `bubble_out_color` | Bulles sortantes (réponses du joueur) |
| `accent_color` | Avatar, survol des boutons de choix |
| `text_color` | Texte des messages et des boutons |
| `time_color` | Horodatages |
| `font_size` | Taille de police des messages (entier, px) |
| `typing_speed` | Vitesse de frappe du joueur (secondes par caractère) |

Seules les clés présentes dans le fichier sont appliquées — les autres gardent leur valeur par défaut. Les couleurs sont au format `#RRGGBB`.

---

## 12. Exemple complet annoté

`story.json` :

```json
{
  "start_scene": "ch1_intro",
  "contacts": [
    { "id": "maeve", "name": "Maeve", "is_main": true,  "avatar": null },
    { "id": "alex",  "name": "Alex",  "is_main": false, "avatar": null }
  ]
}
```

`dialogues/acte1.json` :

```json
{
  "scenes": [
    {
      "_notes": "Scène d'ouverture — 2 choix qui affectent la variable confiance",
      "id": "ch1_intro",
      "messages_in": [
        { "text": "...Hello?",          "time": "14:23", "requires_flag": null, "pause": null,    "edit": null, "condition": null },
        { "text": "Y a quelqu'un là ?", "time": "14:24", "requires_flag": null, "pause": "short", "edit": null, "condition": null }
      ],
      "choices": [
        { "text": "Je vous crois.",     "message": "OK, racontez-moi.", "next": "ch1_a", "flag": "approche_douce", "effects": [{ "var": "confiance", "op": "add", "value": 2 }] },
        { "text": "Qui êtes-vous ?",    "message": "Qui est-ce ?",      "next": "ch1_b", "flag": null,             "effects": [{ "var": "confiance", "op": "add", "value": 1 }] }
      ]
    },
    {
      "_notes": "edit:correct — faute de frappe corrigée après 1.5s",
      "id": "ch1_a",
      "messages_in": [
        { "text": "Desole",              "time": "14:26", "requires_flag": null,           "pause": null,    "edit": { "type": "correct", "corrected_text": "Désolée", "delay": 1.5 }, "condition": null },
        { "text": "Ta douceur m'aide.",  "time": "14:26", "requires_flag": "approche_douce", "pause": "short", "edit": null, "condition": null },
        { "text": "J'ai besoin d'aide.", "time": "14:27", "requires_flag": null,           "pause": null,    "edit": null, "condition": { "var": "confiance", "op": "gte", "value": 2 } }
      ]
    },
    {
      "_notes": "Arc Alex déclenché en parallèle après ch1_a",
      "id": "alex_01",
      "contact_id": "alex",
      "trigger_after_scene": "ch1_a",
      "messages_in": [
        { "text": "T'as des nouvelles de Maeve ?", "time": "14:35", "requires_flag": null, "pause": null, "edit": null, "condition": null }
      ],
      "choices": [
        { "text": "Oui, elle m'écrit.", "message": "Je parle avec elle là.", "next": "alex_02", "flag": null, "effects": [{ "var": "alex_info", "op": "set", "value": 1 }] },
        { "text": "Non.",              "message": "Aucune idée.",            "next": "alex_02", "flag": null, "effects": [{ "var": "alex_info", "op": "set", "value": 0 }] }
      ]
    },
    {
      "id": "alex_02",
      "contact_id": "alex",
      "messages_in": [
        { "text": "Tant mieux !",              "time": "14:36", "requires_flag": null, "pause": null, "edit": null, "condition": { "var": "alex_info", "op": "eq", "value": 1 } },
        { "text": "Je commence à m'inquiéter.", "time": "14:36", "requires_flag": null, "pause": null, "edit": null, "condition": { "var": "alex_info", "op": "eq", "value": 0 } }
      ]
    }
  ]
}
```

---

## 13. Export web (Itch.io)

### Prérequis

1. Dans Godot : **Editor → Manage Export Templates** → télécharger les templates pour la version 4.6.
2. Le fichier `export_presets.cfg` (déjà inclus dans le projet) configure l'export Web.

### Exporter

```
Projet → Exporter → Web → Export Project
```

Les fichiers sont générés dans `exports/web/`. Créer ce dossier si nécessaire.

### Mettre en ligne sur Itch.io

1. Zipper le **contenu** du dossier `exports/web/` (pas le dossier lui-même).
2. Sur Itch.io : **Upload files** → cocher **"This file will be played in the browser"**.
3. Laisser "SharedArrayBuffer support" désactivé — l'export est configuré pour fonctionner sans.

> **Résolution** : le jeu est en 1920×1080 avec `stretch/mode = canvas_items`. Il s'adapte à toutes les tailles d'écran automatiquement.

---

## Flux de travail

1. Configurer `story.json` une fois : `start_scene` et liste des contacts.
2. Créer un fichier `.json` dans `dialogues/` et y écrire un tableau `"scenes"`.
3. Lancer le jeu dans Godot (F5) pour tester.
4. Lire la console Godot au démarrage — le validator signale automatiquement :
   - les références cassées (`next`, `trigger_after_scene`, `contact_id` inexistants) en **rouge**
   - les flags jamais posés (`requires_flag`, `resume_after_flag`) en **jaune**
   - les champs manquants ou les valeurs inconnues
   - en cas de succès : `Validator: N scènes vérifiées — aucune erreur.`
5. Utiliser le bouton **Reset** en jeu (ou supprimer `user://savegame.json`) pour repartir du début.
