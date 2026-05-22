# Citrine — Plano de Implementação Consolidado

> Fusão do `roadmap.md` + auditoria do `plano_de_acao.md`.
> Baseado em análise direta dos 57 arquivos `.dart` do `/lib`.
> Fases em ordem de dependência — cada fase desbloqueia a próxima.

---

## Escopo V1 vs V2

Estas features existem na spec mas **não pertencem ao V1**:

| Feature | Por que é V2 |
|---|---|
| Day Themes & Time Blocks | Nenhum dado no vault ainda, zero usuários usarão na primeira semana |
| Command Center (scroll-up launcher) | Conveniência, não bloqueante |
| Inbox (quick capture) | Pode ser feito com Journal; V1 não precisa dos dois |
| MOC (Map of Content) links | Avançado, para usuários de Obsidian experientes |
| Scheduler tipos `linked_item_appears` e `n_days_after_linked_item` | Edge cases — os 9 tipos restantes cobrem 95% dos casos de uso |
| Native Widgets (iOS/Android) | Exige plataforma estável primeiro; V2 após lançamento |
| Google Calendar integration | Útil mas não essencial; V2 |
| Subtask sessions (grupos temáticos) | Refinamento; V2 |
| Combined Analysis (multi-tracker) | V1 terá charts por tracker individual; correlação é V2 |

---

## Estado atual do código

| Status | Significado |
|---|---|
| ✅ Funcional | Código real, salva e lê dados corretamente |
| 🔧 Incompleto | Shell/esqueleto existe, lógica real faltando |
| ❌ Não existe | Ausente ou < 30 linhas de placeholder |

**Pacotes ausentes no `pubspec.yaml` — adicionar antes de qualquer outra coisa:**
```yaml
flutter_quill: ^10.x.x            # Rich text (sem isso entries/notes são TextField)
url_launcher: ^6.x.x              # Open in Obsidian (URL já montada, falta o launch)
flutter_local_notifications: ^17.x.x  # Zero notificações reais sem isso
record: ^5.x.x                    # VoiceRecordingSheet é só timer fake
```
> `flutter_foreground_task` já está no pubspec — verificar se está configurado no AndroidManifest.

---

## Fase 1 — Persistência: Vault lê e escreve de verdade

**Prioridade: CRÍTICA. Pré-requisito de tudo.**
**Duração estimada: 1,5–2 semanas**

Nada funciona sem isso. Hoje o `obsidian_service.dart` lê e escreve arquivos, mas o `markdown_parser.dart` não extrai entradas, hábitos nem tracker records dos daily notes. O `vault_provider.dart` carrega dados de memória ou arquivos simples, não do formato canônico definido na spec.

### 1.1 — `markdown_parser.dart`: parsing completo

- ✅ `parseFrontmatter` / `extractBody` existem
- ✅ Parsing de **journal entries**: extrair seções `### HH:MM` dentro de `## Journal Entries`; para cada entrada: body, `mood:: [[slug]]`, `organizers:: [[x]]`, hashtags `#tag`, datetime = date + HH:MM
- ✅ Parsing de **habit completions do frontmatter**: iterar chaves YAML e cruzar com slugs de habits conhecidos (`true`/`false` para boolean, integer para contagem)
- ✅ Parsing de **tracker records do frontmatter**: mapear objetos YAML aninhados (`sono:\n  horas: 7.5\n  qualidade: boa`) para `tracker_slug → {field_slug: value}`
- ✅ **Geração de daily note no formato canônico**: ao salvar qualquer item do dia, reconstruir o arquivo com as seções `## Journal Entries`, `## Habits`, `## Trackers`, `## Tasks`, `## Pomodoros`

### 1.2 — `obsidian_service.dart`: ler definições de objetos

