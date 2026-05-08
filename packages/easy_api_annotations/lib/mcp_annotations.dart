/// MCP annotations package
///
/// Provides annotations used to expose library methods as tools in the
/// Model Context Protocol (MCP) server.
library;

import 'package:meta/meta.dart';

/// Transport protocol options for MCP servers.
///
/// Determines how the generated MCP server will communicate with clients.
enum McpTransport {
  /// Communicate via standard input/output using JSON-RPC protocol.
  ///
  /// This is the default transport and is suitable for CLI-based MCP clients.
  stdio,

  /// Run an HTTP server using the shelf package.
  ///
  /// This transport allows remote clients to connect via HTTP requests.
  http,
}

/// Annotation to mark a class, library, or method for server generation.
///
/// Use this annotation to configure how the server code will be generated
/// for the annotated element. The generator uses these settings to create
/// MCP servers, REST API servers, or both.
///
/// The [generateMcp] parameter controls whether an MCP server implementation
/// is generated. The [generateRest] parameter controls whether a REST API
/// server and OpenAPI specification are generated.
///
/// The [transport] parameter determines whether the MCP server uses stdio
/// (for CLI integration) or HTTP (for network access). Only relevant when
/// [generateMcp] is `true`.
///
/// The [generateJson] parameter controls whether the generator should
/// also produce a JSON metadata file alongside the Dart code.
///
/// The [port] parameter specifies the port number for HTTP transport.
/// Only used when [transport] is [McpTransport.http]. Defaults to 3000.
///
/// The [address] parameter specifies the bind address for HTTP transport.
/// Only used when [transport] is [McpTransport.http].
/// Defaults to '127.0.0.1'. Use '0.0.0.0' to listen on all interfaces.
///
/// The [toolPrefix] parameter adds a prefix to all tool names in this
/// scope. Useful for organizing tools by domain or avoiding naming
/// collisions when aggregating tools from multiple files.
///
/// Example:
/// ```dart
/// @Server(transport: McpTransport.stdio)
/// @Tool(description: 'Create users')
/// Future<bool> createUsers(List<User> users) async { ... }
/// ```
///
/// Example with HTTP transport:
/// ```dart
/// @Server(transport: McpTransport.http, port: 8080, address: '0.0.0.0')
/// @Tool(description: 'Create users')
/// Future<bool> createUsers(List<User> users) async { ... }
/// ```
///
/// Example with tool prefix:
/// ```dart
/// @Server(transport: McpTransport.stdio, toolPrefix: 'user_service_')
/// class UserService {
///   @Tool(description: 'Create user')
///   Future<User> createUser() async { ... }  // Tool name: user_service_createUser
/// }
/// ```
///
/// Example with auto class prefix:
/// ```dart
/// @Server(transport: McpTransport.stdio, autoClassPrefix: true)
/// class UserService {
///   @Tool(description: 'Create user')
///   Future<User> createUser() async { ... }  // Tool name: UserService_createUser
/// }
/// ```
///
/// Tool-naming resolution order (applied in sequence):
/// 1. Base name — either [Tool.name] if provided, otherwise the Dart method name.
/// 2. Auto class prefix — if [autoClassPrefix] is `true` and the method lives
///    in a class, prepend `ClassName_`.
/// 3. Server tool prefix — if [toolPrefix] is set, prepend it last.
///
/// Combined example showing all three options together:
/// ```dart
/// @Server(
///   transport: McpTransport.stdio,
///   autoClassPrefix: true,
///   toolPrefix: 'api_',
/// )
/// class UserService {
///   // Base:  'createUser'       (Dart method name)
///   // Step 2: 'UserService_createUser'   (+ autoClassPrefix)
///   // Step 3: 'api_UserService_createUser' (+ toolPrefix)  ← final tool name
///   @Tool(description: 'Create user')
///   Future<User> createUser() async { ... }
///
///   // Base:  'user_make'        (from @Tool.name, overrides method name)
///   // Step 2: 'UserService_user_make'
///   // Step 3: 'api_UserService_user_make'                 ← final tool name
///   @Tool(name: 'user_make', description: 'Create user (custom name)')
///   Future<User> createUserCustom() async { ... }
/// }
/// ```
@immutable
class Server {
  /// The transport protocol used by the generated MCP server.
  ///
  /// Defaults to [McpTransport.stdio] for command-line integration.
  ///
  /// Note: This setting is only relevant when [generateMcp] is `true`.
  final McpTransport transport;

