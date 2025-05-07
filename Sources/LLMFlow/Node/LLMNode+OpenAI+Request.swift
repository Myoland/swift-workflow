//
//  LLMNode+OpenAI+Request.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/6.
//

import Foundation
import DynamicJSON
import HTTPTypes
import NIOHTTP1
import WantLazy

/// https://platform.openai.com/docs/guides/pdf-files?api-mode=chat
public struct OpenAIModelReponseRequestInputItemMessageContentItemFileInput: Codable {
    public let type: OpenAIModelReponseRequestInputItemMessageContentType
    
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
public enum OpenAIModelReponseRequestInputItemMessageContentImageItemDetail: String, Codable {
    case high
    case low
    case auto
    
    // static let `default`: Self = .auto
}

/// An image input to the model.
/// Learn about [image inputs](https://platform.openai.com/docs/guides/images?api-mode=responses).
public struct OpenAIModelReponseRequestInputItemMessageContentItemImageInput: Codable {
    public let type: OpenAIModelReponseRequestInputItemMessageContentType
    
    public let detail: OpenAIModelReponseRequestInputItemMessageContentImageItemDetail
    
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
    
    init(detail: OpenAIModelReponseRequestInputItemMessageContentImageItemDetail, fileId: String?, imageUrl: String?) {
        self.type = .image
        self.detail = detail
        self.fileId = fileId
        self.imageUrl = imageUrl
    }
}

public struct OpenAIModelReponseRequestInputItemMessageContentItemTextInput: Codable {
    public let text: String
    public let type: OpenAIModelReponseRequestInputItemMessageContentType
    
    init(text: String) {
        self.text = text
        self.type = .text
    }
}

public enum OpenAIModelReponseRequestInputItemMessageContentType: String, Codable {
    case text = "input_text"
    case image = "input_image"
    case file = "input_file"
}

/// A list of one or many input items to the model, containing different content types.
public enum OpenAIModelReponseRequestInputItemMessageContentItem: Codable {
    case text(OpenAIModelReponseRequestInputItemMessageContentItemTextInput)
    case image(OpenAIModelReponseRequestInputItemMessageContentItemImageInput)
    case file(OpenAIModelReponseRequestInputItemMessageContentItemFileInput)
    
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
        if let textInput = try? container.decode(OpenAIModelReponseRequestInputItemMessageContentItemTextInput.self) {
            if textInput.type == .text {
                self = .text(textInput)
                return
            }
        }
        
        if let imageInput = try? container.decode(OpenAIModelReponseRequestInputItemMessageContentItemImageInput.self) {
            if imageInput.type == .image {
                self = .image(imageInput)
                return
            }
        }
        
        if let fileInput = try? container.decode(OpenAIModelReponseRequestInputItemMessageContentItemFileInput.self) {
            if fileInput.type == .file {
                self = .file(fileInput)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemMessageContentItem")
    }
}

public enum OpenAIModelReponseRequestInputItemMessageContent: Codable {
    case text(String)
    case inputs([OpenAIModelReponseRequestInputItemMessageContentItem])
    
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
        if let itemArray = try? container.decode([OpenAIModelReponseRequestInputItemMessageContentItem].self) {
            self = .inputs(itemArray)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemMessageContent")
    }
}

public enum OpenAIModelReponseRequestInputItemMessageRole: String, Codable {
    case user
    case assistant
    case system
    case developer
}

/// A message input to the model with a role indicating instruction following hierarchy.
/// Instructions given with the developer or system role take precedence over instructions given with the user role.
/// Messages with the assistant role are presumed to have been generated by the model in previous interactions.
public struct OpenAIModelReponseRequestInputItemMessage: Codable {
    
    /// Text, image, or audio input to the model, used to generate a response. Can also contain previous assistant responses.
    public let content: OpenAIModelReponseRequestInputItemMessageContent
    
    /// The role of the message input. One of user, assistant, system, or developer.
    public let role: OpenAIModelReponseRequestInputItemMessageRole
    
    public let type: ModelReponseRequestInputItemType?
    
