# Citrine — Roadmap V2

> Features adiadas do V1, ordenadas por dependência e impacto.
> Pré-requisito: app V1 estável, vault lendo/escrevendo corretamente.

---

## Estado do código relevante para o V2

Alguns modelos já foram parcialmente construídos para o V2 durante o V1:

| Arquivo | O que já existe |
|---|---|
| `day_theme_model.dart` | `DayTheme` e `TimeBlock` com `TimeRange` completos |
| `scheduler.dart` | `RepeatType` já inclui `daysOfTheme`, `daysWithBlock`, `linkedItemAppears`, `nDaysAfterLinkedItem` no enum |
| `google_calendar_service.dart` | `pushSessionToCalendar`, `fetchEvents`, `deleteSessionFromCalendar` implementados — só falta OAuth |
| `voice_recording_sheet.dart` | UI completa (117 linhas) — sem gravação real |

---

## Fase V2.1 — Day Themes e Time Blocks

**Duração estimada: 1,5 semanas**
**Depende: V1 Planner estável + V1 Scheduler funcionando**

Day Themes definem o "tipo" de um dia (Dia de trabalho, Fim de semana, Descanso). Cada tema tem uma lista de Time Blocks (Morning, Deep Work, Admin, Evening). O Planner do V1 já exibe sessions e hábitos numa timeline de horas — V2.1 reorganiza isso em blocos nomeados.

### V2.1.1 — Gestão de Time Blocks

- ✅ **Time Block management screen** (Settings → Time Blocks):
  - ✅ Lista de blocos com nome, cor, horários e drag-to-reorder
  - ✅ Cada bloco: nome livre (ex: "Manhã", "Deep Work", "Admin"), cor, lista de `TimeRange` (start/end opcionais — bloco pode ser só um rótulo sem horário fixo)
  - ✅ "+" → form: nome, cor, time ranges (pode ter múltiplos ranges, ex: "Admin" pode ser 08:00–09:00 e 17:00–18:00)
  - ✅ Swipe left → delete (com aviso se bloco tiver sessions/hábitos associados)
  - ✅ Salvar como `time_blocks/SLUG.md` no vault

- ✅ **Time Block picker**: componente reutilizável usado no Calendar Session form e no Habit form para atribuir um item a um bloco; lista scrollável de chips coloridos com o nome do bloco

### V2.1.2 — Gestão de Day Themes

- ✅ **Day Theme management screen** (Settings → Day Themes):
  - ✅ Lista de temas: "Dia de trabalho", "Fim de semana", "Descanso", etc.
  - ✅ Cada tema: nome, cor, lista de Time Blocks (reordernáveis via drag), dias da semana onde este tema é o padrão (`daysOfWeek`)
  - ✅ "+" → form com nome, cor, seletor de dias (checkboxes Mon–Sun), seletor de blocos (multi-select da lista de Time Blocks criados)
  - ✅ Salvar como `day_themes/SLUG.md` no vault

- ✅ **Day Theme automático**: ao abrir o Planner num dia, detectar qual tema se aplica via `daysOfWeek`; mostrar nome do tema no header do day view

### V2.1.3 — Planner: Day View reorganizado em blocos

- ✅ **seções de blocos**: além da régua contínua de horas, crie um day view  alternativo que mostra cards colapsáveis por Time Block (ex: card "Manhã" contendo todas as sessions/hábitos/tasks do bloco)
  - Se o bloco tem `TimeRange`: mostrar horário no header do card ("Manhã — 07:00 a 09:00")
  - Se não tem TimeRange: bloco como container sem horário fixo
  - Blocos expandem/colapsam ao tap no header
  - Bloco "All day" sempre no topo (items sem bloco ou sem hora)
  - os blocos sao criaveis e editaveis

- ✅ **Reordenar items dentro do bloco**: drag handle por item dentro do card do bloco (`ReorderableListView`)

- ✅ **Criar session diretamente num bloco**: tap no "+" dentro do card de um bloco → tarefa ou pomodoro form com `time_block` pré-preenchido

### V2.1.4 — Scheduler: tipos `daysOfTheme` e `daysWithBlock`

