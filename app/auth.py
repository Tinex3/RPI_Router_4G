import os
from dataclasses import dataclass
from flask_login import UserMixin

@dataclass
class User(UserMixin):
    id: str
    username: str

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

def authenticate(username: str, password: str) -> User | None:
    env_pass = get_env_password()
    if username == "admin" and password == env_pass:
        return User(id="1", username=username)
    return None

def get_user() -> User:
    """Retorna el usuario admin"""
    return User(id="1", username="admin")
