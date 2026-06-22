# App Guidelines V4 — Especificação Completa e Autoritativa
feito em 2026-06-18

> **Como usar este documento**
> Esta é a única fonte de verdade. Quando qualquer versão anterior (V1, V2, screenshot, mensagem de chat) conflitar com o que está aqui, este documento vence.
>
> **Regras de parsing (leia antes de tudo)**
> - **Regra 1** — Este documento anula todas as versões anteriores (V1, V2, V3, screenshots, mensagens de chat).
> - **Regra 2** — MOC não existe. Não leia, não escreva, não exiba. Organizadores substituem MOC completamente.
> - **Regra 3** — `habit_mode` ausente → tratar como `habit`. Não errar.
> - **Regra 4** — `entry_type` ausente → tratar como `standard`. Não errar.
> - **Regra 5** — `goal_mode` ausente → tratar como `standard`. Não errar.
> - **Regra 6** — `linked_system` ausente numa Task → criada manualmente. Não errar.
> - **Regra 7** — `triple_check` ausente numa Task → diagnóstico nunca executado. Não errar, não exibir badge.
> - **Regra 8** — Localização dos arquivos é definida pela configuração do usuário em Object Identification. O app não presume pasta por tipo. Sempre lê `type` do frontmatter para determinar o que é o objeto.
> - **Regra 9** — Daily notes ficam em `daily/YYYY-MM-DD.md`. PMN ficam em `daily/YYYY-MM-WNN.md` (ex: `2026-05-W21.md`), onde MM é o mês de `date_range_start`. O mês canônico de um PMN é sempre lido de `date_range_start` no frontmatter, nunca parseado do nome do arquivo. O nome existe para legibilidade e ordenação no Obsidian.
> - **Regra 10** — Arquivos System (type: system) devem ser tratados graciosamente quando ausentes. Mostrar empty state, não errar.
> - **Regra 11** — IDs são internos. Nunca exibir ao usuário. Usar sempre title/name nas interfaces.
> - **Regra 12** — Object Identification é soberana. Se o usuário definiu que objetos do tipo X ficam na pasta Y, isso tem prioridade sobre qualquer default do app.

---

## PARTE 1 — ARQUITETURA CONCEITUAL

### 1.1 Vault Structure (Flat por padrão, configurável por Object Identification)

Por padrão, todos os arquivos criados pelo app ficam numa pasta configurável pelo usuário (default: `app/`), independente do tipo. O tipo é sempre determinado pelo campo `type` no frontmatter YAML.

**Exceções fixas:**
- `daily/YYYY-MM-DD.md` — daily notes
- `daily/YYYY-MM-WNN.md` — entradas PMN (Plus/Minus/Next)
- `moods/SLUG.md` — definições de mood
- `_attachments/` — fotos e arquivos
- `_deleted/` — soft delete (purga automática em 30 dias)
- `_conflicts/` — backups de conflito de sync

**Object Identification (soberana sobre tudo):**
O usuário define, na página Object Identification (Settings → Object Identification), o que identifica cada tipo de objeto. Isso pode ser:
- Uma pasta específica (ex: todos arquivos em `projetos/` são type: project)
- Uma tag (ex: arquivos com `#habito` são type: habit)
- Uma propriedade no frontmatter (ex: arquivos com `categoria: tarefa` são type: task)

Quando a Object Identification define uma pasta para um tipo, o app salva novos objetos desse tipo nessa pasta e lê a pasta para listar objetos desse tipo. Esta configuração tem prioridade máxima sobre qualquer default do app.

**Detecção de conflito:** Se um objeto tem atributos que apontam para tipos conflitantes (ex: está na pasta `tasks/` mas tem propriedade `categoria: area`), o app exibe ⚠️ ao lado do título em todas as telas onde aparece, e o objeto aparece na página "Conflitos" (menu Mais).

### 1.2 Duas categorias de objetos

**OBJETOS DE CONTEÚDO** — Conteúdo gerado pelo usuário (ou, no caso do Event, espelhado de fora). 14 tipos:
1. Entry (journal entry) — inclui Field Note e PMN como sub-modos
2. Task — inclui Triple Check e link com System
3. Goal — inclui modo Project Plan
4. Habit — inclui modo Pact
5. Tracker (definição) + Tracking Record (instância)
6. Note (Text Note, Outline Note, Collection Note)
7. Calendar Session
8. Reminder
9. System
10. Social Post
11. Idea
12. Inbox Item
13. Event ← **exceção:** não vira arquivo no vault, não passa pela Object Identification. É um espelho somente-leitura de um evento do Google Calendar, populado em memória a cada sync (ver Objeto 13). Listado aqui porque aparece na mesma Timeline/Planner que os outros, mas não tem persistência local.
14. Shopping List (+ Shopping Item)

**OBJETOS ORGANIZADORES** — Contêineres estruturais. Todo objeto de conteúdo pertence a múltiplos organizadores simultaneamente. Organizadores têm sua própria Timeline com todo conteúdo associado.

Tipos de organizador:
1. Area (domínio de vida: "Trabalho", "Saúde", "Família")
2. Project (tem datas; vive sob Area ou Activity)
3. Activity (interesse ou tema recorrente; vive sob Area)
4. Task (uma Task também é Organizador)
5. Goal (um Goal também é Organizador)
6. Habit (um Habit também é Organizador)
7. Tracker (um Tracker também é Organizador)
8. Label (tag flexível, sem hierarquia)
9. People (pessoa nomeada)
10. Places (lugar nomeado com coordenadas opcionais)

Hierarquia: Area > Activity > Project > [Tasks, Habits, Trackers, Labels, People, Places]

---

## PARTE 2 — OBJETOS DE DADOS: ESPECIFICAÇÃO DETALHADA

---

### OBJETO 1: ENTRY (Journal Entry)

**Propósito:** Journal cronológico pessoal. Três sub-modos: `standard` (narrativa), `field_note` (auto-observação rápida), `pmn` (revisão semanal Plus/Minus/Next).

**Propriedades comuns:**
- `id` — string, único
- `type` — sempre `entry`
- `entry_type` — enum: `standard` | `field_note` | `pmn`. Default: `standard`
- `date` — ISO datetime. Default: agora. Editável retroativamente.
- `mood` — WikiLink para arquivo MoodDefinition: `mood:: [[calm]]`
- `feelings` — array de tags de sentimento (secundário ao mood)
- `photos` — array de imagens
- `location` — geolocalização ou lugar nomeado
- `organizers` — array de WikiLinks para Organizadores
- `archived` — boolean, default false
- `body` — rich text (para standard). Suporta: imagens inline, bold/italic/underline, headings, checklists, `[[WikiLink]]`

**Propriedades adicionais para `entry_type: field_note`:**
- `category` — enum: `insight` | `energy` | `mood_note` | `encounter`
- `text` — string (observação única, sem rich text)
- `energy_value` — integer 1–5 (apenas quando `category: energy`)

Field Notes são intencionalmente minimalistas. Sem body, sem título, sem formatação. Apenas category + text + timestamp.

**Propriedades adicionais para `entry_type: pmn`:**

PMN tem **arquivo próprio** em `daily/YYYY-MM-WNN.md` (ex: `daily/2026-05-W21.md`). O mês de referência é determinado por `date_range_start`, não pelo nome do arquivo.

- `week` — string no formato `YYYY-WNN`
- `date_range_start` — data do primeiro dia da semana de referência
- `date_range_end` — data do último dia da semana de referência
- `referenced_dates` — array de datas ISO que o usuário explicitamente selecionou como referência desta PMN. Quando o usuário abre uma data no calendário e essa data tem um PMN que a cita, o app exibe o card PMN linkado.
- `pact_refs` — array de WikiLinks para Habit-Pact sendo revisados
- `plus` — array de strings
- `minus` — array de strings
- `next` — array de strings

**Comportamento de linkagem de datas no PMN:**
Na criação de um PMN, o usuário seleciona o intervalo de datas (ou a semana) que este PMN cobre. Essas datas são salvas em `referenced_dates`. Quando o usuário navega para qualquer uma dessas datas no Journal, no Planner ou no Timeline, o card PMN aparece associado àquela data com um link "📋 Revisão W21". Tapping no card abre o arquivo PMN. O PMN não vive na daily note — tem arquivo próprio, mas cita as datas.

**Armazenamento Obsidian — Standard e Field Note:**
Ficam na daily note `daily/YYYY-MM-DD.md` sob `## Journal Entries`, cada um como subseção `### HH:MM`.

```markdown
## Journal Entries

### 08:30
entry_type: standard
mood:: [[calm]]
organizers:: [[area-saude]]

Acordei com energia hoje.

---

### 09:15
entry_type: field_note
category: insight

Percebi que minha resistência a emails de manhã é proteção do tempo criativo.

---

### 11:00
entry_type: field_note
category: energy
energy_value: 4

Alta energia depois da reunião.
```

**Armazenamento Obsidian — PMN:**
```markdown
---
id: "pmn-2026-W21"
type: entry
entry_type: pmn
week: 2026-W21
date_range_start: 2026-05-18
date_range_end: 2026-05-24
referenced_dates:
  - "2026-05-18"
  - "2026-05-19"
  - "2026-05-20"
  - "2026-05-21"
  - "2026-05-22"
pact_refs:
  - "[[escrever-100-palavras]]"
organizers:
  - "[[area-escrita]]"
archived: false
created_at: 2026-05-24T18:30:00
updated_at: 2026-05-24T18:30:00
---

## Plus
- Mantive o pact de escrita 6/7 dias
- Consegui bloquear as manhãs para deep work

## Minus
- Admin acumulou na quarta
- Reuniões quebraram o flow na quinta

## Next
- Mover admin para tarde
- Proteger manhã com bloco de foco no calendário
```

**Display no Timeline:**
- `standard` — Card completo: título em bold, preview do body 2–3 linhas, emoji de mood, chips de organizer, thumbnails de fotos.
- `field_note` — Card compacto: ícone de categoria + nome da categoria (pequeno, muted) + texto completo (não truncado). Sem linha de mood. Tapping abre edição mínima.
- `pmn` — Card distinto: ícone 3 colunas (+ / − / →) + label "Semana W21" + contagem de itens por coluna. Tapping expande inline.

**UI de criação:**
- Standard: `+` → aba Journal → editor full-screen. Title opcional (28pt), rich text, barra de metadados (mood, organizers, location), toolbar de formatação.
- Field Note: `+` → aba Journal → toggle "Observação rápida". Formulário de 3 elementos: 4 chips de categoria, campo de texto, botão Salvar. Timestamp automático.
- PMN: `+` → aba Journal → picker de template → "PMN da semana". Formulário: seletor de semana/intervalo de datas, 3 seções de bullets. Pact refs auto-sugeridos se houver Pacts ativos.

---

### OBJETO 2: TASK

**Propriedades:**
- `id` — string, único
- `type` — sempre `task`
- `title` — string, obrigatório
- `stage` — enum: `idea` | `backlog` | `todo` | `in_progress` | `pending` | `finalized`
- `priority` — enum: `none` | `low` | `medium` | `high`
- `start_date` — date, opcional
- `end_date` — date, opcional (deadline)
- `date_range` — boolean. Se true, task aparece em todos os dias entre start e end no Planner
- `until_done` — boolean. Se true, aparece diariamente no Planner até ser finalizada
- `duration` — integer, minutos. Default: 15
- `all_day` — boolean
- `scheduled_time` — HH:MM opcional
- `notes` — rich text
- `subtasks` — array de objetos Task (cada subtask é um arquivo Task completo com `parent_task` WikiLink)
- `organizers` — array de WikiLinks
- `tags` — array de strings
- `links` — array de WikiLinks (qualquer objeto)
- `scheduler` — configuração de Scheduler opcional
- `reminders` — array de configurações de Reminder
- `color` — opcional
- `participants` — array de WikiLinks para People
- `places` — array de WikiLinks para Places
- `timer_sessions` — derivado: tempo total de Pomodoro
- `comments` — array de Comment
- `reflection` — rich text opcional, solicitado ao finalizar
- `archived` — boolean, default false
- `parent_task` — WikiLink opcional (se for subtask)
- `linked_system` — WikiLink opcional para System (definido ao criar via execução de System)
- `triple_check` — bloco opcional (ver abaixo)
- `depends_on` — array de WikiLinks para Tasks bloqueadoras
- `estimated_minutes` — integer opcional
- `social_refs` — array de WikiLinks para SocialPost

**Bloco triple_check:**
```yaml
triple_check:
  head: true          # boolean — a task faz sentido estratégico
  heart: false        # boolean — estou motivado para fazê-la
  hand: true          # boolean — tenho o que preciso para começar
  blocker: heart      # derivado: dimensão(ões) com false
  diagnosis: "O bloqueio é emocional. Tente parear com algo prazeroso."
  checked_at: "2026-05-19T14:30:00"
```

**Comportamento Triple Check:**

Pontos de trigger:
1. Menu ⋯ da Task → "Por que estou evitando isso?"
2. Badge ⚠ no card após 7 dias no mesmo stage sem progresso
3. Formulário de criação de PMN: opção batch para tasks velhas

Bottom sheet:
```
Triple Check

🧠 A tarefa faz sentido agora?
   ○ Sim   ○ Incerto   ○ Não

❤️  Você está animado com isso?
   ○ Sim   ○ Incerto   ○ Não

🖐  Você tem o que precisa pra começar?
   ○ Sim   ○ Incerto   ○ Não

[Diagnóstico aparece aqui em tempo real]
[Salvar diagnóstico]
```

Regras de diagnóstico:
- `head` false/uncertain → "A tarefa pode não fazer sentido agora. Reformular ou arquivar?" — Botões: Reformular / Arquivar
- `heart` false/uncertain → "O bloqueio é emocional. Tente parear com algo prazeroso, mudar de ambiente, ou quebrar em partes menores." — Botões: Criar subtasks / Adiar
- `hand` false/uncertain → "Falta recurso ou clareza. O que você precisa antes de começar?" — Botões: Adicionar dependência / Pedir ajuda
- Todos true → "O bloqueio pode ser externo. Verifique dependências e agenda."

Após salvar: ícone muted no card (🧠/❤️/🖐). Tapping abre resultado (read-only) com opção de re-executar.

**Comportamento de Backlog:**
Ao salvar Task sem data: modal "Esta tarefa não tem data. Onde colocá-la?" com opções "Backlog" (stage: backlog, sem data) e "Adicionar para hoje" (data = hoje). Se dismissido: default para hoje.

**Subtasks:**
Cada subtask é um objeto Task completo com arquivo próprio e `parent_task: "[[parent-slug]]"`. Podem ser agrupadas em sessões nomeadas via propriedade `session` em cada subtask.

**Formato Obsidian:**
```yaml
---
id: "task-comprar-equipamento"
type: task
title: "Comprar equipamento de treino"
stage: todo
priority: medium
end_date: 2026-06-30
duration: 30
organizers:
  - "[[projeto-fitness]]"
  - "[[area-saude]]"
tags:
  - compras
linked_system: null
triple_check: null
archived: false
created_at: 2026-05-01T10:00:00
updated_at: 2026-05-19T14:00:00
---

Notas sobre a task.

## Subtasks

- [ ] Pesquisar modelos
- [x] Definir orçamento
```

---

### OBJETO 3: GOAL

**Propriedades:**
- `id`, `type: goal`, `title`, `description`, `start_date`, `end_date`, `status`
- `goal_mode` — enum: `standard` | `plan`. Default: `standard`
- `organizers` — array de WikiLinks
- `kpis` — array de configurações KPI
- `objective` — string (o porquê — apenas para `goal_mode: plan`)
- `strategy` — string (o como — apenas para `goal_mode: plan`)
- `phases` — array de objetos Phase (apenas para `goal_mode: plan`)
- `subtasks` — array de WikiLinks para Tasks
- `schedulers` — array de Schedulers
- `color`, `icon`, `comments`, `participants`, `places`

**goal_mode: plan** adiciona 3 seções na detail view: Objective, Strategy, Phases. Phases agrupam Tasks por etapa temática.

---

### OBJETO 4: HABIT

**Propriedades core:**
- `id`, `type: habit`, `title`, `description`, `color`, `icon`
- `habit_mode` — enum: `habit` | `pact`. Default: `habit`
- `completion_unit` — string livre. Default: "times". Exemplos: "glasses", "minutes", "pages"
- `daily_goal` — integer
- `slots` — array de HabitSlot (cada slot tem `time`, `completed`, `label`, `reminderEnabled`, `reminderTime`, `notificationType`, `actions[]`)
- `schedulers` — array de Schedulers
- `organizers` — array de WikiLinks
- `status` — enum: `active` | `paused` | `completed`
- `habitStartDate` — date
- `priority` — enum: `none` | `low` | `medium` | `high`
- `isNegative` — boolean (habit de evitação)
- `inputType` — enum: `boolean` | `numeric` | `mood` | `duration`
- `linkedTrackerSlug` — slug do Tracker opcional
- `actions` — array de ActionDef (7 tipos — ver seção Actions)
- `archived` — boolean

**Propriedades adicionais para `habit_mode: pact`:**
- `curiosity_question` — string ("O que acontece com minha resistência depois de 30 dias?")
- `hypothesis` — string ("Escrita diária vai reduzir minha ansiedade sobre começar")
- `started_at` — date
- `ends_at` — date
- `pact_outcome` — enum: `persist` | `pause` | `pivot` | null (definido após Steering Sheet)
- `previous_cycles` — array de `{started_at, ends_at, outcome}` (histórico de ciclos anteriores)

**Comportamento do Steering Sheet (apenas para `habit_mode: pact`):**

Acionado quando `ends_at` é atingido e `pact_outcome` é null. Notificação solicita revisão.

Etapa 1 — Revisão:
```
Revisão do Pacto: "[título do pact]"

Sua hipótese era: "[hypothesis]"

O que aconteceu? [campo de texto livre]
```

Etapa 2 — Reflexão:
```
O que você aprendeu?

○ Minha hipótese estava correta
○ Minha hipótese estava incorreta
○ Não tenho certeza

Por que o pacto terminou?
○ Concluí o objetivo
○ Virou obrigação
○ Quero ajustar o escopo
```

Etapa 3 — Decisão:
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  PERSISTIR   │  │    PAUSAR    │  │   PIVOTAR    │
│  Por mais    │  │  Encerrar    │  │  Ajustar o   │
│  ___ dias    │  │  por ora     │  │  pact        │
└──────────────┘  └──────────────┘  └──────────────┘

