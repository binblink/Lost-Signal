# Maeve // Lost Signal — Guide auteur

Ce document explique comment écrire du contenu narratif pour le moteur de messages.
Le principe : un auteur doit uniquement fournir des fichiers JSON bien formés, sans modifier le code.

## 1. Principe général

Le jeu charge automatiquement :
- `story.json` pour la configuration des contacts et de la scène de départ
- tous les fichiers JSON du dossier `dialogues/` pour les scènes

Un fichier de dialogue contient toujours un objet racine avec une clé `scenes`.

## 2. `story.json`

### Structure minimale

```json
{
  "start_scene": "ch1_intro",
  "contacts": [
    { "id": "maeve", "name": "+33 6 23 11 47 05", "is_main": true,  "avatar": null, "status": "network_issue" },
    { "id": "alex",  "name": "Alex",              "is_main": false, "avatar": null, "status": "online" }
  ]
}
```

### Champs autorisés

- `start_scene` : ID de la première scène que le moteur joue au démarrage d'une nouvelle partie. C'est toujours la scène d'ouverture du contact principal.
- `start_contact` : ID du contact dont la conversation est affichée à l'écran au lancement. Par défaut, le jeu s'ouvre sur le contact principal. Utilisez ce champ si vous voulez que le joueur démarre dans la conversation d'un autre contact — le contact principal n'apparaîtra pas du tout dans la liste avant qu'il écrive. Requiert que la première scène du contact principal utilise `resume_after_flag` (pour qu'elle attende un flag avant de démarrer, plutôt que de s'exécuter pendant que le joueur regarde une autre conversation).
- `contacts` : tableau de contacts.
  - `id` : identifiant unique du contact.
  - `name` : texte affiché dans le bandeau. Utilisé comme valeur par défaut si aucune traduction n'est définie pour la langue active.
  - `names` : dictionnaire de noms localisés — voir ci-dessous.
  - `is_main` : `true` pour le contact principal scriptable.
  - `avatar` : chemin vers l'image d'avatar du contact, ou `null`. Voir ci-dessous.
  - `status` : `online`, `away`, `offline`, `network_issue`.
  - `history` : messages pré-existants affichés dès le début d'une nouvelle partie. Voir ci-dessous.
  - `pending_scene` : ID d'une scène dont les choix seront proposés au joueur dès qu'il ouvre la conversation. Voir ci-dessous.

### Noms localisés (`names`)

Le champ `names` permet de donner un nom différent à un contact selon la langue active du jeu, sans toucher au code. Il est entièrement optionnel : si absent, le champ `name` est utilisé dans toutes les langues.

Le cas le plus courant est un contact dont le nom affiché est une description de rôle ou un placeholder qui doit être traduit — avant que l'histoire révèle l'identité du personnage, ou parce que le nom du contact est en réalité un titre :

```json
{
  "id": "inconnu",
  "name": "Numéro inconnu",
  "names": {
    "fr": "Numéro inconnu",
    "en": "Unknown number",
    "de": "Unbekannte Nummer"
  }
}
```

Un prénom propre (`"Maeve"`, `"Alex"`) n'a généralement pas besoin d'être dans `names` — il est identique dans toutes les langues et `name` suffit.

**Comment ça fonctionne :**

- Au démarrage, le moteur lit la langue active et cherche la clé correspondante dans `names`.
- Si une traduction est trouvée, elle remplace `name` pour toute la session.
- Si la langue n'a pas de clé dans `names` (langue non traduite, ou `names` absent), le champ `name` est utilisé comme valeur de secours.
- Si le joueur change de langue en cours de partie, les noms sont mis à jour au rechargement suivant des fichiers de dialogue.

**Le code langue doit correspondre exactement** au suffixe utilisé dans vos fichiers de dialogue. Si vous avez `acte1.en.json`, le code est `"en"`. Si vous avez `acte1.de.json`, le code est `"de"`. Une coquille dans le code (`"EN"` au lieu de `"en"`, `"fr-FR"` au lieu de `"fr"`) fera silencieusement tomber le moteur sur `name` — aucune erreur n'est levée.

