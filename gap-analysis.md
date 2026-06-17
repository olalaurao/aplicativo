=============================================================
  CITRINE — GUIA DE OTIMIZAÇÃO DE PERFORMANCE
  Foco: lentidão no startup e navegação geral
  Baseado em auditoria do código atual (junho 2026)
=============================================================

Este documento está organizado por impacto estimado (maior → menor).
Cada item explica O QUÊ mudar, POR QUÊ é lento, e COMO resolver.


══════════════════════════════════════════════════════════════
  BLOCO 1 — STARTUP (o app tarda pra abrir)
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
1.1  allObjectsProvider lê TODO o vault de uma vez no startup
     (arquivo: lib/providers/vault_provider.dart, classe AllObjectsNotifier.build())
──────────────────────────────────────────────

PROBLEMA:
  O método build() do AllObjectsNotifier faz o seguinte:
    1. Lista TODOS os arquivos .md do vault com getFilesInFolder('', recursive: true)
    2. Lê o conteúdo de CADA arquivo com readAsString()
    3. Faz parse de YAML frontmatter de cada um
    4. Instancia objetos Dart para cada um
    5. Deduplica, ordena, e monta o estado final

  Isso é executado de forma BLOQUEANTE (do ponto de vista da tela de splash)
  via Future.wait() no _initApp() em main.dart antes de qualquer UI aparecer.
  Se o vault tiver 500+ arquivos (tarefas, diários, hábitos, sociais, notas),
  isso pode levar vários segundos.

  Além disso, toda vez que qualquer objeto é salvo (addTask, toggleHabit etc.),
  o código chama ref.invalidate(allObjectsProvider) — ou seja, relê o vault
  INTEIRO de novo do disco. Há pelo menos 10 lugares no código que fazem isso.

POR QUÊ É LENTO:
  - I/O de disco é a operação mais lenta disponível (muito pior que RAM).
  - Mesmo com batches de 50 arquivos em paralelo, se você tem 300+ arquivos
    a leitura sequencial de batches demora (3x+ segundos em dispositivos médios).
  - A invalidação total a cada write força uma releitura completa mesmo quando
    só 1 arquivo mudou.

COMO RESOLVER:
  Etapa A — Não bloquear a splash screen esperando o vault completo:
    Em main.dart, no _initApp(), o Future.wait() espera 'vault_load' antes
    de liberar a UI. Remova 'vault_load' do Future.wait() e deixe o vault
    carregar em background. A HomeScreen já lida com o estado de loading
    (via AsyncValue) — use um skeleton/loading state lá em vez de segurar
    o splash.

  Etapa B — Invalidação cirúrgica em vez de total:
    Em vez de ref.invalidate(allObjectsProvider) após cada write, atualize
    diretamente a lista em memória. Os providers específicos (tasksProvider,
    habitsProvider etc.) já fazem isso corretamente — o problema é que eles
    TAMBÉM chamam invalidate(allObjectsProvider) por via indireta.

    Crie um método interno no AllObjectsNotifier:
      void patchObject(ContentObject updated) {
        // Substitui o objeto na lista em memória sem reler o disco
        if (state.hasValue) {
          final list = state.value!.toList();
          final idx = list.indexWhere((o) => o.id == updated.id);
          if (idx >= 0) list[idx] = updated;
          else list.add(updated);
          state = AsyncData(list);
        }
      }

    E em updateObject() / createObject() / deleteObject() do VaultNotifier,
    chame patchObject() em vez de invalidate(). Só invalide o provider completo
    quando for uma operação que afeta múltiplos arquivos (import, merge, etc.).

  Etapa C — Carregar apenas o necessário primeiro:
    Priorize carregar apenas os tipos usados na HomeScreen (tasks de hoje,
    hábitos de hoje, journal de hoje). Os demais tipos (social, trackers,
    snapshots, analyses) podem ser carregados sob demanda quando a tela
    correspondente é aberta. Isso requer separar o AllObjectsNotifier em
    provedores por pasta/tipo com lazy loading.


──────────────────────────────────────────────
1.2  obsidianServiceProvider é recriado a cada rebuild de settings
     (arquivo: lib/providers/vault_provider.dart, topo)
