# 🚀 EC25 Router - Router 4G LTE Profesional

Router LTE profesional basado en Quectel EC25 + Raspberry Pi con WiFi Access Point.

## ✨ Features

### Core
- ✅ **WAN Auto-Failover** - Ethernet / LTE automático con prioridad configurable
- ✅ **Ethernet Dual Mode** - WAN (entrada) o LAN (salida para switch) configurable desde web
- ✅ **Panel Web** - Dashboard moderno con métricas en tiempo real
- ✅ **Autenticación** - Login seguro con Flask-Login y hash de passwords
- ✅ **Monitor LTE** - Señal (CSQ/RSRP/RSRQ/RSSI), operador, tecnología, banda, frecuencia
- ✅ **Speedtest** - Prueba de velocidad integrada en el dashboard
- ✅ **Firewall/NAT** - iptables con MASQUERADE automático
- ✅ **Watchdog** - Auto-recovery de conexión WAN/LTE
- ✅ **Logging** - Sistema rotativo, no llena el disco

### WiFi Access Point
- ✅ **WiFi AP** - Punto de acceso WiFi configurable (hostapd + dnsmasq)
- ✅ **DHCP Server** - Asignación automática de IPs (192.168.50.10-100)
- ✅ **NAT/Routing** - Comparte internet de eth0/usb0 con clientes WiFi
- ✅ **Auto-start** - Servicios persistentes con systemd

### Ethernet Modes
- 🌐 **Modo WAN** (por defecto) - Ethernet recibe internet, failover con EC25
- 🔌 **Modo LAN** - Ethernet comparte internet del EC25 a switch/router/PC
- 🔄 **Cambio desde web** - Settings → Modo Ethernet (un click)

Ver: [docs/ETHERNET-MODE.md](docs/ETHERNET-MODE.md)

### Producción
- ✅ **Systemd Services** - Arranque automático y gestión de servicios
- ✅ **Instalación Portátil** - Detecta usuario automáticamente, no hardcodea paths
- ✅ **Verificación** - Script de diagnóstico completo post-instalación

## 📋 Requisitos

- Raspberry Pi 3/4/5
- Quectel EC25 (modo ECM)
- Debian/Raspbian Bookworm
- Python 3.9+

## ⚡ Instalación Rápida

### Opción 1: Script Automático (Recomendado)

```bash
# Clonar proyecto
git clone https://github.com/Tinex3/RPI_Router_4G.git
cd RPI_Router_4G

# Hacer ejecutable el instalador
chmod +x install.sh

# Ejecutar instalador (detecta usuario automáticamente)
./install.sh

# Durante la instalación te preguntará si quieres configurar el WiFi AP
# Responde 'y' para configurar hostapd + dnsmasq automáticamente
```

**El instalador configura:**
1. Dependencias del sistema (python3-venv, iptables, jq)
2. Entorno virtual Python con todos los paquetes
3. Servicios systemd (ec25-router, wan-manager, watchdog)
4. **Opcional:** WiFi Access Point (hostapd, dnsmasq, wlan0-ap)
5. Reglas iptables persistentes (NAT/MASQUERADE)
6. Logs rotativos en `/var/log/ec25-router/`

### Opción 2: Instalación manual

```bash
# 1. Dependencias
sudo apt update
sudo apt install -y jq iptables iptables-persistent python3-venv

# 2. Copiar proyecto
sudo cp -r . /opt/ec25-router
sudo chown -R $USER:$USER /opt/ec25-router

# 3. Virtual env + dependencias
cd /opt/ec25-router
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. Crear directorio logs
sudo mkdir -p /var/log/ec25-router
sudo chown $USER:$USER /var/log/ec25-router

# 5. Scripts ejecutables
chmod +x scripts/*.sh

# 6. Editar usuario en systemd/ec25-router.service
# Cambiar "User=%USER%" por tu usuario real

# 7. Instalar servicios
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ec25-router wan-manager watchdog
```

