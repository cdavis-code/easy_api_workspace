// Minimal example for the `easy_api_generator` package.
//
// This file shows the annotated input that the generator consumes. When you
// run `dart run build_runner build` in a package that contains a file like
// this, the generator produces:
//
//   * `<name>.mcp.dart`      — a complete MCP server (stdio or HTTP)
//   * `<name>.mcp.json`      — tool metadata (when generateJson: true)
//   * `<name>.openapi.dart`  — a shelf-based REST server (when generateRest: true)
//   * `<name>.openapi.json`  — an OpenAPI 3.0 spec (when generateRest: true)
//
// For a full runnable walkthrough — including generated outputs, build
// configuration, and a working MCP + REST server — see the workspace-level
// `/example` directory at the repository root. It is the canonical
// end-to-end demonstration for this codebase.

// The generator package itself does not depend on `easy_api_annotations` at
// runtime — it only reads the annotations from *consumer* packages during
// code generation. This example demonstrates the annotated input shape, so
// the import is suppressed for `depend_on_referenced_packages`.
// ignore: depend_on_referenced_packages
import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(
  transport: McpTransport.http,
  port: 3000,
  generateRest: true,
  generateJson: true,
)
class TodoService {
  /// Returns all todos in the system.
  @Tool(description: 'List todos')
  Future<List<Map<String, Object?>>> listTodos() async => const [];

  /// Creates a new todo item.
  @Tool(description: 'Create a todo item')
  Future<Map<String, Object?>> createTodo({
    @Parameter(
      title: 'Title',
      description: 'Short description of the task',
      example: 'Write release notes',
    )
    required String title,
    @Parameter(
      title: 'Priority',
      description: 'Priority bucket for the task',
      enumValues: ['low', 'medium', 'high'],
      example: 'medium',
    )
    String priority = 'medium',
  }) async {
    return {'id': 1, 'title': title, 'priority': priority, 'done': false};
  }

  /// Marks a todo as complete. Excluded from code-mode orchestration because
  /// it mutates state — callers should invoke it explicitly.
  @Tool(description: 'Mark a todo complete', codeMode: false)
  Future<bool> completeTodo({required int id}) async => true;
}

void main() {
  // This file is meant to be consumed by `build_runner`, not executed
  // directly. Running it simply prints a pointer to the workspace example.
  //
  // ignore: avoid_print
  print(
    'easy_api_generator consumes the @Server / @Tool / @Parameter\n'
    'annotations above via build_runner. For a full runnable demo\n'
    '(generated MCP server, REST server, OpenAPI spec) see the\n'
    '/example directory at the repository root.',
  );
}
