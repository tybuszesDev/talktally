# ADR-0030: Extraction model Amazon Nova Pro with a forced tool call

- Status: Accepted
- Date: 2026-11-16
- Amends: [ADR-0008](0008-ai-proposes-changes-code-applies-them.md) (model access, structured outputs, auto-apply at launch) and [ADR-0002](0002-serverless-aws-and-cost-guardrails.md) (the AI service row and the model access check)

## Context

ADR-0008 planned Claude Opus 5.5 on Amazon Bedrock, called through the Anthropic Bedrock SDK, with structured outputs forcing the response into the change set schema. The F-14 spike ([results](../spikes/F-14-transcribe-and-bedrock.md)) found:

- **Claude is not available to this account.** Every Anthropic model returns `AccessDeniedException: ... is not available for this account`, on the Free plan and on the Paid plan. So do the OpenAI GPT-5 and GPT-6 models, Grok and GLM-5.3. The message points to AWS Sales.
- **Ten available models were compared** on three real Polish dictations with the same prompt and a forced tool call. None is reliable enough to apply changes without review: the best found about three quarters of the expected facts, and every model gave confidence 0.8–0.95 to some wrong operations.
- **Amazon Nova Pro** had the highest share of found facts (74% over five runs) and 3% invalid operations; MiniMax M2.5 had none, but took up to four minutes per dictation. Nova Pro was the fastest of the five strongest models (7.9 s mean); smaller models with lower recall answered in 4–5 s. It costs about 0.008 USD per dictation in `eu-central-1`. Its Polish titles contain occasional errors; Polish is not among the 15 languages Amazon Nova is optimized for ([What is Amazon Nova](https://docs.aws.amazon.com/nova/latest/userguide/what-is-nova.html)).
- **Qwen3 235B** came second (71%), at a quarter of the cost and with better Polish, but recorded the day's panel area for the tiles metric as well in five of five runs, with confidence 0.95.
- **Nova Pro does not support structured outputs** on bedrock-runtime ([Nova Pro model card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-nova-pro.html)). It supports tool use with `toolChoice` `tool`, `any` and `auto` ([Nova tool choice](https://docs.aws.amazon.com/nova/latest/userguide/tool-choice.html)); every tested model accepted the forced tool call.
- **Nova Pro runs in `eu-central-1` only through the EU geographic inference profile** `eu.amazon.nova-pro-v1:0`, which routes requests to eu-central-1, eu-north-1, eu-west-1 and eu-west-3. Its maximum output is 10,000 tokens. The model card lists "EOL no sooner than" December 2025; the model is still `ACTIVE` with no end-of-life date.

## Decision

- **Model.** Extraction uses Amazon Nova Pro through the inference profile `eu.amazon.nova-pro-v1:0`. The model ID stays in Parameter Store per environment (ADR-0008).
- **API.** The extraction Lambda calls the Bedrock Runtime Converse API with the AWS SDK for JavaScript v3 (`@aws-sdk/client-bedrock-runtime`), not the Anthropic Bedrock SDK.
- **Forced tool call instead of structured outputs.** The request defines one tool, `propose_change_set`, whose input schema is generated from the Zod change set schema, and sets `toolChoice: { tool: { name: "propose_change_set" } }`.
  - The step succeeds only when `stopReason` is `tool_use` and the response contains that tool call. Any other stop reason, including `max_tokens`, fails the step.
  - The tool input is validated with the Zod schema. Invalid output fails the step and is never repaired (ADR-0008).
  - `maxTokens` stays below the model's limit (10,000 for Nova Pro).
- **No auto-apply at launch.** Until the evaluation set (F-45) shows at which confidence each operation type is correct often enough, every operation is stored as `PENDING`: the auto-apply allowlist starts empty. The F-45 report sets the allowlist and the default threshold; the mechanism from ADR-0008 stays unchanged.
- **Prompt.** The spike's prompt v2 is the starting point for prompt v1 in F-44: English instructions, the transcript in `<transcript>` tags as data, Polish titles and questions.
- **Ask instead of guessing.** Different people describe the same work in different ways, so when a statement can mean more than one change (for example material carried from the car against material used), the model adds a clarification instead of choosing. The mobile app shows these questions right after processing (F-46). The F-45 evaluation set includes such statements and measures whether the model asks.
- **Changing the model** (for example to Claude, if AWS grants access, or to a Nova successor) requires a run of the F-45 evaluation set with both models and a new ADR. When AWS announces an end-of-life date for Nova Pro, the successor is evaluated before the legacy period ends.

## Consequences

- Extraction works today, inside the EU and on AWS only, for about 0.008 USD per dictation; one dictation a day costs about 0.25 USD a month.
- The user reviews every proposal at first. TalkTally saves typing, not decisions, until the evaluation set justifies auto-apply.
- Without structured outputs the model can return output that does not match the schema; such entries fail and can be retried. The step's failure rate must be watched (ADR-0015).
- Titles may contain Polish errors, so the review screens must let the user edit titles before confirming (F-46, F-47).
- The Converse API is the same for all Bedrock models, so changing the model later does not change the calling code.
- F-44 is described with a forced tool call instead of structured outputs.

## Alternatives considered

- **Claude Opus 5.5 (ADR-0008):** the planned model, but denied for this account. An access request to AWS is a follow-up; switching needs an evaluation and a new ADR.
- **Qwen3 235B:** a quarter of the cost, runs in Frankfurt, better Polish; more invalid operations and a repeated metric misattribution with high confidence.
- **gpt-oss-120b:** the only model that regularly asked clarification questions, but lower recall and unstable results between runs.
- **MiniMax M2.5:** no invalid operations, but latency up to four minutes.
- **Amazon Nova 2 Lite:** lower recall and 23% invalid operations; with reasoning effort `medium` it used the whole output budget on reasoning.
- **Global inference profiles:** sometimes cheaper, but requests may leave the EU; no available model on a global profile performed better.
