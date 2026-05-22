# Citrine — Roadmap de Testes

> Ordem de implementação e validação. Cada fase pressupõe a anterior funcionando.
> Marque os itens conforme for concluindo.

---

## Como usar este roadmap

- Teste sempre **no dispositivo físico** (não simulador) — notificações, widgets e share sheet se comportam diferente em emuladores.
- O critério mínimo de "passou" para qualquer feature de vault é: criar um objeto, fechar e reabrir o app, e o objeto estar lá com todos os campos corretos no arquivo `.md`. Se o frontmatter estiver certo, quase tudo no app funciona automaticamente por conta do `allObjectsProvider`.
- Corrija os bugs base antes de qualquer feature nova — eles afetam a confiabilidade de tudo que vem depois.

---

## Fase 0 — Correções base (itens 1–8)

> **Dica geral:** resolva tudo nesta fase antes de avançar. Bugs de renderização, duplicatas e crashes afetam a confiança nos testes das fases seguintes.

### Rich text no journal

- [ ] Journal entry na timeline renderiza rich text corretamente
  - Criar uma entry com negrito, itálico, uma imagem e uma lista. A timeline deve renderizar via `RichTextWidget`, não o JSON raw (`[{"insert":"..."}]`).
- [ ] Negrito, itálico, listas e mídia aparecem com a formatação correta
  - Verificar cada tipo de bloco que o editor suporta.

### Notificações

> **Dica:** teste notificações obrigatoriamente no dispositivo físico. Emuladores não reproduzem alarmes com fidelidade e o canal de push pode não estar registrado.

- [ ] Notificação pop-up dispara no horário certo e fecha corretamente
  - Verificar dismiss manual e tap para abrir o objeto vinculado.
- [ ] Notificação alarme toca áudio e vibra
  - Testar com app em background e com tela bloqueada.
- [ ] Push notification entrega e redireciona para a tela correta
  - Confirmar canal separado; verificar que o payload abre a tela certa.

### Tasks

- [ ] Tasks sem duplicatas na lista
  - Criar 1 task, fechar e reabrir o app; deve aparecer só uma vez.
- [ ] Tap numa task mostra subtasks corretamente
  - Task com 3+ subtasks: todas devem aparecer no detail view.

### Hábitos

- [ ] Tela de Hábitos carrega sem erro de tipo
  - Corrigir `type Map<dynamic,dynamic> is not a subtype of List<dynamic>`; navegar até a aba Hábitos e verificar a listagem completa.

### Subtask sessions

- [ ] Subtask sessions (grupos colapsáveis) funcionam
  - Criar sessão com nome, adicionar subtasks, colapsar e expandir. Testar drag de subtask entre sessões.

### Home e widgets

- [ ] Todos os widgets da dashboard têm versão equivalente na tela inicial
  - Comparar side-by-side os blocos da Dashboard com o que aparece na home.
- [ ] Quick add de entry funciona via FAB/atalho
  - Acionar atalho, preencher só o título, confirmar que a entry é salva no vault.
- [ ] Quick add de task funciona
  - Mesmo fluxo; confirmar que aparece na lista de tasks.
- [ ] Quick add de habit funciona
  - Confirmar que hábito aparece na tela de Hábitos após criação via atalho.

### Widgets de lock screen

> **Dica:** instalar e testar no dispositivo físico. O gatilho de botões físicos (home/volume) é restrito pelo Android OS para apps de terceiros; a Notificação Persistente é a rota mais confiável.

- [ ] Widget de keyguard (lock screen) aparece corretamente
  - Instalar widget na tela de bloqueio; verificar botões de captura rápida.
- [ ] Notificação persistente de captura rápida está ativa
  - Deve aparecer na bandeja de notificações; tap abre o quick add.

---

## Fase V2.1 — Day Themes & Time Blocks

> **Depende de:** Fase 0 concluída + V1 Planner e Scheduler estáveis.
>
> **Dica:** teste a detecção de tema com pelo menos dois temas diferentes configurados para dias da semana distintos. O caso mais fácil de errar é o fallback quando nenhum tema cobre o dia atual.

- [ ] CRUD de Time Blocks em Settings funciona
  - Criar, editar, reordenar via drag e deletar um bloco. Confirmar arquivo salvo em `time_blocks/SLUG.md` com frontmatter correto.
- [ ] Time Block picker aparece nos formulários de session e habit
  - Abrir cada form; chips de blocos disponíveis devem listar os blocos criados.
- [ ] CRUD de Day Themes em Settings funciona
  - Criar tema com nome, cor, dias da semana e blocos associados. Confirmar `day_themes/SLUG.md`.
