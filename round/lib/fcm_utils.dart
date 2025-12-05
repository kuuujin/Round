// lib/utils/fcm_utils.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:round/api_client.dart';
import 'package:round/user_provider.dart';

// 서버에 내 FCM 토큰을 업데이트하는 함수
Future<void> updateServerToken() async {
  try {
    // 1. 내 ID 확인 (로그인 되어 있어야 함)
    final myId = UserProvider().userId;
    if (myId == null) {
      print("❌ [FCM] 토큰 업데이트 실패: 로그인이 필요합니다.");
      return;
    }

    // 2. 토큰 가져오기
    String? token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    print("📲 [FCM] 토큰 서버 전송 시작: $token (User: $myId)");

    // 3. 서버 API 호출
    final dio = ApiClient().dio;
    await dio.post('/api/update-fcm', data: {
      'user_id': myId, 
      'fcm_token': token,
    });
    print("✅ [FCM] 토큰 서버 저장 완료!");
    
  } catch (e) {
    print("❌ [FCM] 토큰 업데이트 오류: $e");
  }
}