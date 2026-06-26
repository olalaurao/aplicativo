# Auditoria de cobertura do gap-analysis

- Total de itens auditados: **120**
- Feitos: **8**
- Parciais: **80**
- Faltando: **24**
- Dependem de decisão: **8**

## Critério

- `feito`: arquivo(s) existem e há evidência forte dos símbolos/estruturas pedidas.
- `parcial`: arquivo(s) existem, mas a comprovação automática é incompleta ou só parte do pedido está presente.
- `faltando`: arquivo(s) pedidos não existem ou não há base objetiva mínima.
- `decisão`: o próprio item é uma decisão de produto/arquitetura, não apenas implementação.

## Itens

### 0.1 — HABIT: ADICIONAR TODO O SUBSISTEMA PACT
- Status: **parcial**
- Arquivos: `lib/models/habit_model.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (2/5).

### 0.2 — TASK: ADICIONAR CLASSE TripleCheck
- Status: **parcial**
- Arquivos: `lib/models/task_model.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (9/16).

### 0.3 — DECISÃO DE PRODUTO: Idea / Inbox / Event / ShoppingList (tipos fora
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.

### 1.1 — ESTRUTURA DE PASTAS: `app/` FLAT COMO PADRÃO (não pasta-por-tipo)
- Status: **parcial**
- Arquivos: `lib/services/obsidian_service.dart`, `lib/providers/vault_provider.dart`, `lib/services/dataview_generator.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (3/60).

### 1.2 — PMN (`daily/YYYY-MM-WNN.md`) É INVISÍVEL AO APP
- Status: **feito**
- Arquivos: `lib/providers/vault_provider.dart`, `lib/services/markdown_parser.dart`, `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem e há forte presença de símbolos esperados (25/33).

### 1.3 — FIELD NOTE / PMN: entry_type NUNCA É LIDO PELO PARSER PRINCIPAL
- Status: **parcial**
- Arquivos: `lib/services/markdown_parser.dart`, `lib/models/journal_entry.dart`, `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (14/60).

### 1.4 — `type: system` E `type: calendar_session` AUSENTES DO DISPATCHER
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (4/11).

### 1.5 — HABIT COMPLETIONS: CHAVES PLANAS NO FRONTMATTER, NÃO ANINHADAS SOB
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`, `lib/services/markdown_parser.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/14).

### 1.6 — DAILY NOTE TEMPLATE NÃO GERA O FORMATO CANÔNICO
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/8).

### 1.7 — IDs DE OBJETOS SÃO UUID ALEATÓRIO; WIKILINKS DEVEM USAR SLUG ESTÁVEL
- Status: **decisão**
- Arquivos: `lib/models/content_object.dart`
- Evidência: Item explicitamente marcado como decisão de produto.

### 1.8 — OrganizerReference.toWikiLink() GRAVA "[[tipo/slug]]" EM VEZ DE
- Status: **parcial**
- Arquivos: `lib/models/shared_types.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (1/9).

### 2.1 — PomodoroSession NÃO PERSISTE EM LUGAR NENHUM
- Status: **parcial**
- Arquivos: `lib/models/pomodoro_session.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/2).

### 2.2 — KPI: TAXONOMIA INCOMPATÍVEL; FALTA AUTO-COMPLETE E BOTÃO "+N"
- Status: **parcial**
- Arquivos: `lib/models/kpi_model.dart`, `lib/services/kpi_engine.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (9/40).

### 2.13 — SISTEMA DE ACTIONS: SÓ 2 DOS 7 TIPOS DA SPEC ESTÃO IMPLEMENTADOS;
- Status: **parcial**
- Arquivos: `lib/services/automation_service.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (8/20).

### 2.14 — INCONSISTÊNCIA DE IDIOMA: STRINGS EM INGLÊS MISTURADAS COM O RESTO
- Status: **parcial**
- Arquivos: `lib/services/automation_service.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/9).

### 2.15 — `checkKPIGoals()` AUTO-COMPLETA O GOAL INTEIRO QUANDO TODOS OS KPIs
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.

### 2.3 — DASHBOARD: FALTA PAINEL pact_today; dashboard_panel.dart MORTO
- Status: **parcial**
- Arquivos: `lib/models/dashboard_block.dart`, `lib/models/dashboard_panel.dart`
- Evidência: Arquivo ainda existe apesar da ação ser DELETE.

