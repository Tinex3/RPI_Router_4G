#!/bin/bash
# =========================================================
# WAN Failover Script (para ejecución periódica)
# - Detecta mejor WAN disponible
# - Prioridad: EC25 (wwan0) -> Ethernet (eth0)
# - Ejecutado por wan-failover.timer cada 30s
# =========================================================

PING_TARGET="8.8.8.8"
WAN_4G="wwan0"
WAN_ETH="eth0"
LOG_TAG="wan-failover"

# ---------------------------------------------------------
# Funciones de detección
# ---------------------------------------------------------

get_gw_eth() {
    ip route show dev "$WAN_ETH" 2>/dev/null | awk '/via/ {print $3; exit}' | head -1
}

get_gw_4g() {
    ip route show dev "$WAN_4G" 2>/dev/null | awk '/via/ {print $3; exit}' | head -1
}

test_wan() {
    local iface="$1"
    if ip link show "$iface" &>/dev/null; then
        if ip addr show "$iface" | grep -q "inet "; then
            if ping -I "$iface" -c 2 -W 3 "$PING_TARGET" &>/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    return 1
}

get_current_wan() {
    ip route show | awk '/^default/ {print $5; exit}'
}

log_info() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_warn() {
    logger -t "$LOG_TAG" -p user.warning "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
}

# ---------------------------------------------------------
# Limpiar rutas duplicadas sin gateway
# ---------------------------------------------------------

clean_duplicate_routes() {
    local had_duplicates=false
    
    # Detectar y eliminar rutas sin gateway (scope link)
    if ip route show | grep -q "^default dev eth0 scope link"; then
        ip route del default dev eth0 scope link 2>/dev/null && had_duplicates=true
    fi
    
    if ip route show | grep -q "^default dev wwan0 scope link"; then
        ip route del default dev wwan0 scope link 2>/dev/null && had_duplicates=true
    fi
    
    if [ "$had_duplicates" = true ]; then
        log_warn "Rutas duplicadas sin gateway eliminadas"
    fi
}

# ---------------------------------------------------------
# Main Logic
# ---------------------------------------------------------

CURRENT_WAN=$(get_current_wan)

# Limpiar rutas problemáticas primero
clean_duplicate_routes

# ---------------------------------------------------------
# PRIORIDAD 1: EC25 / 4G (wwan0)
# ---------------------------------------------------------
if test_wan "$WAN_4G"; then
    GW=$(get_gw_4g)
    if [ -n "$GW" ]; then
        if [ "$CURRENT_WAN" != "$WAN_4G" ]; then
            ip route del default 2>/dev/null || true
            ip route add default via "$GW" dev "$WAN_4G"
            log_info "WAN switched to EC25 (wwan0) via $GW"
        fi
        exit 0
    fi
fi

# ---------------------------------------------------------
# PRIORIDAD 2: ETHERNET (eth0) - FALLBACK
# ---------------------------------------------------------
if [ "$CURRENT_WAN" != "$WAN_ETH" ]; then
    GW=$(get_gw_eth)
    
    if [ -n "$GW" ]; then
        ip route del default 2>/dev/null || true
        ip route add default via "$GW" dev "$WAN_ETH"
        log_info "WAN switched to Ethernet (eth0) via $GW"
        exit 0
    fi
fi

# ---------------------------------------------------------
# WAN actual sigue siendo válida
# ---------------------------------------------------------
if [ -n "$CURRENT_WAN" ]; then
    # Verificar que la WAN actual sigue funcionando
    if test_wan "$CURRENT_WAN"; then
        exit 0
    else
        log_warn "WAN actual ($CURRENT_WAN) perdió conectividad"
        ip route del default 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------
# Sin WAN disponible
# ---------------------------------------------------------
if [ -z "$(ip route show | grep '^default')" ]; then
    log_warn "No hay WAN disponible (EC25 ni Ethernet)"
fi

exit 0
