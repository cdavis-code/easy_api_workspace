// Persistent user store backed by a JSON file.
import 'dart:convert';
import 'dart:io';
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'user.dart';
import 'todo.dart';
import 'todo_store.dart';

@Server(
  annotationsDefault: ToolAnnotations(openWorldHint: false, readOnlyHint: true),
)
class UserStore {
  static const _filePath = 'users.json';
  static List<User>? _cache;

  /// Invalidates the cache to force reload from file.
  static void invalidateCache() {
    _cache = null;
  }

  static Future<List<User>> _loadUsers() async {
    if (_cache != null) return _cache!;

    final file = File(_filePath);
    if (!await file.exists()) {
      _cache = [];
      return _cache!;
    }

    final content = await file.readAsString();
    if (content.isEmpty) {
      _cache = [];
      return _cache!;
    }

    final json = jsonDecode(content) as List;
    _cache = json.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  static Future<void> _saveUsers(List<User> users) async {
    _cache = users;
    final file = File(_filePath);
    final json = jsonEncode(users.map((u) => u.toJson()).toList());
    await file.writeAsString(json);
  }

  static int get _nextId {
    if (_cache == null || _cache!.isEmpty) return 1;
    return _cache!.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Creates a new user with the given name and email.
  ///
  /// This tool overrides the server's readOnlyHint default because it modifies data.
  @Tool(
    description: 'Create a new user',
    annotations: ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
    ),
  )
  static Future<User> createUser({
    @Parameter(
      title: 'Full Name',
      description: 'The user\'s full name (1-100 characters)',
      example: 'John Doe',
    )
    required String name,
    @Parameter(
      title: 'Email Address',
      description: 'A valid email address for the user',
      example: 'john.doe@example.com',
      pattern: r'^[\w\.-]+@[\w\.-]+\.\w+$',
    )
    required String email,
  }) async {
    final users = await _loadUsers();
    final user = User(id: _nextId, name: name, email: email, todoIds: []);
    users.add(user);
    await _saveUsers(users);
    return user;
  }

  /// Gets all todos assigned to a user.
  @Tool(description: 'Get all todos assigned to a user')
  static Future<List<Todo>> getUserTodos(int userId) async {
    final users = await _loadUsers();
    try {
      final user = users.firstWhere((u) => u.id == userId);
      if (user.todoIds.isEmpty) return [];
      final todos = await TodoStore.listTodos();
      return todos.where((t) => user.todoIds.contains(t.id)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Gets a user by their ID.
  @Tool(description: 'Get user by ID')
  static Future<User?> getUser(int id) async {
    final users = await _loadUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lists all users in the store.
  @Tool(description: 'List all users')
  static Future<List<User>> listUsers() async {
    return _loadUsers();
  }

  /// Deletes a user by their ID.
  /// Also removes the user reference from all todos.
  ///
  /// This tool overrides the server's readOnlyHint default because it modifies data.
  @Tool(
    description: 'Delete a user',
    codeMode: false,
    annotations: ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: true,
    ),
  )
  static Future<bool> deleteUser(int id) async {
    final users = await _loadUsers();
    final initialLength = users.length;
    users.removeWhere((u) => u.id == id);
    if (users.length != initialLength) {
      await _saveUsers(users);

      // Clean up userId references in all todos
      final todos = await TodoStore.listTodos();
      bool todosModified = false;
      for (var i = 0; i < todos.length; i++) {
        if (todos[i].userIds.contains(id)) {
          todos[i] = todos[i].copyWith(
            userIds: todos[i].userIds.where((userId) => userId != id).toList(),
          );
          todosModified = true;
        }
      }
      if (todosModified) {
        final file = File('todos.json');
        final json = jsonEncode(todos.map((t) => t.toJson()).toList());
        await file.writeAsString(json);
      }

      return true;
    }
    return false;
  }

  /// Search users by query string.
  @Tool(description: 'Search users by query')
  static Future<List<User>> searchUsers(
    @Parameter(
      alias: 'q',
      title: 'Search Query',
      description: 'Text to search for in user names and emails',
      example: 'john',
    )
    String query,
  ) async {
    final users = await _loadUsers();
    final lowerQuery = query.toLowerCase();
    return users
        .where(
          (u) =>
              u.name.toLowerCase().contains(lowerQuery) ||
              u.email.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }
}
