import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/location_search_screen.dart'; // Ensure this import is correct
import 'package:round/models/club_models.dart'; // Ensure ClubRank is here

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
      setState(() {
        _rankingList = data.map((e) => ClubRank.fromJson(e)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("랭킹 로딩 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationData>(
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
    // Separate Top 3 and Others
    List<ClubRank> top3 = [];
    List<ClubRank> others = [];
    if (_rankingList.isNotEmpty) {
      top3 = _rankingList.take(3).toList();
      if (_rankingList.length > 3) {
        others = _rankingList.sublist(3);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Location Selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: _pickLocation,
            child: Row(
              children: [
                Text("$_sido $_sigungu", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        // Sport Chips
        SizedBox(
          height: 40,
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
                  setState(() => _selectedSport = sport);
                  _fetchRanking(); 
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? _chipSel : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? _chipSel : Colors.white),
                  ),
                  child: Text(sport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("Rank", style: TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),

        // Ranking List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _lime))
              : _rankingList.isEmpty
                  ? const Center(child: Text("랭킹 정보가 없습니다.", style: TextStyle(color: Colors.white38)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      children: [
                        if (top3.isNotEmpty) _buildTop3Card(top3),
                        
                        const SizedBox(height: 16),
                        
                        ...others.map((club) => _buildRankItem(club)),
                        
                        const SizedBox(height: 80), 
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildTop3Card(List<ClubRank> top3) {
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
        crossAxisAlignment: CrossAxisAlignment.end,
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
    final Color crownColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown);
    
    return Column(
      children: [
        Icon(Icons.emoji_events, color: crownColor, size: 30),
        const SizedBox(height: 4),
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: crownColor, width: 2),
            color: Colors.grey[800],
            image: (club.imageUrl.isNotEmpty && !club.imageUrl.contains('placeholder'))
                ? DecorationImage(image: NetworkImage(club.imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: (club.imageUrl.isEmpty || club.imageUrl.contains('placeholder'))
              ? Center(child: Text(club.name.isNotEmpty ? club.name[0] : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              : null,
        ),
        const SizedBox(height: 8),
        Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            child: Text("${club.ranking}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              image: (club.imageUrl.isNotEmpty && !club.imageUrl.contains('placeholder'))
                  ? DecorationImage(image: NetworkImage(club.imageUrl), fit: BoxFit.cover)
                  : null,
            ),
             child: (club.imageUrl.isEmpty || club.imageUrl.contains('placeholder'))
              ? Center(child: Text(club.name.isNotEmpty ? club.name[0] : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(club.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          Text(_formatNumber(club.point), style: const TextStyle(color: _lime, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}