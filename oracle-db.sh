#!/usr/bin/env bash
# =============================================================================
#  oracle-db.sh — Instalador y gestor de Oracle Database con Docker
#  para Ubuntu 24.04 LTS (Docker Desktop, o Docker Engine si no hay KVM).
#
#  Versiones: 26ai y 23ai Free; 21c, 18c y 11g Express Edition (XE);
#  19c y 21c Enterprise/Standard Edition; o cualquier otra etiqueta disponible.
#
#  Uso:
#     ./oracle-db.sh                        Panel (ventanas gráficas si hay escritorio)
#     ./oracle-db.sh instalar               Asistente de instalación
#     ./oracle-db.sh --oracle 21c instalar  Propone directamente una versión
#     ./oracle-db.sh --tui instalar         El asistente en ventanas de terminal
#     ./oracle-db.sh ayuda                  Lista de comandos
#
#  Tras instalar quedan el comando «oracle-db» (en ~/.local/bin) y el acceso
#  «Oracle Database (Docker)» en el menú de aplicaciones.
#  Licencia: MIT
# =============================================================================
set -Eeuo pipefail

readonly APP_VERSION="2.0.0"
readonly APP_CMD="oracle-db"
readonly APP_NAME="Instalador de Oracle Database"
readonly LEGACY_CMD="oracle23ai"        # nombre de las versiones 1.x (se migra solo)

# --- Rutas (estándar XDG) ------------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP_CMD"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_CMD"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_CMD"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BIN_DIR="$HOME/.local/bin"
CONFIG_FILE="$CONFIG_DIR/config"
INFO_FILE="$CONFIG_DIR/conexion.txt"

# --- Descargas oficiales -------------------------------------------------------
readonly DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
readonly DOCKER_GPG_URL="$DOCKER_REPO_URL/gpg"
readonly DOCKER_GPG_FPR="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
readonly DD_DEB_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
readonly DD_SUMS_URL="https://desktop.docker.com/linux/main/amd64/checksums.txt"
readonly SQLCL_URL="https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip"
readonly SQLDEV_URL="https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-24.3.1.347.1826-no-jre.zip"
readonly ORACLE_REGISTRY="container-registry.oracle.com"
# Las capas de las imágenes oficiales se sirven desde Oracle Cloud Object Storage.
# Algunas redes (por ejemplo, las de algunos centros educativos) lo bloquean.
readonly OCI_STORAGE_HOST="objectstorage.us-phoenix-1.oraclecloud.com"

# --- Requisitos ----------------------------------------------------------------
readonly RAM_MIN_MB=3500 RAM_REC_MB=7000
readonly DISK_MIN_GB=15 DISK_REC_GB=25
readonly PROFILE_NAME="PERFIL_PRACTICAS"

# --- Versiones que ofrece el asistente: clave|descripción ----------------------
readonly VERSION_LIST=(
  "26ai|Oracle AI Database 26ai Free · la más reciente (23.26.x) · recomendada"
  "23ai|Oracle Database 23ai Free (23.9)"
  "21c-xe|Oracle Database 21c Express Edition (XE)"
  "18c-xe|Oracle Database 18c Express Edition (XE)"
  "11g-xe|Oracle Database 11g Express Edition (XE) · antigua, sin PDB"
  "19c-ee|Oracle Database 19c Enterprise o Standard · requiere cuenta de Oracle"
  "21c-ee|Oracle Database 21c Enterprise o Standard · requiere cuenta de Oracle"
  "otra|Otra versión o actualización concreta (ver todas las disponibles)"
)

# --- Imágenes por versión: versión|clave|imagen|descripción|descarga aproximada -
readonly IMAGE_CATALOG=(
  "26ai|oficial-26ai|container-registry.oracle.com/database/free:latest|Oracle oficial · completa|3,5 GB"
  "26ai|oficial-26ai-lite|container-registry.oracle.com/database/free:latest-lite|Oracle oficial · lite (menos funciones)|0,9 GB"
  "26ai|hub-26ai|docker.io/gvenzl/oracle-free:23|Docker Hub (gvenzl)|1,1 GB"
  "26ai|hub-26ai-full|docker.io/gvenzl/oracle-free:23-full|Docker Hub (gvenzl) · full (todas las funciones)|2,1 GB"
  "26ai|hub-26ai-slim|docker.io/gvenzl/oracle-free:23-slim|Docker Hub (gvenzl) · slim (mínima)|0,8 GB"
  "23ai|oficial-23ai|container-registry.oracle.com/database/free:23.9.0.0|Oracle oficial · completa|3,4 GB"
  "23ai|oficial-23ai-lite|container-registry.oracle.com/database/free:23.9.0.0-lite|Oracle oficial · lite (menos funciones)|0,8 GB"
  "23ai|hub-23ai|docker.io/gvenzl/oracle-free:23.9|Docker Hub (gvenzl)|1 GB"
  "23ai|hub-23ai-full|docker.io/gvenzl/oracle-free:23.9-full|Docker Hub (gvenzl) · full (todas las funciones)|2 GB"
  "23ai|hub-23ai-slim|docker.io/gvenzl/oracle-free:23.9-slim|Docker Hub (gvenzl) · slim (mínima)|0,7 GB"
  "21c-xe|oficial-21c-xe|container-registry.oracle.com/database/express:21.3.0-xe|Oracle oficial|3,5 GB"
  "21c-xe|hub-21c-xe|docker.io/gvenzl/oracle-xe:21|Docker Hub (gvenzl)|1,4 GB"
  "21c-xe|hub-21c-xe-full|docker.io/gvenzl/oracle-xe:21-full|Docker Hub (gvenzl) · full (todas las funciones)|3,1 GB"
  "21c-xe|hub-21c-xe-slim|docker.io/gvenzl/oracle-xe:21-slim|Docker Hub (gvenzl) · slim (mínima)|0,7 GB"
  "18c-xe|oficial-18c-xe|container-registry.oracle.com/database/express:18.4.0-xe|Oracle oficial|2,9 GB"
  "18c-xe|hub-18c-xe|docker.io/gvenzl/oracle-xe:18|Docker Hub (gvenzl)|1,4 GB"
  "18c-xe|hub-18c-xe-full|docker.io/gvenzl/oracle-xe:18-full|Docker Hub (gvenzl) · full (todas las funciones)|3,3 GB"
  "18c-xe|hub-18c-xe-slim|docker.io/gvenzl/oracle-xe:18-slim|Docker Hub (gvenzl) · slim (mínima)|0,8 GB"
  "11g-xe|hub-11g-xe|docker.io/gvenzl/oracle-xe:11|Docker Hub (gvenzl)|0,3 GB"
  "11g-xe|hub-11g-xe-full|docker.io/gvenzl/oracle-xe:11-full|Docker Hub (gvenzl) · full (todas las funciones)|0,4 GB"
  "19c-ee|oficial-19c-ee|container-registry.oracle.com/database/enterprise:19.3.0.0|Oracle oficial · Enterprise Edition|unos 3 GB"
  "19c-ee|oficial-19c-se2|container-registry.oracle.com/database/enterprise:19.3.0.0|Oracle oficial · Standard Edition 2|unos 3 GB"
  "21c-ee|oficial-21c-ee|container-registry.oracle.com/database/enterprise:21.3.0.0|Oracle oficial · Enterprise Edition|unos 3,5 GB"
  "21c-ee|oficial-21c-se2|container-registry.oracle.com/database/enterprise:21.3.0.0|Oracle oficial · Standard Edition 2|unos 3,5 GB"
)

# --- Repositorios para «Otra versión»: clave|repositorio|descripción -----------
readonly REPO_LIST=(
  "free-oficial|container-registry.oracle.com/database/free|Oracle oficial · Free: 23ai y 26ai (todas las actualizaciones)"
  "xe-oficial|container-registry.oracle.com/database/express|Oracle oficial · Express Edition: 18c y 21c"
  "free-hub|docker.io/gvenzl/oracle-free|Docker Hub (gvenzl) · Free: 23ai y 26ai"
  "xe-hub|docker.io/gvenzl/oracle-xe|Docker Hub (gvenzl) · Express Edition: 11g, 18c y 21c"
  "ee-oficial|container-registry.oracle.com/database/enterprise|Oracle oficial · Enterprise y Standard (requiere cuenta de Oracle)"
  "manual|-|Escribir la imagen a mano"
)

# Paquetes no oficiales que chocan con los del repositorio de Docker
readonly CONFLICTS_DESKTOP=(docker.io docker-cli podman-docker)
readonly CONFLICTS_ENGINE=(docker.io docker-cli docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc)

readonly PWD_RULES="Requisitos: 8 a 30 caracteres, empezar por letra y tener al menos una mayúscula, una minúscula y un número. Solo letras sin tildes, números, _ y #."

# --- Perfil de la base de datos elegida (lo rellena image_profile) ------------
DB_VERSION=""          # 26ai | 23ai | 21c-xe | 18c-xe | 11g-xe | 19c-ee | 21c-ee ...
DB_LABEL=""            # nombre para mostrar
DB_FAMILY=""           # free | xe | ee
CDB_NAME=""            # FREE | XE | ORCLCDB
PDB_NAME=""            # FREEPDB1 | XEPDB1 | ORCLPDB1 | vacío (11g no tiene PDB)
DB_SERVICE=""          # servicio para conectarse: la PDB o, si no hay, la base
DATA_PATH="/opt/oracle/oradata"
PWD_STYLE="oficial"    # oficial (contraseña aleatoria) | gvenzl (ORACLE_RANDOM_PASSWORD)
HAS_DEV_ROLE=0         # DB_DEVELOPER_ROLE existe desde 23ai
NEEDS_LOGIN=0          # Enterprise/Standard: hace falta cuenta de Oracle
DB_EDITION=""          # enterprise | standard (solo Enterprise/Standard)
FIRST_TIMEOUT=1800     # segundos máximos para crear la base de datos la primera vez
FIRST_HINT="entre 2 y 15 minutos"
VM_MEM_MIN_MB=2800

# --- Estado de ejecución -------------------------------------------------------
DRY_RUN=0
UI_MODE="auto"         # auto | gui | tui | texto
GUI_READY=0
GUI_FD=""              # descriptor de la ventana de progreso (modo gráfico)
GUI_FIFO=""
GUI_PROGRESS_PID=""
GUI_BUSY=0
GUI_STEP_TEXT=""
GUI_INFO_PID=""
SUDO=(sudo)            # en modo gráfico: sudo -A (contraseña en una ventana)
ORACLE_PREF=""         # versión propuesta con --oracle
STOP_ALL=0
SUDO_READY=0
SUDO_KEEPALIVE_PID=""
APT_UPDATED=0
TMP_DIR=""
LOG_FILE=""
NEEDS_RELOGIN=0
DOCKER_GROUP_ADDED=0
STEP_N=0
STEP_TOTAL=0
DOCKER=(docker)
UI_W=76
UI_H=20
MIGRATED=0

# --- Respuestas del asistente / configuración guardada (nunca contraseñas) ----
ENGINE=""
IMAGE_KEY=""
IMAGE=""
CONTAINER_NAME=""
VOLUME_NAME=""
HOST_PORT="1521"
BIND_ADDR="127.0.0.1"
APP_USER=""
RESTART_POLICY="unless-stopped"
DD_AUTOSTART="no"
EXTRAS=""
INSTALL_STAGE=""
INSTALLED_AT=""
EXISTING_ACTION=""
EXISTING_IMAGE=""
DATA_IS_BIND=0
REMOVE_CONFLICTS=()
PREV_VERSION=""
ADMIN_PWD=""
APP_PWD=""
REG_USER=""            # cuenta de Oracle (solo Enterprise/Standard; no se guarda)
REG_TOKEN=""
CONTAINER_SINCE=0

readonly CONFIG_KEYS=(ENGINE IMAGE_KEY IMAGE DB_EDITION CONTAINER_NAME VOLUME_NAME HOST_PORT BIND_ADDR APP_USER RESTART_POLICY DD_AUTOSTART EXTRAS INSTALL_STAGE INSTALLED_AT)

# =============================================================================
#  Salida por pantalla y registro
# =============================================================================
setup_output() {
  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
  else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
  fi
  if [[ $(locale charmap 2>/dev/null) == "UTF-8" ]]; then
    S_OK="✔"; S_ERR="✘"; S_WARN="⚠"; S_INFO="➜"; S_RULE="════════════════════════════════════════════════════════════"
  else
    S_OK="[OK]"; S_ERR="[X]"; S_WARN="[!]"; S_INFO="->"; S_RULE="============================================================"
  fi
}

log() {
  if [[ -n $LOG_FILE ]]; then printf '[%(%F %T)T] %s\n' -1 "$*" >>"$LOG_FILE"; fi
  return 0
}
info() { printf '%s %s\n' "${C_BLUE}${S_INFO}${C_RESET}" "$*"; log "INFO  $*"; gui_note "$*"; }
ok()   { printf '%s %s\n' "${C_GREEN}${S_OK}${C_RESET}" "$*"; log "OK    $*"; gui_note "$S_OK $*"; }
warn() { printf '%s %s\n' "${C_YELLOW}${S_WARN}${C_RESET}" "$*" >&2; log "AVISO $*"; gui_note "$S_WARN $*"; }
err()  { printf '%s %s\n' "${C_RED}${S_ERR}${C_RESET}" "$*" >&2; log "ERROR $*"; gui_note "$S_ERR $*"; }

die() {
  err "$*"
  if [[ -n $LOG_FILE ]]; then printf '  %s\n' "Registro completo: $LOG_FILE" >&2; fi
  gui_error "$*"
  exit 1
}

step() {
  STEP_N=$((STEP_N + 1))
  printf '\n%s\n' "${C_BOLD}${C_CYAN}[$STEP_N/$STEP_TOTAL] $*${C_RESET}"
  log "==== [$STEP_N/$STEP_TOTAL] $*"
  GUI_STEP_TEXT="[$STEP_N/$STEP_TOTAL] $*"
  gui_progress_send "$(( (STEP_N - 1) * 100 / STEP_TOTAL ))" "# $GUI_STEP_TEXT"
}

init_log() {  # init_log nombre [anexar]
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR" 2>/dev/null || true
  if [[ ${2:-} == anexar ]]; then
    LOG_FILE="$STATE_DIR/$1.log"
    [[ -e $LOG_FILE ]] || install -m 600 /dev/null "$LOG_FILE"
  else
    LOG_FILE="$STATE_DIR/$1-$(date +%Y%m%d-%H%M%S).log"
    install -m 600 /dev/null "$LOG_FILE"
  fi
  log "---- $APP_CMD $APP_VERSION · $(uname -srm) · simulación=$DRY_RUN"
}

show_log_tail() {
  [[ -n $LOG_FILE && -s $LOG_FILE ]] || return 0
  printf '%s\n' "${C_DIM}   --- últimas líneas del registro ($LOG_FILE) ---" >&2
  tail -n 15 "$LOG_FILE" | sed 's/^/   /' >&2
  printf '%s\n' "   ---${C_RESET}" >&2
}

on_error() {
  local rc=$? line="${1:-?}"
  (( BASH_SUBSHELL == 0 )) || return 0
  log "ERR código=$rc línea=$line orden=${BASH_COMMAND}"
  err "Se ha producido un error inesperado (código $rc, línea $line)."
  if [[ -n $LOG_FILE ]]; then err "Revisa el registro: $LOG_FILE"; fi
  gui_error "Se ha producido un error inesperado (código $rc, línea $line)."
  return 0
}

on_interrupt() {
  printf '\n' >&2
  err "Interrumpido por el usuario."
  exit 130
}

cleanup() {
  gui_progress_close
  if [[ -n $GUI_INFO_PID ]]; then kill "$GUI_INFO_PID" 2>/dev/null || true; fi
  if [[ -n $SUDO_KEEPALIVE_PID ]]; then kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; fi
  if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then rm -rf -- "$TMP_DIR"; fi
  if [[ -t 1 ]]; then tput cnorm 2>/dev/null || true; fi
  ADMIN_PWD=""; APP_PWD=""; REG_TOKEN=""
  return 0
}

make_tmp() {
  if [[ -z $TMP_DIR ]]; then TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$APP_CMD.XXXXXX"); fi
  return 0
}

fmt_time() { printf '%dm %02ds' $(($1 / 60)) $(($1 % 60)); }

quote_cmd() {
  local a out=""
  for a in "$@"; do out+="$(printf '%q' "$a") "; done
  printf '%s' "${out% }"
}

# Ejecuta una orden guardando su salida en el registro y mostrando un indicador.
# En modo simulación solo muestra la orden.
run() {  # run "descripción" orden [args...]
  local desc="$1"; shift
  if (( DRY_RUN )); then
    printf '%s %s\n      %s\n' "${C_DIM}[simulación]${C_RESET}" "$desc" "${C_DIM}\$ $(quote_cmd "$@")${C_RESET}"
    log "SIMULA $desc: $(quote_cmd "$@")"
    return 0
  fi
  log "EJECUTA $desc: $(quote_cmd "$@")"
  gui_note "$desc..."
  local rc=0 out="${LOG_FILE:-/dev/null}"
  if [[ -t 1 ]]; then
    "$@" >>"$out" 2>&1 </dev/null &
    local pid=$! i=0 frames='|/-\'
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r %s %s ' "${C_CYAN}${frames:i++%4:1}${C_RESET}" "$desc"
      sleep 0.2
    done
    wait "$pid" || rc=$?
    tput cnorm 2>/dev/null || true
    printf '\r\e[K'
  else
    "$@" >>"$out" 2>&1 </dev/null || rc=$?
  fi
  if (( rc == 0 )); then
    ok "$desc"
  else
    err "$desc: ha fallado (código $rc)"
    show_log_tail
  fi
  return "$rc"
}

# Espera hasta que una comprobación sea cierta (o se agote el tiempo).
wait_for() {  # wait_for "descripción" segundos orden [args...]
  local desc="$1" timeout="$2"; shift 2
  if (( DRY_RUN )); then printf '%s %s\n' "${C_DIM}[simulación]${C_RESET}" "$desc"; return 0; fi
  local start=$SECONDS i=0 frames='|/-\'
  while ! "$@"; do
    if (( SECONDS - start >= timeout )); then
      [[ -t 1 ]] && printf '\r\e[K'
      return 1
    fi
    if [[ -t 1 ]]; then
      printf '\r\e[K %s %s (%s)' "${C_CYAN}${frames:i++%4:1}${C_RESET}" "$desc" "$(fmt_time $((SECONDS - start)))"
    fi
    gui_note "$desc ($(fmt_time $((SECONDS - start))))"
    sleep 3
  done
  [[ -t 1 ]] && printf '\r\e[K'
  ok "$desc"
}

# Descarga con barra de progreso (o simulada).
download() {  # download URL destino
  if (( DRY_RUN )); then
    printf '%s descargar %s\n' "${C_DIM}[simulación]${C_RESET}" "$1"
    return 0
  fi
  log "DESCARGA $1 -> $2"
  if [[ -t 2 ]]; then
    curl -fL --retry 3 --retry-delay 3 --connect-timeout 20 --progress-bar -o "$2" "$1"
  else
    curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 20 -o "$2" "$1"
  fi
}

# =============================================================================
#  Interfaz: ventanas gráficas (zenity), ventanas de terminal (whiptail) o texto
#  Lo que se dibuja va a la pantalla o a stderr; los valores elegidos, a stdout.
# =============================================================================
gui_available() { command -v zenity >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; }

ui_init() {
  if [[ $UI_MODE == auto ]]; then
    if gui_available; then UI_MODE="gui"; else UI_MODE="tui"; fi
  fi
  if [[ $UI_MODE == gui ]]; then
    if gui_available; then
      gui_setup
      return 0
    fi
    warn "No hay escritorio gráfico o falta zenity: se usan ventanas de terminal."
    UI_MODE="tui"
  fi
  if [[ $UI_MODE == tui ]]; then
    local lines=0 cols=0
    if command -v whiptail >/dev/null 2>&1 && [[ -t 0 && -t 2 ]]; then
      lines=$(tput lines 2>/dev/null || echo 0)
      cols=$(tput cols 2>/dev/null || echo 0)
    fi
    if (( lines >= 20 && cols >= 70 )); then return 0; fi
    UI_MODE="texto"
  fi
  return 0
}

strip_ansi() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }

# --- Modo gráfico (zenity) ----------------------------------------------------
zen() { zenity "$@" 2>/dev/null; }   # oculta los avisos internos de GTK

gui_setup() {
  (( GUI_READY )) && return 0
  GUI_READY=1
  make_tmp
  # sudo pedirá la contraseña en una ventana (sudo -A) en lugar de en la terminal
  cat >"$TMP_DIR/pedir-contrasena.sh" <<'EOF'
#!/bin/sh
exec zenity --entry --hide-text --title="Contraseña de administrador" --width=480 \
  --text="El instalador de Oracle Database necesita la contraseña de tu usuario de Ubuntu (la de iniciar sesión) para instalar programas." \
  --ok-label="Aceptar" --cancel-label="Cancelar" 2>/dev/null
EOF
  chmod 700 "$TMP_DIR/pedir-contrasena.sh"
  export SUDO_ASKPASS="$TMP_DIR/pedir-contrasena.sh"
  SUDO=(sudo -A)
  return 0
}