- [ ] Header do Planner mostra o tema do dia automaticamente
  - Configurar tema "Workday" para Mon–Fri; abrir Planner numa segunda; nome do tema deve aparecer no header.
- [ ] Day view em blocos colapsáveis funciona
  - Sessions e hábitos agrupados por bloco. Colapsar e expandir cada card. Bloco "All day" deve estar sempre no topo.
- [ ] Criar session diretamente dentro de um bloco
  - Tap no `+` de um bloco; form deve abrir com `time_block` pré-preenchido.
- [ ] Scheduler `daysOfTheme` dispara corretamente
  - Configurar regra "todo Workday"; verificar que itens aparecem apenas em dias com esse tema.
- [ ] Scheduler `daysWithBlock` dispara corretamente
  - Regra vinculada a bloco específico; verificar nos dias que têm aquele bloco e confirmar ausência nos outros.
- [ ] Daily note salva frontmatter `day_theme`
  - Abrir daily note de um dia com tema detectado; confirmar campo `day_theme: slug` no frontmatter.

---

## Fase V2.2 — Combined Analysis multi-fonte

> **Depende de:** V1 Trackers com charts funcionando + V1 Journal com mood.
>
> **Dica:** use dados reais de pelo menos 7 dias antes de testar os charts. Com poucos pontos, erros de agregação passam despercebidos.

- [ ] Criar análise com múltiplos data sources
  - Adicionar um source do tipo `tracker_field` + um `habit` + um `journal_mood`. Salvar e confirmar `analyses/SLUG.md`.
- [ ] Calendário mensal multi-dot renderiza corretamente
  - Cada day cell mostra dots coloridos por source. Tap num dia abre bottom sheet com os valores de cada source.
- [ ] Line chart multi-série exibe com cor e legenda
  - Cada source como linha com sua cor. Tap num item da legenda deve ocultar/exibir a série.
- [ ] Scatter plot correlaciona dois sources
  - Selecionar source A (eixo X) e source B (eixo Y); pontos devem aparecer na data correta.
- [ ] Date range picker filtra todos os charts
  - Selecionar "Last 30 days" e depois um range customizado; dados devem mudar em todos os gráficos.
- [ ] Mood como data source lê valores numéricos corretamente
  - Adicionar source `journal_mood`; confirmar que `MoodDefinition.numeric_value` é usado, não o texto.
- [ ] Exportar para Obsidian Charts gera bloco correto
  - Colar o bloco copiado num note do Obsidian e verificar que o chart renderiza com o plugin Charts.

---

## Fase V2.3 — Google Calendar

> **Depende de:** V1 OAuth (Drive) configurado + V1 Planner estável.
>
> **Dica:** o `google_calendar_service.dart` já tem os métodos implementados — o ponto crítico é o OAuth. Teste conectar, desconectar e reconectar antes de avançar para a exibição de eventos. Se o token expirar durante os testes, o fluxo de refresh precisa funcionar silenciosamente.

- [ ] Fluxo OAuth completo em Settings → Google Calendar
  - Conectar conta Google, verificar email exibido, desconectar e reconectar sem reiniciar o app.
- [ ] Eventos do GCal aparecem no Planner Day View
  - Evento agendado para hoje deve aparecer como `GoogleCalendarEventCard` com a cor do calendário de origem.
- [ ] Bottom sheet de evento mostra todos os detalhes
  - Tap num evento GCal; título, horário, descrição, local e link "Abrir no GCal" devem aparecer.
- [ ] Exportar session para GCal funciona
  - Acionar "Exportar para Google Calendar" no menu `⋯` da session; confirmar evento criado na conta Google.
- [ ] Editar session atualiza o evento no GCal
  - Mudar horário de uma session já exportada; app deve perguntar "Atualizar no GCal?"; confirmar e verificar na conta.
- [ ] Deletar session remove evento do GCal
  - Deletar session com `exportedCalendarId`; confirmar que o evento some do Google Calendar.
- [ ] Ícone 📅 aparece no card de sessions exportadas
  - Card da session no Planner deve mostrar o ícone quando `exportedCalendarId != null`.

---

## Fase Social — S1 & S2: Modelo e captura

> **Depende de:** V1 vault estável + `obsidian_service.dart` funcionando.
>
> **Dica:** teste o oEmbed obrigatoriamente no dispositivo físico com rede real antes de avançar para S3. As políticas de CORS e redirect do TikTok/Instagram se comportam diferente em emuladores. Se o fetch falhar na rede do emulador mas funcionar no dispositivo, o problema é de ambiente, não de código.

- [ ] Pasta `social/` criada no vault após primeiro sync
  - Confirmar existência da pasta no vault Obsidian.
