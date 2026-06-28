import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/habit_model.dart';
import '../models/shared_types.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../models/people_model.dart';
import '../providers/vault_provider.dart';
import '../services/kpi_engine.dart';
import '../models/goal_model.dart';
import '../models/tracker_model.dart';
import 'notification_service.dart';

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
    DateTime date,
  ) async {
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
    }
  }

  static Future<void> checkPersonContacts(Ref ref, List<Person> people) async {
    final tasks = ref.read(tasksProvider);
    final entries = ref.read(allEntriesProvider);
    final now = DateTime.now();

    for (final person in people) {
      final latestContact = _latestContactFromBacklinks(person, entries, tasks);
      final effectivePerson =
          latestContact != null &&
              (person.lastContactDate == null ||
                  latestContact.isAfter(person.lastContactDate!))
          ? person.copyWith(lastContactDate: latestContact)
          : person;
      if (effectivePerson.id == person.id &&
          effectivePerson.lastContactDate != person.lastContactDate) {
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

  static DateTime? _latestContactFromBacklinks(
    Person person,
    List<JournalEntry> entries,
    List<Task> tasks,
  ) {
    final wiki = '[[${person.slug}]]';
    DateTime? latest;

    void include(DateTime date) {
      if (latest == null || date.isAfter(latest!)) latest = date;
    }

    for (final entry in entries) {
      final mentionsPerson =
          entry.body.contains(wiki) ||
          entry.organizers.any((org) => org.slug == person.slug);
      if (mentionsPerson) include(entry.date);
    }

    for (final task in tasks) {
      final mentionsPerson =
          task.notes.any((note) => note.contains(wiki)) ||
          task.organizers.any((org) => org.slug == person.slug);
      if (mentionsPerson && task.stage == TaskStage.finalized) {
        include(task.updatedAt);
      }
    }

    return latest;
  }

  static Future<void> updateAllKPIs(Ref ref) async {
    if (_updatingKpis) return;
    _updatingKpis = true;
    try {
      final goals = ref.read(goalsProvider);
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
            if (kpi.autoCompleteAction != null) {
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
