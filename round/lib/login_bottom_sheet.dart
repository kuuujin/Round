import 'package:flutter/material.dart';
import 'find_id_screen.dart';
import 'reset_pw_screen.dart';

class LoginBottomSheet extends StatelessWidget {
  const LoginBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        child: Column(
          mainAxisSize: MainAxisSize.min, // 컨텐츠 크기만큼만 높이를 차지
          children: [
            // 손잡이 모양
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 30),
            
            // 아이디 입력 필드
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '아이디 입력',
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

            // 비밀번호 입력 필드
            TextField(
              obscureText: true, // 비밀번호 가리기
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '비밀번호 입력',
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
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB2F142), // 버튼 배경색
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // 아이디 찾기, 비밀번호 재설정
            Row(
  mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}