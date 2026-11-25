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
#if canImport(CoreImage)
import CoreImage
import UniformTypeIdentifiers
#endif

/// A `LanguageModel` that talks to any OpenAI-compatible
/// `/chat/completions` endpoint, streaming results back through the
/// Foundation Models framework.
///
/// Use this model to drive a `LanguageModelSession` against any remote
/// service that implements the OpenAI Chat Completions API.
///
/// ```swift
/// let model = ChatCompletionsLanguageModel(
///     name: "your-model-name",
///     url: URL(string: "https://api.example.com")!,
///     additionalHeaders: ["Authorization": "Bearer \(apiKey)"]
/// )
///
/// let session = LanguageModelSession(model: model)
/// let response = try await session.respond(to: "Hello!")
/// ```
public struct ChatCompletionsLanguageModel: Sendable {
  /// The name of the underlying model, sent in the `model` field of each
  /// chat completion request.
  public var name: String

  /// The base URL of the chat completions endpoint. The path
  /// `/v1/chat/completions` is appended automatically when the supplied
  /// URL does not already include a version segment matching `v<digits>`
  /// (for example `v1`, `v2`, or `v3`). When a version segment is
  /// present, only `/chat/completions` is appended.
  public var url: URL

  /// Headers added to every outgoing request, merged on top of the
  /// defaults. Use this to provide authorization tokens or other
  /// vendor-specific headers.
  public var additionalHeaders: [String: String]

  public var supportsGuidedGeneration: Bool

  // Overridden in tests to inject a URLSession with mock protocol handlers.
  var urlSession: URLSession?

  /// Creates a chat completions language model.
  ///
  /// - Parameters:
  ///   - name: The model identifier sent in the `model` field of each
  ///     request.
  ///   - url: The base URL of the chat completions endpoint.
  ///   - additionalHeaders: Headers to merge on top of the defaults
  ///     (for example, an `Authorization` header).
  ///   - supportsGuidedGeneration: Whether the endpoint supports the
  ///     `response_format` field for structured output. Defaults to `true`.
  ///   - urlSessionConfiguration: An optional `URLSessionConfiguration` used
  ///     to build the `URLSession` that drives requests. Use this to tune
  ///     timeouts, proxies, or other transport settings. When `nil`, an
  ///     ephemeral configuration is used.
  public init(
    name: String,
    url: URL,
    additionalHeaders: [String: String] = [:],
    supportsGuidedGeneration: Bool = true,
    urlSessionConfiguration: URLSessionConfiguration? = nil
  ) {
    self.name = name
    self.url = url
    self.additionalHeaders = additionalHeaders
    self.supportsGuidedGeneration = supportsGuidedGeneration
    self.urlSession = urlSessionConfiguration.map { URLSession(configuration: $0) }
  }

