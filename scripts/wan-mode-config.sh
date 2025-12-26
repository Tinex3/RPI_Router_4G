#!/bin/bash
# =========================================================
# Configurador de Modo WAN
# Permite seleccionar entre: ethernet-only, lte-only, auto-smart
# =========================================================

set -e

CONFIG_FILE="/etc/ec25-router/wan-mode.conf"
CONFIG_DIR=$(dirname "$CONFIG_FILE")

# Crear directorio si no existe
sudo mkdir -p "$CONFIG_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              Configuración de Modo WAN                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Selecciona el modo de operación WAN:"
echo ""
echo "1) Ethernet ONLY"
echo "   - Solo usa eth0 como WAN"
echo "   - NO hay failover automático"
echo "   - Ideal: Conexión Ethernet estable y confiable"
echo ""
echo "2) LTE ONLY"
echo "   - Solo usa wwan0 (EC25) como WAN"
echo "   - NO hay failover automático"
echo "   - Ideal: Router 4G puro, sin Ethernet disponible"
echo ""
echo "3) Auto (Smart Failover)"
echo "   - Prioridad ETHERNET primero"
echo "   - Monitoreo continuo de la interfaz activa"
echo "   - Solo cambia cuando la activa FALLA"
echo "   - NO compara constantemente (evita flapping)"
echo "   - Ideal: Alta disponibilidad con backup inteligente"
echo ""
read -p "Opción (1/2/3): " -n 1 -r
echo
echo ""

case $REPLY in
  1)
    MODE="ethernet-only"
    echo "✅ Modo seleccionado: Ethernet ONLY"
    ;;
  2)
    MODE="lte-only"
    echo "✅ Modo seleccionado: LTE ONLY"
    ;;
  3)
    MODE="auto-smart"
    echo "✅ Modo seleccionado: Auto (Smart Failover)"
    ;;
  *)
    echo "❌ Opción inválida"
    exit 1
    ;;
esac

# Guardar configuración
echo "MODE=$MODE" | sudo tee "$CONFIG_FILE" > /dev/null

echo ""
echo "✅ Configuración guardada en $CONFIG_FILE"
echo ""
echo "🔄 Reiniciando servicio wan-failover..."
sudo systemctl restart wan-failover.timer 2>/dev/null || true
sudo systemctl restart wan-failover.service 2>/dev/null || true

echo ""
echo "✅ Configuración aplicada correctamente"
echo ""
echo "Ver logs: journalctl -u wan-failover.service -f"
echo ""