    init(content: OpenAIModelReponseRequestInputItemMessageContent, role: OpenAIModelReponseRequestInputItemMessageRole) {
        self.content = content
        self.role = role
        self.type = .message
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decodeIfPresent(ModelReponseRequestInputItemType.self, forKey: .type)
        let role = try container.decode(OpenAIModelReponseRequestInputItemMessageRole.self, forKey: .role)
        let content = try container.decode(OpenAIModelReponseRequestInputItemMessageContent.self, forKey: .content)
        
        self.role = role
        self.content = content
        self.type = type
    }
}

/// Populated when items are returned via API.
public enum OpenAIModelReponseContextInputStatus: String, Codable {
    case inProgress = "in_progress"
    case completed
    case incomplete
}

public enum OpenAIModelReponseContextInputRole: Codable {
    case user
    case system
    case developer
}

/// A citation to a file.
public struct OpenAIModelReponseContextOutputContentTextOutputAnnotationFileCitation: Codable {
    let fileId: String
    let index: Int
    let type: OpenAIModelReponseContextOutputContentTextOutputAnnotationType = .file_citation
    
    public enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case index
        case type
    }
}

/// A citation for a web resource used to generate a model response.
public struct OpenAIModelReponseContextOutputContentTextOutputAnnotationURLCitation: Codable {
    let endIndex: Int
    let startIndex: Int
    let title: String
    let url: String
    let type: OpenAIModelReponseContextOutputContentTextOutputAnnotationType = .url_citation
    
    public enum CodingKeys: String, CodingKey {
        case endIndex = "end_index"
        case startIndex = "start_index"
        case title
        case url
        case type
    }
}

/// A path to a file.
public struct OpenAIModelReponseContextOutputContentTextOutputAnnotationFilePath: Codable {
    let fileId: String
    let index: Int
    let type: OpenAIModelReponseContextOutputContentTextOutputAnnotationType = .file_path
    
    public enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case index
        case type
    }
}

public enum OpenAIModelReponseContextOutputContentTextOutputAnnotationType: String, Codable {
    case file_citation
    case url_citation
    case file_path
}

public enum OpenAIModelReponseContextOutputContentTextOutputAnnotation: Codable {
    case fileCitation(OpenAIModelReponseContextOutputContentTextOutputAnnotationFileCitation)
    case url(OpenAIModelReponseContextOutputContentTextOutputAnnotationURLCitation)
    case filePath(OpenAIModelReponseContextOutputContentTextOutputAnnotationFilePath)
    
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
        
        if let fileCitation = try? container.decode(OpenAIModelReponseContextOutputContentTextOutputAnnotationFileCitation.self) {
            if fileCitation.type == .file_citation {
                self = .fileCitation(fileCitation)
                return
            }
        }
        
        if let urlCitation = try? container.decode(OpenAIModelReponseContextOutputContentTextOutputAnnotationURLCitation.self) {
            if urlCitation.type == .url_citation {
                self = .url(urlCitation)
                return
            }
        }
        
        if let filePath = try? container.decode(OpenAIModelReponseContextOutputContentTextOutputAnnotationFilePath.self) {
            if filePath.type == .file_path {
                self = .filePath(filePath)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContextOutputContentTextOutputAnnotation")
    }
}

// A text output from the model.
public struct OpenAIModelReponseContextOutputContentTextOutput: Codable {
    let annotations: [OpenAIModelReponseContextOutputContentTextOutputAnnotation]
    let text: String
    let type: String = "output_text"
    
    public enum CodingKeys: String, CodingKey {
        case annotations
        case text
        case type
    }
}

// The refusal explanationfrom the model.
public struct OpenAIModelReponseContextOutputContentRefusal: Codable {
    let refusal: String
    let type: String = "refusal"
    
    public enum CodingKeys: String, CodingKey {
        case refusal
        case type
    }
}

public enum OpenAIModelReponseContextOutputContent: Codable {
    case text(OpenAIModelReponseContextOutputContentTextOutput)
    case refusal(OpenAIModelReponseContextOutputContentRefusal)
    
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
        
        if let textOutput = try? container.decode(OpenAIModelReponseContextOutputContentTextOutput.self) {
            if textOutput.type == "output_text" {
                self = .text(textOutput)
                return
            }
        }
        
        if let refusal = try? container.decode(OpenAIModelReponseContextOutputContentRefusal.self) {
            if refusal.type == "refusal" {
                self = .refusal(refusal)
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItemContextOutputContent")
    }
}


public struct OpenAIModelReponseContextOutput: Codable {
    
    /// The unique ID of the output message.
    let id: String
    let content: OpenAIModelReponseContextOutputContent
    let role: String
    let type: String
    
    init(id: String, content: OpenAIModelReponseContextOutputContent) {
        self.id = id
        self.content = content
        self.role = "assistant"
        self.type = "message"
    }
}

/// A message input to the model with a role indicating instruction following hierarchy.
/// Instructions given with the developer or system role take precedence over instructions given with the user role.
public struct OpenAIModelReponseContextInput: Codable {
    
