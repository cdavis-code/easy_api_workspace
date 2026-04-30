# Changelog

All notable changes to this project will be documented in this file.

## [0.6.0] - Unreleased

### Changed
- **Renamed `@Mcp` to `@Server`** — the primary annotation for defining server configuration
- Renamed `generateOpenApi` parameter to `generateRest`
- Added `generateMcp` parameter (default: true) to control .mcp.dart generation
- Added `generateRest` parameter (default: false) to control .openapi.json generation

### Deprecated
- `@Mcp` typedef — still works but emits a deprecation warning. Use `@Server` instead.

## [0.5.0] - 2026-04-14

### Added
- **Code Mode** - Batch tool orchestration via sandboxed Node.js subprocess
  - `codeMode` parameter on `@Mcp` to enable `execute_code` tool generation
  - `codeModeTimeout` parameter to set max execution time (default: 30s)
  - `codeMode` parameter on `@Tool` to exclude tools from batch orchestration
  - JavaScript sandbox with JSON-lines IPC protocol (`external_*` async functions)
  - Memory limits (`--max-old-space-size=64`) and timeout enforcement
  - Process isolation with temporary directories cleanup
- **OpenAPI 3.0 Specification Generation**
  - `generateOpenApi` parameter on `@Mcp` for RESTful spec generation
  - Smart REST-to-MCP mapping (resource-based URLs, proper HTTP methods)
  - OpenApiBuilder class for spec generation
- **Multi-library Tool Aggregation** - Automatically aggregates tools from imported libraries
- **Rich Tool Naming** - Custom tool names via `@Tool(name:)`, prefixes via `@Mcp(toolPrefix:, autoClassPrefix:)`
- **Sensitive Parameter Support** - `sensitive` field on `@Parameter` for masking sensitive data
- **Enum Validation** - `enumValues` field on `@Parameter` for restricting values

### Changed
- Generator now fully integrated with `build_runner` and `source_gen`
- Internal error details are never exposed in generated code (uses generic error messages)

### Fixed
- Special character escaping in generated strings (backslashes, dollar signs, quotes)

## [0.4.0] - 2026-04-13

### Added
- Multi-library tool aggregation - tools imported from other files are included
- Full `build_runner` integration with `source_gen` for reliable code generation
- `.openapi.json` output with resource-based REST endpoints
- HTTP method mapping (GET, POST, PATCH, DELETE) based on tool semantics
- Generated code now uses `Schema.object()` / `Schema.string()` from `dart_mcp`

## [0.3.0] - 2026-04-12

### Added
- `@Tool(name:)` parameter for custom tool names
- `@Mcp(toolPrefix:)` for domain-based tool naming
- `@Mcp(autoClassPrefix:)` for automatic class name prefixes
- `@Parameter(sensitive:)` for marking sensitive data
- `@Parameter(enumValues:)` for enum-like parameter restrictions
- Tool naming hierarchy: method name → custom name → class prefix → tool prefix

## [0.2.0] - 2026-04-12

### Added
- `@Parameter` annotation for rich parameter metadata (title, description, example, min, max, pattern)
- HTTP transport configuration: `port` and `address` parameters on `@Mcp`
- `generateJson` parameter for optional `.mcp.json` metadata generation
- `SchemaBuilder` for generating `dart_mcp` Schema expressions with metadata

### Changed
- Renamed to `easy_api_annotations` and `easy_api_generator` packages
- Published easy_api_annotations 0.2.0 to pub.dev

## [0.1.0] - 2026-04-12

### Added
- `mcp_annotations` package with:
  - `@mcp` annotation with `transport` parameter (stdio/http)
  - `@tool` annotation with optional `description`, `icons`, `execution` parameters
  - `McpTransport` enum for type-safe transport selection
- `mcp_generator` package with:
  - Stub builder for code generation
  - DocExtractor for doc comment parsing
  - JSON-Schema generation
  - StdioTemplate and HttpTemplate for server generation
- Specification files under `specs/001-mcp-annotations/`
- Complete task list for implementation

### Known Limitations
- Generator uses stub implementations; full `build_runner` integration pending
- `execution` parameter on `@tool` is deprecated (future feature)
- Icons are stored but not validated for HTTPS URLs in this version