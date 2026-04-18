/// MCP annotations package
///
/// Provides annotations used to expose library methods as tools in the
/// Model Context Protocol (MCP) server.
library;

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

/// Annotation to mark a class, library, or method for MCP exposure.
///
/// Use this annotation to configure how the MCP server will be generated
/// for the annotated element. The generator uses these settings to create
/// the appropriate server transport and behavior.
///
/// The [transport] parameter determines whether the server uses stdio
/// (for CLI integration) or HTTP (for network access).
///
/// The [generateJson] parameter controls whether the generator should
/// also produce a JSON metadata file alongside the Dart code.
///
/// The [port] parameter specifies the port number for HTTP transport.
/// Only used when [transport] is [McpTransport.http]. Defaults to 3000.
///
/// The [address] parameter specifies the bind address for HTTP transport.
/// Only used when [transport] is [McpTransport.http].
/// Defaults to 'localhost'. Use '0.0.0.0' to listen on all interfaces.
///
/// The [toolPrefix] parameter adds a prefix to all tool names in this
/// scope. Useful for organizing tools by domain or avoiding naming
/// collisions when aggregating tools from multiple files.
///
/// Example:
/// ```dart
/// @Mcp(transport: McpTransport.stdio)
/// @Tool(description: 'Create users')
/// Future<bool> createUsers(List<User> users) async { ... }
/// ```
///
/// Example with HTTP transport:
/// ```dart
/// @Mcp(transport: McpTransport.http, port: 8080, address: '0.0.0.0')
/// @Tool(description: 'Create users')
/// Future<bool> createUsers(List<User> users) async { ... }
/// ```
///
/// Example with tool prefix:
/// ```dart
/// @Mcp(transport: McpTransport.stdio, toolPrefix: 'user_service_')
/// class UserService {
///   @Tool(description: 'Create user')
///   Future<User> createUser() async { ... }  // Tool name: user_service_createUser
/// }
/// ```
///
/// Example with auto class prefix:
/// ```dart
/// @Mcp(transport: McpTransport.stdio, autoClassPrefix: true)
/// class UserService {
///   @Tool(description: 'Create user')
///   Future<User> createUser() async { ... }  // Tool name: UserService_createUser
/// }
/// ```
class Mcp {
  /// The transport protocol used by the generated MCP server.
  ///
  /// Defaults to [McpTransport.stdio] for command-line integration.
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

  /// Whether to generate an OpenAPI 3.0 specification file.
  ///
  /// When true, the generator will create a `.openapi.json` file containing
  /// a RESTful OpenAPI 3.0 specification that represents the tools as standard
  /// API endpoints following REST conventions.
  ///
  /// The generated spec maps tool operations to HTTP methods:
  /// - Create operations → POST /{resource}
  /// - List operations → GET /{resource}
  /// - Get by ID → GET /{resource}/{id}
  /// - Update operations → PATCH /{resource}/{id}
  /// - Delete operations → DELETE /{resource}/{id}
  ///
  /// Defaults to false.
  final bool generateOpenApi;

  /// Creates an MCP configuration annotation.
  ///
  /// [transport] determines the communication protocol (stdio or HTTP).
  /// [generateJson] controls whether to generate additional JSON metadata.
  /// [port] specifies the HTTP server port (default: 3000).
  /// [address] specifies the HTTP bind address (default: '127.0.0.1').
  /// [toolPrefix] adds a prefix to all tool names in this scope.
  /// [autoClassPrefix] automatically prefixes tool names with class name.
  /// [generateOpenApi] controls whether to generate OpenAPI specification.
  const Mcp({
    this.transport = McpTransport.stdio,
    this.generateJson = false,
    this.port = 3000,
    this.address = '127.0.0.1',
    this.toolPrefix,
    this.autoClassPrefix = false,
    this.generateOpenApi = false,
  });
}

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
/// Example:
/// ```dart
/// @Tool(
///   name: 'user_create',
///   description: 'Creates a new user in the system',
///   icons: ['https://example.com/user-icon.png'],
/// )
/// Future<User> createUser({required String name, required String email}) async {
///   // Implementation
/// }
/// ```
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

  /// Deprecated: Execution metadata will be supported in a future version.
  ///
  /// Currently ignored. Reserved for future use to specify execution
  /// parameters like timeouts and resource limits.
  @Deprecated('Will be implemented in future version')
  final Map<String, Object?>? execution;

  /// Creates a Tool annotation.
  ///
  /// [name] - Optional custom tool name (defaults to method name).
  /// [description] - Human-readable description of the tool's purpose.
  /// [icons] - Optional list of icon URLs for visual identification.
  /// [execution] - Deprecated, will be implemented in a future version.
  const Tool({this.name, this.description, this.icons, this.execution});
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
class Parameter {
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
  /// Sensitive parameters (like passwords, API keys) may be masked
  /// in logs and UI by MCP clients.
  final bool sensitive;

  /// Allowed values for enum-like parameters.
  ///
  /// When specified, restricts the parameter to these specific values.
  final List<Object?>? enumValues;

  /// Creates a Parameter annotation.
  ///
  /// [title] - Human-readable title displayed in MCP clients.
  /// [description] - Detailed explanation of the parameter's purpose.
  /// [example] - Example value to guide users.
  /// [minimum] - Minimum allowed value for numeric types.
  /// [maximum] - Maximum allowed value for numeric types.
  /// [pattern] - Regular expression pattern for string validation.
  /// [sensitive] - Whether this parameter contains sensitive data.
  /// [enumValues] - List of allowed values for enum-like parameters.
  const Parameter({
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
