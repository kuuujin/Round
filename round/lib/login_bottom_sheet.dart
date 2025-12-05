import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // Import Dio
import 'package:round/api_client.dart'; // Import ApiClient
import 'find_id_screen.dart';
import 'reset_pw_screen.dart';
import 'package:round/user_provider.dart';
import 'package:round/fcm_utils.dart';

class LoginBottomSheet extends StatefulWidget { // Changed to StatefulWidget
  const LoginBottomSheet({super.key});

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> { // New State class
  // 1. Add Controllers
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  // 2. Add State variables
  bool _isLoading = false;
  final Dio dio = ApiClient().dio; // Get Dio instance

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 3. Login Logic Implementation
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
        // Login Successful
        final userData = response.data['user'];
        final String loggedInUserId = userData['user_id'];

        UserProvider().setUser(
          userData['user_id'], 
          userData['name'], 
          userData['role']
        );
        await updateServerToken();

        if (!mounted) return;
        Navigator.pop(context); // Close the bottom sheet

        Navigator.pushReplacementNamed(context, '/home', arguments: loggedInUserId,);

      } else {
         // Handle cases where API returns success: false but status 200 (should ideally be 401)
         _showErrorDialog(response.data['error'] ?? '아이디 또는 비밀번호가 올바르지 않습니다.');
      }

    } on DioException catch (e) {
      String errorMessage = "로그인 요청에 실패했습니다.";
      if (e.response?.statusCode == 401) { // Unauthorized
        errorMessage = "아이디 또는 비밀번호가 올바르지 않습니다.";
      } else if (e.response?.data is Map && e.response?.data['error'] != null) {
        errorMessage = e.response?.data['error'];
      }
      _showErrorDialog(errorMessage);
    } finally {
      // Ensure loading state is turned off even if widget is disposed during async call
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 4. Error Dialog (similar to other screens)
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333).withOpacity(0.8),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          SizedBox(width: 10),
          Text('로그인 실패', style: TextStyle(color: Colors.white)),
        ]),
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
    return Padding(
      // Keep keyboard visibility handling
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3B3B).withOpacity(0.4),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for bottom sheet
          children: [
            // Handle
            Container(width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),),
            const SizedBox(height: 30),

            // ID Field - Attach Controller
            TextField(
              controller: _idController, // Attach controller
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: '아이디 입력',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1), // 필드 내부 색상
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB2F142)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password Field - Attach Controller
            TextField(
              controller: _passwordController, // Attach controller
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: '비밀번호 입력',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                ),
                 focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB2F142)),
                ),),
            ),
            const SizedBox(height: 30),

            // Login Button - Connect Logic and Loading State
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Disable button when loading, call _handleLogin when pressed
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFFB2F142), // 버튼 배경색
                   foregroundColor: Colors.black,
                  // Disable color slightly faded
                  disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Show indicator when loading, otherwise show text
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                    : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            // Find ID / Reset PW Row (Keep navigation as is)
            Row(mainAxisAlignment: MainAxisAlignment.center,
  children: [
    TextButton(
      style: TextButton.styleFrom(
        // 버튼의 기본 패딩을 제거하여 텍스트처럼 보이게 함
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FindIdScreen()),
        );
      },
      child: Text('아이디 찾기', style: TextStyle(color: Colors.white.withOpacity(0.6))),
    ),
    const SizedBox(width: 12),
    Text('|', style: TextStyle(color: Colors.white.withOpacity(0.3))),
    const SizedBox(width: 12),
    TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ResetPwScreen()),
        );
      },
      child: Text('비밀번호 재설정', style: TextStyle(color: Colors.white.withOpacity(0.6))),
    ),
  ],
),
            const SizedBox(height: 50),
          ],
        ),
      ),
    ),
    );
  }
}
