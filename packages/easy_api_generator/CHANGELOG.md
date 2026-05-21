# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-05-21

### Security

#### Critical
- **Temporary Directory Hardening**: Enhanced code mode sandbox temporary directory creation with unpredictable naming using timestamp + cryptographically secure random suffix (`mcp_sandbox_{timestamp}_{random}_`). Prevents symlink attacks by making directory names unpredictable. Added `dart:math` import for `Random.secure()` in both stdio and HTTP templates.

## [1.1.0] - 2026-05-20

### Added
- Added MCP Prompts support — the third MCP capability alongside Tools and Resources.
  Servers can now expose parameterized prompt templates that users invoke explicitly
  (e.g., as slash commands) to generate structured LLM messages.
- Added `@Prompt` and `@PromptArgument` annotation extraction in the builder.
  Prompts are extracted from annotated methods alongside tools, with full support
  for argument metadata (custom names, titles, descriptions, requirement status).
- Generated servers now declare `PromptsCapability` when prompts are present,
  enabling the `prompts/list` and `prompts/get` JSON-RPC methods.
- Generated prompt handlers automatically:
  - Return prompt metadata with arguments for `prompts/list`
  - Call the user's prompt method and convert `PromptResult` to MCP messages for `prompts/get`
  - Support all content types: text, image, audio, and embedded resources
- `.mcp.json` metadata now includes a `prompts` array when prompts are defined,
  with name, title, description, and arguments for each prompt.
- Added example prompt class in `example/lib/src/example_prompts.dart` demonstrating
  code review, documentation generation, and code explanation prompts.

### Security

#### Critical
- **Node.js Sandbox Hardening**: Added `--no-addons` and `--frozen-intrinsics` flags to code mode sandbox execution. Prevents native module loading and prototype pollution attacks in the JavaScript sandbox environment.
- **Prompt Argument Validation**: Added 10,000 character length limit on prompt argument values with proper error handling. Prevents potential denial-of-service through excessively long inputs. All prompt handlers now include try-catch blocks with generic error messages.
- **Temporary Directory Security**: Enhanced temporary directory creation with unpredictable naming (timestamp + cryptographically secure random suffix) to prevent symlink attacks. Directory names now follow pattern `mcp_sandbox_{timestamp}_{random}_` instead of predictable `mcp_code_mode_` prefix.
- **Temporary File Security**: Set restrictive file permissions (700 for directories, 600 for files) on Linux/macOS systems. Prevents other users from reading sandbox code and tool information from temporary files.

#### High  
- **Input Length Validation**: Added maximum length limits across all inputs:
  - Tool names: 64 characters
  - Tool descriptions: 500 characters
  - Prompt arguments: 1,000 characters
  - Code mode JavaScript: 10,000 characters
  - Search queries: 500 characters
  
- **Regex Pattern Validation (ReDoS Prevention)**: Added validation for `@Parameter(pattern:)` values to prevent Regular Expression Denial of Service attacks. Detects:
  - Nested quantifiers: `(a+)+`, `(a*)*`
  - Overlapping alternation: `(a|a)+`
  - Catastrophic backtracking via timeout testing (100ms threshold)

#### Medium
- **Configurable CORS Origins**: Added `corsOrigins` parameter to `@Server` annotation for HTTP transport. Defaults to `['*']` for backward compatibility. Production deployments can now restrict to specific origins to prevent CSRF attacks.
- **Safe PORT Parsing**: Changed PORT environment variable parsing from `int.parse()` to `int.tryParse()` with fallback to configured port. Prevents server crashes from malformed PORT values.
- **Graceful Process Shutdown**: Changed Node.js sandbox termination from immediate SIGKILL to graceful SIGTERM with 2-second timeout before SIGKILL. Allows proper cleanup and prevents orphaned processes.
- **Generator Bug Fixes**: Fixed critical template bugs causing compilation errors in generated servers:
  - Invalid CORS origin syntax (`<'*'>` → `<String>['*']`)
  - Const expression violation in CORS headers
  - Null safety violation in code mode process shutdown
  - Missing imports for prompt source files

