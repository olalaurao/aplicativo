from __future__ import annotations

from deepeval import assert_test
from deepeval.openai import OpenAI
from deepeval.tracing import LlmSpanContext, trace
from deepeval.dataset import Golden
from deepeval.metrics import AnswerRelevancyMetric

from project_context import collect_project_context


def test_openai_project_audit_is_relevant() -> None:
    golden = Golden(
        input="Audit the Citrine Flutter project for the highest engineering risks.",
        expected_output=(
            "A relevant audit that discusses analyzer output, test status, runtime risks, "
            "data integrity risks, and next fixes for this Flutter app."
        ),
    )
    client = OpenAI()
    project_context = collect_project_context()

    with trace(
        name="citrine_openai_project_audit_ci",
        tags=["citrine", "audit", "ci"],
        llm_span_context=LlmSpanContext(
            metrics=[AnswerRelevancyMetric()],
            expected_output=golden.expected_output,
            context=[project_context],
        ),
    ):
        client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Audit this Flutter project. Prioritize concrete findings, "
                        "reference files, and avoid inventing facts."
                    ),
                },
                {"role": "user", "content": project_context},
            ],
        )

    assert_test(golden=golden)
