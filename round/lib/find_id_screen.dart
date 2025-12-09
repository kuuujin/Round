import 'dart:async';
import 'package:flutter/material.dart';
import 'package:round/api_client.dart';
import 'package:dio/dio.dart';
import 'verification_view.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  // UI State
  bool _showVerificationStep = false;
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  // Controllers
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final Dio dio = ApiClient().dio;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB2F142);

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
    if (!_showVerificationStep) { // 1단계: 전화번호 입력
      isEnabled = _phoneController.text.length == 11;
    } else { // 2단계: 인증코드 입력
      isEnabled = _codeController.text.length == 6;
    }
    
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  // --- Logic ---

  Future<void> _handlePhoneSubmission() async {
    setState(() => _isLoading = true);
    try {
      await dio.post(
        '/find-id/send-code',
        data: {'phone': _phoneController.text},
      );
      
      if (mounted) {
        setState(() {
          _showVerificationStep = true;
          _isButtonEnabled = false; // 버튼 상태 초기화 (코드 입력 대기)
        });
      }
    } on DioException catch (e) {
      String errorMessage = "요청에 실패했습니다.";
      if (e.response?.statusCode == 404) {
        errorMessage = "가입되지 않은 번호입니다.";
      }
      if (mounted) _showErrorDialog(errorMessage);
    } catch (e) {
      if (mounted) _showErrorDialog("오류가 발생했습니다.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCodeVerification() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post(
        '/find-id/verify-code',
        data: {'code': _codeController.text},
      );
      final userId = response.data['user_id'];
      
      if (mounted) _showFoundIdDialog(userId);

    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? "인증에 실패했습니다.";
      if (mounted) _showErrorDialog(errorMessage);
    } catch (e) {
      if (mounted) _showErrorDialog("오류가 발생했습니다.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('아이디 찾기', style: TextStyle(fontFamily: 'WantedSans', color: Colors.white ,fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: _bg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: _lime, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 40),
            
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showVerificationStep
                  ? _buildVerificationStep()
                  : _buildPhoneInputStep(),
            ),
          ],
        ),
      ),
    );
  }

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
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime, width: 1.5)),
          ),
        ),
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isButtonEnabled && !_isLoading) ? _handlePhoneSubmission : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _lime.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('다음', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey('verify_step'),
      children: [
        VerificationView(
            controller: _codeController,
            onResend: () async {
                // 재발송 로직: 성공 시 true 반환하여 타이머 리셋
                try {
                  await dio.post('/find-id/send-code', data: {'phone': _phoneController.text});
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("인증번호가 재발송되었습니다.")));
                  return true; 
                } catch (e) {
                  if (mounted) _showErrorDialog("재발송 실패: 잠시 후 다시 시도해주세요.");
                  return false;
                }
            },
        ),
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isButtonEnabled && !_isLoading) ? _handleCodeVerification : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _lime.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('인증 번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- Dialogs ---

  void _showFoundIdDialog(String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('아이디 확인', style: TextStyle(color: Colors.white)),
        content: Text('회원님의 아이디는 "$userId" 입니다.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false); // 로그인 화면으로 이동하며 스택 비움
            },
            child: const Text('로그인하러 가기', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
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
            child: const Text('확인', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}