import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:round/main.dart'; 
import 'package:round/friendly_match_detail_screen.dart';

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
  bool _isSearching = false; 
  int? _myClubId; 
  String? _myClubName;
  List<dynamic> _myClubsList = []; // API Raw Data (Role, Info 확인용)

  // Matching Preferences
  String _selectedDay = 'ANY'; 
  String _selectedTime = 'ANY';

  // Mappings
  final Map<String, String> _dayMap = {'무관': 'ANY', '평일': 'WEEKDAY', '주말': 'WEEKEND'};
  final Map<String, String> _timeMap = {'무관': 'ANY', '오전': 'MORNING', '오후': 'AFTERNOON', '저녁': 'EVENING'};

  @override
  void initState() {
    super.initState();
    _fetchMyClubs();
    _initSocket();
    _initFCM();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  // 1. 내 클럽 목록 로드
  Future<void> _fetchMyClubs() async {
    try {
      final response = await dio.get('/api/my-clubs');
      final List<dynamic> clubs = response.data['clubs'];
      
      if (mounted) {
        setState(() {
          _myClubsList = clubs;
          if (clubs.isNotEmpty) {
            _myClubId = clubs[0]['id'];
            _myClubName = clubs[0]['name'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("내 동호회 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 소켓 초기화
  void _initSocket() {
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      debugPrint('✅ 소켓 연결됨 (매칭 탭)');
      socket.emit('join', {'user_id': widget.userId});
    });

    // 매칭 성공 이벤트
    socket.on('match_found', (data) {
      debugPrint('🎉 [Socket] 매칭 성공: $data');
      if (!mounted) return;

      setState(() => _isSearching = false);
      _showMatchSuccessDialog(
        opponentName: data['opponent_name'] ?? '상대팀',
        matchId: data['match_id'],
      );
    });

    // 매칭 에러 이벤트
    socket.on('match_error', (data) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showSnackBar("오류 발생: ${data['error']}");
    });

    socket.connect();
  }

  // 3. 매칭 시작 요청
  void _startMatching() async {
    if (_myClubId == null) {
      _showSnackBar("참가할 팀을 선택해주세요.");
      return;
    }

    final selectedClubData = _myClubsList.firstWhere(
      (club) => club['id'] == _myClubId, 
      orElse: () => null
    );

    if (selectedClubData == null) {
       _showSnackBar("클럽 정보를 찾을 수 없습니다.");
       return;
    }

    // 권한 체크
    String role = selectedClubData['role'] ?? 'MEMBER';
    if (role != 'ADMIN' && role != 'admin') {
      _showSnackBar("운영진만 매칭을 신청할 수 있습니다.");
      return;
    }

    // 소켓 연결 체크
    if (socket.id == null) {
      debugPrint("⚠️ 소켓 재연결 시도...");
      socket.connect();
      int retry = 0;
      while (socket.id == null && retry < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retry++;
      }
      if (socket.id == null) {
        if (mounted) _showSnackBar("서버 연결 중입니다. 잠시 후 다시 시도해주세요.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = await dio.post('/api/match/request', data: {
        'user_id': widget.userId,
        'club_id': _myClubId,
        'preferred_day': _selectedDay,
        'preferred_time': _selectedTime,
        'socket_id': socket.id,
        'sport': selectedClubData['sport'] ?? '기타',
        'sido': selectedClubData['sido'] ?? '',
        'sigungu': selectedClubData['sigungu'] ?? '',
      });
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      final data = response.data;

      // 즉시 매칭
      if (data['status'] == 'MATCHED') {
        debugPrint("🎉 [HTTP] 즉시 매칭 성공!");
        _showMatchSuccessDialog(
          opponentName: data['opponent_name'] ?? '상대팀',
          matchId: data['match_id']
        );
      } else {
        // 대기열 등록
        setState(() => _isSearching = true);
        _showWaitingDialog(data['message']);
      }

    } on DioException catch (e) {
      debugPrint("매칭 요청 실패: ${e.response?.data}");
      if (mounted) setState(() => _isLoading = false);
      if (mounted) _showSnackBar("요청 실패: ${e.response?.data['error'] ?? '서버 오류'}");
    }
  }

  void _cancelMatching() {
    setState(() => _isSearching = false);
    socket.disconnect();
    socket.connect(); // 상태 초기화를 위해 재연결
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _lime));
    }

    if (_myClubsList.isEmpty) {
      return const Center(
        child: Text("가입된 동호회가 없습니다.\n동호회 탭에서 가입해주세요.", 
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54)
        ),
      );
    }

    // 매칭 중일 때 (레이더 화면)
    if (_isSearching) {
      return _buildSearchingView();
    }

    // 기본 입력 폼
    return _buildMatchForm();
  }

  // --- View Builders ---

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 100, height: 100, child: CircularProgressIndicator(color: _lime, strokeWidth: 6)),
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

  Widget _buildMatchForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Text("매칭 조건을 선택하세요", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),

          _buildSectionTitle("참가 팀 선택"),
          const SizedBox(height: 12),
          _buildClubDropdown(),

          const SizedBox(height: 30),

          _buildSectionTitle("선호 요일"),
          const SizedBox(height: 12),
          _buildChoiceWrap(_dayMap, _selectedDay, (val) => setState(() => _selectedDay = val)),
          
          const SizedBox(height: 30),

          _buildSectionTitle("선호 시간대"),
          const SizedBox(height: 12),
          _buildChoiceWrap(_timeMap, _selectedTime, (val) => setState(() => _selectedTime = val)),

          const SizedBox(height: 60),

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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildClubDropdown() {
    return Container(
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
    );
  }

  Widget _buildChoiceWrap(Map<String, String> map, String currentValue, Function(String) onSelected) {
    return Wrap(
      spacing: 10,
      children: map.keys.map((label) {
        final value = map[label]!;
        final isSelected = currentValue == value;
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
          onSelected: (selected) {
            if (selected) onSelected(value);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  // --- Utils & Dialogs ---

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
              Navigator.pop(ctx);
              if (matchId != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => FriendlyMatchDetailScreen(matchId: matchId, opponentName: opponentName),
                ));
              }
            },
            child: const Text("이동", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWaitingDialog(String? message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text("매칭 대기 시작", style: TextStyle(color: _lime)),
        content: Text(message ?? "대기열에 등록되었습니다.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("확인", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getKeyByValue(Map<String, String> map, String value) {
    return map.keys.firstWhere((k) => map[k] == value, orElse: () => value);
  }

  void _initFCM() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // 👇👇👇 main.dart의 인스턴스 사용 👇👇👇
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data.toString(), 
        );
        
        if (message.data['type'] == 'MATCH_FOUND') {
           setState(() => _isSearching = false);
        }
      }
    });
  }
}