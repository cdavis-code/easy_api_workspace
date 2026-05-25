# easy_api_annotations

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/packages/easy_api_annotations/images/banner.svg" width="600" alt="easy_api_annotations">
</p>

Dart annotations for exposing library methods as MCP tools, REST APIs, or both.

Provides the core annotations used to declaratively describe Model Context Protocol (MCP) servers, REST endpoints, and their parameters — all from plain Dart code that is processed by the companion `easy_api_generator` build_runner package:

- `@Server` — configures transport (stdio/HTTP), port/address, code mode, and which artifacts to generate (`.mcp.dart`, `.mcp.json`, `.openapi.dart`, `.openapi.json`, `.cli.dart`).
- `@Tool` — exposes a method as an MCP tool and/or REST endpoint, with optional custom naming, icons, and code-mode controls.
- `@Parameter` *(optional)* — provides rich metadata for individual parameters: titles, descriptions, examples, validation (min/max, pattern, enum values), sensitivity flags, and external name aliases. The generator infers parameter info from Dart types by default, so you only need `@Parameter` when you want to add metadata beyond what's expressible in the method signature.

> **Migration note:** `@Mcp` is still available as a deprecated typedef for backward compatibility. New code should use `@Server`.

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  easy_api_annotations: ^1.2.1

dev_dependencies:
  build_runner: ^2.4.0
  easy_api_generator: ^1.1.0
```

> **Note:** This package provides only the annotations. You also need [`easy_api_generator`](https://pub.dev/packages/easy_api_generator) to generate the MCP server code from your annotated classes.

## Usage

### Basic Example (stdio transport)

This example shows all three annotations working together. `@Parameter` is optional — it's only needed when you want richer metadata than the Dart type alone conveys.

```dart
import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(transport: McpTransport.stdio)
class MyServer {
  @Tool(description: 'Create a new user')
  Future<bool> createUser({
    @Parameter(
      title: 'Full Name',
      description: "The user's complete name",
      example: 'John Doe',
    )
    required String name,
    @Parameter(
      title: 'Email Address',
      description: 'A valid email address',
      example: 'john@example.com',
      pattern: r'^[\w\.-]+@[\w\.-]+\.\w+$',
    )
    required String email,
  }) async {
    // Implementation here
    return true;
  }

  @Tool(description: 'Get user by ID')
  Future<User?> getUser(int id) async {
    // Implementation here
    return null;
  }
}
```

### HTTP Transport with Custom Port and Address

```dart
import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(
  transport: McpTransport.http,
  port: 8080,
  address: '0.0.0.0',  // Use '0.0.0.0' to listen on all interfaces
)
class MyServer {
  @Tool(description: 'Create a new user')
  Future<bool> createUser(String name, String email) async {
    // Implementation here
    return true;
  }
}
```

#### @Server Annotation Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `transport` | `McpTransport` | `McpTransport.stdio` | Transport protocol: `stdio` or `http` (only relevant when `generateMcp` is `true`) |
| `port` | `int` | `3000` | HTTP server port (only for HTTP transport) |
| `address` | `String` | `'127.0.0.1'` | HTTP bind address (only for HTTP transport). Use `'0.0.0.0'` to listen on all interfaces |
| `generateMcp` | `bool` | `true` | Whether to generate the MCP server (`.mcp.dart`) |
| `generateJson` | `bool` | `false` | Whether to generate `.mcp.json` tool-metadata file |
| `generateRest` | `bool` | `false` | Whether to generate a REST API server (`.openapi.dart`) and OpenAPI 3.0 spec (`.openapi.json`) |
| `generateCli` | `bool` | `false` | Whether to generate a runnable command-line app (`.cli.dart`) that exposes annotated `@Tool` methods as `package:args` `CommandRunner` subcommands |
| `toolPrefix` | `String?` | `null` | Prefix added to all tool names (e.g., `'user_'` makes `createUser` → `user_createUser`) |
| `autoClassPrefix` | `bool` | `false` | Automatically prefix tool names with class name (e.g., `UserService_createUser`) |
| `codeMode` | `bool` | `false` | Enables `search`/`execute` tools backed by a Node.js sandbox for batch tool orchestration |
| `codeModeTimeout` | `int` | `30` | Max execution time in seconds for code-mode scripts |
| `logErrors` | `bool` | `false` | Whether to log internal errors to stderr for troubleshooting (client-facing messages stay generic) |
| `annotationsDefault` | `ToolAnnotations?` | `null` | Server-wide default values for the 4 boolean tool annotation hints (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`). Individual tools can override any hint via their own `@Tool(annotations: ToolAnnotations(...))`. The `title` field is never inherited. **If neither `annotationsDefault` nor per-tool `annotations` are set, no annotations are emitted in the generated output.** |

### Parameter Annotations (Optional)

The `@Parameter` annotation is **optional**. By default, the generator automatically extracts parameter information from Dart types and method signatures. You only need `@Parameter` when you want to provide additional metadata beyond what's available from the code itself.

