//
//  LLMNode+OpenAI.swift
//  dify-forward
//
//  Created by AFuture on 2025/4/9.
//


import Foundation
import DynamicJSON
import HTTPTypes
import NIOHTTP1
import WantLazy

/// https://platform.openai.com/docs/guides/pdf-files?api-mode=chat
public struct ModelReponseRequestInputItemMessageContentItemFileInput: Codable {
    public let type: ModelReponseRequestInputItemMessageContentType
    
    /// The content of the file to be sent to the model.
    public let fileData: String?
    
    /// The ID of the file to be sent to the model.
    public let fileID: String?
    
    /// The name of the file to be sent to the model.
    public let filename: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case fileData = "file_data"
        case fileID = "file_id"
        case filename
    }
    
    init(fileData: String?, fileID: String?, filename: String?) {
        self.type = .file
        self.fileData = fileData
        self.fileID = fileID
        self.filename = filename
    }
}

/// The detail level of the image to be sent to the model. One of high, low, or auto. Defaults to auto.
public enum ModelReponseRequestInputItemMessageContentImageItemDetail: String, Codable {
    case high
    case low
    case auto
    
    // static let `default`: Self = .auto
}

/// An image input to the model.
/// Learn about [image inputs](https://platform.openai.com/docs/guides/images?api-mode=responses).
public struct ModelReponseRequestInputItemMessageContentItemImageInput: Codable {
    public let type: ModelReponseRequestInputItemMessageContentType
    
    public let detail: ModelReponseRequestInputItemMessageContentImageItemDetail
    
    // The ID of the file to be sent to the model.
    public let fileId: String?
    
    // The URL of the image to be sent to the model.
    // A fully qualified URL or base64 encoded image in a data URL.
    public let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case detail
        case fileId = "file_id"
        case imageUrl = "image_url"
    }
    
    init(detail: ModelReponseRequestInputItemMessageContentImageItemDetail, fileId: String?, imageUrl: String?) {
        self.type = .image
        self.detail = detail
        self.fileId = fileId
        self.imageUrl = imageUrl
    }
}

public struct ModelReponseRequestInputItemMessageContentItemTextInput: Codable {
    public let text: String
    public let type: ModelReponseRequestInputItemMessageContentType
    
    init(text: String) {
        self.text = text
        self.type = .text
    }
}

public enum ModelReponseRequestInputItemMessageContentType: String, Codable {
    case text = "input_text"
    case image = "input_image"
    case file = "input_file"
}

/// A list of one or many input items to the model, containing different content types.
public enum ModelReponseRequestInputItemMessageContentItem: Codable {
    case text(ModelReponseRequestInputItemMessageContentItemTextInput)
    case image(ModelReponseRequestInputItemMessageContentItemImageInput)
    case file(ModelReponseRequestInputItemMessageContentItemFileInput)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let modelReponseRequestInputItemMessageContentItemTextInput):
            try container.encode(modelReponseRequestInputItemMessageContentItemTextInput)
        case .image(let modelReponseRequestInputItemMessageContentItemImageInput):
            try container.encode(modelReponseRequestInputItemMessageContentItemImageInput)
        case .file(let modelReponseRequestInputItemMessageContentItemFileInput):
            try container.encode(modelReponseRequestInputItemMessageContentItemFileInput)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as each possible type and check which one succeeds
        if let textInput = try? container.decode(ModelReponseRequestInputItemMessageContentItemTextInput.self) {
            if textInput.type == .text {
                self = .text(textInput)
                return
            }
        }
        
        if let imageInput = try? container.decode(ModelReponseRequestInputItemMessageContentItemImageInput.self) {
            if imageInput.type == .image {
                self = .image(imageInput)
                return
            }
        }
        
        if let fileInput = try? container.decode(ModelReponseRequestInputItemMessageContentItemFileInput.self) {
            if fileInput.type == .file {
                self = .file(fileInput)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemMessageContentItem")
    }
}

public enum ModelReponseRequestInputItemMessageContent: Codable {
    case text(String)
    case inputs([ModelReponseRequestInputItemMessageContentItem])
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let a0):
            try container.encode(a0)
        case .inputs(let a0):
            try container.encode(a0)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // First try to decode as a simple string
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
            return
        }
        
        // Then try to decode as an array of content items
        if let itemArray = try? container.decode([ModelReponseRequestInputItemMessageContentItem].self) {
            self = .inputs(itemArray)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemMessageContent")
    }
}

public enum ModelReponseRequestInputItemMessageRole: String, Codable {
    case user
    case assistant
    case system
    case developer
}

/// A message input to the model with a role indicating instruction following hierarchy.
/// Instructions given with the developer or system role take precedence over instructions given with the user role.
/// Messages with the assistant role are presumed to have been generated by the model in previous interactions.
public struct ModelReponseRequestInputItemMessage: Codable {
    
    /// Text, image, or audio input to the model, used to generate a response. Can also contain previous assistant responses.
    public let contenet: ModelReponseRequestInputItemMessageContent
    
    /// The role of the message input. One of user, assistant, system, or developer.
    public let role: ModelReponseRequestInputItemMessageRole
    
    public let type: ModelReponseRequestInputItemType
    
    init(contenet: ModelReponseRequestInputItemMessageContent, role: ModelReponseRequestInputItemMessageRole) {
        self.contenet = contenet
        self.role = role
        self.type = .message
    }
}

