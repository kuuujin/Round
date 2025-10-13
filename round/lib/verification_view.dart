import 'dart:async';
import 'package:flutter/material.dart';

class VerificationView extends StatefulWidget {
  // 부모 위젯에서 컨트롤러를 전달받기 위한 파라미터
  final TextEditingController controller;

  const VerificationView({
    super.key,
    required this.controller,
  });

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  Timer? _timer;
  int _remainingSeconds = 180;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 180; // 재발송 시 타이머 초기화
    _timer?.cancel(); // 기존 타이머가 있다면 취소
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('verify_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('보내드린 인증번호 6자리를 입력해주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 22, color: Colors.white)),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller, // 전달받은 컨트롤러 사용
                maxLength: 6,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(hint: '인증번호'),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () { 
                _startTimer();
                // TODO: 재발송 API 호출
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('재발송'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(100, 58), side: BorderSide(color: Colors.white.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              Text('남은시간', style: TextStyle(color: Colors.grey[400])),
              const SizedBox(width: 8),
              Text(_formatDuration(_remainingSeconds), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () { /* TODO: 시간 연장 로직 */ }, child: Text('시간연장', style: TextStyle(color: Colors.grey[400], decoration: TextDecoration.underline))),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
    );
  }
}