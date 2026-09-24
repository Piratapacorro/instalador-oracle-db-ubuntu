# Instalación manual paso a paso

Esta guía hace **exactamente lo mismo que `oracle23ai.sh`**, pero a mano, comando a comando.
Sirve para entender qué ocurre por debajo o para arreglar algo si la herramienta falla.

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

Si `ls -l /dev/kvm` muestra `crw-rw----+` normalmente ya tienes acceso. Si Docker Desktop
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

La primera vez aparece el **Docker Subscription Service Agreement**: léelo y pulsa **Accept**
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

Oracle necesita al menos **3 GB** (mejor 4 GB) dentro de Docker Desktop. Si `docker info`
muestra menos, en Docker Desktop ve a **Settings → Resources → Advanced → Memory limit**,
súbelo a 4 GB o más y pulsa **Apply & restart**.

---

## 6. Descargar la imagen de Oracle Database Free

Elige **una**:

```bash
# Imagen oficial de Oracle · 23ai (23.9) · ~3,4 GB
docker pull container-registry.oracle.com/database/free:23.9.0.0

# Alternativa en Docker Hub (Gerald Venzl) · 23ai (23.9) · ~1 GB
docker pull gvenzl/oracle-free:23.9
```

> **¿La descarga oficial falla con `i/o timeout` o `objectstorage...oraclecloud.com`?**
> Tu red bloquea el almacenamiento de Oracle Cloud (pasa en algunas redes de centros
> educativos). Usa la imagen de Docker Hub.

Etiquetas útiles:

| Imagen | Versión |
|---|---|
| `container-registry.oracle.com/database/free:23.9.0.0` | 23ai 23.9, completa |
| `container-registry.oracle.com/database/free:23.9.0.0-lite` | 23ai 23.9, reducida |
| `container-registry.oracle.com/database/free:latest` | 26ai (23.26.x), la más reciente |
| `gvenzl/oracle-free:23.9` · `23.9-full` | 23ai 23.9 (normal / completa) |
| `gvenzl/oracle-free:23` | 26ai (23.26.x) |

---

## 7. Crear el volumen y el contenedor

```bash
docker volume create oracle23ai-datos
```

**Imagen oficial:**

```bash
docker run -d --name oracle23ai \
  -p 127.0.0.1:1521:1521 \
  -v oracle23ai-datos:/opt/oracle/oradata \
  -e ORACLE_CHARACTERSET=AL32UTF8 \
  --restart unless-stopped \
  container-registry.oracle.com/database/free:23.9.0.0
```

**Imagen de Docker Hub (gvenzl):**

```bash
docker run -d --name oracle23ai \
  -p 127.0.0.1:1521:1521 \
  -v oracle23ai-datos:/opt/oracle/oradata \
  -e ORACLE_RANDOM_PASSWORD=yes \
  --restart unless-stopped \
  gvenzl/oracle-free:23.9
```

Notas:

- `-p 127.0.0.1:1521:1521` solo permite conexiones desde tu equipo. Para aceptar conexiones
  de tu red usa `-p 1521:1521`.
- El volumen `oracle23ai-datos` guarda la base de datos: si borras el contenedor, los datos siguen ahí.
- No pasamos la contraseña con `-e ORACLE_PWD=...` para que no quede visible en `docker inspect`:
  la imagen genera una aleatoria temporal y en el paso 9 la cambiamos por la nuestra.

---

## 8. Esperar a que la base de datos esté lista

```bash
docker logs -f oracle23ai
```

Espera a ver este mensaje (la primera vez tarda entre 2 y 15 minutos) y pulsa `Ctrl+C`:

```
#########################
DATABASE IS READY TO USE!
#########################
```

---

## 9. Poner tus contraseñas y crear tu usuario

Entra como SYSDBA dentro del contenedor (no pide contraseña):

```bash
docker exec -it oracle23ai sqlplus / as sysdba
```

Y ejecuta (cambia `TuClave123` y `alumno` por los tuyos):

```sql
-- Administradores (SYS y SYSTEM son comunes a todo el CDB)
ALTER USER SYS IDENTIFIED BY "TuClave123";
ALTER USER SYSTEM IDENTIFIED BY "TuClave123" ACCOUNT UNLOCK;

-- Pasar a la base de datos de trabajo (PDB)
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER USER PDBADMIN IDENTIFIED BY "TuClave123" ACCOUNT UNLOCK;   -- solo en la imagen oficial

-- Perfil sin caducidad de contraseña (para que no caduque a mitad de curso)
CREATE PROFILE PERFIL_PRACTICAS LIMIT PASSWORD_LIFE_TIME UNLIMITED;

-- Tu usuario de trabajo
CREATE USER alumno IDENTIFIED BY "Alumno123x"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS
  PROFILE PERFIL_PRACTICAS;
GRANT CREATE SESSION TO alumno;
GRANT DB_DEVELOPER_ROLE TO alumno;   -- rol de 23ai: tablas, vistas, procedimientos, etc.

EXIT
```

> Las contraseñas de Oracle distinguen **mayúsculas y minúsculas**. Evita `@`, `/`, comillas y
> espacios: rompen las cadenas de conexión.

---

## 10. Conectarte

| Dato | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `1521` |
| Servicio (PDB, para trabajar) | `FREEPDB1` |
| Servicio (CDB, administración) | `FREE` |

```bash
# SQL*Plus dentro del contenedor (te pide la contraseña)
docker exec -it oracle23ai sqlplus alumno@//localhost:1521/FREEPDB1
```

- **JDBC:** `jdbc:oracle:thin:@//localhost:1521/FREEPDB1`
- **SQL Developer:** Nueva conexión → Tipo *Básico* → Host `localhost` → Puerto `1521` →
  **Nombre del servicio** `FREEPDB1` (no «SID»).

---

## 11. Uso diario

```bash
docker start oracle23ai          # arrancar (Docker Desktop debe estar abierto)
docker stop -t 120 oracle23ai    # parar de forma ordenada
docker ps -a                     # ver el estado
docker logs -f oracle23ai        # ver el registro
```

---

## 12. Opcional: clientes en tu Ubuntu

### SQLcl (línea de comandos)

```bash
sudo apt-get install -y openjdk-17-jre-headless unzip
curl -fLo /tmp/sqlcl.zip https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip
mkdir -p ~/.local/share/oracle23ai && unzip -q /tmp/sqlcl.zip -d ~/.local/share/oracle23ai
~/.local/share/oracle23ai/sqlcl/bin/sql alumno@//localhost:1521/FREEPDB1
```

### SQL Developer 24.3.1 (gráfico)

```bash
sudo apt-get install -y openjdk-17-jdk unzip
curl -fLo /tmp/sqldeveloper.zip \
  https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-24.3.1.347.1826-no-jre.zip
unzip -q /tmp/sqldeveloper.zip -d ~/.local/share/oracle23ai
~/.local/share/oracle23ai/sqldeveloper/sqldeveloper.sh
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
