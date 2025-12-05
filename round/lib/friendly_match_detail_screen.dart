import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/user_provider.dart';

class FriendlyMatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String opponentName;
  // final String opponentImage; // 이미지도 있으면 좋습니다

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
  final Dio dio = ApiClient().dio;
  late IO.Socket socket;
  List<Map<String, String>> _messages = [];
  final String myUserId = UserProvider().userId!;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _locationController = TextEditingController();

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  @override
  void initState() {
    super.initState();
    _loadChatHistory(); // 1. 이전 대화 불러오기
    _initSocket();
  }

  // 1. 채팅 내역 로드
  Future<void> _loadChatHistory() async {
    try {
      final response = await dio.get('/api/chat/history', queryParameters: {'match_id': widget.matchId});
      final List<dynamic> data = response.data['messages'];
      setState(() {
        _messages = data.map((m) => {
          'sender': m['sender_id'].toString() == myUserId ? 'me' : 'opponent',
          'message': m['message'].toString(),
          'time': m['time'].toString(),
        }).toList();
      });
    } catch (e) {
      print("채팅 내역 로드 실패: $e");
    }
  }

  // 2. 소켓 연결 (기존과 동일)
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
          _messages.add({
            'sender': data['sender'] == myUserId ? 'me' : 'opponent',
            'message': data['message'],
            'time': DateTime.now().toString().substring(11, 16), // 임시 시간
          });
        });
      }
    });

    socket.connect();
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

  Future<void> _submitSchedule() async {
    if (_selectedDate == null || _selectedTime == null || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ 날짜, 시간, 장소를 모두 입력해주세요.")));
      return;
    }

    // 날짜 + 시간 합치기
    final DateTime finalDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      // API 호출
      final response = await dio.post('/api/match/schedule', data: {
        'match_id': widget.matchId, 
        'schedule_date': finalDateTime.toIso8601String(), // ISO8601 형식 전송
        'location': _locationController.text.trim(),
      });

      if (response.data['success'] == true) {
        Navigator.pop(context); // 다이얼로그 닫기
        
        // 소켓으로 시스템 메시지 전송 (상대방도 알 수 있게)
        String systemMsg = "✅ 일정이 확정되었습니다.\n"
                           "📅 일시: ${_formatDate(finalDateTime)}\n"
                           "📍 장소: ${_locationController.text}";
                           
        socket.emit('send_message', {
          'room': widget.matchId,
          'user_id': 'system', // system ID 처리 필요 (서버에서 system이면 UI 다르게 표시 등)
          'message': systemMsg,
        });
        
        // 내 화면에 바로 띄우기 위해 리스트에 추가 (선택사항)
        // 소켓 리스너가 이미 있다면 거기서 받아 처리됨
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("일정이 확정되었습니다!")));
      }
    } catch (e) {
      print("일정 확정 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("서버 통신 오류가 발생했습니다.")));
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.month}월 ${dt.day}일 ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}";
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // 다이얼로그 내부에서만 상태를 갱신하기 위해 StatefulBuilder 사용
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _panel, // #2F2F2F
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("📅 일정 및 장소 확정", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  onPressed: _submitSchedule, // 확정 버튼 클릭 시 함수 호출
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

  

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: Text("친선 경기 매칭", style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- 👆 1. 매칭 정보 카드 (헤더) ---
          Container(
            padding: EdgeInsets.all(20),
            color: _panel,
            child: Row(
              children: [
                Text("우리팀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Spacer(),
                Text("VS", style: TextStyle(color: _lime, fontSize: 20, fontWeight: FontWeight.bold)),
                Spacer(),
                Text(widget.opponentName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // --- ✌️ 2. 일정 확정 / 결과 입력 버튼 ---
          Container(
            color: _panel,
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showScheduleDialog,
                  icon: Icon(Icons.calendar_month),
                  label: Text("일정 확정"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () { /* 경기 결과 입력 */ }, 
                  icon: Icon(Icons.scoreboard),
                  label: Text("결과 입력"),
                  style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
                ),
              ],
            ),
          ),

          // --- 👌 3. 채팅 영역 ---
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? _lime : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['message']!, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
                  ),
                );
              },
            ),
          ),
          
          // 입력창 (기존과 동일)
          Container(
            padding: const EdgeInsets.all(12),
            color: _panel,
            child: Row(children: [
                Expanded(child: TextField(controller: _msgController, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "채팅 입력...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none))),
                IconButton(icon: Icon(Icons.send, color: _lime), onPressed: _sendMessage)
            ]),
          ),
        ],
      ),
    );
  }
}

