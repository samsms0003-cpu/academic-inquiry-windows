import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/text_utils.dart';
import '../data/repository.dart';
import '../domain/grade_logic.dart';
import '../domain/models.dart';
import 'xlsx_io.dart';

part 'report_builders.dart';

enum ReportType {
  gradesSummary('بيان درجات الطالب المجمل', 'grades_summary'),
  gradesDetailed('بيان درجات الطالب التفصيلي', 'grades_detailed'),
  attendanceSummary('إشعار بحالة الطالب (ملخص الحضور)', 'attendance_summary'),
  attendanceDetailed('تقرير الحضور التفصيلي', 'attendance_detailed'),
  classAbsence('تقرير الغياب الجماعي حسب الفصل', 'class_absence'),
  subjectAbsence('تقرير الغياب حسب المادة', 'subject_absence'),
  systemStats('تقرير إحصائيات النظام', 'system_stats'),
  topStudents('قائمة الطلاب المتفوقين', 'top_students');

  const ReportType(this.title, this.fileKey);
  final String title;
  final String fileKey;
  bool get needsStudent => index <= 3;
}

/// خيارات التقارير الجماعية.
class ReportParams {
  final String? semester;
  final String? subject;
  final double minPercent;
  final String? level;
  /// تصفية حالة الحضور (لتقارير الطالب الفردية).
  final String? status;
  const ReportParams({this.semester, this.subject, this.minPercent = 40, this.level, this.status});
  bool get hasAttendanceFilter => (semester ?? '').isNotEmpty || (subject ?? '').isNotEmpty || (status ?? '').isNotEmpty;
  String get filterLabel => [
        if ((semester ?? '').isNotEmpty) 'الفصل: $semester',
        if ((subject ?? '').isNotEmpty) 'المادة: $subject',
        if ((status ?? '').isNotEmpty) 'الحالة: $status',
      ].join('  |  ');
}

/// نتيجة التقرير: PDF + بيانات جدولية لتصدير Excel.
class ReportOutput {
  final Uint8List pdf;
  final String title;
  final List<String> excelHeaders;
  final List<List<Object?>> excelRows;
  final String fileBase;
  ReportOutput({required this.pdf, required this.title, required this.excelHeaders, required this.excelRows, required this.fileBase});

  Uint8List toXlsx() {
    final w = XlsxWriter();
    final s = w.addSheet('Report');
    s.addHeader(excelHeaders);
    for (final r in excelRows) {
      s.addRow(r);
    }
    return w.build();
  }
}

/// مولد تقارير PDF أصلي (بدون HTML) بخط Cairo واتجاه RTL حقيقي.
/// يكرر رأس الجدول عند الانتقال بين الصفحات ولا يقسم الصف الواحد.
class ReportService {
  ReportService(this.repo, this.state);
  final Repository repo;
  final AppState state;

  static pw.Font? _regular, _bold;
  static String? _loadedFont;
  static pw.MemoryImage? _defaultLogo;

  static const _green = PdfColor.fromInt(0xFF006B45);
  static const _greenDark = PdfColor.fromInt(0xFF004B31);
  static const _gold = PdfColor.fromInt(0xFFC9962C);
  static const _goldLight = PdfColor.fromInt(0xFFF6EBD2);
  static const _greenLight = PdfColor.fromInt(0xFFE6F2EC);
  static const _failBg = PdfColor.fromInt(0xFFFECACA);
  static const _fail = PdfColor.fromInt(0xFFDC2626);
  static const _ok = PdfColor.fromInt(0xFF059669);
  static const _grey = PdfColor.fromInt(0xFF667085);
  static const _border = PdfColor.fromInt(0xFF9CA3AF);

  Future<void> _ensureFonts() async {
    final f = AppConstants.fonts[state.reportFont] ?? AppConstants.fonts['Cairo']!;
    if (_loadedFont != state.reportFont || _regular == null) {
      _regular = pw.Font.ttf(await rootBundle.load(f.regular));
      _bold = pw.Font.ttf(await rootBundle.load(f.bold));
      _loadedFont = state.reportFont;
    }
    _defaultLogo ??= pw.MemoryImage((await rootBundle.load('assets/images/academy_logo.png')).buffer.asUint8List());
  }

  pw.ThemeData get _theme => pw.ThemeData.withFont(base: _regular!, bold: _bold!).copyWith(
        defaultTextStyle: pw.TextStyle(font: _regular, fontSize: 9),
      );

