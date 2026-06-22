# Lost Signal — Premiers pas

Ce guide vous emmène de l'ouverture du projet à votre premier dialogue qui tourne en jeu. Il ne remplace pas le [Guide auteur](authoring.md) ni la doc du [Story Editor](story_editor.md) — il vous montre le chemin dans l'ordre.

---

## Prérequis

- **Godot 4.6** ou supérieur ([godotengine.org](https://godotengine.org))
- Aucune connaissance en GDScript requise — votre histoire vit entièrement dans des fichiers JSON

---

## Étape 1 — Ouvrir le projet

1. Lancez Godot
2. Dans le gestionnaire de projets, cliquez **Importer** et sélectionnez le dossier du projet
3. Cliquez **Modifier** pour l'ouvrir dans l'éditeur

---

## Étape 2 — Lancer la démo

Appuyez sur **F5** (ou le bouton ▶ en haut à droite).

La démo *Maeve* s'ouvre : parcourez quelques échanges pour voir ce que le moteur peut faire — bulles animées, choix multiples, contact secondaire, image dans une bulle.

---

## Étape 3 — Activer le Story Editor

1. **Projet → Paramètres du projet → Plugins**
2. Activez **Story Editor**
3. Un onglet **Story Editor** apparaît en bas de l'éditeur (à côté de la console)

Cliquez dessus. Vous voyez le graphe de toutes les scènes de la démo. Cliquez sur un nœud pour voir son contenu dans le panneau de droite.

> Prenez quelques minutes pour explorer `acte1.json` depuis le graphe — c'est votre modèle de référence.

---

## Étape 4 — Créer votre contact

Dans le Story Editor, cliquez **Contacts** (barre du haut).

Le panneau Contacts vous permet de configurer `story.json` sans ouvrir le fichier :

1. Supprimez ou renommez le contact existant selon votre histoire
2. Définissez un **ID** (ex: `emma`), un **nom affiché**, un **statut** (`online`, `away`, `offline`, `network_issue`)
3. Cochez **Contact principal** — c'est le personnage avec qui le joueur parle dès le lancement
4. Cliquez **Sauvegarder**

---

## Étape 5 — Créer votre premier fichier de dialogue

1. Dans `dialogues/`, créez un nouveau fichier `.json` (ex: `mon_histoire.json`)
2. Copiez-y la structure minimale suivante :

```json
{
  "scenes": [
    {
      "id": "intro",
      "contact_id": "emma",
      "messages_in": [
        { "text": "Bonjour !", "out": false }
      ],
      "choices": [
        { "text": "Bonjour à toi.", "next": null }
      ]
    }
  ]
}
```

> Remplacez `emma` par l'ID du contact que vous avez créé à l'étape 4.

---

## Étape 6 — Définir la scène de départ

Dans le panneau Contacts, champ **Scène de départ** : entrez `intro` (l'ID de votre première scène).

Ou directement dans `story.json` : `"start_scene": "intro"`.

---

## Étape 7 — Tester

Appuyez sur **F5**.

Si `story.json` ou votre fichier JSON contient une erreur, une fenêtre de validation s'affiche avec le détail. Corrigez et relancez.

Si tout est correct, votre premier dialogue s'affiche.

---

## Étape 8 — Continuer depuis le Story Editor

Une fois le projet lancé, travaillez principalement depuis le Story Editor :

- **Clic droit sur le fond** du graphe → créer une nouvelle scène
- **Glisser un port de sortie vers un port d'entrée** → connecter deux scènes (`next`)
- **Cliquer sur un nœud** → éditer les textes, pauses, choix, effets dans le panneau de droite
- **F9 en jeu** → outil de debug : sauter directement à n'importe quelle scène sans rejouer depuis le début

---

## Pour aller plus loin

- **[Guide auteur](authoring.md)** — tous les champs JSON, conditions, effets, variables, triggers, messages différés
- **[Story Editor](story_editor.md)** — référence complète du plugin
- **`acte1.json`** — la démo est votre meilleur exemple : chaque feature du moteur y est illustrée
