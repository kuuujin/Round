import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyPageScreen extends StatelessWidget {
  final String userId;
  const MyPageScreen({super.key, required this.userId});

  static const Color _bg = Color(0xFF262626);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  void _onTapBottom(BuildContext context, int index) {
    if (index == 3) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: userId);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/club', arguments: userId);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/community', arguments: userId);
        break;
      case 3:
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
          child: Center(
            child: Text(
              '마이페이지 (준비중)\nUser: $userId',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: 3,
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
