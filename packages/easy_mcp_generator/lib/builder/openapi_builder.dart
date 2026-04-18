/// Generates OpenAPI 3.0 specifications from MCP tool definitions.
///
/// This builder transforms MCP tool metadata into RESTful OpenAPI 3.0 specifications
/// following API design best practices. It intelligently maps tool operations to
/// standard HTTP methods and resource-based URL patterns.
class OpenApiBuilder {
  /// Generates an OpenAPI 3.0 specification from tool definitions.
  ///
  /// [tools] - List of tool definitions with parameters and metadata
  /// [transport] - Transport protocol (http or stdio)
  /// [port] - Server port number
  /// [address] - Server bind address
  ///
  /// Returns a Map representing the complete OpenAPI 3.0 specification.
  static Map<String, dynamic> build(
    List<Map<String, dynamic>> tools,
    String transport,
    int port,
    String address,
  ) {
    // Group tools by inferred resource
    final resourceGroups = _groupToolsByResource(tools);

    // Build RESTful paths
    final paths = _buildRestfulPaths(resourceGroups);

    // Build complete OpenAPI specification
    return <String, dynamic>{
      'openapi': '3.0.3',
      'info': <String, dynamic>{
        'title': 'API Documentation',
        'version': '1.0.0',
        'description': 'Auto-generated OpenAPI specification from MCP tools',
      },
      'servers': [
        <String, dynamic>{
          'url': transport == 'http'
              ? 'http://$address:$port'
              : 'http://localhost:3000',
          'description': transport == 'http'
              ? 'HTTP API Server'
              : 'Local API Server',
        },
      ],
      'paths': paths,
    };
  }

  /// Groups tools by their inferred resource name.
  static Map<String, List<Map<String, dynamic>>> _groupToolsByResource(
    List<Map<String, dynamic>> tools,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final tool in tools) {
      final toolName = tool['name'] as String;
      final resourceName = _extractResourceName(toolName);

      if (!groups.containsKey(resourceName)) {
        groups[resourceName] = [];
      }
      groups[resourceName]!.add(tool);
    }