/// Populated when items are returned via API.
public enum ModelReponseRequestInputItemContextOutputStatus: String, Codable {
    case inProgress = "in_progress"
    case completed
    case incomplete
}

public enum ModelReponseRequestInputItemContextOutputRole: Codable {
    case user
    case system
    case developer
}

/// A citation to a file.
public struct ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFileCitation: Codable {
    let file_id: String
    let index: Int
    let type: ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationType = .file_citation
}

/// A citation for a web resource used to generate a model response.
public struct ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationURLCitation: Codable {
    let end_index: Int
    let start_index: Int
    let title: String
    let url: String
    let type: ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationType = .url_citation
}

/// A path to a file.
public struct ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFilePath: Codable {
    let file_id: String
    let index: Int
    let type: ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationType = .file_path
}

public enum ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationType: String, Codable {
    case file_citation
    case url_citation
    case file_path
}

public enum ModelReponseRequestInputItemContextOutputContentTextOutputAnnotation: Codable {
    case fileCitation(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFileCitation)
    case url(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationURLCitation)
    case filePath(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFilePath)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .fileCitation(let a0):
            try container.encode(a0)
        case .url(let a0):
            try container.encode(a0)
        case .filePath(let a0):
            try container.encode(a0)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let fileCitation = try? container.decode(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFileCitation.self) {
            if fileCitation.type == .file_citation {
                self = .fileCitation(fileCitation)
                return
            }
        }
        
        if let urlCitation = try? container.decode(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationURLCitation.self) {
            if urlCitation.type == .url_citation {
                self = .url(urlCitation)
                return
            }
        }
        
        if let filePath = try? container.decode(ModelReponseRequestInputItemContextOutputContentTextOutputAnnotationFilePath.self) {
            if filePath.type == .file_path {
                self = .filePath(filePath)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContextOutputContentTextOutputAnnotation")
    }
}

// A text output from the model.
public struct ModelReponseRequestInputItemContextOutputContentTextOutput: Codable {
    let annotations: [ModelReponseRequestInputItemContextOutputContentTextOutputAnnotation]
    let text: String
    let type: String = "output_text"
}

// The refusal explanationfrom the model.
public struct ModelReponseRequestInputItemContextOutputContentRefusal: Codable {
    let refusal: String
    let type: String = "refusal"
}

public enum ModelReponseRequestInputItemContextOutputContent: Codable {
    case text(ModelReponseRequestInputItemContextOutputContentTextOutput)
    case refusal(ModelReponseRequestInputItemContextOutputContentRefusal)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let a0):
            try container.encode(a0)
        case .refusal(let a0):
            try container.encode(a0)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let textOutput = try? container.decode(ModelReponseRequestInputItemContextOutputContentTextOutput.self) {
            if textOutput.type == "output_text" {
                self = .text(textOutput)
                return
            }
        }
        
        if let refusal = try? container.decode(ModelReponseRequestInputItemContextOutputContentRefusal.self) {
            if refusal.type == "refusal" {
                self = .refusal(refusal)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContextOutputContent")
    }
}


public struct ModelReponseRequestInputItemContextOutput: Codable {
    
    /// The unique ID of the output message.
    let id: String
    let content: ModelReponseRequestInputItemContextOutputContent
    let role: String
    let type: String
    
    init(id: String, content: ModelReponseRequestInputItemContextOutputContent) {
        self.id = id
        self.content = content
        self.role = "assistant"
        self.type = "message"
    }
}

/// A message input to the model with a role indicating instruction following hierarchy.
/// Instructions given with the developer or system role take precedence over instructions given with the user role.
public struct ModelReponseRequestInputItemContextInput: Codable {
    
    let content: [ModelReponseRequestInputItemMessageContentItem]
    let role: ModelReponseRequestInputItemContextOutputRole
    let status: ModelReponseRequestInputItemContextOutputStatus?
    let type: String
    
