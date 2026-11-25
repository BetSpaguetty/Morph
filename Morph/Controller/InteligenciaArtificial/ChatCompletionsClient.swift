//===----------------------------------------------------------------------===//
//
// This source file is part of the Foundation Models open source project.
//
// Copyright © 2024-2027 Apple Inc. and the Foundation Models project authors.
//
// Licensed under the Apache License v2.0
//
// See LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FoundationModels

struct ChatCompletionsClient {
  let baseURL: URL
  let headers: [String: String]
  let session: URLSession

  func streamChatCompletions(
    request: ChatCompletionRequest
  ) -> AsyncThrowingStream<ChatCompletionChunk, Swift.Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          let urlRequest = try buildURLRequest(for: request)
          #if canImport(Darwin)
          let (stream, response) = try await session.bytes(for: urlRequest)
          let httpResponse = response as! HTTPURLResponse

          guard httpResponse.statusCode == 200 else {
            throw ChatCompletionsLanguageModel.RequestError.httpError(
              statusCode: httpResponse.statusCode,
              data: try await stream.reduce(Data(), { $0 + [$1] })
            )
          }

          for try await line in stream.lines {
            if let chunk = try parseStreamLine(line) {
              continuation.yield(chunk)
            }
          }

          continuation.finish()
          #else
          let (data, response) = try await session.data(for: urlRequest)
          let httpResponse = response as! HTTPURLResponse

          guard httpResponse.statusCode == 200 else {
            throw ChatCompletionsLanguageModel.RequestError.httpError(
              statusCode: httpResponse.statusCode,
              data: data
            )
          }

