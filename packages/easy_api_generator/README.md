# easy_api_generator

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/images/logo-banner.svg" width="400" alt="easy_api">
</p>

Build Runner generator that creates MCP server code, REST API servers, OpenAPI 3.0 specs, and command-line apps from annotated Dart classes.

Processes Dart code annotated with the `easy_api_annotations` package to produce any combination of:
- **MCP server** (`.mcp.dart`) — stdio or HTTP transport using `dart_mcp`
- **MCP metadata** (`.mcp.json`) — tool/prompt schemas for AI clients
- **REST API server** (`.openapi.dart`) — Shelf-based HTTP server
- **OpenAPI 3.0 specification** (`.openapi.json`) — Swagger-compatible API docs
- **Command-line app** (`.cli.dart`) — runnable CLI built on `package:args` `CommandRunner`

- `@Server` — configures transport (stdio/HTTP), port/address, code mode, and which artifacts to generate.
- `@Tool` — exposes a method as an MCP tool and/or REST endpoint, with optional custom naming, icons, and code-mode controls.
- `@Parameter` *(optional)* — attaches rich metadata to individual parameters (titles, descriptions, examples, validation constraints like `maxLength` and `pattern`, sensitivity, external aliases). The generator infers parameter info from Dart types by default, so you only need `@Parameter` when you want richer metadata than the Dart signature already expresses.

> **Migration note:** `@Mcp` is still available as a deprecated typedef for backward compatibility. New code should use `@Server`.

## Installation

`easy_api_generator` is a build-time tool, so it belongs under `dev_dependencies`. Only `easy_api_annotations` is needed at runtime:

```yaml
dependencies:
  easy_api_annotations: ^1.1.0

dev_dependencies:
  build_runner: ^2.4.0
  easy_api_generator: ^1.1.2
```

## Usage

1. Annotate your functions with `@Server` and `@Tool`:

```dart
import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(transport: McpTransport.stdio)
class MyServer {
  @Tool(description: 'Create a new user')
  Future<bool> createUser(String name, String email) async {
    // Implementation here
    return true;
  }
}
```

### HTTP Transport Configuration

For HTTP transport, you can customize the port and bind address:

```dart
@Server(
  transport: McpTransport.http,
  port: 8080,           // Default: 3000
  address: '0.0.0.0',   // Default: '127.0.0.1' (loopback)
)
class MyServer {
  @Tool(description: 'Create a new user')
  Future<bool> createUser(String name, String email) async {
    // Implementation here
    return true;
  }
}
```

**Note:** Use `address: '0.0.0.0'` to listen on all network interfaces (useful for Docker containers or remote access).

### REST API Specification Generation

Set `generateRest: true` on `@Server` to generate a Shelf-based REST API server (`.openapi.dart`) plus a matching OpenAPI 3.0 specification (`.openapi.json`). REST generation is independent of MCP generation — you can generate REST only, MCP only, or both.

#### REST + MCP (both artifacts)

```dart
@Server(
  transport: McpTransport.http,
  port: 8080,
  generateRest: true,        // Adds .openapi.dart + .openapi.json
  // generateMcp defaults to true, so .mcp.dart is also produced
)
class MyApi {
  @Tool(description: 'Create a new user')
  Future<User> createUser({
    required String name,
    required String email,
  }) async { ... }

  @Tool(description: 'Get user by ID')
  Future<User> getUser({required int id}) async { ... }

  @Tool(description: 'List all users')
  Future<List<User>> listUsers() async { ... }
}
```

#### REST only (no MCP server)

When you only need a REST API, set `generateMcp: false` so the MCP artifacts are skipped. The `transport` and `port` options are MCP-specific and are not required in REST-only mode — configure the REST server's host/port when you run `.openapi.dart` instead.

```dart
@Server(
  generateMcp: false,   // Skip .mcp.dart / .mcp.json
  generateRest: true,   // Produce .openapi.dart + .openapi.json
)
class MyApi {
  @Tool(description: 'Create a new user')
  Future<User> createUser({
    required String name,
    required String email,
  }) async { ... }

  @Tool(description: 'Get user by ID')
  Future<User> getUser({required int id}) async { ... }

  @Tool(description: 'List all users')
  Future<List<User>> listUsers() async { ... }
}
```

Either configuration generates a `.openapi.json` with RESTful endpoints:

