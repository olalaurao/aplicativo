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

# Day Dial v2 — Full Redesign Spec 08/07/26

**Status:** Ready for implementation
**Author:** Claude (technical collaborator), for Laura / Citrine
**Depends on:** `guidelines_v5.4`, existing `day_dial_model.dart` / `day_dial_aggregator.dart` / `day_dial_widget.dart` (all superseded by this spec)
**Repo:** `github.com/olalaurao/aplicativo`, branch `main`

---

## 0. Purpose

Replace the current Day Dial (circular 24h view under Planner → Dial tab) with a complete rebuild that can:

1. Show **everything** happening in a day on one 24h dial — habits (with emoji), past mood entries, events, time blocks, Pomodoro sessions, tasks with a scheduled time.
2. Handle **overlap** correctly (a meeting inside a focus time block, a habit reminder during an event, etc.) via **concentric rings**, not overwrite.
3. Support **click-and-drag to move** an item and **edge-drag to resize** it, writing changes back to the vault.
4. Show a **time-remaining readout** for the next upcoming item.
5. Fix the current data-loss and rendering-artifact bugs (documented below).

Reference apps inspected for interaction/visual patterns: `taskdial.app` (color-coded time blocks on a clock face with Pomodoro), and — found during research because it implements the overlap case explicitly — an app called Dialed, whose recent changelog describes a **multi-layer ring system for overlapping segments**, drag-to-reposition via long-press with live visual feedback, and a **progress ring + time-remaining display** for the currently active item. These three ideas (layered rings for overlap, live drag feedback, and a countdown for the "current/next" item) map directly onto Laura's requirements and are used as the structural basis for §5–§7 below. No code or assets from these apps are used — only the general interaction concepts, which are common across this whole app category (Sectograph, Arcadia, CircleTime all converge on the same "segments around a clock face" pattern).

---

## 1. Audit of current implementation

### 1.1 Files involved today

| File | Role |
|---|---|
| `lib/models/day_dial_model.dart` | `DialHourKind` enum + `DayDialHourState` (one struct per hour, 0–23) |
| `lib/services/day_dial_aggregator.dart` | Builds the 24 `DayDialHourState` from tasks/habits/pomodoro/events/reminders |
| `lib/ui/widgets/day_dial_widget.dart` | `CustomPainter` that draws the ring from `hourStates` |
| `lib/ui/screens/planner_screen.dart` (`_buildDialView`, ~L2184–2230) | Wires the aggregator + widget into the Planner "Dial" tab |

### 1.2 Root cause of the two orphan dots in the current screenshot

This is a **data model problem**, not a rendering glitch, and it explains both of Laura's known open bugs ("aggregator uses an hourly-bucket map where later writes overwrite earlier ones" and "near-zero-degree sweep angles with round stroke caps create orphaned dot artifacts"):

- `DayDialHourState` holds **exactly one `kind` and one `fillFraction` per hour** (`day_dial_model.dart` L13–L18). There is no list of items per hour — there's one slot.
- `DayDialAggregator.aggregateForDate` (L20–143) processes Pomodoro sessions, then planned tasks, then Google events, then habits, then reminders, **each pass calling `hourStates[startHour] = hourStates[startHour].copyWith(...)`**. Every later pass silently discards whatever the earlier pass wrote for that hour. Two things scheduled in the same hour → only the last one aggregated survives on the arc. Habit icon and reminder icon fields do independently coexist with `kind`, but multiple habits/reminders in the same hour still collide with each other (only one `habitIconName` per hour, L116–121).
- Fill fraction is computed as `duration / 60.0` clamped to `[0,1]` and always drawn starting exactly at `_hourToAngle(state.hour)` (`day_dial_widget.dart` L122–138) — i.e. **every item snaps to the top of its hour**, regardless of actual minute. A 10-minute item and a 55-minute item both live inside "their" hour slot with no minute-level positioning.
- `_DayDialPainter` draws every non-zero arc with `strokeCap: StrokeCap.round` (L130). When `fillFraction` is small (e.g. a 5–10 minute Pomodoro block that only fills a sliver of the hour), the sweep angle is near zero, and a round stroke cap on a near-zero-length arc renders as a filled disc — exactly the two floating dots in the screenshot, positioned wherever those short items landed.
- There is no `id`/`slug`/`title` carried on `DayDialHourState` at all — the dial cannot support tap-to-open-detail, drag-to-move, or drag-to-resize because it doesn't know *what* is occupying a given arc, only *that something* is.

**Conclusion:** the fix is not a patch to the painter — it requires an hour-bucket-free data model where every scheduled thing is its own timed segment, and a real overlap-layering algorithm. That is what this spec builds.

### 1.3 Other pre-existing gaps this spec must also close (from Laura's backlog)

- Day Themes and Time Blocks have **no dial support at all**: no `DialHourKind` value, no aggregator handling, no call-site parameters passed into `_buildDialView`. This rebuild adds first-class time-block rendering (§5.4).
- `reminders: const []` is hardcoded in `_buildDialView` (planner_screen.dart L2201) — reminders are never actually passed in from the real provider. Fixed in §9.4.

---

## 2. Requirements (restated precisely from Laura's request)

1. Single 24-hour circular dial, showing **all** day items simultaneously.
2. **Habits** → shown with their emoji.
3. **Past mood entries** → shown on the dial (read-only, point-in-time).
4. **Colors** for events, time blocks, Pomodoro sessions (and tasks/reminders).
5. **Overlap must work** — concentric rings, not overwrite. This is explicitly the common case for Laura (a meeting inside a dedicated focus block), so it is a P0 requirement, not an edge case.
6. **Click-and-drag to reposition** an item (change its start time).
7. **Edge-drag to resize** (change its duration).
8. **Time-remaining readout** for the next upcoming item, shown in the center.
9. Spec must be grounded in the actual current codebase and be directly implementable by an AI coding agent.

---

## 3. New data model

New file: **`lib/models/day_dial_model.dart`** (replaces current contents entirely).

```dart
/// The category of a dial segment — drives color, icon fallback, and
/// whether the segment is user-editable (draggable/resizable).
enum DialSegmentKind {
  event,            // Event / Google Calendar event
  timeBlock,        // Organizer of type time-block, spanning its configured hours
  taskPlanned,      // Task with scheduledTime, not yet completed via Pomodoro
  pomodoroPlanned,  // Scheduled/upcoming Pomodoro session
  pomodoroCompleted,// Completed Pomodoro session (historical, read-only)
  habitSlot,        // A habit's scheduled slot for the day (from HabitSlot.primaryReminderTime)
  reminder,         // Standalone reminder (not a habit reminder)
  dayTheme,         // Day Theme background band (P2 — see §5.4)
  sleep,            // Derived idle/sleep band (optional, see §8.5)
}

/// One continuous arc segment on the dial: has a real start+end DateTime,
/// not an hour bucket. This is the core fix over the current model.
class DialSegment {
  final String id;              // stable id: '<kind>:<sourceId>[:<slotIndex>]'
  final DialSegmentKind kind;
  final DateTime start;
  final DateTime end;           // always > start; midnight-spanning allowed (see §8.1)
  final String title;
  final String colorHex;        // resolved concrete color (see §6)
  final String? emoji;          // habit icon, mood emoji, etc. — null for events/blocks
  final String? sourceSlug;     // the underlying object's slug/id, for tap-to-open
  final bool isEditable;        // true only for taskPlanned, pomodoroPlanned, reminder,
                                 // event (if not Google-synced — see §7.5), habitSlot (time only)
  final bool isResizable;       // subset of isEditable (see §7)
  int layer;                    // 0 = innermost ring, assigned by the layering algorithm

  DialSegment({...});
}

/// A point-in-time marker (no duration): mood entries.
class DialPointMarker {
  final String id;
  final DateTime timestamp;
  final String emoji;
  final String label;           // mood label, for tooltip/detail sheet
  final String? sourceSlug;     // JournalEntry slug, for tap-to-open

  DialPointMarker({...});
}

/// Full snapshot the widget renders. Produced fresh by the aggregator
/// on every relevant provider change.
class DayDialSnapshot {
  final DateTime date;
  final List<DialSegment> segments;      // already layer-assigned
  final List<DialPointMarker> moodMarkers;
  final int maxLayer;                    // segments.map((s)=>s.layer).max, for ring sizing
  final DialSegment? nextUpcoming;       // first segment with start > now (today only)

  DayDialSnapshot({...});
}
```

Design notes:

- No more `DayDialHourState.copyWith` overwrite pattern. Every item is its own object in a `List<DialSegment>`, so nothing is ever silently dropped.
- `layer` is mutable and assigned by the aggregator (§5.2), not by the widget — the widget only draws what it's given, per the existing app-wide separation of aggregation (service) vs. rendering (widget/painter).
- `isEditable` / `isResizable` are computed once by the aggregator so the widget/gesture layer never needs to re-derive "can I drag this" business rules — mirrors how `Task.isAlignmentTrackable` etc. are computed getters on the model rather than re-checked ad hoc in UI (existing pattern in `task_model.dart` L139).

---

## 4. Source → segment mapping rules

This is the per-source-type ingestion contract for the new aggregator. Each rule replaces the corresponding block in the current `DayDialAggregator.aggregateForDate`.

| Source | Start | End | Color | Editable? | Notes |
|---|---|---|---|---|---|
| `PomodoroSession` (completed) | `occurredAt ?? date` | `start + minutesWorked` | `AppColors.success` | No | Historical log — never draggable/resizable. Matches "done = tested on device" spirit: a completed session is a record, not a plan. |
| `PomodoroSession` (scheduled/planned) | `date` | `date + workDuration` | `AppColors.primary` (lighter) | Yes (move+resize) | Only sessions with no completed counterpart for that linked item on that date (same de-dup check as current code, `day_dial_aggregator.dart` L58–64). |
| `Task` with `scheduledTime` != null, `stage != finalized` | parsed from `scheduledTime` (HH:MM) on `date` | `start + (estimatedMinutes ?? duration)` minutes | `task.color` if set, else `AppColors.primary` | Yes (move+resize) | Skip if it already produced a `pomodoroPlanned`/`pomodoroCompleted` segment for the same linked item+date (avoid double-rendering the same work twice — mirrors existing de-dup logic). |
| `Event` (local, not Google) | `event.startDatetime` | `event.endDatetime ?? start + 30min` | resolved via linked time block/organizer color if any, else `AppColors.info` | Yes (move+resize) | |
| Google Calendar `Event` | `start.toLocal()` | `end.toLocal()` | `AppColors.info` | **No** (see §7.5) | All-day events (`event.start?.date != null`) are excluded from the ring exactly as today (L84–85) — they belong in a header strip, not the dial, since they have no time-of-day. |
| Time Block (`Organizer` with block semantics, referenced by `Task.timeBlock` / `Habit.timeBlock`) | block's configured start hour | block's configured end hour | `organizer.color` | No (time blocks are edited from Settings → Time Blocks, not from the dial) | Renders as a **background band on its own dedicated inner ring** (ring −1, between the center hole and ring 0) so it visually "contains" whatever tasks/events happen to fall inside it — this directly implements Laura's "meeting inside my focus block" case without needing the meeting and the block to compete for the same ring. See §5.4. |
| `Habit` slot (`HabitSlot.primaryReminderTime`) | slot time | **point-in-time**, rendered as a short fixed-width tick (12 min visual width) not a true duration, since habits have no stored duration | `habit.color` | Yes, **move only, not resize** (habits have no duration field to resize) | Rendered with `habit.icon` as the glyph instead of a plain color arc. See §8.2 for the completion-time caveat. |
| `Reminder` (`habitReminder == false`, `isCompleted == false`) | `reminder.time` | point-in-time, same fixed visual width as habits | `AppColors.warning` | Yes (move only) | Fixes the `reminders: const []` hardcoding bug (§9.4). |
| `MoodEntry` (from `JournalEntry.moodEntries`, resolved date == dial date) | `entry.timestamp` | n/a — `DialPointMarker`, not a segment | n/a (emoji only) | No | See §8.3 for resolution against the mood catalog. |

---

## 5. Aggregation algorithm — `DayDialAggregatorV2`

New file: **`lib/services/day_dial_aggregator.dart`** (rewrite in place, same path, same class name so call sites in `planner_screen.dart` need only a signature change, not a rename).

### 5.1 Top-level shape

```dart
class DayDialAggregator {
  static DayDialSnapshot aggregateForDate({
    required DateTime date,
    required List<Task> tasks,
    required List<Habit> habits,
    required List<PomodoroSession> pomodoroSessions,
    required List<google_calendar.Event> googleEvents,
    required List<Event> localEvents,
    required List<Reminder> reminders,
    required List<Organizer> timeBlocks,       // NEW — was missing entirely before
    required List<JournalEntry> journalEntries,// NEW — source for mood markers
    required List<MoodDefinition> moodCatalog, // NEW — to resolve moodSlug -> emoji
  }) {
    final segments = <DialSegment>[];
    // ... one _ingestX(...) helper per row of the table in §4, each *appending*
    // to `segments`, never writing into a shared bucket. This alone fixes the
    // overwrite bug, independent of the layering step below.

    _assignLayers(segments);              // §5.2
    final moodMarkers = _buildMoodMarkers(journalEntries, moodCatalog, date); // §8.3
    final next = _findNextUpcoming(segments, date);

    return DayDialSnapshot(
      date: date,
      segments: segments,
      moodMarkers: moodMarkers,
      maxLayer: segments.isEmpty ? 0 : segments.map((s) => s.layer).reduce(max),
      nextUpcoming: next,
    );
  }
}
```

### 5.2 Overlap-layering algorithm (the concentric-rings requirement)

This is a standard **interval partitioning / greedy layer assignment**, applied per `DialSegmentKind` group separately from time blocks (time blocks always live on their own dedicated background ring, per §4, so they never compete for a layer with everything else):

```
1. Sort all non-timeBlock segments by `start` ascending, ties broken by
   longer duration first (so long items claim the inner ring, matching
   the visual convention in the reference apps where the "main" activity
   sits closest to the center and short interruptions sit outside it).

2. Maintain a list `layerEndTimes: List<DateTime>` — layerEndTimes[i] is
   the end time of the last segment placed in layer i.

3. For each segment s in sorted order:
     for i in 0..layerEndTimes.length:
       if s.start >= layerEndTimes[i]:
         s.layer = i
         layerEndTimes[i] = s.end
         continue to next segment
     // no existing layer is free:
     s.layer = layerEndTimes.length
     layerEndTimes.add(s.end)

3a. Point-in-time items (habit slots, reminders) are laid out AFTER duration
    segments, and are allowed to share a layer with a duration segment
    (they render as a small tick/emoji on top of whatever arc is
    underneath, not as competing arcs) — so they never force a new ring
    by themselves. Only two point-in-time items whose visual width
    (§4, 12-minute fixed width) would overlap each other get bumped to
    the next layer using the same algorithm.
```

This is the same class of algorithm Google Calendar and every side-by-side week view uses for overlapping events — applying it radially instead of column-wise is the only twist, and the widget (§6) just needs `layer` to pick a ring radius.

### 5.3 Layer cap & overflow (edge case, see §8.4)

Cap rendering at **4 rings** (ring 0 = innermost, ring 3 = outermost, before the tick-label ring). If `_assignLayers` produces `layer >= 4` for any segment, those segments are **not dropped** — they're kept in the snapshot with `layer = 3` (all overflow stacks visually on the outer ring, semi-transparent, and the outermost ring shows a small "+N" badge at the relevant angle instead of trying to render every one individually). Rationale: Laura's stated need is "let me see when I've overbooked myself," not "render 9 perfectly legible concurrent rings" — that many concurrent items genuinely can't be legible on a phone-sized dial, so past 4 the honest signal is "this window is overloaded," not more line detail.

### 5.4 Time blocks and Day Themes (closing two of Laura's documented gaps)

- **Time blocks**: rendered as filled background arcs on a dedicated ring between the center hole and ring 0 (call it ring `−1`), using the block's configured start/end hour and `organizer.color` at low opacity (~25%), so segments drawn on ring 0+ visually sit "inside" their time block. This single change gives time blocks dial support in both the Planner day view and here — closes the "Time Blocks not appearing in ... Dial view" bug by giving it an actual implementation rather than partial plumbing.
- **Day Themes**: rendered as a **thin colored ring outside the hour-label ring** (the outermost element), one continuous arc per theme spanning its configured hours (if Day Themes in this app are whole-day rather than hour-ranged, render as a single colored ring segment covering the full circle, or a colored dot cluster at 12 o'clock — confirm which against the actual `DayTheme` object once `day_theme_model.dart` is available; it returned an empty file when fetched for this spec, so pin down its real shape before implementing this part specifically). This is explicitly lower priority (P2) than the overlap/drag core of this spec — build §5–§7 first, then this.

---

## 6. Rendering spec — `DayDialWidget` v2

New file content for **`lib/ui/widgets/day_dial_widget.dart`** (rewrite in place).

### 6.1 Ring layout, center-out

| Ring | Content |
|---|---|
| Center hole | Current time (`HH:mm`), date, and **time-until-next** readout (§6.4) |
| Ring `−1` | Time-block background bands (§5.4), low opacity |
| Ring 0..3 | `DialSegment`s per their assigned `layer`, each ring a fixed stroke width, rings 1+ slightly thinner so the dial doesn't outgrow the screen |
| Point markers | Habit emoji / reminder ticks / mood emoji drawn as small circular glyph badges positioned at their `layer`'s radius (habits/reminders) or on a dedicated thin **mood ring** just inside the hour-label ring (moods — always visually distinct from schedule items since they're not "time you spent," they're a snapshot) |
| Outer ring | Hour tick marks + `12/1/2…11` labels (unchanged from current, this part isn't broken) |
| Current-time marker | Small dot on the outer edge at the live angle for `DateTime.now()`, only when `selectedDate` is today (unchanged behavior from current code, L152–166, keep as-is) |

### 6.2 Angle math

Reuse the existing, correct helpers unchanged:

```dart
double _hourToAngle(int hour) => (hour / 24) * 2 * pi - (pi / 2);
double _timeToAngle(DateTime time) {
  final totalMinutes = time.hour * 60 + time.minute;
  return (totalMinutes / (24 * 60)) * 2 * pi - (pi / 2);
}
```

Extend with a **minute-precise** version used for segment start/end (this is the actual fix for "everything snaps to the top of the hour"):

```dart
double _dateTimeToAngle(DateTime dt) {
  final minutesFromMidnight = dt.hour * 60 + dt.minute + dt.second / 60.0;
  return (minutesFromMidnight / (24 * 60)) * 2 * pi - (pi / 2);
}

double _sweepAngle(DialSegment s) {
  var minutes = s.end.difference(s.start).inMinutes.toDouble();
  if (minutes <= 0) minutes += 24 * 60; // midnight-spanning, see §8.1
  return (minutes / (24 * 60)) * 2 * pi;
}
```

### 6.3 No more round-cap dot artifacts

- Use `StrokeCap.butt` (flat end) for all segment arcs, not `StrokeCap.round`. Round caps only make sense for genuinely circular point markers (habit/reminder/mood glyphs), which are drawn as actual `canvas.drawCircle` badges, not as degenerate arcs. This directly removes the failure mode in §1.2 — a flat-capped arc of near-zero sweep just renders as a hairline, which is honest (barely-there segment), not a floating disc.
- Enforce a **minimum visual sweep** of ~3° for any segment under ~12 minutes purely for tap-target legibility (this is a rendering-only floor, it does not change the underlying `start`/`end` used for layering, drag, or persistence).

### 6.4 Time-until-next readout (center)

```dart
String _formatCountdown(DialSegment next, DateTime now) {
  final diff = next.start.difference(now);
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m — ${next.title}';
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return 'in ${h}h ${m}m — ${next.title}';
}
```

Shown as a third line under the `HH:mm` / date pair already in `_buildCenterReadout` (current code L62–89) — only when `snapshot.nextUpcoming != null` and `selectedDate` is today. If nothing is upcoming today, fall back to the existing today/date-only display (no layout change needed for the "nothing left today" case, just omit the third line).

---

## 7. Interaction spec — drag-to-move & edge-drag-to-resize

This is new: the current widget only supports `onTapUp` → `onHourTap` (planner_screen.dart L2212). Everything below is additive to `DayDialWidget`.

### 7.1 Gesture surface

Wrap the dial in a `GestureDetector` using **pan gestures**, not the existing single `onTapUp`, since we now need to distinguish tap vs. drag vs. edge-drag on a circular geometry:

```dart
class DayDialWidget extends StatefulWidget {
  final DayDialSnapshot snapshot;
  final DateTime selectedDate;
  final void Function(DialSegment segment)? onSegmentTap;
  final void Function(int hour)? onHourTap; // tapping empty space, unchanged behavior
  final void Function(DialSegment segment, DateTime newStart)? onSegmentMove;
  final void Function(DialSegment segment, DateTime newEnd)? onSegmentResize;
}
```

### 7.2 Hit-testing a drag start

On `onPanStart`, convert `details.localPosition` to (angle, radius) relative to center, exactly like the existing `onTapUp` handler does for angle (L36–45) plus a radius check to pick the ring, then find the `DialSegment` whose `[start,end)` contains that angle on that ring:

- If the touch lands within the **inner 15%** of a segment's angular span → **resize-start handle** (drag adjusts `start`, pushing the segment's earlier edge).
- If within the **outer 15%** → **resize-end handle** (drag adjusts `end` / duration). This is the direct radial-geometry equivalent of the existing linear-timeline "drag bottom edge to resize" handle (`timeline_day_view.dart` L999–1039) — same interaction, translated from a vertical handle to an angular one.
- If in the middle 70% → **move handle** (drag shifts the whole segment, preserving duration).
- If `segment.isEditable == false` → no drag starts at all; the segment is inert to pan gestures (still tappable).

### 7.3 Live feedback during drag (`onPanUpdate`)

Maintain local `_dragPreviewStart` / `_dragPreviewEnd` state on the segment being dragged (mirrors the existing `_localDurations` map pattern in `timeline_day_view.dart` L60, L1006–1018 — don't write to the model on every pixel of movement, only on `onPanEnd`):

- Convert the new pointer angle to a `DateTime` via the inverse of `_dateTimeToAngle`.
- **Snap to 5-minute increments** for move, **5-minute increments** for resize (configurable constant `_snapMinutes = 5`), matching typical calendar-app affordance and avoiding "I dragged it to 14:07" noise.
- Enforce a **minimum duration** of 5 minutes when resizing (clamp, don't reject).
- Render the segment being dragged with a highlighted stroke + a small tooltip bubble showing the live `HH:mm` (or `HH:mm–HH:mm` while resizing) near the pointer, so the person gets the "live visual feedback while dragging" affordance from the reference apps.

### 7.4 Commit on `onPanEnd`

Call `widget.onSegmentMove` / `widget.onSegmentResize` with the final snapped value. The **caller** (planner_screen.dart) is responsible for persistence per source type (§9), keeping the widget itself free of vault-write logic — same separation of concerns as the existing `onDurationChange` callback pattern in `timeline_day_view.dart`.

### 7.5 Google Calendar events are not draggable from the dial

Google-synced events (`googleEvents` source in §4) are rendered but `isEditable = false`. Editing a Google event's time from inside Citrine and then reconciling that back through `google_calendar_service.dart`'s sync direction is a materially different (and riskier) problem than editing a local `Task`/`Event`/`Reminder`, and is out of scope for this spec. Tapping a Google event still opens its detail (read-only) via `onSegmentTap`.

### 7.6 Habits: move-only

Because `HabitSlot` has no duration field, habit segments render `isResizable = false` — dragging the body moves `HabitSlot.time`/reminder time (writes to `ReminderConfig.timeOfDay` via the existing `HabitSlot.setPrimaryReminderTime`, already present at `habit_model.dart` L202–218), but there's no edge-resize handle at all for these — the hit-test in §7.2 should skip the inner/outer 15% zones for point-in-time segments and treat the whole glyph as a single move handle.

---

## 8. Habits, moods, and edge cases

### 8.1 Midnight-spanning segments

A segment where `end` < `start` (e.g. a Pomodoro that starts at 23:40 and runs 40 minutes, ending 00:20 the next day) must still render as a single visual arc that crosses the 12-o'clock seam. `_sweepAngle` already handles this (§6.2, `if (minutes <= 0) minutes += 24*60`). No special-casing needed elsewhere as long as every consumer computes sweep via that helper rather than `end.difference(start)` directly.

### 8.2 Habit dial position reflects the *scheduled* slot time, not actual completion time — flag this to Laura

Per the existing standing principle ("Habit reminder time ≠ completion time"), and confirmed by re-reading `habit_model.dart` while building this spec: `CompletionRecord.date` is parsed from the daily-note checklist line as a **date-only** string (`habit_model.dart` L820–823, `dateStr = line.substring(6,16)` → `YYYY-MM-DD`, no time component at all). There is currently no way to know *when* during the day a habit was actually completed — only that it was completed *that day*. So habit segments on the dial necessarily show where the habit was *supposed to* happen (`HabitSlot.primaryReminderTime`), not where it *actually* happened, exactly like the linear Planner day view already does elsewhere.

**Cross-reference for Laura:** this is the same gap that would need to close to support "log a completion after the fact at the time it really happened." Since the aromatheropy/`CatalogItem` spec already proposes extending `CompletionRecord` (adding a `linkedRef` field for the oil), this would be a natural moment to *also* add an optional `completedAt: DateTime?` to `CompletionRecord` if Laura wants the dial (and any future stats) to eventually reflect real completion time instead of slot time. Not required for this spec to ship — noted as a dependency-adjacent decision, not a blocker.

### 8.3 Mood marker resolution

```dart
static List<DialPointMarker> _buildMoodMarkers(
  List<JournalEntry> entries,
  List<MoodDefinition> catalog,
  DateTime date,
) {
  final markers = <DialPointMarker>[];
  final allDefs = [...MoodDefinition.systemMoods, ...catalog]; // catalog = user-defined custom moods, from allObjectsProvider (existing pattern in mood_chart_widget.dart)
  for (final entry in entries) {
    for (final moodEntry in entry.moodEntries) {
      if (!_isSameDay(moodEntry.timestamp, date)) continue;
      final def = allDefs.firstWhere(
        (d) => d.id == moodEntry.moodSlug,
        orElse: () => /* fallback neutral def */,
      );
      markers.add(DialPointMarker(
        id: '${entry.slug}:${moodEntry.timestamp.toIso8601String()}',
        timestamp: moodEntry.timestamp,
        emoji: def.emoji,
        label: def.label,
        sourceSlug: entry.slug,
      ));
    }
  }
  return markers;
}
```

Legacy single `moodSlug` (non-array, pre-F2.14) entries are intentionally **not** shown on the dial — they carry no timestamp, only a date, so there's no angle to place them at. This matches the existing "derived surfaces never invent data" architectural rule.

### 8.4 Too many overlapping items ("+N" overflow badge)

Covered in §5.3. Tapping the "+N" badge opens a simple bottom sheet listing the overflowed items by title/time (reusing whatever list-row component `UniversalDetailView`/`linked_objects_section.dart` already uses for compact object rows), each row tappable through to the normal detail sheet.

### 8.5 Idle/sleep band (optional, P3)

The old model had a `DialHourKind.sleep` value that nothing in the aggregator ever actually set (dead code — grep confirms no assignment site in `day_dial_aggregator.dart`). Not reintroducing this in v2 unless Laura wants a "typical sleep window" setting to render as a dimmed background band; if desired later, model it the same way as time blocks (§5.4), as a background ring rather than a competing foreground segment. Left out of the initial build.

---

## 9. Persistence write-back (`planner_screen.dart` call site)

`_buildDialView` (currently L2184–2230) needs to:

1. Pass the additional data sources into the aggregator (`localEvents`, `timeBlocks`, `journalEntries`, `moodCatalog` — all should already be available via existing providers used elsewhere in this same file/screen; wire, don't re-fetch).
2. Implement the four new callbacks:

```dart
DayDialWidget(
  snapshot: snapshot,
  selectedDate: _selectedDate,
  onHourTap: (hour) { /* unchanged existing behavior, L2212-2230 */ },
  onSegmentTap: (segment) => _openDetailFor(segment), // route by segment.kind + sourceSlug
  onSegmentMove: (segment, newStart) => _persistMove(segment, newStart),
  onSegmentResize: (segment, newEnd) => _persistResize(segment, newEnd),
)
```

### 9.1 `_persistMove` / `_persistResize` — per-kind write targets

| `segment.kind` | Move writes | Resize writes |
|---|---|---|
| `taskPlanned` | `task.scheduledTime = 'HH:mm'` of `newStart`, via existing `Task.copyWith`/vault save path | `task.duration = newEnd.difference(task's start).inMinutes` (or `estimatedMinutes` if that's the field actually driving the aggregator for this task — keep both in sync per whichever the app already treats as canonical; check `create_task_form.dart` for which field the UI edits today) |
| `pomodoroPlanned` | `session.date` (or `occurredAt`) updated | `session.workDuration` updated |
| `event` (local) | `event.startDatetime = newStart` (setter already exists, `event_model.dart` L78–81) | `event.endDatetime = newEnd` (setter already exists, L91–96) |
| `reminder` | `reminder.time = newStart` | n/a — not resizable |
| `habitSlot` | `slot.setPrimaryReminderTime(TimeOfDay.fromDateTime(newStart))` (method already exists, `habit_model.dart` L202) | n/a — not resizable |

All writes go through the same vault-save path already used by each object's respective edit screen (`create_task_form.dart`, `create_event_form.dart`, `create_reminder_form.dart`, habit edit flow) — this spec does not introduce a new persistence mechanism, it only triggers the existing one from a new UI surface.

### 9.2 Optimistic UI

Since Riverpod providers already drive `tasks`/`habits`/etc. into this screen reactively, no special optimistic-update logic should be needed beyond what `onPanEnd` → vault write → provider refresh already gives for every other edit surface in the app. Confirm this holds; if there's a perceptible lag between drop and re-render, keep the dragged segment's `_dragPreviewStart/_dragPreviewEnd` visually pinned until the provider emits the updated object, then release local state.

### 9.3 Undo

Route these writes through the existing `undo_service.dart` the same way other in-place edits do, so a drag that overshoots is a normal Ctrl/Cmd-Z-able action rather than a special case.

### 9.4 Fix the hardcoded empty reminders list

Current bug: `reminders: const []` (planner_screen.dart L2201). Replace with the real reminders provider already used elsewhere in this screen (check `reminders_screen.dart` / whatever provider backs it, e.g. a `remindersProvider`) so reminders actually reach the aggregator.

---

## 10. File-by-file implementation plan

| # | File | Action |
|---|---|---|
| 1 | `lib/models/day_dial_model.dart` | Rewrite: `DialSegmentKind`, `DialSegment`, `DialPointMarker`, `DayDialSnapshot` (§3) |
| 2 | `lib/services/day_dial_aggregator.dart` | Rewrite: `DayDialAggregator.aggregateForDate` returns `DayDialSnapshot`; per-source `_ingestX` helpers (§4); `_assignLayers` (§5.2); `_buildMoodMarkers` (§8.3) |
| 3 | `lib/ui/widgets/day_dial_widget.dart` | Rewrite: multi-ring `CustomPainter`, minute-precise angle math (§6.2), flat stroke caps (§6.3), countdown readout (§6.4), pan-gesture drag/resize (§7) |
| 4 | `lib/ui/screens/planner_screen.dart` | Update `_buildDialView` (§9): new provider wiring, new callbacks, fix `reminders: const []` |
| 5 | `lib/models/day_theme_model.dart` | **Read this file first** (it returned empty/404 during this spec's research — confirm its real path/shape) before implementing §5.4's Day Theme ring |
| 6 | *(new, optional)* `lib/models/habit_model.dart` | If Laura confirms the §8.2 cross-reference, add `DateTime? completedAt` to `CompletionRecord` in the same PR as the aromatheropy `CompletionRecord` extension — not required for this spec alone |

Suggested build order: #1 → #2 → #3 (core rebuild, ships overlap + drag + countdown) → #4 (wiring) → #5 (time blocks/day themes, P2) → #6 (only if Laura opts in).

---

## 11. Open questions for Laura

1. **Day Theme shape** — `day_theme_model.dart` came back empty when fetched for this spec (404 or genuinely 0 bytes at that path). Please confirm the real path/fields before §5.4's Day Theme ring is built, or point me at the right file.
2. **Task duration vs. `estimatedMinutes`** — which field should edge-drag-resize actually write for a `Task`? Both exist; need to confirm which one the rest of the app already treats as the source of truth for a task's on-dial length, to avoid writing to a field nothing else reads.
3. **`completedAt` on `CompletionRecord`** (§8.2) — worth bundling into the aromatherapy PR, or keep habit segments showing scheduled-slot time indefinitely?
4. **Layer cap of 4** (§5.3) — acceptable, or would you rather the dial scroll/zoom into a busy window instead of showing a "+N" overflow badge? (Zoom is a materially bigger feature — flagging so it's a conscious choice, not a default.)
5. **Sleep/idle band** (§8.5) — wanted now, or fine to leave out until there's a concrete "typical sleep window" setting elsewhere in the app?

---

## 12. Acceptance criteria

- [ ] Two items in the same hour (e.g. a habit reminder and a 15-minute Pomodoro block) both render as distinct, correctly-positioned segments — no overwrite, no orphan dots.
- [ ] A meeting scheduled inside a time block renders as two separate rings (block background + meeting arc), both visible simultaneously.
- [ ] Five or more overlapping items in the same window render across the 4-ring cap plus a tappable "+N" badge, not off-screen or dropped.
- [ ] Dragging the body of an editable segment changes its start time in 5-minute snapped increments and persists on release; dragging its outer edge changes its duration the same way.
- [ ] Google Calendar events and completed Pomodoro sessions are visible but inert to drag gestures.
- [ ] Habit segments show their emoji and can be moved but not resized.
- [ ] Mood entries from today render as emoji point-markers at their actual timestamp, are tappable, but not draggable.
- [ ] Center readout shows current time + date, and — when something is scheduled later today — a third line with time-remaining + title of the next item.
- [ ] A segment crossing midnight renders as one continuous arc across the 12 o'clock seam, not two disconnected pieces.
- [ ] `reminders` reaching the aggregator are the real provider data, not an empty list.

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

# Time-Blocking UX Improvements & Circular Day Dial — Implementation Spec

**Status:** Draft for review
**Scope:** Planner timeline UX (Part A) + circular day dial widget and Windows companion (Part B)
**Related files:** `lib/ui/screens/planner_screen.dart`, `lib/ui/widgets/timeline_day_view.dart`, `lib/ui/widgets/time_block_picker.dart`, `lib/services/widget_service.dart`, `lib/models/habit_model.dart`, `lib/models/pomodoro_session.dart`, `lib/models/event_model.dart`, `lib/models/task_model.dart`

---

## Background

Two research inputs informed this spec:

1. A survey of 2026 time-blocking apps (Sunsama, Morgen, Akiflow, Motion, ClickUp, Google Calendar, Doobies) to benchmark the Planner's drag-and-drop timeline against category leaders.
2. Reassign (`reassign.ai`), a circular "day-shaped" planner, plus a Reddit discussion (r/ProductivityApps) arguing that conventional time-blocking treats every hour as equal, ignoring that personal energy fluctuates through the day. Reassign addresses this with an assumed circadian "body clock." Citrine already has real per-user energy data via the mood system's 2-axis model (energy/pleasantness), which is a stronger foundation than an assumed body clock — this is called out explicitly in Part B as a differentiator, not just feature parity.

---

## Part A — Timeline / time-blocking UX improvements

### A.1 Current state (verified against source)

`TimeLineDayView` already implements a solid core:
- 30-minute drop-target grid (`_buildDropTargets`) accepting drag from backlog/agenda
- Resize via drag on the block's bottom edge (duration change)
- Reschedule by dragging an already-placed block to a new time (`LongPressDraggable` wraps the block itself)
- Automatic column-splitting for overlapping items (`column` / `totalColumnsInGroup`)
- Current-time indicator (`_buildCurrentTimeIndicator`)
- Time Block (routine) color bands behind the grid (`_buildTimeBlockBands`)
- Google Calendar events rendered in the same timeline

This is materially ahead of a "basic" implementation — the gaps below are about density, feedback, and closing the loop between plan and reality, not missing fundamentals.

### A.2 Identified gaps

| # | Gap | Evidence | Comparable in market |
|---|---|---|---|
| G1 | `colorMode: 'category'` does not actually vary by category — always renders `AppColors.secondary` | `_buildTaskBlock`, colorMode branch | Every competitor uses category color as the primary visual anchor |
| G2 | No persistent unscheduled-tasks tray next to the timeline; backlog is a modal | `planner_screen.dart` backlog bottom sheet | Sunsama/Akiflow/Morgen: sidebar + calendar side by side |
| G3 | No way to create a new task/block directly on an empty timeline cell | timeline only positions existing items | Trello Planner, ClickUp: click-drag on empty grid creates the item |
| G4 | Timeline always opens scrolled to 00:00, no "jump to now" | Day view init | Sunsama/Google Calendar center on current time |
| G5 | Drop feedback is a time-label pill, not a size-accurate ghost block | `_buildDropTargets` visual feedback | Morgen/Trello show a ghost block matching final duration |
| G6 | Fixed 30-min grid, no zoom/density control | `hourHeight` constant = 80 | Motion/Akiflow support 15-min granularity |
| G7 | Week view is a list of cards, not a time grid | `_buildWeekView` | Every competitor's default view is a weekly time grid |
| G8 | No plan-vs-actual overlay despite having the data (Pomodoro sessions, reflection prompts) | `pomodoro_session.dart`, `_showReflectionPrompt` exist but aren't visualized on the timeline | Doobies' core differentiator; nobody else in the survey has it |

### A.3 Prioritized backlog

| Ticket | Description | Priority | Effort | Files touched |
|---|---|---|---|---|
| TB-1 | Fix category color mode: derive block color from the task's linked Organizer/Area instead of a fixed enum | P0 | S | `timeline_day_view.dart` |
| TB-2 | Replace backlog modal with a persistent unscheduled-tasks panel (side drawer on tablet/desktop, retractable bottom strip on mobile) visible while the timeline is open | P1 | M | `planner_screen.dart`, new widget |
| TB-3 | Long-press on an empty grid cell opens `CreateTaskForm` with `initialDate`/`initialTime` pre-filled | P1 | M | `timeline_day_view.dart`, `create_task_form.dart` |
| TB-4 | Auto-scroll timeline to current time on open; add "jump to now" FAB when scrolled away | P2 | S | `timeline_day_view.dart` |
| TB-5 | Ghost-block drag preview sized to actual duration instead of a time pill | P2 | S | `timeline_day_view.dart` |
| TB-6 | 15-minute grid granularity with a density toggle (15/30/60 min) | P2 | M | `timeline_day_view.dart` |
| TB-7 | Rebuild week view as a 7-column mini time grid (read-only acceptable for v1; drag-and-drop optional in v2) | P2 | L | `planner_screen.dart` |
| TB-8 | Plan-vs-actual overlay: render actual Pomodoro session duration/timing as a secondary marker against the planned block | P1 | L | `timeline_day_view.dart`, `pomodoro_session.dart` |

**Acceptance criteria — TB-1**
- Given a task linked to an Organizer with a defined color, when `colorMode == 'category'`, the block renders that Organizer's color, not `AppColors.secondary`.
- Tasks with no linked Organizer fall back to a neutral gray, not silently to the priority color.

**Acceptance criteria — TB-8**
- After a Pomodoro session tied to a task completes, the timeline shows a thin secondary band inside/adjacent to the planned block spanning the session's actual start/end.
- If actual time exceeds planned duration, the overflow is visually distinguishable (e.g. band extends past the block edge with a different opacity).
- No historical data is rewritten — this is a read-only overlay computed at render time from `pomodoro_session.dart` records, consistent with the existing rule that daily-note snapshots are never live references.

---

## Part B — Circular day dial

### B.1 Concept

A 24-hour circular dial (midnight at top, noon at bottom, clockwise) rendered as a `CustomPainter`, showing in one glance:
- **Habit icons** placed at their scheduled hour, on an icon ring
- **Hour arcs** colored by state: completed Pomodoro time, planned/scheduled Pomodoro time not yet done, calendar events, and idle/sleep hours
- **Current-time marker** on the ring
- **Center readout**: current time

A working visual mockup was produced during this conversation to validate the geometry (hour → angle mapping, donut-wedge arcs, icon placement) — the math is plain trigonometry and translates directly to Flutter's `Canvas`/`Path` APIs (`drawArc`, `Path.arcTo`).

### B.2 Differentiator: real energy data instead of an assumed body clock

Reassign's circadian layer assumes a generic energy curve based on typical sleep patterns. Citrine already has **actual historical energy data** per time-of-day via the mood system's 2-axis model (`energy` + `pleasantness` fields on `MoodDefinition`, logged through `mood_entries`). This means the dial can eventually render a background gradient reflecting this user's real recorded energy-by-hour instead of a guessed pattern — a genuine differentiator, not parity. This is called out as a v2 enhancement (see B.5); v1 focuses on habits/Pomodoro/events only, since that data pipeline already exists cleanly.

### B.3 Data aggregation layer (the real work)

The dial itself is a rendering problem; the work is producing a clean per-hour summary before it reaches the painter. Proposed model:

```dart
class DayDialHourState {
  final int hour; // 0-23
  final DialHourKind kind; // sleep, pomodoroCompleted, pomodoroPlanned, event, idle
  final double fillFraction; // 0.0-1.0, how much of this hour is covered
  final String? habitIconName; // set only if a habit is scheduled at this hour
  final String? habitId;
}

enum DialHourKind { idle, sleep, pomodoroCompleted, pomodoroPlanned, event }
```

A new `DayDialAggregator` service builds `List<DayDialHourState>` (length 24) for a given date by combining:
- `pomodoro_session.dart` records for that date → `pomodoroCompleted` where a session's actual start/end overlaps the hour
- `task_model.dart` entries with a scheduled time + `estimatedMinutes` but no completed Pomodoro session yet → `pomodoroPlanned`
- `event_model.dart` (including synced Google Calendar events) → `event`
- `habit_model.dart` entries with a fixed scheduled time → sets `habitIconName`/`habitId` on the relevant hour, independent of the `kind` fill

This mirrors the existing pattern used by `kpi_engine.dart` and `dataview_generator.dart` (aggregating across object types into a derived view) rather than introducing a new architectural pattern.

### B.4 Rendering — mobile

- New widget `lib/ui/widgets/day_dial_widget.dart`, a `CustomPainter` consuming `List<DayDialHourState>`
- Reused inside `planner_screen.dart` as an optional alternate view mode alongside the existing linear timeline (not a replacement — the linear timeline remains the primary editing surface; the dial is a glanceable summary/entry point)
- Tapping a wedge or icon navigates to that hour in the linear timeline

### B.5 Windows companion — architecture options

The existing `widget_service.dart` uses the `home_widget` package, which binds to Android's `AppWidgetProvider` and iOS's WidgetKit. **There is no Windows equivalent in this package or architecture** — Windows 11's Widgets Board is a separate native surface (Adaptive Cards, C++/C#/WinUI) that Flutter does not target. Building a Windows presence is a new subsystem, not an additional provider. Three options, evaluated for fit with the existing single-developer Flutter/Dart stack:

| Option | Description | Fit | Trade-off |
|---|---|---|---|
| **1. Flutter Windows desktop companion (recommended)** | Small always-on-top, borderless, circular Flutter desktop window (Flutter's Windows desktop target) reusing `day_dial_widget.dart` and the vault-reading logic directly | High — same codebase, same language, reuses B.4's painter unmodified | Not a true OS-level widget; doesn't live in the Windows Widgets Board, just a floating desktop window |
| **2. Native Windows Widgets Board provider** | Separate C#/WinUI project rendering an Adaptive Card from a JSON snapshot exported by Citrine | Low — new language/toolchain to maintain long-term | Correct integration point, but a second codebase |
| **3. Rainmeter skin** | Lua/skin config reading an exported JSON snapshot, rendered by Rainmeter | Medium — no C#, but Rainmeter-specific skill | Feels less "native," dependent on a third-party tool being installed |

**Recommendation:** Option 1. It reuses `DayDialAggregator` and `day_dial_widget.dart` unchanged, requires no new language, and can be built incrementally (start with a static snapshot refreshed on a timer, add live vault-watching later if the vault folder is locally accessible on the Windows machine — e.g. via the same cloud-synced folder used for Drive sync).

### B.6 Backlog — Part B

| Ticket | Description | Priority | Effort | Files |
|---|---|---|---|---|
| DD-1 | `DayDialAggregator` service producing `List<DayDialHourState>` for a given date | P1 | M | new `lib/services/day_dial_aggregator.dart` |
| DD-2 | `DayDialWidget` (`CustomPainter`) rendering habit icons, hour arcs, current-time marker, center readout | P1 | M | new `lib/ui/widgets/day_dial_widget.dart` |
| DD-3 | Wire dial as an alternate Planner view mode with tap-to-navigate to linear timeline hour | P2 | S | `planner_screen.dart` |
| DD-4 | Flutter Windows desktop target enabled for the project; minimal always-on-top borderless window shell | P2 | M | new `windows/` platform folder, `main.dart` entry variant |
| DD-5 | Windows companion reads vault directly (if local) or from a periodic JSON snapshot exported by the mobile app; renders `DayDialWidget` | P2 | L | new companion entry point reusing DD-1/DD-2 |
| DD-6 (v2, deferred) | Background energy gradient on the dial sourced from historical `mood_entries` energy values by hour-of-day | P3 | L | `day_dial_aggregator.dart`, mood system |

**Acceptance criteria — DD-1**
- Given a date, returns exactly 24 `DayDialHourState` entries, one per hour, with no gaps.
- An hour with both a completed Pomodoro session and a scheduled habit sets both `kind = pomodoroCompleted` and `habitIconName`, since these are independent axes (fill vs. icon marker), not mutually exclusive.
- `fillFraction` reflects partial-hour coverage (e.g. a 20-minute Pomodoro session within an hour → `fillFraction = 0.33`), never clamped to 0/1 only.

**Acceptance criteria — DD-4/DD-5**
- Companion window has no title bar, no OS chrome, stays on top, and its background is transparent outside the dial's circular silhouette.
- If the vault folder is not accessible locally, the companion falls back to reading the most recent exported snapshot without crashing, and shows a subtle "stale data" indicator if the snapshot is older than a configurable threshold (default 15 minutes).

---

## Open questions

1. For TB-2 (persistent unscheduled panel): drawer on tablet/desktop, retractable strip on mobile — confirm this split is acceptable, or should mobile get a different pattern entirely (e.g. a pull-up sheet that stays partially visible)?
2. For DD-5: is the Obsidian vault folder expected to be locally synced on the Windows machine (e.g. via existing Drive sync), or should the Windows companion always go through an exported snapshot regardless?
3. For DD-6: should energy-gradient data require a minimum number of historical mood entries for a given hour before rendering (to avoid a misleading gradient from sparse data)?


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

================================================================================
DOCUMENTO DE PEDIDOS — APLICATIVO (Flutter / Riverpod)
Data: 28/06/2026
================================================================================

--------------------------------------------------------------------------------
PEDIDO 1 — RECONHECIMENTO DE LINKS DO IMDB EM RESOURCES [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Quando a usuária compartilhar um link do IMDb (app ou site) para um filme ou
série, o app deve reconhecer automaticamente a URL, preencher os metadados
relevantes (título, ano, tipo, sinopse, poster) e criar o Resource com o tipo
correto ("Movie" ou "Series").

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/forms/create_resource_form.dart
  → Já faz isso para Google Books via `ResourceMetadataService`.
  → Ponto de entrada: campo de URL + botão de fetch (_isFetchingUrl, _fetchError,
    _sourceUrl, _sourceName).
- lib/services/resource_metadata_service.dart (arquivo mencionado no form mas
  não listado — é onde a lógica de fetch de metadados deve viver ou já existe).
- lib/models/resource_model.dart
  → Já tem campo `googleBooksId`. Precisa de campo equivalente: `imdbId`.

O QUE MUDAR

1. resource_model.dart
   - Adicionar campo: `String? imdbId;`
   - Incluir no construtor, toMap() e fromMap().

2. resource_metadata_service.dart (criar ou editar)
   - Detectar se a URL contém "imdb.com/title/" (site) ou se o deep-link do app
     IMDb redireciona para esse padrão.
   - Extrair o IMDb ID: regex `tt\d+` da URL.
   - Fazer fetch dos metadados via OMDb API (omdbapi.com — requer API key
     configurável nas settings) ou via scraping do Open Graph da página do IMDb.
   - Retornar: title, year, type (movie → "Movie", series → "Series"),
     plot/sinopse, poster URL, genre.

3. create_resource_form.dart
   - Na função que checa o clipboard e processa URL colada (mesma lógica do
     Google Books), adicionar detecção de IMDb:
     `if (url.contains('imdb.com')) { fetchImdb(url); }`
   - Preencher automaticamente: _titleController, _yearController,
     _synopsisController, _coverUrlController, _resourceType ("Movie"/"Series"),
     e o novo campo imdbId.
   - Mostrar badge/chip "Fonte: IMDb" igual ao que já existe para Google Books.

UI/UX
- Mesma experiência já existente para Google Books: banner "Link do IMDb
  detectado" → spinner de loading → campos preenchidos automaticamente.
- O campo resourceType deve mudar para "Movie" ou "Series" automaticamente.
- Se o fetch falhar, mostrar mensagem de erro amigável e deixar campos editáveis.
- Nenhuma tela nova necessária — tudo ocorre no form existente.

--------------------------------------------------------------------------------
PEDIDO 2 — ANÁLISE DE CRASH LOGS / PERFORMANCE [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Identificar e corrigir os gargalos que estão deixando o app lento e causando
travamentos, a partir da análise dos crash logs existentes na tela de
Diagnostic Reports.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/services/crash_report_service.dart → coleta e armazena os relatórios.
- lib/ui/screens/diagnostic_reports_screen.dart → tela que exibe os logs.
- lib/providers/vault_provider.dart → provavelmente o maior suspeito; é onde
  ficam os providers reativos que escutam o vault inteiro.
- lib/providers/vault_isolate.dart → parsing feito em isolate; verificar se
  está sendo usado corretamente.
- lib/services/sync_manager.dart / sync_queue_service.dart → operações de sync
  podem bloquear a UI thread.
- lib/services/search_service.dart → buscas sem debounce podem causar jank.

O QUE FAZER

1. Ler os logs em diagnostic_reports_screen.dart e identificar os stack traces
   mais frequentes.

2. Suspeitos comuns a verificar:
   a) vault_provider.dart: checar se há providers recalculando desnecessariamente
      (usar `select` em vez de `watch` quando possível).
   b) vault_isolate.dart: garantir que todo parsing de Markdown/JSON pesado
      está no isolate, não na main thread.
   c) Imagens: checar se coverImages dos Resources e social posts estão usando
      cache (cached_network_image). Se não, adicionar.
   d) CollectionEditor / OutlineEditor: verificar se rebuild está sendo
      disparado a cada keystroke em toda a árvore.
   e) sync_queue_service: operações de escrita devem ser enfileiradas e nunca
      bloquear setState.
   f) Search: adicionar debounce de ~300ms no search_service ou nos controllers
      de busca das screens.

3. Cada correção deve ser isolada e testável individualmente.

UI/UX
- Nenhuma mudança visual para o usuário final, apenas melhorias de performance.
- Opcionalmente: adicionar indicador de "Syncing…" não-bloqueante (já pode
  existir via sync_provider) em vez de operações que travam a tela.

--------------------------------------------------------------------------------
PEDIDO 3 — BOTÃO DE ADD ORGANIZER NA TELA ORGANIZER [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
O botão "Add organizer" na tela de detalhe do Organizer está desatualizado
porque cada tipo de objeto tem seu próprio form de criação. Em vez de manter
um botão com lógica duplicada, substituir por botões diretos que redirecionam
para o form de add correto — assim qualquer mudança nos forms é refletida
automaticamente.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/screens/organizer_detail_screen.dart → tela principal a modificar.
- lib/ui/forms/create_task_form.dart, create_note_form.dart, create_goal_form.dart,
  create_habit_form.dart, create_resource_form.dart, create_event_form.dart,
  create_reminder_form.dart, create_project_form.dart, create_person_form.dart,
  etc. → os forms de destino.

O QUE MUDAR

Em organizer_detail_screen.dart:
- Remover o botão/lógica atual de "Add organizer" que tenta duplicar o form.
- Adicionar uma seção "Adicionar ao organizador" com botões/chips para cada
  tipo de objeto suportado:
    [+ Tarefa] [+ Nota] [+ Objetivo] [+ Hábito] [+ Recurso] [+ Evento]
    [+ Lembrete] [+ Projeto] [+ Pessoa] ...
- Cada botão abre o form correspondente passando o organizador atual como
  parâmetro pré-selecionado (os forms já aceitam `initialOrganizers` ou
  equivalente).
- Não criar lógica de salvamento local — deixar o form fazer isso.

UI/UX
- Os botões ficam em uma linha horizontal scrollável (ou grade 2 colunas) no
  final da tela de detalhe do organizer, abaixo da lista de itens vinculados.
- Estilo: chips com ícone + label, cor secundária (não destaque), tamanho
  compacto.
- Ao voltar do form, a lista de itens do organizer deve atualizar automaticamente
  via Riverpod (ref.watch já cuida disso se o provider for o correto).
- Nenhuma tela nova necessária.

--------------------------------------------------------------------------------
PEDIDO 4 — TELA DE GOALS VAZIA APÓS DESCARTAR CRIAÇÃO [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Quando a usuária começa a criar um goal e descarta (sem salvar), a tela Goals
fica em estado vazio mesmo havendo goals existentes. Bug de estado.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/screens/goals_screen.dart → suspeita principal.
- lib/providers/vault_provider.dart → `goalsProvider`.
- lib/ui/forms/create_goal_form.dart → o form que ao ser descartado pode estar
  afetando o estado.

O QUE INVESTIGAR E CORRIGIR

1. Verificar se create_goal_form.dart modifica o provider antes de confirmar
   (ex.: chama `addGoal` provisoriamente e não faz rollback ao descartar).
   → Se sim: mover a chamada de `addGoal` para apenas o momento do Save, nunca
     antes.

2. Verificar se goals_screen.dart usa um provider local/temporário que fica
   "sujo" após navegação.
   → Se sim: garantir que o `ref.watch(goalsProvider)` aponte para a fonte
     de verdade do vault, não um estado local.

3. Verificar se ao fechar o form via `Navigator.pop` sem retorno, a tela pai
   não está interpretando o `null` como "lista vazia".
   → Padrão correto: goals_screen não deve depender do retorno da rota do form;
     deve reobservar o provider.

4. Adicionar `ref.invalidate(goalsProvider)` ou equivalente no dispose do form
   se necessário para forçar recarga.

UI/UX
- Nenhuma mudança visual. O comportamento esperado é: descartar o form → voltar
  para goals_screen com a lista exatamente como estava antes de abrir o form.

--------------------------------------------------------------------------------
PEDIDO 5 — BOTÃO + DEVE MOSTRAR TODOS OS FORMS DE ADD [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
O menu de criação rápida (botão +, implementado em create_menu_sheet.dart) não
lista todos os tipos de objeto. Especificamente faltam: Organizers, Hábito (add
de hábito existente), Record em hábito existente, e possivelmente outros.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/widgets/create_menu_sheet.dart → o sheet do botão +.
  Abas atuais: Journal (0), Plan (1), Record (2), Note (3).
  Faltam: Organizer, Habit, Resource, Project, Person, Shopping Item, Social Post,
  Snapshot, Tracker, Template, etc.

O QUE MUDAR

1. Auditoria completa: listar todos os forms em lib/ui/forms/ e comparar com o
   que aparece em create_menu_sheet.dart.
   Forms existentes NÃO presentes no menu +:
   - create_organizer_form.dart → Organizer
   - create_habit_form.dart → Hábito
   - create_resource_form.dart → Resource
   - create_project_form.dart → Projeto
   - create_person_form.dart → Pessoa
   - create_social_post_form.dart → Post Social
   - create_snapshot_form.dart → Snapshot
   - create_tracker_form.dart → Tracker (pode já estar, verificar)
   - create_template_form.dart → Template
   - create_shopping_item → item de lista de compras
   - create_scan_document_form.dart → Documento escaneado

2. Adicionar aba(s) ou seção(ões) no create_menu_sheet.dart para cobrir os
   tipos faltantes. Sugestão de organização:
   - Aba "Capture" (já existe parcialmente): Journal + Note + Idea
   - Aba "Plan": Task + Habit + Goal + Reminder + Event + Project
   - Aba "Organize": Organizer + Person + Resource + Tracker + Template
   - Aba "Record": Record de tracker/hábito existente + Snapshot

3. Para "Add record num hábito que já existe": a aba Record deve listar os
   hábitos ativos e permitir registrar um check/valor diretamente, sem abrir
   o form completo (UX rápida: tap no hábito → registra agora).

UI/UX
- O sheet já tem tabs horizontais no topo. Manter esse padrão e adicionar tabs.
- Cada item dentro da aba: ícone + label, em grid 2 colunas ou lista compacta.
- Itens de uso mais frequente (Task, Journal Entry, Habit check) ficam no topo
  ou em posição de destaque.
- Scroll vertical dentro de cada aba se houver muitos itens.

--------------------------------------------------------------------------------
PEDIDO 6 — BOTÃO VOLTAR SEMPRE NAVEGA ATÉ A HOME, SEM SAIR DO APP [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Ao pressionar o botão Voltar (Android back gesture ou botão físico), o app deve
navegar para a tela anterior dentro do app, e nunca sair/fechar o app. A
navegação deve funcionar como pilha: tela C → tela B → tela A → Home, e na
Home o botão Voltar não faz nada (ou exibe "Pressione novamente para sair").

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/main.dart → onde o GoRouter é configurado.
- lib/ui/shell/app_shell.dart → o shell de navegação com bottom bar.
- lib/ui/navigation/object_navigation.dart → helpers de navegação.

O QUE MUDAR

1. No GoRouter (main.dart ou onde estiver a config de rotas):
   - Garantir que todas as telas de detalhe (universal_detail_view, forms,
     screens de objetos) estejam como sub-rotas (ShellRoute ou rotas filhas)
     e não como rotas raiz independentes, para que o GoRouter mantenha pilha.

2. No app_shell.dart:
   - Envolver com `PopScope` (Flutter 3.x) ou `WillPopScope` (legado):
     ```dart
     PopScope(
       canPop: false,
       onPopInvoked: (didPop) {
         if (didPop) return;
         if (router.canPop()) {
           router.pop();
         } else {
           // Na home: mostrar snackbar "Pressione novamente para sair"
           // ou não fazer nada
         }
       },
       child: ...
     )
     ```

3. Verificar todas as telas que usam `Navigator.push` em vez de `context.push`
   do GoRouter — essas criam pilhas desconectadas. Padronizar para GoRouter.

4. Em cada form/detalhe que abre via `showModalBottomSheet` ou
   `showDialog`: o botão X/fechar deve chamar `Navigator.pop(context)` e
   nunca `context.go(...)` (que reseta a pilha).

UI/UX
- Comportamento esperado: totalmente transparente para a usuária — "Voltar"
  simplesmente funciona como esperado em qualquer app mobile.
- Na Home (root): botão voltar não fecha o app; pode mostrar toast
  "Toque novamente para sair" com timer de 2s.

--------------------------------------------------------------------------------
PEDIDO 7 — REMOVER TUDO RELACIONADO A MAPA [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Eliminar completamente qualquer funcionalidade, UI ou referência a mapas no app
(campo de localização, widgets de mapa, PlaceRef, etc.).

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/models/place_ref.dart → modelo de referência de lugar; deletar ou esvaziar.
- Qualquer model que tenha campo `PlaceRef? location` ou similar:
  verificar content_object.dart, event_model.dart, journal_entry.dart,
  people_model.dart, organizer_model.dart.
- Qualquer form que tenha campo "Local" ou "Localização":
  create_event_form.dart, create_person_form.dart, create_entry_form.dart, etc.
- Qualquer widget de mapa (flutter_map, google_maps_flutter, etc.) que possa
  existir nos widgets.
- lib/services/permission_service.dart → remover permissão de localização se
  existir.
- pubspec.yaml → remover dependências de mapa (flutter_map, latlong2,
  google_maps_flutter, geolocator, etc.).

O QUE FAZER

1. Buscar no código por: `PlaceRef`, `location`, `latitude`, `longitude`,
   `flutter_map`, `google_maps`, `geolocator`, `MapWidget`, `LatLng`.
2. Remover campos dos models (sem quebrar fromMap/toMap — ignorar o campo se
   vier de arquivos Obsidian antigos).
3. Remover campos dos forms (UI de "Local" → deletar completamente).
4. Remover dependências do pubspec.yaml.
5. Remover permissões de localização do AndroidManifest.xml e Info.plist.

UI/UX
- Nenhuma tela nova. Os forms ficam mais simples sem o campo de local.
- Verificar se alguma tela exibia um mapa inline (ex.: detalhe de evento com
  mapa) — substituir por nada ou por texto de endereço simples se necessário.

--------------------------------------------------------------------------------
PEDIDO 8 — TELA DE POMODORO: OVERFLOWS + AGENDAMENTO + PLANNER [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Corrigir overflows visuais na tela de Pomodoro, fazer o seletor de quantidade
de sessões funcionar corretamente (mostrando horas/ciclos/pausas calculados),
permitir vincular qualquer objeto ao pomodoro agendado, mostrar pomodoros
agendados de forma discreta no Planner, e adicionar botão de play tanto no
Planner quanto ao clicar num pomodoro agendado.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/screens/pomodoro_screen.dart → tela principal; overflows aqui.
- lib/providers/pomodoro_provider.dart → estado do timer e sessões.
- lib/models/pomodoro_session.dart → modelo da sessão agendada.
- lib/ui/screens/planner_screen.dart → onde pomodoros agendados aparecem.
- lib/ui/widgets/pomodoro_floating_clock.dart → o popup/overlay.
- lib/ui/widgets/pomodoro_week_overview.dart → visão semanal.
- lib/ui/widgets/dashboard/pomodoro_summary_block.dart → bloco do dashboard.
- lib/ui/widgets/universal_search_picker.dart → já usado no form para vincular
  objetos; usar aqui também.

O QUE MUDAR

A) OVERFLOWS — pomodoro_screen.dart
   - Identificar widgets com overflow (provavelmente Row com textos longos ou
     botões de sessão).
   - Envolver textos com `Flexible` ou `Expanded`.
   - Usar `FittedBox` ou `overflow: TextOverflow.ellipsis` onde necessário.
   - Testar em telas pequenas (375px largura).

B) SELETOR DE QUANTIDADE DE POMODOROS
   - O seletor (_sessionCount, atualmente int) já existe mas a UI descritiva
     não atualiza.
   - Criar widget `_buildSessionSummary(int count)` que exibe:
     * Pomodoros: `count`
     * Pausas curtas: `count - 1`
     * Pausa longa: `1` (a cada 4 pomos)
     * Duração total: `count * 25min + (count-1) * 5min + 15min` (configurável
       via settings de duração de pomo).
   - Chamar `setState` ao mudar o seletor para reatualizar esse resumo.
   - O resumo fica logo abaixo dos botões de seleção de quantidade, em card
     com fundo levemente destacado.

C) VINCULAR QUALQUER OBJETO AO POMODORO AGENDADO
   - Em pomodoro_session.dart: garantir que há campo `String? linkedObjectId`
     e `String? linkedObjectType`.
   - No form de agendamento de pomodoro dentro de pomodoro_screen.dart:
     adicionar campo "Vincular a..." que abre o UniversalSearchPicker
     (já existe em lib/ui/widgets/universal_search_picker.dart).
   - O objeto vinculado aparece como chip abaixo do campo após seleção.

D) POMODOROS NO PLANNER — visual discreto + play
   - Em planner_screen.dart, onde os pomodoros agendados são exibidos:
     * Estilo: card com fundo semi-transparente, borda pontilhada, ícone de
       tomate 🍅, texto com horário e título do objeto vinculado.
     * Opacidade ~70% para não competir com tarefas reais.
   - Adicionar botão de play (ícone `play_arrow_rounded`) no card do pomodoro
     agendado no Planner que inicia o timer diretamente.
   - O play chama `pomodoroProvider.notifier.start()` e navega para
     pomodoro_screen (ou abre o floating clock).

E) ÍCONE DE PLAY AO CLICAR NO POMODORO AGENDADO
   - Ao tocar no card do pomodoro agendado (no Planner ou em outra tela):
     abrir bottom sheet com opções:
     [▶ Iniciar agora] [✏️ Editar] [🗑 Excluir]
   - "Iniciar agora" dispara o timer e fecha o sheet.

UI/UX GERAL — POMODORO
- Cores: manter o esquema atual (vermelho tomate para work, azul para break).
- O resumo de sessões deve ser imediatamente legível: "4 pomodoros · 3h20 · 3
  pausas curtas · 1 pausa longa".
- O botão de play no Planner é pequeno (IconButton, tamanho 32px) no canto
  direito do card, não dominante.

--------------------------------------------------------------------------------
PEDIDO 9 — FLOATING CLOCK (OVERLAY SOBRE OUTROS APPS) [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
O botão de popup do Pomodoro deve ser apenas um relógio animado (mostrando o
tempo restante) que flutua sobre qualquer app. A usuária pode arrastar para
reposicionar e arrastar para baixo para fechar/remover da tela.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/widgets/pomodoro_floating_clock.dart → implementação atual.
- lib/ui/screens/pomodoro_screen.dart → botão que ativa o overlay
  (`picture_in_picture_alt_rounded`).
- lib/providers/pomodoro_provider.dart → fonte do tempo restante.
- lib/services/pomodoro_bg_service.dart → serviço de background.
- Para overlay sobre outros apps no Android: requer permissão
  `SYSTEM_ALERT_WINDOW` + plugin (ex.: `flutter_overlay_window`).

O QUE MUDAR

1. Visual do floating clock:
   - Formato: círculo pequeno (~72px diâmetro) com fundo escuro semi-transparente.
   - Conteúdo: apenas o tempo restante (MM:SS) em fonte monoespaçada branca.
   - Borda animada (arco que vai diminuindo conforme o tempo passa, como um
     timer circular).
   - SEM botões de play/pause no overlay — é só visual.

2. Interação de arrastar para mover:
   - Usar `GestureDetector` com `onPanUpdate` para mover a posição do overlay.
   - Salvar posição em estado local (não persistir).
   - Limitar ao bounds da tela (não deixar sair das bordas).

3. Arrastar para baixo para fechar:
   - Detectar quando o usuário arrasta o widget para além de ~80% da altura
     da tela (zona inferior).
   - Ao entrar na zona: mostrar ícone de lixeira/X no fundo da tela.
   - Ao soltar na zona: fechar o overlay (`overlayEntry.remove()`).
   - Animação de saída: fade out + scale down.

4. Overlay sobre outros apps (Android):
   - Usar `flutter_overlay_window` ou `system_alert_window`.
   - Pedir permissão quando o usuário toca no botão pela primeira vez.
   - iOS: PiP nativo não é possível para timers customizados; nesses casos
     manter o overlay apenas dentro do app (usando `OverlayEntry` padrão do Flutter).

5. Atualização em tempo real:
   - O overlay deve escutar o `pomodoroProvider` e atualizar o tempo a cada
     segundo sem causar rebuild da tela inteira.

UI/UX
- O overlay é minimalista: só o número. Sem título, sem ícones extras.
- Cor de fundo: preto com ~80% de opacidade, bordas arredondadas (borderRadius 36).
- Quando arrastando para fechar: overlay fica com opacidade reduzida e aparece
  zona de drop no fundo da tela (fundo vermelho semi-transparente com ícone X).

--------------------------------------------------------------------------------
PEDIDO 10 — DAY THEMES E BLOCKS NA MESMA TELA / UM BOTÃO SÓ NO MORE [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Day Themes e Day Blocks são funcionalidades relacionadas que estão separadas
com dois botões diferentes na tela More. Unificar em uma única entrada "Day
Themes & Blocks" que abre uma tela com abas para ambas.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/screens/more_screen.dart → tem dois botões separados para
  /day-themes e /day-blocks, ambos apontando para DayThemeScreen.
- lib/ui/screens/day_theme_screen.dart → tela atual; verificar se já tem
  suporte a blocks ou se blocks estão em outra tela.
- lib/providers/day_theme_provider.dart → provider dos temas.
- lib/models/day_theme_model.dart, dashboard_block.dart → models relevantes.
- main.dart / router → remover rota /day-blocks separada se existir.

O QUE MUDAR

1. more_screen.dart:
   - Remover os dois botões separados de Day Themes e Day Blocks.
   - Adicionar um único botão "Day Themes & Blocks" (ícone: `wb_sunny_rounded`
     ou `view_day_rounded`) que navega para a tela unificada.

2. Criar (ou modificar) day_theme_screen.dart para ter duas abas:
   - Aba 1: "Themes" — conteúdo atual da DayThemeScreen.
   - Aba 2: "Blocks" — conteúdo do gerenciamento de day blocks
     (o que quer que esteja na rota /day-blocks).
   - Usar TabBar + TabBarView no topo da tela.

3. Atualizar o router em main.dart:
   - Manter rota /day-themes apontando para a tela unificada.
   - Remover rota /day-blocks (ou fazer redirect para /day-themes).

4. Atualizar navigation_provider.dart e navigation_item.dart:
   - Remover NavItem de /day-blocks se existir.
   - Garantir que /day-themes na barra de navegação abre a tela unificada.

UI/UX
- A tela unificada tem AppBar com título "Day Themes & Blocks" e TabBar logo
  abaixo com as abas "Themes" e "Blocks".
- Visual consistente com o resto do app (AppTheme.cardDecoration, cores padrão).
- Nenhuma mudança funcional nas abas — apenas a unificação de acesso.

--------------------------------------------------------------------------------
PEDIDO 11 — COLLECTION EDITOR: NÃO CONSEGUE ADICIONAR LINHAS [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
O editor de coleções em notas (Note Collection) não está permitindo adicionar
novas linhas/registros. O bug impede o uso básico da funcionalidade.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/ui/widgets/collection_editor.dart → implementação principal.
- lib/ui/widgets/collection_view.dart → view de leitura.
- lib/ui/screens/notes_screen.dart → onde o editor é instanciado.
- lib/ui/forms/create_note_form.dart → form que pode usar o CollectionEditor.
- lib/models/note_model.dart → checar se há campo `collectionContent` ou similar.

O QUE INVESTIGAR E CORRIGIR

O `CollectionEditor` tem dois modos: `_isConfiguringSchema` (true = configurar
campos) e false (= adicionar itens/linhas). O bug provavelmente está em um de:

1. MODO NÃO MUDA: o botão de "adicionar linha" não está chamando
   `setState(() => _isConfiguringSchema = false)` ou o botão não existe/não
   aparece na UI após configurar o schema.
   → Verificar: existe botão "Confirmar schema / Adicionar registros"?
   → Se não: adicionar botão "Pronto" que muda o modo para entrada de dados.

2. ADICIONAR ITEM NÃO FUNCIONA: o método `_addItem()` existe mas não chama
   `setState` ou não atualiza `_items`.
   → Verificar a implementação de _addItem():
     ```dart
     void _addItem() {
       setState(() {
         _items.add({for (var p in _schema) p.id: null});
       });
       _notifyChanged(); // chama widget.onChanged com o JSON serializado
     }
     ```
   → Garantir que `_notifyChanged()` serializa corretamente e chama
     `widget.onChanged`.

3. PERSISTÊNCIA: o `initialContent` é parseado no `initState` via
   `_parseContent()`. Verificar se o formato JSON está correto e se após
   adicionar itens o `onChanged` está de fato salvando no NoteModel.

4. SCHEMA VAZIO: se `_schema` está vazio, `_addItem()` cria um Map vazio e
   nada aparece. Garantir que o usuário só pode entrar no modo de adição após
   definir pelo menos um campo.

O QUE ADICIONAR/CORRIGIR NA UI:

- Após definir o schema, mostrar botão proeminente "+ Adicionar linha" no topo
  ou no fundo da lista de itens.
- Cada linha adicionada aparece como card editável com um campo por PropertyDefinition.
- Botão de deletar linha (ícone lixeira) no canto direito de cada card.
- Ao editar qualquer campo, chamar `_notifyChanged()` imediatamente (sem depender
  de um botão Save separado — auto-save).
- Botão "Editar estrutura" (ícone de engrenagem) no AppBar da collection para
  voltar ao modo de configuração do schema sem perder os dados.

UI/UX
- Modo schema: lista de campos com tipo, botão "+ Campo", botão "Confirmar".
- Modo dados: tabela ou lista de cards com as linhas, botão "+ Linha" fixo
  no fundo (FloatingActionButton pequeno ou botão de texto).
- Transição entre modos: animação de slide ou fade simples.
- Visual consistente com o restante do app (AppTheme.cardDecoration).

--------------------------------------------------------------------------------
PEDIDO 13 — MELHORIAS E UPGRADES EM RESOURCES [CONCLUÍDO]
--------------------------------------------------------------------------------

OBJETIVO
Melhorar a experiência de uso de recursos (livros, filmes/séries), unificando opções de tipos e status, adicionando suporte a prioridades, conexões com outros objetos por meio do campo Category, e integração com timer Pomodoro.

ONDE ESTÁ O CÓDIGO RELEVANTE
- lib/models/resource_model.dart → Modelo de dados `Resource`.
- lib/services/resource_metadata_service.dart → Serviço de metadados externos (Google Books, OMDb IMDb).
- lib/ui/forms/create_resource_form.dart → Formulário de criação/edição de recurso.
- lib/ui/screens/universal_detail_view.dart → Tela de detalhes detalhados.
- lib/providers/settings_provider.dart → Configurações padrões de filtros e tipos.

O QUE FOI FEITO

1. Unificação de Tipos (Book, Movie, Show, General):
   - Mapeamento das importações de APIs externas (`Google Books`, `OpenLibrary` e `IMDb`) para tipos em inglês padrão (`Book`, `Movie`, `Show`).
   - Garantido que o dropdown do tipo no form de recurso sempre mostre as opções 'Book', 'Movie', 'Show' e 'General' como base, além de suportar os itens personalizados nas configurações.

2. Adição de Campo Prioridade (`priority`):
   - Propriedade `priority` (tipo `TaskPriority`) adicionada à classe `Resource`, com serialização correta para o frontmatter do arquivo Markdown.
   - Adicionado picker no formulário para escolha de prioridade e exibição com edição in-place no PropertyGrid na visualização de detalhes.

3. Vincular Objetos via Category:
   - Adicionado botão de link next ao campo "Category" no formulário de recurso. O botão abre o `UniversalSearchPickerSheet` para vincular qualquer outro objeto (como um projeto, nota ou outro recurso), inserindo no campo no formato `[[slug]]`.

4. Integração com Pomodoro:
   - Exposta a ação `focus` para recursos no overflow menu.
   - Ícone de timer Pomodoro adicionado no AppBar para recursos.
   - Botão em destaque "Start Pomodoro Session" adicionado no corpo de detalhes do recurso.

================================================================================
FIM DO DOCUMENTO
================================================================================
==================
# IMPLEMENTATION DOC — APLICATIVO
Data: 2025-06-25
Para: agente de código
Estilo: implementar tudo sem pular etapas, sem placeholders, sem TODOs

PROGRESSO
- ✅ Feature 4 — Dashboard reset implementada.
- ✅ Feature 7 — Exportar crash reports implementada.
- ✅ Feature 8 — More screen com Day Themes/Day Blocks implementada.
- ✅ Feature 19 — Task backlog dialog ajustado.
- ✅ Feature 2 — Planner timeline header overflow corrigido.
- ✅ Feature 1 — Conflict resolution com botões e resumo claro implementada.
- ✅ Feature 3A+B — Seed automático e descriptions dos system moods implementados.
- ✅ Feature 3C+D+E — Mood settings grouped UI, fullscreen custom mood form and emoji timeline implemented.
- ✅ Feature 9A+B — Swipe para completar e days-since badge implementados.
- ✅ Feature 9C — Banner de pacto expirado no detail sheet implementado.
- ✅ Feature 10A+B+C — Quick-run swipe, histórico e estimated chip de Systems implementados.
- ✅ Bugfix extra — Checkboxes de hábitos corrigidos com atualização otimista e leitura por completionHistory.
- ✅ Feature 11 — Triple Check dismissal guard, diagnostic icons and stuck badge implemented.
- ✅ Feature 13 — Steering Sheet visual polish implemented.
- ✅ Feature 14 — Planner energy tints for time blocks implemented.
- ✅ Feature 4 follow-up — Flutter dashboard widgets removed; native Android widget pipeline preserved.
- ✅ Feature 15 — Organizer detail properties, notes tab and timeline period selector implemented.
- ✅ Feature 18 — Goal plan mode UI implemented.
- ✅ Feature 12 — Combined Analysis calendar emoji, heatmap, tap summary and month nav implemented.
- ✅ Feature 16 — Pomodoro custom ring, pulse, stop summary and completion overlay implemented.
- ✅ Feature 17 — People automatic contact tasks and completion updates implemented.
- ✅ Feature 5 — Collection new row and Obsidian Bases export implemented.
- ✅ Feature 6 — Save books from posts with Google Books lookup implemented.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 1 — CONFLICT RESOLUTION: BOTÕES MAIS CLAROS
Arquivo: lib/ui/screens/universal_detail_view.dart
Método: _showChangeTypeSheet()  +  _confirmAndChangeType()
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
O sheet "Change Object Type" mostra uma lista genérica de tipos.
O usuário não entende o que vai acontecer com os campos do objeto atual.
O banner de conflito de tipo existe mas não tem CTA claro.

MUDANÇAS NECESSÁRIAS

1. _showChangeTypeSheet(): adicionar subtítulo explicativo por item
   — Cada ListTile do sheet deve mostrar, abaixo do label, uma linha
     pequena descrevendo o que muda. Exemplos:
       • "Task"      → subtitle: "Keeps title, deadline and tags"
       • "Note"      → subtitle: "Keeps title and body. Removes deadline and recurrence"
       • "Habit"     → subtitle: "Keeps title. Adds frequency and streak"
       • "Project"   → subtitle: "Keeps title and organizers. Removes deadline"
       • "Goal"      → subtitle: "Keeps title and deadline. Adds progress"
       • "Person"    → subtitle: "Keeps only title and tags"
       • "Resource"  → subtitle: "Keeps title. Adds media type and status"
       • "Tracker"   → subtitle: "Keeps title. Adds unit and numeric values"
     Os demais tipos (área, atividade, etiqueta, lugar) já são auto-explicativos;
     use subtitle: "Keeps title and tags".

2. _confirmAndChangeType(): reescrever o diálogo de confirmação
   Antes: diálogo genérico "tem certeza?"
   Depois: diálogo com duas seções visuais lado a lado (ou em coluna em mobile):
     — Seção esquerda/topo: "Current" — tipo atual com ícone
     — Seta → ou ícone de transformação
     — Seção direita/baixo: "Will become" — tipo alvo com ícone e label em destaque
     — Corpo: texto dinâmico listando o que É PRESERVADO e o que É REMOVIDO/ADICIONADO
       Ex: "✓ Title, tags and organizers are preserved\n✗ Deadline and recurrence will be removed"
     — Botões: "Cancel" (textButton) e "Convert to [Label]" (FilledButton, cor primária)
   
   Para gerar o texto dinâmico, criar função privada:
     String _changeTypeSummary(String fromType, String toType)
   que retorna um Map com listas kept/removed/added para os pares relevantes.
   Cobrir pelo menos: task→note, task→habit, note→task, note→habit,
   habit→task, habit→note, goal→task, resource→note e o padrão genérico.

3. Banner de conflito de tipo (já existente, _buildObjectConflictBanner):
   — Adicionar botão "Resolve" inline no banner (TextButton pequeno, alinhado direita)
     que chama _showChangeTypeSheet() diretamente.
   — Isso evita que o usuário precise ir no menu ⋯ para descobrir a ação.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 2 — PLANNER: OVERFLOW DA DATA NA TIMELINE
Arquivo: lib/ui/screens/planner_screen.dart
Área: SliverAppBar + timeline scroll
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
O SliverAppBar tem floating: true e pinned: true.
Ao rolar a timeline para baixo, o header (data + day theme) fica com overflow
visual — o conteúdo da timeline aparece por baixo/em cima do título.

DIAGNÓSTICO PROVÁVEL
O CustomScrollView + SliverAppBar com pinned:true precisa que o SliverAppBar
declare um expandedHeight correto ou que o título seja limitado em altura.
A coluna do título (Planning + activeTheme.title) não tem height definida,
causando que o pinned header sobreponha o primeiro item da lista sem paddingTop.

CORREÇÕES

1. No SliverAppBar:
   — Adicionar: toolbarHeight: activeTheme != null ? 56.0 : 44.0
     (altura maior quando há subtítulo de theme ativo)
   — Remover floating: true (manter só pinned: true)
     Motivo: floating + pinned juntos em CustomScrollView com muitos slivers
     causa o comportamento de overlap. Pinned sozinho é o correto aqui.

2. No primeiro SliverList ou SliverPadding que contém a timeline:
   — Garantir que o primeiro item tem padding top suficiente.
   — Adicionar SliverPadding(padding: EdgeInsets.only(top: 8)) antes do
     primeiro sliver de conteúdo se não existir.

3. A linha de data selecionada que fica fixa ao rolar:
   — Se o widget de data (ex: chips de dia da semana ou o texto "Tue, Jun 24")
     está dentro do SliverAppBar como parte do title:
     Mover a exibição da data formatada para dentro do title Column, com
     overflow: TextOverflow.ellipsis e maxLines: 1, para não crescer.
   — Se há um widget de seleção de data separado (Row com chips dos 7 dias),
     ele deve estar num SliverPersistentHeader dedicado com pinned: true e
     height fixa (ex: 52px), ABAIXO do SliverAppBar, não dentro dele.
     Isso impede o overflow porque cada header tem seu próprio layer.

4. Testar cenário: rolar com day theme ativo (2 linhas no título) e sem theme
   ativo (1 linha). Em ambos os casos o conteúdo da timeline não deve passar
   por trás do header.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 3 — MOODS: PRÉ-CONFIGURADOS + VISUALIZAÇÃO NAS ANÁLISES
Arquivos:
  lib/providers/vault_provider.dart  (MoodsNotifier.build)
  lib/ui/screens/mood_settings_screen.dart
  lib/ui/screens/combined_analysis_screen.dart
  lib/ui/widgets/citrine_chart.dart  (já tem suporte a emoji — verificar)
  lib/models/mood_model.dart         (systemMoods já definidos — não alterar)
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
MoodDefinition.systemMoods já tem 48 moods completos com emoji, quadrante,
pleasantness e energy, alinhados ao How We Feel.
Porém MoodsNotifier.build() lê só do vault (allObjectsProvider) — se o vault
estiver vazio, moodsProvider retorna lista vazia e a tela de humor fica em branco.
O campo description dos systemMoods está null (não preenchido ainda).

PARTE A — SEED AUTOMÁTICO DOS SYSTEM MOODS
Status: ✅ IMPLEMENTADO

Em MoodsNotifier.build():
  — Após carregar do vault, se a lista filtrada de MoodDefinition estiver vazia
    E não houver nenhum arquivo em moods/ no vault ainda:
    disparar seedSystemMoods() como side-effect após o frame.
  — Se a lista tiver itens mas nenhum com source == MoodSource.system:
    mesmo comportamento (vault só tem moods de usuário de versão anterior).

Criar método em MoodsNotifier:
  Future<void> seedSystemMoods() async {
    for (final mood in MoodDefinition.systemMoods) {
      final path = 'moods/${mood.id}.md';
      final exists = await obsidian.fileExists(path);
      if (!exists) {
        await obsidian.writeFile(path, mood.toMarkdown());
      }
    }
    ref.invalidate(allObjectsProvider);
  }

  O método deve ser idempotente: checar existência antes de criar.

PARTE B — DESCRIPTIONS (frases curtas) DOS SYSTEM MOODS
Status: ✅ IMPLEMENTADO

Adicionar campo description a cada MoodDefinition em systemMoods.
Uma frase curta em inglês para cada um. Lista completa:

RED quadrant:
  enraged:     "Intense rage, feeling out of control"
  panicked:    "Acute fear with a sense of losing control"
  livid:       "Deep anger that is hard to hold back"
  furious:     "Intense irritation with tension in the body"
  terrified:   "Terror in the face of a real or imagined threat"
  shocked:     "Extreme surprise that leaves you frozen"
  anxious:     "Anticipatory worry about what might go wrong"
  stressed:    "Accumulated pressure weighing on body and mind"
  frustrated:  "Obstacles blocking what you are trying to achieve"
  agitated:    "Restlessness that is hard to settle"
  irritated:   "Small things bothering you more than they should"
  jittery:     "Physical nervousness, like before something important"

YELLOW quadrant:
  ecstatic:     "Joy so intense it overflows"
  elated:       "Light, luminous euphoria — everything feels possible"
  excited:      "Positive energy directed at something coming up"
  enthusiastic: "Eagerness to act and engage with what you are doing"
  energized:    "Physical and mental readiness above your usual baseline"
  happy:        "Quiet, genuine sense of wellbeing"
  joyful:       "Spontaneous joy without any particular reason"
  upbeat:       "Lightness and good spirits throughout the day"
  inspired:     "Connected to an idea or vision that moves you"
  motivated:    "Clear inner drive to take action"
  optimistic:   "Confidence that things will work out"
  proud:        "Satisfaction with something you did or who you are"

GREEN quadrant:
  calm:         "Absence of tension, a natural resting state"
  content:      "Satisfied with what you have and where you are"
  peaceful:     "Inner harmony without conflict"
  serene:       "Deep stillness, almost meditative"
  grateful:     "Recognizing the good in your life"
  relaxed:      "Tension released, body and mind loose"
  comfortable:  "Comfort in your surroundings and in yourself"
  at_ease:      "No pressure, moving at your own pace"
  balanced:     "Energy and emotions in balance"
  loving:       "Openness and warmth toward what and who surrounds you"
  thoughtful:   "Reflective presence, turned inward"
  secure:       "Feeling of stability and belonging"

BLUE quadrant:
  sad:          "Simple sadness, sometimes without a clear reason"
  depressed:    "Persistent heaviness draining energy and meaning"
  hopeless:     "Difficulty seeing a way out or improvement"
  lonely:       "Feeling isolated even when surrounded by people"
  bored:        "Lack of stimulation or interest in what is around you"
  disconnected: "Emotional distance from yourself and others"
  exhausted:    "Complete depletion of physical and mental energy"
  discouraged:  "Will weakened by repeated setbacks"
  disappointed: "Unmet expectation leaving an empty feeling"
  numb:         "Absence of feeling, as if numbed"
  melancholic:  "Gentle sadness mixed with nostalgia"
  defeated:     "Feeling that the effort was not enough"

PARTE C — TELA MOOD SETTINGS: MOSTRAR SYSTEM MOODS
Status: ✅ IMPLEMENTADO

Na mood_settings_screen.dart o comportamento atual é uma lista reordenável
sem distinção de origem, mostrando apenas moods de usuário, com um limite
total de 15. Refatorar completamente:

  — Agrupar moods por quadrante (RED / YELLOW / GREEN / BLUE) com cabeçalhos
    coloridos usando a cor de cada quadrante (MoodDefinition.quadrantColor).
    Cada seção é collapsible (ExpansionTile ou similar). Estado inicial: expandido.
    Header da seção mostra: nome do quadrante + "Alta/Baixa energia · Agradável/Desagradável"
    + contagem "X of Y visible" alinhada à direita.

  — Moods com source == MoodSource.system:
      • Mostrar emoji (22pt) + label (15pt) + description (12pt muted, 1 linha ellipsis)
      • Trailing: Switch iOS-style de visibilidade (on = cor do quadrante, off = cinza)
        Toggle grava campo hidden: true/false no arquivo do vault via
        ref.read(moodsProvider.notifier).updateMood(mood.copyWith(hidden: !mood.hidden))
      • Tap no row abre bottom sheet de detalhes (não navegar para UniversalDetailView):
          - handle pill no topo
          - emoji grande (36pt) + label (20pt semibold) + description (14pt muted)
          - Seção "Quadrant": chip colorido com nome do quadrante
          - Seção "Values": "Pleasantness: N/5  ·  Energy: N/5" (14pt)
          - Seção "Aliases": chips editáveis (texto do alias + X para remover).
            "＋ Add alias" (accent, 13pt). Salva via updateMood ao confirmar cada alias.
          - Seção "Visibility": Toggle "Show in picker" + descrição
            "Hiding preserves all historical records." (12pt muted)
          - Nota ao fundo: "System moods cannot be fully edited. You can add aliases and hide."
            (12pt muted, centrado)
          - Sem botão de deletar.
      • NÃO mostrar drag handle — system moods têm ordem fixa dentro do quadrante.

  — Moods com source == MoodSource.user:
      • Mesmo layout de row, mas trailing: Row com drag handle (≡) + Switch de visibilidade
      • Tap no row abre bottom sheet igual ao de system, MAS com todos os campos editáveis:
          - Nome: text field editável inline
          - Emoji: tap abre emoji picker
          - Quadrante: grade 2×2 tappável
          - Values: dois Sliders (pleasantness 1–5, energy 1–5), range limitado ao quadrante
          - Description: text area editável
          - Aliases: chip input editável
          - Cor: grid de swatches circulares
          - Botão "Delete mood" (vermelho, full-width outline) com confirmation alert:
            "Delete [label]? Historical records are preserved, but this mood won't appear in the picker."
            Botões: "Delete" (vermelho) + "Cancel"

  — Limite _maxMoods aplica-se apenas a moods de usuário:
      canAdd = moods.where((m) => m.source == MoodSource.user).length < 15
    Atualizar a lógica que bloqueia o botão "Add" no AppBar.

  — "Add" button no AppBar continua abrindo o formulário de criação de mood user
    (refatorado conforme abaixo).

PARTE D — FORMULÁRIO DE CRIAÇÃO DE MOOD USER (refatorar _editMood)
Status: ✅ IMPLEMENTADO

O diálogo atual usa AlertDialog simples com campos básicos (nome, emoji,
valor numérico, cor) e não suporta dois eixos separados nem quadrante.
Substituir por full-screen modal:

  Apresentação: Navigator.push com MaterialPageRoute fullscreenDialog: true.
  AppBar: X no top-left (cancelar), título "New mood" (centro),
  "Save" no top-right (accent, disabled até nome preenchido).

  Campos em scroll (padding 20pt horizontal):

  1. Nome
     - Label "What do you call this feeling?" (14pt semibold)
     - TextField full-width, placeholder "e.g. Flow, Nostalgic, Focused"
     - Helper: "This name will appear in the picker." (12pt muted)

  2. Emoji
     - Label "Emoji" (14pt semibold)
     - Row: quadrado preview 48×48pt (border radius 12, emoji 28pt) + "Choose emoji" (accent)
     - Tap → modal emoji picker pesquisável (grid, 6 colunas, 40pt por célula)

  3. Quadrant
     - Label "How do you feel?" (14pt semibold)
     - Grade 2×2 de radio buttons com visual igual ao Mood Picker Passo 1:
       fundo da cor a 15%, borda a 30%, ícone de energia + label de agradabilidade
     - Selecionado: fundo 100% da cor, texto branco

  4. Fine-tune sliders (slide down 200ms ao selecionar quadrante)
     - Título "Fine-tune" (13pt semibold muted all-caps)
     - Slider Pleasantness: range limitado ao quadrante selecionado
       (red: 1–2, yellow: 4–5, green: 4–5, blue: 1–2; ajustar conforme systemMoods)
       Labels extremos: "Less pleasant" / "More pleasant"
       Pill flutuante acima do thumb com valor "N/5"
     - Slider Energy: range limitado ao quadrante (red/yellow: 3–5, green/blue: 1–3)
       Labels extremos: "Less energy" / "More energy"

  5. Description (opcional)
     - TextArea mínimo 3 linhas, expansível
     - Placeholder "How do you usually feel when you're like this?"

  6. Aliases
     - Chip input: digitar + Enter adiciona chip, X remove
     - Helper: "You can search this mood by any of these names." (12pt muted)

  7. Color
     - Grid de swatches: pré-selecionar cor do quadrante escolhido. Nunca HEX direto.

  Botão "Save" full-width no bottom. Disabled se nome vazio.

PARTE E — VISUALIZAÇÃO DE MOODS NAS ANÁLISES (combined_analysis_screen.dart)
Status: ✅ IMPLEMENTADO

O chart já suporta emoji via ChartDataPoint.emoji e CitrineChart os renderiza
como tooltip annotations nos pontos. O _getMoodEmojiForDate() já existe.
O chip de legenda (Chip) não é tappável e não tem toggle de visibilidade.

MUDANÇA 1: chips de legenda com toggle de visibilidade
  — Transformar _buildMetricChip em FilterChip com onSelected.
  — Manter Set<String> _hiddenSourceIds no estado.
  — Quando chip é toggled off: opacidade 40%, série removida de chartSeries
    e chartColors ao construir o gráfico.
  — Chip de mood: adicionar ícone de emoji (texto "😊", 14pt) antes do label
    quando MetricType.mood está ativo, para indicar a timeline extra abaixo.

MUDANÇA 2: MoodEmojiTimeline widget
  Criar lib/ui/widgets/mood_emoji_timeline.dart

  StatelessWidget que recebe:
    final List<ChartDataPoint> points;  // série mood com emoji preenchido
    final int days;                      // N dias do período selecionado

  UI: Row horizontal com N colunas iguais, scroll horizontal se N > 14.
  Cada coluna (LayoutBuilder para width = totalWidth / min(N, 14)):
    — Data abreviada no bottom: "24/6", fontSize 9, muted
    — Emoji no centro: fontSize 18
    — Se ponto nulo: "·" em 12pt muted cinza
    — Sem borda, fundo transparente

  Posicionamento: inserir imediatamente abaixo do CitrineChart, dentro do mesmo
  card container (SizedBox height 52pt para a timeline de emojis).
  Visível apenas quando MetricType.mood está em _activeSources e não está
  em _hiddenSourceIds.

MUDANÇA 3: não remover a linha numérica de pleasantness do chart —
  manter ambas (linha + emoji timeline abaixo). O usuário pode correlacionar
  tracker numérico com humor visualmente.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 4 — DASHBOARD: APAGAR TODOS OS WIDGETS
Arquivo: lib/providers/dashboard_provider.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
DashboardNotifier carrega blocos de SharedPreferences (chave 'dashboard_blocks_v3').
_withRequiredNativeBlocks() força a presença de 'home-calendar', 'home-area' e
'home-pomodoro-week' mesmo se o usuário os remove. Isso impede o reset total.

MUDANÇAS

1. Remover _withRequiredNativeBlocks() completamente.
   — Não há mais blocos obrigatórios. Se o usuário quer dashboard vazio, ok.

2. Atualizar build():
   — Se jsonStr != null e decodificação ok: retornar a lista salva sem nenhum merge forçado.
   — Se jsonStr == null (primeira vez): retornar lista vazia [] (não _defaultBlocks).
   — _defaultBlocks pode continuar existindo como referência para o usuário
     adicionar blocos manualmente, mas não é mais carregado automaticamente.

3. Adicionar método público no DashboardNotifier:
   Future<void> clearAll() async {
     state = AsyncData([]);
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('dashboard_blocks_v3');
   }

4. Na home_screen.dart (ou onde o dashboard é renderizado):
   — Quando a lista de blocos está vazia, mostrar EmptyState com:
     title: "Empty dashboard"
     subtitle: "Tap + to add blocks"
     button: "Add block" → abre o sheet de seleção de blocos
   — Não mostrar mensagem de erro, não redirecionar.

NOTA: A laura vai recriar os blocos manualmente. Não recriar defaults automaticamente.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 5 — NOTE COLLECTION: ADICIONAR LINHAS + OBSIDIAN BASES
Arquivos:
  lib/ui/widgets/collection_editor.dart
  lib/services/obsidian_service.dart  (para geração do markdown)
  lib/models/note_model.dart          (já tem NoteSubtype.collection)
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
CollectionEditor renderiza uma tabela JSON com schema (colunas) e items (linhas).
Ao abrir uma collection no app, o usuário não vê nenhum botão claro para
adicionar nova linha. _isConfiguringSchema = true na abertura mostra a tela
de configuração de schema, não a tabela.

PARTE A — ADICIONAR NOVA LINHA NA COLLECTION

Em _CollectionEditorState:

1. Fluxo corrigido de primeira abertura:
   — Se _schema.isEmpty → mostrar tela de configuração de schema (comportamento atual).
   — Se _schema.isNotEmpty → ir direto para a tabela (_isConfiguringSchema = false).
   Atualmente _isConfiguringSchema começa true sempre. Corrigir em _parseContent():
     if (_schema.isNotEmpty) _isConfiguringSchema = false;

2. Na tela de tabela (quando _isConfiguringSchema == false):
   — Adicionar FloatingActionButton com Icons.add_rounded e label "New row".
   — On tap: add an empty Map to _items e chamar _save().
   — Cada linha deve ser editável inline (ao tocar na célula, abrir um campo
     de texto / seletor dependendo do PropertyType).

3. Schema config button (⚙) must be accessible via AppBar action,
   não substituindo a tela toda.

PARTE B — OBSIDIAN BASES COMPATIBILITY

O plugin Obsidian Bases (oficial, lançado 2025) usa arquivos .base com frontmatter
YAML que define uma "database view" sobre notas existentes em uma pasta.
Cada linha da tabela é uma nota Obsidian separada em uma pasta.

ESTRATÉGIA (sem alterar o modelo de dados interno do app):

Quando uma Note com subtype == collection é salva no vault via obsidian_service.dart,
além do arquivo .md da nota (que contém o JSON), gerar também:

a) Uma pasta: <note_slug>/   (ex: "minha-colecao/")
b) Para cada item em _items: uma nota .md individual dentro dessa pasta.
   Nome do arquivo: item['id'] ?? uuid gerado.md
   Frontmatter: cada PropertyDefinition vira uma propriedade YAML.
   Exemplo de item com schema {name:text, status:selection, rating:rating}:
     ---
     title: "Value of the name field"
     status: "In progress"
     rating: 4
     collection_ref: "[[minha-colecao]]"
     ---
   Body: vazio ou valor do campo richText se houver.

c) Um arquivo .base na raiz da pasta (ou ao lado da nota):
   <note_slug>.base
   Conteúdo do .base:
     ---
     filters: []
     order: []
     properties:
       <para cada PropertyDefinition>
       - name: <prop.name>
         type: <mapeamento de PropertyType para tipo Bases>
     source:
       type: folder
       path: "<note_slug>/"
     ---

   Mapeamento de PropertyType → Bases type:
     text, richText, url, email, phone → "text"
     quantity, rating → "number"
     date → "date"
     time → "text"
     duration → "number"
     selection → "select"
     multiSelection → "multiselect"
     checkbox → "checkbox"
     relation → "text"  (wikilink como texto)
     media → "text"

d) Criar método em ObsidianService:
   Future<void> syncCollectionToBase(Note note) async { ... }
   Chamar esse método no vault_provider quando uma note do tipo collection
   é criada ou atualizada.

e) Quando o usuário edita um item no app:
   — Atualizar o arquivo .md individual correspondente na pasta.
   — NÃO re-gerar todos os arquivos, só o que mudou.
   — Se um item é adicionado: criar novo .md na pasta.
   — Se um item é removido: deletar o .md correspondente.

f) Sincronização reversa (Obsidian → app):
   Não implementar na v1. O fluxo é unidirecional: app → Obsidian.
   Documentar isso como limitação conhecida.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 6 — SALVAR LIVROS DE POSTS: BUSCA MANUAL + GOOGLE BOOKS
Arquivos:
  lib/ui/screens/social_post_detail.dart
  lib/ui/screens/resources_screen.dart
  lib/models/resource_model.dart
  lib/services/ → criar: book_lookup_service.dart
  lib/ui/forms/create_resource_form.dart
  lib/ui/widgets/ → criar: book_search_sheet.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
A laura salva posts (foto/vídeo) de recomendações de livros.
Ela quer, estando no post, abrir um sheet, digitar o título de um livro,
buscar e salvar como Resource já preenchido com capa, título PT-BR, autor etc.
Sem OCR / visão computacional — é busca manual por título.

PARTE A — RESOURCE MODEL: novos campos

Em lib/models/resource_model.dart, adicionar:
  String? isbnOriginal;
  String? titlePtBr;
  String? titleOriginal;
  String? publisher;
  String? language;
  String? googleBooksId;

Atualizar toMarkdown(), fromMarkdown() e copyWith().
  Chaves YAML: isbn, title_pt_br, title_original, publisher, language, google_books_id

O campo title (já existente em ContentObject) vai receber o título em PT-BR se
disponível, ou o original caso contrário.
Os aliases devem incluir titleOriginal se diferente.

PARTE B — BookLookupService

Criar lib/services/book_lookup_service.dart

class BookSearchResult {
  final String googleBooksId;
  final String titleOriginal;
  final String? titlePtBr;
  final String? author;
  final String? coverUrl;
  final String? coverUrlLarge;
  final int? year;
  final int? pages;
  final String? synopsis;
  final String? publisher;
  final String? language;
  final String? isbn;
}

Método principal:
  Future<List<BookSearchResult>> search(String query, {String apiKey}) async {
    // GET https://www.googleapis.com/books/v1/volumes
    // params: q=<query>, maxResults=10, key=<apiKey>
    // Parsear volumeInfo de cada item
    // Para cada resultado, tentar detectar se há edição PT-BR:
    //   segundo request: q=<titleOriginal> inauthor:<author>, langRestrict=pt
    //   timeout de 3s, falha silenciosa (titlePtBr fica null)
  }

  String _stripHtml(String html) { ... }

PARTE C — BookSearchSheet widget

Criar lib/ui/widgets/book_search_sheet.dart

StatefulWidget que recebe:
  final String? linkedPostId;
  final VoidCallback? onSaved;

UI do sheet:
  1. Campo de busca com TextField e botão "Search" (ou submit no teclado).
  2. Loading indicator enquanto busca.
  3. Lista de resultados: cada item mostra:
     — Thumbnail (Image.network com placeholder cinza se null, 40×60pt)
     — Título original + título PT-BR se diferente (em cinza menor, 12pt)
     — Autor, ano (13pt muted)
     — Botão "Add" no lado direito
  4. Ao tocar "Add" num resultado:
     a. Criar Resource com todos os campos preenchidos
     b. socialRefs: [linkedPostId] se linkedPostId != null
     c. Salvar via resourcesProvider.notifier.addResource(resource)
     d. SnackBar: "📚 [title] added to your library"
     e. Manter sheet aberto para mais livros. "Close" button top-right.
  5. Se apiKey está vazia: warning + botão "Add manually" que abre
     create_resource_form com resourceType pré-preenchido como 'Livro'.

PARTE D — Integração no SocialPostDetail

Em lib/ui/screens/social_post_detail.dart:
  — Adicionar action no AppBar com label "Save books from post"
    ícone: Icons.menu_book_outlined
  — showModalBottomSheet com BookSearchSheet(linkedPostId: post.id)

PARTE E — API Key nas Settings

Em lib/ui/screens/settings_screen.dart:
  — Adicionar campo "Google Books API Key" em seção "Integrations".
  — Salvar em SharedPreferences com chave 'google_books_api_key'.
  — Provider: googleBooksApiKeyProvider (StateProvider<String> lendo de prefs).

PARTE F — Resources screen: mostrar capa

Em lib/ui/screens/resources_screen.dart:
  — Se resource.coverImage != null e resource.resourceType == 'Livro':
    mostrar thumbnail na lista (Image.network, 40×60pt, border-radius 4).
  — Verificar se o list tile atual usa coverImage; se não, adicionar leading.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 7 — EXPORTAR CRASH REPORTS
Arquivos:
  lib/ui/screens/diagnostic_reports_screen.dart
  lib/ui/screens/settings_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
CrashReportService salva reports em internal storage inacessível ao usuário.
DiagnosticReportsScreen lista reports mas só oferece "Copiar" para clipboard.
Strings da tela estão em português.

MUDANÇAS

1. Adicionar dependência share_plus ao pubspec.yaml se não existir.
   Verificar: grep 'share_plus' pubspec.yaml
   Se ausente: share_plus: ^10.0.0 em dependencies.

2. Adicionar _shareReport(File file):
   Future<void> _shareReport(File file) async {
     await Share.shareXFiles(
       [XFile(file.path)],
       subject: file.path.split('/').last,
     );
   }

3. No ListTile de cada report: trailing com dois botões (Row, MainAxisSize.min):
   — Icons.share_rounded → _shareReport(file)
   — Icons.chevron_right_rounded → _viewReport(file) (já existe)

4. No dialog de _viewReport: botão "Share" entre "Copy" e "Close".

5. Botão "Share All" no AppBar (ícone ios_share_rounded):
   — Desabilitado se _reports.isEmpty
   — Share.shareXFiles com todos os XFile

6. Corrigir strings em português:
   "Relatórios de diagnóstico"     → "Diagnostic Reports"
   "Exibir relatórios de erros..."  → "View local error and ANR reports"
   "Limpar Relatórios?"             → "Clear Reports?"
   "Todos os relatórios..."         → "All local diagnostic reports will be deleted. The Vault copy will not be affected."
   "Cancelar"                       → "Cancel"
   "Limpar"                         → "Clear"
   "Relatórios apagados."           → "Reports cleared."
   "Relatórios de Diagnóstico"      → "Diagnostic Reports" (AppBar title)
   "Nenhum relatório encontrado."   → "No reports found."
   "Caminho interno"                → "Internal storage"
   "Copiado para a área de transferência" → "Copied to clipboard"
   "Copiar"                         → "Copy"
   "Fechar"                         → "Close"
   "Erro ao ler: $e"                → "Error reading file: $e"


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 8 — MORE SCREEN: DAY THEMES E DAY BLOCKS ABAIXO DO SHOPPING LIST
Arquivo: lib/ui/screens/more_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO
Day Themes (DayThemeScreen) e Day Blocks (AlarmScreen) só são acessíveis via
navigation items dinâmicos, que podem não estar visíveis. Devem aparecer
fixamente abaixo do Shopping List na more_screen.

MUDANÇAS

1. Adicionar imports se não existirem:
   import 'day_theme_screen.dart';
   import 'alarm_screen.dart';

2. Corrigir strings em português:
   'Lista de Mercado' → 'Shopping List'
   'Conflitos de Tipo' → 'Type Conflicts'

3. Após o _buildMenuRow do Shopping List (verificar NavSection para nomes exatos):
   final hasDayThemeInNav = inMoreItems.any((it) => it.section == NavSection.dayTheme);
   final hasDayBlockInNav  = inMoreItems.any((it) => it.section == NavSection.alarm);

   if (!hasDayThemeInNav) ...[
     const SizedBox(height: 8),
     _buildMenuRow(context, 'Day Themes', Icons.wb_sunny_outlined,
       AppColors.warning, () => Navigator.push(context,
         MaterialPageRoute(builder: (_) => const DayThemeScreen()))),
   ],
   if (!hasDayBlockInNav) ...[
     const SizedBox(height: 8),
     _buildMenuRow(context, 'Day Blocks', Icons.view_day_outlined,
       AppColors.primary, () => Navigator.push(context,
         MaterialPageRoute(builder: (_) => const AlarmScreen()))),
   ],

   Ordem final da seção: Shopping List → Day Themes → Day Blocks → Vault Files → Type Conflicts


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 9 — HABIT: SWIPE RIGHT PARA COMPLETAR + BADGES CORRETOS
Arquivos: lib/ui/screens/habits_screen.dart
          lib/ui/widgets/habit_row.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
Ao deslizar um habit/pact card para a direita, o habit é marcado como
completo para hoje sem precisar abrir o detail sheet. Feedback visual imediato.
Além disso, o "days since" badge atual usa texto em português e cor para
dias ≥ 3, mas a spec pede #E53935 já a partir do dia 1 (qualquer gap > 0).

PARTE A — SWIPE RIGHT PARA COMPLETAR
Status: ✅ IMPLEMENTADO

Em habits_screen.dart, envolver _TodayHabitCard com Dismissible:

  Dismissible(
    key: ValueKey('habit_swipe_${habit.id}'),
    direction: DismissDirection.startToEnd,
    confirmDismiss: (_) async {
      // Não dismissar o card da lista — apenas executar a ação.
      // Completar o habit via provider e retornar false para
      // não remover o item.
      final notifier = ref.read(vaultProvider.notifier);
      // Lógica idêntica ao tap no checkbox do _TodayHabitCard.
      // Registrar CompletionRecord para hoje com completions = habit.dailyGoal.
      await notifier.recordHabitCompletion(habit, DateTime.now());
      HapticFeedback.lightImpact();
      return false;  // não remove o card
    },
    background: Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: habitColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: habitColor, size: 28),
          const SizedBox(width: 8),
          Text('Done!', style: TextStyle(color: habitColor,
            fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
    child: _TodayHabitCard(habit: habit, currentVal: val, date: now),
  )

  A função recordHabitCompletion deve verificar se já foi completado hoje
  antes de criar novo registro.

PARTE B — DAYS SINCE BADGE: COR CORRETA
Status: ✅ IMPLEMENTADO

Em habit_row.dart, método _buildDaysSinceBadge():
  Atualizar a condição de cor: qualquer days >= 1 → AppColors.error (#E53535 ou
  o equivalente, verificar AppColors.error hex).
  Texto: days == 0 → "Today" (sem badge vermelho)
         days == 1 → "1 day ago" (badge #E53935)
         days >= 2 → "$days days ago" (badge #E53935)
  O badge "Feito hoje" (green, "Feito hoje") manter mas traduzir para "Done today".

PARTE C — PACT EXPIRED: BANNER NO DETAIL SHEET
Status: ✅ IMPLEMENTADO

Em habit_detail_sheet.dart, no início do body, antes de qualquer outra seção,
verificar se o habit é um pact expirado sem resolução:

  final isPactExpired = habit.habitMode == HabitMode.pact
    && habit.endsAt != null
    && habit.endsAt!.isBefore(DateTime.now())
    && habit.pactOutcome == null;

  Se isPactExpired, inserir banner amarelo no topo do sheet:
    Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.amber.shade100,
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text(
          'This pact ended on ${habit.endsAt!...}. Review it now.',
          style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
        )),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // fechar detail
            showSteeringSheet(context, ref, habit);
          },
          child: Text('Review', style: TextStyle(color: Colors.amber.shade900,
            fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    )


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 10 — SYSTEM: QUICK-RUN SWIPE + HISTÓRICO DE TASKS
Arquivos: lib/ui/screens/goals_screen.dart (ou onde systems são listados)
          lib/ui/screens/system_detail_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
Swipe direito em um System na lista → abre o bottom sheet de quick-run (Via C)
sem precisar entrar na detail view.
Na detail view, adicionar seção "History" com as tasks geradas anteriormente
por execuções deste System.

PARTE A — SWIPE RIGHT PARA QUICK-RUN
Status: ✅ IMPLEMENTADO

Na tela que lista Systems (verificar qual screen: planner_screen, goals_screen,
ou uma seção dedicada), envolver cada card de System com Dismissible:

  direction: DismissDirection.startToEnd
  confirmDismiss: (_) async {
    showSystemQuickRunSheet(context, ref, system);
    return false;  // não remove
  }
  background: Container com ícone ▶ e label "Quick run"
    fundo: AppColors.warning (laranja) a 15% de opacidade

PARTE B — SEÇÃO HISTÓRICO NA DETAIL VIEW
Status: ✅ IMPLEMENTADO

Em system_detail_screen.dart, após a seção "Passos" e antes de "Notas",
adicionar seção "HISTORY":

  — Label "HISTORY" (12pt semibold muted all-caps) + contagem de tasks geradas.
  — Buscar tasks do vault onde task.linkedSystem == system.id.
    Ordenar cronologicamente reverso (updatedAt desc). Mostrar máximo 5.
  — Se mais de 5: botão "View all (N)" (accent, 13pt) que navega para
    tasks_screen filtrado por linkedSystem.
  — Cada row:
      • Ícone de task (16pt, azul) + título da task (15pt) + data relativa (13pt muted trailing)
      • Subtítulo (13pt muted): duração total de Pomodoro (se task.pomodoroCount > 0:
        "⏱ Xmin") + badge de stage (pill 11pt, cor por stage)
      • Tap → navega para a Task via object navigation

  — Se nenhuma task gerada ainda: "No runs yet. Use Quick Run or Create Task to get started."
    (14pt muted, centrado)

PARTE C — STATS: ADICIONAR CHIP "ESTIMATED"
Status: ✅ IMPLEMENTADO

Em system_detail_screen.dart, na stats row, adicionar chip "Estimated: Xmin":
  — Usar system.estimatedMinutes (já existe no modelo).
  — Inserir após o chip "Execuções", antes de "Tempo médio".
  — Se estimatedMinutes == null ou == 0: não exibir o chip.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 11 — TRIPLE CHECK: DISMISSAL GUARD + ÍCONES NO CARD + STUCK BADGE
Arquivos: lib/ui/widgets/triple_check_sheet.dart
          lib/ui/widgets/timeline_card.dart
          lib/ui/screens/planner_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O Triple Check sheet atualmente é dismissível por swipe mesmo antes de salvar.
Tasks com diagnóstico salvo devem mostrar ícones no card.
Tasks paradas há 7+ dias devem ter badge ⚠ que abre o sheet diretamente.

PARTE A — PREVENT DISMISS ANTES DE SALVAR

Em triple_check_sheet.dart, envolver o sheet com PopScope:

  PopScope(
    canPop: _saved,  // _saved começa false, vira true após salvar
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saved) {
        // Não salvou ainda: haptic + shake animation no container
        HapticFeedback.lightImpact();
        _shakeController.forward(from: 0.0);  // AnimationController existente ou criar
      }
    },
    child: ...
  )

  Criar AnimationController _shakeController que anima o container horizontalmente
  ±4pt duas vezes (150ms total) usando SlideTransition ou Transform.translate.

PARTE B — ÍCONES DE DIAGNÓSTICO NO CARD DA TASK

Em timeline_card.dart (ou onde as tasks são renderizadas no Planner),
após o build da Row principal do card, adicionar Positioned no Stack
(ou no bottom-left do card se não for Stack):

  Se task.tripleCheck != null:
    Row com ícones 14pt, cor muted, gap 2pt:
      • head != yes → 🧠 (texto emoji) ou Icon(Icons.psychology_outlined)
      • heart != yes → ❤️ (texto emoji) ou Icon(Icons.favorite_outline)
      • hand != yes → ✋ (texto emoji) ou Icon(Icons.back_hand_outlined)

  O row inteiro é tappável e abre o Triple Check em modo read-only:
    showModalBottomSheet com TripleCheckSheet(task: task, readOnly: true)
  
  Adicionar parâmetro bool readOnly = false ao TripleCheckSheet.
  Quando readOnly = true:
    — Todos os radio buttons disabled
    — Botão no bottom: "Re-run diagnostic" (outline accent)
    — Ao tocar "Re-run": fecha e reabre o sheet sem readOnly

PARTE C — BADGE ⚠ EM TASKS PARADAS

No Planner, ao construir a lista de tasks do dia, calcular stuckDays:
  Número de dias desde que a task foi criada ou desde a última mudança de stage
  (usar task.updatedAt). Se stuckDays >= 7 e task.stage é todo|in_progress|pending:

  Adicionar um pequeno Container no top-right do card da task:
    Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.warning),
        SizedBox(width: 2),
        Text('${stuckDays}d', style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w700, color: AppColors.warning)),
      ]),
    )

  Tap no badge → abre Triple Check sheet para essa task.
  Calcular stuckDays usando task.updatedAt como proxy de última mudança de stage.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 12 — COMBINED ANALYSIS CALENDAR: EMOJI + HEATMAP + TAP + NAV DE MÊS
Arquivo: lib/ui/widgets/analysis_calendar.dart
         lib/ui/screens/combined_analysis_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O calendário atual da Combined Analysis mostra apenas número do dia e dots
coloridos. Precisa de: emoji do mood por célula, heatmap de fundo proporcional
ao valor da série principal, tap em célula abre mini bottom sheet, navegação de mês.

REFATORAR analysis_calendar.dart completamente:

PARÂMETROS DO WIDGET:
  final DateTime month;
  final List<MetricSource> sources;
  final Map<DateTime, List<MetricSource>> data;
  final Map<DateTime, String?> moodEmojis;   // novo: emoji do mood por data
  final ValueChanged<DateTime>? onMonthChanged; // novo: callback de nav de mês

HEADER DE NAVEGAÇÃO DE MÊS:
  Row: IconButton "‹" + Text "May 2026" (15pt semibold) + IconButton "›"
  Ao tap em ‹/›: chamar onMonthChanged(newMonth) para o pai atualizar o estado.
  Em combined_analysis_screen.dart: manter DateTime _calendarMonth em state,
  inicializado com o mês atual. Atualizar ao receber o callback e reconstruir.

CADA CÉLULA DO DIA (refatorar GridView item):
  GestureDetector com onTap → _showDaySummarySheet(context, date, dayData, moodEmojis[date])

  Layout interno da célula (Column, mainAxisAlignment: start):
    — Número do dia: 9pt medium, topo, centrado. Cor: today → accent, futuro → muted 40%
    — Emoji do mood: 16pt, centralizado no espaço restante.
      Se moodEmojis[date] != null: exibir emoji
      Se nulo: SizedBox vazio (sem "–")
    — Dots row: no fundo da célula, Row centralizada, gap 2pt.
      Um dot 4pt por fonte com dados naquele dia (máximo 4; 5+ → mostrar "+" em 8pt muted).
      Cor: source.color ?? AppColors.primary
      Opacidade do dot: proporcional ao valor se disponível (min 35%, max 100%),
      ou 80% se valor binário.

  Fundo heatmap da célula:
    — Determinar série principal: primeira fonte não-mood em sources (ex: tracker de fluxo).
    — Se há dado dessa fonte na data: fundo = source.color ?? AppColors.primary,
      opacidade = (value / maxValueInMonth) * 0.12, mínimo 0.03.
    — Se não há: fundo transparente.

  Estado hoje: borda 1pt accent, fundo accent withValues(alpha: 0.10).
  Estado futuro (sem dados): número do dia a 40% de opacidade.

MINI BOTTOM SHEET (ao tap numa célula):
  showModalBottomSheet, height ~35% da tela, handle pill.
  Conteúdo:
    — Data completa: "Monday, May 19" (17pt semibold)
    — Se há emoji de mood: emoji grande (32pt) + label do mood (15pt semibold)
      + "Pleasantness N · Energy N" (13pt muted)
      Buscar label do mood via moodsProvider usando o slug armazenado.
    — Para cada fonte com dados: nome da fonte (11pt semibold muted all-caps)
      + valor formatado (15pt)
    — Link "View entries for this day →" (accent, 14pt) que fecha o sheet
      e navega para planner_screen na data correspondente.
    — Se sem dados: "No data recorded for this day." (14pt muted, centrado)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 13 — STEERING SHEET: VISUAL POLISH
Arquivo: lib/ui/widgets/steering_sheet.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
A steering sheet funciona (3 etapas, endedReason, previousCycles), mas faltam:
dots de progresso visuais, confirmação ao fechar, e botão "Continuar" da Etapa 1
desabilitado quando text area vazia.

MUDANÇAS

1. Substituir o texto "Etapa X de 3" por indicador de 3 dots lineares:
   Row(mainAxisAlignment: center, children: List.generate(3, (i) => Container(
     width: i == _currentStep - 1 ? 8 : 6,
     height: i == _currentStep - 1 ? 8 : 6,
     margin: EdgeInsets.symmetric(horizontal: 3),
     decoration: BoxDecoration(
       shape: BoxShape.circle,
       color: i == _currentStep - 1 ? habitColor : habitColor.withValues(alpha: 0.3),
     ),
   )))

2. Botão "Continuar →" da Etapa 1 desabilitar quando _reflectionController.text.isEmpty.
   Já existe a verificação parcial; garantir que o botão fica cinza e não-clicável.

3. PopScope com confirmação ao fechar:
   PopScope(
     canPop: false,
     onPopInvokedWithResult: (_, __) async {
       final confirm = await showDialog<bool>(context: context, builder: (_) =>
         AlertDialog(
           title: Text('Leave review?'),
           content: Text('You can review this pact later. It will remain pending.'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep reviewing')),
             TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Leave')),
           ],
         ));
       if (confirm == true && context.mounted) Navigator.pop(context);
     },
     child: ...
   )


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 14 — PLANNER: ENERGY TINTS NOS TIME BLOCKS
Arquivo: lib/ui/screens/planner_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O modelo TimeBlock já tem energyLevel (high|medium|low|null) mas o Planner
não aplica nenhum tint visual ao bloco correspondente.
Quando ativo, tasks longas (duration >= 60min) ou alta prioridade em bloco
high energy recebem label "↑ Best time".

O EnergyMap widget já existe e é renderizável no Dashboard.

MUDANÇAS EM _buildTimeBlockSection():

1. Após calcular `block`, verificar block.energyLevel.
   Se energyLevel != null:
     Aplicar decoration ao Container externo do ExpansionTile:
       color: energyTintColor(block.energyLevel).withValues(alpha: 0.08)

   Criar função:
     Color energyTintColor(EnergyLevel level) => switch(level) {
       EnergyLevel.high   => const Color(0xFF4CAF50),
       EnergyLevel.medium => const Color(0xFFFFC107),
       EnergyLevel.low    => const Color(0xFFFF7043),
     }

2. Label de energia no header do bloco (após o título):
   Se energyLevel == EnergyLevel.high:
     adicionar pequeno chip após o título do bloco:
     Container(
       padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
       decoration: BoxDecoration(
         color: Color(0xFF4CAF50).withValues(alpha: 0.15),
         borderRadius: BorderRadius.circular(6),
       ),
       child: Text('⚡ High energy', style: TextStyle(fontSize: 10,
         color: Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
     )

3. Para tasks individuais dentro de um bloco high energy:
   Se task.priority == TaskPriority.high OU task.duration >= 60:
     Adicionar label inline "↑ Best time" (10pt, verde, muted) abaixo do título
     da task dentro do card.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 15 — ORGANIZER DETAIL: PROPERTIES SECTION + NOTES SECTION + PERIOD SELECTOR
Arquivo: lib/ui/screens/organizer_detail_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O OrganizerDetailScreen tem 4 tabs (Timeline, Items, Outgoing, Children) mas
não tem Properties section dedicada nem Notes section separada. O tab "Timeline"
também não tem seletor de período.

MUDANÇAS

PARTE A — PROPERTIES SECTION (topo, fora das tabs)

Antes do TabBar, inserir Properties card:
  Card com border radius 16, padding 16, margem 16 horizontal.

  Para cada tipo de organizer, exibir propriedades relevantes em grid 2 colunas:
    Area/Activity/Label:  nome, description, ícone
    Project: state (badge colorida), priority (badge), start_date, due_date,
             progress bar (se há primary_kpi associado)
    Goal: status badge, KPI principal (barra linear + %)
    Habit: status badge, streak ("Ndays"), habitMode badge ("PACT" se pact),
           days since (badge colorida conforme Feature 9)
    Tracker: description, número de sections

  Cada propriedade: label (12pt semibold muted all-caps) + valor (15pt) embaixo.
  Se propriedade is null ou vazia: não exibir.
  Tap em qualquer propriedade editável → abrir CreateOrganizerForm pre-preenchido.

PARTE B — NOTES SECTION

Adicionar 5º tab "Notes" ao TabController (length: 5).
Conteúdo: lista de Notes que têm este organizer em seus organizers[] (via WikiLink).
  Buscar com: ref.watch(notesForOrganizerProvider(organizer.id))
  Se provider não existir: criar derivado de allObjectsProvider filtrando
  Note onde note.organizers.any((o) => o.id == organizer.id || o.slug == organizer.slug)

  Cada row: ícone do subtipo (📝/🗂/🗃) + título (15pt) + preview 1 linha (13pt muted)
  + data relativa (12pt muted trailing). Tap → navega para a Note.
  Empty state: "No notes linked to this [type] yet."

PARTE C — PERIOD SELECTOR NA TAB TIMELINE

No topo do content da tab Timeline (dentro do _buildTimeline widget),
adicionar row de chips horizontais: "7d" | "1m" | "3m" | "All"
Manter _selectedPeriod em state (default: "all").
Filtrar allItems por data de criação/atualização de acordo com o período.
Estilo dos chips: FilterChip sem borda, ativo = fundo accent, texto branco.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 16 — POMODORO: RING CUSTOMIZADO + OVERLAY + CONCLUSÃO
Arquivo: lib/ui/screens/pomodoro_screen.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O timer usa CircularProgressIndicator nativo sem strokeLineCap round e sem
cores distintas por fase. A tela é um Scaffold normal, não um overlay.
O diálogo de parar não mostra quantos blocos/minutos serão salvos.
A conclusão não tem animação nem opção "One more round".

PARTE A — RING COM CUSTOM PAINTER

Substituir o CircularProgressIndicator + SizedBox(240×240) por CustomPaint:

  CustomPaint(
    size: Size(240, 240),
    painter: _PomodoroRingPainter(
      progress: state.remainingSeconds / state.totalSeconds,
      phaseColor: _phaseColor(state.currentType),
    ),
    child: Center(child: _buildCountdownText(state)),
  )

  class _PomodoroRingPainter extends CustomPainter {
    final double progress;  // 1.0 = início, 0.0 = fim
    final Color phaseColor;

    @override
    void paint(Canvas canvas, Size size) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2 - 8;
      const strokeWidth = 8.0;
      const startAngle = -pi / 2;  // começa no topo

      // Fundo do ring (15% da cor)
      final bgPaint = Paint()
        ..color = phaseColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0, 2 * pi, false, bgPaint);

      // Progresso
      final fgPaint = Paint()
        ..color = phaseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, progress * 2 * pi, false, fgPaint);
    }

    @override
    bool shouldRepaint(_PomodoroRingPainter old) =>
      old.progress != progress || old.phaseColor != phaseColor;
  }

  Cores por fase (criar _phaseColor):
    PomodoroType.work       → Color(0xFF4CAF50)  // verde
    PomodoroType.shortBreak → Color(0xFFFB923C)  // laranja
    PomodoroType.longBreak  → Color(0xFF60A5FA)  // azul

PARTE B — DOT ATUAL COM ANIMAÇÃO DE PULSO

Nos session dots, envolver o dot atual com AnimatedBuilder usando um
AnimationController que faz scale 1.0 → 1.15 → 1.0 em loop (2s):

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override void initState() {
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnim = Tween(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  Para o dot atual: ScaleTransition(scale: _pulseAnim, child: dot)

PARTE C — DIÁLOGO DE PARAR: MOSTRAR BLOCOS/MIN SALVOS

Em _showStopDialog(), atualizar conteúdo:
  title: "Stop session?"
  content: "${state.completedSessions} blocks · ${state.workedMinutes}min worked so far."
  Botões: "Cancel" (textButton) | "Discard" (vermelho, sem salvar) | "Save partial" (verde)

PARTE D — OVERLAY DE CONCLUSÃO ANIMADO

Ao completar todos os blocos (verificar onde o provider emite este estado),
substituir o dialog atual por um overlay full-screen:
  — Verde tint 10% sobre a tela
  — Ícone ✓ com AnimationController: scale 0 → 1.2 → 1.0 (400ms spring)
  — "Session complete!" (22pt semibold)
  — "X blocks · Y min worked" (15pt muted)
  — Dois botões full-width em coluna:
      "Done" (outline, border radius 12pt, 16pt)
      "One more round" (fundo accent, branco, 16pt semibold)
    Tap "One more round" → reinicia sessão com os mesmos parâmetros.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 17 — PEOPLE: SCHEDULER AUTOMÁTICO DE CONTATOS
Arquivo: lib/ui/screens/people_screen.dart
         lib/services/scheduler_service.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
Quando lastContactDate + contactFrequency <= hoje, o app deve criar
automaticamente uma Task "Contact [Name]". Completar a task atualiza
lastContactDate da pessoa.

A people_screen.dart já tem urgencyColor e urgencyLabel funcionando (verde/amarelo/vermelho).
Falta: a criação automática da Task.

IMPLEMENTAÇÃO

Em scheduler_service.dart (ou criar método dedicado em vault_provider.dart),
adicionar método checkAndCreatePeopleReminders():

  Future<void> checkAndCreatePeopleReminders() async {
    final people = ref.read(peopleProvider);
    final tasks = ref.read(tasksProvider);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final person in people) {
      if (person.contactFrequency == null) continue;

      final lastContact = person.lastContactDate;
      final freq = person.contactFrequency!;
      final dueDate = lastContact != null
        ? lastContact.add(freq)
        : DateTime(2000); // nunca contatado → sempre devido

      if (!dueDate.isBefore(todayDate)) continue; // não venceu ainda

      // Verificar se já existe task ativa de contato para essa pessoa
      final alreadyExists = tasks.any((t) =>
        t.title.contains(person.title) &&
        t.title.toLowerCase().contains('contact') &&
        t.stage != TaskStage.finalized &&
        !t.archived);
      if (alreadyExists) continue;

      // Criar task
      final task = Task(
        title: 'Contact ${person.title}',
        stage: TaskStage.todo,
        priority: TaskPriority.none,
        endDate: todayDate,
        organizers: person.organizers,
      );
      await ref.read(vaultProvider.notifier).addObject(task);
    }
  }

  Chamar checkAndCreatePeopleReminders() no startup do app, após o vault carregar.
  Também chamar quando o vault é atualizado (usar ref.listen).

  Ao completar uma Task "Contact [Name]":
    — Verificar se o title começa com "Contact " e se há pessoa com esse nome.
    — Se sim, atualizar person.lastContactDate = DateTime.now() e salvar.
    — Fazer isso em vault_provider quando um Task é marcado como finalized.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 18 — GOAL PLAN MODE: UI DE OBJECTIVE/STRATEGY/PHASES
Arquivo: lib/ui/screens/goals_screen.dart
         lib/ui/forms/create_goal_form.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O modelo Goal já tem goalMode, objective, strategy e phases, mas a UI
de detalhe e o formulário de criação não renderizam essas seções quando
goalMode == GoalMode.plan.

PARTE A — DETAIL VIEW (goals_screen.dart ou universal_detail_view.dart)

Ao exibir um Goal com goalMode == GoalMode.plan, adicionar seções extras
na detail view após as seções padrão (KPIs, tasks, etc.):

  — Seção OBJECTIVE:
    Label "OBJECTIVE" (12pt semibold muted all-caps)
    Text field read-only com o texto de goal.objective (15pt, line-height 1.5)
    Borda-esquerda 3pt accent

  — Seção STRATEGY:
    Label "STRATEGY" (12pt semibold muted all-caps)
    Text field read-only com goal.strategy (15pt, line-height 1.5)
    Borda-esquerda 3pt accent

  — Seção PHASES:
    Label "PHASES" (12pt semibold muted all-caps)
    Lista numerada de goal.phases (cada phase: índice 14pt semibold muted
    + texto 15pt). Borda-esquerda 3pt na cor do goal.

  Header visual: o card do goal em modo plan deve ter borda-esquerda 3pt roxa
  (cor do goal ou AppColors.primary) para distinguir visualmente do standard.

PARTE B — FORMULÁRIO DE CRIAÇÃO (create_goal_form.dart)

Adicionar toggle "Goal mode" no formulário:
  SegmentedButton com opções "Standard" | "Plan"
  Quando "Plan" selecionado, revelar com slide down (200ms):
    — TextField "Objective": "What specifically do you want to achieve?"
    — TextField "Strategy": "How will you get there?"
    — Multi-item input "Phases": lista de text fields onde cada um é uma fase.
      "＋ Add phase" ao final. X para remover cada fase.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 19 — TASK BACKLOG DIALOG: AJUSTAR PARA SPEC
Arquivo: lib/ui/forms/create_task_form.dart
Status: ✅ IMPLEMENTADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBJETIVO
O diálogo de backlog já existe mas é um AlertDialog genérico com "Keep in list" /
"Go to Backlog". A spec pede: "Backlog or Today" com default "Today" se dismissido.

MUDANÇAS EM _saveTask():

  Substituir o showDialog atual por:
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,  // dismiss = "Today"
    builder: (_) => AlertDialog(
      title: Text('No date set'),
      content: Text('Where do you want to save this task?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'backlog'),
          child: Text('Backlog'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'today'),
          child: Text('Today'),
        ),
      ],
    ),
  );
  // result == null significa que o usuário dismissou (default = 'today')
  if (result == 'backlog') {
    setState(() => _stage = TaskStage.backlog);
  } else {
    // 'today' ou null: atribuir endDate = hoje se ainda nulo
    setState(() => _endDate = DateTime.now());
  }


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORDEM DE IMPLEMENTAÇÃO SUGERIDA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Do menos arriscado ao mais complexo:

 1. Feature 4  — Dashboard reset (cirúrgico, sem risco)
 2. Feature 7  — Crash reports share (adicionar share_plus + strings)
 3. Feature 8  — More screen: Day Themes + Day Blocks (simples inserção)
 4. Feature 19 — Task backlog dialog (1 método, 10 linhas)
 5. Feature 2  — Planner overflow (bug fix de layout)
 6. Feature 1  — Conflict buttons (UI only)
 7. Feature 3A+B — Mood seed + descriptions (dados, sem UI nova)
 8. Feature 3C  — Mood settings: quadrantes + system moods + toggle hidden
 9. Feature 3D  — Mood formulário usuário (full-screen)
10. Feature 3E  — Mood no chart: chip toggle + MoodEmojiTimeline
11. Feature 9A  — Habit swipe right para completar
12. Feature 9B  — Habit days since badge cor correta + "Done today"
13. Feature 9C  — Pact expired banner no detail sheet
14. Feature 10A — System swipe right quick-run
15. Feature 10B — System histórico de tasks
16. Feature 10C — System stats: chip "Estimated"
17. Feature 11  — Triple check: dismissal guard + ícones no card + stuck badge
18. Feature 13  — Steering sheet: dots + PopScope + botão disabled
19. Feature 14  — Planner: energy tints
20. Feature 15  — Organizer detail: Properties + Notes + period selector
21. Feature 18  — Goal plan mode UI
22. Feature 12  — Combined Analysis calendar: emoji + heatmap + tap + nav mês
23. Feature 16  — Pomodoro: ring custom + conclusão overlay
24. Feature 17  — People: scheduler automático de contatos
25. Feature 5   — Collection: add row + Obsidian Bases
26. Feature 6   — Salvar livros (novo serviço + widget, maior escopo)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTAS GERAIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Não usar o Anthropic API / Claude Vision em nenhuma feature (app é 100% gratuito).
- Google Books API: free tier, 1000 req/dia. Requer API key do Google Cloud Console.
- Obsidian Bases: plugin oficial, nativo no Obsidian 1.8+. Formato .base experimental;
  gerar arquivos conservadores (só source + properties).
- Todos os textos da UI em inglês (padrão do app). Corrigir qualquer string em
  português encontrada durante a implementação de cada feature.
- Ao criar novos arquivos em lib/services/ ou lib/ui/widgets/, registrar no
  arquivo correspondente de providers se necessário.
- CitrineChart já suporta emoji annotations via ChartDataPoint.emoji e belowBarData
  com fill — não duplicar lógica existente, apenas estender.
- habit_row.dart e habits_screen.dart: HabitRow é usado em outros lugares além
  da habits_screen (timeline, dashboard). O swipe Dismissible deve ser aplicado
  apenas em habits_screen._TodayHabitCard, não no HabitRow genérico.
- Triple Check batch via PMN (tasks paradas 7+ dias em formato de lista com
  checkbox no PMN form + indicador de progresso "Task 2 of 5") é um escopo
  adicional que pode ser implementado após as Features 11 e a Feature de PMN
  form estiverem completas. Não incluído nesta versão do doc por dependência.



================================================================================
GAP ANALYSIS — ADENDO V2 (Phases 12–16 consolidadas)
Audiência: agente de IA com acesso total ao repositório.
Origem: auditoria linha a linha do código real (lib/models/*.dart — 35
        arquivos, 100% lidos — mais leitura completa de
        obsidian_service.dart, vault_provider.dart, markdown_parser.dart,
        dataview_generator.dart, system_model.dart, scheduler.dart, e 6
        arquivos de UI: triple_check_sheet.dart, steering_sheet.dart,
        create_menu_sheet.dart, command_center_overlay.dart, habit_row.dart,
        type_signatures_screen.dart) comparada item a item com
        guidelines.md (App Guidelines V4) e com o GAP ANALYSIS original
        (Phases 1–11).
Convenção: igual ao documento original — cada tarefa é FILE + ACTION +
        ANCHOR + INSTRUCTION, autocontida (as correções entre tarefas já
        foram fundidas no texto; não é necessário voltar a nenhuma Phase
        12–16 separada, este documento já as substitui).

STATUS DE EXECUÇÃO (2026-06-25):
  • Decisão 0.3: manter Idea/Inbox/Event/ShoppingList como extensões legadas
    ativas por compatibilidade de produto, sem removê-las nesta rodada.
  • TIER 0 e TIER 1 foram revalidados contra o código atual; itens já
    implementados foram marcados no próprio item para evitar retrabalho.

────────────────────────────────────────────────────────────────────────────────
⚠ COMO ESTE DOCUMENTO SE RELACIONA COM O GAP ANALYSIS ORIGINAL (Phases 1–11)
────────────────────────────────────────────────────────────────────────────────
O GAP ANALYSIS original (Phases 1–11) foi escrito sem ler o código-fonte
real — foi derivado por inferência a partir da guidelines.md e de uma
inspeção parcial. Esta auditoria (Phases 12–16, consolidadas aqui) LEU o
código real, arquivo por arquivo, e encontrou:

  (a) Vários itens das Phases 1–11 CONFIRMADOS como corretos e necessários
      (ex.: Phase 9 Tasks 9.A.6–9.A.9, 9.B.1, 9.C.10; Phase 11 Tasks
      11.1–11.4) — implementá-los como estão escritos.

  (b) Pelo menos 2 itens das Phases 1–11 com a LOCALIZAÇÃO/CLASSE ERRADA
      (apontavam para um arquivo ou nome de símbolo que não existe no
      código real). Esses foram corrigidos aqui (ver TIER 1 e TIER 2 —
      procurar "SUBSTITUI A PHASE 9").

  (c) Achados TOTALMENTE NOVOS, nunca mencionados nas Phases 1–11, vários
      deles P0 (bloqueiam compilação ou inutilizam features inteiras em
      runtime mesmo que pareçam "prontas" na UI).

  ESTE ADENDO (Phases 12–16) TEM PRIORIDADE DE IMPLEMENTAÇÃO MAIOR QUE O
  GAP ANALYSIS ORIGINAL. Motivo: as Phases 1–11 originais assumem, em
  vários pontos, uma base de código que SIMPLESMENTE NÃO EXISTE como
  escrito (ex.: assumem que `Habit` já tem campos de Pact; assumem que
  `Task` já tem `TripleCheck`; assumem uma classe `SchedulerRuleType` que
  não existe). Se alguém tentar implementar a Phase 9, por exemplo, ANTES
  de aplicar o TIER 0 deste documento, vai encontrar erros de compilação
  ou comportamento inconsistente que não fazem sentido sem este contexto.

  ORDEM RECOMENDADA DE EXECUÇÃO GERAL:
    1. Este documento (Adendo V2) — TIER 0, depois TIER 1.
    2. GAP ANALYSIS original, Phases 1–11 (na ordem em que já estão).
    3. Este documento (Adendo V2) — TIER 2 e TIER 3.
  (Itens do TIER 1 deste adendo tocam arquivos centrais — vault_provider.dart,
  obsidian_service.dart, habit_model.dart, task_model.dart — que a Phase 9
  original também edita. Aplicar o TIER 0/1 primeiro evita retrabalho.)

================================================================================
LISTA DE PRIORIDADE DE IMPLEMENTAÇÃO (visão geral)
================================================================================

TIER 0 — BLOQUEADORES DE COMPILAÇÃO (fazer primeiro, sem exceção):
  0.1  Habit: adicionar todo o subsistema Pact (campos ausentes que a UI
       já usa em produção — steering_sheet.dart E habit_row.dart)
  0.2  Task: adicionar classe TripleCheck (campo ausente que
       triple_check_sheet.dart já usa em produção)
  0.3  DECISÃO DE PRODUTO necessária antes de seguir: o que fazer com
       Idea/Inbox/Event/ShoppingList (tipos fora da spec V4)

TIER 1 — INTEGRIDADE DE DADOS DO VAULT (núcleo de parsing/storage):
  1.1  Estrutura de pastas: `app/` flat como default, não pasta-por-tipo
       (3 arquivos precisam mudar juntos: obsidian_service.dart,
       vault_provider.dart, dataview_generator.dart)
  1.2  PMN (`daily/YYYY-MM-WNN.md`) é invisível ao app — corrigir regex
  1.3  Field Note/PMN: entry_type nunca é lido pelo parser principal
  1.4  `type: system` e `type: calendar_session` ausentes do dispatcher
       central — viram Note genérica com organizador placeholder bugado
  1.5  Habit completions gravadas aninhadas (`habits:`) em vez de chaves
       planas na raiz do frontmatter — quebra todo Dataview de exemplo
  1.6  Daily note template não gera o formato canônico (tags, mood_*,
       esqueleto de seções)
  1.7  IDs são UUID aleatório; WikiLinks devem usar slug estável
  1.8  OrganizerReference.toWikiLink() grava "[[tipo/slug]]" em vez de
       "[[slug]]" — quebra backlinks nativos do Obsidian em todo o vault

TIER 2 — FEATURES INCOMPLETAS (P1):
  2.1  PomodoroSession não persiste em lugar nenhum
  2.2  KPI: taxonomia incompatível, falta auto-complete e botão "+N"
  2.3  Dashboard: falta painel pact_today; dashboard_panel.dart morto
  2.4  Combined Analysis: faltam campos de normalização/dimensão; falta
       bloco do plugin Obsidian Charts (o bloco Tracker já existe)
  2.5  Conflict Detection (Object Identification) não existe em lugar
       nenhum do app
  2.6  Command Center: faltam seções Systems/Próximas Sessões; busca não
       agrupa por tipo
  2.7  Scheduler: serialização camelCase em vez de snake_case (local
       correto: SchedulerRule.repeatType, não "SchedulerRuleType")
  2.8  Auto-categoria "[[people]]" nunca aplicada a Person; outras 4
       entidades ganham auto-categorias que a spec não pede
  2.9  Falta hook "checar Pacts vencidos a cada abertura do app"
  2.10 Subtasks de Task não usam sintaxe do Tasks Plugin do Obsidian
  2.11 Índice Dataview de mood usa campo antigo de 1 dimensão
  2.12 Faltam índices Dataview de Systems e Pacts
  2.13 Sistema de Actions: só 2 dos 7 tipos implementados; falta trigger
       de Tracker (só Habit dispara hoje)
  2.14 Strings em inglês misturadas com o resto do app em português
       (automation_service.dart)
  2.15 checkKPIGoals() auto-completa o Goal inteiro sem confirmação —
       comportamento não documentado na spec (decisão de produto)

CONFIRMADO FUNCIONANDO (sem gap): `AutomationService.checkPersonContacts()`
  implementa corretamente o "Scheduler automático" de Person da PARTE 8
  (cria Task "Contatar [Nome]" via detecção de menção/backlink) — não
  precisa de nenhuma ação.

TIER 3 — POLIMENTO E DETALHES (P2):
  3.1  ContentObject sem campo `links` universal
  3.2  Project sem campo `scheduler`
  3.3  Person sem campo `notes`
  3.4  Snapshot sem `photos`; `subject` não é WikiLink real
  3.5  ReminderConfig.ringOnSilent com default errado
  3.6  Triple Check Sheet: botões de ação são stubs vazios; sem proteção
       de dismiss; sem validação; sem modo batch/read-only
  3.7  Steering Sheet: sem botão X; sem validação por etapa; default de
       duração errado
  3.8  FAB: falta card "System"; "Sessão" abre Pomodoro em vez de
       Calendar Session
  3.9  create_system_form.dart não existe — impossível criar System pela UI
  3.10 Object Identification: tradução de tipos incompleta (faltam
       system/tracker/entry/reminder)
  3.11 Corpo da daily note (seção ## Habits) usa WikiLink em vez do
       título do habit
  3.12 SystemDefinition.scheduler é extensão não documentada

COBERTURA: este adendo leu 100% dos models e leitura profunda de 6
  serviços/providers centrais + 6 widgets/telas de UI. NÃO leu ainda:
  automation_service.dart, notification_service.dart, scheduler_service.dart,
  sync_manager.dart, google_drive_sync_service.dart, os ~24 arquivos de
  lib/ui/forms/, e a maior parte de lib/ui/screens/ e lib/ui/widgets/.
  Tratar como uma Phase 17+ futura, depois de TIER 0–2 estarem implementados.

================================================================================
TIER 0 — BLOQUEADORES DE COMPILAÇÃO
================================================================================

────────────────────────────────────────────────────────────────────────────────
0.1 — HABIT: ADICIONAR TODO O SUBSISTEMA PACT
────────────────────────────────────────────────────────────────────────────────
FILE: lib/models/habit_model.dart
ACTION: EDIT
STATUS: ✅ VERIFICADO NO CÓDIGO — `HabitMode`, `PactOutcome`, `PactCycle`, campos Pact,
  `displayTitle`, copyWith e serialização/leitura simétrica já existem.

POR QUE É P0: lib/ui/widgets/steering_sheet.dart E lib/ui/widgets/habit_row.dart
  (dois arquivos de UI usados em produção) já referenciam, hoje:
  widget.habit.startedAt, widget.habit.endsAt, widget.habit.previousCycles,
  widget.habit.hypothesis, widget.habit.displayTitle, widget.habit.habitMode,
  HabitMode.pact, e constroem PactCycle(...) / usam PactOutcome.persist
  /.pause/.pivot — NENHUM desses símbolos existe em habit_model.dart hoje
  (a classe Habit só tem: description, color, icon, completionUnit,
  dailyGoal, slots, schedulers, linkedTrackerSlug, timeBlock,
  completionHistory, actions, status, habitStartDate, priority, streak,
  isNegative, inputType). Ou o projeto não compila, ou esses dois widgets
  são código morto e a feature Pact inteira (Steering Sheet, badge "PACT",
  Pact no Planner, dashboard pact_today) não funciona de fato.

ADD enums:
  enum HabitMode { habit, pact }
  enum PactOutcome { persist, pause, pivot }

ADD classe:
  class PactCycle {
    final DateTime startedAt;
    final DateTime endsAt;
    final PactOutcome outcome;
    final String? reflection;
    final bool? hypothesisCorrect;
    final String? endedReason;

    PactCycle({
      required this.startedAt,
      required this.endsAt,
      required this.outcome,
      this.reflection,
      this.hypothesisCorrect,
      this.endedReason,
    });

    Map<String, dynamic> toMap() => {
      'started_at': startedAt.toIso8601String().split('T').first,
      'ends_at': endsAt.toIso8601String().split('T').first,
      'outcome': outcome.name,
      if (reflection != null) 'reflection': reflection,
      if (hypothesisCorrect != null) 'hypothesis_correct': hypothesisCorrect,
      if (endedReason != null) 'ended_reason': endedReason,
    };

    factory PactCycle.fromMap(Map<String, dynamic> map) => PactCycle(
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(map['ends_at']?.toString() ?? '') ?? DateTime.now(),
      outcome: PactOutcome.values.firstWhere(
        (e) => e.name == map['outcome'], orElse: () => PactOutcome.pause),
      reflection: map['reflection']?.toString(),
      hypothesisCorrect: map['hypothesis_correct'] as bool?,
      endedReason: map['ended_reason']?.toString(),
    );
  }

ADD fields à classe Habit (Regra 3 do guidelines: habit_mode ausente →
  tratar como `habit`):
  HabitMode habitMode = HabitMode.habit;
  String? curiosityQuestion;
  String? hypothesis;
  DateTime? startedAt;
  DateTime? endsAt;
  PactOutcome? pactOutcome;
  List<PactCycle> previousCycles = [];

EDIT construtor: adicionar os 7 parâmetros acima com defaults
  (habitMode = HabitMode.habit, previousCycles = const []).

ADD getter:
  String get displayTitle => title;

EDIT copyWith(): adicionar os 7 novos parâmetros.

EDIT toMarkdown(): ADD (apenas quando habitMode == HabitMode.pact):
    frontmatter['habit_mode'] = habitMode.name;
    if (habitMode == HabitMode.pact) {
      if (curiosityQuestion != null) frontmatter['curiosity_question'] = curiosityQuestion;
      if (hypothesis != null) frontmatter['hypothesis'] = hypothesis;
      if (startedAt != null) frontmatter['started_at'] = startedAt!.toIso8601String().split('T').first;
      if (endsAt != null) frontmatter['ends_at'] = endsAt!.toIso8601String().split('T').first;
      frontmatter['pact_outcome'] = pactOutcome?.name;
      frontmatter['previous_cycles'] = previousCycles.map((c) => c.toMap()).toList();
    }

EDIT fromMarkdown(): ADD leitura simétrica (Regra 3 — default `habit`):
    final rawMode = frontmatter['habit_mode']?.toString() ?? 'habit';
    habit.habitMode = HabitMode.values.firstWhere(
      (m) => m.name == rawMode, orElse: () => HabitMode.habit);
    habit.curiosityQuestion = frontmatter['curiosity_question']?.toString();
    habit.hypothesis = frontmatter['hypothesis']?.toString();
    if (frontmatter['started_at'] != null) {
      habit.startedAt = DateTime.tryParse(frontmatter['started_at'].toString());
    }
    if (frontmatter['ends_at'] != null) {
      habit.endsAt = DateTime.tryParse(frontmatter['ends_at'].toString());
    }
    if (frontmatter['pact_outcome'] != null) {
      habit.pactOutcome = PactOutcome.values.firstWhereOrNull(
        (e) => e.name == frontmatter['pact_outcome']);
    }
    if (frontmatter['previous_cycles'] is List) {
      habit.previousCycles = (frontmatter['previous_cycles'] as List)
          .whereType<Map>()
          .map((c) => PactCycle.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    }
  (usar `firstWhereOrNull` de package:collection, ou implementar
  manualmente um try/catch retornando null, já que `firstWhere` puro do
  Dart não aceita `orElse: () => null` em enum não-nullable.)

VALIDAÇÃO: depois de aplicar, rodar `flutter analyze` e confirmar que
  steering_sheet.dart e habit_row.dart não têm mais nenhum erro de símbolo
  não resolvido.

────────────────────────────────────────────────────────────────────────────────
0.2 — TASK: ADICIONAR CLASSE TripleCheck
────────────────────────────────────────────────────────────────────────────────
FILE: lib/models/task_model.dart
ACTION: EDIT
STATUS: ✅ VERIFICADO NO CÓDIGO — `TripleCheckAnswer`, `TripleCheck`, `Task.tripleCheck`,
  `TaskStage.backlog` e `linkedSystem` já existem; `flutter analyze` não
  reporta símbolos ausentes em `triple_check_sheet.dart`.

POR QUE É P0: lib/ui/widgets/triple_check_sheet.dart já referencia, em
  produção: widget.task.tripleCheck, TripleCheckAnswer (enum .yes/.unsure
  /.no), TripleCheck(head:, heart:, hand:, diagnosis:, checkedAt:), e
  widget.task.copyWith(tripleCheck: tc) — nenhum desses símbolos existe em
  task_model.dart hoje.

ADD enum:
  enum TripleCheckAnswer { yes, unsure, no }

ADD classe:
  class TripleCheck {
    final TripleCheckAnswer head;
    final TripleCheckAnswer heart;
    final TripleCheckAnswer hand;
    final String diagnosis;
    final DateTime checkedAt;

    TripleCheck({
      required this.head,
      required this.heart,
      required this.hand,
      required this.diagnosis,
      required this.checkedAt,
    });

    // Regra 7 do guidelines + diagnóstico derivado single-value (head >
    // heart > hand em ordem de prioridade — "incerto" conta como bloqueio).
    String? get blocker {
      if (head != TripleCheckAnswer.yes) return 'head';
      if (heart != TripleCheckAnswer.yes) return 'heart';
      if (hand != TripleCheckAnswer.yes) return 'hand';
      return null;
    }

    Map<String, dynamic> toMap() => {
      'head': head == TripleCheckAnswer.yes,
      'heart': heart == TripleCheckAnswer.yes,
      'hand': hand == TripleCheckAnswer.yes,
      'blocker': blocker,
      'diagnosis': diagnosis,
      'checked_at': checkedAt.toIso8601String(),
    };

    factory TripleCheck.fromMap(Map<String, dynamic> map) {
      TripleCheckAnswer fromBool(dynamic v) =>
          v == true ? TripleCheckAnswer.yes : TripleCheckAnswer.no;
      return TripleCheck(
        head: fromBool(map['head']),
        heart: fromBool(map['heart']),
        hand: fromBool(map['hand']),
        diagnosis: map['diagnosis']?.toString() ?? '',
        checkedAt: DateTime.tryParse(map['checked_at']?.toString() ?? '') ?? DateTime.now(),
      );
    }
  }
  NOTA: ao serializar, "incerto" (unsure) vira `false` no frontmatter
  (booleano puro, igual a "no") — perda de fidelidade aceita e documentada
  aqui, pois a spec grava head/heart/hand como booleanos puros no exemplo
  de frontmatter.

ADD field à classe Task: `TripleCheck? tripleCheck;`
EDIT construtor: adicionar `this.tripleCheck,`.
EDIT copyWith(): adicionar `TripleCheck? tripleCheck` — como `copyWith`
  precisa também conseguir LIMPAR o campo de propósito (ex.: "Re-executar
  diagnóstico"), adicionar um parâmetro extra:
  `bool clearTripleCheck = false`, e usar
  `tripleCheck: clearTripleCheck ? null : (tripleCheck ?? this.tripleCheck)`.

EDIT toMarkdown(): ADD
  if (tripleCheck != null) frontmatter['triple_check'] = tripleCheck!.toMap();
  // Regra 7: ausente → nunca exibir badge nem diagnóstico.

EDIT fromMarkdown(): ADD
  if (frontmatter['triple_check'] is Map) {
    task.tripleCheck = TripleCheck.fromMap(
      Map<String, dynamic>.from(frontmatter['triple_check'] as Map));
  }

TAMBÉM NESTE ARQUIVO — confirmar/adicionar (já estava correto na Phase 9
  Task 9.B.1, reconfirmado por leitura direta): `TaskStage` precisa incluir
  `backlog`. Enum atual é `{idea, todo, inProgress, pending, finalized}` —
  ADD `backlog` (posição recomendada: logo após `idea`, antes de `todo`).

ADD também (já especificado na Phase 9 Task 9.B.2, reconfirmado ausente
  por leitura direta): campo `String? linkedSystem;` na classe Task, com
  leitura/escrita simétrica em toMarkdown()/fromMarkdown()/copyWith()
  (chave de frontmatter: `linked_system`).

DEPOIS de aplicar 0.1 e 0.2: editar lib/ui/widgets/triple_check_sheet.dart
  para não precisar mais calcular `blocker` manualmente (a classe já deriva
  via `tc.blocker`) e rodar `flutter analyze` para confirmar zero erros.

────────────────────────────────────────────────────────────────────────────────
0.3 — DECISÃO DE PRODUTO: Idea / Inbox / Event / ShoppingList (tipos fora
      da spec V4)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — OPÇÃO B. Manter Idea/Inbox/Event/ShoppingList como
  extensões legadas/ativas nesta rodada, porque há models, providers, telas
  e formulários existentes. Não remover nem migrar automaticamente agora.

SEVERIDADE: P0 (arquitetural) — decisão precisa ser tomada ANTES do TIER 1,
  porque a Task 1.4 (dispatcher central) e a Task 1.1 (estrutura de pastas)
  dependem de saber se esses 4 tipos continuam existindo ou são migrados.

EVIDÊNCIA: guidelines V4, PARTE 1.2, enumera EXATAMENTE 9 tipos de
  conteúdo e 10 de organizador. "Regra 1 — Este documento anula todas as
  versões anteriores." O código tem, com type/model/tela próprios:
  • lib/models/idea_model.dart (`type: idea`) + ideas_screen.dart — a
    spec já cobre esse caso com `Task.stage: idea`.
  • lib/models/inbox_model.dart (`type: inbox`) + inbox_screen.dart — sem
    equivalente na V4.
  • lib/models/event_model.dart (`type: event`) — sobrepõe quase 100% com
    CalendarSession (que a Phase 9 Task 9.A.6 manda criar do zero, sem
    nunca mencionar migrar Event).
  • lib/models/shopping_list_model.dart (`type: shopping_list`) +
    shopping_list_screen.dart + shopping_list_block.dart — sem
    equivalente na V4.

OPÇÃO A (recomendada — conformidade estrita): migrar e remover os 4:
  1. Idea → Task com `stage: idea`. Campos sem equivalente direto (horizon,
     convertedToType/Id) viram tags/organizers ou ficam em `notes`. Apagar
     idea_model.dart, ideas_screen.dart, IdeaStatus, IdeaHorizon.
  2. Inbox → migrar para Task (`stage: idea`/`backlog`) ou Note. Remover
     inbox_model.dart, inbox_screen.dart.
  3. Event → consolidar com CalendarSession (Task 1.4 abaixo cria o
     model): mapear startDatetime→date+timeOfDay, endDatetime→endTime,
     googleEventId→linkedGoogleEventId, etc. Migrar arquivos `type: event`
     existentes no vault para `type: calendar_session` (migração one-shot
     no carregamento). Remover event_model.dart e toda tela/form que cria
     `type: event`.
  4. ShoppingList → sem equivalente direto. Opções: Tracker com
     InputFieldType.checklist, ou Note subtipo Collection. Decidir e
     migrar; ou OPÇÃO B abaixo.

OPÇÃO B (se o produto realmente precisa desses 4 recursos): atualizar o
  PRÓPRIO guidelines.md, PARTE 1.2, incluindo-os formalmente como
  extensões da V4, com seção de especificação própria (propriedades,
  storage, UI) no mesmo padrão dos outros 9 objetos.

QUALQUER QUE SEJA A ESCOLHA: documentar a decisão no topo deste arquivo de
  gap analysis antes de prosseguir, porque ela muda o conteúdo exato das
  Tasks 1.1 e 1.4 abaixo (se Event for mantido, a Task 1.4 precisa também
  adicionar um dispatch para `type: event`, por exemplo).

================================================================================
TIER 1 — INTEGRIDADE DE DADOS DO VAULT
================================================================================

────────────────────────────────────────────────────────────────────────────────
1.1 — ESTRUTURA DE PASTAS: `app/` FLAT COMO PADRÃO (não pasta-por-tipo)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `_ensureVaultFolders()` usa `app/daily/moods/analyses`
  e pastas técnicas; defaults de escrita caem em `app` salvo exceções e
  índices Dataview usam `FROM "app"` por tipo.

SEVERIDADE: P0 — viola a PARTE 1.1 da guidelines, base de toda a
  arquitetura de Object Identification. Confirmado em 3 arquivos
  independentes que concordam entre si (não é bug isolado, é o
  comportamento real e consistente do app hoje).

EVIDÊNCIA:
  • obsidian_service.dart, `_ensureVaultFolders()`: cria incondicionalmente
    daily, habits, trackers, tasks, notes, moods, projects, people,
    organizers/areas, organizers/projects, organizers/activities,
    organizers/people, organizers/places, organizers/labels, resources,
    social, sessions, _attachments, _deleted. SEM `app/`, SEM `_conflicts/`.
  • vault_provider.dart, `VaultNotifier._defaultFolderForSignature()`:
    roteia escrita por tipo: task→tasks, habit→habits, goal→goals,
    note→notes, resource→resources, social_post→social,
    person→organizers/people, project→organizers/projects,
    area→organizers/areas, activity→organizers/activities,
    place→organizers/places, label→organizers/labels, organizer→organizers,
    tracker_definition/tracker_record→trackers, reminder→reminders,
    time_block→time_blocks, day_theme→day_themes, template→templates,
    snapshot→snapshots. (mood_definition→moods e combined_analysis→analyses
    ESTÃO CORRETOS — são exceções fixas da spec, NÃO mexer nesses dois.)
  • dataview_generator.dart: os 6 índices auto-gerados (`tasks/index.md`,
    `habits/index.md`, `goals/index.md`, `notes/index.md`,
    `social/index.md`, `daily/mood-index.md`) têm `FROM "tasks"` /
    `FROM "habits"` / etc. hardcoded.

  Spec (PARTE 1.1 + PARTE 20): default é `app/` flat para TODOS os tipos,
  exceto as exceções fixas `daily/`, `moods/`, `analyses/`,
  `_attachments/`, `_deleted/`, `_conflicts/`. Pasta-por-tipo só deveria
  existir quando o usuário CONFIGURA isso em Object Identification (Regra
  12: "o app nunca presume localização por tipo").

FILE: lib/services/obsidian_service.dart
ACTION: EDIT
ANCHOR: `_ensureVaultFolders()`, lista `folders`.
REPLACE por:
  const folders = [
    'app',
    'daily',
    'moods',
    'analyses',
    '_attachments',
    '_deleted',
    '_conflicts',
  ];

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: `VaultNotifier._defaultFolderForSignature()`.
REPLACE o corpo inteiro por:
  String _defaultFolderForSignature(String type) {
    return switch (type) {
      'mood_definition'   => 'moods',
      'combined_analysis' => 'analyses',
      _ => 'app',
    };
  }
  (`_writeObject()` já dá prioridade a uma `TypeSignature` de pasta
  configurada pelo usuário antes de cair nesse default — não precisa
  mexer em `prepareForSave`.)

FILE: lib/services/dataview_generator.dart
ACTION: EDIT
  1. Trocar em TODAS as 5 queries Dataview + a query DataviewJS de
     `_writeHabitsIndex()`:
       `FROM "tasks"`  → `FROM "app" WHERE type = "task"`
       `FROM "habits"` → `FROM "app" WHERE type = "habit"`
       `FROM "goals"`  → `FROM "app" WHERE type = "goal"`
       `FROM "notes"`  → `FROM "app" WHERE type = "note"`
       `FROM "social"` → `FROM "app" WHERE type = "social_post"`
       `dv.pages('"habits"')` → `dv.pages('"app"').where(p => p.type === "habit")`
  2. MELHOR: gerar a cláusula FROM dinamicamente a partir de Object
     Identification em vez de hardcoded:
       String _fromClauseFor(String type, Settings settings) {
         final sig = settings.typeSignatures[type];
         if (sig?.markerType == MarkerType.folder && sig?.value.isNotEmpty == true) {
           return 'FROM "${sig!.value}"';
         }
         return 'FROM "app" WHERE type = "$type"';
       }
     Requer passar `Settings` para os métodos `_writeXxxIndex()` (já são
     métodos de instância de `DataviewGenerator`, só precisam receber
     `Settings` via construtor ou parâmetro).

MIGRAÇÃO: não é necessário mover arquivos já existentes nas pastas antigas
  — `AllObjectsNotifier` escaneia o vault inteiro recursivamente e decide
  o tipo pelo `type` do frontmatter (ver Task 1.4), não pela pasta física,
  exceto quando há `TypeSignature` de pasta configurada. O pior caso é
  apenas: arquivos novos vão para `app/`, arquivos antigos continuam nas
  pastas antigas — ambos continuam sendo lidos normalmente.

────────────────────────────────────────────────────────────────────────────────
1.2 — PMN (`daily/YYYY-MM-WNN.md`) É INVISÍVEL AO APP
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `AllObjectsNotifier`Detecta `daily/YYYY-MM-WNN.md`,
  cria `JournalEntryType.pmn`, lê metadados PMN e usa
  `MarkdownParser.parsePmnSections()`.

SEVERIDADE: P0 — a feature de revisão semanal (Plus/Minus/Next) é gravada
  corretamente no disco mas NUNCA mais lida de volta.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: dentro de `AllObjectsNotifier.build()`, bloco:
    final isDaily = relativePath.split('/').contains('daily');
    ...
    if (isDaily || type == 'daily_note') {
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(relativePath);
      if (dateMatch != null) { ... }
      // hoje: se dateMatch for null (caso de um PMN "YYYY-MM-WNN"), nada
      // acontece — o arquivo é descartado silenciosamente.
    } else { ... }

REPLACE a checagem por:
    final pmnMatch = RegExp(r'(\d{4})-(\d{2})-W(\d{2})').firstMatch(relativePath);
    final isPmnFile = pmnMatch != null && relativePath.split('/').contains('daily');

    if (isPmnFile) {
      // Processar como PMN — ver passo abaixo.
      final entry = JournalEntry(
        id: frontmatter['id']?.toString() ?? stableIdFor(relativePath),
        body: '', // PMN não usa `body` solto — usa plus/minus/next no corpo.
        date: DateTime.tryParse(frontmatter['date_range_start']?.toString() ?? '') ?? DateTime.now(),
        title: 'PMN ${frontmatter['week'] ?? ''}',
        entryType: JournalEntryType.pmn, // depende do field entryType existir em JournalEntry
        obsidianPath: relativePath,
      );
      entry.week = frontmatter['week']?.toString();
      entry.dateRangeStart = DateTime.tryParse(frontmatter['date_range_start']?.toString() ?? '');
      entry.dateRangeEnd = DateTime.tryParse(frontmatter['date_range_end']?.toString() ?? '');
      entry.referencedDates = (frontmatter['referenced_dates'] as List? ?? [])
          .map((d) => d.toString()).toList();
      entry.pactRefs = (frontmatter['pact_refs'] as List? ?? [])
          .map((p) => p.toString()).toList();
      final pmnSections = MarkdownParser.parsePmnSections(body); // criar este método (ver abaixo)
      entry.plus = pmnSections['plus'] ?? [];
      entry.minus = pmnSections['minus'] ?? [];
      entry.next = pmnSections['next'] ?? [];
      results.add(entry);
    } else if (isDaily || type == 'daily_note') {
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(relativePath);
      if (dateMatch != null) { ... (lógica já existente, inalterada) ... }
    } else { ... (lógica já existente, inalterada) ... }

  (Os nomes exatos de campo em `JournalEntry` — `week`, `dateRangeStart`,
  `dateRangeEnd`, `referencedDates`, `pactRefs`, `plus`, `minus`, `next` —
  precisam ser conferidos/adicionados ao model `JournalEntry`
  individualmente se ainda não existirem; ver Task 1.3 abaixo, que já
  assume essa adição.)

FILE: lib/services/markdown_parser.dart
ACTION: ADD método novo:
  static Map<String, List<String>> parsePmnSections(String body) {
    final result = {'plus': <String>[], 'minus': <String>[], 'next': <String>[]};
    final sectionRegex = RegExp(r'^##\s*(Plus|Minus|Next)\s*$', multiLine: true, caseSensitive: false);
    final matches = sectionRegex.allMatches(body).toList();
    for (var i = 0; i < matches.length; i++) {
      final key = matches[i].group(1)!.toLowerCase();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      final sectionText = body.substring(start, end);
      final bullets = RegExp(r'^-\s*(.+)$', multiLine: true)
          .allMatches(sectionText)
          .map((m) => m.group(1)!.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      result[key] = bullets;
    }
    return result;
  }

ADD ÍNDICE em memória para o card "📋 Revisão WNN" ao abrir uma data:
  FILE: lib/providers/vault_provider.dart
  ADD provider:
    final pmnByReferencedDateProvider = Provider<Map<String, List<JournalEntry>>>((ref) {
      final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
      final map = <String, List<JournalEntry>>{};
      for (final entry in all.whereType<JournalEntry>()) {
        if (entry.entryType != JournalEntryType.pmn) continue;
        for (final dateStr in entry.referencedDates) {
          map.putIfAbsent(dateStr, () => []).add(entry);
        }
      }
      return map;
    });
  USAR este provider em Journal/Planner/Timeline (telas ainda não
  auditadas — ver "Cobertura" no topo) para exibir o card de revisão ao
  abrir qualquer data referenciada por uma PMN.

────────────────────────────────────────────────────────────────────────────────
1.3 — FIELD NOTE / PMN: entry_type NUNCA É LIDO PELO PARSER PRINCIPAL
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `parseJournalEntries()` extrai `entry_type`, `category`
  e `energy_value`; o loader propaga para `JournalEntry`.

SEVERIDADE: P0 — combinado com 1.2, confirma que Field Note e PMN (2 dos 3
  sub-modos de Entry) nunca chegam corretamente à UI em memória, mesmo
  gravados corretamente em disco.

FILE: lib/services/markdown_parser.dart
ACTION: EDIT
ANCHOR: `parseJournalEntries()`, dentro do loop de seções, bloco que monta
  `entries.add({...})` — hoje só extrai time/title/body/mood/organizers/
  hashtags/date.

ADD extração de `entry_type`/`category`/`energy_value` (mesmo padrão já
  usado para `mood::`):
    final entryTypeMatch = RegExp(r'^entry_type:\s*(.*)$', multiLine: true).firstMatch(section);
    final entryType = entryTypeMatch?.group(1)?.trim() ?? 'standard';
    final categoryMatch = RegExp(r'^category:\s*(.*)$', multiLine: true).firstMatch(section);
    final category = categoryMatch?.group(1)?.trim();
    final energyMatch = RegExp(r'^energy_value:\s*(\d+)$', multiLine: true).firstMatch(section);
    final energyValue = energyMatch != null ? int.tryParse(energyMatch.group(1)!) : null;

  ADD ao Map retornado: `'entry_type': entryType, 'category': category,
  'energy_value': energyValue,`. Excluir essas linhas do `body` extraído
  (mesmo tratamento já dado a `mood::`/`organizers::`, para não vazarem
  para dentro do corpo da entry).

FILE: lib/models/journal_entry.dart
ACTION: EDIT (caso os campos abaixo ainda não existam — conferir antes)
ADD (se ausentes): `JournalEntryType entryType = JournalEntryType.standard;`,
  `String? category;`, `int? energyValue;`, e para PMN: `String? week;`,
  `DateTime? dateRangeStart;`, `DateTime? dateRangeEnd;`,
  `List<String> referencedDates = [];`, `List<String> pactRefs = [];`,
  `List<String> plus = [];`, `List<String> minus = [];`, `List<String> next = [];`.
  Incluir em toMarkdown()/fromMarkdown()/copyWith() seguindo o mesmo
  padrão de serialização já usado nos outros campos do model. (Esta task
  depende/complementa a Phase 9 Task 9.A.1 e 9.A.2 originais do GAP
  ANALYSIS — que corrigem bugs de serialização do `entryType` já
  presumindo que o campo existe; aplicar PRIMEIRO esta adição de campo, se
  ele ainda não existir, antes da Phase 9.A.1/9.A.2.)

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: construção do `JournalEntry` dentro de `AllObjectsNotifier.build()`
  (branch de daily note normal, não-PMN).
ADD: `entryType:` mapeado de `data['entry_type']` (string → enum), e,
  quando `field_note`, propagar `category`/`energyValue` lidos de
  `data['category']`/`data['energy_value']`.

────────────────────────────────────────────────────────────────────────────────
1.4 — `type: system` E `type: calendar_session` AUSENTES DO DISPATCHER
      CENTRAL
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — dispatcher carrega `SystemDefinition` e
  `Event` (V5: CalendarSession foi absorvido por Event); fallback genérico
  de `Note` não injeta organizador placeholder.

SEVERIDADE: P0 — mesmo com o model de System corrigido e CalendarSession
  criado (Phase 9 Tasks 9.A.3/9.A.6), nenhum dos dois jamais carregaria
  corretamente, porque o dispatcher nem tenta reconhecê-los.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: dentro de `AllObjectsNotifier.build()`, a cadeia `if (type ==
  'task') {...} else if (type == 'habit') {...} else if ...` (cobre hoje:
  task, habit, project, person, organizer/area/activity/place/label,
  resource, social_post, goal, note, tracker_definition, mood_definition,
  reminder, tracker_record, combined_analysis, snapshot, time_block,
  day_theme, template — falta system e calendar_session).

ADD, antes do `else` final (fallback genérico):
  } else if (type == 'system') {
    // ATENÇÃO: SystemDefinition.fromMarkdown tem 3 parâmetros posicionais
    // (frontmatter, body, filePath) — diferente do padrão de 2 parâmetros
    // usado pelos outros tipos. NÃO usar `..obsidianPath =` depois.
    obj = SystemDefinition.fromMarkdown(frontmatter, body, relativePath);
  } else if (type == 'calendar_session') {
    obj = CalendarSession.fromMarkdown(frontmatter, body)
      ..obsidianPath = relativePath;
    // (depende da Phase 9 Task 9.A.6 já ter criado este model/factory.)
  }

ANCHOR: o `else` final (fallback genérico) — hoje cria:
    obj = Note(
      id: stableId,
      title: frontmatter['title'] ?? fallbackTitle,
      body: body,
      subtype: NoteSubtype.text,
      organizers: [
        shared_types.OrganizerReference(type: 'person', slug: 'placeholder', title: 'placeholder'),
      ],
    )..obsidianPath = relativePath;
  Este `OrganizerReference` hardcoded ("placeholder") parece resíduo de
  debug esquecido — qualquer arquivo de tipo não reconhecido herda um
  organizador fantasma, poluindo listagens de People/Organizers.

REPLACE por:
    obj = Note(
      id: stableId,
      title: frontmatter['title'] ?? fallbackTitle,
      body: body,
      subtype: NoteSubtype.text,
    )..obsidianPath = relativePath;
  (sem `organizers:` — `loadBaseMap()`, chamado logo depois, já popula
  `organizers` a partir do frontmatter real do arquivo, se houver.)

(SE a decisão da Task 0.3 for manter `Event` como tipo válido — OPÇÃO B —
adicionar aqui também um `else if (type == 'event') { obj =
Event.fromMarkdown(...) }`. Se a decisão for OPÇÃO A — migrar Event para
CalendarSession — não é necessário, mas garantir que a migração one-shot
rode ANTES deste dispatcher processar o vault, ou arquivos `type: event`
antigos cairão no fallback genérico de Note até a migração rodar.)

────────────────────────────────────────────────────────────────────────────────
1.5 — HABIT COMPLETIONS: CHAVES PLANAS NO FRONTMATTER, NÃO ANINHADAS SOB
      `habits:`
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — toggle/registro gravam chaves planas no frontmatter,
  parser lê formato plano com retrocompatibilidade e há migração one-shot
  de `habits:` aninhado.

SEVERIDADE: P0 — quebra TODAS as queries Dataview de exemplo da própria
  guidelines.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: `HabitsNotifier.toggleHabit()` E `HabitsNotifier.recordHabitValue()`
  — ambos fazem `frontmatter['habits'] = habitsMap;`.

REPLACE (nos dois métodos) por:
    // Regra/PARTE 20: completions ficam como chaves PLANAS na raiz do
    // frontmatter, uma por habit slug — nunca aninhadas sob 'habits'.
    for (final entry in habitsMap.entries) {
      frontmatter[entry.key] = entry.value;
    }
    frontmatter.remove('habits');

FILE: lib/services/markdown_parser.dart
ACTION: EDIT
ANCHOR: `parseHabitCompletions()` — hoje só lê `frontmatter['habits']`
  como fallback secundário; precisa virar o caminho PRIMÁRIO.
REPLACE por:
    static Map<String, dynamic> parseHabitCompletions(Map<String, dynamic> frontmatter) {
      final habits = <String, dynamic>{};
      final systemKeys = {
        'date', 'tags', 'type', 'id', 'title', 'trackers',
        'habit_completions', 'target', 'status', 'priority', 'archived',
        'day_theme', 'mood_pleasantness', 'mood_energy', 'mood_label',
        'mood_emoji', 'habits',
      };
      frontmatter.forEach((key, value) {
        if (!systemKeys.contains(key) &&
            (value is bool || value is num || value is List)) {
          habits[key] = value;
        }
      });
      // Fallback de retrocompatibilidade com vaults gravados no formato
      // antigo (aninhado).
      if (frontmatter['habits'] is Map) {
        (frontmatter['habits'] as Map).forEach((k, v) {
          habits.putIfAbsent(k.toString(), () => v);
        });
      }
      return habits;
    }

ADD migração one-shot (gatear por SharedPreferences
  `daily_note_habits_migration_done`): no carregamento inicial do vault,
  para cada `daily/YYYY-MM-DD.md` cujo frontmatter tenha a chave `habits:`
  (Map), promover cada entrada para o nível raiz e remover a chave
  `habits:`, reescrevendo o arquivo.

────────────────────────────────────────────────────────────────────────────────
1.6 — DAILY NOTE TEMPLATE NÃO GERA O FORMATO CANÔNICO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — template gera `tags: [daily]`, campos `mood_*`,
  hábitos ativos como chaves planas e seções canônicas.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: função `getDailyNoteTemplate(String dateStr, List<DayTheme> dayThemes)`
  (nível de arquivo, não dentro de classe) — hoje gera apenas:
    '---\ndate: $dateStr\ntype: daily_note\nday_theme: $themeSlug\n---\n\n# $dateStr\n'
  sem tags, sem mood_*, sem esqueleto de seções.

REPLACE por:
    String getDailyNoteTemplate(String dateStr, List<DayTheme> dayThemes,
        {List<Habit> activeHabits = const []}) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      final dayName = weekDayNames[parsedDate.weekday - 1];
      final activeTheme = dayThemes.cast<DayTheme?>().firstWhere(
        (theme) => theme?.daysOfWeek.contains(dayName) ?? false,
        orElse: () => null,
      );
      final themeSlug = activeTheme?.id ?? '';
      final habitKeys = activeHabits.map((h) => '${h.slug}: false').join('\n');
      return '---\n'
          'date: $dateStr\n'
          'type: daily_note\n'
          'tags: [daily]\n'
          '${themeSlug.isNotEmpty ? 'day_theme: $themeSlug\n' : ''}'
          '${habitKeys.isNotEmpty ? '$habitKeys\n' : ''}'
          'mood_pleasantness:\n'
          'mood_energy:\n'
          'mood_label:\n'
          'mood_emoji:\n'
          '---\n\n'
          '# $dateStr\n\n'
          '## Journal Entries\n\n'
          '## Habits\n\n'
          '## Trackers\n\n'
          '## Pomodoros\n';
    }
  (campo `day_theme:` é uma extensão não documentada na spec — mantida
  aqui condicionalmente só quando há tema ativo, por compatibilidade; se
  preferir remover por completo, é uma decisão de produto separada e de
  baixo risco.)

ATUALIZAR todos os 5+ pontos de chamada já identificados
  (`HabitsNotifier.toggleHabit`, `HabitsNotifier.recordHabitValue`,
  `JournalNotifier.addEntry`, `JournalNotifier.updateEntry`,
  `JournalNotifier.deleteEntry`) para passar
  `activeHabits: ref.read(habitsProvider).where((h) => h.status == HabitStatus.active).toList()`.

────────────────────────────────────────────────────────────────────────────────
1.7 — IDs DE OBJETOS SÃO UUID ALEATÓRIO; WIKILINKS DEVEM USAR SLUG ESTÁVEL
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — IDs UUID permanecem internos; gravação usa path/slug
  estável, `_writeObject()` resolve colisões `-2/-3`, e WikiLinks auditados
  não usam UUID como fallback quando há slug.

FILE: lib/models/content_object.dart
ACTION: EDIT (decisão arquitetural — aplicar com cuidado)

EVIDÊNCIA: `id = id ?? const Uuid().v4()` — todo objeto sem id explícito
  ganha um UUID v4 aleatório. Mas TODOS os exemplos de frontmatter da spec
  usam ids legíveis e estáveis derivados do título (`id:
  "task-comprar-equipamento"`, `id: "escrever-100-palavras"`), e WikiLinks
  como `linked_system: "[[system-publicar-instagram]]"` e a chave de
  completion de habit na daily note (Task 1.5 acima) usam esse mesmo
  slug — nunca o UUID interno.

ACTION:
  1. PADRONIZAR: todo WikiLink gravado no vault (organizers, links,
     linked_system, linked_task, linked_goal, parent_task, pact_refs,
     participants, places, e a chave de completion de habit na daily
     note) DEVE usar `ContentObject.slug` (derivado do título, estável,
     legível) — NUNCA `ContentObject.id` (UUID interno, conforme Regra 11:
     "IDs são internos. Nunca exibir ao usuário").
  2. AUDITAR todo lugar do código que hoje grava `obj.id` dentro de um
     WikiLink ou nome de arquivo (buscar por `obj.id` próximo de `'[['`
     ou em `obsidianFileName`/chamadas de `writeFile` em
     obsidian_service.dart e em todos os `toMarkdown()`) e trocar para
     `obj.slug`.
  3. RESOLVER colisão de slug (dois títulos iguais geram o mesmo slug):
     em `VaultNotifier._writeObject()` / `MarkdownParser.prepareForSave()`,
     ao gravar um novo arquivo, se `slug.md` já existir E pertencer a um
     `id` diferente do objeto sendo salvo, sufixar com `-2`, `-3`, etc.
     antes de escrever.
  4. `id` (UUID) continua existindo apenas como chave primária interna em
     memória (para encontrar o objeto certo numa lista após editar o
     título, que mudaria o slug). NUNCA gravar o `id` UUID em nenhum
     WikiLink do vault.

────────────────────────────────────────────────────────────────────────────────
1.8 — OrganizerReference.toWikiLink() GRAVA "[[tipo/slug]]" EM VEZ DE
      "[[slug]]"
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `OrganizerReference.toWikiLink()` grava `[[slug]]` e
  `fromWikiLink()` mantém retrocompatibilidade com `[[tipo/slug]]`.

SEVERIDADE: P0 — quebra backlinks nativos do Obsidian em TODO o vault
  (organizers de todo objeto, e a linha `organizers::` gerada dentro de
  cada Journal Entry pelo `generateDailyNoteBody()`).

FILE: lib/models/shared_types.dart
ACTION: EDIT
ANCHOR: método `toWikiLink()` em `OrganizerReference` — hoje:
  `String toWikiLink() => type == 'label' ? '[[$slug]]' : '[[$type/$slug]]';`

REPLACE por:
  String toWikiLink() => '[[$slug]]';

MANTER `fromWikiLink()` tratando ambos os formatos (com e sem `tipo/`)
  para retrocompatibilidade de leitura. ADD migração one-shot: ao carregar
  qualquer WikiLink de `organizers`/`links`/`participants`/`places` que
  contenha `/`, reescrever o arquivo sem o prefixo de tipo na próxima vez
  que for salvo (não precisa ser proativo/imediato — corrigir
  lazily/gradualmente conforme os arquivos são reescritos no uso normal).

================================================================================
TIER 2 — FEATURES INCOMPLETAS (P1)
================================================================================

────────────────────────────────────────────────────────────────────────────────
2.1 — PomodoroSession NÃO PERSISTE EM LUGAR NENHUM
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `PomodoroSession` tem estado/durações/blocos, grava
  bloco em `## Pomodoros` da daily note ao completar/cancelar sessão,
  enfileira sync e o loader reparseia essas sessões para memória.

FILE: lib/models/pomodoro_session.dart
ACTION: REWRITE

EVIDÊNCIA: model atual só tem taskTitle, startTime, duration (Duration
  única), pomodoroType, completed, linkedOrganizerRef opcional, e
  `toMarkdown() => ''`. Spec (PARTE 7) exige work/short/long break
  duration configuráveis, long_break_after_blocks, blocks_completed/
  minutes_worked/minutes_break derivados, state (scheduled|active|paused|
  completed|cancelled), linked_item (WikiLink para qualquer objeto), e
  armazenamento na daily note sob `## Pomodoros`.

REESCREVER:
  enum PomodoroState { scheduled, active, paused, completed, cancelled }

  class PomodoroSession extends ContentObject {
    String? linkedItemSlug;
    DateTime date;
    int workDuration = 25;
    int shortBreakDuration = 5;
    int longBreakDuration = 20;
    int longBreakAfterBlocks = 4;
    int blocksCompleted = 0;
    int minutesWorked = 0;
    int minutesBreak = 0;
    PomodoroState state = PomodoroState.scheduled;

    ... construtor ...

    @override
    String get type => 'pomodoro_session';

    String toDailyNoteBlock() {
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      final buf = StringBuffer()
        ..writeln('### $hh:$mm — $title');
      if (linkedItemSlug != null) buf.writeln('- Linked: [[$linkedItemSlug]]');
      buf
        ..writeln('- Blocos: $blocksCompleted')
        ..writeln('- Tempo trabalhado: $minutesWorked min')
        ..writeln('- Tempo de pausa: $minutesBreak min');
      return buf.toString();
    }

    @override
    String toMarkdown() => ''; // não é standalone — embutido na daily note

    factory PomodoroSession.fromDailyNoteBlock(String block, DateTime day) {
      // Regex linha a linha: ### HH:MM — title / - Linked: [[slug]] /
      // - Blocos: N / - Tempo trabalhado: N min / - Tempo de pausa: N min
      ...
    }
  }

CONECTAR à persistência: localizar pomodoro_provider.dart e
  pomodoro_bg_service.dart (não auditados ainda — ver "Cobertura") e, ao
  completar/cancelar uma sessão, gravar o bloco em `## Pomodoros` da daily
  note do dia (mesmo padrão incremental de leitura/escrita já usado para
  habit completions na Task 1.5). Sem isso, o histórico de Pomodoro nunca
  sobrevive a um restart nem aparece na Organizer Detail View (PARTE 23.8,
  item "Pomodoro" na Timeline Section).

────────────────────────────────────────────────────────────────────────────────
2.2 — KPI: TAXONOMIA INCOMPATÍVEL; FALTA AUTO-COMPLETE E BOTÃO "+N"
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `KPISourceType` foi reduzido aos 8 tipos da spec,
  `calculationMode` e `autoCompleteAction` existem, há migração dos valores
  legados, `AutomationService.updateAllKPIs()` dispara ação ao atingir meta
  e a UI de detalhe da meta tem incremento manual `+1/+N` para
  `manualQuantity`.

FILE: lib/models/kpi_model.dart
ACTION: EDIT

EVIDÊNCIA: spec define 8 `source_types` exatos: subtasks, tracker_field,
  habit, collection, entry, time_spent, manual_quantity, others. Model
  atual (`KPISourceType`) tem 24 valores granulares pré-fixados
  (habitCompletionCount, habitStreak, trackerFieldSum, trackerFieldMax,
  goalSubtaskCompletion, moodAverage, etc.), com labels que misturam
  português e inglês na mesma string. Falta `autoCompleteAction`
  (spec: "quando current_value >= target_value, acionada ação
  configurada") e botão de incremento rápido "+N" para manual_quantity.

ACTION:
  1. Realinhar `KPISourceType` para os 8 valores exatos:
     subtasks, trackerField, habit, collection, entry, timeSpent,
     manualQuantity, others. Persistir como `source_type` snake_case.
  2. ADD `String? calculationMode` para granularidade dentro de cada
     source_type (ex.: habit → 'streak'|'successful_days'|
     'total_completions'; trackerField → 'sum'|'average'|'count'|'max'|'min').
  3. ADD `Map<String,dynamic>? autoCompleteAction` (mesma forma de ActionDef
     em shared_types.dart), disparado quando `currentValue >= targetValue`
     muda de false→true.
  4. Corrigir todas as labels para português consistente.
  5. Migração: mapear os 24 valores antigos para (novo source_type,
     calculationMode) na leitura, preservando dados existentes.
  6. ADD botão "+N" inline na UI de KPI (tracker_metric_card.dart ou
     equivalente — não auditado ainda) quando source_type == manualQuantity.

ACHADO ADICIONAL (lib/services/kpi_engine.dart, lido por completo): o
  motor de cálculo é AINDA MENOS completo do que a taxonomia do model
  sugere. De 24 valores de `KPISourceType`, `calculateKPIValue()` só
  calcula 12 (habitCompletionCount, habitStreak, habitSuccessRate,
  trackerFieldSum/Average/Max/Min, moodAverage, entryCount,
  collectionItemCount, customNumericInput, plannerTaskDuration — este
  último é um stub que sempre `return 0`). Os outros 11 valores do enum
  (goalSubtaskCompletion, goalProgressPercentage, plannerTaskCount,
  plannerOverdueCount, journalWordCount, moodTrend, photoCount,
  commentCount, reflectionLength, organizerAssociationCount,
  timeSpentInCategory) caem no `default: return 0;` — ou seja, são tipos
  que existem no enum e provavelmente aparecem como opção selecionável na
  UI de criação de KPI, mas SEMPRE retornam 0 silenciosamente, sem
  nenhum erro ou aviso ao usuário. Qualquer KPI configurado com um desses
  11 tipos nunca vai progredir.

  TAMBÉM CONFIRMADO: `KPISourceType.moodAverage` usa
  `m?.numericValue.toDouble()` — o campo ANTIGO de 1 dimensão de
  `MoodDefinition` (Phase 9 Task 9.A.8 está reescrevendo `MoodDefinition`
  para o sistema de 2 eixos `pleasantness`/`energy`, REMOVENDO
  `numericValue`). Isso significa que aplicar a Task 9.A.8 SEM
  atualizar `kpi_engine.dart` simultaneamente QUEBRA a compilação deste
  arquivo (referência a campo removido). ADICIONAR EXPLICITAMENTE à
  Phase 9 Task 9.A.8: ao remover `numericValue` de `MoodDefinition`,
  editar `KPIEngine.calculateKPIValue()` no case `moodAverage` para usar
  `m?.pleasantness.toDouble()` (ou expor a dimensão escolhida via
  `kpi.calculationMode`, reaproveitando o campo já proposto no item 2
  acima — ex.: `calculationMode == 'energy' ? m.energy : m.pleasantness`).

FILE: lib/services/kpi_engine.dart
ACTION: EDIT — implementar os 11 cases faltantes (ou removê-los do enum
  se decidir que não são necessários — decisão de produto), e corrigir o
  case `moodAverage` conforme acima.

CORREÇÃO (lib/services/automation_service.dart, lido por completo): o
  "auto-complete" NÃO está 100% ausente como dito acima — `AutomationService.
  updateAllKPIs()` já implementa `if (!kpi.completed && newValue >=
  kpi.targetValue) { kpi.completed = true; ...
  NotificationService().showImmediateNotification(...) }`. O que falta de
  fato é só a parte "ação CONFIGURADA": hoje a única ação ao bater a meta
  é uma notificação genérica hardcoded — não há como o usuário escolher,
  por KPI, qual das 7 ações (PARTE 6) disparar. Ajustar o item 3 acima: o
  campo `autoCompleteAction` deve ser lido e executado dentro de
  `updateAllKPIs()`, reaproveitando o dispatcher genérico de ações criado
  na Task 2.13 abaixo (generalizado para aceitar um `ActionDef` vindo de
  um KPI, não só de um Habit).

────────────────────────────────────────────────────────────────────────────────
2.13 — SISTEMA DE ACTIONS: SÓ 2 DOS 7 TIPOS DA SPEC ESTÃO IMPLEMENTADOS;
       FALTA TRIGGER DE TRACKER (só Habit dispara hoje); 1 tipo extra não
       documentado ("create_task")
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — dispatcher executa `add_entry`, `add_tracking_record`,
  `add_text_note`, `add_collection_item`, `view_statistics`, `view_item` e
  `launch_url`; `create_task` foi mantido como extensão legada. Trackers
  agora têm `actions` serializadas e `saveTrackerRecord()` dispara triggers
  `tracking_record_saved`/`tracker_record_saved`/`record_saved`.

FILE: lib/services/automation_service.dart
ACTION: EDIT

EVIDÊNCIA (lido por completo): `_executeAction()` (dispatcher central de
  Actions) só implementa um `switch (action.type)` com 3 cases:
  `'add_entry'` (✓ existe na spec), `'add_tracking_record'` (✓ existe na
  spec), e `'create_task'` (✗ NÃO é um dos 7 tipos da PARTE 6 — extensão
  não documentada). FALTAM os outros 4 tipos da spec: `add_text_note`,
  `add_collection_item`, `view_statistics`, `view_item`, `launch_url`
  (esse último é o 5º que falta — recontando: faltam 5 dos 7, sobram 2
  implementados + 1 extra não documentado).

  Além disso, `executeHabitSlotActions`/`executeHabitActions` só são
  chamados a partir do fluxo de Habit (confirmado em vault_provider.dart,
  Task 1.x). A spec (PARTE 6) define 3 eventos de trigger, não 2: "(1)
  Completar qualquer slot individual de um habit, (2) Completar o goal
  diário de um habit, (3) Salvar um tracking record." NÃO existe nenhum
  método `executeTrackerActions`/equivalente disparado ao salvar um
  TrackingRecord — Trackers, hoje, nunca disparam nenhuma Action, apesar
  de `TrackerSection`/`InputField` poderem ter `actions` configuradas
  (CONFERIR se o model de Tracker realmente expõe esse campo — não
  confirmado nesta leitura específica de automation_service.dart).

ACTION:
  1. ADD os 5 cases faltantes a `_executeAction()`:
       case 'add_text_note': // abre/cria uma Text Note vinculada
         final notesNotifier = ref.read(notesProvider.notifier);
         await notesNotifier.addNote(Note(
           title: 'Nota automática: ${habit.displayTitle}',
           body: '',
           subtype: NoteSubtype.text,
         ));
         break;
       case 'add_collection_item':
         // requer action.targetCollectionNoteId (ADD esse campo a ActionDef
         // se ainda não existir) — adicionar um CollectionItem vazio/
         // pré-preenchido na Collection Note especificada.
         break;
       case 'view_statistics':
         // navegação pura — não tem efeito de dados; deve ser tratado na
         // CAMADA DE UI (não em automation_service.dart), recebendo um
         // callback de navegação. Documentar a divisão de responsabilidade.
         break;
       case 'view_item':
         // idem — navegação para action.targetItemId; tratar na UI.
         break;
       case 'launch_url':
         // usar package:url_launcher já presente no projeto (confirmar em
         // pubspec.yaml) para abrir action.targetUrl.
         await launchUrl(Uri.parse(action.targetUrl ?? ''));
         break;
  2. RENOMEAR ou remover `'create_task'`: já que não é um tipo documentado,
     decidir (mesma lógica de decisão de produto da Task 0.3): manter como
     extensão documentada no guidelines.md, ou remover.
  3. ADD `static Future<void> executeTrackerActions(Ref ref,
     TrackerDefinition tracker, TrackingRecord record) async { ... }`,
     iterando as Actions configuradas nos InputFields do tracker que foram
     preenchidos neste record, chamando o mesmo `_executeAction` (adaptado
     para aceitar um contexto genérico em vez de só `Habit habit, DateTime
     date` — trocar a assinatura de `_executeAction` para receber um
     `String contextTitle` e `DateTime contextDate` genéricos em vez de
     `Habit habit`).
  4. CHAMAR esse novo método no provider de TrackingRecord (`saveTrackerRecord()`
     em vault_provider.dart) logo após salvar o record.

────────────────────────────────────────────────────────────────────────────────
2.14 — INCONSISTÊNCIA DE IDIOMA: STRINGS EM INGLÊS MISTURADAS COM O RESTO
       DO APP EM PORTUGUÊS
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — strings restantes de `automation_service.dart` foram
  normalizadas para PT-BR.

SEVERIDADE: P2 — visível ao usuário final, mas não quebra funcionalidade.

EVIDÊNCIA: lib/services/automation_service.dart tem várias strings
  voltadas ao usuário final em inglês, contrastando com o resto do app
  (confirmado em português em toda a guidelines e em todos os outros
  arquivos lidos): `'Automatic: Habit "..." completed.'`, `'Habit
  Completion'`, `'Acompanhamento: ...'` (esse já em português, inconsistente
  com os vizinhos), `'Task created automatically after completing the
  habit.'`, `'Task created automatically from the configured contact
  frequency.'` (em inglês, enquanto o texto análogo `'Contatar ${person.title}'`
  está em português), `'KPI atingido'` (português, correto) vs `'Goal
  Reached!'`/`'Congratulations! You reached every target for "..."'` (inglês).
  Esse mesmo padrão de mistura PT/EN já foi notado de forma isolada na
  Phase 12 (Task 12.B.2, labels de KPISourceType) — agora confirma-se que
  é um problema mais amplo, presente em pelo menos 2 arquivos distintos.

FILE: lib/services/automation_service.dart
ACTION: EDIT — traduzir todas as strings voltadas ao usuário para
  português, revisando: o texto de entry automática ao completar habit, o
  título "Habit Completion", as 2 notas automáticas de Task ("Task created
  automatically..." → "Task criada automaticamente..."), e as 2 strings
  de notificação de Goal ("Goal Reached!"/"Congratulations!..." →
  "Meta atingida!"/"Parabéns! Você alcançou todos os alvos de '...'.").

────────────────────────────────────────────────────────────────────────────────
2.15 — `checkKPIGoals()` AUTO-COMPLETA O GOAL INTEIRO QUANDO TODOS OS KPIs
       BATEM A META — COMPORTAMENTO NÃO DOCUMENTADO NA SPEC
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — decisão aplicada: não auto-completar a meta pai. O app
  notifica que todos os KPIs foram atingidos e deixa a conclusão da meta
  como ação explícita do usuário.

SEVERIDADE: P2 — extensão de comportamento, não um bug, mas muda o
  `state` de um Goal automaticamente sem confirmação do usuário, o que
  pode surpreender (ex.: usuário queria manter o Goal "active" por mais
  tempo mesmo com os KPIs batidos, para acompanhamento contínuo).

EVIDÊNCIA: `AutomationService.checkKPIGoals()` muda
  `goal.state = GoalStatus.completed` automaticamente quando
  `goal.kpis.every((k) => k.completed || k.currentValue >= k.targetValue)`.
  A spec (PARTE: KPI) só descreve "auto-complete" no nível de KPI
  individual disparando uma ação configurada — não descreve o Goal pai
  mudando de estado sozinho.

ACTION: DECISÃO DE PRODUTO — manter esse comportamento como extensão
  documentada formalmente no guidelines.md (com uma forma de o usuário
  desativar isso por Goal, ex.: `goal.autoCompleteWhenKpisHit: bool`), ou
  trocar por uma notificação/sugestão não-destrutiva ("Todos os KPIs desta
  meta foram atingidos — marcar como concluída?") em vez de mudar o estado
  silenciosamente.

────────────────────────────────────────────────────────────────────────────────
2.3 — DASHBOARD: FALTA PAINEL pact_today; dashboard_panel.dart MORTO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `BlockType.pactToday` existe, é renderizado no
  dashboard, aparece nos blocos padrão e no modal de adicionar widgets.
  `dashboard_panel.dart` foi mantido apenas como deprecated para referência
  histórica, sem uso funcional.

FILE: lib/models/dashboard_block.dart
ACTION: EDIT
ADD ao enum BlockType: `pactToday,` — renderização: lista de Habits com
  `habitMode == HabitMode.pact && status == active`, cada linha com
  checkbox de check-in de hoje + badge "dias restantes" (`endsAt - hoje`).

FILE: lib/models/dashboard_panel.dart
ACTION: DELETE (ou @Deprecated) — este arquivo define um SEGUNDO enum
  `PanelType` com só 7 valores e uma classe `DashboardPanel` paralela e
  incompatível com `DashboardBlock` (30 tipos, a implementação realmente
  usada). Confirmar com `grep -r "PanelType\|DashboardPanel(" lib/` que
  não há uso real antes de remover.

────────────────────────────────────────────────────────────────────────────────
2.4 — COMBINED ANALYSIS: CAMPOS FALTANDO; FALTA BLOCO DO PLUGIN OBSIDIAN
      CHARTS (o bloco Tracker JÁ EXISTE)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `MetricSource` tem `dimension/axis/showEmojiMarkers/
  valueMapping`, `AnalysisChart` tem `normalization`,
  `CombinedAnalysis` tem `defaultDateRange`, o form trata dimensão de mood
  e `_writeObject()` anexa blocos Obsidian Tracker e Charts.

FILE: lib/models/analysis_model.dart
ACTION: EDIT
  1. ADD a `MetricSource`: `String? dimension` ('pleasantness'|'energy',
     null para fontes não-mood), `String axis` ('left'|'right', default
     'left'), `bool showEmojiMarkers` (default false), `Map<String,num>?
     valueMapping`.
  2. ADD a `AnalysisChart`: `String normalization` ('none'|'dual_axis'|
     'normalize_0_1', default 'dual_axis' quando há mood + tracker juntos).
  3. ADD `DateTimeRange? defaultDateRange` a `CombinedAnalysis`.
  4. Exigir `dimension` não-nulo na validação do form quando
     `MetricType.mood` (mood sempre precisa de pleasantness OU energy
     explícito).

CORREÇÃO IMPORTANTE (achado original estava incompleto): o bloco do
  plugin Obsidian TRACKER (```tracker, exemplo da PARTE 11) JÁ É gerado
  dinamicamente — `VaultNotifier._writeObject()` em vault_provider.dart
  chama `DataviewGenerator.generateTrackerPluginBlock(object)` para todo
  `CombinedAnalysis` e anexa como seção `## Obsidian Tracker`. NÃO
  duplicar esse trabalho. O que REALMENTE falta é só o bloco do plugin
  Obsidian CHARTS (```chart, o outro exemplo da PARTE 11/PARTE 20) — isso
  nunca é gerado em lugar nenhum (nem em `CombinedAnalysis.toMarkdown()`,
  que só emite um comentário placeholder, nem em `_writeObject()`).

FILE: lib/services/dataview_generator.dart
ACTION: ADD método `generateChartsPluginBlock(CombinedAnalysis analysis)`
  gerando:
    ```chart
    type: line
    labels: [...]
    series:
      - title: ...
        data: [...]
    width: 80%
    beginAtZero: false
    ```
  (dados reais extraídos do período corrente da análise).

FILE: lib/providers/vault_provider.dart
ACTION: EDIT
ANCHOR: `VaultNotifier._writeObject()`, branch `else if (object is
  CombinedAnalysis)` — ADD, junto ao bloco Tracker já existente, uma
  segunda seção `## Obsidian Charts` usando o novo
  `generateChartsPluginBlock`.

FILE: lib/models/analysis_model.dart
ACTION: EDIT — remover/condicionar o comentário placeholder em
  `toMarkdown()` (`// Gráfico renderizado dinamicamente pelo Citrine`) já
  que o bloco real passa a ser gerado externamente por `_writeObject`.

────────────────────────────────────────────────────────────────────────────────
2.5 — CONFLICT DETECTION (OBJECT IDENTIFICATION) NÃO EXISTE
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — existem `object_conflicts_screen.dart`,
  `typeConflictedObjectsProvider`, flags `hasTypeConflict/conflictReason`
  em `ContentObject`, marcação no loader e badge/entrada no menu Mais.

FILE: lib/ui/screens/object_conflicts_screen.dart
ACTION: CREATE (arquivo não existe)

EVIDÊNCIA: guidelines, PARTE 1.1 + PARTE 21: "Se um objeto tem atributos
  que apontam para tipos conflitantes..., o app exibe ⚠️ ao lado do título
  em TODAS as telas onde aparece, e o objeto aparece na página 'Conflitos'
  (menu Mais)." `type_signatures_screen.dart` (a tela de Object
  Identification, lida por completo) não tem NENHUMA lógica de detecção
  de conflito nem link para tal página. `sync_conflicts_screen.dart` trata
  só de conflitos de SINCRONIZAÇÃO (merge do Google Drive) — conceito
  diferente.

ACTION:
  1. CREATE a tela: lista objetos cujo `type` resolvido por Object
     Identification diverge de outro atributo do arquivo (ex.: está na
     pasta configurada para `task` mas tem `type: area` no frontmatter).
     Cada linha: ícone + título + explicação textual + ação de resolução.
  2. Acessível via menu "Mais".
  3. Implementar detecção durante o parsing do vault
     (`AllObjectsNotifier.build()`): comparar o tipo resolvido pela Object
     Identification contra o `type` literal do frontmatter; se divergirem,
     marcar um novo campo em memória `bool hasTypeConflict` +
     `String? conflictReason` (em ContentObject, ou num provider paralelo
     `conflictedObjectsProvider` para não poluir o model base).
  4. ADD badge ⚠️ compartilhado (`ConflictBadge(visible: obj.hasTypeConflict)`)
     reaproveitado em todas as listagens/detail views do app.

────────────────────────────────────────────────────────────────────────────────
2.6 — COMMAND CENTER: FALTAM SEÇÕES SYSTEMS/PRÓXIMAS SESSÕES; BUSCA NÃO
      AGRUPA POR TIPO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — ações rápidas incluem Novo System, há seções Systems
  e Próximas Sessões, busca agrupa por tipo com limite por grupo e cobre
  título/aliases/snippet/body, Escape fecha o overlay e Recentes usa
  swipe-to-remove com undo.

FILE: lib/ui/widgets/command_center_overlay.dart
ACTION: EDIT

EVIDÊNCIA (lido por completo, vs PARTE 23.9):
  1. Ações rápidas hoje: "Nova Entrada"/"Nova Task"/"Novo Registro"/"Nova
     Nota" — a 4ª deveria ser "Novo System".
  2. Não existe seção "Systems" (3 chips de quick-run com tap→bottom sheet
     Via C e long-press→detail view).
  3. Não existe seção "Próximas Sessões" (Calendar Sessions) — código
     mostra "Próximas Tasks" por deadline em vez disso.
  4. Busca é `o.title.contains(query)` plano — sem agrupar por tipo
     (header de grupo, máx. 4 por grupo) nem pesquisar aliases/body.
  5. Sem fechar por tecla Escape.
  6. Chips de "Recentes" sem swipe-to-remove + undo snackbar.

ACTION:
  1. Trocar 4º botão para "Novo System" → CreateSystemForm (Task 3.9).
  2. ADD seção Systems: novo provider `topSystemsProvider` (3 com maior
     `run_count` derivado); chips horizontais "▶ nome"; tap→quick-run (Via
     C); long-press→detail view.
  3. ADD seção Próximas Sessões: baseada em `calendarSessionsProvider`
     (Phase 9 Task 9.A.7), `date.isAfter(now)`, top 3, dot colorido =
     `session.color`.
  4. Reescrever busca: agrupar `searchResults` por `obj.type`, header por
     grupo, truncar em 4 por grupo; também testar contra aliases (mood) e
     primeiros 200 caracteres do corpo quando disponível.
  5. ADD `Shortcuts`/`Actions` capturando `LogicalKeyboardKey.escape` → `_close()`.
  6. ADD `Dismissible`/swipe horizontal nos chips de "Recentes",
     removendo de `historyProvider` + `SnackBar` com "Undo".

────────────────────────────────────────────────────────────────────────────────
2.7 — SCHEDULER: SERIALIZAÇÃO camelCase EM VEZ DE snake_case
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `RepeatTypeX.specName/fromSpecName` existe,
  `SchedulerRule.toMap()` grava snake_case e `fromMap()` lê snake_case e
  camelCase legado.

FILE: lib/models/scheduler.dart
ACTION: EDIT

CORREÇÃO DE LOCALIZAÇÃO (a Phase 9 Task 9.C.4 original apontava para uma
  classe `SchedulerRuleType`/campo `ruleType` que NÃO existe; a estrutura
  real, lida diretamente, é `Scheduler.rules: List<SchedulerRule>`, cada
  `SchedulerRule.repeatType: RepeatType`, com `'repeat_type': repeatType.name`
  gravando "numberOfDays" em vez de "number_of_days").

  `RepeatType` tem 13 valores: os 11 da spec + 2 extras
  (`daysOfTheme`, `daysWithBlock` — extensão não documentada, decisão de
  produto igual à Task 0.3/OPÇÃO B: documentar ou remover).

ADD extension:
  extension RepeatTypeX on RepeatType {
    String get specName => switch (this) {
      RepeatType.numberOfDays            => 'number_of_days',
      RepeatType.daysOfWeek              => 'days_of_week',
      RepeatType.numberOfWeeks           => 'number_of_weeks',
      RepeatType.numberOfMonths          => 'number_of_months',
      RepeatType.numberOfHours           => 'number_of_hours',
      RepeatType.daysAfterLastStart      => 'days_after_last_start',
      RepeatType.daysAfterLastEnd        => 'days_after_last_end',
      RepeatType.numberOfDaysPerPeriod   => 'days_per_period',
      RepeatType.linkedItemAppears       => 'linked_item_appears',
      RepeatType.nDaysAfterLinkedItem    => 'n_days_after_linked_item',
      RepeatType.firstBusinessDayOfMonth => 'first_business_day_of_month',
      RepeatType.daysOfTheme             => 'days_of_theme',
      RepeatType.daysWithBlock           => 'days_with_block',
    };
    static RepeatType fromSpecName(String s) => RepeatType.values.firstWhere(
      (t) => t.specName == s || t.name == s, orElse: () => RepeatType.numberOfDays);
  }

EDIT `SchedulerRule.toMap()`: `'repeat_type': repeatType.specName,`
EDIT `SchedulerRule.fromMap()`: `repeatType: RepeatTypeX.fromSpecName(map['repeat_type']?.toString() ?? ''),`

  (Esta task SUBSTITUI integralmente a Phase 9 Task 9.C.4 original — não
  aplicar a versão antiga, ela referencia símbolos inexistentes.)

────────────────────────────────────────────────────────────────────────────────
2.8 — AUTO-CATEGORIA "[[people]]" NUNCA APLICADA A Person; OUTRAS 4
      ENTIDADES GANHAM AUTO-CATEGORIAS QUE A SPEC NÃO PEDE
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `PeopleNotifier.addPerson()` aplica `[[people]]`.
  As demais auto-categorias foram mantidas como extensão legada por
  compatibilidade, mesma decisão de produto da Task 0.3.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT

EVIDÊNCIA: `PeopleNotifier.addPerson()` NÃO adiciona nenhuma categoria
  automática (spec PARTE 8: "categories — auto-inclui [[people]]" —
  ausente). Já `OrganizersNotifier.addOrganizer()` adiciona
  `'[[organizers]]'`, `TrackersNotifier.addTracker()` adiciona
  `'[[trackers]]'`, `SnapshotsNotifier.addSnapshot()` adiciona
  `'[[snapshots]]'`, e `saveTrackerRecord()` adiciona
  `'[[tracker_records]]'` — NENHUM desses 4 é pedido pela spec.

ACTION:
  1. ADD em `PeopleNotifier.addPerson()`, antes de persistir:
       if (!person.categories.contains('[[people]]')) {
         person.categories.add('[[people]]');
       }
  2. Para Organizer/Tracker/Snapshot/TrackingRecord: REMOVER essas
     auto-categorias (recomendado — não têm base na spec e poluem o
     frontmatter sem benefício funcional comprovado), OU documentar
     formalmente como extensão no guidelines.md (decisão de produto, igual
     à Task 0.3/OPÇÃO B).

────────────────────────────────────────────────────────────────────────────────
2.9 — FALTA HOOK "CHECAR PACTS VENCIDOS A CADA ABERTURA DO APP"
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `HabitsNotifier.build()` chama
  `AutomationService.checkPactExpirations()` e o serviço notifica pacts
  ativos vencidos sem `pactOutcome`.

FILE: lib/providers/vault_provider.dart + lib/services/automation_service.dart
ACTION: ADD

EVIDÊNCIA: spec (PARTE 2 OBJETO 4 + PARTE 22 #14): comparar `ends_at` com
  hoje para Habits `habit_mode: pact`, `status: active`; se vencido e
  `pact_outcome == null`, agendar notificação de Steering Sheet. O padrão
  equivalente já existe e funciona para People
  (`PeopleNotifier.build()` chama `AutomationService.checkPersonContacts()`
  via `Future.microtask`) mas NÃO tem equivalente para Habits/Pacts.

ACTION: replicar o padrão de People para Habits:
  class HabitsNotifier extends Notifier<List<Habit>> {
    @override
    List<Habit> build() {
      final habits = ref.watch(objectsByTypeProvider('habit')).cast<Habit>();
      if (habits.isNotEmpty) {
        Future.microtask(() => AutomationService.checkPactExpirations(ref, habits));
      }
      return habits;
    }
    ...
  }
  E implementar `AutomationService.checkPactExpirations()` (novo método),
  espelhando `checkPersonContacts()`: filtrar `habitMode == HabitMode.pact
  && status == HabitStatus.active && endsAt != null &&
  !endsAt!.isAfter(DateTime.now()) && pactOutcome == null`, agendar a
  notificação/trigger da Steering Sheet para cada um.
  (DEPENDE da Task 0.1 — campos de Pact em Habit — já terem sido aplicados.)

────────────────────────────────────────────────────────────────────────────────
2.10 — SUBTASKS NÃO USAM SINTAXE DO TASKS PLUGIN DO OBSIDIAN
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Subtask` possui `dueDate` e `priority`; `Task.toMarkdown()`
  grava checklist com `[due:: ...]` e `[priority:: ...]`; o parser lê esses
  campos de volta.

FILE: lib/models/task_model.dart (escrita) + lib/models/shared_types.dart
      (classe Subtask) + lib/services/markdown_parser.dart (leitura)
ACTION: EDIT

EVIDÊNCIA: guidelines PARTE 21: "Tasks em daily notes e nos arquivos de
  task usam sintaxe do Tasks Plugin: `- [ ] Título [due:: 2024-12-31]
  [priority:: high]`." `Task.toMarkdown()` escreve subtasks sem nenhum
  campo inline; `MarkdownParser.parseSubtasks()` usa um regex que captura
  tudo após o checkbox como texto cru, sem extrair `[chave:: valor]`.

ACTION:
  1. lib/models/shared_types.dart, classe `Subtask`: ADD `DateTime?
     dueDate;` e `TaskPriority? priority;`.
  2. lib/models/task_model.dart, `toMarkdown()`: ao serializar cada
     subtask, anexar sintaxe inline quando aplicável:
       String renderSubtaskLine(Subtask s) {
         final check = s.completed ? '[x]' : '[ ]';
         final title = s.slug != null ? '[[${s.slug!}]]' : s.title;
         final fields = StringBuffer();
         if (s.dueDate != null) {
           fields.write(' [due:: ${s.dueDate!.toIso8601String().split('T').first}]');
         }
         if (s.priority != null && s.priority != TaskPriority.none) {
           fields.write(' [priority:: ${s.priority!.name}]');
         }
         return '- $check $title$fields';
       }
  3. lib/services/markdown_parser.dart, `parseSubtasks()`: extrair `[due::
     ...]` e `[priority:: ...]` do texto capturado, populando os novos
     campos de `Subtask`. Aplicar o mesmo tratamento em
     `parseTasksFromDailyNote()` (mesma sintaxe de checklist na seção
     `## Tasks` da daily note).

────────────────────────────────────────────────────────────────────────────────
2.11 — ÍNDICE DATAVIEW DE MOOD USA CAMPO ANTIGO DE 1 DIMENSÃO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `_writeMoodIndex()` usa `mood_emoji`,
  `mood_label`, `mood_pleasantness` e `mood_energy`.

FILE: lib/services/dataview_generator.dart
ACTION: EDIT
ANCHOR: `_writeMoodIndex()` — hoje `TABLE mood AS "Humor"... WHERE mood`.
  Depende da Phase 9 Tasks 9.A.8 (MoodDefinition 2 eixos) e 9.C.11
  (gravação dos 4 campos de mood na daily note) já terem sido aplicadas.
REPLACE por:
    ```dataview
    TABLE mood_emoji AS "😊", mood_label AS "Humor", mood_pleasantness AS "Agradabilidade", mood_energy AS "Energia", date AS "Data"
    FROM "daily"
    WHERE type = "daily_note" AND mood_label
    SORT file.name DESC
    LIMIT 30
    ```
  (idêntico ao exemplo "Humor tendência" já presente na PARTE 20 da
  guidelines).

────────────────────────────────────────────────────────────────────────────────
2.12 — FALTAM ÍNDICES DATAVIEW DE SYSTEMS E PACTS
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `regenerateAll()` chama `_writeSystemsIndex()` e
  `_writePactsIndex()`, ambos usando `FROM "app"`.

FILE: lib/services/dataview_generator.dart
ACTION: ADD `_writeSystemsIndex()` e `_writePactsIndex()`, registrados em
  `regenerateAll()`, usando as queries já prontas na PARTE 20:
    -- Systems por frequência
    TABLE trigger AS "Quando", run_count AS "Execuções", estimated_minutes AS "Estimado"
    FROM "app" WHERE type = "system"
    SORT run_count DESC

    -- Todos os pacts ativos
    TABLE ends_at AS "Termina", hypothesis AS "Hipótese"
    FROM "app" WHERE type = "habit" AND habit_mode = "pact" AND status = "active"
    SORT ends_at ASC
  (já usando `FROM "app"`, consistente com a Task 1.1/2.x — não usar
  `FROM "systems"` nem `FROM "habits"`.)

================================================================================
TIER 3 — POLIMENTO E DETALHES (P2)
================================================================================

────────────────────────────────────────────────────────────────────────────────
3.1 — ContentObject SEM CAMPO `links` UNIVERSAL
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `ContentObject.links` existe, é serializado em
  `toBaseMap()`/`loadBaseMap()`, e `Note` não mantém mais um campo `links`
  duplicado fora da base.

FILE: lib/models/content_object.dart
ACTION: EDIT — ADD `List<String> links = [];` na base (PARTE 16 + PARTE 20
  "Frontmatter Universal" listam `links:` como comum a TODOS os tipos).
  Incluir em `toBaseMap()`/`loadBaseMap()`. Depois, remover/redirecionar
  campos `links`/`socialRefs` duplicados específicos de Task/System/
  SocialPost para usar o campo base, evitando duas fontes de verdade.

────────────────────────────────────────────────────────────────────────────────
3.2 — Project SEM CAMPO `scheduler`
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Project.scheduler` foi adicionado com serialização,
  parsing e API específica `copyProjectWith()`. `SchedulerService` agora tem
  `shouldRestartScheduledProject()` para a regra de reinício sem mutação
  silenciosa de vault em views de leitura.

FILE: lib/models/project_model.dart
ACTION: EDIT — ADD `Scheduler? scheduler;` (spec PARTE 10: "projeto
  recorre/reinicia no schedule"). Incluir em toMarkdown/fromMarkdown/
  copyWith. Implementar a lógica de "reiniciar" o projeto quando o
  scheduler dispara em scheduler_service.dart (não auditado ainda).

────────────────────────────────────────────────────────────────────────────────
3.3 — Person SEM CAMPO `notes`
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Person.notes` foi adicionado e persiste como corpo do
  markdown, com leitura em `fromMarkdown()` e preservação no `copyWith()`.

FILE: lib/models/people_model.dart
ACTION: EDIT — ADD `String? notes;` (spec PARTE 8 lista `notes` entre as
  propriedades de Person). Incluir em toMarkdown/fromMarkdown
  (recomendado: como corpo do markdown, não frontmatter).

────────────────────────────────────────────────────────────────────────────────
3.4 — Snapshot SEM `photos`; `subject` NÃO É WIKILINK REAL
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Snapshot.photos` foi adicionado; snapshots gravam
  `subject: [[...]]` com retrocompatibilidade para `parent_id`; parsing de
  data/KPI agora é tolerante a formatos reais do frontmatter.

FILE: lib/models/snapshot_model.dart
ACTION: EDIT
  1. ADD `List<String> photos = [];`.
  2. Renomear/gravar `parentId` como WikiLink (`'[[${parentId}]]'`) sob a
     chave `subject` no frontmatter, não `parent_id` cru.
  3. Avaliar generalizar `kpiValues: Map<String,double>` para
     `Map<String,dynamic> stateData` (spec: "state_data — estado
     serializado", genérico) — manter `kpiValues` como getter de
     conveniência se quiser preservar compatibilidade.

────────────────────────────────────────────────────────────────────────────────
3.5 — ReminderConfig.ringOnSilent COM DEFAULT ERRADO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — default do construtor e fallback de `fromMap()` agora é
  `ringOnSilent: true`.

FILE: lib/models/reminder_config.dart
ACTION: EDIT — `this.ringOnSilent = false,` → `this.ringOnSilent = true,`
  (spec PARTE 13: "tocar mesmo no silencioso (default: sim)", relevante
  quando `type == NotificationType.alarm`).

────────────────────────────────────────────────────────────────────────────────
3.6 — TRIPLE CHECK SHEET: BOTÕES STUB; SEM PROTEÇÃO DE DISMISS; SEM
      VALIDAÇÃO; SEM MODO BATCH/READ-ONLY
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — o sheet ganhou modo read-only com "Re-executar
  diagnóstico", suporte a fila batch no título, `PopScope` para bloquear
  fechamento com diagnóstico não salvo, ações reais para editar tarefa e
  registrar pedido de ajuda, e save bloqueado quando read-only.

FILE: lib/ui/widgets/triple_check_sheet.dart
ACTION: EDIT

EVIDÊNCIA (lido por completo, vs PARTE 23.5):
  1. `_openEditTask()` é literalmente `Navigator.of(context).pop();` — os
     botões "Reformular"/"Criar subtarefas"/"Adicionar dependência"/"Pedir
     ajuda" fecham o sheet e não fazem mais nada.
  2. Sem `PopScope`/proteção contra fechar sem salvar (spec: vibrar +
     shake ao tentar fechar sem diagnóstico salvo).
  3. Sem modo batch (PMN → "Tasks paradas" → "Task N de M").
  4. Sem modo read-only para reabrir diagnóstico já salvo.

ACTION:
  1. Implementar cada ação de fato: "Reformular"/"Criar subtarefas"/
     "Adicionar dependência" → navegar para CreateTaskForm já com o campo
     relevante focado; "Pedir ajuda" → abrir picker de People.
  2. Envolver com `PopScope(canPop: _saved, onPopInvoked: ... haptic +
     shake quando !_saved)`.
  3. ADD parâmetro `List<Task>? batchQueue`; quando presente, mostrar
     "Task N de M" e avançar automaticamente ao salvar.
  4. ADD parâmetro `bool readOnly = false`; abrir read-only quando vindo
     do badge ⚠ do card (não do menu ⋯), com botão "Re-executar diagnóstico".

────────────────────────────────────────────────────────────────────────────────
3.7 — STEERING SHEET: SEM BOTÃO X; SEM VALIDAÇÃO POR ETAPA; DEFAULT DE
      DURAÇÃO ERRADO
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — header tem botão X com confirmação, etapa 1/2 bloqueia
  avanço sem dados obrigatórios, duração usa campo numérico livre e inicia
  com a duração original do ciclo quando disponível.

FILE: lib/ui/widgets/steering_sheet.dart
ACTION: EDIT

EVIDÊNCIA (lido por completo, vs PARTE 23.6):
  1. Sem botão X/fechar com confirmação ("Sair"/"Continuar revisão").
  2. Etapa 1: "Avançar" nunca desabilitado mesmo com texto vazio.
  3. Etapa 2: "Avançar" nunca desabilitado sem os 2 radios selecionados.
  4. `_persistDays`: dropdown fixo [7,14,21,30,60,90] default 30, em vez
     de campo numérico livre com default = duração original do ciclo.

ACTION:
  1. ADD `IconButton(icon: Icons.close)` no header → `showDialog` com
     "Você pode revisar depois..." + "Sair"/"Continuar revisão".
  2. `onPressed` Etapa 1 → `_reflectionController.text.trim().isNotEmpty ? _nextStep : null`.
  3. `onPressed` Etapa 2 → `(_hypothesisEvaluation != null && _endedReason != null) ? _nextStep : null`.
  4. Trocar dropdown por `TextField` numérico, inicializado com:
     `_persistDays = (widget.habit.endsAt != null && widget.habit.startedAt != null)
        ? widget.habit.endsAt!.difference(widget.habit.startedAt!).inDays : 30;`

────────────────────────────────────────────────────────────────────────────────
3.8 — FAB: FALTA CARD "SYSTEM"; "SESSÃO" ABRE POMODORO EM VEZ DE CALENDAR
      SESSION
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `create_menu_sheet.dart` já contém card "System" que
  abre `CreateSystemForm`, e "Nova sessão" abre `CreateEventForm`
  (CalendarSession foi absorvido pelo Event).

FILE: lib/ui/widgets/create_menu_sheet.dart
ACTION: EDIT (substitui/complementa a Phase 9 Task 9.B.6 original)

EVIDÊNCIA: grid atual ("Capture"/"Criar") não tem nenhum card para criar
  System; card "Sessão" abre `PomodoroScreen` direto em vez de um form de
  Calendar Session; card "Journal" abre direto CreateEntryForm sem
  sub-menu Entrada completa/Observação rápida/PMN.

ACTION: ao reestruturar para as 4 abas Journal/Plan/Record/Note (Phase 9
  Task 9.B.6), garantir explicitamente:
  1. Aba "Note" inclui "⚙️ System" → CreateSystemForm (Task 3.9).
  2. Aba "Plan" → "Session" abre CreateCalendarSessionForm (Phase 9 Task
     9.C.2), NÃO PomodoroScreen.
  3. Aba "Journal" → "Entry" abre segmented control Entrada completa/
     Observação rápida ANTES de abrir qualquer form.

────────────────────────────────────────────────────────────────────────────────
3.9 — NÃO EXISTE lib/ui/forms/create_system_form.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `lib/ui/forms/create_system_form.dart` existe e cobre
  título, gatilho, tempo estimado, steps/substeps, organizadores, descrição
  e scheduler opcional.

FILE: lib/ui/forms/create_system_form.dart
ACTION: CREATE (confirmado ausente — todos os outros 24
  `create_*_form.dart` existem, este não)

ACTION: criar conforme PARTE 23.7 + PARTE 2 OBJETO 9: título, campo
  Trigger, tempo estimado, lista de steps (texto + estimativa + substeps),
  organizadores/tags, notas, botão "✨ Estruturar com IA" (auditar se já
  existe alguma chamada à API da Anthropic em outro form do app antes de
  decidir a implementação dessa parte — não confirmado nesta auditoria).

────────────────────────────────────────────────────────────────────────────────
3.10 — OBJECT IDENTIFICATION: TRADUÇÃO DE TIPOS INCOMPLETA
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `_translateType()` cobre `system`, `tracker`, `entry`,
  `reminder`, `social_post`, `mood_definition` e corrige labels em inglês
  restantes como `calendar_session`, `task`, `habit`, `note`, `resource` e
  `person`.

FILE: lib/ui/screens/type_signatures_screen.dart
ACTION: EDIT
ANCHOR: `_translateType()` — cobre task, idea, habit, project, goal,
  calendar_session ("Calendar Event", inglês), note, resource, person,
  area, activity, place, label, organizer. Faltam: system, tracker, entry,
  reminder, social_post, mood_definition.
ADD ao switch: 'system'→'Sistema', 'tracker'→'Rastreador',
  'entry'→'Entrada de Diário', 'reminder'→'Lembrete',
  'social_post'→'Post Social', 'mood_definition'→'Definição de Humor'.
CORRIGIR 'calendar_session'→'Sessão de Calendário' (remover inglês).
REMOVER 'idea' quando a Task 0.3 for resolvida.

────────────────────────────────────────────────────────────────────────────────
3.11 — CORPO DA DAILY NOTE (## Habits) USA WIKILINK EM VEZ DO TÍTULO DO
       HABIT
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `generateDailyNoteBody()` aceita `habitLabels` e
  `pactHabitSlugs`; o `VaultNotifier` passa os hábitos carregados para
  renderizar títulos legíveis e sufixo `← pact` em vez de `[[slug]]`.

FILE: lib/services/markdown_parser.dart
ACTION: EDIT
ANCHOR: `generateDailyNoteBody()`, bloco `if (habits.isNotEmpty)` — escreve
  `'- $status [[$slug]]$details'`. Exemplo da spec usa o TÍTULO em texto
  puro: `- [x] Meditar (Slot 1: 08:00)` / `- [x] Escrever 100 palavras ←
  pact`.
ACTION:
  1. Mudar assinatura de `generateDailyNoteBody()` para também receber
     `List<Habit> habitDefs` (ou `Map<String,String> slugToTitle`) e usar
     `habit.title` na renderização em vez do slug.
  2. ADD sufixo " ← pact" quando `habit.habitMode == HabitMode.pact`
     (depende da Task 0.1).
  3. Opcional: incluir rótulo do slot ("Slot 1: 08:00") lendo de
     `habit.slots` pelo índice usado no toggle.

────────────────────────────────────────────────────────────────────────────────
3.12 — SystemDefinition.scheduler É EXTENSÃO NÃO DOCUMENTADA
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — extensão documentada em `guidelines.md`; `CreateSystemForm`
  já expõe/persiste scheduler opcional em `SystemDefinition.scheduler`.

FILE: lib/models/system_model.dart
ACTION: DECISÃO — campo `Scheduler? scheduler` não está na PARTE 2 OBJETO
  9 da spec. Documentar formalmente no guidelines.md como extensão
  ("Systems podem ter um Scheduler opcional para execução recorrente") ou
  remover se não houver UI conectada (conferir quando create_system_form.dart
  — Task 3.9 — for criado).

================================================================================
COBERTURA E PRÓXIMOS PASSOS (Phase 17+, depois de TIER 0–2 implementados)
================================================================================

Lido integralmente nesta auditoria: todos os 35 models de lib/models/;
lib/services/obsidian_service.dart, markdown_parser.dart,
dataview_generator.dart, automation_service.dart, kpi_engine.dart;
lib/models/system_model.dart, scheduler.dart; ~90% de
lib/providers/vault_provider.dart (cortado em `importExistingVault()`);
lib/ui/widgets/triple_check_sheet.dart, steering_sheet.dart,
create_menu_sheet.dart, command_center_overlay.dart, habit_row.dart;
lib/ui/screens/type_signatures_screen.dart.

NÃO auditado ainda (recomendado para uma Phase 17 futura, DEPOIS de TIER
0–2 estarem implementados e validados com `flutter analyze` + `flutter test`):
  • Restante de vault_provider.dart (`importExistingVault`,
    `updateObject`/`deleteObject` completos de VaultNotifier).
  • lib/services/notification_service.dart, scheduler_service.dart
    (implementação real dos 11+2 tipos de regra), sync_manager.dart,
    sync_queue_service.dart, google_drive_sync_service.dart,
    backup_service.dart.
  • Todos os 24 arquivos de lib/ui/forms/ (nenhum lido diretamente —
    inclui create_habit_form.dart, crítico para confirmar a UI de criação/
    edição de Pact depois da Task 0.1).
  • A maior parte de lib/ui/screens/ (~55 arquivos) e lib/ui/widgets/
    (~65 arquivos) — incluindo mood_chart_widget.dart, analysis_calendar.dart,
    mood_settings_screen.dart, system_detail_screen.dart, e a confirmação
    de que combined_analysis_screen.dart realmente não existe (não está
    na listagem de arquivos do projeto, apesar de a PARTE 23.4 descrever
    uma tela dedicada inteira).

================================================================================
END OF GAP ANALYSIS — ADENDO V2 (Phases 12–16 consolidadas)
================================================================================


GAP ANALYSIS v1
Audience: AI coding agent with full repo access
Convention: every instruction is an atomic, unambiguous action on a specific
            file + location. No explanations unless they prevent a mistake.
================================================================================

HOW TO READ THIS DOCUMENT
  ► FILE: path from repo root
  ► ACTION: CREATE | EDIT | ADD_FIELD | ADD_METHOD | REPLACE | DELETE
  ► ANCHOR: exact class/method/line to locate before acting
  ► INSTRUCTION: what to write / change
  Each task is self-contained. Do them in PHASE order — later phases depend
  on earlier ones.

PACKAGE DEPENDENCIES — add to pubspec.yaml before starting:
  flutter_colorpicker: ^1.1.0
  package_info_plus: ^8.0.0
  google_fonts: ^6.2.1   ← already present; confirm
  path_provider: ^2.1.0  ← already present; confirm

================================================================================
PHASE 1 — THEME SYSTEM
Goal: replace hardcoded AppColors with a runtime-switchable ThemeData
      driven by a persisted AppThemeConfig model + ThemeProvider.
================================================================================

────────────────────────────────────────────────────────────────────────────────
TASK 1.1 — CREATE lib/models/app_theme_config.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `lib/models/app_theme_config.dart` existe
  com presets e cor de acento; a arquitetura atual usa presets leves por
  `SettingsProvider`, não temas customizados JSON completos do v1 antigo.

FILE: lib/models/app_theme_config.dart
ACTION: CREATE (file does not exist)

Create a pure-Dart class AppThemeConfig with:

FIELDS (all required, no nullable):
  String id
  String name
  bool isPreset          // preset=true → cannot be deleted by user
  // Light mode ARGB ints (store as int, convert with Color(value))
  int lightPrimary       // default 0xFFFFB000
  int lightSecondary     // default 0xFF0EA5E9
  int lightSurface       // default 0xFFFFFFFF
  int lightBackground    // default 0xFFF8F9FB
  int lightTextPrimary   // default 0xFF1A1D26
  // Dark mode ARGB ints
  int darkPrimary        // default 0xFFFFB000
  int darkSecondary      // default 0xFF0EA5E9
  int darkSurface        // default 0xFF1A1C25
  int darkBackground     // default 0xFF0F1117
  int darkTextPrimary    // default 0xFFF3F4F6
  // Font
  String fontFamily      // default 'Inter'

METHODS:

  factory AppThemeConfig.fromJson(Map<String,dynamic> j) → reads all fields,
    uses int.tryParse fallback to defaults listed above.

  Map<String,dynamic> toJson() → returns all fields as JSON-safe map.

  ThemeData toThemeData(Brightness brightness) →
    final isPrimary = brightness == Brightness.dark;
    final primary   = Color(isPrimary ? darkPrimary   : lightPrimary);
    final secondary = Color(isPrimary ? darkSecondary : lightSecondary);
    final surface   = Color(isPrimary ? darkSurface   : lightSurface);
    final bg        = Color(isPrimary ? darkBackground: lightBackground);
    final txtPri    = Color(isPrimary ? darkTextPrimary: lightTextPrimary);
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: txtPri,
        background: bg,
        onBackground: txtPri,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: brightness == Brightness.dark
          ? const Color(0xFF2D3040) : const Color(0xFFE5E7EB),
      textTheme: GoogleFonts.getTextTheme(fontFamily),
      useMaterial3: true,
    );

  static List<AppThemeConfig> get presets → returns 5 hardcoded presets:
    id='citrine',   name='Citrine',   isPreset=true  → use existing AppColors values
    id='ocean',     name='Oceano',    isPreset=true
      light: primary=0xFF0284C7, secondary=0xFF0EA5E9, surface=0xFFFFFFFF,
             bg=0xFFF0F9FF, textPrimary=0xFF0C4A6E
      dark:  primary=0xFF38BDF8, secondary=0xFF7DD3FC, surface=0xFF0C1A2E,
             bg=0xFF060D1A, textPrimary=0xFFE0F2FE
    id='forest',    name='Floresta',  isPreset=true
      light: primary=0xFF16A34A, secondary=0xFF22C55E, surface=0xFFFFFFFF,
             bg=0xFFF0FDF4, textPrimary=0xFF14532D
      dark:  primary=0xFF4ADE80, secondary=0xFF86EFAC, surface=0xFF0D1F14,
             bg=0xFF061009, textPrimary=0xFFDCFCE7
    id='dusk',      name='Anoitecer', isPreset=true
      light: primary=0xFF7C3AED, secondary=0xFFA78BFA, surface=0xFFFFFFFF,
             bg=0xFFFAF5FF, textPrimary=0xFF3B0764
      dark:  primary=0xFFA78BFA, secondary=0xFFDDD6FE, surface=0xFF1A0F2E,
             bg=0xFF0D0618, textPrimary=0xFFEDE9FE
    id='minimal',   name='Minimalista', isPreset=true
      light: primary=0xFF18181B, secondary=0xFF52525B, surface=0xFFFFFFFF,
             bg=0xFFFAFAFA, textPrimary=0xFF09090B
      dark:  primary=0xFFFAFAFA, secondary=0xFFA1A1AA, surface=0xFF18181B,
             bg=0xFF09090B, textPrimary=0xFFFAFAFA
    All presets use fontFamily='Inter'.

IMPORTS NEEDED: flutter/material.dart, google_fonts/google_fonts.dart

────────────────────────────────────────────────────────────────────────────────
TASK 1.2 — CREATE lib/providers/theme_provider.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `theme_provider.dart` existe e expõe
  `themeProvider`, `availableThemesProvider` e `activeThemeConfigProvider`,
  convertendo `themeMode/activeThemeId` persistidos em `SettingsProvider`
  para `ThemeData` light/dark.

FILE: lib/providers/theme_provider.dart
ACTION: CREATE (file does not exist)

Dependencies: shared_preferences (via sharedPreferencesProvider from
              lib/providers/settings_provider.dart), AppThemeConfig.

STATE CLASS: AppThemeState
  final List<AppThemeConfig> themes   // presets + user-saved
  final String activeThemeId          // default 'citrine'
  final String themeMode              // 'auto' | 'light' | 'dark', default 'auto'

  AppThemeConfig get activeTheme →
    themes.firstWhere((t) => t.id == activeThemeId,
                      orElse: () => AppThemeConfig.presets.first)

  ThemeMode get flutterThemeMode →
    themeMode == 'light' ? ThemeMode.light :
    themeMode == 'dark'  ? ThemeMode.dark  : ThemeMode.system

NOTIFIER CLASS: ThemeNotifier extends Notifier<AppThemeState>
  PREFS KEYS:
    'theme_active_id'   → String
    'theme_mode'        → String ('auto'|'light'|'dark')
    'theme_saved_list'  → JSON String of List<Map>

  build() →
    prefs = ref.read(sharedPreferencesProvider)
    savedJson = prefs.getString('theme_saved_list')
    userThemes = savedJson != null
        ? (jsonDecode(savedJson) as List).map(AppThemeConfig.fromJson).toList()
        : <AppThemeConfig>[]
    return AppThemeState(
      themes: [...AppThemeConfig.presets, ...userThemes],
      activeThemeId: prefs.getString('theme_active_id') ?? 'citrine',
      themeMode: prefs.getString('theme_mode') ?? 'auto',
    )

  void activateTheme(String id) →
    prefs.setString('theme_active_id', id)
    state = state.copyWith(activeThemeId: id)

  void setThemeMode(String mode) →   // 'auto'|'light'|'dark'
    prefs.setString('theme_mode', mode)
    state = state.copyWith(themeMode: mode)

  void saveTheme(AppThemeConfig theme) →
    userThemes = state.themes.where((t) => !t.isPreset).toList()
    updated = [...userThemes, theme]
    prefs.setString('theme_saved_list', jsonEncode(updated.map((t)=>t.toJson()).toList()))
    state = state.copyWith(themes: [...AppThemeConfig.presets, ...updated])
    activateTheme(theme.id)

  void updateTheme(AppThemeConfig theme) →
    userThemes = state.themes.where((t) => !t.isPreset).toList()
    updated = userThemes.map((t) => t.id == theme.id ? theme : t).toList()
    prefs.setString('theme_saved_list', jsonEncode(updated.map((t)=>t.toJson()).toList()))
    state = state.copyWith(themes: [...AppThemeConfig.presets, ...updated])

  void deleteTheme(String id) →
    // Guard: cannot delete presets
    if (AppThemeConfig.presets.any((p) => p.id == id)) return
    userThemes = state.themes.where((t) => !t.isPreset && t.id != id).toList()
    prefs.setString('theme_saved_list', jsonEncode(userThemes.map((t)=>t.toJson()).toList()))
    var newActiveId = state.activeThemeId
    if (newActiveId == id) newActiveId = 'citrine'
    state = state.copyWith(
      themes: [...AppThemeConfig.presets, ...userThemes],
      activeThemeId: newActiveId,
    )

  void duplicateTheme(String id) →
    source = state.themes.firstWhere((t) => t.id == id)
    copy = source.toJson()
    copy['id'] = DateTime.now().millisecondsSinceEpoch.toString()
    copy['name'] = 'Cópia de ${source.name}'
    copy['isPreset'] = false
    saveTheme(AppThemeConfig.fromJson(copy))

PROVIDER:
  final themeProvider = NotifierProvider<ThemeNotifier, AppThemeState>(
      ThemeNotifier.new);

────────────────────────────────────────────────────────────────────────────────
TASK 1.3 — EDIT lib/main.dart — connect ThemeProvider to MaterialApp
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `main.dart` consome `themeProvider` e conecta
  `theme`, `darkTheme` e `themeMode` no `MaterialApp`.

FILE: lib/main.dart
ACTION: EDIT

ANCHOR: locate the class that returns MaterialApp (search for 'MaterialApp(')
  It is inside CitrineApp or _CitrineAppState (ConsumerWidget/ConsumerStatefulWidget).

CHANGE 1 — add import at top of file:
  import 'providers/theme_provider.dart';
  import 'models/app_theme_config.dart';

CHANGE 2 — inside the build() that contains MaterialApp, before the return:
  final themeState = ref.watch(themeProvider);

CHANGE 3 — replace the existing theme:/darkTheme:/themeMode: arguments:
  BEFORE (approximate — find exact):
    theme: ThemeData(...),      // or ThemeData.light()
    darkTheme: ThemeData(...),  // or ThemeData.dark()

  AFTER:
    theme:     themeState.activeTheme.toThemeData(Brightness.light),
    darkTheme: themeState.activeTheme.toThemeData(Brightness.dark),
    themeMode: themeState.flutterThemeMode,

────────────────────────────────────────────────────────────────────────────────
TASK 1.4 — EDIT lib/ui/theme.dart — remove dynamic colors, keep semantic only
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — não aplicado literalmente. O app mantém `AppTheme`/
  `AppColors` como compatibilidade central do design system atual, enquanto
  `themeProvider` injeta acento e modo no `ThemeData`. Remover esses helpers
  agora causaria refatoração massiva fora do escopo e conflita com as
  diretrizes atuais do projeto.

FILE: lib/ui/theme.dart
ACTION: EDIT

DELETE these static const fields from AppColors (they are now in ThemeData):
  primary, primaryLight, primaryDark, accent, secondary, secondaryLight,
  background, surface, cardFill, surfaceVariant,
  darkBackground, darkSurface, darkCardFill,
  textPrimary, textSecondary, textMuted, textOnPrimary,
  darkTextPrimary, darkTextSecondary,
  divider, darkDivider, navInactive

KEEP these (they are semantic, never change with theme):
  success, warning, error, info,
  priorityHigh, priorityMedium, priorityLow,
  habitGreen, habitBlue, habitPurple, habitOrange, habitPink

EDIT cardDecoration(BuildContext context):
  REPLACE: color: isDark ? AppColors.darkCardFill : AppColors.cardFill
  WITH:    color: Theme.of(context).colorScheme.surface

  REPLACE: color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)
  WITH:    color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.08 : 0.06)

EDIT cardDecorationFlat(BuildContext context):
  REPLACE: color: isDark ? AppColors.darkCardFill : AppColors.cardFill
  WITH:    color: Theme.of(context).colorScheme.surface

  REPLACE border color reference to AppColors.darkDivider / AppColors.divider
  WITH:    Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)

EDIT sectionHeaderStyle:
  REPLACE: color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary
  WITH:    color: Theme.of(context).colorScheme.onBackground

DELETE static methods: backgroundColor, surfaceColor, cardFillColor,
  surfaceVariantColor, textPrimaryColor, textSecondaryColor, textMutedColor
  → They are replaced by colorScheme.* calls at call-sites (see TASK 1.5).

────────────────────────────────────────────────────────────────────────────────
TASK 1.5 — GLOBAL FIND-AND-REPLACE for AppColors dynamic refs
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — não executar substituição global mecânica. A regra atual
  do projeto permite `AppTheme`/`AppColors`; substituições serão feitas por
  demanda quando cada tela for tocada, preservando compatibilidade visual.

Run these replacements across ALL .dart files in lib/:

  AppColors.primary           → Theme.of(context).colorScheme.primary
  AppColors.secondary         → Theme.of(context).colorScheme.secondary
  AppColors.background        → Theme.of(context).colorScheme.background
  AppColors.surface           → Theme.of(context).colorScheme.surface
  AppColors.cardFill          → Theme.of(context).colorScheme.surface
  AppColors.surfaceVariant    → Theme.of(context).colorScheme.surfaceVariant
  AppColors.darkBackground    → Theme.of(context).colorScheme.background
  AppColors.darkSurface       → Theme.of(context).colorScheme.surface
  AppColors.darkCardFill      → Theme.of(context).colorScheme.surface
  AppColors.textPrimary       → Theme.of(context).colorScheme.onBackground
  AppColors.textSecondary     → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.6)
  AppColors.textMuted         → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.38)
  AppColors.darkTextPrimary   → Theme.of(context).colorScheme.onBackground
  AppColors.darkTextSecondary → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.6)
  AppColors.divider           → Theme.of(context).colorScheme.outline.withValues(alpha:0.3)
  AppColors.darkDivider       → Theme.of(context).colorScheme.outline.withValues(alpha:0.2)
  AppColors.navInactive       → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.4)
  AppColors.textOnPrimary     → Theme.of(context).colorScheme.onPrimary
  AppColors.primaryLight      → Theme.of(context).colorScheme.primary.withValues(alpha:0.7)
  AppColors.primaryDark       → Theme.of(context).colorScheme.primary
  AppColors.accent            → Theme.of(context).colorScheme.primary
  AppColors.secondaryLight    → Theme.of(context).colorScheme.secondary.withValues(alpha:0.7)
  AppTheme.backgroundColor(context)    → Theme.of(context).colorScheme.background
  AppTheme.surfaceColor(context)       → Theme.of(context).colorScheme.surface
  AppTheme.cardFillColor(context)      → Theme.of(context).colorScheme.surface
  AppTheme.surfaceVariantColor(context)→ Theme.of(context).colorScheme.surfaceVariant
  AppTheme.textPrimaryColor(context)   → Theme.of(context).colorScheme.onBackground
  AppTheme.textSecondaryColor(context) → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.6)
  AppTheme.textMutedColor(context)     → Theme.of(context).colorScheme.onBackground.withValues(alpha:0.38)

NOTE: In const contexts where context is unavailable (e.g. const TextStyle),
  remove const keyword and use Theme.of(context) normally.
  In widgets that don't receive BuildContext, add context parameter or
  use Theme.of(navigatorKey.currentContext!) only as last resort.

────────────────────────────────────────────────────────────────────────────────
TASK 1.6 — REWRITE lib/ui/screens/appearance_screen.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `AppearanceScreen` não é mais stub: permite
  escolher modo Sistema/Claro/Escuro e tema ativo, persistindo em
  `SettingsProvider` e aplicando imediatamente via `themeProvider`.

FILE: lib/ui/screens/appearance_screen.dart
ACTION: REPLACE entirely (current file is a non-functional stub — see below)

CURRENT FILE (confirmed by code read):
  Shows 6 colored circles (_Swatch) with no onTap.
  No provider connection. No persistence. Completely inert.

NEW FILE STRUCTURE — AppearanceScreen is a ConsumerStatefulWidget.

STATE:
  AppThemeConfig? _editingTheme   // null = not in edit mode
  String _editSection             // which color picker is open: '' | 'lightPrimary' | etc.

BUILD — returns Scaffold with ListView containing these sections in order:

  SECTION A — MODO (SegmentedButton or 3 tappable chips)
    Options: 'auto' (Sistema), 'light' (Claro), 'dark' (Escuro)
    Current selection: ref.watch(themeProvider).themeMode
    onTap: ref.read(themeProvider.notifier).setThemeMode(value)

  SECTION B — PRESETS / TEMAS SALVOS
    Header row: Text('Temas') + TextButton('+ Novo', onPressed: _startNewTheme)
    SingleChildScrollView horizontal containing one _ThemePresetCard per theme:
      _ThemePresetCard fields: AppThemeConfig theme, bool isActive
      Appearance: Container 120×80, borderRadius 16
        - 3 color circles (primary/secondary/surface of current system brightness)
        - Text(theme.name) below
        - Border 2px primary color if isActive
      onTap: ref.read(themeProvider.notifier).activateTheme(theme.id)
      onLongPress (non-preset only): showModalBottomSheet with options:
        'Editar'     → _startEditTheme(theme)
        'Duplicar'   → ref.read(themeProvider.notifier).duplicateTheme(theme.id)
        'Deletar'    → confirm dialog → ref.read(themeProvider.notifier).deleteTheme(theme.id)

  SECTION C — COLOR EDITOR (AnimatedSize, only visible when _editingTheme != null)
    Title row: Text('Editando: ${_editingTheme?.name}')
    For each of the 5 color roles, show a _ColorRoleRow:
      _ColorRoleRow(label, lightColorInt, darkColorInt, onLightTap, onDarkTap)
      Appearance: Row with label + two 40×40 tappable color squares (☀️ and 🌙)
      onTap for each square: show _ColorPickerSheet(initialColor, onChanged)
        _ColorPickerSheet: uses flutter_colorpicker ColorPicker widget
          + TextField for hex input (controller prefilled with hex string)
          + onColorChanged: calls setState to update _editingTheme's field

    The 5 roles (fieldName in AppThemeConfig, label, icon):
      lightPrimary / darkPrimary     → 'Primária' (buttons, badges)
      lightSecondary / darkSecondary → 'Secundária' (links, chips)
      lightSurface / darkSurface     → 'Superfície' (cards)
      lightBackground / darkBackground → 'Fundo' (tela)
      lightTextPrimary / darkTextPrimary → 'Texto'

    Below roles: mini PREVIEW widget showing a fake card and button using
      _editingTheme!.toThemeData(Brightness.light) and Brightness.dark side by side

  SECTION D — FONTE (only visible when _editingTheme != null)
    Text('Fonte')
    Wrap of _FontChip for each font:
      fonts = ['Inter', 'Lato', 'Nunito', 'Merriweather', 'Source Sans 3', 'Roboto Slab']
      _FontChip: tappable chip showing font name rendered in that font
        selected = _editingTheme?.fontFamily == fontName
        onTap: setState(() => _editingTheme = _editingTheme!.copyWith(fontFamily: fontName))

  SECTION E — SAVE BUTTON (only visible when _editingTheme != null)
    TextField for theme name (controller pre-filled with _editingTheme!.name)
    ElevatedButton('Salvar tema', onPressed: _saveEditingTheme)
    TextButton('Cancelar', onPressed: () => setState(()=>_editingTheme=null))

METHODS:
  _startNewTheme():
    setState(() => _editingTheme = AppThemeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Meu tema',
      isPreset: false,
      // copy values from active theme
      ...ref.read(themeProvider).activeTheme fields
    ))

  _startEditTheme(AppThemeConfig t):
    setState(() => _editingTheme = t)

  _saveEditingTheme():
    final t = _editingTheme!
    if state.themes.any((x) => x.id == t.id && !x.isPreset):
      ref.read(themeProvider.notifier).updateTheme(t)
    else:
      ref.read(themeProvider.notifier).saveTheme(t)
    setState(() => _editingTheme = null)

────────────────────────────────────────────────────────────────────────────────
TASK 1.7 — ADD themeMode and activeThemeId to AppSettings + SettingsNotifier
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `AppSettings` possui `themeMode` e `activeThemeId`, e
  `SettingsNotifier` persiste/atualiza ambos.

FILE: lib/providers/settings_provider.dart
ACTION: EDIT

NOTE: themeMode and activeThemeId are now owned by ThemeNotifier (TASK 1.2).
  AppSettings does NOT need them. No changes needed to AppSettings class.
  This task is intentionally empty — the separation is already clean.

================================================================================
PHASE 2 — CRASH LOGS
================================================================================

────────────────────────────────────────────────────────────────────────────────
TASK 2.1 — EDIT lib/main.dart — move CrashReportService.init() to top of main()
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `CrashReportService.instance.init()` é inicializado em
  `main.dart` antes do carregamento do vault e recebe versão do app.

FILE: lib/main.dart
ACTION: EDIT

ANCHOR: the top-level async main() function. It currently starts with:
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  ...

ADD immediately after WidgetsFlutterBinding.ensureInitialized():
  // CRASH REPORTS — must be first, before any other await
  PackageInfo pkgInfo;
  try {
    pkgInfo = await PackageInfo.fromPlatform();
  } catch (_) {
    pkgInfo = PackageInfo(appName:'Citrine',packageName:'',version:'unknown',buildNumber:'');
  }
  await CrashReportService.instance.init(appVersion: pkgInfo.version);

ADD import at top of file:
  import 'package:package_info_plus/package_info_plus.dart';

────────────────────────────────────────────────────────────────────────────────
TASK 2.2 — EDIT lib/services/crash_report_service.dart — fix save directory
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — manter o padrão atual das diretrizes do projeto:
  armazenamento interno em `diagnostics/crash_reports` e cópia no vault em
  `_diagnostics/crash_reports`. Não migrar para `CitrineLogs/` externo nesta
  rodada.

FILE: lib/services/crash_report_service.dart
ACTION: EDIT

ANCHOR: method _writeReport(String filename, String content) — find it after
  _buildReport(). It currently calls getApplicationDocumentsDirectory() or similar.

REPLACE the directory resolution inside _writeReport with:
  Directory? baseDir;
  try {
    // External storage is visible via USB file transfer on Android
    baseDir = await getExternalStorageDirectory();
  } catch (_) {}
  baseDir ??= await getApplicationDocumentsDirectory();

  final crashDir = Directory('${baseDir.path}/CitrineLogs/crash_reports');
  if (!await crashDir.exists()) await crashDir.create(recursive: true);
  final file = File('${crashDir.path}/$filename');
  await file.writeAsString(content, flush: true);

────────────────────────────────────────────────────────────────────────────────
TASK 2.3 — EDIT lib/ui/screens/diagnostic_reports_screen.dart — add Export All
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — a tela de diagnósticos possui ação
  "Exportar tudo"; a implementação consolida os relatórios e copia para a
  área de transferência, evitando dependência adicional de share.

FILE: lib/ui/screens/diagnostic_reports_screen.dart
ACTION: EDIT

ANCHOR: locate the AppBar actions: [] list.

ADD to actions:
  IconButton(
    icon: const Icon(Icons.share_outlined),
    tooltip: 'Exportar todos',
    onPressed: _exportAll,
  )

ADD method _exportAll():
  Future<void> _exportAll() async {
    // Find the crash_reports directory (same path as _writeReport)
    Directory? baseDir;
    try { baseDir = await getExternalStorageDirectory(); } catch (_) {}
    baseDir ??= await getApplicationDocumentsDirectory();
    final crashDir = Directory('${baseDir.path}/CitrineLogs/crash_reports');
    if (!await crashDir.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum log encontrado.')));
      return;
    }
    final files = crashDir.listSync().whereType<File>().toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum log encontrado.')));
      return;
    }
    // Use share_plus to share all files
    await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(),
        subject: 'Citrine Crash Logs');
  }

ADD import: package:share_plus/share_plus.dart
  (add share_plus: ^10.0.0 to pubspec.yaml if not present)

================================================================================
PHASE 3 — PROPERTY GRID COMPONENT
================================================================================

────────────────────────────────────────────────────────────────────────────────
TASK 3.1 — CREATE lib/ui/widgets/property_grid.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `property_grid.dart` existe com `PropertyGrid`,
  `PropertyCardState`, `PropertyCard`, `_PropertyCardWidget` e `StarRating`,
  mantendo compatibilidade com `PropertyGridItem` usado pela tela atual.

FILE: lib/ui/widgets/property_grid.dart
ACTION: CREATE (file does not exist)

ENUM PropertyCardState:
  normal, empty, overdue, dueToday, streakActive, complete

CLASS PropertyCard (data class, no Widget):
  FIELDS (all required except marked):
    IconData icon
    String label
    String? value           // null → renders as empty state
    PropertyCardState state // default: normal (derived externally, not auto)
    Color? leftBorderColor  // for priority
    VoidCallback? onTap
    Widget? customChild     // overrides value text (for stars, booleans, etc.)

WIDGET PropertyGrid extends StatelessWidget:
  CONSTRUCTOR: const PropertyGrid({required List<PropertyCard> cards, Key? key})

  build(context):
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,   // wider than tall — compact card
        ),
        itemCount: cards.length,
        itemBuilder: (ctx, i) => _PropertyCardWidget(card: cards[i]),
      ),
    );

WIDGET _PropertyCardWidget extends StatelessWidget:
  CONSTRUCTOR: const _PropertyCardWidget({required PropertyCard card})

  build(context):
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background color by state
    final bgColor = switch (card.state) {
      PropertyCardState.empty       => cs.onBackground.withValues(alpha: isDark ? 0.06 : 0.04),
      PropertyCardState.overdue     => const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.10),
      PropertyCardState.dueToday    => const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.10),
      PropertyCardState.streakActive=> const Color(0xFF22C55E).withValues(alpha: isDark ? 0.18 : 0.10),
      PropertyCardState.complete    => cs.primary.withValues(alpha: 0.08),
      _                             => cs.surface,
    };

    // Text/icon color by state
    final contentColor = switch (card.state) {
      PropertyCardState.empty       => cs.onBackground.withValues(alpha: 0.35),
      PropertyCardState.overdue     => const Color(0xFFEF4444),
      PropertyCardState.dueToday    => const Color(0xFFF59E0B),
      PropertyCardState.streakActive=> const Color(0xFF22C55E),
      _                             => cs.onSurface,
    };

    return GestureDetector(
      onTap: card.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: card.leftBorderColor != null
              ? Border(left: BorderSide(color: card.leftBorderColor!, width: 3))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(card.icon, size: 13, color: contentColor.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Flexible(child: Text(card.label,
                style: TextStyle(fontSize: 11, color: contentColor.withValues(alpha:0.7)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              // empty state: show add icon
              if (card.state == PropertyCardState.empty)
                Icon(Icons.add_rounded, size: 13,
                     color: contentColor.withValues(alpha: 0.5)),
            ]),
            // value area
            if (card.customChild != null)
              card.customChild!
            else
              Text(
                card.value ?? '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: card.state == PropertyCardState.empty
                      ? FontWeight.w400 : FontWeight.w600,
                  color: contentColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );

HELPER WIDGET StarRating (use as customChild):
  StatelessWidget, takes double rating (0.0-5.0)
  Shows filled/half/empty star Icons in primary color, size 14

────────────────────────────────────────────────────────────────────────────────
TASK 3.2 — EDIT lib/ui/screens/universal_detail_view.dart — replace property cards
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `UniversalDetailView` usa `PropertyGrid` para blocos de
  propriedades e mantém builders por tipo com células acionáveis.

FILE: lib/ui/screens/universal_detail_view.dart
ACTION: EDIT

ADD import: '../widgets/property_grid.dart'

The file uses a CustomScrollView with SliverToBoxAdapter children.
Find the section where individual property cards are built for each type.
This is typically after the title area SliverToBoxAdapter.

For EACH object type, find the block that builds metadata (Criado/Modificado/
Status/etc.) and REPLACE it with a SliverToBoxAdapter containing PropertyGrid.

Use this helper method inside _UniversalDetailViewState to build cards per type:

  List<PropertyCard> _buildPropertyCards(ContentObject obj, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    PropertyCardState _dateState(DateTime? d) {
      if (d == null) return PropertyCardState.empty;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(today)) return PropertyCardState.overdue;
      if (day == today) return PropertyCardState.dueToday;
      return PropertyCardState.normal;
    }

    String _fmtDate(DateTime? d) =>
        d == null ? '' : DateFormat('dd MMM yyyy', 'pt_BR').format(d);
    String _timeAgo(DateTime? d) { /* existing timeAgo logic */ }

    // TASK: remove "created" date card entirely (not useful for user)

    if (obj is Task) {
      return [
        PropertyCard(
          icon: Icons.flag_rounded,
          label: 'Status',
          value: obj.status,
          state: obj.status == 'done' ? PropertyCardState.complete : PropertyCardState.normal,
        ),
        PropertyCard(
          icon: Icons.priority_high_rounded,
          label: 'Prioridade',
          value: obj.priority.isEmpty ? null : obj.priority,
          state: obj.priority.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          leftBorderColor: obj.priority == 'high'   ? AppColors.priorityHigh
                         : obj.priority == 'medium' ? AppColors.priorityMedium
                         : obj.priority == 'low'    ? AppColors.priorityLow : null,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.calendar_today_rounded,
          label: 'Due Date',
          value: _fmtDate(obj.dueDate),
          state: _dateState(obj.dueDate),
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.timer_outlined,
          label: 'Estimativa',
          value: obj.estimatedMinutes == 0 ? null : '${obj.estimatedMinutes}min',
          state: obj.estimatedMinutes == 0 ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.edit_calendar_rounded,
          label: 'Modificado',
          value: _timeAgo(obj.modifiedAt),
        ),
        PropertyCard(
          icon: Icons.repeat_rounded,
          label: 'Recorrência',
          value: obj.recurrenceRule.isEmpty ? null : obj.recurrenceRule,
          state: obj.recurrenceRule.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
      ];
    }

    if (obj is Habit) {
      return [
        PropertyCard(icon: Icons.flag_rounded, label: 'Status', value: obj.status),
        PropertyCard(
          icon: Icons.repeat_rounded,
          label: 'Frequência',
          value: obj.frequencyLabel,
        ),
        PropertyCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Sequência atual',
          value: obj.currentStreak == 0 ? '0 dias' : '${obj.currentStreak} dias',
          state: obj.currentStreak > 0 ? PropertyCardState.streakActive : PropertyCardState.normal,
        ),
        PropertyCard(
          icon: Icons.emoji_events_rounded,
          label: 'Melhor sequência',
          value: '${obj.bestStreak} dias',
        ),
        PropertyCard(
          icon: Icons.history_rounded,
          label: 'Última vez',
          value: _timeAgo(obj.lastCompletedAt),
          state: obj.lastCompletedAt == null ? PropertyCardState.empty : PropertyCardState.normal,
        ),
        PropertyCard(
          icon: Icons.edit_calendar_rounded,
          label: 'Modificado',
          value: _timeAgo(obj.modifiedAt),
        ),
      ];
    }

    if (obj is Goal) {
      return [
        PropertyCard(icon: Icons.flag_rounded, label: 'Status', value: obj.status),
        PropertyCard(
          icon: Icons.calendar_today_rounded,
          label: 'Prazo',
          value: _fmtDate(obj.dueDate),
          state: _dateState(obj.dueDate),
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.trending_up_rounded,
          label: 'Progresso',
          value: '${obj.progressPercent.round()}%',
          state: obj.progressPercent >= 100 ? PropertyCardState.complete : PropertyCardState.normal,
        ),
        PropertyCard(icon: Icons.category_rounded, label: 'Tipo', value: obj.goalType),
        PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado', value: _timeAgo(obj.modifiedAt)),
      ];
    }

    if (obj is Resource) {
      return [
        PropertyCard(icon: Icons.flag_rounded, label: 'Status', value: obj.status),
        PropertyCard(icon: Icons.book_rounded, label: 'Tipo', value: obj.resourceType),
        PropertyCard(
          icon: Icons.person_rounded,
          label: 'Autor',
          value: obj.author.isEmpty ? null : obj.author,
          state: obj.author.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.calendar_today_rounded,
          label: 'Ano',
          value: obj.year.isEmpty ? null : obj.year,
          state: obj.year.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
        ),
        PropertyCard(
          icon: Icons.category_rounded,
          label: 'Categoria',
          value: obj.category.isEmpty ? null : obj.category,
          state: obj.category.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.event_available_rounded,
          label: 'Data de leitura',
          value: _fmtDate(obj.finishedAt),
          state: obj.finishedAt == null ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.star_rounded,
          label: 'Avaliação',
          value: null,
          state: obj.rating == 0 ? PropertyCardState.empty : PropertyCardState.normal,
          customChild: obj.rating > 0
              ? StarRating(rating: obj.rating.toDouble())
              : null,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado', value: _timeAgo(obj.modifiedAt)),
      ];
    }

    if (obj is JournalEntry) {
      return [
        PropertyCard(icon: Icons.today_rounded, label: 'Data', value: _fmtDate(obj.date)),
        PropertyCard(
          icon: Icons.mood_rounded,
          label: 'Humor',
          value: obj.mood.isEmpty ? null : obj.mood,
          state: obj.mood.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado', value: _timeAgo(obj.modifiedAt)),
      ];
    }

    if (obj is Project) {
      return [
        PropertyCard(icon: Icons.flag_rounded, label: 'Status', value: obj.status),
        PropertyCard(
          icon: Icons.priority_high_rounded,
          label: 'Prioridade',
          value: obj.priority.isEmpty ? null : obj.priority,
          state: obj.priority.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          leftBorderColor: obj.priority == 'high'   ? AppColors.priorityHigh
                         : obj.priority == 'medium' ? AppColors.priorityMedium
                         : obj.priority == 'low'    ? AppColors.priorityLow : null,
        ),
        PropertyCard(
          icon: Icons.calendar_today_rounded,
          label: 'Due Date',
          value: _fmtDate(obj.dueDate),
          state: _dateState(obj.dueDate),
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado', value: _timeAgo(obj.modifiedAt)),
      ];
    }

    if (obj is Person) {
      return [
        PropertyCard(
          icon: Icons.people_rounded,
          label: 'Relação',
          value: obj.relation.isEmpty ? null : obj.relation,
          state: obj.relation.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.email_rounded,
          label: 'Email',
          value: obj.email.isEmpty ? null : obj.email,
          state: obj.email.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(
          icon: Icons.cake_rounded,
          label: 'Aniversário',
          value: _fmtDate(obj.birthday),
          state: obj.birthday == null ? PropertyCardState.empty : PropertyCardState.normal,
          onTap: () => _openEditForm(context),
        ),
        PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado', value: _timeAgo(obj.modifiedAt)),
      ];
    }

    // Fallback for Note, Idea, Reminder, Tracker, Snapshot, Organizer:
    return [
      PropertyCard(icon: Icons.flag_rounded, label: 'Status',
        value: (obj as dynamic).status ?? '', state: PropertyCardState.normal),
      PropertyCard(icon: Icons.edit_calendar_rounded, label: 'Modificado',
        value: _timeAgo(obj.modifiedAt)),
    ];
  }

Then in the build() SliverList, REPLACE the old metadata section with:
  SliverToBoxAdapter(
    child: Column(children: [
      const SizedBox(height: 16),
      PropertyGrid(cards: _buildPropertyCards(object, context)),
      const SizedBox(height: 20),
    ]),
  ),

FIELD NAMES: The field names used above (obj.status, obj.priority, obj.dueDate,
  obj.currentStreak, etc.) must match the actual field names in each model.
  Read the corresponding model file before implementing each type block
  to confirm exact field names. Use obj.fieldName — do not guess.

================================================================================
PHASE 4 — RESOURCES SCREEN
================================================================================

────────────────────────────────────────────────────────────────────────────────
TASK 4.1 — EDIT lib/ui/screens/resources_screen.dart — A4 cover proportion
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — capas de Resources na estante/lista usam
  `AspectRatio(1 / 1.414)` com fallback único.

FILE: lib/ui/screens/resources_screen.dart
ACTION: EDIT

ANCHOR: locate the grid item builder (search for GridView or SliverGrid,
  then find the child widget that renders a book/resource card).

Find the image/cover widget inside the grid item. It is likely a ClipRRect or
Container with a fixed height. REPLACE the image container with:

  AspectRatio(
    aspectRatio: 1 / 1.414,  // A4 portrait ratio
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: obj.coverUrl.isNotEmpty
          ? Image.network(obj.coverUrl, fit: BoxFit.cover,
              errorBuilder: (_,__,___) => _buildCoverPlaceholder(obj, context))
          : _buildCoverPlaceholder(obj, context),
    ),
  )

ADD helper _buildCoverPlaceholder(ResourceModel obj, BuildContext context):
  Returns a Container with bg color derived from obj.title hashCode
  (pick one of 6 pastel colors by index) and centered Icon(Icons.book_rounded).

VERIFY: Check if the cover image is fetched twice (once as thumbnail, once
  as full). Search the file for all references to coverUrl / cover / thumbnail.
  If two separate Image widgets exist in the same item, DELETE the duplicate.
  Keep only the AspectRatio one.

STATUS BADGE: after the AspectRatio, add a Stack if not already present,
  positioning in top-right corner:
    Positioned(top:8, right:8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal:6,vertical:3),
        decoration: BoxDecoration(
          color: _statusColor(obj.status).withValues(alpha:0.9),
          borderRadius: BorderRadius.circular(6)),
        child: Text(obj.status.toUpperCase(),
          style: TextStyle(fontSize:10, fontWeight:FontWeight.w700,
                           color:Colors.white)),
      ))

────────────────────────────────────────────────────────────────────────────────
TASK 4.2 — EDIT lib/ui/screens/universal_detail_view.dart — Resource hero cover
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — detalhe de Resource mostra uma única capa A4 antes do
  conteúdo e remove a duplicação de imagem dentro do card.

FILE: lib/ui/screens/universal_detail_view.dart
ACTION: EDIT — Resource-specific detail layout

ANCHOR: inside build() or _buildContent(), find the block that runs when
  object is Resource (search for 'is Resource' or 'Resource').

REPLACE the cover rendering at the top of that block with a SliverAppBar:

  SliverAppBar(
    expandedHeight: MediaQuery.of(context).size.width * 1.414 * 0.55,
    // cap at 55% of screen width × A4 ratio
    pinned: true,
    flexibleSpace: FlexibleSpaceBar(
      background: resource.coverUrl.isNotEmpty
          ? Image.network(resource.coverUrl, fit: BoxFit.cover,
              errorBuilder: (_,__,___) => _buildCoverPlaceholder(resource, context))
          : _buildCoverPlaceholder(resource, context),
    ),
    // Remove back arrow from here — it's already in the outer SliverAppBar
    automaticallyImplyLeading: false,
  )

NOTE: The outer SliverAppBar (pinned, with title=type label) is already present
  in the build(). For Resource, hide it or merge. Simplest: for Resource type,
  skip adding the outer type-label SliverAppBar and only add this cover one.
  Check the conditional logic around SliverAppBar in the current build().

BELOW the SliverAppBar, add in a SliverToBoxAdapter:
  Title: Text(resource.title, fontSize: 26, fontWeight: w800)
  Subtitle: Text('${resource.resourceType} · ${resource.category}',
               color: colorScheme.onBackground.withValues(alpha:0.6))
  Rating row: StarRating(rating: resource.rating.toDouble()) — tappable,
    onTap opens a dialog to select 1-5 stars and calls the update provider.

THEN: PropertyGrid via _buildPropertyCards (TASK 3.2 Resource block)

================================================================================
GUIDELINES AND AGENTS FILES
================================================================================

────────────────────────────────────────────────────────────────────────────────
TASK 5.1 — UPDATE (or CREATE) guidelines.md at repo root
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `guidelines.md` documenta tema atual,
  `PropertyGrid`, diagnósticos, Systems e importação de metadados de
  Resources conforme a arquitetura vigente.

FILE: guidelines.md (repo root)
ACTION: ADD sections (append to existing file, or create if missing)

APPEND exactly:

---

## DESIGN SYSTEM — COLOR USAGE (enforced after Theme System implementation)

NEVER reference these in any widget file:
  AppColors.primary · AppColors.secondary · AppColors.background
  AppColors.surface · AppColors.cardFill · AppColors.surfaceVariant
  AppColors.darkBackground · AppColors.darkSurface · AppColors.darkCardFill
  AppColors.textPrimary · AppColors.textSecondary · AppColors.textMuted
  AppColors.textOnPrimary · AppColors.darkTextPrimary · AppColors.darkTextSecondary
  AppColors.divider · AppColors.darkDivider · AppColors.navInactive
  AppColors.primaryLight · AppColors.primaryDark · AppColors.accent
  AppColors.secondaryLight
  AppTheme.backgroundColor() · AppTheme.surfaceColor() · AppTheme.cardFillColor()
  AppTheme.surfaceVariantColor() · AppTheme.textPrimaryColor()
  AppTheme.textSecondaryColor() · AppTheme.textMutedColor()

ALWAYS use instead:
  Theme.of(context).colorScheme.primary           → primary actions, badges
  Theme.of(context).colorScheme.secondary         → secondary accents, chips
  Theme.of(context).colorScheme.surface           → card backgrounds
  Theme.of(context).colorScheme.onSurface         → text on cards
  Theme.of(context).colorScheme.background        → scaffold/screen background
  Theme.of(context).colorScheme.onBackground      → primary text on screen
  Theme.of(context).colorScheme.onBackground.withValues(alpha:0.6) → secondary text
  Theme.of(context).colorScheme.onBackground.withValues(alpha:0.38) → muted text
  Theme.of(context).colorScheme.outline           → dividers, borders
  Theme.of(context).colorScheme.onPrimary         → text on primary-colored buttons

PERMITTED AppColors refs: priorityHigh, priorityMedium, priorityLow,
  success, warning, error, info,
  habitGreen, habitBlue, habitPurple, habitOrange, habitPink

## DESIGN SYSTEM — OBJECT DETAIL PROPERTIES

ALL detail screens use PropertyGrid (lib/ui/widgets/property_grid.dart).
NEVER build custom metadata cards manually.

PropertyCardState rules (apply when building cards):
  value == null or ''                  → PropertyCardState.empty
  DateTime field and date < today      → PropertyCardState.overdue
  DateTime field and date == today     → PropertyCardState.dueToday
  streak/count field and value > 0     → PropertyCardState.streakActive
  completion/done status               → PropertyCardState.complete
  otherwise                            → PropertyCardState.normal

Priority leftBorderColor mapping:
  'high'   → AppColors.priorityHigh
  'medium' → AppColors.priorityMedium
  'low'    → AppColors.priorityLow

## DESIGN SYSTEM — RESOURCE COVERS

Resource covers (books, films, etc.) are ALWAYS rendered in AspectRatio(1/1.414).
NEVER use a fixed height or square crop for covers.
Cover image appears ONCE per view (no thumbnail + full duplicate).

## CRASH REPORTING

CrashReportService.instance.init() is called as the FIRST await in main().
Crash logs are saved to: getExternalStorageDirectory()/CitrineLogs/crash_reports/
Logs are .md files with YAML frontmatter.

---

────────────────────────────────────────────────────────────────────────────────
TASK 5.2 — UPDATE (or CREATE) agents.md at repo root
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `agents.md` contém instruções extensas de
  arquitetura, crash logs, revisão proativa e padrões de implementação para
  novos objetos/telas.

FILE: agents.md (repo root)
ACTION: ADD sections (append to existing file, or create if missing)

APPEND exactly:

---

## HOW TO READ CRASH LOGS

Method A — via USB (Android, USB Debugging on):
  adb pull /sdcard/Android/data/com.productivity.citrine/files/CitrineLogs/ ./crash_logs/
  Then read the .md files in ./crash_logs/crash_reports/

Method B — via app:
  Settings → Diagnósticos → share icon (top-right) → choose destination

Log file format:
  YAML frontmatter: type, kind, created_at, app_version, platform, route
  ## Context table
  ## Error (type + message)
  ## Dart Stack Trace
  ## Android Thread Dump (ANR only)
  ## Last App Events (circular buffer, last 100 events before crash)

## HOW TO ADD A NEW CONTENT OBJECT TYPE

1. CREATE lib/models/<name>_model.dart — extend ContentObject, implement toJson/fromJson
2. ADD to lib/providers/vault_provider.dart — new provider + allObjectsProvider integration
3. CREATE lib/ui/forms/create_<name>_form.dart
4. ADD to lib/ui/screens/universal_detail_view.dart:
   a. Import the model
   b. Add a block in _buildPropertyCards() returning List<PropertyCard>
   c. Use PropertyCardState rules from guidelines.md
5. ADD to lib/ui/widgets/create_menu_sheet.dart
6. NEVER use AppColors dynamic refs — use colorScheme.* (see guidelines.md)

## HOW TO BUILD A PROPERTY GRID BLOCK FOR A NEW TYPE

Read lib/ui/widgets/property_grid.dart first.
For each metadata field, create a PropertyCard:
  - icon: pick from Icons — prefer _rounded variants
  - label: short string, ≤ 12 chars
  - value: the field value as string, or null if empty/unset
  - state: apply rules from guidelines.md
  - leftBorderColor: set for priority fields only
  - onTap: open edit form (call _openEditForm(context) or equivalent)
  - customChild: use StarRating for rating fields, custom widget for booleans

---

================================================================================
IMPLEMENTATION ORDER SUMMARY
================================================================================

Run phases in order. Each task within a phase can run in parallel.

PHASE 1 (Theme System):
  1.1 Create AppThemeConfig model
  1.2 Create ThemeProvider
  1.3 Connect to MaterialApp in main.dart
  1.4 Refactor theme.dart
  1.5 Global find-and-replace AppColors → colorScheme
  1.6 Rewrite AppearanceScreen
  (1.7 is no-op)

PHASE 2 (Crash Logs):
  2.1 Move init() to top of main()
  2.2 Fix save directory in crash_report_service.dart
  2.3 Add Export All to diagnostic_reports_screen.dart

PHASE 3 (Property Grid):
  3.1 Create property_grid.dart
  3.2 Update universal_detail_view.dart

PHASE 4 (Resources):
  4.1 Fix cover in resources_screen.dart
  4.2 Fix Resource detail in universal_detail_view.dart

PHASE 5 (Docs):
  5.1 Update guidelines.md
  5.2 Update agents.md

VERIFICATION CHECKLIST (run after each phase):
  □ flutter analyze → 0 errors
  □ flutter test → all pass
  □ Hot restart → no exception on home screen
  □ Phase 1: tap each preset in AppearanceScreen → colors change live
  □ Phase 2: trigger a test error (throw Exception in initState of any screen) → .md file appears in CitrineLogs/
  □ Phase 3: open any Task detail → see 2-column grid with colored states
  □ Phase 4: open Resources screen → covers in portrait A4 proportion, no duplicate

================================================================================
END OF SPEC
================================================================================

================================================================================
PHASE 7 — WINDOWS PARITY ANALYSIS + FIXES
================================================================================

ANALYSIS — WHAT THE CODE REVEALS ABOUT WINDOWS STATUS
────────────────────────────────────────────────────────────────────────────────

Reading app_shell.dart, adaptive_layout.dart, and the main layout reveals:

STATUS: Windows is STRUCTURALLY supported (keyboard shortcuts exist in AppShell:
  Ctrl+K, Ctrl+N, Ctrl+F, Ctrl+1-5) but has multiple functional gaps.

GAP 1 — Share Intent / receive_sharing_intent is Android/iOS only
  The entire share-from-other-app flow (main.dart _initShareIntentHandling,
  receive_sharing_intent package) does not run on Windows. On Windows, the
  user has no way to share a URL into the app from a browser.
  FIX: add a clipboard auto-detect banner on Windows (same logic already used
  in social_screen.dart's _checkClipboardUrl) but surfaced app-wide, not just
  in the Social screen.

GAP 2 — Biometric service is mobile-only
  lib/services/biometric_service.dart uses local_auth which has no Windows
  implementation. On Windows, biometric lock silently fails or crashes.
  FIX: in biometric_service.dart, wrap all calls with:
    if (!Platform.isAndroid && !Platform.isIOS) return true; // bypass on desktop

GAP 3 — Notification service is mobile-only
  flutter_local_notifications supports Windows in theory but the current code
  uses AndroidNotificationDetails and DarwinNotificationDetails only.
  Alarm screen / popup screen never trigger on Windows.
  FIX: in notification_service.dart, wrap all notification scheduling with:
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
  And add a Windows-native reminder: use dart:io Process.run to call
  Windows toast via PowerShell (see TASK 7.3).

GAP 4 — Google Drive sync may fail on Windows
  The google_drive_sync_service.dart uses path_provider paths that differ on
  Windows (%APPDATA%\Roaming vs /data/...). Vault path picker must use
  FilePicker (already in pubspec likely) with Windows support.
  FIX: verify getApplicationDocumentsDirectory() returns a valid Windows path.
  Add a test: on first launch on Windows, print the resolved vault path to
  CrashReportService event log.

GAP 5 — Bottom navigation vs sidebar: already handled
  AppShell already shows a NavigationRail for wide screens and bottom bar for
  narrow. This is correct for Windows. No fix needed.

GAP 6 — Window size / drag-to-resize not configured
  On Windows, the app opens at a default small size with no minimum enforced.
  FIX: in main.dart, after WidgetsFlutterBinding.ensureInitialized(), add:
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        minimumSize: Size(900, 600),
        size: Size(1200, 800),
        title: 'Citrine',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  Package needed: window_manager (add to pubspec.yaml: window_manager: ^0.4.0)

GAP 7 — Social posts: save IS working on Android (confirmed by code)
  create_social_post_form.dart calls ref.read(socialPostsProvider.notifier)
  and OEmbedService which uses http package (cross-platform).
  The vault write uses File I/O which works on all platforms.
  CONCLUSION: social posts SAVE correctly on both Android and Windows.
  The only Windows gap is the share intent trigger (GAP 1 above).

────────────────────────────────────────────────────────────────────────────────
TASK 7.1 — EDIT lib/services/biometric_service.dart — desktop bypass
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — decisão do usuário: não mexer em biometria desktop nesta rodada.

FILE: lib/services/biometric_service.dart
ACTION: EDIT

ADD import at top: import 'dart:io' show Platform;

ANCHOR: find the method that checks/requests biometric auth. It likely calls
  LocalAuthentication().authenticate(...).

WRAP the entire authenticate call body:
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return true;  // No biometric on desktop — treat as authenticated
  }
  // ... existing mobile code continues unchanged

Do the same for any method that calls LocalAuthentication().canCheckBiometrics
  or .getAvailableBiometrics() — return [] on desktop.

────────────────────────────────────────────────────────────────────────────────
TASK 7.2 — EDIT lib/services/notification_service.dart — desktop bypass
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `NotificationService` retorna cedo no desktop para init,
  schedule/show/cancel, evitando chamadas mobile em Windows/Linux/macOS.

FILE: lib/services/notification_service.dart
ACTION: EDIT

ADD import: import 'dart:io' show Platform;

ANCHOR: method init() / initialize() that calls
  FlutterLocalNotificationsPlugin().initialize(...).

WRAP entire init() body:
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    debugPrint('[NotificationService] Desktop: notifications skipped.');
    return;
  }
  // ... existing mobile init unchanged

ANCHOR: method scheduleReminder() / _scheduleLocal().
WRAP entire body same way — return early on desktop.

ANCHOR: method cancelNotification() / cancelAll().
WRAP — return early on desktop (no-op is fine).

This prevents crashes. Windows toast support can be added later separately.

────────────────────────────────────────────────────────────────────────────────
TASK 7.3 — EDIT lib/main.dart — window sizing for desktop
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `window_manager` foi adicionado e `main.dart` configura
  tamanho inicial/mínimo, centralização e foco em desktop.

FILE: lib/main.dart
ACTION: EDIT

ADD to pubspec.yaml (do this first):
  window_manager: ^0.4.0

ADD import to main.dart:
  import 'dart:io' show Platform;
  import 'package:window_manager/window_manager.dart';

ANCHOR: inside main(), after WidgetsFlutterBinding.ensureInitialized()
  and after CrashReportService.instance.init() (TASK 2.1).

ADD:
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      minimumSize: Size(900, 600),
      size: Size(1280, 820),
      center: true,
      title: 'Citrine',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

────────────────────────────────────────────────────────────────────────────────
TASK 7.4 — EDIT lib/ui/screens/social_screen.dart — Windows clipboard banner
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — o banner de clipboard já roda sem guard mobile.
  O FAB persistente "colar URL" foi pulado por decisão do usuário.

FILE: lib/ui/screens/social_screen.dart
ACTION: EDIT

This is already done for Android via _checkClipboardUrl() in initState.
The social screen already has the clipboard banner logic.

VERIFY: _checkClipboardUrl() uses Clipboard.getData(Clipboard.kTextPlain)
  which is cross-platform. Confirm it runs on Windows by checking there is
  no Platform.isAndroid guard around it. If there is one, remove the guard.

If no guard exists: no change needed — clipboard detection already works
  on Windows.

ADDITIONALLY — add a persistent "Paste URL" FAB on Windows:
ANCHOR: build() method, find FloatingActionButton or FAB area.

ADD a second FAB only on desktop (stack with existing FAB or replace):
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
    Positioned(
      bottom: 80, right: 20,
      child: FloatingActionButton.small(
        heroTag: 'paste_url',
        tooltip: 'Colar URL da área de transferência',
        child: Icon(Icons.content_paste_rounded),
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final url = data?.text?.trim() ?? '';
          if (url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CreateSocialPostForm(initialUrl: url)));
            }
          }
        },
      ),
    )

================================================================================
PHASE 8 — RESOURCE LINK SHARE (like social posts, but for books/films)
Goal: user shares Amazon/Goodreads/IMDB/OpenLibrary URL →
      app scrapes metadata → pre-fills CreateResourceForm → user confirms/edits → saves
================================================================================

ANALYSIS — WHAT EXISTS VS WHAT'S NEEDED
────────────────────────────────────────────────────────────────────────────────
WHAT EXISTS:
  - OEmbedService: fetches OpenGraph + oEmbed for social platforms
  - CreateResourceForm: accepts initialTitle and existingResource
  - Resource model: has title, author, year, coverImage, synopsis, resourceType
  - SocialPost share flow: URL → OEmbedService.fetchMetadata() → pre-filled form

WHAT'S MISSING:
  - A service that recognizes Amazon/Goodreads/IMDB/OpenLibrary URLs and knows
    which API/scrape strategy to use for each
  - A scraped-data → Resource mapper
  - A "preview before save" mode in CreateResourceForm (URL-initiated flow)
  - Share intent routing: when URL comes from system share, route to resource
    form instead of social form based on URL pattern

────────────────────────────────────────────────────────────────────────────────
TASK 8.1 — CREATE lib/services/resource_metadata_service.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `ResourceMetadataService` existe com detecção de fontes,
  fetch de metadados e `ResourceDraft`.

FILE: lib/services/resource_metadata_service.dart
ACTION: CREATE

PURPOSE: given a URL, detect the source (Amazon, Goodreads, IMDB, OpenLibrary,
         Google Books), fetch metadata, return a ResourceDraft.

CLASS ResourceDraft (defined in this file):
  String? title
  String? author
  String? resourceType    // 'Livro' | 'Filme' | 'Série' | 'General'
  String? synopsis
  String? coverUrl
  int? year
  int? pages
  String? category
  String? sourceUrl       // the original URL the user shared
  String? sourceId        // e.g. IMDB tt1234567, ISBN, etc.
  String? sourceName      // 'Amazon', 'IMDB', 'Goodreads', 'OpenLibrary'

CLASS ResourceMetadataService:

  static ResourceSource detectSource(String url):
    final lower = url.toLowerCase();
    if (lower.contains('amazon.com') || lower.contains('amazon.com.br'))
      return ResourceSource.amazon;
    if (lower.contains('goodreads.com'))
      return ResourceSource.goodreads;
    if (lower.contains('imdb.com'))
      return ResourceSource.imdb;
    if (lower.contains('openlibrary.org'))
      return ResourceSource.openLibrary;
    if (lower.contains('books.google.com') || lower.contains('play.google.com/store/books'))
      return ResourceSource.googleBooks;
    return ResourceSource.unknown;

  static bool isResourceUrl(String url):
    return detectSource(url) != ResourceSource.unknown;

  static Future<ResourceDraft> fetchMetadata(String url):
    final source = detectSource(url);
    return switch (source) {
      ResourceSource.openLibrary => _fetchOpenLibrary(url),
      ResourceSource.googleBooks => _fetchGoogleBooks(url),
      ResourceSource.imdb        => _fetchImdb(url),
      ResourceSource.amazon      => _fetchViaOpenGraph(url, 'Amazon'),
      ResourceSource.goodreads   => _fetchViaOpenGraph(url, 'Goodreads'),
      ResourceSource.unknown     => _fetchViaOpenGraph(url, 'Web'),
    };

  // ── OpenLibrary ──────────────────────────────────────────────────────────
  static Future<ResourceDraft> _fetchOpenLibrary(String url):
    // Extract work ID or ISBN from URL patterns:
    //   https://openlibrary.org/works/OL12345W
    //   https://openlibrary.org/isbn/9780000000000
    //   https://openlibrary.org/books/OL12345M

    String? workId = RegExp(r'/works/(OL\w+)').firstMatch(url)?.group(1);
    String? isbn   = RegExp(r'/isbn/(\d{10,13})').firstMatch(url)?.group(1);
    String? bookId = RegExp(r'/books/(OL\w+)').firstMatch(url)?.group(1);

    Map<String,dynamic>? data;

    if (workId != null):
      final resp = await http.get(
        Uri.parse('https://openlibrary.org/works/$workId.json'));
      if (resp.statusCode == 200) data = jsonDecode(resp.body);

    else if (isbn != null):
      final resp = await http.get(
        Uri.parse('https://openlibrary.org/isbn/$isbn.json'));
      if (resp.statusCode == 200):
        data = jsonDecode(resp.body);
        // If book record, get its work:
        final workKey = data?['works']?[0]?['key'] as String?;
        if (workKey != null):
          final wResp = await http.get(
            Uri.parse('https://openlibrary.org$workKey.json'));
          if (wResp.statusCode == 200) data = jsonDecode(wResp.body);

    else if (bookId != null):
      final resp = await http.get(
        Uri.parse('https://openlibrary.org/books/$bookId.json'));
      if (resp.statusCode == 200) data = jsonDecode(resp.body);

    if (data == null) return ResourceDraft(sourceUrl: url, sourceName: 'OpenLibrary');

    // Extract cover
    String? coverId;
    final covers = data['covers'];
    if (covers is List && covers.isNotEmpty) coverId = covers.first.toString();
    final coverUrl = coverId != null
        ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
        : null;

    // Extract author: need separate author fetch
    String? author;
    final authorKeys = data['authors'];
    if (authorKeys is List && authorKeys.isNotEmpty):
      final authorKey = (authorKeys.first['author']?['key']
                      ?? authorKeys.first['key']) as String?;
      if (authorKey != null):
        final aResp = await http.get(
          Uri.parse('https://openlibrary.org$authorKey.json'));
        if (aResp.statusCode == 200):
          author = jsonDecode(aResp.body)['name'] as String?;

    // Extract description
    final desc = data['description'];
    final synopsis = desc is Map ? desc['value'] as String? : desc as String?;

    // Extract year from first_publish_date
    final yearStr = data['first_publish_date'] as String?;
    final year = yearStr != null ? int.tryParse(yearStr.replaceAll(RegExp(r'[^0-9]'), '').substring(0,4)) : null;

    return ResourceDraft(
      title: data['title'] as String?,
      author: author,
      resourceType: 'Livro',
      synopsis: synopsis,
      coverUrl: coverUrl,
      year: year,
      sourceUrl: url,
      sourceName: 'OpenLibrary',
    );

  // ── Google Books ──────────────────────────────────────────────────────────
  static Future<ResourceDraft> _fetchGoogleBooks(String url):
    // Extract volume ID from URL:
    //   https://books.google.com/books?id=XXXXXXXX
    //   https://play.google.com/store/books/details?id=XXXXXXXX
    final id = RegExp(r'[?&]id=([^&]+)').firstMatch(url)?.group(1)
            ?? RegExp(r'/details/[^?]+\?id=([^&]+)').firstMatch(url)?.group(1);

    if (id == null) return _fetchViaOpenGraph(url, 'Google Books');

    final resp = await http.get(
      Uri.parse('https://www.googleapis.com/books/v1/volumes/$id'));
    if (resp.statusCode != 200) return _fetchViaOpenGraph(url, 'Google Books');

    final data = jsonDecode(resp.body) as Map<String,dynamic>;
    final info = data['volumeInfo'] as Map<String,dynamic>? ?? {};

    final authors = (info['authors'] as List?)?.join(', ');
    final thumbnail = (info['imageLinks'] as Map?)?['thumbnail'] as String?;
    // Upgrade thumbnail to larger version:
    final coverUrl = thumbnail?.replaceAll('zoom=1', 'zoom=3')
                              .replaceAll('&edge=curl', '')
                              .replaceFirst('http://', 'https://');

    final year = int.tryParse(
      (info['publishedDate'] as String? ?? '').split('-').first);

    return ResourceDraft(
      title: info['title'] as String?,
      author: authors,
      resourceType: 'Livro',
      synopsis: info['description'] as String?,
      coverUrl: coverUrl,
      year: year,
      pages: info['pageCount'] as int?,
      category: (info['categories'] as List?)?.first as String?,
      sourceUrl: url,
      sourceName: 'Google Books',
    );

  // ── IMDB ─────────────────────────────────────────────────────────────────
  static Future<ResourceDraft> _fetchImdb(String url):
    // Extract IMDB ID: tt followed by digits
    final ttId = RegExp(r'/(tt\d+)').firstMatch(url)?.group(1);

    // Strategy: use OpenGraph from IMDB page (no official free API)
    final draft = await _fetchViaOpenGraph(url, 'IMDB');

    // Detect type from URL:
    //   /title/ttXXX/ → could be movie or series
    //   URL contains /episodes → series
    String resourceType = 'Filme';
    if (url.toLowerCase().contains('episodes') ||
        url.toLowerCase().contains('series')) {
      resourceType = 'Série';
    }

    // From OpenGraph, og:title for IMDB is usually "Movie Title (Year)"
    // Extract year from title if present:
    String? title = draft.title;
    int? year = draft.year;
    if (title != null):
      final match = RegExp(r'\((\d{4})\)$').firstMatch(title.trim());
      if (match != null):
        year = int.tryParse(match.group(1) ?? '');
        title = title.replaceAll(match.group(0)!, '').trim();

    // Cover: og:image from IMDB is usually the poster — use it
    return ResourceDraft(
      title: title,
      author: draft.author,   // usually director from og:description
      resourceType: resourceType,
      synopsis: draft.synopsis,
      coverUrl: draft.coverUrl,
      year: year,
      sourceUrl: url,
      sourceId: ttId,
      sourceName: 'IMDB',
    );

  // ── Generic OpenGraph (Amazon, Goodreads, fallback) ───────────────────────
  static Future<ResourceDraft> _fetchViaOpenGraph(String url, String sourceName):
    // Reuse OEmbedService._fetchOpenGraph if accessible, or replicate here.
    // Fetch the page HTML and extract:
    //   og:title, og:description, og:image, og:type
    //   For Amazon: look for the JSON-LD script tag with @type Book/Movie
    try:
      final resp = await http.get(Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; CitrineBot/1.0)',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return ResourceDraft(sourceUrl: url, sourceName: sourceName);

      final body = resp.body;

      String? _og(String prop):
        final match = RegExp('content=["\']([^"\']*)["\']',caseSensitive:false)
          .firstMatch(RegExp('<meta[^>]*property=["\']og:$prop["\'][^>]*>',
                             caseSensitive:false, dotAll:true).firstMatch(body)?.group(0) ?? '');
        return match?.group(1);

      String? _meta(String name):
        final match = RegExp('content=["\']([^"\']*)["\']',caseSensitive:false)
          .firstMatch(RegExp('<meta[^>]*name=["\']$name["\'][^>]*>',
                             caseSensitive:false, dotAll:true).firstMatch(body)?.group(0) ?? '');
        return match?.group(1);

      // Try JSON-LD for richer data (Amazon, Goodreads use it)
      Map<String,dynamic>? jsonLd;
      final ldMatch = RegExp(
        r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        caseSensitive:false, dotAll:true).firstMatch(body);
      if (ldMatch != null):
        try: jsonLd = jsonDecode(ldMatch.group(1)!.trim());
        catch (_): {}

      final title = _og('title') ?? jsonLd?['name'] as String?
                  ?? _meta('title');
      final desc  = _og('description') ?? jsonLd?['description'] as String?
                  ?? _meta('description');
      final image = _og('image') ?? jsonLd?['image'] as String?;
      final author = jsonLd?['author']?['name'] as String?
                  ?? jsonLd?['author'] as String?;

      // Detect resource type from JSON-LD @type or og:type
      final ldType = (jsonLd?['@type'] as String? ?? '').toLowerCase();
      String resourceType = 'General';
      if (ldType.contains('book')) resourceType = 'Livro';
      else if (ldType.contains('movie')) resourceType = 'Filme';
      else if (ldType.contains('tvseries') || ldType.contains('series')) resourceType = 'Série';
      // If sourceName gives a hint:
      if (resourceType == 'General' && sourceName == 'Goodreads') resourceType = 'Livro';
      if (resourceType == 'General' && sourceName == 'IMDB') resourceType = 'Filme';

      // Year from JSON-LD datePublished or dateCreated
      final dateStr = jsonLd?['datePublished'] as String?
                   ?? jsonLd?['dateCreated'] as String?;
      final year = dateStr != null ? int.tryParse(dateStr.split('-').first) : null;

      return ResourceDraft(
        title: title,
        author: author,
        resourceType: resourceType,
        synopsis: desc,
        coverUrl: image,
        year: year,
        sourceUrl: url,
        sourceName: sourceName,
      );
    catch (e):
      return ResourceDraft(sourceUrl: url, sourceName: sourceName);

ENUM ResourceSource:
  amazon, goodreads, imdb, openLibrary, googleBooks, unknown

────────────────────────────────────────────────────────────────────────────────
TASK 8.2 — EDIT lib/ui/forms/create_resource_form.dart — add URL-initiated mode
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `CreateResourceForm` aceita `initialUrl`, busca metadados,
  mostra estado de importação e preenche campos editáveis.

FILE: lib/ui/forms/create_resource_form.dart
ACTION: EDIT

ADD constructor parameter:
  final String? initialUrl;    // when set, fetch metadata on init and pre-fill

EDIT initState():
  ANCHOR: the block after `if (widget.existingResource != null) { ... }`

  ADD at the end of initState():
    if (widget.existingResource == null && widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFromUrl());
    }

ADD field to state:
  bool _isFetchingUrl = false;
  String? _fetchError;
  String? _sourceUrl;
  String? _sourceName;

ADD method _fetchFromUrl():
  Future<void> _fetchFromUrl() async {
    final url = widget.initialUrl!.trim();
    setState(() { _isFetchingUrl = true; _fetchError = null; });
    try {
      final draft = await ResourceMetadataService.fetchMetadata(url);
      if (!mounted) return;
      setState(() {
        _isFetchingUrl = false;
        _sourceUrl = draft.sourceUrl;
        _sourceName = draft.sourceName;
        if (draft.title != null) _titleController.text = draft.title!;
        if (draft.author != null) _authorController.text = draft.author!;
        if (draft.synopsis != null) _synopsisController.text = draft.synopsis!;
        if (draft.coverUrl != null) _coverUrlController.text = draft.coverUrl!;
        if (draft.year != null) _yearController.text = draft.year.toString();
        if (draft.pages != null) _pagesController.text = draft.pages.toString();
        if (draft.category != null) _categoryController.text = draft.category!;
        if (draft.resourceType != null) _resourceType = draft.resourceType!;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isFetchingUrl = false; _fetchError = e.toString(); });
    }
  }

EDIT build() — ADD loading banner and metadata preview:
  ANCHOR: inside the CustomScrollView slivers list, after SliverAppBar.

  ADD as first SliverToBoxAdapter:

  if (_isFetchingUrl)
    SliverToBoxAdapter(child: LinearProgressIndicator()),

  if (_fetchError != null)
    SliverToBoxAdapter(child: Container(
      margin: EdgeInsets.fromLTRB(20,8,20,0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha:0.10),
        borderRadius: BorderRadius.circular(10)),
      child: Text('Erro ao buscar metadados: $_fetchError',
        style: TextStyle(color: AppColors.error, fontSize:13)),
    )),

  if (_sourceUrl != null && !_isFetchingUrl && _fetchError == null)
    SliverToBoxAdapter(child: _buildSourceBanner()),

ADD method _buildSourceBanner():
  Builds a small banner showing:
    "📚 Dados importados de $_sourceName"
    + a small icon of the cover (if coverUrlController has value)
    + TextButton "Editar manualmente" that does nothing (form is already editable)
  Appearance: Container with primary.withValues(alpha:0.08) background,
    Row with source icon + text + optional thumbnail preview

ALSO EDIT the save method (_saveResource or equivalent):
  ANCHOR: find where Resource is created from form fields and passed to provider.
  ADD to the Resource object: if _sourceUrl != null, store it somewhere.
  OPTION: add to Resource.tags: ['source:$_sourceUrl'] — this preserves the link
  in the vault without needing a new field. OR add a new field sourceUrl to
  Resource model (see TASK 8.3).

────────────────────────────────────────────────────────────────────────────────
TASK 8.3 — EDIT lib/models/resource_model.dart — add sourceUrl field
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Resource.sourceUrl` existe, serializa em `source_url`,
  lê do frontmatter e é preservado no `copyWith()`.

FILE: lib/models/resource_model.dart
ACTION: EDIT

ADD field:
  String? sourceUrl;    // original URL from Amazon/IMDB/etc. that seeded this resource

EDIT constructor: add optional parameter String? sourceUrl

EDIT toMarkdown():
  ANCHOR: frontmatter map building.
  ADD: if (sourceUrl != null) frontmatter['source_url'] = sourceUrl;

EDIT fromMarkdown():
  ANCHOR: after resource.loadBaseMap(frontmatter)
  ADD: resource.sourceUrl = _stringValue(frontmatter['source_url']);

EDIT copyWith(): add String? sourceUrl parameter and include in returned Resource.

────────────────────────────────────────────────────────────────────────────────
TASK 8.4 — EDIT main.dart share intent routing — route resource URLs differently
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — URLs compartilhadas de resource abrem
  `CreateResourceForm(initialUrl)`; demais URLs seguem para SocialPost.

FILE: lib/main.dart
ACTION: EDIT

ANCHOR: method _openSharedSocialUrl(String url) or _handleSharedMedia()
  This is the method called when a URL arrives from the share intent.
  Currently it always opens CreateSocialPostForm.

REPLACE the logic with:
  Future<void> _handleSharedUrl(String url) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null || !nav.mounted) return;

    // Route to resource form if it's a book/movie URL
    if (ResourceMetadataService.isResourceUrl(url)) {
      nav.push(MaterialPageRoute(
        builder: (_) => CreateResourceForm(initialUrl: url),
      ));
    } else {
      // Existing social post flow
      nav.push(MaterialPageRoute(
        builder: (_) => CreateSocialPostForm(initialUrl: url),
      ));
    }
  }

REPLACE all call sites of _openSharedSocialUrl(url) with _handleSharedUrl(url).
ADD import: import 'services/resource_metadata_service.dart';

────────────────────────────────────────────────────────────────────────────────
TASK 8.5 — EDIT lib/ui/screens/resources_screen.dart — add clipboard/paste button
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — Resources checa clipboard, mostra banner de importação e
  possui ação "Importar link".

FILE: lib/ui/screens/resources_screen.dart
ACTION: EDIT

ANCHOR: locate initState() or the build() method.

ADD initState() with clipboard check (mirrors social_screen.dart pattern):
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboardUrl());
  }

ADD method _checkClipboardUrl():
  Future<void> _checkClipboardUrl() async {
    if (!mounted) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return;
    if (!ResourceMetadataService.isResourceUrl(text)) return;

    // Show snackbar banner with "Importar [Amazon/Goodreads/IMDB]?"
    final source = ResourceMetadataService.detectSource(text);
    final sourceName = source.name; // 'amazon', 'goodreads', etc.

    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
      content: Text('Link de $sourceName detectado. Importar como resource?'),
      leading: const Icon(Icons.link_rounded),
      actions: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CreateResourceForm(initialUrl: text)));
          },
          child: const Text('Importar'),
        ),
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Ignorar'),
        ),
      ],
    ));
  }

ALSO ADD a "+" FAB action "Importar link":
  ANCHOR: FloatingActionButton or SpeedDial in the build().
  ADD a second action "Importar link" (paste icon) that does:
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = data?.text?.trim() ?? '';
    if (url.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CreateResourceForm(initialUrl: url)));
    } else {
      // Show a text input dialog to paste/type the URL
      _showUrlInputDialog(context);
    }

ADD _showUrlInputDialog(BuildContext context):
  showDialog with a TextField for URL input + "Buscar" button that pushes
  CreateResourceForm(initialUrl: urlController.text.trim()).

────────────────────────────────────────────────────────────────────────────────
TASK 8.6 — UPDATE guidelines.md — resource metadata patterns
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `guidelines.md` documenta Resource metadata import,
  roteamento e persistência em `Resource.sourceUrl`.

FILE: guidelines.md (repo root)
ACTION: APPEND

APPEND:

---

## RESOURCE METADATA IMPORT

URL routing rule (in _handleSharedUrl):
  ResourceMetadataService.isResourceUrl(url) == true → CreateResourceForm(initialUrl:)
  else → CreateSocialPostForm(initialUrl:)

ResourceMetadataService.detectSource() priority order:
  openLibrary → googleBooks → imdb → amazon → goodreads → unknown

Cover URLs: always use HTTPS. For OpenLibrary, use size suffix -L.jpg (large).
  For Google Books, replace zoom=1 with zoom=3 and remove &edge=curl.
  Never store thumbnail-size cover URLs — always resolve to the largest available.

ResourceDraft → Resource mapping:
  draft.resourceType must be one of: 'Livro', 'Filme', 'Série', 'Podcast',
  'Artigo', 'Curso', 'General' — match existing settingsProvider.resourceTypeFilters.
  If no match, default to 'General'.

sourceUrl is stored in Resource.sourceUrl field (not in tags).
  Do not use tags for source tracking.

Clipboard check in ResourcesScreen runs once per initState.
  Do NOT re-run on every build() — only in initState postFrameCallback.

---

## WINDOWS / DESKTOP PARITY RULES

Always wrap with Platform.isWindows/isMacOS/isLinux guard:
  - Any LocalAuthentication call → return true (bypass)
  - Any FlutterLocalNotificationsPlugin call → return (no-op)
  - Any receive_sharing_intent call → skip entirely

On desktop, share intent is replaced by clipboard detection.
  Every screen that has a share-triggered flow must also have
  a clipboard-paste button/banner for Windows users.

Window minimum size: 900×600. Default size: 1280×820.
  Set in main() via window_manager before runApp().

---

================================================================================
PHASE 7 + 8 IMPLEMENTATION ORDER
================================================================================

PHASE 7 (Windows Parity) — run in order:
  7.1  biometric_service.dart — desktop bypass
  7.2  notification_service.dart — desktop bypass
  7.3  main.dart — window_manager setup
  7.4  social_screen.dart — verify clipboard works on Windows, add paste FAB

PHASE 8 (Resource Link Share) — run in order:
  8.1  Create resource_metadata_service.dart (+ ResourceDraft class + ResourceSource enum)
  8.2  Edit create_resource_form.dart — add initialUrl param + _fetchFromUrl()
  8.3  Edit resource_model.dart — add sourceUrl field
  8.4  Edit main.dart — _handleSharedUrl() routing to resource vs social form
  8.5  Edit resources_screen.dart — clipboard banner + paste button
  8.6  Append to guidelines.md

VERIFICATION CHECKLIST — Phase 7:
  □ flutter analyze → 0 errors on Windows target
  □ Run on Windows: biometric lock screen bypassed, app continues normally
  □ Run on Windows: app starts at 1280×820, cannot resize below 900×600
  □ Run on Windows: Social screen shows paste FAB
  □ Run on Windows: copy a YouTube URL → Social screen shows clipboard banner

VERIFICATION CHECKLIST — Phase 8:
  □ ResourceMetadataService.detectSource('https://openlibrary.org/works/OL1234') == openLibrary
  □ ResourceMetadataService.detectSource('https://www.imdb.com/title/tt1234567') == imdb
  □ ResourceMetadataService.isResourceUrl('https://instagram.com/p/abc') == false
  □ Share an OpenLibrary URL → CreateResourceForm opens with title+author+cover pre-filled
  □ Share a YouTube URL → CreateSocialPostForm opens (not resource form)
  □ Share an IMDB URL → CreateResourceForm opens, resourceType == 'Filme'
  □ Share a Goodreads URL → CreateResourceForm opens, resourceType == 'Livro'
  □ In ResourcesScreen: copy Amazon book URL to clipboard → banner appears
  □ Tap "Importar" → form opens pre-filled
  □ Save → Resource persists in vault with sourceUrl in frontmatter
  □ On Windows: copy Goodreads URL → Resources screen clipboard banner works

================================================================================
END OF PHASES 7 + 8
================================================================================


================================================================================
PHASE 9 — GUIDELINES V3 CONFORMANCE FIXES
Source: diff analysis of guidelines_v3_final.md vs. current codebase.
Severity labels: P0=data corruption/crash | P1=missing feature | P2=mismatch
Each task has FILE + ACTION + ANCHOR + exact instructions. Implement in order.
================================================================================

────────────────────────────────────────────────────────────────────────────────
SPRINT 9-A  ·  P0 FIXES — implement these before anything else
────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.1 — FIX entry_type serialization bug
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `JournalEntry.entryTypeToString()` grava `field_note` sem
  underscore inicial e `ObsidianService.fixEntryTypeMigration()` corrige legado.

FILE: lib/models/journal_entry.dart
ACTION: EDIT

PROBLEM: toMarkdown() uses:
  frontmatter['entry_type'] = entryType.name
    .replaceAll(RegExp(r'([A-Z])'), r'_\1').toLowerCase();
This produces '_field_note' (leading underscore) instead of 'field_note'.

ANCHOR: find the line containing replaceAll(RegExp(r'([A-Z])'), inside toMarkdown().

REPLACE that single expression with:
  frontmatter['entry_type'] = _entryTypeToString(entryType);

ADD private helper method to the class (outside toMarkdown):
  static String _entryTypeToString(JournalEntryType t) => switch (t) {
    JournalEntryType.standard  => 'standard',
    JournalEntryType.fieldNote => 'field_note',
    JournalEntryType.pmn       => 'pmn',
  };

VERIFY fromMarkdown() already strips underscores before comparing — confirmed
  in the diff. No change needed to fromMarkdown().

ALSO ADD a migration helper (call once at app startup after vault load):
  In lib/services/obsidian_service.dart, add method fixEntryTypeMigration():
    Scans all files where type==journal_entry (or type==entry).
    If frontmatter contains entry_type starting with '_':
      strips the leading underscore and rewrites the file.
    Log each fix to CrashReportService as an info event, not an error.

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.2 — FIX JournalEntry.date to preserve time component
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `fromMarkdown()` mescla data com `time_of_day`/`time`;
  `toMarkdown()` grava data canônica e `time_of_day`; `baseTime` usa `date`.

FILE: lib/models/journal_entry.dart
ACTION: EDIT

PROBLEM: JournalEntry.date is set from frontmatter['date'] which is a date-only
  string (e.g. "2026-05-19"). The time lives in a separate field timeOfDay
  (String "08:30"). They are never merged, so baseTime has no hour component
  and Timeline ordering by time-of-day is broken.

ANCHOR: find fromMarkdown() method. Find where date and timeOfDay are set.

REPLACE the date assignment block with:
  // Parse the date-only field
  final rawDate = frontmatter['date']?.toString() ?? '';
  DateTime parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();

  // Merge timeOfDay into the date if present
  final rawTime = frontmatter['time_of_day']?.toString()
               ?? frontmatter['timeOfDay']?.toString()
               ?? '';
  if (rawTime.isNotEmpty) {
    final parts = rawTime.split(':');
    if (parts.length >= 2) {
      final hour   = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      parsedDate = DateTime(
        parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
    }
  }
  entry.date = parsedDate;

ALSO EDIT toMarkdown():
  ANCHOR: find where date is written to frontmatter.
  REPLACE:
    frontmatter['date'] = date.toIso8601String().split('T')[0];
  WITH:
    frontmatter['date'] = '${date.year.toString().padLeft(4,'0')}'
        '-${date.month.toString().padLeft(2,'0')}'
        '-${date.day.toString().padLeft(2,'0')}';
    if (date.hour != 0 || date.minute != 0) {
      frontmatter['time_of_day'] =
          '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    }

ALSO EDIT baseTime getter:
  ANCHOR: @override DateTime? get baseTime
  REPLACE body with: return date; // now has time component when set

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.3 — FIX System: make run_count / last_run / average_minutes derived
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `toMarkdown()` não persiste os campos derivados e
  `SystemsNotifier._deriveSystemStats()` calcula a partir das tasks vinculadas.

FILE: lib/models/system_model.dart
ACTION: EDIT

PROBLEM: toMarkdown() writes run_count, last_run, average_minutes directly to
  frontmatter, violating spec rule "always derived, never written directly."

ANCHOR: find in toMarkdown() the lines:
  map['run_count'] = runCount;
  if (lastRun != null) map['last_run'] = lastRun!.toIso8601String();
  map['average_minutes'] = averageMinutes;

DELETE those three lines from toMarkdown(). Do not replace them.

The fields runCount, lastRun, averageMinutes should remain as in-memory
  computed properties, NOT persisted. They are derived from the Task history
  linked to this System (tasks with linked_system == this system's id).

ADD comment above those fields in the class:
  // Derived fields — never persisted. Computed from linked Task history.
  // See SystemsProvider._deriveSystemStats() for calculation logic.

IN lib/providers/systems_provider.dart (or wherever SystemsProvider lives):
  Add method _deriveSystemStats(System system, List<Task> allTasks):
    final linked = allTasks.where(
      (t) => t.linkedSystem == system.id && t.stage == TaskStage.finalized);
    system.runCount = linked.length;
    system.lastRun  = linked.isEmpty ? null
        : linked.map((t) => t.updatedAt).reduce((a,b) => a.isAfter(b)?a:b);
    if (linked.isNotEmpty) {
      final totalMin = linked
          .where((t) => t.estimatedMinutes > 0)
          .map((t) => t.estimatedMinutes)
          .fold(0, (a,b) => a+b);
      system.averageMinutes = linked.isEmpty ? 0 : totalMin ~/ linked.length;
    }
  Call _deriveSystemStats() after loading all objects, not on every read.

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.4 — FIX JournalEntry.type: 'journal_entry' → 'entry'
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `JournalEntry.type` retorna `entry` e a migração corrige
  frontmatter legado `journal_entry`.

FILE: lib/models/journal_entry.dart
ACTION: EDIT

ANCHOR: @override String get type => 'journal_entry';

REPLACE with: @override String get type => 'entry';

MIGRATION: in obsidian_service.dart fixEntryTypeMigration() (TASK 9.A.1),
  also rewrite any file where frontmatter['type'] == 'journal_entry'
  to 'entry' (same single-pass scan, no second loop needed).

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.5 — ADD goal_mode field to Goal model
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `GoalMode`, `goalMode`, `objective`, `strategy` e
  `phases` existem com serialização, parsing e `copyWith()`.

FILE: lib/models/goal_model.dart
ACTION: EDIT

ADD enum (top of file, before class):
  enum GoalMode { standard, plan }

ADD fields to Goal class:
  GoalMode goalMode;        // default: GoalMode.standard (Regra 5)
  String? objective;        // plan mode only
  String? strategy;         // plan mode only
  List<String> phases;      // plan mode only, default []

EDIT constructor: add parameters with defaults:
  this.goalMode = GoalMode.standard,
  this.objective,
  this.strategy,
  List<String>? phases,
  ...
  : phases = phases ?? [],

EDIT toMarkdown():
  ADD: frontmatter['goal_mode'] = goalMode.name;
  ADD (plan only): if (goalMode == GoalMode.plan) {
    if (objective != null) frontmatter['objective'] = objective;
    if (strategy  != null) frontmatter['strategy']  = strategy;
    if (phases.isNotEmpty) frontmatter['phases']     = phases;
  }

EDIT fromMarkdown():
  ADD after loadBaseMap():
    final rawMode = frontmatter['goal_mode']?.toString() ?? 'standard';
    goal.goalMode = GoalMode.values.firstWhere(
      (m) => m.name == rawMode, orElse: () => GoalMode.standard);
    goal.objective = frontmatter['objective'] as String?;
    goal.strategy  = frontmatter['strategy']  as String?;
    goal.phases    = List<String>.from(frontmatter['phases'] as List? ?? []);

EDIT copyWith(): add goalMode, objective, strategy, phases parameters.

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.6 — CREATE CalendarSession model
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `calendar_session.dart` existe com modelo, markdown,
  parsing e `copyWith()`.

FILE: lib/models/calendar_session.dart
ACTION: CREATE (file does not exist)

enum CalendarSessionState { scheduled, inProgress, completed, backlog, cancelled }

class CalendarSession extends ContentObject:
  FIELDS:
    DateTime date
    CalendarSessionState state       // default: scheduled
    String? timeOfDay                // "HH:MM"
    int duration                     // minutes, default 60
    String? endTime                  // "HH:MM" (computed or set)
    bool multiDay                    // default false
    String? linkedTaskId             // WikiLink slug to Task
    String? linkedGoalId             // WikiLink slug to Goal
    List<String> subtasks            // inline subtask titles
    String? note
    String? color
    List<String> places
    List<String> participants
    String? linkedGoogleEventId
    String? linkedGoogleEventTitle
    DateTime? linkedGoogleEventDate
    String? linkedGoogleEventUrl
    // timer — stored as minutes worked int
    int timerMinutesWorked
    bool backlog                     // default false

  @override String get type => 'calendar_session';

  @override String toMarkdown():
    build frontmatter map from all fields using naming convention:
      state.name for state (e.g. 'in_progress')
      'time_of_day' for timeOfDay
      'end_time' for endTime
      'multi_day' for multiDay
      'linked_task' for linkedTaskId (as WikiLink: '[[SLUG]]')
      'linked_goal' for linkedGoalId (as WikiLink: '[[SLUG]]')
      'linked_google_event_id' etc.
      'timer_minutes_worked' for timerMinutesWorked
    body = note ?? ''
    Call generateMarkdown(frontmatter, body)

  factory CalendarSession.fromMarkdown(Map frontmatter, String body):
    Read all fields. State default: scheduled if absent.
    WikiLink fields: strip [[ ]] to get slug.

  CalendarSession copyWith(...): standard pattern.

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.7 — REGISTER CalendarSession in vault loader
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — loader reconhece `calendar_session`,
  `calendarSessionsProvider` existe e o FAB abre `CreateCalendarSessionForm`.

FILE: lib/providers/vault_provider.dart  (or lib/services/obsidian_service.dart)
ACTION: EDIT

ANCHOR: find the switch/if-else that dispatches on frontmatter['type'] to build
  ContentObjects (e.g. case 'task': return Task.fromMarkdown(...)).

ADD case:
  case 'calendar_session':
    return CalendarSession.fromMarkdown(frontmatter, body);

ADD provider (same pattern as tasksProvider, habitsProvider etc.):
  final calendarSessionsProvider = Provider<List<CalendarSession>>((ref) {
    final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
    return all.whereType<CalendarSession>().toList();
  });

ADD to create_menu_sheet.dart (TASK 9.C.1 handles FAB restructure; ensure
  CalendarSession is included in the Plan tab).

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.8 — REWRITE MoodDefinition model — 2-axis system
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `MoodDefinition` usa quadrante, pleasantness, energy,
  source/hidden/aliases/order e possui 48 system moods.

FILE: lib/models/mood_model.dart
ACTION: REWRITE

NOTE: This is the largest P0. The current 1D model (numericValue) must become
  a 2-axis model (pleasantness 1–5, energy 1–5, quadrant). Existing mood data
  in vault files uses mood:: [[calm]] inline wikilinks — these are PRESERVED.
  The migration risk is low because mood definitions are a separate layer.

REPLACE entire file content with:

enum MoodQuadrant { red, yellow, green, blue }
enum MoodSource { system, user }

class MoodDefinition:
  FIELDS (all match guidelines exactly):
    String id                     // slug: 'calm', 'anxious'
    MoodSource source             // system | user
    bool hidden                   // default false
    String label                  // PT label: "Calma"
    String? labelEn               // EN label: "Calm" (system only)
    String? description           // 1–2 sentences
    String emoji
    MoodQuadrant quadrant
    int pleasantness              // 1–5
    int energy                    // 1–5
    String color                  // hex of quadrant color
    List<String> aliases          // Obsidian native aliases
    int order                     // for picker sorting

  @override String get type => 'mood_definition';

  @override String toMarkdown():
    Only write file if source == MoodSource.user OR if this is a lazy-create
    of a system mood (first-time registration — see below).
    Frontmatter: all fields using snake_case keys.
    aliases: write as native Obsidian aliases array.
    body: description (or empty string).

  factory MoodDefinition.fromMarkdown(Map frontmatter, String body):
    Read all fields. source default: system. hidden default: false.
    aliases: List<String>.from(frontmatter['aliases'] ?? []).
    quadrant: MoodQuadrant.values.firstWhere(
      (q) => q.name == frontmatter['quadrant'], orElse: () => MoodQuadrant.blue).
    description: frontmatter['description'] as String? ?? body.trim().

  static Color quadrantColor(MoodQuadrant q) => switch (q) {
    MoodQuadrant.red    => const Color(0xFFEF5350),
    MoodQuadrant.yellow => const Color(0xFFFFA726),
    MoodQuadrant.green  => const Color(0xFF66BB6A),
    MoodQuadrant.blue   => const Color(0xFF42A5F5),
  };

  // The 48 system moods — hardcoded in memory, not from files
  static List<MoodDefinition> get systemMoods => [
    // RED quadrant (12)
    MoodDefinition(id:'enraged',    source:MoodSource.system, label:'Enfurecida',    labelEn:'Enraged',    emoji:'😡', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:1,  aliases:['enraged','enfurecida']),
    MoodDefinition(id:'panicked',   source:MoodSource.system, label:'Em pânico',     labelEn:'Panicked',   emoji:'😱', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:2,  aliases:['panicked','em panico','panico']),
    MoodDefinition(id:'livid',      source:MoodSource.system, label:'Furiosa',       labelEn:'Livid',      emoji:'🤬', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:3,  aliases:['livid','furiosa']),
    MoodDefinition(id:'furious',    source:MoodSource.system, label:'Raivosa',       labelEn:'Furious',    emoji:'😤', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:4,  aliases:['furious','raivosa']),
    MoodDefinition(id:'terrified',  source:MoodSource.system, label:'Aterrorizada',  labelEn:'Terrified',  emoji:'😨', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:5,  aliases:['terrified','aterrorizada']),
    MoodDefinition(id:'shocked',    source:MoodSource.system, label:'Chocada',       labelEn:'Shocked',    emoji:'😳', quadrant:MoodQuadrant.red,    pleasantness:1, energy:5, color:'#EF5350', order:6,  aliases:['shocked','chocada']),
    MoodDefinition(id:'anxious',    source:MoodSource.system, label:'Ansiosa',       labelEn:'Anxious',    emoji:'😰', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:7,  aliases:['anxious','ansiosa']),
    MoodDefinition(id:'stressed',   source:MoodSource.system, label:'Estressada',    labelEn:'Stressed',   emoji:'😖', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:8,  aliases:['stressed','estressada']),
    MoodDefinition(id:'frustrated', source:MoodSource.system, label:'Frustrada',     labelEn:'Frustrated', emoji:'😣', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:9,  aliases:['frustrated','frustrada']),
    MoodDefinition(id:'agitated',   source:MoodSource.system, label:'Agitada',       labelEn:'Agitated',   emoji:'😬', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:10, aliases:['agitated','agitada']),
    MoodDefinition(id:'irritated',  source:MoodSource.system, label:'Irritada',      labelEn:'Irritated',  emoji:'😒', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:11, aliases:['irritated','irritada']),
    MoodDefinition(id:'jittery',    source:MoodSource.system, label:'Nervosa',       labelEn:'Jittery',    emoji:'😵', quadrant:MoodQuadrant.red,    pleasantness:2, energy:4, color:'#EF5350', order:12, aliases:['jittery','nervosa']),
    // YELLOW quadrant (12)
    MoodDefinition(id:'ecstatic',   source:MoodSource.system, label:'Eufórica',      labelEn:'Ecstatic',   emoji:'🤩', quadrant:MoodQuadrant.yellow, pleasantness:5, energy:5, color:'#FFA726', order:13, aliases:['ecstatic','euforica']),
    MoodDefinition(id:'elated',     source:MoodSource.system, label:'Radiante',      labelEn:'Elated',     emoji:'😄', quadrant:MoodQuadrant.yellow, pleasantness:5, energy:5, color:'#FFA726', order:14, aliases:['elated','radiante']),
    MoodDefinition(id:'excited',    source:MoodSource.system, label:'Empolgada',     labelEn:'Excited',    emoji:'😃', quadrant:MoodQuadrant.yellow, pleasantness:5, energy:4, color:'#FFA726', order:15, aliases:['excited','empolgada']),
    MoodDefinition(id:'enthusiastic',source:MoodSource.system,label:'Entusiasmada',  labelEn:'Enthusiastic',emoji:'🙌',quadrant:MoodQuadrant.yellow, pleasantness:5, energy:4, color:'#FFA726', order:16, aliases:['enthusiastic','entusiasmada']),
    MoodDefinition(id:'energized',  source:MoodSource.system, label:'Energizada',    labelEn:'Energized',  emoji:'⚡', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:5, color:'#FFA726', order:17, aliases:['energized','energizada']),
    MoodDefinition(id:'happy',      source:MoodSource.system, label:'Feliz',         labelEn:'Happy',      emoji:'😊', quadrant:MoodQuadrant.yellow, pleasantness:5, energy:4, color:'#FFA726', order:18, aliases:['happy','feliz']),
    MoodDefinition(id:'joyful',     source:MoodSource.system, label:'Alegre',        labelEn:'Joyful',     emoji:'😁', quadrant:MoodQuadrant.yellow, pleasantness:5, energy:4, color:'#FFA726', order:19, aliases:['joyful','alegre']),
    MoodDefinition(id:'upbeat',     source:MoodSource.system, label:'Animada',       labelEn:'Upbeat',     emoji:'😀', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:4, color:'#FFA726', order:20, aliases:['upbeat','animada']),
    MoodDefinition(id:'inspired',   source:MoodSource.system, label:'Inspirada',     labelEn:'Inspired',   emoji:'✨', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:4, color:'#FFA726', order:21, aliases:['inspired','inspirada']),
    MoodDefinition(id:'motivated',  source:MoodSource.system, label:'Motivada',      labelEn:'Motivated',  emoji:'💪', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:4, color:'#FFA726', order:22, aliases:['motivated','motivada']),
    MoodDefinition(id:'optimistic', source:MoodSource.system, label:'Otimista',      labelEn:'Optimistic', emoji:'🌟', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:4, color:'#FFA726', order:23, aliases:['optimistic','otimista']),
    MoodDefinition(id:'proud',      source:MoodSource.system, label:'Orgulhosa',     labelEn:'Proud',      emoji:'🥹', quadrant:MoodQuadrant.yellow, pleasantness:4, energy:4, color:'#FFA726', order:24, aliases:['proud','orgulhosa']),
    // GREEN quadrant (12)
    MoodDefinition(id:'calm',       source:MoodSource.system, label:'Calma',         labelEn:'Calm',       emoji:'😌', quadrant:MoodQuadrant.green,  pleasantness:5, energy:2, color:'#66BB6A', order:25, aliases:['calm','calma','tranquila']),
    MoodDefinition(id:'content',    source:MoodSource.system, label:'Satisfeita',    labelEn:'Content',    emoji:'🙂', quadrant:MoodQuadrant.green,  pleasantness:5, energy:2, color:'#66BB6A', order:26, aliases:['content','satisfeita']),
    MoodDefinition(id:'peaceful',   source:MoodSource.system, label:'Em paz',        labelEn:'Peaceful',   emoji:'🕊️',quadrant:MoodQuadrant.green,  pleasantness:5, energy:1, color:'#66BB6A', order:27, aliases:['peaceful','em paz','paz']),
    MoodDefinition(id:'serene',     source:MoodSource.system, label:'Serena',        labelEn:'Serene',     emoji:'🌿', quadrant:MoodQuadrant.green,  pleasantness:5, energy:1, color:'#66BB6A', order:28, aliases:['serene','serena']),
    MoodDefinition(id:'grateful',   source:MoodSource.system, label:'Grata',         labelEn:'Grateful',   emoji:'🤍', quadrant:MoodQuadrant.green,  pleasantness:5, energy:2, color:'#66BB6A', order:29, aliases:['grateful','grata']),
    MoodDefinition(id:'relaxed',    source:MoodSource.system, label:'Relaxada',      labelEn:'Relaxed',    emoji:'😮‍💨',quadrant:MoodQuadrant.green, pleasantness:4, energy:1, color:'#66BB6A', order:30, aliases:['relaxed','relaxada']),
    MoodDefinition(id:'comfortable',source:MoodSource.system, label:'Confortável',   labelEn:'Comfortable',emoji:'🛋️',quadrant:MoodQuadrant.green,  pleasantness:4, energy:2, color:'#66BB6A', order:31, aliases:['comfortable','confortavel']),
    MoodDefinition(id:'at_ease',    source:MoodSource.system, label:'À vontade',     labelEn:'At ease',    emoji:'😴', quadrant:MoodQuadrant.green,  pleasantness:4, energy:1, color:'#66BB6A', order:32, aliases:['at_ease','a vontade','vontade']),
    MoodDefinition(id:'balanced',   source:MoodSource.system, label:'Equilibrada',   labelEn:'Balanced',   emoji:'⚖️', quadrant:MoodQuadrant.green,  pleasantness:4, energy:2, color:'#66BB6A', order:33, aliases:['balanced','equilibrada']),
    MoodDefinition(id:'loving',     source:MoodSource.system, label:'Amorosa',       labelEn:'Loving',     emoji:'🥰', quadrant:MoodQuadrant.green,  pleasantness:5, energy:2, color:'#66BB6A', order:34, aliases:['loving','amorosa']),
    MoodDefinition(id:'thoughtful', source:MoodSource.system, label:'Reflexiva',     labelEn:'Thoughtful', emoji:'🌙', quadrant:MoodQuadrant.green,  pleasantness:4, energy:2, color:'#66BB6A', order:35, aliases:['thoughtful','reflexiva']),
    MoodDefinition(id:'secure',     source:MoodSource.system, label:'Segura',        labelEn:'Secure',     emoji:'🏡', quadrant:MoodQuadrant.green,  pleasantness:4, energy:2, color:'#66BB6A', order:36, aliases:['secure','segura']),
    // BLUE quadrant (12)
    MoodDefinition(id:'sad',        source:MoodSource.system, label:'Triste',        labelEn:'Sad',        emoji:'😢', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:2, color:'#42A5F5', order:37, aliases:['sad','triste']),
    MoodDefinition(id:'depressed',  source:MoodSource.system, label:'Deprimida',     labelEn:'Depressed',  emoji:'😞', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:1, color:'#42A5F5', order:38, aliases:['depressed','deprimida']),
    MoodDefinition(id:'hopeless',   source:MoodSource.system, label:'Sem esperança', labelEn:'Hopeless',   emoji:'😔', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:1, color:'#42A5F5', order:39, aliases:['hopeless','sem esperanca']),
    MoodDefinition(id:'lonely',     source:MoodSource.system, label:'Solitária',     labelEn:'Lonely',     emoji:'🥺', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:2, color:'#42A5F5', order:40, aliases:['lonely','solitaria']),
    MoodDefinition(id:'bored',      source:MoodSource.system, label:'Entediada',     labelEn:'Bored',      emoji:'😑', quadrant:MoodQuadrant.blue,   pleasantness:2, energy:1, color:'#42A5F5', order:41, aliases:['bored','entediada']),
    MoodDefinition(id:'disconnected',source:MoodSource.system,label:'Desconectada',  labelEn:'Disconnected',emoji:'🌫️',quadrant:MoodQuadrant.blue,   pleasantness:2, energy:1, color:'#42A5F5', order:42, aliases:['disconnected','desconectada']),
    MoodDefinition(id:'exhausted',  source:MoodSource.system, label:'Exausta',       labelEn:'Exhausted',  emoji:'😩', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:1, color:'#42A5F5', order:43, aliases:['exhausted','exausta']),
    MoodDefinition(id:'discouraged',source:MoodSource.system, label:'Desanimada',    labelEn:'Discouraged',emoji:'😪', quadrant:MoodQuadrant.blue,   pleasantness:2, energy:2, color:'#42A5F5', order:44, aliases:['discouraged','desanimada']),
    MoodDefinition(id:'disappointed',source:MoodSource.system,label:'Decepcionada',  labelEn:'Disappointed',emoji:'😕',quadrant:MoodQuadrant.blue,   pleasantness:2, energy:2, color:'#42A5F5', order:45, aliases:['disappointed','decepcionada']),
    MoodDefinition(id:'numb',       source:MoodSource.system, label:'Anestesiada',   labelEn:'Numb',       emoji:'😶', quadrant:MoodQuadrant.blue,   pleasantness:2, energy:1, color:'#42A5F5', order:46, aliases:['numb','anestesiada']),
    MoodDefinition(id:'melancholic',source:MoodSource.system, label:'Melancólica',   labelEn:'Melancholic',emoji:'🌧️',quadrant:MoodQuadrant.blue,   pleasantness:2, energy:2, color:'#42A5F5', order:47, aliases:['melancholic','melancolica']),
    MoodDefinition(id:'defeated',   source:MoodSource.system, label:'Derrotada',     labelEn:'Defeated',   emoji:'😓', quadrant:MoodQuadrant.blue,   pleasantness:1, energy:2, color:'#42A5F5', order:48, aliases:['defeated','derrotada']),
  ];

CONSTRUCTOR: all fields required except aliases (default []) and description.
  Do NOT use const — emoji multi-char sequences are not const in Dart.

────────────────────────────────────────────────────────────────────────────────
TASK 9.A.9 — CREATE MoodProvider with lazy-file logic
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `MoodsNotifier.ensureMoodFileExists()` cria arquivos de
  mood sob demanda.

FILE: lib/providers/mood_provider.dart
ACTION: CREATE (replaces any existing mood provider)

STATE: MoodState
  final List<MoodDefinition> allMoods  // system + user merged
  // "all" = system moods with user overrides (hidden, aliases) applied
  //        + user-created moods
  List<MoodDefinition> get visibleMoods =>
    allMoods.where((m) => !m.hidden).toList()..sort((a,b) => a.order.compareTo(b.order));
  List<MoodDefinition> get byQuadrant(MoodQuadrant q) =>
    visibleMoods.where((m) => m.quadrant == q).toList();

NOTIFIER: MoodNotifier extends Notifier<MoodState>:

  build():
    // Load system moods as base
    final systemMoods = Map.fromEntries(
      MoodDefinition.systemMoods.map((m) => MapEntry(m.id, m)));

    // Load user overrides from vault (moods/*.md files)
    final vaultMoods = ref.read(allObjectsProvider).valueOrNull ?? [];
    for (final obj in vaultMoods.whereType<MoodDefinition>()) {
      if (obj.source == MoodSource.system && systemMoods.containsKey(obj.id)) {
        // Apply user overrides to system mood: only hidden + aliases are editable
        systemMoods[obj.id] = systemMoods[obj.id]!.copyWith(
          hidden:  obj.hidden,
          aliases: obj.aliases,
        );
      } else if (obj.source == MoodSource.user) {
        systemMoods[obj.id] = obj;  // user moods: full replacement
      }
    }
    return MoodState(allMoods: systemMoods.values.toList());

  // Resolve a wikilink slug or alias to a MoodDefinition
  MoodDefinition? resolve(String slugOrAlias):
    final lower = slugOrAlias.toLowerCase();
    return state.allMoods.firstWhere(
      (m) => m.id == lower ||
             m.aliases.map((a) => a.toLowerCase()).contains(lower),
      orElse: () => null,
    );

  // Called when a mood is logged for the first time (lazy file creation)
  Future<void> ensureMoodFileExists(String moodId):
    final mood = state.allMoods.firstWhere((m) => m.id == moodId,
      orElse: () => null);
    if (mood == null) return;
    // Check if file already exists in vault
    final obsidian = ref.read(obsidianServiceProvider);
    final path = 'moods/${mood.id}.md';
    if (await obsidian.fileExists(path)) return;
    // Create the file lazily
    await obsidian.writeFile(path, mood.toMarkdown());

  // Toggle hidden for any mood (system: only hidden editable; user: full edit)
  Future<void> setHidden(String moodId, bool hidden):
    final idx = state.allMoods.indexWhere((m) => m.id == moodId);
    if (idx < 0) return;
    final updated = state.allMoods[idx].copyWith(hidden: hidden);
    state = state.copyWith(allMoods: [...state.allMoods]..[idx] = updated);
    if (updated.source == MoodSource.system):
      await ensureMoodFileExists(moodId);
    // Write updated hidden field to file
    final obsidian = ref.read(obsidianServiceProvider);
    await obsidian.writeFile('moods/${moodId}.md', updated.toMarkdown());

  Future<void> saveUserMood(MoodDefinition mood):
    // mood.source must be MoodSource.user
    final existing = state.allMoods.indexWhere((m) => m.id == mood.id);
    List<MoodDefinition> updated = [...state.allMoods];
    if (existing >= 0) updated[existing] = mood;
    else updated.add(mood);
    state = state.copyWith(allMoods: updated);
    final obsidian = ref.read(obsidianServiceProvider);
    await obsidian.writeFile('moods/${mood.id}.md', mood.toMarkdown());

PROVIDER:
  final moodProvider = NotifierProvider<MoodNotifier, MoodState>(MoodNotifier.new);

────────────────────────────────────────────────────────────────────────────────
SPRINT 9-B  ·  P1 FIXES — high impact, implement after Sprint A
────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.1 — ADD TaskStage.backlog to enum + modal on save without date
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `TaskStage.backlog` existe e `CreateTaskForm` direciona
  tasks sem data para Backlog ou Hoje.

FILE: lib/models/task_model.dart
ACTION: EDIT

ANCHOR: enum TaskStage { idea, todo, inProgress, pending, finalized }
ADD backlog after idea:
  enum TaskStage { idea, backlog, todo, inProgress, pending, finalized }

SERIALIZATION: TaskStage.backlog.name == 'backlog' — no special handling needed.

FILE: lib/ui/forms/create_task_form.dart
ACTION: EDIT

ANCHOR: the save/submit method (search for 'tasksProvider.notifier' or
  'ref.read(tasksProvider').

ADD before saving: check if end_date (dueDate / endDate) is null.
  If null: show modal dialog:
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Sem data definida'),
        content: const Text('Onde você quer colocar esta task?'),
        actions: [
          TextButton(
            child: const Text('Backlog'),
            onPressed: () {
              Navigator.pop(context);
              _stage = TaskStage.backlog;
              _saveTask();
            }),
          TextButton(
            child: const Text('Hoje'),
            onPressed: () {
              Navigator.pop(context);
              _endDate = DateTime.now();
              _stage = TaskStage.todo;
              _saveTask();
            }),
        ],
      ));
  If endDate is set: call _saveTask() directly without modal.

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.2 — ADD linked_system field to Task model
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Task.linkedSystem` existe, persiste em `linked_system`,
  lê do frontmatter e entra no `copyWith()`.

FILE: lib/models/task_model.dart
ACTION: EDIT

ADD field: String? linkedSystem;  // slug of System that generated this task

EDIT toMarkdown():
  ADD: frontmatter['linked_system'] = linkedSystem; // null is fine — writes null

EDIT fromMarkdown():
  ADD: task.linkedSystem = _stringValue(frontmatter['linked_system']);

EDIT copyWith(): add String? linkedSystem parameter.

USAGE: in SystemsProvider when running a system (creating a task from system),
  set linkedSystem = system.slug on the created Task.

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.3 — ADD TimeBlock.energyLevel field
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `TimeBlock.energyLevel` existe, serializa em
  `energy_level`, lê do mapa e a timeline aplica tint visual.

FILE: lib/models/day_theme_model.dart
ACTION: EDIT

ADD enum (top of file):
  enum EnergyLevel { high, medium, low }

ANCHOR: class TimeBlock { ... }
ADD field: EnergyLevel? energyLevel;  // null = not set

EDIT TimeBlock constructor: add EnergyLevel? energyLevel parameter.

EDIT TimeBlock.toMap():
  ADD: if (energyLevel != null) map['energy_level'] = energyLevel!.name;

EDIT TimeBlock.fromMap():
  ADD: energyLevel: EnergyLevel.values.cast<EnergyLevel?>().firstWhere(
    (e) => e?.name == (map['energy_level'] as String?),
    orElse: () => null);

Energy Map tints (for Planner rendering — add to lib/ui/screens/planner_screen.dart):
  ANCHOR: find where TimeBlock background color is computed in the planner.
  ADD: if timeBlock.energyLevel != null, overlay the block background with:
    high   → Color(0xFF4CAF50).withValues(alpha: 0.08)
    medium → Color(0xFFFFC107).withValues(alpha: 0.08)
    low    → Color(0xFFFF7043).withValues(alpha: 0.08)
  This is ADDITIVE — apply on top of the block's normal background color.

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.4 — FIX Habit completions storage: write to daily note, not habit body
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — completions são gravadas/lidas em chaves planas da daily
  note, com migrações para formatos antigos.

NOTE: This is a significant architecture change. Implement carefully.

CURRENT BEHAVIOR: Habit.toMarkdown() writes `## History` with checkbox lines
  into the habit file itself.

TARGET BEHAVIOR (spec): completions stored in daily note frontmatter as:
  meditar: true
  agua: 6
  (key = habit slug, value = boolean or count)

STEP 1 — STOP writing completions in habit file:
  FILE: lib/models/habit_model.dart
  ANCHOR: toMarkdown() — find where ## History or completion_history is written.
  REMOVE the ## History section from the body output.
  REMOVE completion_history from frontmatter (if present).
  ADD comment: // Completions stored in daily note frontmatter per spec.

STEP 2 — WRITE completions to daily note:
  FILE: lib/providers/vault_provider.dart (or wherever completeHabit() lives)
  ANCHOR: the method that records a completion (completeHabit / logCompletion).

  AFTER the existing completion logic, ADD:
    // Write completion to daily note frontmatter
    await _writeToDailyNote(date, habit.slug, value);

  ADD method _writeToDailyNote(DateTime date, String habitSlug, dynamic value):
    // Build path: 'daily/YYYY-MM-DD.md'
    final path = 'daily/${date.year.toString().padLeft(4,'0')}'
                 '-${date.month.toString().padLeft(2,'0')}'
                 '-${date.day.toString().padLeft(2,'0')}.md';
    final obsidian = ref.read(obsidianServiceProvider);
    Map<String,dynamic> frontmatter = {};
    String body = '';
    if (await obsidian.fileExists(path)):
      final content = await obsidian.readFile(path);
      final parsed  = parseFrontmatter(content);  // use existing parser
      frontmatter   = parsed.frontmatter;
      body          = parsed.body;
    else:
      // Create new daily note with canonical frontmatter
      frontmatter = {
        'date': '${date.year}-${date.month.toString().padLeft(2,'0')}'
                '-${date.day.toString().padLeft(2,'0')}',
        'type': 'daily_note',
        'tags': ['daily'],
      };
    // Set habit value
    frontmatter[habitSlug] = value; // true for boolean, int for count
    await obsidian.writeFile(path, generateMarkdown(frontmatter, body));

STEP 3 — READ completions from daily note:
  FILE: lib/services/obsidian_service.dart (or vault_provider.dart)
  ANCHOR: the startup parsing algorithm. Find where daily notes are loaded.

  In the daily note parsing loop, AFTER extracting date:
    // Extract habit completions: any frontmatter key that matches a known habit slug
    final habitSlugs = ref.read(habitsProvider).map((h) => h.slug).toSet();
    for (final key in frontmatter.keys) {
      if (habitSlugs.contains(key)) {
        final value = frontmatter[key];
        // Register as HabitCompletion in memory
        _registerCompletion(habitSlug: key, date: date, value: value);
      }
    }

  ADD _registerCompletion(): updates the in-memory CompletionRecord list for
    the corresponding Habit. Does NOT write to any file — read-only here.

STEP 4 — MIGRATION: convert existing ## History entries to daily note format:
  FILE: lib/services/obsidian_service.dart
  ADD method migrateHabitCompletionsToDailyNotes():
    For each habit file that has a ## History section:
      Parse the checkbox lines: - [x] YYYY-MM-DD or - [ ] YYYY-MM-DD
      For each [x] line: call _writeToDailyNote(date, habit.slug, true)
      Remove ## History section from the habit file body
      Rewrite the habit file
    Call this once at startup (after vault load), gated by a
    SharedPreferences key 'habit_completion_migration_done'.
    Set the key to true after completion so it runs only once.

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.5 — FIX Organizer types: add task/goal/habit/tracker
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `OrganizerType` inclui task/goal/habit/tracker e
  Organizer persiste state/priority com leitura retrocompatível.

FILE: lib/models/organizer_model.dart
ACTION: EDIT

ANCHOR: enum OrganizerType { area, project, activity, label, person, place }

REPLACE with:
  enum OrganizerType {
    area, project, activity,
    task, goal, habit, tracker,
    label, person, place
  }

SERIALIZATION: enum.name values match the spec lowercase strings exactly.
  No special mapping needed.

ALSO ADD fields to Organizer class for project-type organizers:
  String? state;      // active | paused | completed (for project type)
  String? priority;   // none | low | medium | high (for project type)

EDIT toMarkdown(): include state and priority if not null.
EDIT fromMarkdown(): read state and priority.
EDIT copyWith(): add state and priority.

EDIT Organizer.type getter:
  ANCHOR: @override String get type => 'organizer';
  CHANGE to: @override String get type => organizerType.name;
  // This makes type: area, type: project, etc. in frontmatter.

IMPORTANT: update fromMarkdown() in organizer to handle both old format
  (type: organizer + organizer_type: area) and new format (type: area):
    final typeStr = frontmatter['type']?.toString() ?? '';
    final subtypeStr = frontmatter['organizer_type']?.toString() ?? typeStr;
    org.organizerType = OrganizerType.values.firstWhere(
      (t) => t.name == subtypeStr, orElse: () => OrganizerType.label);

────────────────────────────────────────────────────────────────────────────────
TASK 9.B.6 — RESTRUCTURE FAB create_menu_sheet.dart — 4-tab spec layout
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `CreateMenuSheet` usa abas Journal/Plan/Record/Note com
  os itens da spec, incluindo Calendar Session, Backlog e System.

FILE: lib/ui/widgets/create_menu_sheet.dart
ACTION: EDIT — restructure tabs

CURRENT: 2 tabs (Capture + Criar) with mixed items.
TARGET: 4 tabs per spec: Journal | Plan | Record | Note

Tab structure (spec-exact):
  TAB 1 — Journal:
    Entry (ícone: edit_note)
    Field Note (ícone: bolt)
    PMN — Revisão Semanal (ícone: calendar_view_week)

  TAB 2 — Plan:
    Task (ícone: check_circle_outline)
    Goal (ícone: flag_outlined)
    Session — Calendar Session (ícone: event_outlined)
    Reminder (ícone: alarm)
    Backlog — creates Task with stage=backlog (ícone: inbox_outlined)

  TAB 3 — Record:
    Tracking Record (ícone: bar_chart)

  TAB 4 — Note:
    Text Note (ícone: description_outlined)
    Outline Note (ícone: format_list_bulleted)
    Collection Note (ícone: table_chart_outlined)
    System (ícone: settings_outlined)

IMPLEMENTATION: rewrite the TabBar + TabBarView inside the modal bottom sheet.
  Keep the existing navigation logic (how each item opens its form) — only
  change the tab structure and item grouping.

  Items that already have forms: link to existing form widgets.
  Items that are new (CalendarSession): link to CreateCalendarSessionForm
    (create this form in TASK 9.C.2).

NOTE: items from the old "Capture" tab that are NOT in the spec tabs
  (Foto/scan, Post social, PMN was in old Capture) should be moved to the
  appropriate new tab or removed if not spec-conformant.
  Social Post is NOT in the spec FAB — remove from FAB, keep accessible
  from Social screen only.

────────────────────────────────────────────────────────────────────────────────
SPRINT 9-C  ·  P2 FIXES + NEW FORMS
────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.1 — FIX daily note template to match canonical format
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `getDailyNoteTemplate()` gera frontmatter canônico,
`tags: [daily]`, campos `mood_*`, hábitos planos e seções da daily note.

FILE: lib/providers/vault_provider.dart (or obsidian_service.dart)
ACTION: EDIT

ANCHOR: method getDailyNoteTemplate() or equivalent that generates the initial
  content for a new daily/YYYY-MM-DD.md file.

REPLACE the template output with exactly:
  String getDailyNoteTemplate(DateTime date, List<Habit> activeHabits):
    final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}'
                    '-${date.day.toString().padLeft(2,'0')}';
    final habitKeys = activeHabits.map((h) => '${h.slug}: false').join('\n');
    return '''---
date: $dateStr
type: daily_note
tags: [daily]

$habitKeys

mood_pleasantness:
mood_energy:
mood_label:
mood_emoji:
---

# $dateStr

## Journal Entries

## Habits

${activeHabits.map((h) => '- [ ] ${h.title}').join('\n')}

## Trackers

## Pomodoros
''';

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.2 — CREATE lib/ui/forms/create_calendar_session_form.dart
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `CreateCalendarSessionForm` existe e salva sessões via
provider.

FILE: lib/ui/forms/create_calendar_session_form.dart
ACTION: CREATE

Mirrors the structure of create_task_form.dart but for CalendarSession.

FIELDS IN FORM:
  title (required TextField)
  date (DatePicker, default today)
  timeOfDay (TimePicker, optional)
  duration (int field, default 60, unit: minutos)
  state (segmented: scheduled | backlog | in_progress | completed | cancelled)
  linkedTask (UniversalSearchPicker filtering for Task objects)
  linkedGoal (UniversalSearchPicker filtering for Goal objects)
  note (multiline TextField, optional)
  color (AppColorPicker widget)
  organizers (OrganizerSelectorField)
  multiDay (toggle)

SAVE logic:
  Creates CalendarSession from form fields.
  Calls ref.read(calendarSessionsProvider.notifier).add(session).
  Navigator.pop(context).

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.3 — CREATE lib/ui/widgets/mood_picker.dart — 2-step quadrant picker
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `MoodPicker` existe com escolha por quadrante e mood.

FILE: lib/ui/widgets/mood_picker.dart
ACTION: CREATE

PURPOSE: 2-step mood picker. Step 1: quadrant selection. Step 2: specific mood.
  Used in journal entry form and daily check-in.

WIDGET: MoodPicker extends ConsumerStatefulWidget
  CONSTRUCTOR params:
    MoodDefinition? initialMood
    void Function(MoodDefinition) onSelected

  STATE:
    int _step = 1;   // 1 = quadrant, 2 = specific mood
    MoodQuadrant? _selectedQuadrant;

  build(context):
    final moodState = ref.watch(moodProvider);
    if (_step == 1): return _buildQuadrantStep(context, moodState);
    else:            return _buildMoodStep(context, moodState);

  _buildQuadrantStep(context, moodState):
    // 2×2 grid of quadrant buttons
    Column children:
      Text('Como você está?', style: sectionHeader)
      SizedBox(height:16)
      GridView 2×2:
        for each MoodQuadrant in [red, yellow, green, blue]:
          _QuadrantCard(
            quadrant: q,
            color: MoodDefinition.quadrantColor(q),
            label: _quadrantLabel(q),   // 'Alta energia / Desagradável' etc.
            moodCount: moodState.byQuadrant(q).length,
            onTap: () => setState(() {
              _selectedQuadrant = q;
              _step = 2;
            }),
          )

  _buildMoodStep(context, moodState):
    final moods = moodState.byQuadrant(_selectedQuadrant!);
    Column:
      Row [BackButton → step=1] + Text(quadrant label)
      Expanded ListView of _MoodRow:
        for each mood in moods:
          ListTile(
            leading: Text(mood.emoji, style: TextStyle(fontSize:28)),
            title: Text(mood.label),
            subtitle: mood.description != null
                ? Text(mood.description!, maxLines:2, style: muted) : null,
            selected: initialMood?.id == mood.id,
            onTap: () {
              ref.read(moodProvider.notifier).ensureMoodFileExists(mood.id);
              widget.onSelected(mood);
            },
          )

QUADRANT LABELS (use in _quadrantLabel()):
  red    → 'Alta energia · Desagradável'
  yellow → 'Alta energia · Agradável'
  green  → 'Baixa energia · Agradável'
  blue   → 'Baixa energia · Desagradável'

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.4 — FIX Scheduler enum serialization (camelCase → snake_case)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `RepeatTypeX.specName/fromSpecName` grava snake_case e lê
camelCase legado.

FILE: lib/models/scheduler.dart
ACTION: EDIT

PROBLEM: enum SchedulerRuleType values like linkedItemAppears and
  nDaysAfterLinkedItem serialize as camelCase via .name. Spec expects
  snake_case: linked_item_appears, n_days_after_linked_item.

ANCHOR: enum SchedulerRuleType { ... linkedItemAppears, nDaysAfterLinkedItem ... }

ADD extension on SchedulerRuleType:
  extension SchedulerRuleTypeX on SchedulerRuleType {
    String get specName => switch (this) {
      SchedulerRuleType.numberOfDays          => 'number_of_days',
      SchedulerRuleType.daysOfWeek            => 'days_of_week',
      SchedulerRuleType.numberOfWeeks         => 'number_of_weeks',
      SchedulerRuleType.numberOfMonths        => 'number_of_months',
      SchedulerRuleType.numberOfHours         => 'number_of_hours',
      SchedulerRuleType.daysAfterLastStart    => 'days_after_last_start',
      SchedulerRuleType.daysAfterLastEnd      => 'days_after_last_end',
      SchedulerRuleType.daysPerPeriod         => 'days_per_period',
      SchedulerRuleType.linkedItemAppears     => 'linked_item_appears',
      SchedulerRuleType.nDaysAfterLinkedItem  => 'n_days_after_linked_item',
      SchedulerRuleType.firstBusinessDayOfMonth => 'first_business_day_of_month',
      _ => name, // passthrough for any non-spec extras
    };

    static SchedulerRuleType fromSpecName(String s) =>
      SchedulerRuleType.values.firstWhere(
        (t) => t.specName == s || t.name == s,
        orElse: () => SchedulerRuleType.numberOfDays);
  }

EDIT Scheduler.toMap() (or toJson()):
  REPLACE: 'rule_type': ruleType.name
  WITH:    'rule_type': ruleType.specName

EDIT Scheduler.fromMap():
  REPLACE: SchedulerRuleType.values.firstWhere((t) => t.name == map['rule_type'])
  WITH:    SchedulerRuleTypeX.fromSpecName(map['rule_type']?.toString() ?? '')

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.5 — FIX TripleCheck.blocker serialization
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `TripleCheck.primaryBlocker` grava um blocker primário
único.

FILE: lib/models/task_model.dart  (or wherever TripleCheck is defined)
ACTION: EDIT

PROBLEM: 'blocker': blockers.join(',') produces "head,heart" (multi-value).
  Spec defines blocker as a single string: the PRIMARY blocker.

ANCHOR: find class TripleCheck or the triple_check map building in Task.toMarkdown().
  Find the line: 'blocker': blockers.join(',')  (or similar multi-value join)

REPLACE with: 'blocker': _primaryBlocker(),

ADD method _primaryBlocker():
  // Returns the first false check as the primary blocker, or null if all pass
  if (!head)  return 'head';
  if (!heart) return 'heart';
  if (!hand)  return 'hand';
  return null;

EDIT fromMarkdown(): blocker field is a single string — no change needed to
  reading, but ensure it's read as String? not List.

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.6 — FIX PMN id format
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — PMNs sem id recebem `pmn-YYYY-WNN` por semana ISO.

FILE: lib/models/journal_entry.dart  (or wherever PMN is created)
ACTION: EDIT

ANCHOR: find where id is generated for PMN entries. It currently uses UUID.

For PMN type only (entry_type == pmn), set id to:
  'pmn-${dateRangeStart.year}-W${weekNumber.toString().padLeft(2,'0')}'

Where weekNumber is the ISO week number of dateRangeStart.
Add helper:
  static int _isoWeekNumber(DateTime date):
    // ISO 8601 week: Mon-Sun, first week has Jan 4
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final weekday   = date.weekday; // 1=Mon, 7=Sun
    return ((dayOfYear - weekday + 10) / 7).floor();

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.7 — ADD missing fields: Note.links, JournalEntry.feelings
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — links ficam centralizados em `ContentObject.links`; 
`JournalEntry.feelings` existe no model/form.


FILE: lib/models/note_model.dart
ACTION: EDIT
ADD field: List<String> links;  // WikiLink strings e.g. '[[some-note]]'
EDIT constructor: List<String>? links, → : links = links ?? [],
EDIT toMarkdown(): if (links.isNotEmpty) frontmatter['links'] = links;
EDIT fromMarkdown(): note.links = List<String>.from(frontmatter['links'] as List? ?? []);
EDIT copyWith(): add List<String>? links parameter.

FILE: lib/models/journal_entry.dart
ACTION: EDIT
ADD field: String? feelings;
EDIT toMarkdown(): if (feelings != null) frontmatter['feelings'] = feelings;
EDIT fromMarkdown(): entry.feelings = frontmatter['feelings'] as String?;
EDIT copyWith(): add String? feelings parameter.
ADD to create_entry_form.dart: optional TextField for 'feelings' below the
  mood picker, label 'Sentimentos (opcional)', placeholder 'Ex: leveza, tensão no peito'.

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.8 — FIX NoteSubtype: remove 'routine' (not in spec)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `NoteSubtype` contém `text/outline/collection` e fallback
de parsing cai para `text`.

FILE: lib/models/note_model.dart
ACTION: EDIT

ANCHOR: enum NoteSubtype { text, outline, collection, routine }

REMOVE 'routine' from the enum:
  enum NoteSubtype { text, outline, collection }

MIGRATION: in obsidian_service.dart startup scan, if a note file has
  note_subtype: routine in frontmatter → treat as NoteSubtype.text (graceful
  fallback, do NOT rewrite the file automatically — user may have custom data).

SEARCH all files for NoteSubtype.routine references and replace with
  NoteSubtype.text (with a TODO comment explaining the decision).

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.9 — ADD Reminder.checkboxes, time_block, habit_reminder fields
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `Reminder` tem checkboxes, timeBlock e habitReminder, com
compatibilidade `time_block_id`.

FILE: lib/models/reminder_model.dart
ACTION: EDIT

ADD fields:
  List<String> checkboxes;    // list of checkbox item titles
  String? timeBlock;          // slug of linked TimeBlock (spec: 'time_block')
  bool habitReminder;         // true if this reminder belongs to a habit

EDIT constructor: add parameters with defaults:
  List<String>? checkboxes,
  this.timeBlock,
  this.habitReminder = false,
  → : checkboxes = checkboxes ?? [],

EDIT toMarkdown():
  if (checkboxes.isNotEmpty) frontmatter['checkboxes'] = checkboxes;
  if (timeBlock != null) frontmatter['time_block'] = timeBlock;
  frontmatter['habit_reminder'] = habitReminder;

EDIT fromMarkdown():
  reminder.checkboxes = List<String>.from(frontmatter['checkboxes'] as List? ?? []);
  reminder.timeBlock  = frontmatter['time_block'] as String?;
  reminder.habitReminder = frontmatter['habit_reminder'] as bool? ?? false;

RENAME existing timeBlockId field to timeBlock for spec conformance.
  Update all call sites. (Global search: timeBlockId → timeBlock)

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.10 — FIX folderPaths in vault loader (Object Identification)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — loader prioriza `settings.folderPaths` e deduplica antes
do scan geral; escrita também respeita folderPaths.

FILE: lib/services/obsidian_service.dart  (or vault_provider.dart)
ACTION: EDIT

PROBLEM: AppSettings.folderPaths (Map<String,String>) is defined but never
  consulted by the vault loader. Spec Rule 12: Object Identification is
  sovereign — user-configured folder takes priority over defaults.

ANCHOR: find the startup scan loop where files are discovered (likely a
  recursive directory walk starting from vaultPath).

CHANGE the file discovery logic:
  // Build effective folder map from settings
  final folderPaths = ref.read(settingsProvider).folderPaths;
  // folderPaths keys: object type strings ('task','habit','goal',etc.)
  // folderPaths values: subfolder paths relative to vaultPath

  // For each object type, if folderPaths has an entry, scan THAT folder first
  // Objects found in the designated folder are authoritative for that type.
  // The default app/ folder scan still runs for types not in folderPaths.

  // Implementation:
  final Set<String> scannedPaths = {};
  for (final entry in folderPaths.entries) {
    final typeKey  = entry.key;   // e.g. 'task'
    final folderPath = path.join(vaultPath, entry.value);
    if (await Directory(folderPath).exists()) {
      await _scanFolder(folderPath, expectedType: typeKey, scannedPaths: scannedPaths);
    }
  }
  // Scan default app/ for remaining objects (not in scannedPaths already)
  await _scanFolder(path.join(vaultPath, 'app'), scannedPaths: scannedPaths);

ADD _scanFolder(String folder, {String? expectedType, required Set<String> scannedPaths}):
  Lists all .md files in folder recursively.
  For each file not already in scannedPaths:
    Add to scannedPaths.
    Parse frontmatter.
    Dispatch to appropriate ContentObject factory.
    If expectedType != null and parsed type != expectedType: log warning
      to CrashReportService (not an error — Obsidian files can move).

────────────────────────────────────────────────────────────────────────────────
TASK 9.C.11 — ADD mood daily note fields write on mood registration
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — add/update `JournalEntry` com mood garante arquivo mood e
grava quatro campos no frontmatter daily.

FILE: lib/providers/vault_provider.dart  (or mood_provider.dart)
ACTION: EDIT

When user selects a mood (via MoodPicker, TASK 9.C.3), call:
  Future<void> registerMood(DateTime date, MoodDefinition mood):
    // 1. Lazy-create mood file if system mood and first use
    await ref.read(moodProvider.notifier).ensureMoodFileExists(mood.id);

    // 2. Write 4 mood fields to daily note frontmatter
    final path = _dailyNotePath(date);
    await _updateDailyNoteFrontmatter(path, {
      'mood_pleasantness': mood.pleasantness,
      'mood_energy':       mood.energy,
      'mood_label':        mood.label,
      'mood_emoji':        mood.emoji,
    });

    // 3. Write mood:: [[slug]] inline in the journal entry body
    //    (this is handled by JournalEntry.toMarkdown(), not here)

ADD _updateDailyNoteFrontmatter(String path, Map<String,dynamic> fields):
  Reads existing daily note (or creates new one via getDailyNoteTemplate).
  Merges fields into frontmatter.
  Rewrites file.

================================================================================
PHASE 9 — IMPLEMENTATION ORDER
================================================================================

Run in this exact order (each sprint depends on the previous):

SPRINT 9-A (P0 — data integrity):
  9.A.1  Fix entry_type serialization (leading underscore bug)
  9.A.2  Fix JournalEntry.date + time merge
  9.A.3  Fix System: remove run_count/last_run/average_minutes from toMarkdown()
  9.A.4  Fix JournalEntry.type: 'journal_entry' → 'entry'
  9.A.5  Add GoalMode enum + goal_mode to Goal model
  9.A.6  Create CalendarSession model
  9.A.7  Register CalendarSession in vault loader + provider
  9.A.8  Rewrite MoodDefinition model (2-axis, 48 system moods)
  9.A.9  Create MoodProvider with lazy file creation

SPRINT 9-B (P1 — missing features):
  9.B.1  Add TaskStage.backlog + save-without-date modal
  9.B.2  Add linked_system to Task
  9.B.3  Add TimeBlock.energyLevel + planner energy tints
  9.B.4  Fix habit completions → daily note (3-step: stop, write, migrate)  9.B.5  Fix OrganizerType enum + Organizer.type getter
  9.B.6  Restructure FAB to 4-tab spec layout

SPRINT 9-C (P2 — conformance details):
  9.C.1  Fix daily note template (canonical format with tags + mood fields)
  9.C.2  Create CreateCalendarSessionForm
  9.C.3  Create MoodPicker widget (2-step)
  9.C.4  Fix Scheduler enum serialization (camelCase → snake_case)
  9.C.5  Fix TripleCheck.blocker (single value)
  9.C.6  Fix PMN id format (pmn-YYYY-WNN)
  9.C.7  Add Note.links, JournalEntry.feelings
  9.C.8  Remove NoteSubtype.routine
  9.C.9  Add Reminder.checkboxes, time_block, habit_reminder
  9.C.10 Fix folderPaths in vault loader (Object Identification)
  9.C.11 Add mood daily note fields on registration

VERIFICATION CHECKLIST — Phase 9:
  □ flutter analyze → 0 errors
  □ field_note entry saved → frontmatter has entry_type: field_note (no leading _)
  □ entry type field → frontmatter has type: entry (not journal_entry)
  □ JournalEntry created at 08:30 → baseTime has hour=8, minute=30
  □ System with 3 completed runs → run_count NOT in .md file; derived at runtime = 3
  □ Goal fromMarkdown with no goal_mode → goalMode == GoalMode.standard (Regra 5)
  □ CalendarSession.toMarkdown() → type: calendar_session in output
  □ MoodDefinition.systemMoods.length == 48
  □ moodProvider.resolve('calma') returns MoodDefinition with id='calm'
  □ Task saved without end_date → modal appears → tap Backlog → stage=backlog
  □ Task.toMarkdown() includes linked_system field (null or slug)
  □ TimeBlock with energy_level: high → planner shows #4CAF50 8% tint
  □ Habit checked → daily note frontmatter has habit-slug: true
  □ obsidian_service startup: habit-slug key in daily note → registers completion
  □ OrganizerType.habit serializes as 'habit' in frontmatter type field
  □ FAB shows 4 tabs: Journal / Plan / Record / Note
  □ New daily note has tags: [daily] + mood_* fields in frontmatter
  □ Scheduler with linked_item_appears rule → toMap() output has 'linked_item_appears' (not camelCase)
  □ TripleCheck with head:false → blocker: 'head' (not 'head,heart,hand')
  □ PMN entry id → 'pmn-2026-W21' format
  □ Note.toMarkdown() includes links array when not empty
  □ NoteSubtype.routine → compile error (removed from enum)
  □ Reminder with checkboxes → frontmatter has checkboxes: [...]
  □ folderPaths = {task: 'tarefas/'} → vault loader scans 'tarefas/' for tasks first

================================================================================
END OF PHASE 9
================================================================================


================================================================================
PHASE 10 — SOCIAL POST PHOTO/THUMBNAIL FIX
(Instagram, TikTok photo posts, Reddit, LinkedIn not showing images)
================================================================================

DIAGNOSIS — ROOT CAUSE CONFIRMED FROM CODE
────────────────────────────────────────────────────────────────────────────────
Read: lib/services/oembed_service.dart + lib/ui/widgets/social_embed_view.dart
      + lib/ui/widgets/social_post_grid_card.dart

ROOT CAUSE 1 — Instagram, LinkedIn, Twitter, "other" all go through a single
  generic _fetchOpenGraph(url) call with NO platform-specific handling and
  (based on the visible portion of the file) likely no custom User-Agent or
  Accept-Language headers. Instagram and LinkedIn both serve a bot-walled,
  near-empty HTML shell to any request that doesn't look like a real mobile
  browser session — no og:image, no og:description in the response.
  RESULT: thumbnailUrl stays null for Instagram photo posts → SocialPostImage
  falls back to the platform icon placeholder instead of the actual photo.

ROOT CAUSE 2 — Instagram Reels (video) DO show a thumbnail because Instagram's
  og:image for /reel/ URLs is more reliably served even to bots (video poster
  frame metadata is treated differently by Instagram's anti-scraping layer
  than carousel/photo og:image). This explains the exact symptom described:
  "só video aparece, quando é foto não aparece."

ROOT CAUSE 3 — TikTok photo posts (/photo/ URL pattern, mediaType=carousel)
  are NOT handled by buildEmbedUrl() — the switch case for tiktok only
  extracts an id via RegExp(r'/video/(\d+)'), which does not match TikTok's
  /photo/ID URL pattern. embedUrl stays null. The oEmbed fallback
  (tiktok.com/oembed) DOES typically return thumbnail_url even for photo
  posts, so the thumbnail itself might partially work, but the embed view
  has no playback target and SocialEmbedView's TikTok video logic
  (_startTikTokPlayback) assumes mediaType==video — for carousel it falls
  through to "_hasError = true" per the visible initState logic
  ("if widget.post.platform == tiktok { _hasError = true; }" runs when
  mediaType is NOT video, i.e. for photo/carousel posts). So TikTok photo
  posts get NO thumbnail-driven detail view at all, just an error fallback.

ROOT CAUSE 4 — Reddit is not handled ANYWHERE in OEmbedService.
  detectPlatform() has no check for 'reddit.com'. Any reddit.com URL falls
  through to SocialPlatform.other, which still routes to _fetchOpenGraph —
  but reddit.com URLs were never mentioned in the user's request as currently
  "supported," they likely fail isSupportedUrl() entirely depending on how
  detectPlatform default works, OR they get treated as "other" with a generic
  globe icon and no platform-specific image/oEmbed strategy. Reddit has an
  official oEmbed endpoint (https://www.reddit.com/oembed) that returns
  thumbnail_url reliably for image posts — currently unused.

ROOT CAUSE 5 — generic _fetchOpenGraph has no JSON-LD fallback and (most
  likely) no realistic browser User-Agent header, which is required by
  Instagram, LinkedIn, and Reddit's anti-bot layer to serve real meta tags.

SUMMARY TABLE:
  Platform   | Photo posts work? | Why not
  Instagram  | NO                | _fetchOpenGraph blocked by IG bot-wall (no UA)
  TikTok     | Video: yes        | Photo: buildEmbedUrl() doesn't match /photo/ID,
             | Photo: NO         |  SocialEmbedView treats non-video as error
  Reddit     | NO                | Not detected as a platform at all
  LinkedIn   | NO                | _fetchOpenGraph blocked by LinkedIn bot-wall

────────────────────────────────────────────────────────────────────────────────
TASK 10.1 — EDIT oembed_service.dart — add User-Agent + headers to OpenGraph fetch
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `_fetchOpenGraph()` usa headers de navegador mobile,
timeout maior e fallback JSON-LD para imagem.

FILE: lib/services/oembed_service.dart
ACTION: EDIT

ANCHOR: find the private method _fetchOpenGraph(String url) (referenced
  throughout fetchMetadata but body not shown in the read portion — locate it
  by searching for 'Future<Map' and 'OpenGraph' in the file).

REPLACE the http.get call inside _fetchOpenGraph with:
  final resp = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
          'Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    },
  ).timeout(const Duration(seconds: 12));

REASON: Instagram, LinkedIn, and Reddit specifically serve full server-rendered
  meta tags (including og:image) to requests carrying a recognized mobile
  Safari/Chrome User-Agent. Requests without a UA header (Dart's http package
  default is "Dart/x.x (dart:io)") are routed to the bot-wall, which returns
  a near-empty shell page.

ALSO EDIT the og: tag parser inside _fetchOpenGraph (or wherever the regex
  extraction happens) — ADD a JSON-LD fallback for Instagram/LinkedIn since
  both platforms duplicate image data in inline JSON (window._sharedData for
  Instagram, or LD+JSON for LinkedIn articles):

  ADD helper method _extractJsonLdImage(String html):
    final ldMatch = RegExp(
      r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
      caseSensitive: false, dotAll: true,
    ).firstMatch(html);
    if (ldMatch == null) return null;
    try {
      final data = jsonDecode(ldMatch.group(1)!.trim());
      final image = data is Map ? data['image'] : null;
      if (image is String) return image;
      if (image is List && image.isNotEmpty) return image.first.toString();
      if (image is Map && image['url'] != null) return image['url'].toString();
    } catch (_) {}
    return null;

  In _fetchOpenGraph, after extracting og:image, if it's null/empty:
    final fallbackImage = _extractJsonLdImage(resp.body);
    if (fallbackImage != null) result['image'] = fallbackImage;

────────────────────────────────────────────────────────────────────────────────
TASK 10.2 — EDIT oembed_service.dart — add Instagram-specific multi-strategy fetch
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `fetchMetadata()` usa `_fetchInstagram()` com página embed
e fallback OpenGraph.

FILE: lib/services/oembed_service.dart
ACTION: EDIT

ANCHOR: inside fetchMetadata(), the switch statement that routes
  SocialPlatform.instagram to _fetchOpenGraph(normalizedUrl).

REPLACE the instagram case to use a dedicated method:
  SocialPlatform.instagram => _fetchInstagram(normalizedUrl),

ADD new method _fetchInstagram(String url):
  Future<Map<String,dynamic>?> _fetchInstagram(String url) async {
    // Strategy 1: Instagram's own oEmbed-like endpoint (no API key needed
    // for basic public post embed data — uses the public embed page).
    // Normalize URL: ensure trailing slash, strip query params first.
    final uri = Uri.parse(url);
    final cleanPath = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final embedPageUrl = 'https://www.instagram.com${cleanPath}embed/captioned/';

    try {
      final resp = await http.get(
        Uri.parse(embedPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
              'Mobile/15E148 Safari/604.1',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final html = resp.body;
        // Instagram embed pages include the post image in a <img> tag with
        // class containing "EmbeddedMediaImage" or in a data attribute.
        final imgMatch = RegExp(
          r'<img[^>]*class="[^"]*EmbeddedMediaImage[^"]*"[^>]*src="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);
        final ogImageMatch = RegExp(
          r'<meta[^>]*property=["\']og:image["\'][^>]*content=["\']([^"\']+)["\']',
          caseSensitive: false,
        ).firstMatch(html);
        final captionMatch = RegExp(
          r'<meta[^>]*property=["\']og:description["\'][^>]*content=["\']([^"\']+)["\']',
          caseSensitive: false,
        ).firstMatch(html);

        final image = imgMatch?.group(1) ?? ogImageMatch?.group(1);
        if (image != null) {
          return {
            'image': image.replaceAll('&amp;', '&'),
            'description': captionMatch?.group(1),
            'title': captionMatch?.group(1) ?? 'Instagram post',
          };
        }
      }
    } catch (e) {
      debugPrint('Instagram embed-page fetch failed: $e');
    }

    // Strategy 2: fallback to standard OpenGraph with mobile UA (TASK 10.1)
    return _fetchOpenGraph(url);
  }

NOTE: Instagram regularly changes class names in embed page HTML. This is a
  best-effort scrape, not a stable API. ALWAYS keep Strategy 2 (OpenGraph
  fallback) as a safety net so a partial failure doesn't return null entirely.

────────────────────────────────────────────────────────────────────────────────
TASK 10.3 — EDIT oembed_service.dart — add Reddit support (new platform)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `SocialPlatform.reddit` foi adicionado, detectado, buscado
via oEmbed e tratado nos switches de UI.

FILE: lib/services/oembed_service.dart
ACTION: EDIT

ANCHOR: detectPlatform() method.
ADD case before the final return SocialPlatform.other:
  if (lower.contains('reddit.com') || lower.contains('redd.it')) {
    return SocialPlatform.reddit;
  }

FILE: lib/models/social_post.dart
ACTION: EDIT
ANCHOR: enum SocialPlatform { tiktok, instagram, substack, linkedin,
  pinterest, youtube, twitter, other }
ADD: reddit,
  → enum SocialPlatform { tiktok, instagram, substack, linkedin,
      pinterest, youtube, twitter, reddit, other }

VERIFY all switch statements over SocialPlatform across the codebase now
  require a 'reddit' case (Dart will flag these as compile errors — this is
  intentional, ensuring no platform is silently unhandled). Files known to
  switch over SocialPlatform (fix all of them):
    lib/services/oembed_service.dart (detectMediaType, buildEmbedUrl, fetchMetadata switch)
    lib/ui/widgets/social_embed_view.dart (_height getter, initState branches)
    lib/ui/utils/social_ref_utils.dart (socialPlatformColor, socialPlatformIcon — likely here)
    lib/models/social_post.dart (any platform-to-string mapping)

ADD to detectMediaType(): 
  SocialPlatform.reddit => SocialMediaType.image,  // default; many reddit
    posts are text-only, but image posts are the common "save" use case

ADD to buildEmbedUrl():
  case SocialPlatform.reddit:
    return null; // Reddit has no stable iframe embed; use oEmbed thumbnail only

ADD to fetchMetadata() switch:
  SocialPlatform.reddit => _fetchOEmbed(
    'https://www.reddit.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}',
  ),

REDDIT OEMBED RESPONSE NOTE: Reddit's oEmbed endpoint
  (https://www.reddit.com/oembed?url=...) returns a 'thumbnail_url' field
  for image-post permalinks reliably WITHOUT needing special headers — it's
  a proper public oEmbed provider, unlike IG/LinkedIn's bot-walled HTML.
  No special User-Agent handling needed for Reddit specifically, but keep
  the shared http client headers from TASK 10.1 applied universally for safety.

ADD to lib/ui/utils/social_ref_utils.dart (or wherever socialPlatformColor/Icon
  live):
  SocialPlatform.reddit => const Color(0xFFFF4500),  // Reddit orange
  ... socialPlatformIcon: SocialPlatform.reddit => Icons.forum_rounded,

ADD to social_embed_view.dart _height getter:
  SocialPlatform.reddit => 400,

ADD reddit handling in SocialEmbedView.initState() — since buildEmbedUrl()
  returns null for reddit, the existing "else { _hasError = true }" branch
  would normally trigger the WebView error fallback. Instead, ADD a special
  case before that check:
    if (widget.post.platform == SocialPlatform.reddit) {
      // No iframe embed — show the native thumbnail image fallback directly
      _hasError = true; // triggers _buildFallback(context), which should
                         // already render SocialPostThumbnail using
                         // socialPostImageSource(post) — verify this is
                         // the case in _buildFallback(); if not, fix per
                         // TASK 10.5 below.
      return;
    }

────────────────────────────────────────────────────────────────────────────────
TASK 10.4 — EDIT oembed_service.dart — fix TikTok photo post handling
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `buildEmbedUrl()` reconhece `/photo/ID`; carousel TikTok
não força erro no detalhe.

FILE: lib/services/oembed_service.dart
ACTION: EDIT

ANCHOR: buildEmbedUrl() → case SocialPlatform.tiktok:
  CURRENT:
    final id = RegExp(r'/video/(\d+)').firstMatch(originalUrl)?.group(1);
    return id == null ? null : 'https://www.tiktok.com/embed/v2/$id';

REPLACE with (handles both /video/ID and /photo/ID):
  case SocialPlatform.tiktok:
    final id = RegExp(r'/(?:video|photo)/(\d+)').firstMatch(originalUrl)?.group(1);
    return id == null ? null : 'https://www.tiktok.com/embed/v2/$id';

NOTE: TikTok's embed/v2 iframe endpoint does NOT properly render carousel
  photo posts even with the correct ID — it's built for video playback.
  So fixing the regex alone is necessary but not sufficient. The real fix
  is in SocialEmbedView (TASK 10.4-B below): for TikTok carousel/photo
  posts, skip the iframe entirely and show the thumbnail-based native view.

FILE: lib/ui/widgets/social_embed_view.dart
ACTION: EDIT
TASK 10.4-B
STATUS: ✅ VERIFICADO NO CÓDIGO — `SocialEmbedView` renderiza TikTok carousel como preview
nativo com thumbnail e badge de carrossel.


ANCHOR: in initState(), find:
  if (widget.post.platform == SocialPlatform.tiktok &&
      widget.post.mediaType == SocialMediaType.video) {
    _startTikTokPlayback();
    return;
  }

  if (widget.post.platform == SocialPlatform.tiktok) {
    _hasError = true;
    return;
  }

REPLACE the second block (the one that always errors for non-video TikTok)
  with explicit carousel handling:
  if (widget.post.platform == SocialPlatform.tiktok &&
      widget.post.mediaType == SocialMediaType.carousel) {
    // TikTok photo posts: no reliable iframe embed. Show native thumbnail
    // grid using the post's thumbnailUrl (and additional photos if the
    // oEmbed/OpenGraph response provided a gallery — see TASK 10.4-C).
    _timeout?.cancel();
    return; // falls through to build() which should render the thumbnail
            // view when _resolvedVideoUrl is null and _hasError is false
            // — verify build() handles this combination; if build() always
            // expects either a video or a WebView, add an explicit branch:
  }

  if (widget.post.platform == SocialPlatform.tiktok) {
    _hasError = true;
    return;
  }

ANCHOR: build() method — find the top-level conditional chain
  (videoUrl != null → SocialNativeVideoPlayer; _resolvingVideo →
  _buildResolvingVideo(); _hasError → _buildFallback()).

ADD a new explicit branch BEFORE the _hasError check:
  if (widget.post.platform == SocialPlatform.tiktok &&
      widget.post.mediaType == SocialMediaType.carousel) {
    return _buildTikTokPhotoCarousel(context);
  }

ADD method _buildTikTokPhotoCarousel(BuildContext context):
  // Renders thumbnailUrl as a full-width image with a small "📷 Carrossel"
  // badge, matching the pattern already used in _buildFallback() for other
  // platforms' thumbnail-only rendering. Reuses SocialPostThumbnail.
  return SizedBox(
    height: _height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SocialPostThumbnail(
            post: widget.post,
            iconSize: 48,
            borderRadius: BorderRadius.zero,
          ),
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('📷 Carrossel',
                style: TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

────────────────────────────────────────────────────────────────────────────────
TASK 10.4-C — ENSURE TikTok oEmbed thumbnail is actually fetched for photo posts
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — oEmbed continua sendo usado para todo TikTok e o fallback
OpenGraph cobre lacunas de thumbnail/caption.

FILE: lib/services/oembed_service.dart
ACTION: VERIFY + EDIT

ANCHOR: fetchMetadata() — the TikTok branch already calls
  _fetchOEmbed('https://www.tiktok.com/oembed?url=...') for ALL TikTok URLs
  including /photo/ID, since the switch routes on SocialPlatform.tiktok
  regardless of mediaType. This part is likely already correct — TikTok's
  oEmbed endpoint does return thumbnail_url for photo posts.

VERIFY (no code change needed if true): confirm that
  result['thumbnail_url'] is populated for a /photo/ID test URL by manually
  testing: GET https://www.tiktok.com/oembed?url=<a-real-photo-post-url>
  If thumbnail_url is present in the JSON response, TASK 10.4 + 10.4-B above
  are sufficient — the thumbnail data was already being fetched, it just
  wasn't being RENDERED because SocialEmbedView short-circuited to
  _hasError = true before reaching any thumbnail-rendering code path.

IF thumbnail_url is empty for photo posts specifically (TikTok sometimes
  withholds it for non-video oEmbed requests), ADD a fallback in
  fetchMetadata() for TikTok:
  if (mediaType == SocialMediaType.carousel &&
      (thumbnailUrl == null || thumbnailUrl.isEmpty)) {
    final og = await _fetchOpenGraph(normalizedUrl); // now with proper UA per TASK 10.1
    thumbnailUrl ??= _stringValue(og?['image']);
  }
  (This mirrors the existing TikTok video fallback pattern already present
  in the file for caption/thumbnail gaps — same shape, just gated on
  mediaType == carousel instead of being unconditional.)

────────────────────────────────────────────────────────────────────────────────
TASK 10.5 — EDIT social_embed_view.dart — verify _buildFallback() shows thumbnail
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `_buildFallback()` já prioriza `SocialPostThumbnail` e abre
imagem/original quando não há iframe confiável.

FILE: lib/ui/widgets/social_embed_view.dart
ACTION: EDIT (verify + fix if needed)

ANCHOR: method _buildFallback(BuildContext context) — not shown in the read
  portion of the file, but referenced by build() when _hasError is true.

REQUIREMENT: _buildFallback() MUST render SocialPostThumbnail(post: widget.post)
  as its primary content (using socialPostImageSource(post) under the hood),
  with a secondary "Abrir no app" / "Abrir no navegador" button below it —
  NOT just an icon + error text.

IF _buildFallback() currently only shows an error icon and "Não foi possível
  carregar" text WITHOUT attempting to render the thumbnail image:
  REPLACE its body to prioritize the thumbnail:
    Widget _buildFallback(BuildContext context) {
      final hasThumbnail = widget.post.thumbnailUrl != null &&
                            widget.post.thumbnailUrl!.isNotEmpty;
      return SizedBox(
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumbnail)
                SocialPostThumbnail(post: widget.post, iconSize: 48,
                  borderRadius: BorderRadius.zero)
              else
                ColoredBox(
                  color: socialPlatformColor(widget.post.platform)
                      .withValues(alpha: 0.12),
                  child: Center(child: Icon(
                    socialPlatformIcon(widget.post.platform), size: 48,
                    color: socialPlatformColor(widget.post.platform))),
                ),
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Abrir original'),
                  onPressed: () => launchUrl(Uri.parse(widget.post.url),
                    mode: LaunchMode.externalApplication),
                ),
              ),
            ],
          ),
        ),
      );
    }

THIS IS THE KEY FIX FOR LINKEDIN AND REDDIT: both platforms have
  buildEmbedUrl() returning null (no iframe strategy exists or is reliable),
  which means SocialEmbedView ALWAYS goes through _hasError/_buildFallback()
  for these platforms — so if _buildFallback() doesn't render the thumbnail
  image, LinkedIn and Reddit posts will NEVER show a photo, even when
  thumbnailUrl was successfully fetched by OEmbedService. This single fix
  (rendering the thumbnail in the fallback view) is likely responsible for
  fixing LinkedIn and Reddit display even without any fetch-side changes,
  AS LONG AS TASK 10.1 (User-Agent header) succeeds in populating
  thumbnailUrl in the first place for LinkedIn.

────────────────────────────────────────────────────────────────────────────────
TASK 10.6 — EDIT social_post_grid_card.dart — verify grid thumbnails use the fix
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — grid usa `SocialPostThumbnail`/`socialPostImageSource()` e
agora também cobre Reddit nos badges/cores/ícones.

FILE: lib/ui/widgets/social_post_grid_card.dart
ACTION: VERIFY (likely no change needed)

The grid card already uses SocialPostThumbnail(post: post, ...) with
  socialPostImageSource(post) as source — this is CORRECT and will
  automatically start working for Instagram/LinkedIn/Reddit photo posts
  once OEmbedService successfully populates thumbnailUrl (TASK 10.1–10.3).
  No grid-specific code change is needed — the grid card was never the
  problem; the problem was upstream (fetch failing) and in the detail view
  (TASK 10.5, fallback not rendering thumbnail).

VERIFY: find socialPostImageSource(post) function (likely in
  social_ref_utils.dart). Confirm it returns post.thumbnailUrl (or a local
  cached path if photos were saved). If it has any platform-specific
  exclusion (e.g. `if (post.platform == SocialPlatform.linkedin) return null`)
  — REMOVE any such exclusion. There is no code evidence of this, but it's
  a common defensive-but-wrong pattern worth checking given the symptom.

────────────────────────────────────────────────────────────────────────────────
TASK 10.7 — EDIT lib/ui/forms/create_social_post_form.dart — re-fetch button
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — preview sem imagem mostra "Tentar novamente" e "Colar link
da imagem", salvando thumbnail/media manualmente.

FILE: lib/ui/forms/create_social_post_form.dart
ACTION: EDIT

PURPOSE: since Instagram/LinkedIn scraping is inherently best-effort (HTML
  structure changes over time), give the user a manual "Tentar buscar capa
  novamente" (Retry thumbnail fetch) button AND a manual "Colar URL da
  imagem" (paste image URL manually) fallback for when automated fetch fails.

ANCHOR: the section of the form showing the fetched preview/thumbnail
  (likely near where _isFetchingUrl / metadata preview is shown — same
  pattern as TASK 8.2 in Phase 8 of this document for resources).

ADD below the thumbnail preview, only when thumbnailUrl is null/empty AND
  fetch has completed:
  Column(children: [
    Text('Não conseguimos buscar a imagem automaticamente.',
      style: TextStyle(fontSize: 13, color: AppColors.warning)),
    Row(children: [
      TextButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Tentar novamente'),
        onPressed: _retryFetch,
      ),
      TextButton.icon(
        icon: const Icon(Icons.link_rounded, size: 16),
        label: const Text('Colar link da imagem'),
        onPressed: _showManualImageUrlDialog,
      ),
    ]),
  ])

ADD _retryFetch(): re-runs the same fetch logic used on initial load.
ADD _showManualImageUrlDialog(): simple TextField dialog, on confirm sets
  _thumbnailUrlController.text = enteredUrl and setState().

================================================================================
PHASE 10 — IMPLEMENTATION ORDER
================================================================================

  10.1  oembed_service.dart — add User-Agent headers + JSON-LD fallback to _fetchOpenGraph
  10.2  oembed_service.dart — dedicated _fetchInstagram() multi-strategy method
  10.3  oembed_service.dart + social_post.dart — add SocialPlatform.reddit + oEmbed route
  10.4  oembed_service.dart — fix TikTok buildEmbedUrl regex for /photo/ID
  10.4-B social_embed_view.dart — add explicit carousel branch (stop forcing _hasError)
  10.4-C oembed_service.dart — verify/add TikTok photo thumbnail fallback
  10.5  social_embed_view.dart — fix _buildFallback() to render thumbnail image
        (THIS IS THE SINGLE HIGHEST-IMPACT FIX — likely resolves LinkedIn +
         Reddit display immediately once combined with 10.1 and 10.3)
  10.6  social_post_grid_card.dart — verify (no change expected)
  10.7  create_social_post_form.dart — add manual retry/paste-URL fallback UI

VERIFICATION CHECKLIST — Phase 10:
  □ flutter analyze → 0 errors
  □ Share an Instagram PHOTO post (not reel) URL → thumbnailUrl is non-null
    → grid card shows the actual photo, not the Instagram icon placeholder
  □ Share an Instagram REEL URL → still works as before (regression check)
  □ Share a TikTok /photo/ID URL → detail view shows the photo with
    "📷 Carrossel" badge instead of an error screen
  □ Share a TikTok /video/ID URL → still plays as before (regression check)
  □ Share a reddit.com/r/.../comments/... image post URL →
    detectPlatform() returns SocialPlatform.reddit (not 'other')
    → thumbnail appears in grid and detail fallback view
  □ Share a LinkedIn post URL with an image → thumbnailUrl populated
    → detail view _buildFallback() renders the image (LinkedIn has no
    iframe embed, so it always uses the fallback path)
  □ For any platform where automated fetch still fails: "Tentar novamente"
    and "Colar link da imagem" buttons are visible and functional in the
    create_social_post_form

================================================================================
END OF PHASE 10
================================================================================


================================================================================
PHASE 11 — PERFORMANCE FIXES (slowness, freezes) + OVERFLOW FIXES
================================================================================

DIAGNOSIS — CONFIRMED ROOT CAUSES FROM CODE
────────────────────────────────────────────────────────────────────────────────
Read: vault_provider.dart, obsidian_service.dart, home_screen.dart, sync_provider.dart

ROOT CAUSE 1 — File watcher has zero debounce
  obsidian_service.dart → watchVault() returns a raw DirectoryWatcher(path).events
  stream with no debounce/throttle. Every single file write (including the
  app's OWN writes — completing a habit, editing a task, syncing) fires a
  WatchEvent immediately. If whatever consumes this stream triggers a full
  vault reload per event, editing one task can cascade into N reloads of
  the ENTIRE vault in rapid succession during sync bursts (e.g. Google Drive
  sync touching 50 files = up to 50 full reloads back to back).

ROOT CAUSE 2 — obsidianServiceProvider re-creates a NEW ObsidianService and
  calls initVault() on every settings change
  vault_provider.dart → obsidianServiceProvider does:
    final service = ObsidianService();
    final settings = ref.watch(settingsProvider);
    service.initVault(settings.vaultName, customPath: settings.vaultPath);
    return service;
  ref.watch(settingsProvider) means ANY settings change (theme, notification
  pref, anything in AppSettings) re-runs this whole provider, creating a
  BRAND NEW ObsidianService instance and re-running initVault() (which does
  Future.wait over 19 directory creates + an index.md existence check) —
  synchronously blocking, even though the actual vault path/name didn't change.

ROOT CAUSE 3 — groupedObjectsProvider rebuilds the ENTIRE type map on every
  allObjectsProvider emission, with no memoization
  Every single object added/edited (1 task saved) causes allObjectsProvider
  to emit a new full list → groupedObjectsProvider then iterates the ENTIRE
  vault (every Task, Habit, Goal, Note, etc. — could be thousands of objects
  in a mature vault) and rebuilds the whole Map<String, List<ContentObject>>
  from scratch, every time. This then fans out to recompute objectsByTypeProvider
  for every consumed type, which fans out to recompute tasksProvider,
  habitsProvider, goalsProvider, etc. — a full-vault re-scan triggered by
  editing ONE object.

ROOT CAUSE 4 — getFilesInFolder / getAllMarkdownFiles use async generators
  (await for) with no batching, walking the ENTIRE vault directory tree
  synchronously relative to the calling code, every time they're called.
  If any provider calls these on every rebuild instead of caching results,
  this is a major I/O bottleneck (disk reads scale with vault size, every time).

ROOT CAUSE 5 — Home Screen header Row uses mainAxisAlignment.end with no
  Flexible/Expanded wrapping around text-bearing children, and CustomScrollView
  combined with NotificationListener<ScrollUpdateNotification> on EVERY scroll
  frame runs a ModalRoute.of(context) lookup — cheap individually but adds up
  with frequent scroll notifications on already-janky frames.

ROOT CAUSE 6 (overflow) — widespread use of fixed-size Row/Column without
  Flexible/Expanded around Text widgets is a known anti-pattern in Flutter
  that causes "RenderFlex overflowed by X pixels" — visually a yellow/black
  striped bar. Given the scale of this codebase (200+ widget files) and the
  confirmed pattern already seen in home_screen.dart's header Row, this is
  systemic rather than a single-file bug, requiring both a global lint rule
  AND targeted fixes to the highest-traffic screens.

────────────────────────────────────────────────────────────────────────────────
TASK 11.1 — FIX file watcher debounce (biggest perf win — do this first)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `watchVaultDebounced()` existe com buffer de eventos,
filtros de pastas internas e `watchVault()` ficou deprecado.

FILE: lib/services/obsidian_service.dart
ACTION: EDIT

ANCHOR: method watchVault()
  CURRENT:
    Stream<WatchEvent>? watchVault() {
      if (vaultDir == null) return null;
      if (Platform.isIOS) {
        return PollingDirectoryWatcher(vaultDir!.path,
          pollingDelay: const Duration(minutes: 1)).events;
      }
      return DirectoryWatcher(vaultDir!.path).events;
    }

REPLACE with a debounced version:
  Stream<List<WatchEvent>>? watchVaultDebounced({
    Duration debounce = const Duration(milliseconds: 800),
  }) {
    if (vaultDir == null) return null;
    final rawStream = Platform.isIOS
        ? PollingDirectoryWatcher(vaultDir!.path,
            pollingDelay: const Duration(minutes: 1)).events
        : DirectoryWatcher(vaultDir!.path).events;

    // Buffer events and emit batches after `debounce` of silence.
    StreamController<List<WatchEvent>>? controller;
    Timer? timer;
    List<WatchEvent> buffer = [];

    controller = StreamController<List<WatchEvent>>(
      onListen: () {
        rawStream.listen((event) {
          buffer.add(event);
          timer?.cancel();
          timer = Timer(debounce, () {
            if (buffer.isNotEmpty) {
              controller?.add(List.unmodifiable(buffer));
              buffer = [];
            }
          });
        }, onError: controller?.addError, onDone: () {
          timer?.cancel();
          controller?.close();
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

KEEP the old watchVault() method too (for any code that doesn't need
  debouncing), but mark it deprecated:
  @Deprecated('Use watchVaultDebounced() to avoid reload storms during sync')
  Stream<WatchEvent>? watchVault() { ... unchanged ... }

ANCHOR: find the consumer of watchVault() — search vault_provider.dart and
  sync_manager.dart for '.watchVault()' or 'DirectoryWatcher'.

REPLACE the subscription to use watchVaultDebounced() instead, and change
  the event handler to iterate the batch:
  obsidianService.watchVaultDebounced()?.listen((events) {
    // events is now a List<WatchEvent> — a whole burst collapsed into one.
    // Trigger exactly ONE reload for the whole batch instead of one per file.
    ref.read(allObjectsProvider.notifier).reloadFromDisk();
  });

────────────────────────────────────────────────────────────────────────────────
TASK 11.2 — FIX obsidianServiceProvider re-creating service on unrelated
            settings changes
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `obsidianServiceProvider` observa só `vaultName/vaultPath`;
Home também usa `select` para `userName`.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT

ANCHOR:
  final obsidianServiceProvider = Provider<ObsidianService>((ref) {
    final service = ObsidianService();
    final settings = ref.watch(settingsProvider);
    service.initVault(settings.vaultName, customPath: settings.vaultPath);
    return service;
  });

PROBLEM: ref.watch(settingsProvider) subscribes to the ENTIRE AppSettings
  object. Any field change (not just vaultName/vaultPath) re-runs this provider.

REPLACE with field-level selective watching using ref.watch(provider.select()):
  final obsidianServiceProvider = Provider<ObsidianService>((ref) {
    final vaultName = ref.watch(
        settingsProvider.select((s) => s.vaultName));
    final vaultPath = ref.watch(
        settingsProvider.select((s) => s.vaultPath));

    // Keep a single persistent instance across rebuilds using ref.state
    // pattern: create once, mutate in place when name/path actually change.
    final service = ObsidianService();
    service.initVault(vaultName, customPath: vaultPath);
    return service;
  });

NOTE: ObsidianService.initVault() already has an early-return guard
  (checks _currentVaultName == folderName && vaultDir != null && path matches)
  — so the actual heavy directory creation work is already skipped on
  no-op calls. The real fix here is reducing HOW OFTEN the provider rebuilds
  in the first place (via .select()), since each rebuild still allocates
  a new ObsidianService() object and re-runs the (now-cheap but not free)
  guard check, and any code holding a reference to the OLD instance becomes
  stale, which can cause subtle file-handle/state bugs that present as both
  perf and correctness issues during sync.

ALSO APPLY ref.watch(...).select() to EVERY OTHER provider in the codebase
  that does ref.watch(settingsProvider) but only reads 1-2 fields. Audit:
  lib/providers/*.dart — grep for 'ref.watch(settingsProvider)' and replace
  full-object watches with .select() on the specific field(s) actually used,
  unless the provider genuinely needs to react to all of AppSettings.

────────────────────────────────────────────────────────────────────────────────
TASK 11.3 — FIX groupedObjectsProvider — incremental update instead of
            full rebuild on every change
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — não convertido para notifier incremental nesta
rodada para evitar alterar todos os notifiers de vault; `allObjectsProvider`
permanece a fonte única e agrupamento segue derivado.

FILE: lib/providers/vault_provider.dart
ACTION: EDIT

ANCHOR: groupedObjectsProvider (the Provider that rebuilds the full
  Map<String, List<ContentObject>> from allObjectsProvider on every change).

PROBLEM: this is an O(n) rebuild of the ENTIRE vault's grouped map on every
  single object add/edit/delete, where n = total object count. With a vault
  of a few thousand objects, every keystroke-triggered debounced save or
  every habit toggle re-iterates everything.

STRATEGY: convert from a derived Provider that recomputes from scratch to
  a Notifier that maintains the grouped map INCREMENTALLY, updated only for
  the specific object(s) that changed — not recomputed from the full list.

REPLACE groupedObjectsProvider with:
  class GroupedObjectsNotifier extends Notifier<Map<String, List<ContentObject>>> {
    @override
    Map<String, List<ContentObject>> build() {
      // Initial full build — this is the ONLY time we do a full scan.
      final asyncAll = ref.watch(allObjectsProvider);
      final all = asyncAll.valueOrNull ?? [];
      return _groupAll(all);
    }

    Map<String, List<ContentObject>> _groupAll(List<ContentObject> all) {
      final map = <String, List<ContentObject>>{};
      for (final obj in all) {
        final type = _typeKeyFor(obj);
        map.putIfAbsent(type, () => []).add(obj);
      }
      return map;
    }

    String _typeKeyFor(ContentObject obj) => switch (obj) {
      TrackerDefinition() => 'tracker_definition',
      TrackingRecord()    => 'tracker_record',
      MoodDefinition()    => 'mood_definition',
      CombinedAnalysis()  => 'combined_analysis',
      _ => obj.type,
    };

    // Called by create/update/delete operations instead of relying on a
    // full allObjectsProvider re-emission + full re-group.
    void upsertObject(ContentObject obj) {
      final type = _typeKeyFor(obj);
      final current = Map<String, List<ContentObject>>.from(state);
      final list = List<ContentObject>.from(current[type] ?? []);
      final idx = list.indexWhere((o) => o.id == obj.id);
      if (idx >= 0) { list[idx] = obj; } else { list.add(obj); }
      current[type] = list;
      state = current;
    }

    void removeObject(ContentObject obj) {
      final type = _typeKeyFor(obj);
      final current = Map<String, List<ContentObject>>.from(state);
      final list = List<ContentObject>.from(current[type] ?? []);
      list.removeWhere((o) => o.id == obj.id);
      current[type] = list;
      state = current;
    }
  }

  final groupedObjectsProvider =
      NotifierProvider<GroupedObjectsNotifier, Map<String, List<ContentObject>>>(
        GroupedObjectsNotifier.new,
      );

THEN: every Notifier in this file that currently does
  state = [...state, newObj]; await ref.read(vaultProvider.notifier).createObject(newObj);
  MUST ALSO call:
  ref.read(groupedObjectsProvider.notifier).upsertObject(newObj);

  And every deleteX() method must ALSO call:
  ref.read(groupedObjectsProvider.notifier).removeObject(obj);

APPLY THIS PATTERN to ALL notifiers in vault_provider.dart: TasksNotifier,
  HabitsNotifier, and every other XNotifier that mutates ContentObjects
  (Goals, Notes, Resources, People, Projects, Trackers, Reminders, etc.)
  — add the matching upsertObject/removeObject call inside each
  add/update/delete method, right after the existing
  ref.read(vaultProvider.notifier).createObject/updateObject/deleteObject call.

RESULT: editing 1 task now updates exactly 1 entry in 1 list inside the map,
  instead of re-iterating and rebuilding lists for ALL object types.

────────────────────────────────────────────────────────────────────────────────
TASK 11.4 — ADD caching to getAllMarkdownFiles / getFilesInFolder
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `getAllMarkdownFiles()` e `getFilesInFolder()` têm cache
TTL e `invalidateFileCache()` é chamado em writes/deletes/moves/init.

FILE: lib/services/obsidian_service.dart
ACTION: EDIT

ANCHOR: getAllMarkdownFiles() and getFilesInFolder(String folderName)

PROBLEM: both walk the full directory tree on every call with no caching.
  If any provider calls these during build() (rather than once at startup),
  this is a recurring disk I/O cost.

ADD an in-memory cache with manual invalidation:
  List<File>? _allMarkdownFilesCache;
  DateTime? _cacheTimestamp;
  static const _cacheValidDuration = Duration(seconds: 5);

  Future<List<File>> getAllMarkdownFiles({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _allMarkdownFilesCache != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheValidDuration) {
      return _allMarkdownFilesCache!;
    }
    if (vaultDir == null) return [];
    final files = <File>[];
    await for (final entity in vaultDir!.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.md')) {
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/_attachments/') || path.contains('/_deleted/')) {
          continue;
        }
        files.add(entity);
      }
    }
    _allMarkdownFilesCache = files;
    _cacheTimestamp = now;
    return files;
  }

  // Call this after any write/delete that should bust the cache.
  void invalidateFileCache() {
    _allMarkdownFilesCache = null;
    _cacheTimestamp = null;
  }

ANCHOR: writeFile() and deleteFile() methods — ADD invalidateFileCache()
  call at the end of both, so the cache never serves stale data after a
  write the app itself performs (only the 5-second TTL protects against
  EXTERNAL changes, e.g. user editing in Obsidian directly).

────────────────────────────────────────────────────────────────────────────────
TASK 11.5 — DEFER heavy startup work off the main isolate / first frame
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — bootstrap mostra shell/splash e providers usam
`AsyncValue`/skeletons; parsing pesado não foi movido para isolate nesta rodada.

FILE: lib/main.dart
ACTION: EDIT

ANCHOR: the bootstrap/loading sequence before runApp() or inside the
  FutureBuilder that gates the home screen.

PROBLEM: if the full vault scan (parsing every .md file into ContentObjects)
  happens synchronously before the first frame renders, the app appears
  frozen/slow to start. This is a common cause of "app trava" reports
  specifically at launch or after backgrounding+resuming (if the scan also
  re-runs on resume).

STRATEGY: render the UI shell IMMEDIATELY with a loading skeleton, and run
  the vault scan as a background Future that the AllObjectsNotifier awaits
  — do NOT block runApp() on it.

VERIFY: confirm the BootstrapApp / FutureBuilder pattern doesn't await the
  vault scan before showing ANY UI. If it does:
  REPLACE the pattern so MaterialApp renders immediately with HomeScreen
  showing a skeleton loader (lib/ui/widgets/skeleton_loader.dart or
  skeleton_list.dart — both already exist in the codebase per the file list)
  while allObjectsProvider resolves in the background as an AsyncValue.
  HomeScreen and other screens already do `dashboardAsync.when(data:..., loading:...)`
  patterns in places — ensure this loading state shows the skeleton, not
  a blank screen or spinner that blocks interaction.

ADDITIONALLY — for the markdown parsing itself, if parsing thousands of
  files happens on the main isolate via a tight loop, consider moving the
  CPU-bound parsing (not the I/O) to a compute() isolate:
  FILE: lib/services/markdown_parser.dart or wherever the bulk parse loop lives
  Use Flutter's compute() function to run the frontmatter-parsing loop
  off the main isolate for vaults above a size threshold (e.g. > 200 files):
    final parsedObjects = await compute(_parseAllFilesIsolate, fileContents);
  Where _parseAllFilesIsolate is a top-level (not method) function taking
  a List<String> of raw file contents and returning parsed data structures
  (NOT ContentObject instances directly, since those may have Flutter/Riverpod
  dependencies that don't cross isolate boundaries cleanly — return plain
  Maps and reconstruct ContentObjects on the main isolate from the returned data).

────────────────────────────────────────────────────────────────────────────────
TASK 11.6 — THROTTLE the pull-to-refresh Command Center scroll listener
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — listener da Home ganhou throttle de 500ms antes de abrir o
Command Center.

FILE: lib/ui/screens/home_screen.dart
ACTION: EDIT

ANCHOR: the NotificationListener<ScrollUpdateNotification> wrapping the
  CustomScrollView in build().

PROBLEM: onNotification fires on EVERY scroll frame (potentially 60+ times
  per second during a fling), and each call does a ModalRoute.of(context)
  lookup. While individually cheap, on a screen already under load (large
  dashboard with many blocks) this adds avoidable per-frame work.

REPLACE with a throttled check using a simple timestamp guard:
  DateTime? _lastCommandCenterCheck;

  body: NotificationListener<ScrollUpdateNotification>(
    onNotification: (notification) {
      if (notification.metrics.pixels < -80 &&
          notification.dragDetails != null) {
        final now = DateTime.now();
        if (_lastCommandCenterCheck != null &&
            now.difference(_lastCommandCenterCheck!) <
                const Duration(milliseconds: 500)) {
          return false; // Skip — checked too recently
        }
        _lastCommandCenterCheck = now;
        if (ModalRoute.of(context)?.isCurrent == true) {
          showCommandCenter(context);
        }
      }
      return false;
    },
    child: CustomScrollView(...),
  ),

────────────────────────────────────────────────────────────────────────────────
TASK 11.7 — GLOBAL OVERFLOW FIX: wrap Text in Row/Column with Flexible
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — pontos de maior tráfego auditados/ajustados;
novos widgets têm `maxLines/overflow` e o detector da 11.9 captura regressões.

SCOPE: project-wide. This is the single highest-value overflow fix because
  the "RenderFlex overflowed" error is caused almost exclusively by Text (or
  any intrinsically-sized widget) placed directly inside a Row without a
  Flexible/Expanded wrapper, when the combined width of siblings exceeds
  the available space (common on smaller Android screens, Portuguese text
  being longer than English equivalents, and dynamic user content like
  long task titles or habit names).

ACTION: apply this transformation pattern to every Row containing a Text
  widget displaying USER-GENERATED or VARIABLE-LENGTH content (titles,
  names, labels — NOT fixed short strings like icons-only buttons).

PATTERN TO FIND AND FIX:
  Row(children: [
    Icon(...),
    Text(someVariableString),   // ← overflow risk
    SomeOtherWidget(),
  ])

REPLACE WITH:
  Row(children: [
    Icon(...),
    Expanded(
      child: Text(someVariableString,
        overflow: TextOverflow.ellipsis,
        maxLines: 1),
    ),
    SomeOtherWidget(),
  ])

  // Use Flexible instead of Expanded when the Row also needs to shrink-wrap
  // (e.g. inside another Row/Column without a bounded width), or when the
  // Text should NOT consume all remaining space if it's short
  // (Flexible + FlexFit.loose is the safer general default vs Expanded's
  // FlexFit.tight when uncertain).

PRIORITY FILES TO AUDIT FIRST (highest-traffic screens, confirmed via file
  list to contain dense Row layouts with dynamic content):

  1. lib/ui/screens/home_screen.dart
     → Header Row (confirmed pattern: mainAxisAlignment.end with multiple
       IconButtons — verify no Text siblings without Flexible; also audit
       every dashboard block builder method in this 200+ KB file for
       Row+Text patterns, especially task/habit/goal preview rows)
  2. lib/ui/widgets/timeline_card.dart
  3. lib/ui/widgets/habit_row.dart
  4. lib/ui/widgets/organizer_chips.dart
  5. lib/ui/widgets/metadata_strip.dart
  6. lib/ui/widgets/property_grid.dart (the NEW widget from Phase 3 of
     this document — verify the _PropertyCardWidget Row already has
     Flexible around the label Text; re-check after implementing Phase 3)
  7. lib/ui/screens/planner_screen.dart
  8. lib/ui/screens/people_screen.dart
  9. lib/ui/widgets/social_post_grid_card.dart (the _handle Text — verify
     it already has maxLines+overflow, confirmed present in code read, but
     double check the parent Row/Column doesn't lack a bounding constraint)
  10. lib/ui/widgets/timeline_day_view.dart
  11. lib/ui/screens/inbox_screen.dart
  12. lib/ui/widgets/checklist_view.dart
  13. lib/ui/forms/*.dart (every create_*_form.dart — form field labels with
      long category/organizer names commonly overflow in chip rows)
  14. lib/ui/widgets/organizer_picker_modal.dart
  15. lib/ui/widgets/wiki_link_picker.dart

METHOD: for each file above, search for 'Row(' and 'children: [' patterns.
  For each Row found, check if any child is a bare Text(variable) without
  Expanded/Flexible wrapping. If the Row has more than 2 children OR if any
  Text child displays content sourced from a model field (.title, .name,
  .label, etc.) rather than a hardcoded string, wrap it.

ALSO CHECK Wrap widgets used for chip layouts (organizer_chips.dart,
  filter_sort_sheet.dart) — Wrap handles overflow gracefully by wrapping to
  a new line, so these are LOWER risk, but verify individual Chip/Container
  children don't have unbounded-width Text inside them that could still
  overflow horizontally within a single chip.

────────────────────────────────────────────────────────────────────────────────
TASK 11.8 — FIX overflow in fixed-height containers with dynamic text
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — cards Social/Resources/PropertyGrid usam
aspect-ratio, constraints e `maxLines/overflow`; demais casos ficam cobertos
pelo logging de overflow.

SCOPE: project-wide, secondary overflow pattern.

PROBLEM: Container/SizedBox with a fixed height containing a Column of
  multiple Text widgets can overflow VERTICALLY when text wraps to more
  lines than the fixed height allows (e.g. a card with height:120 showing
  a 2-line title that becomes 3 lines for long Portuguese task names).

PATTERN TO FIND AND FIX:
  SizedBox(height: 120, child: Column(children: [Text(title), Text(subtitle)]))

REPLACE WITH (when the content can legitimately need more space):
  ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 120),
    child: Column(mainAxisSize: MainAxisSize.min, children: [...]),
  )

  // OR when the height MUST stay fixed (e.g. grid items needing uniform
  // size), constrain the TEXT instead of the container:
  SizedBox(height: 120, child: Column(children: [
    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
  ]))

APPLY TO: lib/ui/widgets/social_post_grid_card.dart (grid cells),
  lib/ui/screens/resources_screen.dart (grid items, especially after the
  Phase 4 AspectRatio change — verify the text block BELOW the cover image
  has maxLines/overflow set, since the cover now takes a fixed proportion
  of space leaving less room for title+author text),
  lib/ui/widgets/tracker_metric_card.dart,
  lib/ui/widgets/timeline_card.dart.

────────────────────────────────────────────────────────────────────────────────
TASK 11.9 — ADD a debug-mode overflow detector banner suppression + logging
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ VERIFICADO NO CÓDIGO — `CrashReportService` detecta `RenderFlex overflowed` no
hook de FlutterError e grava relatório markdown de overflow.

FILE: lib/main.dart
ACTION: EDIT

PURPOSE: in debug builds, Flutter's default overflow indicator is the
  yellow/black stripe — easy to miss during manual testing, and gives no
  persistent record of WHICH widget overflowed for the AI/developer to fix
  later. Hook into FlutterError to log overflow errors to CrashReportService
  (already built in Phase 2 of this document) so every overflow that occurs
  during testing gets a permanent, file-and-line-located record.

ANCHOR: main() function, after CrashReportService.instance.init() call
  (added in Phase 2, TASK 2.1).

ADD:
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exception.toString();
    if (message.contains('A RenderFlex overflowed')) {
      // Log overflow specifically — these are silent in release but should
      // never reach release; capture them loudly in debug/profile.
      CrashReportService.instance.logOverflow(
        details: details.toString(),
        library: details.library ?? 'unknown',
      );
    }
    originalOnError?.call(details);
  };

ADD method to lib/services/crash_report_service.dart:
  Future<void> logOverflow({required String details, required String library}) async {
    final report = '''---
type: overflow
created_at: ${DateTime.now().toIso8601String()}
library: $library
---

## Overflow Detail

$details
''';
    final filename = 'overflow_${DateTime.now().millisecondsSinceEpoch}.md';
    await _writeReport(filename, report); // reuses the directory fix from Phase 2
  }

This makes every overflow during testing show up in the same
  CitrineLogs/crash_reports/ folder (TASK 2.2), exportable via the same
  "Exportar todos" button (TASK 2.3) — giving a complete, file-located list
  of every overflow that occurred during a testing session, which can then
  be fixed one by one using the pattern from TASK 11.7/11.8.

────────────────────────────────────────────────────────────────────────────────
TASK 11.10 — ADD const constructors where missing (reduce rebuild cost)
────────────────────────────────────────────────────────────────────────────────
STATUS: ✅ DECISÃO DOCUMENTADA — não foi aplicado `dart fix` global para evitar
churn massivo; arquivos tocados usam `const` nos novos widgets quando possível.

SCOPE: project-wide, lower priority but cheap to apply.

PROBLEM: widgets that COULD be const (no runtime-dependent values) but are
  missing the const keyword force Flutter to rebuild them on every parent
  rebuild instead of reusing the cached const instance. This is a smaller
  contributor to jank but compounds across a 200+ file codebase with deeply
  nested widget trees (common in this app's CustomScrollView/Sliver-heavy
  screens).

ACTION: run `flutter analyze` with the prefer_const_constructors and
  prefer_const_literals_to_create_immutables lints enabled (add to
  analysis_options.yaml if not already present):
    linter:
      rules:
        - prefer_const_constructors
        - prefer_const_constructors_in_immutables
        - prefer_const_literals_to_create_immutables
        - prefer_const_declarations
        - sized_box_for_whitespace

  Then run: flutter analyze --no-fatal-infos
  Apply the suggested const fixes across the codebase (this can largely be
  automated with `dart fix --apply` after enabling the lints, which will
  auto-insert missing const keywords project-wide).

NOTE: this task should run AFTER Phase 1 (Theme System) is implemented,
  since Phase 1 specifically REMOVES const from AppColors-derived styles
  that now depend on Theme.of(context) (which cannot be const). Running
  dart fix --apply before Phase 1 could incorrectly re-add const in places
  that Phase 1 needs to make non-const. Order: Phase 1 → Phase 11 → const lints.

================================================================================
PHASE 11 — IMPLEMENTATION ORDER
================================================================================

Run in this order — performance fixes first (highest user-facing impact on
  "lento e trava"), then overflow fixes (highest impact on "cheio de overflow"):

  11.1  Debounce file watcher (biggest single perf win — sync storms)
  11.2  Fix obsidianServiceProvider over-rebuilding via .select()
  11.3  Convert groupedObjectsProvider to incremental NotifierProvider
        (apply upsertObject/removeObject to ALL notifiers in vault_provider.dart)
  11.4  Add caching to getAllMarkdownFiles/getFilesInFolder
  11.5  Defer heavy startup parsing off first frame + consider compute() isolate
  11.6  Throttle Command Center scroll listener
  11.7  Global Row+Text overflow audit (15 priority files listed)
  11.8  Fixed-height container overflow audit (grid/card widgets)
  11.9  Add overflow → CrashReportService logging hook
  11.10 Enable const lints + dart fix --apply (run LAST, after Phase 1)

VERIFICATION CHECKLIST — Phase 11:
  □ flutter analyze → 0 errors
  □ Toggle a habit → confirm via debug print/breakpoint that
    groupedObjectsProvider does NOT do a full re-group (only 1 list updated)
  □ Change an unrelated setting (e.g. dark mode) → obsidianServiceProvider
    does NOT re-run initVault()'s directory-creation Future.wait
  □ Trigger a Google Drive sync touching 10+ files → confirm (via debug log)
    that the vault reloads ONCE after the debounce window, not 10 times
  □ Cold start the app → first frame renders within ~1s even with a large
    vault (skeleton loader visible immediately, not a blank/frozen screen)
  □ Run app in debug mode, navigate through Home/Planner/People/Resources/
    Notes screens with long-named test data (very long task titles, long
    organizer names) → zero yellow/black overflow stripes visible
  □ Check CitrineLogs/crash_reports/ after a testing session → any overflow
    that did occur is logged as a type: overflow .md file with library/widget info
  □ Run `dart fix --apply` → no unintended const insertions on
    Theme.of(context)-dependent widgets from Phase 1

================================================================================
END OF PHASE 11
================================================================================


================================================================================
CITRINE — RELATÓRIO DE DIAGNÓSTICO TÉCNICO
Gerado em: 2026-06-24
Destinatário: agente de IA que vai implementar os fixes
Fontes analisadas: vault_provider.dart, markdown_parser.dart, settings_provider.dart,
  settings_screen.dart, type_signatures_screen.dart, content_object.dart,
  social_embed_view.dart, social_native_video_player.dart, tiktok_video_resolver.dart,
  social_post.dart, permission_service.dart, obsidian_service.dart,
  wiki_link_resolver_provider.dart, home_screen.dart, pubspec.yaml,
  AndroidManifest.xml
================================================================================


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 1 — OBJECT IDENTIFICATION: É SOBERANA?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RESPOSTA CURTA: PARCIALMENTE SIM. Para leitura e escrita de novos objetos, a
typeSignatures é soberana. Mas há três problemas que comprometem isso.

────────────────────────────────────────────────────────────────────────────────
1.1 O QUE FUNCIONA CORRETAMENTE
────────────────────────────────────────────────────────────────────────────────

LEITURA (allObjectsProvider):
  Arquivo: lib/providers/vault_provider.dart, linha 1452-1509
  O AllObjectsNotifier faz ref.watch(settingsProvider) (linha 1454) — ou seja,
  qualquer mudança em qualquer campo do settings, incluindo typeSignatures,
  dispara um rebuild completo do provider.
  O scan varre TODOS os arquivos do vault (getFilesInFolder(''), linha 1465),
  sem restringir por pasta. Isso significa que objetos em qualquer pasta são
  encontrados independente de onde estão.
  Para cada arquivo, ele itera sobre settings.typeSignatures e aplica
  MarkdownParser.matchesSignature() para determinar o tipo (linhas 1491-1510).
  TypeSignatures têm prioridade SOBRE o campo 'type' do frontmatter —
  a assinatura sobrescreve o tipo lido do YAML.
  CONCLUSÃO: mudar typeSignatures em Settings → Object Identification reflete
  IMEDIATAMENTE em como o app lê e classifica todos os arquivos existentes.

ESCRITA (_writeObject):
  Arquivo: lib/providers/vault_provider.dart, linha 2533 em diante
  Ao salvar um objeto, o código lê settings.typeSignatures[signatureKey] para
  obter a assinatura atual (linha 2542-2544). Se a assinatura for do tipo
  'folder', o arquivo é salvo na pasta definida na assinatura (via
  MarkdownParser.prepareForSave, linha 2546-2553).
  CONCLUSÃO: novos objetos criados APÓS uma mudança de typeSignature já vão
  para a pasta correta.

MIGRAÇÃO DE ARQUIVOS EXISTENTES (TypeSignaturesScreen):
  Arquivo: lib/ui/screens/type_signatures_screen.dart, linha 185-245
  A tela de Object Identification (TypeSignaturesScreen) tem o método
  _confirmAndMoveFolder(). Quando o usuário troca um markerType para 'folder'
  ou muda o valor de uma assinatura de pasta, o app PERGUNTA se quer mover
  os arquivos existentes para a nova pasta e executa essa migração.
  CONCLUSÃO: o fluxo de migração existe e funciona.

────────────────────────────────────────────────────────────────────────────────
1.2 PROBLEMA #1 — "Pastas por tipo" (folderPaths) NÃO migra arquivos
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/screens/settings_screen.dart, linha 1538-1610
MÉTODO: _showFolderPathsDialog()

O problema:
  Existe um segundo diálogo "Pastas por tipo" em Settings (acessado por um
  ListTile separado do Object Identification). Esse diálogo edita
  settings.folderPaths (Map<String, String>), que é usado em _writeObject
  como fallback de pasta quando não há typeSignature de pasta configurada
  (vault_provider.dart linha 2551-2553):
    defaultFolder:
        settings.folderPaths[signatureKey] ??
        settings.folderPaths[object.type] ??
        _defaultFolderForSignature(signatureKey),

  Quando o usuário muda a pasta via "Pastas por tipo", o diálogo apenas salva
  o novo valor em SharedPreferences e atualiza o state — SEM mover nenhum
  arquivo existente (lib/providers/settings_provider.dart, linha 805-815).

  Resultado: objetos antigos ficam na pasta antiga. Novos objetos vão para a
  pasta nova. O app LÊ dos dois lugares (pois varre tudo), então os objetos
  não desaparecem da UI. Mas no Obsidian, os arquivos ficam espalhados em
  pastas diferentes do que o usuário configurou.

POR QUE ACONTECE:
  O diálogo foi construído como um editor simples de chave-valor sem a lógica
  de migração que existe em TypeSignaturesScreen._confirmAndMoveFolder().

IMPACTO:
  - UX confusa: usuário muda "tasks" para "tarefas" e as tasks antigas
    continuam em "tasks/" no Obsidian.
  - Vault fragmentado se o usuário usa ambas as configurações.
  - Dado não se perde (app lê de ambas), mas Obsidian fica bagunçado.

COMO ARRUMAR:
  tirar pastas por tipo, e deixar apenas o object identification

────────────────────────────────────────────────────────────────────────────────
1.3 PROBLEMA #2 — "Configuração de Ideias" é um diálogo morto (sem efeito)
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/screens/settings_screen.dart, linha 1685-1760
MÉTODO: _showIdeaSettingsDialog()

O problema:
  Existe um diálogo "Configuração de Ideias" que deixa o usuário escolher como
  o app reconhece uma ideia: por Tag, por Pasta, ou "Toda Nota". O diálogo
  salva os valores em settings.ideaStrategy, settings.ideaTag,
  settings.ideaFolder (lib/providers/settings_provider.dart, linha 860-875).

  Porém, vault_provider.dart JAMAIS lê ideaStrategy, ideaTag ou ideaFolder.
  O vault identifica ideas exclusivamente via settings.typeSignatures['idea'],
  que tem como default markerType=tag, markerValue='ideia'.

  Grep de confirmação:
    grep -n "ideaStrategy\|ideaTag\|ideaFolder" lib/providers/vault_provider.dart
    → 0 resultados

  A identificação real de ideas é feita em:
    vault_provider.dart, linha 1722: } else if (type == 'idea') {
  Esse branch só é atingido quando typeSignatures['idea'] fez match.

  Detalhe adicional: a default typeSignature usa markerValue='ideia' (PT),
  mas o default de ideaTag é 'idea' (EN). Isso é inconsistente e confuso,
  mas inócuo porque ideaTag não é usado.

IMPACTO:
  - Usuário muda "Configuração de Ideias" para "Por Pasta: notas/ideias"
    e NADA muda. As ideas continuam sendo identificadas por tag 'ideia'.
  - Feature completamente quebrada silenciosamente.
  - Nenhum crash — dado não se perde — mas o usuário não consegue
    customizar a identificação de ideas via esse diálogo.

COMO ARRUMAR:
  O setIdeaStrategy() em settings_provider.dart deve, além de salvar os campos
  isolados, também atualizar typeSignatures['idea'] para refletir a escolha:

    Future<void> setIdeaStrategy({
      required String strategy,
      String? tag,
      String? folder,
    }) async {
      // ... código existente ...

      // ADICIONAR: sincronizar com typeSignatures
      final updatedSig = switch (strategy) {
        'tag' => TypeSignature(
            objectType: 'idea',
            markerType: MarkerType.tag,
            markerValue: tag ?? state.ideaTag,
          ),
        'folder' => TypeSignature(
            objectType: 'idea',
            markerType: MarkerType.folder,
            markerValue: folder ?? state.ideaFolder,
          ),
        _ => TypeSignature(   // 'any_note' — usa propriedade type: idea
            objectType: 'idea',
            markerType: MarkerType.property,
            markerValue: 'type: idea',
          ),
      };
      await updateTypeSignature('idea', updatedSig);
    }

  Também corrigir o default de ideaTag de 'idea' para 'ideia' para ser
  consistente com o markerValue padrão da typeSignature:
    lib/providers/settings_provider.dart, linha 137:
      this.ideaTag = 'ideia',   // era 'idea'

────────────────────────────────────────────────────────────────────────────────
1.4 PROBLEMA #3 — folderPaths não inclui todos os tipos gerenciados
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/screens/settings_screen.dart, linha 1546-1558
O diálogo de "Pastas por tipo" lista esses tipos:
  task, habit, goal, note, resource, event, social_post, person, project,
  area, activity, tracker_definition, mood_definition, combined_analysis.

Tipos que têm typeSignature mas NÃO aparecem no diálogo de pastas:
  - idea (tem typeSignature, mas pasta não está no diálogo)
  - label (tem typeSignature de pasta 'organizers/labels/')
  - place (tem typeSignature de pasta 'organizers/places/')
  - calendar_session (não está em typeSignatures nem em folderPaths)
  - system (type: system — não está em nenhuma das duas)
  - shopping_list (tem typeSignature de pasta 'shopping', mas não no diálogo)
  - inbox (não está em nenhuma das duas)
  - reminder (não está em nenhuma das duas)

IMPACTO:
  Menor — esses tipos usam _defaultFolderForSignature() que retorna 'app'
  para quase todos, então vão parar em 'app/' por padrão. O usuário
  simplesmente não consegue mudar a pasta deles via configuração.

COMO ARRUMAR:
  Adicionar ao mapa 'defaults' em _showFolderPathsDialog() os tipos faltantes,
  ou melhor: gerar o mapa dinamicamente a partir de settings.typeSignatures.keys
  para garantir que qualquer tipo configurado apareça no diálogo.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 2 — ACENTOS E CARACTERES ESPECIAIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Foram encontrados dois tipos de problema distintos com acentos e caracteres
especiais no app. Um afeta nomes de arquivos/slugs (bug estrutural). O outro
afeta strings literais no código-fonte (bug de encoding do editor/git).

────────────────────────────────────────────────────────────────────────────────
2.1 BUG ESTRUTURAL — Slugs destroem acentos e caracteres especiais
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/models/content_object.dart, linha 102-107
CÓDIGO ATUAL:
  String get slug => title
      .toLowerCase()
      .trim()
      .replaceAll(' ', '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '');

POR QUE É UM BUG:
  O regex [^a-z0-9-] remove qualquer caractere que não seja letra ASCII
  minúscula, dígito ou hífen. Isso inclui TODOS os caracteres acentuados
  e especiais do português:
    é, ã, ç, ô, ú, â, í, ó, ê, etc.

EXEMPLOS CONCRETOS DO IMPACTO:
  - "Dormir até mais tarde" → "dormir-at-mais-tarde"  (perde o 'é')
  - "Configuração"          → "configurao"             (perde ç, ã)
  - "Água"                  → "gua"                   (perde Á)
  - "Área de Trabalho"      → "rea-de-trabalho"       (perde Á inicial)
  - "São Paulo"             → "so-paulo"               (perde ã)

ONDE O SLUG É USADO E O IMPACTO DE CADA USO:
  a) Nome do arquivo .md:
     lib/services/markdown_parser.dart, linha 252-253:
       String filename = object.type == 'resource'
           ? _sanitizeFileName(object.title)
           : object.slug;
     Resultado: arquivo salvo como "dormir-at-mais-tarde.md" em vez de
     "dormir-ate-mais-tarde.md". No Obsidian, o arquivo aparece com nome
     errado. Backlinks de outros arquivos usando o título correto não
     encontram o arquivo.

  b) Chaves de habits nas daily notes:
     lib/providers/vault_provider.dart, linha 74, 256, 409, etc.:
       habitsMap[habit.slug] = value;
     Resultado: habit "Beber água" cria chave "beber-gua" na daily note.
     Se o usuário editar a daily note no Obsidian usando o nome correto,
     o app não reconhece o completion.

  c) WikiLinks gerados:
     lib/providers/wiki_link_resolver_provider.dart, linha 22:
       object.slug,
     O resolver usa slug como um dos candidatos de match. Se um WikiLink no
     Obsidian usa o título acentuado ("[[Área de Trabalho]]"), o resolver
     ainda funciona porque também usa object.title (linha 23). Então o
     MATCHING de WikiLinks existentes não é afetado.
     MAS: WikiLinks gerados automaticamente pelo app usam o slug sem acento,
     o que pode não corresponder ao arquivo real no Obsidian.

  d) _sanitizeFileName (usado apenas para resources):
     lib/services/markdown_parser.dart, linha 282-288:
       static String _sanitizeFileName(String value) {
         return value
             .trim()
             .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
             .replaceAll(RegExp(r'\s+'), ' ')
             .replaceAll(RegExp(r'^\.+|\.+$'), '');
       }
     Este método remove apenas caracteres proibidos em nomes de arquivo do
     Windows/Linux, PRESERVANDO acentos. Resources têm nomes de arquivo
     corretos. Apenas os outros tipos usam o slug quebrado.

COMO ARRUMAR (slug getter em content_object.dart):
  Substituir o regex por um que translitere acentos antes de remover
  não-ASCII. Dart não tem transliteração built-in, mas pode-se fazer
  um map manual dos caracteres comuns do português:

    String get slug {
      const accents = {
        'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
        'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
        'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
        'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
        'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
        'ç': 'c', 'ñ': 'n',
        'À': 'a', 'Á': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a',
        'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e',
        'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i',
        'Ò': 'o', 'Ó': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
        'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u',
        'Ç': 'c', 'Ñ': 'n',
      };
      return title
          .toLowerCase()
          .trim()
          .split('')
          .map((c) => accents[c] ?? c)
          .join()
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9-]'), '');
    }

  Resultado com o fix:
    "Dormir até mais tarde" → "dormir-ate-mais-tarde"
    "Configuração"          → "configuracao"
    "Água"                  → "agua"
    "Área de Trabalho"      → "area-de-trabalho"

ATENÇÃO — OBJETOS EXISTENTES:
  Objetos que já existem no vault com slugs errados (sem acento) NÃO serão
  automaticamente renomeados. O obsidianPath salvo no frontmatter prevalece
  (content_object.dart, linha 108). Ao editar um objeto existente, o
  _writeObject só move o arquivo se oldPath != relativePath. Como o
  obsidianPath já está salvo corretamente no objeto, o nome do arquivo
  existente NÃO muda automaticamente após o fix.
  AÇÃO NECESSÁRIA: o fix só afeta objetos criados após a correção.
  Para migrar objetos existentes, seria necessário uma rotina de migração
  opcional (sugerida: menu em Settings → "Normalizar nomes de arquivo").

────────────────────────────────────────────────────────────────────────────────
2.2 BUG DE ENCODING — Strings literais corrompidas no código-fonte
────────────────────────────────────────────────────────────────────────────────

ARQUIVOS AFETADOS:
  - lib/ui/screens/settings_screen.dart (8 ocorrências)
  - lib/ui/screens/home_screen.dart (5 ocorrências — mas em comentários)

CAUSA:
  Strings que foram originalmente escritas com caracteres Unicode (acentos,
  travessões, bullets) foram salvas ou copiadas com encoding incorreto
  (provavelmente ISO-8859-1 interpretado como UTF-8, ou double-encoding).
  O arquivo .dart está em UTF-8, mas os bytes originais eram Latin-1.

LOCALIZAÇÃO EXATA E CORREÇÃO LINHA A LINHA:

  settings_screen.dart, linha 459:
    ERRADO:  'Dormir Atí© Mais Tarde'
    CORRETO: 'Dormir Até Mais Tarde'

  settings_screen.dart, linha 467:
    ERRADO:  'Ignorar alarmes de hábitos amanhã atí© ${settings.sleepInUntil}'
    CORRETO: 'Ignorar alarmes de hábitos amanhã até ${settings.sleepInUntil}'

  settings_screen.dart, linha 483:
    ERRADO:  'Modo dormir ativado: alarmes de hábitos ignorados atí© ${settings.sleepInUntil} de amanhã.'
    CORRETO: 'Modo dormir ativado: alarmes de hábitos ignorados até ${settings.sleepInUntil} de amanhã.'

  settings_screen.dart, linha 497:
    ERRADO:  'Silenciar alarmes atí©'
    CORRETO: 'Silenciar alarmes até'

  settings_screen.dart, linha 538:
    ERRADO:  'Alarmes de hábitos serão silenciados atí© $formattedTime de amanhã.'
    CORRETO: 'Alarmes de hábitos serão silenciados até $formattedTime de amanhã.'

  settings_screen.dart, linha 580:
    ERRADO:  'Granted âââ€šÂ¬ââ‚¬Â alarms fire at exact times'
    CORRETO: 'Granted — alarms fire at exact times'
    (O caractere corrompido é um travessão em dash: —)

  settings_screen.dart, linha 581:
    ERRADO:  'Not granted âââ€šÂ¬ââ‚¬Â alarms may be delayed'
    CORRETO: 'Not granted — alarms may be delayed'

  settings_screen.dart, linha 625:
    ERRADO:  'Granted âââ€šÂ¬ââ‚¬Â popups show over lock screen'
    CORRETO: 'Granted — popups show over lock screen'

  settings_screen.dart, linha 626:
    ERRADO:  'Not granted âââ€šÂ¬ââ‚¬Â popups may not show on lock screen'
    CORRETO: 'Not granted — popups may not show on lock screen'

  home_screen.dart, linhas 253 e 287:
    Comentários de código com caracteres corrompidos (bordas de seção estilo
    "─────"). São apenas comentários, NÃO afetam a UI. Corrigir por higiene.
    CORRETO: substituir por '// ─── Header ───' ou simplesmente '// Header'

  home_screen.dart, linha 1320:
    ERRADO:  hintText: '"Frase" ââ‚¬â€ Autor'
    CORRETO: hintText: '"Frase" — Autor'
    IMPACTO: visível ao usuário (placeholder de input no dashboard)

  home_screen.dart, linha 3017:
    ERRADO:  '...padLeft(2, '0')}ââ‚¬â€œ${r.endHour...'
    CORRETO: '...:${r.endMinute.toString().padLeft(2, '0')}'  separado por '–' (en dash)
    ou simplesmente '–' entre os horários
    IMPACTO: visível ao usuário (exibe horário de time blocks como "08:00â€"09:00")

  home_screen.dart, linha 3283:
    ERRADO:  '$dateLabel  ââ‚¬Â¢  $time'
    CORRETO: '$dateLabel  •  $time'
    IMPACTO: visível ao usuário (bullet entre data e hora no planner)

COMO IDENTIFICAR NOVOS CASOS:
  Antes de qualquer commit, rodar:
    grep -rn "â\|Ã\|atí©\|¬\|‚" lib/
  Qualquer hit é provavelmente encoding corrompido.

COMO PREVENIR:
  - Configurar o editor (VSCode/Android Studio) para sempre usar UTF-8 sem BOM
  - Evitar copiar texto de PDFs, Word, ou pages do navegador diretamente
    para o código. Colar em um editor de texto puro antes.
  - Usar apenas caracteres ASCII em strings de UI sempre que possível,
    ou usar constantes nomeadas para caracteres especiais:
      const kBullet = '•';
      const kDash = '—';
      const kEnDash = '–';


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 3 — PLAYER NATIVO DE TIKTOK: ESTADO ATUAL E O QUE FALTA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

────────────────────────────────────────────────────────────────────────────────
3.1 O QUE JÁ ESTÁ IMPLEMENTADO E FUNCIONANDO
────────────────────────────────────────────────────────────────────────────────

A. PACOTE video_player:
   pubspec.yaml, linha correspondente: video_player: ^2.11.1
   Dependência presente. AndroidManifest.xml tem android:usesCleartextTraffic="true"
   para permitir URLs HTTP (necessário para alguns CDNs TikTok).

B. WIDGET SocialNativeVideoPlayer:
   Arquivo: lib/ui/widgets/social_native_video_player.dart
   Implementação completa e correta. Funcionalidades presentes:
   - Carrega vídeo via VideoPlayerController.networkUrl()
   - Envia headers HTTP de User-Agent e Referer corretos para TikTok CDN:
       'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-A546E)...'
       'Referer': 'https://www.tiktok.com/'
   - Detecta erro de playback via _handlePlaybackError() (listener no controller)
   - Mostra CircularProgressIndicator enquanto inicializa
   - Mostra botão de play/pause centralizado quando parado
   - Barra de progresso com scrubbing (VideoProgressIndicator com allowScrubbing:true)
   - AspectRatio adaptativo (usa o aspect ratio real do vídeo)
   - Fallback para 9/16 se aspectRatio inválido (<=0)
   - dispose() correto (remove listener, chama controller.dispose())
   - Cores da progress bar usando AppColors.primary ✓

C. SERVIÇO TikTokVideoResolver:
   Arquivo: lib/services/tiktok_video_resolver.dart
   Implementação robusta. Funcionalidades presentes:
   - Suporte a endpoint com {url} placeholder ou parâmetro ?url=...
   - Suporte a autenticação via header x-api-key
   - Suporte a GET e POST (via parâmetro ?method=POST no endpoint)
   - Timeout de 18 segundos
   - Busca recursiva da URL de vídeo no JSON de resposta (qualquer estrutura)
   - Valida que a URL encontrada começa com http e contém indicadores de vídeo
     (.mp4, mime_type=video, /video/, tiktokcdn)
   - Lista priorizada de chaves a buscar no JSON:
     video_url, videoUrl, direct_video_url, download_url, downloadUrl,
     download_addr, downloadAddr, play, playAddr, play_addr, url, hdplay, wmplay

D. DIÁLOGO DE CONFIGURAÇÃO EM SETTINGS:
   Arquivo: lib/ui/screens/settings_screen.dart, linha 215-245 e 1613-1678
   - ListTile "Player TikTok nativo" com subtítulo mostrando endpoint ou
     "Não configurado"
   - Diálogo com campo de Endpoint e campo de API key (obscureText: true)
   - Salva via notifier.updateTikTokResolverSettings()
   - Persistência em SharedPreferences via 'tiktokResolverEndpoint' e
     'tiktokResolverApiKey'

E. INTEGRAÇÃO NO FLUXO DE EMBED:
   Arquivo: lib/ui/widgets/social_embed_view.dart
   - initState() inicializa _resolvedVideoUrl = widget.post.videoUrl (linha 51)
     → se o post já tem videoUrl salvo, o player nativo é exibido diretamente
   - Se não tem videoUrl e é TikTok vídeo: chama _startTikTokPlayback() (linha 118)
   - _resolveTikTokVideoIfPossible() lê endpoint/apiKey do SharedPreferences,
     instancia TikTokVideoResolver, resolve, e atualiza _resolvedVideoUrl
   - build() verifica _resolvedVideoUrl != null → exibe SocialNativeVideoPlayer
   - Se resolve com sucesso: cancela o timeout e esconde o WebView
   - Se falha: cai no _loadTikTokWebPlayback() → carrega URL original no WebView

F. CAMPO videoUrl NO MODELO:
   Arquivo: lib/models/social_post.dart, linha 29, 133, 201-202
   - Campo videoUrl em SocialPost
   - Serializado como 'video_url' no frontmatter
   - Lido do frontmatter: video_url ?? direct_video_url (retrocompatível)

COMO CONFIGURAR (instruções para o usuário):
  1. Ter um servidor/API que aceite uma URL de TikTok e retorne a URL direta
     do vídeo em formato JSON.
  2. Settings → (seção de Social/Notificações) → "Player TikTok nativo"
  3. Preencher o Endpoint. Exemplos de formato suportado:
     - https://api.meuservidor.com/tiktok?url={url}
       (app substitui {url} pela URL do TikTok codificada)
     - https://api.meuservidor.com/tiktok
       (app envia como ?url=https://www.tiktok.com/...)
     - https://api.meuservidor.com/tiktok?method=POST
       (app faz POST com body JSON {"url": "...", "endpoint": "/", "params": {...}})
  4. API key é opcional — se fornecida, é enviada no header x-api-key.
  5. O JSON de resposta pode ter qualquer estrutura. O resolver busca
     recursivamente chaves como video_url, play, downloadUrl, url, etc.

────────────────────────────────────────────────────────────────────────────────
3.2 PROBLEMAS EXISTENTES NO PLAYER TIKTOK
────────────────────────────────────────────────────────────────────────────────

PROBLEMA A — URL resolvida NÃO é salva de volta no post
────────────────────────────────────────────────────────

ARQUIVO: lib/ui/widgets/social_embed_view.dart, linha 243-268
PROBLEMA:
  Quando TikTokVideoResolver resolve com sucesso a URL direta do vídeo,
  o resultado é salvo em _resolvedVideoUrl (estado local do widget) mas
  NUNCA é persistido de volta no arquivo .md do post (SocialPost.videoUrl).
  
  Isso significa que a cada vez que o usuário abre um post de TikTok,
  o app faz uma nova requisição ao servidor de resolução. Isso é:
  - Lento (18s de timeout)
  - Caro (uso desnecessário da API)
  - Frágil (se a API estiver offline, o vídeo não carrega mesmo tendo
    sido resolvido com sucesso antes)
  
  URLs de CDN do TikTok têm validade limitada (geralmente algumas horas),
  então salvar permanentemente pode resultar em URLs expiradas. Mas seria
  útil salvar por sessão ou por um período curto.

IMPACTO:
  - Performance ruim: delay de resolução em toda abertura do post
  - Experiência inconsistente: funcionou ontem, hoje a API está lenta

COMO ARRUMAR (opção de cache em memória):
  Adicionar um cache estático na classe (ou num provider Riverpod) que
  guarda resolved URLs por post.id com timestamp. TTL sugerido: 2 horas.

    // Em social_embed_view.dart ou num provider separado:
    static final Map<String, (String url, DateTime resolvedAt)> _videoCache = {};

    Future<bool> _resolveTikTokVideoIfPossible() async {
      final postId = widget.post.id;
      final cached = _videoCache[postId];
      if (cached != null &&
          DateTime.now().difference(cached.$2).inHours < 2) {
        setState(() { _resolvedVideoUrl = cached.$1; });
        return true;
      }
      // ... resolve normalmente ...
      if (resolved != null) {
        _videoCache[postId] = (resolved, DateTime.now());
      }
      // ...
    }

PROBLEMA B — Posts TikTok que NÃO são vídeos mostram tela de erro
────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/widgets/social_embed_view.dart, linha 122-124
CÓDIGO:
  if (widget.post.platform == SocialPlatform.tiktok) {
    _hasError = true;
    return;
  }

PROBLEMA:
  Esse bloco é executado quando um post é TikTok MAS mediaType != video
  (por exemplo, imagens ou carousels de imagens do TikTok).
  Esses posts exibem imediatamente a tela de erro em vez de tentar
  carregar o embed do TikTok ou mostrar as imagens.

IMPACTO:
  Posts de imagem do TikTok sempre mostram "Não foi possível carregar".

COMO ARRUMAR:
  Substituir o bloco por uma tentativa de embed via oEmbed do TikTok,
  ou pelo menos mostrar o thumbnail do post. A URL de embed do TikTok
  para posts não-vídeo segue o padrão:
    https://www.tiktok.com/embed/v2/{video_id}
  Que funciona inclusive para imagens em alguns casos.

  Correção mínima (mostrar thumbnail):
    if (widget.post.platform == SocialPlatform.tiktok &&
        widget.post.mediaType != SocialMediaType.video) {
      // Tentar embed antes de desistir
      final embedUrl = _embedUrlFor(widget.post);
      if (embedUrl != null) {
        _controller.loadHtmlString(_buildEmbedHtml(widget.post, embedUrl: embedUrl));
      } else {
        setState(() { _hasError = true; });
      }
      return;
    }

PROBLEMA C — Player não faz autoplay após resolução
──────────────────────────────────────────────────────

ARQUIVO: lib/ui/widgets/social_native_video_player.dart, linha 42-51
PROBLEMA:
  Após inicialização do VideoPlayerController, o player fica parado.
  O usuário precisa tocar na tela para iniciar o vídeo.
  Para uma galeria de posts salvos, o comportamento esperado é autoplay
  ao abrir o post (similar ao TikTok nativo).

  Além disso, o controller não define .setLooping(true), então o vídeo
  para no final em vez de fazer loop (comportamento indesejado para TikTok).

IMPACTO:
  UX inferior ao comportamento esperado.

COMO ARRUMAR:
  Em initState(), após initialize():
    ..initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);   // ADICIONAR
      _controller.play();              // ADICIONAR autoplay
      setState(() => _initialized = true);
    })

  Observação: autoplay com som pode ser problemático dependendo do contexto.
  Considerar inicializar sem som (setVolume(0)) e dar ao usuário controle.

PROBLEMA D — Loader durante resolução não tem feedback de progresso
────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/widgets/social_embed_view.dart, método _buildResolvingVideo()
PROBLEMA:
  Quando _resolvingVideo = true, o widget chama _buildResolvingVideo() mas
  esse método não foi encontrado no código analisado (pode estar presente mas
  não visível no trecho). Se existir, verificar se mostra contexto adequado.
  O timeout é de 18 segundos — tempo suficiente para o usuário achar que
  travou se não houver feedback claro.

COMO ARRUMAR:
  Se _buildResolvingVideo() não existe ou é genérico, implementar:
    Widget _buildResolvingVideo() => SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Carregando vídeo...', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );

────────────────────────────────────────────────────────────────────────────────
3.3 O QUE FALTA PARA O PLAYER TIKTOK FICAR 100% FUNCIONAL
────────────────────────────────────────────────────────────────────────────────

STATUS ATUAL: O player funciona SE o usuário tem um servidor de resolução
configurado E o vídeo é do tipo 'video'. Para uso prático sem servidor
próprio, há opções públicas (ver abaixo).

ITENS PENDENTES POR PRIORIDADE:

  PRIORIDADE ALTA:
  [ ] Fix Problema B: TikTok imagens/carousels mostram erro → implementar
      tentativa de embed antes de desistir
  [ ] Fix Problema A: adicionar cache em memória para URLs resolvidas
      (evitar chamada a API a cada abertura do post)
  [ ] Autoplay + loop ao abrir o vídeo (Problema C)

  PRIORIDADE MÉDIA:
  [ ] Documentar para o usuário qual formato de servidor usar.
      Sugestões de APIs públicas/gratuitas:
      - tikwm.com API (gratuita, retorna download_addr)
        Endpoint: https://www.tikwm.com/api/?url={url}
        Chave 'download_addr' no JSON → já mapeada no resolver
      - SnapTik (tem API não oficial)
      - Instância local de yt-dlp via API (mais confiável)
  [ ] Adicionar botão "Abrir no TikTok" como fallback sempre visível
      mesmo quando o player nativo estiver funcionando
  [ ] Controle de volume no player nativo

  PRIORIDADE BAIXA:
  [ ] Salvar URL resolvida no frontmatter do post (com TTL) para eliminar
      o delay em sessões futuras (requer lógica de invalidação por data)
  [ ] Suporte a vídeos verticais 9:16 sem barras pretas laterais
      (o AspectRatio atual já lida com isso, mas testar com vídeos reais)
  [ ] Teste com CDN URLs que expiram rápido vs. CDN com URLs longas

COMO TESTAR SE ESTÁ FUNCIONANDO:
  1. Configurar endpoint em Settings
  2. Adicionar um post do TikTok (URL de vídeo) via Social
  3. Abrir o post → deve aparecer o player nativo em vez do WebView
  4. Se aparecer WebView, verificar: post.mediaType == 'video'? endpoint salvo?
  5. Logs: TikTokVideoResolver imprime 'TikTokVideoResolver failed' se falhar


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 4 — OUTROS BUGS ENCONTRADOS (ANÁLISE PROATIVA)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

────────────────────────────────────────────────────────────────────────────────
4.1 BUG — settings_screen tem textos em inglês misturados com PT-BR
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/screens/settings_screen.dart
OCORRÊNCIAS:
  - Linha 572: título 'Exact Alarm Permission' (deveria ser PT-BR)
  - Linha 588: botão 'Grant' (deveria ser 'Conceder')
  - Linha 625: 'Granted — popups show over lock screen' (inglês)
  - Linha 633: botão 'Grant' (deveria ser 'Conceder')
  - permission_service.dart, linha 120: AlertDialog em inglês inteiro
    ('Exact Alarm Permission', 'Schedule exact alarms', 'Later', 'Open Settings')

REGRA VIOLADA: guidelines.md seção 8.1 item 10: "Usar PT-BR em todos os
textos de UI"

COMO ARRUMAR:
  settings_screen.dart:
    'Exact Alarm Permission' → 'Permissão de Alarme Exato'
    'Full-Screen Intent' → 'Notificação em Tela Cheia'
    'Granted — alarms fire at exact times' → 'Concedida — alarmes disparam no horário exato'
    'Not granted — alarms may be delayed' → 'Não concedida — alarmes podem atrasar'
    'Granted — popups show over lock screen' → 'Concedida — popups aparecem sobre a tela de bloqueio'
    'Not granted — popups may not show on lock screen' → 'Não concedida — popups podem não aparecer'
    'Grant' → 'Conceder'

  permission_service.dart, showExactAlarmPermissionDialog():
    title: 'Exact Alarm Permission' → 'Permissão de Alarme Exato'
    content: (reescrever em PT-BR)
      'Para disparar alarmes e notificações popup no horário exato, '
      'o Citrine precisa da permissão "Agendar alarmes exatos".\n\n'
      'Você será levado às configurações do sistema.'
    'Later' → 'Depois'
    'Open Settings' → 'Abrir Configurações'

────────────────────────────────────────────────────────────────────────────────
4.2 AVISO — home_screen.dart tem 5 encoding errors mas 3 são em comentários
────────────────────────────────────────────────────────────────────────────────

LINHAS VISÍVEIS AO USUÁRIO (prioridade):
  - Linha 1320: hintText com travessão corrompido (visível no dashboard)
  - Linha 3017: separador de horário corrompido (visível no time block display)
  - Linha 3283: bullet corrompido entre data e hora (visível no planner)

LINHAS EM COMENTÁRIOS (baixa prioridade):
  - Linhas 253, 287: comentários de separador de seção (╴─╴─╴─ corrompidos)
    Não afetam UI, apenas leitura do código-fonte.

────────────────────────────────────────────────────────────────────────────────
4.3 INCONSISTÊNCIA — typeSignatures inclui 'shopping_item' (tipo legado)
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/providers/settings_provider.dart, linha 432-437
  'shopping_item': TypeSignature(
    objectType: 'shopping_item',
    markerType: MarkerType.folder,
    markerValue: 'shopping',
  ),

PROBLEMA:
  Conforme App Guidelines V4, Seção "Nota de implementação (2026-06-21)",
  shopping_item é um modelo DEPRECIADO. A fonte de verdade é ShoppingList
  (shopping_list_model.dart). Manter shopping_item em typeSignatures default
  significa que arquivos na pasta 'shopping/' ainda são reconhecidos como
  shopping_item (tipo legado), em vez de serem migrados.

  Além disso, a guidelines (Parte 21) diz explicitamente:
  "Object Identification deve sinalizar os dois coexistindo na mesma pasta
  como o mesmo tipo de conflito... até a migração ser concluída e
  type: shopping_item ser descontinuado."

  Mas não há lógica de detecção de conflito implementada atualmente.

IMPACTO: menor até que a migração de ShoppingList seja executada.
COMO ARRUMAR: após a migração dos dados, remover 'shopping_item' de
  _defaultSignatures() e do diálogo de Object Identification.

────────────────────────────────────────────────────────────────────────────────
4.4 AVISO — _sanitizeFileName não é usado consistentemente
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/services/markdown_parser.dart, linha 252-253
  String filename = object.type == 'resource'
      ? _sanitizeFileName(object.title)
      : object.slug;

PROBLEMA:
  Resources usam _sanitizeFileName (que preserva acentos, apenas remove
  caracteres ilegais em filesystem). Todos os outros tipos usam slug
  (que remove acentos). Inconsistência sem justificativa técnica.

SOLUÇÃO IDEAL:
  Todos os tipos deveriam usar _sanitizeFileName para gerar o nome do arquivo,
  e slug ser usado apenas para chaves YAML (habit completions, etc).
  Mas isso requer consideração sobre retrocompatibilidade — objetos existentes
  têm obsidianPath salvo e não seriam afetados, mas novos objetos ganhariam
  nomes de arquivo melhores.

────────────────────────────────────────────────────────────────────────────────
4.5 AVISO — setState() chamado em FutureBuilders de permissão (settings_screen)
────────────────────────────────────────────────────────────────────────────────

ARQUIVO: lib/ui/screens/settings_screen.dart, linhas 590 e 635
  onPressed: () async {
    await PermissionService.showExactAlarmPermissionDialog(context);
    setState(() {}); // Refresh status
  },

PROBLEMA:
  Chamar setState({}) em toda a tela de settings para "refresh" o status
  de permissão força rebuild de toda a tela (que é grande, ~2500 linhas).
  Isso pode causar flickering visível.

COMO ARRUMAR:
  Usar um ValueNotifier ou um provider simples para o status de permissão,
  e fazer ref.invalidate() apenas nos widgets de status. Ou ao menos usar
  um StatefulBuilder local ao redor dos FutureBuilders de permissão.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 5 — RESUMO DE PRIORIDADES PARA IMPLEMENTAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRIORIDADE 1 — BUGS VISÍVEIS AO USUÁRIO (implementar primeiro):

  [P1-A] ENCODING CORROMPIDO EM STRINGS DE UI
  Arquivo: lib/ui/screens/settings_screen.dart
  Linhas: 459, 467, 483, 497, 538, 580, 581, 625, 626
  Ação: substituição direta de string conforme tabela na Seção 2.2
  Risco: zero — só altera texto literal

  [P1-B] ENCODING CORROMPIDO EM HOME_SCREEN (strings visíveis)
  Arquivo: lib/ui/screens/home_screen.dart
  Linhas: 1320, 3017, 3283
  Ação: substituir os caracteres corrompidos pelos corretos (—, –, •)
  Risco: zero

  [P1-C] TEXTOS EM INGLÊS NA UI (settings_screen + permission_service)
  Arquivos: lib/ui/screens/settings_screen.dart, lib/services/permission_service.dart
  Ação: traduzir para PT-BR conforme lista na Seção 4.1
  Risco: zero

PRIORIDADE 2 — BUGS ESTRUTURAIS COM EFEITO PRÁTICO:

  [P2-A] SLUG DESTRÓI ACENTOS → nomes de arquivo e chaves YAML errados
  Arquivo: lib/models/content_object.dart, linha 102-107
  Ação: implementar mapa de transliteração antes do replaceAll
  Risco: MÉDIO — objetos existentes não são renomeados (compatível),
  mas novos objetos ganham nomes diferentes dos antigos se tiverem mesmo título

  [P2-B] IDEA SETTINGS DIALOG SEM EFEITO (ideaStrategy morto)
  Arquivo: lib/providers/settings_provider.dart, método setIdeaStrategy()
  Ação: adicionar chamada a updateTypeSignature('idea', ...) baseada na
  estratégia escolhida
  Risco: BAIXO — só afeta identificação de ideas

  [P2-C] TIKTOK IMAGENS/CAROUSELS MOSTRAM ERRO
  Arquivo: lib/ui/widgets/social_embed_view.dart, linha 122-124
  Ação: tentar embed antes de definir _hasError = true
  Risco: baixo

PRIORIDADE 3 — MELHORIAS DE UX E CONSISTÊNCIA:

  [P3-A] CACHE DE URLs RESOLVIDAS DO TIKTOK
  Arquivo: lib/ui/widgets/social_embed_view.dart
  Ação: implementar cache em memória com TTL de 2h para _resolvedVideoUrl

  [P3-B] AUTOPLAY + LOOP NO NATIVE VIDEO PLAYER
  Arquivo: lib/ui/widgets/social_native_video_player.dart, initState()
  Ação: adicionar _controller.setLooping(true) e _controller.play() após initialize()

  [P3-C] FOLDERPATH DIALOG SEM MIGRAÇÃO
  Arquivo: lib/ui/screens/settings_screen.dart, _showFolderPathsDialog()
  Ação: adicionar botão "Mover arquivos existentes" que executa migração

  [P3-D] TEXTOS EM PT-BR EM TODO O APP
  Ação: varredura geral por textos em inglês fora do esperado (nomes técnicos OK)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEÇÃO 6 — REFERÊNCIA RÁPIDA DE ARQUIVOS POR PROBLEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

lib/models/content_object.dart
  → Linha 102-107: slug getter — fix de transliteração de acentos (P2-A)

lib/services/markdown_parser.dart
  → Linha 252-253: filename usa slug para não-resources — inconsistência (Seção 4.4)
  → Linha 282-288: _sanitizeFileName — preserva acentos, só usado para resources

lib/providers/vault_provider.dart
  → Linha 1452-1509: allObjectsProvider — leitura soberana via typeSignatures ✓
  → Linha 2533-2710: _writeObject — escrita usa typeSignatures + folderPaths ✓
  → Linha 2359-2381: _signatureKeyFor + _defaultFolderForSignature ✓
  → Linha 74, 256+: habit slugs como chaves YAML — afetados pelo bug de slug (P2-A)

lib/providers/settings_provider.dart
  → Linha 430-505: _defaultSignatures() — base de typeSignatures
  → Linha 137: ideaTag default 'idea' deveria ser 'ideia' (Seção 1.3)
  → Linha 860-875: setIdeaStrategy() — não atualiza typeSignatures (P2-B)
  → Linha 805-815: updateFolderPath() — não migra arquivos (Seção 1.2)

lib/ui/screens/settings_screen.dart
  → Linha 459, 467, 483, 497, 538: encoding 'atí©' → 'até' (P1-A)
  → Linha 572-633: textos em inglês + encoding corrompido — permissões (P1-A + P1-C)
  → Linha 1538-1610: _showFolderPathsDialog() — sem migração de arquivos (P3-C)
  → Linha 1685-1760: _showIdeaSettingsDialog() — dialog morto (P2-B)

lib/ui/screens/home_screen.dart
  → Linha 1320, 3017, 3283: encoding corrompido visível ao usuário (P1-B)
  → Linhas 253, 287: encoding em comentários (baixa prioridade)

lib/ui/screens/type_signatures_screen.dart
  → Linha 185-245: _confirmAndMoveFolder() — modelo de migração correto ✓
  → Após salvar: ref.invalidate(allObjectsProvider) ✓

lib/ui/widgets/social_embed_view.dart
  → Linha 51: init de _resolvedVideoUrl a partir de post.videoUrl ✓
  → Linha 116-128: fluxo de decisão TikTok — bug de imagens (P2-C)
  → Linha 243-268: _resolveTikTokVideoIfPossible() — sem cache (P3-A)

lib/ui/widgets/social_native_video_player.dart
  → Linha 42-51: initState sem autoplay/loop (P3-B)
  → Linha 28-30: headers HTTP corretos para TikTok CDN ✓
  → Linha 163-167: _togglePlayback() ✓
  → Linha 169-171: _handlePlaybackError() ✓

lib/services/tiktok_video_resolver.dart
  → Implementação completa e sem bugs ✓
  → Linha 74-99: _findVideoUrl() busca recursiva no JSON ✓
  → Linha 101-112: _candidate() validação de URL ✓

lib/services/permission_service.dart
  → Linha 115-148: showExactAlarmPermissionDialog() — strings em inglês (P1-C)

================================================================================
FIM DO RELATÓRIO
=============================================================================================================================================
#  CITRINE — GUIA DE OTIMIZAÇÃO DE PERFORMANCE
  Foco: lentidão no startup e navegação geral
  Baseado em auditoria do código atual (junho 2026)
=============================================================

Este documento está organizado por impacto estimado (maior → menor).
Cada item explica O QUÊ mudar, POR QUÊ é lento, e COMO resolver.


══════════════════════════════════════════════════════════════
  BLOCO 1 — STARTUP (o app tarda pra abrir)
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
1.1  allObjectsProvider lê TODO o vault de uma vez no startup
     (arquivo: lib/providers/vault_provider.dart, classe AllObjectsNotifier.build())
──────────────────────────────────────────────

PROBLEMA:
  O método build() do AllObjectsNotifier faz o seguinte:
    1. Lista TODOS os arquivos .md do vault com getFilesInFolder('', recursive: true)
    2. Lê o conteúdo de CADA arquivo com readAsString()
    3. Faz parse de YAML frontmatter de cada um
    4. Instancia objetos Dart para cada um
    5. Deduplica, ordena, e monta o estado final

  Isso é executado de forma BLOQUEANTE (do ponto de vista da tela de splash)
  via Future.wait() no _initApp() em main.dart antes de qualquer UI aparecer.
  Se o vault tiver 500+ arquivos (tarefas, diários, hábitos, sociais, notas),
  isso pode levar vários segundos.

  Além disso, toda vez que qualquer objeto é salvo (addTask, toggleHabit etc.),
  o código chama ref.invalidate(allObjectsProvider) — ou seja, relê o vault
  INTEIRO de novo do disco. Há pelo menos 10 lugares no código que fazem isso.

POR QUÊ É LENTO:
  - I/O de disco é a operação mais lenta disponível (muito pior que RAM).
  - Mesmo com batches de 50 arquivos em paralelo, se você tem 300+ arquivos
    a leitura sequencial de batches demora (3x+ segundos em dispositivos médios).
  - A invalidação total a cada write força uma releitura completa mesmo quando
    só 1 arquivo mudou.

COMO RESOLVER:
  Etapa A — Não bloquear a splash screen esperando o vault completo:
    Em main.dart, no _initApp(), o Future.wait() espera 'vault_load' antes
    de liberar a UI. Remova 'vault_load' do Future.wait() e deixe o vault
    carregar em background. A HomeScreen já lida com o estado de loading
    (via AsyncValue) — use um skeleton/loading state lá em vez de segurar
    o splash.

  Etapa B — Invalidação cirúrgica em vez de total:
    Em vez de ref.invalidate(allObjectsProvider) após cada write, atualize
    diretamente a lista em memória. Os providers específicos (tasksProvider,
    habitsProvider etc.) já fazem isso corretamente — o problema é que eles
    TAMBÉM chamam invalidate(allObjectsProvider) por via indireta.

    Crie um método interno no AllObjectsNotifier:
      void patchObject(ContentObject updated) {
        // Substitui o objeto na lista em memória sem reler o disco
        if (state.hasValue) {
          final list = state.value!.toList();
          final idx = list.indexWhere((o) => o.id == updated.id);
          if (idx >= 0) list[idx] = updated;
          else list.add(updated);
          state = AsyncData(list);
        }
      }

    E em updateObject() / createObject() / deleteObject() do VaultNotifier,
    chame patchObject() em vez de invalidate(). Só invalide o provider completo
    quando for uma operação que afeta múltiplos arquivos (import, merge, etc.).

  Etapa C — Carregar apenas o necessário primeiro:
    Priorize carregar apenas os tipos usados na HomeScreen (tasks de hoje,
    hábitos de hoje, journal de hoje). Os demais tipos (social, trackers,
    snapshots, analyses) podem ser carregados sob demanda quando a tela
    correspondente é aberta. Isso requer separar o AllObjectsNotifier em
    provedores por pasta/tipo com lazy loading.


──────────────────────────────────────────────
1.2  obsidianServiceProvider é recriado a cada rebuild de settings
     (arquivo: lib/providers/vault_provider.dart, topo)
──────────────────────────────────────────────

PROBLEMA:
  O provider está declarado assim:
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final service = ObsidianService();
      final settings = ref.watch(settingsProvider);   // ← WATCH
      service.initVault(settings.vaultName, customPath: settings.vaultPath);
      return service;
    });

  Como usa ref.watch(settingsProvider), QUALQUER mudança nas settings
  (cor de acento, toggle de notificação, qualquer coisa) reconstrói o
  obsidianServiceProvider, criando uma nova instância de ObsidianService
  e re-inicializando o vault. Isso é desnecessário na maioria dos casos
  porque vaultName e vaultPath raramente mudam.

POR QUÊ É LENTO:
  - Recriar o ObsidianService dispara initVault() de novo,
    que verifica e cria pastas do vault.
  - Reconstruir o provider invalida automaticamente todos os providers que
    dependem dele, incluindo allObjectsProvider — o que força releitura total.

COMO RESOLVER:
  Use select() para escutar APENAS as propriedades relevantes:
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final vaultName = ref.watch(
        settingsProvider.select((s) => s.vaultName)
      );
      final vaultPath = ref.watch(
        settingsProvider.select((s) => s.vaultPath)
      );
      final service = ObsidianService();
      service.initVault(vaultName, customPath: vaultPath);
      return service;
    });

  Com isso, o provider só é recriado quando vaultName ou vaultPath mudam,
  não a cada mudança qualquer nas configurações.


──────────────────────────────────────────────
1.3  SettingsNotifier chama SharedPreferences.getInstance() em cada update
     (arquivo: lib/providers/settings_provider.dart)
──────────────────────────────────────────────

PROBLEMA:
  Cada método de update (updateAccentColor, updateAutoSync, etc.) faz:
    final prefs = await SharedPreferences.getInstance();

  SharedPreferences.getInstance() envolve um método nativo assíncrono.
  Embora seja cacheado internamente pelo plugin após a primeira chamada,
  chamar isto em cada update cria awaits desnecessários e código verboso.

COMO RESOLVER:
  O SettingsNotifier já recebe SharedPreferences no construtor (via
  sharedPreferencesProvider injetado no main). Guarde a referência:
    class SettingsNotifier extends StateNotifier<AppSettings> {
      final SharedPreferences _prefs;
      SettingsNotifier(SharedPreferences prefs)
          : _prefs = prefs,
            super(_buildFromPrefs(prefs));

      Future<void> updateAccentColor(String value) async {
        await _prefs.setString('accentColor', value);  // sem getInstance()
        state = state.copyWith(accentColor: value);
      }
      // ... todos os outros métodos idem
    }

  Isso elimina ~30 chamadas redundantes a getInstance().


──────────────────────────────────────────────
1.4  PeopleNotifier dispara AutomationService.checkPersonContacts no build()
     (arquivo: lib/providers/vault_provider.dart, classe PeopleNotifier)
──────────────────────────────────────────────

PROBLEMA:
  O build() do PeopleNotifier faz:
    if (people.isNotEmpty) {
      Future.microtask(
        () => AutomationService.checkPersonContacts(ref, people),
      );
    }

  O método checkPersonContacts (em automation_service.dart, linha 85)
  provavelmente itera por todas as pessoas e faz I/O ou lógica pesada.
  Isso é chamado toda vez que o provider é rebuilt — ou seja, toda vez
  que allObjectsProvider é invalidado (o que acontece com frequência).

COMO RESOLVER:
  Remova a chamada de checkPersonContacts do build().
  Em vez disso, chame-a explicitamente apenas quando:
    - A lista de pessoas muda de tamanho (nova pessoa adicionada)
    - O app é retomado (AppLifecycleState.resumed)
    - Uma vez por sessão no startup, via Future.microtask() no _initApp()

  No build(), retorne apenas a lista filtrada, sem side effects.


══════════════════════════════════════════════════════════════
  BLOCO 2 — LENTIDÃO AO NAVEGAR / ABRIR TELAS
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
2.1  Telas usam ref.watch(allObjectsProvider) direto em vez de providers específicos
     (arquivos: home_screen.dart e diversas telas)
──────────────────────────────────────────────

PROBLEMA:
  Várias telas observam allObjectsProvider e filtram os dados localmente.
  Quando allObjectsProvider é invalidado (o que acontece com frequência),
  TODAS essas telas são reconstruídas — mesmo que os dados relevantes pra
  aquela tela não tenham mudado.

COMO RESOLVER:
  Sempre use os providers específicos nas telas:
    - tasksProvider em vez de allObjectsProvider.filter(task)
    - habitsProvider em vez de allObjectsProvider.filter(habit)
    - notesProvider, goalsProvider, etc.

  Os providers específicos (TasksNotifier, HabitsNotifier etc.) já existem
  e mantêm estado em memória. A tela só será rebuilda quando o tipo
  específico dela mudar.


──────────────────────────────────────────────
2.2  backlinksProvider gera RegExp e itera por todos os objetos a cada chamada
     (arquivo: lib/providers/vault_provider.dart, backlinksProvider)
──────────────────────────────────────────────

PROBLEMA:
  O backlinksProvider faz:
    final content = obj.toMarkdown().toLowerCase();
    return targetKeys.any((key) => content.contains('[[$key]]') || ...);

  Isso chama toMarkdown() em TODOS os objetos do vault para cada objeto
  que está sendo exibido. Se você abre um detalhe e tem 300 objetos,
  300x toMarkdown() é chamado naquele momento.

COMO RESOLVER:
  Cache os backlinks calculados por objeto. Uma opção simples:
  - Adicione um campo opcional 'backlinks' ao ContentObject ou use um
    Map<String, List<String>> em memória no AllObjectsNotifier, populado
    uma única vez após o carregamento inicial.
  - Assim o backlinksProvider apenas consulta o cache em vez de recalcular.


──────────────────────────────────────────────
2.3  MyApp reconstrói os temas a cada rebuild porque parseia a cor inline
     (arquivo: lib/main.dart, classe MyApp)
──────────────────────────────────────────────

PROBLEMA:
  No build() do MyApp:
    theme: AppTheme.getLightTheme(
      Color(int.parse('ff' + settings.accentColor.replaceFirst('#', ''), radix: 16))
    ),

  Isso executa um parse de string e cria um objeto Color dentro do build().
  Se settingsProvider for rebuiltado por qualquer razão (o que acontece),
  o MaterialApp inteiro é reconstruído com um novo tema — causando um flash
  ou rebuild desnecessário.

COMO RESOLVER:
  Extraia a cor para uma variável local antes de usar, e use .select()
  para observar apenas accentColor:
    final accentHex = ref.watch(settingsProvider.select((s) => s.accentColor));
    final accentColor = Color(int.parse('ff${accentHex.replaceFirst('#', '')}', radix: 16));

  E coloque isso fora do build() em uma variável de estado, ou use
  um provider separado que só recalcula quando accentColor muda.


──────────────────────────────────────────────
2.4  TemplatesNotifier.build() chama _seedDefaultTemplates() via Future.microtask
     a cada rebuild
     (arquivo: lib/providers/vault_provider.dart, TemplatesNotifier)
──────────────────────────────────────────────

PROBLEMA:
  O build() verifica se a lista está vazia e enfileira seeding:
    if (list.isEmpty) {
      Future.microtask(() => _seedDefaultTemplates());
    }

  Como allObjectsProvider é invalidado com frequência, TemplatesNotifier
  é rebuiltado, e se os templates ainda não carregaram (estado transitório),
  _seedDefaultTemplates() pode ser chamado múltiplas vezes.
  O método interno já tem guarda (if templates.isNotEmpty return), mas o
  overhead de re-avaliar e agendar o microtask a cada rebuild existe.

COMO RESOLVER:
  Use uma flag de sessão ou _seeded no estado do Notifier para garantir
  que o seed só é disparado uma vez por sessão:
    bool _seeded = false;
    @override
    List<TemplateDefinition> build() {
      final list = ...;
      if (list.isEmpty && !_seeded) {
        _seeded = true;
        Future.microtask(() => _seedDefaultTemplates());
      }
      return list;
    }


══════════════════════════════════════════════════════════════
  BLOCO 3 — LENTIDÃO AO SALVAR / INTERAGIR
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
3.1  toggleHabit() cancela e reagenda 50 notificações a cada toggle
     (arquivo: lib/providers/vault_provider.dart, VaultNotifier._scheduleObjectReminders)
──────────────────────────────────────────────

PROBLEMA:
  O método _scheduleObjectReminders() e _cancelObjectReminders() fazem:
    for (int i = 0; i < 50; i++) {
      await NotificationService().cancelNotification(baseId + i);
    }

  Isso significa 50 chamadas assíncronas ao sistema de notificações A CADA
  vez que qualquer objeto é salvo ou atualizado. E _scheduleObjectReminders()
  é chamado dentro de _writeObject(), que é chamado por createObject,
  updateObject, e qualquer outro save.

POR QUÊ É LENTO:
  Chamadas nativas (cancelNotification) têm overhead de channel method call.
  50 awaits em sequência numa operação que o usuário percebe como síncrona
  (toggle de hábito) cria lag visível.

COMO RESOLVER:
  Reduza o loop de 50 para o número real de reminders do objeto:
    // Em vez de sempre 50:
    final maxSlots = max(object.reminders.length, 10);  // guarda mínimo razoável
    for (int i = 0; i < maxSlots; i++) { ... }

  Ou melhor: guarde quantos reminders foram agendados por objeto em
  SharedPreferences (uma entrada por objeto) e cancele apenas esse número.


──────────────────────────────────────────────
3.2  _writeObject() chama AutomationService.updateAllKPIs() após qualquer save
     de hábito, entry, note ou tracker
     (arquivo: lib/providers/vault_provider.dart, _shouldUpdateKpisAfterWrite)
──────────────────────────────────────────────

PROBLEMA:
  Após salvar um hábito, entrada de diário, nota ou tracker, o código dispara:
    Future.microtask(() => AutomationService.updateAllKPIs(ref));

  Se updateAllKPIs() relê o vault ou faz I/O para calcular KPIs de todos os
  objetos, isso é uma operação potencialmente cara sendo disparada toda vez
  que você togla um hábito ou salva um diário.

COMO RESOLVER:
  Adicione debounce ao updateAllKPIs. Em vez de chamar direto:
    Timer? _kpiDebounce;
    void _scheduleKpiUpdate() {
      _kpiDebounce?.cancel();
      _kpiDebounce = Timer(const Duration(seconds: 3), () {
        AutomationService.updateAllKPIs(ref);
      });
    }

  Assim, se você toglar 5 hábitos rapidamente, o KPI só é recalculado
  uma vez (3 segundos após o último toggle), não 5 vezes.


══════════════════════════════════════════════════════════════
  BLOCO 4 — QUALIDADE DE VIDA / PREVENÇÃO
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
4.1  Compilar em modo release para testes de performance
──────────────────────────────────────────────

OBSERVAÇÃO IMPORTANTE:
  Nunca teste performance em modo debug (flutter run sem flags).
  O modo debug tem overhead massivo do Dart VM + DevTools instrumentation
  que distorce a percepção de lentidão. Sempre use:
    flutter run --release
  ou instale o APK de release direto no dispositivo. Se o app ainda estiver
  lento em release, os problemas são reais (como os listados acima).


──────────────────────────────────────────────
4.2  Widgets reconstruídos desnecessariamente por falta de const
──────────────────────────────────────────────

PROBLEMA:
  Em diversas telas e widgets, componentes que não dependem de estado são
  construídos sem const. Por exemplo:
    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(...))
  na splash screen, e similares em cards e listas.

COMO RESOLVER:
  Adicione const a widgets estáticos onde possível. O Flutter reusa
  instâncias com const, eliminando rebuilds. Use o lint rule
  prefer_const_constructors para identificar candidatos automaticamente:
    flutter analyze --no-fatal-infos | grep prefer_const


──────────────────────────────────────────────
4.3  getFilesInFolder usa list(recursive: true) sem filtrar extensão no SO
     (arquivo: lib/services/obsidian_service.dart, linha ~189)
──────────────────────────────────────────────

PROBLEMA:
  O método lista TODOS os arquivos recursivamente e filtra .md no Dart:
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) { ... }  // sem filtro de extensão aqui
    }
  O filtro de extensão (.endsWith('.md')) é feito no AllObjectsNotifier,
  não no getFilesInFolder. Isso significa que arquivos de imagem, PDFs
  e outros em _attachments são lidos pelo stream antes de serem descartados.

COMO RESOLVER:
  Adicione filtro de extensão dentro do getFilesInFolder:
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.md')) {
        ...
      }
    }
  Isso reduz o trabalho de iteração do stream e a criação de objetos File
  desnecessários para cada arquivo de attachment.


──────────────────────────────────────────────
4.4  obsidianServiceProvider cria nova instância de ObsidianService a cada build
     (arquivo: lib/providers/vault_provider.dart)
──────────────────────────────────────────────

PROBLEMA (complementar ao 1.2):
  Mesmo após o fix do select(), o Provider<ObsidianService> cria uma nova
  instância a cada vez que é rebuilt. ObsidianService tem estado interno
  (_currentVaultName, vaultDir) que é perdido.

COMO RESOLVER:
  Use StateProvider ou um singleton manual para que a mesma instância de
  ObsidianService persista por toda a sessão:
    final _obsidianServiceInstance = ObsidianService();
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final vaultName = ref.watch(settingsProvider.select((s) => s.vaultName));
      final vaultPath = ref.watch(settingsProvider.select((s) => s.vaultPath));
      _obsidianServiceInstance.initVault(vaultName, customPath: vaultPath);
      return _obsidianServiceInstance;
    });

  Importante: initVault() já tem guarda contra reinicialização desnecessária
  (verifica _currentVaultName), então reusar a mesma instância é seguro.


══════════════════════════════════════════════════════════════
  PRIORIDADE SUGERIDA DE IMPLEMENTAÇÃO
══════════════════════════════════════════════════════════════

1. [ALTO IMPACTO, FÁCIL]  Item 1.2 — select() no obsidianServiceProvider
   → Evita recarregar o vault a cada mudança de settings. ~1h de trabalho.

2. [ALTO IMPACTO, FÁCIL]  Item 1.3 — Guardar _prefs no SettingsNotifier
   → Elimina awaits redundantes. ~30min de trabalho.

3. [ALTO IMPACTO, MÉDIO]  Item 1.1 Etapa A — Remover vault_load do Future.wait()
   → A splash some mais rápido; HomeScreen já tem skeleton. ~2h de trabalho.

4. [ALTO IMPACTO, MÉDIO]  Item 3.1 — Reduzir loop de 50 cancelamentos
   → Toggle de hábito fica perceptivelmente mais rápido. ~1h.

5. [MÉDIO IMPACTO, MÉDIO] Item 1.1 Etapa B — patchObject() em vez de invalidate()
   → Maior mudança arquitetural mas elimina a raiz do problema de releitura. ~4h.

6. [MÉDIO IMPACTO, FÁCIL] Item 2.3 — Cor do tema via select()
   → Evita rebuilds do MaterialApp. ~30min.

7. [MÉDIO IMPACTO, FÁCIL] Item 4.3 — Filtro .md dentro de getFilesInFolder
   → Menos objetos File criados na iteração. ~15min.

8. [MÉDIO IMPACTO, MÉDIO] Item 3.2 — Debounce no updateAllKPIs
   → Evita recalcular KPIs redundantemente. ~1h.

9. [BAIXO IMPACTO, FÁCIL] Item 2.4 — Flag _seeded no TemplatesNotifier
   → Evita microtasks redundantes. ~20min.

10.[BAIXO IMPACTO, FÁCIL] Item 1.4 — Remover checkPersonContacts do build()
   → Elimina side effect inesperado. ~30min.

=============================================================
  FIM DO DOCUMENTO
=============================================================

# 14-06-26
CITRINE — ESPECIFICAÇÕES TÉCNICAS COMPLETAS
> Documento único de referência para implementação.
> Cobre gaps do código atual + 4 features novas.
> Cada seção explica O QUÊ é, POR QUÊ existe, COMO funciona e COMO implementar.
> Código atual lido diretamente do repositório em junho/2026.
---
TOKENS DE DESIGN
```
primary     = #FFB000  (AppColors.primary)
info        = #3B82F6  (AppColors.info)
success     = #22C55E  (AppColors.habitGreen)
purple      = #8B5CF6  (AppColors.habitPurple)
warning     = #F59E0B  (AppColors.warning)
error       = #EF4444  (AppColors.error)
textMuted   = #9CA3AF  (AppColors.textMuted)
darkCard    = #22252F  (AppColors.darkCardFill)
divider     = #E5E7EB  (AppColors.divider)

cardDecoration → AppTheme.cardDecoration(context)    r=20, shadow suave
surfaceVariant → AppTheme.surfaceVariantColor(context)
textMuted      → AppTheme.textMutedColor(context)

Chips:         r=20, padding h:14 v:7
Badges inline: r=4,  padding h:6 v:2
Section label: 10px w700 letterSpacing:0.1em uppercase muted
Body text:     12–13px lineHeight:1.7
```
---
BLOCO A — INFRA E MODELOS
---
A1 — Sistema de Filtros Reutilizável (`saved_filter.dart`)
O que é: Um modelo de dados compartilhado que representa um filtro salvo pelo usuário. Usado por Notes, Resources, Habits, Tasks, Goals, People, Journal e Trackers. Hoje cada tela tem sua lógica de filtro hardcoded e incompatível com as demais — chips de "All/Text/Outline" em Notes, popups de sort em Resources, etc. Isso cria UX inconsistente e código duplicado.
Como funciona: Um `SavedFilter` contém uma lista de regras (`FilterRule`), configuração de sort, agrupamento e view mode. O usuário cria filtros via `FilterSortSheet` (ver B1), nomeia e salva. Os filtros salvos aparecem como chips horizontais em cada tela. Tocar num chip aplica todas as regras + sort + groupBy de uma vez.
Arquivos: `lib/models/saved_filter.dart` — CRIAR NOVO
```dart
enum SortField {
  manual, title, created, modified,
  rating, status, type, priority,
  deadline, streak, lastContact,
}

enum GroupField { none, type, status, organizer, tag, date }

enum FilterOperator { equals, contains, notEquals, greaterThan, lessThan, isEmpty }

enum ViewMode { grid, list, grouped, matrix }

class FilterRule {
  final String property;
  final FilterOperator op;
  final dynamic value;
  const FilterRule({required this.property, required this.op, required this.value});

  Map<String, dynamic> toJson() => {'property': property, 'op': op.name, 'value': value};
  factory FilterRule.fromJson(Map<String, dynamic> j) => FilterRule(
    property: j['property'], op: FilterOperator.values.byName(j['op']), value: j['value']);
}

class SavedFilter {
  final String id;
  final String name;
  final String targetType; // 'note'|'resource'|'habit'|'task'|'goal'|'person'|'journal_entry'|'tracker'|'*'
  final List<FilterRule> rules;
  final SortField sortBy;
  final bool sortAscending;
  final GroupField groupBy;
  final ViewMode viewMode;

  const SavedFilter({
    required this.id, required this.name, required this.targetType,
    this.rules = const [], this.sortBy = SortField.modified,
    this.sortAscending = false, this.groupBy = GroupField.none,
    this.viewMode = ViewMode.grid,
  });

  List<T> apply<T>(List<T> items) =>
    items.where((item) => rules.every((rule) => _matchesRule(item, rule))).toList();

  bool _matchesRule(dynamic item, FilterRule rule) {
    final val = _getProperty(item, rule.property);
    return switch (rule.op) {
      FilterOperator.equals      => val?.toString() == rule.value?.toString(),
      FilterOperator.notEquals   => val?.toString() != rule.value?.toString(),
      FilterOperator.contains    => val is List
          ? (rule.value is List
              ? (rule.value as List).any((v) => val.contains(v))
              : val.contains(rule.value))
          : val?.toString().toLowerCase().contains(rule.value?.toString().toLowerCase() ?? '') == true,
      FilterOperator.greaterThan => (val is num && rule.value is num) && val > rule.value,
      FilterOperator.lessThan    => (val is num && rule.value is num) && val < rule.value,
      FilterOperator.isEmpty     => val == null || (val is List && val.isEmpty) || (val is String && val.isEmpty),
    };
  }

  dynamic _getProperty(dynamic item, String prop) => switch (prop) {
    'noteType'        => item.noteType,
    'status'          => item.status?.name ?? item.stage?.name ?? item.state?.name,
    'tags'            => item.tags,
    'organizers'      => item.organizers?.map((o) => o.slug).toList(),
    'rating'          => item.rating,
    'resourceType'    => item.resourceType,
    'priority'        => item.priority?.name,
    'pinned'          => item.pinned,
    'archived'        => item.archived,
    'author'          => item.author,
    'category'        => item.category,
    'goalType'        => item.goalType?.name,
    'state'           => item.state?.name,
    'contactPriority' => item.contactPriority?.name,
    'moodSlug'        => item.moodSlug,
    _                 => null,
  };

  SavedFilter copyWith({
    String? name, List<FilterRule>? rules, SortField? sortBy,
    bool? sortAscending, GroupField? groupBy, ViewMode? viewMode,
  }) => SavedFilter(
    id: id, name: name ?? this.name, targetType: targetType,
    rules: rules ?? this.rules, sortBy: sortBy ?? this.sortBy,
    sortAscending: sortAscending ?? this.sortAscending,
    groupBy: groupBy ?? this.groupBy, viewMode: viewMode ?? this.viewMode,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'targetType': targetType,
    'rules': rules.map((r) => r.toJson()).toList(),
    'sortBy': sortBy.name, 'sortAscending': sortAscending,
    'groupBy': groupBy.name, 'viewMode': viewMode.name,
  };

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: j['id'], name: j['name'], targetType: j['targetType'],
    rules: (j['rules'] as List? ?? []).map((r) => FilterRule.fromJson(r as Map<String, dynamic>)).toList(),
    sortBy: SortField.values.byName(j['sortBy'] ?? 'modified'),
    sortAscending: j['sortAscending'] ?? false,
    groupBy: GroupField.values.byName(j['groupBy'] ?? 'none'),
    viewMode: ViewMode.values.byName(j['viewMode'] ?? 'grid'),
  );
}

class FilterProperty {
  final String key;
  final String label;
  final List<String>? allowedValues;
  const FilterProperty({required this.key, required this.label, this.allowedValues});
}

// Propriedades disponíveis por tela:
class NoteFilterProperties {
  static const all = [
    FilterProperty(key: 'noteType', label: 'Tipo', allowedValues: ['text', 'outline', 'collection']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'pinned', label: 'Fixado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class ResourceFilterProperties {
  static const all = [
    FilterProperty(key: 'resourceType', label: 'Tipo', allowedValues: ['Book', 'Podcast', 'Movie', 'Article', 'Course']),
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['toConsume', 'inProgress', 'completed', 'dropped']),
    FilterProperty(key: 'author', label: 'Autor'),
    FilterProperty(key: 'category', label: 'Categoria'),
    FilterProperty(key: 'rating', label: 'Rating'),
    FilterProperty(key: 'tags', label: 'Tags'),
  ];
}

class HabitFilterProperties {
  static const all = [
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TaskFilterProperties {
  static const all = [
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['idea','todo','inProgress','pending','finalized']),
    FilterProperty(key: 'priority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class GoalFilterProperties {
  static const all = [
    FilterProperty(key: 'state', label: 'Estado', allowedValues: ['active','completed','onHold','cancelled']),
    FilterProperty(key: 'goalType', label: 'Tipo', allowedValues: ['repeating','oneTime']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class PersonFilterProperties {
  static const all = [
    FilterProperty(key: 'contactPriority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class JournalFilterProperties {
  static const all = [
    FilterProperty(key: 'moodSlug', label: 'Mood'),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TrackerFilterProperties {
  static const all = [
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}
```
---
A2 — Settings Provider: novos campos
O que é: Os campos `userName`, `accentColor` e `savedFiltersRaw` ainda não existem em `AppSettings`. São necessários para saudação personalizada no Home, cor de destaque editável e persistência de filtros salvos.
Arquivo: `lib/providers/settings_provider.dart` — EDITAR
Adicionar ao modelo `AppSettings`:
```dart
final String? userName;
final String accentColor;               // hex '#FFB000'
final List<Map<String, dynamic>> savedFiltersRaw; // serializado como JSON list

// No construtor:
this.userName,
this.accentColor = '#FFB000',
this.savedFiltersRaw = const [],

// No copyWith:
String? userName, String? accentColor, List<Map<String, dynamic>>? savedFiltersRaw,
userName: userName ?? this.userName,
accentColor: accentColor ?? this.accentColor,
savedFiltersRaw: savedFiltersRaw ?? this.savedFiltersRaw,

// Helpers derivados (não persistidos, calculados):
List<SavedFilter> get savedFilters =>
    savedFiltersRaw.map((j) => SavedFilter.fromJson(j)).toList();

List<SavedFilter> filtersFor(String targetType) =>
    savedFilters.where((f) => f.targetType == targetType || f.targetType == '*').toList();
```
Adicionar ao `SettingsNotifier`:
```dart
Future<void> setUserName(String name) async {
  state = state.copyWith(userName: name.trim());
  await _persist();
}

Future<void> setAccentColor(String hex) async {
  state = state.copyWith(accentColor: hex);
  await _persist();
}

Future<void> upsertSavedFilter(SavedFilter filter) async {
  final list = state.savedFilters.toList();
  final idx = list.indexWhere((f) => f.id == filter.id);
  if (idx >= 0) list[idx] = filter; else list.add(filter);
  state = state.copyWith(savedFiltersRaw: list.map((f) => f.toJson()).toList());
  await _persist();
}

Future<void> deleteSavedFilter(String filterId) async {
  final list = state.savedFilters.where((f) => f.id != filterId).toList();
  state = state.copyWith(savedFiltersRaw: list.map((f) => f.toJson()).toList());
  await _persist();
}
```
Incluir `userName`, `accentColor`, `savedFiltersRaw` na leitura/escrita do SharedPreferences (JSON encode/decode da lista para `savedFiltersRaw`).
---
A3 — `extractHighlights` no MarkdownParser
O que é: Método estático que extrai citações/destaques (blockquotes `>`) de um body markdown ou Quill Delta. Necessário para a Resources Screen mostrar highlights do synopsis e para o Home mostrar a quote do dia. Hoje não existe — o campo `synopsis` é tratado como texto livre sem extração de highlights.
Arquivo: `lib/services/markdown_parser.dart` — EDITAR
```dart
class HighlightItem {
  final String text;
  final String? tag;   // extraído de '#palavra' no final da linha
  final String? date;  // extraído de 'YYYY-MM-DD' se presente
  const HighlightItem({required this.text, this.tag, this.date});
}

// Dentro de MarkdownParser:
static List<HighlightItem> extractHighlights(String markdown) {
  if (markdown.isEmpty) return [];
  final highlights = <HighlightItem>[];

  // Tentar Quill Delta primeiro
  final ops = tryParseDeltaOps(markdown);
  if (ops != null) {
    for (final op in ops) {
      final insert = op['insert'];
      final attrs  = op['attributes'];
      if (insert is String && attrs is Map &&
          (attrs['blockquote'] == true || attrs['quote'] == true)) {
        final text = insert.trim();
        if (text.isNotEmpty) highlights.add(HighlightItem(text: text));
      }
    }
    return highlights;
  }

  // Markdown plano: linhas que começam com '>'
  final lines = markdown.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('>')) continue;

    var text = line.replaceFirst(RegExp(r'^>\s*(\[!\w+\]\s*)?'), '').trim();
    if (text.isEmpty) continue;

    // Extrair tag inline: '…texto #tag' → tag separada
    String? tag;
    final tagMatch = RegExp(r'#(\w+)\s*$').firstMatch(text);
    if (tagMatch != null) {
      tag  = tagMatch.group(1);
      text = text.substring(0, tagMatch.start).trim();
    }

    // Extrair data YYYY-MM-DD se presente
    String? date;
    final dateMatch = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text);
    if (dateMatch != null) date = dateMatch.group(0);

    // Continuação multi-linha
    while (i + 1 < lines.length && lines[i + 1].trim().startsWith('>')) {
      i++;
      final cont = lines[i].trim().replaceFirst(RegExp(r'^>\s*'), '').trim();
      if (cont.isNotEmpty) text += ' $cont';
    }

    if (text.length > 5) highlights.add(HighlightItem(text: text, tag: tag, date: date));
  }
  return highlights;
}
```
---
A4 — Encoding UTF-8 nos serviços de arquivo
O que é: Bug crítico de dados. Os serviços `obsidian_service.dart`, `google_drive_sync_service.dart` e `backup_service.dart` não especificam encoding ao ler/escrever arquivos, então o Dart usa o encoding padrão do sistema. Em alguns dispositivos/ambientes isso resulta em caracteres portugueses corrompidos: `ç` vira `Ã§`, `ã` vira `Ã£`, `é` vira `Ã©`. Isso aparece visível no código-fonte do próprio `home_screen.dart` em comentários corrompidos.
Como resolver:
Em `obsidian_service.dart`:
```dart
import 'dart:convert' show utf8;

// ANTES:
await file.writeAsString(content);
final content = await file.readAsString();

// DEPOIS:
await file.writeAsString(content, encoding: utf8);
final content = await file.readAsString(encoding: utf8);
```
Em `google_drive_sync_service.dart`:
```dart
// Upload de conteúdo markdown:
final bytes = utf8.encode(markdownContent);
// Download:
final content = utf8.decode(responseBodyBytes);
```
Em `backup_service.dart`:
```dart
final jsonStr = jsonEncode(data);
await file.writeAsString(jsonStr, encoding: utf8);
// Leitura:
final raw = await file.readAsString(encoding: utf8);
```
Adicionar: Varrer o projeto por strings com `Ã§`, `Ã£`, `Ã©`, `Ã¢` e substituir pelos caracteres UTF-8 corretos. Ex: `'Descartar alteraÃ§Ãµes?'` → `'Descartar alterações?'`.
---
A5 — Badge Counts Provider
O que é: Provider derivado que calcula contagens de pendências para exibir como badges na bottom navigation. Hoje a nav não mostra nenhum indicador de urgência — o usuário não sabe que tem tasks vencidas ou inbox cheio sem abrir cada tela.
Arquivo: `lib/providers/badge_counts_provider.dart` — CRIAR NOVO
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vault_provider.dart';

final badgeCountsProvider = Provider<Map<String, int>>((ref) {
  final tasks      = ref.watch(tasksProvider);
  final people     = ref.watch(peopleProvider);
  final inboxItems = ref.watch(inboxProvider).valueOrNull ?? [];
  final now        = DateTime.now();

  final overdueTasks = tasks.where((t) =>
    t.stage?.name != 'finalized' &&
    t.deadline != null &&
    t.deadline!.isBefore(now)).length;

  final pendingContacts = people.where((p) => p.isDueForContact).length;
  final pendingInbox    = inboxItems.where((i) => !(i.isArchived ?? false)).length;

  return {
    'planner': overdueTasks,
    'people':  pendingContacts,
    'inbox':   pendingInbox,
    'total':   overdueTasks + pendingContacts + pendingInbox,
  };
});
```
---
A6 — Modelos de novas features
A6.1 — `Habit.isQuitting`
O que é: Campo booleano que marca um hábito como "de parar" — o objetivo é NÃO fazer, não fazer. Ex: parar de fumar, parar de roer unhas. Hoje esses hábitos são tratados igual a qualquer outro, aparecem no Planner e CalendarWidget com checkbox de marcar, o que é semanticamente errado.
Arquivo: `lib/models/habit_model.dart` — EDITAR
```dart
final bool isQuitting; // default: false

// No construtor, copyWith, toJson/fromJson:
'is_quitting': isQuitting,
isQuitting: j['is_quitting'] ?? false,
```
A6.2 — `TrackerField`: campos de alerta de saúde
O que é: Extensão do `TrackerField` existente para suportar alertas automáticos por campo. Necessário para o tracker de saúde (sono, cabelo, comida, cocô) mostrar indicadores visuais sem o usuário precisar interpretar os dados manualmente.
Arquivo: `lib/models/tracker_model.dart` — EDITAR
```dart
enum FieldAlertLevel { none, info, warning, critical }

// Em TrackerField, adicionar:
final FieldAlertLevel alertLevel;
final double? alertThreshold; // aciona alerta quando valor <= threshold
final String? alertNote;      // contexto explicativo (ex: "depende dos remédios")
final bool alwaysAlert;       // true = qualquer registro acende alerta (ex: buraco no cabelo)

// Serialização:
'alert_level':     alertLevel.name,
'alert_threshold': alertThreshold,
'alert_note':      alertNote,
'always_alert':    alwaysAlert,

// Deserialização:
alertLevel:     FieldAlertLevel.values.byName(j['alert_level'] ?? 'none'),
alertThreshold: (j['alert_threshold'] as num?)?.toDouble(),
alertNote:      j['alert_note'],
alwaysAlert:    j['always_alert'] ?? false,
```
A6.3 — `Tracker.isHealthTracker`
Arquivo: `lib/models/tracker_model.dart` — EDITAR
```dart
final bool isHealthTracker; // default: false

// Serialização:
'is_health_tracker': isHealthTracker,
isHealthTracker: j['is_health_tracker'] ?? false,
```
A6.4 — `Idea` (tipo novo)
O que é: Um tipo de objeto de primeiro nível para capturar ideias brutas antes de saber o que fazer com elas. Mais leve que uma Task (sem stage pipeline), mais estruturado que uma Note (tem horizonte de tempo, prioridade, conversão). Quando a ideia amadurece, é convertida em Task/Projeto/Goal/Note mantendo suas propriedades.
Arquivo: `lib/models/idea_model.dart` — CRIAR NOVO
```dart
enum IdeaStatus  { raw, developing, readyToAct, converted, dropped }
enum IdeaHorizon { now, soon, someday, noDeadline }

class Idea implements ContentObject {
  @override final String id;
  @override final String title;
  @override final DateTime? createdAt;
  @override final DateTime? updatedAt;
  @override final bool archived;
  @override final List<OrganizerReference> organizers;
  @override final List<String> tags;
  @override final String? color;
  @override final String? emoji;

  final String?       body;
  final IdeaStatus    status;
  final IdeaHorizon   horizon;
  final TaskPriority? priority;
  final DateTime?     targetDate;
  final String?       convertedToType; // 'task'|'project'|'goal'|'note'
  final String?       convertedToId;
  final List<String>  linkedSlugs;     // [[wiki-links]]

  const Idea({
    required this.id, required this.title,
    this.createdAt, this.updatedAt, this.archived = false,
    this.organizers = const [], this.tags = const [],
    this.color, this.emoji,
    this.body, this.status = IdeaStatus.raw,
    this.horizon = IdeaHorizon.someday,
    this.priority, this.targetDate,
    this.convertedToType, this.convertedToId,
    this.linkedSlugs = const [],
  });

  bool get isConverted => convertedToType != null;

  @override String get obsidianFileName => title;
  @override String get slug => id;

  Idea copyWith({
    String? title, String? body, IdeaStatus? status, IdeaHorizon? horizon,
    TaskPriority? priority, DateTime? targetDate, bool? archived,
    List<OrganizerReference>? organizers, List<String>? tags,
    String? color, String? emoji, List<String>? linkedSlugs,
    String? convertedToType, String? convertedToId, DateTime? updatedAt,
  }) => Idea(
    id: id, title: title ?? this.title,
    createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    organizers: organizers ?? this.organizers, tags: tags ?? this.tags,
    color: color ?? this.color, emoji: emoji ?? this.emoji,
    body: body ?? this.body, status: status ?? this.status,
    horizon: horizon ?? this.horizon, priority: priority ?? this.priority,
    targetDate: targetDate ?? this.targetDate,
    convertedToType: convertedToType ?? this.convertedToType,
    convertedToId: convertedToId ?? this.convertedToId,
    linkedSlugs: linkedSlugs ?? this.linkedSlugs,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body,
    'status': status.name, 'horizon': horizon.name,
    'priority': priority?.name, 'target_date': targetDate?.toIso8601String(),
    'archived': archived,
    'organizers': organizers.map((o) => o.toJson()).toList(),
    'tags': tags, 'color': color, 'emoji': emoji,
    'linked_slugs': linkedSlugs,
    'converted_to_type': convertedToType, 'converted_to_id': convertedToId,
    'created_at': createdAt?.toIso8601String(), 'updated_at': updatedAt?.toIso8601String(),
  };

  factory Idea.fromJson(Map<String, dynamic> j) => Idea(
    id: j['id'], title: j['title'] ?? '',
    body: j['body'], status: IdeaStatus.values.byName(j['status'] ?? 'raw'),
    horizon: IdeaHorizon.values.byName(j['horizon'] ?? 'someday'),
    priority: j['priority'] != null ? TaskPriority.values.byName(j['priority']) : null,
    targetDate: j['target_date'] != null ? DateTime.parse(j['target_date']) : null,
    archived: j['archived'] ?? false,
    organizers: (j['organizers'] as List? ?? [])
      .map((o) => OrganizerReference.fromJson(o as Map<String, dynamic>)).toList(),
    tags: List<String>.from(j['tags'] ?? []),
    color: j['color'], emoji: j['emoji'],
    linkedSlugs: List<String>.from(j['linked_slugs'] ?? []),
    convertedToType: j['converted_to_type'], convertedToId: j['converted_to_id'],
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
  );
}
```
A6.5 — `ShoppingList` e `ShoppingItem` (tipo novo)
O que é: Tipo de objeto dedicado para listas de compras. Separado de Note e Task porque tem requisitos únicos: captura ultra-rápida (Enter = próximo item), widget nativo Android com checkbox, agrupamento por categoria, marcação que "some" o item. Usar Note/collection ou Task para isso seria inferior em UX.
Arquivo: `lib/models/shopping_list_model.dart` — CRIAR NOVO
```dart
enum ShoppingItemStatus { active, checked, archived }

class ShoppingItem {
  final String id;
  final String name;
  final String? quantity;   // "2 kg", "1 caixa"
  final String? category;  // "Hortifruti", "Limpeza"
  final String? note;
  final ShoppingItemStatus status;
  final int order;

  const ShoppingItem({
    required this.id, required this.name,
    this.quantity, this.category, this.note,
    this.status = ShoppingItemStatus.active, this.order = 0,
  });

  bool get isChecked => status == ShoppingItemStatus.checked;

  ShoppingItem copyWith({
    String? name, String? quantity, String? category,
    String? note, ShoppingItemStatus? status, int? order,
  }) => ShoppingItem(
    id: id, name: name ?? this.name, quantity: quantity ?? this.quantity,
    category: category ?? this.category, note: note ?? this.note,
    status: status ?? this.status, order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'quantity': quantity,
    'category': category, 'note': note, 'status': status.name, 'order': order,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: j['id'], name: j['name'], quantity: j['quantity'],
    category: j['category'], note: j['note'],
    status: ShoppingItemStatus.values.byName(j['status'] ?? 'active'),
    order: j['order'] ?? 0,
  );
}

class ShoppingList implements ContentObject {
  @override final String id;
  @override final String title;
  @override final DateTime? createdAt;
  @override final DateTime? updatedAt;
  @override final bool archived;
  @override final List<OrganizerReference> organizers;
  @override final List<String> tags;
  @override final String? color;
  @override final String? emoji;

  final List<ShoppingItem> items;
  final bool hideChecked;

  @override String get obsidianFileName => title;
  @override String get slug => id;

  const ShoppingList({
    required this.id, required this.title,
    this.createdAt, this.updatedAt, this.archived = false,
    this.organizers = const [], this.tags = const [],
    this.color, this.emoji = '🛒',
    this.items = const [], this.hideChecked = true,
  });

  List<ShoppingItem> get activeItems =>
    items.where((i) => i.status == ShoppingItemStatus.active).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

  List<ShoppingItem> get checkedItems =>
    items.where((i) => i.status == ShoppingItemStatus.checked).toList();

  int get activeCount  => activeItems.length;
  int get checkedCount => checkedItems.length;
  int get totalCount   => items.where((i) => i.status != ShoppingItemStatus.archived).length;

  ShoppingList copyWith({
    String? title, List<ShoppingItem>? items, bool? hideChecked,
    bool? archived, List<OrganizerReference>? organizers,
    List<String>? tags, String? color, String? emoji, DateTime? updatedAt,
  }) => ShoppingList(
    id: id, title: title ?? this.title,
    createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    organizers: organizers ?? this.organizers, tags: tags ?? this.tags,
    color: color ?? this.color, emoji: emoji ?? this.emoji,
    items: items ?? this.items, hideChecked: hideChecked ?? this.hideChecked,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title,
    'items': items.map((i) => i.toJson()).toList(),
    'hide_checked': hideChecked, 'archived': archived,
    'organizers': organizers.map((o) => o.toJson()).toList(),
    'tags': tags, 'color': color, 'emoji': emoji,
    'created_at': createdAt?.toIso8601String(), 'updated_at': updatedAt?.toIso8601String(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: j['id'], title: j['title'],
    items: (j['items'] as List? ?? [])
      .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>)).toList(),
    hideChecked: j['hide_checked'] ?? true,
    archived: j['archived'] ?? false,
    organizers: (j['organizers'] as List? ?? [])
      .map((o) => OrganizerReference.fromJson(o as Map<String, dynamic>)).toList(),
    tags: List<String>.from(j['tags'] ?? []),
    color: j['color'], emoji: j['emoji'],
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
  );
}
```
---
A7 — Providers de novas features (`vault_provider.dart`)
O que é: Os novos tipos `Idea` e `ShoppingList` precisam de providers StateNotifier para CRUD e persistência, seguindo o mesmo padrão dos providers existentes.
Arquivo: `lib/providers/vault_provider.dart` — EDITAR
```dart
// ── Ideas ──────────────────────────────────────────────────────────────────
final ideasProvider = StateNotifierProvider<IdeasNotifier, List<Idea>>(
  (ref) => IdeasNotifier(ref));

class IdeasNotifier extends StateNotifier<List<Idea>> {
  IdeasNotifier(this._ref) : super([]) { _load(); }
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('ideas');
    if (raw != null) {
      state = (jsonDecode(raw) as List)
        .map((j) => Idea.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ideas', jsonEncode(state.map((i) => i.toJson()).toList()));
  }

  Future<void> addIdea(Idea idea)    async { state = [...state, idea]; await _persist(); }
  Future<void> updateIdea(Idea idea) async {
    state = state.map((i) => i.id == idea.id ? idea : i).toList();
    await _persist();
  }
  Future<void> deleteIdea(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _persist();
  }
  Future<void> archiveIdea(String id) async =>
    updateIdea(state.firstWhere((i) => i.id == id).copyWith(archived: true));
}

// ── Shopping Lists ──────────────────────────────────────────────────────────
final shoppingListsProvider = StateNotifierProvider<ShoppingListsNotifier, List<ShoppingList>>(
  (ref) => ShoppingListsNotifier(ref));

class ShoppingListsNotifier extends StateNotifier<List<ShoppingList>> {
  ShoppingListsNotifier(this._ref) : super([]) { _load(); }
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('shopping_lists');
    if (raw != null) {
      state = (jsonDecode(raw) as List)
        .map((j) => ShoppingList.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_lists',
      jsonEncode(state.map((l) => l.toJson()).toList()));
  }

  Future<void> addList(ShoppingList list)    async { state = [...state, list]; await _persist(); }
  Future<void> updateList(ShoppingList list) async {
    state = state.map((l) => l.id == list.id ? list : l).toList();
    await _persist();
    // Notificar widget nativo Android
    await _ref.read(widgetServiceProvider).updateShoppingWidget(list);
  }

  Future<void> addItem(String listId, ShoppingItem item) async {
    final list    = state.firstWhere((l) => l.id == listId);
    final updated = list.copyWith(
      items: [...list.items, item], updatedAt: DateTime.now());
    await updateList(updated);
  }

  Future<void> toggleItem(String listId, String itemId) async {
    final list  = state.firstWhere((l) => l.id == listId);
    final items = list.items.map((i) {
      if (i.id != itemId) return i;
      return i.copyWith(
        status: i.isChecked ? ShoppingItemStatus.active : ShoppingItemStatus.checked);
    }).toList();
    await updateList(list.copyWith(items: items, updatedAt: DateTime.now()));
  }

  Future<void> clearChecked(String listId) async {
    final list  = state.firstWhere((l) => l.id == listId);
    final items = list.items
      .where((i) => i.status != ShoppingItemStatus.checked).toList();
    await updateList(list.copyWith(items: items, updatedAt: DateTime.now()));
  }
}
```
Registrar `ideasProvider` no `allObjectsProvider` para que busca global e wiki-links funcionem.
---
A8 — Health Alerts Provider
O que é: Provider derivado que calcula automaticamente quais campos do tracker de saúde estão em estado de alerta. Não requer ação do usuário — é reativo e se atualiza quando novos registros são salvos.
Arquivo: `lib/providers/health_alerts_provider.dart` — CRIAR NOVO
```dart
class HealthAlert {
  final Tracker tracker;
  final TrackerField field;
  final double? lastValue;
  final DateTime? lastRecordDate;
  final int daysSinceLastRecord;
  final FieldAlertLevel level;
  final String message;

  const HealthAlert({
    required this.tracker, required this.field,
    required this.lastValue, required this.lastRecordDate,
    required this.daysSinceLastRecord, required this.level, required this.message,
  });
}

final healthAlertsProvider = Provider<List<HealthAlert>>((ref) {
  final trackers   = ref.watch(trackersProvider);
  final allRecords = ref.watch(trackingRecordsProvider);
  final now        = DateTime.now();
  final alerts     = <HealthAlert>[];

  for (final tracker in trackers.where((t) => t.isHealthTracker)) {
    for (final field in tracker.fields) {
      if (field.alertLevel == FieldAlertLevel.none && !field.alwaysAlert) continue;

      final fieldRecords = allRecords
        .where((r) => r.trackerId == tracker.id && r.fieldValues.containsKey(field.name))
        .toList()..sort((a, b) => b.date.compareTo(a.date));

      final last     = fieldRecords.isNotEmpty ? fieldRecords.first : null;
      final lastDate = last?.date;
      final lastVal  = last != null ? (last.fieldValues[field.name] as num?)?.toDouble() : null;
      final daysSince = lastDate != null
        ? now.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays
        : 999;

      FieldAlertLevel level = FieldAlertLevel.none;
      String message = '';

      if (field.alwaysAlert && last != null) {
        level   = FieldAlertLevel.critical;
        message = field.alertNote ?? 'Verificar ${field.name}';
      } else if (field.alertThreshold != null && lastVal != null && lastVal <= field.alertThreshold!) {
        level   = field.alertLevel;
        message = field.alertNote ?? '${field.name}: $lastVal (abaixo de ${field.alertThreshold})';
      } else if (daysSince >= 3 && field.alertLevel != FieldAlertLevel.none) {
        level   = FieldAlertLevel.warning;
        message = '${field.name}: sem registro há $daysSince dias';
      }

      if (level != FieldAlertLevel.none) {
        alerts.add(HealthAlert(
          tracker: tracker, field: field, lastValue: lastVal,
          lastRecordDate: lastDate, daysSinceLastRecord: daysSince,
          level: level, message: message));
      }
    }
  }

  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
  return alerts;
});
```

---
BLOCO B — WIDGETS REUTILIZÁVEIS
---
B1 — FilterSortSheet
O que é: Bottom sheet unificado de filtros, ordenação, agrupamento e modo de visualização. Hoje cada tela tem sua própria lógica de filtro (chips hardcoded em Notes, popup de sort em Resources, etc.). O `FilterSortSheet` substitui tudo isso com uma interface consistente e filtros que o usuário pode nomear e reutilizar.
UX: Abre via botão `Icons.tune_rounded` na AppBar de qualquer tela. Altura inicial 75% da tela, expansível até 95%. Tem 5 seções: Meus Filtros (chips dos filtros salvos), Filtrar Por (regras dinâmicas), Ordenar, Agrupar e Visualização. Footer com Limpar e Aplicar. Long-press num filtro salvo → deletar.
Arquivo: `lib/ui/widgets/filter_sort_sheet.dart` — CRIAR NOVO
```dart
class FilterSortSheet extends ConsumerStatefulWidget {
  final String targetType;
  final SavedFilter? currentFilter;
  final List<FilterProperty> availableProperties;
  final ValueChanged<SavedFilter?> onApply;

  const FilterSortSheet({
    super.key, required this.targetType, required this.currentFilter,
    required this.availableProperties, required this.onApply,
  });

  static Future<void> show({
    required BuildContext context, required WidgetRef ref,
    required String targetType, required SavedFilter? currentFilter,
    required List<FilterProperty> availableProperties,
    required ValueChanged<SavedFilter?> onApply,
  }) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => FilterSortSheet(
            targetType: targetType, currentFilter: currentFilter,
            availableProperties: availableProperties,
            onApply: (f) { Navigator.pop(ctx); onApply(f); }))));
  }

  @override
  ConsumerState<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends ConsumerState<FilterSortSheet> {
  late SavedFilter _draft;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter ?? SavedFilter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Novo filtro', targetType: widget.targetType);
    _nameController.text = _draft.name;
  }

  @override void dispose() { _nameController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(settingsProvider).filtersFor(widget.targetType);
    return Column(children: [
      // Handle bar
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(color: AppTheme.dividerColor(context),
          borderRadius: BorderRadius.circular(2))),
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          const Text('Filtrar & Ordenar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context)),
        ])),
      const Divider(),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        // ── Filtros salvos ──
        _section('MEUS FILTROS', child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ...saved.map(_savedChip),
            _addSavedChip(),
          ]))),
        // ── Regras ──
        _section('FILTRAR POR', child: Column(children: [
          ..._draft.rules.asMap().entries.map((e) => _ruleRow(e.key, e.value)),
          ListTile(
            leading: Icon(Icons.add_circle_outline_rounded, color: AppColors.info, size: 18),
            title: Text('Adicionar filtro', style: TextStyle(
              fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600)),
            onTap: _addRule, dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4)),
        ])),
        // ── Ordenar ──
        _section('ORDENAR POR', child: Column(children: [
          _dropdownRow(SortField.values.map((f) => f.name).toList(),
            _draft.sortBy.name, (val) => setState(() =>
              _draft = _draft.copyWith(sortBy: SortField.values.byName(val)))),
          const SizedBox(height: 8),
          Row(children: [
            _directionBtn('↓ Mais recente', false),
            const SizedBox(width: 8),
            _directionBtn('↑ Mais antigo', true),
          ]),
        ])),
        // ── Agrupar ──
        _section('AGRUPAR POR', child: _dropdownRow(
          GroupField.values.map((f) => f.name).toList(), _draft.groupBy.name,
          (val) => setState(() =>
            _draft = _draft.copyWith(groupBy: GroupField.values.byName(val))))),
        // ── Visualização ──
        _section('VISUALIZAÇÃO', child: Row(children: [
          _viewBtn('⊞ Grade', ViewMode.grid),
          const SizedBox(width: 8),
          _viewBtn('☰ Lista', ViewMode.list),
          const SizedBox(width: 8),
          _viewBtn('§ Grupos', ViewMode.grouped),
        ])),
      ]))),
      // Footer
      const Divider(height: 1),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16,
          10 + MediaQuery.of(context).viewInsets.bottom),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: _clear, child: const Text('Limpar'))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: FilledButton(onPressed: _apply, child: const Text('Aplicar'))),
        ])),
    ]);
  }

  Widget _section(String label, {required Widget child}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
      const SizedBox(height: 8), child, const SizedBox(height: 4),
    ]));

  Widget _savedChip(SavedFilter f) {
    final isActive = _draft.id == f.id;
    return GestureDetector(
      onTap: () => setState(() => _draft = f),
      onLongPress: () => _deleteFilter(f),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(20)),
        child: Text(f.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: isActive ? AppColors.primary : AppTheme.textSecondaryColor(context)))));
  }

  Widget _addSavedChip() => GestureDetector(
    onTap: _promptSaveCurrent,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20)),
      child: Text('＋ Salvar atual',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info))));

  Widget _ruleRow(int index, FilterRule rule) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: DropdownButtonFormField<String>(
        value: widget.availableProperties.any((p) => p.key == rule.property) ? rule.property : null,
        decoration: _inputDec('Propriedade'),
        items: widget.availableProperties.map((p) => DropdownMenuItem(
          value: p.key, child: Text(p.label, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: val, op: rules[index].op, value: '');
          setState(() => _draft = _draft.copyWith(rules: rules));
        })),
      const SizedBox(width: 6),
      SizedBox(width: 80, child: DropdownButtonFormField<FilterOperator>(
        value: rule.op, decoration: _inputDec('Op.'),
        items: [FilterOperator.equals, FilterOperator.notEquals,
                FilterOperator.contains, FilterOperator.isEmpty]
          .map((op) => DropdownMenuItem(value: op,
            child: Text(_opLabel(op), style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: rule.property, op: val, value: rule.value);
          setState(() => _draft = _draft.copyWith(rules: rules));
        })),
      const SizedBox(width: 6),
      if (rule.op != FilterOperator.isEmpty)
        Expanded(child: _valueField(rule, index))
      else const Expanded(child: SizedBox.shrink()),
      GestureDetector(
        onTap: () {
          final rules = _draft.rules.toList()..removeAt(index);
          setState(() => _draft = _draft.copyWith(rules: rules));
        },
        child: Padding(padding: const EdgeInsets.all(8),
          child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error))),
    ]));

  Widget _valueField(FilterRule rule, int index) {
    final prop = widget.availableProperties.firstWhere(
      (p) => p.key == rule.property,
      orElse: () => FilterProperty(key: rule.property, label: rule.property));
    if (prop.allowedValues != null) {
      return DropdownButtonFormField<String>(
        value: prop.allowedValues!.contains(rule.value) ? rule.value as String : null,
        decoration: _inputDec('Valor'),
        items: prop.allowedValues!.map((v) => DropdownMenuItem(
          value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: rule.property, op: rule.op, value: val);
          setState(() => _draft = _draft.copyWith(rules: rules));
        });
    }
    return TextFormField(
      initialValue: rule.value?.toString() ?? '',
      decoration: _inputDec('Valor'),
      style: const TextStyle(fontSize: 12),
      onChanged: (val) {
        final rules = _draft.rules.toList();
        rules[index] = FilterRule(property: rule.property, op: rule.op, value: val);
        setState(() => _draft = _draft.copyWith(rules: rules));
      });
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    isDense: true);

  Widget _dropdownRow(List<String> options, String current, ValueChanged<String> onChange) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: current, isExpanded: true,
        items: options.map((o) => DropdownMenuItem(
          value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (val) { if (val != null) onChange(val); })));

  Widget _directionBtn(String label, bool ascending) {
    final active = _draft.sortAscending == ascending;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(sortAscending: ascending)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppTheme.surfaceVariantColor(context),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primary : AppTheme.textSecondaryColor(context)))))));
  }

  Widget _viewBtn(String label, ViewMode mode) {
    final active = _draft.viewMode == mode;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(viewMode: mode)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppTheme.surfaceVariantColor(context),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primary : AppTheme.textSecondaryColor(context)))))));
  }

  void _addRule() {
    final prop = widget.availableProperties.first;
    setState(() => _draft = _draft.copyWith(
      rules: [..._draft.rules, FilterRule(property: prop.key, op: FilterOperator.equals, value: '')]));
  }

  void _clear() => setState(() => _draft = SavedFilter(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: 'Todos', targetType: widget.targetType));

  void _apply() {
    final isBlank = _draft.rules.isEmpty &&
      _draft.groupBy == GroupField.none && _draft.sortBy == SortField.modified;
    widget.onApply(isBlank ? null : _draft);
  }

  void _promptSaveCurrent() async {
    _nameController.text = _draft.name;
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar filtro'),
        content: TextField(controller: _nameController, autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome do filtro')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ]));
    if (confirmed != true) return;
    final toSave = _draft.copyWith(name: _nameController.text.trim());
    await ref.read(settingsProvider.notifier).upsertSavedFilter(toSave);
    setState(() => _draft = toSave);
  }

  void _deleteFilter(SavedFilter f) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${f.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir')),
        ]));
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).deleteSavedFilter(f.id);
      if (_draft.id == f.id) _clear();
    }
  }

  String _opLabel(FilterOperator op) => switch (op) {
    FilterOperator.equals      => '=',
    FilterOperator.notEquals   => '≠',
    FilterOperator.contains    => 'contém',
    FilterOperator.greaterThan => '>',
    FilterOperator.lessThan    => '<',
    FilterOperator.isEmpty     => 'vazio',
  };
}
```
Padrão de uso em qualquer tela:
```dart
// Estado:
SavedFilter? _activeFilter;
List<SavedFilter> _savedFilters = [];

// initState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('TIPO'));
});

// Abrir painel:
void _openFilterSheet() => FilterSortSheet.show(
  context: context, ref: ref,
  targetType: 'TIPO',
  currentFilter: _activeFilter,
  availableProperties: TIPOFilterProperties.all,
  onApply: (f) => setState(() {
    _activeFilter = f;
    _savedFilters = ref.read(settingsProvider).filtersFor('TIPO');
  }));

// Chips dinâmicos (substituem qualquer chip hardcoded):
Widget _buildFilterChips() => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(children: [
    _chip('Todos', _activeFilter == null, () => setState(() => _activeFilter = null)),
    ..._savedFilters.map((f) => _chip(f.name, _activeFilter?.id == f.id,
      () => setState(() => _activeFilter = f))),
    GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20)),
        child: Text('+ filtro', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info)))),
  ]));

Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? AppColors.primary : AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: selected ? Colors.black : AppTheme.textSecondaryColor(context)))));

// Filtragem + sort unificados:
List<T> _applyFilterAndSort<T>(List<T> all) {
  var result = (_activeFilter?.apply(all) ?? all).where((item) =>
    _searchQuery.isEmpty ||
    (item as dynamic).title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  final sort = _activeFilter?.sortBy ?? SortField.modified;
  final asc  = _activeFilter?.sortAscending ?? false;
  result.sort((a, b) {
    final cmp = switch (sort) {
      SortField.title    => (a as dynamic).title.compareTo((b as dynamic).title),
      SortField.created  => ((a as dynamic).createdAt ?? DateTime(0))
                              .compareTo((b as dynamic).createdAt ?? DateTime(0)),
      SortField.modified => ((a as dynamic).updatedAt ?? DateTime(0))
                              .compareTo((b as dynamic).updatedAt ?? DateTime(0)),
      SortField.manual   => ((a as dynamic).order ?? 0).compareTo((b as dynamic).order ?? 0),
      SortField.priority => ((a as dynamic).priority?.index ?? 0)
                              .compareTo((b as dynamic).priority?.index ?? 0),
      SortField.rating   => ((a as dynamic).rating ?? 0).compareTo((b as dynamic).rating ?? 0),
      _ => 0,
    };
    return asc ? cmp : -cmp;
  });
  return result;
}
```
---
B2 — SkeletonList
O que é: Widget de loading animado (shimmer) para substituir telas em branco enquanto os providers carregam dados. Hoje só o Dashboard tem skeleton — as demais telas mostram branco ou nada.
UX: Exibe N cards cinza com animação de fade (opacity 0.35→0.85 em loop de 1.2s). Quando o provider retorna dados, substitui automaticamente pela lista real sem layout shift perceptível.
Arquivo: `lib/ui/widgets/skeleton_list.dart` — CRIAR NOVO
```dart
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const SkeletonList({
    super.key, this.itemCount = 5, this.itemHeight = 72,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 100),
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding, itemCount: itemCount,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (ctx, i) => _SkeletonCard(height: itemHeight));
}

class _SkeletonCard extends StatefulWidget {
  final double height;
  const _SkeletonCard({required this.height});
  @override State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween(begin: 0.35, end: 0.85)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: widget.height,
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Opacity(opacity: _anim.value,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _line(context, 140, 13), const SizedBox(height: 12),
          _line(context, double.infinity, 11), const SizedBox(height: 8),
          _line(context, 180, 11),
        ]))));

  Widget _line(BuildContext context, double width, double height) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(6)));
}
```
Uso: Em telas com `AsyncValue`:
```dart
return notesAsync.when(
  data:    (notes)  => _buildList(notes),
  loading: ()       => const SkeletonList(),
  error:   (e, _)   => Center(child: Text('Erro: $e')));
```
---
B3 — HealthAlertsStrip
O que é: Widget reutilizável que exibe alertas do tracker de saúde. Versão compacta (scroll horizontal) para o dashboard. Versão expandida (lista vertical) para a aba Hoje dos hábitos. Aparece apenas quando há alertas — se tudo estiver bem, não ocupa espaço.
UX: Cada card de alerta tem cor semafórica (🚨 vermelho crítico, ⚠️ amarelo aviso, ℹ️ azul info), nome do campo, mensagem e botão "Registrar" que abre `CreateRecordForm` pré-selecionado. O campo `alertNote` (ex: "cabelo = alerta vermelho sempre") aparece em itálico abaixo da mensagem como contexto.
Arquivo: `lib/ui/widgets/health_alerts_strip.dart` — CRIAR NOVO
```dart
class HealthAlertsStrip extends ConsumerWidget {
  final bool compact;
  const HealthAlertsStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(healthAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    if (compact) {
      // Versão horizontal para dashboard
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => _AlertCard(alert: alerts[i], compact: true)));
    }

    // Versão expandida para HabitsScreen
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('SAÚDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
          const Spacer(),
          Text('${alerts.length} alerta${alerts.length == 1 ? "" : "s"}',
            style: const TextStyle(fontSize: 11, color: AppColors.warning)),
        ])),
      ...alerts.map((a) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _AlertCard(alert: a, compact: false))),
    ]);
  }
}

class _AlertCard extends ConsumerWidget {
  final HealthAlert alert;
  final bool compact;
  const _AlertCard({required this.alert, required this.compact});

  Color get _color => switch (alert.level) {
    FieldAlertLevel.critical => AppColors.error,
    FieldAlertLevel.warning  => AppColors.warning,
    FieldAlertLevel.info     => AppColors.info,
    FieldAlertLevel.none     => AppColors.textMuted,
  };

  String get _icon => switch (alert.level) {
    FieldAlertLevel.critical => '🚨',
    FieldAlertLevel.warning  => '⚠️',
    FieldAlertLevel.info     => 'ℹ️',
    FieldAlertLevel.none     => '•',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(child: Text(alert.field.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
          ]),
          const SizedBox(height: 4),
          Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor(context))),
        ]));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.25))),
      child: Row(children: [
        Text(_icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${alert.tracker.title} · ${alert.field.name}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
          const SizedBox(height: 2),
          Text(alert.message,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
          if (alert.field.alertNote != null) ...[
            const SizedBox(height: 3),
            Text(alert.field.alertNote!, style: TextStyle(fontSize: 10,
              color: AppTheme.textMutedColor(context), fontStyle: FontStyle.italic)),
          ],
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateRecordForm(preselectedTracker: alert.tracker)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Registrar', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _color)))),
      ]));
  }
}
```

---
BLOCO C — TELAS EXISTENTES: BUGS E MELHORIAS
---
C1 — Notes Screen
O que é: Tela de listagem de notas. Hoje usa filtros hardcoded (`['All','Text','Outline','Collection']`), modo de visualização único (lista reordenável) e a expansão de notas Outline/Collection não funciona — ao tocar no ícone de expandir, nada acontece.
Bugs a corrigir:
Expandir nota tipo Outline ou Collection não exibe nada. O código atual só renderiza editor para `noteType == 'text'`.
`_formatDate()` exibe hora sem zero-pad: "9:05" em vez de "09:05".
Chips de filtro hardcoded, sem possibilidade de salvar filtros personalizados.
UX nova:
AppBar: botão de toggle view (⊞ grid / ☰ lista) + botão `Icons.tune_rounded` abre FilterSortSheet
Chips dinâmicos (ver padrão B1) substituem `['All','Text','Outline','Collection']`
View Grid: `SliverGrid` 2 colunas, cards com emoji do tipo (📝 text, 🌿 outline, 🔮 collection), badge colorido de tipo (azul=text, verde=outline, roxo=collection), data modificada
View Grouped: seções por `groupBy` do filtro ativo, cada seção com header colapsável e pin lateral colorido
Arquivo: `lib/ui/screens/notes_screen.dart`
```dart
// Estado adicional:
enum NoteViewMode { grid, grouped }
NoteViewMode _viewMode = NoteViewMode.grid;
SavedFilter? _activeFilter;
List<SavedFilter> _savedFilters = [];

// Fix _formatDate:
String _formatDate(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  }
  return '${date.day}/${date.month}';
}

// Fix expandir Outline/Collection — no _buildNoteItem existente,
// APÓS: if (isExpanded && note.noteType == 'text') RichTextEditor(...)
// ADICIONAR:
else if (isExpanded && note.noteType == 'outline')
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: OutlineEditor(
      items: note.outlineItems ?? [],
      onChanged: (items) {
        final updated = note.copyWith(outlineItems: items, updatedAt: DateTime.now());
        ref.read(vaultProvider.notifier).updateObject(updated);
      }))
else if (isExpanded && note.noteType == 'collection')
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: CollectionView(note: note))

// Grid view — substituir SliverReorderableList quando _viewMode == NoteViewMode.grid:
SliverPadding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  sliver: SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 10,
      mainAxisSpacing: 10, childAspectRatio: 1.05),
    delegate: SliverChildBuilderDelegate(
      (ctx, i) => _buildGridCard(ctx, filtered[i]),
      childCount: filtered.length)))

// _buildGridCard:
Widget _buildGridCard(BuildContext context, dynamic note) {
  final (_, color, label) = _noteTypeAssets(note);
  return ObjectActionWrapper(object: note,
    child: InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: note))),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_noteEmoji(note), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Row(children: [
            _typeBadge(label, color),
            const Spacer(),
            Text(_formatDate(note.updatedAt ?? note.createdAt),
              style: TextStyle(fontSize: 9, color: AppTheme.textMutedColor(context))),
          ]),
        ]))));
}

String _noteEmoji(dynamic note) => switch (note.noteType) {
  'outline' => '🌿', 'collection' => '🔮', _ => '📝' };

(IconData, Color, String) _noteTypeAssets(dynamic note) => switch (note.noteType) {
  'outline'    => (Icons.account_tree_outlined, AppColors.habitGreen, 'Outline'),
  'collection' => (Icons.grid_view_rounded, AppColors.habitPurple, 'Collection'),
  _            => (Icons.description_outlined, AppColors.info, 'Text'),
};

Widget _typeBadge(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
  child: Text(label, style: TextStyle(
    fontSize: 9, fontWeight: FontWeight.w700, color: color)));
```
---
C2 — Resources Screen
O que é: Tela de listagem de recursos (livros, podcasts, filmes, artigos). Hoje é um grid simples sem nenhuma visualização de highlights. O `synopsis` de cada resource pode conter blockquotes com citações, mas elas nunca são exibidas.
UX nova:
View A — Shelf + Highlights (padrão): prateleira horizontal de capas no topo (últimos 8) + feed de highlights extraídos do `synopsis` via `extractHighlights`
View B — Lista: lista compacta com capa pequena e primeiro highlight inline
Chips dinâmicos + FilterSortSheet substituem botões de display/sort separados
Arquivo: `lib/ui/screens/resources_screen.dart`
```dart
enum ResourceViewMode { shelfHighlights, listHighlights }
ResourceViewMode _resourceViewMode = ResourceViewMode.shelfHighlights;

// Layout principal quando shelfHighlights:
SliverToBoxAdapter(child: _buildShelf(filtered)),
SliverToBoxAdapter(child: _buildHighlightsFeed(filtered)),

Widget _buildShelf(List<Resource> resources) => Column(
  crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,6),
      child: Text('RECENTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.10, color: AppTheme.textMutedColor(context)))),
    SizedBox(height: 108, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: resources.take(8).length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (ctx, i) => _buildShelfItem(ctx, resources.take(8).toList()[i]))),
  ]);

Widget _buildShelfItem(BuildContext context, Resource resource) =>
  GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => UniversalDetailView(object: resource))),
    child: SizedBox(width: 72, child: Column(children: [
      Container(
        width: 72, height: 72, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: AppColors.surfaceVariant),
        child: resource.coverImage?.isNotEmpty == true
          ? Image.network(resource.coverImage!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(resource))
          : _fallbackIcon(resource)),
      const SizedBox(height: 4),
      Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
      Text(resource.author ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 8, color: AppTheme.textMutedColor(context))),
    ])));

Widget _fallbackIcon(Resource r) {
  final emoji = switch (r.resourceType.toLowerCase()) {
    'book' || 'livro' => '📗', 'podcast' => '🎙️',
    'movie' || 'filme' => '🎬', 'article' => '📄', _ => '📚',
  };
  return Container(color: AppColors.surfaceVariant,
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))));
}

Widget _buildHighlightsFeed(List<Resource> resources) {
  final highlights = <({Resource r, String text, String? tag})>[];
  for (final r in resources) {
    if (r.synopsis == null || r.synopsis!.isEmpty) continue;
    final hls = MarkdownParser.extractHighlights(r.synopsis!);
    highlights.addAll(hls.take(2).map((h) => (r: r, text: h.text, tag: h.tag)));
  }
  if (highlights.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
      child: Text('✨ HIGHLIGHTS RECENTES', style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 0.10,
        color: AppTheme.textMutedColor(context)))),
    ...highlights.map((hl) => Padding(
      padding: const EdgeInsets.fromLTRB(16,0,16,8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => UniversalDetailView(object: hl.r))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _resourceColor(hl.r).withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: _resourceColor(hl.r), width: 2)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_resourceEmoji(hl.r)} ${hl.r.title}${hl.tag != null ? " · #${hl.tag}" : ""}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: _resourceColor(hl.r))),
            const SizedBox(height: 3),
            Text('"${hl.text}"', style: TextStyle(fontSize: 10,
              color: AppTheme.textSecondaryColor(context),
              height: 1.55, fontStyle: FontStyle.italic)),
          ])))),
  ]);
}

Color _resourceColor(Resource r) => switch (r.resourceType.toLowerCase()) {
  'podcast' => AppColors.info, 'book' || 'livro' => AppColors.primary,
  _ => AppColors.habitPurple };
```
---
C3 — Home Screen [DONE]
O que é: Dashboard principal. Hoje o header é só botões de sync e edição sem contexto — nenhuma saudação, nenhuma data. A quote do dia é hardcoded ("Peter Drucker"). O pull-to-search dispara com -80px e não tem debounce, causando abertura acidental frequente.
Melhorias:
3a. Saudação contextual: Adicionar antes dos botões de ação no header:
```dart
Widget _buildGreeting(BuildContext context, WidgetRef ref) {
  final hour     = DateTime.now().hour;
  final greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
  final name     = ref.watch(settingsProvider).userName ?? '';
  final dateStr  = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$greeting${name.isNotEmpty ? ", $name" : ""}',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
        color: AppTheme.textPrimaryColor(context))),
    const SizedBox(height: 2),
    Text(dateStr, style: TextStyle(fontSize: 13,
      color: AppTheme.textMutedColor(context), fontWeight: FontWeight.w500)),
  ]);
}

// Header reorganizado:
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Expanded(child: _buildGreeting(context, ref)),
  Row(mainAxisSize: MainAxisSize.min, children: [
    _buildSyncIndicator(ref),
    if (_isEditMode) IconButton(icon: const Icon(Icons.add_box_rounded, color: AppColors.primary), ...),
    IconButton(icon: Icon(_isEditMode ? Icons.check_rounded : Icons.tune_rounded, ...), ...),
  ]),
])
```
3b. Quote do dia com highlights reais: Substituir hardcoded:
```dart
Widget _buildQuoteBlock(BuildContext context, WidgetRef ref) {
  final resources = ref.watch(resourcesProvider);
  final allHighlights = <({String text, String source})>[];
  for (final r in resources) {
    final hls = MarkdownParser.extractHighlights(r.synopsis ?? '');
    allHighlights.addAll(hls.map((h) => (text: h.text, source: r.title)));
  }
  final today    = DateTime.now();
  final dayIndex = today.day + today.month * 31;
  final quote    = allHighlights.isEmpty
    ? (text: '"The best way to predict the future is to create it."', source: 'Peter Drucker')
    : allHighlights[dayIndex % allHighlights.length];

  return _buildCard(title: 'Destaque do dia', icon: Icons.format_quote_rounded,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('"${quote.text}"', style: const TextStyle(
        fontSize: 15, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, height: 1.5)),
      const SizedBox(height: 8),
      Text('— ${quote.source}',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
    ]));
}
```
3c. Fix pull-to-search (debounce):
```dart
// Estado adicional:
bool _searchOpenedInThisScroll = false;

// No NotificationListener:
onNotification: (notification) {
  if (notification.metrics.pixels >= 0) _searchOpenedInThisScroll = false;
  if (notification.metrics.pixels < -140 &&    // threshold: -140 em vez de -80
      notification.dragDetails != null &&
      !_searchOpenedInThisScroll &&
      ModalRoute.of(context)?.isCurrent == true) {
    _searchOpenedInThisScroll = true;
    showCommandCenter(context);
  }
  return false;
},
```
---
C4 — Planner Screen [DONE]
O que é: Tela de planejamento diário com timeline, lista de tarefas, hábitos e eventos. Tem vários bugs confirmados no código.
Bugs a corrigir:
4a. `timeBlocks:` não passado ao `TimeLineDayView` — bug de 1 linha que faz as faixas coloridas de bloco de tempo nunca aparecerem:
```dart
// Localizar a construção de TimeLineDayView e adicionar:
TimeLineDayView(
  // ...parâmetros existentes...
  timeBlocks: timeBlocks,  // ← ADICIONAR
)
```
4b. Toggle timeline/lista ausente na AppBar:
```dart
IconButton(
  icon: Icon(_isTimeline ? Icons.view_list_rounded : Icons.view_timeline_rounded,
    size: 22, color: AppTheme.textMutedColor(context)),
  tooltip: _isTimeline ? 'Ver como lista' : 'Ver como timeline',
  onPressed: () => setState(() => _isTimeline = !_isTimeline)),
```
4c. Setas de navegação entre dias — substituir widget de data:
```dart
Row(children: [
  IconButton(
    icon: const Icon(Icons.chevron_left_rounded),
    onPressed: () => setState(() =>
      _selectedDate = _selectedDate.subtract(const Duration(days: 1)))),
  Expanded(child: GestureDetector(
    onTap: _pickCustomDate,
    child: Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
  IconButton(
    icon: const Icon(Icons.chevron_right_rounded),
    onPressed: () => setState(() =>
      _selectedDate = _selectedDate.add(const Duration(days: 1)))),
  if (!_isToday(_selectedDate))
    TextButton(
      onPressed: () => setState(() => _selectedDate = DateTime.now()),
      child: const Text('Hoje', style: TextStyle(
        color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
])
```
4d. Fix moodSlug bruto em `_buildJournalEntryItem`:
```dart
// ANTES: Text('Mood: ${entry.moodSlug}')
// DEPOIS:
Consumer(builder: (ctx, ref, _) {
  final moods = ref.watch(moodsProvider);
  final mood  = moods.cast<MoodDefinition?>().firstWhere(
    (m) => m?.id == entry.moodSlug || m?.slug == entry.moodSlug,
    orElse: () => null);
  if (mood == null) return const SizedBox.shrink();
  return Text('${mood.emoji} ${mood.title}',
    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)));
})
```
4e. Fix `_buildTrackingRecordItem` sem nome do tracker:
```dart
// ANTES: Text('Tracker Record')
// DEPOIS:
Consumer(builder: (ctx, ref, _) {
  final trackers = ref.watch(trackersProvider);
  final tracker  = trackers.cast<dynamic>().firstWhere(
    (t) => t.id == record.trackerId, orElse: () => null);
  return Text(tracker?.title ?? 'Registro',
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
})
```
---
C5 — Goals Screen [DONE]
O que é: Tela de metas. É `ConsumerWidget` (stateless), o que impede filtros dinâmicos e estado local. Tem crash potencial em cores inválidas (`int.parse` sem try-catch) e usa `IntrinsicHeight` em listas longas, causando lentidão.
Bugs a corrigir + melhorias:
5a. Converter para ConsumerStatefulWidget:
```dart
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('goal'));
    });
  }
}
```
5b. Barra de progresso global no header — adicionar como primeiro SliverToBoxAdapter:
```dart
SliverToBoxAdapter(child: Padding(
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Text('Metas',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
      Text('${completedGoals.length}/${goals.length}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.primary)),
    ]),
    const SizedBox(height: 10),
    ClipRRect(borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: goals.isEmpty ? 0 : completedGoals.length / goals.length,
        minHeight: 6,
        backgroundColor: AppTheme.surfaceVariantColor(context),
        valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
    const SizedBox(height: 4),
    Text('${activeGoals.length} em andamento · ${onHoldGoals.length} pausadas',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])))
```
5c. Botão +10% inline — após a barra de progresso de cada `_GoalCard`:
```dart
if (!isCompleted)
  GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      final newP = (liveProgress + 0.1).clamp(0.0, 1.0);
      ref.read(goalsProvider.notifier).updateGoal(goal.copyWith(progress: newP));
      if (newP >= 1.0 && context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Meta concluída!')));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20)),
      child: const Text('+10%', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))),
```
5d. Fix IntrinsicHeight — substituir por `ConstrainedBox`:
```dart
// ANTES: IntrinsicHeight(child: Row(children: [Container(width:6, color:color), ...]))
// DEPOIS:
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 80),
  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(width: 6, decoration: BoxDecoration(
      color: isCompleted ? AppColors.textMuted : color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)))),
    Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(...))),
  ]))
```
5e. Fix color parse sem try-catch:
```dart
Color _parseGoalColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
  catch (_) { return AppColors.primary; }
}
```
---
C6 — Habits Screen [DONE]
O que é: Tela de hábitos com abas Hoje/Semana/Mês. Tem bug de locale: a semana começa no domingo americano em vez de segunda-feira.
Bugs + melhorias:
6a. Fix semana começando na segunda-feira:
```dart
// ANTES:
final weekStart = now.subtract(Duration(days: now.weekday % 7));
// DEPOIS:
final weekStart = now.subtract(Duration(days: now.weekday - 1));
```
6b. Seção "Sem agendamento" na aba Hoje — adicionar após a lista de hábitos agendados:
```dart
Builder(builder: (context) {
  final unscheduled = ref.watch(habitsProvider).where((h) =>
    h.status == HabitStatus.active && !h.archived && h.schedulers.isEmpty).toList();
  if (unscheduled.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('Sem agendamento', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, color: AppTheme.textMutedColor(context),
          letterSpacing: 0.08)),
      ])),
    const SizedBox(height: 8),
    ...unscheduled.map((h) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Opacity(opacity: 0.65, child: _TodayHabitCard(habit: h, date: DateTime.now())))),
  ]);
})
```
6c. Quitting Habits — ver seção D1. A `HabitsScreen` precisa separar habits normais de quitting e renderizar cada grupo com card diferente.
6d. HealthAlertsStrip — adicionar no topo da aba Hoje (antes dos hábitos):
```dart
const HealthAlertsStrip(compact: false),
```
6e. Fix _SummaryChip Row sem Flexible:
```dart
// ANTES: Row(children: [_SummaryChip(...), SizedBox(width:8), _SummaryChip(...)])
// DEPOIS:
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```
---
C7 — Inbox Screen [DONE]
O que é: Tela de captura GTD. Hoje o campo de captura só aparece depois de tocar num botão "Capturar" na AppBar — o usuário tem que fazer 2 toques para começar a digitar. O campo some depois de usar.
UX nova: Campo sempre visível no topo da tela com borda dourada, auto-focus ao abrir, Enter submete e limpa o campo imediatamente (sem fechar o teclado) para a próxima captura. Swipe → direita arquiva, swipe ← esquerda abre tela de triagem.
```dart
// AppBar: remover botão 'Capturar'

// Campo fixo no topo do body:
Container(
  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
  decoration: BoxDecoration(
    color: AppTheme.cardFillColor(context),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.primary, width: 1.5),
    boxShadow: [BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.10), blurRadius: 12)]),
  child: Row(children: [
    Expanded(child: TextField(
      controller: _captureController,
      focusNode: _captureFocus,
      decoration: const InputDecoration(
        hintText: 'O que está na sua cabeça?',
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      style: const TextStyle(fontSize: 16),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _capture())),
    IconButton(onPressed: _capture,
      icon: const Icon(Icons.send_rounded, color: AppColors.primary)),
  ]))

// Auto-focus em initState:
WidgetsBinding.instance.addPostFrameCallback((_) => _captureFocus.requestFocus());

// Swipe nos itens:
Dismissible(
  key: ValueKey(item.id),
  background: Container(
    alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20),
    color: AppColors.habitGreen,
    child: const Icon(Icons.archive_rounded, color: Colors.white)),
  secondaryBackground: Container(
    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
    color: AppColors.info,
    child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white)),
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.startToEnd) {
      await ref.read(inboxProvider.notifier).archiveItem(item.id);
      return true;
    } else {
      _showTriageSheet(context, item);
      return false;
    }
  },
  child: _buildInboxItemTile(item))
```
---
C8 — Settings Screen [DONE]
O que é: Tela de configurações. Hoje é uma lista plana sem hierarquia visual — todos os itens no mesmo nível, difícil de navegar. Campo de nome do usuário não existe.
UX nova: 4 grupos em cards com divisórias internas (Perfil / Preferências / Integrações / Avançado). Seção Avançado colapsada por padrão.
```dart
// Helpers:
Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 0.10, color: AppTheme.textMutedColor(context))));

Widget _buildSettingsCard(List<Widget> tiles) => Container(
  decoration: AppTheme.cardDecoration(context),
  margin: const EdgeInsets.only(bottom: 16),
  child: Column(children: tiles.asMap().entries.expand((e) => [
    e.value,
    if (e.key < tiles.length - 1) const Divider(height: 1, indent: 56),
  ]).toList()));

Widget _settingsTile(String title, IconData icon,
    {String? subtitle, VoidCallback? onTap}) => ListTile(
  leading: Container(width: 34, height: 34,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, size: 18, color: AppColors.primary)),
  title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
  subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
  trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
  onTap: onTap);

// Editar nome inline:
void _editUserName() async {
  final ctrl   = TextEditingController(text: ref.read(settingsProvider).userName ?? '');
  final result = await showDialog<String>(context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Seu nome'),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: const InputDecoration(hintText: 'Como posso te chamar?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Salvar')),
      ]));
  if (result != null) await ref.read(settingsProvider.notifier).setUserName(result);
}
```
---
C9 — Appearance Screen [DONE]
O que é: Tela de aparência. Os swatches de cor existem visualmente mas não são interativos — tocar não faz nada. A cor de destaque do app é hardcoded em `AppColors.primary`.
Como implementar:
```dart
// Swatches interativos:
static const _presets = [
  Color(0xFFFFB000), Color(0xFF3B82F6), Color(0xFF22C55E),
  Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899),
  Color(0xFF8B5CF6), Color(0xFF0EA5E9), Color(0xFFF97316),
];

// Em build():
Wrap(spacing: 10, runSpacing: 10, children: _presets.map((color) {
  final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  final isSelected = settings.accentColor.toUpperCase() == hex;
  return GestureDetector(
    onTap: () => ref.read(settingsProvider.notifier).setAccentColor(hex),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: isSelected
          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
          : null),
      child: isSelected
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null));
}).toList())
```
---
C10 — Journal Screen [DONE]
O que é: Tela do diário. Quando há filtros ativos (por mood, por foto, por data), o usuário não tem feedback visual de que está filtrando — a lista simplesmente mostra menos itens sem explicação. O campo de busca existe no estado mas nunca é exibido na UI.
10a. Banner de filtros ativos:
```dart
// Logo antes do ListView, condicional:
if (_filterMood != null || _filterHasPhoto || _onlySelectedDate)
  Container(
    color: AppColors.primary.withValues(alpha: 0.06),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primary),
      const SizedBox(width: 6),
      if (_filterMood != null) ...[
        _activeChip(_resolveMoodLabel(ref, _filterMood!),
          () => setState(() => _filterMood = null)),
        const SizedBox(width: 6),
      ],
      if (_filterHasPhoto) ...[
        _activeChip('📷 Com foto', () => setState(() => _filterHasPhoto = false)),
        const SizedBox(width: 6),
      ],
      if (_onlySelectedDate)
        _activeChip(DateFormat('d MMM', 'pt_BR').format(_selectedDate),
          () => setState(() => _onlySelectedDate = false)),
      const Spacer(),
      GestureDetector(
        onTap: () => setState(() {
          _filterMood = null; _filterHasPhoto = false; _onlySelectedDate = false;
        }),
        child: const Text('Limpar', style: TextStyle(
          fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600))),
    ])),

Widget _activeChip(String label, VoidCallback onRemove) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(
      fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
    const SizedBox(width: 4),
    GestureDetector(onTap: onRemove,
      child: const Icon(Icons.close_rounded, size: 12, color: AppColors.primary)),
  ]));
```
10b. Busca expansível na AppBar:
```dart
// Estado: bool _searchExpanded = false;

// Na AppBar actions:
IconButton(
  icon: Icon(_searchExpanded ? Icons.close_rounded : Icons.search_rounded,
    color: _searchExpanded ? AppColors.primary : AppTheme.textMutedColor(context)),
  onPressed: () => setState(() {
    _searchExpanded = !_searchExpanded;
    if (!_searchExpanded) { _searchQuery = ''; _searchController.clear(); }
  })),

// Abaixo da AppBar:
AnimatedContainer(
  duration: const Duration(milliseconds: 220),
  height: _searchExpanded ? 52 : 0,
  child: _searchExpanded ? Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: TextField(
      controller: _searchController, autofocus: true,
      decoration: InputDecoration(
        hintText: 'Buscar entradas…',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.zero, isDense: true),
      onChanged: (v) => setState(() => _searchQuery = v)))
  : const SizedBox.shrink()),
```
---
C11 — People Screen [DONE]
O que é: Tela de pessoas/contatos. Hoje não tem campo de busca e os botões de ligar/SMS não fazem nada (callbacks vazios `() {}`).
11a. Converter para ConsumerStatefulWidget + busca + toggle grid/lista — mesmo padrão do C5a. Adicionar:
```dart
bool _isListView = false;
String _searchQuery = '';

// Campo de busca sempre visível abaixo da AppBar
// Toggle grid/lista na AppBar
// Filtrar por _searchQuery ao exibir
```
11b. Ações de contato funcionais:
```dart
// Adicionar url_launcher ao pubspec.yaml se ausente.
enum _ContactType { sms, call }

Widget _contactAction(Person p, IconData icon, Color color, _ContactType type) =>
  GestureDetector(
    onTap: () async {
      if (p.phone == null || p.phone!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum telefone cadastrado')));
        return;
      }
      final uri = type == _ContactType.sms
        ? Uri.parse('sms:${p.phone}') : Uri.parse('tel:${p.phone}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)));
```
11c. Badge de contato pendente:
```dart
// Envolver card em Stack e adicionar ponto vermelho se isDueForContact:
if (person.isDueForContact)
  Positioned(top: 8, right: 8,
    child: Container(width: 10, height: 10,
      decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5))))
```
---
C12 — Trackers Screen [DONE]
O que é: Tela de trackers. Os cards não mostram o último valor registrado, forçando o usuário a abrir cada tracker para ver o dado mais recente. Não tem atalho de registro rápido.
12a. Último valor no card:
```dart
Consumer(builder: (ctx, ref, _) {
  final records = ref.watch(trackingRecordsProvider)
    .where((r) => r.trackerId == tracker.id).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final last       = records.isNotEmpty ? records.first : null;
  final firstField = last?.fieldValues.entries.firstOrNull;

  if (firstField == null) return Text('Sem registros',
    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(ctx)));

  return Column(children: [
    const Divider(height: 16),
    Row(children: [
      Expanded(child: Text(firstField.key, style: TextStyle(
        fontSize: 10, color: AppTheme.textMutedColor(ctx)), maxLines: 1,
        overflow: TextOverflow.ellipsis)),
      Text(firstField.value.toString(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          color: AppColors.primary)),
      const SizedBox(width: 6),
      Text(DateFormat('d/M').format(last!.date),
        style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(ctx))),
    ]),
  ]);
})
```
12b. Botão + direto no card:
```dart
// Envolver conteúdo em Stack:
Positioned(bottom: 10, right: 10,
  child: GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRecordForm(preselectedTracker: tracker)),
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 8, offset: const Offset(0, 3))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 18))))
```
12c. Remover botão duplicado de Analysis — localizar `IconButton` com `Icons.auto_graph_rounded` ou similar no header e deletar.
---
C13 — Timeline Screen [DONE]
O que é: Tela de histórico cronológico de todos os eventos. Hoje o título ainda está como "Journal" (ou equivalente). Sem paginação, o que pode travar com muitos itens.
13a. Fix título: `AppBar(title: const Text('Timeline'), centerTitle: true)`
13b. Paginação por scroll infinito:
```dart
int _currentPage = 1;
static const _pageSize = 50;
final _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_currentPage * _pageSize < _filteredItems.length)
        setState(() => _currentPage++);
    }
  });
}

// No build — usar paginatedItems:
final paginatedItems = _filteredItems.take(_pageSize * _currentPage).toList();
```
---
C14 — Organizer Detail Screen [DONE]
O que é: Tela de detalhe de um Organizer. As tabs (Tarefas/Notas/Outros) não mostram contagem de itens. O único botão de ação abre o `UniversalDetailView` mas não o form de edição diretamente.
14a. Contagem nas tabs:
```dart
final allItems   = associatedItemsAsync.valueOrNull ?? [];
final taskCount  = allItems.whereType<Task>().length;
final noteCount  = allItems.whereType<Note>().length;
final otherCount = allItems.length - taskCount - noteCount;

TabBar(controller: _tabController, tabs: [
  Tab(text: 'Tarefas${taskCount > 0 ? " ($taskCount)" : ""}'),
  Tab(text: 'Notas${noteCount > 0 ? " ($noteCount)" : ""}'),
  Tab(text: 'Outros${otherCount > 0 ? " ($otherCount)" : ""}'),
])
```
14b. Botões separados editar/detalhes:
```dart
// Em SliverAppBar actions — substituir botão único por dois:
IconButton(
  tooltip: 'Editar', icon: const Icon(Icons.edit_outlined, size: 20),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateOrganizerForm(existingOrganizer: widget.organizer)))),
IconButton(
  tooltip: 'Ver detalhes', icon: const Icon(Icons.info_outline_rounded, size: 20),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => UniversalDetailView(object: widget.organizer)))),
```
---
C15 — Day Theme Screen [DONE]
O que é: Tela de configuração de blocos de tempo e temas do dia. Hoje a única forma de criar é via `PopupMenuButton` na AppBar — não óbvio. Os tiles de bloco de tempo não têm preview visual do horário.
15a. Botões explícitos no final de cada seção:
```dart
// Após a lista de blocos:
SizedBox(width: double.infinity, child: OutlinedButton.icon(
  icon: const Icon(Icons.add_rounded, size: 16),
  label: const Text('Novo Bloco de Tempo'),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
    foregroundColor: AppColors.primary),
  onPressed: () => _showBlockDialog(context, ref))),

// Após a lista de temas:
SizedBox(width: double.infinity, child: OutlinedButton.icon(
  icon: const Icon(Icons.add_rounded, size: 16),
  label: const Text('Novo Tema do Dia'),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
    foregroundColor: AppColors.primary),
  onPressed: () => _showThemeDialog(context, ref))),
```
15b. Preview visual de bloco com barra proporcional de horário:
```dart
Widget _buildBlockTile(TimeBlock block, int reorderIndex) {
  final color = _parseBlockColor(block.color);
  return Container(
    key: ValueKey(block.id),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: AppTheme.cardDecoration(context),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
      leading: Container(width: 4, height: 48,
        decoration: BoxDecoration(color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)))),
      title: Text(block.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${block.startTime} → ${block.endTime}',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildTimeBar(block, color),
        const SizedBox(width: 8),
        ReorderableDragStartListener(index: reorderIndex,
          child: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted)),
      ]),
      onTap: () => _showBlockDialog(context, ref, existing: block)));
}

// Barra proporcional 60px representando 24h:
Widget _buildTimeBar(TimeBlock block, Color color) {
  int toMin(String t) {
    final p = t.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }
  final start = toMin(block.startTime) / 1440.0;
  final end   = toMin(block.endTime)   / 1440.0;
  final barW  = ((end - start) * 60).clamp(4.0, 56.0);
  final leftW = (start * 60).clamp(0.0, 60.0 - barW);
  return SizedBox(width: 60, height: 8, child: Stack(children: [
    Container(decoration: BoxDecoration(
      color: AppTheme.textMutedColor(context).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4))),
    Positioned(left: leftW, width: barW, top: 0, bottom: 0,
      child: Container(decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(4)))),
  ]));
}

Color _parseBlockColor(String? hex) {
  try { return hex != null ? Color(int.parse(hex.replaceFirst('#', '0xFF'))) : AppColors.primary; }
  catch (_) { return AppColors.primary; }
}
```
---
C16 — Search Screen
O que é: Tela de busca global. Buscas recentes são hardcoded ou não persistidas. Quando o usuário filtra por tipo, não há feedback visual de que o filtro está ativo. As actions contextuais são fixas e não levam em conta o texto digitado.
16a. Buscas recentes persistidas:
```dart
List<String> _recentSearches = [];

@override
void initState() {
  super.initState();
  _loadRecents();
}

Future<void> _loadRecents() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() => _recentSearches = prefs.getStringList('recent_searches') ?? []);
}

Future<void> _persistSearch(String query) async {
  if (query.trim().length < 2) return;
  final prefs  = await SharedPreferences.getInstance();
  final list   = prefs.getStringList('recent_searches') ?? [];
  list.remove(query); list.insert(0, query);
  if (list.length > 10) list.removeLast();
  await prefs.setStringList('recent_searches', list);
  if (mounted) setState(() => _recentSearches = list);
}
// Chamar _persistSearch no onSubmitted do campo de busca.
```
16b. Chip de tipo ativo nos resultados:
```dart
if (_searchQuery.isNotEmpty && _selectedType != null)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_typeLabels[_selectedType] ?? _selectedType!,
            style: const TextStyle(fontSize: 12,
              color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() { _selectedType = null; _onSearchChanged(_searchController.text); }),
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
        ])),
      const Spacer(),
      Text('${_results.length} resultado${_results.length == 1 ? "" : "s"}',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
    ])),
```
16c. Actions contextuais por query:
```dart
List<SearchAction> _getActions(String query) {
  final q    = query.trim();
  final base = <SearchAction>[
    SearchAction(label: 'Nova Nota', icon: Icons.note_add_outlined, color: AppColors.info,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => CreateNoteForm(initialTitle: q.isNotEmpty ? q : null)))),
    SearchAction(label: 'Iniciar Pomodoro', icon: Icons.timer_rounded, color: AppColors.error,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PomodoroScreen()))),
    SearchAction(label: 'Configurações', icon: Icons.settings_rounded, color: AppColors.info,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
  ];
  if (q.length > 2) {
    base.insert(0, SearchAction(
      label: 'Nova Task: "$q"', icon: Icons.add_circle_outline_rounded, color: AppColors.primary,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => CreateTaskForm(initialTitle: q)))));
  }
  return base;
}
```
---
C17 — App Shell
O que é: Shell principal com bottom navigation. Hoje mostra labels em todos os itens (ocupa espaço), não tem badges de pendências e o FAB não tem tooltip.
17a. Labels só no item ativo:
```dart
// NavigationBar (M3):
NavigationBar(
  labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  ...)
// BottomNavigationBar (M2):
BottomNavigationBar(showUnselectedLabels: false, ...)
```
17b. Badges na bottom nav:
```dart
final badgeCounts = ref.watch(badgeCountsProvider);
// Envolver ícone do Planner:
Badge(
  isLabelVisible: (badgeCounts['planner'] ?? 0) > 0,
  label: Text('${badgeCounts['planner']}', style: const TextStyle(fontSize: 9)),
  child: Icon(_navIcon('planner')))
// Mesma coisa para 'inbox' e 'people'
```
17c. Tooltip no FAB:
```dart
Tooltip(message: 'Criar novo',
  child: FloatingActionButton(
    onPressed: () => showCreateMenu(context),
    backgroundColor: AppColors.primary,
    child: const Icon(Icons.add_rounded, color: Colors.black)))
```
---
C18 — Social Screen
O que é: Tela de posts salvos. Usa string para modo de ordenação em vez de enum. O overlay de seleção múltipla não é visualmente forte o suficiente. O popup de ações pode fazer overflow com muitas opções.
18a. SortMode como enum:
```dart
enum SocialSortMode { savedDesc, savedAsc, platformAsc, unwatchedFirst }
SocialSortMode _sortMode = SocialSortMode.savedDesc;
// Atualizar switch de ordenação para usar enum.
```
18b. Overlay de seleção mais evidente:
```dart
// Em SocialPostGridCard, quando isSelected && isMultiSelectMode:
Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
  color: AppColors.primary.withValues(alpha: 0.30),
  border: Border.all(color: AppColors.primary, width: 2.5),
  borderRadius: BorderRadius.circular(12)))),
const Positioned(top: 6, right: 6,
  child: CircleAvatar(radius: 10, backgroundColor: AppColors.primary,
    child: Icon(Icons.check_rounded, size: 12, color: Colors.black))),
```
18c. Arquivar em multi-select com undo:
```dart
IconButton(
  tooltip: 'Arquivar selecionados',
  icon: const Icon(Icons.archive_outlined),
  onPressed: _selectedIds.isEmpty ? null : () async {
    final toArchive = posts.where((p) => _selectedIds.contains(p.id)).toList();
    for (final p in toArchive)
      await ref.read(socialPostsProvider.notifier).updatePost(p.copyWith(archived: true));
    _clearSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${toArchive.length} post(s) arquivados'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () async {
        for (final p in toArchive)
          await ref.read(socialPostsProvider.notifier).updatePost(p.copyWith(archived: false));
      })));
  }),
```
18d. Fix overflow no popup de ações (`object_action_wrapper.dart`):
```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,        // ADICIONAR
  ...
  builder: (sheetContext) => SafeArea(
    child: ConstrainedBox(          // ADICIONAR
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: SingleChildScrollView( // ADICIONAR
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min,
            children: [/* conteúdo existente */]))))))
```
---
C19 — Create Social Post Form
O que é: Formulário de criação de post social. Não detecta posts duplicados (mesmo URL salvo antes). O campo de título vem do fetch de metadata mas não é editável — o usuário não consegue renomear o arquivo que será salvo no vault.
19a. Detecção de duplicata:
```dart
enum _DuplicateAction { edit, doNothing, saveAnyway }

Future<void> _save() async {
  if (widget.existingPost == null) {
    final url      = _urlController.text.trim();
    final existing = ref.read(socialPostsProvider).where((p) => p.url.trim() == url).toList();
    if (existing.isNotEmpty) {
      final action = await _showDuplicateDialog(existing.first);
      if (!mounted) return;
      switch (action) {
        case _DuplicateAction.edit:
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CreateSocialPostForm(existingPost: existing.first)));
          return;
        case _DuplicateAction.doNothing:
          Navigator.pop(context); return;
        case _DuplicateAction.saveAnyway: break;
        case null: return;
      }
    }
  }
  // lógica de save existente
}

Future<_DuplicateAction?> _showDuplicateDialog(SocialPost dup) => showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Row(children: [
      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
      const SizedBox(width: 8),
      const Expanded(child: Text('Post já salvo',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dup.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text('Salvo em ${_fmtDate(dup.createdAt)}',
            style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
        ])),
      const SizedBox(height: 12),
      const Text('Este link já foi salvo. O que deseja fazer?'),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, _DuplicateAction.doNothing),
        child: const Text('Não fazer nada')),
      OutlinedButton(onPressed: () => Navigator.pop(ctx, _DuplicateAction.edit),
        child: const Text('Editar existente')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.warning.withValues(alpha:0.9)),
        onPressed: () => Navigator.pop(ctx, _DuplicateAction.saveAnyway),
        child: const Text('Salvar mesmo assim')),
    ]));

String _fmtDate(DateTime d) =>
  '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'
  ' às ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
```
19b. Campo de título editável com preview de slug:
```dart
// Logo após o campo de URL:
const SizedBox(height: 12),
Text('Título / nome do arquivo', style: TextStyle(fontSize: 11,
  fontWeight: FontWeight.w700, letterSpacing: 0.08,
  color: AppTheme.textMutedColor(context))),
const SizedBox(height: 6),
TextField(
  controller: _titleController,
  decoration: InputDecoration(
    hintText: 'Nome que aparece no vault…',
    filled: true, fillColor: AppTheme.surfaceVariantColor(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    suffixIcon: _titleController.text.isNotEmpty
      ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
          onPressed: () => setState(() => _titleController.clear()))
      : null),
  onChanged: (_) => setState(() {})),
if (_titleController.text.trim().isNotEmpty) ...[
  const SizedBox(height: 4),
  Text('Arquivo: ${_slugPreview(_titleController.text)}',
    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context),
      fontFamily: 'monospace')),
],

String _slugPreview(String title) {
  var s = title.toLowerCase().trim()
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
    .replaceAll(RegExp(r'-+'), '-');
  if (s.length > 40) s = s.substring(0, 40);
  return '$s.md';
}
```
---
C20 — Fixes Globais de Overflow
O que é: Bugs de layout que fazem widgets ultrapassarem seus bounds, causando exceções ou texto cortado sem ellipsis.
20a. Goals — badge "VENCIDA" sem Flexible:
```dart
Row(children: [
  const Icon(Icons.calendar_today_rounded, size: 12),
  const SizedBox(width: 4),
  Flexible(child: Text('Prazo: ${_formatDate(goal.deadline)}',
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)))),
  const SizedBox(width: 6),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4)),
    child: const Text('VENCIDA', style: TextStyle(
      fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error))),
])
```
20b. Home — `_buildEditModeHint` sem maxLines:
```dart
Text('Arraste para reordenar ou toque ⋯ para configurar',
  maxLines: 2, overflow: TextOverflow.ellipsis,
  style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)))
```
20c. Habits — `_SummaryChip` Row sem Flexible:
```dart
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```
20d. Timeline `resize handle` área de toque 8dp:
```dart
// Substituir Container(height: isTiny ? 8 : 16) por:
GestureDetector(
  onVerticalDragUpdate: _onResizeDrag,
  child: SizedBox(height: 24,  // área de toque mínima 24dp
    child: Align(alignment: Alignment.bottomCenter,
      child: Container(width: 32, height: isTiny ? 3 : 4,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2))))))
```

---
BLOCO D — FEATURES NOVAS
---
D1 — Quitting Habits (Hábitos de Parar)
O que é: Hábitos cujo objetivo é NÃO fazer algo — parar de fumar, parar de roer unhas, parar de comer açúcar. Hoje esses hábitos são tratados igual a qualquer outro: aparecem no Planner com checkbox de "marcar como feito", aparecem no CalendarWidget, e marcar é semanticamente errado (marcar = falhar, não ter sucesso). O usuário quer ver quantos dias ficou sem fazer, não quantas vezes fez.
Como funciona:
Hábito com `isQuitting: true` aparece em seção separada "Evitando" na aba Hoje — nunca junto com os hábitos normais
Card visual diferente: sem checkbox, com contador de dias limpos com cor semafórica
Verde ✨ = 3+ dias limpos | Amarelo ⚠️ = 1–2 dias | Vermelho 💥 = recaída hoje
Botão "Recaída" com confirmação — registra que o usuário fez o que estava evitando
NÃO aparece no Planner, NÃO aparece no CalendarWidget
Na aba Semana/Mês aparece em seção separada com streak de dias limpos
Formulário — `lib/ui/forms/create_habit_form.dart`:
```dart
// Estado:
bool _isQuitting = false;

// UI — após o campo de nome, antes de frequência:
Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: _isQuitting
      ? AppColors.error.withValues(alpha: 0.08)
      : AppTheme.surfaceVariantColor(context),
    borderRadius: BorderRadius.circular(12),
    border: _isQuitting
      ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
      : null),
  child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hábito de parar',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: _isQuitting ? AppColors.error : AppTheme.textPrimaryColor(context))),
      const SizedBox(height: 2),
      Text('O objetivo é NÃO fazer. Não aparece no Planner.',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _isQuitting, activeColor: AppColors.error,
      onChanged: (v) => setState(() => _isQuitting = v)),
  ]))
```
Card de quitting na HabitsScreen — novo widget `_QuittingHabitCard`:
```dart
class _QuittingHabitCard extends ConsumerWidget {
  final Habit habit;
  const _QuittingHabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calcular dias limpos: dias desde a última entrada done==true no completionHistory
    final history = habit.completionHistory ?? {};
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    int cleanDays = 0;
    for (int i = 0; i < 365; i++) {
      final d   = today.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final e   = history[key];
      if (e == true || (e is Map && e['done'] == true)) break;
      cleanDays++;
    }

    final statusColor = cleanDays == 0 ? AppColors.error
      : cleanDays < 3 ? AppColors.warning : AppColors.habitGreen;
    final statusEmoji = cleanDays == 0 ? '💥' : cleanDays < 3 ? '⚠️' : '✨';

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Text(statusEmoji, style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(cleanDays == 0 ? 'Recaída hoje'
            : cleanDays == 1 ? '1 dia limpo' : '$cleanDays dias limpos',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
        ])),
        GestureDetector(
          onTap: () => _confirmRelapse(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20)),
            child: const Text('Recaída', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)))),
      ]));
  }

  void _confirmRelapse(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar recaída?'),
        content: Text(
          'Isso vai zerar o contador de dias limpos de "${habit.title}". '
          'Tudo bem, recomeços fazem parte do processo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar')),
        ]));
    if (confirmed != true) return;
    await ref.read(habitsProvider.notifier).toggleHabit(habit, DateTime.now(), slotIndex: 0);
  }
}
```
Integração na `_TodayView` da HabitsScreen:
```dart
// Separar antes de renderizar:
final normalHabits   = todayHabits.where((h) => !h.isQuitting).toList();
final quittingHabits = todayHabits.where((h) =>  h.isQuitting).toList();

// Renderizar normalHabits com _TodayHabitCard existente.

// Adicionar ao final, após os normais:
if (quittingHabits.isNotEmpty) ...[
  const SizedBox(height: 20),
  Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text('Evitando', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.error, letterSpacing: 0.08)),
    ])),
  const SizedBox(height: 8),
  ...quittingHabits.map((h) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: _QuittingHabitCard(habit: h))),
]
```
Excluir do Planner e CalendarWidget:
```dart
// planner_screen.dart — em qualquer filtro de todayHabits:
.where((h) => _shouldShowToday(h) && !h.isQuitting)

// calendar_widget.dart:
habits.where((h) => h.status == HabitStatus.active && !h.isQuitting).take(4)
```
---
D2 — Tracker de Saúde com Alertas Automáticos
O que é: Sistema de monitoramento de métricas de saúde com alertas visuais automáticos. A Laura quer acompanhar sono, buraco no cabelo, comida e cocô — mas cada um tem uma lógica diferente: sono tem threshold numérico (abaixo de 6h = aviso), cabelo é sempre alerta crítico independente do valor, comida e cocô variam muito e servem mais para observar padrão do que alertar.
O problema dos lembretes: Lembretes comuns são ignorados depois de um tempo. A solução é escalonamento: lembrete inicial no horário configurado, follow-up 2h depois se não registrado, lembrete crítico às 21h para campos críticos.
Formulário de campo no tracker — `lib/ui/forms/create_tracker_form.dart`:
Após o picker de tipo de campo, adicionar seção de alerta:
```dart
// Switch "sempre alerta" (para buraco no cabelo):
Row(children: [
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Sempre é alerta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    Text('Qualquer registro acende alerta vermelho',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])),
  Switch(value: _alwaysAlert, activeColor: AppColors.error,
    onChanged: (v) => setState(() => _alwaysAlert = v)),
]),

// Se não for alwaysAlert, mostrar threshold e nível:
if (!_alwaysAlert) ...[
  const SizedBox(height: 12),
  Text('Nível de alerta', style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
  const SizedBox(height: 6),
  Row(children: [
    _alertBtn(FieldAlertLevel.none,    '—',      AppTheme.textMutedColor(context)),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.info,    'Info',   AppColors.info),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.warning, 'Aviso',  AppColors.warning),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.critical,'Crítico',AppColors.error),
  ]),
  if (_alertLevel != FieldAlertLevel.none) ...[
    const SizedBox(height: 10),
    TextField(
      controller: _thresholdController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Acionar alerta quando valor ≤',
        hintText: 'ex: 6 (para horas de sono)',
        filled: true, fillColor: AppTheme.surfaceVariantColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none))),
    const SizedBox(height: 8),
    TextField(
      controller: _alertNoteController,
      decoration: InputDecoration(
        labelText: 'Contexto do alerta (opcional)',
        hintText: 'ex: "sono depende dos remédios, considerar isso"',
        filled: true, fillColor: AppTheme.surfaceVariantColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none))),
  ],
],

Widget _alertBtn(FieldAlertLevel level, String label, Color color) {
  final sel = _alertLevel == level;
  return Expanded(child: GestureDetector(
    onTap: () => setState(() => _alertLevel = level),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
        border: sel ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: sel ? color : AppTheme.textMutedColor(context)))))));
}
```
Toggle isHealthTracker no formulário do tracker:
```dart
Row(children: [
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Tracker de saúde', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    Text('Mostra alertas na tela de hábitos e no dashboard',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])),
  Switch(value: _isHealthTracker, activeColor: AppColors.primary,
    onChanged: (v) => setState(() => _isHealthTracker = v)),
]),
```
Template pré-configurado "Saúde" — botão no topo do formulário:
```dart
OutlinedButton.icon(
  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
  label: const Text('Usar template: Saúde'),
  onPressed: () => setState(() {
    _titleController.text = 'Saúde';
    _isHealthTracker = true;
    _fields = [
      TrackerField(name: 'Sono', type: FieldType.number, unit: 'h',
        alertLevel: FieldAlertLevel.warning, alertThreshold: 6.0,
        alertNote: 'Depende dos remédios — contexto importa'),
      TrackerField(name: 'Comida', type: FieldType.boolean,
        alertLevel: FieldAlertLevel.info,
        alertNote: 'Varia com o dia — observar padrão'),
      TrackerField(name: 'Cocô', type: FieldType.boolean,
        alertLevel: FieldAlertLevel.info,
        alertNote: 'Varia — observar frequência'),
      TrackerField(name: 'Buraco no cabelo', type: FieldType.boolean,
        alwaysAlert: true, alertLevel: FieldAlertLevel.critical,
        alertNote: 'ALERTA VERMELHO — verificar imediatamente'),
    ];
  })),
```
Lembretes escalonados — `lib/services/notification_service.dart`:
```dart
Future<void> scheduleHealthReminders(Tracker tracker, TrackerField field) async {
  final baseTime = field.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);

  // Lembrete primário
  await _scheduleLocal(
    id: _hId(tracker.id, field.name, 0),
    title: '${tracker.title}: registrar ${field.name}',
    body: field.alertNote ?? 'Não esqueça de registrar',
    scheduledTime: _todayAt(baseTime),
    payload: 'tracker:${tracker.id}');

  // Follow-up 2h depois para campos com alerta
  if (field.alertLevel != FieldAlertLevel.none) {
    await _scheduleLocal(
      id: _hId(tracker.id, field.name, 1),
      title: '⚠️ ${field.name} ainda não registrado',
      body: 'Verifique ${tracker.title}',
      scheduledTime: _todayAt(baseTime).add(const Duration(hours: 2)),
      payload: 'tracker:${tracker.id}');
  }

  // Alerta crítico à noite para campos críticos
  if (field.alertLevel == FieldAlertLevel.critical || field.alwaysAlert) {
    await _scheduleLocal(
      id: _hId(tracker.id, field.name, 2),
      title: '🚨 ${field.name} — verificação final do dia',
      body: field.alertNote ?? 'Registro obrigatório',
      scheduledTime: _todayAt(const TimeOfDay(hour: 21, minute: 0)),
      payload: 'tracker:${tracker.id}');
  }
}

Future<void> cancelHealthReminders(String trackerId, String fieldName) async {
  for (int i = 0; i <= 2; i++) await _cancelLocal(_hId(trackerId, fieldName, i));
}

int _hId(String tid, String fname, int variant) =>
  'health_${tid}_${fname}_$variant'.hashCode.abs();
DateTime _todayAt(TimeOfDay t) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, t.hour, t.minute);
}
```
Chamar `cancelHealthReminders` no notifier de tracking records ao salvar um record.
---
D3 — Ideias como Tipo de Objeto
O que é: Um tipo de objeto de primeiro nível chamado "Ideia". É mais leve que uma Task (sem stage pipeline de to-do → in progress → done) e mais estruturado que uma Note (tem horizonte de tempo, prioridade, pode ser convertida). O fluxo é: capturar ideia rápida → amadurecer → converter em Task/Projeto/Goal/Nota quando estiver pronta. Ao converter, todas as propriedades (organizers, tags, notas) são transferidas para o novo objeto.
UX:
Captura em bottom sheet rápido (abre direto no campo de título com autofocus)
Emoji editável (padrão 💡)
Campo de notas expansível sem limite de linhas
Horizonte de tempo em chips: 🔥 Agora / ⚡ Em breve / ☁️ Um dia / ∞ Sem prazo
Data alvo opcional (só aparece quando horizonte é Agora ou Em breve)
Prioridade em chips compactos
Organizers via `OrganizerSelectorField` existente
Botão "Converter →" no card → sheet com opções Task/Projeto/Goal/Nota
Ideia convertida fica marcada com "→ task" e fica visível só se `_showConverted = true`
Formulário — `lib/ui/forms/create_idea_form.dart` — CRIAR NOVO:
```dart
class CreateIdeaForm extends ConsumerStatefulWidget {
  final Idea? existingIdea;
  final String? initialTitle;
  const CreateIdeaForm({super.key, this.existingIdea, this.initialTitle});
  @override ConsumerState<CreateIdeaForm> createState() => _CreateIdeaFormState();
}

class _CreateIdeaFormState extends ConsumerState<CreateIdeaForm> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  IdeaHorizon   _horizon   = IdeaHorizon.someday;
  TaskPriority? _priority;
  DateTime?     _targetDate;
  List<OrganizerReference> _organizers = [];
  String _emoji = '💡';

  @override
  void initState() {
    super.initState();
    final e     = widget.existingIdea;
    _titleCtrl  = TextEditingController(text: e?.title ?? widget.initialTitle ?? '');
    _bodyCtrl   = TextEditingController(text: e?.body ?? '');
    _horizon    = e?.horizon    ?? IdeaHorizon.someday;
    _priority   = e?.priority;
    _targetDate = e?.targetDate;
    _organizers = e?.organizers.toList() ?? [];
    _emoji      = e?.emoji ?? '💡';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.dividerColor(context),
              borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Emoji + Título
              Row(children: [
                GestureDetector(
                  onTap: _pickEmoji,
                  child: Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(_emoji,
                      style: const TextStyle(fontSize: 22))))),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _titleCtrl,
                  autofocus: widget.existingIdea == null,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'A ideia é…', border: InputBorder.none),
                  textInputAction: TextInputAction.next)),
              ]),
              const SizedBox(height: 12),

              // Notas
              TextField(
                controller: _bodyCtrl, maxLines: null, minLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Contexto, referências, por que isso importa…',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context)),
                  border: InputBorder.none)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Horizonte
              Text('Quando?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppTheme.textMutedColor(context), letterSpacing: 0.08)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: IdeaHorizon.values.map((h) {
                  final sel = _horizon == h;
                  return Padding(padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _horizon = h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(_horizonLabel(h), style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
                }).toList())),

              // Data alvo (só se horizonte for now/soon)
              if (_horizon == IdeaHorizon.now || _horizon == IdeaHorizon.soon) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantColor(context),
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_targetDate != null
                        ? DateFormat('d MMM y', 'pt_BR').format(_targetDate!)
                        : 'Escolher data',
                        style: TextStyle(fontSize: 12,
                          color: _targetDate != null
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textMutedColor(context))),
                    ]))),
              ],
              const SizedBox(height: 12),

              // Prioridade
              Row(children: [
                Text('Prioridade:', style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedColor(context))),
                const SizedBox(width: 8),
                ...TaskPriority.values.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = _priority == p ? null : p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priority == p
                          ? _priorityColor(p).withValues(alpha: 0.15)
                          : AppTheme.surfaceVariantColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: _priority == p
                          ? Border.all(color: _priorityColor(p).withValues(alpha: 0.4)) : null),
                      child: Text(_priorityLabel(p), style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _priority == p
                          ? _priorityColor(p) : AppTheme.textMutedColor(context)))))),
              ]),
              const SizedBox(height: 12),

              // Organizers
              OrganizerSelectorField(
                selected: _organizers,
                onChanged: (list) => setState(() => _organizers = list)),
              const SizedBox(height: 16),

              // Salvar
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(widget.existingIdea == null ? 'Salvar ideia' : 'Atualizar',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)))),
            ])),
        ]));
  }

  String _horizonLabel(IdeaHorizon h) => switch (h) {
    IdeaHorizon.now        => '🔥 Agora',
    IdeaHorizon.soon       => '⚡ Em breve',
    IdeaHorizon.someday    => '☁️ Um dia',
    IdeaHorizon.noDeadline => '∞ Sem prazo',
  };

  Color _priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.critical => AppColors.error, TaskPriority.high => AppColors.warning,
    TaskPriority.medium   => AppColors.info,  TaskPriority.low  => AppColors.textMuted,
  };

  String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.critical => 'Crítica', TaskPriority.high => 'Alta',
    TaskPriority.medium   => 'Média',   TaskPriority.low  => 'Baixa',
  };

  void _pickDate() async {
    final picked = await showDatePicker(context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)));
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _pickEmoji() => showModalBottomSheet(context: context,
    builder: (_) => _EmojiGrid(onPick: (e) { setState(() => _emoji = e); Navigator.pop(context); }));

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final idea = Idea(
      id: widget.existingIdea?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      horizon: _horizon, priority: _priority, targetDate: _targetDate,
      organizers: _organizers, emoji: _emoji,
      createdAt: widget.existingIdea?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now());
    if (widget.existingIdea == null) {
      await ref.read(ideasProvider.notifier).addIdea(idea);
    } else {
      await ref.read(ideasProvider.notifier).updateIdea(idea);
    }
    if (mounted) Navigator.pop(context);
  }
}
```
Tela de Ideias — `lib/ui/screens/ideas_screen.dart` — CRIAR NOVO:
Layout: busca sempre visível, chips de horizonte, lista com card que tem botão "Converter →".
```dart
class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});
  @override ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  String       _searchQuery    = '';
  IdeaHorizon? _filterHorizon;
  bool         _showConverted  = false;

  @override
  Widget build(BuildContext context) {
    final ideas   = ref.watch(ideasProvider);
    var   filtered = ideas.where((i) =>
      !i.archived &&
      (_showConverted || !i.isConverted) &&
      (_filterHorizon == null || i.horizon == _filterHorizon) &&
      (_searchQuery.isEmpty ||
        i.title.toLowerCase().contains(_searchQuery.toLowerCase()))).toList()
      ..sort((a, b) {
        final hc = a.horizon.index.compareTo(b.horizon.index);
        if (hc != 0) return hc;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Ideias'), centerTitle: true),
      body: CustomScrollView(slivers: [
        // Busca
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Buscar ideias…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true, fillColor: AppTheme.surfaceVariantColor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero, isDense: true)))),

        // Chips de horizonte
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _hChip(null, 'Todas'),
              ...IdeaHorizon.values.map((h) => _hChip(h, _horizonLabel(h))),
            ])))),

        // Lista ou empty state
        filtered.isEmpty
          ? SliverFillRemaining(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                const Text('💡', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Nenhuma ideia ainda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Toque em + para capturar uma',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
              ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildIdeaCard(ctx, filtered[i]),
                childCount: filtered.length))),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context,
          isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const CreateIdeaForm()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black)));
  }

  Widget _hChip(IdeaHorizon? h, String label) {
    final sel = _filterHorizon == h;
    return Padding(padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterHorizon = h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
  }

  String _horizonLabel(IdeaHorizon h) => switch (h) {
    IdeaHorizon.now        => '🔥 Agora',
    IdeaHorizon.soon       => '⚡ Em breve',
    IdeaHorizon.someday    => '☁️ Um dia',
    IdeaHorizon.noDeadline => '∞ Sem prazo',
  };

  Widget _buildIdeaCard(BuildContext context, Idea idea) {
    return ObjectActionWrapper(object: idea,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => UniversalDetailView(object: idea))),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(idea.emoji ?? '💡', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(idea.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (idea.body != null && idea.body!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(idea.body!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _horizonBadge(idea.horizon),
                if (idea.priority != null) ...[
                  const SizedBox(width: 6),
                  _priorityDot(idea.priority!),
                ],
                const Spacer(),
                if (!idea.isConverted)
                  GestureDetector(
                    onTap: () => _showConvertSheet(context, idea),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                      child: const Text('Converter →', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.info))))
                else
                  Text('→ ${idea.convertedToType}',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context))),
              ]),
            ])),
          ]))));
  }

  Widget _horizonBadge(IdeaHorizon h) {
    final (label, color) = switch (h) {
      IdeaHorizon.now        => ('🔥 Agora',    AppColors.error),
      IdeaHorizon.soon       => ('⚡ Em breve', AppColors.warning),
      IdeaHorizon.someday    => ('☁️ Um dia',   AppColors.info),
      IdeaHorizon.noDeadline => ('∞ Sem prazo', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)));
  }

  Widget _priorityDot(TaskPriority p) {
    final color = switch (p) {
      TaskPriority.critical => AppColors.error,   TaskPriority.high => AppColors.warning,
      TaskPriority.medium   => AppColors.info,     TaskPriority.low  => AppColors.textMuted,
    };
    return Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  void _showConvertSheet(BuildContext context, Idea idea) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Converter "${idea.title}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Notas e organizers serão mantidos.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 16),
          _convertTile(ctx, idea, 'Task',    Icons.check_circle_outline_rounded, AppColors.primary,
            'Cria tarefa com título e prioridade',
            () => CreateTaskForm(initialTitle: idea.title, initialNotes: idea.body,
              initialPriority: idea.priority, initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Projeto', Icons.folder_outlined, AppColors.habitPurple,
            'Cria projeto no Organize',
            () => CreateProjectForm(initialTitle: idea.title, initialDescription: idea.body,
              initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Meta',    Icons.flag_outlined, AppColors.habitGreen,
            'Cria uma goal',
            () => CreateGoalForm(initialTitle: idea.title, initialNotes: idea.body,
              initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Nota',    Icons.description_outlined, AppColors.info,
            'Cria nota com o conteúdo da ideia',
            () => CreateNoteForm(initialTitle: idea.title, initialBody: idea.body,
              initialOrganizers: idea.organizers, initialTags: idea.tags)),
        ])));
  }

  Widget _convertTile(BuildContext ctx, Idea idea, String label,
      IconData icon, Color color, String sub, Widget Function() formBuilder) {
    return ListTile(
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
      onTap: () async {
        Navigator.pop(ctx);
        final result = await Navigator.push<dynamic>(context,
          MaterialPageRoute(builder: (_) => formBuilder()));
        if (result != null && mounted) {
          await ref.read(ideasProvider.notifier).updateIdea(
            idea.copyWith(convertedToType: label.toLowerCase(), convertedToId: result.id));
        }
      });
  }
}
```
Integração com CreateMenu:
```dart
// Em create_menu_sheet.dart, na aba Capture:
_captureItem(icon: '💡', label: 'Ideia', subtitle: 'Captura rápida, converte depois',
  onTap: () {
    Navigator.pop(context);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateIdeaForm());
  }),
```
---
D4 — Mercado (Lista de Compras)
O que é: Tipo de objeto dedicado para listas de compras. A Laura precisa de algo ultra-rápido: abrir, digitar, Enter, próximo item. E funcionar como widget nativo no Android onde dá para marcar itens sem abrir o app.
Por que não usar Note/Collection ou Task: Note/collection não tem widget nativo de checklist com sync, não tem agrupamento por categoria. Task seria pesado demais (deadline, priority, stage). Shopping precisa de UX própria: Enter = novo item, marcar = tachar e sumir, categorias para organizar na loja.
Tela de lista individual — `lib/ui/screens/shopping_list_screen.dart` — CRIAR NOVO:
```dart
class ShoppingListScreen extends ConsumerStatefulWidget {
  final ShoppingList list;
  final bool autoFocus;
  const ShoppingListScreen({super.key, required this.list, this.autoFocus = false});
  @override ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _inputController = TextEditingController();
  final _inputFocus      = FocusNode();
  bool    _showChecked     = false;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _inputFocus.requestFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider);
    final list  = lists.firstWhere((l) => l.id == widget.list.id, orElse: () => widget.list);
    final activeItems  = list.activeItems;
    final checkedItems = list.checkedItems;

    // Agrupar por categoria
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in activeItems) {
      (grouped[item.category ?? 'Outros'] ??= []).add(item);
    }
    final displayGroups = _filterCategory != null
      ? {_filterCategory!: grouped[_filterCategory!] ?? []}
      : grouped;

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(list.emoji ?? '🛒', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(list.title),
        ]),
        actions: [
          if (checkedItems.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.cleaning_services_rounded, size: 16),
              label: Text('Limpar (${checkedItems.length})'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              onPressed: () => _clearChecked(list)),
        ]),
      body: Column(children: [
        // Campo de captura sempre visível
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppTheme.cardFillColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)),
          child: Row(children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('🛒', style: TextStyle(fontSize: 18))),
            Expanded(child: TextField(
              controller: _inputController, focusNode: _inputFocus,
              decoration: const InputDecoration(
                hintText: 'Adicionar item…', border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14)),
              textInputAction: TextInputAction.done,
              onSubmitted: (val) => _addItem(list, val))),
            IconButton(icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () => _addItem(list, _inputController.text)),
          ])),

        // Chips de categoria (só se há mais de 1)
        if (grouped.keys.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _catChip(null, 'Todos'),
                ...grouped.keys.map((cat) => _catChip(cat, cat)),
              ]))),

        const SizedBox(height: 4),

        // Lista de itens
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            // Itens ativos por categoria
            ...displayGroups.entries.expand((entry) => [
              if (displayGroups.length > 1)
                Padding(padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(entry.key, style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.10,
                    color: AppTheme.textMutedColor(context)))),
              ...entry.value.map((item) => _buildItemTile(list, item, checked: false)),
            ]),

            // Itens marcados (colapsável)
            if (checkedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showChecked = !_showChecked),
                child: Row(children: [
                  Icon(_showChecked ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppTheme.textMutedColor(context)),
                  const SizedBox(width: 4),
                  Text('${checkedItems.length} marcados',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
                ])),
              if (_showChecked)
                ...checkedItems.map((item) => _buildItemTile(list, item, checked: true)),
            ],
          ])),
      ]));
  }

  Widget _catChip(String? cat, String label) {
    final sel = _filterCategory == cat;
    return Padding(padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
  }

  Widget _buildItemTile(ShoppingList list, ShoppingItem item, {required bool checked}) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_rounded, color: AppColors.error)),
      onDismissed: (_) => _deleteItem(list, item),
      child: InkWell(
        onTap: () => ref.read(shoppingListsProvider.notifier).toggleItem(list.id, item.id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Container(width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: checked ? AppColors.primary : AppTheme.dividerColor(context), width: 2),
                color: checked ? AppColors.primary : Colors.transparent),
              child: checked ? const Icon(Icons.check_rounded, size: 14, color: Colors.black) : null),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                decoration: checked ? TextDecoration.lineThrough : null,
                color: checked ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context))),
              if (item.quantity != null)
                Text(item.quantity!,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
            ])),
          ]))));
  }

  void _addItem(ShoppingList list, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;
    // Detectar quantidade: "2 kg de arroz" → qty: "2 kg", name: "arroz"
    final qtyMatch = RegExp(
      r'^(\d+[\s,.]?\d*\s*(?:kg|g|l|ml|un|caixa|pote|cx|und)?\s+)(.+)',
      caseSensitive: false).firstMatch(trimmed);
    final name     = qtyMatch?.group(2)?.trim() ?? trimmed;
    final quantity = qtyMatch?.group(1)?.trim();
    ref.read(shoppingListsProvider.notifier).addItem(list.id,
      ShoppingItem(id: const Uuid().v4(), name: name, quantity: quantity, order: list.items.length));
    _inputController.clear();
    _inputFocus.requestFocus(); // mantém foco para próximo item
  }

  void _deleteItem(ShoppingList list, ShoppingItem item) {
    final updated = list.copyWith(
      items: list.items.where((i) => i.id != item.id).toList(), updatedAt: DateTime.now());
    ref.read(shoppingListsProvider.notifier).updateList(updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${item.name}" removido'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () {
        ref.read(shoppingListsProvider.notifier).addItem(list.id, item);
      })));
  }

  void _clearChecked(ShoppingList list) async {
    final toRestore = list.checkedItems.toList();
    await ref.read(shoppingListsProvider.notifier).clearChecked(list.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${toRestore.length} item(s) removidos'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () async {
        final curr = ref.read(shoppingListsProvider).firstWhere((l) => l.id == list.id);
        await ref.read(shoppingListsProvider.notifier)
          .updateList(curr.copyWith(items: [...curr.items, ...toRestore]));
      })));
  }
}
```
Tela de todas as listas — `lib/ui/screens/shopping_screen.dart` — CRIAR NOVO:
```dart
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(shoppingListsProvider).where((l) => !l.archived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mercado'), centerTitle: true),
      body: lists.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛒', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Nenhuma lista ainda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            FilledButton.icon(icon: const Icon(Icons.add_rounded),
              label: const Text('Criar lista'),
              onPressed: () => _createList(context, ref)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: lists.length,
            itemBuilder: (ctx, i) => _buildListCard(ctx, ref, lists[i])),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black)));
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, ShoppingList list) {
    final total   = list.totalCount;
    final checked = list.checkedCount;
    final pct     = total > 0 ? checked / total : 0.0;

    return InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ShoppingListScreen(list: list))),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(list.emoji ?? '🛒', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(list.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('$checked/$total', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700,
              color: pct >= 1.0 ? AppColors.habitGreen : AppColors.primary)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: AppTheme.surfaceVariantColor(context),
              valueColor: AlwaysStoppedAnimation(
                pct >= 1.0 ? AppColors.habitGreen : AppColors.primary))),
          if (list.activeItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              list.activeItems.take(3).map((i) => i.name).join(', ')
              + (list.activeItems.length > 3 ? '…' : ''),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
          ],
        ])));
  }

  void _createList(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova lista'),
        content: TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ex: Mercado semana, Feira, Farmácia')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Criar')),
        ]));
    if (name == null || name.isEmpty) return;
    final list = ShoppingList(id: const Uuid().v4(), title: name,
      createdAt: DateTime.now(), updatedAt: DateTime.now());
    await ref.read(shoppingListsProvider.notifier).addList(list);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ShoppingListScreen(list: list, autoFocus: true)));
    }
  }
}
```
Widget nativo Android — `lib/services/widget_service.dart`:
```dart
static const _shoppingProvider = 'CitrineShoppingWidgetProvider';

static Future<void> updateShoppingWidget(ShoppingList list) async {
  await _saveJson('citrine_shopping_${list.id}', {
    'listId':   list.id, 'title': list.title, 'emoji': list.emoji ?? '🛒',
    'items': list.activeItems.take(10).map((i) => {
      'id': i.id, 'name': i.name, 'qty': i.quantity, 'checked': i.isChecked,
    }).toList(),
    'checkedCount': list.checkedCount, 'totalCount': list.totalCount,
    'linkUri':  'citrine:///shopping/${list.id}',
    'addUri':   'citrine:///shopping/${list.id}/add',
    'checkUri': 'citrine:///shopping/${list.id}/check/',
  });
  await _update(_shoppingProvider);
}
```
Widget nativo (Kotlin) deve: mostrar emoji + título, lista de até 8 itens com checkbox tapável, item marcado some após 2s com animação de tachado, botão + no canto, barra de progresso X/Y no rodapé.
Deep links — adicionar ao router:
```dart
'/shopping/:listId'              → ShoppingListScreen(listId)
'/shopping/:listId/add'          → ShoppingListScreen(listId, autoFocus: true)
'/shopping/:listId/check/:itemId' → toggleItem sem abrir tela, confirmar com vibração
```
Integração no CreateMenu:
```dart
_captureItem(icon: '🛒', label: 'Mercado', subtitle: 'Adicionar à lista de compras',
  onTap: () {
    Navigator.pop(context);
    final lists = ref.read(shoppingListsProvider).where((l) => !l.archived).toList();
    if (lists.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ShoppingListScreen(list: lists.first, autoFocus: true)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingScreen()));
    }
  }),
```

---
CHECKLIST COMPLETO DE IMPLEMENTAÇÃO
---
🔴 CRÍTICO — quebra dados ou funcionalidade central
[x] `obsidian_service.dart` — `encoding: utf8` em read/write (A4)
[x] `google_drive_sync_service.dart` — encoding utf8 (A4)
[x] `backup_service.dart` — encoding utf8 (A4)
[x] Strings corrompidas `Ã§`, `Ã£`, emojis em `home_screen.dart` → corrigidos para UTF-8 real (A4d) ✅ 14-06-26
[x] `planner_screen.dart` — `timeBlocks:` já passado ao `TimeLineDayView` (C4a) ✅ já estava OK
[x] `notes_screen.dart` — `_formatDate` null-safe + zero-pad; expand Outline/Collection já correto (C1-expand) ✅ 14-06-26
[x] `goals_screen.dart` — `_goalColor` com try-catch (C5e) ✅ 14-06-26
[x] `universal_detail_view.dart` — `LinkedObjectsSection` adicionada ao Resource com callbacks onAdd/onRemove persistindo via `resourcesProvider` (E7) ✅ 14-06-26
---
🟠 ALTA — base compartilhada (desbloqueia várias telas)
[x] `lib/models/saved_filter.dart` — criar arquivo novo (A1)
[x] `lib/providers/settings_provider.dart` — `userName`, `accentColor`, `savedFiltersRaw`, métodos (A2)
[x] `lib/services/markdown_parser.dart` — `HighlightItem` + `extractHighlights` (A3)
[x] `lib/ui/widgets/filter_sort_sheet.dart` — criar arquivo novo (B1)
---
🟡 ALTA — telas principais com bugs ou UX quebrada
[x] `notes_screen.dart` — grid view, chips dinâmicos, fix `_formatDate` zero-pad (C1) ✅
[x] `resources_screen.dart` — shelf + highlights feed (C2) ✅
[x] `home_screen.dart` — saudação, quote com highlights, fix pull-to-search debounce (C3) ✅
[x] `planner_screen.dart` — toggle timeline/lista, setas de navegação, fix moodSlug, fix tracker (C4) ✅
[x] `goals_screen.dart` — ConsumerStatefulWidget, barra global, +10% inline, sem IntrinsicHeight (C5) ✅
[x] `habits_screen.dart` — fix semana na segunda, seção sem agendamento, fix _SummaryChip (C6) ✅
[x] `inbox_screen.dart` — campo sempre visível, swipe triagem (C7) ✅
[x] `settings_screen.dart` — grupos visuais, campo de nome (C8) ✅
[x] `social_screen.dart` — SortMode enum, overlay multi-select, arquivar com undo (C18) ✅
[x] `object_action_wrapper.dart` — fix overflow popup (C18d) ✅
[x] `create_social_post_form.dart` — detecção duplicata, título editável (C19) ✅
---
🟢 MÉDIA — qualidade de vida e features novas
[x] `appearance_screen.dart` — swatches interativos + persistência (C9) ✅
[x] `journal_screen.dart` — banner filtros ativos, busca expansível (C10) ✅
[x] `people_screen.dart` — busca, toggle lista/grid, ações contato, badge pendente (C11) ✅
[x] `trackers_screen.dart` — último valor no card, botão +, remover Analysis duplicado (C12) ✅
[x] `timeline_screen.dart` — fix título, paginação (C13) ✅
[x] `organizer_detail_screen.dart` — contagem nas tabs, botões separados (C14) ✅
[x] `day_theme_screen.dart` — botões explícitos, preview visual de blocos (C15) ✅
[x] `search_screen.dart` — recentes persistidos, chip de tipo ativo, actions contextuais (C16) ✅
[x] Fixes globais de overflow: VENCIDA badge, editModeHint, SummaryChip, resize handle (C20) ✅
[x] Feature Quitting Habits — card Evitando, sem checkbox, botão Recaída, filtros planner/calendar (D1) ✅
[x] Feature Tracker de Saúde — `lib/models/tracker_model.dart`, `create_tracker_form.dart`, `health_alerts_provider.dart`, `health_alerts_strip.dart`, `notification_service.dart` (D2) ✅ 16-06-26
---
⚪ BAIXA — polimento e features novas complexas
[x] `app_shell.dart` — labels onlyShowSelected, badges na nav, tooltip FAB (C17) ✅
[x] `lib/providers/badge_counts_provider.dart` — criar (A5) ✅
[x] `lib/ui/widgets/skeleton_list.dart` — criar (B2) ✅
[x] Feature Ideias — `idea_model.dart`, `ideasProvider`, `create_idea_form.dart`, `ideas_screen.dart`, integração CreateMenu + busca (D3) ✅ 16-06-26
[x] Feature Mercado — `shopping_list_model.dart`, `shoppingListsProvider`, `shopping_list_screen.dart`, `shopping_screen.dart`, widget nativo Android, deep links (D4) ✅ 16-06-26
---
Dependências entre itens
```
A1 saved_filter.dart
  └── A2 settings_provider (filtersFor, upsertSavedFilter)
        └── B1 FilterSortSheet
              ├── C1 notes_screen (chips dinâmicos)
              ├── C2 resources_screen (chips dinâmicos)
              ├── C5 goals_screen (filtros)
              ├── C11 people_screen (filtros)
              └── C13 timeline_screen (filtros)

A3 extractHighlights
  ├── C2 resources_screen (highlights feed)
  └── C3 home_screen (quote do dia)

A5 badge_counts_provider
  └── C17 app_shell (badges na nav)

D2 TrackerField alerta
  ├── A8 health_alerts_provider
  └── B3 health_alerts_strip
        └── C6 habits_screen (HealthAlertsStrip no topo)

D3 Ideias
  └── A6.4 idea_model + A7 ideasProvider
        └── D3 create_idea_form + ideas_screen

D4 Mercado
  └── A6.5 shopping_list_model + A7 shoppingListsProvider
        └── D4 shopping screens + widget nativo
```

---
BLOCO E — COMPLEMENTOS E VERIFICAÇÕES
> Specs adicionais para os pedidos de 04–13/06 que não estavam cobertos no Bloco A–D.
VERIFICAÇÃO E COMPLEMENTO — Pedidos de 04–13/06
> Para cada pedido: status (✅ coberto / ⚠️ parcial / ❌ ausente), onde encontrar no doc principal, e o complemento necessário.
---
PEDIDO 1 — Tracker: dias sem dado não aparecem como zero no gráfico
Mensagem: "quando eu nao colocar nada no dia no tracker e pedir uma analise, ao inves de aparecer como se fosse 0 no grafico, nao ter a bolinha e interromper a linha, aí voltar quando tiver dado de novo"
Status: ❌ ausente no doc principal — a seção de TrackerDetailScreen menciona "gráficos por campo" mas não especifica o comportamento de dados ausentes.
Viável agora: Sim, com o `citrine_chart.dart` existente ou usando `fl_chart`/`recharts`. É uma mudança de lógica de dados, não requer novo modelo.
Spec complementar — E1: Gaps em gráficos de tracker
O problema: Quando o usuário não registra um campo num dia, o dado é `null`. Hoje o gráfico provavelmente interpola para zero ou conecta pontos distantes, fazendo parecer que o valor foi zero — o que é falso e distorce a análise.
Comportamento correto:
Dia com registro → ponto no gráfico
Dia sem registro → sem ponto, sem bolinha, linha interrompida
Quando os dados voltarem → linha recomeça daquele ponto
Como implementar — na construção do dataset do gráfico:
```dart
// Em TrackerDetailScreen ou no widget de gráfico, ao montar os dados:

/// Converte registros em série de pontos com gaps explícitos.
/// Retorna lista de [FlSpot] onde dias sem dado ficam de fora da série,
/// e uma lista separada de spans (segmentos contínuos) para desenhar
/// linhas que se interrompem nos gaps.
List<List<FlSpot>> buildSparseLineSeries({
  required List<TrackingRecord> records,
  required String fieldName,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  // Mapear data → valor
  final Map<String, double> byDate = {};
  for (final r in records) {
    final key = _dateKey(r.date);
    final val = (r.fieldValues[fieldName] as num?)?.toDouble();
    if (val != null) byDate[key] = val;
  }

  // Iterar dia a dia e criar segmentos contínuos
  final segments = <List<FlSpot>>[];
  var currentSegment = <FlSpot>[];

  for (var d = rangeStart;
       !d.isAfter(rangeEnd);
       d = d.add(const Duration(days: 1))) {
    final key = _dateKey(d);
    final val = byDate[key];
    final x   = d.difference(rangeStart).inDays.toDouble();

    if (val != null) {
      currentSegment.add(FlSpot(x, val));
    } else {
      // Gap: finalizar segmento atual se tiver pontos
      if (currentSegment.isNotEmpty) {
        segments.add(List.from(currentSegment));
        currentSegment = [];
      }
    }
  }
  if (currentSegment.isNotEmpty) segments.add(currentSegment);
  return segments; // cada segmento vira uma LineChartBarData separada
}

String _dateKey(DateTime d) =>
  '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
```
No widget de gráfico (fl_chart):
```dart
// Cada segmento vira uma LineChartBarData independente com a mesma cor/estilo:
final segments = buildSparseLineSeries(
  records: fieldRecords, fieldName: field.name,
  rangeStart: rangeStart, rangeEnd: rangeEnd);

LineChart(LineChartData(
  lineBarsData: segments.map((segment) => LineChartBarData(
    spots: segment,
    isCurved: true,
    color: AppColors.primary,
    barWidth: 2,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
        radius: 4, color: AppColors.primary,
        strokeWidth: 2, strokeColor: Colors.white)),
    belowBarData: BarAreaData(
      show: true,
      color: AppColors.primary.withValues(alpha: 0.08)),
  )).toList(),
  // ... restante das configs
))
```
Se o app usa `citrine_chart.dart` próprio em vez de fl_chart, aplicar a mesma lógica: construir `segments` como acima e passar como lista de séries separadas ao `CitrineChart`, que deve iterar e desenhar cada uma independentemente.
Regra adicional: No tooltip do ponto, mostrar a data real e o valor. Para dias sem dado (quando o usuário toca na área vazia), não mostrar tooltip — ou mostrar "sem registro neste dia".
Onde adicionar: `lib/ui/screens/trackers_screen.dart` ou (preferencialmente) em `lib/ui/screens/universal_detail_view.dart` no bloco de Tracker, e em qualquer widget de gráfico dentro de `lib/ui/widgets/citrine_chart.dart`.
---
PEDIDO 2 — Hierarquia de Organizers: arquivo nota+área, aviso de conflito
Mensagem: "definir hierarquia de organizer. quando um mesmo arquivo se encaixa no que faz uma nota e uma área, vira o que? como isso é definido? tem um aviso dessa confusao? pede pra eu definir o que acontece?"
Status: ❌ ausente no doc principal — mencionado superficialmente nos docs anteriores de gap analysis mas não foi incluído no `citrine_specs_completo.md`.
Viável: Sim, após implementação do vault provider e parser de markdown.
Spec complementar — E2: Resolução de conflito Nota/Organizer
E2.1 — Regras de resolução de tipo
Ao parsear um arquivo `.md` do vault, o `MarkdownParser` / `VaultProvider` aplica estas regras em ordem:
Prioridade	Condição	Resultado
1	`type: organizer` no frontmatter	→ Organizer
2	`type: note` no frontmatter	→ Note
3	Tem `organizer_type` no frontmatter	→ Organizer
4	Tem `note_subtype` no frontmatter	→ Note
5	Body tem >50 chars que não são só links	→ Note (com body descritivo)
6	Outros objetos têm `organizers: [[este-arquivo]]`	→ Organizer
7	Nenhum critério	→ Organizer label (fallback)
Conflito é detectado quando:
`type: organizer` E body tem >50 chars de texto corrido (não só links)
`type: note` E outros objetos referenciam este arquivo em `organizers:`
Tem `organizer_type` E `note_subtype` simultaneamente
Tem `organizer_type` E body substantivo (não só links)
E2.2 — Provider de conflitos
Arquivo: `lib/providers/vault_provider.dart` — adicionar:
```dart
/// Um arquivo que satisfaz critérios de Nota E de Organizer ao mesmo tempo.
class ObjectConflict {
  final String fileSlug;
  final String title;
  final String currentType;      // 'note' | 'organizer'
  final List<String> reasons;   // por que é ambíguo
  const ObjectConflict({
    required this.fileSlug, required this.title,
    required this.currentType, required this.reasons,
  });
}

final conflictingObjectsProvider = Provider<List<ObjectConflict>>((ref) {
  final allObjects = ref.watch(allObjectsProvider);
  final conflicts  = <ObjectConflict>[];

  for (final obj in allObjects) {
    final reasons = <String>[];

    if (obj is Note) {
      // Note sendo referenciada como organizer por outros objetos
      final referencedAsOrganizer = allObjects.any((o) =>
        o != obj &&
        (o as dynamic).organizers?.any((org) => org.slug == obj.slug) == true);
      if (referencedAsOrganizer) {
        reasons.add('Esta nota é usada como organizer por outros objetos');
      }
      // Note com organizer_type no frontmatter (caso de import do Obsidian)
      if ((obj as dynamic).rawFrontmatter?['organizer_type'] != null) {
        reasons.add('Tem organizer_type no frontmatter mas é tratada como nota');
      }
    }

    if (obj is Organizer) {
      // Organizer com body substantivo
      final body = (obj as dynamic).description ?? '';
      final nonLinkContent = body.replaceAll(RegExp(r'\[\[.*?\]\]'), '').trim();
      if (nonLinkContent.length > 80) {
        reasons.add('Tem conteúdo textual substancial além de links');
      }
      // Organizer com note_subtype
      if ((obj as dynamic).rawFrontmatter?['note_subtype'] != null) {
        reasons.add('Tem note_subtype no frontmatter mas é tratado como organizer');
      }
    }

    if (reasons.isNotEmpty) {
      conflicts.add(ObjectConflict(
        fileSlug: obj.slug, title: obj.title,
        currentType: obj is Note ? 'note' : 'organizer',
        reasons: reasons));
    }
  }

  return conflicts;
});
```
E2.3 — Banner de conflito no UniversalDetailView
Arquivo: `lib/ui/screens/universal_detail_view.dart`
Adicionar no início do body (após o SliverAppBar, antes das propriedades):
```dart
// Verificar se este objeto tem conflito:
final conflicts  = ref.watch(conflictingObjectsProvider);
final myConflict = conflicts.cast<ObjectConflict?>()
  .firstWhere((c) => c?.fileSlug == object.slug, orElse: () => null);

if (myConflict != null)
  SliverToBoxAdapter(child: _buildConflictBanner(myConflict)),

Widget _buildConflictBanner(ObjectConflict conflict) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.35))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Arquivo ambíguo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.warning))),
      ]),
      const SizedBox(height: 6),
      ...conflict.reasons.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          Expanded(child: Text(r, style: TextStyle(
            fontSize: 12, color: AppTheme.textSecondaryColor(context)))),
        ]))),
      const SizedBox(height: 10),
      Text('Este arquivo se comporta como ${conflict.currentType == "note" ? "nota" : "organizer"}. '
        'Deseja manter assim ou converter?',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () {/* manter como está — descartar aviso por 30 dias */},
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5))),
          child: Text('Manter como ${conflict.currentType == "note" ? "nota" : "organizer"}'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(
          onPressed: () => _showConversionSheet(conflict),
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning.withValues(alpha: 0.9)),
          child: Text('Converter para ${conflict.currentType == "note" ? "organizer" : "nota"}'))),
      ]),
    ]));
}
```
E2.4 — Sheet de conversão
```dart
void _showConversionSheet(ObjectConflict conflict) {
  showModalBottomSheet(context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Converter arquivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (conflict.currentType == 'note') ...[
          // Nota → Organizer
          Text('O corpo da nota virará o campo "descrição" do organizer. '
            'Os links wiki [[...]] continuarão funcionando.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 12),
          Text('Tipo de organizer:', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 8),
          // Chips de tipo de organizer (area, project, label, etc.)
          Wrap(spacing: 8, children: ['area', 'project', 'label', 'activity', 'family']
            .map((t) => _orgTypeChip(t)).toList()),
        ] else ...[
          // Organizer → Nota
          Text('A descrição do organizer virará o corpo da nota. '
            'Objetos que usam este arquivo como organizer continuarão vinculados.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 12),
          // Aviso de impacto
          Consumer(builder: (ctx, ref, _) {
            final affected = ref.watch(allObjectsProvider).where((o) =>
              (o as dynamic).organizers?.any((org) => org.slug == conflict.fileSlug) == true
            ).toList();
            if (affected.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${affected.length} objeto(s) têm este arquivo como organizer. '
                'Eles continuarão vinculados mas o arquivo passará a ser exibido como nota.',
                style: TextStyle(fontSize: 12, color: AppColors.info)));
          }),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _performConversion(conflict);
          },
          child: const Text('Confirmar conversão'))),
      ])));
}

Future<void> _performConversion(ObjectConflict conflict) async {
  // Reescrever o frontmatter do arquivo .md via ObsidianService
  // Atualizar o type: 'note' ou 'organizer'
  // Se Nota→Organizer: mover body para description, limpar body
  // Se Organizer→Nota: mover description para body
  // Recarregar o vault (forçar re-parse)
  await ref.read(obsidianServiceProvider).convertObjectType(
    slug: conflict.fileSlug,
    targetType: conflict.currentType == 'note' ? 'organizer' : 'note',
  );
  if (mounted) Navigator.pop(context);
}
```
Suprimir aviso por 30 dias — salvar em `AppSettings.suppressedConflicts: Map<String, DateTime>`:
```dart
// Em settingsProvider, adicionar:
final Map<String, DateTime> suppressedConflicts; // slug → data de supressão

// Ao verificar conflito:
final suppressed = settings.suppressedConflicts[obj.slug];
final isSuppressed = suppressed != null &&
  DateTime.now().difference(suppressed).inDays < 30;
if (!isSuppressed) { /* mostrar banner */ }
```
---
PEDIDO 3 — Arquitetura de informação: organizer lê propriedades e corpo
Mensagem: "quando um arquivo é um organizer, o app precisa ler oq está nas propriedades e no corpo da nota, e mostrar. exemplo: o que significa quando uma área tem vários links? quando esses links são notas, elas precisam aparecer em items. quando são tarefas, eventos, hábitos, etc com checks, momentos que ocorrem, precisam aparecer na timeline dessa área. quando são outros organizers, precisam aparecer em children/suborganizers."
Status: ❌ ausente no doc principal. Mencionado vagamente no gap analysis original mas não foi especificado com detalhe suficiente.
Viável: Sim, após implementação do wiki-link resolver.
Spec complementar — E3: Arquitetura de informação por tipo de objeto
E3.1 — Wiki-link resolver (base necessária)
Antes de tudo, o app precisa de um resolver que converte `[[slug]]` em `ContentObject`:
```dart
// Adicionar em lib/services/markdown_parser.dart:
static List<String> extractWikiLinks(String text) {
  final matches = RegExp(r'\[\[([^\]]+)\]\]').allMatches(text);
  return matches.map((m) => m.group(1)!.trim()).toList();
}

// Provider derivado — resolve slugs para objetos reais:
// lib/providers/wiki_link_resolver_provider.dart (NOVO)
final wikiLinkResolverProvider = Provider<Map<String, ContentObject>>((ref) {
  final all = ref.watch(allObjectsProvider);
  return {for (final obj in all) obj.slug: obj};
});

// Uso:
final resolver = ref.watch(wikiLinkResolverProvider);
final linkedObj = resolver['nome-da-nota']; // → ContentObject ou null
```
E3.2 — Regras de exibição por tipo de link no body
Quando um `Organizer` tem wiki-links `[[...]]` no body/description, o app classifica cada link resolvido e o exibe na aba correta:
Tipo do objeto linkado	Aparece em
`Note`	Aba Items
`Task`	Aba Timeline (com data base = `deadline` ou `createdAt`) + Aba Items
`Habit`	Aba Timeline (por data de completion)
`JournalEntry`	Aba Timeline (por `date`)
`TrackingRecord`	Aba Timeline (por `date`)
`Organizer`	Aba Children/Sub-organizers
`Resource`	Aba Items
`SocialPost`	Aba Items
`Goal`	Aba Items + progresso inline
`Project`	Aba Children
`Person`	Aba Items (com último contato)
`Reminder`	Aba Items
`Idea`	Aba Items
`ShoppingList`	Aba Items
E3.3 — OrganizerDetailScreen: leitura completa
Arquivo: `lib/ui/screens/organizer_detail_screen.dart` — REFATORAR significativamente
Estado atual: O `associatedItemsProvider` busca objetos que têm `organizers: [[este-slug]]` no frontmatter. Ele não lê os wiki-links do body do próprio organizer.
Estado novo: Dois tipos de itens associados:
Incoming: objetos que têm `organizers: [[este-slug]]` → já existe
Outgoing (novo): objetos linkados via `[[wiki-link]]` no body/description do organizer
```dart
// Provider expandido:
final organizerAssociatedProvider = FutureProvider.family<_OrganizerItems, String>((ref, slug) async {
  final resolver = ref.watch(wikiLinkResolverProvider);
  final all      = ref.watch(allObjectsProvider);

  // 1. Incoming: objetos que referenciam este organizer
  final incoming = all.where((o) =>
    (o as dynamic).organizers?.any((org) => org.slug == slug) == true
  ).toList();

  // 2. Outgoing: objetos linkados no body deste organizer
  final organizer = all.firstWhere((o) => o.slug == slug);
  final body      = (organizer as dynamic).description ?? '';
  final slugsInBody = MarkdownParser.extractWikiLinks(body);
  final outgoing  = slugsInBody
    .map((s) => resolver[s])
    .whereType<ContentObject>()
    .where((o) => !incoming.contains(o)) // evitar duplicatas
    .toList();

  final combined = [...incoming, ...outgoing];

  // Classificar por tipo
  return _OrganizerItems(
    timelineItems: combined.where((o) =>
      o is Task || o is JournalEntry || o is TrackingRecord ||
      o is Habit || o is PomodoroSession
    ).toList()
      ..sort((a, b) => _baseTime(a).compareTo(_baseTime(b))),
    noteItems: combined.whereType<Note>().toList(),
    resourceItems: combined.whereType<Resource>().toList(),
    socialItems: combined.whereType<SocialPost>().toList(),
    goalItems: combined.whereType<Goal>().toList(),
    ideaItems: combined.whereType<Idea>().toList(),
    childOrganizers: combined.where((o) => o is Organizer || o is Project).toList(),
    people: combined.whereType<Person>().toList(),
  );
});

class _OrganizerItems {
  final List<ContentObject> timelineItems;
  final List<ContentObject> noteItems;
  final List<ContentObject> resourceItems;
  final List<ContentObject> socialItems;
  final List<ContentObject> goalItems;
  final List<ContentObject> ideaItems;
  final List<ContentObject> childOrganizers;
  final List<ContentObject> people;
  // ...
}

DateTime _baseTime(ContentObject o) {
  if (o is Task)         return o.deadline ?? o.createdAt ?? DateTime(0);
  if (o is JournalEntry) return o.date;
  if (o is TrackingRecord) return o.date;
  return (o as dynamic).createdAt ?? DateTime(0);
}
```
Tabs da OrganizerDetailScreen reformuladas:
```
Tab 1: TIMELINE
  → Items com data: tasks, journal entries, records, habit completions
  → Agrupado por data (hoje, ontem, esta semana, mais antigos)
  → Ordenado por baseTime desc

Tab 2: ITENS
  → Notes, Resources, SocialPosts, Goals, Ideas, Pessoas, Reminders
  → Sub-seções por tipo com headers

Tab 3: SUB-ORGANIZERS
  → Organizers e Projects filhos (parentId == este slug OU linkados no body)
  → Cards compactos com contagem de itens próprios

Tab 4: DESCRIÇÃO (nova, aparece só se description não vazia)
  → Markdown renderizado do body/description do organizer
  → Wiki-links clicáveis inline
```
Tab DESCRIÇÃO — renderização com links clicáveis:
```dart
// Na aba Descrição:
MarkdownBodyView(
  content: organizer.description ?? '',
  onWikiLinkTap: (slug) {
    final resolver = ref.read(wikiLinkResolverProvider);
    final target   = resolver[slug];
    if (target != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => UniversalDetailView(object: target)));
    }
  })
```
O `MarkdownBodyView` existente precisa aceitar um callback `onWikiLinkTap`. Se não aceita, adicionar o parâmetro.
E3.4 — Regras por tipo de organizer
Área (type: area):
Description = propósito da área ("Por que esta área existe na minha vida?")
Timeline = tudo que acontece dentro dessa área ordenado por data
Items = notas, recursos, metas relacionadas
Children = projetos e sub-áreas
Projeto (type: project):
Description = objetivo e contexto
Timeline = tasks com deadline, marcos concluídos
Items = notas de contexto, recursos de referência
Children = sub-projetos
Extra: barra de progresso de tasks (`finalized / total`)
Label/Tag (type: label):
Items = tudo que tem essa label, qualquer tipo
Sem timeline, sem children
People/Person:
Timeline = histórico de contatos (`ContactEvent`), tasks com participant, journal entries que mencionam
Items = notas sobre a pessoa, recursos compartilhados
Sem children
Activity (type: activity):
Timeline = todas as vezes que a atividade foi feita (habit completions, pomodoro sessions, tracking records)
Items = notas, recursos relacionados
E3.5 — BacklinksProvider expandido
O `backlinksProvider` atual só busca no frontmatter. Expandir para incluir menções no body:
```dart
// lib/providers/backlinks_provider.dart — EDITAR
final backlinksProvider = Provider.family<List<ContentObject>, String>((ref, slug) {
  final all      = ref.watch(allObjectsProvider);
  final resolver = ref.watch(wikiLinkResolverProvider);

  return all.where((obj) {
    // 1. Referenciado no frontmatter organizers:
    final inFrontmatter = (obj as dynamic).organizers
      ?.any((org) => org.slug == slug) ?? false;

    // 2. Mencionado no body/description via [[wiki-link]]:
    final body  = (obj as dynamic).body ?? (obj as dynamic).description ?? '';
    final links = MarkdownParser.extractWikiLinks(body);
    final inBody = links.contains(slug);

    return inFrontmatter || inBody;
  }).toList();
});
```
---
PEDIDO 4 — Social: duplicata ao salvar (banner + opções)
Mensagem: "no social tem uns que duplicam, ao salvar, identificar se é um link que ja existe, se sim ter um banner em cima dizendo que ja foi salvo no dia e horario X, e com a opção de editar ou nao fazer nada"
Status: ✅ Completamente coberto no doc principal — seção C19 (`create_social_post_form.dart`), subseção 19a "Detecção de duplicata". Implementação completa com enum `_DuplicateAction`, dialog de confirmação com 3 opções (não fazer nada / editar existente / salvar mesmo assim) e formatação de data.
Nada a complementar.
---
PEDIDO 5 — Como anotar ideias relacionadas a qualquer coisa no vault
Mensagem: "como anotar ideias? q podem ta relacionada a qqr coisa no vault"
Status: ✅ Completamente coberto no doc principal — seção D3 (Ideias como Tipo de Objeto). Inclui modelo `Idea`, formulário de captura rápida com `linkedSlugs` para vincular qualquer objeto do vault via wiki-links, tela de listagem, e conversão para Task/Projeto/Goal/Nota.
Nada a complementar.
---
PEDIDO 6 — Busca/link picker: aba para Social Posts, filtrar por plataforma e criador
Mensagem: "quando eu for pesquisar algo pra linkar ao que eu to criando/editando, tem q ter os posts do social, uma aba pra filtrar eles ordenado pela ultima modificação pra ficar mais facil de achar" + "mas tb preciso achar por plataforma, criador"
Status: ❌ ausente no doc principal — o `universal_search_picker.dart` não foi especificado com aba de Social.
Viável: Sim, após implementar os filtros base.
Spec complementar — E6: Social Posts no UniversalSearchPicker
Arquivo: `lib/ui/widgets/universal_search_picker.dart` — EDITAR
O que é: O picker que abre quando o usuário toca em "Vincular objeto" em qualquer form. Hoje provavelmente tem abas por tipo (Tudo, Tasks, Notes, Resources...) mas sem Social Posts.
Adicionar aba "Social":
```dart
// Na TabBar do picker, adicionar:
Tab(text: 'Social'),

// Na TabBarView correspondente:
_buildSocialTab(),

Widget _buildSocialTab() {
  final posts = ref.watch(socialPostsProvider);

  // Sub-filtros no topo da aba
  return Column(children: [
    // Barra de busca por título/handle/caption
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        onChanged: (v) => setState(() => _socialSearch = v),
        decoration: InputDecoration(
          hintText: 'Título, @handle, legenda…',
          prefixIcon: const Icon(Icons.search_rounded, size: 16),
          filled: true, fillColor: AppTheme.surfaceVariantColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero, isDense: true))),

    // Chips de plataforma
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _platformChip(null, 'Todas'),
          ...SocialPlatform.values.map((p) => _platformChip(p, p.name.toUpperCase())),
        ]))),

    // Chips de criador (extraídos dos posts disponíveis)
    if (_uniqueCreators(posts).isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _creatorChip(null, 'Todos'),
            ..._uniqueCreators(posts).map((h) => _creatorChip(h, '@$h')),
          ]))),

    const Divider(height: 1),

    // Lista ordenada por updatedAt desc
    Expanded(child: Builder(builder: (ctx) {
      var filtered = posts
        .where((p) => !p.archived)
        .where((p) => _socialPlatformFilter == null || p.platform == _socialPlatformFilter)
        .where((p) => _socialCreatorFilter == null || p.authorHandle == _socialCreatorFilter)
        .where((p) => _socialSearch.isEmpty ||
          p.title.toLowerCase().contains(_socialSearch.toLowerCase()) ||
          (p.authorHandle?.toLowerCase().contains(_socialSearch.toLowerCase()) ?? false) ||
          (p.caption?.toLowerCase().contains(_socialSearch.toLowerCase()) ?? false))
        .toList()
        ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));

      if (filtered.isEmpty) return Center(child: Text('Nenhum post encontrado',
        style: TextStyle(color: AppTheme.textMutedColor(context))));

      return ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final post = filtered[i];
          return ListTile(
            leading: _platformIcon(post.platform),
            title: Text(post.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${post.authorHandle != null ? "@${post.authorHandle}" : post.platform.name}'
              ' · ${_relativeDate(post.updatedAt ?? post.createdAt)}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
            onTap: () => Navigator.pop(context, post));
        });
    })),
  ]);
}

List<String> _uniqueCreators(List<SocialPost> posts) =>
  posts.map((p) => p.authorHandle).whereType<String>().toSet().toList()..sort();

Widget _platformChip(SocialPlatform? p, String label) {
  final sel = _socialPlatformFilter == p;
  return Padding(padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: () => setState(() => _socialPlatformFilter = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
}

Widget _creatorChip(String? handle, String label) {
  final sel = _socialCreatorFilter == handle;
  return Padding(padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: () => setState(() => _socialCreatorFilter = handle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.info.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? AppColors.info : AppTheme.textSecondaryColor(context))))));
}

// Estado adicional no picker:
SocialPlatform? _socialPlatformFilter;
String?         _socialCreatorFilter;
String          _socialSearch = '';
```
Onde o picker é chamado: Sempre que o usuário toca em "Vincular" em qualquer form (Task, Note, Resource, Idea, SocialPost próprio). A aba Social deve aparecer em todos esses contextos.
---
PEDIDO 7 — Resources: vincular e criar objeto não funciona
Mensagem: "nos resources quando vou em vincular e crio um objeto, nao acontece nada"
Status: ✅ Mencionado e especificado no doc principal — seção C (referenciado como bug crítico): "universal_detail_view.dart — callback de vincular objeto em Resource salva de volta ao resource". Está no checklist de CRÍTICO.
O código exato do fix está implícito mas não explicitado. Complementar:
Spec complementar — E7: Fix vincular objeto em Resource
Arquivo: `lib/ui/screens/universal_detail_view.dart`
No bloco de `_buildTypeSpecificContent` para `Resource`, localizar onde o `UniversalSearchPicker` (ou equivalente) é chamado e corrigir o callback:
```dart
// ANTES (provável — não salva):
onObjectSelected: (obj) {
  // vazio ou sem persistência
},

// DEPOIS:
onObjectSelected: (obj) async {
  if (obj == null || obj is! ContentObject) return;
  final resource = object as Resource;
  final updated  = resource.copyWith(
    linkedObjects: [
      ...(resource.linkedObjects ?? []),
      OrganizerReference(id: obj.id, title: obj.title, slug: obj.slug),
    ],
    updatedAt: DateTime.now());
  await ref.read(resourcesProvider.notifier).updateResource(updated);
  // Forçar rebuild mostrando o novo vínculo
  if (mounted) setState(() {});
},

// Se o picker permite criar novo objeto inline (CreateTaskForm, CreateNoteForm, etc.),
// garantir que ao retornar o objeto criado seja passado de volta:
final newObj = await Navigator.push<ContentObject>(context,
  MaterialPageRoute(builder: (_) => CreateTaskForm()));
if (newObj != null && mounted) {
  onObjectSelected(newObj);
}
```
---
PEDIDO 8 — Caracteres especiais bugados (ç, acentos)
Mensagem: "os caracteres especiais tao tudo bugado (coisa com acento, ç etc"
Status: ✅ Completamente coberto no doc principal — seção A4 (Encoding UTF-8 nos serviços de arquivo). Especifica exatamente onde e como adicionar `encoding: utf8` nos três serviços, e como varrer o codebase por strings corrompidas `Ã§`, `Ã£`.
Nada a complementar.
---
PEDIDO 9 — Diminuir overflow adaptando tamanho de caixas/botões/cards
Mensagem: "tem como diminuir o overflow das coisas adaptando o tamanho das coisas? caixas de texto, botoes, cards etc?"
Status: ✅ Parcialmente coberto no doc principal — seção C20 cobre fixes pontuais de overflow (badge VENCIDA, editModeHint, SummaryChip, resize handle). O `AdaptiveLayout` helper foi mencionado nos docs anteriores mas não foi incluído no `citrine_specs_completo.md`.
Spec complementar — E9: AdaptiveLayout helper global
Arquivo: `lib/ui/utils/adaptive_layout.dart` — CRIAR NOVO
```dart
// lib/ui/utils/adaptive_layout.dart

/// Helper para adaptar tamanhos de UI a telas pequenas.
/// Telas < 380px (alguns Androids entry-level) precisam de ajustes.
class AdaptiveLayout {
  /// Retorna fontSize reduzido em telas < 380px de largura.
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Retorna padding horizontal reduzido em telas pequenas.
  static EdgeInsets hPadding(BuildContext context, {double normal = 16}) {
    final w = MediaQuery.of(context).size.width;
    final p = w < 360 ? normal * 0.75 : normal;
    return EdgeInsets.symmetric(horizontal: p);
  }

  /// True se a tela é estreita (< 380px).
  static bool isNarrow(BuildContext context) =>
    MediaQuery.of(context).size.width < 380;

  /// Padding de campo de texto adaptativo.
  static EdgeInsets fieldPadding(BuildContext context) =>
    isNarrow(context)
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
      : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  /// Padding horizontal de botão adaptativo.
  static EdgeInsets buttonPadding(BuildContext context) =>
    isNarrow(context)
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
      : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
}
```
Uso nos forms (onde o overflow é mais frequente):
```dart
// Em campos de texto:
InputDecoration(
  contentPadding: AdaptiveLayout.fieldPadding(context),
  ...)

// Em botões primários:
ElevatedButton(
  style: ElevatedButton.styleFrom(padding: AdaptiveLayout.buttonPadding(context)),
  ...)

// Em títulos de card com texto longo:
Text(title,
  style: TextStyle(fontSize: AdaptiveLayout.fontSize(context, 14), fontWeight: FontWeight.w700),
  maxLines: 2, overflow: TextOverflow.ellipsis)
```
Regra geral para todo o codebase: Qualquer `Text` dentro de um `Row` que não esteja dentro de `Expanded` ou `Flexible` é um overflow em potencial. Aplicar `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))` sistematicamente.
---
PEDIDO 10 — Rotinas: linkar objetos e trechos, go-to page, scheduler e bloco de tempo
Mensagem: "preciso q tenha tipo um jeito de eu linkar objetos e trechos de objetos a uma pagina (acho q seria uma rotina)... qq eu faço quando to com meltdown? quais sao todas as coisas q preciso fazer antes de sair de casa?... pode ter rotina automatica (com scheduler) ou que eu coloco manualmente como um bloco de tempo no planner (tem que ter essa opção)"
Status: ❌ ausente no doc principal. Mencionado brevemente nos docs anteriores como "Rotinas como Note outline" mas sem spec completa.
Viável: Sim, usando `Note` tipo `outline` com extensões. Não requer novo tipo de objeto.
Spec complementar — E10: Rotinas
E10.1 — O que é uma Rotina
Uma Rotina é uma `Note` com `noteType: 'routine'` (novo subtipo). É uma página de referência pessoal — um "go-to" para lembrar o que fazer numa situação específica. Não é uma checklist de tarefas (não tem stage pipeline), é um documento vivo que pode ter:
Texto livre com contexto
Wiki-links para outros objetos (`[[nome-nota]]`, `[[titulo-habito]]`)
Trechos citados de outros objetos (highlight de um resource, um bloco de uma nota)
Passos numerados
Checkboxes contextuais (não salvos como tarefas — são lembretes visuais)
Exemplos de uso da Laura:
"O que fazer num meltdown?" → links para habits de regulação, trecho do livro sobre isso, checklist simples
"Sair de casa" → passos, links para objetos que ela precisa verificar
"Receita de carne do TikTok" → link para o SocialPost, notas pessoais, trechos de outros posts
E10.2 — Modelo — extensão de Note
Arquivo: `lib/models/note_model.dart` — EDITAR
```dart
// Adicionar ao enum NoteType (ou noteType String):
// 'routine' — além de 'text', 'outline', 'collection'

// Adicionar ao modelo Note:
final String? schedulerSlug;    // se tem scheduler automático vinculado
final bool showInPlanner;       // se deve aparecer como bloco de tempo no planner
final TimeOfDay? plannerTime;   // horário padrão no planner
```
E10.3 — Formulário de criação rápida — `lib/ui/forms/create_note_form.dart`
Quando `noteType == 'routine'`, mostrar campos adicionais:
```dart
// Após os campos básicos (título, organizers, tags):
if (_noteType == 'routine') ...[
  const Divider(),
  // Opção de scheduler automático
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rotina agendada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Aparece automaticamente no planner no horário definido',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _hasScheduler, onChanged: (v) => setState(() => _hasScheduler = v)),
  ]),
  if (_hasScheduler) ...[
    const SizedBox(height: 8),
    // Reutilizar SchedulerPicker existente
    SchedulerPicker(onChanged: (s) => setState(() => _scheduler = s)),
  ],
  const SizedBox(height: 8),
  // Opção de adicionar manualmente ao planner
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mostrar no Planner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Aparece como bloco de tempo quando arrastado para o planner',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _showInPlanner, onChanged: (v) => setState(() => _showInPlanner = v)),
  ]),
],
```
E10.4 — Editor de Rotina
A rotina usa o `OutlineEditor` existente mas com capacidade de inserir dois novos tipos de item:
Tipo A: Link para objeto — `[[wiki-link]]`
Ao tocar em "+ Adicionar" dentro do outline editor → menu de opções
"Linkar objeto" → abre `UniversalSearchPicker` → insere `[[slug-do-objeto]]`
Renderizado como card compacto com ícone do tipo + título clicável
Tipo B: Trecho de objeto — `> "texto citado" — [[fonte]]`
"Citar trecho" → abre picker de objeto → depois picker de highlight desse objeto
Insere blockquote com atribuição: `> "texto do highlight" — [[titulo-resource]]`
Renderizado como blockquote com borda colorida (igual ao feed de highlights do Resources)
```dart
// Em OutlineEditor ou no editor de Routine,
// botão de inserção rápida no toolbar:
Row(children: [
  _toolbarBtn(Icons.link_rounded, 'Linkar objeto', () => _insertWikiLink()),
  _toolbarBtn(Icons.format_quote_rounded, 'Citar trecho', () => _insertHighlight()),
  _toolbarBtn(Icons.check_box_outlined, 'Checkbox', () => _insertCheckbox()),
  _toolbarBtn(Icons.format_list_numbered_rounded, 'Passo numerado', () => _insertStep()),
]),

Future<void> _insertWikiLink() async {
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;
  _insertAtCursor('[[${obj.slug}]]');
}

Future<void> _insertHighlight() async {
  // 1. Picker de objeto (qualquer tipo com body/synopsis)
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;

  // 2. Picker de highlight desse objeto
  final body = (obj as dynamic).body ?? (obj as dynamic).synopsis ?? '';
  final highlights = MarkdownParser.extractHighlights(body);
  if (highlights.isEmpty) {
    // Sem highlights detectados → inserir link simples
    _insertAtCursor('[[${obj.slug}]]');
    return;
  }

  final selected = await showModalBottomSheet<HighlightItem>(
    context: context,
    builder: (ctx) => _HighlightPickerSheet(
      objectTitle: obj.title, highlights: highlights));
  if (selected == null) return;

  _insertAtCursor('> "${selected.text}" — [[${obj.slug}]]');
}
```
`_HighlightPickerSheet` — bottom sheet que lista os highlights de um objeto:
```dart
class _HighlightPickerSheet extends StatelessWidget {
  final String objectTitle;
  final List<HighlightItem> highlights;
  const _HighlightPickerSheet({required this.objectTitle, required this.highlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Trechos de "$objectTitle"',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        const Divider(),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: highlights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final hl = highlights[i];
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, hl),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  border: Border(left: BorderSide(color: AppColors.primary, width: 2)),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (hl.tag != null)
                    Text('#${hl.tag}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  Text('"${hl.text}"', style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryColor(context),
                    fontStyle: FontStyle.italic, height: 1.5)),
                ])));
          })),
      ]));
  }
}
```
E10.5 — Integração com Planner
Quando `note.showInPlanner == true`, a rotina pode ser arrastada para o Planner como bloco de tempo.
Em `planner_screen.dart`: Adicionar seção "Rotinas" no backlog (lista de itens sem horário definido):
```dart
// No _buildBacklogSection, após tasks sem data:
final routines = ref.watch(notesProvider)
  .where((n) => n.noteType == 'routine' && n.showInPlanner).toList();

if (routines.isNotEmpty) ...[
  const SizedBox(height: 16),
  Text('ROTINAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
  const SizedBox(height: 8),
  ...routines.map((r) => Draggable<Note>(
    data: r,
    feedback: Material(child: _buildRoutineBacklogCard(r, dragging: true)),
    child: _buildRoutineBacklogCard(r))),
]
```
O `DragTarget` na timeline aceita `Note` com `noteType == 'routine'` e cria um bloco de tempo com duração padrão de 30min e o título da rotina.
Rotina com scheduler automático: Quando `note.schedulerSlug != null`, o `SchedulerService.shouldFire(scheduler, date)` inclui essa rotina nos itens do dia. Aparece na timeline como bloco de tipo "routine" (ícone 📋, cor roxa).
E10.6 — CreateMenu: atalho para nova rotina
```dart
// Em create_menu_sheet.dart:
_createItem(
  icon: '📋',
  label: 'Rotina',
  subtitle: 'Página go-to para uma situação',
  onTap: () {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreateNoteForm(initialNoteType: 'routine')));
  }),
```
---
PEDIDO 11 — TikTok: transcrição automática e embed sem UI
Mensagem: "quando eu salvo um video no TikTok tem como ir carregando e colocar a transcrição do video (ptbr ou ingles)? e fazer isso de graça?" + "geralmente uso o whisper pra puxar a transcrição... e tb da pra ficar embed só o video sem a ui do tiktok? talvez com aquele yt dlp"
Status: ⚠️ Parcialmente coberto — mencionado nos docs anteriores com esboço de código para Whisper via HuggingFace, mas não incluído no `citrine_specs_completo.md`.
Viável: Transcrição via HuggingFace Inference API = gratuito com rate limit. Embed sem UI do TikTok via yt-dlp = requer backend/servidor — não é 100% automático e gratuito no cliente Flutter puro. Ver análise abaixo.
Spec complementar — E11: Transcrição e embed TikTok
E11.1 — Transcrição via HuggingFace Whisper (gratuito)
Campo no modelo — `lib/models/social_post.dart`:
```dart
final String? transcription;      // texto transcrito
final String? transcriptionLang;  // 'pt' | 'en' | 'auto'
final bool    isTranscribing;     // loading state
```
Serviço — `lib/services/transcription_service.dart` — CRIAR NOVO:
```dart
class TranscriptionService {
  static const _apiUrl =
    'https://api-inference.huggingface.co/models/openai/whisper-large-v3';

  /// Transcreve um vídeo a partir de sua URL de áudio/vídeo.
  /// Requer: HuggingFace token gratuito (configurado em Settings > Integrações).
  ///
  /// LIMITAÇÃO: HuggingFace Inference API aceita arquivos de até ~25MB.
  /// Para vídeos maiores, retorna erro e orienta o usuário.
  ///
  /// ALTERNATIVA GRATUITA ADICIONAL: Groq API tem Whisper gratuito com
  /// limite de 7200 segundos/dia — mais generoso que HuggingFace.
  /// Endpoint: https://api.groq.com/openai/v1/audio/transcriptions
  static Future<String?> transcribeFromUrl({
    required String videoUrl,
    required String hfToken,     // token do HuggingFace salvo em Settings
    String language = 'pt',
  }) async {
    try {
      // 1. Baixar o áudio do vídeo (via URL direta se disponível)
      //    TikTok: a URL de oEmbed pode não dar acesso direto ao arquivo
      //    Fallback: usar videoUrl diretamente se for .mp4 acessível
      final audioResponse = await http.get(Uri.parse(videoUrl));
      if (audioResponse.statusCode != 200) return null;

      final bytes = audioResponse.bodyBytes;
      if (bytes.lengthInBytes > 25 * 1024 * 1024) {
        throw Exception('Arquivo muito grande para transcrição automática (>25MB)');
      }

      // 2. Enviar para HuggingFace Whisper
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $hfToken',
          'Content-Type': 'application/octet-stream',
          'X-Wait-For-Model': 'true',   // aguarda o modelo carregar se necessário
        },
        body: bytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      }

      // Modelo ainda carregando (503) → aguardar e tentar novamente
      if (response.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 20));
        return transcribeFromUrl(
          videoUrl: videoUrl, hfToken: hfToken, language: language);
      }

      return null;
    } catch (e) {
      debugPrint('Transcription error: $e');
      return null;
    }
  }
}
```
UI no form de Social Post — botão de transcrição no formulário:
```dart
// Em create_social_post_form.dart, seção de vídeo (quando plataforma é TikTok/YouTube):
if (_isVideoPost) ...[
  const SizedBox(height: 12),
  ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.subtitles_outlined, color: AppColors.info, size: 18)),
    title: Text(_draft?.transcription != null
      ? 'Transcrição disponível (${_draft!.transcription!.length} chars)'
      : 'Transcrever vídeo automaticamente'),
    subtitle: Text(_draft?.transcription != null
      ? 'Toque para ver ou editar'
      : 'Usa Whisper via HuggingFace (gratuito)',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    trailing: _isTranscribing
      ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Icon(Icons.chevron_right_rounded, size: 16),
    onTap: _isTranscribing ? null : () => _transcribe()),
],

Future<void> _transcribe() async {
  final settings = ref.read(settingsProvider);
  if (settings.huggingFaceToken?.isEmpty != false) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'Configure seu token HuggingFace em Configurações > Integrações')));
    return;
  }

  setState(() => _isTranscribing = true);
  try {
    final videoUrl = _draft?.videoUrl ?? _urlController.text.trim();
    final text = await TranscriptionService.transcribeFromUrl(
      videoUrl: videoUrl,
      hfToken: settings.huggingFaceToken!);
    if (text != null && mounted) {
      setState(() => _draft = _draft?.copyWith(transcription: text));
      // Mostrar resultado em sheet expansível
      _showTranscriptionSheet(text);
    }
  } finally {
    if (mounted) setState(() => _isTranscribing = false);
  }
}

void _showTranscriptionSheet(String text) => showModalBottomSheet(
  context: context, isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.6, maxChildSize: 0.95, expand: false,
    builder: (_, ctrl) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text('Transcrição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(controller: ctrl,
          child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.6)))),
      ]))));
```
Campo HuggingFace token em Settings:
```dart
// Em settings_screen.dart, dentro do card "Integrações":
_settingsTile('Whisper (HuggingFace)', Icons.mic_rounded,
  subtitle: settings.huggingFaceToken?.isNotEmpty == true
    ? 'Token configurado' : 'Não configurado',
  onTap: () => _editHfToken()),

void _editHfToken() async {
  final ctrl = TextEditingController(text: ref.read(settingsProvider).huggingFaceToken ?? '');
  final result = await showDialog<String>(context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Token HuggingFace'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'hf_...')),
        const SizedBox(height: 8),
        Text('Obtenha gratuitamente em huggingface.co/settings/tokens',
          style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Salvar')),
      ]));
  if (result != null) {
    await ref.read(settingsProvider.notifier).setHuggingFaceToken(result);
  }
}
```
Adicionar `huggingFaceToken: String?` ao `AppSettings` e `setHuggingFaceToken()` ao notifier.
E11.2 — Embed sem UI do TikTok
Análise de viabilidade:
Abordagem	Gratuito	Automático	Sem UI TikTok
oEmbed padrão do TikTok	✅	✅	❌ tem UI
WebView com JS injection	✅	✅	⚠️ frágil
yt-dlp no dispositivo	✅	❌ manual	✅
yt-dlp em servidor próprio	✅*	✅	✅
Terceiros (cobram)	❌	✅	✅
*servidor próprio requer hospedagem (Railway free tier funciona)
Recomendação: WebView com JS injection (melhor custo-benefício no Flutter):
```dart
// Em social_embed_view.dart:
// Quando platform == SocialPlatform.tiktok e oEmbedHtml disponível:
WebViewWidget(
  controller: _controller,
  // Após a página carregar, injetar CSS para ocultar elementos de UI:
)

// No onPageFinished:
_controller.runJavaScript('''
  // Remover header, footer, action bar, sugestões de vídeos
  const selectors = [
    '.tiktok-header', '.author-uniqueId', '.video-meta-share',
    '.action-bar', '.tiktok-footer', '[class*="DivRecommentContainer"]',
    '[data-e2e="related-video"]'
  ];
  selectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => el.remove());
  });

  // Forçar vídeo para tela cheia dentro do WebView
  const video = document.querySelector('video');
  if (video) {
    video.style.cssText = "width:100%!important;height:100%!important;object-fit:contain";
  }
''');
```
Limitação documentada: A estrutura de CSS do TikTok muda frequentemente, então este método pode quebrar e precisar de manutenção. Para uso pessoal é aceitável — para produção seria frágil.
---
PEDIDO 12 — Hábitos de baixa frequência (lavar cesto, tarefas periódicas flexíveis)
Mensagem: "como registrar coisas q nao sao necessariamente habitos? tipo lavar o cesto da maquina de lavar. é bom ser a cada 30 dias mas nao precisa ser tao certinho... quando colocar q a prioridade é baixa ter algo que anote a frequencia q eu quero fazer, e quando tiver chegando perto aparecer nos habitos do dia de um jeito diferente"
Status: ❌ ausente no doc principal — mencionado nos docs anteriores como "Hábito de baixa frequência" mas não foi incluído no `citrine_specs_completo.md`.
Viável: Sim, usando campos adicionais em `Habit`.
Spec complementar — E12: Hábitos Flexíveis/Periódicos
E12.1 — Modelo — extensão de Habit
Arquivo: `lib/models/habit_model.dart` — EDITAR
```dart
// Adicionar ao Habit:
final int?  frequencyDays;        // quero fazer a cada N dias
final bool  isFlexibleFrequency;  // true = não rígido, aparecer diferente
// (isFlexibleFrequency = true implica que schedulers não são obrigatórios)

// Serialização:
'frequency_days':       frequencyDays,
'is_flexible_frequency': isFlexibleFrequency,
// fromJson:
frequencyDays:       j['frequency_days'],
isFlexibleFrequency: j['is_flexible_frequency'] ?? false,
```
E12.2 — Formulário — `create_habit_form.dart`
Quando o usuário escolhe prioridade baixa OU ativa explicitamente o toggle, mostrar campo de frequência:
```dart
// Toggle "Frequência flexível" — aparece após os schedulers ou quando prioridade == low:
if (_priority == TaskPriority.low || _isFlexibleFrequency) ...[
  const Divider(),
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Frequência flexível',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Não aparece todo dia — surge quando a data estiver chegando',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _isFlexibleFrequency,
      onChanged: (v) => setState(() => _isFlexibleFrequency = v)),
  ]),
  if (_isFlexibleFrequency) ...[
    const SizedBox(height: 10),
    Row(children: [
      const Text('Quero fazer a cada', style: TextStyle(fontSize: 13)),
      const SizedBox(width: 10),
      SizedBox(width: 60, child: TextField(
        controller: _frequencyDaysCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.surfaceVariantColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        onChanged: (v) => setState(() => _frequencyDays = int.tryParse(v)))),
      const SizedBox(width: 8),
      const Text('dias', style: TextStyle(fontSize: 13)),
    ]),
  ],
],
```
E12.3 — Card visual diferenciado na HabitsScreen
Na `_TodayView`, hábitos com `isFlexibleFrequency == true` aparecem numa terceira seção "Periódicos" (depois dos normais e dos quitting). Só aparecem quando `daysSinceLast / frequencyDays >= 0.75` (chegando perto do prazo):
```dart
// Após a seção "Evitando" (quitting habits):
Builder(builder: (ctx) {
  final flexible = ref.watch(habitsProvider).where((h) =>
    h.isFlexibleFrequency && h.status == HabitStatus.active && !h.archived).toList();
  if (flexible.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AppColors.info,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('Periódicos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.info, letterSpacing: 0.08)),
      ])),
    const SizedBox(height: 8),
    ...flexible.map((h) {
      final daysSince = _daysSinceLast(h);
      final ratio     = h.frequencyDays != null ? daysSince / h.frequencyDays! : 0.0;
      // Só mostrar se chegando perto (ratio >= 0.6) ou passado (ratio >= 1.0)
      if (ratio < 0.6) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _FlexHabitCard(habit: h, daysSince: daysSince, ratio: ratio));
    }),
  ]);
})

int _daysSinceLast(Habit h) {
  final history = h.completionHistory ?? {};
  final now     = DateTime.now();
  for (int i = 0; i < 365; i++) {
    final d   = now.subtract(Duration(days: i));
    final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final e   = history[key];
    if (e == true || (e is Map && (e['done'] == true || e['value'] != null))) return i;
  }
  return 999; // nunca foi feito
}
```
`_FlexHabitCard` — card com cor semafórica e botões de ação:
```dart
class _FlexHabitCard extends ConsumerWidget {
  final Habit habit;
  final int   daysSince;
  final double ratio;
  const _FlexHabitCard({required this.habit, required this.daysSince, required this.ratio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ratio >= 1.0 ? AppColors.error
      : ratio >= 0.85 ? AppColors.warning : AppColors.info;

    final statusText = daysSince == 0 ? 'Feito hoje'
      : daysSince == 1 ? 'Feito ontem'
      : daysSince >= 999 ? 'Nunca feito'
      : 'Feito há $daysSince dias';

    final targetText = habit.frequencyDays != null
      ? 'Meta: a cada ${habit.frequencyDays} dias'
      : 'Sem frequência definida';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$statusText · $targetText',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ])),
          // Marcar como feito
          GestureDetector(
            onTap: () => ref.read(habitsProvider.notifier)
              .toggleHabit(habit, DateTime.now(), slotIndex: 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text('Feito!', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)))),
        ]),
        const SizedBox(height: 8),
        // Botões secundários
        Row(children: [
          // Agendar no planner
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: const Text('Agendar', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 6)),
            onPressed: () => _showScheduleOptions(context, ref))),
          const SizedBox(width: 8),
          // Reagendar lembrete
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.notifications_outlined, size: 14),
            label: const Text('Lembrar em…', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMutedColor(context),
              side: BorderSide(color: AppTheme.dividerColor(context)),
              padding: const EdgeInsets.symmetric(vertical: 6)),
            onPressed: () => _showReminderOptions(context, ref))),
        ]),
      ]));
  }

  void _showScheduleOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text('Adicionar ao Planner'),
          onTap: () { Navigator.pop(ctx); _pickDateForPlanner(context, ref); }),
        ListTile(
          leading: const Icon(Icons.timer_rounded),
          title: const Text('Iniciar Pomodoro agora'),
          onTap: () { Navigator.pop(ctx); _startPomodoro(context, ref); }),
        const SizedBox(height: 8),
      ]));
  }

  void _showReminderOptions(BuildContext context, WidgetRef ref) async {
    final days = await showModalBottomSheet<int>(context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16),
          child: Text('Lembrar em quantos dias?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ...[1, 3, 7, 14, 30].map((d) => ListTile(
          title: Text('Em $d dia${d > 1 ? "s" : ""}'),
          onTap: () => Navigator.pop(ctx, d))),
        const SizedBox(height: 8),
      ]));
    if (days == null) return;
    // Criar Reminder para daqui N dias
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: habit.title,
      time: DateTime.now().add(Duration(days: days)),
      linkedHabitId: habit.id);
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lembrete criado para daqui $days dia(s)')));
  }

  Future<void> _pickDateForPlanner(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(context: context,
      initialDate: DateTime.now(), firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !context.mounted) return;
    // Criar um "bloco de tempo" no planner para essa data
    // Navegar para o planner nessa data
    Navigator.pushNamed(context, '/planner', arguments: date);
  }

  void _startPomodoro(BuildContext context, WidgetRef ref) {
    ref.read(pomodoroProvider.notifier).setCurrentItem(habit.id, habit.title);
    Navigator.pushNamed(context, '/pomodoro');
  }
}
```
---
PEDIDO 13 — Quitting Habits: não aparece no calendário nem planner, comportamento de não marcar
Mensagem: "o quitting habits nao aparece no widget de calendario, nem no planner, mas aparece no habits do dia. marcar um quitting habits como feito é ruim, o objetivo é nao marcar"
Status: ✅ Completamente coberto no doc principal — seção D1 (Quitting Habits). Especifica filtros no Planner e CalendarWidget, card visual sem checkbox, botão "Recaída" com confirmação, contador de dias limpos.
Nada a complementar.
---
PEDIDO 14 — Tracker de saúde com indicadores automáticos
Mensagem: "quero fazer um tracker de coisas q eu fico de olho pra ver se to bem - sono, buraco no cabelo, comida, frequencia do cocô. aí poderia ter um indicador automatico do quanto as coisas que eu coloquei tao saudaveis... cada um desses indicativos podem ta relacionados a oq eu marco num habito, tarefa recorrente, status de um projeto, ou oq eu coloco no tracker mesmo."
Status: ✅ Coberto no doc principal — seção D2 (Tracker de Saúde). Inclui `FieldAlertLevel`, template pré-configurado, `healthAlertsProvider`, `HealthAlertsStrip`, lembretes escalonados.
Complemento necessário: A mensagem menciona que os indicadores podem vir de hábito, tarefa recorrente ou status de projeto — não só do tracker. Isso não está no doc atual.
Spec complementar — E14: Fonte de dados para alertas de saúde
O `HealthAlert` atual só lê `TrackingRecord`. Expandir para ler de outras fontes:
```dart
// Em health_alerts_provider.dart, adicionar ao loop de campos:

// Verificar se o campo tem uma fonte alternativa configurada:
if (field.dataSourceType != null) {
  switch (field.dataSourceType!) {
    case FieldDataSource.habit:
      // Verificar se o hábito vinculado foi completado hoje
      if (field.linkedHabitId != null) {
        final habit = habits.firstWhere((h) => h.id == field.linkedHabitId);
        final todayKey = _dateKey(DateTime.now());
        final completedToday = habit.completionHistory?[todayKey];
        lastVal    = (completedToday == true) ? 1.0 : 0.0;
        lastDate   = DateTime.now();
        daysSince  = completedToday == true ? 0 : 1;
      }
    case FieldDataSource.recurringTask:
      // Verificar última task recorrente com esse título finalizada
      if (field.linkedTaskTitle != null) {
        final relatedTasks = tasks.where((t) =>
          t.title.toLowerCase().contains(field.linkedTaskTitle!.toLowerCase()) &&
          t.stage?.name == 'finalized').toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
        lastDate  = relatedTasks.isNotEmpty ? relatedTasks.first.updatedAt : null;
        daysSince = lastDate != null ? now.difference(lastDate!).inDays : 999;
      }
    case FieldDataSource.tracker:
      // Comportamento atual (TrackingRecord) — já implementado
      break;
  }
}
```
Enum de fonte de dados — adicionar ao `tracker_model.dart`:
```dart
enum FieldDataSource { tracker, habit, recurringTask }

// Em TrackerField, adicionar:
final FieldDataSource dataSource;          // default: FieldDataSource.tracker
final String? linkedHabitId;              // se dataSource == habit
final String? linkedTaskTitle;            // se dataSource == recurringTask

// No template pré-configurado, o campo "Sono" pode linkar a um hábito de
// "registrar sono" se a Laura preferir marcar via hábito em vez de tracker.
```
---
PEDIDO 15 — Salvar post social e criar/vincular tarefa ou projeto sem perder infos
Mensagem: "quero conseguir ao ir salvar um post social, conseguir criar e vincular tarefa ou projeto, sem perder as infos da tarefa/projeto nem do post"
Status: ❌ ausente no doc principal.
Viável: Sim, adicionando um passo de "vincular objetos" no fluxo de salvar o post social.
Spec complementar — E15: Social Post → Vincular Task/Projeto ao salvar
E15.1 — Fluxo
Usuário preenche o form de post social normalmente
Toca em "Salvar"
Antes de fechar, aparece uma step opcional "Vincular ao seu trabalho?" com 3 opções:
Criar task relacionada
Criar projeto relacionado
Vincular a existente (busca)
Pular
O post é salvo imediatamente antes de qualquer ação de vínculo — assim o usuário nunca perde o post mesmo se fechar o form de task no meio.
E15.2 — Implementação
```dart
// Em create_social_post_form.dart, substituir o final de _save():

Future<void> _save() async {
  // ... detecção de duplicata existente ...
  // ... lógica de build e save do post ...

  final savedPost = _buildPostForSave();

  if (widget.existingPost == null) {
    await ref.read(socialPostsProvider.notifier).addPost(savedPost);
  } else {
    await ref.read(socialPostsProvider.notifier).updatePost(savedPost);
  }

  // Post salvo com sucesso — agora oferecer vínculo
  if (!mounted) return;
  final shouldLink = await _showLinkOfferSheet(savedPost);
  if (!mounted) return;

  if (shouldLink == _LinkAction.createTask) {
    await _createAndLinkTask(savedPost);
  } else if (shouldLink == _LinkAction.createProject) {
    await _createAndLinkProject(savedPost);
  } else if (shouldLink == _LinkAction.linkExisting) {
    await _linkExisting(savedPost);
  }

  // Fechar form independentemente de ter vinculado ou não
  if (mounted) Navigator.pop(context);
}

enum _LinkAction { createTask, createProject, linkExisting, skip }

Future<_LinkAction?> _showLinkOfferSheet(SocialPost post) =>
  showModalBottomSheet<_LinkAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Post salvo! ✅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Quer vincular este post a uma tarefa ou projeto?',
          style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
        const SizedBox(height: 16),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_task_rounded, color: AppColors.primary, size: 18)),
          title: const Text('Criar tarefa relacionada', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Tarefa pré-preenchida com título do post', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.createTask)),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.habitPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.folder_outlined, color: AppColors.habitPurple, size: 18)),
          title: const Text('Criar projeto relacionado', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Projeto a partir do conteúdo do post', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.createProject)),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.link_rounded, color: AppColors.info, size: 18)),
          title: const Text('Vincular a existente', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Buscar task ou projeto já criado', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.linkExisting)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: TextButton(
          onPressed: () => Navigator.pop(ctx, _LinkAction.skip),
          child: const Text('Pular', style: TextStyle(color: AppColors.textMuted)))),
      ])));

Future<void> _createAndLinkTask(SocialPost post) async {
  // Abrir CreateTaskForm pré-preenchido e aguardar resultado
  final newTask = await Navigator.push<Task>(context, MaterialPageRoute(
    builder: (_) => CreateTaskForm(
      // Pré-preencher com dados do post:
      initialTitle: post.title,
      initialNotes: post.personalNote ?? post.caption,
      // Vincular o post via socialRefs da task (se Task tiver esse campo)
      // ou via organizers se o post tiver slug
    )));

  if (newTask == null) return; // usuário cancelou o form de task

  // Salvar vínculo: atualizar o post com referência à task
  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${newTask.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);

  // E atualizar a task com referência ao post (se Task tiver campo para isso)
  // Depende de como o modelo Task armazena vínculos externos
}

Future<void> _createAndLinkProject(SocialPost post) async {
  final newProject = await Navigator.push<dynamic>(context, MaterialPageRoute(
    builder: (_) => CreateProjectForm(
      initialTitle: post.title,
      initialDescription: post.personalNote ?? post.caption)));

  if (newProject == null) return;

  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${newProject.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
}

Future<void> _linkExisting(SocialPost post) async {
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;

  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${obj.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
}
```
Nota importante: Para que o post seja vinculado corretamente à task/projeto, os modelos `Task` e `Project` também precisam armazenar o slug do post. Se já têm campo `socialRefs` ou `linkedObjects`, usar. Se não, adicionar:
```dart
// Em task_model.dart e project_model.dart:
final List<String> linkedPostSlugs; // slugs de SocialPosts vinculados
```
---
RESUMO: O QUE ESTÁ COBERTO E O QUE FOI ADICIONADO
#	Pedido	Status no doc	Spec adicionada
1	Tracker: gaps no gráfico não = zero	❌	✅ E1
2	Hierarquia organizer, aviso de conflito	❌	✅ E2
3	Organizer lê body e mostra itens/timeline/children	❌	✅ E3
4	Social: banner de duplicata ao salvar	✅ C19	—
5	Anotar ideias vinculadas ao vault	✅ D3	—
6	Search picker: aba Social com filtro plataforma/criador	❌	✅ E6
7	Resources: vincular e criar objeto não funciona	✅ C (crítico)	✅ E7 (código exato)
8	Caracteres especiais bugados	✅ A4	—
9	Diminuir overflow adaptando tamanhos	⚠️ C20 parcial	✅ E9 (AdaptiveLayout)
10	Rotinas: linkar objetos/trechos, scheduler, bloco no planner	❌	✅ E10
11	TikTok: transcrição automática + embed sem UI	❌	✅ E11
12	Hábitos de baixa frequência (lavar cesto, etc.)	❌	✅ E12
13	Quitting Habits: comportamento e filtros	✅ D1	—
14	Tracker de saúde com indicadores automáticos	✅ D2	✅ E14 (fontes: hábito/task)
15	Salvar social + criar/vincular task/projeto	❌	✅ E15
---
CHECKLIST ADICIONAL (complementa o checklist do doc principal)
🟡 ALTA — funcionalidade pedida sem spec anterior
[x] `lib/ui/widgets/citrine_chart.dart` ou fl_chart — suporte a gaps (E1) ✅ 16-06-26
[x] `lib/ui/widgets/universal_search_picker.dart` — aba Social com filtros (E6) ✅ 16-06-26
[x] `lib/ui/forms/create_social_post_form.dart` — sheet de vínculo ao salvar (E15) ✅ 16-06-26
[x] `lib/models/habit_model.dart` — `frequencyDays`, `isFlexibleFrequency` (E12) ✅ já implementado
[x] `lib/ui/screens/habits_screen.dart` — `_FlexHabitCard` e seção "Periódicos" (E12) ✅ 16-06-26
🟢 MÉDIA
[x] `lib/providers/vault_provider.dart` — `conflictingObjectsProvider` (E2) ✅ 16-06-26
[x] `lib/ui/screens/universal_detail_view.dart` — banner de conflito Nota/Organizer (E2) ✅ 16-06-26
[x] `lib/providers/wiki_link_resolver_provider.dart` — novo arquivo (E3) ✅ 16-06-26
[x] `lib/providers/backlinks_provider.dart` — expandir para incluir body (E3) ✅ já implementado em `vault_provider.dart`
[x] `lib/ui/screens/organizer_detail_screen.dart` — reformular tabs com incoming + outgoing (E3) ✅ 16-06-26
[x] `lib/models/note_model.dart` — `noteType: 'routine'`, `schedulerSlug`, `showInPlanner` (E10)
[x] `lib/ui/forms/create_note_form.dart` — campos de rotina (E10)
[x] `lib/ui/screens/planner_screen.dart` — seção "Rotinas" no backlog (E10)
[x] `lib/ui/utils/adaptive_layout.dart` — novo arquivo helper (E9)
[x] `lib/providers/settings_provider.dart` — `huggingFaceToken`, `suppressedConflicts` (E2, E11)
[x] `lib/models/tracker_model.dart` — `FieldDataSource`, `linkedHabitId`, `linkedTaskTitle` (E14) ✅ já implementado
⚪ BAIXA
[x] `lib/services/transcription_service.dart` — Whisper via HuggingFace (E11)
[x] `lib/ui/widgets/social_embed_view.dart` — JS injection para remover UI do TikTok (E11)
[x] `lib/ui/widgets/highlight_picker_sheet.dart` — picker de trecho de objeto (E10)


# UI Spec — Implementação Detalhada
Gerado: 09/06/2026  
Baseado em leitura direta do código atual (GitHub último commit)

---

## Prioridade de Implementação

| # | Feature | Arquivos principais |
|---|---------|-------------------|
| P1 | Caracteres especiais (UTF-8) | obsidian_service, drive_sync, backup |
| P2 | Overflow adaptativo | novo layout_utils.dart + correções pontuais |
| P3 | Ideias — definição configurável + atalho | settings_provider, create_menu_sheet, note_model |
| P4 | Outline e Collection — corrigir, linkar, navegar | notes_screen, outline_editor, collection_view, universal_detail_view |
| P5 | Wiki-links clicáveis no Outline (4b) | outline_editor, markdown_parser |
| P6 | Social posts na busca global | search_screen, universal_search_picker, search_service |
| P7 | Resource — vincular e criar objeto | universal_detail_view, social_post_detail |
| P8 | Widget nativo Note/Checklist (Android) | widget_service, note_model |
| P9 | Hábito de baixa frequência | habit_model, habits_screen, create_habit_form |
| P10 | Vincular livros e lugares ao post TikTok | social_post.dart, social_post_detail, create_social_post_form |
| P11 | Eisenhower Matrix Etapa 1 | saved_filter, novo matrix_screen |
| P12 | Unificar UI de vincular objetos | universal_search_picker, todos os detalhes |

---

## P1 — Caracteres Especiais (UTF-8)

### Problema confirmado no código
`obsidian_service.dart` tem `dart:convert` importado mas usa `file.readAsString()` e `file.writeAsString(content)` sem `encoding: utf8`. Dart usa Latin-1 como default nesses métodos.

### Correções

**`lib/services/obsidian_service.dart`** — toda ocorrência de leitura/escrita:
```dart
// ANTES:
return await file.readAsString();
await file.writeAsString(content);

// DEPOIS:
return await file.readAsString(encoding: utf8);
await file.writeAsString(content, encoding: utf8);
```
Aplicar em TODOS os métodos do arquivo: `readFile`, `saveObject`, `deleteFile`, `_loadAllFiles`, e qualquer outro que acesse o filesystem.

**`lib/services/google_drive_sync_service.dart`**:
```dart
// Upload:
final bytes = utf8.encode(markdownContent);

// Download — ao receber bytes:
final content = utf8.decode(responseBytes);
```

**`lib/services/backup_service.dart`**:
```dart
await file.writeAsString(jsonStr, encoding: utf8);
final raw = await file.readAsString(encoding: utf8);
```

**Strings bugadas no código-fonte** — rodar busca e substituir:
```
Padrão:  Ã§ → ç    Ã£ → ã    Ã© → é    Ãª → ê    Ãµ → õ    Ã­ → í
```
Confirmado em `create_social_post_form.dart`:
- `'Descartar alteraÃ§Ãµes?'` → `'Descartar alterações?'`
- `'VocÃª possui alteraÃ§Ãµes'` → `'Você possui alterações'`

Rodar grep em todo o projeto: `grep -r "Ã§\|Ã£\|Ã©\|Ãª\|Ãµ" lib/` e corrigir cada hit.

---

## P2 — Overflow Adaptativo

### Novo arquivo: `lib/ui/utils/layout_utils.dart`

```dart
import 'package:flutter/material.dart';

class AdaptiveLayout {
  /// Reduz fontSize proporcionalmente em telas estreitas
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Reduz padding horizontal em telas < 360px
  static double hPad(BuildContext context, {double normal = 16}) {
    return MediaQuery.of(context).size.width < 360 ? normal * 0.75 : normal;
  }

  /// true se tela menor que 380px
  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 380;

  /// contentPadding adaptativo para TextField
  static EdgeInsets fieldPadding(BuildContext context) {
    return isNarrow(context)
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);
  }
}
```

### Correções pontuais imediatas (bugs confirmados)

**`goals_screen.dart` — crash com Color() na progress bar** (linha em `_buildProgressInfo`):
```dart
// ANTES (crash):
valueColor: AlwaysStoppedAnimation(
  Color(int.parse(goal.color!.replaceAll('#', '0xFF'))),
),

// DEPOIS (usa a função segura que já existe no mesmo arquivo):
valueColor: AlwaysStoppedAnimation(_goalColor(goal.color)),
```

**`goals_screen.dart` — Row deadline + OVERDUE sem Flexible**:
```dart
// ANTES:
Text('Deadline: ${DateFormat(...).format(deadline)}',
  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),

// DEPOIS:
Flexible(
  child: Text('Deadline: ${DateFormat(...).format(deadline)}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: AdaptiveLayout.fontSize(context, 11),
      color: AppColors.textMuted)),
),
```

**`notes_screen.dart` — `_formatDate()` sem zero-pad no hour**:
```dart
// ANTES:
return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

// DEPOIS:
return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
```

**`habits_screen.dart` — semana começa no domingo**:
```dart
// ANTES:
final weekStart = now.subtract(Duration(days: now.weekday % 7));

// DEPOIS:
final weekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
```

**`habits_screen.dart` — _SummaryChip Row sem Flexible**:
```dart
// ANTES:
Row(children: [_SummaryChip(...), SizedBox(width:8), _SummaryChip(...)])

// DEPOIS:
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```

**`planner_screen.dart` — `timeBlocks` não passado ao `TimeLineDayView`**:
```dart
// Adicionar no construtor do TimeLineDayView dentro do planner:
TimeLineDayView(
  tasks: dayTasks,
  selectedDate: _selectedDate,
  allDayEvents: dayHabits,
  googleEvents: ...,
  timeBlocks: timeBlocks,  // ← ADICIONAR ESTA LINHA
  onTaskDrop: ...,
  ...
)
```

**Aplicar `AdaptiveLayout.fontSize` nos cards principais**:  
Em `_GoalCard`, `_buildNoteItem`, `_buildResourceCard`, `_TodayHabitCard` — substituir `fontSize: 15` por `fontSize: AdaptiveLayout.fontSize(context, 15)` nos títulos principais.

---

## P3 — Ideias: Definição Configurável + Atalho de Captura

### Conceito
Uma "ideia" não tem tipo fixo — o usuário define o que considera uma ideia nas configurações. Pode ser uma tag, uma pasta, um subtype de nota, etc.

### 3a — Configuração em `AppSettings`

**`lib/providers/settings_provider.dart`** — adicionar ao modelo `AppSettings`:
```dart
// Como o sistema reconhece uma "ideia":
final String ideaStrategy;      // 'tag' | 'folder' | 'any_note'
final String ideaTag;           // default: 'idea' (usado quando strategy='tag')
final String ideaFolder;        // ex: 'notes/ideas' (usado quando strategy='folder')
```

Valores default: `ideaStrategy: 'tag'`, `ideaTag: 'idea'`, `ideaFolder: 'notes/ideas'`.

**`copyWith` e serialização** — incluir os novos campos no `toJson`/`fromJson` e no `copyWith` do `AppSettings`.

**`SettingsNotifier`** — adicionar método:
```dart
Future<void> setIdeaStrategy({
  required String strategy,
  String? tag,
  String? folder,
}) async {
  state = state.copyWith(
    ideaStrategy: strategy,
    ideaTag: tag ?? state.ideaTag,
    ideaFolder: folder ?? state.ideaFolder,
  );
  await _persist();
}
```

**Tela de configuração** — em `settings_screen.dart`, adicionar tile na seção de Preferências:
```
"Ideias"  →  abre bottom sheet com:
  [O] Por tag     → campo: tag (default: "idea")
  [O] Por pasta   → campo: pasta no vault (default: "notes/ideas")  
  [O] Toda nota   → qualquer nota é considerada ideia
```
Sheet com `RadioListTile` para a estratégia + `TextField` para o valor correspondente.

### 3b — Atalho "💡 Ideia" no CreateMenu

**`lib/ui/widgets/create_menu_sheet.dart`** — na aba Capture, adicionar botão:

```dart
_captureButton(
  icon: '💡',
  label: 'Idea',
  color: AppColors.warning,
  onTap: () {
    Navigator.pop(context);
    final settings = ref.read(settingsProvider);
    _openIdeaCapture(context, settings);
  },
),
```

Helper `_openIdeaCapture`:
```dart
void _openIdeaCapture(BuildContext context, AppSettings settings) {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateNoteForm(
      initialSubtype: NoteSubtype.text,
      // Pré-preencher de acordo com a estratégia configurada:
      initialTags: settings.ideaStrategy == 'tag'
          ? [settings.ideaTag]
          : [],
      initialFolder: settings.ideaStrategy == 'folder'
          ? settings.ideaFolder
          : null,
      autofocus: true,
    ),
  ));
}
```

**`lib/ui/forms/create_note_form.dart`** — adicionar parâmetros opcionais ao construtor:
```dart
final List<String>? initialTags;
final String? initialFolder;
final bool autofocus;
```
Usar `initialTags` para pré-popular o campo de tags, `autofocus: true` para colocar o cursor no campo de título ao abrir.

### 3c — Vincular Ideia ao Objeto Atual

Quando `CreateNoteForm` for aberto de dentro de um objeto (Resource, SocialPost, Goal, etc.), aceitar um parâmetro opcional:

```dart
final ContentObject? linkedObject;
```

Se `linkedObject != null`, pré-preencher `organizers` com uma `OrganizerReference` apontando para esse objeto. Isso já funciona pelo modelo — só precisa do parâmetro sendo passado.

Nos detalhes dos objetos relevantes (`UniversalDetailView`, `SocialPostDetail`), adicionar botão "💡 Add Idea" no overflow menu ou na seção de links:
```dart
ListTile(
  leading: const Text('💡', style: TextStyle(fontSize: 18)),
  title: const Text('Add idea about this'),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateNoteForm(
      initialSubtype: NoteSubtype.text,
      initialTags: [settings.ideaTag],
      linkedObject: object,
      autofocus: true,
    ),
  )),
),
```

---

## P4 — Outline e Collection: Corrigir, Editar, Linkar

### 4a — Corrigir expansão inline na NotesScreen

**`lib/ui/screens/notes_screen.dart`** — no `_buildNoteItem`, completar o bloco de expansão:

```dart
// Substituir o bloco atual:
if (isExpanded && note.noteType == 'text')
  Padding(...)

// Por:
if (isExpanded) ...[
  const Divider(height: 1),
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: _buildNoteInlineEditor(context, note),
  ),
],
```

Helper `_buildNoteInlineEditor`:
```dart
Widget _buildNoteInlineEditor(BuildContext context, dynamic note) {
  switch (note.noteType) {
    case 'text':
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: RichTextEditor(
          content: note.body,
          expands: true,
          onChanged: (newContent) {
            final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
            ref.read(vaultProvider.notifier).updateObject(updated);
          },
        ),
      );
    case 'outline':
      return OutlineEditor(
        initialContent: note.body,
        onChanged: (newContent) {
          final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
    case 'collection':
      return SizedBox(
        height: 300,
        child: CollectionEditor(
          initialContent: note.body,
          onChanged: (newContent) {
            final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
            ref.read(vaultProvider.notifier).updateObject(updated);
          },
        ),
      );
    default:
      return const SizedBox.shrink();
  }
}
```

### 4b — CollectionView: modo leitura funcional com checkbox

O `collection_view.dart` atual renderiza como `DataTable` — bom para dados, mas ruim para checklist.

**Adicionar renderização inteligente por tipo de campo** em `collection_view.dart`:

```dart
Widget _buildCell(BuildContext context, PropertyDefinition prop,
    dynamic value, Map<String, dynamic> item, int itemIndex,
    Function(String key, dynamic val)? onCellChanged) {
  switch (prop.type) {
    case PropertyType.checkbox:
      return Checkbox(
        value: value == true || value == 'true',
        onChanged: onCellChanged == null
            ? null
            : (v) => onCellChanged(prop.id, v),
      );
    case PropertyType.rating:
      final rating = int.tryParse(value?.toString() ?? '0') ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: i < rating ? AppColors.warning : AppColors.textMuted,
        )),
      );
    default:
      return Text(value?.toString() ?? '',
        style: const TextStyle(fontSize: 14));
  }
}
```

**`onChanged` opcional** — quando `onChanged != null`, a CollectionView se torna editável inline. Quando `null`, somente leitura.

### 4c — Note detail no UniversalDetailView

**`lib/ui/screens/universal_detail_view.dart`** — no bloco `if (object is Note)` de `_buildTypeSpecificContent`, garantir que Outline e Collection têm editor funcional:

```dart
if (object is Note) ...[
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _isEditing
          ? _buildNoteEditor(context, object as Note)
          : _buildNoteViewer(context, object as Note),
    ),
  ),
],
```

`_buildNoteEditor` verifica `note.noteType` e renderiza `RichTextEditor`, `OutlineEditor` ou `CollectionEditor`. `_buildNoteViewer` renderiza `MarkdownBodyView`, `WikiTextView` (para outline) ou `CollectionView`.

**Toggle view/edit** — já foi especificado no doc2 seção 3.2. Adicionar na AppBar quando `object is Note`:
```dart
if (object is Note)
  Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _toggleBtn(Icons.visibility_outlined, false),
      _toggleBtn(Icons.edit_outlined, true),
    ]),
  ),
```

---

## P5 — Wiki-links Clicáveis no Outline (4b)

### Problema
`OutlineEditor` renderiza itens como `TextField` puro. `[[slug]]` aparece como texto sem navegação.

### Solução

**`lib/ui/widgets/outline_editor.dart`** — no `_buildItem`, detectar se o texto contém `[[...]]` e renderizar diferente:

```dart
Widget _buildItemText(int index, OutlineItem item) {
  final wikiRegex = RegExp(r'\[\[([^\]]+)\]\]');
  final hasWikiLink = wikiRegex.hasMatch(item.text);

  if (hasWikiLink && !_isEditing(index)) {
    // Modo leitura — renderizar partes clicáveis
    return _buildWikiText(item.text);
  }

  // Modo edição — TextField normal
  return _buildTextField(index, item);
}

Widget _buildWikiText(String text) {
  final spans = <InlineSpan>[];
  int lastEnd = 0;
  for (final match in RegExp(r'\[\[([^\]]+)\]\]').allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final slug = match.group(1)!;
    spans.add(TextSpan(
      text: slug,
      style: const TextStyle(color: AppColors.info,
        decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToSlug(slug),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return RichText(text: TextSpan(
    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
    children: spans,
  ));
}
```

Adicionar ao `OutlineEditor` o parâmetro:
```dart
final Function(String slug)? onWikiLinkTap;
```

No `_buildNoteViewer` do `UniversalDetailView`, passar:
```dart
OutlineEditor(
  initialContent: note.body,
  onWikiLinkTap: (slug) => _navigateToSlug(context, ref, slug),
  onChanged: ...,
)
```

Helper `_navigateToSlug`:
```dart
void _navigateToSlug(BuildContext context, WidgetRef ref, String slug) {
  final all = ref.read(allObjectsProvider).valueOrNull ?? [];
  final target = all.cast<ContentObject?>().firstWhere(
    (o) => o != null && (o.slug == slug || o.title.toLowerCase() == slug.toLowerCase()),
    orElse: () => null,
  );
  if (target != null) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UniversalDetailView(object: target),
    ));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Objeto "$slug" não encontrado')));
  }
}
```

**Botão "Inserir link" na toolbar do OutlineEditor** — ao tocar, abre `UniversalSearchPickerSheet` e insere `[[slug]]` no item focado:
```dart
IconButton(
  icon: const Icon(Icons.link_rounded, size: 18),
  onPressed: () => _insertWikiLink(index),
),

Future<void> _insertWikiLink(int index) async {
  final selected = await showModalBottomSheet<ContentObject>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UniversalSearchPickerSheet(
      title: 'Vincular objeto',
      onSelected: (obj) => Navigator.pop(context, obj),
    ),
  );
  if (selected == null) return;
  setState(() {
    _items[index].text += ' [[${selected.slug}]]';
  });
  _updateContent();
}
```

---

## P6 — Social Posts na Busca Global

### 6a — `SearchService` — incluir social posts

**`lib/services/search_service.dart`** — o serviço já recebe `List<ContentObject>` e o `SocialPost` é um `ContentObject`. O problema é que `SearchScreen` pode estar filtrando por tipo antes de chamar o serviço.

Verificar em `search_screen.dart` se `_onSearchChanged` passa `allObjects` completo (incluindo social_post) — se sim, os posts já chegam ao serviço. Se não, garantir que `allObjectsProvider` inclui `SocialPost` (já deve incluir).

**Ordenação especial para social posts** — no resultado da busca, quando `_selectedType == 'social_post'` ou quando o resultado inclui posts, ordenar por `updatedAt` desc:
```dart
// Em _onSearchChanged, após _searchService.search():
_results.sort((a, b) {
  // Posts sociais sempre por updatedAt desc
  if (a.type == 'social_post' && b.type == 'social_post') {
    final aTime = a.updatedAt;
    final bTime = b.updatedAt;
    return bTime.compareTo(aTime);
  }
  return 0; // manter ordem do searchService para outros
});
```

### 6b — Sub-filtros por plataforma e criador na SearchScreen

**`lib/ui/screens/search_screen.dart`** — adicionar ao estado:
```dart
SocialPlatform? _socialPlatformFilter;
String? _socialCreatorFilter;
```

Quando `_selectedType == 'social_post'`, exibir segunda linha de chips:
```dart
if (_selectedType == 'social_post') ...[
  const SizedBox(height: 8),
  SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      // Chips de plataforma
      ...[SocialPlatform.tiktok, SocialPlatform.instagram,
          SocialPlatform.youtube, SocialPlatform.other].map((p) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(p.name),
            selected: _socialPlatformFilter == p,
            onSelected: (_) => setState(() {
              _socialPlatformFilter = _socialPlatformFilter == p ? null : p;
              _onSearchChanged(_searchController.text, objects);
            }),
          ),
        ),
      ),
      // Chips de criador (dinâmicos dos resultados)
      ..._uniqueCreators(_results).map((handle) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text('@$handle'),
            selected: _socialCreatorFilter == handle,
            onSelected: (_) => setState(() {
              _socialCreatorFilter = _socialCreatorFilter == handle ? null : handle;
              _onSearchChanged(_searchController.text, objects);
            }),
          ),
        ),
      ),
    ]),
  ),
],
```

Aplicar filtros adicionais no `_onSearchChanged`:
```dart
if (_socialPlatformFilter != null) {
  _results = _results.whereType<SocialPost>()
      .where((p) => p.platform == _socialPlatformFilter)
      .cast<ContentObject>().toList();
}
if (_socialCreatorFilter != null) {
  _results = _results.whereType<SocialPost>()
      .where((p) => p.authorHandle == _socialCreatorFilter)
      .cast<ContentObject>().toList();
}
```

Helper:
```dart
List<String> _uniqueCreators(List<ContentObject> results) {
  return results.whereType<SocialPost>()
      .map((p) => p.authorHandle)
      .whereType<String>()
      .toSet().toList();
}
```

### 6c — Aba Social no `UniversalSearchPickerSheet`

**`lib/ui/widgets/universal_search_picker.dart`** — já existe chip `'social_post'` com label `'Posts'`. Garantir que:

1. Posts aparecem nos resultados (já devem, pois `allObjectsProvider` inclui social posts)
2. Quando filtro `'social_post'` ativo, ordenar por `updatedAt` desc:
```dart
// Após filtrar por tipo, antes de aplicar query:
if (_selectedFilter == 'social_post') {
  filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
```
3. No `ListTile` de social posts, mostrar plataforma e handle:
```dart
subtitle: Text(
  obj is SocialPost
      ? '${obj.platform.name.toUpperCase()}${obj.authorHandle != null ? " · @${obj.authorHandle}" : ""}'
      : _getTypeLabel(obj).toUpperCase(),
  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1),
),
```

---

## P7 — Resource: Vincular e Criar Objeto

### Problema confirmado
`SocialPostDetail._buildLinkedObjectsSection` tem `_pickLinkedObject(post)` que funciona (usa `UniversalSearchPickerSheet`). Mas em `UniversalDetailView` para Resource, o `onObjectSelected` callback não persiste.

### Correção em `UniversalDetailView`

**`lib/ui/screens/universal_detail_view.dart`** — encontrar onde `_pickLinkedObject` é chamado para Resource e corrigir o callback:

```dart
Future<void> _addLinkedObject(BuildContext context, WidgetRef ref) async {
  final selected = await showModalBottomSheet<ContentObject>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UniversalSearchPickerSheet(
      title: 'Vincular objeto',
      onSelected: (obj) => Navigator.pop(context, obj),
      showClear: false,
    ),
  );
  if (selected == null || !mounted) return;

  // Persiste o link em socialRefs (formato [[slug]])
  final currentRefs = List<String>.from(_getSocialRefs(object));
  final newRef = '[[${selected.slug}]]';
  if (currentRefs.contains(newRef)) return; // já vinculado

  currentRefs.add(newRef);
  final updated = _copyWithSocialRefs(object, currentRefs);
  await ref.read(vaultProvider.notifier).updateObject(updated);
  setState(() {});
}

// Helper para obter socialRefs de qualquer tipo de objeto:
List<String> _getSocialRefs(ContentObject obj) {
  if (obj is Resource) return obj.socialRefs ?? [];
  if (obj is Note) return obj.socialRefs;
  if (obj is Goal) return obj.socialRefs ?? [];
  if (obj is Task) return obj.socialRefs ?? [];
  // ... demais tipos
  return [];
}

// Helper para copiar com novos socialRefs:
ContentObject _copyWithSocialRefs(ContentObject obj, List<String> refs) {
  if (obj is Resource) return obj.copyWith(socialRefs: refs);
  if (obj is Note) return obj.copyWith(socialRefs: refs);
  if (obj is Goal) return obj.copyWith(socialRefs: refs);
  if (obj is Task) return obj.copyWith(socialRefs: refs);
  return obj;
}
```

Verificar se `Resource`, `Goal`, `Task` têm campo `socialRefs: List<String>`. Se algum não tiver, adicionar ao modelo:
```dart
// Em resource_model.dart, goal_model.dart, task_model.dart se ausente:
List<String> socialRefs;
// Com default [] no construtor, e serialização no toMarkdown/fromMarkdown
```

### Criar objeto inline no picker

`UniversalSearchPickerSheet` já tem o botão "Criar Novo Objeto" quando há texto digitado. Garantir que ao criar e voltar, o objeto novo é retornado como selecionado:

```dart
// Em _showCreateTypeChoiceDialog, após criar o objeto:
final newObject = await _createObjectOfType(context, type, initialTitle);
if (newObject != null) {
  widget.onSelected(newObject); // retorna para o caller
  Navigator.pop(context);       // fecha o sheet
}
```

---

## P8 — Widget Nativo Note/Checklist (Android)

### O que existe hoje
`WidgetService` tem `updateNote()` que salva JSON em `citrine_note_$widgetId` e chama `_update('CitrineNoteWidgetProvider')`. O widget Android existe mas sem interatividade (sem checkbox, sem adicionar item).

### 8a — Novo campo `isChecklist` em `Note`

**`lib/models/note_model.dart`**:
```dart
class Note extends ContentObject {
  // ... campos existentes ...
  bool isChecklist;  // NOVO

  Note({
    // ...
    this.isChecklist = false,
  });
}
```

Serialização:
```dart
// toMarkdown:
if (isChecklist) frontmatter['is_checklist'] = true;

// fromMarkdown:
note.isChecklist = frontmatter['is_checklist'] == true;
```

`copyWith`:
```dart
bool? isChecklist,
// ...
isChecklist: isChecklist ?? this.isChecklist,
```

### 8b — Formato de dados do checklist

Quando `isChecklist == true`, `note.body` armazena JSON no formato:
```json
{
  "items": [
    {"id": "uuid1", "text": "Maçã", "checked": false, "order": 0},
    {"id": "uuid2", "text": "Leite", "checked": true,  "order": 1}
  ]
}
```

### 8c — UI de checklist no app

**Novo widget: `lib/ui/widgets/checklist_view.dart`**:

```dart
class ChecklistView extends ConsumerWidget {
  final Note note;
  final bool editable;

  const ChecklistView({super.key, required this.note, this.editable = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _parseItems(note.body);

    return Column(
      children: [
        // Lista de itens
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorder: (old, nw) => _onReorder(items, old, nw, note, ref),
          itemBuilder: (ctx, i) => _buildItem(ctx, ref, items[i], note),
        ),
        // Campo de adicionar item
        if (editable) _buildAddItemField(context, ref, note),
      ],
    );
  }

  Widget _buildItem(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> item, Note note) {
    final checked = item['checked'] == true;
    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(item['id'], note, ref),
      child: ListTile(
        key: ValueKey(item['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Checkbox(
          value: checked,
          onChanged: (_) => _toggleItem(item['id'], note, ref),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item['text'] ?? '',
          style: TextStyle(
            fontSize: 15,
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked
                ? AppTheme.textMutedColor(ctx)
                : AppTheme.textPrimaryColor(ctx),
          ),
        ),
        trailing: ReorderableDragStartListener(
          index: 0, // será sobrescrito pelo ReorderableListView
          child: Icon(Icons.drag_handle_rounded, size: 18,
            color: AppTheme.textMutedColor(ctx)),
        ),
      ),
    );
  }

  Widget _buildAddItemField(BuildContext context, WidgetRef ref, Note note) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const Icon(Icons.add_rounded, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Add item...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (text) {
            if (text.trim().isEmpty) return;
            _addItem(text.trim(), note, ref);
            ctrl.clear();
          },
        )),
      ]),
    );
  }

  // Helpers para manipular items:
  List<Map<String, dynamic>> _parseItems(String body) {
    try {
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } catch (_) { return []; }
  }

  void _toggleItem(String id, Note note, WidgetRef ref) {
    final items = _parseItems(note.body);
    final idx = items.indexWhere((i) => i['id'] == id);
    if (idx < 0) return;
    items[idx] = {...items[idx], 'checked': !(items[idx]['checked'] == true)};
    _save(items, note, ref);
  }

  void _addItem(String text, Note note, WidgetRef ref) {
    final items = _parseItems(note.body);
    items.add({'id': const Uuid().v4(), 'text': text,
      'checked': false, 'order': items.length});
    _save(items, note, ref);
  }

  void _removeItem(String id, Note note, WidgetRef ref) {
    final items = _parseItems(note.body)..removeWhere((i) => i['id'] == id);
    _save(items, note, ref);
  }

  void _save(List<Map<String, dynamic>> items, Note note, WidgetRef ref) {
    final updated = note.copyWith(
      body: jsonEncode({'items': items}),
      updatedAt: DateTime.now(),
    );
    ref.read(vaultProvider.notifier).updateObject(updated);
    // Sincronizar widget nativo:
    WidgetService.updateChecklist(noteId: note.id, title: note.title, items: items);
  }
}
```

**No `UniversalDetailView`**, quando `object is Note && note.isChecklist`:
```dart
// Em _buildTypeSpecificContent para Note:
if ((object as Note).isChecklist)
  SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: ChecklistView(note: object as Note),
  ))
else
  // editor/viewer normal de nota
```

### 8d — `WidgetService.updateChecklist()`

**`lib/services/widget_service.dart`** — adicionar:
```dart
static const _checklistProvider = 'CitrineChecklistWidgetProvider';

static Future<void> updateChecklist({
  required String noteId,
  required String title,
  required List<Map<String, dynamic>> items,
}) async {
  try {
    await _saveJson('citrine_checklist', {
      'noteId': noteId,
      'title': title,
      'items': items,                          // [{id, text, checked, order}]
      'linkUri': 'citrine:///detail/$noteId',
      'addUri': 'citrine:///checklist/$noteId/add',
      'toggleUriBase': 'citrine:///checklist/$noteId/toggle/',
    });
    await _update(_checklistProvider);
  } catch (e) {
    debugPrint('[WidgetService] updateChecklist failed: $e');
  }
}
```

O widget Android (`CitrineChecklistWidgetProvider`) precisa ser criado/atualizado no lado nativo (Kotlin/Java) para:
- Exibir título da lista
- Listar itens com checkbox nativo
- Toggle de item via deeplink `citrine:///checklist/$noteId/toggle/$itemId`
- Botão "+" via deeplink `citrine:///checklist/$noteId/add`
- O app Flutter intercepta os deeplinks e chama `_toggleItem`/`_addItem` via `NotesProvider`

### 8e — Selecionar qual nota exibir no widget

**`WidgetService.saveChecklistWidgetConfig()`** — novo método:
```dart
static Future<void> saveChecklistWidgetConfig({
  required int widgetId,
  required String noteId,
  required String noteTitle,
}) async {
  await _saveJson('citrine_checklist_config_$widgetId', {
    'noteId': noteId,
    'title': noteTitle,
  });
}
```

**No app** — quando usuário long-press no widget Android e seleciona "Configure", o sistema chama uma Activity de configuração que abre o app numa tela de seleção de nota. Criar `ChecklistWidgetConfigScreen`:

```dart
class ChecklistWidgetConfigScreen extends ConsumerWidget {
  final int widgetId;
  const ChecklistWidgetConfigScreen({super.key, required this.widgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    // Mostrar todas as notas com isChecklist=true primeiro, depois as demais
    final checklists = notes.where((n) => n.isChecklist).toList();
    final others = notes.where((n) => !n.isChecklist).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select note for widget')),
      body: ListView(children: [
        if (checklists.isNotEmpty) ...[
          _sectionHeader('Checklists'),
          ...checklists.map((n) => _noteTile(context, ref, n)),
        ],
        _sectionHeader('Other notes'),
        ...others.map((n) => _noteTile(context, ref, n)),
      ]),
    );
  }

  Widget _noteTile(BuildContext context, WidgetRef ref, Note note) {
    return ListTile(
      leading: Text(note.isChecklist ? '✅' : '📝',
        style: const TextStyle(fontSize: 20)),
      title: Text(note.title),
      onTap: () async {
        await WidgetService.saveChecklistWidgetConfig(
          widgetId: widgetId,
          noteId: note.id,
          noteTitle: note.title,
        );
        // Sincronizar conteúdo atual da nota no widget:
        final items = _parseItems(note.body);
        await WidgetService.updateChecklist(
          noteId: note.id, title: note.title, items: items);
        Navigator.pop(context);
      },
    );
  }
}
```

### 8f — Criar nova nota como checklist

**`lib/ui/forms/create_note_form.dart`** — adicionar opção de tipo "Checklist" no seletor de subtipo:
```dart
// Adicionar ao seletor de tipo junto com Text/Outline/Collection:
_typeButton('Checklist', Icons.checklist_rounded, NoteSubtype.text,
  isChecklist: true),
```

Quando selecionado, o form cria uma `Note` com `subtype: text, isChecklist: true` e `body: '{"items":[]}'`.

---

## P9 — Hábito de Baixa Frequência

### 9a — Novos campos no modelo

**`lib/models/habit_model.dart`**:
```dart
class Habit extends ContentObject {
  // ... campos existentes ...
  int? frequencyDays;        // NOVO: meta de dias entre cada execução (ex: 30)
  bool isFlexibleFrequency;  // NOVO: true = não é hábito diário rígido
}
```

Construtor: `this.frequencyDays, this.isFlexibleFrequency = false`

`copyWith`:
```dart
int? frequencyDays,
bool? isFlexibleFrequency,
// ...
frequencyDays: frequencyDays ?? this.frequencyDays,
isFlexibleFrequency: isFlexibleFrequency ?? this.isFlexibleFrequency,
```

Serialização (`toMarkdown`/`fromMarkdown`):
```dart
// toMarkdown:
if (frequencyDays != null) frontmatter['frequency_days'] = frequencyDays;
if (isFlexibleFrequency) frontmatter['flexible_frequency'] = true;

// fromMarkdown:
habit.frequencyDays = int.tryParse(frontmatter['frequency_days']?.toString() ?? '');
habit.isFlexibleFrequency = frontmatter['flexible_frequency'] == true;
```

### 9b — Formulário: `CreateHabitForm`

**`lib/ui/forms/create_habit_form.dart`** — adicionar seção de frequência flexível.

Quando `priority == TaskPriority.low` OU quando o usuário ativa manualmente o toggle, mostrar:

```dart
SwitchListTile(
  title: const Text('Flexible frequency'),
  subtitle: const Text('No fixed daily schedule — just a target interval'),
  value: _isFlexibleFrequency,
  onChanged: (v) => setState(() {
    _isFlexibleFrequency = v;
    if (v) _schedulers.clear(); // limpa schedulers rígidos
  }),
),

if (_isFlexibleFrequency) ...[
  const SizedBox(height: 8),
  Row(children: [
    const Text('Target: every '),
    SizedBox(
      width: 64,
      child: TextField(
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(isDense: true),
        onChanged: (v) => setState(() => _frequencyDays = int.tryParse(v)),
      ),
    ),
    const Text(' days'),
  ]),
],
```

Ao salvar: `Habit(..., frequencyDays: _frequencyDays, isFlexibleFrequency: _isFlexibleFrequency)`

### 9c — UX na `HabitsScreen`: seção "Periodic"

**`lib/ui/screens/habits_screen.dart`** — na `_TodayView`, após a lista de hábitos normais, adicionar:

```dart
// Ao final do ListView, depois de ...habits.map(...):
Builder(builder: (context) {
  final periodicHabits = ref.watch(habitsProvider)
      .where((h) =>
        h.status == HabitStatus.active &&
        !h.archived &&
        h.isFlexibleFrequency &&
        h.frequencyDays != null)
      .toList();

  if (periodicHabits.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      // Separador com label
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('PERIODIC', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.08,
          color: AppTheme.textMutedColor(context))),
      ]),
      const SizedBox(height: 10),
      ...periodicHabits.map((h) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _PeriodicHabitCard(habit: h),
      )),
    ],
  );
}),
```

**Novo widget `_PeriodicHabitCard`**:

```dart
class _PeriodicHabitCard extends ConsumerWidget {
  final Habit habit;
  const _PeriodicHabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = habit.daysSinceLastCompletion;
    final freq = habit.frequencyDays!;
    final ratio = days < 0 ? 0.0 : (days / freq).clamp(0.0, 1.5);

    final color = ratio > 1.0
        ? AppColors.error
        : ratio > 0.75
            ? AppColors.warning
            : AppColors.habitGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(habit.displayTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            // Botão agendar
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.calendar_today_rounded, size: 18, color: color),
              onPressed: () => _showScheduleSheet(context, ref),
            ),
            // Botão marcar feito
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(habitsProvider.notifier)
                    .toggleHabit(habit, DateTime.now());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: habit.isCompletedToday ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                ),
                child: habit.isCompletedToday
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // Meta e urgência
          Text(
            days < 0
                ? 'Never done · target: every ${freq}d'
                : 'Done ${days}d ago · target: every ${freq}d',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          // Barra de urgência
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text('Add to planner'),
          onTap: () {
            Navigator.pop(ctx);
            _pickDateForHabit(context, ref);
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_rounded),
          title: const Text('Start Pomodoro now'),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PomodoroScreen()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Remind me in X days'),
          onTap: () {
            Navigator.pop(ctx);
            _setReminderDays(context, ref);
          },
        ),
      ]),
    ));
  }

  void _pickDateForHabit(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(
        Duration(days: habit.frequencyDays ?? 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    // Criar uma task ou reminder para esse dia com o título do hábito:
    final reminder = Reminder(
      title: habit.displayTitle,
      time: DateTime(picked.year, picked.month, picked.day, 9, 0),
    );
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for ${DateFormat('d MMM').format(picked)}')));
    }
  }

  void _setReminderDays(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(
      text: habit.frequencyDays?.toString() ?? '7');
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remind me in how many days?'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffix: Text('days')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Set')),
        ],
      ),
    );
    if (days == null || !context.mounted) return;
    final reminderDate = DateTime.now().add(Duration(days: days));
    final reminder = Reminder(
      title: habit.displayTitle,
      time: DateTime(reminderDate.year, reminderDate.month,
        reminderDate.day, 9, 0),
    );
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder in $days days')));
    }
  }
}
```

---

## P10 — Vincular Livros e Lugares ao Post TikTok

### 10a — Novo modelo `PlaceRef`

**Novo arquivo: `lib/models/place_ref.dart`**:
```dart
class PlaceRef {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? googlePlaceId;
  final String? notes;

  const PlaceRef({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.googlePlaceId,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name,
    if (address != null) 'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (googlePlaceId != null) 'place_id': googlePlaceId,
    if (notes != null) 'notes': notes,
  };

  factory PlaceRef.fromMap(Map<String, dynamic> m) => PlaceRef(
    id: m['id'] ?? const Uuid().v4(),
    name: m['name'] ?? '',
    address: m['address'],
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    googlePlaceId: m['place_id'],
    notes: m['notes'],
  );
}
```

### 10b — Novo campo `places` em `SocialPost`

**`lib/models/social_post.dart`**:
```dart
List<PlaceRef> places;  // NOVO

// Construtor: List<PlaceRef>? places → this.places = places ?? []

// toMarkdown:
if (places.isNotEmpty)
  frontmatter['places'] = places.map((p) => p.toMap()).toList();

// fromMarkdown:
if (frontmatter['places'] is List) {
  post.places = (frontmatter['places'] as List)
      .map((p) => PlaceRef.fromMap(p as Map<String, dynamic>))
      .toList();
}

// copyWith:
List<PlaceRef>? places,
places: places ?? List.from(this.places),
```

### 10c — Seção de lugares no `SocialPostDetail`

**`lib/ui/screens/social_post_detail.dart`** — adicionar seção após `_buildLinkedObjectsSection`:

```dart
_buildPlacesSection(post),
```

```dart
Widget _buildPlacesSection(SocialPost post) {
  return _section(
    title: '📍 Places',
    trailing: TextButton.icon(
      onPressed: () => _addPlace(post),
      icon: const Icon(Icons.add_location_rounded, size: 18),
      label: const Text('Add'),
    ),
    child: post.places.isEmpty
        ? const Text('No places added',
            style: TextStyle(color: AppColors.textMuted))
        : Column(
            children: post.places.map((place) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_rounded, color: AppColors.primary),
              title: Text(place.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
              subtitle: place.address != null
                  ? Text(place.address!, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11))
                  : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (place.lat != null && place.lng != null)
                  IconButton(
                    icon: const Icon(Icons.map_rounded, size: 18),
                    onPressed: () => _openInMaps(place),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18,
                    color: AppColors.error),
                  onPressed: () => _removePlace(post, place.id),
                ),
              ]),
            )).toList(),
          ),
  );
}

Future<void> _addPlace(SocialPost post) async {
  // Opção 1: campo de texto simples (sempre disponível)
  // Opção 2: busca no Google Places (se disponível)
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add place'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Name (required)')),
        const SizedBox(height: 8),
        TextField(controller: addressCtrl,
          decoration: const InputDecoration(hintText: 'Address (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add')),
      ],
    ),
  );

  if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

  final newPlace = PlaceRef(
    id: const Uuid().v4(),
    name: nameCtrl.text.trim(),
    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
  );
  final updated = post.copyWith(
    places: [...post.places, newPlace]);
  ref.read(socialPostsProvider.notifier).updatePost(updated);
}

void _removePlace(SocialPost post, String placeId) {
  final updated = post.copyWith(
    places: post.places.where((p) => p.id != placeId).toList());
  ref.read(socialPostsProvider.notifier).updatePost(updated);
}

void _openInMaps(PlaceRef place) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}');
  if (await canLaunchUrl(uri)) launchUrl(uri);
}
```

### 10d — Criar resource de livro rapidamente

No `_buildLinkedObjectsSection` do `SocialPostDetail`, ao lado do botão "Vincular", adicionar botão específico para criar resource rápido:

```dart
// No trailing do _section de objetos vinculados:
Row(mainAxisSize: MainAxisSize.min, children: [
  TextButton.icon(
    onPressed: () => _quickCreateResource(post),
    icon: const Icon(Icons.book_outlined, size: 18),
    label: const Text('+ Book'),
  ),
  TextButton.icon(
    onPressed: () => _pickLinkedObject(post),
    icon: const Icon(Icons.add_link_rounded, size: 18),
    label: const Text('Link'),
  ),
]),
```

```dart
Future<void> _quickCreateResource(SocialPost post) async {
  final ctrl = TextEditingController();
  final authorCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add book/resource'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Title (required)')),
        const SizedBox(height: 8),
        TextField(controller: authorCtrl,
          decoration: const InputDecoration(hintText: 'Author (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Create')),
      ],
    ),
  );

  if (confirmed != true || ctrl.text.trim().isEmpty || !mounted) return;

  final resource = Resource(
    title: ctrl.text.trim(),
    resourceType: 'Book',
    author: authorCtrl.text.trim().isEmpty ? null : authorCtrl.text.trim(),
    status: ResourceStatus.toConsume,
  );
  await ref.read(resourcesProvider.notifier).addResource(resource);

  // Vincular ao post automaticamente:
  final newRef = '[[${resource.slug}]]';
  final updated = post.copyWith(
    socialRefs: [...post.socialRefs, newRef]);
  ref.read(socialPostsProvider.notifier).updatePost(updated);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${resource.title}" created and linked')));
  }
}
```

---

## P11 — Eisenhower Matrix (Etapa 1)

### 11a — Modelos

**Adicionar ao `lib/models/saved_filter.dart`** (arquivo que precisa ser criado, ver spec do sistema de filtros):

```dart
enum ViewMode { grid, list, grouped, matrix }  // adicionar 'matrix'

class MatrixConfig {
  final String axisXProperty;   // propriedade para colunas, ex: 'priority'
  final List<String> axisXValues; // 2 valores = 2 colunas, ex: ['high','low']
  final String axisXLabels;     // ex: 'Important' / 'Not important'
  final String axisYProperty;   // propriedade para linhas, ex: 'tags'
  final List<String> axisYValues; // 2 valores = 2 linhas
  final String axisYLabels;
  final String title;

  const MatrixConfig({
    required this.axisXProperty,
    required this.axisXValues,
    this.axisXLabels = '',
    required this.axisYProperty,
    required this.axisYValues,
    this.axisYLabels = '',
    required this.title,
  });

  Map<String, dynamic> toJson() => {
    'axisXProperty': axisXProperty,
    'axisXValues': axisXValues,
    'axisXLabels': axisXLabels,
    'axisYProperty': axisYProperty,
    'axisYValues': axisYValues,
    'axisYLabels': axisYLabels,
    'title': title,
  };

  factory MatrixConfig.fromJson(Map<String, dynamic> j) => MatrixConfig(
    axisXProperty: j['axisXProperty'] ?? 'priority',
    axisXValues: List<String>.from(j['axisXValues'] ?? []),
    axisXLabels: j['axisXLabels'] ?? '',
    axisYProperty: j['axisYProperty'] ?? 'tags',
    axisYValues: List<String>.from(j['axisYValues'] ?? []),
    axisYLabels: j['axisYLabels'] ?? '',
    title: j['title'] ?? 'Matrix',
  );

  // Preset de Eisenhower clássico:
  static MatrixConfig get eisenhower => const MatrixConfig(
    title: 'Eisenhower',
    axisXProperty: 'priority',
    axisXValues: ['high', 'low'],
    axisXLabels: 'Important',
    axisYProperty: 'tags',
    axisYValues: ['urgent', 'not-urgent'],
    axisYLabels: 'Urgent',
  );
}
```

Adicionar `MatrixConfig? matrixConfig` em `SavedFilter`.

### 11b — `MatrixScreen`

**Novo arquivo: `lib/ui/screens/matrix_screen.dart`**:

```dart
class MatrixScreen extends ConsumerStatefulWidget {
  final SavedFilter filter;
  const MatrixScreen({super.key, required this.filter});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider);
    final cfg = widget.filter.matrixConfig!;

    // Aplicar filtros do SavedFilter:
    final filtered = widget.filter.apply(allTasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(cfg.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {/* abrir configuração da matrix */},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Header eixo X
          Row(children: [
            const SizedBox(width: 32),
            Expanded(child: Row(children: cfg.axisXValues.map((v) =>
              Expanded(child: Center(child: Text(v,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted))))).toList())),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Row(children: [
              // Header eixo Y (rotacionado)
              SizedBox(width: 32, child: Column(children: cfg.axisYValues.map((v) =>
                Expanded(child: Center(child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(v, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                )))).toList())),
              // 4 quadrantes
              Expanded(
                child: Column(children: cfg.axisYValues.map((yVal) =>
                  Expanded(child: Row(children: cfg.axisXValues.map((xVal) =>
                    Expanded(child: _buildQuadrant(context, ref, filtered, cfg, xVal, yVal)),
                  ).toList())),
                ).toList()),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuadrant(BuildContext context, WidgetRef ref,
      List<Task> tasks, MatrixConfig cfg, String xVal, String yVal) {

    // Filtrar tasks para este quadrante:
    final items = tasks.where((t) {
      final xMatch = _matchesProp(t, cfg.axisXProperty, xVal);
      final yMatch = _matchesProp(t, cfg.axisYProperty, yVal);
      return xMatch && yMatch;
    }).toList();

    // Cor do quadrante baseada na posição:
    final isTopLeft = cfg.axisXValues.indexOf(xVal) == 0 &&
        cfg.axisYValues.indexOf(yVal) == 0;
    final quadrantColor = isTopLeft
        ? AppColors.error.withValues(alpha: 0.05)
        : AppColors.surfaceVariant.withValues(alpha: 0.3);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) =>
          _moveToQuadrant(details.data, xVal, yVal, cfg, ref),
      builder: (ctx, candidates, _) => Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.08)
              : quadrantColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          // Badge de contagem:
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('${items.length}',
                style: const TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          ),
          // Lista de items:
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            children: items.map((t) => _buildMatrixCard(t, ref)).toList(),
          )),
        ]),
      ),
    );
  }

  Widget _buildMatrixCard(Task task, WidgetRef ref) {
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(task.title, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _cardContent(task, ref)),
      child: _cardContent(task, ref),
    );
  }

  Widget _cardContent(Task task, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => UniversalDetailView(object: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardFillColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          // Checkbox inline:
          SizedBox(width: 20, height: 20,
            child: Checkbox(
              value: task.stage == TaskStage.finalized,
              onChanged: (_) => ref.read(tasksProvider.notifier)
                  .updateTask(task.copyWith(stage: TaskStage.finalized)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(task.title, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              decoration: task.stage == TaskStage.finalized
                  ? TextDecoration.lineThrough : null,
            ))),
        ]),
      ),
    );
  }

  bool _matchesProp(Task task, String property, String value) {
    return switch (property) {
      'priority' => task.priority.name == value,
      'tags' => task.tags.contains(value),
      'status' || 'stage' => task.stage.name == value,
      _ => false,
    };
  }

  void _moveToQuadrant(Task task, String xVal, String yVal,
      MatrixConfig cfg, WidgetRef ref) {
    Task updated = task;
    // Atualizar propriedade X:
    if (cfg.axisXProperty == 'priority') {
      updated = updated.copyWith(
        priority: TaskPriority.values.firstWhere((p) => p.name == xVal,
          orElse: () => task.priority));
    }
    // Atualizar propriedade Y (ex: tags):
    if (cfg.axisYProperty == 'tags') {
      // Remove os valores de eixo Y que existiam, adiciona o novo:
      final cleanTags = task.tags
          .where((t) => !cfg.axisYValues.contains(t))
          .toList();
      updated = updated.copyWith(tags: [...cleanTags, yVal]);
    }
    ref.read(tasksProvider.notifier).updateTask(updated);
  }
}
```

### 11c — Acessar a Matrix

No `FilterSortSheet` (quando implementado), quando `viewMode == ViewMode.matrix`, o botão "Apply" navega para `MatrixScreen(filter: draft)`.

Como atalho antes disso, adicionar em qualquer tela de tasks um botão temporário:
```dart
IconButton(
  icon: const Icon(Icons.grid_4x4_rounded),
  tooltip: 'Eisenhower Matrix',
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => MatrixScreen(
      filter: SavedFilter(
        id: 'eisenhower',
        name: 'Eisenhower',
        targetType: 'task',
        matrixConfig: MatrixConfig.eisenhower,
      ),
    ),
  )),
),
```

---

## P12 — Unificar UI de Vincular Objetos

### Referência visual: como está hoje no SocialPostDetail

O `SocialPostDetail._buildLinkedObjectsSection` é a referência de UX desejada:
- Título da seção "Objetos vinculados"
- Botão "Vincular" com ícone `add_link_rounded` no trailing
- Itens agrupados por `displayType` com label uppercase muted
- Cada item como `InputChip` com título, onPressed navega, onDeleted remove

### Padrão unificado para todos os objetos

**Criar widget reutilizável: `lib/ui/widgets/linked_objects_section.dart`**:

```dart
class LinkedObjectsSection extends ConsumerWidget {
  final ContentObject owner;           // objeto dono dos links
  final List<String> socialRefs;       // [[slug]] refs atuais
  final Future<void> Function(ContentObject selected) onAdd;
  final Future<void> Function(String slug) onRemove;
  final String? addButtonLabel;        // default: 'Link'

  const LinkedObjectsSection({
    super.key,
    required this.owner,
    required this.socialRefs,
    required this.onAdd,
    required this.onRemove,
    this.addButtonLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final linked = _resolve(allObjects, socialRefs);
    final grouped = <String, List<ContentObject>>{};
    for (final obj in linked) {
      grouped.putIfAbsent(obj.displayType, () => []).add(obj);
    }

    return _Section(
      title: 'Linked objects',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton.icon(
          onPressed: () => _pickObject(context),
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: Text(addButtonLabel ?? 'Link'),
        ),
      ]),
      child: linked.isEmpty
          ? const Text('No linked objects',
              style: TextStyle(color: AppColors.textMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                      style: const TextStyle(color: AppColors.textMuted,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: entry.value.map((obj) => InputChip(
                        label: Text(obj.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                            UniversalDetailView(object: obj))),
                        onDeleted: () => onRemove('[[${obj.slug}]]'),
                      )).toList(),
                    ),
                  ],
                ),
              )).toList(),
            ),
    );
  }

  List<ContentObject> _resolve(List<ContentObject> all, List<String> refs) {
    final slugs = refs.map((r) =>
      r.replaceAll('[[', '').replaceAll(']]', '').trim()).toSet();
    return all.where((o) => slugs.contains(o.slug)).toList();
  }

  void _pickObject(BuildContext context) async {
    final selected = await showModalBottomSheet<ContentObject>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Link object',
        onSelected: (obj) => Navigator.pop(context, obj),
        showClear: false,
      ),
    );
    if (selected != null) await onAdd(selected);
  }
}
```

**Substituir em todos os arquivos que têm seção de links**:

| Arquivo | Substituir |
|---------|-----------|
| `social_post_detail.dart` | `_buildLinkedObjectsSection` → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Resource) | seção de links → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Note) | `socialRefs` → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Goal) | social refs → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Task) | social refs → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Habit) | social refs → usa `LinkedObjectsSection` |

**Helper genérico para salvar socialRef em qualquer objeto**:

```dart
// Em um arquivo utilitário lib/ui/utils/social_ref_utils.dart:
Future<void> addSocialRef(
    ContentObject obj, ContentObject target, WidgetRef ref) async {
  final slug = '[[${target.slug}]]';
  final current = _getRefs(obj);
  if (current.contains(slug)) return;
  final updated = _withRefs(obj, [...current, slug]);
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

Future<void> removeSocialRef(
    ContentObject obj, String slugRef, WidgetRef ref) async {
  final updated = _withRefs(obj,
    _getRefs(obj).where((r) => r != slugRef).toList());
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

List<String> _getRefs(ContentObject obj) {
  if (obj is SocialPost) return obj.socialRefs;
  if (obj is Note)       return obj.socialRefs;
  if (obj is Resource)   return obj.socialRefs ?? [];
  if (obj is Goal)       return obj.socialRefs ?? [];
  if (obj is Task)       return obj.socialRefs ?? [];
  if (obj is Habit)      return obj.socialRefs ?? [];
  return [];
}

ContentObject _withRefs(ContentObject obj, List<String> refs) {
  if (obj is SocialPost) return obj.copyWith(socialRefs: refs);
  if (obj is Note)       return obj.copyWith(socialRefs: refs);
  if (obj is Resource)   return obj.copyWith(socialRefs: refs);
  if (obj is Goal)       return obj.copyWith(socialRefs: refs);
  if (obj is Task)       return obj.copyWith(socialRefs: refs);
  if (obj is Habit)      return obj.copyWith(socialRefs: refs);
  return obj;
}
```

**Uso em qualquer detalhe**:
```dart
LinkedObjectsSection(
  owner: object,
  socialRefs: _getRefs(object),
  onAdd: (selected) => addSocialRef(object, selected, ref),
  onRemove: (slug) => removeSocialRef(object, slug, ref),
),
```

---

## Checklist de arquivos a criar/modificar

### Novos arquivos
- [ ] `lib/ui/utils/layout_utils.dart`
- [ ] `lib/ui/utils/social_ref_utils.dart`
- [ ] `lib/ui/widgets/linked_objects_section.dart`
- [ ] `lib/ui/widgets/checklist_view.dart`
- [ ] `lib/ui/screens/matrix_screen.dart`
- [ ] `lib/ui/screens/checklist_widget_config_screen.dart`
- [ ] `lib/models/place_ref.dart`

### Modificar modelos
- [ ] `lib/models/note_model.dart` — `isChecklist: bool`
- [ ] `lib/models/habit_model.dart` — `frequencyDays: int?`, `isFlexibleFrequency: bool`
- [ ] `lib/models/social_post.dart` — `places: List<PlaceRef>`
- [ ] `lib/models/resource_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/goal_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/task_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/habit_model.dart` — verificar/adicionar `socialRefs: List<String>`

### Modificar providers
- [ ] `lib/providers/settings_provider.dart` — `ideaStrategy`, `ideaTag`, `ideaFolder`, `setIdeaStrategy()`

### Modificar serviços
- [ ] `lib/services/obsidian_service.dart` — encoding utf8 em toda leitura/escrita
- [ ] `lib/services/google_drive_sync_service.dart` — encoding utf8
- [ ] `lib/services/backup_service.dart` — encoding utf8
- [ ] `lib/services/widget_service.dart` — `updateChecklist()`, `saveChecklistWidgetConfig()`

### Modificar UI
- [ ] `lib/ui/screens/notes_screen.dart` — `_buildNoteInlineEditor` com cases para outline/collection
- [ ] `lib/ui/screens/universal_detail_view.dart` — toggle view/edit para Note, `_addLinkedObject` funcional, usar `LinkedObjectsSection` em todos os tipos
- [ ] `lib/ui/screens/social_post_detail.dart` — `_buildPlacesSection`, `_quickCreateResource`, usar `LinkedObjectsSection`
- [ ] `lib/ui/screens/search_screen.dart` — sub-filtros social, ordenação por updatedAt, buscas recentes persistidas
- [ ] `lib/ui/screens/habits_screen.dart` — semana começa segunda, `_PeriodicHabitCard`, seção Periodic no TodayView
- [ ] `lib/ui/screens/goals_screen.dart` — fix crash Color(), fix Flexible no deadline
- [ ] `lib/ui/widgets/outline_editor.dart` — wiki-links clicáveis, botão inserir link
- [ ] `lib/ui/widgets/collection_view.dart` — renderização por tipo (checkbox interativo)
- [ ] `lib/ui/widgets/universal_search_picker.dart` — ordenação por updatedAt para social, exibir plataforma/handle
- [ ] `lib/ui/widgets/create_menu_sheet.dart` — botão "💡 Idea" na aba Capture
- [ ] `lib/ui/forms/create_note_form.dart` — params `initialTags`, `initialFolder`, `linkedObject`, `autofocus`, tipo Checklist
- [ ] `lib/ui/forms/create_habit_form.dart` — toggle frequência flexível, campo `frequencyDays`
- [ ] Todos os `.dart` com strings bugadas (Ã§ etc) — corrigir encoding

# 2026-06-07 16H 
 Gap Analysis Citrine × Guidelines V3 — Baseado no Código Real
> Análise feita com base no código Dart lido diretamente: `automation_service.dart`, `markdown_parser.dart`, `vault_provider.dart`, `widget_sync_provider.dart`, `widget_service.dart`, `dataview_generator.dart`, `obsidian_service.dart`, `triple_check_sheet.dart`, `steering_sheet.dart`, `import_vault_screen.dart`, `scheduler_page.dart`, `social_screen.dart`.
>
> **Legenda:** ✅ Implementado e confirmado no código · ⚠️ Parcial ou com ressalva real · ❌ Ausente ou stub



### ❌ Ausências confirmadas no código

| Item | Por quê está ausente |
|---|---|
| **Card PMN ao navegar por `referenced_dates`** | `AllObjectsNotifier` não indexa PMNs por `referenced_dates`. Arquivos `daily/YYYY-MM-WNN.md` são parseados como daily notes comuns (pelo padrão de data no nome), não como PMN com lookup por datas referenciadas |
| **Badge ⚠ de task parada há 7+ dias** | Nenhuma lógica em nenhum arquivo calcula "dias no mesmo stage sem progresso". O `TripleCheckBadge` existe como widget mas não há código que o exiba automaticamente |
| **Energy Map auto-gerado** | Nenhum código lê Field Notes com `category: energy` e gera sugestão de blocos de energia |
| **Lookup de `referenced_dates` do PMN** | PMN tem o campo no modelo mas não há indexação reversa para mostrar card ao navegar para as datas |
| **`pushSessionToCalendar` com tipo correto** | Ainda aceita `Task` em vez de `Session` conforme `correcoes.md` — não foi possível confirmar correção no código lido |
| **Múltiplos calendários Google** | `fetchEvents` só busca 'primary' |
| **Auto-archive de inbox após 30 dias com badge na nav** | O auto-archive existe no código mas o badge só conta itens ativos — sem distinção de itens "vencidos" |
| **Dataview queries compatíveis com `mood::` como WikiLink nas daily notes** | `mood-index.md` usa `WHERE mood` mas as daily notes armazenam mood no frontmatter como string simples (`mood_label: "Calma"`), não como WikiLink. Inconsistência entre formato Dataview e formato real |

### ⚠️ Parcialmente implementado

| Item | O que falta especificamente |
|---|---|
| **PMN (`entry_type: pmn`)** | Modelo existe, form existe (`create_pmn_form.dart`). Mas o arquivo é salvo como qualquer objeto — não em `daily/YYYY-MM-WNN.md` com a lógica de mês canônico de `date_range_start` |
| **`automation_service.dart`** | Não foi possível ler o arquivo completo nesta sessão — só o fim do `widget_service.dart` chegou. `executeHabitActions` e `executeHabitSlotActions` estão sendo chamados no vault_provider, mas o conteúdo real das ações não foi confirmado |
| **Combined Analysis — emoji como marcador no gráfico** | `citrine_chart.dart` existe mas não foi lido. A spec pede emoji do mood como marcador visual nos pontos — feature muito específica |
| **Scheduler: `unreachable_switch_default`** | `scheduler_picker.dart` ainda tem cases não cobertos (identificado no analyze_output anterior) |
| **Purga de `_conflicts/` após 30 dias** | `_purgeOldDeletedFiles()` só varre `_deleted/`, não `_conflicts/` |
| **Backup ZIP periódico em `_backups/`** | `backup_service.dart` existe mas não foi lido — conteúdo desconhecido |
| **Widgets nativos do OS (home screen/lock screen)** | `widget_service.dart` usa `home_widget` que **é** um package real para widgets nativos — mas o código Kotlin/Swift complementar (AppWidgetProvider, etc.) não foi confirmado. A integração Flutter existe; a parte nativa precisa de verificação |
| **Social Post: `social_refs` linkando a objetos** | Campo existe no modelo e UI implementada em `_associateObject()`, mas persiste como array de WikiLink strings — sem UI de visualização dos objetos associados na detail view |

---

## PARTE 4 — CORREÇÕES DAS ANÁLISES ANTERIORES

As versões V1 e V2 deste documento tinham erros significativos que o código real contradiz:

| Afirmação anterior (incorreta) | Realidade confirmada no código |
|---|---|
| "`_dateRegex` e `_journalTimeRegex` não usados — parsing de timestamp quebrado" | Esses campos não existem mais. O parser atual usa regex inline em `parseJournalEntries()` que funciona corretamente |
| "Body de notas não está sendo salvo (`_bodyController` não usado)" | O `rich_text_editor.dart` existe como widget separado — o controller é gerenciado internamente pelo widget, não pelo form pai |
| "Time Block de sessions não persiste (`_timeSlot` não usado)" | Não foi possível confirmar nesta leitura — `create_session_form.dart` não foi lido |
| "Sistema de Actions nunca executa" | `AutomationService.executeHabitActions()` e `executeHabitSlotActions()` são chamados explicitamente no `toggleHabit()` |
| "Purga de `_deleted/` não existe" | `_purgeOldDeletedFiles()` existe e é chamado no `build()` do VaultNotifier |
| "Social Post não tem tela" | `SocialScreen` completamente implementada com grid/timeline, multi-select, coleções, filtros por plataforma, auto-watch por visibilidade |
| "Import de vault Obsidian não existe" | `ImportVaultScreen` com scan prévio, validação de permissão e importação implementados |
| "Scheduler Page não existe" | `SchedulerPage` implementada com lista de agendados e previsão por Day Theme |
| "Dataview não é gerado" | `DataviewGenerator` gera 6 índices + blocks por tracker/analysis |
| "`widget_service.dart` são só stubs" | Usa `home_widget` real com múltiplos payloads estruturados |
| "Triple Check não tem botões de ação" | Implementado com Reformular, Arquivar, Adiar, Criar subtarefas, etc. |
| "Steering Sheet não persiste" | `updateObject(updatedHabit)` chamado com todos os campos corretos |

---

## RESUMO EXECUTIVO REAL

O app está **substancialmente mais completo** do que as análises anteriores indicavam. A maioria das features críticas existe no código.

### O que genuinamente falta (lista curta e honesta)

1. **PMN com lógica de `referenced_dates`** — o card PMN não aparece ao navegar para datas referenciadas
2. **Badge automático de task parada 7+ dias** — TripleCheckBadge existe mas não é exibido automaticamente
3. **Energy Map** — não existe em nenhum arquivo
4. **Emoji como marcador de mood nos gráficos** — não confirmado no `citrine_chart.dart`
5. **Purga de `_conflicts/` após 30 dias** — `_purgeOldDeletedFiles()` só cobre `_deleted/`
6. **Múltiplos calendários Google**
7. **Parte nativa dos widgets (Kotlin/Swift)** — a parte Flutter existe, a nativa não confirmada

---

## PROGRESSO DE IMPLEMENTAÇÃO (sessão 2026-06-07)

| Item | Status | Arquivo(s) alterado(s) |
|---|---|---|
| Purga de `_conflicts/` após 30 dias | ✅ Feito | `vault_provider.dart` |
| Backup ZIP periódico em `_backups/` | ✅ Feito | `vault_provider.dart` |
| `mood` como inline WikiLink (`mood:: [[slug]]`) | ✅ Feito | `markdown_parser.dart`, `journal_entry.dart` |
| Badge automático task parada 7+ dias (`needsTripleCheckBadge`) | ✅ Feito | `task_model.dart` |
| Parser PMN + `referenced_dates` | ✅ Feito | `journal_entry.dart` |
| `fetchEvents` de múltiplos calendários visíveis | ✅ Feito | `google_calendar_service.dart` |
| Auto-archive de inbox após 30 dias | ✅ Feito | `vault_provider.dart` |
| `unreachable_switch_default` no scheduler_picker | ✅ Feito | `scheduler_picker.dart` |
| `TripleCheckBadge` exibido automaticamente na UI | ✅ Feito | `organizer_tasks_widget.dart`, `planner_screen.dart` |
| `social_refs` renderizados na detail view e com indicador visual | ✅ Feito | `universal_detail_view.dart`, `social_screen.dart`, `social_post_grid_card.dart` |
| Emoji de mood como marcador visual no `citrine_chart.dart` | ✅ Feito | `citrine_chart.dart`, `combined_analysis_screen.dart` |
| `energy_map.dart` — leitura de Field Notes `category: energy` | ✅ Feito | `energy_map.dart`, `dashboard_provider.dart`, `home_screen.dart` |
| Card PMN na timeline por indexação de `referenced_dates` | ✅ Feito | `journal_screen.dart` |
| `AppWidgetProvider.kt` nativo Android | ✅ Feito | Encontrados em `android/app/src/main/kotlin/com/productivity/citrine/` (ex: `CitrineCalendarWidgetProvider.kt`, `CitrineTasksWidgetReceiver.kt`, etc) e declarados no `AndroidManifest.xml` |


# 2026-06-06 22H 20MIN

Citrine — Gap Analysis Completo
> Guidelines V3 × Código implementado (`olalaurao/aplicativo`)  
> Produzido em 06/06/2026 — fonte de verdade: guidelines.md (V3), lista de 166 arquivos Dart, `pendencias_implementacao.md`, `analysis_final_4.txt`, `ajustes.md`, `next_steps.md`, `wip_implementation_status.md`.

---

## Como ler este documento

Cada seção corresponde a uma parte do guidelines. Para cada item o status é classificado em:

- ✅ **Implementado** — arquivo e lógica existem no repositório com evidência clara
- ⚠️ **Parcial** — arquivo existe mas a implementação está incompleta, tem dead code, ou o fluxo não fecha
- ❌ **Ausente** — não existe nenhum arquivo correspondente, ou o guidelines descreve comportamento que não tem nenhuma base no código

---

## Parte 1 — Arquitetura Conceitual

### 1.1 Vault Structure

| Item | Status | Observação |
|---|---|---|
| Pasta padrão `app/` flat | ⚠️ | `VaultNotifier` escreve nessa pasta, mas `pendencias_implementacao.md` sec. 4 admite que o código "mistura `app/`, pastas por tipo, `daily/` e `trackers/records/`". Migração de arquivos legados não foi concluída. |
| `daily/YYYY-MM-DD.md` | ✅ | `MarkdownParser` e `VaultNotifier` geram e lêem daily notes. |
| `daily/YYYY-WNN.md` (PMN) | ⚠️ | Arquivo `journal_entry.dart` existe e tem suporte a `entry_type: pmn`, mas não há evidência de parsing do arquivo PMN próprio separado da daily note. Sem tela ou fluxo de criação dedicado visível. |
| `moods/SLUG.md` lazy | ⚠️ | `mood_model.dart` existe. Criação lazy na primeira vez que o mood é registrado não está verificada no código — não há `create_mood_file` no serviço. |
| `_attachments/`, `_deleted/`, `_conflicts/` | ⚠️ | `_deleted/` e `_conflicts/` referenciados em `sync_provider.dart` e `undo_service.dart`, mas purga automática de 30 dias não verificada. `_attachments/` mencionado sem serviço de gestão dedicado. |
| Object Identification (soberana) | ⚠️ | `type_signatures_screen.dart` existe (renomeado de Object Identification). Configuração de pasta/tag/propriedade por tipo referenciada, mas o parser de startup não demonstra usar essas regras ao indexar — ainda usa tipo no frontmatter como fallback principal. |
| Detecção de conflito de tipo (badge ⚠️) | ❌ | Não há lógica de detecção de conflito de tipo no código. Nenhuma tela "Conflitos" no menu Mais. |

### 1.2 Objetos de Conteúdo e Organizadores

| Item | Status | Observação |
|---|---|---|
| 9 tipos de conteúdo mapeados | ✅ | Todos têm model Dart correspondente. |
| 10 tipos de organizador | ⚠️ | `organizer_model.dart` existe mas `Places` (com coordenadas) e a hierarquia Area > Activity > Project completa não estão verificadas. `Activity` não aparece como tipo distinto em nenhum form. |
| Organizador tem Timeline própria | ⚠️ | `organizer_detail_screen.dart` existe. A timeline agrega dinamicamente conteúdo associado, mas `analysis_final_4.txt` aponta `unused_local_variable` dentro de `vault_provider.dart` (`pendingTasks`, `todayHabits`, `lastEntry`) — sugerindo que a agregação ainda não está totalmente conectada. |

---

## Parte 2 — Objetos de Dados

### Objeto 1: Entry (Journal Entry)

| Item | Status | Observação |
|---|---|---|
| `entry_type: standard` | ✅ | `create_entry_form.dart`, `journal_screen.dart`, `journal_entry.dart` implementados. |
| Rich text editor com bold/italic/heading/checklist/WikiLink | ⚠️ | `rich_text_editor.dart` existe. `next_steps.md` registra bug de renderização do body (`[{"insert":"lorem ipsum/n"}]`), indicando que o QuillDelta ainda não está sendo renderizado corretamente na timeline. `analysis_final_4.txt` aponta `desiredAccuracy` deprecado no form. |
| Fotos inline no body | ⚠️ | `pendencias_implementacao.md` sec. 5 lista "Salvar fotos como `![[arquivo]]` no corpo" como tarefa — indica que só existe thumbnail strip, não inserção inline real. |
| Location GPS real | ⚠️ | `create_entry_form.dart` usa `geolocator` mas a API `desiredAccuracy` está deprecada (`analysis_final_4.txt`). Location manual existe; auto-GPS não verificado como funcional. |
| `entry_type: field_note` (4 categorias, sem rich text) | ⚠️ | Modelo tem `category` e `energy_value`. Não há form dedicado de Field Note rápido — o toggle "Observação rápida" com 3 elementos não está evidente no código. |
| `entry_type: pmn` (arquivo próprio `YYYY-WNN.md`) | ✅ | Tela de criação implementada, parser na `VaultNotifier` adicionado. |
| PMN linkado a datas (`referenced_dates`) | ✅ | Model e parser de date_range e dates adicionados. |
| PMN auto-sugerindo Pact refs ativos | ✅ | Suporte básico adicionado (referências futuras para Pact/Habits). |
| Card PMN distinto na Timeline | ✅ | `PmnCard` adicionado em `timeline_card.dart` e usado nas telas. |
| Templates de Entry com CRUD | ⚠️ | `template_model.dart` e `create_template_form.dart` existem, mas `pendencias_implementacao.md` sec. 5 aponta que "Templates existem como picker, mas precisam CRUD de templates". |
| Organizers salvos como `OrganizerReference(type, slug)` | ⚠️ | `next_steps.md` menciona correção do `OrganizerReference.slug/title`, mas `pendencias_implementacao.md` sec. 5 ainda lista como pendente salvar o tipo do organizer. |

### Objeto 2: Task

| Item | Status | Observação |
|---|---|---|
| Campos core (stage, priority, dates, duration, etc.) | ✅ | `task_model.dart` completo. |
| `until_done`, `date_range`, `all_day` | ✅ | Modelados em `task_model.dart`. |
| Subtasks como Tasks completas com `parent_task` | ⚠️ | Subtasks existem mas `analysis_final_4.txt` aponta `_buildSubtaskItem` e `_buildHabitRow` como `unused_element` — sugerindo que o rendering pode não estar conectado. |
| Subtask sessions (grupos temáticos colapsáveis) | ⚠️ | `next_steps.md` lista como pendente explicitamente. |
| Triple Check (bloco no frontmatter, bottom sheet, 3 perguntas, diagnóstico) | ✅ | `TripleCheck` model adicionado ao `task_model.dart`, `triple_check_sheet.dart` criado com bottom sheet de 3 perguntas, diagnóstico em tempo real, botões de ação por dimensão bloqueada e persistência via `tasksProvider`. |
| Badge Triple Check no card após 7 dias sem progresso | ✅ | `TripleCheckBadge` widget adicionado ao `organizer_tasks_widget.dart` via `task.needsTripleCheckBadge` getter. |
| Triple Check no formulário de PMN (batch) | ❌ | Ausente (PMN nem existe ainda). |
| `depends_on` (array de bloqueadores) | ⚠️ | Modelado, sem UI para gestão de dependências. |
| `linked_system` | ✅ | Modelado em `task_model.dart`. |
| Reflexão ao finalizar | ⚠️ | `pendencias_implementacao.md` sec. 7 lista como pendente "Persistir reflection no markdown quando stage vira finalized". |
| Backlog modal ao salvar sem data | ⚠️ | `ajustes.md` lista backlog como implementado, mas o modal "Onde colocar?" com opção Backlog/Adicionar para hoje não está verificado como comportamento correto. |
| `social_refs` | ⚠️ | `social_post.dart` existe; link de Task → SocialPost não verificado. |
| `estimated_minutes` | ⚠️ | Modelado, sem UI dedicada de estimativa. |
| Scheduler por Task | ✅ | `scheduler.dart` e `scheduler_picker.dart` implementados. |
| Timer/Pomodoro vinculado a Task | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Vincular pomodoro a Task/Habit/Goal/Project e atualizar KPI time_spent" como pendente. |

### Objeto 3: Goal

| Item | Status | Observação |
|---|---|---|
| `goal_mode: standard` | ✅ | `goal_model.dart`, `create_goal_form.dart`, `goals_screen.dart` implementados. |
| `goal_mode: plan` (Objective, Strategy, Phases) | ⚠️ | Modelado com `objective`, `strategy`, `phases`. Sem seções distintas verificadas na detail view. `analysis_final_4.txt` tem null checks desnecessários em `goals_screen.dart` — sugerindo lógica incompleta. |
| KPIs com auto-complete de Goal | ⚠️ | `kpi_model.dart` e `kpi_engine.dart` existem. `pendencias_implementacao.md` sec. 14 lista "Implementar auto-complete de KPI" como pendente. |
| Goal como Organizador com Timeline | ⚠️ | Parcialmente via `organizer_detail_screen.dart`. |

### Objeto 4: Habit

| Item | Status | Observação |
|---|---|---|
| `habit_mode: habit` core | ✅ | `habit_model.dart`, `create_habit_form.dart`, `habits_screen.dart` implementados. |
| `habit_mode: pact` | ✅ | `habit_mode: pact` modelado e persistido corretamente. O bug de tipagem no parsing foi corrigido. |
| Steering Sheet (3 etapas: Revisão, Reflexão, Decisão) | ✅ | Componente `steering_sheet.dart` criado com fluxo completo de 3 etapas e persistência de dados. |
| Check automático de `ends_at` no startup | ✅ | Implementado checker de pactos expirados no startup em `main.dart` com disparador de notificações. |
| `previous_cycles` | ✅ | Salvo e atualizado no Markdown após cada ciclo finalizado via Steering Sheet. |
| `pact_outcome` | ✅ | Atualizado conforme a decisão (persist, pause, pivot) do usuário e persistido. |
| Slots com horário, reminder e Action independentes | ⚠️ | Slots existem no modelo. Reminders por slot existem. Actions por slot: ver seção de Actions abaixo. |
| "Days since" badge | ⚠️ | `habit_row.dart` tem UI de badge, mas lógica de atualização à meia-noite não verificada. |
| Streak e "days since" complementares | ⚠️ | Streak calculado, "days since" sem verificação de atualização automática. |
| Swipe right para completar habit | ⚠️ | Mencionado em gestos mas não verificado em `habit_row.dart`. |
| `isNegative` (habit de evitação) | ⚠️ | Modelado, sem rendering especial verificado. |
| `inputType: mood` | ⚠️ | Modelado, sem picker de mood integrado ao slot de habit. |
| `linkedTrackerSlug` | ⚠️ | Modelado, sem lógica de abertura do record form no momento de completion. |
| Dashboard `pact_today` panel | ❌ | Guidelines menciona panel "pact_today" com check-in diário. Não encontrado em `dashboard_panel.dart`. |

### Objeto 5: Tracker + Tracking Record

| Item | Status | Observação |
|---|---|---|
| Tracker definition com sections/fields | ✅ | `tracker_model.dart`, `create_tracker_form.dart`, `trackers_screen.dart` implementados. |
| 6 tipos de InputField | ⚠️ | `create_record_form.dart` tem switch com `unreachable_switch_default` (`analysis_final_4.txt`) — indica que nem todos os 6 tipos estão cobertos. |
| Tracking Record embebido na daily note | ⚠️ | `pendencias_implementacao.md` sec. 4 aponta que "Tracking records devem seguir uma regra clara: ou ficam em daily notes ou como arquivos próprios, mas não os dois sem sincronização" — problema em aberto. |
| Charts (line, bar, pie, calendar) por Tracker | ⚠️ | `citrine_chart.dart` e `tracker_metric_card.dart` existem. `pendencias_implementacao.md` sec. 12 lista "Statistics view deve permitir criar/remover summaries e charts persistidos no tracker" como pendente. |
| Summaries configuráveis | ⚠️ | Modelados, sem CRUD verificado. |
| InputField com `organizers` auto-adicionados ao Record | ❌ | Não há lógica de auto-adicionar organizers do campo ao record quando preenchido. |
| `media` field com save de arquivo | ⚠️ | `pendencias_implementacao.md` sec. 12 lista "Media field deve salvar arquivo e valor estruturado" como pendente. |
| History por campo (últimos valores) | ⚠️ | Mencionado em pendências sec. 12 como "History icon por campo deve abrir últimos valores reais" — pendente. |

### Objeto 6: Note

| Item | Status | Observação |
|---|---|---|
| Text Note com rich text | ✅ | `create_note_form.dart`, `note_model.dart` implementados. |
| `_bodyController` unused | ⚠️ | `analysis_final_4.txt` aponta `_bodyController` como `unused_field` em `create_note_form.dart` — campo do editor não conectado. |
| Outline Note (árvore, drag, focus mode, mirroring) | ⚠️ | `outline_editor.dart` e `outline_editor.dart` (widget) existem. Focus mode e mirroring não verificados. |
| Collection Note (schema + items + views list/gallery/table) | ⚠️ | `collection_editor.dart` e `collection_view.dart` existem. `pendencias_implementacao.md` sec. 6 lista "trocar contagem por split de texto por JSON/YAML estruturado, com schema e itens reais" como pendente — indica que Collection Note não está funcionando como banco de dados ainda. |
| Notes NÃO aparecem na Timeline principal | ⚠️ | Não verificado — Timeline pode estar mostrando Notes incorretamente. |
| `parent_note` e links bidirecionais | ⚠️ | Modelados, sem gestão de backlinks automática verificada. |
| WikiLink `[[]]` com picker flutuante inline | ⚠️ | `wiki_link_controller.dart` e `wiki_link_picker.dart` existem. Resolução de aliases de mood não verificada. |
| Filtros, reordenação e campos personalizados em listas de Notes | ⚠️ | `ajustes.md` lista como pendente explicitamente (item 6 e 7). |

### Objeto 7: Calendar Session

| Item | Status | Observação |
|---|---|---|
| Criação e visualização | ✅ | `create_session_form.dart`, `planner_screen.dart` implementados. |
| `_timeSlot` unused field | ⚠️ | `analysis_final_4.txt` aponta `_timeSlot` como `unused_field` em `create_session_form.dart`. |
| Chips Objectives, Time spent, Reminder | ⚠️ | `pendencias_implementacao.md` sec. 8 lista os 3 como pendentes. |
| Move modal com persistência completa | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `ajustes.md` registra "no planner visualizacao day, tava dando erro quando tento mudar a duração" — indica que persistência de duração falha. |
| Redimensionar duração arrastando no Day View | ❌ | `ajustes.md` lista como pendente. |
| Timer/Pomodoro inline na sessão | ⚠️ | `pendencias_implementacao.md` sec. 8, `time_block_picker.dart` existe mas integração não verificada. |
| `exported_calendar_id` e link com Google Calendar | ⚠️ | `google_calendar_service.dart` existe. `next_steps.md` lista export como implementado, mas integração bidirecional (importar evento como sessão) está pendente. |
| Backlog de sessões | ⚠️ | Modelado, sem UI verificada. |
| `linked_google_event_*` | ⚠️ | Modelados; persistência de link verificada parcialmente. |

### Objeto 8: Reminder

| Item | Status | Observação |
|---|---|---|
| Model e form básico | ✅ | `reminder_model.dart`, `create_reminder_form.dart`, `reminders_screen.dart` implementados. |
| 3 tipos (push, popup, alarm) | ⚠️ | `notification_service.dart` existe. `ajustes.md` registra "alarme nao funciona ainda" — tipo `alarm` não funcional. |
| Botões de ação (Marcar como feito, Soneca, Dispensar) | ⚠️ | `pendencias_implementacao.md` sec. 9 lista os 3 como pendentes de implementação real — actions só imprimem log. |
| Soneca com duração configurável na hora da notificação | ❌ | Ausente. |
| Confiabilidade via alarm manager nativo | ⚠️ | `notification_service.dart` existe; permissões verificadas em `permission_service.dart`. `ajustes.md` confirma que notificações/alarmes não funcionam no Android. |
| Organizer chip, scheduler e time block no form | ⚠️ | `pendencias_implementacao.md` sec. 9 lista como pendente. |
| Opção soneca/burnout (ignorar alarmes de hábitos até X dia) | ❌ | `ajustes.md` lista como pendente explicitamente. |

### Objeto 9: System

| Item | Status | Observação |
|---|---|---|
| Model | ✅ | Presumido presente via `create_note_form.dart` com aba System e `command_center_overlay.dart`. Porém não há `system_model.dart` explícito na lista de arquivos — o System pode estar embutido em `note_model.dart`. |
| Formulário de criação (título, trigger, steps, substeps, tempo estimado) | ⚠️ | Não há `create_system_form.dart` na lista de arquivos. A criação de System pode estar dentro de `create_note_form.dart` de forma rudimentar. |
| "Estruturar com IA" (botão de AI para montar steps) | ❌ | Ausente. |
| Detail view com stats (run_count, last_run, average_minutes, histórico) | ❌ | Sem `system_detail_screen.dart`. Stats derivadas de Tasks com `linked_system` não calculadas. |
| Botão "▶ Executar" — Via A (cria Task com subtasks dos steps) | ❌ | Ausente. |
| Via B — "Aplicar System" de qualquer Task | ❌ | Ausente. |
| Via C — Quick-run efêmero (checklist sem criar Task) | ❌ | Ausente. |
| "Salvar como System" a partir de Task (menu ⋯) | ❌ | Ausente. |
| `run_count`, `last_run`, `average_minutes` derivados | ❌ | Ausente. |
| Dashboard panel `system_quick_run` | ❌ | Não encontrado em `dashboard_panel.dart`. |
| Systems como chips no Command Center | ⚠️ | `command_center_overlay.dart` existe. Seção "Systems" como quick-run não verificada. |
| Swipe right em System → quick-run | ❌ | Ausente. |

**⚠️ Sistema (Objeto 9) é a feature com maior gap do projeto — quase todo o comportamento está ausente.**

### Objeto 10: Social Post

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `social_post.dart`, `create_social_post_form.dart`, `social_screen.dart`, `social_post_detail.dart` implementados. |
| Bulk import | ✅ | `social_bulk_import_screen.dart` existe. |
| Embed view (oEmbed) | ✅ | `social_embed_view.dart`, `oembed_service.dart` implementados. |
| Linkagem com Tasks (`linked_tasks`) | ⚠️ | Modelado; UI de linkagem unificada com busca por tipo não verificada. |
| `linked_content` (qualquer objeto do vault) | ⚠️ | Modelado sem UI verificada. |

---

## Parte 3 — Objetos de Suporte

### Scheduler

| Item | Status | Observação |
|---|---|---|
| 11 tipos de regra | ⚠️ | `scheduler.dart` e `scheduler_picker.dart` existem. `analysis_final_4.txt` aponta múltiplos `unreachable_switch_default` e `unused_local_variable 'isSelected'` no `scheduler_picker.dart` — indica que nem todos os tipos estão cobertos. `pendencias_implementacao.md` sec. 8 lista "Scheduler deve usar `days_of_theme` e `days_with_block`" como pendente. |
| Regras de exclusão | ⚠️ | Modeladas, sem UI específica verificada. |
| Política de atraso (skip/keep/prompt) | ⚠️ | Modelada, sem UI de escolha verificada. |
| Múltiplas regras por scheduler (OR lógico) | ⚠️ | Modelado, sem UI para adicionar múltiplas regras. |
| Página global de Scheduler (Settings → Scheduler) | ✅ | `scheduler_management_screen.dart` e `scheduler_page.dart` existem. |

### Day Theme e Time Block

| Item | Status | Observação |
|---|---|---|
| CRUD de Day Theme | ✅ | `day_theme_screen.dart`, `day_theme_model.dart`, `day_theme_provider.dart` existem. |
| CRUD de Time Blocks (nome, cor, hora inicial/final) | ⚠️ | `time_block_picker.dart` existe mas `pendencias_implementacao.md` sec. 18 lista "CRUD de Time Blocks com nome, cor, hora inicial/final" como pendente. |
| `energy_level` por bloco | ⚠️ | Modelado. Toggle "Camada de energia" no Planner não verificado. |
| Tints de energia no Planner (8% opacity) | ❌ | Não verificado como implementado. |
| Auto-geração de Energy Map a partir de Field Notes (14+ dias) | ❌ | Ausente — depende também de Field Notes funcionais. |
| Planner agrupa sessões/habits por Time Block | ⚠️ | `ajustes.md` lista "day times pros habits - ficar ao longo do dia no horário do slot reminder" como pendente. |

### KPI

| Item | Status | Observação |
|---|---|---|
| `kpi_model.dart` e `kpi_engine.dart` | ✅ | Existem. |
| Fontes: subtasks, tracker_field, habit, collection, entry, time_spent, manual_quantity | ⚠️ | `kpi_engine.dart` existe mas `pendencias_implementacao.md` sec. 14 lista problemas em fontes específicas (`entryCount` inconsistente, `collection` sem parse estruturado). |
| Auto-complete de KPI | ❌ | `pendencias_implementacao.md` sec. 14 lista como pendente. |
| Input inline de `manual_quantity` com botão "+N" | ⚠️ | Sem UI específica verificada. |

### Snapshot

| Item | Status | Observação |
|---|---|---|
| Model e form | ✅ | `snapshot_model.dart`, `create_snapshot_form.dart` existem. |
| Aparece na Timeline como entrada | ⚠️ | Sem verificação de que `timeline_card.dart` tem variante Snapshot. |
| Update de Snapshot | ⚠️ | `pendencias_implementacao.md` sec. 3 lista "Garantir update para Snapshot" como pendente. |

### Mood Definition

| Item | Status | Observação |
|---|---|---|
| Model com todos os campos | ✅ | `mood_model.dart` implementado. |
| 48 moods do sistema pré-carregados (12 por quadrante) | ⚠️ | Tabela do guidelines tem 48 moods. Não verificado se todos os 48 estão hardcoded no código. |
| Picker de humor em 2 passos (grade 2×2 → lista por quadrante) | ⚠️ | `mood_chart_widget.dart` existe. O picker de 2 passos (grade interativa + lista de moods do quadrante selecionado) não tem arquivo dedicado — provavelmente está inline em algum form. |
| Campo de busca no picker (label, label_en, aliases) | ⚠️ | Sem verificação de busca por `aliases` no picker. |
| "Adicionar minha própria emoção" → form de mood user | ⚠️ | `mood_settings_screen.dart` existe para gerenciar moods. Criação inline no picker não verificada. |
| Moods system: apenas `hidden` e `aliases` editáveis | ⚠️ | Lógica de restrição não verificada. |
| Moods system: arquivo criado lazily na 1ª vez | ⚠️ | Lógica lazy não verificada no código. |
| `aliases` como campo nativo de aliases do Obsidian | ⚠️ | Sem verificação de escrita no frontmatter como array `aliases:`. |
| Emoji como marcador nos gráficos de linha | ⚠️ | `mood_chart_widget.dart` e `citrine_chart.dart` existem. Emoji como marcador de ponto visual não verificado. |
| Emoji no calendário de Combined Analysis | ⚠️ | `analysis_calendar.dart` existe. Emoji no centro do dia não verificado. |
| 4 campos separados na daily note (`mood_pleasantness`, `mood_energy`, `mood_label`, `mood_emoji`) | ⚠️ | Formato canônico definido no guidelines; escrita dos 4 campos separados não verificada no `MarkdownParser`. |

---

## Parte 4 — Telas e Navegação

### Bottom Navigation Bar

| Item | Status | Observação |
|---|---|---|
| 5 slots padrão com Dashboard fixo e Mais fixo | ✅ | `app_shell.dart` implementado. |
| Slots 2–4 customizáveis (adicionar, remover, reordenar) | ✅ | `navigation_shortcut_picker.dart` e `navigation_provider.dart` existem. `ajustes.md` lista como implementado. |
| Máximo de 7 slots | ⚠️ | Sem verificação de enforcement do limite. |
| Atalhos para nota específica, filtro de área, tarefa específica | ⚠️ | `ajustes.md` lista "quero poder colocar atalhos pra qualquer página" como pendente no contexto de customização avançada. |

### FAB Global "Criar"

| Item | Status | Observação |
|---|---|---|
| Bottom sheet com abas Journal/Plan/Record/Note | ✅ | `create_menu_sheet.dart` implementado. |
| Aba Journal → Entry / Field Note / PMN | ⚠️ | Entry existe. Field Note e PMN como opções distintas não verificadas. |
| Aba Note → System | ⚠️ | System não tem form dedicado. |
| Snapshot, Voice Note, Scan Document funcionais | ⚠️ | `pendencias_implementacao.md` sec. 1 lista os 3 como pendentes de implementação real. |

### Command Center (scroll-up)

| Item | Status | Observação |
|---|---|---|
| Overlay com busca, Recentes, Notas, Próximas Sessões | ✅ | `command_center_overlay.dart` implementado. |
| Seção "Systems" com 3 Systems como chips de quick-run | ❌ | Não implementado (System não existe de forma completa). |
| Ações rápidas: "Novo System" | ❌ | Ausente. |

---

## Parte 5 — Padrões de Interação

| Item | Status | Observação |
|---|---|---|
| Gestos: tap, long press, swipe left, swipe right, drag, scroll-up | ⚠️ | Maioria implementada. Swipe right em System → quick-run: ausente. Swipe right em Habit/Pact para completar: não verificado. |
| Undo em Delete/Archive (snackbar 5s, `_deleted/`) | ✅ | `undo_service.dart` implementado. `wip_implementation_status.md` lista como concluído. |
| Drag-and-drop no Planner com persistência | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `pendencias_implementacao.md` sec. 11 lista "Todo drag/drop deve persistir no objeto e reescrever markdown" como pendente — contradição. |
| Organizer Detail View com 4 seções dinâmicas | ⚠️ | `organizer_detail_screen.dart` existe. `analysis_final_4.txt` aponta variáveis locais não usadas no `vault_provider.dart` que alimentam essas seções. |

---

## Parte 6 — Sistema de Actions (Habits e Trackers)

| Item | Status | Observação |
|---|---|---|
| `automation_service.dart` | ✅ | Existe. |
| 7 tipos de Action | ⚠️ | `analysis_final_4.txt` aponta `unused_local_variable 'changed'` em `automation_service.dart` — automação existe mas a variável de resultado não é usada, sugerindo que as actions não são disparadas de fato. |
| Trigger: completar slot individual | ❌ | Não verificado como disparado. |
| Trigger: atingir daily goal | ❌ | Não verificado como disparado. |
| Trigger: salvar tracking record | ❌ | Não verificado como disparado. |
| Configuração de Action por slot (independente do reminder) | ❌ | UI de configuração de Action por slot não encontrada. |

**⚠️ Actions é outra feature com gap significativo — o serviço existe mas as actions não são efetivamente disparadas.**

---

## Parte 7 — Pomodoro

| Item | Status | Observação |
|---|---|---|
| Timer funcional (work/short break/long break) | ✅ | `pomodoro_screen.dart`, `pomodoro_provider.dart`, `pomodoro_bg_service.dart` implementados. |
| UI full-screen com countdown circular, controles, indicador de blocos | ✅ | `pomodoro_screen.dart` implementado. |
| Notificação persistente com Pausar/Retomar/Parar | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Foreground notification precisa ter ações Pause/Resume/Stop conectadas ao provider" como pendente. |
| PomodoroSession persistida na daily note (`## Pomodoros`) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "escrever `## Pomodoros` no daily note" como pendente. |
| Vincular Pomodoro a Task/Habit/Goal/Project | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pendingTasks` e `todayHabits` unused no vault_provider | ⚠️ | `analysis_final_4.txt` — sugere que integração Pomodoro → KPI time_spent não está conectada. |
| Pomodoro Agendado (cria CalendarSession ou Reminder) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Botão 'Agendar Pomodoro' deve criar CalendarSession ou Reminder, não apenas snackbar" como pendente. |
| Histórico de sessões do vault (não só memória) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pomodoro_floating_clock.dart` e `pomodoro_week_overview.dart` | ✅ | Existem. |

---

## Parte 8 — People

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `people_model.dart`, `create_person_form.dart`, `people_screen.dart` implementados. |
| `last_contact_date` derivado de backlinks reais | ⚠️ | `pendencias_implementacao.md` sec. 15 lista "Calcular `last_contact_date` por backlinks reais, journal entries e eventos" como pendente. Variável `frequencyDays` apontada como unused no `people_screen.dart` (`analysis_final_4.txt`). |
| Scheduler automático → Task "Contatar [nome]" | ⚠️ | `automation_service.dart` tem `checkPersonContacts` mas com `unused_local_variable 'changed'` — não conectado. |
| Ao concluir a task automática → atualiza `last_contact_date` | ❌ | Ausente (depende de task completion callback). |
| Histórico de contatos e menções navegáveis | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. |
| Editar `contact_frequency` inline | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. Unused `frequencyDays` confirma. |

---

## Parte 9 — Resources

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `resource_model.dart`, `create_resource_form.dart`, `resources_screen.dart` implementados. |
| Dead code em `create_resource_form.dart` | ⚠️ | `analysis_final_4.txt` aponta `dead_code` e `dead_null_aware_expression` — lógica quebrada no form. |
| Settings → Resources: regras de filtro configuráveis | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Cover image via WikiLink embed | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Rating persistido imediatamente | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. Status duplicado no modelo apontado. |
| Lazy loading do grid | ⚠️ | `ajustes.md` lista "grid de resources deve ser lazy loading" como pendente. |

---

## Parte 10 — Projects

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `project_model.dart`, `create_project_form.dart` implementados. |
| `primary_kpi` como drive do % de progresso | ⚠️ | `kpi_engine.dart` existe mas integração com Projects não verificada. |
| `quick_access` (links rápidos) | ⚠️ | Modelado, sem UI de adição de links verificada. |
| `total_pomodoro_time` derivado | ❌ | Depende de Pomodoro → Task linkado, que está pendente. |
| Project detail com todas as seções | ⚠️ | `pendencias_implementacao.md` sec. 14 lista "Project detail deve expor edição inline de state, priority, due date, KPIs e tarefas vinculadas" como pendente. |
| Scheduler recorrente de projeto (reinicia no schedule) | ⚠️ | Modelado, sem fluxo de reinicialização verificado. |

---

## Parte 11 — Combined Analysis

| Item | Status | Observação |
|---|---|---|
| Tela existe | ✅ | `combined_analysis_screen.dart` implementado. |
| CRUD de objeto CombinedAnalysis persistente | ⚠️ | `pendencias_implementacao.md` sec. 13 lista "Criar CRUD de CombinedAnalysis com title, description, data_sources, chart configs" como pendente — análises são temporárias em estado local. |
| `analysis_model.dart` | ✅ | Existe (com deprecated `.value` apontado em `analysis_final_4.txt`). |
| Picker de fontes com cor/label/field/source type | ⚠️ | Pendente (sec. 13). |
| `normalization: dual_axis / normalize_0_1` | ❌ | Sem evidência de normalização de eixo duplo implementada. |
| `value_mapping` para campos categóricos | ❌ | Sem evidência de mapeamento categórico → numérico. |
| Emoji como marcador em gráficos de linha | ❌ | `analysis_final_4.txt` aponta `unused_local_variable 'firstDay'` em `combined_analysis_screen.dart` — lógica de calendário incompleta. |
| Calendário mensal com emoji de mood + dots coloridos | ⚠️ | `analysis_calendar.dart` existe mas sem emoji de mood verificado. |
| Mood como fonte com dimensão pleasantness/energy | ⚠️ | Pendente (sec. 13). |

---

## Parte 12 — Sync, Offline e Conflitos

| Item | Status | Observação |
|---|---|---|
| Sync com Google Drive (offline-first) | ✅ | `google_drive_sync_service.dart`, `sync_provider.dart`, `sync_queue_service.dart`, `sync_manager.dart` implementados. |
| `fetchRemoteFiles` recursivo | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "hoje busca só filhos diretos da pasta raiz" como pendente. |
| Hash por arquivo para detecção correta de conflito | ⚠️ | Pendente (sec. 19). |
| UI de conflito com comparação campo a campo | ✅ | `conflict_resolution_dialog.dart`, `sync_conflict_dialog.dart`, `sync_conflicts_screen.dart` existem. `wip_implementation_status.md` lista como concluído. |
| Fila offline visível ao usuário | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "Mostrar fila offline e erros de sync ao usuário" como pendente. |
| Indicador de status (synced/syncing/offline/error) | ⚠️ | `sync_provider.dart` tem estados; UI de indicador não verificada. |
| Backup ZIP periódico (diário/semanal/por abertura) | ✅ | `backup_service.dart` existe. Configuração de retenção não verificada. |
| Purga automática de `_deleted/` em 30 dias | ❌ | Sem serviço de purga verificado. |

---

## Parte 13 — Notificações

| Item | Status | Observação |
|---|---|---|
| `notification_service.dart` | ✅ | Existe. |
| 3 tipos: push, popup, alarm | ✅ | Push e popup funcionam; Alarm foi ajustado e verificado para rodar e permitir ações reais. |
| Botões de ação reais (não apenas log) | ✅ | Implementado em `vault_provider.dart` (`_markNotificationTargetDone`, `_snoozeNotification`, `_recordNotificationDismissal`) e nas telas `AlarmScreen` e `PopupScreen`. Suporte a Task, Habit e Reminder. |
| Confiabilidade via alarm manager do sistema | ⚠️ | `permission_service.dart` existe; `ajustes.md` confirma falhas. |
| Notificação persistente de Captura Rápida (lockscreen) | ⚠️ | `next_steps.md` lista como implementado com ressalva (botões físicos não suportados pelo OS). |
| Popup sobre lockscreen | ✅ | `popup_notification_screen.dart` implementado com ações reais e fallback corrigido. |

---

## Parte 14 — Archive Universal

| Item | Status | Observação |
|---|---|---|
| `archived: true` no frontmatter | ✅ | Todos os modelos têm `archived`. |
| Página Archive com lista, filtro por tipo, busca, Restaurar | ✅ | `archive_screen.dart` existe. `wip_implementation_status.md` lista como concluído. |
| Banner "Arquivado" na detail view em read-only | ⚠️ | Não verificado em `universal_detail_view.dart`. |
| "Ver arquivados" por seção via menu ⋯ | ⚠️ | Sem evidência de implementação por seção. |

---

## Parte 15 — Widgets (Home Screen / Lock Screen)

| Item | Status | Observação |
|---|---|---|
| `widget_service.dart` e `widget_sync_provider.dart` | ✅ | Existem. |
| Quick-add widget (2×1) | ⚠️ | `pendencias_implementacao.md` sec. 20 lista "Quick-add widget: botões Journal Entry e Add Task com deep links" como pendente. |
| Calendar widget com dots | ⚠️ | Pendente (sec. 20). |
| Category widget configurável | ⚠️ | Pendente (sec. 20). |
| Obsidian Note widget (renderiza nota específica) | ⚠️ | Pendente (sec. 20). |
| Widget configuration sheet real | ✅ | `widget_config_sheet.dart` existe. |
| Deep links e atualização em background no Android/iOS | ⚠️ | Pendente (sec. 20). |

---

## Parte 16 — Linking Universal

| Item | Status | Observação |
|---|---|---|
| `links` no frontmatter | ✅ | Todos os modelos têm `links`. |
| Inline WikiLink `[[]]` com picker flutuante | ✅ | `wiki_link_controller.dart`, `wiki_link_picker.dart`, `wiki_text_view.dart` implementados. |
| Filtragem fuzzy por título e aliases no picker | ⚠️ | Aliases de mood não verificados como indexados. |
| Menções/Backlinks em todas as detail views | ⚠️ | `universal_detail_view.dart` existe mas `analysis_final_4.txt` aponta `_statBox`, `actions` e `_buildSubtaskItem` como `unused_element` — partes da detail view não conectadas. |
| Busca indexa body de markdown, frontmatter, tags, backlinks | ⚠️ | `search_service.dart` existe. `pendencias_implementacao.md` sec. 17 lista "Search deve indexar todos os corpos de markdown" como pendente — indica indexação incompleta. |

---

## Parte 17 — Navigation History

| Item | Status | Observação |
|---|---|---|
| `history_provider.dart` | ✅ | Existe. |
| Back button em toda tela não-root | ⚠️ | `ajustes.md` lista "Botão de voltar deve sempre voltar para a página anterior, não para o pai (corrigir go_router)" como pendente. |
| Breadcrumb trail quando stack > 2 níveis | ❌ | Sem `breadcrumb.dart` ou equivalente na lista de arquivos. |
| Restaurar posição de scroll e estado de form ao voltar | ❌ | Não implementado. |

---

## Parte 18 — Design Visual

| Item | Status | Observação |
|---|---|---|
| Cores por tipo de objeto | ⚠️ | `theme.dart` existe. Cores por subtipo (field_note por categoria, PMN por seção, System laranja) não verificadas. |
| "Days since" badge em Habits | ⚠️ | `habit_row.dart` tem badge, mas pill vermelha `#E53935` após 1+ dia e atualização à meia-noite não verificadas. |
| Badge "PACT" (pill branca, fundo = cor do habit) | ⚠️ | `habit_row.dart` tem badge PACT, styling exato não verificado. |
| Color picker visual (nunca HEX direto) | ⚠️ | `ajustes.md` e guidelines explicitam isso. Não verificado em todos os forms. |
| Energy level tints no Planner (8% opacity) | ❌ | Não verificado. |
| Dark mode completo sem textos ilegíveis | ⚠️ | `ajustes.md` e `next_steps.md` listam dark mode como corrigido, mas com ressalvas. `analysis_final_4.txt` tem múltiplos `withOpacity` deprecated que afetam cores. |

---

## Parte 19 — UI Fundamentals

| Item | Status | Observação |
|---|---|---|
| Safe Areas (iOS notch, Android status bar) | ⚠️ | `app_shell.dart` usa SafeArea. Consistência em todos os modais não verificada. |
| Back button (‹) em telas pushed, X em modais | ⚠️ | `ajustes.md` lista correção do back button como pendente. |
| Botão Done/Save (pill arredondada, roxo escuro) | ⚠️ | Não verificado como padrão consistente. |
| Keyboard avoidance (CTA sobe com teclado) | ⚠️ | Não verificado em todos os forms. |
| Handle pill em bottom sheets (36×4pt) | ⚠️ | Não verificado como padrão. |
| Stacking de modais com escala do anterior | ⚠️ | Não verificado. |
| Altura de row (48–52pt), padding horizontal (16pt) | ⚠️ | Não verificado como padrão consistente. |
| Haptic feedback (light/medium/warning por tipo de ação) | ⚠️ | Não verificado. |
| Empty states com ilustração, headline e CTA real | ⚠️ | `empty_state.dart` existe. `pendencias_implementacao.md` sec. 21 lista "Adicionar empty states com CTA real em todas as telas" como pendente. |
| Loading: offline-first (instantâneo) + sync indicator | ⚠️ | Arquitetura offline-first existe; feedback visual de sync não verificado em todos os lugares. |
| Delete sempre com confirmation alert nomeando o item | ⚠️ | Não verificado como padrão consistente. |
| Título duplicado/não-fixo no topo | ⚠️ | `ajustes.md` lista "tira o título duplicado que não tá fixo" como pendente. |

---

## Parte 20 — Vault Obsidian: Esquema Completo

| Item | Status | Observação |
|---|---|---|
| `markdown_parser.dart` e `obsidian_service.dart` | ✅ | Existem. |
| Algoritmo de parsing no startup (8 etapas) | ⚠️ | `vault_provider.dart` existe (1250+ linhas). Múltiplos warnings de variáveis não usadas no startup (`analysis_final_4.txt`). Object Identification não soberana no startup. |
| Parse de daily note: habits, trackers, mood 4 campos, entries | ⚠️ | Parcialmente implementado. Mood como 4 campos separados no frontmatter não verificado. Field Notes no formato `### HH:MM` não verificado. |
| Parse de PMN (`daily/YYYY-WNN.md`) | ❌ | Ausente. |
| Criação lazy de arquivo de mood | ⚠️ | Ausente ou não verificado. |
| Derivação de `run_count`, `last_run`, `average_minutes` do System | ❌ | System não implementado. |
| Derivação do Energy Map de Field Notes | ❌ | Ausente. |
| Lookup de PMN por data | ❌ | Ausente. |
| Testes de ida-e-volta objeto → markdown → objeto | ⚠️ | `pendencias_implementacao.md` sec. 4 e sec. 22 listam como pendentes. |
| `dataview_generator.dart` | ✅ | Existe. |
| Queries Dataview de exemplo | ✅ | `dataview_generator.dart`. |

---

## Parte 21 — Object Identification

| Item | Status | Observação |
|---|---|---|
| Tela Settings → Object Identification | ✅ | `type_signatures_screen.dart` existe. |
| 3 tipos de marcador (Folder, Tag, Property) | ⚠️ | UI existe mas parser de startup não usa as regras definidas como soberano. |
| Badge ⚠️ em conflito de tipo | ❌ | Ausente. |
| Página "Conflitos" no menu Mais | ❌ | Ausente. |
| Editar tipo de qualquer objeto (tornar Area em Task, etc.) | ⚠️ | `ajustes.md` lista como implementado. |
| Compatibilidade com Tasks Plugin do Obsidian (`- [ ] [due:: ...] [priority:: ...]`) | ⚠️ | `markdown_parser.dart` existe mas compatibilidade com sintaxe do Tasks Plugin não verificada. |

---

## Parte 22 — Notas de Implementação (regras críticas)

| Regra | Status | Observação |
|---|---|---|
| Sempre ler `habit_mode` antes de renderizar | ⚠️ | Bug de runtime `type map dynamic is not a subtype of list dynamic` confirma que o parsing não é robusto. |
| Sempre ler `entry_type` antes de renderizar | ⚠️ | Field Note e PMN não têm rendering diferenciado verificado. |
| Sempre ler `goal_mode` antes de renderizar | ⚠️ | Null checks desnecessários em `goals_screen.dart` confirmam lógica frágil. |
| Nunca exibir campo `id` ao usuário | ⚠️ | Não verificado como regra aplicada. |
| Color picker visual obrigatório (nunca HEX direto) | ⚠️ | Não verificado em todos os forms. |
| PMN em arquivo próprio, indexado por `referenced_dates` | ❌ | Não implementado. |
| Mood como WikiLink nas entries + 4 campos na daily note | ⚠️ | WikiLink existe; 4 campos na daily não verificados. |
| Moods system criados lazily | ⚠️ | Não verificado. |
| Object Identification soberana no parser de startup | ❌ | Não implementado como soberano. |
| Actions são obrigatórias (7 tipos) | ❌ | Actions não são disparadas. |
| Triple Check não cria arquivo — bloco no frontmatter da Task | ✅ | Implementado: `TripleCheck.toMap()` serializa inline no frontmatter, nunca cria arquivo separado. |
| `run_count`/`last_run`/`average_minutes` sempre derivados | ❌ | System não implementado. |
| Steering Sheet em 3 etapas ao expirar Pact | ❌ | Não implementado. |
| PMN e Triple Check com batch no formulário de PMN | ❌ | PMN não implementado; Triple Check sem UI. |
| `value_mapping` apenas para campos categóricos | ❌ | Não implementado em Combined Analysis. |

---

## Resumo Executivo por Prioridade

### 🔴 Crítico — Ausente ou quebrado em runtime

1. ✅ **PMN completo** — implementado, com tela de criação, card na Timeline, e integração com o VaultNotifier.
2. ✅ **System (Objeto 9)** — implementado: `system_model.dart`, `systems_provider.dart`, `create_system_form.dart`, `system_detail_screen.dart` criados; Vias A (criar Task), B (aplicar steps a Task existente) e C (quick-run efêmero com stats) implementadas; painel `systemQuickRun` adicionado ao dashboard.
3. ✅ **Steering Sheet** — fluxo de revisão de Pact ao término com SteeringSheet de 3 etapas (Revisão, Reflexão, Decisão) e check automático de expiração no startup com notificações locais implementado.
4. ✅ **Triple Check** — UI de bottom sheet com 3 perguntas (Head/Heart/Hand), diagnóstico em tempo real por dimensão bloqueada, botões de ação contextuais (Reformular/Arquivar, Criar subtasks/Adiar, Adicionar dependência), badge ⚠️ após 7 dias sem progresso e persistência no frontmatter da Task implementados.
5. **Notificações — actions reais** — mark done, snooze e dismiss ainda apenas imprimem log; alarm type não funcional.
6. **Actions de Habit/Tracker** — `automation_service.dart` existe mas nenhuma action é efetivamente disparada em nenhum trigger.
7. **Object Identification soberana no startup** — parser não respeita as regras configuradas pelo usuário.
8. **Bug crítico de runtime em Habits** — `type map dynamic is not a subtype of list dynamic` impede a tela de carregar.

### 🟡 Importante — Parcial ou com lógica quebrada

9. **Pomodoro** — timer funciona; persistência na daily note, linkagem com Tasks/Goals, KPI `time_spent` e foreground notification actions pendentes.
10. **Combined Analysis** — tela existe mas análises são temporárias; sem `dual_axis`, sem `value_mapping`, sem emoji de mood nos gráficos.
11. **Field Notes** — modelo existe; form dedicado rápido e rendering diferenciado na Timeline ausentes.
12. **Rich text body na Timeline** — body renderiza como JSON Delta cru em vez de texto formatado.
13. **People CRM automático** — `last_contact_date` derivado de memória, não de backlinks; task automática não cria/atualiza corretamente.
14. **Planner Day View** — redimensionamento de tarefas por drag ausente; duração curta não mostra nome; habits não posicionados por horário de slot.
15. **KPI auto-complete** — engine existe mas auto-complete quando `current >= target` não executa ação.
16. **Back navigation** — botão voltar não restaura tela anterior corretamente em go_router.
17. **Tracker records** — formato dual (daily note + arquivo próprio) sem sincronização definida.
18. **Google Drive sync** — não recursivo; hash de conflito não persistido.

### 🟢 Implementado com ressalvas menores

19. Vault structure básica, modelos Dart, CRUD core de Tasks/Goals/Habits/Notes/Resources.
20. Planner Day/Week/Month com visualização básica.
21. Journal Entry standard com rich text (bugs de rendering existem).
22. Mood model com picker parcial e mood_settings_screen.
23. Sync com Google Drive (arquitetura presente, robustez incompleta).
24. Archive Universal com restore.
25. Scheduler básico (faltam tipos avançados e regras de exclusão na UI).
26. Pomodoro timer funcional.
27. Conflict resolution UI.
28. Command Center overlay.
29. Navigation shortcuts customizáveis.
30. Social Posts com bulk import e oEmbed.

---

*Fim do gap analysis. Total de itens analisados: ~220. Implementados sem ressalvas: ~30 (~14%). Parciais: ~110 (~50%). Ausentes: ~80 (~36%).*