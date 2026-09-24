# Instalador de Oracle Database 23ai Free para Ubuntu 24.04 (Docker Desktop)

Herramienta que **instala todo lo necesario y deja lista una base de datos Oracle Database 23ai Free**
en Ubuntu 24.04 LTS usando Docker Desktop. Te hace unas preguntas en ventanas (nombre, puerto,
contraseñas, usuario…) y hace el resto sola.

Al terminar tendrás:

- **Docker Desktop** instalado y funcionando (con KVM y el repositorio oficial de Docker).
- **Oracle Database 23ai Free** en un contenedor, con los datos en un **volumen persistente**.
- Tus **contraseñas** puestas en SYS, SYSTEM y PDBADMIN.
- Un **usuario de trabajo** para tus prácticas (por ejemplo `ALUMNO`) en la base de datos `FREEPDB1`.
- El comando **`oracle23ai`** para arrancar, parar, conectarte, cambiar contraseñas, etc.
- Opcional: **SQLcl** y **SQL Developer** en tu Ubuntu.

---

## Requisitos

| | Mínimo | Recomendado |
|---|---|---|
| Sistema | Ubuntu 24.04 LTS de 64 bits (x86-64) con escritorio | |
| Memoria RAM | 4 GB | 8 GB o más |
| Disco libre | 15 GB | 25 GB |
| Virtualización | Activada en la BIOS/UEFI (Intel VT-x / AMD-V) | |
| Otros | Conexión a Internet y la contraseña de tu usuario (sudo) | |

> **¿Tu Ubuntu es una máquina virtual (VirtualBox, VMware…) o no tiene virtualización?**
> Docker Desktop necesita KVM. Si no está disponible, la herramienta lo detecta y usa
> **Docker Engine** (Docker sin interfaz gráfica). Oracle funciona exactamente igual.

---

## Instalación rápida

Abre una terminal (`Ctrl + Alt + T`) y ejecuta:

```bash
git clone https://github.com/Piratapacorro/instalador-oracle23ai-ubuntu.git
cd instalador-oracle23ai-ubuntu
./oracle23ai.sh instalar
```

¿No tienes `git`? Descarga solo el script:

```bash
wget https://raw.githubusercontent.com/Piratapacorro/instalador-oracle23ai-ubuntu/main/oracle23ai.sh
chmod +x oracle23ai.sh
./oracle23ai.sh instalar
```

> Ejecútalo con **tu usuario normal**, no con `sudo`: la herramienta pedirá la contraseña cuando haga falta.
> Si prefieres ver antes lo que hará sin cambiar nada: `./oracle23ai.sh --simular instalar`.

### Qué te va a preguntar

| Pregunta | Valor recomendado (pulsa Enter) |
|---|---|
| Motor de contenedores | Docker Desktop |
| Nombre del contenedor | `oracle23ai` |
| Imagen de Oracle | 23ai (23.9); si tu red bloquea Oracle Cloud te propondrá la de Docker Hub |
| Puerto | `1521` |
| ¿Acceso desde otros equipos? | No (solo desde tu equipo) |
| Contraseña de administración | *la que tú elijas* (SYS, SYSTEM y PDBADMIN) |
| Usuario de trabajo | `alumno` y *su contraseña* |
| Arranque automático | Oracle sí; Docker Desktop al iniciar sesión, no |
| Herramientas opcionales | SQLcl y/o SQL Developer (si las quieres) |

Las contraseñas deben tener **8-30 caracteres**, empezar por letra e incluir **mayúscula, minúscula y número**
(solo letras sin tildes, números, `_` y `#`). **No se guardan en ningún sitio: apúntalas.**

### El único paso manual: aceptar el acuerdo de Docker

La primera vez que se abre Docker Desktop aparece el **Docker Subscription Service Agreement**.
Léelo y pulsa **Accept** (es gratuito para uso personal y educativo). Puedes saltarte el inicio de
sesión (*Skip*). La instalación continúa sola en cuanto Docker Desktop está listo.

> Si la herramienta te dice que **cierres sesión** (pasa si hubo que añadirte al grupo `kvm`), cierra
> sesión, vuelve a entrar y ejecuta de nuevo `./oracle23ai.sh instalar`: recordará tus respuestas.

---

## Conectarte a la base de datos

| Dato | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `1521` (o el que elegiste) |
| **Servicio (PDB) para trabajar** | **`FREEPDB1`** |
| Servicio del contenedor raíz (CDB) | `FREE` |
| Tu usuario | el que creaste (p. ej. `ALUMNO`) |
| Administración | `SYSTEM`, `SYS` (como SYSDBA), `PDBADMIN` |

**Desde la terminal** (SQL*Plus dentro del contenedor, no hay que instalar nada más):

```bash
oracle23ai sql              # con tu usuario de trabajo (te pide la contraseña)
oracle23ai sql system       # con otro usuario
oracle23ai sysdba           # como SYSDBA (administración)
```

**SQL Developer / DBeaver / VS Code (SQL Developer Extension):** nueva conexión de tipo *Básico*,
host `localhost`, puerto `1521`, **Nombre del servicio** `FREEPDB1` (¡no «SID»!), tu usuario y contraseña.

**JDBC:** `jdbc:oracle:thin:@//localhost:1521/FREEPDB1`

**SQLcl** (si lo instalaste): `oracle23ai sqlcl` o `sql alumno@//localhost:1521/FREEPDB1`

---

## Uso diario

