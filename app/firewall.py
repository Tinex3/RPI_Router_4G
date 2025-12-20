import subprocess
import logging
from .config import load_config

AP_IF = "wlan0"
AP_NET = "192.168.4.0/24"
WAN_IFS = ["eth0", "usb0"]

def sh(cmd: list[str]) -> None:
    """Ejecuta comando shell, ignora errores"""
    try:
        subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        logging.warning(f"Command failed: {' '.join(cmd)} - {e}")

def apply_firewall() -> None:
    """Aplica reglas de firewall: NAT + forwarding + opcional aislamiento de clientes"""
    cfg = load_config()
    sec = cfg.get("security", {})
    isolate = bool(sec.get("isolate_clients", True))

    logging.info("Applying firewall rules. isolate_clients=%s", isolate)

    # Forward policy (router mode)
    sh(["iptables", "-P", "FORWARD", "ACCEPT"])

    # NAT (masquerade) for both WANs - intenta agregar, ignora si ya existe
    for wan in WAN_IFS:
        # Verifica si existe
        result = subprocess.run(
            ["iptables", "-t", "nat", "-C", "POSTROUTING", "-s", AP_NET, "-o", wan, "-j", "MASQUERADE"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if result.returncode != 0:
            # No existe, agregar
            sh(["iptables", "-t", "nat", "-A", "POSTROUTING", "-s", AP_NET, "-o", wan, "-j", "MASQUERADE"])

    # Allow established return
    for wan in WAN_IFS:
        result = subprocess.run(
            ["iptables", "-C", "FORWARD", "-i", wan, "-o", AP_IF, "-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if result.returncode != 0:
            sh(["iptables", "-A", "FORWARD", "-i", wan, "-o", AP_IF, "-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT"])

    # Allow AP -> WAN
    for wan in WAN_IFS:
        result = subprocess.run(
            ["iptables", "-C", "FORWARD", "-i", AP_IF, "-o", wan, "-j", "ACCEPT"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if result.returncode != 0:
            sh(["iptables", "-A", "FORWARD", "-i", AP_IF, "-o", wan, "-j", "ACCEPT"])

    # Optional: isolate clients on the AP (block wlan0 -> wlan0 forwarding)
    # This is useful to stop clients seeing each other.
    if isolate:
        result = subprocess.run(
            ["iptables", "-C", "FORWARD", "-i", AP_IF, "-o", AP_IF, "-j", "DROP"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if result.returncode != 0:
            sh(["iptables", "-A", "FORWARD", "-i", AP_IF, "-o", AP_IF, "-j", "DROP"])
    else:
        # Remover regla de aislamiento si existe
        sh(["iptables", "-D", "FORWARD", "-i", AP_IF, "-o", AP_IF, "-j", "DROP"])

    # Persist rules
    sh(["netfilter-persistent", "save"])
    logging.info("Firewall rules applied successfully")
