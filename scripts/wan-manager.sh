#!/bin/bash
# WAN Auto Failover Manager - ETAPA 3
# Lee configuración desde config.json y aplica rutas dinámicamente

CFG="/opt/ec25-router/data/config.json"
ETH=eth0
LTE=usb0

ETH_METRIC=100
LTE_METRIC=300

# Función para obtener wan_mode desde config.json
get_mode() {
  if command -v jq &> /dev/null; then
    jq -r '.wan_mode // "auto"' "$CFG" 2>/dev/null || echo "auto"
  else
    # Fallback si jq no está instalado
    grep -oP '"wan_mode":\s*"\K[^"]+' "$CFG" 2>/dev/null || echo "auto"
  fi
}

# Función para verificar conectividad
check_inet() {
  ping -I "$1" -c 1 -W 1 8.8.8.8 > /dev/null 2>&1
}

# Loop infinito - revisar cada 5 segundos
while true; do
  MODE=$(get_mode)
  
  case "$MODE" in
    eth)
      # Forzar solo Ethernet
      if ip link show $ETH 2>/dev/null | grep -q "UP" && check_inet $ETH; then
        ip route replace default dev $ETH metric $ETH_METRIC 2>/dev/null || true
      fi
      ;;
    lte)
      # Forzar solo LTE
      if ip link show $LTE 2>/dev/null | grep -q "UP" && check_inet $LTE; then
        ip route replace default dev $LTE metric $ETH_METRIC 2>/dev/null || true
      fi
      ;;
    *)
      # Auto failover (default)
      if ip link show $ETH 2>/dev/null | grep -q "UP" && check_inet $ETH; then
        # Ethernet prioritario
        ip route replace default dev $ETH metric $ETH_METRIC 2>/dev/null || true
        ip route replace default dev $LTE metric $LTE_METRIC 2>/dev/null || true
      elif ip link show $LTE 2>/dev/null | grep -q "UP" && check_inet $LTE; then
        # LTE prioritario
        ip route replace default dev $LTE metric $ETH_METRIC 2>/dev/null || true
      fi
      ;;
  esac
  
  sleep 5
done
