# Story Editor — User Guide

The Story Editor is a Godot plugin built into the project. It displays a **visual graph** of all narrative scenes defined in the JSON files, directly inside the Godot editor — without modifying the game in any way.

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

- **Refresh button**: re-reads the JSON files and rebuilds the graph. Use it after editing any dialogue file.
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
| **⛔ Dead end** (red) | The scene has no outgoing connections (no `choices`, no `next`, no `free_input`) |
| **⚠ Isolated** (yellow) | No other scene points to this one — it can never be reached |

### Connection Types

Arrows between nodes are color-coded by their nature:

| Color | Type | Description |
|---|---|---|
| Light gray | `next` or `choice` | Normal continuation or player choice |
| Orange | `trigger` | Automatic trigger via `trigger_after_scene` |
| Purple | `resume` | Conditional resume via `resume_after_flag` |

---

## Detail Panel

Clicking a node shows in the right panel:

- **ID** of the scene (title in light blue)
- **Contact**: contact name (resolved from `story.json`)
- **Messages**: all bubbles, with pauses, conditions, and effects
- **Choices**: label, destination (`next`), associated flag, and effects
- **Special**: notable fields (`free_input`, `next`, `trigger_after_scene`, `resume_after_flag`, `music`)

Effects are displayed in orange. Conditions (`if flag`) are shown in the OS language (French if the machine is set to French, English otherwise).

---

## Locale Support

The plugin reads dialogue files using the same locale logic as the game:
- It prefers `acte1.en.json` if the system language is `en`, otherwise falls back to `acte1.json`
- The locale used matches the OS language setting, not the in-game language setting

---

## Architecture (for developers)

The plugin lives in `addons/story_editor/` and does not touch any existing project file.

| File | Role |
|---|---|
| `plugin.cfg` | Godot manifest (name, version) |
| `plugin.gd` | `EditorPlugin` — adds/removes the panel |
| `StoryEditorPanel.tscn` | Panel scene (Control → VBoxContainer → HSplitContainer[GraphEdit, ScrollContainer]) |
| `StoryEditorPanel.gd` | Main logic: parsing, BFS layout, graph rendering, detail panel |
| `scene_parser.gd` | Standalone `RefCounted` — reads `story.json` + `dialogues/*.json` with locale support |

`scene_parser.gd` is intentionally decoupled from `dialogue_loader.gd` to work in the editor context (game autoloads are not available inside a plugin).
