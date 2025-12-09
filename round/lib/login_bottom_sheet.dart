import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'find_id_screen.dart';
import 'reset_pw_screen.dart';
import 'package:round/user_provider.dart';
import 'package:round/fcm_utils.dart'; // updateServerToken이 있는 파일

class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  // Controllers
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  bool _isLoading = false;
  final Dio dio = ApiClient().dio;

  // Palette
  static const Color _lime = Color(0xFFB2F142);
  static const Color _bg = Color(0xFF3B3B3B);

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await dio.post(
        '/login',
        data: {
          'user_id': _idController.text,
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final userData = response.data['user'];
        final String loggedInUserId = userData['user_id'];

        // 1. 유저 정보 저장 (Provider)
        UserProvider().setUser(
          userData['user_id'], 
          userData['name'], 
          userData['role']
        );
        
        // 2. FCM 토큰 갱신
        await updateServerToken();

        if (!mounted) return;
        Navigator.pop(context); // 바텀 시트 닫기
        Navigator.pushReplacementNamed(context, '/home', arguments: loggedInUserId);

      } else {
         _showErrorDialog(response.data['error'] ?? '아이디 또는 비밀번호가 올바르지 않습니다.');
      }

    } on DioException catch (e) {
      String errorMessage = "로그인 요청에 실패했습니다.";
      if (e.response?.statusCode == 401) {
        errorMessage = "아이디 또는 비밀번호가 올바르지 않습니다.";
      } else if (e.response?.data is Map && e.response?.data['error'] != null) {
        errorMessage = e.response?.data['error'];
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
        backgroundColor: const Color(0xFF333333).withOpacity(0.9),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          SizedBox(width: 10),
          Text('로그인 실패', style: TextStyle(color: Colors.white)),
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
    return Padding(
      // 키보드가 올라올 때 바텀 시트도 같이 올라가도록 패딩 설정
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: _bg.withOpacity(0.95), // 투명도 살짝 낮춤
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 30),

              // 아이디 입력
              _buildTextField(controller: _idController, hint: '아이디 입력'),
              const SizedBox(height: 16),

              // 비밀번호 입력
              _buildTextField(controller: _passwordController, hint: '비밀번호 입력', isPassword: true),
              const SizedBox(height: 30),

              // 로그인 버튼
              _buildLoginButton(),
              const SizedBox(height: 20),

              // 아이디/비밀번호 찾기 링크
              _buildLinks(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime)),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _lime,
          foregroundColor: Colors.black,
          disabledBackgroundColor: _lime.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _textLink('아이디 찾기', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindIdScreen()))),
        const SizedBox(width: 12),
        Text('|', style: TextStyle(color: Colors.white.withOpacity(0.3))),
        const SizedBox(width: 12),
        _textLink('비밀번호 재설정', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPwScreen()))),
      ],
    );
  }

  Widget _textLink(String text, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.white.withOpacity(0.6),
      ),
      onPressed: onTap,
      child: Text(text),
    );
  }
}