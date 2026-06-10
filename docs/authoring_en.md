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
- `trigger_after_scene`: ID of a scene after which this one plays automatically.
- `resume_after_flag`: flag name. The scene waits until that flag is set.
- `messages_in`: list of incoming messages.
- `choices`: list of choices presented to the player.
- `free_input`: variable name to capture free text input from the player.
- `next`: ID of the next scene when `free_input` is used.

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

- `text`: message content. Can be `null` if a media file is sent instead.
- `pause`: `short`, `medium`, `long`.
- `requires_flag`: message shown only if the flag is set. Can be a string (single flag) or an array of strings (all flags must be set).
- `condition`: condition based on a numeric variable.
- `edit`: modifies the message after it is sent.
- `effects`: effect triggered immediately when the message appears.
- `media`: image or audio attachment.
- `time`: optional timestamp.

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

- `message` can be a string or an array of strings.
- If `message` is an array, each element is sent as a separate bubble by the player.
- `flag` activates a boolean flag.
- `effects` applies variable changes or contact modifications.

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
- `set_status`: changes a contact's status.

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

## 11. Triggers and Deferred Scenes

- `trigger_after_scene`: the scene plays automatically after the given scene ID finishes.
- `resume_after_flag`: the scene is deferred until the specified flag is set.

## 12. Validation

The game automatically validates `story.json` and all `dialogues/*.json` files on launch in Godot.

If errors or warnings are found, a window appears immediately in the game with a full breakdown. Errors are also logged to the Godot console.

No tools to install: just open the project in Godot and read the report that appears.
