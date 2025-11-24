import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round/club_main.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';



class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 팔레트 (기존과 동일)
  static const Color _bg = Color(0xFF262626);
  static const Color _textLime = Color(0xFFB7F34D);
  static const Color _iconActive = Colors.white;
  static const Color _iconInactive = Color(0xFF9CA3AF);
  static const Color _chipSel = Color(0xFF3B82F6);
  static const Color _chipUnsel = Color(0xFF2F2F2F);
  static const Color _fabBg = Color(0xFFA3E635);
  static const Color _fabFg = Color(0xFF1F2937);

  // --- 상태 변수 ---
  final int _currentIndex = 0;
  bool _isLoading = true; // 1. 로딩 상태 추가
  bool _isNearbyLoading = false;
  bool _userIsInClubs = false; // 2. 동호회 가입 여부 상태
  int? _selectedClubId; // 3. 선택된 동호회 탭 인덱스
  int _selectedDateIndex = 0; // 4. 선택된 날짜 인덱스


  List<MyClub> _myClubs = [];
  List<RecommendedClub> _nearbyClubs = [];
  List<Map<String, String>> _dates = [];
  Map<String, String?> _userLocations = {}; // 예: {'primary_sido': '인천광역시', ...}
  // 2. 지역 선택 드롭다운에 표시할 옵션 리스트
  List<Map<String, dynamic>> _locationOptions = [];
  // 3. 현재 드롭다운에서 선택된 값 (이 값으로 '내 주변 동호회' API를 호출)
  // key: 'label' (예: '🏠 주 활동지역'), value: {'sido': '인천광역시', 'sigungu': '미추홀구'}
  Map<String, dynamic>? _currentLocationContext;
  final Dio dio = ApiClient().dio;


  final List<String> _categories = const [
    '볼링', '축구', '풋살', '농구', '3x3 농구', '배드민턴',
  ];
  String _selectedCategory = '볼링';


  @override
  void initState() {
    super.initState();
    _generateWeekData();
    _fetchData(); // 5. 화면 시작 시 데이터 가져오기
  }

  void _generateWeekData() {
    final List<Map<String, String>> newDates = [];
    final today = DateTime.now();

    // 1. 오늘이 속한 주의 월요일을 찾습니다.
    // (DateTime.weekday는 월요일=1, 일요일=7 입니다.)
    final int daysToSubtract = today.weekday - 1; // 월요일(1)이면 0, 일요일(7)이면 6
    final DateTime monday = today.subtract(Duration(days: daysToSubtract));

    // 2. 한국어 요일 맵
    const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    // 3. 월요일부터 7일간(일요일까지) 반복
    for (int i = 0; i < 7; i++) {
      final DateTime currentDay = monday.add(Duration(days: i));
      newDates.add({
        'day': currentDay.day.toString(), // 날짜 (예: '15')
        'dow': weekdays[i],              // 요일 (예: '월')
      });
    }

    // 4. 상태를 업데이트하여 UI에 반영
    setState(() {
      _dates = newDates; // 새로 생성된 날짜 리스트로 교체
      // 5. 오늘 날짜의 인덱스를 계산하여 _selectedDateIndex로 설정
      // (today.weekday - 1)은 0(월) ~ 6(일)이 됩니다.
      _selectedDateIndex = today.weekday - 1;
    });
  }

 Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. (신규) 사용자 위치 정보부터 가져옵니다.
      final locationResponse = await dio.get('/api/user-locations');
      _userLocations = Map<String, String?>.from(locationResponse.data['locations']);
      
      // 2. (신규) 드롭다운 옵션 및 기본 선택값 설정
      _locationOptions = [];
      Map<String, dynamic>? defaultLocation;

      // 주 활동지역 추가
      if (_userLocations['primary_sido'] != null) {
        final location = {
          'sido': _userLocations['primary_sido'],
          'sigungu': _userLocations['primary_sigungu']
        };
        String label = '🏠 주 활동지역 (${_userLocations['primary_sido']} ${_userLocations['primary_sigungu']})';
        _locationOptions.add({'label': label, 'value': location});
        defaultLocation = _locationOptions.first; // 기본값
      }
      
      // 부 활동지역 추가 (있을 경우에만)
      if (_userLocations['secondary_sido'] != null) {
        final location = {
          'sido': _userLocations['secondary_sido'],
          'sigungu': _userLocations['secondary_sigungu']
        };
        String label = '💼 부 활동지역 (${_userLocations['secondary_sido']} ${_userLocations['secondary_sigungu']})';
        _locationOptions.add({'label': label, 'value': location});
      }
      
      setState(() {
        _currentLocationContext = defaultLocation; // 3. 현재 선택된 지역을 기본값(주 활동지역)으로 설정
      });

      // 4. (수정) 내 동호회 + 추천 동호회 동시 호출 (수정된 파라미터 사용)
      if (_currentLocationContext == null) {
        // 위치 정보가 아예 없는 예외 처리 (회원가입 시 입력을 안 한 경우)
         setState(() => _isLoading = false);
         // TODO: 사용자에게 위치 정보를 먼저 등록하라는 메시지 표시
         return;
      }
      
      await _fetchHomeData(
        category: _selectedCategory,
        location: _currentLocationContext!['value'],
      );

    } on DioException catch (e) {
      print("Error fetching initial data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHomeData({required String category, required Map<String, dynamic> location}) async {
    // _fetchData는 초기 로딩용, _isNearbyLoading은 부분 로딩용
    setState(() {
      _isLoading = true;
      _isNearbyLoading = true;
    });
    
    try {
      final responses = await Future.wait([
        dio.get('/api/my-clubs'),
        dio.get('/api/recommended-clubs',
          queryParameters: {
            'category': category,
            'sido': location['sido'],       // 👈 수정된 API 파라미터
            'sigungu': location['sigungu'] // 👈 수정된 API 파라미터
          },
        )
      ]);
      
      // ... (myClubs, nearbyClubs 파싱 로직은 동일) ...
      final myClubsResponse = responses[0];
      final List<dynamic> myClubsData = myClubsResponse.data['clubs'];
      final List<MyClub> myClubs = myClubsData.map((data) => MyClub.fromJson(data)).toList();

      final nearbyClubsResponse = responses[1];
      final List<dynamic> nearbyClubsData = nearbyClubsResponse.data['clubs'];
      final List<RecommendedClub> nearbyClubs = nearbyClubsData.map((data) => RecommendedClub.fromJson(data)).toList();

      setState(() {
        _myClubs = myClubs;
        _userIsInClubs = myClubs.isNotEmpty;
        _nearbyClubs = nearbyClubs;
        
        if (_userIsInClubs && _selectedClubId == null) { // 👈 _selectedClubId가 비어있을 때만 초기화
          _selectedClubId = myClubs.first.id;
        }
        
        _isLoading = false;
        _isNearbyLoading = false;
      });

    } on DioException catch (e) {
      print("Error fetching home data lists: $e");
      setState(() {
        _isLoading = false;
        _isNearbyLoading = false;
      });
    }
  }

  // TODO: 동호회 탭 클릭 시 일정/피드를 불러오는 함수 (추후 구현)
  // Future<void> _fetchClubData(int clubId) async { ... }

  // ... ( _onTapBottom, _generateWeekData 함수는 동일) ...

  Future<void> _fetchNearbyClubs(String category) async {
    setState(() {
      _isNearbyLoading = true; // 👈 '내 주변 동호회' 섹션만 로딩 시작
      _selectedCategory = category; // 선택된 카테고리 상태 업데이트
    });
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
      final List<RecommendedClub> nearbyClubs = nearbyClubsData.map((data) => RecommendedClub.fromJson(data)).toList();

      setState(() {
        _nearbyClubs = nearbyClubs; // 👈 목록을 새 데이터로 교체
        _isNearbyLoading = false;
      });
    } on DioException catch (e) {
      // (에러 처리)
      print("Error fetching nearby clubs: $e");
      setState(() => _isNearbyLoading = false);
    }
  }

  // --- 6. UI 빌더 함수들이 새 데이터를 사용하도록 수정 ---

  // 하단 탭 네비게이션 (기존과 동일)
  void _onTapBottom(int index) {
    if (index == _currentIndex) return;
    final uid = widget.userId;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: uid);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/club', arguments: uid);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/community', arguments: uid);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/mypage', arguments: uid);
        break;
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
          backgroundColor: _bg, // AppBar 배경색
          elevation: 0, // 그림자 제거
          automaticallyImplyLeading: false, // 뒤로가기 버튼 자동 생성 방지
          // 3. 기존 "Round" 텍스트를 title로 이동
          title: const Text(
            'Round',
            style: TextStyle(
              color: _textLime,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // 4. 로그아웃 버튼을 actions (AppBar의 오른쪽 영역)로 이동
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white70),
              onPressed: () {
                // TODO: 로그아웃 처리 (세션/토큰 삭제)
                Navigator.pushReplacementNamed(context, '/login');
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          // 5. Stack 위젯 제거
          child: SingleChildScrollView( // 6. SingleChildScrollView를 body의 메인 위젯으로
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isLoading && _locationOptions.isNotEmpty)
                Padding(
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
                      // 5. (신규) 지역 변경 시 동작
                      setState(() {
                        _currentLocationContext = newValue; // 현재 컨텍스트 변경
                      });
                      // 새 지역 기준으로 추천 동호회 목록 새로고침
                      _fetchNearbyClubs(_selectedCategory); 
                    },
                    // 드롭다운 스타일
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2F2F2F), // 어두운 패널 색
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    dropdownColor: const Color(0xFF2F2F2F),
                    iconEnabledColor: Colors.white70,
                  ),
                ),

                // 메인 콘텐츠 (로딩, 멤버 UI, 비멤버 UI)
                _buildMainContent(),

                // '내 주변 동호회' 섹션
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                  child: Text('내 지역 추천 동호회', style: TextStyle(
                      color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                _buildCategoryGrid(),

                const SizedBox(height: 24),
                _buildNearbyClubList(),

                const SizedBox(height: 100), // FAB을 위한 하단 여백
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
           type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: _iconActive,
          unselectedItemColor: _iconInactive,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTapBottom,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined), label: 'Club'),
            BottomNavigationBarItem(
                icon: Icon(Icons.groups_2_outlined), label: 'Community'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'My'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
           heroTag: 'fab_create_club',
          backgroundColor: _fabBg,
          foregroundColor: _fabFg,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // --- 8. 메인 콘텐츠 분기 위젯 ---
  Widget _buildMainContent() {
    if (_isLoading) {
      // 로딩 중일 때
      return const Center(
        heightFactor: 10, // 화면 중앙에 보이도록
        child: CircularProgressIndicator(color: _textLime),
      );
    }
    
    if (_userIsInClubs) {
      // 동호회 가입자일 때 (스크린샷 UI)
      return _buildMemberView();
    } else {
      // 동호회 비가입자일 때 (기존 UI)
      return _buildEmptyView();
    }
  }

  // --- 동호회 비가입자용 UI (기존 코드 재활용) ---
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text('✨ 함께할 동호회를 찾아보세요 ✨', style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: 동호회 둘러보기 화면으로 이동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF374151),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('동호회 둘러보기', style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // --- 9. 동호회 가입자용 UI (새로 추가) ---
  Widget _buildMemberView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // 👇👇👇 'ToggleButtons'를 'DropdownButtonFormField'로 교체 👇👇👇
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: DropdownButtonFormField<int>(
            // 1. 현재 선택된 값 (동호회 ID)
            value: _selectedClubId,
            
            // 2. 동호회 목록으로 메뉴 아이템 생성
            items: _myClubs.map((club) {
              return DropdownMenuItem<int>(
                value: club.id, // 각 아이템의 고유 ID
                child: Text(club.name), // 아이템에 표시될 이름
              );
            }).toList(),
            
            // 3. 새로운 아이템이 선택되었을 때
            onChanged: (int? newId) {
      if (newId == null) return;
      
      // 1. 선택된 클럽 객체 찾기
      final selectedClub = _myClubs.firstWhere((club) => club.id == newId);
      
      // 2. ClubMainScreen으로 이동 (Push)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubMainScreen(
            club: selectedClub, 
            userId: widget.userId
          ),
        ),
      );
      
      // 참고: 드롭다운 값은 굳이 setState로 바꿀 필요가 없을 수도 있습니다.
      // (갔다 오면 다시 원래대로 돌아와 있으므로)
    },
            
            // --- 4. 요청하신 UI 스타일 적용 ---
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF60A5FA), // 👈 요청하신 파란색 배경
              // 30의 radius를 가진 둥근 테두리
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none, // 테두리 선 없음
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            
            // --- 5. 드롭다운 세부 스타일 ---
            style: const TextStyle(
              color: Colors.white, // 👈 선택된 항목의 텍스트 색상 (흰색)
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            dropdownColor: _chipUnsel, // 👈 메뉴가 펼쳐졌을 때의 배경색
            iconEnabledColor: Colors.white, // 👈 드롭다운 화살표 아이콘 색상
          ),
        ),
        // 👆👆👆 여기까지 교체 👆👆👆
        
        // 나의 동호회 일정
        _buildScheduleSection(),

        const SizedBox(height: 28),

        // 동호회 소식
        _buildClubFeedSection(),
      ],
    );
  }

  // --- 9-1. 나의 동호회 일정 (새로 추가) ---
  Widget _buildScheduleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('나의 동호회 일정', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // 날짜 선택기
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
                        Text(date['day']!, style: TextStyle(
                            color: isSelected ? _bg : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(date['dow']!, style: TextStyle(
                            color: isSelected ? _bg : Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 일정 카드 (스크린샷 기반 하드코딩)
          // TODO: 이 부분을 _schedule 리스트 기반으로 ListView.builder로 변경
          _buildScheduleCard(),
        ],
      ),
    );
  }

  Widget _buildNearbyClubList() {
    // TODO: 로딩 상태, 데이터가 없을 때의 UI 추가
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _nearbyClubs.length,
        shrinkWrap: true, // SingleChildScrollView 안에서 사용
        physics: const NeverScrollableScrollPhysics(), // SingleChildScrollView와 스크롤 충돌 방지
        itemBuilder: (context, index) {
          final club = _nearbyClubs[index];
          return _buildNearbyClubItem(
            name: club.name,
            desc: club.description,
            tags: club.tags,
            imageUrl: club.imageUrl,
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('9월 15일 오후 12:30', style: TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: Colors.orange), // TODO: 이미지
                  SizedBox(width: 8),
                  Text('익스플로전', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const Text('VS', style: TextStyle(color: _textLime, fontSize: 16)),
              const Row(
                children: [
                  Text('스플래쉬', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  CircleAvatar(radius: 18, backgroundColor: Colors.cyan), // TODO: 이미지
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text('정석항공과학고등학교 운동장', style: TextStyle(
                      color: Colors.white70, fontSize: 13)),
                ],
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B5563),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
                child: const Text('참가 신청', style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // --- 9-2. 동호회 소식 (새로 추가) ---
  Widget _buildClubFeedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('동호회 소식', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // 소식 카드 (스크린샷 기반 하드코딩)
          // TODO: 이 부분을 _feed 리스트 기반으로 ListView.builder로 변경
          _buildFeedPostCard(),
        ],
      ),
    );
  }

  Widget _buildFeedPostCard() {
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Colors.purple), // TODO: 유저 이미지
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('홍길동', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
                Text('9월 9일 오후 11:43', style: TextStyle(
                    color: Colors.white70, fontSize: 12)),
              ],
            ),
            const Spacer(),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('안녕하세요\n이름: 홍길동\n나이: 23....', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.favorite_border, color: Colors.white70, size: 20),
            const SizedBox(width: 4),
            const Text('좋아요 1', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 16),
            const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
            const SizedBox(width: 4),
            const Text('댓글 2', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        const Divider(color: Color(0xFF444444), height: 32),
      ],
    );
  }

  // --- 공통 UI: 내 지역 추천 동호회 ---
  Widget _buildCategoryGrid() {
    // (기존 코드와 동일)
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
                          onTap: () {
              _fetchNearbyClubs(label); // 👈 setState 대신 이 함수를 호출
            },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? _chipSel : _chipUnsel,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF444444),
                                width: 1,
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



  Widget _buildNearbyClubItem({
    required String name,
    required String desc,
    required String tags,
    String? imageUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF2F2F2F),
              borderRadius: BorderRadius.circular(12),
            ),
            // ClipRRect로 이미지를 둥글게 처리
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.grey))
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(tags, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}