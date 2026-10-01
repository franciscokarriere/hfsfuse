# Arquitectura del Port HFS+ a Windows (WinFSP)

## Flujo de Datos y Capas

1. **Capa Física:** Disco duro formateado en HFS+ (acceso raw vía `\\.\PhysicalDriveX`).
2. **Capa de Abstracción FUSE:** `libwinfsp-fuse-X.Y.dll` (proporcionada por WinFSP).
3. **Núcleo de Lectura HFS+:** Código fuente original de `hfsfuse` (parseo de Volume Header, Catalog File, B-Tree Nodes, Extents Overflow File).
4. **WinFSP Kernel Driver:** Mapea las llamadas del sistema de archivos de Windows (NTFS/FAT API) hacia el ejecutable en modo usuario.

## Componentes a Adaptar

- **Reemplazo de `<sys/mount.h>` y `<sys/param.h>`:** Mapear constantes POSIX a tipos equivalentes de Win32 o encabezados de WinFSP.
- **Acceso a Dispositivos Bloque:** Sustituir la apertura de nodos tipo `/dev/sdX` por handlers Win32 `CreateFile` o `open()` con banderas binarias de MSYS2 para dispositivos físicos.
