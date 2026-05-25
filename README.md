<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/images/logo-banner.svg" width="600" alt="easy_api">
</p>

<p align="center">
  <strong>A Dart code generator that transforms annotated functions into MCP servers, REST APIs, and CLI applications.</strong>
</p>

<p align="center">
  <a href="https://buymeacoffee.com/cdavis" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 48px !important;width: 174px !important;" >
  </a>
</p>

<p align="center">
  <a href="packages/easy_api_annotations"><img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/packages/easy_api_annotations/images/banner.svg" width="45%" alt="easy_api_annotations"></a>
  <a href="packages/easy_api_generator"><img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/packages/easy_api_generator/images/banner.svg" width="45%" alt="easy_api_generator"></a>
</p>

## Overview

Easy API allows you to expose Dart library functions as MCP tools, REST API endpoints, and command-line subcommands using simple annotations. The generator produces ready-to-run stdio/HTTP MCP servers, REST API servers, OpenAPI 3.0 specifications, and runnable CLI apps — any combination — from a single source of truth.

### What You Can Build

- **MCP Servers** - Create AI-powered tools callable by Claude Desktop, Cursor, and other MCP clients via stdio or HTTP transport
- **REST APIs** - Generate traditional HTTP REST endpoints with full OpenAPI 3.0 documentation for web/mobile applications
- **Command-Line Apps** - Generate a `package:args` `CommandRunner`-based CLI that exposes the same tools as kebab-case subcommands
- **Hybrid Solutions** - Serve AI agents, traditional HTTP clients, and shell users from the same annotated Dart code
- **Code Mode Orchestration** - Enable LLM-driven batch tool execution via sandboxed JavaScript for complex multi-step workflows

### Uses of Generated `.openapi.json`

The generated OpenAPI 3.0 specification file is a powerful artifact that enables:

- **Interactive API Documentation** - Import into Swagger UI, Redoc, or Stoplight for browsable, interactive documentation
- **Client SDK Generation** - Auto-generate type-safe client libraries in 50+ languages using OpenAPI Generator, Swagger Codegen, or NSwag
- **API Testing & Mocking** - Create mock servers (Prism, WireMock) and automated tests without writing implementation code
- **API Gateway Integration** - Configure Kong, AWS API Gateway, Apigee, or Azure API Management with ready-to-import specs
- **Contract-First Development** - Share API contracts with frontend/mobile teams before implementation begins
- **Automated Validation** - Validate requests/responses against the spec using tools like Dredd or Schemathesis
- **Developer Portals** - Power documentation sites with ReadMe, Postman, or GitBook integrations
- **Load Testing** - Generate realistic test scenarios with k6 or Apache JMeter from the spec

### Generated Files and Artifacts

The code generator can produce several different output files depending on your `@Server` configuration:

| File | Generated When | Purpose |
|------|---------------|---------|
| `.mcp.dart` | `generateMcp: true` (default) | Complete MCP server implementation with stdio or HTTP transport. Contains all tool handlers, JSON-RPC routing, and server lifecycle management. **Do not edit manually** — regenerate via `build_runner`. |
| `.mcp.json` | `generateJson: true` | MCP tool metadata file describing available tools, their parameters, and schemas. Used by MCP clients to discover and understand tool capabilities without connecting to the server. |
| `.openapi.json` | `generateRest: true` | OpenAPI 3.0 specification for RESTful API endpoints. Includes resource-based URLs, request/response schemas, proper HTTP status codes, and can be used with Swagger UI, API gateways, or client code generators. |
| `.openapi.dart` | `generateRest: true` | Complete REST API server implementation using the Shelf web framework. Serves the REST endpoints defined in the OpenAPI spec. Runs as a standard HTTP server on the configured port. |
| `.cli.dart` | `generateCli: true` | Runnable command-line application built on `package:args` `CommandRunner`. Each annotated class becomes a kebab-case command group, each `@Tool` method becomes a subcommand, and each parameter becomes a `--kebab-case` option. Complex parameters accept JSON inline (`--param='{...}'`) or via file (`--param=@file.json`). Output is pretty-printed JSON by default; `--compact` emits single-line JSON. |