    let content: [OpenAIModelReponseRequestInputItemMessageContentItem]
    let role: OpenAIModelReponseContextInputRole
    let status: OpenAIModelReponseContextInputStatus?
    let type: String
    
    init(content: [OpenAIModelReponseRequestInputItemMessageContentItem],
         role: OpenAIModelReponseContextInputRole,
         status: OpenAIModelReponseContextInputStatus?
    ) {
        self.content = content
        self.role = role
        self.status = status
        self.type = "message"
    }
}

public enum OpenAIModelReponseContextWebSearchToolCallStatus: String, Codable {
    case inProgress = "in_progress"
    case searching
    case incomplete
    case failed
}

// The queries used to search for files.
public typealias OpenAIModelReponseContextFileSearchToolCallResultQuery = String

public struct OpenAIModelReponseContextFileSearchToolCallResult: Codable {
    /// Set of 16 key-value pairs that can be attached to an object.
    /// This can be useful for storing additional information about the object in a structured format,
    /// and querying for objects via API or the dashboard.
    /// Keys are strings with a maximum length of 64 characters.
    /// Values are strings with a maximum length of 512 characters, booleans, or numbers.
    let attributes: [String: String]?
    let fileId: String?
    let filename: String?
    let score: Double?
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case attributes
        case fileId = "file_id"
        case filename
        case score
        case text
    }
}

/// The queries used to [search for files](https://platform.openai.com/docs/guides/tools-file-search).
public struct OpenAIModelReponseContextFileSearchToolCall: Codable {
    let id: String
    let queries: [OpenAIModelReponseContextFileSearchToolCallResultQuery]
    let status: OpenAIModelReponseContextWebSearchToolCallStatus
    let type: String = "file_search_call"
    let results: [OpenAIModelReponseContextFileSearchToolCallResult]?
    
    public enum CodingKeys: String, CodingKey {
        case id
        case queries
        case status
        case type
        case results
    }
}

public enum ModelReponseRequestInputItemContextComputerToolCallActionClickButton: String, Codable {
    case left
    case right
    case wheel
    case back
    case forward
}

public struct OpenAIModelReponseContextComputerToolCallActionActionClick: Codable {
    let button: ModelReponseRequestInputItemContextComputerToolCallActionClickButton
    let type: String = "click"
    let x: Int
    let y: Int
    
    public enum CodingKeys: String, CodingKey {
        case button
        case type
        case x
        case y
    }
}

public struct OpenAIModelReponseContextComputerToolCallActionDoubleClick: Codable {
    let type: String = "double_click"
    let x: Int
    let y: Int
    
    public enum CodingKeys: String, CodingKey {
        case type
        case x
        case y
    }
}

public struct OpenAIModelReponseContextComputerToolCallActionDragCoordinate: Codable {
    let x: Int
    let y: Int
}

public struct OpenAIModelReponseContextComputerToolCallActionDrag: Codable {
    let type = "drag"
    /// An array of coordinates representing the path of the drag action. Coordinates will appear as an array of objects.
    let path: [OpenAIModelReponseContextComputerToolCallActionDragCoordinate]
    
    public enum CodingKeys: String, CodingKey {
        case type
        case path
    }
}

/// A collection of keypresses the model would like to perform.
public struct OpenAIModelReponseContextComputerToolCallActionKeyPress: Codable {
    let type: String = "keypress"
    /// The combination of keys the model is requesting to be pressed. This is an array of strings, each representing a key.
    let keys: [String]
    
    public enum CodingKeys: String, CodingKey {
        case type
        case keys
    }
}

/// A mouse move action.
public struct OpenAIModelReponseContextComputerToolCallActionMove: Codable {
    let type: String = "move"
    /// The x-coordinate to move to.
    let x: Int
    /// The y-coordinate to move to.
    let y: Int
    
    public enum CodingKeys: String, CodingKey {
        case type
        case x
        case y
    }
}

/// A screenshot action.
public struct OpenAIModelReponseContextComputerToolCallActionScreenshot: Codable {
    let type: String = "screenshot"
    
    public enum CodingKeys: String, CodingKey {
        case type
    }
}

/// A scroll action.
public struct OpenAIModelReponseContextComputerToolCallActionScroll: Codable {
    let type: String = "scroll"
    /// The horizontal scroll distance.
    let scrollX: Int
    /// The vertical scroll distance.
    let scrollY: Int
    /// The x-coordinate where the scroll occurred.
    let x: Int
    /// The y-coordinate where the scroll occurred.
    let y: Int
    
