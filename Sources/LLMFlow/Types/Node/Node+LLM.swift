//
//  Node+LLM.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//
//
//

/// A node that invokes a Large Language Model (LLM) using a declarative request.
///
/// ``request`` will be rendered as ``swift-gpt/GPT/Prompt``, and than perform request.
/// When an ``output`` is provided, the node may persist its result
/// back into the context.
/// Its ``NodeType`` is `.LLM`.
public struct LLMNode: ResultResaveableNode {
    /// Stable node identifier used for graph wiring and result addressing.
    public let id: ID

    /// Optional human-readable name for display/debugging purposes.
    public let name: String?

    /// The node kind, always `.LLM` for this type.
    public let type: NodeType

    /// Provider/model identifier used to resolve the underlying model client.
    ///
    /// Examples: `"openai:gpt-4o"`, `"openrouter:meta-llama-3.1"`, etc.
    public let modelName: String

    /// Optional context key under which the node's result will be saved.
    ///
    /// If `nil`, the result is only available via the node's run result (see
    /// ``Node/resultKeyPaths``). When set, the value is stored using the output path
    /// determined by ``ResultResaveableNode/outputKeyPaths``.
    public let output: String?

    /// Declarative request body for the model call.
    ///
    /// The payload supports references and templates that are rendered with the
    /// workflow context at runtime. See ``ModelDecl`` and ``ModelDeclKey``.
    public let request: ModelDecl

    /// Creates an `LLMNode`.
    ///
    /// - Parameters:
    ///   - id: Stable node identifier.
    ///   - name: Optional display name.
    ///   - modelName: Provider/model identifier (e.g., `"openai:gpt-4o"`).
    ///   - output: Optional context key where the result should be saved.
    ///   - request: Declarative request payload that will be rendered using the context.
    /// - Note: `type` is set to `.LLM`.
    public init(
        id: ID,
        name: String?,
        modelName: String,
        output: String?,
        request: ModelDecl
    ) {
        self.id = id
        self.name = name
        self.type = .LLM
        self.modelName = modelName
        self.output = output
        self.request = request
    }
}
