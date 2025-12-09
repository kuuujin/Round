import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round/models/club_models.dart';
import 'club_board.dart';
import 'club_members.dart';
import 'club_schedule.dart';
import 'club_home.dart';

class ClubMainScreen extends StatefulWidget {
  final MyClub club; // 선택된 동호회 객체
  final String userId;

  const ClubMainScreen({
    super.key, 
    required this.club, 
    required this.userId
  });

  @override
  State<ClubMainScreen> createState() => _ClubMainScreenState();
}

class _ClubMainScreenState extends State<ClubMainScreen> {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 탭별 화면 초기화 (clubId 전달)
    _pages = [
      // 0: 홈 (전적, 배너, 매칭 등)
      ClubHomeScreen(clubId: widget.club.id, userId: widget.userId),
      
      // 1: 일정 (캘린더)
      ClubScheduleScreen(clubId: widget.club.id, userId: widget.userId),

      // 2: 게시판 (글 목록)
      ClubBoardScreen(clubId: widget.club.id, userId: widget.userId),

      // 3: 정보 (멤버 목록, 소개)
      ClubMembersScreen(clubId: widget.club.id, userId: widget.userId),
    ];
  }

  void _onTapBottom(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 UI 스타일 설정 (상단바 색상 등)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        
        // 상단 앱바 (동호회 이름)
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.club.name,
            style: const TextStyle(color: _lime, fontWeight: FontWeight.w700),
          ),
        ),

        // 본문 (IndexedStack으로 탭 상태 유지)
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),

        // 하단 탭바
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          currentIndex: _currentIndex,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: _onTapBottom,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '일정'),
            BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: '게시판'),
            BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: '정보'),
          ],
        ),
      ),
    );
  }
}