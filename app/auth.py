from dataclasses import dataclass
from flask_login import UserMixin
from werkzeug.security import check_password_hash, generate_password_hash

def get_env_password():
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                if line.startswith("WEB_PASSWORD="):
                    return line.strip().split("=",1)[1]
    return "admin"

def set_env_password(new_password):
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    lines = []
    found = False
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                if line.startswith("WEB_PASSWORD="):
                    lines.append(f"WEB_PASSWORD={new_password}\n")
                    found = True
                else:
                    lines.append(line)
    if not found:
        lines.append(f"WEB_PASSWORD={new_password}\n")
    with open(env_path, "w") as f:
        f.writelines(lines)

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
    # Usuario fijo: admin
    env_pass = get_env_password()
    if username == "admin" and password == env_pass:
        return User(id="1", username=username)
    return None

def get_user() -> User:
    """Retorna el usuario configurado"""
    cfg = load_config()
    return User(id="1", username=cfg["auth"]["username"])
