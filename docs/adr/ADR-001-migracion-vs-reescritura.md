# ADR-001 — Migración vs Reescritura

- **Estado:** Aceptado
- **Fecha:** 2026-08-11
- **Decisión:** Migración progresiva (no rewrite)

## Contexto

El proyecto RPI_Router_4G es un panel de administración para Raspberry Pi 4 con módem EC25 4G LTE, construido con Flask + Jinja2 + Vanilla JS (~3,500 líneas Python, 17 scripts bash).

El plan maestro requiere transformarlo en una plataforma completa con FastAPI + React + SQLite + Docker + LoRaWAN Basic Station.

## Decisión

**Migración progresiva**, no reescritura total.

Se construirá el nuevo stack (`backend/` con FastAPI) junto al código legacy existente. Los módulos de alta calidad (`modem.py`, `ec25_monitor.py`) se migrarán con adaptaciones mínimas. Los scripts bash probados en producción se mantienen sin cambios.

## Alternativas consideradas

### Reescritura total
- **Ventajas:** Código limpio sin deuda técnica, arquitectura coherente desde el inicio.
- **Desventajas:** Alto riesgo de perder conocimiento empírico (AT commands, iptables, network quirks). Tiempo 2-3x mayor.
- **Rechazada:** El código existente contiene módulos de excelente calidad que no justifican ser reescritos.

### Mantener Flask y agregar React
- **Ventajas:** Menor esfuerzo inicial.
- **Desventajas:** Flask no tiene async nativo, validación, ni OpenAPI automático. No escala bien para la complejidad planeada.
- **Rechazada:** No cumple los requisitos de arquitectura del plan.

## Consecuencias

- **Positivas:** Menor riesgo, reutilización de código probado, despliegue progresivo, el sistema legacy sigue operativo.
- **Negativas:** Convivirán dos stacks temporalmente (Flask legacy + FastAPI nuevo). El módem monitor y los AT commands migrados pueden arrastrar deuda técnica menor.
- **Mitigación:** Una vez que el backend FastAPI esté completo y probado, se desmantelará el código Flask legacy.
