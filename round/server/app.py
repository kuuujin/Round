import os
import io
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

app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(seconds=180)

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
        
        sql = """INSERT INTO Users (name, birthdate, gender, phone, user_id, password, profile_image_url)
                 VALUES (%s, %s, %s, %s, %s, %s, %s)"""
        
        val = (name, birthdate, gender, phone, user_id, hashed_password, image_url)
        
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
        session['phone_number'] = phone_number
        session.permanent = True # 위에서 설정한 180초 유효 시간을 적용합니다.
        
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


# 5. 인증번호를 확인하는 새로운 API 엔드포인트
@app.route("/verify-code", methods=["POST"])
def verify_code():
    # 세션에 인증번호가 없으면 (만료되었거나, 요청한 적이 없으면) 에러 처리
    if 'auth_code' not in session:
        return jsonify({"success": False, "error": "인증 시간이 만료되었습니다. 다시 요청해주세요."}), 408 # 408: Request Timeout

    data = request.get_json()
    user_code = data.get('code') # 클라이언트가 보낸 인증번호
    
    # 세션에 저장된 번호와 사용자가 입력한 번호를 비교
    if user_code == session['auth_code']:
        # 인증 성공 시, 사용된 세션 정보는 깨끗하게 지워서 재사용을 방지합니다.
        session.clear()
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
        if 'find_id_auth_code' not in session or 'find_id_phone' not in session:
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
        session.clear()
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
        if 'reset_pw_auth_code' not in session:
            return jsonify({"success": False, "error": "인증 시간이 만료되었습니다."}), 408

        data = request.get_json()
        user_code = data.get('code')
        
        if user_code != session['reset_pw_auth_code']:
            return jsonify({"success": False, "error": "인증번호가 일치하지 않습니다."}), 400
        
        # 인증 성공! 5분 유효한 일회용 토큰 생성
        user_id = session['reset_pw_user_id']
        token = s.dumps(user_id, salt='password-reset-salt')
        
        session.clear()
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
            session.permanent = False # Make session last until browser closes, or set True for longer duration
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

if __name__ == "__main__":
    app.run(debug=True)
