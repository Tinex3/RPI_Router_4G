import speedtest
import logging

logger = logging.getLogger(__name__)

def run_speedtest():
    """Ejecuta prueba de velocidad con speedtest-cli"""
    try:
        logger.info("Iniciando speedtest...")
        st = speedtest.Speedtest()
        
        # Obtener mejor servidor
        st.get_best_server()
        
        # Test de descarga
        logger.info("Probando velocidad de descarga...")
        download_speed = st.download() / 1_000_000  # Convertir a Mbps
        
        # Test de subida
        logger.info("Probando velocidad de subida...")
        upload_speed = st.upload() / 1_000_000  # Convertir a Mbps
        
        # Ping
        ping = st.results.ping
        
        # Información del servidor
        server = st.results.server
        
        logger.info(f"Speedtest completado: {download_speed:.2f} Mbps down, {upload_speed:.2f} Mbps up")
        
        return {
            "success": True,
            "download": round(download_speed, 2),
            "upload": round(upload_speed, 2),
            "ping": round(ping, 2),
            "server": {
                "name": server.get("name", "Desconocido"),
                "country": server.get("country", ""),
                "sponsor": server.get("sponsor", "")
            }
        }
    except Exception as e:
        logger.error(f"Error en speedtest: {e}")
        return {
            "success": False,
            "error": str(e)
        }