    init(content: [ModelReponseRequestInputItemMessageContentItem],
         role: ModelReponseRequestInputItemContextOutputRole,
         status: ModelReponseRequestInputItemContextOutputStatus?
    ) {
        self.content = content
        self.role = role
        self.status = status
        self.type = "message"
    }
}

public enum ModelReponseRequestInputItemContextFileSearchToolCallStatus: String, Codable {
    case inProgress = "in_progress"
    case searching
    case incomplete
    case failed
}

// The queries used to search for files.
public typealias ModelReponseRequestInputItemContextFileSearchToolCallQuery = String

public struct ModelReponseRequestInputItemContextFileSearchToolCallResult: Codable {
    /// Set of 16 key-value pairs that can be attached to an object.
    /// This can be useful for storing additional information about the object in a structured format,
    /// and querying for objects via API or the dashboard.
    /// Keys are strings with a maximum length of 64 characters.
    /// Values are strings with a maximum length of 512 characters, booleans, or numbers.
    let attributes: [String: String]?
    let file_id: String?
    let filename: String?
    let score: Double?
    let text: String?
}

/// The queries used to [search for files](https://platform.openai.com/docs/guides/tools-file-search).
public struct ModelReponseRequestInputItemContextFileSearchToolCall: Codable {
    let id: String
    let queries: [ModelReponseRequestInputItemContextFileSearchToolCallQuery]
    let status: ModelReponseRequestInputItemContextFileSearchToolCallStatus
    let type: String = "file_search_call"
    let results: [ModelReponseRequestInputItemContextFileSearchToolCallResult]?
}

public enum ModelReponseRequestInputItemContextComputerToolCallActionClickButton: String, Codable {
    case left
    case right
    case wheel
    case back
    case forward
}

public struct ModelReponseRequestInputItemContextComputerToolCallActionClick: Codable {
    let button: ModelReponseRequestInputItemContextComputerToolCallActionClickButton
    let type: String = "click"
    let x: Int
    let y: Int
}

public struct ModelReponseRequestInputItemContextComputerToolCallActionDoubleClick: Codable {
    let type: String = "double_click"
    let x: Int
    let y: Int
}

public struct ModelReponseRequestInputItemContextComputerToolCallActionDragCoordinate: Codable {
    let x: Int
    let y: Int
}

public struct ModelReponseRequestInputItemContextComputerToolCallActionDrag: Codable {
    let type = "drag"
    /// An array of coordinates representing the path of the drag action. Coordinates will appear as an array of objects.
    let path: [ModelReponseRequestInputItemContextComputerToolCallActionDragCoordinate]
}

/// A collection of keypresses the model would like to perform.
public struct ModelReponseRequestInputItemContextComputerToolCallActionKeyPress: Codable {
    let type: String = "keypress"
    /// The combination of keys the model is requesting to be pressed. This is an array of strings, each representing a key.
    let keys: [String]
}

/// A mouse move action.
public struct ModelReponseRequestInputItemContextComputerToolCallActionMove: Codable {
    let type: String = "move"
    /// The x-coordinate to move to.
    let x: Int
    /// The y-coordinate to move to.
    let y: Int
}

/// A screenshot action.
public struct ModelReponseRequestInputItemContextComputerToolCallActionScreenshot: Codable {
    let type: String = "screenshot"
}

/// A scroll action.
public struct ModelReponseRequestInputItemContextComputerToolCallActionScroll: Codable {
    let type: String = "scroll"
    /// The horizontal scroll distance.
    let scroll_x: Int
    /// The vertical scroll distance.
    let scroll_y: Int
    /// The x-coordinate where the scroll occurred.
    let x: Int
    /// The y-coordinate where the scroll occurred.
    let y: Int
}

/// An action to type in text.
public struct ModelReponseRequestInputItemContextComputerToolCallActionType: Codable {
    let text: String
    let type: String = "type"
}

/// A wait action.
public struct ModelReponseRequestInputItemContextComputerToolCallActionWait: Codable {
    let type: String = "wait"
}

public enum ModelReponseRequestInputItemContextComputerToolCallAction: Codable {
    case click(ModelReponseRequestInputItemContextComputerToolCallActionClick)
    case doubleClick(ModelReponseRequestInputItemContextComputerToolCallActionDoubleClick)
    case drag(ModelReponseRequestInputItemContextComputerToolCallActionDrag)
    case keyPress(ModelReponseRequestInputItemContextComputerToolCallActionKeyPress)
    case move(ModelReponseRequestInputItemContextComputerToolCallActionMove)
    case screenshot(ModelReponseRequestInputItemContextComputerToolCallActionScreenshot)
    case scroll(ModelReponseRequestInputItemContextComputerToolCallActionScroll)
    case type(ModelReponseRequestInputItemContextComputerToolCallActionType)
    case wait(ModelReponseRequestInputItemContextComputerToolCallActionWait)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .click(let modelReponseRequestInputItemContextComputerToolCallActionClick):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionClick)
        case .doubleClick(let modelReponseRequestInputItemContextComputerToolCallActionDoubleClick):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionDoubleClick)
        case .drag(let modelReponseRequestInputItemContextComputerToolCallActionDrag):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionDrag)
        case .keyPress(let modelReponseRequestInputItemContextComputerToolCallActionKeyPress):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionKeyPress)
        case .move(let modelReponseRequestInputItemContextComputerToolCallActionMove):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionMove)
        case .screenshot(let modelReponseRequestInputItemContextComputerToolCallActionScreenshot):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionScreenshot)
        case .scroll(let modelReponseRequestInputItemContextComputerToolCallActionScroll):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionScroll)
        case .type(let modelReponseRequestInputItemContextComputerToolCallActionType):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionType)
        case .wait(let modelReponseRequestInputItemContextComputerToolCallActionWait):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallActionWait)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode each type based on the "type" field
        if let click = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionClick.self) {
            if click.type == "click" {
                self = .click(click)
                return
            }
        }
        
        if let doubleClick = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionDoubleClick.self) {
            if doubleClick.type == "double_click" {
                self = .doubleClick(doubleClick)
                return
            }
        }
        
        if let drag = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionDrag.self) {
            if drag.type == "drag" {
                self = .drag(drag)
                return
            }
        }
        
        if let keyPress = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionKeyPress.self) {
            if keyPress.type == "keypress" {
                self = .keyPress(keyPress)
                return
            }
        }
        
        if let move = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionMove.self) {
            if move.type == "move" {
                self = .move(move)
                return
            }
        }
        
        if let screenshot = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionScreenshot.self) {
            if screenshot.type == "screenshot" {
                self = .screenshot(screenshot)
                return
            }
        }
        
        if let scroll = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionScroll.self) {
            if scroll.type == "scroll" {
                self = .scroll(scroll)
                return
            }
        }
        
        if let type = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionType.self) {
            if type.type == "type" {
                self = .type(type)
                return
            }
        }
        
        if let wait = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallActionWait.self) {
            if wait.type == "wait" {
                self = .wait(wait)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContextComputerToolCallAction")
    }
}

