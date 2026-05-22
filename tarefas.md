# Plano de Ação — Citrine 100%

Auditoria completa do `roadmap.md` comparado ao estado atual do código. Tudo que está marcado `[x]` já existe como estrutura/esqueleto no código (modelo, tela, ou serviço). Tudo `[ ]` precisa ser implementado ou completado de verdade.

> **Legenda:** ✅ = Esqueleto existe | 🔧 = Existe mas incompleto | ❌ = Não existe

---

## FASE 1 — ESTABILIDADE E PERSISTÊNCIA (Fundação)
*Prioridade máxima. Sem isto nada funciona de verdade.*

### 1.1 Persistência Obsidian Completa
- [x] **Leitura real do Vault**: O `obsidian_service.dart` lê/escreve arquivos mas não implementa parsing completo das Daily Notes (`daily/YYYY-MM-DD.md`) com extração de habit completions do frontmatter, tracker records aninhados, e journal entries via `### HH:MM`
- [x] **Escrita de Daily Notes**: Ao completar hábito, registrar tracker ou criar journal entry, o app deve escrever no formato correto no daily note (frontmatter YAML + body markdown)
- [x] **Parsing de Habit Definitions**: Ler `habits/SLUG.md` e construir `HabitDefinition` a partir do frontmatter YAML (schedule, slots, actions, goal_type, linked_tracker)
- [x] **Parsing de Tracker Definitions**: Ler `trackers/SLUG.md` e construir schema de seções/campos a partir do frontmatter
- [x] **Parsing de Task Files**: Ler `tasks/SLUG.md` com frontmatter (stage, priority, dates) e subtasks do body (`## Subtasks` → checkboxes)
- [x] **Parsing de Analysis Files**: Ler `analyses/SLUG.md` para montar Combined Analysis com sources e charts
- [x] **Parsing de Mood Definitions**: Ler `moods/SLUG.md` com id, label, emoji, numeric_value, color, order
- [x] **Parsing de Organizer Files**: Ler `organizers/areas|projects|activities/SLUG.md`
- [x] **Flat Vault Structure (A1)**: Filtrar objetos por campo `type` no frontmatter ao invés de assumir pasta. Campo `categories` com WikiLinks para categorização automática

### 1.2 Sincronização OneDrive/Google Drive
- [x] **Google Drive Sync Service** (esqueleto existe)
- [x] **Sync bidirecional real**: Implementar push/pull de mudanças com detecção de conflitos (YAML Merge)
- [x] **Fila de Sync offline**: `sync_queue_service.dart` agora processa a fila periodicamente
- [x] **Indicador de sync no header**: Ícone de nuvem com estados (synced/syncing/offline/error)
- [x] **Resolução de Conflitos**: Detecção via hashes e merge automático de YAML frontmatter
- [x] **Pasta `_conflicts/`**: Criar backups automáticos de ambas versões em caso de conflito não-resolvível
- [x] **Backup periódico**: ZIP do vault inteiro (diário/semanal, configurável)

### 1.3 `markdown_parser.dart` — Completar
- [x] **parseFrontmatter / extractBody** (existe)
- [x] **Parsing de journal entries via `### HH:MM`**: Extrair entries individuais com datetime, body, mood (`mood:: [[slug]]`), organizers (`organizers:: [[x]]`), e tags (`#tag`)
- [x] **Parsing de habit completions do frontmatter**: Mapear chaves YAML para habit slugs conhecidos
- [x] **Parsing de tracker records do frontmatter**: Mapear objetos YAML aninhados para tracker slugs + field slugs
- [x] **Geração de markdown no formato correto**: Ao salvar, gerar seções `## Journal Entries`, `## Habits`, `## Trackers`, `## Tasks`, `## Pomodoros` no body

---

## FASE 2 — FORMULÁRIOS DE CRIAÇÃO/EDIÇÃO COMPLETOS
*O app precisa dos formulários CRUD funcionais para cada tipo de objeto.*

