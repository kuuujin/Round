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
  // Controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // State
  bool _isLoading = false;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB2F142); // 혹은 0xFFB7F34D (다른 화면과 통일)

  @override
  void initState() {
    super.initState();
    // 비밀번호 일치 실시간 확인을 위해 리스너 등록
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _resetPassword() async {
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
      _showSuccessDialog();

    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? "오류가 발생했습니다.";
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    // 비밀번호 일치 여부 계산
    final bool isNotEmpty = _passwordController.text.isNotEmpty;
    final bool isMatch = _passwordController.text == _confirmPasswordController.text;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('새 비밀번호 설정', style: TextStyle(fontFamily: 'WantedSans', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: _bg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: _lime, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 40),

                // 1. 새 비밀번호
                const Text('새 비밀번호', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '새 비밀번호 입력'),
                  validator: (value) => value!.isEmpty ? '비밀번호를 입력하세요.' : null,
                ),
                const SizedBox(height: 24),

                // 2. 비밀번호 확인
                const Text('비밀번호 확인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '비밀번호 재입력'),
                  validator: (value) {
                    if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다.';
                    return null;
                  },
                ),
                
                // 3. 일치 여부 피드백 텍스트
                if (_confirmPasswordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4),
                    child: Text(
                      isMatch ? '비밀번호가 일치합니다.' : '비밀번호가 일치하지 않습니다.',
                      style: TextStyle(
                        color: isMatch ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // 4. 변경 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (isNotEmpty && isMatch && !_isLoading) ? _resetPassword : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _lime.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
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

  // --- Helpers ---

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lime, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('성공', style: TextStyle(color: Colors.white)),
        content: const Text('비밀번호가 성공적으로 변경되었습니다.\n다시 로그인해주세요.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 로그인 화면으로 이동하며 스택 비우기
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('로그인하러 가기', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
}