- [ ] `SocialPost` salvo corretamente como `social/SLUG.md`
  - Criar post via form; abrir o vault e verificar frontmatter completo: `url`, `platform`, `media_type`, `author_handle`, `thumbnail`, `watched`, `created_at`.
- [ ] `socialPostsProvider` carrega posts existentes ao reiniciar
  - Reiniciar o app com posts já no vault; verificar que aparecem na Social Screen.
- [ ] Nav item Social aparece e navega para `/social`
  - Ícone `play_circle` na nav; tap navega para a tela correta.
- [ ] oEmbed busca metadados de TikTok corretamente
  - Colar URL de TikTok; thumbnail, handle e caption devem preencher automaticamente.
- [ ] oEmbed busca metadados de YouTube corretamente
  - Colar URL de YouTube; título e thumbnail devem aparecer.
- [ ] Fallback OpenGraph funciona para Instagram e Substack
  - Colar URLs dessas plataformas; título e imagem via tags `og:` devem aparecer.
- [ ] URL curta do TikTok (`vm.tiktok.com`) é resolvida antes do fetch
  - Colar uma URL curta; deve redirecionar, resolver o video ID e buscar os metadados corretamente.
- [ ] Formulário em branco permite preenchimento manual quando fetch falha
  - Forçar falha (modo avião ou URL inválida); campos devem ficar editáveis; salvar deve funcionar.
- [ ] Opção "Post social" aparece no create menu e abre o form
  - Abrir menu de criação global; item deve estar visível.

---

## Fase Social — S3 & S4: Feed e Detail View

> **Depende de:** Social S1 e S2 completos.
>
> **Dica:** o conflito de long press (multi-select vs `ObjectActionWrapper`) é o caso mais fácil de quebrar silenciosamente. Teste long press em grid e lista separadamente, e confirme que o action sheet do post só é acessível via botão `⋯` no detail view.

- [ ] Grid de posts renderiza thumbnails e fallbacks
  - Posts com thumbnail exibem imagem. Posts sem thumbnail mostram ícone da plataforma com cor de fundo.
- [ ] Chips de plataforma filtram o feed corretamente
  - Tap em "TikTok" mostra só posts dessa plataforma. Tap em "Todos" reseta o filtro.
- [ ] Chip "Não visto" filtra posts corretamente
  - Marcar alguns posts como vistos; chip deve mostrar apenas os não vistos.
- [ ] Alternar modo grid ↔ lista funciona sem perder o filtro ativo
  - Aplicar filtro de plataforma, alternar layout; filtro deve persistir.
- [ ] Bottom sheet de filtros ordena o feed
  - Ordenar por "Postado mais recente"; confirmar a ordem dos cards pelo campo `posted_at`.
- [ ] Long press ativa modo multi-select (sem abrir action sheet)
  - Long press num card deve entrar em multi-select. Confirmar que o `ObjectActionWrapper` não está interceptando o gesto.
- [ ] Ação "Marcar como vistos" no multi-select funciona
  - Selecionar 3 posts e marcar; dot azul deve sumir e opacidade deve mudar nos cards.
- [ ] Estado vazio exibe `EmptyState` com CTA
  - Sem posts e sem filtro ativo: mostrar EmptyState com botão "Salvar primeiro post".
- [ ] Post Detail View abre com todos os dados corretos
  - Tap num card; caption, handle, badge de plataforma e metadata devem estar corretos.
- [ ] Nota pessoal salva com auto-save após debounce de 800ms
  - Digitar nota, aguardar sem tocar em nada, fechar e reabrir o detail; nota deve persistir.
- [ ] Seção "Citado em" aparece com backlinks corretos
  - Criar um Goal com esse post em `socialRefs`; seção deve aparecer no detail do post com o goal listado.
- [ ] Botão ↗ abre URL original no browser externo
  - Tap no ícone; URL deve abrir no browser nativo do sistema.
- [ ] Action sheet: "Abrir no Obsidian" funciona
  - Tap na opção; deep link `obsidian://` deve abrir o arquivo `social/SLUG.md` no Obsidian.
- [ ] Deletar post remove o arquivo do vault
  - Confirmar delete; arquivo `social/SLUG.md` deve desaparecer do vault após a operação.

---

## Fase Social — S5, S6, S7, S9: Embed, Coleções, Refs, Share

> **Depende de:** Social S3 e S4 completos. S5 é a única fase com nova dependência (`webview_flutter`).
>
> **Dica:** TikTok e Instagram mudam suas políticas de embed com frequência. Se o WebView ficar em branco após 10s, o `onPageFinished` deve detectar e acionar o fallback — confirme que o timer está funcionando. Para o share intent, teste cold start (app fechado) e warm share (app aberto) separadamente.

- [ ] WebView do TikTok renderiza o vídeo
  - Post com `embedUrl` válida; iframe deve aparecer e permitir tocar o vídeo.
