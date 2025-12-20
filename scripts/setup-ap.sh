#!/bin/bash
# Script de configuración del Access Point WiFi
# Configura hostapd, dnsmasq y wlan0

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Configuración de Access Point WiFi                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Este script debe ejecutarse con sudo"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1️⃣  Instalando hostapd y dnsmasq..."
apt update
apt install -y hostapd dnsmasq

echo ""
echo "2️⃣  Deteniendo servicios..."
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

echo ""
echo "3️⃣  Configurando interfaz wlan0..."

# Detectar sistema de red
if [ -f /etc/dhcpcd.conf ]; then
  echo "   📡 Sistema: dhcpcd"
  
  # Backup de dhcpcd.conf si no existe
  if [ ! -f /etc/dhcpcd.conf.backup ]; then
    cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
  fi

  # Configurar IP estática para wlan0
  if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
    cat >> /etc/dhcpcd.conf << 'EOF'

# Access Point Configuration
interface wlan0
    static ip_address=192.168.50.1/24
    nohook wpa_supplicant
EOF
    echo "   ✅ IP estática configurada en dhcpcd.conf"
  else
    echo "   ℹ️  wlan0 ya configurado en dhcpcd.conf"
  fi
  
elif systemctl is-active --quiet NetworkManager; then
  echo "   📡 Sistema: NetworkManager detectado"
  
  # ⚠️ SOLUCIÓN CRÍTICA: Excluir wlan0 de NetworkManager PERMANENTEMENTE
  echo "   🔧 Excluyendo wlan0 del control de NetworkManager..."
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/unmanaged-wlan0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
  
  # Reiniciar NetworkManager para aplicar cambios
  systemctl restart NetworkManager
  sleep 2
  echo "   ✅ wlan0 excluido de NetworkManager (persistente)"
  
  # Crear directorio si no existe
  mkdir -p /etc/network/interfaces.d
  
  # Configurar IP estática
  cat > /etc/network/interfaces.d/wlan0 << 'EOF'
auto wlan0
iface wlan0 inet static
    address 192.168.50.1
    netmask 255.255.255.0
EOF
  
  echo "   ✅ Configuración guardada en /etc/network/interfaces.d/wlan0"
  
  # Aplicar configuración inmediatamente
  ip addr flush dev wlan0 2>/dev/null || true
  ip addr add 192.168.50.1/24 dev wlan0
  ip link set wlan0 up
  
  echo "   ✅ IP aplicada: 192.168.50.1/24"
  
else
  echo "   📡 Sistema: manual"
  
  # Configuración manual directa
  ip addr flush dev wlan0 2>/dev/null || true
  ip addr add 192.168.50.1/24 dev wlan0
  ip link set wlan0 up
  
  echo "   ✅ IP configurada manualmente"
fi

echo ""
echo "4️⃣  Configurando hostapd..."
cp "$SCRIPT_DIR/../config/hostapd.conf" /etc/hostapd/hostapd.conf

# Apuntar hostapd al archivo de configuración
if [ -f /etc/default/hostapd ]; then
  sed -i 's|^#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
  sed -i 's|^DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
fi

echo "   ✅ hostapd configurado"
echo "   📝 SSID: RPI_Router_4G"
echo "   🔑 Password: router4g2024"
echo "   ⚠️  CAMBIAR PASSWORD en /etc/hostapd/hostapd.conf"

echo ""
echo "5️⃣  Configurando dnsmasq..."

# Backup original
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.backup ]; then
  mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

cp "$SCRIPT_DIR/../config/dnsmasq.conf" /etc/dnsmasq.conf
echo "   ✅ dnsmasq configurado"
echo "   📡 DHCP Range: 192.168.50.10 - 192.168.50.100"

echo ""
echo "6️⃣  Habilitando IP forwarding (CRÍTICO para routing)..."
# Activar inmediatamente
echo 1 > /proc/sys/net/ipv4/ip_forward

# Hacer persistente
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  # Descomentar si existe
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  
  # Agregar si no existe
  if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
fi

sysctl -p > /dev/null 2>&1
echo "   ✅ IP forwarding habilitado y persistente"

echo ""
echo "7️⃣  Configurando NAT/Firewall (LOS 3 PILARES DEL ROUTING)..."

# PILAR 1: Política FORWARD permisiva (por defecto DROP bloquea todo)
iptables -P FORWARD ACCEPT
echo "   ✅ Política FORWARD: ACCEPT"

# PILAR 2: Reglas FORWARD explícitas (wlan0 → WAN)
echo "   🔧 Configurando reglas FORWARD..."

# Permitir wlan0 → eth0 (salida por Ethernet)
iptables -C FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Permitir wlan0 → usb0 (salida por LTE)
iptables -C FORWARD -i wlan0 -o usb0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o usb0 -j ACCEPT

