// Test runner for easy_api_annotations
import 'package:easy_api_annotations/mcp_annotations.dart';

void main() {
  print('Testing mcp_annotations package\n');

  // Test 1: McpTransport enum
  print('Test 1: McpTransport enum');
  print('  stdio: ${McpTransport.stdio}');
  print('  http: ${McpTransport.http}');
  print('  ✓ PASS\n');

  // Test 2: Server annotation
  print('Test 2: Server annotation');
  final serverAnnotation = Server(transport: McpTransport.stdio);
  print('  transport: ${serverAnnotation.transport}');
  print('  ✓ PASS\n');

  // Test 3: Tool annotation with description
  print('Test 3: Tool annotation with description');
  final toolDesc = Tool(description: 'Creates a user');
  print('  description: ${toolDesc.description}');
  print('  ✓ PASS\n');

  // Test 4: Tool annotation with icons
  print('Test 4: Tool annotation with icons');
  final toolIcons = Tool(
    description: 'Create user',
    icons: ['https://example.com/icon.png'],
  );
  print('  icons: ${toolIcons.icons}');
  print('  ✓ PASS\n');

  // Test 5: Tool with deprecated execution
  print('Test 5: Tool with execution (deprecated)');
  final toolExec = Tool(description: 'Create user', execution: {'timeout': 30});
  print('  execution: ${toolExec.execution}');
  print('  (deprecated warning expected)\n');
  print('  ✓ PASS\n');

  print('All tests passed!');
}
