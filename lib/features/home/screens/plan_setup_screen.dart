import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/local_storage.dart';
import '../../../core/database/schedule_engine.dart';

class PlanSetupScreen extends StatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen> {
  int _selectedRange = 0;
  int _selectedDays = 365;
  int _selectedMinutes = 15;
  bool _isGenerating = false;

  final List<Map<String, dynamic>> _ranges = [
    {'label': '신구약 전체', 'chapters': 1189, 'startBook': 1, 'endBook': 66},
    {'label': '구약만', 'chapters': 929, 'startBook': 1, 'endBook': 39},
    {'label': '신약만', 'chapters': 260, 'startBook': 40, 'endBook': 66},
  ];

  final List<int> _dayOptions = [30, 60, 90, 180, 365];
  final List<int> _minuteOptions = [5, 10, 15, 20, 30, 45, 60];

  int get _estimatedDays {
    final chapters = _ranges[_selectedRange]['chapters'] as int;
    const charsPerChapter = 1800;
    final totalChars = chapters * charsPerChapter;
    final charsPerDay = _selectedMinutes * AppConstants.readingSpeedCharsPerMin;
    return (totalChars / charsPerDay).ceil();
  }

  Future<void> _startPlan() async {
    // 기존 플랜이 있으면 경고 팝업
    final existingPlan = LocalStorage.loadPlan();
    if (existingPlan != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '플랜을 변경할까요?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          content: const Text(
            '새 플랜을 시작하면 기존 진행 기록이 모두 초기화됩니다.\n정말 변경하시겠습니까?',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('변경하기'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      if (confirm != true) return;

      // 기존 기록 초기화
      await LocalStorage.clearPlan();
    }

    setState(() => _isGenerating = true);
    final range = _ranges[_selectedRange];
    final plans = await ScheduleEngine.generatePlan(
      startBookId: range['startBook'] as int,
      endBookId: range['endBook'] as int,
      totalDays: _selectedDays,
      minutesPerDay: _selectedMinutes,
    );
    final planData = {
      'rangeName': range['label'],
      'startBookId': range['startBook'],
      'endBookId': range['endBook'],
      'totalDays': plans.length,
      'minutesPerDay': _selectedMinutes,
      'startDate': DateTime.now().toIso8601String(),
      'schedule': plans.map((p) => {
        'dayNumber': p.dayNumber,
        'displayRange': p.displayRange,
        'estimatedMinutes': p.estimatedMinutes,
        'chapters': p.chapters.map((c) => {
          'bookId': c.bookId,
          'bookName': c.bookName,
          'chapter': c.chapter,
        }).toList(),
      }).toList(),
    };
    await LocalStorage.savePlan(planData);
    setState(() => _isGenerating = false);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${range['label']} 통독 플랜 생성 완료! (${plans.length}일)'),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '통독 플랜 만들기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('읽을 범위'),
                  const SizedBox(height: 12),
                  _buildRangeSelector(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('하루 읽기 시간'),
                  const SizedBox(height: 12),
                  _buildMinuteSelector(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('목표 기간'),
                  const SizedBox(height: 12),
                  _buildDaySelector(),
                  const SizedBox(height: 24),
                  _buildEstimateCard(),
                ],
              ),
            ),
          ),
          _buildStartButton(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Column(
      children: _ranges.asMap().entries.map((entry) {
        final i = entry.key;
        final range = entry.value;
        final isSelected = _selectedRange == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedRange = i),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    range['label'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${range['chapters']}장',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMinuteSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _minuteOptions.map((min) {
        final isSelected = _selectedMinutes == min;
        return GestureDetector(
          onTap: () => setState(() => _selectedMinutes = min),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Text(
              '$min분',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _dayOptions.map((day) {
        final isSelected = _selectedDays == day;
        return GestureDetector(
          onTap: () => setState(() => _selectedDays = day),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Text(
              day == 365 ? '1년' : '$day일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEstimateCard() {
    final range = _ranges[_selectedRange];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accentPale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 예상 플랜',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          _buildEstimateRow('읽을 범위', range['label']),
          _buildEstimateRow('하루 읽기', '$_selectedMinutes분'),
          _buildEstimateRow('목표 기간', '$_selectedDays일'),
          _buildEstimateRow(
            '예상 완독',
            '$_estimatedDays일 소요',
            highlight: _estimatedDays <= _selectedDays,
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateRow(String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.success : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isGenerating ? null : _startPlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryLight,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  '플랜 시작하기',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}