## 🌐 Acceso

### Panel Web
```
http://RASPBERRY_IP:5000/

Usuario: admin
Password: admin1234 (¡CAMBIAR INMEDIATAMENTE!)
```

### WiFi Access Point (si configuraste)
```
SSID: RPI_Router_4G
Password: router4g2024

IP Gateway: 192.168.50.1
DHCP Range: 192.168.50.10 - 192.168.50.100
```

⚠️ **Cambiar contraseña WiFi:**
```bash
sudo nano /etc/hostapd/hostapd.conf
# Modificar línea: wpa_passphrase=TU_NUEVA_PASSWORD
sudo systemctl restart hostapd
```

## 📚 Documentación

- [WAN-MODES.md](docs/WAN-MODES.md) - Modos WAN y failover
- [ETHERNET-MODE.md](docs/ETHERNET-MODE.md) - Modo Ethernet
- [AUTO-REPAIR-GATEWAY.md](docs/AUTO-REPAIR-GATEWAY.md) - Auto-reparación

## 🔐 Cambiar password

```bash
source venv/bin/activate
python -c "from werkzeug.security import generate_password_hash; \
print(generate_password_hash('TU_PASSWORD'))"
```
### Servicios Principales
1. **ec25-router.service** - Panel web (Flask/Gunicorn, puerto 5000)
2. **wan-manager.service** - Failover automático eth0 ↔ usb0
3. **watchdog.service** - Auto-recovery de conexiones WAN/LTE

### Servicios WiFi AP (opcionales)
4. **wlan0-ap.service** - Configuración de interfaz wlan0 (IP 192.168.50.1)
5. **hostapd.service** - Daemon de Access Point WiFi
6. **dnsmasq.service** - Servidor DHCP/DNS para clientes WiFi

### Ver Logs
```bash
# Servicios principales
sudo journalctl -u ec25-router -f
sudo journalctl -u wan-manager -f
sudo journalctl -u watchdog -f

# Servicios WiFi
sudo journalctl -u hostapd -f
sudo journalctl -u dnsmasq -f
```

### Reiniciar Servicios
```bash
# Router completo
sudo systemctl restart ec25-router wan-manager watchdog

# WiFi AP completo
sudo syComandos Útiles

### Verificación del Sistema
```bash
# Ejecutar script de diagnóstico completo
sudo bash /opt/ec25-router/scripts/verify-install.sh

