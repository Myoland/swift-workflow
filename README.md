# LLMFlow

LLMFlow is a Swift package for creating, configuring, and running powerful, flexible workflows that leverage large language models (LLMs). It provides a declarative, node-based architecture for defining complex flows, managing data, and handling conditional logic.

## Features

- **Declarative Workflows**: Define complex execution graphs using a simple, serializable configuration (`YAML`).
- **Node-Based Architecture**: Build workflows from different node types:
    - `StartNode`: The entry point of a workflow.
    - `LLMNode`: Interface with LLM providers like OpenAI.
    - `TemplateNode`: Process inputs using Jinja-style templates.
    - `EndNode`: The termination point of a workflow path.
- **Conditional Logic**: Use `Condition` objects on edges to control the flow based on runtime data.
- **Type-Safe Data Flow**: Manage data within a thread-safe `Context` using the `FlowData` type, which supports primitive values, lists, and maps.
- **Asynchronous Execution**: Workflows run asynchronously, providing a stream of real-time state updates.
- **Extensible**: Easily create custom nodes and services.

## Installation

Add LLMFlow as a dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Myoland/swift-workflow", from: "0.1.0") // Replace with the desired version
]
```

## Quick Start

Here is a conceptual example of how to build and run a simple workflow programmatically.

```swift
import LLMFlow

// 1. Define the nodes
let startNode = StartNode(id: "start")
let llmNode = LLMNode(id: "llm", model: .init(provider: .openAI(.gpt4))) // Requires a configured service locator
let endNode = EndNode(id: "end")

// 2. Define the edges connecting the nodes
let edges = [
    Workflow.Edge(from: startNode.id, to: llmNode.id, condition: nil),
    Workflow.Edge(from: llmNode.id, to: endNode.id, condition: nil)
]

let allNodes: [String: any RunnableNode] = [
    startNode.id: startNode,
    llmNode.id: llmNode,
    endNode.id: endNode
]

// 3. Group edges by their source node
let flows: [String: [Workflow.Edge]] = Dictionary(grouping: edges, by: { $0.from })

// 4. Create the workflow
// `myServiceLocator` should be an implementation of `ServiceLocator` that can provide an OpenAI client.
let workflow = Workflow(
    nodes: allNodes,
    flows: flows,
    startNodeID: startNode.id,
    locator: myServiceLocator
)

// 5. Run the workflow and handle updates
Task {
    do {
        let inputs: [String: FlowData] = ["query": "Tell me a short story about a robot."]
        let updates = try workflow.run(inputs: inputs)

        for try await state in updates {
            print("Node '\(state.node.id)' changed to state: \(state.type)")
            if state.type == .generating, let chunk = state.value as? String {
                print("Stream chunk: \(chunk)")
            }
        }
        print("Workflow finished.")
    } catch {
        print("Workflow failed: \(error)")
    }
}
```

## Build a Workflow from YAML

You can define a workflow declaratively in YAML and build it at runtime. This is especially useful when you want to ship your app once and evolve flows via configuration.

Example YAML (excerpt from `Tests/LLMFlowIntegrationTests/Resources/testWorkflowRunWithYaml.yaml`):
```yaml
nodes:
  - id: start_id
    type: START
    inputs:
      message: String
      name: String
      langauge: String

  - id: template_id
    type: TEMPLATE
    template: >
      {% if workflow.inputs.langauge == "zh-Hans" %}简体中文{% elif workflow.inputs.langauge == "zh-Hant" or workflow.inputs.langauge == "zh" %}繁體中文{% elif  workflow.inputs.langauge == "ja"%}日本語{% elif  workflow.inputs.langauge == "vi"%}Tiếng Việt{% elif  workflow.inputs.langauge == "ko"%}한국어{% else %}English{% endif %}

  - id: llm_id
    type: LLM
    modelName: test_openai
    request:
      stream: true
      instructions: >
        be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \"ping\", back \"pong\"\n2. send \"ding\", back \"dang\"
      inputs:
        - type: text
          role: user
          "#content": "you are talking to {{workflow.inputs.name}} in {{ template_id.output }}"
        - type: text
          role: assistant
          "#content": "OK"
        - type: text
          role: user
          $content:
            - workflow
            - inputs
            - message

edges:
  - from: start_id
    to: template_id
  - from: template_id
    to: llm_id
  - from: llm_id
    to: end_id
```

Build and run from YAML:
```swift
import Foundation
import LLMFlow

// Assume myServiceLocator is a configured ServiceLocator instance
// Assume the YAML file is in the project bundle
guard let yamlURL = Bundle.main.url(forResource: "testWorkflowRunWithYaml", withExtension: "yaml") else {
    fatalError("YAML file not found.")
}
let yamlData = try Data(contentsOf: yamlURL)

// 1. Parse YAML into a Workflow.Config object
// Note: This requires a YAML parsing library like Yams.
let config = try Workflow.Config(from: yamlData)

// 2. Build the workflow from the configuration
let workflow = try Workflow.build(from: config, locator: myServiceLocator)

// 3. Define runtime inputs for the workflow
let inputs: [String: FlowData] = [
    "message": "ping",
    "name": "Taylor",
    "langauge": "en"
]

// 4. Run the workflow and handle state updates
let updates = try workflow.run(inputs: inputs)

