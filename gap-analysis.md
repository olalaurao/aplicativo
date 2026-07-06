# Citrine — New Feature Spec: Routine Alignment & Focus Relay
**Source inspiration:** Aligned Schedule Tracker (prismtree.com) + ToDoD: ToDo List + Focus Timer (App Store)
**Status:** Draft for product decision → ready for AI-implementation once approved
**Date:** 2026-07-05

---

## 0. How to read this document

Sections 1–2 are pure competitive analysis (what the two apps actually do, UI/UX-level).
Section 3 checks each idea against what Citrine already has, so we don't rebuild things that exist.
Section 4 is the actual new spec: two features worth building, written as canonical product decisions, data model changes, and UI flows — the same format as `guidelines_v5.md`.
Section 5 is a prioritized backlog with effort estimates.

---

## 1. Aligned Schedule Tracker — what it actually is

**Core concept:** not a to-do app, not a habit tracker. It tracks the *gap between planned time and real time* for recurring daily activities (sleep, meals, work blocks, workouts). The entire product is built around one metric: **drift**.

**UI/UX flow (3 steps):**
1. **Plan your ideal routine** — user defines activities with a target time + a *flexibility window* (e.g. ±10–15 min). No rigid templates; user picks their own day-start hour.
2. **Log what actually happens** — one tap to record the real time an activity occurred, logged live rather than reconstructed from memory.
3. **See your patterns** — weekly trend view, monthly "drift map," quarterly insights. Surfaces things like "Wednesdays are your worst day" or "drift always follows a late meeting."

**Key mechanics worth stealing:**
- **Flexibility window per activity**: a buffer (e.g. 10–15 min) inside which "late" still counts as "on time." This is explicitly designed so small delays don't punish honest logging — an anti-shame design choice.
- **Custom day start**: user chooses what hour their day begins (5am, 9am, noon), so activity ordering respects that instead of a hard midnight cutoff. Explicitly framed as helping night owls / shift workers.
- **Alignment states**: each activity/day gets a qualitative state, not just a number — "aligned," "drifting," "getting closer," "holding steady." This is a deliberate framing choice: state language over raw minutes, to avoid a punitive score.
- **Planned vs. Real, always paired**: every screen shows both values side by side — this is the actual value proposition, distinct from both habit trackers (yes/no only) and to-do apps (plan only, no reality check).
- **Weekday vs weekend drift pattern** and "hardest activity to keep on time" are explicitly called out.
- **Free tier**: 5 activities, 7-day insights, 3 CSV exports. Paid tier: unlimited activities/insights, iCloud sync, unlimited export. (Not relevant to Citrine — no monetization — but confirms this app treats logging as its central value, with insights as the upsell.)

**What it deliberately is NOT:** no AI, no natural language input, no gamification, no social features, no account. Positioned as privacy-first, fully offline, minimal.

---

## 2. ToDoD (ToDo List + Focus Timer) — what it actually is

**Core concept:** a task manager wrapped around an "AI Mate" persona. Two pillars: (a) low-friction capture via AI, (b) a step-sequenced focus timer called "Relay."

**UI/UX flow:**
- **Smart capture**: voice or text input → AI extracts time, reminder, and category automatically ("Just say it. I'll take care of it."). No manual field-filling for the common case. **Note:** in ToDoD this runs on an LLM API call per capture — a recurring per-use cost. This mechanic is **explicitly excluded** from this spec for that reason; see Section 3 for why Citrine's existing regex-based parser already covers the same use case at zero marginal cost.
- **Focus Relay**: not a single Pomodoro block, but a *chain* of timed steps for one task — e.g. "research (10m) → draft (20m) → review (5m)" run back-to-back without the user having to restart a timer for each sub-step.
- **Calendar view & schedule management**, task insights/activity reports, smart alerts/timers, Lock Screen task view, home-screen widgets for both the task list and the Relay timer.
- **"Emotional companion" framing**: AI Mate "characters" with personalities — explicitly marketed as a motivation coach, not just a tool. (This is a monetized gimmick — Lifetime/Pro IAP — not a mechanic Citrine needs to copy.)

