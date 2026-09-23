import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/app_icon.png', width: 170),
                const SizedBox(height: 24),
                const Text(AppConstants.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                const SizedBox(height: 6),
                const Text(AppConstants.appSubtitle, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 40),
                if (state.startupError == null) ...[
                  const SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 5, color: AppColors.gold, backgroundColor: AppColors.goldLight)),
                  const SizedBox(height: 14),
                  Text(state.startupStatus, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ] else ...[
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                  const SizedBox(height: 8),
                  Text('تعذر فتح قاعدة البيانات:\n${state.startupError}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.read<AppState>().init(), child: const Text('إعادة المحاولة')),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text('تطوير وتصميم: محمد الصالحي', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
