# Story Editor — User Guide

The Story Editor is a Godot plugin built into the project. It displays a **visual graph** of all narrative scenes defined in the JSON files, directly inside the Godot editor — without modifying the game outside of explicit editing actions.

---

## Activation

1. In Godot, open **Project → Project Settings → Plugins**
2. Enable **Story Editor**
3. A **Story Editor** tab appears at the bottom of the editor (bottom panel, next to the Output console)

---

## Interface

```
┌──────────────────────────────────────────────────────────────┐
│  [Refresh]  11 scenes loaded                                 │
├─────────────────────────────────────┬────────────────────────┤
│                                     │  scene_04              │
│  [▶ ch1_intro] → [scene_01] → …  │  Contact: Maeve         │
│                                     │  ─────────────────     │
│               Graph                 │  Messages (3)          │
│                                     │  …                     │
│                                     │  Choices (2)           │
│                                     │  …                     │
└─────────────────────────────────────┴────────────────────────┘
```

- **Refresh button**: re-reads the JSON files and rebuilds the graph. Use it after editing any dialogue file manually. Edits made from the graph trigger an automatic refresh.
- **Graph** (main area): nodes are draggable, zoomable with the mouse wheel, and navigable by holding middle-click or Space + drag.
- **Detail panel** (right): clicking a node displays its full content.

---

## Graph Nodes

Each JSON scene maps to one node. The title of the node is the scene's `id`.

### Visual Indicators

| Indicator | Meaning |
|---|---|
| **▶** before the ID | Starting scene (`start_scene` in `story.json`) |
| **✎** after the ID | Scene with `free_input` (player types a free-text response) |
| **⛔ Dead end** (red) | The scene has no outgoing connections — likely an authoring oversight |
| **⚠ Isolated** (yellow) | No other scene points to this one — it can never be reached |

### Connection Types

Arrows between nodes are color-coded by their nature:

| Color | Type | Description |
|---|---|---|
| Light gray | `next` or `choice` | Normal continuation or player choice |
| Orange | `trigger` | Automatic trigger via `trigger_after_scene` |
| Purple | `resume` | Conditional resume via `resume_after_flag` |

### Ports

Each node has:
- **One input port** (left) — receives connections from preceding scenes
- **One output port per connection** (right) — one per `next`, one per choice (`choices[]`)

If a scene has choices without a destination (`next` absent), their output ports appear without a wire — they are available to be connected.

If a scene has neither choices nor `next`, a **→ ?** port is shown: dragging from it to another node will add a scene-level `next` field.

---

## Detail Panel

Clicking a node shows in the right panel:

- **ID** of the scene (title in light blue)
- **Contact**: contact name (resolved from `story.json`)
- **Messages**: all bubbles, with pauses, conditions, and effects
- **Choices**: label, destination (`next`), associated flag, and effects
- **Special**: notable fields (`free_input`, `next`, `trigger_after_scene`, `resume_after_flag`, `music`)

Effects are displayed in orange. Conditions are shown in the OS language.

---

## Editing from the Graph

All edits are **written immediately to the corresponding JSON file**, then the graph is rebuilt automatically. No confirmation is required except for deletion.

### Create a Scene

**Right-click on the graph background** (not on a node) → creation dialog:

- **ID**: unique scene identifier (e.g. `scene_10`). If the ID already exists, creation is rejected.
- **Contact**: dropdown listing all contacts defined in `story.json`.
- **File**: if multiple JSON files exist in `dialogues/`, an extra dropdown lets you choose which file to write the scene into.

The scene is appended to the file with an empty message `{ "text": "" }`. It appears in the graph with the **⚠ Isolated** indicator until an incoming connection is created.

### Connect Two Scenes

**Drag from an output port** (right circle of a node) **to the input port** (left circle) of another node.

- If the output port corresponds to a **choice**, that choice's `next` field is written to the JSON.
- If the output port corresponds to the **scene-level `next`** (or the **→ ?** port), the scene's `next` field is written.
- If the port already had a destination, it is **replaced** by the new one.

> `trigger` and `resume` connections are read-only — they reflect JSON fields but cannot be modified from the graph.

### Disconnect or Remove a Connection

**Right-click on the source node** → the context menu lists all active outgoing connections:

```
Delete this scene
─────────────────────
Disconnect: C'est du spam → scene_02
Disconnect: Oui, je vous reçois → scene_02
```

Clicking a "Disconnect" entry removes the corresponding `next` from the JSON (the choice or scene `next` remains but without a destination).

### Delete a Scene

**Right-click on the node** → **Delete this scene** → confirmation dialog.

On confirmation:
- The scene is removed from its JSON file.
- All `next` and `choices[].next` fields pointing to this scene are removed across **all JSON files** in the project.
- The graph is rebuilt.

> Deletion is immediate and cannot be undone from the graph. Git is recommended for recovering accidental deletions.

---

## JSON Format Produced by the Editor

The editor writes JSON using a consistent semantic key order:

```
id → contact_id → messages_in → free_input → free_input_placeholder → next → choices
```

Messages and choices stay compact (one line per element). Indentation uses tabs, consistent with the rest of the file.

---

## Locale Support

The plugin reads dialogue files using the same locale logic as the game:
- It prefers `acte1.en.json` if the system language is `en`, otherwise falls back to `acte1.json`
- The locale used matches the OS language setting, not the in-game language setting

---

## Architecture (for developers)

The plugin lives in `addons/story_editor/` and does not touch any existing project file outside of explicit editing actions.

| File | Role |
|---|---|
| `plugin.cfg` | Godot manifest (name, version) |
| `plugin.gd` | `EditorPlugin` — adds/removes the panel |
| `StoryEditorPanel.tscn` | Panel scene (`HSplitContainer[GraphEdit, ScrollContainer]`) |
| `StoryEditorPanel.gd` | Main logic: parsing, BFS layout, graph rendering, editing, JSON writing |
| `scene_parser.gd` | Standalone `RefCounted` — reads `story.json` + `dialogues/*.json` with locale support |

`scene_parser.gd` is intentionally decoupled from `dialogue_loader.gd` to work in the editor context (game autoloads are not available inside a `@tool` plugin).

Scenes are written via `_write_json()`, which applies `_ordered_scene()` (semantic key ordering) then `_json_expand()` (custom serializer: expands to depth 3, compact beyond).
