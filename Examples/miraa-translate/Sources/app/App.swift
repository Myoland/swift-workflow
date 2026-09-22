import Foundation
import GPT
import LazyKit
import LLMFlow
import Logging
import OpenAPIAsyncHTTPClient
import SynchronizationKit
import SwiftDotenv

struct APP {
    let logger = Logger(label: "App")
    
    /// The workflow of `MyoTranslateService.translateWithWorkflow(userRequest:userID:)`.
    func buildWorkflow(locator: ServiceLocator) -> Workflow {
        let startNode = StartNode(id: "start_id", name: nil, inputs: [
            "query": .single(.string),
            "from": .single(.string),
            "to": .single(.string),
            "summary": .single(.string),
            "model": .single(.string),
        ])

        let summaryNode = TemplateNode(id: "summary_id", name: nil, template: .init(content: """
        {% if workflow.inputs.summary is not none and workflow.inputs.summary|length > 1 %}
        Previous Context Summary:
        <summary>
        {{ workflow.inputs.summary }}
        </summary>
        {% endif %}

        """))

        let templateNode = TemplateNode(id: "template_id", name: nil, template: .init(content: """
        # Role
        You are an expert translator for language learners. Your translations are accurate, natural, and tone-appropriate.

        # Task
        Translate the numbered conversation lines into the target language requested by the user.

        # Rules
        1. Output a numbered list in the format `id. translated_text`. Keep every ID unchanged, in order, none skipped.
        2. One input line = one output line. Never merge or split lines.
        3. Treat broken fragments as transcription errors and infer from context. Drop gibberish. No meta-talk.
        4. Sound like a native speaker. Keep all information, omit nothing, censor nothing.
        5. Translate fully into the target language, following the requested script and variant.

        # Examples

        <example>
        INPUT:
        Translate the following lines into target language Korean:
        283.but now you must like
        285.like almost as high as your head

        OUTPUT:
        283.하지만 이제는 예를 들면
        285.거의 네 머리 높이만큼 되는 것들 말이야.
        </example>

        <example>
        INPUT:
        Translate the following lines into target language Japanese:
        838.说实话是这样的

        OUTPUT:
        838.実際のところ
        </example>

        """))

        let translationNode = LLMNode(
            id: "translation_llm",
            name: nil,
            modelName: "miraa-translate-model",
            timeout: 15,
            output: "tranlsation_result",
            context: nil,
            request: .init([
                "stream": false,
                "temperature": "0.0", // FlowData has no Double; same as what the YAML decodes to.
                "maxTokens": 1024,
                "extraBody": [
                    "caching": ["type": "enabled"],
                    "thinking": ["type": "disabled"],
                ],
                "context": [
                    "cachingPrefixLength" : 1
                ],
                "inputs": [[
                    "type": "text",
                    "role": "system",
                    "#content": "{{ template_id.output }}\n",
                ], [
                    "type": "text",
                    "role": "user",
                    "#content": "{{ summary_id.output }}\n",
                ], [
                    "type": "text",
                    "role": "user",
                    "#content": """
                    Translate the following lines into target language {{ workflow.inputs.to }}:
                    {{ workflow.inputs.query }}

                    """,
                ], [
                    "type": "text",
                    "role": "assistant",
                    "#content": "OK, I will translate the provided lines into {{ workflow.inputs.to }}.\n",
                ]],
            ])
        )

        let endNode = EndNode(id: "end_id", name: nil)

        return Workflow(nodes: [
            startNode.id: startNode,
            summaryNode.id: summaryNode,
            templateNode.id: templateNode,
            translationNode.id: translationNode,
            endNode.id: endNode,
        ], flows: [
            startNode.id: [
                .init(from: startNode.id, to: summaryNode.id, condition: nil),
            ],
            summaryNode.id: [
                .init(from: summaryNode.id, to: templateNode.id, condition: nil),
            ],
            templateNode.id: [
                .init(from: templateNode.id, to: translationNode.id, condition: nil),
            ],
            translationNode.id: [
                .init(from: translationNode.id, to: endNode.id, condition: nil),
            ],
        ], startNodeID: startNode.id, locator: locator, logger: logger)
    }

    func execute() async throws {
        try Dotenv.configure()
        
        let model = LLMModelReference(
            model: .init(name: "seed-2-0-mini-260428"),
            provider: .init(
                type: .OpenAI,
                name: "Ark",
                apiKey: Dotenv["ARK_API_KEY"]!.stringValue,
                apiURL: "https://ark.ap-southeast.bytepluses.com/api/v3"
            )
        )

        let solver = DummyLLMProviderSolver(
            "miraa-translate-model",
            .init(name: "miraa-translate-model", models: [model])
        )

        let client = AsyncHTTPClientTransport(configuration: .init(timeout: .seconds(15)))
        let cache = ConversationCache()
        
        let locator = DummySimpleLocater(client, solver, cache)
        let workflow = buildWorkflow(locator: locator)
        
        try await mockUserRequestOnce(workflow: workflow)
        try await mockUserRequestOnce(workflow: workflow)
    }
    
    func mockUserRequestOnce(workflow: Workflow) async throws {
        let inputs: [String: FlowData] = [
            "query": """
            1.说实话是这样的
            2.我昨天本来想早点睡
            3.结果刷手机刷到了两点
            """,
            "from": "",
            "summary": "",
            "to": "English",
            "model": "",
        ]
        
        let states = try workflow.run(inputs: inputs, context: Context(), serviceContext: .topLevel)
        for try await state in states {
            logger.info("[*] State: \(state.node.type.rawValue) \(state.node.id) \(state.type)")
        }
        
        guard let nodeResult = states.context["workflow.output.tranlsation_result"] else {
            fatalError("Translation workflow failed to produce result")
        }
        
        let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
        if let usage = response.usage {
            logger.info("[*] Token usage: \(usage)")
        }
    }
}

@main
struct miraa_translate {
    static func main() async throws {
        try await APP().execute()
    }
}

/// Keyed by the prefix hash, so that runs without a conversation ID share the stored prefix.
public final class ConversationCache: Sendable, GPTConversationCache {
    let lockedReference = LazyLockedValue<[String: Conversation.PrefixCacheReference]>([:])

    public func get(conversationID: String?, prompt: Prompt) async throws -> Conversation? {
        guard let hash = prompt.prefixCacheHashValue else {
            return nil
        }
        return lockedReference.withLock { $0[hash] }.map { Conversation(prefixCacheReference: $0) }
    }

    public func update(conversationID: String?, conversation: Conversation?) async throws -> String? {
        guard let reference = conversation?.prefixCacheReference else {
            return nil
        }
        lockedReference.withLock { $0[reference.prefixHashValue] = reference }
        return reference.prefixHashValue
    }
}