  public struct DirectResponse<Content: Sendable>: Sendable {
    public let content: Content
    public let promptTokens: Int?
    public let cachedPromptTokens: Int?
    public let completionTokens: Int?
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  public func respondDirect<Content: Generable & Sendable>(
    instructions: String,
    prompt: String,
    generating type: Content.Type,
    temperature: Double? = nil
  ) async throws -> DirectResponse<Content> {
    let client = Self.makeClient(
      url: url,
      additionalHeaders: additionalHeaders,
      urlSession: urlSession
    )
    let responseFormat: ChatCompletionsClient.ResponseFormat? = supportsGuidedGeneration
      ? ChatCompletionsClient.ResponseFormat(
          jsonSchema: ChatCompletionsClient.ResponseFormat.JSONSchemaWrapper(
            name: String(describing: Content.self),
            schema: Content.generationSchema
          )
        )
      : nil
    let chatRequest = ChatCompletionsClient.ChatCompletionRequest(
      model: name,
      messages: [
        ChatCompletionsClient.ChatMessage(
          role: .system,
          content: [ChatCompletionsClient.MessageContent(text: instructions)]
        ),
        ChatCompletionsClient.ChatMessage(
          role: .user,
          content: [ChatCompletionsClient.MessageContent(text: prompt)]
        )
      ],
      temperature: temperature,
      responseFormat: responseFormat
    )

    var jsonText = ""
    var promptTokens: Int?
    var cachedPromptTokens: Int?
    var completionTokens: Int?
    for try await chunk in client.streamChatCompletions(request: chatRequest) {
      if let text = chunk.choices.first?.delta.content {
        jsonText += text
      }
      if let usage = chunk.usage {
        promptTokens = usage.promptTokens
        cachedPromptTokens = usage.promptTokensDetails?.cachedTokens ?? 0
        completionTokens = usage.completionTokens
      }
    }

    let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw RequestError.invalidStreamData
    }
    let generated = try GeneratedContent(json: trimmed)
    let content = try Content(generated)
    return DirectResponse(
      content: content,
      promptTokens: promptTokens,
      cachedPromptTokens: cachedPromptTokens,
      completionTokens: completionTokens
    )
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  nonisolated fileprivate static func makeClient(
    url: URL,
    additionalHeaders: [String: String],
    urlSession: URLSession?
  ) -> ChatCompletionsClient {
    let headers = [
      "Content-Type": "application/json",
      "Accept": "text/event-stream",
      "User-Agent": Bundle.main.bundleIdentifier ?? "com.apple.FoundationModels"
    ].merging(
      additionalHeaders,
      uniquingKeysWith: { _, custom in custom }
    )
    return ChatCompletionsClient(
      baseURL: url,
      headers: headers,
      session: urlSession ?? URLSession(configuration: .ephemeral)
    )
  }

  /// An error returned by the chat completions endpoint in the body of a
  /// failed request or a streaming error event.
  ///
  /// Servers may populate any subset of the optional fields.
  public struct APIError: LocalizedError {
    /// A human-readable explanation of the error returned by the server.
    public var message: String

    /// The error category reported by the server (for example,
    /// `"invalid_request_error"`).
    public var type: String?

    /// The name of the request parameter associated with the error,
    /// when applicable.
    public var param: String?

    /// A short machine-readable error code provided by the server.
    public var code: String?

    /// Creates a new API error.
    ///
    /// - Parameters:
    ///   - message: A human-readable explanation of the error.
    ///   - type: The error category reported by the server.
    ///   - param: The request parameter associated with the error.
    ///   - code: A short machine-readable error code.
    public init(
      message: String,
      type: String? = nil,
      param: String? = nil,
      code: String? = nil
    ) {
      self.message = message
      self.type = type
      self.param = param
      self.code = code
    }
  }

  /// An error raised by ``ChatCompletionsLanguageModel`` when a request
  /// cannot be issued or its response cannot be parsed.
  public enum RequestError: LocalizedError {
    /// The request could not be constructed because of invalid input.
    /// The associated value contains a human-readable description.
    case invalidRequest(_ description: String)

    /// A streaming chunk could not be decoded as a chat completion event.
    case invalidStreamData

    /// The endpoint returned a non-200 HTTP status code. The associated
    /// values contain the status code and the raw response body.
    case httpError(statusCode: Int, data: Data)

    public var errorDescription: String? {
      switch self {
      case .invalidRequest(let description):
        "Invalid request: \(description)"
      case .invalidStreamData:
        "Invalid streaming data received"
      case .httpError(let statusCode, let data):
        """
        HTTP error with status code \(statusCode):
        \(String(data: data, encoding: .utf8) ?? data.description)
        """
      }
    }
  }

  /// The wire format of an error envelope returned by the chat completions
  /// endpoint, used internally to decode error responses before raising
  /// them as ``APIError``.
  struct ErrorResponse: Codable, Sendable {
    var error: APIError

    struct APIError: Codable, Sendable {
      var message: String
      var type: String?
      var param: String?
      var code: String?
    }
  }

}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
@available(tvOS, unavailable)
extension ChatCompletionsLanguageModel: LanguageModel {
  // Implementation of LanguageModel Protocol
  public var capabilities: LanguageModelCapabilities {
    if supportsGuidedGeneration {
      LanguageModelCapabilities([.vision, .toolCalling, .reasoning, .guidedGeneration])
    } else {
      LanguageModelCapabilities([.vision, .toolCalling, .reasoning])
    }
  }