/// The pending safety checks for the computer call.
public struct ModelReponseRequestInputItemContextComputerToolCallSafetyCheck: Codable {
    // The type of the pending safety check.
    let code: String
    // The ID of the pending safety check.
    let id: String
    // Details about the pending safety check.
    let message: String
}

public enum ModelReponseRequestInputItemContextComputerToolCallStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// A tool call to a computer use tool. See the [computer use guide](https://platform.openai.com/docs/guides/tools-computer-use) for more information.
public struct ModelReponseRequestInputItemContextComputerToolCallRequest: Codable {
    let action: ModelReponseRequestInputItemContextComputerToolCallAction
    /// An identifier used when responding to the tool call with output.
    let call_id: String
    /// The unique ID of the computer call.
    let id: String
    let pending_safety_checks: [ModelReponseRequestInputItemContextComputerToolCallSafetyCheck]
    let status: ModelReponseRequestInputItemContextComputerToolCallStatus
    let type: String = "computer_call"
}

public enum ModelReponseRequestInputItemContextComputerToolCallOutputStatus: String, Codable {
    case in_progress
    case completed
    case incomplete
}

public struct ModelReponseRequestInputItemContextComputerToolCallOutputObject: Codable {
    let type: String = "computer_screenshot"
    /// The identifier of an uploaded file that contains the screenshot.
    let file_id: String?
    /// The URL of the screenshot image.
    let image_url: String?
}

/// The output of a computer tool call.
public struct ModelReponseRequestInputItemContextComputerToolCallReponse: Codable {
    let type: String = "computer_call_output"
    /// The ID of the computer tool call that produced the output.
    let call_id: String
    /// The ID of the computer tool call output.
    let id: String?
    /// The status of the message input. Populated when input items are returned via API.
    let status: ModelReponseRequestInputItemContextComputerToolCallOutputStatus?
    /// A computer screenshot image used with the computer use tool.
    let output: ModelReponseRequestInputItemContextComputerToolCallOutputObject
    /// The safety checks reported by the API that have been acknowledged by the developer.
    let acknowledge_safety_checks: [ModelReponseRequestInputItemContextComputerToolCallSafetyCheck]?
}

/// The results of a web search tool call. See the [web search guide](https://platform.openai.com/docs/guides/tools-web-search) for more information.
public struct ModelReponseRequestInputItemContextWebSearchToolCall: Codable {
    let id: String
    let status: ModelReponseRequestInputItemContextFileSearchToolCallStatus
    let type: String = "web_search_call"
}

public enum ModelReponseRequestInputItemContextFuncToolCallStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// A tool call to run a function.
/// See the [function calling](https://platform.openai.com/docs/guides/function-calling?api-mode=responses) guide for more information.
public struct ModelReponseRequestInputItemContextFuncToolCall: Codable {
    /// A JSON string of the arguments to pass to the function.
    let arguments: String
    
    /// The unique ID of the function tool call generated by the model.
    let call_id: String
    
    /// The name of the function to run.
    let name: String
    
    let type: String = "function_call"
    
    /// The unique ID of the function tool call.
    let id: String?
    
    let status: ModelReponseRequestInputItemContextFuncToolCallStatus?
}

public enum ModelReponseRequestInputItemContextFuncToolCallOutputStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// The output of a function tool call.
public struct ModelReponseRequestInputItemContextFuncToolCallOutput: Codable {
    /// The unique ID of the function tool call generated by the model.
    let call_id: String
    
    /// A JSON string of the output of the function tool call.
    let output: String
    
    let type: String = "function_call_output"

    /// The unique ID of the function tool call output. Populated when this item is returned via API.
    let id: String?

    /// The status of the item. Populated when items are returned via API.
    let status: ModelReponseRequestInputItemContextFuncToolCallOutputStatus?
}

public enum ModelReponseRequestInputItemContextReasoningStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// Reasoning text contents.
public struct ModelReponseRequestInputItemContextReasoningSummaryTextContent: Codable {
    let type: String = "summary_text"
    /// A short summary of the reasoning used by the model when generating the
    let text: String
}

public struct ModelReponseRequestInputItemContextReasoning: Codable {
    let id: String
    let summary: [ModelReponseRequestInputItemContextReasoningSummaryTextContent]
    let type: String = "reasoning"
    /// The status of the item. Populated when items are returned via API.
    let status: ModelReponseRequestInputItemContextReasoningStatus?
}

