from __future__ import annotations

import logging
import os
import platform
import subprocess
import time

logger = logging.getLogger(__name__)


def get_system_info() -> dict:
    hostname = platform.node()
    uptime_seconds = time.time() - time.monotonic()

    uptime_str = ""
    days = int(uptime_seconds // 86400)
    hours = int((uptime_seconds % 86400) // 3600)
    minutes = int((uptime_seconds % 3600) // 60)
    if days > 0:
        uptime_str = f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        uptime_str = f"{hours}h {minutes}m"
    else:
        uptime_str = f"{minutes}m"

    cpu_usage = 0.0
    ram_usage = 0.0
    ram_total = 0.0
    temperature = None
    storage_used = 0.0
    storage_total = 0.0

    try:
        result = subprocess.run(
            ["top", "-bn1"],
            capture_output=True, text=True, timeout=5,
        )
        if result.stdout:
            for line in result.stdout.split("\n"):
                if "Cpu(s)" in line or "CPU:" in line:
                    match = __import__("re").search(r"(\d+\.?\d*)\s*id", line)
                    if match:
                        cpu_usage = round(100.0 - float(match.group(1)), 1)
                if "MiB Mem" in line:
                    parts = line.split()
                    for i, p in enumerate(parts):
                        if p == "total," and i > 0:
                            ram_total = float(parts[i - 1])
                        if p == "used," and i > 0:
                            ram_usage = float(parts[i - 1])
                            break
    except Exception:
        pass

    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            temp_raw = f.read().strip()
            temperature = float(temp_raw) / 1000.0
    except Exception:
        pass

    try:
        stat = os.statvfs("/")
        storage_total = (stat.f_frsize * stat.f_blocks) / (1024 ** 3)
        storage_used = (stat.f_frsize * (stat.f_blocks - stat.f_bfree)) / (1024 ** 3)
    except Exception:
        pass

    return {
        "hostname": hostname,
        "uptime": uptime_str,
        "cpu_usage": cpu_usage,
        "ram_usage": round(ram_usage, 1),
        "ram_total": round(ram_total, 1),
        "temperature": round(temperature, 1) if temperature else None,
        "storage_used": round(storage_used, 1),
        "storage_total": round(storage_total, 1),
    }