──────────────────────────────────────────────

PROBLEMA:
  O provider está declarado assim:
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final service = ObsidianService();
      final settings = ref.watch(settingsProvider);   // ← WATCH
      service.initVault(settings.vaultName, customPath: settings.vaultPath);
      return service;
    });

  Como usa ref.watch(settingsProvider), QUALQUER mudança nas settings
  (cor de acento, toggle de notificação, qualquer coisa) reconstrói o
  obsidianServiceProvider, criando uma nova instância de ObsidianService
  e re-inicializando o vault. Isso é desnecessário na maioria dos casos
  porque vaultName e vaultPath raramente mudam.

POR QUÊ É LENTO:
  - Recriar o ObsidianService dispara initVault() de novo,
    que verifica e cria pastas do vault.
  - Reconstruir o provider invalida automaticamente todos os providers que
    dependem dele, incluindo allObjectsProvider — o que força releitura total.

COMO RESOLVER:
  Use select() para escutar APENAS as propriedades relevantes:
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final vaultName = ref.watch(
        settingsProvider.select((s) => s.vaultName)
      );
      final vaultPath = ref.watch(
        settingsProvider.select((s) => s.vaultPath)
      );
      final service = ObsidianService();
      service.initVault(vaultName, customPath: vaultPath);
      return service;
    });

  Com isso, o provider só é recriado quando vaultName ou vaultPath mudam,
  não a cada mudança qualquer nas configurações.


──────────────────────────────────────────────
1.3  SettingsNotifier chama SharedPreferences.getInstance() em cada update
     (arquivo: lib/providers/settings_provider.dart)
──────────────────────────────────────────────

PROBLEMA:
  Cada método de update (updateAccentColor, updateAutoSync, etc.) faz:
    final prefs = await SharedPreferences.getInstance();

  SharedPreferences.getInstance() envolve um método nativo assíncrono.
  Embora seja cacheado internamente pelo plugin após a primeira chamada,
  chamar isto em cada update cria awaits desnecessários e código verboso.

COMO RESOLVER:
  O SettingsNotifier já recebe SharedPreferences no construtor (via
  sharedPreferencesProvider injetado no main). Guarde a referência:
    class SettingsNotifier extends StateNotifier<AppSettings> {
      final SharedPreferences _prefs;
      SettingsNotifier(SharedPreferences prefs)
          : _prefs = prefs,
            super(_buildFromPrefs(prefs));

      Future<void> updateAccentColor(String value) async {
        await _prefs.setString('accentColor', value);  // sem getInstance()
        state = state.copyWith(accentColor: value);
      }
      // ... todos os outros métodos idem
    }

  Isso elimina ~30 chamadas redundantes a getInstance().


──────────────────────────────────────────────
1.4  PeopleNotifier dispara AutomationService.checkPersonContacts no build()
     (arquivo: lib/providers/vault_provider.dart, classe PeopleNotifier)
──────────────────────────────────────────────

PROBLEMA:
  O build() do PeopleNotifier faz:
    if (people.isNotEmpty) {
      Future.microtask(
        () => AutomationService.checkPersonContacts(ref, people),
      );
    }

  O método checkPersonContacts (em automation_service.dart, linha 85)
  provavelmente itera por todas as pessoas e faz I/O ou lógica pesada.
  Isso é chamado toda vez que o provider é rebuilt — ou seja, toda vez
  que allObjectsProvider é invalidado (o que acontece com frequência).

COMO RESOLVER:
  Remova a chamada de checkPersonContacts do build().
  Em vez disso, chame-a explicitamente apenas quando:
    - A lista de pessoas muda de tamanho (nova pessoa adicionada)
    - O app é retomado (AppLifecycleState.resumed)
    - Uma vez por sessão no startup, via Future.microtask() no _initApp()

  No build(), retorne apenas a lista filtrada, sem side effects.


══════════════════════════════════════════════════════════════
  BLOCO 2 — LENTIDÃO AO NAVEGAR / ABRIR TELAS
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
2.1  Telas usam ref.watch(allObjectsProvider) direto em vez de providers específicos
     (arquivos: home_screen.dart e diversas telas)