/// An item representing part of the context for the response to be generated by the model.
/// Can contain text, images, and audio inputs, as well as previous assistant responses and tool call outputs.
public enum ModelReponseRequestInputItemContext: Codable {
    case input(ModelReponseRequestInputItemContextInput)
    case output(ModelReponseRequestInputItemContextOutput)
    case fileSearchToolCall(ModelReponseRequestInputItemContextFileSearchToolCall)
    case computerToolCallRequest(ModelReponseRequestInputItemContextComputerToolCallRequest)
    case computerToolResponse(ModelReponseRequestInputItemContextComputerToolCallReponse)
    case webSearchToolCall(ModelReponseRequestInputItemContextWebSearchToolCall)
    case funcToolCall(ModelReponseRequestInputItemContextFuncToolCall)
    case funcToolCallResponse(ModelReponseRequestInputItemContextFuncToolCallOutput)
    case reasoning(ModelReponseRequestInputItemContextReasoning)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .input(let modelReponseRequestInputItemContextInput):
            try container.encode(modelReponseRequestInputItemContextInput)
        case .output(let modelReponseRequestInputItemContextOutput):
            try container.encode(modelReponseRequestInputItemContextOutput)
        case .fileSearchToolCall(let modelReponseRequestInputItemContextFileSearchToolCall):
            try container.encode(modelReponseRequestInputItemContextFileSearchToolCall)
        case .computerToolCallRequest(let modelReponseRequestInputItemContextComputerToolCallRequest):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallRequest)
        case .computerToolResponse(let modelReponseRequestInputItemContextComputerToolCallReponse):
            try container.encode(modelReponseRequestInputItemContextComputerToolCallReponse)
        case .webSearchToolCall(let modelReponseRequestInputItemContextWebSearchToolCall):
            try container.encode(modelReponseRequestInputItemContextWebSearchToolCall)
        case .funcToolCall(let modelReponseRequestInputItemContextFuncToolCall):
            try container.encode(modelReponseRequestInputItemContextFuncToolCall)
        case .funcToolCallResponse(let modelReponseRequestInputItemContextFuncToolCallOutput):
            try container.encode(modelReponseRequestInputItemContextFuncToolCallOutput)
        case .reasoning(let modelReponseRequestInputItemContextReasoning):
            try container.encode(modelReponseRequestInputItemContextReasoning)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding each possible type and check based on specific type fields
        if let input = try? container.decode(ModelReponseRequestInputItemContextInput.self) {
            if input.type == "message" {
                self = .input(input)
                return
            }
        }
        
        if let output = try? container.decode(ModelReponseRequestInputItemContextOutput.self) {
            if output.type == "message" {
                self = .output(output)
                return
            }
        }
        
        if let fileSearchToolCall = try? container.decode(ModelReponseRequestInputItemContextFileSearchToolCall.self) {
            if fileSearchToolCall.type == "file_search_call" {
                self = .fileSearchToolCall(fileSearchToolCall)
                return
            }
        }
        
        if let computerToolCallRequest = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallRequest.self) {
            if computerToolCallRequest.type == "computer_call" {
                self = .computerToolCallRequest(computerToolCallRequest)
                return
            }
        }
        
        if let computerToolResponse = try? container.decode(ModelReponseRequestInputItemContextComputerToolCallReponse.self) {
            if computerToolResponse.type == "computer_call_output" {
                self = .computerToolResponse(computerToolResponse)
                return
            }
        }
        
        if let webSearchToolCall = try? container.decode(ModelReponseRequestInputItemContextWebSearchToolCall.self) {
            if webSearchToolCall.type == "web_search_call" {
                self = .webSearchToolCall(webSearchToolCall)
                return
            }
        }
        
        if let funcToolCall = try? container.decode(ModelReponseRequestInputItemContextFuncToolCall.self) {
            if funcToolCall.type == "function_call" {
                self = .funcToolCall(funcToolCall)
                return
            }
        }
        
        if let funcToolCallResponse = try? container.decode(ModelReponseRequestInputItemContextFuncToolCallOutput.self) {
            if funcToolCallResponse.type == "function_call_output" {
                self = .funcToolCallResponse(funcToolCallResponse)
                return
            }
        }
        
        if let reasoning = try? container.decode(ModelReponseRequestInputItemContextReasoning.self) {
            if reasoning.type == "reasoning" {
                self = .reasoning(reasoning)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContext")
    }
}

public enum ModelReponseRequestInputItemType: String, Codable {
    case message
    case item
    case reference
}

public struct ModelReponseRequestInputItemReference: Codable {
    let id: String
    let type: String = "item_reference"
}

public enum ModelReponseRequestInputItem: Codable {
    case message(ModelReponseRequestInputItemMessage)
    case item(ModelReponseRequestInputItemContext)
    case reference(ModelReponseRequestInputItemReference)
}

public enum ModelReponseRequestInput: Codable {
    case text(String)
    case items([ModelReponseRequestInputItem])
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .text(let string):
            try container.encode(string)
        case .items(let array):
            try container.encode(array)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // First try to decode as string
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
            return
        }
        
        // Then try to decode as array of input items
        if let itemsArray = try? container.decode([ModelReponseRequestInputItem].self) {
            self = .items(itemsArray)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInput")
    }
}

public enum ModelReponseRequestAdditionalData: String, Codable {
    /// Include the search results of the file search tool call.
    case fileSearchCallResults = "file_search_call.results"
    
    /// Include image urls from the input message.
    case inputMessageImageUrl = "message.input_image.image_url"
    
    ///  Include image urls from the computer call output.
    case computerCallOutputImageUrl = "computer_call_output.output.image_url"
}

public enum ModelReponseRequestResoningEffort: String, Codable {
    case low
    case medium
    case high
}

public enum ModelReponseRequestResoningGenerateSummary: Codable {
    case concise
    case detailed
}

public struct ModelReponseRequestResoning: Codable {
    
    /// Constrains effort on reasoning for reasoning models.
    /// Currently supported values are low, medium, and high.
    /// Reducing reasoning effort can result in faster responses and fewer tokens used on reasoning in a response.
    ///
    /// o-series models only
    /// Defaults to medium
    let effort: ModelReponseRequestResoningEffort?
    
    /// A summary of the reasoning performed by the model.
    /// This can be useful for debugging and understanding the model's reasoning process.
    ///
    /// computer-use-preview only
    let generate_summary: ModelReponseRequestResoningGenerateSummary?
}

