import os
from datetime import timedelta
from flask import Flask, request
from flask_socketio import SocketIO, emit, join_room
import firebase_admin
from firebase_admin import credentials
from extensions import bcrypt, socketio
from utils.db import get_db_connection

# Blueprints
from routes.auth import auth_bp
from routes.clubs import clubs_bp
from routes.board import board_bp
from routes.match import match_bp

app = Flask(__name__)

# ==========================================
# 1. 앱 설정 (Configuration)
# ==========================================

app.secret_key = os.environ.get('FLASK_SECRET_KEY')
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)

# 확장 라이브러리 초기화
bcrypt.init_app(app)
socketio.init_app(app, cors_allowed_origins="*", async_mode='eventlet')

# Firebase 초기화
if not firebase_admin._apps:
    cred = credentials.Certificate("/var/www/round/firebase-key.json")
    firebase_admin.initialize_app(cred)

# Blueprint 등록
app.register_blueprint(auth_bp)
app.register_blueprint(clubs_bp)
app.register_blueprint(board_bp)
app.register_blueprint(match_bp)

@app.route("/")
def hello():
    return "<h1>Round API Server is Running!</h1>"


# ==========================================
# 2. 소켓 핸들러 (Socket.IO Handlers)
# ==========================================

@socketio.on('connect')
def handle_connect():
    app.logger.info(f"✅ Client connected: {request.sid}")

@socketio.on('disconnect')
def handle_disconnect():
    app.logger.info(f"❌ Client disconnected: {request.sid}")

@socketio.on('join')
def handle_join(data):
    """
    사용자별 전용 채널 입장 (알림용)
    """
    user_id = data.get('user_id')
    if user_id:
        room = f"user_{user_id}"
        join_room(room)
        app.logger.info(f"👥 User {user_id} joined notification room: {room}")

@socketio.on('join_chat')
def handle_join_chat(data):
    """
    특정 채팅방 입장 (경기 매칭 방)
    """
    room = data.get('room')     # room_id (UUID)
    user_id = data.get('user_id')
    
    if room:
        join_room(room) # 해당 방의 메시지를 받기 위해 필수
        app.logger.info(f"🚪 [Socket Join] User: {user_id}, Room: {room}, SID: {request.sid}")

@socketio.on('send_message')
def handle_send_message(data):
    """
    메시지 수신, DB 저장 및 브로드캐스트
    """
    room = data.get('room')
    user_id_str = data.get('user_id')
    message = data.get('message')
    
    app.logger.info(f"📨 [Socket Msg] Room: {room}, User: {user_id_str}")

    conn = None
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True) 
            
            # 1. 유저 PK 조회
            cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
            user_row = cursor.fetchone()
            
            if user_row:
                user_db_id = user_row['id'] 
                
                # 2. 채팅 로그 DB 저장
                sql = "INSERT INTO ChatMessages (match_id, user_id, message) VALUES (%s, %s, %s)"
                cursor.execute(sql, (room, user_db_id, message))
                conn.commit()
            else:
                app.logger.warning(f"User not found for chat: {user_id_str}")
            
            cursor.close()
        else:
            app.logger.error("DB Connection failed during chat save")

    except Exception as e:
        app.logger.error(f"❌ Chat Save Error: {e}")
        if conn: conn.rollback()
    finally:
        if conn: conn.close()

    # 3. 메시지 전송 (DB 저장 성공 여부와 관계없이 전송하여 반응성 확보)
    emit('new_message', {
        'sender': user_id_str,
        'message': message,
        'match_id': room
    }, room=room)


if __name__ == "__main__":
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)