#!/bin/bash
# =========================================================
# Instalador de WAN Failover automático
# =========================================================

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Instalación de WAN Failover Automático                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Ejecuta con sudo: sudo ./install-wan-failover.sh"
  exit 1
fi

INSTALL_DIR="/opt/ec25-router"

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/6] Verificando instalación de ec25-router..."
if [ ! -d "$INSTALL_DIR" ]; then
  echo "   ⚠️  $INSTALL_DIR no existe"
  echo "   ℹ️  Usando directorio actual: $PROJECT_DIR"
  INSTALL_DIR="$PROJECT_DIR"
fi
echo "   ✅ Directorio: $INSTALL_DIR"

echo ""
echo "[2/6] Copiando script wan-failover.sh..."
cp "$PROJECT_DIR/scripts/wan-failover.sh" "$INSTALL_DIR/scripts/wan-failover.sh"
chmod +x "$INSTALL_DIR/scripts/wan-failover.sh"
echo "   ✅ Script copiado y ejecutable"

echo ""
echo "[3/6] Instalando servicio systemd..."
cp "$PROJECT_DIR/systemd/wan-failover.service" /etc/systemd/system/
echo "   ✅ wan-failover.service instalado"

echo ""
echo "[4/6] Instalando timer systemd..."
cp "$PROJECT_DIR/systemd/wan-failover.timer" /etc/systemd/system/
echo "   ✅ wan-failover.timer instalado"

echo ""
echo "[5/6] Recargando systemd y habilitando timer..."
systemctl daemon-reload
systemctl enable wan-failover.timer
systemctl start wan-failover.timer
echo "   ✅ Timer activado"

echo ""
echo "[6/6] Ejecutando failover inicial..."
systemctl start wan-failover.service
sleep 2
echo "   ✅ Failover ejecutado"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              ✅ INSTALACIÓN COMPLETADA                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Estado del sistema:"
echo ""
echo "   Timer activo:"
systemctl is-active wan-failover.timer && echo "      ✅ RUNNING" || echo "      ❌ STOPPED"
echo ""
echo "   Próxima ejecución:"
systemctl list-timers wan-failover.timer --no-pager | tail -2
echo ""
echo "   Ruta WAN actual:"
ip route show | grep default || echo "      (ninguna)"
echo ""
echo "🔍 Comandos útiles:"
echo "   Ver estado:    systemctl status wan-failover.timer"
echo "   Ver logs:      journalctl -u wan-failover.service -f"
echo "   Ejecutar ya:   sudo systemctl start wan-failover.service"
echo "   Detener:       sudo systemctl stop wan-failover.timer"
echo "   Deshabilitar:  sudo systemctl disable wan-failover.timer"
echo ""
echo "💡 El timer revisa cada 30 segundos:"
echo "   - Si EC25 tiene internet → usa EC25"
echo "   - Si EC25 falla → cambia a Ethernet"
echo "   - Si EC25 vuelve → regresa a EC25"
echo ""
