import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:round/club_main.dart'; // 상세 화면 이동용

class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);
  static const Color _chipSel = Color(0xFF3B82F6);
  static const Color _chipUnsel = Color(0xFF2F2F2F);

  // State
  final int _currentIndex = 0;
  bool _isLoading = true;
  bool _isClubDataLoading = false;
  bool _userIsInClubs = false;
  bool _isNearbyLoading = false;
  int? _selectedClubId;
  int _selectedDateIndex = 0;

  List<MyClub> _myClubs = [];
  List<RecommendedClub> _nearbyClubs = [];
  List<Map<String, String>> _dates = [];
  List<Schedule> _schedules = []; 
  List<Post> _posts = [];
  
  // Location Dropdown
  List<Map<String, dynamic>> _locationOptions = [];
  Map<String, dynamic>? _currentLocationContext;
  
  final Dio dio = ApiClient().dio;
  
  final List<String> _categories = const ['볼링', '축구', '풋살', '농구', '3x3 농구', '배드민턴'];
  String _selectedCategory = '볼링';

  @override
  void initState() {
    super.initState();
    _generateWeekData();
    _fetchData();
    _updateFCMToken();
  }

  void _generateWeekData() {
    final List<Map<String, String>> newDates = [];
    final today = DateTime.now();
    final int daysToSubtract = today.weekday - 1;
    final DateTime monday = today.subtract(Duration(days: daysToSubtract));
    const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    for (int i = 0; i < 7; i++) {
      final DateTime currentDay = monday.add(Duration(days: i));
      newDates.add({
        'day': currentDay.day.toString(),
        'dow': weekdays[i],
      });
    }

    setState(() {
      _dates = newDates;
      _selectedDateIndex = today.weekday - 1;
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 사용자 위치 정보 로드
      final locationResponse = await dio.get('/api/user-locations');
      final userLocations = Map<String, String?>.from(locationResponse.data['locations']);
      
      _locationOptions = [];
      Map<String, dynamic>? defaultLocation;

      if (userLocations['primary_sido'] != null) {
        final sido = userLocations['primary_sido'];
        final sigungu = userLocations['primary_sigungu'] ?? '';
        
        final location = {'sido': sido, 'sigungu': sigungu};
        
        final label = '🏠 주 활동지역 ($sido $sigungu)'; 
        
        _locationOptions.add({'label': label, 'value': location});
        defaultLocation = _locationOptions.first;
      }
      
      // 2. 부 활동지역 추가 로직 수정
      if (userLocations['secondary_sido'] != null) {
        final sido = userLocations['secondary_sido'];
        final sigungu = userLocations['secondary_sigungu'] ?? '';
        
        final location = {'sido': sido, 'sigungu': sigungu};
        
        final label = '💼 부 활동지역 ($sido $sigungu)';
        
        _locationOptions.add({'label': label, 'value': location});
      }
      
      if (mounted) {
        setState(() {
          _currentLocationContext = defaultLocation;
        });
      }

      if (_currentLocationContext == null) {
         setState(() => _isLoading = false);
         return;
      }
      
      await _fetchHomeData(
        category: _selectedCategory,
        location: _currentLocationContext!['value'],
      );

    } on DioException catch (e) {
      debugPrint("Error fetching initial data: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHomeData({required String category, required Map<String, dynamic> location}) async {
    setState(() => _isLoading = true);
    
    try {
      final responses = await Future.wait([
        dio.get('/api/my-clubs'),
        dio.get('/api/recommended-clubs',
          queryParameters: {
            'category': category,
            'sido': location['sido'],      
            'sigungu': location['sigungu'] 
          },
        )
      ]);
      
      final List<dynamic> myClubsData = responses[0].data['clubs'];
      final List<MyClub> myClubs = myClubsData.map((data) => MyClub.fromJson(data)).toList();

      final List<dynamic> nearbyClubsData = responses[1].data['clubs'];
      final List<RecommendedClub> nearbyClubs = nearbyClubsData.map((data) => RecommendedClub.fromJson(data)).toList();

      if (mounted) {
        setState(() {
          _myClubs = myClubs;
          _userIsInClubs = myClubs.isNotEmpty;
          _nearbyClubs = nearbyClubs;
          
          if (_userIsInClubs) {
             _selectedClubId ??= myClubs.first.id;
             _fetchClubData(_selectedClubId!); 
          }
          _isLoading = false;
        });
      }

    } on DioException catch (e) {
      debugPrint("Error fetching home data: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchClubData(int clubId) async {
    setState(() => _isClubDataLoading = true);
    try {
      final responses = await Future.wait([
        dio.get('/api/club/$clubId/schedules'),
        dio.get('/api/club/$clubId/posts'),
      ]);

      final scheduleList = responses[0].data['schedules'] as List;
      final postList = responses[1].data['posts'] as List;

      if (mounted) {
        setState(() {
          _schedules = scheduleList.map((j) => Schedule.fromJson(j)).toList();
          _posts = postList.map((j) => Post.fromJson(j)).toList();
          _isClubDataLoading = false;
        });
      }
      
    } catch (e) {
      debugPrint("Club Data Fetch Error: $e");
      if (mounted) setState(() => _isClubDataLoading = false);
    }
  }

  Future<void> _fetchNearbyClubs(String category) async {
    setState(() => _selectedCategory = category);
    final location = _currentLocationContext!['value'];
    
    try {
      final response = await dio.get(
        '/api/recommended-clubs',
        queryParameters: {
          'category': category,
          'sido': location['sido'],
          'sigungu': location['sigungu']
        },
      );
      final List<dynamic> nearbyClubsData = response.data['clubs'];
      
      if (mounted) {
        setState(() {
          _nearbyClubs = nearbyClubsData.map((data) => RecommendedClub.fromJson(data)).toList(); 
        });
      }
    } catch (e) {
      debugPrint("Error fetching nearby clubs: $e");
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await dio.post('/api/update-fcm-token', data: {'fcm_token': token});
      }
    } catch (e) {
      debugPrint("FCM Token Update Failed: $e");
    }
  }

  void _onTapBottom(int index) {
    if (index == _currentIndex) return;
    final uid = widget.userId;
    switch (index) {
      case 1: Navigator.pushReplacementNamed(context, '/club', arguments: uid); break;
      case 2: Navigator.pushReplacementNamed(context, '/community', arguments: uid); break;
      case 3: Navigator.pushReplacementNamed(context, '/mypage', arguments: uid); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Round', style: TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 위치 선택 드롭다운
                if (!_isLoading && _locationOptions.isNotEmpty)
                  _buildLocationDropdown(),

                // 2. 메인 콘텐츠 (가입 여부에 따라 분기)
                _buildMainContent(),

                // 3. 추천 동호회 섹션
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                  child: Text('내 지역 추천 동호회', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                _buildCategoryGrid(),
                const SizedBox(height: 24),
                _buildNearbyClubList(),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          currentIndex: _currentIndex,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          onTap: _onTapBottom,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''), 
            BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.groups_2_outlined), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildLocationDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: _currentLocationContext,
        items: _locationOptions.map((option) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: option,
            child: Text(option['label']!),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue == null) return;
          setState(() => _currentLocationContext = newValue);
          _fetchNearbyClubs(_selectedCategory); 
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF2F2F2F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        dropdownColor: const Color(0xFF2F2F2F),
        iconEnabledColor: Colors.white70,
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(heightFactor: 10, child: CircularProgressIndicator(color: _lime));
    }
    return _userIsInClubs ? _buildMemberView() : _buildEmptyView();
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text('✨ 함께할 동호회를 찾아보세요 ✨', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/community', arguments: widget.userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF374151),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('동호회 둘러보기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 내 클럽 선택 드롭다운
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: DropdownButtonFormField<int>(
            value: _selectedClubId,
            items: _myClubs.map((club) => DropdownMenuItem(value: club.id, child: Text(club.name))).toList(),
            onChanged: (newId) {
              if (newId == null) return;
              setState(() => _selectedClubId = newId);
              _fetchClubData(newId);
              
              // 상세 화면 이동
              final selectedClub = _myClubs.firstWhere((club) => club.id == newId);
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => ClubMainScreen(club: selectedClub, userId: widget.userId),
              ));
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF60A5FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            dropdownColor: const Color(0xFF2F2F2F),
            iconEnabledColor: Colors.white,
          ),
        ),
        
        _buildScheduleSection(),
        const SizedBox(height: 28),
        _buildClubFeedSection(),
      ],
    );
  }

  Widget _buildScheduleSection() {
    if (_isClubDataLoading) return const SizedBox(); 
    if (_schedules.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("예정된 일정이 없습니다.", style: TextStyle(color: Colors.white54)),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('나의 동호회 일정', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          
          // 주간 달력 (가로 스크롤)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isSelected = _selectedDateIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDateIndex = index),
                  child: Container(
                    width: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _chipSel : const Color(0xFF2F2F2F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(date['day']!, style: TextStyle(color: isSelected ? _bg : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(date['dow']!, style: TextStyle(color: isSelected ? _bg : Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // 일정 리스트
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _schedules.length,
            itemBuilder: (context, index) => _buildScheduleCard(_schedules[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    String dateDisplay = schedule.startTime;
    try {
      DateTime dt = DateTime.parse(schedule.startTime);
      dateDisplay = DateFormat('M월 d일 a h:mm', 'ko_KR').format(dt);
    } catch(e) {
      debugPrint("Date error: $e");
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateDisplay, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          
          if (schedule.isMatch) 
            Row(
              children: [
                 const Text("우리팀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                 const SizedBox(width: 8),
                 const Text("VS", style: TextStyle(color: _lime, fontWeight: FontWeight.bold, fontSize: 14)), 
                 const SizedBox(width: 8),
                 Text(schedule.opponentName ?? "상대팀", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            )
          else
            Text(schedule.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 12),
          Row(
            children: [
               const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
               const SizedBox(width: 4),
               Expanded(child: Text(schedule.location, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildClubFeedSection() {
    if (_isClubDataLoading) return const SizedBox();
    if (_posts.isEmpty) {
       return const Padding(
         padding: EdgeInsets.all(16.0),
         child: Text("등록된 소식이 없습니다.", style: TextStyle(color: Colors.white54)),
       );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('동호회 소식', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            itemBuilder: (context, index) => _buildFeedPostCard(_posts[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPostCard(Post post) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18, 
              backgroundColor: Colors.grey[800],
              backgroundImage: post.profileImage != null ? NetworkImage(post.profileImage!) : null,
              child: post.profileImage == null ? const Icon(Icons.person, color: Colors.white70, size: 20) : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(post.time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(post.content, style: const TextStyle(color: Colors.white), maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.favorite_border, color: Colors.white70, size: 20),
            const SizedBox(width: 4),
            Text('좋아요 ${post.likes}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 16),
            const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
            const SizedBox(width: 4),
            Text('댓글 ${post.comments}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        const Divider(color: Color(0xFF444444), height: 32),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.8,
        children: _categories.map((label) {
          final bool selected = _selectedCategory == label;
          return GestureDetector(
            onTap: () => _fetchNearbyClubs(label),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _chipSel : _chipUnsel,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: selected ? const Color(0xFF60A5FA) : const Color(0xFF444444)),
              ),
              child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNearbyClubList() {
    if (_nearbyClubs.isEmpty && !_isNearbyLoading) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("추천할 동호회가 없습니다.", style: TextStyle(color: Colors.white38))));
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _nearbyClubs.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final club = _nearbyClubs[index];
          return _buildNearbyClubItem(club);
        },
      ),
    );
  }

  Widget _buildNearbyClubItem(RecommendedClub club) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: const Color(0xFF2F2F2F), borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (club.imageUrl != null && club.imageUrl!.isNotEmpty)
                  ? Image.network(club.imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.grey))
                  : const Icon(Icons.groups, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(club.description, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(club.tags, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}