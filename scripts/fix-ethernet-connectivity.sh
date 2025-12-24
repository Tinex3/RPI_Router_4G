#!/bin/bash
# Script para corregir problemas de conectividad Ethernet
# causados por reglas iptables incorrectas del AP WiFi

set -e

echo "========================================================================"
echo "         Fix: Restaurar conectividad Ethernet                          "
echo "========================================================================"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "[ERROR] Este script debe ejecutarse con sudo"
  exit 1
fi

echo "[1/4] Diagnosticando conectividad..."
echo ""

# Probar conectividad por IP
echo "   Probando ping a 8.8.8.8 (Google DNS)..."
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Conectividad por IP: OK"
  IP_OK=true
else
  echo "   ❌ Conectividad por IP: FALLA"
  IP_OK=false
fi

# Probar resolución DNS
echo "   Probando resolución DNS (github.com)..."
if nslookup github.com &>/dev/null; then
  echo "   ✅ Resolución DNS: OK"
  DNS_OK=true
else
  echo "   ❌ Resolución DNS: FALLA"
  DNS_OK=false
fi

echo ""
if [ "$IP_OK" = true ] && [ "$DNS_OK" = true ]; then
  echo "✅ La conectividad está funcionando correctamente."
  echo "   No es necesario aplicar ningún fix."
  exit 0
fi

echo "[2/6] Verificando rutas de red..."
echo ""
echo "=== Rutas actuales ==="
ip route show
echo ""

# Detectar ruta duplicada sin gateway
DUPLICATE_ROUTE=$(ip route show | grep "^default dev eth0 scope link" || true)
if [ -n "$DUPLICATE_ROUTE" ]; then
  echo "   ⚠️  PROBLEMA DETECTADO: Ruta por defecto duplicada sin gateway"
  echo "   Ruta problemática: $DUPLICATE_ROUTE"
  echo ""
  echo "[3/6] Eliminando ruta duplicada..."
  ip route del default dev eth0 scope link 2>/dev/null && \
    echo "   ✅ Ruta duplicada eliminada" || \
    echo "   ⚠️  No se pudo eliminar la ruta"
  
  # Configurar NetworkManager para evitar que vuelva a crear la ruta
  if command -v nmcli &> /dev/null; then
    echo ""
    echo "   🔧 Configurando NetworkManager..."
    CONN_NAME=$(nmcli -t -f NAME connection show --active | grep -E "eth|Wired" | head -1)
    if [ -n "$CONN_NAME" ]; then
      nmcli connection modify "$CONN_NAME" ipv4.never-default no 2>/dev/null || true
      nmcli connection modify "$CONN_NAME" ipv6.method disabled 2>/dev/null || true
      echo "   ✅ NetworkManager configurado para '$CONN_NAME'"
    fi
  fi
else
  echo "   ✅ No se detectaron rutas duplicadas"
fi

echo ""
echo "[4/6] Mostrando reglas iptables actuales..."
echo ""
echo "=== Tabla NAT (POSTROUTING) ==="
iptables -t nat -L POSTROUTING -v -n | head -20
echo ""

echo "[5/6] Limpiando reglas iptables problemáticas..."
echo ""

# Hacer backup de reglas actuales
iptables-save > /tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules
echo "   💾 Backup guardado en /tmp/iptables-backup-*.rules"

# Limpiar reglas NAT genéricas que afectan todo el tráfico
echo "   🧹 Eliminando reglas MASQUERADE genéricas en eth0..."
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica eth0 eliminada" || \
  echo "      ℹ️  No había regla genérica en eth0"

iptables -t nat -D POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica usb0 eliminada" || \
  echo "      ℹ️  No había regla genérica en usb0"

echo ""
echo "[6/6] Aplicando reglas correctas (solo para WiFi)..."
echo ""

# Asegurar que existan las reglas correctas (solo para red WiFi)
iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE
echo "   ✅ NAT para WiFi → eth0 configurado"

iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE
echo "   ✅ NAT para WiFi → usb0 configurado"

# Guardar reglas corregidas
iptables-save > /etc/iptables.rules
echo "   💾 Reglas corregidas guardadas"

# Si existe netfilter-persistent, guardar allí también
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
  echo "   💾 Reglas guardadas con netfilter-persistent"
fi

echo ""
echo "========================================================================"
echo "         Verificando conectividad después del fix                      "
echo "========================================================================"
echo ""

# Dar tiempo a que se apliquen cambios
sleep 2

# Verificar DNS
if [ "$DNS_OK" = false ]; then
  echo "   🔧 Corrigiendo DNS..."
  
  # Agregar DNS públicos
  echo "nameserver 8.8.8.8" > /tmp/resolv.conf.new
  echo "nameserver 8.8.4.4" >> /tmp/resolv.conf.new
  echo "nameserver 1.1.1.1" >> /tmp/resolv.conf.new
  
  # Preservar DNS existente si no es el problemático
  if [ -f /etc/resolv.conf ]; then
    grep "^nameserver" /etc/resolv.conf | grep -v "192.168.225.1" >> /tmp/resolv.conf.new || true
  fi
  
  cp /tmp/resolv.conf.new /etc/resolv.conf
  echo "   ✅ DNS públicos agregados (8.8.8.8, 8.8.4.4, 1.1.1.1)"
fi

# Probar conectividad nuevamente
echo ""
echo "   Probando conectividad..."
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Conectividad por IP: RESTAURADA"
else
  echo "   ❌ Conectividad por IP: AÚN FALLA"
  echo ""
  echo "   Diagnóstico adicional necesario:"
  echo "     - Verificar cable Ethernet conectado"
  echo "     - Verificar DHCP: sudo dhclient eth0"
  echo "     - Verificar rutas: ip route"
  echo "     - Ver interfaces: ip addr"
fi

if nslookup github.com &>/dev/null; then
  echo "   ✅ Resolución DNS: RESTAURADA"
else
  echo "   ⚠️  Resolución DNS: Revisar /etc/resolv.conf"
fi

echo ""
echo "========================================================================"
echo "                        FIX COMPLETADO                                  "
echo "========================================================================"
echo ""
echo "📋 Reglas NAT actuales (solo WiFi):"
iptables -t nat -L POSTROUTING -v -n | grep "192.168.50"
echo ""
echo "✅ Ahora el ServerPi debería tener conectividad Ethernet normal"
echo "✅ Los clientes WiFi seguirán funcionando correctamente"
echo ""
