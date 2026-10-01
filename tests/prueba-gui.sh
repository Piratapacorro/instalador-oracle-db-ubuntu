#!/usr/bin/env bash
# =============================================================================
#  Prueba automática del modo gráfico con el zenity falso (no necesita escritorio).
#  Uso: tests/prueba-gui.sh
# =============================================================================
set -uo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
install -m 755 "$raiz/tests/zenity-falso" "$tmp/bin/zenity"
# df falso con espacio de sobra: la prueba no debe depender del disco de la máquina
# (las máquinas de GitHub Actions a veces tienen menos de los 15 GB que exige el instalador)
printf '%s\n' '#!/bin/sh' \
  'echo "Filesystem 1024-blocks Used Available Capacity Mounted on"' \
  'echo "/dev/falso 1048576000 0 1048576000 0% /"' >"$tmp/bin/df"
chmod 755 "$tmp/bin/df"
fallos=0

si() {  # si "descripción" patrón fichero
  if grep -qaE -- "$2" "$3"; then echo "  ✔ $1"; else echo "  ✘ $1"; fallos=$((fallos + 1)); fi
}
no() {  # no "descripción" patrón fichero
  if grep -qaE -- "$2" "$3"; then echo "  ✘ $1"; fallos=$((fallos + 1)); else echo "  ✔ $1"; fi
}

ejecutar() {  # ejecutar nombre "respuestas" args...
  local nombre="$1"
  printf '%b' "$2" >"$tmp/$nombre.resp"
  shift 2
  : >"$tmp/$nombre.log"
  rm -rf "${tmp:?}/home" && mkdir -p "$tmp/home"
  env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_DATA_HOME -u WAYLAND_DISPLAY \
    HOME="$tmp/home" PATH="$tmp/bin:$PATH" DISPLAY=":99" NO_COLOR=1 \
    ZENITY_LOG="$tmp/$nombre.log" ZENITY_RESPUESTAS="$tmp/$nombre.resp" \
    timeout 180 "$raiz/oracle-db.sh" "$@" </dev/null >"$tmp/$nombre.salida" 2>&1
  echo "  (código de salida: $?)"
}

claves='Oracle123x\\x1fOracle123x\\x1fAlumno123x\\x1fAlumno123x'

echo "1) Asistente gráfico completo, versión 26ai (simulación)"
ejecutar asistente "forms.*Contraseñas\t0\t$claves\n" --gui --simular --oracle 26ai instalar
L="$tmp/asistente.log" S="$tmp/asistente.salida"
no "zenity solo recibe opciones válidas" 'OPCION_DESCONOCIDA' "$L"
si "ventana de bienvenida" $'^DIALOGO\tquestion\tBienvenida' "$L"
si "elección del motor de Docker" $'^DIALOGO\t(list\tMotor de contenedores|info\tSe usará Docker Engine)' "$L"
si "elección de la versión de Oracle" $'^DIALOGO\tlist\tVersión de Oracle Database' "$L"
si "comprobación de red con ventana de espera" $'^PROGRESO\t# ' "$L"
si "elección de la imagen" $'^DIALOGO\tlist\tImagen de Oracle' "$L"
si "nombre del contenedor" $'^DIALOGO\tentry\tNombre del contenedor' "$L"
si "puerto" $'^DIALOGO\tentry\tPuerto' "$L"
si "lista de opciones" $'^DIALOGO\tlist\tOpciones' "$L"
si "usuario de trabajo" $'^DIALOGO\tentry\tUsuario de trabajo' "$L"
si "formulario de contraseñas" $'^DIALOGO\tforms\tContraseñas' "$L"
si "resumen con la versión 26ai" $'^DIALOGO\tquestion\tResumen\t.*Versión: Oracle AI Database 26ai Free' "$L"
si "resumen con la imagen 26ai" $'^DIALOGO\tquestion\tResumen\t.*Imagen: (container-registry.oracle.com/database/free:latest|docker.io/gvenzl/oracle-free:23) ' "$L"
si "resumen con el usuario ALUMNO en FREEPDB1" $'^DIALOGO\tquestion\tResumen\t.*Usuario: ALUMNO \\(en FREEPDB1\\)' "$L"
si "contenedor con nombre de la versión" $'^DIALOGO\tquestion\tResumen\t.*Contenedor: oracle-26ai ' "$L"
si "barra de progreso hasta el último paso" $'^PROGRESO\t# \\[(7/7|8/8)\\]' "$L"
si "la barra se completa" $'^PROGRESO\t100$' "$L"
si "ventana final" $'^DIALOGO\tinfo\tSimulación terminada' "$L"
si "la simulación termina" 'Simulación terminada' "$S"
no "las contraseñas no aparecen en la salida" 'Oracle123x|Alumno123x' "$S"
no "las contraseñas no aparecen en los diálogos" 'Oracle123x|Alumno123x' "$L"

