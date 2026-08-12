from __future__ import annotations

import asyncio
import logging
import queue
import threading
import time
from typing import Any

from ..config import settings
from .modem import get_network_info, get_signal, is_ec25_detected

logger = logging.getLogger(__name__)

ec25_data_queue: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=10)

_last_data: dict[str, Any] = {
    "signal": {"csq": "N/A", "qcsq": "N/A"},
    "network": {
        "operator": "N/A",
        "network": "N/A",
        "registration": "N/A",
        "sim": "N/A",
    },
    "timestamp": time.time(),
    "enabled": False,
    "detected": False,
}
_data_lock = threading.Lock()

_monitor_thread: threading.Thread | None = None
_monitor_running = False
_monitor_enabled = False


def get_latest_data() -> dict[str, Any]:
    with _data_lock:
        return _last_data.copy()


def _monitor_worker(update_interval: float = 5.0) -> None:
    global _last_data, _monitor_running

    logger.info("EC25 monitor thread iniciado (intervalo: %.1fs)", update_interval)

    while _monitor_running:
        try:
            if not _monitor_enabled:
                time.sleep(1)
                continue

            detected = is_ec25_detected()

            if not detected:
                data = {
                    "signal": {"csq": "N/A", "qcsq": "N/A"},
                    "network": {
                        "operator": "N/A",
                        "network": "N/A",
                        "registration": "N/A",
                        "sim": "N/A",
                    },
                    "timestamp": time.time(),
                    "enabled": True,
                    "detected": False,
                }
            else:
                signal_data = get_signal()
                network_data = get_network_info()

                data = {
                    "signal": signal_data,
                    "network": network_data,
                    "timestamp": time.time(),
                    "enabled": True,
                    "detected": True,
                }

            with _data_lock:
                _last_data = data

            try:
                ec25_data_queue.put_nowait(data)
            except queue.Full:
                try:
                    ec25_data_queue.get_nowait()
                    ec25_data_queue.put_nowait(data)
                except queue.Empty:
                    pass

            logger.debug(
                "Datos EC25 actualizados: CSQ=%s, Op=%s",
                data["signal"]["csq"],
                data["network"]["operator"],
            )

        except Exception as e:
            logger.error("Error en monitor EC25: %s", e, exc_info=True)

        time.sleep(update_interval)

    logger.info("EC25 monitor thread detenido")


def start_monitor(update_interval: float = 5.0, enabled: bool = True) -> None:
    global _monitor_thread, _monitor_running, _monitor_enabled

    if _monitor_thread and _monitor_thread.is_alive():
        logger.warning("Monitor EC25 ya esta corriendo")
        return

    _monitor_running = True
    _monitor_enabled = enabled
    _monitor_thread = threading.Thread(
        target=_monitor_worker,
        args=(update_interval,),
        daemon=True,
        name="EC25Monitor",
    )
    _monitor_thread.start()
    logger.info("Monitor EC25 iniciado (enabled=%s)", enabled)


def stop_monitor() -> None:
    global _monitor_running, _monitor_thread

    if not _monitor_thread or not _monitor_thread.is_alive():
        logger.warning("Monitor EC25 no esta corriendo")
        return

    logger.info("Deteniendo monitor EC25...")
    _monitor_running = False
    _monitor_thread.join(timeout=5.0)

    if _monitor_thread.is_alive():
        logger.error("Monitor EC25 no se detuvo correctamente")
    else:
        logger.info("Monitor EC25 detenido")

    _monitor_thread = None


def set_monitor_enabled(enabled: bool) -> None:
    global _monitor_enabled
    _monitor_enabled = enabled
    logger.info("Monitor EC25 %s", "habilitado" if enabled else "deshabilitado")


def is_monitor_running() -> bool:
    return _monitor_thread is not None and _monitor_thread.is_alive()


def is_monitor_enabled() -> bool:
    return _monitor_enabled
