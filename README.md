# Instalador de Oracle Database para Ubuntu (Docker Desktop)

Herramienta con **interfaz gráfica** que **instala todo lo necesario y deja lista una base de datos
Oracle Database** en Ubuntu 24.04 LTS usando Docker Desktop. **Tú eliges la versión**: 26ai, 23ai,
21c, 18c, 11g, 19c… o cualquier actualización concreta. Te hace unas preguntas en ventanas (versión,
puerto, contraseñas, usuario…) y hace el resto sola, con una barra de progreso.

Al terminar tendrás:

- **Docker Desktop** instalado y funcionando (con KVM y el repositorio oficial de Docker).
- **Oracle Database** en la versión que elijas, en un contenedor con los datos en un **volumen persistente**.
- Tus **contraseñas** puestas en las cuentas de administración (SYS, SYSTEM…).
- Un **usuario de trabajo** para tus prácticas (por ejemplo `ALUMNO`), con los permisos adecuados para tu versión.
- La aplicación **«Oracle Database (Docker)»** en el menú de aplicaciones: un panel para arrancar,
  detener, conectarte, cambiar contraseñas, crear usuarios…
- El comando **`oracle-db`** para hacer lo mismo desde la terminal.
- Opcional: **SQLcl** y **SQL Developer** en tu Ubuntu.

---

## Versiones que puedes instalar

| Versión | Gratis | Servicio para trabajar | Imagen oficial de Oracle | Docker Hub (gvenzl) |
|---|---|---|---|---|
| **Oracle AI Database 26ai Free** (23.26.x, la más reciente) | Sí | `FREEPDB1` | `database/free:latest` (~3,5 GB) · `latest-lite` | `oracle-free:23` (~1,1 GB) · `-full` · `-slim` |
| **Oracle Database 23ai Free** (23.9) | Sí | `FREEPDB1` | `database/free:23.9.0.0` (~3,4 GB) · `-lite` | `oracle-free:23.9` (~1 GB) · `-full` · `-slim` |
| **Oracle Database 21c Express Edition (XE)** | Sí | `XEPDB1` | `database/express:21.3.0-xe` (~3,5 GB) | `oracle-xe:21` (~1,4 GB) · `-full` · `-slim` |
| **Oracle Database 18c Express Edition (XE)** | Sí | `XEPDB1` | `database/express:18.4.0-xe` (~2,9 GB) | `oracle-xe:18` (~1,4 GB) · `-full` · `-slim` |
| **Oracle Database 11g Express Edition (XE)** (antigua, sin PDB) | Sí | `XE` | — | `oracle-xe:11` (~0,3 GB) · `-full` |
| **Oracle Database 19c Enterprise / Standard Edition 2** | Cuenta de Oracle | `ORCLPDB1` | `database/enterprise:19.3.0.0` | — |
| **Oracle Database 21c Enterprise / Standard Edition 2** | Cuenta de Oracle | `ORCLPDB1` | `database/enterprise:21.3.0.0` | — |
| **Otra versión** | | | cualquier etiqueta de `database/free`, `database/express` o `database/enterprise` | cualquier etiqueta de `gvenzl/oracle-free` o `gvenzl/oracle-xe` |

- Con **«Otra versión»** el asistente consulta en ese momento **todas las etiquetas** disponibles
  (por ejemplo 23.4, 23.26.1, 21.3.0-slim-faststart…) y te deja elegir cualquiera. `oracle-db versiones`
  muestra la lista completa del catálogo.
- **lite / slim**: imágenes reducidas (menos funciones). **full**: con todo. **faststart**: la base ya viene
  creada, arranca antes pero ocupa más.
- **Enterprise y Standard** se pueden usar gratis para aprender y desarrollar, pero Oracle exige una cuenta:
  1. Crea una cuenta gratuita en oracle.com.
  2. Entra en <https://container-registry.oracle.com>, abre **Database → enterprise** y **acepta la licencia**.
  3. En tu perfil del registro, genera un **Auth Token**.
  4. El asistente te pedirá tu usuario (correo) y ese token. **Solo se usan para la descarga y no se guardan.**

  Su primera puesta en marcha tarda mucho más (entre 15 y 45 minutos) y necesita más memoria.

