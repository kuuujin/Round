import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'chat_screen.dart';

class CommunityFriendlyTab extends StatefulWidget {
  final String userId;
  const CommunityFriendlyTab({super.key, required this.userId});

  @override
  State<CommunityFriendlyTab> createState() => _CommunityFriendlyTabState();
}

class _CommunityFriendlyTabState extends State<CommunityFriendlyTab> {
  // Palette
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _bg = Color(0xFF262626);

  final Dio dio = ApiClient().dio;
  late IO.Socket socket;

  // State variables
  bool _isLoading = true;
  bool _isSearching = false; // 매칭 중인지 여부
  int? _myClubId; // 내 동호회 ID (매칭 신청 주체)
  String? _myClubName;
  List<dynamic> _myClubsList = [];

  // Matching Preferences
  String _selectedDay = 'ANY'; 
  String _selectedTime = 'ANY';

  final Map<String, String> _dayMap = {'무관': 'ANY', '평일': 'WEEKDAY', '주말': 'WEEKEND'};
  final Map<String, String> _timeMap = {'무관': 'ANY', '오전': 'MORNING', '오후': 'AFTERNOON', '저녁': 'EVENING'};

  @override
  void initState() {
    super.initState();
    _fetchMyClubs(); // 1. 내 클럽 정보 가져오기
    _initSocket();
    _initFCM();      // 2. 소켓 초기화
  }

  @override
  void dispose() {
    socket.dispose(); // 소켓 연결 해제
    super.dispose();
  }

  Future<void> _fetchMyClubs() async {
    try {
      final response = await dio.get('/api/my-clubs');
      final List<dynamic> clubs = response.data['clubs'];
      
      setState(() {
        _myClubsList = clubs;
        if (clubs.isNotEmpty) {
          // 기본값: 첫 번째 동호회 선택
          _myClubId = clubs[0]['id'];
          _myClubName = clubs[0]['name'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print("내 동호회 로드 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. 소켓 초기화 및 이벤트 리스너 등록
  void _initSocket() {
    // 서버 주소 (https://roundserver.win)
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('✅ 소켓 서버 연결됨');
      socket.emit('join', {'user_id': widget.userId});
    });

    // 매칭 성공 이벤트 수신
    socket.on('match_found', (data) {
      print('🎉 매칭 성공: $data');
      if (!mounted) return;

      setState(() => _isSearching = false);
      
      // 매칭 성공 다이얼로그
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text("🎉 매칭 성공!", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("상대팀: ${data['opponent_name']}", style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              const Text("경기 일정 조율을 위해\n채팅방으로 이동하시겠습니까?", style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // 1. 다이얼로그 닫기
                
                // 2. 채팅 화면으로 이동
                // data['match_id']가 있는지 확인 필수
                if (data['match_id'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        matchId: data['match_id'],     // 서버에서 받은 방 ID
                        userId: widget.userId,         // 내 ID
                        opponentName: data['opponent_name'], // 상대 팀 이름
                      ),
                    ),
                  );
                } else {
                   print("오류: match_id가 없습니다.");
                }
              },
              child: const Text("이동", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });

    socket.on('match_error', (data) {
      print('❌ 매칭 에러: $data');
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류 발생: ${data['error']}")));
    });

    socket.connect();
  }

  // 3. 매칭 시작 요청
  void _startMatching() async {
    setState(() => _isLoading = true); // 잠깐 로딩만 보여줌

    try {
      final response = await dio.post('/api/match/request', data: {
        'club_id': _myClubId,
        'preferred_day': _selectedDay,
        'preferred_time': _selectedTime,
      });

      // 성공 시 알림창만 띄우고 로딩 해제 (화면 유지 or 이동 자유)
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text("매칭 대기 시작", style: TextStyle(color: _lime)),
          content: Text(response.data['message'], style: const TextStyle(color: Colors.white70)), // "대기열에 등록되었습니다..."
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("확인"),
            )
          ],
        ),
      );

    } on DioException catch (e) {
      // 에러 처리
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 4. 매칭 취소
  void _cancelMatching() {
    setState(() => _isSearching = false);
    // socket.emit('cancel_match'); // 필요하다면 서버에 취소 이벤트 전송
    socket.disconnect();
    socket.connect(); // 재연결하여 상태 초기화
  }

  void _initFCM() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // 앱이 켜져 있을 때 푸시 알림이 오면 실행됨
      print('FCM 메시지 수신: ${message.notification?.title}');
      
      // 💡 중요: 소켓이 연결되어 있다면 소켓 이벤트(match_found)가 이미 UI를 처리했을 것입니다.
      // 따라서 여기서는 아무것도 안 하거나, 소켓 연결이 끊긴 특수 상황에만 스낵바를 띄울 수 있습니다.
      if (!socket.connected) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${message.notification?.title}: ${message.notification?.body}"))
         );
         _isSearching = false; // 검색 중 상태 해제
         setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _lime));
    }

