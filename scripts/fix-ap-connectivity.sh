#!/bin/bash
# =========================================================
# Diagnóstico y Reparación de WiFi Access Point
# Verifica NAT, forwarding, DHCP y conectividad
# =========================================================

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Diagnóstico WiFi Access Point                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WIFI_SUBNET="192.168.50.0/24"
WIFI_IFACE="wlan0"

# ---------------------------------------------------------
# 1. Verificar interfaz WiFi
# ---------------------------------------------------------
echo "1️⃣  Verificando interfaz WiFi (wlan0)..."

if ! ip link show "$WIFI_IFACE" &>/dev/null; then
    echo -e "   ${RED}❌ $WIFI_IFACE no existe${NC}"
    echo "   Verifica que el adaptador WiFi esté conectado"
    exit 1
fi

WIFI_UP=$(ip link show "$WIFI_IFACE" | grep -q "state UP" && echo "UP" || echo "DOWN")
WIFI_IP=$(ip addr show "$WIFI_IFACE" | grep "inet " | awk '{print $2}')

if [ "$WIFI_UP" = "UP" ]; then
    echo -e "   ${GREEN}✅ $WIFI_IFACE: UP${NC}"
else
    echo -e "   ${RED}❌ $WIFI_IFACE: DOWN${NC}"
fi

if [ -n "$WIFI_IP" ]; then
    echo -e "   ${GREEN}✅ IP: $WIFI_IP${NC}"
else
    echo -e "   ${RED}❌ Sin IP asignada${NC}"
    echo "   Asignando IP 192.168.50.1/24..."
    sudo ip addr add 192.168.50.1/24 dev "$WIFI_IFACE" 2>/dev/null || true
    WIFI_IP="192.168.50.1/24"
fi

# ---------------------------------------------------------
# 2. Verificar WAN activa
# ---------------------------------------------------------
echo ""
echo "2️⃣  Verificando WAN (salida a internet)..."

WAN_IFACE=$(ip route show | awk '/^default/ {print $5; exit}')
WAN_GW=$(ip route show | awk '/^default/ {print $3; exit}')

if [ -n "$WAN_IFACE" ]; then
    echo -e "   ${GREEN}✅ WAN activa: $WAN_IFACE via $WAN_GW${NC}"
else
    echo -e "   ${RED}❌ Sin WAN activa${NC}"
    echo "   Ver: sudo bash /opt/ec25-router/scripts/diagnose-wan.sh"
    exit 1
fi

# Test de conectividad WAN
echo -n "   Test WAN → 8.8.8.8: "
if ping -I "$WAN_IFACE" -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FALLA${NC}"
    echo "   La WAN no tiene conectividad real"
fi

# ---------------------------------------------------------
# 3. Verificar IP Forwarding
# ---------------------------------------------------------
echo ""
echo "3️⃣  Verificando IP Forwarding..."

FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$FORWARDING" = "1" ]; then
    echo -e "   ${GREEN}✅ IP Forwarding habilitado${NC}"
else
    echo -e "   ${RED}❌ IP Forwarding deshabilitado${NC}"
    echo "   Habilitando..."
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    echo -e "   ${GREEN}✅ Habilitado temporalmente${NC}"
    
    # Hacer persistente
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
        echo "   ✅ Configurado como persistente"
    fi
fi

# ---------------------------------------------------------
# 4. Verificar reglas FORWARD
# ---------------------------------------------------------
echo ""
echo "4️⃣  Verificando reglas FORWARD (iptables)..."

# Regla: WiFi → WAN
FORWARD_OUT=$(sudo iptables -C FORWARD -i "$WIFI_IFACE" -o "$WAN_IFACE" -j ACCEPT 2>&1)
if echo "$FORWARD_OUT" | grep -q "Bad rule"; then
    echo -e "   ${RED}❌ FORWARD $WIFI_IFACE → $WAN_IFACE: NO EXISTE${NC}"
    echo "   Agregando regla..."
    sudo iptables -A FORWARD -i "$WIFI_IFACE" -o "$WAN_IFACE" -j ACCEPT
    echo -e "   ${GREEN}✅ Regla agregada${NC}"
else
    echo -e "   ${GREEN}✅ FORWARD $WIFI_IFACE → $WAN_IFACE: OK${NC}"
fi

