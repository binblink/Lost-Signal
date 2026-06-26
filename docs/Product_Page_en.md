# 💬 Lost Signal — Real-Time Narrative Messaging Engine (Godot 4.6)

> Build interactive story games through a real-time messaging interface — the kind players recognize from Discord, WhatsApp, and modern chat apps.
> **No programming required. Build visually with the Story Editor, or write JSON directly.**

---

## 🎮 What is Lost Signal?

**Lost Signal** is a narrative engine for Godot 4 where the entire story unfolds through a **real-time messaging interface**: multiple simultaneous conversations, branching dialogue, background events, media messages. No code to write. No engine to modify.

Unlike mobile texting games, it's designed for **PC storytelling** with the visual grammar of Discord or Slack — parallel conversations unfolding independently, background characters messaging mid-scene, notification-driven pacing. Narrative structures that don't exist in traditional visual novels.

Most narrative tools are either too technical, too limited, or too generic. Lost Signal is built specifically for messaging-based narratives — not as a skin over a dialogue system, but as a system where communication *is* the mechanic.

---

## ✨ What you can create

- **Relationship stories** — friendships, breakups, emotional dialogue, character-driven drama
- **Psychological & experimental fiction** — unreliable messages, shifting perspectives, fragmented communication
- **Thriller & mystery** — multi-character investigations, conflicting narratives, hidden information
- **Sci-fi communication stories** — remote survival messaging, system-based storytelling (*Lifeline*-style)
- **Horror** — corrupted messages, disappearing contacts, unstable conversations

Perfect for narrative-driven indie games, interactive fiction, game jams, and writers or designers with no game development background.

---

## ⚡ Key Features

### 💬 Real-time messaging system
- Discord-style chat interface, built for PC
- Multiple active conversations with contact switching
- Animated typing indicator (three dots)
- Timestamps and natural message flow
- Emoji support — paste directly or use text shortcuts (`:)`, `<3`, `^^`…) in any message field
- Contact status indicators: online, away, offline, network issue — each a narrative tool, not just a UI state. A contact with *network issue* that keeps dropping in and out tells a story before a single message is sent.
- **Contact avatars** — each contact can have a profile picture (PNG, WEBP, JPG). When no avatar is set, an initial letter on a colored background is shown instead. Avatars appear in both the contact list and the top bar.

---

### 🧠 Full narrative logic — no scripting
Write your story through the Story Editor or directly in JSON. The engine handles the rest.

- **Branching dialogue** — choices that send player messages and advance the story. A choice can send a single message or a sequence of bubbles in a row — the way people actually text.
- **Flags** — boolean states for simple branching
- **Variables** — numeric values for complex systems (trust, stress, relationship scores…)
- **Conditions** — show messages or choices based on flags and variables, with full `and` / `or` / nested logic
- **Effects** — modify variables, change contact status, rename contacts mid-story. A contact listed as "Unknown Number" can reveal their name at the exact moment the story calls for it.
- **Free input + templates** — ask the player to type a free-text response, store it as a variable, and inject it anywhere in the story: `"Thanks {player_name}, that's reassuring."`

---

### 📬 Pre-existing conversations
Secondary contacts can have a conversation history and a pending choice waiting before the player even receives the first message. The player opens the app and already has unread messages — as if their character had a life before the story began.

Both are defined directly in `story.json`. The built-in **Contacts panel** lets you set all of this from inside Godot — no JSON file to open.

---

### 🔀 Background conversations
Characters don't wait for the player to finish reading.

Scenes can be set to **trigger automatically** after another scene ends, or **resume after a specific story flag** is set. A second character can message the player mid-conversation — the notification badge appears, and the player decides when to switch.

When they do, they enter a full conversation — choices, replies, branching — exactly like the main contact. Secondary contacts are not notifications. They are parallel storylines.

Background scenes run independently, are saved automatically, and persist across sessions.

---

### ⏱ Real-time delays
A character can say *"I'll message you in an hour"* — and actually mean it.

Scenes can be scheduled to play after a real-world delay: minutes, hours, or longer. The engine saves the target time. If the player closes the game and comes back later, the message arrives immediately on reload. If they stay in the game, it arrives when the timer expires.

This is the mechanic that made *Lifeline* feel like a real person was on the other end. It's now a single JSON field.

```json
{
  "resume_after_delay": "1h"
}
```

---

