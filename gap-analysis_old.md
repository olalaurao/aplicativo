# 2026-06-06 22H 20MIN

Citrine — Gap Analysis Completo
> Guidelines V3 × Código implementado (`olalaurao/aplicativo`)  
> Produzido em 06/06/2026 — fonte de verdade: guidelines.md (V3), lista de 166 arquivos Dart, `pendencias_implementacao.md`, `analysis_final_4.txt`, `ajustes.md`, `next_steps.md`, `wip_implementation_status.md`.

---

## Como ler este documento

Cada seção corresponde a uma parte do guidelines. Para cada item o status é classificado em:

- ✅ **Implementado** — arquivo e lógica existem no repositório com evidência clara
- ⚠️ **Parcial** — arquivo existe mas a implementação está incompleta, tem dead code, ou o fluxo não fecha
- ❌ **Ausente** — não existe nenhum arquivo correspondente, ou o guidelines descreve comportamento que não tem nenhuma base no código

---

## Parte 1 — Arquitetura Conceitual

### 1.1 Vault Structure

| Item | Status | Observação |
|---|---|---|
| Pasta padrão `app/` flat | ⚠️ | `VaultNotifier` escreve nessa pasta, mas `pendencias_implementacao.md` sec. 4 admite que o código "mistura `app/`, pastas por tipo, `daily/` e `trackers/records/`". Migração de arquivos legados não foi concluída. |
| `daily/YYYY-MM-DD.md` | ✅ | `MarkdownParser` e `VaultNotifier` geram e lêem daily notes. |
| `daily/YYYY-WNN.md` (PMN) | ⚠️ | Arquivo `journal_entry.dart` existe e tem suporte a `entry_type: pmn`, mas não há evidência de parsing do arquivo PMN próprio separado da daily note. Sem tela ou fluxo de criação dedicado visível. |
| `moods/SLUG.md` lazy | ⚠️ | `mood_model.dart` existe. Criação lazy na primeira vez que o mood é registrado não está verificada no código — não há `create_mood_file` no serviço. |
| `_attachments/`, `_deleted/`, `_conflicts/` | ⚠️ | `_deleted/` e `_conflicts/` referenciados em `sync_provider.dart` e `undo_service.dart`, mas purga automática de 30 dias não verificada. `_attachments/` mencionado sem serviço de gestão dedicado. |
| Object Identification (soberana) | ⚠️ | `type_signatures_screen.dart` existe (renomeado de Object Identification). Configuração de pasta/tag/propriedade por tipo referenciada, mas o parser de startup não demonstra usar essas regras ao indexar — ainda usa tipo no frontmatter como fallback principal. |
| Detecção de conflito de tipo (badge ⚠️) | ❌ | Não há lógica de detecção de conflito de tipo no código. Nenhuma tela "Conflitos" no menu Mais. |

### 1.2 Objetos de Conteúdo e Organizadores

| Item | Status | Observação |
|---|---|---|
| 9 tipos de conteúdo mapeados | ✅ | Todos têm model Dart correspondente. |
| 10 tipos de organizador | ⚠️ | `organizer_model.dart` existe mas `Places` (com coordenadas) e a hierarquia Area > Activity > Project completa não estão verificadas. `Activity` não aparece como tipo distinto em nenhum form. |
| Organizador tem Timeline própria | ⚠️ | `organizer_detail_screen.dart` existe. A timeline agrega dinamicamente conteúdo associado, mas `analysis_final_4.txt` aponta `unused_local_variable` dentro de `vault_provider.dart` (`pendingTasks`, `todayHabits`, `lastEntry`) — sugerindo que a agregação ainda não está totalmente conectada. |

---

## Parte 2 — Objetos de Dados

### Objeto 1: Entry (Journal Entry)

| Item | Status | Observação |
|---|---|---|
| `entry_type: standard` | ✅ | `create_entry_form.dart`, `journal_screen.dart`, `journal_entry.dart` implementados. |
| Rich text editor com bold/italic/heading/checklist/WikiLink | ⚠️ | `rich_text_editor.dart` existe. `next_steps.md` registra bug de renderização do body (`[{"insert":"lorem ipsum/n"}]`), indicando que o QuillDelta ainda não está sendo renderizado corretamente na timeline. `analysis_final_4.txt` aponta `desiredAccuracy` deprecado no form. |
| Fotos inline no body | ⚠️ | `pendencias_implementacao.md` sec. 5 lista "Salvar fotos como `![[arquivo]]` no corpo" como tarefa — indica que só existe thumbnail strip, não inserção inline real. |
| Location GPS real | ⚠️ | `create_entry_form.dart` usa `geolocator` mas a API `desiredAccuracy` está deprecada (`analysis_final_4.txt`). Location manual existe; auto-GPS não verificado como funcional. |
| `entry_type: field_note` (4 categorias, sem rich text) | ⚠️ | Modelo tem `category` e `energy_value`. Não há form dedicado de Field Note rápido — o toggle "Observação rápida" com 3 elementos não está evidente no código. |
| `entry_type: pmn` (arquivo próprio `YYYY-WNN.md`) | ✅ | Tela de criação implementada, parser na `VaultNotifier` adicionado. |
| PMN linkado a datas (`referenced_dates`) | ✅ | Model e parser de date_range e dates adicionados. |
| PMN auto-sugerindo Pact refs ativos | ✅ | Suporte básico adicionado (referências futuras para Pact/Habits). |
| Card PMN distinto na Timeline | ✅ | `PmnCard` adicionado em `timeline_card.dart` e usado nas telas. |
| Templates de Entry com CRUD | ⚠️ | `template_model.dart` e `create_template_form.dart` existem, mas `pendencias_implementacao.md` sec. 5 aponta que "Templates existem como picker, mas precisam CRUD de templates". |
| Organizers salvos como `OrganizerReference(type, slug)` | ⚠️ | `next_steps.md` menciona correção do `OrganizerReference.slug/title`, mas `pendencias_implementacao.md` sec. 5 ainda lista como pendente salvar o tipo do organizer. |

### Objeto 2: Task