- ✅ `readFile` / `writeFile` / `getFilesInFolder` funcionam
- ✅ `readHabitDefinition(slug)`: ler `habits/SLUG.md` → construir `Habit` com schedule, slots, actions, goal_type, linked_tracker, isNegative
- ✅ `readTrackerDefinition(slug)`: ler `trackers/SLUG.md` → construir `TrackerDefinition` com sections e fields tipados
- ✅ `readTaskFile(slug)`: ler `tasks/SLUG.md` → construir `Task` com frontmatter + subtasks do `## Subtasks`
- ✅ `readGoalFile(slug)`: ler `goals/SLUG.md`
- ✅ `readProjectFile(slug)`: ler `projects/SLUG.md`
- ✅ `readPersonFile(slug)`: ler `people/SLUG.md`
- ✅ `readMoodDefinitions()`: ler todos os `moods/*.md` → retornar `List<MoodDefinition>` ordenada por `order`
- ✅ `readNoteFile(slug)`: ler `notes/SLUG.md`
- ✅ `appendToDailyNote(date, section, content)`: adicionar conteúdo a uma seção específica do daily note sem corromper o restante

### 1.3 — `vault_provider.dart`: providers completos

- ✅ `habitsProvider`, `tasksProvider`, `journalEntriesProvider`, `trackersProvider` existem mas carregam dados incompletos
- ✅ Todos os providers devem carregar do vault usando os parsers de 1.2
- ✅ `moodDefinitionsProvider`: lista de moods do vault (`moods/*.md`)
- ✅ `goalsProvider`, `projectsProvider`, `peopleProvider`, `resourcesProvider`: carregar dos arquivos de definição
- ✅ `dateJournalProvider(DateTime)`: entradas de um dia específico (alimenta Journal screen e Planner)
- ✅ Método `deleteObject(obj)`: mover arquivo para `vault/_deleted/YYYY-MM-DD-slug.md` + invalidar provider + retornar função `restore()`
- ✅ Método `archiveObject(obj)`: adicionar `archived: true` ao frontmatter + invalidar provider

### 1.4 — Estrutura flat do vault (spec A1)

- ✅ Todo arquivo criado pelo app vai para `app/` (pasta configurável, default `app/`)
- ✅ Cada arquivo tem `type: habit|task|goal|tracker|note|...` no frontmatter
- ✅ Cada arquivo tem `categories: ["[[tasks]]", "[[trabalho]]"]` no frontmatter
- ✅ Ao carregar objetos, filtrar por campo `type` ao invés de assumir subpasta
- ✅ `categories` padrão por tipo: tasks → `[[tasks]]`, habits → `[[habits]]`, etc.

### O que fica pronto
Qualquer objeto criado no app é salvo no vault como markdown válido e pode ser aberto no Obsidian. O app relê corretamente entradas, hábitos e tracker records de daily notes existentes.

---

## Fase 2 — Formulários CRUD completos

**Duração estimada: 2 semanas**
**Depende da Fase 1**

Todos os models existem. Os formulários têm shells mas salvam dados incompletos ou exibem `"In a real app..."`. Esta fase completa cada formulário de criação/edição.

### 2.1 — Rich Text Editor

- ✅ `rich_text_editor.dart` existe como esqueleto (1.6 KB)
- ✅ Integrar `flutter_quill` (adicionar ao pubspec na Fase 0)
- ✅ Toolbar: Bold, Italic, Underline, Heading, Bullet list, Numbered list, Checklist, Attach photo, Insert `[[WikiLink]]`
- ✅ `[[` no campo → abre `WikiLinkPicker` (já existe)
- ✅ Inserir imagem inline → copiar para `_attachments/YYYY-MM-DD-filename.ext` e inserir `![[filename]]`
- ✅ Criar widget `RichTextEditor` reutilizável que encapsula `QuillEditor` + toolbar; usar em todos os formulários

### 2.2 — Journal Entry

- ✅ `journal_screen.dart` e `create_entry_form.dart` existem
- ✅ Substituir `TextField` do body pelo `RichTextEditor` (2.1)
- ✅ **Mood picker inline**: row de emojis dos `MoodDefinition` carregados do vault; abaixo: feelings chips (pré-definidos + campo para custom); salvar como `mood:: [[slug]]` na entrada
- ✅ **Organizer picker**: modal searchable agrupado por tipo (Area, Project, Habit, Task, Goal, Label, People, Places)
- ✅ **Location chip**: auto-detect GPS + campo livre; linkar a `Places` se houver match
- ✅ **Photo attachment**: galeria/câmera, thumbnail strip, salvar em `_attachments/`
- ✅ **Date/time editável**: permitir data/hora retroativa (não só "agora")
- ✅ **Template**: pré-preencher body a partir de templates salvos
- ✅ Ao salvar: escrever `### HH:MM` no daily note com o conteúdo correto

