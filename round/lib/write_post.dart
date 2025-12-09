import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';

class WritePostScreen extends StatefulWidget {
  final int clubId;
  const WritePostScreen({super.key, required this.clubId});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  // Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  // State
  File? _imageFile;
  bool _isLoading = false;
  
  final Dio dio = ApiClient().dio;
  final ImagePicker _picker = ImagePicker();

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _hint = Colors.white54;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _removeImage() {
    setState(() => _imageFile = null);
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      FormData formData = FormData.fromMap({
        'club_id': widget.clubId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
      });

      if (_imageFile != null) {
        formData.files.add(MapEntry(
          'post_image',
          await MultipartFile.fromFile(_imageFile!.path, filename: _imageFile!.path.split('/').last),
        ));
      }

      await dio.post('/api/posts', data: formData);
      
      if (!mounted) return;
      Navigator.pop(context, true); // 성공 시 true 반환

    } on DioException catch (e) {
      debugPrint("Upload failed: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글 등록에 실패했습니다.')),
        );
      }
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
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('글쓰기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _lime, strokeWidth: 2))
                : const Text('등록', style: TextStyle(color: _lime, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 제목 입력
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                hintStyle: TextStyle(color: _hint, fontSize: 20, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
            ),
            const Divider(color: Colors.grey),
            
            // 내용 입력
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: null, // 무제한 줄
                expands: true,  // 남은 공간 채우기
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요.\n(동호회 활동과 관련 없는 내용은 삭제될 수 있습니다.)',
                  hintStyle: TextStyle(color: _hint, height: 1.5),
                  border: InputBorder.none,
                ),
              ),
            ),

            // 이미지 미리보기 영역
            if (_imageFile != null)
              Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 하단 툴바 (이미지 추가 버튼)
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, color: _lime, size: 28),
                  tooltip: '사진 추가',
                ),
                const Text("사진 추가", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}