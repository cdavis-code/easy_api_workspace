import 'package:test/test.dart';
import 'package:easy_api_generator/builder/openapi_builder.dart';

void main() {
  group('OpenApiBuilder', () {
    group('build', () {
      test('generates valid OpenAPI 3.0.3 specification', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a new user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');

        expect(spec['openapi'], equals('3.0.3'));
        expect(spec['info'], isA<Map>());
        expect(spec['paths'], isA<Map>());
        expect(spec['servers'], isA<List>());
      });

      test('generates correct server URL for HTTP transport', () {
        final spec = OpenApiBuilder.build([], 'http', 3000, '127.0.0.1');

        final servers = spec['servers'] as List;
        expect(servers, hasLength(1));
        expect(servers[0]['url'], equals('http://127.0.0.1:3000'));
      });

      test('generates default server URL for stdio transport', () {
        final spec = OpenApiBuilder.build([], 'stdio', 3000, '127.0.0.1');

        final servers = spec['servers'] as List;
        expect(servers[0]['url'], equals('http://localhost:3000'));
      });
    });

    group('resource inference', () {
      test('maps createUser to POST /users', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users'), isTrue);
        expect(paths['/users']['post'], isNotNull);
        expect(paths['/users']['post']['summary'], equals('Create a new user'));
      });

      test('maps listUsers to GET /users', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'listUsers',
            'description': 'List all users',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users'), isTrue);
        expect(paths['/users']['get'], isNotNull);
        expect(paths['/users']['get']['summary'], equals('List all users'));
      });

      test('maps getUser to GET /users/{id}', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'getUser',
            'description': 'Get user by ID',
            'parameters': <Map<String, dynamic>>[
              {'name': 'id', 'type': 'int', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users/{id}'), isTrue);
        expect(paths['/users/{id}']['get'], isNotNull);
        expect(
          paths['/users/{id}']['get']['summary'],
          equals('Get a user by ID'),
        );
      });

      test('maps updateUser to PATCH /users/{id}', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'updateUser',
            'description': 'Update a user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': true},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users/{id}'), isTrue);
        expect(paths['/users/{id}']['patch'], isNotNull);
        expect(
          paths['/users/{id}']['patch']['summary'],
          equals('Update a user'),
        );
      });

      test('maps deleteUser to DELETE /users/{id}', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'deleteUser',
            'description': 'Delete a user',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users/{id}'), isTrue);
        expect(paths['/users/{id}']['delete'], isNotNull);
        expect(
          paths['/users/{id}']['delete']['summary'],
          equals('Delete a user'),
        );
      });

      test('handles class-prefixed tool names (UserStore_createUser)', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'UserStore_createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users'), isTrue);
        expect(paths['/users']['post'], isNotNull);
      });
    });

    group('request/response schemas', () {
      test('generates request body schema for POST', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': false},
              {'name': 'email', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final postOp = spec['paths']['/users']['post'];

        expect(postOp['requestBody']['required'], isTrue);
        final schema =
            postOp['requestBody']['content']['application/json']['schema'];
        expect(schema['type'], equals('object'));
        expect(schema['properties']['name']['type'], equals('string'));
        expect(schema['properties']['email']['type'], equals('string'));
        expect(schema['required'], contains('name'));
        expect(schema['required'], contains('email'));
      });

      test('generates proper response schemas', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {'name': 'name', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final responses = spec['paths']['/users']['post']['responses'];

        expect(responses['201'], isNotNull);
        expect(responses['400'], isNotNull);
        expect(responses['201']['description'], equals('Successfully created'));
      });

      test('generates 404 response for GET by ID', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'getUser',
            'description': 'Get user',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final responses = spec['paths']['/users/{id}']['get']['responses'];

        expect(responses['404'], isNotNull);
        expect(responses['404']['description'], equals('User not found'));
      });

      test('generates 204 response for DELETE', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'deleteUser',
            'description': 'Delete user',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final responses = spec['paths']['/users/{id}']['delete']['responses'];

        expect(responses['204'], isNotNull);
        expect(responses['204']['description'], equals('Successfully deleted'));
      });
    });

    group('parameter metadata', () {
      test('includes @Parameter metadata in schema', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {
                'name': 'age',
                'type': 'int',
                'isOptional': true,
                'title': 'Age',
                'description': 'User age',
                'minimum': 0,
                'maximum': 150,
                'example': 25,
              },
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final schema =
            spec['paths']['/users']['post']['requestBody']['content']['application/json']['schema'];

        expect(schema['properties']['age']['title'], equals('Age'));
        expect(schema['properties']['age']['description'], equals('User age'));
        expect(schema['properties']['age']['minimum'], equals(0));
        expect(schema['properties']['age']['maximum'], equals(150));
        expect(schema['properties']['age']['example'], equals(25));
      });

      test('includes enum values in schema', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create a user',
            'parameters': <Map<String, dynamic>>[
              {
                'name': 'role',
                'type': 'String',
                'isOptional': false,
                'enumValues': ['admin', 'user', 'guest'],
              },
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final schema =
            spec['paths']['/users']['post']['requestBody']['content']['application/json']['schema'];

        expect(
          schema['properties']['role']['enum'],
          equals(['admin', 'user', 'guest']),
        );
      });
    });

    group('type mapping', () {
      test('maps String to string type', () {
        final spec = OpenApiBuilder.build(
          [
            {
              'name': 'createTest',
              'description': 'Test',
              'parameters': [
                {'name': 'field', 'type': 'String', 'isOptional': false},
              ],
            },
          ],
          'http',
          8080,
          '0.0.0.0',
        );

        expect(
          spec['paths']['/tests']['post']['requestBody']['content']['application/json']['schema']['properties']['field']['type'],
          equals('string'),
        );
      });

      test('maps int to integer type', () {
        final spec = OpenApiBuilder.build(
          [
            {
              'name': 'createTest',
              'description': 'Test',
              'parameters': [
                {'name': 'field', 'type': 'int', 'isOptional': false},
              ],
            },
          ],
          'http',
          8080,
          '0.0.0.0',
        );

        expect(
          spec['paths']['/tests']['post']['requestBody']['content']['application/json']['schema']['properties']['field']['type'],
          equals('integer'),
        );
      });

      test('maps bool to boolean type', () {
        final spec = OpenApiBuilder.build(
          [
            {
              'name': 'createTest',
              'description': 'Test',
              'parameters': [
                {'name': 'field', 'type': 'bool', 'isOptional': false},
              ],
            },
          ],
          'http',
          8080,
          '0.0.0.0',
        );

        expect(
          spec['paths']['/tests']['post']['requestBody']['content']['application/json']['schema']['properties']['field']['type'],
          equals('boolean'),
        );
      });

      test('maps List to array type', () {
        final spec = OpenApiBuilder.build(
          [
            {
              'name': 'createTest',
              'description': 'Test',
              'parameters': [
                {'name': 'field', 'type': 'List', 'isOptional': false},
              ],
            },
          ],
          'http',
          8080,
          '0.0.0.0',
        );

        expect(
          spec['paths']['/tests']['post']['requestBody']['content']['application/json']['schema']['properties']['field']['type'],
          equals('array'),
        );
      });

      test('handles nullable types', () {
        final spec = OpenApiBuilder.build(
          [
            {
              'name': 'createTest',
              'description': 'Test',
              'parameters': [
                {'name': 'field', 'type': 'String?', 'isOptional': true},
              ],
            },
          ],
          'http',
          8080,
          '0.0.0.0',
        );

        expect(
          spec['paths']['/tests']['post']['requestBody']['content']['application/json']['schema']['properties']['field']['nullable'],
          isTrue,
        );
      });
    });

    group('multiple resources', () {
      test('groups tools by resource correctly', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create user',
            'parameters': <Map<String, dynamic>>[],
          },
          {
            'name': 'createTodo',
            'description': 'Create todo',
            'parameters': <Map<String, dynamic>>[],
          },
          {
            'name': 'listUsers',
            'description': 'List users',
            'parameters': <Map<String, dynamic>>[],
          },
          {
            'name': 'listTodos',
            'description': 'List todos',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users'), isTrue);
        expect(paths.containsKey('/todos'), isTrue);
        expect(paths['/users']['post'], isNotNull);
        expect(paths['/users']['get'], isNotNull);
        expect(paths['/todos']['post'], isNotNull);
        expect(paths['/todos']['get'], isNotNull);
      });
    });

    group('search operations', () {
      test('maps searchUsers to GET /users/search', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'searchUsers',
            'description': 'Search users',
            'parameters': <Map<String, dynamic>>[
              {'name': 'query', 'type': 'String', 'isOptional': false},
            ],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        final paths = spec['paths'] as Map;

        expect(paths.containsKey('/users/search'), isTrue);
        expect(paths['/users/search']['get'], isNotNull);
        expect(
          paths['/users/search']['get']['summary'],
          equals('Search users'),
        );
      });
    });

    group('operation IDs and tags', () {
      test('generates proper operation IDs', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create user',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        expect(
          spec['paths']['/users']['post']['operationId'],
          equals('createUser'),
        );
      });

      test('generates tags from resource name', () {
        final tools = <Map<String, dynamic>>[
          {
            'name': 'createUser',
            'description': 'Create user',
            'parameters': <Map<String, dynamic>>[],
          },
        ];

        final spec = OpenApiBuilder.build(tools, 'http', 8080, '0.0.0.0');
        expect(spec['paths']['/users']['post']['tags'], equals(['Users']));
      });
    });
  });
}
