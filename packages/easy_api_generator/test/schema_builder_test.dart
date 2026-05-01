import 'package:easy_api_generator/builder/schema_builder.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaBuilder', () {
    test('generates Schema.string() for String type', () {
      expect(SchemaBuilder.fromType('String'), equals('Schema.string()'));
    });

    test('generates Schema.int() for int type', () {
      expect(SchemaBuilder.fromType('int'), equals('Schema.int()'));
    });

    test('generates Schema.num() for double type', () {
      expect(SchemaBuilder.fromType('double'), equals('Schema.num()'));
    });

    test('generates Schema.num() for nullable double type', () {
      expect(SchemaBuilder.fromType('double?'), equals('Schema.num()'));
    });

    test('generates Schema.num() for num type', () {
      expect(SchemaBuilder.fromType('num'), equals('Schema.num()'));
    });

    test('generates Schema.num() for nullable num type', () {
      expect(SchemaBuilder.fromType('num?'), equals('Schema.num()'));
    });

    test('fromSchemaMap emits Schema.num() for JSON-Schema number', () {
      expect(
        SchemaBuilder.fromSchemaMap({'type': 'number'}),
        equals('Schema.num()'),
      );
    });

    test('generates Schema.bool() for bool type', () {
      expect(SchemaBuilder.fromType('bool'), equals('Schema.bool()'));
    });

    test('generates Schema.list() for List type', () {
      expect(
        SchemaBuilder.fromType('List<String>'),
        equals('Schema.list(items: Schema.string())'),
      );
    });

    test('generates Schema.string() for unknown types', () {
      expect(SchemaBuilder.fromType('CustomClass'), equals('Schema.string()'));
    });
  });

  group('SchemaBuilder.buildObjectSchema', () {
    test('generates object schema with properties', () {
      final params = [
        {'name': 'id', 'type': 'int', 'isOptional': false},
        {'name': 'name', 'type': 'String', 'isOptional': false},
        {'name': 'email', 'type': 'String', 'isOptional': true},
      ];
      final result = SchemaBuilder.buildObjectSchema(params);
      expect(result, contains('Schema.object('));
      expect(result, contains("'id': Schema.int()"));
      expect(result, contains("'name': Schema.string()"));
      expect(result, contains("'email': Schema.string()"));
      expect(result, contains("required: ['id', 'name']"));
    });

    test('generates empty schema for no params', () {
      final result = SchemaBuilder.buildObjectSchema([]);
      expect(result, equals('Schema.object()'));
    });
  });
}
