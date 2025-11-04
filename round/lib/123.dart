import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _currentIndex = 0;

  // 팔레트
  static const Color _bg = Color(0xFF262626);
  static const Color _textLime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);
  static const Color _chipSel = Color(0xFF3B82F6);
  static const Color _chipUnsel = Color(0xFF2F2F2F);
  // FAB 색 (다크톤과 자연스럽게)
  static const Color _fabBg = Color(0xFFA3E635);
  static const Color _fabFg = Color(0xFF1F2937);

  final List<String> _categories = const [
    '볼링', '축구', '풋살', '농구', '3x3 농구', '배트민턴',
  ];
  String _selectedCategory = '볼링';

  void _onTapBottom(int index) {
    if (index == _currentIndex) return;
    final uid = widget.userId;
    switch (index) {
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,

        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // 메인 콘텐츠
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 타이틀
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Round',
                      style: TextStyle(
                        color: _textLime,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ✨ 문구 + 버튼
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          '✨ 함께할 동호회를 찾아보세요 ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '동호회 둘러보기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 섹션 제목
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '내 지역 추천 동호회',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 카테고리 버튼 (2줄 3칸)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.8,
                      children: _categories.map((label) {
                        final bool selected = _selectedCategory == label;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = label),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? _chipSel : _chipUnsel,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF444444),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 본문(임시)
                  Expanded(
                    child: Center(
                      child: Text(
                        '선택된 카테고리: $_selectedCategory\nWelcome, ${widget.userId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),

              // 상단 우측 로그아웃(오버레이)
              Positioned(
                right: 6,
                top: 6,
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ),

        // 하단 탭바 (선택된 탭=흰색)
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: _currentIndex,
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

        // + 동그라미 (동호회 개설)
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_create_club',
          backgroundColor: _fabBg,
          foregroundColor: _fabFg,
          elevation: 4,
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/createClub',
              arguments: widget.userId,
            );
          },
          child: const Icon(Icons.add, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