──────────────────────────────────────────────

PROBLEMA:
  Várias telas observam allObjectsProvider e filtram os dados localmente.
  Quando allObjectsProvider é invalidado (o que acontece com frequência),
  TODAS essas telas são reconstruídas — mesmo que os dados relevantes pra
  aquela tela não tenham mudado.

COMO RESOLVER:
  Sempre use os providers específicos nas telas:
    - tasksProvider em vez de allObjectsProvider.filter(task)
    - habitsProvider em vez de allObjectsProvider.filter(habit)
    - notesProvider, goalsProvider, etc.

  Os providers específicos (TasksNotifier, HabitsNotifier etc.) já existem
  e mantêm estado em memória. A tela só será rebuilda quando o tipo
  específico dela mudar.


──────────────────────────────────────────────
2.2  backlinksProvider gera RegExp e itera por todos os objetos a cada chamada
     (arquivo: lib/providers/vault_provider.dart, backlinksProvider)
──────────────────────────────────────────────

PROBLEMA:
  O backlinksProvider faz:
    final content = obj.toMarkdown().toLowerCase();
    return targetKeys.any((key) => content.contains('[[$key]]') || ...);

  Isso chama toMarkdown() em TODOS os objetos do vault para cada objeto
  que está sendo exibido. Se você abre um detalhe e tem 300 objetos,
  300x toMarkdown() é chamado naquele momento.

COMO RESOLVER:
  Cache os backlinks calculados por objeto. Uma opção simples:
  - Adicione um campo opcional 'backlinks' ao ContentObject ou use um
    Map<String, List<String>> em memória no AllObjectsNotifier, populado
    uma única vez após o carregamento inicial.
  - Assim o backlinksProvider apenas consulta o cache em vez de recalcular.


──────────────────────────────────────────────
2.3  MyApp reconstrói os temas a cada rebuild porque parseia a cor inline
     (arquivo: lib/main.dart, classe MyApp)
──────────────────────────────────────────────

PROBLEMA:
  No build() do MyApp:
    theme: AppTheme.getLightTheme(
      Color(int.parse('ff' + settings.accentColor.replaceFirst('#', ''), radix: 16))
    ),

  Isso executa um parse de string e cria um objeto Color dentro do build().
  Se settingsProvider for rebuiltado por qualquer razão (o que acontece),
  o MaterialApp inteiro é reconstruído com um novo tema — causando um flash
  ou rebuild desnecessário.

