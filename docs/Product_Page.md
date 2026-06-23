# 💬 Lost Signal — Moteur narratif de messagerie en temps réel (Godot 4.6)

> Créez des jeux narratifs interactifs à travers une interface de messagerie en temps réel — celle que les joueurs reconnaissent depuis Discord, Teams et les apps de chat modernes.
> **Aucune programmation requise. Construisez visuellement avec le Story Editor, ou écrivez du JSON directement.**

---

## 🎮 Qu'est-ce que Lost Signal ?

**Lost Signal** est un moteur narratif pour Godot 4 où toute l'histoire se déroule à travers une **interface de messagerie en temps réel** : conversations simultanées, dialogues à embranchements, événements de fond, messages médias. Aucun code à écrire. Aucun moteur à modifier.

Contrairement aux jeux de messagerie mobiles, il est conçu pour la **narration sur PC** avec la grammaire visuelle de Discord ou Slack — conversations parallèles, personnages secondaires qui écrivent en pleine scène, rythme piloté par les notifications. Des structures narratives qui n'existent pas dans les visual novels traditionnels.

La plupart des outils narratifs sont trop techniques, trop limités, ou trop génériques. Lost Signal est construit spécifiquement pour les histoires de messagerie — non pas comme un habillage sur un système de dialogue, mais comme un système où la communication *est* la mécanique.

---

## ✨ Ce que vous pouvez créer

- **Histoires relationnelles** — amitiés, ruptures, dialogues émotionnels, drames centrés sur les personnages
- **Fiction psychologique et expérimentale** — messages peu fiables, perspectives changeantes, communication fragmentée
- **Thriller et mystère** — enquêtes multi-personnages, récits contradictoires, informations cachées
- **Science-fiction et communications spatiales** — messagerie de survie à distance, narration basée sur des systèmes (style *Lifeline*)
- **Horreur** — messages corrompus, contacts qui disparaissent, conversations instables

Parfait pour les jeux indés narratifs, la fiction interactive, les game jams, et les auteurs ou designers sans background en développement de jeux.

---

## ⚡ Fonctionnalités clés

### 💬 Système de messagerie en temps réel
- Interface de chat style Discord, pensée pour PC
- Plusieurs conversations actives avec changement de contact
- Indicateur de saisie animé (trois points)
- Horodatages et flux de messages naturel
- Support des emojis — collez directement ou utilisez des raccourcis texte (`:)`, `<3`, `^^`…) dans n'importe quel champ de message
- Indicateurs de statut des contacts : en ligne, absent, hors ligne, problème réseau — chacun est un outil narratif, pas seulement un état d'interface. Un contact en *problème réseau* qui coupe sans arrêt raconte une histoire avant même le premier message.
- **Avatars de contacts** — chaque contact peut avoir une photo de profil (PNG, WEBP, JPG). Si aucun avatar n'est défini, l'initiale du nom s'affiche sur un fond coloré. Les avatars apparaissent dans la liste des contacts et dans le bandeau supérieur.

---

### 🧠 Logique narrative complète — sans script
Construisez votre histoire via le Story Editor ou directement en JSON. Le moteur s'occupe du reste.

- **Dialogues à embranchements** — choix qui envoient des messages du joueur et font avancer l'histoire. Un choix peut envoyer un seul message ou une séquence de bulles consécutives — comme on envoie vraiment des textos.
- **Flags** — états booléens pour les embranchements simples
- **Variables** — valeurs numériques pour les systèmes complexes (confiance, stress, scores de relation…)
- **Conditions** — afficher des messages ou des choix selon les flags et variables, avec une logique `and` / `or` / imbriquée complète
- **Effets** — modifier les variables, changer le statut des contacts, renommer des contacts en pleine histoire. Un contact listé comme « Numéro inconnu » peut révéler son nom au moment exact où l'histoire l'exige.
- **Saisie libre + templates** — demandez au joueur de taper une réponse libre, stockez-la comme variable, et injectez-la n'importe où dans l'histoire : `"Merci {prenom_joueur}, c'est rassurant."`

---

### 📬 Conversations pré-existantes
Les contacts secondaires peuvent avoir un historique de conversation et un choix en attente avant même que le joueur reçoive le premier message. Le joueur ouvre l'app et a déjà des messages non lus — comme si son personnage avait une vie avant que l'histoire commence.

Les deux se définissent directement dans `story.json`. Le panneau **Contacts** intégré permet de tout configurer depuis Godot — sans ouvrir de fichier JSON.

---

### 🔀 Conversations en arrière-plan
Les personnages n'attendent pas que le joueur finisse de lire.

Les scènes peuvent se **déclencher automatiquement** après une autre scène, ou **reprendre après qu'un flag narratif** soit posé. Un deuxième personnage peut écrire au joueur en pleine conversation — le badge de notification apparaît, et le joueur décide quand basculer.

Quand il le fait, il entre dans une vraie conversation — choix, réponses, embranchements — exactement comme le contact principal. Les contacts secondaires ne sont pas des notifications. Ce sont des fils narratifs parallèles.

