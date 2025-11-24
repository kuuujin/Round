import mysql.connector
import os

def get_db_connection():
    """
    환경 변수에서 설정을 읽어와 DB 연결 객체를 반환합니다.
    """
    db_config = {
        'host': os.environ.get('DB_HOST'),
        'user': os.environ.get('DB_USER'),
        'password': os.environ.get('DB_PASSWORD'),
        'database': os.environ.get('DB_NAME')
    }
    
    # 연결 객체 반환
    return mysql.connector.connect(**db_config)