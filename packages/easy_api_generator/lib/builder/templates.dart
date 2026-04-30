// Generated MCP server templates

import 'package:easy_api_generator/builder/schema_builder.dart';

// ---------------------------------------------------------------------------
// Code mode helpers (shared between StdioTemplate and HttpTemplate)
// ---------------------------------------------------------------------------

/// Filters tools to those enabled for code mode (codeMode != false).
List<Map<String, dynamic>> _filterCodeModeTools(
  List<Map<String, dynamic>> tools,
) {
  return tools.where((t) => t['codeMode'] != false).toList();
}

/// Filters tools to those that remain visible in the standard `tools/list`
/// response when the server has `@Server(codeMode: true)`.
///
/// Only tools that explicitly set `@Tool(codeModeVisible: true)` are kept.
/// When `@Server.codeMode` is false this helper is not used — all tools are
/// listed unconditionally.
List<Map<String, dynamic>> _filterCodeModeVisibleTools(
  List<Map<String, dynamic>> tools,
) {
  return tools.where((t) => t['codeModeVisible'] == true).toList();
}

/// Filters tools whose Dart handler (`_toolName`) needs to be generated when
/// the server has `@Server(codeMode: true)`.
///
/// A handler is needed if the tool is either listed in `tools/list`
/// (`codeModeVisible: true`) or callable from the sandbox dispatcher
/// (`codeMode` on `@Tool` is not false). Tools where both are false would
/// produce unreferenced handler methods, so we skip generating them.
List<Map<String, dynamic>> _filterHandlerToolsForCodeMode(
  List<Map<String, dynamic>> tools,
) {
  return tools
      .where((t) => t['codeModeVisible'] == true || t['codeMode'] != false)
      .toList();
}

/// Escapes a string for embedding in a Dart single-quoted string literal.
String _escapeDartString(String s) {
  return s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\$', '\\\$');
}

/// Converts a Dart type string to a JavaScript/JSON Schema type string.
String _jsType(String dartType) {
  final baseType = dartType.endsWith('?')
      ? dartType.substring(0, dartType.length - 1)
      : dartType;
  if (baseType.startsWith('List<')) return 'array';
  switch (baseType) {
    case 'int':
    case 'double':
    case 'num':
      return 'number';
    case 'String':
      return 'string';
    case 'bool':
      return 'boolean';
    default:
      return 'object';
  }
}

/// Generates the search and execute tool registrations for code mode.
String _generateCodeModeToolRegistrations() {
  return '''
    registerTool(
      Tool(
        name: 'search',
        description: 'Search for available tools by name or description. Returns matching tools with their parameter information. Use this to discover available tools before calling execute.',
        inputSchema: Schema.object(
          properties: {
            'query': Schema.string(
              description: 'Search terms. Space-separated terms are AND-matched against tool names and descriptions (case-insensitive).',
            ),
            'detail_level': UntitledSingleSelectEnumSchema(
              description: 'Level of detail: "brief" (name + description), "detailed" (+ parameter names/types/required), "full" (+ complete parameter schemas).',
              values: ['brief', 'detailed', 'full'],
            ),
          },
          required: ['query'],
        ),
      ),
      _search,
    );
    registerTool(
      Tool(
        name: 'execute',
        description: 'Execute JavaScript code with access to MCP tool functions. Use call_tool(name, params) to call any tool by name, or use external_<toolName>(args) convenience wrappers. Use the search tool first to discover available tools and their signatures. All calls are async - use await for sequential calls and Promise.all() for parallel calls. Return a value to include it in the result.',
        inputSchema: Schema.object(
          properties: {
            'code': Schema.string(
              description: 'JavaScript code to execute.',
            ),
          },
          required: ['code'],
        ),
      ),
      _execute,
    );''';
}

/// Generates the static const _codeModeToolSpecs declaration.
String _generateToolSpecRegistry(List<Map<String, dynamic>> codeModeTools) {
  final entries = codeModeTools
      .map((t) {
        final name = t['name'] as String;
        final desc = _escapeDartString(
          t['description'] as String? ?? 'Tool $name',
        );
        final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
        final paramEntries = params
            .map((p) {
              final paramName = p['name'] as String;
              final paramType = _jsType(p['type'] as String);
              final required = p['isOptional'] != true;
              return "<String, dynamic>{'name': '$paramName', 'type': '$paramType', 'required': $required}";
            })
            .join(', ');
        return "<String, dynamic>{'name': '$name', 'description': '$desc', 'parameters': <Map<String, dynamic>>[$paramEntries]}";
      })
      .join(', ');
  return '  static const _codeModeToolSpecs = <Map<String, dynamic>>[$entries];';
}

