# Lost Signal

Un moteur narratif pour Godot 4.6 qui simule une vraie application de messagerie.

Votre histoire vit entièrement dans des fichiers JSON — contacts, scènes, choix multiples, flags, variables, messages différés, images, audio. Aucun code à écrire. Aucun script à apprendre. Ouvrez Godot, appuyez sur F5.

Inclut un éditeur visuel de graphe de scènes directement dans Godot.

---

## Documentation

**Nouveau sur le moteur ?** Commencez par le **[Guide de démarrage](getting_started.md)** — de l'ouverture du projet à votre premier dialogue en jeu, en 8 étapes.

---

**Consultez le [Guide auteur](authoring.md)** pour la documentation complète :
- Structure des fichiers JSON (story.json, dialogues/*.json)
- Messages, choix, conditions, effets
- Flags, variables, templates, déclencheurs
- Tous les champs optionnels et leurs valeurs par défaut
- Outil de debug (F9) pour sauter à n'importe quelle scène sans rejouer depuis le début

**Validation** : Le jeu valide automatiquement `story.json` et les fichiers `dialogues/*.json` au lancement dans Godot. Si des erreurs existent, une fenêtre s'affiche immédiatement.

**Story Editor** : Un plugin Godot intégré affiche un graphe visuel de toutes les scènes narratives, et inclut un **panneau Contacts** pour configurer les personnages et les paramètres globaux sans éditer `story.json` directement — voir le [Story Editor](story_editor.md). À activer via **Projet → Paramètres du projet → Plugins**.

---

## Organisation des fichiers

```
projet/
├── story.json                    ← configuration (contacts, scène de départ)
├── dialogues/
│   ├── acte1.json                ← contenu narratif (langue par défaut)
│   ├── acte1.en.json             ← variante anglaise (optionnel)
│   └── ...autres fichiers.json
├── assets/
│   ├── images/                   ← images pour les bulles (PNG, JPG, WEBP)
│   ├── sounds/                   ← messages audio (OGG, MP3, WAV)
│   └── music/                    ← musiques de fond (OGG, MP3, WAV)
├── translations/
│   └── ui.csv                    ← traductions de l'interface (statuts, boutons…)
└── theme.json                    ← styles visuels (couleurs, polices, etc.)
```

### Pour ajouter du contenu

1. **Créer** un fichier `.json` dans `dialogues/`
2. **Écrire** des scènes avec messages et choix (voir le [Guide auteur](authoring.md) pour la syntaxe)
3. **Placer les assets** :
   - Images dans `assets/images/`
   - Sons dans `assets/sounds/`
   - Musiques dans `assets/music/`
4. **Référencer les assets** dans les fichiers JSON avec un chemin Godot : `res://assets/images/...`, `res://assets/sounds/...` ou `res://assets/music/...`
5. **Lancer** le jeu dans Godot — la validation affiche les erreurs au démarrage

### Localisation des dialogues

Le moteur sélectionne automatiquement le bon fichier de dialogue selon la langue active :

- `acte1.json` → chargé si aucune variante locale n'existe (fallback)
- `acte1.fr.json` → chargé en français
- `acte1.en.json` → chargé en anglais

Le joueur change la langue via le menu **Paramètres** (bouton ⚙ en haut à droite). Si la langue système est supportée, elle est appliquée automatiquement au premier lancement.

---

## Concepts clés

Le framework utilise quelques concepts simples pour construire des histoires :

- **Scènes** : blocs de dialogue identifiés par un ID unique
- **Flags** : variables booléennes pour les embranchements simples
- **Variables** : nombres pour les états complexes (stress, confiance, etc.)
- **Conditions** : afficher un message/choix si un flag est actif ou une variable franchit un seuil — conditions composées (`and` / `or`) supportées
- **Effets** : modifier les variables et contacts lors d'un choix
- **Triggers** : enchaîner les scènes automatiquement ou les différer
- **Contacts secondaires** : des scènes peuvent arriver en arrière-plan dans la conversation d'un autre contact — le joueur reçoit une notification, bascule quand il le souhaite, et peut y avoir une vraie conversation avec choix et réponses

---

## Modifier le visuel

### Ce qui est sans risque

- **`theme.json`** : couleurs, taille de police, vitesse de frappe, et options d'interface. Tous les champs sont optionnels — un fichier invalide ou absent revient simplement au thème par défaut.
  - `title_glitch` (`true` / `false`) : active ou désactive l'animation de glitch sur le titre du menu principal. Défaut : `true`.
- **Repositionner ou redimensionner** des nœuds dans l'éditeur Godot.
- **Modifier les marges, espacements, couleurs** dans l'inspecteur.

### Ce qui fait planter le jeu

**Renommer un nœud** référencé par le code. Les nœuds critiques sont marqués avec une icône de chaîne dans l'éditeur Godot — ce sont ceux déclarés *Access as Unique Name*. Ne pas les renommer.

Changer leur **position dans l'arbre** est sans danger — le code les retrouve par leur nom, pas par leur chemin.
