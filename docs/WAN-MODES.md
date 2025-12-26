# 🔄 Modos WAN: Smart Failover

## 🎯 El Problema del Flapping

**Antes:** El sistema revisaba cada 30 segundos ambas interfaces y podía cambiar constantemente entre Ethernet y LTE, causando:
- Pérdida momentánea de conectividad en cada cambio
- Logs saturados con cambios frecuentes
- Inestabilidad en conexiones activas (SSH, streaming, VPN)

**Ahora:** Sistema inteligente con 3 modos de operación.

---

## 📋 Modos Disponibles

### 🌐 Ethernet ONLY

**Comportamiento:**
- Solo usa `eth0` como WAN
- NO hay failover automático
- Si Ethernet falla → Sin internet (hasta que se repare)

**Monitoreo:**
- Ping continuo a 8.8.8.8 desde `eth0`
- Logs de errores si pierde conectividad
- NO cambia a LTE automáticamente

**Ideal para:**
- Conexión Ethernet estable y confiable
- No tienes tarjeta LTE instalada
- Quieres evitar costos de datos móviles

---

### 📡 LTE ONLY

**Comportamiento:**
- Solo usa `wwan0` (EC25) como WAN
- NO hay failover automático
- Si LTE falla → Sin internet (hasta que recupere señal)

**Monitoreo:**
- Ping continuo a 8.8.8.8 desde `wwan0`
- Logs de errores si pierde conectividad
- NO cambia a Ethernet automáticamente

**Ideal para:**
- Router 4G puro / portable
- No hay Ethernet disponible
- Conexión LTE estable

---

### 🔄 Auto (Smart Failover)

**Comportamiento:**
- **Prioridad ETHERNET primero**
- **Sticky mode:** Usa la activa hasta que FALLE
- Solo cambia cuando la activa pierde internet
- NO compara señales constantemente

**Flujo:**

```
1. Boot → Intenta Ethernet primero
   ├─ Ethernet OK → Usa Ethernet
   └─ Ethernet FAIL → Usa LTE

2. Monitoreo continuo de la activa
   ├─ Ping OK (3 intentos) → Mantiene
   └─ Ping FAIL (3 intentos) → Failover

3. Ethernet activa
   ├─ Ethernet OK → Mantiene Ethernet
   ├─ Ethernet FAIL → Cambia a LTE
   └─ (En background) Revisa si Ethernet volvió → Cambia a Ethernet (prioridad)

4. LTE activa
   ├─ LTE OK + Ethernet recuperado → Cambia a Ethernet (prioridad)
   ├─ LTE OK + Ethernet down → Mantiene LTE
   └─ LTE FAIL → Intenta Ethernet
```

**Características:**
- ✅ **Sticky:** No cambia innecesariamente
- ✅ **Priority:** Prefiere Ethernet sobre LTE
- ✅ **Smart:** Solo cambia cuando hay fallo confirmado (3 pings)
- ✅ **No flapping:** No compara velocidades/latencias
- ✅ **Automatic recovery:** Vuelve a Ethernet cuando se recupera

**Ideal para:**
- Alta disponibilidad
- Backup automático
- Minimizar downtime

---

## 🚀 Configuración

### Desde la Web (Recomendado)

1. Ve a **Settings**
2. Busca **"Modo WAN (Failover)"**
3. Selecciona:
   - **🌐 Ethernet ONLY** - Solo cable
   - **📡 LTE ONLY** - Solo 4G
   - **🔄 Auto (Smart)** - Failover inteligente

### Desde Terminal

```bash
# Configurar modo interactivamente
sudo bash /opt/ec25-router/scripts/wan-mode-config.sh

# O configurar directamente
echo "MODE=auto-smart" | sudo tee /etc/ec25-router/wan-mode.conf
sudo systemctl restart wan-failover.service
```

---

## 🔍 Verificación

### Ver modo actual:

```bash
cat /etc/ec25-router/wan-mode.conf
# Salida: MODE=auto-smart
```

### Ver WAN activa:

```bash
ip route show | grep default
# default via 192.168.1.1 dev eth0  ← Ethernet activa
# default via 10.128.171.57 dev wwan0  ← LTE activa
```

### Ver logs en tiempo real:

```bash
journalctl -u wan-failover.service -f

# Ejemplos de logs:
# [INFO] Monitoreando WAN activa: eth0
# [INFO] WAN activa (eth0) funcionando correctamente
# [WARN] WAN activa (eth0) FALLÓ - Iniciando failover...
# [INFO] WAN cambiada a: wwan0 via 10.128.171.57
# [WARN] Failover: Ethernet → LTE completado
```