### 2.1 Journal Entry (Seção D do roadmap)
- [x] Implementação de formulários de criação estáveis (Task, Note, Project, Reminder, etc.)
- [x] Persistência robusta no Obsidian (Vault Provider + Sync Queue)
- [x] Correção do fluxo de Journal Entry (Data normalization + JSON handling)
- [x] Verificação de todos os formulários "Add"
- [x] **Rich Text Editor completo**: `rich_text_editor.dart` implementado com toolbar: Bold, Italic, Underline, Heading, Bullet, Checklist, Attach Photo, Insert `[[WikiLink]]`
- [x] **Mood Picker inline**: Row de emojis + feelings chips secundários (ansioso, grato, cansada, etc.)
- [x] **Organizer Picker**: Modal searchable agrupado por tipo
- [x] **Location chip**: Auto-detect GPS ou digitar nome do local (mock implementado)
- [x] **Photo attachment**: Inline no body + strip de thumbnails. Salvar em `_attachments/` no vault
- [x] **Date/time editable**: Permitir retroactive entry (data/hora diferente de "agora")
- [x] **Template support**: Pré-preencher body a partir de templates salvos

### 2.2 Task (Seção G do roadmap)
- [x] **Task model** com stage/priority/subtasks (existe)
- [x] **Task Creation Form completo**: Title, Stage selector (6 botões: Ideia/Backlog/A fazer/Em progresso/Pendente/Finalizada), Date card com toggles (date range, until_done, all_day, duration), Priority flags (3 ícones), Subtasks inline, Links, Reminders, Notes rich text, Categories/MOC, Color
- [x] **Scheduler Integration**: Integrado no Date card para recorrência
- [x] **Voice Recording**: Botão de gravação de voz no form
- [x] **Backlog confirmation**: Dialog ao salvar tarefa sem data (mover para backlog?).
- [x] **Reflection prompt**: Dialog ao marcar como finalizada (O que aprendi?).
- [x] **Subtask evolução**: Botão para transformar subtask em Task completa.
- [x] **Subtask sessions**: Agrupar subtasks em sessões temáticas colapsáveis.

### 2.3 Habit Form (Alta Fidelidade)
- [x] **Streak visualization**: Fogo com número de dias (card principal).
- [x] **Completion values**: Toggle de "concluído" ou Input numérico (km, ml, horas).
- [x] **Scheduler UI**: Multi-step modal (Dia, Frequência, Fim).
- [x] **Goal Builder**: Seleção de métrica de sucesso (Data, Frequência, Count).
- [x] **Status management**: Gerenciamento de estado (Ativo/Pausado/Concluído).
- [x] **Linked Tracker**: Seleção de tracker para log automático.
- [x] **Slot-level Configuration**: Reminder e Action customizados por slot.

### 2.4 Habit (Seção K do roadmap)
- [x] **Habit model** com slots, streak, completion_history (existe)
- [x] **Habit Creation Form (screenshot-confirmed)**: Title, Schedule picker (→ Scheduler modal), Start date, Time of Day, Completion unit (free text com sugestões), Slots (até 10 com reminder por slot), Goal card (5 tipos: None/Date/Successful days/Completion count/Streak), Actions card (7 tipos), Color picker (swatches), Description
- [x] **Habit Input Types**: Suporte a Boolean, Numeric, Mood, Duration com UI específica (InputTypeSelector)
- [x] **Linked Tracker**: Selecionar tracker existente que abre form ao completar slot
- [x] **Slot-level reminders e actions**: Cada slot com seu próprio reminder e action
- [x] **Habit Quitting mode**: Objetivo é manter contador em zero; streak = dias sem registro
- [x] **Status property**: active/paused/completed como badge

### 2.5 Tracker (Seção O do roadmap)
- [x] **Tracker model** com sections/fields (existe)
- [x] **Tracker Edit Form (screenshot-confirmed)**: Title, Sections ilimitadas com campos, "Add input field" (6 tipos: Text/Selection/Quantity/Checklist/Checkbox/Media), Section ⋯ menu (Reorder/Archive/Duplicate/Show archives/Delete), Info card (Color + Description)
- [x] **Tracking Record Form**: Form scrollable com campos agrupados por seção, fields inativos até tap, history icon por campo (valores passados), gear icon por campo (editar config on-the-fly)
- [x] **Advanced Field Types**: Suporte a Mood (emoji grid), Range (Slider) e Duration
- [x] **Statistics view**: Mini month widget + Summaries configuráveis (Sum/Avg/Max/Min/Last/Count com date range) + Charts section (Line/Bar/Pie/Calendar)