```json
{
  "openapi": "3.0.3",
  "paths": {
    "/users": {
      "post": {
        "summary": "Create a new user",
        "operationId": "createUser",
        "requestBody": { ... },
        "responses": { "201": { ... } }
      },
      "get": {
        "summary": "List all users",
        "operationId": "listUsers",
        "responses": { "200": { ... } }
      }
    },
    "/users/{id}": {
      "get": {
        "summary": "Get user by ID",
        "operationId": "getUser",
        "parameters": [{ "name": "id", "in": "path" }],
        "responses": { "200": { ... }, "404": { ... } }
      }
    }
  }
}
```

**Features:**
- ✅ RESTful endpoint mapping (POST for create, GET for list/get, PATCH for update, DELETE for remove)
- ✅ Resource-based URL patterns (`/users`, `/users/{id}`)
- ✅ Request/response schemas with validation
- ✅ Proper HTTP status codes (200, 201, 204, 400, 404)
- ✅ Parameter metadata from `@Parameter` annotations
- ✅ Compatible with Swagger UI, API gateways, and code generators

### CLI Application Generation

Set `generateCli: true` on `@Server` to generate a runnable command-line app
(`<source>.cli.dart`) built on `package:args`'s `CommandRunner`. The CLI is
independent of the MCP, REST, and OpenAPI artifacts — generate any
combination you need.

```dart
@Server(
  generateCli: true,         // Adds .cli.dart
  generateMcp: false,        // Optional: skip MCP if you only need a CLI
  // generateRest: true,     // Optional: combine with REST generation
)
Future<void> main() async { /* ... */ }
```

**Command structure**

- Tools defined inside a class become subcommands under a `kebab-case`
  command group named after the class. For example, a static method
  `UserStore.createUser` becomes `example user-store create-user`.
- Top-level tools (those defined as top-level functions) are exposed
  directly as top-level commands. The resolved tool name is used, so any
  `toolPrefix` or `autoClassPrefix` carries through.

**Argument handling**

Each parameter becomes a CLI option with the same validation as the MCP
and REST artifacts (`maxLength`, `pattern`, `minimum`, `maximum`,
`enumValues` → `addOption(allowed: ...)`).

| Dart type | CLI shape |
|-----------|-----------|
| `bool` | `--flag` / `--no-flag` (`addFlag(negatable: true)`) |
| `String`, `int`, `double`, `num` | `addOption('name', mandatory: true)` (or optional with default) |
| `List<String>` / `List<int>` / etc. | `addMultiOption('name')` (repeatable) |
| Custom class (e.g. `User`) | `--name='{...json...}'` or `--name=@/path/to/file.json` |
| `List<Custom>` | JSON array literal or `@file` reference |
| `Map<String, dynamic>` / `dynamic` | JSON literal or `@file` reference |

The `@file` syntax mirrors `curl`: prefix the path with `@` and the CLI
reads the file's contents and decodes it as JSON.

**Output and exit codes**

- Results are emitted as **pretty-printed JSON** by default. Pass the
  global `--compact` flag to emit single-line JSON.
- `null` results produce no output.
- Exit codes follow Unix conventions: `0` on success, `64` on usage or
  validation errors, `1` on internal errors.
- When `logErrors: true` is set on `@Server`, the underlying error
  message and stack trace are also written to stderr before the generic
  message.

```sh
$ dart run bin/example.cli.dart --help
$ dart run bin/example.cli.dart user-store list-users
$ dart run bin/example.cli.dart user-store create-user \
    --name="Alice" --email="alice@example.com"
$ dart run bin/example.cli.dart --compact todo-store create-todo --title="Buy milk"
$ dart run bin/example.cli.dart inventory add-item --item=@./item.json
```

### Tool Annotations

The generator supports `ToolAnnotations` for behavioral hints that inform MCP clients how tools function:

- **`title`** — Human-readable display title for the tool.
- **`readOnlyHint`** — If `true`, the tool does not modify its environment (safe for auto-approval).
- **`destructiveHint`** — If `true`, the tool may perform destructive updates (clients should prompt for confirmation).
- **`idempotentHint`** — If `true`, repeated calls with the same arguments have no additional effect (safe to retry).
- **`openWorldHint`** — If `true`, the tool interacts with external entities like APIs or the internet. If `false`, it operates within a closed system (e.g., local database, in-memory store).

Annotations can come from two sources:

- **`@Server(annotationsDefault: ...)`** — provides server-wide defaults for the 4 boolean hints. All tools inherit these defaults.
- **`@Tool(annotations: ...)`** — provides per-tool annotations. Per-tool values always take precedence over server defaults for the same key. The `title` field is tool-specific and never inherited from server defaults.

