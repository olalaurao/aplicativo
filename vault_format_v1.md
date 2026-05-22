# Vault Format V1

App-managed objects are written as Markdown files under `app/`.

## Canonical Object File

Path:

```text
app/OBJECT_ID.md
```

Every object must include YAML frontmatter with:

```yaml
id: "stable-id"
type: "task"
title: "Object title"
created_at: "2026-05-08T10:00:00.000"
updated_at: "2026-05-08T10:00:00.000"
archived: false
pinned: false
categories: []
tags: []
moc: []
organizers: []
reminders: []
```

Type-specific properties live in the same frontmatter. The Markdown body stores rich text or structured sections when the type needs body content.

## Compatibility

The reader remains recursive from the vault root, so legacy files in `tasks/`, `habits/`, `trackers/`, `notes/`, `people/`, `resources/`, `sessions/`, `moods/`, and `daily/` continue to load.

New object writes go through `MarkdownParser.prepareForSave` via `VaultNotifier.createObject` or `VaultNotifier.updateObject`.

## Daily Notes

Daily notes remain in:

```text
daily/YYYY-MM-DD.md
```

Journal entries, habit completions, task checkboxes, and pomodoros are regenerated together so one section does not overwrite the others.

## Tracker Records

New tracking records are canonical object files:

```text
app/TRACKER_RECORD_ID.md
```

with `type: "tracker_record"`, `tracker_id`, `date`, and `field_values` in frontmatter.

Legacy daily-note tracker records in `trackers:` frontmatter are still read for compatibility, but new writes do not duplicate records into daily notes.
