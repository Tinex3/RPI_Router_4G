from flask import Flask
from flask_login import LoginManager
from .web import web
from .auth import get_user
from .logging_config import setup_logging
from .ec25_monitor import start_monitor, set_monitor_enabled
from .web import get_ec25_enabled
import os

def create_app() -> Flask:
    # Detecta el directorio base del proyecto (donde está run.py)
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    
    # Flask usa rutas absolutas para templates y static
    app = Flask(__name__,
                template_folder=os.path.join(base_dir, 'templates'),
                static_folder=os.path.join(base_dir, 'static'))
    app.secret_key = "change-this-secret-in-prod-ec25-router"

    # Setup logging rotativo
    try:
        setup_logging()
    except:
        # Si falla (permisos), usa logging por defecto
        import logging
        logging.basicConfig(level=logging.INFO)

    # Flask-Login setup
    login = LoginManager()
    login.login_view = "web.login"
    login.init_app(app)

    @login.user_loader
    def load_user(user_id: str):
        return get_user()

    app.register_blueprint(web)
    
    # Iniciar monitor EC25 en hilo separado
    ec25_enabled = get_ec25_enabled()
    start_monitor(update_interval=5.0, enabled=ec25_enabled)
    
    return app
