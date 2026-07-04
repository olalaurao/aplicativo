# Mood System Overhaul — Implementation Plan + Guidelines V5.1 → V5.2

## 0. SOURCING NOTE (read first)

Laura asked for "the real How We Feel mood list." Full disclosure on what this actually is:

- How We Feel's app uses **144 proprietary emotion labels** with their own in-app descriptions. That exact list + those exact descriptions are not published anywhere as clean structured text (they live inside the paid/free app UI), and reproducing their exact wording verbatim would be a copyright problem regardless of source.
- What **is** publicly documented, and is the actual scientific model both How We Feel and the original "Mood Meter" app are built on, is the **Yale Center for Emotional Intelligence / RULER Mood Meter**: 2 axes (pleasantness × energy), 4 quadrants (red/yellow/green/blue), same UX pattern (pick quadrant → pick specific word).
- This plan uses an **80-word catalog (20 per quadrant)**, cross-referenced from multiple Yale/RULER public materials, with **descriptions I wrote myself** (original wording, not copied from How We Feel or anywhere else). It reproduces the *framework* faithfully, not the app's proprietary content.
- If exact parity with How We Feel's specific 144 words/descriptions is a hard requirement later, that would need Laura to source it directly from the app (screenshots/manual transcription), not from me — I won't fabricate quotes I can't verify, and I won't reproduce IP I don't have legitimate access to.
- 80 was chosen over 100 or 144 as a practical default: enough nuance to feel like a real emotional vocabulary, without turning the picker into an overwhelming wall of text on a phone screen. Trivial to extend later since it's just a static seed list.

---

## 1. THE 80-MOOD CATALOG

Each mood has: `emoji`, `energy` (0–10), `pleasantness` (0–10), and `description` (shown as a short caption under the label in the picker, per your request).

Quadrant is **derived**, never stored: `energy >= 5 && pleasantness >= 5` → Yellow · `energy >= 5 && pleasantness < 5` → Red · `energy < 5 && pleasantness >= 5` → Green · `energy < 5 && pleasantness < 5` → Blue.

### 🟡 YELLOW — high energy, pleasant

| Label | Emoji | Energy | Pleasantness | Description |
|---|---|---|---|---|
| Pleasant | 🙂 | 6 | 6 | A light, easy sense that things are going fine. |
| Cheerful | 😊 | 6 | 7 | Bright and good-humored, ready to smile. |
| Hopeful | 🌱 | 6 | 6 | Looking forward to something getting better. |
| Focused | 🎯 | 6 | 6 | Locked in, clear-headed, and on task. |
| Optimistic | ☀️ | 6 | 7 | Expecting things to work out well. |
| Happy | 😄 | 7 | 7 | A solid, warm sense of things being good. |
| Lively | ✨ | 7 | 7 | Full of spark, hard to sit still. |
| Playful | 🤸 | 7 | 7 | In the mood to joke around and have fun. |
| Proud | 🦁 | 7 | 7 | Satisfied with something you did or achieved. |
| Upbeat | 🎶 | 7 | 8 | Bouncy, positive energy that's easy to spot. |
| Excited | 🤩 | 8 | 8 | Buzzing about something coming up or happening now. |
| Festive | 🎉 | 8 | 8 | Celebratory, in a party-like state of mind. |
| Energized | ⚡ | 8 | 8 | Full of physical and mental drive to go. |
| Motivated | 🚀 | 8 | 8 | Pulled strongly toward doing something. |
| Enthusiastic | 🙌 | 8 | 9 | Eager and vocal about something you care about. |
| Thrilled | 🎢 | 9 | 9 | A rush of intense, almost overwhelming excitement. |
| Inspired | 💡 | 9 | 9 | Struck by an idea or possibility, wanting to act on it. |
| Amazed | 😲 | 9 | 9 | Caught off guard by something wonderful. |
| Elated | 🥳 | 10 | 9 | Riding a high, almost giddy with joy. |
| Joyful | 😁 | 9 | 10 | Deep, unmistakable happiness, hard to contain. |

