import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubScreen extends StatefulWidget {
  final String userId;
  const ClubScreen({super.key, required this.userId});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  // ===== Palette =====
  static const _bg = Color(0xFF262626);
  static const _panel = Color(0xFF2F2F2F);
  static const _lime = Color(0xFFB7F34D);
  static const _chipBlue = Color(0xFF60A5FA);
  static const _iconActive = Colors.white;
  static const _iconInactive = Color(0xFF9CA3AF);

  // 가입된 동호회 목록 (임시 목업)
  // TODO: /api/my-clubs 연동해서 실제 데이터로 교체
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

  @override
  void initState() {
    super.initState();
    _selectedClub = _joinedClubs.first;
  }

  // ===== Navigation =====
  void _goTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/club', arguments: widget.userId);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/clubSchedule', arguments: widget.userId);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/clubBoard', arguments: widget.userId);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/clubMembers', arguments: widget.userId);
        break;
    }
  }

  Widget _tabs(BuildContext context, int selected) {
    final tabs = ['홈', '일정', '게시판', '클럽원'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _goTab(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2,
                      width: sel ? 32 : 0,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _onTapBottom(BuildContext context, int i) {
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

  // ===== UI pieces =====

  /// Round 로고 왼쪽 정렬 + 상단 탭
  Widget _buildHeader(BuildContext context) {
    return Column(
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _tabs(context, 0),
      ],
    );
  }

  /// 동호회 선택 드롭다운
  Widget _buildClubSelector() {
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
          // TODO: 선택된 클럽 기준으로 상세 데이터 재요청
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  /// 선택된 클럽 이름
  Widget _clubTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        _selectedClub,
        style: const TextStyle(
          color: _lime,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 대표 이미지 영역 – 임시 placeholder
  Widget _banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            '대표 이미지 없음',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _pointRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          const Text('클럽 point', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '4,682,500',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _lime,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 가입 신청 동작
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B3B3B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              '가입 신청',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashtagBlock() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#주말클럽', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(
            '에버 220 이상만 가입 신청',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// "최근 경기 결과" 제목
  Widget _sectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        '최근 경기 결과',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 팀 컬럼(아바타 + 이름)
  Widget _teamColumn(String name, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 경기 카드
  Widget _matchCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 빨간 칩: 동호회 매치
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A3C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '동호회 매치',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 / 시간 (검정 박스 없이 텍스트만)
                SizedBox(
                  width: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        '9월 2일',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '오후',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '12 : 30',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 가운데: 두 팀 + 장소
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 팀 vs 팀
                      Row(
                        children: [
                          Expanded(
                            child: _teamColumn(_selectedClub, Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: _lime,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _TeamSplash(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 장소: 카드 가운데 정렬
                      Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.location_on_outlined,
                                color: Colors.white70, size: 14),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '정석항공과학고 운동장',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 오른쪽: 결과 블럭 (위치 예쁘게 재조정)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      '2 : 0',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '승',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '+1600p',
                      style: TextStyle(
                        color: Color(0xFFFF4D6A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                _buildHeader(context),
                _buildClubSelector(),
                _clubTitle(),
                _banner(),
                _pointRow(),
                _hashtagBlock(),
                _sectionTitle(),
                _matchCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          currentIndex: 1,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (i) => _onTapBottom(context, i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Club'),
            BottomNavigationBarItem(icon: Icon(Icons.groups_2_outlined), label: 'Community'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'My'),
          ],
        ),
      ),
    );
  }
}

/// 오른쪽 팀(스플래쉬) 전용 위젯
class _TeamSplash extends StatelessWidget {
  const _TeamSplash();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.cyan,
        ),
        SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            '스플래쉬',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
