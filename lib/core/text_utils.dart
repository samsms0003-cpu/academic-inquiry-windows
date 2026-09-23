/// أدوات معالجة النصوص والأرقام العربية.
class TextUtils {
  TextUtils._();

  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// تحويل الأرقام العربية/الفارسية إلى إنجليزية.
  static String normalizeDigits(String input) {
    final buf = StringBuffer();
    for (final r in input.runes) {
      final ch = String.fromCharCode(r);
      final ai = _arabicDigits.indexOf(ch);
      if (ai >= 0) {
        buf.write(ai);
        continue;
      }
      final pi = _persianDigits.indexOf(ch);
      if (pi >= 0) {
        buf.write(pi);
        continue;
      }
      buf.write(ch);
    }
    return buf.toString();
  }

  /// توحيد الهمزات والتاء المربوطة والمسافات لأغراض البحث والمطابقة.
  static String normalizeArabic(String input) {
    var s = normalizeDigits(input).trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[إأآا]'), 'ا');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ؤ', 'و');
    s = s.replaceAll('ئ', 'ي');
    s = s.replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), ''); // التشكيل والتطويل
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// توحيد اسم عمود Excel للمطابقة: يتجاهل المسافات والهمزات وحالة الأحرف.
  static String normalizeHeader(String h) {
    return normalizeArabic(h).replaceAll(' ', '').replaceAll('_', '').toLowerCase();
  }

  /// استخراج الرقم الأكاديمي من نص ممسوح (أول 8 أرقام متتالية).
  static String? extractAcademicId(String raw) {
    final s = normalizeDigits(raw).trim();
    final m = RegExp(r'(\d{8})').firstMatch(s);
    if (m != null) return m.group(1);
    if (RegExp(r'^\d{4,20}$').hasMatch(s)) return s;
    return null;
  }

  /// تحويل قيمة خلية إلى نص مع الحفاظ على الرقم الأكاديمي كنص.
  static String cellToString(Object? v) {
    if (v == null) return '';
    if (v is double) {
      if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
      return v.toString();
    }
    return v.toString().trim();
  }

  static double toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = normalizeDigits(v.toString()).trim().replaceAll('%', '');
    return double.tryParse(s) ?? 0;
  }

  static double? toDoubleOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = normalizeDigits(v.toString()).trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String fmtNum(num? v, {int decimals = 0}) {
    if (v == null) return '-';
    if (decimals == 0 && v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(decimals);
  }

  static String fmtCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
