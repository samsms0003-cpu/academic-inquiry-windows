import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models.dart';
import '../../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'report_viewer_screen.dart';

/// شاشة التقارير: الأنواع الثمانية مع نوافذ إعدادات للتقارير الجماعية.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<Student?> _pickStudent(BuildContext context) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: state.lastStudent?.academicId ?? '');
    final id = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اختر الطالب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم الأكاديمي'), onSubmitted: (v) => Navigator.pop(c, v)),
            if (state.recentStudents.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Align(alignment: AlignmentDirectional.centerStart, child: Text('الأخيرون:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Wrap(spacing: 6, children: [for (final s in state.recentStudents.take(5)) ActionChip(label: Text(s.name.split(' ').take(2).join(' '), style: const TextStyle(fontSize: 11)), onPressed: () => Navigator.pop(c, s.academicId))]),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('متابعة'))],
      ),
    );
    if (id == null || id.trim().isEmpty) return null;
    final s = await state.repo.findByAcademicId(id);
    if (s == null && context.mounted) showSnack(context, 'الرقم الأكاديمي غير موجود', error: true);
    if (s != null) state.rememberStudent(s);
    return s;
  }

  Future<void> _openStudentReport(BuildContext context, ReportType t) async {
    final s = await _pickStudent(context);
    if (s == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: t, student: s)));
  }

  Future<void> _openGroup(BuildContext context, ReportType t) async {
    final params = await showDialog<ReportParams>(context: context, builder: (_) => _AbsenceFilterDialog(bySubject: t == ReportType.subjectAbsence));
    if (params == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: t, params: params)));
  }

  Future<void> _openTop(BuildContext context) async {
    final repo = context.read<AppState>().repo;
    final levels = await repo.gradeLevels();
    if (!context.mounted) return;
    if (levels.isEmpty) {
      showSnack(context, 'لا توجد بيانات درجات', warning: true);
      return;
    }
    final level = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('اختر المستوى'),
        children: [for (final l in levels) SimpleDialogOption(onPressed: () => Navigator.pop(c, l), child: Text(l))],
      ),
    );
    if (level == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: ReportType.topStudents, params: ReportParams(level: level))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('لكل تقرير خيارات مستقلة للعرض والطباعة والتصدير إلى PDF وExcel.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SectionTitle('تقارير الطالب', icon: Icons.person),
            ActionTile(title: '1. بيان درجات الطالب المفصل', subtitle: 'كل الحقول العشرون — اتجاه أفقي', icon: Icons.table_chart, onTap: () => _openStudentReport(context, ReportType.gradesDetailed)),
            const SizedBox(height: 8),
            ActionTile(title: '2. بيان درجات الطالب المجمل', subtitle: 'حسب المستوى والفصل مع المعدل والتقدير', icon: Icons.summarize, onTap: () => _openStudentReport(context, ReportType.gradesSummary)),
            const SizedBox(height: 8),
            ActionTile(title: '3. تقرير حضور وغياب الطالب', subtitle: 'إشعار بحالة الطالب حسب المادة', icon: Icons.assignment_turned_in, color: AppColors.success, onTap: () => _openStudentReport(context, ReportType.attendanceSummary)),
            const SizedBox(height: 8),
            ActionTile(title: '4. تقرير الحضور التفصيلي', subtitle: 'كل المحاضرات بالتاريخين', icon: Icons.list_alt, color: AppColors.success, onTap: () => _openStudentReport(context, ReportType.attendanceDetailed)),
            const SectionTitle('التقارير الجماعية', icon: Icons.groups),
            ActionTile(title: '5. تقرير الغياب الجماعي حسب الفصل', subtitle: 'اختيار الفصل ونسبة الغياب الدنيا (افتراضي 40%)', icon: Icons.group_off, color: AppColors.danger, onTap: () => _openGroup(context, ReportType.classAbsence)),
            const SizedBox(height: 8),
            ActionTile(title: '6. تقرير الغياب حسب المادة', subtitle: 'الفصل ← المادة ← النسبة', icon: Icons.menu_book, color: AppColors.danger, onTap: () => _openGroup(context, ReportType.subjectAbsence)),
            const SectionTitle('تقارير النظام', icon: Icons.analytics),
            ActionTile(title: '7. تقرير إحصائيات النظام', subtitle: 'الطلاب والسجلات والتغطية', icon: Icons.bar_chart, color: AppColors.info, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportViewerScreen(type: ReportType.systemStats)))),
            const SizedBox(height: 8),
            ActionTile(title: '8. قائمة الطلاب المتفوقين', subtitle: 'أفضل 10 حسب المعدل التراكمي للمستوى', icon: Icons.emoji_events, color: AppColors.gold, onTap: () => _openTop(context)),
          ],
        ),
      ),
    );
  }
}

class _AbsenceFilterDialog extends StatefulWidget {
  const _AbsenceFilterDialog({required this.bySubject});
  final bool bySubject;
  @override
  State<_AbsenceFilterDialog> createState() => _AbsenceFilterDialogState();
}

class _AbsenceFilterDialogState extends State<_AbsenceFilterDialog> {
  List<String> _sems = [];
  List<String> _subs = [];
  String? _sem, _sub;
  double _pct = 40;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final s = await repo.attendanceSemesters();
    if (!mounted) return;
    setState(() {
      _sems = s;
      _loading = false;
    });
  }

  Future<void> _loadSubjects() async {
    final repo = context.read<AppState>().repo;
    final s = await repo.attendanceSubjects(semester: _sem);
    if (mounted) {
      setState(() {
        _subs = s;
        _sub = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGo = !widget.bySubject || (_sem != null && _sub != null);
    return AlertDialog(
      title: Text(widget.bySubject ? 'تقرير الغياب حسب المادة' : 'تقرير الغياب حسب الفصل'),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _sem,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
                    items: [
                      if (!widget.bySubject) const DropdownMenuItem<String?>(value: null, child: Text('جميع الفصول')),
                      ..._sems.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e))),
                    ],
                    onChanged: (v) {
                      setState(() => _sem = v);
                      if (widget.bySubject) _loadSubjects();
                    },
                  ),
                  if (widget.bySubject) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: _sub,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'المادة', helperText: _sem == null ? 'اختر الفصل أولًا' : '${_subs.length} مادة'),
                      items: _subs.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _sem == null ? null : (v) => setState(() => _sub = v),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    const Text('نسبة الغياب الدنيا', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text('${_pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 16)),
                  ]),
                  Slider(value: _pct, min: 0, max: 100, divisions: 100, label: '${_pct.toStringAsFixed(0)}%', onChanged: (v) => setState(() => _pct = v)),
                  const Text('يعرض الطلاب الذين تساوي نسبة غيابهم هذه القيمة أو تتجاوزها', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: canGo ? () => Navigator.pop(context, ReportParams(semester: _sem, subject: _sub, minPercent: _pct)) : null,
          icon: const Icon(Icons.visibility),
          label: const Text('عرض التقرير'),
        ),
      ],
    );
  }
}