/// Generates the _search handler method.
String _generateSearchHandler() {
  return r'''
  FutureOr<CallToolResult> _search(CallToolRequest request) async {
    try {
      final query = (request.arguments?['query'] as String?) ?? '';
      final detailLevel = (request.arguments?['detail_level'] as String?) ?? 'brief';

      final terms = query.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();

      if (terms.isEmpty) {
        final results = _codeModeToolSpecs.map((tool) =>
            _formatSearchResult(tool, detailLevel)).toList();
        return CallToolResult(
          content: [TextContent(text: jsonEncode(results))],
        );
      }

      // Phase 1: strict AND match — all terms must appear in name or description
      final andMatches = _codeModeToolSpecs.where((tool) {
        final name = (tool['name'] as String).toLowerCase();
        final desc = (tool['description'] as String).toLowerCase();
        return terms.every((term) => name.contains(term) || desc.contains(term));
      }).toList();

      List<Map<String, dynamic>> matches;
      if (andMatches.isNotEmpty) {
        matches = andMatches;
      } else {
        // Phase 2: ranked OR match — score each tool by how many terms it matches
        final scored = _codeModeToolSpecs.map((tool) {
          final name = (tool['name'] as String).toLowerCase();
          final desc = (tool['description'] as String).toLowerCase();
          int score = 0;
          for (final term in terms) {
            if (name.contains(term) || desc.contains(term)) score++;
          }
          return MapEntry(tool, score);
        }).where((e) => e.value > 0).toList();

        scored.sort((a, b) => b.value.compareTo(a.value));
        matches = scored.map((e) => e.key).toList();
      }

      final results = matches.map((tool) =>
          _formatSearchResult(tool, detailLevel)).toList();

      return CallToolResult(
        content: [TextContent(text: jsonEncode(results))],
      );
    } catch (e, st) {
      if (_logErrors) {
        io.stderr.writeln('[easy_api] _search: $e');
        io.stderr.writeln(st);
        await io.stderr.flush();
      }
      return CallToolResult(
        content: [TextContent(text: 'An error occurred while processing the request.')],
        isError: true,
      );
    }
  }

  Map<String, dynamic> _formatSearchResult(
    Map<String, dynamic> tool,
    String detailLevel,
  ) {
    final name = tool['name'] as String;
    final desc = tool['description'] as String;
    final params = tool['parameters'] as List<Map<String, dynamic>>;

    if (detailLevel == 'brief') {
      return {'name': name, 'description': desc};
    } else if (detailLevel == 'detailed') {
      final paramInfo = params.map((p) => {
        'name': p['name'],
        'type': p['type'],
        'required': p['required'],
      }).toList();
      return {'name': name, 'description': desc, 'parameters': paramInfo};
    } else {
      final paramInfo = params.map((p) {
        final map = <String, dynamic>{
          'name': p['name'],
          'type': p['type'],
          'required': p['required'],
        };
        return map;
      }).toList();
      return {'name': name, 'description': desc, 'parameters': paramInfo};
    }
  }
  // ignore: prefer_adjacent_string_concatenation
  '''; // raw string — _logErrors referenced as-is in generated code
}

/// Generates the _execute handler method.
String _generateExecuteHandler(int codeModeTimeout) {
  return '''
  FutureOr<CallToolResult> _execute(CallToolRequest request) async {
    try {
      final code = request.arguments!['code'] as String;
      final result = await _runCodeSandbox(code, $codeModeTimeout);
      return CallToolResult(
        content: [TextContent(text: result ?? 'null')],
      );
    } catch (e, st) {
      if (_logErrors) {
        io.stderr.writeln('[easy_api] _execute: \$e');
        io.stderr.writeln(st);
        await io.stderr.flush();
      }
      return CallToolResult(
        content: [TextContent(text: 'An error occurred while processing the request.')],
        isError: true,
      );
    }
  }''';
}

