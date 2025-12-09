from flask import Blueprint, request, jsonify, session, current_app
import mysql.connector
import os
from google.cloud import storage
from werkzeug.utils import secure_filename
from utils.db import get_db_connection

board_bp = Blueprint('board', __name__)

# ==========================================
# 1. 게시글 생성 및 조회 (Posts)
# ==========================================

@board_bp.route("/api/posts", methods=["POST"])
def create_post():
    conn = None
    cursor = None
    try:
        # 1. 로그인 확인
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인이 필요합니다."}), 401

        # 2. 데이터 수신
        club_id = request.form.get('club_id')
        title = request.form.get('title')
        content = request.form.get('content')
        post_image = request.files.get('post_image')
        image_url = None
        
        if not club_id or not title or not content:
             return jsonify({"success": False, "error": "필수 정보가 누락되었습니다."}), 400

        # 3. 이미지 업로드 (GCS)
        if post_image:
            filename = secure_filename(post_image.filename)
            storage_client = storage.Client()
            bucket = storage_client.bucket(os.environ.get('GCS_BUCKET'))
            blob = bucket.blob(f"posts/{filename}")
            
            image_bytes = post_image.read()
            blob.upload_from_string(image_bytes, content_type=post_image.content_type)
            image_url = blob.public_url

        # 4. DB 연결
        conn = get_db_connection()
        if conn is None: return jsonify({"success": False, "error": "DB Connection Failed"}), 500
        cursor = conn.cursor()
        
        # 5. 작성자 PK 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_record = cursor.fetchone()
        if not user_record:
            return jsonify({"success": False, "error": "사용자 정보를 찾을 수 없습니다."}), 404
        
        author_id = user_record[0]

        # 6. 게시글 저장
        sql = """INSERT INTO Posts (club_id, user_id, title, content, image_url)
                 VALUES (%s, %s, %s, %s, %s)"""
        val = (club_id, author_id, title, content, image_url)
        
        cursor.execute(sql, val)
        conn.commit()
        
        return jsonify({"success": True, "message": "게시글이 등록되었습니다."}), 201

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Error creating post: {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@board_bp.route("/api/posts", methods=["GET"])
def get_posts():
    conn = None
    cursor = None
    try:
        club_id = request.args.get('club_id')
        if not club_id:
            return jsonify({"success": False, "error": "club_id required"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        # 게시글 목록 조회 (작성자 정보 & 댓글 수 포함)
        sql = """
            SELECT 
                P.id, P.title, P.content, P.image_url, P.likes,
                DATE_FORMAT(P.created_at, '%%Y-%%m-%%d %%H:%%i') as time,
                U.name as author_name, U.profile_image_url as author_image,
                (SELECT COUNT(*) FROM Comments C WHERE C.post_id = P.id) as comment_count
            FROM Posts P
            JOIN Users U ON P.user_id = U.id
            WHERE P.club_id = %s
            ORDER BY P.created_at DESC
        """
        cursor.execute(sql, (club_id,))
        posts = cursor.fetchall()

        return jsonify({"success": True, "posts": posts}), 200

    except Exception as e:
        current_app.logger.error(f"Error fetching posts: {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@board_bp.route("/api/posts/detail", methods=["GET"])
def get_post_detail():
    conn = None
    cursor = None
    try:
        post_id = request.args.get('post_id')
        if not post_id:
            return jsonify({"success": False, "error": "post_id required"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        # 현재 로그인 유저 ID (좋아요 여부 확인용)
        current_user_db_id = None
        if 'user_id' in session:
            cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
            user_record = cursor.fetchone()
            if user_record: current_user_db_id = user_record['id']

        # 게시글 상세 조회 (+ is_liked)
        sql = """
            SELECT 
                P.id, P.title, P.content, P.image_url, P.likes,
                DATE_FORMAT(P.created_at, '%%Y-%%m-%%d %%H:%%i') as time,
                U.name as author_name, U.profile_image_url as author_image,
                (SELECT COUNT(*) FROM Comments C WHERE C.post_id = P.id) as comment_count,
                (SELECT COUNT(*) FROM PostLikes PL WHERE PL.post_id = P.id AND PL.user_id = %s) as is_liked
            FROM Posts P
            JOIN Users U ON P.user_id = U.id
            WHERE P.id = %s
        """
        cursor.execute(sql, (current_user_db_id, post_id))
        post = cursor.fetchone()

        if not post:
            return jsonify({"success": False, "error": "Post not found"}), 404

        # is_liked를 boolean으로 변환
        post['is_liked'] = bool(post['is_liked'])

        return jsonify({"success": True, "post": post}), 200

    except Exception as e:
        current_app.logger.error(f"Error post detail: {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@board_bp.route("/api/posts/like", methods=["POST"])
def toggle_like():
    conn = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401

        data = request.get_json()
        post_id = data.get('post_id')
        
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. 사용자 PK 조회
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        user_id = cursor.fetchone()[0]

        # 2. 좋아요 여부 확인 및 토글
        cursor.execute("SELECT 1 FROM PostLikes WHERE post_id = %s AND user_id = %s", (post_id, user_id))
        liked = cursor.fetchone()

        if liked:
            cursor.execute("DELETE FROM PostLikes WHERE post_id = %s AND user_id = %s", (post_id, user_id))
            cursor.execute("UPDATE Posts SET likes = likes - 1 WHERE id = %s", (post_id,))
            message = "unliked"
        else:
            cursor.execute("INSERT INTO PostLikes (post_id, user_id) VALUES (%s, %s)", (post_id, user_id))
            cursor.execute("UPDATE Posts SET likes = likes + 1 WHERE id = %s", (post_id,))
            message = "liked"

        conn.commit()
        
        # 최신 좋아요 수 반환
        cursor.execute("SELECT likes FROM Posts WHERE id = %s", (post_id,))
        new_like_count = cursor.fetchone()[0]
        
        return jsonify({"success": True, "message": message, "likes": new_like_count}), 200

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Like Error: {e}")
        return jsonify({"success": False, "error": "서버 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


# ==========================================
# 2. 댓글 관리 (Comments)
# ==========================================

@board_bp.route("/api/comments", methods=["POST"])
def create_comment():
    conn = None
    cursor = None
    try:
        if 'user_id' not in session:
            return jsonify({"success": False, "error": "로그인 필요"}), 401

        data = request.get_json()
        post_id = data.get('post_id')
        content = data.get('content')

        if not post_id or not content:
             return jsonify({"success": False, "error": "내용을 입력해주세요."}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM Users WHERE user_id = %s", (session['user_id'],))
        author_id = cursor.fetchone()[0]

        sql = "INSERT INTO Comments (post_id, user_id, content) VALUES (%s, %s, %s)"
        cursor.execute(sql, (post_id, author_id, content))
        conn.commit()
        
        return jsonify({"success": True, "message": "댓글 등록 완료"}), 201

    except Exception as e:
        if conn: conn.rollback()
        current_app.logger.error(f"Error create comment: {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()


@board_bp.route("/api/comments", methods=["GET"])
def get_comments():
    conn = None
    cursor = None
    try:
        post_id = request.args.get('post_id')
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True, buffered=True)

        sql = """
            SELECT 
                C.id, C.content,
                DATE_FORMAT(C.created_at, '%%m/%%d %%H:%%i') as time,
                U.name as author_name, U.profile_image_url as author_image
            FROM Comments C
            JOIN Users U ON C.user_id = U.id
            WHERE C.post_id = %s
            ORDER BY C.created_at ASC
        """
        cursor.execute(sql, (post_id,))
        comments = cursor.fetchall()

        return jsonify({"success": True, "comments": comments}), 200

    except Exception as e:
        current_app.logger.error(f"Error get comments: {e}")
        return jsonify({"success": False, "error": "DB 오류"}), 500
    finally:
        if cursor: cursor.close()
        if conn and conn.is_connected(): conn.close()