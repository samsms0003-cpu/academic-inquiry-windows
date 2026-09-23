import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/text_utils.dart';
import '../../data/app_database.dart';
import '../../domain/models.dart';
import '../../services/backup_service.dart';
import '../../services/file_saver.dart';
import '../../services/xlsx_io.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'import_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearData(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.stats.totalStudents == 0) {
      showSnack(context, 'لا توجد بيانات لمسحها', warning: true);
      return;
    }
    final export = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مسح جميع البيانات'),
        content: Text('سيتم حذف ${TextUtils.fmtCount(state.stats.totalStudents)} طالب و${TextUtils.fmtCount(state.stats.gradeRecords)} درجة و${TextUtils.fmtCount(state.stats.attendanceRecords)} حضور نهائيًا.\n\nهل تريد تصدير نسخة احتياطية قبل المسح؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('مسح بدون نسخة', style: TextStyle(color: AppColors.danger))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تصدير ثم مسح')),
        ],
      ),
    );
    if (export == null) return;
    if (export) {
      final bytes = await BackupService(state.repo).buildXlsx();
      final name = 'backup_before_clear_${BackupService.stamp()}.xlsx';
      await FileSaver.saveInternalBackup(name, bytes);
      final p = await FileSaver.save(name, bytes);
      if (p == null) return;
    }
    if (!context.mounted) return;
    final ok = await confirmDialog(context, title: 'تأكيد نهائي', message: 'اكتب موافقتك بالضغط على "حذف نهائي". لا يمكن التراجع.', okText: 'حذف نهائي', danger: true);
    if (!ok) return;
    await state.repo.clearAllData();
    await state.clearRecents();
    await state.refreshStats();
    if (context.mounted) showSnack(context, 'تم مسح جميع البيانات');
  }

  Future<String?> _askPin(BuildContext context) async {
    final c1 = TextEditingController(), c2 = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('تعيين رمز القفل'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: c1, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'الرمز (4-6 أرقام)')),
            TextField(controller: c2, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: 'تأكيد الرمز', errorText: err)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final p = TextUtils.normalizeDigits(c1.text.trim());
                if (p.length < 4 || !RegExp(r'^\d+\$').hasMatch(p)) {
                  setS(() => err = 'الرمز يجب أن يكون 4 أرقام على الأقل');
                  return;
                }
                if (p != TextUtils.normalizeDigits(c2.text.trim())) {
                  setS(() => err = 'الرمزان غير متطابقين');
                  return;
                }
                Navigator.pop(c, p);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    final kind = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('اختر القالب'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'grades'), child: const Text('قالب الدرجات (Grades)')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'attendance'), child: const Text('قالب الحضور والغياب (Attendance)')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'xlsx'), child: const Text('ملف Excel فارغ بالورقتين')),
      ]),
    );
    if (kind == null) return;
    Uint8List bytes;
    String name;
    if (kind == 'xlsx') {
      final w = XlsxWriter();
      w.addSheet('Grades').addHeader(AppConstants.gradesColumns);
      w.addSheet('Attendance').addHeader(AppConstants.attendanceColumns);
      final ins = w.addSheet('Instructions');
      ins.addHeader(['البند', 'الشرح']);
      ins.addRow(['ورقة Grades', 'صف لكل مادة لكل طالب. المفتاح: الرقم الاكاديمي + معرف المادة + معرف الفصل.']);
      ins.addRow(['ورقة Attendance', 'صف لكل محاضرة. المفتاح: acadym_int + nem_mawad_ar + date_m.']);
      ins.addRow(['تنبيه', 'لا تغيّر أسماء الأعمدة. الرقم الأكاديمي نص للحفاظ على الأصفار.']);
      bytes = w.build();
      name = 'student_data_template.xlsx';
    } else {
      final cols = kind == 'grades' ? AppConstants.gradesColumns : AppConstants.attendanceColumns;
      bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('${cols.join(',')}\n')]);
      name = '${kind}_template.csv';
    }
    final p = await FileSaver.save(name, bytes);
    if (context.mounted && p != null) showSnack(context, 'تم حفظ القالب: $name');
  }

  Future<void> _maintenance(BuildContext context) async {
    final state = context.read<AppState>();
    showDialog(context: context, barrierDismissible: false, builder: (_) => const ProgressDialog(progress: null, message: 'إعادة بناء الفهارس وتحليل القاعدة...'));
    final sw = Stopwatch()..start();
    await AppDatabase.instance.reindex();
    await AppDatabase.instance.vacuum();
    await state.repo.setSetting('lastReindex', DateTime.now().toIso8601String());
    await state.refreshStats();
    sw.stop();
    if (context.mounted) {
      Navigator.pop(context);
      showSnack(context, 'تمت الصيانة في ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} ث');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final st = state.stats;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('المظهر', icon: Icons.palette),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('الوضع'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18), label: Text('فاتح')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18), label: Text('داكن')),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (s) => state.setTheme(s.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('حجم الخط'),
                  subtitle: Slider(value: state.textScale, min: 0.85, max: 1.4, divisions: 11, label: '${(state.textScale * 100).round()}%', onChanged: state.setTextScale),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('خط الواجهة'),
                  trailing: DropdownButton<String>(
                    value: state.uiFont,
                    underline: const SizedBox(),
                    items: [for (final e in AppConstants.fonts.entries) DropdownMenuItem(value: e.key, child: Text(e.value.label, style: TextStyle(fontFamily: e.key, fontSize: 13)))],
                    onChanged: (v) => state.setUiFont(v!),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('خط التقارير (PDF)'),
                  trailing: DropdownButton<String>(
                    value: state.reportFont,
                    underline: const SizedBox(),
                    items: [for (final e in AppConstants.fonts.entries) DropdownMenuItem(value: e.key, child: Text(e.value.label, style: TextStyle(fontFamily: e.key, fontSize: 13)))],
                    onChanged: (v) => state.setReportFont(v!),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('تنسيق التاريخ في التقارير'),
                  trailing: DropdownButton<String>(
                    value: state.dateFormat,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'both', child: Text('هجري وميلادي')),
                      DropdownMenuItem(value: 'hijri', child: Text('هجري')),
                      DropdownMenuItem(value: 'gregorian', child: Text('ميلادي')),
                    ],
                    onChanged: (v) => state.setDateFormat(v!),
                  ),
                ),
              ]),
            ),

            const SectionTitle('التقارير', icon: Icons.print),
            Card(
              child: Column(children: [
                SwitchListTile(value: state.showReportHeader, onChanged: state.setShowReportHeader, secondary: const Icon(Icons.vertical_align_top), title: const Text('إظهار الترويسة في التقارير')),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.edit_document), title: const Text('إدارة الترويسة والشعار'), subtitle: Text(state.headerAr[3], style: const TextStyle(fontSize: 11)), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeaderSettingsScreen()))),
              ]),
            ),

            const SectionTitle('الماسح', icon: Icons.qr_code_scanner),
            Card(
              child: Column(children: [
                SwitchListTile(value: state.scanSound, onChanged: (v) => state.setScanPrefs(sound: v), secondary: const Icon(Icons.vibration), title: const Text('اهتزاز عند المسح')),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bolt),
                  title: const Text('الإجراء بعد مسح طالب'),
                  trailing: DropdownButton<String>(
                    value: state.scanAction,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'profile', child: Text('ملف الطالب')),
                      DropdownMenuItem(value: 'grades-summary', child: Text('بيان الدرجات المجمل')),
                      DropdownMenuItem(value: 'grades-detailed', child: Text('بيان الدرجات التفصيلي')),
                      DropdownMenuItem(value: 'attendance-summary', child: Text('ملخص الحضور')),
                      DropdownMenuItem(value: 'attendance-detailed', child: Text('الحضور التفصيلي')),
                    ],
                    onChanged: (v) => state.setScanPrefs(action: v),
                  ),
                ),
              ]),
            ),

            const SectionTitle('الأمان', icon: Icons.lock_outline),
            Card(
              child: Column(children: [
                SwitchListTile(
                  value: state.pinEnabled,
                  secondary: const Icon(Icons.pin),
                  title: const Text('قفل التطبيق برمز PIN'),
                  subtitle: Text(state.pinEnabled ? 'مفعّل — يُطلب الرمز عند فتح التطبيق أو العودة إليه' : 'غير مفعّل', style: const TextStyle(fontSize: 11)),
                  onChanged: (v) async {
                    if (!v) {
                      await state.setPin(null);
                      return;
                    }
                    final pin = await _askPin(context);
                    if (pin != null) await state.setPin(pin);
                  },
                ),
                if (state.pinEnabled)
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('تغيير الرمز'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      final pin = await _askPin(context);
                      if (pin != null) await state.setPin(pin);
                    },
                  ),
              ]),
            ),

            const SectionTitle('البيانات', icon: Icons.storage),
            ActionTile(title: 'قوالب CSV', subtitle: 'تنزيل قالب الدرجات أو الحضور بأسماء الأعمدة الصحيحة', icon: Icons.download, color: AppColors.textSecondary, onTap: () => _downloadTemplate(context)),
            const SizedBox(height: 8),
            ActionTile(title: 'الاستيراد', subtitle: 'ملفات Excel/CSV', icon: Icons.upload_file, color: AppColors.info, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen()))),
            const SizedBox(height: 8),
            ActionTile(title: 'النسخ الاحتياطي والاستعادة', subtitle: 'XLSX / JSON', icon: Icons.backup, color: AppColors.gold, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
            const SizedBox(height: 8),
            ActionTile(title: 'مسح جميع البيانات', subtitle: 'مع تأكيد مزدوج وخيار تصدير نسخة قبل المسح', icon: Icons.delete_forever, danger: true, onTap: () => _clearData(context)),

            const SectionTitle('التشخيص والصيانة', icon: Icons.build),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow('الطلاب', TextUtils.fmtCount(st.totalStudents)),
                    InfoRow('سجلات الدرجات', TextUtils.fmtCount(st.gradeRecords)),
                    InfoRow('سجلات الحضور', TextUtils.fmtCount(st.attendanceRecords)),
                    InfoRow('حجم القاعدة', st.dbSizeBytes > 0 ? '${(st.dbSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB' : 'غير متاح (Web)'),
                    InfoRow('آخر استيراد', st.lastUpdate == '-' ? '-' : st.lastUpdate.replaceFirst('T', ' ').split('.').first),
                    InfoRow('آخر بحث', state.lastSearchTime == Duration.zero ? '-' : '${state.lastSearchTime.inMicroseconds / 1000} ms'),
                    InfoRow('نسخة المخطط', '${AppDatabase.schemaVersion}'),
                    InfoRow('مسار القاعدة', AppDatabase.instance.path ?? '-'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _maintenance(context), icon: const Icon(Icons.build_circle_outlined), label: const Text('إعادة بناء الفهارس'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfTestScreen())), icon: const Icon(Icons.speed), label: const Text('اختبار الأداء'))),
                    ]),
                    const Text('إعادة بناء الفهارس تُنفذ من هنا فقط، ولا تُنفذ تلقائيًا عند كل تشغيل.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),

            const SectionTitle('عن النظام', icon: Icons.info_outline),
            ActionTile(title: AppConstants.appName, subtitle: 'الإصدار ${AppConstants.appVersion} • ${AppConstants.appSubtitle}', icon: Icons.school, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
          ],
        ),
      ),
    );
  }
}

