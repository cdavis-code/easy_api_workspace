# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - Unreleased

### Changed
- **Renamed `@Mcp` to `@Server`** — generator now recognizes `@Server` as the primary annotation
- Renamed `generateOpenApi` parameter to `generateRest`
- Added `generateMcp` parameter (default: true) to control .mcp.dart generation
- Added `generateRest` parameter (default: false) to control .openapi.json generation

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