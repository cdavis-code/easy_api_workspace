import 'dart:io';
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:mcp_example/src/user_store.dart';
import 'package:mcp_example/src/todo_store.dart';

@Server(
  transport: McpTransport.stdio,
  // generateJson: true,
  // generateRest: true,
  codeMode: true,
  logErrors: true,
)
Future<void> main() async {
  // Seed some initial data if the stores are empty
  final existingUsers = await UserStore.listUsers();
  if (existingUsers.isEmpty) {
    stderr.writeln('Seeding initial data...');

    // Create users
    await UserStore.createUser(name: 'Alice Smith', email: 'alice@example.com');
    await UserStore.createUser(name: 'Bob Jones', email: 'bob@example.com');

    // Create todos
    await TodoStore.createTodo(title: 'Buy groceries');
    final todo2 = await TodoStore.createTodo(title: 'Walk the dog');
    await TodoStore.completeTodo(todo2.id);

    stderr.writeln('✓ Seeded data');
  }
}