| Item | Status | Observação |
|---|---|---|
| Campos core (stage, priority, dates, duration, etc.) | ✅ | `task_model.dart` completo. |
| `until_done`, `date_range`, `all_day` | ✅ | Modelados em `task_model.dart`. |
| Subtasks como Tasks completas com `parent_task` | ⚠️ | Subtasks existem mas `analysis_final_4.txt` aponta `_buildSubtaskItem` e `_buildHabitRow` como `unused_element` — sugerindo que o rendering pode não estar conectado. |
| Subtask sessions (grupos temáticos colapsáveis) | ⚠️ | `next_steps.md` lista como pendente explicitamente. |
| Triple Check (bloco no frontmatter, bottom sheet, 3 perguntas, diagnóstico) | ✅ | `TripleCheck` model adicionado ao `task_model.dart`, `triple_check_sheet.dart` criado com bottom sheet de 3 perguntas, diagnóstico em tempo real, botões de ação por dimensão bloqueada e persistência via `tasksProvider`. |
| Badge Triple Check no card após 7 dias sem progresso | ✅ | `TripleCheckBadge` widget adicionado ao `organizer_tasks_widget.dart` via `task.needsTripleCheckBadge` getter. |
| Triple Check no formulário de PMN (batch) | ❌ | Ausente (PMN nem existe ainda). |
| `depends_on` (array de bloqueadores) | ⚠️ | Modelado, sem UI para gestão de dependências. |
| `linked_system` | ✅ | Modelado em `task_model.dart`. |
| Reflexão ao finalizar | ⚠️ | `pendencias_implementacao.md` sec. 7 lista como pendente "Persistir reflection no markdown quando stage vira finalized". |
| Backlog modal ao salvar sem data | ⚠️ | `ajustes.md` lista backlog como implementado, mas o modal "Onde colocar?" com opção Backlog/Adicionar para hoje não está verificado como comportamento correto. |
| `social_refs` | ⚠️ | `social_post.dart` existe; link de Task → SocialPost não verificado. |
| `estimated_minutes` | ⚠️ | Modelado, sem UI dedicada de estimativa. |
| Scheduler por Task | ✅ | `scheduler.dart` e `scheduler_picker.dart` implementados. |
| Timer/Pomodoro vinculado a Task | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Vincular pomodoro a Task/Habit/Goal/Project e atualizar KPI time_spent" como pendente. |

### Objeto 3: Goal

| Item | Status | Observação |
|---|---|---|
| `goal_mode: standard` | ✅ | `goal_model.dart`, `create_goal_form.dart`, `goals_screen.dart` implementados. |
| `goal_mode: plan` (Objective, Strategy, Phases) | ⚠️ | Modelado com `objective`, `strategy`, `phases`. Sem seções distintas verificadas na detail view. `analysis_final_4.txt` tem null checks desnecessários em `goals_screen.dart` — sugerindo lógica incompleta. |
| KPIs com auto-complete de Goal | ⚠️ | `kpi_model.dart` e `kpi_engine.dart` existem. `pendencias_implementacao.md` sec. 14 lista "Implementar auto-complete de KPI" como pendente. |
| Goal como Organizador com Timeline | ⚠️ | Parcialmente via `organizer_detail_screen.dart`. |

### Objeto 4: Habit

| Item | Status | Observação |
|---|---|---|
| `habit_mode: habit` core | ✅ | `habit_model.dart`, `create_habit_form.dart`, `habits_screen.dart` implementados. |
| `habit_mode: pact` | ✅ | `habit_mode: pact` modelado e persistido corretamente. O bug de tipagem no parsing foi corrigido. |
| Steering Sheet (3 etapas: Revisão, Reflexão, Decisão) | ✅ | Componente `steering_sheet.dart` criado com fluxo completo de 3 etapas e persistência de dados. |
| Check automático de `ends_at` no startup | ✅ | Implementado checker de pactos expirados no startup em `main.dart` com disparador de notificações. |
| `previous_cycles` | ✅ | Salvo e atualizado no Markdown após cada ciclo finalizado via Steering Sheet. |
| `pact_outcome` | ✅ | Atualizado conforme a decisão (persist, pause, pivot) do usuário e persistido. |
| Slots com horário, reminder e Action independentes | ⚠️ | Slots existem no modelo. Reminders por slot existem. Actions por slot: ver seção de Actions abaixo. |
| "Days since" badge | ⚠️ | `habit_row.dart` tem UI de badge, mas lógica de atualização à meia-noite não verificada. |
| Streak e "days since" complementares | ⚠️ | Streak calculado, "days since" sem verificação de atualização automática. |
| Swipe right para completar habit | ⚠️ | Mencionado em gestos mas não verificado em `habit_row.dart`. |
| `isNegative` (habit de evitação) | ⚠️ | Modelado, sem rendering especial verificado. |
| `inputType: mood` | ⚠️ | Modelado, sem picker de mood integrado ao slot de habit. |
| `linkedTrackerSlug` | ⚠️ | Modelado, sem lógica de abertura do record form no momento de completion. |
| Dashboard `pact_today` panel | ❌ | Guidelines menciona panel "pact_today" com check-in diário. Não encontrado em `dashboard_panel.dart`. |

### Objeto 5: Tracker + Tracking Record

| Item | Status | Observação |
|---|---|---|
| Tracker definition com sections/fields | ✅ | `tracker_model.dart`, `create_tracker_form.dart`, `trackers_screen.dart` implementados. |
| 6 tipos de InputField | ⚠️ | `create_record_form.dart` tem switch com `unreachable_switch_default` (`analysis_final_4.txt`) — indica que nem todos os 6 tipos estão cobertos. |
| Tracking Record embebido na daily note | ⚠️ | `pendencias_implementacao.md` sec. 4 aponta que "Tracking records devem seguir uma regra clara: ou ficam em daily notes ou como arquivos próprios, mas não os dois sem sincronização" — problema em aberto. |
| Charts (line, bar, pie, calendar) por Tracker | ⚠️ | `citrine_chart.dart` e `tracker_metric_card.dart` existem. `pendencias_implementacao.md` sec. 12 lista "Statistics view deve permitir criar/remover summaries e charts persistidos no tracker" como pendente. |
| Summaries configuráveis | ⚠️ | Modelados, sem CRUD verificado. |
| InputField com `organizers` auto-adicionados ao Record | ❌ | Não há lógica de auto-adicionar organizers do campo ao record quando preenchido. |
| `media` field com save de arquivo | ⚠️ | `pendencias_implementacao.md` sec. 12 lista "Media field deve salvar arquivo e valor estruturado" como pendente. |
| History por campo (últimos valores) | ⚠️ | Mencionado em pendências sec. 12 como "History icon por campo deve abrir últimos valores reais" — pendente. |

