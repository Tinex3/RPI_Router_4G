# EC25 Router Panel

Router LTE profesional basado en Quectel EC25 + Raspberry Pi.

## 🚀 Features

- ✅ **WAN Auto-Failover** - Ethernet / LTE automático
- ✅ **Panel Web** - Dashboard local con Flask + Gunicorn
- ✅ **Autenticación** - Login seguro con Flask-Login
- ✅ **Monitor LTE** - Señal, operador, tecnología, banda
- ✅ **Config Web** - APN, WAN mode, firewall
- ✅ **Firewall/NAT** - iptables configurable, aislamiento WiFi
- ✅ **Watchdog** - Auto-recovery WAN/LTE
- ✅ **Logging** - Rotativo, no llena disco
- ✅ **Producción** - systemd, arranque automático

## 📋 Requisitos

- Raspberry Pi 3/4/5
- Quectel EC25 (modo ECM)
- Debian/Raspbian Bookworm
- Python 3.9+

## ⚡ Instalación rápida

### Opción 1: Script automático (recomendado)

```bash
# Clonar/copiar proyecto
cd /home/tu_usuario
git clone <repo> ec25-router
cd ec25-router

# Ejecutar instalador (detecta usuario automáticamente)
./install.sh
```

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

```
http://RASPBERRY_IP:5000/

Login: admin
Password: admin1234 (¡cámbiala!)
```

## 📚 Documentación

- [ETAPA4.md](ETAPA4.md) - **Guía completa de instalación** (⭐ EMPEZAR AQUÍ)
- [ETAPA3.md](ETAPA3.md) - Router administrable
- [ETAPA2.md](ETAPA2.md) - WAN failover (deprecado)

## 🔐 Cambiar password

```bash
source venv/bin/activate
python -c "from werkzeug.security import generate_password_hash; \
print(generate_password_hash('TU_PASSWORD'))"
```

Copiar hash en `data/config.json` → `auth.password_hash`

```bash
sudo systemctl restart ec25-router
```

## 🔥 Firewall

Desde Settings en la web:
- Marcar "Aislar clientes Wi-Fi"
- Click "Aplicar"

Esto configura automáticamente NAT y forwarding.

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