  /// Whether to generate a JSON metadata file in addition to Dart code.
  ///
  /// When true, the generator will create a `.mcp.json` file containing
  /// tool metadata and schema definitions.
  final bool generateJson;

  /// The port number for HTTP transport.
  ///
  /// Only used when [transport] is [McpTransport.http].
  /// Defaults to 3000.
  final int port;

  /// The bind address for HTTP transport.
  ///
  /// Only used when [transport] is [McpTransport.http].
  /// Defaults to '127.0.0.1' (loopback). Use '0.0.0.0' to listen on all interfaces.
  final String address;

  /// Optional prefix for all tool names in this scope.
  ///
  /// When specified, this prefix is prepended to each tool name.
  /// Useful for organizing tools by domain (e.g., 'user_', 'order_')
  /// or avoiding collisions when aggregating tools from multiple sources.
  /// The prefix is applied after any custom name from @Tool.name.
  final String? toolPrefix;

  /// Whether to automatically prefix tool names with their class name.
  ///
  /// When true, tools defined in classes will be named `ClassName_methodName`
  /// instead of just `methodName`. This helps avoid naming collisions when
  /// multiple classes have methods with the same name.
  ///
  /// The class name prefix is applied before any custom [toolPrefix].
  /// For example, with `autoClassPrefix: true` and `toolPrefix: 'api_'`,
  /// a method `createUser` in class `UserService` becomes `api_UserService_createUser`.
  ///
  /// Defaults to false for backward compatibility.
  final bool autoClassPrefix;

  /// Whether to generate MCP server code (`.mcp.dart` and `.mcp.json`).
  ///
  /// When `true` (the default), a complete MCP server implementation is
  /// generated. Set to `false` if you only need REST API server generation.
  ///
  /// Note: [transport], [codeMode], [codeModeTimeout], and related MCP-specific
  /// settings are only relevant when this is `true`.
  final bool generateMcp;

  /// Whether to generate a REST API server (`.openapi.dart` and `.openapi.json`).
  ///
  /// When `true`, a standalone REST API server using shelf_plus is generated
  /// alongside an OpenAPI 3.0 specification. The REST endpoints are
  /// automatically mapped from the annotated tool methods.
  ///
  /// Defaults to `false`.
  final bool generateRest;

  /// Whether to enable code mode for this MCP server.
  ///
  /// When true, generates `search` and `execute` tools that allow LLMs
  /// to discover and orchestrate multiple tool calls in a single JavaScript
  /// program instead of making sequential round-trips. This reduces latency
  /// (N round-trips → 1), reduces token usage, enables parallelism via
  /// `Promise.all`, and allows complex logic (math, data transformations).
  ///
  /// The `search` tool lets LLMs discover available tools by name or
  /// description without loading all tool schemas into context. It returns
  /// matching tools at brief, detailed, or full detail levels.
  ///
  /// The `execute` tool spawns a sandboxed Node.js subprocess where all
  /// code-mode-enabled tools are available as `external_*` async functions
  /// and via the generic `call_tool(name, params)` function. The LLM
  /// generates JavaScript code that calls these functions and returns a
  /// structured result.
  ///
  /// Tools can be individually excluded from code mode by setting
  /// `@Tool(codeMode: false)`, which removes them from the search
  /// index and the sandbox environment.
  ///
  /// Code mode requires Node.js to be installed on the system.
  ///
  /// Example:
  /// ```dart
  /// @Server(transport: McpTransport.http, codeMode: true)
  /// class UserService {
  ///   @Tool(description: 'Create user')
  ///   Future<User> createUser() async { ... }
  /// }
  /// ```
  ///
  /// Defaults to false.
  final bool codeMode;

