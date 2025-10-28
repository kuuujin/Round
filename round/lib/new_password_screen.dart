import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';

class NewPasswordScreen extends StatefulWidget {
  final String token;

  const NewPasswordScreen({super.key, required this.token});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to rebuild on text change for password match feedback
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _resetPassword() async {
    // Keep form validation
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient().dio.post(
        '/reset-pw/set-new',
        data: {
          'token': widget.token,
          'new_password': _passwordController.text,
        },
      );
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          // Style the success dialog too
          backgroundColor: const Color(0xFF333333),
          title: const Text('성공', style: TextStyle(color: Colors.white)),
          content: const Text('비밀번호가 성공적으로 변경되었습니다.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('로그인하기', style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? "오류가 발생했습니다.";
      _showErrorDialog(errorMessage); // Use the styled error dialog
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add the styled error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Row(children: [ /* ... Icon/Text ... */ ]), // Copy from ResetPwScreen
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [ /* ... OK Button ... */ ]), // Copy from ResetPwScreen
    );
  }

  // --- 👇👇👇 BUILD METHOD UPDATED 👇👇👇 ---
  @override
  Widget build(BuildContext context) {
    final bool passwordsMatch = _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF262626), // 1. Apply background color
      appBar: AppBar( // 2. Apply AppBar style
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('새 비밀번호 설정', style: TextStyle(fontFamily: 'WantedSans', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: const Color(0xFF262626),
        elevation: 0,
      ),
      body: SingleChildScrollView( // 3. Add SingleChildScrollView
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), // 4. Add Padding
          child: Form( // Keep the Form widget
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)), // 5. Add Logo
                const SizedBox(height: 40),

                // --- New Password Field ---
                const Text('새 비밀번호', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField( // Use TextFormField for validation
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '새 비밀번호 입력'), // 6. Use helper
                  validator: (value) => value!.isEmpty ? '비밀번호를 입력하세요.' : null,
                ),
                const SizedBox(height: 24),

                // --- Confirm Password Field ---
                const Text('비밀번호 확인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField( // Use TextFormField for validation
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '비밀번호 재입력'), // 6. Use helper
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                // Password match feedback
                Visibility(
                  visible: _confirmPasswordController.text.isNotEmpty,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      passwordsMatch ? '비밀번호가 일치합니다.' : '비밀번호가 일치하지 않습니다.',
                      style: TextStyle(
                        color: passwordsMatch ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30), // Increased spacing before button

                // --- Submit Button ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom( // 7. Apply button style
                      backgroundColor: const Color(0xFFB2F142),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black) // Style indicator
                        : const Text('비밀번호 변경', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --- 👆👆👆 BUILD METHOD UPDATED 👆👆👆 ---


  // --- 👇👇👇 Add Helper Function 👇👇👇 ---
  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
      // Add error border style if needed
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      // Style for readOnly fields if needed later
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
    );
  }
  // --- 👆👆👆 Add Helper Function 👆👆👆 ---
}