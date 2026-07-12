# App Guidelines V5.3 — Complete and Authoritative Specification

> **How to use this document**
> This is the single source of truth. When any previous version (V1–V4, screenshots, chat messages) conflicts with this document, this document wins.
>
> **All UI text, labels, and content in the app are in English.** This applies to every screen, button, sheet, and notification described below. This document itself is also in English.
>
> **All spacing/sizing units in this document are `dp`** (density-independent pixels — Flutter's logical pixel unit). There is no `pt`/`dp` platform distinction in Flutter; both platforms render the same logical pixel value.

---

## CHANGELOG — V5 → V5.1

Sourced from a batch of real usage notes (WhatsApp messages, late June 2026). Pure bug reports (crashes, overflow rendering, broken buttons with no spec ambiguity behind them) are **not** included here — those go straight to the dev backlog, not this document. Only items that change, add to, or remove something from the spec are listed.

- **Event/Pomodoro:** scheduling form must live-recompute total hours/cycles/pomodoros/breaks as the pomodoro count changes; linking generalized to any object (not just Task/Goal); unscheduled/not-yet-started pomodoro Events render muted in Planner with a ▶ play icon, both in Planner and in the Event's own detail view.
- **Pomodoro popup mode:** now fully specified as a draggable floating countdown bubble, overlay-over-any-app, drag-to-reposition, drag-down-to-dismiss.
- **Day Theme + Time Block:** merged into a single screen (was two separate More-menu entries); relocated to More, directly below Shopping List.
- **Collection Note:** major storage model change — now backed by the Obsidian Bases plugin; each table row is a real, individual Obsidian note file, not an embedded array.
- **Resources:** formal metadata-source list (Google Books, IMDb, Amazon, Goodreads, Open Library), with original-language title plus a pt-BR title captured as an alias.
- **FAB:** Habit was missing as a creation option — added. "Record" now also supports logging against an existing Habit's linked tracker, not only standalone Tracking Records. All Organizer types must be creatable, either from the FAB or from dedicated "Add [Type]" buttons that navigate to the canonical form (never an inline mutation).
- **Android hardware back button:** explicit rule added — always pops the in-app navigation stack one level at a time down to Home; never exits the app.
- **Photos:** geolocation EXIF data is stripped automatically on save (privacy default, no user action required).
- **Inbox triage:** converting an Inbox Item must remove/transform the original — never leaves an orphaned copy behind in the Inbox list.
- **Overdue surfacing:** overdue Tasks/Reminders must appear in the Journal Timeline and the Planner, both places prompting "Reschedule."
- **Object Identification conflict UI:** resolution buttons must state the exact consequence ("Convert to Note," "Convert to Task," "Move to [folder]"), never a generic "Resolve conflict" button. Conflict handling also now explicitly covers content-object-vs-organizer collisions (e.g. a file that qualifies as both a Note and an Area), not just organizer-vs-organizer ones.
- **Dashboard Panels:** the V5 deduplicated list is retired — the panel system is being redesigned from a blank slate. This document now only specifies the *mechanics* of panels (how they're added/configured/removed), not a prescriptive list of panel types, until the redesign is complete.
- **Social Post:** gains `creator` (platform handle/author); duplicate-URL detection with an "already saved on [date/time]" banner (Edit / Dismiss); multi-Resource extraction from one post (e.g. a video recommending several books becomes several linked Resource objects, each metadata-enriched); creating and linking a new Task/Project/Label/Goal/Habit/Idea/System from within the Social Post save flow now follows the same no-data-loss navigation pattern already defined for Triple Check (Part 2, Task).
- **Universal Search Service:** gains a dedicated "Social" results tab, default-sorted by last modified, plus filters by platform and by `creator`.
- **Universal Linking:** now supports block-level references (`[[note#^block-id]]`), so a link can point at a specific passage inside an object, not only the whole object.
- **System:** gains a formal `scheduler` field (recurring auto-trigger), on top of its existing manual/on-demand execution.
- **Social Post video transcription:** new requirement, analogous to the already-planned OCR feature — automatic, free transcription of saved video content, rendered in a toggleable, searchable, editable section. Engine choice is flagged as an implementation-research item, not fully pinned down here.
- **Combined Analysis:** a tracker field with no data on a given day now renders as a **gap in the line** (no point, line pauses and resumes), never as an implicit zero.
- **New support object: Wellbeing Indicator** — a composite, threshold-based health signal built from one or more `DataSourceReference`s (Part 1.4), each with its own healthy/watch/alert bands, surfaced via a "Health Alerts" strip.
- **Reminder Configuration:** gains an escalation mechanism — reminders repeatedly dismissed/ignored can step up in intensity (push → alarm, color change, longer vibration) instead of staying static forever.
- **Task:** gains a "soft-recurring maintenance task" mode for chores that need to happen roughly every N days without a strict deadline (e.g. cleaning the washing machine's lint trap) — see Part 2, Task.
- **General design principle:** no text/control may overflow its container — see Part 19.

---

## CHANGELOG — V5.1 → V5.2

- **Mood System Overhaul:** complete 2-axis mood model (energy × pleasantness, 0–10 scale) replacing the old 1D numeric value; 80 proprietary mood catalog entries (20 per quadrant: Yellow, Red, Green, Blue); lazy file creation for system moods; one-time migration service for existing user moods; mood picker UI reworked to 2-step quadrant selection → word grid with emoji, label, and description; mood settings screen updated with quadrant grouping, System badge, "Edit coordinates" unlock flow for system moods, custom mood cap raised from 15 to 20, sliders updated to 0–10 scale; mood_entries daily-note generator reads pleasantness/energy directly from MoodDefinition at generation time.

---

## CHANGELOG — V5.2 → V5.3

- **Rotation System (new):** Projects now support rotation-based zone cycling with `rotationGroups` (array of RotationGroup objects with name, emoji, colorHex, periodDays, order), `rotationStartDate`, and computed `rotationCycleLengthDays`. RotationService computes active status, day of period, occurrence number, and upcoming groups. New screens: RotationOverviewScreen (shows current zone and upcoming schedule) and RotationZoneDetailScreen (zone-specific task list). Tasks can be assigned to rotation groups via `rotationGroupId`, `rotationFrequencyType` (none/daily/oncePerPeriod/everyNRotations), `rotationEveryN`, `rotationLastCompletedAtOccurrence`, and `rotationDailyCompletions` map.
- **Alignment Tracking (new):** Tasks and Habits now support alignment tracking (planned vs actual timing). Task gains `flexibilityWindowMinutes` (null = off) and `isAlignmentTrackable` getter. HabitSlot gains `isAlignmentTrackable` via parent Habit. AlignmentService logs `AlignmentLogEntry` records with itemId, date, plannedTime, actualTime, deltaMinutes, and computed state (early/aligned/drifting/missed). Alignment states are stored in daily notes as ```alignment``` blocks and surfaced via AlignmentInsightsPanel.
- **Focus Relay (new):** Tasks support Focus Relay mode via `relaySteps` (List<RelayStep>), replacing flat Pomodoro for structured work sessions. RelayStep defines step name, duration, type (work/break), and optional transition actions. When `hasRelaySteps` is true, Pomodoro uses relay sequence instead of single work/break cycle.
- **Day Dial Widget (new):** Circular day visualization widget showing hour-by-hour activity state. DayDialHourState tracks hour (0-23), DialHourKind (idle/sleep/pomodoroCompleted/pomodoroPlanned/event), fillFraction, and optional habit/reminder associations. DayDialAggregatorService computes state from vault objects. Rendered via DayDialWidget with configurable size and theme integration.
- **Week Time Grid (new):** Weekly calendar grid view (WeekTimeGrid) showing Tasks and Habits across 7 days with time-based layout. Displays day names and dates, highlights current day, shows time column, color-coded items by type/priority, interactive tap navigation to UniversalDetailView.
- **Windows Dial Companion App (new):** Standalone Windows desktop application (windows_dial_main.dart) displaying DayDialWidget with real-time updates. Auto-refreshes every minute, includes date navigation, vault integration, Google Calendar integration, Pomodoro provider integration.
- **HabitSlot Actions (enhanced):** HabitSlot now supports per-slot `actions` (List<ActionDef>) triggered on slot completion, in addition to habit-level day-complete actions. AutomationService executes both slot-level and habit-level actions.
- **Overdue Detail Screen (new):** Dedicated screen (OverdueDetailScreen) for viewing and managing overdue Tasks, Habits, and Goals. Surfaces items past their due date with quick "Reschedule" actions. Integrated with OverdueProvider for reactive state.
- **OCR Service (implemented):** OcrService using Google ML Kit for text recognition from images. Returns OcrResult with text, hasText flag, and blockCount. Integrated with scan document flow and photo attachments.
- **Collection Row Service (new):** CollectionRowService parses Collection Note body into structured rows (CollectionRow) with noteSlug, blockId, lineIndex, rawText, displayTitle, and subtitle. Supports emoji stripping and pipe (::) delimiter parsing. Each row represents a real Obsidian note file when using Obsidian Bases plugin.
- **Automation Service (enhanced):** Expanded AutomationService with additional action types and improved execution logic. Supports add_entry, create_task, create_note, update_kpi, send_notification, open_url, and custom_script actions. Executes habit slot actions, habit day actions, and tracker actions.

---

## CHANGELOG — V4 → V5

This section exists so nothing gets silently lost. Every item below was found in a 5-round audit of V4 plus a clarification pass with the product owner.

**Removed entirely** (see "Deprecated & Removed" section below for the sweep rule):
- MOC (already removed in V4, reconfirmed)
- Places / Place organizer / any map feature
- "Routines" as a bottom-nav page (folded into System)
- Goal `plan_mode` (folded into Project)
- Folder-prefix and folder-based default location as an *automatic* app behavior (Object Identification's "Folder" marker type still exists as a *user-chosen* option — see Part 21)
- The standalone `participants`/`places`-style special-cased relation fields — social_refs merged into the universal `links` field

**Structural fixes:**
- Object Identification no longer auto-assigns folders by type; "Folder" remains available only as an explicit user configuration.
- Goal simplified to an identity/aspiration object; Project absorbs what used to be Goal's `plan_mode` (objective, strategy, phases).
- Universal `categories`, `links`, `reminders` fields (already present in code on every `ContentObject`) are now formally documented as first-class, reusable mechanisms instead of being redefined ad hoc per object.
- Mood-per-day fixed: daily note frontmatter now stores a derived array (`mood_entries`) instead of a single scalar mood, so multiple moods per day are representable and readable by Combined Analysis.
- Habit/tracker daily data: corpo (markdown body of the daily note) is now explicitly *derived, generated, read-only rendering* of the frontmatter — never a second source of truth.
- Pact "Persist" no longer writes to `previous_cycles` (only Pause/Pivot do, since only those end a cycle).
- Archive vs. Delete behaviors clarified and made non-contradictory.
- PMN example data made consistent between sections.
- The canonical `type` enum completed (added `daily_note`, `analysis`, and the 4 newly-documented types), and reconciled with the Object Identification override system.
- Calendar Session redefined as an optional Pomodoro-planning extension of the new unified **Event** object; Google Calendar events and app-native events both become `Event`, differentiated by `source`.
- Triple Check button destinations fully specified as a rule table.
- Steering Sheet unaffected structurally, only the Persist/previous_cycles bug fixed.
- Every object now has a declared list of **required properties**, plus a universal incomplete-save/draft mechanism (new — see Part 1.4).
- Every object type now has a declared **icon/emoji**, used consistently across list rows, chips, and pickers.
- Five previously undocumented object types (Idea, Inbox, Shopping List, Template) are now fully specified from the real implementation. **Saved Filter** is documented as a local (non-vault) configuration object, not a markdown file.
- Area, Activity, and Label (three of the four previously-unspecified Organizer types) now have full specs, pulled from the real shared `Organizer` implementation. Place is removed.
- A duplicate-class bug (two incompatible `ShoppingItem` definitions in the real codebase) is resolved in favor of the embedded-items model — flagged for implementation cleanup.
- A single universal `DataSource` reference type now backs both KPI and Combined Analysis, replacing two parallel, incompatible schemas.
- The FAB (`+` button) is now declared the canonical creation path for every object type; every other entry point (menu actions, "Save as System", quick actions) must open the same underlying form.
- The three separate "search everything in the vault" implementations (WikiLink picker, Command Center, Universal Search Picker) must share one search service.
- Reminder Configuration is confirmed as the single, universal, embedded notification schema (already `ContentObject.reminders`) used by every object, including individual Habit slots.
- Negative habits (`isNegative`) fully specified: checking the box logs an occurrence of the unwanted behavior (a "slip"), and negative habits are excluded from Planner, Dashboard, and Home Screen Widget surfaces by design.
- Scheduler extended with a new generic rule (`days_after_reference_field`) so People's contact-frequency logic (and any future "N days after some date field") runs through the one formal Scheduler system instead of a bespoke one-off.
- `date_range` and `until_done` on Task made mutually exclusive, with `date_range` taking precedence if both are ever set (e.g. from a bad import).
- Object Identification conflict handling reconciled: priority order **does** resolve which type wins automatically, but the ⚠️ badge **still displays** to flag the inconsistency for manual cleanup.
- Backup system clarified: exactly one backup file exists, overwritten in place on the configured cadence (daily/weekly/monthly/biweekly) or on manual "Backup now."
- A `/mnt` — sorry, a **source-folder convention** is defined: `screens/` = routable full-page screens, `widgets/` = reusable pieces with no own route, `components/` = **removed as a category** (folded into `widgets/`) to end the ambiguity between "widget" (reusable UI piece) and "Widget" (Android Home Screen Widget). From V5 on, the Android Home Screen Widget is always called **Home Screen Widget** in this document, never just "widget," to avoid the exact confusion the product owner flagged.
- Energy values changed from a 3-bucket enum to a numeric 0–10 scale, matching how Field Notes already capture energy.
- Journal Timeline now visually distinguishes "created at this time" vs. "happened at this time" entries.
- Pomodoro supports retroactive logging ("I did 4 pomodoros starting at 11am" / "I worked 30 min at this time"), which auto-creates the underlying Calendar Session/Event.
- Project "restart on schedule" now means creating a new Project file (preserving full history of the old one), not resetting the existing one in place.

---

## PARSING RULES (read before everything else)

- **Rule 1** — This document supersedes all previous versions.
- **Rule 2** — MOC does not exist. Do not read, write, or display it.
- **Rule 3** — `habit_mode` absent → treat as `habit`.
- **Rule 4** — `entry_type` absent → treat as `standard`.
- **Rule 5** — `goal_mode` no longer exists (removed in V5 — see Goal/Project split).
- **Rule 6** — `linked_system` absent on a Task → created manually.
- **Rule 7** — `triple_check` absent on a Task → diagnosis never run. Do not error, do not show badge.
- **Rule 8** — The app **never** infers object type from file location or file-name prefix. `type` is always read from frontmatter. Object Identification (Part 21) can define a Folder, Tag, or Property marker as an explicit, user-chosen override — but the app itself never assumes a type-to-folder mapping by default.
- **Rule 9** — Daily notes live at `daily/YYYY-MM-DD.md`. PMN entries live at `daily/YYYY-MM-WNN.md`. The canonical month of a PMN is always read from `date_range_start` in frontmatter, never parsed from the filename.
- **Rule 10** — System files (`type: system`) must be handled gracefully when absent. Show empty state, never error.
- **Rule 11** — IDs are internal. Never display to the user. Always use title/name in the UI.
- **Rule 12** — Object Identification is sovereign **only in the sense that a user-configured marker always wins over any other signal.** The app itself ships with **no default folder-per-type behavior.** Every object is saved, by default, in the single flat folder configured for its Object Identification entry (or in `app/` if the user hasn't configured one), and the file name is a slug for human readability only — never parsed to determine type.
- **Rule 13 (new)** — Every object type declares a list of **required properties** (Part 1.4). The app never blocks a save because of missing required properties — it warns, and always writes what exists to disk, so no data is lost on a crash. The record is flagged as incomplete until required properties are filled.
- **Rule 14 (new)** — The daily note **body** (the markdown under `## Habits`, `## Trackers`, `## Pomodoros`) is always a *generated rendering* of the frontmatter data. It is regenerated on every save and is never read back as a data source by the app's own parser. (A user editing the body directly in Obsidian is a supported escape hatch but is not guaranteed to be re-imported — see Part 20.)

---

## DEPRECATED & REMOVED — Sweep Rule

Whenever you (a developer, or an AI working from this document) find a reference to any of the following, **delete it from the code and from any derived documentation**, don't just leave it disconnected:

| Removed concept | Status |
|---|---|
| `moc` field / MOC pages | Removed since V4. Reconfirmed: if found in frontmatter, ignore and strip on next save. |
| Place / Places (organizer type, `place_ref.dart`, any map UI, `googlePlaceId`, `lat`/`lng` fields) | Removed in V5. No replacement — the app does not do geolocation. |
| "Routines" bottom-nav entry | Removed in V5. Folded into System. |
| Goal `goal_mode: plan`, `objective`, `strategy`, `phases` on Goal | Removed from Goal in V5. These three fields now live on **Project** instead (see Part 2, Project). |
| Standalone `ShoppingItem extends ContentObject` (the file-per-item variant in `shopping_item.dart`) | Removed in V5. The canonical model is the embedded-items variant from `shopping_list_model.dart` (see Object 14, Shopping List). |
| `energy_level` enum (`high`/`medium`/`low`) on Time Block | Removed in V5. Replaced by numeric `energy_level: 0–10` (see Part 3, Time Block / Energy Map). |
| The word "widget" used to mean a reusable UI piece | Removed in V5. Use **component** for reusable UI pieces with no own route; reserve **Home Screen Widget** exclusively for the Android/iOS home-screen widget feature (Part 15). |

**Standing rule:** any time a future audit finds a leftover reference to something in this table, treat it as a bug, not a design choice — remove it, don't work around it.

**Privacy default, new in V5.1:** any photo saved through the app (Entry photos, Resource covers, attachments, etc.) has its **geolocation EXIF metadata stripped automatically on save**, with no user action required and no setting to turn this back on — this is consistent with removing Places/maps entirely from the app; the app never retains or displays photo geolocation.

---

## PART 19 — DESIGN SYSTEM CONSISTENCY (new in V5.2)

### 19.1 Design System Constants — MANDATORY

**NEVER use hardcoded values for spacing, border radius, font sizes, or border width.** ALWAYS use the constants defined in `lib/ui/theme.dart`:

```dart
// ✅ CORRECT
padding: const EdgeInsets.all(AppSpacing.lg),
borderRadius: BorderRadius.circular(AppBorderRadius.md),
fontSize: AppTextSize.md,
borderWidth: AppBorder.normal,

// ❌ WRONG
padding: const EdgeInsets.all(16),
borderRadius: BorderRadius.circular(12),
fontSize: 14,
borderWidth: 1.5,
```

**Available constants:**

#### AppBorderRadius
- `xs` = 4.0 (very small elements)
- `sm` = 8.0 (badges, small chips)
- `md` = 12.0 (inputs, buttons)
- `lg` = 16.0 (standard cards)
- `xl` = 20.0 (highlighted cards, chips)
- `xxl` = 24.0 (sheets, modals)
- `xxxl` = 32.0 (large elements)

#### AppSpacing
- `xs` = 4.0 (minimum spacing)
- `sm` = 8.0 (compact spacing)
- `md` = 12.0 (standard spacing)
- `lg` = 16.0 (comfortable spacing)
- `xl` = 20.0 (generous spacing)
- `xxl` = 24.0 (large spacing)
- `xxxl` = 32.0 (very large spacing)

#### AppTextSize
- `xs` = 10.0 (small labels, captions)
- `sm` = 12.0 (auxiliary text, metadata)
- `md` = 14.0 (standard body text)
- `lg` = 16.0 (item titles, large body)
- `xl` = 18.0 (section titles)
- `xxl` = 20.0 (large titles)
- `display` = 28.0 (screen titles)

#### AppBorder
- `thin` = 1.0 (subtle borders)
- `normal` = 1.5 (standard borders)
- `thick` = 2.0 (highlighted borders)
- `extraThick` = 3.0 (very highlighted borders)

#### AppIconSize
- `xs` = 12.0 (very small icons)
- `sm` = 16.0 (small icons)
- `md` = 20.0 (standard icons)
- `lg` = 24.0 (large icons)
- `xl` = 32.0 (very large icons)
- `xxl` = 48.0 (highlighted icons)
- `display` = 56.0 (hero icons)

### 19.2 Reusable Components — MANDATORY

**ALWAYS use the reusable components available in `lib/ui/widgets/` instead of reimplementing duplicated patterns:**

#### StandardSheet (`lib/ui/widgets/standard_sheet.dart`)
Use for ALL bottom sheets and modals:

```dart
// ✅ CORRECT
StandardSheet(
  radius: SheetRadius.large,
  showHandle: true,
  child: YourContent(),
)

// ❌ WRONG
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).scaffoldBackgroundColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
  ),
  child: YourContent(),
)
```

#### AppChip (`lib/ui/widgets/app_chip.dart`)
Use for ALL chips (choice, filter, action):

```dart
// ✅ CORRECT
AppChip(
  label: 'Label',
  selected: isSelected,
  onTap: () => {},
  variant: ChipVariant.choice,
  size: ChipSize.medium,
)

// ❌ WRONG
ChoiceChip(
  label: Text('Label'),
  selected: isSelected,
  onSelected: (_) => {},
  // ... reimplementing styles manually
)
```

#### StatusBadge (`lib/ui/widgets/status_badge.dart`)
Use for ALL status badges:

```dart
// ✅ CORRECT
StatusBadge(
  label: 'Completed',
  variant: BadgeVariant.success,
  size: BadgeSize.medium,
)

// ❌ WRONG
Container(
  decoration: BoxDecoration(
    color: AppColors.success.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text('Completed'),
)
```

#### DatePickerField (`lib/ui/widgets/date_picker_field.dart`)
Use for ALL date pickers:

```dart
// ✅ CORRECT
DatePickerField(
  selectedDate: _date,
  onDateChanged: (date) => setState(() => _date = date),
  label: 'Due Date',
)

// ❌ WRONG
GestureDetector(
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _date = date);
  },
  child: TextField(...),
)
```

#### TimePickerField (`lib/ui/widgets/time_picker_field.dart`)
Use for ALL time pickers:

```dart
// ✅ CORRECT
TimePickerField(
  selectedTime: _time,
  onTimeChanged: (time) => setState(() => _time = time),
  label: 'Start Time',
)

// ❌ WRONG
GestureDetector(
  onTap: () async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _time = time);
  },
  child: TextField(...),
)
```

#### AppDropdown (`lib/ui/widgets/app_dropdown.dart`)
Use for ALL dropdowns:

```dart
// ✅ CORRECT
AppDropdown<String>(
  value: _selectedValue,
  items: [
    DropdownMenuItem(value: 'option1', child: Text('Option 1')),
    DropdownMenuItem(value: 'option2', child: Text('Option 2')),
  ],
  onChanged: (value) => setState(() => _selectedValue = value),
  label: 'Select Option',
)

// ❌ WRONG
DropdownButtonFormField<String>(
  value: _selectedValue,
  items: [...],
  onChanged: (value) => setState(() => _selectedValue = value),
  decoration: InputDecoration(...),
)
```

#### AppSwitchTile (`lib/ui/widgets/app_switch_tile.dart`)
Use for ALL switches in lists:

```dart
// ✅ CORRECT
AppSwitchTile(
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
  title: 'Enable Feature',
  subtitle: 'Description of the feature',
)

// ❌ WRONG
SwitchListTile.adaptive(
  contentPadding: EdgeInsets.zero,
  title: Text('Enable Feature'),
  subtitle: Text('Description'),
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
)
```

#### ConfirmDialog (`lib/ui/widgets/confirm_dialog.dart`)
Use for ALL confirmation dialogs:

```dart
// ✅ CORRECT
final confirmed = await ConfirmDialog.show(
  context,
  title: 'Delete item?',
  content: 'This action can be undone for 30 days.',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  isDestructive: true,
);

// ❌ WRONG
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Delete item?'),
    content: const Text('This action can be undone for 30 days.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text('Delete'),
      ),
    ],
  ),
);
```

#### FormSection (`lib/ui/widgets/form_section.dart`)
Use for ALL form sections:

```dart
// ✅ CORRECT
FormSection(
  title: 'Basic Information',
  description: 'Enter the basic details',
  children: [
    TextFormField(...),
    TextFormField(...),
  ],
)

// ❌ WRONG
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Basic Information', style: ...),
    Text('Description', style: ...),
    const SizedBox(height: 12),
    TextFormField(...),
    TextFormField(...),
    const SizedBox(height: 16),
  ],
)
```

#### ListItem (`lib/ui/widgets/list_item.dart`)
Use for ALL interactive list items:

```dart
// ✅ CORRECT
ListItem(
  leading: Icon(Icons.task),
  title: Text('Task Title'),
  subtitle: Text('Task description'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => navigateToDetail(),
)

// ❌ WRONG
InkWell(
  onTap: () => navigateToDetail(),
  borderRadius: BorderRadius.circular(12),
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(...),
  ),
)
```

#### UniversalSearchPickerSheet (`lib/ui/widgets/universal_search_picker.dart`)
Use for ALL vault object search pickers:

```dart
// ✅ CORRECT
final selected = await showModalBottomSheet<ContentObject>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => UniversalSearchPickerSheet(
    title: 'Link object',
    initialFilter: 'task',
    onSelected: (obj) => Navigator.pop(context, obj),
  ),
);

// ❌ WRONG
// Do not implement your own search picker
```

#### WikiLinkPicker (`lib/ui/widgets/wiki_link_picker.dart`)
Use for ALL WikiLink pickers in rich text editors:

```dart
// ✅ CORRECT
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => WikiLinkPicker(
    onSelected: (obj) {
      // Insert link [[obj.title]]
    },
  ),
);

// ❌ WRONG
// Do not implement your own wiki link picker
```

#### showOrganizerPickerModal (`lib/ui/widgets/organizer_picker_modal.dart`)
Use for ALL multi-select organizer pickers:

```dart
// ✅ CORRECT
final selected = await showOrganizerPickerModal(
  context,
  ref,
  initialSelected,
);
if (selected != null) {
  setState(() => _organizers = selected);
}

// ❌ WRONG
// Do not implement your own organizer selection modal
```

#### OrganizerSelectorField (`lib/ui/widgets/organizer_selector_field.dart`)
Use for ALL organizer selection fields in forms:

```dart
// ✅ CORRECT
OrganizerSelectorField(
  label: 'Collections',
  selectedOrganizers: _organizers,
  onChanged: (value) => setState(() => _organizers = value),
)

// ❌ WRONG
// Do not implement your own organizer selection field
```

### 19.3 Themeable Properties

The `AppThemeConfig` now supports the following themeable properties:

- `borderRadius` (default: 16.0) - Global UI roundness
- `spacingScale` (default: 1.0) - Spacing scale (0.8 = compact, 1.2 = spacious)
- `fontScale` (default: 1.0) - Font scale (0.9 = smaller, 1.1 = larger)
- `cardElevation` (default: 0.0) - Card elevation
- `useShadows` (default: true) - Shadow usage
- `habitColors` - Customizable habit color palette
- `statusColors` - Customizable status color palette
- `priorityColors` - Customizable priority color palette

**When updating the theme via `AppearanceScreen`, preserve ALL existing properties:**

```dart
final updatedTheme = AppThemeConfig(
  id: activeTheme.id,
  label: activeTheme.label,
  accentColor: activeTheme.accentColor,
  backgroundColor: backgroundColor,
  icon: activeTheme.icon,
  description: activeTheme.description,
  fontFamily: activeTheme.fontFamily,
  borderRadius: activeTheme.borderRadius,           // ← Preserve
  spacingScale: activeTheme.spacingScale,           // ← Preserve
  fontScale: activeTheme.fontScale,                 // ← Preserve
  cardElevation: activeTheme.cardElevation,         // ← Preserve
  useShadows: activeTheme.useShadows,               // ← Preserve
);
```

---

## PART 1 — CONCEPTUAL ARCHITECTURE

### 1.1 Vault Structure

By default, every object the app creates lives in a single flat, user-configurable folder (default: `app/`), regardless of type. Type is always determined by the `type` field in YAML frontmatter — never by folder, never by filename prefix.

**Fixed exceptions** (these locations are structural, not overridable by Object Identification):
- `daily/YYYY-MM-DD.md` — daily notes
- `daily/YYYY-MM-WNN.md` — PMN entries
- `moods/SLUG.md` — mood definitions (created lazily)
- `analyses/SLUG.md` — Combined Analysis definitions
- `_attachments/` — photos and files
- `_deleted/` — soft delete (auto-purged after 30 days, see Part 14)
- `_conflicts/` — sync conflict backups (auto-purged after 30 days)
- `_backups/` — the single rolling backup file (see Part 12)

**Object Identification** (Part 21) lets the user *optionally* define, per type, a Folder, Tag, or Property marker. When configured, that marker takes priority over the flat default — but the app never assumes this on its own.

**Conflict detection:** If an object's attributes point to conflicting types, the app resolves the conflict automatically using the priority order configured in Object Identification (Part 21) — the object is treated as whichever type wins that ordering. It **still** displays a ⚠️ next to the title everywhere it appears, and still appears on the "Conflicts" page (More menu), so the user can clean up the underlying inconsistency even though the app didn't get stuck.

### 1.2 Two Categories of Objects

**CONTENT OBJECTS** — user-generated content. 13 types:
1. Entry (journal entry) — includes Field Note and PMN sub-modes
2. Task — includes Triple Check and System link
3. Goal — identity/aspiration object (simplified in V5)
4. Habit — includes Pact mode
5. Tracker (definition) + Tracking Record (instance)
6. Note (Text, Outline, Collection)
7. Event — includes optional Pomodoro planning (formerly "Calendar Session")
8. Reminder
9. System
10. Social Post
11. Idea *(newly documented in V5)*
12. Inbox Item *(newly documented in V5)*
13. Shopping List *(newly documented in V5; absorbs Shopping Item)*
14. Template *(newly documented in V5)*

**ORGANIZER OBJECTS** — structural containers. Every content object can belong to multiple organizers simultaneously. Organizers have their own Timeline aggregating all associated content.

Organizer types (Place removed in V5):
1. Area (life domain: "Work," "Health," "Family")
2. Project (has dates; absorbs old Goal `plan_mode`; lives under Area or Activity)
3. Activity (recurring interest/theme; lives under Area)
4. Task (a Task is also an Organizer)
5. Goal (a Goal is also an Organizer)
6. Habit (a Habit is also an Organizer)
7. Tracker (a Tracker is also an Organizer)
8. Label (flexible tag, no hierarchy)
9. Person (named person)

Hierarchy: Area > Activity > Project > [Tasks, Habits, Trackers, Labels, People]

**Non-vault configuration objects** (not markdown files, not part of either category above):
- Saved Filter (local device/app config — see Part 3)
- Object Identification rules (Part 21, stored in app settings)

### 1.3 Universal Object Properties

Every object — content or organizer — inherits these base properties (already implemented as `ContentObject` in code; this section formalizes them as intentional, reusable mechanisms rather than ad hoc per-object fields):

- `id` — internal, never shown to the user
- `type` — see the full enum in Part 20
- `title`
- `icon` / `emoji` — every type has a default icon (Part 1.5); individual objects can override it
- `categories` — **personal, freeform organizational tags**, distinct from `organizers`. See note below.
- `tags` — freeform labels
- `aliases` — alternate names, also used for WikiLink resolution
- `links` — the **single universal linking mechanism** (Part 16). Absorbs what V4 called `social_refs`. Renders as a "Links" section with chips in every detail view.
- `organizers` — structural placement in the Area/Activity/Project/etc. hierarchy
- `reminders` — array of Reminder Configuration blocks (Part 13); this is how every object, including individual Habit slots, gets push/popup/alarm notifications, with no separate per-object reminder schema.
- `created_at`, `updated_at`
- `archived`
- `pinned`
- `order`

**On `categories` vs. `organizers` vs. `links`:** `categories` is a personal, cross-cutting classification the user defines for themselves (e.g., grouping Resources by media type, or tagging anything with a personal label like "2026 goals"). It's freeform text, but each category value **can also resolve to a link** — i.e., a category can point to any vault object, not just be a plain string. This makes `categories` effectively a lightweight, user-facing subset of the linking system, distinct in intent from the structural `organizers` hierarchy. `categories` is available on every object (it's already a base field in code), not just Resource — but each screen only surfaces the categories that are meaningful for that type (e.g. Resources shows "Media type" as its primary categories use case; other objects can use it freely for personal organization).

**Depends-on stays separate:** `depends_on` on Task remains its own field, not folded into `links`, because it changes actual app behavior (blocking) rather than being a passive reference.

### 1.4 Required Properties & Incomplete Save (new in V5)

Every object type declares a **minimum required-properties list** (specified per object in Part 2). Behavior:

1. The app **never blocks a save.** If the user tries to close/save an object missing a required property, the app still writes the file to disk immediately (`archived: false`, all filled fields intact, missing ones simply absent) — this guarantees no data loss on a crash or accidental close.
2. A non-blocking warning appears: "Missing: [Property Name]" listing exactly which required properties are still empty.
3. The object gets `is_incomplete: true` in frontmatter (derived, not manually editable) as long as any required property is missing.
4. Incomplete objects show a small "Incomplete" badge (outline, muted, with a "!" icon — never color-only, see Part 18) in list rows and detail views, and appear in a filter ("Incomplete") available from every list screen.
5. Once all required properties are filled, `is_incomplete` clears automatically on next save.

**Per-object required properties are listed in each object's spec in Part 2.** As a baseline default (used unless a type overrides it): `title` is required on every type.

### 1.5 Universal Type Icons

Every object type has a **default icon/emoji**, used consistently in: list rows (leading position), chips, pickers, the Command Center, breadcrumbs, and the Universal Frontmatter icon field. Individual objects may override their type's default via the `icon` property.

| Type | Default icon |
|---|---|
| Entry (standard) | 📓 |
| Entry (field_note) | ⚡ (or category-specific — see Part 2) |
| Entry (pmn) | 📋 |
| Task | ✅ |
| Goal | 🧭 |
| Habit | 🔁 |
| Habit (pact) | 🧪 |
| Tracker | 📊 |
| Note (text) | 📝 |
| Note (outline) | 🗂 |
| Note (collection) | 🗃 |
| Event | 📅 |
| Reminder | 🔔 |
| System | ⚙️ |
| Social Post | 🔗 |
| Idea | 💡 |
| Inbox Item | 📥 |
| Shopping List | 🛒 |
| Template | 🧩 |
| Area | 🏔 |
| Project | 🎯 |
| Activity | 🔄 |
| Label | 🏷 |
| Person | 👤 |

---

## PART 1.4 — UNIFIED LINKING & DATA SOURCE

### Universal Linking (`links`)

`links` (Part 1.3) is the **single** mechanism for "this object references that object," replacing the V4 pattern of one bespoke array per relation type. It absorbs Social Post's old `linked_tasks`/`linked_content` and Task's old `social_refs`. Rendered in every detail view as a "Links" section (chips, tap to navigate), with the same filter-by-type search UI already specified for Social Post in V4 — now generalized to every object.

**Block-level references (new in V5.1):** a `links` entry can optionally point at a specific block inside a target object, not just the whole file, using Obsidian's native block-reference syntax: `[[note-slug#^block-id]]`. This is what makes it possible to build a "go-to" reference System (Part 2, Object 9) that pulls together specific passages from different places — e.g. one excerpt from a book Note, one checklist item from an unrelated Task, a specific line from a Tracker's notes — into a single collected view, without duplicating the underlying content. The link chip for a block-level reference shows a small "§" indicator distinguishing it from a whole-object link, and tapping it navigates to the target object scrolled/highlighted to that specific block.

**Kept separate on purpose** (these are not folded into `links` because they change actual behavior, not just reference something):
- `depends_on` (Task) — blocks the task
- `participants` (Task, Event, etc.) — kept as its own typed field because it renders with a person-specific affordance (avatar, contact info) that a generic link chip doesn't provide
- `organizers` — structural, not a "reference"

### Universal DataSource (replaces two incompatible schemas)

V4 had two separate, incompatible schemas for "read data from a tracker/habit/mood source" — one for KPI, one for Combined Analysis. V5 unifies these into one `DataSourceReference` used by both:

```yaml
data_source:
  source_type: tracker_field | habit | journal_mood | subtasks | collection | entry | time_spent | manual_quantity
  source_id: "[[tracker-or-habit-slug]]"      # omitted for subtasks/entry/time_spent/manual_quantity
  field_id: "fluxo"                            # only for tracker_field
  dimension: pleasantness | energy             # only for journal_mood
  value_mapping: {leve: 1, medio: 2, forte: 3} # only for categorical tracker fields
  aggregation: sum | average | count | max | min | streak # used by KPI; Combined Analysis charts use raw series
```

- **KPI** wraps one `data_source` plus `target_value`, `current_value` (both now formally declared — see Part 3, KPI), and an `aggregation`.
- **Combined Analysis** wraps one or more `data_source` entries as chart series, each with its own `color`, `label`, `axis`, `normalization`.

Both features now read from the exact same resolver function in the codebase — a KPI and a Combined Analysis series pointing at the same tracker field will always agree.

---

## PART 2 — CONTENT OBJECTS: DETAILED SPECIFICATION

---

### OBJECT 1: ENTRY (Journal Entry)

**Purpose:** Personal chronological journal. Three sub-modes: `standard` (narrative), `field_note` (quick self-observation), `pmn` (weekly Plus/Minus/Next review).

**Required properties:** `date`. (For `field_note`: also `category` and `text`. For `pmn`: also `week`, `date_range_start`, `date_range_end`.)

**Common properties:**
- `entry_type` — enum: `standard | field_note | pmn`. Default: `standard`.
- `date` — ISO datetime. Default: now. Editable retroactively.
- `mood` — WikiLink to a Mood Definition file: `mood:: [[calm]]`
- `feelings`, `photos`, `location` (freeform text/place name — no coordinates, no map; see Deprecated & Removed)
- `organizers`, `archived`, `body`

**`entry_type: field_note` adds:** `category` (enum: `insight | energy | mood_note | encounter`), `text`, `energy_value` (0–10, only when `category: energy` — see Part 3, Energy Map, for the numeric-scale fix).

**`entry_type: pmn` adds:** file of its own at `daily/YYYY-MM-WNN.md`, with `week`, `date_range_start`, `date_range_end`, `referenced_dates` (**must cover every date in the range, inclusive** — this was inconsistent between two V4 examples; the canonical example below is the only correct one), `pact_refs`, `plus`, `minus`, `next`.

**Canonical PMN example (fixes the V4 inconsistency — this is now the only version of this example anywhere in the document):**
```yaml
---
id: "pmn-2026-W21"
type: entry
entry_type: pmn
week: 2026-W21
date_range_start: 2026-05-18
date_range_end: 2026-05-24
referenced_dates:
  - "2026-05-18"
  - "2026-05-19"
  - "2026-05-20"
  - "2026-05-21"
  - "2026-05-22"
  - "2026-05-23"
  - "2026-05-24"
pact_refs:
  - "[[write-100-words]]"
organizers:
  - "[[area-writing]]"
archived: false
created_at: 2026-05-24T18:30:00
updated_at: 2026-05-24T18:30:00
---
## Plus
- Kept the writing pact 6/7 days
## Minus
- Admin piled up on Wednesday
## Next
- Move admin to the afternoon
```

**Journal Timeline — "created" vs. "happened" (new in V5):** every Timeline card (Journal screen and Organizer Detail View) shows a small leading glyph indicating *why* the timestamp is what it is:
- 🕐 **Created marker** — the object's timestamp is when the record was made (e.g., a Task created at 3pm today, an Entry written at 3pm).
- ⚡ **Happened marker** — the object's timestamp reflects when an activity actually occurred, which may differ from when it was logged (e.g., 4 Pomodoros logged as having started at 11am, even if entered into the app at 6pm; a Habit completion backfilled for yesterday).
This is purely a rendering distinction — it reads `created_at` vs. the object's own `occurred_at`/`date` field (where one exists) and shows the appropriate glyph; no new object needs a new field beyond what already exists, except Pomodoro Session, which gains `occurred_at` (see Part 7).

*(Storage format, display rules, and creation UI for standard/field_note/PMN are unchanged from V4 aside from the fixes above.)*

---

### OBJECT 2: TASK

**Required properties:** `title`, `stage`.

**Properties** (unchanged from V4 except as noted):
`id`, `type: task`, `title`, `stage` (`idea | backlog | todo | in_progress | pending | finalized`), `priority`, `start_date`, `end_date`, `date_range`, `until_done`, `duration`, `all_day`, `scheduled_time`, `notes`, `subtasks` (array of full Task files, each with `parent_task`), `organizers`, `tags`, `links` (universal — replaces old ad hoc `links` semantics with the Part 1.4 mechanism), `scheduler`, `reminders`, `color`, `participants` (kept separate, see above), `timer_sessions`, `comments`, `reflection`, `archived`, `parent_task`, `linked_system`, `triple_check`, `depends_on` (kept separate), `estimated_minutes`.

**Alignment Tracking (new in V5.3):** Tasks can track alignment between planned and actual execution time:
- `flexibilityWindowMinutes` — optional integer (null = alignment tracking off for this task). Defines the acceptable deviation window in minutes from the scheduled time.
- `isAlignmentTrackable` — computed getter, true if both `flexibilityWindowMinutes` and `scheduledTime` are set.
- When a task with alignment tracking is completed, `AlignmentService` logs an `AlignmentLogEntry` with:
  - `itemId` — task ID
  - `date` — completion date (yyyy-mm-dd)
  - `plannedTime` — scheduled time (HH:mm)
  - `actualTime` — actual completion time (HH:mm)
  - `deltaMinutes` — signed difference (actual - planned)
  - `state` — computed alignment state: `early`, `aligned`, `drifting`, or `missed`
- Alignment states are stored in daily notes as ```alignment``` code blocks and surfaced via `AlignmentInsightsPanel`.

**Focus Relay (new in V5.3):** Tasks support structured multi-step work sessions via Focus Relay mode:
- `relaySteps` — optional `List<RelayStep>`, replacing flat Pomodoro for structured sessions
- Each `RelayStep` defines:
  - `name` — step name (e.g., "Deep Work", "Review", "Break")
  - `duration` — step duration in minutes
  - `type` — step type: `work` or `break`
  - `actions` — optional transition actions to execute when this step completes
- `hasRelaySteps` — computed getter, true if relaySteps is non-empty
- When `hasRelaySteps` is true, the Pomodoro timer uses the relay sequence instead of the standard single work/break cycle
- Relay mode supports complex workflows like: 25min work → 5min break → 25min work → 15min break → repeat

*(`places` removed — Places no longer exist. `social_refs` removed — folded into `links`.)*

**`date_range` and `until_done` are mutually exclusive.** The create/edit form disables `until_done` when `date_range` is on, and vice versa. If a bad import somehow sets both, `date_range` wins and `until_done` is ignored (logged as a data-cleanliness warning, not silently dropped).

**Triple Check block** — unchanged structure, with one correction: `blocker` is now an **array**, not a scalar, since more than one dimension can fail simultaneously:
```yaml
triple_check:
  head: true
  heart: false
  hand: false
  blocker: [heart, hand]   # array — was a single value in V4, which couldn't represent multi-dimension failure
  diagnosis: "The block is emotional and resource-related."
  checked_at: "2026-05-19T14:30:00"
```
Dataview query updated accordingly: `WHERE contains(triple_check.blocker, "heart")`.

**Triple Check button destinations — formal rule table (resolves V4's undefined CTAs):**

| Dimension failing | Button | Destination |
|---|---|---|
| `head` | Reformulate | Opens the Task in edit mode, focus on the title field |
| `head` | Archive | Archives immediately (standard delete-confirmation pattern) |
| `heart` | Create subtasks | Opens "create subtask" form, pre-focused, parented to this Task |
| `heart` | Postpone | Opens a choice: **quick-postpone chips** (+1 day / +1 week / +1 month) **or** a free date picker — both are offered, chips first, "Pick a date…" link below them for the free picker |
| `hand` | Add dependency | Opens the Universal Search Picker filtered to Task, with **two entry points inside the same sheet**: "Choose existing task" (search results) and "Create new task" (pinned row at the top, always visible) — selecting either sets `depends_on` |
| `hand` | Ask for help | Opens WhatsApp (`https://wa.me/`) with a pre-filled message: "Hey, I could use some help with: [Task title]" |
| all true | View dependencies | Navigates to the `depends_on` list on this Task |
| all true | Check schedule | Opens Planner on this Task's `start_date`/`end_date` |

**Navigation state safety (new in V5):** Triple Check, and any bottom sheet that opens a picker/navigation from within it (e.g., "Add dependency" → Universal Search Picker → "Create new task"), must **auto-save partial diagnosis state before navigating away**. If the user backs out of the Planner (opened via "Check schedule") or finishes creating a new dependency Task, the back button returns to the Triple Check sheet exactly as they left it — either still in edit mode with prior answers intact, or already-saved and showing the read-only result if it had been saved before navigating. No Triple Check state is ever lost by navigating to another screen mid-flow. **This is the general pattern for any nested creation flow in the app** — the same guarantee applies, for example, to creating and linking a Task/Project from within the Social Post save flow (Part 10): neither the in-progress Social Post form nor the in-progress Task/Project form loses data when the other is opened on top of it.

**Soft-recurring maintenance mode (new in V5.1):** for chores that need to repeat roughly every N days but don't need a strict deadline (e.g. "clean the washing machine's lint trap," "water the plants") — a middle ground between a strict Habit and a one-off Task:
- A Task with `priority: low` and a `scheduler` configured can additionally set `flexible_recurrence: true` and `target_frequency_days` (e.g. `30`).
- Such a Task does **not** appear in the Planner as a hard-dated item. Instead, once it's "coming due" (default window: within 20% of `target_frequency_days` of the last completion, e.g. day 24+ of a 30-day target), it surfaces inside the **Today's Habits** Dashboard panel alongside real Habits, visually distinguished (muted/outline style, not a solid Habit row) and showing "Last done N days ago · target every X days."
- From that row, two quick actions are always available: **"Schedule a block"** (creates a linked Event, optionally with a Pomodoro block, for a day/time the user picks) and **"Snooze reminder"** (pushes the next nudge back without changing `target_frequency_days`).
- If the user does neither, the item simply stays visible and increasingly prominent (same "days since" escalation styling as Part 18) until marked done — it never silently disappears, and it never auto-generates a duplicate the way a strict recurring Task could.

---

### OBJECT 3: GOAL (simplified — identity/aspiration object)

**Purpose:** Who do I want to be? What do I want to reach? Goals are about identity and direction, not execution — execution-with-structure lives in Project (below).

**Required properties:** `title`.

**Properties:**
- `id`, `type: goal`, `title`, `description`, `status`
- `start_date`, `end_date` — **both fully optional.** A Goal may have no dates at all (pure identity statement, e.g. "Be more patient"), a target date only, or a full range.
- `kpis` — array of KPI configs (Part 3, now using the unified DataSource)
- `links` — the universal linking mechanism (replaces the old `subtasks: array of WikiLinks` — this resolves the V4 naming collision with Task's embedded `subtasks`; a Goal never embeds Task files, it only *links* to them)
- `organizers`, `color`, `icon`, `comments`, `participants`

*(`goal_mode`, `objective`, `strategy`, `phases`, `schedulers` removed from Goal — see Project.)*

---

### OBJECT — PROJECT (absorbs old Goal `plan_mode`)

Project is documented fully as an Organizer in Part 10, but note here the properties it **gained** in V5 by absorbing what used to be Goal's plan mode:
- `objective` — the why
- `strategy` — the how
- `phases` — array of Phase objects, each grouping Tasks by stage

**Rotation System (new in V5.3):** Projects now support rotation-based zone cycling for structured work periods:
- `rotationGroups` — array of `RotationGroup` objects, each defining a zone with:
  - `id` — unique identifier
  - `name` — zone name (e.g., "Deep Work", "Learning", "Health")
  - `emoji` — optional emoji for visual identification
  - `colorHex` — optional hex color for zone theming
  - `periodDays` — duration of this zone in days
  - `order` — sequence order in the rotation cycle
- `rotationStartDate` — start date of the first rotation cycle
- `rotationCycleLengthDays` — computed total days for one full cycle (sum of all `periodDays`)
- `hasRotation` — computed getter, true if rotationGroups is non-empty and rotationStartDate is set
- `methodLabel` — optional custom label for the rotation method

**RotationService** computes:
- Active rotation status (current group, day of period, occurrence number)
- Upcoming groups with their start/end dates
- Daily completion tracking for rotation-assigned tasks

**New screens:**
- `RotationOverviewScreen` — shows current active zone, day of period, and upcoming schedule
- `RotationZoneDetailScreen` — zone-specific task list and completion tracking

**Task integration:** Tasks can be assigned to rotation groups via:
- `rotationGroupId` — reference to the parent RotationGroup
- `rotationFrequencyType` — enum: `none`, `daily`, `oncePerPeriod`, `everyNRotations`
- `rotationEveryN` — for `everyNRotations` frequency, how many cycles between occurrences
- `rotationLastCompletedAtOccurrence` — tracks last completed occurrence number
- `rotationDailyCompletions` — map of date strings to completion status for daily tasks

Everything else about Project (state, priority, dates, primary/secondary KPI, tasks, scheduler, total Pomodoro time, quick access) is unchanged from V4 — see Part 10.

**Project "restart on schedule" (fixes V4's undefined behavior):** when a Project's `scheduler` fires and the Project is due to recur, the app **creates a brand-new Project file** (new `id`, fresh `progress`, fresh dates derived from the schedule), and the old Project is archived with a `superseded_by: "[[new-project-slug]]"` link. This preserves full history of every cycle instead of resetting one file in place — consistent with how Pact cycles are preserved in `previous_cycles`.

---

### OBJECT 4: HABIT

**Required properties:** `title`, `habit_mode`.

**Core properties** (unchanged from V4 except as noted): `id`, `type: habit`, `title`, `description`, `color`, `icon`, `habit_mode` (`habit | pact`), `completion_unit`, `daily_goal`, `slots`, `organizers`, `status`, `habitStartDate`, `priority`, `isNegative`, `inputType`, `linkedTrackerSlug`, `actions`, `archived`.

**Habit slot reminders (resolves V4's parallel-reminder-schema bug):** each `HabitSlot` no longer has its own bespoke `reminderEnabled`/`reminderTime`/`notificationType` fields. Instead, each slot carries a **`reminders: List<ReminderConfig>`** — the exact same universal Reminder Configuration schema (Part 13) used everywhere else in the app. This is already how the base `ContentObject` model works in code; V5 simply extends that same list down to the per-slot level. A slot can have zero, one, or multiple Reminder Configurations, each independently push/popup/alarm.

**HabitSlot Actions (new in V5.3):** In addition to habit-level day-complete actions, individual HabitSlots now support per-slot `actions` (List<ActionDef>) triggered on slot completion:
- `actions` field on `HabitSlot` — array of ActionDef objects
- Trigger: `slot_complete` — fires when the individual slot is checked
- Supports slot-specific automation (e.g., different actions for morning vs evening slots)
- Executed by `AutomationService.executeHabitSlotActions()`
- Complements habit-level `day_complete` actions (both can coexist)
- Use cases: slot-specific notifications, KPI updates, task creation, etc.

**Negative habits (`isNegative`) — fully specified (was an orphaned field in V4):**
- A negative habit tracks something the user wants to **stop** doing (e.g., "Smoking," "Doomscrolling").
- Checking the box for a given day means: **"I did the thing I'm trying to avoid, on this day."** It is a log of a slip, not a log of success.
- Success, for streak purposes, is a day that passes **without** a check — this already matches the real streak logic in the codebase (`isNegative && recordDate != checkDate` counts as success).
- **Negative habits are excluded from Planner, Dashboard, and Home Screen Widget surfaces.** They only appear in the dedicated Habits list screen, where the user can log a slip after the fact. This is intentional: a negative habit showing up as a daily checklist item in the Planner would visually normalize "doing the bad thing" as a routine task.
- Days-since badge (Part 18) is especially meaningful here: "5 days since last slip" reads naturally for a negative habit.

**Pact mode** — unchanged from V4, except:

**Steering Sheet "Persist" no longer touches `previous_cycles` (bug fix):**
```
Persist  → ends_at updated with new duration, status: active, pact_outcome: persist.
           previous_cycles is NOT touched — the cycle is still running, not historical.
Pause    → status: paused, pact_outcome: pause. Current cycle data appended to previous_cycles
           (the cycle has genuinely ended).
Pivot    → opens edit form pre-filled. Current cycle data appended to previous_cycles
           (the cycle has genuinely ended).
```

---

### OBJECT 5: TRACKER (definition) + TRACKING RECORD (instance)

Unchanged from V4, except: Tracking Record storage in the daily note is now explicitly documented as **derived, generated body text** (see Rule 14) — the frontmatter nested block under the tracker's slug is the only source of truth; the `## Trackers` markdown section under it is regenerated on every save and never parsed back.

---

### OBJECT 6: NOTE

Text and Outline sub-types are unchanged from V4.

**Collection Note — storage model changed in V5.1 (this replaces V4's embedded `items`/`schema` array approach):**

A Collection Note is now backed by the **Obsidian Bases** plugin (Obsidian's official database-view plugin) instead of storing rows as an embedded array inside one file. Concretely:
- Each **row** of a Collection is a **real, individual Obsidian note file** of its own, living in a dedicated subfolder named after the Collection (e.g. `app/collection-books/*.md`), with whatever properties the Collection's schema defines as that row's frontmatter.
- The Collection Note itself becomes a `.base` configuration file (per the Obsidian Bases format) plus a lightweight `type: note`, `note_subtype: collection` wrapper file that points at the folder and the `.base` view config — this is what makes "opening the Collection in Obsidian" show a native Obsidian Bases table/grid, not a plain markdown file.
- **Adding a row** in the app = creating a new note file in that folder with the schema's default properties, which is why "can't add a row" was breaking before: there was no per-row file being created. The app's "+ Add row" action must call the exact same object-creation path as everything else (Part 4's canonical-creation rule) — a Collection row is just another content object, scoped to that Collection's folder.
- Property types (text, rich_text, quantity, date, time, duration, selection, multi_selection, checkbox, url, email, phone, rating, relation, media, etc.) map directly to Obsidian Bases' own property types where a native equivalent exists; where it doesn't, the app renders its own editor but still writes a Bases-compatible frontmatter type.
- Views (list/gallery/table) are the app's own rendering on top of the same row files — Obsidian Bases' own view config in the `.base` file is generated to match, so opening the same Collection in Obsidian shows an equivalent table.

---

### OBJECT 7: EVENT (replaces "Calendar Session" as the primary object)

**Purpose:** Anything with a specific time on the calendar — whether the user planned it inside the app, or it came from Google Calendar.

**Required properties:** `title`, `date`.

**Properties:**
- `id`, `type: event`, `title`, `date`, `color`
- `source` — enum: `app | google_calendar`. **This is the key new field.** Determines editability:
  - `source: app` → fully editable inside the app.
  - `source: google_calendar` → **read-only inside the app.** All fields are display-only. A prominent "Open in Google Calendar" button is the only way to edit it. The app still renders it normally in Calendar/Planner alongside app-native events.
- `state` — `scheduled | in_progress | completed | backlog | cancelled`
- `time_of_day`, `duration`, `end_time`, `multi_day`
- `linked_item` — optional WikiLink to **any** object in the vault (generalized in V5.1 — was previously limited to `task`/`goal` only; those two fields are removed in favor of this single generic one, consistent with the Universal Linking mechanism in Part 1.4)
- `subtasks` — inline checklist for the event itself
- `note`, `participants`, `reminders`, `organizers`, `scheduler`
- `pomodoro` — **optional** block (this is what used to be the standalone "Calendar Session" object): `{ work_duration, short_break_duration, long_break_duration, long_break_after_blocks }`. When present, this Event is a "time-blocked Pomodoro plan" — the app pre-fills the Pomodoro timer with this Event's linked item and durations when the user taps "Start" on it.
- `backlog` — boolean
- `linked_google_event_id`, `linked_google_event_title`, `linked_google_event_url` — only present when `source: google_calendar`

*(`exported_calendar_id` from V4 is removed — replaced entirely by the `source`/`linked_google_event_*` pair, which already covers both directions of sync unambiguously: an app-native Event that's also pushed to Google keeps `source: app` plus the same `linked_google_event_id` field once exported, so there's exactly one field family for "this Event has a Google-side counterpart," regardless of which side it originated on.)*

**Calendar Session usage note:** wherever this document (or the UI) refers to "Calendar Session," it now means "an Event with a `pomodoro` block." There is no separate object file type for it anymore.

**Planner rendering for scheduled-but-not-yet-run pomodoro Events (new in V5.1):** an Event carrying a `pomodoro` block, while still in `state: scheduled` (i.e., the timer hasn't been started yet), renders **muted** in the Planner (card at ~60% opacity, same color hue, no bold text) so it visually reads as "planned" rather than "happened" or "happening now." It carries a small ▶ play icon (leading or trailing chip, 20dp) that starts the Pomodoro timer directly from the Planner card. The same ▶ icon appears in the Event's own detail view header. Once started, the Event transitions to `state: in_progress` and renders at full opacity like any other Event.

**Scheduling form must show live totals (fixes a real bug):** in the "Schedule a Pomodoro" form, changing the number of pomodoro blocks must immediately recompute and redisplay: total work time, total break time, number of cycles, and total elapsed time (e.g. "3 pomodoros · 2 short breaks · 1h 30min total"). This recomputation is driven directly off `work_duration`, `short_break_duration`, `long_break_duration`, `long_break_after_blocks`, and the block count — never a stale/cached string.

---

### OBJECT 8: REMINDER

**Purpose:** A standalone object whose entire content *is* a Reminder Configuration — used when a reminder isn't attached to any other object (e.g., "Take out the trash," with no linked Task).

**Required properties:** `title`, at least one `reminders` entry.

**Properties:** `id`, `type: reminder`, `title`, `date`, `completable`, `checkboxes`, `organizers`, `scheduler`, `habit_reminder` (derived, true when auto-generated by a Habit slot scheduler), `reminders` (the universal Reminder Configuration array — this **is** the object's payload).

There is no separate "Reminder Configuration" object type distinct from this — Part 13's `ReminderConfig` schema is what every object (including this one) stores in its `reminders` array.

---

### OBJECT 9: SYSTEM

**Creation flow change (V5):** "Save as System" from a Task's `⋯` menu, the Command Center's System quick-run chip, and any future entry point must all open the exact same System creation form used by the FAB (`+` → Note → System) — pre-filled with steps derived from the calling context where relevant (e.g., "Save as System" pre-fills steps from the Task's current subtasks). See Part 4 for the FAB-as-canonical-entry-point rule.

**`scheduler` field (new in V5.1):** System gains an optional `scheduler` property, using the same formal Scheduler system as every other schedulable object (Part 3). When configured, the System auto-executes (Via A's flow, Part 23.7) on the configured cadence, creating a Task from its steps automatically — on top of its existing manual "▶ Execute" / "Execute inline" paths, which remain available regardless of whether a scheduler is set.

---

### OBJECT 10: SOCIAL POST

`linked_tasks` and `linked_content` are both folded into the universal `links` field (Part 1.4) — Social Post no longer has its own bespoke linking schema, it uses the same one everything else uses.

**New properties in V5.1:**
- `creator` — the platform handle/author of the original post (e.g. `@someuser`), used by the Social filter tab in the Universal Search Service (Part 4) and shown in the Social Post grid/list.
- `transcription` — optional string, populated by the automatic video-transcription pipeline described below.

**Duplicate-URL detection (new in V5.1):** when saving a Social Post, the app checks `sourceUrl`/`url` against existing Social Posts. If a match is found, the save flow shows a banner **before** creating a new file: "Already saved on [date] at [time]," with two actions — **"Edit existing"** (opens the existing Social Post instead of creating a new one) and **"Do nothing"** (dismisses the banner, cancels the save, no duplicate is created). The app never silently creates a second file for the same URL.

**Multi-Resource extraction (new in V5.1):** a single saved Social Post (typically a video or carousel of photos) can reference **multiple** Resources at once — e.g. a video recommending five books. From the Social Post detail view, "Extract Resources" opens a lightweight repeatable form: the user types/pastes a title as they spot each one in the photo/video, and each entry runs through the same metadata lookup as a normal Resource creation (Part 9's source list), producing one fully-populated Resource per entry, each automatically linked back to the originating Social Post via `links`. This flow reuses the canonical Resource-creation form (Part 4's canonical-creation rule) per item — it's a fast repeat-loop over that form, not a separate one-off implementation.

**Creating a linked Task/Project from Social Post (new in V5.1):** the Social Post save/detail flow can open Task or Project creation on top of itself (to link the new object back to this post) without losing either form's state — same navigation-state-preservation pattern already specified for Triple Check (Part 2, Task).

**Automatic video transcription (new in V5.1, research-flagged):** analogous to the already-planned OCR feature for images, a saved video Social Post can have its speech automatically transcribed (Portuguese or English), stored as a delimited section in the object's body (e.g. `## 🎬 Transcription`), rendered in the app via a toggleable, searchable, editable section — same interaction pattern as the OCR text section. **The transcription engine itself must be free and fully automatic** (no manual upload/download step); the exact engine (e.g. an on-device or self-hosted speech-to-text model) is left as an implementation-research decision rather than pinned down in this document, since feasibility (on-device performance, licensing) needs to be verified before committing to one. A related but separate ask — embedding the saved video without the source platform's own UI chrome — is noted here as a desired outcome but is likewise an implementation-research item (e.g. extracting a direct media URL) rather than a resolved spec.

---

### OBJECT 11: IDEA *(newly documented, pulled from `idea_model.dart`)*

**Purpose:** A parking lot for things you might want to act on later — separate from Inbox (which is unstructured capture) because an Idea carries status, horizon, and priority, and can be explicitly converted into another object type.

**Required properties:** `title`.

**Properties:**
- `id`, `type: idea`, `title`, `body` (freeform notes)
- `status` — enum: `raw | developing | ready_to_act | converted | dropped`. Default: `raw`.
- `horizon` — enum: `now | soon | someday | no_deadline`. Default: `someday`.
- `priority` — optional, shared `TaskPriority` enum (`none | low | medium | high`)
- `target_date` — optional
- `converted_to_type`, `converted_to_id` — set when the Idea is turned into a Task/Project/Goal/Note via a "Convert" action; `is_converted` is derived (`true` when `converted_to_type` is set)
- `links` — universal linking (replaces the old separate `linked_slugs`/`linked_tasks` pair)
- `color`, `icon` (default 💡)
- `organizers`, `tags`, `archived`

**Creation:** via the FAB, under a new "Idea" entry alongside Note's sub-types (Text/Outline/Collection/System) — or promoted from Inbox (see below).

**Convert action:** menu `⋯` → "Convert to…" → Task / Project / Goal / Note. Creates the target object pre-filled with the Idea's title/body, sets `converted_to_type`/`converted_to_id`, and sets `status: converted`.

---

### OBJECT 12: INBOX ITEM *(newly documented, pulled from `inbox_model.dart`)*

**Purpose:** The absolute fastest possible capture — no fields to fill beyond the text itself. Meant to be triaged later.

**Required properties:** none beyond `title` (an Inbox Item's `title` can simply be an auto-generated preview of its content if the user typed without a title, since the whole point is zero-friction capture).

**Properties:** `id`, `type: inbox`, `title`, `content` (the captured text/body).

**Triage flow:** Inbox screen shows all items newest-first. Each item has quick actions: "Convert to Idea," "Convert to Task," "Convert to Note," "Delete." There is no `status` field — an Inbox Item's lifecycle is binary: it exists (untriaged) or it's gone (converted or deleted).

**Guarantee (was previously buggy, now explicit):** every "Convert to [X]" action **deletes the original Inbox Item file** (moving it through the normal Delete flow, Part 5 — not a soft "hide" or a leftover copy) as soon as the new object is successfully created. There is never a state where both the original Inbox Item and its converted counterpart exist at once, and the Inbox list must reflect the removal immediately without requiring a manual refresh.

---

### OBJECT 13: SHOPPING LIST *(newly documented — resolves a real duplicate-model bug)*

**Implementation note (read before specifying this in code):** the real codebase currently has **two incompatible classes both named `ShoppingItem`** — one in `shopping_item.dart` (a full standalone `ContentObject`, one file per item, with `isCompleted`), and one in `shopping_list_model.dart` (a lightweight embedded value object with `name`, `quantity`, `category`, `note`, `status`, `order`, living inside a `ShoppingList.items` array). **V5 canonicalizes the second one.** The standalone `shopping_item.dart` file and its `type: shopping_item` should be deleted from the app — this also resolves the previously-flagged Object Identification bug where `shopping_item` had a folder-based default, since that type no longer exists.

**Purpose:** A shopping list is one file with a checklist of items — matching the natural Obsidian mental model (one note, one checklist), and enabling fast native Home Screen Widget capture.

**Required properties:** `title`.

**Properties:**
- `id`, `type: shopping_list`, `title`, `emoji` (default 🛒), `color`
- `hide_checked` — boolean, default `true`
- `items` — array of embedded item objects, each with: `id`, `name`, `quantity` (freeform, e.g. "2 kg"), `category` (freeform grouping label, e.g. "Produce"), `note`, `status` (`active | checked | archived`), `order`
- `organizers`, `tags`, `archived`

**Storage:** frontmatter carries the full `items` array as structured data; the body renders as a generated markdown checklist (`- [ ]` / `- [x]`) purely for Obsidian-native readability — same derived-body rule as habits/trackers (Rule 14).

---

### OBJECT 14: TEMPLATE *(newly documented, pulled from `template_model.dart`)*

**Purpose:** A reusable starting point for creating a new object of a given type, with pre-filled frontmatter defaults and body text.

**Required properties:** `title`, `template_type`.

**Properties:** `id`, `type: template`, `title`, `template_type` (freeform string matching any content-object type, e.g. `entry`, `task`, `note`, `habit`, `tracker`, `goal`), `body`, `frontmatter_defaults` (a map of any properties valid for `template_type`, pre-filled on use), `organizers`.

**Usage:** FAB → any creation form → "Use a template" (when templates exist for that type) → picker of matching Templates → form opens pre-filled with `frontmatter_defaults` and `body`.

---

## PART 3 — SUPPORT OBJECTS

### SAVED FILTER *(newly documented — this is NOT a vault markdown file)*

**Implementation note:** unlike every object above, `SavedFilter` in the real codebase does **not** extend `ContentObject` and has no `toMarkdown`/`fromMarkdown`. It's a local, app-side configuration object (stored in app settings/local DB, not in the Obsidian vault). This is intentional and should stay this way — filters are a personal view configuration, not vault content.

**Properties:** `id`, `name`, `target_type` (which object type this filter applies to, or `*` for any), `rules` (array of `{property, operator, value}` — operators: `equals | not_equals | contains | greater_than | less_than | is_empty`), `sort_by`, `sort_ascending`, `group_by` (`none | type | status | organizer | tag | date`), `view_mode` (`grid | list | grouped | matrix`), `matrix_config` (optional — for the Matrix view; ships with an "Eisenhower Matrix" preset: urgency × importance).

**Filterable properties are declared per type** (e.g. Task exposes `status`, `priority`, `tags`, `organizers`, `archived`; Resource exposes `media_type` — renamed from V4's `type`, see Resources below — `status`, `author`, `category`, `rating`, `tags`). Each type's list of filterable properties should be kept in sync with that type's real schema.

### DATASOURCE

See Part 1.4 — this is the unified schema now shared by KPI and Combined Analysis.

### KPI

**Properties (now formalized — `target_value` and `current_value` were used in V4's auto-complete rule but never declared):**
- `data_source` — one `DataSourceReference` (Part 1.4)
- `target_value` — the goal number
- `current_value` — the live computed (or manually entered, for `manual_quantity`) number
- `auto_complete` — boolean. When `true`, reaching `current_value >= target_value` triggers a configured action (reuses the same 7-type Action system from Part 6 — no separate KPI-specific action list).

### SCHEDULER

**11 rule types, plus one new generic rule added in V5:**
1. `number_of_days`
2. `days_of_week`
3. `number_of_weeks`
4. `number_of_months`
5. `number_of_hours`
6. `days_after_last_start`
7. `days_after_last_end`
8. `days_per_period`
9. `linked_item_appears`
10. `n_days_after_linked_item`
11. `first_business_day_of_month`
12. **`days_after_reference_field`** *(new)* — fires N days after any date-type field on **any object**, specified as `{ target_type, field_name, days }`. This is the generic version of what used to be People's bespoke hardcoded "contact frequency" logic. People's automatic contact reminder (below) now runs through this rule instead of its own one-off implementation, and any future "N days after some date field" need reuses it too — no more parallel scheduling systems outside the formal Scheduler.

Everything else about Scheduler (exclusion rules, delay policy, multiple rules per object, the global Scheduler settings page) is unchanged from V4.

### DAY THEME & TIME BLOCK — merged into one screen (V5.1)

Day Theme and Time Block configuration used to be two separate entries under the More menu; they are **merged into a single screen** (Day Theme's blocks-per-day-of-week view already needs Time Block data side-by-side, so keeping them apart was pure friction). This single screen lives under **More**, positioned directly **below Shopping List** in the menu order. Everything else about Day Theme's and Time Block's own properties (name, blocks, days_of_week, color; time_ranges, order) is unchanged from V4 aside from the energy-scale fix below.

### TIME BLOCK / ENERGY MAP — numeric energy scale (fixes V4's undefined thresholds)

- `energy_level` is now a **numeric value, 0–10**, not a 3-bucket enum. This matches Field Note's `energy_value` scale exactly, so no bucket-conversion threshold is ever needed — Energy Map auto-generation now averages Field Note `energy_value` readings directly into a Time Block's `energy_level` with no lossy bucketing step.
- **Rendering:** the Planner's energy tint is computed continuously from the 0–10 value (not from 3 fixed bands): interpolate the tint color between low (`#FF7043`, at 0) → medium (`#FFC107`, at 5) → high (`#4CAF50`, at 10), always at 8% opacity. "↑ Best time" label still triggers above a configurable threshold (default: 7/10).
- Auto-generation from Field Notes: same flow as V4 ("See my pattern" → "Apply to my calendar"), just without any bucket conversion step, since both sides of the pipeline are now the same 0–10 scale.

### SNAPSHOT

Unchanged, except: `subject` can now reference **Project** in addition to Task, Goal, and Note — this was a real gap in V4 (Project's own menu offered "Take Snapshot" but Snapshot's spec never listed Project as a valid subject type).

### DASHBOARD PANEL — reset pending redesign (updated in V5.1)

V4 had multiple pairs of panels describing the same thing (a leftover from merging two prior spec versions); V5 deduplicated that list. **V5.1 retires the list entirely** — the product owner is redesigning the Dashboard Panel system from a blank slate because the deduplicated version was still "confusing and redundant" in practice. This document intentionally does **not** prescribe a panel list right now. What stays specified is the **mechanics**, since those are structural, not a content decision:

- A panel is always backed by a `DataSourceReference` (Part 1.4) or a direct reference to a specific object (e.g. a Pinned Note), never a bespoke per-panel data path.
- Panels are added/removed/reordered via drag on the Dashboard's edit mode; each panel's own configuration (which Tracker, which Habit, which filter) opens the same kind of lightweight config sheet regardless of panel type.
- **Today's Habits** is the one panel kept explicitly named in this document, since it's a load-bearing dependency for two other V5.1 features: negative habits are explicitly excluded from it (Part 2, Habit), and soft-recurring maintenance Tasks explicitly surface inside it (Part 2, Task).

The full panel-type catalog will be re-specified once the redesign is finalized — until then, treat any other panel type as **not yet decided**, not as removed-forever.

### MOOD DEFINITION

**V5.2 Overhaul:** complete 2-axis mood model (energy × pleasantness, 0–10 scale) replacing the old 1D numeric value; 80 proprietary mood catalog entries (20 per quadrant: Yellow, Red, Green, Blue); lazy file creation for system moods; one-time migration service for existing user moods.

**Properties:**
- `id`, `title` (label), `emoji`, `color` (hex), `order`
- `quadrant` — enum: `yellow | red | green | blue` (computed from energy/pleasantness: energy ≥5 & pleasantness ≥5 → yellow; energy ≥5 & pleasantness <5 → red; energy <5 & pleasantness ≥5 → green; energy <5 & pleasantness <5 → blue)
- `energy` — int 0–10 (activation/arousal dimension)
- `pleasantness` — int 0–10 (valence dimension)
- `description` — optional string (short human-readable description)
- `source` — enum: `system | user` (system moods are from the proprietary catalog)
- `aliases` — array of strings (alternative names for search/matching)
- `hidden` — bool (user can hide moods from picker)

**System Mood Catalog:**
- 80 proprietary mood entries, 20 per quadrant
- Each mood has predefined energy (0–10), pleasantness (0–10), emoji, label, and description
- System moods are created lazily on first use (file written to `moods/SLUG.md` only when selected)
- Users can edit coordinates (energy/pleasantness) of system moods via "Edit coordinates" unlock flow with confirmation dialog
- System moods display a "System" badge in settings

**User Moods:**
- Cap raised from 15 to 20 custom moods
- Created via mood settings screen with quadrant selection, energy/pleasantness sliders (0–10 scale), emoji, label, color, and optional description
- User moods can be deleted (system moods cannot)

**Migration:**
- One-time migration service converts existing user moods from old 1D numeric value (1–15 scale) to new 2-axis schema:
  - pleasantness = ((numeric_value - 1) / 14 * 10).round() — linear remap to 0–10
  - energy = 5 (neutral default)
  - description = '' (empty, non-blocking)
  - is_system = false
- Migration is non-destructive: old file is rewritten with new fields added, nothing deleted

**Mood Picker UI:**
- 2-step flow: quadrant selection (four big colored regions) → word grid with emoji + label + description
- Lazy file creation on selection
- Custom mood tile at end of grid for creating new user moods

**Daily Note Integration:**
- mood_entries array in daily note frontmatter reads pleasantness/energy directly from MoodDefinition at generation time
- mood:: [[slug]] syntax in journal entries references mood definitions

### WELLBEING INDICATOR *(new support object in V5.1, formalizing the existing `health_alerts_provider`/`health_alerts_strip` code area)*

**Purpose:** a composite, glanceable health signal built from one or more real data points the user already tracks — e.g. "am I doing okay?" combining sleep quality, hair loss, food variety, and bowel frequency into one status, without requiring the user to check four separate Trackers.

**Properties:**
- `id`, `title` (e.g. "Overall wellbeing"), `icon`
- `signals` — array of **Signal** configs, each:
  - `data_source` — one `DataSourceReference` (Part 1.4) — can point at a Tracker field, a Habit's completion record, a recurring Task's completion pattern, or a Project's `state`. This is deliberately the same unified mechanism used by KPI and Combined Analysis, so a Wellbeing signal, a KPI, and a chart series can all point at the exact same underlying data without redefining it three times.
  - `bands` — ordered thresholds mapping a resolved value (or absence of one) to a status: `healthy | watch | alert`. Bands can be numeric ranges (e.g. tracker `hours_slept`: `<5 → alert`, `5–7 → watch`, `7+ → healthy`) or pattern-based (e.g. a Habit's completion rate over the last 14 days, or "no data logged in N days" itself counting as `watch`/`alert` for signals where absence is itself informative — e.g. hair-loss tracking with no recent entry escalating to `watch` after 14 days, `alert` after 30).
  - `weight` — optional, used only if the indicator combines multiple signals into one composite score rather than showing them individually.
- `display_mode` — `individual` (show each signal's status separately) or `composite` (roll all signals into one overall status using `weight`).

**Surface:** a **Health Alerts** strip/component — visible wherever `health_alerts_strip.dart` already renders today (Dashboard, and optionally the Journal screen header) — showing any signal currently at `watch` or `alert`, with its icon, a one-line description of why, and a tap-through to the underlying Tracker/Habit/Task/Project. Signals at `healthy` don't clutter the strip; it only surfaces things that need attention, consistent with the rest of the app's "don't nag when everything's fine" pattern (e.g. the "days since" badge, Part 18).

---

## PART 4 — SCREENS & NAVIGATION

### Bottom Navigation Bar

Unchanged structure (5 default slots, Dashboard and More fixed, up to 7 total). **"Routines" removed from the list of assignable pages** — it's gone, folded into System. Current assignable pages: Journal, Planner, Trackers, Archive, Tasks, Projects, People, Goals, Resources, Habits, Systems, Organizers, Ideas, Inbox, Shopping Lists.

### The FAB (`+`) is the canonical creation entry point (new rule in V5)

**Every path that creates any object must open the exact same form the FAB opens for that type.** This includes: `⋯` menu "Save as [X]" actions, Command Center quick actions, Dashboard Panel "+" buttons, and any future entry point. There is exactly one implementation of "create a System" (etc.), parameterized by pre-fill context — never a second, divergent form. This guarantees that editing how a System (or any type) is created only ever requires editing one form.

FAB tabs, updated for V5.1's fixes: **Journal** (Entry / Field Note / PMN) | **Plan** (Task, Goal, Event, Reminder, Backlog item, **Habit** — was missing from the tab in V4/V5, corrected here) | **Record** (Tracking Record for a standalone Tracker, **or** log a completion/entry against an **existing Habit's linked tracker** — the picker lists both standalone Trackers and Habit-linked Trackers, clearly labeled) | **Note** (Text, Outline, Collection, System, Idea) | **Organize** (new tab, V5.1 — creates any Organizer type: Area, Project, Activity, Label, Person; this is also reachable as a dedicated "+ Add [Type]" button on the Organizer list screens, which must always navigate to this same canonical form rather than mutating state inline — see Part 22) | a fast **Inbox** capture action always pinned at the very top of the sheet (single tap, single text field, saves immediately) | **Shopping** (add item to an existing or new Shopping List).

### Universal Search Service (new rule in V5)

The three previously-separate "search the vault" implementations — the WikiLink picker (`[[`), the Command Center's search field, and the Universal Search Picker used by dependency/link pickers — **must call the same underlying search service.** Ranking, fuzzy matching, and result formatting are defined once and reused by all three surfaces. A change to how fuzzy title matching works updates all three simultaneously.

**Social results tab (new in V5.1):** the Universal Search Service exposes a dedicated **"Social"** results group/tab, default-sorted by most-recently-modified (matching how the rest of the picker already prioritizes recency), with two additional filters specific to that tab: **by platform** (Instagram/TikTok/Twitter/etc.) and **by `creator`** (Social Post's new `creator` field — Part 10). This makes it practical to find "that recipe video from @someone" instead of scrolling a mixed-type list.

### Command Center

Unchanged sections, with one addition: the **Systems** quick-run chip row and the general search now both go through the Universal Search Service above.

---

## PART 5 — INTERACTION PATTERNS

### Archive vs. Delete (contradiction fixed)

These are two distinct, non-overlapping flows:

- **Delete** → the file is **moved** to `_deleted/`. Snackbar "Undo" for 5 seconds. If not undone, the file stays in `_deleted/` and is **permanently erased** after 30 days (configurable). This is the only flow that ever moves a file to `_deleted/`.
- **Archive** → `archived: true` is set **in place**, in the object's existing frontmatter. **The file is never moved.** Snackbar "Undo" for 5 seconds (reverts `archived` to `false`). Archived objects stay archived **indefinitely** — there is no purge timer for Archive, ever. They remain visible (and restorable) forever on the Archive page (Part 14).

Every other rule from V4 (gestures, undo snackbar mechanics, etc.) is unchanged.

### Overdue Surfacing (new rule in V5.1)

Any Task or Reminder past its `end_date`/`date` without being completed (`overdue`, per Task's existing stage rendering) must surface in **both** of these places, not just its home list:
- **Journal Timeline** — an overdue item appears on *today's* Timeline (not buried on its original date), with a distinct "Overdue" chip.
- **Planner** — same treatment, shown on today regardless of its original scheduled day.

Both surfaces offer an inline **"Reschedule"** action (opens the date picker directly, same interaction as Task's own "Postpone," Part 2) so the user doesn't have to navigate away to deal with it.

---

## PART 6 — ACTIONS SYSTEM

Unchanged from V4 (7 action types, triggered by slot/day completion or tracking record save). Now also reused by KPI's `auto_complete` (Part 3) instead of KPI having its own separate action list.

---

## PART 7 — POMODORO

**New in V5: retroactive logging.** In addition to starting a live timer, the user can log a Pomodoro session after the fact via two shortcuts:

- **"I did N pomodoros"** — user picks a linked item, a start time, and a count. The app computes the implied duration from the linked item's/default work/break durations and creates a completed `PomodoroSession` plus an `Event` (with a `pomodoro` block, `state: completed`) at that time, visible on the Planner/Calendar exactly as if it had been run live.
- **"I worked N minutes"** — same flow, but a single free-form duration instead of a pomodoro-block count. Also creates a completed Event and logs the minutes to the linked Task's `timer_sessions`.

Both retroactive flows are reachable from: the linked Task's `⋯` menu ("Log Pomodoro time"), and the Pomodoro tab of the FAB's "Record" area.

`PomodoroSession` gains an `occurred_at` field (separate from `created_at`) so the Journal Timeline's created-vs-happened glyph (Part 2, Entry) can correctly show ⚡ for these, even when logged well after the fact.

**Popup mode — fully specified (was ambiguous in V4's Reminder Configuration `type: popup`, and is specific to the Pomodoro timer, not a generic reminder popup):** when the Pomodoro timer is running in "popup" display mode, it renders as a small floating countdown bubble (the running MM:SS, no other chrome) that overlays on top of any other app — an Android/iOS system-overlay bubble, not an in-app screen. The user can:
- **Drag it anywhere** on screen to reposition it; position persists until moved again.
- **Drag it down** (below a dismiss threshold near the bottom of the screen, with a visual "trash"/fade affordance appearing once dragged past ~60% of the way down) to **remove it from the screen** — this stops showing the bubble but does **not** stop the underlying timer; the persistent notification (Part 7, unchanged from V4) remains the fallback control surface once the bubble is dismissed.

Everything else about the Pomodoro object and the full-screen live-timer UI is unchanged from V4.

---

## PART 8 — PEOPLE

**Properties:** unchanged, except:

- `categories` is **removed from People.** (`categories` was ambiguously shared between People and Resource in V4; V5 makes `categories` a universal personal-organization field available on every object, per Part 1.3, and People simply doesn't have a special dedicated use for it beyond that — Resource is where `categories`/media-type gets its dedicated meaning, see Part 9.)
- **Automatic contact reminder now runs through Scheduler's new generic rule** (`days_after_reference_field`, targeting `last_contact_date` + `contact_frequency`), not a bespoke check.
- **Overdue handling (new, replaces V4's silent duplicate-Task risk):** if the auto-generated "Contact [Name]" Task isn't completed by its due date, it does **not** spawn a second Task. It simply becomes `overdue` (a Task's existing stage/overdue rendering already handles this) and stays open. Only when the user actually marks it done does the app: (1) set `last_contact_date` on the Person to the completion date, and (2) recompute the next scheduled contact Task from that new date. This guarantees exactly one open "contact" Task per Person at any time.

---

## PART 9 — RESOURCES

**Metadata source list (new in V5.1 — formalizes and extends what the app already partly does with Google Books):**

When a shared link or a resource URL is detected (via `ResourceMetadataService.isResourceUrl`), the app looks up metadata from the matching source, in this detection order: **Google Books → IMDb → Amazon → Goodreads → Open Library → unknown/manual**. IMDb is added in V5.1 specifically so movies/series shared from the IMDb app or website are recognized, not just books.

For every successful lookup, the app populates: `cover_image`, `title` (kept in its original language), a **`aliases` entry containing the pt-BR title** when the source provides a localized title or the user provides one manually, `author`/creator where applicable, and `sourceUrl` (persisted on `Resource.sourceUrl`, never stuffed into `tags`, per the existing rule in `agents.md`). If no source matches, `media_type` (see below) falls back to a general/manual entry rather than blocking the save.

**`type` renamed to `media_type` (resolves the field-name collision with the universal `type` used for object-kind identification):**

- `media_type` — the kind of media, e.g. `book | movie | series | podcast | article | course | ...`. **User-extensible** — the user can add new media types beyond the built-in set via Settings → Resources, same place the filter conditions (Part 9's "book/movie/series/podcast" tag-based detection rules) already live.
- All other Resource properties unchanged: `title`, `cover_image`, `status`, `categories` (now this is where `categories` gets its primary dedicated meaning — see Part 8), `rating`, `synopsis`, `links` (universal).
- `priority` — **added** (was used in the Resources view's sort options in V4 but never declared on the object). Resource gains an optional `priority` (`none | low | medium | high`), same enum as everywhere else.

---

## PART 10 — PROJECTS (Organizer, absorbs old Goal plan-mode)

**Properties (now includes what used to be Goal's `plan_mode`):**
- `title`, `description`, `state`, `priority`
- `start_date`, `due_date`
- `objective` — the why *(moved here from Goal)*
- `strategy` — the how *(moved here from Goal)*
- `phases` — array grouping Tasks by stage *(moved here from Goal)*
- `progress` (derived from `primary_kpi`), `primary_kpi`, `secondary_kpis`
- `tasks` — array of WikiLinks to child Tasks
- `scheduler` — recurrence, see "restart" behavior in Part 2 (creates a new file, doesn't reset in place)
- `total_pomodoro_time` (derived), `quick_access`
- **`organizers`** — Project's own place in the Area/Activity hierarchy (this was missing from V4's property list despite the hierarchy requiring it; now explicit: `organizers: ["[[area-work]]"]` or `["[[activity-x]]"]`)
- `superseded_by` — set on the old file when a scheduled restart creates a new one

Everything else (detail view layout, menu items including "Take Snapshot," calendar activity view) is unchanged from V4.

---

## PART 11 — COMBINED ANALYSIS

**Mood-per-day fix (the most important fix in this document — see below and Part 20):**

Combined Analysis's `journal_mood` data source no longer reads from single scalar frontmatter fields. It now reads from the daily note's derived `mood_entries` array (Part 20), which supports any number of mood registrations per day. The averaging, "most recent for calendar," and "all entries in tooltip" behaviors described in V4's UI spec (23.4) now have real underlying data to operate on:

- **Line chart:** averages all `mood_entries` for a day into one plotted point per day; each entry's emoji still renders as the point marker (if multiple entries exist for a day, the most recent entry's emoji is used as the marker, per V4's existing rule — now consistent with the data actually being available).
- **Calendar:** shows the most recent entry's emoji, exactly as V4 specified.
- **Tooltip:** lists every entry in `mood_entries` for that day — now genuinely possible, since the data exists.

DataSource series for mood use the unified `DataSourceReference` (Part 1.4) with `source_type: journal_mood` and `dimension: pleasantness | energy`.

**Missing-data rendering (new in V5.1):** a day with no recorded value for a given tracker field must **not** be plotted as `0`. The line chart shows a genuine gap — no point is drawn for that day, and the line itself breaks (does not draw a segment through the missing day) and resumes cleanly at the next day that has data. This applies per-series independently: one series can have a gap on a day while another series on the same chart has data and renders normally.

Everything else (dual-axis normalization, value_mapping for categorical tracker fields, calendar heatmap, insight card) is unchanged from V4.

---

## PART 12 — SYNC, OFFLINE, CONFLICTS & BACKUP

Sync architecture (Google Drive, offline queue, conflict resolution via `_conflicts/`) is unchanged from V4.

**Backup — clarified as a single file (fixes V4's ambiguity):**

- There is **exactly one** backup file at all times, at `_backups/vault-backup.zip` (or platform-equivalent single path).
- It is **overwritten in place** on every backup run — never accumulated as multiple dated ZIPs.
- Cadence is user-configurable: **Daily / Weekly / Every 15 days / Monthly**, plus a standalone **"Backup now"** button that runs an immediate backup regardless of the schedule (and resets the schedule's next-run timer from that moment).
- Settings → Backup shows: current cadence (editable), last backup timestamp, and the "Backup now" button.

---

## PART 13 — NOTIFICATIONS

**Reminder Configuration** is confirmed as the single universal schema (already `ReminderConfig` in code), used identically by every object's `reminders` array, including individual Habit slots (Part 2, Habit) and the standalone Reminder object (Part 2, Object 8) — there is no second parallel notification schema anywhere in the app.

**Platform pending-notification limits (new, addresses a real gap):** because Scheduler rules can generate recurring notifications indefinitely, the app must not attempt to register every future occurrence at once — iOS in particular caps pending local notifications well below what an "every day, forever" habit reminder would need. The app materializes and registers only a **rolling window of upcoming occurrences** (default: next 14 days) per scheduled object, and re-materializes the next window in the background as time passes, rather than scheduling every future occurrence at creation time.

**Escalation (new in V5.1):** each Reminder Configuration gains an optional `escalation` setting: when the same reminder is dismissed/ignored (not acted on, not snoozed intentionally) for **N consecutive occurrences** (user-configurable, default 3), the app automatically increases its intensity for the next occurrence — stepping through, in order: `push` → `popup` → `alarm`, plus a stronger vibration pattern and, optionally, a distinct color/sound the user picks when enabling escalation. This exists specifically to counter notification-blindness on recurring reminders the user has started tuning out. Escalation resets to the base intensity as soon as the user acts on (completes/opens) one occurrence.

Everything else (trigger types, per-type button behavior, reliability via the system alarm manager) is unchanged from V4.

---

## PART 14 — ARCHIVE

Unchanged from V4, now consistent with the fixed Delete/Archive split in Part 5: this page lists every object with `archived: true`, in place, forever — never purged, since only `_deleted/` has a purge timer.

---

## PART 15 — HOME SCREEN WIDGETS

**Terminology fix (resolves a real day-to-day confusion the product owner flagged):** this document, and the app's own internal naming, now reserves the word **"Home Screen Widget"** exclusively for the Android/iOS native home-screen/lock-screen feature described in this Part. Reusable pieces of the app's own UI (what V4 sometimes called "widgets") are now called **components** (see Part 22's new source-folder convention) and never referred to as "widgets" in conversation or documentation, specifically to prevent the confusion where an instruction to "edit the widget" could mean either the Dashboard component or the Android Home Screen Widget.

The 4 Home Screen Widget types (Quick-add, Calendar, Category, Obsidian Note) are unchanged from V4.

---

## PART 16 — UNIVERSAL LINKING

See Part 1.4 for the unified schema. UI mechanics (property link chips, inline `[[mention]]`, the `[[` picker, Mentions/Backlinks sections) are unchanged from V4, now running through the Universal Search Service (Part 4) wherever a picker is involved.

---

## PART 17 — NAVIGATION HISTORY

Unchanged from V4, with the Triple Check navigation-safety rule from Part 2 as a concrete, binding example of how the unlimited nav stack + exact-state-restoration rule applies to a multi-step flow that can branch into other screens mid-flow.

**Android hardware back button (explicit rule, new in V5.1):** the hardware/gesture back action **always** pops the in-app navigation stack one level at a time, exactly like the in-app "‹" back arrow (same exact-state-restoration guarantee) — it **never** exits the app while there is any screen above Home in the stack. Only pressing back while already on the Home/Dashboard root screen is allowed to exit the app (standard Android system behavior at that point). This closes a real gap: without this rule stated explicitly, it's easy for a screen to be wired to the system back button in a way that closes the whole app instead of navigating up.

---

## PART 18 — VISUAL DESIGN

**Units:** every size/spacing value in this document is `dp` (Flutter's logical pixel — identical value on iOS and Android; there is no platform-specific conversion needed, unlike the old `pt`/`dp` split in V4's Part 19, which has been removed).

**Status badges never rely on color alone (fixes an accessibility gap across 4+ badge types):**
- Project state badge: `active` (green + ▶ icon), `paused` (amber + ⏸ icon), `completed` (gray + ✓ icon), `archived` (gray + 🗄 icon)
- "Days since" badge on Habits: pairs its existing color with the numeral itself as the primary signal (e.g. "5" is inherently readable without color; the pill's color is a secondary reinforcement, never the only channel) — additionally, `0`/"today" state uses a ✓ icon, not just a neutral color
- Person urgency badge (Part 8): green/amber/red pill now also carries a short word (`On track` / `Due soon` / `Overdue`) inside the pill, not color alone
- Energy Map tint (Part 3): purely a background wash, never the sole carrier of information — the numeric 0–10 value is always visible on tap/hover in the Time Block editor

**"Incomplete" badge (new, Part 1.4):** outline style, muted gray border, "!" icon, label "Incomplete" — never color-coded (no red), since it's a neutral state, not an error.

Everything else in V4's Part 18 (type colors, color picker rules) is unchanged.

---

## PART 19 — UI FUNDAMENTALS

**No-overflow principle (new in V5.1):** no text, button, card, or input may overflow its container at any supported screen size. This is a binding design principle, not a per-screen bug list — every text element uses adaptive sizing (ellipsis/truncation with a way to see the full value, e.g. tap-to-expand or a tooltip, rather than clipping silently), every row/card uses flexible width constraints instead of fixed pixel widths, and long unbroken strings (URLs, long titles) wrap or truncate rather than forcing horizontal scroll. Any screen found overflowing (e.g. the Pomodoro screen, the Planner's date header while scrolling the timeline — both flagged as real, current instances) should be treated as violating this principle, not as an isolated cosmetic bug.

Unchanged from V4 in substance — every `pt` value in the original document should be read as `dp`. The old platform-specific top/bottom-inset distinction (iOS 44dp vs Android ~24–28dp status bar) still applies as a genuine platform difference (that one *is* real — status bar height differs by OS), but is now expressed using `dp` consistently rather than mixing `pt` and `dp` terminology.

---

## PART 19.5 — DAY DIAL WIDGET (new in V5.3)

**Purpose:** Circular visualization of daily activity distribution, showing hour-by-hour state across a 24-hour dial.

**Data Model:**
- `DayDialHourState` — represents the state of a single hour (0-23):
  - `hour` — hour index (0-23)
  - `kind` — `DialHourKind` enum: `idle`, `sleep`, `pomodoroCompleted`, `pomodoroPlanned`, `event`
  - `fillFraction` — 0.0-1.0, how much of this hour is covered by activity
  - `habitIconName` — optional, set if a habit is scheduled at this hour
  - `habitId` — optional, reference to the habit
  - `reminderIconName` — optional, set if a reminder is scheduled at this hour
  - `reminderId` — optional, reference to the reminder

**Service:**
- `DayDialAggregatorService` — computes hour states from vault objects:
  - Aggregates completed Pomodoro sessions
  - Includes planned Pomodoro Events
  - Includes scheduled Events
  - Includes Habit slots with times
  - Includes Reminders with times
  - Respects sleep schedule (if configured)

**Widget:**
- `DayDialWidget` — renders the circular dial:
  - Configurable size (small/medium/large)
  - Theme integration (uses AppColors)
  - Interactive tap on hours to show details
  - Legend for color coding
  - Current time indicator
  - Optional summary stats (total productive hours, etc.)

**Use Cases:**
- Dashboard panel showing daily activity distribution
- Planner day view integration
- Statistics screen daily breakdown
- Home screen widget (Android/iOS)
- Windows companion app (see PART 19.11)

---

## PART 19.11 — WEEK TIME GRID (new in V5.3)

**Purpose:** Weekly calendar grid view showing Tasks and Habits across 7 days with time-based layout.

**Widget:** `WeekTimeGrid`
- Displays 7-day week starting from `startOfWeek`
- Shows day names (Mon-Sun) and dates in header
- Highlights current day with primary color
- Time column on the left (hourly slots)
- Grid cells show:
  - Tasks with scheduled times
  - Habits with scheduled slots
  - Color-coded by type/priority
- Interactive tap on items:
  - `onTaskTap` — callback for Task selection
  - `onHabitTap` — callback for Habit selection
- Navigates to `UniversalDetailView` on tap

**Data:**
- `tasks` — List of Tasks to display
- `habits` — List of Habits to display
- `startOfWeek` — DateTime for Monday of the week

**Styling:**
- Uses `AppTheme.surfaceVariantColor` for background
- 16dp border radius
- Primary color for today's date
- Responsive layout with expanded columns

**Use Cases:**
- Planner week view
- Statistics weekly breakdown
- Project timeline visualization
- Habit weekly schedule overview

---

## PART 19.12 — WINDOWS DIAL COMPANION APP (new in V5.3)

**Purpose:** Standalone Windows desktop application displaying DayDialWidget with real-time updates.

**Entry Point:** `windows_dial_main.dart`
- Initializes Flutter app with Riverpod
- Loads vault data on startup
- Sets up ProviderContainer with vault and settings providers

**App Structure:**
- `WindowsDialApp` — MaterialApp with Quartzo theme
- `WindowsDialHome` — main screen with DayDialWidget
- Auto-refresh timer — updates every minute to show current time
- Date selector — user can change selected date

**Features:**
- Real-time current time indicator
- Date navigation (previous/next day)
- Vault integration (loads Tasks, Habits, Pomodoro sessions)
- Google Calendar integration (via googleapis package)
- Pomodoro provider integration
- Settings provider integration

**UI Components:**
- `DayDialWidget` — circular dial visualization
- Date picker for selecting different days
- Refresh timer (1-minute interval)
- Theme integration with AppColors

**Use Cases:**
- Desktop companion for productivity tracking
- Always-on daily activity monitor
- Secondary screen dashboard
- Windows-specific widget implementation

---

## PART 19.6 — ALIGNMENT TRACKING (new in V5.3)

**Purpose:** Track how closely actual execution matches planned timing for Tasks and Habits.

**Data Model:**
- `AlignmentLogEntry` — records a single alignment measurement:
  - `itemId` — ID of the Task or Habit
  - `date` — date of completion (yyyy-mm-dd)
  - `plannedTime` — scheduled time (HH:mm)
  - `actualTime` — actual completion time (HH:mm)
  - `deltaMinutes` — signed difference (actual - planned)
  - `state` — `AlignmentState` enum: `early`, `aligned`, `drifting`, `missed`

**Alignment States:**
- `early` — completed before planned time, within 3× flexibility window
- `aligned` — completed within flexibility window (default ±15 minutes)
- `drifting` — completed after planned time, within 3× flexibility window
- `missed` — completed outside 3× flexibility window

**Service:**
- `AlignmentService` — logs and computes alignment:
  - `logTaskAlignment()` — logs alignment when a Task is completed
  - `logHabitAlignment()` — logs alignment when a Habit slot is completed
  - `calculateState()` — computes state from delta and flexibility window

**Storage:**
- Alignment entries stored in daily notes as ```alignment``` code blocks
- Format: key-value pairs in markdown code block
- Parsed back into AlignmentLogEntry objects on load

**UI:**
- `AlignmentInsightsPanel` — shows alignment statistics:
  - Overall alignment rate (percentage of "aligned" entries)
  - Distribution by state (early/aligned/drifting/missed)
  - Average delta minutes
  - Trend over time (chart)
  - Per-item breakdown

**Integration:**
- Task: `flexibilityWindowMinutes` field (null = off)
- HabitSlot: inherits from parent Habit's `flexibilityWindowMinutes`
- Both require `scheduledTime` to be alignment-trackable

---

## PART 19.7 — OVERDUE DETAIL SCREEN (new in V5.3)

**Purpose:** Dedicated screen for viewing and managing overdue Tasks, Habits, and Goals.

**Screen:** `OverdueDetailScreen`
- Shows all overdue items grouped by type (Tasks, Habits, Goals)
- Each item shows:
  - Title and type icon
  - Due date (how many days overdue)
  - Priority badge
  - Quick actions: "Reschedule", "Mark complete", "Snooze"
- Empty state: "No overdue items" with checkmark icon
- Integrated with `OverdueProvider` for reactive state updates

**Provider:** `OverdueProvider`
- Computes overdue items from vault
- Filters by due date < today
- Groups by object type
- Reactive to vault changes

**Navigation:**
- Accessible from:
  - More menu → "Overdue"
  - Dashboard overdue panel (if configured)
  - Notification tap on overdue reminder

**Actions:**
- "Reschedule" — opens date picker to set new due date
- "Mark complete" — marks item as completed
- "Snooze" — defers reminder by configurable duration (default 1 day)

---

## PART 19.8 — OCR SERVICE (new in V5.3)

**Purpose:** Extract text from images using Google ML Kit.

**Service:** `OcrService`
- `extractText(File imageFile)` — extracts text from image
- Returns `OcrResult`:
  - `text` — extracted text string
  - `hasText` — boolean, true if text found
  - `blockCount` — number of text blocks detected
- Uses `TextRecognizer` with Latin script
- `dispose()` — cleans up recognizer resources

**Integration:**
- Scan document flow — OCR on captured photos
- Photo attachments — optional OCR on upload
- Resource covers — OCR for book/movie text extraction
- Social Post images — OCR for text content extraction

**UI:**
- `OcrTextSection` — displays OCR results:
  - Editable text field with extracted content
  - "Retry OCR" button
  - Confidence indicator (if available)
  - Copy to clipboard action

---

## PART 19.9 — COLLECTION ROW SERVICE (new in V5.3)

**Purpose:** Parse Collection Note body into structured rows for Obsidian Bases integration.

**Data Model:**
- `CollectionRow` — represents a single table row:
  - `noteSlug` — parent Collection Note slug
  - `blockId` — optional Obsidian block reference
  - `lineIndex` — line number in the note body
  - `rawText` — raw line text
  - `displayTitle` — parsed title (emoji stripped)
  - `subtitle` — optional parsed subtitle (after pipe delimiter)

**Service:** `CollectionRowService`
- `parseRows(Note note)` — parses note body into rows
- Supports emoji stripping (leading emoji removed from title)
- Supports pipe (::) delimiter for subtitle
- Supports block references (^block-id)
- Skips empty lines and headers (lines starting with #)

**Helper:** `slugify(String value)`
- Converts display title to kebab-case slug
- Removes accents (é → e, ç → c, etc.)
- Replaces spaces with hyphens
- Removes non-alphanumeric characters (except hyphens)

**Integration:**
- Collection Notes using Obsidian Bases plugin
- Each row represents a real Obsidian note file
- "Add row" creates new note in Collection's folder
- Row edits update the underlying note file

---

## PART 19.10 — AUTOMATION SERVICE ENHANCEMENTS (new in V5.3)

**Enhanced Service:** `AutomationService`
- Expanded action types:
  - `add_entry` — creates Journal Entry
  - `create_task` — creates Task
  - `create_note` — creates Note
  - `update_kpi` — updates KPI value
  - `send_notification` — sends push/popup notification
  - `open_url` — opens URL in browser
  - `custom_script` — executes custom script (future)

**Execution Triggers:**
- Habit slot completion (`slot_complete`)
- Habit day completion (`day_complete`)
- Tracker record save (`tracking_record_saved`)

**HabitSlot Actions (new):**
- Per-slot `actions` field in addition to habit-level actions
- Executes when individual slot is completed
- Supports slot-specific automation (e.g., different actions for morning vs evening slots)

**Service Methods:**
- `executeHabitSlotActions()` — executes slot-level actions
- `executeHabitActions()` — executes habit-level day actions
- `executeTrackerActions()` — executes tracker record actions
- `_executeActionDef()` — core action execution logic

---

## PART 20 — VAULT SCHEMA: COMPLETE

### Folder Structure

```
vault/
├── app/                    ← All content objects (flat, type in frontmatter)
├── daily/                  ← Daily notes + PMN
├── analyses/               ← Combined Analysis definitions
├── moods/                  ← Mood definition files (created lazily)
├── _attachments/
├── _deleted/                ← purged after 30 days
├── _conflicts/               ← purged after 30 days
└── _backups/                 ← single rolling backup file, never purged, always overwritten
```

*(No `places/`. No map-related folder ever existed and none is added.)*

### Universal Frontmatter

```yaml
---
id: "unique-id"
type: task  # See the complete type enum below
title: "Title"
icon: "✅"          # optional per-object override of the type default (Part 1.5)
categories: []      # personal organization, can contain plain strings or [[links]]
tags: []
aliases: []
created_at: 2026-05-19T09:00:00
updated_at: 2026-05-19T14:00:00
archived: false
is_incomplete: false   # derived — true while any required property is missing (Part 1.4)
organizers: []
links: []
reminders: []
# TYPE-SPECIFIC PROPERTIES FOLLOW
---
```

**Complete `type` enum (V4's version was missing several values already used elsewhere in the same document — this is now exhaustive):**

```
task | habit | tracker | goal | note | entry | event | reminder | system | social_post
| mood_definition | area | project | activity | label | person | idea | inbox
| shopping_list | template | daily_note | analysis
```

*(`calendar_session` removed — folded into `event`. `place` removed entirely.)*

**On changing an object's type at runtime:** the product owner can reclassify any object's `type` at any time (e.g., turn a Note into a Task) via the object's `⋯` menu → "Change type…" This rewrites the frontmatter's `type` field and strips any properties that don't apply to the new type (with a confirmation showing exactly what will be dropped), while preserving `title`, `categories`, `tags`, `links`, `organizers`, and `created_at`. This is distinct from Object Identification's *automatic* conflict detection (Part 1.1) — this is a deliberate, user-initiated reclassification.

### Daily Note Format — mood-per-day fix

```yaml
---
date: 2026-05-19
type: daily_note
tags: [daily]

# Habit completions — this block is a derived rendering (Rule 14)
> **Implementation note (added 2026-07-12):** the authoritative in-memory
> source of truth for habit completions is `Habit.completionHistory`
> (`List<CompletionRecord>` on the `Habit` model), not the daily note's
> YAML frontmatter block shown above. The frontmatter block below is a
> *derived, generated rendering* of `completionHistory` for that date —
> written on save, never parsed back — following the same
> single-source-of-truth pattern already established for Tracking Records
> in this document. Any future feature (e.g. the Aromatherapy addendum's
> `linkedRef` field) should read/write `CompletionRecord` directly and
> treat the frontmatter block as output only.
meditate: true
write-100-words: true
water: 6

# Mood — now a derived ARRAY, not scalar fields. Populated automatically
# whenever a Journal Entry with mood:: is saved on this date. Never
# hand-edited; regenerated whenever an Entry with a mood is added/edited/removed.
mood_entries:
  - time: "08:30"
    pleasantness: 4
    energy: 3
    label: "Calm"
    emoji: "😌"
  - time: "14:10"
    pleasantness: 2
    energy: 4
    label: "Stressed"
    emoji: "😖"

# Tracker records (nested under the tracker's slug)
sleep:
  hours: 7.5
  quality: good
---
```

**Body of the daily note is entirely generated** (Rule 14) — `## Journal Entries`, `## Habits`, `## Trackers`, `## Pomodoros` are all rendered from the frontmatter above and regenerated on every save. They are never parsed back as data by the app.

### Mapping Object → Obsidian File (complete)

| Object | Location | Type | Backlinks? |
|---|---|---|---|
| Journal Entry (standard/field_note) | `daily/YYYY-MM-DD.md` → `## Journal Entries` | `entry_type` | Via `mood::`, `organizers::` |
| PMN | `daily/YYYY-MM-WNN.md` | `entry_type: pmn` | Via `pact_refs`, `referenced_dates` |
| Task | `app/*.md` | `task` | Yes |
| Goal | `app/*.md` | `goal` | Yes |
| Project | `app/*.md` | `project` | Yes |
| Habit | `app/*.md` | `habit` | Yes |
| Tracker | `app/*.md` | `tracker` | Yes |
| Tracking Record | Embedded in `daily/YYYY-MM-DD.md` | frontmatter + `## Trackers` | Via daily note |
| Note | `app/*.md` | `note` | Yes |
| Event | `app/*.md` | `event` | Yes |
| Reminder | `app/*.md` or embedded in daily note | `reminder` | Yes / via daily note |
| System | `app/*.md` | `system` | Yes |
| Social Post | `app/*.md` | `social_post` | Yes |
| Idea | `app/*.md` | `idea` | Yes |
| Inbox Item | `app/*.md` | `inbox` | Yes |
| Shopping List | `app/*.md` | `shopping_list` | Yes |
| Template | `app/*.md` | `template` | No (not linkable content) |
| Mood Definition | `moods/SLUG.md`, lazy | `mood_definition` | Yes |
| Area / Activity / Label / Person | `app/*.md` | `area`/`activity`/`label`/`person` | Yes |
| Combined Analysis | `analyses/SLUG.md` | `analysis` | Yes |
| PomodoroSession | Embedded in daily note | via `## Pomodoros` | Via daily note |

*(No Place row — removed entirely.)*

### Parsing Algorithm — updated

Unchanged from V4's startup/sync algorithm, with these amendments:
1. Never infer type from folder or filename prefix (Rule 8) — only ever read `type` from frontmatter.
2. Mood parsing per daily note now reads the `mood_entries` array, not scalar fields.
3. Body sections (`## Habits`, `## Trackers`, `## Journal Entries` for standard/field_note, `## Pomodoros`) are write-only from the app's perspective — generated on save, not re-parsed on load except to detect that a user manually edited something in Obsidian outside the app (which triggers a conflict-review flow, same as any other external edit, rather than being silently trusted as new data).

---

## PART 21 — OBJECT IDENTIFICATION (user-configured overrides only)

Settings → Object Identification.

**The app ships with zero default type-to-folder mappings.** Every object saves to the same flat default folder (`app/`) regardless of type, unless the user explicitly configures an override here.

**Marker types (unchanged — Folder, Tag, Property remain all three options):**
- **Folder** — e.g., "files in `tasks/` are type: task" — this is now purely an opt-in user choice, never an app default.
- **Tag** — e.g., "files with `#habit` are type: habit"
- **Property** — e.g., "files with `type: project` are type: project"

**Conflict resolution (reconciled in V5):** when an object's attributes point to two different type markers, the configured **priority order** (drag-to-reorder in this settings page) automatically determines which type wins — the app is never stuck not knowing what an object is. The ⚠️ conflict badge **still appears** everywhere the object is shown, and it still appears on the Conflicts page, specifically so the underlying inconsistency doesn't go unnoticed just because the app resolved it automatically. Opening the Conflicts page explains: "This object is in the tasks folder but has property category: area — treated as area by your priority order."

**This includes content-object-vs-organizer collisions, not just organizer-vs-organizer ones (clarified in V5.1)** — e.g. a file whose properties qualify it as both a Note and an Area is resolved by the exact same priority-order mechanism and shown on the same Conflicts page; there is no separate conflict system for "content vs. structural" collisions.

**Conflict-resolution buttons must state the exact consequence (new in V5.1):** the Conflicts page never shows a generic "Resolve" button. Each conflict shows one button per viable resolution, each labeled with its actual outcome — for example: **"Convert to Note"**, **"Convert to Task"**, **"Move to `tasks/`"** — so the user always knows precisely what will change before tapping. Tapping applies that specific change immediately (with the existing Undo affordance, Part 5) rather than opening yet another menu.

Compatibility with the Obsidian Tasks plugin syntax (`- [ ] Title [due:: 2024-12-31] [priority:: high]`) is unchanged from V4.

---

## PART 22 — NOTES ON IMPLEMENTATION

1. Always read `habit_mode` before rendering a Habit; absent → `habit`.
2. Always read `entry_type` before rendering a journal section; absent → `standard`.
3. Goal no longer has `goal_mode` — that branch of logic should be deleted, not defaulted.
4. Never display `id` fields to the user.
5. Color picker is always a visual selector, never a raw HEX input.
6. PMN lives in its own file, indexed by `referenced_dates` (which must cover every date in the range inclusive — see the corrected canonical example in Part 2).
7. Mood is stored as `mood::` WikiLinks on individual Entries, **and** as the derived `mood_entries` array on the daily note (Part 20) — the array is always regenerated from the Entries, never the other way around.
8. System moods are created lazily on first use; user moods are created immediately.
9. Mood aliases participate in WikiLink resolution.
10. Object Identification overrides are opt-in; there is no default folder-per-type behavior anywhere in the app (Rule 8, Rule 12).
11. The Actions system (7 types) is shared by Habits, Trackers, and now KPI's `auto_complete`.
12. Triple Check writes into the Task's own frontmatter — it never creates a separate file.
13. `System.run_count`/`last_run`/`average_minutes` are always derived from linked Tasks, never written directly.
14. Steering Sheet: only Pause and Pivot append to `previous_cycles`; Persist does not.
15. PMN's creation form can batch-trigger Triple Check for tasks stalled 7+ days.
16. Combined Analysis reads mood from `mood_entries`, never from scalar frontmatter fields.
17. **Required properties never block a save (Rule 13)** — implement saves as always-succeed-and-warn, never as validate-then-block.
18. **The daily note body is always regenerated, never re-parsed as a data source** (Rule 14) for habits, trackers, Pomodoros, and shopping-list checklists.
19. **Source-folder convention (new):** `lib/ui/screens/` = routable, full-page screens only. `lib/ui/widgets/` = reusable pieces with no own route — this is the only "reusable piece" category; `lib/ui/components/` should not exist as a separate folder going forward (existing files there should be merged into `widgets/`, deduplicating any file that currently exists under both `components/` and `widgets/` with the same name — e.g. the real `outline_editor.dart` and `universal_detail_view.dart` duplicates found in the repo should be resolved by picking the more complete/current implementation and deleting the other). Never use the word "widget" to refer to these in conversation — reserve "widget" exclusively for the Home Screen Widget feature (Part 15); call these **components**.
20. **`ShoppingItem` duplicate-class bug:** delete the standalone `shopping_item.dart` model; the canonical `ShoppingItem` is the embedded value class in `shopping_list_model.dart`.
21. Every FAB-adjacent creation path (menu actions, quick-run, "save as") must call the same creation form as the FAB itself (Part 4) — never a second, parallel form implementation for the same object type.
22. The WikiLink picker, Command Center search, and Universal Search Picker must call one shared search service (Part 4).
23. **Every "Add [X]" button anywhere in the app** (not just the FAB) must navigate to that type's canonical creation form (Part 4) rather than mutating state inline — this is what fixes the real bug where an Organizer screen's "add" button wasn't reflecting updates from its own form: an inline mutation with local state is what caused the desync, and navigating to the canonical form (which owns the single source of truth) is what removes the possibility of desync entirely.
24. **Collection Note rows are real files** (Part 2, Object 6) — "add a row" must go through the same object-creation path as any other object, scoped to the Collection's folder, never an in-memory array push.
25. **Habit slot reminders, Reminder (standalone), Task reminders, and any future per-object reminder all read the same escalation logic** (Part 13) — escalation state lives on the Reminder Configuration itself, not duplicated per object type.

---

## PART 23 — DETAILED UI/UX

*(Sections 23.1 Mood Picker, 23.2 Mood Creation Form, 23.3 Mood Management, 23.6 Steering Sheet, 23.9 Command Center, 23.10 FAB, and 23.11 Pomodoro Timer are structurally unchanged from V4 — apply the Part 18 dp/unit correction, the Part 6 English-only correction, and, for 23.10, the new Idea/Inbox-capture FAB entries from Part 4. They are not reproduced in full here to avoid duplicating unchanged text; treat V4's prose for those sections as still authoritative except where a fix above specifically calls out a change.)*

### 23.4 COMBINED ANALYSIS — updated for mood_entries

Unchanged visually from V4. The only functional change: every "average of the day," "most recent entry," and "tooltip lists all registrations" behavior now has real backing data via `mood_entries` (Part 11), instead of being specified over fields that couldn't hold multiple values.

### 23.5 TRIPLE CHECK — updated bottom sheet

Visual layout (header, three questions, diagnosis area) is unchanged from V4. What's new:

- **Diagnosis area is now driven by the rule table in Part 2**, not free-floating example text — the app should look up the exact button set from that table rather than improvising per combination.
- **"Postpone" now opens both**: a row of quick-postpone chips (+1 day / +1 week / +1 month) as the default view, with a "Pick a specific date…" text link beneath them that opens the full date picker. Either path returns to the Triple Check sheet with the new date already applied.
- **"Add dependency" now opens the Universal Search Picker with a pinned "Create new task" row always visible above search results** — so the user never has to guess whether they can create vs. only select existing tasks.
- **Navigation-safety guarantee**: leaving the Triple Check sheet to complete a nested flow (postpone's date picker, add-dependency's task creation, "Check schedule"'s Planner view) and pressing back always returns to Triple Check in its exact prior state — answered questions preserved, or already-saved result shown read-only if it had been saved. This is enforced by auto-persisting Triple Check's in-progress state (not just the final diagnosis) the moment the user navigates away from the sheet.
- Batch mode (via PMN) unchanged from V4.

### 23.7 SYSTEM — Detail View & Execution

Unchanged from V4, with the Part 4 rule applied: "Executing" a System still has its 3 ways (A/B/C), but **creating/editing a System's definition** always goes through the one canonical FAB-driven form.

### 23.8 ORGANIZER DETAIL VIEW — Timeline Section now covers every linkable type

V4's Timeline Section only knew how to render Task, Entry, Field Note, Tracking Record, Habit record, Calendar Session, and Pomodoro — silently dropping Goal, Reminder, System, and Social Post even though all of them carry `organizers`. **V5 completes the type coverage:**

- **Goal:** chip "Goal" (purple, 15%) + title + status badge + progress bar (compact, inline) + target date if set (trailing, muted)
- **Reminder:** chip "Reminder" (gray) + 🔔 + title + trigger time (trailing, muted)
- **System:** chip "System" (orange, 15%) + ⚙️ + title + "N runs" (trailing, muted) — tapping navigates to the System detail view, not an inline expand
- **Social Post:** chip colored by platform + title/caption preview (1 line) + `saved_at` (trailing, muted)
- **Event** (replaces "Calendar Session" row): chip colored by the Event's own color + title + date/time + duration (trailing) — a small ⏱ badge appears additionally when the Event carries a `pomodoro` block

Every Timeline item, regardless of type, also now carries the **created-vs-happened glyph** from Part 2 (🕐 or ⚡), consistent with the Journal screen's Timeline.

**General classification algorithm (new in V5.1 — replaces the manually-maintained list above as the actual governing rule going forward):**

The per-type list above documents *how each type currently renders*, but every time a new object type gets added to the app, that list would otherwise need a manual update — which is exactly how Goal/Reminder/System/Social Post got silently dropped from V4 in the first place. V5.1 fixes this structurally: whenever an Organizer's detail view resolves the objects linked to it (via `organizers` pointing back at it), it dispatches each one into exactly one of the three sections using a **general rule**, not a hardcoded per-type switch:

1. **Is the linked object itself an Organizer type** (Area, Project, Activity, Label, Person, or the Organizer role of Task/Goal/Habit/Tracker when specifically being referenced as a parent/child structural relationship)? → renders in **Children / Sub-organizers**.
2. **Else, does the object have no inherent timestamp/occurrence semantics** (i.e., it's reference material, not something that happens or is due) — this covers Note (all sub-types), Idea, Template? → renders in **Items**.
3. **Else** (everything else — Task, Entry, Habit record, Tracking Record, Event, Reminder, System, Social Post, Goal, and any future content-object type not yet invented) → renders in **Timeline**, ordered chronologically by its own most relevant date field (`date`, `end_date`, `created_at`, or `occurred_at`, in that preference order, whichever the type defines).

A new object type therefore only needs to declare **which of these three buckets it belongs to** (a single flag on its type definition, not a bespoke rendering block) to automatically show up correctly in every Organizer's detail view — closing the gap that let four real types go unrendered in V4.

### 23.9–23.11

Unchanged from V4 in structure — apply the FAB tab additions (Part 4), the dp unit correction (Part 18/19), and the English-only correction (this document's header) throughout.

---

## END OF DOCUMENT

Every item raised across the five audit rounds and the clarification pass has been addressed above, either as a direct fix, a formalized rule, or — for the 5 previously-undocumented object types plus Area/Activity/Label — a full specification pulled from the real implementation. Nothing was left as "TBD" except where explicitly noted as a deliberate open choice (there are none remaining as of this version).
