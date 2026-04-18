// Example: Using mcp_annotations to expose library methods as MCP tools
import 'package:easy_mcp_annotations/mcp_annotations.dart';
import 'package:mcp_example/src/user_store.dart';
import 'package:mcp_example/src/todo_store.dart';

@Mcp(
  transport: McpTransport.http,
  port: 8080,
  address: '0.0.0.0',
  generateJson: true,
  generateOpenApi: true,
)
Future<void> main() async {
  // Seed some initial data if the stores are empty
  final existingUsers = await UserStore.listUsers();
  if (existingUsers.isEmpty) {
    print('Seeding initial data...');

    // Create users
    final alice = await UserStore.createUser(
      name: 'Alice Smith',
      email: 'alice@example.com',
    );
    final bob = await UserStore.createUser(
      name: 'Bob Jones',
      email: 'bob@example.com',
    );
    final charlie = await UserStore.createUser(
      name: 'Charlie Brown',
      email: 'charlie@example.com',
    );

    // Create todos
    final todo1 = await TodoStore.createTodo(title: 'Buy groceries');
    final todo2 = await TodoStore.createTodo(title: 'Walk the dog');
    await TodoStore.completeTodo(todo2.id);
    final todo3 = await TodoStore.createTodo(title: 'Finish project');
    final todo4 = await TodoStore.createTodo(title: 'Plan team meeting');

    // Assign todos to users (many-to-many)
    await TodoStore.assignTodoToUser(todoId: todo1.id, userId: alice.id);
    await TodoStore.assignTodoToUser(todoId: todo2.id, userId: alice.id);
    await TodoStore.assignTodoToUser(todoId: todo3.id, userId: bob.id);
    await TodoStore.assignTodoToUser(
      todoId: todo3.id,
      userId: alice.id,
    ); // shared todo
    await TodoStore.assignTodoToUser(todoId: todo4.id, userId: bob.id);
    await TodoStore.assignTodoToUser(
      todoId: todo4.id,
      userId: charlie.id,
    ); // shared todo
  }

  // Show all users and their todos
  final allUsers = await UserStore.listUsers();
  print('All users (${allUsers.length}):');
  for (final user in allUsers) {
    print('  $user');
    final todos = await UserStore.getUserTodos(user.id);
    for (final todo in todos) {
      print('    - $todo');
    }
  }

  // Show all todos and their assigned users
  final allTodos = await TodoStore.listTodos();
  print('\nAll todos (${allTodos.length}):');
  for (final todo in allTodos) {
    print('  $todo');
  }
}
