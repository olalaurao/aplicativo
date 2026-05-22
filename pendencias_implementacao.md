# Pendências de Implementação - Citrine

Auditoria feita a partir de `guidelines.md`, `tarefas.md`, `tarefas2.md` e do código em `lib/`.
Este arquivo usa o código como fonte de verdade: itens marcados como concluídos nos documentos foram reavaliados quando há botão morto, WIP explícito, fluxo errado ou persistência incompleta.

## 1. Corrigir o menu global de criação

**Problema:** o FAB abre `CreateMenuSheet`, mas alguns cartões prometem ações que o usuário não consegue executar.

- [x] `Snapshot`, `Scan document` e `Voice note` deixaram de mostrar apenas "Work In Progress" em `lib/ui/widgets/create_menu_sheet.dart`.
- [x] `Pomodoro` abre `PomodoroScreen`, iniciando o fluxo real de foco.
- [x] `Tracker` abre `CreateTrackerForm`, criando a definição de tracker em vez de registrar dados.

**Implementar assim:**

1. [x] Trocar o cartão `Tracker` para abrir `CreateTrackerForm`.
2. [x] Trocar o cartão `Pomodoro` para abrir `PomodoroScreen` ou um `QuickPomodoroSheet` com item vinculado, blocos e duração.
3. [x] Implementar `Snapshot` como captura de foto + `Snapshot` salvo em `snapshotsProvider`, com arquivo em `_attachments/` e vínculo opcional com objeto.
4. [x] Implementar `Voice note` com `record`, salvando áudio em `_attachments/` e criando uma Entry com embed.
5. [x] Implementar `Scan document` com captura/importação real; cria anexo e nota.

## 2. Fechar botões visíveis sem ação

**Problema:** várias telas têm botões/chips clicáveis com `onTap/onPressed` vazio, gerando frustração no fluxo de uso.

**Implementar nesta ordem:**

1. [x] `MoreScreen`: substituir snackbars "será implementado em breve" para `Arquivos`, `Lixeira`, `Categorias`, `Aparência` e `Sobre` por telas reais ou remover os itens.
2. [x] `SettingsScreen`: implementar `ADICIONAR REGRA` em regras de auto-categorização e o diálogo de cores de categorias.
3. [x] `DayThemeScreen`: botão `+` deve abrir criação/edição de tema de dia e time blocks.
4. [x] `PeopleScreen` e `ResourcesScreen`: botões `+` devem abrir `CreatePersonForm` e `CreateResourceForm`.
5. [x] `PomodoroScreen`: botão picture-in-picture e botão `+` precisam executar ação real.
6. [x] `UniversalDetailView`: chips/propriedades que hoje só mostram snackbar ou não fazem nada devem abrir editores inline e persistir via `VaultNotifier.updateObject`.

## 3. Padronizar CRUD e persistência por objeto

**Problema:** há muitos `add*`, mas nem todos têm `update`, `delete`, `archive` e restore por tipo. Isso deixa edição/deleção inconsistente.

**Implementar assim:**

1. [x] Criar uma interface única em `VaultNotifier` para `createObject`, `updateObject`, `archiveObject`, `deleteObject`, `restoreObject`.
2. [x] Fazer todos os providers chamarem essa camada, em vez de cada notifier escrever arquivo de um jeito.
3. [x] Garantir update para Project, Person, Note, Snapshot, Mood e Analysis, não apenas add.
4. [x] Garantir delete/archive por tipo para Task, Habit, Session, Tracker, Project, Person, Resource, Goal, Note, Reminder, Snapshot e Analysis.
5. [x] Toda operação deve:
   - atualizar estado local;
   - escrever markdown;
   - invalidar providers afetados;
   - enfileirar sync;
   - mostrar undo quando for destrutiva.

## 4. Consolidar o formato canônico do vault

**Problema:** a spec pede arquivos filtrados por `type` e `categories`, mas o código mistura `app/`, pastas por tipo, `daily/` e `trackers/records/`.

**Implementar assim:**

