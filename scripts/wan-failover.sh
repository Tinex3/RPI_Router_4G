#!/bin/bash
# =========================================================
# WAN Failover SMART (Sticky + Priority)
# - Soporta 3 modos: ethernet-only, lte-only, auto-smart
# - Modo auto: Sticky failover (no cambia hasta que falle)
# - Prioridad: Ethernet > LTE
# - Evita flapping (saltos constantes)
# =========================================================

PING_TARGET="8.8.8.8"
WAN_4G="wwan0"
WAN_ETH="eth0"
LOG_TAG="wan-failover"
ETH_LAN_FLAG="/etc/ec25-router/eth0-lan-mode"
CONFIG_FILE="/etc/ec25-router/wan-mode.conf"
STATE_FILE="/var/run/wan-failover-state"

# ---------------------------------------------------------
# Funciones de logging
# ---------------------------------------------------------

log_info() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_warn() {
    logger -t "$LOG_TAG" -p user.warning "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
}

log_error() {
    logger -t "$LOG_TAG" -p user.err "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1"
}

# ---------------------------------------------------------
# Funciones de detección
# ---------------------------------------------------------

get_gw_eth() {
    ip route show dev "$WAN_ETH" 2>/dev/null | awk '/via/ {print $3; exit}' | head -1
}

get_gw_4g() {
    ip route show dev "$WAN_4G" 2>/dev/null | awk '/via/ {print $3; exit}' | head -1
}

# Auto-reparar gateway faltante
auto_repair_gateway() {
    local iface="$1"
    
    # Verificar si tiene IP pero no gateway
    if ip addr show "$iface" 2>/dev/null | grep -q "inet "; then
        local gw=""
        if [ "$iface" = "$WAN_ETH" ]; then
            gw=$(get_gw_eth)
        elif [ "$iface" = "$WAN_4G" ]; then
            gw=$(get_gw_4g)
        fi
        
        if [ -z "$gw" ]; then
            log_warn "Auto-reparación: $iface tiene IP pero sin gateway, ejecutando dhclient..."
            dhclient -r "$iface" 2>/dev/null || true
            sleep 2
            dhclient "$iface" 2>/dev/null || true
            sleep 3
            
            # Verificar si se obtuvo gateway
            if [ "$iface" = "$WAN_ETH" ]; then
                gw=$(get_gw_eth)
            elif [ "$iface" = "$WAN_4G" ]; then
                gw=$(get_gw_4g)
            fi
            
            if [ -n "$gw" ]; then
                log_info "✅ Auto-reparación exitosa: $iface gateway obtenido ($gw)"
                return 0
            else
                log_error "❌ Auto-reparación falló: $iface sin gateway después de dhclient"
                return 1
            fi
        fi
    fi
    return 0
}

# Ping específico por interfaz (más robusto)
test_wan_ping() {
    local iface="$1"
    local count="${2:-2}"  # Default 2 pings
    
    # Verificar que la interfaz existe y tiene IP
    if ! ip link show "$iface" &>/dev/null; then
        return 1
    fi
    
    if ! ip addr show "$iface" | grep -q "inet "; then
        return 1
    fi
    
    # Ping con timeout corto y binding a interfaz específica
    if ping -I "$iface" -c "$count" -W 3 -q "$PING_TARGET" &>/dev/null; then
        return 0
    fi
    
    return 1
}

get_current_wan() {
    ip route show | awk '/^default/ {print $5; exit}'
}