    public enum CodingKeys: String, CodingKey {
        case type
        case scrollX = "scroll_x"
        case scrollY = "scroll_y"
        case x
        case y
    }
}

/// An action to type in text.
public struct OpenAIModelReponseContextComputerToolCallActionType: Codable {
    let text: String
    let type: String = "type"
    
    public enum CodingKeys: String, CodingKey {
        case text
        case type
    }
}

/// A wait action.
public struct OpenAIModelReponseContextComputerToolCallActionWait: Codable {
    let type: String = "wait"
    
    public enum CodingKeys: String, CodingKey {
        case type
    }
}

public enum OpenAIModelReponseContextComputerToolCallAction: Codable {
    case click(OpenAIModelReponseContextComputerToolCallActionActionClick)
    case doubleClick(OpenAIModelReponseContextComputerToolCallActionDoubleClick)
    case drag(OpenAIModelReponseContextComputerToolCallActionDrag)
    case keyPress(OpenAIModelReponseContextComputerToolCallActionKeyPress)
    case move(OpenAIModelReponseContextComputerToolCallActionMove)
    case screenshot(OpenAIModelReponseContextComputerToolCallActionScreenshot)
    case scroll(OpenAIModelReponseContextComputerToolCallActionScroll)
    case type(OpenAIModelReponseContextComputerToolCallActionType)
    case wait(OpenAIModelReponseContextComputerToolCallActionWait)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .click(let click):
            try container.encode(click)
        case .doubleClick(let doubleClick):
            try container.encode(doubleClick)
        case .drag(let drag):
            try container.encode(drag)
        case .keyPress(let keyPress):
            try container.encode(keyPress)
        case .move(let move):
            try container.encode(move)
        case .screenshot(let screenshot):
            try container.encode(screenshot)
        case .scroll(let scroll):
            try container.encode(scroll)
        case .type(let type):
            try container.encode(type)
        case .wait(let wait):
            try container.encode(wait)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode each type based on the "type" field
        if let click = try? container.decode(OpenAIModelReponseContextComputerToolCallActionActionClick.self) {
            if click.type == "click" {
                self = .click(click)
                return
            }
        }
        
        if let doubleClick = try? container.decode(OpenAIModelReponseContextComputerToolCallActionDoubleClick.self) {
            if doubleClick.type == "double_click" {
                self = .doubleClick(doubleClick)
                return
            }
        }
        
        if let drag = try? container.decode(OpenAIModelReponseContextComputerToolCallActionDrag.self) {
            if drag.type == "drag" {
                self = .drag(drag)
                return
            }
        }
        
        if let keyPress = try? container.decode(OpenAIModelReponseContextComputerToolCallActionKeyPress.self) {
            if keyPress.type == "keypress" {
                self = .keyPress(keyPress)
                return
            }
        }
        
        if let move = try? container.decode(OpenAIModelReponseContextComputerToolCallActionMove.self) {
            if move.type == "move" {
                self = .move(move)
                return
            }
        }
        
        if let screenshot = try? container.decode(OpenAIModelReponseContextComputerToolCallActionScreenshot.self) {
            if screenshot.type == "screenshot" {
                self = .screenshot(screenshot)
                return
            }
        }
        
        if let scroll = try? container.decode(OpenAIModelReponseContextComputerToolCallActionScroll.self) {
            if scroll.type == "scroll" {
                self = .scroll(scroll)
                return
            }
        }
        
        if let type = try? container.decode(OpenAIModelReponseContextComputerToolCallActionType.self) {
            if type.type == "type" {
                self = .type(type)
                return
            }
        }
        
