import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round/community_club.dart';  
import 'package:round/community_ranking.dart';  
import 'package:round/community_friendly.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  const CommunityScreen({super.key, required this.userId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  // 1. 현재 선택된 상단 탭 인덱스 (기본값: 1 동호회)
  int _currentTabIndex = 1;

  // 2. 탭별 화면 위젯 리스트
  late List<Widget> _tabViews;

  @override
  void initState() {
    super.initState();
    _tabViews = [
      CommunityFriendlyTab(userId: widget.userId), // 0: 친선경기
      CommunityClubTab(userId: widget.userId),     // 1: 동호회 (올려주신 코드)
      CommunityRankingTab(userId: widget.userId),  // 2: 랭킹
    ];
  }

  // 하단 탭 이동
  void _onTapBottom(int index) {
    if (index == 2) return;
    final uid = widget.userId;
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/home', arguments: uid); break;
      case 1: Navigator.pushReplacementNamed(context, '/club', arguments: uid); break;
      case 2: break;
      case 3: Navigator.pushReplacementNamed(context, '/mypage', arguments: uid); break;
    }
  }

  // 상단 탭 이동 (이제 Navigator가 아니라 setState입니다!)
  void _onTapTopTab(int index) {
    setState(() {
      _currentTabIndex = index;
    });
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
              const SizedBox(height: 8),
              // --- 공통 헤더 (타이틀) ---
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Round', style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),

              // --- 공통 상단 탭 ---
              _buildTopTabs(),

              // --- 탭별 내용물 (여기가 바뀝니다!) ---
              Expanded(
                // IndexedStack을 쓰면 탭 전환 시 상태(스크롤 등)가 유지됩니다.
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: _tabViews,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 2, // 커뮤니티 탭 고정
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

  // 상단 탭 위젯
  Widget _buildTopTabs() {
    final tabs = ['친선경기', '동호회', '랭킹'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == _currentTabIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _onTapTopTab(i), // setState 호출
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
}