  public var executorConfiguration: Executor.Configuration {
    Executor.Configuration(
      modelName: name,
      url: url,
      additionalHeaders: additionalHeaders,
      urlSession: urlSession
    )
  }

  public struct Executor: LanguageModelExecutor {
    public typealias Model = ChatCompletionsLanguageModel
    private let configuration: Configuration

    public init(configuration: Configuration) {
      self.configuration = configuration
    }

    public struct Configuration: Hashable, Sendable {
      fileprivate let modelName: String
      fileprivate let url: URL
      fileprivate let additionalHeaders: [String: String]
      fileprivate let urlSession: URLSession?

      public static func == (lhs: Configuration, rhs: Configuration) -> Bool {
        lhs.modelName == rhs.modelName
          && lhs.url == rhs.url
          && lhs.additionalHeaders == rhs.additionalHeaders
      }

      public func hash(into hasher: inout Hasher) {
        hasher.combine(modelName)
        hasher.combine(url)
        hasher.combine(additionalHeaders)
      }
    }

    public func respond(
      to request: LanguageModelExecutorGenerationRequest,
      model: ChatCompletionsLanguageModel,
      streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
      let client = ChatCompletionsLanguageModel.makeClient(
        url: configuration.url,
        additionalHeaders: configuration.additionalHeaders,
        urlSession: configuration.urlSession
      )

      // Translate the framework's request into the OpenAI-compatible wire format.
      let chatRequest = ChatCompletionsClient.ChatCompletionRequest(
        model: configuration.modelName,
        messages: try convertedTranscript(request.transcript),
        temperature: request.generationOptions.temperature,
        topP: try request.generationOptions.samplingMode.map(topP),
        maxCompletionTokens: request.generationOptions.maximumResponseTokens,
        tools: request.enabledToolDefinitions.map { tool in
          ChatCompletionsClient.Tool(
            function: ChatCompletionsClient.Tool.Function(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters
            )
          )
        },
        toolChoice: ChatCompletionsClient.ChatCompletionRequest.ToolChoice(
          mode: {
            switch request.generationOptions.toolCallingMode?.kind {
            case .allowed, .none: .auto
            case .required: .required
            case .disallowed: .none
            @unknown default: .auto
            }
          }()
        ),
        responseFormat: request.schema.map { schema in
          ChatCompletionsClient.ResponseFormat(
            jsonSchema: ChatCompletionsClient.ResponseFormat.JSONSchemaWrapper(
              name: schema.name,
              schema: schema
            )
          )
        }
      )

      // Stream the response back into the framework via `channel`.
      try await Self.processChunks(
        client.streamChatCompletions(request: chatRequest),
        into: channel
      )
    }

