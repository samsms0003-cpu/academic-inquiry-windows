import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../data/repository.dart';
import 'xlsx_io.dart';

/// النسخ الاحتياطي الكامل بصيغة XLSX (Grades / Attendance / Instructions) وJSON.
/// القراءة من القاعدة تتم على دفعات (chunks) لتجنب تحميل الملايين إلى الذاكرة.
class BackupService {
  BackupService(this.repo);
  final Repository repo;
  static const _chunk = 5000;

  static String stamp() => DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

  Future<Uint8List> buildXlsx({void Function(double fraction, String msg)? onProgress}) async {
    final gCount = await repo.countGrades();
    final aCount = await repo.countAttendance();
    final total = gCount + aCount;
    var done = 0;

    final w = XlsxWriter();
    final gs = w.addSheet('Grades');
    gs.addHeader(AppConstants.gradesColumns);
    for (var off = 0; off < gCount; off += _chunk) {
      final rows = await repo.gradesChunk(off, _chunk);
      for (final g in rows) {
        gs.addRow(g.toExcelRow());
      }
      done += rows.length;
      onProgress?.call(total > 0 ? done / total : 1, 'Grades: $done من $total سجل');
      if (rows.length < _chunk) break;
    }

    final as = w.addSheet('Attendance');
    as.addHeader(AppConstants.attendanceColumns);
    for (var off = 0; off < aCount; off += _chunk) {
      final rows = await repo.attendanceChunk(off, _chunk);
      for (final a in rows) {
        as.addRow(a.toExcelRow());
      }
      done += rows.length;
      onProgress?.call(total > 0 ? done / total : 1, 'Attendance: $done من $total سجل');
      if (rows.length < _chunk) break;
    }

    final ins = w.addSheet('Instructions');
    ins.addHeader(['البند', 'القيمة']);
    ins.addRow(['نوع النسخة', 'نسخة احتياطية كاملة - نظام الاستعلامات الأكاديمية']);
    ins.addRow(['تاريخ النسخة', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
    ins.addRow(['عدد سجلات الدرجات', gCount]);
    ins.addRow(['عدد سجلات الحضور', aCount]);
    ins.addRow(['نسخة التطبيق', AppConstants.appVersion]);
    ins.addRow(['طريقة الاستعادة', 'من التطبيق: النسخ الاحتياطي ← استعادة نسخة XLSX، ثم اختيار دمج أو استبدال.']);
    ins.addRow(['ورقة Grades', 'الأعمدة العشرون الأصلية. المفتاح: الرقم الاكاديمي + معرف المادة + معرف الفصل.']);
    ins.addRow(['ورقة Attendance', 'الأعمدة الأحد عشر الأصلية. المفتاح: acadym_int + nem_mawad_ar + date_m.']);
    ins.addRow(['تنبيه', 'يحتوي الملف على بيانات أكاديمية حساسة؛ يُحفظ في مكان آمن.']);

    onProgress?.call(1, 'جاري ضغط الملف...');
    return w.build();
  }

  Future<Uint8List> buildJson({void Function(double fraction, String msg)? onProgress}) async {
    final gCount = await repo.countGrades();
    final aCount = await repo.countAttendance();
    final sb = StringBuffer();
    sb.write('{"type":"academic_inquiry_backup","version":"${AppConstants.appVersion}","created_at":"${DateTime.now().toIso8601String()}",');
    sb.write('"grades_count":$gCount,"attendance_count":$aCount,"grades":[');
    var first = true;
    for (var off = 0; off < gCount; off += _chunk) {
      final rows = await repo.gradesChunk(off, _chunk);
      for (final g in rows) {
        if (!first) sb.write(',');
        first = false;
        sb.write(jsonEncode(Map.fromIterables(AppConstants.gradesColumns, g.toExcelRow())));
      }
      onProgress?.call((off + rows.length) / (gCount + aCount + 1), 'Grades: ${off + rows.length}');
      if (rows.length < _chunk) break;
    }
    sb.write('],"attendance":[');
    first = true;
    for (var off = 0; off < aCount; off += _chunk) {
      final rows = await repo.attendanceChunk(off, _chunk);
      for (final a in rows) {
        if (!first) sb.write(',');
        first = false;
        sb.write(jsonEncode(Map.fromIterables(AppConstants.attendanceColumns, a.toExcelRow())));
      }
      onProgress?.call((gCount + off + rows.length) / (gCount + aCount + 1), 'Attendance: ${off + rows.length}');
      if (rows.length < _chunk) break;
    }
    sb.write(']}');
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }
}
