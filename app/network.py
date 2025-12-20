import subprocess
from .config import load_config

ETH_IFACE = "eth0"
LTE_IFACE = "usb0"

def iface_up(iface):
    """Verificar si una interfaz está UP"""
    return subprocess.call(
        ["ip", "link", "show", iface],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    ) == 0

def has_internet(iface):
    """Verificar si la interfaz tiene conectividad a Internet"""
    try:
        subprocess.check_call(
            ["ping", "-I", iface, "-c", "1", "-W", "1", "8.8.8.8"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return True
    except:
        return False

def active_wan():
    """Retorna WAN activa respetando wan_mode: 'eth', 'lte' o 'down'"""
    cfg = load_config()
    mode = cfg.get("wan_mode", "auto")
    
    if mode == "eth":
        return "eth" if (iface_up(ETH_IFACE) and has_internet(ETH_IFACE)) else "down"
    elif mode == "lte":
        return "lte" if (iface_up(LTE_IFACE) and has_internet(LTE_IFACE)) else "down"
    else:  # auto
        if iface_up(ETH_IFACE) and has_internet(ETH_IFACE):
            return "eth"
        if iface_up(LTE_IFACE) and has_internet(LTE_IFACE):
            return "lte"
        return "down"

def get_wan_status():
    """Retorna estado detallado de ambas interfaces"""
    return {
        "eth": {
            "up": iface_up(ETH_IFACE),
            "internet": has_internet(ETH_IFACE) if iface_up(ETH_IFACE) else False
        },
        "lte": {
            "up": iface_up(LTE_IFACE),
            "internet": has_internet(LTE_IFACE) if iface_up(LTE_IFACE) else False
        },
        "active": active_wan()
    }
