import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/local_storage.dart';
import '../../../core/providers/auth_provider.dart';
import '../../reading/screens/reading_screen.dart';
import 'plan_setup_screen.dart';
import '../../group/screens/group_screen.dart'; // 그룹 프로바이더 사용을 위해 필요

class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int)? onTabSwitch;

  const HomeScreen({super.key, this.onTabSwitch});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _plan;
  int _streak = 0;
  double _progress = 0.0;
  int _currentDay = 1;
  Map<String, dynamic>? _todayPlan;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      _plan = LocalStorage.loadPlan();
      _streak = LocalStorage.getStreak();
      _progress = LocalStorage.getProgress();
      _currentDay = LocalStorage.getCurrentDay();
      _todayPlan = _getTodayPlan();
    });
  }

  Map<String, dynamic>? _getTodayPlan() {
    if (_plan == null) return null;
    final schedule = _plan!['schedule'] as List<dynamic>?;
    if (schedule == null) return null;
    final idx = (_currentDay - 1).clamp(0, schedule.length - 1);
    return schedule[idx] as Map<String, dynamic>;
  }

  String get _todayRangeText => _todayPlan?['displayRange'] as String? ?? '';
  int get _todayMinutes => _todayPlan?['estimatedMinutes'] as int? ?? 15;
  bool get _hasPlan => _plan != null;

  String get _dateText {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.year}년 ${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  int get _totalDays => (_plan?['totalDays'] as int?) ?? 365;

  List<DateTime> get _thisWeekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
        7,
        (i) => DateTime(monday.year, monday.month, monday.day)
            .add(Duration(days: i)));
  }

  void _goToReading() {
    if (_todayPlan == null) return;
    final chapters = (_todayPlan!['chapters'] as List<dynamic>)
        .map((c) => c as Map<String, dynamic>)
        .toList();
    if (chapters.isEmpty) return;
    final first = chapters.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          bookId: first['bookId'] as int,
          bookName: first['bookName'] as String,
          chapters: chapters.map((c) => c['chapter'] as int).toList(),
          dayNumber: _currentDay,
          estimatedMinutes: _todayMinutes,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _goToDayReading(int dayNum) {
    if (_plan == null) return;
    final schedule = _plan!['schedule'] as List<dynamic>?;
    if (schedule == null) return;
    final dayPlan = schedule[(dayNum - 1).clamp(0, schedule.length - 1)]
        as Map<String, dynamic>;
    final chapters = (dayPlan['chapters'] as List<dynamic>)
        .map((c) => c as Map<String, dynamic>)
        .toList();
    if (chapters.isEmpty) return;
    final first = chapters.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          bookId: first['bookId'] as int,
          bookName: first['bookName'] as String,
          chapters: chapters.map((c) => c['chapter'] as int).toList(),
          dayNumber: dayNum,
          estimatedMinutes: dayPlan['estimatedMinutes'] as int? ?? 15,
        ),
      ),
    ).then((_) => _loadData());
  }

  // --- 플랜 관리 메뉴 ---
  void _showPlanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('통독 플랜 관리',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.primary),
              title: const Text('플랜 수정하기 (오늘부터 1일)'),
              subtitle: const Text('오늘 날짜를 기준으로 일정을 재조정합니다.'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlanSetupScreen()));
                if (result == true) _loadData();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('플랜 취소하기',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('현재 플랜과 모든 진행 기록이 삭제됩니다.'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePlan();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('플랜 취소'),
        content: const Text('정말 플랜을 취소하시겠습니까?\n저장된 모든 진도 기록이 사라집니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('아니오')),
          TextButton(
            onPressed: () async {
              await LocalStorage.clearPlan();
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('플랜이 취소되었습니다.')));
              }
            },
            child:
                const Text('취소하기', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadData();
            ref.invalidate(myGroupsProvider);
          },
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(),
                const SizedBox(height: 16),
                _buildStreakCard(),
                const SizedBox(height: 16),
                _hasPlan ? _buildTodayCard() : _buildNoPlanCard(),
                const SizedBox(height: 16),
                _buildWeeklyScheduleCard(),
                const SizedBox(height: 16),

                // 👥 실제 그룹 데이터 반영
                groupsAsync.when(
                  data: (groups) => groups.isEmpty
                      ? const SizedBox.shrink()
                      : _buildActualGroupCard(groups.first),
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),
                _buildPlanManagementButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dateText,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 4),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFamily: 'Pretendard'),
              children: [
                TextSpan(text: '오늘도 '),
                TextSpan(text: '말씀', style: TextStyle(color: AppColors.accent)),
                TextSpan(text: '과 함께'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF3D5166)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$_streak',
                  style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -2)),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('일 연속',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                  Text('🔥 Streak',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              _hasPlan
                  ? '${_plan!['rangeName']} · ${(_progress * 100).toStringAsFixed(0)}% 완료'
                  : '통독 플랜을 시작해보세요',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    final isCompleted = LocalStorage.isDayComplete(_currentDay);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.accentPale,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Day $_currentDay',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ),
              const Spacer(),
              Text('약 $_todayMinutes분',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_todayRangeText,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCompleted ? null : _goToReading,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCompleted ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.success,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(isCompleted ? '✓ 오늘 완료!' : '오늘 말씀 읽기',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlanCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.accentPale,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentLight)),
      child: const Column(
        children: [
          Text('📖', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('통독 플랜이 없습니다',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          SizedBox(height: 6),
          Text('아래 버튼을 눌러 나만의\n통독 플랜을 만들어보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleCard() {
    final weekDays = _thisWeekDays;
    final completedDays = LocalStorage.getCompletedDays();
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();
    final todayOnlyDate = DateTime(today.year, today.month, today.day);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이번 주 일정',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              GestureDetector(
                onTap: () => widget.onTabSwitch?.call(1),
                child: const Text('전체 보기 →',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final isToday = day.isAtSameMomentAs(todayOnlyDate);
              final isPast = day.isBefore(todayOnlyDate);

              int? dayNum;
              if (_plan != null) {
                final startDate = DateTime.parse(_plan!['startDate'] as String);
                final startOnlyDate =
                    DateTime(startDate.year, startDate.month, startDate.day);
                final diff = day.difference(startOnlyDate).inDays + 1;
                if (diff > 0 && diff <= _totalDays) dayNum = diff;
              }

              final isCompleted = dayNum != null &&
                  completedDays.containsKey(dayNum.toString());

              return GestureDetector(
                onTap: () {
                  if (dayNum != null) _goToDayReading(dayNum);
                },
                child: Column(
                  children: [
                    Text(dayLabels[i],
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary)),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.successLight
                            : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isToday
                              ? AppColors.accent
                              : (isCompleted
                                  ? const Color(0xFFB8E6CA)
                                  : AppColors.border),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text('${day.day}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isToday
                                    ? AppColors.accent
                                    : (isPast || isToday
                                        ? AppColors.text
                                        : AppColors.textTertiary))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isCompleted)
                      const Text('✓',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w700))
                    else
                      const SizedBox(height: 14),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 👥 실제 그룹 정보를 가져오는 카드 위젯
  Widget _buildActualGroupCard(dynamic group) {
    final membersAsync = ref.watch(groupProgressProvider(group.id));

    return membersAsync.when(
      data: (members) {
        final total = members.length;
        final visibleMembers = members.take(4).toList();
        final extraCount = total - 4;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('함께 읽는 그룹',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  GestureDetector(
                    onTap: () => widget.onTabSwitch?.call(2),
                    child: const Text('보기 →',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: (visibleMembers.length * 26 + 10).toDouble() +
                        (extraCount > 0 ? 26 : 0),
                    height: 36,
                    child: Stack(
                      children: [
                        ...visibleMembers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final member = entry.value;
                          return Positioned(
                            left: idx * 26.0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.groupColors[
                                    idx % AppColors.groupColors.length],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.bgCard, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  member.name.isNotEmpty
                                      ? member.name[member.name.length - 1]
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (extraCount > 0)
                          Positioned(
                            left: visibleMembers.length * 26.0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.bgCard, width: 2)),
                              child: Center(
                                  child: Text('+$extraCount',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary))),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${group.name} · $total명',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildPlanManagementButton() {
    return GestureDetector(
      onTap: _hasPlan
          ? _showPlanOptions
          : () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlanSetupScreen()));
              if (result == true) _loadData();
            },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Text(_hasPlan ? '🗓️' : '📖', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _hasPlan ? '통독 플랜 관리하기' : '새 통독 플랜 만들기',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