### Tests
- Added 13 comprehensive security tests covering:
  - Node.js sandbox security flags
  - Input length validation for prompts, code mode, and search
  - CORS configuration (default and custom origins)
  - PORT environment variable safe parsing
  - Graceful process shutdown sequence
  - Temporary file permission setting
  - ReDoS pattern detection and rejection

### Fixed
- Fixed linter issues in templates:
  - Removed unused variables and constants
  - Fixed string quote style (double quotes → single quotes)
  - Fixed unused `escapedPattern` variable in validation code

## [1.0.2] - 2026-05-20

### Fixed
- Generated MCP tool handlers now properly serialize `Map<String, dynamic>` return types using `jsonEncode()` instead of `.toString()`. Previously, tools returning maps (e.g., from `response.toJson()`) produced invalid JSON output like `{key: value}` instead of `{"key": "value"}`. The `_serializeResult` function in both stdio and HTTP templates now includes a `Map` type check that mirrors the OpenAPI builder's behavior.

## [1.0.1] - 2026-05-19

### Security
- `registerTool(...)` interpolation in both stdio and HTTP templates now
  routes the tool `name` and `description` through `_escapeDartString`, so
  doc comments containing apostrophes, `$`, or backslashes can no longer
  break the generated Dart literal or trigger unintended string
  interpolation. (M1)
- Added identifier validation for user-supplied annotation values that
  flow into generated source: `@Tool(name:)`, `@Server(toolPrefix:)`, and
  `@Parameter(alias:)` must now match `^[a-zA-Z_][a-zA-Z0-9_]*$`. The
  builder raises an `InvalidGenerationSourceError` otherwise. This closes
  a source-injection vector in both the generated Dart member references
  (`_$name`) and the Code Mode JS wrapper's `external_<toolName>` helpers.
  (M2 / transitively M3)

### Documentation
- Added a "Security & Operational Caveats" section to the package README
  covering: (a) the interaction between `@Server(logErrors: true)` and
  `@Parameter(sensitive: true)` — `sensitive` is a transport/UI hint and
  does not redact local stderr — and (b) the trust model of Code Mode,
  clarifying that the Node.js subprocess is a *resource* sandbox bounded
  by `--max-old-space-size=64` and `codeModeTimeout`, not a security
  boundary. (L1, L2)

### Fixed
- Generated MCP tool handlers now preserve the original Dart-type
  nullability of each parameter and re-emit any default-value expression.
  Previously every optional parameter was cast as `Type?`, which broke AOT
  compilation when the underlying method declared an optional non-nullable
  parameter with a default (e.g. `[String greeting = 'hi']`). The builder
  now captures `isNullable` and `defaultValueCode` from the analyzer
  (`_extractParametersFromElement` in `mcp_builder.dart`) and the stdio /
  HTTP templates render the appropriate cast: required params keep their
  original nullability, optional + nullable params cast as `Type?`, and
  optional + non-nullable params with defaults emit
  `(arguments?['x'] as Type?) ?? defaultLiteral` so the call site sees a
  non-nullable value.

## [1.0.0] - 2026-05-08

First stable release. Pairs with `easy_api_annotations` 1.0.0 and targets
`dart_mcp` ≥ 0.5.0.

### Added
- Generator support for `ToolAnnotations` from `easy_api_annotations` 1.0.0.
  Per-tool `@Tool(annotations: ToolAnnotations(...))` and server-wide
  `@Server(annotationsDefault: ToolAnnotations(...))` are now emitted as
  `ToolAnnotations(...)` expressions in both the generated stdio and HTTP
  `.mcp.dart` templates.
