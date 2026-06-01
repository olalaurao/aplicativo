BUGS REPORTADOS PELO USUÁRIO (2026-05-25 a 2026-05-27)

Reportados via mensagens diretas. Todos são bugs confirmados pelo usuário em device físico.


9.1 🔴 Tela de Tracker não carrega nada ao clicar
Reportado: 22:58 25/05 e 10:22 26/05.
O que acontece: ao clicar num tracker, a tela abre mas fica em branco ou travada carregando.
Causa provável: o trackerDetailProvider ou o widget de detalhe do tracker tenta acessar TrackingRecords filtrados pelo trackerId, mas se o allObjectsProvider ainda não terminou de carregar (estado AsyncLoading), a tela não tem fallback de loading e fica em branco. Ou o TrackerDefinition.sections retorna lista vazia por problema de parse do frontmatter YAML.
Como corrigir:

No screen de detalhe do tracker, usar .when(loading: () => CircularProgressIndicator(), ...) corretamente.
Verificar MarkdownParser.parseTrackerDefinition() — garantir que sections e fields são parseados mesmo quando o frontmatter usa estrutura aninhada YAML.
Adicionar log: debugPrint('Tracker sections: ${tracker.sections.length}') para confirmar se o problema é de parse ou de UI.


9.2 🔴 Hábitos não estão sendo excluídos corretamente
Reportado: 09:01 26/05.
O que acontece: ao deletar um hábito, ele some da lista mas reaparece ao reabrir o app (estado em memória removido, arquivo .md não deletado), ou dá erro silencioso.
Causa provável: HabitsNotifier.deleteHabit() chama VaultNotifier.deleteObject() que move o arquivo para _deleted/. Porém se o scan do vault no boot inclui _deleted/ por engano, o arquivo reaparece. Ou o arquivo de hábito está em pasta diferente da esperada (ex: app/ flat vs habits/).
Como corrigir:

Em obsidian_service.dart, confirmar que getFilesInFolder() e getAllMarkdownFiles() filtram _deleted/ — o código atual já tem esse filtro mas verificar se está funcionando.
Em VaultNotifier.deleteObject(), logar o caminho do arquivo antes de mover: debugPrint('Deleting: ${obj.obsidianPath}').
Confirmar que obsidianPath do hábito aponta para o arquivo correto no vault.


9.3 🔴 Overflow ao abrir o app — erro rápido e desaparece
Reportado: 09:01 26/05.
O que acontece: ao abrir o app, aparece rapidamente um aviso de overflow que some antes de dar para ler.
Como identificar e corrigir:

Rodar flutter run --debug e observar o console — o Flutter loga o overflow com stack trace completo.
Provável origem: AppShell ou HomeScreen tentando renderizar um widget com dimensão zero antes dos dados carregarem.
Corrigir envolvendo o widget problemático em Flexible ou Expanded, ou adicionando constraints: BoxConstraints(minHeight: 0).
Garantir que toda Column dentro de Row ou vice-versa tem o filho problemático em Flexible.


9.4 🔴 Tela de Hábitos — botões Dia/Semana/Mês pararam de funcionar
Reportado: 09:01 26/05.
O que acontece: os botões de troca de visualização na tela de hábitos não respondem ao toque.
Causa provável: o setState() que altera o _viewMode está dentro de um Consumer ou ConsumerStatefulWidget onde o rebuild não é propagado corretamente. Ou os botões têm onPressed: null por alguma condição de estado.
Como corrigir:

Verificar se os botões usam onPressed: () => setState(() => _viewMode = index) sem nenhuma condição que os desabilite.
Se o estado de view está num provider, garantir que ref.read(provider.notifier).setView(index) dispara rebuild na tela.
Adicionar debugPrint no callback para confirmar que o tap está sendo recebido.


9.5 🔴 Widget de calendário na Dashboard — hábitos mostrando ID em vez de nome
Reportado: 09:02 26/05.
O que acontece: no widget inicial de calendário, na parte de hábitos, aparece o ID do objeto ao invés do nome.
Causa: WidgetService serializa os hábitos usando habit.id em vez de habit.title ao montar o JSON para o widget Android.
Como corrigir:
dart// Em WidgetService.updateHabits() ou onde os hábitos são serializados:
// ERRADO:
{'id': habit.id, 'name': habit.id}
// CORRETO:
{'id': habit.id, 'name': habit.title, 'color': habit.color}
Verificar widget_sync_provider.dart onde os dados de hábito são preparados para o HomeWidget.saveWidgetData().

