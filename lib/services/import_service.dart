import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/text_utils.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import 'xlsx_io.dart';

enum ImportMode { append, update, replace }

enum SheetKind { grades, attendance, instructions, unknown }

class SheetPreview {
  final String name;
  final SheetKind kind;
  final int rowCount;
  final List<String> headers;
  final List<String> mappedColumns;
  final List<String> missingRequired;
  final List<List<Object?>> sampleRows;
  final String? sheetPath;
  SheetPreview({
    required this.name,
    required this.kind,
    required this.rowCount,
    required this.headers,
    required this.mappedColumns,
    required this.missingRequired,
    required this.sampleRows,
    this.sheetPath,
  });
}

class FilePreview {
  final String fileName;
  final int sizeBytes;
  final String fingerprint;
  final bool alreadyImported;
  final List<SheetPreview> sheets;
  final Uint8List bytes;
  final bool isCsv;
  final bool isJson;
  final String csvDelimiter;
  FilePreview({
    required this.fileName,
    required this.sizeBytes,
    required this.fingerprint,
    required this.alreadyImported,
    required this.sheets,
    required this.bytes,
    this.isCsv = false,
    this.isJson = false,
    this.csvDelimiter = ',',
  });
  bool get hasData => sheets.any((s) => (s.kind == SheetKind.grades || s.kind == SheetKind.attendance) && s.missingRequired.isEmpty);
}

class ImportProgress {
  final int processed;
  final int total;
  final String message;
  const ImportProgress(this.processed, this.total, this.message);
  double get fraction => total > 0 ? (processed / total).clamp(0, 1) : 0;
}

class RowError {
  final String sheet;
  final int row;
  final String reason;
  RowError(this.sheet, this.row, this.reason);
  @override
  String toString() => '$sheet | صف $row | $reason';
}

class ImportResult {
  int gradesInserted = 0;
  int attendanceInserted = 0;
  int skipped = 0;
  final List<RowError> errors = [];
  Duration elapsed = Duration.zero;
  bool cancelled = false;
  int get totalInserted => gradesInserted + attendanceInserted;
  String errorLog() => errors.map((e) => e.toString()).join('\n');
}

// ============================================================ helpers (pure)

final _gradesHeaderIndex = {for (final c in AppConstants.gradesColumns) TextUtils.normalizeHeader(c): c};
final _attHeaderIndex = {for (final c in AppConstants.attendanceColumns) TextUtils.normalizeHeader(c): c};
final _aliases = <String, String>{
  TextUtils.normalizeHeader('الرقم الأكاديمي'): 'الرقم الاكاديمي',
  TextUtils.normalizeHeader('academic_id'): 'الرقم الاكاديمي',
  TextUtils.normalizeHeader('المادة'): 'اسم المادة',
  TextUtils.normalizeHeader('الاسم'): 'اسم الطالب',
  TextUtils.normalizeHeader('اعمال الفصل'): 'أعمال الفصل',
  TextUtils.normalizeHeader('الملاحظات'): 'ملاحظات',
  TextUtils.normalizeHeader('notes'): 'ملاحظات',
  TextUtils.normalizeHeader('semester'): 'NEM_FASOL_AR',
  TextUtils.normalizeHeader('nem_fasl'): 'NEM_FASOL_AR',
};

String? canonicalHeader(String header, SheetKind kind) {
  final n = TextUtils.normalizeHeader(header);
  if (kind == SheetKind.grades) return _gradesHeaderIndex[n] ?? _aliases[n];
  if (kind == SheetKind.attendance) return _attHeaderIndex[n] ?? _aliases[n];
  return _gradesHeaderIndex[n] ?? _attHeaderIndex[n] ?? _aliases[n];
}

SheetKind detectKind(String sheetName, List<String> headers) {
  final ln = sheetName.toLowerCase();
  final norm = headers.map(TextUtils.normalizeHeader).toSet();
  if (norm.contains(TextUtils.normalizeHeader('acadym_int')) || norm.contains(TextUtils.normalizeHeader('nem_tahter'))) return SheetKind.attendance;
  if (norm.contains(TextUtils.normalizeHeader('الرقم الاكاديمي')) || norm.contains(TextUtils.normalizeHeader('الرقم الأكاديمي'))) return SheetKind.grades;
  if (ln.contains('instruction') || ln.contains('إرشاد') || ln.contains('ارشاد')) return SheetKind.instructions;
  if (ln.contains('grade') || ln.contains('درجات')) return SheetKind.grades;
  if (ln.contains('attend') || ln.contains('حضور')) return SheetKind.attendance;
  return SheetKind.unknown;
}

