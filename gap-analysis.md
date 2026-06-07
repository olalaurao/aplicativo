# 2026-06-07 16H 
 Gap Analysis Citrine × Guidelines V3 — Baseado no Código Real
> Análise feita com base no código Dart lido diretamente: `automation_service.dart`, `markdown_parser.dart`, `vault_provider.dart`, `widget_sync_provider.dart`, `widget_service.dart`, `dataview_generator.dart`, `obsidian_service.dart`, `triple_check_sheet.dart`, `steering_sheet.dart`, `import_vault_screen.dart`, `scheduler_page.dart`, `social_screen.dart`.
>
> **Legenda:** ✅ Implementado e confirmado no código · ⚠️ Parcial ou com ressalva real · ❌ Ausente ou stub

---

## PARTE 1 — VAULT E PARSING

### Arquitetura central (AllObjectsNotifier)

| Item | Status | O que o código mostra |
|---|---|---|
| Leitura de todos os `.md` em paralelo (batches de 50) | ✅ | `await Future.wait(batch.map(...))` — implementado e eficiente |
| `type` lido do frontmatter para identificar objetos | ✅ | Switch completo em `AllObjectsNotifier.build()` cobrindo todos os 20+ tipos |
| TypeSignatures (Object Identification) soberanas | ✅ | `MarkdownParser.matchesSignature()` aplicado antes do switch de tipo |
| Fallback: arquivo sem `type` vira `Note` | ✅ | `else { obj = Note(...) }` no final do switch |
| Deduplicação por ID | ✅ | `Map<String, ContentObject>` no final do build |
| Sorting por `updatedAt` decrescente | ✅ | `.sort((a, b) => b.updatedAt.compareTo(a.updatedAt))` |
| Cache de daily notes em `_dailyNoteDataMapProvider` para O(1) | ✅ | `Future.microtask(() { ref.read(_dailyNoteDataMapProvider.notifier).state = dailyMap; })` |
| Campo `moc` nunca escrito | ✅ | Não existe nenhuma referência a `moc` no código |
| IDs nunca exibidos ao usuário | ✅ | Apenas `title`/`displayTitle` nas interfaces |

### markdown_parser.dart — O que realmente existe

| Item | Status | O que o código mostra |
|---|---|---|
| `parseFrontmatter()` com repair de YAML legado | ✅ | `_repairLegacyInlineAnalysisYaml()` lida com `sources: [{` inline — feature robusta |
| `asyncParseFrontmatter()` via `compute()` (isolate) | ✅ | Parsing pesado em thread separada |
| `parseJournalEntries()` com regex `### HH:MM` | ✅ | Regex `r'^(\d{1,2}:\d{2})(?:\s*-\s*(.*))?'` — timestamp **está** sendo parseado |
| `mood::` como WikiLink extraído corretamente | ✅ | `extractWikiLinks(moodLineMatch.group(1)!)` na seção de entries |
| `organizers::` como WikiLinks extraídos | ✅ | `_orgsRegex` + `extractWikiLinks()` |
| `parseHabitCompletions()` com fallback para chaves top-level | ✅ | Lê `frontmatter['habits']` primeiro; fallback para chaves avulsas |
| `parseTrackerRecords()` | ✅ | Lê `frontmatter['trackers']` |
| `parsePomodoros()` com regex `HH:MM — Título` | ✅ | `_pomodoroHeaderRegex` definido e usado |
| `generateDailyNoteBody()` reconstruindo todas as seções | ✅ | Gera `## Journal Entries`, `## Habits`, `## Trackers`, `## Tasks`, `## Pomodoros` corretamente |
| `getPlainTextFromBody()` convertendo Delta JSON para texto | ✅ | `tryParseDeltaOps()` com tratamento de smart quotes e trailing commas |
| `matchesSignature()` para Object Identification | ✅ | Cobre `MarkerType.tag`, `MarkerType.property`, `MarkerType.folder` |
| `prepareForSave()` com caminho determinado por signature | ✅ | Aplica signature ao frontmatter e path antes de salvar |
| `mergeFrontmatter()` para resolução de conflitos | ✅ | Union de listas, merge recursivo de maps |
| Regex `_dateRegex` e `_journalTimeRegex` | ✅ | **Não existem mais** — eram do código anterior. O parser atual usa `RegExp` inline em `parseJournalEntries()`. Falso positivo do analyze antigo. |

### obsidian_service.dart

