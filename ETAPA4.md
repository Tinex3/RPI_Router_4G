# ETAPA 4 - Router Panel en Producción

## 🎯 Objetivo
Sistema completo y robusto listo para producción con autenticación, logging, firewall configurable y watchdog.

## 📋 Características implementadas

✅ **Login/Auth** - Flask-Login con password hash seguro
✅ **Gunicorn + systemd** - Servidor WSGI profesional, arranque automático
✅ **Logs rotativos** - No llena el disco (1MB máx, 5 backups)
✅ **Firewall/NAT** - iptables configurable desde web
✅ **Aislamiento Wi-Fi** - Opcional: clientes no se ven entre ellos
✅ **Watchdog** - Auto-recovery de WAN/LTE
✅ **UI mejorada** - Dashboard oscuro, profesional

## 🚀 INSTALACIÓN EN RASPBERRY PI

### Opción 1: Script automático (⭐ RECOMENDADO)

El script detecta automáticamente tu usuario y configura todo:

```bash
cd /home/tu_usuario
# Copiar/clonar el proyecto aquí
cd SistemaWIFI  # o como se llame tu carpeta

# Ejecutar instalador
./install.sh
```

El script hará automáticamente:
- ✅ Detectar tu usuario actual
- ✅ Instalar dependencias (jq, iptables, python3-venv)
- ✅ Copiar proyecto a /opt/ec25-router
- ✅ Crear venv e instalar requirements
- ✅ Configurar servicios con el usuario correcto
- ✅ Habilitar e iniciar servicios
- ✅ Verificar que todo funciona

### Opción 2: Instalación manual

Si prefieres hacerlo paso a paso:
```bash
sudo apt update
sudo apt install -y jq iptables iptables-persistent python3-venv
```

### 2. Instalar proyecto
```bash
# Si no existe, clonar/copiar a /opt
sudo mkdir -p /opt
sudo cp -r /home/benjamin/Documentos/Github/Personal/SistemaWIFI /opt/ec25-router
sudo chown -R benjamin:benjamin /opt/ec25-router
```

### 3. Crear entorno virtual e instalar dependencias
```bash
cd /opt/ec25-router
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 4. Crear directorio de logs
```bash
sudo mkdir -p /var/log/ec25-router
sudo chown benjamin:benjamin /var/log/ec25-router
```

### 5. Hacer scripts ejecutables
```bash
chmod +x scripts/wan-manager.sh
chmod +x scripts/watchdog.sh
chmod +x scripts/ecm-start.sh
```

### 6. Instalar servicios systemd
```bash
# Enlazar servicios
sudo ln -sf /opt/ec25-router/systemd/ec25-router.service /etc/systemd/system/
sudo ln -sf /opt/ec25-router/systemd/wan-manager.service /etc/systemd/system/
sudo ln -sf /opt/ec25-router/systemd/watchdog.service /etc/systemd/system/

# Recargar daemon
sudo systemctl daemon-reload

# Habilitar e iniciar servicios
sudo systemctl enable --now ec25-router
sudo systemctl enable --now wan-manager
sudo systemctl enable --now watchdog
```

### 7. Verificar que todo está funcionando
```bash
# Ver status de servicios
sudo systemctl status ec25-router
sudo systemctl status wan-manager
sudo systemctl status watchdog

# Ver logs en tiempo real
sudo journalctl -u ec25-router -f
```

## 🔐 SEGURIDAD - Cambiar password por defecto

### Por defecto:
- Usuario: `admin`
- Password: `admin1234`

### Para cambiar:
```bash
source venv/bin/activate
python3 << 'EOF'
from werkzeug.security import generate_password_hash
password = "TU_NUEVO_PASSWORD_SEGURO"
print(generate_password_hash(password))
EOF
```

Copiar el hash generado y pegarlo en `data/config.json` → `auth.password_hash`

```json
{
  "auth": {
    "username": "admin",
    "password_hash": "pbkdf2:sha256:600000$..."
  }
}
```

Reiniciar servicio:
```bash
sudo systemctl restart ec25-router
```

## 🔥 FIREWALL - Primera vez

### Limpiar reglas previas (opcional, solo si tienes problemas):
```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P FORWARD ACCEPT
sudo netfilter-persistent save
```

### Aplicar firewall desde la web:
1. Abrir http://RASPBERRY_IP:5000/
2. Login con admin/admin1234
3. Ir a Settings
4. Marcar/desmarcar "Aislar clientes Wi-Fi"
5. Click "Aplicar"

Esto configura automáticamente:
- NAT (masquerade) para eth0 y usb0
- Forwarding de wlan0 → eth0/usb0
- Opcional: Bloqueo wlan0 → wlan0 (aislamiento)

## 📊 APIS DISPONIBLES

Todas las rutas requieren login. Si no estás autenticado, redirige a `/login`.

### GET /
Dashboard principal

### GET /settings
Página de configuración

### GET /api/signal
Señal del módem
```json
{"csq": "...", "qcsq": "..."}
```

### GET /api/modem/info
Info completa del módem
```json
{
  "cops": "...",
  "qnwinfo": "...",
  "creg": "...",
  "cereg": "...",
  "cpin": "..."
}
```

### POST /api/modem/reset
Reinicia el módem EC25

### GET /api/wan
Estado WAN actual
```json
{"active": "eth", "mode": "auto"}
```

### POST /api/wan
Cambiar modo WAN
```json
{"mode": "auto"}  // o "eth" o "lte"
```

### POST /api/apn
Cambiar APN
```json
{"apn": "internet.com"}
```

### POST /api/security
Configurar firewall
```json
{"isolate_clients": true}
```

## 🧪 PRUEBAS

### 1. Verificar login
```bash
curl http://localhost:5000/
# Debería redirigir a /login o devolver 401
```

### 2. Probar autenticación
```bash
# Login desde navegador
# http://localhost:5000/login
# admin / admin1234
```

### 3. Ver logs de aplicación
```bash
# Logs rotativos
tail -f /var/log/ec25-router/app.log

