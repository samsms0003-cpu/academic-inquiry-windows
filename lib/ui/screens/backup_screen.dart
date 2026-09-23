import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/text_utils.dart';
import '../../services/backup_service.dart';
import '../../services/file_saver.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'import_screen.dart';

/// النسخ الاحتياطي والاستعادة.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  double _p = 0;
  String _msg = '';
  String? _log;
  List<io.File> _internal = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInternal());
  }

  Future<void> _loadInternal() async {
    final l = await FileSaver.listInternalBackups();
    if (mounted) setState(() => _internal = l);
  }

  Future<void> _export({required bool json}) async {
    final state = context.read<AppState>();
    if (state.stats.totalStudents == 0) {
      showSnack(context, 'لا توجد بيانات لتصديرها', warning: true);
      return;
    }
    setState(() {
      _busy = true;
      _p = 0;
      _msg = 'التحضير...';
      _log = null;
    });
    final sw = Stopwatch()..start();
    try {
      final svc = BackupService(state.repo);
      void prog(double f, String m) {
        if (mounted) {
          setState(() {
            _p = f;
            _msg = m;
          });
        }
      }
      final bytes = json ? await svc.buildJson(onProgress: prog) : await svc.buildXlsx(onProgress: prog);
      final name = 'student_data_backup_${BackupService.stamp()}.${json ? 'json' : 'xlsx'}';
      setState(() => _msg = 'حفظ الملف...');
      final path = await FileSaver.save(name, bytes);
      sw.stop();
      if (path != null) {
        await FileSaver.saveInternalBackup(name, bytes);
        _loadInternal();
        setState(() => _log = 'تم التصدير بنجاح\nالملف: $name\nالحجم: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB\n'
            'الدرجات: ${TextUtils.fmtCount(state.stats.gradeRecords)} | الحضور: ${TextUtils.fmtCount(state.stats.attendanceRecords)}\nالزمن: ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)} ث');
        if (mounted) showSnack(context, 'تم حفظ النسخة الاحتياطية');
      } else {
        setState(() => _log = 'تم إلغاء الحفظ');
      }
    } catch (e) {
      setState(() => _log = 'فشل التصدير: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreInternal(io.File f) async {
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportScreen(restoreMode: true, initialFile: (f.uri.pathSegments.last, bytes))));
    if (mounted) context.read<AppState>().refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>().stats;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: AppColors.goldLight,
              child: ListTile(
                leading: Icon(Icons.security, color: AppColors.gold),
                title: Text('تنبيه أمني', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                subtitle: Text('ملفات النسخ الاحتياطية تحتوي على بيانات أكاديمية حساسة. احفظها في مكان آمن ولا تشاركها بلا ضرورة.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
              ),
            ),
            const SectionTitle('البيانات الحالية', icon: Icons.storage),
            Row(children: [
              Expanded(child: StatCard(label: 'الطلاب', value: TextUtils.fmtCount(st.totalStudents), icon: Icons.groups)),
              const SizedBox(width: 8),
              Expanded(child: StatCard(label: 'الدرجات', value: TextUtils.fmtCount(st.gradeRecords), icon: Icons.school, color: AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: StatCard(label: 'الحضور', value: TextUtils.fmtCount(st.attendanceRecords), icon: Icons.fact_check, color: AppColors.success)),
            ]),
            const SectionTitle('تصدير', icon: Icons.upload),
            ActionTile(title: 'نسخة احتياطية كاملة (XLSX)', subtitle: 'أوراق Grades وAttendance وInstructions — متوافقة مع الاستعادة', icon: Icons.table_view, color: AppColors.success, onTap: _busy ? null : () => _export(json: false)),
            const SizedBox(height: 8),
            ActionTile(title: 'نسخة JSON (للاستخدام التقني)', subtitle: 'بنية بيانات كاملة لأغراض الترحيل والتكامل', icon: Icons.data_object, color: AppColors.info, onTap: _busy ? null : () => _export(json: true)),
            const SectionTitle('استعادة', icon: Icons.download),
            ActionTile(
              title: 'استعادة نسخة XLSX أو JSON',
              subtitle: 'التحقق من البنية، معاينة العدد، ثم دمج أو استبدال مع نسخة أمان تلقائية',
              icon: Icons.restore,
              color: AppColors.gold,
              onTap: _busy
                  ? null
                  : () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen(restoreMode: true)));
                      if (context.mounted) context.read<AppState>().refreshStats();
                    },
            ),
            if (_busy) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    LinearProgressIndicator(value: _p, minHeight: 10, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 8),
                    Text(_msg, style: const TextStyle(fontSize: 12)),
                    Text('${(_p * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
                  ]),
                ),
              ),
            ],
            if (_log != null) ...[
              const SectionTitle('سجل العملية', icon: Icons.receipt_long),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_log!, style: const TextStyle(fontSize: 12, height: 1.7)))),
            ],
            if (!kIsWeb && _internal.isNotEmpty) ...[
              const SectionTitle('نسخ الأمان الداخلية (آخر 10)', icon: Icons.folder_special),
              Card(
                child: Column(children: [
                  for (final f in _internal)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file, color: AppColors.gold),
                      title: Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(0)} KB • ${f.lastModifiedSync().toString().split('.').first}', style: const TextStyle(fontSize: 10)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'حفظ خارجيًا',
                          icon: const Icon(Icons.save_alt, size: 20),
                          onPressed: () async {
                            final b = await f.readAsBytes();
                            final p = await FileSaver.save(f.uri.pathSegments.last, b);
                            if (context.mounted && p != null) showSnack(context, 'تم الحفظ');
                          },
                        ),
                        if (f.path.endsWith('.xlsx') || f.path.endsWith('.json')) IconButton(tooltip: 'استعادة', icon: const Icon(Icons.restore, size: 20), onPressed: () => _restoreInternal(f)),
                      ]),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