- Added `_extractToolAnnotations`, `_extractAnnotationsDefault`, and
  `_mergeAnnotations` helpers in `McpBuilder` that resolve per-tool and
  server-wide annotation hints and merge them per the documented rules
  (tool-level overrides server defaults; `title` is never inherited).
- Added `_generateAnnotationsExpression` helper in `templates.dart` that
  emits only the non-null hint fields, producing minimal, readable
  `ToolAnnotations(...)` literals in generated code.

### Fixed
- Hardened `_extractToolAnnotations` against a non-string `title` field:
  `DartObject.toStringValue()` can legally return `null` even when the field
  itself is non-null, so the extractor now guards the result and never stores
  `null` under the `'title'` key (which would later fail an `as String` cast
  during code generation).
- The generated `_runCodeSandbox` method now uses null-safe cleanup
  (`process?.kill(...)` and `await tempDir?.delete(...)`) in its `finally`
  block, preventing `NoSuchMethodError` / `FileSystemException` when an
  exception is thrown before those locals are assigned, or when the outer
  `catch` already cleaned up the temp directory.

### Changed
- Bumped package version to 1.0.0 to signal API stability.
- Targets `easy_api_annotations` 1.0.0 as the companion annotation package.

## [0.6.1] - 2026-05-01

### Fixed
- Schema code generation for `double`/`num` parameters now emits `Schema.num(...)` to match `dart_mcp` ≥ 0.5.0 (previously emitted non-existent `Schema.number(...)`, which caused `Error: Member not found: 'Schema.number'` at compile time in generated `.mcp.dart` files). Also added a dedicated `'num'` case to `SchemaBuilder.fromType` and updated `fromSchemaMap` plus the `_applyMetadataToSchema` regex accordingly.

## [0.6.0] - 2026-04-30

### Added
- Added canonical `lib/easy_api_generator.dart` entry point that re-exports `mcp_generator.dart`. Consumers can now use the conventional `import 'package:easy_api_generator/easy_api_generator.dart'` — the legacy `mcp_generator.dart` import still works.
- REST template now honors `@Server(logErrors:)`, mirroring the MCP templates: detailed exceptions + stack traces go to `stderr` when `logErrors: true`, while the 500 response body stays generic. Previously the REST template silently swallowed caught exceptions, leaving operators with no diagnostic signal.
- `@Parameter(sensitive: true)` is now actually emitted: `.mcp.json` inputSchema adds `"x-sensitive": true` on the property, `.openapi.json` adds `writeOnly: true`, and string-typed sensitive parameters also get `format: 'password'`. Previously the flag was extracted but never written anywhere.

### Changed
- **Renamed `@Mcp` to `@Server`** — generator now recognizes `@Server` as the primary annotation
- Renamed `generateOpenApi` parameter to `generateRest`
- Added `generateMcp` parameter (default: true) to control .mcp.dart generation
- Added `generateRest` parameter (default: false) to control .openapi.json generation
- Consolidated the 12 per-field `@Server` annotation scans in `McpBuilder` into a single `_extractServerConfig` AST walk; the library is now traversed once per build instead of 12 times
- Removed the dead `_dartTypeToJsonSchema` helper and its unread `'schema'` entry from the collected parameter maps; callers already rely on the richer `schemaMap` produced by `_introspectType`
- `SchemaBuilder` and `OpenApiBuilder` now expose private constructors (pure static helpers — not meant to be instantiated)
- Enabled strict analyzer modes (`strict-casts`, `strict-inference`, `strict-raw-types`) and added `always_declare_return_types`, `always_use_package_imports`, `avoid_catches_without_on_clauses`, `unawaited_futures` lints

### Removed
- **BREAKING:** Removed `lib/stubs.dart` — obsolete re-export layer; `package:build` is already a direct dependency
- **BREAKING:** Removed `lib/builder/doc_extractor.dart` along with the unused public classes `ToolInfo`, `ParameterInfo`, and `DocExtractor` — these were never wired into the builder after the full analyzer integration landed
- Deleted the placeholder `test/mcp_builder_test.dart` that only asserted `expect(true, isTrue)`
- Dropped unused `code_builder` and `json_annotation` direct dependencies