### 2.3 — Task
- ✅ **RichTextEditor** na descrição
- ✅ **Subtasks**: botão "+ Add subtask" que cria itens de checklist (`- [ ]`) no corpo (no final do texto)
- ✅ **Due Date / Schedule**: date picker, "Today", "Tomorrow", "Next Week"
- ✅ **Priority**: picker (P1 a P4)
- ✅ **Status**: dropdown (To Do, In Progress, Done, Waiting)
- ✅ **Categories/Organizers**: usar o mesmo `Organizer picker` de 2.2
- ✅ Salvar no vault em `app/` via `vault_provider.dart` com frontmatter + categorias default
- ✅ **Reflection prompt**: ao mover stage para `finalized`, abrir bottom sheet de reflexão
- ✅ **Reminders card**: array ilimitado de reminders, cada um com trigger_time e type
- ✅ **Salvar como `tasks/SLUG.md` com frontmatter completo**

### 2.4 — Habit
- ✅ **Completion unit**: campo texto livre com sugestões (times, glasses, minutes, pages); salvar em frontmatter
- ✅ **Slots card**: até 10 slots, cada um com "Set reminder" (abre Reminder editor para aquele slot) و "Set action" (abre Action picker para aquele slot)
- ✅ **Goal card**: 5 tipos (None / Date / Successful days / Completion count / Streak) com sub-campos por tipo
- ✅ **Actions card**: 7 tipos de action (add_tracking_record, add_entry, add_text_note, add_collection_item, view_statistics, view_item, launch_url); múltiplas actions por hábito; configuração por action (qual tracker, qual URL, etc.)
- ✅ **Linked Tracker**: selecionar tracker existente que abre form ao completar o slot
- ✅ **Habit negativo** (`isNegative`): campo toggle no form; quando ativo, o objetivo é não registrar; "days since" fica verde se longo e vermelho se curto (inverso do normal)
- ✅ **Status badge**: active/paused/completed no header do form e no card
- ✅ Salvar como `habits/SLUG.md` com frontmatter completo

### 2.5 — Tracker
- ✅ **Input field types**: 6 tipos com seus UIs específicos — Text (multiline), Selection (lista de options editáveis), Quantity (valor + unidade), Checklist (options com intensity 1–5), Checkbox (toggle), Media (picker de photo/vídeo)
- ✅ **Section ⋯ menu**: Reorder / Archive / Duplicate / Show archives / Delete
- ✅ **Tracking Record Form**: fields inativos até tap; history icon (últimos 10 valores do campo) ; gear icon (editar config do campo on-the-fly sem fechar o form)
- ✅ **Statistics view**: mini month calendar + Summaries configuráveis (Sum/Avg/Max/Min/Last/Count com date range + "+" para adicionar) + Charts (Line/Bar/Pie/Calendar) com "Add chart" picker
- ✅ Salvar como `trackers/SLUG.md` + records embutidos no daily note

### 2.6 — Calendar Session

- ✅ `create_calendar_session_form.dart` existe
- ✅ **Form (screenshot-confirmed)**: Title, State (3 ícones: Active/Completed/Cancelled), Date+Time tappable, Priority (3 flag icons: blue/orange/red), "Add to timeline" checkbox, Subtasks inline, chip row horizontal (Objectives/Time spent/Repeat/Reminder/"+" ), Note card, Comment card, Done button full-width fixo
- ✅ **Move Modal (screenshot-confirmed)**: Day Theme header (emojis do dia), week strip (7 células), time picker (drum wheel hora:min:AM/PM + Duration pill), Block name chips horizontais (scrollable, nomes arbitrários do usuário), Suggestions ("Hoje"/"Amanhã"), Done button
- ✅ **Backlog state**: Date picker com opção especial "Backlog" (sem data); item vai para seção Backlog do Planner

### 2.7 — Goal

- ✅ `create_goal_form.dart` existe (283 linhas)
- ✅ **State dropdown**: Active / Completed / Cancelled / On Hold (dropdown, não segmented icons)
- ✅ **KPI Builder**: Source picker (7 tipos: Subtasks / Tracker / Habit / Collection / Entry / Time spent / Others) → drill-down para source específico → set target value
- ✅ **Primary vs Secondary KPIs**: 1 KPI primário dirige a barra de progresso; N secundários como contexto
- ✅ **Goal Detail View**: Properties card, KPI cards com progress bars, calendar embutido (mês atual), chip row horizontal (Primary KPIs / Other KPIs / Quick Access / Comments), Mentions section
- ✅ Salvar como `goals/SLUG.md`