    private static func processChunks<ChunkSequence: AsyncSequence>(
      _ chunks: ChunkSequence,
      into channel: LanguageModelExecutorGenerationChannel
    ) async throws where ChunkSequence.Element == ChatCompletionsClient.ChatCompletionChunk {
      // Per-index `id`/`name` for tool calls. The first delta for a given
      // index supplies them; later deltas at the same index typically carry
      // only argument fragments and are routed using these latched values.
      // Argument accumulation is the framework's job — we just forward each
      // delta via `.appendArguments`.
      var toolCallRouting: [Int: (id: String, name: String)] = [:]

      // Stable entryIDs per event type for the duration of this stream.
      // Without these, interleaved reasoning/response/toolCalls chunks would
      // split into multiple transcript entries — the framework only coalesces
      // consecutive events of the same type into the trailing entry.
      let responseEntryID = UUID().uuidString
      let reasoningEntryID = UUID().uuidString
      let toolCallsEntryID = UUID().uuidString

      for try await chunk in chunks {
        if let delta = chunk.choices.first?.delta {
          if let reasoning = delta.reasoningContent {
            await channel.send(
              .reasoning(
                entryID: reasoningEntryID,
                action: .appendText(reasoning, tokenCount: 1)
              )
            )
          }

          if let toolCallDeltas = delta.toolCalls {
            for toolCallDelta in toolCallDeltas {
              let existing = toolCallRouting[toolCallDelta.index] ?? (id: "", name: "")
              let routing = (
                id: existing.id + (toolCallDelta.id ?? ""),
                name: existing.name + (toolCallDelta.function?.name ?? "")
              )
              toolCallRouting[toolCallDelta.index] = routing

              guard !routing.id.isEmpty, !routing.name.isEmpty else { continue }

              await channel.send(
                .toolCalls(
                  entryID: toolCallsEntryID,
                  action: .toolCall(
                    id: routing.id,
                    name: routing.name,
                    action: .appendArguments(
                      toolCallDelta.function?.arguments ?? "",
                      tokenCount: 1
                    )
                  )
                )
              )
            }
          } else if let text = delta.content {
            await channel.send(
              .response(
                entryID: responseEntryID,
                action: .appendText(text, tokenCount: 1)
              )
            )
          }
        }

        // Send usage AFTER content so the authoritative cumulative total
        // overwrites any tokens credited by `appendText` for this chunk.
        if let usage = chunk.usage {
          await channel.send(
            .response(
              entryID: responseEntryID,
              action: .updateUsage(
                input: .init(
                  totalTokenCount: usage.promptTokens,
                  cachedTokenCount: usage.promptTokensDetails?.cachedTokens ?? 0
                ),
                output: .init(
                  totalTokenCount: usage.completionTokens,
                  reasoningTokenCount: usage.completionTokensDetails?.reasoningTokens ?? 0
                )
              )
            )
          )
        }
      }
    }

    private func topP(_ sampling: GenerationOptions.SamplingMode) throws -> Double {
      switch sampling.kind {
      case .greedy:
        return 0

      case .randomTopK:
        throw ChatCompletionsLanguageModel.RequestError.invalidRequest(
          "Top K sampling is not supported"
        )
      case .randomProbabilityThreshold(let threshold, let seed):
        guard seed == nil else {
          throw ChatCompletionsLanguageModel.RequestError.invalidRequest(
            "Setting a random seed is not supported"
          )
        }
        return threshold
      @unknown default:
        throw ChatCompletionsLanguageModel.RequestError.invalidRequest(
          "Unknown sampling mode \(sampling.kind) is not supported"
        )
      }
    }

    private func convertedTranscript(
      _ entries: some Collection<Transcript.Entry>
    ) throws -> [ChatCompletionsClient.ChatMessage] {

      // Converts a single transcript segment into chat-completion message content.
      func convertedSegment(
        _ segment: Transcript.Segment,
        in entry: Transcript.Entry
      ) throws -> [ChatCompletionsClient.MessageContent] {
        switch segment {
        case .text(let text):
          return [
            ChatCompletionsClient.MessageContent(
              text: text.content
            )
          ]
        // Structured content is serialized to JSON text on the wire.
        case .structure(let structure):
          return [
            ChatCompletionsClient.MessageContent(
              text: structure.content.jsonString
            )
          ]
        case .attachment(let attachment):
          switch attachment.content {
          case .image(let image):
            #if canImport(CoreImage)
            // Images are inlined as base64 data URLs (JPEG).
            let base64String = image.cgImage.jpegData().base64EncodedString()
            let dataURL = URL(string: "data:image/jpeg;base64,\(base64String)")!
            let imageURL = ChatCompletionsClient.MessageContent.ImageURL(url: dataURL)
            return [ChatCompletionsClient.MessageContent(imageURL: imageURL)]
            #else
            guard let url = image.url else {
              throw LanguageModelError.unsupportedTranscriptContent(
                LanguageModelError.UnsupportedTranscriptContent(
                  unsupportedContent: [entry],
                  debugDescription: "Image attachment without a URL is not supported by \(Self.self) on this platform."
                )
              )
            }
            let dataURL: URL
            if url.scheme == "data" {
              dataURL = url
            } else {
              let data = try Data(contentsOf: url)
              let base64String = data.base64EncodedString()
              dataURL = URL(string: "data:image/jpeg;base64,\(base64String)")!
            }
            let imageURL = ChatCompletionsClient.MessageContent.ImageURL(url: dataURL)
            return [ChatCompletionsClient.MessageContent(imageURL: imageURL)]
            #endif
          @unknown default:
            throw LanguageModelError.unsupportedTranscriptContent(
              LanguageModelError.UnsupportedTranscriptContent(
                unsupportedContent: [entry],
                debugDescription: "Attachment type not supported by \(Self.self)."
              )
            )
          }
        @unknown default:
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [entry],
              debugDescription: "Unknown segment type not supported by \(Self.self)"
            )
          )
        }
      }

