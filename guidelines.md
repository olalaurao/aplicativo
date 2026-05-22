
## CONCEPTUAL ARCHITECTURE OVERVIEW
this app is organized around two categories of things:

**CONTENT OBJECTS** — The actual user-generated content. There are 8 types:
1. Entry (journal entry)
2. Task
3. Goal (referred to as "Objective" in some UI contexts)
4. Habit
5. Tracker (the template/definition) + Tracking Record (individual instances)
6. Note (3 subtypes: Text Note, Outline Note, Collection Note)
7. Calendar Session (a planner block with start/end time)
8. Reminder (a lightweight planner item, may or may not be completable)

**ORGANIZER OBJECTS** — Structural containers that categorize content. Every content object can belong to multiple organizers simultaneously. Organizers have their own Timeline, showing all content tagged to them.

Organizer types:
1. Area (top-level life domain: "Work", "Health", "Family")
2. Project (has start/end dates; lives under an Area or Activity)
3. Activity (ongoing interest or recurring theme; lives under an Area)
4. Task (a Task is also an Organizer — content can be tagged to a task)
5. Goal/Objective (a Goal is also an Organizer)
6. Habit (a Habit is also an Organizer)
7. Tracker (a Tracker is also an Organizer)
8. Label (flexible tag, no hierarchy)
9. People (a named person)
10. Places (a named place with optional coordinates)

Hierarchy example: Area > Activity > Project > [Tasks, Habits, Trackers, Labels, People, Places]

**SUPPORTING/DERIVED OBJECTS:**
- Scheduler (repeat rule attached to a Calendar Session, Reminder, or Habit)
- Day Theme (a named day template with time blocks; e.g., "Workday", "Rest Day")
- Time Block (named time slot within a day theme; e.g., "Morning", "Deep Work", "Evening")
- KPI (key performance indicator derived from trackers, habits, entries, or custom input)
- Snapshot (a frozen state of a Goal, Note, Task, or statistics, saved to Timeline)
- Dashboard Panel (a pinned widget on the home screen showing data from any object)
- Timeline (a chronological feed of all activity; exists globally and per Organizer)

---

## DATA OBJECTS — DETAILED SPECIFICATION

---

### OBJECT 1: ENTRY (Journal Entry)

**Purpose:** Chronological personal journal. Entries live on the Timeline and are the primary journaling primitive.

**Properties:**
- `title` — string, optional. Free text. If omitted, entry shows as untitled or uses first line of body as preview.
- `body` — rich text, required. Supports: inline images (photos between text), checklists, bold/italic/underline formatting, headings, and bi-directional links (mentions to other objects using @-mention syntax).
- `date` — date + time. Defaults to now. User can edit. Stored as ISO datetime. Displayed on timeline as the entry's chronological position.
- `mood` — optional. Enum with 5 levels (e.g., Terrible, Bad, Neutral, Good, Amazing). Displayed as a color-coded emoji or icon. User picks from a horizontal row of icons. Custom feelings can be added (free text tags added alongside the mood level).
- `photos` — array of images. Photos can be inserted inline within the body OR attached separately. Stored in user's own Google Drive or iCloud (not app servers).
- `location` — optional geolocation or named place. User can tap to auto-detect GPS location or type a place name. Links to a Places organizer if matched.
- `organizers` — array of references to Organizer objects (any type: Area, Project, Activity, Task, Goal, Habit, Tracker, Label, People, Places). User selects from a searchable list. Displayed as chips/pills below entry content.
- `template` — optional. Reference to a saved Template. Applying a template pre-fills the body with structured content (headings, prompts, etc.).
- `comments` — array of Comment objects (each comment has: text, date, optional photo). Comments are added after creation in a separate thread below the entry.
- `weather` — optional, auto-populated if location is set.

**UI: How user creates an Entry:**
1. Tap the global "+" or "Create" button → tab switcher appears with tabs: Journal / Plan / Record / Note. User selects "Journal" tab.
2. Alternatively, tap "+" on the Timeline tab directly.
3. Entry editor opens as a full-screen sheet. Title field is at top (single line, large font). Body is a rich text editor below.
4. A toolbar row below the keyboard provides formatting options: Bold, Italic, Underline, Heading, Checklist, Insert Photo, Link/Mention (@).
5. A metadata row (below or above toolbar) shows chips for: Date, Mood, Location, Organizers. Tapping each chip opens a sub-picker.
6. Mood picker: horizontal row of 5 emoji/icons. Tap to select. Below the 5 levels, a secondary area shows "feelings" (text chips) that user can toggle or type custom feelings.
7. Date/time picker: calendar view for date + time wheel for time. Default is current date/time.
8. Organizers picker: searchable list grouped by type. Tap to toggle. Selected ones appear as chips on the entry form.
9. Tap "Done" or "Save" (button in top-right nav or full-width button at bottom) to save.

**UI: How Entry appears in Timeline:**
- Card format. Title (if present) in bold at top. Body preview (2–3 lines truncated). Below body: mood icon + colored dot. Date/time shown in muted text. Organizer chips shown as small rounded pills. Photos shown as thumbnail strip if present.
- Entries are sorted chronologically in descending order (newest first).

**States:** Entries have no status (not completable). They can be deleted or archived.

---

### OBJECT 2: TASK

**Purpose:** A unit of work that needs to be done. Tasks represent what you want to achieve. They are distinct from Calendar Sessions (which represent when you'll work on them).

**Properties:**
- `title` — string, required. Free text.
- `stage` — enum, required. Values: `Idea`, `To-do`, `In Progress`, `Pending`, `Finalized`. This is the primary status field. Displayed as a kanban column label or colored badge. Default is `Idea` or `To-do`.
- `priority` — enum, optional. Values likely: None, Low, Medium, High. Displayed as a colored flag or icon.
- `start_date` — date, optional. When the task becomes relevant.
- `end_date` — date, optional. Deadline.
- `notes` — array of rich text notes attached to the task. Tasks support multiple notes (not just one description field). Each note is a full rich text document.
- `subtasks` — array of Subtask objects. Each subtask has: `title` (string), `completed` (boolean). Displayed as a checklist. User taps "+" to add subtasks inline.
- `organizers` — array of references to Organizer objects.
- `scheduler` — optional. A Scheduler object defining recurrence rules. Attaching a scheduler auto-generates Calendar Sessions in the planner from this task.
- `color` — optional color for visual distinction.
- `participants` — array of People organizer references.
- `places` — array of Places organizer references.
- `timer_sessions` — derived. Accumulated time from Pomodoro/timer sessions associated with this task.
- `comments` — array of Comment objects.
- `reflection` — optional rich text added when a task moves to Finalized. Prompted at completion.

**UI: How user creates a Task:**
1. Tap "Create" → Plan tab → select "Task" option.
2. Or from the Task list view, tap "+" at the bottom.
3. Task editor is a full-screen form. Title at top. Below: stage selector (row of 5 labeled buttons or segmented control), end date picker, organizers chip selector, notes area, subtasks list.
4. Subtasks: "+" button adds a new text row. Each row has a checkbox on the left. Reorderable via drag handle.
5. Saving: "Done" button top-right.

**UI: How Tasks appear in lists:**
- Tasks are grouped by stage: Idea | To-do | In Progress | Pending | Finalized.
- Each stage is a collapsible section header.
- Each task row shows: title, priority icon, end date (if set), organizer chips, subtask progress indicator (e.g., "2/5").
- Swipe left on a task row to reveal quick actions: Change Stage, Delete.
- Long press for multi-select / batch actions.

**States (Stage transitions):**
- Idea → To-do → In Progress → Pending → Finalized
- Any stage can transition to any other (non-linear).
- "Finalized" triggers a reflection prompt.

---

### OBJECT 3: GOAL (OBJECTIVE)

**Purpose:** Long-term objective with measurable progress. Goals are tracked via KPIs and broken down by Calendar Sessions. Goals are also Organizers, so content can be associated to them.

**Properties:**
- `title` — string, required.
- `description` — rich text, optional.
- `type` — enum: `One-time` or `Repeating`. Repeating goals recur on a schedule (weekly, monthly, yearly).
- `repeat_interval` — for repeating goals: `weekly`, `monthly`, `yearly`.
- `start_date` — date, optional.
- `end_date` — date, optional.
- `kpis` — array of KPI objects. Each KPI is a measurable metric (23 types). KPI types include: completion count of habits, sum/average of tracker fields, number of journal entries, planner session count, custom numeric input, and more. Displayed as a number, percentage, or progress bar.
- `subtasks` — array of Subtask objects (same structure as Task subtasks).
- `schedulers` — array of Scheduler objects. Schedulers auto-create Calendar Sessions and Reminders for this goal in the planner.
- `organizers` — array of references to other Organizer objects.
- `snapshots` — array of Snapshot objects (see Supporting Objects).
- `color` — optional.
- `icon` — optional emoji or icon identifier.
- `comments` — array of Comment objects.
- `notes` — array of rich text notes.
- `participants` — array of People references.
- `places` — array of Places references.

**UI: Creation flow:**
1. Create → Plan tab → Goal (or Objective).
2. Editor: Title, description, type selector (one-time vs repeating), date range pickers, KPI setup section, scheduler section.
3. KPI setup: "Add KPI" button → KPI type picker (segmented list of 23 types, grouped by source: Habits, Trackers, Planner, Entries, Custom) → configure the KPI (select which habit/tracker/etc., set target value).
4. Scheduler setup: "Add Scheduler" button → opens Scheduler editor (see Scheduler section).

**UI: How Goals appear:**
- Goals list view grouped under organizers.
- Each goal card shows: title, KPI progress bar(s), end date, stage/completion indicator.
- Inside a Goal's detail view: KPI section shows each KPI with current value vs target, progress bar. Below: Calendar of scheduled sessions. Below: Timeline of associated content.

---

### OBJECT 4: HABIT

**Purpose:** Recurring behavior tracked through daily completions. Habits track streaks and completion rates.

**Properties:**
- `title` — string, required.
- `description` — string, optional.
- `color` — color picker, required for visual identification.
- `icon` — emoji or icon, optional.
- `completion_unit` — string, defines what is being counted. Default is "times". Can be customized to: "glasses", "minutes", "workouts", "pages", or any custom string. This makes completion granular.
- `daily_goal` — integer. The number of completion units required for a day to be marked "successful". Example: daily_goal=8 with unit="glasses" means 8 glasses of water needed per day.
- `slots` — array of HabitSlot objects. A slot is an individual instance within a reminder. A reminder can have up to 10 slots. Example: "Drink water" habit with 8 slots allows checking off each glass individually. Each slot can have its own scheduled time.
  - HabitSlot properties: `time` (optional specific time), `completed` (boolean per day), `label` (optional string).
- `schedulers` — array of Scheduler objects. Defines which days the habit appears on the planner (e.g., weekdays only, every 3 days). Schedulers create Habit Reminders in the planner automatically.
- `linked_tracker` — optional reference to a Tracker object. Completing a habit slot can trigger a tracker record prompt. Example: completing a "Workout" habit slot prompts the user to fill in the linked Workout Tracker (sets, reps, duration, intensity).
- `organizers` — array of references to Organizer objects.
- `time_block` — optional reference to a Time Block (e.g., assign this habit to the "Morning" block).
- `streak` — derived integer. Current consecutive days with successful completion. Displayed prominently.
- `completion_history` — derived array of daily completion records. Each record: `date`, `completions` (int), `successful` (boolean), `comments` (array of Comment objects), `journal_entries` (array of references to journal entries added on that day).
- `timeline` — derived. Shows journal entries, photos, tracker records, and reflections alongside completion records chronologically.
- `color_theme` — the habit's color is used throughout the UI: progress rings, calendar dots, streak badges.

**UI: How user creates a Habit:**
1. Navigate to Organizer tab → Habit section → tap "+" → "Add New Habit".
2. Editor: Title field, color picker (grid of colors), icon picker (emoji picker or icon library), completion unit field (text input with suggestions: "times", "glasses", "minutes", "pages"), daily goal field (numeric stepper or text input).
3. Slots section: shows a list of slots with individual times. "Add Slot" button adds a row. Each row has a time picker (optional) and a label field. Up to 10 slots.
4. Organizers section: chip selector.
5. Scheduler section: "Add Scheduler" button → opens Scheduler editor.
6. Linked Tracker section: tap to search and select an existing Tracker.
7. Save via "Done" button.

**UI: How Habits appear in the Planner:**
- Habit Reminders appear as distinct visual items within Time Blocks on the daily planner. They are visually differentiated from Calendar Sessions and regular Reminders by a unique design treatment (e.g., a different icon, the habit's assigned color, a habit-specific ring or checkbox design).
- Each slot is shown as an individual checkable item. User taps each slot checkbox to mark completion.
- If a linked tracker is set, tapping the last slot (or completing the daily goal) shows a mini tracker form inline or as a sheet.

**UI: How Habits appear in the Habit view (Organizer detail):**
- Calendar view at top: each day shows a colored dot if goal was met, partial dot if partially completed, empty if not started, gray if habit wasn't scheduled.
- Below calendar: streak count prominently displayed.
- List of completion records with dates and comment indicators.
- Timeline tab shows rich history: journal entries, photos, tracker records mixed with completions.

**States:**
- Per-day: `not_scheduled`, `pending` (scheduled but not yet completed), `partial` (some slots checked, goal not reached), `successful` (daily_goal met), `skipped` (manually skipped).

---

### OBJECT 5: TRACKER (definition) + TRACKING RECORD (instance)

**Purpose:** Fully customizable form for logging quantitative and qualitative data over time. Enables any measurable metric. Visualization via charts.

#### 5a. TRACKER (the template/definition)

**Properties:**
- `title` — string, required.
- `color` — color picker.
- `icon` — emoji or icon.
- `description` — string, optional.
- `organizers` — array of Organizer references.
- `sections` — array of TrackerSection objects. Sections group related input fields. Each section has:
  - `title` — string (can be blank).
  - `input_fields` — array of InputField objects (see below).
- `charts` — array of Chart configuration objects (line chart, bar chart, pie chart, calendar chart). Each chart references specific input fields.
- `summaries` — array of Summary configurations. Types: sum, average, min, max, count. Each references a specific input field and date range.

**InputField types (6 types):**
1. `text` — free text input. Single line or multiline.
2. `selection` — single-select from a predefined list of options. Example: sleep quality → [Terrible, Bad, Good, Amazing]. Displayed as a segmented control or radio buttons.
3. `quantity` — numeric input with a unit. Many built-in units available (kg, km, hours, reps, etc.) and custom units supported. Displayed as a number field with unit label.
4. `checklist` — multi-select from a predefined list. Each option can have an intensity (none, or 1–5). Example: symptoms → [Headache, Tired, Stomachache]. Displayed as a list of checkboxes with optional intensity indicator.
5. `checkbox` — simple boolean. Example: "Did I work out today?". Displayed as a single toggle or large checkbox.
6. `media` — photo/video attachment field. User can add photos or videos as input.

Each InputField has:
- `title` — string.
- `default_value` — optional.
- `organizers` — array. When this field is present in a tracking record, these organizers are auto-added to the record.

#### 5b. TRACKING RECORD (individual instance)

**Properties:**
- `tracker` — reference to parent Tracker.
- `date` — date + time.
- `field_values` — map of InputField.id → value. Not all fields need to be filled.
- `photos` — array of attached images.
- `note` — optional free text.
- `comments` — array of Comment objects (per-record, but also per individual input field).
- `organizers` — array of Organizer references (auto-populated from InputField organizers + manually added).

**UI: How user adds a Tracking Record:**
1. Create → Record tab → tap "+" on the desired Tracker → EditTrackingRecord sheet opens.
2. Or: from the Timeline, tap on a Tracker section "+" button.
3. Record editor: shows all sections and input fields in a scrollable form. Fields are inactive (dimmed) until tapped. Tap a field to activate it and enter a value. No fields are required.
4. Date/time at top, editable.
5. Tap the history icon (clock) next to a field to see past values and optionally copy one.
6. Tap the gear icon next to a field to edit its configuration on the fly.
7. Photos row at bottom. Note field at bottom.
8. "Done" to save.

**UI: How Tracker appears in its detail view:**
- Top: calendar showing dates with records (colored dots).
- Below calendar: filter button to show only specific fields.
- "View as Table" button: switches to tabular view (rows = dates, columns = fields). Sortable. Columns reorderable.
- Summaries section: each summary shows label + value (e.g., "Average Sleep: 7.2 hours").
- Charts section: each chart rendered below. Line/bar/pie/calendar chart types. Tap to expand.

---

### OBJECT 6: NOTE

**Purpose:** Non-chronological reference material. Notes live in a separate library from journal entries. Three distinct subtypes.

**Common properties (all Note types):**
- `title` — string, required.
- `created_at` — datetime.
- `updated_at` — datetime.
- `organizers` — array of Organizer references.
- `color` — optional.
- `parent_note` — optional reference to parent Note (for nesting/hierarchy).
- `bi_directional_links` — derived. Other objects that link to/from this note via @-mentions.

#### 6a. TEXT NOTE
- `body` — rich text. Supports: inline images, bold/italic/headings, checklists, @-mentions (links to any other object), inline notes (embed other notes inline).
- `template` — optional.

#### 6b. OUTLINE NOTE
- `nodes` — tree structure of OutlineNode objects. Unlimited nesting depth.
  - OutlineNode: `id`, `content` (rich text), `children` (array of OutlineNode), `linked_items` (array of references to any content object), `collapsed` (boolean).
- Features: drag-and-drop reordering, focus mode (shows only selected branch), mirroring (same node appears in multiple places), text filter.
- Snapshots can be taken of the entire outline state.

#### 6c. COLLECTION NOTE (database)
- `schema` — array of PropertyDefinition objects. 20+ property types supported.
- `items` — array of CollectionItem objects. Each item has values for each property in the schema.
- `views` — list/gallery/table views.

PropertyDefinition types (20+): text, rich_text, quantity, date, time, duration, selection (single), multi_selection, checkbox, url, email, phone, rating, relation (link to another object), media, and more.

**UI: Note creation:**
1. Create → Note tab → choose type (Text / Outline / Collection).
2. Text note: opens rich text editor. Title at top.
3. Outline note: opens outliner. Each row is a node. Tab to indent (create child). Shift-tab to outdent. Long press node for contextual menu (link to item, add child, mirror, etc.).
4. Collection: prompts to add properties first (or choose from template). Then shows a table/list with "+" to add rows.

**UI: Notes appear in:**
- Notes section in the main navigation.
- Organized in folder hierarchy.
- Notes do NOT appear in the main Timeline (they are reference material, not chronological events). However, a note CAN be pinned or linked to a timeline entry.

---

### OBJECT 7: CALENDAR SESSION

**Purpose:** A time-bound slot on the daily planner. Represents when you will work on something. Can stand alone or belong to a Task or Goal.

**Properties:**
- `title` — string, required.
- `date` — date, required.
- `time_of_day` — either: (a) a reference to a Time Block (e.g., "Morning", "Deep Work") or (b) an exact start time (hour:minute).
- `duration` — duration in minutes, optional (for Pomodoro/timer use).
- `end_time` — derived or explicit, optional.
- `multi_day` — boolean. A session can span multiple days or have a status of "until done".
- `color` — color.
- `task` — optional reference to a parent Task object.
- `goal` — optional reference to a parent Goal object.
- `subtasks` — array of Subtask objects (inline checklist for this specific session).
- `note` — rich text, optional.
- `places` — array of Places references.
- `participants` — array of People references.
- `reminders` — array of Reminder trigger times (e.g., "15 minutes before").
- `organizers` — array of Organizer references.
- `timer` — optional Pomodoro/timer settings. When active, a live timer is shown.
- `scheduler` — optional Scheduler reference (for recurring sessions).
- `backlog` — boolean. A session can be in "Backlog" state (no date assigned, just a target period). Moved out of backlog by scheduling to a date.
- `exported_calendar_id` — optional. If exported to Google Calendar, stores the external event ID.
- `comment` — a post-session comment/reflection, optional. Added after completing.

**States:** `scheduled`, `in_progress` (timer running), `completed`, `backlog`.

**UI: Creation:**
1. Create → Plan tab → enter title → set Date (date picker with a special "Backlog" option in the dropdown) → set Time of Day (block picker OR tap clock icon for exact time) → optionally link to a Task → tap "Calendar Session" button → opens full editor sheet.
2. In Planner: tap "+" button on a specific Time Block → creates session directly in that block (date and block pre-filled).
3. Drag-and-drop from task list onto planner day/block.

**UI: In the Planner:**
- Sessions appear as colored pills/cards within their Time Block.
- Visually distinct from Habit Reminders and regular Reminders.
- Timer sessions show a play button. Tap to start Pomodoro timer. Timer notification shows on lock screen.
- Long press → contextual menu: Move (date picker), Duplicate, Export to Google Calendar, Delete.
- Drag handle for reordering within a block.

---

### OBJECT 8: REMINDER

**Purpose:** A lightweight, optionally completable planner item. Less structured than a Calendar Session. Used for notifications, habits, and general reminders.

**Properties:**
- `title` — string, required.
- `date` — date.
- `time` — optional specific time.
- `time_block` — optional reference to Time Block.
- `completable` — boolean. If false, it's a pure notification. If true, user can check it off.
- `checkboxes` — array (checkboxes can be added/removed after creation).
- `organizers` — array of Organizer references.
- `scheduler` — optional Scheduler (makes it recurring).
- `habit_reminder` — boolean flag. Indicates this reminder was auto-generated by a Habit's scheduler. Displayed differently in UI (uses Habit's color, shows habit slots).

---

## SUPPORTING OBJECTS — DETAILED SPECIFICATION

---

### SCHEDULER

**Purpose:** Defines recurrence rules for Calendar Sessions, Reminders, or Habit Reminders. Attached to Tasks, Goals, or Habits. One object can have multiple schedulers simultaneously.

**UI: How the Repeat picker works (confirmed from screenshots):**

The Repeat screen is a modal (sheet) titled "Repeat" with an X close button in the top-right. It contains a scrollable list of radio button options. Each option is a card-style row with a radio button on the left and a label. When a radio button is selected, that card expands inline to reveal its configuration sub-fields — other options remain collapsed. The bottom of the modal has a full-width "Next" button (dark purple/violet, white text, rounded corners). The flow is multi-step: step 1 picks the repeat type and configures it, tapping "Next" moves to step 2 (likely exclusions, overdue policy, or scheduling target).

**`repeat_type` — enum with 9 confirmed values:**

1. **`number_of_days`** — "Number of days"
   - Inline sub-field when selected: "Every [N] days"
   - `interval`: integer input field (inline text field, default 1). Displayed as: label "Every" + underlined text input + label "days".

2. **`days_of_week`** — "Days of the week"
   - Inline sub-field when selected: 2-column checkbox grid showing all 7 days.
   - Layout: Mon | Tue / Wed | Thu / Fri | Sat / Sun (alone on last row).
   - Each day is a checkbox (square checkbox, not radio). Multiple days can be selected simultaneously.
   - `days`: array of selected day names. At least 1 required.

3. **`number_of_weeks`** — "Number of weeks"
   - Inline sub-field when selected: "Every [N] weeks" (integer input, same pattern as number_of_days).
   - Likely also shows day-of-week selector (not confirmed in screenshot but implied by weekly semantics).
   - `interval`: integer.

4. **`number_of_months`** — "Number of months"
   - Inline sub-fields when selected:
     - "Every [N] months" — integer input field inline.
     - "Days of month" section with a "+" button on the right. Below it: each selected day shown as "Day [N]" with an "×" remove button on the right. User taps "+" to add a specific calendar day number (e.g., Day 11). Multiple days of month can be added.
   - `interval`: integer.
   - `days_of_month`: array of integers (1–31). Each entry shown as a removable chip row ("Day 11 ×").

5. **`days_of_theme`** — "Days of theme"
   - When selected: shows a theme picker (select which Day Theme to match).
   - `theme_id`: reference to a Day Theme object.
   - NOTE: In implementations that don't use Day Themes, this option can be replaced with a tag/category equivalent (e.g., "Days tagged as [X]").

6. **`days_with_block`** — "Days with block"
   - When selected: shows a block picker (select which Time Block to match).
   - `block_id`: reference to a Time Block object.
   - NOTE: In implementations without Time Blocks, this can be replaced with "Days scheduled with [Task type/category]".

7. **`days_after_last_start`** — "Days after last start"
   - Recurs N days after the last instance's start date.
   - `interval`: integer. Inline field: "N days after last start".

8. **`days_after_last_end`** — "Days after last end"
   - Recurs N days after the last instance's end/completion date.
   - `interval`: integer. Inline field: "N days after last end".

9. **`number_of_days_per_period`** — "Number of days per period"
   - Most complex option. Confirmed sub-fields when selected:
     - "[N] days per [Period]" — N is an integer text input; Period is a tappable purple/accent text button that cycles or opens a picker with values: `Week`, `Month`, `Year`.
     - "Starting day offset" — integer input field (right-aligned), default 0. Defines on which day of the period the first instance starts.
     - "Interval between days:" — integer input field (right-aligned), default 1. Minimum gap in days between instances within the same period.
   - Example shown in UI: "Play football twice a month, first starts on day 10 or later, second starts 5+ days after the first" (shown as a small gray helper text below the fields).
   - `count_per_period`: integer (N).
   - `period`: enum (`week`, `month`, `year`).
   - `starting_day_offset`: integer (default 0).
   - `interval_between_days`: integer (default 1).

**Additional Scheduler properties (beyond repeat_type):**
- `start_date` — date from which recurrence begins.
- `next_instance_date` — date. After completing/skipping, next instance is scheduled from here.
- `exclusion_rules` — array of exclusion conditions (configured in a subsequent step after "Next" is tapped).
- `overdue_policy` — enum: `skip`, `keep`, `prompt`.
- `time_block` — optional. Which block to schedule generated items into.
- `exact_time` — optional time. Generated sessions have this exact time.
- `item_type` — enum: `calendar_session`, `reminder`, `habit_reminder`.

**Multi-step creation flow:**
- Step 1: Select repeat_type from the radio list, configure its inline sub-fields. Tap "Next".
- Step 2 (implied): Configure exclusions, overdue policy, and scheduling target (which block/time).
- The modal can be dismissed with the X button at any step.

**One object can have multiple schedulers.** Example: a Task can have a scheduler for daily standups (Calendar Session type) AND a weekly review reminder (Reminder type).

---

### DAY THEME

**Purpose:** A named template for a type of day, defining which Time Blocks appear.

**Properties:**
- `name` — string (e.g., "Workday", "Weekend", "Rest Day").
- `blocks` — array of TimeBlock references, in order.
- `days_of_week` — array of day names where this theme is the default.
- `color` — optional.

---

### TIME BLOCK

**Purpose:** A named time container within a day. Blocks organize planner items by context, not by strict hours.

**Properties:**
- `name` — string (e.g., "Morning", "Deep Work", "Admin", "Evening").
- `time_ranges` — array of time range objects (start_time, end_time). A block can have 0 or multiple time ranges (0 = block has no time constraint, just a label).
- `color` — optional.
- `order` — integer for display order within the day.

---

### KPI (Key Performance Indicator)

**Purpose:** A computed metric attached to a Goal. Measures progress toward the goal from various data sources.

**Properties:**
- `title` — string.
- `source_type` — enum (23 types): habit_completion_count, habit_streak, tracker_field_sum, tracker_field_average, tracker_field_max, tracker_field_min, entry_count, planner_session_count, planner_session_duration, goal_subtask_completion, custom_numeric_input, and more.
- `source_reference` — reference to the specific Habit, Tracker field, etc. being measured.
- `target_value` — number. The goal to reach.
- `current_value` — derived number.
- `date_range` — optional. Custom date range for calculation.
- `display_type` — enum: number, percentage, progress_bar.

---

### SNAPSHOT

**Purpose:** Freezes the current state of a Task, Goal, Note, or statistics at a specific moment. Saved to Timeline for reflection.

**Properties:**
- `subject` — reference to the object being snapshotted (Task, Goal, Note).
- `date` — datetime.
- `state_data` — serialized state of the object at that moment.
- `reflection` — optional rich text written at the time of the snapshot.
- `photos` — optional array of images.
- Appears in the Timeline feed like an entry.

---

### DASHBOARD PANEL

**Purpose:** A pinned widget on the home screen (Dashboard tab). Fully customizable. Shows data from any object.

**Known panel types:**
- Today's Habits (shows completion status for today's habits)
- Upcoming Sessions (next N calendar sessions)
- Goal Progress (KPI progress bars for selected goals)
- KPI Panel (single or multi-KPI display, with custom date range)
- Tracker charts (inline chart from a tracker)
- Task summary (count by stage)
- Pinned Note (a specific note embedded in dashboard)
- Pinned Planner (embedded planner view)
- Statistics summary