        if let wait = try? container.decode(OpenAIModelReponseContextComputerToolCallActionWait.self) {
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
public struct OpenAIModelReponseContextComputerToolCallRequest: Codable {
    let action: OpenAIModelReponseContextComputerToolCallAction
    /// An identifier used when responding to the tool call with output.
    let callId: String
    /// The unique ID of the computer call.
    let id: String
    let pendingSafetyChecks: [ModelReponseRequestInputItemContextComputerToolCallSafetyCheck]
    let status: ModelReponseRequestInputItemContextComputerToolCallStatus
    let type: String = "computer_call"
    
    public enum CodingKeys: String, CodingKey {
        case action
        case callId = "call_id"
        case id
        case pendingSafetyChecks = "pending_safety_checks"
        case status
        case type
    }
}

public enum ModelReponseRequestInputItemContextComputerToolCallOutputStatus: String, Codable {
    case in_progress
    case completed
    case incomplete
}

public struct ModelReponseRequestInputItemContextComputerToolCallOutputObject: Codable {
    let type: String = "computer_screenshot"
    /// The identifier of an uploaded file that contains the screenshot.
    let fileId: String?
    /// The URL of the screenshot image.
    let imageUrl: String?
    
    public enum CodingKeys: String, CodingKey {
        case type
        case fileId = "file_id"
        case imageUrl = "image_url"
    }
}

/// The output of a computer tool call.
public struct OpenAIModelReponseContextComputerToolCallReponse: Codable {
    let type: String = "computer_call_output"
    /// The ID of the computer tool call that produced the output.
    let callId: String
    /// The ID of the computer tool call output.
    let id: String?
    /// The status of the message input. Populated when input items are returned via API.
    let status: ModelReponseRequestInputItemContextComputerToolCallOutputStatus?
    /// A computer screenshot image used with the computer use tool.
    let output: ModelReponseRequestInputItemContextComputerToolCallOutputObject
    /// The safety checks reported by the API that have been acknowledged by the developer.
    let acknowledgeSafetyChecks: [ModelReponseRequestInputItemContextComputerToolCallSafetyCheck]?
    
    public enum CodingKeys: String, CodingKey {
        case type
        case callId = "call_id"
        case id
        case status
        case output
        case acknowledgeSafetyChecks = "acknowledge_safety_checks"
    }
}

/// The results of a web search tool call. See the [web search guide](https://platform.openai.com/docs/guides/tools-web-search) for more information.
public struct OpenAIModelReponseContextWebSearchToolCall: Codable {
    let id: String
    let status: OpenAIModelReponseContextWebSearchToolCallStatus
    let type: String = "web_search_call"
    
    public enum CodingKeys: String, CodingKey {
        case id
        case status
        case type
    }
}

public enum OpenAIModelReponseContextFuncToolCallStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// A tool call to run a function.
/// See the [function calling](https://platform.openai.com/docs/guides/function-calling?api-mode=responses) guide for more information.
public struct OpenAIModelReponseContextFuncToolCall: Codable {
    /// A JSON string of the arguments to pass to the function.
    let arguments: String
    
    /// The unique ID of the function tool call generated by the model.
    let callId: String
    
    /// The name of the function to run.
    let name: String
    
    let type: String = "function_call"
    
    /// The unique ID of the function tool call.
    let id: String?
    
    let status: OpenAIModelReponseContextFuncToolCallStatus?
    
    public enum CodingKeys: String, CodingKey {
        case arguments
        case callId = "call_id"
        case name
        case type
        case id
        case status
    }
}

public enum OpenAIModelReponseContextFuncToolCallOutputStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// The output of a function tool call.
public struct OpenAIModelReponseContextFuncToolCallOutput: Codable {
    /// The unique ID of the function tool call generated by the model.
    let callId: String
    
    /// A JSON string of the output of the function tool call.
    let output: String
    
    let type: String = "function_call_output"
    
    /// The unique ID of the function tool call output. Populated when this item is returned via API.
    let id: String?
    
    /// The status of the item. Populated when items are returned via API.
    let status: OpenAIModelReponseContextFuncToolCallOutputStatus?
    
    public enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case output
        case type
        case id
        case status
    }
}

public enum OpenAIModelReponseContextReasoningStatus: Codable {
    case in_progress
    case completed
    case incomplete
}

/// Reasoning text contents.
public struct OpenAIModelReponseContextReasoningSummaryTextContent: Codable {
    let type: String = "summary_text"
    /// A short summary of the reasoning used by the model when generating the
    let text: String
    
    public enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}

public struct OpenAIModelReponseContextReasoning: Codable {
    let id: String
    let summary: [OpenAIModelReponseContextReasoningSummaryTextContent]
    let type: String = "reasoning"
    /// The status of the item. Populated when items are returned via API.
    let status: OpenAIModelReponseContextReasoningStatus?
    
