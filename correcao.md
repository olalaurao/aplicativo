# GAP ANALYSIS COMPLETO Ã¢â‚¬â€ APLICATIVO
> Atualizado em 04/06/2026. Baseado em anÃƒÂ¡lise completa dos arquivos do repositÃƒÂ³rio + pedidos de usuÃƒÂ¡ria.
> Ã¢Å“â€¦ = jÃƒÂ¡ implementado | Ã°Å¸â€Â´ = crÃƒÂ­tico | Ã°Å¸Å¸Â¡ = importante | Ã°Å¸Å¸Â¢ = melhoria

---

## ÃƒÂNDICE

1. [Task (Tarefa)](#1-task)
2. [Habit (HÃƒÂ¡bito)](#2-habit)
3. [Goal (Meta)](#3-goal)
4. [Note (Nota)](#4-note)
5. [Journal Entry (Entrada de DiÃƒÂ¡rio)](#5-journal-entry)
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

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **Campo `estimatedMinutes`** Ã¢â‚¬â€ existe no model mas nÃƒÂ£o hÃƒÂ¡ picker. Deveria ser campo numÃƒÂ©rico com sugestÃƒÂµes rÃƒÂ¡pidas (15 / 30 / 60 / 90 min) ao lado do `duration`.
- Ã°Å¸â€Â´ **Campo `timeBlock`** Ã¢â‚¬â€ `initialTimeBlock` ÃƒÂ© passado programaticamente mas nÃƒÂ£o hÃƒÂ¡ picker manual no form para o usuÃƒÂ¡rio escolher/mudar o bloco. Deveria ser um dropdown ou chip do bloco ativo do dia.
- Ã°Å¸â€Â´ **Campo `dependsOn`** Ã¢â‚¬â€ existe no model mas o form nÃƒÂ£o expÃƒÂµe nenhum picker de dependÃƒÂªncias. Deveria ser um campo de busca de tarefas com multi-seleÃƒÂ§ÃƒÂ£o via wiki-link.
- Ã°Å¸Å¸Â¡ **Campo `participants` e `places`** Ã¢â‚¬â€ existem no model como `OrganizerReference`, nÃƒÂ£o aparecem no form. Precisam de `OrganizerSelectorField` multi-seleÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Stage selector visual** Ã¢â‚¬â€ deveria ser pipeline horizontal de chips (Idea Ã¢â€ â€™ Todo Ã¢â€ â€™ In Progress Ã¢â€ â€™ Pending Ã¢â€ â€™ Done) em vez de dropdown.
- Ã°Å¸Å¸Â¡ **`color` picker** Ã¢â‚¬â€ o model suporta cor por tarefa, mas nÃƒÂ£o hÃƒÂ¡ color picker. Quando implementado, seguir padrÃƒÂ£o visual (ver item 26).
- Ã°Å¸Å¸Â¢ **`untilDone` toggle** Ã¢â‚¬â€ nÃƒÂ£o estÃƒÂ¡ claro se aparece no form. Deveria ser um toggle explicado ("Repetir atÃƒÂ© concluir").
- Ã°Å¸Å¸Â¢ **`socialRefs`** Ã¢â‚¬â€ sem picker no form.

### Tela de detalhe / ediÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **EdiÃƒÂ§ÃƒÂ£o inline de subtasks** Ã¢â‚¬â€ deveria ser editÃƒÂ¡vel diretamente no detalhe (adicionar, remover, reordenar, marcar) sem abrir form separado.
- Ã°Å¸â€Â´ **`dependsOn` no detalhe** Ã¢â‚¬â€ mostrar quais tarefas bloqueiam esta task, com link direto para cada uma e indicador de status.
- Ã°Å¸Å¸Â¡ **Progress de subtasks** Ã¢â‚¬â€ barra `X/Y subtasks` no topo do detalhe.
- Ã°Å¸Å¸Â¡ **Timer de Pomodoro vinculado** Ã¢â‚¬â€ botÃƒÂ£o "Ã¢â€“Â¶ Focus" no detalhe que abre o Pomodoro jÃƒÂ¡ vinculado.
- Ã°Å¸Å¸Â¡ **Estimado vs realizado** Ã¢â‚¬â€ comparativo "Estimado: 60min | Realizado: 45min".
- Ã°Å¸Å¸Â¢ **Links do Google Calendar** Ã¢â‚¬â€ se a task tem `linkedGoogleEventId`, exibir card com link para abrir no Calendar.
- Ã°Å¸Å¸Â¢ **`reflection`** Ã¢â‚¬â€ sÃƒÂ³ ÃƒÂ© preenchido via popup pÃƒÂ³s-conclusÃƒÂ£o. Deveria ser acessÃƒÂ­vel tambÃƒÂ©m na ediÃƒÂ§ÃƒÂ£o direta.
- Ã°Å¸Å¸Â¢ **HistÃƒÂ³rico de mudanÃƒÂ§as de stage** Ã¢â‚¬â€ data em que foi movida para cada estÃƒÂ¡gio.

### Lista
**Falta:**
- Ã°Å¸Å¸Â¡ **Filtros persistentes** Ã¢â‚¬â€ por stage, prioridade, tag, organizer, prazo.
- Ã°Å¸Å¸Â¡ **Agrupamento** Ã¢â‚¬â€ por stage, prioridade, projeto, data.
- Ã°Å¸Å¸Â¡ **Quick-complete com swipe** Ã¢â‚¬â€ swipe right para completar, swipe left para deletar/arquivar.
- Ã°Å¸Å¸Â¡ **Indicador de tarefas bloqueadas** Ã¢â‚¬â€ ÃƒÂ­cone de cadeado e tooltip mostrando o que bloqueia.
- Ã°Å¸Å¸Â¢ **Drag-to-reorder na lista principal** (nÃƒÂ£o sÃƒÂ³ no planner).
- Ã°Å¸Å¸Â¢ **Badge de subtasks** Ã¢â‚¬â€ "3/5" no card da lista.

---

## 2. HABIT

### Bug identificado pelo usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Completar um slot completa todos Ã¢â‚¬â€ VERIFICADO COMO JÃƒÂ CORRIGIDO** Ã¢â‚¬â€ `TimeLineDayView` chama `onHabitToggle: (habit, slotIndex)` corretamente com ÃƒÂ­ndice por slot. O `_buildHabitBlock` na timeline passa `slotIndex` para o checkbox. `_isHabitSlotCompleted` usa `slotCompletions` do `CompletionRecord`.
- Ã°Å¸â€Â´ **Modo agenda (fora da timeline) ainda nÃƒÂ£o renderiza slots separados** Ã¢â‚¬â€ `_buildHabitCard` e `_buildHabitItem` no planner (modo agenda, nÃƒÂ£o timeline) ainda chamam `toggleHabit(habit, _selectedDate)` sem `slotIndex` e nÃƒÂ£o expandem os slots. HÃƒÂ¡bito com mÃƒÂºltiplos slots aparece como um ÃƒÂºnico item. Cada slot precisa ser uma linha separada com seu botÃƒÂ£o de completar chamando `toggleHabit(habit, date, slotIndex: i)`.

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **`inputType` picker completo** Ã¢â‚¬â€ o model tem `HabitInputType` (boolean, numeric, mood, duration). Para `numeric`: campos `completionUnit` e `dailyGoal`. Para `duration`: meta em minutos.
- Ã°Å¸â€Â´ **MÃƒÂºltiplos schedulers** Ã¢â‚¬â€ o model tem `List<Scheduler>`. O form provavelmente sÃƒÂ³ cria um.
- Ã°Å¸Å¸Â¡ **MÃƒÂºltiplos slots no form** Ã¢â‚¬â€ suporta `List<HabitSlot>`. BotÃƒÂ£o "Adicionar slot" com label e horÃƒÂ¡rio para cada um.
- Ã°Å¸Å¸Â¡ **`linkedTrackerSlug`** Ã¢â‚¬â€ picker para vincular hÃƒÂ¡bito a um tracker.
- Ã°Å¸Å¸Â¡ **`icon` picker** Ã¢â‚¬â€ grid de ÃƒÂ­cones para o usuÃƒÂ¡rio escolher.
- Ã°Å¸Å¸Â¡ **`color` picker** Ã¢â‚¬â€ seguir padrÃƒÂ£o visual (ver item 26).
- Ã°Å¸Å¸Â¢ **`habitStartDate`** Ã¢â‚¬â€ data de inÃƒÂ­cio para cÃƒÂ¡lculo correto do streak.

### Tela de detalhe
**Falta:**
- Ã°Å¸â€Â´ **Completar por slot no detalhe** Ã¢â‚¬â€ cada slot listado separadamente com botÃƒÂ£o de completar prÃƒÂ³prio, label e horÃƒÂ¡rio.
- Ã°Å¸Å¸Â¡ **GrÃƒÂ¡fico de histÃƒÂ³rico** Ã¢â‚¬â€ heatmap mensal dos ÃƒÂºltimos 30/90 dias.
- Ã°Å¸Å¸Â¡ **Streak visual** Ã¢â‚¬â€ contador com "Melhor streak: X dias", "Streak atual: Y dias".
- Ã°Å¸Å¸Â¡ **EdiÃƒÂ§ÃƒÂ£o do histÃƒÂ³rico** Ã¢â‚¬â€ corrigir registro passado retroativamente.
- Ã°Å¸Å¸Â¢ **`linkedTrackerSlug`** Ã¢â‚¬â€ botÃƒÂ£o para abrir o tracker correspondente.
- Ã°Å¸Å¸Â¢ **Status de pausa** Ã¢â‚¬â€ toggle para `HabitStatus.paused` sem deletar.

### HabitsScreen (lista)
**Falta:**
- Ã°Å¸Å¸Â¡ **Progresso diÃƒÂ¡rio geral** Ã¢â‚¬â€ header "X de Y hÃƒÂ¡bitos completos hoje" com barra.
- Ã°Å¸Å¸Â¡ **Agrupamento por status** Ã¢â‚¬â€ ativos, pausados, arquivados.
- Ã°Å¸Å¸Â¢ **Filtro por scheduler** Ã¢â‚¬â€ mostrar sÃƒÂ³ hÃƒÂ¡bitos de hoje.
- Ã°Å¸Å¸Â¢ **Reorder persistente**.
- Ã°Å¸Å¸Â¢ **HÃƒÂ¡bitos negativos** Ã¢â‚¬â€ seÃƒÂ§ÃƒÂ£o separada ou badge diferente.

---

## 3. GOAL

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **KPIs inline no form** Ã¢â‚¬â€ o model tem `List<KPI>` mas o form nÃƒÂ£o permite adicionar KPIs na criaÃƒÂ§ÃƒÂ£o. Precisam de editor inline: nome, target, unidade, tipo de mÃƒÂ©trica.
- Ã°Å¸Å¸Â¡ **`schedulers`** Ã¢â‚¬â€ goals podem ter schedulers (metas recorrentes), mas o form provavelmente nÃƒÂ£o expÃƒÂµe.
- Ã°Å¸Å¸Â¡ **`repeatInterval`** Ã¢â‚¬â€ campo livre deveria ser picker tipado (weekly/monthly/yearly/custom).
- Ã°Å¸Å¸Â¡ **`icon` e `color` picker** Ã¢â‚¬â€ ver item 26.
- Ã°Å¸Å¸Â¡ **VinculaÃƒÂ§ÃƒÂ£o de tasks existentes** Ã¢â‚¬â€ ao criar goal, buscar e vincular tasks existentes como milestones.
- Ã°Å¸Å¸Â¢ **`state` selector** Ã¢â‚¬â€ active/on hold/cancelled acessÃƒÂ­vel no form de ediÃƒÂ§ÃƒÂ£o.

### Tela de detalhe
**Falta:**
- Ã°Å¸â€Â´ **KPIs dinÃƒÂ¢micos** Ã¢â‚¬â€ cada KPI com valor atual, target e progresso visual.
- Ã°Å¸â€Â´ **Progress bar geral** Ã¢â‚¬â€ calculado a partir das subtasks, exibido no topo.
- Ã°Å¸Å¸Â¡ **Subtasks como milestones** Ã¢â‚¬â€ em linha do tempo ou lista com % de progresso.
- Ã°Å¸Å¸Â¡ **VinculaÃƒÂ§ÃƒÂ£o bidirecional com Tasks** Ã¢â‚¬â€ listar tasks que tÃƒÂªm a goal como organizer.
- Ã°Å¸Å¸Â¡ **`state` selector rÃƒÂ¡pido** Ã¢â‚¬â€ chips ou dropdown sem abrir form completo.
- Ã°Å¸Å¸Â¢ **Timeline de progresso** Ã¢â‚¬â€ quando KPIs foram atualizados.

### GoalsScreen (lista)
**Falta:**
- Ã°Å¸Å¸Â¡ **Filtro por estado e tipo**.
- Ã°Å¸Å¸Â¡ **Card rico** Ã¢â‚¬â€ barra de progresso, ÃƒÂ­cone, cor, deadline, estado.
- Ã°Å¸Å¸Â¡ **Goals vencendo** Ã¢â‚¬â€ destaque para deadline nos prÃƒÂ³ximos 7 dias.
- Ã°Å¸Å¸Â¢ **Sorting** Ã¢â‚¬â€ por deadline, progresso, criaÃƒÂ§ÃƒÂ£o.

---

## 4. NOTE

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸Å¸Â¡ **`parentNoteId` picker** Ã¢â‚¬â€ hierarquia de notas sem UI.
- Ã°Å¸Å¸Â¡ **Escolha de `subtype` visual** Ã¢â‚¬â€ text, outline, collection como 3 modos com ÃƒÂ­cone e descriÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¢ **`color` picker** Ã¢â‚¬â€ ver item 26.

### Editor
**Falta:**
- Ã°Å¸â€Â´ **Toolbar persistente** Ã¢â‚¬â€ bold, italic, heading, bullet, numbered list, code, quote, link, imagem.
- Ã°Å¸â€Â´ **Wiki-links `[[...]]`** Ã¢â‚¬â€ `WikiLinkController` existe mas autocomplete ao digitar `[[` precisa ser verificado.
- Ã°Å¸Å¸Â¡ **Modo outline completo** Ã¢â‚¬â€ `OutlineEditor` existe. Verificar: drag-to-reorder, indent/outdent, collapse de subitens.
- Ã°Å¸Å¸Â¡ **Auto-save** Ã¢â‚¬â€ salvar rascunho a cada X segundos ou ao perder foco.
- Ã°Å¸Å¸Â¡ **Modo foco (fullscreen)** Ã¢â‚¬â€ esconder AppBar, sÃƒÂ³ editor.
- Ã°Å¸Å¸Â¢ **Word count** Ã¢â‚¬â€ no rodapÃƒÂ©.
- Ã°Å¸Å¸Â¢ **Exportar como PDF/MD**.
- Ã°Å¸Å¸Â¢ **Imagens inline** Ã¢â‚¬â€ inserir imagens locais ou da cÃƒÂ¢mera.

### NotesScreen (lista)
**Falta:**
- Ã°Å¸Å¸Â¡ **Hierarquia visual** Ã¢â‚¬â€ notas com `parentNoteId` indentadas ou em tree-view.
- Ã°Å¸Å¸Â¡ **Preview do body** Ã¢â‚¬â€ mostrar inÃƒÂ­cio do conteÃƒÂºdo no card.
- Ã°Å¸Å¸Â¢ **Filtro por subtype**.
- Ã°Å¸Å¸Â¢ **Busca dentro do conteÃƒÂºdo** Ã¢â‚¬â€ nÃƒÂ£o sÃƒÂ³ por tÃƒÂ­tulo.
- Ã°Å¸Å¸Â¢ **Cor na lista** Ã¢â‚¬â€ cards coloridos conforme `note.color`.

---

## 5. JOURNAL ENTRY

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **`templateId` picker** Ã¢â‚¬â€ o model suporta templates de diÃƒÂ¡rio, mas nÃƒÂ£o hÃƒÂ¡ picker no form para prÃƒÂ©-preencher estrutura.
- Ã°Å¸Å¸Â¡ **Humor mais visual** Ã¢â‚¬â€ seletor de emoji grande com nome e cor associada, nÃƒÂ£o sÃƒÂ³ slug de texto.
- Ã°Å¸Å¸Â¡ **`photos`** Ã¢â‚¬â€ botÃƒÂ£o cÃƒÂ¢mera/galeria, miniaturas no form, remover foto.
- Ã°Å¸Å¸Â¢ **`weather`** Ã¢â‚¬â€ preenchimento automÃƒÂ¡tico via geolocalizaÃƒÂ§ÃƒÂ£o ou manual.
- Ã°Å¸Å¸Â¢ **`location`** Ã¢â‚¬â€ picker de localizaÃƒÂ§ÃƒÂ£o (Maps).
- Ã°Å¸Å¸Â¢ **`title` auto-gerado** Ã¢â‚¬â€ "Entrada de [data]" se vazio.

### Tela de detalhe
**Falta:**
- Ã°Å¸Å¸Â¡ **Galeria de fotos** Ã¢â‚¬â€ grid/carousel com zoom.
- Ã°Å¸Å¸Â¡ **EdiÃƒÂ§ÃƒÂ£o inline do body** Ã¢â‚¬â€ tocar no texto para editar sem abrir form separado.
- Ã°Å¸Å¸Â¢ **Mapa de localizaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ mini-mapa se `location` preenchido.
- Ã°Å¸Å¸Â¢ **Clima visual** Ã¢â‚¬â€ ÃƒÂ­cone + temperatura se `weather` preenchido.

### JournalScreen (lista)
**Falta:**
- Ã°Å¸Å¸Â¡ **VisualizaÃƒÂ§ÃƒÂ£o de calendÃƒÂ¡rio** Ã¢â‚¬â€ dias com entradas marcados.
- Ã°Å¸Å¸Â¡ **Filtro por humor**.
- Ã°Å¸Å¸Â¢ **Streak de escrita** Ã¢â‚¬â€ "X dias consecutivos com entrada".
- Ã°Å¸Å¸Â¢ **Templates de diÃƒÂ¡rio** Ã¢â‚¬â€ listar e aplicar.

---

## 6. TRACKER / TRACKINGRECORD

### Form de criaÃƒÂ§ÃƒÂ£o do Tracker
**Falta:**
- Ã°Å¸â€Â´ **Preview em tempo real** Ã¢â‚¬â€ visualizar como vai ficar o formulÃƒÂ¡rio de registro enquanto cria a definiÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Editor de seÃƒÂ§ÃƒÂµes/campos completo** Ã¢â‚¬â€ verificar se estÃƒÂ¡ completo: picker de tipo, min/max para range, opÃƒÂ§ÃƒÂµes para selection/checklist.
- Ã°Å¸Å¸Â¢ **Campo `media`** Ã¢â‚¬â€ upload de imagem/vÃƒÂ­deo.
- Ã°Å¸Å¸Â¢ **Campo `mood`** Ã¢â‚¬â€ referencia `MoodDefinition`, sem picker de humor personalizado.

### Form de registro (`create_record_form.dart`)
**Falta:**
- Ã°Å¸â€Â´ **RenderizaÃƒÂ§ÃƒÂ£o por tipo de campo:**
  - `range` Ã¢â€ â€™ slider com min/max
  - `duration` Ã¢â€ â€™ time picker (HH:MM)
  - `mood` Ã¢â€ â€™ seletor de emojis/humor
  - `media` Ã¢â€ â€™ cÃƒÂ¢mera/galeria
  - `checklist` Ã¢â€ â€™ lista de checkboxes
  - `selection` Ã¢â€ â€™ dropdown ou chips
- Ã°Å¸Å¸Â¢ **Registro rÃƒÂ¡pido** Ã¢â‚¬â€ aÃƒÂ§ÃƒÂ£o direta do dashboard sem abrir form completo.

### TrackersScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Mini grÃƒÂ¡fico sparkline** no card dos ÃƒÂºltimos 7 registros.
- Ã°Å¸Å¸Â¡ **BotÃƒÂ£o de registro rÃƒÂ¡pido** no card sem entrar no detalhe.
- Ã°Å¸Å¸Â¢ **Streak de registro** Ã¢â‚¬â€ "ÃƒÅ¡ltimo registro: hÃƒÂ¡ X dias".

### Tela de detalhe
**Falta:**
- Ã¢Å“â€¦ **RenderizaÃƒÂ§ÃƒÂ£o de fieldValues legÃƒÂ­vel** Ã¢â‚¬â€ implementado com helper dinÃƒÂ¢mico para checkboxes, duraÃƒÂ§ÃƒÂµes, humores, etc.
- Ã°Å¸Å¸Â¡ **GrÃƒÂ¡ficos por campo** Ã¢â‚¬â€ linha/barra dos ÃƒÂºltimos 30/90 dias.
- Ã°Å¸Å¸Â¡ **EstatÃƒÂ­sticas** Ã¢â‚¬â€ mÃƒÂ©dia, mÃƒÂ­n, mÃƒÂ¡x, tendÃƒÂªncia.
- Ã°Å¸Å¸Â¡ **Lista de records** Ã¢â‚¬â€ histÃƒÂ³rico paginado com ediÃƒÂ§ÃƒÂ£o e deleÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¢ **Exportar CSV**.

---

## 7. REMINDER

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸Å¸Â¡ **`timeBlockId`** Ã¢â‚¬â€ sem picker de bloco de tempo.
- Ã°Å¸Å¸Â¡ **Tipo de notificaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ push vs alarm vs silencioso.
- Ã°Å¸Å¸Â¢ **`isCompletable` toggle** Ã¢â‚¬â€ desabilitar checkbox para lembretes informativos.
- Ã°Å¸Å¸Â¢ **Lembrete de lembrete** Ã¢â‚¬â€ notificaÃƒÂ§ÃƒÂ£o X minutos antes do principal.

### RemindersScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **SeparaÃƒÂ§ÃƒÂ£o passados/futuros**.
- Ã°Å¸Å¸Â¡ **Reagendar rÃƒÂ¡pido** Ã¢â‚¬â€ swipe para +1h, +1 dia, semana que vem.
- Ã°Å¸Å¸Â¢ **Filtro "sÃƒÂ³ hoje"**.
- Ã°Å¸Å¸Â¢ **Marcar como concluÃƒÂ­do com swipe**.

---

## 8. PERSON

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸Å¸Â¡ **`photo`** Ã¢â‚¬â€ campo de upload de foto (cÃƒÂ¢mera/galeria).
- Ã°Å¸Å¸Â¡ **`contactFrequency` picker** Ã¢â‚¬â€ opÃƒÂ§ÃƒÂµes predefinidas (diÃƒÂ¡rio, semanal, quinzenal, mensal, trimestral) + personalizado.
- Ã°Å¸Å¸Â¡ **`contactPriority`** Ã¢â‚¬â€ picker visual de prioridade.
- Ã°Å¸Å¸Â¢ **`color` e `icon`** Ã¢â‚¬â€ personalizaÃƒÂ§ÃƒÂ£o visual. Ver item 26.

### Tela de detalhe
**Falta:**
- Ã°Å¸â€Â´ **AÃƒÂ§ÃƒÂµes rÃƒÂ¡pidas** Ã¢â‚¬â€ Ligar, Email, WhatsApp via `url_launcher`.
- Ã°Å¸â€Â´ **Status de contato** Ã¢â‚¬â€ "ÃƒÅ¡ltimo contato: X dias atrÃƒÂ¡s", "PrÃƒÂ³ximo: em Y dias" com barra urgÃƒÂªncia.
- Ã°Å¸Å¸Â¡ **Avatar** Ã¢â‚¬â€ foto ou iniciais coloridas.
- Ã°Å¸Å¸Â¡ **Tasks relacionadas** Ã¢â‚¬â€ tasks que tÃƒÂªm essa pessoa como `participant`.
- Ã°Å¸Å¸Â¢ **HistÃƒÂ³rico de contatos** Ã¢â‚¬â€ log de quando foi contatada.

### PeopleScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **OrdenaÃƒÂ§ÃƒÂ£o por urgÃƒÂªncia de contato**.
- Ã°Å¸Å¸Â¡ **Avatars na lista**.
- Ã°Å¸Å¸Â¢ **Filtro por prioridade de contato**.
- Ã°Å¸Å¸Â¢ **Busca por email, telefone**.

---

## 9. PROJECT

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã°Å¸â€Â´ **`primaryKpiId` e `secondaryKpiIds`** Ã¢â‚¬â€ picker de KPIs ou criaÃƒÂ§ÃƒÂ£o inline.
- Ã°Å¸Å¸Â¡ **`taskLinks`** Ã¢â‚¬â€ vincular tasks existentes ao projeto (multi-seleÃƒÂ§ÃƒÂ£o via busca).
- Ã°Å¸Å¸Â¡ **`quickAccessLinks`** Ã¢â‚¬â€ lista de wiki-links para recursos rÃƒÂ¡pidos. UI de adiÃƒÂ§ÃƒÂ£o/remoÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Sub-projetos** Ã¢â‚¬â€ `parentId` permite hierarquia, mas sem UI para escolher projeto pai.
- Ã°Å¸Å¸Â¢ **`state` e `priority`** Ã¢â‚¬â€ verificar se sÃƒÂ£o visualmente ricos.

### Tela de detalhe
**Falta:**
- Ã°Å¸â€Â´ **Board de tasks** Ã¢â‚¬â€ kanban por stage (Idea | Todo | In Progress | Done).
- Ã°Å¸Å¸Â¡ **KPIs do projeto** Ã¢â‚¬â€ valor atual e target.
- Ã°Å¸Å¸Â¡ **Quick Access Links** Ã¢â‚¬â€ grid de links rÃƒÂ¡pidos.
- Ã°Å¸Å¸Â¡ **`totalPomodoroTime`** Ã¢â‚¬â€ tempo total de foco.
- Ã°Å¸Å¸Â¢ **Timeline do projeto** Ã¢â‚¬â€ do start ao end com marcos.
- Ã°Å¸Å¸Â¢ **Sub-projetos** Ã¢â‚¬â€ listar filhos.

---

## 10. SOCIAL POST

### Pedidos do usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Linkar tarefa ao salvar um post** Ã¢â‚¬â€ implementado, incluindo seÃƒÂ§ÃƒÂ£o dedicada de vinculaÃƒÂ§ÃƒÂ£o agrupada por tipo de objeto.
- Ã¢Å“â€¦ **Separar socialRefs por tipo de objeto** Ã¢â‚¬â€ implementado no form de criaÃƒÂ§ÃƒÂ£o e no detalhe do post.

### Form de criaÃƒÂ§ÃƒÂ£o
**Falta:**
- Ã¢Å“â€¦ **SeÃƒÂ§ÃƒÂ£o "Vincular objetos"** no form de criaÃƒÂ§ÃƒÂ£o Ã¢â‚¬â€ implementado com agrupamento por tipo.
- Ã°Å¸Å¸Â¡ **Preview do post** Ã¢â‚¬â€ mostrar preview (embed) dentro do form antes de salvar.
- Ã°Å¸Å¸Â¢ **Tags automÃƒÂ¡ticas** Ã¢â‚¬â€ extrair hashtags do caption e sugerir como tags.

### Tela de detalhe (`social_post_detail.dart`)
**Falta:**
- Ã¢Å“â€¦ **SeÃƒÂ§ÃƒÂ£o de objetos vinculados agrupada por tipo** Ã¢â‚¬â€ implementado com agrupamento visual.
- Ã°Å¸Å¸Â¡ **Player de vÃƒÂ­deo** Ã¢â‚¬â€ para posts com `videoUrl`.
- Ã°Å¸Å¸Â¡ **Carousel de imagens** Ã¢â‚¬â€ para posts com `mediaUrls` mÃƒÂºltiplos.
- Ã°Å¸Å¸Â¢ **`watched` toggle** Ã¢â‚¬â€ botÃƒÂ£o de marcar como visto/assistido visÃƒÂ­vel no detalhe.
- Ã°Å¸Å¸Â¢ **EdiÃƒÂ§ÃƒÂ£o da `personalNote`** Ã¢â‚¬â€ inline no detalhe.

### SocialScreen (lista/grid)
- Ã¢Å“â€¦ Filtro por plataforma Ã¢â‚¬â€ implementado
- Ã¢Å“â€¦ Filtro `watched/unwatched` Ã¢â‚¬â€ implementado
- Ã¢Å“â€¦ Associar a objeto via timeline card Ã¢â‚¬â€ implementado
- Ã¢Å“â€¦ ColeÃƒÂ§ÃƒÂµes/Organizers Ã¢â‚¬â€ implementado
- Ã¢Å“â€¦ Busca via SearchScreen Ã¢â‚¬â€ implementado
- Ã¢Å“â€¦ **IDs visÃƒÂ­veis** Ã¢â‚¬â€ verificado: `_resolveRefs` no `social_post_detail.dart` e no form resolvem wiki-links para `object.title` via `displayType` e chip de objeto com tÃƒÂ­tulo legÃƒÂ­vel. NÃƒÂ£o sÃƒÂ£o exibidos UUIDs/slugs.

---

## 11. RESOURCE

### Form e detalhe
**Falta:**
- Ã°Å¸Å¸Â¡ **`progress` visual** Ã¢â‚¬â€ para livros e cursos, barra com pÃƒÂ¡gina atual / total.
- Ã°Å¸Å¸Â¡ **`cover` image** Ã¢â‚¬â€ auto-fetch via ISBN ou URL.
- Ã°Å¸Å¸Â¡ **Rating** Ã¢â‚¬â€ avaliaÃƒÂ§ÃƒÂ£o de 1 a 5 estrelas apÃƒÂ³s concluir.
- Ã°Å¸Å¸Â¢ **Status rÃƒÂ¡pido** Ã¢â‚¬â€ swipe para mover entre Backlog/Em progresso/ConcluÃƒÂ­do.
- Ã°Å¸Å¸Â¢ **RecomendaÃƒÂ§ÃƒÂµes** Ã¢â‚¬â€ campo "Recomendado por" vinculando a uma `Person`.

### ResourcesScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Shelf view** Ã¢â‚¬â€ grade de covers.
- Ã°Å¸Å¸Â¡ **adicionar listas de Filtros por qualquer propriedade, e ordenar por qualquer propriedade**.
- Ã°Å¸Å¸Â¢ **Stats** Ã¢â‚¬â€ quantos concluÃƒÂ­dos este ano, etc.

---

## 12. DAY THEME & TIME BLOCK

### DayThemeScreen Ã¢â‚¬â€ CRUD
**Falta:**
- Ã°Å¸â€Â´ **Tela de ediÃƒÂ§ÃƒÂ£o de TimeBlock** Ã¢â‚¬â€ tocar num bloco nÃƒÂ£o abre nada. Precisamos de sheet/tela com: campo de nome, color picker (ver item 26), lista de TimeRanges editÃƒÂ¡veis (adicionar, remover, editar cada range), campo de order.
- Ã°Å¸â€Â´ **Tela de ediÃƒÂ§ÃƒÂ£o de DayTheme** Ã¢â‚¬â€ tocar num tema nÃƒÂ£o abre nada. Precisamos de: campo de nome, color picker, picker de dias da semana (chips Mon-Sun), lista de blocos com checkboxes, preview visual.
- Ã°Å¸â€Â´ **MÃƒÂºltiplos TimeRanges por bloco no form de criaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ o model suporta `List<TimeRange>` mas o form cria sÃƒÂ³ um. BotÃƒÂ£o "Adicionar horÃƒÂ¡rio" que adiciona outro range.
- Ã°Å¸Å¸Â¡ **Delete com confirmaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ swipe ou long-press com alerta se bloco estÃƒÂ¡ em uso.
- Ã°Å¸Å¸Â¡ **Cor visual nos tiles** Ã¢â‚¬â€ `color` existe mas nÃƒÂ£o ÃƒÂ© usado na UI. Dot ou borda colorida.
- Ã°Å¸Å¸Â¡ **Preview do dia** Ã¢â‚¬â€ mini-timeline vertical na tela de DayTheme mostrando como o dia ficarÃƒÂ¡.
- Ã°Å¸Å¸Â¢ **ValidaÃƒÂ§ÃƒÂ£o de sobreposiÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ alertar quando dois blocos do mesmo tema tÃƒÂªm horÃƒÂ¡rios sobrepostos.

### IntegraÃƒÂ§ÃƒÂ£o Planner (Timeline)
- Ã¢Å“â€¦ Time Block Bands na timeline Ã¢â‚¬â€ `_buildTimeBlockBands()` implementado no `TimeLineDayView`
- Ã¢Å“â€¦ Blocos passados como parÃƒÂ¢metro para TimeLineDayView Ã¢â‚¬â€ verificado no planner_screen
- Ã°Å¸Å¸Â¡ **`timeBlocks` nÃƒÂ£o estÃƒÂ¡ sendo passado ao `TimeLineDayView`** Ã¢â‚¬â€ verificar: o `TimeLineDayView` recebe `timeBlocks` como parÃƒÂ¢metro, mas no `PlannerScreen` o `TimeLineDayView` ÃƒÂ© construÃƒÂ­do sem passar `timeBlocks`. Confirmar se a prop estÃƒÂ¡ sendo passada corretamente ou se as bands nÃƒÂ£o aparecem.
- Ã°Å¸Å¸Â¡ **Drag-to-assign bloco** Ã¢â‚¬â€ arrastar task para faixa de bloco atribui `task.timeBlock`.
- Ã°Å¸Å¸Â¢ **Resize de bloco** Ã¢â‚¬â€ arrastar borda inferior de uma faixa para redimensionar horÃƒÂ¡rio.

### IntegraÃƒÂ§ÃƒÂ£o Scheduler
- Ã°Å¸â€Â´ **SchedulerPicker sem `daysOfTheme`/`daysWithBlock`** Ã¢â‚¬â€ tipos existem no `SchedulerService` mas nÃƒÂ£o expostos no picker UI.
- Ã°Å¸Å¸Â¡ **Preview de prÃƒÂ³ximas ocorrÃƒÂªncias** Ã¢â‚¬â€ mostrar prÃƒÂ³ximas 5 datas no SchedulerPicker.

---

## 13. PLANNER SCREEN

### Bug identificado pelo usuÃƒÂ¡rio
- Ã¢Å“â€¦ **HÃƒÂ¡bito com mÃƒÂºltiplos slots completa todos ao tocar em um** Ã¢â‚¬â€ ver item 2 (Habit). Bug no `_buildHabitCard` e `_buildHabitItem`: chamam `toggleHabit` sem `slotIndex`. SoluÃƒÂ§ÃƒÂ£o: renderizar cada slot como linha separada com botÃƒÂ£o individual chamando `toggleHabit(habit, date, slotIndex: i)`.

### Bug identificado pelo usuÃƒÂ¡rio Ã¢â‚¬â€ auto-scroll
- Ã¢Å“â€¦ **Ao abrir o Planner, nÃƒÂ£o scrolla para o horÃƒÂ¡rio atual** Ã¢â‚¬â€ `TimeLineDayView` ÃƒÂ© renderizado dentro de `SliverToBoxAdapter` dentro de `CustomScrollView` no `PlannerScreen`. NÃƒÂ£o hÃƒÂ¡ `ScrollController` compartilhado nem `jumpTo` no `initState`. SoluÃƒÂ§ÃƒÂ£o: expor um `ScrollController` no `_PlannerScreenState`, passÃƒÂ¡-lo tanto para o `CustomScrollView` quanto para o `TimeLineDayView`, e no `initState` (ou `didChangeDependencies`) chamar `WidgetsBinding.instance.addPostFrameCallback((_) { _scrollController.jumpTo(now.hour * 80.0 + now.minute / 60 * 80.0 - MediaQuery.of(context).size.height / 3); })`. O `hourHeight` ÃƒÂ© constante `80.0` no `TimeLineDayView`. TambÃƒÂ©m fazer auto-scroll toda vez que `_selectedDate` mudar para hoje.

### IDs visÃƒÂ­veis Ã¢â‚¬â€ pedido do usuÃƒÂ¡rio
- Ã°Å¸â€Â´ **Cards nÃƒÂ£o devem exibir IDs, slugs ou strings `[[...]]`** Ã¢â‚¬â€ apÃƒÂ³s anÃƒÂ¡lise do cÃƒÂ³digo:
  - `_buildTaskCard` no planner: nÃƒÂ£o exibe organizers nem IDs Ã¢â‚¬â€ **OK** como estÃƒÂ¡.
  - `_buildHabitCard`: nÃƒÂ£o exibe organizers Ã¢â‚¬â€ **OK**.
  - `_buildGoogleEventItem`: exibe `event.summary` e horÃƒÂ¡rio Ã¢â‚¬â€ **OK**.
  - `_buildTrackingRecordItem`: exibe texto hardcoded `'Tracker Record'` e `'X fields filled'` Ã¢â‚¬â€ **OK**, sem IDs.
  - `_buildJournalEntryItem`: exibe `entry.title` e `'Mood: \${entry.moodSlug}'` Ã¢â‚¬â€ **bug**: `moodSlug` ÃƒÂ© o ID/slug do mood (ex: `'feliz'`, nÃƒÂ£o o emoji/tÃƒÂ­tulo). Substituir por buscar o `MoodDefinition` pelo slug e mostrar `mood.emoji + mood.title`, ou omitir se slug nÃƒÂ£o resolver.
  - `_buildTimeBlockSection`: exibe `block.title` e `ranges` de horÃƒÂ¡rio Ã¢â‚¬â€ **OK**.
  - `_buildHabitStripItem` na timeline: exibe `habit.displayTitle` Ã¢â‚¬â€ **OK**.
  - **Regra geral**: nunca exibir campos `id`, `slug`, `timeBlock` (ID bruto), `obsidianPath`, `trackerId`. Para organizers, usar sempre `o.title` e deixar vazio se a lista estiver vazia.

### Day View Ã¢â‚¬â€ Agenda Mode
**Falta:**
- Ã°Å¸Å¸Â¡ **Header do bloco clicÃƒÂ¡vel** Ã¢â‚¬â€ tocar no nome do bloco abre ediÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Tasks completadas** Ã¢â‚¬â€ toggle para mostrar/esconder tasks jÃƒÂ¡ finalizadas.
- Ã°Å¸Å¸Â¡ **Drag entre blocos** Ã¢â‚¬â€ arrastar task de um bloco para outro (muda `task.timeBlock`).
- Ã°Å¸Å¸Â¢ **Linha do horÃƒÂ¡rio atual** Ã¢â‚¬â€ tambÃƒÂ©m no modo agenda (nÃƒÂ£o sÃƒÂ³ na timeline).

### Day View Ã¢â‚¬â€ Timeline Mode
**Falta:**
- Ã°Å¸Å¸Â¡ **Google Calendar events visualmente distintos** Ã¢â‚¬â€ jÃƒÂ¡ aparecem na timeline, mas verificar se sÃƒÂ£o diferenciados por ÃƒÂ­cone de calendÃƒÂ¡rio.
- Ã°Å¸Å¸Â¡ **Conflitos de horÃƒÂ¡rio** Ã¢â‚¬â€ eventos sobrepostos em colunas (jÃƒÂ¡ implementado via `groups`/`columns`, verificar edge cases).
- Ã°Å¸Å¸Â¡ **Zoom** Ã¢â‚¬â€ pinch-to-zoom para expandir/comprimir a timeline.
- Ã°Å¸Å¸Â¢ **Eventos all-day** Ã¢â‚¬â€ ÃƒÂ¡rea separada no topo para hÃƒÂ¡bitos/tasks sem horÃƒÂ¡rio.

### Week View
**Falta:**
- Ã°Å¸Å¸Â¡ **Day themes indicados** Ã¢â‚¬â€ mostrar qual tema ativo em cada dia (chip colorido no header).
- Ã°Å¸Å¸Â¡ **Drag entre dias** Ã¢â‚¬â€ arrastar task de um dia para outro.
- Ã°Å¸Å¸Â¢ **Vista de grade** Ã¢â‚¬â€ 7 colunas com timeline vertical.

### Month View
**Falta:**
- Ã°Å¸Å¸Â¡ **42 cÃƒÂ©lulas quando necessÃƒÂ¡rio** Ã¢â‚¬â€ meses que comeÃƒÂ§am na sexta/sÃƒÂ¡bado precisam de 6 semanas.
- Ã°Å¸Å¸Â¡ **Tema do dia** Ã¢â‚¬â€ colorir levemente a cÃƒÂ©lula com a cor do tema ativo.
- Ã°Å¸Å¸Â¢ **Dots de mÃƒÂºltiplos tipos** Ã¢â‚¬â€ habit, reminder, alÃƒÂ©m de task e GCal.

### Sensibilidade de arrastar para pesquisar Ã¢â‚¬â€ pedido do usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Pull-to-search muito sensÃƒÂ­vel / disparando sem querer** Ã¢â‚¬â€ o `AppShell` nÃƒÂ£o implementa pull-to-search; o gesto provavelmente estÃƒÂ¡ no `HomeScreen` ou num widget de scroll. Localizar onde o `DragGestureRecognizer` ou `NotificationListener<ScrollNotification>` (ou `RefreshIndicator`) estÃƒÂ¡ acionando a navegaÃƒÂ§ÃƒÂ£o para `/search`. Aumentar o threshold para Ã¢â€°Â¥ 80px de arrasto antes de disparar, ou substituir completamente por gesto explÃƒÂ­cito: manter apenas o ÃƒÂ­cone de busca na AppBar. O `AppShell` jÃƒÂ¡ tem atalho `Ctrl+F` / `Cmd+F` Ã¢â€ â€™ `/search`; no mobile, o ÃƒÂ­cone na AppBar ÃƒÂ© suficiente e elimina o falso positivo.

---

## 14. CALENDAR WIDGET (DASHBOARD)

### Pedidos do usuÃƒÂ¡rio Ã¢â‚¬â€ estado atual apÃƒÂ³s anÃƒÂ¡lise do cÃƒÂ³digo

- Ã¢Å“â€¦ **Remover abas Dia/Sem/MÃƒÂªs Ã¢â€ â€™ sÃƒÂ³ semana** Ã¢â‚¬â€ `_buildViewToggle()` ainda renderiza 3 abas e `CalendarView` tem 3 valores. Remover completamente o toggle; fixar `_currentView = CalendarView.week`. As setas `<` `>` jÃƒÂ¡ navegam semanas e sÃƒÂ£o os ÃƒÂºnicos controles necessÃƒÂ¡rios.

- Ã¢Å“â€¦ **Substituir toggle por ÃƒÂ­cone sync + botÃƒÂ£o `+`** Ã¢â‚¬â€ no header onde estava o toggle, colocar `Row` com: (a) `IconButton(icon: Icon(Icons.sync_rounded))` que dispara sync do Google Calendar e (b) `IconButton(icon: Icon(Icons.add_rounded))` que chama `showCreateMenu(context)`.

- Ã¢Å“â€¦ **Clicar em dia mostra conteÃƒÂºdo inline (sem bottomsheet)** Ã¢â‚¬â€ `_buildWeekAgenda` jÃƒÂ¡ faz isso parcialmente: toca no dia Ã¢â€ â€™ `_selectedDay` atualiza Ã¢â€ â€™ tasks aparecem abaixo. **Buracos restantes:** (a) hÃƒÂ¡bitos listados sÃƒÂ£o os `h.status == HabitStatus.active` sem filtro de scheduler do dia selecionado Ã¢â‚¬â€ mostrar sÃƒÂ³ os que deveriam aparecer naquele dia; (b) eventos do Google Calendar do dia nÃƒÂ£o aparecem na lista inline; (c) lembretes do dia nÃƒÂ£o aparecem. O `_showDaySheet` (bottomsheet) chamado no `_buildMonthGrid` pode ser eliminado no modo semana.

- Ã¢Å“â€¦ **IDs visÃƒÂ­veis Ã¢â‚¬â€ `'Sem ÃƒÂ¡rea'` em branco** Ã¢â‚¬â€ em `_buildAgendaTask`: trocar o fallback `'Sem ÃƒÂ¡rea'` por `''` para ficar vazio quando nÃƒÂ£o hÃƒÂ¡ organizer. Em `_buildHabitRow`: jÃƒÂ¡ usa `habit.organizers.first.title` se existir, mas o `Text` ao lado do checkbox exibe esse tÃƒÂ­tulo Ã¢â‚¬â€ verificar se nenhum organizer retorna slug `[[nome]]` em vez de tÃƒÂ­tulo resolvido. Regra: suprimir qualquer string que comece com `[[` ou que seja UUID.

### Outros gaps do CalendarWidget
**Falta:**
- Ã°Å¸Å¸Â¡ **HÃƒÂ¡bitos filtrados por scheduler no grid semanal** Ã¢â‚¬â€ dots e lista do dia devem considerar `SchedulerService.shouldFire` para o dia especÃƒÂ­fico.
- Ã°Å¸Å¸Â¡ **Google Calendar inline** Ã¢â‚¬â€ eventos do GCal aparecem como dot no grid mas nÃƒÂ£o na lista inline do dia selecionado. Usar `ref.watch(googleCalendarEventsProvider(_selectedDay))` na seÃƒÂ§ÃƒÂ£o de lista.
- Ã°Å¸Å¸Â¡ **Lembretes inline** Ã¢â‚¬â€ adicionar lembretes do dia na lista inline do dia selecionado.
- Ã°Å¸Å¸Â¢ **Formato de data localizado** Ã¢â‚¬â€ confirmar `pt_BR` em todos os `DateFormat`.

---

## 15. SCHEDULER

### SchedulerPicker (UI)
**Falta:**
- Ã°Å¸â€Â´ **`RepeatType.daysOfTheme`** Ã¢â‚¬â€ opÃƒÂ§ÃƒÂ£o com dropdown para selecionar qual DayTheme.
- Ã°Å¸â€Â´ **`RepeatType.daysWithBlock`** Ã¢â‚¬â€ opÃƒÂ§ÃƒÂ£o com dropdown para selecionar qual TimeBlock.
- Ã°Å¸Å¸Â¡ **`RepeatType.linkedItemAppears`** e **`nDaysAfterLinkedItem`** Ã¢â‚¬â€ picker de item vinculado.
- Ã°Å¸Å¸Â¡ **Preview de prÃƒÂ³ximas ocorrÃƒÂªncias** Ã¢â‚¬â€ ao configurar, mostrar prÃƒÂ³ximas 5 datas.
- Ã°Å¸Å¸Â¡ **`exclusions`** Ã¢â‚¬â€ UI para adicionar exclusÃƒÂµes (datas em que nÃƒÂ£o deve disparar).
- Ã°Å¸Å¸Â¢ **`OverduePolicy`** Ã¢â‚¬â€ picker para polÃƒÂ­tica de overdue (skip/keep/prompt).
- Ã°Å¸Å¸Â¢ **`maxOccurrences`** Ã¢â‚¬â€ limitar nÃƒÂºmero mÃƒÂ¡ximo de disparos.
- Ã°Å¸Å¸Â¢ **`exactTime`** Ã¢â‚¬â€ picker de hora exata.

---

## 16. DASHBOARD / HOME SCREEN

### Widgets Ã¢â‚¬â€ gaps internos

**`BlockType.timeBlocking`:**
- Ã¢Å“â€¦ Deveria mostrar os TimeBlocks do DayTheme ativo com horÃƒÂ¡rios como mini-timeline vertical, nÃƒÂ£o sÃƒÂ³ tasks com `scheduledTime`.

**`BlockType.habits`:**
- Ã°Å¸Å¸Â¡ Progresso diÃƒÂ¡rio (X/Y), streak visÃƒÂ­vel por hÃƒÂ¡bito, distinÃƒÂ§ÃƒÂ£o de negativos.

**`BlockType.goals`:**
- Ã°Å¸Å¸Â¡ Deadline prÃƒÂ³ximo destacado, ÃƒÂ­cone/cor da goal.

**`BlockType.customMarkdown`:**
- Ã°Å¸Å¸Â¡ Editor de markdown configurÃƒÂ¡vel por bloco salvo em `metadata`.

**`BlockType.trackerField`:**
- Ã°Å¸Å¸Â¡ ConfigurÃƒÂ¡vel: escolher tracker e campo, mostrar mini-grÃƒÂ¡fico.

**`BlockType.pinnedObject`:**
- Ã°Å¸Å¸Â¡ ImplementaÃƒÂ§ÃƒÂ£o ausente ou bÃƒÂ¡sica. Deveria abrir `UniversalDetailView` do objeto pinado com preview inline.

**`BlockType.quotes`:**
- Ã°Å¸Å¸Â¢ Quote hardcoded. Deveria ser pool configurÃƒÂ¡vel pelo usuÃƒÂ¡rio.

### Edit Mode
- Ã°Å¸Å¸Â¡ **Configurar metadados inline** Ã¢â‚¬â€ ÃƒÂ­cone de config de cada bloco para abrir configuraÃƒÂ§ÃƒÂµes especÃƒÂ­ficas.
- Ã°Å¸Å¸Â¡ **Tamanho do widget** Ã¢â‚¬â€ compacto, mÃƒÂ©dio, grande.
- Ã°Å¸Å¸Â¢ **Renomear bloco** no edit mode.

### Dashboard geral
- Ã°Å¸Å¸Â¡ **Pull-to-refresh** para forÃƒÂ§ar re-sync.
- Ã°Å¸Å¸Â¢ **PersistÃƒÂªncia por device** Ã¢â‚¬â€ ordem salva no vault pode conflitar entre dispositivos.

---

## 17. POMODORO

### PomodoroScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **SeleÃƒÂ§ÃƒÂ£o de task vinculada durante sessÃƒÂ£o** Ã¢â‚¬â€ mudar a task sem sair da tela.
- Ã°Å¸Å¸Â¡ **HistÃƒÂ³rico visual na tela** Ã¢â‚¬â€ lista dos ÃƒÂºltimos X pomodoros da sessÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Sons/vibraÃƒÂ§ÃƒÂ£o configurÃƒÂ¡veis** Ã¢â‚¬â€ alerta ao final.
- Ã°Å¸Å¸Â¢ **Notas de sessÃƒÂ£o** Ã¢â‚¬â€ anotar o que foi feito, salvo no histÃƒÂ³rico.
- Ã°Å¸Å¸Â¢ **EstatÃƒÂ­sticas de sessÃƒÂ£o** Ã¢â‚¬â€ quantos hoje, esta semana, tempo total.
- Ã°Å¸Å¸Â¢ **Background timer** Ã¢â‚¬â€ `PomodoroBackgroundService` existe. Verificar notificaÃƒÂ§ÃƒÂ£o de progresso.

### PomodoroFloatingClock
- Ã°Å¸Å¸Â¢ **Tap para pausar** sem abrir a tela.
- Ã°Å¸Å¸Â¢ **PosiÃƒÂ§ÃƒÂ£o e tamanho configurÃƒÂ¡veis**.

---

## 18. SYNC / GOOGLE DRIVE / OBSIDIAN

### Google Drive Sync
**Falta:**
- Ã°Å¸Å¸Â¡ **Log de operaÃƒÂ§ÃƒÂµes de sync** Ã¢â‚¬â€ alÃƒÂ©m da tela de conflitos, um log geral.
- Ã°Å¸Å¸Â¡ **ResoluÃƒÂ§ÃƒÂ£o de conflitos melhorada** Ã¢â‚¬â€ diff lado a lado (local vs remoto).
- Ã°Å¸Å¸Â¢ **SincronizaÃƒÂ§ÃƒÂ£o seletiva** Ã¢â‚¬â€ escolher quais pastas/tipos sincronizar.
- Ã°Å¸Å¸Â¢ **Backup automÃƒÂ¡tico** Ã¢â‚¬â€ `backup_service.dart` existe, verificar UI de configuraÃƒÂ§ÃƒÂ£o.

### Obsidian Integration
**Falta:**
- Ã°Å¸Å¸Â¡ **Verificar completude do import** Ã¢â‚¬â€ parsing de frontmatter YAML para todos os tipos.
- Ã°Å¸Å¸Â¡ **Verificar export** Ã¢â‚¬â€ `toMarkdown()` de cada objeto gera YAML Dataview-compatible.
- Ã°Å¸Å¸Â¢ **Dataview queries** Ã¢â‚¬â€ `dataview_generator.dart` existe. UI para mostrar resultados de queries.

---

## 19. SEARCH & NAVIGATION

### Bug identificado pelo usuÃƒÂ¡rio Ã¢â‚¬â€ resultado da pesquisa nÃƒÂ£o abre
- Ã°Å¸â€Â´ **Clicar num resultado nÃƒÂ£o abre nada** Ã¢â‚¬â€ analisando o `_buildResultTile`: o `onTap` chama `Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalDetailView(object: obj, ...)))`. O objeto `obj` vem da lista `_results` que foi populada por `_searchService.search(allObjects, query)`. Causas provÃƒÂ¡veis:
  1. **`allObjectsAsync` ainda `loading` quando o tap ocorre** Ã¢â‚¬â€ `_onSearchChanged` ÃƒÂ© chamado apenas quando `allObjectsAsync.whenData(...)` resolve. Se o provider ainda estÃƒÂ¡ carregando, `_results` fica vazio e nenhum tile aparece. Mas se aparecem tiles, os objetos existem.
  2. **`Navigator.push` no contexto errado** Ã¢â‚¬â€ `SearchScreen` usa `AppBar` com `leading: IconButton(onPressed: () => Navigator.pop(context))`, o que indica que ÃƒÂ© empurrada via `Navigator.push`. O contexto deve estar correto.
  3. **`GoRouter` interceptando** Ã¢â‚¬â€ o app usa `GoRouter` (`app_shell.dart` usa `GoRouterState.of(context)`). Se `SearchScreen` for aberta via `context.go('/search')` em vez de `Navigator.push`, o `Navigator.push` dentro dela pode estar tentando empurrar sobre uma rota gerenciada pelo GoRouter e sendo silenciado. **SoluÃƒÂ§ÃƒÂ£o**: substituir `Navigator.push` em `_buildResultTile` por `context.push('/detail/\${obj.id}')` do GoRouter, ou verificar se existe rota `/detail/:id` registrada e testar com `context.go`.
  4. **`UniversalDetailView` nÃƒÂ£o reconhece o tipo** Ã¢â‚¬â€ se o objeto for de um tipo sem case no switch do `UniversalDetailView`, pode retornar tela em branco. Verificar se todos os tipos retornados pela busca tÃƒÂªm tratamento.

### Bug identificado pelo usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Pull-to-search muito sensÃƒÂ­vel** Ã¢â‚¬â€ ver item 13 (Planner). Mesmo problema se o gesto de abrir busca ÃƒÂ© via pull-down na home/planner. Aumentar threshold ou mudar para gesto explÃƒÂ­cito.

### SearchScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Busca full-text** Ã¢â‚¬â€ buscar tambÃƒÂ©m no body/notes de notas, journal, tasks.
- Ã°Å¸Å¸Â¡ **Busca por tag** Ã¢â‚¬â€ digitar `#tag`.
- Ã°Å¸Å¸Â¡ **Busca por organizer** Ã¢â‚¬â€ digitar `@projeto`.
- Ã°Å¸Å¸Â¡ **AÃƒÂ§ÃƒÂ£o rÃƒÂ¡pida nos resultados** Ã¢â‚¬â€ completar task, marcar hÃƒÂ¡bito, diretamente do resultado.
- Ã°Å¸Å¸Â¢ **Recentes persistentes** Ã¢â‚¬â€ `_recentSearches` ÃƒÂ© hardcoded com 3 strings fixas. Persistir no storage.
- Ã°Å¸Å¸Â¢ **Resultados agrupados por tipo**.

### CommandCenter (overlay)
**Falta:**
- Ã°Å¸Å¸Â¡ **Comandos de navegaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ `/planner`, `/habits`, `/notes`.
- Ã°Å¸Å¸Â¡ **Criar objeto por linguagem natural** Ã¢â‚¬â€ "nova tarefa [tÃƒÂ­tulo]".

---

## 20. SETTINGS & APPEARANCE

### Pedido do usuÃƒÂ¡rio Ã¢â‚¬â€ Color Picker global
- Ã¢Å“â€¦ Ver item 26 separado. **Regra global: nunca pedir HEX. Sempre picker visual.**

### AppearanceScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Temas de cor personalizados** Ã¢â‚¬â€ cor primÃƒÂ¡ria (accent color) do app.
- Ã°Å¸Å¸Â¡ **Preview em tempo real** das configuraÃƒÂ§ÃƒÂµes.
- Ã°Å¸Å¸Â¢ **Tamanho de fonte**.
- Ã°Å¸Å¸Â¢ **ÃƒÂcone do app alternativo** (iOS/Android).

### SettingsScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **ConfiguraÃƒÂ§ÃƒÂ£o de Pomodoro** Ã¢â‚¬â€ duraÃƒÂ§ÃƒÂ£o work/short break/long break.
- Ã¢Å“â€¦ **ConfiguraÃƒÂ§ÃƒÂ£o de mood** Ã¢â‚¬â€ `mood_settings_screen.dart` implementado:
  - Limite de 15 humores com mensagem ao tentar exceder
  - `_MoodHeader` mostra `X/15 configurados`, lista de valores faltando e barra de progresso
  - PrÃƒÂ³ximo valor disponÃƒÂ­vel prÃƒÂ©-preenchido ao criar novo humor
  - ValidaÃƒÂ§ÃƒÂ£o de duplicata de valor numÃƒÂ©rico
  - Valor numÃƒÂ©rico em destaque em cada tile
  - Undo ao deletar
- Ã°Å¸â€Â´ **`color` picker no form de mood** Ã¢â‚¬â€ o campo ainda ÃƒÂ© TextField de HEX (`'Cor hex (ex: #9E9E9E)'`) no `AlertDialog` de ediÃƒÂ§ÃƒÂ£o. Substituir por picker visual (ver item 26).
- Ã°Å¸Å¸Â¡ **ConfiguraÃƒÂ§ÃƒÂ£o de categorias** Ã¢â‚¬â€ `category_management_screen.dart` existe, verificar completude.
- Ã°Å¸Å¸Â¢ **Exportar todos os dados** Ã¢â‚¬â€ ZIP de todos os markdowns.
- Ã°Å¸Å¸Â¢ **Importar de backup**.
- Ã°Å¸Å¸Â¢ **Limpar dados** com confirmaÃƒÂ§ÃƒÂ£o dupla.

---

## 21. ARCHIVE, TRASH & INBOX

### Archive Screen
**Falta:**
- Ã°Å¸Å¸Â¡ **Filtro por tipo**.
- Ã°Å¸Å¸Â¡ **Restaurar em lote**.
- Ã°Å¸Å¸Â¢ **Data de arquivamento**.

### Deleted Files Screen
**Falta:**
- Ã°Å¸Å¸Â¡ **PerÃƒÂ­odo de retenÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ itens por X dias antes de deletar permanentemente.
- Ã°Å¸Å¸Â¡ **Preview do item** Ã¢â‚¬â€ ver conteÃƒÂºdo antes de restaurar/deletar.
- Ã°Å¸Å¸Â¢ **Esvaziar lixeira** com confirmaÃƒÂ§ÃƒÂ£o dupla.

### InboxScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Triagem GTD** Ã¢â‚¬â€ processar cada item: converter em task, nota, lembrete, arquivar, deletar.
- Ã°Å¸Å¸Â¢ **Badge de contagem** na nav.

---

## 22. TEMPLATES

**Falta (praticamente tudo):**
- Ã°Å¸â€Â´ **Lista de templates** Ã¢â‚¬â€ tela para ver, criar, editar templates.
- Ã°Å¸â€Â´ **Templates de diÃƒÂ¡rio aplicÃƒÂ¡veis** Ã¢â‚¬â€ picker no form de JournalEntry com estrutura de perguntas prÃƒÂ©-definidas.
- Ã°Å¸Å¸Â¡ **Templates por tipo** Ã¢â‚¬â€ task, nota, goal, tracker.
- Ã°Å¸Å¸Â¡ **Aplicar template no form** Ã¢â‚¬â€ opÃƒÂ§ÃƒÂ£o "Usar template" que prÃƒÂ©-preenche.
- Ã°Å¸Å¸Â¢ **Compartilhar templates** Ã¢â‚¬â€ exportar/importar como JSON.

---

## 23. ORGANIZER

### OrganizerDetailScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Layout por subtipo** Ã¢â‚¬â€ project abre com kanban, ÃƒÂ¡rea abre com lista.
- Ã°Å¸Å¸Â¡ **Todos os itens vinculados** Ã¢â‚¬â€ tasks, notes, goals, habits com esse organizer.
- Ã°Å¸Å¸Â¢ **Criar sub-organizer** dentro de uma ÃƒÂ¡rea.

### Organizer Chips / Picker
- Ã°Å¸Å¸Â¡ **Criar novo organizer inline** Ã¢â‚¬â€ "Criar '[nome]' como projeto/ÃƒÂ¡rea" ao digitar nome novo.

---

## 24. KPI & ANALYSIS

**Falta:**
- Ã°Å¸Å¸Â¡ **KPI screen** Ã¢â‚¬â€ tela dedicada de gerenciamento e visualizaÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **KPI com fonte automÃƒÂ¡tica** Ã¢â‚¬â€ vincular a campo de tracker, streak de hÃƒÂ¡bito, contagem de tasks.
- Ã°Å¸Å¸Â¡ **HistÃƒÂ³rico de KPI** Ã¢â‚¬â€ registrar valor ao longo do tempo para trending.

### CombinedAnalysisScreen / StatisticsScreen
**Falta:**
- Ã°Å¸Å¸Â¡ **Filtro por perÃƒÂ­odo** Ã¢â‚¬â€ semana, mÃƒÂªs, 3 meses, 1 ano, personalizado.
- Ã°Å¸Å¸Â¡ **ComparaÃƒÂ§ÃƒÂ£o de perÃƒÂ­odos** Ã¢â‚¬â€ esta semana vs semana passada.
- Ã°Å¸Å¸Â¢ **CorrelaÃƒÂ§ÃƒÂµes** Ã¢â‚¬â€ hÃƒÂ¡bitos vs mood, foco vs tasks concluÃƒÂ­das.
- Ã°Å¸Å¸Â¢ **Export de dados**.

---

## 25. NOTIFICATIONS

**Falta:**
- Ã°Å¸Å¸Â¡ **NotificaÃƒÂ§ÃƒÂµes para todos os tipos** Ã¢â‚¬â€ tasks com deadline, habits sem check, goals vencendo, pessoas para contatar.
- Ã°Å¸Å¸Â¡ **NotificaÃƒÂ§ÃƒÂµes com aÃƒÂ§ÃƒÂµes** Ã¢â‚¬â€ completar task/habit direto da notificaÃƒÂ§ÃƒÂ£o.
- Ã°Å¸Å¸Â¡ **Scheduled notifications para schedulers** Ã¢â‚¬â€ agendar localmente para prÃƒÂ³ximas ocorrÃƒÂªncias.
- Ã°Å¸Å¸Â¢ **Agrupamento** Ã¢â‚¬â€ no Android, notification group.
- Ã°Å¸Å¸Â¢ **Popup notifications** Ã¢â‚¬â€ `popup_notification_screen.dart` existe. Verificar integraÃƒÂ§ÃƒÂ£o enquanto app estÃƒÂ¡ aberto.

---

## 26. COLOR PICKER (GLOBAL)

### Pedido do usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Nunca pedir HEX. Sempre picker visual.** Regra que se aplica a todos os pontos do app onde hÃƒÂ¡ seleÃƒÂ§ÃƒÂ£o de cor:
  - Moods (`mood_settings_screen.dart`) Ã¢â‚¬â€ campo HEX atual deve ser substituÃƒÂ­do
  - TimeBlock (form de criaÃƒÂ§ÃƒÂ£o/ediÃƒÂ§ÃƒÂ£o)
  - DayTheme (form de criaÃƒÂ§ÃƒÂ£o/ediÃƒÂ§ÃƒÂ£o)
  - Task, Habit, Goal, Note, Project, Organizer Ã¢â‚¬â€ onde `color` estÃƒÂ¡ exposto

**SoluÃƒÂ§ÃƒÂ£o sugerida:** Criar um `AppColorPicker` widget reutilizÃƒÂ¡vel com:
- **Paleta de cores predefinidas** Ã¢â‚¬â€ grid de ~20 cores com boa distribuiÃƒÂ§ÃƒÂ£o (ex: Material colors ou paleta customizada do app)
- **OpÃƒÂ§ÃƒÂ£o "personalizada"** Ã¢â‚¬â€ sÃƒÂ³ se o usuÃƒÂ¡rio escolher esta opÃƒÂ§ÃƒÂ£o, mostrar o color wheel ou o campo HEX, com preview em tempo real
- O widget deve retornar `String` (hex normalizado como `#RRGGBB`)
- Uso via `showModalBottomSheet` ou `showDialog` com preview da cor selecionada ao lado do nome

---

## 27. 

## 28. ACCESSIBILITY & POLISH GERAL

### Crash / ANR Diagnostics
- Ã¢Å“â€¦ **Local Crash Diagnostics** Ã¢â‚¬â€ Sistema de captura de erros e ANR com relatÃƒÂ³rios markdown em _diagnostics.

### Acessibilidade
- Ã°Å¸Å¸Â¡ **Semantics** Ã¢â‚¬â€ todos os cards, botÃƒÂµes e campos interativos precisam de `Semantics` com `label`, `value`, `button`, `hint`.
- Ã°Å¸Å¸Â¡ **Tamanho mÃƒÂ­nimo de toque** Ã¢â‚¬â€ 44x44dp para todos os elementos interativos.
- Ã°Å¸Å¸Â¢ **Contraste WCAG AA** Ã¢â‚¬â€ verificar tema dark/light.
- Ã°Å¸Å¸Â¢ **VoiceOver / TalkBack** Ã¢â‚¬â€ teste com screen reader.

### Empty States
- Ã°Å¸Å¸Â¡ **Illustrations** Ã¢â‚¬â€ cada tela principal com empty state especÃƒÂ­fico e call-to-action claro.
- Ã°Å¸Å¸Â¡ **Onboarding** Ã¢â‚¬â€ hints na primeira visita a cada tela principal.

### Loading & Errors
- Ã°Å¸Å¸Â¡ **Skeleton loading** Ã¢â‚¬â€ estender para listas de tasks, habits, notes.
- Ã°Å¸Å¸Â¡ **Error states especÃƒÂ­ficos** Ã¢â‚¬â€ sync falhou, vault nÃƒÂ£o encontrado, permissÃƒÂ£o negada, com aÃƒÂ§ÃƒÂ£o de retry.

### AnimaÃƒÂ§ÃƒÂµes & Micro-interaÃƒÂ§ÃƒÂµes
- Ã°Å¸Å¸Â¡ **Completar task** Ã¢â‚¬â€ scale + fade ao marcar como done.
- Ã°Å¸Å¸Â¡ **Completar hÃƒÂ¡bito** Ã¢â‚¬â€ animaÃƒÂ§ÃƒÂ£o de streak ao completar.
- Ã°Å¸Å¸Â¢ **Shared element transitions** Ã¢â‚¬â€ ao abrir detalhe de objeto.
- Ã°Å¸Å¸Â¢ **Pull-to-refresh animado**.

### FormulÃƒÂ¡rios
- Ã°Å¸Å¸Â¡ **Dismiss com confirmaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ "Descartar alteraÃƒÂ§ÃƒÂµes?" ao fechar form com dados.
- Ã°Å¸Å¸Â¡ **Keyboard avoidance** Ã¢â‚¬â€ garantir que teclado nÃƒÂ£o cobre o campo sendo editado.
- Ã°Å¸Å¸Â¢ **ValidaÃƒÂ§ÃƒÂ£o em tempo real**.
- Ã°Å¸Å¸Â¢ **Auto-focus** Ã¢â‚¬â€ cursor direto no primeiro campo ao abrir form.

### UX de DeleÃƒÂ§ÃƒÂ£o
- Ã¢Å“â€¦ Undo snackbar para tasks Ã¢â‚¬â€ implementado com `UndoService`
- Ã¢Å“â€¦ Undo snackbar para moods Ã¢â‚¬â€ implementado no `_confirmDeleteMood`
- Ã°Å¸Å¸Â¡ **Undo snackbar** Ã¢â‚¬â€ estender para habits, notes, goals, reminders, journal entries.
- Ã°Å¸Å¸Â¡ **Swipe to delete/archive** Ã¢â‚¬â€ implementar consistentemente em todas as listas.

---

## RESUMO DE PRIORIDADES

### Ã°Å¸â€Â´ CrÃƒÂ­tico Ã¢â‚¬â€ bugs ou fluxo principal quebrado
1. ~~Mood settings: limite de 15, valor numÃƒÂ©rico visÃƒÂ­vel, header de progresso~~ Ã¢Å“â€¦ implementado Ã¢â‚¬â€ **falta apenas**: substituir campo HEX de cor por picker visual
2. HÃƒÂ¡bito com mÃƒÂºltiplos slots no **modo agenda** do planner: cada slot precisa de linha + botÃƒÂ£o separado (timeline jÃƒÂ¡ estÃƒÂ¡ correto)
3. Planner nÃƒÂ£o auto-scrolla para o horÃƒÂ¡rio atual ao abrir
4. Pull-to-search disparando sem querer Ã¢â‚¬â€ aumentar threshold ou remover gesto
5. Pesquisa: clicar num resultado nÃƒÂ£o abre nada Ã¢â‚¬â€ provÃƒÂ¡vel conflito `Navigator.push` vs `GoRouter`
6. IDs visÃƒÂ­veis: `entry.moodSlug` exibido como texto no card de journal (Planner). Texto `'Sem ÃƒÂ¡rea'` no CalendarWidget deve ser `''`
7. CalendarWidget: remover toggle Dia/Sem/MÃƒÂªs Ã¢â€ â€™ fixar semana + ÃƒÂ­cone sync + botÃƒÂ£o `+`
8. CalendarWidget: lista inline do dia nÃƒÂ£o inclui eventos GCal nem lembretes
9. TimeBlock/DayTheme: sem tela de ediÃƒÂ§ÃƒÂ£o (tocar nÃƒÂ£o faz nada)
10. SchedulerPicker: `daysOfTheme` e `daysWithBlock` nÃƒÂ£o expostos na UI
11. Color picker: substituir HEX por picker visual em todo o app (moods, blocks, themes, habits, tasks, goals)
12. 
13. AnÃƒÂ¡lise: dias sem registro aparecem como zero na linha Ã¢â‚¬â€ `_getValueForDate` deve retornar `null`, `CitrineChart` deve filtrar spots nulos

### Ã°Å¸Å¸Â¡ Importante Ã¢â‚¬â€ experiÃƒÂªncia incompleta
11. `dependsOn` picker no form de Task
12. `estimatedMinutes` e `timeBlock` picker no form de Task
13. MÃƒÂºltiplos TimeRanges por bloco na criaÃƒÂ§ÃƒÂ£o
14. MÃƒÂºltiplos slots no form de Habit + renderizaÃƒÂ§ÃƒÂ£o separada no planner
15. Ã¢Å“â€¦ Social: seÃƒÂ§ÃƒÂ£o de objetos vinculados por tipo no form e no detalhe (Implementado)
16. Planner: header de bloco clicÃƒÂ¡vel para editar
17. Person: aÃƒÂ§ÃƒÂµes rÃƒÂ¡pidas (ligar, email, WhatsApp)
18. Tracker record form: renderizaÃƒÂ§ÃƒÂ£o por tipo de campo
19. Goal: KPIs + progress bar no detalhe
20. Template de diÃƒÂ¡rio aplicÃƒÂ¡vel no form

### Ã°Å¸Å¸Â¢ Melhoria Ã¢â‚¬â€ polimento
21. Empty states com ilustraÃƒÂ§ÃƒÂµes
22. Skeleton loading generalizado
23. Swipe to delete/archive consistente
24. AnimaÃƒÂ§ÃƒÂµes de completar task/habit
25. Export CSV de trackers e highlights
26. ConfiguraÃƒÂ§ÃƒÂ£o de cores do tema (accent color)
27. Recentes persistentes na busca

---

## 29. ANÃƒÂLISE Ã¢â‚¬â€ GAPS DE DADOS / DIAS SEM REGISTRO

### Pedido do usuÃƒÂ¡rio
- Ã¢Å“â€¦ **Dias sem registro no tracker nÃƒÂ£o devem aparecer como zero Ã¢â‚¬â€ devem interromper a linha e retomar quando houver dado de novo.**

### DiagnÃƒÂ³stico exato

Em `_getMetricData()` no `CombinedAnalysisScreen`, para cada um dos 14 dias ÃƒÂ© chamado `_getValueForDate()`, que retorna `0.0` quando nÃƒÂ£o hÃƒÂ¡ registro. Esse `0.0` ÃƒÂ© passado para o `CitrineChart` como `FlSpot(x, 0.0)`, fazendo a linha despencar para o zero nesses dias.

No `CitrineChart._buildLineChart()`, todos os pontos de todas as sÃƒÂ©ries sÃƒÂ£o passados diretamente como `spots` no `LineChartBarData`, sem nenhuma distinÃƒÂ§ÃƒÂ£o entre "valor real zero" e "sem dado".

### O que precisa mudar

**1. Diferenciar "sem dado" de "valor zero"**

`_getValueForDate()` retorna `double`. Mudar o retorno para `double?` Ã¢â‚¬â€ retornar `null` quando nÃƒÂ£o hÃƒÂ¡ registro e o valor numÃƒÂ©rico real (incluindo `0.0`) quando hÃƒÂ¡.

Todos os mÃƒÂ©todos de coleta precisam acompanhar:
- `_getMoodValueForDate` Ã¢â€ â€™ retorna `null` se `dayEntries.isEmpty` ou nenhum mood
- `_getHabitValueForDate` Ã¢â€ â€™ retorna `null` se o hÃƒÂ¡bito nÃƒÂ£o existe ou nÃƒÂ£o tem registro; `1.0` se completou; `0.0` sÃƒÂ³ se explicitamente registrado como nÃƒÂ£o feito (se o design quiser)
- `_getTrackerValueForDate` Ã¢â€ â€™ retorna `null` se `dayRecords.isEmpty` para aquele tracker/campo
- `_getTrackerScoreForDate` Ã¢â€ â€™ retorna `null` se sem registros
- `_getPomodoroValueForDate` Ã¢â€ â€™ retorna `null` se sem sessÃƒÂµes completadas no dia (nÃƒÂ£o `0.0`)
- `_getGoogleEventValueForDate` Ã¢â€ â€™ manter `0.0` pois "0 eventos" ÃƒÂ© um dado vÃƒÂ¡lido (ou tratar como `null` se sem eventos, dependendo da intenÃƒÂ§ÃƒÂ£o da usuÃƒÂ¡ria)

**2. `ChartDataPoint` aceitar valor nulo**

```dart
class ChartDataPoint {
  final String label;
  final double? value; // null = sem dado
  final Color? color;
}
```

**3. `CitrineChart._buildLineChart()` pular pontos nulos**

Na construÃƒÂ§ÃƒÂ£o dos `spots`, filtrar os pontos com `value == null` e nÃƒÂ£o incluÃƒÂ­-los na sÃƒÂ©rie:

```dart
spots: d
    .asMap()
    .entries
    .where((e) => e.value.value != null)   // pular dias sem dado
    .map((e) => FlSpot(e.key.toDouble(), e.value.value!))
    .toList(),
```

Com isso, o `fl_chart` automaticamente desenha a linha apenas entre os pontos existentes, deixando um espaÃƒÂ§o visual (linha interrompida) nos dias sem dado. Se a lista de spots ficar vazia para uma sÃƒÂ©rie inteira, o `LineChartBarData` nÃƒÂ£o deve ser adicionado (ou adicionar com `spots: []` que o `fl_chart` ignora silenciosamente).

**4. Ponto visual diferenciado (opcional mas recomendado)**

Para deixar claro para a usuÃƒÂ¡ria que a linha foi interrompida por falta de dado (e nÃƒÂ£o porque o valor foi zero), adicionar um dot de cor diferente no ÃƒÂºltimo ponto antes da lacuna e no primeiro depois Ã¢â‚¬â€ ou simplesmente garantir que `dotData: FlDotData(show: true)` esteja ativo para sÃƒÂ©ries com gaps.

**5. `_buildBarChart()` Ã¢â‚¬â€ mesmo tratamento**

Barras de valor `0.0` ficam invisÃƒÂ­veis mas ocupam espaÃƒÂ§o no eixo X, criando confusÃƒÂ£o. Para dias sem dado, nÃƒÂ£o criar `BarChartGroupData` para aquele ÃƒÂ­ndice Ã¢â‚¬â€ ou criar com altura zero e cor transparente para manter o espaÃƒÂ§amento do eixo X (dependendo da preferÃƒÂªncia visual).

**6. CalendÃƒÂ¡rio de anÃƒÂ¡lise (`AnalysisCalendar`)**

Em `_getCalendarData()`, a condiÃƒÂ§ÃƒÂ£o atual ÃƒÂ© `if (value > 0)` para adicionar a fonte ao dia. Isso jÃƒÂ¡ filtra os dias com `value == 0`, mas com a mudanÃƒÂ§a para `double?`, a condiÃƒÂ§ÃƒÂ£o deve ser `if (value != null)` para que dias com valor real `0.0` ainda apareÃƒÂ§am no calendÃƒÂ¡rio se forem dados legÃƒÂ­timos.

### Impacto em outros grÃƒÂ¡ficos

- **`StatisticsScreen`** Ã¢â‚¬â€ se usa `CitrineChart` ou lÃƒÂ³gica similar de coleta de dados, aplicar o mesmo padrÃƒÂ£o.
- **`TrackerMetricCard`** (`tracker_metric_card.dart`) Ã¢â‚¬â€ se exibe sparkline do tracker, verificar se tambÃƒÂ©m trata ausÃƒÂªncia de dado como zero ou como gap.
- **Heatmap** (`ChartType.heatmap`) Ã¢â‚¬â€ cÃƒÂ©lulas sem dado (`value == null`) devem usar a cor de "vazio" (`surfaceVariant`), nÃƒÂ£o a cor de intensidade zero da sÃƒÂ©rie. Atualmente jÃƒÂ¡ faz isso via `intensity > 0`, mas com `null` o tratamento fica mais explÃƒÂ­cito.


---

## 29. HOME SCREEN Ã¢â‚¬â€ GAPS ADICIONAIS ENCONTRADOS

### Pull-to-search (CommandCenter)
- Ã¢Å“â€¦ **Threshold de -80px ÃƒÂ© muito baixo** Ã¢â‚¬â€ o `ScrollUpdateNotification` dispara o `showCommandCenter` com apenas 80px de overscroll na fÃƒÂ­sica `BouncingScrollPhysics`. Em scroll rÃƒÂ¡pido ou rebote do final da lista isso dispara acidentalmente. Aumentar para pelo menos -140px e adicionar flag `_commandCenterOpenedThisScroll` que previne mÃƒÂºltiplas aberturas na mesma sequÃƒÂªncia de scroll.

### BlockType.timeBlocking Ã¢â‚¬â€ conteÃƒÂºdo errado
- Ã°Å¸â€Â´ **`_buildTimeBlockingBlock()` mostra tasks com `scheduledTime`, nÃƒÂ£o TimeBlocks do DayTheme** Ã¢â‚¬â€ o bloco mostra tarefas com horÃƒÂ¡rio agendado do dia, mas o nome "Time Blocks" promete mostrar os blocos do tema ativo. Deve ser refatorado para mostrar: tema do dia ativo + seus blocos com faixas de horÃƒÂ¡rio + count de tasks por bloco.

### BlockType.customMarkdown Ã¢â‚¬â€ conteÃƒÂºdo hardcoded
- Ã°Å¸â€Â´ **`_buildCustomMarkdownBlock()` retorna string hardcoded** Ã¢â‚¬â€ "Reminder: Drink water, Stretch every hour". NÃƒÂ£o hÃƒÂ¡ mecanismo de ediÃƒÂ§ÃƒÂ£o. O bloco precisa de `metadata['markdownContent']` salvo no `DashboardBlock` e um botÃƒÂ£o de editar que abre um campo de texto.

### BlockType.quotes Ã¢â‚¬â€ hardcoded
- Ã°Å¸â€Â´ **`_buildQuoteBlock()` retorna quote hardcoded** Ã¢â‚¬â€ Peter Drucker. Sem rotaÃƒÂ§ÃƒÂ£o, sem pool de quotes do usuÃƒÂ¡rio. Adicionar `metadata['quotes']` como lista e exibir uma aleatÃƒÂ³ria a cada abertura do app, com botÃƒÂ£o de adicionar/remover quotes na configuraÃƒÂ§ÃƒÂ£o do bloco.

### BlockType.analysisTrend Ã¢â‚¬â€ cÃƒÂ¡lculo impreciso
- Ã°Å¸Å¸Â¡ **`_buildAnalysisBlock()` calcula consistency incorretamente** Ã¢â‚¬â€ divide total de streaks por `habits.length * 7`, o que ÃƒÂ© uma heurÃƒÂ­stica muito aproximada. Deveria usar `completionHistory` dos ÃƒÂºltimos 7 dias reais para calcular taxa de conclusÃƒÂ£o.

### BlockType.habitTrend Ã¢â‚¬â€ dados aproximados
- Ã°Å¸Å¸Â¡ **`_buildHabitHeatmapBlock()` usa `daysSinceLastCompletion` para estimar completions passados** Ã¢â‚¬â€ isso nÃƒÂ£o reflete o histÃƒÂ³rico real. Deveria iterar `habit.completionHistory` para construir o mapa de atividade dos ÃƒÂºltimos 28 dias.

### BlockType.pinnedObject Ã¢â‚¬â€ sem implementaÃƒÂ§ÃƒÂ£o real
- Ã°Å¸Å¸Â¡ **`_buildPinnedObjectBlock()` nÃƒÂ£o foi encontrado no cÃƒÂ³digo lido** Ã¢â‚¬â€ o mÃƒÂ©todo ÃƒÂ© chamado no switch do `_buildBlock()` mas sua implementaÃƒÂ§ÃƒÂ£o pode estar faltando ou ser mÃƒÂ­nima. Implementar como: picker de qualquer objeto via `UniversalSearchPickerSheet`, salvo no `metadata['pinnedId']`, exibindo preview inline do objeto (tÃƒÂ­tulo, subtÃƒÂ­tulo, ÃƒÂ­cone de tipo) com tap para abrir `UniversalDetailView`.

### Dashboard Ã¢â‚¬â€ pull-to-refresh ausente
- Ã°Å¸Å¸Â¡ **NÃƒÂ£o hÃƒÂ¡ `RefreshIndicator` ou mecanismo de pull-to-refresh** Ã¢â‚¬â€ o usuÃƒÂ¡rio nÃƒÂ£o tem como forÃƒÂ§ar reload dos dados sem fechar e reabrir o app. Adicionar `RefreshIndicator` no `CustomScrollView` ou botÃƒÂ£o de refresh no header.

### Dashboard Ã¢â‚¬â€ `_buildSyncIndicator` nÃƒÂ£o acessa todos os conflitos
- Ã°Å¸Å¸Â¢ **O tooltip de conflito mostra count mas o ÃƒÂ­cone de `SyncStatus.offline` ÃƒÂ© igual ao de `error`** Ã¢â‚¬â€ diferenciar visualmente os dois estados (ex: `cloud_off` para offline, `sync_problem` para error).

---

## 30. UNIVERSAL DETAIL VIEW Ã¢â‚¬â€ GAPS

NÃƒÂ£o foi possÃƒÂ­vel ler o arquivo completo, mas com base nos `Navigator.push` para `UniversalDetailView` por todo o app, identificamos:

- Ã°Å¸â€Â´ **EdiÃƒÂ§ÃƒÂ£o inline ausente para a maioria dos tipos** Ã¢â‚¬â€ o detalhe provavelmente sÃƒÂ³ exibe dados, sem ediÃƒÂ§ÃƒÂ£o inline de campos individuais (tÃƒÂ­tulo, notas, body). Cada tipo deveria ter campos editÃƒÂ¡veis diretamente no detalhe sem precisar abrir um form modal separado.
- Ã°Å¸â€Â´ **`TrackingRecord` no detalhe** Ã¢â‚¬â€ `_buildTrackingRecordItem` no planner abre `UniversalDetailView(object: record)`. Verificar se o detalhe de `TrackingRecord` renderiza os `fieldValues` de forma legÃƒÂ­vel (nome do campo + valor) e nÃƒÂ£o apenas "X fields filled".
- Ã°Å¸Å¸Â¡ **AÃƒÂ§ÃƒÂµes contextuais por tipo** Ã¢â‚¬â€ o `ObjectActionWrapper` existe para long-press. Verificar se as aÃƒÂ§ÃƒÂµes de cada tipo (completar task, toggle habit, arquivar, deletar, duplicar) estÃƒÂ£o todas implementadas e consistentes.
- Ã°Å¸Å¸Â¡ **NavegaÃƒÂ§ÃƒÂ£o para organizers** Ã¢â‚¬â€ chips de organizer no detalhe devem ser clicÃƒÂ¡veis e navegar para o detalhe do organizer.
- Ã°Å¸Å¸Â¢ **Compartilhar objeto** Ã¢â‚¬â€ botÃƒÂ£o de share que gera um texto/card exportÃƒÂ¡vel do objeto.

---

## 31. FORMS Ã¢â‚¬â€ GAPS TRANSVERSAIS ENCONTRADOS

Revisando os formulÃƒÂ¡rios encontrados:

### SchedulerPicker Ã¢â‚¬â€ dentro dos forms
- Ã°Å¸â€Â´ **`RepeatType.daysOfTheme` e `daysWithBlock`** Ã¢â‚¬â€ jÃƒÂ¡ listado no item 15, mas confirmado: esses tipos existem no `SchedulerService` mas nÃƒÂ£o hÃƒÂ¡ evidÃƒÂªncia de que o `SchedulerPicker` os expÃƒÂµe. Todos os forms que tÃƒÂªm scheduler (task, habit, reminder, goal) estÃƒÂ£o afetados.

### Color picker nos forms (item 26)
- Ã¢Å“â€¦ **Mood settings usa campo de texto HEX** Ã¢â‚¬â€ confirmado no `mood_settings_screen.dart`: `TextField(controller: colorController, decoration: InputDecoration(labelText: 'Cor hex (ex: #9E9E9E)'))`. Substituir por `AppColorPicker` visual.

### Forms sem dismiss confirmation
- Ã°Å¸Å¸Â¡ **Nenhum form tem "Descartar alteraÃƒÂ§ÃƒÂµes?"** Ã¢â‚¬â€ ao tocar fora ou pressionar voltar com campos preenchidos, o form fecha silenciosamente. Adicionar `WillPopScope` ou `PopScope` que detecta campos sujos e pergunta antes de fechar.

### Auto-scroll no keyboard
- Ã°Å¸Å¸Â¡ **FormulÃƒÂ¡rios longos podem ter campos ocultos pelo teclado** Ã¢â‚¬â€ verificar se todos os forms usam `SingleChildScrollView` com `keyboardDismissBehavior` adequado ou `resizeToAvoidBottomInset`.

---

## 32. MOOD Ã¢â‚¬â€ GAPS ADICIONAIS ENCONTRADOS

ApÃƒÂ³s anÃƒÂ¡lise do `mood_settings_screen.dart`:

### O que jÃƒÂ¡ estÃƒÂ¡ implementado Ã¢Å“â€¦
- Ã¢Å“â€¦ Limite de 15 humores com bloqueio do botÃƒÂ£o "Adicionar"
- Ã¢Å“â€¦ Header `_MoodHeader` mostra `X/15 configurados`, barra de progresso e valores faltando
- Ã¢Å“â€¦ Valor numÃƒÂ©rico visÃƒÂ­vel no tile de cada mood (bloco colorido com nÃƒÂºmero)
- Ã¢Å“â€¦ ValidaÃƒÂ§ÃƒÂ£o de valor duplicado ao salvar
- Ã¢Å“â€¦ Auto-sugestÃƒÂ£o do prÃƒÂ³ximo valor disponÃƒÂ­vel
- Ã¢Å“â€¦ Undo snackbar ao deletar mood com restauraÃƒÂ§ÃƒÂ£o

### O que ainda falta
- Ã¢Å“â€¦ **Color picker visual** Ã¢â‚¬â€ campo de texto HEX no dialog de ediÃƒÂ§ÃƒÂ£o. Substituir por grid de cores predefinidas + opÃƒÂ§ÃƒÂ£o de personalizar (ver item 26).
- Ã°Å¸Å¸Â¡ **Cor hardcoded no tile** Ã¢â‚¬â€ `_MoodTile` exibe o hex como texto (`mood.color`). Substituir por apenas o dot colorido sem mostrar o cÃƒÂ³digo hex ao usuÃƒÂ¡rio.
- Ã°Å¸Å¸Â¡ **Preview da cor ao selecionar** Ã¢â‚¬â€ ao escolher cor no picker, mostrar preview do emoji com fundo colorido em tempo real antes de salvar.
- Ã°Å¸Å¸Â¡ **Reorder via drag** Ã¢â‚¬â€ `ReorderableListView` existe, mas a ordem de `sortedMoods` ÃƒÂ© sempre por `numericValue`, o que torna o drag ineficaz (a lista reordena, salva `order`, mas na prÃƒÂ³xima build re-sort por `numericValue`). Ou: reorder por `numericValue` (trocar os valores), ou: manter ordem por `order` apenas e nÃƒÂ£o por `numericValue`. Clarificar semÃƒÂ¢ntica: o `numericValue` ÃƒÂ© um campo de escala (1-15) separado da ordem de exibiÃƒÂ§ÃƒÂ£o?
- Ã°Å¸Å¸Â¢ **Emoji picker** Ã¢â‚¬â€ campo livre de texto para emoji. Substituir por um seletor de emoji com grid ou picker nativo.

---

## RESUMO FINAL DE PRIORIDADES (ATUALIZADO)
> ÃƒÅ¡ltima atualizaÃƒÂ§ÃƒÂ£o: 07/06/2026

### Ã°Å¸â€Â´ CrÃƒÂ­tico Ã¢â‚¬â€ bugs ou fluxo quebrado
1. ~~HÃƒÂ¡bito com mÃƒÂºltiplos slots: completar um completa todos~~ Ã¢Å“â€¦
2. ~~Pesquisa: clicar num resultado nÃƒÂ£o abre nada~~ Ã¢Å“â€¦
3. ~~IDs/slugs visÃƒÂ­veis nos cards~~ Ã¢Å“â€¦
4. ~~Planner nÃƒÂ£o abre no horÃƒÂ¡rio atual Ã¢â‚¬â€ sem auto-scroll~~ Ã¢Å“â€¦
5. ~~Pull-to-search muito sensÃƒÂ­vel~~ Ã¢Å“â€¦
6. ~~CalendarWidget: remover toggles Dia/Sem/MÃƒÂªs~~ Ã¢Å“â€¦
7. ~~TimeBlock/DayTheme: sem tela de ediÃƒÂ§ÃƒÂ£o ao tocar~~ Ã¢Å“â€¦ Ã¢â‚¬â€ `_showBlockDialog` e `_showThemeDialog` implementados em `day_theme_screen.dart` com `AppColorPicker`, mÃƒÂºltiplos `TimeRange` e seleÃƒÂ§ÃƒÂ£o de dias/blocos
8. ~~SchedulerPicker: sem `daysOfTheme`/`daysWithBlock`~~ Ã¢Å“â€¦ Ã¢â‚¬â€ ambas as opÃƒÂ§ÃƒÂµes expostas no picker
9. ~~Color picker: substituir campo HEX por picker visual~~ Ã¢Å“â€¦ Ã¢â‚¬â€ `AppColorPicker` integrado em `mood_settings_screen.dart` e `day_theme_screen.dart`
10. ~~`_buildTimeBlockingBlock()`: conteÃƒÂºdo errado~~ Ã¢Å“â€¦ Ã¢â‚¬â€ refatorado para mostrar tema ativo + blocos com faixas de horÃƒÂ¡rio
11. ~~`_buildCustomMarkdownBlock()`: conteÃƒÂºdo hardcoded, sem ediÃƒÂ§ÃƒÂ£o~~ Ã¢Å“â€¦ Ã¢â‚¬â€ editor via `_showCustomMarkdownEditor` salvo em `metadata['content']`
12. ~~`_buildQuoteBlock()`: quote hardcoded, sem pool configurÃƒÂ¡vel~~ Ã¢Å“â€¦ Ã¢â‚¬â€ pool em `metadata['quotes']`, rotaÃƒÂ§ÃƒÂ£o diÃƒÂ¡ria, editor via `_showQuotePoolEditor`
13. Ã¢Å“â€¦ ~~Social: seÃƒÂ§ÃƒÂ£o de objetos vinculados por tipo no form e no detalhe~~ Ã¢â‚¬â€ implementado com agrupamento por `displayType` e chips de objeto com tÃƒÂ­tulo legÃƒÂ­vel
14. ~~Highlights/citaÃƒÂ§ÃƒÂµes de livros~~ Ã¢â‚¬â€ cancelado pela usuÃƒÂ¡ria
15. ~~`timeBlocks` nÃƒÂ£o passado ao `TimeLineDayView`~~ Ã¢Å“â€¦ Ã¢â‚¬â€ `activeTimeBlocks` passado corretamente no `PlannerScreen`

### Ã°Å¸Å¸Â¡ Importante Ã¢â‚¬â€ experiÃƒÂªncia incompleta
16. Ã¢Å“â€¦ ~~Mood: color picker visual~~ Ã¢â‚¬â€ `AppColorPicker` no dialog de ediÃƒÂ§ÃƒÂ£o de humor; dot colorido no tile sem mostrar hex
17. Ã¢Å“â€¦ ~~Mood: emoji picker~~ Ã¢â‚¬â€ grid de emojis selecionÃƒÂ¡veis implementado no `mood_settings_screen.dart`
18. Ã¢Å“â€¦ ~~`dependsOn` picker no form de Task~~ Ã¢â‚¬â€ implementado via `UniversalSearchPickerSheet` com chips
19. Ã¢Å“â€¦ ~~`estimatedMinutes` e `timeBlock` picker no form de Task~~ Ã¢â‚¬â€ `_estimatedMinutes` com sugestÃƒÂµes rÃƒÂ¡pidas + `TimeBlockPicker` implementados
20. Ã¢Å“â€¦ ~~MÃƒÂºltiplos TimeRanges por bloco~~ Ã¢â‚¬â€ suportado no `_showBlockDialog` com botÃƒÂ£o "Adicionar intervalo"
21. Ã¢Å“â€¦ ~~MÃƒÂºltiplos slots no form de Habit + renderizaÃƒÂ§ÃƒÂ£o separada por slot no planner~~ Ã¢â‚¬â€ `_buildHabitCard` Ã¢â€ â€™ `_buildHabitSlotRow` com `slotIndex` individual por slot
22. Ã¢Å“â€¦ ~~KPIs + progress bar no detalhe de Goal~~ Ã¢â‚¬â€ `_buildKPICard` com `KPIEngine.calculateKPIValue` e `LinearProgressIndicator` implementados
23. Ã¢Å“â€¦ ~~Template de diÃƒÂ¡rio aplicÃƒÂ¡vel no form~~ Ã¢â‚¬â€ `create_entry_form.dart` jÃƒÂ¡ tem picker de templates (linha 882) e aplica automÃƒÂ¡tico via `reviewDailyTemplateId` nas settings
24. Ã¢Å“â€¦ ~~Person: aÃƒÂ§ÃƒÂµes rÃƒÂ¡pidas (ligar, email, WhatsApp) + status de contato~~ Ã¢â‚¬â€ `_contactActionButton` (WhatsApp, Message, Call, Email) + barra de progress de frequÃƒÂªncia implementados
25. Ã¢Å“â€¦ ~~Tracker record form: renderizaÃƒÂ§ÃƒÂ£o por tipo de campo~~ Ã¢â‚¬â€ `create_record_form.dart` jÃƒÂ¡ renderiza todos os tipos (range/slider, duration, mood/emojis, selection/chips, checklist, text)
26. Ã¢Å“â€¦ ~~Dashboard pull-to-refresh~~ Ã¢â‚¬â€ `RefreshIndicator` envolvendo `CustomScrollView` na linha 198 do `home_screen.dart`
27. Ã¢Å“â€¦ ~~`_buildHabitHeatmapBlock()` usando histÃƒÂ³rico real~~ Ã¢â‚¬â€ itera `habit.completionHistory` por data para os ÃƒÂºltimos 28 dias
28. Ã¢Å“â€¦ ~~`_buildAnalysisBlock()` com cÃƒÂ¡lculo correto de consistency~~ Ã¢â‚¬â€ usa `completionHistory` dos ÃƒÂºltimos 30 dias reais por hÃƒÂ¡bito
29. Ã¢Å“â€¦ ~~`_buildPinnedObjectBlock()` implementaÃƒÂ§ÃƒÂ£o completa~~ Ã¢â‚¬â€ picker via `_showObjectPickerForBlock`, preview inline do objeto, tap abre `UniversalDetailView`
30. Ã¢Å“â€¦ ~~Forms: dismiss confirmation ("Descartar alteraÃƒÂ§ÃƒÂµes?")~~ Ã¢â‚¬â€ `PopScope` adicionado em todos os forms crÃƒÂ­ticos: goal, note, project, reminder, resource, person, social post, tracker (alÃƒÂ©m de habit e task que jÃƒÂ¡ tinham)
31. Ã¢Å“â€¦ ~~TrackingRecord detail: renderizar fieldValues legÃƒÂ­vel~~ Ã¢â‚¬â€ helper `formatFieldValue` por tipo de campo implementado em `_showRecordDetails`

### AnÃƒÂ¡lise Ã¢â‚¬â€ gaps de dados Ã¢Å“â€¦
- ~~Dias sem registro aparecem como zero na linha~~ Ã¢Å“â€¦ Ã¢â‚¬â€ `_getValueForDate` retorna `double?`; `CitrineChart._buildLineChart()` filtra spots nulos com `.where((e) => e.value.value != null)` antes de construir a linha

### Ã°Å¸Å¸Â¢ Melhoria Ã¢â‚¬â€ polimento
✅ ~~32. Empty states com ilustraÃƒÂ§ÃƒÂµes especÃƒÂ­ficas por tela
✅ ~~33. Skeleton loading generalizado (alÃƒÂ©m do dashboard)
âœ… ~~34. Swipe to delete/archive consistente em todas as listas~~
35. AnimaÃƒÂ§ÃƒÂµes de completar task/habit (scale + fade, confetti)
36. Export CSV de trackers
✅ ~~37. ConfiguraÃƒÂ§ÃƒÂ£o de accent color do app
âœ… ~~38. Recentes persistentes na busca~~
âœ… ~~39. Sync indicator: diferenciar offline vs error visualmente~~
40. Compartilhar objeto do detalhe