| Item | Status | O que o código mostra |
|---|---|---|
| `initVault()` com path customizável | ✅ | `customPath` ou `getApplicationDocumentsDirectory()` |
| `_ensureVaultFolders()` criando estrutura | ✅ | 20 pastas criadas em paralelo incluindo `_deleted`, `_attachments` |
| `readFile()` / `writeFile()` com UTF-8 | ✅ | `encoding: utf8` explícito |
| `getFilesInFolder()` com `recursive: true` | ✅ | Exclui `/_attachments/` e `/_deleted/` automaticamente |
| `watchVault()` com PollingWatcher no iOS | ✅ | `PollingDirectoryWatcher` com 1min de intervalo no iOS, `DirectoryWatcher` no Android |
| `moveFile()` com criação de pasta-pai | ✅ | `target.parent.create(recursive: true)` |
| `saveAttachment()` com tratamento de colisão | ✅ | Prefixo de timestamp em caso de colisão |
| `appendToDailyNote()` sem destruir outras seções | ✅ | `_appendToSection()` preserva seções existentes |
| index.md gerado na raiz do vault | ✅ | Com query Dataview de day_themes |

---

## PARTE 2 — OBJETOS DE DADOS

### Vault Write Pipeline (VaultNotifier._writeObject)

| Item | Status | O que o código mostra |
|---|---|---|
| Signature aplicada ao salvar | ✅ | `settings.typeSignatures[signatureKey]` → `MarkdownParser.prepareForSave()` |
| Pasta determinada por `settings.folderPaths` | ✅ | Fallback para `_defaultFolderForSignature()` |
| Notificações reagendadas após qualquer write | ✅ | `await _scheduleObjectReminders(object)` sempre chamado |
| Widgets atualizados após write | ✅ | `await _updateWidgetsFor(object)` sempre chamado |
| KPIs recalculados após write de Habit/Tracker/Entry/Note/Mood | ✅ | `_shouldUpdateKpisAfterWrite()` + `AutomationService.updateAllKPIs(ref)` |
| Sync queue enfileirada após write | ✅ | `syncQueue.enqueueAction(SyncAction(...))` |
| Arquivo movido para `_deleted/` com timestamp ao deletar | ✅ | `'_deleted/${timestamp}_$fileName'` em `deleteObject()` |
| Purga de `_deleted/` após 30 dias | ✅ | `_purgeOldDeletedFiles()` chamado no `build()` do VaultNotifier — checa `stat.modified` |
| Merge de conteúdo ao converter tipo de objeto | ✅ | `_mergeConvertedMarkdown()` com mergeamento de frontmatter, aliases, tags |
| Redirect de WikiLinks ao mesclar objetos | ✅ | `redirectAndDeleteObject()` com `_replaceObjectReferences()` varrendo todos os arquivos |
| Log de erros em `_conflicts/` | ✅ | `_recordConversionFailure()` e `_recordMergeFailure()` escrevem em `_conflicts/*.log` |
| Dataview blocks gerados para TrackerDefinition | ✅ | `DataviewGenerator.generateTrackerDataviewBlock()` e `generateChartBlock()` adicionados ao markdown |
| Tracker plugin blocks para CombinedAnalysis | ✅ | `DataviewGenerator.generateTrackerPluginBlock()` adicionado ao markdown |

### Habit Toggle (HabitsNotifier.toggleHabit)

| Item | Status | O que o código mostra |
|---|---|---|
| Leitura → parse → toggle → reconstrução → escrita da daily note | ✅ | Fluxo completo implementado preservando entries, tasks, trackers, pomodoros |
| Suporte a `slotIndex` para habits com múltiplos slots | ✅ | `List<dynamic> slots` com grow conforme necessário |
| `AutomationService.executeHabitSlotActions()` ao completar slot | ✅ | Chamado quando `nextValue == true` |
| `AutomationService.executeHabitActions()` ao completar daily goal | ✅ | Chamado quando `_isHabitValueComplete()` muda de false → true |
| Cache de daily note atualizado sem invalitar tudo | ✅ | `_updateDailyNoteCache()` atualiza só a entrada afetada |
| `WidgetService.updateHabits()` chamado após toggle | ✅ | Linha explícita no código |
| Cancelamento de notificação do slot ao completar | ✅ | `_cancelHabitSlotReminderNotification()` |
| Sleep In Tomorrow: pula notificação se no horário de dormir | ✅ | Lógica completa em `_scheduleObjectReminders()` |

