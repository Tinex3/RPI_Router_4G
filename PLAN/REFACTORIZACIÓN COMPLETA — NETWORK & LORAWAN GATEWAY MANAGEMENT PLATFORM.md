# REFACTORIZACIÓN COMPLETA — NETWORK & LORAWAN GATEWAY MANAGEMENT PLATFORM

## 0. INSTRUCCIÓN PRINCIPAL

Este proyecto será sometido a una **refactorización/migración arquitectónica importante**.

El objetivo NO es simplemente agregar funcionalidades al software existente.

Se debe transformar el proyecto actual en una plataforma de gestión para una Raspberry Pi 4 que permita administrar:

- Ethernet
- WiFi
- 4G/LTE
- Access Point de configuración
- Métricas de red
- Failover de conectividad
- LoRaWAN Basic Station
- Docker
- Hardware Gateway
- Usuarios
- SSH
- Backups
- Logs
- Watchdog
- Actualizaciones
- Factory Reset

La plataforma debe tener arquitectura **Full Stack + IoT + Infrastructure Management**.

---

# 1. PRIMERA ETAPA OBLIGATORIA: AUDIT DEL PROYECTO

## IMPORTANTE

**NO comenzar modificando código.**

Antes de realizar cualquier cambio se debe realizar un **AUDIT COMPLETO DEL REPOSITORIO**.

La primera tarea consiste exclusivamente en analizar el proyecto actual.

Se debe investigar:

### Arquitectura

- Estructura de directorios
- Lenguajes utilizados
- Frameworks
- Dependencias
- Servicios
- Scripts
- Configuraciones
- Docker
- Systemd
- Instaladores
- Configuración de red
- Manejo de GPIO
- Manejo del módem EC25
- APIs existentes
- Frontend existente
- Base de datos existente

### Código

Identificar:

- Código reutilizable
- Código obsoleto
- Código acoplado
- Código que debe migrarse
- Código que debe eliminarse
- Código peligroso
- Código duplicado
- Deuda técnica

### Basic Station

Buscar específicamente:

- Commits relacionados con Basic Station
- Docker Compose anterior
- Dockerfile
- Scripts
- Configuración
- Variables de entorno
- Volúmenes
- Network configuration
- Logs
- Configuración de gateway
- Integración con TTN/LoRaWAN

Determinar exactamente cómo funcionaba la implementación anterior y qué partes deben conservarse.

### Networking

Analizar cómo se gestionaba actualmente:

- EC25
- LTE
- WiFi
- Ethernet
- IP
- Routing
- DNS
- NetworkManager
- ModemManager
- systemd-networkd
- otros componentes

No asumir que alguno de estos componentes existe. Verificarlo en el proyecto.

---

# 2. RESULTADO DEL AUDIT

Antes de escribir código se debe entregar un documento:

`docs/AUDIT.md`

Debe contener:

## 2.1 Arquitectura actual

Descripción de cómo funciona actualmente el sistema.

## 2.2 Componentes existentes

Tabla:

| Componente | Tecnología | Estado | Reutilizable |
|---|---|---|---|

## 2.3 Dependencias

Identificar dependencias que:

- Se mantienen
- Se reemplazan
- Se eliminan

## 2.4 Funcionalidades actuales

Identificar qué hace actualmente el sistema.

## 2.5 Riesgos

Identificar riesgos técnicos.

## 2.6 Deuda técnica

Identificar deuda técnica.

## 2.7 Basic Station

Documentar exactamente cómo está implementado.

## 2.8 Propuesta de migración

Explicar cómo pasar de la arquitectura actual a la nueva.

---

# 3. DECISIÓN MIGRAR VS REESCRIBIR

Después del audit, determinar si conviene:

### Opción A — Migración

Reutilizar el código existente.

### Opción B — Reescritura

Eliminar la implementación anterior y crear una arquitectura completamente nueva.

La IA debe recomendar una de las dos opciones explicando:

- Ventajas
- Desventajas
- Riesgo
- Tiempo estimado relativo
- Código reutilizable
- Complejidad

---

# 4. MODO "START FROM SCRATCH"

Debe existir explícitamente la posibilidad de:

