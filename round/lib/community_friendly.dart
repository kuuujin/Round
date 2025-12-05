import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:round/friendly_match_detail_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  List<dynamic> _myClubsList = []; // 드롭다운용 동호회 목록

  // Matching Preferences
  String _selectedDay = 'ANY'; 
  String _selectedTime = 'ANY';

  final Map<String, String> _dayMap = {'무관': 'ANY', '평일': 'WEEKDAY', '주말': 'WEEKEND'};
  final Map<String, String> _timeMap = {'무관': 'ANY', '오전': 'MORNING', '오후': 'AFTERNOON', '저녁': 'EVENING'};

  @override
  void initState() {
    super.initState();
    _fetchMyClubs(); // 1. 내 클럽 정보 가져오기
    _initSocket();   // 2. 소켓 초기화
    _initFCM();      // 3. FCM 초기화
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
      
      if (mounted) {
        setState(() {
          _myClubsList = clubs;
          if (clubs.isNotEmpty) {
            // 기본값: 첫 번째 동호회 선택
            _myClubId = clubs[0]['id'];
            _myClubName = clubs[0]['name'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("내 동호회 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
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
      print("🚪 방 입장 요청: ${widget.userId}");
      socket.emit('join', {'user_id': widget.userId});
    });

    // 매칭 성공 이벤트 수신 (대기자용)
    socket.on('match_found', (data) {
      print('🎉 [Socket] 매칭 성공: $data');
      if (!mounted) return;

      setState(() => _isSearching = false);
      
      // 매칭 성공 다이얼로그 띄우기
      _showMatchSuccessDialog(
        opponentName: data['opponent_name'] ?? '상대팀',
        matchId: data['match_id'],
      );
    });

    socket.on('match_error', (data) {
      print('❌ 매칭 에러: $data');
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류 발생: ${data['error']}")));
    });

    socket.connect();
  }

  // 3. 매칭 시작 요청 (신청자용)
  void _startMatching() async {
    if (_myClubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("참가할 팀을 선택해주세요.")));
      return;
    }

    if (socket.id == null) {
      print("⚠️ 소켓이 아직 연결되지 않았습니다. 재연결 시도...");
      socket.connect();
      // 연결될 때까지 잠시 대기 (최대 2초)
      int retry = 0;
      while (socket.id == null && retry < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retry++;
      }
      
      if (socket.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("서버 연결 중입니다. 잠시 후 다시 시도해주세요.")));
        return;
      }
    }

    setState(() => _isLoading = true); // 잠깐 로딩만 보여줌

    try {
      final response = await dio.post('/api/match/request', data: {
        'user_id': widget.userId, // 사용자 ID도 함께 전송 (서버 로직에 따라 필요할 수 있음)
        'club_id': _myClubId,
        'preferred_day': _selectedDay,
        'preferred_time': _selectedTime,
        'socket_id': socket.id, // 소켓 ID 전송 필수
      });
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      final data = response.data;

      // HTTP 응답으로 바로 매칭된 경우 (신청자)
      if (data['status'] == 'MATCHED') {
        print("🎉 [HTTP] 즉시 매칭 성공!");
        _showMatchSuccessDialog(
          opponentName: data['opponent_name'] ?? '상대팀', 
          matchId: data['match_id']
        );
      } else {
        // 대기열 등록된 경우
        setState(() => _isSearching = true);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF333333),
            title: const Text("매칭 대기 시작", style: TextStyle(color: _lime)),
            content: Text(data['message'] ?? "대기열에 등록되었습니다.", style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("확인", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }

    } on DioException catch (e) {
      print("매칭 요청 실패: $e");
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("요청 실패")));
    }
  }

  // 4. 매칭 취소
  void _cancelMatching() {
    setState(() => _isSearching = false);
    // socket.emit('cancel_match'); // 필요하다면 서버에 취소 이벤트 전송
    // 소켓 재연결로 상태 초기화 (간편한 방법)
    socket.disconnect();
    socket.connect(); 
  }

  // 5. 공통 매칭 성공 다이얼로그
  void _showMatchSuccessDialog({required String opponentName, String? matchId}) {
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
            Text("상대팀: $opponentName", style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            const Text("경기 일정 조율을 위해\n채팅방으로 이동하시겠습니까?", style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 다이얼로그 닫기
              
              if (matchId != null && matchId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendlyMatchDetailScreen(
                      matchId: matchId,       // 서버에서 받은 방 ID
                      opponentName: opponentName, // 상대 팀 이름
                    ),
                  ),
                );
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("채팅방 ID 오류")));
              }
            },
            child: const Text("이동", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _initFCM() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM 메시지 수신: ${message.notification?.title}');
      if (!mounted) return;

      // 👇👇👇 앱이 켜져 있을 때 알림창 띄우기 👇👇👇
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // 소켓이 끊겨있거나, 단순히 알림을 보여주고 싶을 때
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // 채널 ID
              'High Importance Notifications',
              channelDescription: '알림 채널 설명',
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          // (선택) 알림 클릭 시 전달할 데이터
          payload: message.data.toString(), 
        );
        
        // 상태 업데이트
        if (!socket.connected) {
             setState(() => _isSearching = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _lime));
    }

    // 가입된 동호회가 없을 때
    if (_myClubsList.isEmpty) {
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
            const SizedBox(height: 30),

            // 동호회 선택 드롭다운
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
            // 아래에 여백 추가 (BottomNavBar 가림 방지)
            const SizedBox(height: 80),
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