    public enum CodingKeys: String, CodingKey {
        case id
        case summary
        case type
        case status
    }
}

/// An item representing part of the context for the response to be generated by the model.
/// Can contain text, images, and audio inputs, as well as previous assistant responses and tool call outputs.
public enum OpenAIModelReponseContext: Codable {
    case input(OpenAIModelReponseContextInput)
    case output(OpenAIModelReponseContextOutput)
    case fileSearchToolCall(OpenAIModelReponseContextFileSearchToolCall)
    case computerToolCallRequest(OpenAIModelReponseContextComputerToolCallRequest)
    case computerToolResponse(OpenAIModelReponseContextComputerToolCallReponse)
    case webSearchToolCall(OpenAIModelReponseContextWebSearchToolCall)
    case funcToolCall(OpenAIModelReponseContextFuncToolCall)
    case funcToolCallResponse(OpenAIModelReponseContextFuncToolCallOutput)
    case reasoning(OpenAIModelReponseContextReasoning)
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .input(let input):
            try container.encode(input)
        case .output(let output):
            try container.encode(output)
        case .fileSearchToolCall(let fileSearchToolCall):
            try container.encode(fileSearchToolCall)
        case .computerToolCallRequest(let computerToolCallRequest):
            try container.encode(computerToolCallRequest)
        case .computerToolResponse(let computerToolResponse):
            try container.encode(computerToolResponse)
        case .webSearchToolCall(let webSearchToolCall):
            try container.encode(webSearchToolCall)
        case .funcToolCall(let funcToolCall):
            try container.encode(funcToolCall)
        case .funcToolCallResponse(let funcToolCallResponse):
            try container.encode(funcToolCallResponse)
        case .reasoning(let reasoning):
            try container.encode(reasoning)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding each possible type and check based on specific type fields
        if let input = try? container.decode(OpenAIModelReponseContextInput.self) {
            if input.type == "message" {
                self = .input(input)
                return
            }
        }
        
        if let output = try? container.decode(OpenAIModelReponseContextOutput.self) {
            if output.type == "message" {
                self = .output(output)
                return
            }
        }
        
        if let fileSearchToolCall = try? container.decode(OpenAIModelReponseContextFileSearchToolCall.self) {
            if fileSearchToolCall.type == "file_search_call" {
                self = .fileSearchToolCall(fileSearchToolCall)
                return
            }
        }
        
        if let computerToolCallRequest = try? container.decode(OpenAIModelReponseContextComputerToolCallRequest.self) {
            if computerToolCallRequest.type == "computer_call" {
                self = .computerToolCallRequest(computerToolCallRequest)
                return
            }
        }
        
        if let computerToolResponse = try? container.decode(OpenAIModelReponseContextComputerToolCallReponse.self) {
            if computerToolResponse.type == "computer_call_output" {
                self = .computerToolResponse(computerToolResponse)
                return
            }
        }
        
        if let webSearchToolCall = try? container.decode(OpenAIModelReponseContextWebSearchToolCall.self) {
            if webSearchToolCall.type == "web_search_call" {
                self = .webSearchToolCall(webSearchToolCall)
                return
            }
        }
        
        if let funcToolCall = try? container.decode(OpenAIModelReponseContextFuncToolCall.self) {
            if funcToolCall.type == "function_call" {
                self = .funcToolCall(funcToolCall)
                return
            }
        }
        
        if let funcToolCallResponse = try? container.decode(OpenAIModelReponseContextFuncToolCallOutput.self) {
            if funcToolCallResponse.type == "function_call_output" {
                self = .funcToolCallResponse(funcToolCallResponse)
                return
            }
        }
        
        if let reasoning = try? container.decode(OpenAIModelReponseContextReasoning.self) {
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
    
    public enum CodingKeys: String, CodingKey {
        case id
        case type
    }
}

public enum OpenAIModelReponseRequestInputItem: Codable {
    case message(OpenAIModelReponseRequestInputItemMessage)
    case output(OpenAIModelReponseContext)
    case reference(ModelReponseRequestInputItemReference)
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let modelReponseRequestInputItemMessage = try? container.decode(OpenAIModelReponseRequestInputItemMessage.self) {
            self = .message(modelReponseRequestInputItemMessage)
            return
        }
        
        if let modelReponseRequestInputItemContext = try? container.decode(OpenAIModelReponseContext.self) {
            self = .output(modelReponseRequestInputItemContext)
            return
        }
        
        if let modelReponseRequestInputItemReference = try? container.decode(ModelReponseRequestInputItemReference.self) {
            self = .reference(modelReponseRequestInputItemReference)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestInputItem")
    }
    
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .message(let modelReponseRequestInputItemMessage):
            try container.encode(modelReponseRequestInputItemMessage)
        case .output(let modelReponseRequestInputItemContext):
            try container.encode(modelReponseRequestInputItemContext)
        case .reference(let modelReponseRequestInputItemReference):
            try container.encode(modelReponseRequestInputItemReference)
        }
    }
}

public enum OpenAIModelReponseRequestInput: Codable {
    case text(String)
    case items([OpenAIModelReponseRequestInputItem])
    
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
        if let itemsArray = try? container.decode([OpenAIModelReponseRequestInputItem].self) {
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

public enum ModelReponseRequestResoningSummary: Codable {
    case auto
    case concise
    case detailed
}

public struct OpenAIModelReponseRequestResoning: Codable {
    
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
    let summary: ModelReponseRequestResoningSummary?
    
    enum CodingKeys: String, CodingKey {
        case effort
        case summary = "summary"
    }
}

public struct ModelReponseRequestTextConfigurationFormatText: Codable {
    let type: String = "text"
    
    public enum CodingKeys: String, CodingKey {
        case type
    }
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
    
    public enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case strict
        case schema
    }
}

/// JSON object response format.
/// An older method of generating JSON responses.
/// Using `json_schema` is recommended for models that support it.
/// Note that the model will not generate JSON without a system or user message instructing it to do so.
public struct ModelReponseRequestTextConfigurationFormatJson: Codable {
    let type: String = "json_object"
    
