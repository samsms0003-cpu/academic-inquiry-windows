import 'dart:convert' show Utf8Codec;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/text_utils.dart';
import '../../domain/models.dart';
import '../../services/backup_service.dart';
import '../../services/file_saver.dart';
import '../../services/import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// شاشة الاستيراد: اختيار ملف (SAF)، معاينة الأوراق والحقول، اختيار الوضع،
/// شريط تقدم حقيقي، تقرير أخطاء قابل للحفظ.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.restoreMode = false, this.initialFile});
  final bool restoreMode;
  /// ملف جاهز (اسم، بايتات) لتحليله مباشرة — يُستخدم لاستعادة نسخة داخلية.
  final (String, Uint8List)? initialFile;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  FilePreview? _preview;
  ImportMode _mode = ImportMode.update;
  bool _busy = false;
  ImportResult? _result;
  String? _error;
  bool _cancel = false;
  ImportProgress _progress = const ImportProgress(0, 0, '');
  List<ImportHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.restoreMode) _mode = ImportMode.update;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
      if (widget.initialFile != null) _analyze(widget.initialFile!.$1, widget.initialFile!.$2);
    });
  }

  Future<void> _loadHistory() async {
    final h = await context.read<AppState>().repo.importHistory(limit: 10);
    if (mounted) setState(() => _history = h);
  }

  ImportService get _svc => ImportService(context.read<AppState>().repo);

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv', 'txt', 'json'], withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (mounted) showSnack(context, 'تعذر قراءة الملف', error: true);
      return;
    }
    await _analyze(f.name, bytes);
  }

  Future<void> _useSample() async {
    try {
      final data = await rootBundle.load('assets/student_data.xlsx');
      await _analyze('student_data.xlsx', data.buffer.asUint8List());
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل الملف التجريبي: $e');
    }
  }

  Future<void> _analyze(String name, Uint8List bytes) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _preview = null;
    });
    try {
      final p = await _svc.preview(name, bytes);
      if (widget.restoreMode && !p.hasData) throw const FormatException('ملف النسخة الاحتياطية يجب أن يحتوي على ورقة Grades أو Attendance على الأقل');
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = e is FormatException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run() async {
    final p = _preview!;
    final state = context.read<AppState>();
    if (_mode == ImportMode.replace) {
      final ok = await confirmDialog(context, title: 'استبدال جميع البيانات', message: 'سيتم مسح كل البيانات الحالية (${TextUtils.fmtCount(state.stats.gradeRecords)} درجة، ${TextUtils.fmtCount(state.stats.attendanceRecords)} حضور) واستبدالها بمحتوى الملف.\nسيتم إنشاء نسخة أمان تلقائية أولًا.', okText: 'استبدال', danger: true);
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _cancel = false;
      _result = null;
      _progress = const ImportProgress(0, 1, 'التحضير...');
    });
    try {
      if (_mode == ImportMode.replace && state.stats.totalStudents > 0) {
        setState(() => _progress = const ImportProgress(0, 1, 'إنشاء نسخة أمان تلقائية...'));
        final b = await BackupService(state.repo).buildXlsx();
        await FileSaver.saveInternalBackup('auto_backup_before_replace_${BackupService.stamp()}.xlsx', b);
      }
      final r = await _svc.run(p, mode: _mode, onProgress: (pr) {
        if (mounted) setState(() => _progress = pr);
      }, isCancelled: () => _cancel);
      await state.refreshStats();
      if (mounted) setState(() => _result = r);
      _loadHistory();
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل الاستيراد: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveErrors() async {
    final log = _result!.errorLog();
    final name = 'import_errors_${BackupService.stamp()}.txt';
    final p = await FileSaver.save(name, Uint8List.fromList(const Utf8Codec().encode(log)));
    if (mounted && p != null) showSnack(context, 'تم حفظ تقرير الأخطاء');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.restoreMode ? 'استعادة نسخة احتياطية' : 'استيراد البيانات';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.restoreMode ? 'اختر ملف نسخة احتياطية .xlsx أو .json أنشأه النظام (يحتوي Grades وAttendance).' : 'اختر ملف Excel (.xlsx) يحتوي على ورقة Grades و/أو Attendance، أو ملف CSV (فاصلة , أو ;) بنفس أسماء الأعمدة، أو نسخة JSON.', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.folder_open), label: const Text('اختيار ملف من الجهاز'))),
                      if (!widget.restoreMode) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _busy ? null : _useSample, child: const Text('ملف تجريبي')),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            if (_busy && _preview == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('تحليل الملف...')]))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(color: AppColors.danger.withValues(alpha: 0.08), child: ListTile(leading: const Icon(Icons.error, color: AppColors.danger), title: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)))),
            ],
            if (_preview != null) ..._previewWidgets(),
            if (_busy && _preview != null) ..._progressWidgets(),
            if (_result != null) ..._resultWidgets(),
            if (_history.isNotEmpty) ...[
              const SectionTitle('سجل الاستيراد', icon: Icons.history),
              Card(
                child: Column(children: [
                  for (final h in _history)
                    ListTile(
                      dense: true,
                      leading: Icon(h.errors > 0 ? Icons.warning_amber : Icons.check_circle, color: h.errors > 0 ? AppColors.warning : AppColors.success, size: 20),
                      title: Text(h.fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      subtitle: Text('${h.importedAt.replaceFirst('T', ' ').split('.').first} • ${TextUtils.fmtCount(h.inserted)} سجل • ${h.skipped} متجاهل • ${h.errors} خطأ • ${h.result}', style: const TextStyle(fontSize: 10)),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _previewWidgets() {
    final p = _preview!;
    return [
      const SectionTitle('معاينة الملف', icon: Icons.preview),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow('اسم الملف', p.fileName),
              InfoRow('الحجم', '${(p.sizeBytes / 1024).toStringAsFixed(1)} KB'),
              InfoRow('عدد الأوراق', '${p.sheets.length}'),
              if (p.isCsv) InfoRow('فاصل CSV', p.csvDelimiter == '\t' ? 'Tab' : '"${p.csvDelimiter}"'),
              if (p.isJson) const InfoRow('النوع', 'نسخة JSON'),
              InfoRow('بصمة الملف', p.fingerprint.substring(0, 16)),
              if (p.alreadyImported)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: StatusChip('تم استيراد هذا الملف سابقًا بنجاح (استيراد تفاضلي: السجلات المتطابقة لن تتغير)', color: AppColors.warning, icon: Icons.info_outline),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final s in p.sheets) _sheetCard(s),
      if (!p.hasData)
        const Card(color: AppColors.goldLight, child: ListTile(leading: Icon(Icons.warning, color: AppColors.warning), title: Text('لم يتم العثور على ورقة Grades أو Attendance بأعمدة صحيحة', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)))),
      if (p.hasData) ...[
        const SectionTitle('وضع الاستيراد', icon: Icons.merge_type),
        Card(
          child: Column(children: [
            RadioGroup<ImportMode>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              child: const Column(children: [
                RadioListTile<ImportMode>(value: ImportMode.append, title: Text('إضافة فقط', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('إدخال السجلات الجديدة وتجاهل المطابقة', style: TextStyle(fontSize: 11))),
                RadioListTile<ImportMode>(value: ImportMode.update, title: Text('إضافة وتحديث المطابق (دمج)', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('تحديث السجلات المطابقة بمفتاح الطالب+المادة+الفصل / الطالب+المادة+التاريخ', style: TextStyle(fontSize: 11))),
                RadioListTile<ImportMode>(value: ImportMode.replace, title: Text('استبدال كل البيانات', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)), subtitle: Text('مسح القاعدة ثم الاستيراد — مع نسخة أمان تلقائية', style: TextStyle(fontSize: 11))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (!_busy)
          FilledButton.icon(
            onPressed: _run,
            style: FilledButton.styleFrom(backgroundColor: _mode == ImportMode.replace ? AppColors.danger : AppColors.green, minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.play_arrow),
            label: Text(widget.restoreMode ? 'بدء الاستعادة' : 'بدء الاستيراد'),
          ),
      ],
    ];
  }

  Widget _sheetCard(SheetPreview s) {
    final kindLabel = switch (s.kind) {
      SheetKind.grades => ('الدرجات (Grades)', AppColors.info, Icons.school),
      SheetKind.attendance => ('الحضور (Attendance)', AppColors.success, Icons.fact_check),
      SheetKind.instructions => ('إرشادات — تُقرأ ولا تُستورد', AppColors.textSecondary, Icons.info_outline),
      SheetKind.unknown => ('غير معروفة — سيتم تجاهلها', AppColors.warning, Icons.help_outline),
    };
    final importable = (s.kind == SheetKind.grades || s.kind == SheetKind.attendance) && s.missingRequired.isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Icon(kindLabel.$3, color: kindLabel.$2),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${kindLabel.$1} • ${TextUtils.fmtCount(s.rowCount)} صف • ${s.mappedColumns.length}/${s.headers.length} حقل معروف', style: const TextStyle(fontSize: 11)),
        trailing: importable ? const Icon(Icons.check_circle, color: AppColors.success) : (s.kind == SheetKind.instructions ? null : const Icon(Icons.block, color: AppColors.textSecondary)),
        children: [
          if (s.missingRequired.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: AlignmentDirectional.centerStart, child: StatusChip('حقول إلزامية مفقودة: ${s.missingRequired.join(', ')}', color: AppColors.danger))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final h in s.headers)
                Chip(
                  label: Text(h, style: const TextStyle(fontSize: 10)),
                  backgroundColor: s.mappedColumns.contains(h) || _isMapped(s, h) ? AppColors.greenLight : AppColors.goldLight,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
          if (s.sampleRows.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DataTable(
                headingRowHeight: 30,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 32,
                columns: s.headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 10)))).toList(),
                rows: s.sampleRows
                    .map((r) => DataRow(cells: List.generate(s.headers.length, (i) => DataCell(Text(i < r.length ? TextUtils.cellToString(r[i]) : '', style: const TextStyle(fontSize: 10))))))
                    .toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _isMapped(SheetPreview s, String h) {
    final n = TextUtils.normalizeHeader(h);
    return s.mappedColumns.any((c) => TextUtils.normalizeHeader(c) == n);
  }

  List<Widget> _progressWidgets() => [
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              LinearProgressIndicator(value: _progress.total > 0 ? _progress.fraction : null, minHeight: 10, borderRadius: BorderRadius.circular(6)),
              const SizedBox(height: 10),
              Text(_progress.message, style: const TextStyle(fontSize: 13)),
              Text('${(_progress.fraction * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green, fontSize: 18)),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _cancel ? null : () => setState(() => _cancel = true), icon: const Icon(Icons.stop_circle_outlined), label: Text(_cancel ? 'جاري الإيقاف بعد الدفعة الحالية...' : 'إيقاف الاستيراد')),
              const Text('البيانات المُدخلة حتى الآن محفوظة داخل معاملات مكتملة ولن تُفقد.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      ];

  List<Widget> _resultWidgets() {
    final r = _result!;
    return [
      const SectionTitle('نتيجة العملية', icon: Icons.task_alt),
      Card(
        color: r.cancelled ? AppColors.goldLight : AppColors.greenLight,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(r.cancelled ? Icons.pause_circle : Icons.check_circle, color: r.cancelled ? AppColors.warning : AppColors.success),
                const SizedBox(width: 8),
                Text(r.cancelled ? 'تم إيقاف الاستيراد (البيانات المُدخلة محفوظة)' : 'اكتمل الاستيراد بنجاح', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
              const Divider(),
              InfoRow('سجلات الدرجات', TextUtils.fmtCount(r.gradesInserted)),
              InfoRow('سجلات الحضور', TextUtils.fmtCount(r.attendanceInserted)),
              InfoRow('صفوف متجاهلة', TextUtils.fmtCount(r.skipped)),
              InfoRow('أخطاء', TextUtils.fmtCount(r.errors.length)),
              InfoRow('الزمن', '${(r.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} ثانية'),
              if (r.elapsed.inMilliseconds > 0) InfoRow('السرعة', '${TextUtils.fmtCount((r.totalInserted / (r.elapsed.inMilliseconds / 1000)).round())} سجل/ثانية'),
              if (r.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('أول الأخطاء:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                for (final e in r.errors.take(5)) Text('• $e', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _saveErrors, icon: const Icon(Icons.save_alt), label: const Text('حفظ تقرير الأخطاء')),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