  /// Maximum execution time in seconds for code mode scripts.
  ///
  /// Only used when [codeMode] is true. If a script exceeds this timeout,
  /// the sandbox process is forcefully terminated and an error is returned.
  ///
  /// Defaults to 30 seconds.
  final int codeModeTimeout;

  /// Whether to log internal errors to stderr for troubleshooting.
  ///
  /// When true, generated tool handlers will write the full exception
  /// message and stack trace to stderr before returning a generic error
  /// to the MCP client. This helps developers diagnose issues (file I/O
  /// errors, type mismatches, etc.) while keeping client-facing error
  /// messages safe and generic.
  ///
  /// stderr output is visible in the MCP Inspector's "Error output from
  /// MCP server" pane, in terminal output when running via `dart run`,
  /// and in any client that captures the subprocess's stderr stream.
  ///
  /// When false (the default), no diagnostic output is produced,
  /// keeping logs clean for production deployments.
  ///
  /// Defaults to false.
  final bool logErrors;

  /// Server-wide default values for tool annotation hints.
  ///
  /// When set, the 4 boolean hints ([ToolAnnotations.readOnlyHint],
  /// [ToolAnnotations.destructiveHint], [ToolAnnotations.idempotentHint],
  /// [ToolAnnotations.openWorldHint]) are applied as defaults to every
  /// generated tool. Individual tools can override any hint via their own
  /// `@Tool(annotations: ToolAnnotations(...))`.
  ///
  /// **Merge rules:**
  /// - Tool-level values always take precedence over server defaults for
  ///   the same key.
  /// - The [ToolAnnotations.title] field is _never_ inherited from server
  ///   defaults; each tool must provide its own title.
  /// - If neither server defaults nor tool-level annotations exist for a
  ///   tool, no annotations are emitted for that tool.
  ///
  /// Example:
  /// ```dart
  /// @Server(
  ///   annotationsDefault: ToolAnnotations(openWorldHint: false),
  /// )
  /// class MyService {
  ///   @Tool(annotations: ToolAnnotations(readOnlyHint: true))
  ///   // → merged: {readOnlyHint: true, openWorldHint: false}
  ///   Future<User> getUser(int id) async { ... }
  ///
  ///   @Tool(description: 'Create user')
  ///   // → merged: {openWorldHint: false} (server default only)
  ///   Future<User> createUser(String name) async { ... }
  /// }
  /// ```
  ///
  /// Defaults to null (no server-wide annotation defaults).
  final ToolAnnotations? annotationsDefault;

  /// Creates a server configuration annotation.
  ///
  /// [transport] determines the communication protocol (stdio or HTTP).
  /// [generateJson] controls whether to generate additional JSON metadata.
  /// [port] specifies the HTTP server port (default: 3000).
  /// [address] specifies the HTTP bind address (default: '127.0.0.1').
  /// [toolPrefix] adds a prefix to all tool names in this scope.
  /// [autoClassPrefix] automatically prefixes tool names with class name.
  /// [generateMcp] controls whether to generate MCP server code.
  /// [generateRest] controls whether to generate REST API server and OpenAPI spec.
  /// [codeMode] enables the search and execute tools for tool orchestration.
  /// [codeModeTimeout] sets the max execution time for code mode scripts.
  /// [logErrors] controls whether internal errors are logged to stderr.
  /// [annotationsDefault] provides server-wide defaults for tool annotation hints.
  const Server({
    this.transport = McpTransport.stdio,
    this.generateJson = false,
    this.port = 3000,
    this.address = '127.0.0.1',
    this.toolPrefix,
    this.autoClassPrefix = false,
    this.generateMcp = true,
    this.generateRest = false,
    this.codeMode = false,
    this.codeModeTimeout = 30,
    this.logErrors = false,
    this.annotationsDefault,
  });
}

