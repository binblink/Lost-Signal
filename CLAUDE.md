# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Maeve — Lost Signal** is a narrative game built with Godot 4.6 (GDScript). It simulates a messaging app: the player exchanges messages with characters driven entirely by JSON data files. No compilation step — open the project in Godot 4.6 and press F5 (or run via the Godot editor).

There are no automated tests. Validation runs automatically at launch: if `story.json` or any `dialogues/*.json` file has errors, a blocking dialog appears in-game, and errors are logged to the Godot console.

**Debug overlay**: press **F9** in-game (debug builds only) to jump to any scene, set flags, and inject variables without replaying from the start.

## Architecture

### Autoloads (singletons)

| Autoload | File | Role |
|---|---|---|
| `DialogueLoader` | `scripts/autoloads/dialogue_loader.gd` | Loads `story.json` and all `dialogues/*.json`; exposes scenes, contacts, triggers; runs structural validation on startup |
| `SaveManager` | `scripts/autoloads/save_manager.gd` | Read/write `user://savegame.json` (JSON); serialises `NarrativeController.get_state()` |
| `ThemeManager` | `scripts/autoloads/theme_manager.gd` | Loads `theme.json`; exposes colours and `font_size`/`typing_speed`; helpers `restyle_panel`, `restyle_bubble`, `restyle_choice_button` |
| `SettingsManager` | `scripts/autoloads/settings_manager.gd` | Loads `user://settings.json`; manages language, volume, resolution; loads `translations/ui.csv` into `TranslationServer` |
| `AudioManager` | `scripts/autoloads/audio_manager.gd` | Procedurally generates notification beep and typing click (no audio file needed); handles music playback with fade/duck |

### Scene flow

`Main.tscn` / `scripts/main.gd` is the root scene. It instantiates `NarrativeController` (not a scene, just a Node added via code), wires up all UI signals, and orchestrates save/load.

Key responsibilities of `main.gd` that live outside `NarrativeController`:

- **Contact switching** (`_on_contact_selected`): before switching, saves the current conversation via `message_display.collect_messages_data()` into `_narrative.contact_histories[current_id]`, then renders from `_narrative.contact_histories[new_id]` and calls `restore_pending_choice_for`. This is the only place histories are snapshotted from the live UI back into the engine state.
- **Free input visual** (`_start_free_input_visual` / `_stop_free_input_visual`): responds to `NarrativeController.free_input_activated` signal. Creates a pulsing `Panel` border overlay on top of the input bar; cleared on `free_input_aborted`. `line_edit.clear()` is called at the start to flush any stale text before setting `placeholder_text`.
- **Image popup**: `_on_image_clicked(path)` loads the texture into `%PhotoImage` and shows `%PhotoOverlay`. Clicking the overlay hides it.
- **Startup validation**: if `DialogueLoader.has_validation_issues()`, an overlay + `ValidationDialog` block the UI immediately before any narrative starts.
- **Debug overlay**: `scripts/debug_overlay.gd` is added as a child only when `OS.is_debug_build()` — absent from release exports automatically.
- **TopBar** (`scripts/ui/top_bar.gd`): separate Node instantiated by main.gd; receives node refs via properties; exposes `refresh(contact_id, names, statuses)`. Owns the blink tween for `network_issue` status.
- **ExitDialog** (`scripts/ui/exit_dialog.gd`): separate PanelContainer instantiated by main.gd; emits `menu_requested`, `desktop_requested`, `close_requested`. main.gd handles save + navigation on those signals.

`NarrativeController` (`scripts/narrative_controller.gd`) is the story engine. It calls `play_scene(id)`, which:
1. Walks `messages_in` sequentially, evaluating conditions and effects
2. Shows a typing indicator before each text bubble (via `message_display.show_typing`)
3. After all messages, either awaits `free_input_submitted` or shows choices via `ChoicesManager`
4. Calls `_trigger_next_scenes` to chain scenes linked by `trigger_after_scene`

Secondary contacts: if a scene's `contact_id` differs from `active_contact_id`, `_play_secondary_scene` adds messages directly to `contact_histories[contact_id]` without animating them, then emits `secondary_scene_received`.

`MessageDisplay` (`scripts/ui/message_display.gd`) renders bubbles as child nodes of a VBoxContainer. Each bubble is a preloaded `.tscn` instantiated at runtime. It exposes `render_history(Array)` to replay saved messages when switching contacts or loading a save.

### Data files

```
story.json          ← contacts + start_scene
dialogues/
  acte1.json        ← French (default)
  acte1.en.json     ← English variant (loaded when language == "en")
theme.json          ← colour and font overrides
translations/ui.csv ← UI strings (keys, en, fr columns)
```

`DialogueLoader` prefers locale-specific files (`base.locale.json`) over the base file. Scene IDs must be globally unique across all loaded files.

### Story Editor plugin (`addons/story_editor/`)

An `@tool` EditorPlugin that renders a visual graph of all narrative scenes and supports direct JSON editing from the graph. Activated via Project Settings → Plugins.

| File | Role |
|---|---|
| `plugin.cfg` | Godot plugin manifest |
| `plugin.gd` | `EditorPlugin` — mounts/unmounts the bottom panel |
| `StoryEditorPanel.tscn` | Panel scene: `HSplitContainer[GraphEdit, ScrollContainer]` + toolbar |
| `StoryEditorPanel.gd` | Graph rendering, BFS layout, detail panel, editing, JSON writing; opens Contacts and Settings windows |
| `StoryPanelBase.gd` | Shared base (`extends Control`) for both floating panels: `story.json` read/write, undo/redo callables, UI helpers |
| `ContactsPanel.gd` | Character list editor; extends `StoryPanelBase` |
| `StorySettingsPanel.gd` | Global settings, languages, end screen; extends `StoryPanelBase` |
| `scene_parser.gd` | Standalone `RefCounted` that reads JSON files with locale support (uses `OS.get_locale_language()`, not `SettingsManager`) |