**Generation Flags on `@Server`:**

```dart
@Server(
  transport: McpTransport.stdio,
  generateMcp: true,      // Generate .mcp.dart server (default: true)
  generateJson: false,    // Generate .mcp.json metadata (default: false)
  generateRest: false,    // Generate .openapi.json + .openapi.dart (default: false)
  generateCli: false,     // Generate .cli.dart command-line app (default: false)
)
```

**Example Output Files:**

```
example/
├── bin/
│   ├── example.dart                    # Annotated source file (you write this)
│   ├── example.mcp.dart                # Generated MCP server (stdio)
│   ├── example.mcp.json                # Generated tool metadata (optional)
│   ├── example.openapi.dart            # Generated REST API server (optional)
│   ├── example.openapi.json            # Generated OpenAPI 3.0 spec (optional)
│   └── example.cli.dart                # Generated CLI application (optional)
└── lib/src/
    ├── user.dart                       # Domain models
    ├── user_store.dart                 # Business logic
    ├── todo.dart
    └── todo_store.dart
```

**Use Cases:**

- **MCP Server Only** (`generateMcp: true`): Build AI-powered applications that integrate with Claude Desktop, Cursor, or other MCP clients
- **REST API Only** (`generateRest: true`): Create traditional HTTP APIs for web/mobile apps with full OpenAPI documentation
- **CLI Application** (`generateCli: true`): Ship a runnable command-line tool that exposes the same tools to shell users, scripts, and CI pipelines
- **Hybrid Distribution** (`generateMcp: true, generateRest: true, generateCli: true`): Serve AI agents, traditional HTTP clients, and shell users from the same annotated code
- **Metadata Export** (`generateJson: true`): Share tool specifications with team members or use in CI/CD pipelines

### Known Caveats

- **HTTP MCP transport — SSE keepalive buffering.** When `@Server(transport: McpTransport.http)` is used, the generated `.mcp.dart` exposes a Streamable-HTTP compliant endpoint (`GET` opens an SSE channel, `POST` handles JSON-RPC requests, `DELETE` terminates a session, `OPTIONS` returns CORS preflight). The HTTP response **headers** (`200 OK` + `Content-Type: text/event-stream`) flush immediately, which is what MCP clients rely on to accept the transport during the handshake. However, `dart:io`'s `HttpResponse` buffers small chunked writes, so the periodic keepalive comments (`: keepalive\n\n`, every 15s) may not be visible to raw tools like `curl -N` for several seconds. This does **not** affect correctness — all JSON-RPC request/response traffic flows normally over `POST`. If you need faster server-push flushing (for example, server-initiated tool notifications), pad the first SSE event with ~4 KiB of comment bytes or drop down to a raw `dart:io` `HttpServer` that calls `response.flush()` after each write.

## Table of Contents