/// @nodoc
@Deprecated('Use Server instead. Will be removed in a future version.')
typedef Mcp = Server;

/// Annotation that describes an MCP tool.
///
/// Apply this annotation to methods that should be exposed as tools
/// in the generated MCP server. Each tool becomes callable by MCP clients.
///
/// The [name] parameter allows specifying a custom tool name. If not provided,
/// the method name is used. This is useful for avoiding naming collisions
/// when multiple classes have methods with the same name, or for creating
/// more descriptive tool names.
///
/// The [description] provides a human-readable explanation of what
/// the tool does. If not provided, the generator will use the method's
/// dartdoc comment.
///
/// The [icons] parameter allows specifying icon URLs for UI clients
/// that display available tools.
///
/// The [annotations] parameter provides behavioral hints to MCP clients,
/// such as whether the tool is read-only, destructive, or idempotent.
///
/// Example:
/// ```dart
/// @Tool(
///   name: 'user_create',
///   description: 'Creates a new user in the system',
///   icons: ['https://example.com/user-icon.png'],
///   annotations: ToolAnnotations(
///     destructiveHint: false,
///     idempotentHint: false,
///     openWorldHint: false,
///   ),
/// )
/// Future<User> createUser({required String name, required String email}) async {
///   // Implementation
/// }
/// ```
@immutable
class Tool {
  /// Optional custom name for this tool.
  ///
  /// If provided, this name is used instead of the method name.
  /// Useful for avoiding naming collisions or creating more descriptive
  /// tool names. Must be unique within the MCP server.
  final String? name;

  /// Optional text describing what this tool does.
  ///
  /// If not provided, the generator will use the method's dartdoc comment.
  /// This description is shown to users in MCP clients.
  final String? description;

  /// Optional list of icon URLs for this tool.
  ///
  /// These icons may be displayed by MCP clients to visually identify
  /// the tool. Supported formats depend on the client.
  final List<String>? icons;

  /// Optional behavioral annotations for this tool.
  ///
  /// Provides hints to MCP clients about the tool's behavior — whether it
  /// is read-only, destructive, idempotent, or interacts with external
  /// systems. Clients may use these hints to surface approval dialogs or
  /// auto-permit safe operations.
  ///
  /// Example:
  /// ```dart
  /// @Tool(
  ///   description: 'Get user by ID',
  ///   annotations: ToolAnnotations(readOnlyHint: true),
  /// )
  /// Future<User?> getUser(int id) async { ... }
  /// ```
  final ToolAnnotations? annotations;

  /// Whether this tool should be available in code mode.
  ///
  /// Only meaningful when the parent [Server] annotation has `codeMode: true`.
  /// When true (the default), this tool is:
  /// - Listed in the `search` tool's results so LLMs can discover it
  /// - Available as an async JavaScript function named `external_<toolName>`
  ///   in the `execute` tool's sandbox
  /// - Callable via the generic `call_tool(name, params)` function
  ///
  /// Set to false for tools that should not be available in code mode,
  /// such as destructive operations that require explicit confirmation.
  /// Tools with `codeMode: false` are excluded from the search index
  /// and the sandbox environment entirely.
  ///
  /// Note: This controls *sandbox* availability, not whether the tool
  /// appears in the standard `tools/list` response. See [codeModeVisible]
  /// for tool list visibility.
  ///
  /// Example:
  /// ```dart
  /// @Tool(description: 'Delete a user', codeMode: false)
  /// Future<bool> deleteUser(int id) async { ... }
  /// ```
  ///
  /// Defaults to true.
  final bool codeMode;

