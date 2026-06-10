# Maeve // Lost Signal — Guide de contenu

Visual novel au format SMS réalisé avec Godot 4.6. Tout le contenu narratif est défini dans des fichiers JSON, sans toucher au code.

---

## Sommaire

1. [Documentation](#documentation)
2. [Organisation des fichiers](#organisation-des-fichiers)
3. [Concepts clés](#concepts-clés)
4. [Modifier le visuel](#modifier-le-visuel)

---

## Documentation

**Consultez `docs/authoring.md`** pour la documentation complète :
- Structure des fichiers JSON (story.json, dialogues/*.json)
- Messages, choix, conditions, effets
- Flags, variables, templates, déclencheurs
- Tous les champs optionnels et leurs valeurs par défaut

**Validation** : Le jeu valide automatiquement `story.json` et les fichiers `dialogues/*.json` au lancement dans Godot. Si des erreurs existent, une fenêtre s'affiche immédiatement.

---

## Organisation des fichiers

```
projet/
├── story.json                    ← configuration (contacts, scène de départ)
├── dialogues/
│   ├── acte1.json                ← contenu narratif à ajouter/modifier
│   └── ...autres fichiers.json
├── assets/
│   ├── images/                   ← images pour les bulles (PNG, JPG, WEBP)
│   └── sounds/                   ← messages audio (OGG, MP3, WAV)
└── theme.json                    ← styles visuels (couleurs, polices, etc.)
```

### Pour ajouter du contenu

1. **Créer** un fichier `.json` dans `dialogues/`
2. **Écrire** des scènes avec messages et choix (voir `docs/authoring.md` pour la syntaxe)
3. **Placer les assets** :
   - Images dans `assets/images/` 
   - Sons dans `assets/sounds/`
4. **Référencer les assets** dans les fichiers JSON avec un chemin Godot : `res://assets/images/...` ou `res://assets/sounds/...`
5. **Lancer** le jeu dans Godot — la validation affiche les erreurs au démarrage

---

## Modifier le visuel

### Ce qui est sans risque

- **`theme.json`** : couleurs, taille de police, vitesse de frappe. Tous les champs sont optionnels — un fichier invalide ou absent revient simplement au thème par défaut.
- **Repositionner ou redimensionner** des nœuds dans l'éditeur Godot.
- **Modifier les marges, espacements, couleurs** dans l'inspecteur.

### Ce qui fait planter le jeu

**Renommer un nœud** référencé par le code. Les nœuds critiques sont marqués avec une icône de chaîne (🔗) dans l'éditeur Godot — ce sont ceux déclarés *Access as Unique Name*. Ne pas les renommer.

Pour identifier ces nœuds : dans l'éditeur Godot, les nœuds avec l'icône de lien dans le panneau *Scene* sont protégés. Changer leur **nom** casse la référence. Changer leur **position dans l'arbre** est sans danger.

Les nœuds protégés dans chaque scène :

| Scène | Nœuds protégés |
|-------|----------------|
| `Main.tscn` | MessagesList, InputBar, TextInput, ChoicesLayer, ConfirmDialog, Overlay, Reset, PanelButton, MuteButton, PhotoOverlay, PhotoImage, ContactName, StatusDot, StatusText, StatusWarning, ContactPanel, ClockLabel, ContactList, CloseButton, ButtonsContainer |
| `MainMenu.tscn` | Background, GameTitle, BtnContinue, BtnNewGame |
| `ContactPanel.tscn` | ContactList, CloseButton |
| `ContactItem.tscn` | InitialLabel, ContactName, ContactTime, ContactPreview, UnreadBadge |
| `MessageBubbleAudioIn.tscn` | Bubble, PlayButton, Progress, Duration, TimeAndStatus, AudioStreamPlayer |
| `TypingIndicator.tscn` | Dot1, Dot2, Dot3 |

### Ce qui n'existe pas dans ce projet

Déplacer un nœud marqué *unique* n'importe où dans l'arbre de la scène est **toujours sûr** — le code le retrouve par son nom, pas par son chemin.

---

## Concepts clés

Le framework utilise quelques concepts simples pour construire des histoires :

- **Scènes** : blocs de dialogue identifiés par un ID unique
- **Flags** : variables booléennes pour les embranchements simples
- **Variables** : nombres pour les états complexes (stress, confiance, etc.)
- **Conditions** : afficher un message/choix si un flag est actif ou une variable franchit un seuil — conditions composées (`and` / `or`) supportées
- **Effets** : modifier les variables et contacts lors d'un choix
- **Triggers** : enchaîner les scènes automatiquement ou les différer