      var messages: [ChatCompletionsClient.ChatMessage] = []
      // Reasoning entries are buffered and attached to the next assistant
      // message (response or toolCalls) via `reasoning_content`. If a turn
      // has only reasoning with no following assistant entry, it's emitted
      // as a standalone assistant message.
      var pendingReasoning: String? = nil

      func consumePendingReasoning() -> String? {
        defer { pendingReasoning = nil }
        return pendingReasoning
      }

      // Translate each transcript entry into one chat-completion message.
      for entry in entries {
        switch entry {
        case .instructions(let instructions):
          // Instructions become system-role messages.
          messages.append(
            ChatCompletionsClient.ChatMessage(
              role: .system,
              content: try instructions.segments.flatMap { try convertedSegment($0, in: entry) }
            )
          )

        case .prompt(let prompt):
          // User prompts; flush any orphaned reasoning as a message first.
          if let reasoning = consumePendingReasoning() {
            messages.append(
              ChatCompletionsClient.ChatMessage(
                role: .assistant,
                reasoningContent: reasoning
              )
            )
          }
          messages.append(
            ChatCompletionsClient.ChatMessage(
              role: .user,
              content: try prompt.segments.flatMap { try convertedSegment($0, in: entry) }
            )
          )

        case .toolCalls(let toolCalls):
          // Tool calls ride along on an assistant message, with any buffered reasoning attached.
          messages.append(
            ChatCompletionsClient.ChatMessage(
              role: .assistant,
              toolCalls: toolCalls.map { call in
                ChatCompletionsClient.ToolCall(
                  id: call.id,
                  function: ChatCompletionsClient.ToolCall.FunctionCall(
                    name: call.toolName,
                    arguments: call.arguments.jsonString
                  )
                )
              },
              reasoningContent: consumePendingReasoning()
            )
          )

        case .toolOutput(let toolOutput):
          // Tool outputs become tool-role messages keyed by the originating call ID.
          messages.append(
            ChatCompletionsClient.ChatMessage(
              role: .tool,
              content: try toolOutput.segments.flatMap { try convertedSegment($0, in: entry) },
              toolCallID: toolOutput.id
            )
          )

        case .response(let response):
          // Assistant responses; attach any buffered reasoning to this message.
          messages.append(
            ChatCompletionsClient.ChatMessage(
              role: .assistant,
              content: try response.segments.flatMap { try convertedSegment($0, in: entry) },
              reasoningContent: consumePendingReasoning()
            )
          )

        case .reasoning(let reasoning):
          // Buffer reasoning text; it will attach to the next assistant entry.
          let text = reasoning.segments.compactMap { segment -> String? in
            if case .text(let textSegment) = segment { return textSegment.content }
            return nil
          }.joined()
          pendingReasoning = (pendingReasoning ?? "") + text

        @unknown default:
          continue
        }
      }

      // Trailing reasoning with no following assistant entry — emit it solo.
      if let reasoning = consumePendingReasoning() {
        messages.append(
          ChatCompletionsClient.ChatMessage(
            role: .assistant,
            reasoningContent: reasoning
          )
        )
      }

      return messages
    }
  }
}

#if canImport(CoreImage)
private extension CGImage {
  func jpegData() -> Data {
    let imageData = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      /* data */ imageData,
      /* format */ UTType.jpeg.identifier as CFString,
      /* count */ 1,
      /* options */ nil
    )!
    CGImageDestinationAddImage(destination, self, nil)
    CGImageDestinationFinalize(destination)
    return Data(referencing: imageData)
  }
}
#endif