**Emission rule:** If neither `annotationsDefault` (on `@Server`) nor `annotations` (on `@Tool`) are set for a tool, **no `annotations` field is emitted** in the generated output. The generator only produces annotations when at least one source provides values.

```dart
@Server(
  annotationsDefault: ToolAnnotations(openWorldHint: false),
)
class MyService {
  @Tool(annotations: ToolAnnotations(readOnlyHint: true))
  // → Generated annotations: {readOnlyHint: true, openWorldHint: false}
  Future<User> getUser(int id) async { ... }

  @Tool(description: 'Create user')
  // → Generated annotations: {openWorldHint: false} (server default only)
  Future<User> createUser(String name) async { ... }

  @Tool(description: 'Ping')
  // → No annotations emitted (neither server defaults nor tool annotations)
  String ping() => 'pong';
}
```

### Parameter Annotations (Optional)

Use `@Parameter` to provide rich metadata for tool parameters:

```dart
@Server(transport: McpTransport.stdio)
class MyServer {
  @Tool(description: 'Create a new user')
  Future<bool> createUser({
    @Parameter(
      title: 'Full Name',
      description: 'The user\'s full name',
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
  }) async {
    // Implementation here
    return true;
  }
}
```

The `@Parameter` annotation is **optional** - by default, the generator extracts parameter information from Dart types and method signatures. Use it when you need:
- Human-readable titles and descriptions
- Example values to guide users
- Validation constraints (min/max, patterns, enum values)
- To mark sensitive data (passwords, API keys)

### Custom Tool Names

By default, the generator uses method names as tool names. You can customize this using:

**1. The `name` parameter on `@Tool`:**

```dart
@Server(transport: McpTransport.stdio)
class UserService {
  @Tool(
    name: 'user_create',  // Custom tool name
    description: 'Creates a new user',
  )
  Future<User> createUser(String name, String email) async { ... }
}
```

**2. The `toolPrefix` parameter on `@Server` (applies to all tools in the class):**

```dart
@Server(transport: McpTransport.stdio, toolPrefix: 'user_service_')
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: user_service_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: user_service_deleteUser
}
```

**3. The `autoClassPrefix` parameter on `@Server` (automatically uses class name):**

```dart
@Server(transport: McpTransport.stdio, autoClassPrefix: true)
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: UserService_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: UserService_deleteUser
}
```

You can also combine `autoClassPrefix` with `toolPrefix`:

```dart
@Server(transport: McpTransport.stdio, autoClassPrefix: true, toolPrefix: 'api_')
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: api_UserService_createUser
}
```

This is useful for:
- Avoiding naming collisions when aggregating tools from multiple files
- Organizing tools by domain (e.g., `user_`, `order_`, `admin_`)
- Creating more descriptive names for MCP clients

### MCP Prompts

Prompts are parameterized templates that users can invoke explicitly (e.g., as slash commands) to generate structured LLM messages. Unlike tools (which are called by the model), prompts are selected by users.

```dart
@Server(transport: McpTransport.stdio)
class MyPrompts {
  @Prompt(
    title: 'Code Review',
    description: 'Analyzes code quality and suggests improvements',
  )
  PromptResult codeReview({
    @PromptArgument(
      title: 'Source Code',
      description: 'The code to review',
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

When prompts are detected, the generated server:
- Declares `PromptsCapability` during initialization
- Implements `prompts/list` to return available prompt templates with arguments
- Implements `prompts/get` to execute the prompt method and convert `PromptResult` to MCP messages
- Supports all content types: text, images, audio, and embedded resources
- Includes prompts in `.mcp.json` metadata when generated

2. Run the generator:

```bash
dart run build_runner build
```

This generates:
- `my_server.mcp.dart` - Complete MCP server (stdio or HTTP)

**Optional:** To also generate a `.mcp.json` metadata file, set `generateJson: true` in the `@Server` annotation:

```dart
@Server(
  transport: McpTransport.stdio,
  generateJson: true,  // Generates my_server.mcp.json
)
class MyServer { ... }
```

## Features

- **AST-based parsing** - Uses `dart:analyzer` for reliable annotation detection
- **Two transport modes** - stdio (JSON-RPC) and HTTP (Shelf-based) servers
- **Configurable HTTP server** - Customize port and bind address via `@Server` annotation
- **Automatic JSON-Schema generation** - Maps Dart types to proper JSON Schema
- **Rich parameter metadata** - Use `@Parameter` for titles, descriptions, validation (`maxLength`, `pattern`, `minimum`, `maximum`, `enumValues`)
- **Input validation** - Automatic generation of length and pattern validation code to prevent DoS attacks
- **MCP Prompts support** - Parameterized prompt templates with `@Prompt` and `@PromptArgument` annotations
- **ToolAnnotations** - Behavioral hints for MCP clients (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`)
- **Code Mode** - Node.js sandbox for batch tool orchestration with resource limits
- **Configurable CORS** - Restrict HTTP origins via `corsOrigins` parameter
- **Optional parameter support** - Handles named and optional positional parameters with default values
- **Doc comment extraction** - Uses function doc comments when `@Tool.description` not provided
- **Dynamic method dispatch** - Generated `_dispatch` function routes to actual tool methods
- **Security features** - Identifier validation, ReDoS prevention, graceful process shutdown, secure temp file permissions, unpredictable temp directory naming