### Deprecated
- `@Mcp` typedef — still recognized for backward compatibility

## [0.5.0] - 2026-04-18

### Added
- OpenAPI 3.0 specification generation with `generateOpenApi: true` parameter
- RESTful API endpoint mapping following Swagger best practices
- Automatic resource inference from tool names (e.g., `createUser` → `POST /users`)
- Full request/response schema generation with validation
- Proper HTTP status codes (200, 201, 204, 400, 404)
- `OpenApiBuilder` class for transforming MCP tools to OpenAPI specs

## [0.4.2] - 2026-04-15

### Changed
- Updated README with absolute logo URL for pub.dev compatibility
- Added Buy Me a Coffee image button
- Updated version references to 0.4.2

## [0.4.1] - 2026-04-15

### Fixed
- Fixed method name resolution when `autoClassPrefix` is enabled
- Method calls now correctly use original method names instead of prefixed tool names
- Example: `UserStore.createUser()` instead of `UserStore.UserStore_createUser()`

## [0.4.0] - 2026-04-15

### Added
- Added support for `autoClassPrefix` parameter on `@Mcp` annotation
- Generator now automatically prefixes tool names with class name when enabled
- Supports combining `autoClassPrefix` with `toolPrefix` for flexible naming
- Updated documentation with examples for all naming options

## [0.3.0] - 2026-04-15

### Added
- Added support for custom tool names via `@Tool.name` parameter
- Added support for tool name prefixes via `@Mcp.toolPrefix` parameter
- Generator now uses custom names and applies prefixes when generating tool definitions
- Updated documentation with examples for custom tool naming

## [0.2.2] - 2026-04-14

### Fixed
- Fixed example link to use absolute GitHub URL instead of relative path

## [0.2.1] - 2026-04-14

### Fixed
- Updated repository and homepage URLs to point to package-specific directories

## [0.2.0] - 2026-04-14

### Added
- Added support for `@Parameter` annotation for rich parameter metadata
  - Extracts `title`, `description`, `example` for documentation
  - Supports validation constraints: `minimum`, `maximum`, `pattern`, `enumValues`
  - Supports `sensitive` flag for marking sensitive data
- Added support for `port` parameter in HTTP transport configuration
- Added support for `address` parameter in HTTP transport configuration
- Added `generateJson` parameter to control `.mcp.json` metadata file generation
- HTTP server now uses `io.InternetAddress.loopbackIPv4` for default address (127.0.0.1)
- Conditional import of `dart:io` only when needed for HTTP transport
- Updated documentation with HTTP transport and `@Parameter` examples

### Security
- Fixed information leakage in generated code - error messages no longer expose internal exception details
- Generated error responses now return generic "An error occurred while processing the request." message
- Added proper string escaping for regex patterns and special characters

### Fixed
- Fixed unused import warning for `dart:io` in generated HTTP server code
- Fixed annotation extraction to use `peek()` instead of `read()` for optional fields
- Fixed complex schema corruption when applying metadata
- Fixed dollar sign escaping in generated strings for regex patterns

## [0.1.2] - 2026-04-13
### Fixed
- Widen analyzer constraint to support latest versions
- Add example for package usage
- Fix lint issues and improve pana score

## [0.1.0] - 2026-04-13
### Added
- Initial release of mcp_generator package
- Build runner generator for @tool annotations
- AST-based parsing using dart:analyzer and source_gen
- Support for both stdio (JSON-RPC) and HTTP (Shelf) transports
- Automatic JSON-Schema generation from Dart types
- Dynamic method dispatch in generated servers
- Template-based code generation with StdioTemplate and HttpTemplate
- Doc comment extraction for tool descriptions