// The Swift Programming Language
// https://docs.swift.org/swift-book
import Tracing // API
import Logging // API
import OTel // specific Tracing library
import Instrumentation
import LLMFlow
import GPT
import OpenAPIAsyncHTTPClient
import Foundation
import Configuration

struct APP {
    let logger = Logger(label: "App")
    
    func execute() async throws {
        try await withSpan("App execute") { span in

            let config = ConfigReader(providers: [
                try await EnvironmentVariablesProvider(environmentFilePath: ".env",),
            ])
            
            let openai = LLMProviderConfiguration(type: .OpenAI,
                                                  name: "openai",
                                                  apiKey: config.string(forKey: "OPENAI_API_KEY")!,
                                                  apiURL: "https://api.openai.com/v1")

            let client = AsyncHTTPClientTransport()
            let solver = DummyLLMProviderSolver(
                "gpt-4o-mini",
                .init(name: "gpt-4o-mini", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
            )
            let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

            let outputKey = "ultimate"
            let llmNode  = LLMNode(
                id: UUID().uuidString,
                name: nil,
                modelName: "gpt-4o-mini",
                output: outputKey,
                context: nil,
                request: .init([
                    "stream": false,
                    "instructions": """
                        be an echo server.
                        before response, say 'hi [USER NAME]' first.
                        what I send to you, you send back.

                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """,
                    "inputs": [[
                        "type": "text",
                        "role": "system",
                        "#content": "you are talking to {{workflow.inputs.name}}"
                    ], [
                        "type": "text",
                        "role": "user",
                        "$content": ["workflow", "inputs", "message"],
                    ]]
                ]))

            let endNode = EndNode(id: UUID().uuidString, name: nil)
            let locator = DummySimpleLocater(client, solver)

            let workflow = Workflow(nodes: [
                startNode.id : startNode,
                llmNode.id : llmNode,
                endNode.id : endNode
            ], flows: [
                startNode.id : [.init(from: startNode.id, to: llmNode.id, condition: nil)],
                llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
            ], startNodeID: startNode.id, locator: locator)


            let inputs: [String: FlowData] = [
                "name": "John",
                "message": "ping"
            ]

            let context = Context()
            let states = try workflow.run(inputs: inputs, context: context)
            for try await state in states {
                logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
            }

            print(context.store.withLock({ $0 }))
            let response = context["workflow.output.\(outputKey).items.0.content.0.content"] as? String
            print(response ?? "nil")
        }
    }
}

@main
struct simple_cli_with_otel {
    static func main() async throws {
        // Bootstrap observability backends.
        var config = OTel.Configuration.default
        config.serviceName = "workflow-example-with-otel"
        config.diagnosticLogLevel = .info
        config.logs.enabled = true
        config.logs.exporter = .console
        config.logs.batchLogRecordProcessor.scheduleDelay = .seconds(1)
        config.metrics.enabled = true
        config.metrics.exportInterval = .seconds(1)
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(1)
        config.traces.otlpExporter.endpoint = "http://localhost:4318/v1/traces"
        let observability = try OTel.bootstrap(configuration: config)

        let app = APP()
        
        // Run the observability background tasks, alongside your application logic.
        try await withThrowingTaskGroup { group in
            group.addTask {
                do {
                    try await observability.run()
                } catch {
                    print("\(error)")
                }
            }
            group.addTask { try await app.execute() }
            
            try await Task.sleep(nanoseconds: 3 * 1_000_000_000)

            try await group.next()
            group.cancelAll()
            try await group.waitForAll()
        }
    }
}
