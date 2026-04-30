# easy_api_workplace Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-28

## Active Technologies
- Dart 3.11+ (null-safe)
- MCP (Model Context Protocol) server generation
- Code generation via build_runner and source_gen
- AST analysis using dart:analyzer

## Project Structure

```text
packages/
├── easy_api_annotations/    # Annotations package (@Server, @Tool, @Parameter)
│   ├── lib/
│   │   ├── mcp_annotations.dart
│   │   └── stubs.dart
│   ├── example/
│   └── pubspec.yaml
├── easy_api_generator/      # Code generator package
│   ├── lib/
│   │   ├── builder/
│   │   │   ├── mcp_builder.dart      # Main builder logic
│   │   │   ├── schema_builder.dart   # Schema generation
│   │   │   ├── templates.dart        # Code templates (stdio/HTTP/code mode)
│   │   │   ├── openapi_builder.dart  # OpenAPI 3.0 spec generation
│   │   │   └── doc_extractor.dart    # Doc comment extraction
│   │   └── mcp_generator.dart
│   ├── example/
│   └── pubspec.yaml
example/                      # Working example
├── lib/src/
│   ├── user_store.dart
│   ├── todo_store.dart
│   ├── user.dart
│   └── todo.dart
├── bin/
│   ├── example.dart
│   ├── example.mcp.dart      # Generated MCP server (do not edit)
│   ├── example.mcp.json      # Generated MCP tool metadata
│   └── example.openapi.json  # Generated OpenAPI 3.0 spec
└── pubspec.yaml
images/
├── logo-banner.svg
├── logo-icon.svg
└── logo.svg
```

## Commands

### Development
```bash
# Get dependencies
melos bootstrap

# Run code generation
dart run build_runner build

# Run tests
melos run test

# Static analysis
melos run analyze

# Format code
melos run format
```

### Package Management
```bash
# Publish annotations package
cd packages/easy_api_annotations && dart pub publish --force

# Publish generator package
cd packages/easy_api_generator && dart pub publish --force
```

## Code Style

- Follow standard Dart conventions
- Use PascalCase for annotation classes: `@Server`, `@Tool`, `@Parameter`
- Use `peek()` instead of `read()` for optional annotation fields
- Always escape backslashes and dollar signs in generated strings
- Add comprehensive DartDoc comments to public APIs

## Annotations

### @Server
Main server annotation with transport configuration:
- `transport`: `McpTransport.stdio` or `McpTransport.http`
- `port`: HTTP port (default: 3000)
- `address`: HTTP bind address (default: '127.0.0.1')
- `generateJson`: Generate .mcp.json metadata (default: false)
- `generateMcp`: Generate .mcp.dart server (default: true)
- `generateRest`: Generate .openapi.json REST spec (default: false)
- `codeMode`: Enable batch tool orchestration via Node.js sandbox (default: false)
- `codeModeTimeout`: Max execution time for code mode scripts in seconds (default: 30)
- `toolPrefix`: Prefix all tool names (optional)
- `autoClassPrefix`: Prefix tool names with class name (default: false)

> Note: `@Mcp` is still available as a deprecated typedef for backward compatibility.

### @Tool
Method annotation for exposing functions as MCP tools:
- `description`: Tool description (optional, falls back to doc comments)
- `name`: Custom tool name (optional, overrides method name)
- `codeMode`: Available in code mode (default: true, set false for destructive ops)
- `icons`: Optional icon URLs for visual identification

### @Parameter (Optional)
Parameter annotation for rich metadata:
- `title`, `description`, `example`: Documentation
- `minimum`, `maximum`, `pattern`, `enumValues`: Validation
- `sensitive`: Mark sensitive data (default: false)

Note: @Parameter is optional - generator extracts info from Dart types by default.

## Generated Files

- `.mcp.dart`: Complete MCP server implementation (stdio or HTTP)
- `.mcp.json`: Tool metadata (only if `generateJson: true`)
- `.openapi.json`: RESTful OpenAPI 3.0 specification (only if `generateRest: true`)

## Publishing Checklist

1. Update version in pubspec.yaml (both packages together — see "Shared Dependency Strategy")
2. Update CHANGELOG.md with new version entry
3. Run `melos run deps:check` - confirm no stale constraints (especially `analyzer`)
4. Run `dart analyze` - no issues
5. Run `melos run pana` - target 160/160 on both publishable packages (skips `example/`)
6. Run `dart pub publish --dry-run` - no warnings
7. Commit changes
8. Publish: `dart pub publish --force`
9. Push to GitHub

## Shared Dependency Strategy

Both `easy_api_annotations` and `easy_api_generator` depend on `analyzer` and
must stay on compatible major-version ranges. Version drift between the two
will break downstream builds and cause pana's time-bound warnings to fire on
only one package.

**Rules of thumb:**

- Keep `analyzer` (and any other shared transitive dep) constraints identical
  across both `packages/*/pubspec.yaml` files.
- When pana reports "constraint does not support the stable version X…",
  update **both** packages in the same PR.
- Use `melos run deps:check` to audit outdated shared deps before any release.
- Use `melos run deps:upgrade` to bump major versions across the workspace.
- Use `melos run pana` to run pana on publishable packages only (never on
  `example/`, which is intentionally non-publishable).

**Review cadence:** Run `melos run deps:check` at the start of every feature
branch that touches `packages/` and immediately after any pana warning.

## Security

- Never expose internal error details in generated code
- Use generic error messages: "An error occurred while processing the request"
- Escape all special characters in generated strings

## Recent Changes
- Added Code Mode with Node.js sandbox for batch tool orchestration (0.5.0)
- Added OpenAPI 3.0 specification generation (0.5.0)
- Added rich tool naming: custom names, class prefixes, tool prefixes (0.3.0)
- Added @Parameter annotation for rich parameter metadata (0.2.0)
- Added HTTP transport configuration (port, address)
- Added multi-library tool aggregation
- Made .mcp.json generation optional (generateJson parameter)
- Fixed string escaping for regex patterns and special characters
- Published easy_api_annotations 0.5.0 and easy_api_generator 0.5.0 to pub.dev

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
