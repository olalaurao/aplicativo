# 2026-06-07 16H 
 Gap Analysis Citrine × Guidelines V3 — Baseado no Código Real
> Análise feita com base no código Dart lido diretamente: `automation_service.dart`, `markdown_parser.dart`, `vault_provider.dart`, `widget_sync_provider.dart`, `widget_service.dart`, `dataview_generator.dart`, `obsidian_service.dart`, `triple_check_sheet.dart`, `steering_sheet.dart`, `import_vault_screen.dart`, `scheduler_page.dart`, `social_screen.dart`.
>
> **Legenda:** ✅ Implementado e confirmado no código · ⚠️ Parcial ou com ressalva real · ❌ Ausente ou stub



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

---

## PROGRESSO DE IMPLEMENTAÇÃO (sessão 2026-06-07)

| Item | Status | Arquivo(s) alterado(s) |
|---|---|---|
| Purga de `_conflicts/` após 30 dias | ✅ Feito | `vault_provider.dart` |
| Backup ZIP periódico em `_backups/` | ✅ Feito | `vault_provider.dart` |
| `mood` como inline WikiLink (`mood:: [[slug]]`) | ✅ Feito | `markdown_parser.dart`, `journal_entry.dart` |
| Badge automático task parada 7+ dias (`needsTripleCheckBadge`) | ✅ Feito | `task_model.dart` |
| Parser PMN + `referenced_dates` | ✅ Feito | `journal_entry.dart` |
| `fetchEvents` de múltiplos calendários visíveis | ✅ Feito | `google_calendar_service.dart` |
| Auto-archive de inbox após 30 dias | ✅ Feito | `vault_provider.dart` |
| `unreachable_switch_default` no scheduler_picker | ✅ Feito | `scheduler_picker.dart` |
| `TripleCheckBadge` exibido automaticamente na UI | ✅ Feito | `organizer_tasks_widget.dart`, `planner_screen.dart` |
| `social_refs` renderizados na detail view e com indicador visual | ✅ Feito | `universal_detail_view.dart`, `social_screen.dart`, `social_post_grid_card.dart` |
| Emoji de mood como marcador visual no `citrine_chart.dart` | ✅ Feito | `citrine_chart.dart`, `combined_analysis_screen.dart` |
| `energy_map.dart` — leitura de Field Notes `category: energy` | ✅ Feito | `energy_map.dart`, `dashboard_provider.dart`, `home_screen.dart` |
| Card PMN na timeline por indexação de `referenced_dates` | ✅ Feito | `journal_screen.dart` |
| `AppWidgetProvider.kt` nativo Android | ✅ Feito | Encontrados em `android/app/src/main/kotlin/com/productivity/citrine/` (ex: `CitrineCalendarWidgetProvider.kt`, `CitrineTasksWidgetReceiver.kt`, etc) e declarados no `AndroidManifest.xml` |
