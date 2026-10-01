# Hoja de Ruta de Compilación: `hfsfuse` en Windows (MSYS2 UCRT64 + WinFSP)

## 1. Objetivos del Proyecto

Portar y compilar la herramienta `hfsfuse` para entornos Windows 64-bits utilizando la cadena de herramientas GCC de MSYS2 (entorno UCRT64) y la biblioteca de compatibilidad FUSE provista por **WinFSP**.

---

## 2. Estado de Avance

| h   | Estado          | Componente / Hito                   | Descripción / Solución Aplicada                                                                                           |
| --- | --------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Completado**  | Encabezado `version.h`              | Creado manualmente en la raíz con las macros `HFSFUSE_VERSION` y `HFSFUSE_VERSION_STRING`.                                |
| 2   | **Completado**  | Capa de Compatibilidad POSIX        | Creado `win_compat.h` para emular `stpcpy`, `localtime_r`, `syslog` y definiendo `ST_RDONLY`.                             |
| 3   | **Completado**  | Resolución de Conflicto `fuse_stat` | `win_compat.h` incluye `<fuse.h>` primero y no redefine `stat`/`statvfs`; `hfsfuse.c` convierte `struct stat` → `struct fuse_stat` con `stat_to_fuse_stat()`. |
| 4   | **Completado**  | Compilación y Enlace Final          | `hfsfuse.exe` generado en la raíz, enlazado contra `winfsp-x64.dll` (ver Error 3). Sin advertencias con `-Wall -Wextra`. |
| 5   | **Completado**  | Pruebas de Montaje                  | Memoria USB de 8 GB (APM, HFS+ con journal) montada y leída desde el Explorador sin privilegios de administrador. |
| 6   | **Completado**  | Integración con el Explorador       | Servicio de WinFsp.Launcher (`scripts/install-windows.ps1`): `net use M: \hfsfusePhysicalDriveN` o "Conectar a unidad de red". |

---

## 3. Registro de Errores y Resoluciones

### Error 1: `version.h: No such file or directory`

- **Causa**: El archivo de versión no se generó al omitir la fase de `configure/make`.
- **Solución**: Creación de `version.h` con:
  ```c
  #ifndef VERSION_H
  #define VERSION_H
  #define HFSFUSE_VERSION "0.456-windows"
  #define HFSFUSE_VERSION_STRING "0.456-windows"
  #endif
  ```

### Error 2: `win_compat.h:14:14: error: redefinition of 'struct fuse_stat'`

- **Causa**: un `#define stat fuse_stat` global en `win_compat.h`, activo antes de incluir `winfsp_fuse.h`, reescribía la declaración interna de `struct fuse_stat` (`winfsp_fuse.h:151`).
- **Solución**: `win_compat.h` incluye `<fuse.h>` antes de cualquier macro (con `FUSE_USE_VERSION 29` por defecto) y no define alias para `stat` ni `statvfs`. `hfsfuse_statfs` usa `struct fuse_statvfs` directamente bajo `_WIN32`.
- **Consecuencia corregida**: sin el alias, `getattr`, `fgetattr` y el `filler` de `readdir` recibían un `struct stat` de MinGW donde WinFSP espera `struct fuse_stat` (layout distinto; `st_ino` de MinGW es de 16 bits). Bajo `_WIN32`, `stat_type` es `struct fuse_stat` y el helper `stat_to_fuse_stat()` convierte el resultado de `hfs_stat` tomando el CNID y la fecha de creación del registro de catálogo. Ya **no** se necesita `-Wno-incompatible-pointer-types`.

### Error 3: enlace contra `libfuse-2.8.dll.a`

- **Causa**: esa biblioteca de importación pertenece al componente "FUSE for Cygwin" y apunta a una DLL de Cygwin, no utilizable desde un binario nativo UCRT64.
- **Solución**: en MinGW las funciones `fuse_*` de `winfsp_fuse.h` son `static inline` y llaman a `fsp_fuse_*` exportadas por `winfsp-x64.dll`. Se enlaza directamente contra la DLL: `-L"/c/Program Files (x86)/WinFsp/bin" -lwinfsp-x64`.

## 4. Comando de Compilación Verificado (MSYS2 UCRT64)

