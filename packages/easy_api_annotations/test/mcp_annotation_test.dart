import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('@Server annotation', () {
    test('accepts stdio transport parameter', () {
      final annotation = Server(transport: McpTransport.stdio);
      expect(annotation.transport, McpTransport.stdio);
    });

    test('accepts http transport parameter', () {
      final annotation = Server(transport: McpTransport.http);
      expect(annotation.transport, McpTransport.http);
    });

    test('defaults to stdio transport', () {
      final annotation = Server();
      expect(annotation.transport, McpTransport.stdio);
    });
  });
}