"O que você aprendeu com esse pacto?" [campo opcional]
```

Resultados:
- **Persistir** → `ends_at` atualizado com nova duração, `status: active`, `pact_outcome: persist`, dados do ciclo anexados a `previous_cycles`
- **Pausar** → `status: paused`, `pact_outcome: pause`. Badge "PAUSADO". Retomável via ⋯ → "Retomar pact"
- **Pivotar** → Abre formulário de criação de Habit-Pact em modo edição. Ciclo anterior salvo em `previous_cycles`.

**Habit/Pact no Planner:**
Aparecem como Habit Reminders na Day View. Visual: cor do habit + nome + checkboxes de slots + streak (habit) ou contagem de dias (pact) + badge "days since". Pact mostra adicionalmente badge "PACT" (texto 10pt uppercase, pill branca, background = cor do habit).

**Design do badge "PACT":** texto "PACT" em 10pt, uppercase, semibold, texto branco, pill shape, background = cor do habit a 100% opacidade. Posicionado no canto superior direito do card.

**Formato Obsidian (exemplo pact):**
```yaml
---
id: "escrever-100-palavras"
type: habit
habit_mode: pact
title: "Escrever 100 palavras"
statement: "Vou escrever 100 palavras por dia durante 30 dias"
curiosity_question: "O que acontece com minha resistência à escrita depois de 30 dias?"
hypothesis: "Escrita diária vai reduzir minha ansiedade sobre começar"
color: "#6B5EA8"
completion_unit: times
daily_goal: 1
started_at: 2026-05-19
ends_at: 2026-06-18
status: active
pact_outcome: null
previous_cycles: []
organizers:
  - "[[area-escrita]]"
archived: false
created_at: 2026-05-19T09:00:00
updated_at: 2026-05-19T09:00:00
---
```

**Registro diário (formato idêntico para habit e pact):**
```yaml
escrever-100-palavras: true   # ou false, ou integer se count-based
```

**Check de status de Pact (em cada abertura do app):**
Para todos os Habits com `habit_mode: pact`, `status: active`, comparar `ends_at` com hoje. Se `ends_at <= hoje` e `pact_outcome = null`: agendar notificação de trigger do Steering Sheet.

---

### OBJETO 5: TRACKER (definição) + TRACKING RECORD (instância)

**Tracker — propriedades:**
- `id`, `type: tracker`, `title`, `color`, `icon`, `description`
- `organizers` — array de WikiLinks
- `sections` — array de TrackerSection (cada seção tem `title` e `input_fields[]`)
- `charts` — array de configurações de Chart (line, bar, pie, calendar)
- `summaries` — array de configurações de Summary

**Tipos de InputField (6):**
1. `text` — texto livre
2. `selection` — seleção única de lista predefinida
3. `quantity` — input numérico com unidade
4. `checklist` — multi-seleção com intensidade opcional
5. `checkbox` — boolean simples
6. `media` — foto/vídeo

Cada InputField tem `title`, `default_value` opcional, e `organizers` (auto-adicionados ao Tracking Record quando o campo é preenchido).

**Tracking Record — propriedades:**
- `tracker` — WikiLink para Tracker pai
- `date` — datetime
- `field_values` — map de field_id → value
- `photos`, `note`, `comments`
- `organizers` — auto-populado dos InputField + manual

**Armazenamento:** Tracking Records ficam na daily note sob `## Trackers`.

---

### OBJETO 6: NOTE

**Subtipos:** `text` | `outline` | `collection`

**Propriedades comuns:**
- `id`, `type: note`, `title`, `created_at`, `updated_at`, `archived`
- `note_subtype` — enum: `text` | `outline` | `collection`
- `organizers` — array de WikiLinks
- `color`
- `parent_note` — WikiLink opcional
- `links` — array de WikiLinks (bi-direcional)

Notes NÃO aparecem na Timeline principal. Ficam na biblioteca de Notes. Podem ser linkadas via `[[WikiLink]]` em qualquer objeto.

**Text Note:** `body` — rich text com imagens inline, checklists, headings, `[[WikiLink]]`.

**Outline Note:** `nodes` — árvore de OutlineNode (id, content, children[], linked_items[], collapsed). Suporta drag-and-drop, focus mode, mirroring.

**Collection Note (database):**
- `schema` — array de PropertyDefinition (20+ tipos: text, rich_text, quantity, date, time, duration, selection, multi_selection, checkbox, url, email, phone, rating, relation, media, etc.)
- `items` — array de CollectionItem
- `views` — list/gallery/table

---

### OBJETO 7: CALENDAR SESSION

**Propriedades:**
- `id`, `type: calendar_session`, `title`, `date`, `color`
- `state` — enum: `scheduled` | `in_progress` | `completed` | `backlog` | `cancelled`
- `time_of_day` — referência a Time Block OU HH:MM exato
- `duration`, `end_time`, `multi_day`
- `task` — WikiLink opcional para Task
- `goal` — WikiLink opcional para Goal
- `subtasks` — checklist inline para a sessão
- `note`, `places`, `participants`, `reminders`
- `organizers` — array de WikiLinks
- `scheduler` — Scheduler opcional
- `timer` — configurações de Pomodoro opcionais
- `backlog` — boolean
- `exported_calendar_id` — ID de evento Google Calendar
- `linked_google_event_id`, `linked_google_event_title`, `linked_google_event_date`, `linked_google_event_url`

---

### OBJETO 8: REMINDER

**Propriedades:**
- `id`, `type: reminder`, `title`, `date`, `time`, `time_block`
- `completable` — boolean
- `checkboxes` — array
- `organizers` — array de WikiLinks
- `scheduler` — opcional
- `habit_reminder` — boolean (auto-gerado pelo scheduler de Habit)

---

### OBJETO 9: SYSTEM (novo)

**Propósito:** Guia executável reutilizável para um processo repetível. Diferente de uma Note (referência estática) porque um System pode ser executado: a execução gera uma Task com subtasks derivadas dos steps, e o System rastreia histórico de execuções.

**Propriedades:**
- `id`, `type: system`, `title`
- `trigger` — string ("Toda vez que for publicar conteúdo no Instagram")
- `estimated_minutes` — integer
- `run_count` — derivado: total de Tasks com `linked_system = este`
- `last_run` — derivado: `created_at` mais recente dessas Tasks
- `average_minutes` — derivado: média de `timer_sessions` das Tasks vinculadas
- `organizers`, `tags`, `links`
- `archived` — boolean
- `steps` — array de Step:
```yaml
steps:
  - id: s1
    text: "Verificar calendário editorial"
    estimated_minutes: 2
    substeps: []
  - id: s2
    text: "Criar assets no Canva"
    estimated_minutes: 10
    substeps:
      - "Exportar 1080×1080"
      - "Exportar Stories 9×16"
```
- `body` — rich text opcional (notas e contexto)

**UI de criação:**
`+` → aba Note → "System". Formulário full-screen:
1. Título (28pt, obrigatório)
2. Campo Trigger: "Quando usar este system?"
3. Tempo estimado: input numérico + "min"
4. Lista de steps: número + texto + estimativa de tempo + [+ Substep]
5. Organizadores e tags
6. Notas/body
7. Botão "✨ Estruturar com IA" (antes de adicionar steps): usuário descreve o processo em linguagem livre → API retorna JSON estruturado → usuário revisa e confirma

**"Salvar como System" a partir de Task:** Menu ⋯ → "Salvar como System". Cria System com steps gerados das subtasks atuais.

**Detail view do System:**
- Header: título grande + label "System" + menu ⋯
- Stats row: "N execuções", "Estimado: Xmin", "Média real: Xmin" (apenas se run_count > 0), "Último: há N dias"
- Steps: lista numerada read-only. Expansível para ver substeps.
- Histórico: lista de Tasks geradas, com título + data + duração + stage
- Notes: body renderizado como rich text
- CTA: botão "▶ Executar" (full-width, bottom)

**Executando um System (3 vias):**

Via A — Da detail view:
1. Tap "▶ Executar"
2. Bottom sheet: título da task (pré-preenchido), organizadores, data (default: hoje)
3. "Criar task" → Task criada com subtasks dos steps + `linked_system` definido
4. `run_count` incrementa, `last_run` atualiza
5. Task abre na Task detail view

Via B — "Aplicar System" de qualquer Task:
Menu ⋯ → "Aplicar System" → picker de Systems por último uso → tap → steps adicionados como subtasks + `linked_system` definido

Via C — Quick-run (efêmero, sem Task):
Botão secundário "Executar inline". Abre bottom sheet com checklist dos steps. Completar todos: `run_count` incrementa. Nenhum arquivo criado.

**Formato Obsidian:**
```yaml
---
id: "system-publicar-instagram"
type: system
title: "Publicar post no Instagram"
trigger: "Toda vez que for publicar conteúdo no Instagram"
estimated_minutes: 25
organizers:
  - "[[area-marketing]]"
archived: false
created_at: 2026-04-01T10:00:00
updated_at: 2026-05-12T14:00:00
steps:
  - id: s1
    text: "Verificar calendário editorial"
    estimated_minutes: 2
    substeps: []
  - id: s2
    text: "Criar assets no Canva"
    estimated_minutes: 10
    substeps:
      - "Exportar 1080×1080"
      - "Exportar Stories 9×16"
---

## Notas

Use este system sempre que for publicar.
```

---

### OBJETO 10: SOCIAL POST

**Propriedades:**
- `id`, `type: social_post`
- `platform` — enum: `instagram` | `twitter` | `linkedin` | `facebook` | `other`
- `url` — string
- `caption` — rich text
- `media` — array de URLs ou paths locais
- `saved_at` — datetime
- `organizers` — array de WikiLinks
- `linked_tasks` — array de WikiLinks para Tasks
- `linked_content` — array de WikiLinks para qualquer objeto
- `archived` — boolean

**UI de criação:**
1. Platform e URL pré-preenchidos ou entrada manual
2. Caption e media extraídos ou upload
3. Seção de linkagem unificada: busca qualquer objeto do vault
4. Filtro por tipo dentro da busca (Tarefas, Notas, Áreas, Metas, etc.)

---

> **Nota de implementação (2026-06-21):** dois problemas no código atual motivaram as decisões dos objetos 11–14 abaixo. (1) A triagem do Inbox mandava "ideia" para `CreateNoteForm` em vez de criar um `IdeaDefinition` — corrigido no Objeto 12. (2) Existiam dois modelos de Shopping List concorrentes (`shopping_item.dart`, solto, usado de fato hoje, e `shopping_list_model.dart`, com itens aninhados, órfão) — resolvido no Objeto 14, que define `ShoppingList` como fonte de verdade dali pra frente.

### OBJETO 11: IDEA

**Propósito:** capturar uma possibilidade, insight ou pensamento em estágio de maturação — algo que ainda não é uma ação definida (por isso não é Task) e que tem ciclo de vida próprio, não é só referência estática (por isso não é Note). Pode nascer sozinha, a partir da triagem de um Inbox item, ou comentando qualquer outro objeto do vault.

Resolve diretamente o pedido: *"como anotar ideias? q podem tá relacionada a qqr coisa no vault"* (09/06).

**Propriedades:**
- `id` — string, único
- `type` — sempre `idea`
- `title` — string, obrigatório
- `body` — rich text
- `status` — enum: `raw` | `developing` | `ready_to_act` | `converted` | `dropped`. Default: `raw`
- `horizon` — enum: `now` | `soon` | `someday` | `no_deadline`. Default: `someday`
- `priority` — enum opcional (mesmo enum de Task: `none`/`low`/`medium`/`high`)
- `target_date` — date, opcional
- `linked_slugs` — array de WikiLinks para **qualquer objeto do vault** (Task, Note, Area, Project, Resource, Social Post, People, Place, outro Idea, etc.) — é o campo que resolve "relacionada a qualquer coisa"
- `converted_to_type` / `converted_to_id` — preenchidos apenas quando `status: converted`
- `organizers`, `tags`, `color`, `emoji` — opcionais, padrão universal
- `archived` — boolean, default false

**Significado de cada `status`:**
- `raw` — acabou de ser capturada, sem refinamento. Estado inicial sempre.
- `developing` — usuária voltou a ela: editou o body, adicionou links, ou trocou manualmente. Transição automática na primeira edição substancial após a criação (ou manual via menu).
- `ready_to_act` — marcada manualmente quando a ideia está madura o suficiente para virar algo concreto. Aparece destacada numa seção "Prontas para agir" na tela de Ideas.
- `converted` — terminal. Definido automaticamente pelo fluxo de conversão (ver abaixo). Idea some das listas ativas, mas continua acessível via Archive e via link reverso no objeto que ela gerou.
- `dropped` — terminal, descarte consciente. Diferente de deletar: fica arquivada para histórico ("já pensei nisso e decidi que não vale a pena").

**`horizon` — para que serve:** não é prazo (isso é `target_date`), é urgência de revisão. Define o agrupamento/ordenação padrão na tela de Ideas: `now` no topo, depois `soon`, depois `someday`/`no_deadline` juntas no fim.

**Comportamento de conversão (Idea → Task/Goal/Project/Note):**
1. Detail view → botão "✨ Transformar em..." → bottom sheet com 4 opções: Task, Goal, Project (organizador), Note.
2. Ao escolher: abre o formulário de criação do tipo escolhido, pré-preenchido com `title` (vira título do novo objeto) + `body` (vira description/notes/body, conforme o tipo) + `linked_slugs` copiados para `organizers`/`links` do novo objeto, quando fizer sentido pro tipo de destino.
3. Ao salvar o novo objeto com sucesso:
   - A Idea original recebe `status: converted`, `converted_to_type`, `converted_to_id`.
   - O novo objeto recebe automaticamente `links: [["idea-slug"]]` — preserva a proveniência, visível na seção "Menções" de ambos (PARTE 16 — Linking Universal).
4. Cancelar o formulário de destino não altera a Idea.

Isso garante que nenhuma informação da ideia original se perde na conversão — o mesmo princípio do pedido sobre Social Post → Task (13/06): *"sem perder as infos da tarefa/projeto nem do post"*.

**UI de criação:**
FAB → aba **Note** ganha uma 5ª opção: "💡 Ideia" (junto de Nota de texto, Outline, Coleção, System). Formulário: Título (obrigatório), Body (rich text, opcional), Horizon (segmented control: Agora/Em breve/Algum dia), Relacionada a... (abre o Link Picker Universal — mesma busca fuzzy de qualquer objeto do vault descrita na PARTE 16), Organizadores, Tags.

**Tela de Ideas (nova página, listada em PARTE 4 entre as páginas disponíveis para a bottom nav):**
- Filtros: chips de status (Todas / Raw / Developing / Prontas / —) e horizon.
- Cards: título (15pt medium) + preview do body (1 linha, muted) + badge de horizon (cor por urgência: now=vermelho suave, soon=amarelo, someday=cinza) + badge de status + até 3 chips de `linked_slugs` (ícone do tipo linkado + título truncado) + "+N" se houver mais + emoji se definido, alinhado à direita do título.
- Seção fixa no topo "Prontas para agir" quando houver itens `ready_to_act`.
- Empty state: ícone 💡 + "Nenhuma ideia ainda" + CTA "Capturar ideia".

**Formato Obsidian:**
```yaml
---
id: "idea-app-de-receitas-tiktok"
type: idea
title: "App de receitas separado por dicas do TikTok"
status: developing
horizon: soon
linked_slugs:
  - "[[social-post-receita-carne-123]]"
  - "[[area-cozinha]]"
organizers:
  - "[[area-cozinha]]"
converted_to_type: null
converted_to_id: null
archived: false
created_at: 2026-06-09T11:30:00
updated_at: 2026-06-15T09:00:00
---

Reunir todas as dicas de carne que salvo do TikTok num lugar só, com tags por tipo de corte.
```

---

### OBJETO 12: INBOX ITEM

**Propósito:** ponto de captura universal e instantâneo, estilo GTD — um lugar para jogar qualquer pensamento sem decidir agora o que ele é. Por definição, tudo no Inbox é não-tipado: texto cru. A única coisa que se faz com um item de Inbox depois é **triá-lo** (decidir o tipo real e converter) ou descartá-lo.

**Propriedades:**
- `id`, `type: inbox`, `title` (o texto digitado), `content` (corpo opcional, hoje sempre vazio na captura — reservado para anexos futuros), `created_at`, `archived`

**Captura:** campo único de texto, sempre focado ao abrir a tela, Enter ou botão de enviar cria o item. Sem campos adicionais — qualquer fricção aqui anula o propósito do Inbox (consistente com o padrão de fricção mínima pedido em vários pontos: transcrição automática, embed automático, etc.).

**Auto-arquivamento:** item com `created_at` há mais de 30 dias sem triagem é arquivado automaticamente na próxima abertura da tela (mesmo fluxo de `_deleted/` usado em todo o app — PARTE 5, Undo em Delete/Archive). Um snackbar avisa quantos itens foram arquivados e seus títulos. Isso existe para o Inbox não virar um cemitério de pensamentos esquecidos, mas também significa que ele precisa ser revisado com alguma regularidade — sugestão: se `pendingCount > 0` por mais de 7 dias, considerar um lembrete leve (não implementado ainda, fica como nota para o futuro).

**Triagem — bottom sheet "O que é isso?"**

Cada opção abre o formulário de criação correspondente, **pré-preenchido com o texto capturado** (sem perda de informação), e remove o item do Inbox somente se o formulário de destino for salvo com sucesso (cancelar mantém o item no Inbox).

| Opção | Ação |
|---|---|
| ✅ Virou uma task | `CreateTaskForm(initialTitle: item.title)` |
| 💡 Era uma ideia | `CreateIdeaForm(initialTitle: item.title)` — ⚠️ **corrige o bug atual**, que mandava isso para `CreateNoteForm` |
| 📝 Era uma nota | `CreateNoteForm(initialTitle: item.title)` — opção nova, separada da Idea |
| 📓 É uma entrada do journal | `CreateEntryForm(initialBody: item.title)` |
| 📅 Era um evento/compromisso | `CreateCalendarSessionForm(initialTitle: item.title)` — agenda dentro do app (ver Objeto 13 sobre por que não é `Event`) |
| 🛒 Item de compra | adiciona como item `active` na Shopping List padrão (pergunta qual lista se houver mais de uma — ver Objeto 14) |
| 🗑 Descartar | delete direto, sem criar nada, sem confirmação adicional (já existe swipe pra isso na lista) |

**UI da lista:** ordenada do item mais antigo para o mais novo (o que está esperando há mais tempo aparece primeiro — empurra a triagem do que está acumulando). Swipe left → arquiva/descarta. Swipe right ou tap → abre a triagem. Badge de contagem (`pendingCount`) no ícone da bottom nav (se "Inbox" estiver na barra) e na seção correspondente do Command Center.

**Formato Obsidian:** pasta fixa `inbox/`, um arquivo por item, nomeado por timestamp: `inbox/YYYY-MM-DD-HH-mm.md`.

```yaml
---
id: "inbox-2026-06-09-11-26"
type: inbox
title: "ver se da pra puxar transcricao do tiktok de graca com whisper"
created_at: 2026-06-09T11:26:00
archived: false
---
```

---

### OBJETO 13: EVENT (espelho somente-leitura do Google Calendar)

