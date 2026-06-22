# 💬 Lost Signal — Real-Time Narrative Messaging Engine (Godot 4.6)

> Build interactive story games through a real-time messaging interface — the kind players recognize from Discord, Teams, and modern chat apps.
> **No programming required. Stories live in JSON files.**

---

## 🎮 What is Lost Signal?

**Lost Signal** is a narrative engine for Godot 4 that lets you build interactive story-driven games where everything unfolds through a **real-time messaging interface**.

Characters talk to the player through a desktop chat system:
- multiple simultaneous conversations
- branching dialogue with conditions and variables
- media messages (images, audio clips)
- background events that trigger while the player reads

You don't write code.
You don't modify the engine.
You write **JSON story files** — structured like templates, readable like scripts.

---

## 🖥️ A desktop-first narrative experience

Unlike mobile texting games, Lost Signal is designed for **PC storytelling** inspired by modern communication tools — Discord, Slack, Teams.

This unlocks narrative structures that don't exist in traditional visual novels:
- parallel conversations unfolding independently
- background characters sending messages mid-scene
- interruptions and notification-driven pacing
- multi-threaded storytelling across contacts

---

## ✨ What you can create

### 💔 Relationship-driven stories
Friendships, breakups, emotional dialogue, character-driven drama.

### 🧠 Psychological & experimental fiction
Unreliable messages, shifting perspectives, fragmented communication.

### 🕵️ Thriller & mystery
Multi-character investigations, conflicting narratives, hidden information.

### 🚀 Sci-fi communication stories
Remote survival messaging, system-based storytelling (*Lifeline*-style).

### 😨 Horror
Corrupted messages, disappearing contacts, unstable conversations.

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
Write your entire story in JSON. The engine handles the rest.

- **Branching dialogue** — choices that send player messages and advance the story. A choice can send a single message or a sequence of bubbles in a row — the way people actually text.
- **Flags** — boolean states for simple branching
- **Variables** — numeric values for complex systems (trust, stress, relationship scores…)
- **Conditions** — show messages or choices based on flags and variables, with full `and` / `or` / nested logic
- **Effects** — modify variables, change contact status, rename contacts mid-story. A contact listed as "Unknown Number" can reveal their name at the exact moment the story calls for it.
- **Free input + templates** — ask the player to type a free-text response, store it as a variable, and inject it anywhere in the story: `"Thanks {player_name}, that's reassuring."`

---

### 📬 Pre-existing conversations
Secondary contacts can have a conversation history and a pending choice waiting before the player even receives Maeve's first message. The player opens the app and already has unread messages — as if their character had a life before the story began.

Both the message history and the pending choice are defined directly in `story.json`, alongside the contact's name and status. The built-in **Contacts panel** lets you set all of this from inside Godot — no JSON file to open.

---

### 🔀 Background conversations
Characters don't wait for the player to finish reading.

Scenes can be set to **trigger automatically** after another scene ends, or **resume after a specific story flag** is set. This means a second character can message the player mid-conversation — the notification badge appears, and the player decides when to switch.

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
Each scene can optionally declare a background music track. The engine handles the rest — looping, smooth fade-out when stopped, and automatic ducking when the player plays an audio message. If a scene doesn't specify music, whatever is playing continues uninterrupted.

---

### ✏️ Live message editing
Characters can modify their own messages after sending — correcting a typo with a delay, or deleting a message entirely. A single field also lets you send a message that arrives already corrupted: the typing indicator appears as normal, but the bubble shows **✗ Corrupted message** in red instead of text.

These mechanics don't exist in traditional dialogue systems, and they open specific narrative possibilities: hesitation, regret, second thoughts, unreliable communication, degraded signal.

---

### 📎 Media messaging
- 📷 Images sent as chat bubbles, tappable to view fullscreen
- 🔊 Audio messages with a dedicated playback UI (progress bar, duration)
- Both are fully integrated into the save system

---

### 🌍 Built-in localization
Lost Signal is built for multilingual projects from the start.

- Dialogue files are selected per language: `scene.fr.json`, `scene.en.json`
- The engine picks the right file automatically based on the active language
- Falls back to the base file if no translation exists yet
- All UI text (buttons, status labels, menus) is translated via a single CSV file — adding a new language takes minutes
- Language is auto-detected from the player's system on first launch
- Players can change language in-game at any time without losing progress

