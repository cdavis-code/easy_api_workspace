// DocExtractor - extracts tool info from annotated functions
// This is a placeholder that will be fully implemented with analyzer integration

/// Documentation and metadata extraction utilities for MCP tool generation.
///
/// This library provides the building blocks used by [McpBuilder] to describe
/// tools exposed through `@Tool`-annotated methods, including their parameter
/// shape and JSON Schema representation.
library;

/// Information about a tool extracted from annotations.
///
/// A [ToolInfo] describes a single MCP tool: its name, its human-readable
/// description, and the typed list of [parameters] it accepts. It is the
/// canonical intermediate representation produced during analysis and
/// consumed when emitting generated server code and JSON metadata.
class ToolInfo {
  /// The canonical name of the tool as exposed to MCP clients.
  final String name;

  /// Human-readable description of what the tool does.
  ///
  /// Typically sourced from the `@Tool(description: ...)` annotation, falling
  /// back to the method's DartDoc comment when not specified.
  final String description;

  /// Ordered list of parameters the tool accepts.
  final List<ParameterInfo> parameters;

  /// Creates a [ToolInfo] describing a single MCP tool.
  ///
  /// All fields are required and are emitted verbatim into generated code
  /// and JSON metadata.
  ToolInfo({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// Generate JSON-Schema for tool parameters.
  ///
  /// Produces a `type: object` schema with a `properties` map derived from
  /// each parameter's Dart type and a `required` list containing the names
  /// of non-optional parameters. The resulting map is suitable for embedding
  /// in an MCP `tools/list` response or OpenAPI `requestBody` schema.
  Map<String, dynamic> toJsonSchema() {
    final properties = <String, dynamic>{};
    final requiredParams = <String>[];

    for (final param in parameters) {
      properties[param.name] = _dartTypeToJsonSchema(param.type);
      if (!param.isOptional) requiredParams.add(param.name);
    }

    return {
      'type': 'object',
      'properties': properties,
      if (requiredParams.isNotEmpty) 'required': requiredParams,
    };
  }

  Map<String, dynamic> _dartTypeToJsonSchema(String dartType) {
    switch (dartType) {
      case 'int':
      case 'int?':
        return {'type': 'integer'};
      case 'double':
      case 'double?':
        return {'type': 'number'};
      case 'String':
      case 'String?':
        return {'type': 'string'};
      case 'bool':
      case 'bool?':
        return {'type': 'boolean'};
      case 'List':
      case 'List?':
        return {'type': 'array', 'items': {}};
      case 'Map':
      case 'Map?':
        return {'type': 'object'};
      default:
        return {'type': 'object'};
    }
  }
}

/// Information about a single parameter of a tool.
///
/// Captures the minimum information needed to generate both the MCP tool
/// schema and the Dart-side argument unpacking logic.
class ParameterInfo {
  /// The parameter's Dart identifier (e.g. `userId`).
  ///
  /// Used both as the JSON property key and as the named argument when the
  /// generated server invokes the underlying Dart function.
  final String name;

  /// The parameter's Dart type as a source string (e.g. `String`, `int?`,
  /// `List<String>`).
  ///
  /// Nullable types are indicated by a trailing `?` and are mapped to the
  /// same JSON Schema type as their non-nullable counterpart.
  final String type;

  /// Whether the parameter is optional.
  ///
  /// Optional parameters are excluded from the generated schema's `required`
  /// array. Defaults to `false` (i.e. required).
  final bool isOptional;

  /// Creates a [ParameterInfo] describing a tool parameter.
  ///
  /// [name] and [type] are required. [isOptional] defaults to `false`, making
  /// the parameter required by default — consistent with how positional and
  /// non-defaulted named Dart parameters behave.
  ParameterInfo({
    required this.name,
    required this.type,
    this.isOptional = false,
  });
}

/// Extracts documentation comments from Dart source elements.
///
/// [DocExtractor] provides a light-weight, regex-based fallback for pulling
/// DartDoc comments out of raw source when a full `analyzer` resolution is
/// not available. It is intended as a stop-gap until the builder pipeline
/// fully integrates with resolved [Element] information.
///
/// All methods are static — [DocExtractor] is used purely as a namespace and
/// is not meant to be instantiated directly.
class DocExtractor {
  /// Creates a [DocExtractor].
  ///
  /// This class exposes only static helpers, so instances carry no state.
  /// The default constructor is provided for API completeness and future
  /// extension (e.g. injecting a resolver).
  DocExtractor();

  /// Extract a DartDoc comment from [source] preceding [functionName].
  ///
  /// Walks backwards from the function declaration and collects consecutive
  /// `///` lines, joining them into a single space-separated description.
  /// Returns `null` when no DartDoc lines are found.
  static String? extractDocComment(String source, String functionName) {
    final pattern = RegExp(
      r'///\s*(.*?)\n\s*(?:void|String|int|bool|List|Map|Future)[^]*?\b' +
          RegExp.escape(functionName) +
          r'\s*\(',
      multiLine: true,
    );

    final match = pattern.firstMatch(source);
    if (match == null) return null;

    final docLines = <String>[];
    final lines = source.split('\n');
    final startIndex = match.start;

    for (var i = startIndex - 1; i >= 0 && i >= startIndex - 10; i--) {
      final line = lines[i];
      if (!line.trim().startsWith('///')) break;
      docLines.insert(0, line.replaceFirst('///', '').trim());
    }

    if (docLines.isEmpty) return null;
    return docLines.join(' ').replaceAll(r'\s+', ' ').trim();
  }

  /// Default description when no doc comment is available.
  ///
  /// Produces a generic placeholder so every generated tool still has a
  /// non-empty description in its JSON schema.
  static String defaultDescription(String toolName) {
    return 'Tool $toolName';
  }
}