/// إدارة الترويسة (4 أسطر عربية + 4 إنجليزية + شعار).
class HeaderSettingsScreen extends StatefulWidget {
  const HeaderSettingsScreen({super.key});
  @override
  State<HeaderSettingsScreen> createState() => _HeaderSettingsScreenState();
}

class _HeaderSettingsScreenState extends State<HeaderSettingsScreen> {
  late List<TextEditingController> _ar;
  late List<TextEditingController> _en;
  String? _logo;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _ar = s.headerAr.map((e) => TextEditingController(text: e)).toList();
    _en = s.headerEn.map((e) => TextEditingController(text: e)).toList();
    _logo = s.headerLogoBase64;
  }

  Future<void> _pickLogo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final b = r?.files.firstOrNull?.bytes;
    if (b == null) return;
    if (b.length > 2 * 1024 * 1024) {
      if (mounted) showSnack(context, 'حجم الصورة كبير (الحد 2MB)', warning: true);
      return;
    }
    setState(() => _logo = base64Encode(b));
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = _logo == null ? null : base64Decode(_logo!);
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الترويسة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Container(
                    width: 120,
                    height: 100,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.gold), borderRadius: BorderRadius.circular(12)),
                    child: logoBytes != null ? Image.memory(logoBytes, fit: BoxFit.contain) : Image.asset('assets/images/academy_logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.image), label: const Text('اختيار شعار')),
                    const SizedBox(width: 8),
                    if (_logo != null) TextButton(onPressed: () => setState(() => _logo = null), child: const Text('إزالة الصورة')),
                  ]),
                ]),
              ),
            ),
            const SectionTitle('النص العربي (يمين)', icon: Icons.text_fields),
            for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: _ar[i], decoration: InputDecoration(labelText: 'السطر ${i + 1}'))),
            const SectionTitle('النص الإنجليزي (يسار)', icon: Icons.translate),
            for (var i = 0; i < 4; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: _en[i], textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'Line ${i + 1}'))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.read<AppState>().saveHeader(_ar.map((c) => c.text).toList(), _en.map((c) => c.text).toList(), _logo);
                    if (context.mounted) {
                      showSnack(context, 'تم حفظ إعدادات الترويسة');
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الإعدادات'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'استعادة الافتراضي', message: 'سيتم استعادة النصوص والشعار الافتراضيين.');
                  if (!ok || !context.mounted) return;
                  await context.read<AppState>().resetHeader();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('استعادة الافتراضي'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// اختبار الأداء: توليد بيانات ضخمة وقياس زمن الاستيراد والبحث.
class PerfTestScreen extends StatefulWidget {
  const PerfTestScreen({super.key});
  @override
  State<PerfTestScreen> createState() => _PerfTestScreenState();
}

class _PerfTestScreenState extends State<PerfTestScreen> {
  int _students = 50000;
  bool _busy = false;
  double _p = 0;
  final _log = StringBuffer();

  Future<void> _run() async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(context, title: 'توليد بيانات اختبار', message: 'سيتم إدخال $_students طالب × ~8 درجات و~12 حضور (≈ ${TextUtils.fmtCount(_students * 20)} سجل) في القاعدة الحالية. هذه بيانات اصطناعية لأغراض القياس فقط.', okText: 'بدء');
    if (!ok) return;
    setState(() {
      _busy = true;
      _p = 0;
      _log.clear();
    });
    final repo = state.repo;
    final sw = Stopwatch()..start();
    const batch = 2000;
    final levels = ['المستوى الأول', 'المستوى الثاني', 'المستوى الثالث', 'المستوى الرابع'];
    final subjects = ['التفسير', 'علوم القرآن', 'الحديث الشريف', 'الفقه', 'العقيدة', 'النحو', 'القراءات', 'السيرة'];
    final names = ['أحمد', 'محمد', 'علي', 'حسن', 'عبدالله', 'يوسف', 'إبراهيم', 'خالد', 'عمر', 'سعيد'];
    var total = 0;
    for (var start = 0; start < _students; start += batch) {
      final gl = <dynamic>[];
      final al = <dynamic>[];
      for (var i = start; i < start + batch && i < _students; i++) {
        final id = (90000000 + i).toString();
        final name = '${names[i % 10]} ${names[(i ~/ 10) % 10]} ${names[(i ~/ 100) % 10]} التجريبي';
        final lvIdx = i % 4;
        for (var s = 0; s < 8; s++) {
          final score = 40 + ((i * 7 + s * 13) % 61);
          gl.add({
            'الرقم الاكاديمي': id,
            'اسم الطالب': name,
            'التخصص': 'القرآن الكريم وعلومه',
            'العام الدراسي': '2026/2027',
            'المستوى': levels[lvIdx],
            'الفصل الدراسي': s < 4 ? 'الأول' : 'الثاني',
            'معرف المستوى': lvIdx + 1,
            'معرف الفصل': (lvIdx + 1) * 100 + (s < 4 ? 1 : 2),
            'معرف المادة': 1000 + s,
            'اسم المادة': subjects[s],
            'المجموع': score,
            'التقدير': score >= 90 ? 'ممتاز' : score >= 80 ? 'جيد جداً' : score >= 65 ? 'جيد' : score >= 50 ? 'مقبول' : 'راسب',
            'احتساب المادة': 1,
            'مبقي': score < 50 ? 'نعم' : 'لا',
            'الحضور': 10,
            'المشاركة': 8,
            'أعمال الفصل': 25,
            'الامتحان النصفي': 20,
            'الامتحان النهائي': score - 63 > 0 ? score - 63 : 0,
            'ملاحظات': 'اختبار',
          });
        }
        for (var d = 0; d < 12; d++) {
          al.add({
            'acadym_int': id,
            'AL1': name,
            'NEM_ALGESM_AR': 'القرآن الكريم وعلومه',
            'yer': '2026/2027',
            'mestawa': levels[lvIdx],
            'NEM_FASOL_AR': 'الفصل الأول',
            'nem_mawad_ar': subjects[d % 4],
            'date_m': '1448/01/${(d + 1).toString().padLeft(2, '0')}',
            'date_h': '2026-07-${(d + 1).toString().padLeft(2, '0')}',
            'nem_tahter': (i + d) % 5 == 0 ? 'غياب' : 'حضور',
            'ملاحظات': '',
          });
        }
      }
      await repo.upsertGradesBatch(gl.map((m) => GradeRecord.fromExcelMap(m as Map<String, Object?>)).toList(), updateExisting: false);
      await repo.upsertAttendanceBatch(al.map((m) => AttendanceRecord.fromExcelMap(m as Map<String, Object?>)).toList(), updateExisting: false);
      total += gl.length + al.length;
      if (mounted) setState(() => _p = (start + batch) / _students);
    }
    sw.stop();
    _log.writeln('إدخال ${TextUtils.fmtCount(total)} سجل في ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)} ث (${TextUtils.fmtCount((total / (sw.elapsedMilliseconds / 1000)).round())} سجل/ث)');
    await repo.touchLastUpdate();

    // قياس البحث
    final ids = [90000000, 90000000 + _students ~/ 2, 90000000 + _students - 1];
    for (final id in ids) {
      final s2 = Stopwatch()..start();
      await repo.findByAcademicId(id.toString());
      s2.stop();
      _log.writeln('بحث بالرقم $id: ${(s2.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms');
    }
    final s3 = Stopwatch()..start();
    final r = await repo.searchByName('محمد علي', limit: 50);
    s3.stop();
    _log.writeln('بحث بالاسم "محمد علي" (${r.length} نتيجة): ${s3.elapsedMilliseconds} ms');
    final s4 = Stopwatch()..start();
    final ab = await repo.groupAbsence(minPercent: 15);
    s4.stop();
    _log.writeln('تقرير الغياب الجماعي (${ab.length} طالب): ${s4.elapsedMilliseconds} ms');
    final s5 = Stopwatch()..start();
    await repo.topStudents(levels[0]);
    s5.stop();
    _log.writeln('المتفوقون: ${s5.elapsedMilliseconds} ms');
    await state.refreshStats();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار الأداء')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('يولّد بيانات اصطناعية ويقيس زمن الإدخال والبحث والتقارير. يُفضّل تنفيذه على قاعدة تجريبية ثم مسحها.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Text('عدد الطلاب: ${TextUtils.fmtCount(_students)} (≈ ${TextUtils.fmtCount(_students * 20)} سجل)', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _students.toDouble(), min: 5000, max: 100000, divisions: 19, onChanged: _busy ? null : (v) => setState(() => _students = v.round())),
          FilledButton.icon(onPressed: _busy ? null : _run, icon: const Icon(Icons.play_arrow), label: const Text('بدء الاختبار')),
          if (_busy) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(value: _p, minHeight: 8)),
          if (_log.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_log.toString(), style: const TextStyle(fontSize: 12, height: 1.8)))),
        ]),
      ),
    );
  }
}
