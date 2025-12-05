import os
from datetime import timedelta
from utils.db import get_db_connection
from flask import Flask, request, session, jsonify
from flask_socketio import SocketIO, emit, join_room
import firebase_admin
from firebase_admin import credentials, messaging
from extensions import bcrypt, socketio
from routes.auth import auth_bp
from routes.clubs import clubs_bp
from routes.board import board_bp
from routes.match import match_bp

app = Flask(__name__)

# 설정
app.secret_key = os.environ.get('FLASK_SECRET_KEY')
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)

bcrypt.init_app(app)
socketio.init_app(app, cors_allowed_origins="*", async_mode='eventlet')
cred = credentials.Certificate("/var/www/round/firebase-key.json")
firebase_admin.initialize_app(cred)

app.register_blueprint(auth_bp)
app.register_blueprint(clubs_bp)
app.register_blueprint(board_bp)
app.register_blueprint(match_bp)

@app.route("/")
def hello():
    return "<h1>Round API Server is Running!</h1>"

@socketio.on('connect')
def handle_connect():
    print(f"✅ Client connected: {request.sid}")

@socketio.on('disconnect')
def handle_disconnect():
    # 연결이 끊기면 대기열에서 제거하는 로직을 여기에 추가하면 좋습니다.
    print(f"❌ Client disconnected: {request.sid}")

@socketio.on('join')
def handle_join(data):
    user_id = data.get('user_id')
    room = f"user_{user_id}"
    join_room(room) # 해당 유저를 위한 전용 방에 입장
    print(f"👥 User {user_id} joined room: {room}")

@socketio.on('join_chat')
def handle_join_chat(data):
    room = data.get('room') # match_id
    join_room(room)
    print(f"💬 User joined chat room: {room}")

@socketio.on('send_message')
def handle_send_message(data):
    room = data.get('room') # match_id
    message = data.get('message')
    user_id_str = data.get('user_id') # 클라이언트가 보낸 user_id (문자열)
    
    # DB 연결
    db_connection = get_db_connection()
    cursor = db_connection.cursor()
    
    # user_id(문자열) -> id(숫자) 변환
    cursor.execute("SELECT id FROM Users WHERE user_id = %s", (user_id_str,))
    user = cursor.fetchone()
    if user:
        user_db_id = user[0]
        # 메시지 저장
        cursor.execute("INSERT INTO ChatMessages (match_id, user_id, message) VALUES (%s, %s, %s)", 
                       (room, user_db_id, message))
        db_connection.commit()

    cursor.close()
    db_connection.close()
    
    # 전송 (기존 로직 동일)
    print(f"📩 Message saved & sent in {room}: {message}")
    emit('new_message', {
        'sender': user_id_str, 
        'message': message
    }, room=room)

            
if __name__ == "__main__":
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)