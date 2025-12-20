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
echo "4️⃣  Configurando los 3 pilares del routing (IP forwarding + FORWARD + NAT)..."
echo ""

# PILAR 1: IP Forwarding (OBLIGATORIO)
echo "   🔧 PILAR 1: IP Forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Hacer persistente
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
fi
sysctl -p > /dev/null 2>&1
echo "   ✅ IP forwarding habilitado y persistente"

# PILAR 2: Reglas FORWARD (permitir tráfico entre interfaces)
echo "   🔧 PILAR 2: Reglas FORWARD..."
iptables -P FORWARD ACCEPT

# wlan0 → WAN (salida)
iptables -C FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

iptables -C FORWARD -i wlan0 -o usb0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o usb0 -j ACCEPT

# WAN → wlan0 (respuestas)
iptables -C FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -C FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "   ✅ Reglas FORWARD configuradas"

# PILAR 3: NAT/MASQUERADE (reescribir IPs para Internet)
echo "   🔧 PILAR 3: NAT/MASQUERADE..."

# NAT genérico
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE

# NAT específico para WiFi
iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE

echo "   ✅ NAT/MASQUERADE configurado"

# Guardar reglas
iptables-save > /etc/iptables.rules
echo "   💾 Reglas iptables guardadas"

echo ""
echo "5️⃣  Verificando y creando servicios systemd si faltan..."

# Verificar si hostapd.service existe
if [ ! -f /lib/systemd/system/hostapd.service ] && [ ! -f /etc/systemd/system/hostapd.service ]; then
  echo "   ⚠️  hostapd.service no existe, creando..."
  
  cat > /etc/systemd/system/hostapd.service << 'EOF'
[Unit]
Description=Access point and authentication server for Wi-Fi and Ethernet
After=network.target wlan0-ap.service

[Service]
Type=forking
PIDFile=/run/hostapd.pid
Restart=on-failure
RestartSec=2
Environment=DAEMON_CONF=/etc/hostapd/hostapd.conf
ExecStart=/usr/sbin/hostapd -B -P /run/hostapd.pid $DAEMON_CONF

[Install]
WantedBy=multi-user.target
EOF
  
  systemctl daemon-reload
  echo "   ✅ hostapd.service creado"
fi

# Verificar si dnsmasq.service existe
if [ ! -f /lib/systemd/system/dnsmasq.service ] && [ ! -f /etc/systemd/system/dnsmasq.service ]; then
  echo "   ⚠️  dnsmasq.service no existe, creando..."
  
  cat > /etc/systemd/system/dnsmasq.service << 'EOF'
[Unit]
Description=dnsmasq - A lightweight DHCP and caching DNS server
After=network.target
Before=network-online.target

[Service]
Type=forking
PIDFile=/run/dnsmasq/dnsmasq.pid
ExecStartPre=/usr/sbin/dnsmasq --test
ExecStart=/usr/sbin/dnsmasq -x /run/dnsmasq/dnsmasq.pid -u dnsmasq -7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new --local-service
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  
  mkdir -p /run/dnsmasq
  chown dnsmasq:nogroup /run/dnsmasq 2>/dev/null || true
  
  systemctl daemon-reload
  echo "   ✅ dnsmasq.service creado"
fi

echo ""
echo "6️⃣  Desmascando y habilitando servicios..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
echo "   ✅ Servicios habilitados"

echo ""
echo "7️⃣  Reiniciando servicios WiFi AP..."
systemctl restart wlan0-ap.service
sleep 2
systemctl restart hostapd
sleep 2
systemctl restart dnsmasq
echo "   ✅ Servicios WiFi reiniciados"

echo ""
echo "8️⃣  Verificando estado final..."
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
echo "8️⃣  Pruebas de conectividad..."
echo ""

# Verificar IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
  echo "   ✅ IP forwarding: Habilitado"
else
  echo "   ❌ IP forwarding: Deshabilitado"
fi

# Verificar FORWARD policy
FORWARD_POLICY=$(iptables -L FORWARD -n | grep "^Chain FORWARD" | awk '{print $4}' | tr -d ')')
if [ "$FORWARD_POLICY" = "ACCEPT" ]; then
  echo "   ✅ Política FORWARD: ACCEPT"
else
  echo "   ⚠️  Política FORWARD: $FORWARD_POLICY"
fi

# Verificar NAT
NAT_COUNT=$(iptables -t nat -L POSTROUTING -n | grep "MASQUERADE" | wc -l)
if [ "$NAT_COUNT" -gt 0 ]; then
  echo "   ✅ Reglas NAT: $NAT_COUNT reglas MASQUERADE activas"
else
  echo "   ❌ Reglas NAT: No encontradas"
fi

echo ""
echo "🔟 Información de la red WiFi:"
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
echo "   iptables -t nat -L POSTROUTING -n -v"
echo "   iptables -L FORWARD -n -v"
echo ""
echo "📱 Pasos para probar:"
echo "   1. Conectar teléfono a red RPI_Router_4G"
echo "   2. Verificar que recibe IP 192.168.50.x"
echo "   3. Hacer ping a 8.8.8.8 - debe funcionar"
echo "   4. Abrir navegador y buscar google.com"
echo ""
