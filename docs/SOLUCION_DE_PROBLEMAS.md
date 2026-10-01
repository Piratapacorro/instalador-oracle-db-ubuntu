# Solución de problemas

Antes de nada, ejecuta el diagnóstico. Revisa requisitos, Docker, red y estado de la base de datos:

```bash
oracle-db comprobar          # o: ./oracle-db.sh comprobar
```

Los registros detallados de cada instalación están en `~/.local/state/oracle-db/`.

---

## Las ventanas (interfaz gráfica)

### No veo la ventana del asistente

Puede haberse abierto **detrás de otras ventanas**: búscala con `Alt + Tab`. Las ventanas se llaman
«Bienvenida», «Opciones», «Contraseñas», etc.

### No aparece ninguna ventana

- Si estás conectado por SSH o no tienes escritorio, usa las ventanas de terminal: `./oracle-db.sh --tui instalar`.
- Si falta zenity (el programa que dibuja las ventanas): `sudo apt install zenity`, o usa `--tui`.

### Me vuelve a pedir la «Contraseña de administrador»

- Si la escribes mal, la ventana aparece otra vez (Ubuntu da tres intentos).
- Si la instalación dura más de 15 minutos, Ubuntu puede volver a pedirla para los últimos pasos. Es normal.

### La barra de progreso parece parada

Las descargas grandes (Docker Desktop y la imagen de Oracle) y la primera preparación de Oracle tardan varios
minutos. El texto de la ventana dice qué está haciendo y cuánto tiempo lleva. Si quieres más detalle, mira el
registro en `~/.local/state/oracle-db/`.

---

## Durante la instalación

### «La descarga de la imagen oficial falla» (`i/o timeout`, `objectstorage…oraclecloud.com`)

Tu red bloquea *Oracle Cloud Object Storage*, de donde se descargan las imágenes oficiales
(ocurre en redes de algunos centros educativos: el DNS devuelve una dirección «sinkhole»).
Puedes comprobarlo así:

```bash
getent hosts objectstorage.us-phoenix-1.oraclecloud.com   # si sale una IP 10.x.x.x o 192.168.x.x, está bloqueado
```

**Solución:** elige una imagen de **Docker Hub** (`gvenzl/oracle-free` para 26ai/23ai, `gvenzl/oracle-xe`
para 21c/18c/11g). La herramienta te la propone automáticamente. Es la misma base de datos, así que tus
prácticas funcionan igual. Las ediciones **Enterprise y Standard** solo existen como imagen oficial: en una
red así no se pueden descargar (prueba desde otra red).

### Enterprise / Standard: «unauthorized», «denied» o no inicia sesión

- Comprueba que **aceptaste la licencia** en <https://container-registry.oracle.com> → Database →
  **enterprise** (con la misma cuenta).
- Como contraseña se usa un **Auth Token** que se genera en tu perfil del registro, no la contraseña de tu
  cuenta de Oracle.
- El usuario es el correo de tu cuenta de Oracle.

### Enterprise / Standard: la base de datos tarda muchísimo en estar lista

Es normal: la primera vez se crea entera y tarda **entre 15 y 45 minutos** (necesita además unos 4 GB de
memoria para Docker). Las siguientes veces arranca en uno o dos minutos.

### 11g XE no arranca: `ORA-00845: MEMORY_TARGET not supported on this system`

La 11g necesita memoria compartida. La herramienta ya crea el contenedor con `--shm-size=1g`; si lo creaste a
mano, añade esa opción a `docker run`.

### «La CPU no ofrece virtualización» / «No existe /dev/kvm»

- **Ordenador normal:** activa la virtualización en la BIOS/UEFI. Suele llamarse *Intel Virtualization
  Technology (VT-x)*, *AMD-V* o *SVM Mode*.
- **Ubuntu dentro de una máquina virtual (VirtualBox, VMware, Hyper-V):** activa la *virtualización anidada*
  en el programa de virtualización o, más sencillo, deja que la herramienta use **Docker Engine**.

### «Hace falta CERRAR SESIÓN para continuar»

Se te ha añadido al grupo `kvm` y tu sesión actual aún no lo sabe. Cierra sesión, vuelve a entrar y ejecuta
de nuevo `./oracle-db.sh instalar`: recordará tus respuestas (salvo las contraseñas).

### Docker Desktop no arranca o se queda en «Starting the Docker Engine…»

1. Comprueba que tienes acceso a KVM: `ls -l /dev/kvm` (tu usuario debe poder leer y escribir en él).
2. Ciérralo y vuelve a abrirlo:

   ```bash
   systemctl --user restart docker-desktop
   ```

3. Mira los registros: `~/.docker/desktop/log/host/`.
4. Como último recurso: en Docker Desktop, **Troubleshoot (icono del bicho) → Reset to factory defaults**
   (borra imágenes y contenedores de Docker Desktop).

