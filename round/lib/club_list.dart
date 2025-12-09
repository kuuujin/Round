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
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);
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
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/my-clubs');
      final List<dynamic> data = response.data['clubs'];
      
      if (mounted) {
        setState(() {
          _myClubs = data.map((e) => MyClub.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("내 동호회 불러오기 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTapBottom(int index) {
    if (index == _currentIndex) return;
    final uid = widget.userId;
    
    // 네비게이션 로직 (메인 탭 전환)
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: uid);
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('내 동호회 목록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // 하단 탭이 있으므로 뒤로가기 숨김
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : _myClubs.isEmpty
              ? const Center(child: Text("가입된 동호회가 없습니다.", style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  color: _lime,
                  backgroundColor: _panel,
                  onRefresh: _fetchMyClubs,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myClubs.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final club = _myClubs[i];
                      return _buildClubTile(club);
                    },
                  ),
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
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Club'), // 현재 탭 활성 아이콘
          BottomNavigationBarItem(icon: Icon(Icons.groups_2_outlined), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'My'),
        ],
      ),
    );
  }

  Widget _buildClubTile(MyClub club) {
    return ListTile(
      tileColor: _panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 클럽 이미지 (없으면 기본 아이콘)
      leading: CircleAvatar(
        backgroundColor: Colors.black38,
        backgroundImage: (club.clubImage.isNotEmpty) ? NetworkImage(club.clubImage) : null,
        child: (club.clubImage.isEmpty) ? const Icon(Icons.shield, color: Colors.white54) : null,
      ),
      title: Text(
        club.name, 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
      ),
      subtitle: Text(
        "${club.sport} · ${club.sido}", 
        style: const TextStyle(color: Colors.white54, fontSize: 13)
      ),
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
        ).then((_) => _fetchMyClubs());
      },
    );
  }
}