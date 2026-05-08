# MCP Example

<p align="center">
  <img src="https://raw.githubusercontent.com/cdavis-code/easy_api_workspace/refs/heads/main/images/logo-banner.svg" width="400" alt="easy_api">
</p>

Example demonstrating how to use `easy_api_annotations` and `easy_api_generator`. This example showcases a realistic many-to-many domain model where **Users** and **Todos** have bidirectional relationships — a todo can be assigned to multiple users, and a user can have multiple todos.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Transport Modes](#transport-modes)
- [Available Tools](#available-tools)
- [Code Mode](#code-mode)
- [Testing & Validation](#testing--validation)
  - [MCP Inspector (Recommended)](#1-mcp-inspector-recommended)
  - [MCP Inspector CLI Mode](#2-mcp-inspector-cli-mode)
  - [Manual curl Testing](#3-manual-curl-testing)
  - [stdio Pipe Testing](#4-stdio-pipe-testing)
  - [REST API Testing](#5-rest-api-testing)
- [Generated Artifacts](#generated-artifacts)
- [Project Structure](#project-structure)
- [Data Model](#data-model)

## Prerequisites

This example is part of the `easy_api_workplace`. From the project root:

```bash
dart pub get
```

**Additional Requirements:**
- **Dart SDK** 3.11+ (for running the servers)
- **Node.js** 22.7.5+ (for code mode sandbox and MCP Inspector)
- **build_runner** (for code generation)

## 🚀 Quick Start

### 1. Add annotations to your library

Use `@Server` on your entry point and `@Tool` on static methods you want to expose as MCP tools:

```dart
// bin/example.dart
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:mcp_example/src/user_store.dart';
import 'package:mcp_example/src/todo_store.dart';

@Server(transport: McpTransport.stdio)
Future<void> main() async {
  // Your initialization code...
}
```

#### HTTP Transport Configuration

For HTTP transport, you can customize the port and bind address:

```dart
@Server(
  transport: McpTransport.http,
  port: 8080,           // Default: 3000
  address: '0.0.0.0',   // Default: '127.0.0.1' (loopback)
)
Future<void> main() async {
  // Your initialization code...
}
```

**Note:** Use `address: '0.0.0.0'` to listen on all network interfaces (useful for Docker containers or remote access).

```dart
// lib/src/user_store.dart
class UserStore {
  @Tool(description: 'Create a new user')
  static Future<User> createUser({
    @Parameter(
      title: 'Full Name',
      description: 'The user\'s full name (1-100 characters)',
      example: 'John Doe',
    )
    required String name,
    @Parameter(
      title: 'Email Address',
      description: 'A valid email address for the user',
      example: 'john.doe@example.com',
      pattern: r'^[\w\.-]+@[\w\.-]+\.\w+$',
    )
    required String email,
  }) async { ... }

  @Tool(description: 'Get user by ID')
  static Future<User?> getUser(int id) async { ... }

  @Tool(description: 'Get all todos assigned to a user')
  static Future<List<Todo>> getUserTodos(int userId) async { ... }
}
```

#### Parameter Annotations (Optional)

The `@Parameter` annotation is **optional** and only needed when you want to provide additional metadata for parameters. By default, the generator extracts parameter information from Dart types and doc comments.

Use `@Parameter` when you need:
- Human-readable titles and descriptions
- Example values to guide users
- Validation constraints (min/max, patterns, enum values)
- To mark sensitive data (passwords, API keys)

**Without `@Parameter` (simpler approach):**
```dart
@Tool(description: 'Create a new user')
static Future<User> createUser({
  required String name,
  required String email,
}) async { ... }
```

**With `@Parameter` (rich metadata):**

```dart
@Tool(description: 'Create a new item')
static Future<Item> createItem({
  @Parameter(
    title: 'Item Name',
    description: 'A descriptive name for the item',
    example: 'My Awesome Item',
  )
  required String name,
  
  @Parameter(
    title: 'Quantity',
    description: 'Number of items (1-100)',
    minimum: 1,
    maximum: 100,
    example: 5,
  )
  int quantity = 1,
  
  @Parameter(
    title: 'Category',
    description: 'Item category',
    enumValues: ['electronics', 'clothing', 'food', 'other'],
    example: 'electronics',
  )
  String? category,
}) async { ... }
```

```dart
// lib/src/todo_store.dart
class TodoStore {
  @Tool(description: 'Create a new todo')
  static Future<Todo> createTodo({required String title}) async { ... }

  @Tool(description: 'Assign a todo to a user')
  static Future<Todo?> assignTodoToUser({required int todoId, required int userId}) async { ... }

  @Tool(description: 'Get all todos assigned to a user')
  static Future<List<Todo>> getTodosForUser(int userId) async { ... }
}
```

### 2. Run code generation

From the **project root** (not the example directory):

```bash
# Generate all .mcp.dart files
dart run build_runner build --delete-conflicting-outputs

# Or watch for changes
dart run build_runner build --delete-conflicting-outputs --watch
```

For the sample code above (`@Server(transport: McpTransport.stdio)` in `bin/example.dart`), this generates a single file:

- `bin/example.mcp.dart` — Generated stdio MCP server

No `.mcp.json` or `.openapi.json` is produced because `generateJson` and `generateRest` both default to `false`. Enable them on the `@Server` annotation (`generateJson: true`, `generateRest: true`) if you want those metadata artifacts.

The generator discovers all `@Tool`-annotated methods from libraries imported by the `@Server`-annotated entry point and registers them in a single MCP server.

### 3. Run the server

**stdio Transport (used by [bin/example.dart](bin/example.dart)):**
```bash
dart run example/bin/example.mcp.dart
```

**HTTP Transport:**

To produce an HTTP server, change `transport: McpTransport.stdio` to `McpTransport.http` in `bin/example.dart` (adjusting `port` / `address` as needed), re-run `build_runner`, then:

```bash
dart run example/bin/example.mcp.dart
# Server listens on http://<address>:<port>
```

## Available Tools

The generated MCP server exposes 14 tools organized by store:

### UserStore (6 tools)

| Tool | Description | Parameters |
|------|-------------|------------|
| `createUser` | Create a new user | `name` (String), `email` (String) |
| `getUser` | Get user by ID | `id` (int) |
| `listUsers` | List all users | none |
| `deleteUser` | Delete a user | `id` (int) |
| `searchUsers` | Search users by query | `query` (String) |
| `getUserTodos` | Get all todos assigned to a user | `userId` (int) |

### TodoStore (8 tools)

| Tool | Description | Parameters |
|------|-------------|------------|
| `createTodo` | Create a new todo | `title` (String) |
| `getTodo` | Get todo by ID | `id` (int) |
| `listTodos` | List all todos | none |
| `deleteTodo` | Delete a todo | `id` (int) |
| `completeTodo` | Mark a todo as completed | `id` (int) |
| `assignTodoToUser` | Assign a todo to a user | `todoId` (int), `userId` (int) |
| `removeTodoFromUser` | Remove a user from a todo | `todoId` (int), `userId` (int) |
| `getTodosForUser` | Get all todos assigned to a user | `userId` (int) |

## Annotations

### `@Server`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `transport` | `McpTransport` | `McpTransport.stdio` | Transport protocol (stdio or http) |
| `port` | `int` | `3000` | HTTP server port (only for HTTP transport) |
| `address` | `String` | `'127.0.0.1'` | HTTP bind address (only for HTTP transport). Use `'0.0.0.0'` to listen on all interfaces |
| `generateMcp` | `bool` | `true` | Whether to generate the MCP server (`.mcp.dart`) |
| `generateJson` | `bool` | `false` | Whether to generate `.mcp.json` tool-metadata file |
| `generateRest` | `bool` | `false` | Whether to generate a REST API server (`.openapi.dart`) and OpenAPI 3.0 spec (`.openapi.json`) |
| `toolPrefix` | `String?` | `null` | Prefix added to all tool names (e.g., `'user_'` makes `createUser` → `user_createUser`) |
| `autoClassPrefix` | `bool` | `false` | Automatically prefix tool names with class name (e.g., `UserService_createUser`) |
| `codeMode` | `bool` | `false` | Enables `search`/`execute` tools backed by a Node.js sandbox for batch tool orchestration |
| `codeModeTimeout` | `int` | `30` | Max execution time in seconds for code-mode scripts |
| `logErrors` | `bool` | `false` | Whether to log internal errors to stderr for troubleshooting |
| `annotationsDefault` | `ToolAnnotations?` | `null` | Server-wide defaults for the 4 boolean tool annotation hints. Individual tools can override via `@Tool(annotations: ...)`. |

### `@Tool`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String?` | `null` | Custom tool name (defaults to method name) |
| `description` | `String?` | auto-extract | Tool description (falls back to doc comment) |
| `icons` | `List<String>?` | `null` | Icon URLs |
| `annotations` | `ToolAnnotations?` | `null` | Behavioral hints for MCP clients: `title` (display name), `readOnlyHint` (no side-effects), `destructiveHint` (may delete/modify), `idempotentHint` (safe to retry), `openWorldHint` (interacts with external systems) |
| `codeMode` | `bool` | `true` | Whether this tool is exposed inside the code-mode sandbox |
| `codeModeVisible` | `bool` | `false` | When `@Server` has `codeMode: true`, keeps this tool visible in the standard `tools/list` response |

## 🚚 Transport Modes

This example supports **two transport protocols** for MCP communication:

### stdio Transport (Default - Recommended for Testing)

- **Communication**: JSON-RPC 2.0 over stdin/stdout
- **Best for**: CLI-based MCP clients, testing with MCP Inspector
- **Advantages**: 
  - Reliable bidirectional communication
  - Proper MCP protocol support
  - No HTTP overhead
  - Easier debugging
  - Official MCP Inspector support

**Run:**
```bash
dart run example/bin/example.mcp.dart
```

### HTTP Transport

- **Communication**: JSON-RPC 2.0 over HTTP POST requests
- **Best for**: Production deployment, web-based integrations
- **Configuration**:
  - Port: 8080
  - Address: 0.0.0.0 (all interfaces)
- **Advantages**:
  - Network accessible
  - Firewall-friendly
  - Standard web protocol

**Run:**
```bash
dart run example/bin/example.mcp.dart
# Server listens on http://0.0.0.0:8080
```

**Note:** The stdio transport is recommended for development and testing. See [Testing & Validation](#testing--validation) for detailed testing approaches.

---

## 🎯 Code Mode

**Code Mode** is a powerful feature that enables LLMs to generate JavaScript programs that orchestrate multiple tool calls in a single request.

### What is Code Mode?

Code Mode provides a Node.js sandbox where you can write JavaScript that:
- Calls multiple MCP tools sequentially or in parallel
- Uses `await` for sequential execution
- Uses `Promise.all()` for parallel execution
- Returns structured results
- Has access to all available tools via `external_*` functions

### How It Works

When `@Server(codeMode: true)` is enabled, the generated server includes:

1. **`search` Tool** - Search across available tools by name or description
   - Parameters: `query` (required), `detail_level` (optional: 'brief', 'detailed', 'full')
   - AND-matching on search terms
   - Returns matching tools with parameter information

2. **`execute` Tool** - Execute JavaScript code with tool access
   - Parameters: `code` (required) - JavaScript code to execute
   - Provides `call_tool(name, params)` for generic tool invocation
   - Provides `external_<toolName>(args)` convenience wrappers
   - All calls are async - use `await` for sequential, `Promise.all()` for parallel

3. **JavaScript Sandbox** - Isolated Node.js execution environment
   - 64MB memory limit
   - Configurable timeout (default: 30 seconds)
   - IPC via JSON-lines on stdin/stdout
   - Automatic cleanup of temp files
   - Blocked dangerous globals (`require`, `__dirname`, `__filename`, `process.exit()`)

### Code Mode Examples

**Example 1: Sequential Tool Calls**
```javascript
// Create a user, then create and assign a todo
const user = await external_createUser({
  name: 'CodeMode Tester',
  email: 'tester@codemode.test'
});

const todo = await external_createTodo({
  title: 'Test code mode workflow'
});

await external_assignTodoToUser({
  todoId: todo.id,
  userId: user.id
});

`Created user "${user.name}" with todo "${todo.title}"`;
```

**Example 2: Parallel Tool Calls**
```javascript
// Fetch users and todos simultaneously
const [users, todos] = await Promise.all([
  external_listUsers({}),
  external_listTodos({})
]);

`Users: ${users.length}, Todos: ${todos.length}`;
```

**Example 3: Search Then Execute**
```javascript
// Search for user-related tools
const searchResults = await external_search({
  query: 'user create',
  detail_level: 'detailed'
});

// Then create a user
const newUser = await external_createUser({
  name: 'Search Result User',
  email: 'search@test.com'
});

`Found ${searchResults.length} tools, created user ID ${newUser.id}`;
```

**Example 4: Complex Workflow with Filtering**
```javascript
// Get all users and their todo counts
const users = await external_listUsers({});

const results = [];
for (const user of users) {
  const todos = await external_getTodosForUser({ userId: user.id });
  results.push({
    name: user.name,
    email: user.email,
    todoCount: todos.length,
    todos: todos.map(t => t.title)
  });
}

JSON.stringify(results, null, 2);
```

### Code Mode Security

- ✅ 64MB memory limit for Node.js process
- ✅ 30-second timeout (configurable via `@Mcp(codeModeTimeout: X)`)
- ✅ Blocked dangerous globals
- ✅ Isolated temp directory (cleaned up after execution)
- ✅ Generic error messages (no internal details leaked)
- ✅ Tool filtering: Only tools with `codeMode != false` are exposed

**Note:** Destructive operations like `deleteUser` have `@Tool(codeMode: false)` and are intentionally unavailable from code mode to prevent accidental data loss.

---

##  Testing & Validation

This example provides **multiple testing approaches** to validate all functionality:

### 1. MCP Inspector (Recommended)

**Best for**: Interactive testing, exploring tools, testing code mode

**Launch:**
```bash
cd example
./launch_inspector.sh
```

This will:
- Clean up existing test data
- Launch MCP Inspector in your browser (http://localhost:6274)
- Auto-connect to the stdio server
- Display all 15 tools in the Tools tab

**What You Can Test:**
- ✅ All 15 individual tool calls
- ✅ Code mode sequential execution
- ✅ Code mode parallel execution
- ✅ Tool search functionality
- ✅ Data persistence across calls
- ✅ Cross-store operations (users ↔ todos)
- ✅ Many-to-many relationships
- ✅ Error handling

**See:** [TESTING.md](TESTING.md) for detailed testing guide with MCP Inspector setup, code mode examples, and troubleshooting.

### 2. MCP Inspector CLI Mode

**Best for**: Automated testing, scripting, CI/CD

**List available tools:**
```bash
npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/list
```

**Call individual tools:**
```bash
# UserStore tools
npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name listUsers

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name createUser --tool-arg 'name=Test User' --tool-arg 'email=test@example.com'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name getUser --tool-arg 'id=1'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name searchUsers --tool-arg 'query=Alice'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name getUserTodos --tool-arg 'userId=1'

# TodoStore tools
npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name createTodo --tool-arg 'title=Buy groceries'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name listTodos

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name completeTodo --tool-arg 'id=1'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name assignTodoToUser --tool-arg 'todoId=1' --tool-arg 'userId=1'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name removeTodoFromUser --tool-arg 'todoId=1' --tool-arg 'userId=1'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name getTodosForUser --tool-arg 'userId=1'

# Code Mode tools
npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name search --tool-arg 'query=user create' --tool-arg 'detail_level=detailed'

npx @modelcontextprotocol/inspector --cli dart run example/bin/example.mcp.dart --method tools/call --tool-name execute --tool-arg 'code=const users = await external_listUsers({}); `Found ${users.length} users`'
```

### 3. Manual curl Testing

**Best for**: Low-level protocol validation, debugging

**HTTP Transport:**
```bash
# Initialize
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"initialize",
    "params":{
      "protocolVersion":"2024-11-05",
      "capabilities":{},
      "clientInfo":{"name":"test","version":"1.0"}
    }
  }' | jq .

# List tools
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":2,
    "method":"tools/list",
    "params":{}
  }' | jq .

# Call a tool
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":3,
    "method":"tools/call",
    "params":{
      "name":"listUsers",
      "arguments":{}
    }
  }' | jq .
```

### 4. stdio Pipe Testing

**Best for**: Validating stdio protocol, automated testing

```bash
# Full initialization sequence with tool listing
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
} | dart run bin/example.mcp.dart 2>/dev/null | \
  grep -A 100 '"id":2' | \
  jq '.result.tools[] | .name'

# Expected output:
# "createUser"
# "listUsers"
# "getUser"
# "searchUsers"
# "deleteUser"
# "createTodo"
# "listTodos"
# "getTodo"
# "completeTodo"
# "deleteTodo"
# "assignTodoToUser"
# "removeTodoFromUser"
# "getTodosForUser"
# "getUserTodos"
# "execute_code"
# "search"
```

### 5. REST API Testing

**Best for**: Testing the generated Shelf-based REST server ([bin/example.openapi.dart](bin/example.openapi.dart)) — this is a separate server from the MCP server, produced when `@Server(generateRest: true)` is set.

**Run the REST server:**
```bash
dart run example/bin/example.openapi.dart
# Binds to http://0.0.0.0:8080 using the `port` and `address` from the @Server annotation
```

**Call endpoints with curl:**
```bash
# List users
curl -s http://localhost:8080/users | jq .

# Create a user
curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com"}' | jq .

# Get a user by id
curl -s http://localhost:8080/users/1 | jq .

# Search users
curl -s 'http://localhost:8080/users/search?query=Alice' | jq .

# List / create / delete todos
curl -s http://localhost:8080/todos | jq .
curl -s -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Buy groceries"}' | jq .
curl -s -X DELETE http://localhost:8080/todos/1
```

**Inspect the full contract** — the complete list of routes, request/response schemas, and validation rules lives in [bin/example.openapi.json](bin/example.openapi.json). Import it into Swagger UI, Postman, Insomnia, or Redoc for interactive exploration and client-code generation.

**See** [TESTING.md § Testing REST API Servers](TESTING.md#testing-rest-api-servers) for detailed walkthroughs including HTTPie, GUI HTTP clients, OpenAPI-spec verification, MCP-vs-REST comparison, and common considerations (Content-Type headers, CORS, error handling, shared data persistence with the MCP server).

### Testing Checklist

**Individual Tools (15 tools):**
- [ ] `createUser` - Create a new user
- [ ] `listUsers` - List all users
- [ ] `getUser` - Get user by ID
- [ ] `searchUsers` - Search users by query
- [ ] `deleteUser` - Delete a user (codeMode: false)
- [ ] `getUserTodos` - Get all todos assigned to a user
- [ ] `createTodo` - Create a new todo
- [ ] `listTodos` - List all todos
- [ ] `getTodo` - Get todo by ID
- [ ] `completeTodo` - Mark a todo as completed
- [ ] `deleteTodo` - Delete a todo
- [ ] `assignTodoToUser` - Assign a todo to a user
- [ ] `removeTodoFromUser` - Remove a user from a todo
- [ ] `getTodosForUser` - Get all todos assigned to a user

**Code Mode Tools (2 tools):**
- [ ] `search` - Search across available tools
- [ ] `execute_code` - Execute JavaScript code with tool access

**Code Mode Functionality:**
- [ ] Sequential tool calls with `await`
- [ ] Parallel tool calls with `Promise.all()`
- [ ] Tool discovery via `search`
- [ ] Complex workflows with filtering
- [ ] Error handling in JavaScript sandbox
- [ ] Timeout enforcement
- [ ] Memory limit enforcement
- [ ] Tool exclusion (`codeMode: false`)

**Protocol Validation:**
- [ ] MCP initialization handshake
- [ ] Tool listing via `tools/list`
- [ ] Tool execution via `tools/call`
- [ ] Error responses
- [ ] JSON-RPC 2.0 compliance

**Data Persistence:**
- [ ] Data survives across tool calls
- [ ] Many-to-many relationships maintained
- [ ] Automatic cleanup on deletion
- [ ] JSON file persistence (`users.json`, `todos.json`)

**Transport Modes:**
- [ ] stdio transport communication
- [ ] HTTP transport communication
- [ ] Bidirectional messaging
- [ ] Notification handling

---

## 📦 Generated Artifacts

Running `dart run build_runner build --delete-conflicting-outputs` from the project root uses the single source entry point shipped with this example ([bin/example.dart](bin/example.dart), configured with `McpTransport.stdio`, `generateJson: true`, `generateMcp: true`, `generateRest: true`) and produces exactly **four** files:

### Server Files
- **`example.mcp.dart`** — stdio MCP server
  - JSON-RPC 2.0 over stdin/stdout
  - Full code mode support (when `codeMode: true`)

### Metadata Files
- **`example.mcp.json`** — MCP tool metadata
  - Machine-readable tool descriptions
  - Parameter schemas
  - Tool capabilities

### OpenAPI / REST
- **`example.openapi.dart`** — REST API server implementation (Shelf-based)
  - Serves the endpoints described in `example.openapi.json`
- **`example.openapi.json`** — OpenAPI 3.0 specification
  - RESTful API documentation
  - Request/response schemas
  - Can be used with Swagger UI, client generators, and API gateways

### Optional: a second entry point for a different transport

If you want **both** a stdio server and an HTTP server side-by-side, add a second annotated source file — for example `bin/example.http.dart` with `@Server(transport: McpTransport.http, …)` — and re-run `build_runner`. `build_runner` names outputs after the input stem, so that would yield `bin/example.http.mcp.dart` (plus `.mcp.json`, `.openapi.dart`, `.openapi.json` if enabled) alongside the existing `bin/example.mcp.dart`. No `build.yaml` customisation is required.

### Generated Code Features

The generated `.mcp.dart` server includes:
- 15 tool registrations with JSON schemas
- Tool execution handlers with error handling
- Result serialization logic
- **Code mode infrastructure** (when `codeMode: true`):
  - `search` and `execute` tool registrations
  - `_codeModeToolSpecs` registry
  - `_search` handler with AND-matching
  - `_execute` handler with timeout
  - `_runCodeSandbox` method for Node.js execution
  - `_buildJsWrapper` for JavaScript sandbox generation
  - `_dispatchCodeModeToolCall` for tool routing
  - JavaScript IPC layer with `call_tool` and `external_*` functions

---

### Testing the Server

For detailed testing instructions, see **[TESTING.md](TESTING.md)** — a comprehensive guide covering:
- MCP Inspector setup and connection
- Code mode testing with JavaScript examples
- Tool discovery and orchestration
- Debug output configuration (`logErrors`)
- Troubleshooting common issues

**Quick Start with MCP Inspector:**
```bash
cd example
./launch_inspector.sh
```

This launches the interactive web UI at `http://localhost:6274` where you can:
- Explore all 15 tools
- Test individual tool calls
- Test code mode with JavaScript
- View server notifications
- Inspect tool schemas

---

## 📁 Project Structure

```
example/
├── bin/
│   ├── example.dart                  # Entry point with @Server (stdio transport)
│   ├── example.mcp.dart              # Generated stdio MCP server
│   ├── example.mcp.json              # Generated MCP tool metadata
│   ├── example.openapi.dart          # Generated REST API server (Shelf)
│   └── example.openapi.json          # Generated OpenAPI 3.0 spec
├── lib/
│   └── src/
│       ├── todo.dart                  # Todo model
│       ├── todo_store.dart            # TodoStore with @Tool methods
│       ├── user.dart                  # User model
│       └── user_store.dart            # UserStore with @Tool methods
├── build.yaml                         # Build runner configuration
├── launch_inspector.sh                # MCP Inspector launcher script
├── TESTING.md                         # Comprehensive testing guide with MCP Inspector
├── README.md                          # This file
└── pubspec.yaml                       # Package dependencies
```

## Data Model

This example demonstrates a many-to-many relationship between Users and Todos:

- **User** has `todoIds: List<int>` — references to assigned todos
- **Todo** has `userIds: List<int>` — references to assigned users

The relationship is bidirectional and managed by the assignment tools:
- `assignTodoToUser()` — adds references in both directions
- `removeTodoFromUser()` — removes references from both directions
- `deleteUser()` — automatically cleans up todo references
- `deleteTodo()` — automatically cleans up user references

Data is persisted to JSON files (`users.json`, `todos.json`) in the example directory.

## Generated Code

The generated `.mcp.dart` file creates a complete MCP server using `dart_mcp`. It imports each store with a unique alias to avoid naming conflicts:

```dart
import 'package:mcp_example/src/user_store.dart' as user_store;
import 'package:mcp_example/src/todo_store.dart' as todo_store;

base class MCPServerWithTools extends MCPServer with ToolsSupport {
  MCPServerWithTools(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'mcp-server',
          version: '1.0.0',
        ),
        instructions: 'Auto-generated MCP server',
      ) {
    registerTool(
      Tool(
        name: 'createUser',
        description: 'Create a new user',
        inputSchema: Schema.object(
          properties: {
            'name': Schema.string(),
            'email': Schema.string(),
          },
          required: ['name', 'email'],
        ),
      ),
      _createUser,
    );
    registerTool(
      Tool(
        name: 'createTodo',
        description: 'Create a new todo',
        inputSchema: Schema.object(
          properties: {
            'title': Schema.string(),
          },
          required: ['title'],
        ),
      ),
      _createTodo,
    );
    registerTool(
      Tool(
        name: 'assignTodoToUser',
        description: 'Assign a todo to a user',
        inputSchema: Schema.object(
          properties: {
            'todoId': Schema.int(),
            'userId': Schema.int(),
          },
          required: ['todoId', 'userId'],
        ),
      ),
      _assignTodoToUser,
    );
    // ... more tools from both stores
    
    // Code mode tools (when codeMode: true)
    registerTool(Tool(name: 'search', ...), _search);
    registerTool(Tool(name: 'execute', ...), _execute);
  }

  FutureOr<CallToolResult> _createUser(CallToolRequest request) async {
    final name = request.arguments!['name'] as String;
    final email = request.arguments!['email'] as String;
    final result = await user_store.UserStore.createUser(name: name, email: email);
    return CallToolResult(content: [TextContent(text: _serializeResult(result))]);
  }

  FutureOr<CallToolResult> _createTodo(CallToolRequest request) async {
    final title = request.arguments!['title'] as String;
    final result = await todo_store.TodoStore.createTodo(title: title);
    return CallToolResult(content: [TextContent(text: _serializeResult(result))]);
  }

  // ... more handlers
  
  // Code mode handlers (when codeMode: true)
  FutureOr<CallToolResult> _search(CallToolRequest request) async { ... }
  FutureOr<CallToolResult> _execute(CallToolRequest request) async { ... }
  Future<String?> _runCodeSandbox(String userCode, int timeoutSeconds) async { ... }
}
```

---

## 📊 Summary of Available Tests and Functionality

### What You Can Test

**✅ 15 Individual MCP Tools:**

**UserStore (6 tools):**
1. `createUser(name, email)` - Create a new user
2. `getUser(id)` - Get user by ID
3. `listUsers()` - List all users
4. `deleteUser(id)` - Delete a user (codeMode: false)
5. `searchUsers(query)` - Search users by query
6. `getUserTodos(userId)` - Get all todos assigned to a user

**TodoStore (8 tools):**
7. `createTodo(title)` - Create a new todo
8. `getTodo(id)` - Get todo by ID
9. `listTodos()` - List all todos
10. `deleteTodo(id)` - Delete a todo
11. `completeTodo(id)` - Mark a todo as completed
12. `assignTodoToUser(todoId, userId)` - Assign a todo to a user
13. `removeTodoFromUser(todoId, userId)` - Remove a user from a todo
14. `getTodosForUser(userId)` - Get all todos assigned to a user

**Code Mode (2 tools):**
15. `search(query, detail_level?)` - Search across available tools
16. `execute_code(code)` - Execute JavaScript with tool access

**✅ Code Mode Functionality:**
- Sequential tool calls with `await`
- Parallel tool calls with `Promise.all()`
- Tool discovery via search
- Complex workflows with filtering
- Error handling in JavaScript sandbox
- Timeout enforcement (configurable)
- Memory limit enforcement (64MB)
- Tool exclusion (`codeMode: false`)
- Dynamic tool invocation via `call_tool(name, params)`
- Convenience wrappers via `external_<toolName>(args)`

**✅ Transport Modes:**
- stdio transport (JSON-RPC over stdin/stdout)
- HTTP transport (JSON-RPC over HTTP POST)
- Bidirectional communication
- Proper MCP protocol implementation

**✅ Data Operations:**
- CRUD operations on Users and Todos
- Many-to-many relationship management
- Bidirectional reference maintenance
- Automatic cleanup on deletion
- JSON file persistence
- Data seeding on first run

**✅ Protocol Features:**
- MCP initialization handshake
- Tool listing via `tools/list`
- Tool execution via `tools/call`
- JSON-RPC 2.0 compliance
- Error responses
- Notifications support

**✅ Generated Artifacts:**
- MCP servers (stdio + HTTP)
- Tool metadata (JSON)
- OpenAPI 3.0 specifications
- Complete Dart source code

### Testing Approaches

| Approach | Best For | Transport | Automation |
|----------|----------|-----------|------------|
| **MCP Inspector (Web UI)** | Interactive testing, exploring | stdio | Manual |
| **MCP Inspector (CLI)** | Scripting, CI/CD | stdio | Automated |
| **curl Commands (MCP)** | Low-level MCP protocol validation | HTTP | Manual/Automated |
| **stdio Pipes** | MCP protocol validation | stdio | Automated |
| **curl Commands (REST)** | Verifying `example.openapi.dart` endpoints | HTTP (REST) | Manual/Automated |

### Documentation Files

- **[README.md](README.md)** - This file, comprehensive overview
- **[TESTING.md](TESTING.md)** - Complete testing guide with MCP Inspector setup, code mode examples, and troubleshooting

### Quick Commands

```bash
# Launch interactive testing
cd example
./launch_inspector.sh

# Regenerate servers
cd ..
dart run build_runner build --delete-conflicting-outputs

# Run the MCP server directly
dart run example/bin/example.mcp.dart

# Run the generated REST API server (binds to 0.0.0.0:8080)
dart run example/bin/example.openapi.dart
```

---

**Ready to test?** Start with `./launch_inspector.sh` for the best interactive experience!