# Logs de systemd
sudo journalctl -u ec25-router -f
```

### 4. Watchdog funcionando
```bash
# Ver logs del watchdog
sudo journalctl -u watchdog -f

# Desconectar cable ethernet
# Watchdog detectará falta de internet y probará recovery
```

### 5. Firewall activo
```bash
# Ver reglas actuales
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# Deberías ver reglas de NAT y FORWARD
```

## 🔍 TROUBLESHOOTING

### El servicio no inicia
```bash
# Ver logs completos
sudo journalctl -u ec25-router -n 100 --no-pager

# Verificar permisos
ls -la /opt/ec25-router/run.py
ls -la /var/log/ec25-router/

# Probar manualmente
cd /opt/ec25-router
source venv/bin/activate
python run.py
```

### No puedo hacer login
```bash
# Verificar config.json
cat /opt/ec25-router/data/config.json | jq '.auth'

# Regenerar password si está vacío
cd /opt/ec25-router
source venv/bin/activate
python -c "from app.auth import ensure_password_hash; ensure_password_hash()"
sudo systemctl restart ec25-router
```

### Firewall no aplica
```bash
# Verificar que iptables-persistent está instalado
sudo apt install iptables-persistent

# Verificar que ejecutas como root el firewall
# (desde web está OK, se llama como root)

# Ver errores
sudo journalctl -u ec25-router | grep firewall
```

### Watchdog no recupera LTE
```bash
# Ver logs
sudo journalctl -u watchdog -f

# Verificar que puede ejecutar dhclient
which dhclient

# Probar manualmente
sudo dhclient -r usb0
sudo dhclient usb0
```

### No llega al puerto 5000
```bash
# Verificar que Gunicorn está escuchando
sudo netstat -tlnp | grep 5000

# Ver si hay firewall bloqueando
sudo iptables -L INPUT -n -v

# Si estás en otra máquina, asegúrate que RPi acepta conexiones
sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT
```

## 📝 ESTRUCTURA COMPLETA

```
/opt/ec25-router/
├── app/
│   ├── __init__.py          # App factory + Flask-Login
│   ├── auth.py              # Sistema de autenticación
│   ├── config.py            # Carga/guarda JSON
│   ├── firewall.py          # iptables NAT + forwarding
│   ├── logging_config.py    # Logging rotativo
│   ├── modem.py             # Comandos AT
│   ├── network.py           # Detección WAN
│   ├── utils.py             #  Utilidades
│   └── web.py               # Rutas Flask
│
├── templates/
│   ├── base.html            # Template base con nav
│   ├── dashboard.html       # Dashboard principal
│   ├── login.html           # Página de login
│   └── settings.html        # Configuración
│
├── static/
│   ├── css/
│   │   └── style.css        # UI oscura profesional
│   └── js/
│       ├── dashboard.js     # Lógica dashboard
│       └── settings.js      # Lógica settings
│
├── data/
│   └── config.json          # Configuración persistente
│
├── scripts/
│   ├── ecm-start.sh         # DHCP para ECM
│   ├── wan-manager.sh       # Failover WAN automático
│   └── watchdog.sh          # Auto-recovery
│
├── systemd/
│   ├── ec25-router.service  # Servicio Flask/Gunicorn
│   ├── wan-manager.service  # Servicio failover
│   └── watchdog.service     # Servicio watchdog
│
├── venv/                    # Virtual environment
├── run.py                   # Entrypoint WSGI
├── requirements.txt         # Dependencias Python
├── README.md                # Documentación
└── ETAPA4.md                # Esta guía
```

## ✅ CHECKLIST FINAL

- [ ] Servicios instalados y funcionando
- [ ] Login funciona (admin/admin1234)
- [ ] Dashboard muestra WAN activa
- [ ] Cambio de WAN mode funciona
- [ ] Reset de módem funciona
- [ ] Settings guarda APN
- [ ] Firewall se aplica (iptables -L muestra reglas)
- [ ] Watchdog detecta caídas de conexión
- [ ] Logs rotativos en /var/log/ec25-router/
- [ ] Password cambiado de default

## 🎉 ¡FELICITACIONES!

Tu router EC25 está ahora en producción con:
- ✅ Autenticación segura
- ✅ Servidor WSGI robusto (Gunicorn)
- ✅ Logs controlados
- ✅ Firewall configurable
- ✅ Auto-recovery de WAN
- ✅ UI profesional

**Próximas etapas opcionales:**
- Etapa 5: Estadísticas de uso y gráficos
- Etapa 6: Alertas por Telegram/Email
- Etapa 7: API REST completa
- Etapa 8: Configuración WiFi desde panel
