import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/text_utils.dart';
import '../../domain/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ScanResult {
  final Student? student;
  final String? command;
  const ScanResult({this.student, this.command});
}

/// ماسح QR/Barcode أصلي (CameraX + ML Kit عبر mobile_scanner).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.all]);
  final _manual = TextEditingController();
  bool _torch = false;
  bool _handling = false;
  String? _lastCode;
  String? _resultMsg;
  bool _resultOk = false;
  Student? _found;
  String? _foundCmd;
  List<Map<String, Object?>> _history = [];

  /// الكاميرا مدعومة على Android/iOS/Web/macOS فقط؛ على Windows/Linux يُستخدم قارئ باركود USB (يعمل كلوحة مفاتيح).
  bool get _cameraSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    final h = await context.read<AppState>().repo.scanHistory(limit: 10);
    if (mounted) setState(() => _history = h);
  }

  @override
  void dispose() {
    if (_cameraSupported) _ctrl.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _process(String raw) async {
    if (_handling) return;
    _handling = true;
    final code = raw.trim();
    final state = context.read<AppState>();
    if (state.scanSound) HapticFeedback.mediumImpact();
    _lastCode = code;

    // أوامر الباركود CMD-XX
    if (code.startsWith('CMD-')) {
      final cmd = AppConstants.barcodeCommands[code];
      if (cmd != null) {
        await state.repo.addScan(code, null, true);
        setState(() {
          _resultOk = true;
          _resultMsg = 'أمر: ${cmd.name}';
          _found = null;
          _foundCmd = cmd.action;
        });
      } else {
        await state.repo.addScan(code, null, false);
        setState(() {
          _resultOk = false;
          _resultMsg = 'الباركود غير معروف: $code';
          _found = null;
          _foundCmd = null;
        });
      }
      await _ctrl.stop();
      _loadHistory();
      _handling = false;
      return;
    }

    final id = TextUtils.extractAcademicId(code);
    if (id == null) {
      await state.repo.addScan(code, null, false);
      setState(() {
        _resultOk = false;
        _resultMsg = 'لم يتم العثور على رقم أكاديمي صالح في: $code';
        _found = null;
        _foundCmd = null;
      });
    } else {
      final s = await state.repo.findByAcademicId(id);
      await state.repo.addScan(code, id, s != null);
      setState(() {
        _resultOk = s != null;
        _resultMsg = s == null ? 'الرقم الأكاديمي $id غير موجود في النظام' : 'تم العثور على: ${s.name}';
        _found = s;
        _foundCmd = null;
      });
    }
    if (_cameraSupported) await _ctrl.stop();
    _loadHistory();
    _handling = false;
  }

  Future<void> _scanAgain() async {
    setState(() {
      _resultMsg = null;
      _found = null;
      _foundCmd = null;
      _lastCode = null;
    });
    if (_cameraSupported) await _ctrl.start();
  }

  Future<void> _fromImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      final r = await _ctrl.analyzeImage(x.path);
      final v = r?.barcodes.firstOrNull?.rawValue;
      if (v == null || v.isEmpty) {
        if (mounted) showSnack(context, 'لم يتم العثور على باركود في الصورة', warning: true);
        return;
      }
      await _process(v);
    } catch (e) {
      if (mounted) showSnack(context, 'تعذر تحليل الصورة: $e', error: true);
    }
  }

  void _use() {
    if (_found != null) {
      Navigator.pop(context, ScanResult(student: _found));
    } else if (_foundCmd != null) {
      Navigator.pop(context, ScanResult(command: _foundCmd));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR / الباركود'),
        actions: !_cameraSupported ? null : [
          IconButton(
            tooltip: 'الفلاش',
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off, color: _torch ? AppColors.gold : null),
            onPressed: () async {
              await _ctrl.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
          IconButton(tooltip: 'تبديل الكاميرا', icon: const Icon(Icons.cameraswitch), onPressed: _ctrl.switchCamera),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_cameraSupported)
                    Container(
                      color: Colors.black87,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white54, size: 56),
                        SizedBox(height: 10),
                        Text('وضع سطح المكتب: وصّل قارئ باركود USB وامسح مباشرة، أو أدخل الرقم الأكاديمي في الحقل أدناه', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    )
                  else
                  MobileScanner(
                    controller: _ctrl,
                    onDetect: (cap) {
                      final v = cap.barcodes.firstOrNull?.rawValue;
                      if (v != null && v.isNotEmpty && v != _lastCode) _process(v);
                    },
                    errorBuilder: (c, e) => Container(
                      color: Colors.black87,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.no_photography, color: Colors.white54, size: 48),
                        const SizedBox(height: 10),
                        Text('الكاميرا غير متاحة\n${e.errorDetails?.message ?? e.errorCode.name}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        const Text('يمكنك اختيار صورة من الجهاز أو إدخال الرقم يدويًا أدناه', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ]),
                    ),
                  ),
                  // إطار المسح
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(border: Border.all(color: _resultMsg == null ? AppColors.gold : (_resultOk ? AppColors.success : AppColors.danger), width: 3), borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  if (_resultMsg == null)
                    const Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Text('وجّه الكاميرا نحو رمز QR أو الباركود', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6, color: Colors.black)])),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_resultMsg != null)
                    Card(
                      color: _resultOk ? AppColors.greenLight : AppColors.danger.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(children: [
                            Icon(_resultOk ? Icons.check_circle : Icons.error, color: _resultOk ? AppColors.success : AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_resultMsg!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary))),
                          ]),
                          if (_found != null) ...[
                            const SizedBox(height: 6),
                            Text('${_found!.academicId} • ${_found!.major} • ${_found!.level}', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: FilledButton.icon(onPressed: _resultOk ? _use : null, icon: const Icon(Icons.open_in_new), label: const Text('استخدام'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton.icon(onPressed: _scanAgain, icon: const Icon(Icons.refresh), label: const Text('مسح آخر'))),
                          ]),
                        ]),
                      ),
                    ),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        autofocus: !_cameraSupported,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(hintText: 'إدخال يدوي / قارئ باركود خارجي', isDense: true, prefixIcon: Icon(Icons.keyboard)),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) _process(v);
                          _manual.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_cameraSupported) IconButton.filledTonal(tooltip: 'صورة من الجهاز', onPressed: _fromImage, icon: const Icon(Icons.image)),
                  ]),
                  if (_history.isNotEmpty) ...[
                    const SectionTitle('آخر عمليات المسح', icon: Icons.history),
                    for (final h in _history)
                      ListTile(
                        dense: true,
                        leading: Icon((h['success'] as int) == 1 ? Icons.check_circle_outline : Icons.highlight_off, size: 18, color: (h['success'] as int) == 1 ? AppColors.success : AppColors.danger),
                        title: Text(h['code'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text(h['scanned_at'].toString().replaceFirst('T', ' ').split('.').first, style: const TextStyle(fontSize: 10)),
                        onTap: () => _process(h['code'].toString()),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
