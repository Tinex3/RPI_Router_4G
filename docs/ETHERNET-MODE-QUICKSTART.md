## 🔌 NUEVO: Modo Ethernet Dual

Ahora puedes usar el puerto Ethernet de **dos formas diferentes**:

### 🌐 Modo WAN (Por defecto)
**Ethernet recibe internet** → Failover automático con EC25

```
Router ISP → [eth0] → ServerPi ← [EC25 backup]
                ↓
          WiFi AP → Clientes
```

- ✅ Failover automático cada 30s
- ✅ Alta disponibilidad
- ✅ Ethernet y EC25 como WAN

---

### 🔌 Modo LAN (Nuevo!)
**Ethernet comparte internet del EC25** → Para switch/router/PC

```
Internet → EC25 → ServerPi → [eth0] → Switch → Múltiples PCs
                      ↓
                  WiFi AP → Clientes
```

- ✅ Router 4G puro
- ✅ Ethernet como salida (192.168.1.1/24)
- ✅ DHCP automático para dispositivos conectados
- ❌ Sin failover (solo EC25 como WAN)

---

## 🚀 Cómo cambiar de modo

### Desde la Web (más fácil):

1. Ve a **Settings** en el panel web
2. Busca la sección **"Modo Ethernet"**
3. Haz clic en:
   - **🔌 Modo LAN (Salida)** → Para compartir internet
   - **🌐 Modo WAN (Entrada)** → Para failover

### Desde Terminal:

**Activar Modo LAN:**
```bash
cd /opt/ec25-router
sudo bash scripts/setup-eth-lan.sh
```

**Volver a Modo WAN:**
```bash
cd /opt/ec25-router
sudo bash scripts/restore-eth-wan.sh
```

---

## 📋 ¿Cuándo usar cada modo?

| Escenario | Modo Recomendado |
|-----------|------------------|
| Backup de ISP | 🌐 WAN |
| Router 4G portable | 🔌 LAN |
| Conectar switch | 🔌 LAN |
| Alta disponibilidad | 🌐 WAN |
| Solo 4G disponible | 🔌 LAN |

---

## ⚙️ Configuración en Modo LAN

Cuando activas **Modo LAN**, Ethernet se configura así:

- **IP Gateway:** 192.168.1.1
- **Subnet:** 192.168.1.0/24
- **DHCP:** 192.168.1.10 - 192.168.1.100
- **DNS:** 8.8.8.8, 8.8.4.4

**Los dispositivos conectados por cable obtendrán IP automáticamente.**

---

## 📚 Más info

Lee la documentación completa: [docs/ETHERNET-MODE.md](docs/ETHERNET-MODE.md)

- Troubleshooting
- Verificación de configuración
- Casos de uso detallados
- Logs y diagnóstico
