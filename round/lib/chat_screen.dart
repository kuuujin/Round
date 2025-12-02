import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  final String matchId; // 매칭된 방 ID
  final String userId;  // 내 아이디
  final String opponentName; // 상대방 이름

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.userId,
    required this.opponentName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  late IO.Socket socket;
  
  // 채팅 메시지 리스트 (예시 데이터 포함)
  final List<Map<String, String>> _messages = [];

  // 팔레트
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    // 1. 소켓 연결 (기존과 동일한 주소)
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('💬 채팅 소켓 연결됨');
      // 2. 방 입장 요청
      socket.emit('join_chat', {'room': widget.matchId, 'user_id': widget.userId});
    });

    // 3. 메시지 수신 리스너
    socket.on('new_message', (data) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': data['sender'], // 'me' or 'opponent'
            'message': data['message'],
          });
        });
      }
    });

    socket.connect();
  }

  // 4. 메시지 전송
  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;

    final msg = _msgController.text.trim();
    
    // 서버로 전송
    socket.emit('send_message', {
      'room': widget.matchId,
      'user_id': widget.userId,
      'message': msg,
    });

    // 내 화면에 즉시 추가
    setState(() {
      _messages.add({'sender': 'me', 'message': msg});
    });
    
    _msgController.clear();
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: Text("${widget.opponentName} 팀과의 채팅", style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 메시지 리스트
          Expanded(
            child: ListView.builder(
              reverse: false, // 최신 메시지가 아래로 쌓임 (필요시 true로 변경)
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
                      color: isMe ? _lime : _panel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['message']!,
                      style: TextStyle(color: isMe ? Colors.black : Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 입력창
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
                      hintText: "메시지를 입력하세요",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
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