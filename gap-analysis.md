# Spec: Week Timeline Redesign + Notes Reading/Writing Redesign

Status: Draft for Laura's review
Depends on: `TodayAggregatorService` (already implemented), `PropertyGrid` (already implemented, currently unused for Notes)
Does not depend on: Day Dial v2, Aromatherapy, Google Drive sync fixes (unrelated work streams)

---

## 0. Source audit — what already exists (read before implementing)

This spec was written after reading the actual current code, not the docs. Three pieces of relevant infrastructure already exist in the repo but are **not listed in the project's file manifest** (it appears stale) and are **barely wired in**:

| File | Status found |
|---|---|
| `lib/ui/widgets/dashboard/week_overview_component.dart` | Exists. Renders "This Week" as a 7-column grid (one column per weekday), each column showing up to `maxItemsPerDay` compact chips. This is the current "week part" the request refers to. |
| `lib/services/today_aggregator_service.dart` + `lib/providers/today_provider.dart` | Exists and already implemented (previously only spec'd per project memory — it has since been built). `TodayAggregatorService.buildForDate()` returns `List<TodayItem>` per calendar day, already sorted chronologically, already carrying `emoji`, `color`, `isCompletable`, `isCompleted`, `isPlayable`, and the original `source` object. **This is the exact data source needed for the new Week Timeline** — no new aggregation logic is needed, only new UI that consumes it across 7+ days instead of 1. |
| `lib/ui/widgets/property_grid.dart` | Exists: `PropertyGrid` / `PropertyCard` — a grid of **separate boxes**, one per property, each with icon, label, value, color-coded state (`empty`, `overdue`, `dueToday`, `streakActive`, `complete`), and a `customChild` slot for arbitrary widgets (e.g. a `Switch`). **It is used in exactly one place in the whole codebase** (`_buildLinkedGoogleEventRows`, `universal_detail_view.dart:1273`) and is never used for Notes. Notes currently render properties via the older `_buildPropertiesCard`/`_PropRow` pattern (`universal_detail_view.dart:3088`), which is a single rounded container with divided rows — i.e. **not** separate boxes. |

🔎 **Proactive finding (unrelated to this request, flagging per standing practice):** `universal_detail_view.dart` imports `../widgets/quartzo_chart.dart`, and that file exists (200). The old `citrine_chart.dart` no longer exists (404) — it's been renamed already. This is evidence toward resolving the open "Citrine vs Quartzo" naming question from prior sessions: the code has already moved to "Quartzo" for at least this file. Not acted on in this spec; noted for when the naming decision is made.

---

## 1. Decisions this spec makes on your behalf (flagging up front)

You asked several implicit questions in your message. Answers below, with rationale — **please confirm or override before implementation starts**, since they affect ticket scope:

| Question | Decision made | Rationale |
|---|---|---|
| Is "the week part" the small Home dashboard card, or a new full screen? | **Both.** The dashboard `WeekOverviewComponent` stays as a small entry-point preview card, but tapping it (or its header) now opens a new **full-screen Week Timeline** — this is where the Craft-style list lives. A 7-day chronological list with checkboxes, play buttons, and infinite scroll does not fit inside a bounded dashboard card. | The reference screenshot you sent (Image 5) is Craft's own full-page Calendar screen, not an embedded widget — it has its own app bar, its own scroll, its own "show previous days" affordance. That only makes sense as a dedicated screen. |
| Fixed height per day vs. variable, with day-internal scroll vs. page-level scroll? | **Variable height per day, page-level scroll.** No per-day internal scroll. | On the dashboard card (bounded space, side-by-side columns) fixed height + internal scroll makes sense and is correctly what the current `WeekOverviewComponent` already does. On a full screen (single vertical list, one day above another) there is no width constraint forcing a fixed box — each day section is exactly as tall as its item count requires, like Craft's calendar screen. |
| Infinite/eternal scroll, or pagination week-by-week with a "next/prev week" button? | **Infinite, lazily-loaded, chunked by day going forward from today.** Past days are *not* shown by default; a "Show previous days" affordance at the very top reveals them going backward, also lazily. | This exactly matches Image 5: it opens on today, shows a handful of days ahead, and has a collapsed "↑ Mostrar Dias Anteriores" control above today rather than a week-swiper. A "prev/next week" button model (like the existing dashboard card) is a *reasonable alternative* but contradicts the reference screenshot's own pattern, so it's out of scope for the full screen — the dashboard card keeps its arrow-based paging since that already works and matches its bounded layout. |
| How does the user get back to "today"? | **Explicit "Hoje" jump control**, always visible, that scrolls back to today's section instantly (not by paging through days one at a time). | Because scroll is infinite and open-ended in both directions, "keep scrolling until you find today" is not viable UX once the user has scrolled a few weeks out. `planner_screen.dart` already establishes this exact pattern for single-day navigation (a "Hoje" pill button, see `planner_screen.dart:850-859`) — reused here for consistency. |
| What happens on a day with zero items? | **The day header still renders**, with a single muted placeholder row ("Nothing scheduled"), so the chronological structure of the week stays visually intact (you can see Saturday is empty, not that Saturday is missing). | Matches Craft's Calendar screen, which shows every day's header even when a day has no content under it (Image 5 shows day headers with nothing but whitespace beneath some of them). |

---

## PART A — Week Timeline

### A.1 New screen: `WeekTimelineScreen`

New file: `lib/ui/screens/week_timeline_screen.dart`

**Entry points:**
- Tapping the title/header row of the existing `WeekOverviewComponent` dashboard card (currently just static text, "This Week" — `week_overview_component.dart:57`) navigates to `WeekTimelineScreen`.
- Add a route, e.g. `context.push('/week')` (the codebase already uses `go_router`, see `week_overview_component.dart:6` and its existing `context.push('/planner?date=...')` call).
- Optional (P2, not required for v1): a "Week" entry in bottom navigation or the "More" screen, if Laura wants it reachable outside the dashboard.

**Does NOT replace `planner_screen.dart`.** `PlannerScreen` remains the single-day detailed view (Day Dial, habit slots, day-specific actions). `WeekTimelineScreen` is a new, separate, higher-level "scan the week" view. Tapping any row in `WeekTimelineScreen` navigates to that item's own detail (`UniversalDetailView`) exactly like the current dashboard chips do (`navigateToObject(context, item.source)`, reused as-is) — it does **not** navigate into `PlannerScreen`, unless Laura wants a "see full day" affordance per day header (P2, see Ticket W6).

### A.2 Data source

Reuse `todayItemsProvider(date)` (family provider, `lib/providers/today_provider.dart`) for each date needed. No changes to `TodayAggregatorService` are required for v1. Each day's `List<TodayItem>` is already:
- Filtered to that calendar day
- Sorted chronologically, with all-day/untimed items first, alphabetically among themselves, per the existing sort in `TodayAggregatorService.buildForDate` (lines ~163-171 of `today_aggregator_service.dart`)

`WeekTimelineScreen` calls this provider once per visible date and concatenates the results into day sections. No new data model is introduced.

### A.3 Screen layout, top to bottom

```
┌─────────────────────────────────────┐
│  ←   Week Timeline            🔍 ⋯  │  <- AppBar
├─────────────────────────────────────┤
│      ↑ Show previous days           │  <- collapsed by default, tap to expand
├─────────────────────────────────────┤
│  Jul 9  ·  Today  ·  Thursday        │  <- day header
│  ─────────────────────────────────  │
│  ☐  📅 09:00  Standup                │  <- item row
│  ☑  ✅ 10:30  Fix login bug     ▶    │
│  ☐  🔄        Morning stretch        │
├─────────────────────────────────────┤
│  Jul 10  ·  Tomorrow  ·  Friday       │
│  ─────────────────────────────────  │
│  ☐  ✅ 14:00  Send invoice      ▶    │
├─────────────────────────────────────┤
│  Jul 11  ·  Saturday                 │
│  ─────────────────────────────────  │
│  —  Nothing scheduled                │
├─────────────────────────────────────┤
│  ...(more days load as you scroll)   │
└─────────────────────────────────────┘
                                  ⬤ Hoje   <- floating jump-to-today button
```

#### A.3.1 App bar
- Title: "Week Timeline" (or "Semana" if Laura prefers PT for this one label — but per the standing UI terminology rule, all UI text stays in English regardless of Laura's own working language).
- Actions: a search icon (P2, filters visible rows by title substring, no new data needed) and an overflow menu with a single "Jump to date…" action that opens a date picker and scrolls to that date's section (creating it if not yet loaded).

#### A.3.2 "Show previous days" control
- A single tappable row, always the first element in the scroll list, showing an up-arrow icon and the label "Show previous days".
- On first tap: prepends 7 days ending yesterday (i.e., the 7 days immediately before today), each rendered as its own day section, in chronological order, and the control's label changes to reflect it can be tapped again to go back a further 7 days. It never disappears — going further into the past is always possible.
- Tapping it does **not** auto-scroll the viewport down to compensate for inserted content above; the scroll offset is preserved by anchoring on the currently-topmost visible day section, exactly like Craft's control in Image 5 (pressing it inserts days above the fold without visually yanking today off-screen).

#### A.3.3 Forward infinite scroll
- On initial load: render Today + the next 13 days (2 weeks) worth of day sections.
- When the user scrolls within 3 day-sections of the bottom of the loaded list, silently append the next 7 days.
- No visible "load more" button going forward — this direction is the one that behaves like an endless feed, since "what's coming up" is naturally open-ended, matching the ask ("rolagem eterna" for the forward direction). Only the backward/past direction is manual, since revisiting history is a deliberate, occasional action, not a continuous scan.

#### A.3.4 Day header
Each day section header shows, left-aligned, matching the density and structure of Image 5's rows:
- Date, short format: `9 de jul.` equivalent → use `d MMM.` in the user's locale (existing code already formats dates with `intl`, e.g. `DateFormat('E', 'en_US')` in `week_overview_component.dart:99`).
- A separator dot, then a relative-day label: `Today` / `Tomorrow` / `Yesterday` for those three specific days only; every other day shows nothing here (no relative label) — instead:
- A second separator dot, then the weekday name (`Thursday`, `Friday`, …), shown for **every** day including Today/Tomorrow/Yesterday (Image 5 shows both the relative label *and* the weekday name together, e.g. "9 de jul. · Hoje · Quinta-feira").
- Today's header is visually emphasized: bold weight and accent color on the "Today" label (reuse `AppColors.accent`, consistent with how `WeekOverviewComponent` already highlights the current day, `week_overview_component.dart:97-98`).
- A thin full-width divider directly beneath the header row, before the item rows begin.
- No per-day overflow menu ("...") is needed in v1 — Craft's "..." per day in Image 5 is Craft's own generic page actions (add day note, etc.) which has no equivalent object in this app's data model. Omit it; revisit only if Laura wants a "create task for this day" quick-action per header (P2, Ticket W6).

#### A.3.5 Item row anatomy
One row per `TodayItem`, in the order returned by the aggregator (already chronological). Row layout, left to right:

1. **Checkbox** — shown only if `item.isCompletable == true`. If `isCompletable == false` (journal entries, events, pomodoro log entries, reminders — see the `TodayItem` construction sites in `today_aggregator_service.dart`), this slot is left visually empty (a fixed-width blank space, not collapsed), so the emoji column stays aligned across all rows in the section.
   - Checkbox state = `item.isCompleted`.
   - Tapping it toggles completion using the existing per-kind logic, not new logic:
     - `TodayItemKind.task` → `ref.read(tasksProvider.notifier).updateTask(task.copyWith(stage: task.isCompleted ? TaskStage.active : TaskStage.finalized))` (mirroring the existing finalize pattern at `planner_screen.dart:2976-2982`; exact enum/field names must be confirmed against `task_model.dart` at implementation time, since `stage` there uses a `TaskStage` enum with a `finalized` value, not a raw boolean).
     - `TodayItemKind.habitSlot` → `ref.read(vaultProvider.notifier).toggleHabit(habit, date, slotIndex: ...)` (existing method, `vault_provider.dart:410`).
   - No optimistic-UI subtlety needed beyond what `Checkbox`'s own `onChanged` gives you — the underlying providers already drive rebuilds.
2. **Emoji** — `item.emoji`, fixed-width slot (e.g. 20px), so titles align in a column.
3. **Time** — if the item's timestamp carries a real time-of-day (i.e., not midnight — reuse the same "untimed" check already present in `TodayAggregatorService.buildForDate`'s sort comparator, lines ~163-166 of `today_aggregator_service.dart`), show `HH:mm` in a muted, fixed-width slot (e.g. 44px) directly after the emoji. If untimed, this slot is blank (not collapsed — same column-alignment reasoning as the checkbox slot).
4. **Title** — `item.title`, single line, ellipsized, expands to fill remaining width. Uses `item.color` for its text/tint per the existing convention (`item.color` is already computed by the aggregator per task priority/kind).
   - If `isCompleted == true`: title gets `TextDecoration.lineThrough` and is dimmed to ~50% opacity — this exact convention already exists in `checklist_view.dart:98` (`decoration: item.isCompleted ? TextDecoration.lineThrough : null`) and should be reused verbatim for visual consistency across the app.
5. **Play button** — shown only if `item.isPlayable == true` (currently true for `TodayItemKind.task` and for `TodayItemKind.event` when `event.pomodoro != null`, per `today_aggregator_service.dart`). Renders a small circular outline "play" icon button. On tap:
   ```dart
   ref.read(pomodoroProvider.notifier).setCurrentItem(item.source.id, item.source.title);
   Navigator.push(context, MaterialPageRoute(builder: (_) => const PomodoroScreen()));
   ```
   This is the exact call already used by `_startFocusSession` in `universal_detail_view.dart:4797-4803` — reuse it rather than re-implementing.
6. **Tap anywhere else on the row** (i.e. not on the checkbox or the play button specifically): navigates to the item's detail, reusing the existing `navigateToObject(context, item.source)` helper already used by `WeekOverviewComponent` (`week_overview_component.dart`, imported from `../../navigation/object_navigation.dart`).

Row height is intrinsic to its content (single line of text ⇒ compact row, roughly 40-44px tall including vertical padding) — **not** a fixed height with internal truncation of the row itself (only the title text truncates via ellipsis, per item 4 above).

#### A.3.6 "Hoje" (jump to today) control
- A floating pill button, bottom-center or bottom-right of the screen (match the existing floating-button conventions already used elsewhere in the app, e.g. `pomodoro_floating_clock.dart`, for visual consistency — read that file at implementation time for exact styling if a decision is needed).
- Label: "Hoje" (this one label may stay in Portuguese to match the equivalent control already implemented in `planner_screen.dart:859`, which uses "Hoje" verbatim — consistency with that existing precedent outweighs the general English-UI rule for this single reused label; **flag to Laura for final call**, defaulting to matching the existing precedent).
- Only visible/enabled when today's section is **not** currently the topmost fully-visible section in the viewport (avoid showing a no-op button while already looking at today).
- On tap: scrolls the list so today's day header sits at the top of the viewport, loading today's chunk first if it had been scrolled out of the currently-materialized range (i.e., this button can also serve as a "reset" if the user had expanded many weeks of past days and lost their place).

### A.4 Dashboard `WeekOverviewComponent` changes (minimal)

- No structural change to the 7-column grid layout — it continues to work well in its bounded card context and already satisfies "chronological, with emoji" at a glance for the compact use case.
- Make the header row (`Icons.view_week_rounded` + title text, `week_overview_component.dart:52-58`) tappable, navigating to `WeekTimelineScreen`.
- Optional polish (P2): add a small chevron (`Icons.chevron_right_rounded`) after the title text to visually signal it's tappable, consistent with how other dashboard cards/list rows in this app already use trailing chevrons to indicate navigability (e.g. `_buildPropRow` in `universal_detail_view.dart:3176-3179`).

### A.5 Implementation tickets (dependency-ordered)

| # | Priority | Ticket | Depends on | Acceptance criteria |
|---|---|---|---|---|
| W1 | P0 | Create `WeekTimelineScreen` skeleton: app bar, route registration (`/week`), empty scaffold rendering Today + next 13 days using `todayItemsProvider`, no infinite scroll yet. | none | Navigating to `/week` shows 14 day headers in order, each showing correct date/relative-label/weekday, with correct items per day sourced from `todayItemsProvider`. |
| W2 | P0 | Build the item row widget (checkbox / emoji / time / title / play button) as a standalone widget, e.g. `WeekTimelineItemRow`. | W1 | Rows render all 5 slots correctly for at least one item of each `TodayItemKind`; checkbox toggles task/habit completion via existing providers; play button starts a pomodoro session via `pomodoroProvider`; completed items show strikethrough + dimmed title. |
| W3 | P0 | Empty-day placeholder row ("Nothing scheduled") for days with zero `TodayItem`s. | W1 | A day with no items still renders its header + a single muted placeholder row, not a collapsed/hidden section. |
| W4 | P1 | Forward infinite scroll: append next 7 days when scroll nears the bottom. | W1 | Scrolling to the bottom of 14 preloaded days silently loads 7 more without a visible loading spinner or jank. |
| W5 | P1 | "Show previous days" control + backward pagination anchored at current scroll position. | W1 | Tapping the control inserts the 7 preceding days above Today without visibly shifting the currently-visible day section; tapping again goes a further 7 days back; the control never disappears. |
| W6 | P1 | "Hoje" floating jump button with scroll-to-today behavior, visibility tied to whether Today is already the topmost visible section. | W1, W4, W5 | Button is hidden while Today's header is at the top of the viewport; appears once scrolled away in either direction; tapping it scrolls back so Today's header is at the top, re-loading the today chunk if needed. |
| W7 | P2 | In-page search (title substring filter) via the app bar search icon. | W1 | Typing a query hides rows/days that don't match; day headers with zero matching rows collapse entirely while a search query is active (this is the one case where empty-day headers *should* disappear, since the user is actively filtering). |
| W8 | P1 | Dashboard `WeekOverviewComponent` header becomes tappable → navigates to `/week`. | W1 | Tapping the "This Week" title/icon row on the Home dashboard opens `WeekTimelineScreen`. |
| W9 | P2 | Chevron affordance on the dashboard card header. | W8 | Visual only; no behavior change. |

---

## PART B — Notes: Reading & Writing Redesign

### B.1 Current state (read from code)

- All content types share one screen, `UniversalDetailView` (`lib/ui/screens/universal_detail_view.dart`, 7281 lines), which is a generic `CustomScrollView` with: breadcrumbs → `SliverAppBar` (back button, centered type-label, actions, overflow menu) → hero header → **type-specific property cards** → organizers ("Conexões") → linked objects → **type-specific content** (this is where the actual Note body lives) → mentions/backlinks → reminders.
- For `Note` objects specifically, the body is rendered inside `_buildTypeSpecificContent` (line 2584): a single `Container` with generic `AppTheme.cardDecoration` and 16px padding, containing either `_buildNoteEditor` or `_buildNoteViewer` depending on `_isEditing`.
  - `NoteSubtype.text` → `MarkdownBodyView` (read-only render) or `RichTextEditor` (Quill-based, edit mode).
  - `NoteSubtype.outline` → `OutlineEditor` in both modes.
  - `NoteSubtype.collection` → `CollectionView` in both modes.
  - If `note.isChecklist == true` and subtype is `text`, `ChecklistView` is used instead of `MarkdownBodyView` for the read-only render.
- Note properties currently render via `_buildPropertiesCard` (line 1119-1136): one card titled "Config" with three rows (Subtipo, Categoria, Fixado) plus a separate default "Datas" card (Created/Modified) — all inside a single divided-row container, **not** separate boxes.
- `PropertyGrid`/`PropertyCard` (`lib/ui/widgets/property_grid.dart`) already exists and is exactly the "separate boxes" component needed, but is unused for Notes (in fact used almost nowhere in the app yet — see §0).
- The overflow menu ("...") for notes already supports: convert-to-checklist, edit, change-type, merge-note, save-template, archive, delete, open-in-Obsidian (`universal_detail_view.dart:675-684`).

### B.2 What the Craft screenshots show (described in full, since the implementing AI cannot see the images)

Five screenshots of the Craft app (a competing notes app) were provided as inspiration. Described in detail:

1. **Screenshot (doc "..." menu open):** A document titled with breadcrumb "H. / Cr... / Li..." at top (folder icon + truncated ancestor path), a share icon, and a "..." icon. Tapping "..." opens a bottom-anchored menu with, top to bottom: "Estilo da Página" (Page Style), a divider, "Buscar na Página" (Search in Page), a divider, "Sumário" (Table of Contents), a divider, "Visualizar" (View) — this one has a `>` chevron, indicating it opens a submenu — a divider, "Favoritar Documento" (Favorite Document), "Mover para" (Move to), a divider, "Desfazer / Refazer" (Undo/Redo), and finally "Excluir Página" (Delete Page) in red/destructive styling at the bottom. Below the menu, a persistent bottom toolbar shows icons for: reply/share, a "magic wand" (AI actions), a pencil (edit mode toggle), a colorful circular icon (Craft's own AI assistant), and a "+" (add block).
2. **Screenshot (body text, editing):** Plain paragraph text at 1.6-ish line height, followed by a **callout/quote block**: a light blue-gray tinted, fully rounded-corner box (not just a left border — the entire box has a tinted background), containing bold-ish dark blue body text explaining a feature, with an inline highlighted term shown in a small yellow rounded chip (`@` character highlighted this way to call out that it's a special trigger character). Below the callout, a second **plain gray box** (lighter tint, not blue) with a regular-weight explanation paragraph containing one **bold inline term** ("backlinks"). Beneath both boxes: "Read more on our Help Site:" followed by a **link preview card** — a bordered, rounded card with a small link icon, a bold title ("Links and backlinks"), and a muted subtitle ("Document & subpage links"). A bottom toolbar in edit mode shows text-formatting icons: page/paragraph type selector, "Aa" (font/text style), a checkbox icon, a "play" arrow icon, bullet list, numbered list, indent/outdent arrows, and a second row with "Foco" (focus mode), "Bloco" (block menu), a color wheel, and "..." more options.
3. **Screenshot:** Same body content mid-edit with the on-screen keyboard open and a text-suggestion bar above it (standard OS-level autocomplete, not app-specific) plus a small toolbar row above the keyboard with a document icon, "Aa", "...", a circular arrow (redo), a duplicate/copy icon, and a keyboard-dismiss icon.
4. **Screenshot (top of the same document):** This is the key visual reference for the "reading" redesign. From top: breadcrumb bar (same as #1) → a **large H1 title** ("Linking Content") in bold, dark, large sans-serif type, with a thin full-width divider directly beneath it → a **light-gray rounded callout box** containing a short, punchy intro line in large semibold text with a trailing emoji (a "hook" sentence) → a **full-width cover image** (a tall architectural library photo, rounded corners, edge-to-edge within the content margin) directly below the callout, functioning as a hero/cover image for the page → then regular body paragraph text resuming below the image, in the same 1.6-line-height style as #2.
5. **Screenshot (unrelated — Craft's own Calendar/Week screen):** Already fully covered by Part A of this spec; not relevant to Notes.

### B.3 New Note page chrome (applies to all Note subtypes)

The generic `UniversalDetailView` shell stays in place for **every other object type** (Task, Habit, Goal, Project, Person, etc.) — this redesign only changes how the shell is populated **when `object is Note`**, so no other content type is affected.

1. **Breadcrumb bar** — already exists (`_buildBreadcrumbs`, line 6559); keep as-is.
2. **App bar** — keep back button and overflow menu; the centered type-label ("NOTE") stays for consistency with every other object type in the app. Add a share icon button next to the overflow menu specifically for Notes, mirroring Craft's share icon in screenshot #1 (wraps the existing OS share sheet around a rendered plain-text/markdown export of the note — reuse the sharing utility already used elsewhere in the app if one exists; if none exists, this becomes its own small ticket, see N7).
3. **Overflow menu additions for Notes** (extending the existing `typeActions['note']` list at `universal_detail_view.dart:675-684`), in this order to mirror the Craft menu structure described in B.2 item 1:
   - `page_style` (new) — opens a bottom sheet to set the note's **cover image** (pick/replace/remove) and **accent color** (reuses the existing `color` field already on `Note`, and the existing `app_color_picker.dart` widget already in the codebase).
   - `search_in_page` (new) — opens an in-page search overlay that highlights matching text within the rendered body (text/outline subtypes only; not applicable to `collection`).
   - `table_of_contents` (new, text/outline subtypes only) — parses `##`/`###` markdown headings (or outline top-level items) from `note.body` and shows them as a tappable list in a bottom sheet; tapping one scrolls the body to that heading.
   - existing: `convert_to_checklist`, `edit`.
   - `favorite` — this already exists conceptually as the `pinned` field/property; no new menu item needed if pin/unpin stays as a property-grid toggle (see B.4). If Laura wants it *also* reachable from the overflow menu (matching Craft's placement), add a thin wrapper item that flips the same `pinned` field.
   - `move_to` (new) — opens the existing note/folder picker pattern (reuse `parentNoteId` — this already exists on `Note`, currently only settable via... **note: confirm at implementation time whether a "set parent note" UI currently exists anywhere; if not, this ticket includes building that picker using the existing `UniversalSearchPickerSheet` generic search-picker infrastructure**).
   - existing: `change_type`, `merge_note`, `save_template`, `archive`, `delete`, `obsidian`.
   - Undo/redo is not currently a menu-level action anywhere in the app (undo exists as a snackbar-triggered `UndoService` after destructive actions, e.g. `universal_detail_view.dart:4840`) — **do not** add a generic undo/redo menu item; this would require an undo-stack for arbitrary text edits inside the Quill editor, which is a materially larger feature than this redesign and is out of scope (flag as a separate future request if Laura wants it).

### B.4 Body content redesign (the "reading and writing focused" part)

Replace the current generic `Container` + `AppTheme.cardDecoration` wrapper (`universal_detail_view.dart:2592-2603`) for Notes specifically with a dedicated reading-page layout:

1. **Remove the card/border chrome around the body.** The note body should read like a page, not like a card sitting inside another page — full-bleed within the screen's horizontal content margin, no visible container border/shadow behind the text itself.
2. **Cover image (new).** Add an optional `coverImagePath` (or `coverImageUrl`, matching whatever convention the app already uses for storing local image paths — confirm against how Resource/attachment images are already stored in the vault, since the app already handles image attachments elsewhere) field on `Note`. If set, render it full-width, rounded corners (12-16px radius), directly below the app bar/breadcrumb and above the title, height proportional (e.g. 180-220px, `BoxFit.cover`) — matching screenshot #4's cover photo placement. If unset, this space is simply omitted (no placeholder box).
3. **Title.** Note titles are already editable elsewhere in the app (the generic hero header used by every object type handles title editing) — keep using that same mechanism for consistency; just increase its font size/weight specifically when `object is Note` to match the large, bold H1 treatment in screenshot #4 (e.g. 28-32px, weight 800), with a thin full-width divider directly beneath it, matching screenshot #4 exactly.
4. **Body typography.** In `MarkdownBodyView`'s `MarkdownStyleSheet` (`markdown_body_view.dart:88-125`), the paragraph style already uses `fontSize: 15, height: 1.6` — this already matches the Craft reference reasonably well; no change needed there. Two changes are warranted:
   - Constrain body content to a comfortable reading width on large screens (e.g. `maxWidth: 680` centered), reusing the app's existing `adaptive_layout.dart`/`layout_utils.dart` helpers if they already provide a max-content-width primitive (check at implementation time before writing new layout code).
   - Increase paragraph spacing slightly (the current `MarkdownStyleSheet` doesn't set `pPadding`/`blockSpacing` explicitly — Flutter Markdown defaults are used; set an explicit `blockSpacing` of ~16 to give paragraphs visible breathing room, matching the airy spacing visible in screenshots #2 and #4).
5. **Callout/quote block redesign.** The current `blockquote`/`blockquoteDecoration` styling (`markdown_body_view.dart:114-121`) only adds a left border accent — it does **not** tint the background, unlike both callout boxes in screenshot #2 (one blue-tinted, one gray-tinted) and the intro callout in screenshot #4. Change `blockquoteDecoration` to a fully rounded-corner container with a light tinted background fill (using `AppTheme.accentColor(context).withValues(alpha: 0.08)` for emphasis-style callouts, matching the blue box; a plain `AppColors.surfaceVariant` fill for the neutral/gray-style box) plus generous internal padding (12-16px), removing the left-border-only look. Markdown itself only has one blockquote syntax (`>`), so there is only one visual variant available at the markdown level — the two-tone effect seen in Craft (blue vs. gray boxes) is a Craft-specific block-type distinction that doesn't map onto plain markdown blockquotes; **implement a single consistent tinted-callout style** for all blockquotes rather than trying to fake a second visual variant, and flag to Laura that true multi-style callouts would require extending the markdown dialect (out of scope here).
6. **Editing mode (`RichTextEditor`) gets the same page-chrome treatment** (cover image + large title above it + no card border around the editor's text area) so switching between read/edit mode doesn't visually jar the user with a sudden border appearing/disappearing.
7. **`OutlineEditor` and `CollectionView` subtypes** get the same outer chrome (breadcrumb, app bar, optional cover image, large title, no card border) applied around them, but their **internal** rendering (outline bullets, collection grid) is unchanged — this redesign is about the page shell, not about redesigning the outline/collection editors themselves, which are out of scope here.
8. **Checklist-mode notes** (`note.isChecklist == true`) keep using `ChecklistView` internally, wrapped in the same new page chrome as everything else.

### B.5 Properties section redesign (separate boxes + toggle)

Replace the Note-specific branch of `_buildTypeSpecificPropertyCards` (`universal_detail_view.dart:1117-1137`), which currently builds one `_buildPropertiesCard` titled "Config" plus a default dates card, with a `PropertyGrid` built from `PropertyCard`s — i.e., **separate boxes**, one per property, using the component that already exists in `property_grid.dart` but is not yet used anywhere meaningfully.

**Collapsible section (the "toggle" you asked for):** Wrap the whole properties block in a section with a header row — icon + "PROPERTIES" label (uppercase, muted, matching the existing section-header convention already used for "Config"/"Datas" cards, e.g. `universal_detail_view.dart:3099-3116`) + a trailing chevron icon button. Tapping the header row or chevron collapses/expands the entire property grid with a simple `AnimatedSize`. Default state: **expanded**. This state does not need to persist across app restarts for v1 (P2 to persist per-note via a local preference if Laura wants it remembered).

**Individual property boxes for Notes**, each a `PropertyCard`:

| Property | Icon | Value shown | Interaction |
|---|---|---|---|
| Subtype | matches subtype (e.g. `Icons.notes_rounded` for text, `Icons.account_tree_outlined` for outline, `Icons.grid_view_rounded` for collection) | "Text" / "Outline" / "Collection" | Tap opens the existing `change_type`-style subtype picker (read-only display is also acceptable for v1 if changing subtype after creation isn't otherwise supported elsewhere — confirm against `change_type` menu behavior at implementation time). |
| Category | `Icons.label_outline_rounded` | first category, or empty-state | Tap opens the existing category picker used elsewhere for this field. |
| Pinned | `Icons.push_pin_outlined` | **no text value** — `customChild` is a `Switch` bound to `note.pinned` | Toggling the switch directly calls `ref.read(vaultProvider.notifier).updateObject(note.copyWith(pinned: !note.pinned))`, no confirmation dialog, matching how boolean toggles behave everywhere else in the app (e.g. habit slot toggling is a single tap, no confirmation). |
| Is Checklist | `Icons.checklist_rtl_rounded` | **no text value** — `customChild` is a `Switch` bound to `note.isChecklist` | Same pattern as Pinned; this duplicates the existing `convert_to_checklist` overflow-menu action by design (both entry points toggle the same field) — this is intentional, matching how the properties grid elsewhere in the app also duplicates some overflow-menu actions as quick-access toggles. |
| Show in Planner | `Icons.calendar_view_day_outlined` | **no text value** — `customChild` is a `Switch` bound to `note.showInPlanner` | Same pattern. |
| Parent Note | `Icons.drive_file_move_outline` | parent note's title, or "None" (empty-state styling via `PropertyCardState.empty`) | Tap opens the "Move to" picker described in B.3 (shared with the overflow menu's `move_to` action). |
| Created | `Icons.calendar_today_outlined` | formatted `createdAt` | Not tappable. |
| Modified | `Icons.update_rounded` | formatted `updatedAt` | Not tappable. |

This replaces both the old "Config" card and the old default "Datas" card for Notes specifically — Notes get one unified, collapsible `PropertyGrid` instead of two separate `_buildPropertiesCard`s. Other object types (Task, Goal, Person, etc.) are **not** touched by this ticket; migrating them to `PropertyGrid` as well would be a good follow-up for visual consistency app-wide, but is out of scope for this request (flag as a future ticket if Laura wants app-wide consistency).

### B.6 New/modified files

- `lib/models/note_model.dart` — add `coverImagePath` (nullable `String`) field, plumbed through `toMarkdown`/`fromMarkdown`/`copyWith` exactly like the existing `color` field is (same nullability pattern, same frontmatter key convention, e.g. `cover_image_path`).
- `lib/ui/screens/universal_detail_view.dart` — Note-specific branches only: property-cards branch (§B.5), type-specific-content branch (§B.4), overflow-menu actions list (§B.3).
- `lib/ui/widgets/property_grid.dart` — no structural change expected; confirm `PropertyCard.customChild` sizing works well for a `Switch` (the `mainAxisExtent: 102` grid cell height, set in `PropertyGrid` at `property_grid.dart:74`, should comfortably fit a label row + a `Switch`, but verify at implementation time since `Switch` has its own minimum tap-target height).
- New: `lib/ui/widgets/note_table_of_contents_sheet.dart` (B.3).
- New: `lib/ui/widgets/note_search_overlay.dart` (B.3).
- New: `lib/ui/widgets/note_page_style_sheet.dart` (B.3, cover image + accent color picker).
- `lib/ui/widgets/markdown_body_view.dart` — blockquote styling (§B.4.5), block spacing (§B.4.4).

### B.7 Implementation tickets (dependency-ordered)

| # | Priority | Ticket | Depends on | Acceptance criteria |
|---|---|---|---|---|
| N1 | P0 | Convert Note properties from `_buildPropertiesCard` to `PropertyGrid`/`PropertyCard`, per the table in §B.5, without the collapse behavior yet. | none | Opening any Note shows separate boxes (not one divided list) for Subtype, Category, Pinned, Is Checklist, Show in Planner, Parent Note, Created, Modified. |
| N2 | P0 | Add collapsible header + `AnimatedSize` around the properties grid built in N1. | N1 | Tapping the "PROPERTIES" header row collapses/expands the grid smoothly; default state is expanded. |
| N3 | P0 | Replace boolean properties' value text with `Switch` via `customChild`, wired to `pinned`/`isChecklist`/`showInPlanner`. | N1 | Toggling each switch updates the underlying `Note` field immediately, with no confirmation dialog, and persists (confirm via re-opening the note). |
| N4 | P1 | Remove card/border chrome around the Note body; apply max-content-width constraint; increase blockquote/paragraph spacing per §B.4.4-5. | none (independent of N1-N3) | Reading a text-subtype note shows no visible border/shadow directly around the body text; blockquotes render as a filled, rounded, tinted box (not just a left border); paragraphs have visible spacing between them; body content doesn't stretch edge-to-edge on wide/tablet screens. |
| N5 | P1 | Add `coverImagePath` field to `Note` model (frontmatter round-trip) + page-style bottom sheet to set/clear it + render it in the body layout. | N4 | Setting a cover image via the new "Page Style" overflow action shows it full-width above the title on next view; clearing it removes it; the field survives a vault reload (i.e., it's actually persisted to frontmatter, not just in-memory). |
| N6 | P2 | Table of Contents overflow action (text/outline subtypes): parse headings, show tappable list, scroll-to-heading. | N4 | Opening "Sumário" from the overflow menu on a note with at least 2 markdown headings shows both, and tapping one scrolls the body view to that heading. |
| N7 | P2 | In-page search overflow action: highlight matching substrings in the rendered body. | N4 | Opening "Buscar na Página", typing a query present in the note body, highlights all occurrences. |
| N8 | P2 | Share icon in the app bar for Notes (plain-text/markdown export via OS share sheet). | none | Tapping the share icon on a Note opens the OS share sheet with the note's title + body as shareable text. |
| N9 | P2 | "Move to" picker (parent note assignment) — confirm whether this exists anywhere already before building; if not, build using `UniversalSearchPickerSheet`. | N1 (for the Parent Note property box's tap target) | Tapping the Parent Note property box (or the "Mover para" overflow action) opens a note picker; selecting one sets `parentNoteId` and the note now appears under "Nested Notes" on the chosen parent. |

---

## Guidelines.md / agents.md draft changelog additions

Propose adding, under the relevant version section of `guidelines.md` (exact version number to be assigned by Laura at merge time, currently on v5.x):

```
### Week Timeline (new)
- A new full-screen "Week Timeline" view exists at lib/ui/screens/week_timeline_screen.dart,
  reachable by tapping the Home dashboard's "This Week" component header.
- It reuses TodayAggregatorService/todayItemsProvider per-day; it introduces no new
  aggregation logic or data model.
- Scroll behavior: infinite forward (auto-loads future days), manual backward
  (explicit "Show previous days" control) — this asymmetry is intentional, not a bug.
- The dashboard's compact 7-column WeekOverviewComponent is unchanged in layout;
  it now also serves as a navigation entry point into the full Week Timeline.

### Note page redesign (new)
- Notes now render with dedicated "reading page" chrome distinct from every other
  object type's generic card-based property/content layout: optional cover image,
  large title, borderless body, tinted callout blocks.
- Note gained a new optional field: coverImagePath (frontmatter key: cover_image_path).
- Note properties now render via PropertyGrid (separate per-property boxes) instead
  of the older single-card _buildPropertiesCard pattern. This is the first broad use
  of PropertyGrid in the app; other object types still use the older pattern and
  should be migrated in a future pass for consistency.
- Boolean Note properties (pinned, isChecklist, showInPlanner) render as an inline
  Switch inside their property box rather than as tap-to-open text values.
```

---

## Summary of open questions for Laura

1. Confirm the Week Timeline is a **new full screen**, not a reshaping of the existing bounded dashboard card (§1, row 1).
2. Confirm "Hoje" stays in Portuguese for the jump button label, matching the existing `planner_screen.dart` precedent, despite the general English-UI rule (§A.3.6).
3. Confirm whether a "set parent note" / "move to" UI already exists anywhere in the app today — this affects whether Ticket N9 is new work or a wiring fix.
4. Confirm the storage convention to use for `coverImagePath` (how the app already stores local image attachment paths elsewhere, so Notes follow the same convention rather than inventing a new one).
5. Confirm whether the two-tone callout distinction in Craft (blue box vs. gray box) matters enough to extend the markdown dialect, or whether one consistent tinted-callout style (as proposed in §B.4.5) is acceptable.


🔴 Bugs que impedem o build (achados reais, não suposição)

week_timeline_screen.dart importa ../../providers/tasks_provider.dart e ../../providers/habits_provider.dart — nenhum dos dois arquivos existe (404 nos dois). tasksProvider e habitsProvider são definidos dentro de vault_provider.dart (linhas 347 e 830), não em arquivos próprios. Isso não compila como está.
note_page_style_sheet.dart:31 — await image.path.toFile(). image.path é String, e String não tem método .toFile() em Dart puro; não achei nenhuma extension definindo isso em lugar nenhum do repo. O padrão já estabelecido no próprio código (rich_text_editor.dart:161, que também usa ImagePicker) é File(image.path). Isso também não compila.

Week Timeline — o que bateu com o spec
✅ Tela nova (WeekTimelineScreen), rota /week registrada e importada em main.dart, card do dashboard virou clicável e abre a tela nova, com chevron — W1, W8, W9 corretos.
✅ Linha do item: checkbox/emoji/horário/título/play, exatamente como especificado, reusando pomodoroProvider.setCurrentItem igual ao _startFocusSession existente — W2 correto.
✅ Dia vazio mostra "Nothing scheduled" em vez de sumir — W3 correto.
✅ Scroll infinito pra frente (carrega +7 dias a 200px do fim) — W4 correto.
✅ Bônus não pedido explicitamente mas bom: busca com filtro que esconde dias vazios durante a pesquisa.
⚠️ "Mostrar dias anteriores" (W5) não ficou como pedi: usa ListView.builder simples inserindo dias no índice 0 — isso vai fazer o viewport pular visualmente, porque não há âncora de scroll preservada. O spec pedia especificamente que a inserção não deslocasse visualmente o dia que já está na tela.

Notas — o que bateu com o spec
✅ Propriedades viraram PropertyGrid de verdade — 8 caixinhas separadas (Subtype, Category, Pinned, Checklist, Show in Planner, Parent Note, Created, Modified).
✅ Seção colapsável com header "PROPERTIES" + chevron, AnimatedSize, padrão expandido — N2 correto.
✅ Os 3 booleanos (Pinned/Checklist/Show in Planner) usam Switch de verdade via customChild, ligados direto em vaultProvider.updateObject — N3 correto.
✅ Parent Note picker funcional via UniversalSearchPickerSheet — N9 correto.
✅ Card genérico removido do corpo, maxWidth: 680, callout virou caixa cheia tintada com cantos arredondados (não só borda esquerda), blockSpacing: 16 — N4 (tipografia/callout) correto.
✅ coverImagePath no model com round-trip de frontmatter certinho, imagem de capa renderiza acima do corpo quando definida — N5 correto na essência.
✅ Ícone de share na app bar das Notas — N8 correto.
⚠️ Título da nota (parte do N4) não foi feito: o header continua sendo o mesmo card genérico compartilhado com todos os outros tipos de objeto (AppTheme.cardDecoration, 22px) — o pedido de "título grande estilo H1, sem borda de card, com divisor embaixo" especificamente pra Notas não foi aplicado.
⚠️ Subtype e Category nas caixinhas têm onTap com // TODO: Open ... picker (N1) — é um stub silencioso, tocar não faz nada. Exatamente o padrão de "stub vazio" que já discutimos antes como algo pra sinalizar.
⚠️ Imagem de capa não tem altura fixa (180-220px como no spec) — vai renderizar no aspect ratio natural da imagem, podendo ficar bem alta dependendo da foto.
⚠️ Table of Contents (N6): parseia headings e mostra a lista, mas tocar num heading tem // TODO: Scroll to heading position — não rola até lá, então o critério de aceite não foi cumprido.
⚠️ Busca na página (N7): virou um contador "X de Y ocorrências" com next/prev num bottom sheet separado — não faz o destaque (highlight) dentro do corpo renderizado como o spec pedia; é mais um "contador de ocorrências" que uma busca in-page de verdade.
ℹ️ Os dois arquivos que eu tinha sugerido como novos (note_table_of_contents_sheet.dart, note_search_overlay.dart) não foram criados separadamente — viraram classes privadas dentro do próprio universal_detail_view.dart, que já tinha 7280 linhas e agora tem quase 7900. Não é errado, mas engorda ainda mais o arquivo já gigante.