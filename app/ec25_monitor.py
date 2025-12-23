"""
Monitor asíncrono del módem EC25 usando hilos y cola.
Obtiene datos del módem continuamente y los envía a una cola para consumo web.
"""
import threading
import queue
import time
import logging
from typing import Dict, Any
from .modem import get_signal, get_network_info, is_ec25_detected

logger = logging.getLogger(__name__)

# Cola global para datos del EC25
ec25_data_queue = queue.Queue(maxsize=10)

# Última actualización de datos (cache)
_last_data: Dict[str, Any] = {
    "signal": {"csq": "N/A", "qcsq": "N/A"},
    "network": {
        "operator": "N/A",
        "network": "N/A", 
        "registration": "N/A",
        "sim": "N/A"
    },
    "timestamp": time.time(),
    "enabled": False,
    "detected": False
}
_data_lock = threading.Lock()

# Control del hilo monitor
_monitor_thread = None
_monitor_running = False
_monitor_enabled = False


def get_latest_data() -> Dict[str, Any]:
    """Obtiene los últimos datos del EC25 (thread-safe)"""
    with _data_lock:
        return _last_data.copy()


def _monitor_worker(update_interval: float = 5.0):
    """Hilo worker que obtiene datos del EC25 continuamente"""
    global _last_data, _monitor_running
    
    logger.info("🚀 EC25 monitor thread iniciado (intervalo: %.1fs)", update_interval)
    
    while _monitor_running:
        try:
            if not _monitor_enabled:
                # Si está deshabilitado, dormir y continuar
                time.sleep(1)
                continue
            
            # Detectar si el módem está presente
            detected = is_ec25_detected()
            
            if not detected:
                # Módem no detectado, enviar estado vacío
                data = {
                    "signal": {"csq": "N/A", "qcsq": "N/A"},
                    "network": {
                        "operator": "N/A",
                        "network": "N/A",
                        "registration": "N/A",
                        "sim": "N/A"
                    },
                    "timestamp": time.time(),
                    "enabled": True,
                    "detected": False
                }
            else:
                # Obtener datos del módem
                signal_data = get_signal()
                network_data = get_network_info()
                
                data = {
                    "signal": signal_data,
                    "network": network_data,
                    "timestamp": time.time(),
                    "enabled": True,
                    "detected": True
                }
            
            # Actualizar cache thread-safe
            with _data_lock:
                _last_data = data
            
            # Enviar a cola (no bloqueante)
            try:
                ec25_data_queue.put_nowait(data)
            except queue.Full:
                # Cola llena, descartar dato más antiguo
                try:
                    ec25_data_queue.get_nowait()
                    ec25_data_queue.put_nowait(data)
                except queue.Empty:
                    pass
            
            logger.debug("📊 Datos EC25 actualizados: CSQ=%s, Op=%s", 
                        data['signal']['csq'], data['network']['operator'])
            
        except Exception as e:
            logger.error("❌ Error en monitor EC25: %s", e, exc_info=True)
        
        # Esperar antes de la siguiente actualización
        time.sleep(update_interval)
    
    logger.info("🛑 EC25 monitor thread detenido")


def start_monitor(update_interval: float = 5.0, enabled: bool = True):
    """
    Inicia el hilo de monitoreo del EC25
    
    Args:
        update_interval: Intervalo de actualización en segundos (default: 5s)
        enabled: Si el monitor debe estar activo al iniciar
    """
    global _monitor_thread, _monitor_running, _monitor_enabled
    
    if _monitor_thread and _monitor_thread.is_alive():
        logger.warning("⚠️ Monitor EC25 ya está corriendo")
        return
    
    _monitor_running = True
    _monitor_enabled = enabled
    _monitor_thread = threading.Thread(
        target=_monitor_worker,
        args=(update_interval,),
        daemon=True,
        name="EC25Monitor"
    )
    _monitor_thread.start()
    logger.info("✅ Monitor EC25 iniciado (enabled=%s)", enabled)


def stop_monitor():
    """Detiene el hilo de monitoreo del EC25"""
    global _monitor_running, _monitor_thread
    
    if not _monitor_thread or not _monitor_thread.is_alive():
        logger.warning("⚠️ Monitor EC25 no está corriendo")
        return
    
    logger.info("🛑 Deteniendo monitor EC25...")
    _monitor_running = False
    
    # Esperar a que termine (timeout 5s)
    _monitor_thread.join(timeout=5.0)
    
    if _monitor_thread.is_alive():
        logger.error("❌ Monitor EC25 no se detuvo correctamente")
    else:
        logger.info("✅ Monitor EC25 detenido")
    
    _monitor_thread = None


def set_monitor_enabled(enabled: bool):
    """Habilita o deshabilita el monitoreo (sin detener el hilo)"""
    global _monitor_enabled
    _monitor_enabled = enabled
    logger.info("🔄 Monitor EC25 %s", "habilitado" if enabled else "deshabilitado")


def is_monitor_running() -> bool:
    """Verifica si el monitor está corriendo"""
    return _monitor_thread is not None and _monitor_thread.is_alive()


def is_monitor_enabled() -> bool:
    """Verifica si el monitor está habilitado"""
    return _monitor_enabled
