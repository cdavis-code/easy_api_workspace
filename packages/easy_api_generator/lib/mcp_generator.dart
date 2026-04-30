/// mcp_generator package
///
/// This library exports the builder that processes `@mcp` and `@tool`
/// annotations and generates MCP‑compatible server code.
///
/// The actual implementation lives in `builder/mcp_builder.dart`.
/// Users typically depend on this package and run `build_runner` to generate
/// code for their annotated libraries.
library;

export 'builder/mcp_builder.dart';

// Note: Builder implementation uses local stubs