gui_list_height() {  # gui_list_height "texto" filas → alto en píxeles
  local lines=0 line h
  while IFS= read -r line; do lines=$((lines + 1 + ${#line} / 80)); done <<<"$1"
  h=$((170 + lines * 22 + $2 * 40))
  if (( h > 720 )); then h=720; fi
  if (( h < 280 )); then h=280; fi
  printf '%s' "$h"
}

gui_progress_open() {  # gui_progress_open "texto" [pulsate]
  [[ $UI_MODE == gui ]] || return 0
  if [[ -n $GUI_FD ]]; then gui_progress_send "# $1"; return 0; fi
  make_tmp
  GUI_FIFO="$TMP_DIR/progreso-$RANDOM"
  mkfifo -m 600 "$GUI_FIFO"
  local opts=(--progress --title="$APP_NAME" --text="$1" --width=640 --no-cancel --auto-close)
  [[ ${2:-} == pulsate ]] && opts+=(--pulsate)
  zen "${opts[@]}" <"$GUI_FIFO" >/dev/null &
  GUI_PROGRESS_PID=$!
  exec {GUI_FD}>"$GUI_FIFO"
  return 0
}

gui_progress_send() {  # envía líneas a la ventana de progreso (si sigue abierta)
  [[ -n $GUI_FD ]] || return 0
  kill -0 "$GUI_PROGRESS_PID" 2>/dev/null || return 0
  ( printf '%s\n' "$@" >&"$GUI_FD" ) 2>/dev/null || true
  return 0
}

gui_progress_close() {
  [[ -n $GUI_FD ]] || return 0
  gui_progress_send 100
  exec {GUI_FD}>&-
  GUI_FD=""
  sleep 0.2
  kill "$GUI_PROGRESS_PID" 2>/dev/null || true
  wait "$GUI_PROGRESS_PID" 2>/dev/null || true
  rm -f "$GUI_FIFO"
  return 0
}

gui_note() {  # gui_note "texto": actualiza el texto de la ventana de progreso
  [[ -n $GUI_FD ]] || return 0
  local msg="${1//$'\n'/ }"
  if [[ -n $GUI_STEP_TEXT ]]; then
    gui_progress_send "# $GUI_STEP_TEXT\\n$msg"
  else
    gui_progress_send "# $msg"
  fi
}

gui_show_text() {  # gui_show_text "título" "texto" (letra de ancho fijo)
  printf '%s\n' "$2" | zen --text-info --title="$1" --width=860 --height=560 --font="Monospace 10" \
    --ok-label="Aceptar" --cancel-label="Cerrar" >/dev/null || true
}

gui_show_file() {  # gui_show_file "título" fichero
  zen --text-info --title="$1" --filename="$2" --width=920 --height=600 --font="Monospace 9" \
    --ok-label="Aceptar" --cancel-label="Cerrar" >/dev/null || true
}

gui_error() {  # ventana de error con acceso al registro
  [[ $UI_MODE == gui && -z ${GUI_QUIET_ERRORS:-} ]] || return 0
  gui_progress_close
  local msg="$1" btn="" args=(--error --title="$APP_NAME" --no-markup --width=580 --ok-label="Cerrar")
  if [[ -n $LOG_FILE && -f $LOG_FILE ]]; then
    msg+=$'\n\n'"Registro: $LOG_FILE"
    args+=(--extra-button="Ver registro")
  fi
  btn=$(zen "${args[@]}" --text="$msg") || true
  if [[ $btn == "Ver registro" ]]; then gui_show_file "Registro" "$LOG_FILE"; fi
  return 0
}

open_in_terminal() {  # open_in_terminal "título" subcomando [args...]
  local title="$1" self script
  shift
  self=$(readlink -f "${BASH_SOURCE[0]}")
  # shellcheck disable=SC2016  # $0 y $@ se expanden dentro de la terminal nueva
  script='"$0" --tui "$@"; echo; read -r -p "Pulsa Enter para cerrar esta ventana... " _'
  if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal --title="$title" -- bash -c "$script" "$self" "$@" >/dev/null 2>&1 &
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash -c "$script" "$self" "$@" >/dev/null 2>&1 &
  else
    ui_msg "No hay terminal" "No se encontró ninguna terminal. Abre una y ejecuta: $APP_CMD $*"
  fi
  return 0
}

ui_done() {  # confirmación final de una acción (solo hace falta en modo gráfico)
  if [[ $UI_MODE == gui ]]; then ui_msg "Hecho" "$1"; fi
  return 0
}

# --- Modo terminal (whiptail) -------------------------------------------------
ui_backtitle() {
  local t="$APP_NAME · v$APP_VERSION"
  (( DRY_RUN )) && t+=" · MODO SIMULACIÓN (no se cambia nada)"
  printf '%s' "$t"
}

# Calcula el tamaño de la ventana: UI_W (ancho), UI_H (alto), UI_TEXT (filas de texto)
# y UI_MAXH (alto máximo que permite la terminal). Pensado para terminales de 80x24.
ui_dims() {  # ui_dims "texto" filas_extra
  local text="$1" extra="${2:-7}" cols lines line len wrap
  cols=$(tput cols 2>/dev/null || echo 80)
  lines=$(tput lines 2>/dev/null || echo 24)
  UI_W=$((cols - 4))
  if (( UI_W > 78 )); then UI_W=78; fi
  wrap=$((UI_W - 6))
  UI_TEXT=0
  while IFS= read -r line; do
    len=${#line}
    UI_TEXT=$((UI_TEXT + (len == 0 ? 1 : (len + wrap - 1) / wrap)))
  done <<<"$text"
  UI_MAXH=$((lines - 1))
  UI_H=$((UI_TEXT + extra))
  if (( UI_H > UI_MAXH )); then UI_H=$UI_MAXH; fi
  return 0
}

wt() { whiptail --backtitle "$(ui_backtitle)" "$@" 3>&1 1>&2 2>&3; }

# --- Funciones comunes a los tres modos -----------------------------------------
# Nota: en whiptail no se usa --scrolltext porque con él Enter no pulsa «Aceptar»
# (el foco se queda en el texto); por eso los textos son cortos.
ui_msg() {  # ui_msg "título" "texto"
  case $UI_MODE in
    gui)
      zen --info --title="$1" --text="$2" --no-markup --width=580 --ok-label="Aceptar" || true ;;
    tui)
      ui_dims "$2" 7
      whiptail --backtitle "$(ui_backtitle)" --title "$1" --ok-button "Aceptar" \
        --msgbox "$2" "$UI_H" "$UI_W" >&2 || true ;;
    *)
      printf '\n%s\n%s\n' "${C_BOLD}── $1 ──${C_RESET}" "$2" >&2 ;;
  esac
  return 0
}

ui_busy_start() {  # aviso de espera que se cierra solo («Comprobando la red...»)
  case $UI_MODE in
    gui)
      if [[ -z $GUI_FD ]]; then GUI_BUSY=1; gui_progress_open "$1" pulsate; else gui_note "$1"; fi ;;
    tui)
      ui_dims "$1" 5
      whiptail --backtitle "$(ui_backtitle)" --title "Un momento" --infobox "$1" "$UI_H" "$UI_W" >&2 || true ;;
    *)
      printf '%s\n' "$1" >&2 ;;
  esac
  return 0
}

ui_busy_stop() {
  if (( GUI_BUSY )); then GUI_BUSY=0; gui_progress_close; fi
  return 0
}

ui_yesno() {  # ui_yesno "título" "texto" [si|no] → 0 = sí (UI_YES / UI_NO cambian los botones)
  local def="${3:-si}" extra=()
  case $UI_MODE in
    gui)
      [[ $def == no ]] && extra=(--default-cancel)
      zen --question --title="$1" --text="$2" --no-markup --width=580 \
        --ok-label="${UI_YES:-Sí}" --cancel-label="${UI_NO:-No}" "${extra[@]}"
      return $? ;;
    tui)
      [[ $def == no ]] && extra=(--defaultno)
      ui_dims "$2" 7
      whiptail --backtitle "$(ui_backtitle)" --title "$1" --yes-button "${UI_YES:-Sí}" --no-button "${UI_NO:-No}" \
        "${extra[@]}" --yesno "$2" "$UI_H" "$UI_W" >&2
      return $? ;;
  esac
  local hint ans
  if [[ $def == no ]]; then hint="s/N"; else hint="S/n"; fi
  printf '\n%s\n%s\n%s ' "${C_BOLD}$1${C_RESET}" "$2" "¿Sí o no? [$hint]:" >&2
  IFS= read -r ans || ans=""
  ans="${ans,,}"
  ans="${ans:-${def:0:1}}"
  [[ $ans == s* || $ans == y* ]]
}

ui_input() {  # ui_input "título" "texto" "valor por defecto" → valor
  case $UI_MODE in
    gui)
      zen --entry --title="$1" --text="$2" --entry-text="$3" --width=540 \
        --ok-label="Aceptar" --cancel-label="Cancelar"
      return ;;
    tui)
      ui_dims "$2" 8
      wt --title "$1" --ok-button "Aceptar" --cancel-button "Cancelar" --inputbox "$2" "$UI_H" "$UI_W" "$3"
      return ;;
  esac
  local ans
  printf '\n%s\n%s\n%s ' "${C_BOLD}$1${C_RESET}" "$2" "Respuesta${3:+ [$3]}:" >&2
  IFS= read -r ans || return 1
  printf '%s' "${ans:-$3}"
}

ui_password() {  # ui_password "título" "texto" → contraseña
  case $UI_MODE in
    gui)
      zen --entry --hide-text --title="$1" --text="$2" --width=540 \
        --ok-label="Aceptar" --cancel-label="Cancelar"
      return ;;
    tui)
      ui_dims "$2" 8
      wt --title "$1" --ok-button "Aceptar" --cancel-button "Cancelar" --passwordbox "$2" "$UI_H" "$UI_W"
      return ;;
  esac
  local ans
  printf '\n%s\n%s\n%s ' "${C_BOLD}$1${C_RESET}" "$2" "Contraseña (no se ve al escribir):" >&2
  if [[ -t 0 ]]; then
    IFS= read -r -s ans || return 1
    printf '\n' >&2
  else
    IFS= read -r ans || return 1
  fi
  printf '%s' "$ans"
}

ui_menu() {  # ui_menu "título" "texto" "clave por defecto" clave1 desc1 [clave2 desc2 ...]
  local title="$1" text="$2" def="$3"; shift 3
  local n=$(($# / 2)) list
  case $UI_MODE in
    gui)
      local rows=() found=0
      while (( $# )); do
        if [[ $1 == "$def" ]]; then rows+=(TRUE); found=1; else rows+=(FALSE); fi
        rows+=("$1" "$2")
        shift 2
      done
      (( found )) || rows[0]=TRUE
      zen --list --radiolist --title="$title" --text="$text" --width=700 --height="$(gui_list_height "$text" "$n")" \
        --column="✓" --column="clave" --column="Opción" --hide-column=2 --print-column=2 --hide-header \
        --ok-label="Aceptar" --cancel-label="Cancelar" "${rows[@]}"
      return ;;
    tui)
      ui_dims "$text" $((n + 7))
      list=$((UI_H - UI_TEXT - 7))   # si no cabe todo, la lista se desplaza con las flechas
      if (( list > n )); then list=$n; fi
      if (( list < 3 )); then list=3; fi
      wt --title "$title" --ok-button "Aceptar" --cancel-button "Cancelar" --notags \
        --default-item "$def" --menu "$text" "$UI_H" "$UI_W" "$list" "$@"
      return ;;
  esac
  local keys=() i=0 defn=1 ans
  printf '\n%s\n%s\n' "${C_BOLD}$title${C_RESET}" "$text" >&2
  while (( $# )); do
    keys+=("$1")
    i=$((i + 1))
    if [[ $1 == "$def" ]]; then defn=$i; fi
    printf '  %d) %s\n' "$i" "$2" >&2
    shift 2
  done
  while true; do
    printf 'Elige una opción [%d]: ' "$defn" >&2
    IFS= read -r ans || return 1
    ans="${ans:-$defn}"
    if [[ $ans =~ ^[0-9]+$ ]] && (( 10#$ans >= 1 && 10#$ans <= ${#keys[@]} )); then
      printf '%s' "${keys[10#$ans - 1]}"
      return 0
    fi
    printf 'Opción no válida.\n' >&2
  done
}

ui_checklist() {  # ui_checklist "título" "texto" clave desc ON|OFF ... → claves separadas por espacios
  local title="$1" text="$2"; shift 2
  local n=$(($# / 3)) out list
  case $UI_MODE in
    gui)
      local rows=()
      while (( $# )); do
        if [[ $3 == ON ]]; then rows+=(TRUE); else rows+=(FALSE); fi
        rows+=("$1" "$2")
        shift 3
      done
      out=$(zen --list --checklist --title="$title" --text="$text" --width=700 --height="$(gui_list_height "$text" "$n")" \
        --column="✓" --column="clave" --column="Opción" --hide-column=2 --print-column=2 --hide-header \
        --separator=" " --ok-label="Aceptar" --cancel-label="Cancelar" "${rows[@]}") || return 1
      printf '%s' "$out"
      return 0 ;;
    tui)
      ui_dims "$text" $((n + 7))
      list=$((UI_H - UI_TEXT - 7))
      if (( list > n )); then list=$n; fi
      if (( list < 2 )); then list=2; fi
      out=$(wt --title "$title" --ok-button "Aceptar" --cancel-button "Cancelar" --notags --separate-output \
        --checklist "$text" "$UI_H" "$UI_W" "$list" "$@") || return 1
      printf '%s' "$(printf '%s' "$out" | tr '\n' ' ' | sed 's/ *$//')"
      return 0 ;;
  esac
  local sel=() def
  printf '\n%s\n%s\n' "${C_BOLD}$title${C_RESET}" "$text" >&2
  while (( $# )); do
    def="no"
    [[ $3 == ON ]] && def="si"
    if ui_yesno "$2" "¿Incluir esta opción?" "$def"; then sel+=("$1"); fi
    shift 3
  done
  printf '%s' "${sel[*]}"
}

cancelled() {
  gui_progress_close
  printf '\n' >&2
  warn "Asistente cancelado. No se ha realizado ningún cambio."
  exit 1
}

# =============================================================================
#  Validaciones (en locale C para que [A-Z] signifique exactamente A-Z)
# =============================================================================
password_problem() (  # imprime el problema y devuelve 0 si la contraseña NO es válida
  export LC_ALL=C
  p="$1"
  if (( ${#p} < 8 || ${#p} > 30 )); then echo "Debe tener entre 8 y 30 caracteres."; exit 0; fi
  if [[ ! $p =~ ^[A-Za-z] ]]; then echo "Debe empezar por una letra."; exit 0; fi
  if [[ ! $p =~ ^[A-Za-z0-9_#]+$ ]]; then echo "Solo se permiten letras sin tildes ni ñ, números, _ y #."; exit 0; fi
  if [[ ! $p =~ [A-Z] ]]; then echo "Debe tener al menos una letra MAYÚSCULA."; exit 0; fi
  if [[ ! $p =~ [a-z] ]]; then echo "Debe tener al menos una letra minúscula."; exit 0; fi
  if [[ ! $p =~ [0-9] ]]; then echo "Debe tener al menos un número."; exit 0; fi
  exit 1
)

valid_container_name() ( export LC_ALL=C; [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] )

valid_image_ref() ( export LC_ALL=C; [[ $1 =~ ^[a-z0-9.-]+(/[a-z0-9._-]+)+:[A-Za-z0-9._-]+$ ]] )

user_problem() (  # igual que password_problem, para nombres de usuario de Oracle
  export LC_ALL=C
  u="${1^^}"
  if [[ ! $u =~ ^[A-Z][A-Z0-9_]{1,29}$ ]]; then
    echo "Usa de 2 a 30 caracteres: letras sin tildes, números y _, empezando por letra."; exit 0
  fi
  reserved="SYS SYSTEM PDBADMIN SYSBACKUP SYSDG SYSKM SYSRAC AUDSYS DBSNMP XDB OUTLN PUBLIC ANONYMOUS CTXSYS MDSYS ORDSYS WMSYS LBACSYS DVSYS OJVMSYS GSMADMIN_INTERNAL DBSFWUSER USER USERS TABLE SELECT INSERT UPDATE DELETE FROM WHERE ORDER GROUP INDEX VIEW GRANT DATE NUMBER CHAR LEVEL SESSION ACCESS"
  if [[ " $reserved " == *" $u "* ]]; then echo "«$u» es un nombre reservado de Oracle. Elige otro."; exit 0; fi
  exit 1
)

# =============================================================================
#  Versiones e imágenes de Oracle Database
# =============================================================================
normalize_version() {  # acepta alias cortos: 21c → 21c-xe, 19c → 19c-ee...
  case ${1,,} in
    26ai | 26) printf '26ai' ;;
    23ai | 23) printf '23ai' ;;
    21c | 21c-xe | 21xe) printf '21c-xe' ;;
    18c | 18c-xe | 18xe) printf '18c-xe' ;;
    11g | 11g-xe | 11xe) printf '11g-xe' ;;
    19c | 19c-ee | 19ee) printf '19c-ee' ;;
    21c-ee | 21ee) printf '21c-ee' ;;
    *) return 1 ;;
  esac
}

version_label() {  # nombre de la versión según VERSION_LIST (sin las notas)
  local entry
  for entry in "${VERSION_LIST[@]}"; do
    if [[ ${entry%%|*} == "$1" ]]; then
      entry="${entry#*|}"
      printf '%s' "${entry%% · *}"
      return 0
    fi
  done
  printf 'Oracle Database'
}

catalog_get() {  # catalog_get clave campo (1 versión, 3 imagen, 4 descripción, 5 tamaño)
  local entry
  for entry in "${IMAGE_CATALOG[@]}"; do
    if [[ $(cut -d'|' -f2 <<<"$entry") == "$1" ]]; then cut -d'|' -f"$2" <<<"$entry"; return 0; fi
  done
  return 1
}
catalog_image() { catalog_get "$1" 3; }
catalog_version() { catalog_get "$1" 1 || true; }

catalog_key_for_image() {  # primera clave del catálogo para una imagen (si la hay)
  local entry
  for entry in "${IMAGE_CATALOG[@]}"; do
    if [[ $(cut -d'|' -f3 <<<"$entry") == "$1" ]]; then cut -d'|' -f2 <<<"$entry"; return 0; fi
  done
  return 1
}

repo_of() {  # repositorio de una clave de REPO_LIST
  local entry
  for entry in "${REPO_LIST[@]}"; do
    if [[ ${entry%%|*} == "$1" ]]; then cut -d'|' -f2 <<<"$entry"; return 0; fi
  done
  return 1
}

# Deduce de la imagen cómo es la base de datos: servicios, rutas, permisos, memoria...
# Devuelve 1 si la imagen no es de un repositorio conocido.
image_profile() {  # image_profile imagen [clave]
  local img="$1" key="${2:-}" tag major ed
  tag="${img##*:}"
  [[ $img == *:* ]] || tag="latest"
  DATA_PATH="/opt/oracle/oradata"; PWD_STYLE="oficial"; HAS_DEV_ROLE=0; NEEDS_LOGIN=0
  FIRST_TIMEOUT=1800; FIRST_HINT="entre 2 y 15 minutos"; VM_MEM_MIN_MB=2800
  case $img in
    *gvenzl/oracle-free:* | */database/free:*)
      DB_FAMILY="free"; CDB_NAME="FREE"; PDB_NAME="FREEPDB1"; HAS_DEV_ROLE=1; DB_EDITION=""
      if [[ $tag =~ ^23\.[2-9]([.-]|$) ]]; then
        DB_VERSION="23ai"; DB_LABEL="Oracle Database 23ai Free"
      else
        DB_VERSION="26ai"; DB_LABEL="Oracle AI Database 26ai Free"
      fi ;;
    *gvenzl/oracle-xe:* | */database/express:*)
      DB_FAMILY="xe"; CDB_NAME="XE"; PDB_NAME="XEPDB1"; DB_EDITION=""
      case $tag in
        11*)
          DB_VERSION="11g-xe"; DB_LABEL="Oracle Database 11g Express Edition"
          PDB_NAME=""; DATA_PATH="/u01/app/oracle/oradata"; VM_MEM_MIN_MB=1800 ;;
        18*) DB_VERSION="18c-xe"; DB_LABEL="Oracle Database 18c Express Edition" ;;
        *) DB_VERSION="21c-xe"; DB_LABEL="Oracle Database 21c Express Edition" ;;
      esac ;;
    */database/enterprise:*)
      DB_FAMILY="ee"; CDB_NAME="ORCLCDB"; PDB_NAME="ORCLPDB1"; NEEDS_LOGIN=1
      FIRST_TIMEOUT=3600; FIRST_HINT="entre 15 y 45 minutos"; VM_MEM_MIN_MB=3800
      case $key in
        *-se2) DB_EDITION="standard" ;;
        *-ee) DB_EDITION="enterprise" ;;
      esac
      [[ $DB_EDITION == standard ]] || DB_EDITION="enterprise"
      major="${tag%%.*}"
      if [[ $major =~ ^[0-9]+$ ]]; then DB_VERSION="${major}c-ee"; else DB_VERSION="ee"; fi
      ed="Enterprise Edition"
      [[ $DB_EDITION == standard ]] && ed="Standard Edition 2"
      if [[ $major =~ ^[0-9]+$ ]]; then DB_LABEL="Oracle Database ${major}c $ed"; else DB_LABEL="Oracle Database $ed ($tag)"; fi ;;
    *) return 1 ;;
  esac
  [[ $img == *gvenzl/* ]] && PWD_STYLE="gvenzl"
  DB_SERVICE="${PDB_NAME:-$CDB_NAME}"
  return 0
}

default_container_name() {  # oracle-26ai, oracle-21c-xe, oracle-19c-se2...
  local v="$DB_VERSION"
  [[ $DB_EDITION == standard ]] && v="${v%-ee}-se2"
  printf 'oracle-%s' "$v"
}

admin_names() {  # cuentas de administración que existen en la versión elegida
  if [[ -n $PDB_NAME && $PWD_STYLE == oficial ]]; then printf 'SYS, SYSTEM y PDBADMIN'; else printf 'SYS y SYSTEM'; fi
}

role_text() {  # qué permisos recibe el usuario de trabajo
  if (( HAS_DEV_ROLE )); then
    printf 'el rol DB_DEVELOPER_ROLE (crear tablas, vistas, procedimientos, etc.)'
  else
    printf 'permisos para crear tablas, vistas, secuencias, procedimientos, disparadores y tipos'
  fi
}

# Imagen equivalente en Docker Hub (gvenzl) de una imagen oficial Free o XE.
hub_equivalent_image() {
  local tag="${1##*:}"
  case $1 in
    */database/free:*)
      case $tag in
        latest | latest-lite) printf 'docker.io/gvenzl/oracle-free:23' ;;
        *)
          tag="${tag%-lite}"
          if [[ $tag =~ ^(23\.26\.[0-9]+)\.0$ ]]; then tag="${BASH_REMATCH[1]}"
          elif [[ $tag =~ ^(23\.[0-9]+)\.0\.0$ ]]; then tag="${BASH_REMATCH[1]}"; fi
          printf 'docker.io/gvenzl/oracle-free:%s' "$tag" ;;
      esac ;;
    */database/express:*)
      if [[ $tag == latest ]]; then printf 'docker.io/gvenzl/oracle-xe:21'; else printf 'docker.io/gvenzl/oracle-xe:%s' "${tag%-xe}"; fi ;;
    *) return 1 ;;
  esac
}

