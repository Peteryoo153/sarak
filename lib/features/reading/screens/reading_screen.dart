import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/bible_database.dart';
import '../../../core/database/reading_settings.dart';
import '../../../core/database/local_storage.dart';

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
  int _currentChapterIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  final ReadingSettings _settings = ReadingSettings();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _settings.load().then((_) => setState(() {}));
    _loadVerses();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _isFirstChapter => _currentChapterIndex == 0;
  bool get _isLastChapter =>
      _currentChapterIndex == widget.chapters.length - 1;

  void _goToPrevChapter() {
    if (_isFirstChapter) return;
    setState(() => _currentChapterIndex--);
    _loadVerses();
  }

  void _goToNextChapter() {
    if (_isLastChapter) return;
    setState(() => _currentChapterIndex++);
    _loadVerses();
  }

  void _finishReading() {
    _showCompletionSheet();
  }

  Future<void> _saveAndComplete() async {
    await LocalStorage.markDayComplete(
      widget.dayNumber,
      comment: _commentController.text,
    );
  }

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompletionSheet(
        bookName: widget.bookName,
        chapters: widget.chapters,
        dayNumber: widget.dayNumber,
        comment: _commentController.text,
        onComplete: () async {
          await _saveAndComplete();
          if (mounted) {
            Navigator.pop(context);
            Navigator.pop(context);
          }
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(settings: _settings),
    ).then((_) => setState(() {}));
  }

  Color get _bgColor =>
      _settings.isDarkMode ? const Color(0xFF1A1A1A) : AppColors.bg;
  Color get _textColor =>
      _settings.isDarkMode ? const Color(0xFFE8E2D8) : AppColors.text;
  Color get _cardColor =>
      _settings.isDarkMode ? const Color(0xFF2A2A2A) : AppColors.bgCard;
  Color get _borderColor =>
      _settings.isDarkMode ? const Color(0xFF3A3A3A) : AppColors.border;

  TextStyle _getFontStyle() {
    final base = TextStyle(
      fontSize: _settings.fontSize,
      height: 1.8,
      color: _textColor,
      fontWeight: FontWeight.w400,
    );
    switch (_settings.fontFamily) {
      case 'NanumMyeongjo':
        return GoogleFonts.nanumMyeongjo(textStyle: base);
      case 'NanumGothic':
        return GoogleFonts.nanumGothic(textStyle: base);
      case 'serif':
        return base.copyWith(fontFamily: 'Georgia');
      case 'sans-serif':
        return base.copyWith(fontFamily: 'Helvetica');
      default:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Day ${widget.dayNumber}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        actions: [
          if (widget.chapters.length > 1)
            ...widget.chapters.asMap().entries.map((e) {
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
                    color: isActive ? AppColors.primary : _bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(
                    '${e.value}장',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : _textColor,
                    ),
                  ),
                ),
              );
            }),
          IconButton(
            icon: Icon(Icons.text_fields, color: _textColor),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.accent))
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
      controller: _scrollController,
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
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _textColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: _borderColor),
        ],
      ),
    );
  }

  Widget _buildVerseRow(Map<String, dynamic> verse) {
    final verseNum = verse['verse'] as int;
    final text = verse['text'] as String;
    final isBookmarked = LocalStorage.isBookmarked(
      bookId: widget.bookId,
      chapter: widget.chapters[_currentChapterIndex],
      verse: verseNum,
    );

    return GestureDetector(
      onLongPress: () async {
        if (isBookmarked) {
          await LocalStorage.removeBookmark(
            bookId: widget.bookId,
            chapter: widget.chapters[_currentChapterIndex],
            verse: verseNum,
          );
        } else {
          await LocalStorage.addBookmark(
            bookId: widget.bookId,
            bookName: widget.bookName,
            chapter: widget.chapters[_currentChapterIndex],
            verse: verseNum,
            text: text,
          );
        }
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBookmarked ? '북마크가 해제되었습니다' : '📌 북마크에 저장되었습니다',
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: isBookmarked
                  ? AppColors.textSecondary
                  : AppColors.accent,
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isBookmarked ? AppColors.accentPale : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isBookmarked
              ? Border.all(color: AppColors.accentLight)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$verseNum',
                style: TextStyle(
                  fontSize: _settings.fontSize * 0.75,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  height: 1.8,
                ),
              ),
            ),
            Expanded(
              child: Text(text, style: _getFontStyle()),
            ),
            if (isBookmarked)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Icon(
                  Icons.bookmark,
                  size: 14,
                  color: AppColors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLastChapter) ...[
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
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                filled: true,
                fillColor: _settings.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : AppColors.bgElevated,
              ),
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: _textColor),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (!_isFirstChapter) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _goToPrevChapter,
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('이전 장'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: _borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isLastChapter ? _finishReading : _goToNextChapter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLastChapter
                        ? AppColors.accent
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLastChapter ? '통독 마무리' : '다음 장',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isLastChapter
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward_ios,
                        size: 14,
                      ),
                    ],
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