Les scènes en arrière-plan s'exécutent indépendamment, sont sauvegardées automatiquement et persistent entre les sessions.

---

### ⏱ Délais en temps réel
Un personnage peut dire *« Je t'envoie un message dans une heure »* — et le penser vraiment.

Les scènes peuvent être programmées pour se jouer après un délai réel : minutes, heures, ou plus. Le moteur enregistre le moment cible. Si le joueur ferme le jeu et revient plus tard, le message arrive immédiatement au rechargement. S'il reste dans le jeu, il arrive à l'expiration du timer.

C'est la mécanique qui donnait à *Lifeline* l'impression qu'une vraie personne était à l'autre bout. C'est maintenant un seul champ JSON.

```json
{
  "resume_after_delay": "1h"
}
```

---

### 🎵 Musique de scène
Chaque scène peut optionnellement déclarer une piste musicale de fond. Le moteur gère la boucle, le fondu de sortie en douceur, et l'atténuation automatique quand le joueur lit un message audio. Si une scène ne spécifie pas de musique, ce qui joue continue sans interruption.

---

### ✏️ Édition de messages en direct
Les personnages peuvent modifier leurs propres messages après envoi — corriger une faute avec un délai, ou supprimer un message entièrement. Un seul champ permet aussi d'envoyer un message qui arrive déjà corrompu : l'indicateur de saisie apparaît normalement, mais la bulle affiche **✗ Message corrompu** en rouge.

Ces mécaniques ouvrent des possibilités narratives spécifiques : hésitation, regret, remise en question, communication peu fiable, signal dégradé.

---

### 📎 Messages médias
- 📷 Images envoyées comme bulles de chat, cliquables pour afficher en plein écran
- 🔊 Messages audio avec interface de lecture dédiée (barre de progression, durée)
- Les deux sont entièrement intégrés dans le système de sauvegarde

---

### 🌍 Localisation intégrée
- Les fichiers de dialogue sont sélectionnés par langue : `scene.fr.json`, `scene.en.json`
- Le moteur choisit automatiquement le bon fichier selon la langue active
- Retour vers le fichier de base si aucune traduction n'existe encore
- Tout le texte de l'interface traduit via un seul fichier CSV — ajouter une langue prend quelques minutes
- Langue détectée automatiquement depuis le système du joueur au premier lancement
- Les joueurs peuvent changer de langue en jeu à tout moment sans perdre leur progression

---

### 🔍 Validateur d'histoire intégré
À chaque lancement, Lost Signal valide tous vos fichiers JSON et signale les références de scènes manquantes, les flags non définis, les effets malformés et les impasses. Les erreurs s'affichent **directement dans la fenêtre du jeu** — sans console, sans outil externe.

---

### 🛠 Overlay de debug — sautez à n'importe quelle scène instantanément
Appuyez sur **F9** en jeu pour ouvrir l'overlay. Tapez un ID de scène, pré-remplissez les variables `free_input`, définissez des scores, activez ou désactivez des flags — puis sautez directement à la scène. Fermez avec F9.

> Disponible uniquement dans l'éditeur Godot et les exports Debug — automatiquement absent des builds Release.

---

### 🗺 Graphe visuel de l'histoire — construisez sans quitter Godot
Un plugin Godot intégré affiche toute votre histoire sous forme de **graphe interactif** et vous permet d'éditer la structure directement.

À activer une fois dans Paramètres du projet → Plugins.

**Ce que vous voyez :**
- **▶** scène de démarrage · **✎** saisie libre · **⛔ Impasse** (rouge) · **⚠ Isolée** (jaune)
- Flèches codées par couleur : gris = flux normal, **orange** = déclencheur automatique, **violet** = reprise par flag

**Modifier la structure depuis le graphe :**
- **Clic droit sur le fond** → créer une scène, choisir le contact et le fichier cible
- **Tirer d'un port de sortie → nœud** → écrit `next` ou `choices[].next` dans le JSON automatiquement
- **Clic droit sur un nœud** → déconnecter un lien, ou supprimer la scène (toutes les références nettoyées dans tous les fichiers)

**Modifier le contenu depuis le panneau de détail :**
- Messages : texte, pause, `requires_flag`, effets
- Choix : texte du bouton, message du joueur (bulle unique ou séquence), flag, `requires_flag`, scène suivante, effets
- Déclencheurs : `trigger_after_scene`, `resume_after_flag`, `resume_after_delay`
- Saisie libre : nom de variable et placeholder, mutuellement exclusif avec les choix (l'éditeur l'impose)

Tous les dropdowns sont remplis depuis votre projet réel. Les changements sauvegardent à la perte de focus. Les fonctionnalités avancées (conditions `and`/`or` structurées, médias, musique) restent JSON uniquement.

