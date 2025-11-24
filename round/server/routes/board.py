from flask import Blueprint, request, jsonify, session, current_app
import mysql.connector
import os
from google.cloud import storage
from werkzeug.utils import secure_filename
from utils.db import get_db_connection # Use the DB utility

board_bp = Blueprint('board', __name__)

# --- Posts ---

@board_bp.route("/api/posts", methods=["POST"])
def create_post():
    db_connection = None
    cursor = None
    try:
        # 1. Check Login
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        # 2. Get Data
        club_id = request.form.get('club_id')
        title = request.form.get('title')
        content = request.form.get('content')
        post_image = request.files.get('post_image')
        image_url = None
        
        if not club_id or not title or not content:
             return jsonify({"success": False, "error": "필수 정보가 누락되었습니다."}), 400

        # 3. Upload Image (Optional)
        if post_image:
            filename = secure_filename(post_image.filename)
            storage_client = storage.Client()
            bucket = storage_client.bucket(os.environ.get('GCS_BUCKET'))
            blob = bucket.blob(f"posts/{filename}")
            
            image_bytes = post_image.read()
            blob.upload_from_string(image_bytes, content_type=post_image.content_type)
            image_url = blob.public_url

        # 4. DB Connection
        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        # Get Author ID (numeric)
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "사용자 정보를 찾을 수 없습니다."}), 404
        
        author_id = user_record[0]

        # 5. Insert Post
        sql = """INSERT INTO Posts (club_id, user_id, title, content, image_url)
                 VALUES (%s, %s, %s, %s, %s)"""
        val = (club_id, author_id, title, content, image_url)
        
        cursor.execute(sql, val)
        db_connection.commit()
        
        return jsonify({"success": True, "message": "게시글이 등록되었습니다."}), 201

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (create_post): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    except Exception as e:
        current_app.logger.error(f"Server Error (create_post): {e}", exc_info=True)
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@board_bp.route("/api/posts", methods=["GET"])
def get_posts():
    db_connection = None
    cursor = None
    try:
        club_id = request.args.get('club_id')
        if not club_id:
            return jsonify({"success": False, "error": "club_id가 필요합니다."}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # Get Posts with Author Info & Comment Count
        sql = """
            SELECT 
                P.id, P.title, P.content, P.image_url, P.likes,
                DATE_FORMAT(P.created_at, '%Y-%m-%d %H:%i') as time,
                U.name as author_name, U.profile_image_url as author_image,
                (SELECT COUNT(*) FROM Comments C WHERE C.post_id = P.id) as comment_count
            FROM Posts P
            JOIN Users U ON P.user_id = U.id
            WHERE P.club_id = %s
            ORDER BY P.created_at DESC
        """
        cursor.execute(sql, (club_id,))
        posts = cursor.fetchall()

        for post in posts:
             if 'comment_count' not in post or post['comment_count'] is None:
                 post['comment_count'] = 0

        return jsonify({"success": True, "posts": posts}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_posts): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()


# --- Comments ---

@board_bp.route("/api/comments", methods=["POST"])
def create_comment():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        data = request.get_json()
        post_id = data.get('post_id')
        content = data.get('content')

        if not post_id or not content:
             return jsonify({"success": False, "error": "내용을 입력해주세요."}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor()
        
        # Get Author ID
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        author_id = cursor.fetchone()[0]

        # Insert Comment
        sql = "INSERT INTO Comments (post_id, user_id, content) VALUES (%s, %s, %s)"
        cursor.execute(sql, (post_id, author_id, content))
        db_connection.commit()
        
        return jsonify({"success": True, "message": "댓글이 등록되었습니다."}), 201

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (create_comment): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@board_bp.route("/api/comments", methods=["GET"])
def get_comments():
    db_connection = None
    cursor = None
    try:
        post_id = request.args.get('post_id')
        
        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # Get Comments with Author Info
        sql = """
            SELECT 
                C.id, C.content,
                DATE_FORMAT(C.created_at, '%m/%d %H:%i') as time,
                U.name as author_name, U.profile_image_url as author_image
            FROM Comments C
            JOIN Users U ON C.user_id = U.id
            WHERE C.post_id = %s
            ORDER BY C.created_at ASC
        """
        cursor.execute(sql, (post_id,))
        comments = cursor.fetchall()

        return jsonify({"success": True, "comments": comments}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (get_comments): {e}")
        return jsonify({"success": False, "error": "데이터베이스 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@board_bp.route("/api/posts/like", methods=["POST"])
def toggle_like():
    db_connection = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401

        data = request.get_json()
        post_id = data.get('post_id')
        if not post_id:
             return jsonify({"success": False, "error": "post_id 필요"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor()

        # 1. 사용자 ID 찾기
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_id = cursor.fetchone()[0]

        # 2. 좋아요 여부 확인
        cursor.execute("SELECT 1 FROM PostLikes WHERE post_id = %s AND user_id = %s", (post_id, user_id))
        liked = cursor.fetchone()

        if liked:
            # 이미 좋아요 상태 -> 취소 (DELETE) & Posts.likes 감소
            cursor.execute("DELETE FROM PostLikes WHERE post_id = %s AND user_id = %s", (post_id, user_id))
            cursor.execute("UPDATE Posts SET likes = likes - 1 WHERE id = %s", (post_id,))
            message = "unliked"
        else:
            # 좋아요 안 한 상태 -> 추가 (INSERT) & Posts.likes 증가
            cursor.execute("INSERT INTO PostLikes (post_id, user_id) VALUES (%s, %s)", (post_id, user_id))
            cursor.execute("UPDATE Posts SET likes = likes + 1 WHERE id = %s", (post_id,))
            message = "liked"

        db_connection.commit()
        
        # 변경된 좋아요 수 조회
        cursor.execute("SELECT likes FROM Posts WHERE id = %s", (post_id,))
        new_like_count = cursor.fetchone()[0]
        
        return jsonify({"success": True, "message": message, "likes": new_like_count}), 200

    except Exception as e:
        if db_connection: db_connection.rollback()
        current_app.logger.error(f"Like Error: {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()

@board_bp.route("/api/posts/detail", methods=["GET"])
def get_post_detail():
    db_connection = None
    cursor = None
    try:
        post_id = request.args.get('post_id')
        if not post_id:
            return jsonify({"success": False, "error": "post_id 필요"}), 400

        db_connection = get_db_connection()
        cursor = db_connection.cursor(dictionary=True)

        # 1. 현재 로그인한 사용자의 DB PK(숫자 ID) 찾기
        # (로그인하지 않았다면 None으로 처리하여 is_liked 계산 시 0이 되도록 함)
        current_user_db_id = None
        if 'user_id' in session:
            cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
            user_record = cursor.fetchone()
            if user_record:
                current_user_db_id = user_record[0]

        # 2. 게시글 상세 정보 조회 (+ is_liked 계산)
        sql = """
            SELECT 
                P.id, P.title, P.content, P.image_url, P.likes,
                DATE_FORMAT(P.created_at, '%%Y-%%m-%%d %%H:%%i') as time,
                U.name as author_name, U.profile_image_url as author_image,
                (SELECT COUNT(*) FROM Comments C WHERE C.post_id = P.id) as comment_count,
                
                -- 👇 내가 좋아요를 눌렀는지 확인 (1이면 True, 0이면 False)
                (SELECT COUNT(*) FROM PostLikes PL WHERE PL.post_id = P.id AND PL.user_id = %s) as is_liked
                
            FROM Posts P
            JOIN Users U ON P.user_id = U.id
            WHERE P.id = %s
        """
        # 파라미터 순서: 사용자ID(is_liked용), 게시글ID(WHERE절용)
        cursor.execute(sql, (current_user_db_id, post_id))
        post = cursor.fetchone()

        if not post:
            return jsonify({"success": False, "error": "삭제되었거나 존재하지 않는 게시글입니다."}), 404

        return jsonify({"success": True, "post": post}), 200

    except mysql.connector.Error as e:
        current_app.logger.error(f"DB Error (post_detail): {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if db_connection and db_connection.is_connected():
            db_connection.close()