### Objeto 6: Note

| Item | Status | Observação |
|---|---|---|
| Text Note com rich text | ✅ | `create_note_form.dart`, `note_model.dart` implementados. |
| `_bodyController` unused | ⚠️ | `analysis_final_4.txt` aponta `_bodyController` como `unused_field` em `create_note_form.dart` — campo do editor não conectado. |
| Outline Note (árvore, drag, focus mode, mirroring) | ⚠️ | `outline_editor.dart` e `outline_editor.dart` (widget) existem. Focus mode e mirroring não verificados. |
| Collection Note (schema + items + views list/gallery/table) | ⚠️ | `collection_editor.dart` e `collection_view.dart` existem. `pendencias_implementacao.md` sec. 6 lista "trocar contagem por split de texto por JSON/YAML estruturado, com schema e itens reais" como pendente — indica que Collection Note não está funcionando como banco de dados ainda. |
| Notes NÃO aparecem na Timeline principal | ⚠️ | Não verificado — Timeline pode estar mostrando Notes incorretamente. |
| `parent_note` e links bidirecionais | ⚠️ | Modelados, sem gestão de backlinks automática verificada. |
| WikiLink `[[]]` com picker flutuante inline | ⚠️ | `wiki_link_controller.dart` e `wiki_link_picker.dart` existem. Resolução de aliases de mood não verificada. |
| Filtros, reordenação e campos personalizados em listas de Notes | ⚠️ | `ajustes.md` lista como pendente explicitamente (item 6 e 7). |

### Objeto 7: Calendar Session

| Item | Status | Observação |
|---|---|---|
| Criação e visualização | ✅ | `create_session_form.dart`, `planner_screen.dart` implementados. |
| `_timeSlot` unused field | ⚠️ | `analysis_final_4.txt` aponta `_timeSlot` como `unused_field` em `create_session_form.dart`. |
| Chips Objectives, Time spent, Reminder | ⚠️ | `pendencias_implementacao.md` sec. 8 lista os 3 como pendentes. |
| Move modal com persistência completa | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `ajustes.md` registra "no planner visualizacao day, tava dando erro quando tento mudar a duração" — indica que persistência de duração falha. |
| Redimensionar duração arrastando no Day View | ❌ | `ajustes.md` lista como pendente. |
| Timer/Pomodoro inline na sessão | ⚠️ | `pendencias_implementacao.md` sec. 8, `time_block_picker.dart` existe mas integração não verificada. |
| `exported_calendar_id` e link com Google Calendar | ⚠️ | `google_calendar_service.dart` existe. `next_steps.md` lista export como implementado, mas integração bidirecional (importar evento como sessão) está pendente. |
| Backlog de sessões | ⚠️ | Modelado, sem UI verificada. |
| `linked_google_event_*` | ⚠️ | Modelados; persistência de link verificada parcialmente. |

### Objeto 8: Reminder

| Item | Status | Observação |
|---|---|---|
| Model e form básico | ✅ | `reminder_model.dart`, `create_reminder_form.dart`, `reminders_screen.dart` implementados. |
| 3 tipos (push, popup, alarm) | ⚠️ | `notification_service.dart` existe. `ajustes.md` registra "alarme nao funciona ainda" — tipo `alarm` não funcional. |
| Botões de ação (Marcar como feito, Soneca, Dispensar) | ⚠️ | `pendencias_implementacao.md` sec. 9 lista os 3 como pendentes de implementação real — actions só imprimem log. |
| Soneca com duração configurável na hora da notificação | ❌ | Ausente. |
| Confiabilidade via alarm manager nativo | ⚠️ | `notification_service.dart` existe; permissões verificadas em `permission_service.dart`. `ajustes.md` confirma que notificações/alarmes não funcionam no Android. |
| Organizer chip, scheduler e time block no form | ⚠️ | `pendencias_implementacao.md` sec. 9 lista como pendente. |
| Opção soneca/burnout (ignorar alarmes de hábitos até X dia) | ❌ | `ajustes.md` lista como pendente explicitamente. |

### Objeto 9: System

| Item | Status | Observação |
|---|---|---|
| Model | ✅ | Presumido presente via `create_note_form.dart` com aba System e `command_center_overlay.dart`. Porém não há `system_model.dart` explícito na lista de arquivos — o System pode estar embutido em `note_model.dart`. |
| Formulário de criação (título, trigger, steps, substeps, tempo estimado) | ⚠️ | Não há `create_system_form.dart` na lista de arquivos. A criação de System pode estar dentro de `create_note_form.dart` de forma rudimentar. |
| "Estruturar com IA" (botão de AI para montar steps) | ❌ | Ausente. |
| Detail view com stats (run_count, last_run, average_minutes, histórico) | ❌ | Sem `system_detail_screen.dart`. Stats derivadas de Tasks com `linked_system` não calculadas. |
| Botão "▶ Executar" — Via A (cria Task com subtasks dos steps) | ❌ | Ausente. |
| Via B — "Aplicar System" de qualquer Task | ❌ | Ausente. |
| Via C — Quick-run efêmero (checklist sem criar Task) | ❌ | Ausente. |
| "Salvar como System" a partir de Task (menu ⋯) | ❌ | Ausente. |
| `run_count`, `last_run`, `average_minutes` derivados | ❌ | Ausente. |
| Dashboard panel `system_quick_run` | ❌ | Não encontrado em `dashboard_panel.dart`. |
| Systems como chips no Command Center | ⚠️ | `command_center_overlay.dart` existe. Seção "Systems" como quick-run não verificada. |
| Swipe right em System → quick-run | ❌ | Ausente. |

