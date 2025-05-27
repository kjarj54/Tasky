import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class TaskDatabase {
  static final TaskDatabase instance = TaskDatabase._init();
  static Database? _database;

  TaskDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2, // Incrementamos la versión para la migración
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }
  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE tasks(
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      is_completed INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      user_id TEXT,
      server_id TEXT,
      needs_sync INTEGER NOT NULL DEFAULT 1
    )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar las nuevas columnas para la versión 2
      await db.execute('ALTER TABLE tasks ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN server_id TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future<Task> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }
  Future<Task> getTask(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      columns: ['id', 'title', 'is_completed', 'created_at', 'user_id', 'server_id', 'needs_sync'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    } else {
      throw Exception('Task with ID $id not found');
    }
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks');
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksForUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'user_id = ? OR user_id IS NULL',
      whereArgs: [userId],
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksNeedingSync(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'user_id = ? AND needs_sync = 1',
      whereArgs: [userId],
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }
  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTasksForUser(String userId) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> markTaskAsSynced(String localId, String serverId) async {
    final db = await database;
    await db.update(
      'tasks',
      {'server_id': serverId, 'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}