public struct ModelReponseRequestTextConfigurationFormatText: Codable {
    let type: String = "text"
}

/// JSON Schema response format. Used to generate structured JSON responses.
/// Learn more about [Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs).
public struct ModelReponseRequestTextConfigurationFormatJsonSchema: Codable {
    let type: String = "json_schema"
    /// The name of the response format.
    /// Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.
    let name: String
    
    /// A description of what the response format is for, used by the model to determine how to respond in the format.
    let description: String?
    
    /// Whether to enable strict schema adherence when generating the output.
    /// If set to true, the model will always follow the exact `schema` defined in the schema field.
    /// Only a subset of JSON Schema is supported when `strict` is `true`.
    /// To learn more, read the [Structured Outputs guide](https://platform.openai.com/docs/guides/structured-outputs).
    let strict: Bool?
    
    /// The schema for the response format, described as a JSON Schema object.
    /// Learn how to build JSON schemas [here](https://json-schema.org).
    let schema: JSONSchema
}

/// JSON object response format.
/// An older method of generating JSON responses.
/// Using `json_schema` is recommended for models that support it.
/// Note that the model will not generate JSON without a system or user message instructing it to do so.
public struct ModelReponseRequestTextConfigurationFormatJson: Codable {
    let type: String = "json_object"
}

public enum ModelReponseRequestTextConfigurationFormat: Codable {
    case text(ModelReponseRequestTextConfigurationFormatText)
    case jsonSchema(ModelReponseRequestTextConfigurationFormatJsonSchema)
    case json(ModelReponseRequestTextConfigurationFormatJson)
}

public struct ModelReponseRequestTextConfiguration: Codable {
    let format: ModelReponseRequestTextConfigurationFormat?
}

/// Controls which (if any) tool is called by the model.
public enum ModelReponseRequestToolChoiceToolChoiceMode: String, Codable {
    case none
    case auto
    case required
}

public enum ModelReponseRequestToolChoiceHostedToolType: String, Codable {
    case file_search
    case web_search_preview
    case computer_use_preiew
}

/// Indicates that the model should use a built-in tool to generate a response.
///
/// Learn more about [built-in tools](https://platform.openai.com/docs/guides/tools).
public struct ModelReponseRequestToolChoiceHostedTool: Codable {
    let type: ModelReponseRequestToolChoiceHostedToolType
}

/// Use this option to force the model to call a specific function.
public struct ModelReponseRequestToolChoiceFunctionTool: Codable {
    let name: String
    let type: String = "function"
}

public enum ModelReponseRequestToolChoice: Codable {
    case toolChoiceMode(ModelReponseRequestToolChoiceToolChoiceMode)
    case hostedTool(ModelReponseRequestToolChoiceHostedTool)
    case functionTool(ModelReponseRequestToolChoiceFunctionTool)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .toolChoiceMode(let modelReponseRequestToolChoiceToolChoiceMode):
            try container.encode(modelReponseRequestToolChoiceToolChoiceMode)
        case .hostedTool(let modelReponseRequestToolChoiceHostedTool):
            try container.encode(modelReponseRequestToolChoiceHostedTool)
        case .functionTool(let modelReponseRequestToolChoiceFunctionTool):
            try container.encode(modelReponseRequestToolChoiceFunctionTool)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as simple string (for tool choice mode)
        if let mode = try? container.decode(ModelReponseRequestToolChoiceToolChoiceMode.self) {
            self = .toolChoiceMode(mode)
            return
        }
        
        // Try to decode as hosted tool
        if let hostedTool = try? container.decode(ModelReponseRequestToolChoiceHostedTool.self) {
            self = .hostedTool(hostedTool)
            return
        }
        
        // Try to decode as function tool
        if let functionTool = try? container.decode(ModelReponseRequestToolChoiceFunctionTool.self) {
            if functionTool.type == "function" {
                self = .functionTool(functionTool)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestToolChoice")
    }
}

public enum ModelReponseRequestToolFileSearchFilterComparisonType: Codable {
    case eq
    case ne
    case gt
    case gte
    case lt
    case lte
}

public enum ModelReponseRequestToolFileSearchFilterComparisonValue: Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as each possible type
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        
        // Try to decode as number (Int or Double)
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        
        // Try to decode as string
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestToolFileSearchFilterComparisonValue")
    }
}

public struct ModelReponseRequestToolFileSearchFilterComparison: Codable {
    /// The key to compare against the value.
    let key: String
    let type: ModelReponseRequestToolFileSearchFilterComparisonType
    /// The value to compare against the attribute key;
    /// supports string, number, or boolean types.
    let value: ModelReponseRequestToolFileSearchFilterComparisonValue
}

public enum ModelReponseRequestToolFileSearchFilterCompoundType: String, Codable {
    case and
    case or
}

/// Combine multiple filters using and or or.
public struct ModelReponseRequestToolFileSearchFilterCompound: Codable {
    let filters: [ModelReponseRequestToolFileSearchFilter]
    let type: ModelReponseRequestToolFileSearchFilterCompoundType
}

public enum ModelReponseRequestToolFileSearchFilter: Codable {
    case comparsion(ModelReponseRequestToolFileSearchFilterComparison)
    case compound(ModelReponseRequestToolFileSearchFilterCompound)
    