**Propósito:** representar um evento que existe no Google Calendar mas **não** foi criado dentro do app — é o lado inverso da integração. **Calendar Session** (Objeto de conteúdo #7, já documentado na PARTE 2 principal) é a sessão nativa do app, que opcionalmente pode ser exportada para o Google. **Event** é o caminho contrário: um evento que já existia no Google (criado por outro app, por outra pessoa convidando você, etc.) e que o app só reflete.

**Diferença explícita Event × Calendar Session** (resolve a ambiguidade entre os dois, que hoje não está documentada em lugar nenhum):

| | Calendar Session | Event |
|---|---|---|
| Origem | Criada dentro do app | Já existia no Google Calendar |
| Vive como arquivo no vault | Sim — `app/calendar-session-SLUG.md` | Não — existe só em memória/cache, populada a cada sync via Google Calendar API |
| Editável dentro do app | Sim, todos os campos | Não — somente leitura. Editar abre o Google Agenda |
| Pode ter Task/Goal/organizers vinculados | Sim, nativamente (`task`, `goal`, `organizers`) | Indireto: dá pra vincular Participantes (resolvidos para People) e adicionar `organizers`/`links` localmente, mas o evento em si não é editável |
| Aparece no Planner/Timeline | Sim | Sim, na mesma timeline, com ícone do Google para diferenciar visualmente |
| Sentido do sync | App → Google (se `scheduler`/export configurado) | Google → App, nunca o inverso |

**Propriedades:**
- `id`, `type: event`, `title`
- `start_datetime`, `end_datetime` opcional
- `location`, `description` opcionais
- `participants` — array de e-mails/nomes crus do Google
- `google_event_id`, `google_calendar_id`, `google_event_url`
- `organizers` — atribuídos manualmente pela usuária dentro do app (não vêm do Google)
- `tags`, `reminders` — lembretes locais do app, independentes de qualquer lembrete configurado no Google

**Comportamento:**
- Nunca passa pela Object Identification nem é gravado no vault — é populado por `google_calendar_provider` a cada sync e mesclado na timeline junto às Calendar Sessions.
- Sync é **one-way** (Google → app). O app nunca escreve de volta no Google a partir de um Event; escrever de volta só acontece para Calendar Session, via export explícito.
- Detail view (já existe, `google_event_detail_screen.dart`): título, data/hora, local, descrição, participantes com resolução para People existentes, botão "Abrir no Google Agenda".
- **Deduplicação:** se um Event tem o mesmo `google_event_id` de uma Calendar Session já exportada (campo `exported_calendar_id` da Calendar Session), o app mostra **só a Calendar Session** — ela é a fonte de verdade local — com um badge "🔄 sincronizado". O Event "puro" correspondente fica oculto para não duplicar visualmente o mesmo compromisso na timeline.

**UI de criação:** não existe — Events só chegam via sync. Se a usuária quer criar algo, ela cria uma Calendar Session (que pode depois ser exportada pro Google).

**Formato Obsidian:** nenhum. Objeto efêmero, não é arquivo do vault.

---

### OBJETO 14: SHOPPING LIST (+ Shopping Item)

**Propósito:** lista de compras com captura ultra-rápida, agrupamento por categoria, suporte a múltiplas listas, e suporte a widget nativo na home screen.

**⚠️ Decisão de arquitetura — qual modelo é a fonte de verdade daqui pra frente:**

Adoto `ShoppingList` com itens aninhados (`shopping_list_model.dart`) como modelo canônico, e `shopping_item.dart` (item solto, lista única global) como **deprecado**. Motivos:
- Suporta múltiplas listas nomeadas (ex: "Mercado", "Farmácia", "Casa nova") — o modelo antigo só tinha uma lista plana global, sem como separar contextos.
- Suporta `quantity` por item (ex: "2 kg", "1 caixa") — sem isso a lista de compras é só um checklist genérico, não cumpre a função real de lista de compras.
- Suporta `category` nativamente, permitindo o agrupamento visual (Hortifruti, Limpeza, etc.) sem gambiarra.
- `hide_checked` já modela o comportamento padrão de qualquer lista de compras: esconder o que já foi comprado.

**Migração necessária:** a tela atual (`shopping_list_screen.dart`), o provider (`shoppingItemsProvider`) e o dashboard block (`shopping_list_block.dart`) precisam ser reescritos para ler de `ShoppingList.items` em vez do `ShoppingItem` solto. Os itens soltos existentes devem ser importados, na migração, como uma única `ShoppingList` chamada "Lista de Compras" — preservando nome e status (`active`/`checked`).

**Propriedades — ShoppingList:**
- `id`, `type: shopping_list`, `title`
- `emoji` — default `🛒`
- `color` opcional
- `items` — array de ShoppingItem (abaixo)
- `hide_checked` — boolean, default `true`
- `organizers`, `tags`, `archived`

**Propriedades — ShoppingItem (aninhado, sem arquivo próprio):**
- `id`, `name`
- `quantity` — string livre, ex: "2 kg", "1 caixa"
- `category` — string livre, ex: "Hortifruti", "Limpeza"
- `note` — opcional
- `status` — enum: `active` | `checked` | `archived`
- `order` — integer, para ordenação manual dentro do grupo

**Comportamento de captura e duplicatas:**
Campo de texto fixo no topo (mesmo padrão de fricção mínima usado no Inbox) → Enter cria item com `status: active`, sem categoria (vai pro grupo "Outros" até ser categorizado).

Detecção de duplicata ao capturar (mesmo nome, case-insensitive, na mesma lista):
- Se já existe um item `checked` com esse nome: ele volta para `active` (reaproveita o item, não cria um novo) e funde `quantity`/`note` se algo novo foi informado.
- Se já existe um item `active`: não cria duplicado — só dá um highlight visual de 1s no item existente, como feedback de "já está na lista".

**Agrupamento e exibição:**
- Itens `active` agrupados por `category`, em seções com header; dentro de cada grupo, ordenados por `order`. Sem categoria → grupo "Outros" ao final.
- Itens `checked`: se `hide_checked = true`, ficam numa seção colapsável "Comprados (N)" ao final da lista; se `false`, aparecem riscados e com opacidade reduzida nos seus grupos de categoria originais.
- Toggle de `hide_checked` na AppBar da lista (ícone de olho).
- Swipe left no item → toggle active/checked. Swipe right → delete (com Undo padrão de 5s, PARTE 5).

**Múltiplas listas:**
Tela índice "Shopping Lists" — cards por lista (emoji + título + "N de M itens"), tap abre a lista. Criar nova lista: nome + emoji picker.

**Integração com Inbox (Objeto 12):**
Opção de triagem "🛒 Item de compra" pergunta em qual lista adicionar (default: última lista usada) e cria o item como `active`.

**Widget nativo (PARTE 15):**
O widget tipo "Category" já cobre este caso — configurado para apontar para uma `ShoppingList` específica. Marcar um item no widget precisa de write-through direto para o vault (mesmo princípio de qualquer outra mudança offline-first, PARTE 12).

**UI de criação de lista:** nome (placeholder "Mercado", "Farmácia"...) + emoji picker + "Criar". Itens são adicionados depois, dentro da lista, pelo campo de captura.

**Formato Obsidian:** um arquivo por lista, `app/shopping-list-SLUG.md`. Frontmatter com `items` como array YAML; corpo com checklist Markdown espelhado (`- [ ]` / `- [x]`) para legibilidade nativa no Obsidian puro e compatibilidade com o Tasks Plugin.

```yaml
---
id: "shopping-list-mercado"
type: shopping_list
title: "Mercado"
emoji: "🛒"
hide_checked: true
archived: false
items:
  - id: "i1"
    name: "Leite"
    quantity: "2 caixas"
    category: "Laticínios"
    status: active
    order: 0
  - id: "i2"
    name: "Detergente"
    category: "Limpeza"
    status: checked
    order: 0
created_at: 2026-06-01T09:00:00
updated_at: 2026-06-20T18:00:00
---

## Mercado

- [ ] Leite (2 caixas)
- [x] Detergente
```

---

## PARTE 3 — OBJETOS DE SUPORTE

### SCHEDULER

**Tipos de regra (11 tipos):**
1. `number_of_days` — A cada N dias
2. `days_of_week` — Em dias específicos da semana
3. `number_of_weeks` — A cada N semanas
4. `number_of_months` — A cada N meses, em dia(s) específico(s)
5. `number_of_hours` — A cada N horas (intraday)
6. `days_after_last_start` — N dias após início da última instância
7. `days_after_last_end` — N dias após conclusão da última instância
8. `days_per_period` — N dias por período (semana/mês/ano) com offset inicial e intervalo mínimo
9. `linked_item_appears` — Quando [X objeto] aparece no calendário
10. `n_days_after_linked_item` — N dias/horas após [X objeto] aparecer
11. `first_business_day_of_month` — Primeiro dia útil do mês

**Regras de exclusão separadas:** `day_of_week`, `day_of_month`, `linked_item_present`.

**Política de atraso:** `skip` | `keep` | `prompt`.

**Múltiplas regras por scheduler** (OR lógico). Um objeto pode ter múltiplos schedulers.

**Página de Scheduler global (Settings → Scheduler):** lista todos os objetos com scheduler ativo. Toggle por linha. Tapping abre configuração.

---

### DAY THEME

- `name` — string
- `blocks` — array de referências a Time Block
- `days_of_week` — array de dias
- `color` — opcional

---

### TIME BLOCK (atualizado)

- `name` — string
- `time_ranges` — array de `{start_time, end_time}` (pode ser 0 = apenas label)
- `color` — opcional
- `order` — integer
- `energy_level` — enum: `high` | `medium` | `low` | null

**Energy Map no Planner:**
Quando ao menos um bloco tem `energy_level` configurado: toggle "Camada de energia" aparece nos controles da Day View.
- Ativo: tints de background nos blocos (green/yellow/red a 8% opacity). Tasks longas ou de alta prioridade em blocos de alta energia recebem label "↑ Melhor horário".
- Desativado: sem tints.

**Auto-geração a partir de Field Notes:**
Após 14+ dias de Field Notes com `category: energy` e `energy_value`: Settings → Planner → Energy Map → "Ver meu padrão" mostra heatmap médio por hora. "Aplicar ao meu calendário" auto-atribui `energy_level` aos Time Blocks.

Tints:
- high → `#4CAF50` a 8% opacity
- medium → `#FFC107` a 8% opacity
- low → `#FF7043` a 8% opacity

---

### KPI

**Source types:** `subtasks`, `tracker_field`, `habit`, `collection`, `entry`, `time_spent`, `manual_quantity`, `others`.

**Para cada source:**
- `subtasks` → % de subtasks completadas desta goal/project
- `tracker_field` → sum/average/count/max/min de um campo específico
- `habit` → streak, dias bem-sucedidos, ou total de completions
- `collection` → contagem de itens que atendem filtro
- `entry` → contagem de entradas que mencionam este objeto
- `time_spent` → minutos de Pomodoro vinculados
- `manual_quantity` → usuário insere valor. Input inline na detail view. Botão "+N" para incremento rápido.

**Auto-complete:** KPI pode ser marcado como "auto-complete": quando `current_value >= target_value`, acionada ação configurada.

---

### SNAPSHOT

- `subject` — WikiLink para objeto (Task, Goal, Note)
- `date` — datetime
- `state_data` — estado serializado
- `reflection` — rich text opcional
- `photos` — array opcional
- Aparece na Timeline como entrada

---

### DASHBOARD PANEL

**Tipos de painel** (incluindo novos do V2):
- Today's Habits
- Upcoming Sessions
- Goal Progress
- KPI Panel
- Tracker Charts
- Task Summary
- Pinned Note
- Pinned Planner
- Statistics Summary
- `system_quick_run` ← novo: N Systems mais usados como botões de quick-run
- `pact_today` ← novo: Pacts ativos com checkbox de check-in de hoje
- "Como você está?" (mood capture inline)
- Task block (lista configurável de tasks)
- Project block (projetos com barras de progresso)
- Combined Analysis block
- Habit list block
- Journal quick-add block
- Planner/Calendar block
- Google Calendar block
- Time blocking block
- People block
- Stats/KPI block
- Custom Markdown block

---

### MOOD DEFINITION (objeto de primeira classe)

**Propriedades:**
- `id` — slug único (ex: `calm`, `joyful`, `anxious`)
- `type` — sempre `mood_definition`
- `source` — enum: `system` | `user`. Moods `system` não podem ser editados nem deletados, apenas ocultados. Moods `user` são totalmente gerenciáveis.
- `hidden` — boolean. Se `true`, o mood não aparece no picker, mas dados históricos são preservados integralmente.
- `label` — string display em português (ex: "Calma", "Alegre")
- `label_en` — string original em inglês, apenas para moods `source: system` (ex: "Calm", "Joyful"). Usado para busca por nome em inglês no picker.
- `description` — string curta (1–2 frases) explicando o que a pessoa pode estar sentindo nesse estado. Exibida no picker ao selecionar um mood.
- `emoji` — emoji único associado ao mood
- `quadrant` — enum: `red` | `yellow` | `green` | `blue`
- `pleasantness` — integer de 1 a 5 (1 = muito desagradável, 5 = muito agradável)
- `energy` — integer de 1 a 5 (1 = muito baixa energia, 5 = muito alta energia)
- `color` — hex derivado do quadrante (não editável em moods `system`; editável em `user`)
- `aliases` — array de strings. Aliases alternativos para o mood, gravados como campo nativo de aliases do Obsidian. Permitem que `[[feliz]]`, `[[felicidade]]` e `[[joyful]]` resolvam para o mesmo arquivo. Editável em moods `system` e `user`. É o único campo editável em moods `system` além de `hidden`.
- `order` — integer (para reordenar dentro do quadrante)

**Cores por quadrante (fixas para moods `system`):**
- `red` → `#EF5350` (alta energia, desagradável)
- `yellow` → `#FFA726` (alta energia, agradável)
- `green` → `#66BB6A` (baixa energia, agradável)
- `blue` → `#42A5F5` (baixa energia, desagradável)

**Armazenamento:**
Moods `system` **não geram arquivo `.md` na instalação**. O arquivo `moods/SLUG.md` é criado automaticamente na **primeira vez que o usuário registra aquele mood**. Antes disso, o mood vive apenas em memória. Moods `user` geram arquivo imediatamente ao serem criados.

O campo `aliases` é gravado no frontmatter como o campo nativo de aliases do Obsidian, garantindo que WikiLinks alternativos resolvam corretamente tanto no app quanto no Obsidian puro.

**Formato do arquivo (exemplo):**
```yaml
---
id: "joyful"
type: mood_definition
source: system
hidden: false
label: "Alegre"
label_en: "Joyful"
description: "Alegria espontânea, muitas vezes sem causa específica. Leveza e calor."
emoji: "😁"
quadrant: yellow
pleasantness: 5
energy: 4
color: "#FFA726"
order: 7
aliases:
  - alegria
  - joyful
  - feliz
created_at: 2026-05-19T08:30:00
---
```

**Picker de humor (UI — dois passos):**

Passo 1 — Grade 2×2 interativa:
```
┌─────────────────────────────────────────────┐
│  Como você está agora?                      │
│                                             │
│  ↑ ENERGIA                                  │
│  ┌───────────────┬───────────────┐          │
│  │ 🔴            │ 🟡            │          │
│  │ Desagradável  │ Agradável     │          │
│  │ Alta energia  │ Alta energia  │          │
│  ├───────────────┼───────────────┤          │
│  │ 🔵            │ 🟢            │          │
│  │ Desagradável  │ Agradável     │          │
│  │ Baixa energia │ Baixa energia │          │
│  └───────────────┴───────────────┘          │
│                          AGRADÁVEL →        │
└─────────────────────────────────────────────┘
```
Tap num quadrante → Passo 2.

Passo 2 — Lista de moods do quadrante selecionado:
Grid de pills com emoji + label. Campo de busca por texto (busca em `label`, `label_en` e `aliases`). "Adicionar minha própria emoção" no final da lista → abre formulário de criação de mood `user`.

**Moods `user` — formulário de criação:**
1. **Nome** — string livre (ex: "Nostálgica", "Flow")
2. **Emoji** — picker de emoji
3. **Quadrante** — seleção dos 4 quadrantes (define cor base e valores iniciais de `pleasantness` e `energy`)
4. **Ajuste fino** — dois sliders dentro do quadrante: "Mais ou menos agradável" e "Mais ou menos energia" (refina os valores inteiros de 1 a 5)
5. **Descrição** — campo de texto livre (opcional, mas recomendado)
6. **Aliases** — campo de tags editável (ex: "alegria", "felicidade")
7. **Cor** — visual color picker. Default: cor do quadrante selecionado

**Gerenciamento:** Settings → Mood → Mood Levels.
- Moods `system`: toggle de visibilidade (ocultar/mostrar) + campo de aliases. Não editáveis em nenhum outro campo, não deletáveis.
- Moods `user`: criar, editar todos os campos, reordenar, deletar.
- Moods listados por quadrante. Drag para reordenar dentro do quadrante.
- Badge sutil "meu" nos moods `user` nas listagens.

**Gráficos e Combined Analysis — como moods funcionam:**

Cada mood tem dois valores numéricos: `pleasantness` (1–5) e `energy` (1–5). Ambos ficam disponíveis como séries separadas na Combined Analysis.

- **No gráfico de linha:** o emoji do mood é exibido **como marcador visual no ponto de cada dia** na linha de `pleasantness`. A linha em si usa o valor numérico. Isso permite ver o padrão emocional sem precisar decorar a escala numérica.
- **No calendário da Combined Analysis:** cada dia exibe o **emoji do mood registrado** (ou o emoji do mood mais frequente se houver múltiplos registros no dia). Dots coloridos de outras fontes (fluxo, cólica) aparecem abaixo do emoji.
- **Múltiplos registros no mesmo dia:** calendário exibe emoji do registro mais recente. Gráfico de linha usa a média dos valores do dia. Tooltip mostra todos os registros do dia ao tocar.
- **Legenda dos gráficos** usa `label` (PT), não emoji. Emoji aparece apenas como marcador de ponto e no calendário.

**Normalização para Combined Analysis com trackers:**
- Campos de tracker já numéricos (ex: fluxo 0–10, cólica 0–10): usar `normalization: dual_axis` — eixo esquerdo para tracker (escala original), eixo direito para mood (1–5).
- Campos de tracker categóricos (ex: fluxo = "leve/médio/forte"): usar `value_mapping` para converter para numérico antes de plotar.
- Opção `normalization: normalize_0_1` normaliza todas as séries para 0–1 para facilitar comparação visual de formas de curva.

A propriedade `normalization` fica em cada chart config dentro de Combined Analysis:
```yaml
charts:
  - type: line
    normalization: dual_axis   # none | dual_axis | normalize_0_1
    series:
      - source: journal_mood
        dimension: pleasantness   # pleasantness | energy
        label: "Agradabilidade"
        color: "#34d399"
        axis: right
      - source: tracker_field
        tracker: menstruacao
        field: fluxo
        label: "Fluxo"
        color: "#f472b6"
        axis: left
```

---

## MOODS DO SISTEMA (source: system) — Baseados no Mood Meter de Yale / How We Feel

48 moods pré-carregados, 12 por quadrante. Todos `hidden: false` por padrão. O usuário pode ocultar individualmente via Settings → Mood → Mood Levels.

---

### 🔴 Quadrante VERMELHO — Alta energia, Desagradável
`pleasantness: 1–2 | energy: 4–5 | color: #EF5350`

| id | label (PT) | label_en | emoji | pleasantness | energy | description |
|---|---|---|---|---|---|---|
| `enraged` | Enfurecida | Enraged | 😡 | 1 | 5 | Raiva intensa, fora de controle. Pode sentir calor no rosto e vontade de agir impulsivamente. |
| `panicked` | Em pânico | Panicked | 😱 | 1 | 5 | Medo agudo e súbito. O corpo entra em modo de fuga — coração acelerado, respiração curta. |
| `livid` | Furiosa | Livid | 🤬 | 1 | 5 | Raiva que sente injusta. Difícil de deixar passar, domina os pensamentos. |
| `furious` | Raivosa | Furious | 😤 | 1 | 5 | Irritação intensa, prestes a explodir. Pequenas coisas parecem insuportáveis. |
| `terrified` | Aterrorizada | Terrified | 😨 | 1 | 5 | Medo paralisante de algo específico. O corpo reage como se houvesse perigo real. |
| `shocked` | Chocada | Shocked | 😳 | 1 | 5 | Surpresa desagradável e intensa. Difícil processar o que aconteceu. |
| `anxious` | Ansiosa | Anxious | 😰 | 2 | 4 | Preocupação persistente com algo que pode (ou não) acontecer. Mente acelerada, corpo tenso. |
| `stressed` | Estressada | Stressed | 😖 | 2 | 4 | Muita demanda, pouco recurso. Sensação de estar no limite, sobrecarregada. |
| `frustrated` | Frustrada | Frustrated | 😣 | 2 | 4 | Algo está bloqueando o que você quer. Esforço sem resultado gera essa tensão. |
| `agitated` | Agitada | Agitated | 😬 | 2 | 4 | Inquietação física e mental. Difícil ficar parada, difícil focar. |
| `irritated` | Irritada | Irritated | 😒 | 2 | 4 | Incômodo com algo ou alguém. Menor que raiva, mas persistente. |
| `jittery` | Nervosa | Jittery | 😵 | 2 | 4 | Nervosismo físico — tremor, agitação, dificuldade de se acalmar. Antecipação de algo ruim. |

---

### 🟡 Quadrante AMARELO — Alta energia, Agradável
`pleasantness: 4–5 | energy: 4–5 | color: #FFA726`

| id | label (PT) | label_en | emoji | pleasantness | energy | description |
|---|---|---|---|---|---|---|
| `ecstatic` | Eufórica | Ecstatic | 🤩 | 5 | 5 | Alegria no nível máximo. Tudo parece incrível, a energia transborda. |
| `elated` | Radiante | Elated | 😄 | 5 | 5 | Felicidade intensa e elevada. Uma conquista ou notícia boa gerou esse estado. |
| `excited` | Empolgada | Excited | 😃 | 5 | 4 | Antecipação positiva. Algo bom está chegando e o corpo já está reagindo a isso. |
| `enthusiastic` | Entusiasmada | Enthusiastic | 🙌 | 5 | 4 | Energia direcionada para algo que importa. Vontade de agir e se envolver. |
| `energized` | Energizada | Energized | ⚡ | 4 | 5 | Vitalidade plena — física e mental. Pronta para qualquer coisa. |
| `happy` | Feliz | Happy | 😊 | 5 | 4 | Bem-estar geral, satisfação com o momento. Um estado leve e positivo. |
| `joyful` | Alegre | Joyful | 😁 | 5 | 4 | Alegria espontânea, muitas vezes sem causa específica. Leveza e calor. |
| `upbeat` | Animada | Upbeat | 😀 | 4 | 4 | Disposição positiva, otimismo no ar. Interações sociais fluem bem. |
| `inspired` | Inspirada | Inspired | ✨ | 4 | 4 | Algo acendeu uma faísca criativa. Vontade de criar, escrever, fazer. |
| `motivated` | Motivada | Motivated | 💪 | 4 | 4 | Clara intenção de agir. Obstáculos parecem menores que o objetivo. |
| `optimistic` | Otimista | Optimistic | 🌟 | 4 | 4 | Confiança de que as coisas vão melhorar ou dar certo. |
| `proud` | Orgulhosa | Proud | 🥹 | 4 | 4 | Satisfação com algo que fez ou com quem você é. Reconhecimento interno. |

---

### 🟢 Quadrante VERDE — Baixa energia, Agradável
`pleasantness: 4–5 | energy: 1–2 | color: #66BB6A`

| id | label (PT) | label_en | emoji | pleasantness | energy | description |
|---|---|---|---|---|---|---|
| `calm` | Calma | Calm | 😌 | 5 | 2 | Estado de equilíbrio e quietude. Nada precisa ser resolvido agora. |
| `content` | Satisfeita | Content | 🙂 | 5 | 2 | Tudo está bem. Sem desejos urgentes, sem preocupações dominantes. |
| `peaceful` | Em paz | Peaceful | 🕊️ | 5 | 1 | Harmonia interna profunda. O corpo está solto, a mente quieta. |
| `serene` | Serena | Serene | 🌿 | 5 | 1 | Calma que vai além da ausência de problemas — é uma presença positiva. |
| `grateful` | Grata | Grateful | 🤍 | 5 | 2 | Reconhecimento do que é bom na vida. Abre o coração para o presente. |
| `relaxed` | Relaxada | Relaxed | 😮‍💨 | 4 | 1 | Tensão liberada. O corpo se solta, a mente desacelera. |
| `comfortable` | Confortável | Comfortable | 🛋️ | 4 | 2 | Bem-estar físico e emocional. Segurança no ambiente e nas relações. |
| `at_ease` | À vontade | At ease | 😴 | 4 | 1 | Sem pressão, sem julgamento. Pode ser você mesma. |
| `balanced` | Equilibrada | Balanced | ⚖️ | 4 | 2 | Sensação de que as partes da vida estão no lugar certo. |
| `loving` | Amorosa | Loving | 🥰 | 5 | 2 | Afeto e conexão fluindo naturalmente — por pessoas, pela vida, por si mesma. |
| `thoughtful` | Reflexiva | Thoughtful | 🌙 | 4 | 2 | Contemplação tranquila. Processando internamente sem pressa. |
| `secure` | Segura | Secure | 🏡 | 4 | 2 | Confiança no momento e nas pessoas ao redor. Sem ameaça percebida. |

---

### 🔵 Quadrante AZUL — Baixa energia, Desagradável
`pleasantness: 1–2 | energy: 1–2 | color: #42A5F5`

| id | label (PT) | label_en | emoji | pleasantness | energy | description |
|---|---|---|---|---|---|---|
| `sad` | Triste | Sad | 😢 | 1 | 2 | Tristeza presente, muitas vezes sem causa clara. O peso do sentimento pede espaço. |
| `depressed` | Deprimida | Depressed | 😞 | 1 | 1 | Tristeza profunda e persistente. Pouca energia, pouco prazer. Merece atenção e cuidado. |
| `hopeless` | Sem esperança | Hopeless | 😔 | 1 | 1 | Dificuldade de enxergar saída ou melhora. O futuro parece distante e pesado. |
| `lonely` | Solitária | Lonely | 🥺 | 1 | 2 | Desejo de conexão que não está sendo satisfeito. Pode acontecer mesmo rodeada de pessoas. |
| `bored` | Entediada | Bored | 😑 | 2 | 1 | Falta de estímulo ou sentido no que está fazendo. Inquietação sem direção. |
| `disconnected` | Desconectada | Disconnected | 🌫️ | 2 | 1 | Sensação de estar fora do próprio corpo ou das situações. Difícil se engajar. |
| `exhausted` | Exausta | Exhausted | 😩 | 1 | 1 | Esgotamento físico e/ou emocional. O corpo e a mente pediram pausa há algum tempo. |
| `discouraged` | Desanimada | Discouraged | 😪 | 2 | 2 | Esforço sem resultado visível. A motivação foi embora, mas não desapareceu. |
| `disappointed` | Decepcionada | Disappointed | 😕 | 2 | 2 | Expectativa que não se realizou. Tristeza misturada com a clareza do que poderia ter sido. |
| `numb` | Anestesiada | Numb | 😶 | 2 | 1 | Ausência de emoção. Pode ser proteção do sistema nervoso diante de algo difícil. |
| `melancholic` | Melancólica | Melancholic | 🌧️ | 2 | 2 | Tristeza suave e contemplativa. Às vezes acompanhada de nostalgia. |
| `defeated` | Derrotada | Defeated | 😓 | 1 | 2 | Sensação de que perdeu uma batalha importante. Difícil enxergar a próxima tentativa. |

---

## PARTE 4 — TELAS E NAVEGAÇÃO

### Bottom Navigation Bar (customizável)

**Configuração padrão (5 slots):**
1. Dashboard (Início) — **fixo, não pode ser ocultado ou movido**
2. Journal
3. Planner
4. Organizers
5. Mais — **fixo, não pode ser ocultado ou movido**

Os slots 2–4 são totalmente customizáveis: adicionar, remover, reordenar. Máximo de 7 slots no total.

**Páginas disponíveis para colocar na barra:** Journal, Planner, Trackers, Archive, Tasks, Projects, People, Goals, Resources, Routines, Habits, Systems, Organizers, e qualquer página futura.

**Como customizar:** Menu Mais → seção "Content" com lista de páginas arrastáveis. Toggle ligado = na barra. Drag reordena. Aplicado imediatamente.

**Design visual:**
- Fixo no bottom. Altura: 49pt (iOS) / 56dp (Android) + bottom safe area inset
- Cada slot: ícone 24pt centralizado + label 10pt abaixo
- Aba ativa: ícone e label na cor accent (roxo escuro). Inativa: cinza
- Separador hairline acima

### Botão Global "Criar" (FAB)

Bottom sheet com abas:
- **Journal** → cria Entry (standard) OU Field Note (toggle) OU PMN (picker de template)
- **Plan** → cria Task, Goal, Calendar Session, Reminder, ou Backlog item
- **Record** → cria Tracking Record para um Tracker
- **Note** → cria Text Note, Outline Note, Collection Note, ou **System**

### Command Center (scroll-up)

Overlay ativado por scroll para cima:
- Campo de busca (auto-focused)
- Seção "Recentes" (últimos 8 objetos abertos)
- Seção "Notas" (últimas 5 notas modificadas)
- Seção "Próximas sessões" (próximas 3 Calendar Sessions)
- Seção "Systems" (3 Systems mais usados como chips de quick-run) ← novo
- Ações rápidas: "Nova entrada", "Nova task", "Novo registro", "Novo System"

---

## PARTE 5 — PADRÕES DE INTERAÇÃO

### Gestos comuns
- Tap → abre detail view
- Long press → multi-select OU menu contextual
- Swipe left → ações rápidas (Delete, Change Stage, Mark Complete)
- Swipe right em Habit/Pact → marca hoje como completo
- Swipe right em System → abre quick-run (Via C)
- Drag and drop (Planner) → mover sessões entre blocos ou dias
- Scroll up → Command Center

### Undo em Delete/Archive
Snackbar com botão "Undo" por 5 segundos após qualquer delete ou archive. Arquivo movido para `_deleted/`. Apagado permanentemente após 30 dias (configurável).

### Organizer Detail View

Ao abrir qualquer Organizador, a detail view agrega dinamicamente:
1. **Properties Section:** propriedades core do frontmatter
2. **Items Section:** objetos do tipo Note linkados (título + preview)
3. **Timeline Section:** objetos com componente temporal, cronologicamente — Tasks (título, stage, prioridade, data), Entries (timestamp, tipo, resumo), Habits/Pacts (status diário, streak/progresso), Tracking Records (data, campos chave)
4. **Children/Sub-organizers Section:** objetos que são eles mesmos Organizadores, linkados a este

---

## PARTE 6 — SISTEMA DE ACTIONS (Habits e Trackers)

Actions são comportamentos automatizados que executam quando um slot de habit é marcado ou um tracking record é completado.

**Eventos de trigger:**
- Completar qualquer slot individual de um habit
- Completar o goal diário de um habit
- Salvar um tracking record

**7 tipos de Action:**
1. `add_tracking_record` — Abre formulário de Tracking Record para um Tracker pré-configurado, pré-populado com a data de hoje
2. `add_entry` — Abre formulário de criação de Entry
3. `add_text_note` — Abre formulário de criação de Text Note
4. `add_collection_item` — Abre formulário para adicionar item em Collection Note especificada
5. `view_statistics` — Navega para a view de estatísticas do habit/tracker
6. `view_item` — Navega para um objeto linkado especificado
7. `launch_url` — Abre URL especificada no browser

**Múltiplas Actions:** Um habit/tracker pode ter várias Actions. Todas disparam na ordem configurada.

**Configuração por slot:** Cada slot pode ter reminder independente E action independente.

---

## PARTE 7 — POMODORO

### Objeto PomodoroSession

**Propriedades:**
- `title`, `linked_item` (WikiLink para qualquer objeto), `date`
- `work_duration` — integer, minutos (default: 25)
- `short_break_duration` — default: 5
- `long_break_duration` — default: 20
- `long_break_after_blocks` — default: 4
- `blocks_completed` — derivado
- `minutes_worked` — derivado
- `minutes_break` — derivado
- `state` — enum: `scheduled` | `active` | `paused` | `completed` | `cancelled`
- `organizers`

**Armazenamento:** Daily note sob `## Pomodoros`:
```markdown
### 09:00 — Trabalho no Projeto Alpha
- Linked: [[projeto-alpha]]
- Blocos: 3
- Tempo trabalhado: 75 min
- Tempo de pausa: 15 min
```

### UI do Timer Ativo

Full-screen overlay:
- Item trabalhado: título no topo (tappable para trocar)
- Countdown circular grande (MM:SS)
- Label de fase: "Trabalhando" / "Pausa curta" / "Pausa longa"
- Indicador de progresso: N círculos (completados = cheios, atual = animado, próximos = vazios)
- Controles: Pausar/Retomar, Parar/Cancelar, Pular fase
- Notificação persistente com Pausar/Retomar, Parar
- Ao completar fase: som e/ou vibração

Ao cancelar: "Parar sessão? Seu progresso (X blocos, Y min) será salvo." Confirmar salva sessão parcial.

Ao concluir: sheet com totais + "Pronto" ou "Mais uma rodada".

### Pomodoro Agendado

1. Planner → "+" em time slot → selecionar "Sessão Pomodoro"
2. Campos: título, linked item, horário, número de blocos, durações (pré-preenchidas)
3. Display calculado: "X h Y min total"
4. Notificação com action button "Iniciar Pomodoro"

---

## PARTE 8 — PEOPLE

**Propriedades:**
- `name`, `photo`, `priority`, `notes`, `links`
- `last_contact_date` — derivado: data da entrada mais recente ou evento que menciona esta pessoa
- `contact_frequency` — duração (ex: "every 2 weeks", "monthly")
- `categories` — auto-inclui `[[people]]`

**Scheduler automático:** Quando `last_contact_date + contact_frequency <= hoje`, o app cria automaticamente uma Task "Contatar [Nome]" com a prioridade da pessoa. Marcar a task: atualiza `last_contact_date` e reseta o scheduler.

**People view:**
- Lista ordenada por urgência (atrasados primeiro, depois por próxima data)
- Cada linha: thumbnail + nome + "Último contato: N dias atrás" + "A cada X" + badge de urgência (verde/amarelo/vermelho)
- Detail view: todas as propriedades + todas as menções do vault

---

## PARTE 9 — RESOURCES

**Entrada:** Principalmente via Obsidian Web Clipper (extensão de browser). O clipper popula title, cover_image, type, synopsis, links, status automaticamente.

**Filtragem configurável (Settings → Resources):**
- Livros: notes onde `status` é um de `to-read`, `reading`, `read`
- Filmes: notes com tag `#movie`
- Séries: notes com tag `#series`
- Podcasts: notes com tag `#podcast`
Usuário pode mudar estas condições a qualquer momento.

**Propriedades:**
- `title`, `cover_image`, `type` (derivado das condições de filtro), `status`, `categories`, `rating` (1-5, exibido como estrelas), `synopsis`, `links`

**Resources view:**
- Filtros: tipo (All/Books/Movies/...) + status (All/To consume/In progress/Completed)
- Sort: prioridade, rating, título, data adicionado
- Cards em grid (2 colunas) ou lista (toggle)
- Cada card: imagem de capa + título + badge de status + chips + rating em estrelas

---

## PARTE 10 — PROJECTS (como Organizador com modelo completo)

**Projects** são um tipo de Organizador com propriedades estendidas:

**Propriedades:**
- `title`, `description`, `state` (active/paused/completed/archived), `priority`
- `start_date`, `due_date` (exibida como "em X dias (12 abr)")
- `progress` — derivado (0.0–1.0) do primary_kpi
- `primary_kpi` — referência a exatamente 1 KPI (drive o % de progresso)
- `secondary_kpis` — array de KPIs adicionais
- `tasks` — array de WikiLinks para Tasks filhas
- `scheduler` — ao configurar: projeto recorre (reinicia) no schedule
- `total_pomodoro_time` — derivado: soma de todos os Pomodoros vinculados
- `quick_access` — array de WikiLinks para qualquer página

**Project detail view:**
- Properties card: State, Priority, Start date, Due date + label relativo, Progress
- Primary KPI: barra grande + valor atual / target
- Secondary KPIs: barras menores
- Tasks: lista com stages. "Adicionar task" cria e vincula
- Quick Access: chips + "+" para adicionar link
- Total Pomodoro Time formatado
- Calendário mensal com atividade
- Mentions section
- Menu ⋯: Edit, Archive, Delete, Open in Obsidian, Take Snapshot

---

## PARTE 11 — COMBINED ANALYSIS

**Propósito:** Agrega dados de múltiplos Trackers e/ou Habits para revelar correlações. Exemplo: correlacionar ciclo menstrual (fluxo, cólica) com humor e medicação.

**Propriedades:**
- `title`, `description`
- `data_sources` — array de DataSourceReference:
  - `source_type` — enum: `tracker_field` | `habit` | `journal_mood`
  - `source_id` — referência ao Tracker, Habit, ou sistema de journal
  - `field_id` — para Trackers: qual InputField específico
  - `color` — cor para esta fonte em todos os gráficos
  - `label` — nome display na legenda
  - `value_mapping` — mapeamento de valores categóricos para numérico (ex: `{leve: 1, médio: 2, forte: 3}`). Configurável pelo usuário. Usado apenas para campos categóricos; campos já numéricos não precisam de mapeamento.
- `charts` — array de Chart configs. Cada chart tem:
  - `type` — enum: `line` | `bar` | `pie` | `calendar`
  - `normalization` — enum: `none` | `dual_axis` | `normalize_0_1`. Default: `dual_axis` quando séries têm escalas diferentes. `normalize_0_1` normaliza cada série para 0–1 via min-max para facilitar comparação de formas de curva.
  - `series` — array de séries, cada uma referenciando uma fonte e opcionalmente uma dimensão (`pleasantness` ou `energy` para `journal_mood`)
- `default_date_range` — opcional

**Como o Combined Analysis resolve a correlação ciclo × humor:**
1. Usuário cria análise com fontes: `journal_mood` + `tracker_field` (tracker: menstruacao, field: fluxo) + `tracker_field` (tracker: menstruacao, field: colica)
2. Para `journal_mood`, o usuário escolhe qual dimensão plotar: `pleasantness`, `energy`, ou ambas como séries separadas
3. Para campos numéricos de tracker (fluxo 0–10, cólica 0–10): eixo esquerdo com escala original
4. Para mood (1–5): eixo direito com `normalization: dual_axis`
5. No gráfico de linha, o emoji do mood aparece como marcador visual em cada ponto da série de mood
6. Calendário mensal: emoji do mood no centro de cada dia + dots coloridos de fluxo e cólica abaixo
7. Para campos categóricos: app aplica `value_mapping` configurado pelo usuário

**Exemplo de chart config:**
```yaml
charts:
  - type: line
    normalization: dual_axis
    series:
      - source: journal_mood
        dimension: pleasantness
        label: "Agradabilidade"
        color: "#34d399"
        axis: right
        show_emoji_markers: true
      - source: tracker_field
        tracker: menstruacao
        field: fluxo
        label: "Fluxo"
        color: "#f472b6"
        axis: left
      - source: tracker_field
        tracker: menstruacao
        field: colica
        label: "Cólica"
        color: "#fb923c"
        axis: left
```

**Visualização:**
- Calendário mensal: emoji do mood por dia + dots coloridos das outras fontes + legenda
- Gráfico de linha: séries sobrepostas com eixo duplo quando escalas diferem. Emoji como marcador nos pontos de mood.
- Navegação de mês com setas prev/next

**Plugins Obsidian (Obsidian Charts plugin):**
```chart
type: line
labels: [2026-05-01, 2026-05-02, ...]
series:
  - title: Cólica
    data: [2, 4, 3, 1, 3]
  - title: Agradabilidade
    data: [4, 3, 3, 4, 4]
width: 80%
beginAtZero: false
```

**Plugin Obsidian Tracker:**
```tracker
searchType: frontmatter
searchTarget: menstruacao.colica
folder: daily
startDate: 2026-04-01
endDate: 2026-05-31
month:
  startWeekOn: Mon
  color: red
  colorByValue: true
```

---

## PARTE 12 — SYNC, OFFLINE E CONFLITOS

### Arquitetura Offline-First com Google Drive
*IMPORTANTE*: O SYNC É FEITO PELO GOOGLE DRIVE, NÃO PELO ONE DRIVE. SEMPRE QUE ACHAR ALGO CITANDO O ONE DRIVE, CORRIJA: **SYNC E CALENDÁRIO SÃO FEITOS PELO GOOGLE!!!** 
**Fluxo de sync:**
- Armazenamento primário: GOOGLE DRIVE (vault = pasta sincronizada com GOOGLE DRIVE)
- Toda mudança é escrita imediatamente no GOOGLE DRIVE se disponível
- Se indisponível: mudança vai para storage local e fila de sync
- Quando GOOGLE DRIVE volta: mudanças fila são empurradas em ordem
- Indicador de status: ícone de nuvem com estados synced/syncing/offline/error

**Resolução de conflito:**
1. Nenhum vencedor silencioso
2. Backup de ambas as versões em `_conflicts/`
3. Notificação in-app com comparação visual dos campos alterados (não raw markdown)
4. Opções: "Manter local", "Manter GOOGLE DRIVE", "Mesclar"
5. Se "mesclar" falhar: resolução campo a campo
6. `_conflicts/` limpo automaticamente após 30 dias

**Backup:** ZIP do vault periódico (configurável: diário/semanal/por abertura). Salvo em `_backups/` no GOOGLE DRIVE ou localmente. Retenção configurável.

---

## PARTE 13 — NOTIFICAÇÕES

Cada objeto com agendamento pode ter notificações. Configurado por objeto, por ocorrência.

**Reminder Configuration:**
- `trigger_time` — "Na hora do evento", "X minutos/horas/dias antes"
- `type` — enum: `push` | `popup` | `alarm`
- `notification_body` — string (default: título do objeto)
- Múltiplos reminders por objeto ("+")

**Por tipo:**
- Push: som, vibração, LED (Android)
- Popup: cor de fundo (color picker), cor do texto (auto)
- Alarm: toque, vibração, "tocar mesmo no silencioso" (default: sim), duração de soneca

**Botões de ação em TODOS os tipos:**
- "Marcar como feito"
- "Soneca" (duração configurável — também editável no momento da notificação)
- "Dispensar"

**Confiabilidade:** Notificações registradas no alarm manager do sistema no momento de criação.

---

## PARTE 14 — ARCHIVE UNIVERSAL

Todo tipo de objeto suporta archiving. Arquivo arquivado ganha `archived: true` no frontmatter. Não apagado.

**Página Archive (Settings → Archive):**
- Lista de TODOS os objetos arquivados, por data de archive (mais recente primeiro)
- Filtro por tipo
- Barra de busca
- Cada linha: ícone do tipo + título + data de archive + botão "Restaurar"
- Tapping na linha (não no botão): abre read-only com banner "Arquivado"

**Archive por seção:** Menu ⋯ do header de cada seção → "Ver arquivados"

---

## PARTE 15 — WIDGETS (Home Screen / Lock Screen)

**4 tipos:**

1. **Quick-add** (2×1): dois botões configuráveis ("Nova entrada", "Nova task", etc.)
2. **Calendar** (4×2 ou 4×4): dots coloridos por tipo. Botão "+" no canto. Tap em item → detail view.
3. **Category** (configurável): lista de itens de um filtro configurável (ex: "Tasks de alta prioridade")
4. **Obsidian Note** (configurável): renderiza conteúdo de uma nota específica. Atualiza quando a nota muda. Útil para daily note de hoje, checklist de referência, resumo de projeto.

**Configuração:** Long-press no widget → sheet de configuração dentro do app.

---

## PARTE 16 — LINKING UNIVERSAL

Todo objeto pode linkar e ser linkado por qualquer outro objeto. Dois formatos:

**Property link:** Propriedade `links` no frontmatter (array de WikiLinks). Na app: seção "Links" na detail view com chips. Tap navega.

**Inline mention:** `[[WikiLink]]` em qualquer rich text. Cria backlink no Obsidian. Detectado e mostrado na seção "Menções" do objeto referenciado.

**Link picker UI:** Digitar `[[` abre picker flutuante:
- Inicial: páginas ordenadas por modificação mais recente
- Filtragem fuzzy por título e aliases
- Cada linha: título + chips das `categories`
- Se título não existe: "Criar nova página: [texto]" no bottom

**Menções/Backlinks em todas as detail views:**
- Header: "Menções (N)" + ícone de link
- Cada menção: ícone do tipo + título + data/hora
- Sem menções: "Sem menções ainda"
- Notas Obsidian não gerenciadas pelo app: ícone Obsidian → abre no Obsidian

---

## PARTE 17 — NAVIGATION HISTORY

**Stack de navegação ilimitado.** Toda transição é registrada.

**Back button:** Em toda tela não-root, seta "‹" no top-left do nav bar. Navega para a tela anterior exata, restaurando posição de scroll e estado de formulário não salvo.

**Breadcrumb trail** (quando stack > 2 níveis): "Habits › Meditar › Tracking Record". Cada breadcrumb é tappable.

**Cross-section navigation:** Back em qualquer ponto retorna exatamente um nível, independente de qual aba o usuário começou.

---

## PARTE 18 — DESIGN VISUAL

### Cores por tipo de objeto (defaults do sistema, substituíveis por instância)

- Entry (standard): neutro/sem accent (usa cor do quadrante do mood se definido)
- Entry (field_note): compact card, accent por categoria (💡 amber, ⚡ green, 😊 blue, 👥 purple)
- Entry (pmn): ícone 3 colunas, accent por seção (+ verde, − vermelho, → azul)
- Task: família azul
- Goal (standard): família roxo
- Goal (plan mode): mesmo do Goal, com seção de phases com borda-esquerda accent
- Habit: cor configurada pelo usuário
- Habit (pact mode): mesma cor do Habit + badge "PACT"
- Tracker: cor configurada pelo usuário
- System: família laranja (distinto de Notes que são cinza/neutro)
- Calendar Session: cor configurada pelo usuário
- Reminder: cinza/neutro

### "Days since" badge em Habits

Cada habit em qualquer listagem e no Planner exibe badge de status de quando foi completado por último.

- `days_since = 0` (completado hoje): pill cinza muted, texto "today" ou "1 day since"
- `days_since >= 1`: pill vermelha (`#E53935`), texto "N days since"
- `never_completed`: "—" ou ausente

Visual: pill pequena, 12pt medium, canto superior direito do card ou elemento trailing na row.

Atualiza automaticamente à meia-noite.

Streak e "days since" são complementares: streak mostra consecutivos, "days since" mostra recência.

### Energy level tints no Planner

- high → `#4CAF50` a 8% opacity
- medium → `#FFC107` a 8% opacity
- low → `#FF7043` a 8% opacity

Toggle persiste por preferência do usuário.

### Color picker

Em toda seleção de cor no app, usar visual color picker (grid de swatches ou color wheel). Nunca input HEX direto.

---

## PARTE 19 — UI FUNDAMENTALS

### Safe Areas e Insets

Todo conteúdo deve respeitar safe areas:
- **Top:** iOS = 44pt (sem notch) ou 47–59pt (notch/Dynamic Island), Android = altura da status bar (~24–28dp). Nav bar começa ABAIXO do inset.
- **Bottom:** iOS Face ID = 34pt home indicator. Tabs e botões acima deste inset, com 16–20pt de padding acima para não ficar colado.
- Usar `SafeAreaView` ou `useSafeAreaInsets()` (React Native), `SafeArea` widget (Flutter), `safeAreaLayoutGuide` (iOS), `WindowInsetsCompat` (Android).

### Back button e Navegação

- **Modais (sheets):** X no canto superior direito. NÃO usar seta de voltar.
- **Telas pushed:** seta "‹" no top-left, dentro do nav bar.
- **Nav bar:** fixo no topo, 44pt iOS / 56dp Android. Contém: back/close (esquerda), título (centro), ação (direita: Done/Save/gear).
- **Done/Save:** texto no top-right OU botão full-width no bottom (roxo escuro, texto branco, pill arredondada, acima do inset inferior).
- **Swipe-to-dismiss:** sheets modais suportam swipe down para dismissar (iOS). Back button do Android dispensa modais.

### Scroll Behavior

- **Fixo no topo:** Nav bar sempre fixo, não scrollável.
- **Fixo no bottom:** Tab bar fixo. Botão CTA de modal fixo no bottom.
- **Área scrollável:** conteúdo entre os dois fixos.
- **Keyboard avoidance:** campo ativo visível acima do teclado. Botão CTA sobe junto com o teclado.
- **Overscroll:** rubber-band iOS, ripple/glow Android.

### Modal Sheets

- **Bottom sheet parcial:** slide de baixo. Overlay dim. Dismiss por tap fora ou swipe down. Handle pill no topo (36pt × 4pt).
- **Full-screen modal:** cobre tela inteira. Nav bar com X. Sem handle. Stacking de modais: cada um escala levemente o anterior (estilo iOS pageSheet).

### Lista e Cards

- **Altura de row:** 48–52pt (uma linha), 60–72pt (com subtitle)
- **Padding horizontal:** 16pt das bordas da tela
- **Separadores:** 1px hairline cinza claro, inset 16pt da esquerda
- **Card border radius:** 12–16pt
- **Touch feedback:** highlight iOS, ripple Android

### Tipografia

- Screen title (nav bar): 17–18pt, semibold, centrado
- Card/item title (primary): 16–17pt, regular/medium
- Subtitle/metadata: 13–14pt, regular, muted
- Section headers: 13–14pt, semibold ou all-caps
- Helper text: 12–13pt, cinza claro
- Button label (CTA): 16–17pt, semibold, branco sobre escuro
- Form field labels: 14–15pt
- Form field values: 15–16pt, underlined ou bordered

### Componentes de Input

- **Radio button:** círculo. Selecionado = círculo preenchido interno na cor accent. Toda a row é tappável. Selecionar novo = deseleciona anterior.
- **Checkbox:** quadrado com cantos arredondados. Preenchido com checkmark na cor accent.
- **Inline integer input:** campo de texto underlined (sem borda), teclado numérico, alinhado à direita.
- **Segmented control:** row de botões de largura igual em container compartilhado. Selecionado = fundo preenchido.
- **Toggle/switch:** iOS-style. Esquerda = off (cinza), direita = on (accent).
- **Tappable value pill:** label em cor accent (indica interatividade). Abre picker.
- **Color swatch grid:** grid de círculos/quadrados preenchidos. Selecionado = checkmark overlay ou ring border.
- **Emoji/icon picker:** grid de emojis. Pesquisável. Sheet modal.
- **Chip/tag selector:** pills pequenas. Selecionada = fundo accent + texto branco. Não selecionada = outline ou cinza claro.

### Empty States

Todo list/content area que pode estar vazio deve ter:
- Ilustração ou ícone centralizado
- Headline 1–2 palavras
- Subtexto 1–2 frases
- CTA button/link para criar primeiro item
- Posicionado verticalmente centrado na área disponível

### Loading e Feedback

- **Salvar:** offline-first = instantâneo. Breve feedback visual ou haptic.
- **Sync indicator:** ícone pequeno na nav bar.
- **Delete:** sempre confirmation alert (vermelho "Delete" + "Cancelar"). Nomeia o item.
- **Haptic:** completar habit (light), completar task (medium), ações destrutivas (warning).

---

## PARTE 20 — VAULT OBSIDIAN: ESQUEMA COMPLETO

### Estrutura de Pastas (default, configurável via Object Identification)

```
vault/
├── app/                  ← Todos os objetos de conteúdo (flat, type no frontmatter)
│   ├── task-*.md
│   ├── goal-*.md
│   ├── habit-*.md        ← inclui pacts (habit_mode: pact)
│   ├── tracker-*.md
│   ├── note-*.md
│   ├── calendar-session-*.md
│   ├── system-*.md
│   ├── social-post-*.md
│   └── organizer-*.md
├── daily/                ← Daily notes + PMN
│   ├── YYYY-MM-DD.md     ← entradas, habit completions, tracker records
│   └── YYYY-MM-WNN.md    ← Plus/Minus/Next (mês = date_range_start; ex: 2026-05-W21.md)
├── inbox/                ← Itens de Inbox (captura crua, não-tipada)
├── analyses/             ← Combined Analysis definitions
├── moods/                ← Mood definition files (criados lazily na primeira vez que o mood é registrado)
├── _attachments/         ← Fotos e arquivos
├── _deleted/             ← Soft delete (purga em 30 dias)
└── _conflicts/           ← Backups de conflito de sync
```

### Frontmatter Universal (todos os objetos)

```yaml
---
id: "unique-id"
type: task  # task|habit|tracker|goal|note|entry|system|calendar_session|reminder|social_post|idea|inbox|shopping_list|mood_definition|area|project|activity|label|person|place
title: "Título"
created_at: 2026-05-19T09:00:00
updated_at: 2026-05-19T14:00:00
archived: false

organizers:
  - "[[area-trabalho]]"
  - "[[projeto-alpha]]"

tags:
  - trabalho

links:
  - "[[system-publicar-instagram]]"
  - "[[task-revisar-copy]]"

# PROPRIEDADES ESPECÍFICAS DO TIPO A SEGUIR
---
```

**Explicitamente ausente:** campo `moc`. Nunca escrever. Se encontrado ao ler: ignorar.

### Daily Note Format (canônico)

```yaml
---
date: 2026-05-19
type: daily_note
tags: [daily]

# Habit completions (habit_mode: habit E habit_mode: pact — mesmo formato)
meditar: true
escrever-100-palavras: true
agua: 6

# Mood do dia (dois eixos + label + emoji — gravados separadamente para permitir queries e correlações)
mood_pleasantness: 4
mood_energy: 3
mood_label: "Calma"
mood_emoji: "😌"

# Tracker records (nested sob slug do tracker)
sono:
  horas: 7.5
  qualidade: boa
menstruacao:
  fluxo: 2
  colica: 1
  tomou_remedio: false
---

# 2026-05-19

## Journal Entries

### 08:30
entry_type: standard
mood:: [[calm]]
organizers:: [[area-saude]]

Acordei com energia hoje.

---

### 09:15
entry_type: field_note
category: insight

Percebi que minha resistência a emails de manhã é proteção do tempo criativo.

---

### 11:00
entry_type: field_note
category: energy
energy_value: 4

Alta energia depois da reunião.

---

## Habits

- [x] Meditar (Slot 1: 08:00)
- [x] Escrever 100 palavras ← pact
- [x] Água (6/8 copos)

## Trackers

### Sono
- **Horas:** 7.5
- **Qualidade:** Boa

### Menstruação
- **Fluxo:** 2
- **Cólica:** 1

## Pomodoros

### 09:30 — Projeto Alpha
- Linked: [[projeto-alpha]]
- Blocos: 3
- Tempo trabalhado: 75 min
- Tempo de pausa: 15 min
```

### PMN File Format

```yaml
---
id: "pmn-2026-W21"
type: entry
entry_type: pmn
week: 2026-W21
date_range_start: 2026-05-18
date_range_end: 2026-05-24
referenced_dates:
  - "2026-05-18"
  - "2026-05-19"
  - "2026-05-20"
  - "2026-05-21"
  - "2026-05-22"
  - "2026-05-23"
  - "2026-05-24"
pact_refs:
  - "[[escrever-100-palavras]]"
organizers:
  - "[[area-escrita]]"
archived: false
created_at: 2026-05-24T18:30:00
updated_at: 2026-05-24T18:30:00
---

## Plus
- Mantive o pact de escrita 6/7 dias
- Consegui bloquear as manhãs para deep work

## Minus
- Admin acumulou na quarta
- Reuniões quebraram o flow na quinta

## Next
- Mover admin para tarde
- Proteger manhã com bloco de foco no calendário
```

### Mapeamento Objeto → Arquivo Obsidian

| Objeto | Localização | Tipo | Backlinks? |
|---|---|---|---|
| Journal Entry (standard) | daily/YYYY-MM-DD.md → ## Journal Entries → ### HH:MM | entry_type: standard | Via mood:: e organizers:: |
| Field Note | daily/YYYY-MM-DD.md → ## Journal Entries → ### HH:MM | entry_type: field_note | Via organizers:: |
| PMN | daily/YYYY-MM-WNN.md | entry_type: pmn | Via pact_refs e referenced_dates |
| Task | app/task-SLUG.md | type: task | Sim |
| Goal (standard/plan) | app/goal-SLUG.md | type: goal | Sim |
| Habit (habit/pact) | app/habit-SLUG.md | type: habit | Sim |
| Tracker | app/tracker-SLUG.md | type: tracker | Sim |
| Tracking Record | Embedded em daily/YYYY-MM-DD.md | Em frontmatter + ## Trackers | Via daily note |
| Text/Outline/Collection Note | app/note-SLUG.md | type: note | Sim |
| Calendar Session | app/calendar-session-SLUG.md | type: calendar_session | Sim |
| Reminder | daily note ou próprio arquivo | type: reminder | Via daily note |
| System | app/system-SLUG.md | type: system | Sim |
| Social Post | app/social-post-SLUG.md | type: social_post | Sim |
| Idea | app/idea-SLUG.md | type: idea | Sim |
| Inbox Item | inbox/YYYY-MM-DD-HH-mm.md | type: inbox | Não (item efêmero, sem seção de menções) |
| Shopping List | app/shopping-list-SLUG.md | type: shopping_list | Sim |
| Event (Google Calendar) | Não persistido — espelho em memória, populado a cada sync | type: event | Não |
| Mood Definition | moods/SLUG.md — criado lazily na primeira vez que o mood é registrado | type: mood_definition | Sim (todas as entradas linkam de volta via mood::) |
| Area/Project/Activity/Label/Person/Place | app/organizer-SLUG.md | type: area/project/etc | Sim |
| Combined Analysis | analyses/SLUG.md | type: analysis | Sim |
| PomodoroSession | Embedded em daily note | Via ## Pomodoros | Via daily note |

### Algoritmo de Parsing (atualizado)

**No startup / sync:**
1. Carregar todos arquivos da pasta configurada (default: `app/`). Ler `type` do frontmatter de cada arquivo. Se Object Identification define pasta por tipo, carregar dessas pastas.
2. Construir mapas de tipo: task_slug → Task, habit_slug → Habit, system_slug → System, etc.
3. Para Habits: ler `habit_mode`. Default: `habit` se ausente.
4. Para Goals: ler `goal_mode`. Default: `standard` se ausente.
5. Carregar todos os `daily/YYYY-MM-DD.md`.
6. Carregar todos os `daily/YYYY-MM-WNN.md` como objetos PMN. Determinar mês de cada PMN por `date_range_start`, não pelo nome do arquivo.
7. Carregar moods `system` em memória. Para moods com arquivo existente em `moods/`, ler `aliases` e `hidden` do arquivo para sobrepor os defaults.

**Por daily note:**
1. Parse do frontmatter YAML. Extrair `date`.
2. Para cada chave que corresponda a um habit_slug (qualquer `habit_mode`): registrar HabitCompletion(slug, date, value).
3. Para cada chave correspondendo a tracker slug: registrar TrackingRecord.
4. Extrair `mood_pleasantness`, `mood_energy`, `mood_label`, `mood_emoji` do frontmatter para o registro de humor do dia.
5. Parse da seção `## Journal Entries`. Para cada `### HH:MM`:
   - Ler `entry_type` (default: `standard`)
   - Para standard: extrair body, mood::, organizers::, tags
   - Para field_note: extrair category, text, energy_value
6. Parse da seção `## Pomodoros` para PomodoroSessions.

**Por PMN file:**
1. Parse do frontmatter. Extrair `week`, `date_range_start`, `referenced_dates`, `pact_refs`.
2. Parse do body: seções `## Plus`, `## Minus`, `## Next` como arrays de bullets.
3. Indexar por cada data em `referenced_dates` para lookup rápido quando usuário abre uma data.

**Criação lazy de arquivo de mood:**
Na primeira vez que o usuário registra um mood `system` (via `mood::` numa entry ou via `mood_label` na daily note), o app verifica se `moods/SLUG.md` existe. Se não existe: cria o arquivo com todos os dados do mood pré-carregado em memória. A partir daí, o arquivo existe no vault normalmente.

**Derivação de histórico de System:**
Para cada System: query de todas Tasks com `linked_system = [[este-system-slug]]`. Contar para `run_count`. Mais recente `created_at` para `last_run`. Média de `timer_sessions` para `average_minutes`.

**Derivação do Energy Map:**
Para cada dia: coletar field_notes com `category: energy` e `energy_value`. Médias por hora do dia. Sugerir `energy_level` para Time Blocks.

**Check de status de Pact:**
A cada abertura: para todos Habits com `habit_mode: pact`, `status: active`, comparar `ends_at` com hoje. Se `ends_at <= hoje` e `pact_outcome = null`: agendar notificação de Steering Sheet.

**Lookup de PMN por data:**
Quando usuário abre qualquer data (Journal, Planner, Timeline): o app busca no índice de PMNs quais têm essa data em `referenced_dates`. Se encontrado: exibe card/link para o PMN correspondente.

### Queries Dataview Exemplos

```dataview
-- Todos os pacts ativos
TABLE ends_at AS "Termina", hypothesis AS "Hipótese"
FROM "app"
WHERE type = "habit" AND habit_mode = "pact" AND status = "active"
SORT ends_at ASC

-- Systems por frequência
TABLE trigger AS "Quando", run_count AS "Execuções", estimated_minutes AS "Estimado"
FROM "app"
WHERE type = "system"
SORT run_count DESC

-- Field Notes de energia do mês
TABLE text AS "Observação", energy_value AS "Energia"
FROM "daily"
WHERE entry_type = "field_note" AND category = "energy"
SORT date DESC

-- Tasks com bloqueio emocional
TABLE title, triple_check.diagnosis AS "Diagnóstico"
FROM "app"
WHERE type = "task" AND triple_check.blocker = "heart"

-- PMNs das últimas 8 semanas
TABLE week, plus, minus, next
FROM "daily"
WHERE entry_type = "pmn"
SORT date DESC
LIMIT 8

-- Goals em modo plan
TABLE objective, strategy
FROM "app"
WHERE type = "goal" AND goal_mode = "plan"

-- Humor tendência — agradabilidade e energia por dia
TABLE mood_pleasantness AS "Agradabilidade", mood_energy AS "Energia", mood_emoji AS "😊", date AS "Data"
FROM "daily"
WHERE mood_pleasantness
SORT file.name ASC

-- Correlação humor × ciclo (DataviewJS)
```dataviewjs
const notes = dv.pages('"daily"').where(p => p.mood_pleasantness && p.menstruacao).sort(p => p.file.name, "asc");
const rows = notes.map(p => [p.file.name, p.mood_emoji, p.mood_pleasantness, p.mood_energy, p.menstruacao?.fluxo, p.menstruacao?.colica]);
dv.table(["Data", "Mood", "Agradab.", "Energia", "Fluxo", "Cólica"], rows);
```

-- Streak de habit (DataviewJS)
```dataviewjs
const folder = "daily";
const habitSlug = "meditar";
const notes = dv.pages(`"${folder}"`).sort(p => p.file.name, "desc");
let streak = 0;
for (const note of notes) {
    if (note[habitSlug] === true) { streak++; } else { break; }
}
dv.paragraph(`Streak atual: **${streak} dias**`);
```
```

---

## PARTE 21 — OBJECT IDENTIFICATION (Configuração Soberana)

Página Settings → Object Identification.

O usuário define o que identifica cada tipo de objeto no vault. Estas definições têm prioridade máxima sobre qualquer default do app.

**Tipos de marcador:**
- **Folder:** arquivos em `tasks/` são type: task
- **Tag:** arquivos com `#habito` são type: habit
- **Property:** arquivos com `type: project` são type: project (propriedade no frontmatter)

**UI da página:**
- Lista de definições por tipo
- Cada definição: tipo do objeto + marcador atual + botão de editar
- Editar: picker de marcador type (Folder/Tag/Property) + campo de valor
- "+" para adicionar nova definição
- Drag para reordenar prioridade (se houver conflito entre definições)

**Comportamento ao detectar conflito:**
Objeto tem atributos apontando para tipos diferentes → badge ⚠️ ao lado do título em todas as telas → aparece na página "Conflitos" (menu Mais) → ao abrir: explicação clara ("Este objeto está na pasta de tarefas mas possui propriedade categoria: area").

**Compatibilidade com Tasks Plugin do Obsidian:**
Tasks em daily notes e nos arquivos de task usam sintaxe do Tasks Plugin: `- [ ] Título da task [due:: 2024-12-31] [priority:: high]`. Isso garante que abrir daily notes no Obsidian mostre as tasks na interface nativa do Tasks Plugin.

**Conflito de migração — Shopping List:** durante a transição do modelo `ShoppingItem` solto (legado) para `ShoppingList` com itens aninhados (canônico, ver Objeto 14), o parser não deve tratar `type: shopping_item` e `type: shopping_list` como o mesmo tipo de objeto. Object Identification deve sinalizar os dois coexistindo na mesma pasta como o mesmo tipo de conflito tratado em "Detecção de conflito" (PARTE 1.1), até a migração ser concluída e `type: shopping_item` ser descontinuado.

---

## PARTE 22 — NOTES ON IMPLEMENTATION (para AI e desenvolvedores)

1. **Sempre ler `habit_mode` antes de renderizar um Habit.** Pact mode precisa de rendering visual diferente (barra de progresso finita, badge PACT, exibição de ends_at). `habit_mode` ausente → tratar como `habit`.

2. **Sempre ler `entry_type` antes de renderizar seção de journal.** Field Notes e PMN precisam de designs de card e layouts de formulário diferentes. `entry_type` ausente → tratar como `standard`.

3. **Sempre ler `goal_mode` antes de renderizar detail view de Goal.** Plan mode adiciona 3 seções. `goal_mode` ausente → tratar como `standard`.

4. **Nunca exibir campos `id` ao usuário.** Toda interface, log e output usa títulos/nomes legíveis por humanos.

5. **Color picker visual obrigatório.** Nunca input HEX direto. Sempre selector visual.

6. **PMN vive em arquivo próprio** (`daily/YYYY-MM-WNN.md`), não na daily note. É indexado por `referenced_dates` e exibido quando o usuário abre qualquer data contida nesse array. O mês de um PMN é sempre determinado por `date_range_start`, nunca pelo nome do arquivo.

7. **Mood como WikiLink** (`mood:: [[calm]]`) nas entries, e como campos separados (`mood_pleasantness`, `mood_energy`, `mood_label`, `mood_emoji`) no frontmatter da daily note. Os dois eixos — `pleasantness` e `energy` — são as dimensões numéricas usadas em gráficos e Combined Analysis. O emoji é exibido como marcador visual nos gráficos de linha e no calendário. A legenda de gráficos usa `label` (PT), nunca emoji.

8. **Moods `system` são criados lazily.** O arquivo `moods/SLUG.md` só é gerado na primeira vez que o usuário registra aquele mood. Antes disso, o mood existe apenas em memória com seus dados pré-carregados. Ao criar o arquivo, gravar todos os campos incluindo `aliases` como campo nativo de aliases do Obsidian.

9. **Aliases de mood são resolução de WikiLink.** `[[feliz]]`, `[[happy]]` e `[[joyful]]` devem todos resolver para o mesmo arquivo se estiverem nos aliases. O app deve respeitar isso no link picker e no parser de `mood::`.

10. **Object Identification é soberana.** O app nunca presume localização por tipo. Sempre lê `type` do frontmatter para determinar o que o objeto é. Ao salvar, usa a pasta/marcador definido na Object Identification.

11. **Sistema de Actions em Habits/Trackers é obrigatório.** 7 tipos, disparados por slot_complete ou day_complete.

12. **Triple Check** não cria arquivo. Escreve bloco no frontmatter da Task existente.

13. **System.run_count e System.last_run** são sempre derivados, nunca escritos diretamente. Calculados a partir de Tasks com `linked_system` igual a este System.

14. **Steering Sheet** é um fluxo de 3 etapas disparado no app quando Pact expira. Escreve resultado em `pact_outcome` e opcionalmente em `ends_at` (Persistir) ou `status` (Pausar). Ciclo anterior vai para `previous_cycles`.

15. **PMN e Triple Check têm ligação direta:** o formulário de criação de PMN deve oferecer opção de batch Triple Check para tasks que estão no mesmo stage há 7+ dias.

16. **Combined Analysis com moods:** ao adicionar `journal_mood` como fonte, o usuário escolhe qual dimensão plotar: `pleasantness`, `energy`, ou ambas como séries separadas. `value_mapping` é usado apenas para campos categóricos de tracker — campos numéricos e mood não precisam de mapeamento, apenas de `normalization` de escala quando necessário.

17. **Idea ≠ Note.** Ao triar um Inbox item como "ideia", criar um `IdeaDefinition` (`type: idea`), nunca uma `Note`. Os dois têm ciclos de vida diferentes — Idea tem `status` evolutivo e fluxo de conversão; Note é referência estática.

18. **Event nunca é gravado no vault.** É populado em memória a cada sync do Google Calendar e descartado/recriado a cada refresh. Calendar Session é a única metade da integração que vira arquivo.

19. **Shopping List é a fonte de verdade para compras**, não `ShoppingItem` solto. Ver Objeto 14 para o plano de migração.

---

## PARTE 23 — UI/UX DETALHADA

---

### 23.1 PICKER DE HUMOR

**Onde aparece:** ao criar/editar Entry standard | painel Dashboard "Como você está?" | ao finalizar Task (campo opcional).

---

**PASSO 1 — Seleção de quadrante**

Apresentação: bottom sheet de ~50% da tela. Handle pill no topo (36×4pt, cinza claro, centrado, 8pt do topo). Animação: slide de baixo para cima com spring.

**Título:** "Como você está agora?" — 17pt semibold, centrado, 20pt abaixo do handle.

**Grade 2×2:** ocupa a maior parte do sheet, 16pt de margem de cada lado, 8pt de gap entre quadrantes.

Cada quadrante é um botão tappável:
- Fundo: cor do quadrante a 15% de opacidade
- Borda: cor do quadrante a 30%, 1pt, border radius 16pt
- Padding interno: 16pt
- Conteúdo (de cima para baixo):
  - Emoji grande do quadrante (32pt), alinhado ao topo-esquerdo
  - Label de energia (12pt semibold, cor do quadrante): "Alta energia" ou "Baixa energia"
  - Label de agradabilidade (12pt semibold, cor do quadrante): "Agradável" ou "Desagradável"
  - Exemplos de moods (11pt regular muted itálico): 2–3 palavras separadas por " · "
- Estado pressed: fundo a 25% de opacidade (feedback visual)

Layout visual dos quadrantes:
```
┌──────────────────┬──────────────────┐
│ 🔴               │ 🟡               │
│ Alta energia     │ Alta energia     │
│ Desagradável     │ Agradável        │
│ Raiva · Ansied.  │ Alegria · Entus. │
├──────────────────┼──────────────────┤
│ 🔵               │ 🟢               │
│ Baixa energia    │ Baixa energia    │
│ Desagradável     │ Agradável        │
│ Tristeza · Tédio │ Calma · Paz      │
└──────────────────┴──────────────────┘
```

Legenda de eixos abaixo da grade: "↑ ENERGIA" (12pt muted, alinhado à esquerda) e "AGRADÁVEL →" (12pt muted, alinhado à direita). Espaçamento 8pt abaixo da grade.

Tap em qualquer quadrante → transição de slide horizontal para o Passo 2 (o sheet aumenta de altura com animação spring se necessário).

---

**PASSO 2 — Seleção do mood específico**

Navegação interna no sheet:
- "‹ Voltar" (accent, 15pt) no topo esquerdo → volta ao Passo 1
- Título do quadrante selecionado no centro (15pt semibold, cor do quadrante)
- Separador hairline abaixo

**Campo de busca:** sempre visível, logo abaixo da nav interna. Fundo surface2, border radius 10pt, padding 10pt, ícone de lupa (16pt, muted) à esquerda, "✕" para limpar à direita quando há texto. Placeholder "Buscar humor...". Busca em tempo real (debounce 150ms) em `label`, `label_en` e `aliases`.

**Grade de pills:** abaixo do search, 12pt de padding lateral, 8pt de gap.

Cada pill:
- Fundo: cor do quadrante a 12% de opacidade
- Borda: cor do quadrante a 25%, 1pt, border radius 20pt (pill shape)
- Conteúdo: emoji (20pt) + label em português (14pt medium), padding 10pt vertical 14pt horizontal
- Mínimo 44pt de altura para touch target
- Estado selecionado: fundo cor do quadrante 100%, texto branco, sem borda, shadow leve

Ao selecionar uma pill: a pill entra no estado selecionado e uma **área de description** aparece abaixo da grade com animação de slide down + fade in (200ms ease-out):
- Fundo: cor do quadrante a 8% de opacidade
- Border radius 12pt, padding 14pt, 12pt de margem lateral
- Layout: emoji (28pt, alinhado ao topo) à esquerda com 12pt de gap | à direita: label (16pt semibold) na primeira linha + description (14pt regular muted, line-height 1.5) abaixo
- Ao selecionar outra pill: a description anima para o novo conteúdo (fade cross)

**Ao final da lista de pills** (após todos os moods do quadrante):
- Separador hairline
- Botão "＋ Adicionar minha própria emoção" — texto accent, 15pt, centrado, padding 16pt vertical
- Tap → fecha picker e abre formulário de criação de mood `user` (ver 23.2)

**Botão de confirmação:** full-width, bottom do sheet, acima do safe area inset, 16pt de padding acima.
- Com mood selecionado: fundo roxo escuro, texto branco "Salvar humor", 17pt semibold, border radius 14pt
- Sem mood selecionado: fundo cinza claro, texto cinza "Selecione um humor", disabled (não interativo)

**Remoção de mood:** se a entry já tem mood, a pill correspondente aparece no estado selecionado ao abrir. Tap nela → deseleciona, description desaparece, botão muda para "Remover humor" (fundo vermelho suave, texto branco).

---

### 23.2 FORMULÁRIO DE CRIAÇÃO DE MOOD `user`

**Acesso:** "＋ Adicionar minha própria emoção" no picker | Settings → Mood → "＋" no top-right.

**Apresentação:** full-screen modal. Nav bar com X (top-left, cancelar) + título "Novo humor" (centro) + "Salvar" (top-right, accent, disabled até nome preenchido).

**Campos em ordem vertical (scroll):**

**1. Nome**
- Label "Como você chama esse estado?" — 14pt semibold, 20pt acima do campo
- Text field full-width: fundo surface2, border radius 10pt, padding 14pt, 15pt, placeholder "Ex: Flow, Nostálgica, Concentrada"
- Helper: "Esse nome vai aparecer no picker e nos seus registros." — 12pt muted, 6pt abaixo do campo

**2. Emoji**
- Label "Emoji" — 14pt semibold
- Row: quadrado preview 48×48pt (border radius 12pt, fundo surface2, emoji 28pt centralizado) + "Escolher emoji" (texto accent, 15pt, 16pt à direita do quadrado)
- Tap em qualquer um dos dois → sheet modal de Emoji Picker (grid de emojis pesquisável por nome em PT e EN, 6 colunas, 40pt por célula)

**3. Quadrante**
- Label "Como você se sente?" — 14pt semibold
- Grade 2×2 de radio buttons, mesma estrutura visual do Passo 1 do picker mas menor (padding 12pt interno, border radius 12pt)
- Selecionado: fundo 100% da cor, texto branco
- Selecionar quadrante define automaticamente valores base de `pleasantness` e `energy`

**4. Ajuste fino** (aparece com slide down após selecionar quadrante, 200ms ease-out)
- Título "Ajuste fino" — 13pt semibold muted all-caps
- **Slider Agradabilidade:**
  - Label "Agradabilidade" — 14pt
  - Extremos: "Menos agradável" (esquerda, 12pt muted) e "Mais agradável" (direita, 12pt muted)
  - Slider com thumb em accent. Range limitado ao quadrante selecionado (ex: verde: 4–5).
  - Pill numérica flutuante acima do thumb mostrando valor atual (ex: "4/5")
- **Slider Energia:** mesmo visual, label "Energia", extremos "Menos energia" / "Mais energia"
- 12pt de gap entre os dois sliders

**5. Descrição**
- Label "Descreva esse estado (opcional)" — 14pt semibold
- Text area: border radius 10pt, padding 14pt, mínimo 3 linhas visíveis, expansível. Placeholder "Como você costuma se sentir quando está assim? O que seu corpo faz?"
- 14pt

**6. Aliases**
- Label "Outros nomes para esse estado" — 14pt semibold
- Chip input: campo de texto inline com chips das tags já adicionadas. Digitar + "," ou Enter adiciona chip. Cada chip: pill com ícone X para remover. Placeholder "Ex: alegria, felicidade, contente"
- Helper: "Você pode buscar esse humor por qualquer um desses nomes." — 12pt muted

**7. Cor**
- Label "Cor" — 14pt semibold
- Grid de swatches circulares: 20pt diâmetro, gap 8pt, 6 por linha. Cor do quadrante selecionado já marcada com checkmark branco. Scroll horizontal se houver mais cores. Nunca input HEX.

**Botão Salvar:** full-width, bottom, acima do safe area. Roxo escuro, branco, "Salvar humor". Disabled se nome vazio.

---

### 23.3 GERENCIAMENTO DE MOODS (Settings → Mood → Mood Levels)

**Apresentação:** tela pushed. "‹ Configurações" no top-left. Título "Níveis de humor" no centro. "＋" (accent) no top-right para criar mood `user`.

**Estrutura:** 4 seções colapsáveis, uma por quadrante, na ordem: 🔴 Vermelho → 🟡 Amarelo → 🟢 Verde → 🔵 Azul.

**Header de cada seção:**
- Barra vertical colorida à esquerda (4pt wide, cor do quadrante, altura total do header)
- Label do quadrante: "Alta energia · Desagradável" — 13pt semibold
- Contagem: "10 de 12 visíveis" — 12pt muted, trailing
- Chevron ›/∨ para collapse/expand — 16pt muted

**Cada row de mood:**
- Altura: 56pt
- Leading: emoji (24pt) + label PT (16pt medium) + label EN em parênteses (13pt muted) — apenas system
- Trailing: toggle iOS-style (on = cor do quadrante, off = cinza)
- Badge "meu" nos moods `user`: pill 10pt outline na cor do quadrante, "meu" em 10pt
- Separador hairline entre rows (inset 16pt da esquerda)

**Tap em qualquer row** → bottom sheet de detalhes:

Para moods `system`:
- Handle pill no topo
- Header: emoji (40pt) + label PT (20pt semibold) + label EN (14pt muted)
- Seção "Descrição": texto em 14pt, padding 16pt
- Seção "Quadrante": chip visual colorida + nome do quadrante
- Seção "Valores": "Agradabilidade: N/5 · Energia: N/5" — 14pt
- Seção "Aliases": chips editáveis em row. "＋ Adicionar alias" (texto accent, 13pt) ao final. Tap em chip → edit inline (field substituindo o chip). X para remover. Salva automaticamente ao confirmar.
- Seção "Visibilidade": toggle com label "Mostrar no picker" + descrição "Ocultar não apaga seus registros." — 13pt muted
- Nota ao fundo: "Moods do sistema não podem ser editados. Você pode adicionar aliases e ocultar." — 12pt muted, centrado

Para moods `user`:
- Mesmas seções, mas todos os campos são editáveis via tap (abre editor inline ou picker correspondente)
- Botão "Excluir humor" no bottom: texto vermelho, 16pt, full-width outline border radius 12pt. Confirmation alert: "Excluir [label]? Registros históricos são mantidos, mas o humor não aparecerá mais no picker." — "Excluir" (vermelho) + "Cancelar"

**Drag para reordenar:** handle ≡ no leading de moods `user` (moods `system` sem handle, ordem fixa dentro do quadrante). Moods `user` podem ser posicionados em qualquer ordem dentro do quadrante.

**Empty state de quadrante (todos hidden):** ícone de olho fechado + "Nenhum humor visível neste quadrante" + link "Reativar todos" (accent).

---

### 23.4 COMBINED ANALYSIS — GRÁFICO DE LINHA E CALENDÁRIO

**Detail view:**

Nav bar: "‹ Análises" + título + "⋯" (Editar | Compartilhar | Excluir).

**Seletor de período:** row de chips scrollável horizontalmente. "2 sem" | "1 mês" | "3 meses" | "6 meses" | "1 ano" | "Personalizado". Ativo: fundo accent, texto branco, border radius 20pt. Inativo: outline na cor da borda, texto muted.

**Legenda:** grid de chips abaixo do seletor. Cada chip:
- Linha de cor (18×3pt, border radius 2pt): sólida para trackers, tracejada para mood
- Label da série (13pt medium)
- Escala entre parênteses: "(0–10)" ou "(1–5)" — 11pt muted
- Tap no chip → toggle de visibilidade da série no gráfico (chip fica a 40% de opacidade quando oculto)

---

**GRÁFICO DE LINHA**

Container: card surface, border radius 18pt, padding 18pt. Título "SÉRIE TEMPORAL" — 13pt semibold muted all-caps, 14pt abaixo do topo do card.

Área do gráfico (altura 200pt):
- **Eixo Y esquerdo (trackers):** labels numéricos da escala do tracker (0 a 10 ou o range do campo). Fonte monospace 10pt muted. Largura fixa 28pt. Alinhado à direita.
- **Eixo Y direito (mood):** labels 1 a 5. Fonte monospace 10pt muted. Largura fixa 24pt.
- **Eixo X:** labels de data a cada 5 dias (adaptar ao período selecionado). Monospace 9pt muted. Altura 20pt.
- **Grid lines horizontais:** 1px, rgba(255,255,255,0.06) ou rgba(0,0,0,0.04) dependendo do tema. Uma por intervalo de eixo.

**Séries de tracker (fluxo, cólica):**
- Linha sólida, 2pt, cor configurada, lineJoin round, lineCap round
- Fill sob a linha principal (maior destaque): gradiente vertical, cor a 18% topo → 0% base
- Dots nos pontos de dados do período menstrual (dias com fluxo > 0): 5pt radius, cor sólida

**Séries de mood:**
- Linha tracejada (dash 5pt, gap 4pt), 2pt, cor configurada
- Em cada ponto de dado: **emoji do mood** como marcador, em vez de dot geométrico
  - Emoji: 16pt
  - Fundo circular por trás do emoji: 22pt diâmetro, cor surface (branco ou cinza escuro dependendo do tema), border radius 50%, z-index acima das outras linhas — garante legibilidade sobre outras séries
  - Posicionado: centro horizontal = ponto X do dado; base do fundo circular = Y do dado
  - Se dois emojis no mesmo dia se sobreporiam (distância < 20pt): empilhar verticalmente com 3pt de gap, mais recente acima
  - Dia sem registro de mood: nenhum marcador; linha interpola linearmente entre os pontos existentes

**Tooltip ao tocar/arrastar (mobile: touch move):**
- Card flutuante: fundo surface2, borda border, border radius 10pt, padding 10pt 14pt, shadow 0 4pt 16pt rgba(0,0,0,0.2)
- Posicionado: acima do toque se há espaço; abaixo se o toque está no terço superior do gráfico; deslocado horizontalmente para não sair da tela
- Linha vertical guia: 1px accent a 40% de opacidade, do topo ao eixo X, na posição X do toque
- Conteúdo do tooltip:
  - Data em negrito (14pt) — ex: "19 mai"
  - Uma row por série com dados naquele dia: dot colorido (8pt) + label + valor formatado — ex: "● Fluxo · 7/10"
  - Se mood no dia: row especial com emoji (20pt) + label do mood em negrito + "· Agradabilidade 4 · Energia 3" em muted

---

**CALENDÁRIO DA COMBINED ANALYSIS**

Container: card surface, border radius 18pt, padding 18pt. Título "CALENDÁRIO" — 13pt semibold muted all-caps.

Nav de mês: row com "‹" (button 44pt, texto muted 20pt) + "Maio 2026" (15pt semibold, centro) + "›" (button 44pt).

Header de dias: D S T Q Q S S — 10pt semibold muted all-caps, altura 24pt, gap proporcional.

**Grade de dias:** 7 colunas × 5 ou 6 linhas. Gap 3pt entre células.

**Cada célula de dia:**
- Aspect ratio 1:1, border radius 10pt, padding 3pt
- **Número do dia:** 9pt medium muted, topo da célula, centralizado
- **Emoji do mood:** 16pt, vertualmente centralizado no espaço restante da célula
  - Se sem registro de mood: "–" em 10pt muted ou espaço vazio
  - Se múltiplos registros no dia: exibir emoji do registro mais recente
- **Dots de tracker:** row de dots abaixo do emoji, centralizada, gap 2pt
  - Um dot por fonte de tracker com dados naquele dia
  - Dot: 4pt diâmetro, cor da série configurada
  - Opacidade proporcional ao valor: min 35%, max 100% (ex: fluxo 0 → sem dot; fluxo 5 → 65%; fluxo 10 → 100%)
  - Máximo 4 dots visíveis; se mais: substituir o 4º por "+" em 8pt muted
- **Fundo da célula (heatmap):** cor da série principal (fluxo, tipicamente) a 6–12% de opacidade proporcional ao valor. Cria heatmap visual do ciclo sem legenda adicional.
- Estado hoje: borda 1pt accent, fundo accent a 10%
- Estado futuro (sem dados): opacidade 40% no número do dia

**Tap numa célula:**
Abre mini bottom sheet (altura ~35% da tela, handle pill) com:
- Data completa formatada (17pt semibold) — ex: "Segunda, 19 de maio"
- Se mood: emoji grande (32pt) + label do mood (17pt semibold) + "Agradabilidade N · Energia N" (14pt muted)
- Para cada tracker com dados: nome do tracker (13pt semibold muted all-caps) + valor formatado (15pt)
- Link "Ver entradas deste dia →" (accent, 14pt) que navega para a daily note correspondente
- Se nenhum dado: "Nenhum dado registrado neste dia" (14pt muted, centralizado)

---

**CARD DE INSIGHT**

Container: borda-esquerda 3pt verde (#4CAF50 ou tom de accent), fundo verde a 5% opacidade, border radius 12pt, padding 16pt, 16pt abaixo do calendário.
- Ícone 💡 (22pt, alinhado ao topo) à esquerda com 12pt de gap
- Texto gerado automaticamente à direita: 14pt, line-height 1.5. Bold nos valores numéricos de destaque.
- Exemplos: "Nos dias com **fluxo acima de 6**, sua agradabilidade cai em média **1.8 pontos**." / "Seu pico de cólica coincide com os **emojis mais negativos** do mês."

Insights calculados a partir dos dados: correlação simples (pearson) entre séries + identificação de picos e vales coincidentes.

---

### 23.5 TRIPLE CHECK — BOTTOM SHEET

**Triggers:**
1. Menu ⋯ da Task → "Por que estou evitando isso?"
2. Tap no badge ⚠ no card da Task (aparece após 7 dias no mesmo stage sem progresso)
3. Formulário de PMN → seção "Tasks paradas" → seleção batch

**Apresentação:** bottom sheet de ~70% da tela. Handle pill no topo. Não dismissível por swipe enquanto o diagnóstico não for salvo — tentar fechar faz o sheet vibrar sutilmente (haptic light + animação de shake horizontal pequeno).

**Header do sheet:**
- Título "Triple Check" — 17pt semibold, centrado
- Subtítulo: nome da task — 14pt muted, truncado a 1 linha, centrado
- Separador hairline, 12pt abaixo do subtítulo

**Três perguntas** (em ordem vertical, padding 20pt horizontal):

Cada pergunta:
- Row de ícone (28pt) à esquerda + texto da pergunta (15pt medium) à direita do ícone, alinhamento vertical ao topo
- Ícones: 🧠 (A tarefa faz sentido agora?) | ❤️ (Você está animada com isso?) | 🖐 (Você tem o que precisa pra começar?)
- Abaixo, em 8pt de gap: 3 radio buttons em row horizontal — "Sim" | "Incerto" | "Não"
  - Cada radio: círculo 20pt + label 14pt, gap 6pt entre círculo e label, 16pt entre os 3 radios
  - Touch target de toda a área (círculo + label): mínimo 44pt de altura
  - Estado selecionado: círculo preenchido accent, label em negrito
  - Default: nenhum selecionado
- Separador hairline 16pt abaixo de cada pergunta, exceto a última

**Área de diagnóstico** (abaixo das 3 perguntas):

Aparece com slide down + fade in (200ms) quando ao menos 1 resposta é selecionada.

Container: borda-esquerda 3pt accent, fundo accent a 6% opacidade, border radius 12pt, padding 14pt, 16pt de margem horizontal.

Conteúdo em tempo real:
- Sem respostas suficientes: "Responda as perguntas acima para ver o diagnóstico." — 14pt muted itálico
- Com respostas parciais: texto parcial + "..." indicando que aguarda mais respostas
- Com todas as 3 respostas: texto completo do diagnóstico (14pt, line-height 1.5) + botões de ação contextuais

**Botões de ação contextuais** (dentro do container de diagnóstico):
- Pills com borda accent, texto accent, 13pt medium, border radius 20pt, padding 8pt horizontal 14pt vertical, 8pt de gap entre botões
- Por combinação de respostas:
  - head false/incerto: "Reformular" + "Arquivar"
  - heart false/incerto: "Criar subtasks" + "Adiar"
  - hand false/incerto: "Adicionar dependência" + "Pedir ajuda"
  - todos true: "Ver dependências" + "Verificar agenda"
  - múltiplos false: botões de todas as dimensões afetadas, máximo 3 botões visíveis

**Botão "Salvar diagnóstico":**
- Full-width no bottom do sheet, acima do safe area inset, 16pt de padding acima
- Roxo escuro, texto branco "Salvar diagnóstico", 17pt semibold, border radius 14pt
- Disabled (cinza) até as 3 perguntas serem respondidas
- Ao salvar: haptic medium, sheet fecha com animação de slide para baixo

**Após salvar:**
Card da Task recebe ícone muted no canto inferior esquerdo: 🧠 (head false), ❤️ (heart false), 🖐 (hand false), ou os três empilhados horizontalmente se múltiplos (ícones 14pt, muted, gap 2pt). Tappável → abre resultado em read-only (mesmo layout do sheet, sem campos interativos, com botão "Re-executar diagnóstico" no bottom em outline accent).

**Modo batch (via PMN):**
Lista de tasks com 7+ dias paradas. Cada row: checkbox + nome da task + "N dias parada" (muted). Ao confirmar seleção, Triple Check abre para a 1ª task selecionada. Indicador de progresso no topo do sheet: "Task 2 de 5" (13pt muted centrado). Ao salvar, avança automaticamente para a próxima.

---

### 23.6 STEERING SHEET — FLUXO DE REVISÃO DO PACT

**Trigger:** notificação push quando `ends_at <= hoje` e `pact_outcome = null`. Action button "Revisar pacto" → abre app no Steering Sheet. Também via detail view do Pact → banner amarelo "Este pacto terminou em [data]. Revisar agora." + botão accent.

**Apresentação:** full-screen modal. Nav bar: X (top-right) com confirmation "Você pode revisar depois. Seu pact ficará pausado até então." — "Sair" + "Continuar revisão". Título "Revisão do Pacto" (centro, 17pt semibold). Indicador de progresso: 3 dots lineares no centro abaixo do título (dot ativo: preenchido accent, 8pt; inativo: outline, 6pt; gap 6pt).

---

**ETAPA 1 — Revisão**

Conteúdo scrollável, padding 20pt horizontal, 32pt top.

Título da etapa: "O que aconteceu?" — 22pt semibold.

Card de contexto (12pt abaixo do título): fundo surface2, border radius 16pt, padding 16pt.
- Label "SUA HIPÓTESE ERA" — 11pt semibold muted all-caps, 8pt abaixo
- Texto da hypothesis em itálico (15pt, line-height 1.5)

Campo de relato (16pt abaixo do card):
- Label "Conte o que aconteceu:" — 14pt muted, 8pt acima do campo
- Text area: border radius 12pt, padding 14pt, borda 1px surface2, mínimo 5 linhas visíveis, expansível automaticamente com o conteúdo digitado, 15pt
- Placeholder: "O que funcionou? O que não funcionou? Surpresas?"

Botão "Continuar →" full-width no bottom, acima do safe area. Roxo escuro, branco, 17pt semibold. Disabled se text area vazia.

---

**ETAPA 2 — Reflexão**

Título da etapa: "O que você aprendeu?" — 22pt semibold.

Seção "Sobre sua hipótese:" (label 13pt semibold muted all-caps):
3 radio buttons em coluna:
- ○ Minha hipótese estava correta
- ○ Minha hipótese estava incorreta
- ○ Ainda não tenho certeza

Seção "Por que o pacto terminou?" (16pt abaixo, label 13pt semibold muted all-caps):
3 radio buttons em coluna:
- ○ Concluí o objetivo
- ○ Virou obrigação
- ○ Quero ajustar o escopo

Cada radio: row inteira tappável (44pt altura mínima). Círculo 20pt + label 15pt, 12pt de gap. Separador hairline entre rows. Selecionado: círculo preenchido accent.

Botão "Continuar →" no bottom. Disabled até 1 radio de cada seção selecionado.

---

**ETAPA 3 — Decisão**

Título "O que vem a seguir?" — 22pt semibold.

3 cards de opção em coluna, 12pt de gap, 20pt de padding horizontal:
- Border radius 16pt, padding 16pt, borda 1px cinza claro (surface2)
- Selecionado: borda accent 2px, fundo accent a 6%
- Touch target: card inteiro

**Card PERSISTIR:**
- Badge "PERSISTIR" — 11pt semibold all-caps, cor accent, pill fundo accent a 10%, border radius 20pt, padding 3pt 10pt
- Título "Continuar o pacto" — 17pt semibold, 6pt abaixo do badge
- Row inline abaixo: "Por mais" + campo integer underlined (teclado numérico, 30pt de largura, valor default = duração original do ciclo) + "dias" — 15pt

**Card PAUSAR:**
- Badge "PAUSAR" — mesmo estilo mas cor cinza muted
- Título "Encerrar por ora" — 17pt semibold
- Subtítulo "Você pode retomar a qualquer momento." — 14pt muted, 4pt abaixo

**Card PIVOTAR:**
- Badge "PIVOTAR" — cor laranja/amber (#F59E0B)
- Título "Ajustar o pacto" — 17pt semibold
- Subtítulo "Modifica título, hipótese e duração." — 14pt muted

Campo de aprendizado (16pt abaixo dos cards):
- Label "O que você vai levar desse ciclo? (opcional)" — 14pt muted
- Text area 3 linhas, placeholder "Uma frase sobre o que aprendeu."

Botão de ação full-width no bottom (acima do safe area). Texto adaptado ao card selecionado:
- Persistir: "Renovar por X dias"
- Pausar: "Encerrar pacto"
- Pivotar: "Ajustar pacto"
Disabled até card selecionado.

**Resultados:**
- **Persistir:** `ends_at` atualizado, ciclo → `previous_cycles`, `pact_outcome: persist`. Snackbar "Pacto renovado por X dias." Modal fecha.
- **Pausar:** `status: paused`, `pact_outcome: pause`. Snackbar "Pacto pausado. Retome quando quiser." Modal fecha.
- **Pivotar:** modal fecha e abre formulário de edição do Pact pré-preenchido. Ciclo → `previous_cycles`.

---

### 23.7 SYSTEM — DETAIL VIEW E EXECUÇÃO

**Detail view:**

Nav bar: "‹ Systems" + título + "⋯" (menu: Editar | Salvar como System a partir de Task | Arquivar | Deletar | Abrir no Obsidian).

**Stats row:** row scrollável horizontalmente, 16pt padding, gap 8pt entre chips.
Cada chip: fundo surface2, border radius 20pt, padding 8pt 14pt.
- ícone (16pt muted) + valor (14pt semibold) + label (12pt muted) — ex: "▶ 12 execuções"
- Chips: "▶ N execuções" | "⏱ Estimado: Xmin" | "📊 Média real: Xmin" (só se run_count > 0) | "🕐 Último: há N dias" (só se run_count > 0)

**Seção TRIGGER:**
Label "QUANDO USAR" — 12pt semibold muted all-caps, 16pt de padding horizontal.
Card: fundo surface2, border radius 12pt, padding 14pt, 12pt de margem horizontal.
Texto do trigger em 15pt, line-height 1.5. Ícone de gatilho (⚡ ou similar, 16pt muted) à esquerda, 10pt de gap.

**Seção PASSOS:**
Label "PASSOS" — 12pt semibold muted all-caps + "X passos · Estimado: Xmin" (12pt muted, trailing).

Lista numerada. Cada step:
- Row: número (14pt semibold muted, largura 24pt, alinhado à direita) + texto do step (15pt, flex) + estimativa (13pt muted, trailing: "2 min")
- Altura mínima 44pt
- Se tiver substeps: chevron "›" (14pt muted) antes da estimativa. Tap → expande inline com animação slide down
- Substeps expandidos: lista interna indentada 32pt da esquerda. Cada substep: bullet "·" (13pt muted) + texto (14pt). Border-left 2px cor accent a 30%

**Seção HISTÓRICO** (só se run_count > 0):
Label "HISTÓRICO" — 12pt semibold muted all-caps.

Lista das Tasks geradas, cronologia reversa, máximo 5 visíveis + "Ver todas (N)" se mais.
Cada row: ícone task (16pt, cor azul) + título da task (15pt) + data relativa (13pt muted, trailing).
Subtítulo (13pt muted): duração total de Pomodoro + badge de stage (pill 11pt, cor por stage).
Tap → navega para a Task.

**Seção NOTAS:**
Label "NOTAS" — 12pt semibold muted all-caps.
Body renderizado como rich text, 15pt, line-height 1.6.

**CTA:** botão "▶ Executar" full-width, acima do safe area inset, 16pt padding acima. Roxo escuro, branco, 17pt semibold.

---

**BOTTOM SHEET DE EXECUÇÃO (Via A)**

Slide de baixo. Handle pill. Título "Executar: [nome do System]" — 15pt semibold.

Campos (em coluna, 16pt padding horizontal, 12pt gap):
- "Título da task" — text field, pré-preenchido com nome do System, editável, 15pt
- "Organizadores" — chip selector (busca e seleciona do vault), chips em row com X para remover
- "Data" — row com "📅" + valor tappável em pill accent (abre date picker inline), default: hoje
- "Hora" — row com "⏰" + valor tappável em pill accent (abre time picker), default: vazio

Preview dos steps:
- Label "PASSOS QUE SERÃO CRIADOS" — 11pt semibold muted all-caps
- Lista dos primeiros 3 steps (texto truncado a 1 linha, 14pt muted)
- "＋ X passos adicionais" se houver mais (texto accent, 13pt, tappável para expandir)

Botão "Criar task" full-width no bottom. Roxo escuro.

Após criar: sheet fecha com haptic medium. Snackbar "Task criada" + botão "Abrir" em accent.

---

**BOTTOM SHEET QUICK-RUN (Via C)**

Sheet de ~80% da tela. Handle pill. Header:
- Título "Executar: [nome]" — 15pt semibold
- Subtítulo "Modo rápido · sem criar task" — 12pt muted
- Barra de progresso linear: fundo surface2, cor accent, border radius 4pt, altura 4pt, 16pt de margem, 8pt abaixo do subtítulo. Progresso = steps concluídos / total.

Checklist dos steps (scrollável):
- Cada step: row de checkbox (22pt) + texto do step (15pt) + estimativa (13pt muted, trailing)
- Checkbox: quadrado arredondado 22pt. Desmarcado: borda 1.5px cinza. Marcado: fundo accent, checkmark branco, animação de scale 0.8→1 (150ms spring).
- Ao marcar: texto do step fica muted + riscado, row fica a 60% de opacidade
- Substeps: expansíveis via tap no row, lista indentada 28pt, bullets "·"
- Separador hairline entre steps

Botão "Concluir" full-width no bottom (disabled até todos marcados). Roxo escuro.
Botão "Cancelar" abaixo do principal: texto vermelho suave, 15pt, centrado.

Ao concluir: `run_count` incrementa, haptic medium, snackbar "Concluído em X min." Sheet fecha.

---

### 23.8 ORGANIZER DETAIL VIEW

**Apresentação:** tela pushed. Nav com "‹ [nome da seção anterior]" + título do organizador + "⋯".

---

**Properties Section**

Card surface, border radius 16pt, padding 16pt, 16pt de margem, no topo.

Exibe propriedades core relevantes para o tipo. Cada propriedade:
- Label (12pt semibold muted all-caps) acima do valor
- Valor (15pt) abaixo, editável via tap (abre editor inline ou picker)

Por tipo:
- **Area:** nome, description, ícone
- **Project:** state (badge colorida: active=verde, paused=amarelo, completed=cinza), priority (badge), start_date, due_date ("em X dias — 12 abr"), progress (barra linear 8pt com %, fundo surface2, cor = cor do projeto)
- **Habit:** status badge, streak (número + "dias"), days since badge, habit_mode badge ("PACT" se aplicável)
- **Goal:** status, KPI principal (barra + %)

---

**Items Section (Notes linkadas)**

Header row: "NOTAS" (12pt semibold muted all-caps) + contagem (12pt muted, trailing) + "Ver todas" (accent, 13pt) se > 5.

Lista de Notes com WikiLink para este organizador. Cada row:
- Leading: ícone do subtipo (📝 text | 🗂 outline | 🗃 collection), 20pt
- Título (15pt medium) + preview de 1 linha (13pt muted)
- Trailing: data relativa (12pt muted)
- Tap → abre Note

---

**Timeline Section**

Header row: "ATIVIDADE" (12pt semibold muted all-caps) + seletor inline de período (chips pequenas "7d" | "1m" | "3m" | "Tudo", sem borda, texto muted, ativo em accent).

Lista cronológica reversa. Cada item tem altura proporcional ao conteúdo. Separador hairline entre itens. Data relativa no trailing ("hoje", "ontem", "há 3 dias", "12 mai").

Tipos de item e visual:
- **Task:** chip "Task" (pill 11pt, fundo azul a 15%, texto azul) + título (15pt) + badge de stage (pill 11pt) + data deadline (13pt muted trailing)
- **Entry standard:** chip "Journal" (neutro) + timestamp HH:MM + preview de 1 linha (13pt muted) + emoji de mood (20pt, trailing) se houver
- **Field Note:** chip "Observação" (pill da cor da categoria) + ícone de categoria + texto completo (14pt)
- **Tracking Record:** chip da cor do tracker + nome do tracker (13pt semibold) + data + preview dos valores chave (13pt muted)
- **Habit record:** chip da cor do habit + nome + ✓ ou ✗ (16pt, verde ou vermelho) + streak "N dias" (13pt muted)
- **Calendar Session:** chip da cor da sessão + título (15pt) + data/hora + duração (13pt muted trailing)
- **Pomodoro:** chip "Pomodoro" (laranja a 15%) + linked item (14pt) + duração total (13pt muted trailing)

Scroll infinito com lazy loading (carregar mais ao chegar em 80% do scroll).

---

**Children Section (Sub-organizadores)**

Header row: "DENTRO DESTE [TIPO EM MAIÚSCULAS]" (12pt semibold muted all-caps) + contagem + "Ver todos" se > 5.

Lista de objetos Organizadores com WikiLink para este. Cada row:
- Ícone do tipo (20pt, cor do tipo) + nome (15pt medium)
- Subtítulo contextual (13pt muted): ex: para Project "12 tasks · Em progresso", para Habit "Streak 7 dias"
- Trailing: badge de status se aplicável

Botão "＋ Adicionar [tipo filho]" (texto accent, 14pt, padding 12pt) ao final de cada seção que aceita criação direta.

---

### 23.9 COMMAND CENTER

**Trigger:** scroll para cima em qualquer tela root. Overlay de slide down proporcional ao swipe (segue o dedo), com spring ao soltar se passar do threshold (30% da tela).

**Dimming:** fundo preto a 40% de opacidade abaixo do overlay, fade in sincronizado com o slide down.

**Estrutura do overlay** (fundo surface, borda inferior hairline, padding 16pt horizontal):

**Campo de busca:**
Auto-focused ao abrir. Fundo surface2, border radius 12pt, padding 12pt, ícone de lupa (16pt, muted) à esquerda, "✕" à direita quando há texto. Placeholder "Buscar...". 16pt.

Resultados de busca (quando há texto digitado, debounce 200ms): substituem as seções fixas. Agrupados por tipo com header de grupo (12pt semibold muted all-caps). Tap em resultado → navega e fecha o Command Center. Máximo 4 resultados por grupo. Busca em títulos, labels, aliases, body (primeiros 200 chars).

**Seção RECENTES** (quando search vazio):
Label "RECENTES" — 11pt semibold muted all-caps.
Grid de 2 colunas, máximo 8 chips. Cada chip: fundo surface2, border radius 20pt, padding 8pt 12pt. Ícone do tipo (14pt muted) + título truncado (13pt medium), 6pt de gap. Tap → navega. Swipe left em chip → remove dos recentes (com snackbar "Undo").

**Seção NOTAS:**
Label "NOTAS" — 11pt semibold muted all-caps.
Lista de até 5 Notes modificadas recentemente. Row: ícone subtipo (18pt) + título (14pt) + data relativa (12pt muted, trailing). Tap → navega.

**Seção PRÓXIMAS SESSÕES:**
Label "PRÓXIMAS SESSÕES" — 11pt semibold muted all-caps.
Lista de até 3 Calendar Sessions futuras. Row: dot colorido (8pt, cor da sessão) + título (14pt) + data/hora (13pt muted, trailing). Tap → navega.

**Seção SYSTEMS:**
Label "SYSTEMS" — 11pt semibold muted all-caps.
Row horizontal de até 3 chips de quick-run. Cada chip: fundo surface2, border radius 20pt, padding 8pt 14pt. "▶" (13pt accent) + nome do System (13pt medium), 4pt de gap. Tap → abre bottom sheet de quick-run (Via C). Long press → navega para detail view.

**Ações rápidas:**
Row de 4 botões fixos no bottom do overlay, acima do teclado. Cada botão: fundo surface2, border radius 20pt, padding 8pt 14pt. Ícone (16pt) + label (13pt), 4pt de gap.
- "＋ Entrada" | "＋ Task" | "＋ Registro" | "＋ System"
Tap → fecha Command Center + abre formulário correspondente.

**Fechar:** tap na área de dimming abaixo | swipe up (gesto inverso) | tecla Escape | navegar para qualquer item.

---

### 23.10 FAB — BOTÃO GLOBAL "CRIAR"

**Botão:** circular 56pt, fixo no bottom-right da tela. 16pt acima da tab bar. 16pt da borda direita. Fundo roxo escuro, "＋" branco 24pt (SF Symbols "plus" ou equivalente). Shadow: 0 4pt 16pt rgba(0,0,0,0.25). Z-index acima de todo conteúdo.

Ao tocar: "＋" rotaciona 135° para "✕" (180ms ease-out) + bottom sheet sobe.

**Bottom sheet:** ~50% da tela. Handle pill no topo.

**Row de 4 abas** logo abaixo do handle (não scrollável):
"Journal" | "Plan" | "Record" | "Note"
Aba ativa: label 15pt medium accent, underline 2pt accent abaixo do label. Inativa: label 15pt regular muted. Tap → troca aba com transição de fade (150ms).

---

**ABA JOURNAL:**

Segmented control no topo da aba (2 opções, fundo surface2, border radius 10pt):
"Entrada completa" | "Observação rápida"

**Entrada completa:**
- Botão primário full-width: fundo roxo escuro, branco, "📓 Nova entrada", 16pt semibold, border radius 12pt
- Botão secundário full-width outline (borda accent, texto accent): "📋 PMN da semana", 16pt, border radius 12pt, 8pt abaixo do primário

**Observação rápida (Field Note):**
- 4 chips de categoria em row (gap 8pt, scrollável se necessário): "💡 Insight" | "⚡ Energia" | "😊 Humor" | "👥 Encontro"
  - Chips: pill, fundo da cor da categoria a 15%, texto da cor, border radius 20pt, padding 8pt 14pt, 14pt
  - Selecionado: fundo 100%, texto branco
- Campo de texto (aparece com slide down + fade in ao selecionar categoria):
  - Text area, border radius 10pt, padding 14pt, mínimo 3 linhas, placeholder contextual por categoria (ex: "💡 O que você percebeu?" | "⚡ Como está sua energia agora (1-5)?" | "😊 Como você está se sentindo?")
  - 15pt
- Botão "Salvar observação" full-width, roxo escuro, branco. Disabled se campo vazio.

---

**ABA PLAN:**

Lista de opções em coluna (gap 0, separador hairline entre cada uma):
Cada row: ícone (20pt, cor por tipo) + label (16pt medium), padding 14pt horizontal, 52pt de altura, touch highlight.
- ✅ Nova task (azul)
- 🎯 Nova meta (roxo)
- 📅 Nova sessão (cor do usuário ou cinza)
- 🔔 Novo lembrete (cinza)
- 📥 Adicionar ao backlog (azul muted)

Tap → fecha sheet + abre formulário correspondente.

---

**ABA RECORD:**

Se nenhum Tracker ativo: empty state "Você ainda não tem trackers. [Criar um]" (link accent).

Se 1 Tracker ativo: botão full-width roxo escuro "Registrar [nome do tracker]".

Se múltiplos: lista de Trackers ativos. Cada row: ícone da cor do tracker (20pt) + nome (16pt medium) + "→" trailing (16pt muted). Tap → fecha sheet + abre formulário de Tracking Record.

---

**ABA NOTE:**

Lista de opções em coluna:
- 📝 Nota de texto
- 🗂 Nota de outline
- 🗃 Coleção
- ⚙️ System (cor laranja)
- 💡 Idea

Separador hairline entre cada uma. Tap → fecha sheet + abre formulário correspondente.

**Dismiss:** tap fora do sheet | swipe down | tap no FAB (que agora mostra "✕").

---

### 23.11 TIMER DE POMODORO (UI ativa)

**Apresentação:** full-screen overlay cobrindo tudo exceto status bar. Fundo surface (não preto puro — usar a cor de fundo do tema). Acessível mesmo com tela bloqueada via notificação persistente com action buttons.

**Layout (de cima para baixo, padding 24pt horizontal):**

**Item trabalhado:**
- Label "TRABALHANDO EM" — 11pt semibold muted all-caps, centrado, 24pt abaixo do status bar
- Título do item linkado — 20pt semibold, centrado, max 2 linhas, line-height 1.3
- Row tappável: tap → abre picker "Trabalhando em qual item?" (busca no vault, recentes no topo). Chevron "›" (14pt muted) à direita do título.
- 32pt abaixo

**Countdown circular:**
- Container 240pt × 240pt, centrado horizontalmente
- Anel de progresso SVG/Canvas: stroke-width 8pt, stroke-linecap round
  - Cor: verde (#4CAF50) para work | laranja (#FB923C) para pausa curta | azul (#60A5FA) para pausa longa
  - Fundo do anel: mesma cor a 15% opacidade
  - Progresso: de 100% (início da fase) até 0% (fim), sentido anti-horário
  - Animação: reduz proporcionalmente a cada segundo
- Centro do anel:
  - MM:SS — 52pt monospace semibold, centrado (usar fonte de largura fixa para evitar layout shift)
  - Label de fase — 14pt regular muted, 8pt abaixo do countdown: "Trabalhando" | "Pausa curta" | "Pausa longa"
- 32pt abaixo do container

**Indicador de blocos:**
- Row centralizada de N círculos (N = long_break_after_blocks, default 4)
- Cada círculo: 10pt diâmetro, gap 10pt
  - Completo: preenchido cor accent
  - Atual (em progresso): outline accent 2pt, animação de pulso suave (scale 1.0→1.15→1.0, 2s loop)
  - Próximo: outline cinza muted 1pt
- 32pt abaixo

**Controles:**
Row centralizada com 3 botões, gap 16pt:

Botão "⏭ Pular fase" (secundário):
- Circular 52pt, fundo surface2, borda 1pt surface2, ícone 20pt
- Touch feedback: highlight

Botão "⏸ Pausar" / "▶ Retomar" (primário):
- Circular 64pt, fundo accent, ícone branco 24pt
- Shadow: 0 4pt 12pt cor accent a 30%
- Ao pausar: ícone muda para "▶", fundo muda para cinza

Botão "⏹ Parar" (destrutivo):
- Circular 52pt, fundo surface2, ícone vermelho suave 20pt

Tap em "⏹ Parar":
Alert sheet (não full alert): slide de baixo, handle pill.
Título "Parar sessão?" — 17pt semibold.
Subtítulo "X blocos e Y min serão salvos." — 14pt muted.
Dois botões full-width: "Parar e salvar" (borda vermelha, texto vermelho, 16pt) + "Continuar" (fundo accent, branco, 16pt semibold). 8pt de gap.

**Ao concluir todos os blocos:**
Overlay de conclusão com fundo surface + overlay verde a 10%.
- Ícone ✓: animação de scale 0→1.2→1 com spring (400ms)
- "Sessão concluída!" — 22pt semibold, centrado, 16pt abaixo do ícone
- "X blocos · Y min trabalhados" — 15pt muted, centrado
- Dois botões: "Pronto" (outline, 16pt, border radius 12pt) + "Mais uma rodada" (fundo accent, branco, 16pt semibold). Full-width em coluna, 8pt de gap.

**Notificação persistente durante timer ativo:**
- Título: "⏱ [nome do item]" ou "☕ Pausa curta — X min" dependendo da fase
- Subtítulo: countdown em tempo real (atualiza a cada 5s para economizar bateria, exato no último minuto)
- Botões de ação: "Pausar" | "Parar"
- Ícone: ícone do app ou ícone específico de timer
- Prioridade: high (aparece mesmo em modo não perturbe para moods configurados assim)