/// اكتشاف فاصل CSV: ; أو , أو Tab — يُحسب على أول سطر.
String detectCsvDelimiter(String text) {
  final firstLine = text.split('\n').first;
  final counts = {';': 0, ',': 0, '\t': 0};
  var inQ = false;
  for (final ch in firstLine.split('')) {
    if (ch == '"') inQ = !inQ;
    if (!inQ && counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
  }
  var best = ',';
  var max = -1;
  for (final e in counts.entries) {
    if (e.value > max) {
      max = e.value;
      best = e.key;
    }
  }
  return best;
}

String decodeCsvText(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

SheetPreview buildPreview(String name, SheetKind kind, int rows, List<String> headers, List<List<Object?>> samples, {String? sheetPath}) {
  final mapped = <String>[];
  for (final h in headers) {
    final c = canonicalHeader(h, kind);
    if (c != null) mapped.add(c);
  }
  final missing = <String>[];
  if (kind == SheetKind.grades && !mapped.contains('الرقم الاكاديمي')) missing.add('الرقم الاكاديمي');
  if (kind == SheetKind.attendance && !mapped.contains('acadym_int')) missing.add('acadym_int');
  return SheetPreview(name: name, kind: kind, rowCount: rows, headers: headers, mappedColumns: mapped, missingRequired: missing, sampleRows: samples, sheetPath: sheetPath);
}

// ------------------------------------------------ preview (runs in isolate)

class _PreviewArgs {
  final String fileName;
  final Uint8List bytes;
  const _PreviewArgs(this.fileName, this.bytes);
}

class _PreviewOut {
  final List<SheetPreview> sheets;
  final bool isCsv;
  final bool isJson;
  final String delimiter;
  const _PreviewOut(this.sheets, {this.isCsv = false, this.isJson = false, this.delimiter = ','});
}

_PreviewOut _previewIsolate(_PreviewArgs a) {
  final lower = a.fileName.toLowerCase();
  if (lower.endsWith('.json')) {
    final root = jsonDecode(utf8.decode(a.bytes, allowMalformed: true));
    if (root is! Map) throw const FormatException('ملف JSON غير صالح: يجب أن يكون كائنًا يحتوي grades و/أو attendance');
    final out = <SheetPreview>[];
    for (final key in ['grades', 'attendance']) {
      final list = root[key];
      if (list is List && list.isNotEmpty) {
        final headers = (list.first as Map).keys.map((e) => e.toString()).toList();
        final kind = key == 'grades' ? SheetKind.grades : SheetKind.attendance;
        final samples = list.take(5).map((m) => headers.map((h) => (m as Map)[h]).toList()).toList();
        out.add(buildPreview(key == 'grades' ? 'Grades' : 'Attendance', kind, list.length, headers, samples, sheetPath: key));
      }
    }
    if (out.isEmpty) throw const FormatException('ملف JSON لا يحتوي على grades أو attendance');
    return _PreviewOut(out, isJson: true);
  }
  if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
    final text = decodeCsvText(a.bytes);
    final delim = detectCsvDelimiter(text);
    final rows = CsvToListConverter(shouldParseNumbers: false, eol: '\n', fieldDelimiter: delim).convert(text);
    if (rows.isEmpty) throw const FormatException('ملف CSV فارغ');
    final headers = rows.first.map((c) => TextUtils.cellToString(c)).toList();
    var count = 0;
    final samples = <List<Object?>>[];
    for (final r in rows.skip(1)) {
      if (r.any((c) => TextUtils.cellToString(c).isNotEmpty)) {
        count++;
        if (samples.length < 5) samples.add(r);
      }
    }
    final kind = detectKind(a.fileName, headers);
    return _PreviewOut([buildPreview(a.fileName, kind, count, headers, samples)], isCsv: true, delimiter: delim);
  }
  if (!lower.endsWith('.xlsx') && !lower.endsWith('.xlsm')) {
    throw const FormatException('نوع الملف غير مدعوم. المدعوم: .xlsx أو .csv أو .json');
  }
  final XlsxWorkbookReader reader;
  try {
    reader = XlsxWorkbookReader.open(a.bytes);
  } catch (_) {
    throw const FormatException('الملف تالف أو ليس ملف XLSX صالحًا');
  }
  if (reader.sheets.isEmpty) throw const FormatException('الملف لا يحتوي على أوراق عمل');
  final previews = <SheetPreview>[];
  for (final s in reader.sheets) {
    List<String> headers = [];
    final samples = <List<Object?>>[];
    reader.readRows(s, (idx, cells) {
      if (headers.isEmpty) {
        headers = cells.map((c) => TextUtils.cellToString(c)).toList();
        return true;
      }
      if (cells.every((c) => c == null || TextUtils.cellToString(c).isEmpty)) return true;
      samples.add(List<Object?>.from(cells));
      return samples.length < 5;
    });
    final total = reader.rowCount(s);
    final dataRows = total > 0 ? (total - 1).clamp(0, 1 << 31) : samples.length;
    previews.add(buildPreview(s.name, detectKind(s.name, headers), dataRows, headers, samples, sheetPath: s.path));
  }
  return _PreviewOut(previews);
}

// ------------------------------------------------ streaming rows (isolate)

class _StreamArgs {
  final SendPort port;
  final Uint8List bytes;
  final String? sheetPath;
  final bool isCsv;
  final bool isJson;
  final String delimiter;
  final int batch;
  const _StreamArgs(this.port, this.bytes, this.sheetPath, this.isCsv, this.isJson, this.delimiter, this.batch);
}

/// يبث الصفوف على دفعات (قوائم من قوائم القيم)؛ أول صف هو الرأس، وnull يعني الانتهاء.
void _streamIsolate(_StreamArgs a) {
  final buf = <List<Object?>>[];
  var idx = 0;
  void flush() {
    if (buf.isNotEmpty) {
      a.port.send(List<List<Object?>>.from(buf));
      buf.clear();
    }
  }

  try {
    if (a.isJson) {
      final root = jsonDecode(utf8.decode(a.bytes, allowMalformed: true)) as Map;
      final list = root[a.sheetPath] as List;
      final headers = (list.first as Map).keys.map((e) => e.toString()).toList();
      buf.add([0, ...headers]);
      for (final m in list) {
        idx++;
        buf.add([idx, ...headers.map((h) => (m as Map)[h])]);
        if (buf.length >= a.batch) flush();
      }
    } else if (a.isCsv) {
      final text = decodeCsvText(a.bytes);
      final rows = CsvToListConverter(shouldParseNumbers: false, eol: '\n', fieldDelimiter: a.delimiter).convert(text);
      for (final r in rows) {
        buf.add([idx, ...r]);
        idx++;
        if (buf.length >= a.batch) flush();
      }
    } else {
      final reader = XlsxWorkbookReader.open(a.bytes);
      final sheet = reader.sheets.firstWhere((s) => s.path == a.sheetPath);
      reader.readRows(sheet, (rowIdx, cells) {
        buf.add([rowIdx, ...cells]);
        if (buf.length >= a.batch) flush();
        return true;
      });
    }
    flush();
    a.port.send(null);
  } catch (e) {
    a.port.send('ERR:$e');
  }
}

/// خدمة الاستيراد والاستعادة (XLSX / CSV / JSON) — القراءة في Isolate منفصل.
class ImportService {
  ImportService(this.repo);
  final Repository repo;

  static String fingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<FilePreview> preview(String fileName, Uint8List bytes) async {
    if (bytes.length > AppConstants.maxImportFileBytes) throw const FormatException('حجم الملف يتجاوز الحد المسموح (500 ميجابايت)');
    final fp = fingerprint(bytes);
    final already = await repo.fingerprintExists(fp);
    final out = await compute(_previewIsolate, _PreviewArgs(fileName, bytes));
    return FilePreview(
      fileName: fileName,
      sizeBytes: bytes.length,
      fingerprint: fp,
      alreadyImported: already,
      sheets: out.sheets,
      bytes: bytes,
      isCsv: out.isCsv,
      isJson: out.isJson,
      csvDelimiter: out.delimiter,
    );
  }

  Future<ImportResult> run(
    FilePreview file, {
    required ImportMode mode,
    required void Function(ImportProgress) onProgress,
    bool Function()? isCancelled,
  }) async {
    final sw = Stopwatch()..start();
    final result = ImportResult();
    final updateExisting = mode != ImportMode.append;

    if (mode == ImportMode.replace) {
      onProgress(const ImportProgress(0, 1, 'جاري مسح البيانات القديمة...'));
      await repo.clearAllData();
    }

    final sheets = file.sheets.where((s) => (s.kind == SheetKind.grades || s.kind == SheetKind.attendance) && s.missingRequired.isEmpty).toList();
    final grandTotal = sheets.fold<int>(0, (a, s) => a + s.rowCount);
    var processed = 0;

    for (final s in sheets) {
      List<String>? headerCanon;
      final gBuf = <GradeRecord>[];
      final aBuf = <AttendanceRecord>[];

      Future<void> flush() async {
        if (gBuf.isNotEmpty) {
          await repo.upsertGradesBatch(gBuf, updateExisting: updateExisting);
          result.gradesInserted += gBuf.length;
          gBuf.clear();
        }
        if (aBuf.isNotEmpty) {
          await repo.upsertAttendanceBatch(aBuf, updateExisting: updateExisting);
          result.attendanceInserted += aBuf.length;
          aBuf.clear();
        }
      }

      void handle(int idx, List<Object?> cells) {
        if (headerCanon == null) {
          headerCanon = cells.map((c) => canonicalHeader(TextUtils.cellToString(c), s.kind) ?? '').toList();
          return;
        }
        if (cells.every((c) => c == null || TextUtils.cellToString(c).isEmpty)) return;
        final map = <String, Object?>{};
        for (var i = 0; i < cells.length && i < headerCanon!.length; i++) {
          final k = headerCanon![i];
          if (k.isNotEmpty) map[k] = cells[i];
        }
        processed++;
        if (s.kind == SheetKind.grades) {
          final g = GradeRecord.fromExcelMap(map);
          if (g.academicId.isEmpty) {
            if (result.errors.length < 5000) result.errors.add(RowError(s.name, idx, 'الرقم الأكاديمي مفقود'));
            result.skipped++;
            return;
          }
          if (g.subjectId.isEmpty && g.subjectName.isEmpty) {
            if (result.errors.length < 5000) result.errors.add(RowError(s.name, idx, 'معرف المادة واسم المادة مفقودان'));
            result.skipped++;
            return;
          }
          gBuf.add(g);
        } else {
          final a = AttendanceRecord.fromExcelMap(map);
          if (a.academicId.isEmpty) {
            if (result.errors.length < 5000) result.errors.add(RowError(s.name, idx, 'الرقم الأكاديمي (acadym_int) مفقود'));
            result.skipped++;
            return;
          }
          aBuf.add(a);
        }
      }

      final rp = ReceivePort();
      final iso = await Isolate.spawn(_streamIsolate, _StreamArgs(rp.sendPort, file.bytes, s.sheetPath, file.isCsv, file.isJson, file.csvDelimiter, AppConstants.importBatchSize));
      try {
        await for (final msg in rp) {
          if (msg == null) break;
          if (msg is String && msg.startsWith('ERR:')) throw FormatException(msg.substring(4));
          final batch = msg as List<List<Object?>>;
          for (final row in batch) {
            handle(row.first as int, row.sublist(1));
          }
          await flush();
          onProgress(ImportProgress(processed, grandTotal, 'استيراد ${s.name}: ${TextUtils.fmtCount(processed)} من ${TextUtils.fmtCount(grandTotal)}'));
          if (isCancelled?.call() == true) {
            result.cancelled = true;
            break;
          }
        }
      } finally {
        iso.kill(priority: Isolate.immediate);
        rp.close();
      }
      await flush();
      if (result.cancelled) break;
    }

    await repo.touchLastUpdate();
    sw.stop();
    result.elapsed = sw.elapsed;
    await repo.addImportHistory(ImportHistoryEntry(
      fileName: file.fileName,
      importedAt: DateTime.now().toIso8601String(),
      inserted: result.totalInserted,
      skipped: result.skipped,
      errors: result.errors.length,
      result: result.cancelled ? 'ملغى' : 'نجاح',
      fingerprint: file.fingerprint,
      errorLog: result.errors.take(500).map((e) => e.toString()).join('\n'),
    ));
    return result;
  }
}
