# academic_inquiry

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## نسخة Windows (EXE)

المشروع مجهّز بالكامل لمنصة Windows (مجلد `windows/`، أيقونة، بيانات الإصدار، واجهة سطح مكتب بشريط جانبي عند عرض ≥ 900px).
ملف EXE لا يمكن تجميعه إلا على نظام Windows (متطلب من Flutter نفسه)، وهناك طريقتان:

### 1) GitHub Actions (بدون تثبيت أي شيء)
1. ارفع المشروع إلى مستودع GitHub.
2. من تبويب **Actions** شغّل سير العمل **Build Windows EXE & Android APK** (أو ادفع وسمًا `v2.0.0`).
3. حمّل الناتج من **Artifacts**: `AcademicInquiry-Windows` (ZIP محمول + ملف تنصيب Setup) و`AcademicInquiry-Android` (APK).

### 2) البناء محليًا على Windows
- المتطلبات: Flutter 3.35.4 + Visual Studio 2022 مع "Desktop development with C++".
- شغّل `installer\build_windows.bat` أو:
  ```
  flutter config --enable-windows-desktop
  flutter pub get
  flutter build windows --release
  ```
- الناتج: `build\windows\x64\runner\Release\AcademicInquiry.exe` (انسخ المجلد كاملًا — يحتوي DLLs وملفات data).
- ملف تنصيب اختياري (Inno Setup 6): `ISCC.exe installer\windows_setup.iss` → `installer\Output\AcademicInquiry-Setup-2.0.0-win64.exe`.

ملاحظة: على Windows يعمل المسح بقارئ باركود USB أو الإدخال اليدوي (لا توجد كاميرا ML Kit على سطح المكتب)، وتُحفظ قاعدة البيانات في `%APPDATA%`.
