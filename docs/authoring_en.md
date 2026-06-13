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

- `start_scene`: ID of the starting scene.
- `contacts`: array of contacts.
  - `id`: unique identifier for the contact.
  - `name`: text displayed in the top bar.
  - `is_main`: `true` for the main scriptable contact.
  - `avatar`: icon path or `null`.
  - `status`: `online`, `away`, `offline`, `network_issue`.

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

- `id`: unique identifier.
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
- `effects`: effect triggered immediately when the message appears.
- `media`: image or audio attachment.
- `time`: optional timestamp displayed below the bubble. Format `"HH:MM"` — e.g. `"14:43"`.

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

Effects are declared in `effects` and applied immediately.

### Supported Operations

- `set`: sets a variable to a fixed value.
- `add`: adds a value to a variable.
- `sub`: subtracts a value from a variable.
- `rename`: changes a contact's display name.
- `set_status`: changes a contact's status. Accepted values: `online`, `away`, `offline`, `network_issue`.

### Examples

```json
"effects": [
  { "op": "set", "var": "trust", "value": 1 },
  { "op": "add", "var": "stress", "value": 2 },
  { "op": "rename", "contact": "maeve", "value": "Maeve" }
]
```

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
  "next": "scene_response"
}
```

The entered value is stored in the variable `player_name`.

## 10. Templates

Variable values can be injected into message text using curly braces:

```json
"text": "Thank you {player_name}, that's reassuring."
```

## 11. Secondary Contacts

When a scene has a `contact_id` different from the currently active contact, the engine plays it in the background: messages are added to that contact's history, a notification badge appears in the panel, and the player decides when to switch and read the conversation.

This is the main mechanism for multi-contact stories. Example: Maeve is the main contact, Alex sends a message while the player is reading Maeve's conversation.

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