// ═══════════════════════════════════════
// 완료 팝업 시트
// ═══════════════════════════════════════
class _CompletionSheet extends StatelessWidget {
  final String bookName;
  final List<int> chapters;
  final int dayNumber;
  final String comment;
  final VoidCallback onComplete;
  final VoidCallback onClose;

  const _CompletionSheet({
    required this.bookName,
    required this.chapters,
    required this.dayNumber,
    required this.comment,
    required this.onComplete,
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
          Container(
            width: 40,
            height: 4,
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
            '오늘도 말씀과 동행하셨습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
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
                  onPressed: onComplete,
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
                    '통독 완료',
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

// ═══════════════════════════════════════
// 설정 시트
// ═══════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final ReadingSettings settings;
  const _SettingsSheet({required this.settings});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  TextStyle _getPreviewFontStyle(ReadingSettings s) {
    final base = TextStyle(
      fontSize: s.fontSize,
      height: 1.8,
      color: s.isDarkMode ? const Color(0xFFE8E2D8) : AppColors.text,
      fontWeight: FontWeight.w400,
    );
    switch (s.fontFamily) {
      case 'NanumMyeongjo':
        return GoogleFonts.nanumMyeongjo(textStyle: base);
      case 'NanumGothic':
        return GoogleFonts.nanumGothic(textStyle: base);
      case 'serif':
        return base.copyWith(fontFamily: 'Georgia');
      case 'sans-serif':
        return base.copyWith(fontFamily: 'Helvetica');
      default:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        color: s.isDarkMode ? const Color(0xFF2A2A2A) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '읽기 설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: s.isDarkMode ? Colors.white : AppColors.text,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '글자 크기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  s.setFontSize(s.fontSize - 1);
                  setState(() {});
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.accent,
              ),
              Expanded(
                child: Slider(
                  value: s.fontSize,
                  min: 12,
                  max: 24,
                  divisions: 12,
                  activeColor: AppColors.accent,
                  onChanged: (v) {
                    s.setFontSize(v);
                    setState(() {});
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  s.setFontSize(s.fontSize + 1);
                  setState(() {});
                },
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.accent,
              ),
              Text(
                '${s.fontSize.round()}px',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '폰트',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.fontOptions.map((font) {
              final isSelected = s.fontFamily == font.name;
              return GestureDetector(
                onTap: () {
                  s.setFontFamily(font.name);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : s.isDarkMode
                            ? const Color(0xFF3A3A3A)
                            : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    font.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : s.isDarkMode
                              ? Colors.white70
                              : AppColors.text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '다크 모드',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.isDarkMode ? Colors.white : AppColors.text,
                ),
              ),
              const Spacer(),
              Switch(
                value: s.isDarkMode,
                activeColor: AppColors.accent,
                onChanged: (v) {
                  s.setDarkMode(v);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: s.isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1  ',
                  style: TextStyle(
                    fontSize: s.fontSize * 0.75,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: Text(
                    '태초에 하나님이 천지를 창조하시니라',
                    style: _getPreviewFontStyle(s),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}