### Test de ping por interfaz:

```bash
# Ethernet
ping -I eth0 -c 3 8.8.8.8

# LTE
ping -I wwan0 -c 3 8.8.8.8
```

---

## 📊 Comparación de Modos

| Característica | Ethernet ONLY | LTE ONLY | Auto (Smart) |
|----------------|---------------|----------|--------------|
| Failover automático | ❌ | ❌ | ✅ |
| Usa Ethernet | ✅ | ❌ | ✅ (prioridad) |
| Usa LTE | ❌ | ✅ | ✅ (backup) |
| Cambios innecesarios | N/A | N/A | ❌ (sticky) |
| Downtime en fallo | ⚠️ Manual | ⚠️ Manual | ✅ Automático |
| Complejidad | Muy simple | Muy simple | Inteligente |

---

## ⚙️ Configuración Avanzada

### Cambiar target de ping:

Editar `/opt/ec25-router/scripts/wan-failover.sh`:

```bash
PING_TARGET="8.8.8.8"  # Cambiar a otro servidor
```

### Cambiar número de pings de verificación:

En `test_wan_ping()`:

```bash
local count="${2:-2}"  # Default 2 pings, cambiar a 3 o 4
```

### Ajustar timeout de ping:

```bash
ping -I "$iface" -c "$count" -W 3  # -W 3 = timeout 3 segundos
```

---

## 🛠️ Troubleshooting

### Modo no cambia

```bash
# Verificar configuración
cat /etc/ec25-router/wan-mode.conf

# Reiniciar servicio manualmente
sudo systemctl restart wan-failover.service

# Ver errores
journalctl -u wan-failover.service -n 50
```

### Failover no funciona

```bash
# Verificar que el timer está activo
systemctl status wan-failover.timer

# Ver próxima ejecución
systemctl list-timers | grep wan-failover

# Ejecutar manualmente para debug
sudo bash /opt/ec25-router/scripts/wan-failover.sh
```

### Flapping persiste

```bash
# Verificar modo
cat /etc/ec25-router/wan-mode.conf
# Debe ser: MODE=auto-smart

# Si es necesario, cambiar a ethernet-only o lte-only temporalmente
echo "MODE=ethernet-only" | sudo tee /etc/ec25-router/wan-mode.conf
sudo systemctl restart wan-failover.service
```

### Sin internet en ninguna interfaz

```bash
# Test manual de cada interfaz
ping -I eth0 -c 3 8.8.8.8
ping -I wwan0 -c 3 8.8.8.8

# Verificar rutas
ip route show

# Verificar IPs asignadas
ip addr show eth0
ip addr show wwan0
```

---

## 📚 Archivos Relacionados

- `/etc/ec25-router/wan-mode.conf` - Configuración de modo
- `/var/run/wan-failover-state` - WAN activa (cache)
- `/opt/ec25-router/scripts/wan-failover.sh` - Script principal
- `/opt/ec25-router/scripts/wan-mode-config.sh` - Configurador interactivo

---

## 🎓 Conceptos Técnicos

### Sticky Failover

**Definición:** Una vez establecida una conexión, se mantiene hasta que falle, en lugar de cambiar por métricas mejores.

**Ventajas:**
- Conexiones estables (no se interrumpen)
- Logs limpios (menos ruido)
- Menos overhead de CPU/red
- Comportamiento predecible

### Priority-Based Routing

**Definición:** Interfaces tienen prioridad fija (Ethernet > LTE), no basada en métricas dinámicas.

**Ventajas:**
- Comportamiento consistente
- Fácil troubleshooting
- No depende de condiciones de red variables

### Ping-Based Health Check

**Definición:** Usa ICMP ping para verificar conectividad real, no solo link status.

**Ventajas:**
- Detecta problemas de routing/DNS/gateway
- No solo "interfaz up"
- Bajo overhead
- Target configurable (8.8.8.8, 1.1.1.1, etc.)

---

## ✅ Best Practices

1. **Ethernet estable → Ethernet ONLY**
   - Ahorra recursos
   - Menos complejidad
   - Sin costos de datos móviles

2. **Router 4G portable → LTE ONLY**
   - Configuración simple
   - No necesita Ethernet

3. **Alta disponibilidad → Auto (Smart)**
   - Failover automático
   - Recuperación automática
   - Downtime mínimo

4. **Monitorea los logs regularmente**
   ```bash
   journalctl -u wan-failover.service --since "1 hour ago"
   ```

5. **Testea failover manualmente**
   - Desconecta Ethernet → Debe cambiar a LTE
   - Reconecta Ethernet → Debe volver a Ethernet
