# 🚀 NUEVO: Smart WAN Failover - Sin Flapping

## ✅ Problema Resuelto

**Antes:**
- Sistema revisaba cada 30s ambas interfaces
- Cambiaba constantemente (flapping)
- Pérdida de conexión en cada cambio
- Logs saturados

**Ahora:**
- **Sticky mode:** Mantiene la activa hasta que falle
- Solo cambia cuando hay fallo confirmado (3 pings)
- Conexiones estables
- Logs limpios

---

## 🎯 3 Modos Disponibles

### 1️⃣ 🌐 Ethernet ONLY
```
Solo eth0 → Sin failover → Ideal: Conexión estable
```

### 2️⃣ 📡 LTE ONLY
```
Solo wwan0 → Sin failover → Ideal: Router 4G puro
```

### 3️⃣ 🔄 Auto (Smart)
```
Prioridad Ethernet → Failover inteligente → Ideal: Alta disponibilidad
```

**Comportamiento Auto (Smart):**
- ✅ Usa Ethernet primero
- ✅ Monitorea la activa con ping
- ✅ Cambia SOLO cuando falla (3 pings)
- ✅ Vuelve a Ethernet cuando se recupera
- ❌ NO compara constantemente

---

## 🚀 Cómo Usar

### Desde la Web (Más Fácil)

1. Ve a **Settings**
2. Busca **"Modo WAN (Failover)"**
3. Haz clic en el botón que quieras:
   - **🌐 Ethernet ONLY**
   - **📡 LTE ONLY**
   - **🔄 Auto (Smart)**

### Desde Terminal

```bash
sudo bash /opt/ec25-router/scripts/wan-mode-config.sh
```

---

## 🔍 Verificar

```bash
# Ver modo configurado
cat /etc/ec25-router/wan-mode.conf

# Ver WAN activa
ip route show | grep default

# Ver logs en vivo
journalctl -u wan-failover.service -f
```

---

## 📋 Ejemplos de Logs

**Modo Auto - Funcionando bien:**
```
[INFO] Monitoreando WAN activa: eth0
[INFO] WAN activa (eth0) funcionando correctamente
```

**Modo Auto - Failover:**
```
[WARN] WAN activa (eth0) FALLÓ - Iniciando failover...
[INFO] WAN cambiada a: wwan0 via 10.128.171.57
[WARN] Failover: Ethernet → LTE completado
```

**Modo Auto - Recovery:**
```
[INFO] Ethernet disponible nuevamente, cambiando por prioridad
[INFO] WAN cambiada a: eth0 via 192.168.1.1
```

---

## 🎓 ¿Qué es "Sticky"?

**Sticky = Pegajoso:** Una vez establece una conexión, se "pega" a ella y NO cambia innecesariamente.

**Ejemplo sin sticky (antes):**
```
Segundo 0: Ethernet (latencia 10ms)
Segundo 30: LTE (latencia 8ms) → ¡Cambio!
Segundo 60: Ethernet (latencia 9ms) → ¡Cambio!
Segundo 90: LTE (latencia 7ms) → ¡Cambio!
```

**Con sticky (ahora):**
```
Segundo 0: Ethernet OK → Mantiene Ethernet
Segundo 30: Ethernet OK → Mantiene Ethernet
Segundo 60: Ethernet OK → Mantiene Ethernet
Segundo 90: Ethernet FAIL → Cambia a LTE
Segundo 120: LTE OK → Mantiene LTE
Segundo 150: LTE OK + Ethernet recuperado → Vuelve a Ethernet (prioridad)
```

---

## 💡 Recomendaciones

| Situación | Modo Recomendado |
|-----------|------------------|
| Ethernet confiable | 🌐 Ethernet ONLY |
| Sin cable, solo 4G | 📡 LTE ONLY |
| Necesito backup automático | 🔄 Auto (Smart) |
| Router portable | 📡 LTE ONLY |
| Servidor crítico | 🔄 Auto (Smart) |

---

## 📚 Documentación Completa

Ver: [docs/WAN-MODES.md](WAN-MODES.md) para:
- Explicación detallada de cada modo
- Flujo técnico de Smart Failover
- Configuración avanzada
- Troubleshooting completo

---

## ✨ Características Destacadas

1. **Ping por interfaz específica**: Verifica conectividad real, no solo "link up"
2. **Confirmación de fallo**: 3 pings fallidos antes de cambiar
3. **Prioridad fija**: Ethernet > LTE (no depende de métricas variables)
4. **Recovery automático**: Vuelve a preferred WAN cuando se recupera
5. **Estado persistente**: Guarda WAN activa en `/var/run/wan-failover-state`
6. **Logs útiles**: INFO/WARN/ERROR con contexto claro

---

## 🔧 Troubleshooting Rápido

### No cambia de modo
```bash
sudo systemctl restart wan-failover.service
journalctl -u wan-failover.service -n 50
```

### Flapping persiste
```bash
# Cambiar a modo fijo temporalmente
echo "MODE=ethernet-only" | sudo tee /etc/ec25-router/wan-mode.conf
sudo systemctl restart wan-failover.service
```

### Test manual
```bash
# Ejecutar una vez
sudo bash /opt/ec25-router/scripts/wan-failover.sh

# Testear ping por interfaz
ping -I eth0 -c 3 8.8.8.8
ping -I wwan0 -c 3 8.8.8.8
```

---

✅ **Sistema instalado y funcionando!**

El modo por defecto es **Auto (Smart)**, pero puedes cambiarlo desde Settings cuando quieras.
