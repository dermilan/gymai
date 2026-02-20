import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_card_config.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import 'local_store.dart';

class DatabaseStore implements LocalStore {
  static Database? _db;
  static const _dbName = 'gym_ai.db';
  static const _dbVersion = 1;

  // Keep these in SharedPreferences as they are simple key-value settings
  static const _prefsKey = 'user_prefs_json';
  static const _activeSessionKey = 'active_session_json';
  static const _lastSeenHistoryCountKey = 'last_seen_history_count';
  static const _dashboardLayoutKey = 'dashboard_layout_json';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workouts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            summary TEXT,
            durationMinutes INTEGER,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            exercises_json TEXT NOT NULL,
            aiComment TEXT
          )
        ''');
        // Index by date for faster history sorting
        await db.execute('CREATE INDEX idx_workouts_date ON workouts(date)');
      },
    );
  }

  @override
  Future<List<Workout>> fetchWorkouts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts',
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      final json = Map<String, dynamic>.from(map);
      // Map database columns back to Workout JSON format
      final exercisesJson = json['exercises_json'] as String;
      json['exercises'] = jsonDecode(exercisesJson);
      return Workout.fromJson(json);
    }).toList();
  }

  @override
  Future<void> saveWorkout(Workout workout) async {
    final db = await database;
    final resolved = _ensureId(workout);
    final workoutMap = resolved.toJson();
    
    // Separate exercises into a JSON string for the column
    final exercises = workoutMap.remove('exercises');
    workoutMap['exercises_json'] = jsonEncode(exercises);

    await db.insert(
      'workouts',
      workoutMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    // saveWorkout with ConflictAlgorithm.replace handles updates if ID matches
    await saveWorkout(workout);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    final db = await database;
    await db.delete(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<UserPrefs> fetchPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return UserPrefs.empty();
    try {
      return UserPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserPrefs.empty();
    }
  }

  @override
  Future<void> savePrefs(UserPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(prefs.toJson()));
  }

  @override
  Future<Workout?> fetchActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Workout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActiveSession(Workout session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionKey);
  }

  @override
  Future<int> getUnseenHistoryCount() async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM workouts WHERE status = ?',
      [WorkoutStatus.completed.name],
    );
    final completedCount = Sqflite.firstIntValue(countResult) ?? 0;
    
    final lastSeenCount = prefs.getInt(_lastSeenHistoryCountKey) ?? 0;
    return (completedCount - lastSeenCount).clamp(0, completedCount);
  }

  @override
  Future<void> markHistoryAsSeen() async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM workouts WHERE status = ?',
      [WorkoutStatus.completed.name],
    );
    final completedCount = Sqflite.firstIntValue(countResult) ?? 0;
    
    await prefs.setInt(_lastSeenHistoryCountKey, completedCount);
  }

  @override
  Future<List<DashboardCardConfig>> fetchDashboardLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_dashboardLayoutKey);
    if (raw == null || raw.isEmpty) return DashboardCardConfig.defaultLayout();
    try {
      final saved = raw
          .map((e) => DashboardCardConfig.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      return DashboardCardConfig.mergeWithDefaults(saved);
    } catch (_) {
      return DashboardCardConfig.defaultLayout();
    }
  }

  @override
  Future<void> saveDashboardLayout(List<DashboardCardConfig> layout) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = layout.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_dashboardLayoutKey, encoded);
  }

  Workout _ensureId(Workout workout) {
    if (workout.id != null && workout.id!.isNotEmpty) return workout;
    return workout.copyWith(id: workout.effectiveId);
  }
}