## Example

See the [example](https://github.com/cdavis-code/easy_api_workspace/tree/main/example) directory in the workspace root for a complete working example that demonstrates usage of both packages together.

## Generated Server Capabilities

The generated MCP server supports:
- `initialize` - Standard MCP initialization with capability negotiation
- `tools/list` - Returns list of available tools with JSON Schema definitions
- `tools/call` - Executes the requested tool with provided arguments
- `prompts/list` - Returns available prompt templates with argument metadata (when prompts are defined)
- `prompts/get` - Executes a prompt template and returns structured LLM messages (when prompts are defined)

The generated REST server (when `generateRest: true`) provides:
- RESTful endpoint mapping following OpenAPI 3.0 specification
- Resource-based URL patterns (e.g., `/users`, `/users/{id}`)
- Proper HTTP status codes (200, 201, 204, 400, 404)
- Request/response schema validation
- Swagger/OpenAPI compatible `.openapi.json` output

## Security & Operational Caveats

`easy_api_generator` produces servers that run with the full privileges of
the host process. Operators should understand the following before exposing
generated servers to untrusted callers.

### Error logging and sensitive parameters

The `@Server(logErrors: true)` flag is **opt-in** and writes the original
exception message and stack trace to `stderr` when a tool handler throws.
The MCP client always receives the generic message
`"An error occurred while processing the request"` — internal detail never
leaves the process via the protocol response.

However, when `logErrors: true` is enabled, exceptions whose messages
incorporate inbound argument values (for example, a validation error that
echoes the offending input) **may surface those values in the local log
stream**, even when the corresponding parameter is annotated
`@Parameter(sensitive: true)`. The `sensitive` flag controls JSON-Schema
metadata (`x-sensitive: true`, `format: password`) so that MCP clients can
mask the field in UI/transport logs; it does not redact server-side stderr
output.

Recommended posture:

- Leave `logErrors: false` (the default) in production unless you control
  the log destination.
- When `logErrors: true` is required, ensure that the process's stderr is
  routed to a sink with the same trust level as the inputs themselves.
- Avoid embedding raw parameter values in exception messages thrown from
  tool handlers — log a redacted summary instead.

### Code Mode is a resource sandbox, not a security sandbox

`@Server(codeMode: true)` runs user-supplied JavaScript in a Node.js
subprocess that is launched with `--max-old-space-size=64` and a wall-clock
timeout (`codeModeTimeout`, default 30s). This is sufficient to bound
runaway loops and accidental memory exhaustion, but it is **not** a
security boundary:

- The Node.js process inherits the parent's filesystem, network, and
  environment access.
- `require()` and Node built-ins (`fs`, `net`, `child_process`, etc.) are
  not blocked.
- The IPC channel that bridges JS calls back to Dart tools enforces only
  the `@Tool(codeMode: ...)` allow-list — it does not audit arguments.

Treat Code Mode scripts as **trusted code** that simply happens to be
expressed in JS. Do not enable `codeMode` in deployments where the
calling client is untrusted, and do not rely on the sandbox to contain
malicious payloads. If you need true isolation, run the generated server
inside a container, VM, or seccomp/jail profile that enforces the
required boundaries externally.

### Identifier validation

User-supplied values that flow into generated Dart and JS source —
`@Tool(name:)`, `@Server(toolPrefix:)`, and `@Parameter(alias:)` — must
match `^[a-zA-Z_][a-zA-Z0-9_]*$`. The builder rejects anything else with
an `InvalidGenerationSourceError` so that hostile annotation values
cannot inject source code into the output.

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](https://github.com/cdavis-code/easy_api_workspace/blob/main/CONTRIBUTING.md) guide at the root of the workspace for setup instructions, development workflow, coding standards, testing expectations, and the pull-request checklist before opening a PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

If you find this package useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>