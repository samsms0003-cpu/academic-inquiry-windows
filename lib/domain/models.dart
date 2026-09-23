import '../core/text_utils.dart';

/// بيانات الطالب الأساسية (جدول students).
class Student {
  final int? id;
  final String academicId;
  final String name;
  final String major;
  final String academicYear;
  final String level;
  final String notes;
  final bool hasGrades;
  final bool hasAttendance;

  const Student({
    this.id,
    required this.academicId,
    this.name = '',
    this.major = '',
    this.academicYear = '',
    this.level = '',
    this.notes = '',
    this.hasGrades = false,
    this.hasAttendance = false,
  });

  factory Student.fromMap(Map<String, Object?> m) => Student(
        id: m['id'] as int?,
        academicId: (m['academic_id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        major: (m['major'] ?? '').toString(),
        academicYear: (m['academic_year'] ?? '').toString(),
        level: (m['level'] ?? '').toString(),
        notes: (m['notes'] ?? '').toString(),
        hasGrades: (m['has_grades'] ?? 0) == 1,
        hasAttendance: (m['has_attendance'] ?? 0) == 1,
      );
}

/// سجل درجة واحد (جدول grades) — يحافظ على الأعمدة العشرين كما هي.
class GradeRecord {
  final int? id;
  final String academicId;
  final String studentName;
  final String major;
  final String academicYear;
  final String level;
  final String semester;
  final String levelId;
  final String semesterId;
  final String subjectId;
  final String subjectName;
  final double? total;
  final String grade;
  final double? courseCounted;
  final String remaining;
  final double? attendanceScore;
  final double? participation;
  final double? coursework;
  final double? midterm;
  final double? finalExam;
  final String notes;

  const GradeRecord({
    this.id,
    required this.academicId,
    this.studentName = '',
    this.major = '',
    this.academicYear = '',
    this.level = '',
    this.semester = '',
    this.levelId = '',
    this.semesterId = '',
    this.subjectId = '',
    this.subjectName = '',
    this.total,
    this.grade = '',
    this.courseCounted,
    this.remaining = '',
    this.attendanceScore,
    this.participation,
    this.coursework,
    this.midterm,
    this.finalExam,
    this.notes = '',
  });

  bool get isRemaining {
    final r = remaining.trim();
    return r == 'نعم' || r == 'true' || r == '1' || r == 'yes';
  }

  /// احتساب المادة (الافتراضي 1 كما في النظام الحالي).
  double get countedOrOne => (courseCounted == null || courseCounted == 0) ? 1 : courseCounted!;

  factory GradeRecord.fromMap(Map<String, Object?> m) => GradeRecord(
        id: m['id'] as int?,
        academicId: (m['academic_id'] ?? '').toString(),
        studentName: (m['student_name'] ?? '').toString(),
        major: (m['major'] ?? '').toString(),
        academicYear: (m['academic_year'] ?? '').toString(),
        level: (m['level'] ?? '').toString(),
        semester: (m['semester'] ?? '').toString(),
        levelId: (m['level_id'] ?? '').toString(),
        semesterId: (m['semester_id'] ?? '').toString(),
        subjectId: (m['subject_id'] ?? '').toString(),
        subjectName: (m['subject_name'] ?? '').toString(),
        total: (m['total'] as num?)?.toDouble(),
        grade: (m['grade'] ?? '').toString(),
        courseCounted: (m['course_counted'] as num?)?.toDouble(),
        remaining: (m['remaining'] ?? '').toString(),
        attendanceScore: (m['attendance_score'] as num?)?.toDouble(),
        participation: (m['participation'] as num?)?.toDouble(),
        coursework: (m['coursework'] as num?)?.toDouble(),
        midterm: (m['midterm'] as num?)?.toDouble(),
        finalExam: (m['final_exam'] as num?)?.toDouble(),
        notes: (m['notes'] ?? '').toString(),
      );

  Map<String, Object?> toMap() => {
        'academic_id': academicId,
        'student_name': studentName,
        'major': major,
        'academic_year': academicYear,
        'level': level,
        'semester': semester,
        'level_id': levelId,
        'semester_id': semesterId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'total': total,
        'grade': grade,
        'course_counted': courseCounted,
        'remaining': remaining,
        'attendance_score': attendanceScore,
        'participation': participation,
        'coursework': coursework,
        'midterm': midterm,
        'final_exam': finalExam,
        'notes': notes,
      };

  /// القيم بترتيب أعمدة ورقة Grades (للتصدير).
  List<Object?> toExcelRow() => [
        academicId,
        studentName,
        major,
        academicYear,
        level,
        semester,
        levelId,
        semesterId,
        subjectId,
        subjectName,
        total,
        grade,
        courseCounted,
        remaining,
        attendanceScore,
        participation,
        coursework,
        midterm,
        finalExam,
        notes,
      ];

  /// إنشاء من صف Excel بعد مطابقة الأعمدة (المفاتيح = أسماء الأعمدة الأصلية).
  factory GradeRecord.fromExcelMap(Map<String, Object?> r) => GradeRecord(
        academicId: TextUtils.normalizeDigits(TextUtils.cellToString(r['الرقم الاكاديمي'])),
        studentName: TextUtils.cellToString(r['اسم الطالب']),
        major: TextUtils.cellToString(r['التخصص']),
        academicYear: TextUtils.cellToString(r['العام الدراسي']),
        level: TextUtils.cellToString(r['المستوى']),
        semester: TextUtils.cellToString(r['الفصل الدراسي']),
        levelId: TextUtils.cellToString(r['معرف المستوى']),
        semesterId: TextUtils.cellToString(r['معرف الفصل']),
        subjectId: TextUtils.cellToString(r['معرف المادة']),
        subjectName: TextUtils.cellToString(r['اسم المادة']),
        total: TextUtils.toDoubleOrNull(r['المجموع']),
        grade: TextUtils.cellToString(r['التقدير']),
        courseCounted: TextUtils.toDoubleOrNull(r['احتساب المادة']),
        remaining: TextUtils.cellToString(r['مبقي']),
        attendanceScore: TextUtils.toDoubleOrNull(r['الحضور']),
        participation: TextUtils.toDoubleOrNull(r['المشاركة']),
        coursework: TextUtils.toDoubleOrNull(r['أعمال الفصل']),
        midterm: TextUtils.toDoubleOrNull(r['الامتحان النصفي']),
        finalExam: TextUtils.toDoubleOrNull(r['الامتحان النهائي']),
        notes: TextUtils.cellToString(r['ملاحظات']),
      );
}

/// سجل حضور واحد (جدول attendance) — الأعمدة الأحد عشر.
class AttendanceRecord {
  final int? id;
  final String academicId;
  final String studentName;
  final String major;
  final String academicYear;
  final String level;
  final String semester;
  final String subjectName;
  final String hijriDate;
  final String gregorianDate;
  final String status;
  final String notes;

  const AttendanceRecord({
    this.id,
    required this.academicId,
    this.studentName = '',
    this.major = '',
    this.academicYear = '',
    this.level = '',
    this.semester = '',
    this.subjectName = '',
    this.hijriDate = '',
    this.gregorianDate = '',
    this.status = '',
    this.notes = '',
  });

  /// منطق النظام الحالي: أي حالة تحتوي "حضور" أو "حاضر" تُعد حضورًا.
  bool get isPresent => status.contains('حضور') || status.contains('حاضر');

  factory AttendanceRecord.fromMap(Map<String, Object?> m) => AttendanceRecord(
        id: m['id'] as int?,
        academicId: (m['academic_id'] ?? '').toString(),
        studentName: (m['student_name'] ?? '').toString(),
        major: (m['major'] ?? '').toString(),
        academicYear: (m['academic_year'] ?? '').toString(),
        level: (m['level'] ?? '').toString(),
        semester: (m['semester'] ?? '').toString(),
        subjectName: (m['subject_name'] ?? '').toString(),
        hijriDate: (m['hijri_date'] ?? '').toString(),
        gregorianDate: (m['gregorian_date'] ?? '').toString(),
        status: (m['status'] ?? '').toString(),
        notes: (m['notes'] ?? '').toString(),
      );

  Map<String, Object?> toMap() => {
        'academic_id': academicId,
        'student_name': studentName,
        'major': major,
        'academic_year': academicYear,
        'level': level,
        'semester': semester,
        'subject_name': subjectName,
        'hijri_date': hijriDate,
        'gregorian_date': gregorianDate,
        'status': status,
        'notes': notes,
      };

  List<Object?> toExcelRow() => [
        academicId,
        studentName,
        major,
        academicYear,
        level,
        semester,
        subjectName,
        hijriDate,
        gregorianDate,
        status,
        notes,
      ];

  factory AttendanceRecord.fromExcelMap(Map<String, Object?> r) => AttendanceRecord(
        academicId: TextUtils.normalizeDigits(TextUtils.cellToString(r['acadym_int'])),
        studentName: TextUtils.cellToString(r['AL1']),
        major: TextUtils.cellToString(r['NEM_ALGESM_AR']),
        academicYear: TextUtils.cellToString(r['yer']),
        level: TextUtils.cellToString(r['mestawa']),
        semester: TextUtils.cellToString(r['NEM_FASOL_AR']),
        subjectName: TextUtils.cellToString(r['nem_mawad_ar']),
        hijriDate: TextUtils.cellToString(r['date_m']),
        gregorianDate: TextUtils.cellToString(r['date_h']),
        status: TextUtils.cellToString(r['nem_tahter']),
        notes: TextUtils.cellToString(r['ملاحظات']),
      );
}

/// إحصائيات النظام.
class SystemStats {
  final int totalStudents;
  final int withGrades;
  final int withAttendance;
  final int gradeRecords;
  final int attendanceRecords;
  final String lastUpdate;
  final int dbSizeBytes;

  const SystemStats({
    this.totalStudents = 0,
    this.withGrades = 0,
    this.withAttendance = 0,
    this.gradeRecords = 0,
    this.attendanceRecords = 0,
    this.lastUpdate = '-',
    this.dbSizeBytes = 0,
  });
}

/// سجل استيراد.
class ImportHistoryEntry {
  final int? id;
  final String fileName;
  final String importedAt;
  final int inserted;
  final int updated;
  final int skipped;
  final int errors;
  final String result;
  final String fingerprint;
  final String errorLog;

  const ImportHistoryEntry({
    this.id,
    required this.fileName,
    required this.importedAt,
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = 0,
    this.result = '',
    this.fingerprint = '',
    this.errorLog = '',
  });

  factory ImportHistoryEntry.fromMap(Map<String, Object?> m) => ImportHistoryEntry(
        id: m['id'] as int?,
        fileName: (m['file_name'] ?? '').toString(),
        importedAt: (m['imported_at'] ?? '').toString(),
        inserted: (m['inserted'] as int?) ?? 0,
        updated: (m['updated'] as int?) ?? 0,
        skipped: (m['skipped'] as int?) ?? 0,
        errors: (m['errors'] as int?) ?? 0,
        result: (m['result'] ?? '').toString(),
        fingerprint: (m['fingerprint'] ?? '').toString(),
        errorLog: (m['error_log'] ?? '').toString(),
      );
}