---

### 🔍 Built-in story validator
Write with confidence — the engine checks your work before the player sees it.

On every launch, Lost Signal validates all your JSON files and reports:
- missing or broken scene references
- undefined flags used in conditions
- malformed effects or conditions
- unreachable choices or dead ends

Errors and warnings appear **directly in the game window** — no console, no external tool, no guesswork.

---

### 🛠 Debug overlay — jump to any scene instantly
Press **F9** during play to open the debug overlay. Type a scene ID, check the flags and variables the scene depends on, and jump directly to it — no need to replay the beginning every time you test a change.

Pre-fill `free_input` variables, set trust or stress scores, toggle flags on or off: the overlay injects everything before launching the scene. Close it with F9 and nothing changes.

> Only available in the Godot editor and Debug exports — automatically absent from Release builds.

---

### 🗺 Visual story graph — build your narrative without leaving Godot
A built-in Godot editor plugin renders your entire story as an **interactive graph** — every scene as a node, every connection as an arrow — and lets you edit the structure directly.

Enable it once in Project Settings → Plugins.

**What you see:**
- **▶** marks the starting scene
- **✎** marks scenes with free-text player input
- **⛔ Dead end** (red) flags scenes with no outgoing connections — likely an authoring mistake
- **⚠ Isolated** (yellow) flags scenes nothing links to — they can never be reached
- Arrows are color-coded: gray for normal flow, **orange** for automatic triggers, **purple** for flag-based resumes

**Click any node** to inspect its full content in the detail panel: contact, all messages with pauses and conditions, choices with their effects and destinations, and special fields like music or delays.

**Edit the structure directly from the graph:**
- **Right-click on the background** → create a new scene, choose its contact and target file
- **Drag from an output port to another node** → connects two scenes, writing `next` or `choices[].next` into the JSON automatically
- **Right-click on a node** → disconnect a specific outgoing link, or delete the scene entirely (all references to it are cleaned up across every file)

**Edit content directly from the detail panel:**
The detail panel is a full scene editor — no JSON file to open.

- **Messages**: edit each bubble's text, set a `requires_flag` condition, choose a pause, add effects
- **Choices**: edit the button text; set the player message as a single bubble or a sequence of consecutive bubbles — dedicated **+ msg** and **+ msgs [...]** creation buttons appear when no message is set, with an inline multi-bubble editor once one exists; assign a flag, set `requires_flag`, pick the next scene from a dropdown, add effects
- **Effects**: choose the operation (`set` / `add` / `sub` for variables, `rename` / `set_status` for contacts) from a dropdown, pick the target from a pre-populated list, enter the value — or choose `online` / `away` / `offline` / `network_issue` from a status dropdown
- **Triggers**: set `trigger_after_scene`, `resume_after_flag`, and `resume_after_delay` directly from dropdowns and text fields
- **Free input**: add a free-text prompt with a single button, set the variable name and placeholder inline — mutually exclusive with choices (the editor enforces this)

All dropdowns are populated from your actual project: scene IDs, flag names, contact IDs, and variable names are discovered automatically. Changes save when a field loses focus. For advanced features (structured `and`/`or` conditions, media, music, deferred corrections), the JSON remains the source of truth — the editor handles the common 90% without touching a file.

**Configure your cast without touching `story.json`:**
The **Contacts** button in the toolbar opens a dedicated panel where you can manage everything in `story.json`:
- Add, rename, or remove contacts — renaming an ID propagates the change across every dialogue file automatically
- Set each contact's display name, status, avatar, and whether they are the main contact
- Define pre-existing message histories for secondary contacts (time, direction, text)
- Set which contact the player sees first, and which scene plays on a new game

**Reformat button:** rewrites all dialogue files with the canonical key order without touching any content — useful after manual edits or when switching editors.

Every structural action writes directly to the JSON file and refreshes the graph instantly. Text edits save silently in place.

> The graph and the JSON files are always in sync — the graph is not a separate representation, it is a live view of your files.

---

### ⚙️ Player settings — out of the box
A fully functional settings menu is included with no setup required:

- **Language** — switches dialogue and UI language instantly
- **Volume** — master volume slider
- **Resolution** — from 480p to 4K
- **Display mode** — Windowed, Fullscreen Windowed (borderless), or Exclusive Fullscreen