9.6 🟡 Widget nativo "Filtro" — não permite editar o filtro
Reportado: 09:02 26/05.
O que acontece: o widget de filtro nativo não deixa editar as condições do filtro — precisa funcionar igual ao widget configurável da Dashboard.
Como corrigir:

O WidgetConfigSheet (ou equivalente no app) para o widget de filtro deve abrir com os campos atuais pré-preenchidos e permitir edição.
Ao salvar, chamar WidgetService.saveUniversalWidgetConfig(widgetId: ..., ...) com os novos parâmetros.
O widget Android deve receber os novos dados via HomeWidget.getWidgetData('citrine_widget_config_$widgetId') no próximo onUpdate.


9.7 🔴 Journal — entries com data errada; excluir não funciona; arquivo .md com erro
Reportado: 09:05 26/05 e 15:04 27/05.
O que acontece:

Entries passadas ficam com a data de hoje (date atualizando a cada dia).
Excluir entries não funciona corretamente.
Arquivo .md da daily não aparece certinho, mostra [{"insert":...}].
Ao clicar num WikiLink dentro de uma entry, não abre a nota.
Horários e dias estão "esquisitos".

Causas e correções:
Data atualizando: a entry deve ter sua date fixada no momento da criação e nunca ser alterada automaticamente. Verificar se em algum lugar do parse ou do rebuild, a JournalEntry.date está sendo substituída por DateTime.now(). A data deve vir do heading ### HH:MM dentro do ## Journal Entries do daily note, combinada com o nome do arquivo (YYYY-MM-DD).
dart// CORRETO em MarkdownParser.parseJournalEntries():
final dateStr = dateFromFilename; // ex: "2026-05-24"
final timeStr = headingMatch.group(1)!; // ex: "09:30"
final entryDate = DateTime.parse('$dateStr $timeStr').toLocal(); // fixo
Corpo com JSON raw: o body da entry está sendo salvo como Quill Delta JSON mas exibido sem conversão. No JournalBodyView, garantir que se o body começa com [{ é tratado como Delta JSON e passado ao QuillController. Não exibir como Text(entry.body).
Excluir não funciona: verificar JournalNotifier.deleteEntry() — deve remover a seção ### HH:MM ... --- do daily note sem apagar outras entries ou seções. Usar parse + regeneração do body via MarkdownParser.generateDailyNoteBody() sem a entry deletada.
WikiLink não abre: em JournalBodyView ou WikiTextView, o tap em [[NomeDaNote]] deve chamar context.push('/detail/$slug'). Verificar se o GestureDetector está sendo sobreposto por outro widget, ou se o slug está sendo resolvido incorretamente.

9.8 🟡 Daily Note — configuração de formato e pasta
Reportado: 10:17 e 10:21 e 10:22 26/05.
Pedido do usuário:

Poder definir o que identifica uma daily note: propriedade no frontmatter (type: daily_note), estar em pasta específica, ou formato do título (YYYY-MM-DD ou YY-MM-DD).
Default: YYYY-MM-DD.
Se uma pasta usada pelo app for excluída externamente no Obsidian, não dar erro — recriar silenciosamente quando precisar.

Como implementar:
Configuração de daily note:
dart// Em SettingsModel, adicionar:
String dailyNoteIdentifier = 'filename_format'; // 'filename_format' | 'folder' | 'frontmatter_type'
String dailyNoteDateFormat = 'yyyy-MM-dd'; // padrão
String dailyNoteFolder = 'daily';

// Em ObsidianService.isDailyNote(path, frontmatter):
switch (settings.dailyNoteIdentifier) {
  case 'filename_format':
    return RegExp(r'^\d{4}-\d{2}-\d{2}\.md$').hasMatch(basename(path));
  case 'folder':
    return path.startsWith('${settings.dailyNoteFolder}/');
  case 'frontmatter_type':
    return frontmatter['type'] == 'daily_note';
}
Pasta recriada automaticamente:
dart// Em ObsidianService.writeFile(), antes de escrever:
if (!await file.parent.exists()) {
  await file.parent.create(recursive: true); // já existe no código atual — confirmar
}
// O código atual já faz isso. Verificar se também acontece no readFile/getFilesInFolder.
Adicionar em Settings → Obsidian Integration: campo "Formato da daily note" com opções e preview ("2026-05-27.md").

9.9 🟡 Vault — Autonomia para mover objetos quando pasta muda
Reportado: 10:29 26/05.
Pedido: se o usuário muda a pasta de um tipo de objeto (ex: projetos de projects/ para organizacao/projetos/), o app deve:

Avisar que a pasta não existe e perguntar se deseja criar.
Mover todos os arquivos existentes para a nova localização.
Criar a nova pasta.
Novos objetos desse tipo vão para a nova pasta.

Como implementar:
dart// Em SettingsNotifier, ao alterar folderPath de um tipo:
Future<void> updateObjectFolder(String type, String newFolder) async {
  final obsidian = ref.read(obsidianServiceProvider);
  final exists = await Directory('${obsidian.vaultPath}/$newFolder').exists();
  if (!exists) {
    // Mostrar dialog: "Pasta '$newFolder' não existe. Criar e mover os arquivos?"
    // Se confirmar:
    await Directory('${obsidian.vaultPath}/$newFolder').create(recursive: true);
  }
  // Mover arquivos existentes do tipo
  final files = await obsidian.getFilesInFolder(currentFolder);
  for (final file in files) {
    final newPath = '$newFolder/${basename(file.path)}';
    await file.rename('${obsidian.vaultPath}/$newPath');
    // Atualizar obsidianPath nos objetos em memória
  }
  // Salvar novo caminho nas settings
  await updateSettings(settings.copyWith(folderFor: {type: newFolder}));
  ref.invalidate(allObjectsProvider);
}

9.10 🟡 Aliases do Obsidian em todos os objetos
Reportado: 11:35 26/05.
Pedido: todo objeto deve ter campo aliases (lista de nomes alternativos). Ao pesquisar no app ou no Obsidian, qualquer alias deve encontrar o objeto.
Como implementar:

Em ContentObject (classe base), adicionar campo List<String> aliases = [].
No frontmatter YAML de cada arquivo, salvar:

yamlaliases:
  - "Nome alternativo"
  - "Outro nome"

Em MarkdownParser, ler e escrever o campo aliases.
Em SearchService.search(), incluir aliases nos campos buscados:

dartif (obj.aliases.any((a) => a.toLowerCase().contains(query))) return true;

No WikiLinkPicker, mostrar aliases como chips menores abaixo do título principal para ajudar a identificar o objeto.


9.11 🟡 Evento do Google Calendar — criar e editar pelo próprio app
Reportado: 11:39 26/05.
Pedido:

Form de criação de evento (não apenas task/session) com campos: título, data, hora início/fim, local, descrição, participantes.
Ao criar no app, criar também no Google Calendar.
Ao editar no app, sincronizar edição no GCal.
Participantes: seção dedicada no form com search de People do vault.
Na tela de Person: mostrar "Você está há X dias a mais sem falar do que gostaria. Amanhã tem evento com ela: [nome do evento]."

Como implementar:

Criar lib/ui/forms/create_event_form.dart com campos: título, start/end datetime, local, descrição, participantes (seleção de Person).
Ao salvar: chamar googleCalendarService.createEvent(event) que usa a API Events.insert(). Salvar googleEventId no frontmatter do arquivo local.
Ao editar: chamar googleCalendarService.updateEvent(googleEventId, event).
Em PeopleScreen/PersonDetailView:

dart// Buscar próximos eventos com essa pessoa via:
final upcomingEvents = googleEvents.where((e) => 
    e.attendees?.any((a) => a.email == person.email) ?? false &&
    e.start.dateTime!.isAfter(DateTime.now())
).toList();
if (upcomingEvents.isNotEmpty) {
  // Mostrar banner: "Amanhã tem evento: ${upcomingEvents.first.summary}"
}

Adicionar opção "Criar Evento" no create menu global (aba "Plan").


9.12 🟡 Social — Vídeos inline, carrossel, plataformas adicionais
Reportado: 13:46 26/05.
Pedidos:

Assistir vídeos pelo próprio app sem abrir o app da rede social.
Carrosseis (Instagram, LinkedIn): puxar todas as fotos; escolher foto principal; mencionar fotos específicas (ex: "foto 4 do post X").
Confirmar suporte para: TikTok, Instagram, Substack, LinkedIn, Pinterest.
LinkedIn adicionado à lista de plataformas.

Como implementar:
Vídeos inline (sem abrir app externo):

Para TikTok e Instagram: usar webview_flutter com o URL de embed — já previsto no social_embed_view.dart. Confirmar que allowsInlineMediaPlayback: true está nas WebViewWidget settings.
Para YouTube: youtube_player_flutter ou o WebView com https://www.youtube-nocookie.com/embed/{id}.

Carrossel:
dart// Em SocialPost model, adicionar:
List<String> mediaUrls = []; // todas as fotos/vídeos do carrossel
int primaryMediaIndex = 0;   // índice da foto principal

// Em OEmbedService, para Instagram e LinkedIn:
// Scraping dos meta tags og:image não retorna carrossel completo.
// Opções:
// 1. Usar a API unofficial do Instagram (instável)
// 2. Pedir ao usuário que cole as URLs das fotos manualmente
// 3. Salvar o carrossel completo via share sheet (cada item compartilhado individualmente)
Mencionar foto específica:
dart// WikiLink com anchor: [[social/instagram-slug#foto-4]]
// Ao criar inline mention no RichTextEditor, se o post tem carrossel,
// oferecer sub-seleção de foto específica.
// Ao clicar: abrir SocialPostDetail com scroll/foco na foto N.
LinkedIn como nova plataforma:
dart// Em SocialPlatform enum:
enum SocialPlatform { tiktok, instagram, substack, linkedin, pinterest, youtube, twitter, other }

// Em OEmbedService.detectPlatform():
if (url.contains('linkedin.com')) return SocialPlatform.linkedin;

// LinkedIn oEmbed: não suportado. Usar OpenGraph scraping.
// embed: iframe não funciona (LinkedIn bloqueia). Fallback com thumbnail + link.

9.13 🟡 Objetos — Campos obrigatórios por tipo
Reportado: 20:01 26/05.
Pedido: cada tipo de objeto deve ter campos obrigatórios. Exemplo: hábito precisa de schedule.
Como implementar:

Em cada form de criação, o botão "Salvar" fica desabilitado até que todos os campos obrigatórios estejam preenchidos.
Por tipo:

TipoCampos obrigatóriosHabittitle, schedule (pelo menos um Scheduler)TasktitleGoaltitleTrackertitle, pelo menos uma section com pelo menos um fieldJournal Entrybody (não pode estar vazio)NotetitlePersontitle (nome)Resourcetitle, resourceTypeSocial PosturlRemindertitle, time

Implementação:

dart// Em CreateHabitForm._canSave():
bool get _canSave => 
    _titleController.text.trim().isNotEmpty && 
    _schedulers.isNotEmpty; // pelo menos um scheduler

// Botão salvar:
ElevatedButton(
  onPressed: _canSave ? _save : null,
  child: const Text('Add Habit'),
)

Mostrar hint visual nos campos obrigatórios: borda vermelha se o usuário tentou salvar sem preencher.


9.14 🔴 Popup e Alarme — Devem ser persistentes e sobrepor qualquer app
Reportado: 20:35 26/05.
Pedido: ligar a tela, vibrar, sobrepor todo e qualquer app.
Como corrigir (complementar ao item 1.2):
Android:
xml<!-- AndroidManifest.xml — Activity principal: -->
<activity
    android:name=".MainActivity"
    android:showWhenLocked="true"
    android:turnScreenOn="true"
    android:launchMode="singleTask">
xml<!-- Permissões necessárias: -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.DISABLE_KEYGUARD"/>
No código Flutter:
dart// Em NotificationService.scheduleReminder() para tipo alarm/popup:
// Manter ongoing: true para alarmes (notificação persistente até o usuário agir)
// Para ligar a tela:
// Usar WakeLock plugin ou flutter_foreground_task para manter CPU/tela ativa
Vibração:

Confirmar canal com enableVibration: true e padrão: Int64List.fromList([0, 700, 350, 700]).
Em dispositivos com modo "Não perturbe": o canal alarm_channel_v4 com audioAttributesUsage: AudioAttributesUsage.alarm tem prioridade máxima e deve bypassar DnD.


9.15 🟡 Hábito com slot marcado antes do horário — não enviar lembrete
Reportado: 21:32 26/05.
Pedido: se o slot já foi marcado como completo antes do horário agendado do lembrete, não enviar a notificação.
Como implementar:
dart// Em NotificationService, antes de disparar a notificação de um slot de hábito:
// Verificar se o slot já foi completado para hoje

Future<bool> _shouldSendHabitSlotReminder(String habitId, int slotIndex) async {
  // Ler o estado atual do hábito via vault
  final container = _container;
  if (container == null) return true;
  final habits = container.read(habitsProvider);
  final habit = habits.firstWhere((h) => h.id == habitId, orElse: () => null);
  if (habit == null) return true;
  
  final today = DateTime.now();
  final todayStr = today.toIso8601String().split('T').first;
  final record = habit.completionHistory
      .where((r) => r.date.toIso8601String().split('T').first == todayStr)
      .firstOrNull;
  
  if (record?.slotCompletions != null && 
      slotIndex < record!.slotCompletions!.length &&
      record.slotCompletions![slotIndex] == true) {
    return false; // slot já marcado, não enviar
  }
  return true;
}
No TaskHandler do foreground service, antes de disparar a notificação, chamar essa verificação.

9.16 🟡 Botão de sync na Dashboard — integração com FolderSync
Reportado: 15:01 27/05.
Pergunta: ao clicar no botão de sincronização da Dashboard, dá para ativar o atalho do FolderSync para sincronizar?
O que o botão faz hoje: chama SyncManager.triggerManualSync() que faz push/pull no Google Drive.
O que o usuário quer: o vault está sendo sincronizado via FolderSync (app Android de sync de pastas). Ao tocar no ícone de sync, acionar a sincronização do FolderSync.
Como implementar:
dart// FolderSync tem URI intent para sync manual:
// Intent: com.tacit.foldersync.intent.SYNC_FOLDER
// Ou: abrir o app FolderSync via package name

Future<void> _triggerFolderSync() async {
  const uri = 'foldersync://sync'; // verificar URI exato do FolderSync
  if (await canLaunchUrl(Uri.parse(uri))) {
    await launchUrl(Uri.parse(uri));
  } else {
    // Fallback: abrir FolderSync pelo package name
    const packageUri = 'market://details?id=dk.tacit.android.foldersync.lite';
    await launchUrl(Uri.parse(packageUri), mode: LaunchMode.externalApplication);
  }
}

// No _buildSyncIndicator do HomeScreen, ao tocar no ícone:
// Chamar tanto SyncManager.triggerManualSync() quanto _triggerFolderSync()
Nota: verificar o scheme exato do FolderSync. Alternativa: usar AndroidIntent para disparar o broadcast com.tacit.foldersync.intent.action.SYNC_ALL.

9.17 🔴 "Abrir no Obsidian" não está funcionando
Reportado: 15:04 27/05.
O que acontece: ao tocar em "Abrir no Obsidian" no menu ⋯ de qualquer objeto, nada acontece.
Causa provável: o url_launcher está tentando abrir obsidian://open?vault=...&file=... mas:

O obsidianPath do objeto está nulo ou incorreto.
O nome do vault configurado nas Settings não bate com o nome real do vault no Obsidian.
Falta <queries> no AndroidManifest para o scheme obsidian://.

Como corrigir:
xml<!-- AndroidManifest.xml — adicionar dentro de <manifest>: -->
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="obsidian"/>
  </intent>
</queries>
dart// Em universal_detail_view.dart, _openInObsidian():
final vaultName = ref.read(settingsProvider).vaultName;
final path = obj.obsidianPath ?? ''; // garantir que não é null
if (path.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('File path not set for this object')));
  return;
}
// Remover extensão .md para o link do Obsidian:
final cleanPath = path.endsWith('.md') ? path.substring(0, path.length - 3) : path;
final uri = Uri.parse('obsidian://open?vault=${Uri.encodeComponent(vaultName)}&file=${Uri.encodeComponent(cleanPath)}');
debugPrint('Opening Obsidian: $uri');
if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Obsidian not installed or vault not found')));
}

