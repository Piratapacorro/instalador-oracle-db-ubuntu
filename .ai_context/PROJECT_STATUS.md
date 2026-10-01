# PROJECT_STATUS — instalador-oracle-db-ubuntu

_Última actualización: 2026-10-01 (v2.0.0: instalador genérico de Oracle Database)_

## Objetivo
Herramienta (`oracle-db.sh`, bash) para compartir en clase que instala y deja lista **cualquier versión**
de Oracle Database en Ubuntu 24.04 con Docker Desktop: 26ai y 23ai Free, 21c/18c/11g XE, 19c/21c
Enterprise/Standard, o cualquier etiqueta de los repositorios oficiales o de gvenzl. Pregunta los datos
en un asistente (zenity por defecto; whiptail con `--tui`; texto con `--texto`).

## Estado funcional por módulo

| Módulo | Estado | Verificación |
|---|---|---|
| Interfaz gráfica zenity (asistente, progreso, panel, menú) | ✅ | Real (26ai, 2026-10-01) + 40 comprobaciones con zenity falso (también en CI) |
| Asistente whiptail (`--tui`, 80x24) | ✅ | Recorrido completo por PTY con el flujo versión → imagen |
| Asistente en texto (`--texto`) | ✅ | Instalaciones reales con respuestas por stdin |
| Catálogo de versiones + perfiles por imagen (servicio, ruta, rol, memoria) | ✅ | Simulación de las 7 versiones; perfiles comprobados imagen a imagen |
| «Otra versión»: etiquetas en vivo (registro de Oracle y Docker Hub) | ✅ | Real (42 etiquetas de gvenzl/oracle-xe) |
| Detección de red que bloquea Oracle Cloud Storage | ✅ | Real (DNS sinkhole) → propone Docker Hub (gvenzl) |
| Docker Desktop (repo, SHA-256, KVM, arranque, memoria) | ✅ | Real (Docker Desktop 4.93.0) |
| Docker Engine (alternativa sin KVM) | ✅ | Real |
| 26ai (gvenzl/oracle-free:23) | ✅ | Real: contenedor `oracle26ai` del usuario (Docker Desktop) |
| 11g XE (sin PDB, /u01/app/oracle/oradata, shm 1g) | ✅ | Real con Docker Engine: usuario, permisos, CRUD, password, crear-usuario, desinstalar |
| 21c XE (XEPDB1, permisos clásicos) | ✅ | Real con Docker Engine: ídem |
| Contraseñas por SQL (stdin) sin fugas | ✅ | Real; nada en registros, config ni `docker inspect` |
| Migración automática desde v1.x (`oracle23ai`) | ✅ | Real en el equipo del usuario (rutas, comando, acceso del menú) |
| Imagen oficial `container-registry.oracle.com` | ⚠️ | No descargable en la red de pruebas (bloqueo DNS); fallback a Docker Hub probado |
| Enterprise/Standard 19c/21c (login temporal con Auth Token) | ⚠️ | Solo simulación: requiere cuenta de Oracle y red sin bloqueo |
| 18c XE | ⚠️ | Solo simulación (misma familia que 21c XE) |
| SQLcl / SQL Developer (opcionales) | ⚠️ | Solo simulación (URLs verificadas con HEAD) |

## Publicación
- Repositorio: https://github.com/Piratapacorro/instalador-oracle-db-ubuntu (antes instalador-oracle23ai-ubuntu; GitHub redirige).
- CI «Comprobaciones»: bash -n, ShellCheck (warning), prueba gráfica con zenity falso, ayuda, comprobar.

## Riesgos conocidos / pendientes
- Probar Enterprise/Standard con una cuenta de Oracle real (y una red sin bloqueo).
- Probar la imagen oficial de Oracle en una red sin bloqueo.
- SQL Developer: confirmar que `SetJavaHome` en `sqldeveloper.conf` evita la pregunta del JDK.
