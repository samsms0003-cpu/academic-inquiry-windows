import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models.dart';
import '../../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'attendance_screen.dart';
import 'grades_screen.dart';
import 'report_viewer_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key, required this.student, this.initialReport});
  final Student student;
  final ReportType? initialReport;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late Student _s = widget.student;
  int _gradesCount = 0, _attCount = 0;
  bool _loading = true;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notes.text = _s.notes;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (widget.initialReport != null && mounted) _openReport(widget.initialReport!);
    });
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final g = await repo.gradesFor(_s.academicId);
    final a = await repo.attendanceFor(_s.academicId);
    final fresh = await repo.findByAcademicId(_s.academicId);
    if (!mounted) return;
    setState(() {
      _gradesCount = g.length;
      _attCount = a.length;
      if (fresh != null) _s = fresh;
      _loading = false;
    });
  }

  void _openReport(ReportType t) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: t, student: _s)));
  }

  Future<void> _saveNotes() async {
    await context.read<AppState>().repo.saveNotes(_s.academicId, _notes.text.trim());
    if (mounted) showSnack(context, 'تم حفظ الملاحظات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملف الطالب')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ------------------------------------------------ بطاقة البيانات
            Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark], begin: Alignment.topRight, end: Alignment.bottomLeft),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.green, size: 30)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_s.name.isEmpty ? 'بدون اسم' : _s.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                                child: Text(_s.academicId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _kv('التخصص', _s.major),
                    _kv('العام الدراسي', _s.academicYear),
                    _kv('المستوى', _s.level),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ------------------------------------------------ ملخص سريع
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'سجلات الدرجات',
                    value: _loading ? '…' : '$_gradesCount',
                    icon: Icons.school,
                    color: AppColors.info,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GradesScreen(student: _s))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: 'سجلات الحضور',
                    value: _loading ? '…' : '$_attCount',
                    icon: Icons.fact_check,
                    color: AppColors.success,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(student: _s))),
                  ),
                ),
              ],
            ),

            const SectionTitle('العرض', icon: Icons.visibility),
            ActionTile(
              title: 'بيان الدرجات',
              subtitle: 'مجمعة حسب المستوى والعام ثم الفصل',
              icon: Icons.grading,
              color: AppColors.info,
              onTap: _gradesCount == 0 ? () => showSnack(context, 'لا توجد بيانات درجات لهذا الطالب', warning: true) : () => Navigator.push(context, MaterialPageRoute(builder: (_) => GradesScreen(student: _s))),
            ),
            const SizedBox(height: 8),
            ActionTile(
              title: 'الحضور والغياب',
              subtitle: 'جدول قابل للتصفية حسب الفصل والمادة والحالة',
              icon: Icons.event_available,
              color: AppColors.success,
              onTap: _attCount == 0 ? () => showSnack(context, 'لا توجد بيانات حضور لهذا الطالب', warning: true) : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(student: _s))),
            ),

            const SectionTitle('التقارير (عرض / طباعة / PDF / Excel)', icon: Icons.print),
            ActionTile(title: 'بيان الدرجات المجمل', subtitle: 'صفحة لكل مستوى/عام مع ملخص الفصول', icon: Icons.summarize, onTap: () => _openReport(ReportType.gradesSummary)),
            const SizedBox(height: 8),
            ActionTile(title: 'بيان الدرجات التفصيلي', subtitle: 'كل الحقول العشرون بالاتجاه الأفقي', icon: Icons.table_chart, onTap: () => _openReport(ReportType.gradesDetailed)),
            const SizedBox(height: 8),
            ActionTile(title: 'إشعار بحالة الطالب (ملخص الحضور)', subtitle: 'حسب الفصل والمادة مع الحالة', icon: Icons.assignment_turned_in, color: AppColors.success, onTap: () => _openReport(ReportType.attendanceSummary)),
            const SizedBox(height: 8),
            ActionTile(title: 'تقرير الحضور التفصيلي', subtitle: 'كل المحاضرات بالتاريخ الهجري والميلادي', icon: Icons.list_alt, color: AppColors.success, onTap: () => _openReport(ReportType.attendanceDetailed)),

            const SectionTitle('ملاحظات', icon: Icons.note_alt_outlined),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(hintText: 'ملاحظات خاصة بالطالب...')),
                    const SizedBox(height: 8),
                    Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: _saveNotes, icon: const Icon(Icons.save), label: const Text('حفظ الملاحظات'))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 100, child: Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(child: Text(v.isEmpty ? '-' : v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}
