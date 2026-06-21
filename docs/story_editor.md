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
+------------------------------------------------------------------------------+
| [Refresh]  [Reformater]  [Contacts]               11 scenes chargees          |
+------------------------------------------+-----------------------------------+
|                                          |  scene_04                         |
|  [> ch1_intro] --> [scene_01] -------->  |  Contact  [Maeve         v]       |
|                         |                |                                   |
|  [! orpheline]   [X scene_02]            |  Messages -------------------     |
|                                          |                                   |
|  [~ scene_03] - - - trigger - - - ->     |   Bonjour !               [x]     |
|                                          |   +------------------------+      |
|                                          |   | Je t'ecris depuis le  |       |
|                                          |   | train.                |       |
|                                          |   +------------------------+      |
|                                          |   pause    [medium  v]            |
|                                          |   requires [--      v]            |
|                                          |                                   |
|                                          |  Choix  ------------------        |
|                                          |   C'est du spam -> [-- v] [x]     |
|                                          |   Je vous recois-> [-- v] [x]     |
|                                          |   [+ choix]                       |
+------------------------------------------+-----------------------------------+
```

Légende du graphe : `[> id]` = scène de départ · `[! id]` = isolée · `[X id]` = fin de parcours · `[~ id]` = saisie libre · `- - ->` = connexion trigger

- **Bouton Refresh** : relit les fichiers JSON et reconstruit le graphe. À utiliser après chaque modification manuelle des fichiers de dialogue. Les actions d'édition depuis le graphe déclenchent un Refresh automatique.
- **Bouton Reformater** : réécrit tous les fichiers JSON avec l'ordre sémantique des clés, sans modifier aucun contenu. Utile pour harmoniser un fichier édité à la main ou migrer un fichier existant vers le format canonique.
- **Bouton Contacts** : ouvre le [panneau Contacts](#panneau-contacts) — une fenêtre flottante pour éditer `story.json` sans ouvrir le fichier.
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

> **L'éditeur est une aide pratique pour écrire des scènes sans toucher au JSON.** Il couvre la grande majorité des cas d'usage courants. Certaines fonctionnalités avancées (conditions structurées `and`/`or`, médias, corrections différées, musique) restent accessibles uniquement via l'édition directe du fichier JSON — voir la section [Ce que le JSON permet en plus](#ce-que-le-json-permet-en-plus) en fin de document.

Cliquer sur un nœud ouvre le panneau de détail à droite. Tous les champs sont **directement éditables** et sauvegardés **dès que le champ perd le focus** (clic ailleurs ou Tab).

### Niveau scène

| Champ | Interface |
|---|---|
| Contact | Dropdown — tous les contacts du projet |
| `trigger_after_scene` | Dropdown de scènes — se déclenche quand la scène choisie vient d'être jouée |
| `resume_after_flag` | Dropdown de flags — attend en coulisse jusqu'à ce que ce flag soit activé |
| `resume_after_delay` | Texte libre — accepte `300` (secondes), `"5m"`, `"1h"` |
| `free_input` (var) | Bouton **+ Saisie libre** → champ texte pour le nom de variable |
| `free_input_placeholder` | Champ texte — texte indicatif dans le champ de saisie du joueur |

### Par message

| Champ | Interface |
|---|---|
| Texte simple | Zone de texte multi-ligne + × pour supprimer |
| Texte tableau (bulles) | Chaque bulle éditable séparément + **+ bulle** pour en ajouter |
| `requires_flag` | Dropdown de flags — masque le message si le flag n'est pas actif |
| `pause` | Dropdown — `(aucune)`, `short`, `medium`, `long` |
| `effects` | Ligne par effet : dropdown op + dropdown cible + champ valeur + × ; **+ Effet** pour ajouter |

### Par choix

| Champ | Interface |
|---|---|
| Texte du bouton | Zone de texte multi-ligne + × pour supprimer |
| `message` (bulle joueur) | Champ texte — ce qui s'affiche dans la conversation quand le joueur choisit cette option |
| `flag` | Champ texte — flag activé à la sélection |
| `requires_flag` | Dropdown de flags — masque ce choix si le flag n'est pas actif |
| `next` | Dropdown de scènes — scène jouée après ce choix |
| `effects` | Même interface que les effets de messages |

### Effets (`effects`)

Chaque effet se compose de trois champs :

| Op | Cible | Valeur |
|---|---|---|
| `set` | Dropdown de variables | Valeur à affecter |
| `add` | Dropdown de variables | Valeur à ajouter |
| `sub` | Dropdown de variables | Valeur à soustraire |
| `rename` | Dropdown de contacts | Nouveau nom |
| `set_status` | Dropdown de contacts | `online` / `away` / `offline` / `network_issue` |

### Saisie libre vs Choix

`free_input` et `choices` sont **mutuellement exclusifs** : le moteur ignore les choix si une saisie libre est définie. L'éditeur le reflète : **+ Saisie libre** est grisé si des choix existent, et **+ Choix** est grisé si une saisie libre est active.

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

## Panneau Contacts

Cliquer sur le bouton **Contacts** dans la toolbar ouvre une fenêtre flottante pour éditer `story.json` — le fichier qui définit les personnages et la configuration globale. Chaque modification est écrite immédiatement, sans bouton Enregistrer.

### Champs globaux

| Champ | Interface |
|---|---|
| `title` | Texte libre — affiché dans les menus et la barre de titre de la fenêtre |
| `start_scene` | Dropdown de scènes — première scène jouée au lancement d'une nouvelle partie |
| `start_contact` | Dropdown de contacts — contact affiché à l'écran après la scène de départ ; si vide, le contact principal est utilisé |

### Liste des contacts

Chaque contact est affiché sous forme de carte avec tous ses champs éditables :

| Champ | Interface |
|---|---|
| `id` | Texte libre — si modifié, toutes les références `contact_id` dans les fichiers de dialogue sont mises à jour automatiquement |
| `name` | Texte libre — nom affiché dans la liste de contacts et la barre de titre |
| `is_main` | Case à cocher — désigne le contact qui reçoit toutes les scènes sans `contact_id` explicite ; cocher un contact décoche automatiquement tous les autres |
| `avatar` | Texte libre — chemin vers une image (ex : `res://assets/images/maeve.png`), vide pour aucun avatar |
| `status` | Dropdown — `online`, `away`, `offline`, `network_issue` |
| `pending_scene` | Dropdown de scènes — scène mise en attente pour ce contact au démarrage ; le joueur voit un choix en suspens dès l'ouverture de la conversation |
| `history` | Liste de lignes — chaque entrée a une case `→` (envoyé par le joueur), un champ `HH:MM` et un champ texte |