Os tipos já existem no enum `RepeatType` — falta a lógica no `scheduler_service.dart` e o UI no `scheduler_picker.dart`.

- ✅ **`daysOfTheme`**: `shouldFire(date)` → verificar qual `DayTheme` se aplica ao `date` (via `daysOfWeek` do tema) e comparar com `rule.themeId`
  - Sub-form no picker: seletor de Day Theme (dropdown ou radio list dos temas existentes)
  - Exemplo de uso: "Meditar toda Workday"

- ✅ **`daysWithBlock`**: `shouldFire(date)` → verificar se há algum item (session/hábito) no `rule.blockId` no `date`
  - Sub-form no picker: seletor de Time Block
  - Exemplo de uso: "Revisar tarefas todo dia que tiver bloco Deep Work"

### V2.1.5 — Scheduler Page: mostrar próximos dias do tema

- ✅ Na Scheduler Page global (V1 Fase 7), adicionar filtro "Por tema": mostrar quais objetos serão gerados nos próximos 7/30 dias, agrupados por Day Theme

### V2.1.6 — Daily Note: seção de Day Theme

- ✅ Ao abrir/criar o daily note, escrever no frontmatter: `day_theme: workday` (o slug do tema detectado para aquele dia)
- ✅ Dataview query example gerado no `index.md` do vault: `TABLE day_theme FROM "daily" SORT file.name DESC`

---

## Fase V2.2 — Combined Analysis multi-fonte

**Duração estimada: 1,5 semanas**
**Depende: V1 Trackers com charts, V1 Journal com mood funcional**

O V1 entrega charts por tracker individual. V2.2 permite correlacionar múltiplos trackers, hábitos e mood num único calendário e conjunto de charts.

### V2.2.1 — Analysis object: CRUD completo

- ✅ **Analysis creation form**: título, description, lista de data sources com "+" para adicionar fonte
  - Cada source: `source_type` (tracker_field / habit / journal_mood), seletor da fonte específica (qual tracker + qual campo, qual habit, ou mood global), cor, label de exibição
  - Drag-to-reorder fontes
  - Salvar como `analyses/SLUG.md` no vault

- ✅ **`analysesProvider`**: carregar todos os `analyses/*.md` do vault; retornar `List<CombinedAnalysis>`

### V2.2.2 — Monthly calendar multi-dot

- ✅ Grid mensal no topo da Analysis screen (igual ao Habit detail, mas com múltiplos dots por dia)
- Cada day cell: até 5 dots coloridos empilhados ou em row, um por source que tem dado naquele dia
- Tap num dia: bottom sheet com os valores de cada source para aquela data (ex: "Cólica: 3 | Humor: 4 | Remédio: 1")
- Navegação por mês com setas

### V2.2.3 — Charts multi-série

- ✅ **Line chart multi-série**: cada source como uma linha com cor própria; eixo Y compartilhado ou duplo (configurável se unidades são incompatíveis)
- ✅ **Bar chart empilhado/agrupado**: opção de agrupar barras por source ou empilhar
- ✅ **Scatter plot**: correlação entre dois sources (x = source A, y = source B, um ponto por data)
- ✅ **Legenda interativa**: tap num item da legenda → ocultar/exibir aquela série
- ✅ **Date range picker por análise**: This week / This month / Last 30 days / Custom (calendar range picker)

### V2.2.4 — Mood como data source

- ✅ `journal_mood` source type: ler `mood_overall` do frontmatter de cada daily note no range; converter para `{date: numericValue}` usando `MoodDefinition.numeric_value`
- ✅ Aggregation method configurável por análise: average (múltiplas entradas/dia), max, min, last entry do dia

### V2.2.5 — Obsidian Charts plugin output

- ✅ Botão "Exportar para Obsidian" na análise: gera bloco de código `chart` no formato do Obsidian Charts plugin e copia para clipboard ou escreve num arquivo
  ```
  ```chart
  type: line
  labels: [2026-05-01, 2026-05-02, ...]
  series:
    - title: Cólica
      data: [2, 4, 3, 1, 3]
    - title: Humor
      data: [4, 3, 3, 4, 4]
  width: 80%
  beginAtZero: false
  ```
  ```