    public enum CodingKeys: String, CodingKey {
        case type
    }
}

public enum ModelReponseRequestTextConfigurationFormat: Codable {
    case text(ModelReponseRequestTextConfigurationFormatText)
    case jsonSchema(ModelReponseRequestTextConfigurationFormatJsonSchema)
    case json(ModelReponseRequestTextConfigurationFormatJson)
}

public struct openAIModelReponseRequestTextConfiguration: Codable {
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
    
    public enum CodingKeys: String, CodingKey {
        case name
        case type
    }
}

public enum OpenAIModelReponseRequestToolChoice: Codable {
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
    let scoreThreshold: Double?
    
    enum CodingKeys: String, CodingKey {
        case ranker
        case scoreThreshold = "score_threshold"
    }
}

/// A tool that searches for relevant content from uploaded files.
///
/// Learn more about the [file search tool](https://platform.openai.com/docs/guides/tools-file-search).
public struct OpenAIModelReponseRequestToolFileSearch: Codable {
    let type: String = "file_search"
    
    /// The IDs of the vector stores to search.
    let vectorStoreIds: [String]
    
    /// A filter to apply based on file attributes.
    let filters: [ModelReponseRequestToolFileSearchFilter]?
    let maxNumResults: Int?
    
    /// Ranking options for search.
    let rankingOptions: ModelReponseRequestToolFileSearchRankingOption?
    
    public enum CodingKeys: String, CodingKey {
        case type
        case vectorStoreIds = "vector_store_ids"
        case filters
        case maxNumResults = "max_num_results"
        case rankingOptions = "ranking_options"
    }
}

/// Defines a function in your own code the model can choose to call.
///
/// Learn more about [function calling](https://platform.openai.com/docs/guides/function-calling).
public struct OpenAIModelReponseRequestToolFunction: Codable {
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
    
    public enum CodingKeys: String, CodingKey {
        case type
        case name
        case parameters
        case strict
        case description
    }
}

/// A tool that controls a virtual computer.
///
/// Learn more about the [computer tool](https://platform.openai.com/docs/guides/tools-computer-use).
public struct OpenAIModelReponseRequestToolComputerUse: Codable {
    let type: String = "computer_use_preview"
    
    /// The height of the computer display.
    let displayHeight: Int
    /// The width of the computer display.
    let displayWidth: Int
    /// The type of computer environment to control.
    let environment: String
    
    public enum CodingKeys: String, CodingKey {
        case type
        case displayHeight = "display_height"
        case displayWidth = "display_width"
        case environment
    }
}

public enum OpenAIModelReponseRequestToolWebSearchType: String, Codable {
    case web_search_preview
    case web_search_preview_2025_03_11
}

public enum OpenAIModelReponseRequestToolWebSearchContextSize: String, Codable {
    case low
    case medium
    case high
}

public struct OpenAIModelReponseRequestToolWebSearchUserLocation: Codable {
    let type: String = "approximate"
    /// Free text input for the city of the user, e.g. San Francisco.
    let city: String
    /// The two-letter [ISO country code](https://en.wikipedia.org/wiki/ISO_3166-1) of the user, e.g. US.
    let country: String
    /// Free text input for the region of the user, e.g. California.
    let region: String
    /// The [IANA timezone](https://timeapi.io/documentation/iana-timezones) of the user, e.g. `America/Los_Angeles`.
    let timezone: String
    
    public enum CodingKeys: String, CodingKey {
        case type
        case city
        case country
        case region
        case timezone
    }
}

/// This tool searches the web for relevant results to use in a response.
///
/// Learn more about the [web search tool](https://platform.openai.com/docs/guides/tools-web-search).
public struct OpenAIModelReponseRequestToolWebSearch: Codable {
    /// The type of the web search tool.
    let type: OpenAIModelReponseRequestToolWebSearchType
    /// High level guidance for the amount of context window space to use for the search.
    /// medium is the default.
    let searchContextSize: OpenAIModelReponseRequestToolWebSearchContextSize?
    
