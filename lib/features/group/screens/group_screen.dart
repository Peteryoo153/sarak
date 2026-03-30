import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/member_progress.dart';
import '../../../core/models/sarak_group.dart';
import '../../../core/database/firestore_service.dart';

final groupProgressProvider = StreamProvider.family<List<MemberProgress>, String>((ref, groupId) {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.streamGroupProgress(groupId);
});

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  final _joinCodeController = TextEditingController();
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Color _memberColor(int index) {
    const colors = [
      Color(0xFF2D4A6B), Color(0xFFE8834A), Color(0xFF5BA88B),
      Color(0xFFD4A843), Color(0xFF9B6B9E), Color(0xFF4A90D9),
      Color(0xFFE06B75), Color(0xFF45B7AA),
    ];
    return colors[index % colors.length];
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name.length >= 2 ? name[1] : name[0];
  }

  String _statusText(MemberProgress member, int groupMaxDay) {
    if (member.todayCompleted) return '오늘 완료';
    final diff = groupMaxDay - member.currentDay;
    if (diff <= 0) return '읽는 중';
    return '$diff일 뒤처짐';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return _buildLoginPrompt();
    }

    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (groups) {
            if (groups.isEmpty) {
              return _buildNoGroupScreen();
            }
            return _buildGroupView(groups.first);
          },
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_outlined, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 24),
                const Text('그룹 통독은 로그인이 필요해요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('함께 말씀을 읽으려면\nGoogle 계정으로 로그인하세요', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final authService = ref.read(authServiceProvider);
                      try {
                        await authService.signInWithGoogle();
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
                      }
                    },
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Google로 로그인'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D4A6B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoGroupScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.group_add_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 24),
            const Text('아직 참여 중인 그룹이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('그룹을 만들거나 초대코드로 참여하세요', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                onPressed: () => _showCreateGroupDialog(),
                icon: const Icon(Icons.add, size: 22),
                label: const Text('새 그룹 만들기'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D4A6B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: '초대코드 입력',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _joinGroup(),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('참여'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupView(SarakGroup group) {
    final progressAsync = ref.watch(groupProgressProvider(group.id));
    final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
    final isCreator = group.createdBy == currentUid;

    return progressAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('진행 상황 로딩 오류: $e')),
      data: (members) {
        final sortedMembers = List<MemberProgress>.from(members);
        sortedMembers.sort((a, b) {
          if (a.uid == currentUid) return -1;
          if (b.uid == currentUid) return 1;
          return b.currentDay.compareTo(a.currentDay);
        });

        final completedCount = sortedMembers.where((m) => m.todayCompleted).length;
        final totalCount = sortedMembers.length;
        final groupMaxDay = sortedMembers.isEmpty ? 1 : sortedMembers.map((m) => m.currentDay).reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildTodayStatusCard(group, sortedMembers, completedCount, totalCount, currentUid),
              const SizedBox(height: 12),
              _buildMemberList(sortedMembers, currentUid, groupMaxDay, group.id, isCreator, group),
              if (isCreator) _buildInviteButton(context, group.inviteCode),
              const SizedBox(height: 40),
              if (currentUid != null) _buildLeaveGroupButton(context, group.id, currentUid),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('그룹 통독', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5)),
          SizedBox(height: 4),
          Text('함께 읽으면 더 멀리 갑니다', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(SarakGroup group, List<MemberProgress> members, int completed, int total, String? currentUid) {
    final percent = total > 0 ? (completed / total * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF3D5166)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🏫 ${group.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('$total명', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('$completed', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
              Text(' / $total명 오늘 완료', style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('$percent%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accentLight)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: members.asMap().entries.map((entry) {
              final color = _memberColor(entry.key);
              final isDone = entry.value.todayCompleted;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: isDone ? color : color.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: isDone ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Center(child: Text(_initial(entry.value.name), style: TextStyle(color: isDone ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w700))),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(List<MemberProgress> members, String? currentUid, int groupMaxDay, String groupId, bool isCreator, SarakGroup group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        children: members.asMap().entries.map((entry) {
          final isLast = entry.key == members.length - 1;
          final isMe = entry.value.uid == currentUid;
          return Column(
            children: [
              _buildMemberRow(entry.value, entry.key, isMe, groupMaxDay, groupId, isCreator, group),
              if (!isLast) const Divider(height: 1, indent: 60, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberRow(MemberProgress member, int index, bool isMe, int groupMaxDay, String groupId, bool isCreator, SarakGroup group) {
    final color = _memberColor(index);
    final isCompleted = member.todayCompleted;
    final comment = member.todayComment ?? '';
    final progress = member.progress;
    final status = _statusText(member, groupMaxDay);

    Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Center(child: Text(_initial(member.name), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Center(child: Text('✓', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(member.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
                            child: const Text('나 (터치해서 체크)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.success)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Day ${member.currentDay} · $status', style: TextStyle(fontSize: 11, color: isCompleted ? AppColors.success : AppColors.textSecondary, fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
              ),
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.bgElevated, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5),
                    ),
                  ],
                ),
              ),
              if (isCreator && !isMe) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _confirmRemoveMember(context, groupId, member),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.person_remove, size: 20, color: Colors.redAccent),
                  ),
                ),
              ]
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(10)),
              child: Text(comment, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            ),
          ],
        ],
      ),
    );

    if (isMe) {
      return InkWell(
        onTap: () async {
          final firestore = ref.read(firestoreServiceProvider);
          bool willBeCompleted = !member.todayCompleted;
          
          // 👉 [에러 해결] .toDate()를 제거하고 이미 DateTime인 값을 사용합니다.
          if (willBeCompleted && member.progress >= 1.0) {
            await firestore.saveCompletionRecord(
              planName: group.name,
              startDate: group.startDate ?? group.createdAt ?? DateTime.now(),
              range: group.planType,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 축하합니다! 통독 완주 기록이 저장되었습니다.')));
            }
          }

          final updated = MemberProgress(
            uid: member.uid,
            name: member.name,
            currentDay: member.currentDay,
            todayCompleted: willBeCompleted,
            progress: member.progress,
            streak: member.streak,
            lastReadAt: DateTime.now(),
          );
          await firestore.updateMemberProgress(groupId: groupId, progress: updated);
        },
        child: rowContent,
      );
    }
    return rowContent;
  }

  Widget _buildInviteButton(BuildContext context, String inviteCode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: inviteCode));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('초대코드: $inviteCode 가 복사되었습니다!')));
          },
          icon: const Icon(Icons.link, size: 18),
          label: const Text('그룹 초대코드 복사', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveGroupButton(BuildContext context, String groupId, String currentUid) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmLeaveGroup(context, groupId, currentUid),
        icon: const Icon(Icons.exit_to_app, size: 18, color: Colors.grey),
        label: const Text('이 그룹에서 나가기 (플랜 취소)', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ),
    );
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 그룹 만들기'),
        content: TextField(controller: _groupNameController, decoration: const InputDecoration(hintText: '그룹 이름 (예: 성경공방)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final firestore = ref.read(firestoreServiceProvider);
                final group = await firestore.createGroup(name);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${group.name} 그룹이 생성되었습니다! 초대코드: ${group.inviteCode}')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('그룹 생성 실패: $e')));
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _joinGroup() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final success = await firestore.joinGroup(code);
      if (mounted) {
        if (success) {
          _joinCodeController.clear();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('그룹에 참여했습니다!')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유효하지 않은 초대코드입니다')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('참여 실패: $e')));
    }
  }

  void _confirmRemoveMember(BuildContext context, String groupId, MemberProgress member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('${member.name}님을 그룹에서 정말 내보내시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(firestoreServiceProvider).removeMember(groupId, member.uid);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member.name}님이 그룹에서 제외되었습니다.')));
            },
            child: const Text('내보내기', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context, String groupId, String currentUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그룹 나가기'),
        content: const Text('정말 이 그룹에서 나가시겠습니까? 진행 중이던 통독 기록이 그룹에서 지워집니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(firestoreServiceProvider).removeMember(groupId, currentUid);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('그룹에서 나왔습니다.')));
            },
            child: const Text('나가기', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}