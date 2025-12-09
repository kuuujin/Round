import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
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
  // Controllers
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Network & Socket
  final Dio dio = ApiClient().dio;
  late IO.Socket socket;
  late final String myUserId;

  // Data State
  List<Map<String, String>> _messages = [];
  bool _isLoadingInfo = true;

  // Match State
  String _status = 'MATCHED';
  int? _myScore;
  int? _opScore;
  bool _amIProposer = false;

  // Schedule State
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  @override
  void initState() {
    super.initState();
    myUserId = UserProvider().userId ?? '';
    
    _fetchMatchInfo();
    _loadChatHistory();
    _initSocket();
  }

  @override
  void dispose() {
    // 소켓 이벤트 리스너 해제 (연결은 유지하되 핸들러만 제거)
    socket.off('new_message'); 
    _msgController.dispose();
    _locationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- 1. 소켓 및 데이터 로드 ---

  void _initSocket() {
    // 싱글톤 소켓 가져오기
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    void joinRoom() {
      debugPrint("🚪 방 입장: ${widget.matchId}");
      socket.emit('join_chat', {'room': widget.matchId, 'user_id': myUserId});
      _loadChatHistory(); // 입장 후 최신 내역 갱신
    }

    // 중복 방지를 위해 기존 리스너 제거 후 등록
    socket.off('new_message');
    socket.on('new_message', (data) {
      if (!mounted) return;
      
      String sender = data['sender'] ?? data['user_id'] ?? 'unknown';
      if (sender == myUserId || sender == 'me') return; // 내가 보낸 건 무시

      setState(() {
        if (sender == 'system') _fetchMatchInfo(); // 시스템 메시지면 상태 갱신

        _messages.add({
          'sender': sender == 'system' ? 'system' : 'opponent',
          'message': data['message'].toString(),
          'time': DateFormat('HH:mm').format(DateTime.now()),
        });
      });
      _scrollToBottom();
    });

    // 연결 상태에 따른 처리
    if (socket.connected) {
      joinRoom();
    } else {
      socket.onConnect((_) => joinRoom());
      socket.connect();
    }
  }

  Future<void> _fetchMatchInfo() async {
    try {
      final response = await dio.get('/api/match/detail', queryParameters: {'match_id': widget.matchId});
      if (response.data['success'] == true) {
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
      }
    } catch (e) {
      debugPrint("매칭 정보 로드 실패: $e");
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
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("채팅 내역 로드 실패: $e");
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    socket.emit('send_message', {
      'room': widget.matchId,
      'user_id': myUserId,
      'message': text,
    });
    
    _msgController.clear();

    if (mounted) {
      setState(() {
        _messages.add({
          'sender': 'me',
          'message': text,
          'time': DateFormat('HH:mm').format(DateTime.now()),
        });
      });
      _scrollToBottom();
    }
  }

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

  // --- 2. 경기 결과 및 일정 로직 ---

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
        'message': "📢 경기 결과가 입력되었습니다.\n[$my : $op]\n상대방은 결과를 확인해주세요.",
      });

      _fetchMatchInfo(); // 상태 갱신
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

      _fetchMatchInfo(); // 상태 갱신
    } catch (e) {
      debugPrint("승인/거절 실패: $e");
    }
  }

  Future<void> _submitSchedule() async {
    if (_selectedDate == null || _selectedTime == null || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ 날짜, 시간, 장소를 모두 입력해주세요.")));
      return;
    }

    final DateTime finalDateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      final response = await dio.post('/api/match/schedule', data: {
        'match_id': widget.matchId, 
        'schedule_date': finalDateTime.toIso8601String(),
        'location': _locationController.text.trim(),
      });

      if (response.data['success'] == true) {
        if (mounted) Navigator.pop(context); // 다이얼로그 닫기
        
        String dateStr = DateFormat('M월 d일 HH:mm').format(finalDateTime);
        String systemMsg = "✅ 일정이 확정되었습니다.\n📅 일시: $dateStr\n📍 장소: ${_locationController.text}";
                                    
        socket.emit('send_message', {
          'room': widget.matchId,
          'user_id': 'system',
          'message': systemMsg,
        });
      }
    } catch (e) {
      debugPrint("일정 확정 오류: $e");
    }
  }

  // --- 3. UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text("친선 경기 매칭", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. 상단 정보 및 액션 버튼
          _buildMatchHeader(),

          // 2. 채팅 리스트
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildChatList(),
            ),
          ),

          // 3. 입력창
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMatchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _panel,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text("우리팀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text("VS", style: TextStyle(color: _lime, fontSize: 24, fontWeight: FontWeight.w900)),
              Text(widget.opponentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isLoadingInfo) return const SizedBox.shrink();

    if (_status == 'MATCHED') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _showScheduleDialog,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text("일정 확정"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showInputScoreDialog,
            icon: const Icon(Icons.scoreboard, size: 18),
            label: const Text("결과 입력"),
            style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
          ),
        ],
      );
    } else if (_status == 'PENDING') {
      if (_amIProposer) {
        return Column(
          children: [
            const Text("상대방의 승인을 기다리는 중...", style: TextStyle(color: _lime, fontSize: 13)),
            const SizedBox(height: 4),
            Text("$_myScore : $_opScore", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        );
      } else {
        return Column(
          children: [
            Text("결과 입력: $_opScore : $_myScore", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  child: const Text("거절", style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        );
      }
    } else if (_status == 'FINISHED') {
      return Column(
        children: [
          const Text("경기 종료", style: TextStyle(color: Colors.grey)),
          Text("$_myScore : $_opScore", style: const TextStyle(color: _lime, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg['sender'] == 'me';
        final isSystem = msg['sender'] == 'system';

        if (isSystem) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
              child: Text(msg['message']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          );
        }

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? _lime : _panel,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(msg['message']!, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15)),
                const SizedBox(height: 4),
                Text(msg['time'] ?? '', style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _panel,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "메시지를 입력하세요...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _lime,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---

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
            Row(
              children: [
                Expanded(child: _buildScoreField(myCtrl, "내 점수")),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(":", style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                Expanded(child: _buildScoreField(opCtrl, "상대 점수")),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _lime),
            onPressed: () {
              if (myCtrl.text.isNotEmpty && opCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                _proposeResult(int.parse(myCtrl.text), int.parse(opCtrl.text));
              }
            },
            child: const Text("입력", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildScoreField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _panel,
              title: const Text("일정 확정", style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        _selectedDate == null ? "날짜 선택" : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                        style: TextStyle(color: _selectedDate == null ? Colors.white54 : Colors.white),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: _lime),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel)), child: child!),
                        );
                        if (date != null) setStateDialog(() => _selectedDate = date);
                      },
                    ),
                    const Divider(color: Colors.white24),
                    ListTile(
                      title: Text(
                        _selectedTime == null ? "시간 선택" : _selectedTime!.format(context),
                        style: TextStyle(color: _selectedTime == null ? Colors.white54 : Colors.white),
                      ),
                      trailing: const Icon(Icons.access_time, color: _lime),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel)), child: child!),
                        );
                        if (time != null) setStateDialog(() => _selectedTime = time);
                      },
                    ),
                    const Divider(color: Colors.white24),
                    TextField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "장소",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _lime)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: _submitSchedule,
                  style: ElevatedButton.styleFrom(backgroundColor: _lime),
                  child: const Text("확정", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}