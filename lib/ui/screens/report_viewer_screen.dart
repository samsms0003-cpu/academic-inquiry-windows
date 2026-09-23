import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models.dart';
import '../../services/backup_service.dart';
import '../../services/file_saver.dart';
import '../../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// عارض التقرير: معاينة PDF أصلية + طباعة + حفظ PDF + تصدير Excel.
class ReportViewerScreen extends StatefulWidget {
  const ReportViewerScreen({super.key, required this.type, this.student, this.params = const ReportParams()});
  final ReportType type;
  final Student? student;
  final ReportParams params;

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  ReportOutput? _out;
  String? _error;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<void> _build() async {
    setState(() {
      _out = null;
      _error = null;
    });
    final state = context.read<AppState>();
    final sw = Stopwatch()..start();
    try {
      final out = await ReportService(state.repo, state).build(widget.type, student: widget.student, params: widget.params);
      sw.stop();
      if (mounted) {
        setState(() {
          _out = out;
          _elapsed = sw.elapsed;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String get _fileName => '${_out!.fileBase}_${BackupService.stamp()}';

  Future<void> _savePdf() async {
    final p = await FileSaver.save('$_fileName.pdf', _out!.pdf, mime: 'application/pdf');
    if (mounted && p != null) showSnack(context, 'تم حفظ ملف PDF');
  }

  Future<void> _saveXlsx() async {
    final bytes = _out!.toXlsx();
    final p = await FileSaver.save('$_fileName.xlsx', bytes);
    if (mounted && p != null) showSnack(context, 'تم تصدير ملف Excel (${_out!.excelRows.length} صف)');
  }

  Future<void> _share() => FileSaver.share('$_fileName.pdf', _out!.pdf, text: _out!.title);

  Future<void> _print() => Printing.layoutPdf(onLayout: (_) async => _out!.pdf, name: _out!.title);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.title, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: state.showReportHeader ? 'إخفاء الترويسة' : 'إظهار الترويسة',
            icon: Icon(state.showReportHeader ? Icons.vertical_align_top : Icons.crop_7_5),
            onPressed: () async {
              await state.setShowReportHeader(!state.showReportHeader);
              _build();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? EmptyState(icon: Icons.error_outline, title: 'تعذر إنشاء التقرير', subtitle: _error, action: FilledButton(onPressed: _build, child: const Text('إعادة المحاولة')))
            : _out == null
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('جاري إنشاء التقرير...')]))
                : Column(
                    children: [
                      Expanded(
                        child: PdfPreview(
                          build: (_) async => _out!.pdf,
                          useActions: false,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          allowPrinting: false,
                          allowSharing: false,
                          pdfPreviewPageDecoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
                          scrollViewDecoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                          loadingWidget: const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_out!.excelRows.length} صف بيانات • أُنشئ في ${_elapsed.inMilliseconds} ms', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: FilledButton.icon(onPressed: _print, icon: const Icon(Icons.print, size: 18), label: const Text('طباعة', style: TextStyle(fontSize: 12)))),
                                const SizedBox(width: 6),
                                Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: _savePdf, icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text('PDF', style: TextStyle(fontSize: 12)))),
                                const SizedBox(width: 6),
                                Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.success), onPressed: _saveXlsx, icon: const Icon(Icons.table_view, size: 18), label: const Text('Excel', style: TextStyle(fontSize: 12)))),
                                const SizedBox(width: 6),
                                IconButton.outlined(tooltip: 'مشاركة', onPressed: _share, icon: const Icon(Icons.share, size: 20)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
