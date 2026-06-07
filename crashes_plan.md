# Crash/ANR Diagnostics Locais

## Summary
Adicionar um sistema local de diagnóstico que registra crashes, erros Flutter/Dart não tratados e travamentos tipo “Aguardar ou fechar” no Android. Os relatórios serão gravados em dois lugares: armazenamento interno do app e, quando o vault estiver disponível, em `_diagnostics/crash_reports/`, para eu conseguir ler depois mesmo se o celular não estava conectado ao PC no momento.

## Key Changes
- Criar um serviço Dart `CrashReportService` para:
  - capturar `FlutterError.onError`, `PlatformDispatcher.instance.onError` e erros via `runZonedGuarded`;
  - gravar relatório `.md` com timestamp, versão do app, plataforma, rota atual quando possível, erro, stack trace e últimos eventos úteis;
  - manter um pequeno buffer em memória dos últimos `debugPrint`/eventos do app.
- Alterar `main.dart` para inicializar o logger antes de `runApp`, envolver o bootstrap com `runZonedGuarded` e registrar erros de callbacks como widget, share intent, startup e lifecycle.
- Criar uma `CitrineApplication.kt` Android e registrar no `AndroidManifest.xml` para capturar erros nativos antes do Flutter subir:
  - `Thread.setDefaultUncaughtExceptionHandler`;
  - escrita em arquivo interno do app;
  - último lifecycle conhecido.
- Adicionar detector leve de ANR/travamento:
  - watchdog nativo que verifica se a main thread parou de responder por tempo configurado;
  - ao detectar, grava “suspected_anr” com stack trace da main thread e threads relevantes;
  - não tenta impedir o diálogo do Android, só registra o estado antes/depois.
- Expor métodos no canal nativo existente `com.productivity.citrine/settings`:
  - `getDiagnosticReports`;
  - `clearDiagnosticReports`;
  - opcionalmente `copyDiagnosticsToVault` quando o vault carregar.
- Adicionar seção em Settings > Maintenance:
  - “Relatórios de diagnóstico”;
  - listar últimos relatórios;
  - botão para copiar caminho/visualizar resumo;
  - botão para limpar relatórios antigos.

## Report Format
Cada relatório será Markdown legível por agente/humano:

```md
---
type: crash_report
kind: dart_error | flutter_error | native_crash | suspected_anr
created_at: 2026-06-06T...
app_version: 1.0.0+1
platform: android
---

# Crash Report

## What happened
...

## Error
...

## Stack trace
...

## Last app events
...
```

Os arquivos ficarão em:
- interno: diretório de documentos do app, `diagnostics/crash_reports/`;
- vault: `_diagnostics/crash_reports/YYYY-MM-DD_HH-mm-ss_kind.md`.

## Test Plan
- Rodar `flutter analyze`.
- Adicionar teste unitário do serviço Dart para criação e rotação de relatórios.
- Testar erro Dart artificial em debug e confirmar arquivo `.md`.
- Testar exceção Flutter em build/render e confirmar stack trace.
- Testar crash nativo artificial via MethodChannel debug-only e confirmar relatório nativo após reabrir o app.
- Testar ANR artificial debug-only com bloqueio da main thread e confirmar `suspected_anr`.
- Confirmar que o app continua funcionando offline e que nenhum relatório é enviado para servidor externo.

## Assumptions
- Usaremos armazenamento local, sem Firebase Crashlytics/Sentry, para respeitar privacidade e funcionamento offline.
- O relatório tenta explicar “o que, como e por quê”, mas “por quê” será inferido por stack trace, rota e últimos eventos; nem todo ANR permite causa perfeita.
- O vault é o destino principal para leitura posterior, mas a cópia interna é obrigatória para crashes antes do vault carregar.