for try await state in updates {
    print("Node '\(state.node.id)' changed to state: \(state.type)")
    if state.type == .generating, let chunk = state.value as? String {
        print("Stream chunk: \(chunk)")
    }
}
print("Workflow finished.")
```

### Validate YAML with the JSON Schema

`schema/workflow.schema.json` (JSON Schema draft 2020-12) describes the YAML that `Workflow.Config` decodes: node types and their fields, START input types, LLM request keys (`$` references, `#` templates), and `extraBody` key names that look like credentials (rejected). Check a workflow before shipping it:

```bash
check-jsonschema --schemafile schema/workflow.schema.json path/to/workflow.yaml
```

The schema checks structure only; `Workflow.Config.validate()` (below) checks the graph. Jinja template compilation must be checked by the application. Fixtures live in `Tests/Fixtures/WorkflowSchema`; `schema/check-fixtures.sh` runs them.

### Validate a Workflow.Config

`validate()` reports what makes a run fail, or what the engine never runs, without running anything:

```swift
let config = try YAMLDecoder().decode(Workflow.Config.self, from: yaml)
for problem in config.validate() {
    print(problem.rule, problem.path, problem.message) // e.g. lint.dead-end nodes[0] …
}
```

| Rule | Path | Meaning |
| --- | --- | --- |
| `lint.type-decl` | `nodes[i].inputs.<key>` | A START input type a workflow file cannot declare (only `String`, `Int`, `Any`, `[T]`, `[String: T]`, whole value). |
| `lint.duplicate-id` | `nodes[i].id` | Two nodes share an id. |
| `lint.start` | `nodes` / `nodes[i]` | No START node, or more than one. |
| `lint.end` | `nodes` | No END node. |
| `lint.edge` | `edges[j].from` / `edges[j].to` | The edge references a node that does not exist. |
| `lint.cycle` | `edges[j]` | The edges form a cycle (`edges[j]` closes it). |
| `lint.unreachable` | `nodes[i]` | No chain of edges from START reaches the node. |
| `lint.end-edges` | `edges[j]` | An edge out of END: the run ends at END and never takes it. |
| `lint.no-exit` | `nodes[i]` | A node other than END without outgoing edges. |
| `lint.dead-end` | `nodes[i]` | All outgoing edges have a condition and none is sure to hold (no edge without a condition, no condition that always holds such as `and: []`, no pair `C` / `not: C`). |

`Workflow(config:locator:)` does not call `validate()`, so existing configurations keep building.

For dry runs, `runPaths(context:limit:)` lists the paths the engine can take, as node and edge indices. The engine takes the first outgoing edge (in file order) whose condition holds, so edges after an edge without a condition (or after `C` and `not: C`) are never taken, and an edge whose condition never holds (`or: []`) is skipped. A condition evaluated again on the same path, on values no node has written since, gives the same result, and conditions on values in `context` (for example the caller's sample inputs) are evaluated: those follow the one edge the engine takes. Conditions on unknown values (for example an LLM answer) branch both ways, a conservative over-approximation. A path ends at END. Run each path in its own `Context` to find values that only another branch produces:

```swift
let sample: Context.Store = ["workflow": ["inputs": ["query": "hello"]]]
let result = config.runPaths(context: sample) // at most Workflow.Config.defaultRunPathLimit (256) paths
if !result.isComplete { /* truncated: more paths than the limit */ }
for path in result.paths {
    let nodes = path.nodeIndices.map { config.nodes[$0] }
    // path.edgeIndices[k] leads from nodes[k] to nodes[k + 1]
}
```

`evaluatedEdges(from:)` returns the edges the engine may evaluate after a node; `Condition.constantValue` and `Condition.isExhaustive(_:)` are the checks behind `lint.dead-end`.

A `$` reference or an edge condition that indexes past the end of a list (`workflow.inputs.items.5` on a two-element list, or a negative index) throws: `ModelDecl.render(_:)` throws `DecodingError.dataCorrupted` at the field, `Condition.evaluate(_:)` and the engine throw `ContextStorePath.IndexOutOfRangeError`. `Condition.eval(_:)` returns `false`.

### Why Perfer YAML ?

- **Configuration-Driven Evolution**: Update workflows without changing or redeploying code. You can roll out new prompts, templates, or conditional paths simply by shipping a new YAML file.
- **Operational Safety**: Treat your workflow's YAML as a configuration file. This means you can version it, review it, and run it through a CI/CD pipeline. Use canary deployments, feature flags, and rollbacks just as you would with any other configuration change.
- **Environment-Specific Overrides**: Maintain the same application code across `development`, `staging`, and `production` environments while swapping out the YAML file to adjust models, prompts, or node connections.
- **Faster Iteration with Reduced Redeploys**: Product and operations teams can adjust workflows (e.g., prompt instructions, model selection, stream flags) without needing to rebuild or redeploy the entire service.
- **Clear Separation of Concerns**: Keep your business logic in the workflow (YAML) and the infrastructure/runtime logic in your application code. This allows engineers to focus on system reliability while domain experts can fine-tune the workflows.
- **Testability**: You can snapshot and test YAML configurations in isolation. You can also run integration tests against specific workflow files (like the one shown in the example) to guard against regressions.
- **Multitenancy and Per-Tenant Customizations**: Load different YAML files dynamically for each customer or tenant to provide tailored behavior using the same backend binary.