- ✅ Botão "Exportar para Tracker plugin": gera bloco `dataviewjs` ou config do Obsidian Tracker plugin para calendar heatmap

---

## Fase V2.3 — Google Calendar: integração completa

**Duração estimada: 1 semana**
**Depende: V1 Planner estável, OAuth do V1 Sync já configurado**

O `google_calendar_service.dart` já tem `fetchEvents`, `pushSessionToCalendar` e `deleteSessionFromCalendar` implementados. Só falta ligar o OAuth, exibir no Planner e exportar sessions.

### V2.3.1 — OAuth completo no contexto do app

- ✅ **Settings → Google Calendar**: tela com estado de conexão (conectado/desconectado), botão "Conectar com Google", email da conta conectada, botão "Desconectar"
- ✅ Reutilizar `google_auth_service.dart` do V1 (OAuth já configurado para Drive); adicionar escopo `calendar.readonly` para leitura e `calendar.events` para escrita
- ✅ `googleCalendarProvider`: `AsyncNotifier` que mantém lista de eventos do próximo mês; invalida quando a data muda ou ao pull-to-refresh no Planner

### V2.3.2 — Display de eventos no Planner

- ✅ `GoogleCalendarEventCard`: bloco read-only no Day View; visual diferenciado com ícone Google + cor do calendário de origem
- ✅ Integrar `googleCalendarEventsProvider(date)` na `TimeLineDayView` — o provider já existe como esqueleto
- ✅ Múltiplos calendários: mostrar eventos de todos os calendários do usuário com cores distintas; toggle por calendário em Settings

### V2.3.3 — Detail view de evento Google

- ✅ Bottom sheet ao tap num evento: título, horário, descrição, local, attendees (nome + avatar), "Abrir no Google Calendar" (deep link `googlecalendar://`)
- ✅ "Associar ao projeto/goal": WikiLink picker → adicionar evento como menção no objeto selecionado; o evento passa a aparecer no Mentions do objeto

### V2.3.4 — Exportar CalendarSession para Google Calendar

- ✅ `pushSessionToCalendar` já está implementado — ativar no ⋯ menu do Calendar Session: "Exportar para Google Calendar"
- ✅ Ao exportar: salvar `exportedCalendarId` no frontmatter da session
- ✅ Ao editar a session: se `exportedCalendarId != null`, perguntar "Atualizar no Google Calendar também?"
- ✅ Ao deletar a session: se `exportedCalendarId != null`, chamar `deleteSessionFromCalendar`
- ✅ Ícone de "exportado" (📅) no card da session no Planner quando `exportedCalendarId != null`

### V2.3.5 — Google Calendar block no Dashboard (V1 Fase 8 dependência)

- ✅ Block tipo "Google Calendar": eventos de hoje/semana como chips coloridos com horário
- ✅ Configuração: quantos dias mostrar, quais calendários incluir, formato (list vs timeline)

---

## Fase V2.4 — Scheduler: regras avançadas

**Duração estimada: 4–5 dias**
**Depende: V1 Scheduler funcional, V2.1 Day Themes (para daysOfTheme/daysWithBlock)**

Os tipos `linkedItemAppears` e `nDaysAfterLinkedItem` existem no enum mas não têm lógica no `scheduler_service.dart` nem sub-form no picker.

### V2.4.1 — `linkedItemAppears` (tipo 9)

- ✅ **Lógica no `scheduler_service.dart`**: `shouldFire(date, rule)` → buscar se o `linkedItemId` do rule tem alguma session, task ou reminder agendado no `date`; requer consultar o vault (tasks com `deadline == date` ou sessions com `date == date` linkadas ao item)
- ✅ **Sub-form no picker**: label "Toda vez que", WikiLink picker para escolher o item, preview "Repetir nos dias em que [[item]] estiver no calendário"
- ✅ **YAML**: `type: linked_item_appears` + `linked_item: "[[slug]]"` no frontmatter do scheduler

### V2.4.2 — `nDaysAfterLinkedItem` (tipo 10)