**⚠️ Sistema (Objeto 9) é a feature com maior gap do projeto — quase todo o comportamento está ausente.**

### Objeto 10: Social Post

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `social_post.dart`, `create_social_post_form.dart`, `social_screen.dart`, `social_post_detail.dart` implementados. |
| Bulk import | ✅ | `social_bulk_import_screen.dart` existe. |
| Embed view (oEmbed) | ✅ | `social_embed_view.dart`, `oembed_service.dart` implementados. |
| Linkagem com Tasks (`linked_tasks`) | ⚠️ | Modelado; UI de linkagem unificada com busca por tipo não verificada. |
| `linked_content` (qualquer objeto do vault) | ⚠️ | Modelado sem UI verificada. |

---

## Parte 3 — Objetos de Suporte

### Scheduler

| Item | Status | Observação |
|---|---|---|
| 11 tipos de regra | ⚠️ | `scheduler.dart` e `scheduler_picker.dart` existem. `analysis_final_4.txt` aponta múltiplos `unreachable_switch_default` e `unused_local_variable 'isSelected'` no `scheduler_picker.dart` — indica que nem todos os tipos estão cobertos. `pendencias_implementacao.md` sec. 8 lista "Scheduler deve usar `days_of_theme` e `days_with_block`" como pendente. |
| Regras de exclusão | ⚠️ | Modeladas, sem UI específica verificada. |
| Política de atraso (skip/keep/prompt) | ⚠️ | Modelada, sem UI de escolha verificada. |
| Múltiplas regras por scheduler (OR lógico) | ⚠️ | Modelado, sem UI para adicionar múltiplas regras. |
| Página global de Scheduler (Settings → Scheduler) | ✅ | `scheduler_management_screen.dart` e `scheduler_page.dart` existem. |

### Day Theme e Time Block

| Item | Status | Observação |
|---|---|---|
| CRUD de Day Theme | ✅ | `day_theme_screen.dart`, `day_theme_model.dart`, `day_theme_provider.dart` existem. |
| CRUD de Time Blocks (nome, cor, hora inicial/final) | ⚠️ | `time_block_picker.dart` existe mas `pendencias_implementacao.md` sec. 18 lista "CRUD de Time Blocks com nome, cor, hora inicial/final" como pendente. |
| `energy_level` por bloco | ⚠️ | Modelado. Toggle "Camada de energia" no Planner não verificado. |
| Tints de energia no Planner (8% opacity) | ❌ | Não verificado como implementado. |
| Auto-geração de Energy Map a partir de Field Notes (14+ dias) | ❌ | Ausente — depende também de Field Notes funcionais. |
| Planner agrupa sessões/habits por Time Block | ⚠️ | `ajustes.md` lista "day times pros habits - ficar ao longo do dia no horário do slot reminder" como pendente. |

### KPI

| Item | Status | Observação |
|---|---|---|
| `kpi_model.dart` e `kpi_engine.dart` | ✅ | Existem. |
| Fontes: subtasks, tracker_field, habit, collection, entry, time_spent, manual_quantity | ⚠️ | `kpi_engine.dart` existe mas `pendencias_implementacao.md` sec. 14 lista problemas em fontes específicas (`entryCount` inconsistente, `collection` sem parse estruturado). |
| Auto-complete de KPI | ❌ | `pendencias_implementacao.md` sec. 14 lista como pendente. |
| Input inline de `manual_quantity` com botão "+N" | ⚠️ | Sem UI específica verificada. |

### Snapshot

| Item | Status | Observação |
|---|---|---|
| Model e form | ✅ | `snapshot_model.dart`, `create_snapshot_form.dart` existem. |
| Aparece na Timeline como entrada | ⚠️ | Sem verificação de que `timeline_card.dart` tem variante Snapshot. |
| Update de Snapshot | ⚠️ | `pendencias_implementacao.md` sec. 3 lista "Garantir update para Snapshot" como pendente. |

### Mood Definition

| Item | Status | Observação |
|---|---|---|
| Model com todos os campos | ✅ | `mood_model.dart` implementado. |
| 48 moods do sistema pré-carregados (12 por quadrante) | ⚠️ | Tabela do guidelines tem 48 moods. Não verificado se todos os 48 estão hardcoded no código. |
| Picker de humor em 2 passos (grade 2×2 → lista por quadrante) | ⚠️ | `mood_chart_widget.dart` existe. O picker de 2 passos (grade interativa + lista de moods do quadrante selecionado) não tem arquivo dedicado — provavelmente está inline em algum form. |
| Campo de busca no picker (label, label_en, aliases) | ⚠️ | Sem verificação de busca por `aliases` no picker. |
| "Adicionar minha própria emoção" → form de mood user | ⚠️ | `mood_settings_screen.dart` existe para gerenciar moods. Criação inline no picker não verificada. |
| Moods system: apenas `hidden` e `aliases` editáveis | ⚠️ | Lógica de restrição não verificada. |
| Moods system: arquivo criado lazily na 1ª vez | ⚠️ | Lógica lazy não verificada no código. |
| `aliases` como campo nativo de aliases do Obsidian | ⚠️ | Sem verificação de escrita no frontmatter como array `aliases:`. |
| Emoji como marcador nos gráficos de linha | ⚠️ | `mood_chart_widget.dart` e `citrine_chart.dart` existem. Emoji como marcador de ponto visual não verificado. |
| Emoji no calendário de Combined Analysis | ⚠️ | `analysis_calendar.dart` existe. Emoji no centro do dia não verificado. |
| 4 campos separados na daily note (`mood_pleasantness`, `mood_energy`, `mood_label`, `mood_emoji`) | ⚠️ | Formato canônico definido no guidelines; escrita dos 4 campos separados não verificada no `MarkdownParser`. |

---