- [ ] WebView do YouTube renderiza o player
  - Post de YouTube; player embutido deve funcionar normalmente.
- [ ] Substack injeta CSS e remove header/footer da página
  - Post de Substack; artigo deve aparecer limpo, sem navbar ou rodapé da plataforma.
- [ ] Fallback aparece quando embed falha ou `embedUrl` é nulo
  - Post sem `embedUrl` ou com iframe que não carrega; fallback com botão "Abrir no [plataforma]" deve aparecer.
- [ ] Drawer de coleções lista apenas organizers com posts
  - Abrir drawer na Social Screen; organizers sem nenhum post não devem aparecer.
- [ ] Filtro por coleção funciona e exibe chip ativo com `×`
  - Tap num organizer no drawer; feed filtra e chip de filtro ativo aparece no topo da lista.
- [ ] `OrganizerDetailScreen` exibe mini-cards de posts sociais
  - Abrir organizer que tem posts associados; seção "Posts sociais" deve aparecer com scroll horizontal.
- [ ] Goal salva `socialRefs` no frontmatter
  - Criar goal com post de referência; confirmar `social_refs: ["[[social/slug]]"]` no arquivo `.md` do goal.
- [ ] Seção "Inspirado por" no form de Goal funciona
  - Adicionar post de referência via picker; post aparece na lista com thumbnail, handle e plataforma.
- [ ] `UniversalDetailView` de Goal exibe posts de referência
  - Abrir goal com `socialRefs` preenchido; mini-cards dos posts devem aparecer na seção correta.
- [ ] Share sheet (iOS/Android) abre o `CreateSocialPostForm`
  - Compartilhar URL do TikTok direto do app nativo; form deve abrir com URL pré-preenchida e fetch disparando automaticamente. Testar com app fechado (cold start) e com app aberto (warm share).
- [ ] Banner de clipboard aparece na Social Screen
  - Copiar URL do Instagram; abrir Social Screen; banner de sugestão deve aparecer no topo com botões "Ignorar" e "Salvar".
- [ ] Import em lote processa múltiplas URLs
  - Em Settings → Importar: colar 3 URLs válidas (uma por linha) + 1 URL inválida; os 3 posts devem ser salvos e o erro da URL inválida informado ao final.

---

## Fase V2.6 — Command Center & Inbox

> **Depende de:** V1 estável.
>
> **Dica:** o trigger de scroll-beyond-top é frágil em `CustomScrollView` com múltiplos slivers. Teste em cada tab principal, não só na home. O Inbox é independente — pode ser testado antes do Command Center se a implementação for separada.

- [ ] Command Center abre ao scroll além do topo
  - Scroll além do topo na main UI; overlay deve descer com campo de busca auto-focado e teclado aberto.
- [ ] Seções "Recentes", "Notas" e "Próximas sessões" populadas com dados reais
  - Verificar que cada seção exibe objetos reais do vault, não placeholders.
- [ ] Busca inline filtra resultados em tempo real
  - Digitar 3 letras; resultados devem filtrar por título sem delay perceptível.
- [ ] Ações rápidas do Command Center funcionam
  - Tap em "Nova entrada" → form de entry. "Nova task" → form de task.
- [ ] Fechar Command Center via swipe up e tap fora
  - Cada gesto deve fechar o overlay com animação suave.
- [ ] Quick capture (Inbox) salva item com só o título
  - Acionar via FAB secundário; preencher só o título; confirmar `inbox/YYYY-MM-DD-HH-MM.md` no vault.
- [ ] Inbox Screen lista itens do mais antigo para o mais novo
  - Criar 3 itens em sequência; verificar a ordem na tela.
- [ ] Triagem "Virou uma task" abre form pré-preenchido
  - Tap num item do Inbox → "Virou uma task"; form de task deve abrir com o título já preenchido.
- [ ] Badge no tab exibe contagem de itens não triados
  - Adicionar 2 itens ao Inbox sem triagem; badge deve mostrar "2".

---

## Fase V2.7 — Templates

> **Depende de:** V1 rich text funcional.
>
> **Dica:** as variáveis `{{date}}` e `{{title}}` são o ponto mais propenso a falha — verifique que são substituídas ao aplicar, não ao criar o template. Teste criar um template a partir de um item existente com conteúdo rico (não só texto plano).

- [ ] Criar template de Entry com variáveis `{{date}}` e `{{title}}`
  - Após aplicar o template numa entry, verificar que as variáveis foram substituídas pelos valores reais.
- [ ] Template editor salva corretamente em `templates/SLUG.md`
  - Confirmar arquivo no vault com `type`, `body` e `frontmatter_defaults` no frontmatter.
