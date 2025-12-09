import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/location_search_screen.dart';
import 'package:round/models/club_models.dart';

class CommunityRankingTab extends StatefulWidget {
  final String userId;
  const CommunityRankingTab({super.key, required this.userId});

  @override
  State<CommunityRankingTab> createState() => _CommunityRankingTabState();
}

class _CommunityRankingTabState extends State<CommunityRankingTab> {
  // Palette
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _chipSel = Color(0xFF60A5FA);
  static const Color _bg = Color(0xFF262626); // 배경색 명시

  final Dio dio = ApiClient().dio;

  // State
  String _selectedSport = '볼링';
  String _sido = '인천광역시'; 
  String _sigungu = '미추홀구';
  
  bool _isLoading = true;
  List<ClubRank> _rankingList = [];

  final List<String> _sports = const ['볼링', '축구', '풋살', '농구', '3x3 농구', '배드민턴'];

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/ranking', queryParameters: {
        'sport': _selectedSport,
        'sido': _sido,
        'sigungu': _sigungu,
      });
      final List<dynamic> data = response.data['ranking'];
      
      if (mounted) {
        setState(() {
          _rankingList = data.map((e) => ClubRank.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("랭킹 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLocation() async {
    // LocationSearchScreen이 LocationData(sido, sigungu)를 반환한다고 가정
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSearchScreen()),
    );
    
    if (result != null) {
      setState(() {
        _sido = result.sido;
        _sigungu = result.sigungu;
      });
      _fetchRanking(); 
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    // Top 3 분리 로직
    List<ClubRank> top3 = [];
    List<ClubRank> others = [];
    if (_rankingList.isNotEmpty) {
      top3 = _rankingList.take(3).toList();
      if (_rankingList.length > 3) {
        others = _rankingList.sublist(3);
      }
    }

    return Scaffold( // Scaffold 추가하여 배경색 등 제어
      backgroundColor: Colors.transparent, // 상위 탭 배경 사용
      body: RefreshIndicator(
        color: _lime,
        backgroundColor: _panel,
        onRefresh: _fetchRanking,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            // 1. 위치 선택기
            _buildLocationHeader(),
            const SizedBox(height: 16),

            // 2. 종목 선택 칩
            _buildSportChips(),
            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Rank", style: TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),

            // 3. 랭킹 리스트 영역
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _lime)))
            else if (_rankingList.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("랭킹 정보가 없습니다.", style: TextStyle(color: Colors.white38))))
            else ...[
              // Top 3 카드
              if (top3.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTop3Card(top3),
                ),
              
              const SizedBox(height: 16),
              
              // 나머지 리스트
              ...others.map((club) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRankItem(club),
              )),
              
              const SizedBox(height: 80), 
            ],
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildLocationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _pickLocation,
        child: Row(
          mainAxisSize: MainAxisSize.min, // 터치 영역 최적화
          children: [
            Text("$_sido $_sigungu", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSportChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _sports.length,
        separatorBuilder: (c, i) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final sport = _sports[index];
          final isSelected = _selectedSport == sport;
          return GestureDetector(
            onTap: () {
              if (_selectedSport != sport) {
                setState(() => _selectedSport = sport);
                _fetchRanking();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _chipSel : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _chipSel : Colors.white54),
              ),
              child: Text(
                sport, 
                style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTop3Card(List<ClubRank> top3) {
    // 2등, 1등, 3등 순서로 배치
    List<ClubRank?> podium = [
      top3.length > 1 ? top3[1] : null, 
      top3[0],                               
      top3.length > 2 ? top3[2] : null, 
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end, // 바닥 정렬
        children: [
          if (podium[0] != null) _buildPodiumItem(podium[0]!, 2),
          _buildPodiumItem(podium[1]!, 1),
          if (podium[2] != null) _buildPodiumItem(podium[2]!, 3),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(ClubRank club, int rank) {
    final double size = rank == 1 ? 80 : 60;
    final Color crownColor = rank == 1 ? Colors.amber : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    
    return Column(
      children: [
        Icon(Icons.emoji_events, color: crownColor, size: 30),
        const SizedBox(height: 4),
        _buildClubAvatar(club.imageUrl, club.name, size, crownColor),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            club.name, 
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
        ),
        Text(_formatNumber(club.point), style: const TextStyle(color: _lime, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRankItem(ClubRank club) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "${club.ranking}", 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
          _buildClubAvatar(club.imageUrl, club.name, 40, null),
          const SizedBox(width: 12),
          Expanded(
            child: Text(club.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          Text(
            _formatNumber(club.point), 
            style: const TextStyle(color: _lime, fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  //  - 공통 아바타 위젯
  Widget _buildClubAvatar(String? imageUrl, String name, double size, Color? borderColor) {
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty && !imageUrl.contains('placeholder');
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
        color: Colors.grey[800],
        image: hasImage ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
      ),
      child: !hasImage
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0] : "?", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4)
              ),
            )
          : null,
    );
  }
}