1. [x] Decidir e documentar um único padrão V1: preferencialmente `app/SLUG.md` com `type`, `categories`, `created_at`, `updated_at`, `archived`.
2. [x] Fazer `MarkdownParser.prepareForSave` ser o único caminho de escrita de objetos.
3. [x] Criar migração/leitura compatível para arquivos antigos em `tasks/`, `habits/`, `trackers/`, etc.
4. [x] Tracking records devem seguir uma regra clara: ou ficam em daily notes como `trackers:` no frontmatter, ou como arquivos próprios, mas não os dois sem sincronização.
5. [x] Adicionar testes de ida-e-volta: objeto -> markdown -> objeto para cada tipo.

## 5. Completar Journal Entry

**O usuário ainda não consegue fazer tudo que a spec promete.**

- O editor existe, mas ainda há botão vazio na toolbar.
- Fotos funcionam como anexos, mas precisam de inserção inline consistente no rich text.
- Location é manual; auto GPS ainda precisa integração real.
- Templates existem como picker, mas precisam CRUD de templates.
- Organizer picker salva slugs simples; precisa preservar tipo do organizer.

**Implementar assim:**

1. [x] Ligar todos os botões da toolbar do `RichTextEditor` e do form.
2. [x] Salvar fotos como `![[arquivo]]` no corpo, além da strip de thumbnails.
3. [x] Usar `geolocator`/permissão já solicitada para location real, com fallback manual.
4. [x] Criar `Template` como Note especial ou objeto próprio e abrir gerenciador de templates.
5. [x] Salvar organizers como `OrganizerReference(type, slug)` e renderizar chips agrupados.
6. [x] Ao salvar, reconstruir `daily/YYYY-MM-DD.md` sem perder hábitos, trackers, tarefas ou pomodoros do mesmo dia.

## 6. Completar Notes

**Problema:** `CreateNoteForm` mostra chips de Organizers, Tags, Pin e Date com `onTap` vazio.

**Implementar assim:**

1. [x] Organizers: abrir picker reutilizável e salvar referências.
2. [x] Tags: editor de tags com normalização para frontmatter.
3. [x] Pin: persistir campo `pinned: true` e refletir em listas/home.
4. [x] Date: editar `created_at`/data de referência da nota.
5. [x] Text note: suportar embeds `![[note]]` renderizados.
6. [x] Outline note: garantir indentação, drag, focus mode e persistência da árvore.
7. [x] Collection note: trocar contagem por split de texto por JSON/YAML estruturado, com schema e itens reais.

## 7. Completar Task e subtarefas

**O que falta para o usuário:** transformar subtask em task, sessões temáticas de subtasks, links/participantes/lugares completos e reflexão persistida com qualidade.

**Implementar assim:**

1. [x] Adicionar ação "Transformar em tarefa" em cada subtask, criando `Task` com organizer/link para a tarefa mãe.
2. [x] Criar `SubtaskGroup` no modelo ou usar seções no markdown para sessões colapsáveis.
3. [x] Persistir reflection no markdown quando stage vira `finalized`.
4. [x] Revisar `scheduledTime`, `startDate`, `endDate`, `duration`, `all_day` e `until_done` para alimentar Planner sem hacks.
5. [x] Garantir drag/reorder de subtasks com escrita no arquivo.

## 8. Completar Calendar Session

**Problema:** a tela existe, mas alguns chips importantes não fazem nada.

- Botão de delete/subtask no form tem `onPressed` vazio.
- Chips `Objectives`, `Time spent` e `Reminder` estão sem ação.
- `Add to timeline` existe, mas precisa impacto real no timeline.

**Implementar assim:**

1. [x] Objectives: abrir picker de Goal/Project/Task e salvar links.
2. [x] Time spent: calcular a partir de Pomodoros ou permitir ajuste manual.
3. [x] Reminder: abrir `ReminderConfigSheet` e agendar notificação.
4. [x] Delete subtask: remover item e atualizar controladores.
5. [x] `Add to timeline`: quando ativo, sessão deve aparecer no Timeline/Organizer timeline.
6. [x] Move modal deve persistir data, hora, duração e time block.

## 9. Completar Reminders e notificações

**Problema:** `NotificationService` agenda notificações, mas actions de notification ainda imprimem logs e não alteram objetos.

**Implementar assim:**

1. [x] `Mark as done`: resolver payload para objeto e completar Task/Reminder/Habit slot.
2. [x] `Snooze`: reagendar usando configuração do reminder, não valor fixo.
3. [x] `Dismiss`: registrar dismissal quando o objeto pedir histórico.
4. [x] No form de Reminder, ligar organizer chip, scheduler e time block.
5. [x] Criar tela/lista de reminders ativos e expirados.