    return groups;
  }

  /// Extracts resource name from tool name.
  /// Examples:
  /// - "createUser" → "users"
  /// - "UserStore_createUser" → "users"
  /// - "listAllTodos" → "todos"
  static String _extractResourceName(String toolName) {
    String name = toolName;

    // Remove class prefix if present (e.g., "UserStore_" or "UserService_")
    if (toolName.contains('_')) {
      final parts = toolName.split('_');
      if (parts.length >= 2) {
        // If first part looks like a class name (starts with uppercase)
        final firstChar = parts[0][0];
        if (firstChar.toUpperCase() == firstChar) {
          name = parts.sublist(1).join('_');
        }
      }
    }

    // Extract resource from operation patterns
    final patterns = [
      // createX, getX, listX, updateX, deleteX, searchX
      RegExp(r'^(?:create|get|list|update|delete|search|find)(.+)$'),
      // XById, XByName, etc.
      RegExp(r'^(.+?)(?:ById|ByName|ByEmail|All|s)?$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(name);
      if (match != null && match.groupCount > 0) {
        final resource = match.group(1);
        if (resource != null && resource.isNotEmpty) {
          return _toResourcePath(resource);
        }
      }
    }

    // Fallback: use the name as-is
    return _toResourcePath(name);
  }

  /// Converts a name to a RESTful resource path (plural, lowercase).
  static String _toResourcePath(String name) {
    // Insert underscores before uppercase letters
    final spaced = name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );

    // Remove leading underscore
    String result = spaced.startsWith('_') ? spaced.substring(1) : spaced;

    // Simple pluralization
    if (!result.endsWith('s')) {
      if (result.endsWith('y')) {
        result = result.substring(0, result.length - 1) + 'ies';
      } else {
        result += 's';
      }
    }

    return result;
  }

  /// Builds RESTful path definitions from grouped tools.
  static Map<String, dynamic> _buildRestfulPaths(
    Map<String, List<Map<String, dynamic>>> resourceGroups,
  ) {
    final paths = <String, dynamic>{};

    for (final entry in resourceGroups.entries) {
      final resourceName = entry.key;
      final tools = entry.value;

      final collectionPath = '/$resourceName';
      final resourcePath = '/$resourceName/{id}';

      // Identify operations by name patterns
      final createTool = _findTool(tools, ['create']);
      final listTool = _findTool(tools, ['list', 'getall', 'listall']);
      final getTool = _findTool(tools, ['get'], exclude: ['all']);
      final updateTool = _findTool(tools, ['update']);
      final deleteTool = _findTool(tools, ['delete', 'remove']);
      final searchTool = _findTool(tools, ['search', 'find']);

      // GET /{resource} - List all
      if (listTool != null) {
        paths[collectionPath] ??= <String, dynamic>{};
        paths[collectionPath]['get'] = _buildListOperation(
          listTool,
          resourceName,
        );
      }

      // POST /{resource} - Create new
      if (createTool != null) {
        paths[collectionPath] ??= <String, dynamic>{};
        paths[collectionPath]['post'] = _buildCreateOperation(
          createTool,
          resourceName,
        );
      }

      // GET /{resource}/search - Search (if search tool exists)
      if (searchTool != null) {
        paths['$collectionPath/search'] = <String, dynamic>{
          'get': _buildSearchOperation(searchTool, resourceName),
        };
      }

      // GET /{resource}/{id} - Get by ID
      if (getTool != null) {
        paths[resourcePath] ??= <String, dynamic>{};
        paths[resourcePath]['get'] = _buildGetOperation(
          getTool,
          resourceName,
        );
      }

      // PATCH /{resource}/{id} - Update
      if (updateTool != null) {
        paths[resourcePath] ??= <String, dynamic>{};
        paths[resourcePath]['patch'] = _buildUpdateOperation(
          updateTool,
          resourceName,
        );
      }

      // DELETE /{resource}/{id} - Delete
      if (deleteTool != null) {
        paths[resourcePath] ??= <String, dynamic>{};
        paths[resourcePath]['delete'] = _buildDeleteOperation(
          deleteTool,
          resourceName,
        );
      }
    }

    return paths;
  }

  /// Finds a tool whose name contains any of the keywords.
  static Map<String, dynamic>? _findTool(
    List<Map<String, dynamic>> tools,
    List<String> keywords, {
    List<String> exclude = const [],
  }) {
    for (final tool in tools) {
      final name = (tool['name'] as String).toLowerCase();
      final hasKeyword = keywords.any(name.contains);
      final hasExcluded = exclude.any(name.contains);

      if (hasKeyword && !hasExcluded) {
        return tool;
      }
    }
    return null;
  }

  /// Builds POST operation for creating a resource.
  static Map<String, dynamic> _buildCreateOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
    final singularResource = _singularize(resourceName);

    return <String, dynamic>{
      'summary': 'Create a new $singularResource',
      'operationId': 'create${_capitalize(singularResource)}',
      'tags': [_capitalize(resourceName)],
      'requestBody': <String, dynamic>{
        'required': true,
        'content': <String, dynamic>{
          'application/json': <String, dynamic>{
            'schema': _buildRequestBodySchema(params),
            if (params.isNotEmpty) 'example': _buildExampleFromParams(params),
          },
        },
      },
      'responses': <String, dynamic>{
        '201': <String, dynamic>{
          'description': 'Successfully created',
          'content': <String, dynamic>{
            'application/json': <String, dynamic>{
              'schema': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'id': <String, dynamic>{'type': 'integer'},
                  ..._buildResponseProperties(params),
                },
              },
            },
          },
        },
        '400': <String, dynamic>{
          'description': 'Invalid request body',
        },
      },
    };
  }

  /// Builds GET operation for listing resources.
  static Map<String, dynamic> _buildListOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
    final queryParameters = _buildQueryParameters(params);

    return <String, dynamic>{
      'summary': 'List all $resourceName',
      'operationId': 'list${_capitalize(resourceName)}',
      'tags': [_capitalize(resourceName)],
      'parameters': queryParameters,
      'responses': <String, dynamic>{
        '200': <String, dynamic>{
          'description': 'Successfully retrieved list',
          'content': <String, dynamic>{
            'application/json': <String, dynamic>{
              'schema': <String, dynamic>{
                'type': 'array',
                'items': <String, dynamic>{
                  'type': 'object',
                  'properties': <String, dynamic>{
                    'id': <String, dynamic>{'type': 'integer'},
                  },
                },
              },
            },
          },
        },
      },
    };
  }

  /// Builds GET operation for retrieving a single resource.
  static Map<String, dynamic> _buildGetOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final singularResource = _singularize(resourceName);

    return <String, dynamic>{
      'summary': 'Get a $singularResource by ID',
      'operationId': 'get${_capitalize(singularResource)}',
      'tags': [_capitalize(resourceName)],
      'parameters': [
        <String, dynamic>{
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': <String, dynamic>{'type': 'integer'},
          'description': 'The $singularResource ID',
        },
      ],
      'responses': <String, dynamic>{
        '200': <String, dynamic>{
          'description': 'Successfully retrieved',
          'content': <String, dynamic>{
            'application/json': <String, dynamic>{
              'schema': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'id': <String, dynamic>{'type': 'integer'},
                },
              },
            },
          },
        },
        '404': <String, dynamic>{
          'description': '${_capitalize(singularResource)} not found',
        },
      },
    };
  }

  /// Builds PATCH operation for updating a resource.
  static Map<String, dynamic> _buildUpdateOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
    final singularResource = _singularize(resourceName);

    return <String, dynamic>{
      'summary': 'Update a $singularResource',
      'operationId': 'update${_capitalize(singularResource)}',
      'tags': [_capitalize(resourceName)],
      'parameters': [
        <String, dynamic>{
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': <String, dynamic>{'type': 'integer'},
          'description': 'The $singularResource ID',
        },
      ],
      'requestBody': <String, dynamic>{
        'required': true,
        'content': <String, dynamic>{
          'application/json': <String, dynamic>{
            'schema': _buildRequestBodySchema(params),
          },
        },
      },
      'responses': <String, dynamic>{
        '200': <String, dynamic>{
          'description': 'Successfully updated',
        },
        '404': <String, dynamic>{
          'description': '${_capitalize(singularResource)} not found',
        },
        '400': <String, dynamic>{
          'description': 'Invalid request',
        },
      },
    };
  }

  /// Builds DELETE operation for removing a resource.
  static Map<String, dynamic> _buildDeleteOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final singularResource = _singularize(resourceName);

    return <String, dynamic>{
      'summary': 'Delete a $singularResource',
      'operationId': 'delete${_capitalize(singularResource)}',
      'tags': [_capitalize(resourceName)],
      'parameters': [
        <String, dynamic>{
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': <String, dynamic>{'type': 'integer'},
          'description': 'The $singularResource ID',
        },
      ],
      'responses': <String, dynamic>{
        '204': <String, dynamic>{
          'description': 'Successfully deleted',
        },
        '404': <String, dynamic>{
          'description': '${_capitalize(singularResource)} not found',
        },
      },
    };
  }

  /// Builds GET operation for searching resources.
  static Map<String, dynamic> _buildSearchOperation(
    Map<String, dynamic> tool,
    String resourceName,
  ) {
    final params = tool['parameters'] as List<Map<String, dynamic>>? ?? [];
    final queryParameters = _buildQueryParameters(params);

    return <String, dynamic>{
      'summary': 'Search $resourceName',
      'operationId': 'search${_capitalize(resourceName)}',
      'tags': [_capitalize(resourceName)],
      'parameters': queryParameters,
      'responses': <String, dynamic>{
        '200': <String, dynamic>{
          'description': 'Search results',
          'content': <String, dynamic>{
            'application/json': <String, dynamic>{
              'schema': <String, dynamic>{
                'type': 'array',
                'items': <String, dynamic>{
                  'type': 'object',
                },
              },
            },
          },
        },
      },
    };
  }

  /// Builds request body schema from parameters.
  static Map<String, dynamic> _buildRequestBodySchema(
    List<Map<String, dynamic>> params,
  ) {
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final param in params) {
      final paramName = param['name'] as String;
      final paramType = param['type'] as String;
      final isOptional = param['isOptional'] == true;

      properties[paramName] = _dartTypeToOpenApiSchema(paramType, param);

      if (!isOptional) {
        required.add(paramName);
      }
    }

    return <String, dynamic>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  /// Builds query parameters for list/search operations.
  static List<Map<String, dynamic>> _buildQueryParameters(
    List<Map<String, dynamic>> params,
  ) {
    return params
        .map((param) {
          final paramName = param['name'] as String;
          final paramType = param['type'] as String;
          final isOptional = param['isOptional'] == true;
          final description = param['description'] as String?;

          return <String, dynamic>{
            'name': paramName,
            'in': 'query',
            'required': !isOptional,
            'schema': _dartTypeToOpenApiSchema(paramType, param),
            if (description != null) 'description': description,
          };
        })
        .toList();
  }

  /// Converts Dart type to OpenAPI schema.
  static Map<String, dynamic> _dartTypeToOpenApiSchema(
    String rawType,
    Map<String, dynamic> paramMetadata,
  ) {
    final type = rawType.endsWith('?')
        ? rawType.substring(0, rawType.length - 1)
        : rawType;

    Map<String, dynamic> schema;

    switch (type) {
      case 'int':
        schema = <String, dynamic>{'type': 'integer'};
        break;
      case 'double':
      case 'num':
        schema = <String, dynamic>{'type': 'number'};
        break;
      case 'String':
        schema = <String, dynamic>{'type': 'string'};
        break;
      case 'bool':
        schema = <String, dynamic>{'type': 'boolean'};
        break;
      case 'List':
        schema = <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'object'},
        };
        break;
      case 'Map':
      case 'dynamic':
        schema = <String, dynamic>{'type': 'object'};
        break;
      default:
        if (type.startsWith('List<')) {
          schema = <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          };
        } else {
          schema = <String, dynamic>{'type': 'object'};
        }
    }

    // Add metadata from @Parameter annotation
    if (paramMetadata['title'] != null) {
      schema['title'] = paramMetadata['title'];
    }
    if (paramMetadata['description'] != null) {
      schema['description'] = paramMetadata['description'];
    }
    if (paramMetadata['example'] != null) {
      schema['example'] = paramMetadata['example'];
    }
    if (paramMetadata['minimum'] != null) {
      schema['minimum'] = paramMetadata['minimum'];
    }
    if (paramMetadata['maximum'] != null) {
      schema['maximum'] = paramMetadata['maximum'];
    }
    if (paramMetadata['pattern'] != null) {
      schema['pattern'] = paramMetadata['pattern'];
    }
    if (paramMetadata['enumValues'] != null) {
      schema['enum'] = paramMetadata['enumValues'];
    }

    // Handle nullable types
    if (rawType.endsWith('?')) {
      schema['nullable'] = true;
    }

    return schema;
  }

  /// Builds example object from parameters.
  static Map<String, dynamic> _buildExampleFromParams(
    List<Map<String, dynamic>> params,
  ) {
    final example = <String, dynamic>{};

    for (final param in params) {
      final paramName = param['name'] as String;
      final exampleValue = param['example'];

      if (exampleValue != null) {
        example[paramName] = exampleValue;
      } else {
        // Provide sensible defaults
        final paramType = param['type'] as String;
        example[paramName] = _defaultValueForType(paramType);
      }
    }

    return example;
  }

  /// Builds response properties from parameters.
  static Map<String, dynamic> _buildResponseProperties(
    List<Map<String, dynamic>> params,
  ) {
    final properties = <String, dynamic>{};

    for (final param in params) {
      final paramName = param['name'] as String;
      final paramType = param['type'] as String;
      properties[paramName] = _dartTypeToOpenApiSchema(paramType, param);
    }

    return properties;
  }

  /// Returns a default value for a given type.
  static dynamic _defaultValueForType(String type) {
    final baseType = type.endsWith('?')
        ? type.substring(0, type.length - 1)
        : type;

    switch (baseType) {
      case 'String':
        return 'example';
      case 'int':
        return 1;
      case 'double':
      case 'num':
        return 1.0;
      case 'bool':
        return false;
      case 'List':
        return [];
      case 'Map':
      case 'dynamic':
        return {};
      default:
        return null;
    }
  }

  /// Capitalizes the first letter of a string.
  static String _capitalize(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Converts plural to singular.
  static String _singularize(String plural) {
    if (plural.endsWith('ies')) {
      return plural.substring(0, plural.length - 3) + 'y';
    }
    if (plural.endsWith('s') && !plural.endsWith('ss')) {
      return plural.substring(0, plural.length - 1);
    }
    return plural;
  }
}