> **Nota :** `names` ne gère que le nom affiché avant qu'un renommage narratif ait eu lieu. Si une scène renomme le contact via un effet `rename`, le nouveau nom prend le dessus pour le reste de la session. Pour les renommages narratifs qui doivent eux aussi être traduits, l'effet `rename` accepte un dictionnaire localisé en `value` — voir [Effets](#7-effets) ci-dessous.

---

### Avatars des contacts

Le champ `avatar` accepte un chemin Godot vers une image (PNG, JPG, JPEG ou WEBP), ou `null` pour désactiver l'avatar.

```json
{ "id": "maeve", "avatar": "res://assets/avatars/maeve.png" }
```

**Comportement :**
- Si un avatar est défini et que le fichier existe : l'image s'affiche comme photo de profil dans la liste des contacts et dans le bandeau supérieur.
- Si aucun avatar n'est défini (`null`) ou si le fichier est introuvable : l'initiale du nom du contact s'affiche sur un fond de couleur accentuée.

**Convention recommandée :** placez les images d'avatar dans `assets/avatars/`. Le panneau Contacts du Story Editor propose un bouton `…` pour sélectionner l'image directement depuis l'explorateur de fichiers Godot.

**Format recommandé :** image carrée, PNG ou WEBP. Le moteur recadre automatiquement l'image au format rond — une image carrée garantit un recadrage centré sans perte.

---

### Comment la partie démarre

Deux approches sont possibles :

---

**Option A — Contact principal visible dès le départ (par défaut)**

Aucune configuration nécessaire. Le jeu s'ouvre directement sur la conversation du contact principal. Le joueur le voit immédiatement, avant même qu'un message ait été échangé. Les contacts secondaires peuvent envoyer des messages en arrière-plan pendant l'histoire via `trigger_after_scene`.

À utiliser quand le joueur sait déjà à qui il parle, ou quand c'est le contact principal qui écrit en premier.

---

**Option B — Contacts secondaires d'abord, contact principal déclenché plus tard**

Le joueur démarre dans la conversation d'un contact secondaire. Le contact principal n'apparaît nulle part dans la liste tant qu'une réponse spécifique ne le débloque pas. Le joueur peut avoir de courtes conversations avec un ou plusieurs contacts secondaires — et l'une de ces réponses déclenche le premier message du contact principal.

À utiliser quand le contact principal est un inconnu. Voir une conversation vide avec un contact hors-ligne avant qu'il ait écrit quoi que ce soit serait étrange — mieux vaut le faire apparaître naturellement, comme s'il venait de prendre contact.

Trois éléments doivent fonctionner ensemble :

| Quoi | Où | Pourquoi |
|------|-----|---------|
| `start_contact` | `story.json` | Définit quel contact est affiché au lancement |
| `history` + `pending_scene` | sur chaque contact secondaire dans `story.json` | Messages pré-existants et questions sans réponse |
| `resume_after_flag` | sur la première scène du contact principal | Le fait attendre un flag avant d'apparaître |

---

### Conversations pré-existantes (`history` et `pending_scene`)

Ces deux champs permettent de donner l'impression que le joueur a déjà utilisé la messagerie avant que la partie commence. Dès le lancement d'une nouvelle partie, les contacts concernés affichent un badge de messages non lus — sauf si le dernier message de `history` vient du joueur (`"out": true`), auquel cas il n'y a rien à lire.

#### `history`

Tableau de messages pré-écrits — entrants et sortants — affichés dans l'historique de la conversation dès le démarrage.

```json
{
  "id": "alex",
  "name": "Alex",
  "status": "online",
  "history": [
    { "text": "T'as vu les infos ce matin ?", "time": "09:14", "out": false },
    { "text": "Bah non, j'ai pas encore regardé.", "time": "09:15", "out": true },
    { "text": "Rappelle-moi dès que tu peux.", "time": "09:16", "out": false }
  ]
}
```

Chaque entrée contient :
- `text` : contenu du message. Peut être une chaîne simple ou un dictionnaire localisé `{"fr": "...", "en": "..."}` — voir ci-dessous.
- `time` : horodatage affiché sous la bulle. `"HH:MM"` → affiché tel quel. `"AAAA-MM-JJ HH:MM"` → affiché `"JJ-MM-AAAA HH:MM"` (locale FR) ou `"AAAA-MM-JJ HH:MM"` (autres locales) si la date est antérieure à aujourd'hui.
- `out` : `true` si le message vient du joueur, `false` si il vient du contact.

#### Textes localisés dans `history`

Si votre jeu est traduit en plusieurs langues, `text` peut être un dictionnaire plutôt qu'une chaîne :

```json
"history": [
  { "text": {"fr": "T'as vu les infos ce matin ?", "en": "Did you see the news this morning?"}, "time": "09:14", "out": false },
  { "text": {"fr": "Bah non.",                     "en": "No, not yet."},                       "time": "09:15", "out": true }
]
```

Le moteur sélectionne la valeur correspondant à la langue active. Si la langue active n'a pas de clé dans le dictionnaire, il se replie sur `"fr"`. Le format fonctionne de la même façon que `names` pour les contacts.

#### `pending_scene`

ID d'une scène existante dont les **choix** seront présentés au joueur dès qu'il ouvre la conversation — comme si une question était restée sans réponse.

```json
{
  "id": "alex",
  "name": "Alex",
  "status": "online",
  "history": [
    { "text": "Tu viens ce soir ?", "time": "18:42", "out": false }
  ],
  "pending_scene": "alex_soiree_choix"
}
```

La scène référencée par `pending_scene` doit exister dans les fichiers de dialogue et contenir un champ `choices`. Lorsque le joueur sélectionne un choix, la scène reprend normalement — la suite narrative (`next`, flags, effets) s'applique comme pour n'importe quelle scène.

> Ces deux champs sont ignorés si une sauvegarde existe — le jeu restaure l'état sauvegardé, pas l'état initial.

### Exemple complet : option B — contacts secondaires avant le contact principal

`story.json` :
```json
{
  "title": "Mon Histoire",
  "start_scene": "maeve_intro",
  "start_contact": "alex",
  "contacts": [
    { "id": "maeve", "name": "Maeve", "is_main": true, "status": "offline" },
    {
      "id": "alex", "name": "Alex", "status": "online",
      "history": [
        { "text": "T'as vu les infos ?", "time": "09:14", "out": false },
        { "text": "Rappelle-moi.", "time": "09:16", "out": false }
      ],
      "pending_scene": "alex_pending"
    }
  ]
}
```

`dialogues/scenes.json` :
```json
{
  "scenes": [
    {
      "id": "alex_pending",
      "contact_id": "alex",
      "messages_in": [],
      "choices": [
        {
          "text": "J'arrive.",
          "message": "J'arrive dans 20 minutes.",
          "flag": "maeve_peut_ecrire",
          "next": "alex_fin"
        },
        {
          "text": "Pas ce soir.",
          "message": "Désolé, ce soir c'est compliqué.",
          "flag": "maeve_peut_ecrire",
          "next": "alex_fin"
        }
      ]
    },
    {
      "id": "alex_fin",
      "contact_id": "alex",
      "messages_in": [
        { "text": "Ok, on se voit plus tard alors." }
      ]
    },
    {
      "id": "maeve_intro",
      "contact_id": "maeve",
      "resume_after_flag": "maeve_peut_ecrire",
      "messages_in": [
        { "text": "Allô ?" },
        { "text": "Est-ce que quelqu'un reçoit mes messages ?" }
      ],
      "choices": [ ... ]
    }
  ]
}
```

**Ce qui se passe au lancement :**
- Le jeu s'ouvre sur la conversation d'Alex, ses messages sont déjà visibles et les choix de réponse sont affichés
- Maeve n'existe nulle part à l'écran
- Le joueur répond à Alex → le flag `maeve_peut_ecrire` est activé → les messages de Maeve arrivent (badge non-lu) → le joueur ouvre sa conversation et l'histoire commence

**Plusieurs contacts secondaires :** ajoutez autant de contacts que nécessaire, chacun avec son propre `history` et `pending_scene`. Le joueur peut naviguer librement entre eux. Le flag qui débloque le contact principal peut être posé par n'importe laquelle de ces réponses — c'est l'auteur qui choisit laquelle.

## 3. Fichier de dialogue (`dialogues/*.json`)

Chaque fichier contient :

```json
{
  "scenes": [
    {
      "id": "scene_01",
      "contact_id": "maeve",
      "messages_in": [ ... ],
      "choices": [ ... ]
    }
  ]
}
```

### Champs de scène

- `id` : identifiant unique. Les IDs sont globaux — chaque scène dans tous vos fichiers doit avoir un ID différent. **Convention recommandée** : préfixez avec le fichier ou l'acte pour éviter les collisions sur les grands projets (`acte1_intro`, `acte2_confrontation`). Un ID court (`intro`) suffit pour un projet à fichier unique.
- `contact_id` : identifiant du contact qui parle.
- `_notes` : champ ignoré par le moteur — utilisez-le librement pour annoter vos scènes. Ex : `"_notes": "Scène d'ouverture — révision prévue"`.
- `trigger_after_scene` : ID d'une scène après laquelle celle-ci est jouée automatiquement.
- `resume_after_flag` : nom d'un flag. La scène attente jusqu'à ce que le flag soit activé.
- `messages_in` : liste de messages entrants.
- `choices` : liste de choix présentée au joueur.
- `free_input` : nom d'une variable pour saisir du texte libre.
- `next` : ID de la scène suivante lorsque `free_input` est utilisé.
- `music` : chemin Godot vers un fichier audio à lancer en fond sonore. Optionnel — trois comportements possibles :
  - **Absent** : la musique en cours continue sans interruption.
  - **Chemin** (`"res://assets/music/tension.ogg"`) : lance cette piste en boucle. Si la même piste joue déjà, aucun effet.
  - **`null`** : coupe la musique en cours avec un fondu.
- `end` : `true` pour terminer le jeu après cette scène. Le moteur émet le signal `game_ended` au lieu de chercher une scène suivante. Voir [Écran de fin](#18-écran-de-fin).

La musique baisse automatiquement (ducking) quand le joueur lance un message vocal, puis remonte à la fin de la lecture.

## 4. Messages entrants (`messages_in`)

### Forme courte

Un message simple peut être écrit comme une chaîne :

```json
"Bonjour?"
```

Le moteur convertit automatiquement une chaîne en objet `{ "text": "..." }`.

### Forme détaillée

```json
{
  "text": "Je suis perdue.",
  "pause": "short",
  "requires_flag": "a_appele_aide",
  "condition": { "var": "confiance", "op": "gte", "value": 2 },
  "effects": [ ... ],
  "media": { "type": "image", "path": "res://assets/images/lieu.png" },
  "time": "14:43"
}
```

### Champs recommandés

- `text` : contenu du message. Peut être `null` si un média est envoyé. Accepte aussi un **tableau de chaînes** pour enchaîner plusieurs bulles en une seule déclaration — voir ci-dessous.
- `pause` : `short`, `medium`, `long`.
- `requires_flag` : message affiché uniquement si le flag est actif. Peut être une chaîne (flag unique) ou un tableau de chaînes (tous les flags doivent être actifs).
- `condition` : condition sur une variable numérique.
- `edit` : modification du message après envoi.
- `corrupted` : affiche la bulle comme un message corrompu — **✗ Message corrompu** en rouge. `text` n'est pas nécessaire.
- `effects` : effet déclenché immédiatement.
- `media` : image ou audio.
- `time` : horodatage optionnel, affiché sous la bulle. `"HH:MM"` → affiché tel quel (message du jour). `"AAAA-MM-JJ HH:MM"` → affiché `"JJ-MM-AAAA HH:MM"` (locale FR) ou `"AAAA-MM-JJ HH:MM"` (autres locales) si la date est antérieure à aujourd'hui.

### Modification d'un message après envoi (`edit`)

Un message peut se corriger ou se supprimer automatiquement après un délai, comme si le contact réalisait une faute ou regrettait ce qu'il a écrit.

**Correction :**

```json
{
  "text": "J'ai aucune idée d'ou je suis.",
  "edit": { "type": "correct", "corrected_text": "J'ai aucune idée d'où je suis.", "delay": 2.0 }
}
```

**Suppression :**

```json
{
  "text": "Laissez tomber.",
  "edit": { "type": "delete", "delay": 3.0 }
}
```

- `type` : `correct` pour modifier le texte, `delete` pour remplacer la bulle par *"Message supprimé"*.
- `corrected_text` : nouveau texte affiché (requis si `type` est `correct`).
- `delay` : délai en secondes avant la modification. Optionnel — par défaut `1.5`.

`edit` accepte aussi un **tableau** pour enchaîner plusieurs opérations. Chaque délai est relatif à l'opération précédente :

```json
{
  "text": "Laissez tomber, je vais bien.",
  "edit": [
    { "type": "correct", "corrected_text": "Laissez tomber...", "delay": 2.0 },
    { "type": "delete", "delay": 3.0 }
  ]
}
```

### Message corrompu (`corrupted`)

Un message peut arriver dans un état corrompu. L'indicateur de frappe apparaît normalement, puis la bulle affiche **✗ Message corrompu** en rouge à la place d'un texte.

Utile pour simuler une transmission ratée, un signal brouillé, ou un message intentionnellement incomplet.

```json
{
  "id": "scene_signal_faible",
  "messages_in": [
    { "text": "Je vais essayer d'envoyer la photo—" },
    { "corrupted": true },
    { "text": "Tu as reçu quelque chose ?", "pause": "short" }
  ],
  "choices": [
    { "text": "Non, rien reçu.", "message": "Non, rien.", "next": "scene_retry" },
    { "text": "Oui, mais c'est illisible.", "message": "J'ai reçu quelque chose mais c'est tout corrompu.", "next": "scene_retry" }
  ]
}
```

Comme tout message, `corrupted` accepte `pause`, `requires_flag`, `condition` et `effects` :

```json
{ "corrupted": true, "pause": "short", "requires_flag": "signal_faible" }
```

### Tableau de bulles

Quand `text` est un tableau, le moteur l'expanse automatiquement en plusieurs messages distincts :

```json
{
  "text": ["...", "C'est pas du spam!", "Je suis une vraie personne."],
  "requires_flag": "rep_a",
  "pause": "short"
}
```

Règles d'expansion :
- `requires_flag` et `condition` s'appliquent à **toutes** les bulles
- `pause` et `effects` s'appliquent à la **première** bulle uniquement
- `time` s'applique à la **dernière** bulle uniquement

Pour ajouter une pause sur une bulle spécifique, remplacez la chaîne par un objet `{ "text": "...", "pause": "short" }` :

```json
{
  "text": [
    "Merci de rester avec moi!",
    { "text": "Ca me rassure un peu...", "pause": "short" },
    "Mais je suis vraiment inquiète."
  ],
  "requires_flag": "rep_b1"
}
```

Les chaînes et les objets peuvent être mélangés librement dans le même tableau. Le `requires_flag` du parent s'applique à toutes les bulles quoi qu'il arrive.

## 5. Messages média

### Image

```json
{
  "text": null,
  "media": { "type": "image", "path": "res://assets/images/lieu.png" }
}
```

**Important** : 
- Les fichiers image doivent être placés dans le dossier `assets/images/`
- Dans le JSON, utilisez toujours un chemin Godot commençant par `res://assets/images/`

### Audio

```json
{
  "text": null,
  "media": { "type": "audio", "path": "res://assets/sounds/voicenote.ogg" }
}
```

**Important** :
- Les fichiers audio doivent être placés dans le dossier `assets/sounds/`
- Dans le JSON, utilisez toujours un chemin Godot commençant par `res://assets/sounds/`

## 6. Choix (`choices`)

Un choix est un objet avec au moins `text`.

```json
{
  "text": "Je vais vous aider.",
  "message": "Je vais vous aider.",
  "next": "scene_02",
  "flag": "engagement_a",
  "effects": [ ... ]
}
```

### Notes

- `next` : ID de la scène à jouer après que le joueur a confirmé ce choix. Requis dans la plupart des cas.
- `message` peut être une chaîne ou un tableau de chaînes.
- Si `message` est un tableau, chaque élément correspond à une bulle envoyée successivement par le joueur.
- `flag` active un flag booléen.
- `effects` applique des changements de variables ou des modifications de contact.
- `requires_flag` et `condition` filtrent la visibilité du choix — un choix dont la condition n'est pas remplie n'apparaît pas dans la liste. Les mêmes syntaxes que pour les messages sont supportées.

> **Maximum 4 choix par scène.** Le moteur affiche jusqu'à 4 boutons de choix simultanément. Les entrées au-delà du quatrième sont silencieusement ignorées — aucune erreur n'est levée.

> **Attention** : si toutes les conditions de choix sont fausses en même temps, le joueur se retrouve bloqué sans rien à cliquer. Assurez-vous qu'au moins un choix est toujours visible, soit en le laissant sans condition, soit en couvrant tous les cas possibles.

### Exemple de message en plusieurs bulles

```json
{
  "text": "Mouais… curieux quand même.",
  "message": [
    "Mouais je suis pas convaincu…",
    "Mais je suis curieux de voir où ça va."
  ],
  "next": "scene_02"
}
```

Dans cet exemple, le choix affiche d'abord le label `Mouais… curieux quand même.`, puis le joueur envoie deux messages à la suite.

## 7. Effets

Les effets sont déclarés dans le champ `effects` d'un **message** ou d'un **choix** et s'appliquent immédiatement.

> **Important** : `effects` est toujours imbriqué dans un message ou un choix — jamais au niveau de la scène. Un champ comme `"set_status": "..."` placé directement dans la scène sera silencieusement ignoré par le moteur.

### Opérations prises en charge

- `set` : fixe une variable.
- `add` : ajoute une valeur.
- `sub` : soustrait une valeur.
- `rename` : change le nom d'un contact. `value` accepte une chaîne simple ou un dictionnaire par langue (voir ci-dessous).
- `set_status` : change le statut d'un contact. Valeurs acceptées : `online`, `away`, `offline`, `network_issue`.

### Exemples

```json
"effects": [
  { "op": "set", "var": "confiance", "value": 1 },
  { "op": "add", "var": "stress", "value": 2 },
  { "op": "rename", "contact": "inconnu", "value": "Maeve" }
]
```

### Renommage localisé

Quand le nom révélé doit lui aussi être traduit (ex. un titre comme « Le Gardien »), passez un dictionnaire par langue comme `value` au lieu d'une chaîne :

```json
{ "op": "rename", "contact": "inconnu", "value": { "fr": "Le Gardien", "en": "The Guardian" } }
```

Le moteur résout le dictionnaire selon la langue active au moment où l'effet se déclenche, et recalcule si le joueur change de langue ensuite. Si la langue active n'a pas de clé dans le dictionnaire, la première valeur du dictionnaire est utilisée comme secours.

Une chaîne simple (ex. `"Maeve"`) reste le bon choix pour les prénoms identiques dans toutes les langues — elle prend le dessus sur toute valeur localisée.

## 8. Variables et conditions

### Variables

Les variables sont numériques et stockées dans `vars`.

### Flags multiples (ET)

`requires_flag` accepte une chaîne ou un tableau. Avec un tableau, tous les flags doivent être actifs :

```json
"requires_flag": ["rep_a", "commit_t"]
```

### Condition simple

```json
"condition": { "var": "confiance", "op": "gte", "value": 2 }
```

Opérations supportées : `eq`, `neq`, `gt`, `gte`, `lt`, `lte`.

### Conditions composées

`condition` peut utiliser les opérateurs `and` et `or` avec des nœuds imbriqués.

Chaque nœud peut être :
- `{ "flag": "nom_flag" }` — vérifie un flag
- `{ "var": "...", "op": "...", "value": ... }` — compare une variable
- `{ "and": [...] }` ou `{ "or": [...] }` — sous-expression
- `{ "not": { ... } }` — inverse n'importe quel nœud

**ET entre un flag et une variable :**

```json
"condition": {
  "and": [
    { "flag": "rep_a" },
    { "var": "confiance", "op": "gte", "value": 3 }
  ]
}
```

**OU entre deux flags :**

```json
"condition": {
  "or": [
    { "flag": "react_r" },
    { "flag": "react_u" }
  ]
}
```

**NOT — message affiché uniquement si le flag n'est PAS posé :**

```json
"condition": { "not": { "flag": "a_repondu_maman" } }
```

**Imbrication :**

```json
"condition": {
  "and": [
    { "flag": "commit_t" },
    { "or": [
        { "var": "stress", "op": "lt", "value": 5 },
        { "flag": "react_t" }
      ]
    }
  ]
}
```

## 9. `free_input`

Permet au joueur de taper un texte libre.

```json
{
  "id": "scene_capture",
  "messages_in": ["Comment tu t'appelles?"],
  "free_input": "nom_joueur",
  "free_input_placeholder": "Entrez votre prénom…",
  "next": "scene_reponse"
}
```

- `free_input` : nom de la variable dans laquelle la valeur saisie est stockée. Le nom est libre — `"prenom"`, `"code_secret"`, `"reponse"` sont tous valides.
- `free_input_placeholder` : texte affiché dans le champ de saisie avant que le joueur n'écrive. Optionnel — revient au placeholder par défaut si absent.

La valeur saisie est ensuite injectable dans n'importe quel texte via les templates (voir section suivante) : `"Alors {prenom}, qu'est-ce que tu faisais ce soir-là?"`

## 10. Templates

Les valeurs de variable peuvent être injectées dans les textes avec des accolades :

```json
"text": "Merci {nom_joueur}, je suis rassurée."
```

## 11. Contacts secondaires

Quand une scène a un `contact_id` différent du contact actuellement actif, le moteur la joue en arrière-plan : les messages sont ajoutés à l'historique de ce contact, un badge de notification apparaît dans le panneau, et le joueur choisit quand basculer pour lire la conversation.

C'est le mécanisme principal pour les histoires multi-contacts. Exemple : Maeve est le contact principal, Alex envoie un message pendant que le joueur lit la conversation de Maeve. Quand le joueur bascule vers Alex, les messages s'affichent et les choix en attente apparaissent — une vraie conversation avec embranchements est possible, exactement comme avec le contact principal.

```json
{
  "id": "alex_interrompt",
  "contact_id": "alex",
  "trigger_after_scene": "scene_03",
  "messages_in": ["T'as vu les nouvelles?"]
}
```

Cette scène se déclenche automatiquement après `scene_03` et arrive dans la conversation d'Alex, pas de Maeve.

## 12. Triggers et scènes différées

- `trigger_after_scene` : la scène se joue automatiquement après l'ID donné.
- `resume_after_flag` : la scène est différée jusqu'à ce que le flag soit activé.
- `resume_after_delay` : la scène se joue après un délai en temps réel. Le moteur enregistre l'heure cible dans la sauvegarde — si le jeu est relancé entre-temps, la scène joue immédiatement au chargement si le délai est dépassé, ou reprend le compte à rebours sinon.

Formats acceptés pour `resume_after_delay` :
- Nombre de secondes : `300`
- Chaîne avec suffixe : `"5m"`, `"1h"`, `"30s"`

### Pattern 1 — Délai déclenché par un choix

Le contact annonce qu'il part, le joueur répond, et le prochain message n'arrive qu'une heure plus tard en temps réel.

```json
[
  {
    "id": "maeve_part",
    "contact_id": "maeve",
    "messages_in": [
      "Je dois régler un truc urgent.",
      { "text": "Je te recontacte dans une heure.", "pause": "short" }
    ],
    "choices": [
      {
        "text": "Ok, à tout à l'heure.",
        "message": "Ok, prends le temps qu'il faut.",
        "next": "maeve_retour"
      }
    ]
  },
  {
    "id": "maeve_retour",
    "contact_id": "maeve",
    "resume_after_delay": "1h",
    "messages_in": [
      "Je suis de retour.",
      { "text": "Désolée pour l'attente.", "pause": "short" }
    ],
    "choices": [
      {
        "text": "C'est bon, pas de souci.",
        "message": "C'est bon, pas de souci.",
        "next": "scene_suivante"
      }
    ]
  }
]
```

Quand le joueur sélectionne le choix dans `maeve_part`, le moteur tente de jouer `maeve_retour` — mais celle-ci a un délai d'une heure. Le moteur enregistre l'heure cible et s'arrête. Une heure plus tard (jeu ouvert ou relancé), `maeve_retour` se joue automatiquement.

### Pattern 2 — Délai sur une scène déclenchée automatiquement

Ici aucun choix intermédiaire n'est nécessaire. La scène se déclenche à la fin d'une autre via `trigger_after_scene`, mais n'arrive qu'après un délai.

```json
[
  {
    "id": "scene_03",
    "contact_id": "maeve",
    "messages_in": ["Je t'envoie les infos ce soir."],
    "choices": [
      {
        "text": "Ok, j'attends.",
        "message": "Ok, j'attends.",
        "next": "scene_04"
      }
    ]
  },
  {
    "id": "maeve_soir",
    "contact_id": "maeve",
    "trigger_after_scene": "scene_03",
    "resume_after_delay": "3h",
    "messages_in": [
      "Voilà, j'ai tout envoyé.",
      { "text": "Dis-moi si tu reçois bien.", "pause": "short" }
    ],
    "choices": [...]
  }
]
```

`maeve_soir` se déclenche automatiquement à la fin de `scene_03`, mais son délai de 3 heures est appliqué avant tout — le joueur recevra le message 3 heures plus tard, même s'il a fermé le jeu.

> **Note** : `resume_after_delay` fonctionne avec n'importe quel contact (`contact_id`). Une scène secondaire avec un délai arrivera dans la conversation du bon contact au moment prévu, avec son badge de notification.

### Pattern 3 — Scène déclenchée à l'ouverture d'un contact

Quand le joueur bascule sur un contact, le moteur pose automatiquement le flag `opened_{contact_id}`. En combinant cela avec `resume_after_flag`, tu peux déclencher une scène au moment où le joueur ouvre cette conversation.

La différence clé avec une scène de fond : comme le joueur est déjà sur la conversation quand le flag se déclenche, la scène joue **en direct** (avec indicateur de saisie, animations, et effets `edit`) plutôt que d'être silencieusement ajoutée à l'historique.

```json
[
  {
    "id": "scene_maman_01",
    "contact_id": "Maman",
    "trigger_after_scene": "une_scene_anterieure",
    "messages_in": [
      { "text": "Tu es bien arrivée?" }
    ],
    "choices": [...]
  },
  {
    "id": "scene_maman_02",
    "contact_id": "Maman",
    "trigger_after_scene": "scene_maman_01",
    "resume_after_flag": "opened_Maman",
    "messages_in": [
      { "text": "...", "pause": "short", "edit": { "type": "delete", "delay": 2 } }
    ]
  }
]
```

`scene_maman_02` se met en attente après `scene_maman_01`. Quand le joueur ouvre la conversation de Maman, le flag `opened_Maman` est posé, et `scene_maman_02` se joue immédiatement — animée, en temps réel, avec l'effet de suppression au bout de 2 secondes.

> **Note** : le flag `opened_{contact_id}` est posé à chaque fois que le joueur bascule sur ce contact. Si la scène a déjà joué, elle ne rejoue pas — `resume_after_flag` est consommé à la première utilisation.

## 13. Validation

Le jeu valide automatiquement `story.json` et tous les fichiers `dialogues/*.json` au lancement dans Godot.

Si des erreurs ou des avertissements sont trouvés, une fenêtre apparaît immédiatement dans le jeu avec le détail du problème. Les erreurs sont aussi loguées dans la console Godot.

L'auteur n'a rien à installer : il suffit de lancer le projet dans Godot et de lire le rapport qui s'affiche.

## 14. Localisation des dialogues

Le moteur supporte plusieurs langues via des fichiers de dialogue distincts.

### Convention de nommage

```
dialogues/
├── acte1.json        ← fichier de base (chargé si aucune variante n'existe)
├── acte1.fr.json     ← variante française
└── acte1.en.json     ← variante anglaise
```

Au lancement, le moteur sélectionne automatiquement le fichier correspondant à la langue active. Si aucune variante n'existe pour la langue courante, il revient sur le fichier de base (sans suffixe).

### Scène de départ par locale

Si votre histoire a un point d'entrée différent selon la langue (prologue, structure de scènes distincte…), vous pouvez déclarer un `start_scene` directement dans le fichier de dialogue localisé — il prend la priorité sur celui de `story.json` :

```json
{
  "start_scene": "ch1_intro",
  "scenes": [
    { "id": "ch1_intro", ... },
    ...
  ]
}
```

Si le fichier n'a pas de `start_scene`, la valeur définie dans `story.json` est utilisée.

### Changement de langue en cours de partie

Quand le joueur change de langue depuis les Paramètres, le jeu recharge les fichiers de dialogue et reprend depuis la sauvegarde. Ce qui est préservé :

- L'historique des messages déjà joués
- Les flags, variables, et statuts des contacts
- Les noms de contacts renommés via `rename` — si la valeur est un dictionnaire localisé, le nom s'affiche dans la nouvelle langue automatiquement

Si une scène de la sauvegarde n'existe pas dans la locale cible (deux jeux de scènes entièrement distincts par langue), le moteur restaure l'état sans relancer la scène — le joueur retrouve ses conversations telles qu'elles étaient.

### Ajouter une langue

1. Dupliquer le fichier de base : `acte1.json` → `acte1.es.json`
2. Traduire tous les champs `text`, `message` et `choices[].text`
3. Conserver les IDs (`id`, `next`, `flag`, `requires_flag`) identiques — ce sont des clés internes, pas du texte affiché

### Traductions de l'interface

Les textes de l'interface (statuts, boutons, messages de validation) sont gérés séparément dans `translations/ui.csv`. Pour ajouter une langue, ajouter une colonne avec le code ISO de la langue (`es`, `de`, etc.) et renseigner toutes les clés.

```csv
keys,en,fr,es
STATUS_ONLINE,online,en ligne,en línea
BTN_CANCEL,Cancel,Annuler,Cancelar
```

La langue système est détectée automatiquement au premier lancement. Le joueur peut la modifier via le menu **Paramètres** (⚙).

## 15. Outil de debug — Jump to Scene

Un overlay de debug est intégré au moteur pour faciliter les tests sans avoir à rejouer le début à chaque fois.

### Accès

Appuyez sur **F9** pendant le jeu pour ouvrir ou fermer l'overlay.

> **L'overlay n'est disponible que dans l'éditeur Godot et les exports Debug.** Il est automatiquement absent des exports Release — aucune manipulation requise avant de publier le jeu.

### Utilisation

L'overlay contient trois zones :

- **Scene ID** — entrez l'identifiant exact d'une scène (ex : `scene_05`). Si l'ID est invalide, le champ vire au rouge brièvement.
- **Flags à activer** — liste de tous les flags connus du projet. Cochez ceux dont la scène a besoin avant de sauter.
- **Vars** — variables à injecter, une par ligne au format `clé=valeur`. Les entiers et flottants sont reconnus automatiquement ; les autres valeurs sont stockées comme chaînes (utile pour pré-remplir une variable `free_input` avant de sauter dans la scène suivante) :

```
confiance=3
stress=1
nom_joueur=Alice
```

Cliquez sur **Jump** pour appliquer l'état et lancer la scène. La conversation en cours est remplacée immédiatement.

**Fermer** (ou F9) referme l'overlay sans rien changer à l'état du jeu.

## 16. Emoji

Les emoji fonctionnent dans tous les champs textuels : `text`, `message`, `free_input_placeholder`.

### Copier-coller direct

Collez le caractère emoji directement dans le JSON — aucun encodage particulier n'est nécessaire.

```json
{ "text": "Ça m'a fait rire 😂" }
```

### Raccourcis texte

Si vous ne pouvez pas copier-coller un emoji, utilisez les raccourcis texte habituels — le moteur les convertit automatiquement à l'affichage.

| Raccourci | Emoji | | Raccourci | Emoji |
|-----------|-------|-|-----------|-------|
| `:)`  | 😊 | | `:-)`  | 😊 |
| `:D`  | 😄 | | `:-D`  | 😄 |
| `:(`  | 😢 | | `:-(`  | 😢 |
| `;)`  | 😉 | | `;-)`  | 😉 |
| `:P`  | 😛 | | `:-P`  | 😛 |
| `:O`  | 😮 | | `:-O`  | 😮 |
| `:*`  | 😘 | | `:-*`  | 😘 |
| `:/`  | 😕 | | `:-/`  | 😕 |
| `:\|` | 😐 | | `:-\|` | 😐 |
| `:'(` | 😭 | | `:')`  | 🥲 |
| `>:(` | 😠 | | `>:)`  | 😈 |
| `O:)` | 😇 | | `B)`   | 😎 |
| `=D`  | 😁 | | `XD`   | 😆 |
| `^^`  | 😄 | | `^_^`  | 😊 |
| `T_T` | 😭 | | `-_-`  | 😑 |
| `>_<` | 😣 | | `o.O`  | 🤨 |
| `<3`  | ❤️  | | `</3`  | 💔 |

## 17. Menu principal

Le menu principal est entièrement configuré depuis `story.json` et `theme.json` — aucune modification de code n'est nécessaire.

### Titre

Le champ `title` dans `story.json` définit le texte affiché en grand dans le menu principal.

```json
{
  "title": "Mon Histoire",
  "start_scene": "intro",
  "contacts": [ ... ]
}
```

Si le champ est absent, le titre reste vide.

### Effet de glitch

Par défaut, le titre s'affiche avec une animation de glitch : les caractères s'affichent comme du bruit au chargement, puis se décodent progressivement, avec des corruptions aléatoires en idle.

Pour désactiver cet effet, ajoutez `"title_glitch": false` dans `theme.json` :

```json
{
  "title_glitch": false
}
```

| Valeur | Comportement |
|--------|-------------|
| `true` (défaut) | Animation de décodage au chargement + glitches aléatoires en idle |
| `false` | Titre statique, affiché immédiatement |

---

## 18. Écran de fin

Lorsqu'une scène contient `"end": true`, le moteur affiche un écran de fin au lieu de chercher une scène suivante.

### Marquer une scène comme fin

```json
{
  "id": "scene_finale",
  "messages_in": [
    { "text": "À bientôt." }
  ],
  "end": true
}
```

`"end": true` est compatible avec `messages_in` et `choices` — la scène se joue normalement, puis l'écran de fin apparaît. Il est incompatible avec `next` et `trigger_after_scene` (ignorés si `end` est présent).

### Configurer l'écran (`end_screen` dans `story.json`)

```json
{
  "title": "...",
  "start_scene": "...",
  "contacts": [ ... ],
  "end_screen": {
    "title": "CONNECTION TERMINATED",
    "text": "La suite arrive.",
    "link_url": "https://itch.io/votre-jeu",
    "link_label": "En savoir plus",
    "glitch": true,
    "show_stats": true
  }
}
```

Tous les champs sont optionnels. Si `end_screen` est absent de `story.json`, un écran minimal s'affiche avec seulement les boutons Nouvelle partie et Quitter.

| Champ | Type | Défaut | Description |
|---|---|---|---|
| `title` | string ou dict localisé | `"CONNECTION TERMINATED"` | Texte principal affiché en grand, police monospace. Accepte `{"fr": "...", "en": "..."}` pour un texte localisé. |
| `text` | string ou dict localisé | *(absent)* | Texte secondaire sous le titre — accroche, annonce de suite, etc. Accepte `{"fr": "...", "en": "..."}` pour un texte localisé. |
| `link_url` | string | *(absent)* | URL ouverte au clic. Si absent, aucun lien n'est affiché |
| `link_label` | string | *(l'URL brute)* | Texte affiché sur le lien. Si absent, l'URL s'affiche directement |
| `glitch` | bool | `false` | Active l'effet glitch : scramble de texte sur le titre + scanlines animées + flicker |
| `show_stats` | bool | `false` | Affiche le nombre de messages échangés pendant la session |

### Effet glitch

Quand `"glitch": true`, trois effets se combinent :

- **Scramble de texte** — les caractères du titre sont périodiquement remplacés par du bruit, puis se restituent (même algorithme que le titre du menu principal)
- **Scanlines animées** — des bandes horizontales lumineuses dérivent lentement sur l'écran
- **Flicker** — l'écran clignote aléatoirement à faible intensité

### Édition via le Story Editor

Le panneau **Contacts** du Story Editor expose une section **Écran de fin** avec tous les champs configurables directement — aucun fichier JSON à ouvrir.