  pw.TextStyle _ts({double size = 9, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(font: bold ? _bold : _regular, fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : null);

  String get _now => DateFormat('yyyy/MM/dd  HH:mm').format(DateTime.now());

  static PdfColor _pc(int argb) => PdfColor.fromInt(argb);

  // ================================================================ header

  pw.Widget _header() {
    if (!state.showReportHeader) return pw.SizedBox();
    final logoBytes = state.headerLogoBytes;
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : _defaultLogo!;
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 1.5))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // القسم الأيسر (بصريًا): النص الإنجليزي — توسيط داخل القسم
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [for (final t in state.headerEn) pw.Text(t, style: _ts(size: 7.5, color: _greenDark), textAlign: pw.TextAlign.center, textDirection: pw.TextDirection.ltr)],
            ),
          ),
          // القسم الأوسط: الشعار
          pw.SizedBox(width: 78, height: 60, child: pw.Center(child: pw.Image(logo, fit: pw.BoxFit.contain))),
          // القسم الأيمن (بصريًا): النص العربي — توسيط داخل القسم
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [for (final t in state.headerAr) pw.Text(t, style: _ts(size: 9, bold: true, color: _greenDark), textAlign: pw.TextAlign.center, textDirection: pw.TextDirection.rtl)],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _titleBar(String title) => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: pw.BoxDecoration(color: _green, borderRadius: pw.BorderRadius.circular(4)),
        alignment: pw.Alignment.center,
        child: pw.Text(title, style: _ts(size: 12, bold: true, color: PdfColors.white)),
      );

  pw.Widget _studentBar(Student s) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.6)),
        child: pw.Table(
          border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: _border, width: 0.6)),
          columnWidths: {
            5: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.6),
            3: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(2.6),
            1: const pw.FlexColumnWidth(1),
            0: const pw.FlexColumnWidth(1.6)
          },
          children: [
            pw.TableRow(children: [_lbl('الرقم الأكاديمي'), _val(s.academicId), _lbl('اسم الطالب'), _val(s.name), _lbl('المستوى'), _val(s.level)].reversed.toList()),
            pw.TableRow(children: [_lbl('التخصص'), _val(s.major), _lbl('العام الدراسي'), _val(s.academicYear), _lbl('التاريخ'), _val(_now)].reversed.toList()),
          ],
        ),
      );

  pw.Widget _lbl(String t) => pw.Container(color: _greenLight, padding: const pw.EdgeInsets.all(3), alignment: pw.Alignment.center, child: pw.Text(t, style: _ts(size: 8, bold: true)));
  pw.Widget _val(String t) => pw.Container(padding: const pw.EdgeInsets.all(3), alignment: pw.Alignment.center, child: pw.Text(t.isEmpty ? '-' : t, style: _ts(size: 8, bold: true)));

  pw.Widget _footer(pw.Context c) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_now, style: _ts(size: 7.5, color: _grey)),
            pw.Text('صادر من نظام الاستعلامات الأكاديمية — ${AppConstants.appSubtitle}', style: _ts(size: 7.5, color: _grey)),
            pw.Text('الصفحة ${c.pageNumber} من ${c.pagesCount}', style: _ts(size: 7.5, color: _grey)),
          ],
        ),
      );

  pw.Document _doc() => pw.Document(theme: _theme, title: AppConstants.appName, author: AppConstants.appSubtitle);

  pw.MultiPage _page({required List<pw.Widget> children, bool landscape = false, bool withHeader = true}) => pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        textDirection: pw.TextDirection.rtl,
        header: withHeader ? (_) => _header() : null,
        footer: _footer,
        build: (_) => children,
      );

  /// جدول عام: يكرر الرأس بين الصفحات ولا يقسم الصفوف.
  pw.Widget _table(List<String> headers, List<List<pw.Widget>> rows, {Map<int, pw.TableColumnWidth>? widths, double headSize = 8}) {
    final n = headers.length;
    final mirrored = widths == null ? null : {for (final e in widths.entries) (n - 1 - e.key): e.value};
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: mirrored,
      tableWidth: pw.TableWidth.max,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _green),
          children: [
            for (final h in headers.reversed)
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text(h, style: _ts(size: headSize, bold: true, color: PdfColors.white), textAlign: pw.TextAlign.center),
              )
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(decoration: pw.BoxDecoration(color: i.isOdd ? const PdfColor.fromInt(0xFFF7F7F2) : PdfColors.white), children: rows[i].reversed.toList()),
      ],
    );
  }

  pw.Widget _c(String t, {double size = 8, bool bold = false, PdfColor? color, PdfColor? bg, pw.Alignment align = pw.Alignment.center}) => pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        alignment: align,
        child: pw.Text(t.isEmpty ? '-' : t, style: _ts(size: size, bold: bold, color: color), textAlign: pw.TextAlign.center),
      );

  pw.Widget _chip(AbsenceStatus st, {double size = 7.5}) => pw.Container(
        padding: const pw.EdgeInsets.all(2),
        alignment: pw.Alignment.center,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: pw.BoxDecoration(color: _pc(st.bg.toARGB32()), border: pw.Border.all(color: _pc(st.color.toARGB32()), width: 1), borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Text(st.text, style: _ts(size: size, bold: true, color: _pc(st.color.toARGB32()))),
        ),
      );

  pw.Widget _empty(String msg) => pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(40), child: pw.Text(msg, style: _ts(size: 12, color: _grey))));

  pw.Widget _summaryRow(String l1, String v1, String l2, String v2, String l3, String v3, {bool light = false}) {
    final bg = light ? _greenLight : _greenDark;
    pw.Widget item(String l, String v) => pw.Expanded(
          child: pw.Column(children: [
            pw.Text(l, style: _ts(size: 7.5, color: light ? _grey : const PdfColor.fromInt(0xFFD9E5DE))),
            pw.Text(v, style: _ts(size: 10, bold: true, color: light ? _greenDark : _gold)),
          ]),
        );
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Row(children: [item(l3, v3), item(l2, v2), item(l1, v1)]),
    );
  }

  pw.Widget _sectionBar(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8, bottom: 3),
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        color: _goldLight,
        alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: _ts(size: 10, bold: true, color: _greenDark)),
      );

  // ============================================================ dispatcher

  Future<ReportOutput> build(ReportType type, {Student? student, ReportParams params = const ReportParams()}) async {
    await _ensureFonts();
    switch (type) {
      case ReportType.gradesSummary:
        return _gradesSummary(student!);
      case ReportType.gradesDetailed:
        return _gradesDetailed(student!);
      case ReportType.attendanceSummary:
        return _attendanceSummary(student!, params);
      case ReportType.attendanceDetailed:
        return _attendanceDetailed(student!, params);
      case ReportType.classAbsence:
      case ReportType.subjectAbsence:
        return _groupAbsence(type, params);
      case ReportType.systemStats:
        return _systemStats();
      case ReportType.topStudents:
        return _topStudents(params.level ?? '');
    }
  }
}
