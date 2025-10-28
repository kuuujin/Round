import 'dart:async';
import 'package:flutter/material.dart';
import 'package:round/api_client.dart'; // ApiClient import
import 'package:dio/dio.dart'; // Dio import
import 'verification_view.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  bool _showVerificationStep = false;
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => _updateButtonState(step: 0));
    _codeController.addListener(() => _updateButtonState(step: 1));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _updateButtonState({required int step}) {
    bool isEnabled = false;
    if (step == 0) {
      isEnabled = _phoneController.text.length == 11;
    } else if (step == 1) {
      isEnabled = _codeController.text.length == 6;
    }
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  // 1. 휴대폰 번호 제출 처리 함수
  Future<void> _handlePhoneSubmission() async {
    setState(() => _isLoading = true);
    try {
      await dio.post(
        '/find-id/send-code',
        data: {'phone': _phoneController.text},
      );
      // 성공 시 인증 단계로 UI 전환
      setState(() {
        _showVerificationStep = true;
        _isButtonEnabled = false;
      });
    } on DioException catch (e) {
      String errorMessage = "요청에 실패했습니다.";
      if (e.response?.statusCode == 404) {
        errorMessage = "가입되지 않은 번호입니다.";
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 인증번호 확인 처리 함수
  Future<void> _handleCodeVerification() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post(
        '/find-id/verify-code',
        data: {'code': _codeController.text},
      );
      final userId = response.data['user_id'];
      _showFoundIdDialog(userId); // 성공 시 아이디 표시 다이얼로그 호출
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? "인증에 실패했습니다.";
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. 찾은 아이디를 보여주고 로그인 화면으로 이동하는 다이얼로그
  void _showFoundIdDialog(String userId) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('아이디 확인',style: TextStyle(color: Colors.white)),
        content: Text('회원님의 아이디는 "$userId" 입니다.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로 이동
            },
            child: const Text('확인',style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. 공통 에러 다이얼로그
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('알림', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('아이디 찾기', style: TextStyle(fontFamily: 'WantedSans', color: Colors.white ,fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: const Color(0xFF262626),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showVerificationStep
                    ? _buildVerificationStep() // 5. 위젯 빌더 함수 분리
                    : _buildPhoneInputStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 휴대폰 번호 입력 UI 빌더
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            // 6. 버튼 onPressed 및 로딩 상태 연결
            onPressed: (_isButtonEnabled && !_isLoading) ? _handlePhoneSubmission : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB2F142),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('다음', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 인증번호 입력 UI 빌더
  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey('verify_step'),
      children: [
        VerificationView(
            controller: _codeController,
            // 7. 재발송 버튼에 기능 연결
            onResend: ()  async {
                await _handlePhoneSubmission(); // 인증번호 재요청
                return true; // VerificationView의 타이머를 리셋하라는 신호
            },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            // 8. 버튼 onPressed 및 로딩 상태 연결
            onPressed: (_isButtonEnabled && !_isLoading) ? _handleCodeVerification : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB2F142),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('인증 번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}