## 10. Completar Pomodoro

**Problema:** o timer roda, mas partes prometidas ainda não viram dado útil.

**Implementar assim:**

1. [x] Ao completar ou salvar sessão incompleta, escrever `## Pomodoros` no daily note.
2. [x] Vincular pomodoro a Task/Habit/Goal/Project e atualizar KPI `time_spent`.
3. [x] Botão "Agendar Pomodoro" deve criar `CalendarSession` ou `Reminder`, não apenas snackbar.
4. [x] Foreground notification precisa ter ações Pause/Resume/Stop conectadas ao provider.
5. [x] Histórico deve vir de `PomodoroSession` persistido, não só memória.

## 11. Completar Planner

**O usuário já vê Day/Week/Month, mas ainda faltam garantias de ação real.**

**Implementar assim:**

1. [x] Todo drag/drop deve persistir no objeto e reescrever markdown.
2. [x] Backlog -> Dia deve definir data/hora e remover status backlog.
3. [x] Quick complete deve oferecer undo real e reflection prompt para Task finalizada.
4. [x] Evento Google deve ter botão "Open in Google Calendar" com `url_launcher`.
5. [x] Implementar associação de evento Google a Task/Project.
6. [x] Habits negativos, slots e linked tracker precisam abrir record form no momento correto.

## 12. Completar Trackers e Records

**Problema:** existe form de record e form de tracker, mas o fluxo global ainda confunde criar tracker com registrar dado.

**Implementar assim:**

1. [x] Separar claramente:
   - `CreateTrackerForm`: cria/edita definição.
   - `CreateRecordForm`: registra instância de um tracker existente.
2. [x] History icon por campo deve abrir últimos valores reais e permitir copiar.
3. [x] Gear icon por campo deve editar configuração do campo sem sair do record.
4. [x] Media field deve salvar arquivo e valor estruturado.
5. [x] Section menu deve implementar reorder, archive, duplicate, show archives e delete.
6. [x] Statistics view deve permitir criar/remover summaries e charts persistidos no tracker.

## 13. Completar Combined Analysis

**Problema:** a tela calcula séries temporárias em estado local; falta objeto de análise persistente.

**Implementar assim:**

1. [x] Criar CRUD de `CombinedAnalysis` com title, description, data_sources, chart configs.
2. [x] Adicionar entrada "Análise" na área de Trackers e/ou Home.
3. [x] Picker de fontes deve salvar cor/label/field/source type.
4. [x] Calendário mensal deve carregar dots a partir do objeto salvo.
5. [x] Charts multi-série devem ser configuráveis e persistidos.
6. [x] Mood como fonte deve usar todas as entries do dia, não só a primeira.

## 14. Completar Goals, Projects e KPI Engine

**Problema:** KPI existe, mas algumas fontes são aproximadas e auto-complete não executa ações.

**Implementar assim:**

1. [x] Substituir contagem de collection por parse estruturado de Collection Note.
2. [x] `entryCount` deve usar backlinksProvider e organizers de forma consistente.
3. [x] Implementar auto-complete de KPI: quando `current >= target`, marcar concluído e disparar ação configurada.
4. [x] Project detail deve expor edição inline de state, priority, due date, KPIs e tarefas vinculadas.
5. [x] Goal detail deve permitir criar sessão, reminder, snapshot e KPI direto da tela.

## 15. Completar People

**Problema:** há lista e formulário, mas o CRM automático precisa ficar confiável para o usuário.

**Implementar assim:**

1. [x] Calcular `last_contact_date` por backlinks reais, journal entries e eventos.
2. [x] `AutomationService.checkPersonContacts` deve criar ou atualizar uma única task "Contatar [nome]" por pessoa atrasada.
3. [x] Ao concluir essa task, atualizar `last_contact_date` e remover/arquivar a tarefa automática.
4. [x] Detail view deve mostrar histórico de contatos e menções navegáveis.
5. [x] Permitir editar `contact_frequency` inline.

## 16. Completar Resources

**Problema:** grid/lista existem, mas a spec prevê configuração de filtros por propriedades e entrada via Web Clipper/Obsidian.

**Implementar assim:**