- [ ] "Usar template" no form de Entry funciona
  - Selecionar template; body é preenchido e frontmatter defaults aplicados aos campos do form.
- [ ] "Salvar como template" no menu `⋯` de item existente
  - Acionar em uma entry com rich text; template criado deve conter o body atual.
- [ ] Templates pré-definidos instalados na primeira abertura
  - Resetar app ou usar novo vault; confirmar existência de "Reunião 1:1", "Weekly Review", "Leitura", "Sprint Planning" e "Projeto novo" em `templates/`.

---

## Fase V2.10 — Widgets nativos

> **Depende de:** V1 estável com `home_widget` configurado.
>
> **Dica:** teste widgets obrigatoriamente no dispositivo físico. Confirme que o `CitrineWidgetReceiver` está declarado no `AndroidManifest.xml` antes de qualquer teste de widget. Para o widget de Hábitos, o tap no checkbox precisa funcionar com o app em background — esse é o caso mais crítico e o mais fácil de falhar silenciosamente.

- [ ] Widget Quick-add aparece na tela inicial Android (2×1)
  - Adicionar widget; botões 📝 e ✅ devem estar visíveis e com labels corretos.
- [ ] Deep links dos botões do widget abrem os forms corretos
  - Tap no botão de entry: `citrine://create/entry` deve abrir o form. Mesmo para task.
- [ ] Widget Calendar semana (4×2) exibe dots nos dias corretos
  - Criar eventos no Planner; widget deve mostrar dots coloridos nos dias correspondentes.
- [ ] Tap num dia do widget Calendar navega para o Planner
  - Tap num dia: app abre em `citrine://planner/day/YYYY-MM-DD` do dia correto.
- [ ] Widget Habits exibe checkboxes com estado atual
  - Widget 4×2 com hábitos do dia; checkboxes devem refletir o estado real (marcado/não marcado).
- [ ] Tap no checkbox do Widget Habits marca o hábito com app em background
  - Tap → hábito marcado; abrir o app e verificar que a mudança está refletida na tela de Hábitos.
- [ ] `WidgetSyncProvider` atualiza widgets automaticamente ao salvar dados
  - Criar nova task; widget Calendar deve atualizar sem reiniciar o app ou o widget.

---

## Fase V2.4 — Scheduler: regras avançadas

> **Depende de:** V1 Scheduler funcional + V2.1 Day Themes concluído.
>
> **Dica:** os tipos `linkedItemAppears` e `nDaysAfterLinkedItem` já existem no enum `RepeatType` — o risco está na lógica do `scheduler_service.dart`, não no modelo. Teste com itens que têm e não têm sessões agendadas na data-alvo para confirmar que o `shouldFire` está consultando o vault corretamente, e não apenas checando o modelo em memória.

- [ ] `linkedItemAppears` dispara apenas nos dias em que o item vinculado tem session ou task agendada
  - Criar regra vinculada a um objeto; agendar uma session desse objeto para amanhã; confirmar que a regra dispara só nesse dia.
- [ ] `linkedItemAppears` não dispara em dias sem o item vinculado
  - Verificar que nenhum item gerado aparece em dias onde o linked item não está no calendário.
- [ ] Sub-form do picker para `linkedItemAppears` funciona
  - Selecionar tipo "Toda vez que"; WikiLink picker abre; preview "Repetir nos dias em que [[item]] estiver no calendário" aparece corretamente.
- [ ] YAML salvo corretamente: `type: linked_item_appears` + `linked_item: "[[slug]]"`
  - Confirmar frontmatter do scheduler no vault.
- [ ] `nDaysAfterLinkedItem` calcula a data corretamente
  - Configurar "3 dias depois de [[meta-x]]"; a próxima instância deve ser calculada como `data do linked item + 3 dias`.
- [ ] Sub-form do picker para `nDaysAfterLinkedItem` funciona
  - Campos "N", unidade (Days/Hours) e WikiLink picker devem funcionar; preview deve exibir a lógica em linguagem natural.
- [ ] Ao completar instância de `nDaysAfterLinkedItem`, próxima data é recalculada
  - Completar a instância; próxima data deve se basear na próxima ocorrência do linked item, não na data atual.
- [ ] Filtro "Vinculados" na Scheduler Page mostra apenas regras avançadas
  - Aplicar filtro; somente objetos com `linkedItemAppears` ou `nDaysAfterLinkedItem` devem aparecer.
- [ ] Preview "Próximos 7 dias" na Scheduler Page calcula datas em tempo real
  - Verificar que as datas exibidas correspondem ao resultado esperado de `shouldFire` para cada um dos 7 dias.

---

## Fase V2.5 — MOC: Map of Content

