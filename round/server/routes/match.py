from flask import Blueprint, request, jsonify, session, current_app
from utils.db import get_db_connection
from extensions import socketio  # 👈 extensions에서 가져옵니다!
from utils.fcm import send_fcm_notification # 👈 utils에서 가져옵니다!
import mysql.connector

match_bp = Blueprint('match', __name__)

@match_bp.route("/api/match/request", methods=["POST"])
def request_match_http():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        user_id = data.get('user_id') # (필요하다면 세션에서 가져와도 됨)
        club_id = data.get('club_id')
        pref_day = data.get('preferred_day', 'ANY')
        pref_time = data.get('preferred_time', 'ANY')
        
        # (선택사항) 클라이언트가 socket_id를 함께 보냈다면 받아서 저장
        # socket_id = data.get('socket_id') 

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # 2. 내 클럽 정보 조회
        cursor.execute("SELECT sport, sido, sigungu, point, name FROM Clubs WHERE id = %s", (club_id,))
        my_club = cursor.fetchone()
        
        if not my_club:
            return jsonify({"success": False, "error": "내 동호회 정보를 찾을 수 없습니다."}), 404

        # 3. 매칭 상대 검색 (SQL 동일)
        sql_search = """
            SELECT id, club_id FROM MatchQueue 
            WHERE sport = %s 
              AND sido = %s 
              AND status = 'WAITING' 
              AND club_id != %s
              AND ABS(point - %s) <= 200
              AND (
                  %s = 'ANY' OR preferred_day = 'ANY' OR preferred_day = %s
              )
              AND (
                  %s = 'ANY' OR preferred_time = 'ANY' OR preferred_time = %s
              )
            LIMIT 1
        """
        search_params = (
            my_club['sport'], my_club['sido'], club_id, my_club['point'],
            pref_day, pref_day,
            pref_time, pref_time
        )
        cursor.execute(sql_search, search_params)
        opponent = cursor.fetchone()

        if opponent:
            # --- 🎉 매칭 성공! ---
            opponent_queue_id = opponent['id']
            opponent_club_id = opponent['club_id']

            # 상대방 클럽 정보 조회 (이름, FCM 토큰)
            cursor.execute("""
                SELECT C.name, U.fcm_token, U.user_id 
                FROM Clubs C 
                JOIN Users U ON C.creator_id = U.id 
                WHERE C.id = %s
            """, (opponent_club_id,))
            opponent_info = cursor.fetchone()
            opponent_club_name = opponent_info['name']
            opponent_fcm_token = opponent_info['fcm_token']

            # 내 FCM 토큰 조회
            cursor.execute("SELECT fcm_token FROM Users WHERE user_id = %s", (user_id,))
            my_token_row = cursor.fetchone()
            my_fcm_token = my_token_row['fcm_token'] if my_token_row else None

            # DB 업데이트 (상태 MATCHED)
            # 내 기록 저장 (socket_id는 HTTP 요청이라 없을 수 있으므로 NULL 허용하거나 생략)
            sql_insert = """INSERT INTO MatchQueue (club_id, sport, sido, sigungu, point, status, matched_club_id)
                            VALUES (%s, %s, %s, %s, %s, 'MATCHED', %s)"""
            val_insert = (club_id, my_club['sport'], my_club['sido'], my_club['sigungu'], my_club['point'], opponent_club_id)
            cursor.execute(sql_insert, val_insert)
            
            # 상대방 기록 업데이트
            sql_update = "UPDATE MatchQueue SET status = 'MATCHED', matched_club_id = %s WHERE id = %s"
            cursor.execute(sql_update, (club_id, opponent_queue_id))
            
            db_connection.commit()
            match_room_id = f"match_{min(club_id, opponent_club_id)}_{max(club_id, opponent_club_id)}"

            # --- 알림 발송 ---
            
            # 1. FCM 발송 (상대방 & 나)
            if opponent_fcm_token:
                send_fcm_notification(opponent_fcm_token, "매칭 성공! 🎉", f"상대 팀 [{my_club['name']}]을 찾았습니다!")
            if my_fcm_token:
                send_fcm_notification(my_fcm_token, "매칭 성공! 🎉", f"상대 팀 [{opponent_club_name}]을 찾았습니다!")

            # 2. Socket 알림 (혹시 상대가 앱을 켜놓고 있다면)
            # (상대방이 socket room에 조인해 있다면 broadcast 가능. 여기서는 생략하거나 전체 broadcast)
            target_room = f"user_{opponent_info['user_id']}"
            
            current_app.logger.info(f"-------- SOCKET EMIT DEBUG --------")
            current_app.logger.info(f"Target User ID: {opponent_info['user_id']}")
            current_app.logger.info(f"Target Room: {target_room}")
            current_app.logger.info(f"Message Data: match_id={match_room_id}")
            current_app.logger.info(f"-----------------------------------")

            socketio.emit('match_found', {
                "opponent_name": my_club['name'],
                "match_id": match_room_id 
            }, room=target_room, namespace='/')

            # 3. HTTP 응답 (나에게)
            # 👇👇👇 [수정] match_id를 함께 반환 👇👇👇
            return jsonify({
                "success": True, 
                "status": "MATCHED", 
                "opponent_name": opponent_club_name,
                "message": "매칭이 성사되었습니다!",
                "match_id": match_room_id 
            }), 200

        else:
            # --- ⏳ 대기열 등록 ---
            sql_insert = """INSERT INTO MatchQueue (club_id, sport, sido, sigungu, point, status, preferred_day, preferred_time)
                            VALUES (%s, %s, %s, %s, %s, 'WAITING', %s, %s)"""
            val_insert = (club_id, my_club['sport'], my_club['sido'], my_club['sigungu'], my_club['point'], pref_day, pref_time)
            
            cursor.execute(sql_insert, val_insert)
            db_connection.commit()
            
            return jsonify({
                "success": True, 
                "status": "WAITING", 
                "message": "매칭 대기열에 등록되었습니다. 상대를 찾으면 알림을 보내드립니다."
            }), 200

    except mysql.connector.Error as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"DB Error (match request): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"Server Error (match request): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()