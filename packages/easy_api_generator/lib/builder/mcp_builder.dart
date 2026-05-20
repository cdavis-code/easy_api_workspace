import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:easy_api_generator/builder/templates.dart';
import 'package:easy_api_generator/builder/openapi_builder.dart';
import 'package:easy_api_generator/builder/openapi_dart_template.dart';

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

    // Single pass: find the first @Server annotation in the library and
    // resolve every field we care about. Returns null when the library
    // carries no @Server (or deprecated @Mcp typedef).
    final config = _extractServerConfig(library);
    if (config == null) return;

    // Aggregate tools from this library AND all its package-local imports
    final tools = await _extractAllTools(
      library,
      config.toolPrefix,
      config.autoClassPrefix,
      config.annotationsDefault,
    );

    if (tools.isEmpty) return; // No tools found anywhere

    // Aggregate prompts from this library AND all its package-local imports
    final prompts = await _extractAllPrompts(library);

    // Conditionally generate MCP server code (gated by generateMcp flag)
    if (config.generateMcp) {
      // Generate the appropriate server code based on transport type
      final generated = config.transport == 'http'
          ? HttpTemplate.generate(
              tools,
              config.port,
              config.address,
              codeMode: config.codeMode,
              codeModeTimeout: config.codeModeTimeout,
              logErrors: config.logErrors,
              prompts: prompts,
              corsOrigins: config.corsOrigins,
            )
          : StdioTemplate.generate(
              tools,
              codeMode: config.codeMode,
              codeModeTimeout: config.codeModeTimeout,
              logErrors: config.logErrors,
              prompts: prompts,
            );

      // Write the generated server code
      await buildStep.writeAsString(
        inputId.changeExtension('.mcp.dart'),
        generated,
      );

      // Optionally generate JSON metadata file
      if (config.generateJson) {
        final jsonMetadata = _generateJsonMetadata(tools, prompts: prompts);
        await buildStep.writeAsString(
          inputId.changeExtension('.mcp.json'),
          jsonEncode(jsonMetadata),
        );
      }
    }

    // Conditionally generate REST/OpenAPI output (gated by generateRest flag)
    if (config.generateRest) {
      final openApiSpec = OpenApiBuilder.build(
        tools,
        config.transport,
        config.port,
        config.address,
      );
      await buildStep.writeAsString(
        inputId.changeExtension('.openapi.json'),
        const JsonEncoder.withIndent('  ').convert(openApiSpec),
      );

      // Generate .openapi.dart REST server
      final openApiDartCode = OpenApiDartTemplate.generate(
        tools,
        config.port,
        config.address,
        openApiSpec,
        logErrors: config.logErrors,
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
    Map<String, dynamic>? annotationsDefault,
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
      // Extract ToolAnnotations from @Tool annotation (optional)
      final toolAnnotationsMap = _extractToolAnnotations(toolAnnotation);

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
        'annotations': _mergeAnnotations(
          annotationsDefault,
          toolAnnotationsMap,
        ),
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
        // Extract ToolAnnotations from @Tool annotation (optional)
        final toolAnnotationsMap = _extractToolAnnotations(toolAnnotation);

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
          'annotations': _mergeAnnotations(
            annotationsDefault,
            toolAnnotationsMap,
          ),
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
    Map<String, dynamic>? annotationsDefault,
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
      annotationsDefault,
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
        annotationsDefault,
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
  ///
  /// User-supplied custom names are validated as identifiers because they are
  /// interpolated into generated Dart member references (`_$name`) and, in
  /// Code Mode, into JS function names. The `toolPrefix` is validated once at
  /// `_extractServerConfig` time, so we do not re-validate it here.
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
        _validateIdentifier(customName, '@Tool(name:)');
        toolName = customName;
      }
    }

    // Apply prefix if provided
    if (toolPrefix != null && toolPrefix.isNotEmpty) {
      toolName = '$toolPrefix$toolName';
    }

    return toolName;
  }

  /// Pattern for identifiers that are safe to interpolate into both Dart and
  /// JavaScript source: must start with a letter or underscore, followed by
  /// alphanumeric or underscore characters.
  ///
  /// Applied to user-supplied values that flow into generated source:
  /// `@Tool(name:)`, `@Server(toolPrefix:)`, `@Parameter(alias:)`.
  /// Class names (used by `autoClassPrefix`) and Dart member names are not
  /// re-validated because the Dart compiler already enforces this shape on
  /// them.
  static final RegExp _identifierPattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  /// Throws [InvalidGenerationSourceError] when [value] is not a safe
  /// identifier. Used to prevent source injection via annotation strings
  /// that are interpolated unescaped into generated Dart and JS code.
  void _validateIdentifier(String value, String context) {
    if (!_identifierPattern.hasMatch(value)) {
      throw InvalidGenerationSourceError(
        "Invalid $context value '$value': must match "
        r'/^[a-zA-Z_][a-zA-Z0-9_]*$/. '
        'easy_api_generator interpolates this value into generated Dart and '
        'JavaScript source, so non-identifier characters would break codegen '
        'or enable source injection. Pick a name that is a valid identifier '
        'in both languages.',
      );
    }
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
      // Preserve original Dart-type nullability so generated handlers can
      // emit the correct cast even for optional non-nullable parameters.
      final isNullable = typeString.endsWith('?');
      // Source text of the default value expression, or null when absent.
      final defaultValueCode = param.defaultValueCode;

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
        'isNullable': isNullable,
        'defaultValueCode': defaultValueCode,
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
      final aliasValue = alias.stringValue;
      // Aliases are interpolated into generated Dart string literals as JSON
      // keys; validating them as identifiers keeps generated code well-formed
      // and forbids source injection through quotes/backslashes/dollar signs.
      _validateIdentifier(aliasValue, '@Parameter(alias:)');
      metadata['alias'] = aliasValue;
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

    // Extract maxLength
    final maxLength = reader.peek('maxLength');
    if (maxLength != null && !maxLength.isNull && maxLength.isInt) {
      metadata['maxLength'] = maxLength.intValue;
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

  /// Extracts prompts from a library (top-level functions and class methods).
  Future<List<Map<String, dynamic>>> _extractPromptsFromLibrary(
    LibraryElement library,
  ) async {
    final prompts = <Map<String, dynamic>>[];
    const promptChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Prompt',
    );
    const promptArgumentChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#PromptArgument',
    );

    // Top-level functions
    for (final element in library.topLevelFunctions) {
      final promptAnnotation = promptChecker.firstAnnotationOf(element);
      if (promptAnnotation == null) continue;

      final promptData = _extractPromptData(
        promptAnnotation,
        element,
        promptArgumentChecker,
      );
      if (promptData != null) {
        prompts.add(promptData);
      }
    }

    // Class methods
    for (final element in library.classes) {
      for (final method in element.methods) {
        final promptAnnotation = promptChecker.firstAnnotationOf(method);
        if (promptAnnotation == null) continue;

        final promptData = _extractPromptData(
          promptAnnotation,
          method,
          promptArgumentChecker,
          className: element.name,
          isStatic: method.isStatic,
        );
        if (promptData != null) {
          prompts.add(promptData);
        }
      }
    }

    return prompts;
  }

  /// Extracts prompt metadata from a single annotated method.
  Map<String, dynamic>? _extractPromptData(
    DartObject? promptAnnotation,
    ExecutableElement element,
    TypeChecker promptArgumentChecker, {
    String? className,
    bool isStatic = false,
  }) {
    final reader = ConstantReader(promptAnnotation);

    // Extract name
    String promptName;
    final nameField = reader.peek('name');
    if (nameField != null && nameField.isString) {
      final customName = nameField.stringValue;
      if (customName.isNotEmpty) {
        _validateIdentifier(customName, '@Prompt(name:)');
        promptName = customName;
      } else {
        promptName = element.name ?? 'unnamed';
      }
    } else {
      promptName = element.name ?? 'unnamed';
    }

    // Extract title
    String? title;
    final titleField = reader.peek('title');
    if (titleField != null && titleField.isString) {
      title = titleField.stringValue;
    }

    // Extract description
    String description;
    final descField = reader.peek('description');
    if (descField != null && descField.isString) {
      description = descField.stringValue;
    } else if (element.documentationComment != null &&
        element.documentationComment!.isNotEmpty) {
      description = _stripDocComment(element.documentationComment!);
    } else {
      description = 'Prompt $promptName';
    }

    // Extract arguments from parameters
    final arguments = <Map<String, dynamic>>[];
    for (final param in element.formalParameters) {
      final typeString = _getTypeString(param.type);
      final isOptional = !param.isRequired;
      final isNamedParam = param.isNamed;
      final isNullable = typeString.endsWith('?');

      // Extract @PromptArgument annotation if present
      final argumentMetadata = _extractPromptArgumentMetadata(
        param,
        promptArgumentChecker,
      );

      // Determine if required (from annotation or inferred from nullability)
      final required =
          argumentMetadata != null && argumentMetadata.containsKey('required')
          ? argumentMetadata['required'] as bool
          : !isNullable;

      final argName =
          argumentMetadata != null && argumentMetadata.containsKey('alias')
          ? argumentMetadata['alias'] as String
          : param.name;

      arguments.add(<String, dynamic>{
        'name': argName,
        'dartName': param.name,
        'type': typeString,
        'isNullable': isNullable,
        'isOptional': isOptional,
        'isNamed': isNamedParam,
        'required': required,
        'title': argumentMetadata?['title'],
        'description': argumentMetadata?['description'],
      });
    }

    final isAsync = element.returnType.isDartAsyncFuture;

    return <String, dynamic>{
      'name': promptName,
      'methodName': element.name ?? 'unnamed',
      'title': title,
      'description': description,
      'arguments': arguments,
      'isAsync': isAsync,
      'className': className,
      'isStatic': isStatic,
    };
  }

  /// Extracts metadata from a @PromptArgument annotation on a parameter.
  Map<String, dynamic>? _extractPromptArgumentMetadata(
    FormalParameterElement param,
    TypeChecker promptArgumentChecker,
  ) {
    final annotation = promptArgumentChecker.firstAnnotationOf(param);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    final metadata = <String, dynamic>{};

    // Extract alias
    final alias = reader.peek('alias');
    if (alias != null && !alias.isNull && alias.isString) {
      final aliasValue = alias.stringValue;
      _validateIdentifier(aliasValue, '@PromptArgument(alias:)');
      metadata['alias'] = aliasValue;
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

    // Extract required
    final required = reader.peek('required');
    if (required != null && !required.isNull && required.isBool) {
      metadata['required'] = required.boolValue;
    }

    return metadata.isEmpty ? null : metadata;
  }

  /// Extracts prompts from the current library and all package-local imports.
  Future<List<Map<String, dynamic>>> _extractAllPrompts(
    LibraryElement library,
  ) async {
    final allPrompts = <Map<String, dynamic>>[];
    final aliasCounts = <String, int>{};

    // Get the current library's package name
    final currentPackageUri = library.uri.toString();
    final packageName = _extractPackageName(currentPackageUri);

    // Extract prompts from the current library
    final currentLibPrompts = await _extractPromptsFromLibrary(library);
    final currentAlias = _deriveAlias(currentPackageUri);
    for (final prompt in currentLibPrompts) {
      prompt['sourceImport'] = currentPackageUri;
      prompt['sourceAlias'] = currentAlias;
      allPrompts.add(prompt);
    }

    // Scan imported libraries for prompts
    final importedLibraries = library.firstFragment.importedLibraries;
    for (final importedLib in importedLibraries) {
      final importedUri = importedLib.uri.toString();

      // Skip non-package URIs
      if (!importedUri.startsWith('package:')) continue;

      // Skip libraries from other packages
      final importedPackageName = _extractPackageName(importedUri);
      if (importedPackageName != packageName) continue;

      // Extract prompts from this imported library
      final importedPrompts = await _extractPromptsFromLibrary(importedLib);
      if (importedPrompts.isEmpty) continue;

      // Derive alias and ensure uniqueness
      var alias = _deriveAlias(importedUri);
      final count = aliasCounts[alias] ?? 0;
      if (count > 0) {
        alias = '${alias}_$count';
      }
      aliasCounts[alias] = count + 1;

      for (final prompt in importedPrompts) {
        prompt['sourceImport'] = importedUri;
        prompt['sourceAlias'] = alias;
        allPrompts.add(prompt);
      }
    }

    return allPrompts;
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

  Map<String, dynamic> _generateJsonMetadata(
    List<Map<String, dynamic>> tools, {
    List<Map<String, dynamic>> prompts = const [],
  }) {
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
        // Clone so we don't mutate the shared schemaMap used by the Dart template.
        final baseSchema = Map<String, dynamic>.from(
          (p['schemaMap'] as Map<String, dynamic>?) ??
              <String, dynamic>{'type': 'object'},
        );
        final meta = p['parameterMetadata'] as Map<String, dynamic>?;
        if (meta != null && meta['sensitive'] == true) {
          // Surface sensitivity to MCP clients so they can mask values in UI/logs.
          // `x-sensitive` is a non-standard extension; `format: 'password'` is the
          // closest OpenAPI/JSON-Schema convention for string secrets.
          baseSchema['x-sensitive'] = true;
          if (baseSchema['type'] == 'string') {
            baseSchema['format'] = 'password';
          }
        }
        properties[externalName] = baseSchema;
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
        if (t['annotations'] != null) 'annotations': t['annotations'],
      });
    }

    // Generate prompt metadata
    final promptList = <Map<String, dynamic>>[];
    for (final p in prompts) {
      final name = p['name'] as String;
      final arguments = <Map<String, dynamic>>[];

      for (final arg in p['arguments'] as List<Map<String, dynamic>>) {
        arguments.add(<String, dynamic>{
          'name': arg['name'],
          if (arg['title'] != null) 'title': arg['title'],
          if (arg['description'] != null) 'description': arg['description'],
          'required': arg['required'],
        });
      }

      promptList.add(<String, dynamic>{
        'name': name,
        if (p['title'] != null) 'title': p['title'],
        'description': p['description'],
        if (arguments.isNotEmpty) 'arguments': arguments,
      });
    }

    return <String, dynamic>{
      'schemaVersion': '1.0',
      'tools': toolList,
      if (promptList.isNotEmpty) 'prompts': promptList,
    };
  }

  /// Walks the library's top-level functions, classes, and class methods
  /// looking for the first `@Server` annotation. Returns `null` if none is
  /// found. When an annotation is found, every field of [_ServerConfig] is
  /// resolved from it (falling back to documented defaults).
  ///
  /// Replaces a previous generation of per-field scan methods that each
  /// walked the AST independently. Traversing once is both simpler and
  /// avoids 12× redundant analyzer work per build.
  _ServerConfig? _extractServerConfig(LibraryElement library) {
    const serverChecker = TypeChecker.fromUrl(
      'package:easy_api_annotations/mcp_annotations.dart#Server',
    );

    DartObject? annotation;

    // Top-level functions
    for (final element in library.topLevelFunctions) {
      annotation = serverChecker.firstAnnotationOf(element);
      if (annotation != null) break;
    }

    // Classes + their methods
    if (annotation == null) {
      for (final element in library.classes) {
        annotation = serverChecker.firstAnnotationOf(element);
        if (annotation != null) break;
        for (final method in element.methods) {
          annotation = serverChecker.firstAnnotationOf(method);
          if (annotation != null) break;
        }
        if (annotation != null) break;
      }
    }

    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    final toolPrefix = _peekString(reader, 'toolPrefix');
    if (toolPrefix != null && toolPrefix.isNotEmpty) {
      _validateIdentifier(toolPrefix, '@Server(toolPrefix:)');
    }
    return _ServerConfig(
      transport: _readTransport(reader),
      port: _peekInt(reader, 'port') ?? 3000,
      address: _peekString(reader, 'address') ?? '127.0.0.1',
      toolPrefix: toolPrefix,
      autoClassPrefix: _peekBool(reader, 'autoClassPrefix') ?? false,
      generateJson: _peekBool(reader, 'generateJson') ?? false,
      generateMcp: _peekBool(reader, 'generateMcp') ?? true,
      generateRest: _peekBool(reader, 'generateRest') ?? false,
      codeMode: _peekBool(reader, 'codeMode') ?? false,
      codeModeTimeout: _peekInt(reader, 'codeModeTimeout') ?? 30,
      logErrors: _peekBool(reader, 'logErrors') ?? false,
      annotationsDefault: _extractAnnotationsDefault(reader),
      corsOrigins: _extractCorsOrigins(reader),
    );
  }

  /// Reads the `transport` enum field and maps it to the canonical
  /// `'stdio'` or `'http'` string used downstream. Uses the enum's `index`
  /// field because analyzer's `getField(name)` does not return the
  /// constant's symbolic name directly.
  String _readTransport(ConstantReader reader) {
    final transport = reader.peek('transport');
    if (transport == null) return 'stdio';
    final indexField = transport.objectValue.getField('index');
    if (indexField != null) {
      final index = indexField.toIntValue();
      // Keep in sync with `McpTransport` declaration order in
      // packages/easy_api_annotations/lib/mcp_annotations.dart.
      if (index == 1) return 'http';
    }
    return 'stdio';
  }

  String? _peekString(ConstantReader reader, String field) {
    final value = reader.peek(field);
    if (value == null || value.isNull || !value.isString) return null;
    return value.stringValue;
  }

  int? _peekInt(ConstantReader reader, String field) {
    final value = reader.peek(field);
    if (value == null || value.isNull || !value.isInt) return null;
    return value.intValue;
  }

  bool? _peekBool(ConstantReader reader, String field) {
    final value = reader.peek(field);
    if (value == null || value.isNull || !value.isBool) return null;
    return value.boolValue;
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

  /// Extracts the `annotations` field from a `@Tool` annotation.
  ///
  /// Returns a map with the non-null annotation hints (title, readOnlyHint,
  /// destructiveHint, idempotentHint, openWorldHint), or null if no
  /// annotations are specified.
  Map<String, dynamic>? _extractToolAnnotations(DartObject? toolAnnotation) {
    if (toolAnnotation == null) return null;
    final reader = ConstantReader(toolAnnotation);
    final annotationsField = reader.peek('annotations');
    if (annotationsField == null || annotationsField.isNull) return null;

    final annotationsObj = annotationsField.objectValue;
    final result = <String, dynamic>{};

    // Extract title
    final title = annotationsObj.getField('title');
    if (title != null && !title.isNull) {
      final titleValue = title.toStringValue();
      if (titleValue != null) {
        result['title'] = titleValue;
      }
    }

    // Extract readOnlyHint
    final readOnlyHint = annotationsObj.getField('readOnlyHint');
    if (readOnlyHint != null && !readOnlyHint.isNull) {
      result['readOnlyHint'] = readOnlyHint.toBoolValue();
    }

    // Extract destructiveHint
    final destructiveHint = annotationsObj.getField('destructiveHint');
    if (destructiveHint != null && !destructiveHint.isNull) {
      result['destructiveHint'] = destructiveHint.toBoolValue();
    }

    // Extract idempotentHint
    final idempotentHint = annotationsObj.getField('idempotentHint');
    if (idempotentHint != null && !idempotentHint.isNull) {
      result['idempotentHint'] = idempotentHint.toBoolValue();
    }

    // Extract openWorldHint
    final openWorldHint = annotationsObj.getField('openWorldHint');
    if (openWorldHint != null && !openWorldHint.isNull) {
      result['openWorldHint'] = openWorldHint.toBoolValue();
    }

    return result.isEmpty ? null : result;
  }

  /// Extracts the `annotationsDefault` field from a `@Server` annotation.
  ///
  /// Only the 4 boolean hints are extracted (title is excluded because it is
  /// tool-specific and should never be inherited from server defaults).
  Map<String, dynamic>? _extractAnnotationsDefault(ConstantReader reader) {
    final annotationsField = reader.peek('annotationsDefault');
    if (annotationsField == null || annotationsField.isNull) return null;

    final annotationsObj = annotationsField.objectValue;
    final result = <String, dynamic>{};

    // Extract readOnlyHint
    final readOnlyHint = annotationsObj.getField('readOnlyHint');
    if (readOnlyHint != null && !readOnlyHint.isNull) {
      result['readOnlyHint'] = readOnlyHint.toBoolValue();
    }

    // Extract destructiveHint
    final destructiveHint = annotationsObj.getField('destructiveHint');
    if (destructiveHint != null && !destructiveHint.isNull) {
      result['destructiveHint'] = destructiveHint.toBoolValue();
    }

    // Extract idempotentHint
    final idempotentHint = annotationsObj.getField('idempotentHint');
    if (idempotentHint != null && !idempotentHint.isNull) {
      result['idempotentHint'] = idempotentHint.toBoolValue();
    }

    // Extract openWorldHint
    final openWorldHint = annotationsObj.getField('openWorldHint');
    if (openWorldHint != null && !openWorldHint.isNull) {
      result['openWorldHint'] = openWorldHint.toBoolValue();
    }

    return result.isEmpty ? null : result;
  }

  /// Merges server-level annotation defaults with per-tool annotations.
  ///
  /// Tool-level values take precedence over server defaults for the same key.
  /// The `title` field from tool annotations is always preserved.
  /// Returns null only when both inputs are null.
  Map<String, dynamic>? _mergeAnnotations(
    Map<String, dynamic>? serverDefaults,
    Map<String, dynamic>? toolAnnotations,
  ) {
    if (serverDefaults == null && toolAnnotations == null) return null;
    if (serverDefaults == null) return toolAnnotations;
    if (toolAnnotations == null) {
      return Map<String, dynamic>.from(serverDefaults);
    }

    // Start with server defaults, overlay tool-level values
    final merged = Map<String, dynamic>.from(serverDefaults);
    for (final entry in toolAnnotations.entries) {
      merged[entry.key] = entry.value;
    }
    return merged;
  }

  /// Extracts CORS origins from @Server annotation.
  /// Returns ['*'] by default for backward compatibility.
  /// Validates that origins are well-formed URLs or the wildcard '*'.
  List<String> _extractCorsOrigins(ConstantReader reader) {
    final corsField = reader.peek('corsOrigins');
    if (corsField == null || corsField.isNull || !corsField.isList) {
      return ['*']; // Default for backward compatibility
    }

    final origins = corsField.listValue;
    if (origins.isEmpty) {
      return ['*'];
    }

    final validatedOrigins = origins
        .map((e) {
          final val = ConstantReader(e);
          if (!val.isString) return null;
          final origin = val.stringValue;

          // Validate origin format
          if (origin == '*') return origin; // Wildcard is valid

          // Must be a valid URL with http or https scheme
          final urlPattern = RegExp(
            r'^https?://[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*(:[0-9]+)?$',
          );
          if (!urlPattern.hasMatch(origin)) {
            throw ArgumentError(
              'Invalid CORS origin: "$origin". '
              'Origins must be valid URLs with http/https scheme (e.g., "https://example.com") '
              'or the wildcard "*".',
            );
          }

          return origin;
        })
        .whereType<String>()
        .toList();

    // Validate that '*' is not mixed with specific origins
    if (validatedOrigins.contains('*') && validatedOrigins.length > 1) {
      throw ArgumentError(
        'CORS origins cannot mix wildcard "*" with specific origins. '
        'Use either ["*"] for all origins or a list of specific origins.',
      );
    }

    return validatedOrigins.isEmpty ? ['*'] : validatedOrigins;
  }
}

/// Immutable view of the fields on a `@Server` annotation, resolved with
/// documented defaults. Populated by [McpBuilder._extractServerConfig] so the
/// rest of the builder never needs to re-scan the AST.
class _ServerConfig {
  const _ServerConfig({
    required this.transport,
    required this.port,
    required this.address,
    required this.toolPrefix,
    required this.autoClassPrefix,
    required this.generateJson,
    required this.generateMcp,
    required this.generateRest,
    required this.codeMode,
    required this.codeModeTimeout,
    required this.logErrors,
    required this.annotationsDefault,
    required this.corsOrigins,
  });

  final String transport;
  final int port;
  final String address;
  final String? toolPrefix;
  final bool autoClassPrefix;
  final bool generateJson;
  final bool generateMcp;
  final bool generateRest;
  final bool codeMode;
  final int codeModeTimeout;
  final bool logErrors;
  final Map<String, dynamic>? annotationsDefault;
  final List<String> corsOrigins;
}

Builder mcpBuilder(BuilderOptions options) => McpBuilder();
