import logging
import subprocess
import re
import os
from flask import Blueprint, jsonify, render_template, request, redirect, url_for, flash
from flask_login import login_user, logout_user, login_required, current_user

from .modem import get_network_info, get_signal, set_apn, reset_modem
from .config import load_config, save_config
from .network import active_wan
from .firewall import apply_firewall
from .speedtest import run_speedtest

web = Blueprint("web", __name__)

# ============== Helper Functions ==============

def get_system_info():
    """Obtiene informacion del sistema"""
    info = {
        "hostname": "Unknown",
        "uptime": "Unknown",
        "cpu_temp": "N/A",
        "memory_used": 0,
        "memory_total": 0,
        "disk_used": 0,
        "disk_total": 0
    }
    
    try:
        # Hostname
        info["hostname"] = subprocess.check_output(["hostname"], text=True).strip()
        
        # Uptime
        with open("/proc/uptime", "r") as f:
            uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            mins = int((uptime_seconds % 3600) // 60)
            info["uptime"] = f"{days}d {hours}h {mins}m"
            info["uptime_seconds"] = uptime_seconds
        
        # CPU Temperature
        if os.path.exists("/sys/class/thermal/thermal_zone0/temp"):
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                temp = int(f.read().strip()) / 1000
                info["cpu_temp"] = f"{temp:.1f}C"
        
        # Memory
        with open("/proc/meminfo", "r") as f:
            meminfo = f.read()
            total = int(re.search(r"MemTotal:\s+(\d+)", meminfo).group(1)) * 1024
            available = int(re.search(r"MemAvailable:\s+(\d+)", meminfo).group(1)) * 1024
            info["memory_total"] = total
            info["memory_used"] = total - available
            info["memory_percent"] = round((total - available) / total * 100, 1)
        
        # Disk
        stat = os.statvfs("/")
        info["disk_total"] = stat.f_blocks * stat.f_frsize
        info["disk_used"] = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        info["disk_percent"] = round(info["disk_used"] / info["disk_total"] * 100, 1)
        
    except Exception as e:
        logging.error("Error getting system info: %s", e)
    
    return info

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

@web.route("/network")
@login_required
def network_config():
    return render_template("network.html", username=current_user.username)

@web.route("/settings")
@login_required
def settings():
    cfg = load_config()
    return render_template("settings.html", cfg=cfg, username=current_user.username)

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


# ============== WiFi AP Configuration ==============

def read_hostapd_config():
    """Lee configuracion actual de hostapd"""
    config = {"ssid": "", "password": "", "channel": "6"}
    try:
        with open("/etc/hostapd/hostapd.conf", "r") as f:
            content = f.read()
            
        ssid_match = re.search(r'^ssid=(.+)$', content, re.MULTILINE)
        pass_match = re.search(r'^wpa_passphrase=(.+)$', content, re.MULTILINE)
        chan_match = re.search(r'^channel=(\d+)$', content, re.MULTILINE)
        
        if ssid_match:
            config["ssid"] = ssid_match.group(1).strip()
        if pass_match:
            config["password"] = pass_match.group(1).strip()
        if chan_match:
            config["channel"] = chan_match.group(1).strip()
            
    except FileNotFoundError:
        logging.warning("hostapd.conf not found")
    except Exception as e:
        logging.error("Error reading hostapd config: %s", e)
    
    return config


def write_hostapd_config(ssid, password, channel):
    """Escribe configuracion en hostapd.conf"""
    config_content = f"""# Hostapd configuration - WiFi Access Point
# Auto-generated by RPI Router Panel

interface=wlan0
driver=nl80211
ssid={ssid}
hw_mode=g
channel={channel}
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
country_code=CL
ieee80211n=1
ieee80211d=1
"""
    
    with open("/etc/hostapd/hostapd.conf", "w") as f:
        f.write(config_content)


@web.route("/api/wifi/config")
@login_required
def api_wifi_config():
    """Obtiene configuracion WiFi actual"""
    config = read_hostapd_config()
    # No enviar password completo por seguridad
    if config["password"]:
        config["password_masked"] = "*" * len(config["password"])
    return jsonify(config)


@web.route("/api/wifi/config", methods=["POST"])
@login_required
def api_wifi_set_config():
    """Guarda configuracion WiFi y reinicia hostapd"""
    data = request.json
    
    ssid = data.get("ssid", "").strip()
    password = data.get("password", "").strip()
    channel = data.get("channel", "6").strip()
    
    # Validaciones
    if not ssid:
        return jsonify({"ok": False, "error": "SSID no puede estar vacio"}), 400
    
    if len(ssid) > 32:
        return jsonify({"ok": False, "error": "SSID muy largo (max 32 caracteres)"}), 400
    
    # Si no se proporciona password, mantener el actual
    if not password:
        current_config = read_hostapd_config()
        password = current_config.get("password", "")
    
    if len(password) < 8:
        return jsonify({"ok": False, "error": "Password debe tener minimo 8 caracteres"}), 400
    
    if len(password) > 63:
        return jsonify({"ok": False, "error": "Password muy largo (max 63 caracteres)"}), 400
    
    if channel not in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]:
        return jsonify({"ok": False, "error": "Canal invalido"}), 400
    
    try:
        # Guardar configuracion
        write_hostapd_config(ssid, password, channel)
        logging.info("WiFi config updated: SSID=%s, channel=%s by %s", ssid, channel, current_user.username)
        
        # Reiniciar hostapd
        subprocess.run(["systemctl", "restart", "hostapd"], check=True, timeout=30)
        logging.info("hostapd restarted successfully")
        
        return jsonify({
            "ok": True, 
            "message": "Configuracion guardada. WiFi reiniciado.",
            "ssid": ssid,
            "channel": channel
        })
        
    except subprocess.CalledProcessError as e:
        logging.error("Error restarting hostapd: %s", e)
        return jsonify({"ok": False, "error": "Error al reiniciar WiFi. Revisa los logs."}), 500
    except Exception as e:
        logging.error("Error saving WiFi config: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 500


# ============== WiFi Status & Scan ==============

@web.route("/api/wifi/status")
@login_required
def api_wifi_status():
    """Obtiene estado del Access Point"""
    status = {
        "running": False,
        "clients": 0,
        "ip": "192.168.50.1"
    }
    
    try:
        # Verificar si hostapd esta corriendo
        result = subprocess.run(
            ["systemctl", "is-active", "hostapd"],
            capture_output=True, text=True
        )
        status["running"] = result.stdout.strip() == "active"
        
        # Contar clientes conectados
        if os.path.exists("/var/lib/misc/dnsmasq.leases"):
            with open("/var/lib/misc/dnsmasq.leases", "r") as f:
                leases = [l for l in f.readlines() if l.strip()]
                status["clients"] = len(leases)
        
        # Obtener IP de wlan0
        result = subprocess.run(
            ["ip", "-4", "addr", "show", "wlan0"],
            capture_output=True, text=True
        )
        ip_match = re.search(r"inet (\d+\.\d+\.\d+\.\d+)", result.stdout)
        if ip_match:
            status["ip"] = ip_match.group(1)
            
    except Exception as e:
        logging.error("Error getting WiFi status: %s", e)
    
    return jsonify(status)


@web.route("/api/wifi/scan")
@login_required
def api_wifi_scan():
    """Escanea redes WiFi cercanas"""
    networks = []
    
    try:
        # Usar iw para escanear (puede requerir permisos)
        result = subprocess.run(
            ["sudo", "iw", "dev", "wlan0", "scan"],
            capture_output=True, text=True, timeout=30
        )
        
        if result.returncode != 0:
            # Si falla con wlan0, intentar sin especificar interface
            logging.warning("WiFi scan failed, trying alternative method")
            return jsonify({"ok": False, "error": "Escaneo no disponible (AP activo)"})
        
        # Parsear resultados
        current_network = {}
        for line in result.stdout.split('\n'):
            line = line.strip()
            
            if line.startswith("BSS "):
                if current_network.get("ssid"):
                    networks.append(current_network)
                mac = line.split()[1].split("(")[0]
                current_network = {"mac": mac, "ssid": "", "signal": -100, "channel": 0, "security": "Open"}
                
            elif line.startswith("SSID:"):
                current_network["ssid"] = line[6:].strip()
                
            elif line.startswith("signal:"):
                try:
                    current_network["signal"] = int(float(line.split()[1]))
                except:
                    pass
                    
            elif line.startswith("DS Parameter set: channel"):
                try:
                    current_network["channel"] = int(line.split()[-1])
                except:
                    pass
                    
            elif "WPA" in line or "RSN" in line:
                current_network["security"] = "WPA2" if "RSN" in line else "WPA"
            elif "WEP" in line:
                current_network["security"] = "WEP"
        
        # Agregar ultima red
        if current_network.get("ssid"):
            networks.append(current_network)
        
        # Ordenar por senal
        networks.sort(key=lambda x: x["signal"], reverse=True)
        
        return jsonify({"ok": True, "networks": networks})
        
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "error": "Timeout al escanear"})
    except Exception as e:
        logging.error("Error scanning WiFi: %s", e)
        return jsonify({"ok": False, "error": str(e)})


