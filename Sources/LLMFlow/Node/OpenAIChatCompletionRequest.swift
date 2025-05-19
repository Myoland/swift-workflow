//
//  OpenAIChatCompletionRequest.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/18.
//

import Foundation
import DynamicJSON

/// Represents the request body for creating a chat completion.
public struct OpenAIChatCompletionRequest: Codable {
    
    /// A list of messages comprising the conversation so far.
    public let messages: [OpenAIChatCompletionRequestMessage]
    
    /// Model ID used to generate the response.
    public let model: String // TODO: using enum
    
    /// Parameters for audio output. Required when audio output is requested.
    public let audio: OpenAIChatCompletionRequestAudioOutput?
    
    /// Defaults to 0. Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency.
    public let frequencyPenalty: Double?
    
    /// Modify the likelihood of specified tokens appearing in the completion. Maps token IDs (strings) to bias values (-100 to 100).
    public let logitBias: [String: Int]? // WTF?
    
    /// Defaults to false. Whether to return log probabilities of the output tokens.
    public let logprobs: Bool?
    
    /// An upper bound for the number of tokens that can be generated for a completion.
    public let maxCompletionTokens: Int?
    
    /// Set of 16 key-value pairs that can be attached to the object.
    public let metadata: [String: String]?
    
    /// Output types requested (e.g., ["text", "audio"]). Defaults to ["text"].
    public let modalities: [String]?
    
    /// How many chat completion choices to generate for each input message. Defaults to 1.
    public let n: Int?
    
    /// Whether to enable parallel function calling. Defaults to true.
    public let parallelToolCalls: Bool?
    
    /// Configuration for a Predicted Output to improve response times.
    public let prediction: OpenAIChatCompletionRequestPrediction?
    
    /// Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far.
    public let presencePenalty: Double?
    
    /// Constrains effort on reasoning for o-series models. (low, medium, high). Defaults to medium.
    public let reasoningEffort: OpenAIChatCompletionRequestReasoningEffort?
    
    /// An object specifying the format that the model must output.
    public let responseFormat: OpenAIChatCompletionRequestResponseFormat?
    
    /// If specified, attempts to sample deterministically.
    public let seed: Int?
    
    /// Latency tier to use for processing the request (auto, default).
    public let serviceTier: OpenAIChatCompletionRequestServiceTier?
    
    /// Up to 4 sequences where the API will stop generating further tokens. Can be a single string or an array of strings.
    public let stop: String?
    
    /// Whether to store the output for model distillation or evals. Defaults to false.
    public let store: Bool?
    
    /// If set to true, streams response data using server-sent events. Defaults to false.
    public let stream: Bool?
    
    /// Options for streaming response. Only set when stream is true.
    public let streamOptions: OpenAIChatCompletionRequestStreamOptions?
    
    /// Sampling temperature (0 to 2). Higher values = more random, lower = more focused. Defaults to 1.
    public let temperature: Double?
    
    /// Controls which (if any) tool is called by the model.
    public let toolChoice: OpenAIChatCompletionRequestToolChoice?
    
    /// A list of tools the model may call. Currently, only functions are supported.
    public let tools: [OpenAIChatCompletionRequestTool]?
    
    /// Number of most likely tokens to return at each position (0-20). Requires logprobs=true.
    public let topLogprobs: Int?
    
    /// Nucleus sampling parameter (0 to 1). Considers tokens with top_p probability mass. Defaults to 1.
    public let topP: Double?
    
    /// A unique identifier representing your end-user.
    public let user: String?
    
    /// Options for the web search tool.
    public let webSearchOptions: WebSearchOptions?
    
    // Maps Swift camelCase properties to JSON snake_case keys
    enum CodingKeys: String, CodingKey {
        case messages
        case model
        case audio
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case logprobs
        case maxCompletionTokens = "max_completion_tokens"
        case metadata
        case modalities
        case n
        case parallelToolCalls = "parallel_tool_calls"
        case prediction
        case presencePenalty = "presence_penalty"
        case reasoningEffort = "reasoning_effort"
        case responseFormat = "response_format"
        case seed
        case serviceTier = "service_tier"
        case stop
        case store
        case stream
        case streamOptions = "stream_options"
        case temperature
        case toolChoice = "tool_choice"
        case tools
        case topLogprobs = "top_logprobs"
        case topP = "top_p"
        case user
        case webSearchOptions = "web_search_options"
    }
}

