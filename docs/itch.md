# Lost Signal — Moteur narratif de messagerie pour Godot 4

**Créez des jeux de messagerie. Aucun code requis.**

Lost Signal est un framework Godot 4 complet pour les histoires qui se déroulent par messages — le format que vos joueurs connaissent déjà. Plusieurs contacts simultanés, dialogues à embranchements, délais en temps réel, événements en arrière-plan. Tout s'écrit depuis un éditeur visuel. F5 pour jouer.

![Interface du jeu — conversation avec choix et liste des contacts](screenshots/game_conversation.png)

---

## Ce que vous pouvez créer

Tout ce qui vit dans une fenêtre de chat :

- **Histoires relationnelles** — amitiés, ruptures, drames émotionnels à combustion lente
- **Thrillers et mystères** — enquêtes réparties sur des conversations parallèles, récits contradictoires, informations cachées
- **Horreur** — messages corrompus, contacts qui disparaissent, signal dégradé, narrateurs peu fiables
- **Science-fiction et survie** — messagerie sous pression à distance, délais en temps réel style *Lifeline*
- **Fiction psychologique** — perspectives changeantes, communication fragmentée, messages qui se contredisent

---

## Écrire visuellement, jouer immédiatement

Le Story Editor affiche toute votre histoire sous forme de graphe interactif dans Godot. Cliquez sur un nœud pour éditer ses messages et ses choix. Tirez des ports pour connecter les scènes. Clic droit pour créer ou supprimer.

![Story Editor — graphe de scènes](screenshots/editor_graph.png)

![Story Editor — panneau de détail](screenshots/editor_panel.png)

Aucun JSON requis pour les cas courants. Les fonctionnalités avancées (conditions structurées, images, musique) utilisent le fichier directement — le validateur intégré signale les erreurs au lancement, dans la fenêtre du jeu.

---

## Fonctionnalités clés

**Délais en temps réel** — un personnage peut dire *« Je te recontacte dans une heure »* et le penser vraiment. Un seul champ. Survit aux redémarrages du jeu.

```json
{ "resume_after_delay": "1h" }
```

**Conversations parallèles** — les personnages écrivent en arrière-plan pendant que le joueur lit autre chose. Badge de notification. Le joueur bascule quand il le souhaite. Vraie conversation avec embranchements, pas juste une popup.

**Historiques pré-existants** — les contacts arrivent avec des conversations déjà visibles et des questions sans réponse en attente. Le joueur a une vie avant que l'histoire commence. Entièrement configurable depuis le panneau Contacts, sans éditer de fichier.

**Édition de messages en direct** — les personnages corrigent leurs fautes avec un délai, suppriment des messages, envoient des transmissions corrompues. Hésitation, regret, remise en question, signal défaillant — tout est intégré.

**Statut des contacts comme outil narratif** — en ligne, absent, hors ligne, problème réseau. Un contact dont la connexion coupe sans arrêt raconte une histoire avant même le premier message.

![Message corrompu et statut réseau de Maeve](screenshots/corrupted_message_network_issue.png)

**Messages médias** — images envoyées comme bulles de chat, cliquables pour afficher en plein écran. Messages audio avec barre de lecture dédiée.

![Message média reçu](screenshots/game_media_received.png)

![Message média ouvert en plein écran](screenshots/game_media_opened.png)

**Logique narrative complète** — flags, variables numériques, conditions (`and` / `or` / `not`), effets, saisie libre, templates de variables. Sans script.

**Sauvegarde automatique** — après chaque choix du joueur et chaque message reçu. Fichier de sauvegarde JSON lisible. Menu principal avec Nouvelle partie / Continuer inclus.

---

## La boucle d'écriture

```
1. Définir les contacts   →  nom, avatar, statut. Trente secondes par contact.
2. Créer des scènes       →  clic droit sur le fond du graphe, saisir un ID.
3. Écrire le contenu      →  cliquer sur un nœud, taper dans le panneau de détail.
4. Connecter les scènes   →  tirer un port de sortie vers le port d'entrée d'un autre nœud.
5. Ajouter de la logique  →  flags, conditions, effets — tous accessibles via des menus déroulants.
6. Tester                 →  F5 pour lancer. F9 pour sauter à n'importe quelle scène.
```

Aucun script à aucun moment.

---

## Exemple de scène

```json
{
  "id": "intro",
  "messages_in": [
    { "text": "T'es là ?", "pause": "short" },
    { "text": "On doit parler." }
  ],
  "choices": [
    {
      "text": "C'est qui ?",
      "message": "Vous êtes qui ?",
      "next": "scene_reveal",
      "flag": "asked_identity"
    },
    {
      "text": "Mauvais numéro.",
      "message": "Je crois que vous avez le mauvais numéro.",
      "next": "scene_denial"
    }
  ]
}
```

Deux messages arrivent. Le joueur choisit une réponse. Un flag est posé. L'histoire continue. Aucun code écrit.

---

## Ce qui est inclus

- Projet Godot 4.6+ complet — ouvrir et lancer immédiatement
- Interface de messagerie complète : indicateur de saisie animé, bulles image et audio, avatars, statuts des contacts, panneau multi-contacts avec badges non-lus
- Story Editor visuel : graphe de scènes interactif, édition dans le panneau de détail, panneau Contacts, annuler/rétablir sur chaque action
- Overlay de debug (F9) — sauter à n'importe quelle scène, poser des flags, injecter des variables. Sans rejouer depuis le début.
- Validateur d'histoire intégré — les erreurs s'affichent dans la fenêtre du jeu au lancement
- Scénario de démonstration jouable — chaque fonctionnalité du moteur y est illustrée
- Guide d'écriture bilingue (FR + EN) avec référence syntaxique complète

---

## Avant de commencer

Les histoires linéaires avec des choix à embranchements sont faciles à construire. Les narratives multi-contacts — où les personnages vous écrivent indépendamment — demandent de réfléchir à la structure avant d'écrire.

Les fonctionnalités avancées (conditions `and`/`or` structurées, images dans les bulles, musique de scène) nécessitent une édition JSON directe. Une familiarité de base avec le JSON suffit ; le validateur attrape la plupart des erreurs.

**→ [Guide de démarrage](getting_started.md)** — de l'ouverture du projet à votre premier dialogue, en 8 étapes.

---

**Prérequis :** Godot 4.6 ou supérieur · Gratuit · [godotengine.org](https://godotengine.org) · Aucune dépendance externe
