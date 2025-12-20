# ETAPA 3 - Router Administrable

## 🎯 Objetivo
Convertir el router en un sistema administrable desde web con control total de WAN y modem.

## 📁 Archivos nuevos / modificados

✅ `data/config.json` - Nuevo: `wan_mode` (auto/eth/lte)
✅ `app/network.py` - Actualizado: Respeta `wan_mode` de config
✅ `app/modem.py` - Actualizado: `get_network_info()` y `reset_modem()`
✅ `app/web.py` - Actualizado: 4 nuevas rutas API
✅ `templates/dashboard.html` - Actualizado: UI con selector WAN + reset
✅ `static/js/dashboard.js` - Actualizado: Lógica completa
✅ `scripts/wan-manager.sh` - Actualizado: Lee config.json dinámicamente

## 🏗️ ARQUITECTURA - QUÉ CAMBIÓ

**Antes (Etapa 2):**
```
wan-manager.sh → Decide solo basado en disponibilidad
```

**Ahora (Etapa 3):**
```
Flask API ← Usuario/Dashboard
    ↓
config.json (wan_mode)
    ↓
wan-manager.sh → Obedece config.json
```

## 🔧 CONFIGURACIÓN

### data/config.json
```json
{
  "apn": "wap.tmovil.cl",
  "ip_type": "IPV4V6",
  "wan_mode": "auto"
}
```

**Valores de `wan_mode`:**
- `"auto"` - Failover automático (Ethernet → LTE)
- `"eth"` - Forzar solo Ethernet
- `"lte"` - Forzar solo LTE

## 📡 NUEVAS APIs

### GET /api/wan
Obtener WAN activa
```bash
curl http://localhost:5000/api/wan
# {"active": "eth"}  o  {"active": "lte"}  o  {"active": "down"}
```

### POST /api/wan
Cambiar modo WAN
```bash
curl -X POST http://localhost:5000/api/wan \
  -H "Content-Type: application/json" \
  -d '{"mode": "eth"}'
```

### GET /api/modem/info
Obtener info del modem (operador, tecnología, banda)
```bash
curl http://localhost:5000/api/modem/info
```

### POST /api/modem/reset
Reiniciar modem
```bash
curl -X POST http://localhost:5000/api/modem/reset
```

## 🚀 INSTALACIÓN EN RASPBERRY PI

### 1. Preparar
```bash
# Instalar jq (para leer JSON desde bash)
sudo apt update
sudo apt install -y jq

# Si ya existe, actualizar archivos
cd /opt/ec25-router
git pull
# o copiar manualmente los archivos nuevos
```

### 2. Hacer script ejecutable
```bash
chmod +x scripts/wan-manager.sh
```

### 3. Reiniciar servicio
```bash
sudo systemctl restart wan-manager
sudo systemctl status wan-manager
```

## 🧪 PRUEBAS

### Prueba 1: Ver WAN activa
```bash
curl http://localhost:5000/api/wan
# Respuesta: {"active": "eth"}
```

### Prueba 2: Forzar LTE
```bash
curl -X POST http://localhost:5000/api/wan \
  -H "Content-Type: application/json" \
  -d '{"mode": "lte"}'

curl http://localhost:5000/api/wan
# Respuesta: {"active": "lte"}

# Verificar rutas Linux
ip route
# Debería mostrar: default dev usb0 metric 100
```

### Prueba 3: Volver a auto
```bash
curl -X POST http://localhost:5000/api/wan \
  -H "Content-Type: application/json" \
  -d '{"mode": "auto"}'

# Desconectar Ethernet cable → en 5 segundos usará LTE
# Conectar Ethernet → en 5 segundos vuelve a Ethernet
```

### Prueba 4: Reset modem
```bash
curl -X POST http://localhost:5000/api/modem/reset
# Respuesta: {"ok": true, "response": "AT+CFUN=1,1\r\nOK\r\n"}

# El modem se reiniciará en ~10 segundos
```

### Prueba 5: Dashboard web
```
http://localhost:5000/
```
- Ver "WAN Status" con icono 🔌 (Ethernet) o 📡 (LTE)
- Cambiar modo WAN desde dropdown
- Clickear "Reset Modem"

## 📊 LOGS

Ver logs del servicio WAN manager:
```bash
sudo journalctl -u wan-manager -f
# Verás cada cambio de ruta cada 5 segundos
```

Ver logs de Flask:
```bash
# En la terminal donde corre Flask
python run.py
# O si está como servicio systemd:
sudo journalctl -u ec25-router -f
```

## 🔄 FLUJO COMPLETO

1. **Usuario entra a http://localhost:5000**
   - JavaScript carga GET /api/wan
   - Muestra WAN activa (🔌 Ethernet / 📡 LTE)
   - Muestra información del modem

2. **Usuario selecciona "Ethernet Only"**
   - POST /api/wan con {"mode": "eth"}
   - Flask actualiza config.json
   - wan-manager.sh lo lee cada 5 segundos
   - Rutas Linux se ajustan
   - Dashboard muestra cambio en tiempo real

3. **Usuario clickea "Reset Modem"**
   - POST /api/modem/reset
   - Flask envía AT+CFUN=1,1
   - Modem se reinicia (~10 seg)
   - Dashboard vuelve a cargar info

## 🐛 TROUBLESHOOTING

### WAN siempre muestra "down"
```bash
# Verificar interfaces
ip link show eth0
ip link show usb0

# Probar conectividad manualmente
ping -I eth0 8.8.8.8
ping -I usb0 8.8.8.8

# Ver rutas actuales
ip route
```

### wan-manager.sh no respeta cambios
```bash
# Ver logs
sudo journalctl -u wan-manager -f

# Verificar que jq está instalado
which jq

# Verificar permisos
ls -la scripts/wan-manager.sh
# Debe ser: -rwxrwxr-x
```

### Modem no responde a AT commands
```bash
# Verificar puerto
ls -la /dev/ttyUSB*

# Probar manualmente con minicom
minicom -D /dev/ttyUSB2  # o el que corresponda
# Tipear: AT
# Presionar Ctrl+A, Q para salir
```

## 📈 MÉTRICAS LINUX

Las métricas actuales:
- Ethernet: 100 (prioritaria)
- LTE: 300 (backup)

Cuando se fuerza modo LTE:
- LTE: 100 (fuerza uso)

Esto asegura que Linux siempre elige la ruta con menor métrica.

## ✅ CHECKLIST PRE-PRODUCCIÓN

- [ ] jq instalado: `which jq`
- [ ] wan-manager.sh ejecutable: `ls -la scripts/wan-manager.sh | grep x`
- [ ] Servicio activo: `sudo systemctl status wan-manager`
- [ ] Flask corriendo: `sudo systemctl status ec25-router` (si está como servicio)
- [ ] API funciona: `curl http://localhost:5000/api/wan`
- [ ] Dashboard accesible: `http://localhost:5000/`
- [ ] Cambios persisten: Cambiar wan_mode, reiniciar Flask, sigue igual

## 🎯 PRÓXIMAS ETAPAS

**Etapa 4:** WiFi AP + DHCP server
**Etapa 5:** Estadísticas de uso (tráfico, velocidad)
**Etapa 6:** Alertas y monitoreo

---
**Estado:** ✅ ROUTER ADMINISTRABLE
**Complejidad:** Media
**Tiempo instalación:** ~10 minutos