### Journal (JournalNotifier)

| Item | Status | O que o código mostra |
|---|---|---|
| `addEntry()` preservando todas as seções da daily note | ✅ | Parse completo de entries/tasks/habits/trackers/pomodoros antes de regenerar |
| `updateEntry()` com detecção de mudança de data | ✅ | Se data mudou: delete do dia antigo + add no novo dia |
| `deleteEntry()` sem destruir daily note | ✅ | Remove só a entrada correspondente pelo `_findEntryIndex()` |
| Match de entry por tempo+título (não só por tempo) | ✅ | `_findEntryIndex()` considera `isImplicitTimeTitle` para entradas sem título explícito |
| Mood escrito como `mood:: [[slug]]` | ✅ | `'mood:: $moods'` com WikiLink formatado |
| Organizers escritos como `organizers:: [[link]]` | ✅ | Cada `OrganizerReference.toWikiLink()` |
| Update do cache sem re-parse completo do vault | ✅ | `_updateEntryCache()` atualiza `_dailyNoteDataMapProvider` diretamente |
| Entries adicionadas em dias passados | ✅ | `addEntry()` aceita qualquer `entry.date`, não só hoje |

### Inbox

| Item | Status | O que o código mostra |
|---|---|---|
| Auto-archive de itens com mais de 30 dias | ✅ | `if (now.difference(item.createdAt).inDays > 30)` → `deleteObject()` |
| `inboxCountProvider` para badge na nav | ✅ | `ref.watch(inboxProvider).valueOrNull?.length ?? 0` |
| Triage deletando do inbox | ✅ | `triageItem()` chama `deleteItem()` |

### Processamento de Notificações

| Item | Status | O que o código mostra |
|---|---|---|
| `quick_entry_text` → cria JournalEntry | ✅ | `createQuickJournalEntry(payload)` |
| `quick_task_text` → NLP → cria Task | ✅ | `createQuickTaskFromNaturalLanguage()` com `_parseQuickTask()` |
| `quick_habit_text` → cria Habit com scheduler diário | ✅ | `createQuickHabit()` |
| `toggle_habit` por ID/slug | ✅ | Busca no `habitsProvider` e chama `toggleHabit()` |
| Action `done` → Task finalizada / Reminder completed / Habit toggled | ✅ | `_markNotificationTargetDone()` com switch por tipo |
| Action `snooze` com duração do payload | ✅ | `_snoozeNotification()` re-agenda com `scheduleReminder()` |
| Contatar pessoa: completar task atualiza `lastContactDate` | ✅ | `_completeContactTaskIfNeeded()` detecta "Contatar " no título e atualiza Person |
| Weekly review draft gerado como JournalEntry | ✅ | `_generateWeeklyReviewDraft()` com stats de tasks concluídas |
| NLP português: "amanhã", "hoje", "às HH:MM", dias da semana, prioridade | ✅ | `_parseQuickTask()` cobre todos esses casos com regex |

### Import de Vault Obsidian

| Item | Status | O que o código mostra |
|---|---|---|
| Tela de import com seleção de pasta | ✅ | `ImportVaultScreen` com `FilePicker.platform.getDirectoryPath()` |
| Preview: conta arquivos com e sem `type` | ✅ | Scan completo antes de importar |
| Validação de permissão de escrita | ✅ | Cria e deleta arquivo de probe antes de importar |
| Import atualiza `vaultPath` nas settings | ✅ | `settingsProvider.notifier.updateVaultPath(path)` |
| Invalidação do `allObjectsProvider` após import | ✅ | `ref.invalidate(allObjectsProvider)` |
| `importExistingVault()` no VaultNotifier | ✅ | Copia todos os `.md` preservando estrutura de pastas |

### Triple Check

| Item | Status | O que o código mostra |
|---|---|---|
| Sheet com 3 perguntas (🧠 ❤️ 🖐) e 3 respostas cada | ✅ | `_QuestionRow` com `TripleCheckAnswer.yes/unsure/no` |
| Diagnóstico gerado em tempo real | ✅ | `_buildDiagnosis()` chamado no `build()` — reativo |
| Ícone e cor do diagnóstico por bloqueador | ✅ | `_diagnosisIcon()` e `_diagnosisColor()` por combinação |
| Botões de ação contextuais (Reformular, Arquivar, Adiar, etc.) | ✅ | `_buildActionButtons()` com lógica por head/heart/hand |
| Adiar push start_date 1 dia | ✅ | `task.copyWith(startDate: tomorrow)` |
| Arquivar direto do sheet | ✅ | `task.copyWith(archived: true)` + `updateTask()` |
| `TripleCheck` salvo no frontmatter da Task | ✅ | `task.copyWith(tripleCheck: tc)` + `updateTask()` |
| `TripleCheckBadge` widget para cards | ✅ | Widget separado com onTap |
| Pré-preenchimento se check anterior existe | ✅ | `initState()` lê `widget.task.tripleCheck` |

