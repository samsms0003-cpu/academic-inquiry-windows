import 'package:flutter/material.dart';

import 'models.dart';

/// قواعد الحساب المنقولة كما هي من النظام الحالي (index.html) دون تعديل.
///
/// - التقدير من الدرجة: ≥90 ممتاز، ≥80 جيد جداً، ≥65 جيد، ≥50 مقبول، وإلا راسب.
/// - المعدل: المجموع ÷ (Σ احتساب المادة × 100) × 100.
/// - المبقي: إذا وجدت مواد مبقية يظهر نص "منقول بـ..." بدل التقدير، وتظهر
///   شرطة في المجموع والمعدل.
class GradeLogic {
  GradeLogic._();

  static String gradeFromScore(num score) {
    if (score >= 90) return 'ممتاز';
    if (score >= 80) return 'جيد جداً';
    if (score >= 65) return 'جيد';
    if (score >= 50) return 'مقبول';
    return 'راسب';
  }

  static bool isFailGrade(String? grade) {
    if (grade == null || grade.isEmpty) return false;
    return grade == 'راسب' || grade == 'ضعيف' || grade == 'غياب';
  }

  static Color gradeColor(String? grade) {
    switch (grade) {
      case 'ممتاز':
        return const Color(0xFF059669);
      case 'جيد جداً':
        return const Color(0xFF2563EB);
      case 'جيد':
        return const Color(0xFF10B981);
      case 'مقبول':
        return const Color(0xFFF59E0B);
      case null:
      case '':
        return Colors.grey;
      default:
        return const Color(0xFFEF4444);
    }
  }

  /// نص النقل بناءً على مجموع احتساب المواد المبقية.
  static String? munawwalText(double remainingSum) {
    if (remainingSum <= 0) return null;
    final n = remainingSum.round();
    if (remainingSum != n) return 'باقي للإعادة';
    switch (n) {
      case 1:
        return 'منقول بمادة';
      case 2:
        return 'منقول بمادتين';
      case 3:
        return 'منقول بـ ٣مواد';
      case 4:
        return 'منقول بـ ٤مواد';
      case 5:
        return 'منقول بـ ٥مواد';
      default:
        return 'باقي للإعادة';
    }
  }

  /// مجموع احتساب المواد المبقية في مجموعة مواد.
  static double remainingCalcSum(Iterable<GradeRecord> subjects) {
    var sum = 0.0;
    for (final g in subjects) {
      if (g.isRemaining) sum += g.countedOrOne;
    }
    return sum;
  }

  /// ترتيب الفصول: الأول، الثاني، الثالث.
  static int semesterOrder(String s) {
    if (s.contains('الأول') || s.contains('الاول')) return 1;
    if (s.contains('الثاني')) return 2;
    if (s.contains('الثالث')) return 3;
    return 9;
  }