> **Desechar completamente el proyecto de software anterior y comenzar desde cero.**

Esto significa:

- Nueva estructura
- Nuevo backend
- Nuevo frontend
- Nueva API
- Nueva arquitectura
- Nueva base de datos
- Nuevos servicios

Pero se debe conservar únicamente la información técnica que sea necesaria para soportar el hardware y Basic Station.

Antes de eliminar código existente:

1. Crear backup.
2. Crear branch/tag de referencia.
3. Documentar qué se elimina.
4. Documentar por qué se elimina.

Nunca borrar permanentemente código histórico sin dejar una referencia recuperable.

---

# 5. OBJETIVO FINAL

La Raspberry Pi 4 será un:

# Network & LoRaWAN Gateway Management System

Debe administrar múltiples tecnologías de conectividad y un Gateway LoRaWAN basado en Basic Station.

---

# 6. STACK TECNOLÓGICO

## Frontend

- React
- Vite
- TypeScript
- React Router
- Diseño responsive
- REST API

## Backend

- Python
- FastAPI
- Uvicorn
- Pydantic
- SQLAlchemy
- SQLite

## Infraestructura

- Raspberry Pi OS / Linux compatible
- Docker
- Docker Compose
- LoRaWAN Basic Station

No agregar tecnologías innecesarias.

Si se propone introducir una tecnología adicional, justificarla.

---

# 7. ARQUITECTURA

La arquitectura debe seguir una separación clara:

Frontend
↓
REST API
↓
Service Layer
↓
System/Hardware Layer
↓
Linux / Docker / Network / GPIO

No colocar lógica de sistema operativo directamente en las rutas FastAPI.

Ejemplo:

API
→ NetworkService
→ NetworkManagerAdapter

API
→ DockerService
→ DockerAdapter

API
→ GPIOService
→ GPIOAdapter

API
→ ModemService
→ ModemAdapter

La aplicación debe utilizar interfaces/adapters para poder utilizar mocks durante desarrollo y testing.

---

# 8. NETWORK MANAGER

Administrar:

- Ethernet
- WiFi
- 4G/LTE

Mostrar:

- Estado
- IP
- MAC
- Gateway
- DNS
- Interface
- Latencia
- Packet loss
- Velocidad
- Tiempo conectado

---

# 9. WIFI

Permitir:

- Scan
- Selección de SSID
- Password
- Conexión
- Desconexión
- Reconexión
- Estado

Mostrar:

- SSID
- RSSI
- dBm
- Canal
- Seguridad

Clasificar RSSI:

- Excelente
- Muy buena
- Buena
- Regular
- Mala

---

# 10. ACCESS POINT

La Raspberry Pi debe tener un modo AP para configuración.

## First Boot

Si el dispositivo no está configurado:

1. Activar AP.
2. Iniciar backend.
3. Iniciar frontend.
4. Mostrar configuración inicial.
5. Permitir configurar red.
6. Validar Internet.
7. Guardar configuración.
8. Desactivar AP.
9. Pasar a modo normal.

---

# 11. BOTÓN AP / GPIO

Existirá un botón físico mediante GPIO Pull-Up.

Estado:

HIGH = normal

LOW = solicitar AP

Durante desarrollo debe existir una simulación:

`POST /api/ap/enable`

Posteriormente se podrá conectar al GPIO real sin modificar la arquitectura.

---

# 12. NETWORK FAILOVER

Implementar una arquitectura preparada para failover automático.

Prioridad configurable:

1. Ethernet
2. WiFi
3. 4G

Ejemplo:

Ethernet ONLINE

↓ falla

WiFi ONLINE

↓ falla

4G ONLINE

El sistema debe detectar pérdida real de conectividad y no solamente pérdida de link.

Mostrar en dashboard:

`Internet ONLINE — Ethernet`

o:

`Internet ONLINE — WiFi — Failover`

o:

`Internet ONLINE — 4G — Failover activo`

Registrar:

- Cambio de interfaz
- Motivo
- Timestamp
- Interfaz anterior
- Nueva interfaz

Permitir configurar prioridades.

---

# 13. MÉTRICAS