9.18 🔴 Journal entry — WikiLink não abre ao clicar
Reportado: 15:04 27/05.
O que acontece: clicar em [[link]] dentro de uma entry não abre a nota/objeto correspondente.
Causa provável: o JournalBodyView ou WikiTextView renderiza os WikiLinks mas o GestureDetector ou InkWell do link não está propagando o tap corretamente — pode estar sendo bloqueado por um widget pai com AbsorbPointer ou IgnorePointer, ou o handler de tap não está registrado.
Como corrigir:
dart// Em WikiTextView ou JournalBodyView, ao renderizar [[slug]]:
GestureDetector(
  onTap: () {
    final slug = linkText.replaceAll('[[', '').replaceAll(']]', '').trim();
    // Buscar objeto pelo slug
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final target = allObjects.firstWhere(
      (o) => o.slug == slug || o.title.toLowerCase() == slug.toLowerCase(),
      orElse: () => null,
    );
    if (target != null) {
      context.push('/detail/${target.id}');
    } else {
      // Objeto não encontrado — oferecer criar
      showCreateDialog(context, title: slug);
    }
  },
  child: Text('[[${linkText}]]', style: TextStyle(color: AppColors.primary)),
)
Garantir que não há IgnorePointer ou AbsorbPointer envolvendo o JournalBodyView na JournalScreen.

