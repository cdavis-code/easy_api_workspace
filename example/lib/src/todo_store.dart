// Persistent todo store backed by a JSON file.
import 'dart:convert';
import 'dart:io';
import 'package:easy_api_annotations/mcp_annotations.dart';
import 'todo.dart';
import 'user.dart';
import 'user_store.dart';

@Server(
  annotationsDefault: ToolAnnotations(openWorldHint: false, readOnlyHint: true),
)
class TodoStore {
  static const _filePath = 'todos.json';
  static const _usersFilePath = 'users.json';
  static List<Todo>? _cache;

  static Future<List<Todo>> _loadTodos() async {
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
    _cache = json.map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  static Future<void> _saveTodos(List<Todo> todos) async {
    _cache = todos;
    final file = File(_filePath);
    final json = jsonEncode(todos.map((t) => t.toJson()).toList());
    await file.writeAsString(json);
  }

  static int get _nextId {
    if (_cache == null || _cache!.isEmpty) return 1;
    return _cache!.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // Helper methods for cross-store operations with UserStore
  static Future<List<User>> _loadUsers() async {
    final file = File(_usersFilePath);
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.isEmpty) {
      return [];
    }

    final json = jsonDecode(content) as List;
    return json.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveUsers(List<User> users) async {
    final file = File(_usersFilePath);
    final json = jsonEncode(users.map((u) => u.toJson()).toList());
    await file.writeAsString(json);
  }

  /// Creates a new todo with the given title.
  ///
  /// This tool overrides the server's readOnlyHint default because it modifies data.
  @Tool(
    description: 'Create a new todo',
    annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: false),
  )
  static Future<Todo> createTodo({required String title}) async {
    final todos = await _loadTodos();
    final todo = Todo(id: _nextId, title: title);
    todos.add(todo);
    await _saveTodos(todos);
    return todo;
  }

  /// Gets a todo by its ID.
  @Tool(description: 'Get todo by ID')
  static Future<Todo?> getTodo(int id) async {
    final todos = await _loadTodos();
    try {
      return todos.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lists all todos in the store.
  @Tool(description: 'List all todos')
  static Future<List<Todo>> listTodos() async {
    return _loadTodos();
  }

  /// Deletes a todo by its ID.
  /// Also removes the todo reference from all users.
  @Tool(
    description: 'Delete a todo',
    annotations: ToolAnnotations(readOnlyHint: false, idempotentHint: true),
  )
  static Future<bool> deleteTodo(int id) async {
    final todos = await _loadTodos();
    final initialLength = todos.length;
    todos.removeWhere((t) => t.id == id);

    if (todos.length != initialLength) {
      await _saveTodos(todos);

      // Clean up todoIds references in all users
      final users = await _loadUsers();
      bool usersModified = false;
      for (var i = 0; i < users.length; i++) {
        if (users[i].todoIds.contains(id)) {
          users[i] = users[i].copyWith(
            todoIds: users[i].todoIds.where((todoId) => todoId != id).toList(),
          );
          usersModified = true;
        }
      }
      if (usersModified) {
        await _saveUsers(users);
        // Invalidate UserStore cache since we modified users
        UserStore.invalidateCache();
      }

      return true;
    }
    return false;
  }

  /// Marks a todo as completed.
  @Tool(
    description: 'Mark a todo as completed',
    annotations: ToolAnnotations(readOnlyHint: false, idempotentHint: true),
  )
  static Future<Todo?> completeTodo(int id) async {
    final todos = await _loadTodos();
    final index = todos.indexWhere((t) => t.id == id);
    if (index == -1) {
      return null;
    }

    final updatedTodo = todos[index].copyWith(completed: true);
    todos[index] = updatedTodo;
    await _saveTodos(todos);
    return updatedTodo;
  }

  /// Assigns a todo to a user.
  /// Updates both the todo's userIds and the user's todoIds.
  @Tool(
    description: 'Assign a todo to a user',
    annotations: ToolAnnotations(readOnlyHint: false, idempotentHint: true),
  )
  static Future<Todo?> assignTodoToUser({
    required int todoId,
    required int userId,
  }) async {
    // Load both stores
    final todos = await _loadTodos();
    final users = await _loadUsers();

    // Find todo and user
    final todoIndex = todos.indexWhere((t) => t.id == todoId);
    final userIndex = users.indexWhere((u) => u.id == userId);

    if (todoIndex == -1 || userIndex == -1) {
      return null;
    }

    // Add userId to todo.userIds if not already present
    final todo = todos[todoIndex];
    if (!todo.userIds.contains(userId)) {
      todos[todoIndex] = todo.copyWith(userIds: [...todo.userIds, userId]);
    }

    // Add todoId to user.todoIds if not already present
    final user = users[userIndex];
    if (!user.todoIds.contains(todoId)) {
      users[userIndex] = user.copyWith(todoIds: [...user.todoIds, todoId]);
    }

    // Save both stores
    await _saveTodos(todos);
    await _saveUsers(users);

    // Invalidate UserStore cache since we modified users
    UserStore.invalidateCache();

    return todos[todoIndex];
  }

  /// Removes a user from a todo.
  /// Updates both the todo's userIds and the user's todoIds.
  @Tool(
    description: 'Remove a user from a todo',
    annotations: ToolAnnotations(readOnlyHint: false, idempotentHint: true),
  )
  static Future<Todo?> removeTodoFromUser({
    required int todoId,
    required int userId,
  }) async {
    // Load both stores
    final todos = await _loadTodos();
    final users = await _loadUsers();

    // Find todo and user
    final todoIndex = todos.indexWhere((t) => t.id == todoId);
    final userIndex = users.indexWhere((u) => u.id == userId);

    if (todoIndex == -1 || userIndex == -1) {
      return null;
    }

    // Remove userId from todo.userIds
    final todo = todos[todoIndex];
    if (todo.userIds.contains(userId)) {
      todos[todoIndex] = todo.copyWith(
        userIds: todo.userIds.where((id) => id != userId).toList(),
      );
    }

    // Remove todoId from user.todoIds
    final user = users[userIndex];
    if (user.todoIds.contains(todoId)) {
      users[userIndex] = user.copyWith(
        todoIds: user.todoIds.where((id) => id != todoId).toList(),
      );
    }

    // Save both stores
    await _saveTodos(todos);
    await _saveUsers(users);

    // Invalidate UserStore cache since we modified users
    UserStore.invalidateCache();

    return todos[todoIndex];
  }

  /// Gets all todos assigned to a specific user.
  @Tool(description: 'Get all todos assigned to a user')
  static Future<List<Todo>> getTodosForUser(int userId) async {
    final todos = await _loadTodos();
    return todos.where((t) => t.userIds.contains(userId)).toList();
  }
}