| Comando | Qué hace |
|---|---|
| `oracle23ai` | Menú con todas las opciones |
| `oracle23ai estado` | ¿Están en marcha Docker y la base de datos? |
| `oracle23ai iniciar` | Arranca Docker (si hace falta) y Oracle |
| `oracle23ai parar` | Detiene Oracle de forma ordenada (`--todo` cierra también Docker Desktop) |
| `oracle23ai sql [usuario]` | SQL*Plus conectado a `FREEPDB1` |
| `oracle23ai sysdba` | SQL*Plus como SYSDBA |
| `oracle23ai info` | Muestra los datos de conexión |
| `oracle23ai password` | Cambia o **desbloquea** contraseñas (también si las olvidaste) |
| `oracle23ai crear-usuario` | Crea otro usuario en `FREEPDB1` (p. ej. uno por proyecto) |
| `oracle23ai logs` | Registro del contenedor |
| `oracle23ai comprobar` | Diagnóstico de requisitos, red y estado |
| `oracle23ai desinstalar` | Elimina lo que elijas (contenedor, datos, imagen, Docker Desktop…) |

> Si justo después de instalar la terminal dice `oracle23ai: orden no encontrada`, ejecuta
> `source ~/.profile` (o cierra sesión y vuelve a entrar). Mientras tanto también puedes usar
> `~/.local/bin/oracle23ai`.

---

## ¿Estás en la red del instituto? Imagen oficial bloqueada

Las imágenes **oficiales** de Oracle (`container-registry.oracle.com`) se descargan desde
*Oracle Cloud Object Storage*. Algunas redes (por ejemplo, redes de centros educativos) bloquean ese
servicio, y la descarga falla con `i/o timeout`.

La herramienta lo **detecta antes de empezar** y te propone la imagen equivalente de **Docker Hub**
`gvenzl/oracle-free`: es la misma base de datos, empaquetada por Gerald Venzl (product manager de
Oracle Database) y muy usada. Si aun así eliges la oficial y la descarga falla, te ofrece cambiar
a la de Docker Hub. En casa normalmente funcionan las dos.

| Imagen | Versión | Descarga |
|---|---|---|
| `container-registry.oracle.com/database/free:23.9.0.0` | 23ai 23.9 (oficial, completa) | ~3,4 GB |
| `container-registry.oracle.com/database/free:23.9.0.0-lite` | 23ai 23.9 (oficial, reducida) | ~0,8 GB |
| `container-registry.oracle.com/database/free:latest` | 26ai (23.26.x) (oficial) | ~3,5 GB |
| `gvenzl/oracle-free:23.9` | 23ai 23.9 (Docker Hub) | ~1 GB |
| `gvenzl/oracle-free:23.9-full` | 23ai 23.9 completa (Docker Hub) | ~2 GB |
| `gvenzl/oracle-free:23` | 26ai (23.26.x) (Docker Hub) | ~1,1 GB |

> **23ai y 26ai:** en octubre de 2025 Oracle renombró las nuevas versiones de 23ai como
> *Oracle AI Database 26ai* (versión 23.26.x). La 23.9 es la última que se llama «23ai» y es la
> recomendada para seguir el temario; 26ai es su continuación (todo lo de 23ai y más).

---

## Qué instala y dónde

| Qué | Dónde |
|---|---|
| Docker Desktop | `/opt/docker-desktop` (paquete `docker-desktop`) |
| Repositorio de Docker | `/etc/apt/sources.list.d/docker.sources` y `/etc/apt/keyrings/docker.asc` |
| Máquina virtual de Docker Desktop (imágenes y volúmenes) | `~/.docker/desktop/` |
| Comando `oracle23ai` | `~/.local/bin/oracle23ai` |
| Configuración (sin contraseñas) y datos de conexión | `~/.config/oracle23ai/` |
| Registros de instalación | `~/.local/state/oracle23ai/` |
| SQLcl / SQL Developer (opcionales) | `~/.local/share/oracle23ai/` |
| Tu base de datos | volumen de Docker `oracle23ai-datos` |

### Seguridad

- Las contraseñas **nunca** se escriben en disco, en la línea de órdenes ni en variables de entorno
  del contenedor: se aplican con SQL por la entrada estándar. `docker inspect` no las muestra.
- Por defecto el puerto solo escucha en `127.0.0.1` (nadie de tu red puede conectarse).
- Se verifica la **huella de la clave GPG** de Docker y la **suma SHA-256** del paquete de Docker Desktop.
- Nada se descarga de sitios que no sean oficiales (Docker, Oracle, Docker Hub).
- El usuario de trabajo usa un perfil sin caducidad de contraseña (`PERFIL_PRACTICAS`) para que
  no caduque a mitad de curso.

---

## Más documentación

- [Instalación manual paso a paso](docs/PASOS_MANUALES.md): los mismos pasos que hace la herramienta, comando a comando.
- [Solución de problemas](docs/SOLUCION_DE_PROBLEMAS.md): errores frecuentes (KVM, memoria, `ORA-12514`, cuentas bloqueadas…).

---

## Desinstalar

```bash
oracle23ai desinstalar
```

Marca lo que quieras eliminar: el contenedor, **los datos** (pide escribir `BORRAR`), la imagen,
SQLcl/SQL Developer, Docker Desktop entero o el propio comando.

---

## Aviso legal

- **Oracle Database Free** se distribuye bajo los *Oracle Free Use Terms and Conditions*.
- **Docker Desktop** requiere aceptar el *Docker Subscription Service Agreement* (gratuito para uso
  personal, educativo y pequeñas empresas).
- Este proyecto no está afiliado a Oracle ni a Docker. Se distribuye bajo licencia [MIT](LICENSE),
  sin garantía de ningún tipo.
