# CHANGELOG_AGENTS

## 2026-09-24 — Creación de la herramienta (Claude Code)

### Investigación
- Documentación oficial de Docker Desktop para Ubuntu (requisitos, KVM, .deb, `checksums.txt`, contextos).
- Registro de Oracle (API v2): etiquetas `23.9.0.0` (última «23ai»), `23.26.x`/`latest` («26ai»), variantes `-lite`.
- Docker Hub `gvenzl/oracle-free`: `23.9`, `23.9-full`, `23` (26ai); variables `ORACLE_RANDOM_PASSWORD`, etc.
- Enlaces de descarga sin login: `sqlcl-latest.zip`, `sqldeveloper-24.3.1.347.1826-no-jre.zip` (HEAD 200).

### Archivos creados
- `oracle23ai.sh` — instalador + gestor (asistente, estado, iniciar, parar, sql, sysdba, sqlcl, info,
  password, crear-usuario, logs, comprobar, desinstalar; `--simular`, `--sin-tui`).
- `README.md`, `docs/PASOS_MANUALES.md`, `docs/SOLUCION_DE_PROBLEMAS.md`.
- `.github/workflows/comprobaciones.yml` (bash -n, ShellCheck, ayuda, comprobar).
- `.gitignore`, `LICENSE` (MIT), `.ai_context/*`.

### Pruebas ejecutadas (equipo de pruebas con Docker Engine)
- `bash -n`; simulación completa (camino Docker Desktop) en modo texto y en whiptail vía PTY 80x24.
- Instalación real (Docker Engine + `gvenzl/oracle-free:23.9`, puerto 15210, HOME temporal).
- Reinstalación conservando el contenedor; cambio de contraseñas; creación de usuario adicional.
- Ciclo `parar` → `estado` → `iniciar` → `comprobar` → `desinstalar` (contenedor, volumen, imagen, comando).
- Auditoría de secretos: 0 apariciones de contraseñas en registros, configuración y `docker inspect`.
- Limpieza final: 0 imágenes, 0 contenedores, 0 volúmenes de prueba.

### Fallos encontrados y corregidos durante las pruebas
- `whiptail --scrolltext` impide cerrar con Enter → eliminado; ventanas dimensionadas para 80x24.
- Reinstalación «conservar contenedor» mostraba el puerto por defecto → ahora se lee del contenedor.
- `oracle23ai sql` sin terminal no podía pedir la contraseña → modo `/nolog` (entrada con `CONNECT`).
- Textos de preguntas en modo texto con «::» duplicados → formato de pregunta unificado.

### Publicación y CI
- `gh repo create instalador-oracle23ai-ubuntu --public --source . --push` (commit 40481a0).
- CI detectó 6 avisos de ShellCheck (SC2194, SC2155, SC2174, SC2178/SC2128, SC2034) → corregidos en a1a1aa4; CI en verde.
- Eliminadas funciones sin uso (`in_group_now`, `desktop_capable`).

## 2026-10-01 — Interfaz gráfica (v1.1.0) e instalación real de 26ai

### Cambios
- Capa de interfaz con tres modos: `gui` (zenity, por defecto con escritorio), `tui` (whiptail), `texto`.
- Asistente gráfico (`wizard_gui`): opciones en una lista y contraseñas en un formulario.
- Ventana de progreso alimentada por un FIFO (pasos, partes descargadas, espera de Oracle).
- `sudo -A` con SUDO_ASKPASS (zenity) en modo gráfico; todos los `sudo` pasan por `"${SUDO[@]}"`.
- Panel gráfico de uso diario + acceso `~/.local/share/applications/oracle23ai.desktop` con icono SVG propio.
- Opción `--oracle 23ai|26ai`.
- `tests/zenity-falso` + `tests/prueba-gui.sh` (24 comprobaciones) añadidos a la CI; `df` falso en la prueba
  porque el runner de GitHub tenía 13 GB libres (el instalador exige 15).