> **Depende de:** V1 Universal Links + Backlinks funcionando.
>
> **Dica:** o `moc_service.dart` atual gera index automático por pasta — V2.5 substitui isso por MOC definido pelo usuário. Antes de implementar, confirme que o `backlinksProvider` existente já detecta referências `[[mocos/slug]]` corretamente; se sim, a maior parte da conectividade já funciona sem código extra.

- [ ] Criar MOC salva `mocos/SLUG.md` com frontmatter correto
  - Criar MOC com título, descrição e lista de WikiLinks. Confirmar `type: moc`, `title` e `children` no arquivo.
- [ ] `mocsProvider` carrega todos os MOCs do vault
  - Reiniciar o app com 2 MOCs no vault; ambos devem aparecer nos pickers.
- [ ] Adicionar objeto a um MOC atualiza o frontmatter do objeto e o `children` do MOC
  - Adicionar uma task ao MOC via chip; confirmar `moc: ["[[mocos/slug]]"]` na task E o slug da task em `children` do MOC.
- [ ] MOC picker lista todos os MOCs e tem opção "Criar novo MOC"
  - Abrir picker; listar MOCs existentes; opção de criação ao final da lista.
- [ ] MOC detail view exibe lista de children como cards tappáveis
  - Cada child mostra ícone do tipo + título + preview de 1 linha. Tap navega para o detail do objeto.
- [ ] MOC aninhado: child que é outro MOC mostra hierarquia com indent
  - Criar MOC A com MOC B como child; B deve aparecer com indent na detail view de A.
- [ ] Filtro por MOC no Journal funciona
  - Aplicar filtro de MOC; somente entries cujo `moc` contém o slug selecionado devem aparecer.
- [ ] Filtro por MOC no Planner colore items pelo MOC
  - Configurar cor no MOC; items do dia vinculados a esse MOC devem ter a cor aplicada.
- [ ] Botão "Ver Dataview" gera e copia query correta para o clipboard
  - Colar no Obsidian; query deve listar os objetos do MOC ordenados por `file.mtime DESC`.

---

## Fase V2.8 — Subtask sessions e gestão avançada de tasks

> **Depende de:** V1 Tasks com subtasks funcionando (Fase 0 item subtask sessions).
>
> **Dica:** subtask sessions usam drag-and-drop entre grupos — teste com 3+ sessões e subtasks em cada uma para garantir que o `ReorderableListView` não está trocando items entre grupos incorretamente. Task dependencies e time estimates podem ser implementados e testados de forma independente entre si.

### Subtask sessions (grupos temáticos)

- [ ] Criar sessão de subtasks com nome funciona
  - No painel de subtasks: tap em "Criar sessão" → digitar nome → subtasks selecionadas agrupadas sob o header.
- [ ] Header de sessão colapsável funciona
  - Tap no header `[+] Sessão: "Pesquisa"` colapsa e expande as subtasks do grupo.
- [ ] Drag de subtask entre sessões funciona
  - Arrastar subtask de uma sessão para outra; posição deve ser salva no frontmatter.
- [ ] `sessions` array salvo corretamente no frontmatter da task
  - Confirmar estrutura `sessions: [{id: "s1", name: "...", subtasks: ["st1", "st2"]}]` no arquivo `.md`.

### Task dependencies

- [ ] Campo `dependsOn` aceita WikiLinks de outras tasks
  - Adicionar task bloqueante via picker; confirmar `depends_on: ["[[tasks/slug]]"]` no frontmatter.
- [ ] Badge "Bloqueada" aparece no detail quando task bloqueante não está finalizada
  - Task A depende de task B (não finalizada); detail de A deve mostrar badge "Bloqueada".
- [ ] Ícone de cadeado 🔒 aparece no Planner para tasks bloqueadas
  - Task com dependency não concluída agendada no Planner; ícone deve aparecer no card.
- [ ] Badge some quando todas as tasks bloqueantes são finalizadas
  - Finalizar a task bloqueante; badge e cadeado devem desaparecer automaticamente.

### Time estimates vs actuals

- [ ] Campo `estimated_minutes` salvo no frontmatter
  - Preencher estimativa no form; confirmar campo no arquivo `.md`.
- [ ] `actual_minutes` calculado corretamente a partir de sessões Pomodoro
  - Executar Pomodoros vinculados à task; tempo real deve ser acumulado e exibido.
- [ ] Barra de progresso de tempo exibida no detail da task
  - "Estimado: 45min | Real: 1h 12min" deve aparecer com barra de progresso.
- [ ] Planner sugere slot de duração baseado em `estimated_minutes` ao agendar
  - Arrastar task para o Planner; duração do bloco deve ser pré-sugerida com base na estimativa.

---

## Fase V2.9 — Natural Language Input

