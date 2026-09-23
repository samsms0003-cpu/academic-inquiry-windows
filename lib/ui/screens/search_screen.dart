import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/text_utils.dart';
import '../../domain/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'student_profile_screen.dart';

/// شاشة البحث: بالرقم الأكاديمي (مطابقة تامة/بادئة) أو بالاسم مع تصفية مركبة
/// وتحميل تدريجي للنتائج (Paging) دون تحميل كل الطلاب إلى الذاكرة.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  final List<Student> _results = [];
  bool _loading = false;
  bool _hasMore = false;
  bool _searched = false;
  Duration _elapsed = Duration.zero;
  String? _major, _level, _year;
  List<String> _majors = [], _levels = [], _years = [];
  bool _filtersOpen = false;
  static const _page = 50;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && _hasMore && !_loading) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFilters());
  }

  Future<void> _loadFilters() async {
    final repo = context.read<AppState>().repo;
    final m = await repo.distinctStudentValues('major');
    final l = await repo.distinctStudentValues('level');
    final y = await repo.distinctStudentValues('academic_year');
    if (mounted) {
      setState(() {
        _majors = m;
        _levels = l;
        _years = y;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  bool get _isNumeric => RegExp(r'^\d+$').hasMatch(TextUtils.normalizeDigits(_ctrl.text.trim()));

  Future<void> _runSearch() async {
    final term = _ctrl.text.trim();
    _results.clear();
    _hasMore = false;
    if (term.length < 2) {
      setState(() => _searched = false);
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
    });
    final repo = context.read<AppState>().repo;
    final sw = Stopwatch()..start();
    List<Student> r;
    if (_isNumeric) {
      r = await repo.searchByIdPrefix(term, limit: _page);
    } else {
      r = await repo.searchByName(term, limit: _page, major: _major, level: _level, year: _year);
    }
    sw.stop();
    if (!mounted) return;
    setState(() {
      _results.addAll(r);
      _hasMore = r.length == _page;
      _loading = false;
      _elapsed = sw.elapsed;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    final repo = context.read<AppState>().repo;
    final r = _isNumeric
        ? <Student>[]
        : await repo.searchByName(_ctrl.text.trim(), limit: _page, offset: _results.length, major: _major, level: _level, year: _year);
    if (!mounted) return;
    setState(() {
      _results.addAll(r);
      _hasMore = r.length == _page;
      _loading = false;
    });
  }

  void _open(Student s) {
    context.read<AppState>().rememberStudent(s);
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileScreen(student: s)));
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _major != null || _level != null || _year != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث عن طالب'),
        actions: [
          IconButton(
            tooltip: 'تصفية',
            icon: Badge(isLabelVisible: hasFilters, child: const Icon(Icons.filter_list)),
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                onChanged: _onChanged,
                onSubmitted: (_) => _runSearch(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'اكتب الاسم أو جزءًا منه، أو الرقم الأكاديمي',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _ctrl.clear();
                            _runSearch();
                          }),
                ),
              ),
            ),
            if (_filtersOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _filterDrop('التخصص', _majors, _major, (v) => setState(() {
                          _major = v;
                          _runSearch();
                        })),
                    _filterDrop('المستوى', _levels, _level, (v) => setState(() {
                          _level = v;
                          _runSearch();
                        })),
                    _filterDrop('العام', _years, _year, (v) => setState(() {
                          _year = v;
                          _runSearch();
                        })),
                  ],
                ),
              ),
            if (_searched && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text('${_results.length}${_hasMore ? '+' : ''} نتيجة', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text('${_elapsed.inMilliseconds} ms', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            Expanded(
              child: !_searched
                  ? const EmptyState(icon: Icons.person_search, title: 'ابحث عن طالب', subtitle: 'أدخل حرفين على الأقل من الاسم أو أرقام الرقم الأكاديمي.\nالأرقام العربية والإنجليزية مدعومة.')
                  : (_results.isEmpty && !_loading)
                      ? const EmptyState(icon: Icons.search_off, title: 'لا توجد نتائج', subtitle: 'تأكد من كتابة الاسم بشكل صحيح أو جرّب جزءًا أقصر منه')
                      : ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _results.length + (_hasMore || _loading ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (c, i) {
                            if (i >= _results.length) {
                              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                            }
                            final s = _results[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _open(s),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.green.withValues(alpha: 0.12),
                                  child: Text(s.name.isEmpty ? '?' : s.name.characters.first, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                                ),
                                title: Text(s.name.isEmpty ? 'بدون اسم' : s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.academicId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
                                    Text([s.major, s.level, s.academicYear].where((e) => e.isNotEmpty).join(' • '), style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (s.hasGrades) const Icon(Icons.school, size: 16, color: AppColors.info),
                                    if (s.hasAttendance) const Icon(Icons.fact_check, size: 16, color: AppColors.success),
                                    const Icon(Icons.chevron_left),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDrop(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('الكل', style: TextStyle(fontSize: 12))),
          ...items.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
