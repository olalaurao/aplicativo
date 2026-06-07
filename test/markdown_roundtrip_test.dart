import 'package:citrine/models/habit_model.dart';
import 'package:citrine/models/analysis_model.dart';
import 'package:citrine/models/journal_entry.dart';

import 'package:citrine/models/goal_model.dart';
import 'package:citrine/models/mood_model.dart';
import 'package:citrine/models/note_model.dart';
import 'package:citrine/models/organizer_model.dart';
import 'package:citrine/models/people_model.dart';
import 'package:citrine/models/project_model.dart';
import 'package:citrine/models/reminder_model.dart';
import 'package:citrine/models/resource_model.dart';
import 'package:citrine/models/shared_types.dart';
import 'package:citrine/models/snapshot_model.dart';
import 'package:citrine/models/social_post.dart';
import 'package:citrine/models/task_model.dart';
import 'package:citrine/models/tracker_model.dart';
import 'package:citrine/models/kpi_model.dart' as kpi_model;
import 'package:citrine/models/dashboard_block.dart';
import 'package:citrine/providers/settings_provider.dart';
import 'package:citrine/providers/widget_sync_provider.dart';
import 'package:citrine/services/markdown_parser.dart';
import 'package:citrine/services/kpi_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

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
      final reference = OrganizerReference(
        type: 'project',
        slug: 'launch',
        title: 'Launch',
      );
      final parsed = OrganizerReference.fromWikiLink(reference.toWikiLink());

      expect(reference.toWikiLink(), '[[project/launch]]');
      expect(parsed.type, 'project');
      expect(parsed.slug, 'launch');
    });

    test('type signatures match wiki-link category list values', () {
      final signature = TypeSignature(
        objectType: 'habit',
        markerType: MarkerType.property,
        markerValue: 'categoria:[[habits]]',
      );

      expect(
        MarkdownParser.matchesSignature(
          {
            'categoria': ['[[notes]]', '[[habits]]'],
          },
          '',
          'notes/meditar.md',
          signature,
        ),
        isTrue,
      );
    });

    test('folder signatures match normalized organizer paths', () {
      final signature = TypeSignature(
        objectType: 'area',
        markerType: MarkerType.folder,
        markerValue: '01/',
      );

      expect(
        MarkdownParser.matchesSignature(
          const {},
          '',
          '01/carreira.md',
          signature,
        ),
        isTrue,
      );
      expect(
        MarkdownParser.prepareForSave(
          Organizer(title: 'Carreira', organizerType: OrganizerType.area),
          signature,
          defaultFolder: 'organizers/areas',
        )['path'],
        '01/carreira.md',
      );
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

    test('daily journal heading keeps fixed file date and heading time', () {
      const body = '''
## Journal Entries

### 08:30
Entrada antiga.
mood:: [[good]]
organizers:: [[health]]

---
''';

      final entries = MarkdownParser.parseJournalEntries(body, '2026-05-20');

      expect(entries, hasLength(1));
      expect(
        DateTime.parse(entries.single['date'] as String),
        DateTime(2026, 5, 20, 8, 30),
      );
      expect(entries.single['time'], '08:30');
      expect(entries.single['body'], 'Entrada antiga.');
    });

    test(
      'editing journal body preserves original date when date is reused',
      () {
        const body = '''
## Journal Entries

### 08:30 - Morning
Texto original.

---
''';

        final entries = MarkdownParser.parseJournalEntries(body, '2026-05-20');
        final originalDate = DateTime.parse(entries.single['date'] as String);
        final edited = JournalEntry(
          id: 'entry-1',
          title: 'Morning',
          body: 'Texto editado.',
          date: originalDate,
        ).copyWith(body: 'Texto editado.');

        expect(edited.date, DateTime(2026, 5, 20, 8, 30));
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

    test('habit preserves pact fields and previous cycles', () {
      final pact = Habit(
        title: 'Exercise',
        color: '#FF9500',
        dailyGoal: 1,
        habitMode: HabitMode.pact,
        statement: 'I will exercise daily',
        curiosityQuestion: 'How does it affect energy?',
        hypothesis: 'Exercising daily improves afternoon energy levels',
        startedAt: DateTime(2026, 6, 1),
        endsAt: DateTime(2026, 6, 30),
        pactOutcome: PactOutcome.persist,
        previousCycles: [
          PactCycle(
            startedAt: DateTime(2026, 5, 1),
            endsAt: DateTime(2026, 5, 31),
            outcome: PactOutcome.persist,
            reflection: 'Went great, learned a lot.',
            hypothesisCorrect: true,
            endedReason: 'goal_achieved',
          )
        ],
      );

      final markdown = pact.toMarkdown();
      final parsed = Habit.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.habitMode, HabitMode.pact);
      expect(parsed.statement, pact.statement);
      expect(parsed.curiosityQuestion, pact.curiosityQuestion);
      expect(parsed.hypothesis, pact.hypothesis);
      expect(parsed.startedAt, pact.startedAt);
      expect(parsed.endsAt, pact.endsAt);
      expect(parsed.pactOutcome, PactOutcome.persist);
      expect(parsed.previousCycles, hasLength(1));
      expect(parsed.previousCycles.first.reflection, 'Went great, learned a lot.');
      expect(parsed.previousCycles.first.hypothesisCorrect, isTrue);
      expect(parsed.previousCycles.first.endedReason, 'goal_achieved');
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

    test('combined analysis writes nested tracker sources as valid YAML', () {
      final analysis = CombinedAnalysis(
        title: 'Menstruação',
        dataSources: [
          MetricSource(
            type: MetricType.trackerField,
            id: '23f14f0e-b575-4e47-b8ff-cc05bbc38eb2',
            label: 'menstruação: fluxo',
            fieldId: 'field_1',
            color: const Color(0xffef4444),
          ),
        ],
        charts: [
          AnalysisChart(
            title: 'Gráfico Comparativo',
            sources: [
              MetricSource(
                type: MetricType.trackerField,
                id: '23f14f0e-b575-4e47-b8ff-cc05bbc38eb2',
                label: 'menstruação: fluxo',
                fieldId: 'field_1',
                color: const Color(0xffef4444),
              ),
            ],
          ),
        ],
      );

      final markdown = analysis.toMarkdown();
      final frontmatter = MarkdownParser.parseFrontmatter(markdown);
      final parsed = CombinedAnalysis.fromMarkdown(
        frontmatter,
        MarkdownParser.extractBody(markdown),
      );

      expect(markdown, contains('sources:'));
      expect(markdown, isNot(contains('sources: [{')));
      expect(parsed.dataSources.single.label, 'menstruação: fluxo');
      expect(parsed.dataSources.single.color?.toARGB32(), 0xffef4444);
    });

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

    test('widget snapshots keep internal ids out of display fields', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final organizer = Organizer(
        id: 'area-health',
        title: 'Saúde',
        organizerType: OrganizerType.area,
      );
      final habit = Habit(
        id: uuid,
        title: 'Beber água',
        color: '#4D9DE0',
        organizers: [
          OrganizerReference(
            type: 'area',
            slug: organizer.slug,
            title: organizer.title,
          ),
        ],
      );
      final block = DashboardBlock(
        id: 'home-area',
        type: BlockType.organizerSummary,
        title: 'Filtro',
        order: 0,
        metadata: {
          'organizerSlug': organizer.slug,
          'filterObjectTypes': ['habit'],
        },
      );

      final filter = buildFilterSnapshotForTest([organizer, habit], [block]);
      final rows = filter['items'] as List;
      final row = rows.single as Map<String, dynamic>;

      expect(row['id'], uuid);
      expect(row['title'], 'Beber água');
      expect(row['subtitle'], 'Saúde');
      expect(row['title'], isNot(contains(uuid)));
      expect(row['subtitle'], isNot(contains(uuid)));
      expect(filter['organizer'], isNot(contains(uuid)));
    });

    test('calendar widget day snapshot displays habit title, not id', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final habit = Habit(id: uuid, title: 'Beber água', color: '#4D9DE0');
      final snapshot = buildCalendarSnapshotForTest(
        [habit],
        AppSettings(vaultName: 'Test', calendarWidgetType: 'day'),
        const [],
        0,
      );
      final items = snapshot['items'] as List;
      final row = items.single as Map<String, dynamic>;

      expect(row['id'], uuid);
      expect(row['title'], 'Beber água');
      expect(row['title'], isNot(contains(uuid)));
    });

    test(
      'widget snapshots replace technical title fallback with human text',
      () {
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        final habit = Habit(id: uuid, title: uuid, color: '#4D9DE0');
        final snapshot = buildCalendarSnapshotForTest(
          [habit],
          AppSettings(vaultName: 'Test', calendarWidgetType: 'day'),
          const [],
          0,
        );
        final row = (snapshot['items'] as List).single as Map<String, dynamic>;

        expect(row['id'], uuid);
        expect(row['title'], 'Sem título');
        expect(row['title'], isNot(contains(uuid)));
      },
    );

    test('calendar widget snapshot resolves organizer ids for habits', () {
      const organizerId = '1a915725634c42e8979d94d631c95886';
      final organizer = Organizer(
        id: organizerId,
        title: 'Saúde',
        organizerType: OrganizerType.area,
      );
      final habit = Habit(
        id: 'habit-venlafaxina',
        title: 'venlafaxina',
        color: '#4D9DE0',
        organizers: [
          OrganizerReference(
            type: 'area',
            slug: organizerId,
            title: organizerId,
          ),
        ],
      );
      final snapshot = buildCalendarSnapshotForTest(
        [organizer, habit],
        AppSettings(vaultName: 'Test', calendarWidgetType: 'day'),
        const [],
        0,
      );
      final row = (snapshot['items'] as List).single as Map<String, dynamic>;

      expect(row['id'], 'habit-venlafaxina');
      expect(row['title'], 'venlafaxina');
      expect(row['subtitle'], 'Saúde');
      expect(row['subtitle'], isNot(contains(organizerId)));
    });

    test('social posts read Pinterest image aliases from frontmatter', () {
      final parsed = SocialPost.fromMarkdown(const {
        'title': 'Pin salvo',
        'url': 'https://br.pinterest.com/pin/123/',
        'platform': 'pinterest',
        'image': 'https://i.pinimg.com/originals/pin.jpg',
      }, '');

      expect(parsed.platform, SocialPlatform.pinterest);
      expect(parsed.thumbnailUrl, 'https://i.pinimg.com/originals/pin.jpg');
    });

    test('social posts rebuild Pinterest embed for old saved pins', () {
      final parsed = SocialPost.fromMarkdown(const {
        'title': 'Pin antigo',
        'url': 'https://br.pinterest.com/pin/123456789/',
        'platform': 'pinterest',
      }, '');

      expect(parsed.embedUrl, contains('assets.pinterest.com/ext/embed.html'));
      expect(parsed.embedUrl, contains('123456789'));
    });

    test('filter widget snapshot uses saved widget settings', () {
      final organizer = Organizer(
        id: 'area-work',
        title: 'Trabalho',
        organizerType: OrganizerType.area,
      );
      final habit = Habit(
        id: 'habit-water',
        title: 'Beber água',
        color: '#4D9DE0',
        organizers: [
          OrganizerReference(
            type: 'area',
            slug: organizer.slug,
            title: organizer.title,
          ),
        ],
      );
      final task = Task(
        id: 'task-report',
        title: 'Relatório',
        organizers: [
          OrganizerReference(
            type: 'area',
            slug: organizer.slug,
            title: organizer.title,
          ),
        ],
      );

      final filter = buildFilterSnapshotForTest(
        [organizer, habit, task],
        const [],
        AppSettings(
          vaultName: 'Test',
          universalWidgetOrganizer: organizer.slug,
          universalWidgetObjectTypes: const ['habit'],
        ),
      );
      final rows = filter['items'] as List;

      expect(filter['organizer'], 'Trabalho');
      expect(rows, hasLength(1));
      expect((rows.single as Map<String, dynamic>)['title'], 'Beber água');
    });
  });
}
