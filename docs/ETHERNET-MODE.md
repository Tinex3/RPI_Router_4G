# Modo Ethernet: WAN vs LAN

Este sistema permite usar el puerto Ethernet de dos formas diferentes:

## 🌐 Modo WAN (Entrada de Internet) - Por defecto

**Uso:** Ethernet recibe internet y hace failover con EC25

- eth0 obtiene IP por DHCP de tu router/ISP
- Failover automático: EC25 → Ethernet cada 30s
- Sistema usa la mejor WAN disponible
- Ideal para backup de internet

### Activación:
```bash
sudo bash /opt/ec25-router/scripts/restore-eth-wan.sh
```

O desde la web: **Settings → Modo Ethernet → Modo WAN (Entrada)**

---

## 🔌 Modo LAN (Salida de Internet)

**Uso:** Ethernet comparte internet del EC25 a otros dispositivos

- eth0 se configura como gateway (192.168.1.1/24)
- DHCP server activo (192.168.1.10 - 192.168.1.100)
- NAT para compartir internet del EC25
- Ideal para conectar switch/router/PC por cable

### Activación:
```bash
sudo bash /opt/ec25-router/scripts/setup-eth-lan.sh
```

O desde la web: **Settings → Modo Ethernet → Modo LAN (Salida)**

### ¿Qué pasa cuando activo modo LAN?

1. **eth0 deja de recibir internet** (ya no es WAN)
2. **Solo EC25 (4G) será la WAN** del sistema
3. **eth0 comparte internet del EC25** a dispositivos conectados
4. **Dispositivos conectados obtienen IP automáticamente** (192.168.1.x)

### Configuración de red en modo LAN:

| Parámetro | Valor |
|-----------|-------|
| IP Gateway | 192.168.1.1 |
| Subnet | 192.168.1.0/24 |
| DHCP Range | 192.168.1.10 - 192.168.1.100 |
| DNS | 8.8.8.8, 8.8.4.4 |

---

## 🔄 Cambiar entre modos

### Desde la web (recomendado):
1. Ir a **Settings**
2. Ver **Modo Ethernet** actual
3. Hacer clic en:
   - **Modo LAN (Salida)** → Para compartir internet
   - **Modo WAN (Entrada)** → Para failover automático

### Desde terminal:

**Activar modo LAN:**
```bash
ssh server@serverpi.local
sudo bash /opt/ec25-router/scripts/setup-eth-lan.sh
```

**Volver a modo WAN:**
```bash
ssh server@serverpi.local
sudo bash /opt/ec25-router/scripts/restore-eth-wan.sh
```

---

## 📋 Ejemplos de uso

### Caso 1: Router 4G puro (modo LAN)
```
Internet → EC25 (4G) → ServerPi → [eth0] → Switch → Múltiples PCs
```
- Solo EC25 como WAN
- Ethernet comparte internet a dispositivos
- Útil para oficina pequeña, casa, etc.

### Caso 2: Failover automático (modo WAN)
```
Internet → Router ISP → [eth0] → ServerPi ← EC25 (backup 4G)
                          ↓
                      [wlan0] → WiFi AP → Clientes WiFi
```
- Ethernet principal, EC25 backup
- Cambio automático cada 30s
- Alta disponibilidad

---

## ⚠️ Advertencias

**Modo LAN:**
- ❌ eth0 NO recibirá internet
- ❌ Failover automático NO funcionará
- ✅ Solo EC25 será la WAN
- ✅ eth0 compartirá internet del EC25

**Modo WAN:**
- ✅ Failover automático habilitado
- ✅ eth0 puede recibir internet
- ❌ eth0 NO compartirá internet a otros dispositivos

---

## 🔍 Verificar modo actual

### Desde la web:
Settings → **Modo Ethernet** → Ver indicador

### Desde terminal:
```bash
# Verificar flag de modo LAN
if [ -f /etc/ec25-router/eth0-lan-mode ]; then
    echo "🔌 Modo LAN (Salida)"
else
    echo "🌐 Modo WAN (Entrada)"
fi

# Ver IP de eth0
ip addr show eth0 | grep "inet "

# Ver logs de failover
journalctl -u wan-failover.service -f
```

---

## 🛠️ Troubleshooting

### No puedo conectar por SSH después de cambiar a modo LAN
- La IP del ServerPi en eth0 cambia a **192.168.1.1**
- Reconecta vía WiFi: `serverpi.local` (192.168.50.1)
- O conecta directamente: `ssh server@192.168.1.1`

### Dispositivos no obtienen IP en modo LAN
```bash
# Verificar DHCP server
sudo systemctl status dnsmasq

# Ver configuración
cat /etc/dnsmasq.d/eth0-lan.conf

# Reiniciar servicio
sudo systemctl restart dnsmasq
```

### Sin internet en modo LAN
```bash
# Verificar EC25 tiene internet
ping -I wwan0 8.8.8.8

# Verificar NAT
sudo iptables -t nat -L POSTROUTING -v -n | grep 192.168.1

# Ver rutas
ip route show
```

### Quiero volver a modo WAN
```bash
sudo bash /opt/ec25-router/scripts/restore-eth-wan.sh
```

---

## 📚 Archivos relacionados

- `/opt/ec25-router/scripts/setup-eth-lan.sh` - Activar modo LAN
- `/opt/ec25-router/scripts/restore-eth-wan.sh` - Restaurar modo WAN
- `/etc/ec25-router/eth0-lan-mode` - Flag indicando modo LAN
- `/etc/dnsmasq.d/eth0-lan.conf` - Config DHCP para eth0
- `/opt/ec25-router/scripts/wan-failover.sh` - Respeta modo configurado
