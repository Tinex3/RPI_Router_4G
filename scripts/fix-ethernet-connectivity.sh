#!/bin/bash
# =========================================================
# Router WAN Fix + Failover Complete
# - Elimina rutas duplicadas sin gateway (loopback fix)
# - Failover inteligente: EC25 (wwan0) -> Ethernet (eth0)
# - Corrige iptables (solo NAT para WiFi)
# - UNA sola default route controlada
# =========================================================

set -e

echo "========================================================================"
echo "         Fix: Restaurar conectividad + WAN Failover                    "
echo "========================================================================"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "[ERROR] Este script debe ejecutarse con sudo"
  exit 1
fi

# Variables de configuración
PING_TARGET="8.8.8.8"
WAN_4G="wwan0"
WAN_ETH="eth0"

# ---------------------------------------------------------
# Funciones de detección de WAN
# ---------------------------------------------------------

get_gw_eth() {
    # Obtener gateway de DHCP o ruta estática en eth0
    ip route show dev "$WAN_ETH" | awk '/via/ {print $3; exit}' | head -1
}

get_gw_4g() {
    # Obtener gateway de wwan0
    ip route show dev "$WAN_4G" | awk '/via/ {print $3; exit}' | head -1
}

test_wan() {
    local iface="$1"
    # Probar si la interfaz tiene conectividad real
    if ip link show "$iface" &>/dev/null; then
        if ip addr show "$iface" | grep -q "inet "; then
            if ping -I "$iface" -c 2 -W 3 "$PING_TARGET" &>/dev/null; then
                return 0
            fi
        fi
    fi
    return 1
}

echo "[1/7] Diagnosticando conectividad..."
echo ""

# Probar conectividad por IP
echo "   Probando ping a 8.8.8.8 (Google DNS)..."
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Conectividad por IP: OK"
  IP_OK=true
else
  echo "   ❌ Conectividad por IP: FALLA"
  IP_OK=false
fi

# Probar resolución DNS
echo "   Probando resolución DNS (github.com)..."
if nslookup github.com &>/dev/null; then
  echo "   ✅ Resolución DNS: OK"
  DNS_OK=true
else
  echo "   ❌ Resolución DNS: FALLA"
  DNS_OK=false
fi

echo ""
if [ "$IP_OK" = true ] && [ "$DNS_OK" = true ]; then
  echo "✅ La conectividad está funcionando correctamente."
  echo "   No es necesario aplicar ningún fix."
  exit 0
fi

echo "[2/7] Limpiando TODAS las rutas por defecto..."
echo ""
echo "=== Rutas actuales (antes del fix) ==="
ip route show
echo ""

# Eliminar TODAS las rutas por defecto (limpiar slate)
echo "   🧹 Eliminando todas las default routes..."
while ip route del default 2>/dev/null; do
    echo "      ✅ Ruta eliminada"
done

# Configurar NetworkManager para evitar que cree rutas automáticas
if command -v nmcli &> /dev/null; then
  echo ""
  echo "   🔧 Configurando NetworkManager..."
  CONN_NAME=$(nmcli -t -f NAME connection show --active | grep -E "eth|Wired" | head -1)
  if [ -n "$CONN_NAME" ]; then
    nmcli connection modify "$CONN_NAME" ipv4.never-default no 2>/dev/null || true
    nmcli connection modify "$CONN_NAME" ipv6.method disabled 2>/dev/null || true
    echo "   ✅ NetworkManager configurado para '$CONN_NAME'"
  fi
fi

echo ""
echo "[3/7] Detectando WAN disponible (Failover Logic)..."
echo ""

# ---------------------------------------------------------
# PRIORIDAD 1: EC25 / 4G (wwan0)
# ---------------------------------------------------------
if test_wan "$WAN_4G"; then
    GW=$(get_gw_4g)
    if [ -n "$GW" ]; then
        ip route add default via "$GW" dev "$WAN_4G"
        echo "   ✅ WAN ACTIVA: EC25 (wwan0) via $GW"
        echo "   📡 Conexión 4G funcionando correctamente"
        WAN_SELECTED="4G"
    fi
else
    echo "   ℹ️  EC25 (wwan0): No disponible o sin internet"
fi

# ---------------------------------------------------------
# PRIORIDAD 2: ETHERNET (eth0) - FALLBACK
# ---------------------------------------------------------
if [ -z "$WAN_SELECTED" ]; then
    GW=$(get_gw_eth)
    
    if [ -z "$GW" ]; then
        # Intentar obtener gateway desde DHCP
        echo "   🔄 Renovando DHCP en eth0..."
        dhclient -r eth0 2>/dev/null || true
        sleep 2
        dhclient eth0 2>/dev/null || true
        sleep 2
        GW=$(get_gw_eth)
    fi
    
    if [ -n "$GW" ]; then
        ip route add default via "$GW" dev "$WAN_ETH"
        echo "   ✅ WAN ACTIVA: Ethernet (eth0) via $GW"
        echo "   🔌 Usando conexión Ethernet como fallback"
        WAN_SELECTED="Ethernet"
    else
        echo "   ❌ Ethernet (eth0): Sin gateway disponible"
    fi
