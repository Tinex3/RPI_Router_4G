#!/bin/bash
# Script de configuracion del Access Point WiFi
# Configura hostapd, dnsmasq y wlan0

set -e

# Configurar logging
LOGFILE="/var/log/setup-ap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "========================================================================"
echo "         Configuracion de Access Point WiFi                             "
echo "========================================================================"
echo ""
echo "[LOG] Log guardado en: $LOGFILE"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "[ERROR] Este script debe ejecutarse con sudo"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/10] Verificando conectividad a Internet..."
if ! ping -c 1 8.8.8.8 &>/dev/null; then
  echo "   [WARN] Sin conectividad a Internet"
  echo "   Verificando si los paquetes ya estan instalados..."
fi

echo ""
echo "[2/10] Descargando/verificando paquetes necesarios..."
apt update || echo "   [WARN] No se pudo actualizar repositorios, usando cache local"

# Verificar si ya estan instalados
HOSTAPD_INSTALLED=$(dpkg -l | grep -c "^ii  hostapd" || echo "0")
DNSMASQ_INSTALLED=$(dpkg -l | grep -c "^ii  dnsmasq" || echo "0")

if [ "$HOSTAPD_INSTALLED" = "0" ] || [ "$DNSMASQ_INSTALLED" = "0" ]; then
  echo "   [INFO] Instalando paquetes faltantes..."
  if ! apt install -y hostapd dnsmasq; then
    echo ""
    echo "   [ERROR] No se pudieron instalar los paquetes"
    echo "   Verifica tu conectividad a Internet y vuelve a intentar."
    echo ""
    echo "   Comandos de diagnostico:"
    echo "     ping -c 2 8.8.8.8"
    echo "     ip route show"
    echo "     cat /etc/resolv.conf"
    exit 1
  fi
else
  echo "   [OK] hostapd y dnsmasq ya estan instalados"
fi

echo ""
echo "[3/10] Deteniendo servicios..."
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

echo ""
echo "[4/10] Configurando interfaz wlan0..."

# Detectar sistema de red
if [ -f /etc/dhcpcd.conf ]; then
  echo "   [INFO] Sistema: dhcpcd"
  
  # Backup de dhcpcd.conf si no existe
  if [ ! -f /etc/dhcpcd.conf.backup ]; then
    cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
  fi

  # Configurar IP estatica para wlan0
  if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
    cat >> /etc/dhcpcd.conf << 'EOF'

# Access Point Configuration
interface wlan0
    static ip_address=192.168.50.1/24
    nohook wpa_supplicant
EOF
    echo "   [OK] IP estatica configurada en dhcpcd.conf"
  else
    echo "   [INFO] wlan0 ya configurado en dhcpcd.conf"
  fi
  
elif systemctl is-active --quiet NetworkManager; then
  echo "   [INFO] Sistema: NetworkManager detectado"
  
  # SOLUCION CRITICA: Excluir wlan0 de NetworkManager PERMANENTEMENTE
  echo "   [INFO] Excluyendo wlan0 del control de NetworkManager..."
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/unmanaged-wlan0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
  
  # Reiniciar NetworkManager para aplicar cambios
  systemctl restart NetworkManager
  sleep 2
  echo "   [OK] wlan0 excluido de NetworkManager (persistente)"
  
  # Crear directorio si no existe
  mkdir -p /etc/network/interfaces.d
  
  # Configurar IP estatica
  cat > /etc/network/interfaces.d/wlan0 << 'EOF'
auto wlan0
iface wlan0 inet static
    address 192.168.50.1
    netmask 255.255.255.0
EOF
  
  echo "   [OK] Configuracion guardada en /etc/network/interfaces.d/wlan0"
  
  # Aplicar configuracion inmediatamente
  ip addr flush dev wlan0 2>/dev/null || true
  ip addr add 192.168.50.1/24 dev wlan0
  ip link set wlan0 up
  
  echo "   [OK] IP aplicada: 192.168.50.1/24"
  
else
  echo "   [INFO] Sistema: manual"
  
  # Configuracion manual directa
  ip addr flush dev wlan0 2>/dev/null || true
  ip addr add 192.168.50.1/24 dev wlan0
  ip link set wlan0 up
  
  echo "   [OK] IP configurada manualmente"
fi

echo ""
echo "[5/10] Configurando hostapd..."
# Crear directorio si no existe
mkdir -p /etc/hostapd
cp "$SCRIPT_DIR/../config/hostapd.conf" /etc/hostapd/hostapd.conf

# Apuntar hostapd al archivo de configuracion
if [ -f /etc/default/hostapd ]; then
  sed -i 's|^#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
  sed -i 's|^DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
fi

echo "   [OK] hostapd configurado"
echo "   SSID: RPI_Router_4G"
echo "   Password: router4g2024"
echo "   [WARN] CAMBIAR PASSWORD en /etc/hostapd/hostapd.conf"

echo ""
echo "[6/10] Configurando dnsmasq..."

# Backup original
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.backup ]; then
  mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

# Crear directorio dnsmasq.d si no existe
mkdir -p /etc/dnsmasq.d

cp "$SCRIPT_DIR/../config/dnsmasq.conf" /etc/dnsmasq.conf
echo "   [OK] dnsmasq configurado"
echo "   DHCP Range: 192.168.50.10 - 192.168.50.100"

echo ""
echo "[7/10] Habilitando IP forwarding..."
# Activar inmediatamente
echo 1 > /proc/sys/net/ipv4/ip_forward

# Hacer persistente
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
fi

sysctl -p > /dev/null 2>&1
echo "   [OK] IP forwarding habilitado y persistente"