### 🎵 Scene music
Each scene can optionally declare a background music track. The engine handles looping, smooth fade-out when stopped, and automatic ducking when the player plays an audio message. If a scene doesn't specify music, whatever is playing continues uninterrupted.

---

### ✏️ Live message editing
Characters can modify their own messages after sending — correcting a typo with a delay, or deleting a message entirely. A single field also lets you send a message that arrives already corrupted: the typing indicator appears as normal, but the bubble shows **✗ Corrupted message** in red.

These mechanics open specific narrative possibilities: hesitation, regret, second thoughts, unreliable communication, degraded signal.

---

### 📎 Media messaging
- 📷 Images sent as chat bubbles, tappable to view fullscreen
- 🔊 Audio messages with a dedicated playback UI (progress bar, duration)
- Both are fully integrated into the save system

---

### 🌍 Built-in localization
- Dialogue files are selected per language: `scene.fr.json`, `scene.en.json`
- The engine picks the right file automatically based on the active language
- Falls back to the base file if no translation exists yet
- All UI text translated via a single CSV file — adding a new language takes minutes
- Language is auto-detected from the player's system on first launch
- Players can change language in-game at any time without losing progress

---

### 🔍 Built-in story validator
On every launch, Lost Signal validates all your JSON files and reports missing scene references, undefined flags, malformed effects, and dead ends. Errors appear **directly in the game window** — no console, no external tool.

---

### 🛠 Debug overlay — jump to any scene instantly
Press **F9** during play to open the debug overlay. Type a scene ID, pre-fill `free_input` variables, set trust or stress scores, toggle flags — then jump directly to the scene. Close with F9 and nothing changes.

> Only available in the Godot editor and Debug exports — automatically absent from Release builds.

---

### 🗺 Visual story graph — build your narrative without leaving Godot
A built-in Godot editor plugin renders your entire story as an **interactive graph** and lets you edit the structure directly.

Enable it once in Project Settings → Plugins.

**What you see:**
- **▶** marks the starting scene · **✎** marks free-input scenes · **⛔ Dead end** (red) · **⚠ Isolated** (yellow)
- Arrows are color-coded: gray for normal flow, **orange** for automatic triggers, **purple** for flag-based resumes

**Edit the structure from the graph:**
- **Right-click background** → create a scene, choose contact and target file
- **Drag output port → node** → writes `next` or `choices[].next` into JSON automatically
- **Right-click node** → disconnect a link, or delete the scene (all references cleaned up across every file)

**Edit content from the detail panel:**
- Messages: text, pause, `requires_flag`, effects
- Choices: button text, player message (single bubble or sequence), flag, `requires_flag`, next scene, effects
- Triggers: `trigger_after_scene`, `resume_after_flag`, `resume_after_delay`
- Free input: variable name and placeholder, mutually exclusive with choices (enforced by the editor)

All dropdowns are populated from your actual project. Changes save on focus loss. Advanced features (structured `and`/`or` conditions, media, music) remain JSON-only.

**Contacts panel** (toolbar button): manage everything in `story.json` without opening the file — add/rename/remove contacts, set avatars, define histories, configure the start scene, configure the end screen. Renaming a contact ID propagates across every dialogue file automatically.

**Reformat button**: rewrites all dialogue files with canonical key order without changing content.

> The graph and the JSON files are always in sync — the graph is a live view of your files.

---

### ⚙️ Player settings — out of the box
Language, master volume, resolution (480p to 4K), and display mode (Windowed / Borderless / Exclusive Fullscreen). Persisted between sessions, applied automatically on launch.

---

### 🎨 Fully customizable interface
Theme system via `theme.json` — colors, typography, bubble sizing, typing speed. No code changes needed to reskin the entire game. Animated glitch title on the main menu, configurable via `title_glitch`.

---

### 💾 Automatic save system
Story state is saved **after every player choice and every received message**. Full persistence: variables, flags, conversation history, contact names and statuses. Save file is human-readable JSON. Main menu with New Game / Continue; in-game exit dialog.

---

### 🛠 Authoring workflow

**1. Define your contacts**
Open the Contacts panel from the Story Editor toolbar. Add a character: name, avatar, starting status. Thirty seconds per contact.

**2. Create scenes in the graph**
Right-click the graph background. Type a scene ID, pick a contact, choose the target file. A node appears.