// MARK: - Message Types

/// Represents the role of the message author.
public enum MessageRole: String, Codable {
    case developer
    case system
    case user
    case assistant
    case tool
}

/// Represents a single message in the conversation. Uses an enum to handle different message structures based on role.
public enum OpenAIChatCompletionRequestMessage: Codable {
    case developer(OpenAIChatCompletionRequestDeveloperMessage)
    case system(OpenAIChatCompletionRequestSystemMessage)
    case user(OpenAIChatCompletionRequestUserMessage)
    case assistant(OpenAIChatCompletionRequestAssistantMessage)
    case tool(OpenAIChatCompletionRequestToolMessage)
    
    // Custom Codable implementation to handle the different message types
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(MessageRole.self, forKey: .role)
        
        switch role {
        case .developer:
            self = .developer(try OpenAIChatCompletionRequestDeveloperMessage(from: decoder))
        case .system:
            self = .system(try OpenAIChatCompletionRequestSystemMessage(from: decoder))
        case .user:
            self = .user(try OpenAIChatCompletionRequestUserMessage(from: decoder))
        case .assistant:
            self = .assistant(try OpenAIChatCompletionRequestAssistantMessage(from: decoder))
        case .tool:
            self = .tool(try OpenAIChatCompletionRequestToolMessage(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .developer(let message):
            try container.encode(message)
        case .system(let message):
            try container.encode(message)
        case .user(let message):
            try container.encode(message)
        case .assistant(let message):
            try container.encode(message)
        case .tool(let message):
            try container.encode(message)
        }
    }
    
    // Used internally for decoding based on role
    private enum CodingKeys: String, CodingKey {
        case role
    }
}

// --- Specific Message Structs ---

public struct OpenAIChatCompletionRequestDeveloperMessage: Codable {
    public let role: MessageRole
    public let content: OpenAIChatCompletionRequestMessageContent
    public let name: String?
}

public struct OpenAIChatCompletionRequestSystemMessage: Codable {
    public let role: MessageRole
    public let content: OpenAIChatCompletionRequestMessageContent
    public let name: String?
}

/// Represents content for a user message (either plain text or structured parts).
public enum OpenAIChatCompletionRequestMessageContent: Codable {
    case text(String)
    case parts([OpenAIChatCompletionRequestMessageContentPart])
    
    // Custom Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([OpenAIChatCompletionRequestMessageContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.typeMismatch(OpenAIChatCompletionRequestMessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Content must be a String or an array of ContentPart"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

public struct OpenAIChatCompletionRequestUserMessage: Codable {
    public let role: MessageRole
    public let content: OpenAIChatCompletionRequestMessageContent
    public let name: String?
}

/// Represents content for an assistant message (optional text or refusal)
public enum AssistantMessageContent: Codable {
    case text(String)
    // case parts([AssistantContentPart]) // Doc says array of text or exactly one refusal part
    // Let's simplify based on common usage: Optional text content. Tool calls/function calls handle non-text actions.
    // If refusal part is needed, it might be handled differently (e.g., specific error state).
    // For simplicity, let's assume optional text. If parts are strictly needed, need AssistantContentPart enum.
    
