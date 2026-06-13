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

- `start_scene` : ID de la scène de départ.
- `contacts` : tableau de contacts.
  - `id` : identifiant unique du contact.
  - `name` : texte affiché dans le bandeau.
  - `is_main` : `true` pour le contact principal scriptable.
  - `avatar` : chemin d'icône ou `null`.
  - `status` : `online`, `away`, `offline`, `network_issue`.

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

- `id` : identifiant unique.
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
- `effects` : effet déclenché immédiatement.
- `media` : image ou audio.
- `time` : horodatage optionnel, affiché sous la bulle. Format `"HH:MM"` — ex : `"14:43"`.

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

Les effets sont déclarés dans `effects` et s'appliquent immédiatement.

### Opérations prises en charge

- `set` : fixe une variable.
- `add` : ajoute une valeur.
- `sub` : soustrait une valeur.
- `rename` : change le nom d'un contact.
- `set_status` : change le statut d'un contact. Valeurs acceptées : `online`, `away`, `offline`, `network_issue`.

### Exemples

```json
"effects": [
  { "op": "set", "var": "confiance", "value": 1 },
  { "op": "add", "var": "stress", "value": 2 },
  { "op": "rename", "contact": "maeve", "value": "Maeve" }
]
```

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

- `free_input` : nom de la variable dans laquelle la valeur saisie est stockée.
- `free_input_placeholder` : texte affiché dans le champ de saisie avant que le joueur n'écrive. Optionnel — revient au placeholder par défaut si absent.

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