Use `@Parameter` to provide rich metadata for individual tool parameters:

```dart
@Tool(description: 'Create a new user')
Future<User> createUser({
  @Parameter(
    title: 'Full Name',
    description: 'The user\'s complete name',
    example: 'John Doe',
  )
  required String name,
  
  @Parameter(
    title: 'Email Address',
    description: 'A valid email address',
    example: 'john@example.com',
    pattern: r'^[\w\.-]+@[\w\.-]+\.\w+$',
  )
  required String email,
  
  @Parameter(
    title: 'Age',
    description: 'User age in years',
    minimum: 0,
    maximum: 150,
    example: 25,
  )
  int? age,
}) async { ... }
```

#### @Parameter Annotation Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alias` | `String?` | `null` | External parameter name used in REST query/body, MCP tool schemas, and OpenAPI specs (Dart name still used in source) |
| `title` | `String?` | `null` | Human-readable title for the parameter |
| `description` | `String?` | `null` | Detailed description of the parameter |
| `example` | `Object?` | `null` | Example value to guide users |
| `minimum` | `num?` | `null` | Minimum value for numeric parameters |
| `maximum` | `num?` | `null` | Maximum value for numeric parameters |
| `pattern` | `String?` | `null` | Regular expression pattern for string validation |
| `maxLength` | `int?` | `null` | Maximum length for string parameters (prevents DoS attacks) |
| `sensitive` | `bool` | `false` | Whether this parameter contains sensitive data (may be masked in logs/UI) |
| `enumValues` | `List<Object?>?` | `null` | List of allowed values (enum-like restriction) |

#### @Tool Annotation Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String?` | `null` | Custom tool name (defaults to method name). Useful for avoiding naming collisions |
| `description` | `String?` | `null` | Tool description (uses dartdoc if omitted) |
| `icons` | `List<String>?` | `null` | List of icon URLs for UI clients |
| `codeMode` | `bool` | `true` | Whether this tool is exposed inside the code-mode sandbox (`search`/`execute`). Set `false` for destructive ops |
| `codeModeVisible` | `bool` | `false` | When the parent `@Server` has `codeMode: true`, keeps this tool visible in the standard `tools/list` response |

### Tool Annotations

Both `@Server` and `@Tool` accept `ToolAnnotations` for behavioral hints that inform MCP clients how tools function:

- **`title`** — Human-readable display title for the tool.
- **`readOnlyHint`** — If `true`, the tool does not modify its environment (safe for auto-approval).
- **`destructiveHint`** — If `true`, the tool may perform destructive updates (clients should prompt for confirmation).
- **`idempotentHint`** — If `true`, repeated calls with the same arguments have no additional effect (safe to retry).
- **`openWorldHint`** — If `true`, the tool interacts with external entities like APIs or the internet. If `false`, it operates within a closed system (e.g., local database, in-memory store).

Server-wide defaults:

- **`@Server(annotationsDefault: ...)`** — sets server-wide defaults for the 4 boolean hints. Every tool inherits these unless it overrides them.
- **`@Tool(annotations: ...)`** — sets per-tool annotations. Values here take precedence over server defaults for the same key. The `title` field is tool-specific and never inherited.

**Emission rule:** If neither `annotationsDefault` (on `@Server`) nor `annotations` (on `@Tool`) are set for a tool, **no `annotations` field is emitted** in the generated `.mcp.json` or `.mcp.dart` output. Annotations are only generated when at least one source provides values.

```dart
@Server(
  annotationsDefault: ToolAnnotations(openWorldHint: false),
)
class MyService {
  @Tool(annotations: ToolAnnotations(readOnlyHint: true))
  // → merged: {readOnlyHint: true, openWorldHint: false}
  Future<User> getUser(int id) async { ... }

  @Tool(description: 'Create user')
  // → merged: {openWorldHint: false} (server default only)
  Future<User> createUser(String name) async { ... }

  @Tool(description: 'Ping')
  // → no annotations emitted (neither server defaults nor tool annotations)
  String ping() => 'pong';
}
```

**Example with custom tool name:**

```dart
@Server(transport: McpTransport.stdio)
class UserService {
  @Tool(
    name: 'user_create',  // Custom name instead of 'createUser'
    description: 'Creates a new user',
  )
  Future<User> createUser(String name, String email) async { ... }
}
```

**Example with tool prefix:**

```dart
@Server(transport: McpTransport.stdio, toolPrefix: 'user_service_')
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: user_service_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: user_service_deleteUser
}
```

**Example with auto class prefix:**

```dart
@Server(transport: McpTransport.stdio, autoClassPrefix: true)
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: UserService_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: UserService_deleteUser
}
```

**Combining autoClassPrefix with toolPrefix:**

```dart
@Server(transport: McpTransport.stdio, autoClassPrefix: true, toolPrefix: 'api_')
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: api_UserService_createUser
}
```