    /// Approximate location parameters for the search.
    let userLocation: OpenAIModelReponseRequestToolWebSearchUserLocation
    
    enum CodingKeys: String, CodingKey {
        case type
        case searchContextSize = "search_context_size"
        case userLocation = "user_location"
    }
}

public enum OpenAIModelReponseRequestTool: Codable {
    case fileSearch(OpenAIModelReponseRequestToolFileSearch)
    case function(OpenAIModelReponseRequestToolFunction)
    case computerUse(OpenAIModelReponseRequestToolComputerUse)
    case webSearch(OpenAIModelReponseRequestToolWebSearch)
    
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
        if let fileSearch = try? container.decode(OpenAIModelReponseRequestToolFileSearch.self) {
            if fileSearch.type == "file_search" {
                self = .fileSearch(fileSearch)
                return
            }
        }
        
        if let function = try? container.decode(OpenAIModelReponseRequestToolFunction.self) {
            if function.type == "function" {
                self = .function(function)
                return
            }
        }
        
        if let computerUse = try? container.decode(OpenAIModelReponseRequestToolComputerUse.self) {
            if computerUse.type == "computer_use_preview" {
                self = .computerUse(computerUse)
                return
            }
        }
        
        if let webSearch = try? container.decode(OpenAIModelReponseRequestToolWebSearch.self) {
            self = .webSearch(webSearch)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ModelReponseRequestTool")
    }
}

public enum OpenAIModelReponseRequestTruncation: String, Codable {
    /// If the context of this response and previous ones exceeds the model's context window size,
    /// the model will truncate the response to fit the context window by dropping input items in the middle of the conversation.
    case auto
    /// If a model response will exceed the context window size for a model, the request will fail with a 400 error.
    case disabled
}

public struct OpenAIModelReponseRequest: Codable {
    /// Model ID used to generate the response, like gpt-4o or o1.
    /// OpenAI offers a wide range of models with different capabilities, performance characteristics, and price points.
    /// Refer to the [model](https://platform.openai.com/docs/models) guide to browse and compare available models.
    let model: String
    
    /// Text, image, or file inputs to the model, used to generate a response.
    let input: OpenAIModelReponseRequestInput
    
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
    let maxOutputTokens: Int?
    
    /// Set of 16 key-value pairs that can be attached to an object.
    /// This can be useful for storing additional information about the object in a structured format,
    /// and querying for objects via API or the dashboard.
    ///
    /// Keys are strings with a maximum length of 64 characters. Values are strings with a maximum length of 512 characters.
    let metadata: [String: String]?
    
    /// Whether to allow the model to run tool calls in parallel.
    /// Defaults to true.
    let parallelToolCalls: Bool?
    
    /// The unique ID of the previous response to the model.
    /// Use this to create multi-turn conversations.
    /// Learn more about [conversation state](https://platform.openai.com/docs/guides/conversation-state).
    let previousResponseId: String?
    
    /// Configuration options for [reasoning models](https://platform.openai.com/docs/guides/reasoning).
    ///
    /// o-series models only
    let reasoning: OpenAIModelReponseRequestResoning?
    
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
    let text: openAIModelReponseRequestTextConfiguration?
    
    /// How the model should select which tool (or tools) to use when generating a response.
    /// See the tools parameter to see how to specify which tools the model can call.
    let toolChoice: OpenAIModelReponseRequestToolChoice?
    
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
    let tools: OpenAIModelReponseRequestTool?
    
    /// An alternative to sampling with temperature, called nucleus sampling,
    /// where the model considers the results of the tokens with `top_p` probability mass.
    /// So 0.1 means only the tokens comprising the top 10% probability mass are considered.
    /// We generally recommend altering this or `temperature` but not both.
    let topP: Double?
    
    /// The truncation strategy to use for the model response.
    /// Defaults to disabled
    let truncation: OpenAIModelReponseRequestTruncation?
    
    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    /// [Learn more](https://platform.openai.com/docs/guides/safety-best-practices#end-user-ids).
    let user: String?
    
    enum CodingKeys: String, CodingKey {
        case model
        case input
        case include
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case metadata
        case parallelToolCalls = "parallel_tool_calls"
        case previousResponseId = "previous_response_id"
        case reasoning
        case store
        case stream
        case temperature
        case text
        case toolChoice
        case tools
        case topP = "top_p"
        case truncation
        case user
    }
}
