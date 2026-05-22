from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_command(args: list[str]) -> str:
    completed = subprocess.run(
        args,
        cwd=ROOT,
        capture_output=True,
        text=True,
        shell=False,
        timeout=120,
    )
    output = "\n".join(part for part in [completed.stdout, completed.stderr] if part)
    return output.strip()


def read_text(path: str, max_chars: int = 8000) -> str:
    text = (ROOT / path).read_text(encoding="utf-8", errors="replace")
    return text[:max_chars]


def collect_project_context() -> str:
    """Collect compact repo context for an LLM audit.

    Keep this intentionally bounded so CI evals stay cheap and predictable.
    """
    files = [
        "README.md",
        "pubspec.yaml",
        "analysis_options.yaml",
        "lib/services/google_auth_service.dart",
        "lib/services/google_drive_sync_service.dart",
        "lib/services/kpi_engine.dart",
        "lib/services/markdown_parser.dart",
        "test/markdown_roundtrip_test.dart",
    ]

    sections = [
        "# Citrine project context",
        "## Native checks",
        "### flutter analyze",
        run_command(["flutter", "analyze"]),
        "### flutter test",
        run_command(["flutter", "test"]),
    ]

    for file_path in files:
        path = ROOT / file_path
        if path.exists():
            sections.append(f"## {file_path}")
            sections.append(read_text(file_path))

    return "\n\n".join(sections)


if __name__ == "__main__":
    print(collect_project_context())
