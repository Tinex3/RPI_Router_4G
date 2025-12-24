#!/bin/bash
# Script para compactar el proyecto y enviarlo a ServerPi
# Útil cuando no hay conectividad para git pull

set -e

REMOTE_USER="server"
REMOTE_HOST="serverpi.local"
REMOTE_PASS="1234"
REMOTE_DIR="/opt/ec25-router"
PROJECT_NAME="ec25-router"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ZIP_NAME="${PROJECT_NAME}-${TIMESTAMP}.zip"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         Deploy a ServerPi (sin Git)                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Detectar directorio del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📁 Directorio del proyecto: $PROJECT_DIR"
echo "📦 Archivo a crear: $ZIP_NAME"
echo "🎯 Destino: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo ""

# Confirmar
read -p "¿Continuar con el deploy? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Deploy cancelado."
  exit 0
fi

echo ""
echo "[1/5] Compactando proyecto..."
cd "$PROJECT_DIR"

# Crear ZIP excluyendo directorios innecesarios
zip -r "/tmp/$ZIP_NAME" . \
  -x "*.git*" \
  -x "*venv/*" \
  -x "*__pycache__/*" \
  -x "*.pyc" \
  -x "*.pyo" \
  -x "*.log" \
  -x "*data/*" \
  -x "*.env" \
  -x "*.bak" \
  -x "*.tmp" \
  -x "*node_modules/*" \
  -x "*.DS_Store" \
  -q

ZIP_SIZE=$(du -h "/tmp/$ZIP_NAME" | cut -f1)
echo "   ✅ ZIP creado: $ZIP_SIZE"

echo ""
echo "[2/5] Copiando ZIP a ServerPi..."

# Usar scp con sshpass si está disponible
if command -v sshpass &> /dev/null; then
  sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no "/tmp/$ZIP_NAME" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/"
  echo "   ✅ ZIP copiado con sshpass"
else
  echo "   ℹ️  sshpass no disponible, se pedirá password manualmente"
  echo "   Password: $REMOTE_PASS"
  scp "/tmp/$ZIP_NAME" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/"
fi

echo ""
echo "[3/5] Creando backup del proyecto actual en ServerPi..."

if command -v sshpass &> /dev/null; then
  sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    if [ -d "$REMOTE_DIR" ]; then
      echo "   📦 Creando backup..."
      sudo cp -r "$REMOTE_DIR" "${REMOTE_DIR}.backup-${TIMESTAMP}"
      echo "   ✅ Backup creado: ${REMOTE_DIR}.backup-${TIMESTAMP}"
    else
      echo "   ℹ️  No hay instalación previa"
    fi
EOF
else
  echo "   ℹ️  Conéctate manualmente y ejecuta:"
  echo "   ssh ${REMOTE_USER}@${REMOTE_HOST}"
  echo "   sudo cp -r $REMOTE_DIR ${REMOTE_DIR}.backup-${TIMESTAMP}"
  read -p "   Presiona Enter cuando esté listo..."
fi

echo ""
echo "[4/5] Descomprimiendo en ServerPi..."

if command -v sshpass &> /dev/null; then
  sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    echo "   📂 Descomprimiendo ZIP..."
    cd /tmp
    unzip -o "$ZIP_NAME" -d ec25-router-new
    
    echo "   📋 Copiando archivos a $REMOTE_DIR..."
    sudo mkdir -p "$REMOTE_DIR"
    sudo cp -r ec25-router-new/* "$REMOTE_DIR/"
    sudo chown -R ${REMOTE_USER}:${REMOTE_USER} "$REMOTE_DIR"
    
    echo "   🔧 Configurando permisos de scripts..."
    sudo chmod +x "$REMOTE_DIR/scripts/"*.sh
    
    echo "   🧹 Limpiando archivos temporales..."
    rm -rf ec25-router-new "$ZIP_NAME"
    
    echo "   ✅ Archivos actualizados en $REMOTE_DIR"
EOF
else
  echo "   ℹ️  Ejecuta estos comandos en ServerPi:"
  echo ""
  echo "   cd /tmp"
  echo "   unzip -o $ZIP_NAME -d ec25-router-new"
  echo "   sudo cp -r ec25-router-new/* $REMOTE_DIR/"
  echo "   sudo chown -R ${REMOTE_USER}:${REMOTE_USER} $REMOTE_DIR"
  echo "   sudo chmod +x $REMOTE_DIR/scripts/*.sh"
  echo "   rm -rf ec25-router-new $ZIP_NAME"
  echo ""
  read -p "   Presiona Enter cuando esté listo..."
fi

echo ""
echo "[5/5] Reiniciando servicio ec25-router..."

if command -v sshpass &> /dev/null; then
  sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    echo "   🔄 Reiniciando servicio..."
    sudo systemctl restart ec25-router
    sleep 2
    
    if sudo systemctl is-active --quiet ec25-router; then
      echo "   ✅ Servicio ec25-router: RUNNING"
    else
      echo "   ❌ Servicio ec25-router: FAILED"
      echo "   Ver logs: sudo journalctl -u ec25-router -n 20"
    fi
EOF
else
  echo "   ℹ️  Ejecuta en ServerPi:"
  echo "   sudo systemctl restart ec25-router"
  read -p "   Presiona Enter cuando esté listo..."
fi

echo ""
echo "🧹 Limpiando archivo temporal local..."
rm "/tmp/$ZIP_NAME"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ DEPLOY COMPLETADO                              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Los archivos fueron actualizados en:"
echo "   $REMOTE_DIR"
echo ""
echo "📦 Backup del proyecto anterior:"
echo "   ${REMOTE_DIR}.backup-${TIMESTAMP}"
echo ""
echo "🌐 Acceso web:"
echo "   http://${REMOTE_HOST}:5000/"
echo ""
echo "📝 Ver logs:"
echo "   ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "   sudo journalctl -u ec25-router -f"
echo ""