See the [example](https://github.com/faithoflifedev/easy_api_workspace/tree/main/example) directory in the workspace root for a complete working example that demonstrates usage of both packages together.

### MCP Prompts

MCP Prompts are user-invoked templates that generate structured messages for interacting with language models. Unlike tools (which are called by the model), prompts are explicitly selected by users (e.g., as slash commands in MCP clients).

#### @Prompt Annotation

```dart
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:easy_api_annotations/prompt_types.dart';

class CodeReviewPrompts {
  @Prompt(
    title: 'Request Code Review',
    description: 'Asks the LLM to analyze code quality and suggest improvements',
  )
  PromptResult codeReview({
    @PromptArgument(
      title: 'Source Code',
      description: 'The code to review for quality and issues',
    )
    required String code,
  }) {
    return PromptResult(
      description: 'Code review prompt',
      messages: [
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent(
            'Please review this code:\n\n```\n$code\n```',
          ),
        ),
      ],
    );
  }
}
```

#### @Prompt Annotation Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String?` | `null` | Custom prompt name (defaults to method name) |
| `title` | `String?` | `null` | Human-readable title displayed in MCP clients |
| `description` | `String?` | `null` | Description shown to users (uses dartdoc if omitted) |

#### @PromptArgument Annotation Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alias` | `String?` | `null` | Custom external name for the argument |
| `title` | `String?` | `null` | Human-readable title displayed in MCP clients |
| `description` | `String?` | `null` | Detailed explanation of the argument's purpose |
| `required` | `bool?` | `null` | Whether argument is required (inferred from Dart nullability if omitted) |

#### Prompt Types

The `prompt_types.dart` library provides the following types for building prompt results:

- **`PromptResult`** — Return type for @Prompt methods, contains messages and optional description
- **`PromptMessage`** — A single message with a role (user/assistant) and content
- **`PromptRole`** — Enum with `user` and `assistant` values
- **`PromptContent`** — Sealed base class for message content:
  - `TextPromptContent` — Plain text messages
  - `ImagePromptContent` — Base64-encoded images with MIME type
  - `AudioPromptContent` — Base64-encoded audio with MIME type
  - `ResourcePromptContent` — Embedded server resources with URI

#### Multi-content Prompt Example

```dart
import 'dart:convert';
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:easy_api_annotations/prompt_types.dart';

class MultiModalPrompts {
  @Prompt(
    title: 'Analyze Image with Context',
    description: 'Analyzes an image with additional textual context',
  )
  PromptResult analyzeImage({
    @PromptArgument(
      title: 'Image Path',
      description: 'Path to the image file',
    )
    required String imagePath,
    
    @PromptArgument(
      title: 'Analysis Question',
      description: 'What should the LLM focus on?',
    )
    required String question,
  }) {
    // Load and encode image (example)
    final imageBytes = File(imagePath).readAsBytesSync();
    final base64Image = base64Encode(imageBytes);
    
    return PromptResult(
      messages: [
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent('I need you to analyze this image:'),
        ),
        PromptMessage(
          role: PromptRole.user,
          content: ImagePromptContent(base64Image, 'image/png'),
        ),
        PromptMessage(
          role: PromptRole.user,
          content: TextPromptContent(question),
        ),
      ],
    );
  }
}
```

See the [example](https://github.com/faithoflifedev/easy_api_workspace/tree/main/example) directory in the workspace root for a complete working example that demonstrates usage of both packages together.

## Features

- Simple annotations for defining MCP servers, REST APIs, or both from a single class
- `@Server`, `@Tool`, and `@Parameter` cover transport, tool metadata, and parameter-level validation
- **MCP Prompts support** — `@Prompt` and `@PromptArgument` for user-invoked prompt templates with multi-modal content (text, image, audio, resources)
- Support for both stdio (JSON-RPC) and HTTP transports
- **Configurable HTTP server** — customize port, bind address, and CORS origins
- **REST + OpenAPI 3.0 generation** via `generateRest: true` (independent of MCP generation)
- **[Code Mode](https://github.com/faithoflifedev/easy_api_workspace/blob/main/README.md#code-mode)** — optional Node.js sandbox for batch tool orchestration with per-tool opt-out
- **Rich parameter metadata** — titles, descriptions, examples, validation (min/max, pattern, maxLength, enum), sensitivity flags, and external name aliases
- **Flexible tool naming** — custom names, class-based auto prefixing, and tool prefixes
- **Tool annotations** — behavioral hints (readOnlyHint, destructiveHint, idempotentHint, openWorldHint) for MCP clients
- Backward-compatible `@Mcp` typedef for existing codebases
- Compatible with `easy_api_generator` for automatic server code generation
- Null safety compatible (Dart 3.9+)

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](https://github.com/faithoflifedev/easy_api_workspace/blob/main/CONTRIBUTING.md) guide at the root of the workspace for setup instructions, development workflow, coding standards, testing expectations, and the pull-request checklist before opening a PR.

## License

MIT — See [LICENSE](LICENSE) for details.

## Support

If you find this package useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>