import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/habit_model.dart';
import '../models/shared_types.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../models/people_model.dart';
import '../models/content_object.dart';
import '../providers/vault_provider.dart';
import '../services/kpi_engine.dart';
import '../models/goal_model.dart';
import '../models/project_model.dart';
import '../models/tracker_model.dart';
import '../models/sync_action.dart';
import 'notification_service.dart';
import 'markdown_parser.dart';

class AutomationService {
  static bool _updatingKpis = false;

  static Future<void> executeHabitSlotActions(
    Ref ref,
    Habit habit,
    DateTime date,
  ) async {
    for (final action in habit.actions) {
      if (action.trigger == 'slot_complete') {
        await _executeAction(ref, action, habit, date);
      }
    }
  }

  static Future<void> executeHabitActions(
    Ref ref,
    Habit habit,
    DateTime date,
  ) async {
    for (final action in habit.actions) {
      if (action.trigger == 'day_complete') {
        await _executeAction(ref, action, habit, date);
      }
    }
  }

  static Future<void> executeTrackerActions(
    dynamic ref,
    TrackerDefinition tracker,
    TrackingRecord record,
  ) async {
    for (final action in tracker.actions) {
      if (action.trigger == 'tracking_record_saved' ||
          action.trigger == 'tracker_record_saved' ||
          action.trigger == 'record_saved') {
        await _executeActionDef(ref, action, tracker.title, record.date);
      }
    }
  }

  static Future<void> _executeAction(
    Ref ref,
    ActionDef action,
    Habit habit,
    DateTime date,
  ) async {
    await _executeActionDef(ref, action, habit.displayTitle, date);
  }

