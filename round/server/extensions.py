from flask_bcrypt import Bcrypt

# 여기서 인스턴스만 생성하고, 나중에 app.py에서 init_app()으로 연결합니다.
bcrypt = Bcrypt()