# Lost Signal

A narrative engine for Godot 4.6 that simulates a real messaging app.

Your story lives entirely in JSON files — contacts, scenes, branching choices, flags, variables, timed messages, images, audio. No code to write. No scripting to learn. Open Godot, press F5.

Includes a visual scene graph editor built directly into Godot.

---

## Table of Contents

1. [Documentation](#documentation)
2. [File Structure](#file-structure)
3. [Key Concepts](#key-concepts)
4. [Modifying the Visuals](#modifying-the-visuals)

---

## Documentation

**Full documentation online: [lost-signal.pages.dev](https://lost-signal.pages.dev/index_en/)**

**New to the engine?** Start with **`docs/getting_started_en.md`** — from opening the project to your first dialogue running in-game, in 8 steps.

**See `docs/authoring_en.md`** for the full documentation:
- JSON file structure (story.json, dialogues/*.json)
- Messages, choices, conditions, effects
- Flags, variables, templates, triggers
- All optional fields and their default values
- Debug tool (F9) to jump to any scene instantly without replaying from the start

**Validation**: The game automatically validates `story.json` and all `dialogues/*.json` files on launch in Godot. If errors are found, a window appears immediately with a full report.

**Story Editor**: A built-in Godot plugin displays a visual graph of all narrative scenes — see `docs/story_editor_en.md`. Enable it via **Project → Project Settings → Plugins**.

---

## File Structure

```
project/
├── story.json                    ← configuration (contacts, starting scene)
├── dialogues/
│   ├── acte1.json                ← narrative content (default language)
│   ├── acte1.en.json             ← English variant (optional)
│   └── ...other .json files
├── assets/
│   ├── avatars/                  ← contact profile pictures (PNG, JPG, WEBP)
│   ├── images/                   ← images for message bubbles (PNG, JPG, WEBP)
│   ├── sounds/                   ← audio messages (OGG, MP3, WAV)
│   └── music/                    ← background music tracks (OGG, MP3, WAV)
├── translations/
│   └── ui.csv                    ← UI translations (statuses, buttons…)
└── theme.json                    ← visual styles (colors, fonts, etc.)
```

### Adding Content

1. **Create** a `.json` file in `dialogues/`
2. **Write** scenes with messages and choices (see `docs/authoring_en.md` for the syntax)
3. **Place assets**:
   - Images in `assets/images/`
   - Sounds in `assets/sounds/`
   - Music in `assets/music/`
4. **Reference assets** in JSON files using a Godot path: `res://assets/images/...`, `res://assets/sounds/...` or `res://assets/music/...`
5. **Launch** the game in Godot — the validator reports any errors at startup

### Localizing Dialogues

The engine automatically picks the right dialogue file based on the active language:

- `acte1.json` → loaded when no locale-specific file exists (fallback)
- `acte1.fr.json` → loaded in French
- `acte1.en.json` → loaded in English

Players change the language via the **Settings** menu (⚙ button, top right). If the system language is supported, it is applied automatically on first launch.

---

## Modifying the Visuals

### Safe to Change

- **`theme.json`**: colors, font size, typing speed, and interface options. All fields are optional — an invalid or missing file simply falls back to the default theme.
  - `title_glitch` (`true` / `false`): enables or disables the glitch animation on the main menu title. Default: `true`.
- **Repositioning or resizing** nodes in the Godot editor.
- **Adjusting margins, spacing, and colors** in the Inspector.

### What Will Break the Game

**Renaming a node** that is referenced by code. Critical nodes are marked with a chain icon (🔗) in the Godot editor — these are declared as *Access as Unique Name*. Do not rename them.

To identify them: in the Godot editor, nodes with a link icon in the *Scene* panel are protected. Changing their **name** breaks the reference. Changing their **position in the tree** is always safe.

Protected nodes per scene:

| Scene | Protected Nodes |
|-------|----------------|
| `Main.tscn` | MessagesList, InputBar, TextInput, ChoicesLayer, ConfirmDialog, SettingsDialog, Overlay, Reset, PanelButton, SettingsButton, ExitButton, PhotoOverlay, PhotoImage, ContactName, StatusDot, StatusText, StatusWarning, ContactPanel, ClockLabel, ContactList, CloseButton, ButtonsContainer |
| `MainMenu.tscn` | Background, GameTitle, BtnContinue, BtnNewGame |
| `ContactPanel.tscn` | ContactList, CloseButton |
| `ContactItem.tscn` | InitialLabel, ContactName, ContactTime, ContactPreview, UnreadBadge |
| `MessageBubbleAudioIn.tscn` | Bubble, PlayButton, Progress, Duration, TimeAndStatus, AudioStreamPlayer |
| `TypingIndicator.tscn` | Dot1, Dot2, Dot3 |
| `ValidationDialog.tscn` | Title, Body, CopyButton, CloseButton |

### Moving Unique Nodes

Moving a *unique name* node anywhere in the scene tree is **always safe** — the code finds it by name, not by path.

---

## Key Concepts

The framework uses a small set of concepts to build stories:

- **Scenes**: dialogue blocks identified by a unique ID
- **Flags**: boolean variables for simple branching
- **Variables**: numbers for complex states (stress, trust, etc.)
- **Conditions**: show a message or choice only if a flag is set or a variable crosses a threshold — compound conditions (`and` / `or`) supported
- **Effects**: modify variables and contacts when a choice is made
- **Triggers**: chain scenes automatically, or defer them until a condition is met
- **Secondary contacts**: scenes can arrive in the background in another contact's conversation — the player gets a notification badge, switches when they choose, and can have a full conversation with choices and replies
