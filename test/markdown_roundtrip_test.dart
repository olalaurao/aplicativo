import 'package:citrine/models/habit_model.dart';
import 'package:citrine/models/analysis_model.dart';

import 'package:citrine/models/goal_model.dart';
import 'package:citrine/models/mood_model.dart';
import 'package:citrine/models/note_model.dart';
import 'package:citrine/models/people_model.dart';
import 'package:citrine/models/project_model.dart';
import 'package:citrine/models/reminder_model.dart';
import 'package:citrine/models/resource_model.dart';
import 'package:citrine/models/shared_types.dart';
import 'package:citrine/models/snapshot_model.dart';
import 'package:citrine/models/task_model.dart';
import 'package:citrine/models/tracker_model.dart';
import 'package:citrine/models/kpi_model.dart' as kpi_model;
import 'package:citrine/services/markdown_parser.dart';
import 'package:citrine/services/kpi_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markdown round-trip', () {
    test('task preserves base fields and subtasks', () {
      final task = Task(
        title: 'Plan week',
        stage: TaskStage.inProgress,
        priority: TaskPriority.high,
        notes: const ['Review planner'],
        subtasks: [Subtask(title: 'Pick priorities', completed: true)],
        reflection: 'Useful planning pass.',
        tags: const ['planning'],
        pinned: true,
      );

      final markdown = task.toMarkdown();
      final parsed = Task.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.title, task.title);
      expect(parsed.stage, TaskStage.inProgress);
      expect(parsed.priority, TaskPriority.high);
      expect(parsed.tags, contains('planning'));
      expect(parsed.pinned, isTrue);
      expect(parsed.reflection, 'Useful planning pass.');
      expect(parsed.subtasks.single.completed, isTrue);
    });

    test('organizer references preserve type in wikilinks', () {
      final reference = OrganizerReference(type: 'project', slug: 'launch', title: 'Launch');
      final parsed = OrganizerReference.fromWikiLink(reference.toWikiLink());

      expect(reference.toWikiLink(), '[[project/launch]]');
      expect(parsed.type, 'project');
      expect(parsed.slug, 'launch');
    });

    test(
      'daily note body preserves entries, tasks, habits, trackers and pomodoros',
      () {
        final body = MarkdownParser.generateDailyNoteBody(
          entries: const [
            {
              'time': '08:30',
              'title': 'Morning',
              'body': 'Started well',
              'mood': 'good',
              'organizers': ['health'],
            },
          ],
          tasks: const [
            {'title': 'Plan day', 'completed': true},
          ],
          habits: const {'hydrate': 3},
          trackers: const {
            'sleep': {'hours': 7.5},
          },
          pomodoros: const [
            {'time': '09:00', 'title': 'Focus', 'duration': 25, 'blocks': 1},
          ],
        );

        final entries = MarkdownParser.parseJournalEntries(body, '2026-05-08');
        final tasks = MarkdownParser.parseTasksFromDailyNote(body);
        final pomodoros = MarkdownParser.parsePomodoros(body);

        expect(entries.single['body'], 'Started well');
        expect(tasks.single['completed'], isTrue);
        expect(body, contains('[[hydrate]]'));
        expect(body, contains('hours: 7.5'));
        expect(pomodoros.single['title'], 'Focus');
      },
    );

    test('habit preserves schedule metadata', () {
      final habit = Habit(
        title: 'Hydrate',
        color: '#4D9DE0',
        dailyGoal: 8,
        completionUnit: 'glasses',
        tags: const ['health'],
      );

      final markdown = habit.toMarkdown();
      final parsed = Habit.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.title, habit.title);
      expect(parsed.color, '#4D9DE0');
      expect(parsed.dailyGoal, 8);
      expect(parsed.completionUnit, 'glasses');
      expect(parsed.tags, contains('health'));
    });

    test('note preserves subtype, tags and pinned state', () {
      final note = Note(
        title: 'Reference',
        subtype: NoteSubtype.text,
        body: 'Inline ![[image.png]] and [[links]].',
        tags: const ['reference'],
        pinned: true,
      );

      final markdown = note.toMarkdown();
      final parsed = Note.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.title, note.title);
      expect(parsed.subtype, NoteSubtype.text);
      expect(parsed.body, contains('![[image.png]]'));
      expect(parsed.tags, contains('reference'));
      expect(parsed.pinned, isTrue);
    });

    test('tracker definition preserves sections and fields', () {
      final tracker = TrackerDefinition(
        title: 'Sleep',
        sections: [
          TrackerSection(
            title: 'Night',
            inputFields: [
              InputField(
                id: 'hours',
                title: 'Hours',
                type: InputFieldType.quantity,
                unit: 'h',
              ),
            ],
          ),
        ],
      );

      final markdown = tracker.toMarkdown();
      final parsed = TrackerDefinition.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.title, tracker.title);
      expect(parsed.sections.single.title, 'Night');
      expect(parsed.sections.single.inputFields.single.id, 'hours');
      expect(parsed.sections.single.inputFields.single.unit, 'h');
    });

    test('planner and organizer object types preserve key fields', () {
      final project = Project(
        title: 'Launch',
        state: ProjectState.active,
        priority: TaskPriority.high,
        taskLinks: const ['task-a'],
      );
      final projectMarkdown = project.toMarkdown();
      final parsedProject = Project.fromMarkdown(
        MarkdownParser.parseFrontmatter(projectMarkdown),
        MarkdownParser.extractBody(projectMarkdown),
      );
      expect(parsedProject.priority, TaskPriority.high);
      expect(parsedProject.taskLinks, contains('task-a'));

      final goal = Goal(
        title: 'Run 100km',
        state: GoalStatus.active,
        goalType: GoalType.repeating,
        repeatInterval: 'monthly',
      );
      final goalMarkdown = goal.toMarkdown();
      final parsedGoal = Goal.fromMarkdown(
        MarkdownParser.parseFrontmatter(goalMarkdown),
        MarkdownParser.extractBody(goalMarkdown),
      );
      expect(parsedGoal.goalType, GoalType.repeating);
      expect(parsedGoal.repeatInterval, 'monthly');
    });

    test(
      'people, resources, reminders, moods, snapshots and analyses round-trip',
      () {
        final person = Person(
          title: 'Ada',
          email: 'ada@example.com',
          contactFrequency: const Duration(days: 14),
        );
        final personMarkdown = person.toMarkdown();
        final parsedPerson = Person.fromMarkdown(
          MarkdownParser.parseFrontmatter(personMarkdown),
          MarkdownParser.extractBody(personMarkdown),
        );
        expect(parsedPerson.email, 'ada@example.com');
        expect(parsedPerson.contactFrequency?.inDays, 14);

        final resource = Resource(
          title: 'A Book',
          resourceType: 'Book',
          status: ResourceStatus.inProgress,
          rating: 4,
          synopsis: 'Useful notes.',
        );
        final resourceMarkdown = resource.toMarkdown();
        final parsedResource = Resource.fromMarkdown(
          MarkdownParser.parseFrontmatter(resourceMarkdown),
          MarkdownParser.extractBody(resourceMarkdown),
        );
        expect(parsedResource.status, ResourceStatus.inProgress);
        expect(parsedResource.rating, 4);

        final reminder = Reminder(
          title: 'Stretch',
          time: DateTime(2026, 5, 8, 18),
          notes: 'Take a break',
        );
        final reminderMarkdown = reminder.toMarkdown();
        final parsedReminder = Reminder.fromMarkdown(
          MarkdownParser.parseFrontmatter(reminderMarkdown),
          MarkdownParser.extractBody(reminderMarkdown),
        );
        expect(parsedReminder.notes, 'Take a break');

        final mood = MoodDefinition(
          title: 'Good',
          label: 'Good',
          emoji: ':)',
          numericValue: 4,
          color: '#66AA77',
          order: 4,
        );
        final moodMarkdown = mood.toMarkdown();
        final parsedMood = MoodDefinition.fromMarkdown(
          MarkdownParser.parseFrontmatter(moodMarkdown),
          MarkdownParser.extractBody(moodMarkdown),
        );
        expect(parsedMood.numericValue, 4);
        expect(parsedMood.color, '#66AA77');

        final snapshot = Snapshot(
          title: 'Checkpoint',
          parentId: 'goal-1',
          kpiValues: const {'km': 42},
          reflection: 'Halfway.',
          date: DateTime(2026, 5, 8),
        );
        final snapshotMarkdown = snapshot.toMarkdown();
        final parsedSnapshot = Snapshot.fromMarkdown(
          MarkdownParser.parseFrontmatter(snapshotMarkdown),
          MarkdownParser.extractBody(snapshotMarkdown),
        );
        expect(parsedSnapshot.parentId, 'goal-1');
        expect(parsedSnapshot.reflection, 'Halfway.');

        final analysis = CombinedAnalysis(
          title: 'Mood and sleep',
          charts: [
            AnalysisChart(
              title: 'Trend',
              sources: [
                MetricSource(type: MetricType.mood, id: 'mood', label: 'Mood'),
              ],
            ),
          ],
        );
        final analysisMarkdown = analysis.toMarkdown();
        final parsedAnalysis = CombinedAnalysis.fromMarkdown(
          MarkdownParser.parseFrontmatter(analysisMarkdown),
          MarkdownParser.extractBody(analysisMarkdown),
        );
        expect(
          parsedAnalysis.charts.single.sources.single.type,
          MetricType.mood,
        );
      },
    );

    test('collection KPI counts JSON arrays instead of string fragments', () {
      final kpi = kpi_model.KPI(
        id: 'collection-count',
        title: 'Collection count',
        sourceType: kpi_model.KPISourceType.collectionItemCount,
        sourceId: 'collection-note',
      );
      final note = Note(
        id: 'collection-note',
        title: 'Collection',
        subtype: NoteSubtype.collection,
        body: '[{"title":"One"}, {"title":"Two"}, {"title":"Three"}]',
      );

      final value = KPIEngine.calculateKPIValue(
        kpi: kpi,
        habits: const [],
        trackerRecords: const [],
        entries: const [],
        moods: const [],
        notes: [note],
      );

      expect(value, 3);
    });

    test('collection KPI counts checked and unchecked markdown items', () {
      final kpi = kpi_model.KPI(
        id: 'markdown-collection-count',
        title: 'Markdown collection count',
        sourceType: kpi_model.KPISourceType.collectionItemCount,
        sourceId: 'markdown-note',
      );
      final note = Note(
        id: 'markdown-note',
        title: 'Markdown Collection',
        subtype: NoteSubtype.collection,
        body: '- [ ] One\n- [x] Two\n- Three',
      );

      final value = KPIEngine.calculateKPIValue(
        kpi: kpi,
        habits: const [],
        trackerRecords: const [],
        entries: const [],
        moods: const [],
        notes: [note],
      );

      expect(value, 3);
    });
  });
}