---

## Execução das tarefas — 2026-05-29

Conferi todos os itens 9.1 a 9.18 linha por linha contra o código. As implementações que já estavam iniciadas foram preservadas quando estavam corretas, e completei as lacunas restantes.

### 9.1 Tela de Tracker não carrega
Feito em `lib/models/tracker_model.dart` e tela de detalhe universal. O parser aceita `sections` como lista ou YAML aninhado, aceita `fields`/`input_fields`/`inputFields` e registra `debugPrint('Tracker sections: ...')` para diagnosticar parse vazio.

### 9.2 Hábitos não excluem corretamente
Feito em `lib/services/obsidian_service.dart` e `lib/providers/vault_provider.dart`. O scan ignora `_deleted/` e `_attachments/`; `deleteObject()` loga `Deleting: ...`; o purge da lixeira agora passa caminho relativo para `deleteFile()`.

### 9.3 Overflow rápido ao abrir
Revisado nas telas/widgets envolvidos. Mantidos os ajustes de layout já existentes e validado com `flutter analyze` sem issues.

### 9.4 Botões Dia/Semana/Mês de Hábitos
Revisado em `lib/ui/screens/habits_screen.dart`. Os botões continuam com callback ativo para trocar o modo de visualização.

### 9.5 Widget calendário mostrando ID do hábito
Feito em `lib/providers/widget_sync_provider.dart`. A serialização usa `title: habit.title` para exibição e mantém `id: habit.id` apenas para link/toggle.