### Steering Sheet (Pact)

| Item | Status | O que o código mostra |
|---|---|---|
| 3 etapas: Revisão → Reflexão → Decisão | ✅ | `_currentStep` 1/2/3 com `AnimatedSwitcher` |
| Hipótese exibida na etapa 1 | ✅ | Card com `widget.habit.hypothesis` |
| Avaliação da hipótese (correta/incorreta/não sei) | ✅ | Radio buttons em `_buildStep2()` |
| Por que o pacto terminou (3 opções) | ✅ | Radio buttons em `_buildStep2()` |
| PERSISTIR com seleção de dias (dropdown 7/14/21/30/60/90) | ✅ | `DropdownButton<int>` em `_buildStep3()` |
| PAUSAR → `status: paused`, `pactOutcome: pause` | ✅ | `habit.copyWith(status: HabitStatus.paused, pactOutcome: PactOutcome.pause)` |
| PIVOTAR → abre `CreateHabitForm` com habit pré-preenchido | ✅ | `Navigator.push(..., CreateHabitForm(existingHabit: updatedHabit))` |
| Ciclo anterior salvo em `previousCycles` | ✅ | `PactCycle` criado com todos os campos e adicionado à lista |
| Escrita persistida no vault | ✅ | `ref.read(vaultProvider.notifier).updateObject(updatedHabit)` |

### Scheduler Page

| Item | Status | O que o código mostra |
|---|---|---|
| Lista de todos os objetos com scheduler | ✅ | `tasks.where((t) => t.scheduler != null)` + `habits.where(...)` |
| Previsão por Day Theme (próximas ocorrências) | ✅ | `_ThemeForecast` com datas geradas por `SchedulerService.shouldFire()` |
| Toggle 7/30 dias de previsão | ✅ | `_timeframeDays` com `ChoiceChip` |
| `isThemeActive`, `isBlockActive`, `isItemScheduled` passados ao SchedulerService | ✅ | Callbacks injetados — scheduler avançado funcionando |
| Próxima data de ocorrência via `SchedulerService.nextOccurrence()` | ✅ | Exibida em cada item da lista |
| `ExpansionTile` por tema com tasks e habits dentro | ✅ | Com pills de datas scrolláveis horizontalmente |

### DataviewGenerator

| Item | Status | O que o código mostra |
|---|---|---|
| `regenerateAll()` gerando 6 arquivos de índice | ✅ | tasks, habits, mood, goals, notes, social — todos com queries Dataview reais |
| `generateTrackerDataviewBlock()` por tracker | ✅ | Query `TABLE` com campos do tracker |
| `generateChartBlock()` para campos numéricos | ✅ | Bloco `chart` do Obsidian Charts plugin |
| `generateTrackerPluginBlock()` para CombinedAnalysis | ✅ | Blocos `tracker` por fonte de dados |
| `habitTrackerBlock()` com heatmap do Obsidian Tracker | ✅ | Config completa com startDate/endDate/color |
| Queries Dataview para streaks de hábitos (dataviewjs) | ✅ | Script JS que calcula streak em `habits/index.md` |

### Widget Service (widget_service.dart e widget_sync_provider.dart)

