#!/bin/bash
# Script de desinstalacion completa para EC25 Router
# Elimina todos los servicios, configuraciones y archivos

set -e

echo "========================================================================"
echo "         EC25 Router - Desinstalacion Completa                          "
echo "========================================================================"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "[ERROR] Este script debe ejecutarse con sudo"
  echo "   Uso: sudo ./uninstall.sh"
  exit 1
fi

echo "[WARN] Este script eliminara:"
echo "   - Todos los servicios systemd del proyecto"
echo "   - Configuraciones de hostapd y dnsmasq"
echo "   - Reglas iptables del AP"
echo "   - Directorio /opt/ec25-router"
echo "   - Logs en /var/log/ec25-router"
echo ""
read -p "Continuar con la desinstalacion? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Desinstalacion cancelada."
  exit 0
fi

echo ""
echo "[1/8] Deteniendo servicios..."
systemctl stop ec25-router 2>/dev/null || true
systemctl stop wan-manager 2>/dev/null || true
systemctl stop watchdog 2>/dev/null || true
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
systemctl stop wlan0-ap 2>/dev/null || true
echo "   [OK] Servicios detenidos"

echo ""
echo "[2/8] Deshabilitando servicios..."
systemctl disable ec25-router 2>/dev/null || true
systemctl disable wan-manager 2>/dev/null || true
systemctl disable watchdog 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
systemctl disable wlan0-ap 2>/dev/null || true
echo "   [OK] Servicios deshabilitados"

echo ""
echo "[3/8] Eliminando archivos de servicios systemd..."
rm -f /etc/systemd/system/ec25-router.service
rm -f /etc/systemd/system/wan-manager.service
rm -f /etc/systemd/system/watchdog.service
rm -f /etc/systemd/system/wlan0-ap.service
rm -f /etc/systemd/system/hostapd.service
rm -f /etc/systemd/system/dnsmasq.service
systemctl daemon-reload
echo "   [OK] Servicios systemd eliminados"

echo ""
echo "[4/8] Eliminando configuraciones de red..."
# Eliminar configuracion de NetworkManager para wlan0
rm -f /etc/NetworkManager/conf.d/unmanaged-wlan0.conf
# Eliminar configuracion de interfaces
rm -f /etc/network/interfaces.d/wlan0
# Restaurar hostapd default si existe backup
if [ -f /etc/default/hostapd.backup ]; then
  mv /etc/default/hostapd.backup /etc/default/hostapd
fi
# Eliminar configuracion hostapd
rm -rf /etc/hostapd/hostapd.conf
# Restaurar dnsmasq si existe backup
if [ -f /etc/dnsmasq.conf.backup ]; then
  mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
else
  rm -f /etc/dnsmasq.conf
fi
# Restaurar dhcpcd si existe backup
if [ -f /etc/dhcpcd.conf.backup ]; then
  mv /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
fi
echo "   [OK] Configuraciones de red eliminadas"

echo ""
echo "[5/8] Limpiando reglas iptables del AP..."
# Eliminar reglas NAT
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || true
# Eliminar reglas FORWARD
iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wlan0 -o usb0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i usb0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
# Guardar reglas limpias
iptables-save > /etc/iptables.rules 2>/dev/null || true
echo "   [OK] Reglas iptables limpiadas"

echo ""
echo "[6/8] Liberando interfaz wlan0..."
ip addr flush dev wlan0 2>/dev/null || true
ip link set wlan0 down 2>/dev/null || true
# Reiniciar NetworkManager para que retome control de wlan0
systemctl restart NetworkManager 2>/dev/null || true
echo "   [OK] wlan0 liberada"

echo ""
echo "[7/8] Eliminando directorio de instalacion..."
rm -rf /opt/ec25-router
echo "   [OK] /opt/ec25-router eliminado"

echo ""
echo "[8/8] Eliminando logs..."
rm -rf /var/log/ec25-router
rm -f /var/log/setup-ap-*.log
echo "   [OK] Logs eliminados"

echo ""
echo "========================================================================"
echo "              DESINSTALACION COMPLETADA                                 "
echo "========================================================================"
echo ""
echo "El sistema ha sido limpiado. Para reinstalar:"
echo ""
echo "   git clone https://github.com/Tinex3/RPI_Router_4G.git"
echo "   cd RPI_Router_4G"
echo "   ./install.sh"
echo ""
echo "Nota: hostapd y dnsmasq siguen instalados (paquetes apt)"
echo "      Para eliminarlos: sudo apt remove hostapd dnsmasq"
echo ""