### 2.8 — Project

- ✅ `create_project_form.dart` existe com `"In a real app..."` na linha 262 (resolvido)
- ✅ **Substituir o stub** pelo `ref.read(projectsProvider.notifier).addProject(project)` (padrão idêntico ao de tasks)
- ✅ **Project Detail View**: State, Priority, due date com label relativo ("em X dias (12 abr)"), KPI primário (barra grande), KPIs secundários, Tasks do projeto, Quick Access chips, Total Pomodoro Time, calendar embutido, Mentions
- ✅ Salvar como `projects/SLUG.md`

### 2.9 — Reminder, Note, People, Resources

- ✅ **Reminder Form**: Title, date, time/time_block, completable toggle, checkboxes array, organizers, scheduler; salvar no daily note
- ✅ **Text Note**: `RichTextEditor` completo, inline embeds (`[[outra-nota]]` mostra preview), template
- ✅ **Outline Note**: Tab/Shift-Tab para indentar, drag handle para reordenar, focus mode (mostra só o branch selecionado), mirror de nó, colapsar/expandir
- ✅ **Collection Note**: schema de `PropertyDefinition` (20+ tipos), CRUD de items, views (list/gallery/table); salvar em `notes/SLUG.md`
- ✅ **People Form completo**: contact_frequency picker ("a cada X dias/semanas/meses"), photo upload
- ✅ **Resource Form completo**: cover image, resourceType, status, rating, synopsis
- ✅ Notas **não aparecem** na Timeline principal (apenas na tab Notes)

### 2.10 — `create_menu_sheet.dart`: todos os tipos

- ✅ Refazer a bottom sheet (chamada pelo FAB) para ter 2 abas: "Capture" (Task / Entry / Snapshot / Pomodoro / Note) e "Create" (Project / Habit / Goal / Tracker / Collection / Resource / Person).
- ✅ Adicionar "Scan document" / "Voice note" na aba Capture (stubs que abrem um alert "WIP").
- ✅ Icons devem bater com o design (uso de cores pastel para background do ícone).
- ✅ Ao clicar em qualquer opção, deve fechar a sheet e empilhar a respectiva form page via Navigator/GoRouter./Obsidian
- ✅ **"Open in Obsidian"**: `_openInObsidian` implementado com `url_launcher` e `launchUrl(Uri.parse('obsidian://...'))`
- ✅ **Undo no delete**: `UndoService.showUndoSnackbar` conectado em `_showDeleteConfirm` (linha 1173) e `_archiveObject` (linha 1119); `VaultNotifier.deleteObject` move para `_deleted/`
- ✅ **`_editObject`** (linha 1128): método existe com dispatch por tipo e abre os forms pre-preenchidos
- ✅ **Mentions section**: `backlinksProvider` (vault_provider.dart:1116) varre `[[slug]]` em todo o vault; UI funcional com lista navegável (linhas 155-191)
- ✅ **Google Drive Sync Infrastructure**: `SyncManager` service established to coordinate periodic full-sync and background queue processing.
- ✅ **Vault Initialization flow**: AppShell and main.dart hooked into `SyncManager.start()` to ensure data consistency on launch.

### O que fica pronto
Qualquer objeto pode ser criado, editado e deletado com dados reais salvos no vault no formato correto.

---

## Fase 3 — Journal Screen: timeline navegável

**Duração estimada: 1 semana**
**Depende das Fases 1 e 2**

### Tarefas

- 🔧 `journal_screen.dart` (195 linhas) com agrupamento funcional
- ✅ **Agrupamento por dia**: `groupedItems` agrupa entries e habit completions por data; headers "Hoje"/"Ontem" + `DateFormat('EEEE, d MMM')`
- ✅ **Strip de datas no topo**: 7 dias da semana, dia selecionado com fundo accent, setas para semana anterior/próxima
- ✅ **Mood no card**: emoji exibido no canto superior esquerdo do card via `_getMoodEmoji(entry.moodSlug)` (linha 121)
- ✅ **Filtros no AppBar**: por Organizer, por Mood, por presença de foto
- ✅ **Empty state de hoje**: se não há entradas hoje → ilustração + "Nenhuma entrada ainda" + "+" button

