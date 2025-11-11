import 'package:flutter/material.dart';
import 'login_bottom_sheet.dart'; // BottomSheet 위젯 파일
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showButtons = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Image.asset(
                'assets/images/noslogun.png',
                width: 400,
                height: 300,
              ),
              const SizedBox(height: 120),

              AnimatedOpacity(
                opacity: _showButtons ? 1.0 : 0.0,
                // 효과 지속 시간
                duration: const Duration(milliseconds: 200),
                // 버튼 영역
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // 4. BottomSheet를 띄우고 상태 변경
                          setState(() {
                            _showButtons = false; // 버튼 숨기기
                          });

                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) {
                              return const LoginBottomSheet();
                            },
                          ).whenComplete(() {
                            // BottomSheet가 닫히면 다시 버튼 보이기
                            setState(() {
                              _showButtons = true;
                            });
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[600]!, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '로그인',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                           Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB2F142),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }
}