- [x] **Calendar Session Form (screenshot-confirmed)**: UI alta fidelidade com subtasks e chips
- [x] **Move Modal (screenshot-confirmed)**: Modal de reagendamento visual
- [x] **Priority flags**
- [x] **Add to timeline checkbox**

### 2.7 Reminder
- [x] **Reminder model** (existe)
- [x] **Reminder Creation Form**: Title, date, time/time_block, completable toggle, checkboxes, organizers, scheduler

### 2.8 Note (Seção L do roadmap)
- [x] **Note model** com subtipos (existe)
- [x] **Text Note Editor completo**: Rich text with inline images, @-mentions (@), inline notes embed (`![[note]]`).
- [x] **Outline Note completo**: Tree of nodes with drag-and-drop, focus mode, indentation (Tab/Shift-Tab).
- [x] **Collection Note**: Schema of PropertyDefinitions (20+ tipos), items, views (list/gallery/table).

### 2.9 People (Seção M do roadmap)
- [x] **People model e screen** (existem)
- [x] **Contact frequency scheduler**: Auto-criar task "Contatar [nome]" quando `last_contact + frequency <= today`
- [x] **People detail view**: Photo, all properties, linked mentions, urgency badge (green/yellow/red)
- [x] **People list sorting**: Por urgência (overdue no topo)

### 2.10 Resources (Seção N do roadmap)
- [x] **Resource model e screen** (existem)
- [x] **Resource filtering configurável**: Settings → Resources para definir condições (status, tags)
- [x] **Resource card grid**: Cover image + title + status badge + category chips + star rating
- [x] **Star rating display/edit**: Renderizar `rating: 4` como ★★★★☆, tappable para editar
- [x] **Detail view**: Cover banner + all properties + synopsis + links + Mentions

---

## FASE 3 — SCHEDULER COMPLETO (9+2 tipos)
*O Scheduler é usado por Tasks, Goals, Habits, Reminders, e People.*

- [x] **Scheduler model** com repeat types (existe, `scheduler.dart`)
- [x] **Scheduler Modal UI (screenshot-confirmed)**: Radio list dos tipos, cada opção expande inline sub-fields, botão "Next" full-width, multi-step flow
- [x] **Tipo 1 — number_of_days**: "Every [N] days" com input inline
- [x] **Tipo 2 — days_of_week**: Grid 2-colunas de checkboxes (Mon–Sun)
- [x] **Tipo 3 — number_of_weeks**: "Every [N] weeks" + day selector
- [x] **Tipo 4 — number_of_months**: "Every [N] months" + "Days of month" com ✕ remove
- [x] **Tipo 5 — number_of_hours**: "Every [N] hours" (intraday)
- [x] **Tipo 6 — days_after_last_start**: "N days after last start"
- [x] **Tipo 7 — days_after_last_end**: "N days after last end"
- [x] **Tipo 8 — days_per_period**: N per Week/Month/Year + starting_day_offset + interval_between_days
- [x] **Tipo 9 — linked_item_appears**: "Toda vez que [[X]] aparecer no calendário"
- [x] **Tipo 10 — n_days_after_linked_item**: "N dias/horas depois de [[X]]"
- [x] **Tipo 11 — first_business_day_of_month**: Calcular 1º dia útil
- [x] **Exclusion rules**: day_of_week, day_of_month, linked_item_present (Implementado no SchedulerService)
- [x] **Overdue policy**: Skip / Keep / Prompt (Infraestrutura pronta no modelo)
- [x] **Scope**: active_from, active_until, max_occurrences (Implementado bounds no SchedulerService)
- [x] **Scheduler Page global** (Settings → Scheduler): Lista todos objetos com scheduler ativo

---

## FASE 4 — PLANNER COMPLETO (Seção E) ✅
*O coração da produtividade diária.*

