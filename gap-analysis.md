# Home Dashboard — Component System Specification v1
**pedido** na tela home, quero fazer tipo um dashboard, com vários componentes (nao quero chamar de widgets pq a ia sempre confunde com os widgets nativos do android). exemplo: um componente com uma timeline: tudo que foi criado no dia de hj, e tudo q está programado pro dia de hj, em ordem cronologica. outro componente com o dial view. outro com quick add de compras de mercado. outro com uma visualizacão rápida da semana. outro com uma visualização rapida do mes. outro com uma visualização rapida dos meus goals e projetos, mostrando porcentagem. outro com os completáveis de hj, numa visualização rapida (talvez usar emojis pra facilitar mostrar prioridade e se é tarefa, evento, habito, pomodoro, etc) e checkbox e play de pomodoro. no topo dessa tela, tbm tem q ter um iconezinho mostrando o status do sync no drive, e um + pra adicionar/editar esses componentes. pq nem todos vao estar sendo visualizados ao msm tempo mockups de exemplo em anexo no chat. leia guidelines e agents.md, atualizando/modificando esses arquivos se necessario

## 3. Architecture decisions

1. **Keep `DashboardBlock`/`BlockType`, extend it.** It already matches the "mechanics, not content" model `guidelines.md` PART 3 asked for (a panel is generic: id/type/title/visible/order/metadata). No new top-level model needed — just new `BlockType` values and a config schema per type living in `metadata`.
2. **Delete `dashboard_panel.dart` outright.** It's dead, deprecated, unreferenced, and its name collides confusingly with the "Dashboard Panel" heading in `guidelines.md` itself. One less parallel concept for future-you (or future-AI) to trip over.
3. **One new aggregator service, not eight.** The Timeline component (§5.1) and Today's Completables component (§5.7) both need "everything relevant to today across every object type" — building two separate aggregators would immediately duplicate the exact kind of per-type filtering logic your standing rules tell me to avoid. Both consume one new `TodayAggregatorService` (§5.0), each requesting a different projection of the same underlying list. This also means a bug fixed once (e.g. a timezone edge case) fixes both components at once.
4. **Reuse the existing Day Dial spec, don't refork it.** `guidelines.md` PART 19.5 already fully specifies `DayDialAggregatorService`/`DayDialWidget` as a dashboard-panel use case ("Dashboard panel showing daily activity distribution" is explicitly listed). Your Day Dial redesign work (concentric rings, drag-to-reposition) is a separate, already-in-progress spec — this document's Day Dial component (§5.2) is a **thin embedding wrapper** around whatever that work produces, sized for a dashboard card rather than a full screen. I am not redesigning the dial itself here; that's your other in-flight spec's job.
5. **Every component is backed by either a `DataSourceReference` (PART 1.4) or a fully-specified aggregator service — never a bespoke per-component data path**, per the exact mechanics the retired PART 3 section already mandated.
6. **Config sheets reuse `StandardSheet`, `FormSection`, `AppDropdown`, `AppSwitchTile`, `OrganizerSelectorField`** per PART 19.2/`agents.md` §6.8 — no new bottom-sheet chrome invented.
7. **The `+`/edit affordance and the sync icon are Home-screen chrome, not components** — they don't get `BlockType` values, aren't reorderable, aren't removable. They're structurally part of the AppBar (§4), always present regardless of which components are visible.

---

## 4. Top bar (Home screen `AppBar`)

Replaces the current bare `AppBar(title: Text('Home'), actions: [+])`.

### 4.1 Sync status icon (leading side of actions, before the `+`)

```dart
Consumer(
  builder: (context, ref, _) {
    final status = ref.watch(syncStatusProvider);
    final (icon, color, tooltip) = switch (status) {
      SyncStatus.synced   => (Icons.cloud_done_rounded,   AppColors.success, 'Synced'),
      SyncStatus.syncing  => (Icons.cloud_sync_rounded,   AppTheme.accentColor(context), 'Syncing…'),
      SyncStatus.offline  => (Icons.cloud_off_rounded,    AppColors.textMuted, 'Offline — will sync when back online'),
      SyncStatus.error    => (Icons.cloud_off_rounded,    AppColors.destructive, 'Sync error — tap for details'),
      SyncStatus.conflict => (Icons.warning_amber_rounded, AppColors.warning, 'Sync conflict — tap to resolve'),
    };
    return IconButton(
      icon: status == SyncStatus.syncing
          ? const SizedBox(
              width: AppIconSize.md, height: AppIconSize.md,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: status == SyncStatus.conflict || status == SyncStatus.error
          ? () => context.push('/sync-conflicts')
          : null, // synced/syncing/offline: informational only, no tap target
    );
  },
)
```

