# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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