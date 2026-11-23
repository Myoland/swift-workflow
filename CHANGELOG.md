# Changelog

## 0.9.1 (2026-11-23)

Backport of the 0.10.2 validation API and of the 0.10.1 and 0.10.2 crash fixes to the 0.9 line. Dependencies are unchanged (swift-gpt 0.9.x).

Bug Fix:

- Decoding a START input type that is not supported (for example `Bool` or `string`) throws `DecodingError` instead of crashing the process (0.10.1).
- A `$` reference in an LLM request, or an edge condition variable, that indexes past the end of a list (or uses a negative index) crashed the process. Rendering the request now throws `DecodingError.dataCorrupted` (coding path = the field, underlying error `ContextStorePath.IndexOutOfRangeError`); the engine throws `ContextStorePath.IndexOutOfRangeError` when it evaluates such a condition. Out-of-range lookups through `Context` subscripts return `nil`.

Feature enhancements:

- Add `Workflow.Config.validate() -> [WorkflowProblem]`: START input types, unique ids, one START, at least one END, edges between existing nodes, no cycles, every node reachable from START, no node without exit, no dead end (only conditional edges, none sure to hold), no edges out of END. Each problem has a stable rule id (`lint.*`), a message and a path such as `nodes[2]` or `edges[3].to`.
- Add `Workflow.Config.runPaths(limit:)` (default limit 256) and `Workflow.Config.evaluatedEdges(from:)`: the paths the engine can take, following its first-matching-edge rule, for dry runs.
- Add `Condition.evaluate(_:) throws`, `Condition.constantValue` and `Condition.isExhaustive(_:)`.

Behavior changes:

- `Workflow(config:locator:logger:)` does not call `validate()`: configurations that built before still build.
- `Condition.eval(_:)` returns `false` when a variable indexes past the end of a list, instead of crashing.

## 0.9.0 (2026-04-15)

Feature enhancements:

- Bump swift-gpt to 0.9.0  

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
