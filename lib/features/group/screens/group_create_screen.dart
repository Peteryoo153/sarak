import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/schedule_engine.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/sarak_group.dart';

/// 그룹 만들기/플랜 편집 화면.
/// - [existingGroup]이 null이면 "새 그룹 만들기" (이름 포함)
/// - [existingGroup]이 있으면 해당 그룹의 플랜만 수정 (이름 필드 숨김, 생성자만 접근 권장)
class GroupCreateScreen extends ConsumerStatefulWidget {
  final SarakGroup? existingGroup;
  const GroupCreateScreen({super.key, this.existingGroup});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _nameController = TextEditingController();
  int _selectedRange = 0;
  int _selectedDays = 90;
  int _selectedMinutes = 15;
  bool _isSubmitting = false;

  bool get _isEditMode => widget.existingGroup != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGroup;
    if (g != null) {
      _nameController.text = g.name;
      _selectedMinutes = g.minutesPerDay > 0 ? g.minutesPerDay : 15;
      _selectedDays = g.totalDays > 0 ? g.totalDays : 90;
      final idx = _ranges.indexWhere((r) =>
          r['startBook'] == g.startBookId && r['endBook'] == g.endBookId);
      if (idx >= 0) _selectedRange = idx;
    }
  }

  final List<Map<String, dynamic>> _ranges = [
    {'label': '신구약 전체', 'chapters': 1189, 'startBook': 1, 'endBook': 66},
    {'label': '구약만', 'chapters': 929, 'startBook': 1, 'endBook': 39},
    {'label': '신약만', 'chapters': 260, 'startBook': 40, 'endBook': 66},
  ];

  final List<int> _dayOptions = [30, 60, 90, 180, 365];
  final List<int> _minuteOptions = [5, 10, 15, 20, 30, 45, 60];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _estimatedDays {
    final chapters = _ranges[_selectedRange]['chapters'] as int;
    const charsPerChapter = 1800;
    final totalChars = chapters * charsPerChapter;
    final charsPerDay = _selectedMinutes * AppConstants.readingSpeedCharsPerMin;
    return (totalChars / charsPerDay).ceil();
  }

  Future<void> _submit() async {
    if (!_isEditMode) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 이름을 입력해 주세요.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final range = _ranges[_selectedRange];
      final startBookId = range['startBook'] as int;
      final endBookId = range['endBook'] as int;
      final rangeName = range['label'] as String;

      final plans = await ScheduleEngine.generatePlan(
        startBookId: startBookId,
        endBookId: endBookId,
        totalDays: _selectedDays,
        minutesPerDay: _selectedMinutes,
      );

      final schedule = plans
          .map((p) => {
                'dayNumber': p.dayNumber,
                'displayRange': p.displayRange,
                'estimatedMinutes': p.estimatedMinutes,
                'chapters': p.chapters
                    .map((c) => {
                          'bookId': c.bookId,
                          'bookName': c.bookName,
                          'chapter': c.chapter,
                        })
                    .toList(),
              })
          .toList();

      final svc = ref.read(firestoreServiceProvider);

      if (_isEditMode) {
        final g = widget.existingGroup!;
        await svc.updateGroupPlan(
          g.id,
          rangeName: rangeName,
          startBookId: startBookId,
          endBookId: endBookId,
          minutesPerDay: _selectedMinutes,
          totalDays: plans.length,
          schedule: schedule,
          startDate: g.startDate ?? DateTime.now(),
        );
        if (!mounted) return;
        Navigator.pop(context, g);
      } else {
        final created = await svc.createGroup(
          _nameController.text.trim(),
          planType: rangeName,
          totalDays: plans.length,
          startDate: DateTime.now(),
          rangeName: rangeName,
          startBookId: startBookId,
          endBookId: endBookId,
          minutesPerDay: _selectedMinutes,
          schedule: schedule,
        );
        if (!mounted) return;
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditMode ? '그룹 플랜 설정' : '새 그룹 만들기',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditMode) ...[
                    _sectionTitle('그룹 이름'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '예: 우리 교회 90일 통독',
                        filled: true,
                        fillColor: AppColors.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _sectionTitle('읽을 범위'),
                  const SizedBox(height: 12),
                  _buildRangeSelector(),
                  const SizedBox(height: 24),
                  _sectionTitle('하루 읽기 시간'),
                  const SizedBox(height: 12),
                  _buildMinuteSelector(),
                  const SizedBox(height: 24),
                  _sectionTitle('목표 기간'),
                  const SizedBox(height: 12),
                  _buildDaySelector(),
                  const SizedBox(height: 24),
                  _buildEstimateCard(),
                  const SizedBox(height: 8),
                  Text(
                    _isEditMode
                        ? '플랜을 변경해도 기존 멤버의 완료 기록(Day 번호)은 유지됩니다. 해당 Day의 본문만 새 플랜을 따릅니다.'
                        : '이 플랜은 그룹원 모두가 함께 따릅니다. 그룹을 만든 뒤 초대코드를 공유해 보세요.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
      );

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
                  color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color:
                        isSelected ? Colors.white : AppColors.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(range['label'],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.text))),
                Text('${range['chapters']}장',
                    style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white70
                            : AppColors.textSecondary)),
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
                    color: isSelected ? AppColors.accent : AppColors.border)),
            child: Text('$min분',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.text)),
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
                    color: isSelected ? AppColors.accent : AppColors.border)),
            child: Text(day == 365 ? '1년' : '$day일',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.text)),
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
          border: Border.all(color: AppColors.accentLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 예상 플랜',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent)),
          const SizedBox(height: 12),
          _estimateRow('읽을 범위', range['label']),
          _estimateRow('하루 읽기', '$_selectedMinutes분'),
          _estimateRow('목표 기간', '$_selectedDays일'),
          _estimateRow('예상 완독', '$_estimatedDays일 소요',
              highlight: _estimatedDays <= _selectedDays),
        ],
      ),
    );
  }

  Widget _estimateRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppColors.success : AppColors.text)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryLight,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(_isEditMode ? '플랜 저장' : '그룹 만들기',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// 타입 힌트용 (주요 반환 타입 외부 공개)
typedef GroupCreatedCallback = void Function(SarakGroup group);