# Regla: WAN → WiFi (ESTABLISHED, RELATED)
FORWARD_IN=$(sudo iptables -C FORWARD -i "$WAN_IFACE" -o "$WIFI_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>&1)
if echo "$FORWARD_IN" | grep -q "Bad rule"; then
    echo -e "   ${RED}❌ FORWARD $WAN_IFACE → $WIFI_IFACE: NO EXISTE${NC}"
    echo "   Agregando regla..."
    sudo iptables -A FORWARD -i "$WAN_IFACE" -o "$WIFI_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo -e "   ${GREEN}✅ Regla agregada${NC}"
else
    echo -e "   ${GREEN}✅ FORWARD $WAN_IFACE → $WIFI_IFACE: OK${NC}"
fi

# ---------------------------------------------------------
# 5. Verificar reglas NAT (MASQUERADE)
# ---------------------------------------------------------
echo ""
echo "5️⃣  Verificando NAT/MASQUERADE..."

NAT_EXISTS=$(sudo iptables -t nat -C POSTROUTING -s "$WIFI_SUBNET" -o "$WAN_IFACE" -j MASQUERADE 2>&1)
if echo "$NAT_EXISTS" | grep -q "Bad rule"; then
    echo -e "   ${RED}❌ NAT $WIFI_SUBNET → $WAN_IFACE: NO EXISTE${NC}"
    echo "   Agregando regla NAT..."
    sudo iptables -t nat -A POSTROUTING -s "$WIFI_SUBNET" -o "$WAN_IFACE" -j MASQUERADE
    echo -e "   ${GREEN}✅ Regla NAT agregada${NC}"
else
    echo -e "   ${GREEN}✅ NAT $WIFI_SUBNET → $WAN_IFACE: OK${NC}"
fi

# Mostrar reglas NAT actuales
echo ""
echo "   Reglas NAT actuales:"
sudo iptables -t nat -L POSTROUTING -v -n | grep "$WIFI_SUBNET" | head -5

# ---------------------------------------------------------
# 6. Guardar reglas iptables
# ---------------------------------------------------------
echo ""
echo "6️⃣  Guardando reglas iptables..."

sudo iptables-save > /tmp/iptables-backup.rules
sudo cp /tmp/iptables-backup.rules /etc/iptables.rules
echo -e "   ${GREEN}✅ Reglas guardadas en /etc/iptables.rules${NC}"

if command -v netfilter-persistent &> /dev/null; then
    sudo netfilter-persistent save
    echo -e "   ${GREEN}✅ Reglas guardadas con netfilter-persistent${NC}"
fi

# ---------------------------------------------------------
# 7. Verificar DHCP (dnsmasq)
# ---------------------------------------------------------
echo ""
echo "7️⃣  Verificando DHCP server (dnsmasq)..."

if systemctl is-active --quiet dnsmasq; then
    echo -e "   ${GREEN}✅ dnsmasq activo${NC}"
else
    echo -e "   ${RED}❌ dnsmasq NO está activo${NC}"
    echo "   Iniciando dnsmasq..."
    sudo systemctl start dnsmasq
    if systemctl is-active --quiet dnsmasq; then
        echo -e "   ${GREEN}✅ dnsmasq iniciado${NC}"
    else
        echo -e "   ${RED}❌ Error al iniciar dnsmasq${NC}"
        echo "   Ver logs: sudo journalctl -u dnsmasq -n 20"
    fi
fi

# Verificar configuración WiFi en dnsmasq
if [ -f /etc/dnsmasq.d/wlan0-ap.conf ]; then
    echo -e "   ${GREEN}✅ Configuración WiFi AP existe${NC}"
    echo "   Contenido:"
    cat /etc/dnsmasq.d/wlan0-ap.conf | grep -E "interface|dhcp-range|dhcp-option" | sed 's/^/      /'
else
    echo -e "   ${YELLOW}⚠️  Configuración WiFi AP no encontrada${NC}"
fi

# ---------------------------------------------------------
# 8. Verificar hostapd
# ---------------------------------------------------------
echo ""
echo "8️⃣  Verificando hostapd (WiFi AP)..."

if systemctl is-active --quiet hostapd; then
    echo -e "   ${GREEN}✅ hostapd activo${NC}"
else
    echo -e "   ${YELLOW}⚠️  hostapd NO está activo${NC}"
    echo "   Iniciando hostapd..."
    sudo systemctl start hostapd
    if systemctl is-active --quiet hostapd; then
        echo -e "   ${GREEN}✅ hostapd iniciado${NC}"
    else
        echo -e "   ${RED}❌ Error al iniciar hostapd${NC}"
        echo "   Ver logs: sudo journalctl -u hostapd -n 20"
    fi
fi

# ---------------------------------------------------------
# 9. Test final
# ---------------------------------------------------------
echo ""
echo "9️⃣  Test de conectividad desde AP..."

# Ping desde el router mismo
echo -n "   Router → 8.8.8.8: "
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FALLA${NC}"
fi

# ---------------------------------------------------------
# RESUMEN
# ---------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   DIAGNÓSTICO COMPLETADO                           ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${BLUE}📊 Resumen de configuración:${NC}"
echo "   WiFi Interface: $WIFI_IFACE ($WIFI_IP)"
echo "   WiFi Subnet: $WIFI_SUBNET"
echo "   WAN Interface: $WAN_IFACE via $WAN_GW"
echo "   IP Forwarding: $([ "$FORWARDING" = "1" ] && echo "Habilitado" || echo "Deshabilitado")"
echo "   DHCP Server: $(systemctl is-active dnsmasq)"
echo "   WiFi AP: $(systemctl is-active hostapd)"
echo ""

echo -e "${GREEN}✅ Reparación completada${NC}"
echo ""
echo "🧪 Prueba desde un cliente WiFi:"
echo "   1. Conéctate al WiFi AP"
echo "   2. Verifica IP: 192.168.50.x"
echo "   3. Ping gateway: ping 192.168.50.1"
echo "   4. Ping internet: ping 8.8.8.8"
echo "   5. Ping DNS: ping google.com"
echo ""

echo "📝 Si persiste el problema:"
echo "   Ver logs AP: sudo journalctl -u hostapd -f"
echo "   Ver logs DHCP: sudo journalctl -u dnsmasq -f"
echo "   Ver reglas: sudo iptables -L -v -n"
echo "   Ver NAT: sudo iptables -t nat -L -v -n"
echo ""