/// Generates the _runCodeSandbox method.
String _generateRunCodeSandbox() {
  return '''
  Future<String?> _runCodeSandbox(String userCode, int timeoutSeconds) async {
    io.Process? process;
    io.Directory? tempDir;
    try {
      final wrapper = _buildJsWrapper(userCode);
      tempDir = await io.Directory.systemTemp.createTemp('mcp_code_mode_');
      final scriptFile = io.File('\${tempDir.path}/sandbox.js');
      await scriptFile.writeAsString(wrapper);

      process = await io.Process.start(
        'node',
        ['--max-old-space-size=64', scriptFile.path],
      );
    } catch (e) {
      await tempDir?.delete(recursive: true);
      throw StateError('Code mode requires Node.js to be installed');
    }

    try {
      final resultCompleter = Completer<String?>();
      final errorCompleter = Completer<String>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isEmpty) return;

        try {
          final msg = jsonDecode(line) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'call') {
            final callId = msg['callId'] as String;
            final toolName = msg['tool'] as String;
            final args = (msg['args'] as Map<String, dynamic>?) ?? <String, dynamic>{};

            _dispatchCodeModeToolCall(toolName, args).then((resultJson) {
              process?.stdin.writeln(jsonEncode({
                'type': 'result',
                'callId': callId,
                'data': resultJson,
              }));
            }).catchError((e, st) {
              if (_logErrors) {
                io.stderr.writeln('[easy_api] _dispatchCodeModeToolCall(\$toolName): \$e');
                io.stderr.writeln(st);
                io.stderr.flush();  // fire-and-forget; callback is not async
              }
              process?.stdin.writeln(jsonEncode({
                'type': 'result',
                'callId': callId,
                'data': null,
                'error': 'An error occurred while processing the request.',
              }));
            });
          } else if (type == 'done') {
            final result = msg['result'];
            if (result == null) {
              resultCompleter.complete(null);
            } else if (result is String) {
              resultCompleter.complete(result);
            } else {
              resultCompleter.complete(jsonEncode(result));
            }
          } else if (type == 'error') {
            errorCompleter.complete(msg['message'] as String? ?? 'Unknown error');
          }
        } catch (_) {
          // Ignore non-JSON lines
        }
      });

      // Wait for result, error, or timeout
      final timeoutFuture = Future.delayed(
        Duration(seconds: timeoutSeconds),
        () => throw StateError('Code execution timed out after \$timeoutSeconds seconds'),
      );

      final result = await Future.any<String?>([
        resultCompleter.future,
        errorCompleter.future.then((e) => throw StateError('Code execution error: \$e')),
        timeoutFuture,
      ]);

      return result;
    } finally {
      process.kill(io.ProcessSignal.sigkill);
      await tempDir.delete(recursive: true);
    }
  }''';
}

