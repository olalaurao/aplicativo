# Citrine Guidelines

## Objetivo

Este arquivo resume as convenções operacionais do projeto para mudanças rápidas no código, especialmente nas áreas que apareceram no `gap-analysis.txt`.

## Regras principais

- O vault Obsidian continua sendo a fonte de verdade.
- Toda mutação de objetos deve passar por `VaultNotifier`.
- Evite criar estado duplicado fora de providers já existentes.
- Preserve compatibilidade com light mode e dark mode.
- Prefira slugs e nomes de arquivo estáveis em vez de IDs efêmeros quando houver vínculo com WikiLinks.

## Tema e aparência

- A configuração visual do app deve usar `settingsProvider` para persistência.
- `themeMode` e `activeThemeId` definem o comportamento visual global.
- `themeProvider` é a única camada que converte preferências em `ThemeData`.
- Novas telas devem usar `AppTheme` e `AppColors` para cores, superfícies e tipografia.

## UI de detalhe

- Propriedades resumidas devem usar `PropertyGrid`.
- Valores tocáveis devem ser exibidos como células interativas com destaque visual.
- Capas de recursos devem manter proporção estável e não quebrar layouts menores.

## Systems

- `SystemDefinition.scheduler` é uma extensão suportada: Systems podem ter um `Scheduler` opcional para execução recorrente.
- A UI de criação/edição de System deve persistir esse scheduler no frontmatter `scheduler`.

## Diagnósticos

- Relatórios de crash devem ser gravados tanto no armazenamento interno quanto no vault, quando houver caminho configurado.
- O caminho persistido do vault deve usar a chave `vaultPath`.
- A tela de diagnósticos deve permitir exportação rápida dos relatórios agregados.

## Documentação viva

- Atualize este arquivo sempre que uma nova convenção transversal for criada.
- Mantenha `agents.md` como documento mais amplo de arquitetura e práticas.

---

## Resource metadata import

- `ResourceMetadataService.isResourceUrl(url) == true` deve abrir `CreateResourceForm(initialUrl: url)`.
- URLs que não forem de recurso continuam no fluxo social com `CreateSocialPostForm(initialUrl: url)`.
- A ordem de detecção é: `openLibrary`, `googleBooks`, `imdb`, `amazon`, `goodreads`, `unknown`.
- `ResourceDraft.resourceType` deve cair para `General` quando não combinar com os tipos configurados.
- `sourceUrl` deve ser persistido em `Resource.sourceUrl`, nunca em tags.
- URLs de capa devem ser salvas em HTTPS e no maior tamanho disponível quando a origem permitir.
