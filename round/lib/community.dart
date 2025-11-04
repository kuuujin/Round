import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  const CommunityScreen({super.key, required this.userId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // colors
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);
  static const Color _chipSel = Color(0xFF3B82F6);
  static const Color _chipUnsel = Color(0xFF2F2F2F);

  // categories
  final List<String> _categories = const [
    '볼링','축구','풋살','농구','3x3 농구','배트민턴'
  ];
  String _selectedCategory = '볼링';

  // bottom nav
  void _onTapBottom(int index) {
    if (index == 2) return; // 현재 탭
    final uid = widget.userId;
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/home', arguments: uid); break;
      case 1: Navigator.pushReplacementNamed(context, '/club', arguments: uid); break;
      case 2: Navigator.pushReplacementNamed(context, '/community', arguments: uid); break;
      case 3: Navigator.pushReplacementNamed(context, '/mypage', arguments: uid); break;
    }
  }

  // top tabs (친선경기 / 동호회 / 랭킹)
  void _goTab(int i) {
    final uid = widget.userId;
    if (i == 1) return; // 동호회(현재)
    if (i == 0) Navigator.pushReplacementNamed(context, '/communityFriendly', arguments: uid);
    if (i == 2) Navigator.pushReplacementNamed(context, '/communityRanking',  arguments: uid);
  }

  Widget _topTabs({required int selected}) {
    final tabs = ['친선경기','동호회','랭킹'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _goTab(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tabs[i],
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2, width: sel ? 40 : 0,
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF313131),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3D3D)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: const [
            Icon(Icons.search, color: Colors.white60, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white60,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: '동호회 검색',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.8,
        children: _categories.map((label) {
          final selected = _selectedCategory == label;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = label),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _chipSel : _chipUnsel,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? const Color(0xFF60A5FA) : const Color(0xFF444444),
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
    );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Round',
                    style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),

              _topTabs(selected: 1),  // 동호회 선택
              _searchBar(),
              _categoryGrid(),

              const Expanded(child: SizedBox.shrink()), // 아래는 미구현
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 2,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTapBottom,
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
