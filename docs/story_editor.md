# Story Editor — Guide d'utilisation

Le Story Editor est un plugin Godot intégré au projet. Il affiche un **graphe visuel** de toutes les scènes narratives définies dans les fichiers JSON, directement dans l'éditeur Godot — sans modifier le jeu en dehors des actions d'édition explicites.

---

## Activation

1. Dans Godot, ouvrir **Projet → Paramètres du projet → Plugins**
2. Activer **Story Editor**
3. Un onglet **Story Editor** apparaît en bas de l'éditeur (panneau inférieur, à côté de la console)

---

## Interface

```
┌──────────────────────────────────────────────────────────────┐
│  [Refresh]  11 scènes chargées                               │
├─────────────────────────────────────┬────────────────────────┤
│                                     │  scene_04              │
│   [▶ ch1_intro] → [scene_01] → … │  Contact: Maeve         │
│                                     │  ─────────────────     │
│                 Graphe              │  Messages (3)          │
│                                     │  …                     │
│                                     │  Choix (2)             │
│                                     │  …                     │
└─────────────────────────────────────┴────────────────────────┘
```

- **Bouton Refresh** : relit les fichiers JSON et reconstruit le graphe. À utiliser après chaque modification manuelle des fichiers de dialogue. Les actions d'édition depuis le graphe déclenchent un Refresh automatique.
- **Bouton Reformater** : réécrit tous les fichiers JSON avec l'ordre sémantique des clés, sans modifier aucun contenu. Utile pour harmoniser un fichier édité à la main ou migrer un fichier existant vers le format canonique.
- **Graphe** (zone principale) : nœuds déplaçables, zoomables à la molette, navigables en maintenant le clic molette ou en maintenant Espace + glisser.
- **Panneau de détail** (droite) : cliquer sur un nœud affiche son contenu complet. Les textes des messages et des choix sont éditables directement.

---

## Nœuds du graphe

Chaque scène JSON correspond à un nœud. Le nom affiché dans le titre du nœud est l'`id` de la scène.

### Indicateurs visuels

| Indicateur | Signification |
|---|---|
| **▶** avant l'ID | Scène de départ (`start_scene` dans `story.json`) |
| **✎** après l'ID | Scène avec `free_input` (saisie libre du joueur) |
| **⛔ Fin de parcours** (rouge) | La scène n'a aucune sortie — probable oubli d'auteur |
| **⚠ Isolée** (jaune) | Aucune scène ne pointe vers cette scène — elle ne sera jamais atteinte |

### Types de connexions

Les flèches entre les nœuds sont colorées selon leur nature :

| Couleur | Type | Description |
|---|---|---|
| Gris clair | `next` ou `choice` | Enchaînement normal ou choix du joueur |
| Orange | `trigger` | Déclenchement automatique via `trigger_after_scene` |
| Violet | `resume` | Reprise conditionnelle via `resume_after_flag` |

### Ports

Chaque nœud a :
- **Un port d'entrée** (gauche) — reçoit les connexions des scènes précédentes
- **Un port de sortie par connexion** (droite) — une par `next`, une par choix (`choices[]`)

Si une scène a des choix sans destination (`next` absent), **chaque choix dispose de son propre port de sortie** — visible sans fil, prêt à être connecté. Glisser depuis ce port vers une autre scène écrit le `next` dans le bon choix.

Si une scène n'a ni choix ni `next`, un port **→ ?** est affiché : il permet de tirer une connexion vers une autre scène, ce qui ajoutera un `next` de scène.

---

## Panneau de détail

Cliquer sur un nœud affiche dans le panneau de droite :

- **ID** de la scène (titre en bleu clair)
- **Contact** : nom du contact (résolu depuis `story.json`)
- **Messages** : liste de toutes les bulles, avec pauses, conditions et effets
- **Choix** : label, destination (`next`), flag associé et effets
- **Spécial** : champs remarquables (`free_input`, `next`, `trigger_after_scene`, `resume_after_flag`, `music`)

Les effets sont affichés en orange. Les conditions sont affichées en langue système.

---

## Édition depuis le graphe

Toutes les modifications sont **écrites immédiatement dans le fichier JSON** correspondant, puis le graphe est reconstruit automatiquement. Aucune confirmation n'est nécessaire sauf pour la suppression.

### Créer une scène

**Clic droit sur le fond du graphe** (pas sur un nœud) → dialog de création :

- **ID** : identifiant unique de la scène (ex. `scene_10`). Si l'ID existe déjà, la création est refusée.
- **Contact** : liste déroulante de tous les contacts définis dans `story.json`.
- **Fichier** : si plusieurs fichiers JSON existent dans `dialogues/`, un menu supplémentaire permet de choisir dans quel fichier écrire la scène.

