import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/text_utils.dart';
import '../../domain/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'import_screen.dart';
import 'scanner_screen.dart';
import 'student_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final void Function(int tab) onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _idCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _idCtrl.text.trim();
    if (raw.isEmpty) {
      showSnack(context, 'يرجى إدخال الرقم الأكاديمي', warning: true);
      return;
    }
    setState(() => _searching = true);
    final state = context.read<AppState>();
    final sw = Stopwatch()..start();
    final s = await state.repo.findByAcademicId(raw);
    sw.stop();
    state.lastSearchTime = sw.elapsed;
    if (!mounted) return;
    setState(() => _searching = false);
    if (s == null) {
      showSnack(context, 'لم يتم العثور على طالب بالرقم ${TextUtils.normalizeDigits(raw)}', error: true);
      return;
    }
    _open(s);
  }

  void _open(Student s) {
    context.read<AppState>().rememberStudent(s);
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileScreen(student: s)));
  }

  Future<void> _scan() async {
    final result = await Navigator.push<ScanResult>(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (result == null || !mounted) return;
    if (result.student != null) {
      _idCtrl.text = result.student!.academicId;
      _open(result.student!);
    } else if (result.command == 'go-back-and-clear') {
      _idCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final st = state.stats;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Image.asset('assets/images/app_icon.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppConstants.appName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(AppConstants.appSubtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'عن النظام', icon: const Icon(Icons.info_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
          IconButton(tooltip: 'الإعدادات', icon: const Icon(Icons.settings_outlined), onPressed: () => widget.onNavigate(3)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refreshStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ---------------------------------------------- بطاقة البحث
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.badge_outlined, color: AppColors.gold),
                        SizedBox(width: 8),
                        Text('الاستعلام بالرقم الأكاديمي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _idCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                        decoration: InputDecoration(
                          hintText: 'مثال: 20260001',
                          hintStyle: const TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0),
                          prefixIcon: const Icon(Icons.numbers),
                          suffixIcon: _idCtrl.text.isEmpty
                              ? null
                              : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _idCtrl.clear())),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                        onPressed: _searching ? null : _search,
                        icon: _searching
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text('استعلام', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner, size: 20), label: const Text('مسح الباركود'))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(onPressed: () => widget.onNavigate(1), icon: const Icon(Icons.person_search, size: 20), label: const Text('بحث بالاسم'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------------------------------------- آخر طالب
              if (state.lastStudent != null) ...[
                const SectionTitle('آخر استعلام', icon: Icons.history),
                Card(
                  color: Theme.of(context).brightness == Brightness.dark ? null : AppColors.greenLight,
                  child: ListTile(
                    onTap: () => _open(state.lastStudent!),
                    leading: const CircleAvatar(backgroundColor: AppColors.green, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(state.lastStudent!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${state.lastStudent!.academicId} • ${state.lastStudent!.level.isEmpty ? '-' : state.lastStudent!.level}', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
              ],

              // ---------------------------------------------- الإحصائيات
              SectionTitle('إحصائيات قاعدة البيانات', icon: Icons.bar_chart,
                  trailing: Text(st.lastUpdate == '-' ? '' : 'آخر تحديث: ${_fmtDate(st.lastUpdate)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
              GridView.count(
                // سطح المكتب: 3 أعمدة ببطاقات منخفضة بدل التمدد العمودي.
                crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: MediaQuery.sizeOf(context).width >= 900 ? 3.4 : 2.3,
                children: [
                  StatCard(label: 'إجمالي الطلاب', value: TextUtils.fmtCount(st.totalStudents), icon: Icons.groups),
                  StatCard(label: 'لديهم درجات', value: TextUtils.fmtCount(st.withGrades), icon: Icons.school, color: AppColors.info),
                  StatCard(label: 'لديهم حضور', value: TextUtils.fmtCount(st.withAttendance), icon: Icons.fact_check, color: AppColors.success),
                  StatCard(label: 'سجلات الدرجات', value: TextUtils.fmtCount(st.gradeRecords), icon: Icons.grading, color: AppColors.gold),
                  StatCard(label: 'سجلات الحضور', value: TextUtils.fmtCount(st.attendanceRecords), icon: Icons.event_available, color: AppColors.warning),
                  StatCard(label: 'حجم القاعدة', value: _fmtBytes(st.dbSizeBytes), icon: Icons.storage, color: AppColors.textSecondary),
                ],
              ),

              if (st.totalStudents == 0) ...[
                const SizedBox(height: 14),
                Card(
                  color: AppColors.goldLight,
                  child: ListTile(
                    leading: const Icon(Icons.upload_file, color: AppColors.gold, size: 32),
                    title: const Text('لا توجد بيانات بعد', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    subtitle: const Text('ابدأ باستيراد ملف Excel يحتوي على ورقتي Grades وAttendance', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    trailing: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())), child: const Text('استيراد')),
                  ),
                ),
              ],

              // ---------------------------------------------- الوصول السريع
              const SectionTitle('الوصول السريع', icon: Icons.grid_view),
              Row(
                children: [
                  Expanded(child: _QuickAction(icon: Icons.description, label: 'التقارير', onTap: () => widget.onNavigate(2))),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.upload_file, label: 'الاستيراد', color: AppColors.info, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())))),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.backup, label: 'النسخ الاحتياطي', color: AppColors.gold, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())))),
                ],
              ),

              // ---------------------------------------------- المطوّر
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                  leading: const CircleAvatar(backgroundColor: AppColors.gold, child: Icon(Icons.code, color: Colors.white)),
                  title: const Text('محمد الصالحي', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('مطوّر ومصمّم واجهات المستخدم • للتواصل والدعم التقني', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.support_agent, color: AppColors.green),
                ),
              ),

              // ---------------------------------------------- الأخيرون
              if (state.recentStudents.length > 1) ...[
                SectionTitle('طلاب تم الاستعلام عنهم مؤخرًا', icon: Icons.people_outline,
                    trailing: TextButton(onPressed: state.clearRecents, child: const Text('مسح', style: TextStyle(fontSize: 12)))),
                Card(
                  child: Column(
                    children: [
                      for (final s in state.recentStudents.skip(1))
                        ListTile(
                          dense: true,
                          onTap: () => _open(s),
                          leading: const Icon(Icons.person_outline),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(s.academicId, style: const TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.chevron_left, size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  static String _fmtBytes(int b) {
    if (b <= 0) return '-';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.color = AppColors.green});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
