import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

class VerificationView extends StatefulWidget {
  final TextEditingController controller;
  // 1. 재발송 버튼을 눌렀을 때 실행될 콜백 함수를 받습니다.
  // Future<bool>을 반환하여, 부모 위젯이 타이머를 리셋할지 여부를 결정합니다.
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
  // 2. 타이머와 남은 시간을 State 내부에서 직접 관리합니다.
  Timer? _timer;
  int _remainingSeconds = 180;

  @override
  void initState() {
    super.initState();
    listenForCode();
    _startTimer(); // 위젯이 생성될 때 타이머를 시작합니다.
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel(); // 위젯이 사라질 때 타이머를 확실히 종료합니다.
    super.dispose();
  }

  @override
  void codeUpdated() {
    setState((){
      widget.controller.text = code!;
    });
  }

  // 3. 타이머를 시작/리셋하는 내부 함수입니다.
  void _startTimer() {
    _timer?.cancel(); // 기존 타이머가 있다면 취소합니다.
    setState(() {
      _remainingSeconds = 180; // 시간을 180초로 초기화합니다.
    });
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

  // 시간을 MM:SS 형식으로 변환하는 헬퍼 함수입니다.
  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('보내드린 인증번호 6자리를 입력해주세요',
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 22,
                color: Colors.white)),
        const SizedBox(height: 30),
        Row(children: [
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
                letterSpacing: 16,
              ),
              cursorColor: const Color(0xFFB2F142),
              decoration: InputDecoration(
                counterText: '',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 4. 재발송 버튼의 onPressed 로직을 완성합니다.
          OutlinedButton.icon(
            onPressed: () async {
              // 부모로부터 받은 onResend 함수가 있는지 확인하고 실행합니다.
              if (widget.onResend != null) {
                final success = await widget.onResend!();
                // 부모 함수가 true를 반환하면, 타이머를 리셋합니다.
                if (success) {
                  _startTimer();
                }
              }
            },
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('재발송'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 58),
                side: BorderSide(color: Colors.white.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade800.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text('남은시간', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(width: 8),
            Text(_formatDuration(_remainingSeconds),
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
                onPressed: () {},
                child: Text('시간연장',
                    style: TextStyle(
                        color: Colors.grey[400],
                        decoration: TextDecoration.underline))),
          ]),
        ),
      ],
    );
  }
}