### 2.4 — COMBINED ANALYSIS: CAMPOS FALTANDO; FALTA BLOCO DO PLUGIN OBSIDIAN
- Status: **parcial**
- Arquivos: `lib/models/analysis_model.dart`, `lib/services/dataview_generator.dart`, `lib/providers/vault_provider.dart`, `lib/models/analysis_model.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (30/80).

### 2.5 — CONFLICT DETECTION (OBJECT IDENTIFICATION) NÃO EXISTE
- Status: **feito**
- Arquivos: `lib/ui/screens/object_conflicts_screen.dart`
- Evidência: Arquivo solicitado para criação existe.

### 2.6 — COMMAND CENTER: FALTAM SEÇÕES SYSTEMS/PRÓXIMAS SESSÕES; BUSCA NÃO
- Status: **feito**
- Arquivos: `lib/ui/widgets/command_center_overlay.dart`
- Evidência: Arquivos existem e há forte presença de símbolos esperados (10/15).

### 2.7 — SCHEDULER: SERIALIZAÇÃO camelCase EM VEZ DE snake_case
- Status: **parcial**
- Arquivos: `lib/models/scheduler.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (3/12).

### 2.8 — AUTO-CATEGORIA "[[people]]" NUNCA APLICADA A Person; OUTRAS 4
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/9).

### 2.9 — FALTA HOOK "CHECAR PACTS VENCIDOS A CADA ABERTURA DO APP"
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`, `lib/services/automation_service.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (1/18).

### 2.10 — SUBTASKS NÃO USAM SINTAXE DO TASKS PLUGIN DO OBSIDIAN
- Status: **parcial**
- Arquivos: `lib/models/task_model.dart (escrita)`, `lib/models/shared_types.dart`
- Evidência: Alguns arquivos-alvo existem, outros não.

### 2.11 — ÍNDICE DATAVIEW DE MOOD USA CAMPO ANTIGO DE 1 DIMENSÃO
- Status: **parcial**
- Arquivos: `lib/services/dataview_generator.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/2).

### 2.12 — FALTAM ÍNDICES DATAVIEW DE SYSTEMS E PACTS
- Status: **parcial**
- Arquivos: `lib/services/dataview_generator.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/6).

### 3.1 — ContentObject SEM CAMPO `links` UNIVERSAL
- Status: **parcial**
- Arquivos: `lib/models/content_object.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/6).

### 3.2 — Project SEM CAMPO `scheduler`
- Status: **parcial**
- Arquivos: `lib/models/project_model.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/1).

### 3.3 — Person SEM CAMPO `notes`
- Status: **parcial**
- Arquivos: `lib/models/people_model.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/2).

### 3.4 — Snapshot SEM `photos`; `subject` NÃO É WIKILINK REAL
- Status: **parcial**
- Arquivos: `lib/models/snapshot_model.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (3/8).

### 3.5 — ReminderConfig.ringOnSilent COM DEFAULT ERRADO
- Status: **parcial**
- Arquivos: `lib/models/reminder_config.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/3).

### 3.6 — TRIPLE CHECK SHEET: BOTÕES STUB; SEM PROTEÇÃO DE DISMISS; SEM
- Status: **parcial**
- Arquivos: `lib/ui/widgets/triple_check_sheet.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/6).

### 3.7 — STEERING SHEET: SEM BOTÃO X; SEM VALIDAÇÃO POR ETAPA; DEFAULT DE
- Status: **parcial**
- Arquivos: `lib/ui/widgets/steering_sheet.dart`
- Evidência: Arquivos existem, mas a evidência é incompleta (3/7).

### 3.8 — FAB: FALTA CARD "SYSTEM"; "SESSÃO" ABRE POMODORO EM VEZ DE CALENDAR
- Status: **parcial**
- Arquivos: `lib/ui/widgets/create_menu_sheet.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/1).

### 3.9 — NÃO EXISTE lib/ui/forms/create_system_form.dart
- Status: **feito**
- Arquivos: `lib/ui/forms/create_system_form.dart`
- Evidência: Arquivo solicitado para criação existe.

### 3.10 — OBJECT IDENTIFICATION: TRADUÇÃO DE TIPOS INCOMPLETA
- Status: **parcial**
- Arquivos: `lib/ui/screens/type_signatures_screen.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/1).

