# Maeve // Lost Signal — Authoring Guide

This document explains how to write narrative content for the messaging engine.
The idea: an author only needs to provide well-formed JSON files — no code changes required.

## 1. Overview

The game automatically loads:
- `story.json` for contact configuration and the starting scene
- all JSON files in the `dialogues/` folder for scenes

A dialogue file always contains a root object with a `scenes` key.

## 2. `story.json`

### Minimal Structure

```json
{
  "start_scene": "ch1_intro",
  "contacts": [
    { "id": "maeve", "name": "+33 6 23 11 47 05", "is_main": true,  "avatar": null, "status": "network_issue" },
    { "id": "alex",  "name": "Alex",              "is_main": false, "avatar": null, "status": "online" }
  ]
}
```

### Allowed Fields

- `start_scene`: ID of the first scene the engine plays when a new game starts. This is always the main contact's opening scene.
- `start_contact`: ID of the contact whose conversation is shown on screen at launch. Defaults to the main contact. Set this to a secondary contact if you want the player to start in someone else's chat — the main contact won't appear in the list at all until they write. Requires the main contact's first scene to use `resume_after_flag` (so it waits for a flag before starting, rather than trying to play while the player is looking at another conversation).
- `contacts`: array of contacts.
  - `id`: unique identifier for the contact.
  - `name`: text displayed in the top bar. Used as the fallback if no translation is defined for the active language.
  - `names`: dictionary of localized names — see below.
  - `is_main`: `true` for the main scriptable contact.
  - `avatar`: path to the contact's avatar image, or `null`. See below.
  - `status`: `online`, `away`, `offline`, `network_issue`.
  - `history`: pre-existing messages shown at the start of a new game. See below.
  - `pending_scene`: ID of a scene whose choices will be presented to the player as soon as they open the conversation. See below.

### Localized names (`names`)

The `names` field lets you display a different name for a contact depending on the active game language, with no code changes required. It is entirely optional: if absent, `name` is used for all languages.

The most common use case is a contact whose displayed name is a role description or placeholder that needs to be translated — before the story reveals the character's real identity, or because the contact's name is actually a title:

```json
{
  "id": "unknown",
  "name": "Unknown number",
  "names": {
    "fr": "Numéro inconnu",
    "en": "Unknown number",
    "de": "Unbekannte Nummer"
  }
}
```

A proper first name (`"Maeve"`, `"Alex"`) generally doesn't need to be in `names` — it is the same across languages and `name` alone is sufficient.

**How it works:**

- At startup, the engine reads the active language and looks for the matching key in `names`.
- If a translation is found, it replaces `name` for the entire session.
- If the active language has no key in `names` (untranslated language, or `names` absent), `name` is used as the fallback.
- If the player changes language mid-game, names are updated the next time dialogue files are reloaded.

**The language code must match exactly** the suffix used in your dialogue files. If you have `act1.en.json`, the code is `"en"`. If you have `act1.de.json`, the code is `"de"`. A typo in the code (`"EN"` instead of `"en"`, `"fr-FR"` instead of `"fr"`) will silently fall back to `name` — no error is raised.

