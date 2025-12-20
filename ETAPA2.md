# ETAPA 2 - WAN Auto Failover (DEPRECADO - Ver ETAPA3.md)

⚠️ **NOTA:** Esta etapa ha sido superada por la Etapa 3, que es más completa y administrable.
Consulta [ETAPA3.md](ETAPA3.md) para la versión actual.

## 📁 Archivos nuevos

- `app/network.py` - Lógica de detección WAN
- `scripts/wan-manager.sh` - Script failover (root)
- `systemd/wan-manager.service` - Servicio systemd
- `app/web.py` (actualizado) - Nueva ruta `/api/wan`

## 🚀 Instalación

### 1. Hacer script ejecutable
```bash
chmod +x scripts/wan-manager.sh
```

### 2. Instalar servicio (en Raspberry Pi)
```bash
# Copiar proyecto a /opt/ec25-router
sudo mkdir -p /opt/ec25-router
sudo cp -r . /opt/ec25-router

# Crear enlace simbólico del servicio
sudo ln -s /opt/ec25-router/systemd/wan-manager.service \
           /etc/systemd/system/wan-manager.service

# Recargar daemon
sudo systemctl daemon-reload

# Habilitar e iniciar
sudo systemctl enable wan-manager
sudo systemctl start wan-manager
```

### 3. Verificar estado
```bash
# Ver rutas actuales
ip route

# Ejemplo esperado:
# default dev eth0 metric 100
# default dev usb0 metric 200

# Ver logs del servicio
sudo journalctl -u wan-manager -f

# Ver si está corriendo
sudo systemctl status wan-manager
```

## 📊 Pruebas

### Prueba 1: Ethernet activo
```bash
# Conectar cable Ethernet
# Verificar ruta
ip route
# eth0 debe tener metric 100 (prioritario)
```

### Prueba 2: Failover a LTE
```bash
# Desconectar cable Ethernet
# Esperar 5-10 segundos
# Verificar ruta
ip route
# Debería mostrar usb0 con metric 100
```

### Prueba 3: API WAN
```bash
curl http://localhost:5000/api/wan

# Respuesta ejemplo:
{
  "eth": {"up": true, "internet": true},
  "lte": {"up": true, "internet": false},
  "active": "eth"
}
```

## 🔧 Entendiendo el código

### app/network.py
- `iface_up(iface)`: Verifica si interfaz está en estado UP
- `has_internet(iface)`: Verifica ping a 8.8.8.8 en esa interfaz
- `get_active_wan()`: Retorna "eth", "lte" o "none"
- `get_wan_status()`: Retorna estado detallado JSON

### scripts/wan-manager.sh
- Loop cada 5 segundos
- Si eth0 UP + internet → eth obtiene métrica 100 (preferida)
- Si solo lte UP + internet → lte obtiene métrica 100
- Linux automáticamente usa la ruta con menor métrica

### systemd/wan-manager.service
- Arranca automáticamente al boot
- Se reinicia si falla
- Ejecuta como root (necesario para cambiar rutas)

## 📡 Conceptos Linux

**Métricas de ruta:**
```
default dev eth0 metric 100  ← Esta se usa (menor métrica)
default dev usb0 metric 200  ← Backup
```

Si eth0 se desconecta, kernel nota que la ruta es inalcanzable y pasa a usb0.

## 🐛 Troubleshooting

### El servicio no inicia
```bash
sudo systemctl status wan-manager
sudo journalctl -u wan-manager -n 50
```

### No hay internet en LTE
```bash
# Verificar interfaz usb0
ip link show usb0
# Debería estar UP

# Verificar DHCP
ip addr show usb0
# Debería tener IP asignada

# Probar ping manual
ping -I usb0 8.8.8.8
```

### Ethernet no tiene prioritad
```bash
# Verificar si realmente tiene internet
ping -I eth0 8.8.8.8
# Si falla, eth no tiene internet real
```

## 🎯 Próximas etapas
- Etapa 3: Dashboard para ver estado WAN en tiempo real
- Etapa 4: Opción para forzar WAN (auto/eth/lte) desde web
- Etapa 5: WiFi + DHCP server
