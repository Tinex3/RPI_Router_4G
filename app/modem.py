import serial, glob, time
import logging

BAUDRATE = 115200
logger = logging.getLogger(__name__)

def find_at_port():
    """Busca puerto AT del módem EC25 automáticamente"""
    for p in sorted(glob.glob("/dev/ttyUSB*")):
        try:
            logger.info(f"Probando puerto AT: {p}")
            with serial.Serial(p, BAUDRATE, timeout=3, rtscts=False, dsrdtr=False) as s:
                s.write(b"AT\r\n")
                time.sleep(0.5)
                response = s.read(256).decode(errors="ignore")
                logger.info(f"Puerto {p} responde: {repr(response[:100])}")
                if "OK" in response:
                    logger.info(f"✅ Puerto AT encontrado: {p}")
                    return p
        except Exception as e:
            logger.warning(f"Puerto {p} error: {e}")
    logger.error("❌ No se encontró puerto AT del modem en ningún /dev/ttyUSB*")
    return None

def send_at(cmd: str) -> str | None:
    """Envía comando AT y retorna respuesta"""
    port = find_at_port()
    if not port:
        logger.error("No hay puerto AT disponible")
        return None
    try:
        with serial.Serial(port, BAUDRATE, timeout=2) as s:
            s.write((cmd + "\r").encode())
            time.sleep(0.4)
            response = s.read(512).decode(errors="ignore")
            logger.debug(f"AT command {cmd}: {response[:50]}...")
            return response
    except Exception as e:
        logger.error(f"Error enviando comando AT {cmd}: {e}")
        return f"Error: {e}"

def get_signal():
    """Obtiene señal CSQ y QCSQ"""
    return {
        "csq": send_at("AT+CSQ"),
        "qcsq": send_at("AT+QCSQ")
    }

def get_network_info():
    """Obtiene info completa: operador, tecnología, registro, SIM"""
    return {
        "cops": send_at("AT+COPS?"),
        "qnwinfo": send_at("AT+QNWINFO"),
        "creg": send_at("AT+CREG?"),
        "cereg": send_at("AT+CEREG?"),
        "cpin": send_at("AT+CPIN?")
    }

def set_apn(apn: str):
    """Configura APN en el módem"""
    return send_at(f'AT+CGDCONT=1,"IPV4V6","{apn}"')

def reset_modem():
    """Reinicia el módem EC25"""
    return send_at("AT+CFUN=1,1")