**3. Write messages and choices**
Click the node. The detail panel opens on the right. Type messages, add choices with their reply text and destination scene — all from form fields.

**4. Connect scenes**
Drag from an output port to another node's input port. The `next` field is written to JSON automatically.

**5. Add logic when needed**
Flags, conditions, effects, triggers — all available from dropdowns in the detail panel. No JSON to open for common cases.

**6. Test immediately**
Press **F5** in Godot. Press **F9** to jump to any scene, set flags, inject variables — without replaying from the start.

That's the loop: write → connect → test → iterate. A complete game requires only:

```
story.json           ← contacts and starting scene
dialogues/*.json     ← your story scenes
assets/              ← images, audio and music (optional)
theme.json           ← visual style (optional)
```

No scripting, no nodes, no scenes to touch.

---

## 📄 Example scene

```json
{
  "id": "intro",
  "messages_in": [
    { "text": "Are you there?", "pause": "short" },
    { "text": "We need to talk." }
  ],
  "choices": [
    {
      "text": "Who is this?",
      "message": "Who are you?",
      "next": "scene_reveal",
      "flag": "asked_identity",
      "effects": [{ "op": "add", "var": "trust", "value": 1 }]
    },
    {
      "text": "Wrong number.",
      "message": "I think you have the wrong number.",
      "next": "scene_denial"
    }
  ]
}
```

Two messages arrive. The player picks a response. A variable updates. The story continues — no code written.

---

## 🏗 Why not build it yourself?

You could. Here's what it actually takes.

**The messaging UI** — chat bubbles (sent/received), correct text wrapping, scrolling, timestamps, contact switching, unread badges, animated typing indicator, image and audio bubbles with playback, avatars, status indicators. Realistic estimate: **2–4 weeks** for a clean, production-ready implementation.

**The narrative engine** — flag and variable system with save/load, conditional message display with `and`/`or` logic, branching choices with effects, background trigger system, real-time delay scheduling persisted across sessions, free text input with variable injection. Another **3–6 weeks**.

**The tooling** — debug overlay to jump to scenes without replaying, in-game story validator, visual graph editor with direct JSON editing. **2–4 weeks**, if you build them at all.

**Grand total: 2–4 months of infrastructure** before you write a single line of story. And that's if you've done something similar before.

Lost Signal gives you all of it on day one.

---

## 📦 What's included

- Full Godot 4.6 project — open and run immediately
- Complete messaging UI (typing indicators, media bubbles, contact panel, avatars)
- Visual Story Editor — scene graph with full detail editing and Contacts panel
- JSON narrative engine — conditions, variables, flags, effects, free input, templates
- Multi-contact system: background conversations, triggers, pending choices, pre-existing histories
- Real-time delays — scenes that arrive minutes or hours later, persisted across sessions
- Live message editing (correct, delete, or corrupted on arrival)
- Scene music with looping, fade, and audio ducking
- Built-in story validator with in-game reporting
- Debug overlay (F9) — jump to any scene, inject flags and variables
- Auto-save after every story beat; main menu (New Game / Continue)
- Player settings menu (language, volume, resolution, display mode)
- Localization system (per-language dialogue files + UI translation CSV)
- Theme system (`theme.json`) with animated glitch title (configurable)
- Configurable end screen (title, text, link, glitch effect, session stats) — editable from the Story Editor
- Playable demo scenario
- Bilingual authoring guide (EN + FR) with full syntax reference

---

## 📋 Before you start

**The Story Editor handles most authoring tasks without touching a file.** Characters, scenes, messages, choices, effects, triggers — all editable from Godot's interface. For advanced features (structured `and`/`or` conditions, media messages, music), you'll work directly in JSON. A basic familiarity with JSON syntax is enough for those cases; the built-in validator catches most mistakes.

**Linear stories are easy. Parallel stories take planning.** A single-contact story with branching choices is straightforward to build. Multi-contact narratives — where characters message you independently and interrupt each other — require thinking through the structure before you write. The tools are there; the design work is yours.

**The authoring guide is your reference, not a tutorial.** `docs/authoring_en.md` covers every field and every feature, but it assumes you're looking something up, not learning from scratch. Start with the demo scenario and modify it — that's the fastest way in. See the **[Getting Started guide](getting_started_en.md)** to go from opening the project to your first dialogue in 8 steps.

---

## ⚠️ Requirements

- Godot 4.6 or higher
- No external dependencies or plugins
