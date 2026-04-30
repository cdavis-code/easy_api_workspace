# easy_api_annotations

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/images/logo-banner.svg" width="400" alt="easy_api">
</p>

Dart annotations for exposing library methods as MCP tools, REST APIs, or both.

Provides the core annotations used to declaratively describe Model Context Protocol (MCP) servers, REST endpoints, and their parameters — all from plain Dart code that is processed by the companion `easy_api_generator` build_runner package:

- `@Server` — configures transport (stdio/HTTP), port/address, code mode, and which artifacts to generate (`.mcp.dart`, `.mcp.json`, `.openapi.dart`, `.openapi.json`).
- `@Tool` — exposes a method as an MCP tool and/or REST endpoint, with optional custom naming, icons, and code-mode controls.
- `@Parameter` *(optional)* — provides rich metadata for individual parameters: titles, descriptions, examples, validation (min/max, pattern, enum values), sensitivity flags, and external name aliases. The generator infers parameter info from Dart types by default, so you only need `@Parameter` when you want to add metadata beyond what's expressible in the method signature.

> **Migration note:** `@Mcp` is still available as a deprecated typedef for backward compatibility. New code should use `@Server`.

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  easy_api_annotations: ^0.5.0

dev_dependencies:
  build_runner: ^2.4.0
  easy_api_generator: ^0.5.0
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
| `toolPrefix` | `String?` | `null` | Prefix added to all tool names (e.g., `'user_'` makes `createUser` → `user_createUser`) |
| `autoClassPrefix` | `bool` | `false` | Automatically prefix tool names with class name (e.g., `UserService_createUser`) |
| `codeMode` | `bool` | `false` | Enables `search`/`execute` tools backed by a Node.js sandbox for batch tool orchestration |
| `codeModeTimeout` | `int` | `30` | Max execution time in seconds for code-mode scripts |
| `logErrors` | `bool` | `false` | Whether to log internal errors to stderr for troubleshooting (client-facing messages stay generic) |

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

## Features

- Simple annotations for defining MCP servers, REST APIs, or both from a single class
- `@Server`, `@Tool`, and `@Parameter` cover transport, tool metadata, and parameter-level validation
- Support for both stdio (JSON-RPC) and HTTP transports
- **Configurable HTTP server** — customize port and bind address
- **REST + OpenAPI 3.0 generation** via `generateRest: true` (independent of MCP generation)
- **[Code Mode](https://github.com/faithoflifedev/easy_api_workspace/blob/main/README.md#code-mode)** — optional Node.js sandbox for batch tool orchestration with per-tool opt-out
- **Rich parameter metadata** — titles, descriptions, examples, validation (min/max, pattern, enum), sensitivity flags, and external name aliases
- **Flexible tool naming** — custom names, class-based auto prefixing, and tool prefixes
- Backward-compatible `@Mcp` typedef for existing codebases
- Compatible with `easy_api_generator` for automatic server code generation
- Null safety compatible (Dart 3.11+)

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](https://github.com/faithoflifedev/easy_api_workspace/blob/main/CONTRIBUTING.md) guide at the root of the workspace for setup instructions, development workflow, coding standards, testing expectations, and the pull-request checklist before opening a PR.

## License

MIT — See [LICENSE](LICENSE) for details.

## Support

If you find this package useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>