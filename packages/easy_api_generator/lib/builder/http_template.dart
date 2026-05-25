// HTTP MCP server template generator.

import 'package:easy_api_generator/builder/template_utils.dart';
import 'package:easy_api_generator/builder/schema_builder.dart';

/// Generates HTTP server code from tool definitions using dart_mcp.
///
/// This template creates a complete HTTP MCP server that:
/// - Uses the shelf package for HTTP request handling
/// - Supports configurable port and bind address
/// - Implements bidirectional communication via StreamChannel
/// - Registers all tools with their JSON schemas
/// - Handles tool execution with proper error handling
///
/// The generated server uses conditional imports for `dart:io` only when
/// the default loopback address (127.0.0.1) is specified or code mode is
/// enabled, avoiding unused import warnings for custom addresses without
/// code mode.
///
/// Example generated server configuration:
/// ```dart
/// // Default address uses InternetAddress type
/// await shelf_io.serve(handler, io.InternetAddress.loopbackIPv4, 3000);
///
/// // Custom address uses string literal
/// await shelf_io.serve(handler, '0.0.0.0', 8080);
/// ```
class HttpTemplate {
  /// Generates the HTTP server Dart code.
  ///
  /// [tools] - List of tool definitions with parameters and metadata
  /// [port] - The network port to listen on (e.g., 3000, 8080)
  /// [address] - The bind address (e.g., '127.0.0.1', '0.0.0.0')
  /// [codeMode] - Enable code mode with JavaScript sandbox (default: false)
  /// [codeModeTimeout] - Timeout for code mode execution in seconds (default: 30)
  /// [corsOrigins] - Allowed CORS origins (default: `['*']` for backward compatibility)
  ///
  /// Returns the complete server code as a Dart string.
  static String generate(
    List<Map<String, dynamic>> tools,
    int port,
    String address, {
    bool codeMode = false,
    int codeModeTimeout = 30,
    bool logErrors = false,
    List<Map<String, dynamic>> prompts = const [],
    List<String> corsOrigins = const ['*'],
  }) {
    // Collect unique imports for custom List inner types
    final listInnerImports = collectListInnerImports(tools);
    final listInnerImportStatements = listInnerImports
        .map((uri) => "import '$uri';")
        .join('\n');

    // Determine the address expression to use
    final addressExpression = address == '127.0.0.1'
        ? 'io.InternetAddress.loopbackIPv4'
        : "'$address'";

    // Collect unique per-tool source imports with aliases
    final sourceImports = <String, String>{};
    for (final tool in tools) {
      final sourceImport = tool['sourceImport'] as String?;
      final sourceAlias = tool['sourceAlias'] as String?;
      if (sourceImport != null && sourceAlias != null) {
        sourceImports[sourceImport] = sourceAlias;
      }
    }

    // Also collect source imports from prompts
    for (final prompt in prompts) {
      final sourceImport = prompt['sourceImport'] as String?;
      final sourceAlias = prompt['sourceAlias'] as String?;
      if (sourceImport != null && sourceAlias != null) {
        sourceImports[sourceImport] = sourceAlias;
      }
    }

    final sourceImportStatements = sourceImports.entries
        .map((e) => "import '${e.key}' as ${e.value};")
        .join('\n');

    // Filter code mode tools
    final codeModeTools = codeMode
        ? filterCodeModeTools(tools)
        : <Map<String, dynamic>>[];

    final listedTools = codeMode ? filterCodeModeVisibleTools(tools) : tools;
    final handlerTools = codeMode
        ? filterHandlerToolsForCodeMode(tools)
        : tools;

    final toolRegistrations = listedTools
        .map((t) {
          final name = t['name'] as String;
          final camelHandlerName = t['camelCaseHandlerName'] as String? ?? name;
          final description = (t['description'] as String?) ?? 'Tool $name';
          final schema = SchemaBuilder.buildObjectSchema(
            (t['parameters'] as List<Map<String, dynamic>>? ?? []),
          );
          final annotationsExpr = generateAnnotationsExpression(t);
          return '''
    registerTool(
      Tool(
        name: '${escapeDartString(name)}',
        description: '${escapeDartString(description)}',
        inputSchema: $schema,$annotationsExpr
      ),
      _$camelHandlerName,
    );''';
        })
        .join('\n');

    final codeModeRegistrations = codeMode
        ? generateCodeModeToolRegistrations()
        : '';

    final toolHandlers = handlerTools
        .map((t) {
          final name = t['name'] as String;
          final camelHandlerName = t['camelCaseHandlerName'] as String? ?? name;
          final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
          final paramExtractions = params
              .map((p) {
                final paramType = p['type'] as String;
                final dt = dartType(paramType);
                return renderMcpParamExtraction(p, dt);
              })
              .join('\n');

          final paramValidations = params
              .map((p) => renderParamValidation(p))
              .where((v) => v.isNotEmpty)
              .join('\n');

          final paramConversions = params
              .where((p) => needsListConversion(p['type'] as String))
              .map((p) {
                final paramName = p['name'] as String;
                final paramType = p['type'] as String;
                final innerType = extractListInnerType(paramType);
                final isOptional = p['isOptional'] == true;
                if (isOptional) {
                  return '    final ${paramName}Converted = $paramName?.map((e) => $innerType.fromJson(e as Map<String, dynamic>)).toList();';
                }
                return '    final ${paramName}Converted = $paramName.map((e) => $innerType.fromJson(e as Map<String, dynamic>)).toList();';
              })
              .join('\n');

          final isAsync = t['isAsync'] == true;
          final className = t['className'] as String?;
          final isStatic = t['isStatic'] == true;
          final sourceAlias = t['sourceAlias'] as String? ?? 'lib';

          String call;
          final methodName = t['methodName'] as String? ?? name;
          if (className != null && isStatic) {
            call = isAsync
                ? 'await $sourceAlias.$className.$methodName(${callArgsWithConversion(params)})'
                : '$sourceAlias.$className.$methodName(${callArgsWithConversion(params)})';
          } else if (className != null) {
            call = isAsync
                ? 'await $sourceAlias.$className().$methodName(${callArgsWithConversion(params)})'
                : '$sourceAlias.$className().$methodName(${callArgsWithConversion(params)})';
          } else {
            call = isAsync
                ? 'await $sourceAlias.$methodName(${callArgsWithConversion(params)})'
                : '$sourceAlias.$methodName(${callArgsWithConversion(params)})';
          }

          return '''
  FutureOr<CallToolResult> _$camelHandlerName(CallToolRequest request) async {
    try {
$paramExtractions
$paramValidations
$paramConversions
      final result = $call;
      return CallToolResult(
        content: [TextContent(text: _serializeResult(result))],
      );
    } catch (e, st) {
      if (_logErrors) {
        io.stderr.writeln('[easy_api] $name: \$e');
        io.stderr.writeln(st);
        await io.stderr.flush();
      }
      return CallToolResult(
        content: [TextContent(text: 'An error occurred while processing the request.')],
        isError: true,
      );
    }
  }''';
        })
        .join('\n');

    // dart:io is always needed for HTTP transport:
    // - io.Platform.environment['PORT'] for PORT env var support
    // - io.stderr for error logging when logErrors is true
    const ioImport = "import 'dart:io' as io;";

    final codeModeSpecRegistry = codeMode
        ? generateToolSpecRegistry(codeModeTools)
        : '';
    final codeModeHandlers = codeMode
        ? generateCodeModeHandlers(codeModeTools, codeModeTimeout)
        : '';
    final logErrorsConstant = '  static const bool _logErrors = $logErrors;';

    // Generate prompt support
    final hasPrompts = prompts.isNotEmpty;
    final promptAddCalls = hasPrompts
        ? prompts
              .map((p) {
                final name = p['name'] as String;
                return '    addPrompt(_prompt${name}Spec, _prompt${name}Impl);';
              })
              .join('\n')
        : '';
    final promptRegistrations = hasPrompts ? '\n$promptAddCalls' : '';
    final promptSpecs = hasPrompts ? generatePromptSpecs(prompts) : '';
    final promptHandlers = hasPrompts ? generatePromptHandlers(prompts) : '';

    // Generate CORS headers based on configuration
    final corsOriginHeader = corsOrigins.contains('*')
        ? "<String>['*']"
        : "<String>[${corsOrigins.map((o) => "'${escapeDartString(o)}'").join(', ')}]";

    return '''
// Generated MCP HTTP server
// DO NOT EDIT - automatically generated by mcp_generator

import 'dart:async';
import 'dart:convert';
$ioImport
${codeMode ? "import 'dart:math' as math;" : ''}

import 'package:dart_mcp/server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:stream_channel/stream_channel.dart';
${hasPrompts ? "import 'package:easy_api_annotations/easy_api_annotations.dart' as easy_api;" : ''}

$listInnerImportStatements
$sourceImportStatements

/// Allowed CORS origins for this server.
/// Configured via @Server annotation. Defaults to ['*'] for backward compatibility.
/// For production use, restrict to specific origins to prevent CSRF attacks.
const _corsOrigins = $corsOriginHeader;

Future<void> main() async {
  // Create stream controllers for bidirectional communication
  final clientToServer = StreamController<String>();
  final serverToClient = StreamController<String>.broadcast();

  // Create the StreamChannel that MCPServer expects
  final channel = StreamChannel<String>(
    clientToServer.stream,
    serverToClient.sink,
  );

  final server = MCPServerWithTools(channel);

  // FIFO of completers awaiting responses for in-flight POST requests.
  final responseQueue = <Completer<String>>[];
  // Active SSE subscribers (Streamable-HTTP GET streams).
  final sseSinks = <StreamController<List<int>>>{};

  serverToClient.stream.listen((response) {
    if (responseQueue.isNotEmpty) {
      responseQueue.removeAt(0).complete(response);
      return;
    }
    // Fan out unsolicited server→client messages to any open SSE streams.
    final bytes = utf8.encode('event: message\\ndata: \$response\\n\\n');
    for (final sink in sseSinks) {
      if (!sink.isClosed) sink.add(bytes);
    }
  });

  // Pre-compute the CORS origin header value
  final corsOriginValue = _corsOrigins.length == 1 ? _corsOrigins.first : _corsOrigins.join(', ');

  final corsHeaders = <String, String>{
    'Access-Control-Allow-Origin': corsOriginValue,
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Content-Type, Accept, Mcp-Session-Id, Authorization',
    'Access-Control-Expose-Headers': 'Mcp-Session-Id',
  };

  bool containsRequest(dynamic m) {
    if (m is List) return m.any(containsRequest);
    if (m is Map) return m.containsKey('id') && m.containsKey('method');
    return false;
  }

  Future<shelf.Response> handleRequest(shelf.Request request) async {
    final method = request.method;

    // CORS preflight.
    if (method == 'OPTIONS') {
      return shelf.Response(204, headers: corsHeaders);
    }

    // Streamable-HTTP server→client SSE stream.
    if (method == 'GET') {
      final controller = StreamController<List<int>>();
      sseSinks.add(controller);
      controller.add(utf8.encode(': ok\\n\\n'));
      final keepalive = Timer.periodic(const Duration(seconds: 15), (t) {
        if (controller.isClosed) {
          t.cancel();
        } else {
          controller.add(utf8.encode(': keepalive\\n\\n'));
        }
      });
      controller.onCancel = () {
        keepalive.cancel();
        sseSinks.remove(controller);
        controller.close();
      };
      return shelf.Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'X-Accel-Buffering': 'no',
          ...corsHeaders,
        },
      );
    }

    // Session termination.
    if (method == 'DELETE') {
      return shelf.Response.ok('', headers: corsHeaders);
    }

    if (method != 'POST') {
      return shelf.Response(
        405,
        body: 'Method not allowed',
        headers: corsHeaders,
      );
    }

    final body = await request.readAsString();

    dynamic parsed;
    try {
      parsed = jsonDecode(body);
    } catch (_) {
      return shelf.Response(
        400,
        body:
            '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"},"id":null}',
        headers: {'Content-Type': 'application/json', ...corsHeaders},
      );
    }

    // Notification / response-only batches: accept and acknowledge.
    if (!containsRequest(parsed)) {
      clientToServer.add(body);
      return shelf.Response(202, headers: corsHeaders);
    }

    final completer = Completer<String>();
    responseQueue.add(completer);
    clientToServer.add(body);

    final response = await completer.future;
    return shelf.Response.ok(
      response,
      headers: {'Content-Type': 'application/json', ...corsHeaders},
    );
  }

  // Use PORT env var (Cloud Run) or fall back to configured port
  final portEnv = io.Platform.environment['PORT'];
  final serverPort = portEnv != null 
      ? int.tryParse(portEnv) ?? $port 
      : $port;

  final httpServer = await shelf_io.serve(
    handleRequest,
    $addressExpression,
    serverPort,
  );

  print('MCP HTTP server listening on port \${httpServer.port}');

  // Wait for server to complete and then clean up
  await server.done;
  await httpServer.close();
  await clientToServer.close();
  await serverToClient.close();
  for (final sink in sseSinks) {
    await sink.close();
  }
}

base class MCPServerWithTools extends MCPServer with ToolsSupport${hasPrompts ? ', PromptsSupport' : ''} {
$logErrorsConstant

  MCPServerWithTools(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'mcp-server',
          version: '1.0.0',
        ),
        instructions: 'Auto-generated MCP server on port $port',
      ) {
$toolRegistrations$codeModeRegistrations$promptRegistrations
  }

  /// Guards against duplicate initialization requests (e.g. from MCP Inspector
  /// which may send `initialize` more than once for HTTP endpoints).
  bool _isInitialized = false;
  InitializeResult? _initializeResult;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    if (_isInitialized) return _initializeResult!;
    _isInitialized = true;
    final result = await super.initialize(request);
    _initializeResult = result;
    return result;
  }

$toolHandlers
$codeModeSpecRegistry
$codeModeHandlers
$promptSpecs
$promptHandlers

  String _serializeResult(dynamic result) {
    if (result == null) return 'null';
    try {
      if (result is Map) return jsonEncode(result);
      if (result is List) {
        final items = result.map((e) {
          if (e == null) return null;
          if (e is Map) return e;
          final toJson = e.toJson;
          if (toJson != null && toJson is Function) return toJson();
          return e.toString();
        }).where((e) => e != null).toList();
        return jsonEncode(items);
      }
      final toJson = result.toJson;
      if (toJson != null && toJson is Function) return jsonEncode(toJson());
      return result.toString();
    } catch (_) {
      return result.toString();
    }
  }
}
''';
  }
}
