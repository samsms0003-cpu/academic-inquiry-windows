import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// عن النظام + معلومات المطوّر وأزرار التواصل المباشر (كما في النظام الأصلي).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const developerName = 'محمد الصالحي';
  static const developerTitle = 'مطوّر ومصمّم واجهات المستخدم';
  static const developerNote = 'متاح للتواصل والدعم التقني';
  static const phone1 = '967775930220';
  static const phone2 = '967780096567';
  static const landline = '967101103618';

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showSnack(context, 'تعذر فتح الرابط', error: true);
    } catch (_) {
      if (context.mounted) showSnack(context, 'تعذر فتح الرابط: $url', error: true);
    }
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSnack(context, 'تم نسخ الرقم: $text');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن النظام')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Image.asset('assets/images/academy_logo.png', width: 140)),
            const SizedBox(height: 12),
            const Center(child: Text(AppConstants.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.greenDark))),
            const Center(child: Text(AppConstants.appSubtitle, style: TextStyle(color: AppColors.textSecondary))),
            const Center(child: Padding(padding: EdgeInsets.only(top: 6), child: StatusChip('الإصدار ${AppConstants.appVersion} — Android Native', color: AppColors.gold))),

            const SectionTitle('مزايا النظام', icon: Icons.check_circle_outline),
            const Card(
              child: Column(children: [
                _Feature('إدارة بيانات الطلاب والبحث الفوري بالرقم الأكاديمي أو الاسم أو الباركود'),
                _Feature('تقارير الحضور والدرجات — 8 تقارير بصيغة PDF وExcel'),
                _Feature('استيراد ونسخ احتياطي واستعادة بصيغة XLSX حقيقية'),
                _Feature('قاعدة SQLite مفهرسة تتحمل ملايين السجلات'),
                _Feature('يعمل بالكامل محليًا دون إنترنت'),
              ]),
            ),

            // ------------------------------------------------ المطوّر
            const SectionTitle('المطوّر', icon: Icons.code),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    ),
                    child: const Column(children: [
                      CircleAvatar(radius: 34, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: AppColors.green)),
                      SizedBox(height: 10),
                      Text(developerName, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(developerTitle, style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text(developerNote, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, right: 4),
                          child: Row(children: [Icon(Icons.headset_mic, size: 18, color: AppColors.gold), SizedBox(width: 6), Text('وسائل التواصل المباشر', style: TextStyle(fontWeight: FontWeight.w700))]),
                        ),
                        _Contact(icon: Icons.chat, color: const Color(0xFF25D366), label: 'واتساب', value: '775930220', onTap: () => _open(context, 'https://wa.me/$phone1'), onLong: () => _copy(context, '+$phone1')),
                        _Contact(icon: Icons.send, color: const Color(0xFF229ED9), label: 'تيليجرام', value: '775930220', onTap: () => _open(context, 'https://t.me/+$phone1'), onLong: () => _copy(context, '+$phone1')),
                        _Contact(icon: Icons.smartphone, color: AppColors.green, label: 'اتصال — جوال', value: '775930220', onTap: () => _open(context, 'tel:+$phone1'), onLong: () => _copy(context, '+$phone1')),
                        const Divider(height: 18),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, right: 4),
                          child: Row(children: [Icon(Icons.headset_mic, size: 18, color: AppColors.gold), SizedBox(width: 6), Text('وسائل التواصل المباشر 2', style: TextStyle(fontWeight: FontWeight.w700))]),
                        ),
                        _Contact(icon: Icons.chat, color: const Color(0xFF25D366), label: 'واتساب 2', value: '780096567', onTap: () => _open(context, 'https://wa.me/$phone2'), onLong: () => _copy(context, '+$phone2')),
                        _Contact(icon: Icons.send, color: const Color(0xFF229ED9), label: 'تيليجرام 2', value: '780096567', onTap: () => _open(context, 'https://t.me/+$phone2'), onLong: () => _copy(context, '+$phone2')),
                        _Contact(icon: Icons.smartphone, color: AppColors.green, label: 'اتصال — جوال 2', value: '780096567', onTap: () => _open(context, 'tel:+$phone2'), onLong: () => _copy(context, '+$phone2')),
                        _Contact(icon: Icons.phone, color: AppColors.textSecondary, label: 'هاتف ثابت', value: '101 103 618', onTap: () => _open(context, 'tel:+$landline'), onLong: () => _copy(context, '+$landline')),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SectionTitle('قواعد الحساب', icon: Icons.calculate),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '• التقدير: ≥90 ممتاز، ≥80 جيد جداً، ≥65 جيد، ≥50 مقبول، وإلا راسب.\n'
                  '• المعدل = المجموع ÷ (Σ احتساب المادة × 100) × 100.\n'
                  '• المبقي: يُجمع احتساب المواد المبقية ويُعرض "منقول بمادة/مادتين/٣/٤/٥ مواد" أو "باقي للإعادة".\n'
                  '• حالة الغياب: ≥50 حرمان، ≥40 إنذار بالحرمان، ≥30 تحذير، ≥20 ضعيف، ≥10 جيد، وإلا ممتاز.\n'
                  '• المتفوقون: GPA = Σ(نقاط×احتساب) ÷ Σ احتساب، بنقاط 4/3/2/1.',
                  style: TextStyle(height: 1.9, fontSize: 12),
                ),
              ),
            ),
            const SectionTitle('أوامر الباركود', icon: Icons.qr_code),
            Card(
              child: Column(children: [
                for (final e in AppConstants.barcodeCommands.entries)
                  ListTile(dense: true, leading: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)), title: Text(e.value.name, style: const TextStyle(fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Column(children: [
                Icon(Icons.shield_outlined, color: AppColors.textSecondary, size: 18),
                SizedBox(height: 4),
                Text('جميع الحقوق محفوظة © 2025 نظام الاستعلامات — كلية الصماد للقرآن الكريم وعلومه', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text('البيانات محفوظة محليًا فقط ولا تُرسل إلى أي خادم.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(dense: true, leading: const Icon(Icons.check, color: AppColors.success, size: 20), title: Text(text, style: const TextStyle(fontSize: 12)));
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.color, required this.label, required this.value, required this.onTap, required this.onLong});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onLong;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLong,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14, letterSpacing: 0.5), textDirection: TextDirection.ltr),
              const SizedBox(width: 6),
              Icon(Icons.chevron_left, color: color, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
