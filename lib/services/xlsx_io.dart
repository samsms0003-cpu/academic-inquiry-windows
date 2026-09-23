import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// قارئ/كاتب XLSX (Open XML) خفيف بدون مكتبات ثقيلة.
///
/// القراءة تعتمد على تحليل XML متدفق (XmlEventDecoder) لتجنب بناء شجرة DOM
/// كاملة للأوراق الضخمة. الكتابة تنتج ملف Open XML حقيقي (وليس XML قديم بامتداد .xls).

/// تحليل XML بشكل متدفق على أجزاء (يتجنب بناء قائمة أحداث ضخمة في الذاكرة).
Iterable<XmlEvent> _iterEvents(String xmlStr) sync* {
  const chunk = 1 << 16;
  final decoder = XmlEventDecoder();
  final sink = _ListSink();
  final conv = decoder.startChunkedConversion(sink);
  for (var i = 0; i < xmlStr.length; i += chunk) {
    conv.add(xmlStr.substring(i, i + chunk > xmlStr.length ? xmlStr.length : i + chunk));
    if (sink.events.isNotEmpty) {
      final out = sink.events;
      sink.events = <XmlEvent>[];
      yield* out;
    }
  }
  conv.close();
  yield* sink.events;
}

class _ListSink implements Sink<List<XmlEvent>> {
  List<XmlEvent> events = <XmlEvent>[];
  @override
  void add(List<XmlEvent> data) => events.addAll(data);
  @override
  void close() {}
}

class XlsxSheetInfo {
  final String name;
  final String path;
  final int rowCount;
  XlsxSheetInfo(this.name, this.path, this.rowCount);
}

class XlsxWorkbookReader {
  XlsxWorkbookReader._(this._archive, this._shared, this.sheets);

  final Archive _archive;
  final List<String> _shared;
  final List<XlsxSheetInfo> sheets;

  static XlsxWorkbookReader open(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final shared = _readSharedStrings(archive);
    final sheets = _readSheets(archive);
    return XlsxWorkbookReader._(archive, shared, sheets);
  }

  static String? _content(Archive a, String path) {
    final f = a.findFile(path) ?? a.findFile('/$path');
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  static List<String> _readSharedStrings(Archive a) {
    final xmlStr = _content(a, 'xl/sharedStrings.xml');
    if (xmlStr == null) return const [];
    final out = <String>[];
    final buf = StringBuffer();
    var inSi = false;
    for (final ev in _iterEvents(xmlStr)) {
      if (ev is XmlStartElementEvent) {
        if (ev.name == 'si') {
          inSi = true;
          buf.clear();
        }
      } else if (ev is XmlTextEvent) {
        if (inSi) buf.write(ev.value);
      } else if (ev is XmlEndElementEvent) {
        if (ev.name == 'si') {
          out.add(buf.toString());
          inSi = false;
        }
      }
    }
    return out;
  }

  static List<XlsxSheetInfo> _readSheets(Archive a) {
    final wb = _content(a, 'xl/workbook.xml');
    final rels = _content(a, 'xl/_rels/workbook.xml.rels');
    if (wb == null) return const [];
    final relMap = <String, String>{};
    if (rels != null) {
      final doc = XmlDocument.parse(rels);
      for (final r in doc.findAllElements('Relationship')) {
        var target = r.getAttribute('Target') ?? '';
        if (target.startsWith('/')) target = target.substring(1);
        if (!target.startsWith('xl/')) target = 'xl/$target';
        relMap[r.getAttribute('Id') ?? ''] = target;
      }
    }
    final doc = XmlDocument.parse(wb);
    final out = <XlsxSheetInfo>[];
    var idx = 1;
    for (final s in doc.findAllElements('sheet')) {
      final name = s.getAttribute('name') ?? 'Sheet$idx';
      final rid = s.attributes.firstWhere((at) => at.name.local == 'id', orElse: () => XmlAttribute(XmlName('id'), '')).value;
      final path = relMap[rid] ?? 'xl/worksheets/sheet$idx.xml';
      out.add(XlsxSheetInfo(name, path, -1));
      idx++;
    }
    return out;
  }

  /// عدد صفوف الورقة (تقريبي سريع من dimension أو عدّ row).
  int rowCount(XlsxSheetInfo sheet) {
    final xmlStr = _content(_archive, sheet.path);
    if (xmlStr == null) return 0;
    final m = RegExp(r'<dimension ref="[A-Z]+(\d+):[A-Z]+(\d+)"').firstMatch(xmlStr);
    if (m != null) return int.parse(m.group(2)!) - int.parse(m.group(1)!) + 1;
    return RegExp(r'<row[ >]').allMatches(xmlStr).length;
  }

  /// قراءة صفوف الورقة صفًا صفًا (كل صف قائمة قيم حسب ترتيب الأعمدة).
  /// [onRow] تعيد false لإيقاف القراءة.
  void readRows(XlsxSheetInfo sheet, bool Function(int rowIndex, List<Object?> cells) onRow) {
    final xmlStr = _content(_archive, sheet.path);
    if (xmlStr == null) return;
    List<Object?>? row;
    var rowIndex = 0;
    var colIndex = 0;
    String? cellType;
    String? cellRef;
    final vbuf = StringBuffer();
    var inV = false;
    var inIs = false;
    var stop = false;

    for (final ev in _iterEvents(xmlStr)) {
      if (stop) break;
      if (ev is XmlStartElementEvent) {
        switch (ev.name) {
          case 'row':
            row = <Object?>[];
            rowIndex = int.tryParse(ev.attributes.firstWhere((a) => a.name == 'r', orElse: () => XmlEventAttribute('r', '0', XmlAttributeType.DOUBLE_QUOTE)).value) ?? (rowIndex + 1);
            colIndex = 0;
            break;
          case 'c':
            cellType = null;
            cellRef = null;
            for (final a in ev.attributes) {
              if (a.name == 't') cellType = a.value;
              if (a.name == 'r') cellRef = a.value;
            }
            if (cellRef != null) {
              final ci = _colIndex(cellRef);
              while (row!.length < ci) {
                row.add(null);
              }
              colIndex = ci;
            }
            vbuf.clear();
            if (ev.isSelfClosing) {
              row!.add(null);
              colIndex++;
            }
            break;
          case 'v':
            inV = true;
            vbuf.clear();
            break;
          case 'is':
            inIs = true;
            vbuf.clear();
            break;
        }
      } else if (ev is XmlTextEvent) {
        if (inV || inIs) vbuf.write(ev.value);
      } else if (ev is XmlCDATAEvent) {
        if (inV || inIs) vbuf.write(ev.value);
      } else if (ev is XmlEndElementEvent) {
        switch (ev.name) {
          case 'v':
            inV = false;
            break;
          case 'is':
            inIs = false;
            break;
          case 'c':
            if (row == null) break;
            final raw = vbuf.toString();
            Object? val;
            if (raw.isEmpty && cellType != 'inlineStr') {
              val = null;
            } else {
              switch (cellType) {
                case 's':
                  final i = int.tryParse(raw);
                  val = (i != null && i < _shared.length) ? _shared[i] : raw;
                  break;
                case 'b':
                  val = raw == '1';
                  break;
                case 'str':
                case 'inlineStr':
                  val = raw;
                  break;
                default:
                  val = double.tryParse(raw) ?? raw;
              }
            }
            while (row.length < colIndex) {
              row.add(null);
            }
            if (row.length == colIndex) {
              row.add(val);
            } else {
              row[colIndex] = val;
            }
            colIndex++;
            vbuf.clear();
            break;
          case 'row':
            if (row != null) {
              if (!onRow(rowIndex, row)) stop = true;
            }
            row = null;
            break;
        }
      }
    }
  }

  static int _colIndex(String ref) {
    var n = 0;
    for (final r in ref.runes) {
      if (r >= 65 && r <= 90) {
        n = n * 26 + (r - 64);
      } else {
        break;
      }
    }
    return n - 1;
  }
}

/// كاتب XLSX متعدد الأوراق. يُنشئ inline strings لتجنب بناء جدول shared strings
/// ضخم في الذاكرة، ويكتب الأرقام كأرقام والنصوص كنصوص (الرقم الأكاديمي يبقى نصًا).
class XlsxWriter {
  final List<SheetBuf> _sheets = [];