### 3.11 — CORPO DA DAILY NOTE (## Habits) USA WIKILINK EM VEZ DO TÍTULO DO
- Status: **parcial**
- Arquivos: `lib/services/markdown_parser.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/10).

### 3.12 — SystemDefinition.scheduler É EXTENSÃO NÃO DOCUMENTADA
- Status: **decisão**
- Arquivos: `lib/models/system_model.dart`
- Evidência: Item explicitamente marcado como decisão de produto.

### 1.1 — CREATE lib/models/app_theme_config.dart
- Status: **faltando**
- Arquivos: `lib/models/app_theme_config.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 1.2 — CREATE lib/providers/theme_provider.dart
- Status: **faltando**
- Arquivos: `lib/providers/theme_provider.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 1.3 — EDIT lib/main.dart — connect ThemeProvider to MaterialApp
- Status: **parcial**
- Arquivos: `lib/main.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 1.4 — EDIT lib/ui/theme.dart — remove dynamic colors, keep semantic only
- Status: **parcial**
- Arquivos: `lib/ui/theme.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 1.5 — GLOBAL FIND-AND-REPLACE for AppColors dynamic refs
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.

### 1.6 — REWRITE lib/ui/screens/appearance_screen.dart
- Status: **parcial**
- Arquivos: `lib/ui/screens/appearance_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 1.7 — ADD themeMode and activeThemeId to AppSettings + SettingsNotifier
- Status: **parcial**
- Arquivos: `lib/providers/settings_provider.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 2.1 — EDIT lib/main.dart — move CrashReportService.init() to top of main()
- Status: **parcial**
- Arquivos: `lib/main.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 2.2 — EDIT lib/services/crash_report_service.dart — fix save directory
- Status: **parcial**
- Arquivos: `lib/services/crash_report_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 2.3 — EDIT lib/ui/screens/diagnostic_reports_screen.dart — add Export All
- Status: **parcial**
- Arquivos: `lib/ui/screens/diagnostic_reports_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 3.1 — CREATE lib/ui/widgets/property_grid.dart
- Status: **faltando**
- Arquivos: `lib/ui/widgets/property_grid.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 3.2 — EDIT lib/ui/screens/universal_detail_view.dart — replace property cards
- Status: **parcial**
- Arquivos: `lib/ui/screens/universal_detail_view.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 4.1 — EDIT lib/ui/screens/resources_screen.dart — A4 cover proportion
- Status: **parcial**
- Arquivos: `lib/ui/screens/resources_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 4.2 — EDIT lib/ui/screens/universal_detail_view.dart — Resource hero cover
- Status: **parcial**
- Arquivos: `lib/ui/screens/universal_detail_view.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 5.1 — UPDATE (or CREATE) guidelines.md at repo root
- Status: **faltando**
- Arquivos: `guidelines.md (repo root)`
- Evidência: Arquivo solicitado para criação não existe.

### 5.2 — UPDATE (or CREATE) agents.md at repo root
- Status: **faltando**
- Arquivos: `agents.md (repo root)`
- Evidência: Arquivo solicitado para criação não existe.

### 6.1 — EDIT lib/models/tracker_model.dart — add oilPicker InputFieldType
- Status: **parcial**
- Arquivos: `lib/models/tracker_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 6.2 — EDIT lib/models/habit_model.dart — add oilSlugs to CompletionRecord
- Status: **parcial**
- Arquivos: `lib/models/habit_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 6.3 — CREATE lib/models/oil_entry.dart — the oil data structure
- Status: **faltando**
- Arquivos: `lib/models/oil_entry.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.4 — CREATE lib/services/oil_collection_service.dart
- Status: **faltando**
- Arquivos: `lib/services/oil_collection_service.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.5 — CREATE lib/providers/oil_provider.dart
- Status: **faltando**
- Arquivos: `lib/providers/oil_provider.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.6 — CREATE lib/ui/widgets/oil_picker_sheet.dart
- Status: **faltando**
- Arquivos: `lib/ui/widgets/oil_picker_sheet.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.7 — CREATE lib/ui/widgets/oil_properties_selector.dart
- Status: **faltando**
- Arquivos: `lib/ui/widgets/oil_properties_selector.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.8 — EDIT habit completion flow — show OilPickerSheet after check
- Status: **faltando**
- Arquivos: `lib/ui/widgets/habit_row.dart  (the widget that handles habit check-off)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 6.9 — CREATE lib/ui/widgets/oil_usage_chart.dart
- Status: **faltando**
- Arquivos: `lib/ui/widgets/oil_usage_chart.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 6.10 — EDIT lib/ui/screens/universal_detail_view.dart
- Status: **parcial**
- Arquivos: `lib/ui/screens/universal_detail_view.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 6.11 — ADD oilPicker UI to tracker entry form
- Status: **faltando**
- Arquivos: `lib/ui/forms/create_tracker_form.dart  (or the tracker record form)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 6.12 — ADD cross-analysis: oils in tracker analysis view
- Status: **faltando**
- Arquivos: `lib/ui/screens/trackers_screen.dart  OR`
- Evidência: Nenhum dos arquivos-alvo existe.

### 6.13 — UPDATE guidelines.md — add aromatherapy/oil patterns
- Status: **faltando**
- Arquivos: `guidelines.md (repo root)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 7.1 — EDIT lib/services/biometric_service.dart — desktop bypass
- Status: **parcial**
- Arquivos: `lib/services/biometric_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 7.2 — EDIT lib/services/notification_service.dart — desktop bypass
- Status: **parcial**
- Arquivos: `lib/services/notification_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 7.3 — EDIT lib/main.dart — window sizing for desktop
- Status: **parcial**
- Arquivos: `lib/main.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 7.4 — EDIT lib/ui/screens/social_screen.dart — Windows clipboard banner
- Status: **parcial**
- Arquivos: `lib/ui/screens/social_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 8.1 — CREATE lib/services/resource_metadata_service.dart
- Status: **faltando**
- Arquivos: `lib/services/resource_metadata_service.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 8.2 — EDIT lib/ui/forms/create_resource_form.dart — add URL-initiated mode
- Status: **parcial**
- Arquivos: `lib/ui/forms/create_resource_form.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/1).