**Panneau Contacts** (bouton dans la barre d'outils) : gérez tout dans `story.json` sans ouvrir le fichier — ajout/renommage/suppression de contacts, avatars, historiques, scène de départ, configuration de l'écran de fin. Renommer un ID de contact propage le changement dans tous les fichiers de dialogue automatiquement.

**Bouton Reformater** : réécrit tous les fichiers de dialogue avec l'ordre de clés canonique sans toucher au contenu.

> Le graphe et les fichiers JSON sont toujours synchronisés — le graphe est une vue en direct de vos fichiers.

---

### ⚙️ Paramètres joueur — inclus par défaut
Langue, volume maître, résolution (480p à 4K) et mode d'affichage (Fenêtré / Sans bords / Plein écran exclusif). Persistés entre les sessions, appliqués automatiquement au lancement.

---

### 🎨 Interface entièrement personnalisable
Système de thème via `theme.json` — couleurs, typographie, taille des bulles, vitesse de frappe. Aucune modification de code pour restyler le jeu entier. Titre du menu principal animé avec effet glitch, configurable via `title_glitch`.

---

### 💾 Système de sauvegarde automatique
L'état de l'histoire est sauvegardé **après chaque choix du joueur et chaque message reçu**. Persistance complète : variables, flags, historiques, noms et statuts des contacts. Fichier de sauvegarde en JSON lisible. Menu principal avec Nouvelle partie / Continuer ; dialog de sortie en jeu.

---

### 🛠 Workflow d'écriture
Un jeu complet ne nécessite que :

```
story.json           ← contacts et scène de départ
dialogues/*.json     ← vos scènes narratives
assets/              ← images, audio et musique (optionnel)
theme.json           ← style visuel (optionnel)
```

Le Story Editor crée et édite tout cela depuis Godot. Les fichiers JSON restent disponibles pour les éditions directes quand c'est nécessaire. Aucun script, aucun nœud, aucune scène à toucher.

---

## 📄 Exemple de scène

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
      "flag": "asked_identity",
      "effects": [{ "op": "add", "var": "confiance", "value": 1 }]
    },
    {
      "text": "Mauvais numéro.",
      "message": "Je crois que vous avez le mauvais numéro.",
      "next": "scene_denial"
    }
  ]
}
```

Deux messages arrivent. Le joueur choisit une réponse. Une variable se met à jour. L'histoire continue — aucun code écrit.

---

## 📦 Ce qui est inclus

- Projet Godot 4.6 complet — ouvrir et lancer immédiatement
- Interface de messagerie complète (indicateurs de saisie, bulles médias, panneau contacts, avatars)
- Story Editor visuel — graphe de scènes avec édition complète et panneau Contacts
- Moteur narratif JSON — conditions, variables, flags, effets, saisie libre, templates
- Système multi-contacts : conversations en arrière-plan, déclencheurs, choix en attente, historiques pré-existants
- Délais en temps réel — scènes qui arrivent minutes ou heures plus tard, persistées entre sessions
- Édition de messages en direct (corriger, supprimer, ou corrompu à l'arrivée)
- Musique de scène avec boucle, fondu et atténuation audio
- Validateur d'histoire intégré avec signalement en jeu
- Overlay de debug (F9) — sautez à n'importe quelle scène, injectez flags et variables
- Sauvegarde automatique après chaque beat narratif ; menu principal (Nouvelle partie / Continuer)
- Menu paramètres joueur (langue, volume, résolution, mode d'affichage)
- Système de localisation (fichiers de dialogue par langue + CSV de traduction de l'interface)
- Système de thème (`theme.json`) avec titre glitch animé (configurable)
- Écran de fin configurable (titre, texte, lien, effet glitch, stats de session) — éditable depuis le Story Editor
- Scénario de démonstration jouable
- Guide d'écriture bilingue (FR + EN) avec référence syntaxique complète

---

## 📋 Avant de commencer

**Le Story Editor gère la plupart des tâches d'écriture sans toucher un fichier.** Personnages, scènes, messages, choix, effets, déclencheurs — tout est éditable depuis l'interface Godot. Pour les fonctionnalités avancées (conditions `and`/`or` structurées, messages médias, musique), vous travaillerez directement en JSON. Une familiarité de base avec la syntaxe JSON suffit pour ces cas ; le validateur intégré attrape la plupart des erreurs.

**Les histoires linéaires sont faciles. Les histoires parallèles demandent de la préparation.** Une histoire à un seul contact avec des choix à embranchements est simple à construire. Les narratives multi-contacts — où les personnages vous écrivent indépendamment et se coupent — nécessitent de réfléchir à la structure avant d'écrire. Les outils sont là ; le travail de design est le vôtre.

**Le guide d'écriture est votre référence, pas un tutoriel.** `docs/authoring.md` couvre chaque champ et chaque fonctionnalité, mais suppose que vous cherchez quelque chose, pas que vous apprenez de zéro. Commencez par le scénario de démonstration et modifiez-le — c'est la façon la plus rapide d'entrer.

---

## ⚠️ Prérequis

- Godot 4.6
- Aucune dépendance externe ni plugin tiers