    // Custom Codable to handle optional string content
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Attempt to decode as string, if fails, assume no text content (nil string equivalent)
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            // This handles cases where content might be null or an empty object/array if not text
            // Depending on API behavior, might need refinement
            throw DecodingError.typeMismatch(AssistantMessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String content or structure indicating no text"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        }
    }
}


public struct AssistantAudio: Codable {
    public let id: String
}

public struct OpenAIChatCompletionRequestAssistantMessage: Codable {
    public let role: MessageRole = .assistant
    public let audio: AssistantAudio?
    public let content: OpenAIChatCompletionRequestMessageContent?
    public let name: String?
    public let refusal: String?
    public let tool_calls: [OpenAIChatCompletionRequestAssistantMessageToolCall]?
}

public struct OpenAIChatCompletionRequestToolMessage: Codable {
    public let role: MessageRole = .tool
    public let content: OpenAIChatCompletionRequestMessageContent
    public let toolCallId: String
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
    }
}


// MARK: - Content Parts (for User Messages)

/// Represents different types of content parts within a user message.
public enum OpenAIChatCompletionRequestMessageContentPart: Codable {
    case text(OpenAIChatCompletionRequestMessageContentTextPart)
    case image(OpenAIChatCompletionRequestMessageContentImagePart)
    case audio(OpenAIChatCompletionRequestMessageContentAudioPart)
    case file(OpenAIChatCompletionRequestMessageContentFilePart)
    case refusal(OpenAIChatCompletionRequestMessageContentRefusalPart)
    
    // Custom Codable implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        
        switch type {
        case .text:
            self = .text(try OpenAIChatCompletionRequestMessageContentTextPart(from: decoder))
        case .image_url:
            self = .image(try OpenAIChatCompletionRequestMessageContentImagePart(from: decoder))
        case .input_audio: // Mapped from audio type
            self = .audio(try OpenAIChatCompletionRequestMessageContentAudioPart(from: decoder))
        case .file:
            self = .file(try OpenAIChatCompletionRequestMessageContentFilePart(from: decoder))
        case .refusal:
            self = .refusal(try OpenAIChatCompletionRequestMessageContentRefusalPart(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let part):
            try container.encode(part)
        case .image(let part):
            try container.encode(part)
        case .audio(let part):
            try container.encode(part)
        case .file(let part):
            try container.encode(part)
        case .refusal(let part):
            try container.encode(part)
        }
    }
    
    // Used internally for decoding based on type
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    // Maps JSON type strings to Swift cases
    private enum ContentType: String, Codable {
        case text
        case image_url // JSON uses image_url for image type
        case input_audio // JSON uses input_audio for audio type
        case file
        case refusal
    }
}

public struct OpenAIChatCompletionRequestMessageContentTextPart: Codable {
    public let type: String
    public let text: String
    
    public init(text: String) {
        self.text = text
        self.type = "text" // - Warning: Not Sure
    }
}

public enum OpenAIChatCompletionRequestMessageContentImagePartImageDetail: String, Codable {
    case auto, low, high
}

public enum OpenAIChatCompletionRequestMessageContentImagePartImageContent: Codable {
    case url(String)
    case base64(String)
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let str = try container.decode(String.self)
        if str.starts(with: "http") {
            self = .url(str)
        } else {
            self = .base64(str)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .url(let a0):
            try container.encode(a0)
        case .base64(let a0):
            try container.encode(a0)
        }
    }
}

public struct OpenAIChatCompletionRequestMessageContentImageContentPartImageURL: Codable {
    public let url: OpenAIChatCompletionRequestMessageContentImagePartImageContent
    public let detail: OpenAIChatCompletionRequestMessageContentImagePartImageDetail?
}

/// https://platform.openai.com/docs/guides/images?api-mode=chat&format=base64-encoded
public struct OpenAIChatCompletionRequestMessageContentImagePart: Codable {
    public let type: String
    public let imageUrl: OpenAIChatCompletionRequestMessageContentImageContentPartImageURL
    
    enum CodingKeys: String, CodingKey {
        case type
        case imageUrl = "image_url"
    }
}

public enum OpenAIChatCompletionRequestMessageContentAudioPartAudioDataFormat: String, Codable {
    case wav, mp3 // Add others if supported by API
}

public struct OpenAIChatCompletionRequestMessageContentAudioPartInput: Codable {
    public let data: String // Base64 encoded audio data
    public let format: OpenAIChatCompletionRequestMessageContentAudioPartAudioDataFormat
}

/// https://platform.openai.com/docs/guides/audio
public struct OpenAIChatCompletionRequestMessageContentAudioPart: Codable {
    public let type: String = "input_audio"
    public let inputAudio: OpenAIChatCompletionRequestMessageContentAudioPartInput
    
