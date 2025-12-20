from flask import Flask
from flask_login import LoginManager
from .web import web
from .auth import get_user, ensure_password_hash
from .logging_config import setup_logging

def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = "change-this-secret-in-prod-ec25-router"

    # Setup logging rotativo
    try:
        setup_logging()
    except:
        # Si falla (permisos), usa logging por defecto
        import logging
        logging.basicConfig(level=logging.INFO)

    # Asegura que exista password hash
    ensure_password_hash()  # creates default hash if empty

    # Flask-Login setup
    login = LoginManager()
    login.login_view = "web.login"
    login.init_app(app)

    @login.user_loader
    def load_user(user_id: str):
        return get_user()

    app.register_blueprint(web)
    return app