echo "2) Oracle 11g Express Edition (sin PDB, otra ruta de datos)"
ejecutar v11g "forms.*Contraseñas\t0\t$claves\n" --gui --simular --oracle 11g instalar
si "resumen con 11g" $'^DIALOGO\tquestion\tResumen\t.*Versión: Oracle Database 11g Express Edition' "$tmp/v11g.log"
si "usuario en el servicio XE" $'^DIALOGO\tquestion\tResumen\t.*Usuario: ALUMNO \\(en XE\\)' "$tmp/v11g.log"
si "datos en /u01/app/oracle/oradata" 'oracle-11g-xe-datos:/u01/app/oracle/oradata' "$tmp/v11g.salida"

echo "3) Oracle 21c Express Edition"
ejecutar v21c "forms.*Contraseñas\t0\t$claves\n" --gui --simular --oracle 21c instalar
si "usuario en XEPDB1" $'^DIALOGO\tquestion\tResumen\t.*Usuario: ALUMNO \\(en XEPDB1\\)' "$tmp/v21c.log"
si "permisos clásicos (sin DB_DEVELOPER_ROLE)" $'^DIALOGO\tentry\tUsuario de trabajo\t.*permisos para crear tablas' "$tmp/v21c.log"

echo "4) Oracle 19c Enterprise: pide la cuenta de Oracle"
ejecutar v19c "entry.*Usuario de tu cuenta\t0\talumno@example.com\nentry.*Auth Token\t0\tTokenDePrueba\nforms.*Contraseñas\t0\t$claves\n" --gui --simular --oracle 19c instalar
si "explica cómo conseguir la cuenta y el token" $'^DIALOGO\tinfo\tCuenta de Oracle necesaria' "$tmp/v19c.log"
si "inicia sesión en el registro de Oracle" 'docker login container-registry.oracle.com' "$tmp/v19c.salida"
si "usuario en ORCLPDB1" $'^DIALOGO\tquestion\tResumen\t.*Usuario: ALUMNO \\(en ORCLPDB1\\)' "$tmp/v19c.log"
no "el token no aparece en la salida" 'TokenDePrueba' "$tmp/v19c.salida"

echo "5) «Otra versión»: cualquier etiqueta de Docker Hub (gvenzl/oracle-xe)"
ejecutar otra "list.*Versión de Oracle Database\t0\totra\nlist.*Otra versión\t0\txe-hub\nforms.*Contraseñas\t0\t$claves\n" --gui --simular instalar
si "lista de etiquetas disponibles" $'^DIALOGO\tlist\tVersiones disponibles' "$tmp/otra.log"
si "imagen elegida de gvenzl/oracle-xe" $'^DIALOGO\tquestion\tResumen\t.*Imagen: docker.io/gvenzl/oracle-xe:' "$tmp/otra.log"
si "la simulación termina" 'Simulación terminada' "$tmp/otra.salida"

echo "6) Contraseñas que no coinciden: avisa y repite el formulario"
ejecutar claves "forms.*Contraseñas\t0\tOracle123x\\\\x1fOtra12345x\\\\x1f\\\\x1f\nforms.*Contraseñas\t0\tOracle123x\\\\x1fOracle123x\\\\x1f\\\\x1f\n" --gui --simular instalar
si "aviso «No coinciden»" $'^DIALOGO\tinfo\tNo coinciden' "$tmp/claves.log"
si "termina tras corregirlas" 'Simulación terminada' "$tmp/claves.salida"

echo "7) Contraseña débil: avisa del motivo"
ejecutar debil "forms.*Contraseñas\t0\toracle123\\\\x1foracle123\\\\x1f\\\\x1f\nforms.*Contraseñas\t0\tOracle123x\\\\x1fOracle123x\\\\x1f\\\\x1f\n" --gui --simular instalar
si "explica que falta una mayúscula" $'^DIALOGO\tinfo\tContraseña no válida\t.*MAYÚSCULA' "$tmp/debil.log"

echo "8) Cancelar en la bienvenida no cambia nada"
ejecutar cancelar "question.*Bienvenida\t1\t\n" --gui --simular instalar
si "mensaje de cancelación" 'Asistente cancelado' "$tmp/cancelar.salida"
no "no empieza la instalación" $'^PROGRESO\t# \\[1/' "$tmp/cancelar.log"

echo "9) Panel sin nada instalado: se muestra y se puede salir"
ejecutar panel "list.*todavía no está instalado\t1\t\n" --gui
si "panel con el estado" $'^DIALOGO\tlist\t.*todavía no está instalado' "$tmp/panel.log"

echo
if (( fallos == 0 )); then
  echo "TODAS LAS PRUEBAS DEL MODO GRÁFICO HAN PASADO"
else
  echo "$fallos comprobaciones han fallado"
  for f in "$tmp"/*.salida; do echo "--- $f"; tail -n 15 "$f"; done
  exit 1
fi