---

## Requisitos

| | Mínimo | Recomendado |
|---|---|---|
| Sistema | Ubuntu 24.04 LTS de 64 bits (x86-64) con escritorio | |
| Memoria RAM | 4 GB | 8 GB o más (Enterprise: 8 GB) |
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
git clone https://github.com/Piratapacorro/instalador-oracle-db-ubuntu.git
cd instalador-oracle-db-ubuntu
./oracle-db.sh instalar
```

¿No tienes `git`? Descarga solo el script:

```bash
wget https://raw.githubusercontent.com/Piratapacorro/instalador-oracle-db-ubuntu/main/oracle-db.sh
chmod +x oracle-db.sh
./oracle-db.sh instalar
```

> Ejecútalo con **tu usuario normal**, no con `sudo`: la herramienta te pedirá la contraseña en una
> ventana cuando haga falta. Si prefieres ver antes lo que hará sin cambiar nada:
> `./oracle-db.sh --simular instalar`.

¿Ya sabes qué versión te piden? Puedes proponerla directamente:

```bash
./oracle-db.sh --oracle 21c instalar      # 26ai, 23ai, 21c, 18c, 11g, 19c o 21c-ee
```

### Las ventanas del asistente

| Ventana | Qué hacer (lo recomendado ya viene marcado) |
|---|---|
| Bienvenida | **Empezar** |
| Motor de contenedores | Docker Desktop |
| Versión de Oracle Database | la que necesites (26ai viene marcada como recomendada) |
| Imagen de Oracle | la marcada como recomendada. Si tu red bloquea Oracle Cloud, te propondrá la de Docker Hub |
| Cuenta de Oracle | solo para Enterprise/Standard: tu correo y tu Auth Token |
| Nombre del contenedor | el propuesto (por ejemplo `oracle-26ai` u `oracle-21c-xe`) |
| Puerto | `1521` (si ya lo usa otra base de datos, te propone el siguiente libre) |
| Opciones | crear usuario de trabajo ✔, arrancar Oracle con Docker ✔, acceso desde la red ✘, SQLcl / SQL Developer si los quieres |
| Usuario de trabajo | `alumno` (o el nombre que quieras) |
| Contraseñas | las tuyas: administración y la de tu usuario (vacía = la misma) |
| Resumen | **Instalar** |
| Contraseña de administrador | tu contraseña de Ubuntu (la de iniciar sesión) |

Después, una **barra de progreso** muestra cada paso, cuánto falta de la descarga y la preparación de Oracle.
Al final, una ventana te enseña los datos de conexión.

Las contraseñas deben tener **8-30 caracteres**, empezar por letra e incluir **mayúscula, minúscula y número**
(solo letras sin tildes, números, `_` y `#`). **No se guardan en ningún sitio: apúntalas.**

> **¿Quieres varias versiones a la vez?** Instala una y luego vuelve a ejecutar el asistente con otra:
> cada versión usa su propio contenedor y su propio puerto. El panel y el comando `oracle-db` gestionan
> la última que instalaste.

> **¿Sin escritorio o prefieres la terminal?** `./oracle-db.sh --tui instalar` hace las mismas
> preguntas en ventanas dentro de la terminal, y `--texto` las hace en texto plano.

### El único paso manual: aceptar el acuerdo de Docker

La primera vez que se abre Docker Desktop puede aparecer el **Docker Subscription Service Agreement**.
Léelo y pulsa **Accept** (es gratuito para uso personal y educativo). Puedes saltarte el inicio de
sesión (*Skip*). La instalación continúa sola en cuanto Docker Desktop está listo.

> Si la herramienta te dice que **cierres sesión** (pasa si hubo que añadirte al grupo `kvm`), cierra
> sesión, vuelve a entrar y ejecuta de nuevo `./oracle-db.sh instalar`: recordará tus respuestas.

