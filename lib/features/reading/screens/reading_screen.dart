import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/bible_database.dart';

class ReadingScreen extends StatefulWidget {
  final int bookId;
  final String bookName;
  final List<int> chapters;
  final int dayNumber;
  final int estimatedMinutes;

  const ReadingScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapters,
    required this.dayNumber,
    required this.estimatedMinutes,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Map<String, dynamic>> _verses = [];
  bool _isLoading = true;
  bool _isCompleted = false;
  int _currentChapterIndex = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadVerses() async {
    setState(() => _isLoading = true);
    final chapter = widget.chapters[_currentChapterIndex];
    final verses = await BibleDatabase.getChapter(widget.bookId, chapter);
    setState(() {
      _verses = verses;
      _isLoading = false;
    });
  }

  void _completeReading() {
    setState(() => _isCompleted = true);
    _showCompletionSheet();
  }

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompletionSheet(
        bookName: widget.bookName,
        chapters: widget.chapters,
        dayNumber: widget.dayNumber,
        comment: _commentController.text,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  String get _chapterRangeText {
    if (widget.chapters.length == 1) {
      return '${widget.bookName} ${widget.chapters.first}장';
    }
    return '${widget.bookName} ${widget.chapters.first}-${widget.chapters.last}장';
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
        title: Text(
          'Day ${widget.dayNumber}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        actions: [
          if (widget.chapters.length > 1)
            Row(
              children: widget.chapters.asMap().entries.map((e) {
                final isActive = e.key == _currentChapterIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentChapterIndex = e.key);
                    _loadVerses();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.value}장',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            )
          : Column(
              children: [
                Expanded(child: _buildVerseList()),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildVerseList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: _verses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildChapterHeader();
        final verse = _verses[index - 1];
        return _buildVerseRow(verse);
      },
    );
  }

  Widget _buildChapterHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bookName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          Text(
            '${widget.chapters[_currentChapterIndex]}장',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.border),
        ],
      ),
    );
  }

  Widget _buildVerseRow(Map<String, dynamic> verse) {
    final verseNum = verse['verse'] as int;
    final text = verse['text'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$verseNum',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                height: 1.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.8,
                color: AppColors.text,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: '오늘의 묵상을 남겨보세요 (선택)',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppColors.bgElevated,
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCompleted ? null : _completeReading,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isCompleted ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.success,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isCompleted ? '✓ 통독 완료!' : '통독 완료',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// 완료 팝업 시트
// ═══════════════════════════════════════
class _CompletionSheet extends StatelessWidget {
  final String bookName;
  final List<int> chapters;
  final int dayNumber;
  final String comment;
  final VoidCallback onClose;

  const _CompletionSheet({
    required this.bookName,
    required this.chapters,
    required this.dayNumber,
    required this.comment,
    required this.onClose,
  });

  String get _rangeText {
    if (chapters.length == 1) return '$bookName ${chapters.first}장';
    return '$bookName ${chapters.first}-${chapters.last}장';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            '오늘의 통독 완료!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '23일 연속 통독 달성!\n오늘도 말씀과 동행하셨습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // 공유 카드 미리보기
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF1A2A3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Day $dayNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentLight,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '🔥 23일 연속',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _rangeText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '생명의 말씀이 사락 넘어갑니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'SARAK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.3),
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('공유하기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}