echo ""
echo "[8/10] Configurando NAT/Firewall (LOS 3 PILARES)..."

# PILAR 1: Politica FORWARD permisiva
iptables -P FORWARD ACCEPT
echo "   [OK] Politica FORWARD: ACCEPT"

# PILAR 2: Reglas FORWARD explicitas
echo "   [INFO] Configurando reglas FORWARD..."

iptables -C FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

iptables -C FORWARD -i wlan0 -o usb0 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i wlan0 -o usb0 -j ACCEPT

iptables -C FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -C FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "   [OK] Reglas FORWARD configuradas"

# PILAR 3: NAT/MASQUERADE
echo "   [INFO] Configurando NAT/MASQUERADE..."

iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE

echo "   [OK] NAT/MASQUERADE configurado"

# Guardar reglas
iptables-save > /etc/iptables.rules
echo "   [OK] Reglas guardadas en /etc/iptables.rules"

# Asegurar que se cargan al arranque
mkdir -p /etc/network/if-pre-up.d
if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
  cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
EOF
  chmod +x /etc/network/if-pre-up.d/iptables
  echo "   [OK] Script de restauracion iptables creado"
fi

if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
  echo "   [OK] Reglas guardadas con netfilter-persistent"
fi

echo "   [OK] Firewall configurado y persistente"

echo ""
echo "[9/10] Deteniendo ModemManager..."
systemctl stop ModemManager 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
echo "   [OK] ModemManager deshabilitado"

echo ""
echo "[10/10] Configurando inicio automatico..."

# Instalar servicio de configuracion wlan0
cp "$SCRIPT_DIR/../systemd/wlan0-ap.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wlan0-ap.service

echo "   [OK] Servicio wlan0-ap habilitado"

# Verificar si hostapd.service existe
if [ ! -f /lib/systemd/system/hostapd.service ] && [ ! -f /etc/systemd/system/hostapd.service ]; then
  echo "   [WARN] hostapd.service no existe, creando servicio systemd..."
  
  cat > /etc/systemd/system/hostapd.service << 'EOF'
[Unit]
Description=Access point and authentication server for Wi-Fi and Ethernet
After=network.target
Before=network-online.target
Wants=network-online.target

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
  echo "   [OK] Servicio hostapd.service creado"
fi

systemctl unmask hostapd 2>/dev/null || true
systemctl enable hostapd

# Verificar si dnsmasq.service existe
if [ ! -f /lib/systemd/system/dnsmasq.service ] && [ ! -f /etc/systemd/system/dnsmasq.service ]; then
  echo "   [WARN] dnsmasq.service no existe, creando servicio systemd..."
  
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
  echo "   [OK] Servicio dnsmasq.service creado"
fi

systemctl enable dnsmasq

echo "   [OK] hostapd y dnsmasq habilitados para arranque automatico"

# Iniciar servicios
echo ""
echo "[INFO] Iniciando servicios..."
systemctl start wlan0-ap.service || echo "   [WARN] wlan0-ap fallo al iniciar"
sleep 2
systemctl start hostapd || echo "   [WARN] hostapd fallo al iniciar"
sleep 2
systemctl start dnsmasq || echo "   [WARN] dnsmasq fallo al iniciar"

echo ""
echo "[INFO] Verificando estado..."
echo ""

# Verificar wlan0
if ip addr show wlan0 | grep -q "192.168.50.1"; then
  echo "   [OK] wlan0: IP 192.168.50.1 asignada"
else
  echo "   [WARN] wlan0: IP no configurada correctamente"
fi

# Verificar hostapd
if systemctl is-active --quiet hostapd; then
  if journalctl -u hostapd -n 5 | grep -q "AP-ENABLED"; then
    echo "   [OK] hostapd: RUNNING - AP activado"
  else
    echo "   [WARN] hostapd: Running pero sin confirmar AP-ENABLED"
  fi
else
  echo "   [ERROR] hostapd: FAILED"
  echo "      Ver logs: sudo journalctl -u hostapd -n 20"
fi

# Verificar dnsmasq
if systemctl is-active --quiet dnsmasq; then
  echo "   [OK] dnsmasq: RUNNING"
else
  echo "   [ERROR] dnsmasq: FAILED"
  echo "      Ver logs: sudo journalctl -u dnsmasq -n 20"
fi

# Verificar iptables
if iptables -t nat -L POSTROUTING -n | grep -q "192.168.50.0/24"; then
  echo "   [OK] iptables: Reglas NAT configuradas"
else
  echo "   [WARN] iptables: Reglas NAT podrian no estar completas"
fi

echo ""
echo "========================================================================"
echo "              CONFIGURACION COMPLETADA                                  "
echo "========================================================================"
echo ""
echo "[LOG] Log completo guardado en: $LOGFILE"
echo ""
echo "Red WiFi creada:"
echo "   SSID: RPI_Router_4G"
echo "   Password: router4g2024"
echo "   IP Gateway: 192.168.50.1"
echo "   DHCP Range: 192.168.50.10 - 192.168.50.100"
echo ""
echo "Comandos utiles:"
echo "   Ver logs hostapd:  sudo journalctl -u hostapd -f"
echo "   Reiniciar AP:      sudo systemctl restart wlan0-ap hostapd dnsmasq"
echo "   Verificar wlan0:   iw dev wlan0 info"
echo "   Ver clientes WiFi: iw dev wlan0 station dump"
echo ""
echo "Para cambiar SSID/Password:"
echo "   sudo nano /etc/hostapd/hostapd.conf"
echo "   sudo systemctl restart hostapd"
echo ""
