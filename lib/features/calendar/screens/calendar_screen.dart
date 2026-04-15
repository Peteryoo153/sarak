import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/local_storage.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  Map<String, dynamic> _completedDays = {};
  Map<String, dynamic>? _plan;
  String? _selectedComment;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() {
    setState(() {
      _completedDays = LocalStorage.getCompletedDays();
      _plan = LocalStorage.loadPlan();
    });
  }

  int _getDayNumber(DateTime date) {
    if (_plan == null) return -1;
    final startDate = DateTime.parse(_plan!['startDate'] as String);
    final diff = date.difference(startDate).inDays + 1;
    final totalDays = (_plan!['totalDays'] as int?) ?? 365;
    if (diff < 1 || diff > totalDays) return -1;
    return diff;
  }

  bool _isCompleted(DateTime date) {
    final dayNum = _getDayNumber(date);
    if (dayNum < 0) return false;
    return _completedDays.containsKey(dayNum.toString());
  }

  bool _hasComment(DateTime date) {
    final dayNum = _getDayNumber(date);
    if (dayNum < 0) return false;
    final data = _completedDays[dayNum.toString()];
    if (data == null) return false;
    final comment = (data as Map<String, dynamic>)['comment'] as String?;
    return comment != null && comment.isNotEmpty;
  }

  String? _getComment(DateTime date) {
    final dayNum = _getDayNumber(date);
    if (dayNum < 0) return null;
    final data = _completedDays[dayNum.toString()];
    if (data == null) return null;
    return (data as Map<String, dynamic>)['comment'] as String?;
  }

  List<DateTime> get _daysInMonth {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final last = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    return List.generate(
        last.day, (i) => DateTime(first.year, first.month, i + 1));
  }

  int get _completedThisMonth {
    return _daysInMonth.where((d) => _isCompleted(d)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => loadData(),
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildStreakSummary(),
                const SizedBox(height: 16),
                _buildCalendar(),
                const SizedBox(height: 12),
                _buildLegend(),
                if (_selectedComment != null) _buildCommentCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '말씀통독 달력',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month - 1);
                  _selectedComment = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.chevron_left,
                      size: 20, color: AppColors.text),
                ),
              ),
              Expanded(
                child: Text(
                  '${_currentMonth.year}년 ${_currentMonth.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month + 1);
                  _selectedComment = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSummary() {
    final streak = LocalStorage.getStreak();
    final bestStreak = LocalStorage.getBestStreak();
    final progress = LocalStorage.getProgress();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildSummaryItem('🔥', '$streak일', '현재 연속'),
          const SizedBox(width: 8),
          _buildSummaryItem('🏆', '$bestStreak일', '최고 연속'),
          const SizedBox(width: 8),
          _buildSummaryItem('📖', '$_completedThisMonth일', '이번 달'),
          const SizedBox(width: 8),
          _buildSummaryItem('✅', '${(progress * 100).round()}%', '전체'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 요일 헤더
          Row(
            children: weekdays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: day == '일'
                                ? Colors.red[300]
                                : day == '토'
                                    ? Colors.blue[300]
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // 날짜 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
            ),
            itemCount: startOffset + _daysInMonth.length,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox();

              final date = _daysInMonth[index - startOffset];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isCompleted = _isCompleted(date);
              final hasComment = _hasComment(date);
              final isFuture = date.isAfter(today);
              final isSelected = _selectedDay == date.day;

              return GestureDetector(
                onTap: () {
                  if (hasComment) {
                    setState(() {
                      _selectedComment = _getComment(date);
                      _selectedDay = date.day;
                    });
                  } else {
                    setState(() {
                      _selectedComment = null;
                      _selectedDay = null;
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        // 읽은 날: 진한 초록, 오늘: 네이비, 미래: 연회색
                        color: isToday
                            ? AppColors.primary
                            : isSelected
                                ? AppColors.accentPale
                                : isCompleted
                                    ? const Color(0xFF27AE60) // 진한 초록
                                    : isFuture
                                        ? Colors.transparent
                                        : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: AppColors.accent, width: 2)
                            : isToday
                                ? null
                                : isCompleted
                                    ? Border.all(
                                        color: const Color(0xFF219A52),
                                        width: 1)
                                    : Border.all(
                                        color: isFuture
                                            ? Colors.transparent
                                            : const Color(0xFFEEEEEE),
                                        width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isCompleted
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: isToday
                                ? Colors.white
                                : isCompleted
                                    ? Colors.white // 읽은 날 흰색 텍스트
                                    : isFuture
                                        ? AppColors.textTertiary
                                        : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    // 묵상 있음 도트
                    if (hasComment)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          const Text('읽기 완료',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
          ),
          const SizedBox(width: 6),
          const Text('미읽음',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('묵상 있음',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCommentCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentPale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentMonth.month}월 $_selectedDay일 묵상 ✍️',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedComment ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedComment = null;
              _selectedDay = null;
            }),
            child: const Icon(Icons.close,
                size: 16, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
