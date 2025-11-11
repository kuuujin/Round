import os
import io
import time
from werkzeug.utils import secure_filename
from datetime import timedelta
from flask import Flask, request, jsonify, session
from flask_bcrypt import Bcrypt
from sms_service import send_sms
import mysql.connector
from mysql.connector import Error
import logging
import random
from google.cloud import storage
from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadTimeSignature

app = Flask(__name__)
bcrypt = Bcrypt(app)

app.secret_key = os.environ.get('FLASK_SECRET_KEY')
s = URLSafeTimedSerializer(app.secret_key)
app_hash = os.environ.get('APP_HASH', '')

app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)

@app.route("/")
def hello():
    return "<h1>test</h1>"

@app.route("/register", methods=["POST"])
def register_user():
    db_connection = None
    try:
        # 1. 텍스트 데이터 받기 (request.json이 아닌 request.form을 사용합니다)
        name = request.form.get('name')
        birthdate = request.form.get('birthdate')
        gender = request.form.get('gender')
        phone = request.form.get('phone')
        user_id = request.form.get('user_id')
        plain_password = request.form.get('password') # 사용자가 입력한 원본 비밀번호
        primary_sido = request.form.get('primary_sido')
        primary_sigungu = request.form.get('primary_sigungu')
        secondary_sido = request.form.get('secondary_sido')
        secondary_sigungu = request.form.get('secondary_sigungu')
        profile_image = request.files.get('profile_image')
        image_url = None

        hashed_password = bcrypt.generate_password_hash(plain_password).decode('utf-8')

        if profile_image:
            filename = secure_filename(profile_image.filename)
            storage_client = storage.Client()
            bucket = storage_client.bucket(os.environ.get('GCS_BUCKET'))
            blob = bucket.blob(filename)
            image_bytes = profile_image.read()
            blob.upload_from_string(
                image_bytes,
                content_type=profile_image.content_type
            )
            app.logger.warning("--- GCS 업로드 성공: upload_from_string 사용 ---")
            image_url = blob.public_url # 이미지가 있을 때만 URL 할당
        

        # --- 4. 데이터베이스에 연결 및 데이터 저장 ---
        db_config = {
            'host': os.environ.get('DB_HOST'),
            'user': os.environ.get('DB_USER'),
            'password': os.environ.get('DB_PASSWORD'),
            'database': os.environ.get('DB_NAME')
        }
        app.logger.error(f"ATTEMPTING DB CONNECTION WITH: {db_config}")
        
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()
        
        sql = """INSERT INTO Users (name, birthdate, gender, phone, user_id, password, profile_image_url,
                                    primary_sido, primary_sigungu, secondary_sido, secondary_sigungu)
                 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        
        val = (name, birthdate, gender, phone, user_id, hashed_password, image_url,
               primary_sido, primary_sigungu, secondary_sido, secondary_sigungu)
        
        cursor.execute(sql, val)
        db_connection.commit()
        
        print(f"✅ DB에 사용자가 성공적으로 저장되었습니다: {cursor.rowcount} 행.")

        return jsonify({"success": True, "message": "회원가입이 성공적으로 완료되었습니다!"}), 201

    except mysql.connector.Error as e:
        # DB 관련 에러(예: 아이디, 휴대폰 중복)를 더 상세하게 처리
        if e.errno == 1062: # 1062: Duplicate entry
            app.logger.error(f"database duplicate error: {e}")
            return jsonify({"success": False, "error": "이미 사용 중인 아이디 또는 휴대폰 번호입니다."}), 409 # 409: Conflict
        else:
            app.logger.error(f"❌ 데이터베이스 오류 발생: {e}")
            return jsonify({"success": False, "error": "데이터베이스 처리 중 오류가 발생했습니다."}), 500
    except Exception as e:
        app.logger.error(f"❌ 회원가입 처리 중 알 수 없는 오류 발생: {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 처리 중 오류가 발생했습니다."}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()
            print("MySQL connection is closed")

@app.route("/check-phone", methods=["POST"])
def check_phone_exists():
    db_connection = None
    try:
        data = request.get_json()
        phone = data.get('phone')

        if not phone:
            return jsonify({"success": False, "error": "휴대폰 번호가 필요합니다."}), 400

        db_config = {
            'host': os.environ.get('DB_HOST'),
            'user': os.environ.get('DB_USER'),
            'password': os.environ.get('DB_PASSWORD'),
            'database': os.environ.get('DB_NAME')
        }
        
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()
        
        # Users 테이블에서 해당 휴대폰 번호의 개수를 셉니다.
        sql = "SELECT COUNT(*) FROM Users WHERE phone = %s"
        cursor.execute(sql, (phone,))
        count = cursor.fetchone()[0]
        
        # 개수가 0보다 크면 이미 존재하는 사용자입니다.
        exists = count > 0

        return jsonify({"success": True, "exists": exists}), 200

    except mysql.connector.Error as e:
        print(f"❌ 데이터베이스 오류 (check-phone): {e}")
        return jsonify({"success": False, "error": "데이터베이스 조회 중 오류가 발생했습니다."}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()


@app.route("/send-verification", methods=["POST"])
def send_verification_code():
    data = request.get_json()
    if not data or 'phone' not in data:
        return jsonify({"success": False, "error": "휴대폰 번호가 필요합니다."}), 400

    phone_number = data['phone']
    auth_code = str(random.randint(100000, 999999))
    
    message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""

    is_success = send_sms(phone_number, message)
    if is_success:
        # 3. 생성된 인증번호와 휴대폰 번호를 세션에 저장
        session['auth_code'] = auth_code
        session['auth_code_expires_at'] = time.time() + 180
        session['phone_number'] = phone_number
        session.permanent = True
        
        print(f"✅ {phone_number}로 발송된 인증번호 [{auth_code}]가 세션에 저장되었습니다.")
        
        # 4. 응답에서는 인증번호를 제거하고 성공 여부만 알립니다.
        return jsonify({
            "success": True,
            "message": "인증번호가 성공적으로 발송되었습니다."
        }), 200
    else:
        return jsonify({
            "success": False,
            "error": "인증번호 발송에 실패했습니다."
        }), 500



@app.route("/verify-code", methods=["POST"])
def verify_code():
    
    # 1. 세션에 인증 코드나 만료 시간이 없는지 확인
    if 'auth_code' not in session or 'auth_code_expires_at' not in session:
        return jsonify({"success": False, "error": "인증 요청 기록이 없습니다. 다시 시도해주세요."}), 408

    # 2. 현재 시간이 저장된 만료 시간을 초과했는지 확인
    if time.time() > session['auth_code_expires_at']:
        # 만료되었으면 해당 키만 삭제
        session.pop('auth_code', None)
        session.pop('auth_code_expires_at', None)
        return jsonify({"success": False, "error": "인증 시간이 만료되었습니다. 다시 요청해주세요."}), 408
    

    data = request.get_json()
    user_code = data.get('code')
    
    if user_code == session['auth_code']:
        
        session.pop('auth_code', None)
        session.pop('auth_code_expires_at', None)
        return jsonify({"success": True, "message": "인증에 성공했습니다."}), 200
    else:
        return jsonify({"success": False, "error": "인증번호가 일치하지 않습니다."}), 400
    
@app.route("/find-id/send-code", methods=["POST"])
def find_id_send_code():
    db_connection = None
    try:
        data = request.get_json()
        phone = data.get('phone')

        if not phone:
            return jsonify({"success": False, "error": "휴대폰 번호가 필요합니다."}), 400

        # DB 연결
        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()
        
        # 1. 휴대폰 번호가 Users 테이블에 존재하는지 확인
        sql = "SELECT COUNT(*) FROM Users WHERE phone = %s"
        cursor.execute(sql, (phone,))
        if cursor.fetchone()[0] == 0:
            return jsonify({"success": False, "error": "가입되지 않은 번호입니다."}), 404 # 404 Not Found

        # 2. 존재하면 인증번호 생성 및 SMS 발송
        auth_code = str(random.randint(100000, 999999))
        message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""
        
        is_sms_success = send_sms(phone, message) # 이전에 만든 send_sms 함수 재사용
        if not is_sms_success:
            return jsonify({"success": False, "error": "SMS 발송에 실패했습니다."}), 500

        # 3. 세션에 인증번호 저장
        session['find_id_auth_code'] = auth_code
        session['find_id_phone'] = phone
        session['find_id_auth_code_expires_at'] = time.time() + 180
        session.permanent = True # 180초 유효

        return jsonify({"success": True, "message": "인증번호가 발송되었습니다."}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (find-id/send-code): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류가 발생했습니다."}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route("/find-id/verify-code", methods=["POST"])
def find_id_verify_code():
    db_connection = None
    try:
        # 1. 세션에 인증 정보가 없으면 시간 초과 처리
        if 'find_id_auth_code' not in session or 'find_id_auth_code_expires_at' not in session:
            return jsonify({"success": False, "error": "인증 요청 기록이 없습니다."}), 408

        if time.time() > session['find_id_auth_code_expires_at']:
            session.pop('find_id_auth_code', None)
            session.pop('find_id_auth_code_expires_at', None)
            session.pop('find_id_phone', None)
            return jsonify({"success": False, "error": "인증 시간이 만료되었습니다."}), 408

        data = request.get_json()
        user_code = data.get('code')
        
        # 2. 인증번호 비교
        if user_code != session['find_id_auth_code']:
            return jsonify({"success": False, "error": "인증번호가 일치하지 않습니다."}), 400

        # 3. 인증 성공 시, DB에서 아이디(user_id) 조회
        phone = session['find_id_phone']
        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()
        
        sql = "SELECT user_id FROM Users WHERE phone = %s"
        cursor.execute(sql, (phone,))
        result = cursor.fetchone()
        
        if not result:
            return jsonify({"success": False, "error": "사용자 정보를 찾을 수 없습니다."}), 404

        # 4. 세션을 비우고, 찾은 아이디를 반환
        session.pop('find_id_auth_code', None)
        session.pop('find_id_auth_code_expires_at', None)
        session.pop('find_id_phone', None)
        return jsonify({"success": True, "user_id": result[0]}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (find-id/verify-code): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류가 발생했습니다."}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route("/reset-pw/send-code", methods=["POST"])
def reset_pw_send_code():
    db_connection = None
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        phone = data.get('phone')

        # 1. DB에서 user_id로 사용자 정보 조회
        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True) # 결과를 dict 형태로 받기
        
        cursor.execute("SELECT phone FROM Users WHERE user_id = %s", (user_id,))
        user = cursor.fetchone()

        # 2. 아이디가 없거나, 휴대폰 번호가 일치하지 않으면 에러 반환
        if not user:
            return jsonify({"success": False, "error": "존재하지 않는 아이디입니다."}), 404
        if user['phone'] != phone:
            return jsonify({"success": False, "error": "사용자 정보가 일치하지 않습니다."}), 403

        # 3. 정보가 일치하면 인증번호 발송 및 세션 저장
        auth_code = str(random.randint(100000, 999999))
        message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""
        
        send_sms(phone, message)

        session['reset_pw_auth_code'] = auth_code
        session['reset_pw_user_id'] = user_id # 다음 단계를 위해 user_id도 저장
        session['reset_pw_auth_code_expires_at'] = time.time() + 180
        session.permanent = True

        return jsonify({"success": True, "message": "인증번호가 발송되었습니다."}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (reset-pw/send-code): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route("/reset-pw/verify-code", methods=["POST"])
def reset_pw_verify_code():
    try:
        if 'reset_pw_auth_code' not in session or 'reset_pw_auth_code_expires_at' not in session:
            return jsonify({"success": False, "error": "인증 요청 기록이 없습니다."}), 408

        if time.time() > session['reset_pw_auth_code_expires_at']:
            session.pop('reset_pw_auth_code', None)
            session.pop('reset_pw_auth_code_expires_at', None)
            session.pop('reset_pw_user_id', None)
            return jsonify({"success": False, "error": "인증 시간이 만료되었습니다."}), 408

        data = request.get_json()
        user_code = data.get('code')
        
        if user_code != session['reset_pw_auth_code']:
            return jsonify({"success": False, "error": "인증번호가 일치하지 않습니다."}), 400
        
        # 인증 성공! 5분 유효한 일회용 토큰 생성
        user_id = session['reset_pw_user_id']
        token = s.dumps(user_id, salt='password-reset-salt')
        
        session.pop('reset_pw_auth_code', None)
        session.pop('reset_pw_auth_code_expires_at', None)
        session.pop('reset_pw_user_id', None)
        return jsonify({"success": True, "token": token}), 200

    except Exception as e:
        app.logger.error(f"토큰 생성 오류: {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500

@app.route("/reset-pw/set-new", methods=["POST"])
def reset_pw_set_new():
    db_connection = None
    try:
        data = request.get_json()
        token = data.get('token')
        new_password = data.get('new_password')

        # 1. 토큰 유효성 검사 (5분=300초)
        try:
            user_id = s.loads(token, salt='password-reset-salt', max_age=300)
        except SignatureExpired:
            return jsonify({"success": False, "error": "재설정 시간이 만료되었습니다. 처음부터 다시 시도해주세요."}), 400
        except BadTimeSignature:
            return jsonify({"success": False, "error": "잘못된 요청입니다."}), 400
        
        # 2. 새 비밀번호 해싱 및 DB 업데이트
        hashed_password = bcrypt.generate_password_hash(new_password).decode('utf-8')
        
        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()

        cursor.execute("UPDATE Users SET password = %s WHERE user_id = %s", (hashed_password, user_id))
        db_connection.commit()
        
        return jsonify({"success": True, "message": "비밀번호가 성공적으로 변경되었습니다."}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (reset-pw/set-new): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route("/login", methods=["POST"])
def login_user():
    db_connection = None
    try:
        # 1. Get user_id and password from client request (JSON)
        data = request.get_json()
        user_id = data.get('user_id')
        plain_password = data.get('password')

        if not user_id or not plain_password:
            return jsonify({"success": False, "error": "아이디와 비밀번호를 모두 입력해주세요."}), 400

        # 2. Connect to the database
        db_config = {
            'host': os.environ.get('DB_HOST'),
            'user': os.environ.get('DB_USER'),
            'password': os.environ.get('DB_PASSWORD'),
            'database': os.environ.get('DB_NAME')
        }
        db_connection = mysql.connector.connect(**db_config)
        # Use dictionary=True to easily access columns by name
        cursor = db_connection.cursor(dictionary=True)

        # 3. Fetch user data based on user_id
        sql = "SELECT id, user_id, password, name, role, profile_image_url FROM Users WHERE user_id = %s"
        cursor.execute(sql, (user_id,))
        user = cursor.fetchone()

        # 4. Check if user exists and password is correct
        if user and bcrypt.check_password_hash(user['password'], plain_password):
            # Password matches!
            app.logger.info(f"User '{user_id}' logged in successfully.")

            # --- Session Management (Optional but Recommended) ---
            # Store essential, non-sensitive user info in the session
            session['user_id'] = user['user_id']
            session['user_role'] = user['role']
            session['logged_in'] = True
            session.permanent = True
            # -----------------------------------------------------

            # Prepare user data to send back (excluding password)
            user_data = {
                "id": user['id'],
                "user_id": user['user_id'],
                "name": user['name'],
                "role": user['role'],
                "profile_image_url": user['profile_image_url']
            }

            return jsonify({"success": True, "message": "로그인 성공!", "user": user_data}), 200
        else:
            # User not found or password incorrect
            app.logger.warning(f"Login failed for user_id '{user_id}'. Invalid credentials.")
            return jsonify({"success": False, "error": "아이디 또는 비밀번호가 올바르지 않습니다."}), 401 # 401 Unauthorized

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (login): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류가 발생했습니다."}), 500
    except Exception as e:
        app.logger.error(f"로그인 처리 중 알 수 없는 오류 발생: {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 처리 중 오류가 발생했습니다."}), 500
    finally:
        # Ensure the connection is closed
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()
            app.logger.debug("MySQL connection is closed for login request")



@app.route("/create-club", methods=["POST"])
def create_club():
    db_connection = None
    cursor = None # cursor도 finally에서 닫아주기 위해 선언
    try:
        # 1. 폼 데이터 받기
        creator_user_id_str = request.form.get('creator_user_id') # 클라이언트에서 보낸 user_id (문자열)
        sport = request.form.get('sport')
        sido = request.form.get('sido')
        sigungu = request.form.get('sigungu')
        name = request.form.get('name')
        description = request.form.get('description')
        max_capacity = request.form.get('max_capacity')
        club_image = request.files.get('club_image')
        image_url = None

        # 2. GCS에 이미지 업로드 (이미지가 있는 경우)
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
            app.logger.info(f"Club image uploaded to GCS: {image_url}")

        # 3. 데이터베이스 연결
        db_config = {
            'host': os.environ.get('DB_HOST'),
            'user': os.environ.get('DB_USER'),
            'password': os.environ.get('DB_PASSWORD'),
            'database': os.environ.get('DB_NAME')
        }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()

        # 4. (중요!) 클라이언트가 보낸 user_id(문자열)로 Users 테이블의 고유 id(숫자) 찾기
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (creator_user_id_str,))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "생성자 정보를 찾을 수 없습니다."}), 404
        
        creator_id_int = user_record[0] # Users.id (숫자)

        # 5. 데이터베이스 트랜잭션 시작 (두 테이블에 모두 저장해야 하므로)
        db_connection.start_transaction()

        # 6. Clubs 테이블에 동호회 정보 삽입
        sql_club = """INSERT INTO Clubs (name, sport, sido, sigungu, description, max_capacity, club_image_url, creator_id)
                      VALUES (%s, %s, %s, %s, %s, %s, %s)"""
        val_club = (name, sport, sido, sigungu, description, max_capacity, image_url, creator_id_int)
        cursor.execute(sql_club, val_club)
        
        # 7. 방금 생성된 동호회의 고유 ID(auto_increment) 가져오기
        new_club_id = cursor.lastrowid

        # 8. ClubMembers 테이블에 동호회 생성자를 'admin'으로 자동 추가
        sql_member = """INSERT INTO ClubMembers (user_id, club_id, role)
                        VALUES (%s, %s, 'admin')"""
        val_member = (creator_id_int, new_club_id)
        cursor.execute(sql_member, val_member)
        
        # 9. 모든 작업이 성공했으므로 트랜잭션 완료 (DB에 최종 반영)
        db_connection.commit()

        app.logger.info(f"New club created (ID: {new_club_id}) by user (ID: {creator_id_int}).")
        return jsonify({"success": True, "message": "동호회가 성공적으로 생성되었습니다!"}), 201

    except mysql.connector.Error as e:
        if db_connection:
            db_connection.rollback() # ❗️ 오류 발생 시 모든 DB 작업을 되돌립니다.
        if e.errno == 1062: # 이름 중복 오류
            app.logger.error(f"Club creation failed (Duplicate name): {e}")
            return jsonify({"success": False, "error": "이미 사용 중인 동호회 이름입니다."}), 409
        else:
            app.logger.error(f"DB 오류 (create-club): {e}")
            return jsonify({"success": False, "error": "데이터베이스 오류가 발생했습니다."}), 500
    except Exception as e:
        if db_connection:
            db_connection.rollback() # ❗️ 오류 발생 시 모든 DB 작업을 되돌립니다.
        app.logger.error(f"알 수 없는 오류 (create-club): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 처리 중 오류가 발생했습니다."}), 500
    finally:
        # 연결 및 커서 닫기
        if cursor:
            cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()
            app.logger.debug("MySQL connection is closed for create-club request")

@app.route("/api/check-login", methods=["GET"])
def check_login_status():
    db_connection = None
    cursor = None  # 👈 1. cursor를 None으로 초기화
    try:
        # 1. 세션에 'logged_in' 플래그와 'user_id'가 있는지 확인
        if session.get('logged_in') and session.get('user_id'):
            current_user_id_str = session['user_id']
            
            db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
            db_connection = mysql.connector.connect(**db_config)
            cursor = db_connection.cursor(dictionary=True)
            
            cursor.execute("SELECT id, user_id, name, role, profile_image_url FROM Users WHERE user_id = %s", (current_user_id_str,))
            user = cursor.fetchone()

            if user:
                # 3. 세션이 유효하면, 사용자 정보를 반환
                session.permanent = True  # 👈 2. 세션 만료 시간 30일로 갱신
                return jsonify({"success": True, "user": user}), 200
            else:
                session.clear()
                return jsonify({"success": False, "error": "사용자 정보를 찾을 수 없습니다."}), 404
        
        return jsonify({"success": False, "error": "로그인 상태가 아닙니다."}), 401

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (check-login): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e: # 👈 3. 모든 예외를 잡는 구문 추가
        app.logger.error(f"알 수 없는 오류 (check-login): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 내부 오류가 발생했습니다."}), 500
    finally:
        if cursor: # 👈 1. cursor가 None이 아닐 때만 close() 호출
            cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@app.route("/api/user-locations", methods=["GET"])
def get_user_locations():
    db_connection = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401
        
        current_user_id_str = session['user_id']
        
        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        sql = """
            SELECT primary_sido, primary_sigungu, secondary_sido, secondary_sigungu 
            FROM Users WHERE user_id = %s
        """
        cursor.execute(sql, (current_user_id_str,))
        locations = cursor.fetchone()

        if not locations:
            return jsonify({"success": False, "error": "사용자 위치 정보를 찾을 수 없습니다."}), 404
            
        return jsonify({"success": True, "locations": locations}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (get_user_locations): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route("/api/my-clubs", methods=["GET"])
def get_my_clubs():
    db_connection = None
    try:
        # 1. 로그인 세션에서 현재 사용자의 user_id를 가져옵니다.
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        current_user_id_str = session['user_id'] # 로그인 시 저장한 'user_id' (문자열)

        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True) # 👈 결과를 dict 형태로 받습니다.

        # 2. ClubMembers와 Clubs 테이블을 JOIN하여 사용자가 가입한 클럽 정보만 조회
        # (Users.user_id는 문자열, ClubMembers.user_id는 Users.id를 참조하는 숫자(INT)이므로 변환 필요)
        sql = """
            SELECT C.id, C.name
            FROM Clubs C
            JOIN ClubMembers CM ON C.id = CM.club_id
            JOIN Users U ON CM.user_id = U.id
            WHERE U.user_id = %s
        """
        cursor.execute(sql, (current_user_id_str,))
        clubs = cursor.fetchall() # [{'id': 1, 'name': '익스플로전'}, ...]

        return jsonify({"success": True, "clubs": clubs}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (get_my_clubs): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()


@app.route("/api/recommended-clubs", methods=["GET"])
def get_recommended_clubs():
    db_connection = None
    try:
        # 1. 쿼리 파라미터에서 category, sido, sigungu 값을 가져옵니다.
        category = request.args.get('category')
        sido = request.args.get('sido')
        sigungu = request.args.get('sigungu')

        db_config = { 'host': os.environ.get('DB_HOST'), 'user': os.environ.get('DB_USER'), 'password': os.environ.get('DB_PASSWORD'), 'database': os.environ.get('DB_NAME') }
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        # 2. SQL 쿼리와 파라미터를 동적으로 구성합니다.
        sql_select = """
            SELECT 
                id, name, description, sport, sido, sigungu, club_image_url,
                (SELECT COUNT(*) FROM ClubMembers CM WHERE CM.club_id = C.id) AS member_count
            FROM Clubs C
        """
        sql_where_clauses = []
        params = []

        # 3. category 필터 추가
        if category:
            sql_where_clauses.append("C.sport = %s")
            params.append(category)

        # 4. sido, sigungu 필터 추가
        if sido and sigungu:
            sql_where_clauses.append("C.sido = %s AND C.sigungu = %s")
            params.extend([sido, sigungu])
        elif sido:
            # 시/군/구 없이 시/도만 있는 경우 (예: 세종특별자치시)
            sql_where_clauses.append("C.sido = %s")
            params.append(sido)
            
        # 5. WHERE 절 조합
        if sql_where_clauses:
            sql_where = " WHERE " + " AND ".join(sql_where_clauses)
        else:
            sql_where = ""
            
        sql_order = " ORDER BY RAND() LIMIT 10" # 랜덤으로 10개
        
        # 6. 파라미터와 함께 쿼리 실행
        final_sql = sql_select + sql_where + sql_order
        
        cursor.execute(final_sql, tuple(params))
        clubs = cursor.fetchall()

        return jsonify({"success": True, "clubs": clubs}), 200

    except mysql.connector.Error as e:
        app.logger.error(f"DB 오류 (get_recommended_clubs): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

if __name__ == "__main__":
    app.run(debug=True)
