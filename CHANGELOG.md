# Changelog

## 0.8.0 (2026-04-08)

Feature enhancements:

- Add `timeout` support for generating block response on LLM Node via `swift-gpt` 0.8.0

## 0.7.1 (2026-03-05)

Bug Fix:

- LLM Node will generate duplicate delta text. Fixed via `swift-gpt` 0.7.2

## 0.7.0 (2026-03-04)

Feature enhancements:

- Add Gemini suppoet via `swift-gpt` 0.7.0

## 0.6.0 (2025-11-04)

Feature enhancements:

- `LLMNode` add Image input support and `ExtraBody` support via `swift-gpt` 0.6.0

## 0.5.0 (2025-10-19)

Feature enhancements:

- Add tracing support via `swift-distributed-tracing`.
- Add `simple-cli-with-otel` Example.

## 0.4.0 (2025-10-12)

Feature enhancements:

- `LLMNode` add conversation id support.

Performance improvements:

- Upgrade `Jinja` to 0.2.0

## 0.3.2 (2025-10-06)

Feature enhancements:

- Extend `GPTConversationCache` with context support by declaring required keys in `LLMNode`.

## 0.3.1 (2025-10-04)


Feature enhancements:

- Make `GPTConversationCache` Async

## 0.3.0 (2025-10-04)

Bug Fix:

- fix `LLMNode` may produce wrong event type by upgrade `swift-gpt` to 0.3.0

## 0.2.0 (2025-10-04)

BREAK CHANGES:

- Remove `WorkflowNodeRunResultKey` and using `WorkflowNodeRunOutputKey` instead.

Feature enhancements:

- `LLMNode` Add Conversation Support with `GPTConversationCache` protocol