is_oracle_registry_image() { [[ $1 == "$ORACLE_REGISTRY"/* ]]; }

# Lista las etiquetas de un repositorio (las más nuevas primero), sin variantes de arquitectura.
list_tags() {  # list_tags repositorio
  python3 - "$1" <<'PY'
import json, re, sys, urllib.request
repo = sys.argv[1]
def get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)
tags = []
if repo.startswith("container-registry.oracle.com/"):
    name = repo.split("/", 1)[1]
    tok = get("https://container-registry.oracle.com/auth?service=Oracle%20Registry&scope=repository:" + name + ":pull").get("token", "")
    tags = get("https://container-registry.oracle.com/v2/" + name + "/tags/list", {"Authorization": "Bearer " + tok}).get("tags") or []
else:
    name = repo.split("/", 1)[1] if repo.startswith("docker.io/") else repo
    url = "https://hub.docker.com/v2/repositories/" + name + "/tags?page_size=100"
    while url:
        j = get(url)
        tags += [t["name"] for t in j.get("results", [])]
        url = j.get("next")
tags = [t for t in tags if not re.search(r"(amd64|arm64)", t) and not t.startswith("RDBMS_")]
def clave(t):
    return ([int(x) for x in re.findall(r"\d+", t)], t)
for t in sorted(set(tags), key=clave, reverse=True):
    print(t)
PY
}

# =============================================================================
#  Detección del sistema
# =============================================================================
pkg_installed() { [[ $(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null) == ii* ]]; }
pkg_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true; }
in_group_db() { [[ " $(id -nG "$USER" 2>/dev/null) " == *" $1 "* ]]; }   # según /etc/group (no la sesión)

read_os_release() {
  OS_ID=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}") || OS_ID=""
  OS_LIKE=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}") || OS_LIKE=""
  OS_VERSION=$(. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_ID:-}") || OS_VERSION=""
  OS_NAME=$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-Linux}") || OS_NAME="Linux"
  OS_CODENAME=$(. /etc/os-release 2>/dev/null && printf '%s' "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}") || OS_CODENAME=""
  return 0
}

detect_system() {
  read_os_release
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
  MEM_MB=$(awk '/^MemTotal:/ {printf "%d", $2 / 1024}' /proc/meminfo)
  DISK_ROOT_GB=$(df -Pk / | awk 'NR == 2 {printf "%d", $4 / 1048576}')
  DISK_HOME_GB=$(df -Pk "$HOME" | awk 'NR == 2 {printf "%d", $4 / 1048576}')
  CPU_VIRT=0
  if grep -Eqw 'vmx|svm' /proc/cpuinfo; then CPU_VIRT=1; fi
  HAS_SYSTEMD=0
  if [[ -d /run/systemd/system ]]; then HAS_SYSTEMD=1; fi
  VIRT_ENV=$(systemd-detect-virt 2>/dev/null) || VIRT_ENV="none"
  HAS_DESKTOP=0
  if [[ -n ${XDG_CURRENT_DESKTOP:-}${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then HAS_DESKTOP=1; fi
  DD_INSTALLED=0
  if pkg_installed docker-desktop; then DD_INSTALLED=1; fi
  ENGINE_INSTALLED=0
  if pkg_installed docker-ce; then ENGINE_INSTALLED=1; fi
  return 0
}

virt_hint() {
  if [[ $VIRT_ENV != none && -n $VIRT_ENV ]]; then
    printf ' (Ubuntu se ejecuta dentro de una máquina virtual «%s»: activa la virtualización anidada o usa Docker Engine)' "$VIRT_ENV"
  else
    printf ' (actívala en la BIOS/UEFI: Intel VT-x o AMD-V/SVM)'
  fi
}

mb_to_gb() { awk -v m="$1" 'BEGIN {printf "%.1f", m / 1024}' | tr '.' ','; }

preflight_collect() {
  PF_OK=(); PF_WARN=(); PF_ERR=()
  detect_system
  if [[ $OS_ID == ubuntu && $OS_VERSION == 24.04 ]]; then
    PF_OK+=("Sistema: $OS_NAME")
  elif [[ $OS_ID == ubuntu || " $OS_LIKE " == *" ubuntu "* ]]; then
    PF_WARN+=("Sistema: $OS_NAME. La herramienta está pensada para Ubuntu 24.04; puede funcionar, pero no está probada aquí.")
  else
    PF_ERR+=("Sistema no compatible: $OS_NAME. Se necesita Ubuntu (24.04 recomendado).")
  fi
  case $ARCH in
    amd64) PF_OK+=("Arquitectura: amd64 (x86-64)") ;;
    arm64) PF_WARN+=("Procesador ARM (arm64): Docker Desktop para Linux no existe para ARM; se usará Docker Engine.") ;;
    *) PF_ERR+=("Arquitectura no compatible: $ARCH.") ;;
  esac
  if (( HAS_SYSTEMD )); then
    PF_OK+=("systemd activo")
  else
    PF_ERR+=("systemd no está activo (¿WSL o un contenedor?). Hace falta un Ubuntu instalado normalmente.")
  fi
  if (( MEM_MB < RAM_MIN_MB )); then
    PF_ERR+=("Memoria RAM: $(mb_to_gb "$MEM_MB") GB. Oracle y Docker necesitan al menos 4 GB (8 GB recomendados).")
  elif (( MEM_MB < RAM_REC_MB )); then
    PF_WARN+=("Memoria RAM: $(mb_to_gb "$MEM_MB") GB. Irá justo (se recomiendan 8 GB): cierra otros programas mientras uses Oracle.")
  else
    PF_OK+=("Memoria RAM: $(mb_to_gb "$MEM_MB") GB")
  fi
  local disk=$DISK_ROOT_GB
  if (( DISK_HOME_GB < disk )); then disk=$DISK_HOME_GB; fi
  if (( disk < DISK_MIN_GB )); then
    PF_ERR+=("Espacio libre en disco: $disk GB. Se necesitan al menos $DISK_MIN_GB GB (recomendado $DISK_REC_GB GB).")
  elif (( disk < DISK_REC_GB )); then
    PF_WARN+=("Espacio libre en disco: $disk GB. Se recomiendan $DISK_REC_GB GB.")
  else
    PF_OK+=("Espacio libre en disco: $disk GB")
  fi
  if (( CPU_VIRT )); then
    PF_OK+=("Virtualización de CPU disponible (KVM)")
  else
    PF_WARN+=("La CPU no ofrece virtualización$(virt_hint). Docker Desktop no funcionará; se usará Docker Engine.")
  fi
  if (( HAS_DESKTOP )); then
    PF_OK+=("Escritorio gráfico: ${XDG_CURRENT_DESKTOP:-detectado}")
  else
    PF_WARN+=("No se detecta escritorio gráfico (¿conexión SSH?). Docker Desktop lo necesita; se usará Docker Engine.")
  fi
  if curl -sS -o /dev/null -m 10 -I https://download.docker.com/ 2>/dev/null; then
    PF_OK+=("Conexión con download.docker.com")
  else
    PF_ERR+=("No hay conexión con download.docker.com. Revisa tu conexión a Internet (o el proxy).")
  fi
  return 0
}

# --- Red: ¿se pueden descargar las imágenes? -----------------------------------
is_private_ipv4() {
  local a b rest
  IFS=. read -r a b rest <<<"$1"
  [[ $a =~ ^[0-9]+$ && $b =~ ^[0-9]+$ ]] || return 1
  if (( a == 10 || a == 127 || a == 0 )); then return 0; fi
  if (( a == 172 && b >= 16 && b <= 31 )); then return 0; fi
  if (( a == 192 && b == 168 )); then return 0; fi
  if (( a == 100 && b >= 64 && b <= 127 )); then return 0; fi
  return 1
}

oracle_storage_ok() {
  local ip
  ip=$(getent ahostsv4 "$OCI_STORAGE_HOST" 2>/dev/null | awk 'NR == 1 {print $1}') || ip=""
  [[ -n $ip ]] || return 1
  if is_private_ipv4 "$ip"; then return 1; fi   # redirigido a un «sinkhole» de la red
  curl -s -o /dev/null -m 8 "https://$OCI_STORAGE_HOST/" 2>/dev/null
}

dockerhub_ok() { curl -s -o /dev/null -m 8 https://registry-1.docker.io/v2/ 2>/dev/null; }

# =============================================================================
#  Docker: órdenes y consultas
# =============================================================================
set_docker_cmd() {  # set_docker_cmd [nosudo]
  if [[ $ENGINE == desktop ]]; then
    DOCKER=(docker --context desktop-linux)
  elif docker --context default info >/dev/null 2>&1 || (( DRY_RUN )) || [[ ${1:-} == nosudo ]]; then
    DOCKER=(docker --context default)
  else
    ensure_sudo
    DOCKER=("${SUDO[@]}" docker --context default)
  fi
  return 0
}

docker_ready() { command -v docker >/dev/null 2>&1 && "${DOCKER[@]}" info >/dev/null 2>&1; }
docker_desktop_ready() { docker --context desktop-linux info >/dev/null 2>&1; }
container_state() { "${DOCKER[@]}" inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true; }
volume_exists() { "${DOCKER[@]}" volume inspect "$VOLUME_NAME" >/dev/null 2>&1; }
image_exists() { "${DOCKER[@]}" image inspect "$1" >/dev/null 2>&1; }

print_container_logs() {
  printf '%s\n' "${C_DIM}   --- últimas líneas de 'docker logs $CONTAINER_NAME' ---" >&2
  "${DOCKER[@]}" logs --tail "${1:-30}" "$CONTAINER_NAME" 2>&1 | sed 's/^/   /' >&2 || true
  printf '%s\n' "   ---${C_RESET}" >&2
}

port_in_use() { [[ -n $(ss -Hltn "sport = :$1" 2>/dev/null) ]]; }

free_port_from() {  # primer puerto libre a partir de uno dado
  local p="$1"
  while port_in_use "$p" && (( p < 65535 )); do p=$((p + 1)); done
  printf '%s' "$p"
}

# --- SQL dentro del contenedor (las contraseñas viajan siempre por stdin) ------
sql_sysdba() { "${DOCKER[@]}" exec -i "$CONTAINER_NAME" sqlplus -s -L / as sysdba; }

db_sql_ready() {
  local out q
  if [[ -n $PDB_NAME ]]; then
    q="SELECT open_mode FROM v\$pdbs WHERE name = '$PDB_NAME';"
  else
    q="SELECT status FROM v\$instance;"
  fi
  out=$(printf '%s\n' "SET HEADING OFF FEEDBACK OFF PAGESIZE 0" "$q" "EXIT" | sql_sysdba 2>/dev/null) || return 1
  if [[ -n $PDB_NAME ]]; then [[ $out == *"READ WRITE"* ]]; else [[ $out == *OPEN* ]]; fi
}

verify_login() {  # verify_login USUARIO CONTRASEÑA → 0 si puede conectar por el listener
  local out
  out=$(printf 'CONNECT %s/"%s"@//localhost:1521/%s\nSET HEADING OFF FEEDBACK OFF\nSELECT %s FROM dual;\nEXIT\n' \
    "$1" "$2" "$DB_SERVICE" "'CONEXION_OK'" \
    | "${DOCKER[@]}" exec -i "$CONTAINER_NAME" sqlplus -s -L /nolog 2>&1) || true
  [[ $out == *CONEXION_OK* ]]
}

pdb_switch_sql() {  # pasa a la base de trabajo (si hay PDB)
  if [[ -n $PDB_NAME ]]; then printf 'ALTER SESSION SET CONTAINER = %s;\n' "$PDB_NAME"; fi
  return 0
}

admin_sql() {  # SQL para fijar la contraseña de los administradores
  cat <<SQL
WHENEVER SQLERROR EXIT FAILURE
SET DEFINE OFF
SET FEEDBACK OFF
SET HEADING OFF
BEGIN
  EXECUTE IMMEDIATE 'ALTER USER SYS IDENTIFIED BY "$1"';
  EXECUTE IMMEDIATE 'ALTER USER SYSTEM IDENTIFIED BY "$1" ACCOUNT UNLOCK';
END;
/
SQL
  [[ -n $PDB_NAME ]] || return 0
  cat <<SQL
ALTER SESSION SET CONTAINER = $PDB_NAME;
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'PDBADMIN';
  IF n > 0 THEN
    EXECUTE IMMEDIATE 'ALTER USER PDBADMIN IDENTIFIED BY "$1" ACCOUNT UNLOCK';
  END IF;
END;
/
SQL
}

user_sql() {  # SQL (ya en la base de trabajo) para crear o actualizar un usuario de trabajo
  local grants
  if (( HAS_DEV_ROLE )); then
    grants="  EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO $1';
  EXECUTE IMMEDIATE 'GRANT DB_DEVELOPER_ROLE TO $1';"
  else
    grants="  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE TYPE, CREATE SYNONYM, CREATE MATERIALIZED VIEW TO $1';"
  fi
  cat <<SQL
WHENEVER SQLERROR EXIT FAILURE
SET DEFINE OFF
SET FEEDBACK OFF
DECLARE
  n  NUMBER;
  ts VARCHAR2(128);
BEGIN
  SELECT COUNT(*) INTO n FROM dba_profiles WHERE profile = '$PROFILE_NAME';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE PROFILE $PROFILE_NAME LIMIT PASSWORD_LIFE_TIME UNLIMITED';
  END IF;
  -- USERS si existe (en 11g XE el tablespace por defecto es SYSTEM, que no debe usarse)
  SELECT COUNT(*) INTO n FROM dba_tablespaces WHERE tablespace_name = 'USERS';
  IF n > 0 THEN
    ts := 'USERS';
  ELSE
    SELECT property_value INTO ts FROM database_properties
     WHERE property_name = 'DEFAULT_PERMANENT_TABLESPACE';
  END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = '$1';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER $1 IDENTIFIED BY "$2" DEFAULT TABLESPACE ' || ts
      || ' QUOTA UNLIMITED ON ' || ts || ' PROFILE $PROFILE_NAME';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER $1 IDENTIFIED BY "$2" ACCOUNT UNLOCK';
  END IF;
$grants
END;
/
SQL
}

alter_user_sql() {  # cambiar contraseña y desbloquear un usuario existente
  printf 'WHENEVER SQLERROR EXIT FAILURE\nSET DEFINE OFF\nSET FEEDBACK OFF\n'
  pdb_switch_sql
  cat <<SQL
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = '$1';
  IF n = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'El usuario $1 no existe en $DB_SERVICE');
  END IF;
  EXECUTE IMMEDIATE 'ALTER USER $1 IDENTIFIED BY "$2" ACCOUNT UNLOCK';
END;
/
SQL
}

run_sql_script() {  # run_sql_script "descripción" < SQL por stdin
  local desc="$1" out rc=0
  if (( DRY_RUN )); then
    cat >/dev/null
    printf '%s %s %s\n' "${C_DIM}[simulación]${C_RESET}" "$desc" "${C_DIM}(SQL por stdin, no se muestra porque lleva contraseñas)${C_RESET}"
    return 0
  fi
  out=$(sql_sysdba 2>&1) || rc=$?
  log "sqlplus ($desc) código=$rc salida: $out"
  if (( rc != 0 )) || [[ $out == *ORA-* || $out == *SP2-* || $out == *PLS-* ]]; then
    err "$desc: ha fallado."
    printf '%s\n' "$out" | sed 's/^/   /' >&2
    return 1
  fi
  ok "$desc"
}

# =============================================================================
#  sudo y apt
# =============================================================================
ensure_sudo() {
  (( SUDO_READY )) && return 0
  if (( DRY_RUN )); then SUDO_READY=1; return 0; fi
  command -v sudo >/dev/null 2>&1 || die "No se encontró 'sudo'. Usa un usuario administrador."
  if ! "${SUDO[@]}" -n true 2>/dev/null; then
    gui_note "Escribe tu contraseña de Ubuntu en la ventana que se ha abierto..."
    printf '\n'
    info "Se necesitan permisos de administrador: escribe la contraseña de TU usuario de Ubuntu."
    info "(Mientras escribes no se ve nada; es normal.)"
    "${SUDO[@]}" -v || die "No se pudieron obtener permisos de administrador (sudo). ¿Tu usuario es administrador?"
  fi
  SUDO_READY=1
  ( while kill -0 "$$" 2>/dev/null; do "${SUDO[@]}" -n true 2>/dev/null || true; sleep 45; done ) &
  SUDO_KEEPALIVE_PID=$!
  return 0
}

apt_update_once() {
  (( APT_UPDATED )) && return 0
  ensure_sudo
  if ! run "Actualizando la lista de paquetes (apt update)" "${SUDO[@]}" apt-get update -o DPkg::Lock::Timeout=300; then
    warn "apt update ha dado errores (¿algún repositorio roto?). Se intenta continuar."
  fi
  APT_UPDATED=1
  return 0
}

apt_install() {  # apt_install "descripción" paquete...
  local desc="$1"; shift
  local missing=() p
  for p in "$@"; do
    if ! pkg_installed "$p"; then missing+=("$p"); fi
  done
  if (( ${#missing[@]} == 0 )); then
    ok "$desc: ya instalado"
    return 0
  fi
  apt_update_once
  run "$desc (${missing[*]})" "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -o DPkg::Lock::Timeout=300 "${missing[@]}"
}

# =============================================================================
#  Asistente (preguntas)
# =============================================================================
welcome_text() {
  local text
  text="Este asistente deja lista Oracle Database en tu Ubuntu:

 1. Instala Docker Desktop y lo que necesita (KVM, repositorio...).
 2. Te deja elegir la versión: 26ai, 23ai, 21c, 18c, 11g, 19c...
 3. Crea el contenedor, con los datos en un volumen persistente.
 4. Pone tus contraseñas y crea tu usuario de trabajo.
 5. Añade el comando '$APP_CMD' y un acceso en el menú.

Primero unas preguntas (Enter = opción recomendada) y luego todo
va solo. Necesitarás tu contraseña de Ubuntu y unos 20-40 minutos."
  if (( DRY_RUN )); then text+=$'\n\nMODO SIMULACIÓN: solo se muestra lo que se haría.'; fi
  printf '%s' "$text"
}

wizard() {
  ui_msg "Bienvenida" "$(welcome_text)"
  wizard_engine
  wizard_conflicts
  wizard_version
  wizard_container
  if [[ $EXISTING_ACTION != keep ]]; then
    wizard_port
    wizard_network
  fi
  wizard_admin_password
  wizard_app_user
  wizard_autostart
  wizard_extras
  wizard_summary || cancelled
}

wizard_engine() {
  local reasons=() text
  [[ $ARCH == amd64 ]] || reasons+=("Docker Desktop para Linux solo existe para procesadores x86-64 (amd64).")
  (( CPU_VIRT )) || reasons+=("La CPU no ofrece virtualización KVM$(virt_hint).")
  (( HAS_DESKTOP )) || reasons+=("No hay sesión de escritorio gráfico.")
  (( HAS_SYSTEMD )) || reasons+=("systemd no está activo.")
  if (( ${#reasons[@]} == 0 )); then
    text="¿Con qué Docker quieres ejecutar Oracle?

Docker Desktop es lo recomendado: trae interfaz gráfica y ejecuta los contenedores dentro de una pequeña máquina virtual (KVM)."
    if (( DD_INSTALLED )); then text+=$'\n\n(Docker Desktop ya está instalado en este equipo.)'; fi
    ENGINE=$(ui_menu "Motor de contenedores" "$text" "${ENGINE:-desktop}" \
      desktop "Docker Desktop (recomendado)" \
      engine "Docker Engine (sin interfaz gráfica, más ligero)") || cancelled
  else
    text="No se puede usar Docker Desktop en este equipo:
$(printf ' - %s\n' "${reasons[@]}")

Se usará Docker Engine (Docker sin interfaz gráfica). Oracle funciona exactamente igual."
    ui_msg "Se usará Docker Engine" "$text"
    ENGINE="engine"
  fi
  set_docker_cmd nosudo
}

wizard_conflicts() {
  local list=() p
  REMOVE_CONFLICTS=()
  if [[ $ENGINE == desktop ]]; then
    (( DD_INSTALLED )) && return 0
    list=("${CONFLICTS_DESKTOP[@]}")
  else
    (( ENGINE_INSTALLED )) && return 0
    list=("${CONFLICTS_ENGINE[@]}")
  fi
  for p in "${list[@]}"; do
    if pkg_installed "$p"; then REMOVE_CONFLICTS+=("$p"); fi
  done
  (( ${#REMOVE_CONFLICTS[@]} )) || return 0
  ui_yesno "Paquetes en conflicto" "Tienes instalados paquetes de Docker no oficiales que impiden instalar la versión oficial:

   ${REMOVE_CONFLICTS[*]}

Hay que desinstalarlos. Tus imágenes, contenedores y volúmenes de /var/lib/docker NO se borran.

¿Desinstalarlos y continuar?" si || cancelled
}

wizard_version() {  # versión de Oracle Database y, después, la imagen concreta
  local args=() entry key def="${ORACLE_PREF:-}" choice
  if [[ -z $def ]]; then
    if [[ -n $PREV_VERSION ]] && normalize_version "$PREV_VERSION" >/dev/null; then def="$PREV_VERSION"; else def="26ai"; fi
  fi
  for entry in "${VERSION_LIST[@]}"; do
    key="${entry%%|*}"
    args+=("$key" "${entry#*|}")
  done
  choice=$(ui_menu "Versión de Oracle Database" "¿Qué versión de Oracle Database quieres instalar?

Free y Express Edition (XE) son gratuitas y no necesitan cuenta.
Enterprise y Standard necesitan una cuenta gratuita de Oracle." "$def" "${args[@]}") || cancelled
  if [[ $choice == otra ]]; then
    wizard_image_other
  else
    wizard_variant "$choice"
  fi
}

wizard_variant() {  # wizard_variant versión → imagen concreta (oficial o Docker Hub)
  local ver="$1" blocked=0 def="" first="" text args=() entry v key img desc size
  ui_busy_start "Comprobando la red (acceso a los registros de imágenes)..."
  if ! oracle_storage_ok; then blocked=1; fi
  ui_busy_stop
  for entry in "${IMAGE_CATALOG[@]}"; do
    IFS='|' read -r v key img desc size <<<"$entry"
    [[ $v == "$ver" ]] || continue
    [[ -n $first ]] || first="$key"
    if [[ -z $def ]]; then
      if (( ! blocked )) || [[ $key == hub-* ]]; then def="$key"; fi
    fi
  done
  [[ -n $def ]] || def="$first"
  # Si en una instalación anterior se eligió esta misma versión, se propone lo mismo
  if [[ -n $IMAGE_KEY && $(catalog_version "$IMAGE_KEY") == "$ver" ]]; then
    if (( ! blocked )) || [[ $IMAGE_KEY == hub-* ]]; then def="$IMAGE_KEY"; fi
  fi
  for entry in "${IMAGE_CATALOG[@]}"; do
    IFS='|' read -r v key img desc size <<<"$entry"
    [[ $v == "$ver" ]] || continue
    desc+=" · ~$size"
    [[ $key == "$def" ]] && desc+="  [recomendada]"
    args+=("$key" "$desc")
  done
  text="¿De dónde descargo $(version_label "$ver")?"
  if [[ $ver == *-ee ]]; then
    text+="
Enterprise y Standard solo existen como imagen oficial de Oracle y piden una cuenta de Oracle."
  fi
  if (( blocked )); then
    text+="

AVISO: tu red bloquea Oracle Cloud Storage, de donde se bajan las
imágenes oficiales (pasa en redes de algunos centros educativos)."
    if [[ $ver == *-ee ]]; then
      text+=" Es probable que esta descarga falle en esta red."
    else
      text+=" Usa Docker Hub: es la misma base de datos, empaquetada por Gerald
Venzl (product manager de Oracle)."
    fi
  fi
  IMAGE_KEY=$(ui_menu "Imagen de Oracle" "$text" "$def" "${args[@]}") || cancelled
  IMAGE=$(catalog_image "$IMAGE_KEY")
  DB_EDITION=""
  image_profile "$IMAGE" "$IMAGE_KEY" || die "Imagen no reconocida: $IMAGE"
  maybe_registry_login
}

wizard_image_other() {  # cualquier etiqueta de los repositorios conocidos, o una imagen a mano
  local args=() entry key repo desc tags tag img ed
  for entry in "${REPO_LIST[@]}"; do
    IFS='|' read -r key repo desc <<<"$entry"
    args+=("$key" "$desc")
  done
  key=$(ui_menu "Otra versión" "¿De dónde quieres elegir la versión?" "free-oficial" "${args[@]}") || cancelled
  if [[ $key == manual ]]; then
    while true; do
      img=$(ui_input "Imagen a mano" "Escribe la imagen completa (repositorio:etiqueta). Ejemplos:
docker.io/gvenzl/oracle-xe:21.3.0-slim
container-registry.oracle.com/database/free:23.4.0.0" "${IMAGE:-}") || cancelled
      if valid_image_ref "$img" && image_profile "$img"; then break; fi
      ui_msg "Imagen no reconocida" "Solo se admiten imágenes de Oracle Database de container-registry.oracle.com (database/free, database/express o database/enterprise) o de Docker Hub (gvenzl/oracle-free o gvenzl/oracle-xe), con su etiqueta."
    done
    IMAGE="$img"
  else
    repo=$(repo_of "$key")
    if [[ $key == ee-oficial ]]; then
      tags=$'19.3.0.0\n21.3.0.0'   # el registro no deja listar estas etiquetas sin cuenta
    else
      ui_busy_start "Consultando las versiones disponibles en $repo..."
      tags=$(list_tags "$repo" 2>/dev/null) || tags=""
      ui_busy_stop
      [[ -n $tags ]] || die "No se pudo obtener la lista de versiones de $repo. Revisa la conexión o elige una versión de la lista principal."
    fi
    args=()
    while IFS= read -r tag; do
      [[ -n $tag ]] && args+=("$tag" "$tag")
    done <<<"$tags"
    tag=$(ui_menu "Versiones disponibles" "Elige la versión (etiqueta) de $repo.
Las más nuevas están arriba. «slim» = mínima, «full» = con todo, «faststart» = arranca antes pero ocupa más, «lite» = reducida." "${args[0]}" "${args[@]}") || cancelled
    IMAGE="$repo:$tag"
  fi
  IMAGE_KEY="personalizada"
  DB_EDITION=""
  image_profile "$IMAGE" "$IMAGE_KEY" || die "Imagen no reconocida: $IMAGE"
  if [[ $DB_FAMILY == ee ]]; then
    ed=$(ui_menu "Edición" "¿Qué edición de $DB_LABEL quieres?" enterprise \
      enterprise "Enterprise Edition" standard "Standard Edition 2") || cancelled
    DB_EDITION="$ed"
    image_profile "$IMAGE" "$IMAGE_KEY"
  fi
  maybe_registry_login
}

maybe_registry_login() {  # Enterprise/Standard: cuenta de Oracle (salvo si ya está la imagen)
  (( NEEDS_LOGIN )) || return 0
  if docker_ready && image_exists "$IMAGE"; then return 0; fi
  ui_msg "Cuenta de Oracle necesaria" "$DB_LABEL solo se puede descargar con una cuenta de Oracle (gratuita) y aceptando su licencia:

1. Crea una cuenta en oracle.com si no la tienes.
2. Entra con ella en https://container-registry.oracle.com, abre «Database» > «enterprise» y acepta la licencia.
3. En tu perfil del registro (arriba a la derecha) genera un «Auth Token»: es la contraseña que pide la descarga.

Ahora escribe tu usuario (el correo) y ese token. Solo se usan para descargar la imagen; no se guardan."
  while true; do
    REG_USER=$(ui_input "Cuenta de Oracle" "Usuario de tu cuenta de Oracle (tu correo):" "${REG_USER:-}") || cancelled
    REG_TOKEN=$(ui_password "Cuenta de Oracle" "Auth Token del registro de contenedores de Oracle:") || cancelled
    if [[ -n $REG_USER && -n $REG_TOKEN ]]; then break; fi
    ui_msg "Faltan datos" "Escribe el usuario y el token."
  done
}

wizard_container() {
  local name state def
  if [[ -n $CONTAINER_NAME && $PREV_VERSION == "$DB_VERSION" ]]; then def="$CONTAINER_NAME"; else def=$(default_container_name); fi
  while true; do
    name=$(ui_input "Nombre del contenedor" "Nombre del contenedor de Oracle (letras, números, guion y guion bajo):" "$def") || cancelled
    if ! valid_container_name "$name"; then
      ui_msg "Nombre no válido" "Usa solo letras sin tildes, números, guion (-), punto o guion bajo (_), empezando por letra o número."
      continue
    fi
    CONTAINER_NAME="$name"
    VOLUME_NAME="${CONTAINER_NAME}-datos"
    EXISTING_ACTION=""
    if docker_ready; then
      state=$(container_state)
      if [[ -n $state ]]; then ask_existing_container "$state"; fi
    fi
    [[ $EXISTING_ACTION == rename ]] && { def="${CONTAINER_NAME}-2"; continue; }
    break
  done
  return 0
}

# Lee del contenedor existente su puerto, IP, reinicio, datos e imagen.
read_container_settings() {
  local fmt out pb rp mtype msrc img ip port
  fmt='{{with index .HostConfig.PortBindings "1521/tcp"}}{{with index . 0}}{{.HostIp}} {{.HostPort}}{{end}}{{end}}'
  fmt+='|{{.HostConfig.RestartPolicy.Name}}'
  fmt+='|{{range .Mounts}}{{if or (eq .Destination "/opt/oracle/oradata") (eq .Destination "/u01/app/oracle/oradata")}}{{.Type}} {{if eq .Type "volume"}}{{.Name}}{{else}}{{.Source}}{{end}}{{end}}{{end}}'
  fmt+='|{{.Config.Image}}'
  out=$("${DOCKER[@]}" inspect -f "$fmt" "$CONTAINER_NAME" 2>/dev/null) || return 0
  IFS='|' read -r pb rp mtype img <<<"$out"
  if [[ -n $pb ]]; then
    read -r ip port <<<"$pb"
    [[ -z $port ]] && { port="$ip"; ip=""; }
    [[ $port =~ ^[0-9]+$ ]] && HOST_PORT="$port"
    if [[ $ip == 127.0.0.1 || $ip == localhost ]]; then BIND_ADDR="127.0.0.1"; else BIND_ADDR="0.0.0.0"; fi
  fi
  [[ -n $rp ]] && RESTART_POLICY="$rp"
  DATA_IS_BIND=0
  if [[ -n $mtype ]]; then
    msrc="${mtype#* }"
    if [[ ${mtype%% *} == bind ]]; then DATA_IS_BIND=1; fi
    [[ -n $msrc ]] && VOLUME_NAME="$msrc"
  fi
  [[ -n $img ]] && EXISTING_IMAGE="$img"
  return 0
}

ask_existing_container() {
  local state="$1" cur_img chosen_version="$DB_VERSION" chosen_label="$DB_LABEL" chosen_edition="$DB_EDITION" note=""
  EXISTING_IMAGE="?"
  read_container_settings
  cur_img="$EXISTING_IMAGE"
  if image_profile "$cur_img"; then
    if [[ $DB_VERSION != "$chosen_version" ]]; then
      note="
OJO: ese contenedor tiene $DB_LABEL y has elegido $chosen_label. Sus datos no sirven para otra versión: usa otro nombre o bórralo."
    fi
  else
    note="
OJO: ese contenedor usa una imagen que esta herramienta no reconoce."
  fi
  # Se recupera el perfil de la versión elegida (se cambiará si se conserva el contenedor)
  DB_EDITION="$chosen_edition"
  image_profile "$IMAGE" "$IMAGE_KEY" || true
  while true; do
    EXISTING_ACTION=$(ui_menu "El contenedor ya existe" "Ya existe un contenedor llamado '$CONTAINER_NAME' (estado: $state).
Imagen: $cur_img$note

¿Qué quieres hacer?" rename \
      rename "Usar otro nombre para el nuevo contenedor (los dos pueden convivir)" \
      keep "Conservarlo: arrancarlo y aplicar contraseñas y usuario" \
      recreate "Recrearlo conservando los datos (para cambiar puerto u opciones)" \
      wipe "Borrarlo TODO (contenedor y datos) y empezar de cero") || cancelled
    if [[ $EXISTING_ACTION != wipe ]]; then break; fi
    if ui_yesno "Confirmar borrado" "Se borrarán el contenedor '$CONTAINER_NAME' y el volumen '$VOLUME_NAME' con TODAS tus tablas y datos. No se puede deshacer.

¿Seguro que quieres borrarlo todo?" no; then break; fi
  done
  if [[ $EXISTING_ACTION == keep ]]; then
    image_profile "$cur_img" || die "No se puede gestionar el contenedor '$CONTAINER_NAME': su imagen ($cur_img) no es de Oracle Database."
    IMAGE="$cur_img"
    IMAGE_KEY=$(catalog_key_for_image "$cur_img") || IMAGE_KEY="personalizada"
  fi
  return 0
}

wizard_port() {
  local port def="$HOST_PORT"
  if [[ $EXISTING_ACTION != recreate && $EXISTING_ACTION != wipe ]] && port_in_use "$def"; then
    def=$(free_port_from "$def")
  fi
  while true; do
    port=$(ui_input "Puerto" "Puerto de tu equipo en el que escuchará Oracle.
El estándar es 1521; si ya lo usa otra base de datos se propone el siguiente libre." "$def") || cancelled
    if [[ ! $port =~ ^[1-9][0-9]{3,4}$ ]] || (( port < 1024 || port > 65535 )); then
      ui_msg "Puerto no válido" "Escribe un número entre 1024 y 65535."
      continue
    fi
    if [[ $EXISTING_ACTION != recreate && $EXISTING_ACTION != wipe ]] && port_in_use "$port"; then
      if ! ui_yesno "Puerto ocupado" "El puerto $port ya lo usa otro programa de este equipo.

¿Quieres usarlo igualmente? (Elige «No» para escribir otro)" no; then
        continue
      fi
    fi
    break
  done
  HOST_PORT="$port"
}

wizard_network() {
  local def="no"
  [[ $BIND_ADDR == 0.0.0.0 ]] && def="si"
  if ui_yesno "Acceso desde otros equipos" "¿Quieres que OTROS equipos de tu red puedan conectarse a esta base de datos?

- No (recomendado): solo se podrá conectar desde este mismo equipo.
- Sí: cualquiera de tu red podrá intentar conectarse al puerto $HOST_PORT." "$def"; then
    BIND_ADDR="0.0.0.0"
  else
    BIND_ADDR="127.0.0.1"
  fi
}

ask_new_password() {  # ask_new_password "descripción" → contraseña por stdout
  local p1 p2 problem
  while true; do
    p1=$(ui_password "Contraseña" "Contraseña para $1.

$PWD_RULES") || return 1
    if problem=$(password_problem "$p1"); then
      ui_msg "Contraseña no válida" "$problem"
      continue
    fi
    p2=$(ui_password "Confirmar contraseña" "Vuelve a escribir la contraseña para $1:") || return 1
    if [[ $p1 != "$p2" ]]; then
      ui_msg "No coinciden" "Las dos contraseñas no coinciden. Inténtalo otra vez."
      continue
    fi
    printf '%s' "$p1"
    return 0
  done
}

wizard_admin_password() {
  ADMIN_PWD=$(ask_new_password "los administradores $(admin_names)") || cancelled
}

wizard_app_user() {
  local name problem
  if ! ui_yesno "Usuario de trabajo" "¿Crear un usuario propio para tus prácticas en $DB_SERVICE?

Es lo recomendado: no conviene trabajar con SYS ni SYSTEM. Tendrá $(role_text)." si; then
    APP_USER=""
    APP_PWD=""
    return 0
  fi
  while true; do
    name=$(ui_input "Usuario de trabajo" "Nombre del usuario (letras sin tildes, números y _, empezando por letra):" "${APP_USER:-alumno}") || cancelled
    if problem=$(user_problem "$name"); then
      ui_msg "Nombre no válido" "$problem"
      continue
    fi
    break
  done
  APP_USER="${name^^}"
  if ui_yesno "Contraseña de $APP_USER" "¿Usar para $APP_USER la misma contraseña que para los administradores?

(Más cómodo; menos seguro. Si dices «No», te pediré otra.)" no; then
    APP_PWD="$ADMIN_PWD"
  else
    APP_PWD=$(ask_new_password "el usuario $APP_USER") || cancelled
  fi
}

wizard_autostart() {
  if [[ $EXISTING_ACTION != keep ]]; then
    local rdef="si"
    [[ $RESTART_POLICY == no ]] && rdef="no"
    if ui_yesno "Arranque automático de Oracle" "¿Quieres que Oracle arranque solo cada vez que se inicie Docker?

(Si dices «No», tendrás que usar '$APP_CMD iniciar' cada vez.)" "$rdef"; then
      RESTART_POLICY="unless-stopped"
    else
      RESTART_POLICY="no"
    fi
  fi
  if [[ $ENGINE == desktop ]]; then
    local def="no"
    [[ $DD_AUTOSTART == yes ]] && def="si"
    if ui_yesno "Docker Desktop al iniciar sesión" "¿Quieres que Docker Desktop se abra solo al iniciar sesión en Ubuntu?

Docker Desktop reserva varios GB de RAM mientras está abierto. Si dices «No», '$APP_CMD iniciar' lo abrirá cuando lo necesites." "$def"; then
      DD_AUTOSTART="yes"
    else
      DD_AUTOSTART="no"
    fi
  fi
}

wizard_extras() {
  local s1="OFF" s2="OFF"
  [[ " $EXTRAS " == *" sqlcl "* ]] && s1="ON"
  [[ " $EXTRAS " == *" sqldeveloper "* ]] && s2="ON"
  EXTRAS=$(ui_checklist "Herramientas opcionales" "La base de datos ya trae SQL*Plus dentro del contenedor ('$APP_CMD sql').
Si quieres, también puedo instalar en tu Ubuntu (espacio para marcar):" \
    sqlcl "SQLcl: línea de comandos moderna de Oracle (~120 MB + Java 17)" "$s1" \
    sqldeveloper "SQL Developer 24.3.1: entorno gráfico (~560 MB + JDK 17)" "$s2") || cancelled
}

wizard_summary() {
  local engine_txt image_txt extras_txt user_txt cont_txt dl=""
  if [[ $ENGINE == desktop ]]; then
    if (( DD_INSTALLED )); then engine_txt="Docker Desktop (ya instalado)"; else engine_txt="Docker Desktop (se instalará)"; dl="Docker Desktop ~450 MB"; fi
  else
    if (( ENGINE_INSTALLED )); then engine_txt="Docker Engine (ya instalado)"; else engine_txt="Docker Engine (se instalará)"; fi
  fi
  image_txt="$IMAGE"
  if [[ $EXISTING_ACTION != keep ]]; then
    local size
    size=$(catalog_get "$IMAGE_KEY" 5 2>/dev/null) || size=""
    if [[ -n $size ]]; then dl+="${dl:+, }imagen ~$size"; else dl+="${dl:+, }imagen (tamaño según la versión)"; fi
  fi
  case $EXISTING_ACTION in
    keep) cont_txt="$CONTAINER_NAME (se conserva tal cual)" ;;
    recreate) cont_txt="$CONTAINER_NAME (se recrea; los datos se conservan)" ;;
    wipe) cont_txt="$CONTAINER_NAME (se BORRA y se crea de cero)" ;;
    *) cont_txt="$CONTAINER_NAME (datos en el volumen $VOLUME_NAME)" ;;
  esac
  user_txt="${APP_USER:-no se crea}"
  extras_txt="${EXTRAS:-ninguna}"
  local restart_txt="sí, con Docker" text
  [[ $RESTART_POLICY == no ]] && restart_txt="no"
  text="Esto es lo que se va a hacer:
$(sum_line "Versión" "$DB_LABEL")$(sum_line "Docker" "$engine_txt")$(sum_line "Imagen" "$image_txt")$(sum_line "Contenedor" "$cont_txt")$(sum_line "Puerto" "$BIND_ADDR:$HOST_PORT")$(sum_line "Arranque auto." "$restart_txt")$(sum_line "Usuario" "$user_txt (en $DB_SERVICE)")$(sum_line "Herramientas" "$extras_txt")"
  if (( ${#REMOVE_CONFLICTS[@]} )); then text+="$(sum_line "Se desinstala" "${REMOVE_CONFLICTS[*]}")"; fi
  if [[ -n $dl ]]; then text+="

Descargas aproximadas: $dl."; fi
  if [[ $DB_FAMILY == ee && $EXISTING_ACTION != keep ]]; then text+="
La primera creación de la base de datos tarda $FIRST_HINT."; fi
  text+="

¿Empezamos?"
  UI_YES="Instalar" UI_NO="Cancelar" ui_yesno "Resumen" "$text" si
}

sum_line() {  # sum_line "etiqueta" "valor" → línea del resumen (empieza con salto de línea)
  if [[ $UI_MODE == gui ]]; then
    printf '\n• %s: %s' "$1" "$2"
  else
    local dots="................"
    printf '\n  %s %s %s' "$1" "${dots:0:$((16 - ${#1}))}" "$2"
  fi
}

# --- Asistente en modo gráfico: menos ventanas, con varias opciones juntas ----
wizard_gui() {
  local text
  text="$(welcome_text)"
  if (( ${#PF_WARN[@]} )); then text+=$'\n\nAvisos:\n'"$(printf -- '• %s\n' "${PF_WARN[@]}")"; fi
  UI_YES="Empezar" UI_NO="Salir" ui_yesno "Bienvenida" "$text" si || cancelled
  wizard_engine
  wizard_conflicts
  wizard_version
  wizard_container
  if [[ $EXISTING_ACTION != keep ]]; then
    wizard_port
  fi
  wizard_gui_options
  wizard_gui_passwords
  wizard_summary || cancelled
}

wizard_gui_options() {  # una sola lista con todas las opciones de sí/no
  local items=() sel name problem
  local o_restart="ON" o_net="OFF" o_dd="OFF" o_sqlcl="OFF" o_sqldev="OFF"
  [[ $RESTART_POLICY == no ]] && o_restart="OFF"
  [[ $BIND_ADDR == 0.0.0.0 ]] && o_net="ON"
  [[ $DD_AUTOSTART == yes ]] && o_dd="ON"
  [[ " $EXTRAS " == *" sqlcl "* ]] && o_sqlcl="ON"
  [[ " $EXTRAS " == *" sqldeveloper "* ]] && o_sqldev="ON"
  items+=(usuario "Crear un usuario de trabajo para las prácticas (recomendado)" ON)
  if [[ $EXISTING_ACTION != keep ]]; then
    items+=(autoarranque "Arrancar Oracle automáticamente cuando se inicie Docker" "$o_restart")
    items+=(red "Permitir conexiones desde otros equipos de la red (no recomendado)" "$o_net")
  fi
  if [[ $ENGINE == desktop ]]; then
    items+=(dd_login "Abrir Docker Desktop al iniciar sesión en Ubuntu" "$o_dd")
  fi
  items+=(sqlcl "Instalar SQLcl, la línea de comandos de Oracle (~120 MB + Java 17)" "$o_sqlcl")
  items+=(sqldeveloper "Instalar SQL Developer 24.3.1, entorno gráfico (~560 MB + JDK 17)" "$o_sqldev")
  sel=$(ui_checklist "Opciones" "Marca lo que quieras (las marcadas son las recomendadas):" "${items[@]}") || cancelled
  sel=" $sel "
  if [[ $EXISTING_ACTION != keep ]]; then
    if [[ $sel == *" autoarranque "* ]]; then RESTART_POLICY="unless-stopped"; else RESTART_POLICY="no"; fi
    if [[ $sel == *" red "* ]]; then BIND_ADDR="0.0.0.0"; else BIND_ADDR="127.0.0.1"; fi
  fi
  if [[ $ENGINE == desktop ]]; then
    if [[ $sel == *" dd_login "* ]]; then DD_AUTOSTART="yes"; else DD_AUTOSTART="no"; fi
  fi
  EXTRAS=""
  if [[ $sel == *" sqlcl "* ]]; then EXTRAS="sqlcl"; fi
  if [[ $sel == *" sqldeveloper "* ]]; then EXTRAS="${EXTRAS:+$EXTRAS }sqldeveloper"; fi
  if [[ $sel != *" usuario "* ]]; then
    APP_USER=""
    return 0
  fi
  while true; do
    name=$(ui_input "Usuario de trabajo" "Nombre de tu usuario de trabajo en $DB_SERVICE (letras sin tildes, números y _, empezando por letra). Tendrá $(role_text)." "${APP_USER:-alumno}") || cancelled
    if problem=$(user_problem "$name"); then
      ui_msg "Nombre no válido" "$problem"
      continue
    fi
    break
  done
  APP_USER="${name^^}"
}

wizard_gui_passwords() {  # todas las contraseñas en un solo formulario
  local out a1 a2 u1 u2 problem fields
  fields=(--add-password="Contraseña de $(admin_names)" --add-password="Repite esa contraseña")
  if [[ -n $APP_USER ]]; then
    fields+=(--add-password="Contraseña de $APP_USER (vacía = la misma)" --add-password="Repite la contraseña de $APP_USER")
  fi
  while true; do
    out=$(zen --forms --title="Contraseñas" --width=560 --separator=$'\x1f' \
      --text="8 a 30 caracteres, empezando por letra, con al menos una mayúscula, una minúscula y un número.
Solo letras sin tildes, números, _ y #. No se guardan en ningún sitio: apúntalas." \
      --ok-label="Aceptar" --cancel-label="Cancelar" "${fields[@]}") || cancelled
    a1="" a2="" u1="" u2=""
    IFS=$'\x1f' read -r a1 a2 u1 u2 <<<"$out" || true
    if problem=$(password_problem "$a1"); then
      ui_msg "Contraseña no válida" "Contraseña de administración: $problem"
      continue
    fi
    if [[ $a1 != "$a2" ]]; then
      ui_msg "No coinciden" "Las dos contraseñas de administración no coinciden."
      continue
    fi
    if [[ -n $APP_USER ]]; then
      if [[ -z $u1 && -z $u2 ]]; then
        u1="$a1"
      elif problem=$(password_problem "$u1"); then
        ui_msg "Contraseña no válida" "Contraseña de $APP_USER: $problem"
        continue
      elif [[ $u1 != "$u2" ]]; then
        ui_msg "No coinciden" "Las dos contraseñas de $APP_USER no coinciden."
        continue
      fi
    fi
    ADMIN_PWD="$a1"
    APP_PWD="$u1"
    return 0
  done
}

# =============================================================================
#  Pasos de instalación
# =============================================================================
install_base_packages() {
  local pkgs=(ca-certificates curl gnupg)
  if [[ $ENGINE == desktop ]]; then
    pkgs+=(cpu-checker)
    [[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || pkgs+=(gnome-terminal)
  fi
  if [[ -n $EXTRAS ]]; then pkgs+=(unzip); fi
  apt_install "Paquetes básicos" "${pkgs[@]}" || die "No se pudieron instalar los paquetes básicos."
}

setup_kvm() {
  if ! grep -Eqw 'vmx|svm' /proc/cpuinfo; then
    die "La CPU no ofrece virtualización$(virt_hint). Vuelve a ejecutar el asistente y elige Docker Engine."
  fi
  if [[ ! -e /dev/kvm ]]; then
    ensure_sudo
    local mod="kvm_intel"
    grep -qw svm /proc/cpuinfo && mod="kvm_amd"
    run "Cargando los módulos de KVM" "${SUDO[@]}" modprobe -a kvm "$mod" || true
    if [[ ! -e /dev/kvm ]] && (( ! DRY_RUN )); then
      die "No existe /dev/kvm. Activa la virtualización (Intel VT-x o AMD-V/SVM) en la BIOS/UEFI y vuelve a intentarlo."
    fi
  fi
  if command -v kvm-ok >/dev/null 2>&1; then
    log "kvm-ok: $(kvm-ok 2>&1 || true)"
  fi
  ok "Virtualización KVM disponible"
  if ! in_group_db kvm; then
    ensure_sudo
    run "Añadiendo tu usuario al grupo kvm" "${SUDO[@]}" usermod -aG kvm "$USER" || die "No se pudo añadir tu usuario al grupo kvm."
  fi
  if [[ -r /dev/kvm && -w /dev/kvm ]] || (( DRY_RUN )); then
    ok "Tu usuario tiene acceso a /dev/kvm"
  else
    NEEDS_RELOGIN=1
    warn "Tu sesión actual aún no tiene acceso a /dev/kvm: hará falta cerrar sesión y volver a entrar."
  fi
}

remove_conflicts() {
  (( ${#REMOVE_CONFLICTS[@]} )) || return 0
  ensure_sudo
  run "Desinstalando paquetes de Docker no oficiales (${REMOVE_CONFLICTS[*]})" \
    "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get remove -y -o DPkg::Lock::Timeout=300 "${REMOVE_CONFLICTS[@]}" \
    || die "No se pudieron desinstalar los paquetes en conflicto."
}

setup_docker_repo() {
  if grep -rqsE '^[^#]*download\.docker\.com' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    ok "Repositorio oficial de Docker ya configurado"
    return 0
  fi
  ensure_sudo
  make_tmp
  local key="$TMP_DIR/docker.asc" src="$TMP_DIR/docker.sources"
  run "Descargando la clave GPG de Docker" curl -fsSL --retry 3 -o "$key" "$DOCKER_GPG_URL" \
    || die "No se pudo descargar la clave de Docker."
  if (( ! DRY_RUN )); then
    if command -v gpg >/dev/null 2>&1; then
      local fpr
      mkdir -p "$TMP_DIR/gnupg"
      chmod 700 "$TMP_DIR/gnupg"
      fpr=$(GNUPGHOME="$TMP_DIR/gnupg" gpg --batch --show-keys --with-colons "$key" 2>/dev/null \
        | awk -F: '/^fpr:/ {print $10; exit}') || fpr=""
      [[ $fpr == "$DOCKER_GPG_FPR" ]] || die "La clave descargada NO coincide con la huella oficial de Docker ($DOCKER_GPG_FPR). Se aborta por seguridad."
      ok "Huella de la clave de Docker verificada"
    else
      warn "gpg no está disponible: no se verifica la huella de la clave de Docker."
    fi
  fi
  printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
    "$DOCKER_REPO_URL" "$OS_CODENAME" "$ARCH" >"$src"
  run "Instalando la clave en /etc/apt/keyrings/docker.asc" "${SUDO[@]}" install -D -m 0644 "$key" /etc/apt/keyrings/docker.asc \
    || die "No se pudo instalar la clave de Docker."
  run "Añadiendo el repositorio oficial de Docker" "${SUDO[@]}" install -m 0644 "$src" /etc/apt/sources.list.d/docker.sources \
    || die "No se pudo añadir el repositorio de Docker."
  APT_UPDATED=0
  apt_update_once
}

install_docker_desktop() {
  if pkg_installed docker-desktop; then
    ok "Docker Desktop ya está instalado (versión $(pkg_version docker-desktop))"
    return 0
  fi
  remove_conflicts
  setup_docker_repo
  make_tmp
  local dir="$TMP_DIR/docker-desktop" deb sums attempt expected actual
  deb="$dir/docker-desktop-amd64.deb"
  sums="$dir/checksums.txt"
  mkdir -p "$dir"
  chmod 755 "$TMP_DIR" "$dir"   # el usuario _apt debe poder leer el .deb
  for attempt in 1 2; do
    info "Descargando Docker Desktop (~450 MB)..."
    download "$DD_DEB_URL" "$deb" || die "No se pudo descargar Docker Desktop."
    (( DRY_RUN )) && break
    if ! curl -fsSL --retry 3 -o "$sums" "$DD_SUMS_URL"; then
      warn "No se pudo descargar checksums.txt: se comprueba solo que el paquete sea válido."
      dpkg-deb --info "$deb" >/dev/null 2>&1 || die "El paquete descargado está dañado."
      break
    fi
    expected=$(awk '$2 ~ /docker-desktop-amd64\.deb$/ {print $1}' "$sums")
    actual=$(sha256sum "$deb" | awk '{print $1}')
    if [[ -n $expected && $expected == "$actual" ]]; then
      ok "Suma SHA-256 del paquete verificada"
      break
    fi
    (( attempt == 2 )) && die "La suma SHA-256 de Docker Desktop no coincide. Vuelve a intentarlo más tarde."
    warn "La suma SHA-256 no coincide (¿se publicó una versión nueva durante la descarga?). Se repite la descarga."
  done
  chmod 644 "$deb" 2>/dev/null || true
  ensure_sudo
  apt_update_once
  run "Instalando Docker Desktop (puede tardar varios minutos)" "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -o DPkg::Lock::Timeout=300 "$deb" || die "No se pudo instalar Docker Desktop."
}

install_docker_engine() {
  if pkg_installed docker-ce; then
    ok "Docker Engine ya está instalado (versión $(pkg_version docker-ce))"
  else
    remove_conflicts
    setup_docker_repo
    apt_install "Instalando Docker Engine" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      || die "No se pudo instalar Docker Engine."
  fi
}

start_docker() {
  if [[ $ENGINE == desktop ]]; then start_docker_desktop; else start_docker_engine; fi
}

relogin_exit() {
  INSTALL_STAGE="relogin"
  save_config
  printf '\n%s\n' "${C_YELLOW}${C_BOLD}$S_RULE${C_RESET}"
  printf '%s\n' "${C_YELLOW}${C_BOLD}  Hace falta CERRAR SESIÓN para continuar${C_RESET}"
  printf '%s\n\n' "${C_YELLOW}${C_BOLD}$S_RULE${C_RESET}"
  printf '%s\n' "Tu usuario se ha añadido al grupo «kvm», pero la sesión actual todavía no lo sabe."
  printf '%s\n\n' "Docker Desktop no podrá arrancar hasta que cierres sesión y vuelvas a entrar (o reinicies)."
  printf '%s\n' "Después, vuelve a ejecutar:"
  printf '\n    %s\n\n' "${C_BOLD}$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo ./oracle-db.sh) instalar${C_RESET}"
  printf '%s\n' "Se recordarán tus respuestas (salvo las contraseñas) y se continuará donde lo dejaste."
  if [[ $UI_MODE == gui ]]; then
    gui_progress_close
    ui_msg "Hace falta cerrar sesión" "Tu usuario se ha añadido al grupo «kvm», pero la sesión actual todavía no lo sabe, así que Docker Desktop no podría arrancar.

1. Cierra sesión en Ubuntu y vuelve a entrar (o reinicia).
2. Vuelve a abrir el instalador: recordará tus respuestas (salvo las contraseñas) y seguirá donde lo dejó."
  fi
  exit 0
}

start_docker_desktop() {
  (( NEEDS_RELOGIN )) && relogin_exit
  if [[ $DD_AUTOSTART == yes ]]; then
    run "Activando el inicio automático de Docker Desktop" systemctl --user enable docker-desktop || true
  fi
  set_docker_cmd
  if docker_desktop_ready; then
    ok "Docker Desktop ya está en marcha"
  else
    run "Abriendo Docker Desktop" systemctl --user start docker-desktop || die "No se pudo arrancar Docker Desktop."
    printf '\n%s\n' "${C_YELLOW}${C_BOLD}  ACCIÓN NECESARIA en la ventana de Docker Desktop:${C_RESET}"
    printf '%s\n' "  1. La primera vez aparece el «Docker Subscription Service Agreement»: léelo y pulsa «Accept»."
    printf '%s\n' "     (Es gratuito para uso personal y educativo.)"
    printf '%s\n' "  2. Puedes saltarte el inicio de sesión y la encuesta («Skip» / «Continue without signing in»)."
    printf '%s\n\n' "  La instalación seguirá sola en cuanto Docker Desktop esté listo."
    if command -v notify-send >/dev/null 2>&1 && (( ! DRY_RUN )); then
      notify-send "$APP_NAME" "Acepta el acuerdo de Docker Desktop para continuar" 2>/dev/null || true
    fi
    if [[ $UI_MODE == gui ]] && (( ! DRY_RUN )); then
      zen --info --title="Acción necesaria en Docker Desktop" --no-markup --width=540 --ok-label="Entendido" \
        --text="Se está abriendo Docker Desktop.

1. La primera vez aparece el «Docker Subscription Service Agreement»: léelo y pulsa «Accept» (es gratuito para uso personal y educativo).
2. Puedes saltarte el inicio de sesión y la encuesta («Skip»).

La instalación seguirá sola en cuanto Docker Desktop esté listo (esta ventana se cerrará sola)." &
      GUI_INFO_PID=$!
    fi
    wait_for "Esperando a que Docker Desktop esté listo" 1200 docker_desktop_ready \
      || die "Docker Desktop no ha arrancado en 20 minutos. Ábrelo desde el menú de aplicaciones, revisa si muestra algún error y vuelve a ejecutar '$APP_CMD instalar'. Registros de Docker Desktop: ~/.docker/desktop/log/"
    if [[ -n $GUI_INFO_PID ]]; then
      kill "$GUI_INFO_PID" 2>/dev/null || true
      GUI_INFO_PID=""
    fi
  fi
  if (( ! DRY_RUN )); then
    docker context use desktop-linux >>"$LOG_FILE" 2>&1 || true
  fi
  check_desktop_memory
}

check_desktop_memory() {
  (( DRY_RUN )) && return 0
  local bytes mb choice
  while true; do
    bytes=$("${DOCKER[@]}" info --format '{{.MemTotal}}' 2>/dev/null) || bytes=0
    [[ $bytes =~ ^[0-9]+$ ]] || bytes=0
    mb=$((bytes / 1048576))
    if (( mb >= VM_MEM_MIN_MB )); then
      ok "Memoria disponible para Docker: $(mb_to_gb "$mb") GB"
      return 0
    fi
    choice=$(ui_menu "Poca memoria para Docker" "Docker Desktop solo tiene $(mb_to_gb "$mb") GB de RAM y $DB_LABEL necesita al menos $(mb_to_gb "$VM_MEM_MIN_MB") GB.

Cómo aumentarla:
 1. En Docker Desktop abre Settings (icono del engranaje).
 2. Resources > Advanced > Memory limit: súbelo (4 GB o más).
 3. Pulsa «Apply & restart» y espera a que termine." check \
      check "Ya lo he cambiado: comprobar otra vez" \
      continue "Continuar de todas formas (puede fallar)" \
      cancel "Cancelar la instalación") || choice="cancel"
    case $choice in
      check) wait_for "Esperando a Docker Desktop" 300 docker_desktop_ready || true ;;
      continue) warn "Se continúa con poca memoria para Docker."; return 0 ;;
      *) die "Instalación detenida. Aumenta la memoria de Docker Desktop y vuelve a ejecutar '$APP_CMD instalar'." ;;
    esac
  done
}

start_docker_engine() {
  if ! systemctl is-active --quiet docker 2>/dev/null; then
    ensure_sudo
    run "Arrancando el servicio de Docker" "${SUDO[@]}" systemctl enable --now docker.service || die "No se pudo arrancar Docker."
  else
    ok "El servicio de Docker está en marcha"
  fi
  if ! in_group_db docker; then
    ensure_sudo
    run "Añadiendo tu usuario al grupo docker" "${SUDO[@]}" usermod -aG docker "$USER" || true
    DOCKER_GROUP_ADDED=1
  fi
  set_docker_cmd
  wait_for "Comprobando que Docker responde" 120 docker_ready || die "Docker no responde. Prueba: sudo systemctl status docker"
  if (( ! DRY_RUN )); then
    local bytes
    bytes=$("${DOCKER[@]}" info --format '{{.MemTotal}}' 2>/dev/null) || bytes=0
    [[ $bytes =~ ^[0-9]+$ ]] || bytes=0
    if (( bytes / 1048576 < VM_MEM_MIN_MB )); then
      warn "Este equipo tiene poca memoria para $DB_LABEL (se recomiendan $(mb_to_gb "$VM_MEM_MIN_MB") GB libres)."
    fi
  fi
}

pull_progress() {  # resume la salida de «docker pull» en la ventana de progreso
  local line id start=$SECONDS
  local -A seen=() finished=()
  while IFS= read -r line; do
    printf '%s\n' "$line" >>"${LOG_FILE:-/dev/null}"
    if [[ $line =~ ^([0-9a-f]{12}):\ (.*)$ ]]; then
      id="${BASH_REMATCH[1]}"
      seen[$id]=1
      case ${BASH_REMATCH[2]} in
        "Pull complete"* | "Already exists"*) finished[$id]=1 ;;
      esac
    fi
    if (( ${#seen[@]} )); then
      gui_note "Descargando la imagen: ${#finished[@]} de ${#seen[@]} partes listas ($(fmt_time $((SECONDS - start))))"
    else
      gui_note "Descargando la imagen ($(fmt_time $((SECONDS - start))))"
    fi
  done
  return 0
}

docker_pull() {  # docker_pull imagen → 0 si se descarga
  local img="$1" errf="$TMP_DIR/pull.err"
  if (( DRY_RUN )); then
    printf '%s docker pull %s\n' "${C_DIM}[simulación]${C_RESET}" "$img"
    return 0
  fi
  log "PULL $img"
  if [[ $UI_MODE == gui ]]; then
    if "${DOCKER[@]}" pull "$img" 2>"$errf" | pull_progress; then return 0; fi
  elif "${DOCKER[@]}" pull "$img" 2>"$errf"; then
    return 0
  fi
  cat "$errf" >&2
  cat "$errf" >>"$LOG_FILE"
  # Docker Desktop sin «pass» inicializado puede fallar al consultar credenciales:
  # se reintenta de forma anónima (las imágenes Free y XE son públicas).
  if [[ $ENGINE == desktop ]] && grep -qi 'error getting credentials' "$errf"; then
    warn "Reintentando la descarga sin el almacén de credenciales de Docker Desktop..."
    mkdir -p "$TMP_DIR/docker-anon"
    printf '{}\n' >"$TMP_DIR/docker-anon/config.json"
    if DOCKER_CONFIG="$TMP_DIR/docker-anon" docker -H "unix://$HOME/.docker/desktop/docker.sock" pull "$img" 2>"$errf"; then
      return 0
    fi
    cat "$errf" >&2
  fi
  return 1
}

# Enterprise/Standard: inicio de sesión temporal en el registro de Oracle y descarga.
# Las credenciales viajan por stdin y se borran al terminar (no quedan guardadas).
registry_pull() {  # registry_pull imagen
  local img="$1" cfg="$TMP_DIR/registro-oracle" sock rc=0 d=()
  if (( DRY_RUN )); then
    printf '%s docker login %s (cuenta de Oracle) + docker pull %s\n' "${C_DIM}[simulación]${C_RESET}" "$ORACLE_REGISTRY" "$img"
    return 0
  fi
  [[ -n $REG_USER && -n $REG_TOKEN ]] || maybe_registry_login
  mkdir -p "$cfg"
  chmod 700 "$cfg"
  printf '{}\n' >"$cfg/config.json"
  if [[ $ENGINE == desktop ]]; then sock="unix://$HOME/.docker/desktop/docker.sock"; else sock="unix:///var/run/docker.sock"; fi
  d=(env DOCKER_CONFIG="$cfg" docker -H "$sock")
  [[ ${DOCKER[0]} == sudo ]] && d=("${SUDO[@]}" "${d[@]}")
  info "Iniciando sesión en $ORACLE_REGISTRY como $REG_USER..."
  if ! printf '%s\n' "$REG_TOKEN" | "${d[@]}" login "$ORACLE_REGISTRY" --username "$REG_USER" --password-stdin >>"$LOG_FILE" 2>&1; then
    rm -rf -- "$cfg"
    err "No se pudo iniciar sesión: revisa el usuario y el Auth Token."
    return 1
  fi
  ok "Sesión iniciada en el registro de Oracle"
  if [[ $UI_MODE == gui ]]; then
    "${d[@]}" pull "$img" 2>"$TMP_DIR/pull.err" | pull_progress || rc=$?
  else
    "${d[@]}" pull "$img" 2>"$TMP_DIR/pull.err" || rc=$?
  fi
  "${d[@]}" logout "$ORACLE_REGISTRY" >/dev/null 2>&1 || true
  rm -rf -- "$cfg"
  REG_TOKEN=""
  if (( rc != 0 )); then
    cat "$TMP_DIR/pull.err" >&2
    cat "$TMP_DIR/pull.err" >>"$LOG_FILE"
  fi
  return "$rc"
}

pull_image() {
  if image_exists "$IMAGE"; then
    ok "La imagen ya está descargada: $IMAGE"
    return 0
  fi
  make_tmp
  if (( NEEDS_LOGIN )); then
    info "Descargando $IMAGE. Es grande: puede tardar bastante..."
    if registry_pull "$IMAGE"; then
      ok "Imagen descargada: $IMAGE"
      return 0
    fi
    die "No se pudo descargar $IMAGE. Comprueba tu usuario y tu Auth Token, que aceptaste la licencia de «enterprise» en $ORACLE_REGISTRY y que tu red permite descargar de Oracle Cloud."
  fi
  local attempt
  for attempt in 1 2 3; do
    info "Descargando $IMAGE (intento $attempt de 3). Puede tardar bastante según tu conexión..."
    if docker_pull "$IMAGE"; then
      ok "Imagen descargada: $IMAGE"
      return 0
    fi
    if is_oracle_registry_image "$IMAGE" \
      && grep -qiE 'objectstorage|oraclecloud|i/o timeout|no such host|connection refused|tls' "$TMP_DIR/pull.err" 2>/dev/null; then
      break
    fi
    if (( attempt < 3 )); then
      warn "La descarga ha fallado; se reintenta en 10 segundos."
      sleep 10
    fi
  done
  local alt
  if alt=$(hub_equivalent_image "$IMAGE"); then
    if ui_yesno "No se pudo descargar la imagen oficial" "No se ha podido descargar la imagen oficial de Oracle. Casi siempre es porque la red bloquea el almacenamiento de Oracle Cloud (pasa en algunas redes de centros educativos).

¿Descargar en su lugar la imagen equivalente de Docker Hub?

   $alt" si; then
      IMAGE="$alt"
      IMAGE_KEY=$(catalog_key_for_image "$alt") || IMAGE_KEY="personalizada"
      image_profile "$IMAGE" "$IMAGE_KEY" || true
      pull_image
      return
    fi
  fi
  die "No se pudo descargar la imagen $IMAGE. Revisa tu conexión y vuelve a ejecutar '$APP_CMD instalar'."
}

wait_db() {  # wait_db nueva|reinicio → espera a que la base de datos esté lista
  local mode="$1" timeout="$FIRST_TIMEOUT" start=$SECONDS i=0 frames='|/-\' st state restarts logs last
  if (( DRY_RUN )); then
    printf '%s Esperar el mensaje «DATABASE IS READY TO USE!»\n' "${C_DIM}[simulación]${C_RESET}"
    return 0
  fi
  if [[ $mode == reinicio ]]; then
    timeout=900
    if db_sql_ready; then ok "Base de datos abierta y lista"; return 0; fi
  fi
  if [[ $mode == nueva ]]; then
    info "Oracle está creando la base de datos: tarda $FIRST_HINT. No cierres esta ventana."
  else
    info "Arrancando Oracle (normalmente menos de un minuto)..."
  fi
  while true; do
    st=$("${DOCKER[@]}" inspect -f '{{.State.Status}} {{.RestartCount}}' "$CONTAINER_NAME" 2>/dev/null) || st="missing 0"
    state=${st%% *}
    restarts=${st##* }
    if [[ $state != running ]] || (( restarts > 0 )); then
      [[ -t 1 ]] && printf '\r\e[K'
      err "El contenedor se ha detenido de forma inesperada (estado: $state)."
      print_container_logs 40
      return 1
    fi
    logs=$("${DOCKER[@]}" logs --since "$CONTAINER_SINCE" "$CONTAINER_NAME" 2>&1) || logs=""
    if [[ $logs == *"DATABASE IS READY TO USE"* ]]; then break; fi
    if [[ $logs == *"DATABASE SETUP WAS NOT SUCCESSFUL"* ]]; then
      [[ -t 1 ]] && printf '\r\e[K'
      err "La creación de la base de datos ha fallado."
      print_container_logs 40
      return 1
    fi
    if [[ $mode == reinicio ]] && db_sql_ready; then break; fi
    if (( SECONDS - start > timeout )); then
      [[ -t 1 ]] && printf '\r\e[K'
      err "Oracle no ha terminado de arrancar en $((timeout / 60)) minutos."
      print_container_logs 30
      return 1
    fi
    last=$(printf '%s\n' "$logs" | grep -v '^[[:space:]]*$' | tail -n 1 | cut -c1-45) || last=""
    gui_note "Preparando Oracle... $(fmt_time $((SECONDS - start))) · ${last}"
    if [[ -t 1 ]]; then
      printf '\r\e[K %s Preparando Oracle... %s  %s' "${C_CYAN}${frames:i++%4:1}${C_RESET}" \
        "$(fmt_time $((SECONDS - start)))" "${C_DIM}${last}${C_RESET}"
    fi
    sleep 4
  done
  [[ -t 1 ]] && printf '\r\e[K'
  ok "Base de datos lista (en $(fmt_time $((SECONDS - start))))"
}

create_or_reuse_container() {
  local state fresh=1
  state=$(container_state)
  if [[ -n $state && -z $EXISTING_ACTION ]]; then ask_existing_container "$state"; fi
  if [[ $EXISTING_ACTION == rename ]]; then
    die "Ya existe un contenedor '$CONTAINER_NAME'. Vuelve a ejecutar '$APP_CMD instalar' y elige otro nombre."
  fi
  if [[ -n $state ]]; then
    case $EXISTING_ACTION in
      keep)
        if [[ $state != running ]]; then
          CONTAINER_SINCE=$(( $(date +%s) - 5 ))
          run "Arrancando el contenedor existente '$CONTAINER_NAME'" "${DOCKER[@]}" start "$CONTAINER_NAME" \
            || die "No se pudo arrancar el contenedor existente."
        else
          ok "El contenedor '$CONTAINER_NAME' ya está en marcha"
        fi
        wait_db reinicio || die "La base de datos del contenedor existente no arranca. Prueba a reinstalar eligiendo «Borrarlo TODO»."
        return 0
        ;;
      recreate)
        run "Eliminando el contenedor anterior (los datos se conservan)" "${DOCKER[@]}" rm -f "$CONTAINER_NAME" \
          || die "No se pudo eliminar el contenedor anterior."
        ;;
      wipe)
        run "Eliminando el contenedor anterior" "${DOCKER[@]}" rm -f "$CONTAINER_NAME" \
          || die "No se pudo eliminar el contenedor anterior."
        if (( DATA_IS_BIND )); then
          warn "Los datos antiguos estaban en la carpeta $VOLUME_NAME: no se toca (bórrala tú si ya no la quieres)."
          VOLUME_NAME="${CONTAINER_NAME}-datos"
          DATA_IS_BIND=0
        fi
        if volume_exists; then
          run "Eliminando el volumen de datos anterior" "${DOCKER[@]}" volume rm -f "$VOLUME_NAME" \
            || die "No se pudo eliminar el volumen anterior."
        fi
        ;;
    esac
  fi
  if (( DATA_IS_BIND )); then
    fresh=0
    info "Se reutilizan los datos existentes de la carpeta $VOLUME_NAME."
  else
    if volume_exists; then
      fresh=0
      info "Se reutilizan los datos existentes del volumen '$VOLUME_NAME'."
    fi
    run "Creando el volumen de datos '$VOLUME_NAME'" "${DOCKER[@]}" volume create "$VOLUME_NAME" \
      || die "No se pudo crear el volumen de datos."
  fi
  local args=(run -d --name "$CONTAINER_NAME"
    -p "$BIND_ADDR:$HOST_PORT:1521"
    -v "$VOLUME_NAME:$DATA_PATH"
    --restart "$RESTART_POLICY"
    --label "$APP_CMD.gestionado-por=$APP_CMD.sh"
    --label "$APP_CMD.version=$DB_VERSION")
  # Sin contraseña en variables de entorno: la imagen genera una aleatoria temporal
  # y después se cambia por la tuya vía SQL (así no queda en 'docker inspect').
  if [[ $PWD_STYLE == gvenzl ]]; then
    args+=(-e ORACLE_RANDOM_PASSWORD=yes)
  else
    args+=(-e ORACLE_CHARACTERSET=AL32UTF8)
    if [[ $DB_FAMILY == ee ]]; then
      args+=(-e "ORACLE_SID=$CDB_NAME" -e "ORACLE_PDB=$PDB_NAME" -e "ORACLE_EDITION=$DB_EDITION")
    fi
  fi
  [[ $DB_VERSION == 11g-xe ]] && args+=(--shm-size=1g)
  args+=("$IMAGE")
  CONTAINER_SINCE=$(( $(date +%s) - 5 ))
  run "Creando y arrancando el contenedor '$CONTAINER_NAME'" "${DOCKER[@]}" "${args[@]}" \
    || die "No se pudo crear el contenedor. ¿Está ocupado el puerto $HOST_PORT? Compruébalo con: ss -ltnp | grep $HOST_PORT"
  if (( fresh )); then
    wait_db nueva || die "La base de datos no se ha podido crear. Revisa los mensajes anteriores."
  else
    wait_db reinicio || die "La base de datos no ha arrancado con los datos existentes."
  fi
}

configure_db() {
  { admin_sql "$ADMIN_PWD"; printf 'EXIT SUCCESS\n'; } \
    | run_sql_script "Contraseña de $(admin_names) configurada" \
    || die "No se pudo configurar la contraseña de administración."
  if [[ -n $APP_USER ]]; then
    { pdb_switch_sql; user_sql "$APP_USER" "$APP_PWD"; printf 'EXIT SUCCESS\n'; } \
      | run_sql_script "Usuario $APP_USER listo en $DB_SERVICE" \
      || die "No se pudo crear el usuario $APP_USER."
  fi
  (( DRY_RUN )) && return 0
  if verify_login SYSTEM "$ADMIN_PWD"; then
    ok "Conexión comprobada: SYSTEM@$DB_SERVICE"
  else
    warn "No se pudo comprobar la conexión de SYSTEM (revisa con: $APP_CMD sql system)."
  fi
  if [[ -n $APP_USER ]]; then
    if verify_login "$APP_USER" "$APP_PWD"; then
      ok "Conexión comprobada: $APP_USER@$DB_SERVICE"
    else
      warn "No se pudo comprobar la conexión de $APP_USER."
    fi
  fi
}

write_wrapper() {  # write_wrapper destino programa [línea previa]
  local dest="$1" target="$2" pre_line="${3:-}"
  if (( DRY_RUN )); then
    printf '%s crear %s -> %s\n' "${C_DIM}[simulación]${C_RESET}" "$dest" "$target"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  {
    printf '#!/bin/sh\n# Creado por %s.sh\n' "$APP_CMD"
    if [[ -n $pre_line ]]; then printf '%s\n' "$pre_line"; fi
    printf 'exec "%s" "$@"\n' "$target"
  } >"$dest"
  chmod 0755 "$dest"
}

unpack_zip() {  # unpack_zip "descripción" zip carpeta_destino (se reemplaza)
  run "$1" bash -c 'rm -rf -- "$3" && mkdir -p "$2" && unzip -q "$1" -d "$2"' _ "$2" "$(dirname "$3")" "$3"
}

java_major() {
  local v
  v=$(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}') || v=""
  v=${v#1.}
  printf '%s' "${v%%.*}"
}

jdk17_home() { printf '/usr/lib/jvm/java-17-openjdk-%s' "$(dpkg --print-architecture)"; }

install_sqlcl() {
  local major
  major=$(java_major 2>/dev/null) || major=""
  if [[ ! $major =~ ^[0-9]+$ ]] || (( major < 17 )); then
    apt_install "Java 17 para SQLcl" openjdk-17-jre-headless || return 1
  fi
  apt_install "unzip" unzip || return 1
  make_tmp
  info "Descargando SQLcl (~120 MB)..."
  download "$SQLCL_URL" "$TMP_DIR/sqlcl.zip" || return 1
  if (( ! DRY_RUN )) && ! unzip -tq "$TMP_DIR/sqlcl.zip" >/dev/null 2>&1; then
    err "El archivo de SQLcl está dañado."
    return 1
  fi
  unpack_zip "Instalando SQLcl en $DATA_DIR/sqlcl" "$TMP_DIR/sqlcl.zip" "$DATA_DIR/sqlcl" || return 1
  write_wrapper "$BIN_DIR/sql" "$DATA_DIR/sqlcl/bin/sql"
  ok "SQLcl instalado: comando 'sql'"
}

write_sqldeveloper_launcher() {  # acceso de SQL Developer en el menú de aplicaciones
  mkdir -p "$APPS_DIR"
  cat >"$APPS_DIR/$APP_CMD-sqldeveloper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Oracle SQL Developer
Comment=Cliente gráfico para Oracle Database (instalado con $APP_CMD.sh)
Exec="$BIN_DIR/sqldeveloper"
Icon=$DATA_DIR/sqldeveloper/icon.png
Terminal=false
Categories=Development;Database;
EOF
}

install_sqldeveloper() {
  local jdk
  jdk=$(jdk17_home)
  apt_install "JDK 17 para SQL Developer" openjdk-17-jdk || return 1
  apt_install "unzip" unzip || return 1
  make_tmp
  info "Descargando SQL Developer 24.3.1 (~560 MB)..."
  download "$SQLDEV_URL" "$TMP_DIR/sqldeveloper.zip" || return 1
  if (( ! DRY_RUN )) && ! unzip -tq "$TMP_DIR/sqldeveloper.zip" >/dev/null 2>&1; then
    err "El archivo de SQL Developer está dañado."
    return 1
  fi
  unpack_zip "Instalando SQL Developer en $DATA_DIR/sqldeveloper" "$TMP_DIR/sqldeveloper.zip" "$DATA_DIR/sqldeveloper" || return 1
  if (( ! DRY_RUN )); then
    # Indicar el JDK para que no lo pregunte en el primer arranque
    printf '\n# Añadido por %s.sh\nSetJavaHome %s\n' "$APP_CMD" "$jdk" \
      >>"$DATA_DIR/sqldeveloper/sqldeveloper/bin/sqldeveloper.conf"
    chmod +x "$DATA_DIR/sqldeveloper/sqldeveloper.sh"
    write_sqldeveloper_launcher
  fi
  write_wrapper "$BIN_DIR/sqldeveloper" "$DATA_DIR/sqldeveloper/sqldeveloper.sh" "export JAVA_HOME=\"$jdk\""
  ok "SQL Developer instalado: búscalo en el menú de aplicaciones o ejecuta 'sqldeveloper'"
}

install_extras() {
  if [[ -z $EXTRAS ]]; then
    ok "Sin herramientas opcionales (SQL*Plus del contenedor: '$APP_CMD sql')"
    return 0
  fi
  if [[ " $EXTRAS " == *" sqlcl "* ]]; then
    install_sqlcl || warn "SQLcl no se pudo instalar. Puedes reintentarlo con '$APP_CMD instalar'."
  fi
  if [[ " $EXTRAS " == *" sqldeveloper "* ]]; then
    install_sqldeveloper || warn "SQL Developer no se pudo instalar. Puedes reintentarlo con '$APP_CMD instalar'."
  fi
  return 0
}

install_helper() {
  local self
  self=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null) || self=""
  if [[ -z $self || ! -f $self ]]; then
    warn "No se pudo instalar el comando '$APP_CMD' (el script no se está ejecutando desde un archivo)."
    return 0
  fi
  if [[ -e $BIN_DIR/$APP_CMD && $self -ef $BIN_DIR/$APP_CMD ]]; then
    ok "Comando '$APP_CMD' ya instalado en $BIN_DIR"
    return 0
  fi
  run "Instalando el comando '$APP_CMD' en $BIN_DIR" install -D -m 0755 "$self" "$BIN_DIR/$APP_CMD" \
    || warn "No se pudo instalar el comando '$APP_CMD'."
  return 0
}

write_icon() {  # icono propio: base de datos blanca sobre fondo rojo
  cat >"$1" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect x="8" y="8" width="112" height="112" rx="26" fill="#c74634"/>
  <g fill="none" stroke="#ffffff" stroke-width="7" stroke-linecap="round">
    <ellipse cx="64" cy="38" rx="31" ry="11"/>
    <path d="M33 38v52c0 6 14 11 31 11s31-5 31-11V38"/>
    <path d="M33 64c0 6 14 11 31 11s31-5 31-11"/>
  </g>
</svg>
SVG
}

install_desktop_entry() {  # acceso «Oracle Database (Docker)» en el menú de aplicaciones
  [[ -n ${XDG_CURRENT_DESKTOP:-}${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] || return 0
  if (( DRY_RUN )); then
    printf '%s crear el acceso «Oracle Database (Docker)» en el menú de aplicaciones\n' "${C_DIM}[simulación]${C_RESET}"
    return 0
  fi
  mkdir -p "$DATA_DIR" "$APPS_DIR"
  write_icon "$DATA_DIR/$APP_CMD.svg"
  cat >"$APPS_DIR/$APP_CMD.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Oracle Database (Docker)
GenericName=Base de datos Oracle
Comment=Arranca, detén y conéctate a tu base de datos Oracle (instalada con $APP_CMD.sh)
Exec="$BIN_DIR/$APP_CMD" --gui
Icon=$DATA_DIR/$APP_CMD.svg
Terminal=false
Categories=Development;Database;
Keywords=oracle;sql;database;base de datos;
EOF
  ok "Acceso «Oracle Database (Docker)» añadido al menú de aplicaciones"
}

save_config() {
  if (( DRY_RUN )); then
    printf '%s guardar la configuración (sin contraseñas) en %s\n' "${C_DIM}[simulación]${C_RESET}" "$CONFIG_FILE"
    return 0
  fi
  local k
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  {
    printf '# Configuración de %s (generada automáticamente; no contiene contraseñas)\n' "$APP_CMD"
    for k in "${CONFIG_KEYS[@]}"; do printf '%s=%s\n' "$k" "${!k}"; done
  } >"$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
}

load_config() {  # carga solo claves conocidas y valores con caracteres seguros
  [[ -r $CONFIG_FILE ]] || return 1
  local line key value safe='^[A-Za-z0-9_.:/@ -]*$'
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^([A-Z_]+)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    [[ " ${CONFIG_KEYS[*]} " == *" $key "* ]] || continue
    [[ $value =~ $safe ]] || continue
    printf -v "$key" '%s' "$value"
  done <"$CONFIG_FILE"
  valid_container_name "$CONTAINER_NAME" || CONTAINER_NAME=""
  [[ $HOST_PORT =~ ^[1-9][0-9]{3,4}$ ]] || HOST_PORT="1521"
  [[ $BIND_ADDR == 0.0.0.0 ]] || BIND_ADDR="127.0.0.1"
  [[ -n $VOLUME_NAME || -z $CONTAINER_NAME ]] || VOLUME_NAME="${CONTAINER_NAME}-datos"
  if [[ -n $IMAGE ]]; then image_profile "$IMAGE" "$IMAGE_KEY" || true; fi
  return 0
}

require_config() {
  load_config || die "No hay ninguna instalación registrada. Ejecuta primero: $APP_CMD instalar"
  [[ -n $CONTAINER_NAME ]] || die "La configuración guardada está incompleta. Ejecuta: $APP_CMD instalar"
  [[ -n $ENGINE ]] || ENGINE="desktop"
  set_docker_cmd
}

connection_text() {
  local host_note="" user_hint="${APP_USER:-SYSTEM}" admins="SYSTEM · SYS (como SYSDBA)"
  [[ $BIND_ADDR == 0.0.0.0 ]] && host_note="  (o la IP de este equipo desde tu red)"
  [[ -n $PDB_NAME && $PWD_STYLE == oficial ]] && admins+=" · PDBADMIN"
  printf 'Versión: %s\n\n' "${DB_LABEL:-Oracle Database}"
  printf 'Datos de conexión\n'
  printf '  Host ............. localhost%s\n' "$host_note"
  printf '  Puerto ........... %s\n' "$HOST_PORT"
  if [[ -n $PDB_NAME ]]; then
    printf '  Servicio (PDB) ... %s   <- usa este para tus prácticas\n' "$PDB_NAME"
    printf '  Servicio (CDB) ... %s\n' "$CDB_NAME"
  else
    printf '  Servicio ......... %s\n' "$CDB_NAME"
  fi
  cat <<EOF
  Tu usuario ....... ${APP_USER:-(no creado)}
  Administración ... $admins

Cadenas de conexión
  SQL*Plus / SQLcl . $user_hint@//localhost:$HOST_PORT/$DB_SERVICE
  JDBC ............. jdbc:oracle:thin:@//localhost:$HOST_PORT/$DB_SERVICE
  SQL Developer .... Tipo «Básico» · Host localhost · Puerto $HOST_PORT · Nombre del servicio $DB_SERVICE

Uso diario
  $APP_CMD estado · iniciar · parar · sql · sysdba · info · password · logs · desinstalar
EOF
}

write_info_file() {
  if (( DRY_RUN )); then
    printf '%s guardar los datos de conexión en %s\n' "${C_DIM}[simulación]${C_RESET}" "$INFO_FILE"
    return 0
  fi
  mkdir -p "$CONFIG_DIR"
  {
    printf '%s · contenedor %s · imagen %s\n' "$DB_LABEL" "$CONTAINER_NAME" "$IMAGE"
    printf 'Generado el %(%F %H:%M)T (las contraseñas no se guardan)\n\n' -1
    connection_text
  } >"$INFO_FILE"
  chmod 600 "$INFO_FILE"
}

show_final_summary() {
  if (( DRY_RUN )); then
    printf '\n%s\n' "${C_BOLD}Simulación terminada: no se ha cambiado nada.${C_RESET}"
    if [[ $UI_MODE == gui ]]; then
      gui_progress_close
      ui_msg "Simulación terminada" "No se ha cambiado nada. Con una instalación real, estos serían tus datos:

$(connection_text)"
    fi
    return 0
  fi
  printf '\n%s\n' "${C_GREEN}${C_BOLD}$S_RULE${C_RESET}"
  printf '%s\n' "${C_GREEN}${C_BOLD}  $S_OK ¡$DB_LABEL está lista para usar!${C_RESET}"
  printf '%s\n\n' "${C_GREEN}${C_BOLD}$S_RULE${C_RESET}"
  connection_text
  printf '\n'
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    info "Para usar '$APP_CMD' en ESTA terminal ejecuta: source ~/.profile (tras reiniciar sesión funciona siempre)."
  fi
  info "Las contraseñas no se guardan en ningún sitio: apúntalas. Si olvidas una: $APP_CMD password"
  info "La contraseña aleatoria que aparece en 'docker logs' era temporal: ya no sirve."
  if (( DOCKER_GROUP_ADDED )); then
    info "Te he añadido al grupo docker: tras cerrar sesión podrás usar 'docker' sin sudo."
  fi
  info "Datos de conexión guardados en: $INFO_FILE"
  info "Registro de la instalación: $LOG_FILE"
  if [[ $UI_MODE == gui ]]; then
    gui_progress_close
    local btn args=(--info --title="$DB_LABEL está lista" --no-markup --width=660 --ok-label="Cerrar")
    [[ -z ${GUI_IN_PANEL:-} ]] && args+=(--extra-button="Abrir el panel")
    btn=$(zen "${args[@]}" --text="$(connection_text)

Las contraseñas no se guardan en ningún sitio: apúntalas. Si olvidas una, usa «Cambiar o desbloquear contraseñas» en el panel.
Busca «Oracle Database (Docker)» en el menú de aplicaciones para arrancar, detener o conectarte.") || true
    if [[ $btn == "Abrir el panel" ]]; then gui_panel; fi
  fi
  return 0
}

install_run() {
  make_tmp
  STEP_N=0
  if [[ $ENGINE == desktop ]]; then STEP_TOTAL=8; else STEP_TOTAL=7; fi
  step "Paquetes básicos del sistema"
  install_base_packages
  if [[ $ENGINE == desktop ]]; then
    step "Virtualización (KVM)"
    setup_kvm
    step "Docker Desktop"
    install_docker_desktop
  else
    step "Docker Engine"
    install_docker_engine
  fi
  step "Arrancando Docker"
  start_docker
  step "Imagen de $DB_LABEL"
  pull_image
  step "Contenedor de Oracle"
  create_or_reuse_container
  step "Contraseñas y usuario de trabajo"
  configure_db
  step "Herramientas, comando '$APP_CMD' y acceso en el menú"
  install_extras
  install_helper
  install_desktop_entry
  INSTALL_STAGE="completo"
  INSTALLED_AT=$(date '+%F %H:%M')
  save_config
  write_info_file
  show_final_summary
}

# --- Migración desde las versiones 1.x («oracle23ai») ----------------------------
migrate_legacy() {
  local old_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/$LEGACY_CMD"
  local old_state="${XDG_STATE_HOME:-$HOME/.local/state}/$LEGACY_CMD"
  local old_data="${XDG_DATA_HOME:-$HOME/.local/share}/$LEGACY_CMD"
  [[ -d $old_cfg && ! -e $CONFIG_DIR ]] || return 0
  if (( DRY_RUN )); then
    printf '%s pasar la instalación anterior (%s) a los nombres nuevos (%s)\n' "${C_DIM}[simulación]${C_RESET}" "$old_cfg" "$CONFIG_DIR"
    return 0
  fi
  mkdir -p "$(dirname "$CONFIG_DIR")"
  mv -- "$old_cfg" "$CONFIG_DIR"
  if [[ -d $old_state && ! -e $STATE_DIR ]]; then mv -- "$old_state" "$STATE_DIR"; fi
  if [[ -d $old_data && ! -e $DATA_DIR ]]; then mv -- "$old_data" "$DATA_DIR"; fi
  rm -f -- "$DATA_DIR/$LEGACY_CMD.svg" "$APPS_DIR/$LEGACY_CMD.desktop"
  # El comando antiguo solo se borra si es nuestro script
  if [[ -f $BIN_DIR/$LEGACY_CMD ]] && grep -q "$LEGACY_CMD.sh" "$BIN_DIR/$LEGACY_CMD" 2>/dev/null; then
    rm -f -- "$BIN_DIR/$LEGACY_CMD"
  fi
  # SQLcl y SQL Developer: rutas nuevas en sus accesos
  if [[ -f $BIN_DIR/sql ]] && grep -q "$old_data" "$BIN_DIR/sql" 2>/dev/null; then
    write_wrapper "$BIN_DIR/sql" "$DATA_DIR/sqlcl/bin/sql"
  fi
  if [[ -f $BIN_DIR/sqldeveloper ]] && grep -q "$old_data" "$BIN_DIR/sqldeveloper" 2>/dev/null; then
    write_wrapper "$BIN_DIR/sqldeveloper" "$DATA_DIR/sqldeveloper/sqldeveloper.sh" "export JAVA_HOME=\"$(jdk17_home)\""
  fi
  if [[ -f $APPS_DIR/$LEGACY_CMD-sqldeveloper.desktop ]]; then
    rm -f -- "$APPS_DIR/$LEGACY_CMD-sqldeveloper.desktop"
    write_sqldeveloper_launcher
  fi
  MIGRATED=1
  return 0
}

after_migration() {  # comando y acceso del menú con los nombres nuevos
  (( MIGRATED )) || return 0
  load_config || true
  install_helper
  install_desktop_entry
  [[ -n $IMAGE && -n $CONTAINER_NAME ]] && write_info_file
  info "Tu instalación anterior se ha pasado al nuevo nombre: ahora el comando es '$APP_CMD' y el acceso del menú «Oracle Database (Docker)»."
  return 0
}

# =============================================================================
#  Comandos
# =============================================================================
cmd_install() {
  init_log instalacion
  ui_init
  load_config || true
  PREV_VERSION="$DB_VERSION"
  preflight_collect
  local m msg
  for m in "${PF_OK[@]}"; do log "OK    $m"; done
  if (( ${#PF_ERR[@]} )); then
    for m in "${PF_WARN[@]}"; do warn "$m"; done
    for m in "${PF_ERR[@]}"; do err "$m"; done
    msg="No se puede instalar en este equipo:
$(printf -- '- %s\n' "${PF_ERR[@]}")"
    [[ $UI_MODE == gui ]] || ui_msg "No se puede instalar" "$msg"
    die "$msg
Corrige los problemas y vuelve a ejecutar '$0 instalar'."
  fi
  [[ $INSTALL_STAGE == relogin ]] && info "Continuando la instalación que quedó pendiente de cerrar sesión."
  if [[ $UI_MODE == gui ]]; then
    wizard_gui
  else
    if (( ${#PF_WARN[@]} )); then
      for m in "${PF_WARN[@]}"; do warn "$m"; done
      ui_yesno "Avisos" "Se han encontrado estos avisos:

$(printf -- '- %s\n\n' "${PF_WARN[@]}")¿Quieres continuar?" si || cancelled
    fi
    wizard
    [[ -t 1 ]] && clear
  fi
  printf '%s\n' "${C_BOLD}$APP_NAME · v$APP_VERSION · $DB_LABEL${C_RESET}"
  info "Registro detallado: $LOG_FILE"
  gui_progress_open "Preparando la instalación de $DB_LABEL..."
  install_run
}

ensure_docker_running() {
  docker_ready && return 0
  if [[ $ENGINE == desktop ]]; then
    run "Abriendo Docker Desktop" systemctl --user start docker-desktop || die "No se pudo arrancar Docker Desktop."
    wait_for "Esperando a Docker Desktop" 600 docker_ready \
      || die "Docker Desktop no arranca. Ábrelo desde el menú de aplicaciones y revisa si muestra algún error."
  else
    ensure_sudo
    run "Arrancando el servicio de Docker" "${SUDO[@]}" systemctl start docker.service || die "No se pudo arrancar Docker."
    set_docker_cmd
    wait_for "Esperando a Docker" 120 docker_ready || die "Docker no responde. Prueba: sudo systemctl status docker"
  fi
}

ensure_container_running() {
  ensure_docker_running
  local state
  state=$(container_state)
  [[ -n $state ]] || die "No existe el contenedor '$CONTAINER_NAME'. Ejecuta: $APP_CMD instalar"
  if [[ $state != running ]]; then
    CONTAINER_SINCE=$(( $(date +%s) - 5 ))
    run "Arrancando el contenedor '$CONTAINER_NAME'" "${DOCKER[@]}" start "$CONTAINER_NAME" \
      || die "No se pudo arrancar el contenedor."
  fi
  wait_db reinicio || die "La base de datos no está disponible. Mira qué ocurre con: $APP_CMD logs"
}

cmd_start() {
  require_config
  init_log "$APP_CMD" anexar
  ensure_container_running
  printf '\n'
  connection_text
}

cmd_stop() {
  require_config
  init_log "$APP_CMD" anexar
  # Se pregunta antes de detener nada (el panel gráfico ya lo pregunta él mismo)
  if [[ $ENGINE == desktop ]] && (( ! STOP_ALL )) && [[ -z ${STOP_ASKED:-} ]] \
    && { [[ $UI_MODE == gui ]] || [[ -t 0 && -t 1 ]]; }; then
    ui_init
    if ui_yesno "Cerrar Docker Desktop" "¿Cerrar también Docker Desktop para liberar memoria?" no; then STOP_ALL=1; fi
  fi
  if ! docker_ready; then
    ok "Docker no está en marcha: Oracle ya está detenido."
    return 0
  fi
  if [[ $(container_state) == running ]]; then
    run "Deteniendo Oracle de forma ordenada (hasta 2 minutos)" "${DOCKER[@]}" stop -t 120 "$CONTAINER_NAME" \
      || die "No se pudo detener el contenedor."
  else
    ok "Oracle ya estaba detenido."
  fi
  if [[ $ENGINE == desktop ]] && (( STOP_ALL )); then
    run "Cerrando Docker Desktop" systemctl --user stop docker-desktop || true
  fi
}

cmd_status() {
  require_config
  local label state health img ports
  if [[ $ENGINE == desktop ]]; then label="Docker Desktop"; else label="Docker Engine"; fi
  printf '%s\n' "${C_BOLD}${DB_LABEL:-Oracle Database} · estado${C_RESET}"
  if ! docker_ready; then
    printf '  %-13s %s\n' "Docker:" "$label (detenido)"
    info "Arráncalo todo con: $APP_CMD iniciar"
    return 0
  fi
  printf '  %-13s %s\n' "Docker:" "$label (en marcha)"
  state=$(container_state)
  if [[ -z $state ]]; then
    warn "No existe el contenedor '$CONTAINER_NAME'. Ejecuta: $APP_CMD instalar"
    return 0
  fi
  health=$("${DOCKER[@]}" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER_NAME" 2>/dev/null) || health=""
  img=$("${DOCKER[@]}" inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null) || img="?"
  ports=$("${DOCKER[@]}" port "$CONTAINER_NAME" 1521/tcp 2>/dev/null) || ports=""
  printf '  %-13s %s\n' "Contenedor:" "$CONTAINER_NAME ($state${health:+, $health})"
  printf '  %-13s %s\n' "Imagen:" "$img"
  ports="${ports%%$'\n'*}"
  printf '  %-13s %s\n' "Puerto:" "${ports:-$BIND_ADDR:$HOST_PORT}"
  printf '  %-13s %s\n' "Servicio:" "$DB_SERVICE"
  printf '  %-13s %s\n' "Datos:" "volumen $VOLUME_NAME"
  if [[ $state == running ]]; then
    if db_sql_ready; then
      ok "Base de datos $DB_SERVICE abierta: lista para conectar."
    else
      warn "El contenedor está en marcha pero la base de datos aún no está abierta (¿arrancando?). Mira: $APP_CMD logs"
    fi
  else
    info "Oracle está detenido. Arráncalo con: $APP_CMD iniciar"
  fi
}

cmd_sql() {
  require_config
  ensure_container_running
  local user="${1:-${APP_USER:-SYSTEM}}"
  [[ $user =~ ^[A-Za-z][A-Za-z0-9_]{0,127}$ ]] || die "Nombre de usuario no válido: $user"
  if [[ -t 0 && -t 1 ]]; then
    info "Conectando como ${user^^} a $DB_SERVICE (para salir escribe: exit)"
    exec "${DOCKER[@]}" exec -it "$CONTAINER_NAME" sqlplus -L "$user@//localhost:1521/$DB_SERVICE"
  fi
  # Sin terminal (p. ej. «oracle-db sql < script.sql»): SQL*Plus no puede pedir la
  # contraseña, así que la entrada debe empezar con una línea CONNECT.
  printf '%s\n' "(Sin terminal: la entrada debe empezar con CONNECT usuario/contraseña@//localhost:1521/$DB_SERVICE)" >&2
  exec "${DOCKER[@]}" exec -i "$CONTAINER_NAME" sqlplus -s -L /nolog
}

cmd_sysdba() {
  require_config
  ensure_container_running
  local tty=(-i)
  [[ -t 0 && -t 1 ]] && tty=(-it)
  if [[ -n $PDB_NAME ]]; then
    info "Conectando como SYSDBA al CDB (usa ALTER SESSION SET CONTAINER = $PDB_NAME; para ir a la PDB)"
  else
    info "Conectando como SYSDBA a $CDB_NAME"
  fi
  exec "${DOCKER[@]}" exec "${tty[@]}" "$CONTAINER_NAME" sqlplus / as sysdba
}

cmd_sqlcl() {
  require_config
  [[ -x $BIN_DIR/sql ]] || die "SQLcl no está instalado. Instálalo con '$APP_CMD instalar' (herramientas opcionales)."
  ensure_container_running
  local user="${1:-${APP_USER:-SYSTEM}}"
  [[ $user =~ ^[A-Za-z][A-Za-z0-9_]{0,127}$ ]] || die "Nombre de usuario no válido: $user"
  exec "$BIN_DIR/sql" "$user@//localhost:$HOST_PORT/$DB_SERVICE"
}

cmd_logs() {
  require_config
  ensure_docker_running
  info "Registro del contenedor '$CONTAINER_NAME' (Ctrl+C para salir)"
  exec "${DOCKER[@]}" logs -f --tail 100 "$CONTAINER_NAME"
}

cmd_info() {
  require_config
  printf '%s\n' "${C_BOLD}Contenedor $CONTAINER_NAME · imagen $IMAGE${C_RESET}"
  printf '%s\n\n' "${C_DIM}Instalado: ${INSTALLED_AT:-?}${C_RESET}"
  connection_text
}

cmd_password() {
  require_config
  init_log "$APP_CMD" anexar
  ui_init
  ensure_container_running
  local opts=(admin "$(admin_names) (administración)") target user pwd problem
  [[ -n $APP_USER ]] && opts+=(app "Tu usuario de trabajo ($APP_USER)")
  opts+=(otro "Otro usuario de $DB_SERVICE")
  target=$(ui_menu "Cambiar contraseña" "¿Qué contraseña quieres cambiar? (también desbloquea la cuenta si estaba bloqueada)" \
    "${APP_USER:+app}" "${opts[@]}") || exit 1
  case $target in
    admin)
      pwd=$(ask_new_password "$(admin_names)") || exit 1
      { admin_sql "$pwd"; printf 'EXIT SUCCESS\n'; } | run_sql_script "Contraseña de administración cambiada" || exit 1
      ui_done "Contraseña de $(admin_names) cambiada."
      ;;
    app|otro)
      if [[ $target == app ]]; then
        user="$APP_USER"
      else
        while true; do
          user=$(ui_input "Usuario" "Nombre del usuario de $DB_SERVICE:" "") || exit 1
          if problem=$(user_problem "$user"); then ui_msg "Nombre no válido" "$problem"; continue; fi
          break
        done
        user="${user^^}"
      fi
      pwd=$(ask_new_password "el usuario $user") || exit 1
      { alter_user_sql "$user" "$pwd"; printf 'EXIT SUCCESS\n'; } | run_sql_script "Contraseña de $user cambiada (y cuenta desbloqueada)" || exit 1
      ui_done "Contraseña de $user cambiada (y cuenta desbloqueada)."
      ;;
  esac
}

cmd_create_user() {
  require_config
  init_log "$APP_CMD" anexar
  ui_init
  ensure_container_running
  local user pwd problem
  while true; do
    user=$(ui_input "Nuevo usuario" "Nombre del nuevo usuario de $DB_SERVICE (letras sin tildes, números y _):" "") || exit 1
    if problem=$(user_problem "$user"); then ui_msg "Nombre no válido" "$problem"; continue; fi
    break
  done
  user="${user^^}"
  pwd=$(ask_new_password "el usuario $user") || exit 1
  { pdb_switch_sql; user_sql "$user" "$pwd"; printf 'EXIT SUCCESS\n'; } \
    | run_sql_script "Usuario $user creado en $DB_SERVICE" || exit 1
  if verify_login "$user" "$pwd"; then ok "Conexión comprobada: $user@$DB_SERVICE"; fi
  info "Conéctate con: $APP_CMD sql $user"
  ui_done "Usuario $user creado en $DB_SERVICE, con $(role_text).
Conéctate con: $APP_CMD sql $user"
}

cmd_versions() {  # lista de versiones que se pueden instalar
  local entry v row ver key img desc size
  printf '%s\n\n' "${C_BOLD}Versiones de Oracle Database que puede instalar $APP_CMD${C_RESET}"
  for entry in "${VERSION_LIST[@]}"; do
    v="${entry%%|*}"
    [[ $v == otra ]] && continue
    printf '%s\n' "${C_BOLD}${entry#*|}${C_RESET}   (--oracle $v)"
    for row in "${IMAGE_CATALOG[@]}"; do
      IFS='|' read -r ver key img desc size <<<"$row"
      [[ $ver == "$v" ]] || continue
      printf '   %-62s %-46s ~%s\n' "$img" "$desc" "$size"
    done
  done
  printf '\n%s\n' "Y en «Otra versión» del asistente, cualquier etiqueta de estos repositorios:"
  for entry in "${REPO_LIST[@]}"; do
    IFS='|' read -r key img desc <<<"$entry"
    [[ $key == manual ]] || printf '   %s\n' "$img"
  done
}

cmd_check() {
  local m
  printf '%s\n' "${C_BOLD}Sistema${C_RESET}"
  preflight_collect
  for m in "${PF_OK[@]}"; do ok "$m"; done
  for m in "${PF_WARN[@]}"; do warn "$m"; done
  for m in "${PF_ERR[@]}"; do err "$m"; done
  printf '\n%s\n' "${C_BOLD}Docker${C_RESET}"
  if (( DD_INSTALLED )); then ok "Docker Desktop instalado ($(pkg_version docker-desktop))"; else info "Docker Desktop no instalado"; fi
  if (( ENGINE_INSTALLED )); then ok "Docker Engine instalado ($(pkg_version docker-ce))"; else info "Docker Engine no instalado"; fi
  if [[ -e /dev/kvm ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then ok "Acceso a /dev/kvm"; else warn "Sin acceso a /dev/kvm: añade tu usuario al grupo kvm y cierra sesión."; fi
  else
    info "No existe /dev/kvm (virtualización no disponible o módulos sin cargar)"
  fi
  if docker_desktop_ready; then ok "Docker Desktop en marcha"; elif (( DD_INSTALLED )); then info "Docker Desktop detenido"; fi
  if docker --context default info >/dev/null 2>&1; then ok "Docker Engine en marcha"; fi
  printf '\n%s\n' "${C_BOLD}Red${C_RESET}"
  if oracle_storage_ok; then
    ok "Registro oficial de Oracle: accesible"
  else
    warn "Almacenamiento de Oracle Cloud bloqueado o inaccesible: usa una imagen de Docker Hub (gvenzl)."
  fi
  if dockerhub_ok; then ok "Docker Hub: accesible"; else warn "Docker Hub no accesible"; fi
  printf '\n%s\n' "${C_BOLD}Instalación${C_RESET}"
  if load_config && [[ -n $CONTAINER_NAME ]]; then
    [[ -n $ENGINE ]] || ENGINE="desktop"
    set_docker_cmd nosudo
    ok "Configuración: $DB_LABEL · contenedor $CONTAINER_NAME · puerto $BIND_ADDR:$HOST_PORT · imagen $IMAGE"
    if docker_ready; then
      local state
      state=$(container_state)
      if [[ -n $state ]]; then ok "Contenedor $CONTAINER_NAME: $state"; else warn "El contenedor $CONTAINER_NAME no existe"; fi
    fi
  else
    info "No hay ninguna instalación registrada (ejecuta: $0 instalar)"
  fi
}

cmd_uninstall() {
  init_log desinstalacion
  ui_init
  load_config || warn "No se encontró configuración guardada: se usan los valores por defecto."
  [[ -n $CONTAINER_NAME ]] || CONTAINER_NAME="oracle-26ai"
  [[ -n $VOLUME_NAME ]] || VOLUME_NAME="${CONTAINER_NAME}-datos"
  if [[ -z $ENGINE ]]; then
    if pkg_installed docker-desktop; then ENGINE="desktop"; else ENGINE="engine"; fi
  fi
  set_docker_cmd
  local items=() choice confirm
  items+=(contenedor "Contenedor '$CONTAINER_NAME'" ON)
  items+=(datos "Datos: volumen '$VOLUME_NAME' (¡borra tus tablas!)" OFF)
  [[ -n $IMAGE ]] && items+=(imagen "Imagen $IMAGE" OFF)
  if [[ -e $DATA_DIR/sqlcl || -e $DATA_DIR/sqldeveloper ]]; then
    items+=(extras "SQLcl y SQL Developer instalados por esta herramienta" OFF)
  fi
  if [[ $ENGINE == desktop ]] && pkg_installed docker-desktop; then
    items+=(docker "Docker Desktop entero (con TODOS sus contenedores e imágenes)" OFF)
  fi
  items+=(comando "El comando '$APP_CMD', su acceso en el menú, su configuración y sus registros" ON)
  choice=$(ui_checklist "Desinstalar" "Marca lo que quieres eliminar (barra espaciadora para marcar):" "${items[@]}") || exit 0
  if [[ -z $choice ]]; then
    info "No se ha marcado nada: no se elimina nada."
    return 0
  fi
  has() { [[ " $choice " == *" $1 "* ]]; }
  if has datos || has docker; then
    confirm=$(ui_input "Confirmar borrado de datos" "Vas a borrar DEFINITIVAMENTE datos de la base de datos. No se puede deshacer.
Escribe BORRAR para confirmar:" "") || exit 1
    [[ $confirm == BORRAR ]] || die "Confirmación incorrecta: no se ha borrado nada."
  fi
  if has contenedor || has datos || has imagen; then
    if ensure_docker_running; then
      if [[ -n $(container_state) ]]; then
        run "Eliminando el contenedor '$CONTAINER_NAME'" "${DOCKER[@]}" rm -f "$CONTAINER_NAME" || true
      fi
      if has datos; then
        run "Eliminando el volumen de datos '$VOLUME_NAME'" "${DOCKER[@]}" volume rm -f "$VOLUME_NAME" || true
      fi
      if has imagen; then
        run "Eliminando la imagen $IMAGE" "${DOCKER[@]}" image rm "$IMAGE" || true
      fi
    fi
  fi
  if has extras; then
    run "Eliminando SQLcl y SQL Developer" rm -rf -- "$DATA_DIR/sqlcl" "$DATA_DIR/sqldeveloper" \
      "$BIN_DIR/sql" "$BIN_DIR/sqldeveloper" "$APPS_DIR/$APP_CMD-sqldeveloper.desktop" || true
  fi
  if has docker; then
    ensure_sudo
    run "Cerrando Docker Desktop" systemctl --user stop docker-desktop || true
    run "Desactivando su inicio automático" systemctl --user disable docker-desktop || true
    run "Desinstalando Docker Desktop" "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get purge -y docker-desktop || true
    run "Borrando la máquina virtual de Docker Desktop" rm -rf -- "$HOME/.docker/desktop" || true
    run "Borrando /usr/local/bin/com.docker.cli" "${SUDO[@]}" rm -f /usr/local/bin/com.docker.cli || true
    if [[ -f $HOME/.docker/config.json ]] && command -v python3 >/dev/null 2>&1; then
      run "Limpiando ~/.docker/config.json" python3 - "$HOME/.docker/config.json" <<'PY' || true
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except Exception:
    sys.exit(0)
changed = False
if cfg.get("credsStore") == "desktop":
    cfg.pop("credsStore"); changed = True
if cfg.get("currentContext") == "desktop-linux":
    cfg.pop("currentContext"); changed = True
if changed:
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
PY
    fi
  fi
  if has comando; then
    local log_copy="${TMPDIR:-/tmp}/$APP_CMD-desinstalacion.log"
    [[ -n $LOG_FILE && -f $LOG_FILE ]] && cp "$LOG_FILE" "$log_copy" 2>/dev/null
    LOG_FILE=""
    run "Eliminando el comando '$APP_CMD', su acceso en el menú, su configuración y registros" \
      rm -rf -- "$BIN_DIR/$APP_CMD" "$APPS_DIR/$APP_CMD.desktop" "$DATA_DIR/$APP_CMD.svg" \
      "$CONFIG_DIR" "$STATE_DIR" || true
    [[ -f $log_copy ]] && info "Copia del registro de esta desinstalación: $log_copy"
  fi
  ok "Desinstalación terminada."
  ui_done "Desinstalación terminada."
}

cmd_help() {
  cat <<EOF
${C_BOLD}$APP_NAME · v$APP_VERSION${C_RESET}

Uso: $APP_CMD [comando] [opciones]      (sin comando abre el panel o un menú)

${C_BOLD}Instalación${C_RESET}
  instalar           Asistente que instala y configura todo (Docker + Oracle)
  versiones          Lista de versiones e imágenes que se pueden instalar
  comprobar          Revisa requisitos, red y estado (útil si algo falla)
  desinstalar        Elimina lo que elijas: contenedor, datos, imagen, Docker...

${C_BOLD}Uso diario${C_RESET}
  estado             ¿Están en marcha Docker y la base de datos?
  iniciar            Arranca Docker (si hace falta) y Oracle
  parar [--todo]     Detiene Oracle (con --todo también cierra Docker Desktop)
  sql [usuario]      SQL*Plus conectado a la base de trabajo (por defecto, tu usuario)
  sysdba             SQL*Plus como SYSDBA (administración)
  sqlcl [usuario]    SQLcl desde tu Ubuntu (si lo instalaste)
  info               Datos de conexión (host, puerto, servicio...)
  password           Cambiar o desbloquear contraseñas
  crear-usuario      Crear otro usuario
  logs               Registro del contenedor (Ctrl+C para salir)

${C_BOLD}Opciones${C_RESET}
  --oracle VERSIÓN   Versión propuesta en el asistente: 26ai, 23ai, 21c, 18c, 11g,
                     19c (Enterprise/Standard) o 21c-ee
  --gui              Ventanas gráficas (lo normal si hay escritorio)
  --tui              Ventanas dentro de la terminal
  --texto            Preguntas en texto plano, sin ventanas (también --sin-tui)
  --simular          Muestra lo que haría sin cambiar nada
  -h, --ayuda        Esta ayuda
  -V, --version      Versión de la herramienta
EOF
}

# --- Panel gráfico de uso diario (lo abre el acceso del menú de aplicaciones) --
gui_status_line() {
  local state
  if [[ $INSTALL_STAGE != completo ]]; then
    printf 'Oracle Database todavía no está instalado en este equipo.'
    return 0
  fi
  if ! docker_ready; then
    printf '%s · Docker está detenido. Pulsa «Arrancar Oracle» para ponerlo todo en marcha.' "$DB_LABEL"
    return 0
  fi
  state=$(container_state)
  case $state in
    running)
      if db_sql_ready; then
        printf '✔ %s en marcha · localhost:%s · servicio %s' "$DB_LABEL" "$HOST_PORT" "$DB_SERVICE"
      else
        printf '… %s está arrancando: espera un momento.' "$DB_LABEL"
      fi ;;
    "") printf 'No existe el contenedor %s: usa «Reinstalar o reparar».' "$CONTAINER_NAME" ;;
    *) printf '■ %s está detenida.' "$DB_LABEL" ;;
  esac
}

gui_panel() {
  local choice status
  export GUI_IN_PANEL=1
  while true; do
    INSTALL_STAGE=""
    load_config || true
    [[ -n $ENGINE ]] || ENGINE="desktop"
    set_docker_cmd nosudo
    status=$(gui_status_line 2>/dev/null) || status=""
    if [[ $INSTALL_STAGE == completo ]]; then
      choice=$(zen --list --title="Oracle Database (Docker)" --text="$status" --width=580 --height=620 \
        --column="id" --column="Acción" --hide-column=1 --print-column=1 --hide-header \
        --ok-label="Abrir" --cancel-label="Salir" \
        iniciar "▶  Arrancar Oracle" \
        parar "■  Detener Oracle" \
        sql "⌨  SQL*Plus con tu usuario" \
        sysdba "⌨  SQL*Plus como SYSDBA (administración)" \
        info "ℹ  Datos de conexión" \
        estado "◉  Estado detallado" \
        password "🔑  Cambiar o desbloquear contraseñas" \
        crear-usuario "👤  Crear otro usuario" \
        logs "📜  Registro de Oracle" \
        comprobar "🩺  Diagnóstico del sistema" \
        instalar "⟳  Instalar otra versión, reinstalar o reparar" \
        desinstalar "🗑  Desinstalar") || return 0
    else
      choice=$(zen --list --title="$APP_NAME" --text="$status" --width=580 --height=380 \
        --column="id" --column="Acción" --hide-column=1 --print-column=1 --hide-header \
        --ok-label="Abrir" --cancel-label="Salir" \
        instalar "⬇  Instalar Oracle Database (elige la versión)" \
        versiones "☰  Ver las versiones que se pueden instalar" \
        comprobar "🩺  Comprobar requisitos y red") || return 0
    fi
    if [[ -n $choice ]]; then gui_action "$choice" || true; fi
  done
}

gui_action() {  # cada acción va en un subproceso: si falla, el panel sigue abierto
  local out rc=0 title
  case $1 in
    estado|info|comprobar|versiones)
      case $1 in
        estado) title="Estado de Oracle" ;;
        info) title="Datos de conexión" ;;
        versiones) title="Versiones que se pueden instalar" ;;
        *) title="Diagnóstico del sistema" ;;
      esac
      gui_progress_open "Consultando..." pulsate
      out=$( (GUI_QUIET_ERRORS=1 dispatch "$1") 2>&1 ) || rc=$?
      gui_progress_close
      gui_show_text "$title" "$(strip_ansi <<<"$out")"
      ;;
    iniciar|parar)
      if [[ $1 == parar && $ENGINE == desktop ]]; then
        STOP_ALL=0
        if ui_yesno "Detener Oracle" "¿Cerrar también Docker Desktop para liberar memoria?" no; then STOP_ALL=1; fi
        export STOP_ASKED=1
      fi
      if [[ $1 == iniciar ]]; then
        gui_progress_open "Arrancando Oracle (y Docker si hace falta)..." pulsate
      else
        gui_progress_open "Deteniendo Oracle de forma ordenada (hasta 2 minutos)..." pulsate
      fi
      out=$( (GUI_QUIET_ERRORS=1 dispatch "$1") 2>&1 ) || rc=$?
      gui_progress_close
      if (( rc != 0 )); then
        gui_show_text "No se pudo completar" "$(strip_ansi <<<"$out")"
      elif [[ $1 == iniciar ]]; then
        ui_msg "Oracle está en marcha" "$(connection_text)"
      else
        ui_msg "Oracle detenido" "Oracle se ha detenido correctamente."
      fi
      ;;
    sql) open_in_terminal "SQL*Plus · Oracle" sql ;;
    sysdba) open_in_terminal "SQL*Plus SYSDBA · Oracle" sysdba ;;
    logs) open_in_terminal "Registro de Oracle" logs ;;
    *) (dispatch "$1") || true ;;
  esac
  return 0
}

cmd_menu() {
  ui_init
  if [[ $UI_MODE == gui ]]; then
    gui_panel
    return 0
  fi
  local choice installed=0
  if load_config && [[ $INSTALL_STAGE == completo ]]; then installed=1; fi
  if (( installed )); then
    choice=$(ui_menu "$APP_NAME" "$DB_LABEL · contenedor $CONTAINER_NAME · puerto $HOST_PORT · servicio $DB_SERVICE

¿Qué quieres hacer?" estado \
      estado "Ver el estado de la base de datos" \
      iniciar "Arrancar Oracle (y Docker si hace falta)" \
      parar "Detener Oracle" \
      sql "Abrir SQL*Plus con tu usuario" \
      info "Ver los datos de conexión" \
      password "Cambiar o desbloquear contraseñas" \
      crear-usuario "Crear otro usuario" \
      logs "Ver el registro del contenedor" \
      comprobar "Comprobar requisitos y red" \
      instalar "Instalar otra versión, reinstalar o reparar" \
      desinstalar "Desinstalar" \
      salir "Salir") || exit 0
  else
    choice=$(ui_menu "$APP_NAME" "Instala y deja lista Oracle Database en Ubuntu con Docker:
26ai, 23ai, 21c, 18c, 11g, 19c... la versión que necesites.

¿Qué quieres hacer?" instalar \
      instalar "Instalar Oracle Database (asistente)" \
      versiones "Ver las versiones que se pueden instalar" \
      comprobar "Comprobar requisitos y red antes de instalar" \
      ayuda "Ver todos los comandos" \
      salir "Salir") || exit 0
  fi
  [[ $choice == salir ]] && exit 0
  [[ -t 1 && $UI_MODE == tui ]] && clear
  dispatch "$choice"
}

dispatch() {
  local cmd="${1:-}"
  (( $# )) && shift
  case $cmd in
    instalar|install) cmd_install ;;
    estado|status) cmd_status ;;
    iniciar|arrancar|start) cmd_start ;;
    parar|detener|stop) cmd_stop ;;
    sql|sqlplus|conectar) cmd_sql "$@" ;;
    sysdba) cmd_sysdba ;;
    sqlcl) cmd_sqlcl "$@" ;;
    logs|log) cmd_logs ;;
    info|conexion) cmd_info ;;
    password|contrasena|contraseña) cmd_password ;;
    crear-usuario|usuario) cmd_create_user ;;
    versiones|versions) cmd_versions ;;
    comprobar|check|diagnostico) cmd_check ;;
    desinstalar|uninstall) cmd_uninstall ;;
    ayuda|help) cmd_help ;;
    *) err "Comando desconocido: $cmd"; cmd_help; exit 1 ;;
  esac
}

main() {
  setup_output
  local cmd="" args=()
  while (( $# )); do
    case $1 in
      --simular|--dry-run) DRY_RUN=1 ;;
      --gui|--grafico) UI_MODE="gui" ;;
      --tui|--terminal) UI_MODE="tui" ;;
      --sin-tui|--no-tui|--texto) UI_MODE="texto" ;;
      --todo|--all) STOP_ALL=1 ;;
      --oracle=*) ORACLE_PREF="${1#*=}" ;;
      --oracle)
        [[ $# -ge 2 ]] || die "Falta la versión después de --oracle (por ejemplo: 26ai, 23ai, 21c, 18c, 11g o 19c)."
        ORACLE_PREF="$2"
        shift
        ;;
      -h|--help|--ayuda) cmd="ayuda" ;;
      -V|--version) printf '%s %s\n' "$APP_CMD" "$APP_VERSION"; exit 0 ;;
      -*) die "Opción desconocida: $1 (usa '$APP_CMD ayuda')" ;;
      *) if [[ -z $cmd ]]; then cmd="$1"; else args+=("$1"); fi ;;
    esac
    shift
  done
  if [[ -n $ORACLE_PREF ]]; then
    ORACLE_PREF=$(normalize_version "$ORACLE_PREF") \
      || die "Versión no válida en --oracle. Usa una de estas: 26ai, 23ai, 21c, 18c, 11g, 19c o 21c-ee."
  fi
  if (( EUID == 0 )); then
    die "No ejecutes esta herramienta como root ni con sudo: usa tu usuario normal (./oracle-db.sh). Pedirá la contraseña cuando haga falta."
  fi
  trap cleanup EXIT
  trap on_interrupt INT TERM
  trap 'on_error "$LINENO"' ERR
  migrate_legacy
  after_migration
  if [[ -z $cmd ]]; then
    cmd_menu
  else
    dispatch "$cmd" "${args[@]}"
  fi
}

main "$@"
