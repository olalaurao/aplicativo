import 'package:quartzo/models/habit_model.dart';
import 'package:quartzo/models/analysis_model.dart';
import 'package:quartzo/models/journal_entry.dart';

import 'package:quartzo/models/goal_model.dart';
import 'package:quartzo/models/mood_model.dart';
import 'package:quartzo/models/note_model.dart';
import 'package:quartzo/models/organizer_model.dart';
import 'package:quartzo/models/people_model.dart';
import 'package:quartzo/models/pillar_model.dart';
import 'package:quartzo/models/project_model.dart';
import 'package:quartzo/models/reminder_model.dart';
import 'package:quartzo/models/resource_model.dart';
import 'package:quartzo/models/shared_types.dart';
import 'package:quartzo/models/snapshot_model.dart';
import 'package:quartzo/models/social_post.dart';
import 'package:quartzo/models/task_model.dart';
import 'package:quartzo/models/relay_step.dart';
import 'package:quartzo/models/tracker_model.dart';
import 'package:quartzo/models/kpi_model.dart' as kpi_model;
import 'package:quartzo/models/dashboard_block.dart';
import 'package:quartzo/models/content_object.dart';
import 'package:quartzo/providers/settings_provider.dart';
import 'package:quartzo/providers/widget_sync_provider.dart' show buildCalendarSnapshotForTest, buildFilterSnapshotForTest;
import 'package:quartzo/services/markdown_parser.dart';
import 'package:quartzo/services/kpi_engine.dart';
import 'package:quartzo/services/project_hierarchy_service.dart';
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
      final parsed = OrganizerReference.fromWikiLink(
        reference.toWikiLink(),
        defaultType: 'project',
      );

      // Typed references serialize as [[type/slug]] per spec
      expect(reference.toWikiLink(), '[[project/launch]]');
      expect(parsed.type, 'project');
      expect(parsed.slug, 'launch');
    });

    test('relay steps preserve labels in roundtrip', () {
      final task = Task(
        title: 'Task with steps',
        relaySteps: [
          RelayStep(label: 'Custom Step 1', durationMinutes: 25),
          RelayStep(label: 'Another Step', durationMinutes: 5),
        ],
      );
      final md = task.toMarkdown();
      final parsed = Task.fromMarkdown(
        MarkdownParser.parseFrontmatter(md),
        MarkdownParser.extractBody(md),
      );
      
      expect(parsed.relaySteps, isNotNull);
      expect(parsed.relaySteps!.length, 2);
      expect(parsed.relaySteps![0].label, 'Custom Step 1');
      expect(parsed.relaySteps![1].label, 'Another Step');
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
          habitLabels: const {'hydrate': 'Hydrate'},
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
        expect(body, contains('- [x] Hydrate (3)'));
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
          ),
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
      expect(
        parsed.previousCycles.first.reflection,
        'Went great, learned a lot.',
      );
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

    test('TrackingRecord preserves boolean checkbox values', () {
      final record = TrackingRecord(
        title: 'Daily Meds',
        trackerId: 'meds',
        date: DateTime(2026, 7, 27),
        fieldValues: {
          'took_vitamins': true,
          'had_headache': false,
          'notes': 'Felt good',
        },
      );

      final markdown = record.toMarkdown();
      final parsed = TrackingRecord.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.trackerId, 'meds');
      expect(parsed.fieldValues['took_vitamins'], isTrue);
      expect(parsed.fieldValues['had_headache'], isFalse);
      expect(parsed.fieldValues['notes'], 'Felt good');
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
      expect(parsedProject.projectPriority, TaskPriority.high);
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
          mediaType: 'Book',
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
          color: '#66AA77',
          order: 4,
          quadrant: MoodQuadrant.green,
          pleasantness: 4,
          energy: 4,
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
        sourceType: kpi_model.KPISourceType.collection,
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
        allObjects: [note],
      );

      expect(value, 3);
    });

    test('collection KPI counts checked and unchecked markdown items', () {
      final kpi = kpi_model.KPI(
        id: 'markdown-collection-count',
        title: 'Markdown collection count',
        sourceType: kpi_model.KPISourceType.collection,
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
        allObjects: [note],
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
        type: BlockType.custom,
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

    test('project preserves parentId in roundtrip', () {
      final project = Project(
        id: 'project-1',
        title: 'Parent Project',
        parentId: 'project-parent',
        description: 'Test project with parent',
        hierarchyCombinationMode: 'weighted',
      );

      final markdown = project.toMarkdown();
      final parsed = Project.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.id, project.id);
      expect(parsed.title, project.title);
      expect(parsed.parentId, project.parentId);
      expect(parsed.description, project.description);
      expect(parsed.hierarchyCombinationMode, project.hierarchyCombinationMode);
    });

    test('kpi with childProjects source type preserves fields in roundtrip', () {
      final kpi = kpi_model.KPI(
        id: 'kpi-1',
        title: 'Subproject Progress',
        sourceType: kpi_model.KPISourceType.childProjects,
        sourceId: 'project-parent',
        targetValue: 100,
        currentValue: 75,
      );

      final markdown = kpi.toMap();
      final parsed = kpi_model.KPI.fromMap(markdown);

      expect(parsed.id, kpi.id);
      expect(parsed.title, kpi.title);
      expect(parsed.sourceType, kpi_model.KPISourceType.childProjects);
      expect(parsed.sourceId, kpi.sourceId);
      expect(parsed.targetValue, kpi.targetValue);
      expect(parsed.currentValue, kpi.currentValue);
    });

    test('project hierarchy service calculates correct descendant progress', () {
      final parentProject = Project(
        id: 'project-parent',
        title: 'Parent',
        taskLinks: ['task-1'],
      );
      
      final childProject1 = Project(
        id: 'project-child-1',
        title: 'Child 1',
        parentId: 'project-parent',
        taskLinks: ['task-2', 'task-3'],
      );
      
      final childProject2 = Project(
        id: 'project-child-2',
        title: 'Child 2',
        parentId: 'project-parent',
        taskLinks: ['task-4'],
      );

      final tasks = [
        Task(id: 'task-1', title: 'Task 1', stage: TaskStage.finalized),
        Task(id: 'task-2', title: 'Task 2', stage: TaskStage.finalized),
        Task(id: 'task-3', title: 'Task 3', stage: TaskStage.inProgress),
        Task(id: 'task-4', title: 'Task 4', stage: TaskStage.finalized),
      ];

      final allProjects = [parentProject, childProject1, childProject2];
      final allObjects = [...allProjects, ...tasks] as List<ContentObject>;

      // Test getting children
      final children = ProjectHierarchyService.getChildProjects(
        'project-parent',
        allProjects,
      );
      expect(children, hasLength(2));
      expect(children.map((p) => p.id).toSet(), containsAll(['project-child-1', 'project-child-2']));

      // Test hierarchical progress calculation
      final hierarchicalProgress = ProjectHierarchyService.calculateHierarchicalProgress(
        parentProject,
        allProjects,
        tasks,
        combinationMode: 'simple',
      );

      // Parent has 1/1 = 100%, Child1 has 1/2 = 50%, Child2 has 1/1 = 100%
      // Simple average: (1.0 + 0.5 + 1.0) / 3 = 0.833
      expect(hierarchicalProgress, closeTo(0.833, 0.01));
    });

    test('cycle detection prevents infinite loops', () {
      final projectA = Project(id: 'project-a', title: 'Project A');
      final projectB = Project(id: 'project-b', title: 'Project B');
      final allProjects = [projectA, projectB];

      // A cannot be parent of itself
      expect(
        ProjectHierarchyService.detectCycle('project-a', 'project-a', allProjects),
        isTrue,
      );

      // A → B is fine
      expect(
        ProjectHierarchyService.detectCycle('project-b', 'project-a', allProjects),
        isFalse,
      );

      // B → A would create cycle A → B → A (simulated by setting parentId)
      expect(
        ProjectHierarchyService.detectCycle('project-a', 'project-b', allProjects),
        isFalse,
      );
    });

    test('legacy projects without parentId still work', () {
      final legacyProject = Project(
        id: 'project-legacy',
        title: 'Legacy Project',
        // No parentId field
        // No hierarchyCombinationMode field
      );

      final markdown = legacyProject.toMarkdown();
      final parsed = Project.fromMarkdown(
        MarkdownParser.parseFrontmatter(markdown),
        MarkdownParser.extractBody(markdown),
      );

      expect(parsed.id, legacyProject.id);
      expect(parsed.title, legacyProject.title);
      expect(parsed.parentId, isNull); // Should be null for legacy projects
      expect(parsed.hierarchyCombinationMode, isNull); // Should be null for legacy projects
    });
  });
}
