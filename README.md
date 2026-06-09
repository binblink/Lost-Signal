# Maeve // Lost Signal — Guide de contenu

Visual novel au format SMS réalisé avec Godot 4.6. Tout le contenu narratif est défini dans des fichiers JSON, sans toucher au code.

---

## Sommaire

1. [Documentation](#documentation)
2. [Organisation des fichiers](#organisation-des-fichiers)
3. [Concepts clés](#concepts-clés)

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

## Concepts clés

Le framework utilise quelques concepts simples pour construire des histoires :

- **Scènes** : blocs de dialogue identifiés par un ID unique
- **Flags** : variables booléennes pour les embranchements simples
- **Variables** : nombres pour les états complexes (stress, confiance, etc.)
- **Conditions** : afficher un message/choix si un flag est actif ou une variable franchit un seuil
- **Effets** : modifier les variables et contacts lors d'un choix
- **Triggers** : enchaîner les scènes automatiquement ou les différer