  /// حساب ملخص مجموعة مواد (فصل أو مستوى).
  static GroupSummary summarize(List<GradeRecord> subjects) {
    var total = 0.0;
    var calcSum = 0.0;
    for (final g in subjects) {
      total += g.total ?? 0;
      calcSum += g.countedOrOne;
    }
    final maxPossible = calcSum * 100;
    final average = maxPossible > 0 ? (total / maxPossible) * 100 : 0.0;
    final rem = remainingCalcSum(subjects);
    final isMunawwal = rem > 0;
    return GroupSummary(
      total: total,
      calcSum: calcSum,
      average: average,
      isMunawwal: isMunawwal,
      displayGrade: isMunawwal ? (munawwalText(rem) ?? '') : gradeFromScore(average),
      displayTotal: isMunawwal ? '-' : _fmt(total),
      displayAverage: isMunawwal ? '-' : '${average.toStringAsFixed(2)}%',
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// تجميع الدرجات: المستوى|العام ← الفصل ← المواد، مرتبة كما في النظام الحالي.
  static List<LevelGroup> groupGrades(List<GradeRecord> grades, {String fallbackYear = '-'}) {
    final map = <String, LevelGroup>{};
    for (final g in grades) {
      final level = g.level.isEmpty ? 'غير محدد' : g.level;
      final year = g.academicYear.isEmpty ? fallbackYear : g.academicYear;
      final sem = g.semester.isEmpty ? 'الأول' : g.semester;
      final key = '$level|$year';
      final lg = map.putIfAbsent(key, () => LevelGroup(level: level, academicYear: year, levelId: g.levelId));
      final sg = lg.semesters.putIfAbsent(sem, () => SemesterGroup(semester: sem, semesterId: g.semesterId));
      sg.subjects.add(g);
    }
    final list = map.values.toList();
    list.sort((a, b) {
      final la = int.tryParse(a.levelId) ?? 0;
      final lb = int.tryParse(b.levelId) ?? 0;
      if (la == lb) return a.academicYear.compareTo(b.academicYear);
      return la - lb;
    });
    return list;
  }

  /// نقاط GPA للمتفوقين (4/3/2/1).
  static double gpaPoints(String grade) {
    switch (grade) {
      case 'ممتاز':
        return 4;
      case 'جيد جداً':
        return 3;
      case 'جيد':
        return 2;
      case 'مقبول':
        return 1;
      default:
        return 0;
    }
  }

  static String gpaGrade(double gpa) {
    if (gpa >= 3.5) return 'ممتاز';
    if (gpa >= 2.5) return 'جيد جداً';
    if (gpa >= 1.5) return 'جيد';
    return 'مقبول';
  }
}

class GroupSummary {
  final double total;
  final double calcSum;
  final double average;
  final bool isMunawwal;
  final String displayGrade;
  final String displayTotal;
  final String displayAverage;
  const GroupSummary({
    required this.total,
    required this.calcSum,
    required this.average,
    required this.isMunawwal,
    required this.displayGrade,
    required this.displayTotal,
    required this.displayAverage,
  });
}

class SemesterGroup {
  final String semester;
  final String semesterId;
  final List<GradeRecord> subjects = [];
  SemesterGroup({required this.semester, required this.semesterId});
  GroupSummary get summary => GradeLogic.summarize(subjects);
}

class LevelGroup {
  final String level;
  final String academicYear;
  final String levelId;
  final Map<String, SemesterGroup> semesters = {};
  LevelGroup({required this.level, required this.academicYear, required this.levelId});

  List<SemesterGroup> get sortedSemesters {
    final l = semesters.values.toList();
    l.sort((a, b) => GradeLogic.semesterOrder(a.semester) - GradeLogic.semesterOrder(b.semester));
    return l;
  }

  List<GradeRecord> get allSubjects => semesters.values.expand((s) => s.subjects).toList();
  GroupSummary get summary => GradeLogic.summarize(allSubjects);
}

/// منطق الحضور والغياب المنقول من النظام الحالي.
class AttendanceLogic {
  AttendanceLogic._();

  /// حالة الطالب حسب نسبة الغياب (تقرير الملخص الفردي).
  static AbsenceStatus statusForSummary(double absentPercent) {
    if (absentPercent >= 50) return const AbsenceStatus('حرمان', Color(0xFFDC2626), Color(0xFFFEE2E2));
    if (absentPercent >= 40) return const AbsenceStatus('إنذار بالحرمان', Color(0xFFEF4444), Color(0xFFFFE4E6));
    if (absentPercent >= 30) return const AbsenceStatus('تحذير', Color(0xFFCA8A04), Color(0xFFFEF9C3));
    if (absentPercent >= 20) return const AbsenceStatus('ضعيف', Color(0xFFD97706), Color(0xFFFFEDD5));
    if (absentPercent >= 11) return const AbsenceStatus('جيد', Color(0xFF0891B2), Color(0xFFCFFAFE));
    if (absentPercent >= 6) return const AbsenceStatus('جيد جداً', Color(0xFF0891B2), Color(0xFFCFFAFE));
    return const AbsenceStatus('ممتاز', Color(0xFF059669), Color(0xFFD1FAE5));
  }

  /// حالة الطالب حسب نسبة الغياب (التقارير الجماعية).
  static AbsenceStatus statusForGroup(double absentPercent) {
    if (absentPercent >= 50) return const AbsenceStatus('حرمان', Color(0xFFDC2626), Color(0xFFFEE2E2));
    if (absentPercent >= 40) return const AbsenceStatus('إنذار بالحرمان', Color(0xFFEF4444), Color(0xFFFFE4E6));
    if (absentPercent >= 30) return const AbsenceStatus('تحذير', Color(0xFFCA8A04), Color(0xFFFEF9C3));
    if (absentPercent >= 20) return const AbsenceStatus('ضعيف', Color(0xFFD97706), Color(0xFFFFEDD5));
    if (absentPercent >= 10) return const AbsenceStatus('جيد', Color(0xFF0891B2), Color(0xFFCFFAFE));
    return const AbsenceStatus('ممتاز', Color(0xFF059669), Color(0xFFD1FAE5));
  }

  static int semesterOrder(String s) {
    if (s.contains('الأول') || s.contains('الاول')) return 1;
    if (s.contains('الثاني')) return 2;
    if (s.contains('الثالث')) return 3;
    return 99;
  }

  /// تجميع سجلات الحضور: فصل ← مادة ← إحصائيات.
  static List<AttendanceSemester> group(List<AttendanceRecord> records) {
    final map = <String, AttendanceSemester>{};
    for (final r in records) {
      final sem = r.semester.trim().isEmpty ? 'غير محدد' : r.semester.trim();
      final sub = r.subjectName.trim().isEmpty ? 'غير محدد' : r.subjectName.trim();
      final s = map.putIfAbsent(sem, () => AttendanceSemester(sem));
      final st = s.subjects.putIfAbsent(sub, () => SubjectAttendance(sub));
      st.records.add(r);
      st.total++;
      s.totalLectures++;
      if (r.isPresent) {
        st.present++;
        s.totalPresent++;
      } else {
        st.absent++;
        s.totalAbsent++;
      }
    }
    final l = map.values.toList();
    l.sort((a, b) => semesterOrder(a.semester) - semesterOrder(b.semester));
    return l;
  }
}

class AbsenceStatus {
  final String text;
  final Color color;
  final Color bg;
  const AbsenceStatus(this.text, this.color, this.bg);
}

class SubjectAttendance {
  final String subject;
  final List<AttendanceRecord> records = [];
  int total = 0;
  int present = 0;
  int absent = 0;
  SubjectAttendance(this.subject);
  double get absencePercent => total > 0 ? absent / total * 100 : 0;
  AbsenceStatus get status => AttendanceLogic.statusForSummary(absencePercent);
}

class AttendanceSemester {
  final String semester;
  final Map<String, SubjectAttendance> subjects = {};
  int totalLectures = 0;
  int totalPresent = 0;
  int totalAbsent = 0;
  AttendanceSemester(this.semester);

  List<SubjectAttendance> get sortedSubjects {
    final l = subjects.values.toList();
    l.sort((a, b) => a.subject.compareTo(b.subject));
    return l;
  }

  double get absencePercent => totalLectures > 0 ? totalAbsent / totalLectures * 100 : 0;
  double get attendanceRate => totalLectures > 0 ? totalPresent / totalLectures * 100 : 0;
  AbsenceStatus get status => AttendanceLogic.statusForSummary(absencePercent);
  int get deprivedCount => subjects.values.where((s) => s.absencePercent >= 50).length;
}
