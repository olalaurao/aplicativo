from __future__ import annotations

import argparse
from pathlib import Path

from deepeval.openai import OpenAI
from deepeval.tracing import LlmSpanContext, trace
from deepeval.metrics import AnswerRelevancyMetric

from project_context import ROOT, collect_project_context


SYSTEM_PROMPT = """You are auditing a Flutter productivity app.
Return a concise engineering audit with:
1. Highest-risk findings, ordered by severity.
2. Concrete file references when possible.
3. Recommended next fixes.
Do not invent files or claim tests were run unless the project context says so."""


def run_audit(model: str, output_path: Path) -> str:
    client = OpenAI()
    project_context = collect_project_context()

    with trace(
        name="citrine_openai_project_audit",
        tags=["citrine", "audit", "openai", "deepeval"],
        llm_span_context=LlmSpanContext(
            metrics=[AnswerRelevancyMetric()],
            expected_output=(
                "A project audit that prioritizes analyzer failures, failing tests, "
                "runtime risks, data integrity risks, and CI/CD recommendations."
            ),
            context=[project_context],
        ),
    ):
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": project_context},
            ],
        )

    audit = response.choices[0].message.content or ""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(audit, encoding="utf-8")
    return audit


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the traced OpenAI/deepeval project audit.")
    parser.add_argument("--model", default="gpt-4o", help="OpenAI model to use for the audit.")
    parser.add_argument(
        "--output",
        default=str(ROOT / "audit" / "openai_project_audit.md"),
        help="Where to write the generated audit markdown.",
    )
    args = parser.parse_args()

    print(run_audit(model=args.model, output_path=Path(args.output)))


if __name__ == "__main__":
    main()
