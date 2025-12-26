#!/bin/bash
# =========================================================
# Diagnóstico rápido de conectividad WAN
# Ayuda a identificar por qué no hay internet
# =========================================================

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              Diagnóstico de Conectividad WAN                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------------------------------------------------------
# 1. Verificar modo eth0
# ---------------------------------------------------------
echo "1️⃣  Verificando modo Ethernet..."
if [ -f /etc/ec25-router/eth0-lan-mode ]; then
    echo -e "   ${YELLOW}⚠️  eth0 en MODO LAN (salida)${NC}"
    echo "      → eth0 NO recibe internet, solo comparte"
    echo "      → Solo EC25 puede ser WAN"
    ETH_IS_LAN=true
else
    echo -e "   ${GREEN}✅ eth0 en MODO WAN (entrada)${NC}"
    echo "      → eth0 puede recibir internet"
    ETH_IS_LAN=false
fi

# ---------------------------------------------------------
# 2. Verificar modo WAN failover
# ---------------------------------------------------------
echo ""
echo "2️⃣  Verificando modo WAN Failover..."
WAN_MODE="auto-smart"
if [ -f /etc/ec25-router/wan-mode.conf ]; then
    WAN_MODE=$(grep "^MODE=" /etc/ec25-router/wan-mode.conf | cut -d= -f2)
fi
echo "   Modo configurado: $WAN_MODE"

# ---------------------------------------------------------
# 3. Verificar interfaces de red
# ---------------------------------------------------------
echo ""
echo "3️⃣  Verificando interfaces de red..."

# Ethernet
if ip link show eth0 &>/dev/null; then
    ETH_UP=$(ip link show eth0 | grep -q "state UP" && echo "UP" || echo "DOWN")
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | head -1)
    
    if [ "$ETH_UP" = "UP" ]; then
        echo -e "   ${GREEN}✅ eth0: $ETH_UP${NC}"
    else
        echo -e "   ${RED}❌ eth0: $ETH_UP${NC}"
    fi
    
    if [ -n "$ETH_IP" ]; then
        echo "      IP: $ETH_IP"
    else
        echo -e "      ${RED}Sin IP asignada${NC}"
    fi
else
    echo -e "   ${RED}❌ eth0: NO EXISTE${NC}"
fi

echo ""

# LTE/EC25
if ip link show wwan0 &>/dev/null; then
    LTE_UP=$(ip link show wwan0 | grep -q "state UP" && echo "UP" || echo "DOWN")
    LTE_IP=$(ip addr show wwan0 | grep "inet " | awk '{print $2}' | head -1)
    
    if [ "$LTE_UP" = "UP" ]; then
        echo -e "   ${GREEN}✅ wwan0: $LTE_UP${NC}"
    else
        echo -e "   ${RED}❌ wwan0: $LTE_UP${NC}"
    fi
    
    if [ -n "$LTE_IP" ]; then
        echo "      IP: $LTE_IP"
    else
        echo -e "      ${RED}Sin IP asignada${NC}"
    fi
else
    echo -e "   ${RED}❌ wwan0: NO EXISTE (EC25 no detectado)${NC}"
fi

# ---------------------------------------------------------
# 4. Verificar ruta por defecto
# ---------------------------------------------------------
echo ""
echo "4️⃣  Verificando ruta por defecto (WAN activa)..."
DEFAULT_ROUTE=$(ip route show | grep "^default" | head -1)

if [ -n "$DEFAULT_ROUTE" ]; then
    echo -e "   ${GREEN}✅ Ruta por defecto existe:${NC}"
    echo "      $DEFAULT_ROUTE"
    
    WAN_IFACE=$(echo "$DEFAULT_ROUTE" | awk '{print $5}')
    WAN_GW=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')
    echo ""
    echo "   WAN activa: $WAN_IFACE via $WAN_GW"
else
    echo -e "   ${RED}❌ SIN RUTA POR DEFECTO${NC}"
    echo "      → No hay WAN configurada"
    echo "      → El sistema no puede salir a Internet"
fi

# ---------------------------------------------------------
# 5. Test de conectividad
# ---------------------------------------------------------
echo ""
echo "5️⃣  Probando conectividad real..."