### 8.3 — EDIT lib/models/resource_model.dart — add sourceUrl field
- Status: **parcial**
- Arquivos: `lib/models/resource_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 8.4 — EDIT main.dart share intent routing — route resource URLs differently
- Status: **parcial**
- Arquivos: `lib/main.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 8.5 — EDIT lib/ui/screens/resources_screen.dart — add clipboard/paste button
- Status: **parcial**
- Arquivos: `lib/ui/screens/resources_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 8.6 — UPDATE guidelines.md — resource metadata patterns
- Status: **faltando**
- Arquivos: `guidelines.md (repo root)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.A.1 — FIX entry_type serialization bug
- Status: **parcial**
- Arquivos: `lib/models/journal_entry.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.2 — FIX JournalEntry.date to preserve time component
- Status: **parcial**
- Arquivos: `lib/models/journal_entry.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.3 — FIX System: make run_count / last_run / average_minutes derived
- Status: **parcial**
- Arquivos: `lib/models/system_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.4 — FIX JournalEntry.type: 'journal_entry' → 'entry'
- Status: **parcial**
- Arquivos: `lib/models/journal_entry.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.5 — ADD goal_mode field to Goal model
- Status: **parcial**
- Arquivos: `lib/models/goal_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.6 — CREATE CalendarSession model
- Status: **feito**
- Arquivos: `lib/models/calendar_session.dart`
- Evidência: Arquivo solicitado para criação existe.

### 9.A.7 — REGISTER CalendarSession in vault loader
- Status: **faltando**
- Arquivos: `lib/providers/vault_provider.dart  (or lib/services/obsidian_service.dart)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.A.8 — REWRITE MoodDefinition model — 2-axis system
- Status: **parcial**
- Arquivos: `lib/models/mood_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.A.9 — CREATE MoodProvider with lazy-file logic
- Status: **faltando**
- Arquivos: `lib/providers/mood_provider.dart`
- Evidência: Arquivo solicitado para criação não existe.

### 9.B.1 — ADD TaskStage.backlog to enum + modal on save without date
- Status: **parcial**
- Arquivos: `lib/models/task_model.dart`, `lib/ui/forms/create_task_form.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.B.2 — ADD linked_system field to Task model
- Status: **parcial**
- Arquivos: `lib/models/task_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.B.3 — ADD TimeBlock.energyLevel field
- Status: **parcial**
- Arquivos: `lib/models/day_theme_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.B.4 — FIX Habit completions storage: write to daily note, not habit body
- Status: **parcial**
- Arquivos: `lib/models/habit_model.dart`, `lib/providers/vault_provider.dart (or wherever completeHabit() lives)`, `lib/services/obsidian_service.dart (or vault_provider.dart)`, `lib/services/obsidian_service.dart`
- Evidência: Alguns arquivos-alvo existem, outros não.