**Key mechanics worth stealing:**
- **Relay = chained timers**, each step pre-defined with its own duration, auto-advancing to the next step, one running total for the parent task. This is meaningfully different from Citrine's current flat Pomodoro loop (work → break → work).
- **Task insights/activity reports** — retrospective view of where time actually went, similar spirit to Aligned's drift maps but scoped to tasks/focus time rather than routine timing.
- Everything else (AI voice capture, calendar sync, widgets, Lock Screen view) **already exists in Citrine** in some form (see Section 3) — the "AI Mate" personality layer is the only genuinely new UX idea, and it's a tone/branding choice rather than a technical feature; it's flagged in Section 5 as optional/low-priority rather than spec'd in detail.

---

## 3. Cross-check against what Citrine already has

Before proposing anything new, confirming actual current state from source (not assumptions):

| Idea | Already in Citrine? | Evidence |
|---|---|---|
| Natural-language task capture (time/priority/recurrence from free text) | **Yes — and it's free** | `nlp_task_parser.dart` already parses priority, dates, scheduled time, and recurrence rules from raw text (PT + EN patterns) using plain regex, entirely on-device. No LLM call, no API key, no per-use cost — unlike ToDoD's voice/AI capture. **This is the reason voice/AI capture is not proposed anywhere in this spec: it would add a recurring cost for a capability Citrine already has for free.** |
| Recurring schedules with rich repeat types | **Yes, and richer than Aligned's** | `scheduler.dart` supports 14 repeat types including `daysAfterReferenceField`, `linkedItemAppears`, `firstBusinessDayOfMonth` — well beyond Aligned's simple daily-time model |
| Reminders with custom timing, sound, snooze, popup/alarm type | **Yes** | `reminder_config.dart` — `minutesBefore`, `daysBefore`, `timeOfDay`, snooze, alarm type |
| Pomodoro / focus timer with work-break cycling, history logging | **Yes** | `pomodoro_provider.dart`, `pomodoro_session.dart` — includes retroactive logging (`occurredAt` vs `date`, per V5 F2.18) |
| Home-screen widgets (tasks, calendar, pomodoro, quick-add, checklist) | **Yes** | `widget_service.dart` — 7 distinct Android widget providers already wired |
| Habit tracking with boolean/numeric/mood/duration inputs, Pact mode | **Yes, and richer than a yes/no habit tracker** | `habit_model.dart` — `HabitInputType`, `HabitMode.pact` with `PactOutcome` (persist/pause/pivot) is already more sophisticated than Aligned's binary logging |
| Mood tracking | **Yes, mid-redesign** | Current 1D scalar model being replaced by the 2-axis Yale RULER model per `mood_system_v5.2_implementation_plan.md` |

**What is genuinely absent:**
1. **Planned-time vs. real-time drift tracking** for recurring daily activities, with a flexibility window and qualitative alignment states. Citrine's Scheduler answers "when should this repeat," and Habit answers "did you do it," but nothing currently answers "*how close to your intended time* did you actually do it, and is that gap trending in one direction." This is Aligned's entire product and it does not overlap with Habit, Task, or Scheduler as they exist today.
2. **Custom day-start hour** as a global setting affecting how a day's timeline is ordered/displayed. Citrine's daily notes are calendar-day-based; there's no user-configurable "day starts at X" concept in the settings/vault provider layer reviewed.
3. **Chained multi-step focus timer ("Relay")**. Citrine's Pomodoro is a single work/break loop; there is no concept of a task-defined sequence of differently-labeled, differently-timed steps that auto-advance.
4. **Weekly/monthly/quarterly pattern surfacing phrased as *insight sentences*** (e.g. "Wednesdays are your worst day," "drift always follows a late meeting") rather than raw charts. Citrine has `statistics_screen.dart`, `analysis_calendar.dart`, and the Combined Analysis system, which likely already produce charts — worth auditing before building new UI, but the *insight-sentence* framing itself (plain-language pattern callouts, not just charts) is worth adding regardless of what chart infra exists.

Everything else in both apps (AI capture, calendar sync, widgets, lock screen, personality-driven copy) is either already present or is a branding/tone choice rather than a mechanic — not worth spec'ing as a feature.

---

## 4. Proposed new features

### 4.1 Feature: Routine Alignment (Planned vs. Real drift tracking)

**Product decision:** This is a **new lens on existing Habits and Tasks with a scheduled time**, not a new top-level object type. Any Habit or Task that has a specific planned time of day (not just a date) becomes "alignment-trackable." This avoids creating a fifth overlapping recurrence/tracking concept alongside Scheduler, Habit, and Task.

