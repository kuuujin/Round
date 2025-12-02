from flask import Blueprint, request, jsonify, session, current_app
import mysql.connector
import os
import random
import time
from sms_service import send_sms
from google.cloud import storage
from werkzeug.utils import secure_filename
from extensions import bcrypt
from utils.db import get_db_connection

# Create the Blueprint
auth_bp = Blueprint('auth', __name__)

# --- Registration & User Info ---

@auth_bp.route("/register", methods=["POST"])
def register_user():
    db_connection = None
    cursor = None
    try:
        # 1. Get form data
        name = request.form.get('name')
        birthdate = request.form.get('birthdate')
        gender = request.form.get('gender')
        phone = request.form.get('phone')
        user_id = request.form.get('user_id')
        plain_password = request.form.get('password')
        primary_sido = request.form.get('primary_sido')
        primary_sigungu = request.form.get('primary_sigungu')
        secondary_sido = request.form.get('secondary_sido')
        secondary_sigungu = request.form.get('secondary_sigungu')
        profile_image = request.files.get('profile_image')
        image_url = None

        # 2. Hash password
        hashed_password = bcrypt.generate_password_hash(plain_password).decode('utf-8')

        # 3. Upload image to GCS
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
            current_app.logger.warning("--- GCS Upload Success ---")
            image_url = blob.public_url

        # 4. Save to DB
        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        sql = """INSERT INTO Users (name, birthdate, gender, phone, user_id, password, profile_image_url,
                                    primary_sido, primary_sigungu, secondary_sido, secondary_sigungu)
                 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        
        val = (name, birthdate, gender, phone, user_id, hashed_password, image_url,
               primary_sido, primary_sigungu, secondary_sido, secondary_sigungu)
        
        cursor.execute(sql, val)
        db_connection.commit()
        
        return jsonify({"success": True, "message": "회원가입이 성공적으로 완료되었습니다!"}), 201

    except mysql.connector.Error as e:
        if e.errno == 1062:
            current_app.logger.error(f"DB Duplicate Error: {e}")
            return jsonify({"success": False, "error": "이미 사용 중인 아이디 또는 휴대폰 번호입니다."}), 409
        else:
            current_app.logger.error(f"DB Error (register): {e}")
            return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        current_app.logger.error(f"Server Error (register): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/check-phone", methods=["POST"])
def check_phone_exists():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        phone = data.get('phone')

        if not phone:
            return jsonify({"success": False, "error": "휴대폰 번호가 필요합니다."}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        sql = "SELECT COUNT(*) FROM Users WHERE phone = %s"
        cursor.execute(sql, (phone,))
        count = cursor.fetchone()[0]
        
        exists = count > 0
        return jsonify({"success": True, "exists": exists}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (check-phone): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/api/user-locations", methods=["GET"])
def get_user_locations():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401
        
        current_user_id_str = session['user_id']
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        sql = """
            SELECT primary_sido, primary_sigungu, secondary_sido, secondary_sigungu 
            FROM Users WHERE user_id = %s
        """
        cursor.execute(sql, (current_user_id_str,))
        locations = cursor.fetchone()

        if not locations:
            return jsonify({"success": False, "error": "위치 정보를 찾을 수 없습니다."}), 404
            
        return jsonify({"success": True, "locations": locations}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (user-locations): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()


# --- Authentication (SMS Verification) ---

@auth_bp.route("/send-verification", methods=["POST"])
def send_verification_code():
    data = request.get_json()
    if not data or 'phone' not in data:
        return jsonify({"success": False, "error": "휴대폰 번호가 필요합니다."}), 400

    phone_number = data['phone']
    auth_code = str(random.randint(100000, 999999))
    app_hash = os.environ.get('APP_HASH', '')
    
    message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""

    is_success = send_sms(phone_number, message)
    if is_success:
        session['auth_code'] = auth_code
        session['auth_code_expires_at'] = time.time() + 180
        session['phone_number'] = phone_number
        session.permanent = True 
        
        return jsonify({"success": True, "message": "인증번호 발송 성공"}), 200
    else:
        return jsonify({"success": False, "error": "인증번호 발송 실패"}), 500

@auth_bp.route("/verify-code", methods=["POST"])
def verify_code():
    if 'auth_code' not in session or 'auth_code_expires_at' not in session:
        return jsonify({"success": False, "error": "인증 요청 기록이 없습니다."}), 408

    if time.time() > session['auth_code_expires_at']:
        session.pop('auth_code', None)
        session.pop('auth_code_expires_at', None)
        return jsonify({"success": False, "error": "인증 시간 만료"}), 408

    data = request.get_json()
    user_code = data.get('code')
    
    if user_code == session['auth_code']:
        session.pop('auth_code', None)
        session.pop('auth_code_expires_at', None)
        return jsonify({"success": True, "message": "인증 성공"}), 200
    else:
        return jsonify({"success": False, "error": "인증번호 불일치"}), 400


# --- Find ID ---

@auth_bp.route("/find-id/send-code", methods=["POST"])
def find_id_send_code():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        phone = data.get('phone')

        if not phone:
            return jsonify({"success": False, "error": "휴대폰 번호 필요"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM Users WHERE phone = %s", (phone,))
        if cursor.fetchone()[0] == 0:
            return jsonify({"success": False, "error": "가입되지 않은 번호입니다."}), 404

        auth_code = str(random.randint(100000, 999999))
        app_hash = os.environ.get('APP_HASH', '')
        message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""
        
        if not send_sms(phone, message):
            return jsonify({"success": False, "error": "SMS 발송 실패"}), 500

        session['find_id_auth_code'] = auth_code
        session['find_id_phone'] = phone
        session['find_id_auth_code_expires_at'] = time.time() + 180
        session.permanent = True

        return jsonify({"success": True, "message": "인증번호 발송 성공"}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (find-id): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/find-id/verify-code", methods=["POST"])
def find_id_verify_code():
    db_connection = None
    cursor = None
    try:
        if 'find_id_auth_code' not in session or 'find_id_auth_code_expires_at' not in session:
            return jsonify({"success": False, "error": "인증 요청 기록 없음"}), 408

        if time.time() > session['find_id_auth_code_expires_at']:
            session.pop('find_id_auth_code', None)
            session.pop('find_id_auth_code_expires_at', None)
            session.pop('find_id_phone', None)
            return jsonify({"success": False, "error": "인증 시간 만료"}), 408

        data = request.get_json()
        user_code = data.get('code')
        
        if user_code != session['find_id_auth_code']:
            return jsonify({"success": False, "error": "인증번호 불일치"}), 400

        phone = session['find_id_phone']
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        cursor.execute("SELECT user_id FROM Users WHERE phone = %s", (phone,))
        result = cursor.fetchone()
        
        if not result:
            return jsonify({"success": False, "error": "사용자 정보 없음"}), 404

        session.pop('find_id_auth_code', None)
        session.pop('find_id_auth_code_expires_at', None)
        session.pop('find_id_phone', None)
        
        return jsonify({"success": True, "user_id": result[0]}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (find-id-verify): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()


# --- Reset Password ---
# Note: Requires 's' (Serializer) to be imported or passed.
# Since 's' depends on 'app.secret_key', we need a way to access it.
# Option: Create 's' here using 'current_app.secret_key' inside the function,
# or move 's' to extensions.py (requires initialization with app).
# For simplicity, we'll create it inside the route using current_app.

from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadTimeSignature

@auth_bp.route("/reset-pw/send-code", methods=["POST"])
def reset_pw_send_code():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        phone = data.get('phone')

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)
        
        cursor.execute("SELECT phone FROM Users WHERE user_id = %s", (user_id,))
        user = cursor.fetchone()

        if not user:
            return jsonify({"success": False, "error": "존재하지 않는 아이디"}), 404
        if user['phone'] != phone:
            return jsonify({"success": False, "error": "정보 불일치"}), 403

        auth_code = str(random.randint(100000, 999999))
        app_hash = os.environ.get('APP_HASH', '')
        message = f"""<#>[Round] 본인확인 인증번호 [{auth_code}]를 입력해주세요.
{app_hash}"""
        
        send_sms(phone, message)

        session['reset_pw_auth_code'] = auth_code
        session['reset_pw_user_id'] = user_id
        session['reset_pw_auth_code_expires_at'] = time.time() + 180
        session.permanent = True

        return jsonify({"success": True, "message": "인증번호 발송 성공"}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (reset-pw): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/reset-pw/verify-code", methods=["POST"])
def reset_pw_verify_code():
    try:
        if 'reset_pw_auth_code' not in session or 'reset_pw_auth_code_expires_at' not in session:
            return jsonify({"success": False, "error": "인증 요청 기록 없음"}), 408

        if time.time() > session['reset_pw_auth_code_expires_at']:
            session.pop('reset_pw_auth_code', None)
            session.pop('reset_pw_auth_code_expires_at', None)
            session.pop('reset_pw_user_id', None)
            return jsonify({"success": False, "error": "인증 시간 만료"}), 408

        data = request.get_json()
        user_code = data.get('code')
        
        if user_code != session['reset_pw_auth_code']:
            return jsonify({"success": False, "error": "인증번호 불일치"}), 400
        
        user_id = session['reset_pw_user_id']
        
        # Generate Token
        s = URLSafeTimedSerializer(current_app.secret_key)
        token = s.dumps(user_id, salt='password-reset-salt')
        
        session.pop('reset_pw_auth_code', None)
        session.pop('reset_pw_auth_code_expires_at', None)
        session.pop('reset_pw_user_id', None)
        
        return jsonify({"success": True, "token": token}), 200

    except Exception as e:
        current_app.logger.error(f"Token Error: {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500

@auth_bp.route("/reset-pw/set-new", methods=["POST"])
def reset_pw_set_new():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        token = data.get('token')
        new_password = data.get('new_password')

        s = URLSafeTimedSerializer(current_app.secret_key)
        try:
            user_id = s.loads(token, salt='password-reset-salt', max_age=300)
        except SignatureExpired:
            return jsonify({"success": False, "error": "토큰 만료"}), 400
        except BadTimeSignature:
            return jsonify({"success": False, "error": "잘못된 토큰"}), 400
        
        hashed_password = bcrypt.generate_password_hash(new_password).decode('utf-8')
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor()

        cursor.execute("UPDATE Users SET password = %s WHERE user_id = %s", (hashed_password, user_id))
        db_connection.commit()
        
        return jsonify({"success": True, "message": "비밀번호 변경 성공"}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (reset-pw-new): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()


# --- Login & Session ---

@auth_bp.route("/login", methods=["POST"])
def login_user():
    db_connection = None
    cursor = None
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        plain_password = data.get('password')

        if not user_id or not plain_password:
            return jsonify({"success": False, "error": "아이디/비번 입력 필요"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        cursor.execute("SELECT id, user_id, password, name, role, profile_image_url FROM Users WHERE user_id = %s", (user_id,))
        user = cursor.fetchone()

        if user and bcrypt.check_password_hash(user['password'], plain_password):
            current_app.logger.info(f"User '{user_id}' logged in.")

            session['user_id'] = user['user_id']
            session['user_role'] = user['role']
            session['logged_in'] = True
            session.permanent = True
            
            user_data = {
                "id": user['id'],
                "user_id": user['user_id'],
                "name": user['name'],
                "role": user['role'],
                "profile_image_url": user['profile_image_url']
            }

            return jsonify({"success": True, "message": "로그인 성공", "user": user_data}), 200
        else:
            return jsonify({"success": False, "error": "아이디 또는 비밀번호 불일치"}), 401

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (login): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    except Exception as e:
        current_app.logger.error(f"Login Error: {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/api/check-login", methods=["GET"])
def check_login_status():
    db_connection = None
    cursor = None
    try:
        if session.get('logged_in') and session.get('user_id'):
            current_user_id_str = session['user_id']
            
            db_connection = get_db_connection()
            cursor = db_connection.cursor(dictionary=True)
            
            cursor.execute("SELECT id, user_id, name, role, profile_image_url FROM Users WHERE user_id = %s", (current_user_id_str,))
            user = cursor.fetchone()

            if user:
                session.permanent = True
                return jsonify({"success": True, "user": user}), 200
            else:
                session.clear()
                return jsonify({"success": False, "error": "사용자 정보 없음"}), 404
        
        return jsonify({"success": False, "error": "로그인 필요"}), 401

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (check-login): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    except Exception as e:
        current_app.logger.error(f"Error (check-login): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@auth_bp.route("/api/update-fcm-token", methods=["POST"])
def update_fcm_token():
    db_connection = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False}), 401

        data = request.get_json()
        fcm_token = data.get('fcm_token')
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        # 현재 사용자의 토큰 업데이트
        cursor.execute("UPDATE Users SET fcm_token = %s WHERE user_id = %s", 
                       (fcm_token, session['user_id']))
        db_connection.commit()
        
        return jsonify({"success": True}), 200
    except Exception as e:
        current_app.logger.error(f"FCM Update Error: {e}")
        return jsonify({"success": False}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()