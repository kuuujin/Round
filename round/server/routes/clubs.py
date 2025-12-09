from flask import Blueprint, request, jsonify, session, current_app
import mysql.connector
import os
from google.cloud import storage
from werkzeug.utils import secure_filename
from utils.db import get_db_connection

clubs_bp = Blueprint('clubs', __name__)

# ==========================================
# 1. 동호회 생성 및 관리 (Create & Manage)
# ==========================================

@clubs_bp.route("/create-club", methods=["POST"])
def create_club():
    conn = None
    cursor = None
    try:
        # 1. Form 데이터 수신
        creator_user_id_str = request.form.get('creator_user_id')
        sport = request.form.get('sport')
        sido = request.form.get('sido')
        sigungu = request.form.get('sigungu')
        name = request.form.get('name')
        description = request.form.get('description')
        max_capacity = request.form.get('max_capacity')
        club_image = request.files.get('club_image')
        image_url = None

        # 2. GCS 이미지 업로드
        if club_image:
            filename = secure_filename(club_image.filename)
            storage_client = storage.Client()
            bucket = storage_client.bucket(os.environ.get('GCS_BUCKET'))
            blob = bucket.blob(filename)
            
            image_bytes = club_image.read()
            blob.upload_from_string(
                image_bytes,
                content_type=club_image.content_type
            )
            image_url = blob.public_url

        # 3. DB 연결
        conn = get_db_connection()
        cursor = conn.cursor()

        # 4. 생성자 ID 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (creator_user_id_str,))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "생성자 정보를 찾을 수 없습니다."}), 404
        
        creator_id_int = user_record[0]

        # 5. Clubs 테이블 Insert
        sql_club = """INSERT INTO Clubs (name, sport, sido, sigungu, description, max_capacity, club_image_url, creator_id)
                      VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
        val_club = (name, sport, sido, sigungu, description, max_capacity, image_url, creator_id_int)
        cursor.execute(sql_club, val_club)
        
        new_club_id = cursor.lastrowid

        # 6. 생성자를 관리자(admin)로 멤버 추가
        sql_member = """INSERT INTO ClubMembers (user_id, club_id, role)
                        VALUES (%s, %s, 'admin')"""
        val_member = (creator_id_int, new_club_id)
        cursor.execute(sql_member, val_member)
        
        conn.commit()

        current_app.logger.info(f"Club created: {name} (ID: {new_club_id})")
        return jsonify({"success": True, "message": "동호회가 성공적으로 생성되었습니다!"}), 201

    except mysql.connector.Error as e:
        if conn: conn.rollback()
        if e.errno == 1062: # Duplicate entry
            return jsonify({"success": False, "error": "이미 사용 중인 동호회 이름입니다."}), 409
        else:
            current_app.logger.error(f"DB Error (create-club): {e}")
            return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Server Error (create-club): {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/my-clubs", methods=["GET"])
def get_my_clubs():
    conn = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        current_user_id_str = session['user_id']

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # 내가 가입한 클럽 목록 및 내 역할(role) 조회
        sql = """
            SELECT C.id, C.name, C.sport, C.sido, C.sigungu, CM.role 
            FROM Clubs C
            JOIN ClubMembers CM ON C.id = CM.club_id
            WHERE CM.user_id = (SELECT id FROM Users WHERE user_id = %s)
        """
        cursor.execute(sql, (current_user_id_str,))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except Exception as e:
        current_app.logger.error(f"Error (get_my_clubs): {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


# ==========================================
# 2. 동호회 조회 및 정보 (Search & Info)
# ==========================================

@clubs_bp.route("/api/clubs/list", methods=["GET"])
def get_clubs_list():
    conn = None
    cursor = None
    try:
        sido = request.args.get('sido')
        sport = request.args.get('sport')
        keyword = request.args.get('keyword')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        sql = """
            SELECT 
                C.id, C.name, C.description, C.sport, C.sido, C.sigungu, C.club_image_url,
                C.max_capacity,
                (SELECT COUNT(*) FROM ClubMembers CM WHERE CM.club_id = C.id) AS member_count
            FROM Clubs C
            WHERE C.sido = %s AND C.sport = %s
        """
        params = [sido, sport]

        if keyword:
            sql += " AND C.name LIKE %s"
            params.append(f"%{keyword}%")

        sql += " ORDER BY C.created_at DESC"

        cursor.execute(sql, tuple(params))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except Exception as e:
        current_app.logger.error(f"Error (get_clubs_list): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/recommended-clubs", methods=["GET"])
def get_recommended_clubs():
    conn = None
    cursor = None
    try:
        category = request.args.get('category')
        sido = request.args.get('sido')
        sigungu = request.args.get('sigungu')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        sql_select = """
            SELECT 
                id, name, description, sport, sido, sigungu, club_image_url,
                (SELECT COUNT(*) FROM ClubMembers CM WHERE CM.club_id = C.id) AS member_count
            FROM Clubs C
        """
        sql_where_clauses = []
        params = []

        if category:
            sql_where_clauses.append("C.sport = %s")
            params.append(category)

        if sido:
            sql_where_clauses.append("C.sido = %s")
            params.append(sido)
            if sigungu:
                sql_where_clauses.append("C.sigungu = %s")
                params.append(sigungu)
            
        if sql_where_clauses:
            sql_where = " WHERE " + " AND ".join(sql_where_clauses)
        else:
            sql_where = ""
            
        sql_order = " ORDER BY RAND() LIMIT 10"
        
        cursor.execute(sql_select + sql_where + sql_order, tuple(params))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except Exception as e:
        current_app.logger.error(f"Error (get_recommended_clubs): {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club-info", methods=["GET"])
def get_club_info():
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
        
        # 다중 쿼리 실행 시 안전을 위해 buffered=True 사용
        cursor = conn.cursor(dictionary=True, buffered=True)

        club_id = request.args.get('club_id')
        user_id_str = session.get('user_id')

        if not club_id:
             return jsonify({"success": False, "error": "Club ID is required"}), 400

        # 1. 클럽 기본 정보 조회
        sql = """
            SELECT 
                id, name, sport, sido, sigungu, description, max_capacity, club_image_url,
                point, wins, draws, losses,
                (SELECT COUNT(*) FROM ClubMembers CM WHERE CM.club_id = C.id) AS member_count
            FROM Clubs C
            WHERE id = %s
        """
        cursor.execute(sql, (club_id,))
        club = cursor.fetchone()

        if not club:
            return jsonify({"success": False, "error": "존재하지 않는 동호회"}), 404

        # 2. 내 권한 조회 (MEMBER / ADMIN / PENDING / NONE)
        my_role = "NONE"
        if user_id_str:
            # (1) 이미 멤버인지 확인
            cursor.execute("""
                SELECT role FROM ClubMembers 
                WHERE club_id = %s 
                  AND user_id = (SELECT id FROM Users WHERE user_id = %s)
            """, (club_id, user_id_str))
            member_row = cursor.fetchone()
            
            if member_row:
                my_role = member_row['role']
            else:
                # (2) 가입 신청 대기 중인지 확인 (테이블 없을 경우 대비 try-except)
                try:
                    cursor.execute("""
                        SELECT id FROM ClubJoinRequests 
                        WHERE club_id = %s 
                          AND user_id = (SELECT id FROM Users WHERE user_id = %s)
                    """, (club_id, user_id_str))
                    if cursor.fetchone():
                        my_role = "PENDING"
                except Exception:
                    pass # 테이블이 없으면 무시

        # 3. 랭킹 계산 (동일 지역, 동일 종목 내 순위)
        sql_rank = """
            SELECT COUNT(*) + 1 AS ranking
            FROM Clubs
            WHERE sido = %s AND sigungu = %s AND sport = %s AND point > %s
        """
        cursor.execute(sql_rank, (club['sido'], club['sigungu'], club['sport'], club['point']))
        rank_result = cursor.fetchone()
        
        club['rank_text'] = f"Rank #{rank_result['ranking']}"
        club['total_matches'] = club['wins'] + club['draws'] + club['losses']
        club['my_role'] = my_role

        return jsonify({"success": True, "club": club}), 200

    except Exception as e:
        current_app.logger.error(f"Error (get_club_info): {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/ranking", methods=["GET"])
def get_club_ranking():
    conn = None
    try:
        sido = request.args.get('sido')
        sigungu = request.args.get('sigungu')
        sport = request.args.get('sport')

        if not sport:
             return jsonify({"success": False, "error": "종목을 선택해주세요."}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        sql = """
            SELECT id, name, club_image_url, point,
                   RANK() OVER (ORDER BY point DESC) as ranking
            FROM Clubs
            WHERE sport = %s
        """
        params = [sport]

        if sido:
            sql += " AND sido = %s"
            params.append(sido)
        if sigungu:
            sql += " AND sigungu = %s"
            params.append(sigungu)

        sql += " ORDER BY point DESC LIMIT 50"

        cursor.execute(sql, tuple(params))
        ranking_list = cursor.fetchall()

        return jsonify({"success": True, "ranking": ranking_list}), 200

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


# ==========================================
# 3. 일정 및 게시글 (Schedule & Posts)
# ==========================================

@clubs_bp.route("/api/schedules", methods=["GET"])
def get_schedules():
    conn = None
    try:
        club_id = request.args.get('club_id')
        year = request.args.get('year')
        month = request.args.get('month')
        
        if not all([club_id, year, month]):
             return jsonify({"success": False, "error": "필수 파라미터 누락"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        sql = """
            SELECT 
                id, title, description, location, is_match, opponent_name,
                max_participants, current_participants,
                DATE_FORMAT(schedule_date, '%Y-%m-%d') as date_str,
                DATE_FORMAT(schedule_date, '%H:%i') as time_str,
                DATE_FORMAT(schedule_date, '%p') as ampm
            FROM Schedules
            WHERE club_id = %s 
              AND YEAR(schedule_date) = %s 
              AND MONTH(schedule_date) = %s
            ORDER BY schedule_date ASC
        """
        cursor.execute(sql, (club_id, year, month))
        schedules = cursor.fetchall()

        return jsonify({"success": True, "schedules": schedules}), 200

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/schedules", methods=["POST"])
def create_schedule():
    conn = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        data = request.get_json()
        # 필수 데이터 검증
        if not all(key in data for key in ['club_id', 'title', 'location', 'schedule_date', 'max_participants']):
             return jsonify({"success": False, "error": "필수 정보가 누락되었습니다."}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 작성자 DB ID 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "사용자 불일치"}), 404
        
        author_id = user_record[0]

        sql = """
            INSERT INTO Schedules 
            (club_id, user_id, title, description, location, schedule_date, max_participants, is_match, opponent_name)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        val = (
            data['club_id'], author_id, data['title'], data.get('description'), 
            data['location'], data['schedule_date'], data['max_participants'], 
            data.get('is_match', False), data.get('opponent_name')
        )
        
        cursor.execute(sql, val)
        conn.commit()
        
        return jsonify({"success": True, "message": "일정이 등록되었습니다."}), 201

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club/<int:club_id>/schedules", methods=["GET"])
def get_club_schedules(club_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # 다가오는 일정 5개 조회
        sql = """
            SELECT id, title, description, location, schedule_date,
                   is_match, opponent_name, max_participants, current_participants
            FROM Schedules 
            WHERE club_id = %s AND schedule_date >= NOW()
            ORDER BY schedule_date ASC 
            LIMIT 5
        """
        cursor.execute(sql, (club_id,))
        schedules = cursor.fetchall()
        
        # JSON 직렬화를 위해 datetime 변환
        for s in schedules:
            s['schedule_date'] = s['schedule_date'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({"success": True, "schedules": schedules}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club/<int:club_id>/matches/finished", methods=["GET"])
def get_finished_matches(club_id):
    conn = None
    try:
        conn = get_db_connection()
        # 이전 쿼리 충돌 방지를 위해 buffered=True 필수
        cursor = conn.cursor(dictionary=True, buffered=True)
        
        # 최근 경기 결과 조회
        # schedule_date가 없으면 created_at을 대신 사용 (COALESCE)
        sql = """
            SELECT 
                MQ.id, MQ.score_a as my_score, MQ.score_b as op_score, 
                DATE_FORMAT(COALESCE(MQ.schedule_date, MQ.created_at), '%%m월 %%d일') as match_date,
                DATE_FORMAT(COALESCE(MQ.schedule_date, MQ.created_at), '%%H:%%i') as match_time,
                C.name as opponent_name,
                C.club_image_url as opponent_image
            FROM MatchQueue MQ
            JOIN Clubs C ON MQ.matched_club_id = C.id
            WHERE MQ.club_id = %s 
              AND MQ.status = 'FINISHED'
            ORDER BY COALESCE(MQ.schedule_date, MQ.created_at) DESC
            LIMIT 5
        """
        cursor.execute(sql, (club_id,))
        matches = cursor.fetchall()
        
        return jsonify({"success": True, "matches": matches}), 200
        
    except Exception as e:
        current_app.logger.error(f"Error fetching match history: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club/<int:club_id>/posts", methods=["GET"])
def get_club_posts(club_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        sql = """
            SELECT P.id, P.title, P.content, P.likes, P.image_url, P.created_at,
                   U.name as author_name,
                   0 as comment_count
            FROM Posts P
            JOIN Users U ON P.user_id = U.id
            WHERE P.club_id = %s
            ORDER BY P.created_at DESC 
            LIMIT 5
        """
        cursor.execute(sql, (club_id,))
        posts = cursor.fetchall()
        
        for p in posts:
            p['created_at'] = p['created_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({"success": True, "posts": posts}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


# ==========================================
# 4. 가입 신청 및 관리 (Join Request)
# ==========================================

@clubs_bp.route("/api/club/join", methods=["POST"])
def request_join_club():
    conn = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401

        data = request.get_json()
        club_id = data.get('club_id')
        user_str_id = session['user_id']

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # 1. 유저 PK 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_str_id,))
        user_row = cursor.fetchone()
        user_db_id = user_row['id']

        # 2. 중복 가입/신청 확인
        cursor.execute("SELECT * FROM ClubMembers WHERE club_id=%s AND user_id=%s", (club_id, user_db_id))
        if cursor.fetchone():
            return jsonify({"success": False, "error": "이미 가입된 동호회입니다."}), 400

        try:
            cursor.execute("SELECT * FROM ClubJoinRequests WHERE club_id=%s AND user_id=%s", (club_id, user_db_id))
            if cursor.fetchone():
                return jsonify({"success": False, "error": "이미 가입 신청을 했습니다."}), 400
        except Exception:
            pass # 테이블이 없으면 패스 (혹은 에러 처리)

        # 3. 신청 등록
        cursor.execute("INSERT INTO ClubJoinRequests (club_id, user_id) VALUES (%s, %s)", (club_id, user_db_id))
        conn.commit()

        return jsonify({"success": True, "message": "가입 신청이 완료되었습니다."}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club/requests", methods=["GET"])
def get_join_requests():
    conn = None
    try:
        club_id = request.args.get('club_id')
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        sql = """
            SELECT R.id as request_id, U.id as user_id, U.name, U.profile_image_url, 
                   DATE_FORMAT(R.created_at, '%%Y-%%m-%%d') as created_at
            FROM ClubJoinRequests R
            JOIN Users U ON R.user_id = U.id
            WHERE R.club_id = %s
            ORDER BY R.created_at DESC
        """
        cursor.execute(sql, (club_id,))
        requests = cursor.fetchall()
        
        return jsonify({"success": True, "requests": requests}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()


@clubs_bp.route("/api/club/request/process", methods=["POST"])
def process_join_request():
    conn = None
    try:
        data = request.get_json()
        request_id = data.get('request_id')
        action = data.get('action') # 'APPROVE' or 'REJECT'
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # 요청 정보 조회
        cursor.execute("SELECT club_id, user_id FROM ClubJoinRequests WHERE id=%s", (request_id,))
        req = cursor.fetchone()
        if not req:
            return jsonify({"success": False, "error": "요청을 찾을 수 없습니다."}), 404

        if action == 'APPROVE':
            # 멤버 추가
            cursor.execute("INSERT INTO ClubMembers (club_id, user_id, role) VALUES (%s, %s, 'MEMBER')", 
                           (req['club_id'], req['user_id']))
            cursor.execute("UPDATE Clubs SET member_count = member_count + 1 WHERE id=%s", (req['club_id'],))
            
        # 승인/거절 후 요청 내역 삭제
        cursor.execute("DELETE FROM ClubJoinRequests WHERE id=%s", (request_id,))
        
        conn.commit()
        return jsonify({"success": True, "message": "처리되었습니다."}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn and conn.is_connected(): conn.close()