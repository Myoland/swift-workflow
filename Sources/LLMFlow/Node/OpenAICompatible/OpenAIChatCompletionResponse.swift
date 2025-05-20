//
//  OpenAIChatCompletionResponse.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/20.
//


struct OpenAIChatCompletionResponse: Codable {
    let choices: [OpenAIChatCompletionResponseChoice]
    
    let created: Int
    
    let id: String
    
    let model: String
    
    let object: String = "chat.completion.chunk"
    
    let service_tier: OpenAIChatCompletionServiceTier?
    
    let system_fingerprint: String
    
    let usage: OpenAIChatCompletionResponseUsage?
    
    enum CodingKeys: CodingKey {
        case choices
        case created
        case id
        case model
        case object
        case service_tier
        case system_fingerprint
        case usage
    }
}

struct OpenAIChatCompletionResponseChoice: Codable {
    let index: Int
    let finish_reason: String?
    let logprobs: OpenAIChatCompletionResponseChoiceLogprobs?
    let message: OpenAIChatCompletionResponseChoiceMessage
}

struct OpenAIChatCompletionResponseChoiceMessage: Codable {
    let content: String?
    let refusal: String?
    let role: String
    let annotations: [OpenAIChatCompletionResponseChoiceMessageAnnotation]?
    let audio: [OpenAIChatCompletionResponseChoiceMessageAudio]?
    let tool_calls: [OpenAIChatCompletionResponseChoiceDeltaToolCall]?
}

struct OpenAIChatCompletionResponseChoiceMessageAnnotation: Codable {
    let type: String = "url_citation"
    let url_citation: OpenAIChatCompletionResponseChoiceMessageAnnotationURLCitation
    
    enum CodingKeys: CodingKey {
        case type
        case url_citation
    }
}

struct OpenAIChatCompletionResponseChoiceMessageAnnotationURLCitation: Codable {
    let end_index: Int
    let strat_index: Int
    let title: String
    let url: String
}

struct OpenAIChatCompletionResponseChoiceMessageAudio: Codable {
    let data: String
    let expires_at: Int
    let id: String
    let trancript: String
}


struct OpenAIChatCompletionStreamResponse: Codable {
    let choices: [OpenAIChatCompletionStreamResponseChoice]
    
    let created: Int
    
    let id: String
    
    let model: String
    
    let object: String = "chat.completion.chunk"
    
    let service_tier: OpenAIChatCompletionServiceTier?
    
    let system_fingerprint: String
    
    let usage: OpenAIChatCompletionResponseUsage?
    
    enum CodingKeys: CodingKey {
        case choices
        case created
        case id
        case model
        case object
        case service_tier
        case system_fingerprint
        case usage
    }
}

struct OpenAIChatCompletionResponseUsage: Codable {
    let completion_tokens: Int
    let prompt_tokens: Int
    let total_tokens: Int
    let completion_tokens_details: OpenAIChatCompletionResponseUsageCompletionDetails
    let prompt_tokens_details: OpenAIChatCompletionResponseUsagePromptDetails
}

struct OpenAIChatCompletionResponseUsageCompletionDetails: Codable {
    let accepted_prediction_tokens: Int
    let audio_tokens: Int
    let reasoning_tokens: Int
    let rejected_prediction_tokens: Int
}

struct OpenAIChatCompletionResponseUsagePromptDetails: Codable {
    let audio_tokens: Int
    let cached_tokens: Int
    
}

struct OpenAIChatCompletionStreamResponseChoice: Codable {
    let index: Int
    let finish_reason: String?
    let logprobs: OpenAIChatCompletionResponseChoiceLogprobs?
    let delta: OpenAIChatCompletionStreamResponseChoiceDelta
}

struct OpenAIChatCompletionResponseChoiceLogprobs: Codable {
    let content: [OpenAIChatCompletionResponseChoiceLogprobsInfo]?
    let refusal: [OpenAIChatCompletionResponseChoiceLogprobsInfo]?
}

struct OpenAIChatCompletionResponseChoiceLogprobsInfo: Codable {
    let bytes: [String]
    let logprob: Double
    let token: String
    let top_logprobs: [OpenAIChatCompletionResponseChoiceLogprobsInfo]
}

struct OpenAIChatCompletionStreamResponseChoiceDelta: Codable {
    let content: String?
    let refusal: String?
    let role: String?
    let tool_calls: [OpenAIChatCompletionResponseChoiceDeltaToolCall]?
}

struct OpenAIChatCompletionResponseChoiceDeltaToolCall: Codable {
    let index: Int
    let function: OpenAIChatCompletionResponseChoiceDeltaToolCallFunction
    let id: String
    let type: String = "function"
    
    enum CodingKeys: CodingKey {
        case index
        case function
        case id
        case type
    }
}

struct OpenAIChatCompletionResponseChoiceDeltaToolCallFunction: Codable {
    let arguments: String
    let name: String
}