> **Note:** `names` only controls the name shown in the top bar and contact list before any narrative rename occurs. If a scene renames the contact via a `rename` effect, the renamed name takes over for the rest of the session. For narrative renames that also need to be translated, the `rename` effect supports a localized dict as its `value` — see [Effects](#7-effects) below.

---

### Contact avatars

The `avatar` field accepts a Godot resource path to an image (PNG, JPG, JPEG, or WEBP), or `null` to disable the avatar.

```json
{ "id": "maeve", "avatar": "res://assets/avatars/maeve.png" }
```

**Behavior:**
- If an avatar is set and the file exists: the image is shown as the contact's profile picture in both the contact list and the top bar.
- If no avatar is set (`null`) or the file is missing: the contact's name initial is shown on an accent-colored background.

**Recommended convention:** place avatar images in `assets/avatars/`. The Story Editor's Contacts panel includes a `…` button to browse and select the image directly from Godot's file picker.

**Recommended format:** square image, PNG or WEBP. The engine automatically clips the image to a circle — a square image ensures centered cropping without loss.

---

### How the game opens

There are two ways to set up the game's opening:

---

**Option A — Main contact visible from the start (default)**

No setup needed. The game opens directly on the main contact's conversation. The player sees the main contact immediately, even before any message is exchanged. Secondary contacts can send messages in the background during the story using `trigger_after_scene`.

Use this when the player already knows who they're talking to, or when the main contact writes first.

---

**Option B — Secondary contacts first, main contact triggered later**

The player starts in a secondary contact's conversation. The main contact doesn't appear in the list at all until a specific reply unlocks them. The player can have short conversations with one or more secondary contacts — and one of those replies triggers the main contact's first message.

Use this when the main contact is a stranger. Seeing an empty conversation with an offline contact before they've written anything would feel odd — it's better to have them appear naturally, as if they just reached out.

This requires three things working together:

| What | Where | Why |
|------|-------|-----|
| `start_contact` | `story.json` | Sets which contact is shown on launch |
| `history` + `pending_scene` | on each secondary contact in `story.json` | Pre-existing messages and unanswered questions |
| `resume_after_flag` | on the main contact's first scene | Makes them wait for a specific reply before appearing |

---

### Pre-existing conversations (`history` and `pending_scene`)

These two fields give the impression that the player has already been using the messaging app before the story begins. At the start of a new game, affected contacts immediately show an unread badge.

#### `history`

An array of pre-written messages — both incoming and outgoing — displayed in the conversation history from the very first moment.

```json
{
  "id": "alex",
  "name": "Alex",
  "status": "online",
  "history": [
    { "text": "Did you see the news this morning?", "time": "09:14", "out": false },
    { "text": "No, haven't checked yet.",           "time": "09:15", "out": true },
    { "text": "Call me when you can.",              "time": "09:16", "out": false }
  ]
}
```

Each entry contains:
- `text`: message content.
- `time`: timestamp displayed below the bubble. `"HH:MM"` → shown as-is. `"YYYY-MM-DD HH:MM"` → shown as `"DD-MM-YYYY HH:MM"` (FR locale) or `"YYYY-MM-DD HH:MM"` (other locales) if the date is before today.
- `out`: `true` if the message comes from the player, `false` if it comes from the contact.

#### `pending_scene`

ID of an existing scene whose **choices** are presented to the player as soon as they open the conversation — as if a question had been left unanswered.

```json
{
  "id": "alex",
  "name": "Alex",
  "status": "online",
  "history": [
    { "text": "You coming tonight?", "time": "18:42", "out": false }
  ],
  "pending_scene": "alex_party_choice"
}
```

The scene referenced by `pending_scene` must exist in the dialogue files and contain a `choices` field. When the player selects a choice, the scene resumes normally — the narrative continuation (`next`, flags, effects) applies exactly as for any other scene.

> Both fields are ignored if a save file exists — the game restores the saved state, not the initial state.

### Full example: Option B — secondary contacts before the main contact

`story.json`:
```json
{
  "title": "My Story",
  "start_scene": "maeve_intro",
  "start_contact": "alex",
  "contacts": [
    { "id": "maeve", "name": "Maeve", "is_main": true, "status": "offline" },
    {
      "id": "alex", "name": "Alex", "status": "online",
      "history": [
        { "text": "Did you see the news?", "time": "09:14", "out": false },
        { "text": "Call me back.",         "time": "09:16", "out": false }
      ],
      "pending_scene": "alex_pending"
    }
  ]
}
```

`dialogues/scenes.json`:
```json
{
  "scenes": [
    {
      "id": "alex_pending",
      "contact_id": "alex",
      "messages_in": [],
      "choices": [
        {
          "text": "On my way.",
          "message": "I'll be there in 20 minutes.",
          "flag": "maeve_can_write",
          "next": "alex_end"
        },
        {
          "text": "Not tonight.",
          "message": "Sorry, tonight's complicated.",
          "flag": "maeve_can_write",
          "next": "alex_end"
        }
      ]
    },
    {
      "id": "alex_end",
      "contact_id": "alex",
      "messages_in": [
        { "text": "Ok, talk later then." }
      ]
    },
    {
      "id": "maeve_intro",
      "contact_id": "maeve",
      "resume_after_flag": "maeve_can_write",
      "messages_in": [
        { "text": "Hello?" },
        { "text": "Is anyone receiving my messages?" }
      ],
      "choices": [ ... ]
    }
  ]
}
```

**What happens at launch:**
- The game opens on Alex's conversation, with his messages already visible and reply choices ready
- Maeve doesn't exist anywhere on screen yet
- The player replies to Alex → flag `maeve_can_write` is set → Maeve's messages arrive (unread badge) → the player opens her conversation and the story begins

**Multiple secondary contacts:** add as many contacts as needed, each with their own `history` and `pending_scene`. The player can switch freely between them. The flag that unlocks the main contact can be set by any one of those replies — whichever the author designates.

## 3. Dialogue File (`dialogues/*.json`)

Each file contains:

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

### Scene Fields

- `id`: unique identifier. IDs are global — every scene across all your files must have a different ID. **Recommended convention**: prefix with the file or act name to avoid collisions on larger projects (`act1_intro`, `act2_confrontation`). A short ID (`intro`) is fine for single-file projects.
- `contact_id`: identifier of the contact speaking.
- `_notes`: ignored by the engine — use freely to annotate your scenes. E.g. `"_notes": "Opening scene — revision planned"`.
- `trigger_after_scene`: ID of a scene after which this one plays automatically.
- `resume_after_flag`: flag name. The scene waits until that flag is set.
- `messages_in`: list of incoming messages.
- `choices`: list of choices presented to the player.
- `free_input`: variable name to capture free text input from the player.
- `next`: ID of the next scene when `free_input` is used.
- `music`: Godot path to an audio file to play as background music. Optional — three possible behaviors:
  - **Absent**: the current music continues uninterrupted.
  - **Path** (`"res://assets/music/tension.ogg"`): plays this track on loop. No effect if the same track is already playing.
  - **`null`**: fades out and stops the current music.

Music automatically ducks when the player plays an audio message, then fades back up when playback ends.

## 4. Incoming Messages (`messages_in`)

### Short Form

A simple message can be written as a string:

```json
"Hello?"
```

The engine automatically converts a string into `{ "text": "..." }`.

### Full Form

```json
{
  "text": "I'm lost.",
  "pause": "short",
  "requires_flag": "called_for_help",
  "condition": { "var": "trust", "op": "gte", "value": 2 },
  "effects": [ ... ],
  "media": { "type": "image", "path": "res://assets/images/location.png" },
  "time": "14:43"
}
```

### Available Fields

- `text`: message content. Can be `null` if a media file is sent instead. Also accepts an **array of strings** to chain multiple bubbles in a single declaration — see below.
- `pause`: `short`, `medium`, `long`.
- `requires_flag`: message shown only if the flag is set. Can be a string (single flag) or an array of strings (all flags must be set).
- `condition`: condition based on a numeric variable.
- `edit`: modifies the message after it is sent.
- `corrupted`: displays the bubble as a corrupted message — **✗ Corrupted message** in red. `text` is not required.
- `effects`: effect triggered immediately when the message appears.
- `media`: image or audio attachment.
- `time`: optional timestamp displayed below the bubble. `"HH:MM"` → shown as-is (same-day message). `"YYYY-MM-DD HH:MM"` → shown as `"DD-MM-YYYY HH:MM"` (FR locale) or `"YYYY-MM-DD HH:MM"` (other locales) if the date is before today.

### Editing a Message After Sending (`edit`)

A message can correct itself or be deleted automatically after a delay — as if the contact noticed a typo or thought better of what they wrote.

**Correction:**

```json
{
  "text": "I have no idea where i am.",
  "edit": { "type": "correct", "corrected_text": "I have no idea where I am.", "delay": 2.0 }
}
```

**Deletion:**

```json
{
  "text": "Never mind.",
  "edit": { "type": "delete", "delay": 3.0 }
}
```

- `type`: `correct` to replace the text, `delete` to replace the bubble with *"Message deleted"*.
- `corrected_text`: the new text to display (required if `type` is `correct`).
- `delay`: time in seconds before the edit occurs. Optional — defaults to `1.5`.

`edit` also accepts an **array** to chain multiple operations. Each delay is relative to the previous operation:

```json
{
  "text": "Never mind, I'm fine.",
  "edit": [
    { "type": "correct", "corrected_text": "Never mind...", "delay": 2.0 },
    { "type": "delete", "delay": 3.0 }
  ]
}
```

### Corrupted Message (`corrupted`)

A message can arrive in a corrupted state. The typing indicator appears as normal, then instead of text the bubble displays **✗ Corrupted message** in red.

Useful to simulate a failed transmission, a jammed signal, or an intentionally incomplete message.

```json
{
  "id": "scene_weak_signal",
  "messages_in": [
    { "text": "I'm going to try sending the photo—" },
    { "corrupted": true },
    { "text": "Did you get anything?", "pause": "short" }
  ],
  "choices": [
    { "text": "No, nothing came through.", "message": "No, nothing.", "next": "scene_retry" },
    { "text": "Something arrived but it's unreadable.", "message": "I got something but it's completely corrupted.", "next": "scene_retry" }
  ]
}
```

Like any other message, `corrupted` accepts `pause`, `requires_flag`, `condition`, and `effects`:

```json
{ "corrupted": true, "pause": "short", "requires_flag": "weak_signal" }
```

### Bubble Array

When `text` is an array, the engine automatically expands it into multiple separate message bubbles:

```json
{
  "text": ["...", "That's not spam!", "I'm a real person."],
  "requires_flag": "rep_a",
  "pause": "short"
}
```

Expansion rules:
- `requires_flag` and `condition` apply to **all** bubbles
- `pause` and `effects` apply to the **first** bubble only
- `time` applies to the **last** bubble only

To add a pause on a specific bubble, replace the string with an object `{ "text": "...", "pause": "short" }`:

```json
{
  "text": [
    "Thank you for staying with me!",
    { "text": "It's reassuring to have someone on the outside...", "pause": "short" },
    "But I'm really scared."
  ],
  "requires_flag": "rep_b1"
}
```

Strings and objects can be freely mixed in the same array. The parent's `requires_flag` applies to all bubbles regardless.

## 5. Media Messages

### Image

```json
{
  "text": null,
  "media": { "type": "image", "path": "res://assets/images/location.png" }
}
```

**Important**:
- Image files must be placed in the `assets/images/` folder.
- In JSON, always use a Godot path starting with `res://assets/images/`.

### Audio

```json
{
  "text": null,
  "media": { "type": "audio", "path": "res://assets/sounds/voicenote.ogg" }
}
```

**Important**:
- Audio files must be placed in the `assets/sounds/` folder.
- In JSON, always use a Godot path starting with `res://assets/sounds/`.

## 6. Choices (`choices`)

A choice is an object with at least a `text` field.

```json
{
  "text": "I'll help you.",
  "message": "I'll help you.",
  "next": "scene_02",
  "flag": "commitment_a",
  "effects": [ ... ]
}
```

### Notes

- `next`: ID of the scene to play after the player confirms this choice. Required in most cases.
- `message` can be a string or an array of strings.
- If `message` is an array, each element is sent as a separate bubble by the player.
- `flag` activates a boolean flag.
- `effects` applies variable changes or contact modifications.
- `requires_flag` and `condition` control choice visibility — a choice whose condition is not met will not appear in the list. The same syntax as for messages is supported.

> **Maximum 4 choices per scene.** The engine renders up to 4 choice buttons at a time. Entries beyond the fourth are silently ignored — no error is raised.

> **Warning**: if all choice conditions are false at the same time, the player will be stuck with nothing to click. Always ensure at least one choice is visible — either by leaving it without a condition, or by making sure all cases are covered.

### Multi-bubble Message Example

```json
{
  "text": "Hmm… curious though.",
  "message": [
    "I'm not convinced…",
    "But I'm curious to see where this goes."
  ],
  "next": "scene_02"
}
```

In this example, the choice displays the label `Hmm… curious though.`, then the player sends two messages in sequence.

## 7. Effects

Effects are declared in the `effects` field of a **message** or a **choice** and applied immediately.

> **Important**: `effects` is always nested inside a message or choice — never at the scene level. A field like `"set_status": "..."` placed directly on the scene object will be silently ignored by the engine.

### Supported Operations

- `set`: sets a variable to a fixed value.
- `add`: adds a value to a variable.
- `sub`: subtracts a value from a variable.
- `rename`: changes a contact's display name. `value` accepts either a plain string or a language-keyed dict (see below).
- `set_status`: changes a contact's status. Accepted values: `online`, `away`, `offline`, `network_issue`.

### Examples

```json
"effects": [
  { "op": "set", "var": "trust", "value": 1 },
  { "op": "add", "var": "stress", "value": 2 },
  { "op": "rename", "contact": "unknown", "value": "Maeve" }
]
```

### Localized rename

When the revealed name must itself be translated (e.g. a title like "The Guardian"), pass a language-keyed dict as `value` instead of a plain string:

```json
{ "op": "rename", "contact": "unknown", "value": { "fr": "Le Gardien", "en": "The Guardian" } }
```

The engine resolves the dict against the active language at the moment the effect fires, and again if the player changes language after that. If the active language has no key in the dict, the first value in the dict is used as the fallback.

A plain string (e.g. `"Maeve"`) remains the right choice for proper names that are the same in all languages — it takes precedence over all locale-specific values.

## 8. Variables and Conditions

### Variables

Variables are numeric and stored in `vars`.

### Multiple Flags (AND)

`requires_flag` accepts a string or an array. With an array, all flags must be set:

```json
"requires_flag": ["rep_a", "commit_t"]
```

### Simple Condition

```json
"condition": { "var": "trust", "op": "gte", "value": 2 }
```

Supported operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`.

### Compound Conditions

`condition` can use `and` and `or` operators with nested nodes.

Each node can be:
- `{ "flag": "flag_name" }` — checks a flag
- `{ "var": "...", "op": "...", "value": ... }` — compares a variable
- `{ "and": [...] }` or `{ "or": [...] }` — sub-expression

**AND between a flag and a variable:**

```json
"condition": {
  "and": [
    { "flag": "rep_a" },
    { "var": "trust", "op": "gte", "value": 3 }
  ]
}
```

**OR between two flags:**

```json
"condition": {
  "or": [
    { "flag": "react_r" },
    { "flag": "react_u" }
  ]
}
```

**Nested:**

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

Lets the player type a free-text response.

```json
{
  "id": "scene_capture",
  "messages_in": ["What's your name?"],
  "free_input": "player_name",
  "free_input_placeholder": "Enter your first name…",
  "next": "scene_response"
}
```

- `free_input`: name of the variable where the entered value is stored. The name is up to you — `"first_name"`, `"secret_code"`, `"answer"` are all valid.
- `free_input_placeholder`: text displayed in the input field before the player types. Optional — falls back to the default placeholder if absent.

The entered value can then be injected into any message text via templates (see next section): `"So {first_name}, what were you doing that night?"`

## 10. Templates

Variable values can be injected into message text using curly braces:

```json
"text": "Thank you {player_name}, that's reassuring."
```

## 11. Secondary Contacts

When a scene has a `contact_id` different from the currently active contact, the engine plays it in the background: messages are added to that contact's history, a notification badge appears in the panel, and the player decides when to switch and read the conversation.

This is the main mechanism for multi-contact stories. Example: Maeve is the main contact, Alex sends a message while the player is reading Maeve's conversation. When the player switches to Alex, the messages appear and any pending choices are shown — a full branching conversation is possible, exactly like the main contact.

```json
{
  "id": "alex_interrupts",
  "contact_id": "alex",
  "trigger_after_scene": "scene_03",
  "messages_in": ["Did you see the news?"]
}
```

This scene triggers automatically after `scene_03` and arrives in Alex's conversation, not Maeve's.

## 12. Triggers and Deferred Scenes

- `trigger_after_scene`: the scene plays automatically after the given scene ID finishes.
- `resume_after_flag`: the scene is deferred until the specified flag is set.
- `resume_after_delay`: the scene plays after a real-time delay. The engine records the target time in the save file — if the game is relaunched in between, the scene plays immediately on load if the delay has passed, or resumes the countdown otherwise.

Accepted formats for `resume_after_delay`:
- Number of seconds: `300`
- String with suffix: `"5m"`, `"1h"`, `"30s"`

### Pattern 1 — Delay triggered by a choice

The contact announces they're leaving, the player replies, and the next message only arrives one hour later in real time.

```json
[
  {
    "id": "maeve_leaves",
    "contact_id": "maeve",
    "messages_in": [
      "I need to deal with something urgent.",
      { "text": "I'll message you again in an hour.", "pause": "short" }
    ],
    "choices": [
      {
        "text": "Ok, take your time.",
        "message": "Ok, take all the time you need.",
        "next": "maeve_returns"
      }
    ]
  },
  {
    "id": "maeve_returns",
    "contact_id": "maeve",
    "resume_after_delay": "1h",
    "messages_in": [
      "I'm back.",
      { "text": "Sorry for the wait.", "pause": "short" }
    ],
    "choices": [
      {
        "text": "No worries at all.",
        "message": "No worries at all.",
        "next": "next_scene"
      }
    ]
  }
]
```

When the player selects a choice in `maeve_leaves`, the engine tries to play `maeve_returns` — but it has a one-hour delay. The engine records the target time and stops. One hour later (game open or relaunched), `maeve_returns` plays automatically.

### Pattern 2 — Delay on an automatically triggered scene

No intermediate choice needed here. The scene triggers at the end of another via `trigger_after_scene`, but only arrives after a delay.

```json
[
  {
    "id": "scene_03",
    "contact_id": "maeve",
    "messages_in": ["I'll send you the info tonight."],
    "choices": [
      {
        "text": "Ok, I'll wait.",
        "message": "Ok, I'll wait.",
        "next": "scene_04"
      }
    ]
  },
  {
    "id": "maeve_evening",
    "contact_id": "maeve",
    "trigger_after_scene": "scene_03",
    "resume_after_delay": "3h",
    "messages_in": [
      "Done, I sent everything.",
      { "text": "Let me know if you got it.", "pause": "short" }
    ],
    "choices": [...]
  }
]
```

`maeve_evening` triggers automatically at the end of `scene_03`, but its 3-hour delay is applied first — the player will receive the message 3 hours later, even if they closed the game.

> **Note**: `resume_after_delay` works with any contact (`contact_id`). A secondary contact scene with a delay will arrive in the right conversation at the right time, with its notification badge.

## 13. Validation

The game automatically validates `story.json` and all `dialogues/*.json` files on launch in Godot.

If errors or warnings are found, a window appears immediately in the game with a full breakdown. Errors are also logged to the Godot console.

No tools to install: just open the project in Godot and read the report that appears.

## 14. Localizing Dialogues

The engine supports multiple languages through separate dialogue files.

### Naming Convention

```
dialogues/
├── acte1.json        ← base file (loaded when no locale-specific variant exists)
├── acte1.fr.json     ← French variant
└── acte1.en.json     ← English variant
```

On startup, the engine automatically selects the file matching the active language. If no variant exists for the current locale, it falls back to the base file (no suffix).

### Per-locale Start Scene

If your story has a different entry point per language (different prologue, entirely distinct scene structure…), you can declare a `start_scene` directly inside the localized dialogue file — it takes priority over the one in `story.json`:

```json
{
  "start_scene": "ch1_intro",
  "scenes": [
    { "id": "ch1_intro", ... },
    ...
  ]
}
```

If the file has no `start_scene`, the value defined in `story.json` is used.

### Language Change Mid-Game

When the player changes language from Settings, the game reloads the dialogue files and resumes from the save. What is preserved:

- The history of messages already played
- Flags, variables, and contact statuses
- Contact names renamed via `rename` — if the value is a localized dict, the name is displayed in the new language automatically

If a scene from the save does not exist in the target locale (two entirely separate scene sets per language), the engine restores the state without replaying the scene — the player finds their conversations as they left them.

### Adding a Language

1. Duplicate the base file: `acte1.json` → `acte1.es.json`
2. Translate all `text`, `message`, and `choices[].text` fields
3. Keep all IDs (`id`, `next`, `flag`, `requires_flag`) identical — these are internal keys, not displayed text

### UI Translations

Interface texts (statuses, buttons, validation messages) are managed separately in `translations/ui.csv`. To add a language, add a column with the ISO language code (`es`, `de`, etc.) and fill in all keys.

```csv
keys,en,fr,es
STATUS_ONLINE,online,en ligne,en línea
BTN_CANCEL,Cancel,Annuler,Cancelar
```

The system language is detected automatically on first launch. Players can change it via the **Settings** menu (⚙).

## 15. Debug Tool — Jump to Scene

A debug overlay is built into the engine to make testing easier — no need to replay from the beginning every time.

### Access

Press **F9** during the game to open or close the overlay.

> **The overlay is only available in the Godot editor and Debug exports.** It is automatically absent from Release exports — no cleanup required before publishing.

### Usage

The overlay has three sections:

- **Scene ID** — type the exact ID of any scene (e.g. `scene_05`). The field flashes red briefly if the ID is invalid.
- **Flags** — a list of every flag known to the project. Check the ones the target scene depends on before jumping.
- **Vars** — variables to inject, one per line in `key=value` format. Integers and floats are detected automatically; anything else is stored as a string (useful for pre-filling a `free_input` variable before jumping to the next scene):

```
trust=3
stress=1
player_name=Alice
```

Click **Jump** to apply the state and play the scene. The current conversation is replaced immediately.

**Close** (or F9) dismisses the overlay without changing any game state.

## 16. Emoji

Emoji work in any text field: `text`, `message`, `free_input_placeholder`.

### Copy-paste

Paste the emoji character directly into the JSON — no special encoding needed.

```json
{ "text": "That made me laugh 😂" }
```

### Text shortcuts

If you can't copy-paste an emoji, use the standard text shortcuts — the engine converts them automatically on display.

| Shortcut | Emoji | | Shortcut | Emoji |
|----------|-------|-|----------|-------|
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

## 17. Main Menu

The main menu is fully configured from `story.json` and `theme.json` — no code changes needed.

### Title

The `title` field in `story.json` sets the text displayed prominently on the main menu.

```json
{
  "title": "My Story",
  "start_scene": "intro",
  "contacts": [ ... ]
}
```

If the field is absent, the title is left empty.

### Glitch effect

By default, the title plays a glitch animation on load: characters appear as noise, then decode progressively, with random corruptions at idle.

To disable the effect, add `"title_glitch": false` in `theme.json`:

```json
{
  "title_glitch": false
}
```

| Value | Behaviour |
|-------|-----------|
| `true` (default) | Decode animation on load + random idle glitches |
| `false` | Static title, displayed immediately |
