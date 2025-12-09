import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart'; // MyClub 모델
import 'package:round/club_main.dart'; // 상세 화면


class CommunityClubTab extends StatefulWidget {
  final String userId;
  const CommunityClubTab({super.key, required this.userId});

  @override
  State<CommunityClubTab> createState() => _CommunityClubTabState();
}

class _CommunityClubTabState extends State<CommunityClubTab> {
  // Palette
  static const Color _chipSel = Color(0xFF60A5FA);
  static const Color _chipUnsel = Color(0xFF2F2F2F);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _lime = Color(0xFFB7F34D);

  final Dio dio = ApiClient().dio;
  final TextEditingController _searchController = TextEditingController();

  // State
  bool _isLoading = true;
  String _userSido = ''; 
  String _selectedCategory = '볼링';
  String _searchKeyword = '';
  List<CommunityClub> _clubList = [];

  final List<String> _categories = const [
    '볼링','축구','풋살','농구','3x3 농구','배드민턴'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. 초기 데이터 로드 (위치 -> 목록)
  Future<void> _initializeData() async {
    try {
      final response = await dio.get('/api/user-locations');
      final locations = response.data['locations'];
      
      if (mounted) {
        setState(() {
          _userSido = locations['primary_sido'] ?? '서울특별시';
        });
        _fetchClubs();
      }
    } catch (e) {
      debugPrint("위치 정보 로드 실패: $e");
      if (mounted) {
        setState(() => _userSido = '서울특별시');
        _fetchClubs();
      }
    }
  }

  // 2. 동호회 목록 API 호출
  Future<void> _fetchClubs() async {
    if (_userSido.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/clubs/list', queryParameters: {
        'sido': _userSido,
        'sport': _selectedCategory,
        'keyword': _searchKeyword,
      });

      final List<dynamic> data = response.data['clubs'];
      
      if (mounted) {
        setState(() {
          _clubList = data.map((e) => CommunityClub.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("동호회 목록 로드 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 부모 배경 유지
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryGrid(),
          _buildClubListArea(),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_club_community', 
        backgroundColor: _lime,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 4,
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/createClub',
            arguments: widget.userId,
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // 1. 검색창 위젯
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF313131),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3D3D)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white60, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white60,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  hintText: '동호회 검색',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  setState(() => _searchKeyword = value);
                  _fetchClubs();
                },
              ),
            ),
            if (_searchKeyword.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchKeyword = '');
                  _fetchClubs();
                },
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              )
          ],
        ),
      ),
    );
  }

  // 2. 카테고리 선택 그리드
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
        physics: const NeverScrollableScrollPhysics(),
        children: _categories.map((label) {
          final selected = _selectedCategory == label;
          return GestureDetector(
            onTap: () {
              if (_selectedCategory != label) {
                setState(() => _selectedCategory = label);
                _fetchClubs();
              }
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _chipSel : _chipUnsel,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? const Color(0xFF60A5FA) : const Color(0xFF444444),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. 리스트 영역
  Widget _buildClubListArea() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator(color: _lime)));
    }

    if (_clubList.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text("조건에 맞는 동호회가 없습니다.", style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        color: _lime,
        backgroundColor: _panel,
        onRefresh: _fetchClubs,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _clubList.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildClubItem(_clubList[index]);
          },
        ),
      ),
    );
  }

  // 4. 개별 아이템 카드
  Widget _buildClubItem(CommunityClub club) {
    // Tags("인천광역시 미추홀구") -> Sido, Sigungu 분리
    List<String> locations = club.tags.split(' ');
    String sido = locations.isNotEmpty ? locations[0] : '';
    String sigungu = locations.length > 1 ? locations[1] : '';

    // 상세 화면 이동을 위한 모델 변환
    final myClub = MyClub(
      id: club.id, 
      name: club.name,
      description: club.description,
      clubImage: club.imageUrl ?? '',
      memberCount: club.memberCount,
      sport: _selectedCategory, // 현재 선택된 카테고리 주입
      sido: sido,
      sigungu: sigungu,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubMainScreen(club: myClub, userId: widget.userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 
            // 클럽 이미지
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (club.imageUrl != null && club.imageUrl!.isNotEmpty)
                    ? Image.network(club.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.groups, color: Colors.white24, size: 30)),
              ),
            ),
            const SizedBox(width: 16),
            
            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    club.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(club.tags, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.person, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        "${club.memberCount}/${club.maxCapacity}", 
                        style: const TextStyle(color: Colors.white38, fontSize: 12)
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}