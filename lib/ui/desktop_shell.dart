import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import 'screens/about_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

/// عرض الشاشة الذي يتم عنده التحويل إلى تخطيط سطح المكتب (Windows/Web عريض).
const double kDesktopBreakpoint = 900;

bool isDesktopLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// هيكل سطح المكتب: شريط جانبي (NavigationRail) دائم مع نفس الصفحات والبيانات.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;
  bool _extended = true;

  void goTo(int i) => setState(() => _index = i.clamp(0, 3));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      HomeScreen(onNavigate: goTo),
      const SearchScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // ---------- الشريط الجانبي ----------
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _extended ? 240 : 84,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(left: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6))),
            ),
            child: Column(
              children: [
                _RailHeader(extended: _extended, onToggle: () => setState(() => _extended = !_extended)),
                Expanded(
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: goTo,
                    extended: _extended,
                    minExtendedWidth: 220,
                    labelType: _extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    backgroundColor: Colors.transparent,
                    indicatorColor: AppColors.green.withValues(alpha: .14),
                    selectedIconTheme: const IconThemeData(color: AppColors.green),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('الرئيسية')),
                      NavigationRailDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.saved_search), label: Text('البحث')),
                      NavigationRailDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: Text('التقارير')),
                      NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('الإعدادات')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _RailAction(extended: _extended, icon: Icons.upload_file, label: 'استيراد البيانات', onTap: () => _open(const ImportScreen())),
                _RailAction(extended: _extended, icon: Icons.backup_outlined, label: 'النسخ الاحتياطي', onTap: () => _open(const BackupScreen())),
                _RailAction(extended: _extended, icon: Icons.info_outline, label: 'عن النظام', onTap: () => _open(const AboutScreen())),
                if (state.pinEnabled)
                  _RailAction(extended: _extended, icon: Icons.lock_outline, label: 'قفل النظام', onTap: () => context.read<AppState>().lock()),
                const SizedBox(height: 8),
                if (_extended)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text(
                      'تطوير وتصميم: محمد الصالحي\nالإصدار ${AppConstants.appVersion}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          // ---------- المحتوى ----------
          Expanded(
            child: ClipRect(
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
    );
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended, required this.onToggle});
  final bool extended;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (extended) Image.asset('assets/images/app_icon.png', width: 40, height: 40),
          if (extended) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'الاستعلامات الاكاديمية',
                maxLines: 2,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.green, fontSize: 14),
              ),
            ),
          ],
          IconButton(
            tooltip: extended ? 'طيّ الشريط' : 'توسيع الشريط',
            icon: Icon(extended ? Icons.menu_open : Icons.menu),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({required this.extended, required this.icon, required this.label, required this.onTap});
  final bool extended;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return IconButton(tooltip: label, icon: Icon(icon), onPressed: onTap);
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    );
  }
}
