# ARCHITECTURE — Network & LoRaWAN Gateway Management Platform

> Versión 2.0 — Migración de Flask a FastAPI + React
> Fecha: 2026-08-11

---

## Visión general

Plataforma Full Stack + IoT + Infrastructure Management para Raspberry Pi 4 que administra:
Ethernet, WiFi, 4G/LTE, Access Point, failover, LoRaWAN Basic Station, Docker, métricas, usuarios, SSH, backups, logs, watchdog.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | React 18 + Vite + TypeScript + React Router |
| Backend | Python 3.9+ + FastAPI + Uvicorn + Pydantic |
| Base de datos | SQLite + SQLAlchemy (async) |
| Autenticación | JWT + bcrypt + RBAC (admin/user) |
| Infraestructura | Docker + Docker Compose + systemd |
| IoT | LoRaWAN Basic Station (Docker container) |
| Testing | pytest + httpx + pytest-asyncio |

---

## Estructura del proyecto

```
RPI_Router_4G/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI app factory + lifespan
│   │   ├── config.py            # Settings via pydantic-settings
│   │   ├── database.py          # SQLAlchemy async engine + session
│   │   ├── api/                 # Routers por dominio
│   │   │   ├── __init__.py
│   │   │   ├── auth.py          # /api/auth/*
│   │   │   ├── network.py       # /api/network/*
│   │   │   ├── wifi.py          # /api/wifi/*
│   │   │   ├── lte.py           # /api/lte/*
│   │   │   ├── metrics.py       # /api/metrics/*
│   │   │   ├── system.py        # /api/system/*
│   │   │   ├── docker.py        # /api/docker/*
│   │   │   └── admin.py         # /api/admin/*
│   │   ├── models/              # SQLAlchemy models
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── audit_log.py
│   │   │   ├── metric.py
│   │   │   └── backup.py
│   │   ├── schemas/             # Pydantic schemas
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── token.py
│   │   │   ├── network.py
│   │   │   └── lte.py
│   │   ├── services/            # Lógica de negocio + adapters
│   │   │   ├── __init__.py
│   │   │   ├── modem.py         # Migrado de app/modem.py
│   │   │   ├── ec25_monitor.py  # Migrado de app/ec25_monitor.py
│   │   │   ├── network.py
│   │   │   ├── wifi.py
│   │   │   ├── firewall.py
│   │   │   ├── docker.py
│   │   │   ├── speedtest.py
│   │   │   └── hardware.py
│   │   └── core/                # Infraestructura transversal
│   │       ├── __init__.py
│   │       ├── security.py      # JWT + hashing
│   │       ├── deps.py          # FastAPI dependencies
│   │       └── logging_config.py
│   ├── tests/
│   │   ├── conftest.py
│   │   ├── test_auth.py
│   │   └── test_network.py
│   ├── requirements.txt
│   └── alembic.ini              # (futuro) Migraciones
├── frontend/                    # (Fase 20)
├── scripts/                     # Bash scripts (legacy, mantenidos)
├── config/                      # Config files (hostapd, dnsmasq)
├── data/                        # Runtime data + SQLite
├── docs/                        # Documentación
│   ├── AUDIT.md
│   ├── ARCHITECTURE.md
│   ├── adr/
│   └── ...
├── PLAN/
└── README.md
```

---

## Capas de arquitectura

```
┌─────────────────────────────────────────────┐
│                  FRONTEND                    │
│            React + Vite + TS                 │
│         REST API + JWT tokens                │
└──────────────┬──────────────────────────────┘
               │ HTTP/HTTPS
┌──────────────▼──────────────────────────────┐
│                  API LAYER                   │
│         FastAPI Routers (por dominio)        │
│    /api/auth  /api/network  /api/lte  ...    │
│         Pydantic validation + OpenAPI        │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│              SERVICE LAYER                   │
│    NetworkService  WiFiService  LTEService   │
│    DockerService   ModemService  ...         │
│                                              │
│    ┌──────────────────────────────┐          │
│    │         ADAPTERS             │          │
│    │  NetworkAdapter  ModemAdapter│          │
│    │  GPIOAdapter  DockerAdapter  │          │
│    │  (interfaces for mocking)    │          │
│    └──────────────────────────────┘          │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│           SYSTEM / HARDWARE LAYER            │
│    Linux  Docker  Network  GPIO  Modem       │
│    systemd  iptables  hostapd  dnsmasq       │
└─────────────────────────────────────────────┘
```

---

## API Design

Todos los endpoints bajo `/api/` con prefijos por dominio:

| Prefijo | Dominio | Auth requerida |
|---|---|---|
| `/api/auth` | Login, refresh, perfil | No (login) / Sí (resto) |
| `/api/network` | Estado WAN, interfaces, failover | Sí |
| `/api/wifi` | Scan, conectar, AP mode | Sí (admin para escritura) |
| `/api/lte` | Métricas EC25, comandos AT | Sí |
| `/api/metrics` | CPU, RAM, storage, network usage | Sí |
| `/api/docker` | Contenedores, compose | Admin |
| `/api/lorawan` | Basic Station control | Admin |
| `/api/system` | Health, logs, reboot, SSH | Admin |
| `/api/admin` | Usuarios, backup, factory reset | Admin |

---

## Modelo de datos (SQLite)

```
users
├── id (PK)
├── username (unique)
├── hashed_password
├── role (admin | user)
├── is_active
├── created_at
└── last_login

audit_logs
├── id (PK)
├── user_id (FK → users)
├── action
├── resource
├── ip_address
├── result
├── metadata (JSON)
├── timestamp
└── ...

metrics_history
├── id (PK)
├── metric_type (cpu, ram, network_rx, network_tx, lte_signal, ...)
├── value
├── interface
├── timestamp
└── ...

config
├── id (PK)
├── key (unique)
├── value (JSON)
├── updated_at
└── ...
```

---

## Flujo de autenticación

```
POST /api/auth/login {username, password}
     │
     ▼
  Verificar bcrypt hash
     │
     ▼
  Generar JWT (access_token + refresh_token)
     │
     ▼
  Frontend almacena en localStorage/memory
     │
     ▼
  Requests subsiguientes: Authorization: Bearer <token>
     │
     ▼
  Middleware verifica JWT + rol (deps.py)
```

---

## Principios de diseño

1. **Separación de responsabilidades** — API → Service → Adapter
2. **Interfaces para testing** — Adapters con mocks para desarrollo sin RPi
3. **Type hints** — 100% del código Python con tipado
4. **Validación exhaustiva** — Pydantic models para entrada/salida
5. **Operaciones asíncronas** — Sin bloqueos en el event loop de FastAPI
6. **Configuración centralizada** — Un solo source of truth (pydantic-settings + SQLite)
7. **Logging estructurado** — RotatingFileHandler + console
8. **Seguridad por defecto** — JWT + bcrypt + CORS restrictivo + rate limiting
9. **Desarrollo sin hardware** — `APP_ENV=development` activa mocks
10. **Recuperación ante fallos** — Watchdog, health checks, graceful degradation

---

## ADR Index

- ADR-001 — Migración vs Reescritura
- ADR-002 — FastAPI como framework backend
- ADR-003 — SQLite como base de datos
- ADR-004 — Arquitectura de adapters para testing
- ADR-005 — JWT para autenticación
- (más ADRs según se tomen decisiones)