**Editing actions** (all write directly to JSON and trigger an auto-refresh):
- **Right-click on background** → create a new scene (ID, contact, target file)
- **Drag output port → input port** → writes `next` or `choices[i].next`
- **Right-click on node** → disconnect a specific outgoing connection, or delete the scene (cleans up all references across all files)
- **Click node → detail panel** → full scene editor: message text/pause/requires_flag/effects, choice text/message/flag/requires_flag/next/effects, free_input, trigger_after_scene, resume_after_flag, resume_after_delay — all via form controls with dropdowns populated from live project data (scene IDs, flags, contacts, vars). Advanced fields (structured `condition`, media, music) remain JSON-only. For `edit` ops, `corrected_text` is editable in the panel; type and delay are read-only.

**Key constraints**:
- `scene_parser.gd` is decoupled from `dialogue_loader.gd` because game autoloads are unavailable in editor context.
- Only `GraphNode` children of `GraphEdit` are freed on rebuild — never `get_children()` blindly, as that would delete the internal `connection_layer` node and corrupt the graph.
- `_editor_file` meta-key is injected per scene in memory by `scene_parser.gd` to track which file to write to; it is never written to disk.
- `_write_json()` applies `_ordered_scene()` (semantic key order) then `_json_expand()` (custom serializer, compact at depth ≥ 4) before writing.
- Both floating panels (`ContactsPanel`, `StorySettingsPanel`) extend `StoryPanelBase` and receive four injected callables: `get_scene_ids`, `begin_mutation`, `end_mutation`, `snapshot_file`. The last three wire them into the undo/redo system without creating a direct dependency on `StoryEditorPanel`. All editor mutations use snapshot-based undo/redo via `EditorUndoRedoManager` (before/after file content pairs); CSV language mutations are excluded as they trigger a Godot reimport.

Full user-facing docs: `docs/story_editor_en.md` (English), `docs/story_editor.md` (French).

### State machine in NarrativeController

Key state variables:
- `flags: Dictionary` — boolean flags set by choices (`flag` field)
- `vars: Dictionary` — numeric/string variables set by effects; injected into message text via `{var_name}` templates
- `contact_histories: Dictionary` — `contact_id → Array` of message data; persisted in save
- `deferred_scenes: Dictionary` — `flag_name → scene_id` for `resume_after_flag`
- `scheduled_scenes: Dictionary` — `scene_id → unix_timestamp` for `resume_after_delay`
- `pending_choices: Dictionary` — `contact_id → scene_id` for secondary contacts awaiting player input

`get_state()` / `set_state()` serialise and restore the complete engine state.

## Key patterns

**Awaiting player interaction**: `play_scene` uses `await` on signals (`choice_made`, `free_input_submitted`). `abort_current()` emits these signals with empty values and sets `_abort = true` to unblock any suspended coroutine cleanly.

**Generation guard**: `_play_generation` is incremented on abort. Each `play_scene` call captures `var _gen := _play_generation` and checks it after any `await` to bail out if the scene was aborted mid-playback.

**Message bubble sizing**: Bubble width is set by `scripts/ui/messageswidth.gd` (attached to each Bubble PanelContainer) after layout via `get_viewport_rect().size.x * 0.45`. Image thumbnails use `custom_minimum_size` set via code after the texture is loaded (texture dimensions are available immediately on `load()`; no frame await needed).

**Localisation**: UI strings use `tr("KEY")` with keys defined in `translations/ui.csv`. Dialogue text is in the JSON files themselves — no TR keys.

**Theme application**: `ThemeManager` methods duplicate existing `StyleBoxFlat` resources rather than mutating them, to avoid cross-node contamination.

## GDScript typing rules

Warnings are treated as errors in this project. The most common violation:

**Never use `:=` when the right-hand side returns a `Variant`** — this infers the variable as `Variant` and triggers `INFERRED_DECLARATION_UNKNOWN_TYPE`. Always provide an explicit type instead:

```gdscript
# WRONG — Dictionary.get() returns Variant, := infers Variant
var is_main := some_dict.get("is_main", false)

# CORRECT
var is_main: bool = some_dict.get("is_main", false)
```

This applies to any call that returns `Variant`: `Dictionary.get()`, `Array` element access by index, untyped function return values, etc. When in doubt, annotate the type explicitly.

## Authoring dialogue (quick reference)

Full spec: `docs/authoring_en.md`

- Scene chain: `next` (after `free_input` or `trigger_after_scene`), `choices[].next`
- Conditional display: `requires_flag` (string or array) or `condition` (structured with `and`/`or`/`flag`/`var`)
- Effects on message or choice: `{ "op": "set"|"add"|"sub", "var": "...", "value": ... }` or `{ "op": "rename"|"set_status", "contact": "...", "value": "..." }`
- `free_input`: captures player text into a variable; use `free_input_placeholder` for the hint text; variable available as `{var_name}` in later messages
- `text` as array: expands into multiple bubbles; `pause`/`effects` on first, `time` on last
- `resume_after_delay`: accepts `300`, `"5m"`, `"1h"` — delay is wall-clock time, survives game restarts
- Max 4 choices per scene (extras silently ignored)
- `_notes` field on any scene is ignored by the engine (safe to use freely)
