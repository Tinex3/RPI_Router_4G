import logging
from flask import Blueprint, jsonify, render_template, request, redirect, url_for, flash
from flask_login import login_user, logout_user, login_required, current_user

from .modem import get_network_info, get_signal, set_apn, reset_modem
from .config import load_config, save_config
from .network import active_wan
from .firewall import apply_firewall
from .speedtest import run_speedtest

web = Blueprint("web", __name__)

@web.route("/login", methods=["GET", "POST"])
def login():
    from .auth import authenticate
    if request.method == "POST":
        u = request.form.get("username", "")
        p = request.form.get("password", "")
        user = authenticate(u, p)
        if user:
            login_user(user)
            logging.info("User %s logged in", u)
            return redirect(url_for("web.dashboard"))
        flash("Credenciales inválidas", "error")
        logging.warning("Failed login attempt for user %s", u)
    return render_template("login.html")

@web.route("/logout")
@login_required
def logout():
    logging.info("User %s logged out", current_user.username)
    logout_user()
    return redirect(url_for("web.login"))

@web.route("/")
@login_required
def dashboard():
    return render_template("dashboard.html", username=current_user.username)

@web.route("/settings")
@login_required
def settings():
    cfg = load_config()
    return render_template("settings.html", cfg=cfg)

@web.route("/api/signal")
@login_required
def api_signal():
    return jsonify(get_signal())

@web.route("/api/modem/info")
@login_required
def api_modem_info():
    return jsonify(get_network_info())

@web.route("/api/modem/reset", methods=["POST"])
@login_required
def api_reset():
    result = reset_modem()
    logging.info("Modem reset requested by %s", current_user.username)
    return jsonify({"ok": True, "response": result})

@web.route("/api/apn", methods=["POST"])
@login_required
def api_set_apn():
    apn = request.json.get("apn", "").strip()
    if not apn:
        return jsonify({"ok": False, "error": "APN vacío"}), 400
    set_apn(apn)
    cfg = load_config()
    cfg["apn"] = apn
    save_config(cfg)
    logging.info("APN updated to %s by %s", apn, current_user.username)
    return jsonify({"ok": True})

@web.route("/api/wan")
@login_required
def api_wan():
    return jsonify({"active": active_wan(), "mode": load_config().get("wan_mode", "auto")})

@web.route("/api/wan", methods=["POST"])
@login_required
def api_set_wan():
    mode = request.json.get("mode", "auto")
    if mode not in ("auto", "eth", "lte"):
        return jsonify({"ok": False, "error": "Modo inválido"}), 400
    cfg = load_config()
    cfg["wan_mode"] = mode
    save_config(cfg)
    logging.info("WAN mode set to %s by %s", mode, current_user.username)
    return jsonify({"ok": True, "mode": mode})

@web.route("/api/security", methods=["POST"])
@login_required
def api_security():
    cfg = load_config()
    sec = cfg.setdefault("security", {})
    sec["isolate_clients"] = bool(request.json.get("isolate_clients", True))
    save_config(cfg)
    
    # Aplicar firewall inmediatamente
    try:
        apply_firewall()
        logging.info("Firewall applied. isolate_clients=%s by %s", sec["isolate_clients"], current_user.username)
        return jsonify({"ok": True})
    except Exception as e:
        logging.error("Error applying firewall: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 500

@web.route("/api/speedtest", methods=["POST"])
@login_required
def api_speedtest():
    """Ejecuta test de velocidad (puede tardar 30-60 segundos)"""
    logging.info("Speedtest iniciado por %s", current_user.username)
    result = run_speedtest()
    return jsonify(result)
