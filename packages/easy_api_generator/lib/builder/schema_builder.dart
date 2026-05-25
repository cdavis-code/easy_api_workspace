import 'package:easy_api_generator/builder/template_utils.dart';

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
      final title = metadata['title'] as String;
      if (title.length > 200) {
        throw ArgumentError(
          'Parameter title exceeds maximum length of 200 characters '
          '(got ${title.length} characters)',
        );
      }
      params.add("title: '${escapeDartString(title)}'");
    }

    // Add description if present
    if (metadata['description'] != null) {
      final description = metadata['description'] as String;
      if (description.length > 1000) {
        throw ArgumentError(
          'Parameter description exceeds maximum length of 1000 characters '
          '(got ${description.length} characters)',
        );
      }
      params.add("description: '${escapeDartString(description)}'");
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

    // Add pattern for string types with ReDoS validation
    if (metadata['pattern'] != null) {
      final pattern = metadata['pattern'] as String;
      _validateRegexPattern(pattern);
      params.add("pattern: '${escapeDartString(pattern)}'");
    }

    // Add enum values if present
    if (metadata['enumValues'] != null) {
      final enumValues = metadata['enumValues'] as List;
      final enumStr = enumValues
          .map((v) {
            if (v is String) {
              if (v.length > 200) {
                throw ArgumentError(
                  'Enum value exceeds maximum length of 200 characters '
                  '(got ${v.length} characters): ${v.substring(0, 50)}...',
                );
              }
              return "'${escapeDartString(v)}'";
            }
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

  /// Validates a regex pattern to prevent ReDoS (Regular Expression Denial of Service) attacks.
  /// Throws [ArgumentError] if the pattern is potentially vulnerable.
  static void _validateRegexPattern(String pattern) {
    // Check for common ReDoS patterns
    // 1. Nested quantifiers: (a+)+, (a*)*, (a+){1,}
    if (RegExp(r'\([^)]*[+*][^)]*\)[+*{]').hasMatch(pattern)) {
      throw ArgumentError(
        'Regex pattern may be vulnerable to ReDoS: contains nested quantifiers. '
        'Pattern: $pattern',
      );
    }

    // 2. Alternation with overlapping prefixes: (a|a)+, (ab|ac)+
    // Fixed: Use single backslash in raw string for proper backreference
    if (RegExp(r'\(([^|]+)\|\1[^)]*\)[+*]').hasMatch(pattern)) {
      throw ArgumentError(
        'Regex pattern may be vulnerable to ReDoS: contains overlapping alternation. '
        'Pattern: $pattern',
      );
    }

    // 3. Test the pattern with multiple test strings to catch various ReDoS patterns
    try {
      final regex = RegExp(pattern);
      // Test with multiple strings that could trigger backtracking in different pattern types
      const testStrings = [
        'aaaaaaaaaaaaaaaaaaaa!', // Alphabetic repetition + termination
        '00000000000000000000x', // Numeric repetition
        'a,a,a,a,a,a,a,a,a,a,a,a,a,a,', // Comma-separated repetition
        'aaaaaaaaaaaaaaaaaaaa', // Pure repetition (no terminator)
      ];

      for (final testString in testStrings) {
        final stopwatch = Stopwatch()..start();
        regex.hasMatch(testString);
        stopwatch.stop();

        if (stopwatch.elapsedMilliseconds > 100) {
          throw ArgumentError(
            'Regex pattern may be vulnerable to ReDoS: matching took ${stopwatch.elapsedMilliseconds}ms on test input. '
            'Pattern: $pattern',
          );
        }
      }
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw ArgumentError('Invalid regex pattern: $pattern. Error: $e');
    }
  }
}
