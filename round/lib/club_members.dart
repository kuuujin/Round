import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/home_screen.dart';
import 'package:round/models/club_models.dart';

class ClubMembersScreen extends StatefulWidget {
  final int clubId; // 👈 clubId 받기
  final String userId;
  
  const ClubMembersScreen({
    super.key, 
    required this.clubId, 
    required this.userId
  });

  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  // ===== 공통 팔레트 =====
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _chipBlue = Color(0xFF60A5FA);
  static const Color _panel = Color(0xFF1F2937);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);

  bool _isLoading = true;
  ClubInfo? _currentClubInfo;
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    // 1. 전달받은 clubId로 정보 조회
    _fetchClubInfo(widget.clubId);
  }

  Future<void> _fetchClubInfo(int clubId) async {
    try {
      final response = await dio.get('/api/club-info', queryParameters: {'club_id': clubId});
      final clubData = response.data['club'];
      setState(() {
        _currentClubInfo = ClubInfo.fromJson(clubData);
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("Error fetching club info: $e");
      setState(() => _isLoading = false);
    }
  }

  // ===== 클럽명 (라임 컬러) =====
  Widget _clubTitle(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(
        info.name,
        style: const TextStyle(
          color: _lime,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ===== 배너 이미지 =====
  Widget _clubBanner(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            info.bannerUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF374151),
                alignment: Alignment.center,
                child: const Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ===== 정보 카드 =====
  Widget _infoPanel(ClubInfo info) {
    final winRate =
        info.totalMatches == 0 ? 0 : (info.wins / info.totalMatches * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 로고 + 이름
            Row(
              children: [
                Container(
                  width: 40, // 지름 (radius * 2)
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827), // 배경색
                    shape: BoxShape.circle, // 원형 모양
                    image: (info.bannerUrl.isNotEmpty && !info.bannerUrl.contains('placeholder'))
                        ? DecorationImage(
                            image: NetworkImage(info.bannerUrl), // 1. 네트워크 이미지 로드
                            fit: BoxFit.cover, // 이미지를 원에 꽉 채움
                          )
                        : null, // 이미지가 없으면 null (배경색만 보임)
                  ),
                  // 이미지가 없을 때만 글자 표시
                  child: (info.bannerUrl.isEmpty || info.bannerUrl.contains('via.placeholder.com'))
                      ? Center(
                          child: Text(
                            info.name.characters.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  info.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 첫 줄: 클럽 point / 총 경기 횟수
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '클럽 point',
                    value: _formatNumber(info.point),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '총 경기 횟수',
                    value: '${info.totalMatches}경기',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 두 번째 줄: 전적 / 지역랭킹
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '전적',
                    value:
                        '${info.wins} W / ${info.losses} L\n(승률 $winRate%)',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '지역랭킹',
                    value: info.rankText,
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 세 번째 줄: 활동지역 / 멤버 수
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    label: '활동지역',
                    value: info.area,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statBlock(
                    label: '멤버 수',
                    value: '${info.members}명',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: highlight ? _lime : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _lime)),
      );
    }
    if (_currentClubInfo == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text("정보를 불러올 수 없습니다.", style: TextStyle(color: Colors.white))),
      );
    }

    final info = _currentClubInfo!;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드롭다운 제거됨
            const SizedBox(height: 20),
            _clubTitle(info),
            _clubBanner(info),
            _infoPanel(info),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    buffer.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
  }