**Properties:**
- `type` — enum (panel type).
- `title` — string.
- `organizer_filter` — optional reference to an Organizer (show only data from that context).
- `date_range` — optional.
- `order` — integer (drag-to-reorder).

---

## SCREENS AND NAVIGATION STRUCTURE

### Main Navigation (Bottom Tab Bar, 5 tabs):

1. **Timeline** — Chronological feed of all content (Entries, Habit completions, Tracking Records, Completed Tasks, Snapshots). Can filter by date (Day/Week/Month view). Scrollable vertically. Each item type has a distinct card design.

2. **Planner** — Daily/Weekly/Monthly views of Calendar Sessions, Habit Reminders, and Reminders. Organized by Time Blocks within each day. Day view is default. Switching between views via a segmented control at top.

3. **Dashboard (Home)** — Customizable grid of Dashboard Panels. User pins/unpins panels. Panels are reorderable via drag.

4. **Organizer** — Shows all Organizer objects grouped by type (Area, Project, Activity, Task, Goal, Habit, Tracker, Label, People, Places). Each type is a section. Tapping an Organizer opens its detail view showing its Timeline, associated Tasks, Notes, Planner, etc.

5. **Notes** — Notes library. Folders hierarchy at top. Three note types listed with type icons. Search bar. Recent + All sections.

### Global "Create" Button (Floating Action Button or persistent nav button):
Opens a bottom sheet or modal with tabs:
- **Journal** tab → creates Entry
- **Plan** tab → creates Task, Goal, Calendar Session, Reminder, or Backlog item
- **Record** tab → creates Tracking Record for a Tracker
- **Note** tab → creates Text Note, Outline Note, or Collection Note

### Additional Entry Points:
- **Command Center** — Activated by scrolling up anywhere in main UI. Quick launcher for notes, tasks, upcoming sessions, organizers, statistics.
- **Inbox** — Quick-capture area for unorganized thoughts. Items captured here can be triaged later.
- **Home Screen Widgets** — Native iOS/Android widgets showing habits, tasks, sessions.

---

## INTERACTION PATTERNS

### Common gestures and UI behaviors:

- **Tap item** → opens detail/edit view (full screen or sheet depending on item type).
- **Long press item** → enters multi-select mode OR shows contextual action menu (Move, Duplicate, Delete, Archive, Change Stage).
- **Swipe left on list item** → reveals quick actions (Delete, Change Stage, Mark Complete).
- **Drag and drop (Planner)** → move Calendar Sessions between blocks or days. Drag tasks from list onto planner.
- **Drag and drop (Organizer)** → reorder Habits, Trackers, Tasks within lists.
- **Pull down on main screen** → possibly refreshes or opens search.
- **Scroll up in main UI** → triggers Command Center.

### Input component patterns:

- **Title fields** — always single-line text input, large font, prominent at top of editors.
- **Rich text body** — full keyboard editor with a custom toolbar row (formatting, photo insert, @-mention).
- **Date picker** — calendar grid + optional time wheel. A "Backlog" special option appears in date dropdowns for Calendar Sessions.
- **Time picker** — scrollable time wheel (hour/minute) or a discrete block selector (tapping from a list of named Time Blocks).
- **Color picker** — grid of preset colors (12–20 swatches). No custom hex input implied.
- **Icon picker** — emoji keyboard or a curated icon library.
- **Organizer picker** — searchable list modal. Items grouped by type. Tap to toggle selection. Selected items shown as chips in the form.
- **Enum selectors (stage, priority)** — horizontal segmented control or row of labeled buttons. Tap to select.
- **Mood picker** — horizontal row of 5 large emoji/icon buttons. Below that: a cloud of "feelings" chips (pre-defined + custom) that can be toggled.
- **Numeric stepper** — for daily goal, slot count, etc. +/- buttons OR direct text input.
- **Repeat rule builder (Scheduler)** — multi-step form: select repeat type → configure days/interval → set start date → optionally configure exclusions → set overdue policy.
- **KPI builder** — select source type from grouped list → drill into specific habit/tracker → set target value.
- **Subtask list** — inline editable checklist. "+" button adds a new row. Each row: checkbox + text field + optional drag handle. Tap checkbox to complete.
- **Tracker record form** — scrollable form of input fields grouped in sections. Fields are inactive until tapped. History icon shows past values. Gear icon edits field config.

---

## OBJECT RELATIONSHIP MAP

The following relationships exist between objects (all cross-references are navigable in both directions):

- Entry ←→ Organizer (any type): Entry can belong to multiple organizers. Organizer shows all associated entries in its Timeline.
- Task ←→ Calendar Session: A Calendar Session optionally belongs to a Task. A Task generates sessions via Schedulers.
- Task ←→ Organizer: Task is both a content object and an Organizer. Other content can be associated to a Task.
- Goal ←→ KPI ←→ Tracker/Habit/Entry/Planner: KPIs pull data from these sources to measure goal progress.
- Goal ←→ Calendar Session: Goal generates sessions via Schedulers.
- Goal ←→ Organizer: Goal is both content and Organizer.
- Habit ←→ Habit Reminder: Habit's Scheduler auto-generates Habit Reminders in Planner.
- Habit ←→ Tracker: Habit completion can trigger a Tracking Record prompt.
- Habit ←→ Organizer: Habit is both content and Organizer.
- Tracker ←→ KPI: Tracker fields feed into Goal KPIs.
- Tracker ←→ Organizer: Tracker is both content and Organizer.
- Note ←→ Note (nesting): Notes can be nested inside other notes.
- Any object ←→ Any object (via @-mention in rich text): Bi-directional links are created when one object's rich text body mentions another.
- Snapshot → Task/Goal/Note: A snapshot is always attached to a parent object and appears in both the parent's detail and the main Timeline.
- Calendar Session ←→ Time Block: Sessions are placed inside blocks.
- Scheduler → Calendar Session/Reminder/Habit Reminder: Schedulers produce these planner items automatically.

---

## VISUAL DESIGN NOTES

- **Color system:** Each object type has a system color. Individual instances can have custom colors (Habits especially rely on color for identity). The app supports dark and light themes.
- **Typography:** Clean sans-serif. Large titles. Body text is readable at normal size. Muted secondary text for dates, metadata.
- **Card style:** Timeline items use card components with subtle shadows or borders. Cards have consistent padding. Title is bold, body is regular weight, metadata row (date, organizers) is small and muted.
- **Organizer chips:** Small rounded pills showing organizer name. Colored with organizer's color or a system default. Shown below content in list items.
- **Progress indicators:** Streaks shown as bold numbers with a flame or star icon. Progress bars are thin horizontal bars. KPI values shown large with a label below.
- **Empty states:** Descriptive text + illustration encouraging the user to create the first item.
- **Loading/saving:** Minimal; app is offline-first so no loading spinners for most operations.

---

## IMPLEMENTATION NOTES FOR AI (Key Design Decisions)

1. **Content vs Organizer duality:** Tasks, Goals, Habits, and Trackers serve as both content (they can be created and viewed individually) and as Organizers (other content can be associated to them). This means every content object has an `organizers` array that can reference any type of organizer, including other Tasks and Goals.

2. **Planner vs Task separation:** The app enforces a conceptual separation between WHAT (Task/Goal) and WHEN (Calendar Session). A task has no date assigned to it directly — instead, Calendar Sessions are created and linked to the task. This is a deliberate design philosophy different from most todo apps.

3. **Scheduler as a first-class object:** Schedulers are not just simple "repeat every X days" flags. They are separate configurable objects that can be added to multiple parent objects and produce different types of planner items. Multiple schedulers can be attached to one object.

4. **Flexible units for Habits:** The completion_unit field is a free text field with suggestions. This is crucial for implementing diverse habits beyond simple checkboxes.

5. **Tracker input field organizers:** When a specific InputField is filled in a Tracking Record, that field's associated organizers are automatically added to the record. This enables fine-grained automatic categorization.