Dashboard con:

- CPU
- RAM
- Temperatura
- Storage
- Uptime
- Network status
- Latencia
- Packet loss
- Jitter
- DNS latency

## Internet Speed Test

Mostrar:

- Download
- Upload
- Ping
- Server
- Timestamp

Debe ejecutarse de forma asíncrona.

No bloquear FastAPI.

---

# 14. NETWORK USAGE

Registrar:

- Upload
- Download
- Total

Períodos:

- 24 horas
- 7 días
- 30 días

Mostrar gráficos.

Implementar retención de datos para evitar crecimiento indefinido de SQLite.

---

# 15. LTE

Cuando el módem lo permita mostrar:

- IMEI
- ICCID
- Operator
- RSSI
- RSRP
- RSRQ
- SINR
- Band
- Technology
- Signal quality
- Registration state

Nunca asumir que todos estos datos están disponibles.

---

# 16. LORAWAN BASIC STATION

Utilizar Docker para ejecutar Basic Station.

Debe ser administrable desde la plataforma.

Permitir:

- Start
- Stop
- Restart
- Status
- Logs
- Uptime
- Container info
- Health

---

# 17. BASIC STATION WATCHDOG

Implementar watchdog.

Si Basic Station falla:

1. Detectar.
2. Registrar.
3. Intentar restart.
4. Verificar.
5. Registrar resultado.

Configurar:

- Máximo de intentos
- Delay
- Cooldown

Evitar loops infinitos de restart.

---

# 18. DOCKER COMPOSE EDITOR

Solo admin.

Permitir:

- Ver compose
- Editar
- Validar
- Backup
- Aplicar
- Restart

Proceso:

`current config`

↓

`backup`

↓

`validate`

↓

`apply`

↓

`restart`

↓

`health check`

Si falla:

`rollback`

La aplicación debe evitar ejecución arbitraria mediante el editor.

Definir claramente qué propiedades pueden modificarse.

---

# 19. GATEWAY HARDWARE

Mostrar:

- Chip ID
- Device ID
- MAC
- Serial
- Board
- Hardware revision
- Firmware

Crear `HardwareService`.

---

# 20. SSH

Admin únicamente.

Permitir:

- Estado
- Enable
- Disable

Verificar el estado real del servicio.

Registrar todas las acciones.

---

# 21. USUARIOS

Roles:

- admin
- user

Admin:

- Users
- Docker
- SSH
- Compose
- Backup
- Factory reset
- System settings

User:

- Dashboard
- Network
- Metrics
- Basic Station status

Implementar autenticación segura.

Passwords con hashing.

Nunca almacenar passwords en texto plano.

---

# 22. AUDIT LOG

Registrar acciones importantes:

- Login
- Logout
- Network changes
- WiFi connection
- Docker start/stop/restart
- Compose changes
- SSH enable/disable
- Factory reset
- Backup
- Restore
- User creation/deletion
- Configuration changes
- Failover

Campos:

- user
- action
- timestamp
- source IP
- result
- metadata

---

# 23. SYSTEM LOGS

Crear visor de logs.

Categorías:

- Application
- Network
- Docker
- Basic Station
- System

No permitir acceso arbitrario al filesystem.

---

# 24. BACKUP / RESTORE

Admin.

Permitir:

- Crear backup
- Descargar
- Restaurar

Backup debe contener:

- SQLite
- Configuration
- Docker configuration
- Application settings

No incluir secretos sin protección.

Antes de restore:

1. Backup actual.
2. Validación.
3. Restore.
4. Restart.
5. Health check.

---

# 25. FACTORY RESET

Implementar:

## Configuration Reset

Eliminar:

- Configuración
- Usuarios
- WiFi
- Históricos

## Full Application Reset

Restablecer toda la aplicación a estado inicial.

No destruir el sistema operativo.

Proceso:

1. Confirmación.
2. Backup.
3. Reset.
4. Restart.
5. AP mode.
6. First Boot wizard.

---

# 26. OTA / REMOTE UPDATE

La arquitectura debe quedar preparada para actualizaciones remotas.

Posteriormente permitir:

- Firmware update
- Application update
- Docker image update
- Configuration update

Debe existir:

- Version actual
- Build
- Commit
- Update status

No necesariamente implementar OTA completo en la primera versión.

Pero dejar la arquitectura preparada.

---

# 27. HEALTH CHECK

Crear:

`GET /api/system/health`

Debe verificar:

- FastAPI
- SQLite
- Docker
- Network
- Internet
- Basic Station
- Storage
- System resources

Ejemplo:

```json
{
  "status": "healthy",
  "services": {
    "database": "ok",
    "docker": "ok",
    "network": "ok",
    "basic_station": "ok"
  }
}
```

---

# 28. API

Organizar APIs por dominio.

Ejemplo:

`/api/auth`

`/api/network`

`/api/wifi`

`/api/lte`

`/api/ap`

`/api/metrics`

`/api/docker`

`/api/lorawan`

`/api/gateway`

`/api/system`

`/api/admin`

No crear un único router gigante.

Documentar automáticamente mediante OpenAPI.

---

# 29. FRONTEND

Crear:

### Login

### Dashboard

### Network

### WiFi

### LTE

### Metrics

### LoRaWAN

### Gateway

### Administration

### Logs

### Backup

### System

### Factory Reset

La navegación debe depender del rol.

---

# 30. UX

El sistema será utilizado para administrar hardware real.

Por lo tanto:

- Mostrar estados claramente.
- Mostrar loading states.
- Mostrar errores útiles.
- Confirmar operaciones destructivas.
- Evitar acciones duplicadas.
- Mostrar progreso en operaciones largas.
- Mostrar cuándo una acción está en proceso.
- No congelar la interfaz.

---

# 31. SEGURIDAD

Este punto es crítico.

El backend tiene capacidad para ejecutar operaciones sobre Linux y Docker.

Nunca permitir:

- Command injection
- Arbitrary shell execution
- Path traversal
- Arbitrary Docker commands
- Arbitrary file access

Evitar:

`shell=True`

cuando no sea estrictamente necesario.

Validar inputs.

Aplicar autorización también en backend.

El frontend NO es una capa de seguridad.

---

# 32. TESTING

Implementar tests para:

- Auth
- Permissions
- Network
- WiFi
- LTE
- Docker
- Basic Station
- Failover
- Metrics
- Factory reset
- Backup
- Restore
- SSH
- Hardware

Utilizar mocks para:

- GPIO
- Network
- Modem
- Docker
- systemctl

Los tests deben poder ejecutarse sin Raspberry Pi física.

---

# 33. DOCUMENTACIÓN

**Documentar absolutamente todas las partes importantes del proyecto.**

Crear:

`docs/`

con:

- ARCHITECTURE.md
- API.md
- NETWORK.md
- WIFI.md
- LTE.md
- AP_MODE.md
- FAILOVER.md
- LORAWAN.md
- BASIC_STATION.md
- DOCKER.md
- SECURITY.md
- AUTHENTICATION.md
- DATABASE.md
- METRICS.md
- BACKUP_RESTORE.md
- FACTORY_RESET.md
- HARDWARE.md
- GPIO.md
- DEPLOYMENT.md
- DEVELOPMENT.md
- TESTING.md
- TROUBLESHOOTING.md
- OTA.md
- AUDIT.md

Además:

`README.md`

debe explicar:

- Qué es el proyecto.
- Arquitectura.
- Instalación.
- Desarrollo.
- Deployment.
- Configuración.
- Troubleshooting.

---

# 34. ADR — ARCHITECTURE DECISION RECORDS

Para decisiones arquitectónicas importantes crear:

`docs/adr/`

Ejemplos:

- ADR-001 — FastAPI
- ADR-002 — SQLite
- ADR-003 — React/Vite
- ADR-004 — Network abstraction
- ADR-005 — Docker integration
- ADR-006 — Failover architecture
- ADR-007 — Authentication
- ADR-008 — Factory reset
- ADR-009 — Metrics storage

Cada ADR debe explicar:

- Contexto
- Problema
- Decisión
- Alternativas
- Consecuencias

---

# 35. CHANGELOG

Mantener:

`CHANGELOG.md`