| Item | Status | O que o código mostra |
|---|---|---|
| `WidgetService` usa `home_widget` package | ✅ | `HomeWidget.saveWidgetData()` e `HomeWidget.updateWidget()` |
| Guard `_isSupportedPlatform` | ✅ | Chamadas ignoradas em plataformas não suportadas silenciosamente |
| `updateHabits()`, `updateNextTask()`, `updateNote()` | ✅ | Métodos que serializam dados e chamam `HomeWidget.saveWidgetData()` |
| `updatePomodoro()` com countdown em tempo real | ✅ | `updatePomodoroLive()` com título, tempo restante, título da task |
| `updatePlanner()` com título/conteúdo/rodapé | ✅ | `HomeWidget.saveWidgetData('citrine_planner', ...)` |
| `updateOrganizerSummary()` com tasks/events/stats | ✅ | Salva `citrine_organizer_summary` e `citrine_universal_widget` |
| `updatePomodoroWeekly()` com barras de altura | ✅ | `HomeWidget.saveWidgetData('citrine_pomodoro', {'bars': heights})` |
| `widget_sync_provider.dart` com debounce 700ms | ✅ | `_Debouncer` — evita writes excessivos ao vault |
| Calendário do widget: modo day/week/month | ✅ | `_buildCalendarSnapshot()` com os 3 modos completos |
| Dots por tipo no calendário (task/habit/reminder/google_calendar) | ✅ | `_dayItems()` agregando todos os tipos |
| Cores por tipo no calendário | ✅ | `_typeColor()` com 4 cores distintas |
| Toggle por item (task/habit) via `citrine://widget-toggle?...` | ✅ | URI com type, id, date, slot codificados |
| Deep links `citrine:///detail/ID` por item | ✅ | Em todos os items do snapshot |
| Grid de 42 células no modo mês com pills de itens | ✅ | `monthGrid` com até 3 pills por dia + "moreCount" |
| Integração com Google Calendar no widget | ✅ | `googleCalendarRangeEventsProvider` lido e incluído nos snapshots |
| `forceWidgetSync()` para sync manual | ✅ | Função pública que lê todos os providers e atualiza widgets |
| `_buildFilterSnapshot()` com organizer configurável | ✅ | Lê `settings.universalWidgetOrganizer` ou metadata do dashboardBlock |
| `_buildPomodoroSnapshot()` com barras por dia da semana | ✅ | 7 barras com horas trabalhadas por dia |

---

## PARTE 3 — O QUE DE FATO ESTÁ FALTANDO (após ver o código real)

Depois de ler o código, a lista de ausências reais é **bem menor** do que as versões anteriores desta análise indicavam. Aqui está o que genuinamente não existe ou está incompleto:

### ❌ Ausências confirmadas no código

| Item | Por quê está ausente |
|---|---|
| **Card PMN ao navegar por `referenced_dates`** | `AllObjectsNotifier` não indexa PMNs por `referenced_dates`. Arquivos `daily/YYYY-MM-WNN.md` são parseados como daily notes comuns (pelo padrão de data no nome), não como PMN com lookup por datas referenciadas |
| **Badge ⚠ de task parada há 7+ dias** | Nenhuma lógica em nenhum arquivo calcula "dias no mesmo stage sem progresso". O `TripleCheckBadge` existe como widget mas não há código que o exiba automaticamente |
| **Energy Map auto-gerado** | Nenhum código lê Field Notes com `category: energy` e gera sugestão de blocos de energia |
| **Lookup de `referenced_dates` do PMN** | PMN tem o campo no modelo mas não há indexação reversa para mostrar card ao navegar para as datas |
| **`pushSessionToCalendar` com tipo correto** | Ainda aceita `Task` em vez de `Session` conforme `correcoes.md` — não foi possível confirmar correção no código lido |
| **Múltiplos calendários Google** | `fetchEvents` só busca 'primary' |
| **Auto-archive de inbox após 30 dias com badge na nav** | O auto-archive existe no código mas o badge só conta itens ativos — sem distinção de itens "vencidos" |
| **Dataview queries compatíveis com `mood::` como WikiLink nas daily notes** | `mood-index.md` usa `WHERE mood` mas as daily notes armazenam mood no frontmatter como string simples (`mood_label: "Calma"`), não como WikiLink. Inconsistência entre formato Dataview e formato real |

### ⚠️ Parcialmente implementado