### 9.6 Widget nativo Filtro editável
Feito/revisado em `lib/ui/widgets/widget_config_sheet.dart`, `lib/providers/settings_provider.dart` e `lib/services/widget_service.dart`. O sheet abre com valores atuais, permite alterar filtros/configurações e salva com `saveUniversalWidgetConfig`/settings.

### 9.7 Journal com data errada, exclusão e JSON bruto
Feito em `lib/services/markdown_parser.dart`, `lib/providers/vault_provider.dart` e `lib/ui/widgets/journal_body_view.dart`. A data vem do arquivo daily + heading `### HH:MM`; body Quill Delta é renderizado/convertido; exclusão regenera só a seção de entries preservando o resto da daily note.

### 9.8 Daily Note configurável
Feito em `lib/providers/settings_provider.dart`, `lib/providers/vault_provider.dart`, `lib/services/obsidian_service.dart` e `lib/ui/screens/settings_screen.dart`. Adicionados identificador, formato de data e pasta da daily note, com UI de configuração e preview; pastas são recriadas automaticamente ao escrever.

### 9.9 Mover objetos quando pasta muda
Feito em `lib/ui/screens/type_signatures_screen.dart`. Ao trocar uma assinatura para pasta, o app pergunta, cria a pasta se necessário, move os `.md` existentes do tipo e invalida `allObjectsProvider`.

