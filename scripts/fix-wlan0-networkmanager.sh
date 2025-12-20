#!/bin/bash
# Fix rápido para wlan0 - Excluir de NetworkManager permanentemente

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         FIX: Excluir wlan0 de NetworkManager (SOLUCIÓN REAL)      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Ejecuta con sudo"
  exit 1
fi

echo "1️⃣  Creando configuración permanente de NetworkManager..."
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/unmanaged-wlan0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
echo "   ✅ Archivo creado: /etc/NetworkManager/conf.d/unmanaged-wlan0.conf"

echo ""
echo "2️⃣  Reiniciando NetworkManager..."
systemctl restart NetworkManager
sleep 2
echo "   ✅ NetworkManager reiniciado (wlan0 ya NO está bajo su control)"

echo ""
echo "3️⃣  Configurando IP en wlan0..."
ip addr flush dev wlan0
ip addr add 192.168.50.1/24 dev wlan0
ip link set wlan0 up
echo "   ✅ IP 192.168.50.1/24 asignada"

echo ""
echo "4️⃣  Agregando reglas iptables específicas para WiFi..."
iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE

# Guardar reglas
iptables-save > /etc/iptables.rules
echo "   ✅ Reglas iptables configuradas y guardadas"

echo ""
echo "5️⃣  Desmascando y habilitando hostapd..."
systemctl unmask hostapd
systemctl enable hostapd
echo "   ✅ hostapd habilitado"

echo ""
echo "6️⃣  Reiniciando servicios WiFi AP..."
systemctl restart wlan0-ap.service
sleep 2
systemctl restart hostapd
sleep 2
systemctl restart dnsmasq
echo "   ✅ Servicios WiFi reiniciados"

echo ""
echo "7️⃣  Verificando estado final..."
echo ""

# Estado wlan0
if ip addr show wlan0 | grep -q "192.168.50.1"; then
  echo "   ✅ wlan0: IP 192.168.50.1 asignada"
else
  echo "   ❌ wlan0: Sin IP"
fi

# Estado hostapd
if systemctl is-active --quiet hostapd; then
  if journalctl -u hostapd -n 5 | grep -q "AP-ENABLED"; then
    echo "   ✅ hostapd: AP-ENABLED (red WiFi transmitiendo)"
  else
    echo "   ⚠️  hostapd: Running pero verificar logs"
  fi
else
  echo "   ❌ hostapd: FAILED"
fi

# Estado dnsmasq
if systemctl is-active --quiet dnsmasq; then
  echo "   ✅ dnsmasq: RUNNING"
else
  echo "   ❌ dnsmasq: FAILED"
fi

echo ""
echo "8️⃣  Información de la red WiFi:"
echo ""
echo "   SSID: RPI_Router_4G"
echo "   Password: router4g2024"
echo "   Gateway: 192.168.50.1"
echo "   DHCP: 192.168.50.10 - 192.168.50.100"
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ FIX APLICADO                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Verificar con:"
echo "   ip addr show wlan0"
echo "   sudo journalctl -u hostapd -n 10"
echo "   iw dev wlan0 info"
echo ""
echo "📱 Buscar red WiFi 'RPI_Router_4G' desde tu teléfono"
echo ""
