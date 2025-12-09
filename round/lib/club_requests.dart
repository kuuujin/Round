import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';

class ClubRequestsScreen extends StatefulWidget {
  final int clubId;
  const ClubRequestsScreen({super.key, required this.clubId});

  @override
  State<ClubRequestsScreen> createState() => _ClubRequestsScreenState();
}

class _ClubRequestsScreenState extends State<ClubRequestsScreen> {
  final Dio dio = ApiClient().dio;
  
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _lime = Color(0xFFB7F34D);

  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/club/requests', queryParameters: {'club_id': widget.clubId});
      if (mounted) {
        setState(() {
          _requests = response.data['requests'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("가입 신청 목록 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processRequest(int reqId, String action) async {
    try {
      await dio.post('/api/club/request/process', data: {
        'request_id': reqId,
        'action': action, // 'APPROVE' or 'REJECT'
      });
      
      if (mounted) {
        _fetchRequests(); // 목록 새로고침
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'APPROVE' ? "승인되었습니다." : "거절되었습니다."),
          backgroundColor: action == 'APPROVE' ? _lime : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint("처리 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("처리 중 오류가 발생했습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("가입 신청 관리", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : _requests.isEmpty 
              ? const Center(child: Text("대기 중인 가입 신청이 없습니다.", style: TextStyle(color: Colors.white54)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildRequestTile(_requests[index]);
                  },
                ),
    );
  }

  Widget _buildRequestTile(dynamic req) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[700],
          backgroundImage: (req['profile_image_url'] != null && req['profile_image_url'].isNotEmpty)
              ? NetworkImage(req['profile_image_url']) 
              : null,
          child: (req['profile_image_url'] == null || req['profile_image_url'].isEmpty) 
              ? const Icon(Icons.person, color: Colors.white) 
              : null,
        ),
        title: Text(req['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(req['created_at'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: _lime, size: 28),
              tooltip: '승인',
              onPressed: () => _processRequest(req['request_id'], 'APPROVE'),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
              tooltip: '거절',
              onPressed: () => _processRequest(req['request_id'], 'REJECT'),
            ),
          ],
        ),
      ),
    );
  }
}