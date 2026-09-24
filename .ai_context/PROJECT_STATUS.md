# PROJECT_STATUS — instalador-oracle23ai-ubuntu

_Última actualización: 2026-09-24_

## Objetivo
Herramienta (`oracle23ai.sh`, bash) para compartir en clase que instala y deja lista
Oracle Database 23ai Free en Ubuntu 24.04 con Docker Desktop, preguntando los datos
necesarios en un asistente (whiptail, con modo texto alternativo).

## Estado funcional por módulo

| Módulo | Estado | Verificación |
|---|---|---|
| Asistente whiptail (80x24) | ✅ | Recorrido completo por PTY en modo `--simular` |
| Asistente modo texto (`--sin-tui`) | ✅ | Instalación real con respuestas por stdin |
| Comprobaciones previas / `comprobar` | ✅ | Real |
| Detección de red que bloquea Oracle Cloud Storage | ✅ | Real (DNS sinkhole) → propone Docker Hub (gvenzl) |
| Docker Desktop: repo apt, GPG (huella), .deb (SHA-256), KVM, arranque, memoria | ⚠️ | Solo simulación: no se instaló Docker Desktop en el equipo de pruebas |
| Docker Engine (alternativa sin KVM) | ✅ | Real (ya instalado en el equipo de pruebas) |
| Contenedor + volumen + espera «DATABASE IS READY TO USE!» | ✅ | Real con `gvenzl/oracle-free:23.9` (lista en ~1 min) |
| Contraseñas SYS/SYSTEM/PDBADMIN por SQL (stdin) | ✅ | Real; sin fugas en logs/config/`docker inspect` |
| Usuario de trabajo (DB_DEVELOPER_ROLE, perfil sin caducidad) | ✅ | Real: CREATE TABLE/INSERT/SELECT |
| Reinstalar conservando contenedor existente | ✅ | Real (lee puerto/volumen del contenedor) |
| `estado`, `iniciar`, `parar`, `sql`, `sysdba`, `password`, `crear-usuario`, `desinstalar` | ✅ | Real |
| Imagen oficial `container-registry.oracle.com/database/free` | ⚠️ | No descargable en la red de pruebas (bloqueo); lógica compartida con gvenzl |
| SQLcl / SQL Developer (opcionales) | ⚠️ | Solo simulación (URLs verificadas con HEAD) |

## Publicación
- Repositorio: https://github.com/Piratapacorro/instalador-oracle23ai-ubuntu (público, rama `main`).
- CI «Comprobaciones» (bash -n, ShellCheck --severity=warning, ayuda, comprobar): ✅ en verde.

## Riesgos conocidos / pendientes
- Probar en un Ubuntu 24.04 limpio con Docker Desktop real (aceptación del acuerdo, memoria de la VM).
- Probar la imagen oficial de Oracle en una red sin bloqueo.
- SQL Developer: confirmar que `SetJavaHome` en `sqldeveloper.conf` evita la pregunta del JDK.
