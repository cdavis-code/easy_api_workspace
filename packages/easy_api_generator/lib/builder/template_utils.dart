// Shared template utilities used across multiple generator template files.

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum allowed length for code mode scripts to prevent abuse.
const maxCodeModeLength = 10000;

/// Maximum allowed length for search queries to prevent DoS.
const maxSearchQueryLength = 500;

/// Maximum allowed length for prompt arguments to prevent abuse.
const maxPromptArgumentLength = 10000;

/// Set of Dart primitive type names.
const primitives = {'String', 'int', 'double', 'num', 'bool'};

// ---------------------------------------------------------------------------
// String Escaping
// ---------------------------------------------------------------------------

/// Escapes a string for embedding in a Dart single-quoted string literal.
String escapeDartString(String s) {
  return s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t')
      .replaceAll('\$', '\\\$');
}

// ---------------------------------------------------------------------------
// Name Utilities
// ---------------------------------------------------------------------------

/// Converts a camelCase, PascalCase, or snake_case identifier to kebab-case.
///
/// Consecutive uppercase characters are kept together (e.g. `HTTPServer` →
/// `http-server`). Underscores are treated as word boundaries.
String kebabCase(String input) {
  if (input.isEmpty) return input;
  final result = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (ch == '_') {
      result.write('-');
      i++;
      continue;
    }
    if (_isUpper(ch)) {
      // Gather consecutive uppercase characters
      var end = i + 1;
      while (end < input.length && _isUpper(input[end]) && input[end] != '_') {
        end++;
      }
      // If the uppercase run is followed by a lowercase letter, the last
      // uppercase belongs to the next word.
      if (end > i + 1) {
        result.write(input.substring(i, end - 1).toLowerCase());
        result.write('-');
        i = end - 1;
      } else {
        if (i > 0 && !_isUpper(input[i - 1]) && input[i - 1] != '_') {
          result.write('-');
        }
        result.write(ch.toLowerCase());
        i++;
      }
    } else {
      result.write(ch);
      i++;
    }
  }
  return result.toString();
}

bool _isUpper(String ch) => ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90;

/// Capitalizes the first letter of a string.
String pascalCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Type Utilities
// ---------------------------------------------------------------------------

/// Strips a nullable `?` suffix from a type string.
String baseType(String type) {
  return type.endsWith('?') ? type.substring(0, type.length - 1) : type;
}

/// Returns true if the base type (nullable-stripped) is a primitive.
bool isPrimitive(String type) => primitives.contains(baseType(type));

/// Returns true if the type is `List<primitive>` or `List<primitive>?`.
bool isPrimitiveList(String type) {
  final base = baseType(type);
  if (!base.startsWith('List<')) return false;
  final inner = base.substring(5, base.length - 1);
  return primitives.contains(inner);
}

/// Returns true if the type is `List<non-primitive,non-dynamic>` or nullable variant.
bool isCustomList(String type) {
  final base = baseType(type);
  if (!base.startsWith('List<')) return false;
  final inner = base.substring(5, base.length - 1);
  return !primitives.contains(inner) && inner != 'dynamic';
}

/// Extracts the inner type from a `List<T>` or `List<T>?` type string.
///
/// Caller must verify the type is a List variant before calling.
String extractListInnerType(String type) {
  final base = baseType(type);
  return base.substring(5, base.length - 1);
}

/// Normalizes a parameter type string to a Dart type for MCP parameter extraction.
///
/// Non-primitive `List<T>` becomes `List<dynamic>`; unknown types become `dynamic`.
/// Nullable suffix is preserved.
String dartType(String type) {
  final nullable = type.endsWith('?');
  final suffix = nullable ? '?' : '';
  final bt = baseType(type);

  if (bt.startsWith('List<')) {
    final inner = bt.substring(5, bt.length - 1);
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
    return '$bt$suffix';
  }
  switch (bt) {
    case 'String':
    case 'int':
    case 'double':
    case 'bool':
      return '$bt$suffix';
    default:
      return 'dynamic';
  }
}

