#!/bin/bash
# Script de verificación post-instalación
# Valida que todos los servicios y configuraciones estén correctos

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         EC25 Router - Verificación de Instalación                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "1️⃣  Verificando servicios principales..."
echo ""

for service in wan-manager watchdog ec25-router; do
  if systemctl is-active --quiet "$service"; then
    echo -e "   ${GREEN}✅${NC} $service: RUNNING"
  else
    echo -e "   ${RED}❌${NC} $service: FAILED"
    ((ERRORS++))
  fi
done

echo ""
echo "2️⃣  Verificando WiFi Access Point..."
echo ""

# wlan0-ap service
if systemctl is-active --quiet wlan0-ap 2>/dev/null || systemctl is-enabled --quiet wlan0-ap 2>/dev/null; then
  echo -e "   ${GREEN}✅${NC} wlan0-ap.service: Configurado"
else
  echo -e "   ${YELLOW}⚠️${NC}  wlan0-ap.service: No configurado (opcional)"
  ((WARNINGS++))
fi

# hostapd
if systemctl is-active --quiet hostapd 2>/dev/null; then
  if sudo journalctl -u hostapd -n 5 2>/dev/null | grep -q "AP-ENABLED"; then
    echo -e "   ${GREEN}✅${NC} hostapd: RUNNING (AP activado)"
  else
    echo -e "   ${YELLOW}⚠️${NC}  hostapd: Running pero sin AP-ENABLED"
    ((WARNINGS++))
  fi
else
  echo -e "   ${YELLOW}⚠️${NC}  hostapd: No activo (¿WiFi AP configurado?)"
  ((WARNINGS++))
fi

# dnsmasq
if systemctl is-active --quiet dnsmasq 2>/dev/null; then
  echo -e "   ${GREEN}✅${NC} dnsmasq: RUNNING"
else
  echo -e "   ${YELLOW}⚠️${NC}  dnsmasq: No activo (¿WiFi AP configurado?)"
  ((WARNINGS++))
fi

# wlan0 interface
if ip addr show wlan0 2>/dev/null | grep -q "192.168.50.1"; then
  echo -e "   ${GREEN}✅${NC} wlan0: IP 192.168.50.1 configurada"
elif ip link show wlan0 &>/dev/null; then
  echo -e "   ${YELLOW}⚠️${NC}  wlan0: Interface existe pero sin IP configurada"
  ((WARNINGS++))
else
  echo -e "   ${YELLOW}⚠️${NC}  wlan0: Interface no encontrada"
  ((WARNINGS++))
fi

echo ""
echo "3️⃣  Verificando configuración de red..."
echo ""

# IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
  echo -e "   ${GREEN}✅${NC} IP forwarding: Habilitado"
else
  echo -e "   ${RED}❌${NC} IP forwarding: Deshabilitado"
  ((ERRORS++))
fi

# iptables NAT rules
if sudo iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE"; then
  echo -e "   ${GREEN}✅${NC} iptables NAT: Configurado"
  
  # Verificar reglas específicas de WiFi
  if sudo iptables -t nat -L POSTROUTING -n | grep -q "192.168.50.0/24"; then
    echo -e "   ${GREEN}✅${NC} iptables WiFi: Reglas específicas presentes"
  else
    echo -e "   ${YELLOW}⚠️${NC}  iptables WiFi: Sin reglas específicas (usará reglas genéricas)"
    ((WARNINGS++))
  fi
else
  echo -e "   ${RED}❌${NC} iptables NAT: No configurado"
  ((ERRORS++))
fi

# iptables persistence
if [ -f /etc/iptables.rules ] || command -v netfilter-persistent &> /dev/null; then
  echo -e "   ${GREEN}✅${NC} iptables: Persistencia configurada"
else
  echo -e "   ${YELLOW}⚠️${NC}  iptables: Sin persistencia (se perderán al reiniciar)"
  ((WARNINGS++))
fi

echo ""
echo "4️⃣  Verificando interfaz web..."
echo ""

