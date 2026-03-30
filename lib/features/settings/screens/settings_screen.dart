import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/local_storage.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildProfileCard(),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, [
                _buildSettingsItem(context, '📖', '통독 플랜 관리', ''),
                _buildSettingsItem(context, '📝', '나의 묵상 기록', ''),
                _buildSettingsItem(context, '📌', '북마크', ''),
                _buildSettingsItem(context, '🔔', '알림 설정', ''),
              ]),
              const SizedBox(height: 8),
              _buildSettingsGroup(context, [
                _buildSettingsItem(context, '📜', '역본 설정', '개역개정'),
                _buildSettingsItem(context, '☕', '개발자 후원하기', ''),
              ]),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Text(
        '더보기',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.groupColors[0],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '찬',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '유찬호',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'chanhoyoo@apple.com',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.border,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, String icon, String label, String value) {
    return GestureDetector(
      onTap: () {
        if (label == '북마크') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookmarkScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            '${AppConstants.appName} v${AppConstants.appVersion}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '성경공방 · 등대교육공동체',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// 북마크 화면
// ═══════════════════════════════════════
class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  List<Map<String, dynamic>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarks = LocalStorage.getBookmarks();
    });
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
          '북마크',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: _bookmarks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📌', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text(
                    '저장된 북마크가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '성경 본문에서 절을 길게 누르면\n북마크에 저장됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final b = _bookmarks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
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
                              color: AppColors.accentPale,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${b['bookName']} ${b['chapter']}:${b['verse']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await LocalStorage.removeBookmark(
                                bookId: b['bookId'] as int,
                                chapter: b['chapter'] as int,
                                verse: b['verse'] as int,
                              );
                              _loadBookmarks();
                            },
                            child: const Icon(
                              Icons.bookmark_remove_outlined,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b['text'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
