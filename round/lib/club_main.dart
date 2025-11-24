import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round/models/club_models.dart';
import 'club_board.dart';
import 'club_members.dart';
import 'club_schedule.dart';
import 'club_home.dart';

class ClubMainScreen extends StatefulWidget {
  final MyClub club; // 선택된 동호회 정보 (ID, 이름)
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
  int _currentIndex = 0;
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 각 페이지에 clubId를 주입하여 생성
    _pages = [
      ClubHomeScreen(clubId: widget.club.id, userId: widget.userId),
      
      // 1: 일정
      ClubScheduleScreen(clubId: widget.club.id, userId: widget.userId),

      // 2: 게시판
      ClubBoardScreen(clubId: widget.club.id, userId: widget.userId),

      // 3: 클럽 정보
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.club.name, // 상단에 동호회 이름 표시
            style: const TextStyle(color: _lime, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        // IndexedStack을 사용하면 탭 전환 시 상태(스크롤 위치 등)가 유지됩니다.
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          currentIndex: _currentIndex,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: true,
          showUnselectedLabels: true,
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