@web.route("/api/wifi/clients")
@login_required
def api_wifi_clients():
    """Obtiene lista de clientes conectados"""
    clients = []
    
    try:
        # Leer leases de dnsmasq
        if os.path.exists("/var/lib/misc/dnsmasq.leases"):
            with open("/var/lib/misc/dnsmasq.leases", "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 4:
                        # Formato: timestamp mac ip hostname client_id
                        clients.append({
                            "mac": parts[1],
                            "ip": parts[2],
                            "hostname": parts[3] if parts[3] != "*" else None,
                            "connected_time": None  # TODO: calcular desde timestamp
                        })
        
        return jsonify({"ok": True, "clients": clients})
        
    except Exception as e:
        logging.error("Error getting WiFi clients: %s", e)
        return jsonify({"ok": False, "error": str(e)})


# ============== System Control ==============

@web.route("/api/system/restart", methods=["POST"])
@login_required
def api_system_restart():
    """Reinicia el sistema"""
    logging.warning("System restart requested by %s", current_user.username)
    try:
        subprocess.Popen(["sudo", "shutdown", "-r", "+1"], 
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return jsonify({"ok": True, "message": "Sistema reiniciando en 1 minuto..."})
    except Exception as e:
        logging.error("Error restarting system: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 500


@web.route("/api/system/shutdown", methods=["POST"])
@login_required
def api_system_shutdown():
    """Apaga el sistema"""
    logging.warning("System shutdown requested by %s", current_user.username)
    try:
        subprocess.Popen(["sudo", "shutdown", "-h", "+1"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return jsonify({"ok": True, "message": "Sistema apagandose en 1 minuto..."})
    except Exception as e:
        logging.error("Error shutting down system: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 500


@web.route("/api/system/info")
@login_required
def api_system_info():
    """Obtiene informacion del sistema"""
    return jsonify(get_system_info())


@web.route("/restarting")
def restarting():
    """Pagina de reinicio"""
    return render_template("restarting.html")


# ============== Gateway LoRaWAN Configuration ==============

BASICSTATION_DIR = "/opt/ec25-router/BasicStation"
BASICSTATION_ENV = os.path.join(BASICSTATION_DIR, ".env")
BASICSTATION_COMPOSE = os.path.join(BASICSTATION_DIR, "docker-compose.yml")


def read_gateway_config():
    """Lee configuracion del gateway desde .env"""
    config = {
        "gateway_eui": "0000000000000000",
        "tc_uri": "wss://eu1.cloud.thethings.network:8887",
        "tc_key": "",
        "has_gps": "1"
    }
    
    try:
        if os.path.exists(BASICSTATION_ENV):
            with open(BASICSTATION_ENV, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, value = line.split("=", 1)
                        key_lower = key.lower()
                        if key_lower in config:
                            config[key_lower] = value
    except Exception as e:
        logging.error("Error reading gateway config: %s", e)
    
    return config


def save_gateway_config(config):
    """Guarda configuracion del gateway en .env"""
    try:
        os.makedirs(BASICSTATION_DIR, exist_ok=True)
        
        content = """# Configuracion de BasicStation LoRaWAN Gateway
# Este archivo es generado automaticamente por la interfaz web
# No editar manualmente

# Gateway EUI (obtenido del chip)
GATEWAY_EUI={gateway_eui}

# Servidor LNS (The Things Network, ChirpStack, etc)
TC_URI={tc_uri}
TC_KEY={tc_key}

# GPS (1=habilitado, 0=deshabilitado)
HAS_GPS={has_gps}
""".format(**config)
        
        with open(BASICSTATION_ENV, "w") as f:
            f.write(content)
        
        # Actualizar docker-compose.yml con los valores
        update_docker_compose(config)
        
        return True
    except Exception as e:
        logging.error("Error saving gateway config: %s", e)
        return False


def update_docker_compose(config):
    """Actualiza docker-compose.yml con la configuracion actual"""
    compose_content = """services:
  basicstation:
    image: xoseperez/basicstation:latest
    container_name: basicstation
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      # Configuracion del chip LoRa
      CLKSRC: 1
      SPI_SPEED: 8000000
      DISABLE_DUTY_CYCLE_CHECK: 1
      DISABLE_DWELL_TIME_LIMITS: 1
      
      # Configuracion GPS (1=habilitado, 0=deshabilitado)
      HAS_GPS: {has_gps}
      GPS_DEV: "/dev/ttyAMA0"
      
      # Configuracion GPIO
      USE_LIBGPIO: 1
      GPIO_CHIP: "gpiochip0"
      RESET_GPIO: "17"
      
      # Modelo del concentrador
      MODEL: "SX1302"
      INTERFACE: "SPI"
      DESIGN: "CORECELL"
      DEVICE: "/dev/spidev0.0"
      
      # Configuracion del servidor LoRaWAN
      TC_URI: "{tc_uri}"
      GATEWAY_EUI: "{gateway_eui}"
      TC_KEY: "{tc_key}"
""".format(**config)
    
    with open(BASICSTATION_COMPOSE, "w") as f:
        f.write(compose_content)


@web.route("/gateway")
@login_required
def gateway_config_page():
    """Pagina de configuracion del gateway LoRaWAN"""
    return render_template("gateway_config.html", username=current_user.username)


@web.route("/api/gateway/docker-status")
@login_required
def api_gateway_docker_status():
    """Verifica si Docker esta instalado"""
    try:
        result = subprocess.run(
            ["docker", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            version = result.stdout.strip()
            return jsonify({"installed": True, "version": version})
        else:
            return jsonify({"installed": False})
    except FileNotFoundError:
        return jsonify({"installed": False})
    except Exception as e:
        return jsonify({"installed": False, "error": str(e)})


@web.route("/api/gateway/install-docker", methods=["POST"])
@login_required
def api_gateway_install_docker():
    """Instala Docker"""
    logging.warning("Docker installation requested by %s", current_user.username)
    try:
        script_path = "/opt/ec25-router/scripts/setup-docker.sh"
        result = subprocess.run(
            ["sudo", "bash", script_path],
            capture_output=True,
            text=True,
            timeout=600  # 10 minutos max
        )
        
        if result.returncode == 0:
            return jsonify({"success": True, "output": result.stdout})
        else:
            return jsonify({"success": False, "error": result.stderr or result.stdout})
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Timeout - la instalacion tardo demasiado"})
    except Exception as e:
        logging.error("Error installing Docker: %s", e)
        return jsonify({"success": False, "error": str(e)})


@web.route("/api/gateway/container-status")
@login_required
def api_gateway_container_status():
    """Verifica estado del contenedor BasicStation"""
    config = read_gateway_config()
    
    try:
        # Verificar si el contenedor existe
        result = subprocess.run(
            ["docker", "ps", "-a", "--filter", "name=basicstation", "--format", "{{.Status}}"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        status = result.stdout.strip()
        
        if not status:
            return jsonify({
                "exists": False,
                "running": False,
                "gateway_eui": config.get("gateway_eui")
            })
        
        running = status.startswith("Up")
        
        return jsonify({
            "exists": True,
            "running": running,
            "status": status,
            "gateway_eui": config.get("gateway_eui")
        })
        
    except FileNotFoundError:
        return jsonify({"exists": False, "running": False, "error": "Docker no instalado"})
    except Exception as e:
        return jsonify({"exists": False, "running": False, "error": str(e)})


@web.route("/api/gateway/detect-eui", methods=["POST"])
@login_required
def api_gateway_detect_eui():
    """Detecta el Gateway EUI del chip LoRa"""
    logging.info("Gateway EUI detection requested by %s", current_user.username)
    
    try:
        result = subprocess.run(
            ["docker", "run", "-it", "--privileged", "--rm", 
             "-e", "GATEWAY_EUI_SOURCE=chip",
             "xoseperez/basicstation:latest", "gateway_eui"],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        output = result.stdout + result.stderr
        
        # Buscar el EUI en la salida (formato: 16 caracteres hex)
        eui_match = re.search(r'([0-9A-Fa-f]{16})', output)
        
        if eui_match:
            eui = eui_match.group(1).upper()
            
            # Guardar en la config
            config = read_gateway_config()
            config["gateway_eui"] = eui
            save_gateway_config(config)
            
            return jsonify({"success": True, "eui": eui})
        else:
            return jsonify({
                "success": False, 
                "error": "No se pudo detectar el EUI",
                "output": output
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Timeout detectando EUI"})
    except FileNotFoundError:
        return jsonify({"success": False, "error": "Docker no instalado"})
    except Exception as e:
        logging.error("Error detecting gateway EUI: %s", e)
        return jsonify({"success": False, "error": str(e)})


@web.route("/api/gateway/config", methods=["GET"])
@login_required
def api_gateway_config_get():
    """Obtiene configuracion del gateway"""
    config = read_gateway_config()
    return jsonify({"success": True, "config": config})


@web.route("/api/gateway/config", methods=["POST"])
@login_required
def api_gateway_config_post():
    """Guarda configuracion del gateway"""
    try:
        data = request.json
        
        config = {
            "gateway_eui": data.get("gateway_eui", "0000000000000000"),
            "tc_uri": data.get("tc_uri", ""),
            "tc_key": data.get("tc_key", ""),
            "has_gps": data.get("has_gps", "1")
        }
        
        if save_gateway_config(config):
            logging.info("Gateway config updated by %s", current_user.username)
            return jsonify({"success": True})
        else:
            return jsonify({"success": False, "error": "Error guardando configuracion"})
            
    except Exception as e:
        logging.error("Error saving gateway config: %s", e)
        return jsonify({"success": False, "error": str(e)})


@web.route("/api/gateway/start", methods=["POST"])
@login_required
def api_gateway_start():
    """Inicia el contenedor BasicStation"""
    logging.info("BasicStation start requested by %s", current_user.username)
    
    try:
        # Usar docker-compose up
        result = subprocess.run(
            ["docker", "compose", "-f", BASICSTATION_COMPOSE, "up", "-d"],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=BASICSTATION_DIR
        )
        
        if result.returncode == 0:
            return jsonify({"success": True})
        else:
            # Intentar con docker-compose (guion)
            result = subprocess.run(
                ["docker-compose", "-f", BASICSTATION_COMPOSE, "up", "-d"],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=BASICSTATION_DIR
            )
            
            if result.returncode == 0:
                return jsonify({"success": True})
            else:
                return jsonify({"success": False, "error": result.stderr or result.stdout})
                
    except Exception as e:
        logging.error("Error starting BasicStation: %s", e)
        return jsonify({"success": False, "error": str(e)})


@web.route("/api/gateway/stop", methods=["POST"])
@login_required
def api_gateway_stop():
    """Detiene el contenedor BasicStation"""
    logging.info("BasicStation stop requested by %s", current_user.username)
    
    try:
        result = subprocess.run(
            ["docker", "stop", "basicstation"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            return jsonify({"success": True})
        else:
            return jsonify({"success": False, "error": result.stderr or result.stdout})
            
    except Exception as e:
        logging.error("Error stopping BasicStation: %s", e)
        return jsonify({"success": False, "error": str(e)})


@web.route("/api/gateway/logs")
@login_required
def api_gateway_logs():
    """Obtiene logs del contenedor BasicStation"""
    try:
        result = subprocess.run(
            ["docker", "logs", "--tail", "100", "basicstation"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        logs = result.stdout + result.stderr
        return jsonify({"success": True, "logs": logs})
        
    except FileNotFoundError:
        return jsonify({"success": False, "error": "Docker no instalado"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})
