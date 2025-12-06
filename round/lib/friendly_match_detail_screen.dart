import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/user_provider.dart';

class FriendlyMatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String opponentName;

  const FriendlyMatchDetailScreen({
    super.key,
    required this.matchId,
    required this.opponentName,
  });

  @override
  State<FriendlyMatchDetailScreen> createState() => _FriendlyMatchDetailScreenState();
}

class _FriendlyMatchDetailScreenState extends State<FriendlyMatchDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // 👇 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController(); 
  
  final Dio dio = ApiClient().dio;
  late IO.Socket socket;
  
  List<Map<String, String>> _messages = [];
  // 👇 UserProvider가 null일 경우를 대비해 안전하게 가져오기
  late final String myUserId; 
  
  // 일정 관련 변수
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // 매칭 상태 변수
  String _status = 'MATCHED';
  int? _myScore;
  int? _opScore;
  bool _amIProposer = false;
  bool _isLoadingInfo = true;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  @override
  void initState() {
    super.initState();
    // UserID 초기화 (없으면 빈 문자열 처리하여 에러 방지)
    myUserId = UserProvider().userId ?? '';
    
    _fetchMatchInfo();
    _loadChatHistory();
    _initSocket();
  }

  @override
  void dispose() {
    socket.dispose();
    _msgController.dispose();
    _locationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- 1. 데이터 로드 및 소켓 ---

  Future<void> _fetchMatchInfo() async {
    try {
      final response = await dio.get('/api/match/detail', queryParameters: {'match_id': widget.matchId});
      final info = response.data['info'];

      if (mounted) {
        setState(() {
          _status = info['status'];
          _amIProposer = info['is_proposer'] ?? false;
          _myScore = info['my_score'];
          _opScore = info['op_score'];
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      print("매칭 정보 로드 실패: $e");
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final response = await dio.get('/api/chat/history', queryParameters: {'match_id': widget.matchId});
      final List<dynamic> data = response.data['messages'];
      
      if (mounted) {
        setState(() {
          _messages = data.map((m) => {
            'sender': m['sender_id'].toString() == myUserId ? 'me' : (m['sender_id'].toString() == 'system' ? 'system' : 'opponent'),
            'message': m['message'].toString(),
            'time': m['time'].toString(),
          }).toList();
        });
        // 로딩 후 스크롤 아래로
        _scrollToBottom();
      }
    } catch (e) {
      print("채팅 내역 로드 실패: $e");
    }
  }

  void _initSocket() {
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      socket.emit('join_chat', {'room': widget.matchId, 'user_id': myUserId});
    });

    socket.on('new_message', (data) {
      if (mounted) {
        setState(() {
          // 시스템 메시지면 상태 갱신 (예: 경기 결과 확정 등)
          if (data['sender'] == 'system') {
             _fetchMatchInfo();
          }

          _messages.add({
            'sender': data['sender'] == 'system' ? 'system' : (data['sender'] == myUserId ? 'me' : 'opponent'),
            'message': data['message'],
            'time': DateTime.now().toString().substring(11, 16),
          });
        });
        // 메시지 오면 스크롤 아래로
        _scrollToBottom();
      }
    });

    socket.connect();
  }

  // 👇👇👇 스크롤을 맨 아래로 내리는 함수 구현 👇👇👇
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    socket.emit('send_message', {
      'room': widget.matchId,
      'user_id': myUserId,
      'message': _msgController.text.trim(),
    });
    _msgController.clear();
  }

  // --- 2. 경기 결과 로직 ---

  Future<void> _proposeResult(int my, int op) async {
    try {
      await dio.post('/api/match/result/propose', data: {
        'match_id': widget.matchId,
        'score_my': my,
        'score_op': op,
      });
      
      socket.emit('send_message', {
        'room': widget.matchId,
        'user_id': 'system',
        'message': "📢 경기 결과가 입력되었습니다.\n[${my} : ${op}]\n상대방은 결과를 확인해주세요.",
      });

      if (mounted) {
        setState(() {
          _status = 'PENDING';
          _amIProposer = true;
          _myScore = my;
          _opScore = op;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("입력 실패: $e")));
    }
  }

  Future<void> _confirmResult(bool accept) async {
    try {
      await dio.post('/api/match/result/confirm', data: {
        'match_id': widget.matchId,
        'accept': accept,
      });

      String msg = accept 
          ? "✅ 경기 결과가 승인되었습니다.\n수고하셨습니다!" 
          : "❌ 경기 결과가 거절되었습니다.\n다시 입력해주세요.";

      socket.emit('send_message', {
        'room': widget.matchId,
        'user_id': 'system',
        'message': msg,
      });

      if (mounted) {
        setState(() {
          if (accept) {
            _status = 'FINISHED';
          } else {
            _status = 'MATCHED';
            _amIProposer = false;
          }
        });
      }
    } catch (e) {
      print("승인/거절 실패: $e");
    }
  }

  void _showInputScoreDialog() {
    final myCtrl = TextEditingController();
    final opCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        title: const Text("경기 결과 입력", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("우리팀 vs 상대팀", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: myCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "내 점수", hintStyle: TextStyle(color: Colors.grey)))),
                const Text(" : ", style: TextStyle(color: Colors.white, fontSize: 20)),
                Expanded(child: TextField(controller: opCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "상대 점수", hintStyle: TextStyle(color: Colors.grey)))),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _lime),
            onPressed: () {
              if (myCtrl.text.isNotEmpty && opCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                _proposeResult(int.parse(myCtrl.text), int.parse(opCtrl.text));
              }
            },
            child: const Text("입력 완료", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- 3. 일정 확정 로직 ---

  Future<void> _submitSchedule() async {
    if (_selectedDate == null || _selectedTime == null || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ 날짜, 시간, 장소를 모두 입력해주세요.")));
      return;
    }

    final DateTime finalDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      final response = await dio.post('/api/match/schedule', data: {
        'match_id': widget.matchId, 
        'schedule_date': finalDateTime.toIso8601String(),
        'location': _locationController.text.trim(),
      });

      if (response.data['success'] == true) {
        if (mounted) Navigator.pop(context);
        
        // 👇👇👇 날짜 포맷팅 함수 호출 👇👇👇
        String dateStr = _formatDate(finalDateTime); 

        String systemMsg = "✅ 일정이 확정되었습니다.\n📅 일시: $dateStr\n📍 장소: ${_locationController.text}";
                           
        socket.emit('send_message', {
          'room': widget.matchId,
          'user_id': 'system',
          'message': systemMsg,
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("일정이 확정되었습니다!")));
      }
    } catch (e) {
      print("일정 확정 오류: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("서버 통신 오류가 발생했습니다.")));
    }
  }
  
  // 👇👇👇 날짜 포맷팅 함수 구현 👇👇👇
  String _formatDate(DateTime dt) {
    return "${dt.month}월 ${dt.day}일 ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}";
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("📅 일정 및 장소 확정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 날짜 선택
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedDate == null 
                          ? "날짜를 선택해주세요" 
                          : "${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일",
                      style: TextStyle(color: _selectedDate == null ? Colors.white54 : Colors.white),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: _lime),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setStateDialog(() => _selectedDate = date);
                      }
                    },
                  ),
                  const Divider(color: Colors.white24),
                  // 시간 선택
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedTime == null 
                          ? "시간을 선택해주세요" 
                          : "${_selectedTime!.hour}시 ${_selectedTime!.minute.toString().padLeft(2,'0')}분",
                      style: TextStyle(color: _selectedTime == null ? Colors.white54 : Colors.white),
                    ),
                    trailing: const Icon(Icons.access_time, color: _lime),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setStateDialog(() => _selectedTime = time);
                      }
                    },
                  ),
                  const Divider(color: Colors.white24),
                  // 장소 입력
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "경기 장소",
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: "예: 인하대 후문 볼링장",
                      hintStyle: TextStyle(color: Colors.white30),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _lime)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: _submitSchedule,
                  style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
                  child: const Text("확정 하기", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== UI Build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text("친선 경기 매칭", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. 매칭 정보 카드
          Container(
            padding: const EdgeInsets.all(20),
            color: _panel,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text("우리팀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Text("VS", style: TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(widget.opponentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                
                // 상태별 버튼 UI
                if (_status == 'MATCHED') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 일정 확정 버튼
                      ElevatedButton.icon(
                        onPressed: _showScheduleDialog,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text("일정 확정"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                      ),
                      const SizedBox(width: 10),
                      // 결과 입력 버튼
                      ElevatedButton.icon(
                        onPressed: _showInputScoreDialog,
                        icon: const Icon(Icons.scoreboard),
                        label: const Text("결과 입력"),
                        style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                ] else if (_status == 'PENDING') ...[
                  if (_amIProposer)
                    Column(
                      children: [
                        const Text("승인 대기 중...", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
                        Text("$_myScore : $_opScore", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text("상대방이 결과를 입력했습니다.", style: TextStyle(color: Colors.white70)),
                        Text("$_opScore : $_myScore", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _confirmResult(true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: const Text("승인", style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => _confirmResult(false),
                              child: const Text("거절", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        )
                      ],
                    )
                ] else if (_status == 'FINISHED') ...[
                  Column(
                    children: [
                      const Text("경기 종료", style: TextStyle(color: Colors.grey)),
                      Text("$_myScore : $_opScore", style: const TextStyle(color: _lime, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ],
            ),
          ),

          // 2. 채팅 영역
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), // 빈 곳 터치 시 키보드 내림
              child: ListView.builder(
                controller: _scrollController, // 스크롤 컨트롤러 연결
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  
                  // 시스템 메시지
                  if (msg['sender'] == 'system') {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                        child: Text(msg['message']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    );
                  }
                  
                  final isMe = msg['sender'] == 'me';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? _lime : _panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(msg['message']!, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
                          const SizedBox(height: 2),
                          Text(msg['time'] ?? '', style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. 입력창
          Container(
            padding: const EdgeInsets.all(12),
            color: _panel,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "채팅 입력...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(), // 엔터 입력 시 전송
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: _lime),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}