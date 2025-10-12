// The Swift Programming Language
// https://docs.swift.org/swift-book
import Configuration
import Foundation
import GPT
import Instrumentation
import LLMFlow
import Logging // API
import OpenAPIAsyncHTTPClient
import OTel // specific Tracing library
import Tracing // API

struct APP {
    let logger = Logger(label: "App")

    func execute() async throws {
        let span = startSpan("App App")

        try await withSpan("App Execute", context: span.context) { span in
            let config = try ConfigReader(providers: [
                await EnvironmentVariablesProvider(environmentFilePath: ".env"),
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

            let templateID = UUID().uuidString
            let templateNode = TemplateNode(id: templateID, name: nil, template: .init(content: """
                be an echo server.
                before response, say 'hi [USER NAME]' first.
                what I send to you, you send back.

                the exceptions:
                1. send "ping", back "pong"
                2. send "ding", back "dang"
            """))

            let outputKey = "ultimate"
            let llmNode = LLMNode(
                id: UUID().uuidString,
                name: nil,
                modelName: "gpt-4o-mini",
                output: outputKey,
                context: nil,
                request: .init([
                    "stream": true,
                    "#instructions": .init(stringLiteral: "\(templateID).output"),
                    "inputs": [[
                        "type": "text",
                        "role": "system",
                        "#content": "you are talking to {{workflow.inputs.name}}",
                    ], [
                        "type": "text",
                        "role": "user",
                        "$content": ["workflow", "inputs", "message"],
                    ]],
                ])
            )

            let endNode = EndNode(id: UUID().uuidString, name: nil)
            let locator = DummySimpleLocater(client, solver)

            let workflow = Workflow(nodes: [
                startNode.id: startNode,
                llmNode.id: llmNode,
                endNode.id: endNode,
                templateID: templateNode,
            ], flows: [
                startNode.id: [.init(from: startNode.id, to: templateID, condition: nil)],
                templateID: [.init(from: templateID, to: llmNode.id, condition: nil)],
                llmNode.id: [.init(from: llmNode.id, to: endNode.id, condition: nil)],
            ], startNodeID: startNode.id, locator: locator)

            let inputs: [String: FlowData] = [
                "name": "John",
                "message": "ping",
            ]

            let context = Context()
            let states = try workflow.run(inputs: inputs, context: context, serviceContext: span.context)
            for try await state in states {
                logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
            }

            print(context.store.withLock { $0 })
            let response = context["workflow.output.\(outputKey).items.0.content.0.content"] as? String
            print(response ?? "nil")
        }

        span.end()
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
        config.logs.batchLogRecordProcessor.scheduleDelay = .milliseconds(50)
        config.metrics.enabled = true
        config.metrics.exportInterval = .seconds(1)
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(1)
        config.traces.otlpExporter.timeout = .seconds(10)
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

            try await group.next()
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

            group.cancelAll()
            try await group.waitForAll()
        }
    }
}
