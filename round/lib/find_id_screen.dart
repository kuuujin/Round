import 'dart:async';
import 'package:flutter/material.dart';
import 'verification_view.dart'; // ## 1. 재사용 위젯 import ##

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  bool _showVerificationStep = false;
  bool _isButtonEnabled = false;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  // ## 2. 타이머 관련 변수와 함수들 제거 ##
  // Timer? _timer;
  // int _remainingSeconds = 180; 

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _isButtonEnabled = _phoneController.text.length == 11;
      });
    });
     _codeController.addListener(() {
      setState(() {
        _isButtonEnabled = _codeController.text.length == 6;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    // _timer?.cancel(); // 타이머가 VerificationView 내부에서 관리되므로 제거
    super.dispose();
  }

  // ## 3. 타이머 시작 로직 제거 ##
  void _goToVerificationStep() {
    setState(() {
      _showVerificationStep = true;
      _isButtonEnabled = false;
    });
    // _startTimer(); // 타이머가 VerificationView 내부에서 관리되므로 제거
    // TODO: 서버에 인증번호 전송 API 호출
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF262626),
    appBar: AppBar(
      iconTheme: const IconThemeData(color: Colors.white), // 아이콘 테마 적용
      title: const Text('아이디 찾기', style: TextStyle(fontFamily: 'WantedSans', fontSize: 18, fontWeight: FontWeight.w600)),
      centerTitle: true,
      backgroundColor: const Color(0xFF262626), // 배경색 통일
      elevation: 0,
    ),
    // ## 1. 레이아웃 위젯을 단순한 SingleChildScrollView로 변경 ##
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 40),

            // ## 2. AnimatedSwitcher 내부 구조 수정 ##
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showVerificationStep
                  // 2-1. 인증 단계 UI
                  ? Column(
                      key: const ValueKey('verify_step'),
                      children: [
                        VerificationView(controller: _codeController),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isButtonEnabled ? () { /* TODO */ } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB2F142),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('인증 번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  // 2-2. 휴대폰 입력 단계 UI
                  : _buildPhoneInputStep(),
            ),
            
            // ## 3. 하단 Spacer와 버튼 제거 ##
          ],
        ),
      ),
    ),
  );
}

  // 1단계: 휴대폰 번호 입력 UI
  Widget _buildPhoneInputStep() {
  return Column(
    key: const ValueKey('phone_step'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.grey[300])),
      const SizedBox(height: 12),
      const Text('휴대폰번호를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
      const SizedBox(height: 30),
      TextField(
        controller: _phoneController,
        maxLength: 11,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          hintText: '휴대폰번호',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
        ),
      ),
      
      // ## 4. 휴대폰 입력 필드 아래에 '다음' 버튼 추가 ##
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isButtonEnabled ? _goToVerificationStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB2F142),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('다음', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );
}
}