1. [x] Settings -> Resources: tela para regras por tipo/status/tags/propriedades.
2. [x] Refiltrar resources usando as regras, não apenas campos fixos.
3. [x] Cover image deve renderizar WikiLink embed e URL externa.
4. [x] Star rating deve persistir imediatamente e aceitar escala configurável.
5. [x] Detail view deve expor synopsis, links e mentions com edição.

## 17. Completar Search, Command Center e Inbox

**Problema:** Search existe; Command Center e Inbox existem de forma parcial ou fora do fluxo principal.

**Implementar assim:**

1. [x] Search deve indexar todos os corpos de markdown, frontmatter, tags, categories e backlinks.
2. [x] Resultado deve abrir a tela correta e destacar trecho/snippet.
3. [x] Command Center deve ser acessível por gesto/atalho e executar comandos reais.
4. [x] Inbox deve permitir capturar, converter para Task/Entry/Note e remover item triado.

## 18. Completar Day Themes e Time Blocks

**Problema:** modelo/tela existem, mas a criação e o uso ainda não estão completos.

**Implementar assim:**

1. [x] Tela de CRUD para Day Theme.
2. [x] CRUD de Time Blocks com nome, cor, hora inicial/final.
3. [x] Planner deve agrupar sessões/hábitos por block.
4. [x] Scheduler deve usar `days_of_theme` e `days_with_block`.
5. [x] Move Session sheet deve listar blocks reais do tema do dia.

## 19. Completar Google Calendar e Google Drive

**Google Calendar:**

1. [x] Botão "Open in Google Calendar" deve usar `htmlLink`/URL real.
2. [x] Criar link persistido entre evento Google e Task/Project/Session.
3. [x] Permitir importar evento como sessão ou task.
4. [x] Tratar auth desconectado com CTA claro no Planner.

**Google Drive:**

1. [x] `fetchRemoteFiles` precisa ser recursivo; hoje busca só filhos diretos da pasta raiz.
2. [x] Resolver conflitos com tela de comparação, não só merge automático ou `_conflicts`.
3. [x] Persistir base hash por arquivo para detectar conflito corretamente.
4. [x] Mostrar fila offline e erros de sync ao usuário.

## 20. Completar Widgets nativos

**Problema:** `WidgetService` só envia dados simples para alguns widgets; a tela de configuração é mockup.

**Implementar assim:**

1. [x] Quick-add widget: botões Journal Entry e Add Task com deep links.
2. [x] Calendar widget: week/month com dots e abertura de Planner por data.
3. [x] Category widget: filtro configurável por categoria/condição.
4. [x] Obsidian Note widget: selecionar nota e renderizar conteúdo.
5. [x] Widget configuration sheet real, aberto pelo fluxo nativo.
6. [x] Android/iOS: revisar receivers, intents, deep links e atualização em background.

## 21. Ajustes finais de UX e consistência visual

**Implementar assim:**

1. [x] listar tudo o que for WIP em um novo arquivo .md
2. [x] Usar a mesma linguagem em inglês
3. [x] Reduzir cards aninhados e botões arredondados grandes onde ícones bastam.
4. [x] Garantir que todo botão visível tenha feedback: navegação, sheet, salvamento ou estado disabled com motivo.
5. [x] Adicionar empty states com CTA real em todas as telas.
6. [x] Rodar auditoria mobile: textos não podem estourar em botões/chips/cards.

## 22. Testes necessários antes de considerar concluído

1. [x] Testes de parser markdown para daily notes, tasks, habits, trackers, notes, people e resources.
2. [x] Testes de providers para add/update/archive/delete/restore por tipo.
3. [x] Teste de fluxo: criar Task -> aparece no Planner -> concluir -> reflection -> markdown atualizado.
4. [x] Teste de fluxo: criar Entry com mood/foto/location/organizers -> daily note preserva outras seções.
5. [x] Teste de fluxo: criar Tracker -> registrar Record -> chart/statistics/analysis refletem dado.
6. [x] Teste de fluxo: Pomodoro vinculado -> daily note -> KPI time_spent.
7. [x] Teste de UI com golden/screenshot nas telas principais: Home, Journal, Planner, Organize, Trackers, More, Settings.
8. [x] Rodar `flutter analyze` e `flutter test` a cada fase.