COMO RESOLVER:
  Extraia a cor para uma variável local antes de usar, e use .select()
  para observar apenas accentColor:
    final accentHex = ref.watch(settingsProvider.select((s) => s.accentColor));
    final accentColor = Color(int.parse('ff${accentHex.replaceFirst('#', '')}', radix: 16));

  E coloque isso fora do build() em uma variável de estado, ou use
  um provider separado que só recalcula quando accentColor muda.


──────────────────────────────────────────────
2.4  TemplatesNotifier.build() chama _seedDefaultTemplates() via Future.microtask
     a cada rebuild
     (arquivo: lib/providers/vault_provider.dart, TemplatesNotifier)
──────────────────────────────────────────────

PROBLEMA:
  O build() verifica se a lista está vazia e enfileira seeding:
    if (list.isEmpty) {
      Future.microtask(() => _seedDefaultTemplates());
    }

  Como allObjectsProvider é invalidado com frequência, TemplatesNotifier
  é rebuiltado, e se os templates ainda não carregaram (estado transitório),
  _seedDefaultTemplates() pode ser chamado múltiplas vezes.
  O método interno já tem guarda (if templates.isNotEmpty return), mas o
  overhead de re-avaliar e agendar o microtask a cada rebuild existe.

COMO RESOLVER:
  Use uma flag de sessão ou _seeded no estado do Notifier para garantir
  que o seed só é disparado uma vez por sessão:
    bool _seeded = false;
    @override
    List<TemplateDefinition> build() {
      final list = ...;
      if (list.isEmpty && !_seeded) {
        _seeded = true;
        Future.microtask(() => _seedDefaultTemplates());
      }
      return list;
    }


══════════════════════════════════════════════════════════════
  BLOCO 3 — LENTIDÃO AO SALVAR / INTERAGIR
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
3.1  toggleHabit() cancela e reagenda 50 notificações a cada toggle
     (arquivo: lib/providers/vault_provider.dart, VaultNotifier._scheduleObjectReminders)
──────────────────────────────────────────────

PROBLEMA:
  O método _scheduleObjectReminders() e _cancelObjectReminders() fazem:
    for (int i = 0; i < 50; i++) {
      await NotificationService().cancelNotification(baseId + i);
    }

  Isso significa 50 chamadas assíncronas ao sistema de notificações A CADA
  vez que qualquer objeto é salvo ou atualizado. E _scheduleObjectReminders()
  é chamado dentro de _writeObject(), que é chamado por createObject,
  updateObject, e qualquer outro save.

POR QUÊ É LENTO:
  Chamadas nativas (cancelNotification) têm overhead de channel method call.
  50 awaits em sequência numa operação que o usuário percebe como síncrona
  (toggle de hábito) cria lag visível.

COMO RESOLVER:
  Reduza o loop de 50 para o número real de reminders do objeto:
    // Em vez de sempre 50:
    final maxSlots = max(object.reminders.length, 10);  // guarda mínimo razoável
    for (int i = 0; i < maxSlots; i++) { ... }

  Ou melhor: guarde quantos reminders foram agendados por objeto em
  SharedPreferences (uma entrada por objeto) e cancele apenas esse número.


──────────────────────────────────────────────
3.2  _writeObject() chama AutomationService.updateAllKPIs() após qualquer save
     de hábito, entry, note ou tracker
     (arquivo: lib/providers/vault_provider.dart, _shouldUpdateKpisAfterWrite)
──────────────────────────────────────────────

PROBLEMA:
  Após salvar um hábito, entrada de diário, nota ou tracker, o código dispara:
    Future.microtask(() => AutomationService.updateAllKPIs(ref));

  Se updateAllKPIs() relê o vault ou faz I/O para calcular KPIs de todos os
  objetos, isso é uma operação potencialmente cara sendo disparada toda vez
  que você togla um hábito ou salva um diário.

COMO RESOLVER:
  Adicione debounce ao updateAllKPIs. Em vez de chamar direto:
    Timer? _kpiDebounce;
    void _scheduleKpiUpdate() {
      _kpiDebounce?.cancel();
      _kpiDebounce = Timer(const Duration(seconds: 3), () {
        AutomationService.updateAllKPIs(ref);
      });
    }

  Assim, se você toglar 5 hábitos rapidamente, o KPI só é recalculado
  uma vez (3 segundos após o último toggle), não 5 vezes.


══════════════════════════════════════════════════════════════
  BLOCO 4 — QUALIDADE DE VIDA / PREVENÇÃO
══════════════════════════════════════════════════════════════

──────────────────────────────────────────────
4.1  Compilar em modo release para testes de performance
──────────────────────────────────────────────

OBSERVAÇÃO IMPORTANTE:
  Nunca teste performance em modo debug (flutter run sem flags).
  O modo debug tem overhead massivo do Dart VM + DevTools instrumentation
  que distorce a percepção de lentidão. Sempre use:
    flutter run --release
  ou instale o APK de release direto no dispositivo. Se o app ainda estiver
  lento em release, os problemas são reais (como os listados acima).


──────────────────────────────────────────────
4.2  Widgets reconstruídos desnecessariamente por falta de const
──────────────────────────────────────────────

PROBLEMA:
  Em diversas telas e widgets, componentes que não dependem de estado são
  construídos sem const. Por exemplo:
    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(...))
  na splash screen, e similares em cards e listas.

COMO RESOLVER:
  Adicione const a widgets estáticos onde possível. O Flutter reusa
  instâncias com const, eliminando rebuilds. Use o lint rule
  prefer_const_constructors para identificar candidatos automaticamente:
    flutter analyze --no-fatal-infos | grep prefer_const


──────────────────────────────────────────────
4.3  getFilesInFolder usa list(recursive: true) sem filtrar extensão no SO
     (arquivo: lib/services/obsidian_service.dart, linha ~189)
──────────────────────────────────────────────

PROBLEMA:
  O método lista TODOS os arquivos recursivamente e filtra .md no Dart:
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) { ... }  // sem filtro de extensão aqui
    }
  O filtro de extensão (.endsWith('.md')) é feito no AllObjectsNotifier,
  não no getFilesInFolder. Isso significa que arquivos de imagem, PDFs
  e outros em _attachments são lidos pelo stream antes de serem descartados.

