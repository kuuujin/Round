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
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  // 상단 탭 (0: 친선경기, 1: 동호회, 2: 랭킹) - 기본값 동호회
  int _currentTabIndex = 1;
  late List<Widget> _tabViews;

  @override
  void initState() {
    super.initState();
    _tabViews = [
      CommunityFriendlyTab(userId: widget.userId),
      CommunityClubTab(userId: widget.userId),
      CommunityRankingTab(userId: widget.userId),
    ];
  }

  // 하단 탭 이동 (메인 네비게이션)
  void _onTapBottom(int index) {
    if (index == 2) return; // 현재 탭
    final uid = widget.userId;
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/home', arguments: uid); break;
      case 1: Navigator.pushReplacementNamed(context, '/club', arguments: uid); break;
      case 3: Navigator.pushReplacementNamed(context, '/mypage', arguments: uid); break;
    }
  }

  // 상단 탭 이동 (페이지 전환)
  void _onTapTopTab(int index) {
    setState(() {
      _currentTabIndex = index;
    });
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // 헤더
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Round', style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),

              // 상단 탭 바
              _buildTopTabs(),

              // 탭별 콘텐츠 (IndexedStack으로 상태 유지)
              Expanded(
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: _tabViews,
                ),
              ),
            ],
          ),
        ),
        
        // 하단 네비게이션 바
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 2, // Community 탭 고정
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTapBottom,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Club'),
            BottomNavigationBarItem(icon: Icon(Icons.groups_2), label: 'Community'), // 활성 아이콘
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'My'),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    final tabs = ['친선경기', '동호회', '랭킹'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(3, (i) {
          final isSelected = i == _currentTabIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _onTapTopTab(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 선택된 탭 하단 인디케이터
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2, 
                      width: isSelected ? 40 : 0,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
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