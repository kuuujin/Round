from flask import Blueprint, request, jsonify, session, current_app
import mysql.connector
import os
from google.cloud import storage
from werkzeug.utils import secure_filename
from utils.db import get_db_connection # Use the DB utility

# Create the Blueprint
clubs_bp = Blueprint('clubs', __name__)

@clubs_bp.route("/create-club", methods=["POST"])
def create_club():
    db_connection = None
    cursor = None
    try:
        # 1. Get form data
        creator_user_id_str = request.form.get('creator_user_id')
        sport = request.form.get('sport')
        sido = request.form.get('sido')
        sigungu = request.form.get('sigungu')
        name = request.form.get('name')
        description = request.form.get('description')
        max_capacity = request.form.get('max_capacity')
        club_image = request.files.get('club_image')
        image_url = None

        # 2. Upload to GCS
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
            current_app.logger.info(f"Club image uploaded to GCS: {image_url}")

        # 3. DB Connection
        db_connection = get_db_connection()
        cursor = db_connection.cursor()

        # 4. Get Creator ID
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (creator_user_id_str,))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "생성자 정보를 찾을 수 없습니다."}), 404
        
        creator_id_int = user_record[0]

        # 5. Insert Club
        sql_club = """INSERT INTO Clubs (name, sport, sido, sigungu, description, max_capacity, club_image_url, creator_id)
                      VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
        val_club = (name, sport, sido, sigungu, description, max_capacity, image_url, creator_id_int)
        cursor.execute(sql_club, val_club)
        
        new_club_id = cursor.lastrowid

        # 6. Insert Admin Member
        sql_member = """INSERT INTO ClubMembers (user_id, club_id, role)
                        VALUES (%s, %s, 'admin')"""
        val_member = (creator_id_int, new_club_id)
        cursor.execute(sql_member, val_member)
        
        db_connection.commit()

        current_app.logger.info(f"New club created (ID: {new_club_id}) by user (ID: {creator_id_int}).")
        return jsonify({"success": True, "message": "동호회가 성공적으로 생성되었습니다!"}), 201

    except mysql.connector.Error as e:
        if db_connection: db_connection.rollback()
        if e.errno == 1062:
            current_app.logger.error(f"Club creation failed (Duplicate name): {e}")
            return jsonify({"success": False, "error": "이미 사용 중인 동호회 이름입니다."}), 409
        else:
            current_app.logger.error(f"DB Error (create-club): {e}")
            return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"Server Error (create-club): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()
            current_app.logger.debug("MySQL connection is closed for create-club request")

@clubs_bp.route("/api/my-clubs", methods=["GET"])
def get_my_clubs():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        current_user_id_str = session['user_id']

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        sql = """
            SELECT C.id, C.name
            FROM Clubs C
            JOIN ClubMembers CM ON C.id = CM.club_id
            JOIN Users U ON CM.user_id = U.id
            WHERE U.user_id = %s
        """
        cursor.execute(sql, (current_user_id_str,))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_my_clubs): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()


@clubs_bp.route("/api/recommended-clubs", methods=["GET"])
def get_recommended_clubs():
    db_connection = None
    cursor = None
    try:
        category = request.args.get('category')
        sido = request.args.get('sido')
        sigungu = request.args.get('sigungu')

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

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

        if sido and sigungu:
            sql_where_clauses.append("C.sido = %s AND C.sigungu = %s")
            params.extend([sido, sigungu])
        elif sido:
            sql_where_clauses.append("C.sido = %s")
            params.append(sido)
            
        if sql_where_clauses:
            sql_where = " WHERE " + " AND ".join(sql_where_clauses)
        else:
            sql_where = ""
            
        sql_order = " ORDER BY RAND() LIMIT 10"
        
        final_sql = sql_select + sql_where + sql_order
        
        cursor.execute(final_sql, tuple(params))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_recommended_clubs): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@clubs_bp.route("/api/club-info", methods=["GET"])
def get_club_info():
    db_connection = None
    cursor = None
    try:
        club_id = request.args.get('club_id')
        if not club_id:
            return jsonify({"success": False, "error": "club_id 필요"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

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

        # Calculate Rank
        sql_rank = """
            SELECT COUNT(*) + 1 AS ranking
            FROM Clubs
            WHERE sido = %s 
              AND sigungu = %s 
              AND sport = %s 
              AND point > %s
        """
        rank_params = (club['sido'], club['sigungu'], club['sport'], club['point'])
        
        cursor.execute(sql_rank, rank_params)
        rank_result = cursor.fetchone()
        
        current_rank = rank_result['ranking']
        
        club['rank_text'] = f"Rank #{current_rank}"
        club['total_matches'] = club['wins'] + club['draws'] + club['losses']

        return jsonify({"success": True, "club": club}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_club_info): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@clubs_bp.route("/api/schedules", methods=["GET"])
def get_schedules():
    db_connection = None
    try:
        club_id = request.args.get('club_id')
        year = request.args.get('year')   # 선택된 연도
        month = request.args.get('month') # 선택된 월
        
        if not club_id or not year or not month:
             return jsonify({"success": False, "error": "필수 파라미터 누락"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # 해당 연/월의 일정 조회
        sql = """
            SELECT 
                id, title, description, location, is_match, opponent_name,
                max_participants, current_participants,
                DATE_FORMAT(schedule_date, '%Y-%m-%d') as date_str,
                DATE_FORMAT(schedule_date, '%H:%i') as time_str,
                DATE_FORMAT(schedule_date, '%p') as ampm -- AM/PM
            FROM Schedules
            WHERE club_id = %s 
              AND YEAR(schedule_date) = %s 
              AND MONTH(schedule_date) = %s
            ORDER BY schedule_date ASC
        """
        cursor.execute(sql, (club_id, year, month))
        schedules = cursor.fetchall()

        return jsonify({"success": True, "schedules": schedules}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_schedules): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@clubs_bp.route("/api/schedules", methods=["POST"])
def create_schedule():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        data = request.get_json()
        club_id = data.get('club_id')
        title = data.get('title')
        description = data.get('description')
        location = data.get('location')
        schedule_date = data.get('schedule_date') # 'YYYY-MM-DD HH:MM:SS' 형식
        max_participants = data.get('max_participants')
        is_match = data.get('is_match', False) # 기본값 False
        opponent_name = data.get('opponent_name') # 경기일 경우만

        if not club_id or not title or not location or not schedule_date or not max_participants:
             return jsonify({"success": False, "error": "필수 정보가 누락되었습니다."}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        # 작성자 ID 찾기
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "사용자 정보를 찾을 수 없습니다."}), 404
        author_id = user_record[0]

        # 일정 저장
        sql = """
            INSERT INTO Schedules 
            (club_id, user_id, title, description, location, schedule_date, max_participants, is_match, opponent_name)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        val = (club_id, author_id, title, description, location, schedule_date, max_participants, is_match, opponent_name)
        
        cursor.execute(sql, val)
        db_connection.commit()
        
        return jsonify({"success": True, "message": "일정이 등록되었습니다."}), 201

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (create_schedule): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()