  static Future<void> _executeActionDef(
    dynamic ref,
    ActionDef action,
    String sourceTitle,
    DateTime date, [
    List<VaultLinkRef>? selectedRefs,
  ]) async {
    switch (action.type) {
      case 'add_entry':
        final journalNotifier = ref.read(todayJournalProvider.notifier);
        await journalNotifier.addEntry(
          JournalEntry(
            body:
                'Acionado automaticamente após "$sourceTitle" ser concluído/atingido.',
            date: DateTime.now(),
            title: 'Registro automático',
          ),
        );
        break;

      case 'create_task':
        // Extensão não documentada na spec — mantida para retrocompatibilidade.
        final tasksNotifier = ref.read(tasksProvider.notifier);
        await tasksNotifier.addTask(
          Task(
            title: 'Acompanhamento: $sourceTitle',
            notes: [
              'Tarefa criada automaticamente após concluir/atingir a meta.',
            ],
            startDate: DateTime.now(),
            stage: TaskStage.todo,
          ),
        );
        break;

      case 'add_tracking_record':
        if (action.targetTracker != null) {
          final recordsNotifier = ref.read(trackingRecordsProvider.notifier);
          final record = TrackingRecord(
            title: 'Registro automático: $sourceTitle',
            trackerId: action.targetTracker!,
            date: DateTime.now(),
            fieldValues: {},
          );
          await recordsNotifier.addRecord(record);
        }
        break;

      case 'add_text_note':
        // Cria uma nota de texto vinculada automaticamente.
        // targetNoteTitle pode vir em action.params['title'].
        final notesNotifier = ref.read(notesProvider.notifier);
        await notesNotifier.addNote(
          Note(
            title:
                action.params?['title'] as String? ??
                'Nota automática: $sourceTitle',
            body: '',
            subtype: NoteSubtype.text,
          ),
        );
        break;

      case 'add_collection_item':
        final targetId =
            action.params?['collection_note_id']?.toString() ??
            action.params?['target_note_id']?.toString() ??
            action.params?['target_id']?.toString();
        if (targetId == null || targetId.isEmpty) {
          debugPrint('[AutomationService] add_collection_item sem destino.');
          break;
        }

        final notes = ref.read(notesProvider);
        final collection = notes.where((note) {
          return note.subtype == NoteSubtype.collection &&
              (note.id == targetId ||
                  note.slug == targetId ||
                  note.title == targetId);
        }).firstOrNull;
        if (collection == null) {
          debugPrint(
            '[AutomationService] Nota de coleção não encontrada: $targetId',
          );
          break;
        }

        final itemText =
            action.params?['item']?.toString().trim().isNotEmpty == true
            ? action.params!['item'].toString().trim()
            : sourceTitle;
        final nextBody = [
          collection.body.trimRight(),
          if (collection.body.trim().isNotEmpty) '',
          '- $itemText',
        ].join('\n');
        await ref
            .read(notesProvider.notifier)
            .updateNote(collection.copyWith(body: nextBody));
        break;

      case 'view_statistics':
      case 'view_item':
        // Ações de navegação pura — devem ser tratadas na camada de UI via
        // callback de navegação injetado. AutomationService não conhece o
        // contexto de roteamento; registrar apenas para rastreamento.
        debugPrint(
          '[AutomationService] ${action.type}: destino=${action.params?["target_id"]}',
        );
        break;

      case 'launch_url':
        final url = action.params?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              debugPrint('[AutomationService] launch_url falhou: $url');
            }
          }
        }
        break;

      case 'link_item':
        if (selectedRefs != null && selectedRefs.isNotEmpty && sourceTitle.isNotEmpty) {
          final habits = ref.read(habitsProvider);
          final habit = habits
              .where((h) => h.displayTitle == sourceTitle || h.title == sourceTitle)
              .firstOrNull;
          if (habit != null) {
            await _persistLinkedRefs(ref, habit, date, selectedRefs);
          }
        }
        break;
    }
  }

  static Future<void> persistLinkedRefsPublic(
    dynamic ref,
    Habit habit,
    DateTime date,
    List<VaultLinkRef> refs,
  ) =>
      _persistLinkedRefs(ref, habit, date, refs);

  static Future<void> _persistLinkedRefs(
    dynamic ref,
    Habit habit,
    DateTime date,
    List<VaultLinkRef> refs,
  ) async {
    final dateStr = date.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);
    final dayThemes = ref.read(dayThemesProvider);

    try {
      final path = 'daily/$dateStr.md';
      final content =
          await obsidianService.readFile(path) ??
          getDailyNoteTemplate(
            dateStr,
            dayThemes,
            activeHabits: ref
                .read(habitsProvider)
                .where((h) => h.status == HabitStatus.active)
                .toList(),
          );

      final frontmatter = MarkdownParser.parseFrontmatter(content);
      final body = MarkdownParser.extractBody(content);
      frontmatter['${habit.slug}__links'] =
          refs.map((r) => r.toWikiLink()).toList();

      final entries = MarkdownParser.parseJournalEntries(body, dateStr);
      final tasks = MarkdownParser.parseTasksFromDailyNote(body);
      final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
      final pomodoros = MarkdownParser.parsePomodoros(body);
      final habitsMap = MarkdownParser.parseHabitCompletions(frontmatter);

      frontmatter.remove('habits');
      habitsMap.forEach((slug, value) {
        frontmatter[slug] = value;
      });

      final newBody = MarkdownParser.generateDailyNoteBody(
        entries: entries,
        tasks: tasks,
        habits: habitsMap,
        trackers: trackers,
        pomodoros: pomodoros,
      );

      await obsidianService.writeFile(
        path,
        generateMarkdown(frontmatter, newBody),
      );

      await syncQueue.enqueueAction(
        SyncAction(
          objectType: 'daily_note',
          objectId: dateStr,
          operation: SyncOperation.update,
          payload: frontmatter,
        ),
      );
    } catch (e, st) {
      debugPrint('[AutomationService] _persistLinkedRefs failed: $e\n$st');
    }
  }

  static Future<void> checkPersonContacts(Ref ref, List<Person> people) async {
    final tasks = ref.read(tasksProvider);
    final entries = ref.read(allEntriesProvider);
    final now = DateTime.now();

    // Pre-calculate latest contact date for each person slug to avoid O(N * M) string contains searches
    final latestContactMap = <String, DateTime>{};

    void updateLatest(String slug, DateTime date) {
      final existing = latestContactMap[slug];
      if (existing == null || date.isAfter(existing)) {
        latestContactMap[slug] = date;
      }
    }

    for (final entry in entries) {
      final links = MarkdownParser.extractWikiLinks(entry.body);
      for (final slug in links) {
        updateLatest(slug, entry.date);
      }
      for (final org in entry.organizers) {
        updateLatest(org.slug, entry.date);
      }
    }

    for (final task in tasks) {
      if (task.stage == TaskStage.finalized) {
        for (final note in task.notes) {
          final links = MarkdownParser.extractWikiLinks(note);
          for (final slug in links) {
            updateLatest(slug, task.updatedAt);
          }
        }
        for (final org in task.organizers) {
          updateLatest(org.slug, task.updatedAt);
        }
      }
    }

    for (final person in people) {
      // Yield control to the event loop to prevent ANR and allow UI to render
      await Future.delayed(Duration.zero);

      final latestContact = latestContactMap[person.slug];
      final effectivePerson =
          latestContact != null &&
                  (person.lastContactDate == null ||
                      latestContact.isAfter(person.lastContactDate!))
              ? person.copyWith(lastContactDate: latestContact)
              : person;

      if (effectivePerson.lastContactDate != person.lastContactDate) {
        await ref.read(peopleProvider.notifier).updatePerson(effectivePerson);
      }

      if (_isDueForContact(effectivePerson, now)) {
        final taskTitle = 'Contact ${person.title}';

        final exists = tasks.any(
          (task) =>
              task.stage != TaskStage.finalized &&
              !task.archived &&
              (task.title.toLowerCase() == taskTitle.toLowerCase() ||
                  (task.title.toLowerCase().contains('contact') &&
                      task.title.toLowerCase().contains(
                            person.title.toLowerCase(),
                          )) ||
                  task.organizers.any(
                    (organizer) =>
                        organizer.type == 'person' &&
                        (organizer.slug == person.slug ||
                            organizer.slug == person.id),
                  )),
        );
        if (!exists) {
          final tasksNotifier = ref.read(tasksProvider.notifier);
          await tasksNotifier.addTask(
            Task(
              id: 'contact_${person.id}_${now.millisecondsSinceEpoch}',
              title: taskTitle,
              notes: [
                'Automatically created from this person contact frequency.',
              ],
              startDate: now,
              priority: person.contactPriority,
              stage: TaskStage.todo,
              endDate: now,
              organizers: [
                OrganizerReference(
                  type: 'person',
                  slug: person.slug,
                  title: person.title,
                ),
              ],
            ),
          );
        }
      }
    }
  }

  static bool _isDueForContact(Person person, DateTime now) {
    final frequency = person.contactFrequency;
    if (frequency == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final lastContact = person.lastContactDate;
    if (lastContact == null) return true;
    final lastDate = DateTime(
      lastContact.year,
      lastContact.month,
      lastContact.day,
    );
    final dueDate = lastDate.add(frequency);
    return !dueDate.isAfter(today);
  }

  static Future<void> checkPactExpirations(Ref ref, List<Habit> habits) async {
    final now = DateTime.now();
    final expiredPacts = habits
        .where(
          (h) =>
              h.habitMode == HabitMode.pact &&
              h.status == HabitStatus.active &&
              h.endsAt != null &&
              !h.endsAt!.isAfter(now) &&
              h.pactOutcome == null,
        )
        .toList();

    if (expiredPacts.isEmpty) return;

    final notificationService = NotificationService();
    for (final pact in expiredPacts) {
      debugPrint('[PactChecker] Pacto vencido encontrado: ${pact.title}');
      await notificationService.showImmediateNotification(
        id: pact.id.hashCode,
        title: 'Pacto Expirado: ${pact.displayTitle}',
        body: 'Seu pacto expirou e precisa de revisão (Steering Sheet).',
        payload: 'steering_sheet?id=${pact.id}',
      );
    }
  }

  static Future<void> updateAllKPIs(Ref ref) async {
    if (_updatingKpis) return;
    _updatingKpis = true;
    try {
      final goals = ref.read(goalsProvider);
      final projects = ref.read(projectsProvider);
      final habits = ref.read(habitsProvider);
      final trackers = ref.read(trackingRecordsProvider);
      final entries = ref.read(allEntriesProvider);
      final moods = ref.read(moodsProvider);
      final notes = ref.read(notesProvider);
      final tasks = ref.read(tasksProvider);

      for (final goal in goals) {
        bool goalChanged = false;
        for (final kpi in goal.kpis) {
          final newValue = KPIEngine.calculateKPIValue(
            kpi: kpi,
            habits: habits,
            trackerRecords: trackers,
            entries: entries,
            moods: moods,
            notes: notes,
            tasks: tasks,
          );
          if (kpi.currentValue != newValue) {
            kpi.currentValue = newValue;
            goalChanged = true;
          }
          if (!kpi.completed && newValue >= kpi.targetValue) {
            kpi.completed = true;
            goalChanged = true;
            await NotificationService().showImmediateNotification(
              id: kpi.id.hashCode.abs() % 1000000,
              title: 'KPI atingido',
              body:
                  '${kpi.title}: ${newValue.toStringAsFixed(0)} / ${kpi.targetValue.toStringAsFixed(0)}',
            );
            if (kpi.autoComplete && kpi.autoCompleteAction != null) {
              try {
                final action = ActionDef.fromJson(kpi.autoCompleteAction!);
                await _executeActionDef(ref, action, kpi.title, DateTime.now());
              } catch (e) {
                debugPrint('Falha ao executar ação automática do KPI: $e');
              }
            }
          }
        }
        if (goalChanged) {
          await ref.read(goalsProvider.notifier).updateGoal(goal);
          await checkKPIGoals(ref, goal);
        }
      }

      // Update KPIs for projects
      for (final project in projects) {
        if (project.projectState != ProjectState.active) continue;
        
        bool projectChanged = false;
        for (final kpi in project.kpis) {
          final newValue = KPIEngine.calculateKPIValue(
            kpi: kpi,
            habits: habits,
            trackerRecords: trackers,
            entries: entries,
            moods: moods,
            notes: notes,
            tasks: tasks,
          );
          if (kpi.currentValue != newValue) {
            kpi.currentValue = newValue;
            projectChanged = true;
          }
          if (!kpi.completed && newValue >= kpi.targetValue) {
            kpi.completed = true;
            projectChanged = true;
            await NotificationService().showImmediateNotification(
              id: kpi.id.hashCode.abs() % 1000000,
              title: 'Project KPI atingido',
              body:
                  '${project.title} - ${kpi.title}: ${newValue.toStringAsFixed(0)} / ${kpi.targetValue.toStringAsFixed(0)}',
            );
            if (kpi.autoComplete && kpi.autoCompleteAction != null) {
              try {
                final action = ActionDef.fromJson(kpi.autoCompleteAction!);
                await _executeActionDef(ref, action, kpi.title, DateTime.now());
              } catch (e) {
                debugPrint('Falha ao executar ação automática do KPI: $e');
              }
            }
          }
        }
        if (projectChanged) {
          await ref.read(projectsProvider.notifier).updateProject(project);
          // Check if all KPIs are met to complete the project
          if (project.kpis.isNotEmpty && project.kpis.every((k) => k.completed)) {
            project.projectState = ProjectState.completed;
            await ref.read(projectsProvider.notifier).updateProject(project);
            await NotificationService().showImmediateNotification(
              id: project.id.hashCode.abs() % 1000000,
              title: 'Projeto completado',
              body: 'Todos os KPIs do projeto "${project.title}" foram atingidos!',
            );
          }
        }
      }
    } finally {
      _updatingKpis = false;
    }
  }

  static Future<void> checkKPIGoals(Ref ref, Goal goal) async {
    if (goal.state != GoalStatus.active) return;

    if (goal.kpis.isNotEmpty &&
        goal.kpis.every(
          (k) => k.completed || k.currentValue >= k.targetValue,
        )) {
      await NotificationService().showImmediateNotification(
        id: goal.id.hashCode,
        title: 'KPIs atingidos',
        body:
            'Todos os KPIs de "${goal.title}" foram atingidos. Revise a meta para concluir.',
      );
    }
  }
}
