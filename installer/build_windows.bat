@echo off
chcp 65001 >nul
REM ============================================================
REM  بناء نسخة Windows من نظام الاستعلامات الأكاديمية
REM  المتطلبات: Flutter 3.35.4 + Visual Studio 2022 (Desktop development with C++)
REM ============================================================
cd /d "%~dp0.."
echo [1/4] تفعيل منصة Windows ...
call flutter config --enable-windows-desktop
echo [2/4] تحميل الحزم ...
call flutter pub get || goto :err
echo [3/4] بناء الإصدار النهائي ...
call flutter build windows --release || goto :err
echo [4/4] تم البناء. الملف التنفيذي:
echo     %cd%\build\windows\x64\runner\Release\AcademicInquiry.exe
echo.
echo لإنشاء ملف تنصيب (اختياري): ISCC.exe installer\windows_setup.iss
pause
exit /b 0
:err
echo فشل البناء. راجع الرسائل أعلاه.
pause
exit /b 1