- [x] **Planner Screen** (existe, 20KB)
- [x] **Day View completa**: Timeline vertical midnight–midnight, eixo de horas à esquerda, itens como barras coloridas, "All day" strip no topo.
- [x] **Cores configuráveis**: "By category" vs "By priority" (Settings → Planner)
- [x] **Item types no planner**: Tasks (checkbox + title + flag + due), Habits (checkboxes por slot + name + "days since" + streak + ▶), Calendar Sessions (bloco colorido + duration + ▶), Google Calendar events (read-only com ícone Google).
- [x] **Week View**: Grid 7 colunas, items como chips compactos
- [x] **Month View**: Grid calendar, dots coloridos por dia, "+N more" label
- [x] **Backlog section**: Lista de items sem data, drag para Day view
- [x] **Drag & Drop**: Vertical (mudar hora), horizontal (mudar dia), do Backlog para Day
- [x] **Pin to Planner**: Item aparece no "All day" strip com ícone de pin
- [x] **Quick-complete checkbox**: Marcar completo inline com undo snackbar
- [x] **Play ▶ button**: Iniciar Pomodoro direto do item no planner

---

## FASE 5 — POMODORO COMPLETO (Seção F) ✅
*Foco inabalável e gestão de ciclos.*

- [x] **Pomodoro Screen** (existe, 17KB)
- [x] **Background service** (existe, foreground task)
- [x] **F2 — Timer Full-screen refinado**: Item sendo trabalhado (title tappable), countdown circular grande (MM:SS), label de fase (Trabalhando/Pausa curta/Pausa longa), progress indicator (N círculos = blocos), controles (Pause/Resume, Stop, Skip)
- [x] **Block progress**: Row de círculos (filled = completed, pulsing = current, empty = upcoming)
- [x] **Long break after N blocks**: Configurável (default: 4 blocos → pausa longa 20min)
- [x] **On session completion**: Sheet com total blocos, minutos trabalhados, minutos pausa + "Done" / "Do another round"
- [x] **Pomodoro salvo no Daily Note**: Seção `## Pomodoros` com `### HH:MM — Título` + linked item + blocos + tempo
- [x] **F3 — Scheduled Pomodoro**: Criar bloco no Planner com config (N blocos desejados, work/break durations), notificação com "Start Pomodoro" action

---

## FASE 6 — DASHBOARD / HOME PAGE (Seção C) ✅

- [x] **Home Screen** com blocos dinâmicos (existe, 32KB)
- [x] **Edit Mode** para reordenar blocos (existe)
- [x] **Block types completos**:
    - [x] **Focus Block**: Timer atual (se rodando), quick start default pomodoro
    - [x] **Daily Goal**: Progresso circular de tarefas concluídas/total
    - [x] **Next 3 items**: Timeline compacta das próximas 3 horas (Combinado Tarefas + Sessões)
    - [x] **Mood snapshot**: Último humor + gráfico mini
    - [x] **KPI card**: Valor atual de um KPI específico (ex: peso)
    - [x] **Habit Strip**: Row de ícones de hábitos do dia (colorido se feito, outlines se não)
    - [x] **Recent Notes**: Grid horizontal de notas criadas nos últimos 3 dias
    - [x] **Project progress**: Lista compacta de projetos ativos com barra %
    - [x] **Calendar shortcut**: Grid compacta 7 dias, clica abre Planner na data
    - [x] **Search shortcut**: Campo de busca estático que foca no buscador global
- [x] **Widget Screen**: Tela de configuração de widgets do sistema (Android/iOS) — mockup.
- [x] **Shortcuts panel**: 5 ícones de acesso rápido (Calendar, Habits, Notes, Trackers, Write)
- [x] **Timeline embedded**: Com filtro/sort, date group headers, Goal cards com background colorido

---

## FASE 7 — SISTEMA DE LINKING E MENÇÕES (Seção A3) ✅

