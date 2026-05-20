import 'package:easy_api_annotations/easy_api_annotations.dart';

/// Example prompts demonstrating MCP prompt template functionality.
///
/// Prompts are user-invoked templates that generate structured messages
/// for interacting with language models. Unlike tools (which are model-called),
/// prompts are explicitly selected by users (e.g., as slash commands).
@Server(
  transport: McpTransport.stdio,
  generateJson: true,
)
class ExamplePrompts {
  /// Prompts the LLM to review code quality and suggest improvements.
  @Prompt(
    title: 'Code Review',
    description:
        'Asks the LLM to analyze code quality and suggest improvements',
  )
  PromptResult codeReview({
    @PromptArgument(
      title: 'Source Code',
      description: 'The code to review for quality and issues',
    )
    required String code,
  }) {
    return PromptResult(
      description: 'Code review prompt for the provided source code',
      messages: [
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent(
            'Please review this code and suggest improvements:\n\n```\n$code\n```',
          ),
        ),
      ],
    );
  }

  /// Generates documentation for a piece of code.
  @Prompt(
    title: 'Generate Documentation',
    description: 'Creates comprehensive documentation for the provided code',
  )
  PromptResult generateDocumentation({
    @PromptArgument(
      title: 'Code',
      description: 'The code to generate documentation for',
    )
    required String code,
    @PromptArgument(
      title: 'Language',
      description: 'Programming language of the code',
    )
    String? language,
  }) {
    final langContext = language != null ? ' in $language' : '';
    return PromptResult(
      description: 'Documentation generation prompt',
      messages: [
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent(
            'Please generate comprehensive documentation for this$langContext code:\n\n```\n$code\n```\n\nInclude:\n- Overview and purpose\n- Parameter descriptions\n- Return value explanation\n- Usage examples',
          ),
        ),
      ],
    );
  }

  /// Explains code in simple terms.
  @Prompt(
    title: 'Explain Code',
    description:
        'Explains what a piece of code does in simple, easy-to-understand terms',
  )
  PromptResult explainCode({
    @PromptArgument(
      title: 'Code',
      description: 'The code to explain',
    )
    required String code,
    @PromptArgument(
      title: 'Audience Level',
      description:
          'Target audience expertise level (beginner, intermediate, advanced)',
    )
    String? audienceLevel,
  }) {
    final level = audienceLevel ?? 'beginner';
    return PromptResult(
      description: 'Code explanation prompt for $level audience',
      messages: [
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent(
            'Please explain what this code does in simple terms suitable for a $level audience:\n\n```\n$code\n```',
          ),
        ),
      ],
    );
  }
}