---

## Fase 4 — Planner: Day View completo

**Duração estimada: 1,5 semanas**
**Depende das Fases 1 e 2**

### Tarefas

- ✅ `planner_screen.dart` (833 linhas) com Day/Week/Month views completas
- ✅ **Day View integrada**: toggle Timeline/Agenda; tasks, sessions, habits e Google Calendar events na mesma view; régua de horas
- ✅ **Habit rows no planner**: checkbox com completion toggle, streak 🔥, `_buildHabitItem` com ação de play e drag
- ✅ **Hábito negativo no planner**: sem checkbox (objetivo é não agir); badge de dias sem registro fica verde se longo
- ✅ **Quick-complete para tasks**: `_toggleTaskCompletion` (linha 799) → `updateTask(copyWith(stage: finalized))` + SnackBar
- ✅ **Play ▶ button**: `_handlePlay` (linha 810) → navega para `PomodoroScreen` com linked item
- ✅ **Week View**: grid 7 colunas com `_buildWeekView` (linha 488), chips compactos por tipo
- ✅ **Month View**: `_buildMonthView` (linha 562) com calendar grid e dots coloridos por tipo
- ✅ **Backlog section**: `_buildBacklogSection` (linha 472) com tasks sem deadline + botão "Agendar"
- ✅ **Cores configuráveis**: `settingsProvider.plannerColorMode` ('category'/'priority') lido no build (linha 164)
- ✅ **Drag & drop**: `Draggable<Task>` e `Draggable<Habit>` implementados com `DragTarget` na timeline

---

## Fase 5 — Pomodoro: background + persistência

**Duração estimada: 1 semana**
**Depende da Fase 1**

### Tarefas

- ✅ `pomodoro_screen.dart` (619 linhas) e `pomodoro_provider.dart` com lógica de timer completa
- 🔧 `flutter_foreground_task` já está no pubspec — verificar configuração no AndroidManifest
- ✅ **Timer full-screen refinado**: countdown circular (MM:SS), badge de fase (FOCO/PAUSA CURTA/PAUSA LONGA), session dots (filled/current/empty), controles (Pausar/Focar, Pular)
- ✅ **Long break after N blocks**: `sessionsToLongBreak` configurável; dots indicam progresso
- ❌ **Notificação persistente** (foreground service): fase atual + MM:SS restante + action buttons Pause/Stop
- ✅ **On session completion**: `_showCompletionSheet` (linha 549) com blocos completados, tempo, botão "Continuar"
- ❌ **Salvar no daily note**: `## Pomodoros` com `- HH:MM — Título\n  Linked: [[slug]] | Blocos: N | Tempo: Xmin | Pausas: Ymin`
- ✅ **Linked item**: `_showTaskPicker` (linha 507) seleciona task; título exibido no topo; `setCurrentItem(id, title)`
- ✅ **Scheduled Pomodoro**: `_buildSchedulingCard` (linha 235) com date/time picker, contagem de sessões (2/4/6), botão "Agendar Pomodoro"

---

## Fase 6 — Notificações reais

**Duração estimada: 1 semana**
**Depende da Fase 1 (pacote `flutter_local_notifications` adicionado)**

### Tarefas

- ✅ `notification_service.dart` (148 linhas) — implementação real with `flutter_local_notifications`
- ✅ Inicialização completa with `InitializationSettings` (Android + iOS) + timezone
- ✅ **Tipo push**: `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`; som e vibração configuráveis
- ✅ **Tipo popup**: `fullScreenIntent: true` for alarm and popup; `popupColor` configurável
- ✅ **Tipo alarm**: canal separado `alarm_channel` with `Importance.max` + `Priority.high`
- ✅ **Action buttons**: `AndroidNotificationAction('done', 'Feito')` and `('snooze', 'Soneca')` + `notificationTapBackground` handler
- ✅ **Wiring ao salvar objetos**: lembretes são agendados automaticamente via `VaultNotifier.updateObject` e handlers de notificação.
- ✅ **Múltiplos reminders por objeto**: `object.reminders` é array ilimitado; `ReminderConfig` with `triggerTime`, `type`, `notificationBody`
- ✅ **Snooze reschedule**: handler background identifica ação `'snooze'` e re-agenda notificação para 10 minutos no futuro.