          let body = String(data: data, encoding: .utf8) ?? ""
          for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if let chunk = try parseStreamLine(String(line)) {
              continuation.yield(chunk)
            }
          }

          continuation.finish()
          #endif

        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func buildURLRequest(for request: ChatCompletionRequest) throws -> URLRequest {
    let isVersioned = baseURL.pathComponents.contains { component in
      component.wholeMatch(of: #/v\d+/#) != nil
    }
    let endpoint = (isVersioned || baseURL.path.contains("/openai")) ? "/chat/completions" : "/v1/chat/completions"
    let url = baseURL.appendingPathComponent(endpoint)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    for (header, value) in headers {
      urlRequest.setValue(value, forHTTPHeaderField: header)
    }

    let encoder = JSONEncoder()
    urlRequest.httpBody = try encoder.encode(request)

    return urlRequest
  }

  func parseStreamLine(_ line: String) throws -> ChatCompletionChunk? {
    let trimmedLine = line.trimmingCharacters(in: .whitespaces)

    // Skip empty lines and comments
    guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix(":") else {
      return nil
    }

    if trimmedLine.hasPrefix("data: ") {
      let jsonString = String(trimmedLine.dropFirst(6))  // Remove "data: "

      if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
        return nil
      }

      guard let jsonData = jsonString.data(using: .utf8) else {
        throw ChatCompletionsLanguageModel.RequestError.invalidStreamData
      }

      let decoder = JSONDecoder()
      do {
        return try decoder.decode(ChatCompletionChunk.self, from: jsonData)
      } catch {
        if let response = try? decoder.decode(
          ChatCompletionsLanguageModel.ErrorResponse.self,
          from: jsonData
        ) {
          throw ChatCompletionsLanguageModel.APIError(
            message: response.error.message,
            type: response.error.type,
            param: response.error.param,
            code: response.error.code
          )
        }
        throw error
      }
    }

    return nil
  }

  struct ChatCompletionRequest: Encodable {
    enum ToolChoiceMode: String, Encodable {
      case auto
      case required
      case none
    }

    struct ToolChoice: Encodable {
      let mode: ToolChoiceMode

      func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(mode)
      }
    }

    var model: String
    var messages: [ChatMessage]
    var temperature: Double?
    var topP: Double?
    var maxCompletionTokens: Int?
    var tools: [Tool]?
    var toolChoice: ChatCompletionRequest.ToolChoice?
    var responseFormat: ResponseFormat?
    var stream = true
    var streamOptions = StreamOptions(includeUsage: true)

    struct StreamOptions: Encodable {
      var includeUsage: Bool

      private enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
      }
    }

    private enum CodingKeys: String, CodingKey {
      case model
      case messages
      case temperature
      case topP = "top_p"
      case maxCompletionTokens = "max_completion_tokens"
      case tools
      case responseFormat = "response_format"
      case stream
      case streamOptions = "stream_options"
      case toolChoice = "tool_choice"
    }
  }

  struct ChatMessage: Encodable {
    var role: Role
    var content: [MessageContent]
    var toolCalls: [ToolCall]?
    var toolCallID: String?
    var reasoningContent: String?

    private enum CodingKeys: String, CodingKey {
      case role
      case content
      case toolCalls = "tool_calls"
      case toolCallID = "tool_call_id"
      case reasoningContent = "reasoning_content"
    }

    enum Role: String, Encodable {
      case system
      case user
      case assistant
      case tool
    }

    init(
      role: Role,
      content: [MessageContent] = [],
      toolCalls: [ToolCall]? = nil,
      toolCallID: String? = nil,
      reasoningContent: String? = nil
    ) {
      self.role = role
      self.content = content
      self.toolCalls = toolCalls
      self.toolCallID = toolCallID
      self.reasoningContent = reasoningContent
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(role, forKey: .role)

      let hasToolCalls = toolCalls?.isEmpty == false
      let compactText = content.count == 1 ? content.first?.text : nil

      if let compactText {
        try container.encode(compactText, forKey: .content)
      } else if !hasToolCalls && !content.isEmpty {
        try container.encode(content, forKey: .content)
      }

      try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
      try container.encodeIfPresent(toolCallID, forKey: .toolCallID)
      try container.encodeIfPresent(reasoningContent, forKey: .reasoningContent)
    }
  }

  struct Tool: Encodable {
    var type: String = "function"
    var function: Function

    struct Function: Encodable {
      let name: String
      let description: String
      let parameters: GenerationSchema
    }
  }

  struct ToolCall: Codable {
    var id: String
    var type = "function"
    var function: FunctionCall

    struct FunctionCall: Codable {
      var name: String
      var arguments: String
    }
  }

  struct ResponseFormat: Encodable {
    var type = "json_schema"
    var jsonSchema: JSONSchemaWrapper

    private enum CodingKeys: String, CodingKey {
      case type
      case jsonSchema = "json_schema"
    }

    struct JSONSchemaWrapper: Encodable {
      var name: String
      var description: String?
      var schema: GenerationSchema
      var strict = true
    }
  }

  struct ChatCompletionChunk: Decodable {
    let id: String
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
      let delta: Delta

      struct Delta: Decodable {
        var role: String?
        var content: String?
        var reasoningContent: String?
        var toolCalls: [ToolCallDelta]?

        enum CodingKeys: String, CodingKey {
          case role
          case content
          case reasoningContent = "reasoning_content"
          case toolCalls = "tool_calls"
        }
      }
    }

    struct ToolCallDelta: Decodable {
      let index: Int
      let id: String?
      let type: String?
      let function: FunctionCallDelta?

      struct FunctionCallDelta: Decodable {
        let name: String?
        let arguments: String?
      }
    }

    struct Usage: Decodable {
      let promptTokens: Int
      let completionTokens: Int
      let promptTokensDetails: PromptTokensDetails?
      let completionTokensDetails: CompletionTokensDetails?

      struct PromptTokensDetails: Decodable {
        let cachedTokens: Int?

        private enum CodingKeys: String, CodingKey {
          case cachedTokens = "cached_tokens"
        }
      }

      struct CompletionTokensDetails: Decodable {
        let reasoningTokens: Int?

        private enum CodingKeys: String, CodingKey {
          case reasoningTokens = "reasoning_tokens"
        }
      }

      private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
      }
    }
  }

  struct MessageContent: Codable {
    var type: ContentType
    var text: String?
    var imageURL: ImageURL?

    enum CodingKeys: String, CodingKey {
      case type
      case text
      case imageURL = "image_url"
    }

    enum ContentType: String, Codable {
      case text
      case imageURL = "image_url"
    }

    struct ImageURL: Codable {
      var url: URL
      var detail: String? = "auto"
    }

    init(text: String) {
      self.type = .text
      self.text = text
      self.imageURL = nil
    }

    init(imageURL: ImageURL) {
      self.type = .imageURL
      self.text = nil
      self.imageURL = imageURL
    }
  }
}