  /// Whether this tool should remain visible in the standard `tools/list`
  /// response when the parent [Server] annotation has `codeMode: true`.
  ///
  /// When [Server.codeMode] is true, the standard tool list is replaced by
  /// just the `search` and `execute` tools so that LLMs orchestrate
  /// everything through the JavaScript sandbox. Individual tools can
  /// opt back in to the standard list by setting `codeModeVisible: true`.
  ///
  /// When [Server.codeMode] is false, this field has no effect — all tools
  /// are always listed.
  ///
  /// This is independent of [codeMode]: a tool can be visible in the
  /// standard list and also available inside the sandbox, or visible only
  /// in one of the two surfaces.
  ///
  /// Example — expose a single tool directly alongside search/execute:
  /// ```dart
  /// @Tool(description: 'Ping the server', codeModeVisible: true)
  /// String ping() => 'pong';
  /// ```
  ///
  /// Defaults to false.
  final bool codeModeVisible;

  /// Creates a Tool annotation.
  ///
  /// [name] - Optional custom tool name (defaults to method name).
  /// [description] - Human-readable description of the tool's purpose.
  /// [icons] - Optional list of icon URLs for visual identification.
  /// [annotations] - Behavioral hints for MCP clients (read-only,
  ///   destructive, idempotent, open-world).
  /// [codeMode] - Whether this tool is available in the code mode sandbox
  ///   (default: true).
  /// [codeModeVisible] - Whether this tool remains listed in `tools/list`
  ///   when the parent `@Server` has `codeMode: true` (default: false).
  const Tool({
    this.name,
    this.description,
    this.icons,
    this.annotations,
    this.codeMode = true,
    this.codeModeVisible = false,
  });
}

/// Metadata hints that describe a Tool's behavior to MCP clients.
///
/// These annotations inform clients _how_ a tool functions — whether it
/// reads or mutates state, whether repeated calls are safe, and whether
/// it interacts with external systems — enabling clients to automatically
/// permit safe queries or request approval before risky actions.
///
/// **Important:** All properties are _hints_. Clients should not rely on
/// them for security decisions.
///
/// Example:
/// ```dart
/// @Tool(
///   description: 'Delete a user permanently',
///   annotations: ToolAnnotations(
///     destructiveHint: true,
///     idempotentHint: true,
///     openWorldHint: false,
///   ),
/// )
/// Future<void> deleteUser(String id) async { ... }
/// ```
///
/// Example — read-only tool:
/// ```dart
/// @Tool(
///   description: 'Look up a user by ID',
///   annotations: ToolAnnotations(
///     title: 'Get User',
///     readOnlyHint: true,
///     openWorldHint: false,
///   ),
/// )
/// Future<User?> getUser(int id) async { ... }
/// ```
@immutable
class ToolAnnotations {
  /// A human-readable title for the tool.
  ///
  /// When provided, MCP clients may display this instead of (or alongside)
  /// the tool name.
  final String? title;

  /// If true, the tool does not modify its environment.
  ///
  /// Read-only tools are safe to call without side-effects. Defaults to
  /// `false` when omitted.
  final bool? readOnlyHint;

  /// If true, the tool may perform destructive updates to its environment.
  ///
  /// Only meaningful when [readOnlyHint] is `false`. Defaults to `true`
  /// when omitted (conservative assumption).
  final bool? destructiveHint;

  /// If true, calling the tool repeatedly with the same arguments will have
  /// no additional effect on its environment.
  ///
  /// Only meaningful when [readOnlyHint] is `false`. Defaults to `false`
  /// when omitted.
  final bool? idempotentHint;

  /// If true, this tool may interact with an "open world" of external
  /// entities (e.g., the internet, third-party APIs).
  ///
  /// If false, the tool's domain of interaction is closed (e.g., a local
  /// database or in-memory store). Defaults to `true` when omitted.
  final bool? openWorldHint;

  /// Creates tool annotations.
  ///
  /// [title] - Human-readable display title.
  /// [readOnlyHint] - Tool does not modify its environment.
  /// [destructiveHint] - Tool may perform destructive updates.
  /// [idempotentHint] - Repeated calls with same args have no additional effect.
  /// [openWorldHint] - Tool interacts with external entities.
  const ToolAnnotations({
    this.title,
    this.readOnlyHint,
    this.destructiveHint,
    this.idempotentHint,
    this.openWorldHint,
  });
}