## Parte 4 — Telas e Navegação

### Bottom Navigation Bar

| Item | Status | Observação |
|---|---|---|
| 5 slots padrão com Dashboard fixo e Mais fixo | ✅ | `app_shell.dart` implementado. |
| Slots 2–4 customizáveis (adicionar, remover, reordenar) | ✅ | `navigation_shortcut_picker.dart` e `navigation_provider.dart` existem. `ajustes.md` lista como implementado. |
| Máximo de 7 slots | ⚠️ | Sem verificação de enforcement do limite. |
| Atalhos para nota específica, filtro de área, tarefa específica | ⚠️ | `ajustes.md` lista "quero poder colocar atalhos pra qualquer página" como pendente no contexto de customização avançada. |

### FAB Global "Criar"

| Item | Status | Observação |
|---|---|---|
| Bottom sheet com abas Journal/Plan/Record/Note | ✅ | `create_menu_sheet.dart` implementado. |
| Aba Journal → Entry / Field Note / PMN | ⚠️ | Entry existe. Field Note e PMN como opções distintas não verificadas. |
| Aba Note → System | ⚠️ | System não tem form dedicado. |
| Snapshot, Voice Note, Scan Document funcionais | ⚠️ | `pendencias_implementacao.md` sec. 1 lista os 3 como pendentes de implementação real. |

### Command Center (scroll-up)

| Item | Status | Observação |
|---|---|---|
| Overlay com busca, Recentes, Notas, Próximas Sessões | ✅ | `command_center_overlay.dart` implementado. |
| Seção "Systems" com 3 Systems como chips de quick-run | ❌ | Não implementado (System não existe de forma completa). |
| Ações rápidas: "Novo System" | ❌ | Ausente. |

---

## Parte 5 — Padrões de Interação

| Item | Status | Observação |
|---|---|---|
| Gestos: tap, long press, swipe left, swipe right, drag, scroll-up | ⚠️ | Maioria implementada. Swipe right em System → quick-run: ausente. Swipe right em Habit/Pact para completar: não verificado. |
| Undo em Delete/Archive (snackbar 5s, `_deleted/`) | ✅ | `undo_service.dart` implementado. `wip_implementation_status.md` lista como concluído. |
| Drag-and-drop no Planner com persistência | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `pendencias_implementacao.md` sec. 11 lista "Todo drag/drop deve persistir no objeto e reescrever markdown" como pendente — contradição. |
| Organizer Detail View com 4 seções dinâmicas | ⚠️ | `organizer_detail_screen.dart` existe. `analysis_final_4.txt` aponta variáveis locais não usadas no `vault_provider.dart` que alimentam essas seções. |

---

## Parte 6 — Sistema de Actions (Habits e Trackers)

| Item | Status | Observação |
|---|---|---|
| `automation_service.dart` | ✅ | Existe. |
| 7 tipos de Action | ⚠️ | `analysis_final_4.txt` aponta `unused_local_variable 'changed'` em `automation_service.dart` — automação existe mas a variável de resultado não é usada, sugerindo que as actions não são disparadas de fato. |
| Trigger: completar slot individual | ❌ | Não verificado como disparado. |
| Trigger: atingir daily goal | ❌ | Não verificado como disparado. |
| Trigger: salvar tracking record | ❌ | Não verificado como disparado. |
| Configuração de Action por slot (independente do reminder) | ❌ | UI de configuração de Action por slot não encontrada. |

**⚠️ Actions é outra feature com gap significativo — o serviço existe mas as actions não são efetivamente disparadas.**

---

## Parte 7 — Pomodoro

| Item | Status | Observação |
|---|---|---|
| Timer funcional (work/short break/long break) | ✅ | `pomodoro_screen.dart`, `pomodoro_provider.dart`, `pomodoro_bg_service.dart` implementados. |
| UI full-screen com countdown circular, controles, indicador de blocos | ✅ | `pomodoro_screen.dart` implementado. |
| Notificação persistente com Pausar/Retomar/Parar | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Foreground notification precisa ter ações Pause/Resume/Stop conectadas ao provider" como pendente. |
| PomodoroSession persistida na daily note (`## Pomodoros`) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "escrever `## Pomodoros` no daily note" como pendente. |
| Vincular Pomodoro a Task/Habit/Goal/Project | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pendingTasks` e `todayHabits` unused no vault_provider | ⚠️ | `analysis_final_4.txt` — sugere que integração Pomodoro → KPI time_spent não está conectada. |
| Pomodoro Agendado (cria CalendarSession ou Reminder) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Botão 'Agendar Pomodoro' deve criar CalendarSession ou Reminder, não apenas snackbar" como pendente. |
| Histórico de sessões do vault (não só memória) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pomodoro_floating_clock.dart` e `pomodoro_week_overview.dart` | ✅ | Existem. |

---

## Parte 8 — People

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `people_model.dart`, `create_person_form.dart`, `people_screen.dart` implementados. |
| `last_contact_date` derivado de backlinks reais | ⚠️ | `pendencias_implementacao.md` sec. 15 lista "Calcular `last_contact_date` por backlinks reais, journal entries e eventos" como pendente. Variável `frequencyDays` apontada como unused no `people_screen.dart` (`analysis_final_4.txt`). |
| Scheduler automático → Task "Contatar [nome]" | ⚠️ | `automation_service.dart` tem `checkPersonContacts` mas com `unused_local_variable 'changed'` — não conectado. |
| Ao concluir a task automática → atualiza `last_contact_date` | ❌ | Ausente (depende de task completion callback). |
| Histórico de contatos e menções navegáveis | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. |
| Editar `contact_frequency` inline | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. Unused `frequencyDays` confirma. |

---

## Parte 9 — Resources

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `resource_model.dart`, `create_resource_form.dart`, `resources_screen.dart` implementados. |
| Dead code em `create_resource_form.dart` | ⚠️ | `analysis_final_4.txt` aponta `dead_code` e `dead_null_aware_expression` — lógica quebrada no form. |
| Settings → Resources: regras de filtro configuráveis | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Cover image via WikiLink embed | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Rating persistido imediatamente | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. Status duplicado no modelo apontado. |
| Lazy loading do grid | ⚠️ | `ajustes.md` lista "grid de resources deve ser lazy loading" como pendente. |