/// Generates the _buildJsWrapper method that constructs the JS sandbox script.
String _generateBuildJsWrapper(List<Map<String, dynamic>> codeModeTools) {
  final externalFunctions = codeModeTools
      .map((t) {
        final name = t['name'] as String;
        return '    sb.writeln("async function external_$name(args) { return call_tool(\'$name\', args); }");';
      })
      .join('\n');

  return '''
  String _buildJsWrapper(String userCode) {
    final sb = StringBuffer();
    sb.writeln('// Code Mode Sandbox - IPC Layer');
    sb.writeln('const __pending = {};');
    sb.writeln('let __callId = 0;');
    sb.writeln("let __buffer = '';");
    sb.writeln();
    sb.writeln("process.stdin.on('data', (chunk) => {");
    sb.writeln('  __buffer += chunk.toString();');
    sb.writeln("  const lines = __buffer.split('\\\\n');");
    sb.writeln('  __buffer = lines.pop();');
    sb.writeln('  for (const line of lines) {');
    sb.writeln("    if (!line.trim()) continue;");
    sb.writeln('    try {');
    sb.writeln('      const msg = JSON.parse(line);');
    sb.writeln("      if (msg.type === 'result' && __pending[msg.callId]) {");
    sb.writeln('        const { resolve, reject } = __pending[msg.callId];');
    sb.writeln('        if (msg.error) { reject(new Error(msg.error)); }');
    sb.writeln('        else { resolve(msg.data); }');
    sb.writeln('        delete __pending[msg.callId];');
    sb.writeln('      }');
    sb.writeln('    } catch (e) {}');
    sb.writeln('  }');
    sb.writeln('});');
    sb.writeln();
    sb.writeln('function __send(msg) {');
    sb.writeln("  process.stdout.write(JSON.stringify(msg) + '\\\\n');");
    sb.writeln('}');
    sb.writeln();
    sb.writeln('async function __externalCall(tool, args) {');
    sb.writeln('  const callId = String(++__callId);');
    sb.writeln('  return new Promise((resolve, reject) => {');
    sb.writeln('    __pending[callId] = { resolve, reject };');
    sb.writeln("    __send({ type: 'call', callId, tool, args: args || {} });");
    sb.writeln('  });');
    sb.writeln('}');
    sb.writeln();
    sb.writeln('// Generic tool invocation function');
    sb.writeln('async function call_tool(name, params) {');
    sb.writeln('  return __externalCall(name, params || {});');
    sb.writeln('}');
    sb.writeln();
    sb.writeln('// External Tool Functions (convenience wrappers)');
$externalFunctions
    sb.writeln();
    sb.writeln('// Execute user code');
    sb.writeln('(async () => {');
    sb.writeln('  try {');
    sb.writeln('    const __result = await (async () => {');
    // Auto-return expression-like code (IIFE or bare await) so the LLM
    // doesn't need to remember an explicit return for single-expression snippets.
    final trimmedCode = userCode.trim();
    final isExpressionLike = trimmedCode.startsWith('(') || trimmedCode.startsWith('await ');
    final alreadyHasReturn = trimmedCode.startsWith('return ');
    final codeToRun = (isExpressionLike && !alreadyHasReturn) ? 'return ' + userCode : userCode;
    sb.writeln(codeToRun);
    sb.writeln('    })();');
    sb.writeln("    __send({ type: 'done', result: __result });");
    sb.writeln('  } catch (e) {');
    sb.writeln("    __send({ type: 'error', message: e.message || String(e) });");
    sb.writeln('  }');
    sb.writeln('})();');
    return sb.toString();
  }''';
}

/// Generates the _dispatchCodeModeToolCall method.
String _generateDispatchCases(List<Map<String, dynamic>> codeModeTools) {
  final cases = codeModeTools
      .map((t) {
        final name = t['name'] as String;
        return "      case '$name': result = await _$name(request); break;";
      })
      .join('\n');

  return '''
  dynamic _dispatchCodeModeToolCall(String toolName, Map<String, dynamic> args) async {
    final request = CallToolRequest(name: toolName, arguments: args);
    CallToolResult result;
    switch (toolName) {
      case 'search': result = await _search(request); break;
$cases
      default:
        throw StateError('Unknown tool: \$toolName');
    }

    final textContent = result.content.whereType<TextContent>().firstOrNull;
    if (textContent != null) {
      final text = textContent.text;
      try {
        return jsonDecode(text);
      } catch (_) {
        return text;
      }
    }
    return result.content.map((c) => c.toString()).join('\\n');
  }''';
}

/// Generates all code mode handler methods combined.
String _generateCodeModeHandlers(
  List<Map<String, dynamic>> codeModeTools,
  int codeModeTimeout,
) {
  return [
    _generateSearchHandler(),
    _generateExecuteHandler(codeModeTimeout),
    _generateRunCodeSandbox(),
    _generateBuildJsWrapper(codeModeTools),
    _generateDispatchCases(codeModeTools),
  ].join('\n');
}

