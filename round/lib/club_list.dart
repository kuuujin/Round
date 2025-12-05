import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:round/club_main.dart';

class ClubListScreen extends StatefulWidget {
  final String userId;
  const ClubListScreen({super.key, required this.userId});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  // 팔레트 (다른 화면과 통일)
  static const Color _bg = Color(0xFF262626);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);


  List<MyClub> _myClubs = [];
  bool _isLoading = true;
  final Dio dio = ApiClient().dio;

  // 현재 탭 인덱스 (Club 탭은 1번)
  final int _currentIndex = 1; 

  @override
  void initState() {
    super.initState();
    _fetchMyClubs();
  }

  Future<void> _fetchMyClubs() async {
    try {
      final response = await dio.get('/api/my-clubs');
      final List<dynamic> data = response.data['clubs'];
      setState(() {
        _myClubs = data.map((e) => MyClub.fromJson(e)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("내 동호회 불러오기 실패: $e");
      setState(() => _isLoading = false);
    }
  }


  void _onTapBottom(int index) {
    if (index == _currentIndex) return;
    final uid = widget.userId;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: uid);
        break;
      case 1:
        // 현재 화면이므로 아무것도 안 함 (또는 새로고침)
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
    return Scaffold(
      backgroundColor: _bg, // 배경색 통일
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('내 동호회 목록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // 👈 하단 탭이 있으므로 뒤로가기 버튼 숨김
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB7F34D)))
          : _myClubs.isEmpty
              ? const Center(child: Text("가입된 동호회가 없습니다.", style: TextStyle(color: Colors.white54)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myClubs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final club = _myClubs[i];
                    return ListTile(
                      tileColor: const Color(0xFF2F2F2F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClubMainScreen(
                              club: club,
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _bg,
        currentIndex: _currentIndex,
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
    );
  }
}