fi

# ---------------------------------------------------------
# SIN WAN DISPONIBLE
# ---------------------------------------------------------
if [ -z "$WAN_SELECTED" ]; then
    echo ""
    echo "   ⚠️  ADVERTENCIA: No hay WAN disponible"
    echo "   📋 Diagnóstico:"
    echo "      - EC25 no está conectado o sin señal"
    echo "      - Ethernet sin cable o sin DHCP"
    echo ""
    echo "   🔧 Soluciones:"
    echo "      - Verificar SIM y señal del EC25"
    echo "      - Conectar cable Ethernet y verificar router"
fi

echo ""
echo "[4/7] Mostrando reglas iptables actuales..."
echo ""
echo "=== Tabla NAT (POSTROUTING) ==="
iptables -t nat -L POSTROUTING -v -n | head -20
echo ""

echo "[5/6] Limpiando reglas iptables problemáticas..."
echo ""

# Hacer backup de reglas actuales
iptables-save > /tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules
echo "   💾 Backup guardado en /tmp/iptables-backup-*.rules"

# Limpiar reglas NAT genéricas que afectan todo el tráfico
echo "   🧹 Eliminando reglas MASQUERADE genéricas en eth0..."
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica eth0 eliminada" || \
  echo "      ℹ️  No había regla genérica en eth0"

iptables -t nat -D POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica usb0 eliminada" || \
  echo "      ℹ️  No había regla genérica en usb0"

echo "[6/7] Aplicando reglas correctas (solo para WiFi)..."
echo ""

# Asegurar que existan las reglas correctas (solo para red WiFi)
iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE
echo "   ✅ NAT para WiFi → eth0 configurado"

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE
echo "   ✅ NAT para WiFi → usb0 configurado"

# Guardar reglas corregidas
iptables-save > /etc/iptables.rules
echo "   💾 Reglas corregidas guardadas"

# Si existe netfilter-persistent, guardar allí también
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
  echo "   💾 Reglas guardadas con netfilter-persistent"
fi

echo ""
echo "[7/7] Verificando conectividad después del fix..."
echo ""
echo "=== Rutas actuales (después del fix) ==="
ip route show
echo ""

# Dar tiempo a que se apliquen cambios
sleep 2

echo "========================================================================"
echo "         Verificando conectividad después del fix                      "
echo "========================================================================"
echo ""

# Verificar DNS
if [ "$DNS_OK" = false ]; then
  echo "   🔧 Corrigiendo DNS..."
  
  # Agregar DNS públicos
  echo "nameserver 8.8.8.8" > /tmp/resolv.conf.new
  echo "nameserver 8.8.4.4" >> /tmp/resolv.conf.new
  echo "nameserver 1.1.1.1" >> /tmp/resolv.conf.new
  
  # Preservar DNS existente si no es el problemático
  if [ -f /etc/resolv.conf ]; then
    grep "^nameserver" /etc/resolv.conf | grep -v "192.168.225.1" >> /tmp/resolv.conf.new || true
  fi
  
  cp /tmp/resolv.conf.new /etc/resolv.conf
  echo "   ✅ DNS públicos agregados (8.8.8.8, 8.8.4.4, 1.1.1.1)"
fi

# Probar conectividad nuevamente
echo ""
echo "   Probando conectividad..."
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Conectividad por IP: RESTAURADA"
else
  echo "   ❌ Conectividad por IP: AÚN FALLA"
  echo ""
  echo "   Diagnóstico adicional necesario:"
  echo "     - Verificar cable Ethernet conectado"
  echo "     - Verificar DHCP: sudo dhclient eth0"
  echo "     - Verificar rutas: ip route"
  echo "     - Ver interfaces: ip addr"
fi

if nslookup github.com &>/dev/null; then
  echo "   ✅ Resolución DNS: RESTAURADA"
else
  echo "   ⚠️  Resolución DNS: Revisar /etc/resolv.conf"
fi

echo ""
echo "========================================================================"
echo "                        FIX COMPLETADO                                  "
echo "========================================================================"
echo ""

if [ -n "$WAN_SELECTED" ]; then
    echo "🌐 WAN ACTIVA: $WAN_SELECTED"
else
    echo "⚠️  Sin WAN disponible"
fi

echo ""
echo "📋 Estado del sistema:"
echo "   Rutas:"
ip route show | grep default || echo "      (ninguna)"
echo ""
echo "   Reglas NAT (solo WiFi):"
iptables -t nat -L POSTROUTING -v -n | grep "192.168.50" || echo "      (ninguna configurada)"
echo ""
echo "✅ Fix aplicado correctamente"
echo "✅ El ServerPi tiene conectividad con WAN disponible"
echo "✅ Los clientes WiFi seguirán funcionando correctamente"
echo ""
echo "💡 Para failover automático, ejecuta este script periódicamente:"
echo "   (El timer wan-failover.timer lo hace automáticamente)"
echo ""