# Limpiar rutas duplicadas sin gateway
clean_duplicate_routes() {
    local had_duplicates=false
    
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

# Cambiar WAN activa
switch_to_wan() {
    local iface="$1"
    local gw="$2"
    
    if [ -z "$gw" ]; then
        log_error "No hay gateway disponible para $iface"
        return 1
    fi
    
    # Eliminar ruta por defecto actual
    ip route del default 2>/dev/null || true
    
    # Agregar nueva ruta
    if ip route add default via "$gw" dev "$iface"; then
        log_info "WAN cambiada a: $iface via $gw"
        echo "$iface" > "$STATE_FILE"
        return 0
    else
        log_error "Fallo al cambiar WAN a $iface"
        return 1
    fi
}

# ---------------------------------------------------------
# Cargar configuración
# ---------------------------------------------------------

WAN_MODE="auto-smart"  # Default
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# ---------------------------------------------------------
# Verificar modo eth0-lan
# ---------------------------------------------------------

if [ -f "$ETH_LAN_FLAG" ]; then
    # eth0 es LAN de salida, solo usar EC25
    CURRENT_WAN=$(get_current_wan)
    
    if [ "$CURRENT_WAN" != "$WAN_4G" ]; then
        if test_wan_ping "$WAN_4G"; then
            GW=$(get_gw_4g)
            if [ -n "$GW" ]; then
                switch_to_wan "$WAN_4G" "$GW"
            fi
        else
            log_warn "EC25 sin internet - eth0 en modo LAN"
        fi
    else
        # Verificar que EC25 sigue funcionando
        if ! test_wan_ping "$WAN_4G" 3; then
            log_error "EC25 perdió conectividad - eth0 en modo LAN (sin backup)"
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------
# Limpiar rutas problemáticas
# ---------------------------------------------------------

clean_duplicate_routes

# ---------------------------------------------------------
# MODO: ethernet-only
# ---------------------------------------------------------

if [ "$WAN_MODE" = "ethernet-only" ]; then
    CURRENT_WAN=$(get_current_wan)
    
    # Auto-reparar gateway si falta
    auto_repair_gateway "$WAN_ETH"
    
    if [ "$CURRENT_WAN" != "$WAN_ETH" ]; then
        # Forzar Ethernet
        GW=$(get_gw_eth)
        if [ -z "$GW" ]; then
            # Intentar DHCP
            dhclient -r "$WAN_ETH" 2>/dev/null || true
            sleep 2
            dhclient "$WAN_ETH" 2>/dev/null || true
            sleep 2
            GW=$(get_gw_eth)
        fi
        
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_ETH" "$GW"
        else
            log_error "Ethernet ONLY: Sin gateway disponible"
        fi
    else
        # Monitorear que Ethernet sigue vivo
        if ! test_wan_ping "$WAN_ETH" 3; then
            log_error "Ethernet ONLY: Conectividad perdida"
            # Intentar auto-reparación
            auto_repair_gateway "$WAN_ETH"
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------
# MODO: lte-only
# ---------------------------------------------------------

if [ "$WAN_MODE" = "lte-only" ]; then
    CURRENT_WAN=$(get_current_wan)
    
    # Auto-reparar gateway si falta
    auto_repair_gateway "$WAN_4G"
    
    if [ "$CURRENT_WAN" != "$WAN_4G" ]; then
        # Forzar LTE
        GW=$(get_gw_4g)
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_4G" "$GW"
        else
            log_error "LTE ONLY: Sin gateway disponible"
        fi
    else
        # Monitorear que LTE sigue vivo
        if ! test_wan_ping "$WAN_4G" 3; then
            log_error "LTE ONLY: Conectividad perdida"
            # Intentar auto-reparación
            auto_repair_gateway "$WAN_4G"
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------
# MODO: auto-smart (Sticky Failover)
# ---------------------------------------------------------

CURRENT_WAN=$(get_current_wan)
LAST_WAN=""

if [ -f "$STATE_FILE" ]; then
    LAST_WAN=$(cat "$STATE_FILE")
fi

# Si no hay WAN activa, establecer una con prioridad Ethernet
if [ -z "$CURRENT_WAN" ]; then
    log_info "Sin WAN activa, estableciendo con prioridad Ethernet..."
    
    # Auto-reparar gateway si falta
    auto_repair_gateway "$WAN_ETH"
    
    # Probar Ethernet primero
    if test_wan_ping "$WAN_ETH" 2; then
        GW=$(get_gw_eth)
        if [ -z "$GW" ]; then
            dhclient -r "$WAN_ETH" 2>/dev/null || true
            sleep 2
            dhclient "$WAN_ETH" 2>/dev/null || true
            sleep 2
            GW=$(get_gw_eth)
        fi
        
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_ETH" "$GW"
            exit 0
        fi
    fi
    
    # Auto-reparar gateway LTE si falta
    auto_repair_gateway "$WAN_4G"
    
    # Fallback a LTE
    if test_wan_ping "$WAN_4G" 2; then
        GW=$(get_gw_4g)
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_4G" "$GW"
            exit 0
        fi
    fi
    
    log_error "No hay WAN disponible (ni Ethernet ni LTE)"
    exit 0
fi

# ---------------------------------------------------------
# Monitorear WAN activa (Sticky behavior)
# ---------------------------------------------------------

log_info "Monitoreando WAN activa: $CURRENT_WAN"

# Auto-reparar gateway si falta (prevención)
auto_repair_gateway "$CURRENT_WAN"

# Hacer 3 pings para estar seguro del fallo
if test_wan_ping "$CURRENT_WAN" 3; then
    log_info "WAN activa ($CURRENT_WAN) funcionando correctamente"
    
    # Si estamos en LTE pero Ethernet volvió, cambiar (prioridad Ethernet)
    if [ "$CURRENT_WAN" = "$WAN_4G" ]; then
        auto_repair_gateway "$WAN_ETH"
        if test_wan_ping "$WAN_ETH" 2; then
            GW=$(get_gw_eth)
            if [ -n "$GW" ]; then
                log_info "Ethernet disponible nuevamente, cambiando por prioridad"
                switch_to_wan "$WAN_ETH" "$GW"
            fi
        fi
    fi
    
    exit 0
fi

# ---------------------------------------------------------
# WAN activa FALLÓ - Realizar failover
# ---------------------------------------------------------

log_warn "WAN activa ($CURRENT_WAN) FALLÓ - Iniciando failover..."

if [ "$CURRENT_WAN" = "$WAN_ETH" ]; then
    # Ethernet falló, cambiar a LTE
    auto_repair_gateway "$WAN_4G"
    
    if test_wan_ping "$WAN_4G" 2; then
        GW=$(get_gw_4g)
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_4G" "$GW"
            log_warn "Failover: Ethernet → LTE completado"
        else
            log_error "Failover falló: LTE sin gateway"
        fi
    else
        log_error "Failover falló: LTE sin conectividad"
    fi
else
    # LTE falló, intentar Ethernet
    auto_repair_gateway "$WAN_ETH"
    
    if test_wan_ping "$WAN_ETH" 2; then
        GW=$(get_gw_eth)
        if [ -z "$GW" ]; then
            dhclient -r "$WAN_ETH" 2>/dev/null || true
            sleep 2
            dhclient "$WAN_ETH" 2>/dev/null || true
            sleep 2
            GW=$(get_gw_eth)
        fi
        
        if [ -n "$GW" ]; then
            switch_to_wan "$WAN_ETH" "$GW"
            log_warn "Failover: LTE → Ethernet completado"
        else
            log_error "Failover falló: Ethernet sin gateway"
        fi
    else
        log_error "Failover falló: Ethernet sin conectividad"
    fi
fi

exit 0
