# Citrine project audit - 2026-05-11

## Summary

- `flutter test` passed: 9 tests.
- `flutter analyze` failed: 208 issues.
- No existing OpenAI/deepeval usage was found in the Flutter app before this harness was added.
- The new deepeval/OpenAI audit harness lives in `evals/` and is documented in `docs/openai_deepeval_audit.md`.

## Highest-risk findings

1. Analyzer is not yet a passing CI gate.
   - Evidence: `flutter analyze` exits with 208 issues.
   - Priority: fix warnings and correctness-looking analyzer findings before using the app as a release candidate.

2. Several async UI flows use `BuildContext` after async gaps.
   - Evidence: analyzer warnings in `lib/ui/forms/create_entry_form.dart`, `lib/ui/forms/create_task_form.dart`, `lib/ui/screens/planner_screen.dart`, `lib/ui/screens/settings_screen.dart`, `lib/ui/screens/universal_detail_view.dart`, and `lib/ui/shell/app_shell.dart`.
   - Risk: navigation, snackbar, or dialog calls can run after a widget is disposed.
   - Recommendation: add local `if (!context.mounted) return;` checks after awaited work, or restructure the flow to avoid holding context across awaits.

3. Google auth has an `AuthClient.credentials` implementation that throws.
   - Evidence: `lib/services/google_auth_service.dart` implements `AuthClient` but `credentials` throws `UnimplementedError`.
   - Risk: any Google API path or future dependency that reads `credentials` will crash at runtime.
   - Recommendation: wrap only the request-header behavior with an interface the app controls, or provide a real credentials object if `AuthClient` is required.

4. Drive query strings interpolate unsanitized file and folder names.
   - Evidence: `lib/services/google_drive_sync_service.dart` builds Drive query strings with `folderName`, path parts, and file names directly.
   - Risk: names containing quotes can break sync queries or match incorrectly.
   - Recommendation: centralize Drive query escaping and cover names with quotes in tests.

5. Collection KPI counting uses a rough string split for JSON-like content.
   - Evidence: `lib/services/kpi_engine.dart` counts JSON array items with `note.body.split('},{').length`.
   - Risk: malformed or pretty-printed JSON can produce incorrect KPI values.
   - Recommendation: parse JSON with `jsonDecode`, validate arrays, and fall back to markdown line counting only when parsing fails.

## Medium-risk cleanup

- Replace production `print` calls with `debugPrint`, logging abstractions, or user-visible error handling where appropriate.
- Remove unused imports and unreachable/default dead code reported by the analyzer.
- Add focused tests for Google Drive conflict handling, query escaping, KPI collection parsing, and async UI save flows.

## New audit commands

```bash
python -m pip install -r evals/requirements.txt
python evals/openai_project_audit.py --model gpt-4o
deepeval test run evals/test_openai_project_audit.py
```
