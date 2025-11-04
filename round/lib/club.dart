import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubScreen extends StatelessWidget {
  final String userId;
  const ClubScreen({super.key, required this.userId});

  static const _bg = Color(0xFF262626);
  static const _lime = Color(0xFFB7F34D);
  static const _iconActive = Colors.white;
  static const _iconInactive = Color(0xFF9CA3AF);

  void _goTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/club', arguments: userId);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/clubSchedule', arguments: userId);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/clubBoard', arguments: userId);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/clubMembers', arguments: userId);
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Round',
                style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _tabs(context, 0),
              const Expanded(
                child: Center(
                  child: Text('클럽 홈 화면', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
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
