import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import 'constants.dart';

/// حالة التطبيق العامة: القاعدة، الإحصائيات، الإعدادات، آخر طالب.
class AppState extends ChangeNotifier {
  AppState();

  late final Repository repo;
  bool ready = false;
  String startupStatus = 'فتح قاعدة البيانات...';
  String? startupError;

  SystemStats stats = const SystemStats();
  Student? lastStudent;
  final List<Student> recentStudents = [];

  ThemeMode themeMode = ThemeMode.light;
  String dateFormat = 'both'; // hijri | gregorian | both
  List<String> headerAr = List.of(AppConstants.defaultHeaderAr);
  List<String> headerEn = List.of(AppConstants.defaultHeaderEn);
  String? headerLogoBase64;
  bool showReportHeader = true;
  bool scanSound = true;
  String scanAction = 'grades-summary';
  double textScale = 1.0;
  String uiFont = 'Cairo';
  String reportFont = 'Cairo';
  Duration lastSearchTime = Duration.zero;

  // ---- قفل التطبيق برمز PIN
  String? _pinHash;
  int pinLength = 4;
  bool locked = false;
  bool get pinEnabled => _pinHash != null;

  static String _hash(String pin) => sha256.convert(utf8.encode('ai-pin:$pin')).toString();

  bool verifyPin(String pin) => _pinHash != null && _hash(pin) == _pinHash;

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void lock() {
    if (pinEnabled) {
      locked = true;
      notifyListeners();
    }
  }

  Future<void> setPin(String? pin) async {
    final p = await SharedPreferences.getInstance();
    if (pin == null || pin.isEmpty) {
      _pinHash = null;
      locked = false;
      p.remove('pinHash');
      p.remove('pinLength');
    } else {
      _pinHash = _hash(pin);
      pinLength = pin.length;
      p.setString('pinHash', _pinHash!);
      p.setInt('pinLength', pinLength);
    }
    notifyListeners();
  }

  Future<void> init() async {
    try {
      startupStatus = 'فتح قاعدة البيانات...';
      notifyListeners();
      await AppDatabase.instance.open();
      repo = Repository(AppDatabase.instance);

      startupStatus = 'قراءة الإعدادات...';
      notifyListeners();
      await _loadPrefs();

      startupStatus = 'قراءة الفهارس...';
      notifyListeners();
      await refreshStats();

      startupStatus = 'جاهز';
      ready = true;
      notifyListeners();
    } catch (e) {
      startupError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    themeMode = (p.getString('theme') ?? 'light') == 'dark' ? ThemeMode.dark : ThemeMode.light;
    dateFormat = p.getString('dateFormat') ?? 'both';
    showReportHeader = p.getBool('showReportHeader') ?? true;
    scanSound = p.getBool('scanSound') ?? true;
    scanAction = p.getString('scanAction') ?? 'grades-summary';
    textScale = p.getDouble('textScale') ?? 1.0;
    uiFont = p.getString('uiFont') ?? 'Cairo';
    _pinHash = p.getString('pinHash');
    pinLength = p.getInt('pinLength') ?? 4;
    locked = _pinHash != null;
    reportFont = p.getString('reportFont') ?? 'Cairo';
    final ar = p.getStringList('headerAr');
    if (ar != null && ar.length == 4) headerAr = ar;
    final en = p.getStringList('headerEn');
    if (en != null && en.length == 4) headerEn = en;
    headerLogoBase64 = p.getString('headerLogo');
    final lastId = p.getString('lastStudentId');
    if (lastId != null) lastStudent = await repo.findByAcademicId(lastId);
    final recent = p.getStringList('recent') ?? [];
    for (final id in recent) {
      final s = await repo.findByAcademicId(id);
      if (s != null) recentStudents.add(s);
    }
  }

  Future<void> refreshStats() async {
    stats = await repo.stats();
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('theme', m == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setDateFormat(String f) async {
    dateFormat = f;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('dateFormat', f);
  }

  Future<void> setTextScale(double s) async {
    textScale = s;
    notifyListeners();
    (await SharedPreferences.getInstance()).setDouble('textScale', s);
  }

  Future<void> setUiFont(String f) async {
    uiFont = f;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('uiFont', f);
  }

  Future<void> setReportFont(String f) async {
    reportFont = f;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('reportFont', f);
  }

  Future<void> setShowReportHeader(bool v) async {
    showReportHeader = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('showReportHeader', v);
  }

  Future<void> setScanPrefs({bool? sound, String? action}) async {
    final p = await SharedPreferences.getInstance();
    if (sound != null) {
      scanSound = sound;
      p.setBool('scanSound', sound);
    }
    if (action != null) {
      scanAction = action;
      p.setString('scanAction', action);
    }
    notifyListeners();
  }

  Future<void> saveHeader(List<String> ar, List<String> en, String? logoB64) async {
    headerAr = ar;
    headerEn = en;
    headerLogoBase64 = logoB64;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setStringList('headerAr', ar);
    p.setStringList('headerEn', en);
    if (logoB64 == null) {
      p.remove('headerLogo');
    } else {
      p.setString('headerLogo', logoB64);
    }
  }

  Future<void> resetHeader() => saveHeader(List.of(AppConstants.defaultHeaderAr), List.of(AppConstants.defaultHeaderEn), null);

  Uint8List? get headerLogoBytes => headerLogoBase64 == null ? null : base64Decode(headerLogoBase64!);

  Future<void> rememberStudent(Student s) async {
    lastStudent = s;
    recentStudents.removeWhere((x) => x.academicId == s.academicId);
    recentStudents.insert(0, s);
    if (recentStudents.length > 8) recentStudents.removeLast();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setString('lastStudentId', s.academicId);
    p.setStringList('recent', recentStudents.map((e) => e.academicId).toList());
  }

  Future<void> clearRecents() async {
    lastStudent = null;
    recentStudents.clear();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.remove('lastStudentId');
    p.remove('recent');
  }
}
