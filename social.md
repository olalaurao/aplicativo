# Social — Especificação Completa

> Módulo para arquivar, assistir e citar posts de redes sociais dentro do Citrine.
> Obsidian é a fonte da verdade. Cada post é um `.md` no vault.
> Todos os posts são citáveis por qualquer objeto do app via WikiLink `[[social/slug]]`.

---

## Índice

1. [Visão geral e princípios](#1-visão-geral-e-princípios)
2. [S1 — Modelo, vault e provider](#2-s1--modelo-vault-e-provider)
3. [S2 — Serviço oEmbed + formulário de captura](#3-s2--serviço-oembed--formulário-de-captura)
4. [S3 — Social Screen e feed](#4-s3--social-screen-e-feed)
5. [S4 — Post Detail View](#5-s4--post-detail-view)
6. [S5 — Embed in-app (ver vídeo e conteúdo)](#6-s5--embed-in-app)
7. [S6 — Organização por coleções](#7-s6--organização-por-coleções)
8. [S7 — Cross-references: citar posts em outros objetos](#8-s7--cross-references)
9. [S8 — Obsidian integration](#9-s8--obsidian-integration)
10. [S9 — Share sheet e import em lote](#10-s9--share-sheet-e-import-em-lote)
11. [Apêndice A — Widgets utilitários completos](#apêndice-a--widgets-utilitários-completos)
12. [Apêndice B — Casos de borda e tratamento de erros](#apêndice-b--casos-de-borda-e-tratamento-de-erros)
13. [Apêndice C — `navigatorKey` e share intent](#apêndice-c--navigatorkey-e-share-intent)
14. [Apêndice D — Conflito long press: multi-select vs ObjectActionWrapper](#apêndice-d--conflito-long-press)
15. [Apêndice E — CreateSocialPostForm em modo edição](#apêndice-e--createsocialpostform-em-modo-edição)
16. [Apêndice F — Ordem de implementação e arquivos](#apêndice-f--ordem-de-implementação-e-arquivos)

---

## 1. Visão geral e princípios

### O que é

A seção Social é uma biblioteca de posts salvos de redes sociais. O usuário cola uma URL do TikTok, Instagram, Substack ou Pinterest; o app busca os metadados automaticamente (título, thumbnail, caption, autor); o post é salvo como arquivo `.md` no vault na pasta `social/`. A partir daí, o post pode ser assistido dentro do app, organizado em coleções (via o sistema de Organizers existente), citado por goals, tasks, notes e qualquer outro objeto do vault, e aberto no Obsidian como qualquer outro arquivo.

### Princípios que guiam cada decisão

- **Obsidian como fonte da verdade.** Nada é guardado só no banco local. Cada post tem um `.md` com frontmatter completo. Se o usuário deletar o arquivo no Obsidian, o post some do app no próximo sync.
- **Citabilidade total.** Todo post tem um `obsidianPath` do tipo `social/platform-slug.md`. Qualquer campo WikiLink do app pode referenciar `[[social/platform-slug]]`. O `backlinksProvider` já existente detecta automaticamente essas referências — não precisa de código extra para backlinks funcionarem.
- **Reutilizar o que já existe.** O sistema de `Organizers` (área, projeto, label) já é o mecanismo de organização do app. Posts têm `organizers: List<OrganizerReference>` herdado de `ContentObject` — usar isso diretamente, sem inventar "coleções" novas.
- **Zero novas dependências até S5.** As fases S1–S4 rodam com o que já está no `pubspec.yaml`. Só na S5 (embed WebView) uma dependência nova entra.
- **Consistência visual com o app.** Usar os mesmos padrões: `CustomScrollView` + `SliverAppBar`, `AppColors`, `AppTheme.cardDecoration`, `ObjectActionWrapper`, `showModalBottomSheet` com `borderRadius top 24`.

### Plataformas suportadas e estratégia de embed

| Plataforma | URL de exemplo | Embed strategy |
|---|---|---|
| TikTok | `tiktok.com/@user/video/12345` | iframe `https://www.tiktok.com/embed/v2/{video_id}` |
| Instagram | `instagram.com/p/ABC123/` | iframe `https://www.instagram.com/p/{shortcode}/embed/` |
| Substack | `author.substack.com/p/slug` | WebView do URL original com CSS injetado |
| Pinterest | `pinterest.com/pin/12345/` | iframe `https://assets.pinterest.com/ext/embed.html?id={pin_id}` |
| YouTube | `youtube.com/watch?v=ABC` | iframe `https://www.youtube.com/embed/{video_id}` |
| Twitter/X | `x.com/user/status/12345` | iframe via `https://platform.twitter.com/embed/Tweet.html?id={id}` |

---

## 2. S1 — Modelo, vault e provider

### Pré-requisitos antes de começar S1

- V1 estável: vault lendo e escrevendo `.md` corretamente para pelo menos tasks e notes
- `obsidian_service.dart` funcionando com `_ensureVaultFolders()`
- `allObjectsProvider` carregando todos os tipos existentes sem erro
- `groupedObjectsProvider` e `objectsByTypeProvider` funcionando
- `ContentObject` base class estável (não vai mudar mais)

### S1.1 — Arquivo `lib/models/social_post.dart`

Criar o arquivo do zero. O modelo segue exatamente o mesmo padrão dos outros modelos do app.

```dart
// lib/models/social_post.dart

import 'package:uuid/uuid.dart';
import 'content_object.dart';
import 'shared_types.dart';
import 'reminder_config.dart';

enum SocialPlatform {
  tiktok,
  instagram,
  substack,
  pinterest,
  youtube,
  twitter,
  other,
}

enum SocialMediaType {
  video,      // TikTok, Instagram Reel, YouTube
  image,      // Instagram foto, Pinterest pin imagem
  carousel,   // Instagram carrossel (múltiplas fotos)
  article,    // Substack post, artigo longo
  newsletter, // Substack email
  other,
}

class SocialPost extends ContentObject {
  String url;                    // URL original, sempre preenchida
  SocialPlatform platform;
  SocialMediaType mediaType;
  String? caption;               // Legenda/texto do post, pode ter múltiplas linhas
  String? authorHandle;          // @handle sem o @, ex: "johndoe"
  String? authorName;            // Nome de exibição, ex: "John Doe"
  String? thumbnailUrl;          // URL da imagem de capa/thumbnail para cards
  String? embedUrl;              // URL calculada para o iframe de embed (ver tabela acima)
  DateTime? postedAt;            // Data/hora original do post na plataforma
  String? personalNote;          // Anotação pessoal do usuário sobre o post
  bool watched;                  // true = usuário marcou como visto/lido
  List<String> socialRefs;       // WikiLinks de outros posts citados por este post
                                  // ex: ["[[social/tiktok-outro-post]]"]

  // Campos herdados de ContentObject que são usados:
  // - id, title (= caption truncada ou URL se sem caption)
  // - organizers: List<OrganizerReference> → as "coleções"
  // - tags: List<String>
  // - moc: List<String>
  // - categories: List<String>
  // - obsidianPath: "social/platform-slug.md"
  // - archived, pinned
  // - createdAt (= quando foi salvo no app), updatedAt

  SocialPost({
    super.id,
    required super.title,
    required this.url,
    required this.platform,
    this.mediaType = SocialMediaType.other,
    this.caption,
    this.authorHandle,
    this.authorName,
    this.thumbnailUrl,
    this.embedUrl,
    this.postedAt,
    this.personalNote,
    this.watched = false,
    List<String>? socialRefs,
    super.organizers,
    super.tags,
    super.moc,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
    super.pinned,
    super.order,
    super.reminders,
  }) : socialRefs = socialRefs ?? [],
       super();

  @override
  String get type => 'social_post';

  @override
  String get displayType => platform.name.toUpperCase();

  // Gera o slug para o nome do arquivo .md
  // Formato: "tiktok-nome-do-autor-primeiras-palavras-do-titulo"
  // Máximo 60 chars, apenas a-z 0-9 e hifens
  String get socialSlug {
    final base = '${platform.name}-${title}'
        .toLowerCase()
        .trim()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-');
    return base.length > 60 ? base.substring(0, 60) : base;
  }

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['url'] = url;
    frontmatter['platform'] = platform.name;
    frontmatter['media_type'] = mediaType.name;
    if (caption != null) frontmatter['caption'] = caption;
    if (authorHandle != null) frontmatter['author_handle'] = authorHandle;
    if (authorName != null) frontmatter['author_name'] = authorName;
    if (thumbnailUrl != null) frontmatter['thumbnail'] = thumbnailUrl;
    if (embedUrl != null) frontmatter['embed_url'] = embedUrl;
    if (postedAt != null) {
      frontmatter['posted_at'] = postedAt!.toIso8601String();
    }
    frontmatter['watched'] = watched;
    if (socialRefs.isNotEmpty) frontmatter['social_refs'] = socialRefs;

    // O body do .md é a caption completa + nota pessoal separadas por ---
    // Isso faz a caption pesquisável no Obsidian via Dataview/full-text search
    final buffer = StringBuffer();
    if (caption != null && caption!.isNotEmpty) {
      buffer.writeln(caption);
    }
    if (personalNote != null && personalNote!.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln('\n---\n');
      buffer.writeln('## Nota pessoal\n');
      buffer.writeln(personalNote);
    }

    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory SocialPost.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final platformStr = frontmatter['platform'] as String? ?? 'other';
    final platform = SocialPlatform.values.firstWhere(
      (e) => e.name == platformStr,
      orElse: () => SocialPlatform.other,
    );

    final mediaTypeStr = frontmatter['media_type'] as String? ?? 'other';
    final mediaType = SocialMediaType.values.firstWhere(
      (e) => e.name == mediaTypeStr,
      orElse: () => SocialMediaType.other,
    );

    final post = SocialPost(
      title: frontmatter['title'] is List
          ? (frontmatter['title'] as List).join(', ')
          : frontmatter['title']?.toString() ?? '',
      url: frontmatter['url']?.toString() ?? '',
      platform: platform,
      mediaType: mediaType,
    );

    post.loadBaseMap(frontmatter);
    post.caption = frontmatter['caption']?.toString();
    post.authorHandle = frontmatter['author_handle']?.toString();
    post.authorName = frontmatter['author_name']?.toString();
    post.thumbnailUrl = frontmatter['thumbnail']?.toString();
    post.embedUrl = frontmatter['embed_url']?.toString();
    post.watched = frontmatter['watched'] as bool? ?? false;

    if (frontmatter['posted_at'] != null) {
      post.postedAt = DateTime.tryParse(frontmatter['posted_at'].toString());
    }

    if (frontmatter['social_refs'] != null &&
        frontmatter['social_refs'] is List) {
      post.socialRefs =
          List<String>.from(frontmatter['social_refs'] as List);
    }

    // Separar body em caption e nota pessoal pelo separador ---
    // Se o post foi criado com caption no frontmatter, o body pode ter a nota pessoal
    if (body.contains('\n---\n## Nota pessoal\n')) {
      final parts = body.split('\n---\n## Nota pessoal\n');
      // caption no body é redundante com frontmatter, mas preservar nota pessoal
      post.personalNote = parts.length > 1 ? parts[1].trim() : null;
    } else if (body.trim().isNotEmpty &&
        !body.trim().startsWith(post.caption ?? '')) {
      post.personalNote = body.trim();
    }

    return post;
  }

  SocialPost copyWith({
    String? title,
    String? url,
    SocialPlatform? platform,
    SocialMediaType? mediaType,
    String? caption,
    String? authorHandle,
    String? authorName,
    String? thumbnailUrl,
    String? embedUrl,
    DateTime? postedAt,
    String? personalNote,
    bool? watched,
    List<String>? socialRefs,
    List<OrganizerReference>? organizers,
    List<String>? tags,
    List<String>? moc,
    List<String>? categories,
    bool? archived,
    bool? pinned,
    int? order,
    String? obsidianPath,
  }) {
    return SocialPost(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      authorHandle: authorHandle ?? this.authorHandle,
      authorName: authorName ?? this.authorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      embedUrl: embedUrl ?? this.embedUrl,
      postedAt: postedAt ?? this.postedAt,
      personalNote: personalNote ?? this.personalNote,
      watched: watched ?? this.watched,
      socialRefs: socialRefs ?? List.from(this.socialRefs),
      organizers: organizers ?? List.from(this.organizers),
      tags: tags ?? List.from(this.tags),
      moc: moc ?? List.from(this.moc),
      categories: categories ?? List.from(this.categories),
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    )..reminders = List.from(reminders);
  }
}
```

### S1.2 — Adicionar pasta `social/` no vault

Em `lib/services/obsidian_service.dart`, dentro do método `_ensureVaultFolders()`, adicionar `'social'` na lista `const folders`:

```dart
// ANTES:
const folders = [
  'daily', 'habits', 'trackers', 'tasks', 'notes',
  'projects', 'people', 'resources', 'sessions',
  '_attachments', '_deleted',
];

// DEPOIS:
const folders = [
  'daily', 'habits', 'trackers', 'tasks', 'notes',
  'projects', 'people', 'resources', 'sessions',
  'social',          // ← adicionar esta linha
  '_attachments', '_deleted',
];
```

Não precisa de mais nenhuma mudança no `obsidian_service.dart`. O método `saveFile`, `readFile`, `deleteFile` e `listFiles` são genéricos e funcionam com qualquer pasta.

### S1.3 — Registrar `SocialPost` no `AllObjectsNotifier`

Em `lib/providers/vault_provider.dart`, dentro da classe `AllObjectsNotifier` (que está em torno da linha 1066), no método que carrega todos os arquivos do vault (procurar o método que itera sobre os arquivos e chama `MarkdownParser.parseFrontmatter`):

1. Adicionar o import no topo do arquivo:
   ```dart
   import '../models/social_post.dart';
   ```

2. No método de loading do `AllObjectsNotifier`, adicionar o case para `social_post`. O padrão já existente para outros tipos é: verificar o `type` no frontmatter e instanciar o modelo correto. Adicionar após o case de `resource`:

   ```dart
   case 'social_post':
     objects.add(SocialPost.fromMarkdown(frontmatter, body)
       ..obsidianPath = relativePath);
     break;
   ```

3. No `groupedObjectsProvider`, o `SocialPost.type` retorna `'social_post'` — o map já vai categorizá-lo corretamente sem precisar de mudança (o `else` branch usa `obj.type`).

### S1.4 — Criar `socialPostsProvider` em `vault_provider.dart`

Seguindo o padrão de `resourcesProvider` (linha ~596), adicionar:

```dart
class SocialPostsNotifier extends Notifier<List<SocialPost>> {
  @override
  List<SocialPost> build() {
    return ref
        .watch(objectsByTypeProvider('social_post'))
        .cast<SocialPost>();
  }

  Future<void> addPost(SocialPost post) async {
    state = [...state, post];
    await ref.read(vaultProvider.notifier).createObject(post);
  }

  Future<void> updatePost(SocialPost post) async {
    state = [
      for (final p in state)
        if (p.id == post.id) post else p,
    ];
    await ref.read(vaultProvider.notifier).updateObject(post);
  }

  Future<void> deletePost(SocialPost post) async {
    state = state.where((p) => p.id != post.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(post);
  }

  Future<void> toggleWatched(SocialPost post) async {
    final updated = post.copyWith(watched: !post.watched);
    await updatePost(updated);
  }
}

final socialPostsProvider =
    NotifierProvider<SocialPostsNotifier, List<SocialPost>>(() {
  return SocialPostsNotifier();
});
```

### S1.5 — Registrar no `vaultProvider.createObject` e `updateObject`

Em `lib/providers/vault_provider.dart`, nos métodos `createObject` e `updateObject` do `VaultNotifier` (que recebem um `ContentObject`), adicionar `SocialPost` na lógica que determina o caminho do arquivo. Procurar o switch/if que mapeia tipo → pasta:

```dart
// Onde já existe algo como:
// if (object is Resource) folder = 'resources';
// Adicionar:
if (object is SocialPost) {
  folder = 'social';
  // O slug do arquivo é o socialSlug do post, não o slug genérico
  fileName = '${(object as SocialPost).socialSlug}.md';
}
```

Se o método já usa `object.obsidianPath` diretamente quando preenchido, garantir que ao criar um novo `SocialPost` o `obsidianPath` seja atribuído antes de salvar:
```dart
post.obsidianPath = 'social/${post.socialSlug}.md';
```
Isso deve acontecer no `CreateSocialPostForm` antes de chamar `addPost`.

### S1.6 — Adicionar `NavSection.social` em `navigation_item.dart`

Em `lib/models/navigation_item.dart`:

```dart
// No enum NavSection, adicionar:
enum NavSection {
  home, timeline, planner, organize, trackers, pomodoro,
  habits, people, resources, goals, notes, archive, map,
  reminders, deletedFiles, more,
  social,   // ← adicionar aqui
  shortcut,
}

// No método _getSectionIcon, adicionar o case:
case NavSection.social:
  return active
      ? Icons.play_circle_rounded
      : Icons.play_circle_outline_rounded;
```

### S1.7 — Adicionar rota `/social` em `main.dart`

```dart
// Imports a adicionar:
import 'ui/screens/social_screen.dart';

// Na lista de rotas do GoRouter:
GoRoute(
  path: '/social',
  builder: (context, state) => const SocialScreen(),
),
```

### S1.8 — Adicionar `social_post` nos pickers existentes

Em `lib/ui/widgets/universal_search_picker.dart`:

1. Adicionar `import '../../models/social_post.dart';` no topo.
2. No método `getIconForType` (ou equivalente), adicionar:
   ```dart
   case 'social_post':
     return Icons.play_circle_outline_rounded;
   ```
3. Na lista de filtros de tipo, adicionar `'social_post'` com label `'Post'`.
4. No método que constrói o item de resultado, para `SocialPost` mostrar: ícone de plataforma (ver tabela abaixo) + handle `@author` como subtítulo + thumbnail como leading se `thumbnailUrl != null`.

Em `lib/ui/widgets/organizer_picker_modal.dart`, no `getIconForType`:
```dart
case 'social_post':
  return Icons.play_circle_outline_rounded;
```

### S1.9 — Ícones por plataforma

Criar função estática utilitária (pode ficar no próprio `social_post.dart` ou em um arquivo `lib/ui/widgets/social_platform_badge.dart`):

```dart
// Retorna a cor da plataforma para usar em badges
Color platformColor(SocialPlatform p) {
  switch (p) {
    case SocialPlatform.tiktok:    return const Color(0xFF010101); // preto TikTok
    case SocialPlatform.instagram: return const Color(0xFFE1306C); // rosa Instagram
    case SocialPlatform.substack:  return const Color(0xFFFF6719); // laranja Substack
    case SocialPlatform.pinterest: return const Color(0xFFE60023); // vermelho Pinterest
    case SocialPlatform.youtube:   return const Color(0xFFFF0000); // vermelho YouTube
    case SocialPlatform.twitter:   return const Color(0xFF1DA1F2); // azul Twitter
    case SocialPlatform.other:     return AppColors.textMuted;
  }
}

// Retorna o label curto para o badge
String platformLabel(SocialPlatform p) {
  switch (p) {
    case SocialPlatform.tiktok:    return 'TikTok';
    case SocialPlatform.instagram: return 'Instagram';
    case SocialPlatform.substack:  return 'Substack';
    case SocialPlatform.pinterest: return 'Pinterest';
    case SocialPlatform.youtube:   return 'YouTube';
    case SocialPlatform.twitter:   return 'X / Twitter';
    case SocialPlatform.other:     return 'Link';
  }
}

// Retorna o ícone Material mais próximo para a plataforma
IconData platformIcon(SocialPlatform p) {
  switch (p) {
    case SocialPlatform.tiktok:
    case SocialPlatform.instagram:
    case SocialPlatform.youtube:   return Icons.play_circle_outline_rounded;
    case SocialPlatform.substack:  return Icons.article_outlined;
    case SocialPlatform.pinterest: return Icons.push_pin_outlined;
    case SocialPlatform.twitter:   return Icons.chat_bubble_outline_rounded;
    case SocialPlatform.other:     return Icons.link_rounded;
  }
}
```

---

## 3. S2 — Serviço oEmbed + formulário de captura

### Pré-requisitos antes de começar S2

- S1 completo e compilando sem erros
- `social/` pasta existindo no vault após primeiro sync
- `socialPostsProvider` retornando lista (vazia é ok)

### S2.1 — Arquivo `lib/services/oembed_service.dart`

Este serviço recebe uma URL, detecta a plataforma, busca metadados e retorna um `SocialPost` pré-preenchido. O pacote `http` já está no `pubspec.yaml`.

```dart
// lib/services/oembed_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/social_post.dart';

class OEmbedService {

  // Detecta a plataforma a partir da URL
  static SocialPlatform detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('tiktok.com'))    return SocialPlatform.tiktok;
    if (lower.contains('instagram.com')) return SocialPlatform.instagram;
    if (lower.contains('substack.com'))  return SocialPlatform.substack;
    if (lower.contains('pinterest.com') ||
        lower.contains('pin.it'))        return SocialPlatform.pinterest;
    if (lower.contains('youtube.com') ||
        lower.contains('youtu.be'))      return SocialPlatform.youtube;
    if (lower.contains('twitter.com') ||
        lower.contains('x.com'))        return SocialPlatform.twitter;
    return SocialPlatform.other;
  }

  // Detecta o media type com base na plataforma e URL
  static SocialMediaType detectMediaType(SocialPlatform platform, String url) {
    switch (platform) {
      case SocialPlatform.tiktok:
      case SocialPlatform.youtube:
        return SocialMediaType.video;
      case SocialPlatform.instagram:
        if (url.contains('/reel/')) return SocialMediaType.video;
        if (url.contains('/p/'))    return SocialMediaType.image;
        return SocialMediaType.image;
      case SocialPlatform.substack:
        return SocialMediaType.article;
      case SocialPlatform.pinterest:
        return SocialMediaType.image;
      case SocialPlatform.twitter:
        return SocialMediaType.other;
      case SocialPlatform.other:
        return SocialMediaType.other;
    }
  }

  // Calcula a embed URL para o WebView
  static String? buildEmbedUrl(SocialPlatform platform, String originalUrl) {
    switch (platform) {
      case SocialPlatform.tiktok: {
        final match = RegExp(r'/video/(\d+)').firstMatch(originalUrl);
        final id = match?.group(1);
        if (id == null) return null;
        return 'https://www.tiktok.com/embed/v2/$id';
      }
      case SocialPlatform.instagram: {
        final match = RegExp(r'/(p|reel)/([A-Za-z0-9_-]+)').firstMatch(originalUrl);
        final shortcode = match?.group(2);
        if (shortcode == null) return null;
        return 'https://www.instagram.com/p/$shortcode/embed/';
      }
      case SocialPlatform.substack:
        // Substack: abrir o artigo diretamente no WebView
        return originalUrl;
      case SocialPlatform.pinterest: {
        final match = RegExp(r'/pin/(\d+)').firstMatch(originalUrl);
        final id = match?.group(1);
        if (id == null) return null;
        return 'https://assets.pinterest.com/ext/embed.html?id=$id';
      }
      case SocialPlatform.youtube: {
        String? videoId;
        if (originalUrl.contains('youtu.be/')) {
          videoId = originalUrl.split('youtu.be/').last.split('?').first;
        } else {
          final match = RegExp(r'[?&]v=([A-Za-z0-9_-]+)').firstMatch(originalUrl);
          videoId = match?.group(1);
        }
        if (videoId == null) return null;
        return 'https://www.youtube.com/embed/$videoId';
      }
      case SocialPlatform.twitter: {
        final match = RegExp(r'/status/(\d+)').firstMatch(originalUrl);
        final id = match?.group(1);
        if (id == null) return null;
        return 'https://platform.twitter.com/embed/Tweet.html?id=$id';
      }
      case SocialPlatform.other:
        return null;
    }
  }

  // Método principal: busca metadados para uma URL
  // Retorna SocialPost pré-preenchido, sem id/obsidianPath (serão atribuídos no form)
  Future<SocialPost> fetchMetadata(String url) async {
    final platform = detectPlatform(url);
    final mediaType = detectMediaType(platform, url);
    final embedUrl = buildEmbedUrl(platform, url);

    String title = url; // fallback
    String? caption;
    String? authorHandle;
    String? authorName;
    String? thumbnailUrl;

    try {
      switch (platform) {
        case SocialPlatform.tiktok:
          final result = await _fetchOEmbed(
            'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}',
          );
          if (result != null) {
            title = result['title'] as String? ?? url;
            authorName = result['author_name'] as String?;
            authorHandle = (result['author_url'] as String?)
                ?.split('@')
                .last
                .split('?')
                .first;
            thumbnailUrl = result['thumbnail_url'] as String?;
          }
          break;

        case SocialPlatform.pinterest: {
          final result = await _fetchOEmbed(
            'https://www.pinterest.com/oembed/?url=${Uri.encodeComponent(url)}',
          );
          if (result != null) {
            title = result['title'] as String? ?? url;
            authorName = result['author_name'] as String?;
            thumbnailUrl = result['thumbnail_url'] as String?;
            // Pinterest oEmbed retorna a descrição do pin em 'description'
            caption = result['description'] as String?;
          }
          break;
        }

        case SocialPlatform.youtube: {
          final result = await _fetchOEmbed(
            'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
          );
          if (result != null) {
            title = result['title'] as String? ?? url;
            authorName = result['author_name'] as String?;
            thumbnailUrl = result['thumbnail_url'] as String?;
          }
          break;
        }

        case SocialPlatform.instagram:
        case SocialPlatform.substack:
        case SocialPlatform.twitter:
        case SocialPlatform.other:
          // Para estas, fazer scrape de OpenGraph tags
          final result = await _fetchOpenGraph(url);
          if (result != null) {
            title = result['title'] ?? url;
            caption = result['description'];
            thumbnailUrl = result['image'];
            authorName = result['site_name'];
          }
          break;
      }
    } catch (_) {
      // Se falhar, manter os valores padrão (só a URL como title)
    }

    return SocialPost(
      title: title.length > 80 ? title.substring(0, 80) : title,
      url: url,
      platform: platform,
      mediaType: mediaType,
      caption: caption,
      authorHandle: authorHandle,
      authorName: authorName,
      thumbnailUrl: thumbnailUrl,
      embedUrl: embedUrl,
    );
  }

  Future<Map<String, dynamic>?> _fetchOEmbed(String oembedUrl) async {
    try {
      final response = await http
          .get(Uri.parse(oembedUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>?> _fetchOpenGraph(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0 (compatible; Citrine/1.0)'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final html = response.body;
      final result = <String, String>{};

      // Extrair og:title
      final titleMatch = RegExp(
        r'<meta\s+property="og:title"\s+content="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (titleMatch != null) result['title'] = titleMatch.group(1) ?? '';

      // Extrair og:description
      final descMatch = RegExp(
        r'<meta\s+property="og:description"\s+content="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (descMatch != null) result['description'] = descMatch.group(1) ?? '';

      // Extrair og:image
      final imageMatch = RegExp(
        r'<meta\s+property="og:image"\s+content="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (imageMatch != null) result['image'] = imageMatch.group(1) ?? '';

      // Extrair og:site_name
      final siteMatch = RegExp(
        r'<meta\s+property="og:site_name"\s+content="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (siteMatch != null) result['site_name'] = siteMatch.group(1) ?? '';

      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
```

### S2.2 — Arquivo `lib/ui/forms/create_social_post_form.dart`

**Layout geral do formulário:**

O formulário é uma tela completa (não bottom sheet), aberta via `Navigator.push(MaterialPageRoute(...))`, exatamente como os outros formulários do app (`CreateResourceForm`, `CreateGoalForm`, etc.).

**Estrutura visual (de cima para baixo):**

```
┌─────────────────────────────────────┐
│  ← [X]    Novo post social          │  ← AppBar fixo
│                         [Salvar →]  │
├─────────────────────────────────────┤
│  Seção URL                          │  ─┐
│  ┌─────────────────────┐            │   │
│  │ Cole o link aqui... │ [Buscar]   │   │
│  └─────────────────────┘            │   │
│  [estado: idle / loading / erro]    │   │
├─────────────────────────────────────┤   │
│  Preview do post (aparece após      │   │
│  fetch bem-sucedido)                │   │  Rola junto
│  ┌──────┬──────────────────────┐   │   │  (SingleChildScrollView)
│  │thumb │ @handle              │   │   │
│  │      │ Caption (editável)   │   │   │
│  └──────┴──────────────────────┘   │   │
├─────────────────────────────────────┤   │
│  Nota pessoal (opcional)            │   │
│  [campo de texto multilinhas]       │   │
├─────────────────────────────────────┤   │
│  Coleções (Organizers)              │   │
│  [OrganizerSelectorField]           │   │
├─────────────────────────────────────┤   │
│  Tags  [campo de texto]             │   │
└─────────────────────────────────────┘  ─┘
```

**Comportamento do campo URL:**

1. Campo de texto com ícone de link à esquerda e botão `Buscar` à direita.
2. Quando o usuário cola uma URL e toca `Buscar` (ou pressiona enter):
   - O botão `Buscar` vira um `CircularProgressIndicator` de tamanho 18.
   - Uma chamada a `OEmbedService().fetchMetadata(url)` é feita.
   - Se sucesso: o preview aparece abaixo com animação `AnimatedSwitcher` (fadeIn, duração 200ms). O campo URL fica desabilitado (readonly, com ícone de cadeado pequeno à direita). Um link "Mudar URL" pequeno aparece abaixo do campo para re-habilitar.
   - Se erro ou timeout: o botão volta para `Buscar`; um texto de erro em `AppColors.error` aparece abaixo do campo: `"Não conseguimos buscar esse link. Preencha manualmente."`. Os campos de título, caption, etc. ficam visíveis e editáveis para preenchimento manual.
3. Ao colar texto no campo (evento `onChanged`): se o texto colado for detectado como URL válida de plataforma suportada (via `OEmbedService.detectPlatform()`), disparar o fetch automaticamente sem precisar tocar em `Buscar`.

**Seção de preview (aparece após fetch bem-sucedido):**

```
┌──────────────────────────────────────┐
│  [badge de plataforma: "TIKTOK"]     │
│  ┌──────┐                            │
│  │      │  @authorHandle             │
│  │thumb │  authorName                │
│  │ 72px │                            │
│  └──────┘                            │
│  Caption: [campo de texto          ] │
│           [editável, multilinhas   ] │
│           [max 3 linhas sem scroll ] │
│           [expandível se usuário   ] │
│           [tocar para expandir     ] │
└──────────────────────────────────────┘
```

- O badge de plataforma usa `platformColor(platform)` como cor de fundo e texto branco, font 10px, uppercase, padding 2×8.
- A thumbnail é 72×72, `BoxFit.cover`, `borderRadius 8`. Se `thumbnailUrl` for null: mostrar ícone `platformIcon(platform)` com cor `platformColor(platform)` no fundo de cor `platformColor(platform).withAlpha(30)`.
- `authorHandle` é mostrado em `AppColors.info` (azul) com `@` na frente.
- O campo de caption é pré-preenchido mas editável. Sem borda estilizada, só `hintText: "Legenda do post"`. `maxLines: 3` por padrão, mas ao tocar no campo ele expande para permitir edição livre.

**Campo de nota pessoal:**

- Label: `"Nota pessoal"` em `AppColors.textSecondary`, tamanho 12.
- Campo de texto multilinhas, `minLines: 2, maxLines: 6`.
- Placeholder: `"O que esse post significa pra você?"`.
- Sem borda extra — usar o mesmo estilo dos outros campos do app.

**Campo de Organizers (Coleções):**

- Label: `"Coleções"` em `AppColors.textSecondary`, tamanho 12.
- Usar `OrganizerSelectorField` já existente em `lib/ui/widgets/organizer_selector_field.dart` passando `allowedTypes: null` (todos os tipos de organizer).

**Campo de Tags:**

- Campo de texto simples com chips. Ao pressionar vírgula ou enter, a palavra vira chip. Chip tem `×` para remover. Mesmo padrão usado no `CreateTaskForm`.

**Botão Salvar:**

- Fica no `AppBar` como `TextButton` à direita com o texto `"Salvar"` em `AppColors.primary`.
- Habilitado apenas quando a URL está preenchida (não precisa de fetch bem-sucedido — usuário pode ter preenchido manualmente).
- Ao tocar:
  1. Gerar `obsidianPath`: `'social/${post.socialSlug}.md'` e atribuir ao post.
  2. Chamar `ref.read(socialPostsProvider.notifier).addPost(post)`.
  3. `Navigator.pop(context)`.
  4. Mostrar `SnackBar` com texto `"Post salvo"` (sem ação).

**Adicionar ao `create_menu_sheet.dart`:**

Na lista de opções de criação, adicionar a opção "Post social":

```dart
_CreateOption(
  icon: Icons.play_circle_outline_rounded,
  label: 'Post social',
  color: AppColors.info,
  onTap: () {
    Navigator.pop(context); // fechar o menu
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSocialPostForm()),
    );
  },
),
```

---

## 4. S3 — Social Screen e feed

### Pré-requisitos antes de começar S3

- S1 e S2 completos
- `socialPostsProvider` retornando lista (pode ser vazia)
- Rota `/social` configurada

### S3.1 — Arquivo `lib/ui/screens/social_screen.dart`

**Layout geral da tela:**

A tela usa `Scaffold` com `CustomScrollView`, seguindo o padrão de todas as outras telas do app.

**Partes fixas (não rolam):**

- `SliverAppBar` com `title: const Text('Social')`, `centerTitle: true`, `floating: true`, `pinned: true`.
- AppBar actions (da esquerda para direita na action bar):
  - `IconButton` com `Icons.search_rounded` → abre `SearchScreen` filtrada por `'social_post'`.
  - `IconButton` com `Icons.tune_rounded` → abre bottom sheet de filtros avançados (ver S3.3).
  - `IconButton` com `Icons.grid_view_rounded` (quando em modo lista) ou `Icons.view_list_rounded` (quando em modo grid) → alterna entre modo grid e modo lista. Estado local `bool _isGridMode = true` (grid é o padrão).
  - `IconButton` com `Icons.add_rounded` → abre `CreateSocialPostForm`.
- Row de chips de plataforma (ver S3.2) — fica logo abaixo do AppBar, dentro de `SliverToBoxAdapter`, ROLA JUNTO com o conteúdo (não fica fixo).

**Partes que rolam:**

- Row de chips de plataforma (dentro do scroll).
- A lista/grid de posts.

**Estado da tela:**

```dart
class _SocialScreenState extends ConsumerState<SocialScreen> {
  SocialPlatform? _selectedPlatform; // null = todos
  String _sortMode = 'saved_desc';   // 'saved_desc', 'saved_asc', 'posted_desc', 'unwatched'
  bool _isGridMode = true;
  bool _showUnwatchedOnly = false;
  bool _isMultiSelectMode = false;
  Set<String> _selectedIds = {};
}
```

### S3.2 — Row de chips de plataforma

Dentro de `SliverToBoxAdapter`, um `SingleChildScrollView` horizontal com `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)`:

- Chip `"Todos"`: sempre presente. Selecionado quando `_selectedPlatform == null`. Cor quando selecionado: `AppColors.primary` com opacidade 0.15 + borda `AppColors.primary`.
- Chips de plataforma: gerados dinamicamente a partir das plataformas presentes na lista atual de posts. Só mostrar chips de plataformas que têm ao menos 1 post. Não mostrar chips de plataformas sem posts. Chip selecionado: fundo `platformColor(platform).withAlpha(30)` + borda `platformColor(platform)`. Chip não selecionado: fundo `AppColors.surfaceVariant` + sem borda especial.
- Chip `"Não visto"`: sempre presente ao fim da row. Selecionado quando `_showUnwatchedOnly == true`. Cor quando selecionado: fundo `AppColors.info.withAlpha(30)` + borda `AppColors.info`.

Comportamento dos chips: tap seleciona/deseleciona. Múltipla seleção não é permitida entre plataformas (tap numa plataforma deseleciona a anterior). O chip "Não visto" pode estar ativo simultaneamente com qualquer plataforma.

### S3.3 — Bottom sheet de filtros avançados

Aberto pelo botão `tune_rounded` no AppBar. `showModalBottomSheet` com `isScrollControlled: false`. Conteúdo:

```
┌─────────────────────────────┐
│         [handle bar]        │
│  Ordenar por                │
│  ○ Salvo (mais recente)     │
│  ○ Salvo (mais antigo)      │
│  ○ Data do post (mais rec.) │
│  ○ Não vistos primeiro      │
│                             │
│  [Aplicar]  [Limpar filtros]│
└─────────────────────────────┘
```

Radio buttons com `ListTile`. Ao tocar em `Aplicar`: fechar o sheet e atualizar `_sortMode`. Ao tocar em `Limpar filtros`: resetar todos os filtros para o padrão.

### S3.4 — Modo grid

Quando `_isGridMode == true`, usar `SliverGrid` com `SliverGridDelegateWithFixedCrossAxisCount`:
- `crossAxisCount: 2`
- `mainAxisSpacing: 10`
- `crossAxisSpacing: 10`
- Padding: `EdgeInsets.all(16)`

Cada célula do grid: widget `SocialPostGridCard` (ver S3.6).

### S3.5 — Modo lista

Quando `_isGridMode == false`, usar `SliverList` com padding `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`. Cada item: widget `SocialPostListTile` (ver S3.7).

### S3.6 — Widget `SocialPostGridCard`

Arquivo: `lib/ui/widgets/social_post_grid_card.dart`

```
┌─────────────────────────┐
│                         │
│    thumbnail            │
│    (aspectRatio 3/4)    │
│    cover fit            │
│                         │
│ ┌─────────────────────┐ │
│ │ [badge plataforma]  │ │  ← overlay no canto inferior esquerdo
│ │ @handle  [● não     │ │  ← dot azul se não visto
│ │           visto]    │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

Especificação:
- Container com `borderRadius: 12`, `ClipRRect`.
- Background: se `thumbnailUrl != null` → `NetworkImage` com `BoxFit.cover`. Se null → fundo `platformColor(platform).withAlpha(20)` + ícone `platformIcon(platform)` de 40px no centro.
- **Overlay inferior**: `Positioned(bottom: 0, left: 0, right: 0)` com `DecoratedBox` usando `gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])`. Altura: 64px.
- Sobre o overlay: `Padding(EdgeInsets.all(8))` com:
  - Badge de plataforma: fundo `platformColor(platform)`, texto branco, 9px, uppercase.
  - Handle: `@${authorHandle ?? authorName ?? ''}` em branco, 11px, `overflow: ellipsis`.
  - Dot azul `•` se `!post.watched`: `Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.info, shape: BoxShape.circle))` no canto superior direito do card (via `Stack` + `Positioned(top: 8, right: 8)`).
- **Tap**: navegar para `SocialPostDetailView(post: post)`.
- **Long press**: `ObjectActionWrapper` já cuida disso — wrapping do card com `ObjectActionWrapper(object: post, child: ...)`.
- Se `_isMultiSelectMode == true`: mostrar checkbox `Positioned(top: 8, left: 8)` no lugar do dot. Tap seleciona/deseleciona.

### S3.7 — Widget `SocialPostListTile`

Arquivo: pode ser método `_buildListTile` dentro do screen ou widget separado.

```
┌──────────────────────────────────────────────┐
│ ┌──────┐  @handle · badge plataforma  [•]    │
│ │      │  Título / Caption (1 linha)         │
│ │thumb │  Organizers como chips pequenos     │
│ │ 56px │  "há 3 dias" em muted              │
│ └──────┘                                      │
└──────────────────────────────────────────────┘
```

- Thumbnail: 56×56, `borderRadius: 8`, `BoxFit.cover`. Fallback igual ao grid.
- Handle: `@handle` em `AppColors.info`, 12px.
- Badge de plataforma: inline, mesmo estilo do grid mas 9px.
- Dot azul `•` se não visto: `Container(width: 8, height: 8)` azul após o handle.
- Título/Caption: primeira linha da caption, `overflow: ellipsis`, 14px.
- Chips de organizers: `Row` com chips de 10px, máximo 3 chips + `"+N"` se tiver mais.
- Timestamp: `"há X dias"` / `"há X horas"` calculado de `createdAt`, em `AppColors.textMuted`, 11px.
- Tap → `SocialPostDetailView`.
- Long press → `ObjectActionWrapper` handle.

### S3.8 — Multi-select mode

Ativado por long press em qualquer card (quando não está em `ObjectActionWrapper` action sheet). Quando ativado:

- `_isMultiSelectMode = true`
- AppBar actions mudam: aparecem `"Cancelar"` (TextButton à esquerda) e `"X selecionados"` como título. Actions: `Icons.collections_bookmark_outlined` (adicionar a coleção), `Icons.visibility_rounded` (marcar como visto), `Icons.delete_outline_rounded` (deletar).
- Todos os cards mostram checkbox no canto superior esquerdo.
- Long press em outro card não abre action sheet, apenas adiciona à seleção.
- Tap no `×` do card selecionado ou tap fora: deseleciona só aquele.
- `"Cancelar"`: desativa multi-select mode, limpa `_selectedIds`.

**Ação "Adicionar a coleção":** Abre `OrganizerPickerModal`. Ao confirmar um organizer: para cada `SocialPost` com id em `_selectedIds`, adicionar o organizer e salvar via `updatePost`. Fechar modal. Mostrar SnackBar `"X posts adicionados a [coleção]"`.

**Ação "Marcar como vistos":** Para cada post selecionado: `toggleWatched(post)` se `!post.watched`. Fechar multi-select. SnackBar `"X posts marcados como vistos"`.

**Ação "Deletar":** `showDialog` de confirmação com `"Deletar X posts?"` + botões `Cancelar` e `Deletar` (em `AppColors.error`). Ao confirmar: `deletePost` para cada um.

### S3.9 — Estado vazio

Quando não há posts (lista vazia após filtros): usar `EmptyState` widget existente:
```dart
EmptyState(
  icon: Icons.play_circle_outline_rounded,
  headline: 'Nenhum post salvo ainda',
  subtext: 'Cole um link do TikTok, Instagram, Substack ou Pinterest para começar.',
  ctaLabel: 'Salvar primeiro post',
  onCta: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const CreateSocialPostForm(),
  )),
)
```

Quando há posts mas o filtro de plataforma não retorna nada: `Center(child: Text("Nenhum post de ${platformLabel(platform)}", style: TextStyle(color: AppColors.textMuted)))`.

---

## 5. S4 — Post Detail View

### Pré-requisitos antes de começar S4

- S3 completo (Social Screen funcionando)
- `UniversalDetailView` existente entendido como referência de padrão (mas NÃO reutilizar o UniversalDetailView para posts sociais — a view de posts é específica demais)

### S4.1 — Arquivo `lib/ui/screens/social_post_detail.dart`

**Como abrir:** `Navigator.push(context, MaterialPageRoute(builder: (_) => SocialPostDetail(post: post)))`. Recebe o `SocialPost` diretamente. Não usar `UniversalDetailView` — os posts sociais têm estrutura muito específica.

**Layout geral (CustomScrollView):**

```
┌─────────────────────────────────┐
│  ← (back)   @handle · Platform  │  ← AppBar fixo (pinned)
│                        [⋯] [↗]  │
├─────────────────────────────────┤
│  [SocialEmbedView]              │  ─┐
│  (placeholder até S5 — só      │   │
│   thumbnail + botão "Abrir")    │   │
├─────────────────────────────────┤   │
│  Caption completa               │   │  Rola
│  (SelectableText)               │   │
├─────────────────────────────────┤   │
│  Nota pessoal (editável)        │   │
├─────────────────────────────────┤   │
│  ───── Organizers ─────         │   │
│  [OrganizerSelectorField]       │   │
├─────────────────────────────────┤   │
│  ───── Tags ─────               │   │
│  [chips editáveis]              │   │
├─────────────────────────────────┤   │
│  ───── Citado em ─────          │   │
│  [backlinks automáticos]        │   │
├─────────────────────────────────┤   │
│  ───── Metadata ─────           │   │
│  Salvo em: DD/MM/AAAA           │   │
│  Post original: DD/MM/AAAA      │   │
│  URL: [link tappável]           │   │
└─────────────────────────────────┘  ─┘
```

**AppBar:**

- `leading`: `IconButton(Icons.arrow_back_rounded)` → `Navigator.pop`.
- `title`: `@${post.authorHandle ?? post.authorName ?? 'Post'}` + ` · ` + badge de plataforma (inline, 10px). Se ambos null, `"Post salvo"`.
- `centerTitle: false`.
- Actions:
  - `IconButton(Icons.open_in_new_rounded)` → abre URL original com `launchUrl(Uri.parse(post.url), mode: LaunchMode.externalApplication)`.
  - `IconButton(Icons.more_horiz_rounded)` → abre action sheet (ver S4.2).

**Seção embed (antes de S5):**

Placeholder temporário: `Container(height: 200, decoration: BoxDecoration(color: platformColor(post.platform).withAlpha(20), borderRadius: BorderRadius.circular(12)))` com thumbnail centralizada se disponível + botão `ElevatedButton("Abrir no app original")` que chama `launchUrl`. Após S5, substituir por `SocialEmbedView(post: post)`.

**Seção caption:**

- Se `caption != null && caption!.isNotEmpty`:
  - `SelectableText(post.caption!, style: TextStyle(fontSize: 15, height: 1.6))`.
  - `SelectableText` permite ao usuário copiar trechos da caption.
  - Mostrar os primeiros 5 parágrafos. Se houver mais: `TextButton("Ver tudo")` que expande (`_showFullCaption` bool).
- Se null: não mostrar a seção.

**Seção nota pessoal:**

- Label `"Nota pessoal"` em `AppColors.textSecondary`, 12px, acima do campo.
- `TextField` com `maxLines: null` (expande conforme conteúdo), `minLines: 2`.
- Placeholder: `"Adicione uma nota sobre esse post..."`.
- Edição inline: `onChanged` com debounce de 800ms chama `updatePost(post.copyWith(personalNote: newValue))`. Não precisa de botão salvar — auto-save.
- Se a nota foi salva, mostrar um `•` pequeno em `AppColors.success` temporariamente (2 segundos) para indicar que salvou.

**Seção Organizers:**

- Label `"Coleções"`.
- `OrganizerSelectorField` existente, passando `post.organizers` e callback `onChanged` que chama `updatePost`.

**Seção Tags:**

- Label `"Tags"`.
- Chips editáveis, mesmo padrão do form de criação. `onChanged` → `updatePost`.

**Seção "Citado em" (backlinks):**

- Usar `ref.watch(backlinksProvider(post.id))` — o `backlinksProvider` existente busca automaticamente todos os objetos do vault que mencionam `[[social/slug]]` no conteúdo ou no campo `organizers`.
- Se a lista estiver vazia: não mostrar a seção.
- Se tiver itens: label `"Citado em"` em `AppColors.textSecondary` + lista de `ListTile` compactos: ícone do tipo do objeto + título + subtipo. Tap → `Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalDetailView(object: obj)))`.

**Seção Metadata:**

- `"Salvo em: ${DateFormat('dd/MM/yyyy').format(post.createdAt)}"`.
- Se `postedAt != null`: `"Postado em: ${DateFormat('dd/MM/yyyy').format(post.postedAt!)}"`.
- URL como `InkWell` que abre `launchUrl`.

### S4.2 — Action sheet do post (⋯ menu)

`showModalBottomSheet` com options:

```
[ Editar post              ]   → abre CreateSocialPostForm com post preenchido
[ Adicionar a coleção      ]   → OrganizerPickerModal
[ Marcar como visto / não-visto ]   → toggleWatched
[ Abrir no Obsidian        ]   → obsidian://open?vault=...&file=social/slug
[ Copiar URL               ]   → Clipboard.setData
[ Arquivar                 ]   → updatePost(post.copyWith(archived: true))
[ Deletar post             ]   → confirmar → deletePost → Navigator.pop
```

Ícones: `Icons.edit_outlined`, `Icons.folder_outlined`, `Icons.visibility_outlined` / `Icons.visibility_off_outlined`, `Icons.open_in_new_rounded`, `Icons.copy_rounded`, `Icons.inventory_2_outlined`, `Icons.delete_outline_rounded`.

"Deletar post" em `AppColors.error` com ícone também em vermelho.

---

## 6. S5 — Embed in-app

### Pré-requisitos antes de começar S5

- S4 completo
- Aprovação para adicionar dependência nova (`webview_flutter`)
- Testar se TikTok embed funciona sem cookies (geralmente funciona)

### S5.1 — Adicionar dependência no `pubspec.yaml`

```yaml
dependencies:
  # ... dependências existentes ...
  webview_flutter: ^4.10.0
```

Executar `flutter pub get`.

Para iOS, em `ios/Runner/Info.plist` adicionar:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Para Android, em `android/app/src/main/AndroidManifest.xml`, dentro de `<application>`:
```xml
android:usesCleartextTraffic="true"
```

### S5.2 — Arquivo `lib/ui/widgets/social_embed_view.dart`

Este widget renderiza o conteúdo do post em um WebView. Recebe um `SocialPost`.

**Comportamento por tipo de embed:**

**Caso 1 — TikTok, Instagram Reel, YouTube, Pinterest (embed via iframe):**

O widget constrói uma string HTML mínima e carrega no `WebViewController` via `loadHtmlString`:

```dart
String _buildEmbedHtml(SocialPost post) {
  if (post.embedUrl == null) return '';

  final isSubstack = post.platform == SocialPlatform.substack;
  if (isSubstack) return ''; // substack tem caso especial abaixo

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100vh; border: none; }
  </style>
</head>
<body>
  <iframe src="${post.embedUrl}"
    allowfullscreen
    allow="autoplay; encrypted-media; picture-in-picture">
  </iframe>
</body>
</html>
''';
}
```

**Caso 2 — Substack (WebView direto do URL com CSS injetado):**

```dart
// Para Substack, carregar a URL diretamente e injetar CSS ao carregar
controller.loadRequest(Uri.parse(post.url));
// No onPageFinished:
controller.runJavaScript('''
  document.querySelector('header')?.remove();
  document.querySelector('footer')?.remove();
  document.querySelector('.navbar')?.remove();
  document.querySelector('.subscribe-footer')?.remove();
  document.body.style.padding = '16px';
  document.body.style.maxWidth = '100%';
  document.body.style.fontSize = '16px';
  document.body.style.lineHeight = '1.7';
''');
```

**Alturas dos WebViews:**

- TikTok vídeo: `height: 600` (formato vertical).
- Instagram Reel: `height: 560`.
- Instagram foto/carrossel: `height: 480`.
- YouTube: `height: 220` (formato 16:9 em tela de ~390px de largura).
- Pinterest: `height: 400`.
- Substack: `height: MediaQuery.of(context).size.height * 0.7`.
- Twitter: `height: 280`.

**Estados do widget:**

1. **Loading**: `Stack` com `WebView` invisível (`Opacity(opacity: 0)`) + `Shimmer` ou `Container` com cor de fundo de plataforma + `CircularProgressIndicator` centralizado.
2. **Loaded**: `WebView` visível com `AnimatedOpacity` (duração 300ms).
3. **Error** (timeout ou embed falhou): `Container(height: 200)` com thumbnail centralizada se disponível + botão `"Abrir no ${platformLabel(platform)}"` que chama `launchUrl`.

**Widget completo:**

```dart
class SocialEmbedView extends StatefulWidget {
  final SocialPost post;
  const SocialEmbedView({super.key, required this.post});
  @override
  State<SocialEmbedView> createState() => _SocialEmbedViewState();
}

class _SocialEmbedViewState extends State<SocialEmbedView> {
  late final WebViewController _controller;
  bool _isLoaded = false;
  bool _hasError = false;

  double get _height {
    switch (widget.post.platform) {
      case SocialPlatform.tiktok:    return 600;
      case SocialPlatform.instagram:
        return widget.post.mediaType == SocialMediaType.video ? 560 : 480;
      case SocialPlatform.youtube:   return 220;
      case SocialPlatform.pinterest: return 400;
      case SocialPlatform.twitter:   return 280;
      case SocialPlatform.substack:
        return MediaQuery.of(context).size.height * 0.7;
      default:                       return 400;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (widget.post.platform == SocialPlatform.substack) {
            _controller.runJavaScript(/* CSS injection acima */);
          }
          setState(() => _isLoaded = true);
        },
        onWebResourceError: (_) => setState(() => _hasError = true),
      ));

    if (widget.post.platform == SocialPlatform.substack) {
      _controller.loadRequest(Uri.parse(widget.post.url));
    } else if (widget.post.embedUrl != null) {
      _controller.loadHtmlString(_buildEmbedHtml(widget.post));
    } else {
      _hasError = true;
    }
  }
  // build: Stack com loading/error/loaded states
}
```

**Fallback completo (quando `embedUrl == null` ou quando houve erro):**

```
┌─────────────────────────────────────┐
│                                     │
│         [thumbnail ou ícone]        │
│                                     │
│    Não foi possível carregar        │
│    o embed deste post.              │
│                                     │
│  [ Abrir no TikTok →            ]   │
│                                     │
└─────────────────────────────────────┘
```

Altura: 200px. Background: `platformColor(platform).withAlpha(15)`. `borderRadius: 12`.

### S5.3 — Integrar `SocialEmbedView` no `SocialPostDetail`

Substituir o placeholder da seção embed pela chamada real:

```dart
if (post.embedUrl != null || post.platform == SocialPlatform.substack)
  SocialEmbedView(post: post)
else
  _buildEmbedFallback(post),
```

O `SocialEmbedView` NÃO tem padding — o padding é aplicado no pai.

---

## 7. S6 — Organização por coleções

### Pré-requisitos antes de começar S6

- S3 completo (Social Screen)
- S4 completo (Post Detail View)
- `OrganizerSelectorField`, `OrganizerPickerModal` funcionando

Esta fase não cria nenhum arquivo novo. Ela finaliza a integração dos posts com o sistema de Organizers existente em lugares que S3 e S4 ainda não fizeram completamente.

### S6.1 — Sidebar/drawer de coleções na Social Screen

Adicionar na Social Screen um `Drawer` acessível pelo botão `Icons.folder_outlined` no AppBar:

```
┌────────────────────────┐
│  Coleções              │
│  ──────────────────    │
│  Todos os posts   (12) │
│  ──────────────────    │
│  [ícone] Sem coleção (3)│
│  [ícone] Vida       (5)│
│  [ícone] Trabalho   (4)│
│  [ícone] Inspiração (3)│
│  ──────────────────    │
│  [+] Nova coleção      │
└────────────────────────┘
```

Implementação:
- `Scaffold(drawer: _buildCollectionsDrawer())`.
- O drawer lista os organizers que têm ao menos 1 post social associado, com contagem.
- "Sem coleção": posts com `organizers.isEmpty`.
- Tap num organizer: fechar drawer + setar `_selectedOrganizerFilter = organizer.id`. A lista de posts é filtrada por `posts.where((p) => p.organizers.any((o) => o.slug == selectedSlug))`.
- `[+] Nova coleção`: abre `CreateOrganizerForm` (já existe).
- `_selectedOrganizerFilter` é um novo campo de estado na screen (`String? _selectedOrganizerFilter`).
- Quando `_selectedOrganizerFilter != null`, mostrar um chip de "filtro ativo" no topo da lista, com `×` para remover o filtro.

### S6.2 — Posts na `OrganizerDetailScreen`

Em `lib/ui/screens/organizer_detail_screen.dart`, no método que constrói as seções do organizer, adicionar uma seção "Posts sociais":

```dart
// Buscar posts que têm este organizer
final posts = ref.watch(socialPostsProvider)
    .where((p) => p.organizers.any((o) => o.slug == organizer.slug))
    .toList();

if (posts.isNotEmpty) ...[
  const SectionHeader(title: 'POSTS SOCIAIS'),
  const SizedBox(height: 8),
  SizedBox(
    height: 120,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => _SocialPostMiniCard(post: posts[i]),
    ),
  ),
  const SizedBox(height: 24),
],
```

`_SocialPostMiniCard`: card 80×120 com thumbnail, badge de plataforma no canto. Tap → `SocialPostDetail`.

---

## 8. S7 — Cross-references: citar posts em outros objetos

### Pré-requisitos antes de começar S7

- S1 completo (`SocialPost` no vault e no `allObjectsProvider`)
- `universal_search_picker.dart` incluindo `social_post` (feito em S1.8)
- `backlinksProvider` funcionando (já existia, não precisa mudar)

### S7.1 — Campo `socialRefs` nos modelos Goal, Task, Note

Em `lib/models/goal_model.dart`:

```dart
class Goal extends ContentObject {
  // ... campos existentes ...
  List<String> socialRefs; // WikiLinks: "[[social/tiktok-post-slug]]"

  Goal({
    // ... parâmetros existentes ...
    List<String>? socialRefs,
  }) : socialRefs = socialRefs ?? [],
       super();
```

Em `toMarkdown()`, adicionar:
```dart
if (socialRefs.isNotEmpty) frontmatter['social_refs'] = socialRefs;
```

Em `fromMarkdown()`, adicionar:
```dart
if (frontmatter['social_refs'] != null) {
  goal.socialRefs = List<String>.from(frontmatter['social_refs'] as List? ?? []);
}
```

Repetir o mesmo em `Task` e `Note`. Para `JournalEntry`, não adicionar `socialRefs` — entries usam WikiLinks inline no body de texto rico.

### S7.2 — "Inspirado por" no formulário de Goal

Em `lib/ui/forms/create_goal_form.dart`, adicionar uma seção chamada `"Inspirado por"` após a seção de KPIs:

**Layout da seção:**

```
Inspirado por
┌────────────────────────────────────┐
│  [+ Adicionar post de referência]  │
└────────────────────────────────────┘
```

Quando há posts adicionados:
```
Inspirado por
┌──────────────────────────────────────┐
│  ┌────┐ @handle · TikTok    [×]      │
│  │    │ Título do post               │
│  └────┘                              │
│  ┌────┐ @user · Substack    [×]      │
│  │    │ Título do artigo             │
│  └────┘                              │
│  [+ Adicionar post de referência]    │
└──────────────────────────────────────┘
```

Implementação:

```dart
// Estado no form:
List<SocialPost> _socialRefs = []; // posts selecionados

// Botão "+ Adicionar post de referência"
TextButton.icon(
  icon: Icon(Icons.play_circle_outline_rounded, size: 16, color: AppColors.info),
  label: Text('Adicionar post de referência',
    style: TextStyle(color: AppColors.info, fontSize: 13)),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Buscar post',
        initialFilter: 'social_post',
        onSelected: (obj) {
          if (obj is SocialPost) {
            setState(() => _socialRefs.add(obj));
          }
          Navigator.pop(context);
        },
      ),
    );
  },
)

// Ao salvar o Goal:
goal.socialRefs = _socialRefs.map((p) => '[[${p.obsidianPath.replaceAll('.md', '')}]]').toList();
```

Cada post na lista mostra:
- Thumbnail 40×40 como leading.
- `@handle · platformLabel` como título.
- Primeira linha da caption como subtítulo.
- `IconButton(Icons.close_rounded)` para remover.

### S7.3 — "Adicionar referência" em Task

Em `lib/ui/forms/create_task_form.dart`, na seção de notas/links (onde já existem campos relacionados), adicionar campo similar mas mais compacto:

- Label: `"Referências"`.
- Botão `"+ Link ou post"` que abre `UniversalSearchPickerSheet` sem filtro inicial (busca em todos os tipos, incluindo `social_post`).
- Os objetos selecionados ficam como WikiLinks na lista `task.moc` (reutilizar o campo `moc` existente — não criar campo novo em Task). Task já tem `moc: List<String>`, funciona direto.

### S7.4 — Seção "Referências" no `UniversalDetailView` para Goals

Em `lib/ui/screens/universal_detail_view.dart`, dentro do case de Goal, adicionar seção após KPIs:

```dart
// Dentro do switch que renderiza por tipo, no case Goal:
if (goal.socialRefs.isNotEmpty) ...[
  const SectionHeader(title: 'POSTS DE REFERÊNCIA'),
  const SizedBox(height: 8),
  ...goal.socialRefs.map((ref) {
    // ref = "[[social/tiktok-post-slug]]"
    final path = ref.replaceAll('[[', '').replaceAll(']]', '') + '.md';
    final post = ref.watch(socialPostsProvider)
        .firstWhereOrNull((p) => p.obsidianPath == path);
    if (post == null) return const SizedBox.shrink();
    return _SocialPostMiniCard(post: post); // mesmo card do S6.2
  }),
  const SizedBox(height: 16),
],
```

### S7.5 — Garantir que `backlinksProvider` funciona para posts sociais

**Sem nenhuma mudança de código.** O `backlinksProvider` existente já faz:

```dart
final content = obj.toMarkdown().toLowerCase();
return content.contains('[[${targetSlug.toLowerCase()}]]') ||
    content.contains('[[${target.title.toLowerCase()}]]');
```

Como `SocialPost.toMarkdown()` inclui o campo `social_refs` no frontmatter (ex: `social_refs: ["[[social/tiktok-post-slug]]"]`), e como Goals e Tasks incluem `social_refs` no frontmatter também, o backlinks vai funcionar automaticamente para todos os sentidos.

**O único cuidado:** garantir que o `slug` de um `SocialPost` retornado por `target.slug` (herdado de `ContentObject`) coincida com o `socialSlug` usado no `obsidianPath`. Para isso, sobrescrever `slug` no `SocialPost`:

```dart
@override
String get slug => socialSlug; // garantir que ContentObject.slug == socialSlug
```

---

## 9. S8 — Obsidian integration

### Pré-requisitos antes de começar S8

- S1 completo (posts sendo salvos em `social/*.md`)
- Formato do `.md` já funciona (S1.1)

### S9.1 — Formato canônico do `.md` de um post

Exemplo completo de `social/tiktok-johndoe-video-sobre-meditacao.md`:

```markdown
---
id: "abc123"
type: "social_post"
title: "Video sobre meditação e produtividade"
url: "https://www.tiktok.com/@johndoe/video/12345678"
platform: "tiktok"
media_type: "video"
caption: "Essa rotina de meditação de 5 minutos mudou minha produtividade completamente. Experimenta por 7 dias e me conta."
author_handle: "johndoe"
author_name: "John Doe"
thumbnail: "https://p16-sign.tiktokcdn-us.com/..."
embed_url: "https://www.tiktok.com/embed/v2/12345678"
posted_at: "2026-04-15T14:30:00.000Z"
watched: false
tags:
  - "meditação"
  - "produtividade"
organizers:
  - "[[label/inspiração]]"
  - "[[area/saude]]"
social_refs: []
created_at: "2026-05-17T10:00:00.000Z"
updated_at: "2026-05-17T10:00:00.000Z"
archived: false
pinned: false
moc: []
categories: []
---

Essa rotina de meditação de 5 minutos mudou minha produtividade completamente. Experimenta por 7 dias e me conta.

---

## Nota pessoal

Quero tentar essa rotina por uma semana. Associar ao goal [[goals/saude-mental-2026]].
```

**Importante:** A caption aparece tanto no frontmatter (campo `caption`) quanto no body do `.md`. Isso é intencional: o frontmatter serve para queries Dataview e para o app ler eficientemente, e o body serve para busca full-text no Obsidian e para o campo de nota pessoal ser separável visualmente.

### S9.2 — `moc_service.dart` — gerar `social/index.md`

Em `lib/services/moc_service.dart`, no método que gera index files por pasta, adicionar o case para a pasta `social`:

```dart
// Ao gerar o index da pasta social/:
const socialIndexContent = '''
---
type: moc
title: Social Archive
---

# Social Archive

## Todos os posts

\`\`\`dataview
TABLE platform, author_handle AS "Autor", posted_at AS "Data", watched AS "Visto"
FROM "social"
WHERE type = "social_post"
SORT created_at DESC
\`\`\`

## Por plataforma

### TikTok
\`\`\`dataview
TABLE author_handle AS "Autor", caption AS "Caption", watched
FROM "social"
WHERE type = "social_post" AND platform = "tiktok"
SORT created_at DESC
\`\`\`

### Instagram
\`\`\`dataview
TABLE author_handle AS "Autor", watched
FROM "social"
WHERE type = "social_post" AND platform = "instagram"
SORT created_at DESC
\`\`\`

### Substack
\`\`\`dataview
TABLE author_name AS "Autor", title, watched
FROM "social"
WHERE type = "social_post" AND platform = "substack"
SORT posted_at DESC
\`\`\`

## Não vistos
\`\`\`dataview
TABLE platform, author_handle, created_at AS "Salvo em"
FROM "social"
WHERE type = "social_post" AND watched = false
SORT created_at DESC
\`\`\`
''';
await obsidianService.saveFile('social/index.md', socialIndexContent);
```

### S9.3 — Botão "Abrir no Obsidian" no Post Detail

Já está no action sheet (S4.2). Implementação:

```dart
case 'abrir_obsidian':
  final settings = ref.read(settingsProvider);
  final uri = Uri.parse(
    'obsidian://open?vault=${Uri.encodeComponent(settings.vaultName)}'
    '&file=${Uri.encodeComponent(post.obsidianPath)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
  break;
```

---

## 10. S9 — Share sheet e import em lote

### Pré-requisitos antes de começar S9

- S2 completo (`CreateSocialPostForm` e `OEmbedService` funcionando)
- Testar S2 no dispositivo real (não simulador) antes de implementar share

### S9.1 — Adicionar `receive_sharing_intent` ao `pubspec.yaml`

```yaml
receive_sharing_intent: ^1.8.0
```

Para iOS, em `ios/Runner/Info.plist` dentro do `NSExtensionActivationRule` do Share Extension (precisa criar o target no Xcode):

```xml
<key>NSExtensionAttributes</key>
<dict>
  <key>NSExtensionActivationRule</key>
  <dict>
    <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
    <integer>1</integer>
    <key>NSExtensionActivationSupportsText</key>
    <true/>
  </dict>
</dict>
```

Para Android, em `AndroidManifest.xml` dentro de `<activity>`:
```xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="text/plain" />
</intent-filter>
```

### S9.2 — Interceptar share no `main.dart` / `BootstrapApp`

Em `lib/main.dart`, dentro do `_BootstrapAppState`:

```dart
@override
void initState() {
  super.initState();
  // Interceptar share intent
  ReceiveSharingIntent.instance.getInitialMedia().then((media) {
    if (media.isNotEmpty) {
      final text = media.first.message ?? media.first.path ?? '';
      if (_isUrl(text)) {
        _openCreateFormWithUrl(text);
      }
    }
  });
  ReceiveSharingIntent.instance.getMediaStream().listen((media) {
    if (media.isNotEmpty) {
      final text = media.first.message ?? media.first.path ?? '';
      if (_isUrl(text)) {
        _openCreateFormWithUrl(text);
      }
    }
  });
}

bool _isUrl(String text) =>
    text.startsWith('http://') || text.startsWith('https://');

void _openCreateFormWithUrl(String url) {
  // Navegar para CreateSocialPostForm passando a URL
  // O Navigator ainda não está disponível no initState, então usar um flag
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => CreateSocialPostForm(initialUrl: url),
    ));
  });
}
```

Em `CreateSocialPostForm`, aceitar `String? initialUrl` no construtor:

```dart
class CreateSocialPostForm extends ConsumerStatefulWidget {
  final String? initialUrl;
  const CreateSocialPostForm({super.key, this.initialUrl});
```

Em `initState` do form, se `initialUrl != null`, preencher o campo URL e disparar o fetch automaticamente:

```dart
@override
void initState() {
  super.initState();
  if (widget.initialUrl != null) {
    _urlController.text = widget.initialUrl!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
  }
}
```

### S9.3 — Clipboard auto-detect na Social Screen

Em `_SocialScreenState.initState`:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
}

Future<void> _checkClipboard() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  if (!mounted) return;
  final platform = OEmbedService.detectPlatform(text);
  if (platform != SocialPlatform.other && _isUrl(text)) {
    // Mostrar banner
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          'Você tem um link de ${platformLabel(platform)} copiado.',
          style: const TextStyle(fontSize: 13),
        ),
        leading: Icon(platformIcon(platform), color: platformColor(platform)),
        actions: [
          TextButton(
            child: const Text('Ignorar'),
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          ),
          TextButton(
            child: Text('Salvar', style: TextStyle(color: AppColors.primary)),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateSocialPostForm(initialUrl: text),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

O banner aparece no topo da tela (acima do AppBar) e fica até o usuário tocar em "Ignorar" ou "Salvar".

### S9.4 — Import em lote (Settings → Social)

Em `lib/ui/screens/settings_screen.dart`, adicionar entrada no grupo de configurações (pode ser em um grupo novo "Social"):

```
Social
────────────────────────────
Importar lista de URLs →
```

Tap → abre `SocialBulkImportScreen`.

**Arquivo `lib/ui/screens/social_bulk_import_screen.dart`:**

```
┌─────────────────────────────────────┐
│  ←  Importar posts em lote          │
├─────────────────────────────────────┤
│  Cole os links abaixo.              │
│  Um link por linha.                 │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ https://tiktok.com/...      │    │
│  │ https://instagram.com/...   │    │
│  │ https://substack.com/...    │    │
│  └─────────────────────────────┘    │
│                                     │
│  Links válidos detectados: 3/3      │  ← contagem em tempo real
│                                     │
│  [      Importar 3 posts      ]     │  ← botão primário
└─────────────────────────────────────┘
```

Comportamento:
- `TextField` com `maxLines: null, minLines: 5`.
- `onChanged`: dividir por `\n`, filtrar linhas que são URLs válidas de plataformas suportadas. Atualizar contagem em tempo real.
- Botão "Importar X posts": habilitado apenas se `validUrls.isNotEmpty`.
- Ao tocar: mostrar `LinearProgressIndicator`. Para cada URL, chamar `OEmbedService().fetchMetadata(url)` em sequência (não em paralelo, para não rate-limitar). A cada post buscado, salvar imediatamente via `addPost`. Ao terminar: `Navigator.pop` + SnackBar `"X posts importados com sucesso"`.
- Se um URL falhar: continuar para o próximo. Ao final, informar `"X importados, Y falharam"`.

---

---

## Apêndice A — Widgets utilitários completos

### A.1 — `_SocialPostMiniCard`

Usado em `OrganizerDetailScreen` (S6.2) e em `UniversalDetailView` para Goals (S7.4). É um widget privado inline (pode ser definido como `class _SocialPostMiniCard extends StatelessWidget` no arquivo onde for usado pela primeira vez, e importado nos demais, ou copiado como widget privado em cada arquivo).

**Dimensões:** largura 80px, altura 120px (fixas — para uso em `ListView` horizontal).

**Estrutura:**

```dart
class _SocialPostMiniCard extends StatelessWidget {
  final SocialPost post;
  const _SocialPostMiniCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SocialPostDetail(post: post)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo: thumbnail ou cor de plataforma
            if (post.thumbnailUrl != null)
              Image.network(
                post.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildColorFallback(),
              )
            else
              _buildColorFallback(),

            // Overlay gradiente no fundo
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),

            // Badge de plataforma no canto inferior esquerdo
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: platformColor(post.platform),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  platformLabel(post.platform).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Dot "não visto" no canto superior direito
            if (!post.watched)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorFallback() {
    return ColoredBox(
      color: platformColor(post.platform).withAlpha(30),
      child: Center(
        child: Icon(
          platformIcon(post.platform),
          color: platformColor(post.platform),
          size: 28,
        ),
      ),
    );
  }
}
```

### A.2 — `SocialPostListTile` completo

Referenciado em S3.5 como modo lista da Social Screen. Definir como método privado `_buildListTile(SocialPost post)` dentro do `_SocialScreenState`, ou como widget separado `lib/ui/widgets/social_post_list_tile.dart`.

```dart
Widget _buildListTile(SocialPost post) {
  return ObjectActionWrapper(
    object: post,
    child: GestureDetector(
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (_selectedIds.contains(post.id)) {
              _selectedIds.remove(post.id);
            } else {
              _selectedIds.add(post.id);
            }
          });
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SocialPostDetail(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox de multi-select (só visível no modo multi-select)
            if (_isMultiSelectMode)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _selectedIds.contains(post.id),
                    onChanged: (_) {
                      setState(() {
                        if (_selectedIds.contains(post.id)) {
                          _selectedIds.remove(post.id);
                        } else {
                          _selectedIds.add(post.id);
                        }
                      });
                    },
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: post.thumbnailUrl != null
                    ? Image.network(
                        post.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: platformColor(post.platform).withAlpha(30),
                          child: Icon(
                            platformIcon(post.platform),
                            color: platformColor(post.platform),
                            size: 24,
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: platformColor(post.platform).withAlpha(30),
                        child: Icon(
                          platformIcon(post.platform),
                          color: platformColor(post.platform),
                          size: 24,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // Conteúdo textual
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha 1: handle + badge plataforma + dot não-visto
                  Row(
                    children: [
                      if (post.authorHandle != null) ...[
                        Text(
                          '@${post.authorHandle}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Badge de plataforma
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: platformColor(post.platform),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          platformLabel(post.platform).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Dot azul se não visto
                      if (!post.watched)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.info,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Linha 2: título/caption
                  Text(
                    post.caption?.isNotEmpty == true
                        ? post.caption!
                        : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Linha 3: organizers como chips + timestamp
                  Row(
                    children: [
                      // Chips de organizers (máximo 2 + "+N")
                      Expanded(
                        child: post.organizers.isEmpty
                            ? const SizedBox.shrink()
                            : Wrap(
                                spacing: 4,
                                children: [
                                  ...post.organizers
                                      .take(2)
                                      .map((o) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              o.title,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          )),
                                  if (post.organizers.length > 2)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${post.organizers.length - 2}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      // Timestamp relativo
                      Text(
                        _relativeTime(post.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper para timestamp relativo
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays}d';
  if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()}sem';
  if (diff.inDays < 365) return 'há ${(diff.inDays / 30).floor()}m';
  return 'há ${(diff.inDays / 365).floor()}a';
}
```

### A.3 — `_buildEmbedFallback` no `SocialPostDetail`

Referenciado em S5.3 como método do detail view. Definir em `social_post_detail.dart`:

```dart
Widget _buildEmbedFallback(SocialPost post) {
  return Container(
    height: 200,
    decoration: BoxDecoration(
      color: platformColor(post.platform).withAlpha(15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Thumbnail se disponível, senão ícone da plataforma
        if (post.thumbnailUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              post.thumbnailUrl!,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                platformIcon(post.platform),
                size: 48,
                color: platformColor(post.platform),
              ),
            ),
          )
        else
          Icon(
            platformIcon(post.platform),
            size: 48,
            color: platformColor(post.platform),
          ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(post.url),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text('Abrir no ${platformLabel(post.platform)}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: platformColor(post.platform),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    ),
  );
}
```

---

## Apêndice B — Casos de borda e tratamento de erros

### B.1 — URLs curtas e variantes de plataforma

O método `detectPlatform` em `OEmbedService` precisa tratar as variantes abaixo. Adicionar estes cases **antes** dos cases genéricos de domínio:

```dart
static SocialPlatform detectPlatform(String url) {
  final lower = url.toLowerCase().trim();

  // TikTok: URLs curtas vm.tiktok.com e vt.tiktok.com
  if (lower.contains('vm.tiktok.com') ||
      lower.contains('vt.tiktok.com') ||
      lower.contains('tiktok.com'))     return SocialPlatform.tiktok;

  // Instagram: também IG.ME
  if (lower.contains('instagram.com') ||
      lower.contains('ig.me'))          return SocialPlatform.instagram;

  // Pinterest: URLs curtas pin.it
  if (lower.contains('pinterest.com') ||
      lower.contains('pinterest.co.uk') ||
      lower.contains('pin.it'))         return SocialPlatform.pinterest;

  // Substack: domínios customizados de autores terminam em .substack.com
  // Mas autores podem ter domínio próprio (ex: newsletter.author.com)
  // Tratar só os .substack.com aqui — domínio próprio cai em 'other'
  if (lower.contains('.substack.com')) return SocialPlatform.substack;

  // YouTube
  if (lower.contains('youtube.com') ||
      lower.contains('youtu.be'))       return SocialPlatform.youtube;

  // Twitter/X
  if (lower.contains('twitter.com') ||
      lower.contains('x.com'))         return SocialPlatform.twitter;

  return SocialPlatform.other;
}
```

**URLs curtas do TikTok (`vm.tiktok.com/XXXXX`):** Estas URLs redirecionam para a URL canônica com o video ID. O `buildEmbedUrl` não consegue extrair o ID diretamente. Solução: em `fetchMetadata`, antes de chamar `buildEmbedUrl`, resolver o redirect da URL curta:

```dart
// Em fetchMetadata(), logo no início, antes de qualquer switch:
String resolvedUrl = url;
if (url.contains('vm.tiktok.com') || url.contains('vt.tiktok.com')) {
  resolvedUrl = await _resolveRedirect(url) ?? url;
}
// Usar resolvedUrl no lugar de url daqui para frente

Future<String?> _resolveRedirect(String url) async {
  try {
    // http.Client com followRedirects: false para pegar o Location header
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url))
      ..followRedirects = false;
    final response = await client.send(request);
    client.close();
    return response.headers['location'];
  } catch (_) {
    return null;
  }
}
```

### B.2 — Timeout e fallback para metadados

Se `fetchMetadata` falhar completamente (sem rede, URL inválida, plataforma bloqueou o scrape), o app **não pode travar**. O método já retorna um `SocialPost` com o `title` preenchido com o URL. Isso é suficiente para salvar o post — o usuário pode preencher os campos manualmente no form. Não mostrar erro de exceção ao usuário — somente o texto de erro no form (ver S2.2).

### B.3 — Thumbnails que falham ao carregar

Em todos os widgets que usam `Image.network`, o `errorBuilder` deve mostrar a cor de fundo de plataforma + ícone. Esse padrão já está definido em `_SocialPostMiniCard`, `SocialPostListTile` e `SocialPostGridCard`. **Não usar `Image.network` sem `errorBuilder` em nenhum ponto do módulo Social.**

### B.4 — `socialSlug` com colisões

Dois posts diferentes podem gerar o mesmo `socialSlug` (mesmo handle, mesma primeira palavra). Para evitar colisão no nome do arquivo:

```dart
String get socialSlug {
  // Usar os primeiros 8 chars do UUID (já sempre único)
  final shortId = id.replaceAll('-', '').substring(0, 8);
  final base = '${platform.name}-${authorHandle ?? ''}-$shortId'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return base;
}
```

Exemplo de resultado: `tiktok-johndoe-a1b2c3d4.md`. Isso garante unicidade total sem depender de nenhum campo que o usuário ou o oEmbed preencha.

**Atualizar S1.1 do modelo:** Substituir o `socialSlug` baseado em título pelo baseado em `id` acima.

### B.5 — Posts sem `embedUrl` (plataforma `other` ou regex não encontrou o ID)

Na `SocialPostDetail`, a condição de exibição do embed já cobre isso:

```dart
// Se não tem embedUrl e não é Substack: mostrar só o fallback
if (post.embedUrl != null || post.platform == SocialPlatform.substack)
  SocialEmbedView(post: post)
else
  _buildEmbedFallback(post),
```

Para posts da plataforma `other`: sempre mostrar `_buildEmbedFallback` com o botão "Abrir link".

### B.6 — Vault não inicializado / pasta `social/` não existe ainda

`_ensureVaultFolders()` é chamado no início de cada sync e ao abrir o vault. Se o usuário abrir a Social Screen antes de qualquer sync ter ocorrido, a pasta `social/` pode não existir. O `socialPostsProvider` vai retornar lista vazia (não erro). Isso é o comportamento correto — mostrar a `EmptyState` é suficiente.

Ao criar o primeiro post via `addPost`, o `vaultProvider.createObject` vai chamar `_ensureVaultFolders()` internamente (já acontece nos outros tipos), criando a pasta na hora.

### B.7 — Deletar arquivo `.md` do post diretamente no Obsidian

Se o usuário deletar `social/tiktok-abc.md` no Obsidian, no próximo `allObjectsProvider` reload o post vai sumir do app. Nenhuma ação especial necessária — é o comportamento correto (Obsidian é a fonte da verdade).

Se o app mantiver uma referência ao post deletado em algum `socialRefs` de um Goal (ex: `social_refs: ["[[social/tiktok-abc]]"`), ao tentar resolver essa referência em `UniversalDetailView` (S7.4), o `firstWhereOrNull` retornará `null` e o `SizedBox.shrink()` vai ser renderizado. O Goal em si não quebra.

### B.8 — WebView bloqueado por política de embed da plataforma

TikTok e Instagram ocasionalmente mudam suas políticas de embed. Se o embed do TikTok parar de funcionar (a iframe retornar página de erro ou ficar em branco após timeout de 10s), o `WebViewController` vai disparar `onWebResourceError` e o `SocialEmbedView` vai mostrar o fallback automaticamente.

Para detectar iframe em branco (sem `onWebResourceError`): no `onPageFinished`, verificar o título da página carregada:

```dart
onPageFinished: (url) async {
  final title = await _controller.getTitle();
  if (title == null || title.isEmpty || title.toLowerCase().contains('error')) {
    setState(() => _hasError = true);
    return;
  }
  setState(() => _isLoaded = true);
},
```

### B.9 — `_isUrl` helper

Referenciado em S9.3 (clipboard detect) e S9.2 (share intent). Definir como função top-level em `lib/utils/url_utils.dart`:

```dart
// lib/utils/url_utils.dart
bool isUrl(String text) {
  final trimmed = text.trim();
  return trimmed.startsWith('https://') || trimmed.startsWith('http://');
}

bool isSupportedSocialUrl(String text) {
  if (!isUrl(text)) return false;
  return OEmbedService.detectPlatform(text) != SocialPlatform.other;
}
```

Importar onde necessário. **Não duplicar essa lógica inline** — qualquer ponto do app que precise verificar URLs sociais usa `isSupportedSocialUrl`.

---

## Apêndice C — `navigatorKey` e share intent

O share intent (S9.2) dispara fora do ciclo de vida de qualquer `Widget` — chega via stream do `ReceiveSharingIntent`. Para navegar programaticamente nesses casos, o `Navigator` não pode ser acessado via `context` (pois não existe contexto disponível naquele momento). A solução é um `navigatorKey` global.

### C.1 — Adicionar `navigatorKey` em `main.dart`

```dart
// No topo do arquivo main.dart, fora de qualquer classe:
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

No `MaterialApp` (ou `GoRouter`), passar o key:

```dart
// Se usando MaterialApp diretamente:
MaterialApp(
  navigatorKey: navigatorKey,
  // ... resto
)

// Se usando GoRouter (caso do app):
// GoRouter não aceita navigatorKey diretamente da mesma forma.
// A solução é usar ShellRoute ou RouterDelegate.
// Alternativa mais simples: manter um Navigator raiz com o key e usar
// navigatorKey.currentState?.push(...) para abrir o CreateSocialPostForm
// por cima do GoRouter, como overlay.
```

**Se o app usa GoRouter:** A abordagem mais simples é não tentar navegar via GoRouter a partir do share intent. Em vez disso, usar `navigatorKey.currentState?.push(MaterialPageRoute(...))` diretamente — isso abre o form como uma nova rota Material por cima da stack do GoRouter, o que é aceitável para esse caso específico.

### C.2 — Inicialização do listener de share intent

O listener deve ser iniciado no `initState` do widget raiz (o `ConsumerStatefulWidget` que engloba o `MaterialApp`/`GoRouter`). Não iniciar em `SocialScreen.initState` — o app pode não estar na Social Screen quando o share chegar.

```dart
class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    _initShareListener();
  }

  void _initShareListener() {
    // URL compartilhada quando o app estava fechado (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (media.isEmpty) return;
      final text = media.first.message ?? '';
      if (!isSupportedSocialUrl(text)) return;
      // Aguardar o frame para ter contexto disponível
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => CreateSocialPostForm(initialUrl: text),
        ));
      });
    });

    // URL compartilhada com o app aberto (warm share)
    ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      if (media.isEmpty) return;
      final text = media.first.message ?? '';
      if (!isSupportedSocialUrl(text)) return;
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => CreateSocialPostForm(initialUrl: text),
      ));
    });
  }

  @override
  void dispose() {
    ReceiveSharingIntent.instance.reset();
    super.dispose();
  }
}
```

### C.3 — Verificar se o share intent já foi processado

O `getInitialMedia()` é chamado toda vez que o app inicia — se o usuário abrir o app normalmente (sem share), ele retorna lista vazia, então não há problema. Mas se o app for aberto via share e o usuário fechar sem salvar o post e abrir o app novamente, `getInitialMedia()` pode retornar a mesma URL de novo (comportamento depende de plataforma). Para evitar abrir o form duas vezes:

```dart
bool _initialShareHandled = false;