# Permitir respuestas: WAN → wlan0 (RELATED,ESTABLISHED)
iptables -C FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -C FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "   ✅ Reglas FORWARD configuradas"

# PILAR 3: NAT/MASQUERADE (reescribir IP origen para salida a Internet)
echo "   🔧 Configurando NAT/MASQUERADE..."

# NAT genérico (todo tráfico saliente por eth0/usb0)
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE

# NAT específico para red WiFi (192.168.50.0/24)
iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE

echo "   ✅ NAT/MASQUERADE configurado"

# Guardar reglas con iptables-save
iptables-save > /etc/iptables.rules
echo "   ✅ Reglas guardadas en /etc/iptables.rules"

# Asegurar que se cargan al arranque
mkdir -p /etc/network/if-pre-up.d
if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
  cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
EOF
  chmod +x /etc/network/if-pre-up.d/iptables
  echo "   ✅ Script de restauración iptables creado"
fi

# También intentar con netfilter-persistent si está disponible
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
  echo "   ✅ Reglas guardadas con netfilter-persistent"
fi

echo "   ✅ Firewall configurado y persistente"

echo ""
echo "8️⃣  Deteniendo ModemManager (puede interferir con WiFi)..."
systemctl stop ModemManager 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
echo "   ✅ ModemManager deshabilitado"

echo ""
echo "9️⃣  Configurando inicio automático..."

# Instalar servicio de configuración wlan0
cp "$SCRIPT_DIR/../systemd/wlan0-ap.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wlan0-ap.service

echo "   ✅ Servicio wlan0-ap habilitado"

systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

echo "   ✅ hostapd y dnsmasq habilitados para arranque automático"

# Iniciar servicio wlan0-ap primero
systemctl start wlan0-ap.service
sleep 2
🔟 Verificando estado..."
echo ""

# Verificar wlan0
if ip addr show wlan0 | grep -q "192.168.50.1"; then
  echo "   ✅ wlan0: IP 192.168.50.1 asignada"
else
  echo "   ⚠️  wlan0: IP no configurada correctamente"
fi

# Verificar hostapd
if systemctl is-active --quiet hostapd; then
  if journalctl -u hostapd -n 5 | grep -q "AP-ENABLED"; then
    echo "   ✅ hostapd: RUNNING (AP activado)"
  else
    echo "   ⚠️  hostapd: Running pero sin confirmar AP-ENABLED"
  fi
else
  echo "   ❌ hostapd: FAILED"
  echo "      Ver logs: sudo journalctl -u hostapd -n 20"
fi

# Verificar dnsmasq
if systemctl is-active --quiet dnsmasq; then
  echo "   ✅ dnsmasq: RUNNING"
else
  echo "   ❌ dnsmasq: FAILED"
  echo "      Ver logs: sudo journalctl -u dnsmasq -n 20"
fi

# Verificar iptables
if iptables -t nat -L POSTROUTING -n | grep -q "192.168.50.0/24"; then
  echo "   ✅ iptables: Reglas NAT configuradas"
else
  echo "   ⚠️  iptables: Reglas NAT podrían no estar completas"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              ✅ CONFIGURACIÓN COMPLETADA                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📡 Red WiFi creada:"
echo "   SSID: RPI_Router_4G"
echo "   Password: router4g2024"
echo "   IP Gateway: 192.168.50.1"
echo "   DHCP Range: 192.168.50.10 - 192.168.50.100"
echo ""
echo "🔧 Comandos útiles:"
echo "   Ver logs hostapd:  sudo journalctl -u hostapd -f"
echo "   Reiniciar AP:      sudo systemctl restart wlan0-ap hostapd dnsmasq"
echo "   Verificar wlan0:   iw dev wlan0 info"
echo "   Ver clientes WiFi: iw dev wlan0 station dump════════════════════════╗"
echo "║              ✅ CONFIGURACIÓN COMPLETADA                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📡 Red WiFi creada:"
echo "   SSID: RPI_Router_4G"
echo "   Password: router4g2024"
echo "   IP Gateway: 192.168.50.1"
echo "   DHCP Range: 192.168.50.10 - 192.168.50.100"
echo ""
echo "🔧 Para cambiar SSID/Password:"
echo "   sudo nano /etc/hostapd/hostapd.conf"
echo "   sudo systemctl restart hostapd"
echo ""
echo "📝 Ver logs:"
echo "   sudo journalctl -u hostapd -f"
echo "   sudo journalctl -u dnsmasq -f"
echo ""
echo "🔍 Ver clientes conectados:"
echo "   arp -n | grep 192.168.50"
echo ""