**Data model changes:**

- **`HabitModel` / `Task`**: add optional fields
  - `plannedTimeOfDay` (`TimeOfDay?`) — when the activity is meant to happen. Already conceptually adjacent to `scheduledTime` produced by `NlpTaskParser`; reuse that field on Task rather than duplicating it.
  - `flexibilityWindowMinutes` (`int?`, default `null` = alignment tracking off for this item). Explicit opt-in per item — most tasks/habits should NOT show drift UI; this is only for the subset the user cares about timing-wise (sleep, meals, work-start, etc.).
- **New lightweight record, not a new ContentObject**: `AlignmentLogEntry`
  ```
  {
    itemId: string,           // Task or Habit id
    date: string (yyyy-mm-dd),
    plannedTime: string (HH:mm),
    actualTime: string (HH:mm),   // logged at tap-time, never reconstructed
    deltaMinutes: int,             // actual - planned, signed
    state: enum { early, aligned, drifting, missed }
  }
  ```
  Stored as a snapshot on the daily note, same pattern as `mood_entries` and `PomodoroSession` — **never parsed back as a source of truth for the plan itself**, consistent with Citrine's firm rule that daily-note bodies are derived, not re-parsed. The plan (planned time + flexibility window) lives on the Habit/Task object; only the log entries live on the daily note.

**Alignment state calculation** (per entry):
- `|deltaMinutes| <= flexibilityWindowMinutes` → `aligned`
- `flexibilityWindowMinutes < delta <= flexibilityWindowMinutes * 3` (late) or symmetric early → `drifting`
- Beyond that, or no log at all by end of day → `missed`
- Open sub-question carried over from the mood-system plan's pattern of surfacing open questions: exact multiplier for `drifting` vs `missed` threshold needs Laura's product decision — 3x is a starting proposal, not final.

**UI/UX (directly adapted from Aligned's 3-step flow, fitted into Citrine's existing screens rather than a new tab):**
1. **Setup**: in the existing Create Task / Create Habit forms, an optional "Track timing" toggle reveals `plannedTimeOfDay` + a flexibility-window stepper (5/10/15/30 min presets + custom). No new screen needed — this is a form section, not a new object type.
2. **Logging**: a single tap action already exists conceptually wherever tasks/habits are marked done (`habit_row.dart`, task completion actions) — add a lightweight "Log now" affordance that also stamps `actualTime` when the item has timing tracking enabled. No separate logging screen.
3. **Insights**: new section inside the existing **Statistics** screen (`statistics_screen.dart`) or Combined Analysis, not a new top-level tab: a "Routine Alignment" panel showing:
   - Per-item weekly drift trend (small sparkline, planned line vs. actual dots)
   - Plain-language insight sentences (e.g. "Você costuma atrasar o café da manhã às quartas" surfaced in English per the UI-text rule, since these are UI strings) generated from the delta data via a small set of **hardcoded rule templates** (e.g. "worst day of week by average delta," "most-missed item," "trend direction vs. last week") — plugged with the computed numbers. **No LLM call involved**, same zero-cost philosophy as the existing NLP parser. This satisfies the "insight sentence" pattern noted in Section 3.4 without requiring new chart infrastructure if Combined Analysis already has charting primitives (needs a source audit before implementation, flagged as a P0 verification task in the backlog below).