COMO RESOLVER:
  Adicione filtro de extensão dentro do getFilesInFolder:
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.md')) {
        ...
      }
    }
  Isso reduz o trabalho de iteração do stream e a criação de objetos File
  desnecessários para cada arquivo de attachment.


──────────────────────────────────────────────
4.4  obsidianServiceProvider cria nova instância de ObsidianService a cada build
     (arquivo: lib/providers/vault_provider.dart)
──────────────────────────────────────────────

PROBLEMA (complementar ao 1.2):
  Mesmo após o fix do select(), o Provider<ObsidianService> cria uma nova
  instância a cada vez que é rebuilt. ObsidianService tem estado interno
  (_currentVaultName, vaultDir) que é perdido.

COMO RESOLVER:
  Use StateProvider ou um singleton manual para que a mesma instância de
  ObsidianService persista por toda a sessão:
    final _obsidianServiceInstance = ObsidianService();
    final obsidianServiceProvider = Provider<ObsidianService>((ref) {
      final vaultName = ref.watch(settingsProvider.select((s) => s.vaultName));
      final vaultPath = ref.watch(settingsProvider.select((s) => s.vaultPath));
      _obsidianServiceInstance.initVault(vaultName, customPath: vaultPath);
      return _obsidianServiceInstance;
    });

  Importante: initVault() já tem guarda contra reinicialização desnecessária
  (verifica _currentVaultName), então reusar a mesma instância é seguro.


══════════════════════════════════════════════════════════════
  PRIORIDADE SUGERIDA DE IMPLEMENTAÇÃO
══════════════════════════════════════════════════════════════

1. [ALTO IMPACTO, FÁCIL]  Item 1.2 — select() no obsidianServiceProvider
   → Evita recarregar o vault a cada mudança de settings. ~1h de trabalho.

2. [ALTO IMPACTO, FÁCIL]  Item 1.3 — Guardar _prefs no SettingsNotifier
   → Elimina awaits redundantes. ~30min de trabalho.

3. [ALTO IMPACTO, MÉDIO]  Item 1.1 Etapa A — Remover vault_load do Future.wait()
   → A splash some mais rápido; HomeScreen já tem skeleton. ~2h de trabalho.

4. [ALTO IMPACTO, MÉDIO]  Item 3.1 — Reduzir loop de 50 cancelamentos
   → Toggle de hábito fica perceptivelmente mais rápido. ~1h.

5. [MÉDIO IMPACTO, MÉDIO] Item 1.1 Etapa B — patchObject() em vez de invalidate()
   → Maior mudança arquitetural mas elimina a raiz do problema de releitura. ~4h.

6. [MÉDIO IMPACTO, FÁCIL] Item 2.3 — Cor do tema via select()
   → Evita rebuilds do MaterialApp. ~30min.

7. [MÉDIO IMPACTO, FÁCIL] Item 4.3 — Filtro .md dentro de getFilesInFolder
   → Menos objetos File criados na iteração. ~15min.

8. [MÉDIO IMPACTO, MÉDIO] Item 3.2 — Debounce no updateAllKPIs
   → Evita recalcular KPIs redundantemente. ~1h.

9. [BAIXO IMPACTO, FÁCIL] Item 2.4 — Flag _seeded no TemplatesNotifier
   → Evita microtasks redundantes. ~20min.

10.[BAIXO IMPACTO, FÁCIL] Item 1.4 — Remover checkPersonContacts do build()
   → Elimina side effect inesperado. ~30min.

=============================================================
  FIM DO DOCUMENTO
=============================================================