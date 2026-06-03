# 💬 Lost Signal — Real-Time Narrative Messaging Engine (Godot 4.6)

> Create interactive story games through a real-time messaging interface inspired by desktop chat applications like Discord and Teams.  
> **No coding required. Only JSON.**

---

## 🎮 What is Lost Signal?

**Lost Signal** is a narrative engine for Godot that lets you build interactive story-driven games where everything happens through a **real-time messaging interface**.

Characters communicate through a desktop chat system:
- multiple conversations at once  
- branching dialogue  
- media messages (images, audio)  
- real-time narrative events  

You don’t write code.  
You don’t modify the engine.  
You only write **JSON story files**.

---

## 🖥️ A desktop-first narrative experience

Unlike mobile texting games, Lost Signal is designed for **PC storytelling experiences** inspired by modern communication tools.

The interface is inspired by:
- Discord
- Slack
- Microsoft Teams

This enables richer narrative structures:
- parallel conversations
- group dynamics
- interruptions
- multi-threaded storytelling

---

## ✨ What you can create

Lost Signal is not limited to a single genre.

You can build:

### 💔 Relationship-driven stories
- friendships
- breakups
- emotional dialogue systems
- character-driven narratives

### 🧠 Psychological or experimental fiction
- unreliable messages
- shifting perspectives
- fragmented communication

### 🕵️ Thriller & mystery stories
- multi-character investigations
- conflicting narratives
- hidden information systems

### 🚀 Sci-fi communication stories
- remote survival messaging
- system-based communication (*Lifeline-style experiences*)

### 😨 Horror (optional)
- corrupted messages
- disappearing texts
- unstable contacts
- unsettling parallel conversations

---

## ⚡ Key Features

### 💬 Real-time messaging system
- Discord-style chat interface
- multiple active conversations
- typing simulation
- timestamps & message flow

---

### 🧠 Full narrative logic (JSON only)
- branching dialogue
- variables & conditions
- flags & story states
- dynamic story progression

---

### 🔀 Parallel storytelling system
- multiple scenes running simultaneously
- background conversations continue independently
- reactive narrative threads

---

### 📎 Media messaging
- 📷 images inside chat bubbles
- 🔊 audio messages with playback UI
- fully persistent in save system

---

### 🎨 Fully customizable interface
- theme system via `theme.json`
- colors, typography, spacing
- easy reskin for different game styles

---

### 💾 Built-in save system
- persistent story state
- variables & flags tracking
- conversation memory across sessions

---

### 🛠 No-code workflow

Create a full game using only:
story.json
dialogues/*.json
assets/

No scripting required.

---

## 🧩 How it works

1. Define characters in `story.json`
2. Write story scenes in JSON
3. Drop files into `/dialogues`
4. Add images or audio if needed
5. Run the game in Godot

That’s it.

---

## 📁 Example scene

```json
{
  "id": "intro",
  "messages_in": [
    { "text": "Are you there?", "time": "02:14" },
    { "text": "We need to talk.", "pause": "short" }
  ],
  "choices": [
    {
      "text": "Who is this?",
      "message": "Who are you?",
      "next": "scene_2",
      "effects": [
        { "var": "trust", "op": "add", "value": 1 }
      ]
    }
  ]
}
```

## 🧪 Perfect for

- narrative-driven indie games  
- interactive fiction projects  
- experimental storytelling  
- game jams (fast prototyping)  
- character-focused drama games  
- sci-fi / mystery / horror narratives  

---

## 📦 What’s included

- Full Godot 4.6 project  
- Messaging UI system (Discord-style)  
- JSON-based narrative engine  
- Example story scenario  
- Theme system  
- Save/load system  
- Documentation with examples  

---

## 🚀 Why this engine?

Most narrative tools fall into one of these categories:

- too technical (requires programming)  
- too limited (simple branching only)  
- too generic (not focused on real-time communication storytelling)  

**Lost Signal is designed specifically for real-time messaging narratives.**

It enables a unique form of storytelling where:

> The story happens through conversations that evolve while the player is reading them.

---

## 🧠 Design philosophy

Lost Signal is built around one idea:

> Communication itself is the narrative system.

Messages are not just dialogue — they are:

- events  
- systems  
- interruptions  
- contradictions  
- evolving information streams  

---

## ⚠️ Requirements

- Godot 4.6  
- No external dependencies  