**Custom day-start hour** (global setting, separately useful beyond this feature):
- New setting in `settings_provider.dart` / Settings screen: `dayStartHour` (int, default 0 = midnight, matching current behavior exactly for anyone who doesn't touch it).
- Affects only **ordering/display** of same-day timeline views (Timeline screen, alignment insight panel) — does **not** change which calendar date a daily note belongs to, to avoid touching the vault's date-keyed file naming, which is out of scope and risky. This keeps the change purely presentational.

**Explicit non-goals (to prevent scope creep into a 5th tracking system):**
- No separate "Alignment" object type, no separate CRUD screens, no separate navigation entry.
- No CSV export tier / no monetization framing (not applicable to a personal single-user app).
- Does not replace or change existing Habit streak logic — alignment state is additive metadata, streaks still fire the same way they do today.

---

### 4.2 Feature: Focus Relay (chained multi-step timer)

**Product decision:** extend the existing Pomodoro system rather than building a parallel timer. `PomodoroSession` already models one work/break unit; Relay is a **named sequence of PomodoroSession-like steps** attached to a Task.

**Data model changes:**
- New field on `Task`: `relaySteps: List<RelayStep>?` (nullable — absent means the task uses today's flat Pomodoro behavior unchanged).
  ```
  class RelayStep {
    String id;
    String label;        // e.g. "Research", "Draft", "Review"
    int durationMinutes;
    bool isBreak;         // lets a step be a deliberate rest without being a full long-break cycle
  }
  ```
- `PomodoroProvider` gains a **Relay mode**: instead of the fixed work/short-break/long-break loop, when a Task with `relaySteps` is started, the provider walks the list in order, auto-advancing on completion of each step's timer, and logs one `PomodoroSession` per step (reusing the existing `toDailyNoteBlock()` / `fromDailyNoteBlock()` round-trip — no serialization format changes needed, since each Relay step is just a normally-shaped session with the step label as its title).

**UI/UX:**
- In the Task detail view / create-task form, an optional "Break into steps" action converts the single planned duration into an editable ordered list of `RelayStep`s (add/remove/reorder/rename, each with its own duration).
- Pomodoro screen (`pomodoro_screen.dart`) and floating clock (`pomodoro_floating_clock.dart`) gain a **step progress indicator** (e.g. "Step 2 of 4 — Draft") when running a Relay, otherwise unchanged from today's single-timer UI. This is additive UI, not a redesign of the existing pomodoro screen.
- Widget: existing `_pomodoroProvider` Android widget shows the current step label instead of just "Focus Session" when in Relay mode — no new widget provider needed.

**Explicit non-goals:**
- No AI-generated step breakdowns and no "AI Mate" personality layer. In ToDoD, the AI Mate persona and any AI-suggested step breakdown would run on LLM API calls — a recurring cost with no functional benefit here, on top of being a branding/monetization device Citrine's single-user, non-monetized context doesn't need. All `RelayStep`s are created manually by the user in the form UI; if Laura later wants lighter/friendlier copy in notifications, that's a static copy change, not a spec item.
- Relay does not replace the flat Pomodoro flow for tasks that don't opt in; zero behavior change for existing sessions.

---

## 5. Prioritized backlog

| ID | Item | Priority | Why |
|---|---|---|---|
| RA-P0-1 | Audit `statistics_screen.dart` / `combined_analysis_screen.dart` / `analysis_model.dart` to confirm what charting primitives already exist before building the Alignment insights panel | P0 | Avoid duplicating existing chart infra; this is a verification task per Citrine's "done means verified against source" principle |
| RA-P1-1 | `plannedTimeOfDay` + `flexibilityWindowMinutes` fields on Task/Habit + form UI toggle | P1 | Core of the feature, low risk (additive nullable fields) |
| RA-P1-2 | `AlignmentLogEntry` snapshot-on-daily-note + state calculation | P1 | Depends on RA-P1-1 |
| RA-P2-1 | Alignment insights panel (sparkline + insight sentences) | P2 | Depends on RA-P0-1 audit result |
| RA-P2-2 | `dayStartHour` setting + timeline display reordering | P2 | Independently useful even without Alignment; low complexity |
| RA-P1-3 | `RelayStep` model + Task form "break into steps" UI | P1 | Additive, reuses existing PomodoroSession serialization |
| RA-P1-4 | `PomodoroProvider` Relay-mode auto-advance logic | P1 | Depends on RA-P1-3 |
| RA-P2-3 | Step progress indicator on Pomodoro screen + floating clock + widget | P2 | Depends on RA-P1-4 |
| RA-P3-1 | Distress/nudge-style copy for missed alignment (tone only) | P3 | Optional polish, needs product-voice decision, not a mechanic |

**Open questions requiring Laura's decision before implementation tickets are written** (following the project's pattern of surfacing ambiguity rather than guessing):
1. Drift threshold multiplier for `drifting` vs `missed` (proposed 3x flexibility window — needs confirmation).
2. Whether Alignment tracking is exposed for both Habits and Tasks at launch, or Habits only first (Tasks have more heterogeneous scheduling and may need a narrower first cut).
3. Whether `dayStartHour` should eventually affect anything beyond display ordering (explicitly scoped OUT above, but flagging in case there's a use case already in mind, e.g. night-shift daily-note boundaries).