# Configuración de Hardware Post-Docker

## ⚠️ Importante: Reinicio Necesario

Después de instalar Docker con `setup-docker.sh`, el script realiza configuraciones de hardware que **requieren reiniciar el sistema**.

## 🔧 Cambios Realizados

### 1. Activación de SPI

Se agrega en `/boot/firmware/config.txt`:
```
dtparam=spi=on
```

**¿Por qué?**
- Necesario para comunicación con módulos LoRaWAN (SX1301, SX1302, etc.)
- Habilita el bus SPI del Raspberry Pi
- Sin esto, el gateway LoRaWAN no puede detectar el hardware

### 2. Desactivación de Bluetooth

Se agrega en `/boot/firmware/config.txt`:
```
dtoverlay=disable-bt
```

**¿Por qué?**
- Libera UART (serial) que puede usar LoRaWAN
- Libera recursos de memoria y CPU
- Evita conflictos de hardware con módulos LoRaWAN
- El Bluetooth no es necesario para el router

### 3. Servicios Bluetooth Detenidos

```bash
systemctl disable hciuart.service
systemctl stop hciuart.service
systemctl disable bluetooth.service
systemctl stop bluetooth.service
```

**¿Por qué?**
- Asegura que los servicios Bluetooth no consuman recursos
- Libera inmediatamente el UART (no espera al reinicio)

## 🚀 Flujo de Instalación

### Si instalas Docker manualmente:

```bash
# 1. Instalar Docker
sudo bash /opt/ec25-router/scripts/setup-docker.sh

# 2. ¡Verás este mensaje al final!
╔════════════════════════════════════════════════════════════════════╗
║              🔄 REINICIO NECESARIO                                ║
╚════════════════════════════════════════════════════════════════════╝

   Se han realizado cambios en /boot/firmware/config.txt:
   ✅ SPI activado (necesario para LoRaWAN)
   ✅ Bluetooth desactivado (libera recursos)

   🔄 DEBES REINICIAR EL SISTEMA para que los cambios surtan efecto:

   sudo reboot

# 3. Reiniciar
sudo reboot

# 4. Después del reinicio, verificar:
ls /dev/spidev*  # Debe mostrar /dev/spidev0.0, /dev/spidev0.1
```

### Si usas install.sh:

El instalador detecta si Docker está instalado y muestra el mensaje de reinicio necesario al final:

```bash
./install.sh

# ... instalación ...

# Si Docker está instalado, verás:
╔════════════════════════════════════════════════════════════════════╗
║              🔄 REINICIO NECESARIO                                ║
╚════════════════════════════════════════════════════════════════════╝

   ⚠️  Se realizaron cambios en /boot/firmware/config.txt
   (SPI activado + Bluetooth desactivado para LoRaWAN)

   🔄 DEBES REINICIAR el sistema para que los cambios surtan efecto:

   sudo reboot
```

## 🔍 Verificación

### Antes del reinicio:

```bash
# Ver cambios en config.txt
cat /boot/firmware/config.txt | grep -E "spi=on|disable-bt"

# Deberías ver:
# dtparam=spi=on
# dtoverlay=disable-bt
```

### Después del reinicio:

```bash
# Verificar SPI habilitado
ls -l /dev/spidev*
# Salida esperada:
# crw-rw---- 1 root spi 153, 0 Dec 24 10:00 /dev/spidev0.0
# crw-rw---- 1 root spi 153, 1 Dec 24 10:00 /dev/spidev0.1

# Verificar Bluetooth deshabilitado
systemctl status bluetooth
# Salida: Unit bluetooth.service could not be found.

# Verificar hciuart
systemctl status hciuart
# Salida: Unit hciuart.service could not be found.

# Verificar dispositivo Bluetooth NO existe
hciconfig
# Salida: Can't get device info: No such device
```

## 📋 Troubleshooting

### SPI no aparece después del reinicio

```bash
# Verificar config.txt
sudo nano /boot/firmware/config.txt

# Asegurarse que existe:
dtparam=spi=on

# Sin comentarios (#) al inicio
# Guardar y reiniciar nuevamente
```

### Bluetooth sigue activo

```bash
# Verificar config.txt
sudo nano /boot/firmware/config.txt

# Asegurarse que existe:
dtoverlay=disable-bt

# Sin comentarios (#) al inicio
# Detener servicios manualmente:
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth
sudo systemctl disable hciuart
sudo systemctl stop hciuart

# Reiniciar
sudo reboot
```

### ¿Por qué necesito reiniciar?

Los cambios en `/boot/firmware/config.txt` son configuraciones de **boot firmware**. Se cargan cuando el sistema arranca, no se pueden aplicar en tiempo de ejecución.

**Analogía:** Es como cambiar la configuración de BIOS/UEFI en una PC. Los cambios solo aplican después de reiniciar.

## 📚 Archivos Relacionados

- `/boot/firmware/config.txt` - Configuración de hardware del boot
- `scripts/setup-docker.sh` - Script de instalación de Docker + hardware
- `install.sh` - Instalador principal (detecta y avisa reinicio)

## ✅ Checklist Post-Instalación

Después de instalar Docker y reiniciar:

- [ ] `/dev/spidev*` existe
- [ ] `systemctl status bluetooth` → not found
- [ ] `systemctl status hciuart` → not found
- [ ] Docker funciona: `docker run hello-world`
- [ ] Usuario en grupo docker: `groups | grep docker`

Si todo está ✅, el sistema está listo para LoRaWAN!