- ✅ **Lógica**: encontrar a data do `linkedItem` mais próxima (próxima ocorrência) → adicionar `interval` dias/horas
- ✅ **Sub-form**: campos "N" (integer input), unidade (Days/Hours, como pill tappável), WikiLink picker para o item, preview "X dias/horas depois de [[item]]"
- ✅ **Cálculo de nextInstanceDate**: ao completar/pular uma instância, recalcular baseado na próxima ocorrência do linked item

### V2.4.3 — UI da Scheduler Page para regras avançadas

- ✅ Na Scheduler Page global: filtro "Vinculados" → mostra apenas objetos com regras `linkedItemAppears` ou `nDaysAfterLinkedItem`
- ✅ Preview "Próximos 7 dias" por objeto: quais datas as regras avançadas vão gerar, calculado em tempo real

---


**Duração estimada: 1 semana**
**Depende: V1 Universal Links + Backlinks funcionando**







- ✅ Cada child: ícone do tipo (Task/Habit/Note/Goal...) + título + preview de 1 linha



### V2.5.5 — Dataview queries geradas automaticamente

  ```dataview
  TABLE type AS "Tipo", updated AS "Atualizado"
  FROM "app"
  SORT file.mtime DESC
  ```

---

## Fase V2.6 — Command Center e Inbox

**Duração estimada: 1 semana**
**Depende: V1 estável**

### V2.6.1 — Command Center (scroll-up launcher)

- ✅ **Trigger**: ao scrollar para cima na main UI (scroll além do topo), animar o Command Center para baixo a partir do topo da tela
- ✅ **Layout**: overlay full-width com blur de fundo; campo de busca/texto no topo (auto-focado com teclado aberto); abaixo: 4 seções side-scrollable:
  - "Recentes": últimos 8 objetos abertos (qualquer tipo), como chips com ícone de tipo + título
  - "Notas": últimas 5 notas modificadas
  - "Próximas sessões": as 3 próximas Calendar Sessions do dia
  - "Organizers": chips dos organizers mais usados (por frequência de acesso)
- ✅ **Busca inline**: digitar no campo filtra em tempo real nos recentes e mostra resultados de todos os tipos
- ✅ **Ações rápidas**: row de botões abaixo do campo — "Nova entrada", "Nova task", "Novo registro", "Nova nota"
- ✅ **Fechar**: swipe up de volta, tap fora, ou Escape

### V2.6.2 — Inbox (quick capture)

- ✅ **Inbox como seção no vault**: `inbox/YYYY-MM-DD-HH-MM.md` por cada item capturado
- ✅ **Quick capture**: botão de mic ou texto flutuante acessível de qualquer tela (FAB secundário ou long-press no "+" global)
- ✅ **Entrada mínima**: só título (texto livre) + timestamp + opção de gravar áudio; sem categorização — a ideia é capturar rápido e categorizar depois
- ✅ **Inbox screen**: lista de itens não categorizados, mais antigo primeiro; cada item tem: título + data + ações rápidas (swipe)
- ✅ **Triagem**: tap num item → bottom sheet "O que é isso?" com 4 opções: "Virou uma task" / "Era uma ideia (nota)" / "É uma entrada do journal" / "Deletar"; cada opção abre o form correspondente pré-preenchido com o título do inbox item
- ✅ **Badge no ícone do app / More tab**: contagem de itens não triados no Inbox
- ✅ **Auto-archive**: itens no Inbox com mais de 30 dias sem triagem → mover para `_deleted/` com aviso

---

## Fase V2.7 — Templates

**Duração estimada: 1 semana**
**Depende: V1 rich text funcional**

### V2.7.1 — Template object

- ✅ **Template model**: `{id, title, type: entry|task|note|habit|tracker, body: richText, frontmatterDefaults: Map<String, dynamic>}`
- ✅ Salvar como `templates/SLUG.md` no vault; frontmatter com defaults (ex: template de "Reunião" → `organizers: [[trabalho]]`, `priority: medium`)
- ✅ `templatesProvider`: carregar todos os templates do vault por tipo

### V2.7.2 — Template editor

- ✅ **Template creation screen**: tipo (Entry/Task/Note), título do template, `RichTextEditor` para o body com suporte a variáveis: `{{date}}`, `{{time}}`, `{{weekday}}`, `{{title}}` — substituídas ao aplicar
- ✅ Frontmatter defaults: lista de propriedades com valor padrão (organizers, priority, etc.)
- ✅ "Salvar como template a partir de um item existente": botão no ⋯ menu de qualquer Entry, Task ou Note → cria template com o body atual

