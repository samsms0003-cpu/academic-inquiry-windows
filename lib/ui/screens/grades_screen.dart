import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/text_utils.dart';
import '../../domain/grade_logic.dart';
import '../../domain/models.dart';
import '../../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'report_viewer_screen.dart';

/// شاشة الدرجات: مجمعة حسب المستوى والعام ← الفصل، مع ملخصات كما في النظام الحالي.
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, required this.student});
  final Student student;
  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<LevelGroup>? _groups;
  bool _detailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final g = await context.read<AppState>().repo.gradesFor(widget.student.academicId);
    if (mounted) setState(() => _groups = GradeLogic.groupGrades(g, fallbackYear: widget.student.academicYear));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('درجات: ${widget.student.name}', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _detailed ? 'عرض مختصر' : 'عرض كل الحقول',
            icon: Icon(_detailed ? Icons.view_agenda : Icons.view_column),
            onPressed: () => setState(() => _detailed = !_detailed),
          ),
          IconButton(
            tooltip: 'تقرير PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: _detailed ? ReportType.gradesDetailed : ReportType.gradesSummary, student: widget.student))),
          ),
        ],
      ),
      body: SafeArea(
        child: _groups == null
            ? const Center(child: CircularProgressIndicator())
            : _groups!.isEmpty
                ? const EmptyState(icon: Icons.school_outlined, title: 'لا توجد بيانات درجات')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _groups!.length,
                    itemBuilder: (c, i) => _LevelCard(group: _groups![i], detailed: _detailed),
                  ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.group, required this.detailed});
  final LevelGroup group;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final ls = group.summary;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.green,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.layers, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${group.level} — العام الدراسي ${group.academicYear}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ),
          for (final s in group.sortedSemesters) _SemesterBlock(sem: s, detailed: detailed),
          _SummaryBar(title: 'ملخص ${group.level}', s: ls, dark: true),
        ],
      ),
    );
  }
}

class _SemesterBlock extends StatelessWidget {
  const _SemesterBlock({required this.sem, required this.detailed});
  final SemesterGroup sem;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: isDark ? AppColors.gold.withValues(alpha: 0.2) : AppColors.goldLight,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text('الفصل الدراسي ${sem.semester}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            horizontalMargin: 10,
            headingRowHeight: 38,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            columns: [
              const DataColumn(label: Text('م')),
              if (detailed) const DataColumn(label: Text('معرف المادة')),
              const DataColumn(label: Text('اسم المادة')),
              const DataColumn(label: Text('المجموع')),
              const DataColumn(label: Text('التقدير')),
              const DataColumn(label: Text('احتساب')),
              const DataColumn(label: Text('مبقي')),
              if (detailed) ...[
                const DataColumn(label: Text('الحضور')),
                const DataColumn(label: Text('المشاركة')),
                const DataColumn(label: Text('أعمال الفصل')),
                const DataColumn(label: Text('النصفي')),
                const DataColumn(label: Text('النهائي')),
                const DataColumn(label: Text('ملاحظات')),
              ],
            ],
            rows: [
              for (var i = 0; i < sem.subjects.length; i++) _row(i + 1, sem.subjects[i]),
            ],
          ),
        ),
        _SummaryBar(title: 'ملخص ${sem.semester}', s: sem.summary),
      ],
    );
  }

  DataRow _row(int idx, GradeRecord g) {
    final grade = g.grade.isEmpty ? GradeLogic.gradeFromScore(g.total ?? 0) : g.grade;
    final fail = GradeLogic.isFailGrade(grade);
    final failColor = fail ? const Color(0xFFDC2626) : null;
    final failBg = fail ? const Color(0xFFFECACA) : null;
    Widget cell(String t, {Color? color, Color? bg, bool bold = false}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: Alignment.center,
          child: Text(t, style: TextStyle(color: color, fontWeight: bold || fail ? FontWeight.w700 : null, fontSize: 12)),
        );
    return DataRow(cells: [
      DataCell(cell('$idx')),
      if (detailed) DataCell(cell(g.subjectId)),
      DataCell(SizedBox(width: 140, child: Text(g.subjectName.isEmpty ? 'غير مسماة' : g.subjectName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis))),
      DataCell(cell(TextUtils.fmtNum(g.total), color: failColor, bg: failBg)),
      DataCell(cell(grade, color: failColor ?? GradeLogic.gradeColor(grade), bg: failBg, bold: true)),
      DataCell(cell(TextUtils.fmtNum(g.courseCounted))),
      DataCell(g.isRemaining ? const StatusChip('نعم', color: AppColors.danger) : cell(g.remaining.isEmpty ? 'لا' : g.remaining)),
      if (detailed) ...[
        DataCell(cell(TextUtils.fmtNum(g.attendanceScore))),
        DataCell(cell(TextUtils.fmtNum(g.participation))),
        DataCell(cell(TextUtils.fmtNum(g.coursework))),
        DataCell(cell(TextUtils.fmtNum(g.midterm))),
        DataCell(cell(TextUtils.fmtNum(g.finalExam))),
        DataCell(SizedBox(width: 120, child: Text(g.notes, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis))),
      ],
    ]);
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.title, required this.s, this.dark = false});
  final String title;
  final GroupSummary s;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.greenDark : (isDarkTheme ? const Color(0xFF1E3A2E) : AppColors.greenLight);
    final fg = dark ? Colors.white : (isDarkTheme ? Colors.white : AppColors.greenDark);
    final gradeColor = s.isMunawwal ? AppColors.gold : (dark ? AppColors.gold : GradeLogic.gradeColor(s.displayGrade));
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12))),
          _item('المعدل', s.displayAverage, fg),
          const SizedBox(width: 14),
          _item('المجموع', s.displayTotal, fg),
          const SizedBox(width: 14),
          _item('التقدير', s.displayGrade, gradeColor),
        ],
      ),
    );
  }

  Widget _item(String l, String v, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(l, style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 10)),
          Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      );
}