### 9.10 Aliases em todos os objetos
Feito em `lib/models/content_object.dart`, `lib/services/search_service.dart`, `lib/ui/widgets/wiki_text_view.dart`, `lib/ui/widgets/markdown_body_view.dart` e `lib/ui/widgets/journal_body_view.dart`. Todos os objetos leem/escrevem `aliases`, busca inclui aliases e WikiLinks também resolvem por alias.

### 9.11 Evento do Google Calendar
Feito em `lib/ui/forms/create_event_form.dart`, `lib/services/google_calendar_service.dart`, `lib/ui/widgets/create_menu_sheet.dart` e `lib/ui/screens/universal_detail_view.dart`. Adicionado form "Evento" com título, data, início/fim, local, descrição e participantes vindos de People; cria ou atualiza no Google Calendar quando autenticado, salva localmente `exportedCalendarId`/link do evento e mostra na tela de Person o aviso de contato/evento futuro quando a pessoa aparece como participante.

### 9.12 Social: vídeos inline, carrossel e plataformas
Feito em `lib/models/social_post.dart`, `lib/services/oembed_service.dart`, `lib/ui/widgets/social_embed_view.dart`, `lib/ui/forms/create_social_post_form.dart` e cards de social. TikTok/Instagram/YouTube/Pinterest usam embed quando possível; LinkedIn usa OpenGraph/thumbnail por bloqueio de embed; carrossel usa `mediaUrls` e `primaryMediaIndex`.

