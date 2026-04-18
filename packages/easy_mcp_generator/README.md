# easy_mcp_generator

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_mcp_workspace/main/images/logo-banner.svg" width="400" alt="easy_mcp">
</p>

Build Runner generator that creates MCP server code from @Tool annotations.

Processes Dart code annotated with `@Mcp` and `@Tool` from the `easy_mcp_annotations` package to generate complete MCP server implementations.

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  easy_mcp_generator: ^0.4.2
  easy_mcp_annotations: ^0.4.2

dev_dependencies:
  build_runner: ^2.4.0
```

## Usage

1. Annotate your functions with `@Mcp` and `@Tool`:

```dart
import 'package:easy_mcp_annotations/mcp_annotations.dart';

@Mcp(transport: McpTransport.stdio)
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
@Mcp(
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

### OpenAPI Specification Generation

Generate RESTful OpenAPI 3.0 specifications by setting `generateOpenApi: true`:

```dart
@Mcp(
  transport: McpTransport.http,
  port: 8080,
  generateOpenApi: true,
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

This generates `my_api.openapi.json` with RESTful endpoints:

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

### Parameter Annotations (Optional)

Use `@Parameter` to provide rich metadata for tool parameters:

```dart
@Mcp(transport: McpTransport.stdio)
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
@Mcp(transport: McpTransport.stdio)
class UserService {
  @Tool(
    name: 'user_create',  // Custom tool name
    description: 'Creates a new user',
  )
  Future<User> createUser(String name, String email) async { ... }
}
```

**2. The `toolPrefix` parameter on `@Mcp` (applies to all tools in the class):**

```dart
@Mcp(transport: McpTransport.stdio, toolPrefix: 'user_service_')
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: user_service_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: user_service_deleteUser
}
```

**3. The `autoClassPrefix` parameter on `@Mcp` (automatically uses class name):**

```dart
@Mcp(transport: McpTransport.stdio, autoClassPrefix: true)
class UserService {
  @Tool(description: 'Create user')
  Future<User> createUser() async { ... }  // Tool name: UserService_createUser
  
  @Tool(description: 'Delete user')
  Future<void> deleteUser(String id) async { ... }  // Tool name: UserService_deleteUser
}
```

You can also combine `autoClassPrefix` with `toolPrefix`:

```dart
@Mcp(transport: McpTransport.stdio, autoClassPrefix: true, toolPrefix: 'api_')
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

**Optional:** To also generate a `.mcp.json` metadata file, set `generateJson: true` in the `@Mcp` annotation:

```dart
@Mcp(
  transport: McpTransport.stdio,
  generateJson: true,  // Generates my_server.mcp.json
)
class MyServer { ... }
```

## Features

- **AST-based parsing** - Uses `dart:analyzer` for reliable annotation detection
- **Two transport modes** - stdio (JSON-RPC) and HTTP (Shelf-based) servers
- **Configurable HTTP server** - Customize port and bind address via `@Mcp` annotation
- **Automatic JSON-Schema generation** - Maps Dart types to proper JSON Schema
- **Rich parameter metadata** - Use `@Parameter` annotation for titles, descriptions, validation
- **Optional parameter support** - Handles named and optional positional parameters
- **Doc comment extraction** - Uses function doc comments when `@Tool.description` not provided
- **Dynamic method dispatch** - Generated `_dispatch` function routes to actual tool methods

## Example

See the [example](https://github.com/cdavis-code/easy_mcp_workspace/tree/main/example) directory in the workspace root for a complete working example that demonstrates usage of both packages together.

## Generated Server Capabilities

The generated MCP server supports:
- `initialize` - Standard MCP initialization
- `tools/list` - Returns list of available tools with schemas
- `tools/call` - Executes the requested tool with provided arguments

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

If you find this package useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>