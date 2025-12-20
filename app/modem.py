import serial, glob, time
import logging

BAUDRATE = 115200
logger = logging.getLogger(__name__)

def find_at_port():
    """Busca puerto AT del módem EC25 automáticamente"""
    for p in sorted(glob.glob("/dev/ttyUSB*")):
        try:
            logger.info(f"Probando puerto AT: {p}")
            with serial.Serial(p, BAUDRATE, timeout=2, rtscts=False, dsrdtr=False) as s:
                # Limpiar buffer
                s.reset_input_buffer()
                s.reset_output_buffer()
                
                # Enviar AT y esperar respuesta completa
                s.write(b"AT\r\n")
                time.sleep(0.3)
                
                # Leer respuesta en múltiples intentos
                response = ""
                for _ in range(3):
                    chunk = s.read(s.in_waiting or 64).decode(errors="ignore")
                    response += chunk
                    if "OK" in response or "ERROR" in response:
                        break
                    time.sleep(0.2)
                
                logger.info(f"Puerto {p} responde: {repr(response[:150])}")
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
        with serial.Serial(port, BAUDRATE, timeout=2, rtscts=False, dsrdtr=False) as s:
            # Limpiar buffers
            s.reset_input_buffer()
            s.reset_output_buffer()
            
            # Enviar comando
            s.write((cmd + "\r\n").encode())
            time.sleep(0.5)
            
            # Leer respuesta completa
            response = ""
            for _ in range(5):
                chunk = s.read(s.in_waiting or 128).decode(errors="ignore")
                response += chunk
                if "OK" in response or "ERROR" in response:
                    break
                time.sleep(0.1)
            
            logger.debug(f"AT {cmd}: {response[:80]}...")
            return response if response else None
    except Exception as e:
        logger.error(f"Error enviando comando AT {cmd}: {e}")
        return None

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
