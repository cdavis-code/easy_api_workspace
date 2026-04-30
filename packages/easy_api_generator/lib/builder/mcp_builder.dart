import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/constant/value.dart';
import '../stubs.dart';
import 'templates.dart';
import 'openapi_builder.dart';
import 'openapi_dart_template.dart';

/// Builder that generates MCP server code from @Server and @Tool annotations.
///
/// This builder processes Dart files containing MCP annotations and generates:
/// - `.mcp.dart` files containing the complete MCP server implementation
/// - `.mcp.json` files containing tool metadata (if generateJson is true)
///
/// The builder supports two transport modes:
/// - **stdio**: JSON-RPC over standard input/output (default)
/// - **http**: HTTP server using the shelf package
///
/// For HTTP transport, the builder extracts port and address configuration from
/// the @Server annotation to customize the server binding.
///
/// Example generated files:
/// - `my_server.mcp.dart` - Complete MCP server with tool handlers
/// - `my_server.mcp.json` - Tool metadata with JSON schemas
class McpBuilder extends Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.mcp.dart', '.mcp.json', '.openapi.json', '.openapi.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final resolver = buildStep.resolver;

    if (!await resolver.isLibrary(inputId)) return;

    final library = await buildStep.resolver.libraryFor(inputId);

    // Only process files with @Server annotation
    if (!_hasServerAnnotation(library)) return;

    // Extract tool prefix from @Server annotation (applies to all tools in scope)
    final toolPrefix = _findToolPrefix(library);

    // Extract auto class prefix setting from @Server annotation
    final autoClassPrefix = _findAutoClassPrefix(library);

    // Aggregate tools from this library AND all its imports
    final tools = await _extractAllTools(library, toolPrefix, autoClassPrefix);

    if (tools.isEmpty) return; // No tools found anywhere

    // Extract transport configuration from @Server annotation
    final transport = _findTransport(library);

    // For HTTP transport, extract port and address configuration
    // These settings customize how the HTTP server binds to the network
    final port = _findPort(library);
    final address = _findAddress(library);

    // Extract code mode configuration from @Server annotation
    final codeMode = _findCodeMode(library);
    final codeModeTimeout = _findCodeModeTimeout(library);
    final logErrors = _findLogErrors(library);

    // Conditionally generate MCP server code (gated by generateMcp flag)
    if (_shouldGenerateMcp(library)) {
      // Generate the appropriate server code based on transport type
      final generated = transport == 'http'
          ? HttpTemplate.generate(
              tools,
              port,
              address,
              codeMode: codeMode,
              codeModeTimeout: codeModeTimeout,
              logErrors: logErrors,
            )
          : StdioTemplate.generate(
              tools,
              codeMode: codeMode,
              codeModeTimeout: codeModeTimeout,
              logErrors: logErrors,
            );

      // Write the generated server code
      await buildStep.writeAsString(
        inputId.changeExtension('.mcp.dart'),
        generated,
      );

      // Optionally generate JSON metadata file
      if (_shouldGenerateJson(library)) {
        final jsonMetadata = _generateJsonMetadata(tools);
        await buildStep.writeAsString(
          inputId.changeExtension('.mcp.json'),
          jsonEncode(jsonMetadata),
        );
      }
    }

    // Conditionally generate REST/OpenAPI output (gated by generateRest flag)
    if (_shouldGenerateRest(library)) {
      final openApiSpec = OpenApiBuilder.build(tools, transport, port, address);
      await buildStep.writeAsString(
        inputId.changeExtension('.openapi.json'),
        const JsonEncoder.withIndent('  ').convert(openApiSpec),
      );

      // Generate .openapi.dart REST server
      final openApiDartCode = OpenApiDartTemplate.generate(
        tools,
        port,
        address,
        openApiSpec,
      );
      await buildStep.writeAsString(
        inputId.changeExtension('.openapi.dart'),
        openApiDartCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _extractToolsFromLibrary(
    LibraryElement library,
    String? toolPrefix,
    bool autoClassPrefix,
  ) async {
    final tools = <Map<String, dynamic>>[];
    const toolChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Tool',
    );

    // Top-level functions
    for (final element in library.topLevelFunctions) {
      final toolAnnotation = toolChecker.firstAnnotationOf(element);
      if (toolAnnotation == null) continue;

      final description = _extractDescription(toolAnnotation, element);
      final parameters = _extractParametersFromElement(element);
      final isAsync = element.returnType.isDartAsyncFuture;
      final toolName = _extractToolName(
        toolAnnotation,
        element.name ?? 'unnamed',
        toolPrefix,
      );

      // Extract codeMode from @Tool annotation (defaults to true)
      final toolCodeMode = _extractToolCodeMode(toolAnnotation);
      // Extract codeModeVisible from @Tool annotation (defaults to false)
      final toolCodeModeVisible = _extractToolCodeModeVisible(toolAnnotation);

      // Get the return type string, unwrapping Future<T> if async
      final returnType = _getTypeString(element.returnType);

      tools.add(<String, dynamic>{
        'name': toolName,
        'methodName': element.name ?? 'unnamed',
        'description': description,
        'parameters': parameters,
        'isAsync': isAsync,
        'returnType': returnType,
        'codeMode': toolCodeMode,
        'codeModeVisible': toolCodeModeVisible,
      });
    }

    // Class methods
    for (final element in library.classes) {
      for (final method in element.methods) {
        final toolAnnotation = toolChecker.firstAnnotationOf(method);
        if (toolAnnotation == null) continue;

        final description = _extractDescription(toolAnnotation, method);
        final parameters = _extractParametersFromElement(method);
        final isAsync = method.returnType.isDartAsyncFuture;

        // Get base tool name (without any prefixes)
        final baseToolName = _extractToolName(
          toolAnnotation,
          method.name ?? 'unnamed',
          null, // Don't apply prefix yet
        );

        // Build final tool name with prefixes
        String toolName = baseToolName;

        // Apply auto class prefix if enabled
        if (autoClassPrefix && element.name != null) {
          toolName = '${element.name}_$toolName';
        }

        // Apply custom tool prefix if provided
        if (toolPrefix != null && toolPrefix.isNotEmpty) {
          toolName = '$toolPrefix$toolName';
        }

        // Extract codeMode from @Tool annotation (defaults to true)
        final toolCodeMode = _extractToolCodeMode(toolAnnotation);
        // Extract codeModeVisible from @Tool annotation (defaults to false)
        final toolCodeModeVisible = _extractToolCodeModeVisible(toolAnnotation);

        // Get the return type string, unwrapping Future<T> if async
        final returnType = _getTypeString(method.returnType);

        tools.add(<String, dynamic>{
          'name': toolName,
          'methodName': method.name ?? 'unnamed',
          'description': description,
          'parameters': parameters,
          'isAsync': isAsync,
          'returnType': returnType,
          'className': element.name,
          'isStatic': method.isStatic,
          'codeMode': toolCodeMode,
          'codeModeVisible': toolCodeModeVisible,
        });
      }
    }

    return tools;
  }

  /// Extracts tools from the current library and all package-local imports.
  /// Each tool is annotated with sourceImport and sourceAlias.
  /// Applies the toolPrefix and autoClassPrefix to all extracted tool names.
  Future<List<Map<String, dynamic>>> _extractAllTools(
    LibraryElement library,
    String? toolPrefix,
    bool autoClassPrefix,
  ) async {
    final allTools = <Map<String, dynamic>>[];
    final aliasCounts = <String, int>{};

    // Get the current library's package name
    final currentPackageUri = library.uri.toString();
    final packageName = _extractPackageName(currentPackageUri);

    // Extract tools from the current library (@Server file itself)
    final currentLibTools = await _extractToolsFromLibrary(
      library,
      toolPrefix,
      autoClassPrefix,
    );
    final currentAlias = _deriveAlias(currentPackageUri);
    for (final tool in currentLibTools) {
      tool['sourceImport'] = currentPackageUri;
      tool['sourceAlias'] = currentAlias;
      allTools.add(tool);
    }

    // Scan imported libraries for tools
    // Access imported libraries through the first fragment
    final importedLibraries = library.firstFragment.importedLibraries;
    for (final importedLib in importedLibraries) {
      final importedUri = importedLib.uri.toString();

      // Skip non-package URIs (dart: core libraries)
      if (!importedUri.startsWith('package:')) continue;

      // Skip libraries from other packages
      final importedPackageName = _extractPackageName(importedUri);
      if (importedPackageName != packageName) continue;

      // Extract tools from this imported library (also apply prefix and auto class prefix)
      final importedTools = await _extractToolsFromLibrary(
        importedLib,
        toolPrefix,
        autoClassPrefix,
      );
      if (importedTools.isEmpty) continue;

      // Derive alias and ensure uniqueness
      var alias = _deriveAlias(importedUri);
      final count = aliasCounts[alias] ?? 0;
      if (count > 0) {
        alias = '${alias}_$count';
      }
      aliasCounts[alias] = count + 1;

      for (final tool in importedTools) {
        tool['sourceImport'] = importedUri;
        tool['sourceAlias'] = alias;
        allTools.add(tool);
      }
    }

    return allTools;
  }

  /// Extracts the package name from a package URI.
  /// E.g., 'package:mcp_example/src/user.dart' -> 'mcp_example'
  /// Also handles asset URIs: 'asset:mcp_example/bin/example.dart' -> 'mcp_example'
  String _extractPackageName(String uri) {
    // Handle asset: URIs (e.g., for bin/ files)
    if (uri.startsWith('asset:')) {
      final withoutAsset = uri.substring('asset:'.length);
      final slashIndex = withoutAsset.indexOf('/');
      if (slashIndex == -1) return withoutAsset;
      return withoutAsset.substring(0, slashIndex);
    }
    // Handle package: URIs
    if (!uri.startsWith('package:')) return '';
    final withoutPackage = uri.substring('package:'.length);
    final slashIndex = withoutPackage.indexOf('/');
    if (slashIndex == -1) return withoutPackage;
    return withoutPackage.substring(0, slashIndex);
  }

  /// Derives an import alias from a package URI.
  /// E.g., 'package:mcp_example/src/user_store.dart' -> 'user_store'
  /// Also handles asset URIs: 'asset:mcp_example/bin/example.dart' -> 'example'
  String _deriveAlias(String uri) {
    final lastSlash = uri.lastIndexOf('/');
    if (lastSlash == -1) return uri;
    final fileName = uri.substring(lastSlash + 1);
    // Remove .dart extension
    if (fileName.endsWith('.dart')) {
      return fileName.substring(0, fileName.length - '.dart'.length);
    }
    return fileName;
  }

  String _extractDescription(
    DartObject? toolAnnotation,
    ExecutableElement element,
  ) {
    final reader = ConstantReader(toolAnnotation);
    final desc = reader.peek('description');
    if (desc != null) {
      return desc.stringValue;
    }

    // Fall back to doc comment
    if (element.documentationComment != null &&
        element.documentationComment!.isNotEmpty) {
      return _stripDocComment(element.documentationComment!);
    }

    return 'Tool ${element.name}';
  }

  /// Extracts the tool name from the annotation, applying custom name and prefix.
  ///
  /// Priority: custom name from @Tool.name > method name
  /// Then applies toolPrefix if provided.
  String _extractToolName(
    DartObject? toolAnnotation,
    String methodName,
    String? toolPrefix,
  ) {
    final reader = ConstantReader(toolAnnotation);
    final nameField = reader.peek('name');

    // Use custom name if provided, otherwise use method name
    String toolName = methodName;
    if (nameField != null && nameField.isString) {
      final customName = nameField.stringValue;
      if (customName.isNotEmpty) {
        toolName = customName;
      }
    }

    // Apply prefix if provided
    if (toolPrefix != null && toolPrefix.isNotEmpty) {
      toolName = '$toolPrefix$toolName';
    }

    return toolName;
  }

  String _stripDocComment(String docComment) {
    return docComment
        .replaceAll(RegExp(r'^///\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^//\s?', multiLine: true), '')
        .trim();
  }

  List<Map<String, dynamic>> _extractParametersFromElement(
    ExecutableElement element,
  ) {
    final params = <Map<String, dynamic>>[];
    const parameterChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Parameter',
    );

    for (final param in element.formalParameters) {
      final typeString = _getTypeString(param.type);
      final isOptional = !param.isRequired;
      final isNamedParam = param.isNamed;

      // Use full introspection for the schema map
      final schemaMap = _introspectType(param.type);

      // Extract import URI for custom List inner types
      final String? listInnerTypeImport = _extractListInnerTypeImport(
        param.type,
      );

      // Extract @Parameter annotation metadata if present
      final parameterMetadata = _extractParameterMetadata(
        param,
        parameterChecker,
      );

      params.add(<String, dynamic>{
        'name': param.name,
        'type': typeString,
        'schema': _dartTypeToJsonSchema(typeString),
        'schemaMap': schemaMap,
        'isOptional': isOptional,
        'isNamed': isNamedParam,
        'listInnerTypeImport': listInnerTypeImport,
        'parameterMetadata': parameterMetadata,
      });
    }

    return params;
  }

  /// Extracts metadata from a @Parameter annotation on a parameter.
  Map<String, dynamic>? _extractParameterMetadata(
    FormalParameterElement param,
    TypeChecker parameterChecker,
  ) {
    final annotation = parameterChecker.firstAnnotationOf(param);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    final metadata = <String, dynamic>{};

    // Extract alias
    final alias = reader.peek('alias');
    if (alias != null && !alias.isNull && alias.isString) {
      metadata['alias'] = alias.stringValue;
    }

    // Extract title
    final title = reader.peek('title');
    if (title != null && !title.isNull && title.isString) {
      metadata['title'] = title.stringValue;
    }

    // Extract description
    final description = reader.peek('description');
    if (description != null && !description.isNull && description.isString) {
      metadata['description'] = description.stringValue;
    }

    // Extract example
    final example = reader.peek('example');
    if (example != null && !example.isNull) {
      if (example.isString) {
        metadata['example'] = example.stringValue;
      } else if (example.isInt) {
        metadata['example'] = example.intValue;
      } else if (example.isDouble) {
        metadata['example'] = example.doubleValue;
      } else if (example.isBool) {
        metadata['example'] = example.boolValue;
      }
    }

    // Extract minimum
    final minimum = reader.peek('minimum');
    if (minimum != null && !minimum.isNull) {
      if (minimum.isInt) {
        metadata['minimum'] = minimum.intValue;
      } else if (minimum.isDouble) {
        metadata['minimum'] = minimum.doubleValue;
      }
    }

    // Extract maximum
    final maximum = reader.peek('maximum');
    if (maximum != null && !maximum.isNull) {
      if (maximum.isInt) {
        metadata['maximum'] = maximum.intValue;
      } else if (maximum.isDouble) {
        metadata['maximum'] = maximum.doubleValue;
      }
    }

    // Extract pattern
    final pattern = reader.peek('pattern');
    if (pattern != null && !pattern.isNull && pattern.isString) {
      metadata['pattern'] = pattern.stringValue;
    }

    // Extract sensitive
    final sensitive = reader.peek('sensitive');
    if (sensitive != null && !sensitive.isNull && sensitive.isBool) {
      metadata['sensitive'] = sensitive.boolValue;
    }

    // Extract enumValues
    final enumValues = reader.peek('enumValues');
    if (enumValues != null && !enumValues.isNull && enumValues.isList) {
      final enumList = enumValues.listValue;
      metadata['enumValues'] = enumList.map((v) {
        final valueReader = ConstantReader(v);
        if (valueReader.isString) return valueReader.stringValue;
        if (valueReader.isInt) return valueReader.intValue;
        if (valueReader.isDouble) return valueReader.doubleValue;
        if (valueReader.isBool) return valueReader.boolValue;
        return v.toString();
      }).toList();
    }

    return metadata.isEmpty ? null : metadata;
  }

  /// Extracts the import URI for the inner type of a `List<T>` if T is a custom type.
  /// Returns null if the type is not a List or if the inner type is a primitive.
  String? _extractListInnerTypeImport(DartType type) {
    // Handle List<T>
    if (type.isDartCoreList) {
      if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
        final itemType = type.typeArguments.first;
        // Check if it's a custom class (not dart:core or dart:async)
        if (_isCustomClass(itemType)) {
          final element = itemType.element;
          if (element != null) {
            final library = element.library;
            if (library != null) {
              return library.uri.toString();
            }
          }
        }
      }
    }
    return null;
  }

  String _getTypeString(DartType type) {
    if (type.isDartAsyncFuture) {
      if (type is ParameterizedType) {
        final typeArg = type.typeArguments.first;
        return _getTypeString(typeArg);
      }
      return 'dynamic';
    }
    return type.getDisplayString();
  }

  /// Checks if a type is a custom class (not a dart:core or dart:async type).
  bool _isCustomClass(DartType type) {
    if (type is! InterfaceType) return false;
    final element = type.element;
    // Skip dart:core types (String, int, List, Map, etc.)
    if (element.library.isDartCore) return false;
    // Skip dart:async types (Future, Stream, etc.)
    if (element.library.isDartAsync) return false;
    return true;
  }

  /// Introspects a DartType to generate a full JSON Schema map.
  /// Handles primitives, lists, maps, and custom classes with cycle detection.
  Map<String, dynamic> _introspectType(DartType type, {Set<String>? visited}) {
    visited ??= <String>{};

    // Handle nullable types by unwrapping
    if (type.isDartCoreNull) {
      return <String, dynamic>{'type': 'object'};
    }

    // Handle primitives
    if (type.isDartCoreInt) {
      return <String, dynamic>{'type': 'integer'};
    }
    if (type.isDartCoreDouble || type.isDartCoreNum) {
      return <String, dynamic>{'type': 'number'};
    }
    if (type.isDartCoreString) {
      return <String, dynamic>{'type': 'string'};
    }
    if (type.isDartCoreBool) {
      return <String, dynamic>{'type': 'boolean'};
    }

    // Handle DateTime (commonly used, treated as string with format)
    final typeString = type.getDisplayString();
    if (typeString == 'DateTime') {
      return <String, dynamic>{'type': 'string', 'format': 'date-time'};
    }

    // Handle dynamic
    if (type.getDisplayString() == 'dynamic') {
      return <String, dynamic>{'type': 'object'};
    }

    // Handle List<T>
    if (type.isDartCoreList) {
      if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
        final itemType = type.typeArguments.first;
        return <String, dynamic>{
          'type': 'array',
          'items': _introspectType(itemType, visited: visited),
        };
      }
      return <String, dynamic>{'type': 'array'};
    }

    // Handle Map<K, V>
    if (type.isDartCoreMap) {
      return <String, dynamic>{'type': 'object'};
    }

    // Handle custom classes
    if (_isCustomClass(type)) {
      final typeName = type.getDisplayString();

      // Cycle detection - if we've seen this type, return generic object
      if (visited.contains(typeName)) {
        return <String, dynamic>{'type': 'object'};
      }

      // Add to visited set
      final newVisited = {...visited, typeName};

      if (type is InterfaceType) {
        final classElement = type.element;
        final properties = <String, dynamic>{};
        final requiredFields = <String>[];

        for (final field in classElement.fields) {
          // Skip static fields
          if (field.isStatic) continue;
          // Skip private fields
          final fieldName = field.name;
          if (fieldName == null) continue;
          if (fieldName.startsWith('_')) continue;

          final fieldType = field.type;
          properties[fieldName] = _introspectType(
            fieldType,
            visited: newVisited,
          );

          // Add to required if non-nullable (doesn't end with ?) and no default value
          final fieldTypeName = fieldType.getDisplayString();
          final isNullable = fieldTypeName.endsWith('?');
          if (!isNullable) {
            requiredFields.add(fieldName);
          }
        }

        final result = <String, dynamic>{
          'type': 'object',
          'properties': properties,
        };

        if (requiredFields.isNotEmpty) {
          result['required'] = requiredFields;
        }

        return result;
      }
    }

    // Default fallback
    return <String, dynamic>{'type': 'object'};
  }

  String _dartTypeToJsonSchema(String rawType) {
    final dartType = rawType.endsWith('?')
        ? rawType.substring(0, rawType.length - 1)
        : rawType;
    switch (dartType) {
      case 'int':
        return "{'type': 'integer'}";
      case 'double':
      case 'num':
        return "{'type': 'number'}";
      case 'String':
        return "{'type': 'string'}";
      case 'bool':
        return "{'type': 'boolean'}";
      case 'List':
        return "{'type': 'array', 'items': <String, dynamic>{}}";
      case 'Map':
      case 'dynamic':
        return "{'type': 'object'}";
      case 'DateTime':
        return "{'type': 'string', 'format': 'date-time'}";
      default:
        if (dartType.startsWith('List<') || dartType.startsWith('Map<')) {
          return "{'type': 'array'}";
        }
        return "{'type': 'object'}";
    }
  }

  Map<String, dynamic> _generateJsonMetadata(List<Map<String, dynamic>> tools) {
    final toolList = <Map<String, dynamic>>[];

    for (final t in tools) {
      final name = t['name'] as String;
      final params = t['parameters'] as List<Map<String, dynamic>>? ?? [];
      final properties = <String, dynamic>{};
      final required = <String>[];

      for (final p in params) {
        final externalName =
            (p['parameterMetadata']?['alias'] as String?) ??
            p['name'] as String;
        properties[externalName] = p['schemaMap'] ?? {'type': 'object'};
        if (p['isOptional'] != true) required.add(externalName);
      }

      toolList.add(<String, dynamic>{
        'name': name,
        'description': t['description'],
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      });
    }

    return <String, dynamic>{'schemaVersion': '1.0', 'tools': toolList};
  }

  /// Checks if the library has a @Server annotation.
  bool _hasServerAnnotation(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        return true;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        return true;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          return true;
        }
      }
    }

    return false;
  }

  bool _shouldGenerateJson(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateJson = reader.peek('generateJson');
        if (generateJson != null) {
          return generateJson.boolValue;
        }
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateJson = reader.peek('generateJson');
        if (generateJson != null) {
          return generateJson.boolValue;
        }
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final reader = ConstantReader(methodAnnotation);
          final generateJson = reader.peek('generateJson');
          if (generateJson != null) {
            return generateJson.boolValue;
          }
        }
      }
    }

    return false;
  }

  bool _shouldGenerateRest(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateRest = reader.peek('generateRest');
        if (generateRest != null) {
          return generateRest.boolValue;
        }
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateRest = reader.peek('generateRest');
        if (generateRest != null) {
          return generateRest.boolValue;
        }
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final reader = ConstantReader(methodAnnotation);
          final generateRest = reader.peek('generateRest');
          if (generateRest != null) {
            return generateRest.boolValue;
          }
        }
      }
    }

    return false;
  }

  bool _shouldGenerateMcp(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateMcp = reader.peek('generateMcp');
        if (generateMcp != null) {
          return generateMcp.boolValue;
        }
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final reader = ConstantReader(annotation);
        final generateMcp = reader.peek('generateMcp');
        if (generateMcp != null) {
          return generateMcp.boolValue;
        }
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final reader = ConstantReader(methodAnnotation);
          final generateMcp = reader.peek('generateMcp');
          if (generateMcp != null) {
            return generateMcp.boolValue;
          }
        }
      }
    }

    return true; // Default to true for backward compatibility
  }

  String _findTransport(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final transport = _extractTransportFromAnnotation(annotation);
        if (transport != null) return transport;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final transport = _extractTransportFromAnnotation(annotation);
        if (transport != null) return transport;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final transport = _extractTransportFromAnnotation(methodAnnotation);
          if (transport != null) return transport;
        }
      }
    }

    return 'stdio';
  }

  String? _extractTransportFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final transport = reader.peek('transport');
    if (transport != null) {
      // Try to read enum value by name first (more reliable)
      final transportObject = transport.objectValue;
      final type = transportObject.type;
      if (type != null) {
        final enumElement = type.element;
        if (enumElement is EnumElement) {
          // Get the enum field name from the object value
          for (final field in enumElement.constants) {
            final fieldName = field.name;
            if (fieldName == null) continue;
            final fieldValue = transportObject.getField(fieldName);
            if (fieldValue != null) {
              // This is the matching enum value
              if (fieldName == 'http') return 'http';
              if (fieldName == 'stdio') return 'stdio';
            }
          }
        }
      }
      // Fallback to index-based check
      final transportField = transportObject.getField('index');
      if (transportField != null) {
        final transportValue = transportField.toIntValue();
        if (transportValue == 1) return 'http';
      }
    }
    return null;
  }

  /// Finds the HTTP port from @Server annotations in the library.
  ///
  /// Searches through top-level functions, classes, and methods for @Server
  /// annotations and extracts the port parameter. This port determines
  /// which network port the HTTP server will listen on.
  ///
  /// Returns 3000 (the default port) if no port is explicitly specified
  /// in the annotation.
  int _findPort(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions for @Server annotation with port
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final port = _extractPortFromAnnotation(annotation);
        if (port != null) return port;
      }
    }

    // Check classes and their methods for @Server annotation with port
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final port = _extractPortFromAnnotation(annotation);
        if (port != null) return port;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final port = _extractPortFromAnnotation(methodAnnotation);
          if (port != null) return port;
        }
      }
    }

    return 3000; // Default port for HTTP transport
  }

  /// Extracts the port value from a @Server annotation.
  ///
  /// Returns null if the port field is not explicitly set in the annotation.
  /// The port determines which network port the HTTP server will listen on.
  int? _extractPortFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final portField = reader.peek('port');
    if (portField != null) {
      return portField.intValue;
    }
    return null;
  }

  /// Finds the HTTP bind address from @Server annotations in the library.
  ///
  /// Searches through top-level functions, classes, and methods for @Server
  /// annotations and extracts the address parameter. This address determines
  /// which network interface the HTTP server will bind to.
  ///
  /// Common address values:
  /// - '127.0.0.1' (default): Loopback interface, only accessible locally
  /// - '0.0.0.0': All interfaces, accessible from other machines (useful for Docker/containers)
  /// - Specific IP: Bind to a specific network interface
  ///
  /// Returns '127.0.0.1' if no address is explicitly specified.
  String _findAddress(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final address = _extractAddressFromAnnotation(annotation);
        if (address != null) return address;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final address = _extractAddressFromAnnotation(annotation);
        if (address != null) return address;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final address = _extractAddressFromAnnotation(methodAnnotation);
          if (address != null) return address;
        }
      }
    }

    return '127.0.0.1'; // Default address (loopback)
  }

  String? _extractAddressFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final addressField = reader.peek('address');
    if (addressField != null) {
      return addressField.stringValue;
    }
    return null;
  }

  /// Finds the tool prefix from @Server annotations in the library.
  ///
  /// Searches through top-level functions, classes, and methods for @Server
  /// annotations and extracts the toolPrefix parameter. This prefix is
  /// applied to all tool names in the generated MCP server.
  ///
  /// Returns null if no prefix is explicitly specified.
  String? _findToolPrefix(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final prefix = _extractToolPrefixFromAnnotation(annotation);
        if (prefix != null) return prefix;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final prefix = _extractToolPrefixFromAnnotation(annotation);
        if (prefix != null) return prefix;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final prefix = _extractToolPrefixFromAnnotation(methodAnnotation);
          if (prefix != null) return prefix;
        }
      }
    }

    return null; // No prefix specified
  }

  String? _extractToolPrefixFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final prefixField = reader.peek('toolPrefix');
    if (prefixField != null) {
      return prefixField.stringValue;
    }
    return null;
  }

  /// Finds the auto class prefix setting from @Server annotations in the library.
  ///
  /// Searches through top-level functions, classes, and methods for @Server
  /// annotations and extracts the autoClassPrefix parameter. When true,
  /// tool names are automatically prefixed with their class name.
  ///
  /// Returns false if no setting is explicitly specified.
  bool _findAutoClassPrefix(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final autoPrefix = _extractAutoClassPrefixFromAnnotation(annotation);
        if (autoPrefix != null) return autoPrefix;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final autoPrefix = _extractAutoClassPrefixFromAnnotation(annotation);
        if (autoPrefix != null) return autoPrefix;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final autoPrefix = _extractAutoClassPrefixFromAnnotation(
            methodAnnotation,
          );
          if (autoPrefix != null) return autoPrefix;
        }
      }
    }

    return false; // Default to false for backward compatibility
  }

  bool? _extractAutoClassPrefixFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final autoPrefixField = reader.peek('autoClassPrefix');
    if (autoPrefixField != null) {
      return autoPrefixField.boolValue;
    }
    return null;
  }

  bool _extractToolCodeMode(DartObject? toolAnnotation) {
    if (toolAnnotation == null) return true;
    final reader = ConstantReader(toolAnnotation);
    final codeModeField = reader.peek('codeMode');
    if (codeModeField != null && !codeModeField.isNull) {
      return codeModeField.boolValue;
    }
    return true; // Default to true
  }

  /// Extracts the `codeModeVisible` field from a `@Tool` annotation.
  ///
  /// When the enclosing `@Server` has `codeMode: true`, only tools with
  /// `codeModeVisible: true` are registered in the standard tools/list.
  /// Defaults to `false` so code mode hides standard tools by default.
  bool _extractToolCodeModeVisible(DartObject? toolAnnotation) {
    if (toolAnnotation == null) return false;
    final reader = ConstantReader(toolAnnotation);
    final field = reader.peek('codeModeVisible');
    if (field != null && !field.isNull) {
      return field.boolValue;
    }
    return false;
  }

  /// Finds the code mode setting from @Server annotations in the library.
  ///
  /// When true, the generated server includes `search` and `execute` tools
  /// that allow LLMs to discover and orchestrate multiple tool calls in a
  /// single JavaScript program.
  ///
  /// Returns false if not explicitly specified.
  bool _findCodeMode(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final codeMode = _extractCodeModeFromAnnotation(annotation);
        if (codeMode != null) return codeMode;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final codeMode = _extractCodeModeFromAnnotation(annotation);
        if (codeMode != null) return codeMode;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final codeMode = _extractCodeModeFromAnnotation(methodAnnotation);
          if (codeMode != null) return codeMode;
        }
      }
    }

    return false; // Default to false for backward compatibility
  }

  bool? _extractCodeModeFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final codeModeField = reader.peek('codeMode');
    if (codeModeField != null && !codeModeField.isNull) {
      return codeModeField.boolValue;
    }
    return null;
  }

  /// Finds the code mode timeout from @Server annotations in the library.
  ///
  /// Returns 30 if no timeout is explicitly specified.
  int _findCodeModeTimeout(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final timeout = _extractCodeModeTimeoutFromAnnotation(annotation);
        if (timeout != null) return timeout;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final timeout = _extractCodeModeTimeoutFromAnnotation(annotation);
        if (timeout != null) return timeout;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final timeout = _extractCodeModeTimeoutFromAnnotation(
            methodAnnotation,
          );
          if (timeout != null) return timeout;
        }
      }
    }

    return 30; // Default timeout
  }

  int? _extractCodeModeTimeoutFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final timeoutField = reader.peek('codeModeTimeout');
    if (timeoutField != null && !timeoutField.isNull) {
      return timeoutField.intValue;
    }
    return null;
  }

  /// Extracts the logErrors flag from the @Server annotation.
  bool _findLogErrors(LibraryElement library) {
    const mcpChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    // Check top-level functions
    for (final element in library.topLevelFunctions) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final value = _extractLogErrorsFromAnnotation(annotation);
        if (value != null) return value;
      }
    }

    // Check classes
    for (final element in library.classes) {
      final annotation = mcpChecker.firstAnnotationOf(element);
      if (annotation != null) {
        final value = _extractLogErrorsFromAnnotation(annotation);
        if (value != null) return value;
      }
      // Check methods within classes
      for (final method in element.methods) {
        final methodAnnotation = mcpChecker.firstAnnotationOf(method);
        if (methodAnnotation != null) {
          final value = _extractLogErrorsFromAnnotation(methodAnnotation);
          if (value != null) return value;
        }
      }
    }

    return false; // Default to false
  }

  bool? _extractLogErrorsFromAnnotation(DartObject annotation) {
    final reader = ConstantReader(annotation);
    final field = reader.peek('logErrors');
    if (field != null && !field.isNull) {
      return field.boolValue;
    }
    return null;
  }
}

Builder mcpBuilder(BuilderOptions options) => McpBuilder();
