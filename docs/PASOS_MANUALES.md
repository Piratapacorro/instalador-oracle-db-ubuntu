# Instalación manual paso a paso

Esta guía hace **exactamente lo mismo que `oracle-db.sh`**, pero a mano, comando a comando y para
cualquier versión de Oracle Database. Sirve para entender qué ocurre por debajo o para arreglar algo
si la herramienta falla.

> Ejecuta los comandos como **tu usuario normal** (no como root). Los que empiezan por `sudo`
> te pedirán tu contraseña de Ubuntu.

---

## 0. Comprobar los requisitos

```bash
# Ubuntu 24.04 de 64 bits (x86-64)
lsb_release -ds; dpkg --print-architecture          # debe decir amd64

# Memoria (8 GB recomendados) y disco libre (25 GB recomendados)
free -h
df -h / ~

# Virtualización de la CPU: debe salir un número mayor que 0
grep -Ecw 'vmx|svm' /proc/cpuinfo
```

Si la última orden devuelve `0`, la virtualización está desactivada en la BIOS/UEFI
(actívala: *Intel VT-x* / *AMD-V* o *SVM*) o tu Ubuntu es una máquina virtual sin
virtualización anidada. En ese caso **no podrás usar Docker Desktop**: salta al
[anexo A (Docker Engine)](#anexo-a-docker-engine-en-lugar-de-docker-desktop).

---

## 1. Paquetes básicos

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg cpu-checker
```

Si tu escritorio **no** es GNOME (por ejemplo KDE o XFCE), Docker Desktop también necesita:

```bash
sudo apt-get install -y gnome-terminal
```

---

## 2. Virtualización KVM

```bash
# Cargar los módulos (kvm_intel en Intel, kvm_amd en AMD)
sudo modprobe kvm
sudo modprobe kvm_intel     # o: sudo modprobe kvm_amd

# Comprobar
kvm-ok                      # debe decir "KVM acceleration can be used"
ls -l /dev/kvm

# Dar permiso a tu usuario
sudo usermod -aG kvm "$USER"
```

Si `ls -l /dev/kvm` muestra `crw-rw----+`, normalmente ya tienes acceso. Si Docker Desktop
se queja de KVM más adelante, **cierra sesión y vuelve a entrar** para que se aplique el grupo `kvm`.

---

## 3. Repositorio oficial de Docker

Docker Desktop depende de paquetes de este repositorio (`docker-ce-cli`).

```bash
# Clave GPG oficial de Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# (Opcional, recomendado) Verificar la huella: debe ser 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
gpg --show-keys --with-colons /etc/apt/keyrings/docker.asc | awk -F: '/^fpr:/ {print $10; exit}'

# Añadir el repositorio
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
```

> Si ya tenías el repositorio configurado (por ejemplo en `/etc/apt/sources.list.d/docker.list`),
> no lo añadas otra vez: apt daría un error de «Signed-By» en conflicto.

Si tienes instalados paquetes de Docker **no oficiales**, desinstálalos antes
(tus imágenes y contenedores en `/var/lib/docker` no se borran):

```bash
sudo apt-get remove -y docker.io docker-cli podman-docker
```

---

## 4. Descargar e instalar Docker Desktop

```bash
cd /tmp
curl -fLO https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb

# Verificar la suma SHA-256 con la que publica Docker
curl -fsSL https://desktop.docker.com/linux/main/amd64/checksums.txt | grep 'docker-desktop-amd64.deb'
sha256sum docker-desktop-amd64.deb          # las dos sumas deben coincidir

sudo apt-get install -y ./docker-desktop-amd64.deb
```

Al terminar, apt puede mostrar este aviso, que **se puede ignorar**:

```
N: Download is performed unsandboxed as root as file '.../docker-desktop-amd64.deb' couldn't be accessed by user '_apt'
```

---

## 5. Arrancar Docker Desktop y aceptar el acuerdo

```bash
systemctl --user start docker-desktop
```

(O ábrelo desde el menú de aplicaciones: **Docker Desktop**.)

Si aparece el **Docker Subscription Service Agreement**, léelo y pulsa **Accept**
(es gratuito para uso personal y educativo). Puedes saltarte el inicio de sesión (*Skip*).

Comprueba que responde:

```bash
docker context use desktop-linux
docker info --format 'Docker {{.ServerVersion}} · RAM {{.MemTotal}} bytes'
```

Opcional: que se abra solo al iniciar sesión.

```bash
systemctl --user enable docker-desktop
```

### Memoria para Docker

Oracle Free y XE necesitan al menos **3 GB** (mejor 4 GB) dentro de Docker Desktop; Enterprise/Standard,
unos **4 GB** o más. Si `docker info` muestra menos, en Docker Desktop ve a
**Settings → Resources → Advanced → Memory limit**, súbelo y pulsa **Apply & restart**.

---

## 6. Elegir la versión y descargar su imagen

| Versión | Imagen oficial | Imagen de Docker Hub | Servicio para trabajar | Ruta de datos en el contenedor |
|---|---|---|---|---|
| 26ai Free | `container-registry.oracle.com/database/free:latest` | `gvenzl/oracle-free:23` | `FREEPDB1` | `/opt/oracle/oradata` |
| 23ai Free | `container-registry.oracle.com/database/free:23.9.0.0` | `gvenzl/oracle-free:23.9` | `FREEPDB1` | `/opt/oracle/oradata` |
| 21c XE | `container-registry.oracle.com/database/express:21.3.0-xe` | `gvenzl/oracle-xe:21` | `XEPDB1` | `/opt/oracle/oradata` |
| 18c XE | `container-registry.oracle.com/database/express:18.4.0-xe` | `gvenzl/oracle-xe:18` | `XEPDB1` | `/opt/oracle/oradata` |
| 11g XE | — | `gvenzl/oracle-xe:11` | `XE` (no tiene PDB) | `/u01/app/oracle/oradata` |
| 19c Enterprise/Standard | `container-registry.oracle.com/database/enterprise:19.3.0.0` | — | `ORCLPDB1` | `/opt/oracle/oradata` |
| 21c Enterprise/Standard | `container-registry.oracle.com/database/enterprise:21.3.0.0` | — | `ORCLPDB1` | `/opt/oracle/oradata` |

Todas las etiquetas disponibles (también actualizaciones concretas como 23.4 o 23.26.1):

- Oficiales: <https://container-registry.oracle.com> (Database → free / express / enterprise).
- Docker Hub: <https://hub.docker.com/r/gvenzl/oracle-free/tags> y <https://hub.docker.com/r/gvenzl/oracle-xe/tags>.

Descarga la que elijas, por ejemplo:

```bash
docker pull container-registry.oracle.com/database/free:latest   # 26ai, imagen oficial
docker pull gvenzl/oracle-xe:21                                   # 21c XE, Docker Hub
```

> **¿La descarga oficial falla con `i/o timeout` o `objectstorage...oraclecloud.com`?**
> Tu red bloquea el almacenamiento de Oracle Cloud (pasa en algunas redes de centros
> educativos). Usa la imagen equivalente de Docker Hub.

### Enterprise y Standard: iniciar sesión antes de descargar

1. Crea una cuenta gratuita en oracle.com.
2. En <https://container-registry.oracle.com> abre **Database → enterprise** y **acepta la licencia**.
3. En tu perfil del registro genera un **Auth Token**.
4. Inicia sesión (te pedirá el usuario y, como contraseña, el token), descarga y cierra la sesión:

```bash
docker login container-registry.oracle.com
docker pull container-registry.oracle.com/database/enterprise:19.3.0.0
docker logout container-registry.oracle.com
```

---

## 7. Crear el volumen y el contenedor

Cambia `oracle-26ai` por un nombre propio de tu versión (por ejemplo `oracle-21c-xe`) si vas a tener varias.

```bash
docker volume create oracle-26ai-datos
```

**Imagen oficial Free o XE:**

```bash
docker run -d --name oracle-26ai \
  -p 127.0.0.1:1521:1521 \
  -v oracle-26ai-datos:/opt/oracle/oradata \
  -e ORACLE_CHARACTERSET=AL32UTF8 \
  --restart unless-stopped \
  container-registry.oracle.com/database/free:latest
```

**Imagen de Docker Hub (gvenzl), Free o XE:**

```bash
docker run -d --name oracle-21c-xe \
  -p 127.0.0.1:1521:1521 \
  -v oracle-21c-xe-datos:/opt/oracle/oradata \
  -e ORACLE_RANDOM_PASSWORD=yes \
  --restart unless-stopped \
  gvenzl/oracle-xe:21
```

Para **11g XE** cambia la ruta de datos y añade memoria compartida:
`-v oracle-11g-xe-datos:/u01/app/oracle/oradata --shm-size=1g` con la imagen `gvenzl/oracle-xe:11`.

**Enterprise / Standard Edition (19c o 21c):**

```bash
docker run -d --name oracle-19c-ee \
  -p 127.0.0.1:1521:1521 \
  -v oracle-19c-ee-datos:/opt/oracle/oradata \
  -e ORACLE_SID=ORCLCDB -e ORACLE_PDB=ORCLPDB1 \
  -e ORACLE_EDITION=enterprise \
  -e ORACLE_CHARACTERSET=AL32UTF8 \
  --restart unless-stopped \
  container-registry.oracle.com/database/enterprise:19.3.0.0
```

(Para Standard Edition 2: `-e ORACLE_EDITION=standard`.)

Notas:

- `-p 127.0.0.1:1521:1521` solo permite conexiones desde tu equipo. Para aceptar conexiones
  de tu red usa `-p 1521:1521`. Si ya tienes otra base de datos en el 1521, usa otro puerto
  del equipo: `-p 127.0.0.1:1522:1521`.
- El volumen guarda la base de datos: si borras el contenedor, los datos siguen ahí.
- No pasamos la contraseña con `-e ORACLE_PWD=...` ni `-e ORACLE_PASSWORD=...` para que no quede
  visible en `docker inspect`: la imagen genera una aleatoria temporal y en el paso 9 la cambiamos por la nuestra.

---

## 8. Esperar a que la base de datos esté lista

```bash
docker logs -f oracle-26ai
```

Espera a ver este mensaje y pulsa `Ctrl+C`:

```
#########################
DATABASE IS READY TO USE!
#########################
```

La primera vez tarda entre unos segundos y 15 minutos (Free y XE), o entre 15 y 45 minutos (Enterprise/Standard).

---

## 9. Poner tus contraseñas y crear tu usuario

Entra como SYSDBA dentro del contenedor (no pide contraseña):

```bash
docker exec -it oracle-26ai sqlplus / as sysdba
```

Y ejecuta (cambia `TuClave123`, `alumno` y `Alumno123x` por los tuyos):

```sql
-- Administradores (SYS y SYSTEM son comunes a toda la base de datos)
ALTER USER SYS IDENTIFIED BY "TuClave123";
ALTER USER SYSTEM IDENTIFIED BY "TuClave123" ACCOUNT UNLOCK;

-- Pasar a la base de trabajo (PDB): FREEPDB1, XEPDB1 u ORCLPDB1 según tu versión.
-- En 11g XE no hay PDB: sáltate esta línea y la de PDBADMIN.
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER USER PDBADMIN IDENTIFIED BY "TuClave123" ACCOUNT UNLOCK;   -- solo en imágenes oficiales con PDB

-- Perfil sin caducidad de contraseña (para que no caduque a mitad de curso)
CREATE PROFILE PERFIL_PRACTICAS LIMIT PASSWORD_LIFE_TIME UNLIMITED;

-- Tu usuario de trabajo
CREATE USER alumno IDENTIFIED BY "Alumno123x"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS
  PROFILE PERFIL_PRACTICAS;
GRANT CREATE SESSION TO alumno;
```

Y los permisos, según la versión:

```sql
-- 26ai y 23ai: el rol para desarrolladores lo incluye todo
GRANT DB_DEVELOPER_ROLE TO alumno;

-- 21c, 19c, 18c y 11g (no existe DB_DEVELOPER_ROLE):
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER,
      CREATE TYPE, CREATE SYNONYM, CREATE MATERIALIZED VIEW TO alumno;

EXIT
```

> Las contraseñas de Oracle distinguen **mayúsculas y minúsculas**. Evita `@`, `/`, comillas y
> espacios: rompen las cadenas de conexión.

---

## 10. Conectarte

| Dato | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `1521` (o el que pusiste en `-p`) |
| Servicio | el de tu versión: `FREEPDB1`, `XEPDB1`, `XE` u `ORCLPDB1` |

```bash
# SQL*Plus dentro del contenedor (te pide la contraseña)
docker exec -it oracle-26ai sqlplus alumno@//localhost:1521/FREEPDB1
```

- **JDBC:** `jdbc:oracle:thin:@//localhost:1521/FREEPDB1`
- **SQL Developer:** Nueva conexión → Tipo *Básico* → Host `localhost` → Puerto `1521` →
  **Nombre del servicio** el de tu versión (no «SID»).

---

## 11. Uso diario

```bash
docker start oracle-26ai          # arrancar (Docker Desktop debe estar abierto)
docker stop -t 120 oracle-26ai    # parar de forma ordenada
docker ps -a                      # ver el estado
docker logs -f oracle-26ai        # ver el registro
```

---

## 12. Opcional: clientes en tu Ubuntu

### SQLcl (línea de comandos)

```bash
sudo apt-get install -y openjdk-17-jre-headless unzip
curl -fLo /tmp/sqlcl.zip https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip
mkdir -p ~/.local/share/oracle-db && unzip -q /tmp/sqlcl.zip -d ~/.local/share/oracle-db
~/.local/share/oracle-db/sqlcl/bin/sql alumno@//localhost:1521/FREEPDB1
```

### SQL Developer 24.3.1 (gráfico)

```bash
sudo apt-get install -y openjdk-17-jdk unzip
curl -fLo /tmp/sqldeveloper.zip \
  https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-24.3.1.347.1826-no-jre.zip
unzip -q /tmp/sqldeveloper.zip -d ~/.local/share/oracle-db
~/.local/share/oracle-db/sqldeveloper/sqldeveloper.sh
```

La primera vez pregunta la ruta del JDK: escribe `/usr/lib/jvm/java-17-openjdk-amd64`.

---

## Anexo A: Docker Engine en lugar de Docker Desktop

Para equipos sin virtualización (máquinas virtuales sin virtualización anidada, servidores sin escritorio…).
Tras el paso 3 (repositorio de Docker):

```bash
sudo apt-get remove -y docker.io docker-cli docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"      # cierra sesión para usar docker sin sudo
```

Después sigue desde el paso 6 (usa `sudo docker ...` hasta que cierres sesión).
