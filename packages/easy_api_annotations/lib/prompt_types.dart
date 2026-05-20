/// Types used for MCP prompt results.
///
/// These types define the structure of prompt messages that are returned
/// from @Prompt-annotated methods and sent to language models via the
/// Model Context Protocol.
library;

/// Role of a message in a prompt conversation.
enum PromptRole {
  /// Message from the user perspective.
  user,

  /// Message from the assistant perspective.
  assistant,
}

/// Base class for prompt message content.
///
/// Subclasses represent different content types that can be included
/// in a prompt message (text, image, audio, or embedded resources).
sealed class PromptContent {
  const PromptContent();
}

/// Text content for a prompt message.
///
/// This is the most common content type, representing plain text
/// that will be sent to the language model.
///
/// Example:
/// ```dart
/// PromptMessage(
///   role: PromptRole.user,
///   content: TextPromptContent('Please review this code: $code'),
/// )
/// ```
class TextPromptContent extends PromptContent {
  /// The text content.
  final String text;

  /// Creates text content.
  const TextPromptContent(this.text);
}

/// Image content for a prompt message.
///
/// Includes visual information in the prompt as a base64-encoded image
/// with an associated MIME type.
///
/// Example:
/// ```dart
/// PromptMessage(
///   role: PromptRole.user,
///   content: ImagePromptContent(base64Data, 'image/png'),
/// )
/// ```
class ImagePromptContent extends PromptContent {
  /// Base64-encoded image data.
  final String data;

  /// MIME type of the image (e.g., 'image/png', 'image/jpeg').
  final String mimeType;

  /// Creates image content.
  const ImagePromptContent(this.data, this.mimeType);
}

/// Audio content for a prompt message.
///
/// Includes audio information in the prompt as a base64-encoded audio
/// file with an associated MIME type.
///
/// Example:
/// ```dart
/// PromptMessage(
///   role: PromptRole.user,
///   content: AudioPromptContent(base64AudioData, 'audio/wav'),
/// )
/// ```
class AudioPromptContent extends PromptContent {
  /// Base64-encoded audio data.
  final String data;

  /// MIME type of the audio (e.g., 'audio/wav', 'audio/mp3').
  final String mimeType;

  /// Creates audio content.
  const AudioPromptContent(this.data, this.mimeType);
}

/// Embedded resource content for a prompt message.
///
/// References a server-side resource directly in the prompt, allowing
/// prompts to incorporate documentation, code samples, or other
/// reference materials.
///
/// Example:
/// ```dart
/// PromptMessage(
///   role: PromptRole.user,
///   content: ResourcePromptContent(
///     'resource://docs/api-reference',
///     'text/plain',
///     'API documentation content...',
///   ),
/// )
/// ```
class ResourcePromptContent extends PromptContent {
  /// URI of the resource.
  final String uri;

  /// MIME type of the resource content.
  final String mimeType;

  /// Text content of the resource.
  final String text;

  /// Creates resource content.
  const ResourcePromptContent(this.uri, this.mimeType, this.text);
}

/// A single message in a prompt result.
///
/// Messages have a role (user or assistant) and contain content
/// (text, image, audio, or embedded resource).
///
/// Example:
/// ```dart
/// PromptMessage(
///   role: PromptRole.user,
///   content: TextPromptContent('Analyze this code and suggest improvements.'),
/// )
/// ```
class PromptMessage {
  /// The role of the message sender.
  final PromptRole role;

  /// The content of the message.
  final PromptContent content;

  /// Creates a prompt message.
  const PromptMessage({required this.role, required this.content});
}

/// Result returned by a @Prompt-annotated method.
///
/// Contains a list of messages that form the prompt template,
/// optionally with a description explaining what the prompt does.
///
/// Example:
/// ```dart
/// @Prompt(description: 'Code review prompt')
/// PromptResult codeReview({required String code}) {
///   return PromptResult(
///     description: 'Prompts the LLM to review code quality',
///     messages: [
///       PromptMessage(
///         role: PromptRole.user,
///         content: TextPromptContent('Please review: $code'),
///       ),
///     ],
///   );
/// }
/// ```
class PromptResult {
  /// Optional description of what this prompt does.
  ///
  /// This description is returned in the prompts/get response and
  /// can provide additional context beyond the prompt's metadata.
  final String? description;

  /// List of messages that form the prompt.
  ///
  /// Messages can have alternating roles (user/assistant) to set up
  /// a conversation context for the language model.
  final List<PromptMessage> messages;

  /// Creates a prompt result.
  ///
  /// [description] - Optional explanation of what the prompt does.
  /// [messages] - Required list of messages forming the prompt.
  const PromptResult({this.description, required this.messages});
}
