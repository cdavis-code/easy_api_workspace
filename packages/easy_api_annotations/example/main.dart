// Minimal example showing how `easy_api_annotations` is used.
//
// This file is intentionally tiny: it demonstrates the annotation surface
// only. The annotations themselves have no runtime behavior — they are
// consumed by the companion `easy_api_generator` package at build time to
// produce MCP servers, REST servers, and OpenAPI specs.
//
// For a complete, runnable end-to-end example (including generated output
// and a working MCP / REST server), see the workspace-level `/example`
// directory at the repository root.

import 'package:easy_api_annotations/mcp_annotations.dart';

@Server(transport: McpTransport.http, port: 3000, generateRest: true)
class UserService {
  /// Creates a new user in the system.
  @Tool(description: 'Create a new user')
  Future<Map<String, Object?>> createUser({
    @Parameter(
      title: 'Full Name',
      description: "The user's complete name",
      example: 'Ada Lovelace',
    )
    required String name,
    @Parameter(title: 'Age', minimum: 0, maximum: 150, example: 36) int? age,
  }) async {
    return {'name': name, 'age': age, 'id': 1};
  }
}

void main() {
  // The annotations have no runtime effect. Running this file by itself
  // prints a short reminder pointing to the generator package.
  //
  // ignore: avoid_print
  print(
    'easy_api_annotations defines compile-time metadata only.\n'
    'Pair it with easy_api_generator and run `dart run build_runner build`\n'
    'to generate MCP / REST servers from the annotated class above.',
  );
}