```bash
# 1. Bibliotecas estáticas
make lib/libhfsuser/libhfsuser.a lib/libhfs/libhfs.a lib/utf8proc/libutf8proc.a lib/LZVN/libFastCompression.a

# 2. Ejecutable
gcc -std=gnu11 -O2 -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers \
    -D_FILE_OFFSET_BITS=64 -D_POSIX_THREAD_SAFE_FUNCTIONS -D_WIN32_WINNT=0x0601 \
    -DFUSE_USE_VERSION=29 -DHAVE_UTF8PROC -DHAVE_LZVN -DHAVE_ZLIB -DXATTR_NAMESPACE=user. \
    -include win_compat.h -I. -Ithird_party/winfsp/lib \
    -iquote lib/libhfsuser -iquote lib/libhfs -iquote lib/utf8proc -iquote lib/LZVN \
    src/hfsfuse.c lib/libhfsuser/libhfsuser.a lib/libhfs/libhfs.a \
    lib/utf8proc/libutf8proc.a lib/LZVN/libFastCompression.a \
    -L"/c/Program Files (x86)/WinFsp/bin" -lwinfsp-x64 -lz -lpthread -o hfsfuse.exe
```

Dependencias en tiempo de ejecución: `winfsp-x64.dll`, `zlib1.dll`, `libwinpthread-1.dll` (deben estar en el `PATH`). LZFSE no está disponible: los archivos comprimidos con LZFSE no podrán leerse.

## 5. Plan v2: Lectura y Escritura (Opción A — implementación propia)

Investigación previa (2026-10): no existe una solución gratuita/open source con escritura HFS+ en Windows. Los proyectos existentes son de solo lectura: `0x09/hfsfuse`, `libyal/libfshfs`, `zombodotcom/applesauce` (WinFSP), HFSExplorer. Las opciones con escritura son de pago (Paragon HFS+, MacDrive).

Requisito del volumen: journal desactivado (`diskutil disableJournal /Volumes/NOMBRE` en macOS). Con journal activo se monta en solo lectura.

| Fase | Estado        | Contenido                                                                                                   | Criterio de aceptación                                        |
| ---- | ------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 0    | **Pendiente** | Imágenes HFS+ de prueba, `fsck.hfsplus` (hfsprogs vía WSL), validación de la v1 de solo lectura en memoria real | v1 monta y lee la memoria USB; flujo imagen → fsck automatizado |
| 1    | **Pendiente** | E/S de escritura en dispositivo, bitmap de asignación, Volume Header principal y alternativo, bit "en uso", `-o rw` | Montar/desmontar en rw deja el volumen limpio según fsck       |
| 2    | **Pendiente** | `write`, `truncate`, extensión de archivos (extents del registro y árbol de extents overflow), fechas       | Modificar archivos existentes sin errores de fsck             |
| 3    | **Pendiente** | Inserción/borrado en B-Tree con división y fusión de nodos: `create`, `mkdir`, `unlink`, `rmdir`, `rename`, thread records, valence | Crear/borrar/renombrar desde el Explorador sin errores de fsck |
| 4    | **Pendiente** | xattrs, `chmod`/`chown`, flush al desmontar, pruebas de concurrencia                                        | Uso diario con varias aplicaciones en paralelo                |

Fuera de alcance inicial: escribir archivos comprimidos (decmpfs), crear hard links, escritura del journal.

## 6. Uso desde el Explorador de Windows (WinFsp.Launcher)

Un proceso elevado crea letras de unidad invisibles para el Explorador normal, por eso hfsfuse se registra como servicio de WinFsp.Launcher, que lo ejecuta como LocalSystem (puede leer el disco en bruto) y expone la unidad en la sesión del usuario.

```powershell
# Compilar (genera hfsfuse.exe autónomo: zlib/winpthread estáticos, winfsp-x64.dll con carga diferida)
C:\msys64\usr\bin\env.exe MSYSTEM=UCRT64 /usr/bin/bash -l scripts/build-windows.sh

# Instalar (PowerShell de administrador, una sola vez)
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 [-AllowDirtyJournal]

# Montar / desmontar (usuario normal)
net use M: \hfsfuse\PhysicalDrive3
net use M: /delete
```

- El launcher pasa la ruta como `\hfsfuse\PhysicalDriveN` (`%1`) y la letra (`%2`); hfsfuse la traduce a `\.\PhysicalDriveN` y solo acepta discos físicos.
- Una instancia por disco: mapear el mismo disco dos veces devuelve `STATUS_OBJECT_NAME_COLLISION` (`c0000035`).
- Diagnóstico: `C:\ProgramData\hfsfuse\hfsfuse.log` y el Visor de eventos (origen `WinFsp`).
- Opciones por defecto en Windows: `uid=-1,gid=-1,umask=022,dothidden` y `volname` con el nombre del volumen HFS+.