### V2.7.3 — Aplicar template

- ✅ No creation form de Entry, Task e Note: botão "Usar template" → bottom sheet com lista de templates compatíveis com o tipo
- ✅ Tap num template: preenche o body com o conteúdo do template (variáveis substituídas) e aplica os frontmatter defaults como valores iniciais do form
- ✅ **Template de daily review**: template especial tipo Entry com prompt de perguntas de revisão diária; configurável em Settings

### V2.7.4 — Template library (built-in)

- ✅ Conjunto de templates pré-definidos instalados na primeira abertura do app (opcionais — usuário pode deletar):
  - "Reunião 1:1" (Entry): Pauta, Decisões, Próximos passos
  - "Weekly Review" (Entry): Vitórias da semana, Lições aprendidas, Foco da próxima semana
  - "Leitura" (Entry): Citação, O que aprendi, Como vou aplicar
  - "Sprint Planning" (Note): Objetivo, Tasks, Definition of Done
  - "Projeto novo" (Note): Visão, Métricas de sucesso, Milestones, Riscos

---

## Fase V2.8 — Subtask sessions e gestão avançada de tasks

**Duração estimada: 4–5 dias**
**Depende: V1 Tasks com subtasks funcionando**

### V2.8.1 — Subtask sessions (grupos temáticos)

- ✅ **Session model dentro de Task**: `{id, name, subtaskIds: List<String>}` — grupo nomeado de subtasks
- ✅ No painel de subtasks do Task detail view: botão "Criar sessão" → input de nome → as subtasks selecionadas são agrupadas sob aquela sessão
- ✅ Cada sessão aparece como header colapsável (`[+] Sessão: "Pesquisa"`) com suas subtasks indentadas abaixo
- ✅ Drag de subtask entre sessões: mover subtask de uma sessão para outra ou para fora de qualquer sessão
- ✅ Salvar como `sessions` array no frontmatter da task: `sessions: [{id: "s1", name: "Pesquisa", subtasks: ["st1", "st2"]}]`

### V2.8.2 — Task dependencies

- ✅ `dependsOn: List<WikiLink>` no model da task — tarefas que precisam ser concluídas antes desta
- ✅ Visual no Task detail: seção "Depende de" com chips das tasks bloqueantes; se alguma não está `finalized`, mostrar badge "Bloqueada"
- ✅ No Planner: tasks bloqueadas por dependências não concluídas aparecem com ícone de cadeado 🔒

### V2.8.3 — Task time estimates vs actuals

- ✅ `estimated_minutes` no model (já existe `durationMinutes`) vs `actual_minutes` (derivado de Pomodoro sessions)
- ✅ No Task detail: "Estimado: 45min | Real: 1h 12min"; progresso de tempo como barra
- ✅ No Planner: ao agendar uma task, sugerir automaticamente o slot de duração baseado em `estimated_minutes`

---

## Fase V2.9 — Captura rápida e Natural Language Input

**Status:** implementado sem recursos de voz, conforme decisão de produto.

### V2.9.1 — Voice recording funcional [REMOVIDO]

- ✅ Removido do app: dependência `record`, permissões de microfone e qualquer fluxo de gravação de voz.
- ✅ Android não solicita mais `RECORD_AUDIO`.

### V2.9.2 — Speech-to-text (transcrição) [REMOVIDO]

- ✅ Removido junto com voice recording. O app mantém captura rápida por texto e NLP local.

### V2.9.3 — Natural Language Input (NLP para tasks)

- ✅ No campo de título de criação de task: interpretar linguagem natural
  - "Comprar leite amanhã às 10h" → `title: "Comprar leite"`, `deadline: amanhã`, `exact_time: 10:00`
  - "Ligar pro João todo domingo" → `title: "Ligar pro João"` + scheduler `daysOfWeek: [sunday]`
  - "Projeto X até dia 30 alta prioridade" → `deadline: 30 do mês corrente`, `priority: high`
