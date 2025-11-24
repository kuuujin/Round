import os
from datetime import timedelta
from flask import Flask
# 👇👇👇 만든 모듈들 import 👇👇👇
from extensions import bcrypt
from routes.auth import auth_bp
from routes.clubs import clubs_bp
from routes.board import board_bp

app = Flask(__name__)

# 설정
app.secret_key = os.environ.get('FLASK_SECRET_KEY')
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)

bcrypt.init_app(app)

app.register_blueprint(auth_bp)
app.register_blueprint(clubs_bp)
app.register_blueprint(board_bp)

@app.route("/")
def hello():
    return "<h1>Round API Server is Running!</h1>"

if __name__ == "__main__":
    app.run(debug=True)