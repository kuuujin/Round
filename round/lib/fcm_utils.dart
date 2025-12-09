import 'package:flutter/foundation.dart'; // debugPrint용
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:round/api_client.dart';
import 'package:round/user_provider.dart';


Future<void> updateServerToken() async {
  try {
    // 1. 내 ID 확인 (로그인 상태 체크)
    final myId = UserProvider().userId;
    if (myId == null || myId.isEmpty) {
      debugPrint("⚠️ [FCM] 토큰 업데이트 건너뜀: 로그인 정보 없음");
      return;
    }

    // 2. FCM 토큰 가져오기
    String? token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint("⚠️ [FCM] 기기 토큰을 가져올 수 없습니다.");
      return;
    }

    // 3. 서버로 전송
    final dio = ApiClient().dio;
    await dio.post('/api/update-fcm', data: {
      'user_id': myId, 
      'fcm_token': token,
    });
    
    debugPrint("✅ [FCM] 서버 토큰 업데이트 완료");

  } catch (e) {
    debugPrint("❌ [FCM] 토큰 업데이트 오류: $e");
  }
}

/// (선택 사항) 토큰이 변경될 때 자동으로 업데이트하는 리스너
void listenToTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final myId = UserProvider().userId;
    if (myId != null && myId.isNotEmpty) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/api/update-fcm', data: {
          'user_id': myId,
          'fcm_token': newToken,
        });
        debugPrint("🔄 [FCM] 토큰 갱신됨 및 서버 전송 완료");
      } catch (e) {
        debugPrint("❌ [FCM] 토큰 갱신 서버 전송 실패: $e");
      }
    }
  });
}