Settings persist between sessions and are applied automatically on launch.

---

### 🎨 Fully customizable interface
- Theme system via `theme.json` — colors, typography, bubble sizing, typing speed
- No code changes needed to reskin the entire game
- Designed to adapt to different visual identities
- Animated main menu title with glitch effect — configurable via `title_glitch` in `theme.json`
- Main menu title driven by `story.json` — no code to touch when shipping a new story

---

### 💾 Automatic save system
- Story state is saved **after every player choice and every received message** — players never lose progress
- Full persistence: variables, flags, conversation history, contact names and statuses
- Main menu with New Game / Continue and in-game exit dialog (main menu / desktop / cancel)
- Save file is human-readable JSON

---

### 🛠 Authoring workflow
A complete game requires only:

```
story.json           ← contacts and starting scene
dialogues/*.json     ← your story scenes
assets/              ← images, audio and music (optional)
theme.json           ← visual style (optional)
```

No Godot editor knowledge required to write content.
No scripting, no nodes, no scenes to touch.

---

## 🧩 How it works

1. Define your characters in `story.json`
2. Write story scenes in JSON files
3. Drop the files into `/dialogues`
4. Add images or audio if needed
5. Run in Godot — the validator reports any issues immediately

That's it.

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

## 🧪 Perfect for

- Narrative-driven indie games
- Interactive fiction and digital stories
- Game jams — a full prototype in hours
- Character-focused drama and emotional narratives
- Sci-fi, mystery, horror, and experimental storytelling
- Writers and designers with no game development background

---

## 📦 What's included

- Full Godot 4.6 project — open and run immediately
- Complete messaging UI (typing indicators, media bubbles, contact panel)
- JSON narrative engine with conditions, variables, flags, effects, templates
- Multi-contact system with status indicators and contact avatars
- Background conversation and trigger system
- Pre-existing conversation histories and pending choices at game start
- Real-time delays — scenes that arrive minutes or hours later, persisted across sessions
- Scene music with looping, fade, and audio ducking
- Live message editing (correct, delete, or corrupted on arrival)
- Built-in story validator with in-game reporting
- Debug overlay (F9) — jump to any scene mid-play, inject flags and variables on the fly
- Auto-save system (saves after every story beat)
- Main menu (New Game / Continue)
- Player settings menu (language, volume, resolution, display mode)
- Localization system (per-language dialogue files + UI translation CSV)
- Theme system (`theme.json`) with animated glitch title (configurable)
- Playable demo scenario
- Bilingual authoring guide (EN + FR) with full syntax reference
- **Visual story graph + Contacts panel** — built-in Godot editor plugin: scene graph with full detail editing, and a dedicated Contacts panel to configure `story.json` (characters, histories, start scene) without touching a file

---

## 🚀 Why Lost Signal?

Most narrative tools fall into one of three categories:

- **Too technical** — requires programming to do anything meaningful
- **Too limited** — simple linear branching, no variables, no parallel threads
- **Too generic** — not designed around real-time communication as the core mechanic

**Lost Signal is built specifically for messaging-based narratives.**

The interface is not a skin over a traditional dialogue system. It is the system — with the timing, the interruptions, the multi-threaded pacing that make communication stories feel real.

---

## 🧠 Design philosophy

> Communication itself is the narrative system.

Messages are not just dialogue. They are:

- events
- interruptions
- contradictions
- delayed revelations
- evolving information streams

Lost Signal gives you the tools to use all of that.

---

## 📋 Before you start

Lost Signal is designed to be accessible to writers and designers — but a few things are worth knowing upfront.

**JSON is the authoring format.** You don't write code, but you do write structured text files. A basic familiarity with JSON syntax (curly braces, quotes, commas) will save you time. The built-in validator catches most mistakes, and any text editor with JSON highlighting makes the experience smoother.

**Linear stories are easy. Parallel stories take planning.** A single-contact story with branching choices is straightforward to build. Multi-contact narratives — where characters message you independently and interrupt each other — require thinking through the structure before you write. The tools are there; the design work is yours.

**The authoring guide is your reference, not a tutorial.** `docs/authoring.md` covers every field and every feature, but it assumes you're looking something up, not learning from scratch. Start with the demo scenario and modify it — that's the fastest way in.

---

## ⚠️ Requirements

- Godot 4.6
- No external dependencies or plugins