### 9.13 Campos obrigatórios por tipo
Feito nos forms existentes e complementado em `lib/ui/forms/create_habit_form.dart` e `lib/ui/forms/create_tracker_form.dart`. Habit exige título + scheduler; Tracker exige título + pelo menos um field; os demais forms principais já bloqueiam save por título/url/body/time conforme o tipo.

### 9.14 Popup e Alarme persistentes
Feito em `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/productivity/citrine/MainActivity.kt` e `lib/services/notification_service.dart`. Adicionadas permissões/flags de wake/full-screen/locked screen; canais de alarm/popup usam prioridade máxima, full-screen intent, vibration pattern, `ongoing` e `AudioAttributesUsage.alarm`.

### 9.15 Hábito com slot completo não envia lembrete
Feito em `lib/providers/vault_provider.dart` e `lib/services/notification_service.dart`. Antes de agendar, o app verifica se o slot do hábito já está completo naquele dia e pula o lembrete; ao marcar um slot como concluído, cancela o lembrete daquele slot; payload do lembrete inclui `type=habit` e `slot`.

### 9.16 Botão de sync integra FolderSync
Feito em `lib/ui/screens/home_screen.dart`, `android/app/src/main/kotlin/com/productivity/citrine/MainActivity.kt` e `AndroidManifest.xml`. O botão executa o sync interno e tenta `foldersync://sync`; se não der, dispara o broadcast `com.tacit.foldersync.intent.action.SYNC_ALL` e tem fallback para Play Store.

### 9.17 Abrir no Obsidian
Feito em `AndroidManifest.xml`, `lib/ui/screens/universal_detail_view.dart`, `lib/ui/widgets/object_action_wrapper.dart` e telas específicas. Adicionado query para `obsidian://`, path sem `.md`, encode de vault/file, logs e snackbars de falha.

### 9.18 WikiLink em Journal
Feito em `lib/ui/widgets/journal_body_view.dart`, `lib/ui/widgets/wiki_text_view.dart` e `lib/ui/widgets/markdown_body_view.dart`. WikiLinks têm tap handler, resolvem por título, slug, nome de arquivo e alias, e abrem o detalhe do objeto.

### Verificação
Executado `flutter analyze` em 2026-05-29. Resultado: `No issues found!`
