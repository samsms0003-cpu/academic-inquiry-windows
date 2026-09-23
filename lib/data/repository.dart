import 'package:sqflite/sqflite.dart';

import '../core/text_utils.dart';
import '../domain/grade_logic.dart';
import '../domain/models.dart';
import 'app_database.dart';

/// طبقة موحدة بين الواجهة وقاعدة البيانات.
/// لا تحمّل كل البيانات إلى الذاكرة؛ كل الاستعلامات مفهرسة ومقيدة بـ LIMIT.
class Repository {
  Repository(this._adb);
  final AppDatabase _adb;
  Database get _db => _adb.db;

  // ---------------------------------------------------------------- students

  Future<Student?> findByAcademicId(String rawId) async {
    final id = TextUtils.normalizeDigits(rawId.trim());
    if (id.isEmpty) return null;
    final rows = await _db.query('students', where: 'academic_id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }

  Future<bool> exists(String rawId) async => (await findByAcademicId(rawId)) != null;

  /// بحث بالاسم (أو جزء منه) مع ترقيم صفحات.
  Future<List<Student>> searchByName(String term, {int limit = 50, int offset = 0, String? major, String? level, String? year}) async {
    final norm = TextUtils.normalizeArabic(term);
    if (norm.length < 2) return [];
    final where = StringBuffer('name_norm LIKE ?');
    final args = <Object?>['%$norm%'];
    if (major != null && major.isNotEmpty) {
      where.write(' AND major = ?');
      args.add(major);
    }
    if (level != null && level.isNotEmpty) {
      where.write(' AND level = ?');
      args.add(level);
    }
    if (year != null && year.isNotEmpty) {
      where.write(' AND academic_year = ?');
      args.add(year);
    }
    final rows = await _db.query(
      'students',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<List<Student>> searchByIdPrefix(String prefix, {int limit = 20}) async {
    final id = TextUtils.normalizeDigits(prefix.trim());
    if (id.isEmpty) return [];
    final rows = await _db.query('students', where: 'academic_id LIKE ?', whereArgs: ['$id%'], orderBy: 'academic_id', limit: limit);
    return rows.map(Student.fromMap).toList();
  }

  Future<void> saveNotes(String academicId, String notes) async {
    await _db.update('students', {'notes': notes, 'updated_at': DateTime.now().toIso8601String()},
        where: 'academic_id = ?', whereArgs: [academicId]);
  }

  Future<List<String>> distinctStudentValues(String column) async {
    final rows = await _db.rawQuery('SELECT DISTINCT $column AS v FROM students WHERE $column != \'\' ORDER BY v');
    return rows.map((r) => r['v'].toString()).toList();
  }

  // ------------------------------------------------------------------ grades

  Future<List<GradeRecord>> gradesFor(String academicId) async {
    final rows = await _db.query('grades',
        where: 'academic_id = ?', whereArgs: [academicId], orderBy: 'CAST(level_id AS INTEGER), CAST(semester_id AS INTEGER), id');
    return rows.map(GradeRecord.fromMap).toList();
  }

  Future<List<String>> gradeLevels() async {
    final rows = await _db.rawQuery(
        'SELECT level, MIN(CAST(level_id AS INTEGER)) AS lid FROM grades WHERE level != \'\' GROUP BY level ORDER BY lid');
    return rows.map((r) => r['level'].toString()).toList();
  }

  // -------------------------------------------------------------- attendance

  Future<List<AttendanceRecord>> attendanceFor(String academicId, {String? semester, String? subject, String? status}) async {
    final where = StringBuffer('academic_id = ?');
    final args = <Object?>[academicId];
    if (semester != null && semester.isNotEmpty) {
      where.write(' AND semester = ?');
      args.add(semester);
    }
    if (subject != null && subject.isNotEmpty) {
      where.write(' AND subject_name = ?');
      args.add(subject);
    }
    if (status != null && status.isNotEmpty) {
      where.write(' AND status = ?');
      args.add(status);
    }
    final rows = await _db.query('attendance', where: where.toString(), whereArgs: args, orderBy: 'semester, subject_name, hijri_date');
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<String>> attendanceSemesters() async {
    final rows = await _db.rawQuery('SELECT DISTINCT semester FROM attendance WHERE semester != \'\'');
    final l = rows.map((r) => r['semester'].toString()).toList();
    l.sort((a, b) => AttendanceLogic.semesterOrder(a) - AttendanceLogic.semesterOrder(b));
    return l;
  }

  Future<List<String>> attendanceSubjects({String? semester}) async {
    final rows = semester == null || semester.isEmpty
        ? await _db.rawQuery('SELECT DISTINCT subject_name FROM attendance WHERE subject_name != \'\' ORDER BY subject_name')
        : await _db.rawQuery(
            'SELECT DISTINCT subject_name FROM attendance WHERE semester = ? AND subject_name != \'\' ORDER BY subject_name', [semester]);
    return rows.map((r) => r['subject_name'].toString()).toList();
  }

  Future<List<String>> attendanceStatuses() async {
    final rows = await _db.rawQuery('SELECT DISTINCT status FROM attendance WHERE status != \'\' ORDER BY status');
    return rows.map((r) => r['status'].toString()).toList();
  }

  /// تقرير الغياب الجماعي: يُحسب داخل SQL بدون تحميل السجلات.
  /// منطق الحضور: الحالة تحتوي "حضور" أو "حاضر".
  Future<List<AbsenceRow>> groupAbsence({String? semester, String? subject, required double minPercent}) async {
    final where = StringBuffer('1=1');
    final args = <Object?>[];
    if (semester != null && semester.isNotEmpty) {
      where.write(' AND a.semester LIKE ?');
      args.add('%$semester%');
    }
    if (subject != null && subject.isNotEmpty) {
      where.write(' AND a.subject_name = ?');
      args.add(subject);
    }
    final rows = await _db.rawQuery('''
      SELECT a.academic_id, s.name, s.level, s.major,
             COUNT(*) AS total,
             SUM(CASE WHEN a.status LIKE '%حضور%' OR a.status LIKE '%حاضر%' THEN 0 ELSE 1 END) AS absent
      FROM attendance a
      LEFT JOIN students s ON s.academic_id = a.academic_id
      WHERE $where
      GROUP BY a.academic_id
      HAVING total > 0 AND (absent * 100.0 / total) >= ?
      ORDER BY (absent * 100.0 / total) DESC, s.name
    ''', [...args, minPercent]);
    return rows
        .map((r) => AbsenceRow(
              academicId: r['academic_id'].toString(),
              name: (r['name'] ?? 'غير معروف').toString(),
              level: (r['level'] ?? '-').toString(),
              major: (r['major'] ?? '-').toString(),
              total: (r['total'] as int?) ?? 0,
              absent: ((r['absent'] as num?) ?? 0).toInt(),
            ))
        .toList();
  }

  /// المتفوقون حسب المستوى — يُحسب GPA لكل طالب داخل SQL.
  Future<List<TopStudentRow>> topStudents(String level, {int limit = 10}) async {
    final rows = await _db.rawQuery('''
      SELECT g.academic_id, s.name,
        SUM(COALESCE(g.course_counted,0) * CASE g.grade
          WHEN 'ممتاز' THEN 4 WHEN 'جيد جداً' THEN 3 WHEN 'جيد' THEN 2 WHEN 'مقبول' THEN 1 ELSE 0 END) AS pts,
        SUM(COALESCE(g.course_counted,0)) AS hrs
      FROM grades g LEFT JOIN students s ON s.academic_id = g.academic_id
      WHERE g.level = ?
      GROUP BY g.academic_id
      HAVING hrs > 0 AND pts > 0
      ORDER BY (pts / hrs) DESC
      LIMIT ?
    ''', [level, limit]);
    return rows.map((r) {
      final pts = (r['pts'] as num).toDouble();
      final hrs = (r['hrs'] as num).toDouble();
      return TopStudentRow(academicId: r['academic_id'].toString(), name: (r['name'] ?? '').toString(), gpa: pts / hrs);
    }).toList();
  }

  // ------------------------------------------------------------------- stats

  Future<SystemStats> stats() async {
    Future<int> c(String sql) async => Sqflite.firstIntValue(await _db.rawQuery(sql)) ?? 0;
    final total = await c('SELECT COUNT(*) FROM students');
    final wg = await c('SELECT COUNT(*) FROM students WHERE has_grades = 1');
    final wa = await c('SELECT COUNT(*) FROM students WHERE has_attendance = 1');
    final gr = await c('SELECT COUNT(*) FROM grades');
    final ar = await c('SELECT COUNT(*) FROM attendance');
    final lu = await getSetting('lastUpdate') ?? '-';
    final size = await _adb.fileSizeBytes();
    return SystemStats(
        totalStudents: total, withGrades: wg, withAttendance: wa, gradeRecords: gr, attendanceRecords: ar, lastUpdate: lu, dbSizeBytes: size);
  }

  // ---------------------------------------------------------------- settings

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------- import history

  Future<void> addImportHistory(ImportHistoryEntry e) async {
    await _db.insert('import_history', {
      'file_name': e.fileName,
      'imported_at': e.importedAt,
      'inserted': e.inserted,
      'updated': e.updated,
      'skipped': e.skipped,
      'errors': e.errors,
      'result': e.result,
      'fingerprint': e.fingerprint,
      'error_log': e.errorLog,
    });
  }

  Future<List<ImportHistoryEntry>> importHistory({int limit = 30}) async {
    final rows = await _db.query('import_history', orderBy: 'id DESC', limit: limit);
    return rows.map(ImportHistoryEntry.fromMap).toList();
  }

  Future<bool> fingerprintExists(String fp) async {
    final rows = await _db.query('import_history', where: 'fingerprint = ? AND errors = 0', whereArgs: [fp], limit: 1);
    return rows.isNotEmpty;
  }

  // ------------------------------------------------------------ scan history

  Future<void> addScan(String code, String? academicId, bool success) async {
    await _db.insert('scan_history', {
      'code': code,
      'academic_id': academicId,
      'scanned_at': DateTime.now().toIso8601String(),
      'success': success ? 1 : 0,
    });
    await _db.rawDelete('DELETE FROM scan_history WHERE id NOT IN (SELECT id FROM scan_history ORDER BY id DESC LIMIT 50)');
  }

  Future<List<Map<String, Object?>>> scanHistory({int limit = 20}) => _db.query('scan_history', orderBy: 'id DESC', limit: limit);

  // ------------------------------------------------------------------- write

  /// إدخال دفعة درجات داخل Transaction مع Upsert + تحديث بيانات الطالب.
  Future<void> upsertGradesBatch(List<GradeRecord> records, {required bool updateExisting}) async {
    if (records.isEmpty) return;
    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final batch = txn.batch();
      for (final g in records) {
        batch.rawInsert('''
          INSERT INTO students (academic_id, name, name_norm, major, academic_year, level, has_grades, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
          ON CONFLICT(academic_id) DO UPDATE SET
            name = CASE WHEN excluded.name != '' THEN excluded.name ELSE students.name END,
            name_norm = CASE WHEN excluded.name != '' THEN excluded.name_norm ELSE students.name_norm END,
            major = CASE WHEN excluded.major != '' THEN excluded.major ELSE students.major END,
            academic_year = CASE WHEN excluded.academic_year != '' THEN excluded.academic_year ELSE students.academic_year END,
            level = CASE WHEN excluded.level != '' THEN excluded.level ELSE students.level END,
            has_grades = 1,
            updated_at = excluded.updated_at
        ''', [g.academicId, g.studentName, TextUtils.normalizeArabic(g.studentName), g.major, g.academicYear, g.level, now, now]);
        final m = g.toMap();
        if (updateExisting) {
          batch.insert('grades', m, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          batch.insert('grades', m, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (g.subjectName.isNotEmpty) {
          batch.insert(
              'subjects',
              {
                'subject_id': g.subjectId,
                'subject_name': g.subjectName,
                'level_id': g.levelId,
                'semester_id': g.semesterId,
                'major': g.major,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertAttendanceBatch(List<AttendanceRecord> records, {required bool updateExisting}) async {
    if (records.isEmpty) return;
    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final batch = txn.batch();
      for (final a in records) {
        batch.rawInsert('''
          INSERT INTO students (academic_id, name, name_norm, major, academic_year, level, has_attendance, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
          ON CONFLICT(academic_id) DO UPDATE SET
            name = CASE WHEN excluded.name != '' THEN excluded.name ELSE students.name END,
            name_norm = CASE WHEN excluded.name != '' THEN excluded.name_norm ELSE students.name_norm END,
            major = CASE WHEN excluded.major != '' THEN excluded.major ELSE students.major END,
            academic_year = CASE WHEN excluded.academic_year != '' THEN excluded.academic_year ELSE students.academic_year END,
            level = CASE WHEN excluded.level != '' THEN excluded.level ELSE students.level END,
            has_attendance = 1,
            updated_at = excluded.updated_at
        ''', [a.academicId, a.studentName, TextUtils.normalizeArabic(a.studentName), a.major, a.academicYear, a.level, now, now]);
        batch.insert('attendance', a.toMap(),
            conflictAlgorithm: updateExisting ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> countGrades() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM grades')) ?? 0;
  Future<int> countAttendance() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM attendance')) ?? 0;

  /// مسح كل بيانات الطلاب (يُستدعى بعد تأكيد صريح ونسخة أمان).
  Future<void> clearAllData() async {
    await _db.transaction((txn) async {
      await txn.delete('grades');
      await txn.delete('attendance');
      await txn.delete('students');
      await txn.delete('subjects');
    });
    await _adb.vacuum();
  }

  /// قراءة متدفقة للتصدير الكبير (chunked).
  Future<List<GradeRecord>> gradesChunk(int offset, int limit) async {
    final rows = await _db.query('grades', orderBy: 'academic_id, id', limit: limit, offset: offset);
    return rows.map(GradeRecord.fromMap).toList();
  }

  Future<List<AttendanceRecord>> attendanceChunk(int offset, int limit) async {
    final rows = await _db.query('attendance', orderBy: 'academic_id, id', limit: limit, offset: offset);
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<void> touchLastUpdate() => setSetting('lastUpdate', DateTime.now().toIso8601String());
}

class AbsenceRow {
  final String academicId, name, level, major;
  final int total, absent;
  AbsenceRow({required this.academicId, required this.name, required this.level, required this.major, required this.total, required this.absent});
  double get percent => total > 0 ? absent / total * 100 : 0;
  AbsenceStatus get status => AttendanceLogic.statusForGroup(percent);
}

class TopStudentRow {
  final String academicId, name;
  final double gpa;
  TopStudentRow({required this.academicId, required this.name, required this.gpa});
}