> **Depende de:** V1 rich text e forms de criação estáveis. (Voice recording e speech-to-text foram removidos do escopo.)
>
> **Dica:** o parse local usa `intl` para datas e regex para padrões — teste com datas relativas em português ("amanhã", "próxima segunda") e absolutas ("dia 30"). Confirme que o preview dos campos detectados aparece **antes** de confirmar, para que o usuário possa corrigir antes de salvar.

- [ ] "Comprar leite amanhã às 10h" detecta título, deadline e horário
  - Resultado esperado: `title: "Comprar leite"`, `deadline: amanhã`, `exact_time: 10:00`.
- [ ] "Ligar pro João todo domingo" detecta título e cria scheduler `daysOfWeek: [sunday]`
  - Verificar que o scheduler é criado junto com a task.
- [ ] "Projeto X até dia 30 alta prioridade" detecta deadline e prioridade
  - `deadline: 30 do mês corrente`, `priority: high`.
- [ ] Preview dos campos detectados aparece abaixo do input antes de confirmar
  - Campos identificados (deadline, horário, prioridade) devem ser exibidos para revisão.
- [ ] NLP pode ser desligado em Settings
  - Desativar; criar task com texto "amanhã às 10h"; campos não devem ser auto-preenchidos.
- [ ] Texto sem padrões reconhecíveis não altera campos
  - Digitar "Fazer algo"; nenhum campo extra deve ser pré-preenchido.

---

## Fase V2.11 — Dataview e Obsidian plugin output

> **Depende de:** V1 vault escrevendo no formato correto + dados suficientes para as queries fazerem sentido.
>
> **Dica:** as queries geradas precisam ser testadas **dentro do Obsidian** com o plugin Dataview instalado, não só verificando o texto gerado. Uma query com frontmatter errado (campo com tipo diferente do esperado) vai silenciosamente não retornar resultados. Use o Obsidian como ambiente de validação final desta fase.

- [ ] `dataview_generator.dart` gera query de streak de hábitos corretamente
  - Abrir `habits/index.md` no Obsidian; query deve calcular streak atual com base nas daily notes.
- [ ] Query de tasks por stage aparece no `index.md` de tasks
  - Confirmar que a query `TABLE stage, priority` é gerada e retorna resultados reais no Obsidian.
- [ ] Query de mood trend aparece no `index.md` de daily notes
  - Confirmar query `TABLE mood_overall` com `LIMIT 30` no Obsidian.
- [ ] Botão "Regenerar queries Dataview" em Settings reescreve os index files
  - Tap no botão; confirmar que os arquivos `index.md` de cada pasta são atualizados no vault.
- [ ] Bloco `chart` gerado no arquivo de tracker é válido para o plugin Obsidian Charts
  - Abrir arquivo de tracker no Obsidian com o plugin Charts instalado; bloco deve renderizar o gráfico.
- [ ] Bloco do Obsidian Tracker plugin gerado em arquivos de análise
  - Confirmar que as variáveis `{{today}}` e `{{lastMonth}}` foram substituídas pela data real.
- [ ] `social/index.md` gerado com queries Dataview por plataforma e por `watched`
  - Confirmar existência do arquivo após sync; queries devem retornar posts reais no Obsidian.

---

## Fase V2.12 — Import de outros apps

> **Depende de:** V1 vault estável com formato de frontmatter definido.
>
> **Dica:** o caso mais importante é preservar o conteúdo original de arquivos sem frontmatter estruturado. Teste com um vault Obsidian real que tenha uma mistura de arquivos com e sem frontmatter — o import não deve modificar arquivos que já estão no formato correto, apenas indexar.

- [ ] Import de vault Obsidian existente detecta arquivos com frontmatter compatível
  - Apontar para uma pasta de vault; arquivos com `type`, `categories`, etc. devem aparecer no app após indexação.
- [ ] Arquivos sem frontmatter estruturado são importados como Text Notes
  - Conteúdo original deve ser preservado integralmente; nenhum dado deve ser perdido ou truncado.
- [ ] Arquivos já no formato Citrine não são duplicados no import
  - Rodar o import duas vezes; objetos não devem aparecer em duplicata no app.
- [ ] Progresso do import é exibido durante o processamento
  - Para vaults grandes (100+ arquivos), uma barra de progresso ou contador deve ser visível.

---

## Fase V2.13 — iPad e telas grandes

> **Depende de:** V1 estável em iPhone.
>
> **Dica:** teste em iPad físico ou simulador com resolução real. O caso mais fácil de quebrar é o master-detail no Planner — confirme que tap numa task na coluna esquerda abre o detail na coluna direita sem fazer push na lista (sem substituir a lista pela detail view). `LayoutBuilder` com breakpoint em 600dp é o critério de corte.