ReceiveSharingIntent.instance.getInitialMedia().then((media) {
  if (_initialShareHandled || media.isEmpty) return;
  _initialShareHandled = true;
  // ... rest of logic
});
```

---

## Apêndice D — Conflito long press: multi-select vs ObjectActionWrapper

### O problema

`ObjectActionWrapper` usa `GestureDetector(onLongPress: ...)` para abrir o action sheet genérico. A Social Screen precisa que long press **ative o modo multi-select** em vez de abrir o action sheet. Há conflito.

### A solução

**Não usar `ObjectActionWrapper` em `SocialPostGridCard` e `SocialPostListTile`.** Em vez disso, o longo pressionamento é tratado localmente no card e no screen. O action sheet do post (o equivalente do `ObjectActionWrapper`) é acessível pelo botão ⋯ no `SocialPostDetail`.

Implementação no `SocialPostGridCard`:

```dart
GestureDetector(
  onTap: () {
    if (_isMultiSelectMode) {
      // selecionar/deselecionar
      onMultiSelectToggle?.call(post.id);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SocialPostDetail(post: post),
      ));
    }
  },
  onLongPress: () {
    HapticFeedback.mediumImpact();
    onLongPress?.call(post.id); // callback para o screen ativar multi-select
  },
  child: /* card visual */,
)
```

O `SocialPostGridCard` precisa de dois callbacks no construtor:

```dart
class SocialPostGridCard extends StatelessWidget {
  final SocialPost post;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback? onLongPress;          // ativa multi-select no screen
  final ValueChanged<String>? onMultiSelectToggle; // toggle do id
  // ...
}
```

No `SocialScreen`, ao construir os cards:

```dart
SocialPostGridCard(
  post: post,
  isSelected: _selectedIds.contains(post.id),
  isMultiSelectMode: _isMultiSelectMode,
  onLongPress: () {
    setState(() {
      _isMultiSelectMode = true;
      _selectedIds.add(post.id);
    });
  },
  onMultiSelectToggle: (id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  },
)
```

O mesmo padrão se aplica ao `_buildListTile` no modo lista — substituir `ObjectActionWrapper` por `GestureDetector` com `onLongPress` explícito.

**Onde acessar o action sheet genérico do post (o que `ObjectActionWrapper` daria):** No `SocialPostDetail`, o botão ⋯ no AppBar abre o action sheet completo (definido em S4.2). Não há perda de funcionalidade.

---

## Apêndice E — CreateSocialPostForm em modo edição

Referenciado em S4.2 (action sheet item "Editar post"). O formulário precisa suportar dois modos: **criação** (novo post a partir de URL) e **edição** (post existente, todos os campos pré-preenchidos e URL já buscada).

### E.1 — Construtor com modo edição

```dart
class CreateSocialPostForm extends ConsumerStatefulWidget {
  final String? initialUrl;    // modo criação: URL a ser buscada automaticamente
  final SocialPost? editPost;  // modo edição: post a ser editado

