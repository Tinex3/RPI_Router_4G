import serial, glob, time

BAUDRATE = 115200

def find_at_port():
    """Busca puerto AT del módem EC25 automáticamente"""
    for p in glob.glob("/dev/ttyUSB*"):
        try:
            with serial.Serial(p, BAUDRATE, timeout=1) as s:
                s.write(b"AT\r")
                if "OK" in s.read(32).decode(errors="ignore"):
                    return p
        except:
            pass
    return None

def send_at(cmd: str) -> str | None:
    """Envía comando AT y retorna respuesta"""
    port = find_at_port()
    if not port:
        return None
    try:
        with serial.Serial(port, BAUDRATE, timeout=2) as s:
            s.write((cmd + "\r").encode())
            time.sleep(0.4)
            return s.read(512).decode(errors="ignore")
    except Exception as e:
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
