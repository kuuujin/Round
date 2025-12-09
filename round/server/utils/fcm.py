from firebase_admin import messaging
from flask import current_app
from utils.db import get_db_connection

# ==========================================
# 1. FCM 기본 발송 함수 (Generic)
# ==========================================

def send_fcm_notification(token, title, body, data=None):
    """
    단일 기기에 FCM 알림을 전송하는 기본 함수
    """
    if not token: 
        return None
    
    try:
        # 메시지 구성
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data, # 클라이언트에서 사용할 데이터 (Map<String, String>)
            token=token,
        )
        
        response = messaging.send(message)
        current_app.logger.info(f"FCM sent successfully: {response}")
        return response

    except Exception as e:
        current_app.logger.error(f"FCM send error: {e}")
        return None


# ==========================================
# 2. 비즈니스 로직별 알림 함수 (Specific)
# ==========================================

def send_match_notification(target_club_id, room_id, title_text):
    """
    매칭 성사 시 상대방 클럽 운영진(생성자)에게 알림 발송
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if conn is None:
            current_app.logger.error("DB connection failed in send_match_notification")
            return

        cursor = conn.cursor(dictionary=True)
        
        # 1. 대상(상대 클럽 운영진)의 토큰 조회
        sql = """
            SELECT U.fcm_token, C.name as club_name
            FROM Clubs C
            JOIN Users U ON C.creator_id = U.id
            WHERE C.id = %s
        """
        cursor.execute(sql, (target_club_id,))
        target_user = cursor.fetchone()
        
        if target_user and target_user['fcm_token']:
            token = target_user['fcm_token']
            club_name = target_user['club_name']
            
            # 2. 클라이언트 이동을 위한 데이터 페이로드 구성
            data_payload = {
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "type": "MATCH_FOUND",
                "match_id": room_id,     # 채팅방 UUID
                "opponent_name": "상대팀" # (필요시 DB에서 조회하여 변경 가능)
            }
            
            # 3. 발송
            current_app.logger.info(f"Sending Match FCM to {club_name} (Token: {token[:10]}...)")
            
            send_fcm_notification(
                token=token,
                title=title_text, 
                body="새로운 매칭이 시작되었습니다. 터치하여 확인하세요.",
                data=data_payload
            )
        else:
            current_app.logger.warning(f"Target club {target_club_id} has no admin token or user not found.")
            
    except Exception as e:
        current_app.logger.error(f"Error sending match notification: {e}")
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()