/// Checks if a type is a `List<T>` where T is not a primitive.
bool needsListConversion(String type) {
  final bt = baseType(type);
  if (!bt.startsWith('List<')) return false;
  final inner = bt.substring(5, bt.length - 1);
  return !const [
    'String',
    'int',
    'double',
    'bool',
    'num',
    'dynamic',
  ].contains(inner);
}

/// Generates call arguments for a tool invocation, using `Converted` suffix for
/// List parameters with custom inner types.
String callArgsWithConversion(List<Map<String, dynamic>> params) {
  return params
      .map((p) {
        final name = p['name'] as String;
        final isNamed = p['isNamed'] == true;
        final paramType = p['type'] as String;
        final argName = needsListConversion(paramType)
            ? '${name}Converted'
            : name;
        return isNamed ? '$name: $argName' : argName;
      })
      .join(', ');
}

/// Collects unique import URIs for custom List inner types from all tools.
Set<String> collectListInnerImports(List<Map<String, dynamic>> tools) {
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

/// Converts a Dart type string to a JavaScript/JSON Schema type string.
String jsType(String dartType) {
  final bt = baseType(dartType);
  if (bt.startsWith('List<')) return 'array';
  switch (bt) {
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

// ---------------------------------------------------------------------------
// Code Mode Filters
// ---------------------------------------------------------------------------

/// Filters tools to those enabled for code mode (codeMode != false).
List<Map<String, dynamic>> filterCodeModeTools(
  List<Map<String, dynamic>> tools,
) {
  return tools.where((t) => t['codeMode'] != false).toList();
}

/// Filters tools to those that remain visible in the standard `tools/list`
/// response when the server has `@Server(codeMode: true)`.
List<Map<String, dynamic>> filterCodeModeVisibleTools(
  List<Map<String, dynamic>> tools,
) {
  return tools.where((t) => t['codeModeVisible'] == true).toList();
}

/// Filters tools whose Dart handler needs to be generated when code mode is
/// enabled. A handler is needed if the tool is either visible in tools/list
/// or callable from the sandbox dispatcher.
List<Map<String, dynamic>> filterHandlerToolsForCodeMode(
  List<Map<String, dynamic>> tools,
) {
  return tools
      .where((t) => t['codeModeVisible'] == true || t['codeMode'] != false)
      .toList();
}

// ---------------------------------------------------------------------------
// Code Mode Generators
// ---------------------------------------------------------------------------

/// Generates the search and execute tool registrations for code mode.
String generateCodeModeToolRegistrations() {
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
String generateToolSpecRegistry(List<Map<String, dynamic>> codeModeTools) {
  final entries = codeModeTools
      .map((t) {
        final name = t['name'] as String;
        final desc = escapeDartString(
          t['description'] as String? ?? 'Tool $name',
        );
        final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
        final paramEntries = params
            .map((p) {
              final paramName = p['name'] as String;
              final paramType = jsType(p['type'] as String);
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
String generateSearchHandler() {
  return '''
  FutureOr<CallToolResult> _search(CallToolRequest request) async {
    try {
      final query = (request.arguments?['query'] as String?) ?? '';
      final detailLevel = (request.arguments?['detail_level'] as String?) ?? 'brief';

      // Validate query length
      if (query.length > $maxSearchQueryLength) {
        return CallToolResult(
          content: [TextContent(text: 'Search query exceeds maximum length of $maxSearchQueryLength characters.')],
          isError: true,
        );
      }

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
        io.stderr.writeln('[easy_api] _search: \$e');
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
  ''';
}

/// Generates the _execute handler method.
String generateExecuteHandler(int codeModeTimeout) {
  return '''
  FutureOr<CallToolResult> _execute(CallToolRequest request) async {
    try {
      final code = request.arguments!['code'] as String;
      
      // Validate code length to prevent abuse
      if (code.length > $maxCodeModeLength) {
        return CallToolResult(
          content: [TextContent(text: 'Code exceeds maximum length of $maxCodeModeLength characters.')],
          isError: true,
        );
      }
      
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
String generateRunCodeSandbox() {
  return '''
  Future<String?> _runCodeSandbox(String userCode, int timeoutSeconds) async {
    io.Process? process;
    io.Directory? tempDir;
    try {
      final wrapper = _buildJsWrapper(userCode);
      
      // Security: Use unpredictable directory name with timestamp + random suffix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = math.Random.secure();
      final suffix = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
      tempDir = await io.Directory.systemTemp.createTemp('mcp_sandbox_\${timestamp}_\${suffix}_');
      final scriptFile = io.File('\${tempDir.path}/sandbox.js');
            
      // Set restrictive permissions (owner read/write only)
      if (io.Platform.isLinux || io.Platform.isMacOS) {
        await scriptFile.create(recursive: true);
        await io.Process.run('chmod', ['700', tempDir.path]);
        await io.Process.run('chmod', ['600', scriptFile.path]);
      }
            
      await scriptFile.writeAsString(wrapper);

      process = await io.Process.start(
        'node',
        [
          '--max-old-space-size=64',
          '--no-addons',
          '--frozen-intrinsics',
          scriptFile.path,
        ],
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
      // Graceful shutdown: process is guaranteed to be non-null here
      // (otherwise process.stdout would have thrown earlier)
      final proc = process;
      final dir = tempDir;
      try {
        // First, check if process already exited naturally
        await proc.exitCode.timeout(
          const Duration(milliseconds: 100),
        );
      } catch (_) {
        // Process still running, begin graceful shutdown
        proc.kill(io.ProcessSignal.sigterm);
        try {
          // Wait up to 2 seconds for graceful shutdown
          await proc.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              // Process didn't exit, force kill
              proc.kill(io.ProcessSignal.sigkill);
              return -1;
            },
          );
        } catch (_) {
          // Error during exit code wait - attempt force kill as fallback
          proc.kill(io.ProcessSignal.sigkill);
        }
      }
      await dir.delete(recursive: true);
    }
  }''';
}

/// Generates the _buildJsWrapper method that constructs the JS sandbox script.
String generateBuildJsWrapper(List<Map<String, dynamic>> codeModeTools) {
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
String generateDispatchCases(List<Map<String, dynamic>> codeModeTools) {
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
String generateCodeModeHandlers(
  List<Map<String, dynamic>> codeModeTools,
  int codeModeTimeout,
) {
  return [
    generateSearchHandler(),
    generateExecuteHandler(codeModeTimeout),
    generateRunCodeSandbox(),
    generateBuildJsWrapper(codeModeTools),
    generateDispatchCases(codeModeTools),
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Parameter Helpers
// ---------------------------------------------------------------------------

/// Generates the ToolAnnotations expression for a tool, or empty string if none.
String generateAnnotationsExpression(Map<String, dynamic> tool) {
  final annotations = tool['annotations'] as Map<String, dynamic>?;
  if (annotations == null || annotations.isEmpty) return '';

  final parts = <String>[];
  if (annotations.containsKey('title')) {
    parts.add("title: '${escapeDartString(annotations['title'] as String)}'");
  }
  if (annotations.containsKey('readOnlyHint')) {
    parts.add('readOnlyHint: ${annotations['readOnlyHint']}');
  }
  if (annotations.containsKey('destructiveHint')) {
    parts.add('destructiveHint: ${annotations['destructiveHint']}');
  }
  if (annotations.containsKey('idempotentHint')) {
    parts.add('idempotentHint: ${annotations['idempotentHint']}');
  }
  if (annotations.containsKey('openWorldHint')) {
    parts.add('openWorldHint: ${annotations['openWorldHint']}');
  }

  if (parts.isEmpty) return '';
  return '\n        annotations: ToolAnnotations(${parts.join(', ')}),';
}

/// Renders a single MCP parameter extraction line for either transport.
///
/// Honors the original Dart-type nullability captured by the builder
/// (`isNullable`) and any default-value source code (`defaultValueCode`)
/// so optional non-nullable parameters with defaults compile under AOT.
String renderMcpParamExtraction(Map<String, dynamic> p, String dartType) {
  final paramName = p['name'] as String;
  final isOptional = p['isOptional'] == true;
  final defaultCode = p['defaultValueCode'] as String?;
  final externalName =
      (p['parameterMetadata']?['alias'] as String?) ?? paramName;

  if (!isOptional) {
    return "    final $paramName = request.arguments!['$externalName'] as $dartType;";
  }

  final nullableCast = dartType.endsWith('?') ? dartType : '$dartType?';

  if (defaultCode != null) {
    return "    final $paramName = (request.arguments?['$externalName'] as $nullableCast) ?? $defaultCode;";
  }

  return "    final $paramName = request.arguments?['$externalName'] as $nullableCast;";
}

/// Generates validation code for a parameter if it has validation constraints.
String renderParamValidation(Map<String, dynamic> p) {
  final paramName = p['name'] as String;
  final isOptional = p['isOptional'] == true;
  final metadata = p['parameterMetadata'] as Map<String, dynamic>?;

  if (metadata == null) return '';

  final validations = <String>[];

  if (metadata.containsKey('maxLength')) {
    final maxLength = metadata['maxLength'] as int;
    if (isOptional) {
      validations.add(
        '    if ($paramName != null && $paramName.length > $maxLength) {\n'
        '      return CallToolResult(\n'
        "        content: [TextContent(text: 'Parameter $paramName exceeds maximum length of $maxLength characters.')],\n"
        '        isError: true,\n'
        '      );\n'
        '    }',
      );
    } else {
      validations.add(
        '    if ($paramName.length > $maxLength) {\n'
        '      return CallToolResult(\n'
        "        content: [TextContent(text: 'Parameter $paramName exceeds maximum length of $maxLength characters.')],\n"
        '        isError: true,\n'
        '      );\n'
        '    }',
      );
    }
  }

  if (metadata.containsKey('pattern')) {
    final pattern = metadata['pattern'] as String;
    if (isOptional) {
      validations.add(
        '    if ($paramName != null && !RegExp(r\'$pattern\').hasMatch($paramName)) {\n'
        '      return CallToolResult(\n'
        "        content: [TextContent(text: 'Parameter $paramName does not match required pattern.')],\n"
        '        isError: true,\n'
        '      );\n'
        '    }',
      );
    } else {
      validations.add(
        '    if (!RegExp(r\'$pattern\').hasMatch($paramName)) {\n'
        '      return CallToolResult(\n'
        "        content: [TextContent(text: 'Parameter $paramName does not match required pattern.')],\n"
        '        isError: true,\n'
        '      );\n'
        '    }',
      );
    }
  }

  return validations.isEmpty ? '' : validations.join('\n');
}

// ---------------------------------------------------------------------------
// Prompt Helpers
// ---------------------------------------------------------------------------

/// Generates prompt spec constants for each prompt.
String generatePromptSpecs(List<Map<String, dynamic>> prompts) {
  final specs = prompts
      .map((p) {
        final name = p['name'] as String;
        final title = p['title'] as String?;
        final description = p['description'] as String;
        final arguments = p['arguments'] as List<Map<String, dynamic>>;

        final argsList = arguments
            .map((arg) {
              final argName = arg['name'] as String;
              final argTitle = arg['title'] as String?;
              final argDesc = arg['description'] as String?;
              final argRequired = arg['required'] as bool;

              var argStr =
                  'PromptArgument(name: \'$argName\', required: $argRequired)';
              if (argTitle != null || argDesc != null) {
                final titlePart = argTitle != null
                    ? 'title: \'${escapeDartString(argTitle)}\''
                    : '';
                final descPart = argDesc != null
                    ? 'description: \'${escapeDartString(argDesc)}\''
                    : '';
                argStr =
                    'PromptArgument(name: \'$argName\', $titlePart, $descPart, required: $argRequired)';
              }
              return argStr;
            })
            .join(',\n          ');

        var promptStr =
            'static final _prompt${name}Spec = Prompt(name: \'$name\', description: \'${escapeDartString(description)}\'';
        if (title != null) {
          promptStr =
              'static final _prompt${name}Spec = Prompt(name: \'$name\', title: \'${escapeDartString(title)}\', description: \'${escapeDartString(description)}\'';
        }
        if (arguments.isNotEmpty) {
          promptStr +=
              ',\n        arguments: [\n          $argsList,\n        ]';
        }
        promptStr += ');';
        return promptStr;
      })
      .join('\n\n');

  return specs;
}

/// Generates prompt handler methods for prompts/list and prompts/get.
String generatePromptHandlers(List<Map<String, dynamic>> prompts) {
  final promptImpls = prompts
      .map((p) {
        final name = p['name'] as String;
        final methodName = p['methodName'] as String;
        final className = p['className'] as String?;
        final isStatic = p['isStatic'] as bool? ?? false;
        final isAsync = p['isAsync'] as bool;
        final sourceAlias = p['sourceAlias'] as String? ?? 'lib';
        final arguments = p['arguments'] as List<Map<String, dynamic>>;

        final argExtractions = arguments
            .map((arg) {
              final argName = arg['name'] as String;
              final dartName = arg['dartName'] as String;
              return """    final $dartName = request.arguments?['$argName'] as String?;
    if ($dartName != null && $dartName.length > $maxPromptArgumentLength) {
      throw ArgumentError('Argument $argName exceeds maximum length of $maxPromptArgumentLength characters');
    }""";
            })
            .join('\n');

        final argCalls = arguments
            .map((arg) {
              final dartName = arg['dartName'] as String;
              final isNamed = arg['isNamed'] as bool;
              return isNamed ? '$dartName: $dartName ?? \'\'' : dartName;
            })
            .join(', ');

        String call;
        if (className != null && isStatic) {
          call = isAsync
              ? 'await $sourceAlias.$className.$methodName($argCalls)'
              : '$sourceAlias.$className.$methodName($argCalls)';
        } else if (className != null) {
          call = isAsync
              ? 'await $sourceAlias.$className().$methodName($argCalls)'
              : '$sourceAlias.$className().$methodName($argCalls)';
        } else {
          call = isAsync
              ? 'await $sourceAlias.$methodName($argCalls)'
              : '$sourceAlias.$methodName($argCalls)';
        }

        return """  FutureOr<GetPromptResult> _prompt${name}Impl(GetPromptRequest request) async {
    try {
    $argExtractions
    final promptResult = $call;
    return GetPromptResult(
      description: promptResult.description,
      messages: promptResult.messages.map(_promptMessageToMcp).toList(),
    );
    } catch (e, st) {
      if (_logErrors) {
        io.stderr.writeln('[easy_api] prompt $name: \$e');
        io.stderr.writeln(st);
        await io.stderr.flush();
      }
      return GetPromptResult(
        description: 'An error occurred while processing the prompt.',
        messages: [],
      );
    }
  }""";
      })
      .join('\n\n');

  return '''
$promptImpls

  PromptMessage _promptMessageToMcp(easy_api.PromptMessage message) {
    final content = message.content;
    return switch (content) {
      easy_api.TextPromptContent() => PromptMessage(
          role: message.role == easy_api.PromptRole.user ? Role.user : Role.assistant,
          content: TextContent(text: content.text),
        ),
      easy_api.ImagePromptContent() => PromptMessage(
          role: message.role == easy_api.PromptRole.user ? Role.user : Role.assistant,
          content: ImageContent(data: content.data, mimeType: content.mimeType),
        ),
      easy_api.AudioPromptContent() => PromptMessage(
          role: message.role == easy_api.PromptRole.user ? Role.user : Role.assistant,
          content: AudioContent(data: content.data, mimeType: content.mimeType),
        ),
      easy_api.ResourcePromptContent() => PromptMessage(
          role: message.role == easy_api.PromptRole.user ? Role.user : Role.assistant,
          content: EmbeddedResource(
            resource: TextResourceContents(
              uri: content.uri,
              mimeType: content.mimeType,
              text: content.text,
            ),
          ),
        ),
    };
  }''';
}