- Purely additive — `ref.watch(syncStatusProvider)` is already correct and live; no provider changes needed (§2.4).
- `conflict`/`error` states are the only tappable ones, routing to the existing `sync_conflicts_screen.dart`.
- Icon animates via the existing `CircularProgressIndicator` idiom already used elsewhere in the app (`_QuickCaptureCard`'s submitting spinner) — no new spinner pattern introduced.

### 4.2 `+` — Add/Edit Components button

Distinct from the FAB (which remains the canonical **object-creation** entry point per PART 4 — Task/Habit/Event/etc.). This `+` is scoped **only** to the dashboard's own composition: which components are visible, in what order, with what per-component config. Tapping it enters **Dashboard Edit Mode** (§7.1) rather than opening a creation form — this is a deliberate, narrow exception to "every `+` opens a creation form" (PART 22 Rule 21/23), because this `+` isn't creating a vault object at all; it's editing dashboard layout state (`SharedPreferences`-backed, per `dashboard_provider.dart`), which is a different kind of thing than a Task/Note/Habit. I call this out explicitly so it isn't mistaken for a violation of that rule during review.

```dart
IconButton(
  icon: Icon(_editMode ? Icons.done_rounded : Icons.tune_rounded),
  tooltip: _editMode ? 'Done editing' : 'Edit dashboard',
  onPressed: () => setState(() => _editMode = !_editMode),
),
```

Uses `Icons.tune_rounded` rather than a second `Icons.add_rounded` specifically to avoid the exact FAB-confusion pattern you're trying to eliminate everywhere else in the app — a second `+` right next to the FAB's `+` in the same screen would recreate the "which plus does what" ambiguity at a smaller scale.

---

## 5. Component catalog

All eight components below are `BlockType` values. `metadata` (already a free `Map<String,dynamic>` on `DashboardBlock`) holds each component's config; schemas given per component. All components:
- Render inside a `Container(decoration: AppTheme.cardDecoration(context))` — the existing "Card de seção" pattern (`agents.md` §6.3).
- Show an empty state (icon + one line + optional CTA) when their data source has nothing today, never a bare blank card.
- Have every `Text` wrapped with `maxLines`/`overflow: ellipsis` (checklist item 14.1).
- Are individually removable/reorderable in Edit Mode (§7.1) — none is mandatory except as noted in §5.7.

### 5.0 Shared service: `TodayAggregatorService` (new — `lib/services/today_aggregator_service.dart`)

Single resolver behind both the Timeline (§5.1) and Today's Completables (§5.7) components, per the "one aggregator, not eight" decision (§3.3).

```dart
enum TodayItemKind { entry, task, event, habitSlot, pomodoro, trackerRecord, reminder }
enum TodayItemOrigin { created, scheduled } // drives the 🕐 vs ⚡ glyph (PART 23.8 convention, reused)

class TodayItem {
  final String id;              // stable id of the underlying object (or `${objectId}_${slotIndex}` for habit slots)
  final TodayItemKind kind;
  final TodayItemOrigin origin;
  final DateTime timestamp;     // the time used for chronological sort
  final String title;
  final String emoji;           // per Object Identification override if set, else PART 1.5 type default
  final Color color;            // priority color (Task), Organizer color (Event/Habit), or type default
  final bool isCompletable;     // true for task, habitSlot; false for entry, event*, reminder, trackerRecord
  final bool isCompleted;
  final bool isPlayable;        // true for task, event with pomodoro != null; false otherwise (see §5.7)
  final ContentObject source;   // for navigation on tap
}

class TodayAggregatorService {
  List<TodayItem> buildForDate(DateTime date, {required List<ContentObject> allObjects}) {
    // 1. Entries created today (JournalEntry.date == date) → origin: created, kind: entry, not completable
    // 2. Tasks with endDate == date OR startDate == date (whichever the Task itself considers its
    //    "scheduled for" field — see task_model.dart's own date semantics) → origin: scheduled, kind: task,
    //    completable (checkbox toggles TaskStage.finalized per PART 22)
    // 3. Events with date == date → origin: scheduled, kind: event, not completable by default
    //    (no "did the meeting happen" checkbox — meetings aren't a completion concept in this app's model)
    // 4. Habit slots for every active, non-negative Habit whose scheduler fires today, one TodayItem per
    //    slot → origin: scheduled, timestamp from HabitSlot.primaryReminderTime (per your own standing rule:
    //    "Habit reminder time ≠ completion time" — never use actual completion timestamp for placement)
    // 5. Pomodoro sessions with date == date (completed ones only; scheduled/future ones are covered by
    //    their linked Task/Event instead, to avoid double-listing) → origin: created (uses occurredAt),
    //    kind: pomodoro, not completable (it's a log, not a to-do)
    // 6. Reminders (standalone) firing today → origin: scheduled, kind: reminder, not completable here
    //    (completing a standalone Reminder happens via its own notification actions, not this component)
    // Sort ascending by `timestamp`. Items with no time-of-day (e.g. all-day Events, undated Tasks) sort
    // to a fixed position: grouped at the very top of the list, in title-alphabetical order, before the
    // first timestamped item — never silently dropped, never given a fake midnight timestamp that would
    // misplace them mid-list.
  }
}
```

This service takes `allObjects` as a parameter (not `ref.watch` internally) so it stays a stateless, testable service per the existing `lib/services/` convention (`obsidian_service.dart`, `scheduler_service.dart` follow the same shape) — the *provider* wrapping it does the `ref.watch(allObjectsProvider)` call (see `lib/providers/today_provider.dart`, new, thin `Provider.autoDispose` that just calls this service and re-runs whenever `allObjectsProvider` changes).

---

### 5.1 Timeline (Today) — `BlockType.todayTimeline`

**Matches your mockup's "Timeline do dia" card exactly** (07:00 Rotina matinal → 21:30 Rotina noturna, chronological, mixed types).

- **Data source:** `TodayAggregatorService.buildForDate(today)`, unfiltered — every kind, both origins.
- **Rendering per row:** left rail = time label (`HH:mm`, or blank for the untimed group per §5.0's sort rule) in a muted vertical dotted-line rail (matches mockup's grey dot + connecting line); type-emoji + colored dot; title (bold if `origin == scheduled` and time is in the future relative to now, regular otherwise); trailing origin glyph (🕐 created / ⚡ scheduled, reused verbatim from PART 23.8's existing convention — no new iconography invented).
- **"agora HH:mm" header:** a horizontal marker line at the row corresponding to `DateTime.now()`'s position in the sorted list (visible only when viewing today, not other dates — this component only ever shows today, by design; historical days are the Journal/Planner's job).
- **Tap behavior:** navigates to the source object's detail view (`ContentObject` → its canonical detail screen), consistent with PART 23.8's dispatch rule.
- **Config (`metadata`):**
  ```json
  { "maxItems": 12, "showUntimedGroup": true }
  ```
  `maxItems` truncates with a "+N more · View full day in Planner" footer link to `/planner?date=today` — keeps the card from growing unboundedly on a busy day.
- **Empty state:** "Nothing on your plate today yet" + CTA → opens FAB's Plan tab.

### 5.2 Day Dial — `BlockType.todayDial`

**Thin dashboard-sized embedding of the existing/in-progress Day Dial spec** (`guidelines.md` PART 19.5 explicitly lists this exact use case).

- **Data source:** `DayDialAggregatorService` (already specified, or its redesigned successor from your in-flight Day Dial spec — whichever lands first, this component just calls it).
- **Rendering:** `DayDialWidget(size: DialSize.small)` (or whatever size enum your redesign ships) inside the card, plus the legend row shown in your mockup (colored dot + label + duration per category — "Rotina 7h", "Login 9.5h", etc.) rendered *below* the dial rather than as an overlay, since the dashboard card is width-constrained and an overlay legend would collide with the small dial's own hour markers.
- **Tap behavior:** whole card navigates to the Planner's day view (where the full-size, interactive dial lives) — the dashboard copy is view-only, no drag/resize here (that interaction model belongs on the full Planner dial per your redesign spec, not duplicated at dashboard-card scale).
- **Config (`metadata`):** `{ "showLegend": true, "showSummaryStats": true }` — matches the "Optional summary stats" flag PART 19.5 already specifies for `DayDialWidget`.
- **Empty state:** N/A — the dial always renders (an all-`idle` dial is itself the empty state, same as any day with nothing scheduled).
- **Dependency note:** if your Day Dial redesign spec is still mid-implementation when this ticket is picked up, ship this component against the *current* `DayDialWidget`/`DayDialAggregatorService` (PART 19.5, already real code) first — swapping in the redesigned dial later is a drop-in replacement of the widget this card embeds, not a rework of this component's own spec.

### 5.3 Quick-Add Shopping — `BlockType.shoppingQuickAdd`

- **Data source:** one specific `ShoppingList` (see config below), read via `allObjectsProvider.whereType<ShoppingList>()`.
- **Rendering:** single-line text field + send button (visually identical to the existing `_QuickCaptureCard` pattern already in `home_screen.dart` today — reuse that exact widget, parameterized, rather than building a fourth variant of "text field + submit button" card) + a compact preview of up to 3 active items below it (name, quantity if set, tap-to-check).
- **Submit behavior:** appends a new `ShoppingItem` (status: active) to the configured list's `items`, via `VaultNotifier.updateObject` on the `ShoppingList` — **not** a new file (a `ShoppingItem` is an embedded value class per `shopping_list_model.dart`, never its own vault object; per the already-resolved duplicate-model bug in PART 22 Rule 20, do not resurrect the deleted standalone `ShoppingItem` model — construct the embedded class directly).
- **List target resolution:** `ShoppingList` has no `isDefault`/pinned flag in the model today (checked — none exists). Resolution order: (1) `metadata['shoppingListId']` if the config sheet has one set explicitly; (2) else, the most-recently-`updatedAt` non-archived `ShoppingList`; (3) else, if none exist at all, the submit action creates a new list titled "Shopping List" on first use (same lazy-creation idiom already used for system moods per PART 22 Rule 8) rather than blocking the quick-add with an empty state that requires leaving the dashboard.
- **Config (`metadata`):**
  ```json
  { "shoppingListId": "wikilink-or-null", "previewCount": 3 }
  ```
  The config sheet's picker for `shoppingListId` reuses `UniversalSearchPickerSheet` filtered to `shopping_list` (per PART 22 Rule 22's "one shared search service" rule), with a "Create new list" pinned row, exactly like every other object picker in the app.