---

## Parte 10 — Projects

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `project_model.dart`, `create_project_form.dart` implementados. |
| `primary_kpi` como drive do % de progresso | ⚠️ | `kpi_engine.dart` existe mas integração com Projects não verificada. |
| `quick_access` (links rápidos) | ⚠️ | Modelado, sem UI de adição de links verificada. |
| `total_pomodoro_time` derivado | ❌ | Depende de Pomodoro → Task linkado, que está pendente. |
| Project detail com todas as seções | ⚠️ | `pendencias_implementacao.md` sec. 14 lista "Project detail deve expor edição inline de state, priority, due date, KPIs e tarefas vinculadas" como pendente. |
| Scheduler recorrente de projeto (reinicia no schedule) | ⚠️ | Modelado, sem fluxo de reinicialização verificado. |

---

## Parte 11 — Combined Analysis

| Item | Status | Observação |
|---|---|---|
| Tela existe | ✅ | `combined_analysis_screen.dart` implementado. |
| CRUD de objeto CombinedAnalysis persistente | ⚠️ | `pendencias_implementacao.md` sec. 13 lista "Criar CRUD de CombinedAnalysis com title, description, data_sources, chart configs" como pendente — análises são temporárias em estado local. |
| `analysis_model.dart` | ✅ | Existe (com deprecated `.value` apontado em `analysis_final_4.txt`). |
| Picker de fontes com cor/label/field/source type | ⚠️ | Pendente (sec. 13). |
| `normalization: dual_axis / normalize_0_1` | ❌ | Sem evidência de normalização de eixo duplo implementada. |
| `value_mapping` para campos categóricos | ❌ | Sem evidência de mapeamento categórico → numérico. |
| Emoji como marcador em gráficos de linha | ❌ | `analysis_final_4.txt` aponta `unused_local_variable 'firstDay'` em `combined_analysis_screen.dart` — lógica de calendário incompleta. |
| Calendário mensal com emoji de mood + dots coloridos | ⚠️ | `analysis_calendar.dart` existe mas sem emoji de mood verificado. |
| Mood como fonte com dimensão pleasantness/energy | ⚠️ | Pendente (sec. 13). |

---

## Parte 12 — Sync, Offline e Conflitos

| Item | Status | Observação |
|---|---|---|
| Sync com Google Drive (offline-first) | ✅ | `google_drive_sync_service.dart`, `sync_provider.dart`, `sync_queue_service.dart`, `sync_manager.dart` implementados. |
| `fetchRemoteFiles` recursivo | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "hoje busca só filhos diretos da pasta raiz" como pendente. |
| Hash por arquivo para detecção correta de conflito | ⚠️ | Pendente (sec. 19). |
| UI de conflito com comparação campo a campo | ✅ | `conflict_resolution_dialog.dart`, `sync_conflict_dialog.dart`, `sync_conflicts_screen.dart` existem. `wip_implementation_status.md` lista como concluído. |
| Fila offline visível ao usuário | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "Mostrar fila offline e erros de sync ao usuário" como pendente. |
| Indicador de status (synced/syncing/offline/error) | ⚠️ | `sync_provider.dart` tem estados; UI de indicador não verificada. |
| Backup ZIP periódico (diário/semanal/por abertura) | ✅ | `backup_service.dart` existe. Configuração de retenção não verificada. |
| Purga automática de `_deleted/` em 30 dias | ❌ | Sem serviço de purga verificado. |

---

## Parte 13 — Notificações

| Item | Status | Observação |
|---|---|---|
| `notification_service.dart` | ✅ | Existe. |
| 3 tipos: push, popup, alarm | ✅ | Push e popup funcionam; Alarm foi ajustado e verificado para rodar e permitir ações reais. |
| Botões de ação reais (não apenas log) | ✅ | Implementado em `vault_provider.dart` (`_markNotificationTargetDone`, `_snoozeNotification`, `_recordNotificationDismissal`) e nas telas `AlarmScreen` e `PopupScreen`. Suporte a Task, Habit e Reminder. |
| Confiabilidade via alarm manager do sistema | ⚠️ | `permission_service.dart` existe; `ajustes.md` confirma falhas. |
| Notificação persistente de Captura Rápida (lockscreen) | ⚠️ | `next_steps.md` lista como implementado com ressalva (botões físicos não suportados pelo OS). |
| Popup sobre lockscreen | ✅ | `popup_notification_screen.dart` implementado com ações reais e fallback corrigido. |

---

## Parte 14 — Archive Universal

| Item | Status | Observação |
|---|---|---|
| `archived: true` no frontmatter | ✅ | Todos os modelos têm `archived`. |
| Página Archive com lista, filtro por tipo, busca, Restaurar | ✅ | `archive_screen.dart` existe. `wip_implementation_status.md` lista como concluído. |
| Banner "Arquivado" na detail view em read-only | ⚠️ | Não verificado em `universal_detail_view.dart`. |
| "Ver arquivados" por seção via menu ⋯ | ⚠️ | Sem evidência de implementação por seção. |

---

## Parte 15 — Widgets (Home Screen / Lock Screen)

| Item | Status | Observação |
|---|---|---|
| `widget_service.dart` e `widget_sync_provider.dart` | ✅ | Existem. |
| Quick-add widget (2×1) | ⚠️ | `pendencias_implementacao.md` sec. 20 lista "Quick-add widget: botões Journal Entry e Add Task com deep links" como pendente. |
| Calendar widget com dots | ⚠️ | Pendente (sec. 20). |
| Category widget configurável | ⚠️ | Pendente (sec. 20). |
| Obsidian Note widget (renderiza nota específica) | ⚠️ | Pendente (sec. 20). |
| Widget configuration sheet real | ✅ | `widget_config_sheet.dart` existe. |
| Deep links e atualização em background no Android/iOS | ⚠️ | Pendente (sec. 20). |

---