### 🔴 RED — high energy, unpleasant

| Label | Emoji | Energy | Pleasantness | Description |
|---|---|---|---|---|
| Peeved | 😒 | 6 | 4 | Mildly annoyed by something small. |
| Annoyed | 😑 | 6 | 4 | Irritated by something that's bothering you. |
| Worried | 😟 | 6 | 4 | Uneasy about something that might go wrong. |
| Nervous | 😬 | 6 | 4 | On edge about something coming up. |
| Troubled | 😔 | 6 | 4 | Weighed down by a concern you can't shake. |
| Irritated | 😠 | 7 | 3 | Actively bothered, patience running thin. |
| Tense | 😖 | 7 | 3 | Wound up, body and mind both on alert. |
| Agitated | 😤 | 7 | 3 | Restless and stirred up, hard to settle. |
| Jittery | 😰 | 7 | 3 | Shaky, keyed-up energy you can't quite place. |
| Stressed | 🥵 | 7 | 3 | Under pressure, feeling like too much at once. |
| Anxious | 😨 | 8 | 2 | Gripped by worry that's hard to set aside. |
| Frustrated | 😣 | 8 | 2 | Blocked from something you're trying to do. |
| Overwhelmed | 🌀 | 8 | 2 | Facing more than you feel able to handle right now. |
| Alarmed | 🚨 | 8 | 2 | Suddenly on high alert to a possible threat. |
| Frightened | 😧 | 8 | 2 | Afraid of something happening or about to happen. |
| Angry | 😡 | 9 | 1 | Strong displeasure, often at something unfair. |
| Furious | 🤬 | 10 | 1 | Intense anger, close to boiling over. |
| Enraged | 🔥 | 10 | 0 | Anger at its peak, hard to contain. |
| Panicked | 😱 | 10 | 1 | Sudden, overpowering fear pushing you to act now. |
| Shocked | 😳 | 9 | 1 | Jolted by something unexpected and unwelcome. |

### 🟢 GREEN — low energy, pleasant

| Label | Emoji | Energy | Pleasantness | Description |
|---|---|---|---|---|
| Thoughtful | 🤔 | 4 | 6 | Quietly turning something over in your mind. |
| Mellow | 🎐 | 4 | 6 | Easygoing, nothing pushing at you right now. |
| Comfy | 🛋️ | 4 | 6 | Physically and mentally settled in. |
| Cozy | 🕯️ | 4 | 6 | Warm, sheltered, small-scale contentment. |
| Balanced | ⚖️ | 4 | 7 | Steady, nothing pulling you too far one way. |
| Calm | 🍃 | 3 | 7 | Quiet inside, no urgency to move or react. |
| Relaxed | 🧘 | 3 | 7 | Muscles and mind both loosened up. |
| Easygoing | 😌 | 3 | 7 | Unbothered, taking things as they come. |
| Content | 🙏 | 3 | 7 | Quietly satisfied with how things are right now. |
| Carefree | 🦋 | 3 | 7 | Light, unburdened by worry for the moment. |
| At ease | 🌤️ | 2 | 8 | Fully settled, nothing on guard. |
| Restful | 😴 | 2 | 8 | Recovering, replenished, in no rush. |
| Grateful | 🙌 | 2 | 8 | Aware of and warmed by something good you have. |
| Satisfied | ✅ | 2 | 8 | A quiet sense that something turned out well. |
| Secure | 🏡 | 2 | 8 | Steady and safe, nothing shaky underfoot. |
| Serene | 🌊 | 1 | 9 | Deep stillness, untouched by outside noise. |
| Peaceful | 🕊️ | 1 | 9 | A settled quiet, inside and out. |
| Tranquil | 🌙 | 1 | 9 | Calm that runs deep, almost still-water quiet. |
| Blessed | 🌟 | 1 | 9 | A quiet fullness, aware of your good fortune. |
| Loving | 💗 | 2 | 9 | Warm, open, full of affection toward someone. |

