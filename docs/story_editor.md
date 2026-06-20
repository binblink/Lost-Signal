# Story Editor — Guide d'utilisation

Le Story Editor est un plugin Godot intégré au projet. Il affiche un **graphe visuel** de toutes les scènes narratives définies dans les fichiers JSON, directement dans l'éditeur Godot — sans modifier le jeu.

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

- **Bouton Refresh** : relit les fichiers JSON et reconstruit le graphe. À utiliser après chaque modification des fichiers de dialogue.
- **Graphe** (zone principale) : nœuds déplaçables, zoomables à la molette, navigables en maintenant le clic molette ou en maintenant espace + glisser.
- **Panneau de détail** (droite) : cliquer sur un nœud affiche son contenu complet.

---

## Nœuds du graphe

Chaque scène JSON correspond à un nœud. Le nom affiché dans le titre du nœud est l'`id` de la scène.

### Indicateurs visuels

| Indicateur | Signification |
|---|---|
| **▶** avant l'ID | Scène de départ (`start_scene` dans `story.json`) |
| **✎** après l'ID | Scène avec `free_input` (saisie libre du joueur) |
| **⛔ Fin de parcours** (rouge) | La scène n'a aucune sortie (ni `choices`, ni `next`, ni `free_input`) |
| **⚠ Isolée** (jaune) | Aucune scène ne pointe vers cette scène — elle ne sera jamais atteinte |

### Types de connexions

Les flèches entre les nœuds sont colorées selon leur nature :

| Couleur | Type | Description |
|---|---|---|
| Gris clair | `next` ou `choice` | Enchaînement normal ou choix du joueur |
| Orange | `trigger` | Déclenchement automatique via `trigger_after_scene` |
| Violet | `resume` | Reprise conditionnelle via `resume_after_flag` |

---

## Panneau de détail

Cliquer sur un nœud affiche dans le panneau de droite :

- **ID** de la scène (titre en bleu clair)
- **Contact** : nom du contact (résolu depuis `story.json`)
- **Messages** : liste de toutes les bulles, avec pauses, conditions et effets
- **Choix** : label, destination (`next`), flag associé et effets
- **Spécial** : champs remarquables (`free_input`, `next`, `trigger_after_scene`, `resume_after_flag`, `music`)

Les effets sont affichés en orange. Les conditions (`si flag` / `if flag`) sont en langue système (français si le PC est en français, anglais sinon).

---

## Localisation

Le plugin lit les fichiers de dialogue en appliquant la même logique de locale que le jeu :
- Il préfère `acte1.fr.json` si la langue système est `fr`, sinon `acte1.json`
- La langue lue correspond au réglage de la langue système de l'OS, pas au réglage dans le jeu

---

## Architecture (pour les développeurs)

Le plugin est dans `addons/story_editor/` et ne touche à aucun fichier existant du projet.

| Fichier | Rôle |
|---|---|
| `plugin.cfg` | Manifest Godot (nom, version) |
| `plugin.gd` | `EditorPlugin` — ajoute/retire le panneau |
| `StoryEditorPanel.tscn` | Scène du panneau (Control → VBoxContainer → HSplitContainer[GraphEdit, ScrollContainer]) |
| `StoryEditorPanel.gd` | Logique principale : parsing, layout BFS, rendu du graphe, panneau de détail |
| `scene_parser.gd` | `RefCounted` autonome — lit `story.json` + `dialogues/*.json` avec support locale |

`scene_parser.gd` est volontairement découplé de `dialogue_loader.gd` pour fonctionner dans le contexte éditeur (les autoloads du jeu ne sont pas disponibles dans un plugin).
