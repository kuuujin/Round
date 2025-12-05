from flask import Blueprint, request, jsonify, session, current_app
from utils.db import get_db_connection
from extensions import socketio  # 👈 extensions에서 가져옵니다!
from utils.fcm import send_fcm_notification # 👈 utils에서 가져옵니다!
import mysql.connector

match_bp = Blueprint('match', __name__)

@match_bp.route("/api/update-fcm", methods=["POST"])
def update_fcm():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        token = data.get('fcm_token')

        if not user_id or not token:
            return jsonify({"success": False}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # User ID로 찾아서 fcm_token 업데이트
        cursor.execute("UPDATE Users SET fcm_token = %s WHERE user_id = %s", (token, user_id))
        conn.commit()
        
        print(f"✅ FCM Token Updated for {user_id}")
        
        cursor.close()
        conn.close()
        return jsonify({"success": True}), 200
    except Exception as e:
        print(f"Error updating token: {e}")
        return jsonify({"success": False}), 500

@match_bp.route("/api/match/request", methods=["POST"])
def request_match_http():
    db_connection = None
    cursor = None
    try:
        # 1. 세션 검증 (클라이언트 데이터보다 세션을 신뢰해야 함)
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401
            
        user_id_str = session['user_id'] # 세션에서 가져온 문자열 ID
        
        data = request.get_json()
        club_id = data.get('club_id')
        pref_day = data.get('preferred_day', 'ANY')
        pref_time = data.get('preferred_time', 'ANY')
        client_socket_id = data.get('socket_id')
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # 2. 내 정보(User DB ID, FCM 토큰) 및 클럽 정보 미리 조회
        #    (나중에 알림 보낼 때 또 조회하지 않도록 여기서 한 번에!)
        cursor.execute("SELECT id, fcm_token FROM Users WHERE user_id = %s", (user_id_str,))
        my_user_row = cursor.fetchone()
        if not my_user_row:
             return jsonify({"success": False, "error": "사용자 정보 오류"}), 404
             
        my_db_id = my_user_row['id']
        my_fcm_token = my_user_row['fcm_token']

        # 3. 내 클럽 정보 조회
        cursor.execute("SELECT sport, sido, sigungu, point, name FROM Clubs WHERE id = %s", (club_id,))
        my_club = cursor.fetchone()
        if not my_club:
            return jsonify({"success": False, "error": "내 동호회 정보를 찾을 수 없습니다."}), 404

        # 4. 매칭 상대 검색
        sql_search = """
            SELECT id, club_id FROM MatchQueue 
            WHERE sport = %s 
              AND sido = %s 
              AND status = 'WAITING' 
              AND club_id != %s
              AND ABS(point - %s) <= 200
              AND ( %s = 'ANY' OR preferred_day = 'ANY' OR preferred_day = %s )
              AND ( %s = 'ANY' OR preferred_time = 'ANY' OR preferred_time = %s )
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
            match_room_id = f"match_{min(club_id, opponent_club_id)}_{max(club_id, opponent_club_id)}"

            # 상대방 클럽 정보 및 생성자(Creator) 토큰 조회
            cursor.execute("""
                SELECT C.name, U.fcm_token, U.user_id 
                FROM Clubs C 
                JOIN Users U ON C.creator_id = U.id 
                WHERE C.id = %s
            """, (opponent_club_id,))
            opponent_info = cursor.fetchone()
            
            opponent_club_name = opponent_info['name'] if opponent_info else "상대팀"
            opponent_fcm_token = opponent_info['fcm_token'] if opponent_info else None

            # [DB 업데이트]
            # 1. 내 기록 INSERT (MATCHED)
            sql_insert = """INSERT INTO MatchQueue (club_id, sport, sido, sigungu, point, status, matched_club_id, socket_id)
                            VALUES (%s, %s, %s, %s, %s, 'MATCHED', %s, %s)"""
            val_insert = (club_id, my_club['sport'], my_club['sido'], my_club['sigungu'], my_club['point'], opponent_club_id, client_socket_id)
            cursor.execute(sql_insert, val_insert)
            
            # 2. 상대방 기록 UPDATE (MATCHED)
            sql_update = "UPDATE MatchQueue SET status = 'MATCHED', matched_club_id = %s WHERE id = %s"
            cursor.execute(sql_update, (club_id, opponent_queue_id))
            
            db_connection.commit()

            # [알림 발송]
            noti_data = {
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "type": "MATCH_FOUND",
                "match_id": match_room_id,
                "opponent_name": opponent_club_name
            }
            noti_data_for_opponent = {
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "type": "MATCH_FOUND",
                "match_id": match_room_id,
                "opponent_name": my_club['name']
            }

            # 상대방에게 알림
            if opponent_fcm_token:
                print(f"🚀 Sending FCM to Opponent: {opponent_fcm_token[:20]}...")
                send_fcm_notification(opponent_fcm_token, "매칭 성공! 🎉", f"{my_club['name']}팀과 매칭되었습니다!", noti_data_for_opponent)
            
            # 나에게 알림 (내 토큰은 위에서 이미 조회했음)
            if my_fcm_token:
                send_fcm_notification(my_fcm_token, "매칭 성공! 🎉", f"{opponent_club_name}팀과 매칭되었습니다!", noti_data)

            return jsonify({
                "success": True, 
                "status": "MATCHED", 
                "opponent_name": opponent_club_name,
                "message": "매칭이 성사되었습니다!",
                "match_id": match_room_id 
            }), 200

        else:
            # --- ⏳ 대기열 등록 ---
            sql_insert = """INSERT INTO MatchQueue (club_id, sport, sido, sigungu, point, status, preferred_day, preferred_time, socket_id)
                            VALUES (%s, %s, %s, %s, %s, 'WAITING', %s, %s, %s)"""
            val_insert = (club_id, my_club['sport'], my_club['sido'], my_club['sigungu'], my_club['point'], pref_day, pref_time, client_socket_id)            
            cursor.execute(sql_insert, val_insert)
            db_connection.commit()
            
            return jsonify({
                "success": True, 
                "status": "WAITING", 
                "message": "매칭 대기열에 등록되었습니다."
            }), 200

    except mysql.connector.Error as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"DB Error: {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"Server Error: {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@match_bp.route("/api/chat/history", methods=["GET"])
def get_chat_history():
    db_connection = None
    try:
        match_id = request.args.get('match_id')
        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)
        
        sql = """
            SELECT CM.message, U.user_id as sender_id, 
                   DATE_FORMAT(CM.created_at, '%%H:%%i') as time
            FROM ChatMessages CM
            JOIN Users U ON CM.user_id = U.id
            WHERE CM.match_id = %s
            ORDER BY CM.created_at ASC
        """
        cursor.execute(sql, (match_id,))
        messages = cursor.fetchall()
        
        return jsonify({"success": True, "messages": messages}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if db_connection: db_connection.close()

@match_bp.route("/api/my-matches", methods=["GET"])
def get_my_matches():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
             return jsonify({"success": False, "error": "로그인 필요"}), 401
             
        user_id_str = session['user_id']
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True, buffered=True)

        # 1. 내 User ID(숫자) 찾기
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
        user_row = cursor.fetchone()
        if not user_row:
            return jsonify({"success": False, "error": "사용자 정보 없음"}), 404
        user_db_id = user_row['id']

        # 👇👇👇 [수정] 내가 가입한 '모든' 동호회 ID 리스트 가져오기 👇👇👇
        cursor.execute("SELECT club_id FROM ClubMembers WHERE user_id = %s", (user_db_id,))
        my_club_rows = cursor.fetchall()
        
        if not my_club_rows:
             return jsonify({"success": True, "matches": []}), 200

        # ID 리스트 만들기 (예: [1, 9])
        my_club_ids = [row['club_id'] for row in my_club_rows]
        
        # SQL 파라미터 포맷팅 (IN 절 사용)
        format_strings = ','.join(['%s'] * len(my_club_ids)) 

        # 2. 매칭 목록 조회 (IN 절을 사용하여 내 모든 동호회의 매칭을 찾음)
        #    쿼리가 조금 복잡하지만, 내 클럽 ID들이 포함된 모든 매칭을 찾습니다.
        sql = f"""
            SELECT 
                MQ.id, MQ.sport, MQ.sido, MQ.sigungu, MQ.status,
                C.name as opponent_name, 
                C.club_image_url as opponent_image,
                CASE 
                    WHEN MQ.club_id < MQ.matched_club_id THEN CONCAT('match_', MQ.club_id, '_', MQ.matched_club_id)
                    ELSE CONCAT('match_', MQ.matched_club_id, '_', MQ.club_id)
                END as match_id
            FROM MatchQueue MQ
            -- 상대방 클럽(C) 정보 찾기
            -- (만약 MQ.club_id가 '내꺼' 중에 있으면 -> 상대는 matched_club_id)
            -- (만약 MQ.matched_club_id가 '내꺼' 중에 있으면 -> 상대는 club_id)
            JOIN Clubs C ON C.id = (
                CASE 
                    WHEN MQ.club_id IN ({format_strings}) THEN MQ.matched_club_id 
                    ELSE MQ.club_id 
                END
            )
            WHERE (MQ.club_id IN ({format_strings}) OR MQ.matched_club_id IN ({format_strings}))
              AND MQ.status = 'MATCHED'
            ORDER BY MQ.created_at DESC
        """
        
        # 파라미터를 3번 반복해서 넣어줘야 함 (JOIN CASE문, WHERE OR문 2개)
        params = my_club_ids + my_club_ids + my_club_ids
        
        cursor.execute(sql, tuple(params))
        rows = cursor.fetchall()
        # 👆👆👆 ----------------------------------------------------- 👆👆👆

        # 3. 중복 제거 (동일)
        unique_matches = {}
        for row in rows:
            m_id = row['match_id']
            if m_id not in unique_matches:
                unique_matches[m_id] = row
        
        final_matches = list(unique_matches.values())

        return jsonify({"success": True, "matches": final_matches}), 200
    
    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_my_matches): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    except Exception as e:
        current_app.logger.error(f"Server Error (get_my_matches): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@match_bp.route("/api/match/schedule", methods=["POST"])
def update_match_schedule():
    conn = None
    try:
        data = request.get_json()
        match_id_str = data.get('match_id')     # 예: "match_1_9"
        schedule_date = data.get('schedule_date') # "2025-12-05 14:00:00"
        location = data.get('location')

        if not match_id_str or not match_id_str.startswith("match_"):
            return jsonify({"success": False, "error": "Invalid match_id format"}), 400

        # 1. ID 파싱
        ids = match_id_str.replace("match_", "").split("_")
        club_a_id = int(ids[0])
        club_b_id = int(ids[1])

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) # 딕셔너리 커서 사용

        # 2. MatchQueue 테이블 업데이트 (기존 로직)
        sql_update = """
            UPDATE MatchQueue 
            SET schedule_date = %s, location = %s 
            WHERE status = 'MATCHED'
              AND (
                  (club_id = %s AND matched_club_id = %s)
                  OR
                  (club_id = %s AND matched_club_id = %s)
              )
        """
        cursor.execute(sql_update, (schedule_date, location, club_a_id, club_b_id, club_b_id, club_a_id))

        # === 👇👇👇 [추가] Schedules 테이블 INSERT 로직 👇👇👇 ===
        
        # 3. 두 클럽의 정보(이름, 생성자ID) 조회
        # Schedules 테이블의 user_id(작성자)는 동호회 생성자(creator_id)로 지정
        cursor.execute("SELECT id, name, creator_id FROM Clubs WHERE id IN (%s, %s)", (club_a_id, club_b_id))
        clubs_info = cursor.fetchall()
        
        # ID로 쉽게 찾기 위해 매핑
        club_map = {c['id']: c for c in clubs_info}
        club_a = club_map.get(club_a_id)
        club_b = club_map.get(club_b_id)

        if club_a and club_b:
            sql_insert = """
                INSERT INTO Schedules 
                (club_id, user_id, title, location, schedule_date, is_match, opponent_name, max_participants, current_participants, description)
                VALUES (%s, %s, %s, %s, %s, 1, %s, 30, 0, '매칭 확정 일정')
            """

            # (1) Club A의 일정 추가 (상대는 B)
            title_a = f"VS {club_b['name']}"
            cursor.execute(sql_insert, (
                club_a['id'], club_a['creator_id'], title_a, location, schedule_date, club_b['name']
            ))

            # (2) Club B의 일정 추가 (상대는 A)
            title_b = f"VS {club_a['name']}"
            cursor.execute(sql_insert, (
                club_b['id'], club_b['creator_id'], title_b, location, schedule_date, club_a['name']
            ))
            
            print(f"✅ Schedules 테이블에 일정 2개 추가 완료 ({title_a}, {title_b})")
        
        conn.commit()
        
        return jsonify({"success": True, "message": "Schedule updated and inserted"}), 200

    except Exception as e:
        print(f"Error updating schedule: {e}")
        if conn: conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()