# Test por cada interfaz
if [ "$ETH_IS_LAN" = false ] && ip link show eth0 &>/dev/null; then
    echo -n "   eth0 → 8.8.8.8: "
    if ping -I eth0 -c 2 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALLA${NC}"
    fi
fi

if ip link show wwan0 &>/dev/null; then
    echo -n "   wwan0 → 8.8.8.8: "
    if ping -I wwan0 -c 2 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALLA${NC}"
    fi
fi

# Test general
echo -n "   General → 8.8.8.8: "
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FALLA${NC}"
fi

# ---------------------------------------------------------
# 6. Diagnóstico y recomendaciones
# ---------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              Diagnóstico y Recomendaciones                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

HAS_PROBLEM=false

# Caso 1: eth0 es LAN pero EC25 no funciona
if [ "$ETH_IS_LAN" = true ]; then
    if ! ip link show wwan0 &>/dev/null || ! ping -I wwan0 -c 2 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "${RED}⚠️  PROBLEMA DETECTADO:${NC}"
        echo "   eth0 está en modo LAN (salida)"
        echo "   EC25 no tiene conectividad"
        echo ""
        echo "💡 SOLUCIÓN:"
        echo "   Opción 1: Cambiar eth0 a modo WAN para usar cable:"
        echo "      sudo bash /opt/ec25-router/scripts/restore-eth-wan.sh"
        echo ""
        echo "   Opción 2: Verificar EC25:"
        echo "      - Revisar SIM insertada"
        echo "      - Verificar señal LTE"
        echo "      - Ver logs: journalctl -u wan-manager -f"
        HAS_PROBLEM=true
    fi
fi

# Caso 2: Sin ruta por defecto
if [ -z "$DEFAULT_ROUTE" ]; then
    echo -e "${RED}⚠️  PROBLEMA DETECTADO:${NC}"
    echo "   No hay ruta por defecto (sin WAN activa)"
    echo ""
    echo "💡 SOLUCIÓN:"
    echo "   Ejecutar manualmente wan-failover:"
    echo "      sudo bash /opt/ec25-router/scripts/wan-failover.sh"
    echo ""
    echo "   O reiniciar servicio:"
    echo "      sudo systemctl restart wan-failover.service"
    HAS_PROBLEM=true
fi

# Caso 3: Ambas interfaces sin conectividad
if [ "$ETH_IS_LAN" = false ]; then
    ETH_WORKS=$(ping -I eth0 -c 2 -W 3 8.8.8.8 &>/dev/null && echo true || echo false)
    LTE_WORKS=$(ping -I wwan0 -c 2 -W 3 8.8.8.8 &>/dev/null && echo true || echo false)
    
    if [ "$ETH_WORKS" = false ] && [ "$LTE_WORKS" = false ]; then
        echo -e "${RED}⚠️  PROBLEMA DETECTADO:${NC}"
        echo "   Ninguna interfaz tiene conectividad"
        echo ""
        echo "💡 VERIFICAR:"
        echo "   Ethernet:"
        echo "      - Cable conectado"
        echo "      - Router/switch encendido"
        echo "      - DHCP funcionando: sudo dhclient eth0"
        echo ""
        echo "   LTE/EC25:"
        echo "      - SIM insertada y con saldo/datos"
        echo "      - Antenas conectadas"
        echo "      - Señal LTE: Ver dashboard web"
        HAS_PROBLEM=true
    fi
fi

if [ "$HAS_PROBLEM" = false ]; then
    echo -e "${GREEN}✅ Sistema funcionando correctamente${NC}"
    echo ""
    echo "📊 Resumen:"
    echo "   - eth0: $([ "$ETH_IS_LAN" = true ] && echo "Modo LAN (salida)" || echo "Modo WAN (entrada)")"
    echo "   - WAN failover: $WAN_MODE"
    echo "   - WAN activa: $WAN_IFACE"
    echo "   - Internet: Funcionando"
fi

echo ""
echo "📝 Ver logs:"
echo "   journalctl -u wan-failover.service -f"
echo "   journalctl -u wan-manager -f"
echo ""
