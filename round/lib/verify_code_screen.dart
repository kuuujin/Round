import 'dart:async';
import 'package:flutter/material.dart';
import 'user_details_screen.dart';

// 타이머 기능이 필요하므로 StatefulWidget으로 생성
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  
  Timer? _timer;
  int _remainingSeconds = 180; // 3분 = 180초
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // 인증번호 입력 필드를 감지하여 '다음' 버튼 활성화
    _codeController.addListener(() {
      setState(() {
        _isButtonEnabled = _codeController.text.length == 6;
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel(); // 화면이 사라질 때 타이머를 반드시 취소해야 합니다.
    super.dispose();
  }

  // 타이머 시작 함수
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  // 남은 시간을 MM:SS 형식으로 변환하는 함수
  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('회원가입', style: TextStyle(fontFamily: 'WantedSans', fontSize: 18, color: Colors.white,fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 40),
              
              const Text(
                '보내드린 인증번호 6자리를 입력해주세요',
                style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 30),

              // 인증번호 입력 및 재발송 버튼
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '인증번호',
                        counterText: '',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: 재발송 로직 구현
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('재발송'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 58),
                      side: BorderSide(color: Colors.white.withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // 타이머 섹션
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 8),
                    Text('남은시간', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_remainingSeconds),
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: 시간 연장 로직 구현
                      },
                      child: Text('시간연장', style: TextStyle(color: Colors.grey[400], decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isButtonEnabled ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserDetailsScreen()),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB2F142),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('인증번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}