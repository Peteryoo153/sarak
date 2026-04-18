import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform; // 🌟 애플 기기인지 확인하는 부품 추가
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/member_progress.dart';
import '../../../core/models/sarak_group.dart';
import '../../../core/database/local_storage.dart';
import 'group_create_screen.dart';

// 🌟 실시간 그룹 진도 감시자.
// authStateProvider가 준비된 뒤에만 Firestore listener를 붙이도록 해서
// 로그인 직후 credential 전파가 덜 된 상태에서 permission-denied를 맞는 레이스를 피함.
final groupProgressProvider =
    StreamProvider.family<List<MemberProgress>, String>((ref, groupId) {
  final authState = ref.watch(authStateProvider);
  if (authState.valueOrNull == null) return Stream.value(const <MemberProgress>[]);
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

  // 현재 화면에 표시 중인 그룹 id. null이면 groups.first로 폴백
  String? _selectedGroupId;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  // 목사님의 세심한 컬러 선택 유지
  Color _memberColor(int index) {
    const colors = [
      Color(0xFF2D4A6B),
      Color(0xFFE8834A),
      Color(0xFF5BA88B),
      Color(0xFFD4A843),
      Color(0xFF9B6B9E),
      Color(0xFF4A90D9),
      Color(0xFFE06B75),
      Color(0xFF45B7AA),
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

    if (user == null) return _buildLoginPrompt();

    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (groups) {
            if (groups.isEmpty) return _buildNoGroupScreen();
            // 선택된 id가 현재 목록에 있으면 사용, 아니면 첫 그룹으로 폴백
            // (나가기/삭제 등으로 기존 선택이 사라져도 안전)
            final displayed = groups.firstWhere(
              (g) => g.id == _selectedGroupId,
              orElse: () => groups.first,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildGroupTabs(groups, displayed.id),
                Expanded(child: _buildGroupView(displayed)),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- 🌟 수정된 부분: 로그인 프롬프트 (애플 버튼 추가) ---
  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 24),
            const Text('그룹 통독은 로그인이 필요해요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),
            
            // 🔴 구글 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(authServiceProvider).signInWithGoogle(),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Google로 로그인'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D4A6B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            
            const SizedBox(height: 12), // 버튼 사이 간격

            // 🍏 애플 로그인 버튼 (아이폰일 때만 보여줌)
            if (Platform.isIOS)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(authServiceProvider).signInWithApple(),
                  icon: const Icon(Icons.apple, size: 24),
                  label: const Text('Apple로 로그인'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.black, // 애플은 블랙
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 그룹 없음 화면 ---
  Widget _buildNoGroupScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.group_add_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 24),
            const Text('아직 참여 중인 그룹이 없어요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _openCreateGroup,
                icon: const Icon(Icons.add),
                label: const Text('새 그룹 만들기'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D4A6B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    height: 52,
                    child: FilledButton(
                        onPressed: _joinGroup,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent),
                        child: const Text('참여'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 🌟 핵심: 그룹 뷰 ---
  Widget _buildGroupView(SarakGroup group) {
    final progressAsync = ref.watch(groupProgressProvider(group.id));
    final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
    final isCreator = group.createdBy == currentUid;

    // 내가 이 그룹 플랜을 쓰는 중이라면 방장이 바꾼 스케줄을 로컬에도 자동 반영
    _maybeSyncActivePlan(group);

    return progressAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('로딩 오류: $e')),
      data: (members) {
        final sortedMembers = List<MemberProgress>.from(members);
        sortedMembers.sort((a, b) {
          if (a.uid == currentUid) return -1;
          if (b.uid == currentUid) return 1;
          return b.currentDay.compareTo(a.currentDay);
        });

        final completedCount =
            sortedMembers.where((m) => m.todayCompleted).length;
        final totalCount = sortedMembers.length;
        final groupMaxDay = sortedMembers.isEmpty
            ? 1
            : sortedMembers
                .map((m) => m.currentDay)
                .reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayStatusCard(
                  group, sortedMembers, completedCount, totalCount),
              const SizedBox(height: 12),
              _buildPlanSection(group, isCreator),
              const SizedBox(height: 12),
              _buildMemberList(sortedMembers, currentUid, groupMaxDay, group.id,
                  isCreator, group),
              if (isCreator) _buildInviteButton(context, group.inviteCode),
              const SizedBox(height: 40),
              if (currentUid != null)
                _buildLeaveGroupButton(context, group.id, currentUid),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// 그룹 플랜 섹션: 플랜 정보 표시 + "이 플랜으로 함께 읽기" 전환 버튼
  /// 생성자에게는 플랜이 없으면 "플랜 설정하기", 있으면 "플랜 수정" 메뉴도 노출
  Widget _buildPlanSection(SarakGroup group, bool isCreator) {
    final source = LocalStorage.groupSource(group.id);
    final isActive = LocalStorage.getActiveSource() == source;
    final hasSchedule = group.hasSchedule;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
              const Icon(Icons.menu_book_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('그룹 플랜',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const Spacer(),
              if (hasSchedule && isCreator)
                TextButton(
                  onPressed: () => _openEditGroupPlan(group),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32)),
                  child: const Text('수정',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasSchedule) ...[
            const Text(
              '아직 이 그룹의 플랜이 설정되지 않았습니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (isCreator)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openEditGroupPlan(group),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('플랜 설정하기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              const Text(
                '그룹을 만든 사람이 플랜을 설정할 때까지 기다려 주세요.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
          ] else ...[
            Text(
              '${group.rangeName.isNotEmpty ? group.rangeName : group.planType} · ${group.minutesPerDay}분/일 · 총 ${group.totalDays}일',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentPale,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentLight),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 14, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text('현재 이 플랜으로 읽는 중',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _activateGroupPlan(group),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('이 플랜으로 함께 읽기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 최신 그룹 스케줄과 로컬 캐시를 비교하여 달라졌으면 자동 재저장.
  /// 활성 소스가 이 그룹이 아닌 경우에는 아무것도 하지 않음.
  void _maybeSyncActivePlan(SarakGroup group) {
    if (!group.hasSchedule) return;
    final source = LocalStorage.groupSource(group.id);
    if (LocalStorage.getActiveSource() != source) return;

    final local = LocalStorage.loadPlanFor(source);
    final needsResync = local == null ||
        local['totalDays'] != group.totalDays ||
        local['minutesPerDay'] != group.minutesPerDay ||
        local['startBookId'] != group.startBookId ||
        local['endBookId'] != group.endBookId ||
        (local['schedule'] as List?)?.length != group.schedule.length;
    if (!needsResync) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activateGroupPlan(group, silent: true);
    });
  }

  /// 그룹 플랜을 내 로컬 활성 플랜으로 전환.
  /// [silent]가 true면 스낵바를 띄우지 않음 (백그라운드 자동 동기화 등)
  Future<void> _activateGroupPlan(SarakGroup group,
      {bool silent = false}) async {
    if (!group.hasSchedule) return;

    // 기존 개인 진행 기록은 유지(활성 소스만 변경)되며,
    // 이 그룹 소스의 완료 기록은 별도로 누적됩니다.
    final planData = {
      'rangeName': group.rangeName.isNotEmpty ? group.rangeName : group.planType,
      'startBookId': group.startBookId,
      'endBookId': group.endBookId,
      'totalDays': group.totalDays,
      'minutesPerDay': group.minutesPerDay,
      'startDate': (group.startDate ?? DateTime.now()).toIso8601String(),
      'schedule': group.schedule,
      'source': LocalStorage.groupSource(group.id),
      'groupId': group.id,
      'groupName': group.name,
    };

    final source = LocalStorage.groupSource(group.id);
    await LocalStorage.setActiveSource(source);
    await LocalStorage.savePlanFor(source, planData);

    if (!mounted) return;
    setState(() {}); // 뱃지 재렌더
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${group.name}" 플랜으로 함께 읽기 시작!'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('그룹 통독',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        Text('함께 읽으면 더 멀리 갑니다',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  // 여러 그룹 간 전환용 가로 스크롤 탭. 마지막에 "추가" 칩으로 신규 그룹 생성/참여
  Widget _buildGroupTabs(List<SarakGroup> groups, String selectedId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            ...groups.map((g) {
              final selected = g.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g.name),
                  selected: selected,
                  onSelected: (_) {
                    if (!selected) {
                      setState(() => _selectedGroupId = g.id);
                    }
                  },
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.bgCard,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
              onPressed: _showAddGroupSheet,
              backgroundColor: AppColors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "추가" 칩을 눌렀을 때 그룹 만들기/참여 중 선택하게 해주는 바텀시트
  void _showAddGroupSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('새 그룹 만들기'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCreateGroup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('초대코드로 참여'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showJoinGroupDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 초대코드 입력 다이얼로그 (이미 그룹에 속한 상태에서 다른 그룹에 추가 참여)
  void _showJoinGroupDialog() {
    _joinCodeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대코드로 참여'),
        content: TextField(
          controller: _joinCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '초대코드 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _joinGroup();
            },
            child: const Text('참여'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(SarakGroup group, List<MemberProgress> members,
      int completed, int total) {
    final percent = total > 0 ? (completed / total * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF3D5166)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text('🏫 ${group.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Text('$total명',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Text('$completed',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const Text(' / 오늘 완료', style: TextStyle(color: Colors.white70)),
          const Spacer(),
          Text('$percent%',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentLight)),
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(
            value: total > 0 ? completed / total : 0,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            minHeight: 6),
      ]),
    );
  }

  Widget _buildMemberList(List<MemberProgress> members, String? currentUid,
      int groupMaxDay, String groupId, bool isCreator, SarakGroup group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
          children: members
              .asMap()
              .entries
              .map((entry) => _buildMemberRow(
                  entry.value,
                  entry.key,
                  entry.value.uid == currentUid,
                  groupMaxDay,
                  groupId,
                  isCreator,
                  group))
              .toList()),
    );
  }

  Widget _buildMemberRow(MemberProgress member, int index, bool isMe,
      int groupMaxDay, String groupId, bool isCreator, SarakGroup group) {
    final color = _memberColor(index);
    final hasComment = (member.todayComment ?? '').trim().isNotEmpty;
    return ListTile(
      leading: CircleAvatar(
          backgroundColor: color,
          child: Text(_initial(member.name),
              style: const TextStyle(color: Colors.white))),
      title: Text(member.name,
          style: TextStyle(
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Day ${member.currentDay} · ${_statusText(member, groupMaxDay)}'),
          if (hasComment) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💬 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    member.todayComment!.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      isThreeLine: hasComment,
      trailing: isMe
          ? IconButton(
              icon: Icon(
                  member.todayCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: AppColors.success),
              onPressed: () => _toggleMyProgress(member, group))
          : Icon(
              member.todayCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: Colors.grey[300]),
    );
  }

  Future<void> _toggleMyProgress(
      MemberProgress member, SarakGroup group) async {
    final firestore = ref.read(firestoreServiceProvider);
    final willBeCompleted = !member.todayCompleted;

    if (willBeCompleted && member.progress >= 1.0) {
      await firestore.saveCompletionRecord(
        planName: group.name,
        startDate: group.startDate ?? group.createdAt,
        range: group.planType,
      );
    }

    final updated = MemberProgress(
      uid: member.uid,
      name: member.name,
      currentDay: member.currentDay,
      todayCompleted: willBeCompleted,
      // 완료 취소 시엔 한마디도 같이 비움
      todayComment: willBeCompleted ? member.todayComment : null,
      progress: member.progress,
      streak: member.streak,
      lastReadAt: DateTime.now(),
    );
    await firestore.updateMemberProgress(groupId: group.id, progress: updated);
  }

  Future<void> _openCreateGroup() async {
    final created = await Navigator.push<SarakGroup?>(
      context,
      MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
    );
    if (!mounted || created == null) return;
    setState(() => _selectedGroupId = created.id);
    // 만든 사람도 자동으로 이 그룹 플랜을 활성 플랜으로 사용
    if (created.hasSchedule) {
      await _activateGroupPlan(created, silent: true);
    }
  }

  Future<void> _openEditGroupPlan(SarakGroup group) async {
    await Navigator.push<SarakGroup?>(
      context,
      MaterialPageRoute(
          builder: (_) => GroupCreateScreen(existingGroup: group)),
    );
    if (!mounted) return;
    // 내가 해당 그룹 플랜을 활성 중이라면 로컬 캐시도 새 스케줄로 갱신
    final source = LocalStorage.groupSource(group.id);
    if (LocalStorage.getActiveSource() == source) {
      // watchGroup 스트림이 최신 SarakGroup을 전달하면 아래에서 캐시 갱신됨
    }
  }

  Future<void> _joinGroup() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final joined = await ref.read(firestoreServiceProvider).joinGroup(code);
    _joinCodeController.clear();
    if (!mounted) return;
    if (joined == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('잘못된 초대코드입니다.')),
      );
      return;
    }
    // 방금 참여한 그룹을 자동 선택 + 해당 그룹 플랜으로 자동 전환
    setState(() => _selectedGroupId = joined.id);
    if (joined.hasSchedule) {
      await _activateGroupPlan(joined, silent: false);
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text('"${joined.name}" 그룹에 참여했습니다. 방장이 플랜을 설정하면 자동으로 적용됩니다.')));
    }
  }

  // --- 🌟 초대코드 복사 및 스낵바 알림 ---
  Widget _buildInviteButton(BuildContext context, String inviteCode) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('초대코드가 복사되었습니다!'),
                  backgroundColor: AppColors.accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text('초대코드 복사: $inviteCode')));
  }

  // --- 🌟 그룹 나가기 버튼 ---
  Widget _buildLeaveGroupButton(
      BuildContext context, String groupId, String uid) {
    return Center(
      child: TextButton(
        onPressed: () => _confirmLeaveGroup(context, groupId, uid),
        child: const Text(
          '그룹 나가기',
          style: TextStyle(
            color: Colors.grey,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  // --- 🌟 그룹 나가기 로직 ---
  Future<void> _confirmLeaveGroup(
      BuildContext context, String groupId, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그룹 나가기'),
        content: const Text('정말 이 그룹에서 나가시겠습니까?\n내 활동 기록이 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (leave == true) {
      try {
        await ref.read(firestoreServiceProvider).leaveGroup(groupId);
        // 선택이 나간 그룹이면 초기화 → 빌드 시 남은 그룹 중 첫 번째로 폴백
        if (mounted && _selectedGroupId == groupId) {
          setState(() => _selectedGroupId = null);
        }
        messenger.showSnackBar(
          const SnackBar(content: Text('그룹에서 성공적으로 나갔습니다.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }
}