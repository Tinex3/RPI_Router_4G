#!/bin/bash
# =========================================================
# Configurar puerto Ethernet como LAN (salida de internet)
# Similar al WiFi AP, pero por cable
# =========================================================

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Configurar Ethernet como LAN (compartir internet)         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Ejecuta con sudo: sudo bash setup-eth-lan.sh"
  exit 1
fi

echo "⚠️  ADVERTENCIA:"
echo "   Esta configuración cambiará eth0 de WAN (entrada) a LAN (salida)"
echo "   - Ethernet NO se usará para recibir internet"
echo "   - Solo EC25 (4G) será la WAN"
echo "   - Ethernet compartirá internet del EC25 a dispositivos conectados"
echo ""
read -p "¿Continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Configuración cancelada."
  exit 0
fi

ETH_IP="192.168.1.1"
ETH_SUBNET="192.168.1.0/24"
DHCP_START="192.168.1.10"
DHCP_END="192.168.1.100"

echo ""
echo "[1/6] Configurando IP estática en eth0..."
echo ""

# Configurar NetworkManager para ignorar eth0
if command -v nmcli &> /dev/null; then
  echo "   🔧 Excluyendo eth0 de NetworkManager..."
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/unmanaged-eth0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:eth0
EOF
  systemctl restart NetworkManager
  sleep 2
  echo "   ✅ NetworkManager configurado"
fi

# Configurar IP estática
echo "   🔧 Asignando IP estática: $ETH_IP/24"
ip addr flush dev eth0 2>/dev/null || true
ip addr add $ETH_IP/24 dev eth0
ip link set eth0 up

# Hacer persistente en /etc/network/interfaces.d/
mkdir -p /etc/network/interfaces.d
cat > /etc/network/interfaces.d/eth0 << EOF
auto eth0
iface eth0 inet static
    address $ETH_IP
    netmask 255.255.255.0
EOF

echo "   ✅ IP configurada: $ETH_IP/24"

echo ""
echo "[2/6] Configurando DHCP server para eth0..."
echo ""

# Backup de dnsmasq.conf si existe
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.backup-eth ]; then
  cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup-eth
fi

# Agregar configuración para eth0
cat > /etc/dnsmasq.d/eth0-lan.conf << EOF
# DHCP para Ethernet LAN
interface=eth0
dhcp-range=$DHCP_START,$DHCP_END,24h
dhcp-option=option:router,$ETH_IP
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
EOF

echo "   ✅ DHCP configurado: $DHCP_START - $DHCP_END"

echo ""
echo "[3/6] Habilitando IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
fi
sysctl -p > /dev/null 2>&1

echo "   ✅ IP forwarding habilitado"

echo ""
echo "[4/6] Configurando reglas NAT para eth0..."
echo ""

# Reglas FORWARD
iptables -C FORWARD -i eth0 -o wwan0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o wwan0 -j ACCEPT

iptables -C FORWARD -i wwan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wwan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "   ✅ Reglas FORWARD configuradas"

# NAT para subnet de Ethernet
iptables -t nat -C POSTROUTING -s $ETH_SUBNET -o wwan0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s $ETH_SUBNET -o wwan0 -j MASQUERADE

echo "   ✅ NAT configurado para $ETH_SUBNET → wwan0"

# Guardar reglas
iptables-save > /etc/iptables.rules
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
fi

echo "   ✅ Reglas guardadas"

echo ""
echo "[5/6] Actualizando wan-failover para modo LAN..."
echo ""

# Crear flag indicando que eth0 es LAN
touch /etc/ec25-router/eth0-lan-mode
echo "   ✅ Flag creado: /etc/ec25-router/eth0-lan-mode"

echo ""
echo "[6/6] Reiniciando servicios..."
systemctl restart dnsmasq
systemctl restart wan-failover.timer 2>/dev/null || true

echo "   ✅ Servicios reiniciados"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              ✅ CONFIGURACIÓN COMPLETADA                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📡 Configuración Ethernet LAN:"
echo "   IP Gateway: $ETH_IP"
echo "   Subnet: $ETH_SUBNET"
echo "   DHCP: $DHCP_START - $DHCP_END"
echo ""
echo "🔌 Conecta dispositivos a eth0:"
echo "   - Switch/Router/PC recibirán IP automáticamente"
echo "   - Internet compartido desde EC25 (4G)"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - eth0 YA NO se usa como WAN (entrada de internet)"
echo "   - Solo EC25 (wwan0) es la WAN ahora"
echo ""
echo "🔄 Para volver eth0 a modo WAN:"
echo "   sudo bash /opt/ec25-router/scripts/restore-eth-wan.sh"
echo ""
