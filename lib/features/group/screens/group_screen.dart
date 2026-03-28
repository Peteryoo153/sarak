import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final List<Map<String, dynamic>> members = const [
    {'name': '유찬호', '초성': '찬', 'day': 23, 'status': '읽는 중', 'progress': 0.34, 'colorIndex': 0, 'isMe': true, 'completed': false, 'comment': ''},
    {'name': '김은혜', '초성': '은', 'day': 23, 'status': '오늘 완료', 'progress': 0.34, 'colorIndex': 1, 'isMe': false, 'completed': true, 'comment': '요셉의 이야기가 너무 감동적이었어요 🙏'},
    {'name': '박지현', '초성': '지', 'day': 22, 'status': '1일 뒤처짐', 'progress': 0.31, 'colorIndex': 2, 'isMe': false, 'completed': false, 'comment': ''},
    {'name': '이민수', '초성': '민', 'day': 23, 'status': '오늘 완료', 'progress': 0.34, 'colorIndex': 3, 'isMe': false, 'completed': true, 'comment': '말씀이 살아있습니다'},
    {'name': '정소영', '초성': '소', 'day': 20, 'status': '3일 뒤처짐', 'progress': 0.28, 'colorIndex': 4, 'isMe': false, 'completed': false, 'comment': ''},
    {'name': '최현준', '초성': '현', 'day': 23, 'status': '오늘 완료', 'progress': 0.34, 'colorIndex': 5, 'isMe': false, 'completed': true, 'comment': ''},
    {'name': '한수진', '초성': '수', 'day': 21, 'status': '2일 뒤처짐', 'progress': 0.30, 'colorIndex': 6, 'isMe': false, 'completed': false, 'comment': ''},
  ];

  @override
  Widget build(BuildContext context) {
    final completedCount = members.where((m) => m['completed'] == true).length;
    final totalCount = members.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildTodayStatusCard(completedCount, totalCount),
              const SizedBox(height: 12),
              _buildMemberList(),
              _buildInviteButton(context),
              const SizedBox(height: 20),
            ],
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
            '그룹 통독',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '함께 읽으면 더 멀리 갑니다',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(int completed, int total) {
    final percent = (completed / total * 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF3D5166)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🏫 등대교육공동체',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total명',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$completed',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                ' / $total명 오늘 완료',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completed / total,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          // 아바타 줄
          Row(
            children: members.map((m) {
              final color = AppColors.groupColors[m['colorIndex'] as int];
              final isDone = m['completed'] as bool;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDone ? color : color.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: isDone
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    m['초성'],
                    style: TextStyle(
                      color: isDone ? Colors.white : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: members.asMap().entries.map((entry) {
          final isLast = entry.key == members.length - 1;
          return Column(
            children: [
              _buildMemberRow(entry.value),
              if (!isLast)
                Divider(height: 1, indent: 60, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final color = AppColors.groupColors[member['colorIndex'] as int];
    final isCompleted = member['completed'] as bool;
    final comment = member['comment'] as String;
    final progress = member['progress'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 아바타
              Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        member['초성'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            '✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // 이름 + 상태
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        if (member['isMe'] == true) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '나',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Day ${member['day']} · ${member['status']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: isCompleted
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // 진행 바
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 코멘트
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                comment,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('초대 링크가 복사되었습니다!')),
            );
          },
          icon: const Icon(Icons.link, size: 18),
          label: const Text(
            '그룹 초대 링크 생성',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}