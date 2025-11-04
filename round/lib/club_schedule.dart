import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubScheduleScreen extends StatelessWidget {
  final String userId;
  const ClubScheduleScreen({super.key, required this.userId});

  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  void _goTab(BuildContext context, int i) {
    if (i == 1) return; // 현재: 일정
    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/club', arguments: userId);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/clubBoard', arguments: userId);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/clubMembers', arguments: userId);
        break;
    }
  }

  void _onTapBottom(BuildContext context, int i) {
    final uid = userId;
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

  Widget _tabs(BuildContext context, int selected) {
    final tabs = ['홈', '일정', '게시판', '클럽원'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(4, (i) {
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
            children: [
              const SizedBox(height: 8),
              const Text(
                'Round',
                style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _tabs(context, 1),
              const Expanded(
                child: Center(
                  child: Text('클럽 일정 화면', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
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