- [Overview](#overview)
  - [What You Can Build](#what-you-can-build)
  - [Uses of Generated `.openapi.json`](#uses-of-generated-openapijson)
  - [Generated Files and Artifacts](#generated-files-and-artifacts)
  - [Known Caveats](#known-caveats)
- [Table of Contents](#table-of-contents)
- [Packages](#packages)
- [Quick Start](#quick-start)
  - [1. Add Dependencies](#1-add-dependencies)
  - [2. Annotate Your Functions](#2-annotate-your-functions)
  - [3. Run the Generator](#3-run-the-generator)
  - [4. Run the Server](#4-run-the-server)
- [Annotations](#annotations)
  - [`@Server`](#server)
  - [`@Tool`](#tool)
    - [Tool Annotations](#tool-annotations)
  - [`@Parameter` (Optional)](#parameter-optional)
  - [@Prompt (MCP Prompts)](#prompt-mcp-prompts)
  - [Code Mode](#code-mode)
  - [REST API Specification Generation](#rest-api-specification-generation)
- [Features](#features)
- [Development](#development)
  - [Prerequisites](#prerequisites)
  - [AI Agent Skills](#ai-agent-skills)
  - [Commands](#commands)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Packages

| Package | Description | Version |
|---------|-------------|---------|
| [`easy_api_annotations`](packages/easy_api_annotations) | Annotation definitions (`@Server`, `@Tool`, `@Parameter`) | [![pub package](https://img.shields.io/pub/v/easy_api_annotations.svg)](https://pub.dev/packages/easy_api_annotations) |
| [`easy_api_generator`](packages/easy_api_generator) | Build runner generator that produces MCP server code | [![pub package](https://img.shields.io/pub/v/easy_api_generator.svg)](https://pub.dev/packages/easy_api_generator) |

## Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  easy_api_annotations: ^0.6.0

dev_dependencies:
  build_runner: ^2.4.0
  easy_api_generator: ^0.6.1
```

### 2. Annotate Your Functions

```dart
import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(transport: McpTransport.stdio)
class UserServer {
  @Tool(description: 'Get user by ID')
  Future<User> getUser(
    @Parameter(
      title: 'User ID',
      description: 'The unique identifier for the user',
      example: 42,
    )
    int id,
  ) async {
    // ...
  }
  
  @Tool(description: 'Create a new user')
  Future<User> createUser({
    @Parameter(
      title: 'Name',
      description: 'The user\'s full name',
      example: 'Jane Doe',
    )
    required String name,
    
    @Parameter(
      title: 'Email',
      description: 'A valid email address',
      example: 'jane@example.com',
      pattern: r'^[\w\.-]+@[\w\.-]+\.\w+$',
    )
    required String email,
  }) async {
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

### `@Server`

Controls the transport type and configuration for the generated server.

```dart
// Stdio transport (default)
@Server(transport: McpTransport.stdio)

// HTTP transport with custom port and address
@Server(
  transport: McpTransport.http,
  port: 8080,                    // Default: 3000
  address: '0.0.0.0',            // Default: '127.0.0.1'
  generateJson: true,            // Optional: generate .mcp.json metadata
  generateMcp: true,             // Default: true — generate .mcp.dart server
  generateRest: false,           // Default: false — generate .openapi.json REST spec
  generateCli: false,            // Default: false — generate .cli.dart CLI application
  toolPrefix: 'user_service_',   // Optional: prefix all tool names
  autoClassPrefix: true,         // Optional: prefix with class name
  annotationsDefault: ToolAnnotations(  // Optional: server-wide defaults for tool hints
    openWorldHint: false,
  ),
)
```

> **Migration note:** `@Mcp` is still available as a deprecated typedef for backward compatibility. New code should use `@Server`.

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

#### Tool Annotations

Tools can carry behavioral hints via `ToolAnnotations` that inform MCP clients how they function:

- **`title`** — Human-readable display title.
- **`readOnlyHint`** — If `true`, the tool does not modify its environment (safe for auto-approval).
- **`destructiveHint`** — If `true`, the tool may perform destructive updates (clients should prompt for confirmation).
- **`idempotentHint`** — If `true`, repeated calls with the same arguments have no additional effect (safe to retry).
- **`openWorldHint`** — If `true`, the tool interacts with external entities like APIs or the internet. If `false`, it operates within a closed system.

Set server-wide defaults with `@Server(annotationsDefault: ...)` so all tools inherit the same hints unless overridden. If neither server defaults nor per-tool annotations are set, no annotations are emitted in the generated output.

```dart
@Tool(
  description: 'Get user by ID',
  annotations: ToolAnnotations(
    title: 'Get User',
    readOnlyHint: true,
    openWorldHint: false,
  ),
)
Future<User?> getUser(int id) async { ... }
```

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

### @Prompt (MCP Prompts)

Prompts are user-invoked templates that generate structured messages for interacting with language models. Unlike tools (which are model-called), prompts are explicitly selected by users, typically as slash commands in MCP clients like Claude Desktop.

```dart
import 'package:easy_api_annotations/easy_api_annotations.dart';

class CodeReviewPrompts {
  @Prompt(
    title: 'Code Review',
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
}
```

**Key Concepts:**

- **User-Controlled**: Prompts are explicitly invoked by users (e.g., `/code_review`), not auto-called by the model
- **Structured Messages**: Return a `PromptResult` containing a list of `PromptMessage` objects with roles (`user` or `assistant`)
- **Rich Content**: Support text, images, audio, and embedded resources via the `PromptContent` hierarchy
- **Typed Arguments**: Method parameters become prompt arguments, with optional `@PromptArgument` metadata

**`@Prompt` Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String?` | Custom prompt name (defaults to method name) |
| `title` | `String?` | Human-readable title shown in MCP clients |
| `description` | `String?` | Description of what the prompt does |

**`@PromptArgument` Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `alias` | `String?` | Custom external name for the argument |
| `title` | `String?` | Human-readable label displayed in clients |
| `description` | `String?` | Detailed description of the argument |
| `required` | `bool?` | Whether the argument is required (default: inferred from nullability) |

**Content Types:**

- `TextPromptContent` - Plain text messages
- `ImagePromptContent` - Base64-encoded images with MIME type
- `AudioPromptContent` - Base64-encoded audio with MIME type
- `ResourcePromptContent` - Embedded server-side resources with URI and MIME type

**Generated Output:**

When prompts are defined, the generator:
- Adds `PromptsSupport` mixin to the server class
- Registers prompts using `addPrompt()` in the constructor
- Generates `prompts/list` and `prompts/get` JSON-RPC handlers
- Includes prompt metadata in `.mcp.json` (when `generateJson: true`)

**Important Limitation:**

Libraries containing **only prompts** (no `@Tool` methods) must be explicitly imported in the file with the `@Server` annotation. The generator extracts prompts from imported libraries, but only if those libraries are already imported for other reasons (e.g., they contain tools or are imported by your main file).

**Example:**

```dart
// bin/example.dart
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:my_app/src/user_store.dart';  // Contains @Tool methods
import 'package:my_app/src/example_prompts.dart';  // Contains ONLY @Prompt methods

@Server(transport: McpTransport.stdio)
void main() {
  // The generator will extract prompts from both imported libraries
}
```

If `example_prompts.dart` is not imported, its prompts will not be included in the generated server.

### Code Mode

Enable batch tool orchestration via sandboxed JavaScript execution. Reduces latency by replacing N sequential round-trips with a single call.

```dart
@Server(
  codeMode: true,           // Enable the execute tool
  codeModeTimeout: 60,      // Optional: max execution time (default: 30s)
)
```

When enabled, an `execute` tool is generated that spawns a sandboxed Node.js subprocess where all code-mode-enabled tools are available as `external_*` async functions. The LLM can use `Promise.all()` for parallel calls and `await` for sequential logic.

**Benefits of Code Mode:**

- **Progressive Tool Discovery** - Instead of loading all tool definitions upfront (which can consume 100,000+ tokens), the agent discovers tools on-demand through the filesystem, reducing context usage by up to 98.7%
- **Context-Efficient Data Processing** - Filter, aggregate, and transform large datasets in the execution environment before returning results. Process 10,000 rows but return only the 5 that matter
- **Powerful Control Flow** - Use loops, conditionals, and error handling in code rather than chaining individual tool calls through the agent loop, saving both time and tokens
- **Privacy-Preserving Operations** - Intermediate results stay in the execution environment by default. Sensitive data flows through your workflow without entering the model's context unless explicitly logged
- **Parallel Execution** - Use `Promise.all()` to execute multiple independent tools simultaneously, dramatically reducing latency compared to sequential calls
- **Reduced Token Costs** - By writing code instead of making sequential tool calls, agents avoid loading intermediate results into context multiple times, saving significant tokens on complex workflows

**Requirements:** Node.js must be installed on the system.

> **Learn More:** Read Anthropic's comprehensive guide on [Code Execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) to understand the efficiency gains and architectural patterns.

> **Security note — Code Mode is an orchestration primitive, not a security sandbox.**
> The spawned Node.js subprocess runs with a 64 MB heap cap and a wall-clock timeout, but it has full access to the host filesystem, network, and `require('child_process')`. Treat any code that reaches `execute` with the same trust level as code you run locally, and enable Code Mode only for trusted LLMs / operators. For stricter isolation, consider running your MCP server inside a container or enabling Node.js [`--permission`](https://nodejs.org/api/permissions.html) flags (Node ≥ 20).

### REST API Specification Generation

Generate RESTful OpenAPI 3.0 specifications and a ready-to-run REST server alongside your MCP tools by setting `generateRest: true` on the `@Server` annotation:

```dart
@Server(
  transport: McpTransport.http,
  port: 8080,
  generateRest: true,  // Enable OpenAPI spec + REST server generation
)
class UserService {
  @Tool(description: 'Get user by ID')
  Future<User> getUser(int id) async { ... }
  
  @Tool(description: 'Create a new user')
  Future<User> createUser(String name, String email) async { ... }
}
```

This generates a `.openapi.json` file with:
- **RESTful endpoints** - Tools mapped to standard HTTP methods (GET, POST, PATCH, DELETE)
- **Resource-based URLs** - e.g., `/users`, `/users/{id}` instead of `/tools/createUser`
- **Request/response schemas** - Full type information with validation
- **Proper status codes** - 200, 201, 204, 400, 404 as appropriate
- **Tags and operation IDs** - For API organization and client generation

A companion `.openapi.dart` file is also generated, providing a complete REST API server implementation built on the Shelf web framework. The generated spec follows Swagger API design best practices and can be used with Swagger UI, API gateways, and client code generation tools.

## Features

- **AST-based parsing** - Uses `dart:analyzer` for reliable code extraction
- **Two transport modes** - stdio (JSON-RPC) and HTTP (Shelf-based)
- **Configurable HTTP server** - Customize port and bind address
- **Rich parameter metadata** - Optional `@Parameter` annotation for titles, descriptions, validation, sensitive flags, and enum values
- **MCP Prompts** - User-invoked prompt templates with `@Prompt` and `@PromptArgument` annotations for slash commands
- **Custom tool names** - Use `name` parameter on `@Tool`, `toolPrefix` or `autoClassPrefix` on `@Server` to avoid collisions
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

### AI Agent Skills

This project includes specialized skills for AI agents to assist with annotation and code generation:

- **Add Server Annotations Skill**: Located at `packages/easy_api_annotations/skills/easy_mcp_add-server-annotations/SKILL.md`
  - Helps AI agents automatically add `@Server`, `@Tool`, and `@Parameter` annotations to existing Dart code
  - Provides step-by-step workflow guidance for converting Dart libraries into MCP/REST servers
  - Includes best practices, common patterns (CRUD, API wrappers, utilities), and troubleshooting tips
  - **How to use**: Share this skill file with your AI assistant (Claude, Cursor, etc.) to guide it through the annotation process with expert-level knowledge of the Easy API framework

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

## Contributing

Contributions are welcome! Whether you're reporting a bug, improving docs, or
submitting a pull request, please read [CONTRIBUTING.md](CONTRIBUTING.md)
first. It covers local setup, the Melos-based workflow, coding standards,
testing, and the release process.

Quick links:

- [Open an issue](https://github.com/cdavis-code/easy_api_workplace/issues)
- [Contribution guide](CONTRIBUTING.md)
- [Development guidelines for agents](AGENTS.md)

## License

MIT License - see [LICENSE](LICENSE) for details.


