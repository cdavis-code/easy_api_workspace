import 'package:easy_api_generator/builder/templates.dart';
import 'package:easy_api_generator/builder/openapi_dart_template.dart';
import 'package:test/test.dart';

void main() {
  group('StdioTemplate', () {
    late List<Map<String, dynamic>> tools;

    setUp(() {
      tools = [
        <String, dynamic>{
          'name': 'getUser',
          'description': 'Get user by ID',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'id',
              'type': 'int',
              'schema': "{'type': 'integer'}",
              'schemaMap': {'type': 'integer'},
              'isOptional': false,
            },
          ],
          'isAsync': true,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
        },
        <String, dynamic>{
          'name': 'createUser',
          'description': 'Create a new user',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'name',
              'type': 'String',
              'schema': "{'type': 'string'}",
              'schemaMap': {'type': 'string'},
              'isOptional': false,
            },
            <String, dynamic>{
              'name': 'email',
              'type': 'String',
              'schema': "{'type': 'string'}",
              'schemaMap': {'type': 'string'},
              'isOptional': false,
            },
          ],
          'isAsync': true,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
        },
      ];
    });

    test('generates valid Dart code', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains("import 'package:dart_mcp/server.dart';"));
      expect(result, contains("import 'package:dart_mcp/stdio.dart';"));
      expect(
        result,
        contains("import 'package:example/user_store.dart' as user_store;"),
      );
    });

    test('includes MCPServer with ToolsSupport', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('extends MCPServer with ToolsSupport'));
    });

    test('includes all tool names in registerTool', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains("name: 'getUser'"));
      expect(result, contains("name: 'createUser'"));
    });

    test('includes tool descriptions', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('Get user by ID'));
      expect(result, contains('Create a new user'));
    });

    test('uses Schema.* builders', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('Schema.int()'));
      expect(result, contains('Schema.string()'));
      expect(result, contains('Schema.object('));
    });

    test('generates handler methods with CallToolResult', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('CallToolResult'));
      expect(result, contains('TextContent'));
    });

    test('uses await for async tools', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('await user_store.getUser'));
      expect(result, contains('await user_store.createUser'));
    });

    test('does not use await for sync tools', () {
      final syncTools = [
        <String, dynamic>{
          'name': 'searchUsers',
          'description': 'Search users',
          'parameters': <Map<String, dynamic>>[],
          'isAsync': false,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
        },
      ];
      final result = StdioTemplate.generate(syncTools);
      expect(result, contains('user_store.searchUsers'));
      expect(result, isNot(contains('await user_store.searchUsers')));
    });

    test('handles empty tools list', () {
      final result = StdioTemplate.generate([]);
      expect(result, contains('MCPServerWithTools'));
      expect(result, contains('extends MCPServer with ToolsSupport'));
    });

    test('uses stdioChannel', () {
      final result = StdioTemplate.generate(tools);
      expect(result, contains('stdioChannel'));
    });

    group('code mode disabled', () {
      test(
        'does not include search or execute tools when codeMode is false',
        () {
          final result = StdioTemplate.generate(tools, codeMode: false);
          expect(result, isNot(contains("name: 'search'")));
          expect(result, isNot(contains("name: 'execute'")));
          expect(result, isNot(contains('_search')));
          expect(result, isNot(contains('_execute')));
          expect(result, isNot(contains('_codeModeToolSpecs')));
          expect(result, isNot(contains('_runCodeSandbox')));
        },
      );
    });

    group('code mode enabled', () {
      test('registers search and execute tools', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
      });

      test('registers search handler', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('_search'));
      });

      test('registers execute handler', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('_execute'));
      });

      test('execute tool has static description without tool names', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        // The execute description should mention call_tool but not individual tool names
        expect(result, contains('call_tool(name, params)'));
        expect(result, contains('Use the search tool first'));
        // Should NOT contain individual tool names in the execute description
        // (the description is static regardless of how many tools exist)
        expect(result, contains('external_<toolName>'));
      });

      test('search tool has query and detail_level parameters', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains("'query'"));
        expect(result, contains("'detail_level'"));
        expect(result, contains('UntitledSingleSelectEnumSchema'));
        expect(result, contains("'brief'"));
        expect(result, contains("'detailed'"));
        expect(result, contains("'full'"));
      });

      test('generates tool spec registry', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('_codeModeToolSpecs'));
        // Both tools are code-mode-enabled by default
        expect(result, contains("'name': 'getUser'"));
        expect(result, contains("'name': 'createUser'"));
      });

      test('includes call_tool in JS wrapper', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('async function call_tool(name, params)'));
      });

      test('includes external_* convenience functions in JS wrapper', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('async function external_getUser'));
        expect(result, contains('async function external_createUser'));
      });

      test('external_* functions delegate to call_tool', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        // The JS wrapper is escaped for embedding in a Dart string literal,
        // so single quotes become \'. Check for the escaped form.
        expect(result, contains('call_tool'));
        expect(result, contains('external_getUser'));
        expect(result, contains('external_createUser'));
        // Verify delegation pattern exists (escaped single quotes around tool names)
        expect(result, contains('getUser'));
        expect(result, contains('createUser'));
      });

      test('generates _runCodeSandbox', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('_runCodeSandbox'));
        expect(result, contains('io.Process.start'));
        expect(result, contains('io.Directory.systemTemp'));
      });

      test('generates dispatch cases for code mode tools', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains("case 'getUser': result = await _getUser"));
        expect(
          result,
          contains("case 'createUser': result = await _createUser"),
        );
      });

      test('generates _search handler with AND-matching', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains('terms.every'));
      });

      test('includes dart:io import when code mode is enabled', () {
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains("import 'dart:io' as io;"));
      });

      test('excludes tool with codeMode: false from spec registry', () {
        final toolsWithExclusion = [
          ...tools,
          <String, dynamic>{
            'name': 'deleteUser',
            'description': 'Delete a user',
            'parameters': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'id',
                'type': 'int',
                'schema': "{'type': 'integer'}",
                'schemaMap': {'type': 'integer'},
                'isOptional': false,
              },
            ],
            'isAsync': true,
            'sourceImport': 'package:example/user_store.dart',
            'sourceAlias': 'user_store',
            'codeMode': false,
            // Mark visible so it still appears in tools/list in code mode.
            'codeModeVisible': true,
          },
        ];
        final result = StdioTemplate.generate(
          toolsWithExclusion,
          codeMode: true,
        );
        // Tool spec registry should NOT include the excluded tool
        // but should include the others
        expect(result, contains("'name': 'getUser'"));
        expect(result, contains("'name': 'createUser'"));
        // The deleteUser should still be registered as a regular tool
        // because it opted back in via codeModeVisible: true.
        expect(result, contains("name: 'deleteUser'"));
        // But no external_deleteUser in the JS wrapper
        expect(result, isNot(contains('external_deleteUser')));
        // And no dispatch case for deleteUser in code mode
        expect(
          result,
          isNot(contains("case 'deleteUser': result = await _deleteUser")),
        );
      });

      test('hides standard tools from tools/list by default when code mode '
          'is enabled', () {
        // Default: no tool sets codeModeVisible, so only search/execute
        // remain in the tools/list registrations.
        final result = StdioTemplate.generate(tools, codeMode: true);
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
        // Standard tools should NOT be registered in tools/list.
        expect(result, isNot(contains("name: 'getUser'")));
        expect(result, isNot(contains("name: 'createUser'")));
      });

      test('registers tools with codeModeVisible: true in tools/list', () {
        final toolsWithVisible = [
          <String, dynamic>{...tools[0], 'codeModeVisible': true},
          tools[1],
        ];
        final result = StdioTemplate.generate(toolsWithVisible, codeMode: true);
        // getUser opted in, so it is listed.
        expect(result, contains("name: 'getUser'"));
        // createUser did not opt in, so it is hidden.
        expect(result, isNot(contains("name: 'createUser'")));
        // search/execute always visible in code mode.
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
      });

      test('lists all tools in tools/list when @Server codeMode is false '
          'regardless of codeModeVisible', () {
        final mixed = [
          <String, dynamic>{...tools[0], 'codeModeVisible': false},
          <String, dynamic>{...tools[1], 'codeModeVisible': true},
        ];
        final result = StdioTemplate.generate(mixed, codeMode: false);
        expect(result, contains("name: 'getUser'"));
        expect(result, contains("name: 'createUser'"));
      });

      test('respects codeModeTimeout parameter', () {
        final result = StdioTemplate.generate(
          tools,
          codeMode: true,
          codeModeTimeout: 60,
        );
        expect(result, contains('60'));
      });

      test('generates _logErrors constant and conditional logging', () {
        final result = StdioTemplate.generate(
          tools,
          codeMode: true,
          logErrors: true,
        );
        expect(result, contains('static const bool _logErrors = true;'));
        expect(result, contains('if (_logErrors)'));
        expect(result, contains("io.stderr.writeln('[easy_api]"));
      });

      test('does not generate logging when logErrors is false', () {
        final result = StdioTemplate.generate(
          tools,
          codeMode: true,
          logErrors: false,
        );
        expect(result, contains('static const bool _logErrors = false;'));
        // The if (_logErrors) guard is still generated but the compiler
        // will optimize it away since _logErrors is const false.
        expect(result, contains('if (_logErrors)'));
      });
    });
  });

  group('Parameter nullability and defaults', () {
    Map<String, dynamic> toolWithParam(Map<String, dynamic> param) =>
        <String, dynamic>{
          'name': 'doThing',
          'description': 'Test tool',
          'parameters': <Map<String, dynamic>>[param],
          'isAsync': true,
          'sourceImport': 'package:example/store.dart',
          'sourceAlias': 'store',
        };

    test('required non-nullable parameter casts without ?', () {
      final result = StdioTemplate.generate([
        toolWithParam(<String, dynamic>{
          'name': 'name',
          'type': 'String',
          'schemaMap': {'type': 'string'},
          'isOptional': false,
          'isNullable': false,
          'defaultValueCode': null,
        }),
      ]);
      expect(
        result,
        contains("final name = request.arguments!['name'] as String;"),
      );
      expect(
        result,
        isNot(contains("final name = request.arguments!['name'] as String?;")),
      );
    });

    test('required nullable parameter preserves trailing ?', () {
      final result = StdioTemplate.generate([
        toolWithParam(<String, dynamic>{
          'name': 'name',
          'type': 'String?',
          'schemaMap': {'type': 'string'},
          'isOptional': false,
          'isNullable': true,
          'defaultValueCode': null,
        }),
      ]);
      expect(
        result,
        contains("final name = request.arguments!['name'] as String?;"),
      );
    });

    test('optional nullable parameter without default uses nullable cast', () {
      final result = StdioTemplate.generate([
        toolWithParam(<String, dynamic>{
          'name': 'name',
          'type': 'String?',
          'schemaMap': {'type': 'string'},
          'isOptional': true,
          'isNullable': true,
          'defaultValueCode': null,
        }),
      ]);
      expect(
        result,
        contains("final name = request.arguments?['name'] as String?;"),
      );
    });

    test(
      'optional non-nullable String parameter with default emits ?? fallback',
      () {
        final result = StdioTemplate.generate([
          toolWithParam(<String, dynamic>{
            'name': 'greeting',
            'type': 'String',
            'schemaMap': {'type': 'string'},
            'isOptional': true,
            'isNullable': false,
            'defaultValueCode': "'hi'",
          }),
        ]);
        expect(
          result,
          contains(
            "final greeting = (request.arguments?['greeting'] as String?) ?? 'hi';",
          ),
        );
      },
    );

    test(
      'optional non-nullable int parameter with default emits ?? fallback',
      () {
        final result = StdioTemplate.generate([
          toolWithParam(<String, dynamic>{
            'name': 'count',
            'type': 'int',
            'schemaMap': {'type': 'integer'},
            'isOptional': true,
            'isNullable': false,
            'defaultValueCode': '0',
          }),
        ]);
        expect(
          result,
          contains("final count = (request.arguments?['count'] as int?) ?? 0;"),
        );
      },
    );

    test('alias is honored for required non-nullable parameter', () {
      final result = StdioTemplate.generate([
        toolWithParam(<String, dynamic>{
          'name': 'query',
          'type': 'String',
          'schemaMap': {'type': 'string'},
          'isOptional': false,
          'isNullable': false,
          'defaultValueCode': null,
          'parameterMetadata': <String, dynamic>{'alias': 'q'},
        }),
      ]);
      expect(
        result,
        contains("final query = request.arguments!['q'] as String;"),
      );
    });

    test('HttpTemplate applies the same nullability/default rules', () {
      final result = HttpTemplate.generate(
        [
          toolWithParam(<String, dynamic>{
            'name': 'greeting',
            'type': 'String',
            'schemaMap': {'type': 'string'},
            'isOptional': true,
            'isNullable': false,
            'defaultValueCode': "'hi'",
          }),
        ],
        3000,
        '127.0.0.1',
      );
      expect(
        result,
        contains(
          "final greeting = (request.arguments?['greeting'] as String?) ?? 'hi';",
        ),
      );
    });
  });

  group('Tool description escaping', () {
    Map<String, dynamic> toolWithDescription(String description) =>
        <String, dynamic>{
          'name': 'doThing',
          'description': description,
          'parameters': <Map<String, dynamic>>[],
          'isAsync': true,
          'sourceImport': 'package:example/store.dart',
          'sourceAlias': 'store',
        };

    test('StdioTemplate escapes single quotes in description', () {
      final result = StdioTemplate.generate(<Map<String, dynamic>>[
        toolWithDescription("It's a tool"),
      ]);
      // Must produce a valid Dart single-quoted literal — the apostrophe
      // has to be backslash-escaped, never bare.
      expect(result, contains(r"description: 'It\'s a tool'"));
      expect(result, isNot(contains("description: 'It's a tool'")));
    });

    test('StdioTemplate escapes dollar signs in description', () {
      final result = StdioTemplate.generate(<Map<String, dynamic>>[
        toolWithDescription(r'Costs $5'),
      ]);
      // `$` would otherwise trigger Dart string interpolation in the
      // generated source; the escape helper must neutralize it.
      expect(result, contains(r"description: 'Costs \$5'"));
    });

    test('StdioTemplate escapes backslashes in description', () {
      final result = StdioTemplate.generate(<Map<String, dynamic>>[
        toolWithDescription(r'C:\path\to\thing'),
      ]);
      expect(result, contains(r"description: 'C:\\path\\to\\thing'"));
    });

    test('HttpTemplate escapes single quotes in description', () {
      final result = HttpTemplate.generate(
        <Map<String, dynamic>>[toolWithDescription("It's a tool")],
        3000,
        '127.0.0.1',
      );
      expect(result, contains(r"description: 'It\'s a tool'"));
    });
  });

  group('HttpTemplate', () {
    late List<Map<String, dynamic>> tools;

    setUp(() {
      tools = [
        <String, dynamic>{
          'name': 'getUser',
          'description': 'Get user by ID',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'id',
              'type': 'int',
              'schema': "{'type': 'integer'}",
              'schemaMap': {'type': 'integer'},
              'isOptional': false,
            },
          ],
          'isAsync': true,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
        },
      ];
    });

    test('generates valid Dart code', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains("import 'package:dart_mcp/server.dart';"));
      expect(result, contains("import 'package:shelf/shelf.dart' as shelf;"));
      expect(
        result,
        contains("import 'package:example/user_store.dart' as user_store;"),
      );
    });

    test('includes correct port in instructions', () {
      final result = HttpTemplate.generate(tools, 8080, '127.0.0.1');
      expect(result, contains('port 8080'));
    });

    test('includes correct address in server configuration', () {
      final result = HttpTemplate.generate(tools, 3000, '0.0.0.0');
      expect(result, contains("'0.0.0.0'"));
    });

    test('uses io.InternetAddress.loopbackIPv4 for default address', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains('io.InternetAddress.loopbackIPv4'));
    });

    test('includes dart:io import for default address', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains("import 'dart:io' as io;"));
    });

    test('excludes dart:io import for custom address', () {
      final result = HttpTemplate.generate(tools, 3000, '0.0.0.0');
      expect(result, isNot(contains("import 'dart:io' as io;")));
    });

    test('includes MCPServer with ToolsSupport', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains('extends MCPServer with ToolsSupport'));
    });

    test('generates dispatch cases', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains('_getUser'));
      expect(result, contains('await user_store.getUser'));
    });

    test('uses Schema.* builders', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains('Schema.int()'));
      expect(result, contains('Schema.object('));
    });

    test('generates handler methods with CallToolResult', () {
      final result = HttpTemplate.generate(tools, 3000, '127.0.0.1');
      expect(result, contains('CallToolResult'));
      expect(result, contains('TextContent'));
    });

    group('code mode disabled', () {
      test(
        'does not include search or execute tools when codeMode is false',
        () {
          final result = HttpTemplate.generate(
            tools,
            3000,
            '127.0.0.1',
            codeMode: false,
          );
          expect(result, isNot(contains("name: 'search'")));
          expect(result, isNot(contains("name: 'execute'")));
          expect(result, isNot(contains('_search')));
          expect(result, isNot(contains('_execute')));
          expect(result, isNot(contains('_codeModeToolSpecs')));
        },
      );
    });

    group('code mode enabled', () {
      test('registers search and execute tools', () {
        final result = HttpTemplate.generate(
          tools,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
      });

      test('generates tool spec registry and handlers', () {
        final result = HttpTemplate.generate(
          tools,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, contains('_codeModeToolSpecs'));
        expect(result, contains('_search'));
        expect(result, contains('_execute'));
      });

      test('includes call_tool and external_* in JS wrapper', () {
        final result = HttpTemplate.generate(
          tools,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, contains('async function call_tool(name, params)'));
        expect(result, contains('async function external_getUser'));
      });

      test('includes dart:io import when code mode is enabled', () {
        // Even with custom address, code mode forces dart:io import
        final result = HttpTemplate.generate(
          tools,
          3000,
          '0.0.0.0',
          codeMode: true,
        );
        expect(result, contains("import 'dart:io' as io;"));
      });

      test('excludes tool with codeMode: false from spec registry', () {
        final toolsWithExclusion = [
          ...tools,
          <String, dynamic>{
            'name': 'deleteUser',
            'description': 'Delete a user',
            'parameters': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'id',
                'type': 'int',
                'schema': "{'type': 'integer'}",
                'schemaMap': {'type': 'integer'},
                'isOptional': false,
              },
            ],
            'isAsync': true,
            'sourceImport': 'package:example/user_store.dart',
            'sourceAlias': 'user_store',
            'codeMode': false,
          },
        ];
        final result = HttpTemplate.generate(
          toolsWithExclusion,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, isNot(contains('external_deleteUser')));
        expect(
          result,
          isNot(contains("case 'deleteUser': result = await _deleteUser")),
        );
      });

      test('hides standard tools from tools/list by default when code mode '
          'is enabled', () {
        final result = HttpTemplate.generate(
          tools,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
        expect(result, isNot(contains("name: 'getUser'")));
      });

      test('registers tools with codeModeVisible: true in tools/list', () {
        final toolsWithVisible = [
          <String, dynamic>{...tools[0], 'codeModeVisible': true},
        ];
        final result = HttpTemplate.generate(
          toolsWithVisible,
          3000,
          '127.0.0.1',
          codeMode: true,
        );
        expect(result, contains("name: 'getUser'"));
        expect(result, contains("name: 'search'"));
        expect(result, contains("name: 'execute'"));
      });

      test('generates _logErrors constant and conditional logging', () {
        final result = HttpTemplate.generate(
          tools,
          3000,
          '127.0.0.1',
          codeMode: true,
          logErrors: true,
        );
        expect(result, contains('static const bool _logErrors = true;'));
        expect(result, contains('if (_logErrors)'));
        expect(result, contains("io.stderr.writeln('[easy_api]"));
      });
    });
  });

  group('OpenApiDartTemplate', () {
    late List<Map<String, dynamic>> tools;
    late Map<String, dynamic> openApiSpec;

    setUp(() {
      tools = <Map<String, dynamic>>[
        {
          'name': 'createUser',
          'methodName': 'createUser',
          'description': 'Create a user',
          'parameters': <Map<String, dynamic>>[
            {'name': 'name', 'type': 'String', 'isOptional': false},
          ],
          'isAsync': true,
          'sourceImport': 'package:example/src/user_store.dart',
          'sourceAlias': 'lib',
          'className': 'UserStore',
          'isStatic': false,
        },
      ];
      openApiSpec = <String, dynamic>{
        'openapi': '3.0.3',
        'paths': <String, dynamic>{
          '/users': <String, dynamic>{
            'post': <String, dynamic>{
              'operationId': 'createUser',
              'x-tool-name': 'createUser',
              'requestBody': <String, dynamic>{
                'content': <String, dynamic>{
                  'application/json': <String, dynamic>{
                    'schema': <String, dynamic>{
                      'type': 'object',
                      'properties': <String, dynamic>{
                        'name': <String, dynamic>{'type': 'string'},
                      },
                    },
                  },
                },
              },
            },
          },
        },
      };
    });

    test(
      'emits _logErrors const and conditional stderr logging when logErrors is true',
      () {
        final result = OpenApiDartTemplate.generate(
          tools,
          8080,
          '127.0.0.1',
          openApiSpec,
          logErrors: true,
        );
        expect(result, contains('const bool _logErrors = true;'));
        expect(result, contains("import 'dart:io' as io;"));
        expect(result, contains('if (_logErrors)'));
        expect(result, contains("io.stderr.writeln('[easy_api]"));
        // 500 body must stay generic regardless of logErrors.
        expect(
          result,
          contains("'error': 'An error occurred while processing the request'"),
        );
      },
    );

    test('defaults logErrors to false and keeps generic 500 body', () {
      final result = OpenApiDartTemplate.generate(
        tools,
        8080,
        '127.0.0.1',
        openApiSpec,
      );
      expect(result, contains('const bool _logErrors = false;'));
      expect(
        result,
        contains("'error': 'An error occurred while processing the request'"),
      );
    });
  });

  group('Security Features', () {
    group('Node.js Sandbox Hardening', () {
      test('generates sandbox with security flags', () {
        final result = StdioTemplate.generate(
          [],
          codeMode: true,
          codeModeTimeout: 30,
        );

        // Verify security flags are present
        expect(result, contains('--no-addons'));
        expect(result, contains('--frozen-intrinsics'));
        expect(result, contains('--max-old-space-size=64'));
      });
    });

    group('Input Validation', () {
      test('prompt handlers include length validation', () {
        final prompts = [
          <String, dynamic>{
            'name': 'codeReview',
            'methodName': 'codeReview',
            'title': 'Code Review',
            'description': 'Review code',
            'arguments': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'code',
                'dartName': 'code',
                'type': 'String',
                'isNullable': false,
                'isOptional': false,
                'isNamed': true,
                'required': true,
              },
            ],
            'isAsync': false,
            'className': 'ExamplePrompts',
            'isStatic': false,
            'sourceAlias': 'example_prompts',
          },
        ];

        final result = StdioTemplate.generate([], prompts: prompts);

        // Verify length validation is present
        expect(result, contains('.length > 10000'));
        expect(result, contains('exceeds maximum length of 10000 characters'));
        // Verify try-catch block
        expect(result, contains('try {'));
        expect(result, contains('catch (e, st)'));
        expect(
          result,
          contains('An error occurred while processing the prompt.'),
        );
      });

      test('code mode execute handler validates code length', () {
        final result = StdioTemplate.generate(
          [],
          codeMode: true,
          codeModeTimeout: 30,
        );

        // Verify code length validation
        expect(result, contains('.length > 10000'));
        expect(result, contains('Code exceeds maximum length'));
      });

      test('search handler validates query length', () {
        final result = StdioTemplate.generate(
          [],
          codeMode: true,
          codeModeTimeout: 30,
        );

        // Verify query length validation - constant gets interpolated to 500
        expect(result, contains('query.length > 500'));
        expect(
          result,
          contains('Search query exceeds maximum length of 500 characters'),
        );
      });
    });

    group('CORS Configuration', () {
      test('generates default CORS origins as wildcard', () {
        final result = HttpTemplate.generate([], 3000, '127.0.0.1');

        expect(result, contains("const _corsOrigins = <'*'>;"));
        expect(result, contains('Access-Control-Allow-Origin'));
      });

      test('generates custom CORS origins when provided', () {
        final result = HttpTemplate.generate(
          [],
          3000,
          '127.0.0.1',
          corsOrigins: [
            'https://myapp.example.com',
            'https://admin.example.com',
          ],
        );

        expect(
          result,
          contains(
            "const _corsOrigins = <'https://myapp.example.com', 'https://admin.example.com'>;",
          ),
        );
      });
    });

    group('PORT Environment Variable', () {
      test('uses int.tryParse for safe PORT parsing', () {
        final result = HttpTemplate.generate([], 3000, '127.0.0.1');

        // Verify safe parsing with fallback
        expect(result, contains('int.tryParse(portEnv)'));
        expect(result, contains('?? 3000'));
      });
    });

    group('Process Shutdown', () {
      test('uses graceful shutdown with SIGTERM before SIGKILL', () {
        final result = StdioTemplate.generate(
          [],
          codeMode: true,
          codeModeTimeout: 30,
        );

        // Verify graceful shutdown sequence
        expect(result, contains('io.ProcessSignal.sigterm'));
        expect(result, contains('io.ProcessSignal.sigkill'));
        expect(result, contains('Duration(seconds: 2)'));
      });
    });

    group('Temporary File Security', () {
      test('sets restrictive file permissions on Unix systems', () {
        final result = StdioTemplate.generate(
          [],
          codeMode: true,
          codeModeTimeout: 30,
        );

        // Verify permission setting commands
        expect(result, contains("chmod', ['700'"));
        expect(result, contains("chmod', ['600'"));
        expect(result, contains('io.Platform.isLinux'));
        expect(result, contains('io.Platform.isMacOS'));
      });
    });
  });
}
