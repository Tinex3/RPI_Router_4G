# AUDIT — RPI Router 4G

> Fase 0 — Auditoría completa del proyecto antes de la migración a FastAPI + React.
> Fecha: 2026-08-11

---

## 2.1 Arquitectura actual

La aplicación está construida con **Flask + Jinja2 + Vanilla JS** desplegada con **Gunicorn (2 workers)** y gestionada con **systemd** en una Raspberry Pi 4 con módem Quectel EC25.

```
Browser ──► Gunicorn (port 5000) ──► Flask (create_app)
                                        │
                          ┌─────────────┼─────────────┐
                          │             │             │
                   web.py (monolito)  auth.py    ec25_monitor.py
                   ~40 endpoints      .env       (hilo daemon)
                          │
              ┌───────────┼───────────┐
         modem.py    network.py   firewall.py
         (AT cmds)   (ping eth/usb) (iptables)
```

**Flujo de datos EC25:** Hilo daemon consulta módem cada 5s → `queue.Queue` → SSE streaming al frontend.

**Failover WAN:** Script bash (`wan-failover.sh`) ejecutado por systemd timer cada 30s. Sticky failover con 3 modos (ethernet-only, lte-only, auto-smart).

**WiFi AP:** hostapd + dnsmasq configurados por `setup-ap.sh`.

**Persistencia:** `data/config.json` (JSON plano) + `.env` (texto plano) + `/etc/ec25-router/wan-mode.conf`.

---

## 2.2 Componentes existentes

| Componente | Tecnología | Estado | Reutilizable |
|---|---|---|---|
| **Backend HTTP** | Flask + Gunicorn | Monolítico (web.py 819 líneas) | No |
| **Autenticación** | Flask-Login + .env texto plano | Inseguro | No |
| **Monitor EC25** | Thread + queue.Queue | Bien diseñado | Sí |
| **Capa AT commands** | pyserial + regex parsers | Excelente | Sí |
| **Firewall** | iptables vía subprocess | Con bug (AP_NET) | Parcial |
| **Network detection** | ping + socket | Con inconsistencia (usb0/wwan0) | Parcial |
| **Speedtest** | speedtest-cli (bloqueante) | Funcional | Parcial |
| **Failover WAN** | Bash + systemd timer | Robusto | Sí (como script) |
| **WiFi AP** | hostapd + dnsmasq | Robusto | Sí (como script) |
| **Watchdog** | Bash + AT commands | Funcional | Sí (como script) |
| **Diagnóstico** | Bash scripts (7 archivos) | Útiles | Sí (como scripts) |
| **Frontend** | Jinja2 + Vanilla JS + CSS | Profesional pero acoplado | CSS como referencia |
| **Base de datos** | No existe | N/A | N/A |
| **Configuración** | 4 fuentes dispersas | Fragmentada | No |
| **Logging** | RotatingFileHandler | Correcto | Sí |
| **Deploy** | SCP + SSH (contrasenas hardcodeadas) | Inseguro | No |
| **Docker** | scripts/setup-docker.sh | Preparación solamente | No |
| **Basic Station** | No existe en código actual | N/A | N/A |

---

## 2.3 Dependencias

### Se mantienen
- `pyserial` — Comunicación serial con EC25
- `gunicorn` — WSGI server (se reemplaza por uvicorn)
- `speedtest-cli` — Tests de velocidad

### Se reemplazan
- `flask` → `fastapi`
- `flask-login` → JWT (python-jose + passlib)

### Se eliminan
- Ninguna dependencia sobra, todas son necesarias para la versión legacy.

### Nuevas
- `fastapi`, `uvicorn`, `sqlalchemy`, `aiosqlite`, `pydantic`, `python-jose`, `passlib[bcrypt]`, `python-multipart`, `httpx`

---

## 2.4 Funcionalidades actuales

| Funcionalidad | Implementación | Cobertura |
|---|---|---|
| Dashboard LTE en tiempo real | SSE streaming | Completa |
| Métricas EC25 (CSQ, RSRP, RSRQ, SINR, banda, operador) | AT commands | Completa |
| Failover WAN (3 modos) | Bash + systemd | Completa |
| WiFi Access Point | hostapd + dnsmasq | Completa |
| Ethernet dual-mode (WAN/LAN) | Scripts bash | Completa |
| Speedtest | Bloqueante | Básica |
| Firewall/NAT | iptables | Completa |
| Watchdog auto-recovery | Bash | Completa |
| Autenticación | Texto plano, un solo usuario | Insegura |
| Configuración WiFi desde web | Flask + hostapd | Completa |
| Configuración APN/seguridad | Flask + JSON | Básica |

