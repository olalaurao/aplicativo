V2.3.4 — pushSessionToCalendar
Problema: O upgrade.md diz que pushSessionToCalendar já está implementado e só falta "ativar no ⋯ menu". Mas o método na google_calendar_service.dart é pushTaskToCalendar(Task task) — recebe Task, não Session. Não existe pushSessionToCalendar.
Correção: Renomear/criar pushSessionToCalendar aceitando o objeto correto (provavelmente a Task que representa a session no vault atual), ou criar um método separado. Verificar qual tipo representa "Calendar Session" no vault e adaptar.
V2.6.2 — Auto-archive inbox (30 dias)
Problema: upgrade.md L277 especifica: "itens no Inbox com mais de 30 dias → mover para _deleted/ com aviso". Não existe nenhuma referência a auto-archive, purge, ou timer de 30 dias no InboxNotifier.
Correção: Adicionar em InboxNotifier.build() (ou em método chamado na inicialização) lógica que filtra itens com createdAt > 30 dias e chama vaultNotifier.deleteObject(item) com aviso via Snackbar.
V2.6.2 — Badge de contagem no ícone/More tab
Problema: L276 especifica badge com contagem de itens não triados. Não foi encontrada referência de badge conectado ao inboxCountProvider na shell/navegação.
Correção: No navigation_provider.dart ou no widget da bottom nav, ref.watch(inboxCountProvider) (L2376 existe no vault_provider) e exibir Badge sobre o ícone do More/Inbox tab.
V2.7.4 — Templates pré-definidos (built-in library)
Problema: L306 especifica 5 templates instalados na primeira abertura ("Reunião 1:1", "Weekly Review", "Leitura", "Sprint Planning", "Projeto novo"). Não existe código de seed/instalação desses templates.
Correção: Adicionar em TemplatesNotifier.build() verificação: se a lista de templates estiver vazia (primeiro uso), criar e persistir os 5 templates built-in via addTemplate().
V2.8.1 — Subtask Sessions (grupos temáticos dentro de Task)
Problema: L322 especifica {id, name, subtaskIds} dentro da Task, header colapsável, drag entre sessões. O Subtask model atual tem isHeader: bool para simular headers, mas não existe um sessions array com estrutura própria no frontmatter da task.
Correção: Adicionar List<SubtaskSession> sessions ao Task model, onde SubtaskSession = {id, name, subtaskIds}. Persistir como sessions: [...] no frontmatter. Implementar UI de header colapsável usando isHeader ou um novo mecanismo.
V2.8.3 — actual_minutes derivado de Pomodoro
Problema: L336–337 especifica "Estimado: 45min | Real: 1h 12min" com barra de progresso, onde actual_minutes é derivado de sessões Pomodoro. Campo estimatedMinutes existe, mas não há campo actual_minutes nem lógica de derivação.
Correção: Adicionar getter int get actualMinutes na Task derivado de pomodoroCount * 25 (ou lendo sessões Pomodoro linkadas pelo id). Exibir no detail view no universal_detail_view.dart.
V2.9.1 / V2.9.2 — voice_recording_sheet ainda referenciada
Problema: O upgrade.md L349–352 diz explicitamente "não quero usar, retire do app" para voice recording e speech-to-text. Mas voice_recording_sheet.dart ainda existe E ainda é importada em:
journal_screen.dart L10
create_voice_note_form.dart L7
create_task_form.dart L11
Correção: Remover o arquivo voice_recording_sheet.dart. Remover todos os imports e qualquer UI que o invoca. Remover create_voice_note_form.dart se ele só serve voice notes.
V2.10 — Widgets nativos todos stubados ("Native widgets disabled")
Problema: Toda a V2.10 (V2.10.1 a V2.10.6) está marcada ✅ no upgrade.md. Mas:
widget_service.dart: todos os métodos são stubs vazios com comentário // Native widgets disabled
widget_sync_provider.dart: retorna null, comentário // Native widgets disabled - empty provider
Não existe CitrineWidgetReceiver.kt nem citrine_widget_info.xml no android/
Não existe nenhum layout XML de widget em android/app/src/main/res/xml/
Correção: Esta fase inteira não está implementada. Marcar como ❌ no upgrade.md. Para implementar: criar CitrineWidgetReceiver.kt, citrine_widget_info.xml, layouts XML dos widgets, e substituir os stubs do widget_service.dart por chamadas reais ao home_widget package.
V2.11 — analysesProvider não existe no vault_provider
Problema: L101 diz analysesProvider deve carregar todos os analyses/*.md. O provider existente é combinedAnalysisProvider (via CombinedAnalysisNotifier). Não existe alias/export chamado analysesProvider.
Correção: Ou renomear para analysesProvider para ficar consistente com o nome citado no upgrade.md, ou garantir que todos os pontos que referenciam analysesProvider usem combinedAnalysisProvider. A inconsistência de nomenclatura pode causar confusão futura.
V2.11.2/3 — Obsidian Charts e Tracker plugin output ✅
Problema: L469–497 especificam que ao salvar definição de tracker/análise, o obsidian_service.dart gera blocos chart e config do Tracker plugin. Não existe nenhuma lógica disso no obsidian_service.dart atual (5KB, muito simples).
Correção: Implementar em obsidian_service.dart (ou no dataview_generator.dart) método generateChartBlock(TrackerDefinition) e generateTrackerPluginBlock(CombinedAnalysis) que retornam as strings de bloco. Chamar ao escrever arquivos de definição.
V2.12.1 — Import de vault Obsidian existente ✅
Problema: L506 especifica tela "Importar vault existente" com picker de pasta, detecção de frontmatter compatível e import de notas sem frontmatter como Text Notes. Não existe nenhum arquivo ou tela para isso.
Correção: Criar import_vault_screen.dart + método no VaultNotifier que: (1) usa file_picker para selecionar pasta, (2) itera .md arquivos, (3) tenta parsear frontmatter, (4) se type presente → indexa, (5) se não → cria Note com body preservado.
V2.14.1 — Weekly Review automático ✅
Problema: L545 especifica template de revisão semanal gerado todo sexta/domingo com dados pré-preenchidos (hábitos, tasks, pomodoro, goals, mood). Nenhum código de geração automática ou agendamento de notificação semanal foi encontrado.
Correção: Adicionar em NotificationService agendamento de notificação recorrente semanal. Ao disparar, chamar método que gera Entry com os dados da semana pré-preenchidos via template "Weekly Review".
⚠️ Discrepâncias menores / inconsistências com guidelines.md

google_calendar_service.dart não tem fetchEvents por múltiplos calendários: L160 especifica "múltiplos calendários com cores distintas; toggle por calendário em Settings". O fetchEvents atual só busca 'primary' — sem suporte a múltiplos calendários.

NlpTaskParser não tem toggle de desabilitar via Settings: L361 diz "configurável: pode ser desligado em Settings". Não há referência a nlpEnabled ou similar nas settings. ✅ Adicionado o toggle de desabilitar o NlpTaskParser na settings_screen.dart e respectiva configuração.

V2.1.3 — seções de blocos no day view alternativo: O upgrade.md especifica um day view alternativo com cards colapsáveis por Time Block. Verificar se o planner_screen.dart (67KB) de fato implementa esse modo ou apenas usa a timeline linear. (Não foi possível confirmar no espaço disponível — recomendo verificar se existe um toggle "Blocos" vs "Timeline" na UI do planner.)

Resumo de prioridade para corrigir
Prioridade	Item
🔴 Alta	Remover voice_recording_sheet (instrução explícita do usuário no upgrade.md)
🔴 Alta	V2.10 inteiro está stubado — marcar como ❌ ou implementar
🟡 Média	Auto-archive inbox 30 dias
🟡 Média	Badge de inbox na nav
🟡 Média	Templates built-in seed
🟡 Média	actual_minutes derivado de Pomodoro
🟠 Baixa	pushSessionToCalendar renomear/corrigir
🟠 Baixa	analysesProvider vs combinedAnalysisProvider — padronizar nome
🟠 Baixa	Import vault Obsidian (V2.12)
🟠 Baixa	Weekly Review automático (V2.14.1)
🟠 Baixa	Obsidian Charts/Tracker plugin output (V2.11.2/3)