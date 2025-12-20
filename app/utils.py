# Utilidades
import subprocess
from datetime import datetime

def get_system_info():
    """Obtener información del sistema"""
    try:
        uptime = subprocess.run(['uptime', '-p'], capture_output=True, text=True)
        return {
            'uptime': uptime.stdout.strip(),
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        return {'error': str(e)}

def check_internet():
    """Verificar conectividad a internet"""
    try:
        subprocess.run(['ping', '-c', '1', '8.8.8.8'], 
                      capture_output=True, timeout=5, check=True)
        return True
    except:
        return False

def get_ip_addresses():
    """Obtener direcciones IP de todas las interfaces"""
    try:
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        return result.stdout.strip().split()
    except Exception as e:
        return []
