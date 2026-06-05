# GAP ANALYSIS COMPLETO — APLICATIVO
> Atualizado em 04/06/2026. Baseado em análise completa dos arquivos do repositório + pedidos de usuária.
> ✅ = já implementado | 🔴 = crítico | 🟡 = importante | 🟢 = melhoria

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
14. [Calendar Widget (Dashboard)](#14-calendar-widget-dashboard)
15. [Scheduler (Agendador)](#15-scheduler)
16. [Dashboard / Home Screen](#16-dashboard--home-screen)
17. [Pomodoro](#17-pomodoro)
18. [Sync / Google Drive / Obsidian](#18-sync--google-drive--obsidian)
19. [Search & Navigation](#19-search--navigation)
20. [Settings & Appearance](#20-settings--appearance)
21. [Archive, Trash & Inbox](#21-archive-trash--inbox)
22. [Templates](#22-templates)
23. [Organizer (Pasta/Categoria)](#23-organizer)
24. [KPI & Analysis](#24-kpi--analysis)
25. [Notifications](#25-notifications)
26. [Color Picker (Global)](#26-color-picker-global)
27. ---
28. [Accessibility & Polish Geral](#28-accessibility--polish-geral)

---

## 1. TASK

### Form de criação
**Falta:**
- 🔴 **Campo `estimatedMinutes`** — existe no model mas não há picker. Deveria ser campo numérico com sugestões rápidas (15 / 30 / 60 / 90 min) ao lado do `duration`.
- 🔴 **Campo `timeBlock`** — `initialTimeBlock` é passado programaticamente mas não há picker manual no form para o usuário escolher/mudar o bloco. Deveria ser um dropdown ou chip do bloco ativo do dia.
- 🔴 **Campo `dependsOn`** — existe no model mas o form não expõe nenhum picker de dependências. Deveria ser um campo de busca de tarefas com multi-seleção via wiki-link.
- 🟡 **Campo `participants` e `places`** — existem no model como `OrganizerReference`, não aparecem no form. Precisam de `OrganizerSelectorField` multi-seleção.
- 🟡 **Stage selector visual** — deveria ser pipeline horizontal de chips (Idea → Todo → In Progress → Pending → Done) em vez de dropdown.
- 🟡 **`color` picker** — o model suporta cor por tarefa, mas não há color picker. Quando implementado, seguir padrão visual (ver item 26).
- 🟢 **`untilDone` toggle** — não está claro se aparece no form. Deveria ser um toggle explicado ("Repetir até concluir").
- 🟢 **`socialRefs`** — sem picker no form.

### Tela de detalhe / edição
**Falta:**
- 🔴 **Edição inline de subtasks** — deveria ser editável diretamente no detalhe (adicionar, remover, reordenar, marcar) sem abrir form separado.
- 🔴 **`dependsOn` no detalhe** — mostrar quais tarefas bloqueiam esta task, com link direto para cada uma e indicador de status.
- 🟡 **Progress de subtasks** — barra `X/Y subtasks` no topo do detalhe.
- 🟡 **Timer de Pomodoro vinculado** — botão "▶ Focus" no detalhe que abre o Pomodoro já vinculado.
- 🟡 **Estimado vs realizado** — comparativo "Estimado: 60min | Realizado: 45min".
- 🟢 **Links do Google Calendar** — se a task tem `linkedGoogleEventId`, exibir card com link para abrir no Calendar.
- 🟢 **`reflection`** — só é preenchido via popup pós-conclusão. Deveria ser acessível também na edição direta.
- 🟢 **Histórico de mudanças de stage** — data em que foi movida para cada estágio.

### Lista
**Falta:**
- 🟡 **Filtros persistentes** — por stage, prioridade, tag, organizer, prazo.
- 🟡 **Agrupamento** — por stage, prioridade, projeto, data.
- 🟡 **Quick-complete com swipe** — swipe right para completar, swipe left para deletar/arquivar.
- 🟡 **Indicador de tarefas bloqueadas** — ícone de cadeado e tooltip mostrando o que bloqueia.
- 🟢 **Drag-to-reorder na lista principal** (não só no planner).
- 🟢 **Badge de subtasks** — "3/5" no card da lista.

---

## 2. HABIT

### Bug identificado pelo usuário
- ✅ **Completar um slot completa todos — VERIFICADO COMO JÁ CORRIGIDO** — `TimeLineDayView` chama `onHabitToggle: (habit, slotIndex)` corretamente com índice por slot. O `_buildHabitBlock` na timeline passa `slotIndex` para o checkbox. `_isHabitSlotCompleted` usa `slotCompletions` do `CompletionRecord`.
- 🔴 **Modo agenda (fora da timeline) ainda não renderiza slots separados** — `_buildHabitCard` e `_buildHabitItem` no planner (modo agenda, não timeline) ainda chamam `toggleHabit(habit, _selectedDate)` sem `slotIndex` e não expandem os slots. Hábito com múltiplos slots aparece como um único item. Cada slot precisa ser uma linha separada com seu botão de completar chamando `toggleHabit(habit, date, slotIndex: i)`.

### Form de criação
**Falta:**
- 🔴 **`inputType` picker completo** — o model tem `HabitInputType` (boolean, numeric, mood, duration). Para `numeric`: campos `completionUnit` e `dailyGoal`. Para `duration`: meta em minutos.
- 🔴 **Múltiplos schedulers** — o model tem `List<Scheduler>`. O form provavelmente só cria um.
- 🟡 **Múltiplos slots no form** — suporta `List<HabitSlot>`. Botão "Adicionar slot" com label e horário para cada um.
- 🟡 **`linkedTrackerSlug`** — picker para vincular hábito a um tracker.
- 🟡 **`icon` picker** — grid de ícones para o usuário escolher.
- 🟡 **`color` picker** — seguir padrão visual (ver item 26).
- 🟢 **`habitStartDate`** — data de início para cálculo correto do streak.

### Tela de detalhe
**Falta:**
- 🔴 **Completar por slot no detalhe** — cada slot listado separadamente com botão de completar próprio, label e horário.
- 🟡 **Gráfico de histórico** — heatmap mensal dos últimos 30/90 dias.
- 🟡 **Streak visual** — contador com "Melhor streak: X dias", "Streak atual: Y dias".
- 🟡 **Edição do histórico** — corrigir registro passado retroativamente.
- 🟢 **`linkedTrackerSlug`** — botão para abrir o tracker correspondente.
- 🟢 **Status de pausa** — toggle para `HabitStatus.paused` sem deletar.

### HabitsScreen (lista)
**Falta:**
- 🟡 **Progresso diário geral** — header "X de Y hábitos completos hoje" com barra.
- 🟡 **Agrupamento por status** — ativos, pausados, arquivados.
- 🟢 **Filtro por scheduler** — mostrar só hábitos de hoje.
- 🟢 **Reorder persistente**.
- 🟢 **Hábitos negativos** — seção separada ou badge diferente.

---

## 3. GOAL

### Form de criação
**Falta:**
- 🔴 **KPIs inline no form** — o model tem `List<KPI>` mas o form não permite adicionar KPIs na criação. Precisam de editor inline: nome, target, unidade, tipo de métrica.
- 🟡 **`schedulers`** — goals podem ter schedulers (metas recorrentes), mas o form provavelmente não expõe.
- 🟡 **`repeatInterval`** — campo livre deveria ser picker tipado (weekly/monthly/yearly/custom).
- 🟡 **`icon` e `color` picker** — ver item 26.
- 🟡 **Vinculação de tasks existentes** — ao criar goal, buscar e vincular tasks existentes como milestones.
- 🟢 **`state` selector** — active/on hold/cancelled acessível no form de edição.

### Tela de detalhe
**Falta:**
- 🔴 **KPIs dinâmicos** — cada KPI com valor atual, target e progresso visual.
- 🔴 **Progress bar geral** — calculado a partir das subtasks, exibido no topo.
- 🟡 **Subtasks como milestones** — em linha do tempo ou lista com % de progresso.
- 🟡 **Vinculação bidirecional com Tasks** — listar tasks que têm a goal como organizer.
- 🟡 **`state` selector rápido** — chips ou dropdown sem abrir form completo.
- 🟢 **Timeline de progresso** — quando KPIs foram atualizados.

### GoalsScreen (lista)
**Falta:**
- 🟡 **Filtro por estado e tipo**.
- 🟡 **Card rico** — barra de progresso, ícone, cor, deadline, estado.
- 🟡 **Goals vencendo** — destaque para deadline nos próximos 7 dias.
- 🟢 **Sorting** — por deadline, progresso, criação.

---

## 4. NOTE

### Form de criação
**Falta:**
- 🟡 **`parentNoteId` picker** — hierarquia de notas sem UI.
- 🟡 **Escolha de `subtype` visual** — text, outline, collection como 3 modos com ícone e descrição.
- 🟢 **`color` picker** — ver item 26.

### Editor
**Falta:**
- 🔴 **Toolbar persistente** — bold, italic, heading, bullet, numbered list, code, quote, link, imagem.
- 🔴 **Wiki-links `[[...]]`** — `WikiLinkController` existe mas autocomplete ao digitar `[[` precisa ser verificado.
- 🟡 **Modo outline completo** — `OutlineEditor` existe. Verificar: drag-to-reorder, indent/outdent, collapse de subitens.
- 🟡 **Auto-save** — salvar rascunho a cada X segundos ou ao perder foco.
- 🟡 **Modo foco (fullscreen)** — esconder AppBar, só editor.
- 🟢 **Word count** — no rodapé.
- 🟢 **Exportar como PDF/MD**.
- 🟢 **Imagens inline** — inserir imagens locais ou da câmera.

### NotesScreen (lista)
**Falta:**
- 🟡 **Hierarquia visual** — notas com `parentNoteId` indentadas ou em tree-view.
- 🟡 **Preview do body** — mostrar início do conteúdo no card.
- 🟢 **Filtro por subtype**.
- 🟢 **Busca dentro do conteúdo** — não só por título.
- 🟢 **Cor na lista** — cards coloridos conforme `note.color`.

---

## 5. JOURNAL ENTRY

### Form de criação
**Falta:**
- 🔴 **`templateId` picker** — o model suporta templates de diário, mas não há picker no form para pré-preencher estrutura.
- 🟡 **Humor mais visual** — seletor de emoji grande com nome e cor associada, não só slug de texto.
- 🟡 **`photos`** — botão câmera/galeria, miniaturas no form, remover foto.
- 🟢 **`weather`** — preenchimento automático via geolocalização ou manual.
- 🟢 **`location`** — picker de localização (Maps).
- 🟢 **`title` auto-gerado** — "Entrada de [data]" se vazio.

### Tela de detalhe
**Falta:**
- 🟡 **Galeria de fotos** — grid/carousel com zoom.
- 🟡 **Edição inline do body** — tocar no texto para editar sem abrir form separado.
- 🟢 **Mapa de localização** — mini-mapa se `location` preenchido.
- 🟢 **Clima visual** — ícone + temperatura se `weather` preenchido.

### JournalScreen (lista)
**Falta:**
- 🟡 **Visualização de calendário** — dias com entradas marcados.
- 🟡 **Filtro por humor**.
- 🟢 **Streak de escrita** — "X dias consecutivos com entrada".
- 🟢 **Templates de diário** — listar e aplicar.

---

## 6. TRACKER / TRACKINGRECORD

### Form de criação do Tracker
**Falta:**
- 🔴 **Preview em tempo real** — visualizar como vai ficar o formulário de registro enquanto cria a definição.
- 🟡 **Editor de seções/campos completo** — verificar se está completo: picker de tipo, min/max para range, opções para selection/checklist.
- 🟢 **Campo `media`** — upload de imagem/vídeo.
- 🟢 **Campo `mood`** — referencia `MoodDefinition`, sem picker de humor personalizado.

### Form de registro (`create_record_form.dart`)
**Falta:**
- 🔴 **Renderização por tipo de campo:**
  - `range` → slider com min/max
  - `duration` → time picker (HH:MM)
  - `mood` → seletor de emojis/humor
  - `media` → câmera/galeria
  - `checklist` → lista de checkboxes
  - `selection` → dropdown ou chips
- 🟢 **Registro rápido** — ação direta do dashboard sem abrir form completo.

### TrackersScreen
**Falta:**
- 🟡 **Mini gráfico sparkline** no card dos últimos 7 registros.
- 🟡 **Botão de registro rápido** no card sem entrar no detalhe.
- 🟢 **Streak de registro** — "Último registro: há X dias".

### Tela de detalhe
**Falta:**
- 🟡 **Gráficos por campo** — linha/barra dos últimos 30/90 dias.
- 🟡 **Estatísticas** — média, mín, máx, tendência.
- 🟡 **Lista de records** — histórico paginado com edição e deleção.
- 🟢 **Exportar CSV**.

---

## 7. REMINDER

### Form de criação
**Falta:**
- 🟡 **`timeBlockId`** — sem picker de bloco de tempo.
- 🟡 **Tipo de notificação** — push vs alarm vs silencioso.
- 🟢 **`isCompletable` toggle** — desabilitar checkbox para lembretes informativos.
- 🟢 **Lembrete de lembrete** — notificação X minutos antes do principal.

### RemindersScreen
**Falta:**
- 🟡 **Separação passados/futuros**.
- 🟡 **Reagendar rápido** — swipe para +1h, +1 dia, semana que vem.
- 🟢 **Filtro "só hoje"**.
- 🟢 **Marcar como concluído com swipe**.

---

## 8. PERSON

### Form de criação
**Falta:**
- 🟡 **`photo`** — campo de upload de foto (câmera/galeria).
- 🟡 **`contactFrequency` picker** — opções predefinidas (diário, semanal, quinzenal, mensal, trimestral) + personalizado.
- 🟡 **`contactPriority`** — picker visual de prioridade.
- 🟢 **`color` e `icon`** — personalização visual. Ver item 26.

### Tela de detalhe
**Falta:**
- 🔴 **Ações rápidas** — Ligar, Email, WhatsApp via `url_launcher`.
- 🔴 **Status de contato** — "Último contato: X dias atrás", "Próximo: em Y dias" com barra urgência.
- 🟡 **Avatar** — foto ou iniciais coloridas.
- 🟡 **Tasks relacionadas** — tasks que têm essa pessoa como `participant`.
- 🟢 **Histórico de contatos** — log de quando foi contatada.

### PeopleScreen
**Falta:**
- 🟡 **Ordenação por urgência de contato**.
- 🟡 **Avatars na lista**.
- 🟢 **Filtro por prioridade de contato**.
- 🟢 **Busca por email, telefone**.

---

## 9. PROJECT

### Form de criação
**Falta:**
- 🔴 **`primaryKpiId` e `secondaryKpiIds`** — picker de KPIs ou criação inline.
- 🟡 **`taskLinks`** — vincular tasks existentes ao projeto (multi-seleção via busca).
- 🟡 **`quickAccessLinks`** — lista de wiki-links para recursos rápidos. UI de adição/remoção.
- 🟡 **Sub-projetos** — `parentId` permite hierarquia, mas sem UI para escolher projeto pai.
- 🟢 **`state` e `priority`** — verificar se são visualmente ricos.

### Tela de detalhe
**Falta:**
- 🔴 **Board de tasks** — kanban por stage (Idea | Todo | In Progress | Done).
- 🟡 **KPIs do projeto** — valor atual e target.
- 🟡 **Quick Access Links** — grid de links rápidos.
- 🟡 **`totalPomodoroTime`** — tempo total de foco.
- 🟢 **Timeline do projeto** — do start ao end com marcos.
- 🟢 **Sub-projetos** — listar filhos.

---

## 10. SOCIAL POST

### Pedidos do usuário
- 🔴 **Linkar tarefa ao salvar um post** — na tela de detalhe/form do social post, uma seção "Vincular a tarefa" com `UniversalSearchPickerSheet` já existe via `_associateObject()` na timeline card. **Porém falta no `CreateSocialPostForm` e no `SocialPostDetail`**: seção dedicada de vinculação por tipo de objeto, não apenas `socialRefs` genérico. Deveria haver abas ou seções: "Tarefas", "Notas", "Goals", "Projetos" para separar o tipo de objeto linkado.
- 🔴 **Separar socialRefs por tipo de objeto** — o campo `socialRefs` é uma lista de wiki-links sem tipo. Precisaria ou de um campo tipado (`linkedTasks`, `linkedNotes`, etc.) ou de uma UI que agrupe os refs por tipo detectado para facilitar filtragem e visualização.

### Form de criação
**Falta:**
- 🟡 **Seção "Vincular objetos"** no form de criação — não só via card na timeline após salvar.
- 🟡 **Preview do post** — mostrar preview (embed) dentro do form antes de salvar.
- 🟢 **Tags automáticas** — extrair hashtags do caption e sugerir como tags.

### Tela de detalhe (`social_post_detail.dart`)
**Falta:**
- 🟡 **Seção de objetos vinculados agrupada por tipo** — tarefas linkadas, notas linkadas, etc., cada uma clicável.
- 🟡 **Player de vídeo** — para posts com `videoUrl`.
- 🟡 **Carousel de imagens** — para posts com `mediaUrls` múltiplos.
- 🟢 **`watched` toggle** — botão de marcar como visto/assistido visível no detalhe.
- 🟢 **Edição da `personalNote`** — inline no detalhe.

### SocialScreen (lista/grid)
- ✅ Filtro por plataforma — implementado
- ✅ Filtro `watched/unwatched` — implementado
- ✅ Associar a objeto via timeline card — implementado
- ✅ Coleções/Organizers — implementado
- ✅ Busca via SearchScreen — implementado
- 🟡 **IDs visíveis** — verificar se `socialRefs` mostra slugs/IDs no UI. Substituir por títulos dos objetos linkados.

---

## 11. RESOURCE

### Form e detalhe
**Falta:**
- 🟡 **`progress` visual** — para livros e cursos, barra com página atual / total.
- 🟡 **`cover` image** — auto-fetch via ISBN ou URL.
- 🟡 **Rating** — avaliação de 1 a 5 estrelas após concluir.
- 🟢 **Status rápido** — swipe para mover entre Backlog/Em progresso/Concluído.
- 🟢 **Recomendações** — campo "Recomendado por" vinculando a uma `Person`.

### ResourcesScreen
**Falta:**
- 🟡 **Shelf view** — grade de covers.
- 🟡 **adicionar listas de Filtros por qualquer propriedade, e ordenar por qualquer propriedade**.
- 🟢 **Stats** — quantos concluídos este ano, etc.

---

## 12. DAY THEME & TIME BLOCK

### DayThemeScreen — CRUD
**Falta:**
- 🔴 **Tela de edição de TimeBlock** — tocar num bloco não abre nada. Precisamos de sheet/tela com: campo de nome, color picker (ver item 26), lista de TimeRanges editáveis (adicionar, remover, editar cada range), campo de order.
- 🔴 **Tela de edição de DayTheme** — tocar num tema não abre nada. Precisamos de: campo de nome, color picker, picker de dias da semana (chips Mon-Sun), lista de blocos com checkboxes, preview visual.
- 🔴 **Múltiplos TimeRanges por bloco no form de criação** — o model suporta `List<TimeRange>` mas o form cria só um. Botão "Adicionar horário" que adiciona outro range.
- 🟡 **Delete com confirmação** — swipe ou long-press com alerta se bloco está em uso.
- 🟡 **Cor visual nos tiles** — `color` existe mas não é usado na UI. Dot ou borda colorida.
- 🟡 **Preview do dia** — mini-timeline vertical na tela de DayTheme mostrando como o dia ficará.
- 🟢 **Validação de sobreposição** — alertar quando dois blocos do mesmo tema têm horários sobrepostos.

### Integração Planner (Timeline)
- ✅ Time Block Bands na timeline — `_buildTimeBlockBands()` implementado no `TimeLineDayView`
- ✅ Blocos passados como parâmetro para TimeLineDayView — verificado no planner_screen
- 🟡 **`timeBlocks` não está sendo passado ao `TimeLineDayView`** — verificar: o `TimeLineDayView` recebe `timeBlocks` como parâmetro, mas no `PlannerScreen` o `TimeLineDayView` é construído sem passar `timeBlocks`. Confirmar se a prop está sendo passada corretamente ou se as bands não aparecem.
- 🟡 **Drag-to-assign bloco** — arrastar task para faixa de bloco atribui `task.timeBlock`.
- 🟢 **Resize de bloco** — arrastar borda inferior de uma faixa para redimensionar horário.

### Integração Scheduler
- 🔴 **SchedulerPicker sem `daysOfTheme`/`daysWithBlock`** — tipos existem no `SchedulerService` mas não expostos no picker UI.
- 🟡 **Preview de próximas ocorrências** — mostrar próximas 5 datas no SchedulerPicker.

---

## 13. PLANNER SCREEN

### Bug identificado pelo usuário
- 🔴 **Hábito com múltiplos slots completa todos ao tocar em um** — ver item 2 (Habit). Bug no `_buildHabitCard` e `_buildHabitItem`: chamam `toggleHabit` sem `slotIndex`. Solução: renderizar cada slot como linha separada com botão individual chamando `toggleHabit(habit, date, slotIndex: i)`.

### Bug identificado pelo usuário — auto-scroll
- 🔴 **Ao abrir o Planner, não scrolla para o horário atual** — `TimeLineDayView` é renderizado dentro de `SliverToBoxAdapter` dentro de `CustomScrollView` no `PlannerScreen`. Não há `ScrollController` compartilhado nem `jumpTo` no `initState`. Solução: expor um `ScrollController` no `_PlannerScreenState`, passá-lo tanto para o `CustomScrollView` quanto para o `TimeLineDayView`, e no `initState` (ou `didChangeDependencies`) chamar `WidgetsBinding.instance.addPostFrameCallback((_) { _scrollController.jumpTo(now.hour * 80.0 + now.minute / 60 * 80.0 - MediaQuery.of(context).size.height / 3); })`. O `hourHeight` é constante `80.0` no `TimeLineDayView`. Também fazer auto-scroll toda vez que `_selectedDate` mudar para hoje.

### IDs visíveis — pedido do usuário
- 🔴 **Cards não devem exibir IDs, slugs ou strings `[[...]]`** — após análise do código:
  - `_buildTaskCard` no planner: não exibe organizers nem IDs — **OK** como está.
  - `_buildHabitCard`: não exibe organizers — **OK**.
  - `_buildGoogleEventItem`: exibe `event.summary` e horário — **OK**.
  - `_buildTrackingRecordItem`: exibe texto hardcoded `'Tracker Record'` e `'X fields filled'` — **OK**, sem IDs.
  - `_buildJournalEntryItem`: exibe `entry.title` e `'Mood: \${entry.moodSlug}'` — **bug**: `moodSlug` é o ID/slug do mood (ex: `'feliz'`, não o emoji/título). Substituir por buscar o `MoodDefinition` pelo slug e mostrar `mood.emoji + mood.title`, ou omitir se slug não resolver.
  - `_buildTimeBlockSection`: exibe `block.title` e `ranges` de horário — **OK**.
  - `_buildHabitStripItem` na timeline: exibe `habit.displayTitle` — **OK**.
  - **Regra geral**: nunca exibir campos `id`, `slug`, `timeBlock` (ID bruto), `obsidianPath`, `trackerId`. Para organizers, usar sempre `o.title` e deixar vazio se a lista estiver vazia.

### Day View — Agenda Mode
**Falta:**
- 🟡 **Header do bloco clicável** — tocar no nome do bloco abre edição.
- 🟡 **Tasks completadas** — toggle para mostrar/esconder tasks já finalizadas.
- 🟡 **Drag entre blocos** — arrastar task de um bloco para outro (muda `task.timeBlock`).
- 🟢 **Linha do horário atual** — também no modo agenda (não só na timeline).

### Day View — Timeline Mode
**Falta:**
- 🟡 **Google Calendar events visualmente distintos** — já aparecem na timeline, mas verificar se são diferenciados por ícone de calendário.
- 🟡 **Conflitos de horário** — eventos sobrepostos em colunas (já implementado via `groups`/`columns`, verificar edge cases).
- 🟡 **Zoom** — pinch-to-zoom para expandir/comprimir a timeline.
- 🟢 **Eventos all-day** — área separada no topo para hábitos/tasks sem horário.

### Week View
**Falta:**
- 🟡 **Day themes indicados** — mostrar qual tema ativo em cada dia (chip colorido no header).
- 🟡 **Drag entre dias** — arrastar task de um dia para outro.
- 🟢 **Vista de grade** — 7 colunas com timeline vertical.

### Month View
**Falta:**
- 🟡 **42 células quando necessário** — meses que começam na sexta/sábado precisam de 6 semanas.
- 🟡 **Tema do dia** — colorir levemente a célula com a cor do tema ativo.
- 🟢 **Dots de múltiplos tipos** — habit, reminder, além de task e GCal.

### Sensibilidade de arrastar para pesquisar — pedido do usuário
- 🔴 **Pull-to-search muito sensível / disparando sem querer** — o `AppShell` não implementa pull-to-search; o gesto provavelmente está no `HomeScreen` ou num widget de scroll. Localizar onde o `DragGestureRecognizer` ou `NotificationListener<ScrollNotification>` (ou `RefreshIndicator`) está acionando a navegação para `/search`. Aumentar o threshold para ≥ 80px de arrasto antes de disparar, ou substituir completamente por gesto explícito: manter apenas o ícone de busca na AppBar. O `AppShell` já tem atalho `Ctrl+F` / `Cmd+F` → `/search`; no mobile, o ícone na AppBar é suficiente e elimina o falso positivo.

---

## 14. CALENDAR WIDGET (DASHBOARD)

### Pedidos do usuário — estado atual após análise do código

- 🔴 **Remover abas Dia/Sem/Mês → só semana** — `_buildViewToggle()` ainda renderiza 3 abas e `CalendarView` tem 3 valores. Remover completamente o toggle; fixar `_currentView = CalendarView.week`. As setas `<` `>` já navegam semanas e são os únicos controles necessários.

- 🔴 **Substituir toggle por ícone sync + botão `+`** — no header onde estava o toggle, colocar `Row` com: (a) `IconButton(icon: Icon(Icons.sync_rounded))` que dispara sync do Google Calendar e (b) `IconButton(icon: Icon(Icons.add_rounded))` que chama `showCreateMenu(context)`.

- 🔴 **Clicar em dia mostra conteúdo inline (sem bottomsheet)** — `_buildWeekAgenda` já faz isso parcialmente: toca no dia → `_selectedDay` atualiza → tasks aparecem abaixo. **Buracos restantes:** (a) hábitos listados são os `h.status == HabitStatus.active` sem filtro de scheduler do dia selecionado — mostrar só os que deveriam aparecer naquele dia; (b) eventos do Google Calendar do dia não aparecem na lista inline; (c) lembretes do dia não aparecem. O `_showDaySheet` (bottomsheet) chamado no `_buildMonthGrid` pode ser eliminado no modo semana.

- 🔴 **IDs visíveis — `'Sem área'` em branco** — em `_buildAgendaTask`: trocar o fallback `'Sem área'` por `''` para ficar vazio quando não há organizer. Em `_buildHabitRow`: já usa `habit.organizers.first.title` se existir, mas o `Text` ao lado do checkbox exibe esse título — verificar se nenhum organizer retorna slug `[[nome]]` em vez de título resolvido. Regra: suprimir qualquer string que comece com `[[` ou que seja UUID.

### Outros gaps do CalendarWidget
**Falta:**
- 🟡 **Hábitos filtrados por scheduler no grid semanal** — dots e lista do dia devem considerar `SchedulerService.shouldFire` para o dia específico.
- 🟡 **Google Calendar inline** — eventos do GCal aparecem como dot no grid mas não na lista inline do dia selecionado. Usar `ref.watch(googleCalendarEventsProvider(_selectedDay))` na seção de lista.
- 🟡 **Lembretes inline** — adicionar lembretes do dia na lista inline do dia selecionado.
- 🟢 **Formato de data localizado** — confirmar `pt_BR` em todos os `DateFormat`.

---

## 15. SCHEDULER

### SchedulerPicker (UI)
**Falta:**
- 🔴 **`RepeatType.daysOfTheme`** — opção com dropdown para selecionar qual DayTheme.
- 🔴 **`RepeatType.daysWithBlock`** — opção com dropdown para selecionar qual TimeBlock.
- 🟡 **`RepeatType.linkedItemAppears`** e **`nDaysAfterLinkedItem`** — picker de item vinculado.
- 🟡 **Preview de próximas ocorrências** — ao configurar, mostrar próximas 5 datas.
- 🟡 **`exclusions`** — UI para adicionar exclusões (datas em que não deve disparar).
- 🟢 **`OverduePolicy`** — picker para política de overdue (skip/keep/prompt).
- 🟢 **`maxOccurrences`** — limitar número máximo de disparos.
- 🟢 **`exactTime`** — picker de hora exata.

---

## 16. DASHBOARD / HOME SCREEN

### Widgets — gaps internos

**`BlockType.timeBlocking`:**
- 🔴 Deveria mostrar os TimeBlocks do DayTheme ativo com horários como mini-timeline vertical, não só tasks com `scheduledTime`.

**`BlockType.habits`:**
- 🟡 Progresso diário (X/Y), streak visível por hábito, distinção de negativos.

**`BlockType.goals`:**
- 🟡 Deadline próximo destacado, ícone/cor da goal.

**`BlockType.customMarkdown`:**
- 🟡 Editor de markdown configurável por bloco salvo em `metadata`.

**`BlockType.trackerField`:**
- 🟡 Configurável: escolher tracker e campo, mostrar mini-gráfico.

**`BlockType.pinnedObject`:**
- 🟡 Implementação ausente ou básica. Deveria abrir `UniversalDetailView` do objeto pinado com preview inline.

**`BlockType.quotes`:**
- 🟢 Quote hardcoded. Deveria ser pool configurável pelo usuário.

### Edit Mode
- 🟡 **Configurar metadados inline** — ícone de config de cada bloco para abrir configurações específicas.
- 🟡 **Tamanho do widget** — compacto, médio, grande.
- 🟢 **Renomear bloco** no edit mode.

### Dashboard geral
- 🟡 **Pull-to-refresh** para forçar re-sync.
- 🟢 **Persistência por device** — ordem salva no vault pode conflitar entre dispositivos.

---

## 17. POMODORO

### PomodoroScreen
**Falta:**
- 🟡 **Seleção de task vinculada durante sessão** — mudar a task sem sair da tela.
- 🟡 **Histórico visual na tela** — lista dos últimos X pomodoros da sessão.
- 🟡 **Sons/vibração configuráveis** — alerta ao final.
- 🟢 **Notas de sessão** — anotar o que foi feito, salvo no histórico.
- 🟢 **Estatísticas de sessão** — quantos hoje, esta semana, tempo total.
- 🟢 **Background timer** — `PomodoroBackgroundService` existe. Verificar notificação de progresso.

### PomodoroFloatingClock
- 🟢 **Tap para pausar** sem abrir a tela.
- 🟢 **Posição e tamanho configuráveis**.

---

## 18. SYNC / GOOGLE DRIVE / OBSIDIAN

### Google Drive Sync
**Falta:**
- 🟡 **Log de operações de sync** — além da tela de conflitos, um log geral.
- 🟡 **Resolução de conflitos melhorada** — diff lado a lado (local vs remoto).
- 🟢 **Sincronização seletiva** — escolher quais pastas/tipos sincronizar.
- 🟢 **Backup automático** — `backup_service.dart` existe, verificar UI de configuração.

### Obsidian Integration
**Falta:**
- 🟡 **Verificar completude do import** — parsing de frontmatter YAML para todos os tipos.
- 🟡 **Verificar export** — `toMarkdown()` de cada objeto gera YAML Dataview-compatible.
- 🟢 **Dataview queries** — `dataview_generator.dart` existe. UI para mostrar resultados de queries.

---

## 19. SEARCH & NAVIGATION

### Bug identificado pelo usuário — resultado da pesquisa não abre
- 🔴 **Clicar num resultado não abre nada** — analisando o `_buildResultTile`: o `onTap` chama `Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalDetailView(object: obj, ...)))`. O objeto `obj` vem da lista `_results` que foi populada por `_searchService.search(allObjects, query)`. Causas prováveis:
  1. **`allObjectsAsync` ainda `loading` quando o tap ocorre** — `_onSearchChanged` é chamado apenas quando `allObjectsAsync.whenData(...)` resolve. Se o provider ainda está carregando, `_results` fica vazio e nenhum tile aparece. Mas se aparecem tiles, os objetos existem.
  2. **`Navigator.push` no contexto errado** — `SearchScreen` usa `AppBar` com `leading: IconButton(onPressed: () => Navigator.pop(context))`, o que indica que é empurrada via `Navigator.push`. O contexto deve estar correto.
  3. **`GoRouter` interceptando** — o app usa `GoRouter` (`app_shell.dart` usa `GoRouterState.of(context)`). Se `SearchScreen` for aberta via `context.go('/search')` em vez de `Navigator.push`, o `Navigator.push` dentro dela pode estar tentando empurrar sobre uma rota gerenciada pelo GoRouter e sendo silenciado. **Solução**: substituir `Navigator.push` em `_buildResultTile` por `context.push('/detail/\${obj.id}')` do GoRouter, ou verificar se existe rota `/detail/:id` registrada e testar com `context.go`.
  4. **`UniversalDetailView` não reconhece o tipo** — se o objeto for de um tipo sem case no switch do `UniversalDetailView`, pode retornar tela em branco. Verificar se todos os tipos retornados pela busca têm tratamento.

### Bug identificado pelo usuário
- 🔴 **Pull-to-search muito sensível** — ver item 13 (Planner). Mesmo problema se o gesto de abrir busca é via pull-down na home/planner. Aumentar threshold ou mudar para gesto explícito.

### SearchScreen
**Falta:**
- 🟡 **Busca full-text** — buscar também no body/notes de notas, journal, tasks.
- 🟡 **Busca por tag** — digitar `#tag`.
- 🟡 **Busca por organizer** — digitar `@projeto`.
- 🟡 **Ação rápida nos resultados** — completar task, marcar hábito, diretamente do resultado.
- 🟢 **Recentes persistentes** — `_recentSearches` é hardcoded com 3 strings fixas. Persistir no storage.
- 🟢 **Resultados agrupados por tipo**.

### CommandCenter (overlay)
**Falta:**
- 🟡 **Comandos de navegação** — `/planner`, `/habits`, `/notes`.
- 🟡 **Criar objeto por linguagem natural** — "nova tarefa [título]".

---

## 20. SETTINGS & APPEARANCE

### Pedido do usuário — Color Picker global
- 🔴 Ver item 26 separado. **Regra global: nunca pedir HEX. Sempre picker visual.**

### AppearanceScreen
**Falta:**
- 🟡 **Temas de cor personalizados** — cor primária (accent color) do app.
- 🟡 **Preview em tempo real** das configurações.
- 🟢 **Tamanho de fonte**.
- 🟢 **Ícone do app alternativo** (iOS/Android).

### SettingsScreen
**Falta:**
- 🟡 **Configuração de Pomodoro** — duração work/short break/long break.
- ✅ **Configuração de mood** — `mood_settings_screen.dart` implementado:
  - Limite de 15 humores com mensagem ao tentar exceder
  - `_MoodHeader` mostra `X/15 configurados`, lista de valores faltando e barra de progresso
  - Próximo valor disponível pré-preenchido ao criar novo humor
  - Validação de duplicata de valor numérico
  - Valor numérico em destaque em cada tile
  - Undo ao deletar
- 🔴 **`color` picker no form de mood** — o campo ainda é TextField de HEX (`'Cor hex (ex: #9E9E9E)'`) no `AlertDialog` de edição. Substituir por picker visual (ver item 26).
- 🟡 **Configuração de categorias** — `category_management_screen.dart` existe, verificar completude.
- 🟢 **Exportar todos os dados** — ZIP de todos os markdowns.
- 🟢 **Importar de backup**.
- 🟢 **Limpar dados** com confirmação dupla.

---

## 21. ARCHIVE, TRASH & INBOX

### Archive Screen
**Falta:**
- 🟡 **Filtro por tipo**.
- 🟡 **Restaurar em lote**.
- 🟢 **Data de arquivamento**.

### Deleted Files Screen
**Falta:**
- 🟡 **Período de retenção** — itens por X dias antes de deletar permanentemente.
- 🟡 **Preview do item** — ver conteúdo antes de restaurar/deletar.
- 🟢 **Esvaziar lixeira** com confirmação dupla.

### InboxScreen
**Falta:**
- 🟡 **Triagem GTD** — processar cada item: converter em task, nota, lembrete, arquivar, deletar.
- 🟢 **Badge de contagem** na nav.

---

## 22. TEMPLATES

**Falta (praticamente tudo):**
- 🔴 **Lista de templates** — tela para ver, criar, editar templates.
- 🔴 **Templates de diário aplicáveis** — picker no form de JournalEntry com estrutura de perguntas pré-definidas.
- 🟡 **Templates por tipo** — task, nota, goal, tracker.
- 🟡 **Aplicar template no form** — opção "Usar template" que pré-preenche.
- 🟢 **Compartilhar templates** — exportar/importar como JSON.

---

## 23. ORGANIZER

### OrganizerDetailScreen
**Falta:**
- 🟡 **Layout por subtipo** — project abre com kanban, área abre com lista.
- 🟡 **Todos os itens vinculados** — tasks, notes, goals, habits com esse organizer.
- 🟢 **Criar sub-organizer** dentro de uma área.

### Organizer Chips / Picker
- 🟡 **Criar novo organizer inline** — "Criar '[nome]' como projeto/área" ao digitar nome novo.

---

## 24. KPI & ANALYSIS

**Falta:**
- 🟡 **KPI screen** — tela dedicada de gerenciamento e visualização.
- 🟡 **KPI com fonte automática** — vincular a campo de tracker, streak de hábito, contagem de tasks.
- 🟡 **Histórico de KPI** — registrar valor ao longo do tempo para trending.

### CombinedAnalysisScreen / StatisticsScreen
**Falta:**
- 🟡 **Filtro por período** — semana, mês, 3 meses, 1 ano, personalizado.
- 🟡 **Comparação de períodos** — esta semana vs semana passada.
- 🟢 **Correlações** — hábitos vs mood, foco vs tasks concluídas.
- 🟢 **Export de dados**.

---

## 25. NOTIFICATIONS

**Falta:**
- 🟡 **Notificações para todos os tipos** — tasks com deadline, habits sem check, goals vencendo, pessoas para contatar.
- 🟡 **Notificações com ações** — completar task/habit direto da notificação.
- 🟡 **Scheduled notifications para schedulers** — agendar localmente para próximas ocorrências.
- 🟢 **Agrupamento** — no Android, notification group.
- 🟢 **Popup notifications** — `popup_notification_screen.dart` existe. Verificar integração enquanto app está aberto.

---

## 26. COLOR PICKER (GLOBAL)

### Pedido do usuário
- 🔴 **Nunca pedir HEX. Sempre picker visual.** Regra que se aplica a todos os pontos do app onde há seleção de cor:
  - Moods (`mood_settings_screen.dart`) — campo HEX atual deve ser substituído
  - TimeBlock (form de criação/edição)
  - DayTheme (form de criação/edição)
  - Task, Habit, Goal, Note, Project, Organizer — onde `color` está exposto

**Solução sugerida:** Criar um `AppColorPicker` widget reutilizável com:
- **Paleta de cores predefinidas** — grid de ~20 cores com boa distribuição (ex: Material colors ou paleta customizada do app)
- **Opção "personalizada"** — só se o usuário escolher esta opção, mostrar o color wheel ou o campo HEX, com preview em tempo real
- O widget deve retornar `String` (hex normalizado como `#RRGGBB`)
- Uso via `showModalBottomSheet` ou `showDialog` com preview da cor selecionada ao lado do nome

---

## 27. 

## 28. ACCESSIBILITY & POLISH GERAL

### Acessibilidade
- 🟡 **Semantics** — todos os cards, botões e campos interativos precisam de `Semantics` com `label`, `value`, `button`, `hint`.
- 🟡 **Tamanho mínimo de toque** — 44x44dp para todos os elementos interativos.
- 🟢 **Contraste WCAG AA** — verificar tema dark/light.
- 🟢 **VoiceOver / TalkBack** — teste com screen reader.

### Empty States
- 🟡 **Illustrations** — cada tela principal com empty state específico e call-to-action claro.
- 🟡 **Onboarding** — hints na primeira visita a cada tela principal.

### Loading & Errors
- 🟡 **Skeleton loading** — estender para listas de tasks, habits, notes.
- 🟡 **Error states específicos** — sync falhou, vault não encontrado, permissão negada, com ação de retry.

### Animações & Micro-interações
- 🟡 **Completar task** — scale + fade ao marcar como done.
- 🟡 **Completar hábito** — animação de streak ao completar.
- 🟢 **Shared element transitions** — ao abrir detalhe de objeto.
- 🟢 **Pull-to-refresh animado**.

### Formulários
- 🟡 **Dismiss com confirmação** — "Descartar alterações?" ao fechar form com dados.
- 🟡 **Keyboard avoidance** — garantir que teclado não cobre o campo sendo editado.
- 🟢 **Validação em tempo real**.
- 🟢 **Auto-focus** — cursor direto no primeiro campo ao abrir form.

### UX de Deleção
- ✅ Undo snackbar para tasks — implementado com `UndoService`
- ✅ Undo snackbar para moods — implementado no `_confirmDeleteMood`
- 🟡 **Undo snackbar** — estender para habits, notes, goals, reminders, journal entries.
- 🟡 **Swipe to delete/archive** — implementar consistentemente em todas as listas.

---

## RESUMO DE PRIORIDADES

### 🔴 Crítico — bugs ou fluxo principal quebrado
1. ~~Mood settings: limite de 15, valor numérico visível, header de progresso~~ ✅ implementado — **falta apenas**: substituir campo HEX de cor por picker visual
2. Hábito com múltiplos slots no **modo agenda** do planner: cada slot precisa de linha + botão separado (timeline já está correto)
3. Planner não auto-scrolla para o horário atual ao abrir
4. Pull-to-search disparando sem querer — aumentar threshold ou remover gesto
5. Pesquisa: clicar num resultado não abre nada — provável conflito `Navigator.push` vs `GoRouter`
6. IDs visíveis: `entry.moodSlug` exibido como texto no card de journal (Planner). Texto `'Sem área'` no CalendarWidget deve ser `''`
7. CalendarWidget: remover toggle Dia/Sem/Mês → fixar semana + ícone sync + botão `+`
8. CalendarWidget: lista inline do dia não inclui eventos GCal nem lembretes
9. TimeBlock/DayTheme: sem tela de edição (tocar não faz nada)
10. SchedulerPicker: `daysOfTheme` e `daysWithBlock` não expostos na UI
11. Color picker: substituir HEX por picker visual em todo o app (moods, blocks, themes, habits, tasks, goals)
12. 
13. Análise: dias sem registro aparecem como zero na linha — `_getValueForDate` deve retornar `null`, `CitrineChart` deve filtrar spots nulos

### 🟡 Importante — experiência incompleta
11. `dependsOn` picker no form de Task
12. `estimatedMinutes` e `timeBlock` picker no form de Task
13. Múltiplos TimeRanges por bloco na criação
14. Múltiplos slots no form de Habit + renderização separada no planner
15. Social: seção de objetos vinculados por tipo no form e no detalhe
16. Planner: header de bloco clicável para editar
17. Person: ações rápidas (ligar, email, WhatsApp)
18. Tracker record form: renderização por tipo de campo
19. Goal: KPIs + progress bar no detalhe
20. Template de diário aplicável no form

### 🟢 Melhoria — polimento
21. Empty states com ilustrações
22. Skeleton loading generalizado
23. Swipe to delete/archive consistente
24. Animações de completar task/habit
25. Export CSV de trackers e highlights
26. Configuração de cores do tema (accent color)
27. Recentes persistentes na busca

---

## 29. ANÁLISE — GAPS DE DADOS / DIAS SEM REGISTRO

### Pedido do usuário
- 🔴 **Dias sem registro no tracker não devem aparecer como zero — devem interromper a linha e retomar quando houver dado de novo.**

### Diagnóstico exato

Em `_getMetricData()` no `CombinedAnalysisScreen`, para cada um dos 14 dias é chamado `_getValueForDate()`, que retorna `0.0` quando não há registro. Esse `0.0` é passado para o `CitrineChart` como `FlSpot(x, 0.0)`, fazendo a linha despencar para o zero nesses dias.

No `CitrineChart._buildLineChart()`, todos os pontos de todas as séries são passados diretamente como `spots` no `LineChartBarData`, sem nenhuma distinção entre "valor real zero" e "sem dado".

### O que precisa mudar

**1. Diferenciar "sem dado" de "valor zero"**

`_getValueForDate()` retorna `double`. Mudar o retorno para `double?` — retornar `null` quando não há registro e o valor numérico real (incluindo `0.0`) quando há.

Todos os métodos de coleta precisam acompanhar:
- `_getMoodValueForDate` → retorna `null` se `dayEntries.isEmpty` ou nenhum mood
- `_getHabitValueForDate` → retorna `null` se o hábito não existe ou não tem registro; `1.0` se completou; `0.0` só se explicitamente registrado como não feito (se o design quiser)
- `_getTrackerValueForDate` → retorna `null` se `dayRecords.isEmpty` para aquele tracker/campo
- `_getTrackerScoreForDate` → retorna `null` se sem registros
- `_getPomodoroValueForDate` → retorna `null` se sem sessões completadas no dia (não `0.0`)
- `_getGoogleEventValueForDate` → manter `0.0` pois "0 eventos" é um dado válido (ou tratar como `null` se sem eventos, dependendo da intenção da usuária)

**2. `ChartDataPoint` aceitar valor nulo**

```dart
class ChartDataPoint {
  final String label;
  final double? value; // null = sem dado
  final Color? color;
}
```

**3. `CitrineChart._buildLineChart()` pular pontos nulos**

Na construção dos `spots`, filtrar os pontos com `value == null` e não incluí-los na série:

```dart
spots: d
    .asMap()
    .entries
    .where((e) => e.value.value != null)   // pular dias sem dado
    .map((e) => FlSpot(e.key.toDouble(), e.value.value!))
    .toList(),
```

Com isso, o `fl_chart` automaticamente desenha a linha apenas entre os pontos existentes, deixando um espaço visual (linha interrompida) nos dias sem dado. Se a lista de spots ficar vazia para uma série inteira, o `LineChartBarData` não deve ser adicionado (ou adicionar com `spots: []` que o `fl_chart` ignora silenciosamente).

**4. Ponto visual diferenciado (opcional mas recomendado)**

Para deixar claro para a usuária que a linha foi interrompida por falta de dado (e não porque o valor foi zero), adicionar um dot de cor diferente no último ponto antes da lacuna e no primeiro depois — ou simplesmente garantir que `dotData: FlDotData(show: true)` esteja ativo para séries com gaps.

**5. `_buildBarChart()` — mesmo tratamento**

Barras de valor `0.0` ficam invisíveis mas ocupam espaço no eixo X, criando confusão. Para dias sem dado, não criar `BarChartGroupData` para aquele índice — ou criar com altura zero e cor transparente para manter o espaçamento do eixo X (dependendo da preferência visual).

**6. Calendário de análise (`AnalysisCalendar`)**

Em `_getCalendarData()`, a condição atual é `if (value > 0)` para adicionar a fonte ao dia. Isso já filtra os dias com `value == 0`, mas com a mudança para `double?`, a condição deve ser `if (value != null)` para que dias com valor real `0.0` ainda apareçam no calendário se forem dados legítimos.

### Impacto em outros gráficos

- **`StatisticsScreen`** — se usa `CitrineChart` ou lógica similar de coleta de dados, aplicar o mesmo padrão.
- **`TrackerMetricCard`** (`tracker_metric_card.dart`) — se exibe sparkline do tracker, verificar se também trata ausência de dado como zero ou como gap.
- **Heatmap** (`ChartType.heatmap`) — células sem dado (`value == null`) devem usar a cor de "vazio" (`surfaceVariant`), não a cor de intensidade zero da série. Atualmente já faz isso via `intensity > 0`, mas com `null` o tratamento fica mais explícito.


---

## 29. HOME SCREEN — GAPS ADICIONAIS ENCONTRADOS

### Pull-to-search (CommandCenter)
- 🔴 **Threshold de -80px é muito baixo** — o `ScrollUpdateNotification` dispara o `showCommandCenter` com apenas 80px de overscroll na física `BouncingScrollPhysics`. Em scroll rápido ou rebote do final da lista isso dispara acidentalmente. Aumentar para pelo menos -140px e adicionar flag `_commandCenterOpenedThisScroll` que previne múltiplas aberturas na mesma sequência de scroll.

### BlockType.timeBlocking — conteúdo errado
- 🔴 **`_buildTimeBlockingBlock()` mostra tasks com `scheduledTime`, não TimeBlocks do DayTheme** — o bloco mostra tarefas com horário agendado do dia, mas o nome "Time Blocks" promete mostrar os blocos do tema ativo. Deve ser refatorado para mostrar: tema do dia ativo + seus blocos com faixas de horário + count de tasks por bloco.

### BlockType.customMarkdown — conteúdo hardcoded
- 🔴 **`_buildCustomMarkdownBlock()` retorna string hardcoded** — "Reminder: Drink water, Stretch every hour". Não há mecanismo de edição. O bloco precisa de `metadata['markdownContent']` salvo no `DashboardBlock` e um botão de editar que abre um campo de texto.

### BlockType.quotes — hardcoded
- 🔴 **`_buildQuoteBlock()` retorna quote hardcoded** — Peter Drucker. Sem rotação, sem pool de quotes do usuário. Adicionar `metadata['quotes']` como lista e exibir uma aleatória a cada abertura do app, com botão de adicionar/remover quotes na configuração do bloco.

### BlockType.analysisTrend — cálculo impreciso
- 🟡 **`_buildAnalysisBlock()` calcula consistency incorretamente** — divide total de streaks por `habits.length * 7`, o que é uma heurística muito aproximada. Deveria usar `completionHistory` dos últimos 7 dias reais para calcular taxa de conclusão.

### BlockType.habitTrend — dados aproximados
- 🟡 **`_buildHabitHeatmapBlock()` usa `daysSinceLastCompletion` para estimar completions passados** — isso não reflete o histórico real. Deveria iterar `habit.completionHistory` para construir o mapa de atividade dos últimos 28 dias.

### BlockType.pinnedObject — sem implementação real
- 🟡 **`_buildPinnedObjectBlock()` não foi encontrado no código lido** — o método é chamado no switch do `_buildBlock()` mas sua implementação pode estar faltando ou ser mínima. Implementar como: picker de qualquer objeto via `UniversalSearchPickerSheet`, salvo no `metadata['pinnedId']`, exibindo preview inline do objeto (título, subtítulo, ícone de tipo) com tap para abrir `UniversalDetailView`.

### Dashboard — pull-to-refresh ausente
- 🟡 **Não há `RefreshIndicator` ou mecanismo de pull-to-refresh** — o usuário não tem como forçar reload dos dados sem fechar e reabrir o app. Adicionar `RefreshIndicator` no `CustomScrollView` ou botão de refresh no header.

### Dashboard — `_buildSyncIndicator` não acessa todos os conflitos
- 🟢 **O tooltip de conflito mostra count mas o ícone de `SyncStatus.offline` é igual ao de `error`** — diferenciar visualmente os dois estados (ex: `cloud_off` para offline, `sync_problem` para error).

---

## 30. UNIVERSAL DETAIL VIEW — GAPS

Não foi possível ler o arquivo completo, mas com base nos `Navigator.push` para `UniversalDetailView` por todo o app, identificamos:

- 🔴 **Edição inline ausente para a maioria dos tipos** — o detalhe provavelmente só exibe dados, sem edição inline de campos individuais (título, notas, body). Cada tipo deveria ter campos editáveis diretamente no detalhe sem precisar abrir um form modal separado.
- 🔴 **`TrackingRecord` no detalhe** — `_buildTrackingRecordItem` no planner abre `UniversalDetailView(object: record)`. Verificar se o detalhe de `TrackingRecord` renderiza os `fieldValues` de forma legível (nome do campo + valor) e não apenas "X fields filled".
- 🟡 **Ações contextuais por tipo** — o `ObjectActionWrapper` existe para long-press. Verificar se as ações de cada tipo (completar task, toggle habit, arquivar, deletar, duplicar) estão todas implementadas e consistentes.
- 🟡 **Navegação para organizers** — chips de organizer no detalhe devem ser clicáveis e navegar para o detalhe do organizer.
- 🟢 **Compartilhar objeto** — botão de share que gera um texto/card exportável do objeto.

---

## 31. FORMS — GAPS TRANSVERSAIS ENCONTRADOS

Revisando os formulários encontrados:

### SchedulerPicker — dentro dos forms
- 🔴 **`RepeatType.daysOfTheme` e `daysWithBlock`** — já listado no item 15, mas confirmado: esses tipos existem no `SchedulerService` mas não há evidência de que o `SchedulerPicker` os expõe. Todos os forms que têm scheduler (task, habit, reminder, goal) estão afetados.

### Color picker nos forms (item 26)
- 🔴 **Mood settings usa campo de texto HEX** — confirmado no `mood_settings_screen.dart`: `TextField(controller: colorController, decoration: InputDecoration(labelText: 'Cor hex (ex: #9E9E9E)'))`. Substituir por `AppColorPicker` visual.

### Forms sem dismiss confirmation
- 🟡 **Nenhum form tem "Descartar alterações?"** — ao tocar fora ou pressionar voltar com campos preenchidos, o form fecha silenciosamente. Adicionar `WillPopScope` ou `PopScope` que detecta campos sujos e pergunta antes de fechar.

### Auto-scroll no keyboard
- 🟡 **Formulários longos podem ter campos ocultos pelo teclado** — verificar se todos os forms usam `SingleChildScrollView` com `keyboardDismissBehavior` adequado ou `resizeToAvoidBottomInset`.

---

## 32. MOOD — GAPS ADICIONAIS ENCONTRADOS

Após análise do `mood_settings_screen.dart`:

### O que já está implementado ✅
- ✅ Limite de 15 humores com bloqueio do botão "Adicionar"
- ✅ Header `_MoodHeader` mostra `X/15 configurados`, barra de progresso e valores faltando
- ✅ Valor numérico visível no tile de cada mood (bloco colorido com número)
- ✅ Validação de valor duplicado ao salvar
- ✅ Auto-sugestão do próximo valor disponível
- ✅ Undo snackbar ao deletar mood com restauração

### O que ainda falta
- 🔴 **Color picker visual** — campo de texto HEX no dialog de edição. Substituir por grid de cores predefinidas + opção de personalizar (ver item 26).
- 🟡 **Cor hardcoded no tile** — `_MoodTile` exibe o hex como texto (`mood.color`). Substituir por apenas o dot colorido sem mostrar o código hex ao usuário.
- 🟡 **Preview da cor ao selecionar** — ao escolher cor no picker, mostrar preview do emoji com fundo colorido em tempo real antes de salvar.
- 🟡 **Reorder via drag** — `ReorderableListView` existe, mas a ordem de `sortedMoods` é sempre por `numericValue`, o que torna o drag ineficaz (a lista reordena, salva `order`, mas na próxima build re-sort por `numericValue`). Ou: reorder por `numericValue` (trocar os valores), ou: manter ordem por `order` apenas e não por `numericValue`. Clarificar semântica: o `numericValue` é um campo de escala (1-15) separado da ordem de exibição?
- 🟢 **Emoji picker** — campo livre de texto para emoji. Substituir por um seletor de emoji com grid ou picker nativo.

---

## RESUMO FINAL DE PRIORIDADES (ATUALIZADO)

### 🔴 Crítico — bugs ou fluxo quebrado
1. Hábito com múltiplos slots: completar um completa todos
2. Pesquisa: clicar num resultado não abre nada
3. IDs/slugs visíveis nos cards (Planner, CalendarWidget, Social)
4. Planner não abre no horário atual — sem auto-scroll
5. Pull-to-search muito sensível (threshold -80px)
6. CalendarWidget: remover toggles Dia/Sem/Mês → só semana + sync icon + botão +
7. TimeBlock/DayTheme: sem tela de edição ao tocar
8. SchedulerPicker: sem `daysOfTheme`/`daysWithBlock`
9. Color picker: substituir campo HEX por picker visual em TODO o app (moods confirmado)
10. `_buildTimeBlockingBlock()`: conteúdo errado (tasks com scheduledTime, não TimeBlocks do DayTheme)
11. `_buildCustomMarkdownBlock()`: conteúdo hardcoded, sem edição
12. `_buildQuoteBlock()`: quote hardcoded, sem pool configurável
13. Social: seção de objetos vinculados por tipo no form e no detalhe
14. Highlights/citações de livros: model + UI básica (Readwise-style)
15. `timeBlocks` não passado ao `TimeLineDayView` — bands podem não aparecer

### 🟡 Importante — experiência incompleta
16. Mood: color picker visual + não mostrar hex no tile + fix de reorder vs numericValue
17. Mood: emoji picker em vez de campo de texto
18. `dependsOn` picker no form de Task
19. `estimatedMinutes` e `timeBlock` picker no form de Task
20. Múltiplos TimeRanges por bloco
21. Múltiplos slots no form de Habit + renderização separada por slot no planner
22. KPIs + progress bar no detalhe de Goal
23. Template de diário aplicável no form
24. Person: ações rápidas (ligar, email, WhatsApp) + status de contato
25. Tracker record form: renderização por tipo de campo
26. Dashboard pull-to-refresh
27. `_buildHabitHeatmapBlock()` usando histórico real
28. `_buildAnalysisBlock()` com cálculo correto de consistency
29. `_buildPinnedObjectBlock()` implementação completa
30. Forms: dismiss confirmation ("Descartar alterações?")
31. TrackingRecord detail: renderizar fieldValues legível

### 🟢 Melhoria — polimento
32. Empty states com ilustrações específicas por tela
33. Skeleton loading generalizado (além do dashboard)
34. Swipe to delete/archive consistente em todas as listas
35. Animações de completar task/habit (scale + fade, confetti)
36. Export CSV de trackers e highlights
37. Configuração de accent color do app
38. Recentes persistentes na busca
39. Sync indicator: diferenciar offline vs error visualmente
40. Compartilhar objeto do detalhe