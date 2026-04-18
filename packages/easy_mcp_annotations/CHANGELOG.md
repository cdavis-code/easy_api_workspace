# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-04-18

### Added
- Added `generateOpenApi` parameter to `@Mcp` annotation for OpenAPI 3.0 specification generation
- Comprehensive DartDoc for the new parameter

## [0.4.2] - 2026-04-15

### Changed
- Updated README with absolute logo URL for pub.dev compatibility
- Added Buy Me a Coffee image button
- Added reference to easy_mcp_generator package in installation section

## [0.4.1] - 2026-04-15

### Added
- Added `autoClassPrefix` parameter documentation to SKILL.md
- Updated skill documentation with examples for all naming options

## [0.4.0] - 2026-04-15

### Added
- Added `autoClassPrefix` parameter to `@Mcp` annotation
- When enabled, tool names are automatically prefixed with their class name (e.g., `UserService_createUser`)
- Can be combined with `toolPrefix` for even more organization (e.g., `api_UserService_createUser`)
- Disabled by default for backward compatibility

## [0.3.0] - 2026-04-15

### Added
- Added `name` parameter to `@Tool` annotation for custom tool names
- Added `toolPrefix` parameter to `@Mcp` annotation for prefixing all tool names in a scope
- Updated documentation with examples for custom tool naming

## [0.2.2] - 2026-04-14

### Fixed
- Fixed example link to use absolute GitHub URL instead of relative path

## [0.2.1] - 2026-04-14

### Fixed
- Updated repository and homepage URLs to point to package-specific directories

## [0.2.0] - 2026-04-14

### Added
- Added `@Parameter` annotation for rich parameter metadata
  - Support for `title`, `description`, `example` fields
  - Support for validation constraints: `minimum`, `maximum`, `pattern`, `enumValues`
  - Support for `sensitive` flag to mark sensitive data
- Updated documentation with `@Parameter` usage examples
- Clarified that `@Parameter` annotation is optional

## [0.1.3] - 2026-04-14

### Added
- Added `port` parameter to `@Mcp` annotation for HTTP transport configuration
- Added `address` parameter to `@Mcp` annotation for HTTP bind address configuration
- Updated documentation with HTTP transport configuration examples

### Security
- Fixed dangling library doc comment to improve pana score

## [0.1.2] - 2026-04-13
### Added
- Added funding link to pubspec.yaml
- Added support section to README.md
- Fixed lint issues (unnecessary library name, camel case types)
- Updated test imports to use package: prefix
- Added analysis_options.yaml package

## [0.1.0] - 2026-04-13
### Added
- Initial release of mcp_annotations package
- @mcp annotation with transport parameter (stdio/http)
- @tool annotation with description, icons, and deprecated execution parameters
- McpTransport enum for specifying server transport type