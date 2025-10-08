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

### Why Perfer YAML ?

- **Configuration-Driven Evolution**: Update workflows without changing or redeploying code. You can roll out new prompts, templates, or conditional paths simply by shipping a new YAML file.
- **Operational Safety**: Treat your workflow's YAML as a configuration file. This means you can version it, review it, and run it through a CI/CD pipeline. Use canary deployments, feature flags, and rollbacks just as you would with any other configuration change.
- **Environment-Specific Overrides**: Maintain the same application code across `development`, `staging`, and `production` environments while swapping out the YAML file to adjust models, prompts, or node connections.
- **Faster Iteration with Reduced Redeploys**: Product and operations teams can adjust workflows (e.g., prompt instructions, model selection, stream flags) without needing to rebuild or redeploy the entire service.
- **Clear Separation of Concerns**: Keep your business logic in the workflow (YAML) and the infrastructure/runtime logic in your application code. This allows engineers to focus on system reliability while domain experts can fine-tune the workflows.
- **Testability**: You can snapshot and test YAML configurations in isolation. You can also run integration tests against specific workflow files (like the one shown in the example) to guard against regressions.
- **Multitenancy and Per-Tenant Customizations**: Load different YAML files dynamically for each customer or tenant to provide tailored behavior using the same backend binary.