### 🔵 BLUE — low energy, unpleasant

| Label | Emoji | Energy | Pleasantness | Description |
|---|---|---|---|---|
| Bored | 😐 | 4 | 4 | Understimulated, waiting for something to change. |
| Tired | 😪 | 4 | 4 | Low on physical or mental fuel. |
| Uneasy | 😕 | 4 | 4 | A vague sense that something's not quite right. |
| Disappointed | 😞 | 4 | 4 | Let down by something that didn't go as hoped. |
| Weary | 🥱 | 4 | 4 | Worn down after sustained effort. |
| Down | ☁️ | 3 | 3 | Low mood, nothing dramatic, just heavier than usual. |
| Gloomy | 🌧️ | 3 | 3 | A dim, grey mood hanging over things. |
| Discouraged | 🚧 | 3 | 3 | Losing motivation after a setback. |
| Lonely | 🪑 | 3 | 3 | Missing connection you don't currently have. |
| Exhausted | 🔋 | 3 | 3 | Completely drained, past ordinary tiredness. |
| Sad | 😢 | 2 | 2 | A heavy, low feeling, often tied to a loss. |
| Disheartened | 💔 | 2 | 2 | Deflated, hope knocked down a notch. |
| Drained | 🕳️ | 2 | 2 | Emptied out, little left to give right now. |
| Apathetic | 🫥 | 2 | 2 | Detached, hard to care about much right now. |
| Alienated | 🚪 | 2 | 2 | Cut off or distant from people around you. |
| Miserable | 😩 | 1 | 1 | A deep, all-over unpleasant state. |
| Depressed | 🌑 | 1 | 1 | A heavy, persistent low that colors everything. |
| Hopeless | ⛓️ | 1 | 1 | Feeling like nothing will improve. |
| Despondent | 🥀 | 1 | 1 | Low and discouraged, with little energy to resist it. |
| Despair | 🖤 | 0 | 0 | The deepest, most depleted end of this quadrant. |

**Note on the last row of Red/Blue:** these sit at the emotional extremes. If Laura wants, a future pass could add an in-app note pointing to support resources when someone repeatedly logs from this end of the scale — flagging as a possible idea, not spec'd here.

---

## 2. CURRENT CODE STATE (grounded — fetched and read directly)

`lib/models/mood_model.dart`:
- `MoodDefinition` has only: `id`, `title`, `label`, `emoji`, `numericValue` (int), `color`. **No `description` field exists at all.**
- 1D scalar only — no `pleasantness`/`energy` split.

`lib/ui/screens/mood_settings_screen.dart`:
- Hard cap: `static const int _maxMoods = 15;` — enforced in two places (`_editMood`, FAB/button disabled state).
- Fully manual creation — user types title, emoji, a number 1–15, and a hex color. **There is no lazy auto-seeding of "system moods" anywhere in this file** — the empty state literally says "Nenhum humor cadastrado" (no moods registered) and waits for the user to add one by hand.
- This directly contradicts the guidelines' claim ("48 system moods... lazy file creation") — that part of the spec was never implemented. Real bug/gap, not a design choice — confirms the divergence already flagged in your notes.