# Verificar puerto 5000
if netstat -tuln 2>/dev/null | grep -q ":5000 " || ss -tuln 2>/dev/null | grep -q ":5000 "; then
  echo -e "   ${GREEN}✅${NC} Puerto 5000: Escuchando"
  
  # Intentar hacer curl
  if command -v curl &> /dev/null; then
    if timeout 3 curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/ | grep -q "200\|302"; then
      echo -e "   ${GREEN}✅${NC} Web: Respondiendo correctamente"
    else
      echo -e "   ${YELLOW}⚠️${NC}  Web: Puerto abierto pero sin respuesta HTTP correcta"
      ((WARNINGS++))
    fi
  fi
else
  echo -e "   ${RED}❌${NC} Puerto 5000: No escuchando"
  ((ERRORS++))
fi

echo ""
echo "5️⃣  Verificando modem EC25..."
echo ""

# Verificar puertos ttyUSB
USB_PORTS=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)
if [ "$USB_PORTS" -gt 0 ]; then
  echo -e "   ${GREEN}✅${NC} Puertos USB: $USB_PORTS puertos encontrados"
else
  echo -e "   ${YELLOW}⚠️${NC}  Puertos USB: No se encontraron puertos ttyUSB"
  ((WARNINGS++))
fi

# Verificar interfaz usb0
if ip link show usb0 &>/dev/null; then
  echo -e "   ${GREEN}✅${NC} Interface usb0: Detectada"
  
  if ip addr show usb0 | grep -q "inet "; then
    IP_USB0=$(ip addr show usb0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo -e "   ${GREEN}✅${NC} usb0 IP: $IP_USB0"
  else
    echo -e "   ${YELLOW}⚠️${NC}  usb0: Sin IP asignada"
    ((WARNINGS++))
  fi
else
  echo -e "   ${YELLOW}⚠️${NC}  Interface usb0: No detectada (¿modem conectado?)"
  ((WARNINGS++))
fi

# ModemManager check
if systemctl is-active --quiet ModemManager 2>/dev/null; then
  echo -e "   ${YELLOW}⚠️${NC}  ModemManager: Activo (puede interferir con puertos AT)"
  ((WARNINGS++))
else
  echo -e "   ${GREEN}✅${NC} ModemManager: Deshabilitado"
fi

echo ""
echo "6️⃣  Verificando Python environment..."
echo ""

VENV_PATH="/opt/ec25-router/venv"
if [ -d "$VENV_PATH" ]; then
  echo -e "   ${GREEN}✅${NC} Virtualenv: Existe"
  
  # Verificar paquetes críticos
  if "$VENV_PATH/bin/pip" list 2>/dev/null | grep -q "flask"; then
    echo -e "   ${GREEN}✅${NC} Flask: Instalado"
  else
    echo -e "   ${RED}❌${NC} Flask: No encontrado"
    ((ERRORS++))
  fi
  
  if "$VENV_PATH/bin/pip" list 2>/dev/null | grep -q "pyserial"; then
    echo -e "   ${GREEN}✅${NC} pyserial: Instalado"
  else
    echo -e "   ${RED}❌${NC} pyserial: No encontrado"
    ((ERRORS++))
  fi
  
  if "$VENV_PATH/bin/pip" list 2>/dev/null | grep -q "speedtest-cli"; then
    echo -e "   ${GREEN}✅${NC} speedtest-cli: Instalado"
  else
    echo -e "   ${YELLOW}⚠️${NC}  speedtest-cli: No encontrado"
    ((WARNINGS++))
  fi
else
  echo -e "   ${RED}❌${NC} Virtualenv: No encontrado en $VENV_PATH"
  ((ERRORS++))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✅ VERIFICACIÓN EXITOSA${NC}"
  echo "   Todos los componentes están funcionando correctamente"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠️  VERIFICACIÓN CON ADVERTENCIAS${NC}"
  echo "   El sistema funciona pero hay $WARNINGS advertencia(s)"
  echo "   Revisa los detalles arriba"
  exit 0
else
  echo -e "${RED}❌ VERIFICACIÓN FALLIDA${NC}"
  echo "   Se encontraron $ERRORS error(es) y $WARNINGS advertencia(s)"
  echo "   Revisa los logs con: sudo journalctl -u <servicio> -n 50"
  exit 1
fi
