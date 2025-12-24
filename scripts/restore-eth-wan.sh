#!/bin/bash
# =========================================================
# Restaurar puerto Ethernet a modo WAN (entrada de internet)
# Reversa de setup-eth-lan.sh
# =========================================================

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Restaurar Ethernet como WAN (entrada de internet)         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Ejecuta con sudo: sudo bash restore-eth-wan.sh"
  exit 1
fi

echo "[1/5] Eliminando IP estática de eth0..."
ip addr flush dev eth0 2>/dev/null || true
rm -f /etc/network/interfaces.d/eth0
echo "   ✅ IP estática eliminada"

echo ""
echo "[2/5] Restaurando control de NetworkManager sobre eth0..."
rm -f /etc/NetworkManager/conf.d/unmanaged-eth0.conf
systemctl restart NetworkManager
sleep 2
echo "   ✅ NetworkManager restaurado"

echo ""
echo "[3/5] Eliminando configuración DHCP de eth0..."
rm -f /etc/dnsmasq.d/eth0-lan.conf
systemctl restart dnsmasq
echo "   ✅ DHCP de eth0 eliminado"

echo ""
echo "[4/5] Eliminando reglas NAT para eth0..."
iptables -t nat -D POSTROUTING -s 192.168.1.0/24 -o wwan0 -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i eth0 -o wwan0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wwan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

iptables-save > /etc/iptables.rules
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
fi
echo "   ✅ Reglas NAT eliminadas"

echo ""
echo "[5/5] Restaurando modo WAN..."
rm -f /etc/ec25-router/eth0-lan-mode
systemctl restart wan-failover.timer 2>/dev/null || true
echo "   ✅ Modo WAN restaurado"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              ✅ RESTAURACIÓN COMPLETADA                           ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ eth0 vuelve a ser WAN (entrada de internet)"
echo "✅ Failover automático: EC25 → Ethernet habilitado"
echo ""