- ✅ Parse local (sem API) usando `intl` para datas e regex para padrões comuns; mostrar preview dos campos detectados abaixo do input antes de confirmar
- ✅ Configurável: pode ser desligado em Settings (alguns usuários preferem preencher os campos manualmente)

---

## Fase V2.10 — Widgets nativos (iOS/Android)

**Duração estimada: 2 semanas**
**Depende: V1 estável com `home_widget` package configurado**

### V2.10.1 — Corrigir ClassNotFoundException no Android

- ✅ Verificado e corrigido no `AndroidManifest.xml`: todos os receivers Android foram declarados com provider XML correto
  ```xml
  <receiver android:name=".CitrineWidgetReceiver" android:exported="true">
    <intent-filter>
      <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/citrine_widget_info"/>
  </receiver>
  ```
- ✅ Criado/atualizado `CitrineWidgetReceivers.kt` usando `HomeWidgetProvider`, `HomeWidgetLaunchIntent` e `HomeWidgetBackgroundIntent`.

### V2.10.2 — Widget: Quick-add (2×1)

- ✅ **Android layout XML**: `citrine_widget_quick_add.xml` — 2 botões configuráveis para criação rápida

- ✅ Tap no botão → deep link `citrine://create/entry`, `citrine://create/task`, `citrine://create/habit` ou `citrine://create/note` → app abre no form correto
- ✅ Configuração: labels e destinos sincronizados por `WidgetService.updateQuickAddLabels()`

### V2.10.3 — Widget: Calendar (4×2 semana / 4×4 mês)

- ✅ **Semana (4×2)**: serialização de 7 dias, contagem por dia e abertura do Planner
- ✅ **Mês (4×4)**: grid mensal com dados serializados e fallback de foco mensal
- ✅ "+" no corner superior direito → `citrine://create/task`
- ✅ Tap no calendário → `citrine://planner/day/YYYY-MM-DD`
- ✅ `widget_service.dart`: serializa planner/tasks/hábitos via `HomeWidget.saveWidgetData()` e atualiza o widget ao sincronizar
- ✅ Configuração: tipo `week/month`, exibição de tasks/habits e fallback para sessões legadas

### V2.10.4 — Widget: Habits summary (4×2)

- ✅ Lista compacta dos hábitos de hoje com checkboxes
- ✅ Tap no checkbox → `home_widget` callback → app enfileira `toggle_habit`, executa `habitsNotifier.toggleHabit(habit, today)` e atualiza o widget
- ✅ Tap no título → `citrine://habits`
- ✅ Configuração: quais hábitos mostrar por organizer via settings do widget universal

### V2.10.5 — Widget: Obsidian Note (2×2 ou 4×2)

- ✅ Renderiza o conteúdo plain text de uma nota específica
- ✅ Tap no widget abre a nota correspondente via `citrine://detail/<slug>`
- ✅ Atualiza o widget quando a nota pinned muda no vault ou durante sync do widget
- ✅ Configuração: nota selecionada pelo fluxo de objeto fixado/widget universal

### V2.10.6 — Lock screen widgets (iOS 16+ / Android 13+)

- ✅ **Habit completion count**: widget compacto mostrando N/total hábitos concluídos hoje
- ✅ **Next session**: próxima task/sessão agendada do dia (título + horário)
- ✅ **Pomodoro timer**: quando Pomodoro está ativo, mostra MM:SS restante e é atualizado pelo provider

### V2.10.7 — Widgets nativos espelhados na Dashboard

- ✅ Widget de Calendário na dashboard com modos Dia/Sem./Mês, agenda diária, grid mensal e bottom sheet de detalhes do dia.
- ✅ Widget de Área na dashboard com tabs de Tarefas/Hábitos, progresso, checkboxes funcionais e botões de adicionar.
- ✅ Widget de Pomodoros da Semana na dashboard com total semanal, gráfico por dia, breakdown por objeto e botão **Iniciar**.
- ✅ Ao iniciar Pomodoro pelo widget, o app abre um popup de busca do vault todo, filtrável por tipo, para escolher o objeto relativo antes de começar.
- ✅ Novos widgets Android nativos: Área e Pomodoros da Semana.

---

## Fase V2.11 — Dataview e Obsidian plugin output