### 9.B.5 — FIX Organizer types: add task/goal/habit/tracker
- Status: **parcial**
- Arquivos: `lib/models/organizer_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.B.6 — RESTRUCTURE FAB create_menu_sheet.dart — 4-tab spec layout
- Status: **parcial**
- Arquivos: `lib/ui/widgets/create_menu_sheet.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.C.1 — FIX daily note template to match canonical format
- Status: **faltando**
- Arquivos: `lib/providers/vault_provider.dart (or obsidian_service.dart)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.C.2 — CREATE lib/ui/forms/create_calendar_session_form.dart
- Status: **feito**
- Arquivos: `lib/ui/forms/create_calendar_session_form.dart`
- Evidência: Arquivo solicitado para criação existe.

### 9.C.3 — CREATE lib/ui/widgets/mood_picker.dart — 2-step quadrant picker
- Status: **feito**
- Arquivos: `lib/ui/widgets/mood_picker.dart`
- Evidência: Arquivo solicitado para criação existe.

### 9.C.4 — FIX Scheduler enum serialization (camelCase → snake_case)
- Status: **parcial**
- Arquivos: `lib/models/scheduler.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.C.5 — FIX TripleCheck.blocker serialization
- Status: **faltando**
- Arquivos: `lib/models/task_model.dart  (or wherever TripleCheck is defined)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.C.6 — FIX PMN id format
- Status: **faltando**
- Arquivos: `lib/models/journal_entry.dart  (or wherever PMN is created)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.C.7 — ADD missing fields: Note.links, JournalEntry.feelings
- Status: **parcial**
- Arquivos: `lib/models/note_model.dart`, `lib/models/journal_entry.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.C.8 — FIX NoteSubtype: remove 'routine' (not in spec)
- Status: **parcial**
- Arquivos: `lib/models/note_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.C.9 — ADD Reminder.checkboxes, time_block, habit_reminder fields
- Status: **parcial**
- Arquivos: `lib/models/reminder_model.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 9.C.10 — FIX folderPaths in vault loader (Object Identification)
- Status: **faltando**
- Arquivos: `lib/services/obsidian_service.dart  (or vault_provider.dart)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 9.C.11 — ADD mood daily note fields write on mood registration
- Status: **faltando**
- Arquivos: `lib/providers/vault_provider.dart  (or mood_provider.dart)`
- Evidência: Nenhum dos arquivos-alvo existe.

### 10.1 — EDIT oembed_service.dart — add User-Agent + headers to OpenGraph fetch
- Status: **parcial**
- Arquivos: `lib/services/oembed_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 10.2 — EDIT oembed_service.dart — add Instagram-specific multi-strategy fetch
- Status: **parcial**
- Arquivos: `lib/services/oembed_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 10.3 — EDIT oembed_service.dart — add Reddit support (new platform)
- Status: **parcial**
- Arquivos: `lib/services/oembed_service.dart`, `lib/models/social_post.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 10.4 — EDIT oembed_service.dart — fix TikTok photo post handling
- Status: **parcial**
- Arquivos: `lib/services/oembed_service.dart`, `lib/ui/widgets/social_embed_view.dart`, `lib/services/oembed_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 10.5 — EDIT social_embed_view.dart — verify _buildFallback() shows thumbnail
- Status: **parcial**
- Arquivos: `lib/ui/widgets/social_embed_view.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 10.6 — EDIT social_post_grid_card.dart — verify grid thumbnails use the fix
- Status: **parcial**
- Arquivos: `lib/ui/widgets/social_post_grid_card.dart`
- Evidência: Arquivos existem, porém com pouca evidência automática (0/1).

### 10.7 — EDIT lib/ui/forms/create_social_post_form.dart — re-fetch button
- Status: **parcial**
- Arquivos: `lib/ui/forms/create_social_post_form.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.1 — FIX file watcher debounce (biggest perf win — do this first)
- Status: **feito**
- Arquivos: `lib/services/obsidian_service.dart`
- Evidência: Arquivos existem e há forte presença de símbolos esperados (1/1).

### 11.2 — FIX obsidianServiceProvider re-creating service on unrelated
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.3 — FIX groupedObjectsProvider — incremental update instead of
- Status: **parcial**
- Arquivos: `lib/providers/vault_provider.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.4 — ADD caching to getAllMarkdownFiles / getFilesInFolder
- Status: **parcial**
- Arquivos: `lib/services/obsidian_service.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.5 — DEFER heavy startup work off the main isolate / first frame
- Status: **parcial**
- Arquivos: `lib/main.dart`, `lib/services/markdown_parser.dart or wherever the bulk parse loop lives`
- Evidência: Alguns arquivos-alvo existem, outros não.

### 11.6 — THROTTLE the pull-to-refresh Command Center scroll listener
- Status: **parcial**
- Arquivos: `lib/ui/screens/home_screen.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.7 — GLOBAL OVERFLOW FIX: wrap Text in Row/Column with Flexible
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.

### 11.8 — FIX overflow in fixed-height containers with dynamic text
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.

### 11.9 — ADD a debug-mode overflow detector banner suppression + logging
- Status: **parcial**
- Arquivos: `lib/main.dart`
- Evidência: Arquivos existem, mas sem símbolos objetivos suficientes para confirmar 100%.

### 11.10 — ADD const constructors where missing (reduce rebuild cost)
- Status: **decisão**
- Evidência: Item sem arquivo específico; depende de decisão/manual.