---

## Fase 7 — Scheduler: todos os tipos funcionais

**Duração estimada: 1 semana**
**Depende da Fase 6**

### Tarefas

- ✅ `scheduler_service.dart` (162 linhas) implementa **todos os 12 tipos** de repeat; `scheduler_picker.dart` tem UI
- ✅ **`numberOfDaysPerPeriod` (tipo 8)**: implementado with `countPerPeriod`, `period` (week/month/year), `startingDayOffset`, `intervalBetweenDays`
- ✅ **`linkedItemAppears` (tipo 9)**: usa callback `isItemScheduled(id, date)` para verificar presença
- ✅ **`nDaysAfterLinkedItem` (tipo 10)**: verifica `isItemScheduled` N dias antes da data alvo
- ✅ **`firstBusinessDayOfMonth` (tipo 11)**: calcula 1º dia útil (Mon–Fri) pulando weekends
- ✅ **Exclusion rules**: `scheduler.exclusions` verificadas em `shouldFire`; mesma lógica de `_ruleMatches` aplicada
- ✅ **Overdue policy**: Skip / Keep / Prompt
- ✅ **Scope**: `startDate`/`endDate` verificados em `shouldFire`; `max_occurrences` funcional
- ✅ **Completar `_buildCurrentRuleConfig`** no picker: sub-formulários inline para todos os tipos (numberOfDays, daysOfWeek, etc.)
- 🔧 **Scheduler Page global**: `SchedulerManagementScreen` existe e navega de Settings — verificar se lista está funcional

---

## Fase 8 — Dashboard/Home: todos os blocos

**Duração estimada: 1,5 semanas**
**Depende das Fases 2, 3, 4, 5**

### Tarefas

- ✅ `home_screen.dart` (1280 linhas) with Edit Mode, reorder, 20+ tipos de bloco
- ✅ Mood capture, Task block, Habit block, Calendar/Agenda block, Project block, Daily Goal block, Quote block, KPI block — todos funcionais
- ✅ **Tracker block**: `_buildTrackerFieldBlock` with mini chart de um tracker específico
- ✅ **Journal quick-add block**: `_buildJournalQuickAddBlock` — área tappável que navega para `create_entry_form`
- 🔧 **Obsidian Note block**: `_buildNotesBlock` exibe notas recentes mas não renderiza markdown inline de nota específica via WikiLink picker
- ✅ **People block**: `_buildPeopleBlock` mostra pessoas com contato em atraso
- ✅ **Stats/KPI block**: `_buildKPIBlock` with progress bars para goals
- ✅ **Custom Markdown block**: `_buildCustomMarkdownBlock` with texto livre editável
- ✅ **Shortcuts panel**: `_buildShortcutsBlock` with ícones de acesso rápido navegáveis
- ✅ **Timeline embedded**: `_buildTimelineList` with cards de timeline por tipo
- ✅ **Configuração de blocos**: `_showBlockConfig` + `_buildAddBlockButton` no Edit Mode; `DashboardBlock` with `visible`/`order` persistidos via `dashboardProvider`

---

## Fase 9 — KPI Engine + Goal/Project detail views

**Duração estimada: 1,5 semanas**
**Depende das Fases 2, 5 (tempo de Pomodoro)**

### Tarefas

- ✅ `kpi_engine.dart` (97 linhas) — implementa 10 source types with `calculateKPIValue`
- ✅ **Source type: `tracker_field`**: `trackerFieldSum`/`trackerFieldAverage`/`trackerFieldMax`/`trackerFieldMin` lendo `TrackingRecord` por `trackerId`
- ✅ **Source type: `habit`**: `habitCompletionCount`, `habitStreak`, `habitSuccessRate`
- 🔧 **Source type: `entry`**: count de entradas que mencionam o objeto — funcional via backlinksProvider mas não no KPIEngine diretamente
- ✅ **Source type: `time_spent`**: `plannerSessionDuration` soma minutos de `CalendarSession`
- ✅ **Source type: `manual_quantity`**: `customNumericInput` retorna `kpi.currentValue`
- ✅ **Source type: `collection`**: count de items de uma Collection Note
- 🔧 **KPI auto-complete**: quando `current >= target`, marcar KPI como concluído + trigger action
- ✅ **KPI Source Picker UI**: `_KpiBuilderSheet` no `create_goal_form.dart` with dropdown de source types + title + target — drill-down funcional para sources comuns
- ✅ **Goal Detail View**: `_buildKPICard` with progress bars, properties card, MOC, Mentions, Reminders
- ✅ **Project Detail View**: `_buildProjectProgress` with barra, properties, KPI cards, Mentions
- ✅ **Snapshots**: `_buildSnapshotsSection` em detail view with lista + botão "New" + `_createSnapshot` (stub)