### No aparece la ventana del acuerdo de Docker (Subscription Service Agreement)

Abre **Docker Desktop** desde el menú de aplicaciones. La herramienta espera hasta 20 minutos a que lo aceptes.

### «Docker Desktop solo tiene X GB de RAM»

En Docker Desktop: **Settings → Resources → Advanced → Memory limit**. Súbelo a 4 GB o más y pulsa
**Apply & restart**. Luego elige «Ya lo he cambiado: comprobar otra vez».

### «Paquetes en conflicto» (`docker.io`, `podman-docker`…)

Son versiones de Docker de Ubuntu, incompatibles con las oficiales. La herramienta las desinstala si se lo
permites. Tus imágenes y contenedores de `/var/lib/docker` no se borran.

### «No se pudo bloquear /var/lib/dpkg/lock» o apt se queda esperando

Ubuntu está instalando actualizaciones en segundo plano. La herramienta espera hasta 5 minutos. Si sigue igual,
espera a que termine el «Actualizador de software» y vuelve a ejecutarla.

### «error getting credentials» al descargar la imagen

Docker Desktop guarda las credenciales con `pass`, que no está inicializado. La herramienta reintenta la
descarga de forma anónima (las imágenes Free y XE son públicas). Si quieres usar `docker login`, sigue la
[guía de Docker para inicializar `pass`](https://docs.docker.com/desktop/setup/sign-in/#signing-in-with-docker-desktop-for-linux).

### «El puerto 1521 ya lo usa otro programa»

Otra base de datos (u otro contenedor) ya usa el puerto. Averigua cuál:

```bash
ss -ltnp | grep 1521
docker ps
```

El asistente ya te propone el siguiente puerto libre (por ejemplo, `1522`): así puedes tener varias versiones
de Oracle a la vez. Usa ese puerto al conectarte (`oracle-db info` te lo recuerda).

---

## Al conectarte

El **servicio** depende de la versión: `FREEPDB1` (26ai/23ai), `XEPDB1` (21c/18c XE), `XE` (11g) u
`ORCLPDB1` (Enterprise/Standard). `oracle-db info` te dice el tuyo.

| Error | Causa habitual | Solución |
|---|---|---|
| `ORA-12541: No listener` / conexión rechazada | Oracle o Docker están parados | `oracle-db iniciar` |
| `ORA-12514: … service … is not registered` | La base de datos aún está arrancando, o el servicio no es el de tu versión | Espera un minuto; `oracle-db estado` y `oracle-db info` |
| `ORA-12514` usando «SID» | En SQL Developer elegiste **SID** en vez de **Nombre del servicio** | Usa **Nombre del servicio** con el de tu versión |
| `ORA-01017: invalid username/password` | Contraseña incorrecta (distingue mayúsculas y minúsculas) | `oracle-db password` |
| `ORA-28000: the account is locked` | Demasiados intentos fallidos | `oracle-db password` (también desbloquea) |
| `ORA-65096: invalid common user or role name` | Estás creando usuarios en el contenedor raíz (CDB) | Conéctate a tu PDB o usa `oracle-db crear-usuario` |
| `ORA-01950: no privileges on tablespace` | Usuario creado a mano sin cuota | `ALTER USER x QUOTA UNLIMITED ON USERS;` |
| `ORA-01919: role 'DB_DEVELOPER_ROLE' does not exist` | Ese rol solo existe desde 23ai | En 21c/19c/18c/11g concede los permisos sueltos (ver [pasos manuales](PASOS_MANUALES.md)) |

### «oracle-db: orden no encontrada»

La carpeta `~/.local/bin` se añade al PATH al iniciar sesión. Ejecuta `source ~/.profile` o cierra sesión
y vuelve a entrar. Mientras tanto: `~/.local/bin/oracle-db`.

### Olvidé la contraseña

```bash
oracle-db password
```

La herramienta entra como SYSDBA desde dentro del contenedor, así que **no necesita la contraseña antigua**.

### SQL Developer pide «the full pathname of a JDK installation»

Escribe `/usr/lib/jvm/java-17-openjdk-amd64` y pulsa Enter (solo la primera vez).

---

## Empezar de cero

```bash
oracle-db desinstalar      # marca «Datos» para borrar también la base de datos (pide escribir BORRAR)
./oracle-db.sh instalar
```

Si instalaste Oracle a mano con otro nombre de contenedor, bórralo antes:

```bash
docker rm -f <nombre>
docker volume rm <volumen>
```

---

## Pedir ayuda

Si nada de esto funciona, abre una *issue* en el repositorio. Adjunta la salida de `oracle-db comprobar`
y el último registro de `~/.local/state/oracle-db/`. Los registros no contienen contraseñas.
