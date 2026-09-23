import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/grade_logic.dart';
import '../../domain/models.dart';
import '../../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'report_viewer_screen.dart';

/// شاشة الحضور والغياب مع تصفية حسب الفصل والمادة والحالة.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.student});
  final Student student;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceRecord>? _all;
  String? _sem, _sub, _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final r = await context.read<AppState>().repo.attendanceFor(widget.student.academicId);
    if (mounted) setState(() => _all = r);
  }

  List<AttendanceRecord> get _filtered => (_all ?? [])
      .where((r) => (_sem == null || r.semester == _sem) && (_sub == null || r.subjectName == _sub) && (_status == null || r.status == _status))
      .toList();

  @override
  Widget build(BuildContext context) {
    final all = _all ?? [];
    final sems = all.map((e) => e.semester).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => AttendanceLogic.semesterOrder(a) - AttendanceLogic.semesterOrder(b));
    final subs = all.where((e) => _sem == null || e.semester == _sem).map((e) => e.subjectName).where((e) => e.isNotEmpty).toSet().toList()..sort();
    final statuses = all.map((e) => e.status).where((e) => e.isNotEmpty).toSet().toList()..sort();
    final list = _filtered;
    final present = list.where((e) => e.isPresent).length;
    final absent = list.length - present;
    final rate = list.isEmpty ? 0.0 : present / list.length * 100;
    final grouped = AttendanceLogic.group(list);

    return Scaffold(
      appBar: AppBar(
        title: Text('حضور: ${widget.student.name}', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'ملخص الحضور PDF (بالتصفية الحالية)',
            icon: const Icon(Icons.summarize),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: ReportType.attendanceSummary, student: widget.student, params: ReportParams(semester: _sem, subject: _sub, status: _status)))),
          ),
          IconButton(
            tooltip: 'تقرير تفصيلي PDF (بالتصفية الحالية)',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportViewerScreen(type: ReportType.attendanceDetailed, student: widget.student, params: ReportParams(semester: _sem, subject: _sub, status: _status)))),
          ),
        ],
      ),
      body: SafeArea(
        child: _all == null
            ? const Center(child: CircularProgressIndicator())
            : all.isEmpty
                ? const EmptyState(icon: Icons.event_busy, title: 'لا توجد بيانات حضور')
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Row(children: [
                          Expanded(child: _drop('الفصل', sems, _sem, (v) => setState(() {
                                _sem = v;
                                _sub = null;
                              }))),
                          const SizedBox(width: 6),
                          Expanded(child: _drop('المادة', subs, _sub, (v) => setState(() => _sub = v))),
                          const SizedBox(width: 6),
                          Expanded(child: _drop('الحالة', statuses, _status, (v) => setState(() => _status = v))),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(children: [
                          _pill('المحاضرات', '${list.length}', AppColors.textSecondary, Icons.event_note),
                          const SizedBox(width: 6),
                          _pill('حضور', '$present', AppColors.success, Icons.check_circle),
                          const SizedBox(width: 6),
                          _pill('غياب', '$absent', AppColors.danger, Icons.cancel),
                          const SizedBox(width: 6),
                          _pill('النسبة', '${rate.toStringAsFixed(1)}%', AppColors.info, Icons.percent),
                        ]),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          children: [
                            for (final sem in grouped) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                                child: Row(children: [
                                  Expanded(child: Text(sem.semester, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                                  StatusChip(sem.status.text, color: sem.status.color, bg: sem.status.bg),
                                ]),
                              ),
                              for (final sub in sem.sortedSubjects) _SubjectCard(sub: sub),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _drop(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('الكل', style: TextStyle(fontSize: 12))),
        ...items.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _pill(String l, String v, Color c, IconData i) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Icon(i, size: 14, color: c),
            Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
            Text(l, style: TextStyle(color: c, fontSize: 10)),
          ]),
        ),
      );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.sub});
  final SubjectAttendance sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(sub.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Row(children: [
          Text('حضور ${sub.present}  •  غياب ${sub.absent}  •  ${sub.absencePercent.toStringAsFixed(1)}% غياب', style: const TextStyle(fontSize: 11)),
        ]),
        trailing: StatusChip(sub.status.text, color: sub.status.color, bg: sub.status.bg),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('م')),
                DataColumn(label: Text('التاريخ الهجري')),
                DataColumn(label: Text('التاريخ الميلادي')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('ملاحظات')),
              ],
              rows: [
                for (var i = 0; i < sub.records.length; i++)
                  DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(sub.records[i].hijriDate)),
                    DataCell(Text(sub.records[i].gregorianDate)),
                    DataCell(_status(sub.records[i])),
                    DataCell(SizedBox(width: 100, child: Text(sub.records[i].notes, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(AttendanceRecord r) {
    final present = r.isPresent;
    return StatusChip(
      r.status.isEmpty ? 'غياب' : r.status,
      color: present ? AppColors.success : AppColors.danger,
      icon: present ? Icons.check : Icons.close,
    );
  }
}
