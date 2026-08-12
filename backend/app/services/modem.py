from __future__ import annotations

import glob
import logging
import re
import time
from typing import Any

import serial

logger = logging.getLogger(__name__)

BAUDRATE = 115200
CACHE_DURATION = 30

_cached_port: str | None = None
_cache_time: float = 0


def find_at_port(force_refresh: bool = False) -> str | None:
    global _cached_port, _cache_time

    if not force_refresh and _cached_port and (time.time() - _cache_time < CACHE_DURATION):
        return _cached_port

    all_ports = glob.glob("/dev/ttyUSB*")
    priority_ports = ["/dev/ttyUSB2", "/dev/ttyUSB3"]
    remaining_ports = sorted([p for p in all_ports if p not in priority_ports])
    ports_to_test = priority_ports + remaining_ports

    for p in ports_to_test:
        try:
            logger.debug("Probando puerto AT: %s", p)
            with serial.Serial(p, BAUDRATE, timeout=1, rtscts=False, dsrdtr=False) as s:
                s.reset_input_buffer()
                s.reset_output_buffer()
                s.write(b"AT\r\n")
                time.sleep(0.2)

                response = ""
                for _ in range(2):
                    chunk = s.read(s.in_waiting or 64).decode(errors="ignore")
                    response += chunk
                    if "OK" in response or "ERROR" in response:
                        break
                    time.sleep(0.15)

                if "OK" in response:
                    logger.info("Puerto AT encontrado: %s", p)
                    _cached_port = p
                    _cache_time = time.time()
                    return p
        except Exception as e:
            logger.debug("Puerto %s error: %s", p, e)

    logger.warning("No se encontro puerto AT del modem")
    _cached_port = None
    return None


def send_at(cmd: str) -> str | None:
    port = find_at_port()
    if not port:
        logger.error("No hay puerto AT disponible")
        return None
    try:
        with serial.Serial(port, BAUDRATE, timeout=2, rtscts=False, dsrdtr=False) as s:
            s.reset_input_buffer()
            s.reset_output_buffer()
            s.write((cmd + "\r\n").encode())
            time.sleep(0.5)

            response = ""
            for _ in range(5):
                chunk = s.read(s.in_waiting or 128).decode(errors="ignore")
                response += chunk
                if "OK" in response or "ERROR" in response:
                    break
                time.sleep(0.1)

            logger.debug("AT %s: %s", cmd, response[:80])
            return response if response else None
    except Exception as e:
        logger.error("Error enviando comando AT %s: %s", cmd, e)
        return None


def parse_csq(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r"\+CSQ:\s*(\d+),(\d+)", response)
    if match:
        rssi = int(match.group(1))
        dbm = -113 + (rssi * 2) if rssi < 31 else None
        if dbm is not None:
            return f"{rssi}/31 ({dbm} dBm)"
        return f"{rssi}/31"
    return None


def parse_qcsq(response: str | None) -> dict[str, Any] | None:
    if not response:
        return None
    match = re.search(r'\+QCSQ:\s*"([^"]+)",(-?\d+),(-?\d+),(-?\d+),(-?\d+)', response)
    if match:
        tech, rssi, rsrp, sinr, rsrq = match.groups()
        return {
            "technology": tech,
            "rssi": int(rssi),
            "rsrp": int(rsrp),
            "rsrq": int(rsrq),
            "sinr": int(sinr),
        }
    return None


def parse_qcsq_text(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r'\+QCSQ:\s*"([^"]+)",(-?\d+),(-?\d+),(-?\d+),(-?\d+)', response)
    if match:
        tech, rssi, rsrp, sinr, rsrq = match.groups()
        return f"{tech}: RSRP {rsrp}dBm, RSRQ {rsrq}dB, SINR {sinr}dB"
    return None


def parse_cops(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r'\+COPS:\s*\d+,\d+,"([^"]+)",(\d+)', response)
    if match:
        operator, act = match.groups()
        tech_map = {"0": "GSM", "2": "UTRAN", "7": "LTE", "9": "NB-IoT"}
        return f"{operator} ({tech_map.get(act, 'Unknown')})"
    return None


def parse_qnwinfo(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r'\+QNWINFO:\s*"([^"]+)","([^"]+)","([^"]+)",(\d+)', response)
    if match:
        act, mcc_mnc, band, channel = match.groups()
        return f"{act} - {band} @ {channel} MHz"
    return None


def parse_reg_status(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r"\+(C?[ER]REG):\s*\d+,(\d+)", response)
    if match:
        stat = match.group(2)
        status_map = {
            "0": "No registrado",
            "1": "Registrado",
            "2": "Buscando",
            "3": "Denegado",
            "5": "Roaming",
        }
        return status_map.get(stat, f"Estado {stat}")
    return None


def parse_cpin(response: str | None) -> str | None:
    if not response:
        return None
    match = re.search(r"\+CPIN:\s*(\w+)", response)
    if match:
        status = match.group(1)
        status_map = {"READY": "Lista", "SIM PIN": "PIN requerido", "SIM PUK": "PUK requerido"}
        return status_map.get(status, status)
    return None


def get_signal() -> dict[str, Any]:
    csq_raw = send_at("AT+CSQ")
    qcsq_raw = send_at("AT+QCSQ")
    return {
        "csq": parse_csq(csq_raw) or "N/A",
        "csq_raw": csq_raw,
        "qcsq": parse_qcsq_text(qcsq_raw) or "N/A",
        "qcsq_raw": qcsq_raw,
        "qcsq_parsed": parse_qcsq(qcsq_raw),
    }


def get_network_info() -> dict[str, Any]:
    cops_raw = send_at("AT+COPS?")
    qnwinfo_raw = send_at("AT+QNWINFO")
    creg_raw = send_at("AT+CREG?")
    cereg_raw = send_at("AT+CEREG?")
    cpin_raw = send_at("AT+CPIN?")

    return {
        "operator": parse_cops(cops_raw) or "N/A",
        "network": parse_qnwinfo(qnwinfo_raw) or "N/A",
        "registration": parse_reg_status(cereg_raw or creg_raw) or "N/A",
        "sim": parse_cpin(cpin_raw) or "N/A",
        "cops_raw": cops_raw,
        "qnwinfo_raw": qnwinfo_raw,
        "creg_raw": creg_raw,
        "cereg_raw": cereg_raw,
        "cpin_raw": cpin_raw,
    }


def set_apn(apn: str) -> str | None:
    return send_at(f'AT+CGDCONT=1,"IPV4V6","{apn}"')


def reset_modem() -> str | None:
    return send_at("AT+CFUN=1,1")


def is_ec25_detected() -> bool:
    port = find_at_port()
    return port is not None