**Duração estimada: 1 semana**
**Depende: V1 vault escrevendo no formato correto**

Esta fase gera conteúdo que funciona no Obsidian nativo, tornando o vault utilizável diretamente no Obsidian além do app.

### V2.11.1 — Dataview queries automáticas

- ✅ **`dataview_generator.dart`**: serviço que gera queries Dataview padrão para tipos comuns
- ✅ Queries geradas e escritas no `index.md` de cada pasta do vault ao sincronizar:

  **Hábitos — streak e completações:**
  ```dataviewjs
  const folder = "app";
  const habitSlug = "meditar";
  const notes = dv.pages(`"${folder}"`).where(p => p.type === 'daily_note').sort(p => p.file.name, "desc");
  let streak = 0;
  for (const note of notes) {
    if (note[habitSlug] === true || (typeof note[habitSlug] === 'number' && note[habitSlug] > 0)) {
      streak++;
    } else break;
  }
  dv.paragraph(`Streak atual: **${streak} dias**`);
  ```

  **Tasks por stage:**
  ```dataview
  TABLE stage AS "Stage", priority AS "Prioridade", file.link AS "Tarefa"
  FROM "app"
  WHERE type = "task" AND stage != "finalized"
  SORT priority DESC, file.name ASC
  ```

  **Mood trend:**
  ```dataview
  TABLE mood_overall AS "Humor", date AS "Data"
  FROM "app"
  WHERE type = "daily_note" AND mood_overall
  SORT file.name DESC
  LIMIT 30
  ```

- ✅ Botão "Regenerar queries Dataview" em Settings → Obsidian Integration

### V2.11.2 — Obsidian Charts plugin charts embutidos

- ✅ Nos arquivos de definição de tracker/habit: gerar bloco `chart` no format do plugin, atualizado ao sincronizar:
  ```
  ```chart
  type: line
  labels: [...]
  series:
    - title: Energia
      data: [...]
  width: 80%
  beginAtZero: false
  ```
  ```
- ✅ A geração é feita no `obsidian_service.dart` ao escrever o arquivo de definição do tracker; usa os últimos 30 dias de dados carregados

### V2.11.3 — Obsidian Tracker plugin (heatmap)

- ✅ Gerar blocos de config do Obsidian Tracker plugin nos arquivos de análise do vault:
  ```yaml
  searchType: frontmatter
  searchTarget: sono.horas
  folder: app
  startDate: {{lastMonth}}
  endDate: {{today}}
  month:
    startWeekOn: Mon
    color: blue
    colorByValue: true
  ```
- ✅ Variáveis `{{today}}` e `{{lastMonth}}` substituídas pela data real ao gerar

---

## Fase V2.12 — Import de outros apps


### V2.12.1 — Import de Obsidian vault existente

- ✅ "Importar vault existente": apontar para pasta de vault Obsidian do usuário
- ✅ Detectar arquivos com frontmatter de formato compatível (os que têm `type`, `categories`, etc.) e indexá-los
- ✅ Para arquivos sem frontmatter estruturado: importar como Text Notes com o conteúdo original preservado

---

## Fase V2.13 — iPad e telas grandes

**Duração estimada: 1 semana**
**Depende: V1 estável em iPhone**

### V2.13.1 — Split View no iPad

- ✅ Implementado com `LayoutBuilder` custom no `AppShell`
- ✅ Em telas > 600dp: sidebar esquerda/side rail substitui bottom nav e o conteúdo principal fica à direita
- ✅ Master-detail automático em rotas de detalhe: lista fica preservada na coluna esquerda e detalhe abre na direita

### V2.13.2 — Layout de 2 colunas

- ✅ **Planner iPad**: suportado pelo split view global e rotas de detalhe preservando a lista
- ✅ **Dashboard iPad**: grid responsivo para blocos em telas > 600dp
- ✅ **Trackers iPad**: cards e records usam layout responsivo; detalhes abrem no painel direito via split view global

### V2.13.3 — Keyboard shortcuts (iPad com teclado)

- ✅ `⌘N` / `Ctrl+N` → abrir criação rápida
- ✅ `⌘F` / `Ctrl+F` → abrir search
- ✅ `⌘K` / `Ctrl+K` → abrir Command Center
- ✅ `⌘1–5` / `Ctrl+1–5` → navegar entre as 5 tabs