// ---------------------------------------------------------------------------
// StdioTemplate
// ---------------------------------------------------------------------------

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
  }) {
    // Collect unique imports for custom List inner types
    final listInnerImports = _collectListInnerImports(tools);
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
    final sourceImportStatements = sourceImports.entries
        .map((e) => "import '${e.key}' as ${e.value};")
        .join('\n');

    // Filter code mode tools
    final codeModeTools = codeMode
        ? _filterCodeModeTools(tools)
        : <Map<String, dynamic>>[];

    // When code mode is enabled, only tools explicitly marked visible
    // (`@Tool(codeModeVisible: true)`) remain in the standard `tools/list`
    // response. The `search` and `execute` tools are always registered.
    final listedTools = codeMode ? _filterCodeModeVisibleTools(tools) : tools;

    // When code mode is enabled, only generate handlers for tools that are
    // referenced somewhere (tools/list or sandbox dispatch).
    final handlerTools = codeMode
        ? _filterHandlerToolsForCodeMode(tools)
        : tools;

    final toolRegistrations = listedTools
        .map((t) {
          final name = t['name'] as String;
          final schema = SchemaBuilder.buildObjectSchema(
            (t['parameters'] as List<Map<String, dynamic>>? ?? []),
          );
          return '''
    registerTool(
      Tool(
        name: '$name',
        description: '${t['description'] ?? 'Tool $name'}',
        inputSchema: $schema,
      ),
      _$name,
    );''';
        })
        .join('\n');

    final codeModeRegistrations = codeMode
        ? _generateCodeModeToolRegistrations()
        : '';

    final toolHandlers = handlerTools
        .map((t) {
          final name = t['name'] as String;
          final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
          final paramExtractions = params
              .map((p) {
                final paramName = p['name'] as String;
                final paramType = p['type'] as String;
                final isOptional = p['isOptional'] == true;
                final dartType = _dartType(paramType);
                // Use alias as external name when present
                final externalName =
                    (p['parameterMetadata']?['alias'] as String?) ?? paramName;
                if (isOptional) {
                  final nullableType = dartType.endsWith('?')
                      ? dartType
                      : '$dartType?';
                  return "    final $paramName = request.arguments?['$externalName'] as $nullableType;";
                }
                return "    final $paramName = request.arguments!['$externalName'] as $dartType;";
              })
              .join('\n');

          // Generate conversion code for List parameters with custom inner types
          final paramConversions = params
              .where((p) => _needsListConversion(p['type'] as String))
              .map((p) {
                final paramName = p['name'] as String;
                final paramType = p['type'] as String;
                final innerType = _extractListInnerType(paramType);
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
                ? 'await $sourceAlias.$className.$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$className.$methodName(${_callArgsWithConversion(params)})';
          } else if (className != null) {
            call = isAsync
                ? 'await $sourceAlias.$className().$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$className().$methodName(${_callArgsWithConversion(params)})';
          } else {
            call = isAsync
                ? 'await $sourceAlias.$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$methodName(${_callArgsWithConversion(params)})';
          }

          return '''
  FutureOr<CallToolResult> _$name(CallToolRequest request) async {
    try {
$paramExtractions
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
        ? _generateToolSpecRegistry(codeModeTools)
        : '';
    final codeModeHandlers = codeMode
        ? _generateCodeModeHandlers(codeModeTools, codeModeTimeout)
        : '';
    final logErrorsConstant = '  static const bool _logErrors = $logErrors;';

    return '''
// Generated MCP stdio server
// DO NOT EDIT - automatically generated by mcp_generator

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

$listInnerImportStatements
$sourceImportStatements

Future<void> main() async {
  final server = MCPServerWithTools(
    stdioChannel(input: io.stdin, output: io.stdout),
  );
  await server.done;
}

base class MCPServerWithTools extends MCPServer with ToolsSupport {
$logErrorsConstant

  MCPServerWithTools(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'mcp-server',
          version: '1.0.0',
        ),
        instructions: 'Auto-generated MCP server',
      ) {
$toolRegistrations$codeModeRegistrations
  }

$toolHandlers
$codeModeSpecRegistry
$codeModeHandlers

  String _serializeResult(dynamic result) {
    if (result == null) return 'null';
    try {
      if (result is List) {
        final items = result.map((e) {
          if (e == null) return null;
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

  /// Generates call arguments, using converted variable names for List parameters with custom inner types.
  static String _callArgsWithConversion(List<Map<String, dynamic>> params) {
    return params
        .map((p) {
          final name = p['name'] as String;
          final isNamed = p['isNamed'] == true;
          final paramType = p['type'] as String;
          final argName = _needsListConversion(paramType)
              ? '${name}Converted'
              : name;
          return isNamed ? '$name: $argName' : argName;
        })
        .join(', ');
  }

  /// Collects unique import URIs for custom List inner types from all tools.
  static Set<String> _collectListInnerImports(
    List<Map<String, dynamic>> tools,
  ) {
    final imports = <String>{};
    for (final tool in tools) {
      final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
      for (final param in params) {
        final importUri = param['listInnerTypeImport'] as String?;
        if (importUri != null) {
          imports.add(importUri);
        }
      }
    }
    return imports;
  }

  static String _dartType(String type) {
    // Strip nullable suffix for matching
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    final isNullable = type.endsWith('?');
    final suffix = isNullable ? '?' : '';

    if (baseType.startsWith('List<')) {
      final inner = baseType.substring(5, baseType.length - 1);
      if (!const [
        'String',
        'int',
        'double',
        'bool',
        'num',
        'dynamic',
      ].contains(inner)) {
        return 'List<dynamic>$suffix';
      }
      return '$baseType$suffix';
    }
    switch (baseType) {
      case 'String':
      case 'int':
      case 'double':
      case 'bool':
        return '$baseType$suffix';
      default:
        return 'dynamic';
    }
  }

  /// Checks if a type is a List with a non-primitive inner type that needs conversion.
  static bool _needsListConversion(String type) {
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    if (!baseType.startsWith('List<')) return false;
    final inner = baseType.substring(5, baseType.length - 1);
    return !const [
      'String',
      'int',
      'double',
      'bool',
      'num',
      'dynamic',
    ].contains(inner);
  }

  /// Extracts the inner type from a `List<T>` type string.
  static String _extractListInnerType(String type) {
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    return baseType.substring(5, baseType.length - 1);
  }
}

// ---------------------------------------------------------------------------
// HttpTemplate
// ---------------------------------------------------------------------------

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
  ///
  /// Returns the complete server code as a Dart string.
  static String generate(
    List<Map<String, dynamic>> tools,
    int port,
    String address, {
    bool codeMode = false,
    int codeModeTimeout = 30,
    bool logErrors = false,
  }) {
    // Collect unique imports for custom List inner types
    final listInnerImports = _collectListInnerImports(tools);
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
    final sourceImportStatements = sourceImports.entries
        .map((e) => "import '${e.key}' as ${e.value};")
        .join('\n');

    // Filter code mode tools
    final codeModeTools = codeMode
        ? _filterCodeModeTools(tools)
        : <Map<String, dynamic>>[];

    // When code mode is enabled, only tools explicitly marked visible
    // (`@Tool(codeModeVisible: true)`) remain in the standard `tools/list`
    // response. The `search` and `execute` tools are always registered.
    final listedTools = codeMode ? _filterCodeModeVisibleTools(tools) : tools;

    // When code mode is enabled, only generate handlers for tools that are
    // referenced somewhere (tools/list or sandbox dispatch).
    final handlerTools = codeMode
        ? _filterHandlerToolsForCodeMode(tools)
        : tools;

    final toolRegistrations = listedTools
        .map((t) {
          final name = t['name'] as String;
          final schema = SchemaBuilder.buildObjectSchema(
            (t['parameters'] as List<Map<String, dynamic>>? ?? []),
          );
          return '''
    registerTool(
      Tool(
        name: '$name',
        description: '${t['description'] ?? 'Tool $name'}',
        inputSchema: $schema,
      ),
      _$name,
    );''';
        })
        .join('\n');

    final codeModeRegistrations = codeMode
        ? _generateCodeModeToolRegistrations()
        : '';

    final toolHandlers = handlerTools
        .map((t) {
          final name = t['name'] as String;
          final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
          final paramExtractions = params
              .map((p) {
                final paramName = p['name'] as String;
                final paramType = p['type'] as String;
                final isOptional = p['isOptional'] == true;
                final dartType = _dartType(paramType);
                // Use alias as external name when present
                final externalName =
                    (p['parameterMetadata']?['alias'] as String?) ?? paramName;
                if (isOptional) {
                  final nullableType = dartType.endsWith('?')
                      ? dartType
                      : '$dartType?';
                  return "    final $paramName = request.arguments?['$externalName'] as $nullableType;";
                }
                return "    final $paramName = request.arguments!['$externalName'] as $dartType;";
              })
              .join('\n');

          // Generate conversion code for List parameters with custom inner types
          final paramConversions = params
              .where((p) => _needsListConversion(p['type'] as String))
              .map((p) {
                final paramName = p['name'] as String;
                final paramType = p['type'] as String;
                final innerType = _extractListInnerType(paramType);
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
                ? 'await $sourceAlias.$className.$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$className.$methodName(${_callArgsWithConversion(params)})';
          } else if (className != null) {
            call = isAsync
                ? 'await $sourceAlias.$className().$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$className().$methodName(${_callArgsWithConversion(params)})';
          } else {
            call = isAsync
                ? 'await $sourceAlias.$methodName(${_callArgsWithConversion(params)})'
                : '$sourceAlias.$methodName(${_callArgsWithConversion(params)})';
          }

          return '''
  FutureOr<CallToolResult> _$name(CallToolRequest request) async {
    try {
$paramExtractions
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

    // dart:io is needed for default address (InternetAddress) or code mode
    final ioImport = (address == '127.0.0.1' || codeMode)
        ? "import 'dart:io' as io;"
        : '';

    final codeModeSpecRegistry = codeMode
        ? _generateToolSpecRegistry(codeModeTools)
        : '';
    final codeModeHandlers = codeMode
        ? _generateCodeModeHandlers(codeModeTools, codeModeTimeout)
        : '';
    final logErrorsConstant = '  static const bool _logErrors = $logErrors;';

    return '''
// Generated MCP HTTP server
// DO NOT EDIT - automatically generated by mcp_generator

import 'dart:async';
import 'dart:convert';
$ioImport

import 'package:dart_mcp/server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:stream_channel/stream_channel.dart';

$listInnerImportStatements
$sourceImportStatements

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

  const corsHeaders = <String, String>{
    'Access-Control-Allow-Origin': '*',
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

  final httpServer = await shelf_io.serve(
    handleRequest,
    $addressExpression,
    $port,
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

base class MCPServerWithTools extends MCPServer with ToolsSupport {
$logErrorsConstant

  MCPServerWithTools(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(
          name: 'mcp-server',
          version: '1.0.0',
        ),
        instructions: 'Auto-generated MCP server on port $port',
      ) {
$toolRegistrations$codeModeRegistrations
  }

$toolHandlers
$codeModeSpecRegistry
$codeModeHandlers

  String _serializeResult(dynamic result) {
    if (result == null) return 'null';
    try {
      if (result is List) {
        final items = result.map((e) {
          if (e == null) return null;
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

  /// Generates call arguments, using converted variable names for List parameters with custom inner types.
  static String _callArgsWithConversion(List<Map<String, dynamic>> params) {
    return params
        .map((p) {
          final name = p['name'] as String;
          final isNamed = p['isNamed'] == true;
          final paramType = p['type'] as String;
          final argName = _needsListConversion(paramType)
              ? '${name}Converted'
              : name;
          return isNamed ? '$name: $argName' : argName;
        })
        .join(', ');
  }

  /// Collects unique import URIs for custom List inner types from all tools.
  static Set<String> _collectListInnerImports(
    List<Map<String, dynamic>> tools,
  ) {
    final imports = <String>{};
    for (final tool in tools) {
      final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
      for (final param in params) {
        final importUri = param['listInnerTypeImport'] as String?;
        if (importUri != null) {
          imports.add(importUri);
        }
      }
    }
    return imports;
  }

  static String _dartType(String type) {
    // Strip nullable suffix for matching
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    final isNullable = type.endsWith('?');
    final suffix = isNullable ? '?' : '';

    if (baseType.startsWith('List<')) {
      final inner = baseType.substring(5, baseType.length - 1);
      if (!const [
        'String',
        'int',
        'double',
        'bool',
        'num',
        'dynamic',
      ].contains(inner)) {
        return 'List<dynamic>$suffix';
      }
      return '$baseType$suffix';
    }
    switch (baseType) {
      case 'String':
      case 'int':
      case 'double':
      case 'bool':
        return '$baseType$suffix';
      default:
        return 'dynamic';
    }
  }

  /// Checks if a type is a List with a non-primitive inner type that needs conversion.
  static bool _needsListConversion(String type) {
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    if (!baseType.startsWith('List<')) return false;
    final inner = baseType.substring(5, baseType.length - 1);
    return !const [
      'String',
      'int',
      'double',
      'bool',
      'num',
      'dynamic',
    ].contains(inner);
  }

  /// Extracts the inner type from a `List<T>` type string.
  static String _extractListInnerType(String type) {
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;
    return baseType.substring(5, baseType.length - 1);
  }
}
