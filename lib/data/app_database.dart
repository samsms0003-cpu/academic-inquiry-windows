import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// فتح قاعدة SQLite مع الترحيلات والفهارس.
///
/// المخطط علائقي: students / grades / attendance / subjects / settings /
/// import_history. الفهارس على academic_id, name, subject_name, semester,
/// level_id, status تضمن بحثًا O(log n).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'academic_inquiry.db';
  static const schemaVersion = 1;

  Database? _db;
  String? _path;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database not opened');
    return d;
  }

  String? get path => _path;

  Future<void> open() async {
    if (_db != null) return;
    final DatabaseFactory factory;
    if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
      _path = _dbName;
    } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      factory = databaseFactory;
      _path = p.join(await getDatabasesPath(), _dbName);
    } else {
      // Windows / Linux / macOS: قاعدة البيانات في مجلد بيانات المستخدم (مثل %APPDATA%) وليس بجانب ملف التشغيل.
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      String dir;
      try {
        dir = (await getApplicationSupportDirectory()).path;
      } catch (_) {
        dir = await getDatabasesPath();
      }
      _path = p.join(dir, _dbName);
    }
    _db = await factory.openDatabase(
      _path!,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          if (!kIsWeb) {
            try {
              await db.execute('PRAGMA journal_mode=WAL');
            } catch (_) {}
          }
          await db.execute('PRAGMA synchronous=NORMAL');
          await db.execute('PRAGMA temp_store=MEMORY');
          await db.execute('PRAGMA cache_size=-20000');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL DEFAULT '',
        name_norm TEXT NOT NULL DEFAULT '',
        major TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        has_grades INTEGER NOT NULL DEFAULT 0,
        has_attendance INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_students_name ON students(name_norm)');
    batch.execute('CREATE INDEX idx_students_level ON students(level)');
    batch.execute('CREATE INDEX idx_students_major ON students(major)');

    batch.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_id TEXT NOT NULL,
        student_name TEXT NOT NULL DEFAULT '',
        major TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        semester TEXT NOT NULL DEFAULT '',
        level_id TEXT NOT NULL DEFAULT '',
        semester_id TEXT NOT NULL DEFAULT '',
        subject_id TEXT NOT NULL DEFAULT '',
        subject_name TEXT NOT NULL DEFAULT '',
        total REAL,
        grade TEXT NOT NULL DEFAULT '',
        course_counted REAL,
        remaining TEXT NOT NULL DEFAULT '',
        attendance_score REAL,
        participation REAL,
        coursework REAL,
        midterm REAL,
        final_exam REAL,
        notes TEXT NOT NULL DEFAULT '',
        UNIQUE(academic_id, subject_id, semester_id) ON CONFLICT REPLACE
      )''');
    batch.execute('CREATE INDEX idx_grades_student ON grades(academic_id)');
    batch.execute('CREATE INDEX idx_grades_subject ON grades(subject_name)');
    batch.execute('CREATE INDEX idx_grades_semester ON grades(semester)');
    batch.execute('CREATE INDEX idx_grades_level_id ON grades(level_id)');
    batch.execute('CREATE INDEX idx_grades_level ON grades(level)');

    batch.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_id TEXT NOT NULL,
        student_name TEXT NOT NULL DEFAULT '',
        major TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        semester TEXT NOT NULL DEFAULT '',
        subject_name TEXT NOT NULL DEFAULT '',
        hijri_date TEXT NOT NULL DEFAULT '',
        gregorian_date TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        UNIQUE(academic_id, subject_name, hijri_date) ON CONFLICT REPLACE
      )''');
    batch.execute('CREATE INDEX idx_att_student ON attendance(academic_id)');
    batch.execute('CREATE INDEX idx_att_subject ON attendance(subject_name)');
    batch.execute('CREATE INDEX idx_att_semester ON attendance(semester)');
    batch.execute('CREATE INDEX idx_att_status ON attendance(status)');
    batch.execute('CREATE INDEX idx_att_sem_subject ON attendance(semester, subject_name)');

    batch.execute('''
      CREATE TABLE subjects (
        subject_id TEXT NOT NULL DEFAULT '',
        subject_name TEXT NOT NULL,
        level_id TEXT NOT NULL DEFAULT '',
        semester_id TEXT NOT NULL DEFAULT '',
        major TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(subject_id, subject_name, semester_id)
      )''');

    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE import_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        inserted INTEGER NOT NULL DEFAULT 0,
        updated INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        errors INTEGER NOT NULL DEFAULT 0,
        result TEXT NOT NULL DEFAULT '',
        fingerprint TEXT NOT NULL DEFAULT '',
        error_log TEXT NOT NULL DEFAULT ''
      )''');
    batch.execute('CREATE INDEX idx_import_fp ON import_history(fingerprint)');

    batch.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        academic_id TEXT,
        scanned_at TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 0
      )''');
    await batch.commit(noResult: true);
  }

  /// ترحيلات مستقبلية — لا يجوز حذف بيانات المستخدم.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // مثال: if (oldVersion < 2) { await db.execute('ALTER TABLE ... ADD COLUMN ...'); }
  }

  Future<int> fileSizeBytes() async {
    if (kIsWeb || _path == null) return 0;
    try {
      final f = File(_path!);
      if (!await f.exists()) return 0;
      var size = await f.length();
      final wal = File('$_path-wal');
      if (await wal.exists()) size += await wal.length();
      return size;
    } catch (_) {
      return 0;
    }
  }

  /// إعادة بناء الفهارس/التحليل — من شاشة الصيانة فقط.
  Future<void> reindex() async {
    await db.execute('REINDEX');
    await db.execute('ANALYZE');
  }

  Future<void> vacuum() async {
    try {
      await db.execute('VACUUM');
    } catch (_) {}
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
