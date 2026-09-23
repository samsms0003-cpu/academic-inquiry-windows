import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../theme/app_theme.dart';

/// شاشة قفل التطبيق برمز PIN (اختيارية من الإعدادات).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;

  void _press(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length >= 4) _check();
  }

  void _check() {
    final state = context.read<AppState>();
    if (state.verifyPin(_pin)) {
      state.unlock();
    } else if (_pin.length >= (state.pinLength)) {
      setState(() {
        _error = 'الرمز غير صحيح';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/app_icon.png', width: 110),
              const SizedBox(height: 10),
              const Text(AppConstants.appName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
              const SizedBox(height: 24),
              const Text('أدخل رمز القفل', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? AppColors.green : Colors.transparent, border: Border.all(color: AppColors.green, width: 2)),
                    )),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
              const SizedBox(height: 24),
              SizedBox(
                width: 260,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) _key(d, () => _press(d)),
                    _key('⌫', () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)), muted: true),
                    _key('0', () => _press('0')),
                    _key('✓', _check, accent: true),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text('تطوير وتصميم: محمد الصالحي', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(String t, VoidCallback onTap, {bool muted = false, bool accent = false}) => Material(
        color: accent ? AppColors.green : (muted ? AppColors.goldLight : Colors.white),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: accent ? Colors.white : AppColors.textPrimary))),
        ),
      );
}