  SheetBuf addSheet(String name) {
    final s = SheetBuf(name);
    _sheets.add(s);
    return s;
  }

  Uint8List build() {
    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''');
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels());
    add('xl/styles.xml', _styles());
    for (var i = 0; i < _sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheets[i].toXml());
    }
    final out = ZipEncoder().encode(archive, level: Deflate.BEST_SPEED);
    return Uint8List.fromList(out ?? const []);
  }

  String _contentTypes() {
    final sb = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');
    for (var i = 0; i < _sheets.length; i++) {
      sb.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    sb.write('</Types>');
    return sb.toString();
  }

  String _workbook() {
    final sb = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<bookViews><workbookView/></bookViews><sheets>');
    for (var i = 0; i < _sheets.length; i++) {
      sb.write('<sheet name="${_esc(_sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    sb.write('</sheets></workbook>');
    return sb.toString();
  }

  String _workbookRels() {
    final sb = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 0; i < _sheets.length; i++) {
      sb.write('<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>');
    }
    sb.write('<Relationship Id="rId${_sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    sb.write('</Relationships>');
    return sb.toString();
  }

  String _styles() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF006B45"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment horizontal="center"/></xf></cellXfs>'
      '</styleSheet>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
}

class SheetBuf {
  SheetBuf(this.name);
  final String name;
  final StringBuffer _rows = StringBuffer();
  int _rowNum = 0;
  int _maxCols = 0;

  void addHeader(List<String> headers) => _add(headers, style: 1);
  void addRow(List<Object?> values) => _add(values);

  void _add(List<Object?> values, {int style = 0}) {
    _rowNum++;
    if (values.length > _maxCols) _maxCols = values.length;
    _rows.write('<row r="$_rowNum">');
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null || (v is String && v.isEmpty)) continue; // خلية فارغة تبقى فارغة
      final ref = '${_colName(i)}$_rowNum';
      final st = style > 0 ? ' s="$style"' : '';
      if (v is num) {
        _rows.write('<c r="$ref"$st><v>$v</v></c>');
      } else if (v is bool) {
        _rows.write('<c r="$ref"$st t="b"><v>${v ? 1 : 0}</v></c>');
      } else {
        _rows.write('<c r="$ref"$st t="inlineStr"><is><t xml:space="preserve">${XlsxWriter._esc(v.toString())}</t></is></c>');
      }
    }
    _rows.write('</row>');
  }

  String toXml() {
    final cols = StringBuffer();
    if (_maxCols > 0) {
      cols.write('<cols>');
      for (var i = 0; i < _maxCols; i++) {
        cols.write('<col min="${i + 1}" max="${i + 1}" width="16" customWidth="1"/>');
      }
      cols.write('</cols>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetViews><sheetView rightToLeft="1" workbookViewId="0"/></sheetViews>'
        '$cols<sheetData>$_rows</sheetData></worksheet>';
  }

  static String _colName(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }
}