### Prueba real en el equipo del usuario (con su intervención: asistente, sudo y acuerdo de Docker)
- Docker Desktop 4.93.0 instalado desde cero (SHA-256 verificado), VM con 5,6 GB.
- La red bloqueó Oracle Cloud Storage → se usó `gvenzl/oracle-free:23` (26ai 23.26.3); base lista en 17 s.
- Verificado: banner 26ai, FREEPDB1 READ WRITE, ALUMNO OPEN con DB_DEVELOPER_ROLE y perfil sin caducidad,
  puerto 127.0.0.1:1521, sin contraseñas en `docker inspect`, `.desktop` válido.

## 2026-10-01 — v2.0.0: instalador genérico de Oracle Database (cualquier versión)

### Cambios
- `oracle23ai.sh` → `oracle-db.sh` (git mv); comando `oracle-db`; rutas `~/.config|state|share/oracle-db`;
  acceso del menú «Oracle Database (Docker)» (`oracle-db.desktop`); repositorio renombrado a
  `instalador-oracle-db-ubuntu`.
- Catálogo `VERSION_LIST` + `IMAGE_CATALOG` (26ai, 23ai, 21c/18c/11g XE, 19c/21c EE/SE2) y `REPO_LIST`
  para «Otra versión» (etiquetas en vivo con `list_tags`, Python/urllib).
- `image_profile`: deduce de la imagen familia, servicios (FREEPDB1/XEPDB1/XE/ORCLPDB1), ruta de datos,
  estilo de contraseña, DB_DEVELOPER_ROLE, cuenta necesaria, tiempo de creación y memoria mínima.
- SQL por versión: sin PDB en 11g; permisos clásicos sin DB_DEVELOPER_ROLE; tablespace USERS si existe.
- Enterprise/Standard: `docker login --password-stdin` con DOCKER_CONFIG temporal (credenciales borradas tras el pull).
- Nombre de contenedor por versión (`oracle-26ai`, `oracle-21c-xe`…) y siguiente puerto libre si 1521 está ocupado.
- `migrate_legacy` + `after_migration`: pasa instalaciones v1.x a los nombres nuevos.
- Comando `versiones`; opción `--oracle` admite 26ai, 23ai, 21c, 18c, 11g, 19c, 21c-ee.

### Pruebas
- Simulación de las 7 versiones (modo texto) y de «Otra versión» con etiquetas reales de Docker Hub.
- 40 comprobaciones del modo gráfico con zenity falso; recorrido whiptail por PTY (19 ventanas, OK).
- Real con Docker Engine (HOME temporal, puertos 15211/15212): 11g XE y 21c XE → contraseñas, usuario,
  permisos, CRUD, crear-usuario, password, desinstalar. Limpieza: 0 imágenes/contenedores/volúmenes.
- Fallo encontrado en real y corregido: en 11g el usuario quedaba en el tablespace SYSTEM.
- Migración real en el equipo del usuario: `oracle-db estado` gestiona su contenedor `oracle26ai`.

## 2026-10-01 — Verificación tras publicar v2.0.0

### Comandos
- `gh run list` / `gh run view` → CI «Comprobaciones» en verde para `b555eb6` (todos los pasos).
- `curl -sI` a la web, al nombre antiguo y a `raw.githubusercontent.com` → 404 en los tres.
- `gh repo view --json visibility` → **PRIVATE**. El registro de la sesión confirma que el repositorio se creó con
  `--public` y que `gh repo rename` / `gh repo edit --description --add-topic` no tocan la visibilidad: el cambio
  se hizo fuera del agente. No se ha revertido (requiere permiso explícito del usuario).
- Comprobado el PC del usuario: `oracle-db 2.0.0`, comando antiguo eliminado, `oracle26ai` en marcha
  (127.0.0.1:1521), Docker Engine sin contenedores ni volúmenes.

### Archivos modificados
- `.ai_context/SESSION_HANDOFF.json` — rutas reales (`~/.config/oracle-db`, `~/.local/state/oracle-db`),
  visibilidad y CI del último commit.
- `.ai_context/PROJECT_STATUS.md` — visibilidad privada, CI verde, pendiente de decisión.
- `.ai_context/CHANGELOG_AGENTS.md` — esta entrada.
