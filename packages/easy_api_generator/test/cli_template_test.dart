import 'package:easy_api_generator/builder/cli_template.dart';
import 'package:test/test.dart';

void main() {
  group('CliTemplate.generate', () {
    test('produces a CommandRunner with --compact flag for empty tools', () {
      final code = CliTemplate.generate(
        const <Map<String, dynamic>>[],
        appName: 'demo',
      );

      expect(code, contains("import 'package:args/command_runner.dart'"));
      expect(code, contains('CommandRunner<int>'));
      expect(code, contains("'demo'"));
      expect(code, contains("'compact'"));
      expect(code, contains('void _emitResult'));
      expect(code, contains('int _usageError'));
      expect(code, contains('int _internalError'));
    });

    test('groups tools by class into command groups with subcommands', () {
      final tools = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'list',
          'methodName': 'listUsers',
          'className': 'UserStore',
          'isStatic': true,
          'isAsync': true,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
          'description': 'List all users',
          'parameters': <Map<String, dynamic>>[],
        },
        <String, dynamic>{
          'name': 'createUser',
          'methodName': 'createUser',
          'className': 'UserStore',
          'isStatic': true,
          'isAsync': true,
          'sourceImport': 'package:example/user_store.dart',
          'sourceAlias': 'user_store',
          'description': 'Create a new user',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'name',
              'type': 'String',
              'isOptional': false,
              'isNamed': true,
            },
            <String, dynamic>{
              'name': 'email',
              'type': 'String',
              'isOptional': false,
              'isNamed': true,
              'parameterMetadata': <String, dynamic>{
                'pattern': r'^[\w\.-]+@[\w\.-]+\.\w+$',
              },
            },
          ],
        },
      ];

      final code = CliTemplate.generate(tools, appName: 'demo');

      // Class group is created with kebab-case name.
      expect(code, contains('_UserStoreGroupCommand'));
      expect(code, contains("get name => 'user-store'"));
      // Each tool becomes a subcommand under the group.
      expect(code, contains('_UserStoreListUsersCommand'));
      expect(code, contains('_UserStoreCreateUserCommand'));
      // The method name is used as the kebab-case subcommand name.
      expect(code, contains("get name => 'list-users'"));
      expect(code, contains("get name => 'create-user'"));
      // Pattern validation is rendered as a raw RegExp string.
      expect(
        code,
        contains(r"RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)"),
      );
      // The static method invocation goes through the source alias.
      expect(code, contains('user_store.UserStore.listUsers()'));
      expect(
        code,
        contains('user_store.UserStore.createUser(name: name, email: email)'),
      );
    });

    test('top-level functions become top-level commands', () {
      final tools = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'ping',
          'methodName': 'ping',
          'isStatic': false,
          'isAsync': false,
          'sourceImport': 'package:example/ping.dart',
          'sourceAlias': 'ping_lib',
          'description': 'Ping the server',
          'parameters': <Map<String, dynamic>>[],
        },
      ];

      final code = CliTemplate.generate(tools, appName: 'demo');

      expect(code, contains('_PingCommand'));
      expect(code, contains("get name => 'ping'"));
      expect(code, contains('ping_lib.ping()'));
    });

    test('renders bool as addFlag and primitive list as addMultiOption', () {
      final tools = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'doStuff',
          'methodName': 'doStuff',
          'className': 'Worker',
          'isStatic': true,
          'isAsync': false,
          'sourceImport': 'package:example/worker.dart',
          'sourceAlias': 'worker',
          'description': 'Do stuff',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'verbose',
              'type': 'bool',
              'isOptional': true,
              'defaultValueCode': 'false',
            },
            <String, dynamic>{
              'name': 'tags',
              'type': 'List<String>',
              'isOptional': true,
            },
          ],
        },
      ];

      final code = CliTemplate.generate(tools, appName: 'demo');

      expect(code, contains("addFlag('verbose'"));
      expect(code, contains("addMultiOption('tags'"));
    });

    test('emits _readJsonValue helper only when needed', () {
      final primitiveTools = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'echo',
          'methodName': 'echo',
          'className': 'Util',
          'isStatic': true,
          'isAsync': false,
          'sourceImport': 'package:example/util.dart',
          'sourceAlias': 'util',
          'description': 'Echo input',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'msg',
              'type': 'String',
              'isOptional': false,
            },
          ],
        },
      ];
      final primitiveCode = CliTemplate.generate(primitiveTools, appName: 'd');
      expect(primitiveCode.contains('dynamic _readJsonValue'), isFalse);

      final customTools = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'create',
          'methodName': 'create',
          'className': 'Store',
          'isStatic': true,
          'isAsync': false,
          'sourceImport': 'package:example/store.dart',
          'sourceAlias': 'store',
          'description': 'Create an item',
          'parameters': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'item',
              'type': 'Item',
              'isOptional': false,
            },
          ],
        },
      ];
      final customCode = CliTemplate.generate(customTools, appName: 'd');
      expect(customCode, contains('dynamic _readJsonValue'));
    });

    test('embeds full error output when logErrors is true', () {
      final code = CliTemplate.generate(
        const <Map<String, dynamic>>[],
        appName: 'demo',
        logErrors: true,
      );
      expect(code, contains('const bool _logErrors = true;'));
    });
  });
}
