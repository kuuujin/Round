import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:round/friendly_match_detail_screen.dart';
import 'package:round/club_requests.dart'; // 가입 관리 화면

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

  bool _isLoading = true;
  String _myRole = "NONE";
  List<ActiveMatch> _activeMatches = [];
  List<RecentMatch> _recentMatches = [];
  ClubInfo? _clubInfo;

  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // 데이터 통합 로딩 (클럽 정보, 진행 중인 매칭, 최근 전적)
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        dio.get('/api/club-info', queryParameters: {'club_id': widget.clubId}),
        dio.get('/api/my-matches'),
        dio.get('/api/club/${widget.clubId}/matches/finished'),
      ]);

      final clubData = results[0].data['club'];
      final activeMatchData = results[1].data['matches'] as List;
      final recentMatchData = results[2].data['matches'] as List;

      if (mounted) {
        setState(() {
          _clubInfo = ClubInfo.fromJson(clubData);
          _myRole = clubData['my_role'] ?? "NONE";
          
          // 진행 중인 매칭 필터링: 매칭 ID에 클럽 ID가 포함된 경우
          // (주의: UUID 방식이면 서버에서 필터링해서 내려주는 게 더 안전하지만, 여기선 클라이언트 필터링 유지)
          _activeMatches = activeMatchData
              .map((m) => ActiveMatch.fromJson(m))
              // .where((m) => m.matchId.contains(widget.clubId.toString())) // 필요 시 활성화
              .toList();

          _recentMatches = recentMatchData.map((m) => RecentMatch.fromJson(m)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("클럽 홈 데이터 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 가입 신청 요청
  Future<void> _requestJoin() async {
    try {
      await dio.post('/api/club/join', data: {'club_id': widget.clubId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("가입 신청을 보냈습니다.")));
        _fetchAllData(); // 상태 갱신
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("오류가 발생했습니다.")));
      }
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
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
            
            // 1. 진행 중인 경기 (있을 때만 표시)
            if (_activeMatches.isNotEmpty) ...[
              _buildSectionTitle("진행 중인 경기"),
              _buildActiveMatchesList(),
            ],
            
            // 2. 최근 경기 결과
            _buildSectionTitle("최근 경기 결과"),
            _buildRecentMatchCard(),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildHeader(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              info.name,
              style: const TextStyle(color: _lime, fontSize: 24, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 내 권한(Role)에 따른 버튼 표시
          if (_myRole == "NONE")
            ElevatedButton(
              onPressed: _requestJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime, 
                foregroundColor: Colors.black, 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              ),
              child: const Text("가입 신청", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else if (_myRole == "PENDING")
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
              child: const Text("신청 대기중", style: TextStyle(color: Colors.grey)),
            )
          else if (_myRole == "ADMIN" || _myRole == "admin")
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => ClubRequestsScreen(clubId: widget.clubId))
                );
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text("관리"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
            ),
        ],
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
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _lime.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: (match.opponentImage != null) ? NetworkImage(match.opponentImage!) : null,
                  child: (match.opponentImage == null) 
                      ? Text(match.opponentName.isNotEmpty ? match.opponentName[0] : '?', style: const TextStyle(color: Colors.white)) 
                      : null,
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

  Widget _buildRecentMatchCard() {
    if (_recentMatches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text("최근 경기 기록이 없습니다.", style: TextStyle(color: Colors.white38)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentMatches.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final match = _recentMatches[index];
        
        String resultText;
        Color resultColor;
        Color resultBg;

        if (match.myScore > match.opScore) {
          resultText = "승리";
          resultColor = const Color(0xFF38BDF8);
          resultBg = const Color(0xFF38BDF8).withOpacity(0.2);
        } else if (match.myScore < match.opScore) {
          resultText = "패배";
          resultColor = const Color(0xFFFF5A3C);
          resultBg = const Color(0xFFFF5A3C).withOpacity(0.2);
        } else {
          resultText = "무승부";
          resultColor = Colors.grey;
          resultBg = Colors.grey.withOpacity(0.2);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  Text(match.matchDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(match.matchTime, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Text(_clubInfo!.name, 
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("${match.myScore} : ${match.opScore}", 
                          style: TextStyle(color: _lime, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    
                    Expanded(
                      child: Text(match.opponentName, 
                          textAlign: TextAlign.left,
                          style: const TextStyle(color: Colors.white54, fontSize: 13))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                child: Text(resultText, style: TextStyle(color: resultColor, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }
}