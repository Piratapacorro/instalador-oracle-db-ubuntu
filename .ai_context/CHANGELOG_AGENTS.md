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