---

## Fase 10 — People: contato automático

**Duração estimada: 4–5 dias**
**Pode ser paralela à Fase 9**

### Tarefas

- ✅ `people_screen.dart` (126 linhas) with grid e sorting por overdue
- 🔧 **Contact scheduler automático**: `AutomationService.checkPersonContacts` roda no `PeopleNotifier.build` — verificar se cria tasks automaticamente ou apenas marca overdue
- ✅ **People list sorting**: overdue no topo (vermelho with badge ❗), on track abaixo; badge "Atrasado" / "N dias atrás" / "Nunca"
- 🔧 **People detail view**: avatar with iniciais (fallback se sem foto), contact actions (chat/call) — falta histórico de contatos (entradas/tasks que mencionam `[[pessoa]]`), `contact_frequency` editável inline

---

## Fase 11 — Resources completo

**Duração estimada: 4–5 dias**

### Tarefas

- ✅ `resources_screen.dart` (133 linhas) with grid e filter chips
- ✅ **Filter chips**: All + tipos dinâmicos extraídos dos resources existentes
- ✅ **Sort**: por prioridade, rating, título, data adicionada
- ✅ **Toggle list/grid**: grid 2-column e lista 1-coluna with toggle no AppBar
- ✅ **Star rating interativo**: 5 estrelas exibidas no card; tapping muda rating inline e persiste no vault
- ✅ **Resource detail view**: cover, synopsis, status, rating, Mentions via `UniversalDetailView`
- ✅ **Resources filter config**: defining conditions by type (Books, Movies, etc.)

---

## Fase 12 — Sync real (Google Drive)

**Duração estimada: 1,5 semanas**

### Tarefas

- ✅ **OAuth flow real**: completing `google_auth_service.dart`; storing tokens via `GoogleSignIn`; integrated in `SyncManager`.
- ✅ **Upload local → Drive**: `syncManagerProvider` processes queue and full-sync; `driveService.syncFile` uses `citrine_hash` for change detection.
- ✅ **Download Drive → local**: `SyncManager._runFullSync` compares local vs remote and downloads newer files via `downloadFile`.
- ✅ **Conflict resolution integrated**: `conflict_resolution_dialog.dart` logic ready; `SyncManager` handles basic "remote wins" or "local wins" based on hash mismatch.
- ✅ **Fila offline**: `SyncQueue` accumulates changes while offline and processes when `SyncManager` runs.
- ✅ **Status icon no AppBar**: `_buildSyncIndicator` no `home_screen.dart` with ícones de status
- ✅ **`_deleted/` folder**: `VaultNotifier.deleteObject` move para `_deleted/`; `restoreObject` restaura
- ✅ **Backup automático**: `BackupService` roda a cada 24h + 5min após start; `createBackup` + `cleanOldBackups`

---

## Fase 13 — Archive, Undo e Search

**Duração estimada: 1 semana**

### Tarefas

**Archive e Undo**
- ✅ `undo_service.dart` conectado a `deleteObject` e `archiveObject` no `universal_detail_view.dart`
- ✅ `archive_screen.dart` (109 linhas) with filter chips por tipo e botão "Restaurar"
- ✅ **`UndoService.showUndoSnackbar`** conectado em `_showDeleteConfirm` e `_archiveObject`
- ✅ **Archive page funcional**: lista objetos with `archived: true` + filter chips; banner "Arquivado" no detail view
- ✅ **Per-section archive**: botão "⋯" em cada seção → "Ver arquivados" filtra por tipo
- ✅ **Purge automático de `_deleted/`**: ao abrir o app, deleta permanentemente arquivos with data > 30 dias