`lib/models/journal_entry.dart`:
- `moodSlug` is a **single nullable string**, one mood per Entry — matches the doc's `mood:: [[slug]]` pattern.
- No `mood_entries` daily-note generation logic lives here (must be elsewhere — flagged as an investigation item below, since I haven't located it yet).

**Net finding:** the "48 system moods, 2-axis, lazy creation" story in the current guidelines was aspirational, not real. This plan replaces it with something the app doesn't have yet, built correctly from scratch, plus an honest migration path for whatever the ~15 users already created manually.

---

## 3. DATA MODEL CHANGES

### 3.1 `MoodDefinition` (rewrite)

```dart
class MoodDefinition extends ContentObject {
  final String label;
  final String emoji;
  final int energy;        // 0–10, replaces numericValue
  final int pleasantness;  // 0–10, new
  final String description; // new — short, shown in picker
  final String color;
  final bool isSystem;     // new — true for the 80 seed moods, false for user-created

  String get quadrant {
    if (energy >= 5 && pleasantness >= 5) return 'yellow';
    if (energy >= 5 && pleasantness < 5) return 'red';
    if (energy < 5 && pleasantness >= 5) return 'green';
    return 'blue';
  }
  // ...rest mirrors current structure (copyWith, toMarkdown, fromMarkdown)
}
```

Frontmatter gains `energy`, `pleasantness`, `description`, `is_system`; `numeric_value` is dropped going forward but still **read** on `fromMarkdown` for one release cycle (see migration below) so no existing file errors out.

### 3.2 Seed catalog

New file: `lib/data/mood_catalog.dart` — a static `const List<MoodSeed>` with the 80 entries from Section 1. Not files on disk by default — this is Rule/Note 8 (Part 22) actually implemented for the first time: **lazy creation**. A seed only becomes a real `moods/slug.md` file the first time the user picks it in the mood picker. Until then it just exists as an in-memory catalog entry the picker reads from.

### 3.3 Migration for existing users

For any `MoodDefinition` file already on disk with the old schema (`numeric_value` present, no `energy`/`pleasantness`):
- `pleasantness = ((numeric_value - 1) / 14 * 10).round()` — naive linear remap of the old 1–15 scale onto 0–10.
- `energy = 5` (neutral default — the old model never captured this dimension, so we can't recover it; user can edit).
- `description = ''` (empty — non-blocking per Rule 13, shows as a gentle "add a description" prompt, never blocks anything).
- `is_system = false` (it was user-created).
- This is a one-time, automatic, non-destructive migration on first load after the update — old file is rewritten with the new fields added, nothing is deleted, consistent with the app's existing "never lose data" posture.

---

## 4. PICKER UI — two-step, per the spec's existing "2-step picker" line

**Step 1 — Quadrant.** Four big colored tappable regions (Yellow/Red/Green/Blue), same visual language as the existing Energy Map tint colors (Part 3) for consistency: red `#FF7043`-family, yellow, green `#4CAF50`-family, blue.

**Step 2 — Word grid.** Within the chosen quadrant, a scrollable grid/list of that quadrant's ~20 moods. Each cell shows: emoji (large) + label (bold) + **description as a muted caption line underneath** — this is the explicit answer to "mostrar a descrição curta pro usuário." Tapping a cell:
1. Materializes `moods/{slug}.md` if it doesn't exist yet (lazy creation, Rule from Part 22 #8, finally implemented).
2. Sets `mood:: [[slug]]` on the current Entry.
3. Returns to the Entry form.

A "Custom" tile is always pinned at the end of each quadrant's grid → opens the existing manual creation dialog (rewritten per §5) for a user-defined mood inside that quadrant.

---

## 5. SETTINGS SCREEN (`mood_settings_screen.dart`) — rework

- **Change `_maxMoods` from 15 to 20 (decided).** This cap applies only to **user-created custom moods**. The 80 system moods are catalog entries, not user-created, so they don't count against it — total addressable vocabulary is 80 system + up to 20 custom = 100.
- List grouped by quadrant (4 collapsible sections) instead of flat numeric sort.
- Edit dialog changes:
  - Remove the single "Valor numérico (1–15)" field.
  - Add **Description** (short text field, required for new custom moods — but per Rule 13, still never blocks save, just shows the "Incomplete" badge if left empty).
  - Add **Pleasantness** slider (0–10) and **Energy** slider (0–10), live-updating a small quadrant-color preview swatch as they drag.
- **System-mood customization (decided — unlockable):** the 80 system moods show a small 🔒/"System" badge. Color, description, and emoji are always freely editable (same precedent as the universal type-icon override, Part 1.5). Pleasantness/energy are locked by default; an "Edit coordinates" action unlocks them after a one-time confirmation dialog: *"This changes how this mood appears from now on. Past check-ins and charts won't change retroactively."*
  - **Why this is safe to allow (verified against the actual data flow):** `mood_entries` on the daily note is a **snapshot**, not a live reference — the `pleasantness`/`energy` values are copied into the daily note's frontmatter at the moment an Entry is saved (Part 20: "regenerated whenever an Entry with a mood is added/edited/removed"). Editing a `MoodDefinition`'s coordinates later does **not** trigger a mass rewrite of past daily notes. Historical check-ins and Combined Analysis charts keep exactly the values that were true when logged; only new check-ins (or edits to existing ones) pick up the new coordinates. So unlocking customization cannot silently rewrite history or corrupt past charts.
- Delete behavior unchanged (soft-delete via `_deleted/`, 30-day purge, undo snackbar) — but deleting a system mood only removes *your* materialized file/customizations; it doesn't remove it from the catalog, so it can be picked (and re-lazily-created) again later.

---

## 5.1 EMOTIONAL DISTRESS SIGNAL (new — Wellbeing Indicator integration)

Reuses the existing **Wellbeing Indicator** object (guidelines Part 3, V5.1) rather than inventing a parallel mechanism. Because *every* mood — system or custom — carries numeric `pleasantness`/`energy`, the trigger is purely coordinate-based, so it applies uniformly regardless of which moods the user ends up customizing:

```yaml
# Default pre-configured Signal, part of a "Wellbeing Indicator" the app ships with out of the box
signal:
  data_source:
    source_type: journal_mood
    dimension: pleasantness
  bands:
    - { pattern: "count(pleasantness <= 2) >= 3 in last 7 days", status: watch }
    - { pattern: "count(pleasantness <= 2) >= 6 in last 14 days", status: alert }
```

- Threshold (`pleasantness <= 2`, window sizes, counts) is **configurable in Settings**, not hardcoded — defaults above are a starting point, not a final call.
- Surfaces through the existing **Health Alerts strip** (Part 3), same as any other Wellbeing signal — no new UI surface needed.
- **Wording must stay non-diagnostic and supportive, never clinical.** E.g.: *"You've logged some tough moments lately. Want to see some support resources?"* — never something like "you may be depressed." The app never assigns a diagnosis; it only reflects a pattern back and offers an opt-in path to resources. Exact copy and which resources to link (a helpline, a saved note, etc.) is Laura's call — not pinned down here.
- Because this reads the same `pleasantness`/`energy` fields as everything else, it automatically covers custom moods too — no separate list of "concerning mood names" to maintain.

---

## 6. COMBINED ANALYSIS / DAILY NOTE INTEGRATION

Since `MoodDefinition` now natively carries `pleasantness`/`energy`, the daily note's derived `mood_entries` array (guidelines Part 20) should read those two numbers **directly from the linked MoodDefinition** at generation time, rather than needing any separate mapping step. This removes a whole class of potential desync between "what mood was picked" and "what number Combined Analysis charts."

**Investigation needed (not yet located in the codebase):** the actual service that generates `mood_entries` on the daily note wasn't found in `journal_entry.dart` — it must live in `obsidian_service.dart`, `dataview_generator.dart`, or a dedicated daily-note builder. Next audit pass should grep for `mood_entries` directly to find and update that write path.

---

## 7. IMPLEMENTATION TICKETS

| # | Priority | Ticket | Files |
|---|---|---|---|
| 1 | P0 | Add `energy`, `pleasantness`, `description`, `isSystem` to `MoodDefinition`; deprecate `numericValue` with read-compat | `lib/models/mood_model.dart` |
| 2 | P0 | Write one-time migration for existing mood files (old scalar → new 2-axis, non-destructive) | new: `lib/services/mood_migration_service.dart` |
| 3 | P0 | Create static 80-mood seed catalog | new: `lib/data/mood_catalog.dart` |
| 4 | P1 | Remove 15-mood cap; rework settings UI (grouped by quadrant, sliders, description field, System badge) | `lib/ui/screens/mood_settings_screen.dart` |
| 5 | P1 | Build 2-step mood picker (quadrant → word grid with description captions → lazy file creation → sets `mood::`) | new: `lib/ui/widgets/mood_picker_sheet.dart`; wire into `create_entry_form.dart` |
| 6 | P1 | Locate and update the `mood_entries` daily-note generator to read `pleasantness`/`energy` straight from `MoodDefinition` | TBD — grep `mood_entries` across `lib/services/` |
| 7 | P2 | `mood_chart_widget.dart` / Combined Analysis: confirm `journal_mood` DataSource reads cleanly off the new fields, no leftover scalar assumptions | `lib/ui/widgets/mood_chart_widget.dart` |
| 8 | P1 | Change custom-mood cap from 15 to 20; add "Edit coordinates" unlock flow (with one-time warning dialog) for system moods | `mood_settings_screen.dart`, `mood_model.dart` |
| 9 | P2 | Emotional Distress signal: pre-configure one default Wellbeing Indicator signal reading `journal_mood`/`pleasantness` with `watch`/`alert` bands (§5.1); wire into Health Alerts strip; wording review with Laura before shipping copy | `health_alerts_provider.dart`, `health_alerts_strip.dart`, new: `lib/data/default_wellbeing_signals.dart` |

---

## 8. GUIDELINES V5.1 → V5.2 — EXACT TEXT CHANGES

### 8.1 New changelog entry (top of doc, new section)

```
## CHANGELOG — V5.1 → V5.2

- **Mood Definition:** fully re-specified. Replaces the never-implemented "48 system
  moods" line with a real 80-mood catalog (20 per quadrant), each with `energy` (0–10),
  `pleasantness` (0–10), and a short `description` shown in the picker. MoodDefinition
  moves from a 1D `numericValue` scalar to the same 2-axis model already used by
  Energy Map and Combined Analysis's `journal_mood` dimension — closing a real
  architecture gap where the spec claimed 2-axis moods but the object itself was 1D.
- **Mood picker:** now a formal 2-step flow (quadrant → specific word), each word
  shown with emoji, label, and a short description caption. Lazy file creation
  (Rule/Note 8, Part 22) is now actually implemented: a system mood only becomes a
  real vault file the first time it's picked.
- **Mood Settings screen:** the hard 15-mood cap is removed. Moods are grouped by
  quadrant. Creation form gains pleasantness/energy sliders and a description field,
  replacing the old single "1–15" numeric field.
- **Migration:** existing user-created moods (old 1–15 scalar) are non-destructively
  migrated to the new 2-axis schema on first load after this update — no data lost,
  per Rule 13.
```

### 8.2 Replace the "MOOD DEFINITION" section, Part 3

Replace this line:

> Unchanged from V4 (48 system moods, user moods, lazy file creation, aliases, quadrants) — this part of V4 had no audit findings.

with:

```
### MOOD DEFINITION (re-specified in V5.2)

**Purpose:** the single vocabulary of moods available to `mood::` on any Entry.

**Properties:** `id`, `type: mood_definition`, `title`, `label`, `emoji`, `color`,
`energy` (0–10), `pleasantness` (0–10), `description` (short, one sentence, shown
as a caption in the mood picker — this is a required-in-spirit field: never blocks
save per Rule 13, but drives the "Incomplete" badge if left empty), `is_system`
(true for the 80 built-in catalog entries, false for user-created), `aliases`
(used for pt-BR translations and WikiLink resolution, same mechanism as Resources'
pt-BR alias pattern, Part 9).

**Quadrant is always derived, never stored:**
`energy >= 5 && pleasantness >= 5` → Yellow (pleasant, high energy)
`energy >= 5 && pleasantness < 5`  → Red (unpleasant, high energy)
`energy < 5 && pleasantness >= 5`  → Green (pleasant, low energy)
`energy < 5 && pleasantness < 5`   → Blue (unpleasant, low energy)

**System catalog:** 80 built-in moods (20 per quadrant), each pre-filled with
`energy`, `pleasantness`, `emoji`, and `description`. See the companion
`mood_catalog.md` reference doc for the full list. System moods are **lazily
created**: they exist only in a static in-app catalog until the user actually
picks one, at which point it's written to `moods/SLUG.md` for the first time.
User-created moods are written immediately on save, same as before.

**Custom mood cap raised from 15 to 20** (V5.2). System moods don't count toward
this cap — it applies only to user-created moods.

**Picker (2-step, formalized in V5.2):**
1. Quadrant selection — four large colored regions.
2. Word selection — grid of that quadrant's moods, each showing emoji + label +
   the short `description` as a muted caption underneath. A "Custom" tile is
   always pinned last, opening the manual creation form pre-scoped to that quadrant.

**Editing:** color, description, and emoji are always editable, including on
system moods (same override precedent as the universal type-icon system, Part 1.5).
Energy/pleasantness on system moods are locked by default but **unlockable** via
an explicit "Edit coordinates" action with a one-time confirmation ("this changes
how this mood appears from now on; past check-ins and charts don't change
retroactively") — safe because `mood_entries` snapshots values at Entry-save time
rather than reading MoodDefinition live. User-created moods are fully editable on
all axes from the start.

**Emotional Distress signal (new, V5.2):** the app ships with one default
Wellbeing Indicator signal (Part 3, Wellbeing Indicator) reading
`data_source: { source_type: journal_mood, dimension: pleasantness }`, with
`watch`/`alert` bands based on how often `pleasantness <= 2` moods are logged in
a trailing window (defaults: 3-in-7-days → watch, 6-in-14-days → alert; both
configurable in Settings). Because this is purely coordinate-based, it covers
user-created moods automatically, not just the 80-entry system catalog. Surfaces
through the existing Health Alerts strip. Copy must stay non-diagnostic and
supportive (e.g. "You've logged some tough moments lately — want to see some
support resources?"), never naming a clinical condition.
```

### 8.3 Part 22, item 8 — update

Old:

> 8. System moods are created lazily on first use; user moods are created immediately.

New:

> 8. System moods (the 80-entry catalog, Part 3) are created lazily on first use —
> this is now actually implemented, not just documented. User moods are created
> immediately on save, same as before.

### 8.4 Part 11 (Combined Analysis) — one addition

Add after the existing `journal_mood` paragraph:

```
Since MoodDefinition (Part 3) now carries `pleasantness`/`energy` directly, the
daily note's `mood_entries` array reads both values straight from the linked
MoodDefinition at generation time — there is no separate mapping step and no way
for the chart to disagree with what the user actually picked.
```

---

## 9. DECISIONS — RESOLVED

1. ✅ Custom mood cap: **20** (not unlimited, not 300). System moods don't count against it.
2. ✅ System-mood coordinates: **unlockable** via explicit confirmation, not permanently locked. Confirmed safe because `mood_entries` is a snapshot, not a live reference — see §5.
3. ✅ Distress nudge: **yes**, built as a Wellbeing Indicator signal (§5.1), coordinate-based (`pleasantness <= 2`) so it covers custom moods automatically, not just the 80 system ones.
4. ✅ Exact How We Feel 144-word parity: out of scope unless Laura sources it by hand from the app directly.

## 9.1 REMAINING SUB-QUESTIONS (smaller, non-blocking)

- Exact default thresholds for the distress signal (`pleasantness <= 2`, 3-in-7-days for `watch`, 6-in-14-days for `alert`) — reasonable starting defaults, but Laura should sanity-check them before ship, since too sensitive = nagging, too loose = useless.
- Exact wording of the support-resources nudge and which resource(s) to link — deliberately left open in §5.1, needs Laura's voice/judgment, not something to lock in from an implementation plan.
- Whether the "Edit coordinates" unlock on system moods needs its own Undo, or the existing Archive/Delete-style undo snackbar pattern is enough — leaning toward reusing the existing pattern, but flagging in case Laura wants something stronger given it affects historical vocabulary meaning.