- **Empty state:** N/A for the input itself (always usable); the 3-item preview area shows "No items yet" only if the resolved list is genuinely empty.

### 5.4 Week Quick View — `BlockType.weekOverview`

**Matches your mockup's "Semana" 7-day mini-grid.**

- **Data source:** `TodayAggregatorService`-style aggregation, but called once per day of the current Mon–Sun week (or Sun–Sat — see config) rather than for a single date; for each day, only the top N items by priority/time (not the full timeline) — reuses the same per-day resolution logic as §5.0, just invoked 7 times with a `maxItemsPerDay` cap instead of §5.1's `maxItems` cap on one day.
- **Rendering:** 7 equal-width columns, day-of-month + day-of-week abbreviation header, today's column visually emphasized (accent-colored circle around the date, matching your mockup's orange "8" circle), up to 3 compact item chips per day (emoji + 1-line truncated title, colored by type), "+N" footer chip if more than 3 exist that day.
- **Tap behavior:** tapping a day column navigates to Planner's day view for that date; tapping an individual chip navigates straight to that object.
- **Config (`metadata`):** `{ "weekStartsMonday": true, "maxItemsPerDay": 3 }` — `weekStartsMonday` should read from the existing global locale/settings preference if one already exists in `settings_provider.dart` rather than being a per-component override; treat this key as a fallback only if no global setting is found (avoids a genuinely silly situation where each of a user's 3 different week-view components disagrees about which day the week starts on).
- **Empty state:** never fully empty (structure always renders); an individual day column with nothing shows a single muted dash, not a whole empty-state block.

### 5.5 Month Quick View — `BlockType.monthOverview`

**Matches your mockup's "Julho 2026" calendar card.**

- **Data source:** same per-day resolution as §5.4, called across every day in the current calendar month, but rendered far more compactly (calendar grid, 1–2 chips max per day cell, mockup shows exactly this: e.g. "Reu..." truncated + a colored dot for additional items).
- **Rendering:** standard calendar grid (reuse `calendar_widget.dart` if its existing rendering mode supports a compact "chip per cell" density — check before writing a new grid from scratch, since a calendar grid is exactly the kind of reusable piece PART 22's source-folder convention wants centralized; if `calendar_widget.dart`'s current API doesn't support this density mode, extend it with a `CalendarDensity.compact` parameter rather than forking a second calendar widget), month navigation via the existing `<`/`>` chevrons pattern shown in your mockup, today's cell emphasized identically to §5.4.
- **Tap behavior:** tapping a day cell navigates to Planner's day view for that date.
- **Config (`metadata`):** `{ "maxChipsPerCell": 2 }`.
- **Empty state:** never fully empty (grid structure always renders).

### 5.6 Goals & Projects Quick View — `BlockType.goalsProjectsOverview`

**Matches your mockup's "Goals & Projetos" percentage-bar list.**

- **Data source:** `allObjectsProvider.whereType<Goal>()` (using the existing, already-correct `Goal.progress` getter, §2.5) **and** `allObjectsProvider.whereType<Project>()` **and** the new `ProjectProgressResolver` (§8, since no equivalent exists for Project today) — merged into one list, sorted by `metadata['sortMode']` (see config).
- **Rendering:** one row per Goal/Project — emoji (Goal/Project type default, or Object Identification override) + title + horizontal progress bar + percentage label, exactly matching the mockup's "🏠 Limpeza da Casa — 42%" row style. A small type chip ("Goal" purple / "Project" per its own `color` field) disambiguates the two, since they're visually merged into one list per your request but are structurally distinct object types.
- **Filtering:** excludes `GoalStatus.cancelled`/`completed` Goals and `ProjectState.archived`/`completed` Projects by default (config can opt back in — see below) — a quick-glance progress component showing already-finished things at "100%" forever provides no ongoing value and clutters the card.
- **Config (`metadata`):**
  ```json
  { "maxItems": 5, "sortMode": "progress_asc | progress_desc | manual", "includeCompleted": false, "typeFilter": "all | goals_only | projects_only" }
  ```
- **Tap behavior:** navigates to the Goal/Project's detail view (Organizer detail view for Project, per PART 23.8).
- **Empty state:** "No active goals or projects yet" + CTA → FAB's Organize tab (Project) / Plan tab (Goal).

### 5.7 Today's Completables — `BlockType.todayCompletables`

**Matches your mockup's "Hoje" checklist card (2/6 progress header, checkbox + play icons).**

This is the one component `guidelines.md` PART 3 already named as load-bearing (there called "Today's Habits"), and your request broadens its scope from habits-only to "tasks, events, habits, Pomodoro, etc." with checkboxes and a Pomodoro play affordance. Rather than ship a second, competing panel, **this component supersedes "Today's Habits" and absorbs its two explicitly load-bearing business rules** — this is a deliberate consolidation decision, documented as such in the `guidelines.md` changelog entry (§10).

- **Data source:** `TodayAggregatorService.buildForDate(today)`, filtered to `isCompletable == true` items only (Tasks, Habit slots; Events/Entries/Pomodoro logs/Reminders are excluded here even though they appear in the Timeline component — a completables list showing un-completable rows would make the checkbox affordance meaningless).
- **Two business rules carried over from PART 3/PART 2 verbatim** (do not relax these during implementation):
  1. **Negative habits are explicitly excluded** (a "don't do X" habit has no meaningful "complete" checkbox).
  2. **Soft-recurring maintenance Tasks surface here once "coming due"** — see Ticket 11 (§9), fenced off since the underlying Task fields don't exist in code yet (§2.7).
- **Header:** progress fraction ("2/6") + linear progress bar, exactly per mockup, computed as `completedCount / totalCount` of the filtered list for today — recalculated live as items are checked, not cached.
- **Rendering per row:** type-emoji + priority/type-colored dot + title (strikethrough + muted when completed, matching mockup's "Rotina FlyLady"/"Comprar vitaminas" styling) + trailing action cluster:
  - **Play button (▶):** shown only when `isPlayable` — Task always; Event only if `Event.pomodoro != null`; Habit slot **never** (habits aren't Pomodoro-linkable objects in this app's current model — confirmed by checking `pomodoro_provider.dart`'s `start()`/`startRelayMode()` signatures, both take a task/item id + title, never a Habit id). Tapping ▶ calls `ref.read(pomodoroProvider.notifier).start()` pre-filled with that item as the linked target (or `.startRelayMode()` if the underlying Task has `RelayStep`s configured, once Focus Relay — currently specced, not built per your own roadmap — lands; until then, always plain `.start()`).
  - **Checkbox:** always shown (every row here is completable by construction). Tapping it:
    - **Task:** `VaultNotifier.updateObject(task.copyWith(stage: TaskStage.finalized))` (uncheck reverses to the task's prior stage, cached client-side for the duration of the checkbox interaction only — not persisted as a separate field).
    - **Habit slot:** appends/removes a `CompletionRecord` on `Habit.completionHistory` for today's date + this slot (per §2.6, this writes to the code's actual source of truth, not the daily-note frontmatter the docs currently describe).
  - **Haptic feedback** on both interactions per `agents.md` §6.5 (light impact for habit, medium for task — matching the existing app-wide convention exactly, not inventing a third haptic weight for this component).
- **Config (`metadata`):** `{ "maxItems": 8, "includeEvents": false }` — `includeEvents` stays `false` by default since Events aren't completable by this component's own filter rule; exposing the flag is only useful once/if a future Event sub-type gains a completion concept, so it's here as a forward-compatible no-op switch, not because it does anything meaningful on day one.
- **Empty state:** "All clear for today 🎉" (only when the filtered list is genuinely empty, not just fully checked — a fully-checked list still shows "6/6" with strikethrough rows, which is itself the desired satisfying end-state, not an empty state).

---

## 6. `ComponentRegistry` (new — `lib/services/component_registry.dart`)

Replaces the stubbed `availableWidgetBlocks` (§2.2) as the single source of truth for "what components exist, and what does each need to render/configure." Purely descriptive metadata — no widget-building logic lives here (that stays in each component's own widget file under `lib/ui/widgets/dashboard/`).

```dart
class ComponentDefinition {
  final BlockType type;
  final String defaultTitle;
  final String description;      // shown in the "add component" picker
  final IconData icon;           // shown in the "add component" picker
  final Map<String, dynamic> defaultMetadata;
  final bool allowMultipleInstances; // e.g. two Week views with different sortModes — true for most;
                                      // false only where it wouldn't make sense (Day Dial: one is enough)
}

const componentRegistry = <ComponentDefinition>[
  ComponentDefinition(type: BlockType.todayTimeline, defaultTitle: 'Timeline',
      description: 'Everything created or scheduled today, in order', icon: Icons.timeline_rounded,
      defaultMetadata: {'maxItems': 12, 'showUntimedGroup': true}, allowMultipleInstances: false),
  ComponentDefinition(type: BlockType.todayDial, defaultTitle: 'Day Dial',
      description: '24-hour view of how your day is filling up', icon: Icons.donut_large_rounded,
      defaultMetadata: {'showLegend': true, 'showSummaryStats': true}, allowMultipleInstances: false),
  ComponentDefinition(type: BlockType.shoppingQuickAdd, defaultTitle: 'Quick Add — Shopping',
      description: 'Add an item to a shopping list without leaving Home', icon: Icons.add_shopping_cart_rounded,
      defaultMetadata: {'shoppingListId': null, 'previewCount': 3}, allowMultipleInstances: true), // one per list
  ComponentDefinition(type: BlockType.weekOverview, defaultTitle: 'This Week',
      description: '7-day glance at what is coming up', icon: Icons.view_week_rounded,
      defaultMetadata: {'weekStartsMonday': true, 'maxItemsPerDay': 3}, allowMultipleInstances: false),
  ComponentDefinition(type: BlockType.monthOverview, defaultTitle: 'This Month',
      description: 'Full calendar-month glance', icon: Icons.calendar_view_month_rounded,
      defaultMetadata: {'maxChipsPerCell': 2}, allowMultipleInstances: false),
  ComponentDefinition(type: BlockType.goalsProjectsOverview, defaultTitle: 'Goals & Projects',
      description: 'Progress at a glance', icon: Icons.flag_rounded,
      defaultMetadata: {'maxItems': 5, 'sortMode': 'progress_asc', 'includeCompleted': false, 'typeFilter': 'all'},
      allowMultipleInstances: true), // e.g. one "goals only", one "projects only"
  ComponentDefinition(type: BlockType.todayCompletables, defaultTitle: "Today's Completables",
      description: 'Tasks, habits and more you can check off today', icon: Icons.checklist_rounded,
      defaultMetadata: {'maxItems': 8, 'includeEvents': false}, allowMultipleInstances: false),
];
```

`BlockType.todayHabits` (the current single named value, §2.2) is **not deleted** from the enum — old persisted `DashboardBlock` entries of that type are migrated on load (§7.4) to `todayCompletables` with a `metadata` flag `{ "migratedFromTodayHabits": true }`, satisfying the "never introduce silent data loss on an enum rename" instinct without keeping two competing habit-only and everything-completable panels alive side by side.

---

## 7. Dashboard Edit Mode

### 7.1 Entering/exiting
Toggled by the `+`/done button (§4.2). While active:
- Each component card gets a drag handle (leading `Icons.drag_indicator_rounded`) and a trailing `⋯` menu (Configure / Remove) — same interaction language as PART 3's original mechanics description ("Panels are added/removed/reordered via drag on the Dashboard's edit mode").
- A "+ Add component" card appears pinned at the bottom of the list, opening the picker below.
- Reordering calls the already-correct `dashboardProvider.notifier.reorderBlocks(oldIndex, newIndex)` (no changes needed there — it already works).

### 7.2 Fixing `addBlock` (was: silent no-op, §2.2)

```dart
Future<void> addBlock(
  BlockType type,
  String title, {
  Map<String, dynamic> metadata = const {},
}) async {
  final current = state.valueOrNull ?? [];
  final block = DashboardBlock(
    id: const Uuid().v4(),
    type: type,
    title: title,
    order: current.length,
    metadata: metadata,
  );
  state = AsyncData([...current, block]);
  await _save();
}
```

### 7.3 "Add component" picker
A `StandardSheet` listing `componentRegistry` entries (icon + title + description), filtering out any `allowMultipleInstances: false` type whose `BlockType` already has a visible instance on the dashboard. Tapping an entry calls `addBlock(definition.type, definition.defaultTitle, metadata: definition.defaultMetadata)`, then immediately opens that component's config sheet (§7.5) so the user configures it (e.g. picks *which* shopping list) before it's added to the visible list, rather than adding a half-configured card and making them hunt for the config afterward.

### 7.4 Migration on load
`DashboardNotifier.build()` (currently a plain decode-or-empty, §2.2's code) gains one migration pass after decoding: any block with `type == BlockType.todayHabits` is rewritten in-memory to `type: BlockType.todayCompletables, metadata: {...oldMetadata, 'migratedFromTodayHabits': true}` before being returned, and the migrated list is immediately re-persisted via `_save()` so the migration only ever runs once per install.

### 7.5 Per-component config sheet
One shared `ComponentConfigSheet(block: DashboardBlock)` widget that switches on `block.type` to render the right `FormSection` fields (per §5's per-component config schemas) — not eight separate sheet files. Saves via `dashboardProvider.notifier.updateBlock(block.copyWith(metadata: newMetadata))` (already correct, no changes needed to `updateBlock`).

---

## 8. `ProjectProgressResolver` (new — extends `kpi_engine.dart`, or a new sibling file `lib/services/project_progress_resolver.dart` if `kpi_engine.dart`'s own scope shouldn't stretch to cover this — check `kpi_engine.dart`'s existing responsibilities before deciding placement)

Closes the gap in §2.5. Resolution order, falling through only when the higher-priority source is unavailable — never blending two sources into one number, since that would make the percentage meaning ambiguous:

1. **If `Project.primaryKpiId` is set** and resolves to a KPI in `Project.kpis`: use that KPI's `current_value / target_value` directly (identical mechanism to `Goal.progress`, reusing the exact same resolver function PART 1.4 already mandates KPI and Combined Analysis share — Project's primary-KPI progress should be the third consumer of that one resolver, not a fourth divergent implementation).
2. **Else, if `Project.phases` is non-empty:** resolve every `taskLinks` WikiLink across all phases against `allObjectsProvider`, and compute `count(stage == finalized) / count(total resolved)`. Tasks that fail to resolve (dangling WikiLink — user deleted the task file directly in Obsidian) are excluded from both numerator and denominator, not counted as incomplete, so a few broken links don't silently tank an otherwise-healthy project's percentage.
3. **Else, if `Project.taskLinks` (project-level, no phases) is non-empty:** same resolution as #2, against the flat list instead of per-phase.
4. **Else (no KPI, no phases, no task links):** the Project has no computable progress. Render "—" instead of "0%" in the Goals & Projects component (§5.6) — a Project with genuinely nothing to measure yet is a different state from a Project that's measurably 0% done, and collapsing them into the same "0%" would be misleading.

---

## 9. Implementation tickets (dependency-ordered)

| # | Ticket | Depends on | Priority |
|---|---|---|---|
| 0 | Delete `lib/models/dashboard_panel.dart` (dead, deprecated, superseded by this spec's use of `dashboard_block.dart`) | — | P2 |
| 1 | Extend `BlockType` enum with the 6 new values (`todayTimeline`, `todayDial`, `shoppingQuickAdd`, `weekOverview`, `monthOverview`, `goalsProjectsOverview`); rename `todayHabits`'s *conceptual* role to be superseded by `todayCompletables` (new enum value added, `todayHabits` kept for migration only) | — | P0 |
| 2 | Fix `DashboardNotifier.addBlock` (§7.2) and add the `todayHabits → todayCompletables` migration pass (§7.4) | 1 | P0 |
| 3 | Build `ComponentRegistry` (§6), delete the stubbed `availableWidgetBlocks` list | 1 | P0 |
| 4 | Build `TodayAggregatorService` (§5.0) + thin `todayProvider` wrapper | 1 | P0 |
| 5 | Build `ProjectProgressResolver` (§8) | — (independent of dashboard work; can run in parallel) | P1 |
| 6 | Build `TodayTimelineComponent` widget (§5.1) | 4 | P1 |
| 7 | Build `TodayCompletablesComponent` widget (§5.7, minus the maintenance-task carve-out — see Ticket 11) | 4 | P1 |
| 8 | Build `DayDialComponent` embedding wrapper (§5.2) | existing/in-progress Day Dial spec | P1 |
| 9 | Build `ShoppingQuickAddComponent` widget (§5.3) | — | P2 |
| 10 | Build `WeekOverviewComponent` and `MonthOverviewComponent` widgets (§5.4/§5.5); extend `calendar_widget.dart` with a compact density mode if it doesn't already support one — check before forking | 4 | P2 |
| 11 | **Blocked, do independently:** implement `Task.flexibleRecurrence`/`targetFrequencyDays` fields (§2.7) end-to-end (model + form + "coming due" surfacing logic), *then* wire the maintenance-task carve-out into `TodayAggregatorService`/`TodayCompletablesComponent` | 4, 7 | P2 |
| 12 | Build `GoalsProjectsOverviewComponent` widget (§5.6) | 5 | P1 |
| 13 | Wire the top-bar sync icon (§4.1) and edit-mode `+` button (§4.2) into `home_screen.dart`; build `ComponentConfigSheet` (§7.5) and the "Add component" picker sheet (§7.3) | 3 | P0 |
| 14 | Rebuild `home_screen.dart`'s body as a reorderable `ReorderableListView` driven by `dashboardProvider`, rendering each visible, sorted `DashboardBlock` via a `switch` on `block.type` to the corresponding component widget from Tickets 6–12 (default/first-run seed: Timeline + Day Dial + Today's Completables, matching your mockups) | 2, 3, 6, 7, 8, 13 | P0 |

Tickets 0–4 and 13 form the load-bearing chain (P0) — everything else is a component that plugs into that chain once it exists, and can be built/reviewed independently and in any order after Ticket 4/13 land.

---

## 10. `guidelines.md` update (draft changelog entry — insert as V5.4)

The existing "DASHBOARD PANEL — reset pending redesign" passage (PART 3) explicitly deferred the panel catalog. This spec is that redesign. Suggested replacement text for that section once implementation lands:

> ### DASHBOARD COMPONENT SYSTEM (finalized in V5.4, supersedes the V5.1 "reset pending redesign" placeholder)
>
> The Home dashboard is composed of **components** (never "widgets" — PART 15) — reusable, configurable cards backed by either a `DataSourceReference` or a fully-specified aggregator service, added/removed/reordered via the Home screen's own Edit Mode (entered via the `tune` icon beside the sync-status icon in the AppBar, distinct from the FAB). The finalized catalog: **Timeline**, **Day Dial**, **Quick-Add Shopping**, **This Week**, **This Month**, **Goals & Projects**, **Today's Completables**. **Today's Completables supersedes the V5.1 "Today's Habits" panel**, broadening it from habits-only to every completable-today object type (Tasks, Habit slots), while preserving both of Today's Habits' load-bearing rules verbatim: negative habits are excluded, and soft-recurring maintenance Tasks surface here once coming due. Full specification, data models, and per-component config schemas: `home_dashboard_components_spec_v1.md`.

I did not apply this edit to your live `guidelines.md` myself — you fetch it from the repo yourself and I can't push commits (per our standing workflow), so this is worded as a drop-in replacement paragraph for you (or your next implementation pass) to paste in once the tickets above are actually built and tested on-device, consistent with your "done = tested on device" rule — I'd hold off committing this changelog text until then, not before.

No changes needed to `agents.md` beyond the stale file-size annotation on `home_screen.dart` noted in §2 — not urgent, cosmetic only.

---

## 11. Acceptance criteria (per component, condensed)

- [ ] All 7 new components render correctly in both light and dark mode, at 360×640 and 412×915, with no text overflow.
- [ ] `addBlock` actually adds a persisted, visible component (fixes §2.2's stub) — verified by force-quitting and relaunching the app.
- [ ] Existing users with a previously-saved `todayHabits` block see it silently become `todayCompletables` on next launch, with no data loss and no duplicate card.
- [ ] Sync icon reflects real `syncStatusProvider` transitions during an actual sync (toggle airplane mode to hit `offline`; trigger a real conflict to hit `conflict`).
- [ ] Today's Completables checkbox interactions correctly write to `Task.stage`/`Habit.completionHistory` (not the daily-note frontmatter, per §2.6) and haptic weights match the existing app-wide convention.
- [ ] Goals & Projects component shows "—" (not "0%") for a Project with no KPI/phases/task-links configured yet.
- [ ] Removing a component from the dashboard and re-adding it resets it to `ComponentDefinition.defaultMetadata`, not stale config from before removal.
- [ ] Play button appears only on Task rows and pomodoro-enabled Event rows within Today's Completables — never on Habit rows.