# Verifica: servicios, red, iptables, WiFi AP, modem, Python env
``` del Proyecto

```
RPI_Router_4G/
├── app/                      # Código Python
│   ├── __init__.py          # Inicialización Flask
│   ├── auth.py              # Autenticación Flask-Login
│   ├── firewall.py          # Gestión iptables
│   ├── modem.py             # Comandos AT al EC25 (parsers CSQ/QCSQ/etc)
│   ├── network.py           # Detección WAN (eth0/usb0)
│   ├── speedtest.py         # Prueba de velocidad (speedtest-cli)
│   └── web.py               # Rutas Flask (UI + API)
├── templates/               # HTML Jinja2
│   ├── dashboard.html       # Dashboard principal (4 cards: WAN/Signal/Modem/Speed)
│   ├── login.html           # Página de login
│   └── settings.html        # Configuración
├── static/                  # Frontend assets
│   ├── css/style.css        # Estilos dark mode profesional
│   └── js/dashboard.js      # Actualización datos en tiempo real
├── scripts/                 # Scripts de instalación/gestión
│   ├── setup-ap.sh          # Configuración WiFi AP (hostapd/dnsmasq)
│   ├── verify-install.sh    # Diagnóstico completo del sistema
│   └── ...                  # Otros scripts auxiliares
├── systemd/                 # Servicios systemd
│   ├── ec25-router.service  # Servicio web principal (Gunicorn)
│   ├── wan-manager.service  # Failover automático
│   ├── watchdog.service     # Auto-recovery
│   └── wlan0-ap.service     # Configuración wlan0 (antes de hostapd)
├── config/                  # Archivos de configuración
│   ├── hostapd.conf         # Config WiFi AP (SSID, password, canal)
│   └── dnsmasq.conf         # Config DHCP/DNS para WiFi
├── data/
│   └── config.json          # Configuración del router (APN, WAN mode, etc)
├── install.sh               # Instalador automático principal
├── requirements.txt         # Dependencias Python
├── run.py                   # Entrypoint Flask
└── README.md               # Este archivo
```basFeatures Implementados

- [x] **Panel básico** - Dashboard con métricas LTE
- [x] **WAN failover** - Cambio automático eth0 ↔ usb0
- [x] **Control web** - Configuración desde UI
- [x] **Producción** - Auth, firewall, watchdog, systemd
- [x] **Parseo AT** - Respuestas legibles (señal, operador, red)
- [x] **UI/UX mejorado** - 4 cards, badges de estado, medidores visuales
- [x] **Speedtest** - Prueba de velocidad integrada
- [x] **WiFi Access Point** - hostapd + dnsmasq automático
- [x] **NAT persistente** - iptables con MASQUERADE para eth0/usb0/wlan0
- [x] **Instalación portátil** - No hardcodea usuarios ni paths
- [x] **Diagnóstico** - Script verify-install.sh completo

## 🚧 Roadmap Futuro

- [ ] Estadísticas históricas (gráficos de señal/consumo)
- [ ] Alertas (email/telegram cuando cae conexión)
- [ ] API REST completa (control remoto)
- [ ] Config WiFi desde UI (cambiar SSID/password sin SSH)
- [ ] SMS Gateway (enviar/recibir SMS desde EC25)
- [ ] VPN Server (OpenVPN/WireGuard)
- [ ] QoS (priorización de tráfico)
# Verificar DHCP leases
cat /var/lib/misc/dnsmasq.leases
```

### Network
```bash
# Ver interfaces y IPs
ip addr show

# Ver rutas
ip route show

# Ver reglas iptables NAT
sudo iptables -t nat -L POSTROUTING -n -v

# Ver reglas FORWARD
sudo iptables -L FORWARD -n -v
```

### Desarrollo
```bash
# Modo desarrollo (sin Gunicorn)
cd /opt/ec25-router
source venv/bin/activate
python run.py

# Acceder en: http://localhost:5000a automáticamente NAT y forwarding.

## 📊 Servicios

1. **ec25-router** - Panel web (Flask/Gunicorn)
2. **wan-manager** - Failover automático eth0/usb0
3. **watchdog** - Auto-recovery WAN/LTE

Ver logs:
```bash
sudo journalctl -u ec25-router -f
sudo journalctl -u wan-manager -f
sudo journalctl -u watchdog -f
```

## 🛠️ Desarrollo

```bash
# Modo desarrollo (sin Gunicorn)
source venv/bin/activate
python run.py
```

## 📁 Estructura

```
├── app/                  # Código Python
│   ├── auth.py          # Autenticación
│   ├── firewall.py      # iptables
│   ├── modem.py         # Comandos AT
│   ├── network.py       # WAN detection
│   └── web.py           # Rutas Flask
├── templates/           # HTML Jinja2
├── static/              # CSS + JS
├── scripts/             # Bash scripts
├── systemd/             # Services
├── data/config.json     # Configuración
└── run.py              # Entrypoint
```

## 🎯 Roadmap

- [x] Etapa 1: Panel básico
- [x] Etapa 2: WAN failover
- [x] Etapa 3: Control web
- [x] Etapa 4: Producción (auth, firewall, watchdog)
- [ ] Etapa 5: Estadísticas
- [ ] Etapa 6: Alertas
- [ ] Etapa 7: API REST
- [ ] Etapa 8: Config WiFi

## 📄 Licencia

MIT
