#!/bin/bash
# Script de actualización para sistemas ya instalados
# Actualiza archivos desde el repositorio sin reinstalar todo

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         EC25 Router - Actualización desde Repositorio             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Detectar si estamos en el directorio correcto
if [ ! -f "install.sh" ]; then
  echo "❌ Error: Debes ejecutar este script desde el directorio del repositorio"
  echo "   cd ~/Documentos/Github/Personal/SistemaWIFI"
  echo "   ./update.sh"
  exit 1
fi

INSTALL_DIR="/opt/ec25-router"

# Verificar que el sistema esté instalado
if [ ! -d "$INSTALL_DIR" ]; then
  echo "❌ Error: EC25 Router no está instalado en $INSTALL_DIR"
  echo "   Ejecuta primero: ./install.sh"
  exit 1
fi

echo "📋 Información:"
echo "   Repositorio: $(pwd)"
echo "   Instalación: $INSTALL_DIR"
echo ""

read -p "¿Actualizar archivos desde el repositorio? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Actualización cancelada."
  exit 0
fi

echo ""
echo "1️⃣  Actualizando scripts de gestión..."
sudo cp -v scripts/*.sh "$INSTALL_DIR/scripts/"
sudo chmod +x "$INSTALL_DIR/scripts/"*.sh
echo "   ✅ Scripts actualizados"

echo ""
echo "2️⃣  Actualizando archivos de configuración base..."
sudo cp -v install.sh "$INSTALL_DIR/"
sudo cp -v README.md "$INSTALL_DIR/"
echo "   ✅ Archivos base actualizados"

echo ""
echo "3️⃣  Verificando archivos de configuración WiFi AP..."
if [ -f "config/hostapd.conf" ] && [ -f "config/dnsmasq.conf" ]; then
  read -p "¿Actualizar configuración WiFi AP? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo cp -v config/hostapd.conf /etc/hostapd/hostapd.conf
    sudo cp -v config/dnsmasq.conf /etc/dnsmasq.conf
    echo "   ✅ Configuración WiFi actualizada"
    echo "   ⚠️  Recuerda personalizar SSID y password en /etc/hostapd/hostapd.conf"
  else
    echo "   ⏭️  Configuración WiFi no modificada"
  fi
else
  echo "   ℹ️  No hay cambios en configuración WiFi"
fi

echo ""
echo "4️⃣  Verificando servicios systemd..."
SERVICES_CHANGED=0
for service in wan-manager watchdog ec25-router wlan0-ap; do
  if [ -f "systemd/${service}.service" ]; then
    if ! sudo cmp -s "systemd/${service}.service" "/etc/systemd/system/${service}.service" 2>/dev/null; then
      echo "   ⚠️  ${service}.service ha cambiado"
      SERVICES_CHANGED=1
    fi
  fi
done

if [ $SERVICES_CHANGED -eq 1 ]; then
  read -p "¿Actualizar servicios systemd? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Detectar usuario actual
    CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    
    for service in wan-manager watchdog ec25-router wlan0-ap; do
      if [ -f "systemd/${service}.service" ]; then
        TEMP_FILE="/tmp/${service}.service.tmp"
        
        # Reemplazar placeholders
        if [ "$service" = "ec25-router" ]; then
          sed "s/User=%USER%/User=$CURRENT_USER/" "systemd/${service}.service" > "$TEMP_FILE"
          sed -i "s/User=benjamin/User=$CURRENT_USER/" "$TEMP_FILE"
          sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|" "$TEMP_FILE"
          sed -i "s|Environment=\"PATH=/opt/ec25-router/venv/bin.*\"|Environment=\"PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"|" "$TEMP_FILE"
          sed -i "s|ExecStart=/opt/ec25-router.*|ExecStart=$INSTALL_DIR/venv/bin/gunicorn -w 2 --timeout 60 -b 0.0.0.0:5000 run:app|" "$TEMP_FILE"
        else
          cp "systemd/${service}.service" "$TEMP_FILE"
        fi
        
        sudo cp "$TEMP_FILE" "/etc/systemd/system/${service}.service"
        rm "$TEMP_FILE"
        echo "   ✅ ${service}.service actualizado"
      fi
    done
    
    sudo systemctl daemon-reload
    echo "   ✅ systemd recargado"
    
    read -p "¿Reiniciar servicios ahora? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "   🔄 Reiniciando servicios..."
      sudo systemctl restart wan-manager watchdog ec25-router
      echo "   ✅ Servicios reiniciados"
    else
      echo "   ℹ️  Recuerda reiniciar servicios manualmente:"
      echo "      sudo systemctl restart wan-manager watchdog ec25-router"
    fi
  fi
else
  echo "   ✅ Servicios systemd sin cambios"
fi

echo ""
echo "5️⃣  Actualizando código Python..."
sudo cp -rv app "$INSTALL_DIR/"
sudo cp -rv templates "$INSTALL_DIR/"
sudo cp -rv static "$INSTALL_DIR/"
sudo cp -v run.py "$INSTALL_DIR/"

# Verificar si hay cambios en requirements.txt
if [ -f "requirements.txt" ]; then
  if ! sudo cmp -s "requirements.txt" "$INSTALL_DIR/requirements.txt" 2>/dev/null; then
    echo ""
    echo "   ⚠️  requirements.txt ha cambiado"
    read -p "   ¿Actualizar dependencias Python? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudo cp requirements.txt "$INSTALL_DIR/"
      cd "$INSTALL_DIR"
      sudo -u $CURRENT_USER bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
      cd - > /dev/null
      echo "   ✅ Dependencias Python actualizadas"
      
      read -p "   ¿Reiniciar ec25-router para aplicar cambios? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl restart ec25-router
        echo "   ✅ ec25-router reiniciado"
      fi
    fi
  else
    echo "   ✅ requirements.txt sin cambios"
  fi
fi

# Ajustar permisos
CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)
if [ -n "$CURRENT_USER" ]; then
  sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"
fi

echo ""
echo "6️⃣  Ejecutando verificación del sistema..."
echo ""
sudo bash "$INSTALL_DIR/scripts/verify-install.sh"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ ACTUALIZACIÓN COMPLETADA                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Comandos útiles:"
echo "   Ver logs web:      sudo journalctl -u ec25-router -f"
echo "   Ver logs WiFi:     sudo journalctl -u hostapd -f"
echo "   Verificar sistema: sudo bash $INSTALL_DIR/scripts/verify-install.sh"
echo "   Acceso web:        http://$(hostname -I | awk '{print $1}'):5000/"
echo ""