## Parte 16 — Linking Universal

| Item | Status | Observação |
|---|---|---|
| `links` no frontmatter | ✅ | Todos os modelos têm `links`. |
| Inline WikiLink `[[]]` com picker flutuante | ✅ | `wiki_link_controller.dart`, `wiki_link_picker.dart`, `wiki_text_view.dart` implementados. |
| Filtragem fuzzy por título e aliases no picker | ⚠️ | Aliases de mood não verificados como indexados. |
| Menções/Backlinks em todas as detail views | ⚠️ | `universal_detail_view.dart` existe mas `analysis_final_4.txt` aponta `_statBox`, `actions` e `_buildSubtaskItem` como `unused_element` — partes da detail view não conectadas. |
| Busca indexa body de markdown, frontmatter, tags, backlinks | ⚠️ | `search_service.dart` existe. `pendencias_implementacao.md` sec. 17 lista "Search deve indexar todos os corpos de markdown" como pendente — indica indexação incompleta. |

---

## Parte 17 — Navigation History

| Item | Status | Observação |
|---|---|---|
| `history_provider.dart` | ✅ | Existe. |
| Back button em toda tela não-root | ⚠️ | `ajustes.md` lista "Botão de voltar deve sempre voltar para a página anterior, não para o pai (corrigir go_router)" como pendente. |
| Breadcrumb trail quando stack > 2 níveis | ❌ | Sem `breadcrumb.dart` ou equivalente na lista de arquivos. |
| Restaurar posição de scroll e estado de form ao voltar | ❌ | Não implementado. |

---

## Parte 18 — Design Visual

| Item | Status | Observação |
|---|---|---|
| Cores por tipo de objeto | ⚠️ | `theme.dart` existe. Cores por subtipo (field_note por categoria, PMN por seção, System laranja) não verificadas. |
| "Days since" badge em Habits | ⚠️ | `habit_row.dart` tem badge, mas pill vermelha `#E53935` após 1+ dia e atualização à meia-noite não verificadas. |
| Badge "PACT" (pill branca, fundo = cor do habit) | ⚠️ | `habit_row.dart` tem badge PACT, styling exato não verificado. |
| Color picker visual (nunca HEX direto) | ⚠️ | `ajustes.md` e guidelines explicitam isso. Não verificado em todos os forms. |
| Energy level tints no Planner (8% opacity) | ❌ | Não verificado. |
| Dark mode completo sem textos ilegíveis | ⚠️ | `ajustes.md` e `next_steps.md` listam dark mode como corrigido, mas com ressalvas. `analysis_final_4.txt` tem múltiplos `withOpacity` deprecated que afetam cores. |

---

## Parte 19 — UI Fundamentals

| Item | Status | Observação |
|---|---|---|
| Safe Areas (iOS notch, Android status bar) | ⚠️ | `app_shell.dart` usa SafeArea. Consistência em todos os modais não verificada. |
| Back button (‹) em telas pushed, X em modais | ⚠️ | `ajustes.md` lista correção do back button como pendente. |
| Botão Done/Save (pill arredondada, roxo escuro) | ⚠️ | Não verificado como padrão consistente. |
| Keyboard avoidance (CTA sobe com teclado) | ⚠️ | Não verificado em todos os forms. |
| Handle pill em bottom sheets (36×4pt) | ⚠️ | Não verificado como padrão. |
| Stacking de modais com escala do anterior | ⚠️ | Não verificado. |
| Altura de row (48–52pt), padding horizontal (16pt) | ⚠️ | Não verificado como padrão consistente. |
| Haptic feedback (light/medium/warning por tipo de ação) | ⚠️ | Não verificado. |
| Empty states com ilustração, headline e CTA real | ⚠️ | `empty_state.dart` existe. `pendencias_implementacao.md` sec. 21 lista "Adicionar empty states com CTA real em todas as telas" como pendente. |
| Loading: offline-first (instantâneo) + sync indicator | ⚠️ | Arquitetura offline-first existe; feedback visual de sync não verificado em todos os lugares. |
| Delete sempre com confirmation alert nomeando o item | ⚠️ | Não verificado como padrão consistente. |
| Título duplicado/não-fixo no topo | ⚠️ | `ajustes.md` lista "tira o título duplicado que não tá fixo" como pendente. |

---

## Parte 20 — Vault Obsidian: Esquema Completo

| Item | Status | Observação |
|---|---|---|
| `markdown_parser.dart` e `obsidian_service.dart` | ✅ | Existem. |
| Algoritmo de parsing no startup (8 etapas) | ⚠️ | `vault_provider.dart` existe (1250+ linhas). Múltiplos warnings de variáveis não usadas no startup (`analysis_final_4.txt`). Object Identification não soberana no startup. |
| Parse de daily note: habits, trackers, mood 4 campos, entries | ⚠️ | Parcialmente implementado. Mood como 4 campos separados no frontmatter não verificado. Field Notes no formato `### HH:MM` não verificado. |
| Parse de PMN (`daily/YYYY-WNN.md`) | ❌ | Ausente. |
| Criação lazy de arquivo de mood | ⚠️ | Ausente ou não verificado. |
| Derivação de `run_count`, `last_run`, `average_minutes` do System | ❌ | System não implementado. |
| Derivação do Energy Map de Field Notes | ❌ | Ausente. |
| Lookup de PMN por data | ❌ | Ausente. |
| Testes de ida-e-volta objeto → markdown → objeto | ⚠️ | `pendencias_implementacao.md` sec. 4 e sec. 22 listam como pendentes. |
| `dataview_generator.dart` | ✅ | Existe. |
| Queries Dataview de exemplo | ✅ | `dataview_generator.dart`. |

---

## Parte 21 — Object Identification

