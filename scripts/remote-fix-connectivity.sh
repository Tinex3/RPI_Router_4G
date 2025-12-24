#!/bin/bash
# Script para ejecutar fix de conectividad en ServerPi de forma remota
# Se ejecuta desde tu PC local

REMOTE_USER="server"
REMOTE_HOST="serverpi.local"
REMOTE_PASS="1234"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Fix Remoto: Restaurar conectividad en ServerPi             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

echo "🎯 Conectando a ${REMOTE_USER}@${REMOTE_HOST}..."
echo ""

# Verificar si sshpass está disponible
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  sshpass no está instalado. Instalando..."
    sudo apt install -y sshpass
fi

# Ejecutar fix remotamente
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" 'bash -s' << 'ENDSSH'

echo "========================================================================"
echo "         Fix: Restaurar conectividad Ethernet en ServerPi              "
echo "========================================================================"
echo ""

echo "[1/5] Diagnosticando conectividad..."
echo ""

# Probar ping
echo "   Probando ping a 8.8.8.8..."
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Ping: OK"
  IP_OK=true
else
  echo "   ❌ Ping: FALLA"
  IP_OK=false
fi

# Probar DNS
echo "   Probando nslookup github.com..."
if nslookup github.com &>/dev/null; then
  echo "   ✅ DNS: OK"
  DNS_OK=true
else
  echo "   ❌ DNS: FALLA"
  DNS_OK=false
fi

echo ""
if [ "$IP_OK" = true ] && [ "$DNS_OK" = true ]; then
  echo "✅ La conectividad está funcionando."
  echo ""
  echo "Si git pull sigue fallando, verifica el DNS:"
  cat /etc/resolv.conf
  exit 0
fi

echo "[2/5] Diagnóstico de red..."
echo ""
echo "=== Interfaces de red ==="
ip -br addr | grep -E "eth0|usb0|wlan0"
echo ""
echo "=== Rutas ==="
ip route | head -5
echo ""
echo "=== DNS actual ==="
cat /etc/resolv.conf
echo ""

echo "[3/5] Mostrando reglas iptables NAT..."
echo ""
sudo iptables -t nat -L POSTROUTING -n | head -15
echo ""

echo "[4/5] Corrigiendo problemas..."
echo ""

# Backup de iptables
sudo iptables-save > /tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules
echo "   💾 Backup iptables guardado"

# Eliminar reglas MASQUERADE genéricas problemáticas
echo "   🧹 Limpiando reglas MASQUERADE genéricas..."
sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica eth0 eliminada" || \
  echo "      ℹ️  No había regla genérica en eth0"

sudo iptables -t nat -D POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null && \
  echo "      ✅ Regla genérica usb0 eliminada" || \
  echo "      ℹ️  No había regla genérica en usb0"

# Agregar reglas correctas (solo para WiFi)
echo "   ✅ Configurando NAT solo para red WiFi (192.168.50.0/24)..."
sudo iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o eth0 -j MASQUERADE

sudo iptables -t nat -C POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE 2>/dev/null || \
  sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o usb0 -j MASQUERADE

# Guardar reglas
sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || sudo iptables-save > /etc/iptables.rules
echo "   💾 Reglas iptables guardadas"

# Fix DNS
if [ "$DNS_OK" = false ]; then
  echo ""
  echo "   🔧 Corrigiendo DNS..."
  
  # Verificar si usa systemd-resolved
  if systemctl is-active --quiet systemd-resolved; then
    echo "      ℹ️  Sistema usa systemd-resolved"
    
    # Configurar DNS en systemd-resolved
    sudo mkdir -p /etc/systemd/resolved.conf.d
    cat << 'EOF' | sudo tee /etc/systemd/resolved.conf.d/dns.conf > /dev/null
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=1.0.0.1
EOF
    
    sudo systemctl restart systemd-resolved
    echo "      ✅ DNS configurado en systemd-resolved"
  else
    # Modificar /etc/resolv.conf directamente
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "      ✅ DNS públicos agregados a /etc/resolv.conf"
  fi
fi

echo ""
echo "[5/5] Verificando conectividad después del fix..."
echo ""

sleep 2

if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
  echo "   ✅ Ping a 8.8.8.8: OK"
else
  echo "   ❌ Ping a 8.8.8.8: FALLA"
fi

if nslookup github.com &>/dev/null; then
  echo "   ✅ DNS (github.com): OK"
else
  echo "   ❌ DNS (github.com): FALLA"
fi

if curl -s --max-time 5 https://github.com > /dev/null; then
  echo "   ✅ HTTPS a github.com: OK"
else
  echo "   ⚠️  HTTPS a github.com: FALLA"
fi

echo ""
echo "========================================================================"
echo "                        FIX COMPLETADO                                  "
echo "========================================================================"
echo ""
echo "📋 Reglas NAT actuales (solo WiFi):"
sudo iptables -t nat -L POSTROUTING -v -n | grep "192.168.50" || echo "   (ninguna encontrada)"
echo ""
echo "🌐 Ahora prueba: git pull"
echo ""

ENDSSH

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ PROCESO COMPLETADO                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "💡 Ahora conéctate a ServerPi y prueba:"
echo "   ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "   cd /opt/ec25-router"
echo "   git pull"
echo ""