/// Annotation to provide rich metadata for individual parameters in a Tool.
///
/// Use this annotation to customize how parameters are presented to MCP clients,
/// including human-readable titles, descriptions, validation hints, and examples.
///
/// Example:
/// ```dart
/// @Tool(description: 'Create a new user')
/// Future<User> createUser({
///   @Parameter(
///     title: 'Full Name',
///     description: 'The user\'s complete name including first and last name',
///     example: 'John Doe',
///   )
///   required String name,
///
///   @Parameter(
///     title: 'Email Address',
///     description: 'A valid email address for the user',
///     example: 'john.doe@example.com',
///   )
///   required String email,
///
///   @Parameter(
///     title: 'Age',
///     description: 'User age in years',
///     minimum: 0,
///     maximum: 150,
///     example: 25,
///   )
///   int? age,
/// }) async { ... }
/// ```
@immutable
class Parameter {
  /// Custom name for this parameter in generated REST APIs, MCP tool schemas,
  /// and OpenAPI specifications.
  ///
  /// When set, the [alias] is used as the external parameter name instead of
  /// the Dart method parameter name. The Dart parameter name is still used
  /// in the source code.
  ///
  /// Example:
  /// ```dart
  /// @Parameter(alias: 'q') String searchQuery
  /// ```
  /// This makes the parameter appear as `q` in REST query strings,
  /// JSON request bodies, and MCP tool input schemas.
  final String? alias;

  /// Human-readable title for this parameter.
  ///
  /// Displayed as the label in MCP clients. If not provided,
  /// the parameter name will be used.
  final String? title;

  /// Detailed description of what this parameter represents.
  ///
  /// Provides context to help users understand what value to provide.
  /// If not provided, the generator will look for dartdoc on the parameter.
  final String? description;

  /// Example value for this parameter.
  ///
  /// Shown to users as a hint for the expected format or value.
  /// Helps LLMs understand the expected input format.
  final Object? example;

  /// Minimum value for numeric parameters.
  ///
  /// Used for validation of int and double types.
  final num? minimum;

  /// Maximum value for numeric parameters.
  ///
  /// Used for validation of int and double types.
  final num? maximum;

  /// Regular expression pattern for string validation.
  ///
  /// When provided, the parameter value must match this pattern.
  final String? pattern;

  /// Whether this parameter should be marked as sensitive.
  ///
  /// Sensitive parameters (like passwords, API keys) are surfaced to downstream
  /// tooling so it can mask values in UIs and logs. When `sensitive: true`:
  ///
  /// - `.mcp.json` inputSchema adds `"x-sensitive": true` on the property
  ///   (plus `"format": "password"` for string types).
  /// - `.openapi.json` adds `writeOnly: true` on the schema
  ///   (plus `format: 'password'` for string types), following OpenAPI 3.0
  ///   conventions for secrets.
  ///
  /// MCP clients and OpenAPI UIs may use these markers to hide the value.
  final bool sensitive;

  /// Allowed values for enum-like parameters.
  ///
  /// When specified, restricts the parameter to these specific values.
  final List<Object?>? enumValues;

  /// Creates a Parameter annotation.
  ///
  /// [alias] - Custom external name for this parameter.
  /// [title] - Human-readable title displayed in MCP clients.
  /// [description] - Detailed explanation of the parameter's purpose.
  /// [example] - Example value to guide users.
  /// [minimum] - Minimum allowed value for numeric types.
  /// [maximum] - Maximum allowed value for numeric types.
  /// [pattern] - Regular expression pattern for string validation.
  /// [sensitive] - Whether this parameter contains sensitive data.
  /// [enumValues] - List of allowed values for enum-like parameters.
  const Parameter({
    this.alias,
    this.title,
    this.description,
    this.example,
    this.minimum,
    this.maximum,
    this.pattern,
    this.sensitive = false,
    this.enumValues,
  });
}
