# OpenAI and deepeval audit harness

This project keeps OpenAI evaluation code outside the Flutter runtime in `evals/`.
The harness uses `deepeval.openai.OpenAI` as a drop-in OpenAI client so each
`client.chat.completions.create(...)` call becomes a traced LLM span.

## Install

```bash
python -m pip install -r evals/requirements.txt
```

Set `OPENAI_API_KEY` before running the audit.

## Run a traced audit script

```bash
python evals/openai_project_audit.py --model gpt-4o
```

The script writes the model's audit to `audit/openai_project_audit.md` and
attaches `AnswerRelevancyMetric` to the OpenAI LLM span.

## Run as a CI/CD eval gate

```bash
deepeval test run evals/test_openai_project_audit.py
```

The CI eval collects bounded Flutter project context, asks OpenAI for a project
audit, and asserts that the generated audit is relevant to the expected audit
shape. Use this alongside the native gates:

```bash
flutter analyze
flutter test
```

## What is traced

- The OpenAI audit call is captured as one LLM span.
- The span includes input context, model output, and the `AnswerRelevancyMetric`.
- The trace is tagged with `citrine`, `audit`, and either `openai` or `ci`.
