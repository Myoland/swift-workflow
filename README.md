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