import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubMembersScreen extends StatefulWidget {
  final String userId;
  const ClubMembersScreen({super.key, required this.userId});

  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  // ===== 공통 팔레트 =====
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _chipBlue = Color(0xFF60A5FA);
  static const Color _panel = Color(0xFF1F2937);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  // 가입된 동호회 목록 (홈/게시판이랑 동일)
  final List<String> _joinedClubs = const [
    '볼링스테이션',
    '축구스테이션',
    '풋살스테이션',
    '농구스테이션',
    '33스테이션',
    '배민스테이션',
    '부평농구',
  ];

  late String _selectedClub;

  // 클럽별 정보 (배너 + 스탯)
  late final Map<String, _ClubInfo> _clubInfos = {
    '볼링스테이션': _ClubInfo(
      name: '볼링스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1600132806370-bf3a4b9ba9c1?auto=format&fit=crop&w=1200&q=80',
      point: 4682500,
      totalMatches: 165,
      wins: 96,
      losses: 69,
      rankText: 'Rank #2',
      area: '인천 미추홀구',
      members: 18,
    ),
    '축구스테이션': _ClubInfo(
      name: '축구스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1508609349937-5ec4ae374ebf?auto=format&fit=crop&w=1200&q=80',
      point: 3124000,
      totalMatches: 120,
      wins: 70,
      losses: 50,
      rankText: 'Rank #5',
      area: '서울 성동구',
      members: 24,
    ),
    '풋살스테이션': _ClubInfo(
      name: '풋살스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=1200&q=80',
      point: 1980000,
      totalMatches: 82,
      wins: 48,
      losses: 34,
      rankText: 'Rank #8',
      area: '경기 안산시',
      members: 15,
    ),
    '농구스테이션': _ClubInfo(
      name: '농구스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1518306727298-4c17a1a76e33?auto=format&fit=crop&w=1200&q=80',
      point: 2540000,
      totalMatches: 97,
      wins: 58,
      losses: 39,
      rankText: 'Rank #3',
      area: '인천 연수구',
      members: 21,
    ),
    '33스테이션': _ClubInfo(
      name: '33스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1531415074968-036ba1b575da?auto=format&fit=crop&w=1200&q=80',
      point: 1420000,
      totalMatches: 64,
      wins: 35,
      losses: 29,
      rankText: 'Rank #11',
      area: '서울 마포구',
      members: 12,
    ),
    '배민스테이션': _ClubInfo(
      name: '배민스테이션',
      bannerUrl:
          'https://images.unsplash.com/photo-1528291151371-582c2a5e0df6?auto=format&fit=crop&w=1200&q=80',
      point: 980000,
      totalMatches: 40,
      wins: 22,
      losses: 18,
      rankText: 'Rank #14',
      area: '경기 수원시',
      members: 10,
    ),
    '부평농구': _ClubInfo(
      name: '부평농구',
      bannerUrl:
          'https://images.unsplash.com/photo-1517164850302-7711a7a65b16?auto=format&fit=crop&w=1200&q=80',
      point: 1760000,
      totalMatches: 71,
      wins: 41,
      losses: 30,
      rankText: 'Rank #6',
      area: '인천 부평구',
      members: 17,
    ),
  };

  @override
  void initState() {
    super.initState();
    _selectedClub = _joinedClubs.first;
  }

  // ===== 상단 탭 이동 =====
  void _goTab(BuildContext context, int i) {
    if (i == 3) return; // 현재: 클럽정보
    final uid = widget.userId;
    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/club', arguments: uid);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/clubSchedule', arguments: uid);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/clubBoard', arguments: uid);
        break;
    }
  }

  Widget _tabs(BuildContext context) {
    final tabs = ['홈', '일정', '게시판', '클럽정보'];
    const selected = 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _goTab(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2,
                      width: sel ? 32 : 0,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===== 하단 네비 =====
  void _onTapBottom(int i) {
    final uid = widget.userId;
    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: uid);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/club', arguments: uid);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/community', arguments: uid);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/mypage', arguments: uid);
        break;
    }
  }

  // ===== 드롭다운 (홈/게시판과 동일 스타일) =====
  Widget _clubSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DropdownButtonFormField<String>(
        value: _selectedClub,
        items: _joinedClubs.map((name) {
          return DropdownMenuItem<String>(
            value: name,
            child: Text(name),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedClub = value;
          });
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: _chipBlue,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        dropdownColor: const Color(0xFF1F2937),
        iconEnabledColor: Colors.white,
      ),
    );
  }

  // ===== 클럽명 (라임 컬러) =====
  Widget _clubTitle(_ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(
        info.name,
        style: const TextStyle(
          color: _lime,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ===== 배너 이미지 =====
  Widget _clubBanner(_ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            info.bannerUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF374151),
                alignment: Alignment.center,
                child: const Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ===== 정보 카드 =====
  Widget _infoPanel(_ClubInfo info) {
    final winRate =
        info.totalMatches == 0 ? 0 : (info.wins / info.totalMatches * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 로고 + 이름
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF111827),
                  child: Text(
                    info.name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  info.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 첫 줄: 클럽 point / 총 경기 횟수
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '클럽 point',
                    value: _formatNumber(info.point),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '총 경기 횟수',
                    value: '${info.totalMatches}경기',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 두 번째 줄: 전적 / 지역랭킹
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '전적',
                    value:
                        '${info.wins} W / ${info.losses} L\n(승률 $winRate%)',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '지역랭킹',
                    value: info.rankText,
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 세 번째 줄: 활동지역 / 멤버 수
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '활동지역',
                    value: info.area,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '멤버 수',
                    value: '${info.members}명',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: highlight ? _lime : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // ===== build =====
  @override
  Widget build(BuildContext context) {
    final info = _clubInfos[_selectedClub]!;

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
                const SizedBox(height: 12),
                _tabs(context),
                _clubSelector(),
                _clubTitle(info),
                _clubBanner(info),
                _infoPanel(info),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 1,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTapBottom,
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

// ===== 클럽 정보 모델 =====
class _ClubInfo {
  final String name;
  final String bannerUrl;
  final int point;
  final int totalMatches;
  final int wins;
  final int losses;
  final String rankText;
  final String area;
  final int members;

  const _ClubInfo({
    required this.name,
    required this.bannerUrl,
    required this.point,
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.rankText,
    required this.area,
    required this.members,
  });
}

// 숫자 포인트를 4,682,500 이런 식으로 표시
String _formatNumber(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    buffer.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
