#!/bin/bash
# Script de instalación automática para EC25 Router
# Detecta usuario actual y configura servicios

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         EC25 Router - Instalación Automática                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Detectar usuario actual (no root)
if [ "$EUID" -eq 0 ]; then
  echo "⚠️  No ejecutes este script como root."
  echo "   Usa: ./install.sh"
  echo "   El script pedirá sudo cuando sea necesario."
  exit 1
fi

CURRENT_USER=$(whoami)
INSTALL_DIR="/opt/ec25-router"
LOG_DIR="/var/log/ec25-router"

echo "📋 Configuración detectada:"
echo "   Usuario: $CURRENT_USER"
echo "   Directorio: $INSTALL_DIR"
echo "   Logs: $LOG_DIR"
echo ""

# Confirmar instalación
read -p "¿Continuar con la instalación? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Instalación cancelada."
  exit 0
fi

echo ""
echo "1️⃣  Instalando dependencias del sistema..."
sudo apt update
sudo apt install -y jq iptables iptables-persistent python3-venv python3-pip hostapd dnsmasq

# Detener servicios recien instalados (se configuraran despues)
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

echo ""
echo "2️⃣  Copiando proyecto a $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r . "$INSTALL_DIR/"
sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"

echo ""
echo "3️⃣  Creando entorno virtual Python..."
cd "$INSTALL_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "4️⃣  Creando directorio de logs..."
sudo mkdir -p "$LOG_DIR"
sudo chown "$CURRENT_USER:$CURRENT_USER" "$LOG_DIR"

echo ""
echo "5️⃣  Configurando permisos de scripts..."
chmod +x scripts/*.sh

echo ""
echo "6️⃣  Configurando servicios systemd..."

# Crear archivo temporal con el usuario correcto
for service in wan-manager watchdog ec25-router; do
  SERVICE_FILE="$INSTALL_DIR/systemd/${service}.service"
  TEMP_FILE="/tmp/${service}.service.tmp"
  
  # Reemplazar placeholder de usuario si existe
  if [ -f "$SERVICE_FILE" ]; then
    # Para wan-manager y watchdog: ejecutar como root
    if [ "$service" = "wan-manager" ] || [ "$service" = "watchdog" ]; then
      sed "s/User=.*/User=root/" "$SERVICE_FILE" > "$TEMP_FILE"
    else
      # Para ec25-router: reemplazar TODOS los placeholders posibles
      sed "s/User=%USER%/User=$CURRENT_USER/" "$SERVICE_FILE" > "$TEMP_FILE"
      sed -i "s/User=benjamin/User=$CURRENT_USER/" "$TEMP_FILE"
      sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|" "$TEMP_FILE"
      sed -i "s|Environment=\"PATH=/opt/ec25-router/venv/bin.*\"|Environment=\"PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"|" "$TEMP_FILE"
      sed -i "s|ExecStart=/opt/ec25-router.*|ExecStart=$INSTALL_DIR/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 run:app|" "$TEMP_FILE"
    fi
    
    sudo cp "$TEMP_FILE" "/etc/systemd/system/${service}.service"
    rm "$TEMP_FILE"
    echo "   ✅ ${service}.service configurado"
  fi
done

echo ""
echo "7️⃣  Recargando systemd..."
sudo systemctl daemon-reload

echo ""
echo "8️⃣  Habilitando e iniciando servicios..."
sudo systemctl enable wan-manager
sudo systemctl enable watchdog
sudo systemctl enable ec25-router

echo ""
echo "9️⃣  Iniciando servicios..."
sudo systemctl start wan-manager
sleep 2
sudo systemctl start watchdog
sleep 2
sudo systemctl start ec25-router

echo ""
echo "🔍 Verificando estado de servicios..."
echo ""
for service in wan-manager watchdog ec25-router; do
  if sudo systemctl is-active --quiet "$service"; then
    echo "   ✅ $service: RUNNING"
  else
    echo "   ❌ $service: FAILED"
    echo "      Ver logs: sudo journalctl -u $service -n 20"
  fi
done

echo ""
echo "🔟 Configurando WiFi Access Point..."
echo ""
read -p "¿Deseas configurar el Access Point WiFi ahora? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if [ -f "$INSTALL_DIR/scripts/setup-ap.sh" ]; then
    sudo bash "$INSTALL_DIR/scripts/setup-ap.sh"
  else
    echo "   ⚠️  Script setup-ap.sh no encontrado, puedes ejecutarlo manualmente después:"
    echo "      sudo bash $INSTALL_DIR/scripts/setup-ap.sh"
  fi
else
  echo "   ℹ️  Puedes configurar el WiFi AP más tarde con:"
  echo "      sudo bash $INSTALL_DIR/scripts/setup-ap.sh"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ INSTALACIÓN COMPLETADA                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Acceso web:"
echo "   URL: http://$(hostname -I | awk '{print $1}'):5000/"
echo "   Usuario: admin"
echo "   Password: admin1234 (¡CAMBIAR!)"
echo ""
echo "📝 Ver logs:"
echo "   sudo journalctl -u ec25-router -f"
echo "   tail -f $LOG_DIR/app.log"
echo ""
echo "🔐 Cambiar password:"
echo "   cd $INSTALL_DIR"
echo "   source venv/bin/activate"
echo "   python -c \"from werkzeug.security import generate_password_hash; print(generate_password_hash('TU_PASSWORD'))\""
echo "   # Copiar hash a data/config.json → auth.password_hash"
echo "   sudo systemctl restart ec25-router"
echo ""
echo "📚 Documentación: $INSTALL_DIR/ETAPA4.md"
echo ""
