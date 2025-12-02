import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart'; // MyClub 등 모델 사용
import 'package:round/club_main.dart'; // 상세 화면 이동용

// 목록용 모델 (RecommendedClub 모델 재사용 또는 새로 정의)
class CommunityClub {
  final int id;
  final String name;
  final String description;
  final String tags;
  final String? imageUrl;
  final int memberCount;
  final int maxCapacity;

  CommunityClub({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    this.imageUrl,
    required this.memberCount,
    required this.maxCapacity,
  });

  factory CommunityClub.fromJson(Map<String, dynamic> json) {
    return CommunityClub(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      tags: "${json['sido']} ${json['sigungu']}",
      imageUrl: json['club_image_url'],
      memberCount: json['member_count'],
      maxCapacity: json['max_capacity'],
    );
  }
}

class CommunityClubTab extends StatefulWidget {
  final String userId;
  const CommunityClubTab({super.key, required this.userId});

  @override
  State<CommunityClubTab> createState() => _CommunityClubTabState();
}

class _CommunityClubTabState extends State<CommunityClubTab> {
  static const Color _chipSel = Color(0xFF60A5FA);
  static const Color _chipUnsel = Color(0xFF2F2F2F);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _lime = Color(0xFFB7F34D);

  final Dio dio = ApiClient().dio;
  final TextEditingController _searchController = TextEditingController();

  // 상태 변수
  bool _isLoading = true;
  String _userSido = ''; // 사용자의 시/도
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

  // 1. 초기화: 사용자 지역 가져오기 -> 목록 가져오기
  Future<void> _initializeData() async {
    try {
      // 사용자 위치 정보 가져오기
      final response = await dio.get('/api/user-locations');
      final locations = response.data['locations'];
      
      if (mounted) {
        setState(() {
          // 주 활동지역의 '시/도'만 저장 (없으면 기본값)
          _userSido = locations['primary_sido'] ?? '서울특별시';
        });
        _fetchClubs(); // 목록 로딩 시작
      }
    } catch (e) {
      print("위치 정보 로드 실패: $e");
      // 실패 시 기본값으로라도 로딩 시도
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
        'sido': _userSido,            // 👈 핵심: 시/도 만 보냄
        'sport': _selectedCategory,
        'keyword': _searchKeyword,
      });

      final List<dynamic> data = response.data['clubs'];
      setState(() {
        _clubList = data.map((e) => CommunityClub.fromJson(e)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("동호회 목록 로드 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryGrid(),
        _buildClubListArea(),
      ],
    );
  }

  // 검색창
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 40,
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
                // 검색어 입력 완료 시(엔터) 검색 실행
                onSubmitted: (value) {
                  setState(() => _searchKeyword = value);
                  _fetchClubs();
                },
              ),
            ),
            // 검색어 초기화 버튼
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

  // 카테고리 그리드
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox( // GridView가 Expanded 되기 전에 높이를 제한하거나 shrinkWrap 사용
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.8,
          children: _categories.map((label) {
            final selected = _selectedCategory == label;
            return GestureDetector(
              onTap: () {
                if (_selectedCategory != label) {
                  setState(() => _selectedCategory = label);
                  _fetchClubs(); // 카테고리 변경 시 목록 새로고침
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
      ),
    );
  }

  // 동호회 목록 영역
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
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _clubList.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final club = _clubList[index];
          return _buildClubItem(club);
        },
      ),
    );
  }

  // 리스트 아이템 UI
  Widget _buildClubItem(CommunityClub club) {
    // 임시 MyClub 변환 (ClubMainScreen 이동용)
    final myClub = MyClub(id: club.id, name: club.name);

    return GestureDetector(
      onTap: () {
        // 클릭 시 상세 화면(ClubMainScreen)으로 이동
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
            // 이미지
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
                  Text(club.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(club.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(club.tags, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.person, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text("${club.memberCount}/${club.maxCapacity}", 
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
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