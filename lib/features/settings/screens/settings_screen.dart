import 'notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
    }
  }

  // 🌟 다시 살려낸 부분: 아래에서 스르륵 올라오는 예쁜 로그인 팝업창입니다!
  void _showLoginBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '로그인',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
              ),
              const SizedBox(height: 8),
              const Text(
                '데이터를 안전하게 동기화하세요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 30),

              // 🔴 구글 로그인 버튼
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 1,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context); // 창 닫기
                  await ref.read(authServiceProvider).signInWithGoogle();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 18)),
                    SizedBox(width: 12),
                    Text('Google로 로그인',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 🍏 애플 로그인 버튼 (아이폰일 때만 보여줌)
              if (Platform.isIOS)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // 창 닫기
                    await ref.read(authServiceProvider).signInWithApple();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apple, size: 24), // 애플 기본 아이콘
                      SizedBox(width: 12),
                      Text('Apple로 로그인',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildProfileCard(context, ref, user),
              if (user != null) _buildSyncButton(context, ref),
              if (user == null) const SizedBox(height: 8),
              
              _buildSettingsGroup(context, [
                _buildSettingsItem(context, '🏆', '나의 통독 기록', '', true, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()));
                }),
                _buildSettingsItem(context, '🔔', '알림 설정', '', true, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                  );
                }),
                _buildSettingsItem(context, '📜', '역본 설정', '개역개정', true, () {}),
              ]),
              
              const SizedBox(height: 20),
              _buildInfoSection(context),
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
      child: Text('더보기', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5)),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref, dynamic user) {
    if (user == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('로그인이 필요합니다', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 4),
                  // 🌟 여기를 누르면 팝업창 함수를 부릅니다!
                  GestureDetector(
                    onTap: () => _showLoginBottomSheet(context, ref),
                    child: const Text('여기를 눌러 로그인하세요', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final name = user.displayName ?? '이름 없음';
    final email = user.email ?? '이메일 없음';
    final photoUrl = user.photoURL;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.groupColors[0],
              shape: BoxShape.circle,
              image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null,
            ),
            child: photoUrl == null
                ? Center(child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('로그아웃', style: TextStyle(fontSize: 12, color: AppColors.textTertiary, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24.0, top: 8.0, bottom: 8.0),
        child: InkWell(
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최신 데이터로 동기화 중...'), duration: Duration(seconds: 1)));
            ref.invalidate(authStateProvider);
            ref.invalidate(myGroupsProvider);
            await Future.delayed(const Duration(seconds: 1));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('동기화가 완료되었습니다.')));
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 4),
              Text('최신 동기화', style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('사역후원 및 제안', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          
          _buildDetailItem(context, Icons.favorite_outline, '사역후원', 'icon_new', isPink: true, () {
            _launchURL(context, 'https://www.youtube.com/@biblecraft/join');
          }),
          
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _buildDetailItem(context, Icons.mail_outline, '앱 제안 및 문의', 'biblestorys@naver.com', isBlue: true, () {}),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          
          _buildDetailItem(context, Icons.person_outline, '제작', '@revchanho 유찬호 목사', isAuthor: true, () {
            _launchURL(context, 'https://linktr.ee/biblestorys');
          }),
          
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _buildDetailItem(context, Icons.info_outline, '버전 정보', '1.0.1 (3)', isVersion: true, null),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String trailingText, VoidCallback? onTap, 
      {bool isPink = false, bool isBlue = false, bool isAuthor = false, bool isVersion = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: isPink ? Colors.pinkAccent : (isBlue ? Colors.blueAccent : Colors.grey)),
      title: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.text)),
      trailing: _buildTrailing(trailingText, isAuthor),
    );
  }

  Widget _buildTrailing(String text, bool isAuthor) {
    if (text == 'icon_new') return const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary);
    if (text.isEmpty) return const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(fontSize: 13, color: isAuthor ? Colors.blueAccent : AppColors.textSecondary)),
        if (isAuthor) const Icon(Icons.chevron_right, size: 18, color: Colors.blueAccent),
      ],
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [e.value, if (e.key != items.length - 1) const Divider(height: 1, indent: 56, color: AppColors.border)])).toList()),
    );
  }

  Widget _buildSettingsItem(BuildContext context, String icon, String label, String value, bool isClickable, VoidCallback? onTap) {
    return GestureDetector(
      onTap: isClickable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(icon, style: const TextStyle(fontSize: 16)))),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isClickable ? AppColors.text : AppColors.textSecondary))),
            if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            const SizedBox(width: 4),
            if (isClickable) const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text('${AppConstants.appName} v${AppConstants.appVersion}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          SizedBox(height: 4),
          Text('유튜브 성경공방', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreServiceProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('나의 통독 기록', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.watchCompletionRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final records = snapshot.data ?? [];
          if (records.isEmpty) return const Center(child: Text('아직 완주 기록이 없습니다.'));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              final start = (r['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
              final end = (r['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(r['planName'] ?? '통독 플랜', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)), const Spacer(), const Text('완주 🎉', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange))]),
                    const SizedBox(height: 8),
                    Text('기간: ${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('범위: ${r['range'] ?? '기록 없음'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}