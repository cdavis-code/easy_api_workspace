// Stdio MCP server template generator.

import 'package:easy_api_generator/builder/template_utils.dart';
import 'package:easy_api_generator/builder/schema_builder.dart';

/// Generates stdio server code from tool definitions using dart_mcp.
///
/// This template creates a complete stdio MCP server that:
/// - Uses JSON-RPC over standard input/output
/// - Suitable for CLI-based MCP clients
/// - Registers all tools with their JSON schemas
/// - Handles tool execution with proper error handling
///
/// The stdio transport is the default and recommended for local CLI tools
/// that communicate via stdin/stdout streams.
class StdioTemplate {
  /// Generates the stdio server Dart code.
  ///
  /// [tools] - List of tool definitions with parameters and metadata
  /// [codeMode] - Enable code mode with JavaScript sandbox (default: false)
  /// [codeModeTimeout] - Timeout for code mode execution in seconds (default: 30)
  /// [logErrors] - Log internal errors to stderr for troubleshooting (default: false)
  ///
  /// Returns the complete server code as a Dart string.
  static String generate(
    List<Map<String, dynamic>> tools, {
    bool codeMode = false,
    int codeModeTimeout = 30,
    bool logErrors = false,
    List<Map<String, dynamic>> prompts = const [],
  }) {
    // Collect unique imports for custom List inner types
    final listInnerImports = collectListInnerImports(tools);
    final listInnerImportStatements = listInnerImports
        .map((uri) => "import '$uri';")
        .join('\n');

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

    // When code mode is enabled, only tools explicitly marked visible
    // (`@Tool(codeModeVisible: true)`) remain in the standard `tools/list`
    // response. The `search` and `execute` tools are always registered.
    final listedTools = codeMode ? filterCodeModeVisibleTools(tools) : tools;

    // When code mode is enabled, only generate handlers for tools that are
    // referenced somewhere (tools/list or sandbox dispatch).
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

          // Generate validation code for parameters
          final paramValidations = params
              .map((p) => renderParamValidation(p))
              .where((v) => v.isNotEmpty)
              .join('\n');

          // Generate conversion code for List parameters with custom inner types
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

    return '''
// Generated MCP stdio server
// DO NOT EDIT - automatically generated by mcp_generator

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
${codeMode ? "import 'dart:math' as math;" : ''}

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
${hasPrompts ? "import 'package:easy_api_annotations/easy_api_annotations.dart' as easy_api;" : ''}

$listInnerImportStatements
$sourceImportStatements

Future<void> main() async {
  final server = MCPServerWithTools(
    stdioChannel(input: io.stdin, output: io.stdout),
  );
  await server.done;
}

base class MCPServerWithTools extends MCPServer with ToolsSupport${hasPrompts ? ', PromptsSupport' : ''} {
$logErrorsConstant

  MCPServerWithTools(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'mcp-server',
          version: '1.0.0',
        ),
        instructions: 'Auto-generated MCP server',
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