    enum CodingKeys: String, CodingKey {
        case type
        case inputAudio = "input_audio"
    }
}

/// https://platform.openai.com/docs/guides/pdf-files?api-mode=chat
public struct OpenAIChatCompletionRequestMessageContentFilePartDetail: Codable {
    
    public let fileId: String?
    public let filename: String?
    public let fileData: String? // The base64 encoded file data, used when passing the file to the model as a string.
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case filename
        case fileData = "file_data"
    }
}

public struct OpenAIChatCompletionRequestMessageContentFilePart: Codable {
    public let type: String = "file"
    public let file: OpenAIChatCompletionRequestMessageContentFilePartDetail
}

public struct OpenAIChatCompletionRequestMessageContentRefusalPart: Codable {
    public let type: String
    public let refusal: String
    
    public init(refusal: String) {
        self.refusal = refusal
        self.type = "refusal"
    }
}


// MARK: - Tool Calls (Assistant Message)

/// Represents a tool call made by the assistant. Currently only function calls are supported.
public struct OpenAIChatCompletionRequestAssistantMessageToolCall: Codable {
    /// The ID of the tool call.
    public let id: String
    /// The type of the tool. Currently, only "function" is supported.
    public let type: String
    /// The function that the model called.
    public let function: OpenAIChatCompletionRequestAssistantMessageToolCallCalledFunction
}

/// Represents the function called by the model within a ToolCall.
public struct OpenAIChatCompletionRequestAssistantMessageToolCallCalledFunction: Codable {
    /// The name of the function to call.
    public let name: String
    /// The arguments to call the function with, as a JSON format string.
    public let arguments: String // Model generates JSON string
}


// MARK: - Tools

/// Represents a tool choice (string 'none', 'auto', 'required' or specific tool).
public enum OpenAIChatCompletionRequestToolChoice: Codable {
    case none
    case auto
    case required
    case tool(OpenAIChatCompletionRequestToolChoiceSpecificTool)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            switch text {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "OpenAIChatCompletionRequestToolChoice Can't decode"))
            }
            return
        }
        let tool = try container.decode(OpenAIChatCompletionRequestToolChoiceSpecificTool.self)
        self = .tool(tool)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none: try container.encode("none")
        case .auto: try container.encode("auto")
        case .required: try container.encode("required")
        case .tool(let toolChoice): try container.encode(toolChoice)
        }
    }
}

public struct OpenAIChatCompletionRequestToolChoiceSpecificToolFunction: Codable {
    public let name: String
}

/// Represents a choice to call a specific tool (currently only function).
public struct OpenAIChatCompletionRequestToolChoiceSpecificTool: Codable {
    public let type: String = "function"
    public let function: OpenAIChatCompletionRequestToolChoiceSpecificToolFunction // Reusing NamedFunction structure
}


/// Represents a tool available to the model. Currently only functions are supported.
public struct OpenAIChatCompletionRequestTool: Codable {
    public let type: String = "function"
    public let function: OpenAIChatCompletionRequestToolFunction
}

/// Describes a function tool available to the model.
///
/// https://platform.openai.com/docs/guides/function-calling?api-mode=chat
/// https://json-schema.org/understanding-json-schema/reference
public struct OpenAIChatCompletionRequestToolFunction: Codable {
    public let name: String
    public let description: String?
    public let parameters: DynamicJSON.JSONSchema?
    
    // https://platform.openai.com/docs/guides/structured-outputs?api-mode=responses
    public let strict: Bool?
}


// MARK: - Other Supporting Structures

/// Represents the format/voice for audio output.
public struct OpenAIChatCompletionRequestAudioOutput: Codable {
    /// Output audio format (wav, mp3, flac, opus, pcm16).
    public let format: OpenAIChatCompletionRequestAudioOutputFormat
    /// Voice to use (alloy, ash, ballad, coral, echo, sage, shimmer).
    public let voice: OpenAIChatCompletionRequestAudioOutputVoice
}