    // 가입된 동호회가 없을 때
    if (_myClubId == null) {
      return const Center(
        child: Text("동호회에 먼저 가입해주세요.", style: TextStyle(color: Colors.white54)),
      );
    }

    // 매칭 중 화면 (레이더 애니메이션 대용)
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 100, height: 100,
              child: CircularProgressIndicator(color: _lime, strokeWidth: 6),
            ),
            const SizedBox(height: 40),
            const Text("비슷한 실력의 상대를\n찾고 있습니다...", 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            Text("내 팀: $_myClubName", style: const TextStyle(color: _lime, fontSize: 16)),
            const SizedBox(height: 8),
            Text("조건: ${_getKeyByValue(_dayMap, _selectedDay)} / ${_getKeyByValue(_timeMap, _selectedTime)}", 
              style: const TextStyle(color: Colors.white54)
            ),
            const SizedBox(height: 60),
            OutlinedButton(
              onPressed: _cancelMatching,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("취소", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }

    // 기본 화면 (조건 선택)
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text("매칭 조건을 선택하세요", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            _buildSectionTitle("참가 팀 선택"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _myClubId,
                  isExpanded: true,
                  dropdownColor: _panel,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  onChanged: (int? newValue) {
                    if (newValue == null) return;
                    setState(() {
                      _myClubId = newValue;
                      // ID로 이름 찾기
                      final selectedClub = _myClubsList.firstWhere((club) => club['id'] == newValue);
                      _myClubName = selectedClub['name'];
                    });
                  },
                  items: _myClubsList.map<DropdownMenuItem<int>>((dynamic club) {
                    return DropdownMenuItem<int>(
                      value: club['id'],
                      child: Text(club['name']),
                    );
                  }).toList(),
                ),
              ),
            ),
            // 👆👆👆 여기까지 추가 👆👆👆

            const SizedBox(height: 30),

            // 1. 요일 선택
            _buildSectionTitle("선호 요일"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: _dayMap.keys.map((label) {
                final value = _dayMap[label]!;
                final isSelected = _selectedDay == value;
                return _buildChoiceChip(label, isSelected, (selected) {
                  if (selected) setState(() => _selectedDay = value);
                });
              }).toList(),
            ),
            
            const SizedBox(height: 30),

            // 2. 시간대 선택
            _buildSectionTitle("선호 시간대"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: _timeMap.keys.map((label) {
                final value = _timeMap[label]!;
                final isSelected = _selectedTime == value;
                return _buildChoiceChip(label, isSelected, (selected) {
                  if (selected) setState(() => _selectedTime = value);
                });
              }).toList(),
            ),

            const SizedBox(height: 60),

            // 3. 매칭 시작 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startMatching,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Text("자동 매칭 시작", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            Text("참가 팀: $_myClubName", style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _lime,
      backgroundColor: _panel,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? _lime : Colors.transparent),
      ),
      onSelected: onSelected,
    );
  }

  String _getKeyByValue(Map<String, String> map, String value) {
    return map.keys.firstWhere((k) => map[k] == value, orElse: () => value);
  }
}