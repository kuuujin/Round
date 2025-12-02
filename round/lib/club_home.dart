import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart'; // 모델 import

class ClubHomeScreen extends StatefulWidget {
  final int clubId; // 👈 부모(ClubMainScreen)로부터 받음
  final String userId;

  const ClubHomeScreen({
    super.key, 
    required this.clubId, 
    required this.userId
  });

  @override
  State<ClubHomeScreen> createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _chipBlue = Color(0xFF60A5FA);
  static const Color _matchChip = Color(0xFFFF5A3C);

  bool _isLoading = true;
  ClubInfo? _clubInfo; // 동호회 상세 정보
  // List<Match> _recentMatches = []; // TODO: 최근 경기 결과 데이터 (추후 구현)

  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchClubData();
  }

  // 데이터 로딩
  Future<void> _fetchClubData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 클럽 상세 정보 가져오기
      final response = await dio.get('/api/club-info', queryParameters: {'club_id': widget.clubId});
      final clubData = response.data['club'];
      
      // 2. (추후) 최근 경기 결과 가져오기
      // final matchesResponse = await dio.get('/api/matches/recent', ...);

      setState(() {
        _clubInfo = ClubInfo.fromJson(clubData);
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("클럽 홈 데이터 로딩 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _lime)));
    }
    if (_clubInfo == null) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: Text("정보를 불러올 수 없습니다.", style: TextStyle(color: Colors.white))));
    }

    final info = _clubInfo!;

    return Scaffold(
      backgroundColor: _bg,
      // AppBar, BottomNav 없음
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _clubSelector 제거됨 (상단 AppBar Title로 대체)
            
            _clubTitle(info),
            _banner(info),
            _pointRow(info),
            _hashtagBlock(info), // TODO: 해시태그 데이터가 있다면 연동
            _sectionTitle(),
            _matchCard(), // TODO: 실제 데이터 연동 필요
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ===== UI Widgets =====

  Widget _clubTitle(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Text(
        info.name,
        style: const TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _banner(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          image: (info.bannerUrl.isNotEmpty)
              ? DecorationImage(image: NetworkImage(info.bannerUrl), fit: BoxFit.cover)
              : null,
        ),
        child: (info.bannerUrl.isEmpty)
            ? const Center(child: Text('대표 이미지 없음', style: TextStyle(color: Colors.white38, fontSize: 13)))
            : null,
      ),
    );
  }

  Widget _pointRow(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          const Text('클럽 point', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatNumber(info.point), // _formatNumber 함수 필요 (아래에 추가)
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _lime, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashtagBlock(ClubInfo info) {
    // TODO: 실제 해시태그 데이터가 있다면 연동
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#주말클럽', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('에버 220 이상만 가입 신청', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text('최근 경기 결과', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }

  // TODO: 실제 매치 데이터 연동 필요
  Widget _matchCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _matchChip, borderRadius: BorderRadius.circular(6)),
              child: const Text('동호회 매치', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Column(
                    children: const [
                      Text('9월 2일', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      SizedBox(height: 6),
                      Text('오후', style: TextStyle(color: Colors.white, fontSize: 12)),
                      SizedBox(height: 6),
                      Text('12 : 30', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _teamColumn("우리팀", Colors.orange),
                          const Padding(padding: EdgeInsets.only(top: 18), child: Text('VS', style: TextStyle(color: _lime, fontSize: 16, fontWeight: FontWeight.w700))),
                          _teamColumn("스플래쉬", Colors.cyan),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Flexible(child: Text('정석항공과학고 운동장', style: TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('2 : 0', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('승', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(height: 10),
                    Text('+1600p', style: TextStyle(color: Color(0xFFFF4D6A), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamColumn(String name, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 18, backgroundColor: color),
        const SizedBox(height: 6),
        SizedBox(width: 70, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}