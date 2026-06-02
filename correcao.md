# GAP ANALYSIS COMPLETO — APLICATIVO
> Levantamento detalhado de tudo que falta em cada objeto, funcionalidade, UI e UX do app.
> Baseado em análise completa dos models, providers, screens, forms e widgets.

---

## ÍNDICE

1. [Task (Tarefa)](#1-task)
2. [Habit (Hábito)](#2-habit)
3. [Goal (Meta)](#3-goal)
4. [Note (Nota)](#4-note)
5. [Journal Entry (Entrada de Diário)](#5-journal-entry)
6. [Tracker / TrackingRecord](#6-tracker--trackingrecord)
7. [Reminder (Lembrete)](#7-reminder)
8. [Person (Pessoa)](#8-person)
9. [Project (Projeto)](#9-project)
10. [Social Post](#10-social-post)
11. [Resource (Recurso)](#11-resource)
12. [Day Theme & Time Block](#12-day-theme--time-block)
13. [Planner Screen](#13-planner-screen)
14. [Scheduler (Agendador)](#14-scheduler)
15. [Dashboard / Home Screen](#15-dashboard--home-screen)
16. [Pomodoro](#16-pomodoro)
17. [Sync / Google Drive / Obsidian](#17-sync--google-drive--obsidian)
18. [Search & Navigation](#18-search--navigation)
19. [Settings & Appearance](#19-settings--appearance)
20. [Archive, Trash & Inbox](#20-archive-trash--inbox)
21. [Templates](#21-templates)
22. [Organizer (Pasta/Categoria)](#22-organizer)
23. [KPI & Analysis](#23-kpi--analysis)
24. [Notifications](#24-notifications)
25. [Accessibility & Polish Geral](#25-accessibility--polish-geral)

---

## 1. TASK

### Model — O que existe
- `title`, `stage` (idea/todo/inProgress/pending/finalized), `priority`, `startDate`, `endDate`, `notes`, `subtasks` com sessões, `scheduler`, `color`, `participants`, `places`, `duration`, `scheduledTime`, `timeBlock`, `dependsOn`, `estimatedMinutes`, `pomodoroCount`, `reflection`, `untilDone`, `allDay`, links com Google Calendar, `socialRefs`.

### Form de criação (`create_task_form.dart`)
**Falta:**
- **Campo `estimatedMinutes`** — existe no model mas não há picker no form. Deveria ser um campo numérico com sugestões rápidas (15 / 30 / 60 / 90 min), aparecendo ao lado do `duration`.
- **Campo `timeBlock`** — `initialTimeBlock` é passado programaticamente mas não há picker manual no form para o usuário escolher/mudar o bloco. Deveria ser um dropdown ou chip do bloco ativo do dia.
- **Campo `dependsOn`** — existe no model, mas o form não expõe nenhum picker de dependências. Fundamental para o sistema de bloqueio. Deveria ser um campo de busca de tarefas com multi-seleção via wiki-link.
- **Campo `participants` e `places`** — existem no model como `OrganizerReference`, mas não aparecem no form de criação (apenas no detalhe talvez). Precisam de um `OrganizerSelectorField` multi-seleção.
- **Campo `socialRefs`** — sem picker no form.
- **Campo `color`** — o model suporta cor por tarefa para diferenciar no calendário/timeline, mas não há color picker no form.
- **Campo `reflection`** — só é preenchido via popup pós-conclusão. Deveria ser acessível também na edição direta no detalhe.
- **Stage selector visual** — no form existe stage, mas deveria ser representado visualmente como um pipeline horizontal de chips (Idea → Todo → In Progress → Pending → Done) em vez de um dropdown.
- **`untilDone` toggle** — não está claro se aparece no form. Deveria ser um toggle explicado ("Repetir até concluir").

### Tela de detalhe / edição
**Falta:**
- **Edição inline de subtasks** — o campo de subtasks deveria ser editável diretamente na tela de detalhe (adicionar, remover, reordenar, marcar) sem precisar abrir o form.
- **Sessões de subtasks** — o model suporta `SubtaskSession` (grupos de subtasks), mas a UI não expõe criação/edição de sessões.
- **Visualização de `dependsOn`** — quando uma tarefa está bloqueada, o detalhe deveria mostrar quais tarefas a bloqueiam com link direto para cada uma e indicador de status.
- **Progress de subtasks** — barra de progresso visível no topo do detalhe (`X/Y subtasks concluídos`).
- **Timer de Pomodoro vinculado** — botão "▶ Focus" no detalhe que vai direto ao Pomodoro já vinculado a essa task.
- **Campo `estimatedMinutes` vs `timerSessions` (actual)** — comparativo visual de estimado vs realizado (ex: "Estimado: 60min | Realizado: 45min").
- **Links do Google Calendar** — se a task tem `linkedGoogleEventId`, exibir card com nome do evento e link para abrir no Calendar.
- **`participants` e `places`** — exibição em chips no detalhe com navegação para os objetos.
- **Histórico de mudanças de stage** — data em que foi movida para `inProgress`, `finalized`, etc.

### Lista (TasksScreen / PlannerScreen)
**Falta:**
- **Filtros persistentes** — filtrar por stage, prioridade, tag, organizer, prazo.
- **Agrupamento** — por stage, por prioridade, por projeto/organizer, por data.
- **Quick-complete com swipe** — swipe right para completar, swipe left para deletar/arquivar.
- **Indicador de tarefas bloqueadas** — ícone de cadeado e tooltip mostrando qual tarefa bloqueia.
- **Drag-to-reorder na lista principal** (não só no planner).
- **Badge de subtasks** — "3/5" subtasks no card da lista.

---

## 2. HABIT

### Model — O que existe
- `title`, `description`, `color`, `icon`, `completionUnit`, `dailyGoal`, `slots` (com reminder, label, actions), `schedulers`, `linkedTrackerSlug`, `timeBlock`, `completionHistory`, `streak`, `isNegative`, `inputType` (boolean/numeric/mood/duration), `status`, `priority`.

### Form de criação (`create_habit_form.dart`)
**Falta:**
- **`inputType` picker** — o model tem `HabitInputType` (boolean, numeric, mood, duration) mas o form provavelmente não expõe completamente. Para `numeric`, deveria aparecer campo `completionUnit` e `dailyGoal`. Para `duration`, deveria aparecer campo de meta em minutos.
- **Múltiplos schedulers** — o model tem `List<Scheduler>`, permitindo que um hábito apareça em múltiplos períodos (manhã E noite). O form provavelmente só cria um.
- **`linkedTrackerSlug`** — campo para vincular hábito a um tracker (quando completado, registra no tracker automaticamente). Não há picker visível.
- **`actions`** — o model tem `List<ActionDef>` por hábito e por slot, permitindo automatizações (ex: ao completar, abrir outra tela, criar uma entrada). Não há UI para configurar.
- **`icon` picker** — há uma lista de `candidates` no HomeScreen para validar os ícones, mas o form precisa de um grid de ícones para o usuário escolher.
- **`color` picker** — deve haver um color picker visual (wheel ou palette de cores predefinidas).
- **`habitStartDate`** — data de início do hábito para cálculo correto de streak desde o início.

### HabitSlot (slots de tempo)
**Falta:**
- **Múltiplos slots** — o model suporta múltiplos slots (ex: hábito que acontece manhã e noite), mas o form provavelmente só cria um slot.
- **`label` por slot** — cada slot pode ter um label diferente ("Manhã", "Noite"). Sem UI.
- **Notificação por slot** — tipo de notificação por slot (push, alarm, silencioso). Sem picker.
- **`actions` por slot** — cada slot tem seus próprios actions. Sem UI.

### Tela de detalhe
**Falta:**
- **Gráfico de histórico** — heatmap mensal/semanal dos últimos 30/90 dias de completude, similar ao GitHub contribution graph.
- **Streak visual** — contador de streak com animação e contexto ("Melhor streak: X dias", "Streak atual: Y dias").
- **Completar por slot** — no detalhe, cada slot deveria ser listado separadamente com seu botão de completar, label e horário.
- **Visualização de `completionHistory`** — lista de registros com data, valor (para numeric) e notas.
- **Edição do histórico** — corrigir um registro passado (marcar como completo/incompleto retroativamente).
- **`linkedTrackerSlug`** — se vinculado, botão para abrir o tracker correspondente.
- **Status de pausa** — toggle para pausar o hábito (`HabitStatus.paused`) sem deletar.

### HabitsScreen (lista)
**Falta:**
- **Agrupamento por status** — separar ativos, pausados, arquivados.
- **Filtro por scheduler** — mostrar só hábitos de hoje, da semana, etc.
- **Visualização compacta / expandida** — toggle de layout (lista vs cards vs grid).
- **Progresso diário geral** — header com "X de Y hábitos completos hoje" e barra de progresso.
- **Reorder persistente** — arrastar para reordenar a lista.
- **Hábitos negativos** — seção separada ou badge diferente para `isNegative`.

---

## 3. GOAL

### Model — O que existe
- `title`, `description`, `goalType` (oneTime/repeating), `state` (active/completed/cancelled/onHold), `repeatInterval`, `startDate`, `deadline`, `kpis` (List<KPI>), `subtasks`, `schedulers`, `color`, `icon`, `linkedGoogleEventId`, `socialRefs`.

### Form de criação
**Falta:**
- **KPIs inline no form** — o model tem `List<KPI>` mas o form provavelmente não permite adicionar/editar KPIs durante a criação. Precisam de um editor inline: nome do KPI, target, unidade, tipo de métrica.
- **`schedulers`** — goals podem ter schedulers (metas recorrentes), mas o form provavelmente não expõe isso.
- **`repeatInterval`** — campo livre ("weekly", "monthly", "yearly") deveria ser um picker tipado, não string livre.
- **`icon` e `color` picker** — idem ao Habit.
- **`state`** — selector de estado (active/on hold/cancelled) deveria estar acessível no form de edição.
- **Vinculação de tasks existentes** — ao criar uma goal, deveria haver opção de buscar e vincular tasks já existentes como milestones/subtasks (via slug/wiki-link).

### Tela de detalhe
**Falta:**
- **KPIs dinâmicos** — exibir cada KPI com seu valor atual, target e progresso. Se vinculado a um tracker, puxar o valor atual automaticamente.
- **Subtasks como milestones** — exibir subtasks em linha do tempo ou lista ordenada, com checkbox de conclusão e % de progresso.
- **Progress bar geral** — calculado a partir das subtasks concluídas (`goal.progress`) mas exibido de forma proeminente no topo.
- **Timeline de progresso** — gráfico ou log de quando KPIs foram atualizados.
- **Vinculação bidirecional com Tasks** — se uma task tem a goal como organizer, listar essas tasks na tela de detalhe da goal.
- **`state` selector rápido** — chips ou dropdown para mudar o estado sem abrir o form completo.
- **Compartilhar progresso** — gerar um card visual de progresso para exportar (para social, por exemplo).

### GoalsScreen (lista)
**Falta:**
- **Filtro por estado** (active, on hold, completed).
- **Filtro por tipo** (oneTime vs repeating).
- **Sorting por deadline, progresso, criação**.
- **Card de goal** — mostrar barra de progresso, ícone, cor, deadline e estado no card.
- **Goals vencendo** — destaque visual para goals com deadline nos próximos 7 dias.

---

## 4. NOTE

### Model — O que existe
- `title`, `subtype` (text/outline/collection), `body` (markdown ou JSON), `parentNoteId`, `color`, `socialRefs`, organizers, tags, reminders.

### Form de criação
**Falta:**
- **`parentNoteId`** — notas podem ser filhas de outras notas, mas não há picker no form para escolher a nota pai. Fundamental para hierarquia de notas.
- **`color` picker** — para colorir a nota visualmente na lista.
- **Escolha de `subtype`** — text, outline ou collection deveriam ser 3 modos claramente distintos no início da criação, com ícone e descrição de cada um.

### Editor (RichTextEditor / OutlineEditor)
**Falta:**
- **Toolbar persistente** — bold, italic, heading, bullet, numbered list, code, quote, link, imagem.
- **Wiki-links `[[...]]`** — o `WikiLinkController` existe, mas precisa de autocomplete de objetos ao digitar `[[`.
- **Modo outline** — `OutlineEditor` existe mas a integração entre o form e o editor de outline provavelmente está incompleta. Deveria ter drag-to-reorder de itens, indent/outdent, collapse de subitens.
- **Modo collection** — editor de coleção sem documentação clara de como é estruturado o JSON. Precisaria de UI de coleção com campos tipados.
- **Auto-save** — salvar rascunho automaticamente a cada X segundos ou ao perder foco.
- **Word count / character count** — no rodapé do editor.
- **Modo foco (fullscreen)** — esconder o AppBar e mostrar só o editor.
- **Exportar como PDF/MD** — botão de exportar o conteúdo da nota.
- **Imagens inline** — inserir imagens locais ou da câmera diretamente no editor.

### NotesScreen (lista)
**Falta:**
- **Hierarquia visual** — notas com `parentNoteId` deveriam aparecer indentadas ou num tree-view.
- **Filtro por subtype** — ver só text, só outlines, só collections.
- **Vista de cards com preview** — mostrar o início do `body` como preview no card.
- **Ordenação** — por data de criação, atualização, alfabética, manual.
- **Busca dentro do conteúdo** — não só por título.
- **Cor na lista** — cards coloridos conforme `note.color`.

---

## 5. JOURNAL ENTRY

### Model — O que existe
- `title`, `body`, `date`, `moodSlug`, `photos`, `location`, `templateId`, `comments`, `weather`, organizers, categories.

### Form de criação (`create_entry_form.dart`)
**Falta:**
- **`templateId`** — o model suporta templates de diário, mas não há picker de template no form para pré-preencher a estrutura.
- **`weather`** — campo de clima existe no model mas sem UI. Poderia ser preenchido automaticamente via geolocalização ou manualmente.
- **`location`** — campo livre existe mas sem picker de localização (Maps picker ou sugestão de local).
- **`comments`** — sem UI para adicionar comentários/reações.
- **`photos`** — campo existe mas precisa de UI: botão de câmera/galeria, visualização de miniaturas no form, remover foto.
- **`title` auto-gerado** — se vazio, gerar automaticamente com "Entrada de [data]" ou o primeiro trecho do body.
- **Entrada de humor mais rica** — o `moodSlug` referencia `MoodDefinition`, mas o seletor deveria ser mais visual (emoji grande, nome, cor associada).

### Tela de detalhe
**Falta:**
- **Galeria de fotos** — exibir fotos em grid/carousel com zoom, não só como caminhos de arquivo.
- **Mapa de localização** — se `location` preenchido, exibir um mini-mapa (ou link para Maps).
- **Clima visual** — se `weather` preenchido, exibir ícone + temperatura.
- **Edição inline do body** — tocar no texto para editar sem abrir form separado.
- **Comentários** — listar e adicionar comentários/reações.

### JournalScreen (lista)
**Falta:**
- **Visualização de calendário** — ver dias com entradas marcados no calendário do mês.
- **Filtro por humor** — ver só entradas de dias felizes, tristes, etc.
- **Streak de escrita** — "X dias consecutivos com entrada".
- **Galeria de fotos geral** — aba de fotos de todas as entradas.
- **Templates de diário** — listar e aplicar templates.

---

## 6. TRACKER / TRACKINGRECORD

### Model — O que existe
- `TrackerDefinition`: `title`, `color`, `icon`, `description`, `sections` (com `inputFields`). Cada `InputField` tem `type` (text/selection/quantity/checkbox/media/mood/range/duration/checklist), `unit`, `min`, `max`, `options`.
- `TrackingRecord`: `trackerId`, `date`, `fieldValues`.

### Form de criação do Tracker
**Falta:**
- **Editor de seções/campos completo** — adicionar/remover/reordenar seções e campos, com picker de tipo, min/max para range, opções para selection/checklist. A UI provavelmente existe parcialmente mas pode estar incompleta.
- **Preview em tempo real** — visualizar como vai ficar o formulário de registro enquanto cria a definição.
- **Campo `media`** — tipo de campo para upload de imagem/vídeo. Sem implementação de upload de arquivo.
- **Campo `mood`** — tipo de campo que referencia `MoodDefinition`. Sem picker de humor personalizado.

### Form de registro (`create_record_form.dart`)
**Falta:**
- **Renderização por tipo de campo:**
  - `range` → slider com min/max.
  - `duration` → time picker (HH:MM ou minutos).
  - `mood` → seletor de emojis/humor.
  - `media` → botão de câmera/galeria.
  - `checklist` → lista de checkboxes.
  - `selection` → dropdown ou chips.
- **Preenchimento de apenas campos obrigatórios** — campos opcionais colapsados.
- **Geolocalização automática** — para fields de localização.
- **Registro rápido** — ação direta do dashboard sem abrir form completo.

### TrackersScreen (lista de definições)
**Falta:**
- **Visualização de histórico inline** — mini gráfico de sparkline no card do tracker mostrando os últimos 7 registros.
- **Streak de registro** — "Último registro: há X dias".
- **Filtro por organizer/categoria**.
- **Botão de registro rápido** diretamente no card (sem entrar no detalhe).

### Tela de detalhe do tracker
**Falta:**
- **Gráficos por campo** — para campos do tipo quantity/range/duration: gráfico de linha/barra dos últimos 30/90 dias.
- **Estatísticas** — média, mín, máx, tendência.
- **Lista de records** — histórico paginado de todos os registros com edição e deleção.
- **Exportar CSV** — exportar todos os registros como CSV.

---

## 7. REMINDER

### Model — O que existe
- `title`, `time`, `isCompleted`, `isCompletable`, `notes`, `scheduler`, `timeBlockId`, organizers, categories.

### Form de criação
**Falta:**
- **`timeBlockId`** — sem picker de bloco de tempo. Campo existe no model mas não está exposto.
- **Tipo de notificação** — push vs alarm vs silencioso. O model base (`ContentObject`) tem `ReminderConfig`, mas o `Reminder` específico não expõe tipo de notificação no form.
- **`isCompletable` toggle** — alguns lembretes são só informações, não ações. Toggle para desabilitar o botão de conclusão.
- **Repetição no proprio form** — o `scheduler` é o mecanismo de repetição, mas o form de reminder provavelmente tem o `SchedulerPicker` como componente separado. Verificar integração.
- **Lembrete de lembrete** — notificação X minutos antes do lembrete principal.

### RemindersScreen (lista)
**Falta:**
- **Separação passados/futuros** — lembretes vencidos vs próximos.
- **Filtro "só hoje"** — ver só lembretes de hoje.
- **Marcar como concluído com swipe**.
- **Reagendar rápido** — swipe ou long-press para reagendar (+1h, +1 dia, semana que vem).
- **Lembretes não completáveis** — exibição diferenciada (sem checkbox).

---

## 8. PERSON

### Model — O que existe
- Estende `Organizer`: `title`, `parentId`, `startDate`, `endDate`, `color`, `icon`, organizers, categories.
- Específico: `photo`, `phone`, `email`, `lastContactDate`, `contactFrequency`, `contactPriority`.

### Form de criação (`create_person_form.dart`)
**Falta:**
- **`photo`** — campo de foto da pessoa (câmera/galeria). Existe no model mas precisa de UI de upload e exibição de avatar.
- **`phone` e `email`** — campos de texto, provavelmente existem. Mas falta ação de discagem/email diretamente do app.
- **`contactFrequency` picker** — `Duration` em dias. Deveria ser um picker com opções predefinidas (todo dia, toda semana, a cada 2 semanas, mensal, trimestral) + opção personalizada.
- **`contactPriority`** — enum `TaskPriority`. Sem picker visual.
- **`color` e `icon`** — personalização visual.
- **Notas/Contexto** — campo para anotar informações sobre a pessoa (interesses, como se conheceram, etc.). O model não tem campo `notes` explícito (herda do ContentObject mas sem uso claro).
- **Vínculos** — a qual projeto, organizer ou contexto essa pessoa pertence (via `organizers` field).

### Tela de detalhe
**Falta:**
- **Avatar** — foto da pessoa em destaque ou avatar gerado com iniciais e cor.
- **Ações rápidas** — botões de Ligar, Email, WhatsApp (abrindo app externo via url_launcher).
- **Status de contato** — "Último contato: X dias atrás", "Próximo contato: em Y dias", com barra de urgência colorida (verde/amarelo/vermelho).
- **Histórico de contatos** — log de quando a pessoa foi contatada (`lastContactDate` + registros anteriores). O model só guarda a última data; precisaria de um histórico simples.
- **Tasks relacionadas** — listar tasks que têm essa pessoa como `participant`.
- **Notas sobre a pessoa** — área de texto livre.

### PeopleScreen (lista)
**Falta:**
- **Ordenação por urgência de contato** — pessoas que estão atrasadas no topo.
- **Filtro por prioridade de contato**.
- **Busca por nome, email, telefone**.
- **Agrupamento** — por organizer, por frequência, por status de contato.
- **Avatars na lista** — foto ou iniciais coloridas.

---

## 9. PROJECT

### Model — O que existe
- Estende `Organizer`: `title`, `parentId`, `startDate`, `endDate`, `color`, `icon`.
- Específico: `state`, `priority`, `description`, `primaryKpiId`, `secondaryKpiIds`, `taskLinks`, `quickAccessLinks`, `totalPomodoroTime`, links Google Calendar.

### Form de criação
**Falta:**
- **`primaryKpiId` e `secondaryKpiIds`** — picker de KPIs existentes ou criação de KPI inline.
- **`taskLinks`** — vincular tasks existentes ao projeto (multi-seleção via busca).
- **`quickAccessLinks`** — lista de wiki-links para recursos rápidos do projeto. UI de adição/remoção de links.
- **`state` e `priority`** — provavelmente existem, mas devem ser visualmente ricos (pipeline de estado, flag de prioridade).
- **`color` e `icon` picker**.
- **Sub-projetos** — `parentId` permite hierarquia, mas não há UI para escolher projeto pai.

### Tela de detalhe
**Falta:**
- **Board de tasks** — visualização kanban das tasks vinculadas por stage (Idea | Todo | In Progress | Done).
- **KPIs do projeto** — exibir `primaryKpiId` com valor atual e target.
- **Quick Access Links** — grid de links rápidos para recursos do projeto.
- **Timeline do projeto** — `startDate` a `endDate` com marcos (tasks concluídas).
- **`totalPomodoroTime`** — exibir tempo total de foco gasto no projeto.
- **Sub-projetos** — listar projetos filhos (onde `parentId` aponta para este).
- **Membros do projeto** — pessoas vinculadas via organizers.

---

## 10. SOCIAL POST

### Model — O que existe
- `url`, `platform`, `mediaType`, `caption`, `authorHandle`, `authorName`, `thumbnailUrl`, `embedUrl`, `videoUrl`, `mediaUrls`, `postedAt`, `personalNote`, `watched`, `socialRefs`, organizers, tags.

### Form de criação
**Falta:**
- **Auto-fetch de metadados** — ao colar uma URL, buscar automaticamente título, autor, thumbnail, caption via oEmbed/scraping. O `OembedService` existe mas a integração com o form pode estar incompleta.
- **Preview do post** — mostrar preview visual do post (embed) dentro do form antes de salvar.
- **`personalNote`** — campo de texto livre existe mas deve ser rico (markdown).
- **Multi-plataforma bulk** — importar vários posts de uma vez. Existe `social_bulk_import_screen.dart`, verificar completude.
- **Tags automáticas** — extrair hashtags do caption e sugerir como tags.

### Tela de detalhe (`social_post_detail.dart`)
**Falta:**
- **Player de vídeo** — para posts com `videoUrl`, player in-app.
- **Carousel de imagens** — para posts com `mediaUrls` múltiplos, swipe entre as imagens.
- **Embed real** — para YouTube, TikTok, Instagram, renderizar o embed via WebView ou widget específico.
- **`watched` toggle** — botão de marcar como visto/assistido.
- **`socialRefs`** — listar outros posts relacionados como cards clicáveis.
- **Edição da `personalNote`** — inline no detalhe.

### SocialScreen (lista/grid)
**Falta:**
- **Grid por plataforma** — aba por plataforma (TikTok, Instagram, etc.) ou filtro.
- **Filtro `watched` / `unwatched`**.
- **Busca por autor, caption, tag**.
- **Grid de miniaturas** — para posts com imagem, visualização em grid.
- **Importação em lote** — link para `social_bulk_import_screen`.

---

## 11. RESOURCE

### Model — O que existe (inferido)
- `title`, `status` (backlog/inProgress/done/paused), `url`, `type` (book/article/video/podcast/course/other), `author`, `cover`, `notes`, `progress`, organizers.

### Form e detalhe
**Falta:**
- **`progress` visual** — para livros e cursos, barra de progresso com input de página atual / total de páginas.
- **`cover` image** — campo de capa com auto-fetch via ISBN ou URL.
- **Highlights/anotações** — sistema de citações e anotações dentro do recurso, cada uma com página/timestamp.
- **Status rápido** — swipe ou long-press para mover entre Backlog/Em progresso/Concluído.
- **Recomendações** — campo "Recomendado por" (vinculando a uma `Person`).
- **Rating** — avaliação pessoal de 1 a 5 estrelas após concluir.

### ResourcesScreen
**Falta:**
- **Shelf view** — visualização de estante de livros (covers em grade).
- **Filtro por tipo e status**.
- **Stats** — quantos concluídos esse ano, tempo médio, etc.

---

## 12. DAY THEME & TIME BLOCK

### Model — O que existe
- `TimeBlock`: `title`, `color`, `timeRanges` (lista de `TimeRange` com startHour/startMinute/endHour/endMinute), `order`.
- `DayTheme`: `title`, `color`, `blockIds` (lista de IDs de TimeBlocks), `daysOfWeek`.

### DayThemeScreen — O que falta

**CRUD completo:**
- **Tela de edição de TimeBlock** — tocar num bloco abre uma tela/sheet com: campo de nome, color picker, lista de TimeRanges editáveis (adicionar, remover, editar cada range), campo de order.
- **Tela de edição de DayTheme** — tocar num tema abre: campo de nome, color picker, picker de dias da semana (chips Mon-Sun), lista de blocos disponíveis com checkboxes, preview visual dos blocos no dia.
- **Delete com confirmação** — swipe ou long-press para deletar bloco/tema, com dialog de confirmação e alerta se o bloco está em uso por tarefas/hábitos.
- **Múltiplos TimeRanges por bloco** — o model já suporta `List<TimeRange>`, mas o form de criação só adiciona um. O form de edição deve ter um botão "Adicionar horário" que adiciona outro `TimeRange` ao mesmo bloco.
- **Validação de sobreposição** — alertar quando dois blocos do mesmo tema têm horários que se sobrepõem.
- **Cor visual nos tiles** — o campo `color` existe nos models mas nenhum tile usa cor. Blocos e temas deveriam ter um dot ou borda colorida.
- **Preview do dia** — na tela de DayTheme, mostrar uma mini-timeline vertical de como o dia ficará organizado com os blocos.

### Integração Planner — Timeline (modo visual)
**O maior gap do sistema:**
- **Blocos como faixas visuais na timeline** — no `TimeLineDayView`, os TimeBlocks ativos para o dia deveriam aparecer como faixas coloridas de fundo no horário correto, similar ao Google Calendar. Faixas semi-transparentes atrás dos eventos, com o nome do bloco no início da faixa.
- **Tasks sem `timeBlock` no bloco correto** — se uma task tem `scheduledTime` que cai dentro do horário de um bloco ativo, ela deveria aparecer visualmente dentro da faixa desse bloco.
- **Drag-to-assign** — arrastar uma task para dentro da faixa de um bloco na timeline automaticamente atribui `task.timeBlock = block.id`.
- **Resize de bloco** — arrastar a borda inferior de uma faixa de bloco para redimensionar o horário (idem ao Fantastical/Google Calendar).

### Integração Scheduler
- **SchedulerPicker com `daysOfTheme` e `daysWithBlock`** — os tipos `RepeatType.daysOfTheme` e `RepeatType.daysWithBlock` existem no `SchedulerService` mas precisam ser expostos no `SchedulerPicker` UI como opções selecionáveis com dropdown de tema/bloco específico.
- **Teste de preview** — no SchedulerPicker, mostrar os próximos 5 dias em que o scheduler vai disparar (calculado via `SchedulerService.nextOccurrence`).

### Task/Habit — timeBlock field
- **TimeBlock picker nos forms** — ao criar/editar task ou habit, deve aparecer um picker de bloco de tempo com os blocos ativos do dia atual ou todos os blocos disponíveis.
- **Indicador visual no card** — no card de task/habit no planner, mostrar o nome do bloco associado como um chip pequeno.

---

## 13. PLANNER SCREEN

### Day View — Agenda Mode
**Falta:**
- **Header do bloco clicável** — tocar no nome do bloco na seção abre a tela de detalhe/edição do bloco.
- **Indicador de horário atual** — linha vermelha no horário atual (como no Google Calendar). Existe na timeline, mas deve estar também no modo agenda.
- **Tasks completadas** — opção de mostrar/esconder tasks já completadas no dia (toggle no header).
- **Seção "Day Today" mais rica** — o bloco "Dia Todo" deveria mostrar quantos itens estão pending vs done.
- **Drag entre blocos** — arrastar uma task de um bloco para outro (muda `task.timeBlock`).

### Day View — Timeline Mode
**Falta (o maior gap visual):**
- **Time Block Bands** — faixas coloridas representando cada `TimeBlock` ativo no horário correspondente (vide item 12).
- **Google Calendar events como blocos** — eventos do Google Calendar já aparecem na timeline, mas deveriam ser visualmente distintos dos blocos internos (cor, ícone de calendário).
- **Eventos all-day** — área separada no topo para hábitos/tasks sem horário.
- **Conflitos de horário** — quando dois eventos se sobrepõem, mostrar lado a lado (colunas), como apps de calendário.
- **Zoom** — pinch-to-zoom para expandir/comprimir a timeline (intervalo de 15 min vs 30 min vs 1h).
- **Scroll para hora atual** — ao abrir a timeline, fazer scroll automático para a hora atual.
- **Drag de borda para duração** — o `onDurationChange` existe nos callbacks, mas a UI de resize (arrastar borda inferior do bloco) precisa ser implementada no `TimeLineDayView`.

### Week View
**Falta:**
- **Vista de grade** — atualmente é lista de dias. Deveria ter opção de grade 7 colunas com timeline vertical (como Google Calendar semana).
- **Day themes indicados** — mostrar qual tema está ativo em cada dia da semana na vista semanal (chip colorido no header da coluna).
- **Drag entre dias** — arrastar task de um dia para outro na vista semanal.

### Month View
**Falta:**
- **Mais de 35 células** — o grid atual tem sempre 35 itens (5 semanas). Meses que começam na sexta/sábado precisam de 42 (6 semanas).
- **Dot de múltiplos tipos** — além do dot de task e Google Calendar, mostrar dots para habit e reminder.
- **Tema do dia** — colorir levemente o fundo da célula do dia com a cor do tema ativo.
- **Tap para mini-agenda** — ao tocar num dia, abrir uma mini-lista de itens do dia sem sair da vista mensal (popover ou bottom sheet).
- **Scroll para ver mais de 1 mês** — navegação para mês anterior/próximo.

### Backlog Sheet
**Falta:**
- **Adicionar à data** — ao ver o backlog, arrastar/tocar numa task para agendá-la para o dia selecionado.
- **Filtros no backlog** — por prioridade, por tag.
- **Criar nova task no backlog** — botão de criar diretamente no sheet.

---

## 14. SCHEDULER

### SchedulerPicker (UI de criação de regras)
**Falta:**
- **`RepeatType.daysOfTheme`** — opção com dropdown para selecionar qual DayTheme.
- **`RepeatType.daysWithBlock`** — opção com dropdown para selecionar qual TimeBlock.
- **`RepeatType.linkedItemAppears`** e **`nDaysAfterLinkedItem`** — picker de item vinculado (busca de tasks/reminders existentes).
- **`RepeatType.numberOfDaysPerPeriod`** — interface para: período (semana/mês/ano), quantidade, intervalo entre dias, offset de início.
- **`RepeatType.firstBusinessDayOfMonth`** — apenas toggle, sem parâmetros adicionais, mas precisa de opção clara.
- **Exclusões** — o model tem `exclusions` (lista de `SchedulerRule` que fazem o scheduler NÃO disparar), mas não há UI para adicionar exclusões.
- **Preview de próximas ocorrências** — ao configurar um scheduler, mostrar os próximos 5 dias em que vai disparar (calculando via `SchedulerService.nextOccurrence`).
- **`OverduePolicy`** — picker para a política de overdue (skip/keep/prompt).
- **`maxOccurrences`** — campo para limitar o número máximo de disparos.
- **`exactTime`** — picker de hora exata para o scheduler (diferente do reminder do próprio item).

### SchedulerService
**Falta:**
- **`RepeatType.numberOfHours`** — a lógica existe mas é complexa e pode ter bugs. Precisa de teste/validação.
- **`daysAfterLastStart`/`daysAfterLastEnd`** — requer `lastCompletionDate` que precisa ser passado corretamente do contexto do hábito.
- **Performance** — `nextOccurrence` faz loop de até 730 dias. Para schedulers complexos com muitas exclusões, pode ser lento. Considerar cache.

---

## 15. DASHBOARD / HOME SCREEN

### Widgets existentes — gaps internos

**`BlockType.timeBlocking`:**
- Atualmente lista tasks com `scheduledTime` no dia. Deveria mostrar os TimeBlocks do DayTheme ativo com seus horários, de forma visual como uma mini-timeline vertical.

**`BlockType.habits`:**
- Mostra hábitos em scroll horizontal de ícones. Falta: progresso diário (X/Y), streak visível por hábito, distinção de hábitos negativos.

**`BlockType.goals`:**
- Mostra goals com barra de progresso. Falta: deadline próximo destacado, ícone/cor da goal.

**`BlockType.quotes`:**
- Quote hardcoded. Deveria ser configurável: pool de quotes personalizadas pelo usuário ou integração com API.

**`BlockType.customMarkdown`:**
- Conteúdo hardcoded. Deveria ter um editor de markdown configurável por bloco, salvo no `metadata` do DashboardBlock.

**`BlockType.pomodoroSummary`:**
- Existe `PomodoroWeekOverview`. Falta configuração de período (semana/mês) e integração com projeto específico.

**`BlockType.trackerField`:**
- Mostra apenas o registro mais recente de qualquer tracker. Deveria ser configurável: escolher qual tracker e qual campo exibir, e mostrar mini-gráfico.

**`BlockType.analysisTrend`:**
- Estatísticas genéricas de hábitos. Deveria ser configurável: escolher qual hábito ou conjunto de hábitos e qual métrica.

### Widgets faltando (mencionados no `BlockType` enum mas sem implementação)
- **`BlockType.pinnedObject`** — existe no `_buildBlock` switch mas sem implementação (`_buildPinnedObjectBlock` não está implementado ou é básico).

### Edit Mode
- **Configurar título do widget** — no edit mode, poder renomear o bloco.
- **Configurar metadados inline** — tocar no ícone de config de um bloco no edit mode para abrir configurações específicas (não só remover/hide).
- **Tamanho do widget** — alguns widgets deveriam suportar tamanhos diferentes (compacto, médio, grande) no edit mode.

### Dashboard geral
- **Persistência da ordem por device** — a ordem é salva no vault (Obsidian), mas deveria ser per-device para evitar conflitos.
- **Widget de boas-vindas** — primeiro acesso: tour guiado de como configurar o dashboard.
- **Pull-to-refresh** — arrastar para baixo para forçar re-sync.

---

## 16. POMODORO

### PomodoroScreen
**Falta:**
- **Seleção de task vinculada** — poder escolher/mudar a task vinculada durante a sessão (não só via `setCurrentItem` antes de entrar).
- **Sessões curtas de pausa** — configuração de duração de pausa curta, pausa longa, número de pomodoros até pausa longa (atualmente fixo ou em settings?).
- **Histórico visual** — no próprio PomodoroScreen, lista dos últimos X pomodoros daquela sessão de trabalho.
- **Sons/vibração** — alerta configurável ao final do pomodoro (som, vibração, silencioso).
- **Modo não-disturbe** — ao iniciar pomodoro, opcionalmente ativar DND no celular.
- **Notas de sessão** — campo para anotar o que foi feito durante o pomodoro, salvo no histórico.
- **Estatísticas de sessão** — quantos pomodoros completados hoje, quantos desta semana, tempo total de foco.
- **Background timer** — `PomodoroBackgroundService` existe. Verificar se o timer continua quando o app vai para background e se a notificação de progresso é exibida corretamente.
- **Widget para tela de bloqueio** — integração com `widget_service.dart` para mostrar tempo restante do pomodoro na tela de bloqueio (iOS/Android widgets).

### PomodoroFloatingClock
- **Falta aparência configurável** — posição, tamanho, mostrar/esconder.
- **Tap para pausar** — tocar no floating clock pausa/retoma o timer sem abrir a tela.

---

## 17. SYNC / GOOGLE DRIVE / OBSIDIAN

### Google Drive Sync
**Falta:**
- **Status de sincronização detalhado** — além do ícone de status no Dashboard, uma tela de log de sincronização (`sync_conflicts_screen.dart` existe para conflitos, mas não há log geral de operações).
- **Sincronização seletiva** — escolher quais pastas/tipos sincronizar.
- **Sync automático em background** — configuração de frequência (a cada 5min, 15min, 1h, só manual).
- **Resolução de conflitos melhorada** — o `conflict_resolution_dialog.dart` existe, mas a UI deveria mostrar um diff lado a lado das duas versões (local vs remoto) para o usuário decidir.
- **Backup automático** — `backup_service.dart` existe. UI para configurar frequência de backup e destino.

### Obsidian Integration
**Falta:**
- **Import de vault existente** — `import_vault_screen.dart` existe. Verificar se o parsing de markdown do Obsidian (frontmatter YAML + body) está completo para todos os tipos de objeto.
- **Export limpo para Obsidian** — verificar se o `toMarkdown()` de cada objeto gera YAML frontmatter válido e Dataview-compatible.
- **Links `[[wiki-link]]`** — o `WikiLinkController` existe, mas verificar se o `markdown_parser.dart` parseia corretamente links wiki bidirecionais.
- **Dataview queries** — `dataview_generator.dart` existe. UI para mostrar o resultado de queries Dataview de dentro do app.

---

## 18. SEARCH & NAVIGATION

### SearchScreen
**Falta:**
- **Busca full-text** — atualmente provavelmente busca por título. Deveria buscar também no body/notes de notes, journal entries, tasks.
- **Filtros de tipo** — filtrar resultado por tipo (task, habit, note, goal, etc.) com chips.
- **Resultados agrupados por tipo** — seções separadas na lista de resultados.
- **Busca por tag** — digitar `#tag` para buscar por tag específica.
- **Busca por organizer** — digitar `@projeto` para buscar dentro de um organizer.
- **Recentes** — mostrar últimos X objetos acessados antes de digitar.
- **Ação rápida nos resultados** — completar task, marcar hábito, ir para objeto diretamente do resultado.

### CommandCenter (overlay)
**Falta:**
- **Comandos de navegação** — `/planner`, `/habits`, `/notes` para ir diretamente para uma tela.
- **Criar objeto** — `nova tarefa [título]`, `novo hábito [título]` via linguagem natural.
- **Busca cruzada** — buscar em todos os tipos de objetos simultaneamente.
- **Histórico de comandos** — últimas buscas/ações.

### Navigation Shortcuts
**Falta:**
- **Customização completa** — o `navigation_shortcut_picker.dart` existe. Verificar se permite drag-to-reorder e se há persistência correta.
- **Shortcuts gesturais** — swipe da borda esquerda para navegar para trás, swipe da borda direita para ir para tela favorita.

---

## 19. SETTINGS & APPEARANCE

### AppearanceScreen
**Falta:**
- **Temas de cor personalizados** — além de light/dark, poder escolher cor primária (accent color) do app.
- **Tamanho de fonte** — configuração de escala de texto.
- **Ícone do app** — seleção de ícone alternativo (iOS/Android).
- **Preview em tempo real** — mostrar preview de como o app ficará com as configurações escolhidas.

### SettingsScreen
**Falta:**
- **Configuração de Pomodoro** — duração do work/short break/long break, número de pomodoros até long break.
- **Configurações de notificação** — horário de silêncio, tipos de notificação habilitados por tipo de objeto.
- **Configuração de mood** — `mood_settings_screen.dart` existe. Verificar completude: adicionar/editar/remover moods, definir emoji e cor.
- **Configuração de categorias** — `category_management_screen.dart` existe. Verificar completude.
- **Exportar todos os dados** — botão de export total em ZIP (todos os markdowns).
- **Importar dados** — além do Obsidian vault, importar de backup ZIP anterior.
- **Limpar dados** — opção de reset de dados com confirmação dupla.
- **Planner color mode** — `settings.plannerColorMode` existe. UI para configurar isso (colorir tasks por prioridade, por tag, por organizer, etc.).

---

## 20. ARCHIVE, TRASH & INBOX

### Archive Screen
**Falta:**
- **Filtro por tipo** — ver só tasks arquivadas, só notas, etc.
- **Restaurar em lote** — selecionar múltiplos e restaurar.
- **Arquivamento com data** — ver quando foi arquivado.

### Deleted Files Screen
**Falta:**
- **Período de retenção** — itens na lixeira por X dias antes de deletar permanentemente.
- **Restaurar com confirmação** — confirmar a restauração.
- **Esvaziar lixeira** — deletar tudo com confirmação dupla.
- **Preview do item** — ver o conteúdo antes de restaurar/deletar permanentemente.

### InboxScreen
**Falta:**
- **Triagem** — processar cada item do inbox: converter em task, nota, lembrete, arquivar ou deletar. Interface similar ao "Getting Things Done" inbox.
- **Inbox de emails/mensagens** — se integrado a email/Slack no futuro.
- **Contagem no badge** — badge de notificação na nav com número de itens no inbox.

---

## 21. TEMPLATES

### TemplateModel / TemplateScreen
**Falta (praticamente tudo):**
- **Lista de templates** — tela para ver, criar, editar templates.
- **Templates por tipo** — template de task, de nota, de journal entry, de goal, de tracker.
- **Aplicar template** — ao criar um objeto, opção "Usar template" que pré-preenche o form.
- **Templates de diário** — templates com estrutura de perguntas diárias (ex: "O que foi bom hoje? O que pode melhorar? Gratidão: ___"). O model tem `templateId` no JournalEntry, mas a UI de aplicação provavelmente está incompleta.
- **Templates de nota** — notas padrão (meeting notes, book notes, etc.).
- **Compartilhar templates** — exportar/importar templates como JSON ou markdown.

---

## 22. ORGANIZER

### OrganizerModel / Types
- O `Organizer` é a base para `Person`, `Project`, e pode ser área, pasta, contexto.
- `OrganizerType`: person, project, area, folder, context, tag.

### OrganizerDetailScreen
**Falta:**
- **Tela de detalhe por subtipo** — um "project" deveria abrir `UniversalDetailView` com layout de projeto (board kanban), não o layout genérico.
- **Criar sub-organizer** — dentro de uma área, criar projetos filhos.
- **Todos os itens vinculados** — tasks, notes, goals, habits, reminders com esse organizer como `organizers` field.

### Organizer Chips / Picker
- **`OrganizerSelectorField`** existe — verificar se suporta multi-seleção.
- **Criar novo organizer inline** — ao digitar um nome que não existe no picker, oferecer "Criar '[nome]' como projeto/área" diretamente.

---

## 23. KPI & ANALYSIS

### KPI Model
- Existe `kpi_model.dart` e `kpi_engine.dart`. Os KPIs são vinculados a goals e projects.

**Falta:**
- **KPI screen** — tela dedicada de gerenciamento e visualização de KPIs.
- **KPI com fonte automática** — vincular um KPI a um campo de tracker, ao streak de um hábito, ou à contagem de tasks concluídas.
- **Histórico de KPI** — registrar o valor do KPI ao longo do tempo para trending.
- **Dashboard de KPIs** — o widget `BlockType.kpi` no dashboard é genérico; deveria mostrar KPIs reais de goals/projects.

### CombinedAnalysisScreen / StatisticsScreen
**Falta:**
- **Filtro por período** — semana, mês, 3 meses, 1 ano, personalizado.
- **Correlações** — mostrar correlação entre hábitos e mood, entre foco e tasks concluídas.
- **Export de dados** — exportar gráficos como imagem ou dados como CSV.
- **Comparação de períodos** — esta semana vs semana passada.

---

## 24. NOTIFICATIONS

### NotificationService
**Falta:**
- **Notificações para todos os tipos** — tasks com deadline, habits sem check, goals vencendo, pessoas para contatar.
- **Notificações agrupadas** — no Android, usar notification group para não spam de notificações separadas.
- **Notificações com ações** — ação de completar task/habit diretamente da notificação (Android notification actions / iOS notification content extension).
- **Scheduled notifications para schedulers** — quando um scheduler é criado/editado, agendar notificações locais para as próximas ocorrências.
- **NotificationSettings** — `notification_settings_screen.dart` existe. Verificar se está completo: por tipo de objeto, horários de silêncio, tipo (push/alarm).
- **Popup notifications** — `popup_notification_screen.dart` e `notification_popup_overlay.dart` existem. Verificar integração: quando um lembrete dispara enquanto o app está aberto, mostrar o overlay.

---

## 25. ACCESSIBILITY & POLISH GERAL

### Acessibilidade
- **Semantics nos widgets** — apenas alguns widgets têm `Semantics`. Todos os cards, botões e campos interativos precisam de `Semantics` com `label`, `value`, `button`, `hint`.
- **Contraste de cores** — verificar se o tema dark/light atende WCAG AA (4.5:1 para texto normal).
- **Tamanho mínimo de toque** — garantir 44x44dp para todos os elementos interativos.
- **VoiceOver / TalkBack** — teste completo com screen reader.

### Empty States
- **Illustrations** — o `empty_state.dart` existe, mas verificar se cada tela tem um empty state específico com ilustração e call-to-action claro (não só texto genérico).
- **Onboarding** — primeira vez que o usuário abre cada tela principal, mostrar hint ou tour.

### Loading & Errors
- **Skeleton loading** — o dashboard tem skeleton. Estender para lists de tasks, habits, notes, etc.
- **Error states** — quando sync falha, vault não encontrado, permissão negada, mostrar mensagens de erro específicas e ação de retry.
- **Optimistic UI** — ao completar task/habit, atualizar a UI imediatamente (sem esperar o write no vault). Já parece ser o caso, mas verificar edge cases.

### Animações & Micro-interações
- **Completar task** — animação de check (scale + fade) ao marcar como done.
- **Completar hábito** — confetti ou animação de streak ao completar.
- **Transições de tela** — shared element transitions para abrir detalhe de um objeto.
- **Pull-to-refresh** com animação personalizada.
- **Reorder** — feedback visual ao arrastar um item para nova posição.

### Formulários
- **Validação em tempo real** — campos inválidos destacados imediatamente, não só ao submeter.
- **Auto-focus** — ao abrir um form, o cursor vai direto para o primeiro campo.
- **Keyboard avoidance** — garantir que o teclado não cobre o campo sendo editado (usar `resizeToAvoidBottomInset` + scroll).
- **Dismiss com confirmação** — ao fechar um form com dados preenchidos, perguntar "Descartar alterações?".

### UX de Deleção
- **Undo snackbar** — o `UndoService` existe para tasks. Estender para habits, notes, goals, reminders, journal entries.
- **Swipe to delete** — implementar consistentemente em todas as listas.
- **Swipe to archive** — alternativa à deleção: swipe esquerdo = arquivar.

### Performance
- **Lazy loading** — listas longas de tasks/notes/entries devem usar `ListView.builder` (já usado na maioria) com paginação se necessário.
- **Image caching** — thumbnails de social posts e fotos de journal entry devem ser cacheadas.
- **Vault read debounce** — se muitas escritas acontecem em sequência, debounce o write para não fazer I/O excessivo.

---

## RESUMO DE PRIORIDADES

### 🔴 Crítico (quebra o fluxo principal)
1. TimeBlock bands na timeline visual do Planner
2. Edição de TimeBlock e DayTheme
3. `dependsOn` picker no form de Task
4. `estimatedMinutes` e `timeBlock` picker no form de Task
5. SchedulerPicker com `daysOfTheme` / `daysWithBlock`
6. Template de diário aplicável no form de JournalEntry
7. Progress + KPIs no detalhe de Goal

### 🟡 Importante (experiência incompleta)
8. Múltiplos TimeRanges por bloco
9. Multiple slots no form de Habit
10. `linkedTrackerSlug` no Habit
11. Timeline mode: conflitos de horário / zoom / scroll para hora atual
12. Person: actions rápidas (ligar, email) + histórico de contatos
13. Tracker record form: renderização por tipo de campo
14. Social post: embed/player in-app
15. Resource: highlights e rating

### 🟢 Melhoria (polimento)
16. Empty states com ilustrações
17. Skeleton loading generalizado
18. Undo snackbar para todos os tipos
19. Swipe to delete/archive consistente
20. Animações de completar task/habit
21. Semantics / acessibilidade completa
22. Export CSV de trackers
23. Configuração de cores do tema
24. Quote block configurável