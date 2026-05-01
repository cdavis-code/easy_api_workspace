/// Builds `Schema.*` source code expressions from MCP parameter metadata.
///
/// [SchemaBuilder] translates between three representations:
/// 1. Raw Dart type strings (e.g. `'int'`, `'List<String>'`) → [fromType]
/// 2. JSON-Schema-like maps produced by introspection → [fromSchemaMap]
/// 3. Ordered parameter lists with metadata → [buildObjectSchema]
///
/// All methods are static; the class is used purely as a namespace.
class SchemaBuilder {
  /// Private constructor — all operations are exposed as static helpers
  /// and this class is not meant to be instantiated.
  SchemaBuilder._();

  /// Converts a Dart type string to a `Schema.*` expression.
  static String fromType(String rawType) {
    final type = rawType.endsWith('?')
        ? rawType.substring(0, rawType.length - 1)
        : rawType;
    // Handle List<T>
    final listMatch = RegExp(r'^List<(.+)>$').firstMatch(type);
    if (listMatch != null) {
      final itemType = listMatch.group(1)!;
      return 'Schema.list(items: ${fromType(itemType)})';
    }

    switch (type) {
      case 'String':
        return 'Schema.string()';
      case 'int':
        return 'Schema.int()';
      case 'double':
        return 'Schema.num()';
      case 'num':
        return 'Schema.num()';
      case 'bool':
        return 'Schema.bool()';
      default:
        return 'Schema.string()';
    }
  }

  /// Converts a schema map (from _introspectType) to a Schema.* expression.
  static String fromSchemaMap(Map<String, dynamic> schema) {
    final type = schema['type'] as String?;
    switch (type) {
      case 'string':
        return 'Schema.string()';
      case 'integer':
        return 'Schema.int()';
      case 'number':
        return 'Schema.num()';
      case 'boolean':
        return 'Schema.bool()';
      case 'array':
        final items = schema['items'] as Map<String, dynamic>?;
        if (items != null) {
          return 'Schema.list(items: ${fromSchemaMap(items)})';
        }
        return 'Schema.list()';
      case 'object':
        final props = schema['properties'] as Map<String, dynamic>?;
        if (props == null || props.isEmpty) {
          return 'Schema.object()';
        }
        final propEntries = props.entries
            .map((e) {
              return "'${e.key}': ${fromSchemaMap(e.value as Map<String, dynamic>)}";
            })
            .join(',\n      ');
        final required = schema['required'] as List?;
        if (required != null && required.isNotEmpty) {
          final reqStr = required.map((r) => "'$r'").join(', ');
          return 'Schema.object(\n    properties: {\n      $propEntries,\n    },\n    required: [$reqStr],\n  )';
        }
        return 'Schema.object(\n    properties: {\n      $propEntries,\n    },\n  )';
      default:
        return 'Schema.string()';
    }
  }

  /// Builds a Schema.object() expression from a list of parameter maps.
  /// Each param map has: 'name', 'type', 'schemaMap', 'isOptional', 'parameterMetadata'
  static String buildObjectSchema(List<Map<String, dynamic>> params) {
    if (params.isEmpty) {
      return 'Schema.object()';
    }

    final properties = params
        .map((p) {
          final name = p['name'] as String;
          final metadata = p['parameterMetadata'] as Map<String, dynamic>?;
          // Use alias as the external property name when present
          final externalName = (metadata?['alias'] as String?) ?? name;
          final schemaMap = p['schemaMap'] as Map<String, dynamic>?;

          String schemaCode;
          if (schemaMap != null) {
            schemaCode = fromSchemaMap(schemaMap);
          } else {
            final type = p['type'] as String;
            schemaCode = fromType(type);
          }

          // Apply metadata enhancements if present
          if (metadata != null && metadata.isNotEmpty) {
            schemaCode = _applyMetadataToSchema(schemaCode, metadata);
          }

          return "'$externalName': $schemaCode";
        })
        .join(',\n      ');

    final required = params
        .where((p) => p['isOptional'] != true)
        .map((p) {
          final metadata = p['parameterMetadata'] as Map<String, dynamic>?;
          final externalName =
              (metadata?['alias'] as String?) ?? p['name'] as String;
          return "'$externalName'";
        })
        .join(', ');

    if (required.isEmpty) {
      return 'Schema.object(\n    properties: {\n      $properties,\n    },\n  )';
    }

    return 'Schema.object(\n    properties: {\n      $properties,\n    },\n    required: [$required],\n  )';
  }

  /// Applies @Parameter metadata to enhance a schema expression.
  /// Only applies to simple primitive schemas (string, int, num, bool).
  /// Complex schemas (objects, lists) are returned unchanged.
  static String _applyMetadataToSchema(
    String baseSchema,
    Map<String, dynamic> metadata,
  ) {
    // Only support augmenting simple primitive schemas for now
    // Complex schemas (objects, lists with arguments) are returned unchanged
    final match = RegExp(
      r'^Schema\.(string|int|num|bool)\(\)$',
    ).firstMatch(baseSchema.trim());
    if (match == null) {
      // Complex schemas keep their original structure
      return baseSchema;
    }

    final schemaType = match.group(1)!;
    final buffer = StringBuffer();
    buffer.write('Schema.$schemaType(');

    final params = <String>[];

    // Add title if present
    if (metadata['title'] != null) {
      params.add("title: '${_escapeString(metadata['title'] as String)}'");
    }

    // Add description if present
    if (metadata['description'] != null) {
      params.add(
        "description: '${_escapeString(metadata['description'] as String)}'",
      );
    }

    // Note: 'example' from @Parameter is not passed to Schema constructors
    // as dart_mcp Schema classes don't support the 'example' parameter.
    // Examples are available in the generated .mcp.json metadata file instead.

    // Add min/max for numeric types
    if (metadata['minimum'] != null) {
      params.add('min: ${metadata['minimum']}');
    }
    if (metadata['maximum'] != null) {
      params.add('max: ${metadata['maximum']}');
    }

    // Add pattern for string types
    if (metadata['pattern'] != null) {
      params.add("pattern: '${_escapeString(metadata['pattern'] as String)}'");
    }

    // Add enum values if present
    if (metadata['enumValues'] != null) {
      final enumValues = metadata['enumValues'] as List;
      final enumStr = enumValues
          .map((v) {
            if (v is String) return "'${_escapeString(v)}'";
            return v.toString();
          })
          .join(', ');
      params.add('enum: [$enumStr]');
    }

    if (params.isNotEmpty) {
      buffer.write('\n      ');
      buffer.write(params.join(',\n      '));
      buffer.write('\n    ');
    }

    buffer.write(')');
    return buffer.toString();
  }

  /// Escapes special characters in a string for use in generated Dart code.
  /// Handles backslashes, single quotes, newlines, and dollar signs (for string interpolation).
  static String _escapeString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\$', '\\\$');
  }
}
