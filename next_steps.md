1: [x] na timeline, o entry journal ta com um erro do que ta aparecendo. ta tipo [{“insert”:”lorem ipsum/n”}], e eu quero que apareça oq eu digitei, já bonitinho incluindo formatação (negrito, mídia, etc)
2: [x] se certifique que todo tipo de notificação funciona - pop up, alarme e push
3: [x] as tarefas parecem estar duplicadas, e quando eu clico numa tarefa/evento, quero que apareça também as subtarefas
4: [x] tela habitos nao ta aparecendo - type map dynamic is not a subtype of list dynamic
5: [x] **Subtask sessions** (grupos temáticos colapsáveis dentro do painel de subtasks)
6: [x] coloca também todos os widgets que ta na dashboard uma versao deles pra pagina inicial
7: [x] faz quick add e shortcuts pra add entry, habit, etc
8: [x] faz widgets de quick add também pra colocar na tela de bloqueio (via widget de keyguard e notificação persistente de captura rápida).
   *Nota: O gatilho de botões físicos (home/volume) é restrito pelo Android OS para apps de terceiros, mas foi mitigado com a Notificação de Captura Rápida sempre acessível.*

## Status de validação - 2026-05-12

- [x] Corrigido resumo de organizer na dashboard para usar `OrganizerReference.slug/title`, sem acessar campo inexistente `id`.
- [x] Corrigida edição de journal entry: `CreateEntryForm` agora chama `JournalNotifier.updateEntry(...)` e substitui a entrada em `daily/YYYY-MM-DD.md`.
- [x] Dark mode revisado: telas principais utilizam `AppTheme` e cores dinâmicas.
- [x] Google Calendar Export: Implementado em UniversalDetailView com persistência de ID em Tasks.
- [x] Implementação de Widgets Nativos Detalhados (Planner Day/Week/Month, Pomodoro Weekly, Habit Grid).
- [x] Integração Completa Google Calendar (Visibilidade, Navegação e Menu de 3 pontos).
- [x] Sincronização Automática de Widgets via `WidgetSyncProvider`.
- [x] Rodar novamente `flutter analyze` e `flutter test` depois dos ajustes finais.


