# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.2] - 2026-05-25

### Changed
- Renamed the AI agent skill from `easy_mcp_add-server-annotations` to
  `easy_mcp_add-api-annotations` to reflect the broader scope of the package
  (MCP, REST, CLI, prompts).

## [1.2.1] - 2026-05-25

### Changed
- Updated the skill (`skills/easy_mcp_add-server-annotations/SKILL.md`) to
  document the full annotation surface: `@Prompt` and `@PromptArgument` for MCP
  prompts, `generateCli` for CLI application generation, `corsOrigins` for HTTP
  transport CORS configuration, `@Parameter(alias:)` for external name mapping,
  and `@Parameter(maxLength:)` for string length validation.

## [1.2.0] - 2026-05-25

### Added
- New `generateCli` field on `@Server` (default `false`). When `true`,
  `easy_api_generator` emits a fourth artifact, `<source>.cli.dart`, a
  runnable command-line application that exposes annotated `@Tool` methods
  as `package:args` `CommandRunner` subcommands. See the generator
  CHANGELOG for the full feature list.
- Added `args: ^2.7.0` as a runtime dependency so the generated CLI
  application can compile against the same version of `package:args`
  that the annotations package vendors.

## [1.1.0] - 2026-05-20

### Added
- Added `@Prompt` annotation for marking methods as MCP prompt templates.
  Prompts are user-invoked templates that generate structured messages for
  interacting with language models (e.g., as slash commands).
- Added `@PromptArgument` annotation for providing rich metadata on prompt
  arguments, including custom names, titles, descriptions, and requirement status.
- Added `PromptResult` class for returning prompt messages from @Prompt methods.
- Added `PromptMessage` class representing a single message with a role and content.
- Added `PromptRole` enum with `user` and `assistant` values.
- Added sealed `PromptContent` class hierarchy:
  - `TextPromptContent` for plain text messages
  - `ImagePromptContent` for base64-encoded images
  - `AudioPromptContent` for base64-encoded audio
  - `ResourcePromptContent` for embedded server resources
- Added comprehensive DartDoc comments with examples for all prompt types.

## [1.0.0] - 2026-05-08

First stable release. The annotation surface is now considered API-stable;
future breaking changes will follow semver.

### Added
- Added `ToolAnnotations` class for describing tool behavior to MCP clients via
  hint properties: `title`, `readOnlyHint`, `destructiveHint`, `idempotentHint`,
  and `openWorldHint`. Clients can use these hints to auto-approve safe
  read-only calls or prompt for confirmation on destructive operations.
- Added `Tool.annotations` field for attaching `ToolAnnotations` to individual
  tools.
- Added `Server.annotationsDefault` field for server-wide default annotation
  hints. The 4 boolean hints cascade from server defaults to every generated
  tool; tool-level values take precedence for the same key, and `title` is
  never inherited (it is intentionally tool-specific).
- Documented `ToolAnnotations` merge semantics in DartDoc with worked examples.

### Changed
- Bumped package version to 1.0.0 to signal API stability.
- Expanded `@Tool` DartDoc with `annotations` parameter usage examples.

## [0.6.0] - 2026-04-30

### Added
- Added canonical `lib/easy_api_annotations.dart` entry point that re-exports `mcp_annotations.dart`. Consumers can now use the conventional `import 'package:easy_api_annotations/easy_api_annotations.dart'` — the legacy `mcp_annotations.dart` import still works.

### Changed
- Clarified the `Parameter.sensitive` dartdoc to describe the concrete effect in generated artifacts (— `x-sensitive` + `format: 'password'` in `.mcp.json`, `writeOnly: true` + `format: 'password'` in `.openapi.json`). Previously the docstring promised masking behavior the generator did not actually implement.
- **Renamed `@Mcp` annotation to `@Server`** — new primary annotation name
- Renamed `generateOpenApi` parameter to `generateRest`
- Added `generateMcp` parameter (default: true)
- Added `generateRest` parameter (default: false)
- Marked `@Server`, `@Tool`, and `@Parameter` as `@immutable` to document intent and catch accidental mutation
- Lowered SDK constraint to `^3.9.0` to match `easy_api_generator`
- Fixed doc mismatch on `@Server.address` default (it is `'127.0.0.1'`, not `'localhost'`)

### Removed
- Dropped the unused direct `analyzer` dependency — the annotations package no longer pulls analyzer into consumer projects
- Removed the public `package:easy_api_annotations/stubs.dart` library; it was dead code and shipped types that duplicated `package:meta`
- Removed the long-deprecated `Tool.execution` field (was a raw `Map<String, Object?>?` reserved for a future feature)

### Deprecated
- `@Mcp` typedef — still available for backward compatibility, emits deprecation warning

## [0.5.0] - 2026-04-18

### Added
- Added `generateOpenApi` parameter to `@Mcp` annotation for OpenAPI 3.0 specification generation
- Comprehensive DartDoc for the new parameter

## [0.4.2] - 2026-04-15

### Changed
- Updated README with absolute logo URL for pub.dev compatibility
- Added Buy Me a Coffee image button
- Added reference to easy_api_generator package in installation section

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