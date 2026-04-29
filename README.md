<p align="center">
  <img src="images/logo-banner.svg" width="600" alt="easy_mcp">
</p>

<p align="center">
  <strong>A Dart code generator that transforms annotated functions into Model Context Protocol (MCP) servers.</strong>
</p>

## Overview

Easy MCP allows you to expose Dart library functions as MCP tools using simple annotations. The generator produces ready-to-run stdio or HTTP servers that comply with the MCP specification.

## Packages

| Package | Description | Version |
|---------|-------------|---------|
| [`easy_mcp_annotations`](packages/easy_mcp_annotations) | Annotation definitions (`@Mcp`, `@Tool`, `@Parameter`) | [![pub package](https://img.shields.io/pub/v/easy_mcp_annotations.svg)](https://pub.dev/packages/easy_mcp_annotations) |
| [`easy_mcp_generator`](packages/easy_mcp_generator) | Build runner generator that produces MCP server code | [![pub package](https://img.shields.io/pub/v/easy_mcp_generator.svg)](https://pub.dev/packages/easy_mcp_generator) |

## Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  easy_mcp_annotations: ^0.5.0

dev_dependencies:
  build_runner: ^2.4.0
  easy_mcp_generator: ^0.5.0
```

### 2. Annotate Your Functions

```dart
import 'package:easy_mcp_annotations/mcp_annotations.dart';

@Mcp(transport: McpTransport.stdio)
class UserServer {
  @Tool(description: 'Get user by ID')
  Future<User> getUser(int id) async {
    // ...
  }
}
```

### 3. Run the Generator

```bash
dart run build_runner build
```

### 4. Run the Server

```bash
dart run bin/my_server.mcp.dart
```

## Annotations

### `@Mcp`

Controls the transport type and configuration for the generated server.

```dart
// Stdio transport (default)
@Mcp(transport: McpTransport.stdio)

// HTTP transport with custom port and address
@Mcp(
  transport: McpTransport.http,
  port: 8080,                    // Default: 3000
  address: '0.0.0.0',            // Default: '127.0.0.1'
  generateJson: true,            // Optional: generate .mcp.json metadata
  toolPrefix: 'user_service_',   // Optional: prefix all tool names
  autoClassPrefix: true,         // Optional: prefix with class name
)
```

### `@Tool`

Marks a method as an MCP tool and provides metadata.

```dart
@Tool(description: 'Create a new user')
Future<User> createUser(String name, String email) async { ... }

// With custom tool name
@Tool(
  name: 'user_create',  // Custom name instead of method name
  description: 'Creates a new user',
)
Future<User> createUser(String name, String email) async { ... }

// Disable code mode for destructive operations
@Tool(
  description: 'Delete a user',
  codeMode: false,  // Not available in batch orchestration
)
Future<bool> deleteUser(int id) async { ... }
```

If `description` is omitted, the function's doc comment is used. Use `name` to customize the tool name for avoiding collisions or better organization. Set `codeMode` to `false` for tools that should not be available in batch orchestration (e.g., destructive operations).

### `@Parameter` (Optional)

Provides rich metadata for individual parameters. Use when you need custom titles, descriptions, examples, or validation constraints.

```dart
@Tool(description: 'Create a new user')
Future<User> createUser({
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
    minimum: 0,
    maximum: 150,
    example: 25,
  )
  int? age,
}) async { ... }
```

**Full `@Parameter` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `title` | `String?` | Human-readable label displayed in MCP clients |
| `description` | `String?` | Detailed description of the parameter |
| `example` | `Object?` | Example value shown as a hint |
| `minimum` | `num?` | Minimum value for numeric parameters |
| `maximum` | `num?` | Maximum value for numeric parameters |
| `pattern` | `String?` | Regex pattern for string validation |
| `sensitive` | `bool` | Mark as sensitive (e.g., passwords, API keys). Default: `false` |
| `enumValues` | `List<Object?>?` | Restrict to specific allowed values |

**Note:** `@Parameter` is optional. By default, the generator extracts parameter information from Dart types and method signatures.

### Code Mode

Enable batch tool orchestration via sandboxed JavaScript execution. Reduces latency by replacing N sequential round-trips with a single call.

```dart
@Mcp(
  codeMode: true,           // Enable the execute_code tool
  codeModeTimeout: 60,      // Optional: max execution time (default: 30s)
)
```

When enabled, an `execute_code` tool is generated that spawns a sandboxed Node.js subprocess where all code-mode-enabled tools are available as `external_*` async functions. The LLM can use `Promise.all()` for parallel calls and `await` for sequential logic.

**Requirements:** Node.js must be installed on the system.

### OpenAPI Specification Generation

Generate RESTful OpenAPI 3.0 specifications from your MCP tools:

```dart
@Mcp(
  generateOpenApi: true,  // Enable OpenAPI generation
)
void configureMcp() { ... }
```

This generates a `.openapi.json` file with:
- **RESTful endpoints** - Tools mapped to standard HTTP methods (GET, POST, PATCH, DELETE)
- **Resource-based URLs** - e.g., `/users`, `/users/{id}` instead of `/tools/createUser`
- **Request/response schemas** - Full type information with validation
- **Proper status codes** - 200, 201, 204, 400, 404 as appropriate
- **Tags and operation IDs** - For API organization and client generation

The generated spec follows Swagger API design best practices and can be used with Swagger UI, API gateways, and client code generation tools.

## Features

- **AST-based parsing** - Uses `dart:analyzer` for reliable code extraction
- **Two transport modes** - stdio (JSON-RPC) and HTTP (Shelf-based)
- **Configurable HTTP server** - Customize port and bind address
- **Rich parameter metadata** - Optional `@Parameter` annotation for titles, descriptions, validation, sensitive flags, and enum values
- **Custom tool names** - Use `name` parameter on `@Tool`, `toolPrefix` or `autoClassPrefix` on `@Mcp` to avoid collisions
- **Automatic schema generation** - Dart types mapped to JSON Schema
- **Optional parameter support** - Named and optional positional parameters
- **Doc comment extraction** - Falls back to doc comments when description not provided
- **Code Mode** - Batch tool orchestration via sandboxed Node.js execution with `external_*` functions and `Promise.all` support
- **OpenAPI 3.0 specification** - Auto-generate RESTful API documentation from MCP tools
- **Tool icons** - Optional icon URLs for visual identification in MCP clients
- **Many-to-many relationships** - Full example with User/Todo cross-store operations
- **Generated metadata** - `.mcp.json` tool metadata and `.openapi.json` RPC-to-REST mapping

## Development

### Prerequisites

- Dart SDK ^3.11.0
- Melos (for workspace management)

### Commands

```bash
# Install dependencies
melos bootstrap

# Run all tests
melos run test

# Analyze code
melos run analyze

# Format code
melos run format

# Rebuild generated code
melos run build
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

If you find this project useful, consider supporting its development:

<a href="https://buymeacoffee.com/cdavis" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
</a>
