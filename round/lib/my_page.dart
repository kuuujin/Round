import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyPageScreen extends StatelessWidget {
  final String userId;
  const MyPageScreen({super.key, required this.userId});

  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  // ---------------- 하단 네비 ----------------
  void _onTapBottom(BuildContext context, int index) {
    if (index == 3) return; // 이미 마이페이지
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: userId);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/club', arguments: userId);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/community', arguments: userId);
        break;
      case 3:
        break;
    }
  }

  // ---------------- 상단 프로필 카드 ----------------
  Widget _profileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF4B5563),
            child: Icon(Icons.person, color: Colors.white70, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '게스트 닉네임',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'User ID: $userId',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 프로필 편집 화면으로 이동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              '프로필 편집',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 내 활동 요약(2x2 카드) ----------------
  Widget _activitySummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 활동 요약',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // 1줄: 총 경기 횟수 / 작성한 게시글
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.sports_esports, // 적당한 경기 아이콘
                  value: '165',
                  label: '총 경기 횟수',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.article_outlined,
                  value: '12',
                  label: '작성한 게시글',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 2줄: 작성한 댓글 / 좋아요한 글
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.chat_bubble_outline,
                  value: '34',
                  label: '작성한 댓글',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.favorite_border,
                  value: '48',
                  label: '좋아요한 글',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF383838),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---------------- 활동 내역 ----------------
  Widget _activityHistory() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 전체 보기
          Row(
            children: [
              const Text(
                '활동 내역',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: 전체 활동 내역 화면
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체 보기',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 경기 기록
          _activityRow(
            icon: Icons.sports_soccer,
            title: '9월 12일 동호회 매치',
            subtitle: '익스플로전 vs 스플래쉬 · 2:0 승',
            tag: '경기 기록',
          ),
          // 리뷰
          _activityRow(
            icon: Icons.image_outlined,
            title: '볼링스테이션 리뷰 작성',
            subtitle: '"레이인 상태 좋고, 만나 친절해요."',
            tag: '리뷰',
          ),
        ],
      ),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3F3F3F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 클럽 관리 ----------------
  Widget _clubManageSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '클럽 관리',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _settingsRow(
            icon: Icons.list_alt_outlined,
            label: '내 클럽 목록',
            onTap: () {
              // TODO: 내 클럽 목록
            },
          ),
          _settingsRow(
            icon: Icons.mail_outline,
            label: '가입 신청 내역',
            onTap: () {
              // TODO: 가입 신청 내역
            },
          ),
          _settingsRow(
            icon: Icons.block_outlined,
            label: '클럽 탈퇴 / 차단 관리',
            onTap: () {
              // TODO: 탈퇴/차단 관리
            },
          ),
        ],
      ),
    );
  }

  // ---------------- 설정 ----------------
  Widget _settingsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '설정',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _settingsRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: () {
              // TODO: 알림 설정 화면
            },
          ),
          _settingsRow(
            icon: Icons.lock_outline,
            label: '계정 · 보안',
            onTap: () {
              // TODO: 계정/보안 화면
            },
          ),
          _settingsRow(
            icon: Icons.map_outlined,
            label: '활동 지역 / 등록 설정',
            onTap: () {
              // TODO: 활동 지역 설정
            },
          ),
          const Divider(
            color: Colors.white10,
            height: 16,
          ),
          _settingsRow(
            icon: Icons.logout,
            label: '로그아웃',
            isDestructive: true,
            onTap: () {
              // TODO: 로그아웃 처리
            },
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFF97373) : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Round',
                    style: TextStyle(
                      color: _lime,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // (요청대로) '마이페이지' 서브타이틀 삭제
                _profileCard(),
                _activitySummary(),
                _activityHistory(),
                _clubManageSection(),
                _settingsSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 3,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (i) => _onTapBottom(context, i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined), label: 'Club'),
            BottomNavigationBarItem(
                icon: Icon(Icons.groups_2_outlined), label: 'Community'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'My'),
          ],
        ),
      ),
    );
  }
}
