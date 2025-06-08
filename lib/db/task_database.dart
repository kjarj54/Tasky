import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/user.dart';

class TaskDatabase {
  static final TaskDatabase instance = TaskDatabase._init();
  static Database? _database;

  TaskDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);    return await openDatabase(
      path,
      version: 5, // Increment version to force migration
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create users table
    await db.execute('''
    CREATE TABLE users(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');

    // Create tasks table with user_id reference
    await db.execute('''
    CREATE TABLE tasks(
      id INTEGER PRIMARY KEY,
      user_id INTEGER,
      title TEXT NOT NULL,
      is_completed INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      temp_id TEXT,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    )
    ''');

    // Create index for better performance
    await db.execute('''
    CREATE INDEX idx_tasks_user_id ON tasks(user_id)
    ''');
  }  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from version 1 to 2 - add users table and modify tasks
      
      // Check if users table exists, if not create it
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tablesResult.isEmpty) {
        await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL
        )
        ''');
      }

      // Check if temp_id column exists
      final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
      final hasTempId = tableInfo.any((column) => column['name'] == 'temp_id');
      final hasUserId = tableInfo.any((column) => column['name'] == 'user_id');
      
      if (!hasTempId || !hasUserId) {
        // Create new tasks table with all required columns
        await db.execute('''
        CREATE TABLE tasks_new(
          id INTEGER PRIMARY KEY,
          user_id INTEGER,
          title TEXT NOT NULL,
          is_completed INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          temp_id TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
        ''');

        // Copy existing tasks data (set user_id to null for old tasks)
        await db.execute('''
        INSERT INTO tasks_new (id, title, is_completed, created_at, updated_at)
        SELECT id, title, is_completed, created_at, updated_at FROM tasks
        ''');

        await db.execute('DROP TABLE tasks');
        await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
      }
      
      await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)
      ''');
    }
      if (oldVersion < 3) {
      // Ensure temp_id column exists
      final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
      final hasTempId = tableInfo.any((column) => column['name'] == 'temp_id');
      
      if (!hasTempId) {
        await db.execute('ALTER TABLE tasks ADD COLUMN temp_id TEXT');
      }
    }
      if (oldVersion < 4) {
      // Force check all required columns and tables exist
      
      // Ensure users table exists
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tablesResult.isEmpty) {
        await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL
        )
        ''');
      }
      
      // Check and add missing columns to tasks table
      final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
      final columns = tableInfo.map((column) => column['name'] as String).toSet();
      
      if (!columns.contains('temp_id')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN temp_id TEXT');
      }
      if (!columns.contains('user_id')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN user_id INTEGER');
      }
      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN updated_at TEXT');
      }
      
      // Create index if it doesn't exist
      await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)
      ''');
        if (kDebugMode) {
        print('Database migrated to version 4 - all columns should now exist');
      }
    }
    
    if (oldVersion < 5) {
      // Final comprehensive schema check and fix
      await _ensureCompleteSchema(db);
      
      if (kDebugMode) {
        print('Database migrated to version 5 - comprehensive schema check completed');
      }
    }
  }
  
  // Helper method to ensure complete schema exists
  Future<void> _ensureCompleteSchema(Database db) async {
    // Ensure users table exists
    final tablesResult = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
    );
    
    if (tablesResult.isEmpty) {
      await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL
      )
      ''');
    }
    
    // Check and add missing columns to tasks table
    final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
    final columns = tableInfo.map((column) => column['name'] as String).toSet();
    
    if (!columns.contains('temp_id')) {
      await db.execute('ALTER TABLE tasks ADD COLUMN temp_id TEXT');
    }
    if (!columns.contains('user_id')) {
      await db.execute('ALTER TABLE tasks ADD COLUMN user_id INTEGER');
    }
    if (!columns.contains('updated_at')) {
      await db.execute('ALTER TABLE tasks ADD COLUMN updated_at TEXT');
    }
    
    // Create index if it doesn't exist
    await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)
    ''');
  }
  // User operations
  Future<User> insertUser(User user) async {
    final db = await database;
    
    try {
      await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Error inserting user: $e');
        print('User data: ${user.toMap()}');
        
        // Check if users table exists
        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
        );
        print('Users table exists: ${tablesResult.isNotEmpty}');
        
        if (tablesResult.isEmpty) {
          print('Creating users table...');
          await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            created_at TEXT NOT NULL
          )
          ''');
          
          // Retry insert
          await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          return user;
        }
      }
      rethrow;
    }
  }

  Future<User?> getUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> deleteUser(int userId) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
  // Task operations
  Future<Task> insertTask(Task task) async {
    final db = await database;
    
    try {
      final id = await db.insert('tasks', task.toMap());
      return task.copyWith(id: task.id ?? id);
    } catch (e) {
      if (kDebugMode) {
        print('Error inserting task: $e');
        print('Task data: ${task.toMap()}');
        
        // Check table structure
        final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
        print('Table structure: $tableInfo');
      }
      rethrow;
    }
  }

  Future<Task?> getTask(int? id, {String? tempId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    
    if (id != null) {
      maps = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else if (tempId != null) {
      maps = await db.query(
        'tasks',
        where: 'temp_id = ?',
        whereArgs: [tempId],
      );
    } else {
      return null;
    }

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> getAllTasks({int? userId}) async {
    final db = await database;
    List<Map<String, dynamic>> result;
    
    if (userId != null) {
      result = await db.query(
        'tasks',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    } else {
      result = await db.query('tasks', orderBy: 'created_at DESC');
    }
    
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksByUser(int userId) async {
    return getAllTasks(userId: userId);
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    if (task.id != null) {
      return db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } else if (task.tempId != null) {
      return db.update(
        'tasks',
        task.toMap(),
        where: 'temp_id = ?',
        whereArgs: [task.tempId],
      );
    }
    return 0;
  }

  Future<int> deleteTask(int? id, {String? tempId}) async {
    final db = await database;
    if (id != null) {
      return await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else if (tempId != null) {
      return await db.delete(
        'tasks',
        where: 'temp_id = ?',
        whereArgs: [tempId],
      );
    }
    return 0;
  }

  Future<void> deleteAllTasksForUser(int userId) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  // Batch operations for sync
  Future<void> insertTasks(List<Task> tasks) async {
    final db = await database;
    final batch = db.batch();
    
    for (final task in tasks) {
      batch.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    await batch.commit(noResult: true);
  }

  Future<void> replaceTasks(List<Task> tasks, int userId) async {
    final db = await database;
    final batch = db.batch();
    
    // Delete existing tasks for user
    batch.delete('tasks', where: 'user_id = ?', whereArgs: [userId]);
    
    // Insert new tasks
    for (final task in tasks) {
      batch.insert('tasks', task.toMap());
    }
    
    await batch.commit(noResult: true);
  }
  Future close() async {
    final db = await database;
    db.close();
  }

  // Force database recreation (for debugging/fixing schema issues)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tasks.db');
    
    // Close current database
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Delete the database file
    await deleteDatabase(path);
    
    // Reinitialize
    await database;
  }

  // Debug method to check database schema
  Future<void> debugDatabaseSchema() async {
    if (!kDebugMode) return;
    
    final db = await database;
    print('=== DATABASE SCHEMA DEBUG ===');
    
    // Check tasks table structure
    final tasksTableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
    print('Tasks table columns:');
    for (final column in tasksTableInfo) {
      print('  ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
    }
    
    // Check users table structure
    try {
      final usersTableInfo = await db.rawQuery("PRAGMA table_info(users)");
      print('Users table columns:');
      for (final column in usersTableInfo) {
        print('  ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
      }
    } catch (e) {
      print('Users table does not exist or error: $e');
    }
    
    print('=== END DATABASE SCHEMA DEBUG ===');
  }

  // Ensure all required tables and columns exist
  Future<void> ensureSchemaExists() async {
    final db = await database;
    
    // Check if users table exists
    final tablesResult = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
    );
    
    if (tablesResult.isEmpty) {
      if (kDebugMode) {
        print('Creating missing users table...');
      }
      await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL
      )
      ''');
    }
    
    // Check and add missing columns to tasks table
    final tableInfo = await db.rawQuery("PRAGMA table_info(tasks)");
    final columns = tableInfo.map((column) => column['name'] as String).toSet();
    
    if (!columns.contains('temp_id')) {
      if (kDebugMode) {
        print('Adding missing temp_id column...');
      }
      await db.execute('ALTER TABLE tasks ADD COLUMN temp_id TEXT');
    }
    if (!columns.contains('user_id')) {
      if (kDebugMode) {
        print('Adding missing user_id column...');
      }
      await db.execute('ALTER TABLE tasks ADD COLUMN user_id INTEGER');
    }
    if (!columns.contains('updated_at')) {
      if (kDebugMode) {
        print('Adding missing updated_at column...');
      }
      await db.execute('ALTER TABLE tasks ADD COLUMN updated_at TEXT');
    }
    
    // Create index if it doesn't exist
    await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)
    ''');
    
    if (kDebugMode) {
      print('Database schema verification completed');
    }
  }
}