Registrar:

- Features
- Fixes
- Breaking changes
- Architecture changes
- Security changes

Utilizar versionado semántico cuando corresponda.

---

# 36. DEVELOPMENT MODE

El sistema debe poder ejecutarse en un PC de desarrollo sin Raspberry Pi.

Crear mocks/simulators para:

- GPIO
- WiFi
- Ethernet
- LTE
- Docker
- Hardware ID

Ejemplo:

`APP_ENV=development`

Esto permitirá desarrollar el frontend y backend sin hardware.

---

# 37. PRODUCCIÓN

En Raspberry Pi:

- Servicios systemd cuando corresponda.
- Docker.
- Logs.
- Restart policies.
- Health checks.
- Watchdog.
- Persistencia.
- Backup.

La aplicación debe poder recuperarse después de un reboot.

---

# 38. ESTRUCTURA DE IMPLEMENTACIÓN

Antes de cada fase:

1. Explicar qué se va a modificar.
2. Indicar archivos afectados.
3. Explicar riesgos.
4. Implementar.
5. Ejecutar tests.
6. Documentar.
7. Mostrar resultado.

No hacer grandes cambios sin validar cada etapa.

---

# 39. ORDEN DE IMPLEMENTACIÓN

### FASE 0
AUDIT

### FASE 1
Arquitectura definitiva

### FASE 2
Decisión migration vs rewrite

### FASE 3
Nueva estructura del proyecto

### FASE 4
FastAPI

### FASE 5
SQLite + Auth

### FASE 6
Network abstraction

### FASE 7
WiFi

### FASE 8
Ethernet

### FASE 9
LTE

### FASE 10
AP Mode

### FASE 11
Failover

### FASE 12
Metrics

### FASE 13
Docker

### FASE 14
Basic Station

### FASE 15
Watchdog

### FASE 16
Gateway Hardware

### FASE 17
SSH

### FASE 18
Backup/Restore

### FASE 19
Factory Reset

### FASE 20
React/Vite

### FASE 21
Admin Panel

### FASE 22
Audit Logs

### FASE 23
Testing

### FASE 24
Security Hardening

### FASE 25
Deployment

### FASE 26
Documentación final

---

# 40. CRITERIOS DE CALIDAD

El resultado debe cumplir:

- Código modular.
- Código mantenible.
- Type hints.
- Validación de datos.
- Manejo correcto de errores.
- Logging.
- Testing.
- Documentación.
- Seguridad.
- Compatibilidad Raspberry Pi.
- Capacidad de recuperación.
- Separación de responsabilidades.

No crear soluciones rápidas o hacks si existe una solución arquitectónicamente correcta.

---

# 41. CRITERIO FUNDAMENTAL

Este proyecto debe parecer un **producto real**, no un proyecto experimental.

Debe ser posible imaginar que la Raspberry Pi será instalada en:

- Un gateway LoRaWAN.
- Una instalación industrial.
- Un invernadero.
- Una estación remota.
- Un sitio donde el acceso físico sea limitado.

Por lo tanto, se debe asumir:

- Pérdida de conectividad.
- Reinicios.
- Fallos de Docker.
- Fallos de WiFi.
- Pérdida de 4G.
- Corrupción de configuración.
- Errores humanos.
- Necesidad de recuperación remota.

Diseñar teniendo estos escenarios en cuenta.

---

# 42. REGLA FINAL

**No comenzar implementando.**

Primero realizar:

`AUDIT → PROPUESTA → DECISIÓN MIGRATE/REWRITE → ARQUITECTURA → PLAN → IMPLEMENTACIÓN`

El primer entregable obligatorio debe ser:

`docs/AUDIT.md`

junto con una propuesta arquitectónica.

Después del audit, esperar aprobación antes de realizar cambios estructurales importantes.

Toda modificación debe quedar documentada.

Toda decisión arquitectónica importante debe quedar registrada.

Toda funcionalidad importante debe tener tests.

Toda funcionalidad relevante debe tener documentación.

El objetivo final es construir una plataforma robusta de gestión de conectividad, infraestructura y LoRaWAN sobre Raspberry Pi.