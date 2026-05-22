# Citrine — Status de Ajustes Técnicos

Este arquivo detalha o progresso das pendências técnicas e refinamentos do aplicativo.
- [x] no object identification precisa ter a divisao por categoria e nao só dizer que é organizer (area, goal, etc)
- [x] preciso poder editar o tipo de qualquer objeto (tornar uma area em tarefa, etc). aí automaticamente adiciona os novos campos no arquivo md, e muda o layout do card pra nova categoria. e salva como categoria nova
- [x] editar organizers nao funciona, e quero poder editar familia depois de criado o objeto (um objeto solto quero colocar como subtipo de uma area que já existe ou uma nova)
- [x] alarme nao funciona ainda
- [x] na pesquisa do pomodoro, como tenho muitos objetos fica dificil achar o que quero. coloca uma pesquisa universal que puxa todas as notas do vault, listas com filtro por tipo de objeto
- [x] todos os procurar objetos/notas, precisam ter pesquisa, e listas com filtro por tipo de objetos (tarefas, areas, projetos etc e criar novo objeto
- [x] oq acontece quando eu crio um novo objeto pela pesquisa? ele vira de qual tipo? preciso conseguir editar esses objetos novos e os antigos, e o tipo deles a qualquer momento
- [x] revisa o dark mode, tem coisa que nao da pra ler, e coisa com fundo branco errado
- [x] opcao soneca/burnout: ter a opção de ignorar os alarmes de hábitos ate X dia e horario, mas aí quando eu acordar/abrir o app mostrar tudo q eu tinha planejado fazer nesse tempo
- [x] day times pros habitos - aí no planner/day ao inves de ficar tudo em cima, ficar ao longo do dia. aparecer no horário que tá o slot reminder
- [x] no planner visualizacao day, tava dando erro quando tento mudar a duração de uma tarefa ve se ja corrigiu
- [x] no planner visualizacao day quero redimensionar duraçao de tarefas arrastando, e que mesmo durações curtas de pra ver o nome da tarefa
- [x] arrumar o journal - nao ta atualizando com o passar dos dias, a entry de intem ta como se fosse hj
- [x] push quick add os botoes ainda nao funcionam
- [x] no journal quero poder ver de dias passados tbm, e poder adicionar entrada em qualquer dia passado, e que ao editar fique no dia certinho, e procurar entries de qualquer dia
- [x] agora ta tendo um titulo que ao descer fica fixo no topo, tira o titulo duplicado que nao ta fixo
- [x] em organizers, tarefas, resources, pessoas, habits, trackers, goals, notas quero poder filtrar por tudo, e adicionar campos, reordenar colunas, salvar filtros, ocultar campos, e adicionar campos personalizados 

## ✅ Concluído

### 🏗️ Arquitetura e Modelagem
- [x] **Modelos Resilientes**: `Task`, `Note`, `Resource` e `Person` atualizados com métodos `copyWith` e parsing robusto de tipos numéricos.
- [x] **Task Architecture**: Suporte nativo a `pomodoroCount`, `duration` e `scheduledTime`.
- [x] **Vault Consistency**: Cache do `VaultNotifier` sincronizado com mutações de arquivos.

### 🎨 UI/UX e Layout
- [x] **Localização PT-BR**: Todas as labels de tipos de objetos, estados de tarefas e prioridades traduzidas.
- [x] **UniversalDetailView**:
    - [x] Correção de **overflow** em propriedades (uso de Expanded/Ellipsis).
    - [x] Interatividade de propriedades (toque em Status/Prioridade abre o seletor).
# Citrine - Lista de Ajustes Técnicos Pendentes

### Dashboard
- [x] 1. O bloco `_buildJournalQuickAddBlock` deve estar no Dashboard por padrão.
- [x] 2. O bloco `_buildHabitProgressBlock` deve estar no Dashboard por padrão.

### Notificações e Lembretes
- [x] 3. Ao criar lembrete, ter as opções: Push, Popup (janela sobre o app/lockscreen) e Alarme (toca mesmo no silencioso).
- [x] 4. No momento as notificações e alarmes não estão funcionando, verificar permissões e configuração no Android (schedule exact alarm, etc).
- [x] 5. Lembrete: se tiver horario, ter X horas antes, X dias antes, tudo 100% editável. se nao tem hora só dia, ter no dia, X horario, ou X dias antes as X horas.

### Notes
- [x] 6. a listas do notes tao overflowing, e eu quero poder editar - filtrar as notas, reordenar, e salvar nessas listas.
- [x] 7. em todas as paginas de objetos, quero poder criar listas onde eu filtro e reordeno os objetos, e edito quais propriedades ficam visiveis (tipo o Notion).

### Forms
- [x] 8. os formularios tem mtos bugs, assertions de duration q nao foram setadas etc. vou criar tarefa, tem assertion de duration. o create_task_form.dart tem q ser o definitivo unificado.

### Resources
- [x] 9. o grid de resources deve ser lazy loading (mto pesado agora), e nao pode cortar a imagem. Corrigir tbm que tem "status" duplicado na definição.

### Organizer Detail View
- [x] 10. No widget do organizer, quero poder filtrar por TUDO (tasks, habits, goals, trackers) e ver tudo junto ou separado.

### Navegação e UX
- [x] 11. O nome da página atual deve aparecer no centro da barra superior (App Bar).
- [x] 12. Botão de voltar deve sempre voltar para a página anterior, não para o pai (corrigir go_router se necessário).
- [x] 13. quero poder colocar atalhos na barra de navegação pra qualquer página - criar form, uma nota específica, um filtro de área específico, uma tarefa ou goal específica, etc. qualquer coisa

---
- [x] adicione um botao de backlog no form de criar tarefas, e no planning (no topo, ao lado dos outros dois icones ao lado do titulo da pagina) esse backlog vai ser todas as tarefas que nao tem data. clicar no botao de backlog ao criar tarefa deixa criar a tarefa sem data, e clicar no botao de backlog no planning vai abrir a lista de tarefas que nao tem data (que é na verdade um filtro). ao clicar na tarefa, da pra editar e colocar uma data
- [x] backsplash inicial com o icone do app, colocar o fundo cinza bem escuro 
> **Nota**: Este arquivo é atualizado conforme o progresso das tarefas seguindo o `AGENTS.md`.