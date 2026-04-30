import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('@Server annotation', () {
    test('accepts stdio transport parameter', () {
      const annotation = Server(transport: McpTransport.stdio);
      expect(annotation.transport, McpTransport.stdio);
    });

    test('accepts http transport parameter', () {
      const annotation = Server(transport: McpTransport.http);
      expect(annotation.transport, McpTransport.http);
    });

    test('has expected defaults', () {
      const annotation = Server();
      expect(annotation.transport, McpTransport.stdio);
      expect(annotation.generateJson, isFalse);
      expect(annotation.port, 3000);
      expect(annotation.address, '127.0.0.1');
      expect(annotation.toolPrefix, isNull);
      expect(annotation.autoClassPrefix, isFalse);
      expect(annotation.generateMcp, isTrue);
      expect(annotation.generateRest, isFalse);
      expect(annotation.codeMode, isFalse);
      expect(annotation.codeModeTimeout, 30);
      expect(annotation.logErrors, isFalse);
    });

    test('accepts HTTP configuration', () {
      const annotation = Server(
        transport: McpTransport.http,
        port: 8080,
        address: '0.0.0.0',
      );
      expect(annotation.port, 8080);
      expect(annotation.address, '0.0.0.0');
    });

    test('Mcp typedef is a deprecated alias of Server', () {
      // ignore: deprecated_member_use_from_same_package
      const Mcp alias = Server();
      expect(alias, isA<Server>());
    });
  });

  group('@Tool annotation', () {
    test('has expected defaults', () {
      const tool = Tool();
      expect(tool.name, isNull);
      expect(tool.description, isNull);
      expect(tool.icons, isNull);
      expect(tool.codeMode, isTrue);
      expect(tool.codeModeVisible, isFalse);
    });

    test('accepts name, description and icons', () {
      const tool = Tool(
        name: 'user_create',
        description: 'Creates a user',
        icons: ['https://example.com/icon.png'],
      );
      expect(tool.name, 'user_create');
      expect(tool.description, 'Creates a user');
      expect(tool.icons, ['https://example.com/icon.png']);
    });

    test('codeMode and codeModeVisible are independent', () {
      const sandboxOnly = Tool(codeMode: true, codeModeVisible: false);
      const listedOnly = Tool(codeMode: false, codeModeVisible: true);
      expect(sandboxOnly.codeMode, isTrue);
      expect(sandboxOnly.codeModeVisible, isFalse);
      expect(listedOnly.codeMode, isFalse);
      expect(listedOnly.codeModeVisible, isTrue);
    });
  });

  group('@Parameter annotation', () {
    test('has expected defaults', () {
      const param = Parameter();
      expect(param.alias, isNull);
      expect(param.title, isNull);
      expect(param.description, isNull);
      expect(param.example, isNull);
      expect(param.minimum, isNull);
      expect(param.maximum, isNull);
      expect(param.pattern, isNull);
      expect(param.sensitive, isFalse);
      expect(param.enumValues, isNull);
    });

    test('accepts validation constraints', () {
      const param = Parameter(
        title: 'Age',
        minimum: 0,
        maximum: 150,
        example: 25,
      );
      expect(param.title, 'Age');
      expect(param.minimum, 0);
      expect(param.maximum, 150);
      expect(param.example, 25);
    });

    test('accepts alias for external parameter name', () {
      const param = Parameter(alias: 'q');
      expect(param.alias, 'q');
    });

    test('accepts sensitive flag', () {
      const param = Parameter(sensitive: true);
      expect(param.sensitive, isTrue);
    });

    test('accepts enumValues', () {
      const param = Parameter(enumValues: ['low', 'medium', 'high']);
      expect(param.enumValues, ['low', 'medium', 'high']);
    });
  });
}