6. **Timeline as the universal view:** Every content object (except Notes) appears in the Timeline. The Timeline is the primary "what happened" view. Organizer timelines are filtered subsets.

7. **Bi-directional links:** When you @-mention an object in rich text, the link is registered in both objects. This means querying "what links to this note" is possible and is shown in the Note's detail view.

8. **Backlog:** Calendar Sessions can be in a Backlog state (no date, just a target period). This is used for planning future work without committing to a specific day.

9. **Day Theme as a scheduling primitive:** The "Days of Theme" repeat type in Schedulers means recurrence can be tied to the type of day, not a calendar rule. This allows "only schedule this on Workdays" even if Workdays vary.

10. **KPI data model complexity:** There are 23 KPI types. When implementing, the KPI's source_type determines which foreign key is relevant (habit_id, tracker_field_id, etc.) and which computation runs (sum, average, count, streak). KPIs are recalculated dynamically and shown as current snapshots.

11. **Scheduler replace pattern for apps without Themes/Blocks:** If the implementation does not use Day Themes or Time Blocks, the `days_of_theme` repeat type should be replaced with a task-category or tag-based equivalent (e.g., "repeat on days that have a [Work] task scheduled"). The `days_with_block` type can be replaced with "days that contain tasks of type [X]". All other 7 repeat types remain unchanged.

---

## UI FUNDAMENTALS — LAYOUT, NAVIGATION, AND PLATFORM CONVENTIONS

This section describes platform-level UI decisions that apply to every screen. These are not specific to Journal.it but are required for a correct mobile implementation.

---

### SAFE AREAS AND INSETS

Every screen must respect platform safe areas:

- **Top safe area (status bar region):** On iOS, the top inset is typically 44pt (non-notch) or 47–59pt (notch/Dynamic Island devices). On Android, it is the status bar height (typically 24–28dp). No content should be placed under the status bar. The app's navigation bar or screen title starts BELOW the top inset. If a screen has no top navigation bar, the content's first element must have top padding equal to the safe area inset.
- **Bottom safe area (home indicator region):** On iOS devices with home indicator (Face ID models), the bottom inset is 34pt. Buttons, tab bars, and bottom navigation elements must be placed ABOVE this inset. A full-width bottom button (like the "Next" button in the Scheduler) must have its bottom edge at least 34pt from the physical screen bottom, typically adding 16–20pt padding above the home indicator inset so the button doesn't feel too close to the edge.
- **Left/right safe areas:** On iPads in split screen or on some foldable Androids, left/right insets may be nonzero. Horizontal padding on content should account for this.
- **Implementation:** On React Native, use `SafeAreaView` or the `useSafeAreaInsets()` hook. On Flutter, use `SafeArea` widget. On native iOS, use `safeAreaLayoutGuide`. On native Android, use `WindowInsetsCompat`.

---

### NAVIGATION STRUCTURE AND BACK BUTTON

Every screen that is not a root tab screen must have a way to go back. Rules:

- **Modal screens (sheets):** Use an X (close) button in the top-right corner. This is confirmed in Journal.it's Scheduler screen (X in top-right). Modal sheets do NOT use a back arrow — they use X because they float above the content rather than replacing it.
- **Pushed screens (navigated into):** Use a back arrow (chevron left "‹" or "←") in the top-left corner. Tapping it pops the screen and returns to the previous screen in the stack. The back button is placed inside the top navigation bar, which itself starts below the top safe area inset.
- **Top navigation bar height:** Standard is 44pt on iOS / 56dp on Android Material. This bar contains: back button (left), screen title (center), and optional action button (right, e.g., "Done", "Save", or a settings gear icon).
- **Done/Save button:** For creation/editing screens that are modals, the primary action button can be either: (a) a text button "Done" in the top-right of the nav bar, OR (b) a full-width bottom button (like Journal.it's "Next" / "Done" button — dark purple, white text, rounded pill shape, full width with horizontal margins, positioned just above the bottom safe area inset).
- **Swipe to dismiss:** Modal sheets should support swipe-down-to-dismiss gesture on iOS. On Android, the back hardware/gesture button should dismiss modals.

---

### SCROLL BEHAVIOR

Rules for what scrolls and what stays fixed:

- **Fixed top:** Navigation bar (back button + title + action button) is always fixed at the top. It does NOT scroll away. The content area starts below it.
- **Fixed bottom:** Tab bar (main navigation) is always fixed at the bottom of the screen. It does NOT scroll away. For modal screens, the bottom CTA button ("Next", "Done") is fixed at the bottom — it does NOT scroll with the content.
- **Scrollable content area:** The content between the fixed top nav and fixed bottom element is a scrollable region. Scrolling is vertical. If the content fits on screen without scrolling, the scrollable region simply shows all content without scroll indicators.
- **The Repeat/Scheduler screen specifically:** The list of repeat type options (radio buttons) is vertically scrollable. The title "Repeat" + X close button are fixed at the top of the modal. The "Next" button is fixed at the bottom of the modal. The list of options scrolls between these two fixed anchors. This is critical because expanded options (like "Number of days per period") add additional height to the list, and the user needs to scroll to see all options.
- **Keyboard avoidance:** When a text input is focused and the keyboard appears, the scrollable content should shift up so the active input field is visible above the keyboard. Use `KeyboardAvoidingView` (React Native), `SingleChildScrollView` with `resizeToAvoidBottomInset` (Flutter), or equivalent. The fixed bottom button should also shift up above the keyboard.
- **Overscroll behavior:** On iOS, use the default rubber-band overscroll. On Android, use the default ripple/glow overscroll indicator.

---

### MODAL SHEET PRESENTATION

Journal.it uses bottom sheets and full-screen modals. Rules:

- **Bottom sheet (partial screen):** Slides up from the bottom. Used for: quick pickers (date, color, organizer selector), contextual action menus (long press actions), small configuration panels. Appears over the current screen with a dim overlay behind it. Can be dismissed by tapping the overlay or swiping down.
- **Full-screen modal:** Used for: creating/editing content objects (Entry, Task, Goal, Habit, etc.), complex multi-step flows (Scheduler). Slides up from the bottom but covers the full screen. The underlying screen is darkened but not interactive while the modal is open. Dismissed via X button or explicit "Cancel"/"Done" action.
- **Sheet handle:** Bottom sheets typically show a small rounded "pill" handle at the very top center (a short horizontal bar, ~36pt wide, 4pt tall, gray/muted color). This indicates the sheet is draggable. Full-screen modals typically do NOT show this handle — they have a top nav bar with X button instead.
- **Stacking modals:** Journal.it stacks modals (e.g., opening the Scheduler from inside a Task editor). The visual effect is each modal appears on top of the previous one, slightly inset/scaled down to show depth. On iOS this is the default `pageSheet` modal style. On Android, it's achieved with a new Activity or a fragment overlay.

---

### LIST AND CARD COMPONENTS

Standard rules for list items across the app:

- **List item height:** Standard rows (single line of text + icon) are 48–52pt tall. Rows with subtitle text are 60–72pt. Rows with expanded content (like the Scheduler options when selected) grow dynamically to fit their content.
- **List item padding:** Horizontal padding is 16pt from screen edges. Vertical padding within each row is 12–16pt top/bottom.
- **Separator lines:** Between list items, a 1px (hairline) separator line in a light gray color. Typically inset 16pt from the left to align with text (not full width). Some lists use card style (each item is a rounded rectangle with a subtle shadow or fill) instead of separator lines — Journal.it uses the card style for Scheduler options (each option is a rounded rect with a light gray/muted background fill).
- **Card border radius:** Rounded rectangle cards use 12–16pt corner radius. Confirmed in Journal.it's Scheduler options.
- **Touch feedback:** On tap, list items show a brief highlight/ripple (platform-native: iOS uses gray highlight, Android uses ripple). On long press, the item enters selection state or shows a context menu.
- **Section headers:** Bold, slightly larger text (or all-caps smaller text), with 16pt horizontal padding. Not tappable unless the section is collapsible.

---

### TYPOGRAPHY HIERARCHY

Standard text size hierarchy for mobile UI (based on Journal.it's visual style):

- **Screen title (nav bar):** 17–18pt, semibold, centered.
- **Card/item title (primary text):** 16–17pt, regular or medium weight.
- **Item subtitle / metadata:** 13–14pt, regular, muted color (gray, ~60% opacity of body text color).
- **Section headers:** 13–14pt, semibold or all-caps, muted.
- **Helper/example text:** 12–13pt, regular, light gray. Used for explanatory text below form fields (e.g., the example text in "Number of days per period").
- **Button label (primary CTA):** 16–17pt, semibold, white on dark background.
- **Form field labels:** 14–15pt, regular or medium.
- **Form field values (inputs):** 15–16pt, regular. Input values are underlined or in a bordered field.

---

### FORM INPUT PATTERNS (UI COMPONENTS)

Complete reference for every input component type used:

- **Radio button:** Circle outline (unfilled = unselected, filled center circle = selected). Selected state uses the app's accent color (dark purple/violet in Journal.it). The entire row is tappable, not just the radio circle. Selecting a new radio deselects the previous one.
- **Checkbox:** Square with rounded corners. Unfilled = unchecked. Filled with checkmark = checked. Accent color fill when checked. Used when multiple selections are allowed simultaneously (e.g., days of week, checklist fields).
- **Inline integer input:** Shown as an underlined text field (no border box, just a bottom underline). Tapping focuses it and shows the numeric keyboard. Default value shown. Right-aligned if it's a value field next to a label.
- **Text input (full field):** A bordered or filled rectangle. Single line for titles, multiline for body/notes. On focus, border highlight changes to accent color.
- **Segmented control:** A row of equal-width buttons with a shared container. The selected option has a filled/highlighted background, others are ghost. Used for: note type selection (Text/Outline/Collection), view switchers (Day/Week/Month).
- **Toggle/switch:** Standard iOS-style toggle (or Material switch on Android). Left = off (gray), right = on (accent color). Used for boolean settings.
- **Tappable value pill:** A label that opens a picker when tapped. Shown as the label text in the app's accent color (to indicate it's tappable), sometimes with a subtle underline or pill background. Example: the "Week" text in "1 days per Week" in the Scheduler — it is purple/accent colored, indicating it's a tappable interactive element that opens a picker to change the period.
- **Date picker:** Platform-native date picker (iOS: wheel or calendar grid; Android: calendar grid). Often shown in a bottom sheet. Shows month/year navigation arrows.
- **Chip/tag selector:** A row or wrap of small rounded pill buttons. Each pill represents an option. Selected state: filled background with accent color + white text. Unselected: outline or light gray fill. Used for: organizer selection, feelings/mood tags. Scrollable horizontally if overflow.
- **Color swatch grid:** A grid of filled circles (or rounded squares), each representing a preset color. Tap to select. Selected swatch shows a checkmark overlay or a ring border. Typically 4–6 columns.
- **Emoji/icon picker:** A grid of emoji characters or icon glyphs. Searchable. Displayed in a modal sheet.
- **Stepper (+ / -):** Two buttons (minus on left, number in center, plus on right) for adjusting a small integer. Used sparingly; inline integer inputs are more common in Journal.it.

---

### EMPTY STATES

Every list or content area that can be empty must have an empty state:

- **Visual:** A centered illustration or icon (simple, monochromatic or lightly colored).
- **Headline:** 1–2 word description of what's missing (e.g., "No habits yet", "Nothing planned").
- **Subtext:** 1–2 sentences explaining what this section is for and how to add the first item.
- **CTA:** A button or tappable text link to create the first item (e.g., "+ Add your first habit").
- **Positioning:** Vertically centered in the available content area (between nav bar and tab bar).

---

### LOADING AND FEEDBACK STATES

- **Saving:** Since the app is offline-first, saving is instant (writes to local storage, syncs in background). No full-screen loading spinners for saves. A brief success indicator (checkmark animation or subtle haptic feedback) is sufficient.
- **Sync indicator:** A small icon or badge in the nav bar when sync is in progress or has failed.
- **Destructive actions (delete):** Always require a confirmation alert with two options: "Delete" (red text, destructive) and "Cancel" (default style). The confirmation message names the item being deleted.
- **Haptic feedback:** Used for: completing a habit slot (light impact), completing a task (medium impact), destructive actions (warning haptic).

---

### ACCESSIBILITY

- All tappable targets should be at least 44×44pt (iOS HIG minimum) / 48×48dp (Material minimum).
- Color is never the only means of conveying state (always pair with icon or text label).
- Text contrast ratio minimum 4.5:1 for body text.
- Support dynamic text sizes (honor system font size settings).


---

## SCREENSHOT-CONFIRMED UI DETAILS

This section documents exact UI layouts and behaviors confirmed directly from screenshots.

---

### CALENDAR SESSION — DETAIL/EDIT SCREEN (confirmed from screenshot)

The Calendar Session form is a full-screen scrollable modal. Title "calendar session title" is a large, light-gray placeholder at the very top (full width, no border, large font ~28–32pt). Below the title, the form is divided into grouped rounded-rect cards:

**Card 1 — Status and metadata:**
- `State` row: label "State" on left (medium weight), current value "Active" below label as secondary muted text. On the right: a segmented icon button group with 3 icons separated by dividers: (1) circular arrows = Active/In-progress, (2) checkmark circle = Completed, (3) X-circle = Cancelled. The currently active state's icon appears visually selected (darker/filled). Tapping any icon changes state immediately — no confirmation required.
- `Date and time` row: label on left. On the right: two tappable accent-colored (purple) values separated by a vertical pipe "|": the date ("Thu, Dec 11, 2025") and the time slot ("All day"). Each is independently tappable. Tapping date opens the Move/date picker modal. Tapping time opens a time picker.
- `Priority` row: label "Priority" + help/info icon "?" (rounded square with question mark). On the right: segmented icon button group with 3 flag icons: blue flag (low), amber/orange flag (medium — shown selected with filled background), red/pink flag (high).
- `Add to timeline` row: label "Add to timeline" + help icon "?". On the right: a standard square checkbox. Unchecked = empty square, checked = filled with checkmark. Controls whether completing this session adds a record to the main Timeline.

**Card 2 — Subtasks:**
- Header: "Subtasks" semibold + "⋯" three-dots overflow menu on the right.
- Below header: "Add item" in muted gray text acting as a tappable button to add a subtask.
- Each subtask row: checkbox + task text.

**Horizontal scrollable chip row (between cards):**
A row of pill-shaped chips scrolling horizontally. Each chip: icon + label + current value. Confirmed chips: "Objectives / Objective", "Time spent / No data", "Repeat / None", "Reminder / On time", and a "+" button at the right. Tapping each chip opens the corresponding sub-editor. This row is optional metadata the user can expand or ignore.

**Card 3 — Note:**
- Header: "Note" semibold + two icon buttons (link/reference icon + insert-template icon) + "+" button.
- Below: "Enter text..." multiline placeholder.

**Card 4 — Comment:**
- Identical layout to Note card. Semantically distinct: Comments are post-event reflections; Notes are planning content.

**Bottom:** Full-width "Done" button (dark purple, white text, rounded pill). Fixed at bottom, does not scroll.

---

### MOVE MODAL — DATE AND TIME PICKER (confirmed from screenshot)

Modal titled "Move" with X close button. Content:

**Day Theme header row:**
- 2–3 emoji icons showing Day Themes for the current date (e.g., briefcase, calendar, train emoji representing Work, Planning, Commute themes). Informational only.
- Current date text ("Dec 11, 2025") with dropdown chevron — tapping opens a full calendar for jumping to distant dates.
- Two icon buttons on the right: infinity symbol (∞) = assign no date / "someday", calendar icon = open full calendar picker.

**Week strip:**
- 7 day cells displayed horizontally (Mon through Sun). Each cell shows: abbreviated day name (top), date number (large, center), abbreviated month name (bottom, only shown for the first visible day or at month boundary). Selected day: filled dark purple/accent background, white text. Other days: light gray card background. The strip is NOT scrollable — use the date header dropdown to navigate to other weeks.

**Time picker (drum/scroll wheel):**
- Three vertical scroll wheel columns: hours | minutes | AM/PM. Center value = selected; adjacent values visible but dimmed (iOS-style drum picker). "Duration" pill button to the right opens a separate duration picker.

**Block name chips:**
- Horizontally scrollable row of pill chips showing the user's named Time Blocks (e.g., "almoço", "ampfy", "organização e planejamento", "cuidar"). These are user-defined. Tapping a block chip assigns the session to that block (overriding exact time). This row makes the blocks system visible and confirms block names are arbitrary user strings.

**Suggestions section:**
- "Suggestions" section header.
- "Today" (date + "All day") and "Tomorrow" (date + "All day") as quick-pick rows. Each row: calendar icon + label + date text + ">" chevron. Tap to apply immediately.

**Done button:** Full-width, fixed at bottom.

---

### NEW HABIT — CREATION FORM (confirmed from screenshots)

Full-screen modal titled "New habit" with X close. Large "Title" placeholder at top (~28pt, light gray). Scrollable form below in rounded-rect cards.

**Schedule card:**
- `Schedule` row: label + help "?" + tappable accent value "Everyday". Tapping opens the Scheduler Repeat picker modal (same as the Repeat modal described in the Scheduler section).
- `Start date` row: label + tappable accent date value. Tapping opens date picker.
- `Time of day` row: label + tappable accent value "All day". Tapping opens block/time picker.

**Completion unit card:**
- Single row: "Completion unit" label + help "?" + tappable accent value "times". Tapping opens a text field with common suggestions (times, glasses, minutes, pages, etc.). The value is a free-text string.

**Slots card:**
- Header: "Slots" + help "?".
- Each slot row: a circle icon (visual slot marker, not a checkbox) + slot number ("1", "2", ...) + "Set reminder" tappable accent text link on the right. Tapping "Set reminder" opens a time picker for that slot's notification.
- "Add slot" tappable text at bottom of card. Up to 10 slots.

**Goal card:**
- `Goal` row: label + tappable accent value. Opens the Goal Type bottom sheet.
- `Per slot completions` row: label + tappable accent numeric value ("1 times"). Completions per slot.
- `Day completion goal` row: label + tappable accent numeric value ("1 times"). Total completions for a successful day.

**Goal Type picker (bottom sheet, 5 options, each row = label + icon):**
1. None — slash-circle icon
2. Date — calendar icon. Reach the habit by a target date.
3. Successful days — checkmark circle icon. Default shows "100 successful days".
4. Completion count — "123" icon. Reach a total completion count.
5. Streak — circular/streak icon. Maintain a streak.

**Actions card:**
- Header: "Actions" label + help "?" + "+" button.
- Empty by default. Tapping "+" opens the Action Type picker (floating popup).

**Action Type picker (floating popup menu, confirmed from screenshot, 7 options):**
1. Add tracking record — auto-creates a Tracking Record in a linked Tracker.
2. Add entry — auto-creates a journal Entry.
3. Add Text note — auto-creates a Text Note.
4. Add Collection item — auto-creates an item in a linked Collection note.
5. View statistics — navigates to statistics view for this habit (navigation action, not creation).
6. View item — navigates to a linked item (any content object).
7. Launch url — opens a specified URL in the device browser.

**Color picker row (standalone strip, no card wrapper):**
Horizontally displayed color swatches as rounded-square (squircle) shapes. Confirmed colors left-to-right: dark red/crimson, light red/rose, dark navy, dark blue, medium blue, light blue/periwinkle, dark green, medium green/teal, light green/mint, black. "⋯" button at right opens extended palette. Tapping immediately applies color.

**Description card:**
- Multiline text area with "Description" label and "Description" placeholder.

**Add button:** Full-width, fixed at bottom. Grayed/disabled until title is entered; becomes active dark-purple once a title exists.

---

### EDIT TRACKER — FORM (confirmed from screenshots)

Full-screen modal titled "Edit tracker" with help icon "?" and X button top-right. Large "Title" placeholder at top.

**"Input fields" section** (purple left-border vertical bar accent + "Input fields" semibold bold label + "⋯" overflow menu button at far right):

Each TrackerSection is a rounded-rect card with:
- "Section title" editable placeholder text at top.
- "⋯" three-dots contextual menu on the right of the section header.
- "Add input field" purple tappable text link below.

"Add section" purple text link appears below all section cards.

**Section three-dots "⋯" contextual menu (floating dropdown, confirmed options):**
Reorder, Archive, Duplicate, Show archives, Delete.

**"Add input field" flow — Type picker (floating popup, title "Type", 6 options):**
1. Text — horizontal lines icon
2. Selection — radio/slider icon
3. Quantity — "¹₂3" icon
4. Checklist — checkbox list icon
5. Checkbox — single checkmark icon
6. Media — photo icon

**"Info" section** (purple left-border bar + "Info" semibold label):
- `Color` row: label + dark gray rounded pill/capsule color swatch on the right. Tapping opens full color picker.
- `Description` row: multiline text area with "Description" placeholder.

**Done button:** Full-width, fixed at bottom. Grayed/disabled until title is entered.

---

### TRACKER / HABIT CHARTS — CONFIRMED FROM SCREENSHOT

**Add chart picker (floating popup, title "Add chart", 4 options):**
1. Line chart — trend line icon
2. Bar chart — histogram icon
3. Pie chart — pie/donut icon
4. Calendar chart — calendar grid icon

**Chart placement contexts:**
Charts appear in two distinct contexts:

1. **Individual tracker or habit detail view:** When opening a specific tracker or habit, the view shows:
   - Monthly calendar at top: a grid of the current month. Days where the item was logged/completed show a colored dot or fill. The month is navigable with previous/next arrows.
   - Timeline below calendar: individual records listed chronologically. Each record row shows: date, note snippet (if present), intensity indicators (if applicable), media thumbnails (if media was attached).
   - "Add chart" button below the timeline: opens the chart type picker. Added charts appear as persistent panels in this view.

2. **Combined Analysis view:** A separate "Analysis" object that aggregates multiple trackers and/or habits. The monthly calendar in this view shows multiple colored dots per day (one color per data source). Charts in this view can overlay multiple data sources as series.

---

## HABIT / TRACKER ACTIONS SYSTEM — FULL SPECIFICATION

Actions are automated behaviors that execute when a habit slot is checked or a tracking record is completed. Configured per-habit or per-tracker at setup time, they fire automatically on the specified trigger.

**Trigger events:**
- Completing any individual slot of a habit (even before daily goal is met)
- Completing the full day goal of a habit
- Saving a tracking record

**Action definitions (confirmed from UI, 7 types):**

1. **Add tracking record** — Opens the Tracking Record creation form for a pre-specified linked Tracker, pre-populated with today's date. Primary mechanism linking Habits to Trackers. Example: completing "Workout" habit slot → opens Workout Tracker form to log reps, duration, intensity.

2. **Add entry** — Opens journal Entry creation form. Example: completing "Meditação" habit → prompts for a brief reflection entry.

3. **Add Text note** — Opens Text Note creation form.

4. **Add Collection item** — Opens form to add a row to a specified Collection note database. Example: completing "Ler" habit → prompts to log the book being read.

5. **View statistics** — Navigates to the statistics/analytics view for this habit or tracker. A navigation action, not a creation action.

6. **View item** — Navigates to a specified linked content object.

7. **Launch url** — Opens a specified URL in the device browser. Example: completing "Idioma" habit → opens the language learning app.

**Multiple actions:** A single habit or tracker can have multiple actions. All fire on the trigger event, in the order they were configured. Each action may have its own sub-configuration (which tracker to create a record in, which URL to open, etc.).

---

## COMBINED ANALYSIS — OBJECT SPECIFICATION

**Purpose:** An Analysis aggregates data from multiple Trackers and/or Habits to reveal correlations and patterns that would not be visible when viewing each source individually. Example: "Análise Menstruação Holística" combining the menstruation tracker (flow level, cramps), mood data from journal entries, and a medication tracker (pain meds) — all shown in a shared monthly calendar and correlated charts.

**Properties:**
- `title` — string, required.
- `description` — optional text.
- `data_sources` — array of DataSourceReference objects. Each has:
  - `source_type` — enum: `tracker_field`, `habit`, `journal_mood`
  - `source_id` — reference to the Tracker, Habit, or journal system
  - `field_id` — for Trackers: which specific InputField to use
  - `color` — the color for this source across all charts and the calendar view
  - `label` — display name for this source in legends
- `charts` — array of Chart configurations (same 4 chart types). Each chart can combine multiple sources as separate series.
- `default_date_range` — optional.

**UI: How the combined view looks:**
- **Monthly calendar** at top: grid of days. Each day cell shows small colored dots — one per data source that has data on that day. Example: day 14 shows red dot (menstruation logged), yellow dot (low mood), blue dot (medication taken).
- **Legend row** below calendar: colored chip per source, labeled.
- **Chart panels** below legend: each chart shows multiple series (one per source), enabling visual correlation.
- **Month navigation:** previous/next arrows to move between months.

**Key design note:** Journal entry mood values are treated as a numeric data source in combined analyses. This bridges the journal and tracker subsystems. The mood value (1–5) is read from the daily note's frontmatter and surfaced as a series alongside tracker data.

---

## OBSIDIAN MARKDOWN SCHEMA — DATA FORMAT SPECIFICATION

This section defines the exact markdown format for each data object when the app uses Obsidian as its data store. The architecture is the "beautiful frontend" model: all data lives in Obsidian `.md` files (portable, plain text, no lock-in). The app reads and writes these files, presenting data as polished UI cards and charts.

### VAULT FOLDER STRUCTURE

```
vault/
├── daily/                    <- All daily notes, named YYYY-MM-DD.md
├── habits/                   <- One file per Habit definition
├── trackers/                 <- One file per Tracker definition
├── tasks/                    <- One file per Task
├── organizers/
│   ├── areas/
│   ├── projects/
│   └── activities/
├── notes/                    <- Text, Outline, Collection notes
└── analyses/                 <- Combined Analysis definitions
```

---

### DAILY NOTE FORMAT (`daily/YYYY-MM-DD.md`)

Daily notes hold habits, tracker records, and journal entries for that day.

```
---
date: 2024-12-11
tags: [daily]

meditar: true
exercitar: false
agua: 6

mood:
  value: 4
  note: "acordei bem disposta"
saude:
  energia: 3
  dor_cabeca: false
  remedio_dor: 1
sono:
  horas: 7.5
  qualidade: boa
menstruacao:
  fluxo: medio
  colica: 3
  tomou_remedio: true
---

# 2024-12-11

## 09:15

Acordei com bastante energia hoje. A meditação foi ótima.

#reflexao #manha
organizers:: [[saude]], [[projeto-fitness]]

---

## 14:30

Reunião com a equipe correu bem.

#trabalho #reuniao
organizers:: [[trabalho]]

---
```

**Parsing rules (critical for correct implementation):**

- YAML frontmatter is between the first and second `---` lines at the top of the file.
- `date` field: canonical date, format `YYYY-MM-DD`.
- **Habit completions:** Any YAML key whose name matches a known habit slug. Value `true`/`false` for boolean habits. Integer or decimal for count-based habits (e.g., `agua: 6` means 6 glasses completed).
- **Tracker records:** Nested YAML object where the outer key is the tracker slug and inner keys are field slugs. Values: boolean (checkbox), integer/decimal (quantity), string (selection/text), or array of strings (checklist, e.g., `sintomas: [dor_cabeca, fadiga]`).
- **Journal entries in the body:** Level-2 headings matching the pattern `## HH:MM` (24-hour format, regex `^## \d{2}:\d{2}$`) mark entry starts. Each entry's content is everything between its heading and either the next `---` separator or the next `## HH:MM` heading.
- **Entry tags:** All `#word` occurrences in the entry body (Obsidian hashtag syntax).
- **Entry organizers:** Inline Dataview field `organizers:: [[LinkName]], [[LinkName2]]` within the entry body.
- **Entry datetime:** Combines the note's `date` frontmatter with the `## HH:MM` heading time to produce a full ISO datetime.

---

### HABIT DEFINITION FILE (`habits/SLUG.md`)

```
---
title: Meditar
slug: meditar
color: "#6B5EA8"
icon: "meditation"
completion_unit: times
daily_goal: 1
slots: 1
schedule: everyday
start_date: 2024-01-01
goal_type: successful_days
goal_value: 100
per_slot_completions: 1
description: "Meditação diária"
organizers: [[saude]]
actions:
  - type: add_entry
    trigger: day_complete
  - type: add_tracking_record
    trigger: slot_complete
    target_tracker: humor
linked_tracker: humor
---
```

**Field notes:**
- `slug`: lowercase, hyphen-separated, matches filename. Used as the key in daily note YAML.
- `schedule`: string for simple cases ("everyday", "weekdays", "weekends") or a nested YAML object for complex cases (see Scheduler format below).
- `goal_type`: "none", "date", "successful_days", "completion_count", "streak".
- `actions`: array of action objects with `type`, `trigger` ("slot_complete" or "day_complete"), and optional `target_tracker`.

---

### TRACKER DEFINITION FILE (`trackers/SLUG.md`)

```
---
title: Saúde Geral
slug: saude
color: "#E85D5D"
icon: "health"
description: "Acompanhamento geral de saúde"
organizers: [[saude]]
sections:
  - title: "Físico"
    fields:
      - slug: energia
        label: "Nível de energia"
        type: quantity
        unit: "pontos"
      - slug: dor_cabeca
        label: "Dor de cabeça"
        type: checkbox
      - slug: remedio_dor
        label: "Remédio para dor"
        type: quantity
        unit: "comprimidos"
  - title: "Mental"
    fields:
      - slug: humor
        label: "Humor"
        type: selection
        options: [muito_ruim, ruim, neutro, bom, muito_bom]
---
```

**Input field type → YAML value mapping (in daily notes):**
- `checkbox` → `true` or `false`
- `quantity` → integer or decimal number
- `selection` → string matching one of the `options` values
- `checklist` → YAML array: `[opcao1, opcao2]`
- `text` → quoted string
- `media` → not stored in frontmatter; stored as Obsidian image embed `![[filename.jpg]]` in a dedicated section in the daily note body

---

### TASK FILE (`tasks/SLUG.md`)

```
---
title: Comprar equipamento de treino
slug: comprar-equipamento
stage: todo
priority: medium
start_date: 2024-12-01
end_date: 2024-12-31
organizers: [[projeto-fitness]], [[saude]]
tags: [compras]
---

Notas e contexto.

## Subtasks

- [ ] Pesquisar modelos
- [x] Definir orçamento
- [ ] Comparar lojas
- [ ] Realizar compra
```

- `stage`: "idea", "todo", "in_progress", "pending", "finalized".
- `priority`: "low", "medium", "high".
- Subtasks: standard markdown checkbox syntax `- [ ]` / `- [x]`, parsed from the `## Subtasks` section.

---

### COMBINED ANALYSIS FILE (`analyses/SLUG.md`)

```
---
title: Análise Menstruação Holística
slug: menstruacao-holistica
sources:
  - type: tracker_field
    tracker: menstruacao
    field: fluxo
    color: "#E85D5D"
    label: "Fluxo"
  - type: tracker_field
    tracker: menstruacao
    field: colica
    color: "#FF8C8C"
    label: "Cólica"
  - type: tracker_field
    tracker: saude
    field: dor_cabeca
    color: "#FFB347"
    label: "Dor de cabeça"
  - type: tracker_field
    tracker: saude
    field: remedio_dor
    color: "#4ECDC4"
    label: "Remédio"
  - type: journal_mood
    color: "#6B5EA8"
    label: "Humor"
charts:
  - type: calendar_chart
    title: "Visão mensal"
    sources_all: true
  - type: line_chart
    title: "Tendências"
    sources: [humor, colica]
  - type: bar_chart
    title: "Frequência de sintomas"
    sources: [dor_cabeca, remedio_dor]
---
```

---

### SCHEDULER YAML FORMAT (inside habit or task frontmatter)

```yaml
# Simple — plain string
schedule: everyday
schedule: weekdays
schedule: weekends

# Number of days — every 3 days
schedule:
  type: number_of_days
  interval: 3

# Days of the week
schedule:
  type: days_of_week
  days: [monday, wednesday, friday]

# Number of months — on the 1st and 15th
schedule:
  type: number_of_months
  interval: 1
  days_of_month: [1, 15]

# Number of days per period — twice a month
schedule:
  type: days_per_period
  count: 2
  period: month       # week | month | year
  starting_day_offset: 10
  interval_between_days: 5

# Multiple schedulers
schedule:
  - type: days_of_week
    days: [monday, wednesday, friday]
  - type: number_of_months
    interval: 1
    days_of_month: [1]
```

---

### APP PARSING ALGORITHM — STEP BY STEP

The app reads Obsidian files and builds its internal data model as follows:

**On startup / sync:**
1. Load all Habit definition files from `habits/`. Build a map: `habit_slug → HabitDefinition`.
2. Load all Tracker definition files from `trackers/`. Build a map: `tracker_slug → TrackerDefinition` (with its field schema).
3. Load all Organizer files. Build organizer trees.
4. Load all Task files. Build task list with stage and subtask completion states.
5. Load all Analysis files. Build analysis configurations.

**Per daily note:**
1. Parse YAML frontmatter. Extract `date`.
2. For each YAML key that matches a habit_slug: record `HabitCompletion(habit_slug, date, value)`.
3. For each YAML key that matches a tracker_slug: record `TrackingRecord(tracker_slug, date, {field_slug: value, ...})`. Validate field types against the tracker's schema.
4. Parse the body. Find all `## HH:MM` headings. For each: extract entry content, compute `entry_datetime = date + HH:MM`, parse tags and organizers. Create `JournalEntry(id, datetime, body, tags, organizers)`.

**Timeline construction:**
- Merge all JournalEntries, HabitCompletions (where completed = true), and TrackingRecords into a single chronological list sorted by datetime descending (newest first).
- Group by day for day-level views.
- Each item type renders as a distinct card design.

**Streak calculation:**
- For a habit on date D: streak = count of consecutive days before and including D where `HabitCompletion.successful == true` (where `successful = completion_count >= habit.daily_goal`).

**Analysis computation:**
- For a combined analysis with date range [start, end]:
  - For each `tracker_field` source: collect `{date: value}` from all TrackingRecords in range where tracker_slug matches.
  - For `journal_mood` source: collect `{date: mood.value}` from each day's frontmatter.
  - For `habit` source: collect `{date: completion_count}` from HabitCompletions in range.
  - Render calendar: for each day, show a colored dot per source that has a non-null value.
  - Render charts: each chart series is one source's `{date: value}` array.

---

### MARKDOWN FORMAT QUICK REFERENCE

| Data | File | Format |
|---|---|---|
| Habit (boolean) | daily/YYYY-MM-DD.md frontmatter | `slug: true` |
| Habit (count) | daily/YYYY-MM-DD.md frontmatter | `slug: 6` |
| Tracker record | daily/YYYY-MM-DD.md frontmatter | `tracker_slug:\n  field_slug: value` |
| Journal entry | daily/YYYY-MM-DD.md body | `## HH:MM\n\nbody\n\n---` |
| Entry tags | Inside entry body | `#tagname` |
| Entry organizers | Inside entry body | `organizers:: [[Name]]` |
| Task subtask | tasks/SLUG.md body under `## Subtasks` | `- [ ] text` / `- [x] text` |
| Habit definition | habits/SLUG.md | YAML frontmatter |
| Tracker definition | trackers/SLUG.md | YAML frontmatter with sections/fields |
| Analysis definition | analyses/SLUG.md | YAML frontmatter with sources + charts |
| Organizer | organizers/TYPE/SLUG.md | YAML frontmatter |


---

## SCREENSHOT-CONFIRMED: DASHBOARD AND GOAL VIEWS (v2 update)

---

### DASHBOARD SCREEN (confirmed from screenshot)

The Dashboard is a scrollable screen (not a tab bar root with fixed content — it scrolls vertically). Layout from top to bottom:

**Header row:**
- Purple left-border vertical accent bar + "Dashboard" semibold title (large, ~24pt).
- Top-right: a settings/customize icon (horizontal sliders icon, ≈ 3 horizontal lines with circles = filter/customize). Tapping opens dashboard panel management (add/remove/reorder panels).

**Shortcuts panel (first card):**
- Card with a lightning bolt icon + "Shortcuts" label (semibold) on the left. "⋯" three-dots overflow on the right.
- Below the header: a horizontal row of 5 large icon buttons, each with a small label below:
  - Calendar icon + "Calendar" label
  - Spiral/habit icon + "Habits" label
  - Note/sticky icon + "Notes" label
  - Tracker icon + "Trackers" label
  - Pencil/write icon + "Write I..." label (truncated, likely "Write Journal" or "Write Item")
- These are quick navigation shortcuts. Tapping each navigates to that section of the app.
- The Shortcuts panel itself is a Dashboard Panel (panel type: shortcuts). It can be customized via the ⋯ menu.

**Timeline section (embedded in Dashboard):**
- Purple left-border accent bar + "Timeline" bold title.
- Top-right of Timeline section: two icon buttons: sort icon (down-arrow with lines = sort order) and filter icon (funnel). These filter/sort the embedded timeline without leaving the dashboard.
- Date group header: a rounded pill label showing the date ("Thu, Apr 30") in semibold text, on a light gray/muted background. This is a sticky or non-sticky section divider.
- Below each date header: content cards for that day.

**Goal cards in timeline (confirmed visual design):**
- Cards have a solid dark colored background matching the goal's assigned color (e.g., dark brown/mahogany for "Registrar minha saúde", dark blue/navy for "Me exercitar").
- Full-width card with rounded corners (16pt radius approximately). Light/white text on dark background.
- **Top row of chips (within the card):** horizontally arranged small rounded pill chips: time chip ("11:59 PM"), Snapshot action chip (camera icon + "Snapshot"), Goal icon chip (target/concentric circles icon + "Goa..." truncated), and "⋯" overflow chip. All chips have a semi-transparent dark background (slightly lighter than the card background). Text is white/light.
- **Title:** Large white bold text below the chip row (e.g., "Registrar minha saúde", "Me exercitar"). ~18–20pt, semibold.
- **Subtitle row:** Smaller white/light text showing progress metadata: "Day 30 | 0 days remaining | 0%". Fields: current day number of the goal, days remaining until due date, completion percentage.
- No footer row — the card ends after the subtitle.

---

### GOAL DETAIL VIEW (confirmed from screenshot, dark mode)

Opened by tapping a Goal card. Full-screen view (not a modal — it is a pushed/navigated screen, confirmed by absence of X button in screenshot; would have a back arrow in top-left nav bar). Title area at very top: large bold white text "goal title" + below it a smaller muted label "Goal" (the object type label).

**Properties card (rounded rect, dark gray background):**
All property rows within one card, each row: label on left (muted gray text) + tappable value on right (accent purple text for editable values, or muted gray for non-set values).

- `State` row: label "State" + value "Active" with a dropdown chevron "∨" on the right. Tapping opens a state picker (likely: Active, Completed, Cancelled, On Hold). This is a dropdown/select, NOT a segmented icon group (different from Calendar Session state which uses icon buttons).
- `Start date` row: label + purple accent value ("Tue, Apr 28"). Tappable — opens date picker.
- `Due date` row: label + gray muted value "None". Tappable — opens date picker.
- `Default Time of day` row: label + purple accent value "All day". Tappable — opens block/time picker.
- `Progress` row: label + gray muted value "Unknown". This is a derived or manually-set field. When KPIs are configured, this shows the computed progress percentage. When no KPIs are set, shows "Unknown".

**Subtasks card:**
- Header: "Subtasks" semibold + a progress counter "0/0" (completed/total) on the right + "⋯" three-dots overflow menu.
- Below: "Add subtask" tappable gray text link.

**Horizontal scrollable chip row (between Subtasks and Calendar cards):**
Confirmed chips (each is a pill with icon + label + value on second line):
- "Primary KPIs / Empty" — 123 icon with checkmark.
- "Other KPIs / Empty" — 123 icon variant.
- "Quick access / Empty" — lightning bolt icon.
- "Comments / Empty" — speech bubble icon.
The row scrolls horizontally if more chips exist. Each chip tapped opens its respective editor/viewer.

**Calendar card:**
- Header: "Calendar" label on left. On the right: a row of stat chips: [timer/session icon + "0"], [snapshot icon + "0"], [number "0"], ["00:00"]. These show counts of: scheduled sessions, snapshots taken, completions (?), and total time spent on this goal.
- Below: a full calendar grid for the current month ("May 2026"). Column headers: Mon Tue Wed Thu Fri Sat Sun. Each day is a number. Today ("5") is highlighted with a rounded-rect outline/border. Days with scheduled sessions would show colored indicators. The calendar is embedded inline (not a separate screen).
- The calendar is vertically scrollable as part of the screen — the user scrolls down to see it; it's not fixed.

---

### KPI SOURCE PICKER (confirmed from screenshot)

Titled "KPI source" — this is the picker that appears when adding a KPI to a Goal. It is a floating popup or bottom sheet (dark background in screenshot, matching dark mode). Lists 7 confirmed source types (each row: label + icon):

1. **Subtasks** — checkbox/tick icon. KPI measures subtask completion count or percentage for this goal.
2. **Tracker** — tracker icon (squiggly line in rounded square). KPI pulls data from a Tracker's input field.
3. **Habit** — habit spiral icon. KPI measures a habit's streak, successful days, or completion count.
4. **Collection** — collection/database icon. KPI measures items in a Collection note (e.g., count of completed items).
5. **Entry** — entry/journal icon (document with heart). KPI measures journal entry count related to this goal.
6. **Time spent** — timer/stopwatch icon. KPI measures accumulated time from Pomodoro/timer sessions linked to this goal.
7. **Others** — three-dots "⋯" icon. Implies additional KPI types available beyond the main 6 (likely: custom numeric input, goal completion percentage, etc.).

**Implementation note:** The KPI source selection drives which secondary picker appears next. Selecting "Tracker" → prompts to choose which Tracker, then which field. Selecting "Habit" → prompts to choose which Habit, then which metric (streak, successful days, completion count). Selecting "Collection" → prompts to choose which Collection note and which property to count.

---

## CUSTOM FEATURES (user-specified additions to base app)

The following features are custom additions to the Journal.it-inspired implementation, specified by the user. They extend or modify behaviors described above.

---

### FEATURE: "DAYS SINCE" TAG ON HABITS

Every habit in every list view and the planner shows a small status badge indicating how long ago it was last completed. This badge functions as a quick health indicator for the habit.

**Badge properties:**
- `days_since_last_completion` — derived integer. Computed at runtime from `completion_history`. If the habit was completed today: 0. If last completed yesterday: 1. If never completed: null (show "—").
- `badge_state` — derived enum:
  - `completed_today` (days_since = 0): badge is gray/muted. Text: "today" or "1 day since" (showing current day). The user confirmed: when done, shows gray "1 day since".
  - `missed_1_plus` (days_since >= 1): badge is red. Text: "N days since" where N is the integer count. The color intensifies as N grows (optional: use darker red or higher opacity at higher N values, but red at all values >= 1).
  - `never_completed` (null): badge shows "—" or is absent.

**Badge visual design:**
- Small rounded pill/chip, positioned in the top-right corner of the habit card, or as a trailing element in the habit list row.
- Text: "N days since" — always lowercase, concise.
- Font: ~12pt, medium weight.
- Colors: gray (#888 or similar muted gray) for completed_today; red (#E53935 or similar) for missed_1_plus.
- The badge updates automatically at midnight (when the date changes, all habits' badges recalculate).

**Where badge appears:**
- In the Habits list/organizer view — on each habit's row.
- In the Planner — on each Habit Reminder card within the day view.
- In the Dashboard's "Today's Habits" panel (if present).
- In the habit's own detail view (prominently, next to or below the streak count).

**Relationship with streak:** The streak count and the "days since" badge are complementary. Streak shows consecutive successes; "days since" shows recency of last action. A habit with streak=30 but days_since=3 (red) is clearly at risk of breaking the streak. Both values are displayed simultaneously.

**Obsidian markdown storage:** No extra frontmatter field needed. `days_since` is always derived from the last entry in `completion_history` that has a truthy completion value. The calculation reads the sorted daily notes and finds the most recent date where `habit_slug: true` (or numeric value > 0).

---

### FEATURE: MOOD AS A FULL OBJECT WITH GRAPHS

Mood is elevated from a simple property of journal entries to a first-class object in the system, with its own definition file, graphing capability, and Obsidian page integration.

#### MOOD DEFINITION OBJECT

Each mood level is defined in a Mood Definition file. The mood system is fully editable and extensible — users can add new mood levels, change names, associate emojis, and configure graph appearance.

**MoodDefinition properties:**
- `id` — string, unique slug (e.g., "great", "good", "neutral", "bad", "terrible").
- `label` — string, display name (e.g., "Great", "Good", "Neutral", "Bad", "Terrible").
- `emoji` — string, a single emoji character associated with this mood level (e.g., "😄", "🙂", "😐", "😕", "😞"). The emoji is shown in the mood picker UI and in journal entry cards as a visual indicator. The emoji is NOT rendered inside charts/graphs — it is only shown in pickers and entry metadata to avoid cluttering visualizations.
- `numeric_value` — integer, the numeric representation for graphing purposes (e.g., 5 for "Great", 4 for "Good", 3 for "Neutral", 2 for "Bad", 1 for "Terrible"). User-definable. The graph uses only this number; the emoji is decorative.
- `color` — hex color string, used for calendar dots, chart series color, and badge color for this mood level.
- `order` — integer, display order in the mood picker (lowest to highest, or configurable).

**Default mood scale (5 levels, customizable):**
1. Terrible (value: 1, emoji: 😞, color: #E53935)
2. Bad (value: 2, emoji: 😕, color: #F57C00)
3. Neutral (value: 3, emoji: 😐, color: #9E9E9E)
4. Good (value: 4, emoji: 🙂, color: #43A047)
5. Great (value: 5, emoji: 😄, color: #1E88E5)

User can add more levels (e.g., a 7-point or 10-point scale), rename existing ones, change emojis and colors. Minimum: 2 levels. Maximum: recommended 10 (UI gets crowded beyond that, but no hard limit).

#### MOOD AS AN OBSIDIAN PAGE

Each Mood Definition is stored as a separate Obsidian markdown file in a `moods/` folder. This makes each mood level a proper Obsidian node with backlinks — any journal entry that uses a mood value creates a link to that mood's page, so the user can open "moods/good.md" in Obsidian and see all journal entries where mood was "Good" in the backlinks panel.

**Mood definition file format (`moods/SLUG.md`):**

```
---
type: mood_definition
id: good
label: Good
emoji: "🙂"
numeric_value: 4
color: "#43A047"
order: 4
---

# Good

This mood level represents feeling positive and productive.

<!-- Obsidian backlinks panel will show all journal entries where mood:: [[good]] -->
```

**In daily notes, mood is stored as a WikiLink to the mood definition file:**
In YAML frontmatter (if a single mood for the whole day) OR as an inline Dataview field within each journal entry:

```
## 09:15

Acordei bem disposta.

mood:: [[good]]
organizers:: [[saude]]
#manha
```

By using `[[good]]` (WikiLink), Obsidian's backlinks system automatically registers this entry as a reference to `moods/good.md`. Opening `moods/good.md` in Obsidian shows all entries in the Linked Mentions / Backlinks pane.

#### MOOD GRAPHS

Mood data (the `numeric_value` from each entry's mood reference) can be visualized as:

- **Line chart** — mood over time (x = date, y = numeric_value). Shows trends and patterns. Multiple entries per day are averaged.
- **Bar chart** — mood distribution (x = mood label, y = count of entries with that mood). Shows frequency.
- **Calendar chart** — monthly grid where each day is color-coded by the average mood numeric_value for that day, using each mood level's color.
- **Combined analysis** — mood as a data source in a Combined Analysis (e.g., correlate mood with menstruation cycle, sleep hours, exercise).

**Graph configuration options (user-editable, stored in the mood system or in analysis files):**
- Date range (this week, this month, last 30 days, custom).
- Aggregation method (for multiple entries per day: average, max, min, last entry).
- Show trend line (moving average overlay on line chart).
- Series label: uses `label` field (e.g., "Good"), NOT the emoji.
- Color per series: uses the mood definition's `color` field.

**Where graphs appear:**
- In the "Mood" section within the app's dedicated Mood view (accessible from Dashboard or a shortcut).
- In Combined Analyses that include `journal_mood` as a data source.
- In the mood definition detail view (opening `moods/good.md` from within the app shows that level's history as a chart).

**Adding/editing mood definitions from the app:**
- Settings → Mood → Mood Levels section.
- List of current mood levels in order. Each row: emoji + label + color swatch + numeric value.
- "+" button at bottom adds a new level (opens a form: label, emoji picker, color picker, numeric value input).
- Tap any existing level to edit its label, emoji, color, numeric value, and order.
- Long press → drag handle to reorder.
- Swipe left → delete (with confirmation: "Existing entries that use this mood level will retain the reference but the level will no longer appear in pickers").
- Changes to mood definitions automatically update all charts (since charts reference numeric_value, which is recalculated on next render).

---

### FEATURE: UNIVERSAL OBJECT DETAIL VIEW

Every content object in the app (Entry, Task, Goal, Habit, Tracker, Tracking Record, Note, Calendar Session, Reminder, Mood) has a standardized detail view that opens when the object is tapped from any list or card. This detail view is consistent in structure across all object types, with type-specific sections added as appropriate.

#### DETAIL VIEW LAYOUT

**Header (fixed, does not scroll):**
- Back arrow "‹" on the left — tapping navigates back to the previous screen.
- Object type label in center (e.g., "Goal", "Habit", "Entry") — muted small text below the title, NOT in the nav bar.
- "⋯" three-dots overflow menu button on the right.

**Title (below nav bar, part of scrollable content):**
- Large bold text displaying the object's title. If the object type has a type label, it appears as smaller muted text directly below the title (e.g., "goal title" in large bold, "Goal" in small muted gray below).

**Properties section (scrollable):**
- Grouped rounded-rect card containing all properties as label-value rows.
- Each value is tappable to edit (opens the appropriate picker/input).
- Properties are shown in a consistent order: primary properties first (state, dates), then secondary (priority, time of day, progress), then system-derived (created at, updated at).

**Type-specific sections:**
- Each object type adds its own specialized sections below the properties card (e.g., Goals add KPIs and Calendar; Habits add completion history and slots; Trackers add input fields and charts; Entries add body content).

**Mentions / Backlinks section:**
This section appears in every object's detail view, below all type-specific content. It is titled "Mentions" (or "Backlinks") with a link icon. It shows all other objects in the system that reference this object (either via organizer tags, @-mentions in rich text, or WikiLink references in markdown).

- Section header: "Mentions" + count badge (e.g., "Mentions (4)").
- Each mention is a tappable row: icon representing the referencing object's type + title + date/time. Tapping navigates to that referencing object's detail view.
- If no mentions: shows "No mentions yet" empty state.
- This data is derived from two sources:
  1. In-app organizer references (objects that have this object in their `organizers` array).
  2. Obsidian WikiLink backlinks (objects whose markdown file contains `[[this-object-slug]]`).

**Three-dots "⋯" overflow menu (consistent across all object types):**
This menu appears in the top-right of every detail view. Tapping shows a floating dropdown or bottom sheet with these actions:

1. **Edit** — opens the full edit form for this object (same form as creation, but pre-filled with current values).
2. **Delete** — shows a confirmation alert: "Delete [object title]? This action cannot be undone." Alert has "Delete" (red, destructive) and "Cancel" buttons.
3. **Open in Obsidian** — opens the corresponding `.md` file in the Obsidian app directly. Uses Obsidian's URL scheme: `obsidian://open?vault=VAULT_NAME&file=PATH_TO_FILE`. This is a deep link — if Obsidian is installed, it opens directly to the file. If not installed, shows a message.
4. (Object-specific actions may appear above these three, e.g., "Duplicate", "Archive", "Share", "Take Snapshot" for relevant types.)

**"Open in Obsidian" — implementation requirements:**
- Every content object must have a corresponding Obsidian file path stored as a property (`obsidian_path`).
- For daily-note-hosted content (journal entries, habit completions, tracker records), the path points to the daily note file, with an optional anchor to the specific section: `obsidian://open?vault=MyVault&file=daily/2024-12-11#09:15`.
- For object definition files (habits, trackers, tasks, goals), the path points to the definition file: `obsidian://open?vault=MyVault&file=habits/meditar`.
- The app must know the vault name (configurable in app settings: Settings → Obsidian Integration → Vault Name).
- On Android, this uses an Intent to open the URL. On iOS, `UIApplication.open(url)`. The system routes it to the Obsidian app if installed.

**Obsidian page requirement for all objects:**
Every content object must have exactly one corresponding Obsidian `.md` file. This is required for the "Open in Obsidian" feature and for backlinks to work correctly. Objects that Journal.it has traditionally stored only as frontmatter properties in daily notes (like individual habit slots) must be surfaced as named files if they are to participate in the backlink graph. Objects that are naturally file-based (Habit definitions, Tracker definitions, Tasks, Notes) already satisfy this. Journal entries need a canonical anchor within the daily note file.

---

## UPDATED OBSIDIAN SCHEMA: JOURNAL ENTRIES (reconciled with v2 PDF)

The PDF document (v2) uses `### HH:MM` (level 3 heading, not level 2) for journal entries within daily notes. This reconciles with an alternative schema structure where `## Journal Entries` is a level-2 section header and individual entries are level-3 subsections within it.

**Recommended canonical format (reconciled between both versions):**

```
---
date: 2026-05-05
type: daily_note
tags: [daily]

meditar: true
agua: 6
mood_overall: 4

menstruacao:
  fluxo: medio
  colica: 3
  tomou_remedio: true
sono:
  horas: 7.5
  qualidade: boa
---

# 2026-05-05

## Journal Entries

### 08:30

Acordei com bastante energia.

mood:: [[good]]
organizers:: [[saude]], [[bem-estar]]
#manha #reflexao

---

### 14:30

Reunião produtiva hoje.

mood:: [[neutral]]
organizers:: [[trabalho]]
#trabalho

---

## Habits

- [x] Meditar (Slot 1: 08:00) [tracker:: [[humor]]]
- [x] Água (6/8 glasses)
- [ ] Exercitar

## Trackers

### Menstruação
- **Fluxo:** Médio
- **Cólica:** 3
- **Tomou remédio:** Sim

### Sono
- **Horas:** 7.5
- **Qualidade:** Boa

## Tasks

- [x] Finalizar relatório [priority:: High] [organizer:: [[trabalho]]]
- [ ] Ligar para cliente [priority:: Medium] [organizer:: [[trabalho]]]
```

**Parsing rule reconciliation:**
- Journal entries: found under `## Journal Entries` section, each entry starts with `### HH:MM`.
- Mood within entries: inline Dataview field `mood:: [[mood-slug]]` using WikiLink to the mood definition file. This creates the Obsidian backlink.
- Habits: under `## Habits` section, markdown checklists. Each slot can be a separate list item. `[tracker:: [[TrackerName]]]` links the habit slot to a tracker.
- Trackers: under `## Trackers` section. Each tracker is a `### TrackerName` subsection with key-value pairs.
- Tasks: under `## Tasks` section, markdown checklists with inline Dataview fields for properties.

**The YAML frontmatter retains numeric/computed values for fast querying by Dataview:**
- `mood_overall` in frontmatter: the average (or dominant) mood numeric value for the day, for use in Dataview TABLE queries and Obsidian Tracker plugin queries.
- Habit booleans in frontmatter: for fast habit completion queries without parsing the body.
- Tracker numeric values nested under tracker slug: for fast chart generation.

**Obsidian Charts plugin format (for rendering charts in Obsidian itself):**

Charts embedded in analysis notes or tracker/habit definition files use the Obsidian Charts plugin syntax. The app generates these blocks dynamically.

```
```chart
type: line
labels: [2026-05-01, 2026-05-02, 2026-05-03, 2026-05-04, 2026-05-05]
series:
  - title: Cólica
    data: [2, 4, 3, 1, 3]
  - title: Humor
    data: [4, 3, 3, 4, 4]
width: 80%
beginAtZero: false
```
```

For calendar/heatmap charts, use the Obsidian Tracker plugin syntax (separate plugin):

```
```tracker
searchType: frontmatter
searchTarget: menstruacao.colica
folder: daily
startDate: 2026-04-01
endDate: 2026-05-31
month:
  startWeekOn: Mon
  color: red
  colorByValue: true
```
```

**Dataview query example (mood trend):**

```
```dataview
TABLE mood_overall AS "Humor", date AS "Data"
FROM "daily"
WHERE mood_overall
SORT file.name ASC
```
```

**Dataview query example (habit streak calculation — requires DataviewJS):**

```
```dataviewjs
const folder = "daily";
const habitSlug = "meditar";
const notes = dv.pages(`"${folder}"`).sort(p => p.file.name, "desc");
let streak = 0;
for (const note of notes) {
    if (note[habitSlug] === true) {
        streak++;
    } else {
        break;
    }
}
dv.paragraph(`Streak atual: **${streak} dias**`);
```
```

---

## UPDATED: OBJECT FILE → OBSIDIAN PAGE MAPPING (complete table)

Every object type maps to exactly one Obsidian file type. This table is the authoritative reference.

| Object Type | Obsidian File Location | File Name Pattern | Has Backlinks? |
|---|---|---|---|
| Journal Entry | daily/YYYY-MM-DD.md | YYYY-MM-DD.md | Yes (via mood:: and organizers:: links) |
| Task | tasks/SLUG.md | kebab-case-title.md | Yes |
| Goal | goals/SLUG.md | kebab-case-title.md | Yes |
| Habit (definition) | habits/SLUG.md | kebab-case-title.md | Yes |
| Tracker (definition) | trackers/SLUG.md | kebab-case-title.md | Yes |
| Tracking Record | Embedded in daily/YYYY-MM-DD.md under ## Trackers | N/A (uses daily note as anchor) | Via daily note |
| Text Note | notes/SLUG.md | kebab-case-title.md | Yes |
| Outline Note | notes/SLUG.md | kebab-case-title.md | Yes |
| Collection Note | notes/SLUG.md | kebab-case-title.md | Yes |
| Calendar Session | planner/YYYY-MM-DD-SLUG.md OR in daily note | YYYY-MM-DD-session-title.md | Yes |
| Reminder | Embedded in daily note or planner file | N/A | Via daily note |
| Mood Definition | moods/SLUG.md | mood-slug.md | Yes (all entries link back to mood file) |
| Area | organizers/areas/SLUG.md | slug.md | Yes |
| Project | organizers/projects/SLUG.md | slug.md | Yes |
| Activity | organizers/activities/SLUG.md | slug.md | Yes |
| Label | organizers/labels/SLUG.md | slug.md | Yes |
| Person | organizers/people/SLUG.md | person-name.md | Yes |
| Place | organizers/places/SLUG.md | place-name.md | Yes |
| Combined Analysis | analyses/SLUG.md | kebab-case-title.md | Yes |

**Consequence:** Every tap on any item in the app can open a real Obsidian file. The "Open in Obsidian" action always has a valid target. The graph view in Obsidian shows the full web of connections between all objects.


---

## USER BRAINDUMP — FULL FEATURE SPECIFICATION
### Translated into UI/UX implementation language, matching the style of the rest of this document.

---

## SECTION A: FOUNDATIONAL ARCHITECTURE DECISIONS

These decisions apply globally to the entire app and must be considered before implementing any individual feature.

---

### A1. FLAT OBSIDIAN VAULT STRUCTURE (no deep folder hierarchy)

All files created by the app are placed in a single folder (configurable, default: `app/`). Objects are NOT organized into subfolders by type. Instead, every file has a `type` property in its YAML frontmatter (e.g., `type: task`, `type: habit`, `type: tracker`) and a `categories` property (a YAML array of WikiLinks, e.g., `categories: ["[[tasks]]", "[[trabalho]]"]`). The app filters by these properties using Dataview queries. The user can also browse all files in Obsidian and see them organized by their `categories` and `type` properties.

**Consequence for implementation:** The app must NOT assume folder location when reading object type. It must read the `type` frontmatter field. When creating a new object, the app writes it to the configured app folder with the correct `type` field. If the user moves the file in Obsidian, the app must still find it by scanning the vault for the `type` and `id` fields.

**Categories system:** Every object type has a set of default categories that are automatically added when the object is created:
- Tasks automatically get `categories: ["[[tasks]]"]`.
- Projects automatically get `categories: ["[[projects]]"]` and tag `#projeto`.
- Habits automatically get `categories: ["[[habits]]"]`.
- The user can add MORE categories to any individual object (e.g., a specific project gets `categories: ["[[projects]]", "[[trabalho]]", "[[desenvolvimento]]"]`).
- Category definitions are managed in the app's Settings → Categories page (see Section B3).

**Tasks Plugin compatibility:** The app uses Obsidian's Tasks plugin format for task checkboxes. Task items in daily notes and task definition files use the Tasks plugin's extended markdown syntax: `- [ ] Task title [due:: 2024-12-31] [priority:: high]`. This ensures that opening daily notes in Obsidian itself shows tasks in the Tasks plugin's native interface.


---

### A2. OFFLINE-FIRST SYNC WITH ONEDRIVE

**Sync architecture:**
- Primary storage: OneDrive (the Obsidian vault is a OneDrive-synced folder).
- The app attempts to write every change to OneDrive immediately.
- If OneDrive is unreachable: the change is written to the local device storage (a local copy of the vault) and queued for sync.
- When OneDrive becomes available again (either by network reconnection OR by the user opening the app): all queued changes are pushed to OneDrive in order.
- The app shows a sync status indicator in the main header: a small cloud icon with states: synced (filled cloud), syncing (animated cloud), offline (cloud with slash), error (cloud with exclamation mark).

**Conflict resolution:** When the app detects that the local version and the OneDrive version of a file have both changed since the last sync (a true conflict):
1. The app does NOT silently pick a winner.
2. It creates a backup copy of both versions in a `_conflicts/` folder in the vault (e.g., `_conflicts/2024-12-11-conflict-1.md`).
3. It shows an in-app notification: a banner or dialog saying "Conflict detected in [filename]. Which version do you want to keep?" with a side-by-side comparison of the changed fields (not raw markdown — a visual diff of the structured properties).
4. Options: "Keep local version", "Keep OneDrive version", "Keep both (merge)". If "merge" is selected, the app attempts an automatic merge; if it cannot, it shows the fields in conflict and lets the user resolve each one.
5. The `_conflicts/` folder is automatically cleaned of files older than 30 days (configurable in Settings → Sync).

**Backup:** In addition to the OneDrive vault itself, the app generates a backup ZIP of the entire vault periodically (configurable: daily, weekly, on each app open). The backup is stored either in a `_backups/` folder on OneDrive or locally on the device. Backups older than the configured retention period are deleted.

---

### A3. UNIVERSAL LINKING

Every object in the app can link to and be linked from any other object. This applies to ALL objects with no exceptions. Links appear in two forms:

**Property link:** A dedicated `links` property in the object's frontmatter (YAML array of WikiLinks). In the app, this shows as a "Links" section in the object detail view with chips for each linked object. Tapping a chip navigates to that object's detail view.

**Inline mention:** A `[[WikiLink]]` embedded inside any rich text body (journal entry body, task notes, habit description, etc.). In Obsidian this creates a backlink. In the app, inline mentions are detected and shown in the "Mentions" section of the referenced object's detail view.

**Linking UI:** Wherever a link can be created (in any text field, in the Links property), the user types `[[` to trigger the link picker. The link picker is a floating searchable list:
- Initially shows pages sorted by most recently modified.
- As the user types, filters by page title (fuzzy match).
- Each row shows: page title + the content of the `categories` property as small chips (so the user can distinguish between two pages with similar titles by seeing their category).
- If the user types a title that doesn't match any existing page, a "Create new page: [typed text]" option appears at the bottom. Tapping it creates a new stub page with that title and the appropriate type.
- Pressing Enter or tapping a result inserts the WikiLink.

**Backlinks display in all object detail views:** Every detail view has a "Mentions" section (described in the Universal Object Detail View feature). This section shows all pages in the vault that contain `[[this-object-title]]`, regardless of whether they are app-managed objects or user-created Obsidian notes. For user-created Obsidian notes (not managed by the app), the mention row shows an Obsidian icon and tapping it opens the file in Obsidian (via URL scheme). For app-managed objects, tapping opens the object's detail view within the app.

---

### A4. NAVIGATION HISTORY ("MEMORY OF WHERE I CAME FROM")

The app maintains a navigation stack with unlimited depth. Every screen transition is recorded.

**Back button behavior:** Every screen (except the 5 root tab screens) has a back arrow "‹" in the top-left of the navigation bar. Tapping it navigates to the exact previous screen in the stack, restoring scroll position and any unsaved form state. This is standard push-navigation behavior, but explicitly: the back button navigates to the previous screen, not to the parent category or a hardcoded destination.

**Navigation stack indicator (optional but recommended):** A breadcrumb trail visible in the navigation bar when the stack is deeper than 2 levels. Example: "Habits › Meditar › Tracking Record". Each breadcrumb is tappable and jumps directly to that level.

**Cross-section navigation:** When navigating from a Timeline card (on the Home/Dashboard screen) to a Goal detail, then from the Goal detail to a KPI, then from the KPI to a Habit — the back button at each level returns exactly one step back through this path, regardless of which tab the user started on.

---

### A5. UNDO ON DELETE/ARCHIVE

Whenever the user deletes or archives any object, a snackbar (small bottom toast popup) appears immediately:

- Visual: a dark rounded-rect toast at the bottom of the screen (above the tab bar). Text: "[Object title] deleted." or "[Object title] archived." On the right: an "Undo" button in the app's accent color (purple).
- Duration: the toast is visible for 5 seconds, then automatically disappears.
- If "Undo" is tapped: the action is reversed. The object is immediately restored to its previous state and location. No confirmation required.
- If the toast disappears without Undo being tapped: the action is committed. For deletion, the file is moved to a `_deleted/` folder in the vault (not permanently erased immediately). Files in `_deleted/` are permanently erased after 30 days (configurable).
- Only one undo toast is shown at a time. If the user deletes another item before the first toast disappears, the first action is committed and the new toast appears.

---

## SECTION B: NAVIGATION AND STRUCTURE

---

### B1. BOTTOM NAVIGATION BAR (CUSTOMIZABLE)

The bottom navigation bar is a persistent element shown on all root-level screens. It is fully customizable by the user.

**Default configuration (5 slots):**
Slot 1: Home (Início) — always present, cannot be removed.
Slot 2: Journal — shows the Journal/Timeline view.
Slot 3: Planner — shows the Planner view.
Slot 4: Trackers — shows the Trackers list.
Slot 5: Mais (More) — always present, cannot be removed. Opens the More/Settings page.

**Customization:** The user can add, remove, and reorder the middle slots (slots 2–4 and any additional slots, up to a maximum of 7 total including Home and More). Items not in the bottom bar appear in the "Content" section of the More page.

**Available pages that can be placed in the bottom bar:**
Journal, Planner, Trackers, Archive, Tasks, Projects, People, Goals, Resources, Rotinas (Routines), Habits, and any future custom page.

**How to customize:**
1. User taps "Mais" → opens the More page.
2. In the More page, there is a "Content" section showing all available pages as draggable rows.
3. Each row has a toggle on the right: toggled on = page is in the bottom bar. Toggled off = page is only accessible from the More page.
4. User drags rows to reorder. The order in the Content section determines the order in the bottom bar (after Home and before More).
5. Changes are applied immediately and persist across app restarts.

**Bottom bar visual design:**
- Fixed at the bottom of the screen. Height: 49pt (iOS) / 56dp (Android) + bottom safe area inset.
- Each slot: icon (24pt) centered above label text (10pt, medium weight).
- Active tab: icon and label in accent color (dark purple). Inactive: gray/muted.
- Tab bar background: matches the app's surface color (white in light mode, dark gray in dark mode). A hairline separator above it.

---

### B2. MORE PAGE (SETTINGS AND CONTENT HUB)

The More page is a scrollable screen. It has a persistent "Mais" title with a settings gear icon in the top right.

**Content section:** A list of all available pages with toggle + drag handle. Pages currently in the bottom bar show a filled/active toggle. Pages not in the bottom bar show an inactive toggle. Dragging reorders.


---

### B3. CATEGORIES MANAGEMENT PAGE (Settings → Categories)

This page defines the system of automatic categorization for all object types.

**Layout:** A list of category definitions. Each definition is a row showing: category name + the condition that defines it (e.g., "Has `[[tasks]]` in `categories` property").

**Editing a category definition:**
- Tapping a row opens the Category Definition editor.
- Changes apply to newly created objects. Existing objects are NOT retroactively modified (the user must bulk-edit if needed).

**How it works in practice:**
- User defines: "Tasks = objects where `categories` contains `[[tasks]]`".
- The app queries Dataview for all notes where `categories` contains `[[tasks]]` to populate the Tasks view.
- When creating a new task, the app automatically sets `categories: ["[[tasks]]"]` in the frontmatter.
- User can add `[[trabalho]]` to the categories of a specific task without affecting the category definition.

---

## SECTION C: HOME PAGE (INÍCIO)

The Home page is the first tab in the bottom bar. It is fully editable — the user controls exactly which blocks appear and in what order.

**Header:**
- Purple left-border accent bar + "Início" large bold title.
- Top-right: edit icon (pencil or grid icon). Tapping enters "Edit Mode" where blocks can be added, removed, and reordered.

**Block system:** The Home page is a vertical list of blocks. Each block is a rounded-rect card with configurable content. Blocks are reorderable via drag-and-drop in Edit Mode. All blocks have a "⋯" menu in their top-right corner (even outside Edit Mode) for: Edit Block, Remove Block.

**Adding a block:**
In Edit Mode, a "+" button appears at the bottom of the block list and between existing blocks. Tapping opens a Block Type picker (bottom sheet) with all available block types. After selecting a type, a configuration sheet opens for that block.

**Available block types:**

1. **"Como você está?" (How are you?) block** — A mood-capture quick block. Shows the mood picker inline (row of emoji buttons) with optional feelings chips below. Tapping a mood records it for the current journal entry (creates one if none exists today) or as a standalone mood data point.

2. **Task block** — Shows a configurable list of tasks. Configuration: which tasks to show (all, by category, by project, by priority, due today, overdue, backlog). Displays each task as a row with checkbox + title + priority flag + due date. Tapping the checkbox completes it inline. Tapping the title opens the task detail.

3. **Project block** — Shows one or more projects with progress bars. Configuration: which projects to show (specific project, all active projects, all projects in a category). Each project shows: title + progress percentage + KPI mini-bars.

4. **Tracker block** — Shows data from one specific tracker or a summary. Configuration: which tracker, which fields, date range, display type (mini chart, latest value, streak count). The "Menstruação" tracker or a sleep tracker summary can be pinned here.

5. **Combined Analysis block** — Renders a combined analysis inline on the Home page. Configuration: which Analysis object to show.

6. **Habit list block** — Shows today's habits with completion status. Configuration: which habits to show (all, by category). Each habit row: habit name + completion indicator + "days since" badge + slots (if multi-slot, shows each slot as a small checkbox). Habits not yet completed for today are more prominent.

7. **Journal quick-add block** — A large tappable area with a "Write in your journal" placeholder or a pre-set prompt. Tapping opens the journal entry creation form.

8. **Planner/Calendar block** — An embedded mini-calendar showing the current month. Each day shows colored dots for events/tasks/habits. Tapping a day navigates to the Planner's day view for that date.

9. **Google Calendar block** — An embedded view of the user's Google Calendar events for today or the week. Shows events as colored chips with time. Read-only from the Home page; tapping an event opens it in Google Calendar.

10. **Time blocking block** — Shows today's time blocks with tasks/pomodoros scheduled in them. Compact version of the Planner's day view.


12. **People block** — Shows people who are due for contact (based on their scheduler). Displays as a list of names + "last contact N days ago" + "contact" button.

13. **Stats/KPI block** — Shows one or more KPI values with progress bars. Configuration: which KPIs or goals to display.

14. **Custom HTML/Markdown block** — Free text content with full markdown formatting. Static content the user writes directly (useful for personal mantras, quick-reference lists, etc.).

**Edit Mode behavior:**
- All blocks get a drag handle on their left edge and a "–" remove button on their right.
- A reorder animation plays as blocks are dragged.
- Tapping "Done" exits Edit Mode and saves the configuration. Configuration is stored in the app's settings file (not in a daily note — it's a persistent preference).

---

## SECTION D: JOURNALING

---

### D1. JOURNAL ENTRY — FULL SPECIFICATION

**Where journal entries live:** In Obsidian, all journal entries for a given day are stored in `daily/YYYY-MM-DD.md` under the `## Journal Entries` section, each as a `### HH:MM` subsection. In the app, they appear as individual cards in the Journal tab's timeline, sorted by time.

**Creation flow:**
1. User taps the Journal tab (bottom bar) OR taps the journal quick-add block on the Home page OR taps the global "+" button.
2. If from the Journal tab or "+": creation form opens as a full-screen modal.
3. Title: "Nova entrada" or the section in the nav bar. X close button top-right. "Salvar" or "Done" button top-right or full-width at bottom.
4. Date/time field at the top of the form: pre-filled with the current date and time. Displayed as a tappable row: "[date] | [time]". Tapping the date opens a calendar picker (month grid, current date highlighted, selectable). Tapping the time opens a time wheel picker. The user CAN set a past or future date/time. This allows retroactive entry.
5. Body: full-screen rich text editor below the date. Placeholder: "O que está em sua mente?". Supports: bold (Ctrl+B / toolbar button), italic, underline, headings (H1/H2/H3 via toolbar), checklist (toggle list via toolbar), bullet list, numbered list, inline `[[WikiLink]]` mention via typing `[[` (see Universal Linking), inline image insertion (via photo attach button in toolbar).
6. Toolbar row (above keyboard, below body): left-to-right icons: Bold, Italic, Underline, Heading, Bullet list, Checklist, Attach photo/file, Insert link (`[[`), More formatting options ("...").
7. Metadata bar (below title, above body OR as a collapsible drawer): chips for Mood, Organizers, Location. Each chip is tappable.
8. Mood chip: shows current mood emoji or "Add mood" if none. Tapping opens the Mood picker.
9. Organizers chip: shows count of selected organizers or "Add organizers". Tapping opens the Organizer picker.
10. Location chip: shows detected or typed location or "Add location". Tapping auto-detects GPS or allows typing.
11. Photo/file attachment: photos can be attached inline (at cursor position) or as a bottom attachment strip. Supported: photos from gallery, camera, and file picker. Photos are stored in the vault's `_attachments/` folder and referenced as `![[filename.jpg]]` in the markdown.
12. Saving: "Done" / "Salvar" button. If the user closes without saving, a "Discard changes?" alert appears.

**Mood picker (full screen or bottom sheet):**
- Displays all MoodDefinition objects as a horizontal row of large emoji buttons (each ~56pt square).
- Below each emoji: the mood label (e.g., "Ótimo").
- Tapping a mood selects it (shows filled/highlighted background on that emoji).
- Below the emoji row: a wrap of "feelings" chips (secondary tags like "ansioso", "grato", "cansada"). Pre-defined list + custom input (tapping "+" opens a text field to add a custom feeling). These are stored as the `feelings` property in the entry's frontmatter.
- Selected mood is stored as `mood:: [[mood-slug]]` inline in the entry body OR in the entry's frontmatter sub-block.

**Journal tab timeline view:**
- The Journal tab shows a vertical timeline of all journal entries across all days.
- At the top: a date navigation strip (horizontal scrollable row of week days, or a month calendar that collapses/expands). The currently selected day is highlighted.
- Below: a scrollable list of entry cards for the selected day, sorted by time (earliest first or latest first, user configurable).
- Each entry card: time label (small, muted, e.g., "09:15") + mood emoji + title (if present, bold) + body preview (2–3 lines truncated) + organizer chips + attachment thumbnails strip (if photos present) + "⋯" overflow menu.
- Tapping a card opens the entry's detail view (full body, all properties, Mentions section, ⋯ menu with Edit/Delete/Archive/Open in Obsidian).
- Between days: a date header pill ("Qui, 12 de Dez") acts as a visual separator.
- "Today" date header: always shows at the top of the list if there are entries today. If no entries today: a "No entries today" empty state with a large "+" button to add the first one.

**Archiving a journal entry:**
- Available from the "⋯" menu on any entry card or in the detail view.
- Archived entries disappear from the Journal timeline and all timeline views.
- They remain in the Obsidian daily note file (the `### HH:MM` section stays intact) but gain a property `archived: true` in an inline Dataview field.
- Archived entries are listed in Settings → Archive → Journal Entries.
- Undo snackbar appears for 5 seconds after archiving.

---

## SECTION E: PLANNER

The Planner is a dedicated tab (or section accessible from the bottom bar). It shows all time-sensitive content: tasks with due dates, habits scheduled for the day, calendar sessions (pomodoros), and imported Google Calendar events.

**View modes:**
A segmented control at the top of the Planner switches between: Day | Week | Month. Default: Day.

**Day view:**
- Shows a vertical timeline of the selected day from midnight to midnight (or from first item to last item).
- Time is shown on the left axis (every hour or half-hour, depending on content density).
- Content items appear as horizontal colored bars at their scheduled time.
- Items without an exact time appear in an "All day" strip at the top of the timeline.
- Items are color-coded: the color is determined by the item's category/priority color scheme (configurable in Planner Settings — the user chooses whether color = category or color = priority).
- Each item shows: colored left border + priority flag icon (if priority is set; flag color = priority color) + title + a quick-complete checkbox on the right + a play (▶) icon for starting a Pomodoro session + "⋯" three-dots icon.

**Item types in the planner:**
- Tasks: show checkbox + title + priority flag + due date.
- Habits: show checkbox(es) per slot + habit name + "days since" badge + streak count.
- Calendar Sessions / Pomodoros: show a filled colored block with title + duration + play button.
- Google Calendar events: show a block with a Google Calendar icon + title + time. Tapping shows event details and a "Edit in Google Calendar" link.
- Reminders: show a bell icon + title + checkbox if completable.

**Quick-complete checkbox:** Tapping the checkbox on any task/habit in the planner marks it complete instantly. No confirmation. Undo snackbar appears.

**Play (▶) button:** Tapping starts a Pomodoro session for that item. The Pomodoro timer opens as an overlay or full-screen (see Pomodoro section).

**Three-dots "⋯" on planner item:**
For tasks/habits: Edit, Delete, Archive, Open detail, Open in Obsidian.
For Google Calendar events: Opens in Google Calendar.
For Pomodoros: Edit session, Delete, Archive.

**Week view:**
- 7-column grid (Mon–Sun). Each column = one day.
- Items shown as compact chips in their day column.
- Tapping a day column navigates to that day's Day view.
- Tapping an item opens its detail view.

**Month view:**
- Full calendar grid (Mon–Sun columns, all weeks of the month).
- Each day cell shows: a colored dot per item type present that day. If more than 4–5 items: shows first 3 + "+N more" label.
- Today: highlighted with a border or background color.
- Tapping a day opens the Day view for that day.

**Planner Settings (accessible via the options icon or ⋯ in the Planner header):**
- Color scheme: "By category" (each category has a color) vs "By priority" (each priority level has a color).
- Category colors: edit the color for each category (Tasks = blue, Habits = green, Pomodoro = orange, Events = purple, etc.).
- Priority colors: edit the color for each priority level (High = red, Medium = orange, Low = blue, None = gray).
- Start of week: Sunday or Monday.
- Default view: Day / Week / Month.
- Time range: first and last hour shown in Day view (e.g., 6 AM to 11 PM).

**Backlog section:**
At the bottom of the Planner (or accessible via a "Backlog" tab/button within the Planner), a separate list of items with no scheduled date. Shows all tasks, habits, and sessions currently in backlog state. User can drag items from the Backlog into the Day view timeline to schedule them.

**Drag and drop in Planner:**
- Items in the Day view can be dragged vertically to change their time.
- Items can be dragged horizontally in Week view to move to a different day.
- Items can be dragged from the Backlog section into the Day view.
- Dragging an item onto a Time Block chip assigns it to that block.
- While dragging: the item's original position shows a placeholder outline. The drop target highlights.

**Pinning items to the Planner:**
Any item (task, Obsidian note, project, etc.) can be "pinned" to the Planner's day view. Pinned items appear in the "All day" strip with a pin icon. Pinning does not schedule the item at a specific time — it just keeps it visible on that day. Pin is toggled via the item's ⋯ menu: "Pin to Planner".

**Google Calendar integration:**
- Configured in Settings → Google Calendar.
- Once connected (OAuth), the Planner reads events from the user's Google Calendar and displays them.
- Google Calendar events are read-only in the app. They show with a Google Calendar icon.
- Tapping a Google Calendar event shows its details (title, time, description, attendees) and a "Open in Google Calendar" button.
- The user can associate a Google Calendar event with an app object (e.g., link it to a Project) via the event's detail view. This adds the event as a mention in the project's Mentions section.

---

## SECTION F: POMODORO TIMER

---

### F1. POMODORO SESSION OBJECT

**Properties:**
- `title` — string, the name of what is being worked on.
- `linked_item` — optional WikiLink to any app object or Obsidian page (the task, project, note, etc. being worked on during this session).
- `date` — date.
- `work_duration` — integer, minutes per work block (default: 25).
- `short_break_duration` — integer, minutes per short break (default: 5).
- `long_break_duration` — integer, minutes per long break (default: 20).
- `long_break_after_blocks` — integer, number of work blocks before a long break (default: 4).
- `blocks_completed` — derived integer, number of 25-min blocks completed in this session.
- `minutes_worked` — derived integer, total minutes of actual work time.
- `minutes_break` — derived integer, total minutes of break time.
- `state` — enum: `scheduled`, `active`, `paused`, `completed`, `cancelled`.
- `organizers` — array of Organizer references.
- `linked_item` — WikiLink to any page.

**Obsidian storage:** Pomodoro sessions are stored in the daily note under a `## Pomodoros` section:
```
## Pomodoros

### 09:00 — Trabalho no Projeto Alpha
- Linked: [[projeto-alpha]]
- Blocos: 3
- Tempo trabalhado: 75 min
- Tempo de pausa: 15 min
```
The session also appears as a mention in the linked item's Mentions section.

---

### F2. POMODORO TIMER — ACTIVE UI

When the user starts a Pomodoro (from the play button in the Planner or from a task's ⋯ menu):

1. The timer opens as a full-screen overlay (or full-screen activity on Android). The rest of the app is still accessible by dismissing the overlay.
2. **Timer screen layout:**
   - Item being worked on: title at top (tappable to change the linked item).
   - Large circular countdown timer in the center (shows MM:SS remaining).
   - Below timer: current phase label ("Trabalhando" / "Pausa curta" / "Pausa longa").
   - Block progress indicator: a row of N circles (N = blocks configured). Completed blocks: filled circle. Current block: animated/pulsing. Upcoming: empty circle.
   - Controls (below progress): Pause button (if running) / Resume button (if paused), Stop/Cancel button, Skip phase button (advance to next break or next work block early).
3. **Timer notifications:** Even if the app goes to background, the timer continues. A persistent notification shows the remaining time and phase. The notification has action buttons: Pause/Resume, Stop.
4. **On phase completion:** A notification sound and/or vibration plays. If the phone is on silent: behavior is configurable (see Notifications). The app shows a brief full-screen flash or sound indicating phase change.
5. **On session completion:** A completion sheet appears showing: total blocks completed, total minutes worked, total break time. Options: "Done" (saves the session), "Do another round" (starts a new session immediately).
6. **Cancelling:** Tapping "Stop" at any time shows a confirmation: "Stop session? Your progress so far (X blocks, Y min) will be saved." Confirming saves a partial session.

---

### F3. SCHEDULED POMODORO

The user can pre-schedule a Pomodoro block in the Planner:

1. In the Planner's Day view, tap the "+" in a time slot.
2. In the creation form, select "Pomodoro session".
3. Fields: title, linked item (WikiLink picker), start time, number of work blocks desired, work/break durations (pre-filled with defaults). A calculated display shows: "X h Y min total = N work blocks + N short breaks + M long breaks".
4. Reminder: the Pomodoro session can have reminders (same as any other item — push, popup, alarm with configurable timing and number of reminders).
5. When the scheduled time arrives, a reminder notification fires. The notification has a "Start Pomodoro" action button that opens the timer directly.

---

## SECTION G: TASKS

---

### G1. TASK OBJECT — COMPLETE SPECIFICATION

**Properties (full list, extending the base specification):**
- `title` — string, required.
- `stage` — enum: `idea`, `backlog`, `todo`, `in_progress`, `pending`, `finalized`.
- `priority` — enum: `none`, `low`, `medium`, `high`.
- `start_date` — date, optional. When the task becomes relevant.
- `end_date` — date, optional. Deadline.
- `date_range` — boolean flag. If true, the task spans the full range between start_date and end_date and appears on EVERY day in the Planner between those dates.
- `until_done` — boolean. If true, the task appears in the Planner every day until it is marked complete, regardless of due date. Shown with a special "∞ until done" indicator icon.
- `duration` — integer, minutes. Default: 15 minutes. Shown as a time block in the Planner's Day view.
- `all_day` — boolean. If true, appears in the "All day" strip rather than at a specific time.
- `scheduled_time` — optional time (HH:MM).
- `notes` — rich text body.
- `subtasks` — array of Subtask objects. Each subtask is a full Task object (same properties as the parent) linked to the parent via the `parent_task` property. Subtasks appear as collapsible nested rows under the parent in list views.
- `categories` — array of WikiLinks (automatically includes `[[tasks]]`).
- `links` — array of WikiLinks (any linked objects).
- `organizers` — array of Organizer references.
- `scheduler` — optional Scheduler configuration.
- `reminders` — array of Reminder configurations (see Notifications section).
- `color` — optional.
- `participants` — array of People references.
- `places` — array of Places references.
- `timer_sessions` — derived. Total pomodoro time.
- `comments` — array of Comment objects.
- `reflection` — optional rich text, prompted when stage moves to `finalized`.
- `archived` — boolean, default false.
- `parent_task` — optional WikiLink, if this task is a subtask of another.

**Subtask specification:**
- Every task has a subtasks section in its detail view.
- Each subtask is created as a SEPARATE full task object (its own Obsidian file with `type: task` and `parent_task: [[parent-task-slug]]` in its frontmatter).
- In the parent task's detail view: subtasks appear as a collapsible list. Tapping a subtask opens it as its own full task detail view.
- In the parent task's Obsidian file: subtasks are referenced as WikiLinks in a `## Subtasks` section.
- If a subtask has a date outside the parent task's date range: it appears in the Planner as an independent task item with a small "↑ Subtarefa de [[parent-task-slug]]" label and a link icon. Tapping the label navigates to the parent task.
- Subtasks can be organized into "sessions" (thematic groups within the subtask list). Sessions are collapsible groups with a name. Implementation: a `session` property on each subtask indicating which session it belongs to.

**Task creation UI:**
1. User taps "+" → Plan tab → Task. OR taps "+" in the Tasks view. OR taps "Add task" in any task block on the Home page.
2. Full-screen modal: "Nova tarefa" title + X close + disabled "Salvar" button (becomes active when title is filled).
3. Title field: large (28pt), top, placeholder "Título da tarefa".
4. Below title: a scrollable form in grouped cards.
5. **Stage card:** Single-select row of 6 labeled buttons: Ideia | Backlog | A fazer | Em progresso | Pendente | Finalizada. Default: "A fazer".
6. **Date card:**
   - `Date` row: tappable, opens the Move/date picker. Default: no date (if no date is selected, a dialog on save asks "Sem data — ir pro backlog?" with options "Ir pro backlog" / "Usar data de hoje" / "Cancelar"). If the user exits without choosing: defaults to today.
   - `Start date` toggle + field: if toggled on, shows a start date picker.
   - `Date range` toggle: if toggled on and both start and end dates are set, the task spans the full range.
   - `Until done` toggle: if toggled on, task appears every day in planner until finalized.
   - `Duration` field: numeric input (minutes). Default: 15.
   - `All day` toggle.
7. **Scheduling card:** `Repeat` row: shows current repeat rule or "None". Tapping opens the Scheduler editor.
8. **Priority card:** Three flag icons: blue (low), orange (medium), red (high). Tap to select. Tap again to deselect.
9. **Subtasks card:** Header "Subtarefas" + "⋯" menu + "0/0" counter. "Add subtask" tappable text creates a subtask inline. Long-press a subtask row → "Open as full task" (converts the subtask to a full task object with its own file).
10. **Links card:** Shows linked items as WikiLink chips. "+" opens the link picker.
11. **Reminders card:** Shows configured reminders. "+" opens the Reminder editor (see Notifications section).
12. **Notes card:** Rich text area. "Enter text..." placeholder.
14. **Color chip:** Optional color selector for visual distinction.
15. **Salvar button:** Full-width, bottom, dark purple, rounded pill. Disabled (gray) until title is entered.

**Backlog behavior:**
When saving a task with no date: a modal alert appears: "Esta tarefa não tem data. Onde devo colocá-la?" with options: "Backlog" (task goes to the Backlog section of the Planner, no date assigned) and "Adicionar para hoje" (task gets today's date). If the user closes the modal without choosing: task defaults to today. This alert does NOT appear if the user explicitly set `stage: backlog`.

---

## SECTION H: PROJECTS

---

### H1. PROJECT OBJECT — COMPLETE SPECIFICATION

**Concept:** Projects are long-running goals with metrics (KPIs), a collection of related tasks, and optional recurrence (a project that restarts every month, year, etc.). Projects operate "in the background" — they group and contextualize tasks rather than appearing directly in the Planner like tasks do.

**Properties:**
- `title` — string, required.
- `description` — rich text, optional.
- `state` — enum: `active`, `paused`, `completed`, `archived`.
- `priority` — enum: `none`, `low`, `medium`, `high`.
- `start_date` — date.
- `due_date` — date. Displayed in the UI as: "em X dias (12 abr)" — both a relative label AND the absolute date.
- `progress` — derived float (0.0–1.0). Computed from primary KPI. Shown as a percentage and a progress bar.
- `primary_kpi` — reference to exactly one KPI object. This KPI drives the progress percentage.
- `secondary_kpis` — array of KPI references (unlimited). Shown below the primary KPI.
- `tasks` — array of WikiLinks to Task objects that are "children" of this project.
- `scheduler` — optional Scheduler configuration. When set: the project recurs (restarts) on the schedule. On recurrence, the project's progress resets and a new instance is created.
- `total_pomodoro_time` — derived integer (minutes). Sum of all Pomodoro sessions linked to this project.
- `quick_access` — array of WikiLinks to any Obsidian page or app object. Pinned references shown in the project's Quick Access section.
- `categories` — array of WikiLinks (auto-includes `[[projects]]`).
- `links` — array of WikiLinks.
- `tags` — array of tag strings (auto-includes `#projeto`).
- `organizers` — array of Organizer references.
- `archived` — boolean.

**Project detail view:**
- Header: large bold title + "Projeto" type label below.
- Properties card: State (dropdown), Priority (flag icons), Start date, Due date (with relative label), Progress (percentage + bar).
- Primary KPI section: large progress bar + current value / target value label.
- Secondary KPIs section: smaller bars, one per secondary KPI.
- Tasks section: list of linked tasks with their stages. "Add task" button creates a new task and automatically links it to this project.
- Quick Access section: pinned items as chips. "+" adds a link to any Obsidian page.
- Total Pomodoro Time: shows formatted time (e.g., "3h 45min").
- Calendar section: embedded month calendar showing days with activity (tasks completed, pomodoros logged, entries written) related to this project.
- Mentions section: backlinks.
- ⋯ menu: Edit, Archive, Delete, Open in Obsidian, Take Snapshot.

---

## SECTION I: SCHEDULER (COMPLETE SPECIFICATION)

This section extends the Scheduler object described earlier with the full set of rules specified in the braindump.

---

### I1. SCHEDULER PAGE (GLOBAL VIEW)

Accessible from Settings → Scheduler OR from the More page.
Shows a list of ALL objects in the vault that have an active scheduler. Each row: object icon + object title + next occurrence date + active/inactive toggle. Tapping a row opens the object's scheduler configuration. The inactive toggle pauses the scheduler without deleting it.

---

### I2. SCHEDULER OBJECT — EXTENDED RULE SET

Every object that can have a scheduler shows a "Repetição" (Repeat) section in its editor. Within that section: a list of currently configured rules (initially empty). "Add rule" button opens the Rule picker.

**Rule types (complete list, extending the screenshot-confirmed types):**

1. `number_of_days` — Every N days. Sub-field: `interval` (integer).
2. `days_of_week` — On specific days of the week. Sub-field: `days` (multi-select checkboxes: Mon/Tue/Wed/Thu/Fri/Sat/Sun).
3. `number_of_weeks` — Every N weeks. Sub-field: `interval` (integer).
4. `number_of_months` — Every N months on specific day(s) of the month. Sub-fields: `interval` (integer), `days_of_month` (list of integers, each with "+" add and "×" remove buttons).
5. `number_of_hours` — Every N hours. Sub-field: `interval` (integer). For intraday items.
6. `days_after_last_start` — N days after the last instance's start date. Sub-field: `interval` (integer).
7. `days_after_last_end` — N days after the last instance's completion/end date. Sub-field: `interval` (integer).
8. `days_per_period` — N days per period (week/month/year). Sub-fields: `count` (integer), `period` (enum: week/month/year, shown as tappable purple accent text), `starting_day_offset` (integer, default 0), `interval_between_days` (integer, default 1). Example text below: "Ex: Jogar futebol 2x por mês, começando no dia 10, com pelo menos 5 dias de intervalo."
9. `linked_item_appears` — "Toda vez que [X coisa] aparecer no calendário". Sub-field: `linked_item` (WikiLink picker — any Obsidian page or app object). When the linked item is scheduled on a day, this item is also scheduled on that day.
10. `n_days_after_linked_item` — "N dias/horas depois que [X coisa] aparecer". Sub-fields: `interval` (integer), `unit` (enum: days/hours), `linked_item` (WikiLink picker).
11. `first_business_day_of_month` — "Primeiro dia útil do mês". No sub-fields. The app calculates the first weekday (Mon–Fri) of each month. If a holiday calendar is connected: optionally skips public holidays.

**Multiple rules:** A single scheduler can have multiple rules simultaneously. Each rule is added as a separate entry in the rules list. The scheduler fires the item on any day that satisfies ANY of the rules (logical OR between rules).

**Exclusion rules:** A separate "Exclusões" section in the Scheduler editor. "Add exclusion" button opens an exclusion picker with types:
- `day_of_week` — never on [Mon/Tue/.../Sun]. Multi-select checkboxes.
- `day_of_month` — never on day N of the month. Numeric input.
- `linked_item_present` — "Quando [X coisa] estiver no meu calendário". WikiLink picker. If the linked item is scheduled on a day, this item is SKIPPED on that day.

**Overdue policy:** A "Política de atraso" section. Options: Skip (discard missed instances silently), Keep (show overdue item until acted upon), Prompt (ask the user what to do when an overdue item is detected).

**Scope:** A "Escopo" section. Optional fields: `active_from` date, `active_until` date or `max_occurrences` integer. If both are null: the scheduler is infinite.

**Next instance field:** Displayed prominently at the top of the Scheduler editor: "Próxima ocorrência: [date]". This is editable — the user can manually override the next instance date without changing the rules.

**Notifications per scheduler rule:** Each rule can have its own notification configuration. A "Set reminder" link appears within each rule's expanded view.

---

## SECTION J: NOTIFICATIONS

Every object that can be scheduled can have notifications. Notifications are configured per-object, per-occurrence.

---

### J1. REMINDER CONFIGURATION OBJECT

Each notification attached to an object has:
- `trigger_time` — when the notification fires. Options: "At time of event", "X minutes/hours/days before". `offset_value` (integer) + `offset_unit` (enum: minutes/hours/days). Multiple reminders can be added to one object (tap "+" to add another reminder — unlimited count).
- `type` — enum: `push` (standard push notification, appears in notification shade), `popup` (full-screen popup that appears over the lock screen or current app), `alarm` (sounds like an alarm, ignores silent mode by default).
- `notification_body` — string. What appears in the notification. Default: object title.

**Per-type customization (all configurable per reminder):**
- Push notification: sound (list of system sounds + custom), vibration pattern (yes/no, configurable pattern), LED color (on Android).
- Popup: background color (color picker), text color (light/dark auto-calculated), which buttons appear (see below).
- Alarm: ring tone (list of sounds), vibration (yes/no), "ring even on silent" (boolean, default YES for alarms), snooze duration (default 10 min, editable).

**Action buttons on ALL notification types (push, popup, alarm):**
- "Mark as done" — marks the associated object as complete without opening the app.
- "Snooze" — delays the notification by the configured snooze duration (default 10 min; editable in the notification's configuration and ALSO editable in the moment when the notification fires by tapping "Snooze" and then adjusting the time).
- "Dismiss/Cancel" — closes the notification without marking as done.

**System-level reliability:** Notifications are stored in the system's alarm manager (Android: `AlarmManager.setExactAndAllowWhileIdle()` for exact notifications, `setAlarmClock()` for alarm-type; iOS: `UNUserNotificationCenter` with precise timing). This ensures notifications fire even when the app has not been opened or updated since the reminder was set. The system-level alarm is registered at the time the reminder is created, not at the time the app is opened.

---

## SECTION K: HABITS (EXTENDED SPECIFICATION)

Extending the base Habit specification with the braindump additions.

**Extended properties:**
- `status` — enum: `active`, `paused`, `completed`. Shown as a badge on the habit card.
- `start_date` — date, when the habit began. Used for "X days since start" calculation.
- `priority` — enum: `none`, `low`, `medium`, `high`. Shown as a flag icon.
- `archived` — boolean.

**Planner appearance (confirmed and extended):**
In the Planner's Day view, each habit appears as a row with:
- Checkbox(es): one per slot. If the habit has 2 slots (e.g., "2 comprimidos"), two checkboxes are shown side by side. Each checkbox is independently tappable.
- Habit name.
- Streak count: small badge (e.g., "🔥 12").
- "Days since start" indicator: small text showing days elapsed since `start_date` (e.g., "Day 42"). This is different from the "days since last completion" badge — this counts from the habit's creation date.
- "Days since" completion badge: small colored pill (see FEATURE: Days Since Tag).
- If the habit has a Goal: a mini progress bar or percentage (e.g., "47/100 dias").
- Play (▶) button: starts a Pomodoro linked to this habit.
- "⋯" three-dots: Edit, Archive, Delete, Open in Obsidian.

**Habit month widget (in habit detail view):**
- A mini calendar grid for the current month.
- Each day is colored based on completion status: accent color (full goal met), lighter tint (partial), empty/gray (not scheduled or not completed), and a small bell/notification icon overlaid on days where a scheduler notification is configured.

**Slot-level reminders and actions:**
Each slot can have its own reminder time AND its own action. In the Habit editor's Slots section, each slot row has: a circle icon + slot number + "Set reminder" link (opens Reminder editor for this slot) + "Set action" link (opens Action picker for this slot — same 7 action types as the global Actions).

---

## SECTION L: KPI OBJECT

**Concept:** A measurable metric attached to a Project or Goal. One primary KPI drives the parent's progress percentage. Unlimited secondary KPIs provide additional context.

**Source types (all supported):**
- `subtasks` — percentage of linked subtasks marked complete.
- `tracker_field` — sum/average/count/max/min of a specific field in a specific Tracker.
- `habit` — completion count, successful days, or streak of a specific Habit.
- `collection` — count of items in a Collection Note that match a filter.
- `entry` — count of journal entries that mention this object (linked via organizers or inline mention).
- `time_spent` — total Pomodoro minutes logged and linked to this object.
- `manual_quantity` — user manually inputs a number (e.g., "Economizados: R$ 350"). Target: a user-defined value (e.g., "R$ 500").
- `others` — a catch-all for any Dataview-query-driven computation.

**KPI tracking behavior:**
- KPIs are recalculated dynamically every time the app loads or a relevant data change is detected.
- A KPI can be marked as "auto-complete": when `current_value >= target_value`, the KPI is marked completed and optionally triggers an action (notification, entry creation, etc.).

**Manual quantity KPI entry UI:**
- In the Project/Goal detail view, the primary KPI card shows: title + current value / target value + a progress bar.
- For manual quantity KPIs: an inline editable field shows the current value. The user taps it to update the number. A "+N" quick-add button (e.g., "+ 50") increments by a preset amount.

---

## SECTION M: PEOPLE

**Concept:** Each person the user wants to stay in contact with has a dedicated Obsidian page (`people/person-name.md`). The app surfaces these as a "People" view where the user can see who they should reach out to.

**Properties:**
- `name` — string.
- `photo` — optional image (Obsidian `![[photo.jpg]]`).
- `last_contact_date` — derived. The date of the most recent journal entry or calendar event where this person is mentioned (via `[[person-name]]` WikiLink).
- `contact_frequency` — duration (e.g., "every 2 weeks", "monthly", "every 3 days"). Editable.
- `priority` — enum: none/low/medium/high. Determines the urgency styling of the "contact" task when it appears in the Planner.
- `notes` — rich text body.
- `links` — array of WikiLinks.
- `categories` — array (auto-includes `[[people]]`).

**Scheduler behavior for People:**
The app automatically creates a Planner task "Contatar [Person name]" when `last_contact_date + contact_frequency <= today`. This task:
- Appears in the Planner with the person's assigned priority.
- Has a checkbox. When checked: `last_contact_date` is updated to today, the scheduler resets, and the task disappears from the Planner.
- If not checked: the task persists every day (effectively "until done") until the user marks it or changes the scheduler.
- The user does NOT need to manually configure a Scheduler for People — the app creates and manages it automatically based on `contact_frequency`.

**People view:**
- List of all people, sorted by urgency (those overdue for contact at top, then by next contact date).
- Each row: photo thumbnail (or initials avatar) + name + "Last contact: N days ago" + "Every X" (contact frequency) + urgency badge (green = on track, yellow = due soon, red = overdue).
- Tapping opens the person's detail view.
- Detail view: all properties + full linked mentions from the vault (every journal entry, task, or note that mentions this person).

---

## SECTION N: RESOURCES

**Concept:** A curated library of media the user wants to consume (books, movies, series, podcasts, etc.), populated primarily via Obsidian Web Clipper. Each resource is an Obsidian page with structured metadata. The app presents these beautifully in card-based views with filtering.

**How resources enter the vault:**
- Obsidian Web Clipper (browser extension) clips pages from Amazon, IMDb, Goodreads, etc. and creates a note with structured frontmatter (title, cover image, type, synopsis, links, status, etc.).
- The user does NOT need to manually enter data — the clipper populates it.

**Resource filtering configuration (Settings → Resources):**
The user defines what makes a note a "resource" in the app. The definition is property-based and fully editable:
- Books: notes where `status` is one of `to-read`, `reading`, `read`.
- Movies: notes where `tags` contains `#movie`.
- Series: notes where `tags` contains `#series`.
- Podcasts: notes where `tags` contains `#podcast`.
The user can change these conditions at any time from within the app. Changing a condition immediately refilters the Resources view.

**Resource object key properties:**
- `title` — string.
- `cover_image` — optional image (WikiLink embed).
- `type` — string (Book, Movie, Series, Podcast, etc.) derived from the filter conditions.
- `status` — string (to-read, reading, read, watching, watched, etc.).
- `categories` — array of WikiLinks shown as chips.
- `rating` — integer (stored as a number in Obsidian; displayed as stars in the app: 1 = ☆☆☆☆☆ filled stars = rating/5 rendering).
- `synopsis` — text.
- `links` — array (other Obsidian pages this resource links to).

**Resources view layout:**
- At top: filter bar with multi-select chips for type (All / Books / Movies / Series / etc.) and status (All / To consume / In progress / Completed).
- Sort button: sort by priority, rating, title, date added, date modified.
- Content displayed as cards in a grid (2 columns) or list (1 column, toggleable).
- Each card shows: cover image (top, fills card width) + title + status badge + category chips + star rating.
- Tapping a card opens the resource detail view.
- Detail view: cover image (full-width banner) + all properties + synopsis + links + Mentions section (backlinks from vault) + ⋯ menu (Edit, Archive, Open in Obsidian).

**Rating display:**
- In Obsidian: stored as `rating: 4` (integer 1–5 or 1–10, configurable).
- In the app: rendered as filled/empty stars (★★★★☆ for rating 4/5). Tapping the stars in the detail view opens an inline star-selector to update the rating.

---

## SECTION O: TRACKERS (EXTENDED SPECIFICATION)

Extending the base Tracker specification with braindump additions.

**Unlimited sections:** No limit on the number of sections within a tracker.

**Statistics view (confirmed and extended):**
In the Tracker detail view, after the calendar and timeline sections:
- **Mini month widget:** Same calendar-grid design as the Habit month widget. Days with at least one tracking record show a colored fill. Days with no records are empty/gray.
- **Summaries section:** User-configurable data summaries. Each summary is a row: label + value. Types: Sum (total of a numeric field over a date range), Average, Max, Min, Last (most recent value), Count (number of records). Date range is configurable per summary (today, this week, this month, last 30 days, all time, custom). The user can add, edit, and remove summaries via a "+" button and per-summary "⋯" menu.
- **Charts section:** Chart panels below the summaries. "Add chart" opens the 4-type picker (Line, Bar, Pie, Calendar). Each chart is configurable: which field(s) to plot, date range, aggregation method (per record, daily average, weekly sum, etc.).

**Multi-tracker analysis (Analysis object):**
- Accessible from a dedicated "Análise" tab within the Trackers section, or from the Home page's Combined Analysis block.
- The user creates a named Analysis and selects data sources (any Tracker field, any Habit, journal mood).
- Each source gets a color and a label.
- The Analysis view shows: monthly calendar with colored dots per source + legend + chart panels.

---

## SECTION P: WIDGETS (HOME SCREEN / LOCK SCREEN)

**Widget types:**

1. **Quick-add widget:** A small widget (2×1 grid units) with two buttons: "Journal entry" and "Add task". Tapping opens the respective creation form within the app. Configurable button labels and targets.

2. **Calendar widget (configurable view mode):**
   - Size: 4×2 (week view) or 4×4 (month view).
   - Shows colored dots/chips for events, tasks, habits, and pomodoros on each day.
   - A "+" button in the top-right corner of the widget opens the task creation form.
   - Tapping the widget (outside a specific item): opens the app's Planner in the corresponding view (month/week/day).
   - Tapping a specific day: opens the Planner's Day view for that day.
   - Tapping a specific item chip: opens that item's detail view.

3. **Category widget:** Shows all items in a configurable category filter. Example: "All high-priority tasks", "Habits this week", "Projects active". Configuration: filter conditions (same as Category definitions). Display: list of titles + status + priority flag.

4. **Obsidian Note widget:** Shows the rendered content of a specific Obsidian note. The note is selectable via the link picker when configuring the widget. Updates whenever the note changes. Tapping opens the note's detail view in the app. Useful for: Daily note for today, a reference checklist, a project summary.

**Widget configuration:**
Widgets are configured by long-pressing the widget on the home screen (standard OS behavior). This opens a widget configuration sheet within the app.

---

## SECTION Q: ARCHIVE (UNIVERSAL)

Every object type in the app supports archiving. Archived objects are NOT deleted — their Obsidian file gains `archived: true` in the frontmatter.

**Archive page (Settings → Archive):**
- A list of ALL archived objects across ALL categories, sorted by archive date (most recently archived first).
- A filter bar at top: filter by object type (All / Tasks / Habits / Journal / Trackers / People / Resources / etc.).
- Search bar.
- Each row: object type icon + title + archive date + "Restore" button.
- Tapping "Restore": removes `archived: true` from the frontmatter, returns the object to its original view. Undo snackbar appears.
- Tapping the row (not the Restore button): opens the archived object's detail view (read-only mode with a banner: "Arquivado — toque para restaurar").

**Per-section archive:**
Each section within the app (Habits, Trackers, Tasks, etc.) also has its own archive accessible from that section's header "⋯" menu → "Ver arquivados". Shows only archived items of that type.

---

## SECTION R: RECAP — OBSIDIAN FRONTMATTER PROPERTIES (CANONICAL FULL LIST)

Every app-managed Obsidian file includes these standard properties in its YAML frontmatter, regardless of type. This enables universal filtering, searching, and Dataview querying across the entire vault.

```yaml
---
# UNIVERSAL PROPERTIES (all object types)
id: "unique-uuid-or-slug"         # Stable identifier, never changes even if title changes
type: task                         # task | habit | tracker | goal | project | person | resource | mood | analysis | daily_note
title: "Human-readable title"
created_at: 2024-12-11T09:15:00
updated_at: 2024-12-11T14:30:00
archived: false

categories:                        # WikiLinks defining type and context
  - "[[tasks]]"
  - "[[trabalho]]"

tags:                              # Standard Obsidian tags
  - projeto
  - trabalho

  - "[[mapa-trabalho]]"
  - "[[mapa-desenvolvimento]]"

links:                             # Explicit property-level links to any page
  - "[[projeto-alpha]]"
  - "[[pessoa-joao]]"

# TYPE-SPECIFIC PROPERTIES follow below (vary by type)
# See individual object specifications for each type's additional properties
---
```