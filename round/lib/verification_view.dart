import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

class VerificationView extends StatefulWidget {
  final TextEditingController controller;
  
  // 재발송 로직 (성공 여부를 Future<bool>로 반환)
  final Future<bool> Function()? onResend;

  const VerificationView({
    super.key,
    required this.controller,
    this.onResend,
  });

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> with CodeAutoFill {
  // State
  Timer? _timer;
  int _remainingSeconds = 180;
  bool _isResending = false; // 재전송 중복 방지

  // Palette
  static const Color _lime = Color(0xFFB2F142);

  @override
  void initState() {
    super.initState();
    listenForCode(); // SMS Autofill 시작
    _startTimer();
  }

  @override
  void dispose() {
    cancel(); // SMS Autofill 해제
    _timer?.cancel();
    super.dispose();
  }

  @override
  void codeUpdated() {
    if (code != null) {
      setState(() {
        widget.controller.text = code!;
      });
    }
  }

  // --- Logic ---

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 180);
    
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

  Future<void> _handleResend() async {
    if (widget.onResend == null || _isResending) return;

    setState(() => _isResending = true);

    try {
      final success = await widget.onResend!();
      if (success) {
        _startTimer(); // 성공 시 타이머 리셋
        widget.controller.clear(); // 입력창 초기화
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$sec';
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '보내드린 인증번호 6자리를 입력해주세요',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: Colors.white),
        ),
        const SizedBox(height: 30),
        
        // 입력창 & 재발송 버튼 Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 16, // 글자 간격 넓게
                ),
                cursorColor: _lime,
                decoration: InputDecoration(
                  counterText: '',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _lime, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // 재발송 버튼
            OutlinedButton.icon(
              onPressed: _isResending ? null : _handleResend,
              icon: _isResending 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              label: Text(_isResending ? '' : '재발송'),
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
        
        // 타이머 영역
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
            ],
          ),
        ),
      ],
    );
  }
}