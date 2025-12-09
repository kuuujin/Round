import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'verification_view.dart';
import 'new_password_screen.dart';

class ResetPwScreen extends StatefulWidget {
  const ResetPwScreen({super.key});

  @override
  State<ResetPwScreen> createState() => _ResetPwScreenState();
}

class _ResetPwScreenState extends State<ResetPwScreen> {
  // State
  int _step = 0; // 0: 아이디 입력, 1: 휴대폰 입력
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  // Controllers
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  
  final Dio dio = ApiClient().dio;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB2F142);

  @override
  void initState() {
    super.initState();
    _idController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _idFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  // --- Logic ---

  void _updateButtonState() {
    bool isEnabled = false;
    if (_step == 0) {
      isEnabled = _idController.text.isNotEmpty;
    } else if (_step == 1) {
      isEnabled = _phoneController.text.length == 11;
    }
    
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  void _resetToIdStep() {
    setState(() {
      _step = 0;
      _phoneController.clear();
      _isButtonEnabled = _idController.text.isNotEmpty;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
       FocusScope.of(context).requestFocus(_idFocusNode);
    });
  }

  void _goToPhoneStep() {
    setState(() {
      _step = 1;
      _isButtonEnabled = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  Future<void> _handlePhoneSubmission() async {
    setState(() => _isLoading = true);
    try {
      await dio.post('/reset-pw/send-code', data: {
        'user_id': _idController.text,
        'phone': _phoneController.text,
      });
      
      if (!mounted) return;

      // 인증 번호 입력 화면으로 이동 (데이터 전달)
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => _VerificationScreen(
          userId: _idController.text,
          phone: _phoneController.text,
        ),
      ));

    } on DioException catch (e) {
      String errorMessage = "가입된 아이디가 없거나 휴대폰번호가 일치하지 않습니다.";
      if (e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('알림', style: TextStyle(color: Colors.white)),
          ]),
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

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('비밀번호 재설정', style: TextStyle(fontFamily: 'WantedSans', color:Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
            _buildIdAndPhoneStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdAndPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 아이디 입력
        Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.grey[300])),
        const SizedBox(height: 12),
        const Text('아이디를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
        const SizedBox(height: 30),
        
        TextField(
          controller: _idController,
          focusNode: _idFocusNode,
          readOnly: _step >= 1, // 다음 단계로 넘어가면 수정 불가 (아이콘 눌러야 가능)
          style: TextStyle(color: _step >= 1 ? Colors.grey : Colors.white),
          decoration: _buildInputDecoration(hint: '아이디').copyWith(
            suffixIcon: _step >= 1
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                    onPressed: _resetToIdStep,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 24),

        // 2. 휴대폰 입력 (애니메이션)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Visibility(
            visible: _step >= 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('휴대폰번호를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
                const SizedBox(height: 30),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '휴대폰번호'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // 3. 하단 버튼
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isButtonEnabled && !_isLoading)
                ? (_step == 0 ? _goToPhoneStep : _handlePhoneSubmission)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _lime.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(
                    _step == 0 ? '다음' : '인증번호 전송', 
                    style: const TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)
                  ),
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
    );
  }
}

// ---------------- Internal Widget: Verification Screen ----------------

class _VerificationScreen extends StatefulWidget {
  final String userId;
  final String phone;

  const _VerificationScreen({
    required this.userId,
    required this.phone,
  });

  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen> {
  final _codeController = TextEditingController();
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  final Dio dio = ApiClient().dio;

  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB2F142);

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    final isEnabled = _codeController.text.length == 6;
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  Future<void> _handleCodeVerification() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post('/reset-pw/verify-code', data: {
        'code': _codeController.text,
      });

      final String token = response.data['token'];
      if (!mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => NewPasswordScreen(token: token),
      ));
    } on DioException catch (e) {
      _showErrorDialog(e.response?.data['error'] ?? "인증에 실패했습니다.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _handleResend() async {
    try {
      await dio.post('/reset-pw/send-code', data: {
        'user_id': widget.userId,
        'phone': widget.phone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증번호를 다시 전송했습니다.'), backgroundColor: Colors.green),
        );
      }
      return true;
    } on DioException catch (e) {
      _showErrorDialog(e.response?.data['error'] ?? "전송 실패");
      return false;
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('알림', style: TextStyle(color: Colors.white)),
          ]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('인증번호 입력', style: TextStyle(fontFamily: 'WantedSans', color:Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
            VerificationView(
              controller: _codeController,
              onResend: () async => await _handleResend(),
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
                    : const Text('인증번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}