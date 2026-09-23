/// ثوابت النظام: أسماء الأعمدة، النصوص الافتراضية، أوامر الباركود.
/// مستخرجة من index.html للحفاظ على التوافق الكامل مع ملفات النظام الحالي.
class AppConstants {
  AppConstants._();

  static const appName = 'نظام الاستعلامات الأكاديمية';
  static const appSubtitle = 'كلية الصماد للقرآن الكريم وعلومه';
  static const appVersion = '2.0.0';

  /// أعمدة ورقة Grades (20 عمودًا) بالترتيب الأصلي.
  static const gradesColumns = <String>[
    'الرقم الاكاديمي',
    'اسم الطالب',
    'التخصص',
    'العام الدراسي',
    'المستوى',
    'الفصل الدراسي',
    'معرف المستوى',
    'معرف الفصل',
    'معرف المادة',
    'اسم المادة',
    'المجموع',
    'التقدير',
    'احتساب المادة',
    'مبقي',
    'الحضور',
    'المشاركة',
    'أعمال الفصل',
    'الامتحان النصفي',
    'الامتحان النهائي',
    'ملاحظات',
  ];

  /// أعمدة ورقة Attendance (11 عمودًا) بالترتيب الأصلي.
  static const attendanceColumns = <String>[
    'acadym_int',
    'AL1',
    'NEM_ALGESM_AR',
    'yer',
    'mestawa',
    'NEM_FASOL_AR',
    'nem_mawad_ar',
    'date_m',
    'date_h',
    'nem_tahter',
    'ملاحظات',
  ];

  /// العناوين العربية لأعمدة الحضور (للعرض والتقارير).
  static const attendanceColumnLabels = <String>[
    'الرقم الأكاديمي',
    'اسم الطالب',
    'التخصص',
    'العام الدراسي',
    'المستوى',
    'الفصل الدراسي',
    'المادة',
    'التاريخ الهجري',
    'التاريخ الميلادي',
    'الحالة',
    'ملاحظات',
  ];

  static const defaultHeaderAr = <String>[
    'الجمهورية اليمنية',
    'وزارة الإرشاد وشؤون الحج والعمرة',
    'الأكاديمية العليا للقرآن الكريم وعلومه',
    'كلية الصماد للقرآن الكريم وعلومه',
  ];

  static const defaultHeaderEn = <String>[
    'Republic of Yemen',
    'Ministry of Guidance and Hajj Affairs',
    'The Higher Academy of the Holy Quran and Its Sciences',
    'Al-Samad College for Holy Quran and Its Sciences',
  ];

  /// أوامر الباركود (CMD-XX) كما في النظام الحالي.
  static const barcodeCommands = <String, ({String action, String name})>{
    'CMD-01': (action: 'attendance-summary', name: 'ملخص الحضور'),
    'CMD-02': (action: 'attendance-detailed', name: 'تقرير الحضور التفصيلي'),
    'CMD-03': (action: 'grades-summary', name: 'كشوفات الدرجات الإجمالية'),
    'CMD-04': (action: 'grades-detailed', name: 'كشوفات الدرجات التفصيلية'),
    'CMD-05': (action: 'go-back-and-clear', name: 'العودة للرئيسية وتفريغ الحقل'),
  };

  /// الخطوط المتاحة: المفتاح = اسم العائلة، القيمة = (الاسم العربي، ملف عادي، ملف عريض).
  static const fonts = <String, ({String label, String regular, String bold})>{
    'Cairo': (label: 'القاهرة (Cairo)', regular: 'assets/fonts/cairo-400.ttf', bold: 'assets/fonts/cairo-700.ttf'),
    'Tajawal': (label: 'تجوال (Tajawal)', regular: 'assets/fonts/tajawal-400.ttf', bold: 'assets/fonts/tajawal-700.ttf'),
    'Almarai': (label: 'المراعي (Almarai)', regular: 'assets/fonts/almarai-400.ttf', bold: 'assets/fonts/almarai-700.ttf'),
    'Amiri': (label: 'أميري (Amiri) — نسخي', regular: 'assets/fonts/amiri-400.ttf', bold: 'assets/fonts/amiri-700.ttf'),
    'NotoNaskh': (label: 'نوتو نسخ (Noto Naskh)', regular: 'assets/fonts/notonaskh.ttf', bold: 'assets/fonts/notonaskh.ttf'),
  };

  static const importBatchSize = 2000;
  static const maxImportFileBytes = 500 * 1024 * 1024;
}