La scène est ajoutée en fin de fichier avec un message vide `{ "text": "" }`. Elle apparaît dans le graphe avec l'indicateur **⚠ Isolée** jusqu'à ce qu'une connexion entrante soit créée.

### Connecter deux scènes

**Glisser depuis un port de sortie** (cercle droit d'un nœud) **vers le port d'entrée** (cercle gauche) d'un autre nœud.

- Si le port de sortie correspond à un **choix**, le champ `next` de ce choix est renseigné dans le JSON.
- Si le port de sortie correspond au **`next` de scène** (ou au port **→ ?**), le champ `next` de la scène est renseigné.
- Si le port avait déjà une destination, elle est **remplacée** par la nouvelle.

> On ne peut pas connecter un port `trigger` ou `resume` — ces connexions sont en lecture seule (elles reflètent des champs du JSON mais ne peuvent pas être modifiées depuis le graphe).

### Déconnecter ou supprimer une connexion

**Clic droit sur le nœud source** → le menu contextuel liste toutes les connexions sortantes actives :

```
Supprimer cette scène
─────────────────────
Déconnecter : C'est du spam → scene_02
Déconnecter : Oui, je vous reçois → scene_02
```

Cliquer sur une entrée "Déconnecter" supprime le `next` correspondant dans le JSON (le choix ou le `next` de scène reste, mais sans destination).

### Supprimer une scène

**Clic droit sur le nœud** → **Supprimer cette scène** → dialog de confirmation.

Sur confirmation :
- La scène est retirée du fichier JSON qui la contient.
- Tous les `next` et `choices[].next` qui pointaient vers cette scène sont supprimés dans **tous les fichiers JSON** du projet.
- Le graphe est reconstruit.

> La suppression est immédiate et non annulable depuis le graphe. Git est recommandé pour récupérer une suppression accidentelle.

---

## Édition du contenu dans le panneau de détail

Cliquer sur un nœud ouvre le panneau de détail à droite. Les champs suivants sont **directement éditables** :

- **Texte de chaque message** (`messages_in[i].text`) — zone de texte multi-ligne. Si le message est un tableau (plusieurs bulles), chaque bulle est éditable séparément.
- **Texte corrigé** (`edit[i].corrected_text`) — affiché sous le texte initial avec l'indicateur `✎ corrigé en (+Xs) :`, éditable.
- **Texte de chaque choix** (`choices[i].text`) — la phrase affichée sur le bouton de choix.

Les autres champs (conditions, effets, flags, pauses, `next`) restent en lecture seule dans le panneau. La modification d'un champ est sauvegardée **dès que le champ perd le focus** (clic ailleurs ou Tab). Le graphe n'est pas reconstruit lors d'une édition de texte — seul le fichier JSON est mis à jour.

---

## Format JSON produit par l'éditeur

L'éditeur écrit le JSON en respectant l'ordre sémantique des clés à trois niveaux :

**Scène :**
```
_notes → id → contact_id → trigger_after_scene → resume_after_flag → resume_after_delay → messages_in → free_input → free_input_placeholder → music → next → choices
```

**Message :**
```
text → edit → effects → media → pause → requires_flag → condition
```

**Choix :**
```
text → message → flag → requires_flag → condition → next → effects
```

Les messages et les choix restent compacts (une ligne par élément). L'indentation utilise des tabulations.

Le bouton **Reformater** applique cet ordre à tous les fichiers existants sans modifier aucun contenu — pratique après une édition manuelle ou une migration.

---

## Localisation

Le plugin lit les fichiers de dialogue en appliquant la même logique de locale que le jeu :
- Il préfère `acte1.fr.json` si la langue système est `fr`, sinon `acte1.json`
- La langue lue correspond au réglage de la langue système de l'OS, pas au réglage dans le jeu

---

## Architecture (pour les développeurs)

Le plugin est dans `addons/story_editor/` et ne touche à aucun fichier existant du projet hors des actions d'édition explicites.

| Fichier | Rôle |
|---|---|
| `plugin.cfg` | Manifest Godot (nom, version) |
| `plugin.gd` | `EditorPlugin` — ajoute/retire le panneau |
| `StoryEditorPanel.tscn` | Scène du panneau (`HSplitContainer[GraphEdit, ScrollContainer]`) |
| `StoryEditorPanel.gd` | Logique principale : parsing, layout BFS, rendu, édition, écriture JSON |
| `scene_parser.gd` | `RefCounted` autonome — lit `story.json` + `dialogues/*.json` avec support locale |

`scene_parser.gd` est volontairement découplé de `dialogue_loader.gd` pour fonctionner dans le contexte éditeur (les autoloads du jeu ne sont pas disponibles dans un plugin `@tool`).

Les scènes sont écrites via `_write_json()` qui applique `_ordered_scene()` (tri sémantique des clés) puis `_json_expand()` (sérialiseur sur mesure : expansion jusqu'à la profondeur 3, compact au-delà).