  const CreateSocialPostForm({
    super.key,
    this.initialUrl,
    this.editPost,
  }) : assert(initialUrl != null || editPost != null ||
      (initialUrl == null && editPost == null),
      'Pode ser criação (initialUrl), edição (editPost), ou novo em branco');
}
```

### E.2 — `initState` com os dois modos

```dart
@override
void initState() {
  super.initState();

  if (widget.editPost != null) {
    // MODO EDIÇÃO: pré-preencher tudo, marcar URL como já buscada
    final p = widget.editPost!;
    _urlController.text = p.url;
    _captionController.text = p.caption ?? '';
    _noteController.text = p.personalNote ?? '';
    _fetchedPost = p;           // já tem o post, não precisa buscar
    _hasFetched = true;         // URL field fica desabilitado
    _selectedOrganizers = List.from(p.organizers);
    _tags = List.from(p.tags);
    _isEditMode = true;
  } else if (widget.initialUrl != null) {
    // MODO CRIAÇÃO COM URL: preencher campo e disparar fetch
    _urlController.text = widget.initialUrl!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
  }
  // else: formulário em branco (modo criação manual)
}
```

### E.3 — Comportamento do botão Salvar em modo edição

```dart
Future<void> _save() async {
  final post = _buildPost(); // monta SocialPost a partir dos campos

  if (_isEditMode) {
    // Modo edição: obsidianPath já existe, só atualizar
    await ref.read(socialPostsProvider.notifier).updatePost(post);
  } else {
    // Modo criação: atribuir obsidianPath novo
    post.obsidianPath = 'social/${post.socialSlug}.md';
    await ref.read(socialPostsProvider.notifier).addPost(post);
  }

  if (!mounted) return;
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_isEditMode ? 'Post atualizado' : 'Post salvo')),
  );
}
```

### E.4 — AppBar em modo edição

```dart
AppBar(
  title: Text(_isEditMode ? 'Editar post' : 'Novo post social'),
  centerTitle: true,
  leading: IconButton(
    icon: const Icon(Icons.close_rounded),
    onPressed: () => Navigator.pop(context),
  ),
  actions: [
    TextButton(
      onPressed: _canSave ? _save : null,
      child: Text(
        _isEditMode ? 'Salvar' : 'Salvar',
        style: TextStyle(
          color: _canSave ? AppColors.primary : AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ],
)
```

### E.5 — Campos desabilitados em modo edição

Em modo edição:
- O campo URL fica desabilitado (`readOnly: true`) e não mostra o botão "Buscar". Mostrar um `TextButton("Mudar URL")` abaixo do campo que pergunta via `showDialog`: *"Mudar a URL vai buscar novos metadados e sobrescrever título e caption. Continuar?"* → se confirmar, resetar `_hasFetched = false` e habilitar o campo.
- O badge de plataforma no preview é informativo, não editável.
- Caption, nota, organizers e tags são editáveis normalmente.

---

## Apêndice F — Ordem de implementação e arquivos

### Ordem obrigatória (cada etapa depende das anteriores)

1. **S1** — `social_post.dart` + vault folder + provider + `allObjectsProvider` + `NavSection.social` + rota `/social`
2. **S2** — `oembed_service.dart` + `url_utils.dart` + `create_social_post_form.dart` (modo criação)
3. **S3** — `social_screen.dart` + `social_post_grid_card.dart` + `_buildListTile` + `_relativeTime`
4. **S4** — `social_post_detail.dart` + action sheet
5. **S6** — drawer de coleções na Social Screen + seção posts na `OrganizerDetailScreen`
6. **S7** — campo `socialRefs` em Goal + `create_goal_form.dart` + `universal_detail_view.dart`
7. **S8** — `moc_service.dart` (gerar `social/index.md`)
8. **Apêndice E** — `CreateSocialPostForm` modo edição (depende de S2 e S4)
9. **Apêndice C** — `navigatorKey` + share intent listener (depende de S2)
10. **S5** — `social_embed_view.dart` + `webview_flutter` no `pubspec.yaml`
11. **S9** — `social_bulk_import_screen.dart` + clipboard detect + `receive_sharing_intent`

S5, S8 e S9 podem ser feitas em qualquer ordem após S4. S5 é a única com nova dependência.

### Novos arquivos

| Arquivo | Fase |
|---|---|
| `lib/models/social_post.dart` | S1 |
| `lib/utils/url_utils.dart` | S2 |
| `lib/services/oembed_service.dart` | S2 |
| `lib/ui/forms/create_social_post_form.dart` | S2 + Apêndice E |
| `lib/ui/screens/social_screen.dart` | S3 |
| `lib/ui/widgets/social_post_grid_card.dart` | S3 |
| `lib/ui/screens/social_post_detail.dart` | S4 |
| `lib/ui/widgets/social_embed_view.dart` | S5 |
| `lib/ui/screens/social_bulk_import_screen.dart` | S9 |

### Arquivos modificados

| Arquivo | O que muda | Fase |
|---|---|---|
| `lib/services/obsidian_service.dart` | `'social'` em `_ensureVaultFolders` | S1 |
| `lib/providers/vault_provider.dart` | Import + case `social_post` no `AllObjectsNotifier` + `SocialPostsNotifier` + `socialPostsProvider` | S1 |
| `lib/models/navigation_item.dart` | `NavSection.social` + case em `_getSectionIcon` | S1 |
| `lib/main.dart` | Rota `/social` + `navigatorKey` global + share intent listener | S1, Apêndice C |
| `lib/ui/widgets/universal_search_picker.dart` | Case `social_post` em `getIconForType` + na lista de filtros | S1 |
| `lib/ui/widgets/organizer_picker_modal.dart` | Case `social_post` em `getIconForType` | S1 |
| `lib/ui/widgets/create_menu_sheet.dart` | Opção "Post social" | S2 |
| `lib/models/goal_model.dart` | Campo `socialRefs: List<String>` + serialização | S7 |
| `lib/models/note_model.dart` | Campo `socialRefs: List<String>` + serialização | S7 |
| `lib/ui/forms/create_goal_form.dart` | Seção "Inspirado por" com picker | S7 |
| `lib/ui/screens/universal_detail_view.dart` | Seção "Posts de referência" no case Goal | S7 |
| `lib/ui/screens/organizer_detail_screen.dart` | Seção "Posts sociais" com mini-cards horizontais | S6 |
| `lib/services/moc_service.dart` | Gerar `social/index.md` com Dataview queries | S8 |
| `lib/ui/screens/settings_screen.dart` | Entrada "Importar posts em lote" | S9 |
| `pubspec.yaml` | `webview_flutter: ^4.10.0` + `receive_sharing_intent: ^1.8.0` | S5, S9 |
| `ios/Runner/Info.plist` | `NSAppTransportSecurity` + configuração de Share Extension | S5, S9 |
| `android/app/src/main/AndroidManifest.xml` | `usesCleartextTraffic` + `intent-filter` para share | S5, S9 |

### Campos adicionados a modelos existentes no vault

| Modelo | Campo novo | Tipo no frontmatter | Fase |
|---|---|---|---|
| Goal | `social_refs` | `list of strings` (WikiLinks) | S7 |
| Note | `social_refs` | `list of strings` (WikiLinks) | S7 |
| Task | usa `moc` existente | `list of strings` (WikiLinks) | S7 |

Task não ganha campo novo — `socialRefs` de tasks vivem no campo `moc` já existente. Isso é intencional: tasks são efêmeras e a referência informal a um post via `moc` é suficiente. Goals e Notes são permanentes e justificam campo dedicado.

### Campos que `SocialPost` acrescenta ao vault Obsidian

Um arquivo `social/*.md` terá no frontmatter todos os campos de `ContentObject` (já conhecidos pelo Dataview) mais:

| Campo | Tipo | Descrição |
|---|---|---|
| `url` | string | URL original do post |
| `platform` | string enum | `tiktok` / `instagram` / `substack` / `pinterest` / `youtube` / `twitter` / `other` |
| `media_type` | string enum | `video` / `image` / `carousel` / `article` / `newsletter` / `other` |
| `caption` | string | Legenda/texto original do post |
| `author_handle` | string | Handle do autor sem `@` |
| `author_name` | string | Nome de exibição |
| `thumbnail` | string | URL da thumbnail |
| `embed_url` | string | URL calculada para iframe |
| `posted_at` | datetime | Data/hora original na plataforma |
| `watched` | bool | Se o usuário marcou como visto |
| `social_refs` | list | WikiLinks para outros posts citados |