public enum OpenAIChatCompletionRequestAudioOutputFormat: String, Codable {
    case wav, mp3, flac, opus, pcm16
}

public enum OpenAIChatCompletionRequestAudioOutputVoice: String, Codable {
    case alloy, ash, ballad, coral, echo, sage, shimmer
}

/// Represents the prediction configuration. Currently only StaticContent shown.
public struct OpenAIChatCompletionRequestPrediction: Codable {
    public let content: OpenAIChatCompletionRequestMessageContent
    public let type: String
}

public enum OpenAIChatCompletionRequestReasoningEffort: String, Codable {
    case low, medium, high
}

/// Specifies the desired response format.
public enum OpenAIChatCompletionRequestResponseFormat: Codable {
    case text(OpenAIChatCompletionRequestResponseTextFormat)
    case jsonSchema(OpenAIChatCompletionRequestResponseFormatJSONSchemaFormat)
    case jsonObject(OpenAIChatCompletionRequestResponseFormatJSONObjectFormat)
    
    // Custom Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FormatType.self, forKey: .type)
        
        switch type {
        case .text:
            // Text format might just be implicit or have 'text' type but no other fields
            // Let's assume a simple struct for consistency
            self = .text(try OpenAIChatCompletionRequestResponseTextFormat(from: decoder))
        case .json_schema:
            self = .jsonSchema(try OpenAIChatCompletionRequestResponseFormatJSONSchemaFormat(from: decoder))
        case .json_object:
            self = .jsonObject(try OpenAIChatCompletionRequestResponseFormatJSONObjectFormat(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let format):
            try container.encode(format)
        case .jsonSchema(let format):
            try container.encode(format)
        case .jsonObject(let format):
            try container.encode(format)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    private enum FormatType: String, Codable {
        case text
        case json_schema
        case json_object
    }
}

public struct OpenAIChatCompletionRequestResponseTextFormat: Codable {
    public let type: String = "text"
}

public struct OpenAIChatCompletionRequestResponseFormatJSONSchemaFormat: Codable {
    public let type: String = "json_schema"
    public let jsonSchema: OpenAIChatCompletionRequestResponseFormatJSONSchemaFormatDefinition
    
    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

public struct OpenAIChatCompletionRequestResponseFormatJSONSchemaFormatDefinition: Codable {
    public let name: String
    public let description: String?
    public let schema: DynamicJSON.JSONSchema?
    public let strict: Bool?
}


public struct OpenAIChatCompletionRequestResponseFormatJSONObjectFormat: Codable {
    public let type: String = "json_object"
}

public enum OpenAIChatCompletionRequestServiceTier: String, Codable {
    case auto, `default`
}

/// Options for streaming responses.
public struct OpenAIChatCompletionRequestStreamOptions: Codable {
    public let includeUsage: Bool?
    
    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}


/// Options for web search tool.
public struct WebSearchOptions: Codable {
    public let searchContextSize: SearchContextSize?
    public let userLocation: UserLocation?
    
    enum CodingKeys: String, CodingKey {
        case searchContextSize = "search_context_size"
        case userLocation = "user_location"
    }
    
    public init(searchContextSize: SearchContextSize? = .medium, userLocation: UserLocation? = nil) {
        self.searchContextSize = searchContextSize
        self.userLocation = userLocation
    }
}

public enum SearchContextSize: String, Codable {
    case low, medium, high
}

public struct UserLocation: Codable {
    public let type: String
    public let approximate: ApproximateLocation? // Only approximate shown in docs
    
    public init(approximate: ApproximateLocation?) {
        self.approximate = approximate
        self.type = "approximate"
    }
}

public struct ApproximateLocation: Codable {
    public let city: String? // Free text input for the city of the user,
    public let country: String? // https://en.wikipedia.org/wiki/ISO_3166-1
    public let region: String? // Free text input for the region of the user
    public let timezone: String? // https://timeapi.io/documentation/iana-timezones
    
    public init(city: String? = nil, country: String? = nil, region: String? = nil, timezone: String? = nil) {
        self.city = city
        self.country = country
        self.region = region
        self.timezone = timezone
    }
}