---

## Fase V2.14 — Weekly Review e estatísticas avançadas

**Duração estimada: 1 semana**
**Depende: V1 dados suficientes no vault**

#### V2.14.1 — Automação de Weekly Review [✅]
- Adicionada automação em NotificationService para gerar um rascunho de Daily Note com os dados preenchidos da semana nos Domingos e Sextas (configurável via payload action).
  - Hábitos: taxa de sucesso da semana por hábito (X/7 dias)
  - Tasks: concluídas vs criadas vs abertas
  - Tempo de Pomodoro: total da semana, top 3 projetos por tempo
  - Goal progress: delta de KPIs (quanto avançou vs semana anterior)
  - Mood trend: gráfico de humor dos últimos 7 dias

- ✅ Notificação semanal: "Sua review da semana está pronta" → abre o review pré-preenchido no Journal

### V2.14.2 — Statistics screen

- ✅ **Statistics tab** (ou acessível pelo More/Settings): dashboard de analytics do vault
  - Streak atual e recorde por hábito
  - Task completion rate (rolling 30 dias)
  - Pomodoro hours por semana (chart de barras)
  - Mood distribution (donut chart)
  - Palavras escritas no journal (total + por semana)
  - Most active days (heatmap calendar do ano)

- ✅ **KPI histórico por goal**: ver o valor de um KPI ao longo do tempo como line chart (progresso do goal semana a semana)

---

## Resumo — V2 por prioridade

| # | Fase | Impacto | Dependências | Estimativa |
|---|---|---|---|---|
| V2.1 | ✅ Day Themes & Time Blocks | Alto — reorganiza o Planner | V1 Planner + Scheduler | 1,5 sem |
| V2.2 | ✅ Combined Analysis multi-fonte | Alto — feature diferenciadora | V1 Trackers + Mood | 1,5 sem |
| V2.3 | ✅ Google Calendar completo | Alto — integração esperada | V1 OAuth (Drive) | 1 sem |
| V2.4 | ✅ Scheduler: regras avançadas | Médio — edge cases de scheduler | V2.1 (daysOfTheme) | 4–5 dias |
| V2.6 | ✅ Command Center + Inbox | Médio — velocidade de captura | V1 estável | 1 sem |
| V2.7 | ✅ Templates | Médio — reduz fricção de criação | V1 rich text | 1 sem |
| V2.8 | ✅ Subtask sessions + dependencies | Baixo–Médio — power users | V1 Tasks | 4–5 dias |
| V2.9 | ✅ Captura texto + NLP input (voz removida) | Médio — experiência mobile | V1 rich text | 1 sem |
| V2.10 | ✅ Native Widgets | Alto — visibilidade fora do app | V1 estável | 2 sem |
| V2.11 | ✅ Dataview + Obsidian plugins | Médio — usuários Obsidian | V1 vault formato correto | 1 sem |
| V2.12 | ✅ Import de outros apps | Médio — aquisição de usuários | V1 vault | 1,5 sem |
| V2.13 | ✅ iPad + telas grandes | Baixo–Médio — público iPad | V1 estável | 1 sem |
| V2.14 | ✅ Weekly Review + Statistics | Alto — retenção e reflexão | V1 dados suficientes | 1 sem |

**Total estimado V2: ~16–18 semanas de dev solo**

---

## Ordem sugerida de implementação

As fases **V2.1 → V2.3 → V2.10** têm o maior impacto por tempo investido e devem vir primeiro após o V1:

1. **V2.1** (Day Themes) — reorganiza o Planner, que é o coração do app
2. **V2.3** (Google Calendar) — a maioria dos usuários já usa GCal, a integração é esperada
3. **V2.2** (Combined Analysis) — feature mais visível e diferenciadora para usuários de trackers
4. **V2.10** (Widgets) — aumenta visibilidade fora do app e retenção
5. **V2.7** (Templates) — reduz fricção diária sem grande esforço
6. **V2.14** (Weekly Review) — gera o hábito de abrir o app semanalmente
7. Demais fases conforme demanda dos usuários pós-lançamento