- **+ Contact** — ajoute une nouvelle carte contact
- **×** sur une carte — demande une confirmation avant de supprimer le contact de `story.json`
- **+ msg** sur une carte — ajoute une entrée d'historique
- **×** sur une ligne d'historique — supprime l'entrée immédiatement

> **Renommer un `id`** est sans risque : le panneau scanne tous les fichiers de dialogue chargés et met à jour chaque `contact_id` qui correspondait à l'ancienne valeur. Le champ `start_contact` global est aussi mis à jour si nécessaire.

---

## Ce que le JSON permet en plus

L'éditeur couvre la grande majorité des scénarios. Les fonctionnalités suivantes nécessitent encore une édition directe du fichier JSON :

| Fonctionnalité | Pourquoi JSON uniquement |
|---|---|
| `condition` structurée (`and`/`or`/`flag`/`var`) | Logique booléenne complexe, `requires_flag` couvre la majorité des cas |
| `media` (image dans une bulle) | Affiché en lecture seule dans l'éditeur (📷 nom du fichier) |
| `edit` (corrections différées) | Le texte corrigé (`corrected_text`) est éditable ; le type et le délai restent en lecture seule |
| `time` (délai d'apparition d'un message) | Cas avancé rare |
| `music` | Cas avancé rare |
| `_notes` | Commentaires internes, ignorés par le moteur |
| `resume_after_flag` via code | Géré via le panneau Déclenchement |

Pour toute édition JSON, utiliser le bouton **Reformater** ensuite pour remettre les clés dans l'ordre canonique.

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
| `StoryEditorPanel.tscn` | Scène du panneau (`HSplitContainer[GraphEdit, ScrollContainer]`) + bouton Contacts dans la toolbar |
| `StoryEditorPanel.gd` | Logique principale : parsing, layout BFS, rendu, édition, écriture JSON ; ouvre la fenêtre Contacts |
| `ContactsPanel.gd` | Panneau Contacts — lit et écrit `story.json` ; communique avec le panneau principal via signaux uniquement |
| `scene_parser.gd` | `RefCounted` autonome — lit `story.json` + `dialogues/*.json` avec support locale |

`scene_parser.gd` est volontairement découplé de `dialogue_loader.gd` pour fonctionner dans le contexte éditeur (les autoloads du jeu ne sont pas disponibles dans un plugin `@tool`).

`ContactsPanel.gd` est de même découplé de `StoryEditorPanel.gd` : il reçoit uniquement un callable `get_scene_ids` pour peupler les dropdowns de scènes, et communique via trois signaux (`story_modified`, `rename_contact_requested`, `error_occurred`). Les écritures dans les fichiers de dialogue lors d'un renommage sont déléguées à `StoryEditorPanel`, qui possède déjà `_write_json`.

Les scènes sont écrites via `_write_json()` qui applique `_ordered_scene()` (tri sémantique des clés) puis `_json_expand()` (sérialiseur sur mesure : expansion jusqu'à la profondeur 3, compact au-delà). `story.json` utilise le même sérialiseur dans `ContactsPanel`.