- [ ] Em telas > 600dp, bottom nav é transformada em side rail
  - Abrir no iPad; navegação deve aparecer como coluna lateral, não como barra inferior.
- [ ] Master-detail no Planner: tap numa task abre detail na coluna direita
  - Tap num item da lista esquerda; detail view abre na coluna direita sem substituir a lista.
- [ ] Dashboard iPad exibe grid de 3 colunas para os blocos
  - Blocos da Dashboard devem ocupar 3 colunas em vez de 1.
- [ ] Trackers iPad: tabela de records à esquerda, charts à direita
  - Layout de duas colunas para a tela de trackers.
- [ ] Atalho `⌘N` abre nova entrada/task conforme a tab ativa
  - Com iPad + teclado: pressionar `⌘N` na tab de Journal deve abrir form de entry; na tab de Tasks deve abrir form de task.
- [ ] Atalho `⌘F` abre a search screen
  - Pressionar `⌘F` em qualquer tela; search deve abrir imediatamente.
- [ ] Atalho `⌘K` abre o Command Center
  - Pressionar `⌘K`; Command Center deve aparecer com foco no campo de busca.
- [ ] Atalhos `⌘1` a `⌘5` navegam entre as tabs
  - Cada combinação deve mudar a tab ativa corretamente.

---

## Fase V2.14 — Weekly Review e estatísticas avançadas

> **Depende de:** dados suficientes no vault (pelo menos 2–3 semanas de uso real ou dados de teste).
>
> **Dica:** o template de Weekly Review pré-preenchido é o ponto mais propenso a erro — cada seção (hábitos, tasks, Pomodoro, goals, mood) puxa dados de providers diferentes. Teste com um vault que tenha dados reais em todas as categorias para garantir que nenhuma seção aparece em branco por erro de query, e não por falta de dados.

### Weekly Review automático

- [ ] Template de Weekly Review é gerado no dia configurado (sexta ou domingo)
  - Configurar para sexta; avançar a data de teste para uma sexta; confirmar geração do template em `daily/`.
- [ ] Taxa de sucesso de hábitos da semana está correta no template
  - Comparar "X/7 dias" gerado com os registros reais das daily notes da semana.
- [ ] Contagem de tasks (concluídas vs criadas vs abertas) está correta
  - Verificar os números contra a lista de tasks filtrada pelo período.
- [ ] Total de horas Pomodoro da semana e top 3 projetos estão corretos
  - Comparar com os registros de sessões Pomodoro do período.
- [ ] Delta de KPIs de goals aparece corretamente (semana atual vs anterior)
  - Goal com KPI numérico; delta deve refletir a diferença real entre os períodos.
- [ ] Notificação semanal "Sua review está pronta" é entregue e abre o review
  - Confirmar entrega no horário configurado; tap deve abrir o daily note de revisão.

### Statistics screen

- [ ] Statistics screen acessível e carrega sem erro
  - Navegar até a tela; nenhum crash ou tela em branco.
- [ ] Streak atual e recorde por hábito exibidos corretamente
  - Comparar com contagem manual a partir das daily notes.
- [ ] Task completion rate (rolling 30 dias) calculado corretamente
  - Verificar a porcentagem contra tasks finalizadas vs criadas no período.
- [ ] Heatmap calendar do ano exibe dias de atividade
  - Dias com tasks, entries ou hábitos devem ter intensidade de cor maior.
- [ ] KPI histórico de goal como line chart funciona
  - Selecionar goal com KPI; gráfico deve exibir os valores semana a semana.
- [ ] Palavras escritas no journal exibidas (total + por semana)
  - Confirmar contagem contra o conteúdo real das entries.

---

## Resumo de dependências entre fases

```
Fase 0 (bugs base)
  ├── V2.1 (Day Themes)
  │     ├── V2.3 (Google Calendar)
  │     └── V2.4 (Scheduler avançado)
  ├── V2.2 (Analysis) — depende também de dados no vault
  ├── Social S1+S2
  │     └── Social S3+S4
  │           └── Social S5+S6+S7+S9
  ├── V2.5 (MOC) — depende de V1 Backlinks
  ├── V2.6 (Command Center & Inbox)
  ├── V2.7 (Templates)
  ├── V2.8 (Subtask sessions + dependencies)
  ├── V2.9 (NLP input)
  ├── V2.10 (Widgets nativos) — pode rodar em paralelo
  ├── V2.11 (Dataview output) — depende do vault no formato correto
  ├── V2.12 (Import) — depende do vault estável
  ├── V2.13 (iPad) — pode rodar em paralelo após V1 estável
  └── V2.14 (Weekly Review + Statistics) — depende de dados suficientes
```