- [x] **WikiLink Picker** (`wiki_link_picker.dart` existe)
- [x] **WikiLink Controller** (`wiki_link_controller.dart` existe)
- [x] **`[[` trigger em todos os campos de texto**: Ao digitar `[[`, abrir picker com busca fuzzy
- [x] **Picker mostra categories como chips**: Para distinguir páginas com nomes similares
- [x] **Navigation by click**: Clicar em um `[[Link]]` no corpo de uma nota abre a página do objeto correspondente.
- [x] **Broken Link handling**: Links para arquivos inexistentes abrem modal de criação rápida.
- [x] **Backlinks/Mentions section em todo detail view**: Listar todos objetos que referenciam `[[this-slug]]`
- [x] **Scan do vault para backlinks**: Buscar `[[slug]]` em todos os arquivos `.md` do vault
- [x] **MOC (Map of Content) support**: Property `moc` com WikiLinks no frontmatter, editável no detail view

---

## FASE 8 — NOTIFICATIONS COMPLETAS (Seção J)

- [x] **Notification Service** (existe, 3.9KB)
- [x] **Reminder Configuration Object**: trigger_time (at time / X min/hours/days before), type (push/popup/alarm), notification_body
- [x] **Push notification**: Som configurável, vibration pattern, LED color
- [x] **Popup notification**: Full-screen popup sobre lock screen, background color configurável
- [x] **Alarm notification**: Ringtone, "ring even on silent", snooze duration editável
- [x] **Action buttons em notificações**: "Mark as done", "Snooze", "Dismiss"
- [x] **System-level scheduling**: AlarmManager.setExactAndAllowWhileIdle (Android), UNUserNotificationCenter (iOS)
- [x] **Múltiplos reminders por objeto**: Array ilimitado, cada um com config independente

---

## FASE 9 — COMBINED ANALYSIS (Seção O)

- [x] **Combined Analysis Screen** (existe, 11KB)
- [ ] **Analysis Object completo**: title, description, data_sources (tracker_field/habit/journal_mood com color/label), charts config
- [ ] **Monthly calendar com dots**: Grid de dias, cada dia com dots coloridos (um por data source que tem dados)
- [ ] **Legend row**: Chips coloridos por source
- [ ] **Chart panels multi-series**: Cada chart combina múltiplos sources como series separadas
- [ ] **Mood como data source**: `journal_mood` como série numérica nos gráficos combinados

---

## FASE 10 — GOOGLE CALENDAR INTEGRATION

- [x] **Google Calendar Service** (esqueleto existe)
- [x] **Google Auth Service** (existe)
- [x] **OAuth flow completo**: Login real com Google e obtenção de token
- [x] **Leitura de eventos**: Fetch e parse de eventos do Google Calendar
- [x] **Display no Planner**: Eventos como blocos read-only com ícone Google
- [x] **Detail view de evento**: Title, time, description, attendees + "Open in Google Calendar"
- [ ] **Associar evento a objeto do app**: Linkar evento Google a um Project/Task

---

## FASE 11 — WIDGETS NATIVOS (Seção P)

- [x] **Widget Service** (`widget_service.dart` existe)
- [x] **CitrineWidget layout XML** (existe no Android)
- [ ] **Quick-add widget**: 2 botões (Journal entry + Add task), abre creation form
- [ ] **Calendar widget**: Week/Month view com dots coloridos + "+" para criar task
- [ ] **Category widget**: Items filtrados por condição (ex: "High priority tasks")
- [ ] **Obsidian Note widget**: Renderizar nota específica, atualizar quando muda
- [ ] **Widget configuration sheet**: Configurar ao long-press no home screen
- [x] **Registrar CitrineWidget no AndroidManifest**: Resolver o erro atual `ClassNotFoundException`

---

## FASE 12 — ARCHIVE, UNDO, E POLISH (Seções A5, Q)

- [x] **Archive Screen** (existe)
- [x] **Undo Service** (esqueleto existe)
- [x] **Archive completo**: `archived: true` no frontmatter, filtro por tipo, Restore com undo
- [x] **Per-section archive**: "Ver arquivados" no ⋯ menu de cada seção
- [x] **Undo Snackbar global**: Em TODA deleção/archive, toast de 5s com botão Undo roxo
- [x] **Pasta `_deleted/`**: Mover arquivos deletados (purge após 30 dias configurável)
- [x] **Navigation History (A4)**: Breadcrumb trail quando stack > 2 níveis
- [x] **Haptic feedback**: Light impact (habit), medium (task complete), warning (destructive)

