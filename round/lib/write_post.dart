import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';

class WritePostScreen extends StatefulWidget {
  final int clubId; // 어느 동호회에 쓸지 ID 필요
  const WritePostScreen({super.key, required this.clubId});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  final Dio dio = ApiClient().dio;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      FormData formData = FormData.fromMap({
        'club_id': widget.clubId,
        'title': _titleController.text,
        'content': _contentController.text,
      });

      if (_imageFile != null) {
        formData.files.add(MapEntry(
          'post_image',
          await MultipartFile.fromFile(_imageFile!.path, filename: _imageFile!.path.split('/').last),
        ));
      }

      await dio.post('/api/posts', data: formData);
      
      if (!mounted) return;
      Navigator.pop(context, true); // 성공 시 true 반환 (목록 새로고침용)

    } on DioException catch (e) {
      // 에러 처리 (생략)
      print("Upload failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262626),
        title: const Text('글쓰기', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: const Text('등록', style: TextStyle(color: Color(0xFFB7F34D), fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_imageFile != null)
              SizedBox(
                height: 100,
                child: Image.file(_imageFile!),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image, color: Color(0xFFB7F34D)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}