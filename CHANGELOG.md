# Changelog

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
