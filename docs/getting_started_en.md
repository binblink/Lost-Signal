# Lost Signal — Getting Started

This guide takes you from opening the project to your first dialogue running in the game. It doesn't replace the [Authoring Guide](authoring_en.md) or the [Story Editor](story_editor_en.md) docs — it shows you the steps in order.

---

## Requirements

- **Godot 4.6** or higher ([godotengine.org](https://godotengine.org))
- No GDScript knowledge needed — your story lives entirely in JSON files

---

## Step 1 — Open the project

1. Launch Godot
2. In the project manager, click **Import** and select the project folder
3. Click **Edit** to open it in the editor

---

## Step 2 — Run the demo

Press **F5** (or the ▶ button at the top right).

The *Maeve* demo opens: go through a few exchanges to see what the engine can do — animated bubbles, multiple choices, secondary contact, image in a bubble.

---

## Step 3 — Enable the Story Editor

1. **Project → Project Settings → Plugins**
2. Enable **Story Editor**
3. A **Story Editor** tab appears at the bottom of the editor (next to the Output console)

Click it. You'll see the graph of all the demo scenes. Click a node to see its content in the right panel.

> Take a few minutes to explore `acte1.json` from the graph — it's your reference model.

---

## Step 4 — Create your contact

In the Story Editor, click **Contacts** (top bar).

The Contacts panel lets you configure `story.json` without opening the file:

1. Delete or rename the existing contact to fit your story
2. Set an **ID** (e.g. `emma`), a **display name**, a **status** (`online`, `away`, `offline`, `network_issue`)
3. Check **Main contact** — this is the character the player talks to from the start
4. Click **Save**

---

## Step 5 — Create your first dialogue file

1. In `dialogues/`, create a new `.json` file (e.g. `my_story.json`)
2. Paste the minimal structure below:

```json
{
  "scenes": [
    {
      "id": "intro",
      "contact_id": "emma",
      "messages_in": [
        { "text": "Hey there!", "out": false }
      ],
      "choices": [
        { "text": "Hi!", "next": null }
      ]
    }
  ]
}
```

> Replace `emma` with the ID of the contact you created in step 4.

---

## Step 6 — Set the starting scene

In the Contacts panel, **Start scene** field: type `intro` (the ID of your first scene).

Or directly in `story.json`: `"start_scene": "intro"`.

---

## Step 7 — Test

Press **F5**.

If `story.json` or your JSON file has an error, a validation window appears with details. Fix and relaunch.

If everything is correct, your first dialogue appears.

---

## Step 8 — Build from the Story Editor

Once the project runs, work primarily from the Story Editor:

- **Right-click on the graph background** → create a new scene
- **Drag an output port to an input port** → connect two scenes (`next`)
- **Click a node** → edit text, pauses, choices, effects in the right panel
- **F9 in-game** → debug tool: jump to any scene instantly without replaying from the start

---

## Going further

- **[Authoring Guide](authoring_en.md)** — all JSON fields, conditions, effects, variables, triggers, timed messages
- **[Story Editor](story_editor_en.md)** — full plugin reference
- **`acte1.json`** — the demo is your best example: every engine feature is illustrated there
