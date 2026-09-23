part of 'report_service.dart';

extension _ReportBuilders on ReportService {
  // ====================================================== grades summary

  Future<ReportOutput> _gradesSummary(Student s) async {
    final grades = await repo.gradesFor(s.academicId);
    final groups = GradeLogic.groupGrades(grades, fallbackYear: s.academicYear);
    final doc = _doc();
    final excel = <List<Object?>>[];

    if (groups.isEmpty) {
      doc.addPage(_page(children: [_titleBar(ReportType.gradesSummary.title), _studentBar(s), _empty('لا توجد بيانات درجات')]));
    }

    // صفحة منفصلة لكل مستوى/عام دراسي كما في النظام الحالي.
    for (final lg in groups) {
      final children = <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: pw.BoxDecoration(color: ReportService._goldLight, borderRadius: pw.BorderRadius.circular(3)),
          alignment: pw.Alignment.centerRight,
          child: pw.RichText(
            textDirection: pw.TextDirection.rtl,
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'بيان درجات الطالب / ', style: _ts(size: 10)),
              pw.TextSpan(text: s.name, style: _ts(size: 10, bold: true)),
              pw.TextSpan(text: '  والمقيد بالرقم الأكاديمي  ', style: _ts(size: 10)),
              pw.TextSpan(text: s.academicId, style: _ts(size: 10, bold: true)),
            ]),
          ),
        ),
        pw.SizedBox(height: 4),
        _titleBar('${lg.level} للعام الدراسي ${lg.academicYear}'),
      ];

      for (final sg in lg.sortedSemesters) {
        children.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, bottom: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ReportService._gold, width: 1))),
          alignment: pw.Alignment.centerRight,
          child: pw.Text('الفصل الدراسي ${sg.semester}', style: _ts(size: 10, bold: true, color: ReportService._greenDark)),
        ));
        // تقسيم المواد إلى عمودين (فردي/زوجي) كما في النظام الحالي.
        final subs = sg.subjects;
        final odd = <int>[], even = <int>[];
        for (var i = 0; i < subs.length; i++) {
          (i.isEven ? odd : even).add(i);
        }
        pw.Widget col(List<int> idx) => idx.isEmpty
            ? pw.SizedBox()
            : _table(
                ['م', 'اسم المادة', 'الدرجة', 'التقدير'],
                [for (final i in idx) _gradeRow(i + 1, subs[i])],
                widths: {0: const pw.FlexColumnWidth(0.5), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1.3)},
              );
        children.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: col(even)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: col(odd)),
        ]));
        final ss = sg.summary;
        children.add(_summaryRow('المعدل', ss.displayAverage, 'مجموع ${sg.semester}', ss.displayTotal, 'تقدير ${sg.semester}', ss.displayGrade, light: true));

        for (var i = 0; i < subs.length; i++) {
          final g = subs[i];
          excel.add([lg.level, lg.academicYear, sg.semester, i + 1, g.subjectId, g.subjectName, g.total, g.grade.isEmpty ? GradeLogic.gradeFromScore(g.total ?? 0) : g.grade, g.courseCounted, g.remaining]);
        }
        excel.add(['', '', sg.semester, 'ملخص الفصل', '', 'المعدل: ${ss.displayAverage}', ss.displayTotal, ss.displayGrade, '', '']);
      }
      final ls = lg.summary;
      children.add(pw.SizedBox(height: 6));
      children.add(_summaryRow('المعدل', ls.displayAverage, 'مجموع ${lg.level}', ls.displayTotal, 'تقدير ${lg.level}', ls.displayGrade));
      excel.add([lg.level, lg.academicYear, '', 'ملخص المستوى', '', 'المعدل: ${ls.displayAverage}', ls.displayTotal, ls.displayGrade, '', '']);
      doc.addPage(_page(children: children));
    }

    return ReportOutput(
      pdf: await doc.save(),
      title: ReportType.gradesSummary.title,
      excelHeaders: const ['المستوى', 'العام الدراسي', 'الفصل الدراسي', 'م', 'معرف المادة', 'اسم المادة', 'المجموع', 'التقدير', 'احتساب المادة', 'مبقي'],
      excelRows: excel,
      fileBase: 'grades_summary_${s.academicId}',
    );
  }

  List<pw.Widget> _gradeRow(int idx, GradeRecord g) {
    final grade = g.grade.isEmpty ? GradeLogic.gradeFromScore(g.total ?? 0) : g.grade;
    final fail = GradeLogic.isFailGrade(grade);
    return [
      _c('$idx'),
      _c(g.subjectName.isEmpty ? 'غير مسماة' : g.subjectName, size: g.subjectName.length > 20 ? 7 : 8, align: pw.Alignment.centerRight),
      _c(TextUtils.fmtNum(g.total), bold: fail, color: fail ? ReportService._fail : null, bg: fail ? ReportService._failBg : null),
      _c(grade, bold: true, color: fail ? ReportService._fail : null, bg: fail ? ReportService._failBg : null),
    ];
  }

  // ===================================================== grades detailed

  Future<ReportOutput> _gradesDetailed(Student s) async {
    final grades = await repo.gradesFor(s.academicId);
    final groups = GradeLogic.groupGrades(grades, fallbackYear: s.academicYear);
    final doc = _doc();
    final children = <pw.Widget>[_titleBar(ReportType.gradesDetailed.title), _studentBar(s)];
    final excel = <List<Object?>>[];

    if (grades.isEmpty) children.add(_empty('لا توجد بيانات درجات'));

    // الأعمدة العشرون كاملة؛ الأعمدة 1-6 (الطالب/المستوى/الفصل) تظهر في شريط الطالب ورأس المجموعة.
    const heads = ['م', 'معرف المستوى', 'معرف الفصل', 'معرف المادة', 'اسم المادة', 'المجموع', 'التقدير', 'احتساب', 'مبقي', 'الحضور', 'المشاركة', 'أعمال الفصل', 'النصفي', 'النهائي', 'ملاحظات'];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.45),
      1: const pw.FlexColumnWidth(0.8),
      2: const pw.FlexColumnWidth(0.8),
      3: const pw.FlexColumnWidth(0.8),
      4: const pw.FlexColumnWidth(2.6),
      5: const pw.FlexColumnWidth(0.8),
      6: const pw.FlexColumnWidth(1),
      7: const pw.FlexColumnWidth(0.7),
      8: const pw.FlexColumnWidth(0.6),
      9: const pw.FlexColumnWidth(0.7),
      10: const pw.FlexColumnWidth(0.7),
      11: const pw.FlexColumnWidth(0.8),
      12: const pw.FlexColumnWidth(0.7),
      13: const pw.FlexColumnWidth(0.7),
      14: const pw.FlexColumnWidth(1.6),
    };

    for (final lg in groups) {
      children.add(_sectionBar('${lg.level} — العام الدراسي ${lg.academicYear}'));
      for (final sg in lg.sortedSemesters) {
        children.add(pw.Container(alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text('الفصل الدراسي ${sg.semester}', style: _ts(size: 9, bold: true))));
        final rows = <List<pw.Widget>>[];
        for (var i = 0; i < sg.subjects.length; i++) {
          final g = sg.subjects[i];
          final grade = g.grade.isEmpty ? GradeLogic.gradeFromScore(g.total ?? 0) : g.grade;
          final fail = GradeLogic.isFailGrade(grade);
          rows.add([
            _c('${i + 1}', size: 7),
            _c(g.levelId, size: 7),
            _c(g.semesterId, size: 7),
            _c(g.subjectId, size: 7),
            _c(g.subjectName, size: 7, align: pw.Alignment.centerRight),
            _c(TextUtils.fmtNum(g.total), size: 7, bold: fail, color: fail ? ReportService._fail : null, bg: fail ? ReportService._failBg : null),
            _c(grade, size: 7, bold: true, color: fail ? ReportService._fail : null, bg: fail ? ReportService._failBg : null),
            _c(TextUtils.fmtNum(g.courseCounted), size: 7),
            _c(g.remaining, size: 7, color: g.isRemaining ? ReportService._fail : null, bold: g.isRemaining),
            _c(TextUtils.fmtNum(g.attendanceScore), size: 7),
            _c(TextUtils.fmtNum(g.participation), size: 7),
            _c(TextUtils.fmtNum(g.coursework), size: 7),
            _c(TextUtils.fmtNum(g.midterm), size: 7),
            _c(TextUtils.fmtNum(g.finalExam), size: 7),
            _c(g.notes, size: 6.5),
          ]);
          excel.add(g.toExcelRow());
        }
        children.add(_table(heads, rows, widths: widths, headSize: 7));
        final ss = sg.summary;
        children.add(_summaryRow('المعدل', ss.displayAverage, 'مجموع ${sg.semester}', ss.displayTotal, 'تقدير ${sg.semester}', ss.displayGrade, light: true));
      }
      final ls = lg.summary;
      children.add(_summaryRow('المعدل', ls.displayAverage, 'مجموع ${lg.level}', ls.displayTotal, 'تقدير ${lg.level}', ls.displayGrade));
    }
    // أفقي تلقائيًا لأن الأعمدة لا تكفي في A4 العمودي.
    doc.addPage(_page(children: children, landscape: true));
    return ReportOutput(pdf: await doc.save(), title: ReportType.gradesDetailed.title, excelHeaders: AppConstants.gradesColumns, excelRows: excel, fileBase: 'grades_detailed_${s.academicId}');
  }

  // ================================================== attendance summary

  pw.Widget _filterBar(ReportParams p) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ReportService._gold, width: 0.8), borderRadius: pw.BorderRadius.circular(3)),
        alignment: pw.Alignment.centerRight,
        child: pw.Text('تصفية: ${p.filterLabel}', style: _ts(size: 8.5, bold: true, color: ReportService._greenDark)),
      );

  Future<ReportOutput> _attendanceSummary(Student s, ReportParams p) async {
    final att = await repo.attendanceFor(s.academicId, semester: p.semester, subject: p.subject, status: p.status);
    final sems = AttendanceLogic.group(att);
    final doc = _doc();
    final excel = <List<Object?>>[];

    if (sems.isEmpty) {
      doc.addPage(_page(children: [_titleBar(ReportType.attendanceSummary.title), _studentBar(s), _empty('لا توجد بيانات حضور')]));
    }

    for (final sem in sems) {
      final subs = sem.sortedSubjects;
      final rows = <List<pw.Widget>>[];
      for (var i = 0; i < subs.length; i++) {
        final x = subs[i];
        final hi = x.absencePercent > 25;
        final warnC = hi ? ReportService._fail : const PdfColor.fromInt(0xFFD97706);
        rows.add([
          _c('${i + 1}', bold: true),
          _c(x.subject, bold: true, align: pw.Alignment.centerRight),
          _c('${x.total}', bold: true),
          _c('${x.present}', bold: true, color: ReportService._ok),
          _c('${x.absent}', bold: true, color: warnC),
          _c('${x.absencePercent.toStringAsFixed(1)}%', bold: true, color: warnC),
          _chip(x.status),
        ]);
        excel.add([sem.semester, x.subject, x.total, x.present, x.absent, double.parse(x.absencePercent.toStringAsFixed(1)), x.status.text]);
      }
      final ov = sem.status;
      doc.addPage(_page(children: [
        pw.Center(child: pw.Text('إشعار بحالة الطالب (ملخص الحضور)', style: _ts(size: 14, bold: true, color: ReportService._greenDark))),
        pw.SizedBox(height: 6),
        _studentBar(s),
        if (p.hasAttendanceFilter) _filterBar(p),
        _sectionBar(sem.semester),
        pw.SizedBox(height: 2),
        _table(['م', 'المادة', 'المحاضرات', 'الحضور', 'الغياب', 'نسبة الغياب', 'الحالة'], rows, widths: {
          0: const pw.FlexColumnWidth(0.5),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1),
          5: const pw.FlexColumnWidth(1.1),
          6: const pw.FlexColumnWidth(1.5)
        }),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: ReportService._border, width: 0.8), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _stat('إجمالي المحاضرات', '${sem.totalLectures}', ReportService._greenDark),
            _stat('الحضور', '${sem.totalPresent}', ReportService._ok),
            _stat('الغياب', '${sem.totalAbsent}', ReportService._fail),
            _stat('نسبة الحضور', '${sem.attendanceRate.toStringAsFixed(1)}%', ReportService._greenDark),
            _stat('نسبة الغياب', '${sem.absencePercent.toStringAsFixed(1)}%', ReportService._fail),
            _stat('الحالة العامة', ov.text, ReportService._pc(ov.color.toARGB32())),
            _stat('مواد الحرمان', '${sem.deprivedCount}', sem.deprivedCount > 0 ? ReportService._fail : ReportService._greenDark),
          ].reversed.toList()),
        ),
      ]));
    }
    return ReportOutput(
      pdf: await doc.save(),
      title: ReportType.attendanceSummary.title,
      excelHeaders: const ['الفصل الدراسي', 'المادة', 'المحاضرات', 'الحضور', 'الغياب', 'نسبة الغياب %', 'الحالة'],
      excelRows: excel,
      fileBase: 'attendance_summary_${s.academicId}',
    );
  }

  pw.Widget _stat(String l, String v, PdfColor c) => pw.Column(children: [pw.Text(l, style: _ts(size: 7, color: ReportService._grey)), pw.Text(v, style: _ts(size: 10, bold: true, color: c))]);

  // ================================================= attendance detailed

  Future<ReportOutput> _attendanceDetailed(Student s, ReportParams p) async {
    final att = await repo.attendanceFor(s.academicId, semester: p.semester, subject: p.subject, status: p.status);
    final sems = AttendanceLogic.group(att);
    final doc = _doc();
    final children = <pw.Widget>[_titleBar(ReportType.attendanceDetailed.title), _studentBar(s), if (p.hasAttendanceFilter) _filterBar(p)];
    final excel = <List<Object?>>[];
    if (att.isEmpty) children.add(_empty('لا توجد بيانات حضور'));

    var totalP = 0, totalA = 0;
    for (final sem in sems) {
      children.add(_sectionBar(sem.semester));
      for (final sub in sem.sortedSubjects) {
        children.add(pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text('${sub.subject}  (حضور ${sub.present} / غياب ${sub.absent} / ${sub.absencePercent.toStringAsFixed(1)}%)', style: _ts(size: 9, bold: true)),
        ));
        final rows = <List<pw.Widget>>[];
        for (var i = 0; i < sub.records.length; i++) {
          final r = sub.records[i];
          final p = r.isPresent;
          if (p) {
            totalP++;
          } else {
            totalA++;
          }
          rows.add([
            _c('${i + 1}'),
            _c(r.hijriDate),
            _c(r.gregorianDate),
            _c(r.status.isEmpty ? 'غياب' : r.status, bold: true, color: p ? ReportService._ok : ReportService._fail, bg: p ? const PdfColor.fromInt(0xFFD1FAE5) : ReportService._failBg),
            _c(r.notes, size: 7),
          ]);
          excel.add(r.toExcelRow());
        }
        children.add(_table(['م', 'التاريخ الهجري', 'التاريخ الميلادي', 'الحالة', 'ملاحظات'], rows,
            widths: {0: const pw.FlexColumnWidth(0.5), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(2.5)}));
      }
    }
    final tot = totalP + totalA;
    if (tot > 0) {
      children.add(pw.SizedBox(height: 8));
      children.add(_summaryRow('عدد الحضور', '$totalP', 'عدد الغياب', '$totalA', 'نسبة الحضور', '${(totalP / tot * 100).toStringAsFixed(1)}%'));
    }
    doc.addPage(_page(children: children));
    return ReportOutput(pdf: await doc.save(), title: ReportType.attendanceDetailed.title, excelHeaders: AppConstants.attendanceColumnLabels, excelRows: excel, fileBase: 'attendance_detailed_${s.academicId}');
  }

  // ====================================================== group absence

  Future<ReportOutput> _groupAbsence(ReportType type, ReportParams p) async {
    final isSubject = type == ReportType.subjectAbsence;
    final rows = await repo.groupAbsence(semester: p.semester, subject: isSubject ? p.subject : null, minPercent: p.minPercent);
    final doc = _doc();
    final excel = <List<Object?>>[];
    final scope = isSubject ? 'المادة: ${p.subject ?? '-'}  |  الفصل: ${p.semester ?? 'الكل'}' : 'الفصل: ${p.semester ?? 'جميع الفصول'}';
    final trows = <List<pw.Widget>>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      trows.add([
        _c('${i + 1}'),
        _c(r.academicId, bold: true),
        _c(r.name, align: pw.Alignment.centerRight),
        _c(r.major, size: 7),
        _c(r.level, size: 7),
        _c('${r.total}'),
        _c('${r.absent}', bold: true, color: ReportService._fail),
        _c('${r.percent.toStringAsFixed(1)}%', bold: true, color: ReportService._fail),
        _chip(r.status, size: 7),
      ]);
      excel.add([i + 1, r.academicId, r.name, r.major, r.level, r.total, r.absent, double.parse(r.percent.toStringAsFixed(1)), r.status.text, isSubject ? (p.subject ?? '') : (p.semester ?? 'الكل')]);
    }
    doc.addPage(_page(children: [
      _titleBar(type.title),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ReportService._border, width: 0.6)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('عدد الطلاب: ${rows.length}', style: _ts(size: 9, bold: true)),
          pw.Text('نسبة الغياب الدنيا: ${p.minPercent.toStringAsFixed(0)}%', style: _ts(size: 9, bold: true, color: ReportService._fail)),
          pw.Text(scope, style: _ts(size: 9, bold: true)),
        ]),
      ),
      pw.SizedBox(height: 6),
      if (rows.isEmpty) _empty('لا يوجد طلاب مطابقون للمعايير المحددة'),
      if (rows.isNotEmpty)
        _table(['م', 'الرقم الأكاديمي', 'اسم الطالب', 'التخصص', 'المستوى', 'المحاضرات', 'الغياب', 'النسبة', 'الحالة'], trows, widths: {
          0: const pw.FlexColumnWidth(0.5),
          1: const pw.FlexColumnWidth(1.3),
          2: const pw.FlexColumnWidth(2.6),
          3: const pw.FlexColumnWidth(1.6),
          4: const pw.FlexColumnWidth(1.2),
          5: const pw.FlexColumnWidth(0.9),
          6: const pw.FlexColumnWidth(0.8),
          7: const pw.FlexColumnWidth(0.9),
          8: const pw.FlexColumnWidth(1.4)
        }),
    ]));
    return ReportOutput(
      pdf: await doc.save(),
      title: type.title,
      excelHeaders: const ['م', 'الرقم الأكاديمي', 'اسم الطالب', 'التخصص', 'المستوى', 'المحاضرات', 'الغياب', 'نسبة الغياب %', 'الحالة', 'النطاق'],
      excelRows: excel,
      fileBase: type.fileKey,
    );
  }

  // ======================================================= system stats

  Future<ReportOutput> _systemStats() async {
    final st = await repo.stats();
    final levels = await repo.gradeLevels();
    final doc = _doc();
    final items = <(String, String)>[
      ('إجمالي الطلاب', TextUtils.fmtCount(st.totalStudents)),
      ('طلاب لديهم درجات', TextUtils.fmtCount(st.withGrades)),
      ('طلاب لديهم حضور', TextUtils.fmtCount(st.withAttendance)),
      ('سجلات الدرجات', TextUtils.fmtCount(st.gradeRecords)),
      ('سجلات الحضور', TextUtils.fmtCount(st.attendanceRecords)),
      ('عدد المستويات', '${levels.length}'),
      ('آخر تحديث', st.lastUpdate == '-' ? '-' : st.lastUpdate.replaceFirst('T', ' ').split('.').first),
      ('حجم قاعدة البيانات', st.dbSizeBytes > 0 ? '${(st.dbSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB' : '-'),
    ];
    doc.addPage(_page(children: [
      _titleBar(ReportType.systemStats.title),
      pw.SizedBox(height: 6),
      _table(['البند', 'القيمة'], [
        for (final i in items) [_c(i.$1, bold: true, size: 9, align: pw.Alignment.centerRight), _c(i.$2, size: 9, bold: true, color: ReportService._greenDark)]
      ], widths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)}),
      pw.SizedBox(height: 10),
      if (st.totalStudents > 0) ...[
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('نسبة التغطية', style: _ts(size: 10, bold: true))),
        pw.SizedBox(height: 4),
        _bar('الدرجات', st.withGrades / st.totalStudents),
        _bar('الحضور', st.withAttendance / st.totalStudents),
      ],
    ]));
    return ReportOutput(pdf: await doc.save(), title: ReportType.systemStats.title, excelHeaders: const ['البند', 'القيمة'], excelRows: [for (final i in items) [i.$1, i.$2]], fileBase: 'system_stats');
  }

  pw.Widget _bar(String l, double f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Text('${(f * 100).toStringAsFixed(1)}%', style: _ts(size: 8, bold: true)),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Stack(children: [
              pw.Container(height: 10, decoration: pw.BoxDecoration(color: ReportService._greenLight, borderRadius: pw.BorderRadius.circular(3))),
              pw.Container(height: 10, width: 400 * f.clamp(0, 1), decoration: pw.BoxDecoration(color: ReportService._green, borderRadius: pw.BorderRadius.circular(3))),
            ]),
          ),
          pw.SizedBox(width: 6),
          pw.SizedBox(width: 60, child: pw.Text(l, style: _ts(size: 8), textAlign: pw.TextAlign.right)),
        ]),
      );

  // ======================================================= top students

  Future<ReportOutput> _topStudents(String level) async {
    final rows = await repo.topStudents(level, limit: 10);
    final doc = _doc();
    final excel = <List<Object?>>[];
    final trows = <List<pw.Widget>>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final g = GradeLogic.gpaGrade(r.gpa);
      trows.add([
        _c('${i + 1}', bold: true, size: 9),
        _c(r.academicId, bold: true),
        _c(r.name, align: pw.Alignment.centerRight, size: 9),
        _c(r.gpa.toStringAsFixed(2), bold: true, size: 9),
        _c(g, bold: true, color: ReportService._pc(GradeLogic.gradeColor(g).toARGB32())),
      ]);
      excel.add([i + 1, r.academicId, r.name, double.parse(r.gpa.toStringAsFixed(2)), g]);
    }
    doc.addPage(_page(children: [
      _titleBar('${ReportType.topStudents.title} — $level'),
      pw.SizedBox(height: 6),
      if (rows.isEmpty) _empty('لا توجد بيانات لهذا المستوى'),
      if (rows.isNotEmpty)
        _table(['الترتيب', 'الرقم الأكاديمي', 'اسم الطالب', 'المعدل التراكمي', 'التقدير'], trows,
            widths: {0: const pw.FlexColumnWidth(0.7), 1: const pw.FlexColumnWidth(1.4), 2: const pw.FlexColumnWidth(3), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.2)}),
    ]));
    return ReportOutput(pdf: await doc.save(), title: ReportType.topStudents.title, excelHeaders: const ['الترتيب', 'الرقم الأكاديمي', 'اسم الطالب', 'المعدل التراكمي', 'التقدير'], excelRows: excel, fileBase: 'top_students');
  }
}
