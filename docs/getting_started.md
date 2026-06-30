# Lost Signal — Premiers pas

Ce guide vous emmène de l'ouverture du projet à votre première histoire Lost Signal jouable. Il ne remplace pas le [Guide auteur](authoring.md) ni la doc du [Story Editor](story_editor.md) — il vous montre le chemin dans l'ordre.

---

## Comment une histoire Lost Signal est organisée

```
Votre histoire
 └── Fichiers de dialogue  (fichiers .json dans le dossier dialogues/)
      └── Scènes            (= nœuds dans le Story Editor)
           └── Messages, choix, conditions, effets
```

Une scène dans le fichier JSON = un nœud dans le graphe. Les deux termes sont interchangeables dans ce guide.

---

## Prérequis

- **Godot 4.6** ou supérieur ([godotengine.org](https://godotengine.org))
- Aucune connaissance en GDScript requise — votre histoire se construit depuis le Story Editor et est stockée dans des fichiers JSON

---

## Étape 1 — Ouvrir le projet

1. Lancez Godot
2. Dans le gestionnaire de projets, cliquez **Importer** et sélectionnez le dossier du projet
3. Cliquez **Modifier** pour l'ouvrir dans l'éditeur

---

## Étape 2 — Lancer la démo

Appuyez sur **F5** (ou le bouton ▶ en haut à droite).

La démo *Maeve* s'ouvre : parcourez quelques échanges pour voir ce que le moteur peut faire — bulles animées, choix multiples, contact secondaire, image dans une bulle.

![Interface du jeu — conversation et liste des contacts](screenshots/game_conversation.png)

---

## Étape 3 — Activer le Story Editor

1. **Projet → Paramètres du projet → Plugins**
2. Activez **Story Editor**
3. Un onglet **Story Editor** apparaît en bas de l'éditeur (à côté de la console)

Cliquez dessus. Vous voyez le graphe des scènes chargées par le projet (dont celles de la démo). Cliquez sur un nœud pour voir son contenu dans le panneau de droite.

> Prenez quelques minutes pour explorer `acte1.json` depuis le graphe — c'est votre modèle de référence.

![Story Editor — graphe des scènes](screenshots/editor_graph.png)

---

## Étape 4 — Créer votre contact

Dans le Story Editor, cliquez **Contacts** (barre du haut).

Le panneau Contacts vous permet de configurer `story.json` sans ouvrir le fichier :

1. Si vous voulez partir de zéro, supprimez les contacts de la démo. Si vous voulez garder la démo comme référence, cliquez **+ Contact** pour ajouter le vôtre sans toucher aux contacts existants.
2. Définissez un **ID** (ex: `emma`), un **nom affiché**, un **statut** (`online`, `away`, `offline`, `network_issue`)
3. Cochez **is_main** — désigne le personnage avec qui le joueur parle dès le lancement ; cocher un contact décoche automatiquement tous les autres

Les modifications sont sauvegardées immédiatement — il n'y a pas de bouton Enregistrer.

---

## Étape 5 — Préparer votre première histoire

1. Sur votre ordinateur, ouvrez le dossier du projet et allez dans `dialogues/`.
2. Dupliquez `acte1.json` et renommez la copie (ex: `mon_histoire.json`).
3. Ouvrez `mon_histoire.json` avec un éditeur de texte (Bloc-notes sur Windows, TextEdit sur Mac) et remplacez tout le contenu par — pour cette première création, nous préparons simplement un fichier vide ; tout le contenu sera créé depuis le Story Editor :

```json
{ "scenes": [] }
```

4. Sauvegardez le fichier, puis cliquez **Refresh** dans la barre d'outils du Story Editor.
5. **Clic droit sur le fond du graphe** → renseignez l'ID (`intro`), sélectionnez votre contact, choisissez `mon_histoire.json` comme fichier cible. Un nœud apparaît dans le graphe.
6. Cliquez sur le nœud et écrivez votre premier message et votre premier choix dans le panneau de détail à droite.

> Le graphe affiche aussi les scènes de la démo `acte1.json` — c'est normal. Utilisez le filtre contact dans la barre d'outils pour n'afficher que les scènes de votre contact.

---

## Étape 6 — Définir la scène et le contact de départ

Dans le panneau **Paramètres** (bouton **Paramètres** dans la barre d'outils du Story Editor) :

- Sélectionnez `intro` dans le menu déroulant **Scène de départ**
- Sélectionnez votre contact (ex: `emma`) dans le menu déroulant **Contact de départ**

Les deux sont nécessaires — sans ça, appuyer sur F5 lancera la démo Maeve plutôt que votre histoire.

---

## Étape 7 — Tester

Appuyez sur **F5**.

Si `story.json` ou votre fichier JSON contient une erreur, une fenêtre de validation s'affiche avec le détail. Corrigez et relancez.

Si tout est correct, votre premier dialogue s'affiche. Félicitations — vous venez de créer votre première scène Lost Signal.

> **Vous avez déjà lancé le jeu avant ?** La sauvegarde précédente peut masquer votre nouveau contenu. Depuis le menu principal, cliquez **Nouvelle partie** pour repartir de zéro.

---

## Étape 8 — Construire votre histoire

Une fois le projet lancé, travaillez principalement depuis le Story Editor :

- **Clic droit sur le fond** du graphe → créer une nouvelle scène
- **Glisser un port de sortie vers un port d'entrée** → connecter deux scènes (`next`)
- **Cliquer sur un nœud** → éditer les textes, pauses, choix, effets dans le panneau de droite
- **F9 en jeu** → outil de debug : sauter directement à n'importe quelle scène sans rejouer depuis le début

![Story Editor — panneau de détail](screenshots/editor_panel.png)

---

## Pour aller plus loin

- **[Guide auteur](authoring.md)** — tous les champs JSON, conditions, effets, variables, triggers, messages différés
- **[Story Editor](story_editor.md)** — référence complète du plugin
- **`acte1.json`** — la démo est votre meilleure référence : presque toutes les features du moteur y sont illustrées
