from flask import Blueprint, request, jsonify, session, current_app
from utils.db import get_db_connection
from extensions import socketio
from utils.fcm import send_match_notification
from utils.elo import calculate_new_ratings
import mysql.connector
import uuid

match_bp = Blueprint('match', __name__)

# ==========================================
# 1. FCM 토큰 관리 (FCM Token Update)
# ==========================================

@match_bp.route("/api/update-fcm", methods=["POST"])
def update_fcm():
    conn = None
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        token = data.get('fcm_token')

        if not user_id or not token:
            return jsonify({"success": False}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("UPDATE Users SET fcm_token = %s WHERE user_id = %s", (token, user_id))
        conn.commit()
        
        return jsonify({"success": True}), 200
    except Exception as e:
        current_app.logger.error(f"Error updating FCM token: {e}")
        return jsonify({"success": False}), 500
    finally:
        if conn: conn.close()


# ==========================================
# 2. 매칭 요청 및 목록 조회 (Request & List)
# ==========================================

@match_bp.route("/api/match/request", methods=["POST"])
def request_match():
    conn = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401

        data = request.get_json()
        my_club_id = data.get('club_id')
        sport = data.get('sport')
        sido = data.get('sido')
        sigungu = data.get('sigungu')
        
        # ENUM 값 검증 및 대문자 변환 (DB 저장 오류 방지)
        raw_day = str(data.get('preferred_day', 'ANY')).upper()
        raw_time = str(data.get('preferred_time', 'ANY')).upper()
        socket_id = data.get('socket_id')

        valid_days = ['WEEKDAY', 'WEEKEND', 'ANY']
        valid_times = ['MORNING', 'AFTERNOON', 'EVENING', 'ANY']
        
        pref_day = raw_day if raw_day in valid_days else 'ANY'
        pref_time = raw_time if raw_time in valid_times else 'ANY'

        user_id_str = session['user_id']
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # 1. 요청자 권한 확인 (운영진만 가능)
        cursor.execute("""
            SELECT role FROM ClubMembers 
            WHERE club_id = %s AND user_id = (SELECT id FROM Users WHERE user_id = %s)
        """, (my_club_id, user_id_str))
        member_row = cursor.fetchone()
        
        if not member_row:
            return jsonify({"success": False, "error": "Not a member"}), 403
        if member_row['role'] not in ['ADMIN', 'admin']:
            return jsonify({"success": False, "error": "Only admins can request match"}), 403

        # 2. 대기 중인 상대 찾기 (FIFO: 먼저 등록한 팀 우선)
        # 조건: 종목, 지역 일치 / 상태 WAITING / 내 클럽 제외
        sql_find = """
            SELECT id, club_id FROM MatchQueue 
            WHERE sport = %s 
              AND sido = %s 
              AND status = 'WAITING' 
              AND club_id != %s
            ORDER BY created_at ASC 
            LIMIT 1
        """
        cursor.execute(sql_find, (sport, sido, my_club_id))
        opponent = cursor.fetchone()

        if opponent:
            # === 매칭 성사 ===
            opponent_mq_id = opponent['id']
            opponent_club_id = opponent['club_id']
            
            # 고유 Room ID 생성 (채팅방 구분용 UUID)
            new_room_id = f"room_{uuid.uuid4()}"
            
            # (1) 상대방 상태 업데이트 (MATCHED & room_id 할당)
            update_op = """
                UPDATE MatchQueue 
                SET status = 'MATCHED', matched_club_id = %s, room_id = %s
                WHERE id = %s
            """
            cursor.execute(update_op, (my_club_id, new_room_id, opponent_mq_id))
            
            # (2) 나도 MATCHED 상태로 등록 (상세 정보 포함)
            insert_me = """
                INSERT INTO MatchQueue 
                (club_id, sport, sido, sigungu, point, status, matched_club_id, room_id, preferred_day, preferred_time, socket_id)
                VALUES (%s, %s, %s, %s, 1000, 'MATCHED', %s, %s, %s, %s, %s)
            """
            cursor.execute(insert_me, (
                my_club_id, sport, sido, sigungu, opponent_club_id, new_room_id, pref_day, pref_time, socket_id
            ))
            
            conn.commit()
            
            # (3) 상대방 알림 발송
            try:
                send_match_notification(opponent_club_id, new_room_id, "매칭 성사!")
            except Exception as e:
                current_app.logger.error(f"FCM Error: {e}")
            
            return jsonify({
                "success": True, 
                "status": "MATCHED", 
                "match_id": new_room_id, 
                "message": "매칭이 성사되었습니다!"
            }), 200

        else:
            # === 대기열 등록 (Waiting) ===
            # 중복 등록 방지
            cursor.execute("SELECT id FROM MatchQueue WHERE club_id=%s AND status='WAITING'", (my_club_id,))
            if cursor.fetchone():
                return jsonify({"success": False, "message": "이미 매칭 대기 중입니다."}), 400

            sql_wait = """
                INSERT INTO MatchQueue (club_id, sport, sido, sigungu, point, status, preferred_day, preferred_time, socket_id)
                VALUES (%s, %s, %s, %s, 1000, 'WAITING', %s, %s, %s)
            """
            cursor.execute(sql_wait, (my_club_id, sport, sido, sigungu, pref_day, pref_time, socket_id))
            conn.commit()
            
            return jsonify({"success": True, "status": "WAITING", "message": "매칭 대기열에 등록되었습니다."}), 200

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Match Request Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


@match_bp.route("/api/my-matches", methods=["GET"])
def get_my_matches():
    conn = None
    try:
        if 'user_id' not in session:
             return jsonify({"success": False, "error": "로그인 필요"}), 401
             
        user_id_str = session['user_id']
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        # 1. 유저 ID 및 가입된 클럽 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
        user_row = cursor.fetchone()
        if not user_row:
            return jsonify({"success": False, "error": "사용자 정보 없음"}), 404
        user_db_id = user_row['id']

        cursor.execute("SELECT club_id FROM ClubMembers WHERE user_id = %s", (user_db_id,))
        my_club_rows = cursor.fetchall()
        
        if not my_club_rows:
             return jsonify({"success": True, "matches": []}), 200

        my_club_ids = [row['club_id'] for row in my_club_rows]
        format_strings = ','.join(['%s'] * len(my_club_ids)) 

        # 2. 매칭 목록 조회
        # 내 클럽이 포함된 매칭(club_id IN ...)을 조회하면, 상대방 정보는 matched_club_id에 존재
        sql = f"""
            SELECT 
                MQ.room_id as match_id,  -- UUID 방 번호
                MQ.status, 
                MQ.sport, 
                MQ.sido, 
                MQ.sigungu,
                C.name as opponent_name,
                C.club_image_url as opponent_image
            FROM MatchQueue MQ
            JOIN Clubs C ON MQ.matched_club_id = C.id
            WHERE MQ.club_id IN ({format_strings}) 
              AND MQ.status IN ('MATCHED', 'PENDING', 'FINISHED')
            ORDER BY MQ.created_at DESC
        """
        cursor.execute(sql, tuple(my_club_ids))
        rows = cursor.fetchall()

        # 중복 제거 (혹시 모를 중복 room_id 방지)
        unique_matches = {}
        for row in rows:
            m_id = row['match_id']
            if m_id not in unique_matches:
                unique_matches[m_id] = row
        
        return jsonify({"success": True, "matches": list(unique_matches.values())}), 200
    
    except Exception as e:
        current_app.logger.error(f"Server Error (get_my_matches): {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


# ==========================================
# 3. 매칭 상세 및 결과 처리 (Detail & Result)
# ==========================================

@match_bp.route("/api/match/detail", methods=["GET"])
def get_match_detail():
    conn = None
    try:
        if 'user_id' not in session:
             return jsonify({"success": False, "error": "로그인 필요"}), 401
        
        user_id_str = session['user_id']
        room_id = request.args.get('match_id') # room_id (UUID)
        
        if not room_id:
             return jsonify({"success": False, "error": "match_id(room_id) required"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        # 1. 내 DB ID 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
        user_row = cursor.fetchone()
        if not user_row:
            return jsonify({"success": False, "error": "User not found"}), 404
        my_db_id = user_row['id']

        # 2. 매칭 정보 조회 (내 클럽 기준)
        # room_id가 같은 데이터 중, '내가 속한 클럽'이 club_id인 행을 찾습니다.
        # 이렇게 하면 score_a는 항상 '내 점수', score_b는 '상대 점수'가 됩니다.
        sql = """
            SELECT MQ.status, MQ.score_a, MQ.score_b, MQ.proposer_id,
                   C_OP.name as opponent_name
            FROM MatchQueue MQ
            JOIN ClubMembers CM ON MQ.club_id = CM.club_id
            JOIN Clubs C_OP ON MQ.matched_club_id = C_OP.id
            WHERE MQ.room_id = %s AND CM.user_id = %s
            LIMIT 1
        """
        cursor.execute(sql, (room_id, my_db_id))
        match_info = cursor.fetchone()
        
        if not match_info:
            return jsonify({"success": False, "error": "Match info not found or unauthorized"}), 404

        response_data = {
            "status": match_info['status'],
            "is_proposer": (match_info['proposer_id'] == my_db_id),
            "my_score": match_info['score_a'],
            "op_score": match_info['score_b'],
            "opponent_name": match_info['opponent_name']
        }

        return jsonify({"success": True, "info": response_data}), 200

    except Exception as e:
        current_app.logger.error(f"Error match detail: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


@match_bp.route("/api/match/schedule", methods=["POST"])
def update_schedule():
    conn = None
    try:
        data = request.get_json()
        room_id = data.get('match_id')
        schedule_date = data.get('schedule_date')
        location = data.get('location')

        conn = get_db_connection()
        cursor = conn.cursor()

        # room_id를 공유하는 모든 행(나와 상대방)을 동시에 업데이트
        cursor.execute("UPDATE MatchQueue SET schedule_date=%s, location=%s WHERE room_id=%s", (schedule_date, location, room_id))
        conn.commit()
        
        return jsonify({"success": True}), 200
    except Exception as e:
        current_app.logger.error(f"Error schedule: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


@match_bp.route("/api/match/result/propose", methods=["POST"])
def propose_match_result():
    conn = None
    try:
        data = request.get_json()
        room_id = data.get('match_id')
        user_id_str = session.get('user_id')
        score_my = int(data.get('score_my'))
        score_op = int(data.get('score_op'))

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
        proposer_db_id = cursor.fetchone()['id']

        # 1. 내 클럽 ID 찾기 (이 room에 참여 중인 내 클럽)
        cursor.execute("""
            SELECT MQ.club_id, MQ.matched_club_id 
            FROM MatchQueue MQ
            JOIN ClubMembers CM ON MQ.club_id = CM.club_id
            WHERE MQ.room_id = %s AND CM.user_id = %s
        """, (room_id, proposer_db_id))
        row = cursor.fetchone()
        
        if not row:
            return jsonify({"success": False, "error": "Unauthorized"}), 403
            
        my_club_id = row['club_id']
        op_club_id = row['matched_club_id']

        # 2. 점수 업데이트 (양쪽 행을 각각 업데이트)
        # 내 행: score_a = 내 점수
        cursor.execute("""
            UPDATE MatchQueue SET status='PENDING', score_a=%s, score_b=%s, proposer_id=%s
            WHERE room_id=%s AND club_id=%s
        """, (score_my, score_op, proposer_db_id, room_id, my_club_id))

        # 상대 행: score_a = 상대 점수 (반대)
        cursor.execute("""
            UPDATE MatchQueue SET status='PENDING', score_a=%s, score_b=%s, proposer_id=%s
            WHERE room_id=%s AND club_id=%s
        """, (score_op, score_my, proposer_db_id, room_id, op_club_id))

        conn.commit()
        return jsonify({"success": True, "message": "Proposed"}), 200

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Error propose: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


@match_bp.route("/api/match/result/confirm", methods=["POST"])
def confirm_match_result():
    conn = None
    try:
        data = request.get_json()
        room_id = data.get('match_id')
        is_accepted = data.get('accept')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        # 거절 시: 상태와 점수 초기화
        if not is_accepted:
            cursor.execute("""
                UPDATE MatchQueue SET status='MATCHED', score_a=NULL, score_b=NULL, proposer_id=NULL
                WHERE room_id=%s
            """, (room_id,))
            conn.commit()
            return jsonify({"success": True, "message": "Rejected"}), 200

        # 승인 시: ELO 계산 및 FINISHED 처리
        # 1. 내 클럽 기준 데이터 가져오기 (점수 계산용)
        cursor.execute("SELECT club_id, matched_club_id, score_a, score_b, status FROM MatchQueue WHERE room_id=%s LIMIT 1", (room_id,))
        record = cursor.fetchone()
        
        if not record or record['status'] == 'FINISHED':
             return jsonify({"success": True, "message": "Already finished"}), 200

        club_1 = record['club_id']
        club_2 = record['matched_club_id']
        score_1 = record['score_a']
        score_2 = record['score_b']

        # 2. 현재 포인트 조회
        cursor.execute("SELECT id, point FROM Clubs WHERE id IN (%s, %s)", (club_1, club_2))
        clubs = {row['id']: row for row in cursor.fetchall()}
        
        rating_1 = clubs[club_1]['point']
        rating_2 = clubs[club_2]['point']

        # 3. 승패 판정 (Club 1 기준)
        actual_1 = 0.5
        if score_1 > score_2: actual_1 = 1.0
        elif score_1 < score_2: actual_1 = 0.0
        
        new_1, new_2 = calculate_new_ratings(rating_1, rating_2, actual_1)
        
        # 4. DB 업데이트 (승무패 기록 및 점수)
        actual_2 = 1.0 - actual_1
        

        sql_update = """
            UPDATE Clubs SET point=%s, 
                wins=wins+%s, losses=losses+%s, draws=draws+%s 
            WHERE id=%s
        """
        # Club 1
        cursor.execute(sql_update, (
            new_1, 
            1 if actual_1 == 1.0 else 0, 1 if actual_1 == 0.0 else 0, 1 if actual_1 == 0.5 else 0, 
            club_1
        ))
        # Club 2
        cursor.execute(sql_update, (
            new_2, 
            1 if actual_2 == 1.0 else 0, 1 if actual_2 == 0.0 else 0, 1 if actual_2 == 0.5 else 0, 
            club_2
        ))
        

        cursor.execute("UPDATE MatchQueue SET status='FINISHED' WHERE room_id=%s", (room_id,))

        conn.commit()
        current_app.logger.info(f"Match Finished! Club {club_1}: {rating_1}->{new_1}, Club {club_2}: {rating_2}->{new_2}")

        return jsonify({"success": True, "message": "Confirmed"}), 200

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Error confirm: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()


# ==========================================
# 4. 채팅 내역 조회 (Chat History)
# ==========================================

@match_bp.route("/api/chat/history", methods=["GET"])
def get_chat_history():
    conn = None
    try:
        room_id = request.args.get('match_id')
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        sql = """
            SELECT CM.message, U.user_id as sender_id, CM.created_at
            FROM ChatMessages CM
            JOIN Users U ON CM.user_id = U.id
            WHERE CM.match_id = %s
            ORDER BY CM.created_at ASC
        """
        cursor.execute(sql, (room_id,))
        messages = cursor.fetchall()
        
        # Python에서 시간 포맷팅 변환 (%% 이슈 방지)
        for msg in messages:
            if msg['created_at']:
                msg['time'] = msg['created_at'].strftime('%H:%M')
            else:
                msg['time'] = ''
        
        return jsonify({"success": True, "messages": messages}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: conn.close()