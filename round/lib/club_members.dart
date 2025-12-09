import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';

class ClubMembersScreen extends StatefulWidget {
  final int clubId;
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
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF1F2937);

  bool _isLoading = true;
  ClubInfo? _currentClubInfo;
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchClubInfo(widget.clubId);
  }

  Future<void> _fetchClubInfo(int clubId) async {
    try {
      final response = await dio.get('/api/club-info', queryParameters: {'club_id': clubId});
      final clubData = response.data['club'];
      if (mounted) {
        setState(() {
          _currentClubInfo = ClubInfo.fromJson(clubData);
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("Error fetching club info: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
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
    if (_currentClubInfo == null) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: Text("정보를 불러올 수 없습니다.", style: TextStyle(color: Colors.white))));
    }

    final info = _currentClubInfo!;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildClubTitle(info),
            _buildClubBanner(info),
            _buildInfoPanel(info),
            // TODO: 멤버 목록 리스트 추가 (API 연동 필요)
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildClubTitle(ClubInfo info) {
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

  Widget _buildClubBanner(ClubInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: (info.bannerUrl.isNotEmpty && !info.bannerUrl.contains('placeholder'))
              ? Image.network(
                  info.bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF374151),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
    );
  }

  Widget _buildInfoPanel(ClubInfo info) {
    final winRate = info.totalMatches == 0 ? 0 : (info.wins / info.totalMatches * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          children: [
            // 상단: 로고 + 이름
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF111827),
                  backgroundImage: (info.bannerUrl.isNotEmpty && !info.bannerUrl.contains('placeholder'))
                      ? NetworkImage(info.bannerUrl)
                      : null,
                  child: (info.bannerUrl.isEmpty || info.bannerUrl.contains('placeholder'))
                      ? Text(info.name.isNotEmpty ? info.name[0] : '?', 
                             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  info.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 통계 정보 그리드
            Row(
              children: [
                Expanded(child: _buildStatItem('클럽 point', _formatNumber(info.point))),
                const SizedBox(width: 16),
                Expanded(child: _buildStatItem('총 경기 횟수', '${info.totalMatches}경기')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('전적', '${info.wins} W / ${info.losses} L\n(승률 $winRate%)')),
                const SizedBox(width: 16),
                Expanded(child: _buildStatItem('지역랭킹', info.rankText, highlight: true)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('활동지역', info.area)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatItem('멤버 수', '${info.members}명')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
}