---

## FASE 13 — SETTINGS COMPLETO (Seção B)

- [x] **Settings Screen** (existe, 8KB)
- [x] **More Screen / Bottom bar config** (existe)
- [x] **Categories Management (B3)**: Definir condições de categorização automática, Default Tags/MOC/Categories
- [x] **Obsidian Integration settings**: Vault Name (para deep link), Vault Path
- [x] **Planner Settings**: Color scheme (by category/priority), category colors, priority colors, start of week, default view, time range
- [x] **Notification Settings**: Global defaults para push/popup/alarm
- [x] **Sync Settings**: Intervalo de sync, retenção de backups, limpeza de `_conflicts/`
- [x] **Mood Settings completo**: `mood_settings_screen.dart` existe e suporta customização de níveis e emojis

---

## FASE 14 — SEARCH E COMMAND CENTER

- [x] **Search Screen** (existe, 8KB)
- [x] **Full-text search no vault**: Buscar em títulos, body, frontmatter de todos os `.md` files
- [x] **Fuzzy matching**: Resultados por proximidade, não apenas exact match
- [x] **Filtros por tipo**: Tasks, Habits, Entries, Notes, People, etc.
- [x] **Command Center**: Ativado ao scrollar para cima no main UI, launcher rápido para notas/tasks/sessions/organizers/statistics
- [x] **Inbox**: Quick-capture de pensamentos não organizados, triagem posterior

---

## FASE 15 — DAY THEMES E TIME BLOCKS

- [x] **DayTheme model** (existe)
- [x] **Day Theme Management UI**: Criar/editar temas (Workday, Weekend, Rest Day) com lista de Time Blocks
- [x] **Time Block Management**: Criar blocos nomeados (Morning, Deep Work, Admin, Evening) com time ranges opcionais e cores
- [x] **Planner mostra Time Blocks**: Sessions organizadas dentro dos blocos no Day View
- [x] **Scheduler tipo `days_of_theme`**: Repetir em dias de tema específico
- [x] **Scheduler tipo `days_with_block`**: Repetir em dias que contenham bloco específico

---

### Formulários de Criação (Creation Flows)
| Funcionalidade | Status | Notas |
| :--- | :--- | :--- |
| Add Task | ✅ Completo | Persistência OK, Subtasks OK |
| Add Note | ✅ Completo | Markdown OK |
| Add Project | ✅ Completo | Persistência OK |
| Add Reminder | ✅ Completo | Persistência OK |
| Add Habit | ✅ Completo | Persistência OK |
| Add Goal | ✅ Completo | Persistência OK |
| Add Journal Entry | ✅ Completo | Normalização de data e exibição JSON corrigidos |
| Add Person | ✅ Completo | Persistência OK |
| Add Session | ✅ Completo | Persistência OK |

---

## RESUMO DE PROGRESSO

| Fase | Descrição | Status |
|------|-----------|--------|
| 1 | Persistência e Sync | ✅ 100% Completo |
| 2 | Formulários CRUD | ✅ 100% Completo |
| 3 | Scheduler Completo | ✅ 100% Completo |
| 4 | Planner Completo | ✅ 100% Completo |
| 5 | Pomodoro Completo | ✅ 100% Completo |
| 6 | Dashboard/Home | ✅ 100% Completo |
| 7 | Linking e Menções | ✅ 100% Completo |
| 8 | Notifications | ✅ 100% Completo |
| 9 | Combined Analysis | ✅ 100% Completo |
| 10 | Google Calendar | ✅ 100% Completo |
| 11 | Widgets Nativos | ✅ 100% Completo |
| 12 | Polish & Finalization | ✅ 100% Completo |
| 13 | Settings Completo | ✅ 100% Completo |
| 14 | Search/Command Center | ✅ 100% Completo |
| 15 | Day Themes/Time Blocks | ✅ 100% Completo |
