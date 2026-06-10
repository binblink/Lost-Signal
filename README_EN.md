# Maeve // Lost Signal — Content Guide

SMS-format visual novel built with Godot 4.6. All narrative content is defined in JSON files — no code changes needed.

---

## Table of Contents

1. [Documentation](#documentation)
2. [File Structure](#file-structure)
3. [Key Concepts](#key-concepts)
4. [Modifying the Visuals](#modifying-the-visuals)

---

## Documentation

**See `docs/authoring.md`** for the full documentation:
- JSON file structure (story.json, dialogues/*.json)
- Messages, choices, conditions, effects
- Flags, variables, templates, triggers
- All optional fields and their default values

**Validation**: The game automatically validates `story.json` and all `dialogues/*.json` files on launch in Godot. If errors are found, a window appears immediately with a full report.

---

## File Structure

```
project/
├── story.json                    ← configuration (contacts, starting scene)
├── dialogues/
│   ├── acte1.json                ← narrative content to add/edit
│   └── ...other .json files
├── assets/
│   ├── images/                   ← images for message bubbles (PNG, JPG, WEBP)
│   └── sounds/                   ← audio messages (OGG, MP3, WAV)
└── theme.json                    ← visual styles (colors, fonts, etc.)
```

### Adding Content

1. **Create** a `.json` file in `dialogues/`
2. **Write** scenes with messages and choices (see `docs/authoring.md` for the syntax)
3. **Place assets**:
   - Images in `assets/images/`
   - Sounds in `assets/sounds/`
4. **Reference assets** in JSON files using a Godot path: `res://assets/images/...` or `res://assets/sounds/...`
5. **Launch** the game in Godot — the validator reports any errors at startup

---

## Modifying the Visuals

### Safe to Change

- **`theme.json`**: colors, font size, typing speed. All fields are optional — an invalid or missing file simply falls back to the default theme.
- **Repositioning or resizing** nodes in the Godot editor.
- **Adjusting margins, spacing, and colors** in the Inspector.

### What Will Break the Game

**Renaming a node** that is referenced by code. Critical nodes are marked with a chain icon (🔗) in the Godot editor — these are declared as *Access as Unique Name*. Do not rename them.

To identify them: in the Godot editor, nodes with a link icon in the *Scene* panel are protected. Changing their **name** breaks the reference. Changing their **position in the tree** is always safe.

Protected nodes per scene:

| Scene | Protected Nodes |
|-------|----------------|
| `Main.tscn` | MessagesList, InputBar, TextInput, ChoicesLayer, ConfirmDialog, Overlay, Reset, PanelButton, MuteButton, PhotoOverlay, PhotoImage, ContactName, StatusDot, StatusText, StatusWarning, ContactPanel, ClockLabel, ContactList, CloseButton, ButtonsContainer |
| `MainMenu.tscn` | Background, GameTitle, BtnContinue, BtnNewGame |
| `ContactPanel.tscn` | ContactList, CloseButton |
| `ContactItem.tscn` | InitialLabel, ContactName, ContactTime, ContactPreview, UnreadBadge |
| `MessageBubbleAudioIn.tscn` | Bubble, PlayButton, Progress, Duration, TimeAndStatus, AudioStreamPlayer |
| `TypingIndicator.tscn` | Dot1, Dot2, Dot3 |

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