---

## Conectarte a la base de datos

| Dato | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `1521` (o el que elegiste) |
| **Servicio para trabajar** | **`FREEPDB1`** (26ai/23ai), **`XEPDB1`** (21c/18c XE), **`XE`** (11g), **`ORCLPDB1`** (19c/21c Enterprise) |
| Tu usuario | el que creaste (p. ej. `ALUMNO`) |
| Administración | `SYSTEM` y `SYS` (como SYSDBA); en las imágenes oficiales con PDB, también `PDBADMIN` |

`oracle-db info` te muestra siempre los datos exactos de tu instalación.

**Desde la terminal** (SQL*Plus dentro del contenedor, no hay que instalar nada más):

```bash
oracle-db sql              # con tu usuario de trabajo (te pide la contraseña)
oracle-db sql system       # con otro usuario
oracle-db sysdba           # como SYSDBA (administración)
```

**SQL Developer / DBeaver / VS Code (SQL Developer Extension):** nueva conexión de tipo *Básico*,
host `localhost`, puerto `1521`, **Nombre del servicio** el de tu versión (¡no «SID»!), tu usuario y contraseña.

**JDBC:** `jdbc:oracle:thin:@//localhost:1521/FREEPDB1` (cambia el servicio según tu versión)

**SQLcl** (si lo instalaste): `oracle-db sqlcl` o `sql alumno@//localhost:1521/FREEPDB1`

---

## Uso diario

### Con ventanas: la aplicación «Oracle Database (Docker)»

Búscala en el menú de aplicaciones de Ubuntu (tecla Super y escribe *Oracle*). Abre un panel que te dice
si Oracle está en marcha y te deja:

- **Arrancar** y **detener** Oracle (y cerrar Docker Desktop para liberar memoria).
- Abrir **SQL*Plus** con tu usuario o como SYSDBA (en una terminal).
- Ver los **datos de conexión**, el **estado detallado** y el **registro** de Oracle.
- **Cambiar o desbloquear contraseñas** y **crear otros usuarios**.
- **Instalar otra versión**, hacer un **diagnóstico**, **reinstalar** o **desinstalar**.

### Con la terminal

| Comando | Qué hace |
|---|---|
| `oracle-db` | Abre el panel (ventanas) o un menú en la terminal |
| `oracle-db estado` | ¿Están en marcha Docker y la base de datos? |
| `oracle-db iniciar` | Arranca Docker (si hace falta) y Oracle |
| `oracle-db parar` | Detiene Oracle de forma ordenada (`--todo` cierra también Docker Desktop) |
| `oracle-db sql [usuario]` | SQL*Plus conectado a la base de trabajo |
| `oracle-db sysdba` | SQL*Plus como SYSDBA |
| `oracle-db info` | Muestra los datos de conexión |
| `oracle-db password` | Cambia o **desbloquea** contraseñas (también si las olvidaste) |
| `oracle-db crear-usuario` | Crea otro usuario (p. ej. uno por proyecto) |
| `oracle-db versiones` | Lista de versiones e imágenes que se pueden instalar |
| `oracle-db logs` | Registro del contenedor |
| `oracle-db comprobar` | Diagnóstico de requisitos, red y estado |
| `oracle-db desinstalar` | Elimina lo que elijas (contenedor, datos, imagen, Docker Desktop…) |

> Si justo después de instalar la terminal dice `oracle-db: orden no encontrada`, ejecuta
> `source ~/.profile` (o cierra sesión y vuelve a entrar). Mientras tanto también puedes usar
> `~/.local/bin/oracle-db`.

---

## ¿Estás en la red del instituto? Imagen oficial bloqueada

Las imágenes **oficiales** de Oracle (`container-registry.oracle.com`) se descargan desde
*Oracle Cloud Object Storage*. Algunas redes (por ejemplo, redes de centros educativos) bloquean ese
servicio, y la descarga falla con `i/o timeout`.