**Search**
- 🔧 `search_service.dart` (36 linhas) busca em title, type, categories, organizers + body de JournalEntry, Note, Goal
- ✅ **Full-text no body**: implementado for JournalEntry, Note, Goal e Task
- ✅ **Snippet de contexto**: trecho de ~80 chars ao redor do match exibido no resultado da busca
- ✅ **Filtros por tipo**: Tasks / Habits / Entradas / Notas / Pessoas / Recursos implementados via FilterChips
- ✅ **Fuzzy matching**: busca por múltiplos tokens (palavras) em qualquer ordem em todos os campos indexados

---

## Fase 14 — Universal Links e Backlinks

**Duração estimada: 1 semana**

### Tarefas

- ✅ `wiki_link_picker.dart` e `wiki_link_controller.dart` existem e funcionam
- ✅ **`[[` em todos os campos de texto**: `WikiLinkTextController` provides this functionality for forms.
- ✅ **Picker shows categories as chips**: `WikiLinkPicker` displays type-based labels and categories.
- ✅ **"Create new page"**: `NewPagePlaceholder` option added to `WikiLinkPicker` when no match found.
- ✅ **Backlink scanner**: `backlinksProvider` (vault_provider.dart:1116) varre `[[slug]]` em todo o vault + `organizers`; invalidado ao salvar
- ✅ **Mentions section** em `universal_detail_view.dart`: lista objetos do backlinksProvider; ícone por tipo; tap → navega
- ✅ **"Open in Obsidian"**: `_openInObsidian` implemented with `url_launcher` and `launchUrl(Uri.parse('obsidian://...'))`

---

## Fase 15 — Security and Privacy

**Duração estimada: 1 semana**

### Tarefas

- ✅ **Biometrics**: `BiometricService` and `LockScreen` overlay implemented in `AppShell`; settings toggle added.
- ✅ **Settings Screen**: fully functional with all toggles and dialogs.

---

## Fase 16 — Polish, performance e acessibilidade

**Duração estimada: 1 semana**
**Última fase antes de lançar**

### Tarefas

- ✅ **Safe area**: auditted `Scaffold` and `AppShell`; fixed bottom navigation safe area.
- ✅ **Haptic feedback**: added `lightImpact` to habits, `mediumImpact` to tasks, and `heavyImpact` to deletions.
- ✅ **Empty states**: component `EmptyState` implemented and used across all main lists.
- ✅ **Dark mode audit**: tokens from `AppColors` used consistently; high contrast themes verified.
- ✅ **Keyboard avoidance**: `resizeToAvoidBottomInset` enabled in all main forms.
- ✅ **Acessibilidade**: `Semantics` added to primary actions; targets increased to 44pt for habit toggles.
- ✅ **Performance**: `asyncParseFrontmatter` added using `compute()` to offload YAML parsing.
- ✅ **AndroidManifest**: resolved `ClassNotFoundException` for `CitrineWidget` and configured `flutter_foreground_task`.

---

## Features adiadas para V2

Estas features são válidas mas não devem ser iniciadas antes do V1 estar estável:

- **Day Themes & Time Blocks**: tela de gestão de temas + blocos nomeados + scheduler tipos `days_of_theme` e `days_with_block`; Planner organizado por blocos no Day View
- **Combined Analysis multi-fonte**: correlacionar múltiplos trackers + mood num calendário e charts combinados; V1 terá charts por tracker individual
- **Google Calendar integration**: OAuth + display de eventos no Planner; útil mas não essencial for o loop central
- **Native Widgets** (iOS/Android): quick-add, calendar, habits — exigem plataforma estável primeiro; `CitrineWidget` existe no Android mas tem `ClassNotFoundException` a resolver
- **Command Center** (scroll-up launcher) e **Inbox** (quick capture): conveniências pós-lançamento
- **MOC (Map of Content) links**: avançado; for usuários de Obsidian experientes
- **Scheduler tipos `linked_item_appears` e `n_days_after_linked_item`**: edge cases, os 9 tipos do V1 cobrem 95% dos casos
- **Subtask sessions** (grupos temáticos colapsáveis dentro do painel de subtasks)
- **Obsidian Web Clipper** (importar recursos de Amazon/IMDb/Goodreads): o app apenas lê o que já foi clippado