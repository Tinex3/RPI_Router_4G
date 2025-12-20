#!/bin/bash
# 📋 RESUMEN ETAPA 3 - ROUTER ADMINISTRABLE

cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                    ETAPA 3 - ROUTER ADMINISTRABLE                     ║
╚════════════════════════════════════════════════════════════════════════╝

🎯 OBJETIVO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Dashboard web para ver WAN activa
✅ Cambiar modo WAN: auto / ethernet / lte
✅ Reset del modem desde web
✅ Ver info: operador, tecnología, banda
✅ Sistema controlado desde config.json + web

📁 ARCHIVOS MODIFICADOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  data/config.json
    ➕ Nuevo campo: "wan_mode": "auto"
    ✅ Valores: "auto" | "eth" | "lte"

2️⃣  app/network.py
    ✏️ active_wan() → Respeta wan_mode de config
    ✏️ Controla qué interfaz usar, no solo detecta

3️⃣  app/modem.py
    ➕ get_network_info() → Operador, tech, signal
    ➕ reset_modem() → Reinicia EC25

4️⃣  app/web.py
    ➕ GET  /api/wan → {"active": "eth"}
    ➕ POST /api/wan → Cambiar modo WAN
    ➕ GET  /api/modem/info → Info del modem
    ➕ POST /api/modem/reset → Reset modem

5️⃣  templates/dashboard.html
    🎨 Nuevo: Selector WAN (dropdown)
    🎨 Nuevo: Botón Reset Modem
    🎨 Nuevo: Info del modem en JSON

6️⃣  static/js/dashboard.js
    ✏️ Auto-refresh cada 5 segundos
    ✏️ Manejo de cambios WAN
    ✏️ Confirmación antes de reset

7️⃣  scripts/wan-manager.sh
    ✏️ Ahora lee config.json con jq
    ✏️ Respeta wan_mode forzado
    ✏️ Mantiene failover automático

🔄 FLUJO ARQUITECTÓNICO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────┐
│   Dashboard  │  🌐 http://localhost:5000
│   (HTML/JS)  │
└──────┬───────┘
       │
       ├──→ GET  /api/wan
       │         ↓ active_wan()
       │         ↓ Retorna WAN activa
       │
       ├──→ POST /api/wan {"mode": "eth"}
       │         ↓ Guarda en config.json
       │         ↓ wan-manager.sh lo lee
       │         ↓ Ajusta rutas Linux
       │
       ├──→ GET  /api/modem/info
       │         ↓ Lee AT+COPS?, AT+QNWINFO
       │
       └──→ POST /api/modem/reset
               ↓ Envía AT+CFUN=1,1

📊 APIS DISPONIBLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GET /api/wan
  Respuesta: {"active": "eth"} | {"active": "lte"} | {"active": "down"}

POST /api/wan
  Body: {"mode": "auto"} | {"mode": "eth"} | {"mode": "lte"}
  Respuesta: {"ok": true, "mode": "auto"}

GET /api/modem/info
  Respuesta: {
    "operator": "AT+COPS?\r\n+COPS: 0,0,\"Claro\",2\r\n...",
    "tech": "AT+QNWINFO\r\n+QNWINFO: ...",
    "signal": "AT+QCSQ\r\n+QCSQ: ...",
  }

POST /api/modem/reset
  Respuesta: {"ok": true, "response": "..."}

🚀 INSTALACIÓN RÁPIDA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# En Raspberry Pi:
sudo apt install -y jq
chmod +x scripts/wan-manager.sh
sudo systemctl restart wan-manager

# Verificar:
curl http://localhost:5000/api/wan
http://localhost:5000/

✅ CHECKLIST DE VALIDACIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Terminal 1 - Ver logs del router:
  sudo journalctl -u wan-manager -f

Terminal 2 - Probar APIs:
  curl http://localhost:5000/api/wan
  # Cambiar a LTE:
  curl -X POST http://localhost:5000/api/wan \
    -H "Content-Type: application/json" \
    -d '{"mode": "lte"}'
  # Volver a auto:
  curl -X POST http://localhost:5000/api/wan \
    -H "Content-Type: application/json" \
    -d '{"mode": "auto"}'

Navegador:
  http://localhost:5000/
  - Ver WAN activa (🔌 Ethernet / 📡 LTE)
  - Cambiar modo WAN con dropdown
  - Clickear "Reset Modem"

🎯 DECISIONES DE DISEÑO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✔ config.json es la fuente de verdad
✔ wan-manager.sh es un servicio que obedece
✔ Flask es el controlador, no ejecuta lógica crítica
✔ Fácil de extender para futuras etapas
✔ Escalable: se puede agregar Wifi, estadísticas, etc.

🔐 PERMISOS NECESARIOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ wan-manager.sh necesita ejecutarse como root para cambiar rutas:
   - /etc/systemd/system/wan-manager.service → User=root

⚠️ AT commands pueden necesitar acceso especial:
   - Usuario Flask en grupo dialout: sudo usermod -a -G dialout nobody

⚠️ Lectura de config.json:
   - Debe estar en ruta accesible: /opt/ec25-router/data/config.json

🐛 COMMON ISSUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"jq: command not found"
  → sudo apt install -y jq

"WAN siempre muestra 'down'"
  → Verificar: ping -I eth0 8.8.8.8 && ping -I usb0 8.8.8.8

"Cambio wan_mode pero no cambia ruta"
  → Ver logs: sudo journalctl -u wan-manager -f
  → Verificar: cat /opt/ec25-router/data/config.json

"Modem no responde"
  → ls -la /dev/ttyUSB*
  → Verificar permisos UART

📈 PRÓXIMAS ETAPAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Etapa 4: WiFi + DHCP server (AP local)
Etapa 5: Estadísticas de uso
Etapa 6: Monitoreo y alertas
Etapa 7: API REST completa para clientes

═════════════════════════════════════════════════════════════════════════

✅ ESTADO: Router administrable via web
📊 COMPLEJIDAD: Media
⏱️  TIEMPO INSTALACIÓN: ~10 minutos
📄 DOCUMENTACIÓN: Ver ETAPA3.md

═════════════════════════════════════════════════════════════════════════
EOF