La herramienta lo **detecta antes de empezar** y te propone la imagen equivalente de **Docker Hub**
(`gvenzl/oracle-free` o `gvenzl/oracle-xe`): es la misma base de datos, empaquetada por Gerald Venzl
(product manager de Oracle Database) y muy usada. Si aun así eliges la oficial y la descarga falla, te
ofrece cambiar a la de Docker Hub. En casa normalmente funcionan las dos.

Las ediciones **Enterprise y Standard** solo existen como imagen oficial: en una red con ese bloqueo no se
pueden descargar.

---

## Qué instala y dónde

| Qué | Dónde |
|---|---|
| Docker Desktop | `/opt/docker-desktop` (paquete `docker-desktop`) |
| Repositorio de Docker | `/etc/apt/sources.list.d/docker.sources` y `/etc/apt/keyrings/docker.asc` |
| Máquina virtual de Docker Desktop (imágenes y volúmenes) | `~/.docker/desktop/` |
| Comando `oracle-db` | `~/.local/bin/oracle-db` |
| Acceso «Oracle Database (Docker)» del menú (e icono) | `~/.local/share/applications/oracle-db.desktop` y `~/.local/share/oracle-db/oracle-db.svg` |
| Configuración (sin contraseñas) y datos de conexión | `~/.config/oracle-db/` |
| Registros de instalación | `~/.local/state/oracle-db/` |
| SQLcl / SQL Developer (opcionales) | `~/.local/share/oracle-db/` |
| Tu base de datos | un volumen de Docker por versión (por ejemplo `oracle-26ai-datos`) |

> Si tenías instalada la versión anterior de esta herramienta (comando `oracle23ai`), la primera vez que
> ejecutes `oracle-db.sh` se pasa sola a los nombres nuevos, sin tocar tu contenedor ni tus datos.

### Seguridad

- Las contraseñas **nunca** se escriben en disco, en la línea de órdenes ni en variables de entorno
  del contenedor: se aplican con SQL por la entrada estándar. `docker inspect` no las muestra.
- La cuenta de Oracle (Enterprise/Standard) se usa con una sesión **temporal** solo para la descarga
  y se borra al terminar.
- Por defecto el puerto solo escucha en `127.0.0.1` (nadie de tu red puede conectarse).
- Se verifica la **huella de la clave GPG** de Docker y la **suma SHA-256** del paquete de Docker Desktop.
- Nada se descarga de sitios que no sean oficiales (Docker, Oracle, Docker Hub).
- El usuario de trabajo usa un perfil sin caducidad de contraseña (`PERFIL_PRACTICAS`) para que
  no caduque a mitad de curso.

---

## Más documentación

- [Instalación manual paso a paso](docs/PASOS_MANUALES.md): los mismos pasos que hace la herramienta, comando a comando.
- [Solución de problemas](docs/SOLUCION_DE_PROBLEMAS.md): errores frecuentes (KVM, memoria, `ORA-12514`, cuentas bloqueadas…).
- Pruebas: `tests/prueba-gui.sh` prueba el modo gráfico con un zenity simulado (se ejecuta en cada cambio en GitHub).

---

## Desinstalar

```bash
oracle-db desinstalar
```

Marca lo que quieras eliminar: el contenedor, **los datos** (pide escribir `BORRAR`), la imagen,
SQLcl/SQL Developer, Docker Desktop entero o el propio comando.

---

## Aviso legal

- **Oracle Database Free y Express Edition** se distribuyen bajo los términos de licencia gratuitos de Oracle.
  **Enterprise y Standard Edition** requieren aceptar la licencia en container-registry.oracle.com.
- **Docker Desktop** requiere aceptar el *Docker Subscription Service Agreement* (gratuito para uso
  personal, educativo y pequeñas empresas).
- Este proyecto no está afiliado a Oracle ni a Docker. Se distribuye bajo licencia [MIT](LICENSE),
  sin garantía de ningún tipo.
