import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:round/friendly_match_detail_screen.dart'; // 채팅방 화면 import

// 진행 중인 매칭 데이터 모델 (이 화면에서만 쓰인다면 여기에 정의)
class ActiveMatch {
  final String matchId;
  final String opponentName;
  final String? opponentImage;
  final String status;
  final String sport;
  final String location;

  ActiveMatch({
    required this.matchId,
    required this.opponentName,
    this.opponentImage,
    required this.status,
    required this.sport,
    required this.location,
  });

  factory ActiveMatch.fromJson(Map<String, dynamic> json) {
    return ActiveMatch(
      matchId: json['match_id'],
      opponentName: json['opponent_name'],
      opponentImage: json['opponent_image'],
      status: json['status'],
      sport: json['sport'],
      location: "${json['sido']} ${json['sigungu']}",
    );
  }
}

class ClubHomeScreen extends StatefulWidget {
  final int clubId;
  final String userId;

  const ClubHomeScreen({
    super.key,
    required this.clubId,
    required this.userId,
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
  ClubInfo? _clubInfo;
  List<ActiveMatch> _activeMatches = [];

  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 클럽 상세 정보 & 2. 진행 중인 매칭 목록 동시 호출
      final results = await Future.wait([
        dio.get('/api/club-info', queryParameters: {'club_id': widget.clubId}),
        dio.get('/api/my-matches'), // 내가 속한 모든 매칭을 가져옴
      ]);

      final clubData = results[0].data['club'];
      final matchData = results[1].data['matches'] as List;

      setState(() {
        _clubInfo = ClubInfo.fromJson(clubData);
        
        // 전체 매칭 중 '이 클럽'과 관련된 매칭만 필터링하거나, 
        // 서버에서 필터링해서 주지 않았다면 클라이언트에서 표시 (여기선 전체 표시)
        _activeMatches = matchData.map((m) => ActiveMatch.fromJson(m)).toList();
        
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("클럽 홈 데이터 로딩 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 숫자 포맷팅
  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildHeader(info),
            _buildBanner(info),
            _buildStatsRow(info),
            
            // --- 👇👇👇 진행 중인 매칭 (채팅방 재입장) 👇👇👇 ---
            if (_activeMatches.isNotEmpty) ...[
              _buildSectionTitle("진행 중인 경기"),
              _buildActiveMatchesList(),
            ],
            
            // 최근 경기 결과 (더미 데이터 or 추후 구현)
            _buildSectionTitle("최근 경기 결과"),
            _buildRecentMatchCard(), 
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ===== 위젯 빌더 =====

  Widget _buildHeader(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        info.name,
        style: const TextStyle(color: _lime, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildBanner(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          image: (info.bannerUrl.isNotEmpty && !info.bannerUrl.contains('placeholder'))
              ? DecorationImage(image: NetworkImage(info.bannerUrl), fit: BoxFit.cover)
              : null,
        ),
        child: (info.bannerUrl.isEmpty || info.bannerUrl.contains('placeholder'))
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 40),
                  SizedBox(height: 8),
                  Text('대표 이미지가 없습니다', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildStatsRow(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem("포인트", _formatNumber(info.point), _lime),
            _verticalDivider(),
            _statItem("랭킹", info.rankText, Colors.white),
            _verticalDivider(),
            _statItem("전적", "${info.wins}승 ${info.losses}패", Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 30, color: Colors.white12);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  // 진행 중인 매칭 리스트 (채팅방 이동 가능)
  Widget _buildActiveMatchesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeMatches.length,
      itemBuilder: (context, index) {
        final match = _activeMatches[index];
        return GestureDetector(
          onTap: () {
            // 채팅방(매칭 상세)으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FriendlyMatchDetailScreen(
                  matchId: match.matchId,
                  opponentName: match.opponentName,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF383838), // 조금 더 밝은 배경
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _lime.withOpacity(0.3)), // 강조 테두리
            ),
            child: Row(
              children: [
                // 상대방 이미지
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: (match.opponentImage != null) ? NetworkImage(match.opponentImage!) : null,
                  child: (match.opponentImage == null) ? Text(match.opponentName[0], style: const TextStyle(color: Colors.white)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("VS ${match.opponentName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text("${match.sport} · ${match.location}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lime,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("채팅하기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 최근 경기 결과 (임시 더미)
  Widget _buildRecentMatchCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 날짜
            Column(
              children: const [
                Text("9월 2일", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("12:30", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 16),
            // 스코어
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(_clubInfo!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Text("2 : 0", style: TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("상대팀", style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            // 결과 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text("승리", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}