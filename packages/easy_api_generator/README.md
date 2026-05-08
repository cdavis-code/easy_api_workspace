# easy_api_generator

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/images/logo-banner.svg" width="400" alt="easy_api">
</p>

Build Runner generator that creates MCP server code, REST API servers, and OpenAPI 3.0 specs from annotated Dart classes.

Processes Dart code annotated with the `easy_api_annotations` package to produce any combination of a ready-to-run MCP server (`.mcp.dart`), MCP metadata (`.mcp.json`), a Shelf-based REST server (`.openapi.dart`), and an OpenAPI 3.0 specification (`.openapi.json`):

- `@Server` — configures transport (stdio/HTTP), port/address, code mode, and which artifacts to generate.
- `@Tool` — exposes a method as an MCP tool and/or REST endpoint, with optional custom naming, icons, and code-mode controls.
- `@Parameter` *(optional)* — attaches rich metadata to individual parameters (titles, descriptions, examples, validation, sensitivity, external aliases). The generator infers parameter info from Dart types by default, so you only need `@Parameter` when you want richer metadata than the Dart signature already expresses.

> **Migration note:** `@Mcp` is still available as a deprecated typedef for backward compatibility. New code should use `@Server`.

## Installation

`easy_api_generator` is a build-time tool, so it belongs under `dev_dependencies`. Only `easy_api_annotations` is needed at runtime:

```yaml
dependencies:
  easy_api_annotations: ^0.6.0

dev_dependencies:
  build_runner: ^2.4.0
  easy_api_generator: ^0.6.1
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
- **Rich parameter metadata** - Use `@Parameter` annotation for titles, descriptions, validation
- **Optional parameter support** - Handles named and optional positional parameters
- **Doc comment extraction** - Uses function doc comments when `@Tool.description` not provided
- **Dynamic method dispatch** - Generated `_dispatch` function routes to actual tool methods

## Example

See the [example](https://github.com/cdavis-code/easy_api_workspace/tree/main/example) directory in the workspace root for a complete working example that demonstrates usage of both packages together.

## Generated Server Capabilities

The generated MCP server supports:
- `initialize` - Standard MCP initialization
- `tools/list` - Returns list of available tools with schemas
- `tools/call` - Executes the requested tool with provided arguments

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](https://github.com/cdavis-code/easy_api_workspace/blob/main/CONTRIBUTING.md) guide at the root of the workspace for setup instructions, development workflow, coding standards, testing expectations, and the pull-request checklist before opening a PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

If you find this package useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>