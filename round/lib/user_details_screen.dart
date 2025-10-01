import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class UserDetailsScreen extends StatefulWidget  {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  // ## 2. 선택된 이미지 파일을 저장할 변수 선언 ##
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('회원가입', style: TextStyle(fontFamily: 'WantedSans', fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 40),
                      Text(
                        '몇 가지 정보만 입력하면,\n바로 시작할 수 있어요.',
                        style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 22, color: Colors.grey[300]),
                      ),
                      const SizedBox(height: 40),

                      // 아이디, 비밀번호 등 입력 필드
                      _buildTextFieldSection(label: '아이디', hint: '아이디 입력'),
                      const SizedBox(height: 24),
                      _buildTextFieldSection(label: '비밀번호 입력', hint: '비밀번호 입력', isPassword: true),
                      const SizedBox(height: 24),
                      _buildTextFieldSection(label: '비밀번호 확인', hint: '비밀번호 재입력', isPassword: true),
                      const SizedBox(height: 24),
                      
                      // 프로필 사진
                      const Text('프로필 사진', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickImage, // 탭하면 _pickImage 함수 호출
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            // _profileImage 유무에 따라 다른 위젯을 표시
                            child: _profileImage == null
                                ? _buildPlaceholder() // 이미지가 없을 때: 플레이스홀더
                                : _buildProfileImage(), // 이미지가 있을 때: 선택된 이미지
                          ),
                        ),
                      ),
                      
                      const Spacer(), // 가입 버튼을 하단으로 밀어냄
                      const SizedBox(height: 24),

                      // 가입 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: 회원가입 완료 로직 구현
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB2F142),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('가입', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage() {
    return CircleAvatar(
      radius: 60,
      backgroundImage: FileImage(_profileImage!),
    );
  }

  // 기본 플레이스홀더 UI
  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.8),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 40),
    );
  }

  // 반복되는 텍스트 필드 UI를 위한 Helper 함수
  Widget _buildTextFieldSection({required String label, required String hint, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}