| Item | Status | Observação |
|---|---|---|
| Tela Settings → Object Identification | ✅ | `type_signatures_screen.dart` existe. |
| 3 tipos de marcador (Folder, Tag, Property) | ⚠️ | UI existe mas parser de startup não usa as regras definidas como soberano. |
| Badge ⚠️ em conflito de tipo | ❌ | Ausente. |
| Página "Conflitos" no menu Mais | ❌ | Ausente. |
| Editar tipo de qualquer objeto (tornar Area em Task, etc.) | ⚠️ | `ajustes.md` lista como implementado. |
| Compatibilidade com Tasks Plugin do Obsidian (`- [ ] [due:: ...] [priority:: ...]`) | ⚠️ | `markdown_parser.dart` existe mas compatibilidade com sintaxe do Tasks Plugin não verificada. |

---

## Parte 22 — Notas de Implementação (regras críticas)

| Regra | Status | Observação |
|---|---|---|
| Sempre ler `habit_mode` antes de renderizar | ⚠️ | Bug de runtime `type map dynamic is not a subtype of list dynamic` confirma que o parsing não é robusto. |
| Sempre ler `entry_type` antes de renderizar | ⚠️ | Field Note e PMN não têm rendering diferenciado verificado. |
| Sempre ler `goal_mode` antes de renderizar | ⚠️ | Null checks desnecessários em `goals_screen.dart` confirmam lógica frágil. |
| Nunca exibir campo `id` ao usuário | ⚠️ | Não verificado como regra aplicada. |
| Color picker visual obrigatório (nunca HEX direto) | ⚠️ | Não verificado em todos os forms. |
| PMN em arquivo próprio, indexado por `referenced_dates` | ❌ | Não implementado. |
| Mood como WikiLink nas entries + 4 campos na daily note | ⚠️ | WikiLink existe; 4 campos na daily não verificados. |
| Moods system criados lazily | ⚠️ | Não verificado. |
| Object Identification soberana no parser de startup | ❌ | Não implementado como soberano. |
| Actions são obrigatórias (7 tipos) | ❌ | Actions não são disparadas. |
| Triple Check não cria arquivo — bloco no frontmatter da Task | ✅ | Implementado: `TripleCheck.toMap()` serializa inline no frontmatter, nunca cria arquivo separado. |
| `run_count`/`last_run`/`average_minutes` sempre derivados | ❌ | System não implementado. |
| Steering Sheet em 3 etapas ao expirar Pact | ❌ | Não implementado. |
| PMN e Triple Check com batch no formulário de PMN | ❌ | PMN não implementado; Triple Check sem UI. |
| `value_mapping` apenas para campos categóricos | ❌ | Não implementado em Combined Analysis. |

---

## Resumo Executivo por Prioridade

### 🔴 Crítico — Ausente ou quebrado em runtime

1. ✅ **PMN completo** — implementado, com tela de criação, card na Timeline, e integração com o VaultNotifier.
2. ✅ **System (Objeto 9)** — implementado: `system_model.dart`, `systems_provider.dart`, `create_system_form.dart`, `system_detail_screen.dart` criados; Vias A (criar Task), B (aplicar steps a Task existente) e C (quick-run efêmero com stats) implementadas; painel `systemQuickRun` adicionado ao dashboard.
3. ✅ **Steering Sheet** — fluxo de revisão de Pact ao término com SteeringSheet de 3 etapas (Revisão, Reflexão, Decisão) e check automático de expiração no startup com notificações locais implementado.
4. ✅ **Triple Check** — UI de bottom sheet com 3 perguntas (Head/Heart/Hand), diagnóstico em tempo real por dimensão bloqueada, botões de ação contextuais (Reformular/Arquivar, Criar subtasks/Adiar, Adicionar dependência), badge ⚠️ após 7 dias sem progresso e persistência no frontmatter da Task implementados.
5. **Notificações — actions reais** — mark done, snooze e dismiss ainda apenas imprimem log; alarm type não funcional.
6. **Actions de Habit/Tracker** — `automation_service.dart` existe mas nenhuma action é efetivamente disparada em nenhum trigger.
7. **Object Identification soberana no startup** — parser não respeita as regras configuradas pelo usuário.
8. **Bug crítico de runtime em Habits** — `type map dynamic is not a subtype of list dynamic` impede a tela de carregar.

### 🟡 Importante — Parcial ou com lógica quebrada

9. **Pomodoro** — timer funciona; persistência na daily note, linkagem com Tasks/Goals, KPI `time_spent` e foreground notification actions pendentes.
10. **Combined Analysis** — tela existe mas análises são temporárias; sem `dual_axis`, sem `value_mapping`, sem emoji de mood nos gráficos.
11. **Field Notes** — modelo existe; form dedicado rápido e rendering diferenciado na Timeline ausentes.
12. **Rich text body na Timeline** — body renderiza como JSON Delta cru em vez de texto formatado.
13. **People CRM automático** — `last_contact_date` derivado de memória, não de backlinks; task automática não cria/atualiza corretamente.
14. **Planner Day View** — redimensionamento de tarefas por drag ausente; duração curta não mostra nome; habits não posicionados por horário de slot.
15. **KPI auto-complete** — engine existe mas auto-complete quando `current >= target` não executa ação.
16. **Back navigation** — botão voltar não restaura tela anterior corretamente em go_router.
17. **Tracker records** — formato dual (daily note + arquivo próprio) sem sincronização definida.
18. **Google Drive sync** — não recursivo; hash de conflito não persistido.

### 🟢 Implementado com ressalvas menores

19. Vault structure básica, modelos Dart, CRUD core de Tasks/Goals/Habits/Notes/Resources.
20. Planner Day/Week/Month com visualização básica.
21. Journal Entry standard com rich text (bugs de rendering existem).
22. Mood model com picker parcial e mood_settings_screen.
23. Sync com Google Drive (arquitetura presente, robustez incompleta).
24. Archive Universal com restore.
25. Scheduler básico (faltam tipos avançados e regras de exclusão na UI).
26. Pomodoro timer funcional.
27. Conflict resolution UI.
28. Command Center overlay.
29. Navigation shortcuts customizáveis.
30. Social Posts com bulk import e oEmbed.

---

*Fim do gap analysis. Total de itens analisados: ~220. Implementados sem ressalvas: ~30 (~14%). Parciais: ~110 (~50%). Ausentes: ~80 (~36%).*