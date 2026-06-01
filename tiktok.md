# 01-05 12H30
## Por que os vídeos do TikTok não reproduzem no app

O problema tem **duas causas encadeadas**, e entender o fluxo ajuda bastante:

### Como o app tenta reproduzir um vídeo TikTok

1. **Primeiro tenta o `TikTokVideoResolver`** — um serviço externo (endpoint configurável nas preferências) que extrai a URL direta do vídeo para tocar nativamente.
2. **Se não configurado**, tenta carregar o embed do TikTok (`https://www.tiktok.com/embed/v2/{id}`) via WebView.
3. **Se ambos falham**, cai no fallback com thumbnail e botão "Abrir em navegador interno".

---

### Causa 1 — O `TikTokVideoResolver` não está configurado (mais provável)

No `social_embed_view.dart`, o resolver só roda se `tiktokResolverEndpoint` estiver salvo nas `SharedPreferences`:

```dart
final endpoint = prefs.getString('tiktokResolverEndpoint') ?? '';
if (endpoint.trim().isEmpty) return false; // ← pula o resolver
```

Se o campo estiver vazio, o app **nunca tenta reproduzir o vídeo nativamente** e vai direto para o embed WebView — que hoje quase sempre falha (causa 2).

---

### Causa 2 — O embed do TikTok via WebView está bloqueado pelo próprio TikTok

O TikTok bloqueia ativamente embeds `tiktok.com/embed/v2/{id}` em WebViews de apps de terceiros. A tentativa de embed no WebView resulta em tela preta ou erro, especialmente em Android, mesmo com `setMediaPlaybackRequiresUserGesture(false)` configurado.

---

## O que fazer

### Solução de curto prazo — Configurar um endpoint resolver

O app já tem a infraestrutura pronta (`TikTokVideoResolver`). Você precisa subir um **serviço backend próprio** que receba a URL do TikTok e retorne a URL direta do vídeo (sem marca d'água). Ferramentas como [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) fazem isso:

```bash
# Exemplo de endpoint simples com Python/FastAPI
yt-dlp --get-url "https://www.tiktok.com/@user/video/123456"
```

Depois, nas **configurações do app**, preencha:
- `tiktokResolverEndpoint` → URL do seu backend
- `tiktokResolverApiKey` → chave de acesso (se necessário)

---

### Solução de médio prazo — Expor a tela de configuração do resolver

Verifique se há uma tela nas configurações que permite o usuário inserir esse endpoint. Se não houver, adicione campos em `settings_screen.dart` para salvar `tiktokResolverEndpoint` e `tiktokResolverApiKey` via `SharedPreferences` — o código do `SocialEmbedView` já os lê, só falta a UI para cadastrá-los.

---

### Resumo rápido

| Problema | Causa | Solução |
|---|---|---|
| Vídeo não toca | Resolver externo não configurado | Subir backend + configurar endpoint |
| WebView tela preta | TikTok bloqueia embeds em apps terceiros | Não há workaround confiável sem o resolver |
| Fallback aparece | Ambos os métodos falharam | Comportamento esperado enquanto sem resolver |