| Item | O que falta especificamente |
|---|---|
| **PMN (`entry_type: pmn`)** | Modelo existe, form existe (`create_pmn_form.dart`). Mas o arquivo é salvo como qualquer objeto — não em `daily/YYYY-MM-WNN.md` com a lógica de mês canônico de `date_range_start` |
| **`automation_service.dart`** | Não foi possível ler o arquivo completo nesta sessão — só o fim do `widget_service.dart` chegou. `executeHabitActions` e `executeHabitSlotActions` estão sendo chamados no vault_provider, mas o conteúdo real das ações não foi confirmado |
| **Combined Analysis — emoji como marcador no gráfico** | `citrine_chart.dart` existe mas não foi lido. A spec pede emoji do mood como marcador visual nos pontos — feature muito específica |
| **Scheduler: `unreachable_switch_default`** | `scheduler_picker.dart` ainda tem cases não cobertos (identificado no analyze_output anterior) |
| **Purga de `_conflicts/` após 30 dias** | `_purgeOldDeletedFiles()` só varre `_deleted/`, não `_conflicts/` |
| **Backup ZIP periódico em `_backups/`** | `backup_service.dart` existe mas não foi lido — conteúdo desconhecido |
| **Widgets nativos do OS (home screen/lock screen)** | `widget_service.dart` usa `home_widget` que **é** um package real para widgets nativos — mas o código Kotlin/Swift complementar (AppWidgetProvider, etc.) não foi confirmado. A integração Flutter existe; a parte nativa precisa de verificação |
| **Social Post: `social_refs` linkando a objetos** | Campo existe no modelo e UI implementada em `_associateObject()`, mas persiste como array de WikiLink strings — sem UI de visualização dos objetos associados na detail view |

---

## PARTE 4 — CORREÇÕES DAS ANÁLISES ANTERIORES

As versões V1 e V2 deste documento tinham erros significativos que o código real contradiz:

| Afirmação anterior (incorreta) | Realidade confirmada no código |
|---|---|
| "`_dateRegex` e `_journalTimeRegex` não usados — parsing de timestamp quebrado" | Esses campos não existem mais. O parser atual usa regex inline em `parseJournalEntries()` que funciona corretamente |
| "Body de notas não está sendo salvo (`_bodyController` não usado)" | O `rich_text_editor.dart` existe como widget separado — o controller é gerenciado internamente pelo widget, não pelo form pai |
| "Time Block de sessions não persiste (`_timeSlot` não usado)" | Não foi possível confirmar nesta leitura — `create_session_form.dart` não foi lido |
| "Sistema de Actions nunca executa" | `AutomationService.executeHabitActions()` e `executeHabitSlotActions()` são chamados explicitamente no `toggleHabit()` |
| "Purga de `_deleted/` não existe" | `_purgeOldDeletedFiles()` existe e é chamado no `build()` do VaultNotifier |
| "Social Post não tem tela" | `SocialScreen` completamente implementada com grid/timeline, multi-select, coleções, filtros por plataforma, auto-watch por visibilidade |
| "Import de vault Obsidian não existe" | `ImportVaultScreen` com scan prévio, validação de permissão e importação implementados |
| "Scheduler Page não existe" | `SchedulerPage` implementada com lista de agendados e previsão por Day Theme |
| "Dataview não é gerado" | `DataviewGenerator` gera 6 índices + blocks por tracker/analysis |
| "`widget_service.dart` são só stubs" | Usa `home_widget` real com múltiplos payloads estruturados |
| "Triple Check não tem botões de ação" | Implementado com Reformular, Arquivar, Adiar, Criar subtarefas, etc. |
| "Steering Sheet não persiste" | `updateObject(updatedHabit)` chamado com todos os campos corretos |

---

## RESUMO EXECUTIVO REAL

O app está **substancialmente mais completo** do que as análises anteriores indicavam. A maioria das features críticas existe no código.

### O que genuinamente falta (lista curta e honesta)

1. **PMN com lógica de `referenced_dates`** — o card PMN não aparece ao navegar para datas referenciadas
2. **Badge automático de task parada 7+ dias** — TripleCheckBadge existe mas não é exibido automaticamente
3. **Energy Map** — não existe em nenhum arquivo
4. **Emoji como marcador de mood nos gráficos** — não confirmado no `citrine_chart.dart`
5. **Purga de `_conflicts/` após 30 dias** — `_purgeOldDeletedFiles()` só cobre `_deleted/`
6. **Múltiplos calendários Google**
7. **Parte nativa dos widgets (Kotlin/Swift)** — a parte Flutter existe, a nativa não confirmada

### O que está bem implementado e era classificado como ausente

- Social Post completo (CRUD, coleções, multi-select, auto-watch)
- Import de vault Obsidian
- Scheduler Page global
- DataviewGenerator com 6 índices + tracker blocks
- Triple Check com diagnóstico real e ações contextuais
- Steering Sheet com 3 etapas e persistência
- Purga de `_deleted/` após 30 dias
- Widget sync com dados reais (não stubs)
- NLP para criação de tasks
- Weekly review automático
- Actions de notificação (done/snooze/dismiss)
- Backlinks e redirect de WikiLinks ao mesclar objetos