    public func encode(to encoder: any Encoder) throws {
        var conatiner = encoder.singleValueContainer()
        
        switch self {
        case .comparsion(let modelReponseRequestToolFileSearchFilterComparison):
            try conatiner.encode(modelReponseRequestToolFileSearchFilterComparison)
        case .compound(let modelReponseRequestToolFileSearchFilterCompound):
            try conatiner.encode(modelReponseRequestToolFileSearchFilterCompound)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as comparison
        if let comparison = try? container.decode(ModelReponseRequestToolFileSearchFilterComparison.self) {
            self = .comparsion(comparison)
            return
        }
        
        // Try to decode as compound
        if let compound = try? container.decode(ModelReponseRequestToolFileSearchFilterCompound.self) {
            self = .compound(compound)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestToolFileSearchFilter")
    }
}

public struct ModelReponseRequestToolFileSearchRankingOption: Codable {
    /// The ranker to use for the file search.
    let ranker: String?
    
    /// The score threshold for the file search, a number between 0 and 1.
    /// Numbers closer to 1 will attempt to return only the most relevant results, but may return fewer results.
    let score_threshold: Double?
}

/// A tool that searches for relevant content from uploaded files.
///
/// Learn more about the [file search tool](https://platform.openai.com/docs/guides/tools-file-search).
public struct ModelReponseRequestToolFileSearch: Codable {
    let type: String = "file_search"
    
    /// The IDs of the vector stores to search.
    let vector_store_ids: [String]
    
    /// A filter to apply based on file attributes.
    let filters: [ModelReponseRequestToolFileSearchFilter]?
    let max_num_results: Int?
    
    /// Ranking options for search.
    let ranking_options: ModelReponseRequestToolFileSearchRankingOption?
}

/// Defines a function in your own code the model can choose to call.
///
/// Learn more about [function calling](https://platform.openai.com/docs/guides/function-calling).
public struct ModelReponseRequestToolFunction: Codable {
    let type: String = "function"
    let name: String
    /// A JSON schema object describing the parameters of the function.
    let parameters: JSONSchema
    
    /// Whether to enforce strict parameter validation.
    /// Default true.
    let strict: Bool
    
    /// A description of the function.
    /// Used by the model to determine whether or not to call the function.
    let description: String?
}

/// A tool that controls a virtual computer.
///
/// Learn more about the [computer tool](https://platform.openai.com/docs/guides/tools-computer-use).
public struct ModelReponseRequestToolComputerUse: Codable {
    let type: String = "computer_use_preview"
    
    /// The height of the computer display.
    let display_height: Int
    /// The width of the computer display.
    let display_width: Int
    /// The type of computer environment to control.
    let environment: String
}

public enum ModelReponseRequestToolWebSearchType: String, Codable {
    case web_search_preview
    case web_search_preview_2025_03_11
}

public enum ModelReponseRequestToolWebSearchContextSize: String, Codable {
    case low
    case medium
    case high
}

public struct ModelReponseRequestToolWebSearchUserLocation: Codable {
    let type: String = "approximate"
    /// Free text input for the city of the user, e.g. San Francisco.
    let city: String
    /// The two-letter [ISO country code](https://en.wikipedia.org/wiki/ISO_3166-1) of the user, e.g. US.
    let country: String
    /// Free text input for the region of the user, e.g. California.
    let region: String
    /// The [IANA timezone](https://timeapi.io/documentation/iana-timezones) of the user, e.g. `America/Los_Angeles`.
    let timezone: String
}

/// This tool searches the web for relevant results to use in a response.
///
/// Learn more about the [web search tool](https://platform.openai.com/docs/guides/tools-web-search).
public struct ModelReponseRequestToolWebSearch: Codable {
    /// The type of the web search tool.
    let type: ModelReponseRequestToolWebSearchType
    /// High level guidance for the amount of context window space to use for the search.
    /// medium is the default.
    let search_context_size: ModelReponseRequestToolWebSearchContextSize?
    
    /// Approximate location parameters for the search.
    let user_location: ModelReponseRequestToolWebSearchUserLocation
}

public enum ModelReponseRequestTool: Codable {
    case fileSearch(ModelReponseRequestToolFileSearch)
    case function(ModelReponseRequestToolFunction)
    case computerUse(ModelReponseRequestToolComputerUse)
    case webSearch(ModelReponseRequestToolWebSearch)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .fileSearch(let modelReponseRequestToolFileSearch):
            try container.encode(modelReponseRequestToolFileSearch)
        case .function(let modelReponseRequestToolFunction):
            try container.encode(modelReponseRequestToolFunction)
        case .computerUse(let modelReponseRequestToolComputerUse):
            try container.encode(modelReponseRequestToolComputerUse)
        case .webSearch(let modelReponseRequestToolWebSearch):
            try container.encode(modelReponseRequestToolWebSearch)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode each possible tool type
        if let fileSearch = try? container.decode(ModelReponseRequestToolFileSearch.self) {
            if fileSearch.type == "file_search" {
                self = .fileSearch(fileSearch)
                return
            }
        }
        
        if let function = try? container.decode(ModelReponseRequestToolFunction.self) {
            if function.type == "function" {
                self = .function(function)
                return
            }
        }
        
        if let computerUse = try? container.decode(ModelReponseRequestToolComputerUse.self) {
            if computerUse.type == "computer_use_preview" {
                self = .computerUse(computerUse)
                return
            }
        }
        
        if let webSearch = try? container.decode(ModelReponseRequestToolWebSearch.self) {
            self = .webSearch(webSearch)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestTool")
    }
}

public enum ModelReponseRequestTruncation: String, Codable {
    /// If the context of this response and previous ones exceeds the model's context window size,
    /// the model will truncate the response to fit the context window by dropping input items in the middle of the conversation.
    case auto
    /// If a model response will exceed the context window size for a model, the request will fail with a 400 error.
    case disabled
}

public struct ModelReponseRequest: Codable {
    /// Model ID used to generate the response, like gpt-4o or o1.
    /// OpenAI offers a wide range of models with different capabilities, performance characteristics, and price points.
    /// Refer to the [model](https://platform.openai.com/docs/models) guide to browse and compare available models.
    let model: String
    
    /// Text, image, or file inputs to the model, used to generate a response.
    let input: ModelReponseRequestInput
    
    /// Specify additional output data to include in the model response.
    let include: [ModelReponseRequestAdditionalData]?
    
    /// Inserts a system (or developer) message as the first item in the model's context.
    ///
    /// When using along with `previous_response_id`,
    /// the instructions from a previous response will not be carried over to the next response.
    /// This makes it simple to swap out system (or developer) messages in new responses.
    let instructions: String?
    
    /// An upper bound for the number of tokens that can be generated for a response,
    /// including visible output tokens and [reasoning tokens](https://platform.openai.com/docs/guides/reasoning).
    let max_output_tokens: Int?
    
    /// Set of 16 key-value pairs that can be attached to an object.
    /// This can be useful for storing additional information about the object in a structured format,
    /// and querying for objects via API or the dashboard.
    ///
    /// Keys are strings with a maximum length of 64 characters. Values are strings with a maximum length of 512 characters.
    let metadata: [String: String]?
    
    /// Whether to allow the model to run tool calls in parallel.
    /// Defaults to true.
    let parallel_tool_calls: Bool?
    
    /// The unique ID of the previous response to the model.
    /// Use this to create multi-turn conversations.
    /// Learn more about [conversation state](https://platform.openai.com/docs/guides/conversation-state).
    let previous_response_id: String?
    
    /// Configuration options for [reasoning models](https://platform.openai.com/docs/guides/reasoning).
    ///
    /// o-series models only
    let reasoning: ModelReponseRequestResoning?
    
    /// Whether to store the generated model response for later retrieval via API.
    ///
    /// Defaults to true
    let store: Bool?
    
    /// If set to true, the model response data will be streamed
    /// to the client as it is generated using [server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#Event_stream_format).
    /// See the [Streaming section](https://platform.openai.com/docs/api-reference/responses-streaming) below for more information.
    ///
    /// Defaults to false
    let stream: Bool?
    
    /// What sampling temperature to use, between 0 and 2.
    /// Higher values like 0.8 will make the output more random,
    /// while lower values like 0.2 will make it more focused and deterministic.
    /// We generally recommend altering this or `top_p` but not both.
    ///
    /// Defaults to 1
    let temperature: Double?
    
    /// Configuration options for a text response from the model.
    /// Can be plain text or structured JSON data.
    ///
    /// Learn more:
    /// [Text inputs and outputs](https://platform.openai.com/docs/guides/text)
    /// [Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs)
    let text: ModelReponseRequestTextConfigurationFormat?
    
    /// How the model should select which tool (or tools) to use when generating a response.
    /// See the tools parameter to see how to specify which tools the model can call.
    let toolChoice: ModelReponseRequestToolChoice?
    
    /// An array of tools the model may call while generating a response.
    /// You can specify which tool to use by setting the `tool_choice` parameter.
    ///
    /// The two categories of tools you can provide the model are:
    ///   - Built-in tools: Tools that are provided by OpenAI that extend the model's capabilities,
    ///     like [web search](https://platform.openai.com/docs/guides/tools-web-search) or [file search](https://platform.openai.com/docs/guides/tools-file-search).
    ///     Learn more about [built-in](https://platform.openai.com/docs/guides/tools) tools.
    ///   - Function calls (custom tools): Functions that are defined by you,
    ///     enabling the model to call your own code.
    ///     Learn more about [function calling](https://platform.openai.com/docs/guides/function-calling).
    let tools: ModelReponseRequestTool?
    
    /// An alternative to sampling with temperature, called nucleus sampling,
    /// where the model considers the results of the tokens with `top_p` probability mass.
    /// So 0.1 means only the tokens comprising the top 10% probability mass are considered.
    ///
    /// We generally recommend altering this or temperature but not both.
    /// Defaults to 1
    let top_p: Double?
    
    /// The truncation strategy to use for the model response.
    /// Defaults to disabled
    let truncation: ModelReponseRequestTruncation?
    
    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    /// [Learn more](https://platform.openai.com/docs/guides/safety-best-practices#end-user-ids).
    let user: String?
}

struct OpenAIConfiguration: Hashable, Codable, Sendable {
    let apiKey: String
    let apiURL: String
}

struct OpenAIClient {
    let httpClient: any HttpClientAbstract
    let configuration: OpenAIConfiguration
    
    init(httpClient: any HttpClientAbstract, configuration: OpenAIConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }
    
    func send(request: ModelReponseRequest) async throws -> HttpClientAbstract.Response {

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(configuration.apiKey)",
        ]

        let request = try {
            var req = HttpClientAbstract.Request(url: "\(configuration.apiURL)/responses")
            req.method = .POST
            req.headers = headers
            req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(request, allocator: .init()))
            return req
        }()
        
        return try await httpClient.send(request: request)
    }
}
