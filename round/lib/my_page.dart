import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyPageScreen extends StatelessWidget {
  final String userId;
  const MyPageScreen({super.key, required this.userId});

  // 공통 컬러
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  // ---------------- bottom nav ----------------
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
      default:
        break;
    }
  }

  // ---------------- 프로필 카드 ----------------
  Widget _profileCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 아바타
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF4B5563),
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          // 닉네임 + userId
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '게스트 닉네임',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'User ID: $userId',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 프로필 편집 버튼
          TextButton(
            onPressed: () {
              // TODO: 프로필 편집 화면으로 이동
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF60A5FA),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '프로필 편집',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        ],
      ),
    );
  }

  // ---------------- 내 활동 요약 카드 ----------------
  Widget _activitySummaryCard() {
    // 더미 데이터 (나중에 실제 값으로 교체)
    const totalGames = 165;
    const myPosts = 12;
    const myComments = 34;
    const likedPosts = 48;

    Widget _statItem(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          Row(
            children: [
              _statItem(
                '총 경기 횟수',
                '$totalGames',
                Icons.flag_outlined,
              ),
              const SizedBox(width: 10),
              _statItem(
                '작성한 게시글',
                '$myPosts',
                Icons.article_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statItem(
                '작성한 댓글',
                '$myComments',
                Icons.chat_bubble_outline,
              ),
              const SizedBox(width: 10),
              _statItem(
                '좋아요한 글',
                '$likedPosts',
                Icons.favorite_border,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 활동 내역 카드 ----------------
  Widget _activityHistoryCard() {
    Widget _historyItem({
      required IconData icon,
      required String title,
      required String meta,
      required String badge,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B3B3B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 12),
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B3B3B),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 타이틀 + 전체보기
          Row(
            children: [
              const Expanded(
                child: Text(
                  '활동 내역',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 전체 활동 내역 화면
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체 보기',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFF3F3F3F), height: 1),
          const SizedBox(height: 4),

          // 예시 2줄
          _historyItem(
            icon: Icons.sports_score_outlined,
            title: '9월 12일 동호회 매치',
            meta: '익스플로전 VS 스플래쉬 · 2:0 승',
            badge: '경기 기록',
          ),
          _historyItem(
            icon: Icons.image_outlined,
            title: '볼링스테이션 리뷰 작성',
            meta: '"레이인 상태 좋고, 매너 진선해요."',
            badge: '리뷰',
          ),
        ],
      ),
    );
  }

  // ---------------- 설정 섹션 ----------------
  Widget _settingsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF3F3F3F), height: 1),

          // 기존 3개
          _settingRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: () {},
          ),
          _settingRow(
            icon: Icons.lock_outline,
            label: '계정 · 보안',
            onTap: () {},
          ),
          _settingRow(
            icon: Icons.map_outlined,
            label: '활동 지역 / 등록 설정',
            onTap: () {},
          ),

          const Divider(color: Color(0xFF3F3F3F), height: 1),

          // 새로 추가: 고객센터 / 자주묻는질문 / 공지사항 / 약관및정책
          _settingRow(
            icon: Icons.support_agent,
            label: '고객센터',
            onTap: () {},
          ),
          _settingRow(
            icon: Icons.help_outline,
            label: '자주 묻는 질문',
            onTap: () {},
          ),
          _settingRow(
            icon: Icons.campaign_outlined,
            label: '공지사항',
            onTap: () {},
          ),
          _settingRow(
            icon: Icons.description_outlined,
            label: '약관 및 정책',
            onTap: () {},
          ),

          const Divider(color: Color(0xFF3F3F3F), height: 1),

          // 로그아웃
          _settingRow(
            icon: Icons.logout,
            label: '로그아웃',
            labelColor: const Color(0xFFFF4D6A),
            iconColor: const Color(0xFFFF4D6A),
            onTap: () {
              // TODO: 로그아웃 처리
            },
          ),
        ],
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String label,
    Color? labelColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white38, size: 18),
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // 상단 Round 로고만
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
                _profileCard(context),
                _activitySummaryCard(),
                _activityHistoryCard(),
                _settingsSection(),
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
