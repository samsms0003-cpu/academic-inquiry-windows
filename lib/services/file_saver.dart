import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' as io;

/// حفظ الملفات عبر Storage Access Framework (Android) أو تنزيل (Web).
class FileSaver {
  FileSaver._();

  /// يعيد المسار/الاسم الذي تم الحفظ فيه، أو null إذا ألغى المستخدم.
  static Future<String?> save(String fileName, Uint8List bytes, {String? mime}) async {
    final ext = fileName.split('.').last.toLowerCase();
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ الملف',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );
      if (path == null) return null;
      if (!kIsWeb && !io.Platform.isAndroid && !io.Platform.isIOS) {
        // على سطح المكتب saveFile يعيد المسار فقط دون كتابة.
        await io.File(path).writeAsBytes(bytes, flush: true);
      }
      return path;
    } catch (e) {
      // احتياط: حفظ في مجلد التطبيق ثم مشاركة.
      if (kIsWeb) rethrow;
      final dir = await getApplicationDocumentsDirectory();
      final f = io.File('${dir.path}/$fileName');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    }
  }

  static Future<void> share(String fileName, Uint8List bytes, {String? text}) async {
    if (kIsWeb) {
      await save(fileName, bytes);
      return;
    }
    final dir = await getTemporaryDirectory();
    final f = io.File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: text));
  }

  /// نسخة أمان تلقائية داخل مجلد التطبيق (قبل الاستبدال/المسح).
  static Future<String?> saveInternalBackup(String fileName, Uint8List bytes) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final bdir = io.Directory('${dir.path}/backups');
    if (!await bdir.exists()) await bdir.create(recursive: true);
    final f = io.File('${bdir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    // احتفظ بآخر 10 نسخ فقط
    final files = bdir.listSync().whereType<io.File>().toList()..sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(10)) {
      try {
        await old.delete();
      } catch (_) {}
    }
    return f.path;
  }

  static Future<List<io.File>> listInternalBackups() async {
    if (kIsWeb) return [];
    final dir = await getApplicationDocumentsDirectory();
    final bdir = io.Directory('${dir.path}/backups');
    if (!await bdir.exists()) return [];
    final files = bdir.listSync().whereType<io.File>().toList()..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