### No implementado
- Históricos de métricas
- Gráficos de consumo
- Alertas (email/Telegram)
- SMS Gateway
- VPN Server
- QoS / Traffic shaping
- Multi-usuario
- Audit log
- Backup/Restore
- Factory reset
- LoRaWAN Basic Station
- Docker management
- API REST documentada (OpenAPI)
- Tests automatizados

---

## 2.5 Riesgos

| Riesgo | Severidad | Descripción |
|---|---|---|
| Contraseñas en texto plano | CRÍTICO | .env, scripts de deploy |
| secret_key hardcodeada | CRÍTICO | app/__init__.py:18 |
| Sin rate limiting | ALTO | Endpoint /login vulnerable a fuerza bruta |
| Configuración fragmentada | ALTO | 4 fuentes de config inconsistentes |
| Interfaces inconsistentes | ALTO | usb0 vs wwan0 en network.py y scripts |
| AP_NET incorrecto | ALTO | firewall.py usa 192.168.4.0/24, AP real 192.168.50.0/24 |
| Scripts conflictivos | MEDIO | wan-manager.sh vs wan-failover.sh |
| Sin tests | MEDIO | Cero cobertura de testing |
| Speedtest bloqueante | BAJO | Bloquea un worker Gunicorn por 30-60s |
| .env no en .gitignore | MEDIO | Riesgo de commitear credenciales |

---

## 2.6 Deuda técnica

1. **Monolito web.py** — 819 líneas, ~40 endpoints sin separación de dominios
2. **Autenticación sin hashing** — Contraseñas en texto plano en .env
3. **Configuración dispersa** — 4 ubicaciones: config.json, .env, wan-mode.conf, flag files
4. **Código muerto** — app/utils.py, scripts/wan-failover-old.sh, scripts/ecm-start.sh, ec25-router.service (raíz)
5. **JavaScript inline** — templates/settings.html tiene ~180 líneas de JS mezclado con HTML
6. **Sin capa de servicios** — Lógica de negocio directamente en rutas Flask
7. **Sin base de datos** — Sin capacidad de guardar históricos, logs, o configuraciones estructuradas
8. **Scripts bash con lógica duplicada** — iptables, NAT, forwarding repetidos en 4+ scripts
9. **Sin API REST documentada** — No hay OpenAPI/Swagger
10. **Credenciales expuestas** — login.html muestra "admin / admin1234", hostapd.conf tiene wpa_passphrase pública

---

## 2.7 Basic Station

**No existe implementación actual de Basic Station en el código.** No hay Dockerfiles, docker-compose, ni configuración de LoRaWAN. El plan contempla agregarlo desde cero en fases posteriores (Fase 14).

---

## 2.8 Propuesta de migración

### Decisión: **MIGRACIÓN** (no rewrite)

**Razones:**
- `modem.py` y `ec25_monitor.py` son reutilizables con adaptaciones mínimas
- Los scripts bash (wan-failover.sh, setup-ap.sh) son robustos y pueden mantenerse como systemd services
- El conocimiento de dominio (AT commands, iptables, network routing) está bien capturado en el código existente
- La UI actual sirve como referencia de diseño comprobada
- Una reescritura total arriesga perder conocimiento empírico adquirido en producción

**Estrategia:**
1. Crear estructura `backend/` con FastAPI junto al código legacy
2. Migrar `modem.py` → `backend/app/services/modem.py` (adapter)
3. Migrar `ec25_monitor.py` → FastAPI background task
4. Refactorizar `web.py` → routers por dominio (auth, network, wifi, lte, system)
5. Agregar SQLite + SQLAlchemy para persistencia
6. Implementar auth con JWT + bcrypt + roles
7. Los scripts bash se mantienen en `scripts/` y se invocan desde servicios Python
8. El frontend React se construye en `frontend/` en fases posteriores

**Ventajas:**
- Menor riesgo que rewrite total
- El sistema legacy sigue funcionando durante la migración
- Reutiliza código de alta calidad (modem.py, ec25_monitor.py)
- Los scripts bash probados en producción no se tocan

**Desventajas:**
- Puede haber deuda técnica residual del código migrado
- Convivirán dos stacks durante la transición (Flask legacy + FastAPI nuevo)

**Tiempo estimado:** ~4-6 semanas para backend completo, +4-6 semanas para frontend React.
