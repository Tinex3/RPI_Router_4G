#!/bin/bash
# Script de instalacion de Docker
# Se ejecuta separado porque usermod puede afectar la sesion

set -e

echo "========================================================================"
echo "         Instalacion de Docker                                          "
echo "========================================================================"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
  echo "[ERROR] Este script debe ejecutarse con sudo"
  echo "   Uso: sudo ./setup-docker.sh"
  exit 1
fi

# Obtener el usuario real (no root)
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER=$(logname 2>/dev/null || echo "")
fi

if [ -z "$REAL_USER" ]; then
  echo "[ERROR] No se pudo determinar el usuario real"
  exit 1
fi

echo "[INFO] Usuario detectado: $REAL_USER"

# Verificar si Docker ya esta instalado
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version 2>/dev/null || echo "desconocida")
  echo "[INFO] Docker ya esta instalado: $DOCKER_VERSION"
  
  # Verificar si el usuario ya esta en el grupo docker
  if groups "$REAL_USER" | grep -q docker; then
    echo "[OK] Usuario $REAL_USER ya esta en el grupo docker"
  else
    echo "[INFO] Agregando $REAL_USER al grupo docker..."
    usermod -aG docker "$REAL_USER"
    echo "[OK] Usuario agregado al grupo docker"
    echo ""
    echo "[IMPORTANTE] Debes cerrar sesion y volver a iniciar para que"
    echo "             los cambios de grupo surtan efecto, o ejecutar:"
    echo "             newgrp docker"
  fi
  
  # Verificar docker-compose
  if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "[OK] Docker Compose disponible"
  fi
  
  exit 0
fi

echo ""
echo "[1/5] Descargando script de instalacion de Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh

echo ""
echo "[2/5] Ejecutando instalacion de Docker..."
sh /tmp/get-docker.sh

echo ""
echo "[3/5] Agregando usuario $REAL_USER al grupo docker..."
# Crear grupo docker si no existe
groupadd -f docker
# Agregar usuario al grupo
usermod -aG docker "$REAL_USER"

echo ""
echo "[4/5] Habilitando servicio Docker..."
systemctl enable docker
systemctl start docker

echo ""
echo "[5/5] Verificando instalacion..."
docker --version
docker compose version 2>/dev/null || echo "[INFO] docker-compose plugin no disponible, usando comando docker compose"

# Limpiar
rm -f /tmp/get-docker.sh

echo ""
echo "========================================================================"
echo "              DOCKER INSTALADO CORRECTAMENTE                            "
echo "========================================================================"
echo ""
echo "[IMPORTANTE] Para usar Docker sin sudo, debes:"
echo ""
echo "   Opcion 1: Cerrar sesion y volver a iniciar"
echo ""
echo "   Opcion 2: Ejecutar en tu terminal actual:"
echo "             newgrp docker"
echo ""
echo "   Opcion 3: Reiniciar el sistema:"
echo "             sudo reboot"
echo ""
echo "Verificar con: docker run hello-world"
echo ""
