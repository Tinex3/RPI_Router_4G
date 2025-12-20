#!/bin/bash
# Estructura del proyecto EC25 Router - ETAPA 2

cat << 'EOF'
ec25-router/
├── app/
│   ├── __init__.py
│   ├── config.py              ✅ Carga/guarda JSON
│   ├── modem.py               ✅ AT commands + auto-detect
│   ├── network.py             ✅ NUEVO - Failover logic
│   ├── utils.py
│   └── web.py                 ✅ ACTUALIZADO - /api/wan
│
├── templates/
│   ├── base.html              ✅ Simplificado
│   ├── dashboard.html         ✅ Monitor de señal
│   └── settings.html          ✅ Config APN
│
├── static/
│   ├── css/
│   │   └── style.css
│   └── js/
│       ├── dashboard.js
│       └── settings.js
│
├── data/
│   └── config.json            ✅ Configuración (APN, etc)
│
├── scripts/
│   ├── ecm-start.sh          ✅ DHCP para ECM
│   └── wan-manager.sh        ✅ NUEVO - Failover bash loop
│
├── systemd/                   ✅ NUEVO DIRECTORIO
│   └── wan-manager.service   ✅ NUEVO - Servicio auto-failover
│
├── venv/                      (virtual env - no versionado)
│
├── run.py                     ✅ Entrypoint Flask
├── ec25-router.service        ✅ Servicio Flask
├── requirements.txt           ✅ Dependencies
├── README.md                  ✅ Documentación
├── ETAPA2.md                  ✅ NUEVO - Guía instalación failover
└── .gitignore                 (recomendado)

═══════════════════════════════════════════════════════════════

🎯 ETAPA 2 IMPLEMENTADA

✅ app/network.py
   - Detecta interfaces eth0 / usb0
   - Verifica conectividad real (ping 8.8.8.8)
   - Expone: get_active_wan(), get_wan_status()

✅ scripts/wan-manager.sh (ejecutable)
   - Loop infinito cada 5 segundos
   - Modifica rutas Linux dinámicamente
   - eth0 métrica 100 (preferida)
   - usb0 métrica 200 (backup)

✅ systemd/wan-manager.service
   - Auto-arranca al boot
   - Se reinicia si falla
   - Ejecuta con root

✅ app/web.py (actualizado)
   - Nueva ruta: GET /api/wan
   - Retorna estado WAN en JSON

═══════════════════════════════════════════════════════════════

🚀 PRÓXIMOS PASOS

1. En Raspberry Pi:
   chmod +x scripts/wan-manager.sh
   sudo cp -r . /opt/ec25-router
   sudo ln -s /opt/ec25-router/systemd/wan-manager.service \
              /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable wan-manager
   sudo systemctl start wan-manager

2. Verificar:
   ip route
   sudo journalctl -u wan-manager -f
   curl http://localhost:5000/api/wan

3. Etapa 3: Dashboard mostrando WAN status en vivo

═══════════════════════════════════════════════════════════════
EOF
