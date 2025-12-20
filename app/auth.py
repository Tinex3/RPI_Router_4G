from dataclasses import dataclass
from flask_login import UserMixin
from werkzeug.security import check_password_hash, generate_password_hash
from .config import load_config, save_config

@dataclass
class User(UserMixin):
    id: str
    username: str

def ensure_password_hash(default_password: str = "admin1234") -> None:
    """Asegura que exista un hash de password, si no lo crea con contraseña por defecto"""
    cfg = load_config()
    if not cfg.get("auth"):
        cfg["auth"] = {"username": "admin", "password_hash": ""}
    if not cfg["auth"].get("password_hash"):
        cfg["auth"]["password_hash"] = generate_password_hash(default_password)
        save_config(cfg)

def authenticate(username: str, password: str) -> User | None:
    """Autentica usuario y retorna objeto User si es válido"""
    cfg = load_config()
    auth = cfg.get("auth", {})
    if username == auth.get("username") and check_password_hash(auth.get("password_hash", ""), password):
        return User(id="1", username=username)
    return None

def get_user() -> User:
    """Retorna el usuario configurado"""
    cfg = load_config()
    return User(id="1", username=cfg["auth"]["username"])
